# TASK-3.9 Report — Centralize Backup Failure Cleanup

## Baseline and exact scope

Baseline: `e55e9d682a4b6d6de480f277f686a81e17b7498b`

Baseline evidence was captured before modification:

```text
host: DESKTOP-JATSMMU
HEAD: e55e9d682a4b6d6de480f277f686a81e17b7498b
git diff --check: clean
working tree: only pre-existing coordinator modifications/untracked task-review artifacts
```

Authorized implementation scope:

```text
A PXBackupFailureCleanup.h
A PXBackupFailureCleanup.m
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.9-REPORT.md
```

All other production diff is zero.

## Baseline 33-failure inventory

Baseline had 33 direct main-queue failure completions after workspace creation and zero operation-level cleanup calls. Current source has one funnel definition, one cleanupWithError call site and 33 funnel calls.

| # | Baseline exit | Current funnel expression |
|---:|---|---|
| 1 | initial workspace validation | `initialCleanupStageError` |
| 2 | artifact-writer factory | `artifactWriterError` |
| 3 | initial artifact-writer validation | `initialArtifactWriterIdentityError` |
| 4 | manifest-writer factory | `manifestWriterError` |
| 5 | initial manifest-writer validation | `initialManifestWriterIdentityError` |
| 6 | canonical policy construction | `err` |
| 7 | directory-publisher factory | `directoryPublisherError` |
| 8 | initial directory-publisher validation | `initialDirectoryPublisherIdentityError` |
| 9 | groups output-directory creation | `err` |
| 10 | required ApplicationData policy abort | `fatalPolicyError ?: err` |
| 11 | required ApplicationData invariant failure | `invariantError` |
| 12 | App Group invalid optional disposition | `fatalPolicyError` |
| 13 | ProfileAppData invalid optional disposition | `fatalPolicyError` |
| 14 | GlobalSafari invalid optional disposition | `fatalPolicyError` |
| 15 | Preferences invalid optional disposition | `fatalPolicyError` |
| 16 | Keychain invalid optional disposition | `fatalPolicyError` |
| 17 | SystemGlobal invalid optional disposition | `fatalPolicyError` |
| 18 | SharedSystemDatabase invalid optional disposition | `fatalPolicyError` |
| 19 | pre-manifest policy audit | `err` |
| 20 | v4 builder failure | `err` |
| 21 | manager-produced v4 validation | `producedManifestValidationError` |
| 22 | pre-manifest artifact-writer validation | `preManifestArtifactWriterIdentityError` |
| 23 | pre-manifest workspace validation | `preManifestWorkspaceIdentityError` |
| 24 | pre-manifest bundle-lock validation | `preManifestBundleLockValidationError` |
| 25 | pre-write manifest-writer validation | `preWriteManifestWriterIdentityError` |
| 26 | atomic manifest write | `manifestWriteError` |
| 27 | final manifest-writer validation | `finalManifestWriterIdentityError` |
| 28 | final workspace validation | `finalWorkspaceIdentityError` |
| 29 | final bundle-lock validation | `finalBundleLockValidationError` |
| 30 | final artifact-writer validation | `finalArtifactWriterIdentityError` |
| 31 | pre-publication publisher validation | `prePublicationDirectoryPublisherIdentityError` |
| 32 | directory publication or rollback failure | `directoryPublicationError` |
| 33 | post-publication validation or disarm stage | `postPublicationCleanupStageError` |

## Exact public API and sixteen errors

- exports: 2
- error codes: 16, contiguous 1 through 16
- subclassing-restricted classes: 1
- readonly properties: 6
- public readwrite properties: 0
- factories: 1
- cleanup methods: 1
- disarm methods: 1
- identity validation methods: 1

The enum is exactly InvalidInput=1 through FactoryCleanupFailed=16 with no gaps. No descriptor, arbitrary-path deletion, traversal-control, stale-cleanup or final-directory deletion API is public.

## Factory placement and authority

Manager ordering is workspace factory success → cleanup factory → cleanup validation → existing workspace validation → artifact writer → manifest writer → policies → publisher → outputs/debug/process kill/producers.

The factory requires exact workspace/lock runtime classes, matching bundle identity and canonical bundle directory, exact partial prefix, lossless bounded paths, no-follow/CLOEXEC parent and workspace descriptors, root mode 0700, same filesystem and path/namespace/descriptor identity.

If setup fails after exact authority is established, only the exact retained empty workspace may be removed and the parent must sync. If this proof or sync fails, FactoryCleanupFailed replaces the setup error and evidence is preserved. No recursive factory cleanup occurs.

## Bounded descriptor-relative traversal

| Limit | Value |
|---|---:|
| traversal depth | 64 |
| visited entries | 16,384 |
| component bytes | 255 |
| workspace path bytes | 4,096 |
| accumulated name bytes | 8 MiB |

There is exactly 1 fdopendir site and 1 readdir site. Traversal uses a duplicated CLOEXEC descriptor, exact readdir errno handling, fstatat(AT_SYMLINK_NOFOLLOW), openat(O_NOFOLLOW|O_CLOEXEC), post-order unlinkat and strict directory fsync.

No absolute child path is constructed. No realpath child traversal, NSFileManager, shell/process deletion or symlink following exists.

## Regular-file removal proof

A regular file must be same-filesystem, non-setid and nlink 1. Cleanup opens it O_RDONLY|O_NONBLOCK|O_NOFOLLOW|O_CLOEXEC, proves namespace/descriptor stable identity, revalidates immediately, unlinks descriptor-relatively, verifies namespace absence and retained descriptor nlink zero, then syncs the containing directory. Mutation accounting increments immediately after a successful unlink syscall so later proof/fsync failures become CleanupIncomplete.

## Directory removal proof

Directories are opened O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC, proved same-filesystem/non-setid/exact identity, recursively emptied within fixed limits, rescanned empty, synced, revalidated and removed post-order with AT_REMOVEDIR. Subdirectory mode 0700 is intentionally not required; only the root workspace must remain exactly 0700.

## Unsafe evidence and incomplete cleanup

Symlinks, FIFO/socket/device nodes, cross-filesystem entries, hard-linked files, setid entries, invalid/oversized names and identity-changed entries are never deleted or followed. Cleanup stops without fallback. If a prior verified unlink already occurred, the public error is CleanupIncomplete and removedEntryCount records the irreversible verified mutations.

## Root cleanup and strict durability

After children are gone, the workspace is rescanned empty, strict-synced, rebound to the original retained partial namespace, removed with unlinkat(parentFD, workspaceName, AT_REMOVEDIR), verified absent and followed by strict parent fsync. cleaned becomes YES only after every proof succeeds.

## Published-state and rollback behavior

An absent original partial name returns PublishedStateDetected. A present but nonmatching partial name returns WorkspaceChanged. Cleanup never searches for or deletes a timestamp/UUID final directory. Therefore rollback-failed final evidence and competing partial entries remain untouched. A successful TASK-3.8A reverse rollback restores the exact retained partial inode and is eligible for current-operation cleanup.

## Disarm contract

Disarm requires the exact published publisher, valid publisher identity, matching workspace path, a distinct nonempty published directory, manifest inside that directory, original partial absence, valid lock and unchanged parent. It opens/deletes no published path. Success sets disarmed=YES, cleaned=NO and closes cleanup-owned workspace/parent descriptors before result construction.

Disarm failure is routed through the same completion funnel in published-preservation mode: the exact disarm NSError is delivered and cleanup is not invoked against the final directory.

## Error privacy and precedence

Cleanup NSError userInfo contains only NSLocalizedDescriptionKey and PXBackupFailureCleanupErrorFieldPathKey. No paths, names, bundle IDs, inode/device values, errno text, removed counts or nested operation errors are exposed.

- cleanup succeeds: exact original NSError object is delivered
- cleanup fails: exact cleanup NSError replaces the operation error
- nil operation error: PXBackupErrorDomain code 108, ‘Backup failed without an error’
- cleanup returns NO with nil error: PXBackupErrorDomain code 109, ‘Backup failure cleanup failed without an error’
- all failure callbacks use one main-queue completion site

## Manager static proof

| Gate | Required | Actual |
|---|---:|---:|
| cleanup factory | 1 | 1 |
| cleanup validation | 1 | 1 |
| cleanupWithError call sites | 1 | 1 |
| disarm calls | 1 | 1 |
| failure-funnel definitions | 1 | 1 |
| failure-funnel calls | 33 | 33 |
| success completion calls | 1 | 1 |
| direct post-funnel failure completions | 0 | 0 |

## Success and Phase-3 non-regression

Success still uses directoryPublisher.publishedDirectoryPath and publishedManifestPath. Warning text/order, debug operations, process-kill/producer ordering, Preferences, Keychain, manifest v4, Restore and discovery are unchanged.

Retained counts: lock 1/4, workspace 1/3, artifact writer 1/3 with 8 writes, manifest writer 1/3 with 1 write, publisher 1/3/1, 8 policy constructions, 8 failure-policy calls, 1 policy audit, 1 v4 builder and 1 manager validator.

TASK-3.1 through TASK-3.8A infrastructure files are byte-identical to baseline, including the one renameatx_np(RENAME_EXCL) publisher site and zero plain publisher renameat sites.

## Protected production SHA-256 before/after

Protected production files: 308. Changed: 0.

| File | Before SHA-256 | After SHA-256 | Bytes |
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
| `PXBackupDirectoryPublisher.h` | `014be6af62da52efab0f442d93814a88634953dbc56ae38d24f932d873834e39` | `014be6af62da52efab0f442d93814a88634953dbc56ae38d24f932d873834e39` | 2889 |
| `PXBackupDirectoryPublisher.m` | `0f85750abf3ef1f2043be5af8708f340cccb20606188b09f63843cc5963d8223` | `0f85750abf3ef1f2043be5af8708f340cccb20606188b09f63843cc5963d8223` | 70795 |
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

## Authorized production artifact hashes

| File | SHA-256 | Bytes |
|---|---|---:|
| `PXBackupFailureCleanup.h` | `ee242afc8ca4aad39dcfe240e168bcc4d52e72abb63a835981f306c71f89466d` | 2377 |
| `PXBackupFailureCleanup.m` | `82480542d53bb039543b3f6d6ec6d284f2e7e6496403cb4ef8a6c27b6c09c399` | 60169 |
| `AppDataBackupManager.m` | `26cd00bb986b2c863ece70a3c54a4b6ada27e9b5a2d9c0efdc820d26a1862781` | 221656 |

## Static gate table

| Gate | Result |
|---|---|
| public API 2 exports / 16 codes / 1 class / 6 readonly | PASS (2/16/1/6) |
| one fdopendir/readdir traversal | PASS (1/1) |
| fstatat/openat/unlinkat sites audited | PASS (7/3/4) |
| NSFileManager/shell/process/dispatch in cleanup source | PASS (0) |
| cleanup automatic deletion in dealloc | PASS (0) |
| manager one funnel / 33 calls / one cleanup site | PASS |
| direct post-funnel failure completions | PASS (0) |
| warnings/debug sequence | PASS |
| Restore/discovery diff | PASS (0) |
| protected production diff | PASS (0) |
| strict cleanup frontend/analyzer | PASS |
| manager frontend, assertions enabled | PASS |
| manager frontend, NS_BLOCK_ASSERTIONS | PASS |
| deterministic cleanup/funnel model | PASS (74 core cases) |

## Explicit scenario matrix

Explicit scenarios: 248.

| # | ID | Scenario | Expected/result |
|---:|---|---|---|
| 1 | `Funnel-01` | initial workspace validation | Calls completeBackupFailure(initialCleanupStageError); cleanup success preserves the exact operation NSError |
| 2 | `Funnel-02` | artifact-writer factory | Calls completeBackupFailure(artifactWriterError); cleanup success preserves the exact operation NSError |
| 3 | `Funnel-03` | initial artifact-writer validation | Calls completeBackupFailure(initialArtifactWriterIdentityError); cleanup success preserves the exact operation NSError |
| 4 | `Funnel-04` | manifest-writer factory | Calls completeBackupFailure(manifestWriterError); cleanup success preserves the exact operation NSError |
| 5 | `Funnel-05` | initial manifest-writer validation | Calls completeBackupFailure(initialManifestWriterIdentityError); cleanup success preserves the exact operation NSError |
| 6 | `Funnel-06` | canonical policy construction | Calls completeBackupFailure(err); cleanup success preserves the exact operation NSError |
| 7 | `Funnel-07` | directory-publisher factory | Calls completeBackupFailure(directoryPublisherError); cleanup success preserves the exact operation NSError |
| 8 | `Funnel-08` | initial directory-publisher validation | Calls completeBackupFailure(initialDirectoryPublisherIdentityError); cleanup success preserves the exact operation NSError |
| 9 | `Funnel-09` | groups output-directory creation | Calls completeBackupFailure(err); cleanup success preserves the exact operation NSError |
| 10 | `Funnel-10` | required ApplicationData policy abort | Calls completeBackupFailure(fatalPolicyError ?: err); cleanup success preserves the exact operation NSError |
| 11 | `Funnel-11` | required ApplicationData invariant failure | Calls completeBackupFailure(invariantError); cleanup success preserves the exact operation NSError |
| 12 | `Funnel-12` | App Group invalid optional disposition | Calls completeBackupFailure(fatalPolicyError); cleanup success preserves the exact operation NSError |
| 13 | `Funnel-13` | ProfileAppData invalid optional disposition | Calls completeBackupFailure(fatalPolicyError); cleanup success preserves the exact operation NSError |
| 14 | `Funnel-14` | GlobalSafari invalid optional disposition | Calls completeBackupFailure(fatalPolicyError); cleanup success preserves the exact operation NSError |
| 15 | `Funnel-15` | Preferences invalid optional disposition | Calls completeBackupFailure(fatalPolicyError); cleanup success preserves the exact operation NSError |
| 16 | `Funnel-16` | Keychain invalid optional disposition | Calls completeBackupFailure(fatalPolicyError); cleanup success preserves the exact operation NSError |
| 17 | `Funnel-17` | SystemGlobal invalid optional disposition | Calls completeBackupFailure(fatalPolicyError); cleanup success preserves the exact operation NSError |
| 18 | `Funnel-18` | SharedSystemDatabase invalid optional disposition | Calls completeBackupFailure(fatalPolicyError); cleanup success preserves the exact operation NSError |
| 19 | `Funnel-19` | pre-manifest policy audit | Calls completeBackupFailure(err); cleanup success preserves the exact operation NSError |
| 20 | `Funnel-20` | v4 builder failure | Calls completeBackupFailure(err); cleanup success preserves the exact operation NSError |
| 21 | `Funnel-21` | manager-produced v4 validation | Calls completeBackupFailure(producedManifestValidationError); cleanup success preserves the exact operation NSError |
| 22 | `Funnel-22` | pre-manifest artifact-writer validation | Calls completeBackupFailure(preManifestArtifactWriterIdentityError); cleanup success preserves the exact operation NSError |
| 23 | `Funnel-23` | pre-manifest workspace validation | Calls completeBackupFailure(preManifestWorkspaceIdentityError); cleanup success preserves the exact operation NSError |
| 24 | `Funnel-24` | pre-manifest bundle-lock validation | Calls completeBackupFailure(preManifestBundleLockValidationError); cleanup success preserves the exact operation NSError |
| 25 | `Funnel-25` | pre-write manifest-writer validation | Calls completeBackupFailure(preWriteManifestWriterIdentityError); cleanup success preserves the exact operation NSError |
| 26 | `Funnel-26` | atomic manifest write | Calls completeBackupFailure(manifestWriteError); cleanup success preserves the exact operation NSError |
| 27 | `Funnel-27` | final manifest-writer validation | Calls completeBackupFailure(finalManifestWriterIdentityError); cleanup success preserves the exact operation NSError |
| 28 | `Funnel-28` | final workspace validation | Calls completeBackupFailure(finalWorkspaceIdentityError); cleanup success preserves the exact operation NSError |
| 29 | `Funnel-29` | final bundle-lock validation | Calls completeBackupFailure(finalBundleLockValidationError); cleanup success preserves the exact operation NSError |
| 30 | `Funnel-30` | final artifact-writer validation | Calls completeBackupFailure(finalArtifactWriterIdentityError); cleanup success preserves the exact operation NSError |
| 31 | `Funnel-31` | pre-publication publisher validation | Calls completeBackupFailure(prePublicationDirectoryPublisherIdentityError); cleanup success preserves the exact operation NSError |
| 32 | `Funnel-32` | directory publication or rollback failure | Calls completeBackupFailure(directoryPublicationError); cleanup success preserves the exact operation NSError |
| 33 | `Funnel-33` | post-publication validation or disarm stage | Calls completeBackupFailure(postPublicationCleanupStageError); cleanup success preserves the exact operation NSError |
| 34 | `Cleanup-precedence-01` | initial workspace validation | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 35 | `Cleanup-precedence-02` | artifact-writer factory | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 36 | `Cleanup-precedence-03` | initial artifact-writer validation | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 37 | `Cleanup-precedence-04` | manifest-writer factory | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 38 | `Cleanup-precedence-05` | initial manifest-writer validation | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 39 | `Cleanup-precedence-06` | canonical policy construction | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 40 | `Cleanup-precedence-07` | directory-publisher factory | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 41 | `Cleanup-precedence-08` | initial directory-publisher validation | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 42 | `Cleanup-precedence-09` | groups output-directory creation | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 43 | `Cleanup-precedence-10` | required ApplicationData policy abort | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 44 | `Cleanup-precedence-11` | required ApplicationData invariant failure | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 45 | `Cleanup-precedence-12` | App Group invalid optional disposition | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 46 | `Cleanup-precedence-13` | ProfileAppData invalid optional disposition | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 47 | `Cleanup-precedence-14` | GlobalSafari invalid optional disposition | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 48 | `Cleanup-precedence-15` | Preferences invalid optional disposition | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 49 | `Cleanup-precedence-16` | Keychain invalid optional disposition | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 50 | `Cleanup-precedence-17` | SystemGlobal invalid optional disposition | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 51 | `Cleanup-precedence-18` | SharedSystemDatabase invalid optional disposition | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 52 | `Cleanup-precedence-19` | pre-manifest policy audit | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 53 | `Cleanup-precedence-20` | v4 builder failure | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 54 | `Cleanup-precedence-21` | manager-produced v4 validation | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 55 | `Cleanup-precedence-22` | pre-manifest artifact-writer validation | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 56 | `Cleanup-precedence-23` | pre-manifest workspace validation | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 57 | `Cleanup-precedence-24` | pre-manifest bundle-lock validation | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 58 | `Cleanup-precedence-25` | pre-write manifest-writer validation | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 59 | `Cleanup-precedence-26` | atomic manifest write | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 60 | `Cleanup-precedence-27` | final manifest-writer validation | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 61 | `Cleanup-precedence-28` | final workspace validation | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 62 | `Cleanup-precedence-29` | final bundle-lock validation | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 63 | `Cleanup-precedence-30` | final artifact-writer validation | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 64 | `Cleanup-precedence-31` | pre-publication publisher validation | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 65 | `Cleanup-precedence-32` | directory publication or rollback failure | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 66 | `Cleanup-precedence-33` | post-publication validation or disarm stage | Cleanup failure returns the exact cleanup NSError and preserves remaining evidence |
| 67 | `Depth-0` | Nested directory depth 0 | accepted |
| 68 | `Depth-1` | Nested directory depth 1 | accepted |
| 69 | `Depth-2` | Nested directory depth 2 | accepted |
| 70 | `Depth-3` | Nested directory depth 3 | accepted |
| 71 | `Depth-4` | Nested directory depth 4 | accepted |
| 72 | `Depth-5` | Nested directory depth 5 | accepted |
| 73 | `Depth-6` | Nested directory depth 6 | accepted |
| 74 | `Depth-7` | Nested directory depth 7 | accepted |
| 75 | `Depth-8` | Nested directory depth 8 | accepted |
| 76 | `Depth-9` | Nested directory depth 9 | accepted |
| 77 | `Depth-10` | Nested directory depth 10 | accepted |
| 78 | `Depth-11` | Nested directory depth 11 | accepted |
| 79 | `Depth-12` | Nested directory depth 12 | accepted |
| 80 | `Depth-13` | Nested directory depth 13 | accepted |
| 81 | `Depth-14` | Nested directory depth 14 | accepted |
| 82 | `Depth-15` | Nested directory depth 15 | accepted |
| 83 | `Depth-16` | Nested directory depth 16 | accepted |
| 84 | `Depth-17` | Nested directory depth 17 | accepted |
| 85 | `Depth-18` | Nested directory depth 18 | accepted |
| 86 | `Depth-19` | Nested directory depth 19 | accepted |
| 87 | `Depth-20` | Nested directory depth 20 | accepted |
| 88 | `Depth-21` | Nested directory depth 21 | accepted |
| 89 | `Depth-22` | Nested directory depth 22 | accepted |
| 90 | `Depth-23` | Nested directory depth 23 | accepted |
| 91 | `Depth-24` | Nested directory depth 24 | accepted |
| 92 | `Depth-25` | Nested directory depth 25 | accepted |
| 93 | `Depth-26` | Nested directory depth 26 | accepted |
| 94 | `Depth-27` | Nested directory depth 27 | accepted |
| 95 | `Depth-28` | Nested directory depth 28 | accepted |
| 96 | `Depth-29` | Nested directory depth 29 | accepted |
| 97 | `Depth-30` | Nested directory depth 30 | accepted |
| 98 | `Depth-31` | Nested directory depth 31 | accepted |
| 99 | `Depth-32` | Nested directory depth 32 | accepted |
| 100 | `Depth-33` | Nested directory depth 33 | accepted |
| 101 | `Depth-34` | Nested directory depth 34 | accepted |
| 102 | `Depth-35` | Nested directory depth 35 | accepted |
| 103 | `Depth-36` | Nested directory depth 36 | accepted |
| 104 | `Depth-37` | Nested directory depth 37 | accepted |
| 105 | `Depth-38` | Nested directory depth 38 | accepted |
| 106 | `Depth-39` | Nested directory depth 39 | accepted |
| 107 | `Depth-40` | Nested directory depth 40 | accepted |
| 108 | `Depth-41` | Nested directory depth 41 | accepted |
| 109 | `Depth-42` | Nested directory depth 42 | accepted |
| 110 | `Depth-43` | Nested directory depth 43 | accepted |
| 111 | `Depth-44` | Nested directory depth 44 | accepted |
| 112 | `Depth-45` | Nested directory depth 45 | accepted |
| 113 | `Depth-46` | Nested directory depth 46 | accepted |
| 114 | `Depth-47` | Nested directory depth 47 | accepted |
| 115 | `Depth-48` | Nested directory depth 48 | accepted |
| 116 | `Depth-49` | Nested directory depth 49 | accepted |
| 117 | `Depth-50` | Nested directory depth 50 | accepted |
| 118 | `Depth-51` | Nested directory depth 51 | accepted |
| 119 | `Depth-52` | Nested directory depth 52 | accepted |
| 120 | `Depth-53` | Nested directory depth 53 | accepted |
| 121 | `Depth-54` | Nested directory depth 54 | accepted |
| 122 | `Depth-55` | Nested directory depth 55 | accepted |
| 123 | `Depth-56` | Nested directory depth 56 | accepted |
| 124 | `Depth-57` | Nested directory depth 57 | accepted |
| 125 | `Depth-58` | Nested directory depth 58 | accepted |
| 126 | `Depth-59` | Nested directory depth 59 | accepted |
| 127 | `Depth-60` | Nested directory depth 60 | accepted |
| 128 | `Depth-61` | Nested directory depth 61 | accepted |
| 129 | `Depth-62` | Nested directory depth 62 | accepted |
| 130 | `Depth-63` | Nested directory depth 63 | accepted |
| 131 | `Depth-64` | Nested directory depth 64 | accepted |
| 132 | `Depth-65` | Nested directory depth 65 | LimitExceeded |
| 133 | `Entries-0` | Visited-entry count 0 | accepted |
| 134 | `Entries-1` | Visited-entry count 1 | accepted |
| 135 | `Entries-2` | Visited-entry count 2 | accepted |
| 136 | `Entries-31` | Visited-entry count 31 | accepted |
| 137 | `Entries-32` | Visited-entry count 32 | accepted |
| 138 | `Entries-255` | Visited-entry count 255 | accepted |
| 139 | `Entries-256` | Visited-entry count 256 | accepted |
| 140 | `Entries-1023` | Visited-entry count 1023 | accepted |
| 141 | `Entries-4095` | Visited-entry count 4095 | accepted |
| 142 | `Entries-8191` | Visited-entry count 8191 | accepted |
| 143 | `Entries-16383` | Visited-entry count 16383 | accepted |
| 144 | `Entries-16384` | Visited-entry count 16384 | accepted |
| 145 | `Entries-16385` | Visited-entry count 16385 | LimitExceeded |
| 146 | `Component-0` | Component byte length 0 | UnsafeEntry/LimitExceeded |
| 147 | `Component-1` | Component byte length 1 | accepted component |
| 148 | `Component-2` | Component byte length 2 | accepted component |
| 149 | `Component-31` | Component byte length 31 | accepted component |
| 150 | `Component-127` | Component byte length 127 | accepted component |
| 151 | `Component-254` | Component byte length 254 | accepted component |
| 152 | `Component-255` | Component byte length 255 | accepted component |
| 153 | `Component-256` | Component byte length 256 | UnsafeEntry/LimitExceeded |
| 154 | `Component-4096` | Component byte length 4096 | UnsafeEntry/LimitExceeded |
| 155 | `Unsafe-01` | symlink | UnsafeEntry; no follow/delete |
| 156 | `Unsafe-02` | FIFO | UnsafeEntry; preserve |
| 157 | `Unsafe-03` | socket | UnsafeEntry; preserve |
| 158 | `Unsafe-04` | character device | UnsafeEntry; preserve |
| 159 | `Unsafe-05` | block device | UnsafeEntry; preserve |
| 160 | `Unsafe-06` | cross-filesystem regular file | UnsafeEntry; preserve |
| 161 | `Unsafe-07` | cross-filesystem directory | UnsafeEntry; preserve |
| 162 | `Unsafe-08` | hard-linked regular file | UnsafeEntry; preserve |
| 163 | `Unsafe-09` | setuid regular file | UnsafeEntry; preserve |
| 164 | `Unsafe-10` | setgid regular file | UnsafeEntry; preserve |
| 165 | `Unsafe-11` | setuid directory | UnsafeEntry; preserve |
| 166 | `Unsafe-12` | setgid directory | UnsafeEntry; preserve |
| 167 | `Unsafe-13` | invalid UTF-8 name | UnsafeEntry; preserve |
| 168 | `Unsafe-14` | embedded control name | UnsafeEntry; preserve |
| 169 | `Unsafe-15` | oversized name | UnsafeEntry; preserve |
| 170 | `Unsafe-16` | regular-file replacement race | EntryChanged; do not fallback |
| 171 | `Unsafe-17` | directory replacement race | EntryChanged; do not fallback |
| 172 | `Unsafe-18` | file link-count race | CleanupIncomplete after proven unlink, otherwise EntryChanged |
| 173 | `Cleanup-01` | empty workspace | root removed and parent synced |
| 174 | `Cleanup-02` | single file | file then root removed |
| 175 | `Cleanup-03` | nested file | post-order directories then root |
| 176 | `Cleanup-04` | file unlink failure | RemovalFailed, or CleanupIncomplete after earlier mutation |
| 177 | `Cleanup-05` | directory unlink failure | RemovalFailed, or CleanupIncomplete after earlier mutation |
| 178 | `Cleanup-06` | file parent fsync failure | CleanupIncomplete |
| 179 | `Cleanup-07` | directory parent fsync failure | CleanupIncomplete |
| 180 | `Cleanup-08` | root workspace fsync failure | DurabilityFailed or CleanupIncomplete |
| 181 | `Cleanup-09` | root parent fsync failure | CleanupIncomplete |
| 182 | `Cleanup-10` | readdir error before mutation | TraversalFailed |
| 183 | `Cleanup-11` | readdir error after earlier subtree removal | CleanupIncomplete |
| 184 | `Cleanup-12` | workspace repopulated after traversal | EntryChanged or CleanupIncomplete |
| 185 | `Cleanup-13` | partial name absent before cleanup | PublishedStateDetected |
| 186 | `Cleanup-14` | partial name replaced | WorkspaceChanged |
| 187 | `Cleanup-15` | rollback restored exact partial inode | current tree cleanup allowed |
| 188 | `Cleanup-16` | rollback failed with final only | PublishedStateDetected; final untouched |
| 189 | `Cleanup-17` | rollback failed with competing partial | WorkspaceChanged; both entries untouched |
| 190 | `Cleanup-18` | factory fails before authority | preserve empty workspace evidence |
| 191 | `Cleanup-19` | factory fails after authority and empty | remove exact empty workspace; return original setup error |
| 192 | `Cleanup-20` | factory fails after authority and nonempty | FactoryCleanupFailed; preserve |
| 193 | `Disarm-01` | published exact publisher | disarmed YES; descriptors closed |
| 194 | `Disarm-02` | publisher not published | DisarmValidationFailed |
| 195 | `Disarm-03` | publisher identity invalid | DisarmValidationFailed |
| 196 | `Disarm-04` | workspace path mismatch | DisarmValidationFailed |
| 197 | `Disarm-05` | published path equals partial path | DisarmValidationFailed |
| 198 | `Disarm-06` | manifest outside published directory | DisarmValidationFailed |
| 199 | `Disarm-07` | partial name still present | DisarmValidationFailed; delete nothing |
| 200 | `Disarm-08` | lock validation fails | LockValidationFailed |
| 201 | `Disarm-09` | parent identity changes | DisarmValidationFailed |
| 202 | `Precedence-01` | operation error + cleanup success | same NSError object delivered |
| 203 | `Precedence-02` | operation error + cleanup NSError | exact cleanup NSError delivered |
| 204 | `Precedence-03` | nil operation error + cleanup success | PXBackupErrorDomain code 108 |
| 205 | `Precedence-04` | cleanup NO + nil cleanup error | PXBackupErrorDomain code 109 |
| 206 | `Precedence-05` | disarm failure after publication | exact disarm NSError; cleanup skipped; final untouched |
| 207 | `Precedence-06` | completion block nil | cleanup still synchronous; no callback |
| 208 | `Precedence-07` | completion block present | one main-queue nil-result callback |
| 209 | `Race-01` | Namespace mutation checkpoint 1 | Identity revalidation fails closed; no path fallback |
| 210 | `Race-02` | Namespace mutation checkpoint 2 | Identity revalidation fails closed; no path fallback |
| 211 | `Race-03` | Namespace mutation checkpoint 3 | Identity revalidation fails closed; no path fallback |
| 212 | `Race-04` | Namespace mutation checkpoint 4 | Identity revalidation fails closed; no path fallback |
| 213 | `Race-05` | Namespace mutation checkpoint 5 | Identity revalidation fails closed; no path fallback |
| 214 | `Race-06` | Namespace mutation checkpoint 6 | Identity revalidation fails closed; no path fallback |
| 215 | `Race-07` | Namespace mutation checkpoint 7 | Identity revalidation fails closed; no path fallback |
| 216 | `Race-08` | Namespace mutation checkpoint 8 | Identity revalidation fails closed; no path fallback |
| 217 | `Race-09` | Namespace mutation checkpoint 9 | Identity revalidation fails closed; no path fallback |
| 218 | `Race-10` | Namespace mutation checkpoint 10 | Identity revalidation fails closed; no path fallback |
| 219 | `Race-11` | Namespace mutation checkpoint 11 | Identity revalidation fails closed; no path fallback |
| 220 | `Race-12` | Namespace mutation checkpoint 12 | Identity revalidation fails closed; no path fallback |
| 221 | `Race-13` | Namespace mutation checkpoint 13 | Identity revalidation fails closed; no path fallback |
| 222 | `Race-14` | Namespace mutation checkpoint 14 | Identity revalidation fails closed; no path fallback |
| 223 | `Race-15` | Namespace mutation checkpoint 15 | Identity revalidation fails closed; no path fallback |
| 224 | `Race-16` | Namespace mutation checkpoint 16 | Identity revalidation fails closed; no path fallback |
| 225 | `Race-17` | Namespace mutation checkpoint 17 | Identity revalidation fails closed; no path fallback |
| 226 | `Race-18` | Namespace mutation checkpoint 18 | Identity revalidation fails closed; no path fallback |
| 227 | `Race-19` | Namespace mutation checkpoint 19 | Identity revalidation fails closed; no path fallback |
| 228 | `Race-20` | Namespace mutation checkpoint 20 | Identity revalidation fails closed; no path fallback |
| 229 | `Race-21` | Namespace mutation checkpoint 21 | Identity revalidation fails closed; no path fallback |
| 230 | `Race-22` | Namespace mutation checkpoint 22 | Identity revalidation fails closed; no path fallback |
| 231 | `Race-23` | Namespace mutation checkpoint 23 | Identity revalidation fails closed; no path fallback |
| 232 | `Race-24` | Namespace mutation checkpoint 24 | Identity revalidation fails closed; no path fallback |
| 233 | `Race-25` | Namespace mutation checkpoint 25 | Identity revalidation fails closed; no path fallback |
| 234 | `Race-26` | Namespace mutation checkpoint 26 | Identity revalidation fails closed; no path fallback |
| 235 | `Race-27` | Namespace mutation checkpoint 27 | Identity revalidation fails closed; no path fallback |
| 236 | `Race-28` | Namespace mutation checkpoint 28 | Identity revalidation fails closed; no path fallback |
| 237 | `Race-29` | Namespace mutation checkpoint 29 | Identity revalidation fails closed; no path fallback |
| 238 | `Race-30` | Namespace mutation checkpoint 30 | Identity revalidation fails closed; no path fallback |
| 239 | `Race-31` | Namespace mutation checkpoint 31 | Identity revalidation fails closed; no path fallback |
| 240 | `Race-32` | Namespace mutation checkpoint 32 | Identity revalidation fails closed; no path fallback |
| 241 | `Race-33` | Namespace mutation checkpoint 33 | Identity revalidation fails closed; no path fallback |
| 242 | `Race-34` | Namespace mutation checkpoint 34 | Identity revalidation fails closed; no path fallback |
| 243 | `Race-35` | Namespace mutation checkpoint 35 | Identity revalidation fails closed; no path fallback |
| 244 | `Race-36` | Namespace mutation checkpoint 36 | Identity revalidation fails closed; no path fallback |
| 245 | `Race-37` | Namespace mutation checkpoint 37 | Identity revalidation fails closed; no path fallback |
| 246 | `Race-38` | Namespace mutation checkpoint 38 | Identity revalidation fails closed; no path fallback |
| 247 | `Race-39` | Namespace mutation checkpoint 39 | Identity revalidation fails closed; no path fallback |
| 248 | `Race-40` | Namespace mutation checkpoint 40 | Identity revalidation fails closed; no path fallback |

## Full authorized production diff

The following is the complete production-source diff for the three authorized production files. The report does not recursively include its own diff.

```diff
diff --git a/AppDataBackupManager.m b/AppDataBackupManager.m
index b27fb66..6daab55 100644
--- a/AppDataBackupManager.m
+++ b/AppDataBackupManager.m
@@ -14,12 +14,13 @@
 #import "PXBackupArtifactVerifier.h"
 #import "PXBackupArchiveValidator.h"
 #import "PXBackupBundleLock.h"
 #import "PXBackupArtifactWriter.h"
 #import "PXBackupManifestWriter.h"
 #import "PXBackupDirectoryPublisher.h"
+#import "PXBackupFailureCleanup.h"
 #import "PXBackupPublicationWorkspace.h"
 #import "PXRestorePlan.h"
 #import "PXAppGroupRestoreTargetPlan.h"
 #import "PXAppGroupRestoreTransaction.h"
 #import "PXOptionalRestoreStaging.h"
 #import "PXOptionalRestoreTransaction.h"
@@ -1743,53 +1744,85 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
         if (!publicationWorkspace) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (completion) completion(nil, workspaceError);
             });
             return;
         }
-        NSError *initialWorkspaceIdentityError = nil;
-        if (![publicationWorkspace validateIdentityWithError:&initialWorkspaceIdentityError]) {
+        NSError *failureCleanupFactoryError = nil;
+        __attribute__((objc_precise_lifetime))
+        PXBackupFailureCleanup *failureCleanup =
+            [PXBackupFailureCleanup cleanupForWorkspace:publicationWorkspace
+                                             bundleLock:bundleLock
+                                                  error:&failureCleanupFactoryError];
+        if (!failureCleanup) {
             dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, initialWorkspaceIdentityError);
+                if (completion) completion(nil, failureCleanupFactoryError);
             });
             return;
         }
+        __block BOOL preservePublishedFailureWithoutCleanup = NO;
+        void (^completeBackupFailure)(NSError *) = ^(NSError *operationError) {
+            NSError *reportedError = operationError ?: [NSError
+                errorWithDomain:PXBackupErrorDomain
+                           code:108
+                       userInfo:@{
+                           NSLocalizedDescriptionKey: @"Backup failed without an error"
+                       }];
+            if (!preservePublishedFailureWithoutCleanup) {
+                NSError *cleanupError = nil;
+                if (![failureCleanup cleanupWithError:&cleanupError]) {
+                    reportedError = cleanupError ?: [NSError
+                        errorWithDomain:PXBackupErrorDomain
+                                   code:109
+                               userInfo:@{
+                                   NSLocalizedDescriptionKey: @"Backup failure cleanup failed without an error"
+                               }];
+                }
+            }
+            dispatch_async(dispatch_get_main_queue(), ^{
+                if (completion) completion(nil, reportedError);
+            });
+        };
+        NSError *initialFailureCleanupIdentityError = nil;
+        NSError *initialWorkspaceIdentityError = nil;
+        NSError *initialCleanupStageError = nil;
+        if (![failureCleanup validateIdentityWithError:&initialFailureCleanupIdentityError]) {
+            initialCleanupStageError = initialFailureCleanupIdentityError;
+        } else if (![publicationWorkspace validateIdentityWithError:&initialWorkspaceIdentityError]) {
+            initialCleanupStageError = initialWorkspaceIdentityError;
+        }
+        if (initialCleanupStageError) {
+            completeBackupFailure(initialCleanupStageError);
+            return;
+        }
         NSError *artifactWriterError = nil;
         __attribute__((objc_precise_lifetime))
         PXBackupArtifactWriter *artifactWriter =
             [PXBackupArtifactWriter writerForWorkspace:publicationWorkspace
                                                  error:&artifactWriterError];
         if (!artifactWriter) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, artifactWriterError);
-            });
+            completeBackupFailure(artifactWriterError);
             return;
         }
         NSError *initialArtifactWriterIdentityError = nil;
         if (![artifactWriter validateIdentityWithError:&initialArtifactWriterIdentityError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, initialArtifactWriterIdentityError);
-            });
+            completeBackupFailure(initialArtifactWriterIdentityError);
             return;
         }
         NSError *manifestWriterError = nil;
         __attribute__((objc_precise_lifetime))
         PXBackupManifestWriter *manifestWriter =
             [PXBackupManifestWriter writerForWorkspace:publicationWorkspace
                                                   error:&manifestWriterError];
         if (!manifestWriter) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, manifestWriterError);
-            });
+            completeBackupFailure(manifestWriterError);
             return;
         }
         NSError *initialManifestWriterIdentityError = nil;
         if (![manifestWriter validateIdentityWithError:&initialManifestWriterIdentityError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, initialManifestWriterIdentityError);
-            });
+            completeBackupFailure(initialManifestWriterIdentityError);
             return;
         }
         PXBackupArtifactPolicy *applicationDataArtifactPolicy =
             [PXBackupArtifactPolicy policyForKind:PXBackupArtifactKindApplicationData];
         PXBackupArtifactPolicy *appGroupArtifactPolicy =
             [PXBackupArtifactPolicy policyForKind:PXBackupArtifactKindAppGroup];
@@ -1831,15 +1864,13 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             PXBackupArtifactPolicyMatchesCanonicalKind(
                 keychainArtifactPolicy,
                 PXBackupArtifactKindKeychain);
         if (!policyConstructionValid) {
             NSError *err = PXBackupArtifactPolicyManagerError(
                 @"Backup artifact policy could not be constructed");
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, err);
-            });
+            completeBackupFailure(err);
             return;
         }
         NSArray<PXBackupArtifactPolicy *> *canonicalArtifactPolicies = @[
             applicationDataArtifactPolicy,
             appGroupArtifactPolicy,
             profileAppDataArtifactPolicy,
@@ -1856,22 +1887,18 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
             [PXBackupDirectoryPublisher publisherForWorkspace:publicationWorkspace
                                                    bundleLock:bundleLock
                                              backupIdentifier:backupIdentifier
                                                     timestamp:timestamp
                                                         error:&directoryPublisherError];
         if (!directoryPublisher) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, directoryPublisherError);
-            });
+            completeBackupFailure(directoryPublisherError);
             return;
         }
         NSError *initialDirectoryPublisherIdentityError = nil;
         if (![directoryPublisher validateIdentityWithError:&initialDirectoryPublisherIdentityError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, initialDirectoryPublisherIdentityError);
-            });
+            completeBackupFailure(initialDirectoryPublisherIdentityError);
             return;
         }
         NSMutableArray<PXVerifiedBackupArtifact *> *groupArtifactRecords =
             [NSMutableArray array];
         NSMutableArray<PXVerifiedBackupArtifact *> *systemGlobalArtifactRecords =
             [NSMutableArray array];
@@ -1891,13 +1918,13 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

         NSError *mkErr = nil;
         if (![fm createDirectoryAtPath:groupsDir withIntermediateDirectories:YES attributes:nil error:&mkErr]) {
             NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                code:104
                                            userInfo:@{NSLocalizedDescriptionKey: mkErr.localizedDescription ?: @"Failed to create backup directory"}];
-            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
+            completeBackupFailure(err);
             return;
         }
         [fm createDirectoryAtPath:prefsDir withIntermediateDirectories:YES attributes:nil error:nil];

         // Restrict permissions best-effort
         [runner run:[NSString stringWithFormat:@"chmod 700 %@ 2>/dev/null || true", PXShellQuote(backupDir)]];
@@ -1971,22 +1998,18 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                 applicationDataArtifactPolicy,
                 warnings,
                 nil,
                 err,
                 &fatalPolicyError);
             if (!shouldContinue) {
-                dispatch_async(dispatch_get_main_queue(), ^{
-                    if (completion) completion(nil, fatalPolicyError ?: err);
-                });
+                completeBackupFailure(fatalPolicyError ?: err);
                 return;
             }
             NSError *invariantError = PXBackupArtifactPolicyManagerError(
                 @"Backup artifact policy invariant failed");
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, invariantError);
-            });
+            completeBackupFailure(invariantError);
             return;
         }
         NSString *dataArchivePath = dataArtifactRecord.filePath;

         NSMutableArray<NSDictionary *> *groupManifests = [NSMutableArray array];
         NSArray<AppGroupContainerInfo *> *groupContainers = @[];
@@ -2043,15 +2066,13 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                     appGroupArtifactPolicy,
                     warnings,
                     [NSString stringWithFormat:@"Failed to archive group %@ (%@)", info.groupID, info.uuid],
                     nil,
                     &fatalPolicyError);
                 if (!shouldContinue) {
-                    dispatch_async(dispatch_get_main_queue(), ^{
-                        if (completion) completion(nil, fatalPolicyError);
-                    });
+                    completeBackupFailure(fatalPolicyError);
                     return;
                 }
                 continue;
             }
             [groupArtifactRecords addObject:groupArtifact];
             [groupManifests addObject:@{
@@ -2085,15 +2106,13 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                         profileAppDataArtifactPolicy,
                         warnings,
                         @"Failed to archive profile appdata; continuing",
                         nil,
                         &fatalPolicyError);
                     if (!shouldContinue) {
-                        dispatch_async(dispatch_get_main_queue(), ^{
-                            if (completion) completion(nil, fatalPolicyError);
-                        });
+                        completeBackupFailure(fatalPolicyError);
                         return;
                     }
                 } else {
                     profileAppDataArchivePath = profileArtifactRecord.filePath;
                 }
             }
@@ -2125,15 +2144,13 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                             globalSafariArtifactPolicy,
                             warnings,
                             @"Failed to archive global Safari library; continuing",
                             nil,
                             &fatalPolicyError);
                         if (!shouldContinue) {
-                            dispatch_async(dispatch_get_main_queue(), ^{
-                                if (completion) completion(nil, fatalPolicyError);
-                            });
+                            completeBackupFailure(fatalPolicyError);
                             return;
                         }
                     } else {
                         globalSafariArchivePath = globalSafariArtifactRecord.filePath;
                     }
                 }
@@ -2165,15 +2182,13 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                         preferencesArtifactPolicy,
                         warnings,
                         nil,
                         nil,
                         &fatalPolicyError);
                     if (!shouldContinue) {
-                        dispatch_async(dispatch_get_main_queue(), ^{
-                            if (completion) completion(nil, fatalPolicyError);
-                        });
+                        completeBackupFailure(fatalPolicyError);
                         return;
                     }
                 }
             } else {
                 [warnings addObject:@"Global preferences plist not found (OK for most apps); skipping"];
             }
@@ -2286,15 +2301,13 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                     keychainArtifactPolicy,
                     warnings,
                     nil,
                     nil,
                     &fatalPolicyError);
                 if (!shouldContinue) {
-                    dispatch_async(dispatch_get_main_queue(), ^{
-                        if (completion) completion(nil, fatalPolicyError);
-                    });
+                    completeBackupFailure(fatalPolicyError);
                     return;
                 }
                 keychainBackupPath = nil;
                 keychainMethod = nil;
             }
         }
@@ -2336,15 +2349,13 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                     systemGlobalArtifactPolicy,
                     warnings,
                     [NSString stringWithFormat:@"Failed to archive system global library %@; continuing", subdir],
                     nil,
                     &fatalPolicyError);
                 if (!shouldContinue) {
-                    dispatch_async(dispatch_get_main_queue(), ^{
-                        if (completion) completion(nil, fatalPolicyError);
-                    });
+                    completeBackupFailure(fatalPolicyError);
                     return;
                 }
                 continue;
             }
             [systemGlobalArtifactRecords addObject:systemArtifact];
             [systemGlobalManifests addObject:@{
@@ -2409,15 +2420,13 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                             sharedSystemDatabaseArtifactPolicy,
                             warnings,
                             nil,
                             nil,
                             &fatalPolicyError);
                         if (!shouldContinue) {
-                            dispatch_async(dispatch_get_main_queue(), ^{
-                                if (completion) completion(nil, fatalPolicyError);
-                            });
+                            completeBackupFailure(fatalPolicyError);
                             return;
                         }
                     }
                 }
             }

@@ -2445,15 +2454,13 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr

         if (!PXBackupAuditVerifiedArtifactPolicies(verifiedArtifactRecords,
                                                    canonicalArtifactPolicies,
                                                    artifactWriter.artifactCount)) {
             NSError *err = PXBackupArtifactPolicyManagerError(
                 @"Backup artifact policy invariant failed");
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, err);
-            });
+            completeBackupFailure(err);
             return;
         }

         NSString *toolVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
         NSString *toolBuild = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey] ?: @"";
         NSMutableArray<NSString *> *restoreNotes = [NSMutableArray array];
@@ -2533,31 +2540,25 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                                            verifiedArtifacts:verifiedArtifactRecords
                                                        error:&manifestV4Error];
         if (!manifestSnapshot) {
             NSError *err = manifestV4Error ?: [NSError errorWithDomain:PXBackupErrorDomain
                                                                    code:107
                                                                userInfo:@{NSLocalizedDescriptionKey: @"Manifest v4 could not be constructed"}];
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, err);
-            });
+            completeBackupFailure(err);
             return;
         }
         NSDictionary<NSString *, id> *manifest = manifestSnapshot.manifestRepresentation;
         NSError *producedManifestValidationError = nil;
         if (![PXBackupManifestValidator validateManifestObject:manifest
                                                          error:&producedManifestValidationError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, producedManifestValidationError);
-            });
+            completeBackupFailure(producedManifestValidationError);
             return;
         }
         NSError *preManifestArtifactWriterIdentityError = nil;
         if (![artifactWriter validateIdentityWithError:&preManifestArtifactWriterIdentityError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, preManifestArtifactWriterIdentityError);
-            });
+            completeBackupFailure(preManifestArtifactWriterIdentityError);
             return;
         }

         // Debug snapshot: after backup artifacts
         {
             PXDebugHeader(debugAfter, @"Backup Artifacts");
@@ -2570,94 +2571,82 @@ static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSStr
                 PXDebugRun(runner, debugAfter, @"ls keychain.plist", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote(keychainBackupPath)]);
             }
         }

         NSError *preManifestWorkspaceIdentityError = nil;
         if (![publicationWorkspace validateIdentityWithError:&preManifestWorkspaceIdentityError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, preManifestWorkspaceIdentityError);
-            });
+            completeBackupFailure(preManifestWorkspaceIdentityError);
             return;
         }
         NSError *preManifestBundleLockValidationError = nil;
         if (![bundleLock validateOwnershipWithError:&preManifestBundleLockValidationError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, preManifestBundleLockValidationError);
-            });
+            completeBackupFailure(preManifestBundleLockValidationError);
             return;
         }
         NSError *preWriteManifestWriterIdentityError = nil;
         if (![manifestWriter validateIdentityWithError:&preWriteManifestWriterIdentityError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, preWriteManifestWriterIdentityError);
-            });
+            completeBackupFailure(preWriteManifestWriterIdentityError);
             return;
         }
         NSError *manifestWriteError = nil;
         if (![manifestWriter writeManifestSnapshot:manifestSnapshot
                                               error:&manifestWriteError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, manifestWriteError);
-            });
+            completeBackupFailure(manifestWriteError);
             return;
         }
         PXDebugRun(runner,
                    debugAfter,
                    @"cat manifest.plist",
                    [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true",
                     PXShellQuote(manifestWriter.manifestPath)]);

         NSError *finalManifestWriterIdentityError = nil;
         if (![manifestWriter validateIdentityWithError:&finalManifestWriterIdentityError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, finalManifestWriterIdentityError);
-            });
+            completeBackupFailure(finalManifestWriterIdentityError);
             return;
         }
         NSError *finalWorkspaceIdentityError = nil;
         if (![publicationWorkspace validateIdentityWithError:&finalWorkspaceIdentityError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, finalWorkspaceIdentityError);
-            });
+            completeBackupFailure(finalWorkspaceIdentityError);
             return;
         }
         NSError *finalBundleLockValidationError = nil;
         if (![bundleLock validateOwnershipWithError:&finalBundleLockValidationError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, finalBundleLockValidationError);
-            });
+            completeBackupFailure(finalBundleLockValidationError);
             return;
         }
         NSError *finalArtifactWriterIdentityError = nil;
         if (![artifactWriter validateIdentityWithError:&finalArtifactWriterIdentityError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, finalArtifactWriterIdentityError);
-            });
+            completeBackupFailure(finalArtifactWriterIdentityError);
             return;
         }
         NSError *prePublicationDirectoryPublisherIdentityError = nil;
         if (![directoryPublisher validateIdentityWithError:&prePublicationDirectoryPublisherIdentityError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, prePublicationDirectoryPublisherIdentityError);
-            });
+            completeBackupFailure(prePublicationDirectoryPublisherIdentityError);
             return;
         }
         NSError *directoryPublicationError = nil;
         if (![directoryPublisher publishWithArtifactWriter:artifactWriter
                                             manifestWriter:manifestWriter
                                                      error:&directoryPublicationError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, directoryPublicationError);
-            });
+            completeBackupFailure(directoryPublicationError);
             return;
         }
         NSError *postPublicationDirectoryPublisherIdentityError = nil;
+        NSError *failureCleanupDisarmError = nil;
+        NSError *postPublicationCleanupStageError = nil;
         if (![directoryPublisher validateIdentityWithError:&postPublicationDirectoryPublisherIdentityError]) {
-            dispatch_async(dispatch_get_main_queue(), ^{
-                if (completion) completion(nil, postPublicationDirectoryPublisherIdentityError);
-            });
+            postPublicationCleanupStageError =
+                postPublicationDirectoryPublisherIdentityError;
+        } else if (![failureCleanup disarmAfterPublishedDirectory:directoryPublisher
+                                                            error:&failureCleanupDisarmError]) {
+            preservePublishedFailureWithoutCleanup = YES;
+            postPublicationCleanupStageError = failureCleanupDisarmError;
+        }
+        if (postPublicationCleanupStageError) {
+            completeBackupFailure(postPublicationCleanupStageError);
             return;
         }
         PXBackupResult *out = [[PXBackupResult alloc] init];
         out.backupDirectory = directoryPublisher.publishedDirectoryPath;
         out.manifestPath = directoryPublisher.publishedManifestPath;
         out.warnings = warnings;
--- /dev/null
+++ b/PXBackupFailureCleanup.h
@@ -0,0 +1,58 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+@class PXBackupPublicationWorkspace;
+@class PXBackupBundleLock;
+@class PXBackupDirectoryPublisher;
+
+FOUNDATION_EXPORT NSErrorDomain const PXBackupFailureCleanupErrorDomain;
+FOUNDATION_EXPORT NSString * const PXBackupFailureCleanupErrorFieldPathKey;
+
+typedef NS_ERROR_ENUM(PXBackupFailureCleanupErrorDomain,
+                      PXBackupFailureCleanupErrorCode) {
+    PXBackupFailureCleanupErrorInvalidInput = 1,
+    PXBackupFailureCleanupErrorLockValidationFailed = 2,
+    PXBackupFailureCleanupErrorParentInspectionFailed = 3,
+    PXBackupFailureCleanupErrorWorkspaceInspectionFailed = 4,
+    PXBackupFailureCleanupErrorWorkspaceChanged = 5,
+    PXBackupFailureCleanupErrorUnsafeEntry = 6,
+    PXBackupFailureCleanupErrorEntryChanged = 7,
+    PXBackupFailureCleanupErrorLimitExceeded = 8,
+    PXBackupFailureCleanupErrorTraversalFailed = 9,
+    PXBackupFailureCleanupErrorRemovalFailed = 10,
+    PXBackupFailureCleanupErrorDurabilityFailed = 11,
+    PXBackupFailureCleanupErrorCleanupIncomplete = 12,
+    PXBackupFailureCleanupErrorPublishedStateDetected = 13,
+    PXBackupFailureCleanupErrorAlreadyFinished = 14,
+    PXBackupFailureCleanupErrorDisarmValidationFailed = 15,
+    PXBackupFailureCleanupErrorFactoryCleanupFailed = 16,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXBackupFailureCleanup : NSObject
+
+@property (nonatomic, copy, readonly) NSString *workspacePath;
+@property (nonatomic, copy, readonly) NSString *workspaceName;
+@property (nonatomic, readonly) BOOL cleanupAttempted;
+@property (nonatomic, readonly) BOOL cleaned;
+@property (nonatomic, readonly) BOOL disarmed;
+@property (nonatomic, readonly) NSUInteger removedEntryCount;
+
++ (nullable instancetype)cleanupForWorkspace:(PXBackupPublicationWorkspace *)workspace
+                                  bundleLock:(PXBackupBundleLock *)bundleLock
+                                       error:(NSError * _Nullable * _Nullable)error;
+
+- (BOOL)cleanupWithError:(NSError * _Nullable * _Nullable)error;
+
+- (BOOL)disarmAfterPublishedDirectory:(PXBackupDirectoryPublisher *)publisher
+                                error:(NSError * _Nullable * _Nullable)error;
+
+- (BOOL)validateIdentityWithError:(NSError * _Nullable * _Nullable)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
--- /dev/null
+++ b/PXBackupFailureCleanup.m
@@ -0,0 +1,1415 @@
+#import "PXBackupFailureCleanup.h"
+#import "PXBackupPublicationWorkspace.h"
+#import "PXBackupBundleLock.h"
+#import "PXBackupDirectoryPublisher.h"
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
+NSErrorDomain const PXBackupFailureCleanupErrorDomain =
+    @"com.hydra.projectx.backup-failure-cleanup";
+NSString * const PXBackupFailureCleanupErrorFieldPathKey = @"fieldPath";
+
+static NSString * const PXBackupFailureCleanupField = @"$.cleanup";
+static NSString * const PXBackupFailureCleanupLockField = @"$.cleanup.lock";
+static NSString * const PXBackupFailureCleanupParentField = @"$.cleanup.parent";
+static NSString * const PXBackupFailureCleanupWorkspaceField = @"$.cleanup.workspace";
+static NSString * const PXBackupFailureCleanupEntryField = @"$.cleanup.entry";
+static NSString * const PXBackupFailureCleanupDurabilityField = @"$.cleanup.durability";
+static NSString * const PXBackupFailureCleanupPublicationField = @"$.cleanup.publication";
+
+static const NSUInteger PXBackupFailureCleanupMaximumDepth = 64U;
+static const NSUInteger PXBackupFailureCleanupMaximumVisitedEntries = 16384U;
+static const NSUInteger PXBackupFailureCleanupMaximumComponentBytes = 255U;
+static const NSUInteger PXBackupFailureCleanupMaximumWorkspacePathBytes = 4096U;
+static const unsigned long long PXBackupFailureCleanupMaximumAccumulatedNameBytes =
+    8ULL * 1024ULL * 1024ULL;
+
+#if defined(__APPLE__)
+#define PX_BACKUP_CLEANUP_MTIME_SEC(value) ((value).st_mtimespec.tv_sec)
+#define PX_BACKUP_CLEANUP_MTIME_NSEC(value) ((value).st_mtimespec.tv_nsec)
+#define PX_BACKUP_CLEANUP_CTIME_SEC(value) ((value).st_ctimespec.tv_sec)
+#define PX_BACKUP_CLEANUP_CTIME_NSEC(value) ((value).st_ctimespec.tv_nsec)
+#else
+#define PX_BACKUP_CLEANUP_MTIME_SEC(value) ((value).st_mtim.tv_sec)
+#define PX_BACKUP_CLEANUP_MTIME_NSEC(value) ((value).st_mtim.tv_nsec)
+#define PX_BACKUP_CLEANUP_CTIME_SEC(value) ((value).st_ctim.tv_sec)
+#define PX_BACKUP_CLEANUP_CTIME_NSEC(value) ((value).st_ctim.tv_nsec)
+#endif
+
+typedef struct {
+    NSUInteger visitedEntries;
+    unsigned long long accumulatedNameBytes;
+    NSUInteger removedEntries;
+    dev_t workspaceDevice;
+} PXBackupFailureCleanupTraversalState;
+
+static void PXBackupFailureCleanupSetError(
+    NSError **error,
+    PXBackupFailureCleanupErrorCode code,
+    NSString *field,
+    NSString *description) {
+    if (!error) return;
+    *error = [NSError errorWithDomain:PXBackupFailureCleanupErrorDomain
+                                 code:code
+                             userInfo:@{
+                                 NSLocalizedDescriptionKey: description,
+                                 PXBackupFailureCleanupErrorFieldPathKey: field,
+                             }];
+}
+
+static BOOL PXBackupFailureCleanupStatIdentityMatches(const struct stat *left,
+                                                       const struct stat *right) {
+    return left && right && left->st_dev == right->st_dev &&
+           left->st_ino == right->st_ino &&
+           (left->st_mode & S_IFMT) == (right->st_mode & S_IFMT);
+}
+
+static BOOL PXBackupFailureCleanupStableFileMatches(const struct stat *left,
+                                                     const struct stat *right) {
+    return PXBackupFailureCleanupStatIdentityMatches(left, right) &&
+           left->st_mode == right->st_mode && left->st_nlink == right->st_nlink &&
+           left->st_size == right->st_size &&
+           PX_BACKUP_CLEANUP_MTIME_SEC(*left) == PX_BACKUP_CLEANUP_MTIME_SEC(*right) &&
+           PX_BACKUP_CLEANUP_MTIME_NSEC(*left) == PX_BACKUP_CLEANUP_MTIME_NSEC(*right) &&
+           PX_BACKUP_CLEANUP_CTIME_SEC(*left) == PX_BACKUP_CLEANUP_CTIME_SEC(*right) &&
+           PX_BACKUP_CLEANUP_CTIME_NSEC(*left) == PX_BACKUP_CLEANUP_CTIME_NSEC(*right);
+}
+
+static BOOL PXBackupFailureCleanupDescriptorHasCloseOnExec(int descriptor) {
+    if (descriptor < 0) return NO;
+    int flags = -1;
+    do {
+        flags = fcntl(descriptor, F_GETFD);
+    } while (flags < 0 && errno == EINTR);
+    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
+}
+
+static int PXBackupFailureCleanupDuplicateDescriptor(int descriptor) {
+    if (descriptor < 0) return -1;
+    int duplicate = -1;
+    do {
+        duplicate = fcntl(descriptor, F_DUPFD_CLOEXEC, 0);
+    } while (duplicate < 0 && errno == EINTR);
+    if (duplicate < 0 ||
+        !PXBackupFailureCleanupDescriptorHasCloseOnExec(duplicate)) {
+        if (duplicate >= 0) close(duplicate);
+        return -1;
+    }
+    return duplicate;
+}
+
+static BOOL PXBackupFailureCleanupStrictSync(int descriptor) {
+    if (descriptor < 0) return NO;
+    int result = -1;
+    do {
+        result = fsync(descriptor);
+    } while (result < 0 && errno == EINTR);
+    return result == 0;
+}
+
+static BOOL PXBackupFailureCleanupStringContainsNUL(NSString *value) {
+    if (![value isKindOfClass:[NSString class]]) return YES;
+    for (NSUInteger index = 0; index < value.length; index++) {
+        if ([value characterAtIndex:index] == 0) return YES;
+    }
+    return NO;
+}
+
+static BOOL PXBackupFailureCleanupStringContainsControl(NSString *value) {
+    if (![value isKindOfClass:[NSString class]]) return YES;
+    for (NSUInteger index = 0; index < value.length; index++) {
+        unichar character = [value characterAtIndex:index];
+        if (character < 0x20 || character == 0x7f) return YES;
+    }
+    return NO;
+}
+
+static NSData *PXBackupFailureCleanupLosslessUTF8Data(NSString *value,
+                                                       NSUInteger maximumBytes,
+                                                       BOOL requireAbsolute) {
+    if (![value isKindOfClass:[NSString class]] || value.length == 0 ||
+        PXBackupFailureCleanupStringContainsNUL(value) ||
+        (requireAbsolute && ![value hasPrefix:@"/"])) return nil;
+    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding
+                        allowLossyConversion:NO];
+    if (!data || data.length == 0 || data.length > maximumBytes) return nil;
+    NSString *roundTrip = [[NSString alloc] initWithData:data
+                                                encoding:NSUTF8StringEncoding];
+    return roundTrip && [roundTrip isEqualToString:value] ? data : nil;
+}
+
+static BOOL PXBackupFailureCleanupValidateComponentString(NSString *component,
+                                                           NSData **dataOut) {
+    if (dataOut) *dataOut = nil;
+    NSData *data = PXBackupFailureCleanupLosslessUTF8Data(
+        component,
+        PXBackupFailureCleanupMaximumComponentBytes,
+        NO);
+    if (!data || PXBackupFailureCleanupStringContainsControl(component) ||
+        [component isEqualToString:@"."] ||
+        [component isEqualToString:@".."] ||
+        [component containsString:@"/"] ||
+        [component containsString:@"\\"]) return NO;
+    if (dataOut) *dataOut = data;
+    return YES;
+}
+
+static BOOL PXBackupFailureCleanupValidateEntryName(const char *name,
+                                                     NSUInteger *lengthOut,
+                                                     NSData **dataOut) {
+    if (lengthOut) *lengthOut = 0;
+    if (dataOut) *dataOut = nil;
+    if (!name) return NO;
+    size_t length = 0;
+    while (length <= PXBackupFailureCleanupMaximumComponentBytes &&
+           name[length] != '\0') {
+        length += 1U;
+    }
+    if (length == 0 || length > PXBackupFailureCleanupMaximumComponentBytes ||
+        (length == 1U && name[0] == '.') ||
+        (length == 2U && name[0] == '.' && name[1] == '.')) return NO;
+    for (size_t index = 0; index < length; index++) {
+        unsigned char byte = (unsigned char)name[index];
+        if (byte == '/' || byte == '\\' || byte < 0x20 || byte == 0x7f) return NO;
+    }
+    NSData *data = [NSData dataWithBytes:name length:length];
+    NSString *string = [[NSString alloc] initWithData:data
+                                              encoding:NSUTF8StringEncoding];
+    NSData *roundTrip = [string dataUsingEncoding:NSUTF8StringEncoding
+                              allowLossyConversion:NO];
+    if (!string || !roundTrip || ![roundTrip isEqualToData:data] ||
+        PXBackupFailureCleanupStringContainsControl(string)) return NO;
+    if (lengthOut) *lengthOut = (NSUInteger)length;
+    if (dataOut) *dataOut = data;
+    return YES;
+}
+
+static char *PXBackupFailureCleanupCopyCString(NSData *data) {
+    if (![data isKindOfClass:[NSData class]] || data.length == 0 ||
+        data.length > SIZE_MAX - 1U) return NULL;
+    char *bytes = malloc(data.length + 1U);
+    if (!bytes) return NULL;
+    memcpy(bytes, data.bytes, data.length);
+    bytes[data.length] = '\0';
+    return bytes;
+}
+
+static BOOL PXBackupFailureCleanupEntryIsAbsent(int parentDescriptor,
+                                                 const char *name) {
+    if (parentDescriptor < 0 || !name || name[0] == '\0') return NO;
+    struct stat current;
+    if (fstatat(parentDescriptor, name, &current, AT_SYMLINK_NOFOLLOW) == 0) {
+        return NO;
+    }
+    return errno == ENOENT;
+}
+
+static BOOL PXBackupFailureCleanupPathMatchesDescriptor(
+    NSString *path,
+    int descriptor,
+    const struct stat *expected,
+    BOOL requireWorkspaceMode,
+    struct stat *currentOut) {
+    NSData *pathData = PXBackupFailureCleanupLosslessUTF8Data(
+        path,
+        PXBackupFailureCleanupMaximumWorkspacePathBytes,
+        YES);
+    char *pathBytes = PXBackupFailureCleanupCopyCString(pathData);
+    if (!pathBytes || descriptor < 0 || !expected) {
+        free(pathBytes);
+        return NO;
+    }
+    struct stat pathStat;
+    struct stat descriptorStat;
+    BOOL valid = lstat(pathBytes, &pathStat) == 0 &&
+                 !S_ISLNK(pathStat.st_mode) && S_ISDIR(pathStat.st_mode) &&
+                 (pathStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                 fstat(descriptor, &descriptorStat) == 0 &&
+                 S_ISDIR(descriptorStat.st_mode) &&
+                 (descriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                 (!requireWorkspaceMode ||
+                  (descriptorStat.st_mode & 07777) == 0700) &&
+                 PXBackupFailureCleanupStatIdentityMatches(&pathStat,
+                                                           &descriptorStat) &&
+                 PXBackupFailureCleanupStatIdentityMatches(expected,
+                                                           &descriptorStat) &&
+                 PXBackupFailureCleanupDescriptorHasCloseOnExec(descriptor);
+    if (valid && currentOut) *currentOut = descriptorStat;
+    free(pathBytes);
+    return valid;
+}
+
+static BOOL PXBackupFailureCleanupDirectoryBindingValid(
+    int parentDescriptor,
+    const char *name,
+    int descriptor,
+    const struct stat *expected,
+    dev_t expectedDevice,
+    BOOL requireWorkspaceMode,
+    struct stat *currentOut) {
+    if (parentDescriptor < 0 || descriptor < 0 || !name || name[0] == '\0' ||
+        !expected) return NO;
+    struct stat namespaceStat;
+    struct stat descriptorStat;
+    if (fstatat(parentDescriptor,
+                name,
+                &namespaceStat,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        !S_ISDIR(namespaceStat.st_mode) ||
+        (namespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        fstat(descriptor, &descriptorStat) != 0 ||
+        !S_ISDIR(descriptorStat.st_mode) ||
+        (descriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        (requireWorkspaceMode && (descriptorStat.st_mode & 07777) != 0700) ||
+        namespaceStat.st_dev != expectedDevice ||
+        descriptorStat.st_dev != expectedDevice ||
+        !PXBackupFailureCleanupStatIdentityMatches(&namespaceStat,
+                                                   &descriptorStat) ||
+        !PXBackupFailureCleanupStatIdentityMatches(expected,
+                                                   &descriptorStat) ||
+        !PXBackupFailureCleanupDescriptorHasCloseOnExec(descriptor)) return NO;
+    if (currentOut) *currentOut = descriptorStat;
+    return YES;
+}
+
+static BOOL PXBackupFailureCleanupReadDirectory(
+    int descriptor,
+    PXBackupFailureCleanupTraversalState *state,
+    BOOL collectNames,
+    NSArray<NSData *> **namesOut,
+    BOOL *emptyOut,
+    NSError **error) {
+    if (namesOut) *namesOut = nil;
+    if (emptyOut) *emptyOut = NO;
+    if (descriptor < 0 || (collectNames && !state)) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorTraversalFailed,
+            PXBackupFailureCleanupEntryField,
+            @"The cleanup directory could not be traversed");
+        return NO;
+    }
+    int duplicate = PXBackupFailureCleanupDuplicateDescriptor(descriptor);
+    if (duplicate < 0) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorTraversalFailed,
+            PXBackupFailureCleanupEntryField,
+            @"The cleanup directory could not be traversed");
+        return NO;
+    }
+    DIR *directory = fdopendir(duplicate);
+    if (!directory) {
+        close(duplicate);
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorTraversalFailed,
+            PXBackupFailureCleanupEntryField,
+            @"The cleanup directory could not be traversed");
+        return NO;
+    }
+    NSMutableArray<NSData *> *names = collectNames ? [NSMutableArray array] : nil;
+    BOOL empty = YES;
+    BOOL valid = YES;
+    for (;;) {
+        errno = 0;
+        struct dirent *entry = readdir(directory);
+        if (!entry) {
+            if (errno != 0) valid = NO;
+            break;
+        }
+        if (strcmp(entry->d_name, ".") == 0 ||
+            strcmp(entry->d_name, "..") == 0) continue;
+        empty = NO;
+        if (!collectNames) continue;
+        NSUInteger nameLength = 0;
+        NSData *nameData = nil;
+        if (!PXBackupFailureCleanupValidateEntryName(entry->d_name,
+                                                     &nameLength,
+                                                     &nameData)) {
+            PXBackupFailureCleanupSetError(
+                error,
+                PXBackupFailureCleanupErrorUnsafeEntry,
+                PXBackupFailureCleanupEntryField,
+                @"The cleanup tree contains an unsafe entry name");
+            valid = NO;
+            break;
+        }
+        if (state->visitedEntries >=
+                PXBackupFailureCleanupMaximumVisitedEntries ||
+            nameLength > ULLONG_MAX - state->accumulatedNameBytes ||
+            state->accumulatedNameBytes + nameLength >
+                PXBackupFailureCleanupMaximumAccumulatedNameBytes) {
+            PXBackupFailureCleanupSetError(
+                error,
+                PXBackupFailureCleanupErrorLimitExceeded,
+                PXBackupFailureCleanupEntryField,
+                @"The cleanup tree exceeds fixed traversal limits");
+            valid = NO;
+            break;
+        }
+        state->visitedEntries += 1U;
+        state->accumulatedNameBytes += nameLength;
+        [names addObject:nameData];
+    }
+    if (closedir(directory) != 0 && valid) valid = NO;
+    if (!valid) {
+        if (error && !*error) {
+            PXBackupFailureCleanupSetError(
+                error,
+                PXBackupFailureCleanupErrorTraversalFailed,
+                PXBackupFailureCleanupEntryField,
+                @"The cleanup directory scan failed");
+        }
+        return NO;
+    }
+    if (collectNames && namesOut) *namesOut = [names copy];
+    if (emptyOut) *emptyOut = empty;
+    return YES;
+}
+
+static BOOL PXBackupFailureCleanupDirectoryIsEmpty(int descriptor,
+                                                    BOOL *emptyOut,
+                                                    NSError **error) {
+    return PXBackupFailureCleanupReadDirectory(descriptor,
+                                               NULL,
+                                               NO,
+                                               NULL,
+                                               emptyOut,
+                                               error);
+}
+
+static BOOL PXBackupFailureCleanupScanEntryNames(
+    int descriptor,
+    PXBackupFailureCleanupTraversalState *state,
+    NSArray<NSData *> **namesOut,
+    NSError **error) {
+    return PXBackupFailureCleanupReadDirectory(descriptor,
+                                               state,
+                                               YES,
+                                               namesOut,
+                                               NULL,
+                                               error);
+}
+
+static BOOL PXBackupFailureCleanupRemoveDirectoryContents(
+    int descriptor,
+    const struct stat *directoryIdentity,
+    NSUInteger depth,
+    PXBackupFailureCleanupTraversalState *state,
+    NSError **error);
+
+static BOOL PXBackupFailureCleanupRemoveRegularFile(
+    int parentDescriptor,
+    const char *name,
+    const struct stat *observed,
+    PXBackupFailureCleanupTraversalState *state,
+    NSError **error) {
+    if (!observed || !state || !S_ISREG(observed->st_mode) ||
+        observed->st_dev != state->workspaceDevice ||
+        (observed->st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        observed->st_nlink != 1) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorUnsafeEntry,
+            PXBackupFailureCleanupEntryField,
+            @"The cleanup tree contains an unsafe regular file");
+        return NO;
+    }
+    int descriptor = openat(parentDescriptor,
+                            name,
+                            O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+    if (descriptor < 0) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorEntryChanged,
+            PXBackupFailureCleanupEntryField,
+            @"A cleanup file changed before it could be opened");
+        return NO;
+    }
+    struct stat descriptorStat;
+    struct stat namespaceStat;
+    BOOL valid = fstat(descriptor, &descriptorStat) == 0 &&
+                 S_ISREG(descriptorStat.st_mode) &&
+                 descriptorStat.st_dev == state->workspaceDevice &&
+                 (descriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                 descriptorStat.st_nlink == 1 &&
+                 PXBackupFailureCleanupStableFileMatches(observed,
+                                                         &descriptorStat) &&
+                 PXBackupFailureCleanupDescriptorHasCloseOnExec(descriptor) &&
+                 fstatat(parentDescriptor,
+                         name,
+                         &namespaceStat,
+                         AT_SYMLINK_NOFOLLOW) == 0 &&
+                 PXBackupFailureCleanupStableFileMatches(&namespaceStat,
+                                                         &descriptorStat);
+    if (!valid) {
+        close(descriptor);
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorEntryChanged,
+            PXBackupFailureCleanupEntryField,
+            @"A cleanup file changed during identity validation");
+        return NO;
+    }
+    if (state->removedEntries == NSUIntegerMax) {
+        close(descriptor);
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorLimitExceeded,
+            PXBackupFailureCleanupEntryField,
+            @"The cleanup removal count overflowed");
+        return NO;
+    }
+    if (unlinkat(parentDescriptor, name, 0) != 0) {
+        close(descriptor);
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorRemovalFailed,
+            PXBackupFailureCleanupEntryField,
+            @"A verified cleanup file could not be removed");
+        return NO;
+    }
+    state->removedEntries += 1U;
+    struct stat unlinkedStat;
+    BOOL removed = PXBackupFailureCleanupEntryIsAbsent(parentDescriptor, name) &&
+                   fstat(descriptor, &unlinkedStat) == 0 &&
+                   PXBackupFailureCleanupStatIdentityMatches(&descriptorStat,
+                                                             &unlinkedStat) &&
+                   unlinkedStat.st_nlink == 0;
+    close(descriptor);
+    if (!removed) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorEntryChanged,
+            PXBackupFailureCleanupEntryField,
+            @"A cleanup file changed during removal");
+        return NO;
+    }
+    if (!PXBackupFailureCleanupStrictSync(parentDescriptor)) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorDurabilityFailed,
+            PXBackupFailureCleanupDurabilityField,
+            @"A cleanup file removal could not be synchronized");
+        return NO;
+    }
+    return YES;
+}
+
+static BOOL PXBackupFailureCleanupRemoveSubdirectory(
+    int parentDescriptor,
+    const char *name,
+    const struct stat *observed,
+    NSUInteger depth,
+    PXBackupFailureCleanupTraversalState *state,
+    NSError **error) {
+    if (!observed || !state || !S_ISDIR(observed->st_mode) ||
+        observed->st_dev != state->workspaceDevice ||
+        (observed->st_mode & (S_ISUID | S_ISGID)) != 0) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorUnsafeEntry,
+            PXBackupFailureCleanupEntryField,
+            @"The cleanup tree contains an unsafe directory");
+        return NO;
+    }
+    if (depth >= PXBackupFailureCleanupMaximumDepth) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorLimitExceeded,
+            PXBackupFailureCleanupEntryField,
+            @"The cleanup tree exceeds the maximum depth");
+        return NO;
+    }
+    int descriptor = openat(parentDescriptor,
+                            name,
+                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (descriptor < 0) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorEntryChanged,
+            PXBackupFailureCleanupEntryField,
+            @"A cleanup directory changed before it could be opened");
+        return NO;
+    }
+    struct stat descriptorStat;
+    BOOL bindingValid = fstat(descriptor, &descriptorStat) == 0 &&
+                        S_ISDIR(descriptorStat.st_mode) &&
+                        descriptorStat.st_dev == state->workspaceDevice &&
+                        (descriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                        PXBackupFailureCleanupStatIdentityMatches(observed,
+                                                                 &descriptorStat) &&
+                        PXBackupFailureCleanupDescriptorHasCloseOnExec(descriptor);
+    if (!bindingValid) {
+        close(descriptor);
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorEntryChanged,
+            PXBackupFailureCleanupEntryField,
+            @"A cleanup directory changed during identity validation");
+        return NO;
+    }
+    if (!PXBackupFailureCleanupRemoveDirectoryContents(descriptor,
+                                                       &descriptorStat,
+                                                       depth + 1U,
+                                                       state,
+                                                       error)) {
+        close(descriptor);
+        return NO;
+    }
+    BOOL empty = NO;
+    if (!PXBackupFailureCleanupDirectoryIsEmpty(descriptor, &empty, error) ||
+        !empty) {
+        close(descriptor);
+        if (error && !*error) {
+            PXBackupFailureCleanupSetError(
+                error,
+                PXBackupFailureCleanupErrorEntryChanged,
+                PXBackupFailureCleanupEntryField,
+                @"A cleanup directory was repopulated during traversal");
+        }
+        return NO;
+    }
+    if (!PXBackupFailureCleanupStrictSync(descriptor)) {
+        close(descriptor);
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorDurabilityFailed,
+            PXBackupFailureCleanupDurabilityField,
+            @"A cleanup directory could not be synchronized");
+        return NO;
+    }
+    struct stat namespaceStat;
+    struct stat currentDescriptorStat;
+    BOOL stable = fstatat(parentDescriptor,
+                          name,
+                          &namespaceStat,
+                          AT_SYMLINK_NOFOLLOW) == 0 &&
+                  fstat(descriptor, &currentDescriptorStat) == 0 &&
+                  S_ISDIR(namespaceStat.st_mode) &&
+                  S_ISDIR(currentDescriptorStat.st_mode) &&
+                  namespaceStat.st_dev == state->workspaceDevice &&
+                  currentDescriptorStat.st_dev == state->workspaceDevice &&
+                  (namespaceStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                  (currentDescriptorStat.st_mode & (S_ISUID | S_ISGID)) == 0 &&
+                  PXBackupFailureCleanupStatIdentityMatches(&namespaceStat,
+                                                            &descriptorStat) &&
+                  PXBackupFailureCleanupStatIdentityMatches(&currentDescriptorStat,
+                                                            &descriptorStat);
+    if (!stable) {
+        close(descriptor);
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorEntryChanged,
+            PXBackupFailureCleanupEntryField,
+            @"A cleanup directory changed before removal");
+        return NO;
+    }
+    if (state->removedEntries == NSUIntegerMax) {
+        close(descriptor);
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorLimitExceeded,
+            PXBackupFailureCleanupEntryField,
+            @"The cleanup removal count overflowed");
+        return NO;
+    }
+    if (unlinkat(parentDescriptor, name, AT_REMOVEDIR) != 0) {
+        close(descriptor);
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorRemovalFailed,
+            PXBackupFailureCleanupEntryField,
+            @"A verified cleanup directory could not be removed");
+        return NO;
+    }
+    state->removedEntries += 1U;
+    BOOL removed = PXBackupFailureCleanupEntryIsAbsent(parentDescriptor, name);
+    close(descriptor);
+    if (!removed) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorEntryChanged,
+            PXBackupFailureCleanupEntryField,
+            @"A cleanup directory changed during removal");
+        return NO;
+    }
+    if (!PXBackupFailureCleanupStrictSync(parentDescriptor)) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorDurabilityFailed,
+            PXBackupFailureCleanupDurabilityField,
+            @"A cleanup directory removal could not be synchronized");
+        return NO;
+    }
+    return YES;
+}
+
+static BOOL PXBackupFailureCleanupRemoveDirectoryContents(
+    int descriptor,
+    const struct stat *directoryIdentity,
+    NSUInteger depth,
+    PXBackupFailureCleanupTraversalState *state,
+    NSError **error) {
+    if (descriptor < 0 || !directoryIdentity || !state ||
+        depth > PXBackupFailureCleanupMaximumDepth) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorLimitExceeded,
+            PXBackupFailureCleanupEntryField,
+            @"The cleanup traversal exceeded fixed limits");
+        return NO;
+    }
+    struct stat currentDirectory;
+    if (fstat(descriptor, &currentDirectory) != 0 ||
+        !S_ISDIR(currentDirectory.st_mode) ||
+        currentDirectory.st_dev != state->workspaceDevice ||
+        (currentDirectory.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        !PXBackupFailureCleanupStatIdentityMatches(directoryIdentity,
+                                                   &currentDirectory) ||
+        !PXBackupFailureCleanupDescriptorHasCloseOnExec(descriptor)) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorEntryChanged,
+            PXBackupFailureCleanupEntryField,
+            @"A cleanup directory identity changed during traversal");
+        return NO;
+    }
+    NSArray<NSData *> *names = nil;
+    if (!PXBackupFailureCleanupScanEntryNames(descriptor,
+                                              state,
+                                              &names,
+                                              error)) return NO;
+    for (NSData *nameData in names) {
+        char *name = PXBackupFailureCleanupCopyCString(nameData);
+        if (!name) {
+            PXBackupFailureCleanupSetError(
+                error,
+                PXBackupFailureCleanupErrorLimitExceeded,
+                PXBackupFailureCleanupEntryField,
+                @"A cleanup entry name could not be represented safely");
+            return NO;
+        }
+        struct stat observed;
+        BOOL observedValid = fstatat(descriptor,
+                                     name,
+                                     &observed,
+                                     AT_SYMLINK_NOFOLLOW) == 0;
+        if (!observedValid) {
+            free(name);
+            PXBackupFailureCleanupSetError(
+                error,
+                PXBackupFailureCleanupErrorEntryChanged,
+                PXBackupFailureCleanupEntryField,
+                @"A cleanup entry changed before inspection");
+            return NO;
+        }
+        BOOL removed = NO;
+        if (S_ISREG(observed.st_mode)) {
+            removed = PXBackupFailureCleanupRemoveRegularFile(descriptor,
+                                                              name,
+                                                              &observed,
+                                                              state,
+                                                              error);
+        } else if (S_ISDIR(observed.st_mode)) {
+            removed = PXBackupFailureCleanupRemoveSubdirectory(descriptor,
+                                                               name,
+                                                               &observed,
+                                                               depth,
+                                                               state,
+                                                               error);
+        } else {
+            PXBackupFailureCleanupSetError(
+                error,
+                PXBackupFailureCleanupErrorUnsafeEntry,
+                PXBackupFailureCleanupEntryField,
+                @"The cleanup tree contains an unsupported entry type");
+        }
+        free(name);
+        if (!removed) return NO;
+    }
+    BOOL empty = NO;
+    if (!PXBackupFailureCleanupDirectoryIsEmpty(descriptor, &empty, error)) {
+        return NO;
+    }
+    if (!empty) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorEntryChanged,
+            PXBackupFailureCleanupEntryField,
+            @"The cleanup directory changed during traversal");
+        return NO;
+    }
+    return YES;
+}
+
+static BOOL PXBackupFailureCleanupRemoveExactEmptyWorkspace(
+    int parentDescriptor,
+    const char *workspaceName,
+    int workspaceDescriptor,
+    const struct stat *workspaceIdentity,
+    dev_t expectedDevice) {
+    BOOL empty = NO;
+    NSError *ignoredError = nil;
+    if (!PXBackupFailureCleanupDirectoryBindingValid(parentDescriptor,
+                                                     workspaceName,
+                                                     workspaceDescriptor,
+                                                     workspaceIdentity,
+                                                     expectedDevice,
+                                                     YES,
+                                                     NULL) ||
+        !PXBackupFailureCleanupDirectoryIsEmpty(workspaceDescriptor,
+                                                &empty,
+                                                &ignoredError) ||
+        !empty ||
+        !PXBackupFailureCleanupStrictSync(workspaceDescriptor) ||
+        unlinkat(parentDescriptor, workspaceName, AT_REMOVEDIR) != 0 ||
+        !PXBackupFailureCleanupEntryIsAbsent(parentDescriptor, workspaceName) ||
+        !PXBackupFailureCleanupStrictSync(parentDescriptor)) return NO;
+    return YES;
+}
+
+@interface PXBackupFailureCleanup () {
+    PXBackupPublicationWorkspace *_workspace;
+    PXBackupBundleLock *_bundleLock;
+    NSString *_parentPath;
+    NSString *_workspacePath;
+    NSString *_workspaceName;
+    int _parentDescriptor;
+    int _workspaceDescriptor;
+    struct stat _parentIdentity;
+    struct stat _workspaceIdentity;
+    BOOL _cleanupAttempted;
+    BOOL _cleaned;
+    BOOL _disarmed;
+    NSUInteger _removedEntryCount;
+}
+
+- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
+                       bundleLock:(PXBackupBundleLock *)bundleLock
+                       parentPath:(NSString *)parentPath
+                    workspacePath:(NSString *)workspacePath
+                    workspaceName:(NSString *)workspaceName
+                 parentDescriptor:(int)parentDescriptor
+              workspaceDescriptor:(int)workspaceDescriptor
+                   parentIdentity:(const struct stat *)parentIdentity
+                workspaceIdentity:(const struct stat *)workspaceIdentity;
+
+- (BOOL)validateActiveIdentityAllowAttempted:(BOOL)allowAttempted
+                                       error:(NSError **)error;
+
+@end
+
+@implementation PXBackupFailureCleanup
+
++ (instancetype)cleanupForWorkspace:(PXBackupPublicationWorkspace *)workspace
+                         bundleLock:(PXBackupBundleLock *)bundleLock
+                              error:(NSError **)error {
+    if (error) *error = nil;
+    NSError *setupError = nil;
+    NSError *lockError = nil;
+    NSError *workspaceError = nil;
+    NSString *parentPath = nil;
+    NSString *workspacePath = nil;
+    NSString *workspaceName = nil;
+    NSString *expectedWorkspacePath = nil;
+    NSData *parentPathData = nil;
+    NSData *workspaceNameData = nil;
+    char *parentPathBytes = NULL;
+    char *workspaceNameBytes = NULL;
+    int parentDescriptor = -1;
+    int workspaceDescriptor = -1;
+    BOOL authorityEstablished = NO;
+    PXBackupFailureCleanup *cleanup = nil;
+    struct stat parentPathStat;
+    struct stat parentDescriptorStat;
+    struct stat workspaceNamespaceStat;
+    struct stat workspaceDescriptorStat;
+    memset(&parentPathStat, 0, sizeof(parentPathStat));
+    memset(&parentDescriptorStat, 0, sizeof(parentDescriptorStat));
+    memset(&workspaceNamespaceStat, 0, sizeof(workspaceNamespaceStat));
+    memset(&workspaceDescriptorStat, 0, sizeof(workspaceDescriptorStat));
+
+    if (![workspace isMemberOfClass:[PXBackupPublicationWorkspace class]] ||
+        ![bundleLock isMemberOfClass:[PXBackupBundleLock class]]) {
+        PXBackupFailureCleanupSetError(
+            &setupError,
+            PXBackupFailureCleanupErrorInvalidInput,
+            PXBackupFailureCleanupField,
+            @"The backup cleanup inputs are invalid");
+        goto finish;
+    }
+    parentPath = bundleLock.canonicalBundleDirectoryPath;
+    workspacePath = workspace.workspacePath;
+    workspaceName = workspace.workspaceName;
+    expectedWorkspacePath =
+        [parentPath stringByAppendingPathComponent:workspaceName];
+    if (![workspace.bundleIdentifier isEqualToString:bundleLock.bundleIdentifier] ||
+        ![workspace.canonicalBundleDirectoryPath isEqualToString:parentPath] ||
+        ![workspaceName hasPrefix:PXBackupPublicationPartialDirectoryPrefix] ||
+        ![workspacePath isEqualToString:expectedWorkspacePath]) {
+        PXBackupFailureCleanupSetError(
+            &setupError,
+            PXBackupFailureCleanupErrorInvalidInput,
+            PXBackupFailureCleanupWorkspaceField,
+            @"The backup cleanup identity is inconsistent");
+        goto finish;
+    }
+    parentPathData = PXBackupFailureCleanupLosslessUTF8Data(
+        parentPath,
+        PXBackupFailureCleanupMaximumWorkspacePathBytes,
+        YES);
+    if (!parentPathData ||
+        !PXBackupFailureCleanupValidateComponentString(workspaceName,
+                                                       &workspaceNameData)) {
+        PXBackupFailureCleanupSetError(
+            &setupError,
+            PXBackupFailureCleanupErrorLimitExceeded,
+            PXBackupFailureCleanupWorkspaceField,
+            @"The backup cleanup path exceeds fixed limits");
+        goto finish;
+    }
+    lockError = nil;
+    if (![bundleLock validateOwnershipWithError:&lockError]) {
+        PXBackupFailureCleanupSetError(
+            &setupError,
+            PXBackupFailureCleanupErrorLockValidationFailed,
+            PXBackupFailureCleanupLockField,
+            @"The backup lock failed cleanup validation");
+        goto finish;
+    }
+    workspaceError = nil;
+    if (![workspace validateIdentityWithError:&workspaceError]) {
+        PXBackupFailureCleanupSetError(
+            &setupError,
+            PXBackupFailureCleanupErrorWorkspaceInspectionFailed,
+            PXBackupFailureCleanupWorkspaceField,
+            @"The backup workspace failed cleanup validation");
+        goto finish;
+    }
+    parentPathBytes = PXBackupFailureCleanupCopyCString(parentPathData);
+    workspaceNameBytes = PXBackupFailureCleanupCopyCString(workspaceNameData);
+    if (!parentPathBytes || !workspaceNameBytes) {
+        PXBackupFailureCleanupSetError(
+            &setupError,
+            PXBackupFailureCleanupErrorLimitExceeded,
+            PXBackupFailureCleanupField,
+            @"The backup cleanup path could not be represented safely");
+        goto finish;
+    }
+    if (lstat(parentPathBytes, &parentPathStat) != 0 ||
+        S_ISLNK(parentPathStat.st_mode) ||
+        !S_ISDIR(parentPathStat.st_mode) ||
+        (parentPathStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
+        PXBackupFailureCleanupSetError(
+            &setupError,
+            PXBackupFailureCleanupErrorParentInspectionFailed,
+            PXBackupFailureCleanupParentField,
+            @"The backup cleanup parent is invalid");
+        goto finish;
+    }
+    parentDescriptor = open(parentPathBytes,
+                            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (parentDescriptor < 0 ||
+        fstat(parentDescriptor, &parentDescriptorStat) != 0 ||
+        !S_ISDIR(parentDescriptorStat.st_mode) ||
+        (parentDescriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        !PXBackupFailureCleanupStatIdentityMatches(&parentPathStat,
+                                                   &parentDescriptorStat) ||
+        !PXBackupFailureCleanupDescriptorHasCloseOnExec(parentDescriptor)) {
+        PXBackupFailureCleanupSetError(
+            &setupError,
+            PXBackupFailureCleanupErrorParentInspectionFailed,
+            PXBackupFailureCleanupParentField,
+            @"The backup cleanup parent descriptor is invalid");
+        goto finish;
+    }
+    if (fstatat(parentDescriptor,
+                workspaceNameBytes,
+                &workspaceNamespaceStat,
+                AT_SYMLINK_NOFOLLOW) != 0 ||
+        !S_ISDIR(workspaceNamespaceStat.st_mode) ||
+        (workspaceNamespaceStat.st_mode & 07777) != 0700 ||
+        (workspaceNamespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        workspaceNamespaceStat.st_dev != parentDescriptorStat.st_dev) {
+        PXBackupFailureCleanupSetError(
+            &setupError,
+            PXBackupFailureCleanupErrorWorkspaceInspectionFailed,
+            PXBackupFailureCleanupWorkspaceField,
+            @"The backup cleanup workspace namespace is invalid");
+        goto finish;
+    }
+    workspaceDescriptor = openat(parentDescriptor,
+                                 workspaceNameBytes,
+                                 O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+    if (workspaceDescriptor < 0 ||
+        fstat(workspaceDescriptor, &workspaceDescriptorStat) != 0 ||
+        !S_ISDIR(workspaceDescriptorStat.st_mode) ||
+        (workspaceDescriptorStat.st_mode & 07777) != 0700 ||
+        (workspaceDescriptorStat.st_mode & (S_ISUID | S_ISGID)) != 0 ||
+        workspaceDescriptorStat.st_dev != parentDescriptorStat.st_dev ||
+        !PXBackupFailureCleanupStatIdentityMatches(&workspaceNamespaceStat,
+                                                   &workspaceDescriptorStat) ||
+        !PXBackupFailureCleanupDescriptorHasCloseOnExec(workspaceDescriptor) ||
+        !PXBackupFailureCleanupPathMatchesDescriptor(workspacePath,
+                                                     workspaceDescriptor,
+                                                     &workspaceDescriptorStat,
+                                                     YES,
+                                                     NULL)) {
+        PXBackupFailureCleanupSetError(
+            &setupError,
+            PXBackupFailureCleanupErrorWorkspaceInspectionFailed,
+            PXBackupFailureCleanupWorkspaceField,
+            @"The backup cleanup workspace descriptor is invalid");
+        goto finish;
+    }
+    authorityEstablished = YES;
+    workspaceError = nil;
+    if (![workspace validateIdentityWithError:&workspaceError] ||
+        !PXBackupFailureCleanupDirectoryBindingValid(parentDescriptor,
+                                                     workspaceNameBytes,
+                                                     workspaceDescriptor,
+                                                     &workspaceDescriptorStat,
+                                                     parentDescriptorStat.st_dev,
+                                                     YES,
+                                                     NULL)) {
+        PXBackupFailureCleanupSetError(
+            &setupError,
+            PXBackupFailureCleanupErrorWorkspaceChanged,
+            PXBackupFailureCleanupWorkspaceField,
+            @"The backup cleanup workspace identity changed");
+        goto finish;
+    }
+    cleanup = [[PXBackupFailureCleanup alloc]
+        initWithWorkspace:workspace
+               bundleLock:bundleLock
+               parentPath:parentPath
+            workspacePath:workspacePath
+            workspaceName:workspaceName
+         parentDescriptor:parentDescriptor
+      workspaceDescriptor:workspaceDescriptor
+           parentIdentity:&parentDescriptorStat
+        workspaceIdentity:&workspaceDescriptorStat];
+    if (!cleanup) {
+        PXBackupFailureCleanupSetError(
+            &setupError,
+            PXBackupFailureCleanupErrorWorkspaceInspectionFailed,
+            PXBackupFailureCleanupWorkspaceField,
+            @"The backup cleanup authority could not be retained");
+        goto finish;
+    }
+    parentDescriptor = -1;
+    workspaceDescriptor = -1;
+
+finish:
+    if (!cleanup && authorityEstablished) {
+        BOOL factoryCleanupSucceeded =
+            PXBackupFailureCleanupRemoveExactEmptyWorkspace(
+                parentDescriptor,
+                workspaceNameBytes,
+                workspaceDescriptor,
+                &workspaceDescriptorStat,
+                parentDescriptorStat.st_dev);
+        if (!factoryCleanupSucceeded) {
+            PXBackupFailureCleanupSetError(
+                &setupError,
+                PXBackupFailureCleanupErrorFactoryCleanupFailed,
+                PXBackupFailureCleanupWorkspaceField,
+                @"The failed cleanup factory could not remove its empty workspace safely");
+        }
+    }
+    if (workspaceDescriptor >= 0) close(workspaceDescriptor);
+    if (parentDescriptor >= 0) close(parentDescriptor);
+    free(parentPathBytes);
+    free(workspaceNameBytes);
+    if (!cleanup && error) *error = setupError ?: [NSError
+        errorWithDomain:PXBackupFailureCleanupErrorDomain
+                   code:PXBackupFailureCleanupErrorWorkspaceInspectionFailed
+               userInfo:@{
+                   NSLocalizedDescriptionKey: @"The backup cleanup authority could not be created",
+                   PXBackupFailureCleanupErrorFieldPathKey: PXBackupFailureCleanupField,
+               }];
+    return cleanup;
+}
+
+- (instancetype)initWithWorkspace:(PXBackupPublicationWorkspace *)workspace
+                       bundleLock:(PXBackupBundleLock *)bundleLock
+                       parentPath:(NSString *)parentPath
+                    workspacePath:(NSString *)workspacePath
+                    workspaceName:(NSString *)workspaceName
+                 parentDescriptor:(int)parentDescriptor
+              workspaceDescriptor:(int)workspaceDescriptor
+                   parentIdentity:(const struct stat *)parentIdentity
+                workspaceIdentity:(const struct stat *)workspaceIdentity {
+    self = [super init];
+    if (self) {
+        _workspace = workspace;
+        _bundleLock = bundleLock;
+        _parentPath = [parentPath copy];
+        _workspacePath = [workspacePath copy];
+        _workspaceName = [workspaceName copy];
+        _parentDescriptor = parentDescriptor;
+        _workspaceDescriptor = workspaceDescriptor;
+        if (parentIdentity) _parentIdentity = *parentIdentity;
+        if (workspaceIdentity) _workspaceIdentity = *workspaceIdentity;
+    }
+    return self;
+}
+
+- (NSString *)workspacePath { return _workspacePath; }
+- (NSString *)workspaceName { return _workspaceName; }
+- (BOOL)cleanupAttempted { return _cleanupAttempted; }
+- (BOOL)cleaned { return _cleaned; }
+- (BOOL)disarmed { return _disarmed; }
+- (NSUInteger)removedEntryCount { return _removedEntryCount; }
+
+- (BOOL)validateActiveIdentityAllowAttempted:(BOOL)allowAttempted
+                                       error:(NSError **)error {
+    if (error) *error = nil;
+    if (_cleaned || _disarmed || (!allowAttempted && _cleanupAttempted) ||
+        _parentDescriptor < 0 || _workspaceDescriptor < 0) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorAlreadyFinished,
+            PXBackupFailureCleanupField,
+            @"The backup cleanup operation is already finished");
+        return NO;
+    }
+    NSError *lockError = nil;
+    if (![_bundleLock validateOwnershipWithError:&lockError]) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorLockValidationFailed,
+            PXBackupFailureCleanupLockField,
+            @"The retained backup lock is invalid");
+        return NO;
+    }
+    if (!PXBackupFailureCleanupPathMatchesDescriptor(_parentPath,
+                                                     _parentDescriptor,
+                                                     &_parentIdentity,
+                                                     NO,
+                                                     NULL)) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorWorkspaceChanged,
+            PXBackupFailureCleanupParentField,
+            @"The retained cleanup parent identity changed");
+        return NO;
+    }
+    NSData *workspaceNameData = nil;
+    if (!PXBackupFailureCleanupValidateComponentString(_workspaceName,
+                                                       &workspaceNameData)) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorWorkspaceChanged,
+            PXBackupFailureCleanupWorkspaceField,
+            @"The retained cleanup workspace name is invalid");
+        return NO;
+    }
+    char *workspaceNameBytes = PXBackupFailureCleanupCopyCString(workspaceNameData);
+    if (!workspaceNameBytes) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorLimitExceeded,
+            PXBackupFailureCleanupWorkspaceField,
+            @"The retained cleanup workspace name exceeds limits");
+        return NO;
+    }
+    struct stat namespaceStat;
+    if (fstatat(_parentDescriptor,
+                workspaceNameBytes,
+                &namespaceStat,
+                AT_SYMLINK_NOFOLLOW) != 0) {
+        int failureErrno = errno;
+        free(workspaceNameBytes);
+        PXBackupFailureCleanupSetError(
+            error,
+            failureErrno == ENOENT
+                ? PXBackupFailureCleanupErrorPublishedStateDetected
+                : PXBackupFailureCleanupErrorWorkspaceChanged,
+            PXBackupFailureCleanupPublicationField,
+            failureErrno == ENOENT
+                ? @"The original partial workspace is no longer present"
+                : @"The original partial workspace could not be inspected");
+        return NO;
+    }
+    BOOL bindingValid =
+        PXBackupFailureCleanupDirectoryBindingValid(_parentDescriptor,
+                                                     workspaceNameBytes,
+                                                     _workspaceDescriptor,
+                                                     &_workspaceIdentity,
+                                                     _parentIdentity.st_dev,
+                                                     YES,
+                                                     NULL) &&
+        PXBackupFailureCleanupPathMatchesDescriptor(_workspacePath,
+                                                    _workspaceDescriptor,
+                                                    &_workspaceIdentity,
+                                                    YES,
+                                                    NULL);
+    free(workspaceNameBytes);
+    NSError *workspaceError = nil;
+    if (!bindingValid ||
+        ![_workspace validateIdentityWithError:&workspaceError]) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorWorkspaceChanged,
+            PXBackupFailureCleanupWorkspaceField,
+            @"The retained cleanup workspace identity changed");
+        return NO;
+    }
+    return YES;
+}
+
+- (BOOL)validateIdentityWithError:(NSError **)error {
+    return [self validateActiveIdentityAllowAttempted:NO error:error];
+}
+
+- (BOOL)cleanupWithError:(NSError **)error {
+    if (error) *error = nil;
+    if (_cleanupAttempted || _cleaned || _disarmed) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorAlreadyFinished,
+            PXBackupFailureCleanupField,
+            @"The backup cleanup operation is already finished");
+        return NO;
+    }
+    _cleanupAttempted = YES;
+    NSError *identityError = nil;
+    if (![self validateActiveIdentityAllowAttempted:YES
+                                             error:&identityError]) {
+        if (error) *error = identityError;
+        return NO;
+    }
+    PXBackupFailureCleanupTraversalState state;
+    memset(&state, 0, sizeof(state));
+    state.workspaceDevice = _workspaceIdentity.st_dev;
+    NSError *traversalError = nil;
+    BOOL traversalSucceeded =
+        PXBackupFailureCleanupRemoveDirectoryContents(_workspaceDescriptor,
+                                                       &_workspaceIdentity,
+                                                       0U,
+                                                       &state,
+                                                       &traversalError);
+    _removedEntryCount = state.removedEntries;
+    if (!traversalSucceeded) {
+        if (_removedEntryCount > 0) {
+            PXBackupFailureCleanupSetError(
+                error,
+                PXBackupFailureCleanupErrorCleanupIncomplete,
+                PXBackupFailureCleanupEntryField,
+                @"The backup cleanup stopped after removing verified entries");
+        } else if (error) {
+            *error = traversalError ?: [NSError
+                errorWithDomain:PXBackupFailureCleanupErrorDomain
+                           code:PXBackupFailureCleanupErrorTraversalFailed
+                       userInfo:@{
+                           NSLocalizedDescriptionKey: @"The backup cleanup traversal failed",
+                           PXBackupFailureCleanupErrorFieldPathKey: PXBackupFailureCleanupEntryField,
+                       }];
+        }
+        return NO;
+    }
+    BOOL empty = NO;
+    NSError *emptyError = nil;
+    if (!PXBackupFailureCleanupDirectoryIsEmpty(_workspaceDescriptor,
+                                                &empty,
+                                                &emptyError) ||
+        !empty) {
+        if (_removedEntryCount > 0) {
+            PXBackupFailureCleanupSetError(
+                error,
+                PXBackupFailureCleanupErrorCleanupIncomplete,
+                PXBackupFailureCleanupEntryField,
+                @"The backup cleanup workspace was repopulated during cleanup");
+        } else if (error) {
+            *error = emptyError ?: [NSError
+                errorWithDomain:PXBackupFailureCleanupErrorDomain
+                           code:PXBackupFailureCleanupErrorEntryChanged
+                       userInfo:@{
+                           NSLocalizedDescriptionKey: @"The backup cleanup workspace is not empty",
+                           PXBackupFailureCleanupErrorFieldPathKey: PXBackupFailureCleanupEntryField,
+                       }];
+        }
+        return NO;
+    }
+    if (!PXBackupFailureCleanupStrictSync(_workspaceDescriptor)) {
+        PXBackupFailureCleanupSetError(
+            error,
+            _removedEntryCount > 0
+                ? PXBackupFailureCleanupErrorCleanupIncomplete
+                : PXBackupFailureCleanupErrorDurabilityFailed,
+            PXBackupFailureCleanupDurabilityField,
+            @"The backup cleanup workspace could not be synchronized");
+        return NO;
+    }
+    NSData *workspaceNameData = nil;
+    char *workspaceNameBytes = NULL;
+    if (!PXBackupFailureCleanupValidateComponentString(_workspaceName,
+                                                       &workspaceNameData) ||
+        !(workspaceNameBytes =
+              PXBackupFailureCleanupCopyCString(workspaceNameData)) ||
+        !PXBackupFailureCleanupDirectoryBindingValid(_parentDescriptor,
+                                                     workspaceNameBytes,
+                                                     _workspaceDescriptor,
+                                                     &_workspaceIdentity,
+                                                     _parentIdentity.st_dev,
+                                                     YES,
+                                                     NULL)) {
+        free(workspaceNameBytes);
+        PXBackupFailureCleanupSetError(
+            error,
+            _removedEntryCount > 0
+                ? PXBackupFailureCleanupErrorCleanupIncomplete
+                : PXBackupFailureCleanupErrorWorkspaceChanged,
+            PXBackupFailureCleanupWorkspaceField,
+            @"The backup cleanup workspace changed before root removal");
+        return NO;
+    }
+    if (_removedEntryCount == NSUIntegerMax) {
+        free(workspaceNameBytes);
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorCleanupIncomplete,
+            PXBackupFailureCleanupEntryField,
+            @"The cleanup removal count overflowed");
+        return NO;
+    }
+    if (unlinkat(_parentDescriptor, workspaceNameBytes, AT_REMOVEDIR) != 0) {
+        free(workspaceNameBytes);
+        PXBackupFailureCleanupSetError(
+            error,
+            _removedEntryCount > 0
+                ? PXBackupFailureCleanupErrorCleanupIncomplete
+                : PXBackupFailureCleanupErrorRemovalFailed,
+            PXBackupFailureCleanupWorkspaceField,
+            @"The verified backup workspace could not be removed");
+        return NO;
+    }
+    _removedEntryCount += 1U;
+    if (!PXBackupFailureCleanupEntryIsAbsent(_parentDescriptor,
+                                             workspaceNameBytes)) {
+        free(workspaceNameBytes);
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorCleanupIncomplete,
+            PXBackupFailureCleanupWorkspaceField,
+            @"The backup workspace namespace changed during root removal");
+        return NO;
+    }
+    free(workspaceNameBytes);
+    if (!PXBackupFailureCleanupStrictSync(_parentDescriptor)) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorCleanupIncomplete,
+            PXBackupFailureCleanupDurabilityField,
+            @"The backup workspace removal could not be synchronized");
+        return NO;
+    }
+    _cleaned = YES;
+    close(_workspaceDescriptor);
+    _workspaceDescriptor = -1;
+    close(_parentDescriptor);
+    _parentDescriptor = -1;
+    return YES;
+}
+
+- (BOOL)disarmAfterPublishedDirectory:(PXBackupDirectoryPublisher *)publisher
+                                error:(NSError **)error {
+    if (error) *error = nil;
+    if (_cleanupAttempted || _cleaned || _disarmed ||
+        _parentDescriptor < 0 || _workspaceDescriptor < 0) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorAlreadyFinished,
+            PXBackupFailureCleanupField,
+            @"The backup cleanup operation is already finished");
+        return NO;
+    }
+    if (![publisher isMemberOfClass:[PXBackupDirectoryPublisher class]] ||
+        !publisher.isPublished ||
+        ![publisher.workspacePath isEqualToString:_workspacePath] ||
+        publisher.publishedDirectoryPath.length == 0 ||
+        [publisher.publishedDirectoryPath isEqualToString:_workspacePath] ||
+        publisher.publishedManifestPath.length == 0 ||
+        ![[publisher.publishedManifestPath stringByDeletingLastPathComponent]
+            isEqualToString:publisher.publishedDirectoryPath]) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorDisarmValidationFailed,
+            PXBackupFailureCleanupPublicationField,
+            @"The published backup cannot disarm the cleanup authority");
+        return NO;
+    }
+    NSError *publisherError = nil;
+    if (![publisher validateIdentityWithError:&publisherError]) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorDisarmValidationFailed,
+            PXBackupFailureCleanupPublicationField,
+            @"The published backup failed cleanup disarm validation");
+        return NO;
+    }
+    NSError *lockError = nil;
+    if (![_bundleLock validateOwnershipWithError:&lockError]) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorLockValidationFailed,
+            PXBackupFailureCleanupLockField,
+            @"The backup lock failed cleanup disarm validation");
+        return NO;
+    }
+    if (!PXBackupFailureCleanupPathMatchesDescriptor(_parentPath,
+                                                     _parentDescriptor,
+                                                     &_parentIdentity,
+                                                     NO,
+                                                     NULL)) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorDisarmValidationFailed,
+            PXBackupFailureCleanupParentField,
+            @"The cleanup parent changed before disarm");
+        return NO;
+    }
+    NSData *workspaceNameData = nil;
+    char *workspaceNameBytes = NULL;
+    BOOL originalPartialAbsent =
+        PXBackupFailureCleanupValidateComponentString(_workspaceName,
+                                                      &workspaceNameData) &&
+        (workspaceNameBytes =
+             PXBackupFailureCleanupCopyCString(workspaceNameData)) &&
+        PXBackupFailureCleanupEntryIsAbsent(_parentDescriptor,
+                                            workspaceNameBytes);
+    free(workspaceNameBytes);
+    if (!originalPartialAbsent) {
+        PXBackupFailureCleanupSetError(
+            error,
+            PXBackupFailureCleanupErrorDisarmValidationFailed,
+            PXBackupFailureCleanupPublicationField,
+            @"The original partial workspace is still present during disarm");
+        return NO;
+    }
+    _disarmed = YES;
+    close(_workspaceDescriptor);
+    _workspaceDescriptor = -1;
+    close(_parentDescriptor);
+    _parentDescriptor = -1;
+    return YES;
+}
+
+- (void)dealloc {
+    if (_workspaceDescriptor >= 0) close(_workspaceDescriptor);
+    if (_parentDescriptor >= 0) close(_parentDescriptor);
+}
+
+@end
```

## Whitespace, CRLF and NUL audit

- production and report NUL bytes: 0
- new report CRLF sequences: 0
- final newline: present
- git diff --check before staging: PASS
- temporary patch/report generators are removed before staging

## Build status and remaining risks

Local Windows gates include strict Objective-C frontend/analyzer parsing with external Foundation/POSIX declarations, manager harness compilation with and without NS_BLOCK_ASSERTIONS, static source audits and an executable deterministic state model.

Full Theos/Apple SDK arm64 and arm64e linking plus target-device APFS race/fault replay remain pending because this workspace has no Theos, xcrun or linked iOS runtime. Runtime tests should inject readdir, unlinkat and fsync failures, concurrent entry replacement, rollback-restored cleanup, rollback-failed publication preservation and disarm failure after final publication.

No stale-workspace scan, age threshold, prior-crash cleanup, rollback-failed final recovery, discovery validation, marker/index/quarantine behavior, TASK-3.10 or later-phase work was implemented.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
