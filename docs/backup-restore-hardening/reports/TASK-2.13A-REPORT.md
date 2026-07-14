# TASK-2.13A Report — Implement Optional Directory Tree Verifier

## Baseline and exact scope

- Required baseline: `08d23dd0a9fa41a39efd5b62680974f23e75fe45`
- Observed baseline HEAD before source edit: `08d23dd0a9fa41a39efd5b62680974f23e75fe45`
- Allowed production file: `PXOptionalRestoreTransaction.m`
- Required report: `docs/backup-restore-hardening/reports/TASK-2.13A-REPORT.md`
- Implementation commit scope must contain exactly those two files.

Baseline evidence captured before source mutation:

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
08d23dd0a9fa41a39efd5b62680974f23e75fe45

git log -4 --oneline
08d23dd phase2(task-2.13): add transactional optional component handling
9e83a05 phase2(task-2.12): add transactional app group commit
9790a22 phase2(task-2.11A): fix transaction pre-recovery proof and durability
e38db40 phase2(task-2.11): add transactional main-data commit
```

## TASK-2.13 blocker

TASK-2.13 production source called `PXOptionalRestoreVerifyDirectoryTree(...)` at two security-critical locations but had no declaration or implementation. A strict Objective-C frontend could reject the implicit call and a permissive compile would leave an unresolved external symbol. The absent verifier also meant DirectoryObject replacement preparation and no-journal cleanup lacked the required deterministic full-tree proof.

## Before/after private-symbol inventory

| Inventory | Before | After | Required |
|---|---:|---:|---:|
| Verifier call sites | 2 | 2 | 2 |
| File-local static definitions | 0 | 1 | 1 |
| Repository production definitions | 0 | 1 | 1 |
| Repository production occurrences | 2 | 3 | 3 total |
| Implicit declaration diagnostics | blocker present | 0 | 0 |
| Semantic undefined verifier references | 2 unresolved calls | 0 | 0 |

Exact private signature:

```objc
static BOOL PXOptionalRestoreVerifyDirectoryTree(
    int rootDescriptor,
    PXValidatedMainDataStage *expectedStage,
    NSError **error);
```

Current call-site lines: 2996, 3546. Both existing call-site bodies are byte-identical to baseline.

## Input and error contract

- Clears `*error` on entry when non-null.
- Requires a nonnegative descriptor and runtime `PXValidatedMainDataStage` instance.
- Requires a 64-character lowercase SHA-256 string.
- Validates `regularFileCount`, `directoryCount`, overflow-safe sum, exact `entryCount`, and the 500000-entry ceiling.
- Uses `regularFileBytes` as an exact accepted total.
- Invalid input maps to `PXOptionalRestoreTransactionErrorInvalidInput`, field `$.replacement`.
- All verifier descriptions are generic and contain no path, filename, digest, count, inode, device, errno, or nested error.

## Descriptor ownership

- The caller root descriptor is never closed or replaced.
- Traversal begins from `dup` through `PXOptionalRestoreDuplicateDescriptor`; close-on-exec is set and verified.
- Every directory/file is opened descriptor-relatively with `openat` and no-follow flags.
- The iterative frame stack owns directory descriptors and closes them on success and failure.
- File descriptors are explicitly closed and close success is required.
- No absolute replacement path, `NSFileManager`, shell, process, `nftw`, `fts`, `glob`, or `realpath` traversal is used.

## Deterministic traversal and path limits

- Iterative depth-first pre-order traversal; no recursive call stack.
- Every directory is enumerated through an independently duplicated descriptor.
- Names are sorted by exact raw-byte comparison before traversal.
- No locale collation, case folding, Unicode normalization, or filesystem enumeration order authority.
- Relative paths concatenate exact component bytes with one `/` byte.
- Strict UTF-8 decode and byte-for-byte round trip.
- Component maximum 255 bytes; full path maximum 4096 bytes; depth maximum 2048; entries maximum 500000.

## Type, link, mount, and reserved-name policy

| Entry | Result |
|---|---|
| Regular file with `st_nlink == 1` | Allowed |
| Directory | Allowed |
| Symlink, FIFO, socket, char/block device, unknown type | Rejected |
| Hard-linked regular file | Rejected |
| Setuid/setgid root or entry | Rejected |
| Device/mount crossing | Rejected |
| Root-level container metadata names | Rejected |
| Any component beginning `.weaponx-optional-restore-` | Rejected |

## Directory stability

Each directory retains device, inode, full type/mode, mtime, and ctime. It is checked before enumeration, after sorted enumeration, and again before frame pop. Namespace stat and opened descriptor identity must agree. Root stability is checked once more through the caller descriptor after traversal.

## Regular-file streaming and stability

Each file is inspected with no-follow `fstatat`, opened with `O_RDONLY|O_NONBLOCK|O_NOFOLLOW|O_CLOEXEC`, and bound by device/inode/type. Contents are streamed through the fixed 64 KiB buffer. Reads retry only `EINTR`; byte counters are overflow-safe; exact retained size is required. Before/after device, inode, mode/type, link count, size, mtime, and ctime must remain equal. Whole-file `NSData` loading count is zero.

## Exact digest contract

Digest initialization is exactly:

```c
static const unsigned char domainPrefix[] = "PXMainDataStageTreeV1";
CC_SHA256_Update(&digestContext, domainPrefix, (CC_LONG)sizeof(domainPrefix));
```

`sizeof(domainPrefix)` is 22 bytes and includes the terminating NUL. Each entry appends `D` or `F`, big-endian uint32 path length, exact path bytes, big-endian uint32 `mode & 07777`, and big-endian uint64 size. Files append raw contents immediately after the header; directories append no content.

Model vectors:

```text
empty tree SHA-256: 4781eb8ee86207d7309c365562cd9d60abba337c3a9957770fa1f57b18d55c17
nested raw order: a, a/z, b
nested tree SHA-256: 67d4a5329717747cf88938467a4728ee5aee11c23fb4dba7617ee93c15df221c
path length 3: 00000003
mode 0644: 000001a4
size 2: 0000000000000002
```

## Exact five-field snapshot comparison

Success requires exact equality of `entryCount`, `regularFileCount`, `directoryCount`, `regularFileBytes`, and lowercase `treeSHA256`. Any mismatch maps to `ReplacementMismatch` at `$.replacement`; digest-only or top-level-only acceptance is impossible.

## Existing call-site proofs

- DirectoryObject replacement preparation call site remains present at line 2996 and its complete body hash is unchanged from baseline.
- No-journal replacement cleanup proof remains present at line 3546 and its complete body hash is unchanged from baseline.
- Neither call was removed, bypassed, or converted to unconditional success.

## Strict compile/link and undefined-symbol evidence

Strongest locally available frontend command used an external `%TEMP%` stub and:

```text
clang-tidy strict_source.m -checks=-*,clang-analyzer-core.NullDereference --
  -x objective-c -fobjc-runtime=gnustep-2.0 -fobjc-arc -fblocks
  -Wno-everything -Werror=implicit-function-declaration
strictImplicitFrontendExit=0
```

- Implicit function declaration diagnostics: 0.
- Two calls resolve semantically to one prior file-local `static` definition.
- Repository production definition count: 1; external verifier definitions: 0.
- Semantic undefined `PXOptionalRestoreVerifyDirectoryTree` references: 0.
- `clang.exe` and `llvm-nm.exe` are not installed in this Windows workspace, so no real Objective-C object or `nm` table could be produced. `dumpbin.exe` exists but there is no compiler-produced object to inspect. Real Theos/iOS link remains pending rather than being claimed as complete.

## TASK-2.13 non-regression

| Surface | Result | Baseline/current SHA evidence |
|---|---|---|
| DirectoryObject replacement preparation call-site body | byte-identical | `282186561996d0a121ae989d68c973ec07d73b007f12dcbdb299f3688e973f35` / `282186561996d0a121ae989d68c973ec07d73b007f12dcbdb299f3688e973f35` |
| No-journal replacement proof call-site body | byte-identical | `91680048e685b6dc27694c88a6c75bd5984688957a97f17160e2491a47c6b0c2` / `91680048e685b6dc27694c88a6c75bd5984688957a97f17160e2491a47c6b0c2` |
| Journal schema and phase code | byte-identical | `e9a4330e81c1c3b99fdca10060e922574f1f6cb66ea426af8633c05e6779c240` / `e9a4330e81c1c3b99fdca10060e922574f1f6cb66ea426af8633c05e6779c240` |
| Rollback and stale recovery | byte-identical | `f5ef6a56481d4a6767d21e62279556be34c54a79b60fbc671c517da0bb1b6bf4` / `f5ef6a56481d4a6767d21e62279556be34c54a79b60fbc671c517da0bb1b6bf4` |
| Transaction factory | byte-identical | `a982a24ff7779ec6053f9461c81d054e437033c23d2aad1b8606a15ca3a73f12` / `a982a24ff7779ec6053f9461c81d054e437033c23d2aad1b8606a15ca3a73f12` |
| Commit state machine | byte-identical | `1e4e027f1fe14a7b711aaf61de2dc98d4529b8fb7aa691eba2797201cc728d38` / `1e4e027f1fe14a7b711aaf61de2dc98d4529b8fb7aa691eba2797201cc728d38` |
| Public header | diff 0 | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` |
| Manager integration and Keychain exclusion | diff 0 | `ac9f60bd2c0af6bc57e48946f3fbd7c14fae59a3afd60e289960be05147efe6d` |

Retained static contract: 3 item kinds, 18 error codes, 3 item factories, 1 transaction factory, 1 commit method, 0 public readwrite properties, 6 journal phases, 5 manager transaction domains, and 0 Keychain transaction items.

## Protected production SHA-256 before/after

Protected production files recorded: 255. Changed protected files: 0.

| File | Before SHA-256 | After SHA-256 | Match |
|---|---|---|---|
| `AppDataBackupManager.h` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | PASS |
| `AppDataBackupManager.m` | `ac9f60bd2c0af6bc57e48946f3fbd7c14fae59a3afd60e289960be05147efe6d` | `ac9f60bd2c0af6bc57e48946f3fbd7c14fae59a3afd60e289960be05147efe6d` | PASS |
| `AppDataBackupRestoreViewController.h` | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | `b470e92a732dca1c97b161f802baf1d3ea8d39706087648e7fc697b63eeba5cf` | PASS |
| `AppDataBackupRestoreViewController.m` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | `48e86f63aeeb6626858fe13fed6487ef36e128f0f0fde173120abb9108bd7a96` | PASS |
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | PASS |
| `AppDataCleaner.m` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | PASS |
| `AppEntitlementsReader.h` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | PASS |
| `AppEntitlementsReader.m` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | PASS |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | PASS |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | PASS |
| `AppVersionManager.h` | `bab65a2d67128d4dd4b2ee061214f0732d1335928a7e599d469a707e4c59ecd2` | `bab65a2d67128d4dd4b2ee061214f0732d1335928a7e599d469a707e4c59ecd2` | PASS |
| `AppVersionManager.m` | `2096f05e3c5d53947ce4dfdc08e3d9015af96441719c455f74944cd8615afd91` | `2096f05e3c5d53947ce4dfdc08e3d9015af96441719c455f74944cd8615afd91` | PASS |
| `AppVersionSpoofingViewController.h` | `011c95fb8f776d6fae961faa94d1b0ff63bc3a1d81a0b222db9d2db8f81bbb1d` | `011c95fb8f776d6fae961faa94d1b0ff63bc3a1d81a0b222db9d2db8f81bbb1d` | PASS |
| `AppVersionSpoofingViewController.m` | `04e55427fc60c91c3a87a3a780161078b1ff643728e3bf8c4bc9ad3ac0eff6ed` | `04e55427fc60c91c3a87a3a780161078b1ff643728e3bf8c4bc9ad3ac0eff6ed` | PASS |
| `BackupKeychainGroupsViewController.h` | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | `fc77d536ab2a573b598ac7ff72339a63229d68f15ae239b827cb4dd2a78c2377` | PASS |
| `BackupKeychainGroupsViewController.m` | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | `2f0590d7b51b05733f92c9df19c93953c2ab14fc8ca7380c43b4126ea60c4ccf` | PASS |
| `BottomButtons.h` | `1c31f5cf5e62bda2cd580d9c7b1b2471a1218e6d8c1c330ae081c9081c49d325` | `1c31f5cf5e62bda2cd580d9c7b1b2471a1218e6d8c1c330ae081c9081c49d325` | PASS |
| `BottomButtons.m` | `025c32bfcdc79f5c81c0ad6d93be0bc1ba02f797b56a44ed62e915c62e26536b` | `025c32bfcdc79f5c81c0ad6d93be0bc1ba02f797b56a44ed62e915c62e26536b` | PASS |
| `CommandRunner.h` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | PASS |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | PASS |
| `ContainerManager.h` | `d1c5ac27362d01b91fee79e6c963e23d52eb1b0b4ee22d9030f9c7d1495e78c1` | `d1c5ac27362d01b91fee79e6c963e23d52eb1b0b4ee22d9030f9c7d1495e78c1` | PASS |
| `ContainerManager.m` | `f49a397e9c1c9122f3cfcfbabda6932b3864f2dbd2855e702b7913c2318bece9` | `f49a397e9c1c9122f3cfcfbabda6932b3864f2dbd2855e702b7913c2318bece9` | PASS |
| `CopyHelper.h` | `d318b6795e3d11414e8e79e0d15441b46dd9e34f7ce88e42d4809635bee786d9` | `d318b6795e3d11414e8e79e0d15441b46dd9e34f7ce88e42d4809635bee786d9` | PASS |
| `CopyHelper.m` | `67ef46d464cb4a1abc839b97aaaefd6ae259a9858f0b46ac062bb396848abbc1` | `67ef46d464cb4a1abc839b97aaaefd6ae259a9858f0b46ac062bb396848abbc1` | PASS |
| `DeviceSpecificSpoofingViewController+EditLabel.h` | `1cda7513c54b5af56a8ab8faa015c529cdb723597ae22e1f6949ebff72653369` | `1cda7513c54b5af56a8ab8faa015c529cdb723597ae22e1f6949ebff72653369` | PASS |
| `DeviceSpecificSpoofingViewController+EditLabel.m` | `eb54be2f1c94b9656ebdd52e5b9bae4f9284d369bcaa223384fa490a2cbb8929` | `eb54be2f1c94b9656ebdd52e5b9bae4f9284d369bcaa223384fa490a2cbb8929` | PASS |
| `DeviceSpecificSpoofingViewController+ProfileManagerDelegate.m` | `51dfdb0f30cb3208cd8375903f986f9597b82d34e2d9c969751238e3dd4ff63c` | `51dfdb0f30cb3208cd8375903f986f9597b82d34e2d9c969751238e3dd4ff63c` | PASS |
| `DeviceSpecificSpoofingViewController.h` | `6c7d28b87e0a0dc009a4394a074aff539a1a2e5c799811b038c3e91400cb4ef4` | `6c7d28b87e0a0dc009a4394a074aff539a1a2e5c799811b038c3e91400cb4ef4` | PASS |
| `DeviceSpecificSpoofingViewController.m` | `403624616748a13ff669e885cfe646145a05dab71a612ace675180ebc41d3ef2` | `403624616748a13ff669e885cfe646145a05dab71a612ace675180ebc41d3ef2` | PASS |
| `DevicesViewController.h` | `6722488756616f27394308ea0c8e6399bc71c5200ccb3421a603682ccd8329e5` | `6722488756616f27394308ea0c8e6399bc71c5200ccb3421a603682ccd8329e5` | PASS |
| `DevicesViewController.m` | `79cf759ccae76beb2ba3cbb5a90ff3a8e7f239fee97748fd019bbd499f4a6e8a` | `79cf759ccae76beb2ba3cbb5a90ff3a8e7f239fee97748fd019bbd499f4a6e8a` | PASS |
| `DomainManagementViewController.h` | `558250c37d54ba9de744c00fa625f127cead096de1e073356837abb1f2e7aa4f` | `558250c37d54ba9de744c00fa625f127cead096de1e073356837abb1f2e7aa4f` | PASS |
| `DomainManagementViewController.m` | `304191541ce30d76ca68b4bf134fabc9db4a9df63b8bafefb90ceaf41a93d66d` | `304191541ce30d76ca68b4bf134fabc9db4a9df63b8bafefb90ceaf41a93d66d` | PASS |
| `DoorDashOrderViewController.h` | `c381a89fb9cad521fd8ccd2492a6ff9592223f631cabf82c7b0701a8d10f7eab` | `c381a89fb9cad521fd8ccd2492a6ff9592223f631cabf82c7b0701a8d10f7eab` | PASS |
| `DoorDashOrderViewController.m` | `1fa89a2df85125dba4de371c28febf138179cfc188e45894853a49a08c09d4a3` | `1fa89a2df85125dba4de371c28febf138179cfc188e45894853a49a08c09d4a3` | PASS |
| `DownloadResourcesViewController.h` | `4106923a6377598b9a40a214b99c799a69a8cb25959ffe9cc23f9b0af55b342f` | `4106923a6377598b9a40a214b99c799a69a8cb25959ffe9cc23f9b0af55b342f` | PASS |
| `DownloadResourcesViewController.m` | `c561ea7c67518b62bf2e91cdcd11c6dd1540f881e1d7887aa3ebe4bc81670deb` | `c561ea7c67518b62bf2e91cdcd11c6dd1540f881e1d7887aa3ebe4bc81670deb` | PASS |
| `FileManagerViewController.h` | `3434af2ed0adfb193198757611ca465792442b0b76dfa4d48d7e3e2b7c0abf64` | `3434af2ed0adfb193198757611ca465792442b0b76dfa4d48d7e3e2b7c0abf64` | PASS |
| `FileManagerViewController.m` | `bb2a6f965ede7581ab658d7300e0d76ce8b96ce1bc83236ae2a7dff9a5728887` | `bb2a6f965ede7581ab658d7300e0d76ce8b96ce1bc83236ae2a7dff9a5728887` | PASS |
| `FixVersionAppsViewController.h` | `d62d7097d8c958218b12354802b4af74f3ca0ae23f95056f1cae6f323adfb749` | `d62d7097d8c958218b12354802b4af74f3ca0ae23f95056f1cae6f323adfb749` | PASS |
| `FixVersionAppsViewController.m` | `c7b82233db03c7d29ae5640228ec987e80f75a1d4fe3805348c43d02e9072cf5` | `c7b82233db03c7d29ae5640228ec987e80f75a1d4fe3805348c43d02e9072cf5` | PASS |
| `FreezeManager.h` | `bdf75483157b774cca85e65c5e93bee581a8ef6be0f5f378070e04d26f43b894` | `bdf75483157b774cca85e65c5e93bee581a8ef6be0f5f378070e04d26f43b894` | PASS |
| `FreezeManager.m` | `00473a0fab8fda61235b66058152697b68a60deff46a3f8d4b209bb3574845c4` | `00473a0fab8fda61235b66058152697b68a60deff46a3f8d4b209bb3574845c4` | PASS |
| `Info.plist` | `2d017f405d32126d2102999838a77984a5c7bffc39be728ed479487cd903f477` | `2d017f405d32126d2102999838a77984a5c7bffc39be728ed479487cd903f477` | PASS |
| `KeychainGroupsViewController.h` | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | `48945d11fbf9ee4e9921140fc7d674abacbed3076db2b514fc641b6ac118a50b` | PASS |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | PASS |
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | PASS |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | PASS |
| `KeychainHelper/backup_helper.m` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | PASS |
| `Makefile` | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` | `717465ec5894548e894412aa7f4205f4b8d5ac7e9d13339327477dd686d6c9a9` | PASS |
| `MatrixRainView.h` | `8a82ddcdcb831793821158d219feafef052540c09ecead96a29d6c63fe2ca94c` | `8a82ddcdcb831793821158d219feafef052540c09ecead96a29d6c63fe2ca94c` | PASS |
| `PXAppGroupRestoreTargetPlan.h` | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | `565924464aafb15836a4506de0336f62c2eb0986f7fa7ebd1839d98c48e888d3` | PASS |
| `PXAppGroupRestoreTargetPlan.m` | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | `c03b64aa48b59ff1fb380ff8fcfb0b6aba468739921fe7b151e8d8445bc8731d` | PASS |
| `PXAppGroupRestoreTransaction.h` | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` | `cd329b3f67433214b36d195719e337cc951204c774dd65bbe379eb8936a33412` | PASS |
| `PXAppGroupRestoreTransaction.m` | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` | `842bf9676fdac4c31433f966b81b2b93c82d03225d7f046d7e464a3b402bfbd6` | PASS |
| `PXBackupArchiveValidator.h` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | `661258274d798bfd67356d472334cfffcc1da6a911278ae6e956a66e0cf4b05b` | PASS |
| `PXBackupArchiveValidator.m` | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | `01c8c628453b8f67853a84ebf9c5511c6a9af454c80bc476da1d9f685eaa306e` | PASS |
| `PXBackupArtifactVerifier.h` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | `6831f6fd7b52eda12d6407c744e8f4fe5b3fcf101567185930ce53246da9c7a0` | PASS |
| `PXBackupArtifactVerifier.m` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | `81a828d3d3365430a308ccf7e8ca655a5efa5496d97caae936ebc1fa303701f1` | PASS |
| `PXBackupManifestValidator.h` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836` | PASS |
| `PXBackupManifestValidator.m` | `0cae70bbceb8f433c9fe68b2c6ee91f98c9ac59dac0ef8e15e10d5f467f525ea` | `0cae70bbceb8f433c9fe68b2c6ee91f98c9ac59dac0ef8e15e10d5f467f525ea` | PASS |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | PASS |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | PASS |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | PASS |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | PASS |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | PASS |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | PASS |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | PASS |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | PASS |
| `PXMainDataRestoreTransaction.h` | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | `df444b03e0214d62e31c89094f7e0afe1037255ab6582928a608ec839466a575` | PASS |
| `PXMainDataRestoreTransaction.m` | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` | `894c40ab599074bc6c481a5b9084c3d557c64fb101336f0495d5297234a5f3c5` | PASS |
| `PXMainDataStaging.h` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | `2eaea45c166986c419b32074141e8e1f7ab6000f153e860b10b48e1405620554` | PASS |
| `PXMainDataStaging.m` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | `686fbbf5c382b9c2dfc4f5917b20993cca434a1976f098f20f98ddfa87769162` | PASS |
| `PXOptionalRestoreStaging.h` | `b412a77d26f4e22d17083f4faa761d0dc02c4fef8e25f5aec4c2c84be86a78e4` | `b412a77d26f4e22d17083f4faa761d0dc02c4fef8e25f5aec4c2c84be86a78e4` | PASS |
| `PXOptionalRestoreStaging.m` | `639333e3f891ee6e61cb1f486c97e54c68751439c64014c03169c37a2ea8e3f5` | `639333e3f891ee6e61cb1f486c97e54c68751439c64014c03169c37a2ea8e3f5` | PASS |
| `PXOptionalRestoreTransaction.h` | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` | `1d162e411824a708209c78325385cff75cea453a8097c93347f02cfb8bf2ad78` | PASS |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | PASS |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | PASS |
| `PXRestorePlan.h` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | `5cc773132c009fd8eedf4069b33ab53901a530edd580e3231c9d982c60cf7643` | PASS |
| `PXRestorePlan.m` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | `cb6f838638a06bc9858b392d123656590291555812c63e3d0ddd4f5529d0d141` | PASS |
| `PlistViewerViewController.h` | `84e7faeb8986573e038eb4ccd89ad69096be5bbb668c28d21701964dce1d9861` | `84e7faeb8986573e038eb4ccd89ad69096be5bbb668c28d21701964dce1d9861` | PASS |
| `PlistViewerViewController.m` | `204b5483da9c6605dd7bce780f32841f5f578a5f808cec9043dcd6158a57b5b1` | `204b5483da9c6605dd7bce780f32841f5f578a5f808cec9043dcd6158a57b5b1` | PASS |
| `ProfileButtonsView.h` | `f684b1fd6790fcf3484195c7115441c435bcfcb0a376f8a9dcec79f71a9dcc44` | `f684b1fd6790fcf3484195c7115441c435bcfcb0a376f8a9dcec79f71a9dcc44` | PASS |
| `ProfileButtonsView.m` | `d4f7db76a846f87a5bbeda0a3360244e56a6c6da77ea38607386c62d29c92d8b` | `d4f7db76a846f87a5bbeda0a3360244e56a6c6da77ea38607386c62d29c92d8b` | PASS |
| `ProfileCreationViewController.h` | `9a0607d0f92ac497b86435e5abdd3402f5f68e900893130a084f777e7b5429b6` | `9a0607d0f92ac497b86435e5abdd3402f5f68e900893130a084f777e7b5429b6` | PASS |
| `ProfileCreationViewController.m` | `3899ba590c6d4e222e7516c1fcfc0947c84a28f2439c84f92cefaaf9a61d4f60` | `3899ba590c6d4e222e7516c1fcfc0947c84a28f2439c84f92cefaaf9a61d4f60` | PASS |
| `ProfileManagerViewController.h` | `d96f5b92633c1aad6ed40a6e007aa9c00e69b4b9fe7209c0ea0502c5d5b7a2f4` | `d96f5b92633c1aad6ed40a6e007aa9c00e69b4b9fe7209c0ea0502c5d5b7a2f4` | PASS |
| `ProfileManagerViewController.m` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | `a26680aa7340f00b913950cd019245066d0854880839403346a965fbf832bb1a` | PASS |
| `ProgressHUDView.h` | `b02f257178fbb9b705ba19f49d37528126d100b968ef1bf9f91f9312c94eb8d5` | `b02f257178fbb9b705ba19f49d37528126d100b968ef1bf9f91f9312c94eb8d5` | PASS |
| `ProgressHUDView.m` | `18f60d3321c26d692e27310e8e1ef334b99a2cd8daa732234623d17006aabb98` | `18f60d3321c26d692e27310e8e1ef334b99a2cd8daa732234623d17006aabb98` | PASS |
| `ProjectX.h` | `5dcd27265018819afb50b9b4d2582563f9048c773e9ced1ce7a1833d44f8fb03` | `5dcd27265018819afb50b9b4d2582563f9048c773e9ced1ce7a1833d44f8fb03` | PASS |
| `ProjectXInstaller.h` | `9b7d06a8a0687e36187b838d9b9acd7ccc66e04d49ea97565fc924e7ea361245` | `9b7d06a8a0687e36187b838d9b9acd7ccc66e04d49ea97565fc924e7ea361245` | PASS |
| `ProjectXInstaller.m` | `5f2d464b5f7c00c4c83a849a8a2783ed54868e9ff8290a7283824309e993b41b` | `5f2d464b5f7c00c4c83a849a8a2783ed54868e9ff8290a7283824309e993b41b` | PASS |
| `ProjectXSceneDelegate.h` | `2e56a5014cde4c047575638be864e83e2560da885aa25a5ecb150f05b3525f5f` | `2e56a5014cde4c047575638be864e83e2560da885aa25a5ecb150f05b3525f5f` | PASS |
| `ProjectXSceneDelegate.m` | `dc056734ec81ff57484ef2e2ddddda9496b39d774ff743c42cfa6e88bbb0677e` | `dc056734ec81ff57484ef2e2ddddda9496b39d774ff743c42cfa6e88bbb0677e` | PASS |
| `ProjectXTweak.plist` | `9c8559c83f6fa8a4e247caf92265adbbbe65cb4d2cdadd2fa594de4700fff2f8` | `9c8559c83f6fa8a4e247caf92265adbbbe65cb4d2cdadd2fa594de4700fff2f8` | PASS |
| `ProjectXTweak/AAA_TestCtor.m` | `3226080d60eec3c92a9966f09c4adc12b58b4211329e2106a4db460333c36b70` | `3226080d60eec3c92a9966f09c4adc12b58b4211329e2106a4db460333c36b70` | PASS |
| `ProjectXTweak/AppContainerHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | PASS |
| `ProjectXTweak/AppGroupHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | PASS |
| `ProjectXTweak/AppInstallHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | PASS |
| `ProjectXTweak/AppVersionHooks.h` | `7010216dcf52c45952a5ac3be1211db49952d46f76a4ee9d98a323a4c864b96a` | `7010216dcf52c45952a5ac3be1211db49952d46f76a4ee9d98a323a4c864b96a` | PASS |
| `ProjectXTweak/AppVersionHooks.x` | `091eda3e306a0fcb5a0889d09d3af11fe491edd1d6acf5c6ca076adc069ee992` | `091eda3e306a0fcb5a0889d09d3af11fe491edd1d6acf5c6ca076adc069ee992` | PASS |
| `ProjectXTweak/BatteryHooks.x` | `cda2451306704f7be1b8e228dea3818a661869fc2951f9bb13ed17d97e04a462` | `cda2451306704f7be1b8e228dea3818a661869fc2951f9bb13ed17d97e04a462` | PASS |
| `ProjectXTweak/BootTimeHooks.x` | `1cf9ff3f8930a12ce53a809aa2c5e3dc8ce648836a882692f0bb2999214aedc9` | `1cf9ff3f8930a12ce53a809aa2c5e3dc8ce648836a882692f0bb2999214aedc9` | PASS |
| `ProjectXTweak/CanvasFingerprintHooks.x` | `8d58697627269d9329490050de59d2d22409bbaadf462e85e16fbb3fa2a160f5` | `8d58697627269d9329490050de59d2d22409bbaadf462e85e16fbb3fa2a160f5` | PASS |
| `ProjectXTweak/CoreDataHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | PASS |
| `ProjectXTweak/DeviceModelHooks.x` | `0523ea3f49d45037a14e319477efb936f22c049582600a649b79765a88618313` | `0523ea3f49d45037a14e319477efb936f22c049582600a649b79765a88618313` | PASS |
| `ProjectXTweak/DeviceSpecHooks.x` | `4cc3bf32980902c66eac012b23b5bc9f3ece2efb6606a84140b99a3827a94e27` | `4cc3bf32980902c66eac012b23b5bc9f3ece2efb6606a84140b99a3827a94e27` | PASS |
| `ProjectXTweak/DomainBlockingHooks.x` | `43130baab0454d4c0be7515b6454ba14ea1aa8327d112f15ad2d87de00999d9b` | `43130baab0454d4c0be7515b6454ba14ea1aa8327d112f15ad2d87de00999d9b` | PASS |
| `ProjectXTweak/FirebasePerfDisableScoped.x` | `a361527514d0de6fef9bb14552f7e753dccc3a1a3ce7010302d68884d85ec844` | `a361527514d0de6fef9bb14552f7e753dccc3a1a3ce7010302d68884d85ec844` | PASS |
| `ProjectXTweak/HookOwnership.h` | `7a35059699c35fd433bbc588d1cfc7e240b4447268e9ecc94a400ae3cfd4d2da` | `7a35059699c35fd433bbc588d1cfc7e240b4447268e9ecc94a400ae3cfd4d2da` | PASS |
| `ProjectXTweak/IOSVersionHooks.x` | `bc3a7d9f7fc848399d90cf1321bcf132708f71263a2c7c509d9b20304b4fb860` | `bc3a7d9f7fc848399d90cf1321bcf132708f71263a2c7c509d9b20304b4fb860` | PASS |
| `ProjectXTweak/JailbreakBypassHooks.x` | `989c720f92a03470a7bba9ce60f2a7b341f7a538a924a41a8ee47304da373494` | `989c720f92a03470a7bba9ce60f2a7b341f7a538a924a41a8ee47304da373494` | PASS |
| `ProjectXTweak/KeychainHooks.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | PASS |
| `ProjectXTweak/LocaleTimeZoneHooks.x` | `853fe8689c3e8173aba8d4e3b34e67fd5e3b99ea35f34cf6cf1eb2f376b215c8` | `853fe8689c3e8173aba8d4e3b34e67fd5e3b99ea35f34cf6cf1eb2f376b215c8` | PASS |
| `ProjectXTweak/MethodSwizzler.h` | `bf42638563a47092e76e95296d999b7bb440b2d98095957aff83a8d3c69f810e` | `bf42638563a47092e76e95296d999b7bb440b2d98095957aff83a8d3c69f810e` | PASS |
| `ProjectXTweak/MethodSwizzler.m` | `39a9324dd2fa8590f25d61b3e8f106cef5acea7d0f2784c4ab1b2f919b52e982` | `39a9324dd2fa8590f25d61b3e8f106cef5acea7d0f2784c4ab1b2f919b52e982` | PASS |
| `ProjectXTweak/MissingSpoofHooks.x` | `ed71e70219a2e4fdc42f6cf1930bee71c83c0a565741f5afdd7ec7752c0508e1` | `ed71e70219a2e4fdc42f6cf1930bee71c83c0a565741f5afdd7ec7752c0508e1` | PASS |
| `ProjectXTweak/MobileGestalt.h` | `a81ba122e63f9ebb143a65afa8227badd76cfd7b971fe7ee5e9aab77c8b6352b` | `a81ba122e63f9ebb143a65afa8227badd76cfd7b971fe7ee5e9aab77c8b6352b` | PASS |
| `ProjectXTweak/NetworkConnectionTypeHooks.x` | `445e68b2a745e17922842fb620c080d83f73dc002e460b362b2e0fdf8ae487db` | `445e68b2a745e17922842fb620c080d83f73dc002e460b362b2e0fdf8ae487db` | PASS |
| `ProjectXTweak/ObjcClassPairGuard.x` | `8d009928b014571c0aec433aac908936989e24fe848e01b38fa1b83991487ad9` | `8d009928b014571c0aec433aac908936989e24fe848e01b38fa1b83991487ad9` | PASS |
| `ProjectXTweak/PXFileDebug.h` | `0ff94999994a071b66a1482d3b97bdacc4f31002096129b661243a774dd1bcc5` | `0ff94999994a071b66a1482d3b97bdacc4f31002096129b661243a774dd1bcc5` | PASS |
| `ProjectXTweak/PXNativeHookCoordinator.h` | `248f78c9bc54e625d540e9ae8c3a7a4021e05fdac0a43830b669cb4dcfa625e4` | `248f78c9bc54e625d540e9ae8c3a7a4021e05fdac0a43830b669cb4dcfa625e4` | PASS |
| `ProjectXTweak/PXNativeHookCoordinator.m` | `2ad1f7fc4b46e59ec6e4776a4eb5d9b8331da41c1fdf4b73860eabd37d4ff27d` | `2ad1f7fc4b46e59ec6e4776a4eb5d9b8331da41c1fdf4b73860eabd37d4ff27d` | PASS |
| `ProjectXTweak/PXScope.h` | `4ebc18511d27845a0a14499406d2525cde6c32043a931857c057521222638b32` | `4ebc18511d27845a0a14499406d2525cde6c32043a931857c057521222638b32` | PASS |
| `ProjectXTweak/PXScope.m` | `46193b6d6b3443b8b879a8e8b32b4f18ee3a4072134e4965957091fa6a4ce44f` | `46193b6d6b3443b8b879a8e8b32b4f18ee3a4072134e4965957091fa6a4ce44f` | PASS |
| `ProjectXTweak/PasteboardHooks.x` | `2a158ee64def29488c10a78bebe7a66b07ad5b3a9e4ad8122599ea8e204cfe19` | `2a158ee64def29488c10a78bebe7a66b07ad5b3a9e4ad8122599ea8e204cfe19` | PASS |
| `ProjectXTweak/SpringBoardLaunchHook.x` | `04b3a6f8caffae072b0bd4c7adf1f2dc5f6ef0d8772da6fcefa570e8d3dc2d55` | `04b3a6f8caffae072b0bd4c7adf1f2dc5f6ef0d8772da6fcefa570e8d3dc2d55` | PASS |
| `ProjectXTweak/StorageHooks.x` | `315d3887f0f2aa3fc59b9b7aa5ef6b0a72e63ce248dd78097b85545f6434297a` | `315d3887f0f2aa3fc59b9b7aa5ef6b0a72e63ce248dd78097b85545f6434297a` | PASS |
| `ProjectXTweak/ThemeHooks.x` | `3c8be122460f652f2c15f5737ab3ae96c44ff1391658191659301adfcc27c4cf` | `3c8be122460f652f2c15f5737ab3ae96c44ff1391658191659301adfcc27c4cf` | PASS |
| `ProjectXTweak/Tweak.x` | `a8dfc1055e1973b7fe2b9f3320a754de63e4ea887e6ca5c836924f5af5bdf82f` | `a8dfc1055e1973b7fe2b9f3320a754de63e4ea887e6ca5c836924f5af5bdf82f` | PASS |
| `ProjectXTweak/UUIDHooks.x` | `90b86d384da2c0c8cb2593ff40eff3ff5831e3ae481034888ace50cfd3d05a7d` | `90b86d384da2c0c8cb2593ff40eff3ff5831e3ae481034888ace50cfd3d05a7d` | PASS |
| `ProjectXTweak/UberURLHooks.x` | `be5123cbfb9971807329e9d97fb881d30ac55550e68b6ba769c4da9b7f69001b` | `be5123cbfb9971807329e9d97fb881d30ac55550e68b6ba769c4da9b7f69001b` | PASS |
| `ProjectXTweak/UserDefaultsHooks.x` | `ad6076166b161d35c82cd1418fca4d72f98df87bc5e2a46812830d21edfd6154` | `ad6076166b161d35c82cd1418fca4d72f98df87bc5e2a46812830d21edfd6154` | PASS |
| `ProjectXTweak/VPNDetectionBypass.x` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | PASS |
| `ProjectXTweak/WiFiHook.x` | `045c84ad29aad9520de43d8bf9c4967132c83ecee239c30f9240807fa9f5c36b` | `045c84ad29aad9520de43d8bf9c4967132c83ecee239c30f9240807fa9f5c36b` | PASS |
| `ProjectXViewController.h` | `046a37c9ccfc33c7a46ddefd74369abfa08b8b96712093f2bffcf3e8bae8fa1c` | `046a37c9ccfc33c7a46ddefd74369abfa08b8b96712093f2bffcf3e8bae8fa1c` | PASS |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | PASS |
| `SecurityTabViewController+IPMonitorInfo.m` | `d389a7c50f1bd2fc14761d72db0c86bda7fae1d931ed9143f0a1c1ecbec57121` | `d389a7c50f1bd2fc14761d72db0c86bda7fae1d931ed9143f0a1c1ecbec57121` | PASS |
| `SecurityTabViewController.h` | `7f21e86f58fe5377f2964fba785ae65dde5e89284aca8aca334ea5322190f53d` | `7f21e86f58fe5377f2964fba785ae65dde5e89284aca8aca334ea5322190f53d` | PASS |
| `SecurityTabViewController.m` | `9a3629b4751b6c9f1dee227a66ff61a57b8cbeed7c13b4e81dc63b314f4acbaf` | `9a3629b4751b6c9f1dee227a66ff61a57b8cbeed7c13b4e81dc63b314f4acbaf` | PASS |
| `TabBarController+DeviceAlerts.h` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | PASS |
| `TabBarController+DeviceAlerts.m` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | PASS |
| `TabBarController.h` | `f71b771e6e94a716f3678744b80fef317baafd33198292fb45b16ebd022b8584` | `f71b771e6e94a716f3678744b80fef317baafd33198292fb45b16ebd022b8584` | PASS |
| `TabBarController.m` | `09f8f74232728fb8edd4c699cf612683d04aff6bc1fdfd766970e65e7829d2eb` | `09f8f74232728fb8edd4c699cf612683d04aff6bc1fdfd766970e65e7829d2eb` | PASS |
| `TestCtorTweak/Makefile` | `acce9155e79d225a6b892aa7b85bb33696bd6d22eed356cc4add4a0dac7de85c` | `acce9155e79d225a6b892aa7b85bb33696bd6d22eed356cc4add4a0dac7de85c` | PASS |
| `TestCtorTweak/TestCtorTweak.plist` | `c84e26f2c423b89c5f84cf847b9132079de48bbef72b1f7d8ebe96370796d61f` | `c84e26f2c423b89c5f84cf847b9132079de48bbef72b1f7d8ebe96370796d61f` | PASS |
| `TestCtorTweak/Tweak.x` | `17219fd435a7dce5cf70f59eca6a21c7f950f9e3f68578c0e560e7e16bb07924` | `17219fd435a7dce5cf70f59eca6a21c7f950f9e3f68578c0e560e7e16bb07924` | PASS |
| `ToolViewController.h` | `8b182a81a023731502ab0be3bef0076733a94fde71077486df8424c46ec01ba0` | `8b182a81a023731502ab0be3bef0076733a94fde71077486df8424c46ec01ba0` | PASS |
| `ToolViewController.m` | `46413d0c6777a0afa4df06ddcb8c10da30b9114b3e6a6db4e1abbaae3c191a2e` | `46413d0c6777a0afa4df06ddcb8c10da30b9114b3e6a6db4e1abbaae3c191a2e` | PASS |
| `URLMonitor.h` | `2897113b7a6e98f40c72d13ccce718c289420d38199939d43a0bd76ada7caaac` | `2897113b7a6e98f40c72d13ccce718c289420d38199939d43a0bd76ada7caaac` | PASS |
| `URLMonitor.m` | `34f764be70ac6fa679f729489550556f5bc49785086932260d03b243d875be59` | `34f764be70ac6fa679f729489550556f5bc49785086932260d03b243d875be59` | PASS |
| `UberOrderViewController.h` | `ed4f5e3011738de767e791813f2adc8a1c2fc970f115ab3c30ce3fcfab8c99e6` | `ed4f5e3011738de767e791813f2adc8a1c2fc970f115ab3c30ce3fcfab8c99e6` | PASS |
| `UberOrderViewController.m` | `5d14235cbcc59a246d82e213f8824defdebe62ba8737ca54d7a554ff69253931` | `5d14235cbcc59a246d82e213f8824defdebe62ba8737ca54d7a554ff69253931` | PASS |
| `VersionManagementViewController.h` | `5b262b3cec01fd6e030efc25672424f8a64b49d2c1ac7e3f54a32f1a959acbb2` | `5b262b3cec01fd6e030efc25672424f8a64b49d2c1ac7e3f54a32f1a959acbb2` | PASS |
| `VersionManagementViewController.m` | `68a33b786e2aea4999b07e37e4801c97e188be0b0dfc876da89e20403cff25ae` | `68a33b786e2aea4999b07e37e4801c97e188be0b0dfc876da89e20403cff25ae` | PASS |
| `WeaponXGuardian.m` | `47db55dc74fe96ec3ae731843d7cbc8e0cbd9c647103a8cb797b7281e433f10b` | `47db55dc74fe96ec3ae731843d7cbc8e0cbd9c647103a8cb797b7281e433f10b` | PASS |
| `WeaponXKeychainBridge.plist` | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | `e47d3b6c67ff941c9232d1fcf643bd94e81327cfd40244f1b5f38b99b918fe02` | PASS |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | PASS |
| `WeaponXMountDaemon/WeaponXDaemon.m` | `c9ba6d287f3743ce3aab7b76615f864d72f32404fa2d3ce85b2ebb0b3cf9dcb3` | `c9ba6d287f3743ce3aab7b76615f864d72f32404fa2d3ce85b2ebb0b3cf9dcb3` | PASS |
| `WeaponXMountDaemon/WeaponXMountDaemon.m` | `30e9e71ba449199e2140e798d6e7b3e35e2f66710dc1bed2c70933af7af04a0f` | `30e9e71ba449199e2140e798d6e7b3e35e2f66710dc1bed2c70933af7af04a0f` | PASS |
| `com.hydra.weaponx.guardian.plist` | `713d7975fdedef0abb50e3207e34a9fbaedd241ec417174ebdd59fc2a6126f68` | `713d7975fdedef0abb50e3207e34a9fbaedd241ec417174ebdd59fc2a6126f68` | PASS |
| `common/AppContainerUUIDManager.h` | `4ce1170d8f576bc9ae7da4a5a52faebf3f2a986ba66ad06561085270436ad9ac` | `4ce1170d8f576bc9ae7da4a5a52faebf3f2a986ba66ad06561085270436ad9ac` | PASS |
| `common/AppContainerUUIDManager.m` | `623df4a811358a3c897a1420c7f3fc6a72bcff1457540821a9e6db5524d05e55` | `623df4a811358a3c897a1420c7f3fc6a72bcff1457540821a9e6db5524d05e55` | PASS |
| `common/AppGroupUUIDManager.h` | `dc28577f1bc5cade1942f4d9a646690fa20cf60544983238dfe0f2fff0c914af` | `dc28577f1bc5cade1942f4d9a646690fa20cf60544983238dfe0f2fff0c914af` | PASS |
| `common/AppGroupUUIDManager.m` | `e5597aecbda830fbc8373103ca68f4674a07231370a7a94b4d1ba78b16dc9355` | `e5597aecbda830fbc8373103ca68f4674a07231370a7a94b4d1ba78b16dc9355` | PASS |
| `common/AppInstallUUIDManager.h` | `5af466057f85afaa59470dde8b576acc056f899246c207b79b91c0557c427c0c` | `5af466057f85afaa59470dde8b576acc056f899246c207b79b91c0557c427c0c` | PASS |
| `common/AppInstallUUIDManager.m` | `da9a3156ea08238c60a75c334bb328b13f81eeae876e996f22d8446cab8f66a3` | `da9a3156ea08238c60a75c334bb328b13f81eeae876e996f22d8446cab8f66a3` | PASS |
| `common/BatteryManager.h` | `24eb8739f4d31c5b70d49393a14e3633cf56c1c5babb99bdab108fa5cb0a6430` | `24eb8739f4d31c5b70d49393a14e3633cf56c1c5babb99bdab108fa5cb0a6430` | PASS |
| `common/BatteryManager.m` | `77b12c45676efe1ce826a282ebe8bc5949ee5349d7405bf719ff6decebce5d26` | `77b12c45676efe1ce826a282ebe8bc5949ee5349d7405bf719ff6decebce5d26` | PASS |
| `common/CarrierDB.h` | `b6696746582b7e687e4fe9ac3eb7dc20e3fdac74574b7e0834d6d08180ce4e32` | `b6696746582b7e687e4fe9ac3eb7dc20e3fdac74574b7e0834d6d08180ce4e32` | PASS |
| `common/CarrierDB.m` | `a4ec03f2cceba3675db17b20024e867b8ffae39c55bba1b9591774c7f56b168e` | `a4ec03f2cceba3675db17b20024e867b8ffae39c55bba1b9591774c7f56b168e` | PASS |
| `common/CoreDataUUIDManager.h` | `892e127ae63e1f47374dfb112f85932ae02ddc1ded28ec15f0e109bd7554fd1d` | `892e127ae63e1f47374dfb112f85932ae02ddc1ded28ec15f0e109bd7554fd1d` | PASS |
| `common/CoreDataUUIDManager.m` | `21f09a12da71e74b703bced4c7a9c4ef8fed1a2046824c8200510ee677045c85` | `21f09a12da71e74b703bced4c7a9c4ef8fed1a2046824c8200510ee677045c85` | PASS |
| `common/DBDebugLogger.h` | `d3a600284f4f0bb5969eb39576b05432263e138fa1f0ab47ea393ee2d02fd714` | `d3a600284f4f0bb5969eb39576b05432263e138fa1f0ab47ea393ee2d02fd714` | PASS |
| `common/DBDebugLogger.m` | `c10cb0af16fe8e67187b6f9de6697a1e0f949dd6af03d8e69774eed946e92f42` | `c10cb0af16fe8e67187b6f9de6697a1e0f949dd6af03d8e69774eed946e92f42` | PASS |
| `common/DeviceModelManager.h` | `fa94aa68e6de07ee7c7697fbfc88f30e929377a35b5083cf106af386a6a67865` | `fa94aa68e6de07ee7c7697fbfc88f30e929377a35b5083cf106af386a6a67865` | PASS |
| `common/DeviceModelManager.m` | `2837317f930529299573cb37bd225a131f0cde10c01463c14631024dd3ffd5ab` | `2837317f930529299573cb37bd225a131f0cde10c01463c14631024dd3ffd5ab` | PASS |
| `common/DeviceNameManager.h` | `0383dab0d4f5890e5f157abbdaf3c1a97b43373716768e1eb6699a80602c838c` | `0383dab0d4f5890e5f157abbdaf3c1a97b43373716768e1eb6699a80602c838c` | PASS |
| `common/DeviceNameManager.m` | `ce19316a6f3ee82166ce1d7867213bd108d1d5d1406b8ecd9fb0fe3ec4cba029` | `ce19316a6f3ee82166ce1d7867213bd108d1d5d1406b8ecd9fb0fe3ec4cba029` | PASS |
| `common/DomainBlockingSettings.h` | `2892eb655c23d45ea40c8ee5e11815e941af7552b54cb573ad6953bfb01e1823` | `2892eb655c23d45ea40c8ee5e11815e941af7552b54cb573ad6953bfb01e1823` | PASS |
| `common/DomainBlockingSettings.m` | `b1e043159a2841c65795d3074cda14194b3b4a83a3fb5cd3652725b65abd132a` | `b1e043159a2841c65795d3074cda14194b3b4a83a3fb5cd3652725b65abd132a` | PASS |
| `common/DyldCacheUUIDManager.h` | `984684afea3a133454c4518855930d546e5caea4fefacaf5b3eedfc78f062025` | `984684afea3a133454c4518855930d546e5caea4fefacaf5b3eedfc78f062025` | PASS |
| `common/DyldCacheUUIDManager.m` | `54f3a2087ef4f2f1d4116682733b19eb753f1e2ed1b0fbb8e75b8cb4cb208562` | `54f3a2087ef4f2f1d4116682733b19eb753f1e2ed1b0fbb8e75b8cb4cb208562` | PASS |
| `common/IDFAManager.h` | `1dfa1d1f301419031727e3b1ec35dbb8cfb6ca1286e683663df6efe7bfcff1a1` | `1dfa1d1f301419031727e3b1ec35dbb8cfb6ca1286e683663df6efe7bfcff1a1` | PASS |
| `common/IDFAManager.m` | `7c0f5d758c886bc5bc38f9a800063c5bd223eeb745a823ac4a514a215c2c9a41` | `7c0f5d758c886bc5bc38f9a800063c5bd223eeb745a823ac4a514a215c2c9a41` | PASS |
| `common/IDFVManager.h` | `0b4f9c2198d5ab9fe2b4935561f051efb120d7ba65d784fdafab42ef51751b29` | `0b4f9c2198d5ab9fe2b4935561f051efb120d7ba65d784fdafab42ef51751b29` | PASS |
| `common/IDFVManager.m` | `a1504d870759b9dcbeb2d3a65a4e3e2befe79b2af684702894c217bc34e0f7f6` | `a1504d870759b9dcbeb2d3a65a4e3e2befe79b2af684702894c217bc34e0f7f6` | PASS |
| `common/IOSBuildDB.h` | `a5c31abe50dce78944fbb8229122d86c21445bd5b96cbab4ca5a9a9ff6160654` | `a5c31abe50dce78944fbb8229122d86c21445bd5b96cbab4ca5a9a9ff6160654` | PASS |
| `common/IOSBuildDB.m` | `234aff3926a0b702f4d47d7b3df8b565d2f304c8035abb127a8c1480bba704e4` | `234aff3926a0b702f4d47d7b3df8b565d2f304c8035abb127a8c1480bba704e4` | PASS |
| `common/IOSVersionInfo.h` | `6e34a51759ad38bd05669b69932a1119ca84cf284203ca3deefb2e0b1664d02a` | `6e34a51759ad38bd05669b69932a1119ca84cf284203ca3deefb2e0b1664d02a` | PASS |
| `common/IOSVersionInfo.m` | `d476ed2ca27e6d08721409a33695d6b42089b221dd778e929fe8c024198409c7` | `d476ed2ca27e6d08721409a33695d6b42089b221dd778e929fe8c024198409c7` | PASS |
| `common/IPMonitorService.h` | `202a42c2804fa7d48c40c9ba44cc88bb7a45f584261c5afb51ff2b643a6b3317` | `202a42c2804fa7d48c40c9ba44cc88bb7a45f584261c5afb51ff2b643a6b3317` | PASS |
| `common/IPMonitorService.m` | `ded7e466921b9d4269488e5413ab2990622275259eb5c4954928ff09dcd83110` | `ded7e466921b9d4269488e5413ab2990622275259eb5c4954928ff09dcd83110` | PASS |
| `common/IPStatusCacheManager.h` | `494c8e1e4aaeb1a4462fec95e56ed88249d72ea6f79fd5fffc501be83e39c887` | `494c8e1e4aaeb1a4462fec95e56ed88249d72ea6f79fd5fffc501be83e39c887` | PASS |
| `common/IPStatusCacheManager.m` | `0136ffd0b9c62a1f30f5f11543650b45f110bdd3a0eabb5bd084b70bf92acc39` | `0136ffd0b9c62a1f30f5f11543650b45f110bdd3a0eabb5bd084b70bf92acc39` | PASS |
| `common/IPStatusViewController.h` | `24d983dca6be3c22410fbf51311a81a7a74027bfdd3e257d4c0b0b2eaa83eb73` | `24d983dca6be3c22410fbf51311a81a7a74027bfdd3e257d4c0b0b2eaa83eb73` | PASS |
| `common/IPStatusViewController.m` | `dd37fc4c0835422d88388dac46c02613eaad7d28cc3f20c3d0c63fb8221faa01` | `dd37fc4c0835422d88388dac46c02613eaad7d28cc3f20c3d0c63fb8221faa01` | PASS |
| `common/IPhoneModelDB.h` | `93244605e5ea9088a44447686a27a22a39d132021b74b044212ef00e4633c449` | `93244605e5ea9088a44447686a27a22a39d132021b74b044212ef00e4633c449` | PASS |
| `common/IPhoneModelDB.m` | `e6a75c47d3aa47655cd0546237570b49f511c1d1c991f0fc850e65eae15cfd13` | `e6a75c47d3aa47655cd0546237570b49f511c1d1c991f0fc850e65eae15cfd13` | PASS |
| `common/IdentifierManager.h` | `3c2c6c4a8c9ff7a39210229ee7c1d8f59e6bb2f6ac0358ea70fbd9e413f073da` | `3c2c6c4a8c9ff7a39210229ee7c1d8f59e6bb2f6ac0358ea70fbd9e413f073da` | PASS |
| `common/IdentifierManager.m` | `f5fc51f24a50ce5457034326de4b5a5e64592d4dd2427b118e75137fe32fe48f` | `f5fc51f24a50ce5457034326de4b5a5e64592d4dd2427b118e75137fe32fe48f` | PASS |
| `common/KeychainUUIDManager.h` | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | `e1354e95536dc3218b3afbc3f198aad582285b0037717ca0fb5515048d8eb626` | PASS |
| `common/KeychainUUIDManager.m` | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | `954bc45263985727851347397300ea31ff908e0464a5cf4efdf29a93df633e02` | PASS |
| `common/LocationSpoofingManager.h` | `fcdcc9cbd2ef2edecd9461b0df81376468fd525cf4d2bf361a931d556cb8ffa3` | `fcdcc9cbd2ef2edecd9461b0df81376468fd525cf4d2bf361a931d556cb8ffa3` | PASS |
| `common/LocationSpoofingManager.m` | `12d2d700334d36bb49abd5231155c85f49e42db1ea9abfc374750f06d3760581` | `12d2d700334d36bb49abd5231155c85f49e42db1ea9abfc374750f06d3760581` | PASS |
| `common/NetworkManager.h` | `2f05d075712b6ab037e94d10fe885a4fb2277cbf97ed8e56ae2831398c37cdea` | `2f05d075712b6ab037e94d10fe885a4fb2277cbf97ed8e56ae2831398c37cdea` | PASS |
| `common/NetworkManager.m` | `d991dc30a5a172f0ac5497a95ee8407f7fc4062b96582415abf7b71cacad7af8` | `d991dc30a5a172f0ac5497a95ee8407f7fc4062b96582415abf7b71cacad7af8` | PASS |
| `common/PXPaths.h` | `106bdf4dd1a58c34af7edb804515d7751807897834fdd798d99cd4ec2f853f9d` | `106bdf4dd1a58c34af7edb804515d7751807897834fdd798d99cd4ec2f853f9d` | PASS |
| `common/PXPaths.m` | `3577ba31ef5e8c8282657b06b198606b54ccebbdcf30075a2b1ec4703d810de9` | `3577ba31ef5e8c8282657b06b198606b54ccebbdcf30075a2b1ec4703d810de9` | PASS |
| `common/PXProcessKiller.h` | `a5c0f8a9f821c5841d68495c911db230dc1225bb79468498df1a0fe9f1a405e2` | `a5c0f8a9f821c5841d68495c911db230dc1225bb79468498df1a0fe9f1a405e2` | PASS |
| `common/PXProcessKiller.m` | `e2a1281cbd11b2a67783136fe68c73d802e96458367a7b3e95f95995bafb72b6` | `e2a1281cbd11b2a67783136fe68c73d802e96458367a7b3e95f95995bafb72b6` | PASS |
| `common/PassThroughWindow.h` | `aea14d36dea1c40ccf7d369cf5354f56e43bc99076839ac7e7d5792d71d16d11` | `aea14d36dea1c40ccf7d369cf5354f56e43bc99076839ac7e7d5792d71d16d11` | PASS |
| `common/PassThroughWindow.m` | `c23d77e605a331ae040b236faa01d6819fd28f22e01bbe1532fc2f762f537c9c` | `c23d77e605a331ae040b236faa01d6819fd28f22e01bbe1532fc2f762f537c9c` | PASS |
| `common/PasteboardUUIDManager.h` | `5af2e4a7a7584f794c98e46848848b06caac05ce889d92eb39a9a7aeaa64c5af` | `5af2e4a7a7584f794c98e46848848b06caac05ce889d92eb39a9a7aeaa64c5af` | PASS |
| `common/PasteboardUUIDManager.m` | `9be2bf8148188a4f0c063c0691f9f1a1c8139e7fea26e88539ababcf06718078` | `9be2bf8148188a4f0c063c0691f9f1a1c8139e7fea26e88539ababcf06718078` | PASS |
| `common/ProfileIndicatorView.h` | `a4d214bd120b31126f0216cd032b4022fa58152393421e6006d32ee903567f7f` | `a4d214bd120b31126f0216cd032b4022fa58152393421e6006d32ee903567f7f` | PASS |
| `common/ProfileIndicatorView.m` | `278783df004305078ff12a2bb747ce544b57b4be5f8bc410139cb739e854c1e0` | `278783df004305078ff12a2bb747ce544b57b4be5f8bc410139cb739e854c1e0` | PASS |
| `common/ProfileManager.h` | `f17f634cae35967d04216783a87b386d537fd038d4ee8945982a527a768581e8` | `f17f634cae35967d04216783a87b386d537fd038d4ee8945982a527a768581e8` | PASS |
| `common/ProfileManager.m` | `cb9c6d7beb8bf935cd987f24fb465d90a8a0e61c3905de99ca4a48ba566a4178` | `cb9c6d7beb8bf935cd987f24fb465d90a8a0e61c3905de99ca4a48ba566a4178` | PASS |
| `common/ProjectXLogging.h` | `ddcc64ac4ab1dcf7130f3b3068e38ac83cbfa7119ed2696fc9c22ac49925676d` | `ddcc64ac4ab1dcf7130f3b3068e38ac83cbfa7119ed2696fc9c22ac49925676d` | PASS |
| `common/ProjectXLogging.m` | `447ddd5d9cef8a552bd56ba6e2f3589b70e7185ae4168aaf424a69dd85cecdff` | `447ddd5d9cef8a552bd56ba6e2f3589b70e7185ae4168aaf424a69dd85cecdff` | PASS |
| `common/ScoreMeterView.h` | `0e9fc5d62252750ce6432032d275c920321b8314eb1aa95d8e036ace220ac1b4` | `0e9fc5d62252750ce6432032d275c920321b8314eb1aa95d8e036ace220ac1b4` | PASS |
| `common/ScoreMeterView.m` | `415d41c0765f93d2f33b50912d746f3efd684b66b625d6d9b9a7f59d9a8272a3` | `415d41c0765f93d2f33b50912d746f3efd684b66b625d6d9b9a7f59d9a8272a3` | PASS |
| `common/SerialNumberManager.h` | `e93ad6cbfe58c9edb2d44b5c620f4f03d84b71886de47a2933139f3334f07a49` | `e93ad6cbfe58c9edb2d44b5c620f4f03d84b71886de47a2933139f3334f07a49` | PASS |
| `common/SerialNumberManager.m` | `6bc5049f5a7bda8023f2d1ba743f703c964dba99a49da9969c0484a0fe38389b` | `6bc5049f5a7bda8023f2d1ba743f703c964dba99a49da9969c0484a0fe38389b` | PASS |
| `common/StorageManager.h` | `3dac3c91e1340ecd4a03f193a1efc5484da0cfee028b8f0c7eec01146c1c3659` | `3dac3c91e1340ecd4a03f193a1efc5484da0cfee028b8f0c7eec01146c1c3659` | PASS |
| `common/StorageManager.m` | `e1c43bdcc633d5d15c3d9680f65ffa234a14158ca462ed66f6a1cb62eb096c8c` | `e1c43bdcc633d5d15c3d9680f65ffa234a14158ca462ed66f6a1cb62eb096c8c` | PASS |
| `common/SystemUUIDManager.h` | `f4e4413cb563255a9b4fd9a49ea827662da0a698925e5d5e921849ba52f3f646` | `f4e4413cb563255a9b4fd9a49ea827662da0a698925e5d5e921849ba52f3f646` | PASS |
| `common/SystemUUIDManager.m` | `bcf62bc2190c5236cf9fbbf4a6768f922c4ff2a760fdf6c7c02bb815088aee80` | `bcf62bc2190c5236cf9fbbf4a6768f922c4ff2a760fdf6c7c02bb815088aee80` | PASS |
| `common/UIButton+SafeConfiguration.h` | `6591286ab29bfc5cc33ae44cbed0d0afc8b0117e65673c49599d83a945679172` | `6591286ab29bfc5cc33ae44cbed0d0afc8b0117e65673c49599d83a945679172` | PASS |
| `common/UIButton+SafeConfiguration.m` | `0d85824389132f835505bd23dedcfe0730f9477ed79bc4e51e1f0937cf90e755` | `0d85824389132f835505bd23dedcfe0730f9477ed79bc4e51e1f0937cf90e755` | PASS |
| `common/UIButtonCompat.h` | `beb3a675c2731563de824d09ca899392c91bb776e6861ae986f497189b41cefe` | `beb3a675c2731563de824d09ca899392c91bb776e6861ae986f497189b41cefe` | PASS |
| `common/UIButtonCompat.m` | `3077e591bde05e4a7bf8a126b7e946533ffd0d7f56a6e10175f562c6ab8efd68` | `3077e591bde05e4a7bf8a126b7e946533ffd0d7f56a6e10175f562c6ab8efd68` | PASS |
| `common/UptimeManager.h` | `2bc2b60a4d351134bfea13c4d0a9c80d0da2ef01fa0c8b69226a67a5fcdefa60` | `2bc2b60a4d351134bfea13c4d0a9c80d0da2ef01fa0c8b69226a67a5fcdefa60` | PASS |
| `common/UptimeManager.m` | `1772f1d6c6a4ac8fe67690744be083f90806fa5a53e3fd327b555cafbd429320` | `1772f1d6c6a4ac8fe67690744be083f90806fa5a53e3fd327b555cafbd429320` | PASS |
| `common/UserDefaultsUUIDManager.h` | `3636875e5fbf661308ac2c2ee306a1cc615589f37c9e76dfb9f73a207d603806` | `3636875e5fbf661308ac2c2ee306a1cc615589f37c9e76dfb9f73a207d603806` | PASS |
| `common/UserDefaultsUUIDManager.m` | `be8ebdb9af1980e8c6a2ad79f31610dc44fdfe6d7395682efad1f0bb33e12f48` | `be8ebdb9af1980e8c6a2ad79f31610dc44fdfe6d7395682efad1f0bb33e12f48` | PASS |
| `common/VersionCompare.h` | `d839282397f82831f9ea163f40f131744021348508f8b51fcfee588613739094` | `d839282397f82831f9ea163f40f131744021348508f8b51fcfee588613739094` | PASS |
| `common/VersionCompare.m` | `ea72d0f06cbd476ed49c0f13f44bb985f1ca8c2bb3d8d16c82e5c292f8df23a4` | `ea72d0f06cbd476ed49c0f13f44bb985f1ca8c2bb3d8d16c82e5c292f8df23a4` | PASS |
| `common/WiFiManager.h` | `dcadd6fea432ad255f5a509253d9f6ebb353ab714dd1adc6e20e327b6015fbdc` | `dcadd6fea432ad255f5a509253d9f6ebb353ab714dd1adc6e20e327b6015fbdc` | PASS |
| `common/WiFiManager.m` | `dfc32e8d70c23b0dd95de81c35697e0e1816d3358b4e77228b85430d2a4b98e3` | `dfc32e8d70c23b0dd95de81c35697e0e1816d3358b4e77228b85430d2a4b98e3` | PASS |
| `ent.plist` | `ad383179c6f8a88b875aa34ae8a1fb85496ad002512210272a85cc81145c0164` | `ad383179c6f8a88b875aa34ae8a1fb85496ad002512210272a85cc81145c0164` | PASS |
| `iOSVersionManager.h` | `91b56e6517f142f5bff9560bf0ad9c111d6a150bafbe57756b9c05e41878948c` | `91b56e6517f142f5bff9560bf0ad9c111d6a150bafbe57756b9c05e41878948c` | PASS |
| `include/ellekit/ellekit.h` | `e3b645ef988671709a238480808415ca7601c63b8dcc947a3619fbdbdc593c13` | `e3b645ef988671709a238480808415ca7601c63b8dcc947a3619fbdbdc593c13` | PASS |
| `include/substrate.h` | `d51adfd695c82181b0145db7129dc320ea45a2e1ce19028a0b16fd9b1d3563d7` | `d51adfd695c82181b0145db7129dc320ea45a2e1ce19028a0b16fd9b1d3563d7` | PASS |
| `keychain_base_ent.plist` | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | `8661cc558cb294239068ce2c24958dc2e717e80998c4f342ad1a9c463fb45496` | PASS |
| `layout/Library/libSandy/projectx_filesystem_access.plist` | `6d8f04e9463c9fa8cf096ba4bf25dd312a0bec29cb605d9a93c48e8f29837a49` | `6d8f04e9463c9fa8cf096ba4bf25dd312a0bec29cb605d9a93c48e8f29837a49` | PASS |
| `main.m` | `7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da` | `7723b95eef99fdc9b8e949daf135cb03e7c8eaad1c000b4db9361eccbfc0f0da` | PASS |
| `scripts/audit_native_hooks.sh` | `9216ef3fcab69bb66f50d7d4b70296719d615a778005dd24aa6babf7d8d95a99` | `9216ef3fcab69bb66f50d7d4b70296719d615a778005dd24aa6babf7d8d95a99` | PASS |
| `scripts/keychain_backup.sh` | `b3f05517ab230b9f37acfefe4c81568e3f88268c5e110653a50b3d30bd9437ae` | `b3f05517ab230b9f37acfefe4c81568e3f88268c5e110653a50b3d30bd9437ae` | PASS |
| `scripts/setup_altlist.sh` | `9921781055e69f08bc6cce043c64f3e59eeabb65fff6e240f4efb12e95aeab7a` | `9921781055e69f08bc6cce043c64f3e59eeabb65fff6e240f4efb12e95aeab7a` | PASS |
| `setup_app.sh` | `dbbf9afa6efc1be0ad11b2bf3f61d466f827d58ff9e59bb9872cf1897ae7791e` | `dbbf9afa6efc1be0ad11b2bf3f61d466f827d58ff9e59bb9872cf1897ae7791e` | PASS |
| `setup_dependencies.sh` | `12fe51bafa3c13ddc8b53d82c8fc0384be6eee43bc34871bac1722bcdf2a9b4b` | `12fe51bafa3c13ddc8b53d82c8fc0384be6eee43bc34871bac1722bcdf2a9b4b` | PASS |
| `weaponx-debug.sh` | `720dfc3a974712d614c30938a0b40e8fb783eedd96aade3bf6f2fa178ceff024` | `720dfc3a974712d614c30938a0b40e8fb783eedd96aade3bf6f2fa178ceff024` | PASS |

## Static gate table

| Gate | Observed | Result |
|---|---:|---|
| Authorized production diff | PXOptionalRestoreTransaction.m only | PASS |
| Public header diff | 0 | PASS |
| Manager diff | 0 | PASS |
| Item kinds | 3 | PASS |
| Error codes | 18 | PASS |
| Item factories | 3 | PASS |
| Transaction factory | 1 | PASS |
| Commit method | 1 | PASS |
| Public readwrite properties | 0 | PASS |
| Verifier call sites | 2 | PASS |
| Static verifier definitions | 1 | PASS |
| Repository production definitions | 1 | PASS |
| NUL-inclusive domain prefix | present | PASS |
| D/F entry types | present | PASS |
| Big-endian uint32/uint64 helpers | present | PASS |
| Strict UTF-8 round trip | present | PASS |
| Metadata rejection | present | PASS |
| Reserved prefix rejection | present | PASS |
| No-follow stat/open | present | PASS |
| Hard-link rejection | present | PASS |
| Same-device rejection | present | PASS |
| Setuid/setgid rejection | present | PASS |
| Depth/path/component/entry bounds | 2048/4096/255/500000 | PASS |
| Exact five-field comparison | present | PASS |
| Whole-file NSData reads | 0 | PASS |
| Path-based recursion | 0 | PASS |
| Shell/process use | 0 | PASS |
| Strict implicit-declaration frontend | exit 0 | PASS |
| Semantic undefined verifier references | 0 | PASS |
| Protected production hash changes | 0 | PASS |

## Explicit scenario matrix

Explicit scenarios: 157

| # | Scenario | Expected result | Proof focus |
|---:|---|---|---|
| 1 | Empty tree with exact zero counts/bytes and prefix-only digest | PASS | Digest finalizes from NUL-inclusive domain prefix and five fields equal zero. |
| 2 | One empty directory | PASS | Directory header D, size zero, directoryCount increments. |
| 3 | One empty regular file | PASS | File header F, size zero, zero content bytes. |
| 4 | One non-empty regular file | PASS | Bounded streaming appends exact raw contents. |
| 5 | Nested directory then child file | PASS | Iterative depth-first pre-order. |
| 6 | Sibling names a then b | PASS | Raw-byte ascending order. |
| 7 | Filesystem enumeration returns b then a | PASS | Enumeration order is discarded; raw sort is authoritative. |
| 8 | Case-sensitive bytes A and a | PASS | No case folding. |
| 9 | Canonically equivalent Unicode byte sequences | PASS when each is valid and expected digest matches | No Unicode normalization. |
| 10 | Valid non-ASCII UTF-8 component | PASS | Strict decode and byte-for-byte round trip. |
| 11 | Invalid UTF-8 component | FAIL ReplacementMismatch | Strict decode fails. |
| 12 | Lossy UTF-8 round trip | FAIL ReplacementMismatch | Round-trip bytes must match exactly. |
| 13 | Empty component | FAIL EntryLimitExceeded/ReplacementMismatch | Component cannot be empty. |
| 14 | Component containing NUL | FAIL ReplacementMismatch | NUL is rejected. |
| 15 | Component containing slash | FAIL ReplacementMismatch | Slash is rejected. |
| 16 | Dot component | FAIL ReplacementMismatch | Dot is rejected. |
| 17 | Dot-dot component | FAIL ReplacementMismatch | Dot-dot is rejected. |
| 18 | Control-byte component | FAIL ReplacementMismatch | Matches TASK-2.8 path policy. |
| 19 | Backslash component | FAIL ReplacementMismatch | Matches TASK-2.8 path policy. |
| 20 | 255-byte component | PASS if valid UTF-8 and snapshot matches | Boundary accepted. |
| 21 | 256-byte component | FAIL EntryLimitExceeded | Component limit enforced. |
| 22 | 4096-byte relative path | PASS if valid and snapshot matches | Boundary accepted. |
| 23 | 4097-byte relative path | FAIL EntryLimitExceeded | Full path limit enforced. |
| 24 | Depth 2048 | PASS if path and entry limits also pass | Iterative boundary accepted. |
| 25 | Depth 2049 | FAIL EntryLimitExceeded | Depth limit enforced. |
| 26 | Exactly 500000 entries | PASS if resources and snapshot match | Entry boundary accepted. |
| 27 | 500001 entries | FAIL EntryLimitExceeded | Aggregate bound enforced. |
| 28 | Expected entryCount 500001 | FAIL InvalidInput | Accepted snapshot input is invalid. |
| 29 | Expected regularFileCount greater than entryCount | FAIL InvalidInput | Count contract rejected. |
| 30 | Expected directoryCount greater than entryCount | FAIL InvalidInput | Count contract rejected. |
| 31 | Expected regular+directory count overflow | FAIL InvalidInput | Overflow-safe addition. |
| 32 | Expected regular+directory count not equal entryCount | FAIL InvalidInput | Internal snapshot inconsistency. |
| 33 | Expected digest shorter than 64 lowercase hex | FAIL InvalidInput | Digest shape rejected. |
| 34 | Expected digest contains uppercase hex | FAIL InvalidInput | Lowercase-only contract. |
| 35 | Expected digest contains non-hex | FAIL InvalidInput | Hex contract rejected. |
| 36 | Negative root descriptor | FAIL InvalidInput | Descriptor input rejected. |
| 37 | Nil expected stage | FAIL InvalidInput | Runtime class proof rejected. |
| 38 | Wrong expected stage runtime class | FAIL InvalidInput | Runtime class proof rejected. |
| 39 | Caller root descriptor is regular file | FAIL ReplacementMismatch | Root must be a directory. |
| 40 | Caller root descriptor has setuid | FAIL ReplacementMismatch | Root security bits rejected. |
| 41 | Caller root descriptor has setgid | FAIL ReplacementMismatch | Root security bits rejected. |
| 42 | Root fstat fails | FAIL FilesystemInspectionFailed | Inspection failure category. |
| 43 | Root descriptor duplicate fails | FAIL FilesystemInspectionFailed | Caller descriptor remains owned by caller. |
| 44 | Root duplicate lacks CLOEXEC and cannot be fixed | FAIL FilesystemInspectionFailed | Owned descriptor safety proof. |
| 45 | Root identity changes between caller fstat and duplicate fstat | FAIL FilesystemChanged | Root replacement race detected. |
| 46 | Root mtime changes during traversal | FAIL FilesystemChanged | Stable directory proof. |
| 47 | Root ctime changes during traversal | FAIL FilesystemChanged | Stable directory proof. |
| 48 | Root mode changes during traversal | FAIL FilesystemChanged | Stable directory mode proof. |
| 49 | Child directory fstatat fails | FAIL FilesystemInspectionFailed | Descriptor-relative inspection failure. |
| 50 | Child directory openat fails | FAIL FilesystemInspectionFailed | No path fallback. |
| 51 | Child directory namespace inode differs from opened inode | FAIL FilesystemChanged | Namespace/descriptor binding. |
| 52 | Child directory namespace device differs from opened device | FAIL FilesystemChanged | Namespace/descriptor binding. |
| 53 | Child directory crosses root device | FAIL ReplacementMismatch | Mount crossing rejected. |
| 54 | Child directory has setuid | FAIL ReplacementMismatch | Unsafe mode rejected. |
| 55 | Child directory has setgid | FAIL ReplacementMismatch | Unsafe mode rejected. |
| 56 | Child directory mtime changes during enumeration | FAIL FilesystemChanged | Frame creation stability proof. |
| 57 | Child directory ctime changes during enumeration | FAIL FilesystemChanged | Frame creation stability proof. |
| 58 | Child directory changes before frame pop | FAIL FilesystemChanged | Final per-frame fstat proof. |
| 59 | Child directory close fails | FAIL FilesystemInspectionFailed | Owned descriptor close success required. |
| 60 | Regular file fstatat fails | FAIL FilesystemInspectionFailed | Inspection failure category. |
| 61 | Regular file openat fails | FAIL FilesystemInspectionFailed | No-follow descriptor-relative open. |
| 62 | Regular file is symlink | FAIL ReplacementMismatch | No-follow namespace type rejected. |
| 63 | Regular file has link count two | FAIL ReplacementMismatch | Hard links rejected. |
| 64 | FIFO entry | FAIL ReplacementMismatch | Unsupported type. |
| 65 | Socket entry | FAIL ReplacementMismatch | Unsupported type. |
| 66 | Character device entry | FAIL ReplacementMismatch | Unsupported type. |
| 67 | Block device entry | FAIL ReplacementMismatch | Unsupported type. |
| 68 | Unknown file type | FAIL ReplacementMismatch | Allow-list is directory/regular only. |
| 69 | Regular file crosses root device | FAIL ReplacementMismatch | Mount/device crossing rejected. |
| 70 | Regular file has setuid | FAIL ReplacementMismatch | Unsafe mode rejected. |
| 71 | Regular file has setgid | FAIL ReplacementMismatch | Unsafe mode rejected. |
| 72 | Regular file has negative size | FAIL ReplacementMismatch | Invalid size rejected. |
| 73 | Namespace file inode differs from opened inode | FAIL FilesystemChanged | Namespace/descriptor binding. |
| 74 | Namespace file type differs from opened descriptor | FAIL FilesystemChanged | Replacement race detected. |
| 75 | File read returns EINTR once then data | PASS | Read retries only EINTR. |
| 76 | File read returns non-EINTR error | FAIL FilesystemInspectionFailed | Read failure category. |
| 77 | File grows while reading | FAIL FilesystemChanged | Streamed bytes exceed retained size or final stat differs. |
| 78 | File truncates while reading | FAIL FilesystemChanged | Streamed bytes differ from retained size. |
| 79 | File inode replacement while reading | FAIL FilesystemChanged | Before/after identity differs. |
| 80 | File mode changes while reading | FAIL FilesystemChanged | Stable mode check. |
| 81 | File link count changes while reading | FAIL FilesystemChanged | Stable link-count check. |
| 82 | File mtime changes while reading | FAIL FilesystemChanged | Stable mtime check. |
| 83 | File ctime changes while reading | FAIL FilesystemChanged | Stable ctime check. |
| 84 | File close fails | FAIL FilesystemInspectionFailed | Close success required. |
| 85 | Regular byte accumulator overflow | FAIL EntryLimitExceeded | Overflow-safe total. |
| 86 | Per-file streamed byte counter overflow | FAIL EntryLimitExceeded | Overflow-safe stream count. |
| 87 | Root-level mobile container metadata file | FAIL ReplacementMismatch | Forbidden exact raw name. |
| 88 | Root-level containermanagerd metadata file | FAIL ReplacementMismatch | Forbidden exact raw name. |
| 89 | Nested mobile container metadata name | PASS only if accepted snapshot matches | Metadata ban is root-level exact per contract. |
| 90 | Root-level .weaponx-optional-restore-* entry | FAIL ReplacementMismatch | Reserved prefix rejected. |
| 91 | Nested .weaponx-optional-restore-* entry | FAIL ReplacementMismatch | Reserved prefix rejected at every depth. |
| 92 | Name merely contains reserved prefix later | PASS if otherwise valid | Only begins-with is forbidden. |
| 93 | Entry count mismatch with matching digest | FAIL ReplacementMismatch | Five-field comparison is mandatory. |
| 94 | Regular-file count mismatch with matching digest | FAIL ReplacementMismatch | Five-field comparison is mandatory. |
| 95 | Directory count mismatch with matching digest | FAIL ReplacementMismatch | Five-field comparison is mandatory. |
| 96 | Regular-file byte mismatch with matching digest | FAIL ReplacementMismatch | Five-field comparison is mandatory. |
| 97 | Digest mismatch with matching counts/bytes | FAIL ReplacementMismatch | Five-field comparison is mandatory. |
| 98 | Directory mode differs from accepted digest input | FAIL ReplacementMismatch | Mode is hashed. |
| 99 | File mode differs from accepted digest input | FAIL ReplacementMismatch | Mode is hashed. |
| 100 | Absolute path changes but descriptor tree is identical | PASS | Absolute/workspace paths are not hashed or traversed. |
| 101 | Inode/device differ from staging but tree bytes/modes match on same root device | PASS | Inode/device are proof inputs, not digest fields. |
| 102 | Ownership differs but digest fields match | PASS | uid/gid are not hashed. |
| 103 | Timestamps stable but different from staging time | PASS | Timestamps are race proofs, not digest fields. |
| 104 | No-journal replacement directory exactly matches accepted stage | PASS cleanup proof | Existing call site invokes real verifier. |
| 105 | No-journal replacement has extra file | FAIL cleanup proof | Count/digest mismatch blocks cleanup. |
| 106 | No-journal replacement has missing file | FAIL cleanup proof | Count/digest mismatch blocks cleanup. |
| 107 | No-journal replacement has symlink | FAIL cleanup proof | Entry policy blocks cleanup. |
| 108 | No-journal replacement has reserved prefix | FAIL cleanup proof | Reserved namespace blocks cleanup. |
| 109 | Prepared DirectoryObject replacement exactly matches stage | PASS prepared publication proof | Existing call site invokes real verifier. |
| 110 | Prepared DirectoryObject replacement differs after top-level moves | FAIL before prepared publication | Verifier blocks prepared state. |
| 111 | Prepared replacement mutates during verification | FAIL FilesystemChanged | Directory/file stability proof. |
| 112 | Caller root descriptor remains usable after verifier success | PASS | Verifier duplicates and never closes caller descriptor. |
| 113 | Caller root descriptor remains usable after verifier failure | PASS | All owned descriptors close independently. |
| 114 | Early failure with deep stack | PASS descriptor audit | All frame descriptors close through explicit stack cleanup/ARC. |
| 115 | Child-frame creation fails before stack insertion | PASS descriptor audit | Helper consumes and closes owned child descriptor. |
| 116 | Enumeration fdopendir failure | FAIL FilesystemInspectionFailed | Enumeration duplicate is closed. |
| 117 | Enumeration readdir failure | FAIL FilesystemInspectionFailed | DIR ownership closes. |
| 118 | Enumeration closedir failure | FAIL FilesystemInspectionFailed | Close error is not ignored on normal enumeration completion. |
| 119 | Raw names with identical locale collation | PASS deterministic | Raw bytes decide order. |
| 120 | Raw names with uppercase/lowercase collision | PASS deterministic | No case folding. |
| 121 | Directory with zero remaining entry budget and zero children | PASS | Bounded empty enumeration. |
| 122 | Directory with zero remaining entry budget and one child | FAIL EntryLimitExceeded | Budget enforced during enumeration. |
| 123 | Path length uint32 encoding for three bytes | PASS vector 00000003 | Big-endian uint32. |
| 124 | Mode 0644 encoding | PASS vector 000001a4 | Big-endian uint32 mode & 07777. |
| 125 | Size two encoding | PASS vector 0000000000000002 | Big-endian uint64. |
| 126 | Domain prefix terminating NUL omitted | FAIL digest comparison | Implementation uses sizeof(domainPrefix). |
| 127 | Directory content bytes erroneously appended | FAIL digest comparison | Directories emit header only. |
| 128 | File content bytes appended after header | PASS | Exact format. |
| 129 | File content bytes appended before header | FAIL digest comparison | Ordering fixed. |
| 130 | Strict compile treats implicit declaration as error | PASS | clang-tidy frontend exit 0 with -Werror=implicit-function-declaration. |
| 131 | Repository has an external verifier definition | FAIL static gate | Production definition count must remain one static definition. |
| 132 | Repository verifier undefined semantic reference | PASS gate: zero | Two calls bind to prior static definition. |
| 133 | Public header gains verifier API | FAIL non-regression gate | Header diff must be zero. |
| 134 | Manager integration changes | FAIL non-regression gate | Manager diff must be zero. |
| 135 | Journal schema changes | FAIL non-regression gate | Journal body hash remains identical. |
| 136 | Rollback/recovery changes | FAIL non-regression gate | Body hash remains identical. |
| 137 | Keychain enters transaction | FAIL non-regression gate | Manager hash and Keychain item count remain unchanged. |
| 138 | Deterministic raw-order replay variant 01 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 139 | Deterministic raw-order replay variant 02 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 140 | Deterministic raw-order replay variant 03 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 141 | Deterministic raw-order replay variant 04 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 142 | Deterministic raw-order replay variant 05 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 143 | Deterministic raw-order replay variant 06 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 144 | Deterministic raw-order replay variant 07 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 145 | Deterministic raw-order replay variant 08 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 146 | Deterministic raw-order replay variant 09 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 147 | Deterministic raw-order replay variant 10 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 148 | Deterministic raw-order replay variant 11 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 149 | Deterministic raw-order replay variant 12 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 150 | Deterministic raw-order replay variant 13 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 151 | Deterministic raw-order replay variant 14 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 152 | Deterministic raw-order replay variant 15 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 153 | Deterministic raw-order replay variant 16 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 154 | Deterministic raw-order replay variant 17 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 155 | Deterministic raw-order replay variant 18 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 156 | Deterministic raw-order replay variant 19 | PASS model | Repeated model preserves identical pre-order and digest bytes. |
| 157 | Deterministic raw-order replay variant 20 | PASS model | Repeated model preserves identical pre-order and digest bytes. |

## Whitespace, CRLF, and NUL audit

- `PXOptionalRestoreTransaction.m`: bytes=240408, CRLF=0, bare LF=4583, bare CR=0, NUL=0, final newline=True.
- `PXOptionalRestoreTransaction.h`: bytes=4050, CRLF=0, bare LF=79, bare CR=0, NUL=0, final newline=True.
- `AppDataBackupManager.m`: bytes=173097, CRLF=0, bare LF=3244, bare CR=0, NUL=0, final newline=True.
- `TASK-2.13A-REPORT.md`: finalized as LF-only, CRLF=0, bare CR=0, NUL=0, with a final newline.
- `git diff --check` passes for both authorized files.

## Build status and runtime risks

- Strict Objective-C semantic/frontend check passes with implicit declarations treated as errors.
- Full Theos/iOS compile and link is unavailable locally because `THEOS`, Apple `clang`, `xcrun`, and an Objective-C object-producing compiler are unavailable.
- Runtime traversal can hold up to the depth bound in directory descriptors; lower process descriptor limits may cause a fail-closed inspection error before depth 2048.
- The 500000-entry bound is finite but can still consume substantial memory for sorted raw-name arrays; failure remains closed.
- Race detection relies on descriptor identity plus mode, mtime, and ctime as exposed by Darwin `stat`; target-device stress tests remain necessary.
- No target-device crash-interruption or malicious concurrent mutation test was executed in this Windows workspace.

## Full authorized source diff

```diff
warning: in the working copy of 'PXOptionalRestoreTransaction.m', LF will be replaced by CRLF the next time Git touches it
diff --git a/PXOptionalRestoreTransaction.m b/PXOptionalRestoreTransaction.m
index d33611f..d27904d 100644
--- a/PXOptionalRestoreTransaction.m
+++ b/PXOptionalRestoreTransaction.m
@@ -42,6 +42,7 @@ static const NSUInteger PXOptionalRestoreMaximumPathBytes = 4096;
 static const NSUInteger PXOptionalRestoreMaximumComponentBytes = 255;
 static const NSUInteger PXOptionalRestoreMaximumCleanupEntries = 500000;
 static const NSUInteger PXOptionalRestoreMaximumCleanupDepth = 2048;
+static const NSUInteger PXOptionalRestoreMaximumTreeDepth = 2048;
 static const NSUInteger PXOptionalRestoreMaximumJournalBytes = 128 * 1024 * 1024;
 static const NSUInteger PXOptionalRestoreMaximumStaleTransactionIdentifiers = 1;
 static const NSUInteger PXOptionalRestoreMaximumWorkspaceEntries = 8;
@@ -1296,6 +1297,7 @@ static NSData *PXOptionalRestoreRelativePath(NSData *parent, NSData *name) {
 @property (nonatomic, copy) NSArray<NSData *> *names;
 @property (nonatomic, assign) NSUInteger nextIndex;
 @property (nonatomic, copy) NSData *relativePath;
+@property (nonatomic, assign) NSUInteger depth;
 @property (nonatomic, assign) struct stat retainedStat;
 @end

@@ -1310,6 +1312,684 @@ static NSData *PXOptionalRestoreRelativePath(NSData *parent, NSData *name) {
 }
 @end

+static BOOL PXOptionalRestoreVerifierStableDirectoryStatsEqual(const struct stat *before,
+                                                                const struct stat *after) {
+    return before && after &&
+           before->st_dev == after->st_dev &&
+           before->st_ino == after->st_ino &&
+           before->st_mode == after->st_mode &&
+           before->st_mtimespec.tv_sec == after->st_mtimespec.tv_sec &&
+           before->st_mtimespec.tv_nsec == after->st_mtimespec.tv_nsec &&
+           before->st_ctimespec.tv_sec == after->st_ctimespec.tv_sec &&
+           before->st_ctimespec.tv_nsec == after->st_ctimespec.tv_nsec;
+}
+
+static BOOL PXOptionalRestoreVerifierStableFileStatsEqual(const struct stat *before,
+                                                           const struct stat *after) {
+    return before && after &&
+           before->st_dev == after->st_dev &&
+           before->st_ino == after->st_ino &&
+           before->st_mode == after->st_mode &&
+           before->st_nlink == after->st_nlink &&
+           before->st_size == after->st_size &&
+           before->st_mtimespec.tv_sec == after->st_mtimespec.tv_sec &&
+           before->st_mtimespec.tv_nsec == after->st_mtimespec.tv_nsec &&
+           before->st_ctimespec.tv_sec == after->st_ctimespec.tv_sec &&
+           before->st_ctimespec.tv_nsec == after->st_ctimespec.tv_nsec;
+}
+
+static BOOL PXOptionalRestoreVerifierNameIsStrictUTF8(NSData *nameData) {
+    if (![nameData isKindOfClass:[NSData class]] ||
+        nameData.length == 0 ||
+        nameData.length > PXOptionalRestoreMaximumComponentBytes) {
+        return NO;
+    }
+    const unsigned char *bytes = nameData.bytes;
+    for (NSUInteger index = 0; index < nameData.length; index++) {
+        unsigned char value = bytes[index];
+        if (value == 0 || value == '/' || value == '\\' ||
+            value < 0x20 || value == 0x7f) {
+            return NO;
+        }
+    }
+    if (PXOptionalRestoreRawNameEquals(nameData, @".") ||
+        PXOptionalRestoreRawNameEquals(nameData, @"..")) {
+        return NO;
+    }
+    NSString *decoded = [[NSString alloc] initWithData:nameData
+                                               encoding:NSUTF8StringEncoding];
+    if (!decoded) {
+        return NO;
+    }
+    NSData *roundTrip = [decoded dataUsingEncoding:NSUTF8StringEncoding
+                               allowLossyConversion:NO];
+    return roundTrip && [roundTrip isEqualToData:nameData];
+}
+
+static NSArray<NSData *> *PXOptionalRestoreVerifierReadDirectoryNames(
+    int descriptor,
+    NSUInteger maximumNameCount,
+    NSError **error) {
+    int enumerationDescriptor = PXOptionalRestoreDuplicateDescriptor(descriptor);
+    if (enumerationDescriptor < 0 || lseek(enumerationDescriptor, 0, SEEK_SET) < 0) {
+        if (enumerationDescriptor >= 0) {
+            close(enumerationDescriptor);
+        }
+        return PXOptionalRestoreFailObject(error,
+                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                           @"$.replacement",
+                                           @"The replacement directory could not be inspected safely.");
+    }
+    DIR *directory = fdopendir(enumerationDescriptor);
+    if (!directory) {
+        close(enumerationDescriptor);
+        return PXOptionalRestoreFailObject(error,
+                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                           @"$.replacement",
+                                           @"The replacement directory could not be inspected safely.");
+    }
+    NSMutableArray<NSData *> *names = [NSMutableArray array];
+    int enumerationError = 0;
+    for (;;) {
+        errno = 0;
+        struct dirent *entry = readdir(directory);
+        if (!entry) {
+            enumerationError = errno;
+            break;
+        }
+        const char *name = entry->d_name;
+        if ((name[0] == '.' && name[1] == '\0') ||
+            (name[0] == '.' && name[1] == '.' && name[2] == '\0')) {
+            continue;
+        }
+        size_t length = strlen(name);
+        if (length == 0 || length > PXOptionalRestoreMaximumComponentBytes ||
+            names.count >= maximumNameCount) {
+            closedir(directory);
+            return PXOptionalRestoreFailObject(error,
+                                               PXOptionalRestoreTransactionErrorEntryLimitExceeded,
+                                               @"$.replacement",
+                                               @"The replacement tree exceeds a fixed safety limit.");
+        }
+        [names addObject:[NSData dataWithBytes:name length:length]];
+    }
+    if (closedir(directory) != 0 && enumerationError == 0) {
+        enumerationError = errno ?: EIO;
+    }
+    if (enumerationError != 0) {
+        return PXOptionalRestoreFailObject(error,
+                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                           @"$.replacement",
+                                           @"The replacement directory could not be inspected safely.");
+    }
+    return [names sortedArrayUsingComparator:^NSComparisonResult(NSData *left, NSData *right) {
+        return PXOptionalRestoreCompareRawNames(left, right);
+    }];
+}
+
+static PXOptionalRestoreTreeFrame *PXOptionalRestoreCreateTreeFrame(
+    int descriptor,
+    NSData *relativePath,
+    NSUInteger depth,
+    NSUInteger maximumNameCount,
+    dev_t rootDevice,
+    const struct stat *expectedStat,
+    NSError **error) {
+    if (descriptor < 0 || !PXOptionalRestoreSetCloseOnExec(descriptor)) {
+        if (descriptor >= 0) {
+            close(descriptor);
+        }
+        return PXOptionalRestoreFailObject(error,
+                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                           @"$.replacement",
+                                           @"The replacement directory could not be inspected safely.");
+    }
+    struct stat before;
+    struct stat after;
+    memset(&before, 0, sizeof(before));
+    memset(&after, 0, sizeof(after));
+    if (fstat(descriptor, &before) != 0) {
+        close(descriptor);
+        return PXOptionalRestoreFailObject(error,
+                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                           @"$.replacement",
+                                           @"The replacement directory could not be inspected safely.");
+    }
+    if (expectedStat &&
+        !PXOptionalRestoreVerifierStableDirectoryStatsEqual(expectedStat, &before)) {
+        close(descriptor);
+        return PXOptionalRestoreFailObject(error,
+                                           PXOptionalRestoreTransactionErrorFilesystemChanged,
+                                           @"$.replacement",
+                                           @"The replacement tree changed during verification.");
+    }
+    if (!S_ISDIR(before.st_mode) || before.st_dev != rootDevice ||
+        (before.st_mode & (S_ISUID | S_ISGID)) != 0) {
+        close(descriptor);
+        return PXOptionalRestoreFailObject(error,
+                                           PXOptionalRestoreTransactionErrorReplacementMismatch,
+                                           @"$.replacement",
+                                           @"The replacement tree does not match the accepted stage.");
+    }
+    NSArray<NSData *> *names =
+        PXOptionalRestoreVerifierReadDirectoryNames(descriptor, maximumNameCount, error);
+    if (!names) {
+        close(descriptor);
+        return nil;
+    }
+    if (fstat(descriptor, &after) != 0) {
+        close(descriptor);
+        return PXOptionalRestoreFailObject(error,
+                                           PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                           @"$.replacement",
+                                           @"The replacement directory could not be inspected safely.");
+    }
+    if (!PXOptionalRestoreVerifierStableDirectoryStatsEqual(&before, &after)) {
+        close(descriptor);
+        return PXOptionalRestoreFailObject(error,
+                                           PXOptionalRestoreTransactionErrorFilesystemChanged,
+                                           @"$.replacement",
+                                           @"The replacement tree changed during verification.");
+    }
+    PXOptionalRestoreTreeFrame *frame = [[PXOptionalRestoreTreeFrame alloc] init];
+    frame.descriptor = descriptor;
+    frame.names = names;
+    frame.nextIndex = 0;
+    frame.relativePath = relativePath;
+    frame.depth = depth;
+    frame.retainedStat = after;
+    return frame;
+}
+
+static void PXOptionalRestoreCloseTreeFrames(
+    NSMutableArray<PXOptionalRestoreTreeFrame *> *stack) {
+    for (PXOptionalRestoreTreeFrame *frame in stack) {
+        int descriptor = frame.descriptor;
+        frame.descriptor = -1;
+        if (descriptor >= 0) {
+            close(descriptor);
+        }
+    }
+    [stack removeAllObjects];
+}
+
+static BOOL PXOptionalRestoreVerifyDirectoryTree(
+    int rootDescriptor,
+    PXValidatedMainDataStage *expectedStage,
+    NSError **error) {
+    if (error) {
+        *error = nil;
+    }
+    if (rootDescriptor < 0 ||
+        ![expectedStage isKindOfClass:[PXValidatedMainDataStage class]] ||
+        !PXOptionalRestoreLowercaseSHA256IsValid(expectedStage.treeSHA256) ||
+        expectedStage.regularFileCount > expectedStage.entryCount ||
+        expectedStage.directoryCount > expectedStage.entryCount ||
+        expectedStage.regularFileCount > NSUIntegerMax - expectedStage.directoryCount ||
+        expectedStage.regularFileCount + expectedStage.directoryCount != expectedStage.entryCount ||
+        expectedStage.entryCount > PXOptionalRestoreMaximumAggregateEntries) {
+        return PXOptionalRestoreFail(error,
+                                     PXOptionalRestoreTransactionErrorInvalidInput,
+                                     @"$.replacement",
+                                     @"The replacement verification input is invalid.");
+    }
+
+    struct stat rootBefore;
+    struct stat traversalRootStat;
+    memset(&rootBefore, 0, sizeof(rootBefore));
+    memset(&traversalRootStat, 0, sizeof(traversalRootStat));
+    if (fstat(rootDescriptor, &rootBefore) != 0) {
+        return PXOptionalRestoreFail(error,
+                                     PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                     @"$.replacement",
+                                     @"The replacement root could not be inspected safely.");
+    }
+    if (!S_ISDIR(rootBefore.st_mode) ||
+        (rootBefore.st_mode & (S_ISUID | S_ISGID)) != 0) {
+        return PXOptionalRestoreFail(error,
+                                     PXOptionalRestoreTransactionErrorReplacementMismatch,
+                                     @"$.replacement",
+                                     @"The replacement tree does not match the accepted stage.");
+    }
+
+    int traversalRoot = PXOptionalRestoreDuplicateDescriptor(rootDescriptor);
+    if (traversalRoot < 0 || fstat(traversalRoot, &traversalRootStat) != 0) {
+        if (traversalRoot >= 0) {
+            close(traversalRoot);
+        }
+        return PXOptionalRestoreFail(error,
+                                     PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                     @"$.replacement",
+                                     @"The replacement root could not be inspected safely.");
+    }
+    if (!PXOptionalRestoreVerifierStableDirectoryStatsEqual(&rootBefore,
+                                                             &traversalRootStat)) {
+        close(traversalRoot);
+        return PXOptionalRestoreFail(error,
+                                     PXOptionalRestoreTransactionErrorFilesystemChanged,
+                                     @"$.replacement",
+                                     @"The replacement tree changed during verification.");
+    }
+
+    PXOptionalRestoreTreeFrame *rootFrame =
+        PXOptionalRestoreCreateTreeFrame(traversalRoot,
+                                         [NSData data],
+                                         0,
+                                         PXOptionalRestoreMaximumAggregateEntries,
+                                         rootBefore.st_dev,
+                                         &rootBefore,
+                                         error);
+    traversalRoot = -1;
+    if (!rootFrame) {
+        return NO;
+    }
+
+    NSMutableArray<PXOptionalRestoreTreeFrame *> *stack =
+        [NSMutableArray arrayWithObject:rootFrame];
+    NSUInteger enumeratedEntryCount = rootFrame.names.count;
+    NSUInteger entryCount = 0;
+    NSUInteger regularFileCount = 0;
+    NSUInteger directoryCount = 0;
+    unsigned long long regularFileBytes = 0;
+    CC_SHA256_CTX digestContext;
+    CC_SHA256_Init(&digestContext);
+    static const unsigned char domainPrefix[] = "PXMainDataStageTreeV1";
+    CC_SHA256_Update(&digestContext, domainPrefix, (CC_LONG)sizeof(domainPrefix));
+
+    while (stack.count > 0) {
+        PXOptionalRestoreTreeFrame *frame = stack.lastObject;
+        if (frame.nextIndex >= frame.names.count) {
+            struct stat finalDirectoryStat;
+            memset(&finalDirectoryStat, 0, sizeof(finalDirectoryStat));
+            struct stat retainedDirectoryStat = frame.retainedStat;
+            if (fstat(frame.descriptor, &finalDirectoryStat) != 0) {
+                PXOptionalRestoreCloseTreeFrames(stack);
+                return PXOptionalRestoreFail(error,
+                                             PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                             @"$.replacement",
+                                             @"The replacement directory could not be inspected safely.");
+            }
+            if (!PXOptionalRestoreVerifierStableDirectoryStatsEqual(&retainedDirectoryStat,
+                                                                     &finalDirectoryStat) ||
+                finalDirectoryStat.st_dev != rootBefore.st_dev ||
+                (finalDirectoryStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
+                PXOptionalRestoreCloseTreeFrames(stack);
+                return PXOptionalRestoreFail(error,
+                                             PXOptionalRestoreTransactionErrorFilesystemChanged,
+                                             @"$.replacement",
+                                             @"The replacement tree changed during verification.");
+            }
+            int completedDescriptor = frame.descriptor;
+            frame.descriptor = -1;
+            [stack removeLastObject];
+            if (close(completedDescriptor) != 0) {
+                PXOptionalRestoreCloseTreeFrames(stack);
+                return PXOptionalRestoreFail(error,
+                                             PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                             @"$.replacement",
+                                             @"The replacement directory could not be closed safely.");
+            }
+            continue;
+        }
+
+        NSData *nameData = frame.names[frame.nextIndex++];
+        if (nameData.length == 0 ||
+            nameData.length > PXOptionalRestoreMaximumComponentBytes) {
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorEntryLimitExceeded,
+                                         @"$.replacement",
+                                         @"The replacement tree exceeds a fixed safety limit.");
+        }
+        if (!PXOptionalRestoreVerifierNameIsStrictUTF8(nameData)) {
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorReplacementMismatch,
+                                         @"$.replacement",
+                                         @"The replacement tree does not match the accepted stage.");
+        }
+        if (frame.depth >= PXOptionalRestoreMaximumTreeDepth) {
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorEntryLimitExceeded,
+                                         @"$.replacement",
+                                         @"The replacement tree exceeds a fixed safety limit.");
+        }
+        NSData *relativePath = PXOptionalRestoreRelativePath(frame.relativePath, nameData);
+        if (!relativePath || relativePath.length > UINT32_MAX) {
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorEntryLimitExceeded,
+                                         @"$.replacement",
+                                         @"The replacement tree exceeds a fixed safety limit.");
+        }
+        NSUInteger entryDepth = frame.depth + 1;
+        if (entryDepth > PXOptionalRestoreMaximumTreeDepth ||
+            entryCount >= PXOptionalRestoreMaximumAggregateEntries) {
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorEntryLimitExceeded,
+                                         @"$.replacement",
+                                         @"The replacement tree exceeds a fixed safety limit.");
+        }
+        entryCount++;
+
+        if ((entryDepth == 1 && PXOptionalRestoreNameIsContainerMetadata(nameData)) ||
+            PXOptionalRestoreRawNameHasPrefix(nameData,
+                                              PXOptionalRestoreTransactionPrefix)) {
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorReplacementMismatch,
+                                         @"$.replacement",
+                                         @"The replacement tree does not match the accepted stage.");
+        }
+
+        char *entryName = PXOptionalRestoreCopyTerminatedName(nameData);
+        if (!entryName) {
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorEntryLimitExceeded,
+                                         @"$.replacement",
+                                         @"The replacement tree exceeds a fixed safety limit.");
+        }
+        struct stat namespaceStat;
+        memset(&namespaceStat, 0, sizeof(namespaceStat));
+        if (fstatat(frame.descriptor,
+                    entryName,
+                    &namespaceStat,
+                    AT_SYMLINK_NOFOLLOW) != 0) {
+            free(entryName);
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                         @"$.replacement",
+                                         @"A replacement entry could not be inspected safely.");
+        }
+        if (namespaceStat.st_dev != rootBefore.st_dev ||
+            (namespaceStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
+            free(entryName);
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorReplacementMismatch,
+                                         @"$.replacement",
+                                         @"The replacement tree does not match the accepted stage.");
+        }
+
+        if (S_ISDIR(namespaceStat.st_mode)) {
+            int childDescriptor = openat(frame.descriptor,
+                                         entryName,
+                                         O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
+            free(entryName);
+            if (childDescriptor < 0 ||
+                !PXOptionalRestoreSetCloseOnExec(childDescriptor)) {
+                if (childDescriptor >= 0) {
+                    close(childDescriptor);
+                }
+                PXOptionalRestoreCloseTreeFrames(stack);
+                return PXOptionalRestoreFail(error,
+                                             PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                             @"$.replacement",
+                                             @"A replacement directory could not be opened safely.");
+            }
+            struct stat openedDirectoryStat;
+            memset(&openedDirectoryStat, 0, sizeof(openedDirectoryStat));
+            if (fstat(childDescriptor, &openedDirectoryStat) != 0) {
+                close(childDescriptor);
+                PXOptionalRestoreCloseTreeFrames(stack);
+                return PXOptionalRestoreFail(error,
+                                             PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                             @"$.replacement",
+                                             @"A replacement directory could not be inspected safely.");
+            }
+            if (!S_ISDIR(openedDirectoryStat.st_mode) ||
+                openedDirectoryStat.st_dev != namespaceStat.st_dev ||
+                openedDirectoryStat.st_ino != namespaceStat.st_ino ||
+                (openedDirectoryStat.st_mode & S_IFMT) !=
+                    (namespaceStat.st_mode & S_IFMT)) {
+                close(childDescriptor);
+                PXOptionalRestoreCloseTreeFrames(stack);
+                return PXOptionalRestoreFail(error,
+                                             PXOptionalRestoreTransactionErrorFilesystemChanged,
+                                             @"$.replacement",
+                                             @"The replacement tree changed during verification.");
+            }
+            if (openedDirectoryStat.st_dev != rootBefore.st_dev ||
+                (openedDirectoryStat.st_mode & (S_ISUID | S_ISGID)) != 0) {
+                close(childDescriptor);
+                PXOptionalRestoreCloseTreeFrames(stack);
+                return PXOptionalRestoreFail(error,
+                                             PXOptionalRestoreTransactionErrorReplacementMismatch,
+                                             @"$.replacement",
+                                             @"The replacement tree does not match the accepted stage.");
+            }
+            if (directoryCount == NSUIntegerMax) {
+                close(childDescriptor);
+                PXOptionalRestoreCloseTreeFrames(stack);
+                return PXOptionalRestoreFail(error,
+                                             PXOptionalRestoreTransactionErrorEntryLimitExceeded,
+                                             @"$.replacement",
+                                             @"The replacement tree exceeds a fixed safety limit.");
+            }
+            directoryCount++;
+            PXOptionalRestoreHashTreeHeader(&digestContext,
+                                            'D',
+                                            relativePath,
+                                            openedDirectoryStat.st_mode,
+                                            0);
+            if (enumeratedEntryCount > PXOptionalRestoreMaximumAggregateEntries) {
+                close(childDescriptor);
+                PXOptionalRestoreCloseTreeFrames(stack);
+                return PXOptionalRestoreFail(error,
+                                             PXOptionalRestoreTransactionErrorEntryLimitExceeded,
+                                             @"$.replacement",
+                                             @"The replacement tree exceeds a fixed safety limit.");
+            }
+            NSUInteger remainingEntryBudget =
+                PXOptionalRestoreMaximumAggregateEntries - enumeratedEntryCount;
+            PXOptionalRestoreTreeFrame *childFrame =
+                PXOptionalRestoreCreateTreeFrame(childDescriptor,
+                                                 relativePath,
+                                                 entryDepth,
+                                                 remainingEntryBudget,
+                                                 rootBefore.st_dev,
+                                                 &openedDirectoryStat,
+                                                 error);
+            childDescriptor = -1;
+            if (!childFrame) {
+                PXOptionalRestoreCloseTreeFrames(stack);
+                return NO;
+            }
+            if (childFrame.names.count >
+                PXOptionalRestoreMaximumAggregateEntries - enumeratedEntryCount) {
+                PXOptionalRestoreCloseTreeFrames(stack);
+                return PXOptionalRestoreFail(error,
+                                             PXOptionalRestoreTransactionErrorEntryLimitExceeded,
+                                             @"$.replacement",
+                                             @"The replacement tree exceeds a fixed safety limit.");
+            }
+            enumeratedEntryCount += childFrame.names.count;
+            [stack addObject:childFrame];
+            continue;
+        }
+
+        if (!S_ISREG(namespaceStat.st_mode) ||
+            namespaceStat.st_nlink != 1 ||
+            namespaceStat.st_size < 0) {
+            free(entryName);
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorReplacementMismatch,
+                                         @"$.replacement",
+                                         @"The replacement tree does not match the accepted stage.");
+        }
+
+        int fileDescriptor = openat(frame.descriptor,
+                                    entryName,
+                                    O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
+        free(entryName);
+        if (fileDescriptor < 0 || !PXOptionalRestoreSetCloseOnExec(fileDescriptor)) {
+            if (fileDescriptor >= 0) {
+                close(fileDescriptor);
+            }
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                         @"$.replacement",
+                                         @"A replacement file could not be opened safely.");
+        }
+        struct stat fileBefore;
+        memset(&fileBefore, 0, sizeof(fileBefore));
+        if (fstat(fileDescriptor, &fileBefore) != 0) {
+            close(fileDescriptor);
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                         @"$.replacement",
+                                         @"A replacement file could not be inspected safely.");
+        }
+        if (!S_ISREG(fileBefore.st_mode) ||
+            fileBefore.st_dev != namespaceStat.st_dev ||
+            fileBefore.st_ino != namespaceStat.st_ino ||
+            (fileBefore.st_mode & S_IFMT) != (namespaceStat.st_mode & S_IFMT)) {
+            close(fileDescriptor);
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorFilesystemChanged,
+                                         @"$.replacement",
+                                         @"The replacement tree changed during verification.");
+        }
+        if (fileBefore.st_dev != rootBefore.st_dev ||
+            fileBefore.st_nlink != 1 ||
+            fileBefore.st_size < 0 ||
+            (fileBefore.st_mode & (S_ISUID | S_ISGID)) != 0) {
+            close(fileDescriptor);
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorReplacementMismatch,
+                                         @"$.replacement",
+                                         @"The replacement tree does not match the accepted stage.");
+        }
+        unsigned long long fileSize = (unsigned long long)fileBefore.st_size;
+        if (regularFileBytes > ULLONG_MAX - fileSize ||
+            regularFileCount == NSUIntegerMax) {
+            close(fileDescriptor);
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorEntryLimitExceeded,
+                                         @"$.replacement",
+                                         @"The replacement tree exceeds a fixed safety limit.");
+        }
+        regularFileCount++;
+        PXOptionalRestoreHashTreeHeader(&digestContext,
+                                        'F',
+                                        relativePath,
+                                        fileBefore.st_mode,
+                                        fileSize);
+        unsigned char buffer[PXOptionalRestoreStreamBufferSize];
+        unsigned long long bytesRead = 0;
+        BOOL readFailed = NO;
+        for (;;) {
+            ssize_t amount = read(fileDescriptor, buffer, sizeof(buffer));
+            if (amount < 0 && errno == EINTR) {
+                continue;
+            }
+            if (amount < 0) {
+                readFailed = YES;
+                break;
+            }
+            if (amount == 0) {
+                break;
+            }
+            if (bytesRead > ULLONG_MAX - (unsigned long long)amount) {
+                close(fileDescriptor);
+                PXOptionalRestoreCloseTreeFrames(stack);
+                return PXOptionalRestoreFail(error,
+                                             PXOptionalRestoreTransactionErrorEntryLimitExceeded,
+                                             @"$.replacement",
+                                             @"The replacement tree exceeds a fixed safety limit.");
+            }
+            bytesRead += (unsigned long long)amount;
+            if (bytesRead > fileSize) {
+                close(fileDescriptor);
+                PXOptionalRestoreCloseTreeFrames(stack);
+                return PXOptionalRestoreFail(error,
+                                             PXOptionalRestoreTransactionErrorFilesystemChanged,
+                                             @"$.replacement",
+                                             @"The replacement tree changed during verification.");
+            }
+            CC_SHA256_Update(&digestContext, buffer, (CC_LONG)amount);
+        }
+        if (readFailed) {
+            close(fileDescriptor);
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                         @"$.replacement",
+                                         @"A replacement file could not be read safely.");
+        }
+        struct stat fileAfter;
+        memset(&fileAfter, 0, sizeof(fileAfter));
+        if (fstat(fileDescriptor, &fileAfter) != 0) {
+            close(fileDescriptor);
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                         @"$.replacement",
+                                         @"A replacement file could not be inspected safely.");
+        }
+        int fileCloseResult = close(fileDescriptor);
+        fileDescriptor = -1;
+        if (fileCloseResult != 0) {
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                         @"$.replacement",
+                                         @"A replacement file could not be closed safely.");
+        }
+        if (bytesRead != fileSize ||
+            !PXOptionalRestoreVerifierStableFileStatsEqual(&fileBefore, &fileAfter)) {
+            PXOptionalRestoreCloseTreeFrames(stack);
+            return PXOptionalRestoreFail(error,
+                                         PXOptionalRestoreTransactionErrorFilesystemChanged,
+                                         @"$.replacement",
+                                         @"The replacement tree changed during verification.");
+        }
+        regularFileBytes += fileSize;
+    }
+
+    struct stat rootAfter;
+    memset(&rootAfter, 0, sizeof(rootAfter));
+    if (fstat(rootDescriptor, &rootAfter) != 0) {
+        return PXOptionalRestoreFail(error,
+                                     PXOptionalRestoreTransactionErrorFilesystemInspectionFailed,
+                                     @"$.replacement",
+                                     @"The replacement root could not be inspected safely.");
+    }
+    if (!PXOptionalRestoreVerifierStableDirectoryStatsEqual(&rootBefore, &rootAfter) ||
+        !S_ISDIR(rootAfter.st_mode) ||
+        (rootAfter.st_mode & (S_ISUID | S_ISGID)) != 0) {
+        return PXOptionalRestoreFail(error,
+                                     PXOptionalRestoreTransactionErrorFilesystemChanged,
+                                     @"$.replacement",
+                                     @"The replacement tree changed during verification.");
+    }
+
+    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
+    CC_SHA256_Final(digest, &digestContext);
+    NSString *treeSHA256 = PXOptionalRestoreLowercaseHexDigest(digest);
+    if (entryCount != expectedStage.entryCount ||
+        regularFileCount != expectedStage.regularFileCount ||
+        directoryCount != expectedStage.directoryCount ||
+        regularFileBytes != expectedStage.regularFileBytes ||
+        ![treeSHA256 isEqualToString:expectedStage.treeSHA256]) {
+        return PXOptionalRestoreFail(error,
+                                     PXOptionalRestoreTransactionErrorReplacementMismatch,
+                                     @"$.replacement",
+                                     @"The replacement tree does not match the accepted stage.");
+    }
+    return YES;
+}
+
 static BOOL PXOptionalRestoreDigestFileDescriptor(int descriptor,
                                                    unsigned long long maximumBytes,
                                                    unsigned long long *byteCountOut,
```

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
