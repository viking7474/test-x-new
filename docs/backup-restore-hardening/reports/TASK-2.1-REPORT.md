# TASK-2.1 Report — Standalone Backup Manifest Schema Validator

## 1. Scope and baseline

- Required baseline: `92b051fcc2e32193cf3e5b8837784e08b9ad1961`
- Observed baseline HEAD before editing: `92b051fcc2e32193cf3e5b8837784e08b9ad1961`
- TASK-1.12 review state supplied by the coordinator: `ACCEPTED`; Phase 1 complete.
- Work performed: TASK-2.1 only. TASK-2.2 and later policy/integration work was not started.

Initial `git status --short --untracked-files=all`:

```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-1.10-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.11-REVIEW.md
?? docs/backup-restore-hardening/reviews/TASK-1.12-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-1.11-remove-unsafe-permission-and-marker-behavior.md
?? docs/backup-restore-hardening/tasks/TASK-1.12-quarantine-ambiguous-legacy-clear-apis.md
?? docs/backup-restore-hardening/tasks/TASK-2.1-add-manifest-schema-validator.md
```

Initial `git log -3 --oneline`:

```text
92b051f phase1(task-1.12): quarantine ambiguous legacy clear APIs
17d76c0 phase1(task-1.11): remove unsafe permission and marker behavior
7b277bf TASK-1.10
```

Coordinator-owned modifications and untracked task/review documents were not rewritten, reverted, formatted or staged.

## 2. Exact file scope

Production files created:

```text
PXBackupManifestValidator.h
PXBackupManifestValidator.m
```

Report created:

```text
docs/backup-restore-hardening/reports/TASK-2.1-REPORT.md
```

No existing production file was modified. No existing source imports or references the validator. `Makefile` was not changed; its existing `$(wildcard *.m)` rule is present: `YES`.

## 3. Protected-file SHA-256 before/after

The initial capture and final pre-commit capture are identical. Protected working-tree diff exit code: `0`.

| Protected file | SHA-256 before | SHA-256 after | Result |
|---|---|---|---|
| `AppDataBackupManager.h` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | `21b2a8da95e155ff910cfef0f489211c02a58e1a2b7486da253871beadc82d03` | MATCH |
| `AppDataBackupManager.m` | `c40f4204d96d77211921320f8c43c889fe92d1714358ba37ca4713d2f43d6636` | `c40f4204d96d77211921320f8c43c889fe92d1714358ba37ca4713d2f43d6636` | MATCH |
| `AppDataCleaner.h` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | `b32a62280c2df60a33658e7ec9193b76802d989c984c42193f045a94365c915e` | MATCH |
| `AppDataCleaner.m` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | `69549666233bbbd812f16ba5abae9bfa875e5d85723a2a8f82d63b54332d4c93` | MATCH |
| `AppEntitlementsReader.h` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | `c3baaeee968e61283f2e6e76ad04855815db9e8872a1814cd449d177c692e94e` | MATCH |
| `AppEntitlementsReader.m` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | `0b53c3e24caaff5db6ceee2ae89e85ac8d4c7a7fa826cfbe814ef62c56448797` | MATCH |
| `PXResolvedContainer.h` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | `6ba935cb659ebdc5fdb8a96b13dd9f1450acb2e284267ac82e8890287a686718` | MATCH |
| `PXResolvedContainer.m` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | `a782089c0605f8d7803ffb53f746a585afb85f3ffbc9ed111f00575d77ada8fb` | MATCH |
| `PXDataContainerResolver.h` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | `b2e10dc045d49d9d09e0055973885b576f9909896dd8778339e65e0e812b8f30` | MATCH |
| `PXDataContainerResolver.m` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | `cc29adca6dc2fb30354541fdec9992b7cf7450d6cc0470c46864ecf456b4a365` | MATCH |
| `PXDestructivePathValidator.h` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | `542e158a4f04bf50125e0064fbebf02ac32f1de07508c3f32058e770f75a3c0a` | MATCH |
| `PXDestructivePathValidator.m` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | `f275a60be5cab58e5d06db3dd0987948f5eab65ddd7e35e35e45927d238877cb` | MATCH |
| `PXClearRequest.h` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | `d87402ee3720f1723977e4deb3d78bc1de87362948dfe585b5ed98f6447ae26b` | MATCH |
| `PXClearRequest.m` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | `afc763afc3306d422ef67ef3bd28a2a1a5741a64ea6078ee28f56f5d5901c790` | MATCH |
| `PXClearResult.h` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | `cedc6e364ebc4bf25acd8d128938db114033ca076750d2fade8e183488b2b592` | MATCH |
| `PXClearResult.m` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | `0e4bce039d6ca19f46590822bdfc938763cddc852be3045f6ada98e2fa0c5715` | MATCH |
| `CommandRunner.h` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | `63b88cf788fa8c981419f2c36f9375d1ed6e55190143c3c4e16b0972fe1d52bf` | MATCH |
| `CommandRunner.m` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | `2d5d68cd307ab150d85a28db69dd5a6169c40f78b3eb6fe49468bdaae2475030` | MATCH |
| `AppGroupContainerResolver.h` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | `c18f6e6dd09d19dd49564d442c956eb3be4a153118faff392cdd899846263c97` | MATCH |
| `AppGroupContainerResolver.m` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | `11646d96beec86f070ea49e0a803fb1bc669bc48af56135f1acd7c39a5439df1` | MATCH |
| `ProjectXViewController.m` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | `b7c5293dfa5d27fdc39c36f236f76306a855eaaf4e9e028f4c2111eb68146162` | MATCH |
| `KeychainGroupsViewController.m` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | `0e25b51199550964a5f743e50dc49641d161efd347973d49f58cc861a6260d35` | MATCH |
| `WeaponXKeychainBridge/Tweak.m` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | `e0733e04eb4915a4753fe59247b17acd5e8cb7f8fa5fcf0bb8dee94f908459aa` | MATCH |
| `KeychainHelper/backup_helper.m` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | `9f4e2c1cd0d7ebb7afef93d537e759858d60d2ae2ddd89b7b535ec611d437b83` | MATCH |
| `KeychainHelper/KeychainBackupHelper.h` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | `dbf0d5a4bdfc1df3e4f74b103968e018d0932f89c245bae8f260b196c0664281` | MATCH |
| `KeychainHelper/KeychainBackupHelper.m` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | `203884bf8d009a01a936acb5371c9316f7a0d6212b0d226f7f8a7661d51d122c` | MATCH |
| `Makefile` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` | `22fb8f6e6095132f1aa6facdb9c7a9995bf96db47005df31b82061c0a98c940f` | MATCH |

## 4. Public API and error contract

The header contains exactly one restricted class and one validator selector:

```objc
+ (BOOL)validateManifestObject:(nullable id)object
                         error:(NSError * _Nullable * _Nullable)error;
```

There is no instance state, property, convenience API, file/directory API, expected bundle argument, supported-version argument or normalized manifest output. `init` and `new` are unavailable.

Error constants:

```text
PXBackupManifestValidatorErrorDomain
PXBackupManifestValidatorErrorFieldPathKey
```

Exact error codes:

| Value | Code |
|---:|---|
| 1 | `PXBackupManifestValidatorErrorInvalidRoot` |
| 2 | `PXBackupManifestValidatorErrorMissingRequiredField` |
| 3 | `PXBackupManifestValidatorErrorInvalidFieldType` |
| 4 | `PXBackupManifestValidatorErrorInvalidFieldValue` |
| 5 | `PXBackupManifestValidatorErrorDuplicateEntry` |
| 6 | `PXBackupManifestValidatorErrorInconsistentField` |

`*error` is cleared at entry. Success returns `YES` with nil error. Failure returns `NO` and uses the fixed domain plus one exact enum code. The single NSError constructor supplies only `NSLocalizedDescriptionKey` and `PXBackupManifestValidatorErrorFieldPathKey`.

Descriptions are fixed literals and do not interpolate manifest values. Graph errors use `$`; field-specific errors use fixed schema field names and ascending array indices. No manifest path, UUID, bundle identifier, archive, checksum, object excerpt or nested error is placed in `userInfo`.

## 5. Property-list graph safety

The complete reachable graph is checked before schema fields:

- containers: runtime `NSDictionary` and `NSArray`;
- leaves: runtime `NSString`, `NSNumber`, `NSDate`, `NSData`;
- unsupported leaves and non-string keys: `InvalidFieldType`;
- invalid string keys, cycles and graph limits: `InvalidFieldValue`;
- maximum container depth: 32, inclusive;
- maximum entries in one array/dictionary: 10000, inclusive;
- maximum aggregate visited values/keys: 100000, inclusive.

Cycle detection uses `NSHashTableObjectPointerPersonality` for the active recursion stack. A container is removed after its branch completes, so shared acyclic subobjects remain valid. Dictionary keys are first type-checked, then sorted with `compare:` before child traversal. Graph errors never expose unknown key text.

No `NSPropertyListSerialization`, serialization, copying or normalization is used.

## 6. Primitive rules

- Required strings: NSString, length > 0, at least one non-whitespace/newline character, no U+0000.
- Empty-permitted strings: NSString and no U+0000.
- Booleans: exact CFBoolean-backed NSNumber only.
- Integral values: NSNumber, not CFBoolean, one integral Objective-C numeric type code; float/double/decimal representations are rejected.
- Nonnegative size/count values accept zero.
- manifestVersion additionally requires value > 0 and value <= NSIntegerMax.

No string is trimmed, lowercased, normalized or rewritten.

## 7. Deterministic schema validation order

After graph safety:

1. required root presence in exact order: manifestVersion, bundleID, appName, timestamp, iosVersion, profileId, data, applicationGroups, appGroups, preferences, keychain, profileAppData, globalSafari, artifacts, options;
2. primitive root values;
3. data;
4. applicationGroups by ascending index;
5. appGroups by ascending index;
6. preferences;
7. keychain;
8. profileAppData;
9. globalSafari;
10. artifacts by ascending index;
11. options;
12. createdAt, toolVersion, toolBuild, backupMode, sourceDataContainerPath, sourceDataContainerUUID, includedOptions, excludedOptions, artifactCount, totalSize, archiveChecksum, warnings;
13. restoreCompatibility;
14. systemGlobalLibrary;
15. sharedSystemDB.

Duplicate checks run while processing ascending array indices and therefore report the later exact duplicate occurrence.

## 8. Complete schema

### Required root

| Field | Rule |
|---|---|
| manifestVersion | positive integral NSNumber, not CFBoolean, fits NSInteger; no supported-version policy |
| bundleID | required nonempty string |
| appName | empty-permitted string |
| timestamp | required nonempty string |
| iosVersion | empty-permitted string |
| profileId | empty-permitted string |
| data | dictionary |
| applicationGroups | array |
| appGroups | array |
| preferences | dictionary |
| keychain | dictionary |
| profileAppData | dictionary |
| globalSafari | dictionary |
| artifacts | array |
| options | dictionary |

### Nested sections

| Section | Required/optional fields and rules |
|---|---|
| data | uuid, archive, containerPath: required nonempty strings |
| applicationGroups | duplicate-free array of required nonempty strings; empty valid |
| appGroups | entries require groupID/uuid/archive; duplicate groupID/archive rejected; duplicate UUID allowed |
| preferences | included exact Boolean; archive required nonempty even when false |
| keychain | included exact Boolean; archive empty-permitted; groupsSelected duplicate-free nonempty strings; optional method empty-permitted |
| profileAppData/globalSafari | included exact Boolean; archive/path empty-permitted |
| artifacts | entries require nonempty name/path, nonnegative integral size, empty-permitted sha256; duplicate name/path rejected |
| options | includeAppGroups/includePreferences/includeKeychain exact Booleans |
| optional v3 metadata | exact rules for createdAt, tool strings, backupMode, source metadata, option arrays, artifactCount, totalSize, checksum and warnings |
| restoreCompatibility | targetBundleID, two exact Booleans, notes array; target exactly equals root bundleID |
| systemGlobalLibrary | included plus item dictionaries containing subdir/archive |
| sharedSystemDB | included plus file dictionaries containing libraryRel/archive |

Unknown root and nested dictionary keys are allowed after graph safety. No option vocabulary, UUID syntax, SHA syntax, path syntax, archive reference or future-version key set is restricted by TASK-2.1.

## 9. Duplicate and consistency policy

Exact duplicates rejected:

- applicationGroups string;
- appGroups groupID and archive;
- keychain groupsSelected;
- artifact name and path;
- includedOptions and excludedOptions internally;
- systemGlobalLibrary subdir and archive;
- sharedSystemDB libraryRel and archive.

Cross-field consistency:

- keychain included YES requires nonempty archive;
- profileAppData/globalSafari included YES requires nonempty archive and path;
- includedOptions and excludedOptions are disjoint;
- artifactCount equals artifacts.count;
- restoreCompatibility.targetBundleID exactly equals root bundleID;
- systemGlobalLibrary included YES requires items, included NO requires zero items;
- sharedSystemDB included YES requires files, included NO requires zero files.

Not enforced: duplicate appGroups UUID, warning/note duplicates, totalSize sum, checksum validity, option request versus produced-section equality.

## 10. Deliberately deferred policies

### Manifest versions

The implementation contains no supported/minimum/maximum manifest-version constant and no whitelist comparison. The only version predicate is positive integral plus NSInteger range. Therefore otherwise valid manifests using versions `1`, `2`, `3` and `999` are not rejected solely because of version value. Restore acceptance remains TASK-2.2.

### Requested bundle identity

The public API has no expected/requested bundle argument. Root bundleID is validated only as structural text. The restoreCompatibility comparison is internal manifest consistency, not comparison with a restore request. Requested target equality remains TASK-2.3.

### Paths, artifacts and archives

No filesystem, destination authorization, path canonicalization, file existence, file size, checksum hashing, archive-entry inspection or artifact cross-reference is performed. Those remain later tasks.

## 11. Pure-Foundation and caller-isolation evidence

`PXBackupManifestValidator.m` imports exactly:

```objc
#import "PXBackupManifestValidator.h"
```

Existing production references outside the new files: `0`. AppDataBackupManager, AppDataCleaner, Restore, Backup writer, listing, UI and Makefile were not integrated or modified.

Forbidden-token audit:

| Token | Count |
|---|---:|
| `NSFileManager` | 0 |
| `NSURL` | 0 |
| `dataWithContentsOfFile` | 0 |
| `dictionaryWithContentsOfFile` | 0 |
| `NSPropertyListSerialization` | 0 |
| `CommandRunner` | 0 |
| `NSTask` | 0 |
| `posix_spawn` | 0 |
| `system(` | 0 |
| `exec` | 0 |
| `fork` | 0 |
| `wait` | 0 |
| `shell` | 0 |
| `rm` | 0 |
| `find` | 0 |
| `sqlite3` | 0 |
| `Security` | 0 |
| `SecItem` | 0 |
| `UIKit` | 0 |
| `UIApplication` | 0 |
| `NSUserDefaults` | 0 |
| `NSNotificationCenter` | 0 |
| `dispatch_async` | 0 |
| `dispatch_sync` | 0 |
| `dispatch_semaphore` | 0 |
| `sleep` | 0 |
| `usleep` | 0 |
| `AppDataBackupManager` | 0 |
| `AppDataCleaner` | 0 |
| `PXDataContainerResolver` | 0 |
| `AppGroupContainerResolver` | 0 |
| `PXDestructivePathValidator` | 0 |
| `PXClearRequest` | 0 |
| `PXClearResult` | 0 |

No manifest logging, global mutable state, result cache, intentional exception, environment/default read or file creation exists.

## 12. Declaration and implementation gates

| Gate | Result |
|---|---|
| PXBackupManifestValidator interface declarations | 1 |
| validateManifestObject:error: declarations | 1 |
| validateManifestObject:error: implementations | 1 |
| error domain definitions | 1 |
| field-path key definitions | 1 |
| error enum cases | exactly 6 |
| instance mutable properties | 0 |
| existing production references | 0 |
| Makefile diff | 0 |
| machine-readable static gates | 101/101 PASS |

Source hashes:

- PXBackupManifestValidator.h: `6bf479c032e044a89a9d028517a50692c7d95ccef35f78e92a782653a4dcc836`
- PXBackupManifestValidator.m: `0cae70bbceb8f433c9fe68b2c6ee91f98c9ac59dac0ef8e15e10d5f467f525ea`

## 13. Scenario matrix

These are static contract cases reviewed against explicit branches and source gates. No row claims an Objective-C runtime, device or Restore integration execution.

| # | Scenario | Expected | Error/result | Static evidence |
|---:|---|---|---|---|
| 1 | nil root | FAIL | InvalidRoot at `$` | Public entry rejects every non-dictionary root before graph traversal. |
| 2 | string root | FAIL | InvalidRoot at `$` | Same root-class guard. |
| 3 | array root | FAIL | InvalidRoot at `$` | Same root-class guard. |
| 4 | empty dictionary | FAIL | MissingRequiredField at `$.manifestVersion` | Required-root array begins with `manifestVersion`. |
| 5 | non-string dictionary key | FAIL | InvalidFieldType at `$` | Graph pass checks every key class before sorting. |
| 6 | empty dictionary key | FAIL | InvalidFieldValue at `$` | Graph key-value rule rejects zero length. |
| 7 | NUL-containing dictionary key | FAIL | InvalidFieldValue at `$` | Graph key-value rule scans UTF-16 units for U+0000. |
| 8 | NSNull unknown value | FAIL | InvalidFieldType at `$` | Accepted graph leaves are only NSString/NSNumber/NSDate/NSData. |
| 9 | custom-object unknown value | FAIL | InvalidFieldType at `$` | Unsupported leaf branch is fail-closed. |
| 10 | valid unknown property-list metadata | PASS | No schema error | Unknown keys are not enumerated by field policy after graph safety. |
| 11 | cyclic array | FAIL | InvalidFieldValue at `$` | Active pointer-identity stack detects an ancestor container. |
| 12 | cyclic dictionary | FAIL | InvalidFieldValue at `$` | Same active-stack rule. |
| 13 | depth exactly 32 | PASS | No graph-depth error | Container depth fails only when greater than 32. |
| 14 | depth greater than 32 | FAIL | InvalidFieldValue at `$` | Explicit `containerDepth > 32` gate. |
| 15 | one container exactly 10000 entries | PASS | No entry-count error | Gate fails only when count is greater than 10000. |
| 16 | one container over 10000 entries | FAIL | InvalidFieldValue at `$` | Explicit maximum-entry gate. |
| 17 | total visited values/keys exactly 100000 | PASS | No visited-limit error | Consumption allows equality with the maximum. |
| 18 | total visited values/keys over 100000 | FAIL | InvalidFieldValue at `$` | Overflow-safe remaining-budget comparison. |
| 19 | missing manifestVersion | FAIL | MissingRequiredField at `$.manifestVersion` | First required root key. |
| 20 | manifestVersion 0 | FAIL | InvalidFieldValue at `$.manifestVersion` | Positive-version helper rejects zero. |
| 21 | negative manifestVersion | FAIL | InvalidFieldValue at `$.manifestVersion` | Signed integral extraction rejects negatives. |
| 22 | Boolean manifestVersion | FAIL | InvalidFieldType at `$.manifestVersion` | CFBoolean is explicitly excluded from integral fields. |
| 23 | floating manifestVersion | FAIL | InvalidFieldType at `$.manifestVersion` | Only integral Objective-C type codes enter the switch. |
| 24 | string manifestVersion | FAIL | InvalidFieldType at `$.manifestVersion` | NSNumber runtime class required. |
| 25 | structurally valid manifestVersion 1 | PASS | No version-value policy error | Any positive integral value fitting NSInteger is accepted. |
| 26 | structurally valid manifestVersion 2 | PASS | No version-value policy error | No whitelist or supported-version constants exist. |
| 27 | structurally valid manifestVersion 3 | PASS | No version-value policy error | No whitelist or supported-version constants exist. |
| 28 | structurally valid manifestVersion 999 | PASS | No version-value policy error | No whitelist or supported-version constants exist. |
| 29 | missing bundleID | FAIL | MissingRequiredField at `$.bundleID` | Second required root key. |
| 30 | whitespace-only bundleID | FAIL | InvalidFieldValue at `$.bundleID` | Required-string helper requires non-whitespace text. |
| 31 | NUL bundleID | FAIL | InvalidFieldValue at `$.bundleID` | Required-string helper rejects U+0000. |
| 32 | Unicode bundleID | PASS | No syntax-policy error | No ASCII whitelist or normalization exists. |
| 33 | underscore-containing bundleID | PASS | No syntax-policy error | Only nonempty/non-whitespace/NUL-free shape is enforced. |
| 34 | no requested bundle comparison API | PASS | Static API boundary | The sole API accepts only object and NSError pointer. |
| 35 | missing appName | FAIL | MissingRequiredField at `$.appName` | Required root order is explicit. |
| 36 | missing timestamp | FAIL | MissingRequiredField at `$.timestamp` | Required root order is explicit. |
| 37 | missing data | FAIL | MissingRequiredField at `$.data` | Required root order is explicit. |
| 38 | missing applicationGroups | FAIL | MissingRequiredField at `$.applicationGroups` | Required root order is explicit. |
| 39 | missing appGroups | FAIL | MissingRequiredField at `$.appGroups` | Required root order is explicit. |
| 40 | missing preferences | FAIL | MissingRequiredField at `$.preferences` | Required root order is explicit. |
| 41 | missing keychain | FAIL | MissingRequiredField at `$.keychain` | Required root order is explicit. |
| 42 | missing profileAppData | FAIL | MissingRequiredField at `$.profileAppData` | Required root order is explicit. |
| 43 | missing globalSafari | FAIL | MissingRequiredField at `$.globalSafari` | Required root order is explicit. |
| 44 | missing artifacts | FAIL | MissingRequiredField at `$.artifacts` | Required root order is explicit. |
| 45 | missing options | FAIL | MissingRequiredField at `$.options` | Required root order is explicit. |
| 46 | numeric substitute for Boolean | FAIL | InvalidFieldType at the Boolean field | Exact CFBoolean type ID is required. |
| 47 | real CFBoolean | PASS | No Boolean-type error | CFBoolean-backed NSNumber is accepted. |
| 48 | floating artifact size | FAIL | InvalidFieldType at `$.artifacts[i].size` | Float/double/decimal type codes are not accepted. |
| 49 | negative artifact size | FAIL | InvalidFieldValue at `$.artifacts[i].size` | Signed negative integral value is rejected. |
| 50 | zero artifact size | PASS | No size-value error | Nonnegative integral helper accepts zero. |
| 51 | empty-permitted metadata string | PASS | No string-value error | Optional-string helper allows empty text when NUL-free. |
| 52 | NUL in empty-permitted string | FAIL | InvalidFieldValue at field path | Optional-string helper rejects U+0000. |
| 53 | valid data section | PASS | No data error | Dictionary with nonempty uuid/archive/containerPath satisfies the section. |
| 54 | missing data archive | FAIL | MissingRequiredField at `$.data.archive` | Nested required-key order is uuid/archive/containerPath. |
| 55 | empty data containerPath | FAIL | InvalidFieldValue at `$.data.containerPath` | All three data values use required-string helper. |
| 56 | empty applicationGroups | PASS | No group-array error | Empty array is accepted. |
| 57 | duplicate application group | FAIL | DuplicateEntry at later index | Exact set membership is checked in ascending index order. |
| 58 | non-string application group | FAIL | InvalidFieldType at indexed path | Every item uses required-string helper. |
| 59 | valid appGroups entry | PASS | No appGroups error | groupID/uuid/archive are nonempty strings. |
| 60 | duplicate appGroups groupID | FAIL | DuplicateEntry at later `groupID` | Exact group identifier set. |
| 61 | duplicate appGroups archive | FAIL | DuplicateEntry at later `archive` | Exact archive set. |
| 62 | duplicate appGroups UUID | PASS | No UUID-duplicate error | No UUID set exists in the validator. |
| 63 | preferences included false with nonempty archive | PASS | No consistency error | Archive remains required regardless of included flag. |
| 64 | keychain included false with empty archive | PASS | No consistency error | Empty archive is allowed when excluded. |
| 65 | keychain included true with empty archive | FAIL | InconsistentField at `$.keychain.archive` | Included section requires non-whitespace archive. |
| 66 | duplicate Keychain selected group | FAIL | DuplicateEntry at later group index | Duplicate-free string-array helper. |
| 67 | profileAppData included true with empty path | FAIL | InconsistentField at `$.profileAppData.path` | Included optional-archive section requires path. |
| 68 | globalSafari included false with empty fields | PASS | No consistency error | Excluded section may record empty archive/path. |
| 69 | empty artifact array | PASS | No artifact-presence policy error | TASK-2.1 accepts zero artifacts. |
| 70 | duplicate artifact name | FAIL | DuplicateEntry at later `name` | Exact name set. |
| 71 | duplicate artifact path | FAIL | DuplicateEntry at later `path` | Exact path set. |
| 72 | empty artifact sha256 | PASS | No checksum-shape error | sha256 uses empty-permitted string helper. |
| 73 | malformed artifact sha256 string | PASS | No checksum-syntax error | No length/hex policy exists. |
| 74 | options numeric Boolean | FAIL | InvalidFieldType at option path | Each required option uses exact Boolean helper. |
| 75 | artifactCount mismatch | FAIL | InconsistentField at `$.artifactCount` | Declared count is compared with artifacts.count. |
| 76 | includedOptions/excludedOptions overlap | FAIL | InconsistentField at later excluded index | Excluded array is scanned in ascending order against included set. |
| 77 | optional createdAt wrong type | FAIL | InvalidFieldType at `$.createdAt` | NSDate runtime class is required when present. |
| 78 | restoreCompatibility target differs from root | FAIL | InconsistentField at targetBundleID | Internal exact equality is enforced. |
| 79 | systemGlobalLibrary included true with empty items | FAIL | InconsistentField at items | Included flag requires nonempty items. |
| 80 | systemGlobalLibrary included false with nonempty items | FAIL | InconsistentField at items | Excluded flag requires zero items. |
| 81 | duplicate system-global subdir | FAIL | DuplicateEntry at later subdir | Exact subdirectory set. |
| 82 | sharedSystemDB included true with empty files | FAIL | InconsistentField at files | Included flag requires nonempty files. |
| 83 | duplicate shared DB archive | FAIL | DuplicateEntry at later archive | Exact archive set. |
| 84 | unknown keys allowed | PASS | No unknown-key schema error | Complete graph is checked, but known schema does not reject extras. |
| 85 | input dictionary remains unmodified | PASS | Static purity property | No input setter/removal API is used; mutable sets are local indexes only. |
| 86 | error cleared on success | PASS | `*error = nil` | Cleared at method entry and never assigned on successful return. |
| 87 | error cleared then replaced on failure | PASS | One contract NSError | Entry clear precedes all failure helper calls. |
| 88 | error userInfo contains only two allowed keys | PASS | Description and field path only | Single error constructor has exactly two dictionary entries. |
| 89 | no raw value in error text/userInfo | PASS | Static privacy property | Descriptions are fixed literals; paths use schema names/indices or `$`. |
| 90 | no filesystem access | PASS | Static boundary | All filesystem tokens are zero. |
| 91 | no artifact hashing | PASS | Static boundary | No hashing or artifact-content API exists. |
| 92 | no archive inspection | PASS | Static boundary | Archive values are validated as strings only. |
| 93 | no version support enforcement | PASS | Static boundary | Only positive integral and NSInteger-range policy exists. |
| 94 | no requested bundle matching | PASS | Static boundary | No expected/requested bundle parameter or caller data exists. |
| 95 | no Restore caller integration | PASS | Static boundary | Existing production reference inventory is empty. |
| 96 | no Backup writer integration | PASS | Static boundary | Existing production reference inventory is empty. |
| 97 | no Makefile change | PASS | Protected diff | Makefile diff is zero; wildcard compilation was already present. |
| 98 | no existing production references | PASS | Reference count 0 | Tracked production source scan excludes only the two new files. |
| 99 | git diff --check | PASS | Exit 0 | Source and complete working diff checks pass. |
| 100 | no NUL/generated/binary artifacts | PASS | Static artifact audit | New sources/report are UTF-8 text; temporary audit files are removed before commit. |
| 101 | shared acyclic subobject referenced twice | PASS | No cycle error | Container is removed from active stack after each completed branch. |
| 102 | empty appName | PASS | No string-value error | appName uses empty-permitted helper. |
| 103 | empty iosVersion | PASS | No string-value error | iosVersion uses empty-permitted helper. |
| 104 | empty profileId | PASS | No string-value error | profileId uses empty-permitted helper. |
| 105 | preferences included false with empty archive | FAIL | InvalidFieldValue at preferences archive | Preferences archive is always required nonempty. |
| 106 | empty optional keychain method | PASS | No method-value error | method is empty-permitted when present. |
| 107 | duplicate system-global archive | FAIL | DuplicateEntry at later archive | Exact archive set. |
| 108 | duplicate shared DB libraryRel | FAIL | DuplicateEntry at later libraryRel | Exact relative-location set. |
| 109 | sharedSystemDB included false with nonempty files | FAIL | InconsistentField at files | Excluded flag requires zero files. |
| 110 | totalSize differs from artifact sum | PASS | No sum-consistency policy | totalSize is only a nonnegative integral shape. |
| 111 | arbitrary archiveChecksum text | PASS | No checksum-verification policy | archiveChecksum is empty-permitted string only. |
| 112 | option request differs from produced sections | PASS | No cross-section option equality | Options are type-checked only. |
| 113 | traversal-looking recorded path | PASS | No path-authorization policy | Recorded paths are structural strings at this task. |
| 114 | absolute recorded path | PASS | No absolute-path rejection | No path canonicalization or authorization exists. |
| 115 | duplicate warnings | PASS | No duplicate warning policy | warnings uses non-deduplicating string-array validation. |
| 116 | duplicate restore notes | PASS | No duplicate note policy | notes uses non-deduplicating string-array validation. |
| 117 | duplicate includedOptions entry | FAIL | DuplicateEntry at later index | includedOptions uses duplicate-free array helper. |
| 118 | duplicate excludedOptions entry | FAIL | DuplicateEntry at later index | excludedOptions uses duplicate-free array helper. |
| 119 | non-dictionary appGroups entry | FAIL | InvalidFieldType at indexed entry | Entry runtime dictionary check precedes field validation. |
| 120 | non-dictionary artifact entry | FAIL | InvalidFieldType at indexed entry | Entry runtime dictionary check precedes field validation. |

Scenario count: **120** (required minimum: 100).

## 14. Whitespace, encoding and artifact audit

| File | Lines | NUL | Trailing whitespace | Line endings |
|---|---:|---:|---:|---|
| `PXBackupManifestValidator.h` | 31 | 0 | 0 | LF |
| `PXBackupManifestValidator.m` | 1117 | 0 | 0 | LF |

`git diff --check` passed. New production files are UTF-8 text, not binary/generated output. Temporary `.task21*` audit scripts/data are excluded from the implementation commit and removed before commit.

## 15. Build status and remaining risks

Local tool discovery on this Windows workspace:

```text
clang=NOT_FOUND
clang-cl=NOT_FOUND
make=NOT_FOUND
xcrun=NOT_FOUND
```

Therefore no local Objective-C/Foundation or Theos build was run. GitHub Actions remains the build owner. Static delimiter, API, schema, forbidden-token, protected-diff and whitespace checks passed. Remaining risks are compiler/platform validation, actual Foundation class-cluster behavior on target iOS versions, large/cyclic mutable graph runtime tests and later caller integration. Input mutation concurrent with validation is outside this standalone contract and was not device-tested.

## 16. Source diff

Source stat:

```text
 PXBackupManifestValidator.h |   31 ++
 PXBackupManifestValidator.m | 1117 +++++++++++++++++++++++++++++++++++++++++++
 2 files changed, 1148 insertions(+)
```

Full focused source diff:

```diff
diff --git a/PXBackupManifestValidator.h b/PXBackupManifestValidator.h
new file mode 100644
index 0000000..0818736
--- /dev/null
+++ b/PXBackupManifestValidator.h
@@ -0,0 +1,31 @@
+#import <Foundation/Foundation.h>
+
+NS_ASSUME_NONNULL_BEGIN
+
+FOUNDATION_EXPORT NSString * const
+    PXBackupManifestValidatorErrorDomain;
+
+FOUNDATION_EXPORT NSString * const
+    PXBackupManifestValidatorErrorFieldPathKey;
+
+typedef NS_ENUM(NSInteger, PXBackupManifestValidatorErrorCode) {
+    PXBackupManifestValidatorErrorInvalidRoot = 1,
+    PXBackupManifestValidatorErrorMissingRequiredField = 2,
+    PXBackupManifestValidatorErrorInvalidFieldType = 3,
+    PXBackupManifestValidatorErrorInvalidFieldValue = 4,
+    PXBackupManifestValidatorErrorDuplicateEntry = 5,
+    PXBackupManifestValidatorErrorInconsistentField = 6,
+};
+
+__attribute__((objc_subclassing_restricted))
+@interface PXBackupManifestValidator : NSObject
+
++ (BOOL)validateManifestObject:(nullable id)object
+                         error:(NSError * _Nullable * _Nullable)error;
+
+- (instancetype)init NS_UNAVAILABLE;
++ (instancetype)new NS_UNAVAILABLE;
+
+@end
+
+NS_ASSUME_NONNULL_END
diff --git a/PXBackupManifestValidator.m b/PXBackupManifestValidator.m
new file mode 100644
index 0000000..7bc29a9
--- /dev/null
+++ b/PXBackupManifestValidator.m
@@ -0,0 +1,1117 @@
+#import "PXBackupManifestValidator.h"
+
+NSString * const PXBackupManifestValidatorErrorDomain =
+    @"PXBackupManifestValidatorErrorDomain";
+
+NSString * const PXBackupManifestValidatorErrorFieldPathKey =
+    @"PXBackupManifestValidatorErrorFieldPath";
+
+static const NSUInteger PXBackupManifestMaximumContainerDepth = 32;
+static const NSUInteger PXBackupManifestMaximumVisitedObjects = 100000;
+static const NSUInteger PXBackupManifestMaximumContainerEntries = 10000;
+
+static BOOL PXManifestFail(NSError **error,
+                           PXBackupManifestValidatorErrorCode code,
+                           NSString *fieldPath,
+                           NSString *description) {
+    if (error) {
+        *error = [NSError errorWithDomain:PXBackupManifestValidatorErrorDomain
+                                     code:code
+                                 userInfo:@{
+            NSLocalizedDescriptionKey: description,
+            PXBackupManifestValidatorErrorFieldPathKey: fieldPath
+        }];
+    }
+    return NO;
+}
+
+static NSString *PXManifestFieldPath(NSString *parent, NSString *field) {
+    return [[parent stringByAppendingString:@"."] stringByAppendingString:field];
+}
+
+static NSString *PXManifestIndexedPath(NSString *parent, NSUInteger index) {
+    NSString *indexText = [@(index) stringValue];
+    NSString *prefix = [parent stringByAppendingString:@"["];
+    return [[prefix stringByAppendingString:indexText] stringByAppendingString:@"]"];
+}
+
+static BOOL PXManifestStringContainsNUL(NSString *value) {
+    for (NSUInteger index = 0; index < value.length; index++) {
+        if ([value characterAtIndex:index] == 0) {
+            return YES;
+        }
+    }
+    return NO;
+}
+
+static BOOL PXManifestStringHasNonWhitespace(NSString *value) {
+    NSCharacterSet *nonWhitespace =
+        [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
+    return [value rangeOfCharacterFromSet:nonWhitespace].location != NSNotFound;
+}
+
+static BOOL PXManifestValidateRequiredString(id value,
+                                             NSString *fieldPath,
+                                             NSError **error) {
+    if (![value isKindOfClass:[NSString class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              fieldPath,
+                              @"The field must be a string.");
+    }
+
+    NSString *stringValue = (NSString *)value;
+    if (stringValue.length == 0 ||
+        !PXManifestStringHasNonWhitespace(stringValue) ||
+        PXManifestStringContainsNUL(stringValue)) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldValue,
+                              fieldPath,
+                              @"The field must be nonempty, contain non-whitespace text, and contain no NUL character.");
+    }
+
+    return YES;
+}
+
+static BOOL PXManifestValidateOptionalString(id value,
+                                             NSString *fieldPath,
+                                             NSError **error) {
+    if (![value isKindOfClass:[NSString class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              fieldPath,
+                              @"The field must be a string.");
+    }
+
+    if (PXManifestStringContainsNUL((NSString *)value)) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldValue,
+                              fieldPath,
+                              @"The field must contain no NUL character.");
+    }
+
+    return YES;
+}
+
+static BOOL PXManifestIsExactBoolean(id value) {
+    if (![value isKindOfClass:[NSNumber class]]) {
+        return NO;
+    }
+    return CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
+}
+
+static BOOL PXManifestValidateBoolean(id value,
+                                      NSString *fieldPath,
+                                      NSError **error) {
+    if (!PXManifestIsExactBoolean(value)) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              fieldPath,
+                              @"The field must be an exact Boolean value.");
+    }
+    return YES;
+}
+
+static BOOL PXManifestExtractIntegralNumber(id value,
+                                            NSString *fieldPath,
+                                            unsigned long long *magnitude,
+                                            NSError **error) {
+    if (![value isKindOfClass:[NSNumber class]] || PXManifestIsExactBoolean(value)) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              fieldPath,
+                              @"The field must be a non-Boolean integral number.");
+    }
+
+    NSNumber *number = (NSNumber *)value;
+    const char *type = number.objCType;
+    if (!type || type[0] == '\0' || type[1] != '\0') {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              fieldPath,
+                              @"The field must use an integral Objective-C numeric type.");
+    }
+
+    switch (type[0]) {
+        case 'c':
+        case 's':
+        case 'i':
+        case 'l':
+        case 'q': {
+            long long signedValue = number.longLongValue;
+            if (signedValue < 0) {
+                return PXManifestFail(error,
+                                      PXBackupManifestValidatorErrorInvalidFieldValue,
+                                      fieldPath,
+                                      @"The field must not be negative.");
+            }
+            if (magnitude) {
+                *magnitude = (unsigned long long)signedValue;
+            }
+            return YES;
+        }
+        case 'C':
+        case 'S':
+        case 'I':
+        case 'L':
+        case 'Q':
+            if (magnitude) {
+                *magnitude = number.unsignedLongLongValue;
+            }
+            return YES;
+        default:
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorInvalidFieldType,
+                                  fieldPath,
+                                  @"The field must use an integral Objective-C numeric type.");
+    }
+}
+
+static BOOL PXManifestValidatePositiveVersion(id value,
+                                              NSString *fieldPath,
+                                              NSError **error) {
+    unsigned long long magnitude = 0;
+    if (!PXManifestExtractIntegralNumber(value, fieldPath, &magnitude, error)) {
+        return NO;
+    }
+    if (magnitude == 0 || magnitude > (unsigned long long)NSIntegerMax) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldValue,
+                              fieldPath,
+                              @"The manifest version must be positive and fit within NSInteger.");
+    }
+    return YES;
+}
+
+static BOOL PXManifestValidateNonnegativeIntegral(id value,
+                                                  NSString *fieldPath,
+                                                  unsigned long long *magnitude,
+                                                  NSError **error) {
+    return PXManifestExtractIntegralNumber(value, fieldPath, magnitude, error);
+}
+
+static BOOL PXManifestConsumeVisited(NSUInteger amount,
+                                     NSUInteger *visited,
+                                     NSError **error) {
+    if (amount > PXBackupManifestMaximumVisitedObjects - *visited) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldValue,
+                              @"$",
+                              @"The manifest graph exceeds the visited-object limit.");
+    }
+    *visited += amount;
+    return YES;
+}
+
+static BOOL PXManifestValidateGraphObject(id object,
+                                          NSUInteger containerDepth,
+                                          NSUInteger *visited,
+                                          NSHashTable *activeContainers,
+                                          NSError **error) {
+    if (!PXManifestConsumeVisited(1, visited, error)) {
+        return NO;
+    }
+
+    BOOL isDictionary = [object isKindOfClass:[NSDictionary class]];
+    BOOL isArray = [object isKindOfClass:[NSArray class]];
+
+    if (!isDictionary && !isArray) {
+        if ([object isKindOfClass:[NSString class]] ||
+            [object isKindOfClass:[NSNumber class]] ||
+            [object isKindOfClass:[NSDate class]] ||
+            [object isKindOfClass:[NSData class]]) {
+            return YES;
+        }
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              @"$",
+                              @"The manifest graph contains an unsupported value type.");
+    }
+
+    if (containerDepth > PXBackupManifestMaximumContainerDepth) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldValue,
+                              @"$",
+                              @"The manifest graph exceeds the container-depth limit.");
+    }
+
+    NSUInteger entryCount = isDictionary
+        ? ((NSDictionary *)object).count
+        : ((NSArray *)object).count;
+    if (entryCount > PXBackupManifestMaximumContainerEntries) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldValue,
+                              @"$",
+                              @"A manifest container exceeds the entry-count limit.");
+    }
+
+    if ([activeContainers containsObject:object]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldValue,
+                              @"$",
+                              @"The manifest graph contains a container cycle.");
+    }
+
+    [activeContainers addObject:object];
+
+    if (isArray) {
+        NSArray *array = (NSArray *)object;
+        for (id value in array) {
+            if (!PXManifestValidateGraphObject(value,
+                                               containerDepth + 1,
+                                               visited,
+                                               activeContainers,
+                                               error)) {
+                [activeContainers removeObject:object];
+                return NO;
+            }
+        }
+        [activeContainers removeObject:object];
+        return YES;
+    }
+
+    NSDictionary *dictionary = (NSDictionary *)object;
+    NSArray *allKeys = dictionary.allKeys;
+    if (!PXManifestConsumeVisited(allKeys.count, visited, error)) {
+        [activeContainers removeObject:object];
+        return NO;
+    }
+
+    for (id key in allKeys) {
+        if (![key isKindOfClass:[NSString class]]) {
+            [activeContainers removeObject:object];
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorInvalidFieldType,
+                                  @"$",
+                                  @"Every manifest dictionary key must be a string.");
+        }
+    }
+
+    NSArray<NSString *> *sortedKeys =
+        [(NSArray<NSString *> *)allKeys sortedArrayUsingSelector:@selector(compare:)];
+    for (NSString *key in sortedKeys) {
+        if (key.length == 0 ||
+            !PXManifestStringHasNonWhitespace(key) ||
+            PXManifestStringContainsNUL(key)) {
+            [activeContainers removeObject:object];
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorInvalidFieldValue,
+                                  @"$",
+                                  @"Every manifest dictionary key must be nonempty, contain non-whitespace text, and contain no NUL character.");
+        }
+
+        id value = [dictionary objectForKey:key];
+        if (!PXManifestValidateGraphObject(value,
+                                           containerDepth + 1,
+                                           visited,
+                                           activeContainers,
+                                           error)) {
+            [activeContainers removeObject:object];
+            return NO;
+        }
+    }
+
+    [activeContainers removeObject:object];
+    return YES;
+}
+
+static BOOL PXManifestRequireKeys(NSDictionary *dictionary,
+                                  NSArray<NSString *> *keys,
+                                  NSString *parentPath,
+                                  NSError **error) {
+    for (NSString *key in keys) {
+        if ([dictionary objectForKey:key] == nil) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorMissingRequiredField,
+                                  PXManifestFieldPath(parentPath, key),
+                                  @"A required manifest field is missing.");
+        }
+    }
+    return YES;
+}
+
+static BOOL PXManifestValidateStringArray(id value,
+                                          NSString *fieldPath,
+                                          BOOL rejectDuplicates,
+                                          NSSet<NSString *> **validatedSet,
+                                          NSError **error) {
+    if (![value isKindOfClass:[NSArray class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              fieldPath,
+                              @"The field must be an array.");
+    }
+
+    NSArray *array = (NSArray *)value;
+    NSMutableSet<NSString *> *seen = [NSMutableSet set];
+    for (NSUInteger index = 0; index < array.count; index++) {
+        NSString *itemPath = PXManifestIndexedPath(fieldPath, index);
+        id item = array[index];
+        if (!PXManifestValidateRequiredString(item, itemPath, error)) {
+            return NO;
+        }
+
+        NSString *stringItem = (NSString *)item;
+        if (rejectDuplicates && [seen containsObject:stringItem]) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorDuplicateEntry,
+                                  itemPath,
+                                  @"The array contains an exact duplicate entry.");
+        }
+        [seen addObject:stringItem];
+    }
+
+    if (validatedSet) {
+        *validatedSet = [seen copy];
+    }
+    return YES;
+}
+
+static BOOL PXManifestValidateDataSection(id value, NSError **error) {
+    NSString *sectionPath = @"$.data";
+    if (![value isKindOfClass:[NSDictionary class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              sectionPath,
+                              @"The data section must be a dictionary.");
+    }
+
+    NSDictionary *section = (NSDictionary *)value;
+    if (!PXManifestRequireKeys(section,
+                               @[@"uuid", @"archive", @"containerPath"],
+                               sectionPath,
+                               error)) {
+        return NO;
+    }
+
+    return PXManifestValidateRequiredString(section[@"uuid"], @"$.data.uuid", error) &&
+           PXManifestValidateRequiredString(section[@"archive"], @"$.data.archive", error) &&
+           PXManifestValidateRequiredString(section[@"containerPath"], @"$.data.containerPath", error);
+}
+
+static BOOL PXManifestValidateApplicationGroups(id value, NSError **error) {
+    return PXManifestValidateStringArray(value,
+                                         @"$.applicationGroups",
+                                         YES,
+                                         NULL,
+                                         error);
+}
+
+static BOOL PXManifestValidateAppGroups(id value, NSError **error) {
+    NSString *sectionPath = @"$.appGroups";
+    if (![value isKindOfClass:[NSArray class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              sectionPath,
+                              @"The appGroups section must be an array.");
+    }
+
+    NSArray *entries = (NSArray *)value;
+    NSMutableSet<NSString *> *groupIdentifiers = [NSMutableSet set];
+    NSMutableSet<NSString *> *archives = [NSMutableSet set];
+
+    for (NSUInteger index = 0; index < entries.count; index++) {
+        NSString *entryPath = PXManifestIndexedPath(sectionPath, index);
+        id rawEntry = entries[index];
+        if (![rawEntry isKindOfClass:[NSDictionary class]]) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorInvalidFieldType,
+                                  entryPath,
+                                  @"Each appGroups entry must be a dictionary.");
+        }
+
+        NSDictionary *entry = (NSDictionary *)rawEntry;
+        if (!PXManifestRequireKeys(entry,
+                                   @[@"groupID", @"uuid", @"archive"],
+                                   entryPath,
+                                   error)) {
+            return NO;
+        }
+
+        NSString *groupPath = PXManifestFieldPath(entryPath, @"groupID");
+        if (!PXManifestValidateRequiredString(entry[@"groupID"], groupPath, error)) {
+            return NO;
+        }
+        NSString *groupIdentifier = entry[@"groupID"];
+        if ([groupIdentifiers containsObject:groupIdentifier]) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorDuplicateEntry,
+                                  groupPath,
+                                  @"The appGroups section contains a duplicate group identifier.");
+        }
+        [groupIdentifiers addObject:groupIdentifier];
+
+        if (!PXManifestValidateRequiredString(entry[@"uuid"],
+                                              PXManifestFieldPath(entryPath, @"uuid"),
+                                              error)) {
+            return NO;
+        }
+
+        NSString *archivePath = PXManifestFieldPath(entryPath, @"archive");
+        if (!PXManifestValidateRequiredString(entry[@"archive"], archivePath, error)) {
+            return NO;
+        }
+        NSString *archive = entry[@"archive"];
+        if ([archives containsObject:archive]) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorDuplicateEntry,
+                                  archivePath,
+                                  @"The appGroups section contains a duplicate archive reference.");
+        }
+        [archives addObject:archive];
+    }
+
+    return YES;
+}
+
+static BOOL PXManifestValidatePreferences(id value, NSError **error) {
+    NSString *sectionPath = @"$.preferences";
+    if (![value isKindOfClass:[NSDictionary class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              sectionPath,
+                              @"The preferences section must be a dictionary.");
+    }
+
+    NSDictionary *section = (NSDictionary *)value;
+    if (!PXManifestRequireKeys(section, @[@"included", @"archive"], sectionPath, error)) {
+        return NO;
+    }
+
+    return PXManifestValidateBoolean(section[@"included"], @"$.preferences.included", error) &&
+           PXManifestValidateRequiredString(section[@"archive"], @"$.preferences.archive", error);
+}
+
+static BOOL PXManifestValidateKeychain(id value, NSError **error) {
+    NSString *sectionPath = @"$.keychain";
+    if (![value isKindOfClass:[NSDictionary class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              sectionPath,
+                              @"The keychain section must be a dictionary.");
+    }
+
+    NSDictionary *section = (NSDictionary *)value;
+    if (!PXManifestRequireKeys(section,
+                               @[@"included", @"archive", @"groupsSelected"],
+                               sectionPath,
+                               error)) {
+        return NO;
+    }
+
+    if (!PXManifestValidateBoolean(section[@"included"], @"$.keychain.included", error) ||
+        !PXManifestValidateOptionalString(section[@"archive"], @"$.keychain.archive", error) ||
+        !PXManifestValidateStringArray(section[@"groupsSelected"],
+                                       @"$.keychain.groupsSelected",
+                                       YES,
+                                       NULL,
+                                       error)) {
+        return NO;
+    }
+
+    id method = section[@"method"];
+    if (method && !PXManifestValidateOptionalString(method, @"$.keychain.method", error)) {
+        return NO;
+    }
+
+    if ([(NSNumber *)section[@"included"] boolValue] &&
+        !PXManifestStringHasNonWhitespace(section[@"archive"])) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.keychain.archive",
+                              @"An included keychain section requires a nonempty archive reference.");
+    }
+
+    return YES;
+}
+
+static BOOL PXManifestValidateOptionalArchiveSection(id value,
+                                                     NSString *sectionPath,
+                                                     NSError **error) {
+    if (![value isKindOfClass:[NSDictionary class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              sectionPath,
+                              @"The section must be a dictionary.");
+    }
+
+    NSDictionary *section = (NSDictionary *)value;
+    if (!PXManifestRequireKeys(section,
+                               @[@"included", @"archive", @"path"],
+                               sectionPath,
+                               error)) {
+        return NO;
+    }
+
+    NSString *includedPath = PXManifestFieldPath(sectionPath, @"included");
+    NSString *archivePath = PXManifestFieldPath(sectionPath, @"archive");
+    NSString *valuePath = PXManifestFieldPath(sectionPath, @"path");
+    if (!PXManifestValidateBoolean(section[@"included"], includedPath, error) ||
+        !PXManifestValidateOptionalString(section[@"archive"], archivePath, error) ||
+        !PXManifestValidateOptionalString(section[@"path"], valuePath, error)) {
+        return NO;
+    }
+
+    if ([(NSNumber *)section[@"included"] boolValue]) {
+        if (!PXManifestStringHasNonWhitespace(section[@"archive"])) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorInconsistentField,
+                                  archivePath,
+                                  @"An included section requires a nonempty archive reference.");
+        }
+        if (!PXManifestStringHasNonWhitespace(section[@"path"])) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorInconsistentField,
+                                  valuePath,
+                                  @"An included section requires a nonempty recorded path.");
+        }
+    }
+
+    return YES;
+}
+
+static BOOL PXManifestValidateArtifacts(id value,
+                                        NSUInteger *artifactCount,
+                                        NSError **error) {
+    NSString *sectionPath = @"$.artifacts";
+    if (![value isKindOfClass:[NSArray class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              sectionPath,
+                              @"The artifacts section must be an array.");
+    }
+
+    NSArray *entries = (NSArray *)value;
+    NSMutableSet<NSString *> *names = [NSMutableSet set];
+    NSMutableSet<NSString *> *paths = [NSMutableSet set];
+
+    for (NSUInteger index = 0; index < entries.count; index++) {
+        NSString *entryPath = PXManifestIndexedPath(sectionPath, index);
+        id rawEntry = entries[index];
+        if (![rawEntry isKindOfClass:[NSDictionary class]]) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorInvalidFieldType,
+                                  entryPath,
+                                  @"Each artifact entry must be a dictionary.");
+        }
+
+        NSDictionary *entry = (NSDictionary *)rawEntry;
+        if (!PXManifestRequireKeys(entry,
+                                   @[@"name", @"path", @"size", @"sha256"],
+                                   entryPath,
+                                   error)) {
+            return NO;
+        }
+
+        NSString *namePath = PXManifestFieldPath(entryPath, @"name");
+        if (!PXManifestValidateRequiredString(entry[@"name"], namePath, error)) {
+            return NO;
+        }
+        NSString *name = entry[@"name"];
+        if ([names containsObject:name]) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorDuplicateEntry,
+                                  namePath,
+                                  @"The artifacts section contains a duplicate name.");
+        }
+        [names addObject:name];
+
+        NSString *recordedPath = PXManifestFieldPath(entryPath, @"path");
+        if (!PXManifestValidateRequiredString(entry[@"path"], recordedPath, error)) {
+            return NO;
+        }
+        NSString *pathValue = entry[@"path"];
+        if ([paths containsObject:pathValue]) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorDuplicateEntry,
+                                  recordedPath,
+                                  @"The artifacts section contains a duplicate path.");
+        }
+        [paths addObject:pathValue];
+
+        if (!PXManifestValidateNonnegativeIntegral(entry[@"size"],
+                                                   PXManifestFieldPath(entryPath, @"size"),
+                                                   NULL,
+                                                   error) ||
+            !PXManifestValidateOptionalString(entry[@"sha256"],
+                                              PXManifestFieldPath(entryPath, @"sha256"),
+                                              error)) {
+            return NO;
+        }
+    }
+
+    if (artifactCount) {
+        *artifactCount = entries.count;
+    }
+    return YES;
+}
+
+static BOOL PXManifestValidateOptions(id value, NSError **error) {
+    NSString *sectionPath = @"$.options";
+    if (![value isKindOfClass:[NSDictionary class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              sectionPath,
+                              @"The options section must be a dictionary.");
+    }
+
+    NSDictionary *section = (NSDictionary *)value;
+    NSArray<NSString *> *keys = @[
+        @"includeAppGroups",
+        @"includePreferences",
+        @"includeKeychain"
+    ];
+    if (!PXManifestRequireKeys(section, keys, sectionPath, error)) {
+        return NO;
+    }
+
+    for (NSString *key in keys) {
+        if (!PXManifestValidateBoolean(section[key],
+                                       PXManifestFieldPath(sectionPath, key),
+                                       error)) {
+            return NO;
+        }
+    }
+    return YES;
+}
+
+static BOOL PXManifestValidateRestoreCompatibility(id value,
+                                                   NSString *rootBundleIdentifier,
+                                                   NSError **error) {
+    NSString *sectionPath = @"$.restoreCompatibility";
+    if (![value isKindOfClass:[NSDictionary class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              sectionPath,
+                              @"The restoreCompatibility section must be a dictionary.");
+    }
+
+    NSDictionary *section = (NSDictionary *)value;
+    if (!PXManifestRequireKeys(section,
+                               @[@"targetBundleID",
+                                 @"requiresSameBundleID",
+                                 @"requiresInstalledAppContainer",
+                                 @"notes"],
+                               sectionPath,
+                               error)) {
+        return NO;
+    }
+
+    if (!PXManifestValidateRequiredString(section[@"targetBundleID"],
+                                          @"$.restoreCompatibility.targetBundleID",
+                                          error) ||
+        !PXManifestValidateBoolean(section[@"requiresSameBundleID"],
+                                   @"$.restoreCompatibility.requiresSameBundleID",
+                                   error) ||
+        !PXManifestValidateBoolean(section[@"requiresInstalledAppContainer"],
+                                   @"$.restoreCompatibility.requiresInstalledAppContainer",
+                                   error) ||
+        !PXManifestValidateStringArray(section[@"notes"],
+                                       @"$.restoreCompatibility.notes",
+                                       NO,
+                                       NULL,
+                                       error)) {
+        return NO;
+    }
+
+    if (![section[@"targetBundleID"] isEqualToString:rootBundleIdentifier]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.restoreCompatibility.targetBundleID",
+                              @"The compatibility target must exactly match the manifest bundle identifier.");
+    }
+
+    return YES;
+}
+
+static BOOL PXManifestValidateSystemGlobalLibrary(id value, NSError **error) {
+    NSString *sectionPath = @"$.systemGlobalLibrary";
+    if (![value isKindOfClass:[NSDictionary class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              sectionPath,
+                              @"The systemGlobalLibrary section must be a dictionary.");
+    }
+
+    NSDictionary *section = (NSDictionary *)value;
+    if (!PXManifestRequireKeys(section, @[@"included", @"items"], sectionPath, error)) {
+        return NO;
+    }
+    if (!PXManifestValidateBoolean(section[@"included"],
+                                   @"$.systemGlobalLibrary.included",
+                                   error)) {
+        return NO;
+    }
+    if (![section[@"items"] isKindOfClass:[NSArray class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              @"$.systemGlobalLibrary.items",
+                              @"The items field must be an array.");
+    }
+
+    NSArray *items = section[@"items"];
+    NSMutableSet<NSString *> *subdirectories = [NSMutableSet set];
+    NSMutableSet<NSString *> *archives = [NSMutableSet set];
+    for (NSUInteger index = 0; index < items.count; index++) {
+        NSString *itemPath = PXManifestIndexedPath(@"$.systemGlobalLibrary.items", index);
+        id rawItem = items[index];
+        if (![rawItem isKindOfClass:[NSDictionary class]]) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorInvalidFieldType,
+                                  itemPath,
+                                  @"Each systemGlobalLibrary item must be a dictionary.");
+        }
+
+        NSDictionary *item = (NSDictionary *)rawItem;
+        if (!PXManifestRequireKeys(item, @[@"subdir", @"archive"], itemPath, error)) {
+            return NO;
+        }
+
+        NSString *subdirPath = PXManifestFieldPath(itemPath, @"subdir");
+        if (!PXManifestValidateRequiredString(item[@"subdir"], subdirPath, error)) {
+            return NO;
+        }
+        NSString *subdir = item[@"subdir"];
+        if ([subdirectories containsObject:subdir]) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorDuplicateEntry,
+                                  subdirPath,
+                                  @"The systemGlobalLibrary section contains a duplicate subdirectory.");
+        }
+        [subdirectories addObject:subdir];
+
+        NSString *archivePath = PXManifestFieldPath(itemPath, @"archive");
+        if (!PXManifestValidateRequiredString(item[@"archive"], archivePath, error)) {
+            return NO;
+        }
+        NSString *archive = item[@"archive"];
+        if ([archives containsObject:archive]) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorDuplicateEntry,
+                                  archivePath,
+                                  @"The systemGlobalLibrary section contains a duplicate archive reference.");
+        }
+        [archives addObject:archive];
+    }
+
+    BOOL included = [(NSNumber *)section[@"included"] boolValue];
+    if ((included && items.count == 0) || (!included && items.count != 0)) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.systemGlobalLibrary.items",
+                              @"The items count is inconsistent with the included flag.");
+    }
+    return YES;
+}
+
+static BOOL PXManifestValidateSharedSystemDB(id value, NSError **error) {
+    NSString *sectionPath = @"$.sharedSystemDB";
+    if (![value isKindOfClass:[NSDictionary class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              sectionPath,
+                              @"The sharedSystemDB section must be a dictionary.");
+    }
+
+    NSDictionary *section = (NSDictionary *)value;
+    if (!PXManifestRequireKeys(section, @[@"included", @"files"], sectionPath, error)) {
+        return NO;
+    }
+    if (!PXManifestValidateBoolean(section[@"included"],
+                                   @"$.sharedSystemDB.included",
+                                   error)) {
+        return NO;
+    }
+    if (![section[@"files"] isKindOfClass:[NSArray class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              @"$.sharedSystemDB.files",
+                              @"The files field must be an array.");
+    }
+
+    NSArray *files = section[@"files"];
+    NSMutableSet<NSString *> *relativeLocations = [NSMutableSet set];
+    NSMutableSet<NSString *> *archives = [NSMutableSet set];
+    for (NSUInteger index = 0; index < files.count; index++) {
+        NSString *itemPath = PXManifestIndexedPath(@"$.sharedSystemDB.files", index);
+        id rawItem = files[index];
+        if (![rawItem isKindOfClass:[NSDictionary class]]) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorInvalidFieldType,
+                                  itemPath,
+                                  @"Each sharedSystemDB entry must be a dictionary.");
+        }
+
+        NSDictionary *item = (NSDictionary *)rawItem;
+        if (!PXManifestRequireKeys(item, @[@"libraryRel", @"archive"], itemPath, error)) {
+            return NO;
+        }
+
+        NSString *relativePath = PXManifestFieldPath(itemPath, @"libraryRel");
+        if (!PXManifestValidateRequiredString(item[@"libraryRel"], relativePath, error)) {
+            return NO;
+        }
+        NSString *relativeLocation = item[@"libraryRel"];
+        if ([relativeLocations containsObject:relativeLocation]) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorDuplicateEntry,
+                                  relativePath,
+                                  @"The sharedSystemDB section contains a duplicate relative location.");
+        }
+        [relativeLocations addObject:relativeLocation];
+
+        NSString *archivePath = PXManifestFieldPath(itemPath, @"archive");
+        if (!PXManifestValidateRequiredString(item[@"archive"], archivePath, error)) {
+            return NO;
+        }
+        NSString *archive = item[@"archive"];
+        if ([archives containsObject:archive]) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorDuplicateEntry,
+                                  archivePath,
+                                  @"The sharedSystemDB section contains a duplicate archive reference.");
+        }
+        [archives addObject:archive];
+    }
+
+    BOOL included = [(NSNumber *)section[@"included"] boolValue];
+    if ((included && files.count == 0) || (!included && files.count != 0)) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInconsistentField,
+                              @"$.sharedSystemDB.files",
+                              @"The files count is inconsistent with the included flag.");
+    }
+    return YES;
+}
+
+@implementation PXBackupManifestValidator
+
++ (BOOL)validateManifestObject:(nullable id)object
+                         error:(NSError * _Nullable * _Nullable)error {
+    if (error) {
+        *error = nil;
+    }
+
+    if (![object isKindOfClass:[NSDictionary class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidRoot,
+                              @"$",
+                              @"The manifest root must be a dictionary.");
+    }
+
+    NSUInteger visited = 0;
+    NSHashTable *activeContainers =
+        [NSHashTable hashTableWithOptions:NSHashTableObjectPointerPersonality];
+    if (!PXManifestValidateGraphObject(object,
+                                       1,
+                                       &visited,
+                                       activeContainers,
+                                       error)) {
+        return NO;
+    }
+
+    NSDictionary *manifest = (NSDictionary *)object;
+    NSArray<NSString *> *requiredRootKeys = @[
+        @"manifestVersion",
+        @"bundleID",
+        @"appName",
+        @"timestamp",
+        @"iosVersion",
+        @"profileId",
+        @"data",
+        @"applicationGroups",
+        @"appGroups",
+        @"preferences",
+        @"keychain",
+        @"profileAppData",
+        @"globalSafari",
+        @"artifacts",
+        @"options"
+    ];
+    if (!PXManifestRequireKeys(manifest, requiredRootKeys, @"$", error)) {
+        return NO;
+    }
+
+    if (!PXManifestValidatePositiveVersion(manifest[@"manifestVersion"],
+                                           @"$.manifestVersion",
+                                           error) ||
+        !PXManifestValidateRequiredString(manifest[@"bundleID"],
+                                          @"$.bundleID",
+                                          error) ||
+        !PXManifestValidateOptionalString(manifest[@"appName"],
+                                          @"$.appName",
+                                          error) ||
+        !PXManifestValidateRequiredString(manifest[@"timestamp"],
+                                          @"$.timestamp",
+                                          error) ||
+        !PXManifestValidateOptionalString(manifest[@"iosVersion"],
+                                          @"$.iosVersion",
+                                          error) ||
+        !PXManifestValidateOptionalString(manifest[@"profileId"],
+                                          @"$.profileId",
+                                          error)) {
+        return NO;
+    }
+
+    if (!PXManifestValidateDataSection(manifest[@"data"], error) ||
+        !PXManifestValidateApplicationGroups(manifest[@"applicationGroups"], error) ||
+        !PXManifestValidateAppGroups(manifest[@"appGroups"], error) ||
+        !PXManifestValidatePreferences(manifest[@"preferences"], error) ||
+        !PXManifestValidateKeychain(manifest[@"keychain"], error) ||
+        !PXManifestValidateOptionalArchiveSection(manifest[@"profileAppData"],
+                                                  @"$.profileAppData",
+                                                  error) ||
+        !PXManifestValidateOptionalArchiveSection(manifest[@"globalSafari"],
+                                                  @"$.globalSafari",
+                                                  error)) {
+        return NO;
+    }
+
+    NSUInteger artifactCount = 0;
+    if (!PXManifestValidateArtifacts(manifest[@"artifacts"], &artifactCount, error) ||
+        !PXManifestValidateOptions(manifest[@"options"], error)) {
+        return NO;
+    }
+
+    id createdAt = manifest[@"createdAt"];
+    if (createdAt && ![createdAt isKindOfClass:[NSDate class]]) {
+        return PXManifestFail(error,
+                              PXBackupManifestValidatorErrorInvalidFieldType,
+                              @"$.createdAt",
+                              @"The createdAt field must be a date.");
+    }
+
+    NSArray<NSString *> *optionalStringFields = @[
+        @"toolVersion",
+        @"toolBuild"
+    ];
+    for (NSString *field in optionalStringFields) {
+        id value = manifest[field];
+        if (value && !PXManifestValidateOptionalString(value,
+                                                       PXManifestFieldPath(@"$", field),
+                                                       error)) {
+            return NO;
+        }
+    }
+
+    id backupMode = manifest[@"backupMode"];
+    if (backupMode &&
+        !PXManifestValidateRequiredString(backupMode, @"$.backupMode", error)) {
+        return NO;
+    }
+
+    optionalStringFields = @[
+        @"sourceDataContainerPath",
+        @"sourceDataContainerUUID"
+    ];
+    for (NSString *field in optionalStringFields) {
+        id value = manifest[field];
+        if (value && !PXManifestValidateOptionalString(value,
+                                                       PXManifestFieldPath(@"$", field),
+                                                       error)) {
+            return NO;
+        }
+    }
+
+    NSSet<NSString *> *includedOptions = nil;
+    id includedOptionsValue = manifest[@"includedOptions"];
+    if (includedOptionsValue &&
+        !PXManifestValidateStringArray(includedOptionsValue,
+                                       @"$.includedOptions",
+                                       YES,
+                                       &includedOptions,
+                                       error)) {
+        return NO;
+    }
+
+    NSSet<NSString *> *excludedOptions = nil;
+    id excludedOptionsValue = manifest[@"excludedOptions"];
+    if (excludedOptionsValue &&
+        !PXManifestValidateStringArray(excludedOptionsValue,
+                                       @"$.excludedOptions",
+                                       YES,
+                                       &excludedOptions,
+                                       error)) {
+        return NO;
+    }
+
+    if (includedOptions && excludedOptions) {
+        NSArray *excludedArray = (NSArray *)excludedOptionsValue;
+        for (NSUInteger index = 0; index < excludedArray.count; index++) {
+            if ([includedOptions containsObject:excludedArray[index]]) {
+                return PXManifestFail(error,
+                                      PXBackupManifestValidatorErrorInconsistentField,
+                                      PXManifestIndexedPath(@"$.excludedOptions", index),
+                                      @"Included and excluded option arrays must be disjoint.");
+            }
+        }
+    }
+
+    id artifactCountValue = manifest[@"artifactCount"];
+    if (artifactCountValue) {
+        unsigned long long declaredCount = 0;
+        if (!PXManifestValidateNonnegativeIntegral(artifactCountValue,
+                                                   @"$.artifactCount",
+                                                   &declaredCount,
+                                                   error)) {
+            return NO;
+        }
+        if (declaredCount != (unsigned long long)artifactCount) {
+            return PXManifestFail(error,
+                                  PXBackupManifestValidatorErrorInconsistentField,
+                                  @"$.artifactCount",
+                                  @"The declared artifact count must equal the artifacts array count.");
+        }
+    }
+
+    id totalSize = manifest[@"totalSize"];
+    if (totalSize &&
+        !PXManifestValidateNonnegativeIntegral(totalSize,
+                                               @"$.totalSize",
+                                               NULL,
+                                               error)) {
+        return NO;
+    }
+
+    id archiveChecksum = manifest[@"archiveChecksum"];
+    if (archiveChecksum &&
+        !PXManifestValidateOptionalString(archiveChecksum,
+                                          @"$.archiveChecksum",
+                                          error)) {
+        return NO;
+    }
+
+    id warnings = manifest[@"warnings"];
+    if (warnings &&
+        !PXManifestValidateStringArray(warnings,
+                                       @"$.warnings",
+                                       NO,
+                                       NULL,
+                                       error)) {
+        return NO;
+    }
+
+    id restoreCompatibility = manifest[@"restoreCompatibility"];
+    if (restoreCompatibility &&
+        !PXManifestValidateRestoreCompatibility(restoreCompatibility,
+                                                manifest[@"bundleID"],
+                                                error)) {
+        return NO;
+    }
+
+    id systemGlobalLibrary = manifest[@"systemGlobalLibrary"];
+    if (systemGlobalLibrary &&
+        !PXManifestValidateSystemGlobalLibrary(systemGlobalLibrary, error)) {
+        return NO;
+    }
+
+    id sharedSystemDB = manifest[@"sharedSystemDB"];
+    if (sharedSystemDB &&
+        !PXManifestValidateSharedSystemDB(sharedSystemDB, error)) {
+        return NO;
+    }
+
+    return YES;
+}
+
+@end
```

## 17. Pre-commit conclusion

- Exact implementation scope: two new production files plus this report.
- Protected existing production diff: zero.
- No caller integration, supported-version enforcement, requested-bundle enforcement, artifact inspection or archive inspection.
- TASK-2.2 was not started.

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
