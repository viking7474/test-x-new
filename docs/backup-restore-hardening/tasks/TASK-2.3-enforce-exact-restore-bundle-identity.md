# TASK-2.3 — Enforce Exact Restore Bundle Identity

- Status: READY
- Phase: Phase 2 — Restore Preflight and Transaction
- Previous task: TASK-2.2 COMPLETED
- Next task: TASK-2.4 remains LOCKED

## Objective

Make `restoreBackupAtDirectory:bundleID:appName:completion:` fail closed when the structurally valid, supported manifest belongs to a different bundle identifier than the caller-requested restore target.

TASK-2.3 introduces one exact requested-target identity gate.

It must not redesign public APIs, destination resolution, artifact verification, archive extraction or transactional behavior.

## Required baseline

```text
9727a0a1e14f4229ee46a74b5f5bf5fcf92bb951
```

The agent must verify that HEAD equals this baseline before production changes.

## Allowed production scope

Only:

```text
AppDataBackupManager.m
```

Required report:

```text
docs/backup-restore-hardening/reports/TASK-2.3-REPORT.md
```

No other production file may change.

## Protected files

At minimum, all of the following must remain byte-identical:

```text
AppDataBackupManager.h
PXBackupManifestValidator.h
PXBackupManifestValidator.m
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
AppDataBackupRestoreViewController.m
ProfileManagerViewController.m
ProjectXViewController.m
KeychainGroupsViewController.m
WeaponXKeychainBridge/Tweak.m
KeychainHelper/backup_helper.m
KeychainHelper/KeychainBackupHelper.h
KeychainHelper/KeychainBackupHelper.m
Makefile
```

Do not modify task specifications, coordinator reviews, `STATUS.md`, `ROADMAP.md`, `DECISIONS.md` or `README.md`.

---

# Part 1 — Preserve the TASK-2.2 common read boundary

Do not change the public signature:

```objc
- (NSDictionary *_Nullable)readManifestAtBackupDirectory:(NSString *)backupDir
                                                    error:(NSError **)error;
```

Do not add an expected/requested bundle parameter to this method.

`readManifestAtBackupDirectory:error:` must remain responsible only for:

1. reading `manifest.plist`;
2. TASK-2.1 structural validation;
3. TASK-2.2 exact supported-version enforcement `{2,3}`;
4. returning the original accepted dictionary.

It must not compare the manifest bundle ID with a caller-requested target because it has no requested-target input.

The following TASK-2.2 contracts must remain unchanged:

```text
read failure -> PXBackupErrorDomain code 200
schema failure -> exact validator NSError
unsupported version -> PXBackupErrorDomain code 201
version 2 -> accepted
version 3 -> accepted
other positive versions -> unsupported
```

Do not modify:

```text
PXBackupManifestVersionIsSupported
PXBackupManifestValidator
Backup manifest writer version @3
```

---

# Part 2 — Exact requested-target comparison

Inside:

```objc
- (void)restoreBackupAtDirectory:(NSString *)backupDir
                        bundleID:(NSString *)bundleID
                         appName:(nullable NSString *)appName
                      completion:(void (^)(PXRestoreResult *_Nullable result,
                                           NSError *_Nullable error))completion;
```

perform the bundle identity check immediately after the common manifest-read call succeeds.

TASK-2.1 validation has already proven that:

```text
manifest[@"bundleID"] is an NSString
manifest[@"bundleID"] is nonempty
manifest[@"bundleID"] is not whitespace-only
manifest[@"bundleID"] contains no U+0000
```

Required comparison:

```objc
NSString *manifestBundleID = manifest[@"bundleID"];
BOOL matches = [manifestBundleID isEqualToString:bundleID];
```

Exact semantics:

- case-sensitive;
- byte/value exact according to `isEqualToString:`;
- no trim;
- no lowercase/uppercase;
- no Unicode normalization;
- no prefix/suffix/substring matching;
- no app-name/company-name fallback;
- no path-derived identity;
- no profile-derived identity;
- no `restoreCompatibility.requiresSameBundleID` override.

The exact comparison is unconditional for every Restore request.

A manifest field saying `requiresSameBundleID = NO` must not disable the gate.

---

# Part 3 — Bundle mismatch error

Use the existing private manager domain:

```text
PXBackupErrorDomain
```

Use the currently unused stable Restore error code:

```text
304
```

Use this generic localized description:

```text
Backup manifest bundle identifier does not match restore target
```

Do not include in `NSError.userInfo`:

- manifest bundle ID;
- requested bundle ID;
- backup directory;
- application name;
- path;
- UUID;
- archive name;
- manifest object;
- nested arbitrary object.

The mismatch error may contain only `NSLocalizedDescriptionKey` under existing manager error construction style.

Do not log both identifiers.

Do not convert the mismatch to a warning.

---

# Part 4 — Early fail-closed ordering

Required background-block order:

1. public parameter guard already present;
2. call `readManifestAtBackupDirectory:error:`;
3. propagate read/schema/version failure and return;
4. exact manifest bundle ID versus requested `bundleID` comparison;
5. on mismatch, dispatch completion on the main queue exactly once and return;
6. only after exact match may the existing Restore setup continue.

The exact bundle match must occur before:

```text
NSMutableArray warnings creation
NSFileManager acquisition for Restore work
CommandRunner acquisition for Restore work
debug path construction
PXDebugHeader/PXDebugAppendLine/PXDebugRun
PXResolvePathsForBundleID
tar discovery
target-process kill
active profile lookup
LaunchServices target lookup
metadata target scan
manifest containerPath fallback
manifest UUID fallback
artifact verification
archive existence checks
archive extraction
preferences restore
App Group restore
Keychain restore
profile/global/system restore
ownership or permission mutation
completion success publication
```

Mismatch must not be masked by `tar not found`, missing target container, missing artifact or later errors.

Do not create a debug file solely to record the mismatch.

---

# Part 5 — Remove warning-and-continue behavior

Remove the existing block equivalent to:

```objc
NSString *manifestBundleID = ...;
if (manifestBundleID.length && ![manifestBundleID isEqualToString:bundleID]) {
    [warnings addObject:[NSString stringWithFormat:
        @"Restore target bundle mismatch: backup bundle %@, requested bundle %@",
        manifestBundleID,
        bundleID]];
}
```

After TASK-2.3:

```text
Restore target bundle mismatch warning occurrences: 0
raw manifest/requested IDs in mismatch log or warning: 0
```

Do not retain a second comparison later in the method.

There must be exactly one requested-target comparison in the Restore method.

---

# Part 6 — Requested bundle input compatibility

Do not redesign the existing parameter validation in this task.

The current public guard remains:

```objc
if (!backupDir.length || !bundleID.length) {
    ... code 300 ...
}
```

Do not add a strict ASCII bundle-ID syntax validator.

Do not trim, lowercase, normalize or rewrite the requested bundle ID.

Exact equality examples:

```text
manifest com.example.app / requested com.example.app -> match
manifest com.example.app / requested Com.example.app -> mismatch
manifest com.example_app / requested com.example_app -> match
manifest café.example / requested café.example -> match
manifest " com.example.app " / same exact requested string -> match structurally
manifest " com.example.app " / requested com.example.app -> mismatch
```

TASK-2.3 is identity equality, not a new public bundle-syntax policy.

---

# Part 7 — UI and caller boundary

Do not modify any UI/controller caller.

In particular, do not change:

```text
AppDataBackupRestoreViewController.m
ProfileManagerViewController.m
ProjectXViewController.m
```

Some existing flows intentionally read a manifest and then request Restore using that manifest's bundle ID. Those calls will naturally satisfy the manager's exact-match gate.

Other flows pass a selected/current app bundle ID. Those calls must now fail if the manifest belongs to a different app.

Do not introduce a new confirmation dialog, override flag or cross-app restore option.

Do not silently replace the caller's requested bundle ID with the manifest bundle ID inside `AppDataBackupManager`.

---

# Part 8 — Preserve TASK-2.4 destination boundary

Do not change destination resolution in TASK-2.3.

The following existing behavior remains:

```text
LaunchServices-reported active data container preferred
metadata scan fallback retained
manifest data.containerPath fallback retained
manifest data.uuid fallback retained
root base list retained
fallback warnings retained
```

Exact bundle identity does not authorize a recorded path or UUID.

TASK-2.4 alone removes manifest path/UUID destination fallback and tightens exact destination selection.

Do not import or use `PXDataContainerResolver` or `PXDestructivePathValidator` in this task.

---

# Part 9 — Preserve later Phase 2 boundaries

Do not change:

- artifact verification — TASK-2.5;
- archive-entry inspection — TASK-2.6;
- immutable `PXRestorePlan` — TASK-2.7;
- staged main data — TASK-2.8;
- staged App Groups — TASK-2.9;
- optional component staging — TASK-2.10;
- transactional commit/rollback — TASK-2.11 through TASK-2.13;
- structured restore result — TASK-2.14;
- Backup publication — Phase 3.

Do not alter current tar commands, checksum behavior, App Group resolution, Keychain restore or optional system/global restore behavior.

---

# Part 10 — Callback behavior

On bundle mismatch:

- produce one non-nil manager `NSError` with code `304`;
- dispatch completion on the main queue;
- call completion at most once;
- pass `result = nil`;
- return immediately.

Do not throw an exception.

Do not call completion synchronously from the background block.

Preserve existing behavior when `completion == nil`.

Do not alter success callback behavior or `PXRestoreResult` in this task.

---

# Part 11 — Deterministic error precedence

Required precedence for early Restore preflight:

1. invalid public parameters -> manager code `300`;
2. manifest read failure -> manager code `200`;
3. manifest structural failure -> exact validator error;
4. unsupported manifest version -> manager code `201`;
5. exact requested bundle mismatch -> manager code `304`;
6. later Restore errors remain in their current order.

Examples:

- malformed manifest with different apparent bundle ID -> structural error, not mismatch;
- unsupported version with different bundle ID -> unsupported version, not mismatch;
- supported valid manifest with different bundle ID and missing tar -> mismatch, not tar error;
- supported valid matching manifest with missing tar -> existing code `301`.

---

# Part 12 — Required static gates

Final source expectations:

```text
AppDataBackupManager.m production diff only
AppDataBackupManager.h diff: 0
PXBackupManifestValidator.h/.m diff: 0
PXBackupManifestValidator import count: unchanged at 1
PXBackupManifestVersionIsSupported definition: unchanged at 1
supported exact values: unchanged at 2 and 3 only
readManifest validator calls: unchanged at 1
readManifest version-helper calls: unchanged at 1
restore readManifest calls: exactly 1
restore direct manifest dictionary load: 0
restore direct validator calls: 0
restore direct version-helper calls: 0
bundle mismatch manager code 304: exactly 1
bundle mismatch generic description: exactly 1
old mismatch warning string: 0
mismatch warning append: 0
requested-target exact isEqualToString comparison: exactly 1
case-insensitive comparison: 0
lowercase/uppercase/trim normalization for comparison: 0
prefix/suffix/substring matching for requested target: 0
manifest bundle replacing requested bundle: 0
UI/controller diffs: 0
Backup writer manifestVersion @3: unchanged
manifest containerPath fallback: retained
manifest UUID fallback: retained
artifact policy changes: 0
archive validation additions: 0
restore-plan additions: 0
```

Ordering gates:

```text
manifest read precedes bundle comparison
bundle comparison precedes warnings allocation
bundle comparison precedes NSFileManager/CommandRunner Restore acquisition
bundle comparison precedes debug paths and writes
bundle comparison precedes tar discovery
bundle comparison precedes target kill
bundle comparison precedes target resolution
bundle comparison precedes artifact verification
bundle comparison precedes archive extraction
```

Error gates:

```text
mismatch domain: PXBackupErrorDomain
mismatch code: 304
mismatch result: nil
mismatch completion: main queue, once
mismatch error contains no raw identifier values
read/schema/version errors retain TASK-2.2 behavior
```

---

# Part 13 — Scenario matrix

The report must cover at least these scenarios honestly:

## Public parameters and earlier gates

1. missing backupDir;
2. empty requested bundle ID;
3. missing manifest file;
4. unreadable manifest;
5. non-dictionary manifest;
6. missing manifestVersion;
7. malformed Boolean manifestVersion;
8. structurally invalid bundleID;
9. structurally valid unsupported version 1;
10. supported version 2;
11. supported version 3;
12. structurally valid unsupported version 999.

## Exact identity

13. identical ASCII bundle IDs;
14. case-only difference;
15. manifest ID with leading whitespace versus untrimmed same requested value;
16. manifest ID with leading whitespace versus trimmed requested value;
17. Unicode identifiers exactly equal;
18. Unicode identifiers visually similar but not exactly equal;
19. underscore identifiers exactly equal;
20. prefix-only relation;
21. suffix-only relation;
22. substring relation;
23. same app name but different bundle ID;
24. same profile ID but different bundle ID;
25. same recorded data UUID but different bundle ID;
26. same recorded containerPath but different bundle ID;
27. `restoreCompatibility.requiresSameBundleID = NO` with mismatch;
28. `restoreCompatibility.targetBundleID` internally matches root but requested target differs.

## Error precedence and side effects

29. malformed manifest plus apparent mismatch;
30. unsupported version plus mismatch;
31. supported mismatch plus tar missing;
32. supported mismatch plus target container missing;
33. supported mismatch plus data archive missing;
34. supported mismatch with existing debug files;
35. supported mismatch with nil completion;
36. supported exact match with tar missing;
37. supported exact match reaches current warnings allocation;
38. supported exact match reaches current target kill;
39. mismatch does not call target kill;
40. mismatch does not run debug command;
41. mismatch does not discover tar;
42. mismatch does not inspect artifact;
43. mismatch does not extract archive;
44. mismatch completes on main queue once.

## Non-regression

45. readManifest still accepts a valid v2 manifest without expected bundle input;
46. readManifest still accepts a valid v3 manifest without expected bundle input;
47. listing/UI read callers are not modified;
48. Backup writer remains v3;
49. profile mismatch remains warning-only;
50. containerPath fallback remains;
51. UUID fallback remains;
52. artifact verification behavior remains;
53. archive extraction behavior remains;
54. App Group restore remains;
55. Keychain restore remains;
56. optional profile/global/system restore remains;
57. AppDataBackupManager.h remains byte-identical;
58. validator files remain byte-identical;
59. no new public API;
60. no UI changes;
61. no TASK-2.4 work;
62. no TASK-2.5 work;
63. no transactional work.

---

# Part 14 — Required report

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.3-REPORT.md
```

The report must include:

1. baseline HEAD and initial status;
2. exact production scope;
3. protected-file SHA-256 before/after;
4. TASK-2.2 non-regression evidence;
5. exact comparison contract;
6. mismatch domain/code/message;
7. proof no raw identifier values enter the error;
8. early ordering proof;
9. proof old warning-and-continue block is removed;
10. error precedence matrix;
11. exact-match/mismatch scenario matrix;
12. public read-boundary non-regression;
13. UI/caller non-regression;
14. path/UUID fallback non-regression;
15. Backup writer non-regression;
16. full source diff;
17. static token/count gates;
18. whitespace, CRLF, NUL and generated-file audit;
19. build status;
20. remaining runtime risks.

The report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

---

# Part 15 — Verification commands

Before commit:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -3 --oneline
git diff --check
git diff --stat -- AppDataBackupManager.m
git diff -- AppDataBackupManager.m
git diff --exit-code -- <protected files>
```

After commit:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff 9727a0a1e14f4229ee46a74b5f5bf5fcf92bb951..HEAD --check
git diff --name-status 9727a0a1e14f4229ee46a74b5f5bf5fcf92bb951..HEAD
```

The implementation commit may contain only:

```text
AppDataBackupManager.m
docs/backup-restore-hardening/reports/TASK-2.3-REPORT.md
```

Stop after TASK-2.3.

Do not implement TASK-2.4.

Do not remove manifest path/UUID fallback.

Do not change artifact verification, archive extraction, restore planning, staging, transaction or structured-result behavior.
