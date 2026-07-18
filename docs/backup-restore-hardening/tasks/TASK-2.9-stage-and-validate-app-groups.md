# TASK-2.9 — Stage and Validate App Group Restore Targets

- Status: READY
- Phase: 2 — Restore Preflight and Transaction
- Baseline: `9aaa575c7ce0e62aeb155c459879043e1ea5acfb`
- Previous task: TASK-2.8 source review ACCEPTED
- Next task: TASK-2.10 remains LOCKED

## Objective

Replace the current legacy App Group Restore path with exact signed-entitlement authorization, typed rootful/rootless destination resolution, canonical destructive-path validation and per-physical-target staged-tree validation.

Current Restore still:

- reads App Group entitlements but treats read failure as warning-only;
- calls the legacy aggregate `resolveGroupContainersForGroupIDs:` API;
- trusts mutable `AppGroupContainerInfo.path` values;
- wipes an App Group target before validating extracted content;
- extracts the backup archive directly into the target;
- can restore the same physical App Group container multiple times when metadata contains several exact group identities.

TASK-2.9 must build one immutable exact App Group target plan before main target mutation, then stage and validate each physical target's planned archive content before that App Group target is wiped.

This task is not App Group transaction/rollback. It does not quarantine the old target or restore it after a failed clone. TASK-2.12 retains transactional App Group commit and rollback.

## Production scope

Create:

```text
PXAppGroupRestoreTargetPlan.h
PXAppGroupRestoreTargetPlan.m
```

Modify:

```text
AppDataBackupManager.m
```

Create report:

```text
docs/backup-restore-hardening/reports/TASK-2.9-REPORT.md
```

Suggested commit subject:

```text
phase2(task-2.9): stage and validate app groups
```

Implementation commit may contain only:

```text
PXAppGroupRestoreTargetPlan.h
PXAppGroupRestoreTargetPlan.m
AppDataBackupManager.m
docs/backup-restore-hardening/reports/TASK-2.9-REPORT.md
```

## Protected production files

Do not modify:

```text
AppDataBackupManager.h
PXMainDataStaging.h
PXMainDataStaging.m
PXRestorePlan.h
PXRestorePlan.m
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

Create `PXAppGroupRestoreTargetPlan.h` with this exact public surface:

```objc
#import <Foundation/Foundation.h>

@class PXRestorePlan;
@class PXRestorePlanAppGroupItem;
@class PXResolvedContainer;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXAppGroupRestoreTargetPlanErrorDomain;
FOUNDATION_EXPORT NSString * const PXAppGroupRestoreTargetPlanErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXAppGroupRestoreTargetPlanErrorCode) {
    PXAppGroupRestoreTargetPlanErrorInvalidInput = 1,
    PXAppGroupRestoreTargetPlanErrorInvalidEntitlementSet = 2,
    PXAppGroupRestoreTargetPlanErrorUnentitledGroup = 3,
    PXAppGroupRestoreTargetPlanErrorResolverFailed = 4,
    PXAppGroupRestoreTargetPlanErrorValidatorFailed = 5,
    PXAppGroupRestoreTargetPlanErrorMissingTarget = 6,
    PXAppGroupRestoreTargetPlanErrorAmbiguousTarget = 7,
    PXAppGroupRestoreTargetPlanErrorInconsistentPlan = 8,
    PXAppGroupRestoreTargetPlanErrorLimitExceeded = 9,
};

__attribute__((objc_subclassing_restricted))
@interface PXAppGroupRestoreTarget : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSArray<NSString *> *groupIdentifiers;
@property (nonatomic, copy, readonly) NSArray<PXResolvedContainer *> *containerModels;
@property (nonatomic, copy, readonly) NSString *canonicalPath;
@property (nonatomic, copy, readonly) NSArray<PXRestorePlanAppGroupItem *> *planItems;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PXAppGroupRestoreTargetPlan : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSArray<PXAppGroupRestoreTarget *> *targets;

+ (nullable instancetype)targetPlanForRestorePlan:(PXRestorePlan *)restorePlan
                         entitledGroupIdentifiers:(NSArray<NSString *> *)entitledGroupIdentifiers
                                            error:(NSError * _Nullable * _Nullable)error;

- (nullable PXAppGroupRestoreTarget *)targetForGroupIdentifier:(NSString *)groupIdentifier;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
```

Do not add:

- mutable setters;
- public designated initializers;
- manifest arguments;
- raw destination path arguments;
- backup-directory arguments;
- staging/extraction methods;
- CommandRunner/tar arguments;
- warning/bypass flags;
- transaction or rollback methods;
- generic mutable dictionary payloads.

# Part 2 — Immutable value contract

Both public classes must:

- be `objc_subclassing_restricted`;
- copy every array/string initializer input;
- expose readonly properties only;
- return `self` from `copyWithZone:`;
- prohibit ordinary `init` and `new`;
- contain no mutable collection after construction;
- contain no descriptor, workspace, cleanup callback, resolver, validator or command runner.

`PXAppGroupRestoreTarget` may retain immutable `PXResolvedContainer` and `PXRestorePlanAppGroupItem` objects.

`PXAppGroupRestoreTargetPlan` must have one immutable exact case-sensitive group-ID lookup map privately.

`targetForGroupIdentifier:` returns nil for:

- nil;
- non-string;
- empty;
- unknown;
- case-mismatching value.

The target plan must not retain the entitlement input array by mutable alias.

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
error domain == PXAppGroupRestoreTargetPlanErrorDomain
error code == one of the exact nine public codes
```

`userInfo` may contain only:

```text
NSLocalizedDescriptionKey
PXAppGroupRestoreTargetPlanErrorFieldPathKey
```

Stable field paths include:

```text
$
$.entitlements
$.appGroups
$.appGroups[2]
$.appGroups[2].groupIdentifier
$.appGroups[2].destination
```

Do not expose in errors or logs created by the target planner:

- bundle ID;
- group identifier value;
- canonical/raw path;
- container UUID;
- archive name/path;
- entitlement value;
- resolver/validator nested error;
- metadata excerpt;
- device/inode.

# Part 4 — Target-planner implementation boundary

`PXAppGroupRestoreTargetPlan.m` may import only:

```objc
#import "PXAppGroupRestoreTargetPlan.h"
#import "PXRestorePlan.h"
#import "PXResolvedContainer.h"
#import "AppGroupContainerResolver.h"
#import "PXDestructivePathValidator.h"
```

It may use Foundation.

Forbidden:

```text
UIKit
AppDataBackupManager
AppDataCleaner
AppEntitlementsReader
PXMainDataStaging
PXBackupArtifactVerifier
PXBackupArchiveValidator
CommandRunner
NSTask
posix_spawn/system/popen
external tar
shell construction
dispatch
Security/Keychain
NSUserDefaults
filesystem mutation
staging/extraction
logging raw values
transaction/rollback
```

The target planner may invoke only the accepted typed App Group resolver and canonical path validator. It must not enumerate or inspect the filesystem through a second local implementation.

# Part 5 — Input and plan consistency

Require:

- runtime `PXRestorePlan` instance;
- runtime `NSArray` entitlement input;
- `restorePlan.appGroupItems` runtime array;
- if `restorePlan.includesAppGroups == NO`, `appGroupItems` must be empty;
- if `restorePlan.includesAppGroups == YES`, every plan item must be a runtime `PXRestorePlanAppGroupItem`;
- each plan item group identifier, archive name and source path must be nonempty and NUL-free;
- duplicate exact plan group identifiers fail defensively;
- plan item count must not exceed the fixed maximum.

Do not reread manifest state or recompute archive source authority.

Use only:

```text
restorePlan.includesAppGroups
restorePlan.appGroupItems
```

# Part 6 — Fixed App Group planning limits

Use private fixed limits:

```text
maximum planned App Group items: 256
maximum entitlement identifiers inspected: 4096
maximum unique physical targets: 256
```

Boundaries:

```text
256 planned items accepted
257 planned items -> LimitExceeded
4096 entitlement IDs accepted
4097 entitlement IDs -> LimitExceeded
256 physical targets accepted
257 physical targets -> LimitExceeded
```

All count arithmetic must be overflow-safe before allocation/append.

Do not expose configurable limits.

# Part 7 — Exact entitlement set

The manager reads signed App Group entitlements exactly once and passes the copied result to the target planner.

The target planner must validate every entitlement element:

- runtime NSString;
- nonempty;
- contains non-whitespace text;
- no NUL;
- no duplicate exact identifier.

Do not trim, lowercase, normalize, prefix-match or substring-match.

For every planned App Group item:

```text
exact group identifier must exist in signed entitlement set
```

A planned unentitled group fails `UnentitledGroup` at the later plan-item field path.

Extra entitled groups not present in the Restore plan are ignored. They do not create targets and do not generate mutation work.

If App Groups are excluded and plan items are empty, return an empty target plan without requiring a nonempty entitlement list.

# Part 8 — Typed rootful/rootless resolution

For each planned group identifier, instantiate/use `AppGroupContainerResolver` and call exactly once per root:

```objc
resolveAppGroupContainerForGroupIdentifier:root:error:
```

Order:

```text
rootful
rootless
```

Rules:

- nil with nil error means absent in that root;
- any resolver error in either root fails the entire target plan;
- do not continue with the other result after an error;
- do not call legacy `resolveGroupContainersForGroupIDs:`;
- do not use `AppGroupContainerInfo`;
- do not reconstruct a path from a recorded UUID;
- do not use manifest App Group UUID;
- do not choose first/newest/arbitrary filesystem match.

# Part 9 — Canonical destination validation

Every non-nil resolved model must be validated by:

```objc
PXDestructivePathValidator
validatedCanonicalPathForContainer:error:
```

Rules for one group identifier:

```text
rootful absent + rootless absent
  -> MissingTarget

one exact validated model
  -> accepted

same exact canonical path from both roots
  -> one physical target; retain models in rootful/rootless order

distinct canonical paths
  -> AmbiguousTarget

resolver error
  -> ResolverFailed

validator error or nil canonical path
  -> ValidatorFailed
```

Only validator-returned canonical paths may enter the target plan.

Do not expose nested resolver/validator errors in target-plan `NSError`.

# Part 10 — Collapse shared physical App Group targets

Several exact entitled group identifiers may legitimately map to one physical App Group container because live metadata can contain an identifier array.

Group planned items by exact validator-returned canonical path.

For each physical target:

- preserve the first plan-item occurrence order;
- preserve group identifiers in plan order;
- preserve plan items in plan order;
- preserve each group's models in rootful/rootless order;
- append all exact models associated with that physical target;
- create one target object and one target-plan lookup entry for every associated group identifier.

Do not wipe the same canonical target more than once.

Do not decide source compatibility in the target planner. Different planned archives for one shared physical target are compared after staged-tree validation in the manager.

# Part 11 — Manager entitlement and target-plan ordering

Add exactly one import:

```objc
#import "PXAppGroupRestoreTargetPlan.h"
```

In Restore, after `PXRestorePlan` success and tar selection but before main staging-workspace creation:

1. If App Groups are excluded or plan item array is empty, use `@[]` entitlements.
2. Otherwise call `applicationGroupsForBundleID:error:` exactly once.
3. Entitlement read error or a non-array result becomes a generic target-plan-domain `InvalidEntitlementSet` error at `$.entitlements`.
4. Call the target-plan factory exactly once.
5. Propagate the exact non-nil target-plan error.
6. Return before main workspace creation, first process kill or mutation on failure.

The previous warning-only behavior is removed for an included nonempty App Group plan:

```text
entitlement read failure -> hard pre-mutation failure
```

Do not include the raw entitlement error or group values in the public error.

# Part 12 — Remove legacy Restore App Group authority

Inside `restoreBackupAtDirectory:bundleID:appName:completion:`:

```text
resolveGroupContainersForGroupIDs: calls = 0
AppGroupContainerInfo variables = 0
info.path destination use = 0
info.uuid destination use = 0
legacy groupContainers array = 0
warning-and-skip for missing manifest mapping = 0
```

Keep the legacy API and class unchanged for Backup or unrelated callers.

Do not modify `AppGroupContainerResolver.h/.m`.

# Part 13 — Per-physical-target staging

At the existing App Group Restore phase, iterate:

```text
appGroupTargetPlan.targets
```

For each physical target, process all `target.planItems` before target mutation.

For every plan item:

1. Obtain exact archive name/source path from the plan item.
2. Obtain member-count and regular-file-byte summaries from:

   ```text
   restorePlan.validatedArchives.memberCountsByArchiveName[archiveName]
   restorePlan.validatedArchives.regularFileBytesByArchiveName[archiveName]
   ```

3. Validate summary numbers using the existing exact unsigned-integral helper.
4. Create one `PXMainDataStagingWorkspace`.
5. Validate its empty data directory.
6. Extract the exact planned archive source into `workspace.dataPath` using `_tarExtract:`.
7. Require extraction exit code zero.
8. Validate the complete staged tree using the accepted archive summaries.
9. Use `validatedStage.dataPath` only after validation.

Reusing the accepted `PXMainDataStagingWorkspace` implementation for App Group archive trees is allowed. Do not modify its public API or source in this task.

The workspace's root-level container metadata rejection applies to App Group staged trees as well.

# Part 14 — Shared-target source equivalence

A physical target can contain multiple planned group identifiers and therefore multiple planned archives.

Stage and validate every planned archive for the physical target before wiping it.

Retain the first successful workspace/stage as the physical target's clone source.

Every later staged source for the same physical target must match the retained stage exactly on:

```text
treeSHA256
entryCount
regularFileCount
directoryCount
regularFileBytes
```

If all fields match:

- clean the duplicate workspace;
- keep the first validated stage as clone authority;
- continue.

If any field differs:

- clean current and retained workspaces best effort;
- fail before wiping that physical target;
- use `PXAppGroupRestoreTargetPlanErrorInconsistentPlan`;
- stable field path `$.appGroups`;
- do not expose identifiers, archive names, paths or digests.

Do not choose first/last/newest conflicting content and do not apply two archives sequentially to one target.

# Part 15 — App Group staging failure behavior

Before a physical target is wiped:

- workspace creation failure propagates exact non-nil staging error;
- empty validation failure propagates exact non-nil staging error;
- staged-tree validation failure propagates exact non-nil staging error;
- summary inconsistency uses target-plan `InconsistentPlan`;
- extraction failure uses existing manager code `310` with generic description:

  ```text
  Failed to extract App Group archive to staging
  ```

Every failure cleans the current workspace and any retained workspace for that physical target.

A cleanup failure must not replace the primary error.

# Part 16 — Immediate pre-wipe target revalidation

After all sources for one physical target are staged and proven equivalent, but immediately before target wipe:

- instantiate `PXDestructivePathValidator`;
- revalidate every `target.containerModels` entry;
- require every non-nil canonical output to exact-equal `target.canonicalPath`;
- require no validator error;
- do not replace the stored canonical path with a newly returned path.

Failure:

```text
domain: PXBackupErrorDomain
code: 319
description: Exact App Group restore target could not be revalidated safely
```

Do not include group identifier, path, UUID, root or nested error.

On failure, cleanup retained staging workspace and return without wiping that target.

# Part 17 — One physical wipe and validated-stage clone

For each accepted physical target:

1. Debug may record only generic target index/count state. Do not add raw destination values to new errors.
2. Call `_wipeDirectoryContents:` exactly once with `target.canonicalPath`.
3. Clone only from the retained `validatedStage.dataPath`.
4. Prefer the current tar-pipe xattr/ACL clone when the selected tar supports it.
5. Retain the current `/usr/bin/tar` and `/bin/tar` cp-preference behavior.
6. Fall back to `cp -a` only when the tar-pipe clone fails or xattr support is unavailable.
7. On complete clone failure, cleanup staging and return manager code `310` with generic description:

   ```text
   Failed to restore validated App Group stage
   ```

8. On success, perform the current recursive `chown -R mobile:mobile` behavior on the canonical target.
9. Cleanup the retained workspace.
10. If post-clone cleanup fails, add one generic warning:

   ```text
   App Group staging cleanup failed
   ```

Do not extract the backup archive directly into the target.

After TASK-2.9:

```text
_tarExtract: archive -> App Group target calls = 0
App Group target source from validatedStage.dataPath = required
App Group target wipe before stage validation = 0
```

# Part 18 — Ordering and component boundary

Preserve the current high-level component order:

```text
main ApplicationData
profile AppData
global Safari
App Groups
system-global
shared-system DB
preferences
Keychain
```

The exact App Group target plan is built before main target mutation, but per-target App Group staging remains at the App Group component phase.

For each physical App Group target, required local order is:

```text
accepted target plan
all planned archive summaries
all planned archives staged
all staged trees validated
shared-target source equivalence proven
all target models revalidated
one target wipe
clone from retained validated stage
chown
workspace cleanup
```

A later physical target may fail after an earlier target was committed. TASK-2.12 remains responsible for transactional multi-target commit and rollback.

# Part 19 — Preserve TASK-2.8 main staging

Do not alter:

- `PXMainDataStaging.h/.m`;
- main unique workspace creation;
- main empty gate;
- main staged-tree validation;
- main summary binding;
- main first process-kill ordering;
- main target revalidation;
- main clone source;
- main cleanup behavior;
- main errors 303/316/317.

Record before/after body hashes for the main staging integration block or exact static tokens proving semantic identity outside the new App Group target-plan insertion.

# Part 20 — Non-regression

Do not change:

- public Restore signature;
- manifest/version/bundle gates;
- ApplicationData exact destination gate;
- artifact/archive validators;
- `PXRestorePlan` semantics;
- tar executable preference;
- main staging implementation;
- profile/global behavior;
- system-global/shared-DB/preferences/Keychain behavior;
- Backup behavior;
- UI;
- Makefile.

Keep existing manager codes except the new App Group target-revalidation code `319`.

# Part 21 — TASK-2.10 and transaction boundaries

Do not:

- stage profile AppData;
- stage global Safari;
- stage system-global items;
- stage shared DB files;
- stage Preferences or Keychain;
- quarantine App Group targets;
- rename/swap target directories;
- journal commits;
- roll back main or App Group targets;
- add structured component results;
- change UI;
- change Backup publication.

TASK-2.10 owns optional-component staging. TASK-2.12 owns transactional App Group commit and rollback.

# Part 22 — Non-regression body hashes

Record before/after body hashes for at least:

```text
PXBackupManifestVersionIsSupported
PXResolveExactRestoreApplicationDataTarget
readManifestAtBackupDirectory:error:
createBackupForBundleID:appName:options:completion:
_tarExtract:archive:toDir:
_tarExtractDataArchive:archive:toDir:warnings:
PXReadUnsignedIntegralSummaryNumber
```

Also prove zero diff for:

```text
PXMainDataStaging.h/.m
PXRestorePlan.h/.m
PXBackupArtifactVerifier.h/.m
PXBackupArchiveValidator.h/.m
AppEntitlementsReader.h/.m
AppGroupContainerResolver.h/.m
PXDestructivePathValidator.h/.m
Makefile
UI files
```

# Part 23 — Final static gates

## Scope

```text
PXAppGroupRestoreTargetPlan.h added
PXAppGroupRestoreTargetPlan.m added
AppDataBackupManager.m modified
report added
all other production diffs = 0
```

## Public API

```text
error-domain exports = 1
field-path exports = 1
error codes = exactly 9
target item classes = 1
target plan classes = 1
factory methods = 1
lookup methods = 1
public readwrite properties = 0
copyWithZone implementations = 2
```

## Planner boundary

```text
AppEntitlementsReader references = 0
PXMainDataStaging references = 0
CommandRunner references = 0
shell/process references = 0
staging/extraction = 0
filesystem mutation = 0
legacy aggregate resolver calls = 0
typed rootful resolver calls = 1 per plan item
typed rootless resolver calls = 1 per plan item
validator output is only canonical-path authority
```

## Restore integration

```text
planner import = 1
signed entitlement reads in Restore = 1 when needed
target-plan factory calls in Restore = 1
legacy resolveGroupContainersForGroupIDs calls in Restore = 0
AppGroupContainerInfo in Restore = 0
plan built before main workspace = yes
plan built before first process kill = yes
planned unentitled group warning/skip = 0
planned unentitled group hard failure = present
```

## App Group staging

```text
workspace creation per staged source present
empty validation per staged source present
archive summary from restorePlan present
external extraction into workspace.dataPath present
stage validation present
shared-target digest/count equivalence present
pre-wipe model revalidation present
canonical target wipe once per physical target
clone source from validatedStage.dataPath
archive direct extraction to target = 0
post-clone cleanup warning exact
```

## Limits

```text
planned item max = 256
entitlement item max = 4096
physical target max = 256
```

# Part 24 — Scenario matrix

Report must include at least 160 explicit scenario rows, including:

1. App Groups excluded and empty plan;
2. included but empty plan;
3. one planned entitled group;
4. multiple planned groups preserve plan order;
5. entitlement read success;
6. entitlement read failure hard-fails;
7. entitlement result non-array;
8. entitlement nil element;
9. entitlement non-string;
10. entitlement empty string;
11. entitlement whitespace-only;
12. entitlement NUL;
13. duplicate exact entitlement;
14. extra entitled group ignored;
15. planned exact entitlement accepted;
16. planned case mismatch rejected;
17. planned prefix match rejected;
18. planned substring match rejected;
19. planned unentitled group rejected;
20. 256 planned groups accepted;
21. 257 planned groups rejected;
22. 4096 entitlement IDs accepted;
23. 4097 entitlement IDs rejected;
24. duplicate plan group rejected;
25. invalid plan item rejected;
26. invalid plan group ID rejected;
27. invalid plan archive rejected;
28. invalid plan source rejected;
29. rootful absent/rootless absent;
30. rootful only accepted;
31. rootless only accepted;
32. rootful resolver error;
33. rootless resolver error;
34. rootful validator error;
35. rootless validator error;
36. rootful/rootless same canonical path collapsed;
37. distinct root paths rejected;
38. resolver nil without error treated absent;
39. validator nil without error rejected;
40. root order retained;
41. canonical path copied;
42. recorded App Group UUID ignored;
43. legacy resolver not called;
44. AppGroupContainerInfo not used;
45. two group IDs same physical target collapsed;
46. target first occurrence order retained;
47. group identifiers preserve plan order;
48. plan items preserve plan order;
49. models preserve root order;
50. lookup exact ID returns target;
51. lookup case mismatch returns nil;
52. lookup nil returns nil;
53. lookup empty returns nil;
54. target strings/arrays copied;
55. target copyWithZone returns self;
56. plan copyWithZone returns self;
57. plan does not retain mutable entitlement alias;
58. error clears at entry;
59. success error nil;
60. error userInfo restricted;
61. error omits group ID;
62. error omits path;
63. error omits UUID;
64. error omits nested resolver error;
65. target plan before main workspace;
66. target plan before first kill;
67. target plan failure before mutation;
68. main staging unchanged;
69. one physical target one archive stage;
70. workspace creation failure;
71. empty stage failure;
72. extraction nonzero failure;
73. stage validation failure;
74. summary missing;
75. summary Boolean rejected;
76. summary floating rejected;
77. summary negative rejected;
78. member count overflow rejected;
79. exact zero summary accepted when stage empty;
80. source from plan item only;
81. summary from restorePlan archive set only;
82. no manifest reread;
83. no backupDir path reconstruction;
84. first shared-target archive retained;
85. second equivalent archive accepted;
86. duplicate workspace cleanup;
87. equivalent tree digest but count mismatch rejected;
88. digest mismatch rejected;
89. entry count mismatch rejected;
90. regular-file count mismatch rejected;
91. directory count mismatch rejected;
92. regular-byte mismatch rejected;
93. no sequential conflicting archive application;
94. conflict before target wipe;
95. current workspace cleanup on conflict;
96. retained workspace cleanup on conflict;
97. one target model revalidated;
98. multiple target models all revalidated;
99. one model revalidation error;
100. one model canonical mismatch;
101. revalidation does not replace stored path;
102. revalidation error code 319;
103. revalidation error generic;
104. no raw group/path in revalidation error;
105. target wipe after stage validation;
106. target wiped exactly once;
107. shared physical target wiped once;
108. clone uses validatedStage.dataPath;
109. direct archive extraction to target absent;
110. tar-pipe clone success;
111. tar-pipe nonzero triggers cp fallback;
112. xattr warning triggers cp fallback;
113. system tar prefers cp;
114. cp fallback success;
115. tar and cp failure code 310;
116. clone error generic;
117. chown only after clone success;
118. cleanup after clone success;
119. cleanup failure warning exact;
120. no cleanup path in warning;
121. extraction failure cleanup;
122. validation failure cleanup;
123. revalidation failure cleanup;
124. clone failure cleanup;
125. primary failure not replaced by cleanup failure;
126. profile/global remain before App Group commit;
127. system-global remains after App Groups;
128. main data remains before App Groups;
129. later physical target may fail without rollback;
130. TASK-2.12 remains unimplemented;
131. PXMainDataStaging header unchanged;
132. PXMainDataStaging source unchanged;
133. PXRestorePlan unchanged;
134. manifest validator unchanged;
135. artifact verifier unchanged;
136. archive validator unchanged;
137. typed resolver source unchanged;
138. destructive validator unchanged;
139. AppEntitlementsReader unchanged;
140. legacy resolver remains available outside Restore;
141. Backup behavior unchanged;
142. Makefile unchanged;
143. UI unchanged;
144. Keychain unchanged;
145. profile staging not implemented;
146. global Safari staging not implemented;
147. system-global staging not implemented;
148. shared DB staging not implemented;
149. Preferences staging not implemented;
150. target quarantine absent;
151. transaction journal absent;
152. rollback absent;
153. structured result absent;
154. no shell/process in planner;
155. no filesystem mutation in planner;
156. planner fixed limits exact;
157. physical-target limit 256 accepted;
158. physical-target limit 257 rejected;
159. deterministic target ordering;
160. TASK-2.10 remains locked.

Add runtime type, overflow, Unicode, cleanup and ordering cases as needed.

# Part 25 — Report requirements

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.9-REPORT.md
```

Report must include:

- baseline and exact scope;
- protected SHA-256 before/after;
- exact public API and nine-code enum;
- immutability proof;
- entitlement-set validation;
- target planner fixed limits;
- rootful/rootless resolver matrix;
- validator/canonical path authority;
- shared physical target grouping;
- planner error privacy;
- manager ordering;
- legacy resolver removal from Restore;
- per-source workspace lifecycle;
- archive-summary integration;
- staged-tree equivalence proof;
- immediate target revalidation;
- one physical wipe/validated clone;
- cleanup path inventory;
- TASK-2.8 main staging non-regression;
- TASK-2.1 through TASK-2.8 non-regression;
- TASK-2.10/TASK-2.12 boundaries;
- full production diff;
- static/forbidden counts;
- at least 160 explicit scenario rows;
- whitespace/CRLF/NUL/generated-artifact audit;
- build status and remaining runtime risks.

Report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Part 26 — Verification

Before commit:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git diff --check
git diff --stat -- PXAppGroupRestoreTargetPlan.h PXAppGroupRestoreTargetPlan.m AppDataBackupManager.m
git diff -- PXAppGroupRestoreTargetPlan.h PXAppGroupRestoreTargetPlan.m AppDataBackupManager.m
git diff --exit-code -- <protected files>
```

After commit:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 9aaa575c7ce0e62aeb155c459879043e1ea5acfb..HEAD --check
git diff --name-status 9aaa575c7ce0e62aeb155c459879043e1ea5acfb..HEAD
```

Stop after TASK-2.9.

Do not implement TASK-2.10 or TASK-2.12.
