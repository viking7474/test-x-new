# TASK-3.6 - Introduce Manifest Schema V4

- Status: READY
- Phase: 3 - Atomic Backup Publication
- Baseline: `5366c503a3946faafc7a107c4e411255ece3e0f3`
- Suggested commit: `phase3(task-3.6): introduce backup manifest schema v4`

## Objective

Introduce one immutable, versioned Backup manifest-v4 snapshot and make both Backup and Restore understand it without changing the current manifest-file write protocol or publishing the partial Backup directory.

Manifest v4 must close the remaining schema-level gaps before atomic writing and publication:

1. artifact `path` values must be safe relative names, not absolute partial-workspace paths that become stale after directory rename;
2. the TASK-3.5 artifact policy must be persisted and structurally validated;
3. every declared artifact must have exactly one matching component reference;
4. exactly one required ApplicationData artifact must exist first;
5. aggregate count, size and checksum fields must be derived from immutable verified records;
6. one stable Backup identifier must be present for later publication;
7. factual included/excluded option reporting must be separated from the raw request dictionary;
8. v2/v3 Restore compatibility must remain unchanged.

TASK-3.6 does **not** replace `writeToFile:atomically:`, does not fsync or read back the manifest, does not rename the partial Backup workspace and does not clean failed or stale workspaces.

## Accepted foundation

The following are accepted and must be preserved:

- TASK-3.1 private partial workspace;
- TASK-3.2 per-bundle nonblocking lock;
- TASK-3.3 verified artifact writer;
- TASK-3.4 Preferences request/inclusion split;
- TASK-3.5 canonical policy model, policy-aware writer and pre-manifest policy audit;
- Phase-2 Restore validator, artifact verifier, archive validator, immutable Restore plan, staging and transaction behavior.

## Authorized production scope

Create:

```text
PXBackupManifestV4.h
PXBackupManifestV4.m
```

Modify:

```text
PXBackupManifestValidator.m
AppDataBackupManager.m
```

Create report:

```text
docs/backup-restore-hardening/reports/TASK-3.6-REPORT.md
```

The implementation commit may contain only those five files.

## Protected files

Do not modify:

```text
PXBackupManifestValidator.h
AppDataBackupManager.h
PXBackupArtifactPolicy.h/.m
PXBackupArtifactWriter.h/.m
PXBackupBundleLock.h/.m
PXBackupPublicationWorkspace.h/.m
PXRestoreResult.h/.m
PXBackupArtifactVerifier.h/.m
PXBackupArchiveValidator.h/.m
PXRestorePlan.h/.m
all Restore transaction/staging/resolver files
AppEntitlementsReader.h/.m
AppGroupContainerResolver.h/.m
CommandRunner.h/.m
Makefile
UI/controller files
Keychain helper/bridge/script files
coordinator docs other than TASK-3.6-REPORT.md
```

## Baseline evidence

Record before editing:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -5 --oneline
git diff --check
```

Record SHA-256 before and after for every protected production file.

# Part 1 - Exact public v4 API

Create `PXBackupManifestV4.h`.

Export exactly:

```objc
FOUNDATION_EXPORT NSInteger const PXBackupManifestV4Version;
FOUNDATION_EXPORT NSString * const PXBackupManifestV4SchemaIdentifier;
FOUNDATION_EXPORT NSInteger const PXBackupManifestV4SchemaRevision;
FOUNDATION_EXPORT NSString * const PXBackupManifestV4DigestAlgorithm;
FOUNDATION_EXPORT NSString * const PXBackupManifestV4PublicationProtocol;
FOUNDATION_EXPORT NSString * const PXBackupManifestV4ContentStateComplete;

FOUNDATION_EXPORT NSErrorDomain const PXBackupManifestV4ErrorDomain;
FOUNDATION_EXPORT NSString * const PXBackupManifestV4ErrorFieldPathKey;
```

Exact values:

```text
version:              4
schema identifier:    com.hydra.projectx.backup-manifest
schema revision:      1
digest algorithm:     sha256
publication protocol: atomic-directory-v1
content state:        complete
```

Define exactly fourteen errors without gaps or aliases:

```objc
typedef NS_ERROR_ENUM(PXBackupManifestV4ErrorDomain,
                      PXBackupManifestV4ErrorCode) {
    PXBackupManifestV4ErrorInvalidInput = 1,
    PXBackupManifestV4ErrorInvalidBackupIdentifier = 2,
    PXBackupManifestV4ErrorInvalidFieldSet = 3,
    PXBackupManifestV4ErrorInvalidFieldValue = 4,
    PXBackupManifestV4ErrorInvalidArtifact = 5,
    PXBackupManifestV4ErrorInvalidArtifactPolicy = 6,
    PXBackupManifestV4ErrorInvalidArtifactOrder = 7,
    PXBackupManifestV4ErrorDuplicateReference = 8,
    PXBackupManifestV4ErrorMissingReference = 9,
    PXBackupManifestV4ErrorUnreferencedArtifact = 10,
    PXBackupManifestV4ErrorMissingRequiredArtifact = 11,
    PXBackupManifestV4ErrorSizeOverflow = 12,
    PXBackupManifestV4ErrorInconsistentOptions = 13,
    PXBackupManifestV4ErrorSnapshotFailed = 14,
};
```

Forward-declare `PXVerifiedBackupArtifact`.

Create one subclassing-restricted `NSObject<NSCopying>`:

```objc
PXBackupManifestV4
```

Readonly properties:

```objc
@property (nonatomic, copy, readonly) NSString *backupIdentifier;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *manifestRepresentation;
@property (nonatomic, readonly) NSUInteger artifactCount;
@property (nonatomic, readonly) unsigned long long totalSize;
@property (nonatomic, copy, readonly) NSString *applicationDataChecksum;
```

Exact factory:

```objc
+ (nullable instancetype)
    manifestWithBackupIdentifier:(NSString *)backupIdentifier
                          fields:(NSDictionary<NSString *, id> *)fields
               verifiedArtifacts:(NSArray<PXVerifiedBackupArtifact *> *)verifiedArtifacts
                           error:(NSError * _Nullable * _Nullable)error;
```

`init` and `new` unavailable. No public initializer, mutation API, writer API, file API, serialization API or publication API.

`copyWithZone:` returns self. Equality and hash use all five semantic properties.

# Part 2 - Pure builder boundary

`PXBackupManifestV4.m` may import only:

```objc
#import "PXBackupManifestV4.h"
#import "PXBackupArtifactWriter.h"
#import "PXBackupArtifactPolicy.h"
```

plus Foundation/C headers needed for bounded graph checks.

Do not import or call:

- `AppDataBackupManager`;
- `PXBackupManifestValidator`;
- filesystem/POSIX path APIs;
- `NSFileManager`;
- process/shell APIs;
- UIKit;
- Security/Keychain;
- user defaults;
- dispatch;
- logging;
- manifest writing;
- directory publication.

The builder consumes already accepted immutable artifact records and a bounded metadata snapshot. It must not inspect artifact files again.

# Part 3 - Backup identifier

The factory requires `backupIdentifier` to be an exact lowercase UUID string:

```text
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Requirements:

- runtime `NSString`;
- exactly 36 ASCII bytes;
- lowercase hexadecimal only;
- hyphens exactly at offsets 8, 13, 18 and 23;
- no NUL/control/uppercase/whitespace;
- exact round trip through `NSUUID`;
- canonical lowercase output equals input.

Do not trim, lowercase, normalize or repair caller input.

Failure uses `PXBackupManifestV4ErrorInvalidBackupIdentifier` at `$.backupID`.

# Part 4 - Exact input field set

The `fields` dictionary must contain exactly these twenty-three keys and no others:

```text
bundleID
appName
createdAt
timestamp
iosVersion
toolVersion
toolBuild
profileId
backupMode
sourceDataContainerPath
sourceDataContainerUUID
warnings
restoreCompatibility
data
applicationGroups
appGroups
preferences
keychain
profileAppData
globalSafari
systemGlobalLibrary
sharedSystemDB
options
```

The caller must not supply derived fields:

```text
manifestVersion
schema
backupID
publication
includedOptions
excludedOptions
artifactCount
totalSize
archiveChecksum
artifacts
```

Unknown, missing or derived input keys fail with `InvalidFieldSet`.

The builder must produce an immutable deep snapshot. It must not retain caller-owned mutable arrays, dictionaries, strings, dates or data objects.

Use bounded iterative graph copying/validation:

```text
maximum graph depth:       64
maximum visited nodes:     500000
maximum dictionary keys:   100000
maximum array items:       500000
maximum string UTF-8:      1 MiB
```

Allowed graph leaves are exactly property-list-safe Foundation types already accepted by the validator:

```text
NSString
NSNumber
NSDate
NSData
NSArray
NSDictionary with NSString keys
```

Reject cycles, mutable-subclass substitution during snapshot, non-string dictionary keys and unsupported custom objects.

# Part 5 - Exact v4 root representation

`manifestRepresentation` must contain exactly thirty-three root keys:

```text
manifestVersion
schema
backupID
publication
bundleID
appName
createdAt
timestamp
iosVersion
toolVersion
toolBuild
profileId
backupMode
sourceDataContainerPath
sourceDataContainerUUID
includedOptions
excludedOptions
artifactCount
totalSize
archiveChecksum
warnings
restoreCompatibility
data
applicationGroups
appGroups
preferences
keychain
profileAppData
globalSafari
systemGlobalLibrary
sharedSystemDB
artifacts
options
```

Exact derived sections:

```objc
@"manifestVersion": @4

@"schema": @{
    @"identifier": @"com.hydra.projectx.backup-manifest",
    @"revision": @1,
    @"digestAlgorithm": @"sha256",
}

@"backupID": backupIdentifier

@"publication": @{
    @"protocol": @"atomic-directory-v1",
    @"contentState": @"complete",
}
```

`contentState == complete` means the immutable content snapshot contains every required artifact and all derived metadata. It does not mean the directory has already been published.

`backupMode` must equal exactly `strict`.

# Part 6 - V4 artifact declaration

Each v4 artifact declaration contains exactly:

```text
name
path
size
sha256
policy
```

`name` is the accepted record `relativePath`.

`path` must equal `name` exactly. It is a safe relative locator, never `record.filePath` and never an absolute partial-workspace path.

`size` and `sha256` come directly from the immutable verified record.

The policy dictionary contains exactly:

```text
kind
requirement
failureDisposition
emptyFilePolicy
```

Exact string mappings:

| Kind enum | kind |
|---|---|
| ApplicationData | `applicationData` |
| AppGroup | `appGroup` |
| ProfileAppData | `profileAppData` |
| GlobalSafari | `globalSafari` |
| SystemGlobal | `systemGlobal` |
| SharedSystemDatabase | `sharedSystemDatabase` |
| Preferences | `preferences` |
| Keychain | `keychain` |

| Enum | string |
|---|---|
| Required | `required` |
| Optional | `optional` |
| AbortBackup | `abortBackup` |
| WarnAndContinue | `warnAndContinue` |
| ContinueWithoutWarning | `continueWithoutWarning` |
| Reject | `reject` |
| Allow | `allow` |

The builder must reconstruct the canonical TASK-3.5 policy for each kind and require exact value equality with `record.policy`.

Do not serialize numeric enum values, Objective-C class names or absolute paths.

# Part 7 - Artifact ordering, aggregate fields and minimum contract

The accepted artifact order remains:

```text
ApplicationData
AppGroup
ProfileAppData
GlobalSafari
SystemGlobal
SharedSystemDatabase
Preferences
Keychain
```

Repeated AppGroup, SystemGlobal and SharedSystemDatabase records preserve manager order within their kind.

Require:

- artifact count from 1 through 4096;
- kinds nondecreasing;
- exactly one ApplicationData artifact;
- ApplicationData is index zero;
- exactly one required artifact total;
- every non-ApplicationData artifact is optional;
- profile, Safari, Preferences and Keychain appear at most once;
- every record size is accepted by its retained policy;
- total-size addition is overflow-safe.

Derived values:

```text
artifactCount             = verifiedArtifacts.count
totalSize                 = exact overflow-safe sum
applicationDataChecksum   = ApplicationData.sha256
archiveChecksum           = applicationDataChecksum
```

No aggregate field is accepted from `fields`.

# Part 8 - Exact component reference coverage

Build a name-to-record map and require every accepted artifact to be referenced by exactly one Restore component.

Exact reference-to-kind mapping:

```text
$.data.archive                         -> ApplicationData
$.appGroups[*].archive                 -> AppGroup
$.profileAppData.archive when included -> ProfileAppData
$.globalSafari.archive when included   -> GlobalSafari
$.systemGlobalLibrary.items[*].archive -> SystemGlobal
$.sharedSystemDB.files[*].archive      -> SharedSystemDatabase
$.preferences.archive when included    -> Preferences
$.keychain.archive when included       -> Keychain
```

Requirements:

- referenced name is a safe exact relative artifact name;
- referenced declaration exists;
- retained policy kind matches the component;
- no name is referenced twice;
- every declaration is referenced exactly once;
- no synthetic, orphan or debug artifact;
- no included component without a declaration;
- no declaration without an included component.

Failures use `DuplicateReference`, `MissingReference`, `UnreferencedArtifact` or `InvalidArtifactPolicy` with stable field paths.

# Part 9 - Component consistency

Keep the existing Restore-compatible component shapes, with stricter v4 consistency.

## Data

Exact keys:

```text
uuid
archive
containerPath
```

`archive` references the one ApplicationData record.

## App Groups

`applicationGroups` remains the exact signed-entitlement/request snapshot.

Each `appGroups` item contains exactly:

```text
groupID
uuid
archive
```

Group IDs must be unique. Successful `appGroups.groupID` values must be an exact subset of `applicationGroups`.

When `options.includeAppGroups == NO`, `appGroups` must be empty.

When the option is true, zero successful App Group artifacts is allowed because App Groups are optional.

## Preferences

Exact keys:

```text
included
archive
```

V4 semantics:

```text
included == YES -> archive is exact Preferences declaration name
included == NO  -> archive is exactly empty string
```

The manifest-v3 excluded locator exception ends at v4. Raw request remains in `options.includePreferences`.

## Keychain

Exact keys:

```text
included
archive
groupsSelected
method
```

`included == NO` requires empty archive and empty method. Existing selected-group snapshot may remain.

## Profile AppData and Global Safari

Exact keys:

```text
included
archive
path
```

Excluded requires empty archive. Existing source `path` remains advisory snapshot metadata and is never Restore destination authority.

## System-global and shared DB

Exact keys remain:

```text
systemGlobalLibrary: included, items
sharedSystemDB: included, files
```

`included` must equal whether the corresponding item/file array is nonempty.

Every item has exactly its accepted v3 keys and one exact kind-matched artifact reference.

# Part 10 - Requested versus factual option reporting

The nested `options` dictionary remains raw caller request telemetry:

```text
includeAppGroups
includePreferences
includeKeychain
```

The builder derives factual top-level arrays.

`includedOptions` canonical order:

```text
DataContainer
AppGroups if appGroups.count > 0
GlobalPreferences if preferences.included == YES
Keychain if keychain.included == YES
```

`excludedOptions` canonical order:

```text
AppGroups if appGroups.count == 0
GlobalPreferences if preferences.included == NO
Keychain if keychain.included == NO
```

Rules:

- arrays are duplicate-free and disjoint;
- DataContainer is always included and never excluded;
- raw request may be true while factual inclusion is false;
- raw request false forbids factual inclusion for the corresponding option;
- profile/Safari/system/shared components remain represented by their own sections, not option-name arrays.

Remove manager-local `PXIncludedOptionNames` and `PXExcludedOptionNames`; the v4 builder is the sole authority for these derived arrays.

# Part 11 - Version-aware validator

Modify only `PXBackupManifestValidator.m`. The public header and six accepted error codes remain byte-identical.

Required behavior:

```text
version 2 -> exact accepted legacy validation
version 3 -> exact accepted legacy validation
version 4 -> strict v4 validation
other positive integral version -> generic graph/version acceptance only;
                                   manager later returns existing code 201
```

This preserves the TASK-2.2 separation between structural validation and supported-version policy.

Do not broaden supported versions by range or minimum.

## Legacy preservation

Keep v2/v3 behavior unchanged, including the manifest-v3 Preferences archive requirement.

Create a separate v4 path rather than weakening or silently changing legacy helpers.

## Strict v4 validation

The v4 validator independently verifies:

- exact thirty-three root keys;
- exact nested key sets;
- schema/publication constants;
- lowercase canonical backup UUID;
- property-list graph limits;
- strict field types and bounds;
- exact relative artifact `name` and `path` equality;
- lowercase 64-character SHA-256;
- exact policy strings and canonical matrix;
- zero-size policy;
- canonical artifact order;
- one required ApplicationData first;
- exact component reference coverage;
- exact aggregate count/size/checksum;
- factual included/excluded arrays;
- raw request consistency;
- v4 excluded-component archive rules;
- no unknown root or nested keys.

The validator must not trust the builder simply because the builder produced the dictionary.

# Part 12 - Manager integration

Import exactly once:

```objc
#import "PXBackupManifestV4.h"
```

Update private version support to exact:

```text
2
3
4
```

No range/minimum policy.

## Backup ID

Generate one backup identifier using:

```objc
[NSUUID UUID].UUIDString.lowercaseString
```

Generate it exactly once after TASK-3.5 policy construction succeeds and before output directories/debug/process kill.

Do not derive it from timestamp, PID, bundle ID, workspace name or random path suffix.

## Manifest construction

After the accepted TASK-3.5 pre-manifest audit:

1. create one exact twenty-three-key `fields` dictionary;
2. use v4 Preferences excluded archive `@""`;
3. do not create `artifacts`, count, total size, checksum, included options or excluded options in manager;
4. call `PXBackupManifestV4` factory exactly once;
5. propagate exact nonnil v4 error;
6. use manager fallback only for impossible nil-without-error:

```text
domain: PXBackupErrorDomain
code: 107
description: Manifest v4 could not be constructed
```

7. call `PXBackupManifestValidator validateManifestObject:error:` exactly once on the produced dictionary before manifest-file writing;
8. propagate exact validator error on failure;
9. use only `manifestSnapshot.manifestRepresentation` as manifest write input.

Do not manually patch the dictionary after factory success.

## Current write boundary

Keep the current manifest write behavior unchanged for this task:

```objc
[manifest writeToFile:manifestPath atomically:YES]
```

Keep the exact warning:

```text
Failed to write manifest
```

Keep existing chmod/debug/result behavior.

TASK-3.7 owns descriptor-relative temporary manifest creation, strict durability, read-back validation and atomic rename.

# Part 13 - Restore compatibility

`readManifestAtBackupDirectory:error:` must accept exact versions 2, 3 and 4.

The Restore flow must continue to:

1. validate structure;
2. enforce supported version;
3. verify artifacts by safe relative `name`;
4. validate archives;
5. build the immutable Restore plan;
6. execute existing transactional Restore.

Do not modify:

- `PXBackupArtifactVerifier`;
- `PXBackupArchiveValidator`;
- `PXRestorePlan`;
- Restore transaction/staging code.

V4 remains compatible because all Restore-consumed component sections and artifact `name`, `size`, `sha256` fields retain their accepted meanings.

The v4 artifact `path` field is relative metadata and is not Restore authority.

# Part 14 - Error privacy

V4 public methods clear `*error` at entry.

Error `userInfo` may contain only:

```text
NSLocalizedDescriptionKey
PXBackupManifestV4ErrorFieldPathKey
```

Do not include:

- bundle ID;
- backup ID value;
- artifact name/path;
- absolute source/workspace path;
- digest;
- size;
- UUID/container UUID;
- nested NSError;
- raw dictionary value;
- process output.

Use stable field paths such as:

```text
$
$.backupID
$.fields
$.artifacts[4].policy.kind
$.preferences.archive
```

# Part 15 - Non-regression

Byte-identical:

```text
PXBackupArtifactPolicy.h/.m
PXBackupArtifactWriter.h/.m
PXBackupBundleLock.h/.m
PXBackupPublicationWorkspace.h/.m
PXBackupManifestValidator.h
AppDataBackupManager.h
all Restore verifier/archive/plan/transaction/staging files
CommandRunner.h/.m
Makefile
UI/controller files
Keychain helper/bridge/script files
```

Preserve:

```text
lock factory calls:          1
lock validations:            4
workspace factory calls:     1
workspace validations:       3
writer factory calls:        1
writer validations:          3
policy construction calls:   8
policy-aware writer sites:   8
failure-policy helper calls: 8
policy audit calls:          1
artifact renameat sites:     1
final Backup publication:    0
```

Keep:

- public Backup selector;
- timestamp format;
- tar preference/source resolution;
- process-kill ordering;
- relative artifact names;
- warning text/order except no change is required in this task;
- TASK-3.4 request telemetry;
- Keychain behavior;
- partial workspace result;
- discovery exclusions;
- current manifest write warning;
- Restore/UI behavior.

# Part 16 - Later-task boundaries

Do not implement:

- TASK-3.7 descriptor-relative atomic manifest protocol;
- manifest tmp filename or `renameat` for manifest;
- manifest file fsync or parent sync;
- read-back from written manifest;
- TASK-3.8 final Backup-directory rename/publication;
- publication marker file;
- TASK-3.9 centralized failure cleanup;
- TASK-3.10 stale partial cleanup/discovery changes;
- Phase 4 Keychain changes;
- UI changes.

# Part 17 - Static gates

Required scope:

```text
A PXBackupManifestV4.h
A PXBackupManifestV4.m
M PXBackupManifestValidator.m
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.6-REPORT.md
```

All other production diff must be zero.

Public v4 API:

```text
exported schema constants:         6
error-domain exports:              1
field-path exports:                1
error codes:                      14
public classes:                    1
public factories:                  1
public readwrite properties:       0
NSCopying classes:                 1
subclassing-restricted classes:    1
```

V4 builder:

```text
input field keys:                 23
output root keys:                 33
schema keys:                       3
publication keys:                  2
artifact keys:                     5
policy keys:                       4
absolute artifact paths:           0
policy numeric serialization:      0
filesystem/process calls:          0
```

Manager:

```text
backup UUID generation sites:      1
v4 factory calls:                  1
v4 validator calls before write:   1
manual artifact dictionaries:      0
manual artifact total-size loop:   0
manual archiveChecksum derivation: 0
included-option helper definitions: 0
excluded-option helper definitions: 0
manifestVersion @3 writes:          0
manifestVersion 4 output:           1
supported versions:                2, 3, 4
writeToFile:atomically: retained:   1
manifest renameat sites:            0
final Backup publication sites:     0
```

Validator:

```text
legacy validation path:             1
v4 strict validation path:          1
exact v4 root-key enforcement:      present
exact nested-key enforcement:       present
relative path == name:              present
reference coverage:                 present
policy consistency:                 present
aggregate consistency:              present
unknown-version schema assumption:  0
public header diff:                  0
```

# Part 18 - Report

Create:

```text
docs/backup-restore-hardening/reports/TASK-3.6-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected SHA-256 before/after;
3. v3 absolute artifact-path problem;
4. exact public API and fourteen-code enum;
5. pure builder boundary;
6. backup-ID validation;
7. exact twenty-three input keys;
8. exact thirty-three output keys;
9. immutable deep snapshot proof;
10. schema/publication constants;
11. relative artifact path proof;
12. exact policy serialization;
13. canonical order and one required record;
14. aggregate count/size/checksum derivation;
15. exact component-reference coverage;
16. v4 Preferences excluded semantics;
17. requested-versus-factual options;
18. version-aware validator matrix;
19. v2/v3 non-regression;
20. unsupported-version code-201 preservation;
21. manager UUID/factory/validator ordering;
22. current write protocol retained;
23. immediate Restore compatibility;
24. error privacy;
25. TASK-3.1 through TASK-3.5 non-regression;
26. explicit TASK-3.7 through TASK-3.10 boundaries;
27. full authorized production diff;
28. static gate table;
29. at least **240 explicit scenario rows**;
30. whitespace/CRLF/NUL audit;
31. build status and remaining runtime risks.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Part 19 - Post-commit gates

Run and record:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 5366c503a3946faafc7a107c4e411255ece3e0f3..HEAD --check
git diff --name-status 5366c503a3946faafc7a107c4e411255ece3e0f3..HEAD
git status --short --untracked-files=all
```

Suggested commit:

```text
phase3(task-3.6): introduce backup manifest schema v4
```

Stop after TASK-3.6.

Do not implement TASK-3.7 or any later task.
