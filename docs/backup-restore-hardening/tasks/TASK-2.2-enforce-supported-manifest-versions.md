# TASK-2.2 — Enforce Supported Manifest Versions

- Status: READY
- Phase: 2 — Restore Preflight and Transaction
- Depends on: TASK-2.1 accepted
- Next task: TASK-2.3 remains LOCKED

## Objective

Integrate the accepted standalone `PXBackupManifestValidator` into the manifest-read and Restore preflight boundaries, then enforce the exact set of manifest versions currently produced by repository history:

```text
2
3
```

TASK-2.1 intentionally accepts any positive structurally valid version. TASK-2.2 adds the policy layer that decides whether Backup/Restore callers may consume that manifest.

The supported-version gate must run before Restore performs target-process termination, target-container lookup, archive verification, extraction or any target mutation.

This task does not enforce requested bundle identity, remove destination fallback, verify artifact files, inspect archive entries, build a restore plan or change transactional mutation behavior.

---

# Part 1 — Baseline

Required baseline:

```text
e15f101cd70cc782274e42e608bce64d4981a578
```

TASK-2.1 review:

```text
docs/backup-restore-hardening/reviews/TASK-2.1-REVIEW.md
```

Before editing, record:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git log -3 --oneline
```

Coordinator-owned uncommitted documentation must not be rewritten, reverted, formatted or staged.

---

# Part 2 — Allowed files

Only this production file may change:

```text
AppDataBackupManager.m
```

Required report:

```text
docs/backup-restore-hardening/reports/TASK-2.2-REPORT.md
```

No other production file may change.

---

# Part 3 — Protected files

Do not modify:

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
ProjectXViewController.m
AppDataBackupRestoreViewController.m
ProfileManagerViewController.m
KeychainGroupsViewController.m
WeaponXKeychainBridge/Tweak.m
KeychainHelper/backup_helper.m
KeychainHelper/KeychainBackupHelper.h
KeychainHelper/KeychainBackupHelper.m
Makefile
```

Do not modify task specifications, reviews, `STATUS.md`, `ROADMAP.md`, `DECISIONS.md` or `README.md`.

Record SHA-256 before and after for all protected files listed in the task report.

---

# Part 4 — Exact supported-version policy

The only supported backup manifest versions are:

```text
2
3
```

Repository history contains writers for v2 and v3 only. Version 1 has never been produced by the tracked `AppDataBackupManager` manifest writer. Future versions require an explicit review gate before Restore may consume them.

Required outcomes after structural validation:

| Version | Result |
|---:|---|
| 1 | unsupported |
| 2 | supported |
| 3 | supported |
| 4 | unsupported |
| 999 | unsupported |

Do not implement a numeric range such as `version >= 2 && version <= 3`. The policy is an exact closed set.

Use a private file-local helper with semantics equivalent to:

```objc
static BOOL PXBackupManifestVersionIsSupported(NSNumber *version) {
    if (![version isKindOfClass:[NSNumber class]]) {
        return NO;
    }

    NSInteger value = version.integerValue;
    return value == 2 || value == 3;
}
```

The helper may rely on `PXBackupManifestValidator` having already established that the value is a positive integral non-Boolean `NSNumber` within `NSInteger` range, but it must still fail closed for an unexpected non-number.

Do not add public constants or APIs for supported versions.

Do not use:

```text
minimum version
maximum version
version range
version >=
version <=
latest-version fallback
unknown-version warning-and-continue
```

---

# Part 5 — Import and source boundary

Add exactly one import to `AppDataBackupManager.m`:

```objc
#import "PXBackupManifestValidator.h"
```

Do not import the validator from `AppDataBackupManager.h` or any UI/controller file.

No existing external caller must change.

---

# Part 6 — Unsupported-version error

Use the existing private manager domain:

```objc
PXBackupErrorDomain
```

Reserve one stable private error code for unsupported manifest version:

```text
201
```

The error must contain only a generic localized description such as:

```text
Unsupported backup manifest version
```

Do not put in the unsupported-version error:

- the actual manifest version;
- manifest contents;
- bundle identifier;
- backup directory;
- archive name;
- nested manifest object;
- arbitrary userInfo.

The unsupported-version error must not use a warning-and-continue policy.

TASK-2.1 structural validation errors must be propagated unchanged so callers retain:

- `PXBackupManifestValidatorErrorDomain`;
- the exact validator error code;
- the stable field path;
- the validator description.

Do not wrap a validator error into a generic manager error.

---

# Part 7 — Harden `readManifestAtBackupDirectory:error:`

Keep the public selector and header unchanged:

```objc
- (NSDictionary *_Nullable)readManifestAtBackupDirectory:(NSString *)backupDir
                                                    error:(NSError **)error;
```

Required order inside the method:

1. clear `*error` at entry when the pointer is non-null;
2. form `<backupDir>/manifest.plist` using the current behavior;
3. read the dictionary once;
4. if reading does not produce an `NSDictionary`, return the existing manager read failure (`PXBackupErrorDomain`, code `200`);
5. call `PXBackupManifestValidator validateManifestObject:error:` exactly once;
6. if structural validation fails, propagate that exact validator error and return `nil`;
7. call the private exact supported-version helper exactly once;
8. if unsupported, return `nil` with manager code `201`;
9. return the original dictionary object unchanged;
10. leave `*error == nil` on success.

Do not:

- mutate or normalize the manifest;
- make a mutable copy;
- rewrite `manifest.plist`;
- remove unknown keys;
- perform bundle-target matching;
- inspect artifact files;
- inspect archive entries;
- authorize `data.containerPath` or `data.uuid`;
- add warnings for unsupported versions;
- fall through with an unsupported manifest.

The method remains the public read boundary used by existing UI callers. Those callers must now receive `nil` for malformed or unsupported manifests without modification.

---

# Part 8 — Restore must reuse the public read boundary

Inside:

```objc
- (void)restoreBackupAtDirectory:bundleID:appName:completion:
```

remove the direct manifest load:

```objc
[NSDictionary dictionaryWithContentsOfFile:manifestPath]
```

Restore must obtain its manifest through exactly one call to:

```objc
[self readManifestAtBackupDirectory:backupDir error:&manifestError]
```

On failure:

- call completion once on the main queue;
- return immediately;
- propagate the exact non-nil error returned by the read boundary;
- use the existing generic Restore manifest error only as an impossible-state fallback when the read method unexpectedly returns `nil` without an error.

Do not re-run `PXBackupManifestValidator` or the version helper directly from Restore. The manifest-read boundary owns both checks.

This avoids divergent schema/version policy between UI inspection and actual Restore.

---

# Part 9 — Preflight ordering

Manifest structural validation and supported-version enforcement must occur before all of the following Restore actions:

```text
CommandRunner acquisition used for Restore commands
debug file creation or append
shell/debug command execution
tar executable discovery
target process termination
LaunchServices target-container lookup
metadata target-container scan
manifest path/UUID fallback resolution
artifact verification
archive extraction
preference restore
App Group restore
Keychain restore
profile/global/system restore
filesystem ownership or permission mutation
```

Recommended order after entering the background block:

1. initialize only local in-memory variables needed to report failure;
2. call `readManifestAtBackupDirectory:error:`;
3. on failure, dispatch completion and return;
4. only after acceptance, initialize warnings, filesystem/runner/debug state and continue the existing Restore flow.

At minimum, there must be no target-process kill, target resolution or target mutation before the accepted manifest is available. The stronger ordering above is required so an unsupported manifest is not masked by an unrelated `tar not found` or debug-command failure.

Do not write a debug file merely to report that an unsupported manifest was rejected.

---

# Part 10 — Structural errors precede version policy

The version policy may run only after TASK-2.1 structural validation succeeds.

Required distinction:

| Input | Required error source |
|---|---|
| missing `manifestVersion` | validator — MissingRequiredField |
| `manifestVersion = @YES` | validator — InvalidFieldType |
| `manifestVersion = @1.0` | validator — InvalidFieldType |
| `manifestVersion = @0` | validator — InvalidFieldValue |
| structurally valid version 1 | manager — unsupported version code 201 |
| structurally valid version 2 | accepted |
| structurally valid version 3 | accepted |
| structurally valid version 999 | manager — unsupported version code 201 |

Do not classify malformed version values as “unsupported”.

---

# Part 11 — Preserve TASK-2.3 boundary

TASK-2.2 must not enforce equality between:

```text
manifest.bundleID
requested restore bundleID
```

Keep the current Restore behavior where a mismatch is appended as a warning and Restore continues.

Do not:

- change the warning to a failure;
- return before target resolution due to bundle mismatch;
- normalize either bundle identifier;
- add a requested-bundle argument to the validator;
- add a requested-bundle argument to the read method.

Exact bundle-target rejection belongs only to TASK-2.3.

---

# Part 12 — Preserve TASK-2.4 boundary

Do not remove or change current destination-resolution behavior, including:

- LaunchServices container path preference;
- metadata scanning fallback;
- manifest `data.containerPath` fallback;
- manifest `data.uuid` fallback;
- existing root base list;
- current warnings emitted when manifest fallback is used.

TASK-2.4 will remove manifest path/UUID destination fallback after exact requested bundle identity is enforced.

No manifest path or UUID becomes authorized merely because the version is supported.

---

# Part 13 — Preserve later Phase 2 boundaries

Do not implement:

- common artifact verifier changes — TASK-2.5;
- archive-entry safety validation — TASK-2.6;
- immutable `PXRestorePlan` — TASK-2.7;
- staging main data — TASK-2.8;
- staging App Groups — TASK-2.9;
- optional-component staging — TASK-2.10;
- transactional commit/rollback — TASK-2.11 through TASK-2.13;
- structured restore result — TASK-2.14.

Do not change Backup publication or manifest writer behavior. Current Backup writer must continue to emit:

```objc
@"manifestVersion": @3
```

Do not write v2 manifests and do not migrate existing manifests.

---

# Part 14 — No UI/caller changes

Do not modify callers in:

```text
AppDataBackupRestoreViewController.m
ProfileManagerViewController.m
ProjectXViewController.m
```

They already call `readManifestAtBackupDirectory:error:` and must receive the new rejection behavior through the existing API.

Do not change alerts, labels, backup listing or restore confirmation UI.

---

# Part 15 — Static gates

Required source gates:

```text
PXBackupManifestValidator import in AppDataBackupManager.m: 1
PXBackupManifestVersionIsSupported definitions: 1
supported exact values: 2 and 3
minimum/range supported-version policy: 0
unsupported-version manager code 201: present
readManifest validator calls: 1
readManifest supported-version helper calls: 1
restore readManifestAtBackupDirectory calls: 1
restore direct manifest.plist dictionary load: 0
restore direct validator calls: 0
restore direct version-helper calls: 0
validator references in UI/controller files: 0
AppDataBackupManager.h diff: 0
PXBackupManifestValidator.h/.m diff: 0
current Backup writer manifestVersion @3: unchanged
requested bundle mismatch failure: 0
requested bundle mismatch warning: retained
manifest data.containerPath fallback: retained
manifest data.uuid fallback: retained
artifact verification policy changes: 0
archive-entry validation additions: 0
restore-plan additions: 0
```

Ordering gates within Restore:

```text
accepted manifest read call occurs before tar discovery
accepted manifest read call occurs before debug writes
accepted manifest read call occurs before target process kill
accepted manifest read call occurs before target resolution
accepted manifest read call occurs before artifact verification
accepted manifest read call occurs before archive extraction
```

Error gates:

```text
readManifest clears *error at entry
read failure: PXBackupErrorDomain code 200
validator failure: exact validator NSError propagated
unsupported version: PXBackupErrorDomain code 201
unsupported error contains no raw version/manifest/path/bundle
success leaves error nil
```

---

# Part 16 — Required scenario matrix

The report must cover at least these scenarios honestly:

## Public read boundary

1. nil/empty backup directory;
2. missing manifest file;
3. malformed/non-dictionary plist;
4. structurally invalid root;
5. missing `manifestVersion`;
6. Boolean version;
7. floating version;
8. zero version;
9. negative version;
10. structurally valid version 1;
11. structurally valid version 2;
12. structurally valid version 3;
13. structurally valid version 4;
14. structurally valid version 999;
15. valid v2 common envelope;
16. valid current v3 manifest;
17. future unknown graph-safe field on v3;
18. validator error field path preserved;
19. error pointer pre-populated before success;
20. error pointer pre-populated before failure;
21. null error pointer;
22. returned dictionary identity/content unchanged.

## Restore integration

23. unsupported version rejected before tar lookup;
24. unsupported version rejected before debug file write;
25. unsupported version rejected before process kill;
26. unsupported version rejected before target resolution;
27. unsupported version rejected before artifact verification;
28. unsupported version rejected before extraction;
29. structural validator error propagated unchanged;
30. unsupported manager error propagated unchanged;
31. completion dispatched once on main queue;
32. v2 proceeds into existing Restore flow;
33. v3 proceeds into existing Restore flow;
34. Restore contains no direct manifest dictionary load;
35. Restore contains no duplicate validator call;
36. Restore contains no duplicate version-policy call.

## Boundaries preserved

37. bundle mismatch remains warning-only;
38. matching bundle remains normal;
39. manifest containerPath fallback remains;
40. manifest UUID fallback remains;
41. LaunchServices path preference remains;
42. metadata scan fallback remains;
43. artifact verifier behavior unchanged;
44. archive extraction behavior unchanged;
45. app group restore behavior unchanged;
46. preferences restore behavior unchanged;
47. Keychain restore behavior unchanged;
48. optional/global restore behavior unchanged;
49. Backup writer remains version 3;
50. validator source remains byte-identical;
51. manager public header remains byte-identical;
52. UI callers remain byte-identical;
53. no TASK-2.3 bundle enforcement;
54. no TASK-2.4 fallback removal;
55. no TASK-2.5 artifact redesign;
56. no TASK-2.6 archive validator;
57. no restore plan/staging/transaction work.

## Static and build

58. exact production file scope;
59. protected checksums unchanged;
60. `git diff --check` passes;
61. cumulative diff check passes;
62. no NUL/generated/binary files;
63. GitHub Actions result recorded honestly.

---

# Part 17 — Report requirements

Create:

```text
docs/backup-restore-hardening/reports/TASK-2.2-REPORT.md
```

Report must include:

1. baseline HEAD/status;
2. exact production scope;
3. protected SHA-256 before/after;
4. historical evidence that repository writers are v2/v3 only;
5. exact supported-version policy;
6. exact unsupported-version error domain/code/message policy;
7. public read-boundary flow;
8. validator error propagation proof;
9. Restore integration and ordering proof;
10. proof no direct Restore manifest load remains;
11. malformed-vs-unsupported distinction;
12. version scenario matrix;
13. requested bundle mismatch non-regression;
14. destination fallback non-regression;
15. Backup writer non-regression;
16. later Phase 2 boundaries not implemented;
17. complete source diff;
18. forbidden/static token counts;
19. whitespace, line-ending, NUL and generated-file audit;
20. build status and remaining runtime risks.

Report must end exactly:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

---

# Part 18 — Verification commands

Before commit:

```text
git status --short --untracked-files=all
git rev-parse HEAD
git diff --check
git diff --stat -- AppDataBackupManager.m
git diff -- AppDataBackupManager.m
git diff --exit-code -- <protected files>
```

After commit:

```text
git show --check --oneline HEAD
git show --stat --oneline HEAD
git diff e15f101cd70cc782274e42e608bce64d4981a578..HEAD --check
git diff --name-status e15f101cd70cc782274e42e608bce64d4981a578..HEAD
```

Implementation commit may contain only:

```text
AppDataBackupManager.m
docs/backup-restore-hardening/reports/TASK-2.2-REPORT.md
```

---

# Stop condition

Stop after TASK-2.2.

Do not implement TASK-2.3.

Do not enforce requested bundle-ID equality.

Do not remove manifest path/UUID destination fallback.

Do not modify artifact/archive verification or Restore mutation behavior beyond placing the schema/version gate before existing work.
