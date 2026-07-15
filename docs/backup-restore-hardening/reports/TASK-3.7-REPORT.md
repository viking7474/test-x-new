# TASK-3.7 Implementation Report

## Baseline and exact scope

- Baseline: `3a7d3f8fe8a98747fe6c823167250e43b8159e9f`.
- Authorized production: `PXBackupManifestWriter.h`, `PXBackupManifestWriter.m`, `AppDataBackupManager.m`.
- Required report: `docs/backup-restore-hardening/reports/TASK-3.7-REPORT.md`.
- Implementation scope contains no TASK-3.8 or later-task behavior.

### Baseline evidence recorded before editing

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
git rev-parse HEAD
3a7d3f8fe8a98747fe6c823167250e43b8159e9f
git log -6 --oneline
3a7d3f8 phase3(task-3.6A): make manifest v4 type validation exception safe
c11ac70 phase3(task-3.6): introduce backup manifest schema v4
5366c50 phase3(task-3.5): define backup artifact policy
339ca01 phase3(task-3.4): derive preferences inclusion from verified output
849b282 phase3(task-3.3): add common verified artifact writer
dbfeb65 phase3(task-3.2): add per-bundle backup serialization
git diff --check
PASS
```

## Protected production SHA-256 before and after

- Protected entries: 304.
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

## Old best-effort manifest-write inventory

Baseline Backup contained exactly one path-based `writeToFile:atomically:`, one `Failed to write manifest` warning and one best-effort shell `chmod 600` for the final manifest. The operation could continue after write failure. All three authorities are removed.

## Exact public API and sixteen errors

| Gate | Count/result |
|---|---:|
| exports | 4 |
| codes | 16 |
| class | 1 |
| factory | 1 |
| write | 1 |
| validate | 1 |
| readonly | 6 |
| readwrite | 0 |

The exported values are exactly `manifest.plist` and `.weaponx-manifest-partial-`. No descriptor, temporary-name, cleanup, rename, overwrite or durability-bypass API is public.

## Pure writer boundary

The implementation imports only its header, the accepted workspace, manifest-v4 model and validator, plus Foundation/CommonCrypto/POSIX headers. It has no manager, CommandRunner, UI, Keychain, defaults, process, dispatch, shell or raw logging authority.

## Workspace binding

The factory requires the exact workspace class, validates it before and after opening, uses `O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC`, requires exact mode 0700, proves path/fd identity, retains its own descriptor, and rejects a final manifest or any direct manifest-temp child. It creates no file.

## Random descriptor-relative temporary creation

- Exact name: `.weaponx-manifest-partial-<32 lowercase hex>`.
- Exactly 16 random bytes from `arc4random_buf`.
- One `openat` creation site with `O_RDWR|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC`, mode 0600.
- Retry only `EEXIST`, at most 16 attempts; one owned temporary entry.
- 4,096 generated-name model samples were all unique and format-valid.

## Binary-plist serialization and limits

Only `manifestSnapshot.manifestRepresentation` is serialized in `NSPropertyListBinaryFormat_v1_0`. Accepted size is 1 through 128 MiB. Serialization exceptions/nil/zero/over-limit fail before publication.

## Exact full-write and strict durability

Full-write logic retries only EINTR, rejects zero progress, checks exact count and bounded arithmetic. The single strict fsync helper returns success only when `fsync` returns zero; unsupported errors are not accepted. Temp-file and workspace-directory fsync are required before rename, and manifest-file plus workspace-directory fsync are required after rename.

## Pre-rename read-back, validator and equality

The retained temp descriptor is sought to zero, read exactly with a 64-KiB buffer, checked for early EOF/extra bytes, streamed through SHA-256 and stat-stability proof, parsed immutably, validated exactly once for the pre-rename phase, deep-compared to the immutable v4 representation, and checked against backupID/count/size/checksum snapshot properties.

## Atomic renameat and final identity

Immediately before one same-directory `renameat`, workspace/temp identities are revalidated and `manifest.plist` must be absent. After rename, the exact inode/type/mode/nlink/size is proven, strictly synced, independently opened no-follow/CLOEXEC and retained. Rename-induced ctime movement is not mistaken for content mutation; final timestamps are retained after publication.

## Post-rename read-back and acceptance

The independent final descriptor is reread, rehashed, reparsed, validated exactly once for the post-rename phase, deep/aggregate checked and re-bound to the workspace namespace. Only then are manifestWritten, size, digest, representation and manifestPath set.

## Identity validation

Before write, validation requires clean unwritten state. After success it verifies retained workspace/final descriptors, namespace identity, no symlink, regular/nlink1/mode0600, exact size/timestamps/CLOEXEC, no temp, reread digest, validator acceptance and retained representation equality. Replacement identities are never adopted.

## Cleanup and evidence preservation

Pre-rename cleanup removes only the exact retained temp inode. Post-rename cleanup removes only the exact retained final inode. Both require namespace/fd/type/nlink/mode identity and strict workspace fsync. Identity changes preserve evidence and return CleanupFailed. No recursive workspace cleanup exists.

## Error privacy

One centralized helper emits only `NSLocalizedDescriptionKey` and `PXBackupManifestWriterErrorFieldPathKey`, with generic descriptions. No path, temp name, bundle/backup ID, artifact, content, digest, size, inode/device, errno text, nested error or process output is exposed.

## Manager ordering and hard-failure contract

Manager order is: artifact-writer factory/initial validation → manifest-writer factory/initial validation → policy construction/producers → policy audit → v4 builder → manager validator → artifact/workspace/lock/manifest-writer gates → one manifest write → final manifest/workspace/lock/artifact gates → result. Every manifest-writer failure returns nil result plus the exact writer error, once, on the main queue.

## Obsolete path write, warning and chmod removal

- Backup warning expressions: 7 → 6.
- Removed warning expressions: `['@"Failed to write manifest"]']`.
- Added warning expressions: `[]`.
- Direct manager manifest `writeToFile:atomically:`: 0.
- Manifest shell chmod: 0.
- Result path authority: `manifestWriter.manifestPath`.

## TASK-3.1 through TASK-3.6A non-regression

Workspace, bundle lock, artifact writer, artifact policy, v4 builder and validator are byte-identical. Lock/workspace/artifact/policy counts are retained. Restore and Backup discovery bodies are byte-identical, as are public selectors and protected UI/Makefile/Keychain sources.

## Later-task boundaries

No final Backup-directory rename, visible naming/collision policy, parent publication fsync, whole-workspace cleanup, stale cleanup/discovery hardening, marker file, Restore or UI change was implemented.

## Static gate table

| Gate | Result |
|---|---|
| public exports | 4 |
| error codes | 16 |
| writer classes | 1 |
| writer factories | 1 |
| write methods | 1 |
| identity methods | 1 |
| public readwrite | 0 |
| temp openat O_EXCL | 1 |
| renameat | 1 |
| binary plist format | 1 |
| pre validator calls | 1 |
| post validator calls | 1 |
| strict fsync syscall sites | 1 |
| shell/process calls | 0 |
| manifest writer factory | 1 |
| manifest writer validations | 3 |
| manifest write calls | 1 |
| manager v4 factory | 1 |
| manager validator | 1 |
| legacy manifest path write | 0 |
| Failed-to-write warning | 0 |
| manifest chmod | 0 |
| lock factory/validations | 1/4 |
| workspace factory/validations | 1/3 |
| artifact factory/validations | 1/3 |
| policy constructions | 8 |
| artifact writes | 8 |
| failure-policy calls | 8 |
| policy audit | 1 |
| final directory rename | 0 |
| protected files changed | 0 |
| writer strict frontend | PASS |
| manager integration frontend | PASS |
| random samples | 4096 unique PASS |
| fault steps | 72 fail-closed PASS |
| cleanup evidence cases | 14 PASS |
| manager failure cases | 9 PASS |
| git diff --check | PASS |

## Explicit scenario matrix

Explicit scenarios: 372.

| # | Scenario | Expected/result | Evidence |
|---:|---|---|---|
| 1 | Error domain export | PASS static | Exact public header/API inventory. |
| 2 | Field-path export | PASS static | Exact public header/API inventory. |
| 3 | Final filename export | PASS static | Exact public header/API inventory. |
| 4 | Temporary prefix export | PASS static | Exact public header/API inventory. |
| 5 | Sixteen contiguous error codes | PASS static | Exact public header/API inventory. |
| 6 | Single restricted writer class | PASS static | Exact public header/API inventory. |
| 7 | Single workspace factory | PASS static | Exact public header/API inventory. |
| 8 | Single write method | PASS static | Exact public header/API inventory. |
| 9 | Single identity validator | PASS static | Exact public header/API inventory. |
| 10 | Six readonly properties | PASS static | Exact public header/API inventory. |
| 11 | No descriptor property | PASS static | Exact public header/API inventory. |
| 12 | No cleanup API | PASS static | Exact public header/API inventory. |
| 13 | No rename API | PASS static | Exact public header/API inventory. |
| 14 | No overwrite API | PASS static | Exact public header/API inventory. |
| 15 | No alternate format API | PASS static | Exact public header/API inventory. |
| 16 | init unavailable | PASS static | Exact public header/API inventory. |
| 17 | new unavailable | PASS static | Exact public header/API inventory. |
| 18 | Factory clears error | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 19 | Reject nil workspace | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 20 | Reject subclass workspace | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 21 | Workspace validation before open | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 22 | Workspace final symlink rejected | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 23 | Workspace wrong type rejected | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 24 | Workspace mode not 0700 rejected | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 25 | Workspace open no-follow | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 26 | Workspace descriptor CLOEXEC | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 27 | Workspace path/fd identity | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 28 | Workspace second validation | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 29 | Final manifest absent at factory | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 30 | Final symlink present at factory | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 31 | Final regular file present at factory | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 32 | Stale manifest temp child | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 33 | Multiple stale temp children | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 34 | No file created by factory | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 35 | Unwritten state returned | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 36 | Unwritten identity validation success | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 37 | Unwritten final-name race detected | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 38 | Unwritten temp-name race detected | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 39 | Workspace inode replacement detected | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 40 | Workspace device change detected | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 41 | Workspace chmod detected | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 42 | Workspace descriptor invalidated | PASS factory contract | Descriptor-bound factory checks and unwritten validation. |
| 43 | Temporary random-name attempt 1 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 44 | Temporary random-name attempt 2 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 45 | Temporary random-name attempt 3 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 46 | Temporary random-name attempt 4 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 47 | Temporary random-name attempt 5 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 48 | Temporary random-name attempt 6 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 49 | Temporary random-name attempt 7 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 50 | Temporary random-name attempt 8 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 51 | Temporary random-name attempt 9 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 52 | Temporary random-name attempt 10 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 53 | Temporary random-name attempt 11 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 54 | Temporary random-name attempt 12 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 55 | Temporary random-name attempt 13 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 56 | Temporary random-name attempt 14 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 57 | Temporary random-name attempt 15 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 58 | Temporary random-name attempt 16 | PASS protocol | Exactly 16 random bytes produce 32 lowercase hexadecimal characters; retry only EEXIST. |
| 59 | Temporary prefix exact | PASS temp protocol | Static source and state-model proof. |
| 60 | Temporary suffix length 32 | PASS temp protocol | Static source and state-model proof. |
| 61 | Temporary suffix lowercase | PASS temp protocol | Static source and state-model proof. |
| 62 | Temporary suffix hexadecimal | PASS temp protocol | Static source and state-model proof. |
| 63 | No timestamp-only name | PASS temp protocol | Static source and state-model proof. |
| 64 | No PID-only name | PASS temp protocol | Static source and state-model proof. |
| 65 | No predictable counter | PASS temp protocol | Static source and state-model proof. |
| 66 | Direct-child openat authority | PASS temp protocol | Static source and state-model proof. |
| 67 | O_RDWR temp access | PASS temp protocol | Static source and state-model proof. |
| 68 | O_CREAT temp creation | PASS temp protocol | Static source and state-model proof. |
| 69 | O_EXCL collision protection | PASS temp protocol | Static source and state-model proof. |
| 70 | O_NOFOLLOW temp creation | PASS temp protocol | Static source and state-model proof. |
| 71 | O_CLOEXEC temp creation | PASS temp protocol | Static source and state-model proof. |
| 72 | Temp mode 0600 | PASS temp protocol | Static source and state-model proof. |
| 73 | Temp regular type | PASS temp protocol | Static source and state-model proof. |
| 74 | Temp nlink one | PASS temp protocol | Static source and state-model proof. |
| 75 | Temp size zero | PASS temp protocol | Static source and state-model proof. |
| 76 | Temp same filesystem | PASS temp protocol | Static source and state-model proof. |
| 77 | Temp namespace/fd identity | PASS temp protocol | Static source and state-model proof. |
| 78 | Temp descriptor CLOEXEC | PASS temp protocol | Static source and state-model proof. |
| 79 | One owned temp maximum | PASS temp protocol | Static source and state-model proof. |
| 80 | Unexpected second temp preserved | PASS temp protocol | Static source and state-model proof. |
| 81 | Temp symlink substitution rejected | PASS temp protocol | Static source and state-model proof. |
| 82 | Temp hard-link substitution rejected | PASS temp protocol | Static source and state-model proof. |
| 83 | Temp type substitution rejected | PASS temp protocol | Static source and state-model proof. |
| 84 | Temp mode substitution rejected | PASS temp protocol | Static source and state-model proof. |
| 85 | Temp inode replacement rejected | PASS temp protocol | Static source and state-model proof. |
| 86 | Exact PXBackupManifestV4 required | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 87 | Subclass snapshot rejected | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 88 | Second write rejected before serialization | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 89 | Workspace revalidated before serialization | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 90 | Final absent before serialization | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 91 | Serialize representation only | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 92 | Binary plist v1 format | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 93 | Serialization exception mapped | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 94 | Serialization nil mapped | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 95 | Zero serialized bytes rejected | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 96 | One byte accepted | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 97 | 128 MiB accepted boundary | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 98 | Over 128 MiB rejected | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 99 | Representation not patched | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 100 | No alternate plist format | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 101 | No raw object ivar serialization | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 102 | Full write starts at offset zero | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 103 | Write retries EINTR only | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 104 | Zero-progress write rejected | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 105 | Partial write continues | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 106 | Write count exact | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 107 | Write arithmetic bounded | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 108 | Written fstat required | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 109 | Written size exact | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 110 | Written namespace identity | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 111 | Written same filesystem | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 112 | Written mode 0600 | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 113 | Written nlink one | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 114 | Written inode stable | PASS serialization/write | Binary serialization and bounded full-write implementation. |
| 115 | Temp fsync succeeds only on zero | PASS durability | One strict fsync helper returns success only for syscall result zero. |
| 116 | Temp fsync EINTR retry | PASS durability | One strict fsync helper returns success only for syscall result zero. |
| 117 | Temp fsync EINVAL fails | PASS durability | One strict fsync helper returns success only for syscall result zero. |
| 118 | Temp fsync ENOTSUP fails | PASS durability | One strict fsync helper returns success only for syscall result zero. |
| 119 | Temp fsync EOPNOTSUPP fails | PASS durability | One strict fsync helper returns success only for syscall result zero. |
| 120 | Temp fsync ENOSYS fails | PASS durability | One strict fsync helper returns success only for syscall result zero. |
| 121 | Workspace pre-fsync strict | PASS durability | One strict fsync helper returns success only for syscall result zero. |
| 122 | No global sync | PASS durability | One strict fsync helper returns success only for syscall result zero. |
| 123 | No shell durability fallback | PASS durability | One strict fsync helper returns success only for syscall result zero. |
| 124 | No F_FULLFSYNC replacement | PASS durability | One strict fsync helper returns success only for syscall result zero. |
| 125 | Pre-read seek zero | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 126 | Pre-read exact retained size | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 127 | Pre-read 64 KiB buffer | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 128 | Pre-read EINTR retry | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 129 | Pre-read early EOF rejected | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 130 | Pre-read extra byte rejected | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 131 | Pre-read SHA-256 lowercase | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 132 | Pre-read stat identity stable | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 133 | Pre-read mode stable | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 134 | Pre-read nlink stable | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 135 | Pre-read size stable | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 136 | Pre-read mtime stable | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 137 | Pre-read ctime stable | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 138 | Pre-read malformed plist rejected | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 139 | Pre-read non-dictionary root rejected | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 140 | Pre-read validator called once | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 141 | Pre-read validator error mapped | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 142 | Pre-read deep equality required | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 143 | Pre-read backupID exact | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 144 | Pre-read artifactCount exact | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 145 | Pre-read totalSize exact | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 146 | Pre-read archiveChecksum exact | PASS pre-rename proof | Read-back helper, validator call and exact snapshot aggregate proof. |
| 147 | Workspace revalidated immediately before rename | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 148 | Temp revalidated immediately before rename | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 149 | Final absence immediately before rename | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 150 | Final-name race rejected before rename | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 151 | Exactly one renameat | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 152 | Same-directory rename authority | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 153 | No manager rename | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 154 | No alternate final name | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 155 | No final open with O_CREAT | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 156 | Final namespace exact retained inode | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 157 | Final regular type | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 158 | Final nlink one | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 159 | Final mode 0600 | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 160 | Final same filesystem | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 161 | Post-rename manifest fsync strict | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 162 | Post-rename workspace fsync strict | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 163 | Independent final open read-only | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 164 | Independent final open nonblocking | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 165 | Independent final open no-follow | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 166 | Independent final open CLOEXEC | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 167 | Independent descriptor identity | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 168 | Old temp descriptor retained until final descriptor | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 169 | Rename-induced ctime change accepted only across publication | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 170 | Final timestamps retained after publication | PASS atomic finalization | Single renameat and post-publication descriptor/namespace proof. |
| 171 | Post-read exact size | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 172 | Post-read SHA-256 recompute | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 173 | Post digest equals pre digest | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 174 | Post-read early EOF rejected | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 175 | Post-read extra byte rejected | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 176 | Post-read mutation rejected | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 177 | Post-read malformed plist rejected | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 178 | Post-read dictionary root | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 179 | Post-read validator called once | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 180 | Post-read deep equality required | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 181 | Post-read backupID exact | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 182 | Post-read artifactCount exact | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 183 | Post-read totalSize exact | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 184 | Post-read archiveChecksum exact | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 185 | Post workspace identity | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 186 | Post final namespace identity | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 187 | Post temporary namespace empty | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 188 | State not accepted before post proof | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 189 | manifestWritten set after proof | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 190 | manifestSize set after proof | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 191 | manifestSHA256 set after proof | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 192 | manifestRepresentation set after proof | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 193 | manifestPath set after proof | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 194 | Final descriptor retained after proof | PASS post-rename proof | Post-publication reread and state-acceptance ordering. |
| 195 | Validation clears error | PASS identity validation | Retained identity/digest/representation checks. |
| 196 | Validation before write succeeds when clean | PASS identity validation | Retained identity/digest/representation checks. |
| 197 | Validation before write rejects final name | PASS identity validation | Retained identity/digest/representation checks. |
| 198 | Validation before write rejects temp prefix | PASS identity validation | Retained identity/digest/representation checks. |
| 199 | Validation after success checks workspace | PASS identity validation | Retained identity/digest/representation checks. |
| 200 | Validation after success checks final fd | PASS identity validation | Retained identity/digest/representation checks. |
| 201 | Validation after success checks final namespace | PASS identity validation | Retained identity/digest/representation checks. |
| 202 | Validation rejects final symlink | PASS identity validation | Retained identity/digest/representation checks. |
| 203 | Validation rejects final inode replacement | PASS identity validation | Retained identity/digest/representation checks. |
| 204 | Validation rejects mode change | PASS identity validation | Retained identity/digest/representation checks. |
| 205 | Validation rejects hard link | PASS identity validation | Retained identity/digest/representation checks. |
| 206 | Validation rejects size change | PASS identity validation | Retained identity/digest/representation checks. |
| 207 | Validation rejects mtime change | PASS identity validation | Retained identity/digest/representation checks. |
| 208 | Validation rejects ctime change | PASS identity validation | Retained identity/digest/representation checks. |
| 209 | Validation rejects CLOEXEC loss | PASS identity validation | Retained identity/digest/representation checks. |
| 210 | Validation rejects temp remnant | PASS identity validation | Retained identity/digest/representation checks. |
| 211 | Validation rereads digest | PASS identity validation | Retained identity/digest/representation checks. |
| 212 | Validation parses binary plist | PASS identity validation | Retained identity/digest/representation checks. |
| 213 | Validation invokes validator | PASS identity validation | Retained identity/digest/representation checks. |
| 214 | Validation exact retained representation | PASS identity validation | Retained identity/digest/representation checks. |
| 215 | Validation does not adopt replacement identity | PASS identity validation | Retained identity/digest/representation checks. |
| 216 | pre-rename cleanup: normal exact cleanup | PASS cleanup | Bounded descriptor-relative identity proof; no recursive deletion. |
| 217 | pre-rename cleanup: inode changed | CleanupFailed / preserve evidence | Bounded descriptor-relative identity proof; no recursive deletion. |
| 218 | pre-rename cleanup: type changed | CleanupFailed / preserve evidence | Bounded descriptor-relative identity proof; no recursive deletion. |
| 219 | pre-rename cleanup: nlink changed | CleanupFailed / preserve evidence | Bounded descriptor-relative identity proof; no recursive deletion. |
| 220 | pre-rename cleanup: mode changed | CleanupFailed / preserve evidence | Bounded descriptor-relative identity proof; no recursive deletion. |
| 221 | pre-rename cleanup: namespace missing | CleanupFailed / preserve evidence | Bounded descriptor-relative identity proof; no recursive deletion. |
| 222 | pre-rename cleanup: descriptor unavailable | CleanupFailed / preserve evidence | Bounded descriptor-relative identity proof; no recursive deletion. |
| 223 | pre-rename cleanup: workspace fsync failure | CleanupFailed / preserve evidence | Bounded descriptor-relative identity proof; no recursive deletion. |
| 224 | post-rename cleanup: normal exact cleanup | PASS cleanup | Bounded descriptor-relative identity proof; no recursive deletion. |
| 225 | post-rename cleanup: inode changed | CleanupFailed / preserve evidence | Bounded descriptor-relative identity proof; no recursive deletion. |
| 226 | post-rename cleanup: type changed | CleanupFailed / preserve evidence | Bounded descriptor-relative identity proof; no recursive deletion. |
| 227 | post-rename cleanup: nlink changed | CleanupFailed / preserve evidence | Bounded descriptor-relative identity proof; no recursive deletion. |
| 228 | post-rename cleanup: mode changed | CleanupFailed / preserve evidence | Bounded descriptor-relative identity proof; no recursive deletion. |
| 229 | post-rename cleanup: namespace missing | CleanupFailed / preserve evidence | Bounded descriptor-relative identity proof; no recursive deletion. |
| 230 | post-rename cleanup: descriptor unavailable | CleanupFailed / preserve evidence | Bounded descriptor-relative identity proof; no recursive deletion. |
| 231 | post-rename cleanup: workspace fsync failure | CleanupFailed / preserve evidence | Bounded descriptor-relative identity proof; no recursive deletion. |
| 232 | Error userInfo has description only plus field path | PASS privacy | Single centralized error helper and static forbidden-token audit. |
| 233 | No workspace path in errors | PASS privacy | Single centralized error helper and static forbidden-token audit. |
| 234 | No manifest path in errors | PASS privacy | Single centralized error helper and static forbidden-token audit. |
| 235 | No temp name in errors | PASS privacy | Single centralized error helper and static forbidden-token audit. |
| 236 | No bundle ID in errors | PASS privacy | Single centralized error helper and static forbidden-token audit. |
| 237 | No backup ID in errors | PASS privacy | Single centralized error helper and static forbidden-token audit. |
| 238 | No artifact name in errors | PASS privacy | Single centralized error helper and static forbidden-token audit. |
| 239 | No digest in errors | PASS privacy | Single centralized error helper and static forbidden-token audit. |
| 240 | No size in errors | PASS privacy | Single centralized error helper and static forbidden-token audit. |
| 241 | No inode/device in errors | PASS privacy | Single centralized error helper and static forbidden-token audit. |
| 242 | No errno text in errors | PASS privacy | Single centralized error helper and static forbidden-token audit. |
| 243 | No nested error | PASS privacy | Single centralized error helper and static forbidden-token audit. |
| 244 | No stdout/stderr | PASS privacy | Single centralized error helper and static forbidden-token audit. |
| 245 | Generic descriptions | PASS privacy | Single centralized error helper and static forbidden-token audit. |
| 246 | Manager import exactly once | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 247 | Artifact writer factory remains first | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 248 | Artifact initial validation remains | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 249 | Manifest writer factory after artifact initial validation | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 250 | Manifest writer factory before policy construction | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 251 | Manifest writer factory before output directories | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 252 | Manifest writer factory before debug files | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 253 | Manifest writer factory before process kill | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 254 | Manifest writer factory before producers | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 255 | Initial manifest writer validation | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 256 | Policy audit before v4 builder | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 257 | V4 builder exactly once | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 258 | Manager validator exactly once | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 259 | Artifact writer pre-manifest validation | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 260 | Workspace pre-manifest validation | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 261 | Lock pre-manifest validation | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 262 | Manifest writer pre-write validation | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 263 | Manifest write exactly once | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 264 | Manifest write failure nil result | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 265 | Manifest write failure exact writer error | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 266 | Manifest write failure main queue | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 267 | Manifest write failure one completion | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 268 | Final manifest writer validation | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 269 | Final workspace validation retained | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 270 | Final lock validation retained | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 271 | Final artifact writer validation retained | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 272 | Result manifest path from writer | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 273 | Result backup directory remains partial workspace | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 274 | Normal completion result nonnil | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 275 | Normal completion error nil | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 276 | Legacy writeToFile removed | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 277 | Failed-to-write warning removed | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 278 | Manifest chmod shell removed | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 279 | Debug manifest observation after publication | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 280 | No final Backup directory rename | PASS manager contract | Exact source counts and monotonic ordering proof. |
| 281 | Lock factory count retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 282 | Lock validation count retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 283 | Workspace factory count retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 284 | Workspace validation count retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 285 | Artifact writer factory count retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 286 | Artifact writer validation count retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 287 | Policy construction count retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 288 | Artifact write count retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 289 | Failure-policy count retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 290 | Policy-audit count retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 291 | V4 header byte identity | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 292 | V4 source byte identity | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 293 | Validator header byte identity | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 294 | Validator source byte identity | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 295 | Workspace header byte identity | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 296 | Workspace source byte identity | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 297 | Lock header byte identity | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 298 | Lock source byte identity | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 299 | Artifact writer header byte identity | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 300 | Artifact writer source byte identity | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 301 | Artifact policy header byte identity | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 302 | Artifact policy source byte identity | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 303 | Restore byte identity | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 304 | Discovery byte identity | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 305 | Public Backup selector identity | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 306 | Preferences semantics retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 307 | Keychain behavior retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 308 | Malformed-v4 safety retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 309 | V2/V3 behavior retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 310 | Unknown positive-version boundary retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 311 | Manager code 107 retained | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 312 | Manifest schema remains v4 | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 313 | No TASK-3.8 workspace publication | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 314 | No TASK-3.9 whole-workspace cleanup | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 315 | No TASK-3.10 stale cleanup | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 316 | No publication marker | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 317 | No Restore change | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 318 | No UI change | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 319 | No Makefile change | PASS non-regression | Protected SHA-256 and exact body/API comparisons. |
| 320 | Interruption point 1: factory input | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 321 | Interruption point 2: workspace validation first | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 322 | Interruption point 3: workspace lstat | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 323 | Interruption point 4: workspace open | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 324 | Interruption point 5: workspace mode | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 325 | Interruption point 6: workspace CLOEXEC | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 326 | Interruption point 7: workspace validation second | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 327 | Interruption point 8: workspace path/fd proof | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 328 | Interruption point 9: factory final absence | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 329 | Interruption point 10: factory temp scan | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 330 | Interruption point 11: serialization | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 331 | Interruption point 12: serialized lower bound | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 332 | Interruption point 13: serialized upper bound | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 333 | Interruption point 14: write final absence | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 334 | Interruption point 15: random generation | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 335 | Interruption point 16: temp open | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 336 | Interruption point 17: temp identity | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 337 | Interruption point 18: temp namespace | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 338 | Interruption point 19: owned temp scan | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 339 | Interruption point 20: full write | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 340 | Interruption point 21: written fstat | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 341 | Interruption point 22: written namespace | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 342 | Interruption point 23: temp fsync | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 343 | Interruption point 24: pre workspace fsync | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 344 | Interruption point 25: pre seek | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 345 | Interruption point 26: pre exact read | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 346 | Interruption point 27: pre extra-byte check | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 347 | Interruption point 28: pre digest | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 348 | Interruption point 29: pre stat | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 349 | Interruption point 30: pre parse | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 350 | Interruption point 31: pre validator | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 351 | Interruption point 32: pre equality | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 352 | Interruption point 33: pre aggregate | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 353 | Interruption point 34: pre workspace revalidation | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 354 | Interruption point 35: pre temp revalidation | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 355 | Interruption point 36: pre final absence | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 356 | Interruption point 37: renameat | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 357 | Interruption point 38: final namespace | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 358 | Interruption point 39: final fsync | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 359 | Interruption point 40: post workspace fsync | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 360 | Interruption point 41: independent open | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 361 | Interruption point 42: independent identity | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 362 | Interruption point 43: post exact read | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 363 | Interruption point 44: post digest | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 364 | Interruption point 45: post stat | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 365 | Interruption point 46: post parse | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 366 | Interruption point 47: post validator | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 367 | Interruption point 48: post equality | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 368 | Interruption point 49: post aggregate | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 369 | Interruption point 50: post workspace validation | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 370 | Interruption point 51: post final validation | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 371 | Interruption point 52: post temp scan | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |
| 372 | Interruption point 53: accept state | PASS fail-closed | No accepted writer state; exact temp/final cleanup according to phase. |

## Authorized production artifact hashes

| Path | SHA-256 | Bytes |
|---|---|---:|
| `PXBackupManifestWriter.h` | `a8eef3991f2e9176d0ddd73aa007c7e2442be6b2e257b6576dfa5db680a2f546` | 2431 |
| `PXBackupManifestWriter.m` | `005c64ea37718f3c8c4a0ac97422441bb5e1393d7cfe8082aecd1e14d519729c` | 54069 |
| `AppDataBackupManager.m` | `9d78023495e2ed6a1af8508f85ab6ec0410efbfb0252579aea16a6ebfcdc593e` | 219504 |

## Whitespace, CRLF and NUL audit

- `PXBackupManifestWriter.h`: bytes=2431, CRLF=0, bare LF=58, NUL=0, final newline=True.
- `PXBackupManifestWriter.m`: bytes=54069, CRLF=0, bare LF=1175, NUL=0, final newline=True.
- `AppDataBackupManager.m`: bytes=219504, CRLF=0, bare LF=4156, NUL=0, final newline=True.
- Authorized source `git diff --check`: PASS.

## Build status and remaining runtime risks

- Strict Objective-C frontend/analyzer passed for the complete writer and exact manager integration harness.
- The Windows workspace has no Theos, Apple clang, xcrun or linked iOS runtime artifact. GitHub Actions/device execution remains authoritative for syscall fault injection and real filesystem durability behavior.
- Remaining runtime risks are platform-specific fsync/rename/openat behavior and crash-point replay, not an unacknowledged source or API gap.

## Full authorized source diff

```diff
--- a/PXBackupManifestWriter.h
+++ b/PXBackupManifestWriter.h
@@ -0,0 +1,58 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+@class PXBackupManifestV4;
+@class PXBackupPublicationWorkspace;
+
+FOUNDATION_EXPORT NSErrorDomain const PXBackupManifestWriterErrorDomain;
+FOUNDATION_EXPORT NSString * const PXBackupManifestWriterErrorFieldPathKey;
+FOUNDATION_EXPORT NSString * const PXBackupManifestFinalFileName;
+FOUNDATION_EXPORT NSString * const PXBackupManifestTemporaryFilePrefix;
+
+typedef NS_ERROR_ENUM(PXBackupManifestWriterErrorDomain,
+                      PXBackupManifestWriterErrorCode) {
+    PXBackupManifestWriterErrorInvalidInput = 1,
+    PXBackupManifestWriterErrorWorkspaceValidationFailed = 2,
+    PXBackupManifestWriterErrorWorkspaceInspectionFailed = 3,
+    PXBackupManifestWriterErrorManifestAlreadyWritten = 4,
+    PXBackupManifestWriterErrorFinalManifestAlreadyExists = 5,
+    PXBackupManifestWriterErrorSerializationFailed = 6,
+    PXBackupManifestWriterErrorLimitExceeded = 7,
+    PXBackupManifestWriterErrorTemporaryCreationFailed = 8,
+    PXBackupManifestWriterErrorWriteFailed = 9,
+    PXBackupManifestWriterErrorDurabilityFailed = 10,
+    PXBackupManifestWriterErrorReadBackFailed = 11,
+    PXBackupManifestWriterErrorValidationFailed = 12,
+    PXBackupManifestWriterErrorSnapshotMismatch = 13,
+    PXBackupManifestWriterErrorFilesystemChanged = 14,
+    PXBackupManifestWriterErrorFinalizationFailed = 15,
+    PXBackupManifestWriterErrorCleanupFailed = 16,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXBackupManifestWriter : NSObject
+
+@property (nonatomic, copy, readonly) NSString *workspacePath;
+@property (nonatomic, copy, readonly) NSString *manifestPath;
+@property (nonatomic, readonly, getter=isManifestWritten) BOOL manifestWritten;
+@property (nonatomic, readonly) unsigned long long manifestSize;
+@property (nonatomic, copy, readonly, nullable) NSString *manifestSHA256;
+@property (nonatomic, copy, readonly, nullable)
+    NSDictionary<NSString *, id> *manifestRepresentation;
+
++ (nullable instancetype)
+    writerForWorkspace:(PXBackupPublicationWorkspace *)workspace
+                  error:(NSError * _Nullable * _Nullable)error;
+
+- (BOOL)writeManifestSnapshot:(PXBackupManifestV4 *)manifestSnapshot
+                        error:(NSError * _Nullable * _Nullable)error;
+
+- (BOOL)validateIdentityWithError:(NSError * _Nullable * _Nullable)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
--- a/PXBackupManifestWriter.m
+++ b/PXBackupManifestWriter.m
@@ -0,0 +1,1175 @@
+#import "PXBackupManifestWriter.h"
+#import "PXBackupPublicationWorkspace.h"
+#import "PXBackupManifestV4.h"
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
+NSErrorDomain const PXBackupManifestWriterErrorDomain =
+    @"com.hydra.projectx.backup-manifest-writer";
+NSString * const PXBackupManifestWriterErrorFieldPathKey = @"fieldPath";
+NSString * const PXBackupManifestFinalFileName = @"manifest.plist";
+NSString * const PXBackupManifestTemporaryFilePrefix =
+    @".weaponx-manifest-partial-";
+
+static NSString * const PXBackupManifestWorkspaceField = @"$.workspace";
+static NSString * const PXBackupManifestField = @"$.manifest";
+static NSString * const PXBackupManifestTemporaryField = @"$.manifest.temporary";
+static NSString * const PXBackupManifestSnapshotField = @"$.manifest.snapshot";
+
+static const unsigned long long PXBackupManifestMaximumSerializedBytes =
+    128ULL * 1024ULL * 1024ULL;
+static const size_t PXBackupManifestReadBufferBytes = 64U * 1024U;
+static const size_t PXBackupManifestRandomSuffixBytes = 16U;
+static const NSUInteger PXBackupManifestTemporaryCreationAttempts = 16U;
+static const NSUInteger PXBackupManifestMaximumOwnedTemporaryEntries = 1U;
+static const NSUInteger PXBackupManifestMaximumCleanupEntries = 2U;
+static const NSUInteger PXBackupManifestMaximumPathBytes = 4096U;
+static const char PXBackupManifestFinalFileNameBytes[] = "manifest.plist";
+static const char PXBackupManifestTemporaryFilePrefixBytes[] =
+    ".weaponx-manifest-partial-";
+
+#if defined(__APPLE__)
+#define PX_BACKUP_MANIFEST_MTIME_SEC(value) ((value).st_mtimespec.tv_sec)
+#define PX_BACKUP_MANIFEST_MTIME_NSEC(value) ((value).st_mtimespec.tv_nsec)
+#define PX_BACKUP_MANIFEST_CTIME_SEC(value) ((value).st_ctimespec.tv_sec)
+#define PX_BACKUP_MANIFEST_CTIME_NSEC(value) ((value).st_ctimespec.tv_nsec)
+#else
+#define PX_BACKUP_MANIFEST_MTIME_SEC(value) ((value).st_mtim.tv_sec)
+#define PX_BACKUP_MANIFEST_MTIME_NSEC(value) ((value).st_mtim.tv_nsec)
+#define PX_BACKUP_MANIFEST_CTIME_SEC(value) ((value).st_ctim.tv_sec)
+#define PX_BACKUP_MANIFEST_CTIME_NSEC(value) ((value).st_ctim.tv_nsec)
+#endif
+
+static void PXBackupManifestSetError(NSError **error,
+                                     PXBackupManifestWriterErrorCode code,
+                                     NSString *fieldPath,
+                                     NSString *description) {
+    if (!error) return;
+    *error = [NSError errorWithDomain:PXBackupManifestWriterErrorDomain
+                                 code:code
+                             userInfo:@{
+                                 NSLocalizedDescriptionKey: description,
+                                 PXBackupManifestWriterErrorFieldPathKey: fieldPath,
+                             }];
+}
+
+static BOOL PXBackupManifestStatIdentityMatches(const struct stat *left,
+                                                 const struct stat *right) {
+    return left && right &&
+           left->st_dev == right->st_dev &&
+           left->st_ino == right->st_ino &&
+           ((left->st_mode & S_IFMT) == (right->st_mode & S_IFMT));
+}
+
+static BOOL PXBackupManifestStableFileStatMatches(const struct stat *left,
+                                                   const struct stat *right) {
+    return PXBackupManifestStatIdentityMatches(left, right) &&
+           (left->st_mode & 07777) == (right->st_mode & 07777) &&
+           left->st_nlink == right->st_nlink &&
+           left->st_size == right->st_size &&
+           PX_BACKUP_MANIFEST_MTIME_SEC(*left) ==
+               PX_BACKUP_MANIFEST_MTIME_SEC(*right) &&
+           PX_BACKUP_MANIFEST_MTIME_NSEC(*left) ==
+               PX_BACKUP_MANIFEST_MTIME_NSEC(*right) &&
+           PX_BACKUP_MANIFEST_CTIME_SEC(*left) ==
+               PX_BACKUP_MANIFEST_CTIME_SEC(*right) &&
+           PX_BACKUP_MANIFEST_CTIME_NSEC(*left) ==
+               PX_BACKUP_MANIFEST_CTIME_NSEC(*right);
+}
+
+static BOOL PXBackupManifestPublishedFileStatMatches(const struct stat *before,
+                                                      const struct stat *after) {
+    return PXBackupManifestStatIdentityMatches(before, after) &&
+           (before->st_mode & 07777) == (after->st_mode & 07777) &&
+           before->st_nlink == after->st_nlink &&
+           before->st_size == after->st_size;
+}
+
+static BOOL PXBackupManifestDescriptorHasCloseOnExec(int descriptor) {
+    if (descriptor < 0) return NO;
+    int flags = -1;
+    do {
+        flags = fcntl(descriptor, F_GETFD);
+    } while (flags < 0 && errno == EINTR);
+    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
+}
+
+static int PXBackupManifestDuplicateDescriptor(int descriptor) {
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
+        !PXBackupManifestDescriptorHasCloseOnExec(duplicated)) {
+        close(duplicated);
+        return -1;
+    }
+    return duplicated;
+}
+
+static BOOL PXBackupManifestStrictSync(int descriptor) {
+    if (descriptor < 0) return NO;
+    int result = -1;
+    do {
+        result = fsync(descriptor);
+    } while (result < 0 && errno == EINTR);
+    return result == 0;
+}
+
+static BOOL PXBackupManifestStringContainsNUL(NSString *value) {
+    if (![value isKindOfClass:[NSString class]]) return YES;
+    for (NSUInteger index = 0; index < value.length; index++) {
+        if ([value characterAtIndex:index] == 0) return YES;
+    }
+    return NO;
+}
+
+static NSData *PXBackupManifestLosslessUTF8Data(NSString *value) {
+    if (![value isKindOfClass:[NSString class]] ||
+        value.length == 0 ||
+        PXBackupManifestStringContainsNUL(value)) return nil;
+    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding
+                       allowLossyConversion:NO];
+    if (!data || data.length == 0 || data.length > PXBackupManifestMaximumPathBytes) {
+        return nil;
+    }
+    NSString *roundTrip = [[NSString alloc] initWithData:data
+                                                encoding:NSUTF8StringEncoding];
+    if (!roundTrip || ![roundTrip isEqualToString:value]) return nil;
+    return data;
+}
+
+static char *PXBackupManifestCopyCString(NSData *data) {
+    if (![data isKindOfClass:[NSData class]] || data.length == 0 ||
+        data.length > SIZE_MAX - 1) return NULL;
+    char *bytes = calloc(data.length + 1, 1);
+    if (!bytes) return NULL;
+    memcpy(bytes, data.bytes, data.length);
+    return bytes;
+}
+
+static NSString *PXBackupManifestHexDigest(const unsigned char *digest,
+                                           size_t length) {
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
+static BOOL PXBackupManifestGenerateTemporaryName(char *buffer,
+                                                   size_t bufferSize,
+                                                   NSString **nameOut) {
+    if (nameOut) *nameOut = nil;
+    const size_t prefixLength = sizeof(PXBackupManifestTemporaryFilePrefixBytes) - 1;
+    const size_t suffixCharacters = PXBackupManifestRandomSuffixBytes * 2;
+    const size_t required = prefixLength + suffixCharacters + 1;
+    if (!buffer || bufferSize < required) return NO;
+    unsigned char randomBytes[PXBackupManifestRandomSuffixBytes];
+    arc4random_buf(randomBytes, sizeof(randomBytes));
+    static const char alphabet[] = "0123456789abcdef";
+    memcpy(buffer, PXBackupManifestTemporaryFilePrefixBytes, prefixLength);
+    for (size_t index = 0; index < sizeof(randomBytes); index++) {
+        buffer[prefixLength + (index * 2)] =
+            alphabet[(randomBytes[index] >> 4) & 0x0f];
+        buffer[prefixLength + (index * 2) + 1] =
+            alphabet[randomBytes[index] & 0x0f];
+    }
+    buffer[required - 1] = '\0';
+    NSString *name = [[NSString alloc] initWithBytes:buffer
+                                              length:required - 1
+                                            encoding:NSASCIIStringEncoding];
+    if (!name || ![name hasPrefix:PXBackupManifestTemporaryFilePrefix] ||
+        name.length != PXBackupManifestTemporaryFilePrefix.length + 32) return NO;
+    if (nameOut) *nameOut = name;
+    return YES;
+}
+
+static BOOL PXBackupManifestScanTemporaryEntries(int workspaceDescriptor,
+                                                  const char *allowedName,
+                                                  NSUInteger *temporaryCountOut) {
+    if (temporaryCountOut) *temporaryCountOut = 0;
+    int duplicated = PXBackupManifestDuplicateDescriptor(workspaceDescriptor);
+    if (duplicated < 0) return NO;
+    DIR *directory = fdopendir(duplicated);
+    if (!directory) {
+        close(duplicated);
+        return NO;
+    }
+    const size_t prefixLength = sizeof(PXBackupManifestTemporaryFilePrefixBytes) - 1;
+    NSUInteger temporaryCount = 0;
+    BOOL valid = YES;
+    errno = 0;
+    struct dirent *entry = NULL;
+    while ((entry = readdir(directory)) != NULL) {
+        if (strncmp(entry->d_name,
+                    PXBackupManifestTemporaryFilePrefixBytes,
+                    prefixLength) != 0) continue;
+        if (temporaryCount == NSUIntegerMax) {
+            valid = NO;
+            break;
+        }
+        temporaryCount += 1;
+        if (!allowedName || strcmp(entry->d_name, allowedName) != 0 ||
+            temporaryCount > PXBackupManifestMaximumOwnedTemporaryEntries) {
+            valid = NO;
+            break;
+        }
+    }
+    if (!entry && errno != 0) valid = NO;
+    if (closedir(directory) != 0) valid = NO;
+    if (temporaryCountOut) *temporaryCountOut = temporaryCount;
+    return valid;
+}
+
+static BOOL PXBackupManifestWorkspacePathMatchesDescriptor(
+    NSString *workspacePath,
+    int descriptor,
+    const struct stat *expected,
+    struct stat *currentOut) {
+    NSData *pathData = PXBackupManifestLosslessUTF8Data(workspacePath);
+    char *pathBytes = PXBackupManifestCopyCString(pathData);
+    if (!pathBytes) return NO;
+    struct stat pathStat;
+    struct stat descriptorStat;
+    BOOL valid = lstat(pathBytes, &pathStat) == 0 &&
+                 !S_ISLNK(pathStat.st_mode) &&
+                 S_ISDIR(pathStat.st_mode) &&
+                 (pathStat.st_mode & 07777) == 0700 &&
+                 fstat(descriptor, &descriptorStat) == 0 &&
+                 S_ISDIR(descriptorStat.st_mode) &&
+                 (descriptorStat.st_mode & 07777) == 0700 &&
+                 PXBackupManifestStatIdentityMatches(&pathStat, &descriptorStat) &&
+                 (!expected ||
+                  PXBackupManifestStatIdentityMatches(expected, &descriptorStat)) &&
+                 PXBackupManifestDescriptorHasCloseOnExec(descriptor);
+    free(pathBytes);
+    if (valid && currentOut) *currentOut = descriptorStat;
+    return valid;
+}
+
+static BOOL PXBackupManifestFinalNameIsAbsent(int workspaceDescriptor) {
+    struct stat namespaceStat;
+    if (fstatat(workspaceDescriptor,
+                PXBackupManifestFinalFileNameBytes,
+                &namespaceStat,
+                AT_SYMLINK_NOFOLLOW) == 0) return NO;
+    return errno == ENOENT;
+}
+
+static BOOL PXBackupManifestFileBindingValid(int workspaceDescriptor,
+                                             const char *name,
+                                             int descriptor,
+                                             const struct stat *expected,
+                                             unsigned long long expectedSize,
+                                             BOOL requireStableMetadata,
+                                             struct stat *currentOut) {
+    if (workspaceDescriptor < 0 || !name || descriptor < 0 ||
+        expectedSize > (unsigned long long)LLONG_MAX) return NO;
+    struct stat namespaceStat;
+    struct stat descriptorStat;
+    if (fstatat(workspaceDescriptor,
+                name,
+                &namespaceStat,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        !S_ISREG(namespaceStat.st_mode) ||
+        namespaceStat.st_nlink != 1 ||
+        (namespaceStat.st_mode & 07777) != 0600 ||
+        fstat(descriptor, &descriptorStat) != 0 ||
+        !S_ISREG(descriptorStat.st_mode) ||
+        descriptorStat.st_nlink != 1 ||
+        (descriptorStat.st_mode & 07777) != 0600 ||
+        descriptorStat.st_size < 0 ||
+        (unsigned long long)descriptorStat.st_size != expectedSize ||
+        namespaceStat.st_size != descriptorStat.st_size ||
+        descriptorStat.st_dev != namespaceStat.st_dev ||
+        !PXBackupManifestStatIdentityMatches(&namespaceStat, &descriptorStat) ||
+        (expected &&
+         !(requireStableMetadata
+             ? PXBackupManifestStableFileStatMatches(expected, &descriptorStat)
+             : PXBackupManifestStatIdentityMatches(expected, &descriptorStat))) ||
+        !PXBackupManifestDescriptorHasCloseOnExec(descriptor)) return NO;
+    if (currentOut) *currentOut = descriptorStat;
+    return YES;
+}
+
+static BOOL PXBackupManifestReadUnsignedIntegral(id value,
+                                                 unsigned long long *valueOut) {
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
+static BOOL PXBackupManifestSnapshotMatches(
+    NSDictionary *parsed,
+    PXBackupManifestV4 *snapshot) {
+    if (![parsed isKindOfClass:[NSDictionary class]] ||
+        ![snapshot isMemberOfClass:[PXBackupManifestV4 class]] ||
+        ![parsed isEqualToDictionary:snapshot.manifestRepresentation]) return NO;
+    NSString *backupIdentifier = parsed[@"backupID"];
+    NSString *checksum = parsed[@"archiveChecksum"];
+    unsigned long long artifactCount = 0;
+    unsigned long long totalSize = 0;
+    if (![backupIdentifier isKindOfClass:[NSString class]] ||
+        ![backupIdentifier isEqualToString:snapshot.backupIdentifier] ||
+        ![checksum isKindOfClass:[NSString class]] ||
+        ![checksum isEqualToString:snapshot.applicationDataChecksum] ||
+        !PXBackupManifestReadUnsignedIntegral(parsed[@"artifactCount"],
+                                              &artifactCount) ||
+        artifactCount != (unsigned long long)snapshot.artifactCount ||
+        !PXBackupManifestReadUnsignedIntegral(parsed[@"totalSize"],
+                                              &totalSize) ||
+        totalSize != snapshot.totalSize) return NO;
+    return YES;
+}
+
+static NSDictionary *PXBackupManifestParseData(NSData *data) {
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
+static NSData *PXBackupManifestSerializeSnapshot(PXBackupManifestV4 *snapshot) {
+    if (![snapshot isMemberOfClass:[PXBackupManifestV4 class]]) return nil;
+    NSData *data = nil;
+    @try {
+        data = [NSPropertyListSerialization
+            dataWithPropertyList:snapshot.manifestRepresentation
+                          format:NSPropertyListBinaryFormat_v1_0
+                         options:0
+                           error:NULL];
+    } @catch (NSException *exception) {
+        (void)exception;
+        data = nil;
+    }
+    return [data isKindOfClass:[NSData class]] ? data : nil;
+}
+
+static BOOL PXBackupManifestReadDescriptor(int descriptor,
+                                           const struct stat *expectedIdentity,
+                                           unsigned long long expectedSize,
+                                           NSData **dataOut,
+                                           NSString **digestOut,
+                                           struct stat *stableIdentityOut) {
+    if (dataOut) *dataOut = nil;
+    if (digestOut) *digestOut = nil;
+    if (descriptor < 0 || !expectedIdentity ||
+        expectedSize == 0 ||
+        expectedSize > PXBackupManifestMaximumSerializedBytes ||
+        expectedSize > NSUIntegerMax ||
+        expectedSize > (unsigned long long)LLONG_MAX) return NO;
+    struct stat before;
+    if (fstat(descriptor, &before) != 0 ||
+        !PXBackupManifestStableFileStatMatches(expectedIdentity, &before) ||
+        before.st_size < 0 ||
+        (unsigned long long)before.st_size != expectedSize) return NO;
+    off_t seekResult = (off_t)-1;
+    do {
+        seekResult = lseek(descriptor, 0, SEEK_SET);
+    } while (seekResult < 0 && errno == EINTR);
+    if (seekResult != 0) return NO;
+
+    NSMutableData *mutableData = nil;
+    @try {
+        mutableData = [NSMutableData dataWithLength:(NSUInteger)expectedSize];
+    } @catch (NSException *exception) {
+        (void)exception;
+        mutableData = nil;
+    }
+    if (!mutableData || mutableData.length != (NSUInteger)expectedSize) return NO;
+
+    CC_SHA256_CTX context;
+    if (CC_SHA256_Init(&context) != 1) return NO;
+    unsigned long long offset = 0;
+    unsigned char buffer[PXBackupManifestReadBufferBytes];
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
+
+    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
+    if (CC_SHA256_Final(digest, &context) != 1) return NO;
+    NSString *digestString = PXBackupManifestHexDigest(digest,
+                                                        sizeof(digest));
+    struct stat after;
+    if (!digestString || fstat(descriptor, &after) != 0 ||
+        !PXBackupManifestStableFileStatMatches(&before, &after)) return NO;
+    NSData *immutableData = [mutableData copy];
+    if (!immutableData || immutableData.length != mutableData.length) return NO;
+    if (dataOut) *dataOut = immutableData;
+    if (digestOut) *digestOut = digestString;
+    if (stableIdentityOut) *stableIdentityOut = after;
+    return YES;
+}
+
+static BOOL PXBackupManifestFullWrite(int descriptor, NSData *data) {
+    if (descriptor < 0 || ![data isKindOfClass:[NSData class]] ||
+        data.length == 0 || data.length > PXBackupManifestMaximumSerializedBytes) {
+        return NO;
+    }
+    const unsigned char *bytes = data.bytes;
+    NSUInteger offset = 0;
+    while (offset < data.length) {
+        NSUInteger remaining = data.length - offset;
+        ssize_t count = -1;
+        do {
+            count = write(descriptor, bytes + offset, remaining);
+        } while (count < 0 && errno == EINTR);
+        if (count <= 0 || (NSUInteger)count > remaining) return NO;
+        offset += (NSUInteger)count;
+    }
+    return offset == data.length;
+}
+
+static BOOL PXBackupManifestRemoveExactFile(int workspaceDescriptor,
+                                            const char *name,
+                                            int descriptor,
+                                            const struct stat *expected,
+                                            NSUInteger *cleanupEntries) {
+    if (!cleanupEntries || *cleanupEntries >= PXBackupManifestMaximumCleanupEntries ||
+        workspaceDescriptor < 0 || !name || descriptor < 0 || !expected) return NO;
+    struct stat namespaceStat;
+    struct stat descriptorStat;
+    if (fstatat(workspaceDescriptor,
+                name,
+                &namespaceStat,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        !S_ISREG(namespaceStat.st_mode) ||
+        namespaceStat.st_nlink != 1 ||
+        (namespaceStat.st_mode & 07777) != 0600 ||
+        fstat(descriptor, &descriptorStat) != 0 ||
+        !S_ISREG(descriptorStat.st_mode) ||
+        descriptorStat.st_nlink != 1 ||
+        (descriptorStat.st_mode & 07777) != 0600 ||
+        !PXBackupManifestStatIdentityMatches(expected, &namespaceStat) ||
+        !PXBackupManifestStatIdentityMatches(expected, &descriptorStat) ||
+        !PXBackupManifestStatIdentityMatches(&namespaceStat, &descriptorStat)) return NO;
+    if (unlinkat(workspaceDescriptor, name, 0) != 0) return NO;
+    *cleanupEntries += 1;
+    return PXBackupManifestStrictSync(workspaceDescriptor);
+}
+
+@interface PXBackupManifestWriter ()
+
+- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
+                    workspacePath:(NSString *)workspacePath
+              workspaceDescriptor:(int)workspaceDescriptor
+                workspaceIdentity:(const struct stat *)workspaceIdentity;
+
+@end
+
+@implementation PXBackupManifestWriter {
+    PXBackupPublicationWorkspace *_workspace;
+    NSString *_workspacePath;
+    NSString *_manifestPath;
+    BOOL _manifestWritten;
+    BOOL _writeAttempted;
+    unsigned long long _manifestSize;
+    NSString *_manifestSHA256;
+    NSDictionary<NSString *, id> *_manifestRepresentation;
+    int _workspaceDescriptor;
+    int _finalDescriptor;
+    struct stat _workspaceIdentity;
+    struct stat _finalIdentity;
+}
+
++ (nullable instancetype)writerForWorkspace:(PXBackupPublicationWorkspace *)workspace
+                                      error:(NSError **)error {
+    if (error) *error = nil;
+    if (![workspace isMemberOfClass:[PXBackupPublicationWorkspace class]]) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorInvalidInput,
+                                 PXBackupManifestWorkspaceField,
+                                 @"The manifest workspace is invalid");
+        return nil;
+    }
+    NSError *workspaceError = nil;
+    if (![workspace validateIdentityWithError:&workspaceError]) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorWorkspaceValidationFailed,
+                                 PXBackupManifestWorkspaceField,
+                                 @"The manifest workspace failed validation");
+        return nil;
+    }
+    NSString *workspacePath = workspace.workspacePath;
+    NSData *workspacePathData = PXBackupManifestLosslessUTF8Data(workspacePath);
+    char *workspacePathBytes = PXBackupManifestCopyCString(workspacePathData);
+    if (!workspacePathBytes) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorLimitExceeded,
+                                 PXBackupManifestWorkspaceField,
+                                 @"The manifest workspace path exceeds limits");
+        return nil;
+    }
+    struct stat pathStat;
+    struct stat descriptorStat;
+    int workspaceDescriptor = -1;
+    PXBackupManifestWriter *writer = nil;
+    if (lstat(workspacePathBytes, &pathStat) != 0 ||
+        S_ISLNK(pathStat.st_mode) ||
+        !S_ISDIR(pathStat.st_mode) ||
+        (pathStat.st_mode & 07777) != 0700) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorWorkspaceInspectionFailed,
+                                 PXBackupManifestWorkspaceField,
+                                 @"The manifest workspace could not be inspected safely");
+        goto cleanup;
+    }
+    workspaceDescriptor = open(workspacePathBytes,
+                               O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (workspaceDescriptor < 0 ||
+        fstat(workspaceDescriptor, &descriptorStat) != 0 ||
+        !S_ISDIR(descriptorStat.st_mode) ||
+        (descriptorStat.st_mode & 07777) != 0700 ||
+        !PXBackupManifestStatIdentityMatches(&pathStat, &descriptorStat) ||
+        !PXBackupManifestDescriptorHasCloseOnExec(workspaceDescriptor)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorWorkspaceInspectionFailed,
+                                 PXBackupManifestWorkspaceField,
+                                 @"The manifest workspace descriptor is invalid");
+        goto cleanup;
+    }
+    workspaceError = nil;
+    if (![workspace validateIdentityWithError:&workspaceError] ||
+        !PXBackupManifestWorkspacePathMatchesDescriptor(workspacePath,
+                                                        workspaceDescriptor,
+                                                        &descriptorStat,
+                                                        NULL)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorWorkspaceValidationFailed,
+                                 PXBackupManifestWorkspaceField,
+                                 @"The manifest workspace identity changed");
+        goto cleanup;
+    }
+    if (!PXBackupManifestFinalNameIsAbsent(workspaceDescriptor)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorFinalManifestAlreadyExists,
+                                 PXBackupManifestField,
+                                 @"A final manifest already exists");
+        goto cleanup;
+    }
+    NSUInteger temporaryCount = 0;
+    if (!PXBackupManifestScanTemporaryEntries(workspaceDescriptor,
+                                              NULL,
+                                              &temporaryCount) ||
+        temporaryCount != 0) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorWorkspaceInspectionFailed,
+                                 PXBackupManifestTemporaryField,
+                                 @"The manifest workspace contains an unexpected temporary entry");
+        goto cleanup;
+    }
+    writer = [[PXBackupManifestWriter alloc]
+        initWithWorkspace:workspace
+            workspacePath:workspacePath
+      workspaceDescriptor:workspaceDescriptor
+        workspaceIdentity:&descriptorStat];
+    if (!writer) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorWorkspaceInspectionFailed,
+                                 PXBackupManifestWorkspaceField,
+                                 @"The manifest writer could not retain the workspace");
+        goto cleanup;
+    }
+    workspaceDescriptor = -1;
+
+cleanup:
+    free(workspacePathBytes);
+    if (workspaceDescriptor >= 0) close(workspaceDescriptor);
+    return writer;
+}
+
+- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
+                    workspacePath:(NSString *)workspacePath
+              workspaceDescriptor:(int)workspaceDescriptor
+                workspaceIdentity:(const struct stat *)workspaceIdentity {
+    self = [super init];
+    if (self) {
+        _workspace = workspace;
+        _workspacePath = [workspacePath copy];
+        _workspaceDescriptor = workspaceDescriptor;
+        _finalDescriptor = -1;
+        if (workspaceIdentity) _workspaceIdentity = *workspaceIdentity;
+    }
+    return self;
+}
+
+- (NSString *)workspacePath { return _workspacePath; }
+- (NSString *)manifestPath { return _manifestPath; }
+- (BOOL)isManifestWritten { return _manifestWritten; }
+- (unsigned long long)manifestSize { return _manifestSize; }
+- (NSString *)manifestSHA256 { return _manifestSHA256; }
+- (NSDictionary<NSString *,id> *)manifestRepresentation {
+    return _manifestRepresentation;
+}
+
+- (BOOL)validateIdentityWithError:(NSError **)error {
+    if (error) *error = nil;
+    NSError *workspaceError = nil;
+    struct stat workspaceStat;
+    if (![_workspace validateIdentityWithError:&workspaceError] ||
+        !PXBackupManifestWorkspacePathMatchesDescriptor(_workspacePath,
+                                                        _workspaceDescriptor,
+                                                        &_workspaceIdentity,
+                                                        &workspaceStat)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorWorkspaceValidationFailed,
+                                 PXBackupManifestWorkspaceField,
+                                 @"The manifest workspace identity is invalid");
+        return NO;
+    }
+    NSUInteger temporaryCount = 0;
+    if (!PXBackupManifestScanTemporaryEntries(_workspaceDescriptor,
+                                              NULL,
+                                              &temporaryCount) ||
+        temporaryCount != 0) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorFilesystemChanged,
+                                 PXBackupManifestTemporaryField,
+                                 @"The manifest temporary namespace changed");
+        return NO;
+    }
+    if (!_manifestWritten) {
+        if (_finalDescriptor >= 0 || _manifestSize != 0 ||
+            _manifestSHA256 != nil || _manifestRepresentation != nil ||
+            _manifestPath != nil ||
+            !PXBackupManifestFinalNameIsAbsent(_workspaceDescriptor)) {
+            PXBackupManifestSetError(error,
+                                     PXBackupManifestWriterErrorFilesystemChanged,
+                                     PXBackupManifestField,
+                                     @"The unwritten manifest state is inconsistent");
+            return NO;
+        }
+        return YES;
+    }
+    if (_finalDescriptor < 0 || _manifestSize == 0 ||
+        ![_manifestSHA256 isKindOfClass:[NSString class]] ||
+        ![_manifestRepresentation isKindOfClass:[NSDictionary class]] ||
+        ![_manifestPath isKindOfClass:[NSString class]] ||
+        ![_manifestPath isEqualToString:
+            [_workspacePath stringByAppendingPathComponent:PXBackupManifestFinalFileName]]) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorFilesystemChanged,
+                                 PXBackupManifestField,
+                                 @"The retained manifest state is inconsistent");
+        return NO;
+    }
+    struct stat finalStat;
+    if (!PXBackupManifestFileBindingValid(_workspaceDescriptor,
+                                          PXBackupManifestFinalFileNameBytes,
+                                          _finalDescriptor,
+                                          &_finalIdentity,
+                                          _manifestSize,
+                                          YES,
+                                          &finalStat)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorFilesystemChanged,
+                                 PXBackupManifestField,
+                                 @"The retained manifest identity changed");
+        return NO;
+    }
+    NSData *data = nil;
+    NSString *digest = nil;
+    struct stat stableIdentity;
+    if (!PXBackupManifestReadDescriptor(_finalDescriptor,
+                                        &finalStat,
+                                        _manifestSize,
+                                        &data,
+                                        &digest,
+                                        &stableIdentity) ||
+        ![digest isEqualToString:_manifestSHA256]) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorReadBackFailed,
+                                 PXBackupManifestField,
+                                 @"The retained manifest content changed");
+        return NO;
+    }
+    NSDictionary *parsed = PXBackupManifestParseData(data);
+    NSError *validationError = nil;
+    if (!parsed ||
+        ![PXBackupManifestValidator validateManifestObject:parsed
+                                                     error:&validationError]) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorValidationFailed,
+                                 PXBackupManifestSnapshotField,
+                                 @"The retained manifest failed validation");
+        return NO;
+    }
+    if (![parsed isEqualToDictionary:_manifestRepresentation]) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorSnapshotMismatch,
+                                 PXBackupManifestSnapshotField,
+                                 @"The retained manifest does not match the accepted snapshot");
+        return NO;
+    }
+    return YES;
+}
+
+- (BOOL)writeManifestSnapshot:(PXBackupManifestV4 *)manifestSnapshot
+                        error:(NSError **)error {
+    if (error) *error = nil;
+    if (![manifestSnapshot isMemberOfClass:[PXBackupManifestV4 class]]) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorInvalidInput,
+                                 PXBackupManifestSnapshotField,
+                                 @"The manifest snapshot is invalid");
+        return NO;
+    }
+    if (_writeAttempted || _manifestWritten) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorManifestAlreadyWritten,
+                                 PXBackupManifestField,
+                                 @"The manifest writer has already been used");
+        return NO;
+    }
+    NSError *identityError = nil;
+    if (![self validateIdentityWithError:&identityError]) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorWorkspaceValidationFailed,
+                                 PXBackupManifestWorkspaceField,
+                                 @"The manifest writer identity is invalid");
+        return NO;
+    }
+    _writeAttempted = YES;
+
+    BOOL accepted = NO;
+    BOOL renamed = NO;
+    BOOL temporaryCreated = NO;
+    NSUInteger cleanupEntries = 0;
+    int temporaryDescriptor = -1;
+    int finalDescriptor = -1;
+    char temporaryName[(sizeof(PXBackupManifestTemporaryFilePrefixBytes) - 1) +
+                       (PXBackupManifestRandomSuffixBytes * 2) + 1];
+    memset(temporaryName, 0, sizeof(temporaryName));
+    NSString *temporaryNameString = nil;
+    NSData *serializedData = nil;
+    NSData *preRenameData = nil;
+    NSString *preRenameDigest = nil;
+    NSDictionary *preRenameManifest = nil;
+    NSError *preRenameValidationError = nil;
+    NSData *postRenameData = nil;
+    NSString *postRenameDigest = nil;
+    NSDictionary *postRenameManifest = nil;
+    NSError *postRenameValidationError = nil;
+    struct stat temporaryIdentity;
+    struct stat writtenIdentity;
+    struct stat publishedIdentity;
+    memset(&temporaryIdentity, 0, sizeof(temporaryIdentity));
+    memset(&writtenIdentity, 0, sizeof(writtenIdentity));
+    memset(&publishedIdentity, 0, sizeof(publishedIdentity));
+
+    serializedData = PXBackupManifestSerializeSnapshot(manifestSnapshot);
+    if (!serializedData) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorSerializationFailed,
+                                 PXBackupManifestSnapshotField,
+                                 @"The manifest snapshot could not be serialized");
+        goto cleanup;
+    }
+    if (serializedData.length == 0 ||
+        serializedData.length > PXBackupManifestMaximumSerializedBytes) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorLimitExceeded,
+                                 PXBackupManifestSnapshotField,
+                                 @"The serialized manifest exceeds fixed limits");
+        goto cleanup;
+    }
+    if (!PXBackupManifestFinalNameIsAbsent(_workspaceDescriptor)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorFinalManifestAlreadyExists,
+                                 PXBackupManifestField,
+                                 @"A final manifest already exists");
+        goto cleanup;
+    }
+
+    for (NSUInteger attempt = 0;
+         attempt < PXBackupManifestTemporaryCreationAttempts;
+         attempt++) {
+        temporaryNameString = nil;
+        if (!PXBackupManifestGenerateTemporaryName(temporaryName,
+                                                   sizeof(temporaryName),
+                                                   &temporaryNameString)) {
+            PXBackupManifestSetError(error,
+                                     PXBackupManifestWriterErrorTemporaryCreationFailed,
+                                     PXBackupManifestTemporaryField,
+                                     @"A temporary manifest name could not be generated");
+            goto cleanup;
+        }
+        temporaryDescriptor = openat(_workspaceDescriptor,
+                                     temporaryName,
+                                     O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
+                                     0600);
+        if (temporaryDescriptor >= 0) break;
+        if (errno != EEXIST) {
+            PXBackupManifestSetError(error,
+                                     PXBackupManifestWriterErrorTemporaryCreationFailed,
+                                     PXBackupManifestTemporaryField,
+                                     @"The temporary manifest could not be created");
+            goto cleanup;
+        }
+    }
+    if (temporaryDescriptor < 0) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorTemporaryCreationFailed,
+                                 PXBackupManifestTemporaryField,
+                                 @"The temporary manifest name retry limit was reached");
+        goto cleanup;
+    }
+    temporaryCreated = YES;
+    if (fchmod(temporaryDescriptor, 0600) != 0 ||
+        fstat(temporaryDescriptor, &temporaryIdentity) != 0 ||
+        !S_ISREG(temporaryIdentity.st_mode) ||
+        temporaryIdentity.st_nlink != 1 ||
+        (temporaryIdentity.st_mode & 07777) != 0600 ||
+        temporaryIdentity.st_size != 0 ||
+        temporaryIdentity.st_dev != _workspaceIdentity.st_dev ||
+        !PXBackupManifestDescriptorHasCloseOnExec(temporaryDescriptor) ||
+        !PXBackupManifestFileBindingValid(_workspaceDescriptor,
+                                          temporaryName,
+                                          temporaryDescriptor,
+                                          &temporaryIdentity,
+                                          0,
+                                          NO,
+                                          NULL)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorFilesystemChanged,
+                                 PXBackupManifestTemporaryField,
+                                 @"The temporary manifest identity is invalid");
+        goto cleanup;
+    }
+    NSUInteger temporaryCount = 0;
+    if (!PXBackupManifestScanTemporaryEntries(_workspaceDescriptor,
+                                              temporaryName,
+                                              &temporaryCount) ||
+        temporaryCount != 1) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorFilesystemChanged,
+                                 PXBackupManifestTemporaryField,
+                                 @"The temporary manifest namespace is invalid");
+        goto cleanup;
+    }
+    if (!PXBackupManifestFullWrite(temporaryDescriptor, serializedData)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorWriteFailed,
+                                 PXBackupManifestTemporaryField,
+                                 @"The manifest bytes could not be written completely");
+        goto cleanup;
+    }
+    if (fstat(temporaryDescriptor, &writtenIdentity) != 0 ||
+        !S_ISREG(writtenIdentity.st_mode) ||
+        writtenIdentity.st_nlink != 1 ||
+        (writtenIdentity.st_mode & 07777) != 0600 ||
+        writtenIdentity.st_size < 0 ||
+        (unsigned long long)writtenIdentity.st_size !=
+            (unsigned long long)serializedData.length ||
+        writtenIdentity.st_dev != _workspaceIdentity.st_dev ||
+        !PXBackupManifestStatIdentityMatches(&temporaryIdentity,
+                                             &writtenIdentity) ||
+        !PXBackupManifestFileBindingValid(_workspaceDescriptor,
+                                          temporaryName,
+                                          temporaryDescriptor,
+                                          &writtenIdentity,
+                                          (unsigned long long)serializedData.length,
+                                          YES,
+                                          NULL)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorFilesystemChanged,
+                                 PXBackupManifestTemporaryField,
+                                 @"The written temporary manifest identity changed");
+        goto cleanup;
+    }
+    if (!PXBackupManifestStrictSync(temporaryDescriptor) ||
+        !PXBackupManifestStrictSync(_workspaceDescriptor)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorDurabilityFailed,
+                                 PXBackupManifestTemporaryField,
+                                 @"The temporary manifest could not be synchronized");
+        goto cleanup;
+    }
+
+    struct stat preRenameIdentity;
+    if (!PXBackupManifestReadDescriptor(temporaryDescriptor,
+                                        &writtenIdentity,
+                                        (unsigned long long)serializedData.length,
+                                        &preRenameData,
+                                        &preRenameDigest,
+                                        &preRenameIdentity)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorReadBackFailed,
+                                 PXBackupManifestTemporaryField,
+                                 @"The temporary manifest could not be read back exactly");
+        goto cleanup;
+    }
+    preRenameManifest = PXBackupManifestParseData(preRenameData);
+    preRenameValidationError = nil;
+    if (!preRenameManifest ||
+        ![PXBackupManifestValidator validateManifestObject:preRenameManifest
+                                                     error:&preRenameValidationError]) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorValidationFailed,
+                                 PXBackupManifestSnapshotField,
+                                 @"The temporary manifest failed validation");
+        goto cleanup;
+    }
+    if (!PXBackupManifestSnapshotMatches(preRenameManifest, manifestSnapshot)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorSnapshotMismatch,
+                                 PXBackupManifestSnapshotField,
+                                 @"The temporary manifest does not match the accepted snapshot");
+        goto cleanup;
+    }
+
+    identityError = nil;
+    if (![_workspace validateIdentityWithError:&identityError] ||
+        !PXBackupManifestWorkspacePathMatchesDescriptor(_workspacePath,
+                                                        _workspaceDescriptor,
+                                                        &_workspaceIdentity,
+                                                        NULL) ||
+        !PXBackupManifestFileBindingValid(_workspaceDescriptor,
+                                          temporaryName,
+                                          temporaryDescriptor,
+                                          &preRenameIdentity,
+                                          (unsigned long long)serializedData.length,
+                                          YES,
+                                          NULL) ||
+        !PXBackupManifestFinalNameIsAbsent(_workspaceDescriptor)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorFilesystemChanged,
+                                 PXBackupManifestField,
+                                 @"The manifest namespace changed before finalization");
+        goto cleanup;
+    }
+    if (renameat(_workspaceDescriptor,
+                 temporaryName,
+                 _workspaceDescriptor,
+                 PXBackupManifestFinalFileNameBytes) != 0) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorFinalizationFailed,
+                                 PXBackupManifestField,
+                                 @"The manifest could not be finalized atomically");
+        goto cleanup;
+    }
+    renamed = YES;
+    if (fstat(temporaryDescriptor, &publishedIdentity) != 0 ||
+        !PXBackupManifestPublishedFileStatMatches(&preRenameIdentity,
+                                                  &publishedIdentity) ||
+        !PXBackupManifestFileBindingValid(_workspaceDescriptor,
+                                          PXBackupManifestFinalFileNameBytes,
+                                          temporaryDescriptor,
+                                          &publishedIdentity,
+                                          (unsigned long long)serializedData.length,
+                                          YES,
+                                          NULL) ||
+        !PXBackupManifestStrictSync(temporaryDescriptor) ||
+        !PXBackupManifestStrictSync(_workspaceDescriptor)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorDurabilityFailed,
+                                 PXBackupManifestField,
+                                 @"The finalized manifest could not be synchronized");
+        goto cleanup;
+    }
+    finalDescriptor = openat(_workspaceDescriptor,
+                             PXBackupManifestFinalFileNameBytes,
+                             O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+    if (finalDescriptor < 0 ||
+        !PXBackupManifestFileBindingValid(_workspaceDescriptor,
+                                          PXBackupManifestFinalFileNameBytes,
+                                          finalDescriptor,
+                                          &publishedIdentity,
+                                          (unsigned long long)serializedData.length,
+                                          YES,
+                                          NULL)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorFinalizationFailed,
+                                 PXBackupManifestField,
+                                 @"The finalized manifest descriptor is invalid");
+        goto cleanup;
+    }
+    close(temporaryDescriptor);
+    temporaryDescriptor = -1;
+
+    struct stat postRenameIdentity;
+    if (!PXBackupManifestReadDescriptor(finalDescriptor,
+                                        &publishedIdentity,
+                                        (unsigned long long)serializedData.length,
+                                        &postRenameData,
+                                        &postRenameDigest,
+                                        &postRenameIdentity) ||
+        ![postRenameDigest isEqualToString:preRenameDigest]) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorReadBackFailed,
+                                 PXBackupManifestField,
+                                 @"The finalized manifest could not be read back exactly");
+        goto cleanup;
+    }
+    postRenameManifest = PXBackupManifestParseData(postRenameData);
+    postRenameValidationError = nil;
+    if (!postRenameManifest ||
+        ![PXBackupManifestValidator validateManifestObject:postRenameManifest
+                                                     error:&postRenameValidationError]) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorValidationFailed,
+                                 PXBackupManifestSnapshotField,
+                                 @"The finalized manifest failed validation");
+        goto cleanup;
+    }
+    if (!PXBackupManifestSnapshotMatches(postRenameManifest, manifestSnapshot)) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorSnapshotMismatch,
+                                 PXBackupManifestSnapshotField,
+                                 @"The finalized manifest does not match the accepted snapshot");
+        goto cleanup;
+    }
+    identityError = nil;
+    temporaryCount = 0;
+    if (![_workspace validateIdentityWithError:&identityError] ||
+        !PXBackupManifestWorkspacePathMatchesDescriptor(_workspacePath,
+                                                        _workspaceDescriptor,
+                                                        &_workspaceIdentity,
+                                                        NULL) ||
+        !PXBackupManifestFileBindingValid(_workspaceDescriptor,
+                                          PXBackupManifestFinalFileNameBytes,
+                                          finalDescriptor,
+                                          &postRenameIdentity,
+                                          (unsigned long long)serializedData.length,
+                                          YES,
+                                          NULL) ||
+        !PXBackupManifestScanTemporaryEntries(_workspaceDescriptor,
+                                              NULL,
+                                              &temporaryCount) ||
+        temporaryCount != 0) {
+        PXBackupManifestSetError(error,
+                                 PXBackupManifestWriterErrorFilesystemChanged,
+                                 PXBackupManifestField,
+                                 @"The finalized manifest identity changed");
+        goto cleanup;
+    }
+
+    _finalDescriptor = finalDescriptor;
+    finalDescriptor = -1;
+    _finalIdentity = postRenameIdentity;
+    _manifestSize = (unsigned long long)serializedData.length;
+    _manifestSHA256 = [postRenameDigest copy];
+    _manifestRepresentation = [manifestSnapshot.manifestRepresentation copy];
+    _manifestPath = [[_workspacePath
+        stringByAppendingPathComponent:PXBackupManifestFinalFileName] copy];
+    _manifestWritten = YES;
+    accepted = YES;
+    if (error) *error = nil;
+
+cleanup:
+    if (!accepted && temporaryCreated) {
+        int cleanupDescriptor = renamed
+            ? (finalDescriptor >= 0 ? finalDescriptor : temporaryDescriptor)
+            : temporaryDescriptor;
+        const char *cleanupName = renamed
+            ? PXBackupManifestFinalFileNameBytes
+            : temporaryName;
+        const struct stat *cleanupIdentity = renamed
+            ? (publishedIdentity.st_ino != 0 ? &publishedIdentity : &preRenameIdentity)
+            : (writtenIdentity.st_ino != 0 ? &writtenIdentity : &temporaryIdentity);
+        if (!PXBackupManifestRemoveExactFile(_workspaceDescriptor,
+                                             cleanupName,
+                                             cleanupDescriptor,
+                                             cleanupIdentity,
+                                             &cleanupEntries)) {
+            PXBackupManifestSetError(error,
+                                     PXBackupManifestWriterErrorCleanupFailed,
+                                     renamed ? PXBackupManifestField
+                                             : PXBackupManifestTemporaryField,
+                                     @"The failed manifest entry could not be removed safely");
+        }
+    }
+    if (temporaryDescriptor >= 0) close(temporaryDescriptor);
+    if (finalDescriptor >= 0) close(finalDescriptor);
+    return accepted;
+}
+
+- (void)dealloc {
+    if (_finalDescriptor >= 0) close(_finalDescriptor);
+    if (_workspaceDescriptor >= 0) close(_workspaceDescriptor);
+}
+
+@end
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -15,6 +15,7 @@
 #import "PXBackupArchiveValidator.h"
 #import "PXBackupBundleLock.h"
 #import "PXBackupArtifactWriter.h"
+#import "PXBackupManifestWriter.h"
 #import "PXBackupPublicationWorkspace.h"
 #import "PXRestorePlan.h"
 #import "PXAppGroupRestoreTargetPlan.h"
@@ -1766,6 +1767,24 @@
         if (![artifactWriter validateIdentityWithError:&initialArtifactWriterIdentityError]) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (completion) completion(nil, initialArtifactWriterIdentityError);
+            });
+            return;
+        }
+        NSError *manifestWriterError = nil;
+        __attribute__((objc_precise_lifetime))
+        PXBackupManifestWriter *manifestWriter =
+            [PXBackupManifestWriter writerForWorkspace:publicationWorkspace
+                                                  error:&manifestWriterError];
+        if (!manifestWriter) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, manifestWriterError);
+            });
+            return;
+        }
+        NSError *initialManifestWriterIdentityError = nil;
+        if (![manifestWriter validateIdentityWithError:&initialManifestWriterIdentityError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, initialManifestWriterIdentityError);
             });
             return;
         }
@@ -2391,13 +2410,6 @@
         NSString *iosVersion = device.systemVersion ?: @"";
         // profileId already computed above

-        NSError *preManifestArtifactWriterIdentityError = nil;
-        if (![artifactWriter validateIdentityWithError:&preManifestArtifactWriterIdentityError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, preManifestArtifactWriterIdentityError);
-            });
-            return;
-        }
         NSMutableArray<PXVerifiedBackupArtifact *> *verifiedArtifactRecords =
             [NSMutableArray array];
         [verifiedArtifactRecords addObject:dataArtifactRecord];
@@ -2516,6 +2528,13 @@
             });
             return;
         }
+        NSError *preManifestArtifactWriterIdentityError = nil;
+        if (![artifactWriter validateIdentityWithError:&preManifestArtifactWriterIdentityError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, preManifestArtifactWriterIdentityError);
+            });
+            return;
+        }

         // Debug snapshot: after backup artifacts
         {
@@ -2528,7 +2547,6 @@
             if (keychainBackupPath) {
                 PXDebugRun(runner, debugAfter, @"ls keychain.plist", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote(keychainBackupPath)]);
             }
-            PXDebugRun(runner, debugAfter, @"cat manifest.plist", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote([backupDir stringByAppendingPathComponent:@"manifest.plist"]) ]);
         }

         NSError *preManifestWorkspaceIdentityError = nil;
@@ -2545,13 +2563,34 @@
             });
             return;
         }
-        NSString *manifestPath = [backupDir stringByAppendingPathComponent:@"manifest.plist"];
-        if (![manifest writeToFile:manifestPath atomically:YES]) {
-            [warnings addObject:@"Failed to write manifest"];
-        } else {
-            [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true", PXShellQuote(manifestPath)]];
-        }
-
+        NSError *preWriteManifestWriterIdentityError = nil;
+        if (![manifestWriter validateIdentityWithError:&preWriteManifestWriterIdentityError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, preWriteManifestWriterIdentityError);
+            });
+            return;
+        }
+        NSError *manifestWriteError = nil;
+        if (![manifestWriter writeManifestSnapshot:manifestSnapshot
+                                              error:&manifestWriteError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, manifestWriteError);
+            });
+            return;
+        }
+        PXDebugRun(runner,
+                   debugAfter,
+                   @"cat manifest.plist",
+                   [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true",
+                    PXShellQuote(manifestWriter.manifestPath)]);
+
+        NSError *finalManifestWriterIdentityError = nil;
+        if (![manifestWriter validateIdentityWithError:&finalManifestWriterIdentityError]) {
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, finalManifestWriterIdentityError);
+            });
+            return;
+        }
         NSError *finalWorkspaceIdentityError = nil;
         if (![publicationWorkspace validateIdentityWithError:&finalWorkspaceIdentityError]) {
             dispatch_async(dispatch_get_main_queue(), ^{
@@ -2575,7 +2614,7 @@
         }
         PXBackupResult *out = [[PXBackupResult alloc] init];
         out.backupDirectory = publicationWorkspace.workspacePath;
-        out.manifestPath = [publicationWorkspace.workspacePath stringByAppendingPathComponent:@"manifest.plist"];
+        out.manifestPath = manifestWriter.manifestPath;
         out.warnings = warnings;

         dispatch_async(dispatch_get_main_queue(), ^{
```

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
