# TASK-2.7 — Build Immutable PXRestorePlan

- Status: READY
- Phase: 2 — Restore Preflight and Transaction
- Baseline: `2bb8473bd16ac097ae03d0e83e42b28987af1495`
- Previous tasks: TASK-2.6 and TASK-2.6A source review ACCEPTED
- Next task: TASK-2.8 remains LOCKED

## Objective

Build one immutable semantic Restore plan immediately after the accepted manifest, destination, artifact and archive preflight snapshots.

Today `restoreBackupAtDirectory:bundleID:appName:completion:` continues reading the mutable manifest dictionary and calling `PXVerifiedBackupArtifactSet` throughout the operational half of Restore. Component inclusion flags, archive names, source paths, relative destination identities, Keychain choices and warning/profile metadata are recomputed at many later mutation sites.

TASK-2.7 must freeze that information into one `PXRestorePlan` before warnings, debug writes, tar discovery, process termination, staging, extraction or target mutation.

The plan is an immutable semantic snapshot. It is not staging, extracted-tree validation, transaction commit, rollback or a structured Restore result.

## Production scope

Create:

```text
PXRestorePlan.h
PXRestorePlan.m
```

Modify:

```text
AppDataBackupManager.m
```

Create report:

```text
docs/backup-restore-hardening/reports/TASK-2.7-REPORT.md
```

Suggested commit subject:

```text
phase2(task-2.7): build immutable restore plan
```

Implementation commit may contain only:

```text
PXRestorePlan.h
PXRestorePlan.m
AppDataBackupManager.m
docs/backup-restore-hardening/reports/TASK-2.7-REPORT.md
```

## Protected production files

Do not modify:

```text
AppDataBackupManager.h
PXBackupManifestValidator.h
PXBackupManifestValidator.m
PXBackupArtifactVerifier.h
PXBackupArtifactVerifier.m
PXBackupArchiveValidator.h
PXBackupArchiveValidator.m
PXResolvedContainer.h
PXResolvedContainer.m
PXDataContainerResolver.h
PXDataContainerResolver.m
PXDestructivePathValidator.h
PXDestructivePathValidator.m
AppEntitlementsReader.h
AppEntitlementsReader.m
AppGroupContainerResolver.h
AppGroupContainerResolver.m
AppDataCleaner.h
AppDataCleaner.m
CommandRunner.h
CommandRunner.m
Makefile
UI/controller files
Keychain helper/bridge files
```

Do not edit coordinator task/review/status/roadmap/decisions/README files.

## Baseline evidence

Before modifying source, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -3 --oneline
```

Record SHA-256 before/after for every protected production file.

# Part 1 — Exact public API

Create `PXRestorePlan.h` with this exact public surface:

```objc
#import <Foundation/Foundation.h>

@class PXResolvedContainer;
@class PXVerifiedBackupArtifactSet;
@class PXValidatedBackupArchiveSet;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXRestorePlanErrorDomain;
FOUNDATION_EXPORT NSString * const PXRestorePlanErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXRestorePlanErrorCode) {
    PXRestorePlanErrorInvalidInput = 1,
    PXRestorePlanErrorInconsistentSnapshot = 2,
    PXRestorePlanErrorMissingArtifact = 3,
    PXRestorePlanErrorUnvalidatedArchive = 4,
    PXRestorePlanErrorUnsafeRelativeDestination = 5,
    PXRestorePlanErrorDuplicateDestination = 6,
    PXRestorePlanErrorInvalidComponent = 7,
    PXRestorePlanErrorLimitExceeded = 8,
};

__attribute__((objc_subclassing_restricted))
@interface PXRestorePlanAppGroupItem : NSObject <NSCopying>
@property (nonatomic, copy, readonly) NSString *groupIdentifier;
@property (nonatomic, copy, readonly) NSString *archiveName;
@property (nonatomic, copy, readonly) NSString *sourcePath;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

__attribute__((objc_subclassing_restricted))
@interface PXRestorePlanSystemGlobalItem : NSObject <NSCopying>
@property (nonatomic, copy, readonly) NSString *librarySubdirectory;
@property (nonatomic, copy, readonly) NSString *archiveName;
@property (nonatomic, copy, readonly) NSString *sourcePath;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

__attribute__((objc_subclassing_restricted))
@interface PXRestorePlanSharedDatabaseItem : NSObject <NSCopying>
@property (nonatomic, copy, readonly) NSString *libraryRelativePath;
@property (nonatomic, copy, readonly) NSString *artifactName;
@property (nonatomic, copy, readonly) NSString *sourcePath;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

__attribute__((objc_subclassing_restricted))
@interface PXRestorePlan : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *bundleIdentifier;

@property (nonatomic, strong, readonly) PXResolvedContainer *applicationDataContainer;
@property (nonatomic, copy, readonly) NSString *applicationDataPath;
@property (nonatomic, copy, readonly) NSString *applicationDataUUID;
@property (nonatomic, copy, readonly) NSString *dataArchiveName;
@property (nonatomic, copy, readonly) NSString *dataArchivePath;

@property (nonatomic, assign, readonly) BOOL includesAppGroups;
@property (nonatomic, copy, readonly) NSArray<PXRestorePlanAppGroupItem *> *appGroupItems;
- (nullable PXRestorePlanAppGroupItem *)appGroupItemForIdentifier:(NSString *)groupIdentifier;

@property (nonatomic, assign, readonly) BOOL includesPreferences;
@property (nonatomic, copy, nullable, readonly) NSString *preferencesArtifactName;
@property (nonatomic, copy, nullable, readonly) NSString *preferencesSourcePath;

@property (nonatomic, assign, readonly) BOOL includesKeychain;
@property (nonatomic, copy, nullable, readonly) NSString *keychainArtifactName;
@property (nonatomic, copy, nullable, readonly) NSString *keychainSourcePath;
@property (nonatomic, copy, readonly) NSArray<NSString *> *keychainGroups;
@property (nonatomic, copy, readonly) NSString *keychainMethod;
@property (nonatomic, assign, readonly) BOOL keychainUsesInAppMethod;

@property (nonatomic, assign, readonly) BOOL includesProfileAppData;
@property (nonatomic, copy, nullable, readonly) NSString *profileAppDataArchiveName;
@property (nonatomic, copy, nullable, readonly) NSString *profileAppDataSourcePath;

@property (nonatomic, assign, readonly) BOOL includesGlobalSafari;
@property (nonatomic, copy, nullable, readonly) NSString *globalSafariArchiveName;
@property (nonatomic, copy, nullable, readonly) NSString *globalSafariSourcePath;

@property (nonatomic, copy, readonly) NSArray<PXRestorePlanSystemGlobalItem *> *systemGlobalItems;
@property (nonatomic, copy, readonly) NSArray<PXRestorePlanSharedDatabaseItem *> *sharedDatabaseItems;

@property (nonatomic, assign, readonly) NSUInteger manifestWarningCount;
@property (nonatomic, copy, nullable, readonly) NSString *manifestProfileIdentifier;

@property (nonatomic, strong, readonly) PXVerifiedBackupArtifactSet *verifiedArtifacts;
@property (nonatomic, strong, readonly) PXValidatedBackupArchiveSet *validatedArchives;

+ (nullable instancetype)planForManifest:(NSDictionary *)manifest
               requestedBundleIdentifier:(NSString *)bundleIdentifier
                 applicationDataContainer:(PXResolvedContainer *)applicationDataContainer
                      applicationDataPath:(NSString *)applicationDataPath
                        verifiedArtifacts:(PXVerifiedBackupArtifactSet *)verifiedArtifacts
                        validatedArchives:(PXValidatedBackupArchiveSet *)validatedArchives
                                    error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
```

Do not add:

- mutable setters;
- public designated initializers;
- filesystem or resolver arguments;
- a tar executable;
- staging paths;
- transaction/rollback methods;
- extraction methods;
- warning-mode or bypass flags;
- a generic mutable dictionary payload;
- a structured Restore result.

# Part 2 — Immutable object contract

All four public classes must:

- be `objc_subclassing_restricted`;
- copy every string/array/dictionary initializer input;
- expose readonly properties only;
- return `self` from `copyWithZone:`;
- reject ordinary `init` and `new`;
- contain no mutable collection after construction;
- contain no callback, descriptor, parser, resolver, command runner or lazy lookup cache.

`PXRestorePlan` must retain the accepted immutable snapshots:

```text
PXResolvedContainer
PXVerifiedBackupArtifactSet
PXValidatedBackupArchiveSet
```

The plan must not retain the manifest dictionary itself.

`appGroupItemForIdentifier:` must return nil for nil, non-string, empty or unknown values and must perform exact case-sensitive lookup.

# Part 3 — Error contract

Clear `*error` at public entry.

Success:

```text
plan != nil
error == nil
```

Failure:

```text
plan == nil
error domain == PXRestorePlanErrorDomain
error code == one of the exact eight public codes
```

`userInfo` may contain only:

```text
NSLocalizedDescriptionKey
PXRestorePlanErrorFieldPathKey
```

Stable field paths include:

```text
$
$.data.archive
$.appGroups[2].archive
$.systemGlobalLibrary.items[1].subdir
$.sharedSystemDB.files[3].libraryRel
$.keychain.groupsSelected
```

Do not expose in errors or logs:

- bundle ID value;
- artifact name or source path;
- application-data path/UUID;
- App Group ID/path;
- Keychain group values;
- relative destination value;
- manifest excerpt;
- nested verifier/validator errors.

# Part 4 — Pure semantic builder boundary

`PXRestorePlan.m` may import only:

```objc
#import "PXRestorePlan.h"
#import "PXResolvedContainer.h"
#import "PXBackupArtifactVerifier.h"
#import "PXBackupArchiveValidator.h"
```

It may use Foundation.

Forbidden in `PXRestorePlan.m`:

```text
UIKit
AppDataBackupManager
AppDataCleaner
AppEntitlementsReader
AppGroupContainerResolver
PXDataContainerResolver
PXDestructivePathValidator
CommandRunner
NSFileManager
fileExistsAtPath
contentsOfDirectoryAtPath
dictionaryWithContentsOfFile
realpath/open/openat/stat/lstat/fstat
NSTask/posix_spawn/system/popen
dispatch
NSUserDefaults
Security/Keychain
filesystem mutation
shell construction
logging
```

The builder consumes only already accepted in-memory snapshots. It must not re-read or revalidate files.

# Part 5 — Input and snapshot consistency

Require runtime-valid:

- manifest `NSDictionary`;
- requested bundle nonempty NUL-free `NSString`;
- exact manifest bundle ID equality with requested bundle ID;
- `PXResolvedContainer` instance of kind ApplicationData;
- model requested identifier and metadata identifier exact-equal requested bundle ID;
- nonempty model UUID/path;
- supplied applicationDataPath exact-equal model.containerPath;
- non-nil `PXVerifiedBackupArtifactSet`;
- non-nil `PXValidatedBackupArchiveSet`.

Do not normalize, trim, case-fold or replace any identity.

Snapshot mismatch must fail with `InconsistentSnapshot` and a stable field path.

# Part 6 — Artifact and archive consistency helpers

Add private helpers equivalent to:

```text
verified source lookup by exact artifact name
validated tar-archive membership check
```

For every included source artifact:

1. artifact name must be a runtime-valid nonempty string;
2. `[verifiedArtifacts pathForArtifactName:name]` must return a nonempty path;
3. copy exact name and exact source path into the plan.

For every tar source:

```text
data
appGroups
profileAppData
globalSafari
systemGlobalLibrary
```

also require:

```objc
[validatedArchives containsArchiveName:name] == YES
```

Preferences, Keychain and shared-system DB files require verified artifacts but are not tar-member validated.

Do not reconstruct source paths from backup directory or recorded `artifact.path`.

# Part 7 — Main ApplicationData plan

Main data is always included.

Freeze:

```text
applicationDataContainer
applicationDataPath
applicationDataUUID
data.archive exact name
data verified source path
```

Require the data archive to be present in both accepted snapshots:

```text
verifiedArtifacts
validatedArchives
```

Do not read or authorize manifest `data.containerPath` or `data.uuid`.

# Part 8 — App Group semantic plan

Read `options.includeAppGroups` as exact CFBoolean from the already validated manifest.

If false:

```text
includesAppGroups == NO
appGroupItems == empty
```

If true:

- build one item for every `manifest.appGroups[i]` in original array order;
- copy exact `groupID`, archive name and verified source path;
- require archive membership in `validatedArchives`;
- reject duplicate exact group identifier defensively;
- create an immutable exact group-ID lookup map;
- do not read recorded group UUID for authority;
- do not resolve installed App Group destinations;
- do not read entitlements;
- do not skip a manifest item silently.

TASK-2.9 still owns exact App Group destination validation and staging.

# Part 9 — Preferences semantic plan

Use exact `preferences.included`.

If excluded:

```text
includesPreferences == NO
preferencesArtifactName == nil
preferencesSourcePath == nil
```

If included:

- require exact artifact name;
- require verified source path;
- freeze both;
- do not compute the destination plist path in `PXRestorePlan.m`.

# Part 10 — Keychain semantic plan

Use exact `keychain.included`.

If excluded:

```text
includesKeychain == NO
artifact/source == nil
keychainGroups == empty
keychainMethod == empty string
keychainUsesInAppMethod == NO
```

If included:

- require verified source artifact;
- copy exact `groupsSelected` array;
- copy method when present, otherwise empty string;
- freeze current method decision exactly:

```text
keychainUsesInAppMethod ==
    method == "in_app"
    OR any selected group contains "platformFamily"
```

Preserve current case-sensitive substring behavior. Do not broaden or normalize Keychain groups.

Do not execute or validate Keychain contents in this task.

# Part 11 — Profile AppData and Global Safari plan

For each section, use exact `included` Boolean.

If excluded, corresponding archive/source properties are nil.

If included:

- require verified source artifact;
- require archive membership in `validatedArchives`;
- freeze archive name/source path;
- ignore recorded manifest `path` for destination authority;
- do not compute or validate current device destination in `PXRestorePlan.m`.

TASK-2.10 owns staging and destination validation for these optional components.

# Part 12 — System-global semantic items

`systemGlobalLibrary` remains optional additive schema.

Absent or excluded:

```text
systemGlobalItems == empty
```

Included:

- preserve original items array order;
- require exact verified and archive-validated source for each item;
- freeze exact archive name/source path;
- freeze a safe single-component `librarySubdirectory`.

Safe system-global subdirectory policy:

- runtime NSString;
- nonempty and non-whitespace;
- no NUL or ASCII control characters;
- no `/` or `\`;
- not `.` or `..`;
- UTF-8 byte length <= 255;
- no trimming, case folding or Unicode normalization.

Reject duplicate exact subdirectory at the later item.

Do not combine with `/var/mobile/Library` in `PXRestorePlan.m`.

# Part 13 — Shared-system database semantic items

`sharedSystemDB` remains optional additive schema.

Absent or excluded:

```text
sharedDatabaseItems == empty
```

Included:

- preserve original files array order;
- require exact verified source artifact;
- freeze artifact name/source path;
- freeze safe `libraryRelativePath`.

Safe relative library path policy:

- runtime NSString;
- nonempty and non-whitespace;
- no NUL/control characters;
- no leading or trailing slash;
- no backslash;
- no doubled slash;
- every component nonempty and not `.` or `..`;
- each component UTF-8 length <= 255;
- full UTF-8 length <= 4096;
- no normalization, standardization or percent decoding.

Reject duplicate exact relative path at the later item.

Do not combine with mobile Library base in `PXRestorePlan.m`.

# Part 14 — Warning and profile metadata

Freeze only the current semantic values needed later:

```text
manifestWarningCount
manifestProfileIdentifier
```

`manifestWarningCount` equals the validated warnings array count, or zero if absent.

`manifestProfileIdentifier` is an exact copied nonempty string or nil.

Do not copy warning text into the plan and do not log manifest values.

# Part 15 — Fixed plan limits

Use one private fixed maximum:

```text
maximum total item records across appGroups + systemGlobalItems + sharedDatabaseItems: 100000
```

Use overflow-safe addition before allocation/append.

Boundary:

```text
100000 -> accepted
100001 -> LimitExceeded
```

Do not expose a configurable limit.

# Part 16 — Restore integration and ordering

Add exactly one import to `AppDataBackupManager.m`:

```objc
#import "PXRestorePlan.h"
```

In Restore, call the plan factory exactly once immediately after TASK-2.6 archive validation succeeds and before warnings allocation:

```objc
NSError *planError = nil;
__attribute__((objc_precise_lifetime))
PXRestorePlan *restorePlan =
    [PXRestorePlan planForManifest:manifest
         requestedBundleIdentifier:bundleID
           applicationDataContainer:dataContainerModel
                applicationDataPath:dataContainerPath
                  verifiedArtifacts:verifiedArtifacts
                  validatedArchives:validatedArchives
                              error:&planError];
```

If nil:

- propagate exact non-nil plan error;
- complete once on the main queue;
- result nil;
- return immediately.

A generic plan-domain fallback is allowed only for impossible nil-without-error state.

Required order:

```text
manifest/schema/version
exact bundle identity
exact main destination
artifact verifier
archive validator
restore plan
warnings/debug/runner/tar/kill/staging/extraction/mutation
```

Plan failure must precede all operational setup.

# Part 17 — Operational code consumes plan only

After successful plan construction, the operational remainder of Restore must have:

```text
direct manifest[...] reads: 0
direct verifiedArtifacts pathForArtifactName: calls: 0
direct validatedArchives containsArchiveName: calls: 0
```

Use plan properties instead.

Required migrations:

- main data source -> `restorePlan.dataArchivePath`;
- main target/model/UUID -> plan properties;
- manifest warning count -> plan property;
- manifest profile ID -> plan property;
- include App Groups -> plan property;
- group archive lookup -> `appGroupItemForIdentifier:`;
- profile source -> plan properties;
- global Safari source -> plan properties;
- system-global loop -> plan item array;
- shared-DB loop -> plan item array;
- preferences source -> plan properties;
- Keychain source/groups/method/use-in-app -> plan properties.

The local variables `manifest`, `verifiedArtifacts` and `validatedArchives` may remain alive for construction but must not provide later operational authority.

# Part 18 — Preserve current dynamic destination behavior

TASK-2.7 freezes semantic intent but does not redesign destination discovery.

After the plan exists, preserve current behavior for:

- App Entitlements reader;
- legacy `resolveGroupContainersForGroupIDs:` call;
- mapping resolved group ID to a planned item;
- warning-and-skip when an installed/resolved group has no planned item;
- profile AppData destination helper;
- global Safari destination helper;
- mobile Library base helper;
- preferences destination helper;
- Keychain execution path;
- system/global destination combination from safe plan identities.

Do not move App Group exact destination validation into TASK-2.7. TASK-2.9 owns it.

Do not claim that semantic relative destination validation authorizes the final filesystem target. TASK-2.8 through TASK-2.10 own staging and destination validation.

# Part 19 — Preserve Restore behavior

Do not change:

- public Restore signature;
- error codes 200/201/300/301/303/304/307–318;
- warning-only entitlement failures;
- tar executable preference;
- process-kill timing after plan success;
- main staging layout;
- extraction helpers;
- main pre-mutation destination revalidation;
- wipe/clone/cp/chown semantics;
- profile/global/App Group/system/shared DB ordering;
- preferences permissions;
- Keychain warning-only failure;
- post-restore verification;
- `PXRestoreResult` output.

The only behavioral tightening in this task is fail-closed plan construction for inconsistent snapshots or unsafe manifest-derived relative destination identities.

# Part 20 — TASK-2.8 and later boundaries

Do not:

- stage or validate main extracted data beyond current behavior;
- modify staging layout;
- stage App Groups;
- stage optional components;
- add target quarantine;
- commit or roll back any component;
- retain open descriptors in the plan;
- add transaction IDs;
- add structured component results;
- change UI;
- change Backup publication.

These remain TASK-2.8 through TASK-2.14 and later phases.

# Part 21 — Non-regression body hashes

Record before/after body hashes for at least:

```text
PXBackupManifestVersionIsSupported
PXResolveExactRestoreApplicationDataTarget
readManifestAtBackupDirectory:error:
createBackupForBundleID:appName:options:completion:
_tarExtract:archive:toDir:
_tarExtractDataArchive:archive:toDir:warnings:
_directoryHasRestoredContent:
```

All must be equal.

Also prove zero diff for all accepted validator/verifier source files.

# Part 22 — Final static gates

## Scope

```text
PXRestorePlan.h added
PXRestorePlan.m added
AppDataBackupManager.m modified
report added
all other production diffs = 0
```

## Public API

```text
plan error-domain exports = 1
field-path exports = 1
error codes = exactly 8
public item classes = exactly 3
public plan classes = exactly 1
public plan factory methods = exactly 1
public mutable setters = 0
```

## Pure plan source

```text
filesystem APIs = 0
resolver APIs = 0
CommandRunner = 0
shell/process = 0
dispatch = 0
Security/Keychain execution = 0
logging = 0
manifest retained as property/ivar = 0
```

## Plan semantics

```text
main artifact verified = 1
main archive validated = 1
app-group tar validation present
profile/global tar validation present
system-global tar validation present
preferences/keychain/shared DB verified-only policy present
recorded data path/UUID authority = 0
recorded optional path authority = 0
safe system subdirectory policy present
safe shared-DB relative path policy present
total item limit = 100000
```

## Restore integration

```text
PXRestorePlan import = 1
plan factory calls in Restore = 1
plan factory calls in Backup = 0
plan follows archive validator
plan precedes warnings/runner/debug/tar/kill/staging/extraction/mutation
exact plan NSError propagation present
post-plan direct manifest reads = 0
post-plan verified-artifact lookups = 0
post-plan archive-set lookups = 0
```

# Part 23 — Scenario matrix

Report must include at least 125 explicit scenario rows, including:

1. valid v2 semantic plan;
2. valid v3 semantic plan;
3. exact bundle mismatch snapshot;
4. wrong container kind;
5. container requested identifier mismatch;
6. container metadata identifier mismatch;
7. supplied path differs from model path;
8. missing verified set;
9. missing archive set;
10. main data artifact missing;
11. main data archive not validated;
12. groups excluded;
13. groups included empty;
14. one valid App Group item;
15. multiple App Group items preserve manifest order;
16. duplicate group identifier rejected;
17. App Group source missing;
18. App Group archive unvalidated;
19. recorded App Group UUID ignored;
20. preferences excluded;
21. preferences included valid;
22. preferences source missing;
23. Keychain excluded;
24. Keychain included helper method;
25. Keychain method `in_app`;
26. platformFamily suffix triggers in-app;
27. platformFamily substring triggers in-app;
28. case-sensitive platformFamily behavior preserved;
29. Keychain groups copied immutably;
30. profile excluded;
31. profile included valid;
32. profile recorded path ignored;
33. profile archive unvalidated;
34. global Safari excluded;
35. global Safari included valid;
36. global recorded path ignored;
37. absent system-global section;
38. excluded system-global section;
39. included system-global item;
40. system subdir with slash rejected;
41. system subdir with backslash rejected;
42. system subdir dot rejected;
43. system subdir dot-dot rejected;
44. system subdir control rejected;
45. system subdir >255 bytes rejected;
46. duplicate system subdir rejected;
47. system item source missing;
48. system item archive unvalidated;
49. absent shared DB section;
50. excluded shared DB section;
51. valid nested shared DB relative path;
52. absolute shared DB path rejected;
53. leading slash rejected;
54. trailing slash rejected;
55. doubled slash rejected;
56. backslash rejected;
57. dot component rejected;
58. dot-dot component rejected;
59. control rejected;
60. component >255 rejected;
61. full path >4096 rejected;
62. duplicate shared DB relative path rejected;
63. shared DB source missing;
64. shared DB does not require tar validation;
65. preferences does not require tar validation;
66. Keychain does not require tar validation;
67. manifest warnings absent;
68. manifest warnings count copied;
69. profile ID absent;
70. profile ID copied;
71. plan does not retain manifest;
72. plan retains verified snapshot;
73. plan retains archive snapshot;
74. plan retains data model;
75. item strings copied;
76. arrays copied;
77. copyWithZone returns self for plan;
78. copyWithZone returns self for App Group item;
79. copyWithZone returns self for system item;
80. copyWithZone returns self for shared DB item;
81. group lookup nil input;
82. group lookup empty input;
83. group lookup unknown input;
84. group lookup exact case-sensitive match;
85. total item count 100000 accepted;
86. total item count 100001 rejected;
87. total-count overflow rejected;
88. error userInfo keys restricted;
89. error omits bundle value;
90. error omits artifact value;
91. error omits source path;
92. error omits relative destination value;
93. builder clears error;
94. success leaves error nil;
95. plan failure before warnings;
96. plan failure before CommandRunner;
97. plan failure before debug write;
98. plan failure before tar discovery;
99. plan failure before process kill;
100. plan failure before staging;
101. plan failure before extraction;
102. plan failure before mutation;
103. exact plan error propagated;
104. impossible nil-error fallback;
105. post-plan manifest reads zero;
106. post-plan verified lookup zero;
107. post-plan archive lookup zero;
108. main source uses plan;
109. App Group source uses plan lookup;
110. profile source uses plan;
111. global source uses plan;
112. system loop uses plan items;
113. shared DB loop uses plan items;
114. preferences source uses plan;
115. Keychain source/groups/method use plan;
116. existing App Group destination resolver retained;
117. existing profile destination helper retained;
118. existing global destination helper retained;
119. existing mobile Library helper retained;
120. extraction helper hashes unchanged;
121. destination helper unchanged;
122. artifact/archive validators unchanged;
123. Makefile unchanged;
124. UI unchanged;
125. TASK-2.8 remains unimplemented.

Add deterministic ordering, optional-section combinations, Unicode and error-cleanup cases as needed.

# Part 24 — Report requirements

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.7-REPORT.md
```

Report must include:

- baseline and exact scope;
- protected SHA-256 before/after;
- exact public API and eight-code enum;
- immutability proof for all four classes;
- no-manifest-retention proof;
- input/snapshot consistency matrix;
- artifact/archive consistency proof by component;
- App Group semantic plan;
- Keychain decision proof;
- safe system/shared relative destination proof;
- fixed item-limit proof;
- Restore ordering;
- exact plan NSError propagation;
- post-plan authority-zero counts;
- operational source migration inventory;
- preserved dynamic destination behavior;
- TASK-2.1 through TASK-2.6A non-regression;
- extraction/helper body hashes;
- TASK-2.8 boundary;
- full production diff;
- static/forbidden counts;
- at least 125 explicit scenarios;
- whitespace/CRLF/NUL/generated-artifact audit;
- build status and remaining runtime risks.

Report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Part 25 — Verification

Before commit:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git diff --check
git diff --stat -- PXRestorePlan.h PXRestorePlan.m AppDataBackupManager.m
git diff -- PXRestorePlan.h PXRestorePlan.m AppDataBackupManager.m
git diff --exit-code -- <protected files>
```

After commit:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 2bb8473bd16ac097ae03d0e83e42b28987af1495..HEAD --check
git diff --name-status 2bb8473bd16ac097ae03d0e83e42b28987af1495..HEAD
```

Stop after TASK-2.7.

Do not implement TASK-2.8.
