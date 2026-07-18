# TASK-3.5 — Define Required and Optional Artifact Policy

- Status: READY
- Phase: 3 — Atomic Backup Publication
- Baseline: `339ca0129da1af9a87cd5e3bbca7ffff17085352`
- Suggested commit: `phase3(task-3.5): define backup artifact policy`

## Goal

Create one immutable policy model for every semantic Backup artifact class, bind that policy into the TASK-3.3 writer before finalization, and make the manager apply one explicit failure disposition for every producer result.

TASK-3.5 must establish all of the following:

1. exactly one required artifact class: ApplicationData;
2. seven optional artifact classes;
3. exact abort/warn/silent failure behavior;
4. an explicit zero-length rule per artifact class;
5. no policy-free artifact writer path;
6. every accepted verified record retains the policy that admitted it;
7. a pre-manifest audit proves the required artifact set and canonical order.

TASK-3.5 does not change manifest version, add policy fields to the manifest, publish the Backup directory, centralize partial cleanup, or change Restore.

## Accepted foundation

The following are accepted and must remain intact except where this task explicitly evolves the writer API:

- TASK-3.1 unique partial Backup workspace;
- TASK-3.2 nonblocking per-bundle lock;
- TASK-3.3 descriptor-relative verified artifact writer;
- TASK-3.4 Preferences request/inclusion split;
- eight synchronous producer sites;
- verified-record manifest authority;
- manifest version 3;
- current partial-workspace result;
- no final Backup publication rename.

## Authorized production scope

Create:

```text
PXBackupArtifactPolicy.h
PXBackupArtifactPolicy.m
```

Modify:

```text
PXBackupArtifactWriter.h
PXBackupArtifactWriter.m
AppDataBackupManager.m
```

Create report:

```text
docs/backup-restore-hardening/reports/TASK-3.5-REPORT.md
```

The implementation commit may contain only those six files.

## Protected files

Do not modify:

```text
AppDataBackupManager.h
PXBackupBundleLock.h/.m
PXBackupPublicationWorkspace.h/.m
PXRestoreResult.h/.m
PXMainDataRestoreTransaction.h/.m
PXAppGroupRestoreTransaction.h/.m
PXOptionalRestoreTransaction.h/.m
PXMainDataStaging.h/.m
PXAppGroupRestoreTargetPlan.h/.m
PXOptionalRestoreStaging.h/.m
PXRestorePlan.h/.m
PXBackupManifestValidator.h/.m
PXBackupArtifactVerifier.h/.m
PXBackupArchiveValidator.h/.m
container resolvers/path validators
AppEntitlementsReader.h/.m
AppGroupContainerResolver.h/.m
CommandRunner.h/.m
Makefile
UI/controller files
Keychain helper/bridge/script files
Backup discovery
coordinator task/review/status/roadmap/decision/README files
```

Record SHA-256 before and after for every protected production file.

# Part 1 — Pure immutable policy model

## Exact enums

Create `PXBackupArtifactPolicy.h` with these exact enums.

```objc
typedef NS_ENUM(NSUInteger, PXBackupArtifactKind) {
    PXBackupArtifactKindApplicationData = 1,
    PXBackupArtifactKindAppGroup = 2,
    PXBackupArtifactKindProfileAppData = 3,
    PXBackupArtifactKindGlobalSafari = 4,
    PXBackupArtifactKindSystemGlobal = 5,
    PXBackupArtifactKindSharedSystemDatabase = 6,
    PXBackupArtifactKindPreferences = 7,
    PXBackupArtifactKindKeychain = 8,
};
```

The numeric order is the canonical verified-record order.

```objc
typedef NS_ENUM(NSUInteger, PXBackupArtifactRequirement) {
    PXBackupArtifactRequirementRequired = 1,
    PXBackupArtifactRequirementOptional = 2,
};
```

```objc
typedef NS_ENUM(NSUInteger, PXBackupArtifactFailureDisposition) {
    PXBackupArtifactFailureDispositionAbortBackup = 1,
    PXBackupArtifactFailureDispositionWarnAndContinue = 2,
    PXBackupArtifactFailureDispositionContinueWithoutWarning = 3,
};
```

```objc
typedef NS_ENUM(NSUInteger, PXBackupArtifactEmptyFilePolicy) {
    PXBackupArtifactEmptyFilePolicyReject = 1,
    PXBackupArtifactEmptyFilePolicyAllow = 2,
};
```

Do not add `Unknown`, `Default`, `Automatic`, `BestEffort`, `Retry`, or other enum values.

## PXBackupArtifactPolicy

Create one subclassing-restricted immutable `NSObject<NSCopying>` class.

Readonly properties:

```objc
@property (nonatomic, readonly) PXBackupArtifactKind kind;
@property (nonatomic, readonly) PXBackupArtifactRequirement requirement;
@property (nonatomic, readonly) PXBackupArtifactFailureDisposition failureDisposition;
@property (nonatomic, readonly) PXBackupArtifactEmptyFilePolicy emptyFilePolicy;
```

Exact factory:

```objc
+ (nullable instancetype)policyForKind:(PXBackupArtifactKind)kind;
```

Exact size method:

```objc
- (BOOL)acceptsFileSize:(unsigned long long)fileSize;
```

Requirements:

- `init` and `new` unavailable;
- no public designated initializer;
- `copyWithZone:` returns `self`;
- equality/hash use all four fields;
- invalid/unknown kind returns nil;
- no error object;
- no global mutable state;
- no filesystem, process, logging, dispatch, UI, manifest, writer, manager or Keychain imports;
- `PXBackupArtifactPolicy.m` imports only its own header.

## Exact canonical matrix

| Kind | Requirement | Failure disposition | Empty file |
|---|---|---|---|
| ApplicationData | Required | AbortBackup | Reject |
| AppGroup | Optional | WarnAndContinue | Reject |
| ProfileAppData | Optional | WarnAndContinue | Reject |
| GlobalSafari | Optional | WarnAndContinue | Reject |
| SystemGlobal | Optional | WarnAndContinue | Reject |
| SharedSystemDatabase | Optional | ContinueWithoutWarning | Allow |
| Preferences | Optional | ContinueWithoutWarning | Reject |
| Keychain | Optional | ContinueWithoutWarning | Reject |

`acceptsFileSize:` returns:

```text
fileSize > 0                       -> YES for all eight kinds
fileSize == 0 + EmptyFile Reject  -> NO
fileSize == 0 + EmptyFile Allow   -> YES
```

Shared-system DB files are the only zero-length exception because exact SQLite database, `-wal`, and `-shm` snapshots may legitimately be empty.

# Part 2 — Policy-bound writer API

## Header integration

`PXBackupArtifactWriter.h` imports exactly once:

```objc
#import "PXBackupArtifactPolicy.h"
```

Add exactly one writer error code after the accepted sixteen codes:

```objc
PXBackupArtifactWriterErrorPolicyRejected = 17,
```

Do not renumber codes 1 through 16.

## Verified record policy

Add one readonly property to `PXVerifiedBackupArtifact`:

```objc
@property (nonatomic, strong, readonly) PXBackupArtifactPolicy *policy;
```

The verified record must retain the exact immutable policy passed to the writer.

Requirements:

- record construction requires an exact runtime `PXBackupArtifactPolicy` object;
- record equality/hash now include policy;
- `copyWithZone:` still returns self;
- `manifestRepresentation` remains exactly four keys:
  - `name`;
  - `path`;
  - `size`;
  - `sha256`.
- no policy/kind/requirement field enters manifest v3.

## Replace policy-free artifact method

Remove the policy-free public method.

The writer exposes exactly this artifact method:

```objc
- (nullable PXVerifiedBackupArtifact *)writeArtifactAtRelativePath:(NSString *)relativePath
                                                            policy:(PXBackupArtifactPolicy *)policy
                                                          producer:(PXBackupArtifactProducer)producer
                                                             error:(NSError **)error;
```

Required static state:

```text
policy-aware artifact methods: 1
policy-free artifact methods:  0
```

Every caller must supply a policy.

## Writer input validation

At public entry:

- clear `*error` when nonnull;
- require nonnil producer;
- require policy is exactly a `PXBackupArtifactPolicy` runtime object;
- reject invalid policy with:
  - domain `PXBackupArtifactWriterErrorDomain`;
  - code `PXBackupArtifactWriterErrorInvalidInput`;
  - field path `$.artifact.policy`.

Do not infer policy from relative path.

## Zero-length policy gate

The writer must continue the accepted TASK-3.3 pipeline through:

1. producer success;
2. exact temporary entry set;
3. no-follow regular/single-link payload open;
4. mode 0600;
5. stable streaming read;
6. exact byte count;
7. before/after stat stability.

After the full stable read and before file `fsync`, final `renameat`, record construction or accepted-set mutation, call:

```objc
[policy acceptsFileSize:streamedBytes]
```

If false:

- return nil;
- code `PXBackupArtifactWriterErrorPolicyRejected`;
- field path `$.artifact.policy`;
- generic description `The artifact output was rejected by policy`;
- perform the accepted bounded pre-rename cleanup;
- do not rename final artifact;
- do not increment `artifactCount`;
- do not add accepted path/aliases;
- do not construct a verified record.

No raw size, path, kind, bundle ID or digest may appear in the error.

## Writer non-regression

Preserve all TASK-3.3 guarantees:

- relative-path rules;
- duplicate/ancestor/normalization conflict rules;
- descriptor-relative parent traversal;
- one `mkdtemp` per attempt;
- exact `payload` entry;
- no-follow/CLOEXEC;
- regular/single-link/type/device policy;
- 64-GiB maximum;
- 64-KiB streaming buffer;
- incremental SHA-256;
- stable stat proof;
- strict file and parent `fsync`;
- exactly one `renameat` site;
- post-rename identity proof;
- exact temporary cleanup;
- bounded rollback after rename;
- error privacy;
- workspace validation;
- no shell/process or whole-file reads.

# Part 3 — Manager policy construction

Immediately after the writer factory and initial writer identity validation, and before:

- `backupDir` output setup;
- groups/preferences directories;
- debug files;
- process kill;
- producer execution;

construct exactly eight canonical policy objects:

```objc
PXBackupArtifactPolicy *applicationDataArtifactPolicy;
PXBackupArtifactPolicy *appGroupArtifactPolicy;
PXBackupArtifactPolicy *profileAppDataArtifactPolicy;
PXBackupArtifactPolicy *globalSafariArtifactPolicy;
PXBackupArtifactPolicy *systemGlobalArtifactPolicy;
PXBackupArtifactPolicy *sharedSystemDatabaseArtifactPolicy;
PXBackupArtifactPolicy *preferencesArtifactPolicy;
PXBackupArtifactPolicy *keychainArtifactPolicy;
```

Use exactly one `policyForKind:` call for each kind.

Create one canonical array in exact order:

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

If any policy is nil or any field differs from the exact canonical matrix, fail before Backup output side effects with:

```text
domain:      PXBackupErrorDomain
code:        106
description: Backup artifact policy could not be constructed
result:      nil
completion:  main queue, exactly once
```

Code 106 is new and only for internal policy construction or pre-manifest policy-audit failure.

# Part 4 — Exact policy binding at eight producer sites

All eight semantic writer calls must use the policy-aware method.

| Producer site | Required policy |
|---|---|
| `data.tar.gz` | applicationDataArtifactPolicy |
| App Group loop | appGroupArtifactPolicy |
| `profile_appdata.tar.gz` | profileAppDataArtifactPolicy |
| `global_safari.tar.gz` | globalSafariArtifactPolicy |
| system-global loop | systemGlobalArtifactPolicy |
| shared-system DB loop | sharedSystemDatabaseArtifactPolicy |
| Preferences plist | preferencesArtifactPolicy |
| `keychain.plist` | keychainArtifactPolicy |

Required counts:

```text
policy-aware writer semantic sites: 8
policy-free writer calls:            0
```

The policy must be evaluated by the writer before finalization. Do not perform a manager-only zero-size check after rename.

# Part 5 — One failure-disposition helper

Create one file-local manager helper with behavior equivalent to:

```objc
static BOOL PXBackupApplyArtifactFailurePolicy(
    PXBackupArtifactPolicy *policy,
    NSMutableArray<NSString *> *warnings,
    NSString * _Nullable warning,
    NSError * _Nullable fatalError,
    NSError **fatalErrorOut);
```

Exact behavior:

## AbortBackup

- require nonnil `fatalError`;
- set `fatalErrorOut` to that error;
- append no warning;
- return NO.

## WarnAndContinue

- require nonempty warning string;
- append the warning exactly once;
- clear/no fatal error;
- return YES.

## ContinueWithoutWarning

- require nil warning;
- append no warning;
- clear/no fatal error;
- return YES.

Invalid policy/disposition fails closed by returning NO with a generic code-106 error. Do not expose raw artifact names or writer errors in the generic policy error.

Call this helper exactly once for each semantic writer failure branch: eight call sites.

Do not place helper side effects inside assertions.

# Part 6 — Required ApplicationData behavior

ApplicationData remains the only required artifact.

On data writer failure, including producer failure, verification failure, zero-length policy rejection, durability failure or finalization failure:

- apply `applicationDataArtifactPolicy`;
- abort Backup;
- return nil result;
- preserve manager error code 105;
- preserve tar stderr text when tar itself failed;
- otherwise preserve exact generic text:

```text
Failed to create verified data artifact
```

No manifest may be written without one accepted nonempty ApplicationData record.

# Part 7 — Optional warning behavior

Preserve exact warning texts and occurrence rules.

## App Group

On each writer failure, including zero-length rejection:

```text
Failed to archive group <groupID> (<uuid>)
```

Warn and continue with remaining groups.

## Profile AppData

On writer failure:

```text
Failed to archive profile appdata; continuing
```

Warn and continue.

## Global Safari

On writer failure:

```text
Failed to archive global Safari library; continuing
```

Warn and continue.

## System-global

On writer failure:

```text
Failed to archive system global library <subdir>; continuing
```

Warn and continue.

## Preferences

Preferences writer failure, including zero-length rejection:

- continue without a new warning;
- `preferencesArtifactRecord == nil`;
- `preferences.included == false`;
- preserve TASK-3.4 request/inclusion semantics.

A missing source still preserves the exact existing warning:

```text
Global preferences plist not found (OK for most apps); skipping
```

This source-absence warning is not a writer-failure-policy warning.

## Keychain

Keychain writer failure, including zero-length rejection:

- continue without a new generic writer warning;
- preserve warnings already produced by existing helper/in-app logic;
- set record/path/method to nil as currently done;
- manifest Keychain inclusion remains false.

Do not modify Keychain helper/bridge/script behavior.

## Shared-system DB

Per-file writer failure:

- continue without a per-file warning;
- preserve the existing final aggregate warning:
  - no shared DB files found/backed up; or
  - shared DB files included.

Zero-length verified shared DB files are accepted and included.

# Part 8 — Policy-bound verified collection audit

Create one file-local pre-manifest audit helper. It may accept:

- ordered verified records;
- ordered canonical policies;
- `artifactWriter.artifactCount`.

The audit must require:

1. runtime arrays and exact record/policy classes;
2. canonical policy array count exactly 8;
3. canonical kinds exactly 1 through 8 in order;
4. exact policy matrix;
5. writer `artifactCount == verifiedArtifactRecords.count`;
6. record count between 1 and 4096;
7. each record has a policy equal to one canonical policy;
8. each record size is accepted by its retained policy;
9. record policy kinds are nondecreasing in canonical order;
10. exactly one ApplicationData record;
11. exactly one required record total;
12. required record is first;
13. ProfileAppData, GlobalSafari, Preferences and Keychain occur at most once each;
14. every non-ApplicationData record is optional.

App Group, SystemGlobal and SharedSystemDatabase may have multiple records.

Run the audit:

- after final writer identity validation before manifest construction;
- before converting records to manifest dictionaries;
- before total-size accumulation;
- before manifest write.

Audit failure:

```text
domain:      PXBackupErrorDomain
code:        106
description: Backup artifact policy invariant failed
result:      nil
completion:  main queue, exactly once
```

Do not repair, reorder, drop or synthesize records after audit failure.

# Part 9 — Manifest v3 and TASK-3.4 preservation

Do not add policy metadata to manifest v3.

Preserve:

```text
manifestVersion: 3
artifacts entries: name/path/size/sha256 only
artifactCount: verified record count
totalSize: overflow-safe sum
archiveChecksum: ApplicationData record SHA-256
```

Preserve TASK-3.4:

```text
options.includePreferences -> raw request
preferences.included       -> verified nonnil record
excluded preferences.archive -> exact nonempty locator
GlobalPreferences option reporting -> verified inclusion
```

A policy-rejected optional record must not enter:

- component mapping;
- verified collection;
- artifacts array;
- artifactCount;
- totalSize;
- included section state.

# Part 10 — Writer/record API and static gates

## Required public counts

```text
artifact kinds:                    8
requirements:                     2
failure dispositions:             3
empty-file policies:              2
policy classes:                   1
policy factories:                 1
size-policy methods:              1
policy public readwrite props:     0
policy NSCopying classes:          1
writer error codes:               17
verified-record policy props:      1
policy-aware artifact methods:     1
policy-free artifact methods:      0
```

## Required writer counts

```text
policy field path definitions:         1
acceptsFileSize calls in writer:       1
PolicyRejected branches:               1
mkdtemp sites:                         1
renameat sites:                        1
whole-file reads:                      0
shell/process calls in writer:         0
manifestRepresentation policy keys:    0
```

## Required manager counts

```text
policyForKind calls:                   8
canonical policy arrays:               1
policy construction code 106:          1
policy audit code 106:                 1
policy-aware writer sites:             8
policy-free writer sites:              0
failure-policy helper definitions:     1
failure-policy helper calls:           8
pre-manifest policy audit calls:       1
ApplicationData required records:      exactly 1 at runtime
```

## Existing Phase-3 counts retained

```text
lock factory calls:       1
lock validations:         4
workspace factory calls:  1
workspace validations:    3
writer factory calls:     1
writer validations:       3
semantic producer sites:  8
manifestVersion 3:        1
final Backup rename:      0
```

# Part 11 — Non-regression

Do not change:

- public Backup selector;
- timestamp generation;
- tar preference;
- source-container resolution;
- process-kill ordering;
- producer synchronous behavior;
- relative artifact paths;
- artifact ordering;
- Preferences request/inclusion split;
- Keychain groups/method/fallback;
- shared DB source list/sidecar expansion;
- manifest field set;
- current `writeToFile:atomically:` behavior;
- partial workspace result;
- discovery exclusion;
- Restore implementation;
- UI behavior;
- Makefile.

Legacy helper tokens remain zero:

```text
PXFileSHA256
PXHexString
PXArtifactInfo
PXVerifyArtifact
Backup artifact verification:
```

# Part 12 — Later-task boundaries

Do not implement:

- TASK-3.6 manifest schema v4;
- policy metadata in manifest;
- TASK-3.7 atomic manifest protocol/validation;
- TASK-3.8 final Backup publication;
- publication marker;
- TASK-3.9 centralized failure cleanup;
- TASK-3.10 stale partial cleanup;
- UI policy reporting;
- Restore policy changes.

Artifact-level rename inside the partial workspace remains the TASK-3.3 mechanism and is not final Backup publication.

# Part 13 — Required report

Create:

```text
docs/backup-restore-hardening/reports/TASK-3.5-REPORT.md
```

The report must contain:

1. baseline and exact scope;
2. protected hashes;
3. pre-task producer-policy inventory;
4. exact four enums;
5. immutable policy model proof;
6. complete eight-kind canonical matrix;
7. shared SQLite zero-length rationale;
8. writer API migration;
9. verified-record policy binding;
10. policy rejection before `fsync`/rename/acceptance;
11. error privacy;
12. eight policy construction calls;
13. exact eight producer bindings;
14. failure-disposition helper proof;
15. required ApplicationData failure matrix;
16. optional warning/silent matrix;
17. zero-length matrix for all eight kinds;
18. policy-bound pre-manifest audit;
19. writer count/record count equality;
20. exactly one required record proof;
21. canonical record ordering;
22. manifest v3 zero policy-field proof;
23. TASK-3.4 non-regression;
24. warning text/order proof;
25. TASK-3.1–3.3 non-regression;
26. Restore/UI/Makefile zero diff;
27. full authorized diff;
28. static gate table;
29. at least **180 explicit scenario rows**;
30. whitespace/CRLF/NUL audit;
31. build status and remaining runtime risks.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Part 14 — Build and post-commit gates

Run the strongest available Objective-C compile gate, including:

- policy model strict frontend;
- writer compile with the new policy-aware signature;
- manager integration harness;
- warning/error diagnostics promoted to errors;
- assertion-disabled configuration where relevant.

If Theos/Apple Clang is unavailable, use temporary external stubs/harnesses outside the repository and state that linked target validation remains pending.

After commit, run:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 339ca0129da1af9a87cd5e3bbca7ffff17085352..HEAD --check
git diff --name-status 339ca0129da1af9a87cd5e3bbca7ffff17085352..HEAD
git status --short --untracked-files=all
```

Stop after TASK-3.5.

Do not implement TASK-3.6 or any later task.
