# TASK-1.11 REPORT ? Remove Unsafe Permission and Marker-File Behavior

## 1. Scope and baseline evidence

- Task: `TASK-1.11` only.
- Expected and actual baseline HEAD: `7b277bfd2579e53f0015b89ef36b43440688590b`.
- Accepted TASK-1.10 production commit in ancestry: `2579c76a8716761b88bf99f7d77b14f4ddb1171e`.
- Production source changed: `AppDataCleaner.m` only.
- Required report created: `docs/backup-restore-hardening/reports/TASK-1.11-REPORT.md`.
- TASK-1.12 was not started; public compatibility selectors remain present.

Initial `git status --short --untracked-files=all`:

```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-1.10-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.8-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.8A-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.9-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.11-remove-unsafe-permission-and-marker-behavior.md
?? docs/backup-restore-hardening/tasks/TASK-1.8A-restore-resolver-contract-and-report-gates.md
?? docs/backup-restore-hardening/tasks/TASK-1.9-migrate-app-group-clear.md
```

The listed documentation/review/task artifacts were coordinator-owned pre-existing changes and were not rewritten, reverted, formatted or staged by this task.

```text
git rev-parse HEAD
7b277bfd2579e53f0015b89ef36b43440688590b

git log -3 --oneline
7b277bf Accepted Task 1.10
2579c76 phase1(task-1.10): integrate keychain clear result
0bb2e35 phase1(task-1.9): migrate app group clear
```

## 2. Diff scope and stat

Pre-commit production diff:

```text
AppDataCleaner.m | 97 ++++++++++++++++++--------------------------------------
1 file changed, 31 insertions(+), 66 deletions(-)
```

The implementation commit is constrained to:

```text
AppDataCleaner.m
docs/backup-restore-hardening/reports/TASK-1.11-REPORT.md
```

Suggested commit title: `phase1(task-1.11): remove unsafe permission and marker behavior`.

## 3. Protected-file SHA-256 before/after

Initial and final working-tree SHA-256 values are identical. The protected-file diff command returned exit code `0`.

| Protected file | Before SHA-256 | After SHA-256 |
|---|---|---|
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` |
| `AppEntitlementsReader.h` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` |
| `AppEntitlementsReader.m` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` |
| `CommandRunner.h` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` |
| `AppDataBackupManager.h` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` |
| `AppDataBackupManager.m` | `c40f4204d96d77211921320f8c43c889fe92d1714358ba37ca4713d2f43d6636` | `c40f4204d96d77211921320f8c43c889fe92d1714358ba37ca4713d2f43d6636` |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` |
| `KeychainHelper/backup_helper.m` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` |
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` |
| `Makefile` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` |

## 4. Accepted typed-path body hashes

Hash definition: SHA-256 over the exact UTF-8 method/function body from opening `{` through matching `}`, preserving CRLF bytes. All accepted bodies are byte-identical before and after TASK-1.11.

| Body | Before SHA-256 | After SHA-256 | Bytes | Result |
|---|---|---|---:|---|
| `PXShellValidatedApplicationDataWipe` | `f98d0de5072a3be6e1bc90bb6e0fb0e67164f326fb63462b86eaed04a4bcdfc4` | `f98d0de5072a3be6e1bc90bb6e0fb0e67164f326fb63462b86eaed04a4bcdfc4` | 981 | PASS |
| `PXApplicationDataCommandResultSucceeded` | `6e4a14b1db210c3d7b16e331b0ffa8bc788a110dea5d4d461d14137fcd9087a0` | `6e4a14b1db210c3d7b16e331b0ffa8bc788a110dea5d4d461d14137fcd9087a0` | 143 | PASS |
| `PXApplicationDataPostconditionIsValid` | `9bcd8389ba32fe6e11e108015577a2f58f043f99776ca98a4a9c440471e1fd1c` | `9bcd8389ba32fe6e11e108015577a2f58f043f99776ca98a4a9c440471e1fd1c` | 4981 | PASS |
| `_completeDataWipeForMigratedRequest:` | `c7a13979b9bc07f41ef1b4f447db1016daac00de9b4da3643f6006fa7b647e3d` | `c7a13979b9bc07f41ef1b4f447db1016daac00de9b4da3643f6006fa7b647e3d` | 7170 | PASS |
| `_clearExactDataContainerComponentForIdentifiers:` | `1d3a53c81fda746642ded3778c31b146c5cc087f01f58514f4554ac997912ce1` | `1d3a53c81fda746642ded3778c31b146c5cc087f01f58514f4554ac997912ce1` | 10086 | PASS |
| `_clearExactAppGroupsComponentForIdentifiers:` | `5dc6b97958895037631321b10780aeb15b3ca31ba0f683a8cb5ded036a110a8b` | `5dc6b97958895037631321b10780aeb15b3ca31ba0f683a8cb5ded036a110a8b` | 8743 | PASS |
| `_keychainClearPlanForBundleIdentifier:` | `17b6c36b3dd18a4091e05998d22718c3bd8e0dbde1fb625d88002ff81d5e579f` | `17b6c36b3dd18a4091e05998d22718c3bd8e0dbde1fb625d88002ff81d5e579f` | 17808 | PASS |
| `_executeKeychainWipeForBundleIdentifier:` | `dd639e3701a18d1e15753d9c5fd32eed392682b18e7a83157c85396e5674b2cc` | `dd639e3701a18d1e15753d9c5fd32eed392682b18e7a83157c85396e5674b2cc` | 12578 | PASS |
| `_keychainComponentForPlan:passResults:` | `d552d7f14597e6b9165ecd5ec39e79085ac8e46f20785f6e31272d9f3da465d8` | `d552d7f14597e6b9165ecd5ec39e79085ac8e46f20785f6e31272d9f3da465d8` | 5925 | PASS |
| `clearDataForBundleID:completion:` | `25a77cd288b7b542d7a7b20ec90e40db172ad7da948198f38c4411a1602fa8c1` | `25a77cd288b7b542d7a7b20ec90e40db172ad7da948198f38c4411a1602fa8c1` | 15419 | PASS |
| `completeAppDataWipe:` | `204b642c83fb14994f4177a717aec4ace883c93c5a3aede0f6d3af53cb4aa644` | `204b642c83fb14994f4177a717aec4ace883c93c5a3aede0f6d3af53cb4aa644` | 1182 | PASS |

This proves no behavior change to the strict ApplicationData script, command-result/postcondition logic, four-scope data aggregate, exact ExtensionData/PluginKitData and AppGroups execution, immutable Keychain plan/execution/accounting, main five-scope orchestration, callback precedence, or data-only `completeAppDataWipe:` compatibility path.

## 5. Permission, ownership, flag and marker inventory

| Token/behavior | Before | After | Classification |
|---|---:|---:|---|
| `chmod -R` | 7 | 0 | Removed unsafe arbitrary-tree recursive mode rewrite. |
| `find -exec chmod` | 1 | 0 | Removed recursive per-directory mode rewrite. |
| `chown -R` | 2 | 0 | Replaced only the two fixed recreated-directory operations with non-recursive ownership. |
| `chflags -R` | 5 | 1 | Only accepted canonical strict-child preparation remains. |
| `active shell touch` | 2 | 0 | Removed marker creation and Siri timestamp disguise. |
| `.nomedia` | 1 | 0 | Removed legacy marker. |
| `.initialized` | 1 | 0 | Removed legacy marker. |
| `AssistantServices target` | 1 | 0 | Removed system-framework timestamp target. |
| `NSFilePosixPermissions @0700` | 1 | 1 | Accepted narrow unique Keychain temporary workspace mode preserved. |
| `helper chmod 0755` | 1 | 1 | Accepted narrow copied helper executable mode preserved. |
| `narrow /var/tmp chmod 0644` | 3 | 3 | Accepted narrow task-owned compatibility-file modes preserved. |
| `receipt token` | 0 | 0 | Remains absent. |
| `PXClearScopeDefaultMask` | 0 | 0 | Remains absent from migration. |

Remaining active permission/ownership operations are fully classified:

- one `chflags -R` inside unchanged `PXShellValidatedApplicationDataWipe`, applied to the canonical validator-authorized immediate non-metadata child;
- one `NSFilePosixPermissions: @0700` for the unique Keychain temporary directory;
- one non-recursive C `chmod(..., 0755)` for the request-local copied Keychain helper;
- three non-recursive `chmod 644` commands for task-owned `/var/tmp` plist compatibility files;
- two non-recursive `chown mobile:mobile` commands on newly recreated fixed Mail and MobileSafari WebKit directories.

Comments containing the English word ?touching? are not shell commands. Active shell `touch` count is zero.

## 6. Focused implementation evidence

### 6.1 `PXShellFinalSweep` and `finalSweepForContainer:`

```objc
static NSString *PXShellFinalSweep(NSString *containerPath) {
    if (!containerPath.length) return @"";
    NSString *q = PXShellQuote(containerPath);
    return [NSString stringWithFormat:
            @"find %@ -mindepth 1 -path '*/.com.apple*' -prune -o -exec rm -rf {} + 2>/dev/null || true",
            q];
}
```

The selector, type/existence guards, deep-clean timeout selection and single call to this fragment are unchanged. No chmod, chown, chflags, marker, mkdir or validator was added.

### 6.2 `fixPermissionsAndRemovePath:`

- validates a nonempty string and returns when the path is absent;
- tries `NSFileManager removeItemAtPath:error:` first;
- only on Foundation failure, creates one `PXShellQuote(path)` value and invokes one bounded `rm -rf` fallback with `timeoutSec:120`;
- contains no permission/flag preparation and no wildcard expansion added by TASK-1.11.

### 6.3 `fixPermissionsForPath:`

The public compatibility selector is now a read/log-only no-op: it validates a nonempty string, optionally checks existence, logs that recursive permission mutation is intentionally skipped, and returns normally. Its body contains zero command runner, chmod, chown, chflags, setAttributes, mode, deletion, directory creation or file-write operations.

### 6.4 Fast wipe and WebKit wipe

- `fastWipeDirectoryContents:keepDirectoryStructure:timeoutSec:` retains both deletion branches, `.com.apple*` pruning, quoting and timeout fallback, then executes only `wipePart`.
- `wipeWebKitDirectoryContents:` retains the presence guard, WebKit deletion, WebsiteData cleanup, standard storage-directory recreation, LocalStorage cleanup and IndexedDB cleanup. The initial recursive chmod was removed without replacement.

### 6.5 Aggressive cleanup and complete-container compatibility wipe

- `performAggressiveCleanupFor:` lost only the recursive Library chmod and its comment. Its remaining legacy behavior was not redesigned; the typed main Clear body remains byte-identical and cannot call this method.
- `completelyWipeContainer:` keeps its selector, absence guard, deep-clean timeout selection, both MCM metadata patterns, non-metadata file deletion, empty non-metadata directory deletion, existing quoting and recreation of Documents, Library/Caches, Library/Preferences and tmp.
- Recursive chmod, `find -exec chmod`, recreated-directory chmod and `.nomedia`/`.initialized` touch commands are absent. No replacement marker, xattr, timestamp or sentinel was added.

### 6.6 SiriAnalytics and fixed recreated-directory ownership

- All existing SiriAnalytics exact bundle ID, app-name and company-name SQLite DELETE operations plus VACUUM remain. The `touch -r` write to AssistantServices was removed without replacement.
- Mail and MobileSafari WebKit retain the existing `mkdir` ordering and exact fixed targets, but now use non-recursive `chown mobile:mobile`.

## 7. Marker and substitute-marker audit

Full-file results: `.nomedia=0`, `.initialized=0`, active shell `touch=0`, AssistantServices target `=0`, `setxattr/xattr=0`, `NSFileModificationDate=0`, and `utimes=0`. The diff adds no `.cleaned`, `.cleared`, `.reset`, `.projectx`, `.weaponx` filesystem marker, hidden marker directory, zero-byte sentinel or defaults-based completion marker. Existing `com.weaponx...` domains and `Mail.WeaponXTrash` quarantine names predate this task and are not completion markers.

## 8. Typed main Clear reachability and compatibility

The byte-identical `clearDataForBundleID:completion:` body has zero calls to `finalSweepForContainer:`, `fixPermissionsForPath:`, `completelyWipeContainer:`, fast wipe, WebKit wipe, aggressive cleanup or full cleanup. It also has zero calls to the legacy Keychain wrapper.

The exact four-scope and five-scope masks remain:

```text
Data: ApplicationData | ExtensionData | AppGroups | PluginKitData
Full: ApplicationData | ExtensionData | AppGroups | PluginKitData | Keychain
Full aggregate structural count: 5
```

`completeAppDataWipe:` remains byte-identical, four-scope and data-only. `AppDataCleaner.h` is protected and unchanged; the four named public selector declarations and implementation definitions remain present. No API was removed, quarantined or given a new return type.

## 9. Static gate table

| Gate | Result |
|---|---|
| baseline matches | PASS |
| chmod -R 0 | PASS |
| find -exec chmod 0 | PASS |
| chown -R 0 | PASS |
| chflags -R exactly 1 | PASS |
| chflags only strict | PASS |
| active shell touch 0 | PASS |
| nomedia 0 | PASS |
| initialized 0 | PASS |
| AssistantServices target 0 | PASS |
| 0700 preserved | PASS |
| helper 0755 preserved | PASS |
| narrow 0644 preserved | PASS |
| receipt 0 | PASS |
| default mask 0 | PASS |
| PXShellFinalSweep deletion only | PASS |
| fixRemove no permissions | PASS |
| fixPermissions no-op | PASS |
| fastWipe no permissions | PASS |
| webKit no permissions | PASS |
| aggressive no permissions | PASS |
| completeWipe no permissions markers | PASS |
| siri no timestamp write | PASS |
| mail nonrecursive chown | PASS |
| safari nonrecursive chown | PASS |
| four scope exact | PASS |
| five scope exact | PASS |
| full aggregate count 5 | PASS |
| compat data only | PASS |
| main legacy keychain wrapper 0 | PASS |
| main legacy permission helpers 0 | PASS |
| all typed hashes equal | PASS |
| public selector definitions | PASS |
| NUL 0 | PASS |
| CRLF preserved | PASS |
| lexical delimiters balanced | PASS |
| Method-boundary focused gate suite | PASS ? 22/22 |
| Aggregate full-file/typed gate suite | PASS ? 36/36 |
| Protected-file diff | PASS ? exit 0 |
| `git diff --check` | PASS ? exit 0 |
| Lexical delimiter audit | PASS |
| NUL audit | PASS ? 0 |

## 10. Scenario matrix

| # | Scenario | Status | Evidence |
|---:|---|---|---|
| 1 | invalid/empty path passed to `fixPermissionsForPath:` | **STATIC COVERAGE / DEVICE PENDING** | Exact runtime type/nonempty guard returns before any read or mutation. |
| 2 | existing path passed to `fixPermissionsForPath:` | **STATIC COVERAGE / DEVICE PENDING** | Only read-only existence check and intentional-skip log remain. |
| 3 | absent path passed to `fixPermissionsAndRemovePath:` | **STATIC COVERAGE / DEVICE PENDING** | Absent-path early return remains. |
| 4 | Foundation deletion succeeds in `fixPermissionsAndRemovePath:` | **STATIC COVERAGE / DEVICE PENDING** | `removeItemAtPath:error:` runs first; fallback is inside `if (!success)`. |
| 5 | Foundation deletion fails and bounded quoted `rm -rf` fallback runs | **STATIC COVERAGE / DEVICE PENDING** | Exactly one `PXShellQuote(path)` fallback with `timeoutSec:120` remains. |
| 6 | `fixPermissionsAndRemovePath:` performs no chmod | **STATIC PASS** | Method-boundary count is zero. |
| 7 | `fixPermissionsAndRemovePath:` performs no chflags | **STATIC PASS** | Method-boundary count is zero. |
| 8 | final sweep receives an absent path | **STATIC COVERAGE / DEVICE PENDING** | Existing type/nonempty and existence early returns remain. |
| 9 | final sweep deletion command contains no permission prefix | **STATIC PASS** | `PXShellFinalSweep` contains only the prune-aware `find` expression. |
| 10 | fast wipe with `keepStructure = YES` | **STATIC COVERAGE / DEVICE PENDING** | Metadata-pruning `find` branch remains. |
| 11 | fast wipe with `keepStructure = NO` | **STATIC COVERAGE / DEVICE PENDING** | Existing quoted `rm -rf path/*` branch remains. |
| 12 | fast wipe contains no permission/flag preparation | **STATIC PASS** | Method has no chmod/chown/chflags/touch. |
| 13 | WebKit directory absent | **STATIC COVERAGE / DEVICE PENDING** | Existing presence guard remains. |
| 14 | WebKit directory present and deletion proceeds without chmod | **STATIC COVERAGE / DEVICE PENDING** | Deletion, WebsiteData cleanup and recreation remain; chmod is absent. |
| 15 | aggressive cleanup no longer chmods Library | **STATIC PASS** | The single Library chmod and related comment were removed. |
| 16 | `completelyWipeContainer:` target absent | **STATIC COVERAGE / DEVICE PENDING** | Existing absence early return remains. |
| 17 | `completelyWipeContainer:` target present | **STATIC COVERAGE / DEVICE PENDING** | Deletion and recreation script remains; device execution not run. |
| 18 | MCM metadata filenames remain excluded from deletion | **STATIC PASS** | Both metadata filename patterns remain in the file and directory `find` exclusions. |
| 19 | required compatibility directories are still recreated | **STATIC PASS** | Documents, Library/Caches, Library/Preferences and tmp remain in `mkdir -p`. |
| 20 | `.nomedia` is not created | **STATIC PASS** | Full-file occurrence count is zero. |
| 21 | `.initialized` is not created | **STATIC PASS** | Full-file occurrence count is zero. |
| 22 | no substitute marker is created | **STATIC PASS** | No new hidden marker/sentinel/xattr/defaults completion behavior appears in the diff. |
| 23 | SiriAnalytics SQLite work remains | **STATIC PASS** | All DELETE families and VACUUM remain. |
| 24 | SiriAnalytics system-framework timestamp command is absent | **STATIC PASS** | Active shell touch and AssistantServices target counts are zero. |
| 25 | MobileMail recreated directory receives non-recursive ownership only | **STATIC PASS** | `mkdir` is followed by `chown mobile:mobile` without `-R`. |
| 26 | MobileSafari recreated WebKit directory receives non-recursive ownership only | **STATIC PASS** | `mkdir` is followed by `chown mobile:mobile` without `-R`. |
| 27 | no recursive chown remains | **STATIC PASS** | Full-file `chown -R` count is zero. |
| 28 | no recursive chmod remains | **STATIC PASS** | Full-file `chmod -R` and `find ... -exec chmod` counts are zero. |
| 29 | exactly one recursive chflags remains | **STATIC PASS** | Full-file `chflags -R` count is one. |
| 30 | remaining chflags is inside accepted canonical strict script | **STATIC PASS** | Outside `PXShellValidatedApplicationDataWipe`, count is zero; body hash is unchanged. |
| 31 | TASK-1.10 temporary directory remains mode 0700 | **STATIC PASS** | Exact `NSFilePosixPermissions: @0700` occurrence remains once. |
| 32 | TASK-1.10 temporary helper remains mode 0755 | **STATIC PASS** | Exact `chmod(workingHelper.fileSystemRepresentation, 0755)` remains once. |
| 33 | Keychain initial/final pass accounting is unchanged | **STATIC PASS** | Keychain plan, execution, component builder and main-flow body hashes are unchanged. |
| 34 | final five-scope aggregate is unchanged | **STATIC PASS** | Main body hash unchanged; exact five-scope mask and aggregate count remain. |
| 35 | callback precedence is unchanged | **STATIC PASS** | `clearDataForBundleID:completion:` body hash is unchanged. |
| 36 | ApplicationData strict command body is unchanged | **STATIC PASS** | Strict command body SHA-256 is identical. |
| 37 | ExtensionData/PluginKitData strict command reuse is unchanged | **STATIC PASS** | Exact data-container component body SHA-256 is identical. |
| 38 | AppGroups strict command reuse is unchanged | **STATIC PASS** | App Groups component body SHA-256 is identical. |
| 39 | `completeAppDataWipe:` remains four-scope/data-only | **STATIC PASS** | Body hash identical and no Keychain execution token occurs in the body. |
| 40 | public selectors remain declared and implemented | **STATIC PASS** | Header protected hash is unchanged; each required implementation definition remains exactly once. |
| 41 | Backup/Restore files are unchanged | **STATIC PASS** | Backup manager and Keychain backup helper protected hashes/diff are unchanged. |
| 42 | protected-file diff is empty | **STATIC PASS** | Required `git diff --exit-code -- <protected files>` returned 0. |
| 43 | receipt tokens remain absent | **STATIC PASS** | `_MASReceipt` count is zero. |
| 44 | cumulative diff whitespace check passes | **STATIC PASS** | `git diff --check` returned 0. |
| 45 | no NUL bytes are introduced | **STATIC PASS** | AppDataCleaner.m NUL count is zero. |

No `DEVICE PASS` is claimed. Runtime path/deletion behavior requires the project owner?s GitHub Actions and device validation.

## 11. Verification commands

Pre-commit commands executed:

```text
git status --short --untracked-files=all
git diff --check                         -> PASS
git diff --stat -- AppDataCleaner.m      -> 31 insertions, 66 deletions
git diff -- AppDataCleaner.m             -> reviewed focused 97-changed-line source diff
git diff --exit-code -- <protected>      -> exit 0
```

Post-commit commands required and reserved for execution immediately after creating the implementation commit:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 7b277bfd2579e53f0015b89ef36b43440688590b..HEAD --check
git diff --name-status 7b277bfd2579e53f0015b89ef36b43440688590b..HEAD
```

## 12. Build status

Local Objective-C/Theos compilation was not available in this Windows workspace: `clang`, `make` and `xcrun` were all `NOT_FOUND`. No local build success is claimed. GitHub Actions remains the build owner, and device runtime scenarios remain pending.

## 13. Remaining risks

- Broad raw-path and heuristic deletion APIs still exist for compatibility and remain unsafe for new callers; their quarantine is explicitly TASK-1.12 and was not started here.
- Removing recursive permission/flag preparation may expose existing ownership or immutable-flag failures in legacy compatibility paths; device testing must confirm expected failure behavior without reintroducing unsafe rewrites.
- Foundation deletion fallback, WebKit recreation, complete-container compatibility recreation, and fixed-directory non-recursive ownership have static coverage but no device execution in this environment.
- The one accepted canonical strict-child `chflags -R` remains intentionally unchanged pending a separate device-backed decision.
- GitHub Actions and device validation may reveal platform-specific shell or filesystem behavior that static analysis cannot prove.

## 14. Final status

Implementation is limited to TASK-1.11, protected typed paths are byte-identical, required static gates pass, and no TASK-1.12 quarantine work is included.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
