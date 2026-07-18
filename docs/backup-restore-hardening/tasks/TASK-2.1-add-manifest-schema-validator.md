# TASK-2.1 — Add Standalone Backup Manifest Schema Validator

- Status: READY
- Phase: Phase 2 — Restore Preflight and Transaction
- Depends on: TASK-1.12 accepted; Phase 1 completed
- Build owner: Project owner via GitHub Actions
- Next task: TASK-2.2 remains LOCKED

## Objective

Add a standalone, deterministic, pure-Foundation schema validator for an already-loaded backup manifest object.

The validator establishes the structural contract that later Restore preflight tasks can consume. It must validate:

- root and nested runtime types;
- required common manifest sections;
- boolean versus numeric distinctions;
- integer/count shape;
- string and collection shape;
- duplicate identifiers that would make later lookup ambiguous;
- limited cross-field consistency that requires no filesystem access;
- property-list graph safety and bounded traversal.

TASK-2.1 is **contract only**.

It must not:

- read `manifest.plist` from disk;
- modify `AppDataBackupManager`;
- integrate the validator into Backup, Restore, listing or UI;
- enforce which `manifestVersion` values are supported;
- compare the manifest bundle identifier with a requested restore bundle;
- authorize a destination path or container UUID;
- inspect artifact files or verify checksums;
- inspect archive entries;
- build a restore plan;
- mutate any filesystem object.

Those behaviors belong to TASK-2.2 and later tasks.

---

## Baseline

Expected baseline HEAD:

```text
92b051fcc2e32193cf3e5b8837784e08b9ad1961
```

TASK-1.12 production review:

```text
ACCEPTED
```

Before editing, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -3 --oneline
```

Coordinator-owned uncommitted documentation must not be staged, rewritten or reverted.

---

## Allowed production changes

Create exactly:

```text
PXBackupManifestValidator.h
PXBackupManifestValidator.m
```

Create the task report:

```text
docs/backup-restore-hardening/reports/TASK-2.1-REPORT.md
```

The root Makefile already compiles `$(wildcard *.m)`. Do not modify `Makefile`.

---

## Protected files

Do not modify any existing production file, including:

```text
AppDataBackupManager.h
AppDataBackupManager.m
AppDataCleaner.h
AppDataCleaner.m
AppEntitlementsReader.h
AppEntitlementsReader.m
PXResolvedContainer.h
PXResolvedContainer.m
PXDataContainerResolver.h
PXDataContainerResolver.m
PXDestructivePathValidator.h
PXDestructivePathValidator.m
PXClearRequest.h
PXClearRequest.m
PXClearResult.h
PXClearResult.m
CommandRunner.h
CommandRunner.m
AppGroupContainerResolver.h
AppGroupContainerResolver.m
ProjectXViewController.m
KeychainGroupsViewController.m
WeaponXKeychainBridge/Tweak.m
KeychainHelper/backup_helper.m
KeychainHelper/KeychainBackupHelper.h
KeychainHelper/KeychainBackupHelper.m
Makefile
```

Do not modify task specifications, reviews, status, roadmap, decisions or README files. These are coordinator-owned.

No existing production file may import or reference `PXBackupManifestValidator` in TASK-2.1.

---

# Part 1 — Exact public contract

Create `PXBackupManifestValidator.h` with this public shape:

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const
    PXBackupManifestValidatorErrorDomain;

FOUNDATION_EXPORT NSString * const
    PXBackupManifestValidatorErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXBackupManifestValidatorErrorCode) {
    PXBackupManifestValidatorErrorInvalidRoot = 1,
    PXBackupManifestValidatorErrorMissingRequiredField = 2,
    PXBackupManifestValidatorErrorInvalidFieldType = 3,
    PXBackupManifestValidatorErrorInvalidFieldValue = 4,
    PXBackupManifestValidatorErrorDuplicateEntry = 5,
    PXBackupManifestValidatorErrorInconsistentField = 6,
};

__attribute__((objc_subclassing_restricted))
@interface PXBackupManifestValidator : NSObject

+ (BOOL)validateManifestObject:(nullable id)object
                         error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
```

Requirements:

- exact class name;
- exact method selector;
- exact six error-code names and values;
- no instance state;
- no mutable property;
- no alternate convenience validator;
- no API accepting a backup directory, file path, expected bundle ID or supported-version set;
- no normalized/corrected manifest return value.

The validator only answers whether the supplied in-memory object satisfies this schema contract.

---

# Part 2 — Error contract

`validateManifestObject:error:` must clear `*error` at entry when the pointer is non-null.

On success:

```text
return YES
error remains nil
```

On failure:

```text
return NO
error domain = PXBackupManifestValidatorErrorDomain
error code = one exact enum value
```

Error `userInfo` may contain only:

```text
NSLocalizedDescriptionKey
PXBackupManifestValidatorErrorFieldPathKey
```

Do not place in `userInfo`:

- the manifest object;
- the invalid field value;
- a dictionary or array excerpt;
- paths from manifest values;
- UUIDs;
- bundle identifiers;
- archive names;
- checksums;
- nested errors;
- arbitrary caller objects.

Field paths must be stable schema locations, for example:

```text
$
$.manifestVersion
$.data.archive
$.artifacts[2].size
$.appGroups[1].groupID
```

Descriptions must explain the failed rule without interpolating the raw field value.

The validator returns the first deterministic failure only.

---

# Part 3 — No version support enforcement

`manifestVersion` is a required positive integral `NSNumber`.

It must:

- not be a CFBoolean;
- not be floating point;
- not be decimal/fractional;
- be greater than zero;
- fit within signed `NSInteger` positive range.

TASK-2.1 must **not** restrict the value to `2`, `3` or any supported set.

Given otherwise identical structurally valid manifests, these version values must pass TASK-2.1:

```text
1
2
3
999
```

These must fail structural validation:

```text
missing manifestVersion
0
-1
@YES
@1.0
@"3"
NSNull
```

TASK-2.2 alone decides which positive schema versions Restore accepts.

Do not add constants such as:

```text
PXSupportedManifestVersion
PXMinimumManifestVersion
PXMaximumManifestVersion
```

in TASK-2.1.

---

# Part 4 — No requested-bundle matching

The validator has no expected/requested bundle-ID input.

`bundleID` is structurally valid when it is:

- runtime `NSString`;
- nonempty;
- not whitespace/newline-only;
- free of Unicode U+0000.

Do not:

- compare it with a caller-supplied bundle ID;
- read the currently installed app;
- apply exact restore-target matching;
- lowercase, trim or normalize it;
- apply an ASCII bundle-syntax whitelist.

TASK-2.3 owns exact requested-target bundle matching.

Values such as Unicode or underscore-containing identifiers are not rejected solely by this schema validator when otherwise nonempty and NUL-free.

---

# Part 5 — Property-list graph safety

Before field-specific schema validation, validate the complete reachable object graph.

Accepted container classes:

```text
NSDictionary
NSArray
```

Accepted leaf classes:

```text
NSString
NSNumber
NSDate
NSData
```

Reject:

- `NSNull`;
- custom non-property-list objects;
- non-string dictionary keys;
- empty/whitespace-only dictionary keys;
- dictionary keys containing U+0000;
- cyclic array/dictionary graphs;
- nesting deeper than 32 container levels;
- more than 100000 visited values/keys in aggregate;
- a single array or dictionary with more than 10000 entries.

Cycle detection must use container object identity for the active recursion stack. Shared non-cyclic subobjects are allowed.

Dictionary traversal used by graph validation must be deterministic. Sort valid string keys with `compare:` before descending.

A graph-limit failure uses:

```text
PXBackupManifestValidatorErrorInvalidFieldValue
```

An unsupported leaf/key type uses:

```text
PXBackupManifestValidatorErrorInvalidFieldType
```

Do not use `NSPropertyListSerialization` as a substitute for the explicit contract.

Do not serialize, copy, rewrite or normalize the graph.

---

# Part 6 — Primitive field rules

## 6.1 Required nonempty strings

A required nonempty string must be:

- runtime `NSString`;
- length greater than zero;
- contain at least one character outside `whitespaceAndNewlineCharacterSet`;
- contain no U+0000;
- preserved exactly.

## 6.2 Strings that may be empty

An empty-permitted string must be:

- runtime `NSString`;
- contain no U+0000.

Do not trim or normalize.

## 6.3 Real booleans

Boolean schema fields must be actual CFBoolean-backed `NSNumber` values.

Accept:

```text
@YES
@NO
```

Reject numeric substitutes even when `boolValue` would work:

```text
@0
@1
@2
@0.0
@"YES"
```

Use `CFBooleanGetTypeID()` or equivalent exact Boolean detection.

## 6.4 Integral numbers

Integral fields must:

- be runtime `NSNumber`;
- not be CFBoolean;
- have an integral Objective-C numeric type;
- reject float/double/decimal representations;
- satisfy the field's sign/range rule.

Nonnegative count/size fields accept zero.

`manifestVersion` requires greater than zero.

---

# Part 7 — Required root schema

The root must be a runtime `NSDictionary` and must contain all of these common required keys:

```text
manifestVersion
bundleID
appName
timestamp
iosVersion
profileId
data
applicationGroups
appGroups
preferences
keychain
profileAppData
globalSafari
artifacts
options
```

Missing keys fail with:

```text
PXBackupManifestValidatorErrorMissingRequiredField
```

Validate required keys in exactly the order listed above.

Required root field types:

| Key | Rule |
|---|---|
| `manifestVersion` | positive integral number, no supported-value enforcement |
| `bundleID` | required nonempty string |
| `appName` | empty-permitted string |
| `timestamp` | required nonempty string |
| `iosVersion` | empty-permitted string |
| `profileId` | empty-permitted string |
| `data` | dictionary using Part 8 |
| `applicationGroups` | string array using Part 9 |
| `appGroups` | dictionary array using Part 10 |
| `preferences` | dictionary using Part 11 |
| `keychain` | dictionary using Part 12 |
| `profileAppData` | dictionary using Part 13 |
| `globalSafari` | dictionary using Part 13 |
| `artifacts` | dictionary array using Part 14 |
| `options` | dictionary using Part 15 |

Unknown root keys are allowed for forward-compatible metadata, but their values must already have passed property-list graph safety.

---

# Part 8 — `data` section

`$.data` must be a dictionary with required keys:

```text
uuid
archive
containerPath
```

Each must be a required nonempty string.

TASK-2.1 does not:

- parse or validate UUID syntax;
- check whether `containerPath` is absolute;
- canonicalize the path;
- check path containment;
- compare path and UUID;
- inspect the filesystem;
- require the archive to exist;
- validate archive path traversal.

The manifest path and UUID are structural metadata only at this gate. TASK-2.4 removes their destination-authority fallback.

Unknown keys are allowed.

---

# Part 9 — `applicationGroups`

`$.applicationGroups` must be an array.

Every element must be a required nonempty string.

Exact duplicate strings are rejected with:

```text
PXBackupManifestValidatorErrorDuplicateEntry
```

Do not:

- lowercase or normalize group identifiers;
- compare them with installed entitlements;
- resolve containers;
- require a naming prefix.

An empty array is structurally valid.

---

# Part 10 — `appGroups`

`$.appGroups` must be an array of dictionaries.

Each entry requires:

```text
groupID
uuid
archive
```

All three are required nonempty strings.

Reject exact duplicate:

- `groupID` values;
- `archive` values.

Do not reject duplicate UUID values solely because two exact group identities may describe one physical metadata-array container.

Do not:

- inspect metadata;
- resolve App Group containers;
- verify entitlement ownership;
- validate archive existence;
- authorize the recorded UUID.

Unknown entry keys are allowed.

---

# Part 11 — `preferences`

`$.preferences` must be a dictionary with required keys:

```text
included
archive
```

Rules:

- `included` is a real Boolean;
- `archive` is a required nonempty string.

The archive remains required even when `included == NO`, matching the existing version-2/version-3 manifest shape.

Do not check file existence or path safety.

---

# Part 12 — `keychain`

`$.keychain` must be a dictionary with required keys:

```text
included
archive
groupsSelected
```

Rules:

- `included` is a real Boolean;
- `archive` is an empty-permitted string;
- `groupsSelected` is an array of exact duplicate-free required nonempty strings.

Cross-field rule:

```text
included == YES  -> archive must be nonempty/non-whitespace
included == NO   -> archive may be empty or nonempty
```

Optional key:

```text
method
```

When present, `method` is an empty-permitted string.

Do not:

- authorize Keychain access groups;
- compare against entitlements;
- restrict method values;
- inspect `keychain.plist`;
- verify Keychain contents.

---

# Part 13 — Optional-archive sections

Both:

```text
$.profileAppData
$.globalSafari
```

must be dictionaries with required keys:

```text
included
archive
path
```

Rules:

- `included` is a real Boolean;
- `archive` is an empty-permitted string;
- `path` is an empty-permitted string.

Cross-field rule:

```text
included == YES -> archive and path must both be nonempty/non-whitespace
included == NO  -> archive and path may be empty or nonempty
```

Do not inspect, canonicalize or authorize `path`.

---

# Part 14 — `artifacts`

`$.artifacts` must be an array of dictionaries.

An empty array is structurally valid in TASK-2.1. Required-artifact policy belongs to TASK-2.5 and later restore planning.

Every artifact entry requires:

```text
name
path
size
sha256
```

Rules:

- `name` is a required nonempty string;
- `path` is a required nonempty string;
- `size` is a nonnegative integral number;
- `sha256` is an empty-permitted string.

Reject exact duplicate:

- artifact `name` values;
- artifact `path` values.

Do not:

- require SHA-256 length or hex syntax;
- hash a file;
- check file size;
- check file existence;
- compare `name` with section archive references;
- canonicalize `path`;
- reject absolute or traversal-looking strings at this stage.

TASK-2.5 owns common artifact verification and cross-reference policy.

---

# Part 15 — `options`

`$.options` must be a dictionary with required real-Boolean keys:

```text
includeAppGroups
includePreferences
includeKeychain
```

Do not infer or require equality between option-request flags and actual included sections. Existing manifests can record an option request even when producing an optional artifact failed.

Unknown option keys are allowed if graph-safe.

---

# Part 16 — Optional known version-3 metadata

The following root fields are optional. When present, validate them exactly as follows:

| Key | Rule |
|---|---|
| `createdAt` | runtime `NSDate` |
| `toolVersion` | empty-permitted string |
| `toolBuild` | empty-permitted string |
| `backupMode` | required nonempty string |
| `sourceDataContainerPath` | empty-permitted string |
| `sourceDataContainerUUID` | empty-permitted string |
| `includedOptions` | duplicate-free required-nonempty string array |
| `excludedOptions` | duplicate-free required-nonempty string array |
| `artifactCount` | nonnegative integral number equal to `artifacts.count` |
| `totalSize` | nonnegative integral number |
| `archiveChecksum` | empty-permitted string |
| `warnings` | array of required nonempty strings |

`includedOptions` and `excludedOptions` must also be exact-disjoint. The same string appearing in both arrays is:

```text
PXBackupManifestValidatorErrorInconsistentField
```

Do not restrict option-name vocabulary.

Do not compare `totalSize` with artifact size sums or verify `archiveChecksum`; TASK-2.5 owns artifact verification.

---

# Part 17 — Optional `restoreCompatibility`

When present, `$.restoreCompatibility` must be a dictionary with required keys:

```text
targetBundleID
requiresSameBundleID
requiresInstalledAppContainer
notes
```

Rules:

- `targetBundleID` is a required nonempty string;
- both `requires...` fields are real Booleans;
- `notes` is an array of required nonempty strings.

Internal consistency rule:

```text
targetBundleID must equal root bundleID exactly
```

This is only consistency between two values inside the same manifest. It does not compare with the restore request and does not implement TASK-2.3.

Do not require either Boolean to be `YES`; validate only type.

---

# Part 18 — Optional `systemGlobalLibrary`

When present, `$.systemGlobalLibrary` must be a dictionary with required keys:

```text
included
items
```

Rules:

- `included` is a real Boolean;
- `items` is an array of dictionaries;
- each item requires nonempty string `subdir` and `archive`;
- exact duplicate `subdir` values are rejected;
- exact duplicate `archive` values are rejected.

Cross-field consistency:

```text
included == YES -> items.count > 0
included == NO  -> items.count == 0
```

Do not authorize library subdirectories or inspect archives.

---

# Part 19 — Optional `sharedSystemDB`

When present, `$.sharedSystemDB` must be a dictionary with required keys:

```text
included
files
```

Rules:

- `included` is a real Boolean;
- `files` is an array of dictionaries;
- each entry requires nonempty string `libraryRel` and `archive`;
- exact duplicate `libraryRel` values are rejected;
- exact duplicate `archive` values are rejected.

Cross-field consistency:

```text
included == YES -> files.count > 0
included == NO  -> files.count == 0
```

Do not validate destination paths or artifact files.

---

# Part 20 — Unknown fields and forward compatibility

Unknown root or nested dictionary keys are allowed.

Requirements for unknown fields:

- dictionary key is a valid nonempty NUL-free string;
- value passes the bounded property-list graph-safety rules;
- no normalization or removal occurs.

Do not fail merely because version-3 or future metadata adds an unknown graph-safe key.

Supported-version enforcement remains TASK-2.2. A future version is not accepted by Restore merely because its shape passes this standalone validator.

---

# Part 21 — Deterministic validation order

After graph safety, field validation must use this deterministic order:

1. required root fields in Part 7 order;
2. `data`;
3. `applicationGroups` by ascending array index;
4. `appGroups` by ascending array index;
5. `preferences`;
6. `keychain`;
7. `profileAppData`;
8. `globalSafari`;
9. `artifacts` by ascending array index;
10. `options`;
11. optional root metadata in Part 16 table order;
12. `restoreCompatibility`;
13. `systemGlobalLibrary`;
14. `sharedSystemDB`.

Duplicate detection reports the later duplicate occurrence.

Do not depend on `NSDictionary` enumeration order for field-specific validation.

---

# Part 22 — Pure validator boundary

`PXBackupManifestValidator.m` may import only:

```objc
#import "PXBackupManifestValidator.h"
```

Foundation/CoreFoundation types available through Foundation may be used.

Forbidden in both new files:

```text
NSFileManager
NSURL file access
NSData dataWithContentsOfFile
NSDictionary dictionaryWithContentsOfFile
NSPropertyListSerialization
CommandRunner
NSTask
posix_spawn
system(
exec
fork
wait
shell
rm
find
sqlite3
Security
SecItem
UIKit
UIApplication
NSUserDefaults
NSNotificationCenter
dispatch_async
dispatch_sync
dispatch_semaphore
sleep
usleep
AppDataBackupManager
AppDataCleaner
PXDataContainerResolver
AppGroupContainerResolver
PXDestructivePathValidator
PXClearRequest
PXClearResult
```

The implementation must not:

- log the manifest or field values;
- mutate input dictionaries or arrays;
- retain global mutable state;
- cache validation results;
- create files;
- read environment/defaults;
- throw exceptions intentionally.

No existing production source may reference the validator in TASK-2.1.

---

# Part 23 — Required static scenarios

The report must cover at least these scenarios honestly as static validation cases:

## Root and graph

1. nil root;
2. string root;
3. array root;
4. empty dictionary;
5. non-string dictionary key;
6. empty dictionary key;
7. NUL-containing dictionary key;
8. NSNull unknown value;
9. custom-object unknown value;
10. valid unknown property-list metadata;
11. cyclic array;
12. cyclic dictionary;
13. depth exactly 32;
14. depth greater than 32;
15. container exactly 10000 entries;
16. container over 10000 entries;
17. total visited nodes exactly 100000;
18. total visited nodes over 100000.

## Version and identity

19. missing manifestVersion;
20. version 0;
21. negative version;
22. Boolean version;
23. floating version;
24. string version;
25. structurally valid version 1;
26. structurally valid version 2;
27. structurally valid version 3;
28. structurally valid version 999;
29. missing bundleID;
30. whitespace-only bundleID;
31. NUL bundleID;
32. Unicode bundleID;
33. underscore bundleID;
34. no requested bundle comparison API.

## Required root sections

35. missing appName;
36. missing timestamp;
37. missing data;
38. missing applicationGroups;
39. missing appGroups;
40. missing preferences;
41. missing keychain;
42. missing profileAppData;
43. missing globalSafari;
44. missing artifacts;
45. missing options.

## Primitive types

46. numeric substitute for Boolean;
47. real CFBoolean;
48. floating artifact size;
49. negative artifact size;
50. zero artifact size;
51. empty-permitted metadata string;
52. NUL in empty-permitted string.

## Data and groups

53. valid data section;
54. missing data archive;
55. empty data containerPath;
56. empty applicationGroups;
57. duplicate application group;
58. non-string application group;
59. valid appGroups entry;
60. duplicate appGroups groupID;
61. duplicate appGroups archive;
62. duplicate appGroups UUID allowed.

## Optional sections

63. preferences included false with nonempty archive;
64. keychain included false with empty archive;
65. keychain included true with empty archive;
66. duplicate Keychain selected group;
67. profileAppData included true with empty path;
68. globalSafari included false with empty fields;
69. artifact array empty;
70. duplicate artifact name;
71. duplicate artifact path;
72. empty artifact sha256;
73. malformed artifact sha256 string accepted structurally;
74. options numeric Boolean rejected;
75. artifactCount mismatch;
76. includedOptions/excludedOptions overlap;
77. optional createdAt wrong type;
78. restoreCompatibility target mismatch with root;
79. systemGlobalLibrary included true with empty items;
80. systemGlobalLibrary included false with nonempty items;
81. duplicate system-global subdir;
82. sharedSystemDB included true with empty files;
83. duplicate shared DB archive.

## Boundaries

84. unknown keys allowed;
85. input dictionary remains unmodified;
86. error cleared on success;
87. error cleared then replaced on failure;
88. error userInfo contains only two allowed keys;
89. no raw value in error text/userInfo;
90. no filesystem access;
91. no artifact hashing;
92. no archive inspection;
93. no version support enforcement;
94. no requested bundle matching;
95. no Restore caller integration;
96. no Backup writer integration;
97. no Makefile change;
98. no existing production references;
99. `git diff --check` passes;
100. no NUL/generated/binary artifacts.

Do not claim runtime or device execution that did not occur.

---

# Part 24 — Required report

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.1-REPORT.md
```

The report must include:

1. baseline HEAD and initial status;
2. exact files changed;
3. protected-file SHA-256 before/after;
4. public API and error constants;
5. error-code and field-path contract;
6. graph-safety algorithm and limits;
7. cycle/shared-subobject behavior;
8. deterministic validation order;
9. primitive string/Boolean/integer rules;
10. complete required root schema;
11. every nested-section schema;
12. duplicate policies;
13. cross-field consistency rules;
14. unknown-field policy;
15. proof that versions `1/2/3/999` are not rejected solely by value;
16. proof no supported-version set exists;
17. proof no requested-bundle comparison exists;
18. proof no filesystem/process/artifact/archive access exists;
19. proof no existing caller imports/references the validator;
20. full focused source diff;
21. declaration/implementation counts;
22. forbidden-token audit;
23. scenario matrix with at least the 100 cases above;
24. whitespace, CRLF/LF, NUL and generated-artifact audit;
25. build status and remaining risks.

Report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

---

# Part 25 — Required verification

Before commit:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git diff --check
git diff --stat -- PXBackupManifestValidator.h PXBackupManifestValidator.m
git diff -- PXBackupManifestValidator.h PXBackupManifestValidator.m
git diff --exit-code -- <all protected production files>
```

Required source gates:

```text
PXBackupManifestValidator interface declarations: 1
validateManifestObject:error: declarations: 1
validateManifestObject:error: implementations: 1
error domain definitions: 1
field-path key definitions: 1
error enum cases: exactly 6
instance mutable properties: 0
filesystem tokens: 0
process/shell tokens: 0
Security/UIKit/defaults/dispatch tokens: 0
AppDataBackupManager references: 0
supported-version constants/checks: 0
requested bundle argument/comparison: 0
existing production references outside new files: 0
Makefile diff: 0
```

After commit:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 92b051fcc2e32193cf3e5b8837784e08b9ad1961..HEAD --check
git diff --name-status 92b051fcc2e32193cf3e5b8837784e08b9ad1961..HEAD
```

Implementation commit may contain only:

```text
PXBackupManifestValidator.h
PXBackupManifestValidator.m
docs/backup-restore-hardening/reports/TASK-2.1-REPORT.md
```

---

# Stop condition

Stop after TASK-2.1.

Do not implement TASK-2.2.

Do not integrate the validator into `readManifestAtBackupDirectory:` or `restoreBackupAtDirectory:`.

Do not enforce supported manifest versions.

Do not enforce requested bundle identity.

Do not inspect artifact files or archive entries.
