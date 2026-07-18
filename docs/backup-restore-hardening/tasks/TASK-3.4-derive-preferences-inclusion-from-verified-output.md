# TASK-3.4 — Derive Preferences Inclusion from Verified Output

- Status: READY
- Phase: 3 — Atomic Backup Publication
- Baseline: `849b2825c0cffc60db33f11ac769f35aae6c78e3`
- Suggested commit: `phase3(task-3.4): derive preferences inclusion from verified output`

## Goal

Correct the remaining Preferences manifest inconsistency after TASK-3.3.

The Preferences option bit represents a **request**. It must no longer be used as proof that a Preferences artifact exists.

The Backup may report Preferences as included only when TASK-3.3 returned a nonnil immutable `PXVerifiedBackupArtifact` for the exact Preferences relative path.

TASK-3.4 is intentionally narrow. It does not formalize general required/optional artifact policy, change the manifest schema, change the artifact writer, publish the Backup directory or centralize failure cleanup.

## Accepted foundation

The following are accepted and must remain intact:

- TASK-3.1 unique descriptor-bound partial workspace;
- TASK-3.2 persistent per-bundle nonblocking serialization lock;
- TASK-3.3 common verified artifact writer;
- manifest version 3;
- current artifact ordering and metadata derivation;
- current optional Preferences production behavior;
- Restore manifest/artifact/plan handling;
- all Phase 2 transaction and result behavior.

TASK-3.3 currently leaves this explicit temporary state:

```text
preferences.included = option requested
preferences.archive  = verified record path or empty
```

This can claim inclusion without a verified artifact and can produce an empty `preferences.archive`, which is invalid under the accepted manifest v3 validator.

## Authorized production scope

Only modify:

```text
AppDataBackupManager.m
```

Create report:

```text
docs/backup-restore-hardening/reports/TASK-3.4-REPORT.md
```

The implementation commit may contain only:

```text
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.4-REPORT.md
```

## Protected production source

Do not modify:

```text
AppDataBackupManager.h
PXBackupArtifactWriter.h/.m
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
PXResolvedContainer.h/.m
PXDataContainerResolver.h/.m
PXDestructivePathValidator.h/.m
AppEntitlementsReader.h/.m
AppGroupContainerResolver.h/.m
CommandRunner.h/.m
Makefile
all UI/controller files
all Keychain helper/bridge/script files
```

Coordinator task/review/status/roadmap/decision/README files are also protected from the implementation agent.

## Baseline evidence

Record before editing:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -5 --oneline
git diff --check
```

Record SHA-256 before and after for every protected production file.

# Part 1 — Separate request state from inclusion state

Replace the ambiguous option-based local with exact request semantics:

```objc
BOOL preferencesRequested =
    (options & PXBackupOptionIncludePreferences) != 0;
```

Do not retain a local named `prefsIncluded` whose value comes directly from the option bit.

The option bit means only:

```text
the caller requested an attempt to back up Preferences
```

It does not mean:

```text
a source existed
a producer succeeded
the writer accepted the payload
a verified artifact was finalized
Preferences may be restored
```

Derive final inclusion only after the writer attempt:

```objc
BOOL preferencesIncluded = (preferencesArtifactRecord != nil);
```

Required invariant:

```text
preferencesIncluded == YES
if and only if
preferencesArtifactRecord is a successfully finalized TASK-3.3 verified record
```

Do not derive inclusion from:

- raw option bits;
- source path existence alone;
- copy exit code alone;
- final path existence;
- NSFileManager rescan;
- warning presence;
- artifact dictionary lookup;
- manifest mutation after construction.

# Part 2 — One exact Preferences relative path

Create one exact local relative path and reuse it for producer request and manifest schema compatibility:

```objc
NSString *preferencesRelativePath =
    [NSString stringWithFormat:@"preferences/%@.plist", bundleID];
```

Required occurrences:

```text
preferencesRelativePath declarations: 1
writer call uses local:                1
manifest archive uses local/record:    1
```

Do not rebuild the Preferences relative path in multiple places.

The path must remain exact and case-sensitive. Do not trim, lowercase, normalize, percent-decode or alter `bundleID`.

Remove the unused `prefDestPath` local and all assignments to it.

# Part 3 — Preferences production matrix

Attempt the Preferences writer only when `preferencesRequested == YES`.

## Not requested

```text
preferencesRequested: false
writer call:           no
preferencesArtifactRecord: nil
preferencesIncluded:  false
```

No source-missing warning is added.

## Requested, source missing

Preserve the exact existing warning:

```text
Global preferences plist not found (OK for most apps); skipping
```

Result:

```text
preferencesArtifactRecord: nil
preferencesIncluded:       false
```

## Requested, source exists, copy or writer fails

Preserve TASK-3.3 behavior:

```text
no new Preferences-specific warning
preferencesArtifactRecord: nil
preferencesIncluded:       false
```

Do not turn this task into formal optional-artifact policy. TASK-3.5 owns that decision.

## Requested and verified

Only writer success may produce:

```text
preferencesArtifactRecord: nonnil
preferencesIncluded:       true
```

The verified record must retain the exact relative path:

```text
preferences/<bundleID>.plist
```

The producer remains synchronous, writes only to the writer temporary output path, requires zero copy exit status and contains no `|| true`.

# Part 4 — Manifest v3 Preferences section

The Preferences manifest section must become:

```objc
@"preferences": @{
    @"included": @(preferencesIncluded),
    @"archive": preferencesIncluded
        ? preferencesArtifactRecord.relativePath
        : preferencesRelativePath,
},
```

Equivalent formatting is allowed, but semantics must be exact.

## Why excluded still has a nonempty archive field

The accepted manifest v3 validator requires `preferences.archive` to be a nonempty string regardless of the `included` value.

Therefore, when Preferences is excluded, use the exact expected relative locator:

```text
preferences/<bundleID>.plist
```

This excluded locator is not artifact authority:

- `preferences.included == NO`;
- no matching verified artifact record is inserted;
- the Restore artifact verifier does not require the reference;
- the Restore plan does not resolve or restore Preferences.

Do not use an empty string when Preferences is excluded.

When included, require:

```text
preferences.archive == preferencesArtifactRecord.relativePath
```

# Part 5 — Included and excluded option names

`GlobalPreferences` in the top-level option-name arrays must reflect verified inclusion, not the raw request bit.

Change the private helpers to accept the final inclusion decision:

```objc
static NSArray<NSString *> *PXIncludedOptionNames(
    PXBackupOptions options,
    BOOL preferencesIncluded);

static NSArray<NSString *> *PXExcludedOptionNames(
    PXBackupOptions options,
    BOOL preferencesIncluded);
```

Exact behavior:

```text
preferencesIncluded == YES
  includedOptions contains GlobalPreferences exactly once
  excludedOptions does not contain GlobalPreferences

preferencesIncluded == NO
  includedOptions does not contain GlobalPreferences
  excludedOptions contains GlobalPreferences exactly once
```

App Groups and Keychain option-name behavior remains unchanged and option-based in this task.

Call each helper exactly once during manifest construction with `preferencesIncluded`.

Do not reorder option names.

Canonical order remains:

```text
includedOptions:
DataContainer
AppGroups when requested
GlobalPreferences when verified
Keychain when requested

excludedOptions:
AppGroups when not requested
GlobalPreferences when not verified
Keychain when not requested
```

# Part 6 — Preserve raw request telemetry

The nested raw options dictionary must continue to record the caller request:

```objc
@"options": @{
    @"includeAppGroups": ...,
    @"includePreferences": @(preferencesRequested),
    @"includeKeychain": ...,
}
```

Do not change `options.includePreferences` to the final inclusion result.

The manifest must distinguish:

```text
options.includePreferences -> requested by caller
preferences.included       -> verified artifact actually included
```

This distinction is required for diagnostics and future policy work.

# Part 7 — Artifact collection invariants

Do not change TASK-3.3 verified-record authority.

Required behavior:

```text
preferencesArtifactRecord == nil
  -> no Preferences record in verifiedArtifactRecords
  -> no Preferences declaration in artifacts
  -> artifactCount excludes Preferences
  -> totalSize excludes Preferences

preferencesArtifactRecord != nil
  -> exactly one Preferences record in verifiedArtifactRecords
  -> exactly one matching artifact declaration
  -> artifactCount includes one Preferences artifact
  -> totalSize includes exact record.size
```

Preferences ordering remains after shared-system DB records and before Keychain.

Do not rescan `preferencesRelativePath` or `preferencesArtifactRecord.filePath` with NSFileManager.

Do not create a synthetic artifact dictionary when the record is nil.

# Part 8 — Restore compatibility matrix

TASK-3.4 must produce manifest v3 states accepted by the existing Restore pipeline.

## Not requested

```text
options.includePreferences: false
preferences.included:       false
preferences.archive:        preferences/<bundleID>.plist
artifact declaration:       absent
Restore behavior:           Preferences skipped
```

## Requested but source missing

```text
options.includePreferences: true
preferences.included:       false
preferences.archive:        preferences/<bundleID>.plist
artifact declaration:       absent
warning:                    exact existing source-missing warning
Restore behavior:           Preferences skipped
```

## Requested but writer fails

```text
options.includePreferences: true
preferences.included:       false
preferences.archive:        preferences/<bundleID>.plist
artifact declaration:       absent
new warning:                none
Restore behavior:           Preferences skipped
```

## Requested and verified

```text
options.includePreferences: true
preferences.included:       true
preferences.archive:        exact verified record relativePath
artifact declaration:       present exactly once
Restore artifact verifier:  requires exact declaration
Restore plan:               includes Preferences
```

Do not modify the accepted manifest validator, artifact verifier or Restore plan to accommodate incorrect Backup output.

# Part 9 — Warning and behavior compatibility

Warning text, occurrence and order must remain unchanged.

The only Preferences source warning remains:

```text
Global preferences plist not found (OK for most apps); skipping
```

Do not add warnings such as:

```text
Preferences copy failed
Preferences writer failed
Preferences was requested but not included
```

Do not restore the removed post-hoc artifact verification warning.

Do not change:

- App Group warnings;
- profile AppData warning;
- global Safari warning;
- Keychain warnings;
- system-global warnings;
- shared-system DB warnings;
- debug call sequence;
- process-kill timing;
- tar preference;
- source-container resolution.

# Part 10 — Preserve TASK-3.1 through TASK-3.3

The following must remain byte-identical:

```text
PXBackupArtifactWriter.h/.m
PXBackupBundleLock.h/.m
PXBackupPublicationWorkspace.h/.m
```

Preserve manager counts:

```text
lock factory calls:             1
lock validations:               4
workspace factory calls:        1
workspace validations:          3
writer factory calls:           1
writer validations:             3
semantic writer call sites:     8
```

Preserve:

```text
artifact temporary prefix/template
payload protocol
streaming SHA-256
strict durability
artifact renameat finalization
artifact ordering
artifactCount derivation
totalSize overflow gate
archiveChecksum from data record
partial workspace result
normal/legacy discovery exclusion
per-bundle lock lifetime
```

No direct final-path producer may be reintroduced.

Legacy helper tokens must remain zero:

```text
PXFileSHA256
PXHexString
PXArtifactInfo
PXVerifyArtifact
```

# Part 11 — Manifest and publication boundaries

Do not change:

```text
manifestVersion = 3
manifest root key set
current writeToFile:atomically: behavior
timestamp format
PXBackupResult fields
partial workspace result path
```

Do not:

- introduce manifest v4;
- call manifest validation before write;
- add a publication marker;
- rename the partial workspace;
- publish a final timestamp directory;
- centralize failure cleanup;
- delete stale partial work.

Those belong to TASK-3.6 through TASK-3.10.

# Part 12 — Required/optional policy boundary

TASK-3.4 corrects only factual Preferences inclusion.

It does not decide whether a requested-but-missing or requested-but-failed Preferences artifact should fail the entire Backup.

Current behavior remains:

```text
source missing -> exact warning and continue
copy/writer failure -> no new warning and continue
verified success -> include
```

TASK-3.5 owns formal required/optional artifact policy, including any future hard-failure, warning or zero-length decision.

# Part 13 — Static gates

Required implementation scope:

```text
M AppDataBackupManager.m
A docs/backup-restore-hardening/reports/TASK-3.4-REPORT.md
all other production diff = 0
```

Required Preferences counts:

```text
preferencesRequested declarations:             1
preferencesIncluded declarations:              1
prefsIncluded declarations/tokens:             0
preferencesRelativePath declarations:          1
preferences writer semantic call sites:        1
prefDestPath tokens:                           0
preferences.included from preferencesIncluded: 1
empty Preferences archive fallback:            0
```

Required helper behavior:

```text
PXIncludedOptionNames definitions:   1
PXExcludedOptionNames definitions:   1
helpers accepting preferencesIncluded: yes
included helper calls:               1
excluded helper calls:               1
GlobalPreferences raw option checks inside helpers: 0
```

Required raw request telemetry:

```text
options.includePreferences from preferencesRequested: 1
```

Required artifact authority:

```text
Preferences record conditional insertion: 1
Preferences synthetic artifact dictionaries: 0
Preferences path rescans: 0
```

Required non-regression:

```text
writer semantic sites:              8
writer factory calls:               1
writer validations:                 3
lock factory calls:                 1
lock validations:                   4
workspace factory calls:            1
workspace validations:              3
legacy helper tokens:               0
manifestVersion 3:                  retained
final Backup publication rename:    0
Restore method diff:                0
backup discovery diff:              0
UI diff:                            0
Makefile diff:                      0
```

# Part 14 — Scenario requirements

The implementation and report must cover at least these scenarios:

1. Preferences option off.
2. Option off with source present.
3. Option off with stale final-looking file impossible under writer authority.
4. Option on with source absent.
5. Option on with source regular file.
6. Option on with copy exit nonzero.
7. Option on with producer returning no payload.
8. Option on with writer rejecting symlink payload.
9. Option on with writer durability failure.
10. Option on with writer finalization failure.
11. Option on with verified zero-length artifact.
12. Option on with verified nonempty artifact.
13. Verified record exact relative path.
14. Excluded manifest archive nonempty.
15. Included manifest archive from record.
16. Excluded Preferences absent from artifacts.
17. Included Preferences present once in artifacts.
18. IncludedOptions contains GlobalPreferences only on verified success.
19. ExcludedOptions contains GlobalPreferences when option off.
20. ExcludedOptions contains GlobalPreferences when requested output fails.
21. Raw options retain requested false.
22. Raw options retain requested true after failure.
23. Raw options retain requested true after success.
24. Restore validator accepts excluded locator.
25. Restore artifact verifier ignores excluded locator.
26. Restore plan skips excluded Preferences.
27. Restore requires included declaration.
28. Source-missing warning unchanged.
29. Writer failure adds no warning.
30. Warning order unchanged.
31. Artifact order unchanged.
32. Total size unchanged when Preferences absent.
33. Total size includes exact Preferences size when present.
34. Artifact count unchanged when Preferences absent.
35. Artifact count increments once when present.
36. No NSFileManager Preferences rescan.
37. No direct final output.
38. No legacy hash/info helper.
39. TASK-3.3 writer byte identity.
40. TASK-3.2 lock byte identity.
41. TASK-3.1 workspace byte identity.
42. Manifest remains v3.
43. No final publication.
44. Restore source unchanged.
45. UI source unchanged.

The report must contain at least **90 explicit scenario rows**.

# Part 15 — Report

Create:

```text
docs/backup-restore-hardening/reports/TASK-3.4-REPORT.md
```

The report must include:

1. baseline and exact scope;
2. protected SHA-256 before/after;
3. TASK-3.3 temporary inconsistency inventory;
4. request-versus-inclusion model;
5. exact Preferences relative path proof;
6. source/copy/writer outcome matrix;
7. manifest v3 excluded locator rationale;
8. included/excluded option-name derivation;
9. raw options request telemetry;
10. verified-record collection proof;
11. artifact count/size effect;
12. Restore validator/verifier/plan compatibility;
13. warning text and order proof;
14. writer/lock/workspace non-regression;
15. manifest/publication boundary;
16. TASK-3.5 policy boundary;
17. full authorized diff;
18. static gate table;
19. at least 90 explicit scenarios;
20. whitespace/CRLF/NUL audit;
21. build status and runtime risks.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

# Post-commit gates

Run:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 849b2825c0cffc60db33f11ac769f35aae6c78e3..HEAD --check
git diff --name-status 849b2825c0cffc60db33f11ac769f35aae6c78e3..HEAD
git status --short --untracked-files=all
```

Stop after TASK-3.4.

Do not implement TASK-3.5 or any later task.
