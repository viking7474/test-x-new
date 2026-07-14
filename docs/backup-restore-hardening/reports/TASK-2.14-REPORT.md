# TASK-2.14 Implementation Report

## Baseline and exact scope

- Baseline: `9d046a406a5a346cab2a66d3fc27c71d702b9321`.
- Authorized production files: `PXRestoreResult.h`, `PXRestoreResult.m`, `AppDataBackupManager.h`, `AppDataBackupManager.m`.
- Required report: `docs/backup-restore-hardening/reports/TASK-2.14-REPORT.md`.
- No coordinator document was edited, staged, reverted, or included.

### Recorded baseline commands

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
?? docs/backup-restore-hardening/reviews/TASK-2.2-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.3-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.4-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.5-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.6-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.6A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.7-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.8-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-2.9-REVIEW.md
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
?? docs/backup-restore-hardening/tasks/TASK-2.2-enforce-supported-manifest-versions.md
?? docs/backup-restore-hardening/tasks/TASK-2.3-enforce-exact-restore-bundle-identity.md
?? docs/backup-restore-hardening/tasks/TASK-2.4-remove-recorded-destination-fallbacks.md
?? docs/backup-restore-hardening/tasks/TASK-2.5-add-common-artifact-verifier.md
?? docs/backup-restore-hardening/tasks/TASK-2.6-add-archive-entry-safety-validator.md
?? docs/backup-restore-hardening/tasks/TASK-2.6A-fix-archive-validator-compatibility-and-bounds.md
?? docs/backup-restore-hardening/tasks/TASK-2.7-build-immutable-restore-plan.md
?? docs/backup-restore-hardening/tasks/TASK-2.8-stage-and-validate-main-data.md
?? docs/backup-restore-hardening/tasks/TASK-2.9-stage-and-validate-app-groups.md
git rev-parse HEAD
9d046a406a5a346cab2a66d3fc27c71d702b9321
git log -5 --oneline
9d046a4 phase2(task-2.13A): implement optional directory tree verifier
08d23dd phase2(task-2.13): add transactional optional component handling
9e83a05 phase2(task-2.12): add transactional app group commit
9790a22 phase2(task-2.11A): fix transaction pre-recovery proof and durability
e38db40 phase2(task-2.11): add transactional main-data commit
git diff --check
PASS
```

## Protected production SHA-256 before/after

- Protected snapshot entries: 291.
- Changed protected entries: 0.

| Path | Before SHA-256 | After SHA-256 | Bytes |
|---|---|---|---:|
| `.DS_Store` | `f4f3698d1ec6f68d7e09216183fe633be14d588a3f41f247b437bf03cf1228e1` | `f4f3698d1ec6f68d7e09216183fe633be14d588a3f41f247b437bf03cf1228e1` | 14340 |
| `.github/workflows/build-ios-arm.yml` | `43814c1ab1f47aee5dd88864aefc2068de5f91f23ce24df96394647958c5706e` | `43814c1ab1f47aee5dd88864aefc2068de5f91f23ce24df96394647958c5706e` | 4548 |
| `.gitignore` | `5f4946295e8cee11cf3e4b1ea686c1abdf2c68aeb1c49f482452e889b68bcec2` | `5f4946295e8cee11cf3e4b1ea686c1abdf2c68aeb1c49f482452e889b68bcec2` | 111 |
| `Agent.md` | `23a29d59fac7fc30d40b6a7c8387d0413d90d400fba88fbafb515476ba317336` | `23a29d59fac7fc30d40b6a7c8387d0413d90d400fba88fbafb515476ba317336` | 6521 |
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

## Old mutable-result inventory and placement correction

- Baseline manager header declared a mutable warnings-only `PXRestoreResult`.
- Baseline manager source contained an empty `@implementation PXRestoreResult`.
- The declaration and implementation now exist only in dedicated pure model files.
- `AppDataBackupManager.h` imports `PXRestoreResult.h` exactly once; public Restore selector bytes remain identical.

## Exact public enums

| Canonical order | Component | Bit |
|---:|---|---:|
| 1 | `PXRestoreComponentApplicationData` | `1 << 0` |
| 2 | `PXRestoreComponentProfileAppData` | `1 << 1` |
| 3 | `PXRestoreComponentGlobalSafari` | `1 << 2` |
| 4 | `PXRestoreComponentAppGroups` | `1 << 3` |
| 5 | `PXRestoreComponentSystemGlobal` | `1 << 4` |
| 6 | `PXRestoreComponentSharedSystemDatabases` | `1 << 5` |
| 7 | `PXRestoreComponentPreferences` | `1 << 6` |
| 8 | `PXRestoreComponentKeychain` | `1 << 7` |

`PXRestoreComponentAll` is the exact union of the eight bits.

| Component status | Rollback status |
|---|---|
| Skipped | NotPerformed |
| NotAttempted | Completed |
| Succeeded | Incomplete |
| Failed | — |

No Pending or Running value exists.

## Model invariants and immutability

### PXRestoreFailure

- Runtime nonempty `NSString` domain/message, no U+0000, UTF-8 limits 255/4096 bytes.
- Copies only domain/code/message; retains no `NSError` or `userInfo`.
- `copyWithZone:` returns self; equality/hash use all three fields.

### PXRestoreComponentResult invariant matrix

| Status | Planned | Committed | Rollback | Failure | Warnings |
|---|---:|---:|---|---|---|
| Skipped | 0 | 0 | NotPerformed | nil | empty |
| NotAttempted | 1…4096 | 0 | NotPerformed | nil | validated/preserved |
| Succeeded | 1…4096 | planned | NotPerformed | nil | validated/preserved |
| Failed | 1…4096 | 0 | exact known status | nonnil | validated/preserved |

Warnings are deep-copied in caller order with duplicates preserved and no trim/sort/normalization.

### Aggregate exact coverage

- Exactly eight component results, one per known single bit, canonicalized regardless of caller order.
- Skipped exactly complements requested; requested equals succeeded | notAttempted | failed.
- All four masks are pairwise disjoint and union to `PXRestoreComponentAll`.
- Aggregate warnings are supplied independently in exact legacy order; they are not concatenated from component warnings.

## Pure model boundary

`PXRestoreResult.m` imports only `PXRestoreResult.h` and references no manager, plan, transaction, staging, filesystem, process, UI, Keychain, user-default, notification, or dispatch API.

## Requested mask and planned-unit derivation

| Component | Requested authority | Planned units |
|---|---|---:|
| ApplicationData | always | 1 |
| ProfileAppData | `restorePlan.includesProfileAppData` | 1 |
| GlobalSafari | `restorePlan.includesGlobalSafari` | 1 |
| AppGroups | physical target-plan count > 0 | exact physical target count |
| SystemGlobal | immutable effective array nonempty | effective count |
| SharedSystemDatabases | immutable plan items nonempty | plan item count |
| Preferences | `restorePlan.includesPreferences` | 1 |
| Keychain | `restorePlan.includesKeychain` | 1 |

## Effective Safari duplicate proof

One immutable `effectiveSystemGlobalItems` array applies the accepted three-part duplicate rule once and is reused by both result planning and the transaction loop.

## Result availability boundary

The accumulator is created only after optional destination-plan success and before main archive-summary inspection. Code 321 is the only structured-planning failure and returns nil result before main staging.

### Pre-boundary completion inventory

1. Invalid public parameter synchronous completion.
2. Manifest/schema/version failure.
3. Exact bundle identity mismatch.
4. Exact ApplicationData destination failure.
5. Artifact verification failure.
6. Archive validation failure.
7. Immutable Restore plan failure.
8. Tar discovery failure.
9. Signed App Group entitlement read failure.
10. App Group target-plan failure.
11. Optional destination-plan failure.
12. Structured result planning code 321 failure.

### Post-boundary hard completion inventory

| Failure category | Component | Publication |
|---|---|---|
| Application main summary invalid | ApplicationData | result + exact existing error |
| Application workspace creation | ApplicationData | result + exact existing error |
| Application empty-stage validation | ApplicationData | result + exact existing error |
| Application extraction | ApplicationData | result + exact existing error |
| Application stage validation | ApplicationData | result + exact existing error |
| Application destination revalidation | ApplicationData | result + exact existing error |
| Application precommit stage equivalence | ApplicationData | result + exact existing error |
| Application transaction factory | ApplicationData | result + exact existing error |
| Application transaction commit | ApplicationData | result + exact existing error |
| Profile staging | ProfileAppData | result + exact existing error |
| Profile destination/item/factory | ProfileAppData | result + exact existing error |
| Profile commit | ProfileAppData | result + exact existing error |
| Safari staging | GlobalSafari | result + exact existing error |
| Safari destination/item/factory | GlobalSafari | result + exact existing error |
| Safari commit | GlobalSafari | result + exact existing error |
| AppGroup summary | AppGroups | result + exact existing error |
| AppGroup workspace creation | AppGroups | result + exact existing error |
| AppGroup empty validation | AppGroups | result + exact existing error |
| AppGroup extraction | AppGroups | result + exact existing error |
| AppGroup stage validation | AppGroups | result + exact existing error |
| AppGroup source equivalence | AppGroups | result + exact existing error |
| AppGroup duplicate workspace cleanup | AppGroups | result + exact existing error |
| AppGroup missing accepted source | AppGroups | result + exact existing error |
| AppGroup staged-array count | AppGroups | result + exact existing error |
| AppGroup transaction factory | AppGroups | result + exact existing error |
| AppGroup commit | AppGroups | result + exact existing error |
| SystemGlobal staging | SystemGlobal | result + exact existing error |
| SystemGlobal destination/item | SystemGlobal | result + exact existing error |
| SystemGlobal transaction factory | SystemGlobal | result + exact existing error |
| SystemGlobal commit | SystemGlobal | result + exact existing error |
| Shared DB staging | SharedSystemDatabases | result + exact existing error |
| Shared DB destination/item | SharedSystemDatabases | result + exact existing error |
| Shared DB transaction factory | SharedSystemDatabases | result + exact existing error |
| Shared DB commit | SharedSystemDatabases | result + exact existing error |
| Preferences staging | Preferences | result + exact existing error |
| Preferences destination/item/factory/commit | Preferences | result + exact existing error |
| Keychain staging hard failure | Keychain | result + exact existing error |

Every post-boundary branch calls the one structured failure publisher, dispatches on the main queue, and returns immediately.

## Failure attribution and success boundaries

| Component | Success boundary | Failure ownership |
|---|---|---|
| ApplicationData | durable main commit plus transaction/staging warnings | all hard failures inside this domain only |
| ProfileAppData | durable optional commit plus cleanup warnings | all hard failures inside this domain only |
| GlobalSafari | durable optional commit plus cleanup warnings | all hard failures inside this domain only |
| AppGroups | durable batch commit plus transaction/staging warnings | all hard failures inside this domain only |
| SystemGlobal | durable optional batch commit plus warnings | all hard failures inside this domain only |
| SharedSystemDatabases | durable optional batch commit plus warnings/informational warning | all hard failures inside this domain only |
| Preferences | durable file transaction commit plus warnings | all hard failures inside this domain only |
| Keychain | helper/bridge success plus staging cleanup warning collection | all hard failures inside this domain only |

## Seven-domain rollback mapping

| Typed transaction domain | rollbackPerformed | rollbackComplete | Published status |
|---|---|---|---|
| ApplicationData | NO | any | NotPerformed |
| ApplicationData | YES | YES | Completed |
| ApplicationData | YES | NO | Incomplete |
| ProfileAppData | NO | any | NotPerformed |
| ProfileAppData | YES | YES | Completed |
| ProfileAppData | YES | NO | Incomplete |
| GlobalSafari | NO | any | NotPerformed |
| GlobalSafari | YES | YES | Completed |
| GlobalSafari | YES | NO | Incomplete |
| AppGroups | NO | any | NotPerformed |
| AppGroups | YES | YES | Completed |
| AppGroups | YES | NO | Incomplete |
| SystemGlobal | NO | any | NotPerformed |
| SystemGlobal | YES | YES | Completed |
| SystemGlobal | YES | NO | Incomplete |
| SharedSystemDatabases | NO | any | NotPerformed |
| SharedSystemDatabases | YES | YES | Completed |
| SharedSystemDatabases | YES | NO | Incomplete |
| Preferences | NO | any | NotPerformed |
| Preferences | YES | YES | Completed |
| Preferences | YES | NO | Incomplete |

Keychain always publishes NotPerformed and has no filesystem rollback claim.

## Keychain warning-only structured failure

- The aggregate warning count is snapshotted immediately before helper/bridge execution.
- Existing helper warnings, exact explicit failure warning, and staging cleanup warning form the component suffix.
- Helper failure remains completion-error nil, but Keychain is Failed with synthetic `PXBackupErrorDomain` code 322 and message `Keychain restore failed`.
- Staging failure remains hard and publishes result plus the exact existing error.

## Warning text/order and component attribution

- Baseline Restore warning append expressions: 21.
- Current Restore warning append expressions: 21.
- Exact normalized expression sequence equal: True.
- Aggregate-only manifest/profile mismatch warnings remain outside component suffixes.
- Component suffix snapshots preserve occurrence order and duplicates without changing aggregate order.

## Post-restore verification

The two existing post-verification warnings remain final warning-only checks, append at the aggregate tail, attach to ApplicationData, and do not change ApplicationData from Succeeded to Failed.

## Existing caller compatibility and UI zero diff

- Public selector byte-identical: True.
- Strict caller harness compiled `PXRestoreResult *`, `result.warnings.count`, and fast enumeration over `result.warnings`.
- All UI/controller files are protected and hash-identical.

## Completion thread/count proof

- Invalid public parameters retain synchronous behavior.
- Async pre-boundary, post-boundary, and normal completions retain main-queue dispatch.
- Every hard branch returns immediately after the single publisher call.
- No callback or progress API was added.

## Code 321 and 322 contracts

| Code | Boundary | Result | Completion error | Description |
|---:|---|---|---|---|
| 321 | result planning, before main staging | nil | nonnil | Structured Restore result could not be constructed |
| 322 | Keychain helper warning-only failure | structured failed Keychain | nil | Keychain restore failed |

## Static and forbidden-change gates

| Gate | Result |
|---|---|
| component bits | 8 |
| all-mask | 1 |
| component statuses | 4 |
| rollback statuses | 3 |
| public model classes | 3 |
| subclassing-restricted classes | 3 |
| NSCopying classes | 3 |
| public readwrite properties | 0 |
| model implementations | 3 |
| manager old declaration/implementation | 0/0 |
| manager header model import | 1 |
| code 321/code 322 | 1/1 |
| effective array declaration | 1 |
| typed rollback mapper calls | 7 |
| success result construction | 1 |
| post-boundary nil-result hard completions | 0 |
| warning sequence equality | True |
| protected changed files | 0 |
| model strict frontend | PASS |
| accumulator strict frontend | PASS |
| manager integration strict frontend | PASS |
| caller compatibility frontend | PASS |
| git diff --check | PASS |

## Explicit scenario matrix

Explicit scenarios: 300.

| # | Scenario | Expected/result | Evidence |
|---:|---|---|---|
| 1 | ApplicationData bit 0 | PASS static | Exact closed component set retained. |
| 2 | ProfileAppData bit 1 | PASS static | Exact closed component set retained. |
| 3 | GlobalSafari bit 2 | PASS static | Exact closed component set retained. |
| 4 | AppGroups bit 3 | PASS static | Exact closed component set retained. |
| 5 | SystemGlobal bit 4 | PASS static | Exact closed component set retained. |
| 6 | SharedSystemDatabases bit 5 | PASS static | Exact closed component set retained. |
| 7 | Preferences bit 6 | PASS static | Exact closed component set retained. |
| 8 | Keychain bit 7 | PASS static | Exact closed component set retained. |
| 9 | All exact union | PASS static | Exact closed component set retained. |
| 10 | Skipped status | PASS static | Exact final enum value exists and no pending/running state exists. |
| 11 | NotAttempted status | PASS static | Exact final enum value exists and no pending/running state exists. |
| 12 | Succeeded status | PASS static | Exact final enum value exists and no pending/running state exists. |
| 13 | Failed status | PASS static | Exact final enum value exists and no pending/running state exists. |
| 14 | NotPerformed rollback | PASS static | Exact final enum value exists and no pending/running state exists. |
| 15 | Completed rollback | PASS static | Exact final enum value exists and no pending/running state exists. |
| 16 | Incomplete rollback | PASS static | Exact final enum value exists and no pending/running state exists. |
| 17 | Failure valid domain/message | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 18 | Failure domain nil | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 19 | Failure domain non-string | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 20 | Failure domain empty | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 21 | Failure domain U+0000 | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 22 | Failure domain 255 UTF-8 bytes | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 23 | Failure domain 256 UTF-8 bytes | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 24 | Failure message nil | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 25 | Failure message non-string | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 26 | Failure message empty | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 27 | Failure message U+0000 | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 28 | Failure message 4096 UTF-8 bytes | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 29 | Failure message 4097 UTF-8 bytes | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 30 | Failure copies mutable domain | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 31 | Failure copies mutable message | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 32 | Failure copyWithZone identity | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 33 | Failure equality all fields | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 34 | Failure inequality domain | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 35 | Failure inequality code | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 36 | Failure inequality message | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 37 | Failure hash all fields | PASS model contract | Initializer/string/copy/equality implementation enforces the documented boundary. |
| 38 | Component zero bit rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 39 | Component multi-bit rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 40 | Component unknown bit rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 41 | Unknown component status rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 42 | Unknown rollback status rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 43 | Planned units 4096 accepted | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 44 | Planned units 4097 rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 45 | Warnings non-array rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 46 | Warnings 4096 items accepted | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 47 | Warnings 4097 items rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 48 | Warning non-string rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 49 | Warning empty rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 50 | Warning U+0000 rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 51 | Warning 4096 bytes accepted | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 52 | Warning 4097 bytes rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 53 | Warning order preserved | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 54 | Warning duplicates preserved | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 55 | Warning strings deep-copied | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 56 | Component copyWithZone identity | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 57 | Component equality every property | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 58 | Component hash every property | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 59 | Skipped exact valid state | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 60 | Skipped planned nonzero rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 61 | Skipped committed nonzero rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 62 | Skipped rollback completed rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 63 | Skipped warning rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 64 | Skipped failure rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 65 | NotAttempted valid state | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 66 | NotAttempted planned zero rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 67 | NotAttempted committed nonzero rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 68 | NotAttempted rollback completed rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 69 | NotAttempted failure rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 70 | Succeeded valid state | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 71 | Succeeded planned zero rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 72 | Succeeded partial committed rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 73 | Succeeded committed above planned rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 74 | Succeeded rollback completed rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 75 | Succeeded failure rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 76 | Failed valid NotPerformed | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 77 | Failed valid Completed | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 78 | Failed valid Incomplete | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 79 | Failed planned zero rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 80 | Failed committed nonzero rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 81 | Failed nil failure rejected | PASS model contract | PXRestoreComponentResult invariant matrix covers this case. |
| 82 | Requested unknown bits rejected | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 83 | ApplicationData absent rejected | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 84 | Exactly eight results required | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 85 | Seven results rejected | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 86 | Nine results rejected | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 87 | Non-result object rejected | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 88 | Zero component result rejected upstream | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 89 | Multi-bit component result rejected upstream | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 90 | Duplicate component rejected | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 91 | Missing component rejected | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 92 | Caller order canonicalized | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 93 | Reverse caller order canonicalized | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 94 | Skipped requested component rejected | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 95 | Non-skipped absent component rejected | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 96 | Skipped mask exact complement | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 97 | Requested equals success|notAttempted|failed | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 98 | Four masks pairwise disjoint | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 99 | Four masks union all components | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 100 | hasWarnings false for empty aggregate | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 101 | hasWarnings true for warning | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 102 | hasFailures false without failed mask | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 103 | hasFailures true with failed component | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 104 | hasIncompleteRollback false normally | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 105 | hasIncompleteRollback true on incomplete | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 106 | allRequestedComponentsSucceeded true exact | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 107 | allRequestedComponentsSucceeded false on failure | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 108 | allRequestedComponentsSucceeded false on not-attempted | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 109 | Aggregate warning order preserved | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 110 | Aggregate warning duplicates preserved | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 111 | Aggregate warnings not concatenated from components | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 112 | Lookup each known component | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 113 | Lookup zero returns nil | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 114 | Lookup multi-bit returns nil | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 115 | Lookup unknown returns nil | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 116 | Result copyWithZone identity | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 117 | Result equality every stored value | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 118 | Result hash every stored value | PASS model contract | PXRestoreResult exact-coverage validation covers this case. |
| 119 | Invalid public parameter synchronous completion | PASS branch inventory | Result remains nil and existing error path is retained before the structured boundary. |
| 120 | Manifest/schema/version failure | PASS branch inventory | Result remains nil and existing error path is retained before the structured boundary. |
| 121 | Exact bundle identity mismatch | PASS branch inventory | Result remains nil and existing error path is retained before the structured boundary. |
| 122 | Exact ApplicationData destination failure | PASS branch inventory | Result remains nil and existing error path is retained before the structured boundary. |
| 123 | Artifact verification failure | PASS branch inventory | Result remains nil and existing error path is retained before the structured boundary. |
| 124 | Archive validation failure | PASS branch inventory | Result remains nil and existing error path is retained before the structured boundary. |
| 125 | Immutable Restore plan failure | PASS branch inventory | Result remains nil and existing error path is retained before the structured boundary. |
| 126 | Tar discovery failure | PASS branch inventory | Result remains nil and existing error path is retained before the structured boundary. |
| 127 | Signed App Group entitlement read failure | PASS branch inventory | Result remains nil and existing error path is retained before the structured boundary. |
| 128 | App Group target-plan failure | PASS branch inventory | Result remains nil and existing error path is retained before the structured boundary. |
| 129 | Optional destination-plan failure | PASS branch inventory | Result remains nil and existing error path is retained before the structured boundary. |
| 130 | Structured result planning code 321 failure | PASS branch inventory | Result remains nil and existing error path is retained before the structured boundary. |
| 131 | ApplicationData always requested one unit | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 132 | Profile requested iff included one unit | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 133 | Safari requested iff included one unit | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 134 | AppGroups physical target count authority | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 135 | SystemGlobal effective immutable item count authority | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 136 | Shared DB Restore-plan item count authority | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 137 | Preferences requested iff included one unit | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 138 | Keychain requested iff included one unit | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 139 | Plan count zero maps to skipped | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 140 | Plan count above 4096 triggers code 321 | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 141 | Safari duplicate excluded from effective system array | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 142 | Non-Safari system item retained | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 143 | Safari item retained for non-MobileSafari bundle | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 144 | Safari item retained when global Safari absent | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 145 | Same effective array used by planning | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 146 | Same effective array used by transaction loop | PASS manager proof | Requested mask and planned units derive only from accepted immutable plan/target-plan state. |
| 147 | Application main summary invalid | PASS structured branch | Publishes result+error and attributes only ApplicationData. |
| 148 | Application workspace creation | PASS structured branch | Publishes result+error and attributes only ApplicationData. |
| 149 | Application empty-stage validation | PASS structured branch | Publishes result+error and attributes only ApplicationData. |
| 150 | Application extraction | PASS structured branch | Publishes result+error and attributes only ApplicationData. |
| 151 | Application stage validation | PASS structured branch | Publishes result+error and attributes only ApplicationData. |
| 152 | Application destination revalidation | PASS structured branch | Publishes result+error and attributes only ApplicationData. |
| 153 | Application precommit stage equivalence | PASS structured branch | Publishes result+error and attributes only ApplicationData. |
| 154 | Application transaction factory | PASS structured branch | Publishes result+error and attributes only ApplicationData. |
| 155 | Application transaction commit | PASS structured branch | Publishes result+error and attributes only ApplicationData. |
| 156 | Profile staging | PASS structured branch | Publishes result+error and attributes only ProfileAppData. |
| 157 | Profile destination/item/factory | PASS structured branch | Publishes result+error and attributes only ProfileAppData. |
| 158 | Profile commit | PASS structured branch | Publishes result+error and attributes only ProfileAppData. |
| 159 | Safari staging | PASS structured branch | Publishes result+error and attributes only GlobalSafari. |
| 160 | Safari destination/item/factory | PASS structured branch | Publishes result+error and attributes only GlobalSafari. |
| 161 | Safari commit | PASS structured branch | Publishes result+error and attributes only GlobalSafari. |
| 162 | AppGroup summary | PASS structured branch | Publishes result+error and attributes only AppGroups. |
| 163 | AppGroup workspace creation | PASS structured branch | Publishes result+error and attributes only AppGroups. |
| 164 | AppGroup empty validation | PASS structured branch | Publishes result+error and attributes only AppGroups. |
| 165 | AppGroup extraction | PASS structured branch | Publishes result+error and attributes only AppGroups. |
| 166 | AppGroup stage validation | PASS structured branch | Publishes result+error and attributes only AppGroups. |
| 167 | AppGroup source equivalence | PASS structured branch | Publishes result+error and attributes only AppGroups. |
| 168 | AppGroup duplicate workspace cleanup | PASS structured branch | Publishes result+error and attributes only AppGroups. |
| 169 | AppGroup missing accepted source | PASS structured branch | Publishes result+error and attributes only AppGroups. |
| 170 | AppGroup staged-array count | PASS structured branch | Publishes result+error and attributes only AppGroups. |
| 171 | AppGroup transaction factory | PASS structured branch | Publishes result+error and attributes only AppGroups. |
| 172 | AppGroup commit | PASS structured branch | Publishes result+error and attributes only AppGroups. |
| 173 | SystemGlobal staging | PASS structured branch | Publishes result+error and attributes only SystemGlobal. |
| 174 | SystemGlobal destination/item | PASS structured branch | Publishes result+error and attributes only SystemGlobal. |
| 175 | SystemGlobal transaction factory | PASS structured branch | Publishes result+error and attributes only SystemGlobal. |
| 176 | SystemGlobal commit | PASS structured branch | Publishes result+error and attributes only SystemGlobal. |
| 177 | Shared DB staging | PASS structured branch | Publishes result+error and attributes only SharedSystemDatabases. |
| 178 | Shared DB destination/item | PASS structured branch | Publishes result+error and attributes only SharedSystemDatabases. |
| 179 | Shared DB transaction factory | PASS structured branch | Publishes result+error and attributes only SharedSystemDatabases. |
| 180 | Shared DB commit | PASS structured branch | Publishes result+error and attributes only SharedSystemDatabases. |
| 181 | Preferences staging | PASS structured branch | Publishes result+error and attributes only Preferences. |
| 182 | Preferences destination/item/factory/commit | PASS structured branch | Publishes result+error and attributes only Preferences. |
| 183 | Keychain staging hard failure | PASS structured branch | Publishes result+error and attributes only Keychain. |
| 184 | ApplicationData rollback NotPerformed flags NO | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 185 | ApplicationData rollback Completed flags YES/YES | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 186 | ApplicationData rollback Incomplete flags YES/NO | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 187 | ProfileAppData rollback NotPerformed flags NO | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 188 | ProfileAppData rollback Completed flags YES/YES | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 189 | ProfileAppData rollback Incomplete flags YES/NO | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 190 | GlobalSafari rollback NotPerformed flags NO | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 191 | GlobalSafari rollback Completed flags YES/YES | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 192 | GlobalSafari rollback Incomplete flags YES/NO | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 193 | AppGroups rollback NotPerformed flags NO | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 194 | AppGroups rollback Completed flags YES/YES | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 195 | AppGroups rollback Incomplete flags YES/NO | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 196 | SystemGlobal rollback NotPerformed flags NO | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 197 | SystemGlobal rollback Completed flags YES/YES | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 198 | SystemGlobal rollback Incomplete flags YES/NO | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 199 | SharedSystemDatabases rollback NotPerformed flags NO | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 200 | SharedSystemDatabases rollback Completed flags YES/YES | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 201 | SharedSystemDatabases rollback Incomplete flags YES/NO | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 202 | Preferences rollback NotPerformed flags NO | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 203 | Preferences rollback Completed flags YES/YES | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 204 | Preferences rollback Incomplete flags YES/NO | PASS typed mapping | Uses retained transaction rollbackPerformed/rollbackComplete flags; failed remains committed=0. |
| 205 | ApplicationData durable success boundary | PASS manager proof | Succeeded is marked only after accepted success and warning collection; committed equals planned. |
| 206 | ProfileAppData durable success boundary | PASS manager proof | Succeeded is marked only after accepted success and warning collection; committed equals planned. |
| 207 | GlobalSafari durable success boundary | PASS manager proof | Succeeded is marked only after accepted success and warning collection; committed equals planned. |
| 208 | AppGroups durable success boundary | PASS manager proof | Succeeded is marked only after accepted success and warning collection; committed equals planned. |
| 209 | SystemGlobal durable success boundary | PASS manager proof | Succeeded is marked only after accepted success and warning collection; committed equals planned. |
| 210 | SharedSystemDatabases durable success boundary | PASS manager proof | Succeeded is marked only after accepted success and warning collection; committed equals planned. |
| 211 | Preferences durable success boundary | PASS manager proof | Succeeded is marked only after accepted success and warning collection; committed equals planned. |
| 212 | Keychain durable success boundary | PASS manager proof | Succeeded is marked only after accepted success and warning collection; committed equals planned. |
| 213 | Manifest warning aggregate-only | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 214 | Profile-ID mismatch aggregate-only | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 215 | Main transaction cleanup warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 216 | Main staging cleanup warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 217 | Profile optional cleanup warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 218 | Profile staging cleanup warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 219 | Safari optional cleanup warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 220 | Safari staging cleanup warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 221 | AppGroup transaction cleanup warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 222 | AppGroup staging cleanup warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 223 | System optional cleanup warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 224 | System staging cleanup warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 225 | Shared optional cleanup warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 226 | Shared staging cleanup warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 227 | Shared informational warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 228 | Preferences optional cleanup warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 229 | Preferences staging cleanup warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 230 | Keychain helper warning suffix attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 231 | Keychain explicit execution warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 232 | Keychain staging cleanup warning attribution | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 233 | Post metadata warning at aggregate tail | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 234 | Post Library warning at aggregate tail | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 235 | Post warnings attach ApplicationData | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 236 | Post warnings do not fail ApplicationData | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 237 | Exact warning occurrence sequence retained | PASS compatibility proof | Baseline and current warning append expression sequence is identical; component suffix attachment is explicit. |
| 238 | Keychain staged source unchanged | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 239 | Keychain groups unchanged | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 240 | Keychain method unchanged | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 241 | Keychain in-app decision unchanged | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 242 | Keychain overwrite unchanged | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 243 | Keychain helper/bridge call unchanged | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 244 | Keychain execution failure warning-only completion error | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 245 | Keychain failure synthetic domain | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 246 | Keychain failure synthetic code 322 | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 247 | Keychain failure synthetic message | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 248 | Keychain failure committed units zero | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 249 | Keychain rollback NotPerformed | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 250 | Keychain success after cleanup warning collection | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 251 | Keychain staging hard result+error | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 252 | All-success result+nil error | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 253 | Keychain warning-only failed mask+nil error | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 254 | Post-boundary result+error compatibility | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 255 | Pre-boundary nil-result compatibility | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 256 | Invalid parameters remain synchronous | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 257 | Async pre-boundary completion main queue | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 258 | Async post-boundary completion main queue | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 259 | Normal completion main queue | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 260 | Every hard branch returns after one callback | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 261 | No progress callback added | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 262 | No second completion callback added | PASS contract proof | Manager source preserves existing execution and publishes the required structured snapshot. |
| 263 | UI/controller zero diff | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 264 | Main transaction byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 265 | AppGroup transaction byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 266 | Optional transaction byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 267 | Main staging byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 268 | AppGroup target plan byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 269 | Optional staging byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 270 | Restore plan byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 271 | Manifest validator byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 272 | Artifact verifier byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 273 | Archive validator byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 274 | Container resolver byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 275 | Path validator byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 276 | CommandRunner byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 277 | Makefile byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 278 | Keychain helper byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 279 | Keychain bridge byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 280 | Keychain script byte identity | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 281 | Backup behavior source outside manager diff zero | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 282 | High-level component order monotonic | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 283 | Public selector byte-identical | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 284 | Legacy result.warnings caller compiles | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 285 | Pure model frontend strict PASS | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 286 | Accumulator frontend strict PASS | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 287 | Manager integration frontend strict PASS | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 288 | Caller frontend strict PASS | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 289 | Protected SHA inventory unchanged | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 290 | No whole-Restore atomicity claim | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 291 | Phase 3 not started | PASS static/frontend | Independent source/hash/frontend gate supports this scenario. |
| 292 | Requested-mask coverage 0x01 | PASS model | ApplicationData present; canonical requested indices [0]; skipped complement is exact. |
| 293 | Requested-mask coverage 0x03 | PASS model | ApplicationData present; canonical requested indices [0, 1]; skipped complement is exact. |
| 294 | Requested-mask coverage 0x05 | PASS model | ApplicationData present; canonical requested indices [0, 2]; skipped complement is exact. |
| 295 | Requested-mask coverage 0x07 | PASS model | ApplicationData present; canonical requested indices [0, 1, 2]; skipped complement is exact. |
| 296 | Requested-mask coverage 0x09 | PASS model | ApplicationData present; canonical requested indices [0, 3]; skipped complement is exact. |
| 297 | Requested-mask coverage 0x0b | PASS model | ApplicationData present; canonical requested indices [0, 1, 3]; skipped complement is exact. |
| 298 | Requested-mask coverage 0x0d | PASS model | ApplicationData present; canonical requested indices [0, 2, 3]; skipped complement is exact. |
| 299 | Requested-mask coverage 0x0f | PASS model | ApplicationData present; canonical requested indices [0, 1, 2, 3]; skipped complement is exact. |
| 300 | Requested-mask coverage 0x11 | PASS model | ApplicationData present; canonical requested indices [0, 4]; skipped complement is exact. |

## Whitespace, CRLF, and NUL audit

- `PXRestoreResult.h`: bytes=4512, CRLF=0, bare LF=107, NUL=0, final newline=True.
- `PXRestoreResult.m`: bytes=15842, CRLF=0, bare LF=422, NUL=0, final newline=True.
- `AppDataBackupManager.h`: bytes=1442, CRLF=39, bare LF=0, NUL=0, final newline=True.
- `AppDataBackupManager.m`: bytes=193800, CRLF=0, bare LF=3614, NUL=0, final newline=True.
- Authorized source `git diff --check`: PASS.

## Build status and remaining runtime risks

- Strict Objective-C frontend gates passed for the pure model, private accumulator, exact planning/publication integration, and existing caller expressions.
- The local Windows workspace has no Theos, Apple clang, xcrun, or linked iOS artifact; GitHub Actions/Theos remains authoritative.
- Remaining runtime risk is limited to device-specific execution and Objective-C runtime integration not reproducible in the local Windows harness.

## Full authorized source diff

```diff
--- a/PXRestoreResult.h
+++ b/PXRestoreResult.h
@@ -0,0 +1,107 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+typedef NS_OPTIONS(NSUInteger, PXRestoreComponent) {
+    PXRestoreComponentApplicationData = 1 << 0,
+    PXRestoreComponentProfileAppData = 1 << 1,
+    PXRestoreComponentGlobalSafari = 1 << 2,
+    PXRestoreComponentAppGroups = 1 << 3,
+    PXRestoreComponentSystemGlobal = 1 << 4,
+    PXRestoreComponentSharedSystemDatabases = 1 << 5,
+    PXRestoreComponentPreferences = 1 << 6,
+    PXRestoreComponentKeychain = 1 << 7,
+    PXRestoreComponentAll =
+        PXRestoreComponentApplicationData |
+        PXRestoreComponentProfileAppData |
+        PXRestoreComponentGlobalSafari |
+        PXRestoreComponentAppGroups |
+        PXRestoreComponentSystemGlobal |
+        PXRestoreComponentSharedSystemDatabases |
+        PXRestoreComponentPreferences |
+        PXRestoreComponentKeychain,
+};
+
+typedef NS_ENUM(NSInteger, PXRestoreComponentStatus) {
+    PXRestoreComponentStatusSkipped = 0,
+    PXRestoreComponentStatusNotAttempted = 1,
+    PXRestoreComponentStatusSucceeded = 2,
+    PXRestoreComponentStatusFailed = 3,
+};
+
+typedef NS_ENUM(NSInteger, PXRestoreRollbackStatus) {
+    PXRestoreRollbackStatusNotPerformed = 0,
+    PXRestoreRollbackStatusCompleted = 1,
+    PXRestoreRollbackStatusIncomplete = 2,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXRestoreFailure : NSObject <NSCopying>
+
+@property (nonatomic, copy, readonly) NSString *domain;
+@property (nonatomic, assign, readonly) NSInteger code;
+@property (nonatomic, copy, readonly) NSString *message;
+
+- (nullable instancetype)initWithDomain:(NSString *)domain
+                                   code:(NSInteger)code
+                                message:(NSString *)message
+    NS_DESIGNATED_INITIALIZER;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+__attribute__((objc_subclassing_restricted))
+@interface PXRestoreComponentResult : NSObject <NSCopying>
+
+@property (nonatomic, assign, readonly) PXRestoreComponent component;
+@property (nonatomic, assign, readonly) PXRestoreComponentStatus status;
+@property (nonatomic, assign, readonly) NSUInteger plannedUnitCount;
+@property (nonatomic, assign, readonly) NSUInteger committedUnitCount;
+@property (nonatomic, assign, readonly) PXRestoreRollbackStatus rollbackStatus;
+@property (nonatomic, copy, readonly) NSArray<NSString *> *warnings;
+@property (nonatomic, copy, nullable, readonly) PXRestoreFailure *failure;
+
+- (nullable instancetype)initWithComponent:(PXRestoreComponent)component
+                                    status:(PXRestoreComponentStatus)status
+                          plannedUnitCount:(NSUInteger)plannedUnitCount
+                        committedUnitCount:(NSUInteger)committedUnitCount
+                            rollbackStatus:(PXRestoreRollbackStatus)rollbackStatus
+                                  warnings:(NSArray<NSString *> *)warnings
+                                   failure:(nullable PXRestoreFailure *)failure
+    NS_DESIGNATED_INITIALIZER;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+__attribute__((objc_subclassing_restricted))
+@interface PXRestoreResult : NSObject <NSCopying>
+
+@property (nonatomic, assign, readonly) PXRestoreComponent requestedComponents;
+@property (nonatomic, copy, readonly) NSArray<PXRestoreComponentResult *> *componentResults;
+@property (nonatomic, assign, readonly) PXRestoreComponent succeededComponents;
+@property (nonatomic, assign, readonly) PXRestoreComponent skippedComponents;
+@property (nonatomic, assign, readonly) PXRestoreComponent notAttemptedComponents;
+@property (nonatomic, assign, readonly) PXRestoreComponent failedComponents;
+@property (nonatomic, copy, readonly) NSArray<NSString *> *warnings;
+@property (nonatomic, assign, readonly) BOOL hasWarnings;
+@property (nonatomic, assign, readonly) BOOL hasFailures;
+@property (nonatomic, assign, readonly) BOOL hasIncompleteRollback;
+@property (nonatomic, assign, readonly) BOOL allRequestedComponentsSucceeded;
+
+- (nullable instancetype)initWithRequestedComponents:(PXRestoreComponent)requestedComponents
+                                    componentResults:(NSArray<PXRestoreComponentResult *> *)componentResults
+                                            warnings:(NSArray<NSString *> *)warnings
+    NS_DESIGNATED_INITIALIZER;
+
+- (nullable PXRestoreComponentResult *)componentResultForComponent:(PXRestoreComponent)component;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
--- a/PXRestoreResult.m
+++ b/PXRestoreResult.m
@@ -0,0 +1,422 @@
+#import "PXRestoreResult.h"
+
+static const NSUInteger PXRestoreMaximumStringBytes = 4096;
+static const NSUInteger PXRestoreMaximumDomainBytes = 255;
+static const NSUInteger PXRestoreMaximumWarnings = 4096;
+static const NSUInteger PXRestoreMaximumPlannedUnits = 4096;
+
+static const PXRestoreComponent PXRestoreCanonicalComponents[] = {
+    PXRestoreComponentApplicationData,
+    PXRestoreComponentProfileAppData,
+    PXRestoreComponentGlobalSafari,
+    PXRestoreComponentAppGroups,
+    PXRestoreComponentSystemGlobal,
+    PXRestoreComponentSharedSystemDatabases,
+    PXRestoreComponentPreferences,
+    PXRestoreComponentKeychain,
+};
+
+static BOOL PXRestoreStringIsValid(NSString *value, NSUInteger maximumUTF8Bytes) {
+    if (![value isKindOfClass:[NSString class]] || value.length == 0) {
+        return NO;
+    }
+    for (NSUInteger index = 0; index < value.length; index++) {
+        if ([value characterAtIndex:index] == 0) {
+            return NO;
+        }
+    }
+    NSData *bytes = [value dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
+    return bytes != nil && bytes.length > 0 && bytes.length <= maximumUTF8Bytes;
+}
+
+static NSArray<NSString *> *PXRestoreCopyWarnings(NSArray<NSString *> *warnings) {
+    if (![warnings isKindOfClass:[NSArray class]] || warnings.count > PXRestoreMaximumWarnings) {
+        return nil;
+    }
+    NSMutableArray<NSString *> *copied = [NSMutableArray arrayWithCapacity:warnings.count];
+    for (id value in warnings) {
+        if (!PXRestoreStringIsValid(value, PXRestoreMaximumStringBytes)) {
+            return nil;
+        }
+        [copied addObject:[(NSString *)value copy]];
+    }
+    return [copied copy];
+}
+
+static BOOL PXRestoreComponentIsKnownSingleBit(PXRestoreComponent component) {
+    NSUInteger value = (NSUInteger)component;
+    return value != 0 &&
+           (value & (value - 1)) == 0 &&
+           (value & ~(NSUInteger)PXRestoreComponentAll) == 0;
+}
+
+static BOOL PXRestoreComponentStatusIsKnown(PXRestoreComponentStatus status) {
+    switch (status) {
+        case PXRestoreComponentStatusSkipped:
+        case PXRestoreComponentStatusNotAttempted:
+        case PXRestoreComponentStatusSucceeded:
+        case PXRestoreComponentStatusFailed:
+            return YES;
+    }
+    return NO;
+}
+
+static BOOL PXRestoreRollbackStatusIsKnown(PXRestoreRollbackStatus status) {
+    switch (status) {
+        case PXRestoreRollbackStatusNotPerformed:
+        case PXRestoreRollbackStatusCompleted:
+        case PXRestoreRollbackStatusIncomplete:
+            return YES;
+    }
+    return NO;
+}
+
+static NSUInteger PXRestoreHashCombine(NSUInteger seed, NSUInteger value) {
+    return seed ^ (value + (NSUInteger)0x9e3779b9 + (seed << 6) + (seed >> 2));
+}
+
+@implementation PXRestoreFailure {
+    NSString *_domain;
+    NSInteger _code;
+    NSString *_message;
+}
+
+- (nullable instancetype)initWithDomain:(NSString *)domain
+                                   code:(NSInteger)code
+                                message:(NSString *)message {
+    if (!PXRestoreStringIsValid(domain, PXRestoreMaximumDomainBytes) ||
+        !PXRestoreStringIsValid(message, PXRestoreMaximumStringBytes)) {
+        return nil;
+    }
+    self = [super init];
+    if (self) {
+        _domain = [domain copy];
+        _code = code;
+        _message = [message copy];
+    }
+    return self;
+}
+
+- (NSString *)domain { return _domain; }
+- (NSInteger)code { return _code; }
+- (NSString *)message { return _message; }
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
+    if (![object isKindOfClass:[PXRestoreFailure class]]) {
+        return NO;
+    }
+    PXRestoreFailure *other = object;
+    return self.code == other.code &&
+           [self.domain isEqualToString:other.domain] &&
+           [self.message isEqualToString:other.message];
+}
+
+- (NSUInteger)hash {
+    NSUInteger value = self.domain.hash;
+    value = PXRestoreHashCombine(value, (NSUInteger)self.code);
+    return PXRestoreHashCombine(value, self.message.hash);
+}
+
+@end
+
+@implementation PXRestoreComponentResult {
+    PXRestoreComponent _component;
+    PXRestoreComponentStatus _status;
+    NSUInteger _plannedUnitCount;
+    NSUInteger _committedUnitCount;
+    PXRestoreRollbackStatus _rollbackStatus;
+    NSArray<NSString *> *_warnings;
+    PXRestoreFailure *_failure;
+}
+
+- (nullable instancetype)initWithComponent:(PXRestoreComponent)component
+                                    status:(PXRestoreComponentStatus)status
+                          plannedUnitCount:(NSUInteger)plannedUnitCount
+                        committedUnitCount:(NSUInteger)committedUnitCount
+                            rollbackStatus:(PXRestoreRollbackStatus)rollbackStatus
+                                  warnings:(NSArray<NSString *> *)warnings
+                                   failure:(nullable PXRestoreFailure *)failure {
+    if (!PXRestoreComponentIsKnownSingleBit(component) ||
+        !PXRestoreComponentStatusIsKnown(status) ||
+        !PXRestoreRollbackStatusIsKnown(rollbackStatus) ||
+        plannedUnitCount > PXRestoreMaximumPlannedUnits ||
+        (failure && ![failure isKindOfClass:[PXRestoreFailure class]])) {
+        return nil;
+    }
+    NSArray<NSString *> *copiedWarnings = PXRestoreCopyWarnings(warnings);
+    if (!copiedWarnings) {
+        return nil;
+    }
+
+    BOOL valid = NO;
+    switch (status) {
+        case PXRestoreComponentStatusSkipped:
+            valid = plannedUnitCount == 0 &&
+                    committedUnitCount == 0 &&
+                    rollbackStatus == PXRestoreRollbackStatusNotPerformed &&
+                    copiedWarnings.count == 0 &&
+                    failure == nil;
+            break;
+        case PXRestoreComponentStatusNotAttempted:
+            valid = plannedUnitCount >= 1 &&
+                    committedUnitCount == 0 &&
+                    rollbackStatus == PXRestoreRollbackStatusNotPerformed &&
+                    failure == nil;
+            break;
+        case PXRestoreComponentStatusSucceeded:
+            valid = plannedUnitCount >= 1 &&
+                    committedUnitCount == plannedUnitCount &&
+                    rollbackStatus == PXRestoreRollbackStatusNotPerformed &&
+                    failure == nil;
+            break;
+        case PXRestoreComponentStatusFailed:
+            valid = plannedUnitCount >= 1 &&
+                    committedUnitCount == 0 &&
+                    failure != nil;
+            break;
+    }
+    if (!valid) {
+        return nil;
+    }
+
+    self = [super init];
+    if (self) {
+        _component = component;
+        _status = status;
+        _plannedUnitCount = plannedUnitCount;
+        _committedUnitCount = committedUnitCount;
+        _rollbackStatus = rollbackStatus;
+        _warnings = copiedWarnings;
+        _failure = [failure copy];
+    }
+    return self;
+}
+
+- (PXRestoreComponent)component { return _component; }
+- (PXRestoreComponentStatus)status { return _status; }
+- (NSUInteger)plannedUnitCount { return _plannedUnitCount; }
+- (NSUInteger)committedUnitCount { return _committedUnitCount; }
+- (PXRestoreRollbackStatus)rollbackStatus { return _rollbackStatus; }
+- (NSArray<NSString *> *)warnings { return _warnings; }
+- (PXRestoreFailure *)failure { return _failure; }
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
+    if (![object isKindOfClass:[PXRestoreComponentResult class]]) {
+        return NO;
+    }
+    PXRestoreComponentResult *other = object;
+    return self.component == other.component &&
+           self.status == other.status &&
+           self.plannedUnitCount == other.plannedUnitCount &&
+           self.committedUnitCount == other.committedUnitCount &&
+           self.rollbackStatus == other.rollbackStatus &&
+           [self.warnings isEqualToArray:other.warnings] &&
+           ((self.failure == nil && other.failure == nil) ||
+            [self.failure isEqual:other.failure]);
+}
+
+- (NSUInteger)hash {
+    NSUInteger value = (NSUInteger)self.component;
+    value = PXRestoreHashCombine(value, (NSUInteger)self.status);
+    value = PXRestoreHashCombine(value, self.plannedUnitCount);
+    value = PXRestoreHashCombine(value, self.committedUnitCount);
+    value = PXRestoreHashCombine(value, (NSUInteger)self.rollbackStatus);
+    value = PXRestoreHashCombine(value, self.warnings.hash);
+    return PXRestoreHashCombine(value, self.failure.hash);
+}
+
+@end
+
+@implementation PXRestoreResult {
+    PXRestoreComponent _requestedComponents;
+    NSArray<PXRestoreComponentResult *> *_componentResults;
+    PXRestoreComponent _succeededComponents;
+    PXRestoreComponent _skippedComponents;
+    PXRestoreComponent _notAttemptedComponents;
+    PXRestoreComponent _failedComponents;
+    NSArray<NSString *> *_warnings;
+    BOOL _hasWarnings;
+    BOOL _hasFailures;
+    BOOL _hasIncompleteRollback;
+    BOOL _allRequestedComponentsSucceeded;
+}
+
+- (nullable instancetype)initWithRequestedComponents:(PXRestoreComponent)requestedComponents
+                                    componentResults:(NSArray<PXRestoreComponentResult *> *)componentResults
+                                            warnings:(NSArray<NSString *> *)warnings {
+    if (((NSUInteger)requestedComponents & ~(NSUInteger)PXRestoreComponentAll) != 0 ||
+        (requestedComponents & PXRestoreComponentApplicationData) == 0 ||
+        ![componentResults isKindOfClass:[NSArray class]] ||
+        componentResults.count != 8) {
+        return nil;
+    }
+    NSArray<NSString *> *copiedWarnings = PXRestoreCopyWarnings(warnings);
+    if (!copiedWarnings) {
+        return nil;
+    }
+
+    NSMutableDictionary<NSNumber *, PXRestoreComponentResult *> *byComponent =
+        [NSMutableDictionary dictionaryWithCapacity:8];
+    PXRestoreComponent succeeded = 0;
+    PXRestoreComponent skipped = 0;
+    PXRestoreComponent notAttempted = 0;
+    PXRestoreComponent failed = 0;
+    BOOL incompleteRollback = NO;
+
+    for (id value in componentResults) {
+        if (![value isKindOfClass:[PXRestoreComponentResult class]]) {
+            return nil;
+        }
+        PXRestoreComponentResult *result = value;
+        if (!PXRestoreComponentIsKnownSingleBit(result.component) ||
+            byComponent[@(result.component)] != nil) {
+            return nil;
+        }
+        BOOL requested = (requestedComponents & result.component) != 0;
+        if ((requested && result.status == PXRestoreComponentStatusSkipped) ||
+            (!requested && result.status != PXRestoreComponentStatusSkipped)) {
+            return nil;
+        }
+        byComponent[@(result.component)] = result;
+        switch (result.status) {
+            case PXRestoreComponentStatusSkipped:
+                skipped |= result.component;
+                break;
+            case PXRestoreComponentStatusNotAttempted:
+                notAttempted |= result.component;
+                break;
+            case PXRestoreComponentStatusSucceeded:
+                succeeded |= result.component;
+                break;
+            case PXRestoreComponentStatusFailed:
+                failed |= result.component;
+                break;
+        }
+        if (result.rollbackStatus == PXRestoreRollbackStatusIncomplete) {
+            incompleteRollback = YES;
+        }
+    }
+
+    NSMutableArray<PXRestoreComponentResult *> *canonical =
+        [NSMutableArray arrayWithCapacity:8];
+    for (NSUInteger index = 0; index < 8; index++) {
+        PXRestoreComponent component = PXRestoreCanonicalComponents[index];
+        PXRestoreComponentResult *result = byComponent[@(component)];
+        if (!result) {
+            return nil;
+        }
+        [canonical addObject:result];
+    }
+
+    PXRestoreComponent unionMask = succeeded | skipped | notAttempted | failed;
+    BOOL masksDisjoint =
+        (succeeded & skipped) == 0 &&
+        (succeeded & notAttempted) == 0 &&
+        (succeeded & failed) == 0 &&
+        (skipped & notAttempted) == 0 &&
+        (skipped & failed) == 0 &&
+        (notAttempted & failed) == 0;
+    if (!masksDisjoint || unionMask != PXRestoreComponentAll ||
+        requestedComponents != (succeeded | notAttempted | failed) ||
+        skipped != (PXRestoreComponentAll & ~requestedComponents)) {
+        return nil;
+    }
+
+    self = [super init];
+    if (self) {
+        _requestedComponents = requestedComponents;
+        _componentResults = [canonical copy];
+        _succeededComponents = succeeded;
+        _skippedComponents = skipped;
+        _notAttemptedComponents = notAttempted;
+        _failedComponents = failed;
+        _warnings = copiedWarnings;
+        _hasWarnings = copiedWarnings.count > 0;
+        _hasFailures = failed != 0;
+        _hasIncompleteRollback = incompleteRollback;
+        _allRequestedComponentsSucceeded = succeeded == requestedComponents;
+    }
+    return self;
+}
+
+- (PXRestoreComponent)requestedComponents { return _requestedComponents; }
+- (NSArray<PXRestoreComponentResult *> *)componentResults { return _componentResults; }
+- (PXRestoreComponent)succeededComponents { return _succeededComponents; }
+- (PXRestoreComponent)skippedComponents { return _skippedComponents; }
+- (PXRestoreComponent)notAttemptedComponents { return _notAttemptedComponents; }
+- (PXRestoreComponent)failedComponents { return _failedComponents; }
+- (NSArray<NSString *> *)warnings { return _warnings; }
+- (BOOL)hasWarnings { return _hasWarnings; }
+- (BOOL)hasFailures { return _hasFailures; }
+- (BOOL)hasIncompleteRollback { return _hasIncompleteRollback; }
+- (BOOL)allRequestedComponentsSucceeded { return _allRequestedComponentsSucceeded; }
+
+- (nullable PXRestoreComponentResult *)componentResultForComponent:(PXRestoreComponent)component {
+    if (!PXRestoreComponentIsKnownSingleBit(component)) {
+        return nil;
+    }
+    for (PXRestoreComponentResult *result in self.componentResults) {
+        if (result.component == component) {
+            return result;
+        }
+    }
+    return nil;
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
+    if (![object isKindOfClass:[PXRestoreResult class]]) {
+        return NO;
+    }
+    PXRestoreResult *other = object;
+    return self.requestedComponents == other.requestedComponents &&
+           self.succeededComponents == other.succeededComponents &&
+           self.skippedComponents == other.skippedComponents &&
+           self.notAttemptedComponents == other.notAttemptedComponents &&
+           self.failedComponents == other.failedComponents &&
+           self.hasWarnings == other.hasWarnings &&
+           self.hasFailures == other.hasFailures &&
+           self.hasIncompleteRollback == other.hasIncompleteRollback &&
+           self.allRequestedComponentsSucceeded == other.allRequestedComponentsSucceeded &&
+           [self.componentResults isEqualToArray:other.componentResults] &&
+           [self.warnings isEqualToArray:other.warnings];
+}
+
+- (NSUInteger)hash {
+    NSUInteger value = (NSUInteger)self.requestedComponents;
+    value = PXRestoreHashCombine(value, self.componentResults.hash);
+    value = PXRestoreHashCombine(value, (NSUInteger)self.succeededComponents);
+    value = PXRestoreHashCombine(value, (NSUInteger)self.skippedComponents);
+    value = PXRestoreHashCombine(value, (NSUInteger)self.notAttemptedComponents);
+    value = PXRestoreHashCombine(value, (NSUInteger)self.failedComponents);
+    value = PXRestoreHashCombine(value, self.warnings.hash);
+    value = PXRestoreHashCombine(value, self.hasWarnings ? 1 : 0);
+    value = PXRestoreHashCombine(value, self.hasFailures ? 1 : 0);
+    value = PXRestoreHashCombine(value, self.hasIncompleteRollback ? 1 : 0);
+    return PXRestoreHashCombine(value, self.allRequestedComponentsSucceeded ? 1 : 0);
+}
+
+@end
--- a/AppDataBackupManager.h
+++ b/AppDataBackupManager.h
@@ -1,4 +1,5 @@
 #import <Foundation/Foundation.h>
+#import "PXRestoreResult.h"

 NS_ASSUME_NONNULL_BEGIN

@@ -11,10 +12,6 @@
 @interface PXBackupResult : NSObject
 @property (nonatomic, copy) NSString *backupDirectory;
 @property (nonatomic, copy) NSString *manifestPath;
-@property (nonatomic, copy) NSArray<NSString *> *warnings;
-@end
-
-@interface PXRestoreResult : NSObject
 @property (nonatomic, copy) NSArray<NSString *> *warnings;
 @end

--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -205,7 +205,226 @@
 @implementation PXBackupResult
 @end

-@implementation PXRestoreResult
+static const PXRestoreComponent PXRestoreManagerCanonicalComponents[] = {
+    PXRestoreComponentApplicationData,
+    PXRestoreComponentProfileAppData,
+    PXRestoreComponentGlobalSafari,
+    PXRestoreComponentAppGroups,
+    PXRestoreComponentSystemGlobal,
+    PXRestoreComponentSharedSystemDatabases,
+    PXRestoreComponentPreferences,
+    PXRestoreComponentKeychain,
+};
+
+static NSArray<NSString *> *PXRestoreWarningsSuffix(NSArray<NSString *> *warnings,
+                                                     NSUInteger startIndex) {
+    if (![warnings isKindOfClass:[NSArray class]] || startIndex > warnings.count) {
+        return @[];
+    }
+    NSRange range = NSMakeRange(startIndex, warnings.count - startIndex);
+    return [[warnings subarrayWithRange:range] copy];
+}
+
+static PXRestoreRollbackStatus PXRestoreRollbackStatusFromFlags(BOOL rollbackPerformed,
+                                                                 BOOL rollbackComplete) {
+    if (!rollbackPerformed) {
+        return PXRestoreRollbackStatusNotPerformed;
+    }
+    return rollbackComplete
+        ? PXRestoreRollbackStatusCompleted
+        : PXRestoreRollbackStatusIncomplete;
+}
+
+static PXRestoreFailure *PXRestoreFailureSnapshotFromError(NSError *error) {
+    if (![error isKindOfClass:[NSError class]]) {
+        return nil;
+    }
+    return [[PXRestoreFailure alloc] initWithDomain:error.domain
+                                               code:error.code
+                                            message:error.localizedDescription];
+}
+
+@interface PXRestoreResultAccumulator : NSObject
+
+@property (nonatomic, assign, readonly) PXRestoreComponent requestedComponents;
+
+- (nullable instancetype)initWithRequestedComponents:(PXRestoreComponent)requestedComponents
+                                    plannedUnitCounts:(NSDictionary<NSNumber *, NSNumber *> *)plannedUnitCounts;
+- (BOOL)markComponentSucceeded:(PXRestoreComponent)component
+                       warnings:(NSArray<NSString *> *)warnings;
+- (BOOL)markComponentFailed:(PXRestoreComponent)component
+                    failure:(PXRestoreFailure *)failure
+             rollbackStatus:(PXRestoreRollbackStatus)rollbackStatus
+                   warnings:(NSArray<NSString *> *)warnings;
+- (BOOL)appendWarnings:(NSArray<NSString *> *)warnings
+           toComponent:(PXRestoreComponent)component;
+- (nullable PXRestoreResult *)resultWithAggregateWarnings:(NSArray<NSString *> *)warnings;
+
+@end
+
+@implementation PXRestoreResultAccumulator {
+    PXRestoreComponent _requestedComponents;
+    NSDictionary<NSNumber *, NSNumber *> *_plannedUnitCounts;
+    NSMutableDictionary<NSNumber *, NSNumber *> *_statuses;
+    NSMutableDictionary<NSNumber *, NSNumber *> *_rollbackStatuses;
+    NSMutableDictionary<NSNumber *, NSMutableArray<NSString *> *> *_componentWarnings;
+    NSMutableDictionary<NSNumber *, PXRestoreFailure *> *_failures;
+}
+
+- (nullable instancetype)initWithRequestedComponents:(PXRestoreComponent)requestedComponents
+                                    plannedUnitCounts:(NSDictionary<NSNumber *, NSNumber *> *)plannedUnitCounts {
+    if (((NSUInteger)requestedComponents & ~(NSUInteger)PXRestoreComponentAll) != 0 ||
+        (requestedComponents & PXRestoreComponentApplicationData) == 0 ||
+        ![plannedUnitCounts isKindOfClass:[NSDictionary class]] ||
+        plannedUnitCounts.count != 8) {
+        return nil;
+    }
+
+    NSMutableDictionary<NSNumber *, NSNumber *> *copiedCounts =
+        [NSMutableDictionary dictionaryWithCapacity:8];
+    NSMutableDictionary<NSNumber *, NSNumber *> *statuses =
+        [NSMutableDictionary dictionaryWithCapacity:8];
+    NSMutableDictionary<NSNumber *, NSNumber *> *rollbackStatuses =
+        [NSMutableDictionary dictionaryWithCapacity:8];
+    NSMutableDictionary<NSNumber *, NSMutableArray<NSString *> *> *componentWarnings =
+        [NSMutableDictionary dictionaryWithCapacity:8];
+
+    for (NSUInteger index = 0; index < 8; index++) {
+        PXRestoreComponent component = PXRestoreManagerCanonicalComponents[index];
+        NSNumber *key = @(component);
+        NSNumber *countNumber = plannedUnitCounts[key];
+        if (![countNumber isKindOfClass:[NSNumber class]]) {
+            return nil;
+        }
+        NSUInteger count = countNumber.unsignedIntegerValue;
+        BOOL requested = (requestedComponents & component) != 0;
+        if ((requested && (count == 0 || count > 4096)) ||
+            (!requested && count != 0)) {
+            return nil;
+        }
+        copiedCounts[key] = @(count);
+        statuses[key] = @(requested
+            ? PXRestoreComponentStatusNotAttempted
+            : PXRestoreComponentStatusSkipped);
+        rollbackStatuses[key] = @(PXRestoreRollbackStatusNotPerformed);
+        componentWarnings[key] = [NSMutableArray array];
+    }
+
+    self = [super init];
+    if (self) {
+        _requestedComponents = requestedComponents;
+        _plannedUnitCounts = [copiedCounts copy];
+        _statuses = statuses;
+        _rollbackStatuses = rollbackStatuses;
+        _componentWarnings = componentWarnings;
+        _failures = [NSMutableDictionary dictionaryWithCapacity:8];
+    }
+    return self;
+}
+
+- (PXRestoreComponent)requestedComponents {
+    return _requestedComponents;
+}
+
+- (BOOL)componentIsRequested:(PXRestoreComponent)component {
+    return component != 0 &&
+           ((NSUInteger)component & ((NSUInteger)component - 1)) == 0 &&
+           ((NSUInteger)component & ~(NSUInteger)PXRestoreComponentAll) == 0 &&
+           (_requestedComponents & component) != 0;
+}
+
+- (BOOL)replaceWarnings:(NSArray<NSString *> *)warnings
+            forComponent:(PXRestoreComponent)component {
+    if (![warnings isKindOfClass:[NSArray class]]) {
+        return NO;
+    }
+    NSMutableArray<NSString *> *copied = [NSMutableArray arrayWithCapacity:warnings.count];
+    for (id warning in warnings) {
+        if (![warning isKindOfClass:[NSString class]]) {
+            return NO;
+        }
+        [copied addObject:[(NSString *)warning copy]];
+    }
+    _componentWarnings[@(component)] = copied;
+    return YES;
+}
+
+- (BOOL)markComponentSucceeded:(PXRestoreComponent)component
+                       warnings:(NSArray<NSString *> *)warnings {
+    NSNumber *key = @(component);
+    if (![self componentIsRequested:component] ||
+        [_statuses[key] integerValue] != PXRestoreComponentStatusNotAttempted ||
+        ![self replaceWarnings:warnings forComponent:component]) {
+        return NO;
+    }
+    _statuses[key] = @(PXRestoreComponentStatusSucceeded);
+    _rollbackStatuses[key] = @(PXRestoreRollbackStatusNotPerformed);
+    [_failures removeObjectForKey:key];
+    return YES;
+}
+
+- (BOOL)markComponentFailed:(PXRestoreComponent)component
+                    failure:(PXRestoreFailure *)failure
+             rollbackStatus:(PXRestoreRollbackStatus)rollbackStatus
+                   warnings:(NSArray<NSString *> *)warnings {
+    NSNumber *key = @(component);
+    if (![self componentIsRequested:component] ||
+        ![failure isKindOfClass:[PXRestoreFailure class]] ||
+        (rollbackStatus != PXRestoreRollbackStatusNotPerformed &&
+         rollbackStatus != PXRestoreRollbackStatusCompleted &&
+         rollbackStatus != PXRestoreRollbackStatusIncomplete) ||
+        [_statuses[key] integerValue] != PXRestoreComponentStatusNotAttempted ||
+        ![self replaceWarnings:warnings forComponent:component]) {
+        return NO;
+    }
+    _statuses[key] = @(PXRestoreComponentStatusFailed);
+    _rollbackStatuses[key] = @(rollbackStatus);
+    _failures[key] = [failure copy];
+    return YES;
+}
+
+- (BOOL)appendWarnings:(NSArray<NSString *> *)warnings
+           toComponent:(PXRestoreComponent)component {
+    NSNumber *key = @(component);
+    if (![warnings isKindOfClass:[NSArray class]] || !_componentWarnings[key]) {
+        return NO;
+    }
+    for (id warning in warnings) {
+        if (![warning isKindOfClass:[NSString class]]) {
+            return NO;
+        }
+        [_componentWarnings[key] addObject:[(NSString *)warning copy]];
+    }
+    return YES;
+}
+
+- (nullable PXRestoreResult *)resultWithAggregateWarnings:(NSArray<NSString *> *)warnings {
+    NSMutableArray<PXRestoreComponentResult *> *results = [NSMutableArray arrayWithCapacity:8];
+    for (NSUInteger index = 0; index < 8; index++) {
+        PXRestoreComponent component = PXRestoreManagerCanonicalComponents[index];
+        NSNumber *key = @(component);
+        PXRestoreComponentStatus status = (PXRestoreComponentStatus)[_statuses[key] integerValue];
+        NSUInteger planned = [_plannedUnitCounts[key] unsignedIntegerValue];
+        NSUInteger committed = status == PXRestoreComponentStatusSucceeded ? planned : 0;
+        PXRestoreComponentResult *componentResult =
+            [[PXRestoreComponentResult alloc]
+                initWithComponent:component
+                           status:status
+                 plannedUnitCount:planned
+               committedUnitCount:committed
+                   rollbackStatus:(PXRestoreRollbackStatus)[_rollbackStatuses[key] integerValue]
+                         warnings:_componentWarnings[key]
+                          failure:_failures[key]];
+        if (!componentResult) {
+            return nil;
+        }
+        [results addObject:componentResult];
+    }
+    return [[PXRestoreResult alloc] initWithRequestedComponents:_requestedComponents
+                                               componentResults:results
+                                                       warnings:warnings];
+}
+
 @end

 @implementation AppDataBackupManager
@@ -2278,6 +2497,75 @@
             return;
         }

+        NSMutableArray<PXRestorePlanSystemGlobalItem *> *effectiveSystemGlobalItemsBuilder =
+            [NSMutableArray arrayWithCapacity:restorePlan.systemGlobalItems.count];
+        for (PXRestorePlanSystemGlobalItem *plannedItem in restorePlan.systemGlobalItems) {
+            BOOL duplicateGlobalSafari =
+                [bundleID isEqualToString:@"com.apple.mobilesafari"] &&
+                [plannedItem.librarySubdirectory isEqualToString:@"Safari"] &&
+                restorePlan.includesGlobalSafari;
+            if (!duplicateGlobalSafari) {
+                [effectiveSystemGlobalItemsBuilder addObject:plannedItem];
+            }
+        }
+        NSArray<PXRestorePlanSystemGlobalItem *> *effectiveSystemGlobalItems =
+            [effectiveSystemGlobalItemsBuilder copy];
+
+        PXRestoreComponent requestedComponents = PXRestoreComponentApplicationData;
+        if (restorePlan.includesProfileAppData) requestedComponents |= PXRestoreComponentProfileAppData;
+        if (restorePlan.includesGlobalSafari) requestedComponents |= PXRestoreComponentGlobalSafari;
+        if (appGroupTargetPlan.targets.count > 0) requestedComponents |= PXRestoreComponentAppGroups;
+        if (effectiveSystemGlobalItems.count > 0) requestedComponents |= PXRestoreComponentSystemGlobal;
+        if (restorePlan.sharedDatabaseItems.count > 0) requestedComponents |= PXRestoreComponentSharedSystemDatabases;
+        if (restorePlan.includesPreferences) requestedComponents |= PXRestoreComponentPreferences;
+        if (restorePlan.includesKeychain) requestedComponents |= PXRestoreComponentKeychain;
+
+        NSDictionary<NSNumber *, NSNumber *> *plannedUnitCounts = @{
+            @(PXRestoreComponentApplicationData): @1,
+            @(PXRestoreComponentProfileAppData): @(restorePlan.includesProfileAppData ? 1 : 0),
+            @(PXRestoreComponentGlobalSafari): @(restorePlan.includesGlobalSafari ? 1 : 0),
+            @(PXRestoreComponentAppGroups): @(appGroupTargetPlan.targets.count),
+            @(PXRestoreComponentSystemGlobal): @(effectiveSystemGlobalItems.count),
+            @(PXRestoreComponentSharedSystemDatabases): @(restorePlan.sharedDatabaseItems.count),
+            @(PXRestoreComponentPreferences): @(restorePlan.includesPreferences ? 1 : 0),
+            @(PXRestoreComponentKeychain): @(restorePlan.includesKeychain ? 1 : 0),
+        };
+        __attribute__((objc_precise_lifetime))
+        PXRestoreResultAccumulator *resultAccumulator =
+            [[PXRestoreResultAccumulator alloc] initWithRequestedComponents:requestedComponents
+                                                          plannedUnitCounts:plannedUnitCounts];
+        if (!resultAccumulator) {
+            NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
+                                               code:321
+                                           userInfo:@{NSLocalizedDescriptionKey: @"Structured Restore result could not be constructed"}];
+            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            return;
+        }
+
+        void (^completeStructuredFailure)(PXRestoreComponent,
+                                          NSError *,
+                                          PXRestoreRollbackStatus,
+                                          NSUInteger) =
+            ^(PXRestoreComponent component,
+              NSError *err,
+              PXRestoreRollbackStatus rollbackStatus,
+              NSUInteger warningStart) {
+                PXRestoreFailure *failure = PXRestoreFailureSnapshotFromError(err);
+                NSArray<NSString *> *componentWarnings = PXRestoreWarningsSuffix(warnings, warningStart);
+                BOOL marked = failure &&
+                    [resultAccumulator markComponentFailed:component
+                                                   failure:failure
+                                            rollbackStatus:rollbackStatus
+                                                  warnings:componentWarnings];
+                PXRestoreResult *result = marked
+                    ? [resultAccumulator resultWithAggregateWarnings:warnings]
+                    : nil;
+                NSCAssert(result != nil, @"Post-boundary Restore failure must publish a structured result");
+                dispatch_async(dispatch_get_main_queue(), ^{
+                    if (completion) completion(result, err);
+                });
+            };
+
         if (restorePlan.manifestWarningCount > 0) {
             [warnings addObject:[NSString stringWithFormat:@"Backup manifest contains %lu warning(s); review manifest before relying on full fidelity restore", (unsigned long)restorePlan.manifestWarningCount]];
         }
@@ -2286,6 +2574,8 @@
         if (manifestProfileId.length && activeProfileId.length && ![manifestProfileId isEqualToString:activeProfileId]) {
             [warnings addObject:[NSString stringWithFormat:@"Backup profileId %@ != active profileId %@", manifestProfileId, activeProfileId]];
         }
+
+        NSUInteger applicationWarningStart = warnings.count;

         PXDebugHeader(debugPre, @"Chosen Container");
         PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"chosenDataContainerPath=%@", dataContainerPath ?: @""]);
@@ -2310,7 +2600,7 @@
                                                NSLocalizedDescriptionKey: @"The accepted main archive summary is invalid.",
                                                PXMainDataStagingErrorFieldPathKey: @"$.data"
                                            }];
-            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            completeStructuredFailure(PXRestoreComponentApplicationData, err, PXRestoreRollbackStatusNotPerformed, applicationWarningStart);
             return;
         }
         NSUInteger expectedLogicalMemberCount = (NSUInteger)logicalMemberValue;
@@ -2326,7 +2616,7 @@
                                                                   NSLocalizedDescriptionKey: @"The private main-data staging workspace could not be created.",
                                                                   PXMainDataStagingErrorFieldPathKey: @"$.workspace"
                                                               }];
-            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            completeStructuredFailure(PXRestoreComponentApplicationData, err, PXRestoreRollbackStatusNotPerformed, applicationWarningStart);
             return;
         }

@@ -2339,7 +2629,7 @@
                                                                     NSLocalizedDescriptionKey: @"The private main-data staging workspace failed empty validation.",
                                                                     PXMainDataStagingErrorFieldPathKey: @"$.data"
                                                                 }];
-            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            completeStructuredFailure(PXRestoreComponentApplicationData, err, PXRestoreRollbackStatusNotPerformed, applicationWarningStart);
             return;
         }

@@ -2352,7 +2642,7 @@
             NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                code:316
                                            userInfo:@{NSLocalizedDescriptionKey: @"Failed to extract data archive to staging"}];
-            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            completeStructuredFailure(PXRestoreComponentApplicationData, err, PXRestoreRollbackStatusNotPerformed, applicationWarningStart);
             return;
         }

@@ -2370,7 +2660,7 @@
                                                                         NSLocalizedDescriptionKey: @"The extracted main-data stage failed validation.",
                                                                         PXMainDataStagingErrorFieldPathKey: @"$.data"
                                                                     }];
-            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            completeStructuredFailure(PXRestoreComponentApplicationData, err, PXRestoreRollbackStatusNotPerformed, applicationWarningStart);
             return;
         }

@@ -2394,7 +2684,7 @@
             NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                code:303
                                            userInfo:@{NSLocalizedDescriptionKey: PXExactRestoreDestinationErrorDescription}];
-            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            completeStructuredFailure(PXRestoreComponentApplicationData, err, PXRestoreRollbackStatusNotPerformed, applicationWarningStart);
             return;
         }

@@ -2413,7 +2703,7 @@
                                     NSLocalizedDescriptionKey: @"The validated main-data stage changed before transaction commit.",
                                     PXMainDataStagingErrorFieldPathKey: @"$.data"
                                 }];
-            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            completeStructuredFailure(PXRestoreComponentApplicationData, err, PXRestoreRollbackStatusNotPerformed, applicationWarningStart);
             return;
         }

@@ -2431,7 +2721,7 @@
                                            userInfo:@{
                                                NSLocalizedDescriptionKey: @"Failed to prepare transactional main-data commit"
                                            }];
-            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            completeStructuredFailure(PXRestoreComponentApplicationData, err, PXRestoreRollbackStatusNotPerformed, applicationWarningStart);
             return;
         }
         PXDebugAppendLine(debugPre,
@@ -2452,7 +2742,12 @@
                                            userInfo:@{
                                                NSLocalizedDescriptionKey: @"Failed to commit validated main-data stage transactionally"
                                            }];
-            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            completeStructuredFailure(
+                PXRestoreComponentApplicationData,
+                err,
+                PXRestoreRollbackStatusFromFlags(mainDataTransaction.rollbackPerformed,
+                                                 mainDataTransaction.rollbackComplete),
+                applicationWarningStart);
             return;
         }
         PXDebugAppendLine(debugPre, @"mainTransactionCommitted=1");
@@ -2470,6 +2765,9 @@
         if (![mainDataWorkspace cleanupWithError:&mainDataCleanupError]) {
             [warnings addObject:@"Main-data staging cleanup failed"];
         }
+        NSCAssert([resultAccumulator markComponentSucceeded:PXRestoreComponentApplicationData
+                                                   warnings:PXRestoreWarningsSuffix(warnings, applicationWarningStart)],
+                  @"ApplicationData result state must be publishable");

         // Post-restore hygiene: refresh preferences daemon caches.
         // Some apps read state via cfprefsd and may not notice external file writes immediately.
@@ -2478,6 +2776,7 @@
         // Data container restored.

         // Restore profile redirected appdata (if present)
+        NSUInteger profileWarningStart = warnings.count;
         if (restorePlan.includesProfileAppData) {
             PXMainDataStagingWorkspace *profileWorkspace = nil;
             PXValidatedMainDataStage *profileStage = nil;
@@ -2492,7 +2791,7 @@
                                                  stageOut:&profileStage
                                                     error:&profileStageError]) {
                 NSError *err = profileStageError;
-                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                completeStructuredFailure(PXRestoreComponentProfileAppData, err, PXRestoreRollbackStatusNotPerformed, profileWarningStart);
                 return;
             }

@@ -2508,7 +2807,7 @@
                                         NSLocalizedDescriptionKey: @"The profile AppData destination could not be revalidated.",
                                         PXOptionalRestoreStagingErrorFieldPathKey: @"$.profileAppData.destination"
                                     }];
-                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                completeStructuredFailure(PXRestoreComponentProfileAppData, err, PXRestoreRollbackStatusNotPerformed, profileWarningStart);
                 return;
             }
             NSError *profileItemError = nil;
@@ -2531,7 +2830,12 @@
                 NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                    code:307
                                                userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore validated profile AppData stage transactionally"}];
-                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                completeStructuredFailure(
+                    PXRestoreComponentProfileAppData,
+                    err,
+                    PXRestoreRollbackStatusFromFlags(profileTransaction.rollbackPerformed,
+                                                     profileTransaction.rollbackComplete),
+                    profileWarningStart);
                 return;
             }
             if (profileCleanupWarning) {
@@ -2543,9 +2847,13 @@
             if (!profileStagingCleaned) {
                 [warnings addObject:@"Optional-directory staging cleanup failed"];
             }
+            NSCAssert([resultAccumulator markComponentSucceeded:PXRestoreComponentProfileAppData
+                                                       warnings:PXRestoreWarningsSuffix(warnings, profileWarningStart)],
+                      @"ProfileAppData result state must be publishable");
         }

         // Restore global Safari library (if present)
+        NSUInteger safariWarningStart = warnings.count;
         if (restorePlan.includesGlobalSafari) {
             PXMainDataStagingWorkspace *safariWorkspace = nil;
             PXValidatedMainDataStage *safariStage = nil;
@@ -2560,7 +2868,7 @@
                                                  stageOut:&safariStage
                                                     error:&safariStageError]) {
                 NSError *err = safariStageError;
-                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                completeStructuredFailure(PXRestoreComponentGlobalSafari, err, PXRestoreRollbackStatusNotPerformed, safariWarningStart);
                 return;
             }

@@ -2576,7 +2884,7 @@
                                         NSLocalizedDescriptionKey: @"The global Safari destination could not be revalidated.",
                                         PXOptionalRestoreStagingErrorFieldPathKey: @"$.globalSafari.destination"
                                     }];
-                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                completeStructuredFailure(PXRestoreComponentGlobalSafari, err, PXRestoreRollbackStatusNotPerformed, safariWarningStart);
                 return;
             }
             NSError *safariItemError = nil;
@@ -2599,7 +2907,12 @@
                 NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                    code:311
                                                userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore validated global Safari stage transactionally"}];
-                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                completeStructuredFailure(
+                    PXRestoreComponentGlobalSafari,
+                    err,
+                    PXRestoreRollbackStatusFromFlags(safariTransaction.rollbackPerformed,
+                                                     safariTransaction.rollbackComplete),
+                    safariWarningStart);
                 return;
             }
             if (safariCleanupWarning) {
@@ -2611,8 +2924,12 @@
             if (!safariStagingCleaned) {
                 [warnings addObject:@"Optional-directory staging cleanup failed"];
             }
-        }
-
+            NSCAssert([resultAccumulator markComponentSucceeded:PXRestoreComponentGlobalSafari
+                                                       warnings:PXRestoreWarningsSuffix(warnings, safariWarningStart)],
+                      @"GlobalSafari result state must be publishable");
+        }
+
+        NSUInteger appGroupWarningStart = warnings.count;
         if (appGroupTargetPlan.targets.count > 0) {
             // Stage every exact physical App Group target before one transactional batch commit.
             __attribute__((objc_precise_lifetime))
@@ -2662,7 +2979,7 @@
                                                            NSLocalizedDescriptionKey: @"The accepted App Group archive summary is inconsistent.",
                                                            PXAppGroupRestoreTargetPlanErrorFieldPathKey: @"$.appGroups"
                                                        }];
-                        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                        completeStructuredFailure(PXRestoreComponentAppGroups, err, PXRestoreRollbackStatusNotPerformed, appGroupWarningStart);
                         return;
                     }
                     [targetMemberCounts addObject:@(memberCountValue)];
@@ -2691,7 +3008,7 @@
                                                 NSLocalizedDescriptionKey: @"The private App Group staging workspace could not be created.",
                                                 PXMainDataStagingErrorFieldPathKey: @"$.workspace"
                                             }];
-                        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                        completeStructuredFailure(PXRestoreComponentAppGroups, err, PXRestoreRollbackStatusNotPerformed, appGroupWarningStart);
                         return;
                     }

@@ -2707,7 +3024,7 @@
                                                 NSLocalizedDescriptionKey: @"The private App Group staging workspace failed empty validation.",
                                                 PXMainDataStagingErrorFieldPathKey: @"$.data"
                                             }];
-                        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                        completeStructuredFailure(PXRestoreComponentAppGroups, err, PXRestoreRollbackStatusNotPerformed, appGroupWarningStart);
                         return;
                     }

@@ -2724,7 +3041,7 @@
                                                        userInfo:@{
                                                            NSLocalizedDescriptionKey: @"Failed to extract App Group archive to staging"
                                                        }];
-                        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                        completeStructuredFailure(PXRestoreComponentAppGroups, err, PXRestoreRollbackStatusNotPerformed, appGroupWarningStart);
                         return;
                     }

@@ -2745,7 +3062,7 @@
                                                 NSLocalizedDescriptionKey: @"The extracted App Group stage failed validation.",
                                                 PXMainDataStagingErrorFieldPathKey: @"$.data"
                                             }];
-                        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                        completeStructuredFailure(PXRestoreComponentAppGroups, err, PXRestoreRollbackStatusNotPerformed, appGroupWarningStart);
                         return;
                     }

@@ -2765,7 +3082,7 @@
                                                            NSLocalizedDescriptionKey: @"App Group archives for one physical target are inconsistent.",
                                                            PXAppGroupRestoreTargetPlanErrorFieldPathKey: @"$.appGroups"
                                                        }];
-                        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                        completeStructuredFailure(PXRestoreComponentAppGroups, err, PXRestoreRollbackStatusNotPerformed, appGroupWarningStart);
                         return;
                     }

@@ -2780,7 +3097,7 @@
                                                 NSLocalizedDescriptionKey: @"A duplicate App Group staging workspace could not be cleaned safely.",
                                                 PXMainDataStagingErrorFieldPathKey: @"$.workspace"
                                             }];
-                        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                        completeStructuredFailure(PXRestoreComponentAppGroups, err, PXRestoreRollbackStatusNotPerformed, appGroupWarningStart);
                         return;
                     }
                 }
@@ -2794,7 +3111,7 @@
                                                        NSLocalizedDescriptionKey: @"The accepted App Group restore target has no validated source.",
                                                        PXAppGroupRestoreTargetPlanErrorFieldPathKey: @"$.appGroups"
                                                    }];
-                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    completeStructuredFailure(PXRestoreComponentAppGroups, err, PXRestoreRollbackStatusNotPerformed, appGroupWarningStart);
                     return;
                 }

@@ -2810,7 +3127,7 @@
                                                userInfo:@{
                                                    NSLocalizedDescriptionKey: @"Failed to commit validated App Group stages transactionally"
                                                }];
-                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                completeStructuredFailure(PXRestoreComponentAppGroups, err, PXRestoreRollbackStatusNotPerformed, appGroupWarningStart);
                 return;
             }

@@ -2835,7 +3152,7 @@
                                                            ? @"Exact App Group restore target could not be revalidated safely"
                                                            : @"Failed to commit validated App Group stages transactionally"
                                                }];
-                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                completeStructuredFailure(PXRestoreComponentAppGroups, err, PXRestoreRollbackStatusNotPerformed, appGroupWarningStart);
                 return;
             }

@@ -2864,7 +3181,12 @@
                                                userInfo:@{
                                                    NSLocalizedDescriptionKey: @"Failed to commit validated App Group stages transactionally"
                                                }];
-                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                completeStructuredFailure(
+                    PXRestoreComponentAppGroups,
+                    err,
+                    PXRestoreRollbackStatusFromFlags(appGroupTransaction.rollbackPerformed,
+                                                     appGroupTransaction.rollbackComplete),
+                    appGroupWarningStart);
                 return;
             }

@@ -2879,11 +3201,15 @@
             if (!appGroupStagingCleanupComplete) {
                 [warnings addObject:@"App Group staging cleanup failed"];
             }
+            NSCAssert([resultAccumulator markComponentSucceeded:PXRestoreComponentAppGroups
+                                                       warnings:PXRestoreWarningsSuffix(warnings, appGroupWarningStart)],
+                      @"AppGroups result state must be publishable");

         }

         // Restore generic system app global Library folders (if present)
-        if (restorePlan.systemGlobalItems.count) {
+        NSUInteger systemGlobalWarningStart = warnings.count;
+        if (effectiveSystemGlobalItems.count > 0) {
             NSMutableArray<PXMainDataStagingWorkspace *> *systemWorkspaces = [NSMutableArray array];
             NSMutableArray<PXOptionalRestoreTransactionItem *> *systemItems = [NSMutableArray array];
             NSMutableArray<NSString *> *systemDestinations = [NSMutableArray array];
@@ -2895,13 +3221,8 @@
                 }
                 return complete;
             };
-            for (PXRestorePlanSystemGlobalItem *plannedItem in restorePlan.systemGlobalItems) {
+            for (PXRestorePlanSystemGlobalItem *plannedItem in effectiveSystemGlobalItems) {
                 NSString *subdir = plannedItem.librarySubdirectory;
-                if ([bundleID isEqualToString:@"com.apple.mobilesafari"] &&
-                    [subdir isEqualToString:@"Safari"] &&
-                    restorePlan.includesGlobalSafari) {
-                    continue;
-                }
                 PXMainDataStagingWorkspace *systemWorkspace = nil;
                 PXValidatedMainDataStage *systemStage = nil;
                 NSError *systemStageError = nil;
@@ -2916,7 +3237,7 @@
                                                         error:&systemStageError]) {
                     cleanupSystemWorkspaces();
                     NSError *err = systemStageError;
-                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    completeStructuredFailure(PXRestoreComponentSystemGlobal, err, PXRestoreRollbackStatusNotPerformed, systemGlobalWarningStart);
                     return;
                 }
                 NSError *destinationError = nil;
@@ -2936,7 +3257,7 @@
                         [NSError errorWithDomain:PXBackupErrorDomain
                                             code:318
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore validated system-global stages transactionally"}];
-                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    completeStructuredFailure(PXRestoreComponentSystemGlobal, err, PXRestoreRollbackStatusNotPerformed, systemGlobalWarningStart);
                     return;
                 }
                 [systemWorkspaces addObject:systemWorkspace];
@@ -2952,7 +3273,7 @@
                     NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                        code:318
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore validated system-global stages transactionally"}];
-                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    completeStructuredFailure(PXRestoreComponentSystemGlobal, err, PXRestoreRollbackStatusNotPerformed, systemGlobalWarningStart);
                     return;
                 }
                 [self _killRelatedProcessesForBundleID:bundleID];
@@ -2963,7 +3284,12 @@
                     NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                        code:318
                                                    userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore validated system-global stages transactionally"}];
-                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    completeStructuredFailure(
+                        PXRestoreComponentSystemGlobal,
+                        err,
+                        PXRestoreRollbackStatusFromFlags(transaction.rollbackPerformed,
+                                                         transaction.rollbackComplete),
+                        systemGlobalWarningStart);
                     return;
                 }
                 if (cleanupWarning) {
@@ -2976,9 +3302,13 @@
                 }
                 if (!stagingCleaned) [warnings addObject:@"Optional-directory staging cleanup failed"];
             }
+            NSCAssert([resultAccumulator markComponentSucceeded:PXRestoreComponentSystemGlobal
+                                                       warnings:PXRestoreWarningsSuffix(warnings, systemGlobalWarningStart)],
+                      @"SystemGlobal result state must be publishable");
         }

         // Restore shared system DBs (if present)
+        NSUInteger sharedDatabaseWarningStart = warnings.count;
         if (restorePlan.sharedDatabaseItems.count) {
             NSMutableArray<PXOptionalFileStagingWorkspace *> *sharedWorkspaces =
                 [NSMutableArray arrayWithCapacity:restorePlan.sharedDatabaseItems.count];
@@ -3000,7 +3330,7 @@
                                             NSLocalizedDescriptionKey: @"The shared database source could not be staged.",
                                             PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
                                         }];
-                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    completeStructuredFailure(PXRestoreComponentSharedSystemDatabases, err, PXRestoreRollbackStatusNotPerformed, sharedDatabaseWarningStart);
                     return;
                 }
                 NSError *destinationError = nil;
@@ -3020,7 +3350,7 @@
                         [NSError errorWithDomain:PXBackupErrorDomain
                                             code:320
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore staged optional files transactionally"}];
-                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                    completeStructuredFailure(PXRestoreComponentSharedSystemDatabases, err, PXRestoreRollbackStatusNotPerformed, sharedDatabaseWarningStart);
                     return;
                 }
                 [sharedWorkspaces addObject:workspace];
@@ -3035,7 +3365,7 @@
                 NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                    code:320
                                                userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore staged optional files transactionally"}];
-                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                completeStructuredFailure(PXRestoreComponentSharedSystemDatabases, err, PXRestoreRollbackStatusNotPerformed, sharedDatabaseWarningStart);
                 return;
             }
             PXKillallByName(@"accountsd", SIGTERM);
@@ -3057,7 +3387,12 @@
                 NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                    code:320
                                                userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore staged optional files transactionally"}];
-                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                completeStructuredFailure(
+                    PXRestoreComponentSharedSystemDatabases,
+                    err,
+                    PXRestoreRollbackStatusFromFlags(sharedTransaction.rollbackPerformed,
+                                                     sharedTransaction.rollbackComplete),
+                    sharedDatabaseWarningStart);
                 return;
             }
             if (sharedCleanupWarning) {
@@ -3072,6 +3407,9 @@
             }
             if (!sharedStagingCleaned) [warnings addObject:@"Optional-file staging cleanup failed"];
             [warnings addObject:@"Restored shared system DBs (this may affect multiple apps)"];
+            NSCAssert([resultAccumulator markComponentSucceeded:PXRestoreComponentSharedSystemDatabases
+                                                       warnings:PXRestoreWarningsSuffix(warnings, sharedDatabaseWarningStart)],
+                      @"SharedSystemDatabases result state must be publishable");
             PXKillallByName(@"accountsd", SIGTERM);
             PXKillallByName(@"calaccessd", SIGTERM);
             PXKillallByName(@"imagent", SIGTERM);
@@ -3079,6 +3417,7 @@
         }

         // Preferences restore
+        NSUInteger preferencesWarningStart = warnings.count;
         if (restorePlan.includesPreferences) {
             NSError *preferencesStageError = nil;
             PXOptionalFileStagingWorkspace *preferencesWorkspace =
@@ -3092,7 +3431,7 @@
                                         NSLocalizedDescriptionKey: @"The Preferences source could not be staged.",
                                         PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
                                     }];
-                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                completeStructuredFailure(PXRestoreComponentPreferences, err, PXRestoreRollbackStatusNotPerformed, preferencesWarningStart);
                 return;
             }
             NSError *preferencesDestinationError = nil;
@@ -3120,7 +3459,12 @@
                 NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                    code:320
                                                userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore staged optional file transactionally"}];
-                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                completeStructuredFailure(
+                    PXRestoreComponentPreferences,
+                    err,
+                    PXRestoreRollbackStatusFromFlags(preferencesTransaction.rollbackPerformed,
+                                                     preferencesTransaction.rollbackComplete),
+                    preferencesWarningStart);
                 return;
             }
             if (preferencesCleanupWarning) {
@@ -3133,9 +3477,13 @@
                 PXKillallByName(@"cfprefsd", SIGTERM);
             }
             if (!preferencesStagingCleaned) [warnings addObject:@"Optional-file staging cleanup failed"];
+            NSCAssert([resultAccumulator markComponentSucceeded:PXRestoreComponentPreferences
+                                                       warnings:PXRestoreWarningsSuffix(warnings, preferencesWarningStart)],
+                      @"Preferences result state must be publishable");
         }

         // Keychain restore (warning-only on execution failure)
+        NSUInteger keychainBranchWarningStart = warnings.count;
         if (restorePlan.includesKeychain) {
             NSError *keychainStageError = nil;
             PXOptionalFileStagingWorkspace *keychainWorkspace =
@@ -3149,7 +3497,7 @@
                                         NSLocalizedDescriptionKey: @"The Keychain input source could not be staged.",
                                         PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
                                     }];
-                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+                completeStructuredFailure(PXRestoreComponentKeychain, err, PXRestoreRollbackStatusNotPerformed, keychainBranchWarningStart);
                 return;
             }

@@ -3158,6 +3506,7 @@
             NSString *method = restorePlan.keychainMethod;
             (void)method;
             BOOL shouldUseInApp = restorePlan.keychainUsesInAppMethod;
+            NSUInteger keychainExecutionWarningStart = warnings.count;
             BOOL ok = NO;
             if (shouldUseInApp) {
                 ok = [self _inAppKeychainRestoreForBundleID:bundleID
@@ -3182,6 +3531,23 @@
             if (![keychainWorkspace cleanupWithError:&keychainCleanupError]) {
                 [warnings addObject:@"Optional-file staging cleanup failed"];
             }
+            NSArray<NSString *> *keychainWarnings =
+                PXRestoreWarningsSuffix(warnings, keychainExecutionWarningStart);
+            if (ok) {
+                NSCAssert([resultAccumulator markComponentSucceeded:PXRestoreComponentKeychain
+                                                           warnings:keychainWarnings],
+                          @"Keychain success result state must be publishable");
+            } else {
+                PXRestoreFailure *keychainFailure =
+                    [[PXRestoreFailure alloc] initWithDomain:PXBackupErrorDomain
+                                                       code:322
+                                                    message:@"Keychain restore failed"];
+                NSCAssert([resultAccumulator markComponentFailed:PXRestoreComponentKeychain
+                                                         failure:keychainFailure
+                                                  rollbackStatus:PXRestoreRollbackStatusNotPerformed
+                                                        warnings:keychainWarnings],
+                          @"Keychain failure result state must be publishable");
+            }

             PXDebugHeader(debugKeychain, @"Keychain After Restore");
             PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"groups=%@", groups ?: @[]]);
@@ -3219,6 +3585,7 @@
             }
         }

+        NSUInteger postVerificationWarningStart = warnings.count;
         NSString *metadataPath = [dataContainerPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
         if (![fm fileExistsAtPath:metadataPath]) {
             [warnings addObject:@"Post-restore verification: data container metadata plist is missing"];
@@ -3228,11 +3595,14 @@
         if (![fm fileExistsAtPath:libraryPath isDirectory:&libraryIsDir] || !libraryIsDir) {
             [warnings addObject:@"Post-restore verification: Library directory missing after restore"];
         }
+        NSCAssert([resultAccumulator appendWarnings:PXRestoreWarningsSuffix(warnings, postVerificationWarningStart)
+                                          toComponent:PXRestoreComponentApplicationData],
+                  @"Post-verification warnings must attach to ApplicationData");

         [self _killRelatedProcessesForBundleID:bundleID];

-        PXRestoreResult *out = [[PXRestoreResult alloc] init];
-        out.warnings = warnings;
+        PXRestoreResult *out = [resultAccumulator resultWithAggregateWarnings:warnings];
+        NSCAssert(out != nil, @"Completed Restore must publish a structured result");
         dispatch_async(dispatch_get_main_queue(), ^{
             if (completion) {
                 completion(out, nil);
```

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
