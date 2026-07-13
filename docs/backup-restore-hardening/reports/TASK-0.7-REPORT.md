# TASK-0.7 Agent Report

## Metadata

```text
Task ID: TASK-0.7
Task title: Bounded direct find helpers
Task specification: docs/backup-restore-hardening/tasks/TASK-0.7-bounded-direct-find-helpers.md
Agent: GPT-5.6 Thinking
Started at: 2026-07-13 (Asia/Ho_Chi_Minh)
Finished at: 2026-07-13 (Asia/Ho_Chi_Minh)
Suggested status: READY_FOR_REVIEW
Commit hash: chưa commit
```

## 1. Summary

TASK-0.7 migrated the two local `find` execution engines in `AppDataCleaner.m` to one bounded direct-execution helper backed by the accepted TASK-0.4 `CommandRunner` API.

Implemented results:

- added the exact private `/usr/bin/find`, 120-second timeout and 4 MiB per-stream cap constants;
- added one private `runBoundedFindWithArguments:` helper in `AppDataCleaner.m`;
- migrated `findPathsMatchingPattern:` to exact direct argv `-L <searchRoot> -path <pattern>`;
- migrated `findPathsUnderRoot:directories:namePatterns:` to the existing exact `find` expression order using Objective-C argument arrays;
- removed both local pipe, `posix_spawn`, file-actions, raw read, blocking `waitpid`, C argv and PID/status implementations;
- preserved all 23 plus 5 caller sites byte-for-byte in their local source contexts;
- preserved the search-root algorithm and root/pattern filtering source blocks exactly;
- retained complete stdout from a normal non-zero exit and rejected incomplete execution output;
- parsed stdout only, preserving newline order, duplicate entries and whitespace inside non-empty path lines.

No TASK-1.1 work, Clear path-safety change or `PXResolvedContainer` implementation was performed.

## 2. Working-tree Baseline

Initial branch:

```text
newok
```

Initial `git status --short` before TASK-0.7 changes:

```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-0.6-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-0.7-bounded-direct-find-helpers.md
```

`AppDataCleaner.m` had no diff at task start. The coordinator-owned documentation/review/task entries above were pre-existing working-tree state. This agent did not edit, stage, revert or reformat them.

Initial protected-file SHA-256 values:

```text
CommandRunner.h    63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF
CommandRunner.m    2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030
AppDataCleaner.h   B32A62280C2DF60A33658E7EC9193B76802D989C984C42193F045A94365C915E
```

Initial helper-body fingerprints:

```text
findPathsMatchingPattern:
732767B47AC896C5522320BC98D8EFCBE638B6BB924326BE6B1E9B9F5D8C65E2

findPathsUnderRoot:directories:namePatterns:
6351FCF3B6FBA69F65B438D55F5330908C975E52126FCEB65F2AB5453E2AD349
```

Initial caller-context fingerprints:

```text
findPathsMatchingPattern: 23 calls
9AB2CB470BE35AE25C04838ABAB70CF35086AD158F9546989183F3EA5057CA1E

findPathsUnderRoot:directories:namePatterns: 5 calls
543ED0319AFE73511A636770FB87DCC3238AA20B51ED88BF298F5FC19DD45BAB
```

## 3. Files Changed

| File | Change | Why required |
|---|---|---|
| `AppDataCleaner.m` | Added private constants/helper; migrated two existing find helpers; removed obsolete local process imports and engines | Required implementation scope for TASK-0.7 |
| `docs/backup-restore-hardening/reports/TASK-0.7-REPORT.md` | Created this report | Required task handoff artifact |

No other file was changed by this agent.

## 4. Exact Constants

Added exactly once in `AppDataCleaner.m`:

```objc
static NSString * const PXFindExecutablePath = @"/usr/bin/find";
static const NSTimeInterval PXFindCommandTimeoutSec = 120.0;
static const NSUInteger PXFindCommandMaxOutputBytes = 4 * 1024 * 1024;
```

Policy:

- executable lookup is fixed at `/usr/bin/find`;
- no `firstExistingPath:` or alternate path is used;
- timeout is 120 seconds for each direct find execution;
- stdout and stderr each inherit the 4 MiB cap from `CommandRunner`.

## 5. Shared Private Helper

Private declaration, only in the existing `.m` class extension:

```objc
- (NSArray<NSString *> *)runBoundedFindWithArguments:(NSArray<NSString *> *)arguments;
```

There is one declaration and one implementation in `AppDataCleaner.m`; it is not exposed in `AppDataCleaner.h`.

The helper contains the single local direct-runner call:

```objc
CommandResult *result =
    [[CommandRunner shared] runExecutableAndCapture:PXFindExecutablePath
                                          arguments:arguments
                                         timeoutSec:PXFindCommandTimeoutSec
                                     maxOutputBytes:PXFindCommandMaxOutputBytes];
```

No second process or capture engine was introduced.

### 5.1 Input validation

The helper returns `@[]` without invoking `CommandRunner` when:

- `arguments` is nil;
- runtime type is not `NSArray`;
- the array is empty;
- any element is not an `NSString`;
- any element is an empty string.

Arguments are not trimmed, joined, quoted, normalized or reinterpreted. UTF-8 conversion, embedded-NUL rejection, overflow checks, allocation and spawn validation remain owned by the direct `CommandRunner` API.

### 5.2 Forbidden execution mechanisms

The shared helper and both migrated find helpers contain zero occurrences of:

```text
/bin/sh
runAndCapture:
runCommandWithPrivilegesResult:
runCommandAndGetOutput:
NSTask
NSPipe
pipe(
posix_spawn
posix_spawn_file_actions
waitpid
raw read(
system(
popen(
posix_spawnp
PXShellQuote
componentsJoinedByString
UTF8String
NSMutableData
pid_t
char **argv
calloc(
free(argv)
```

## 6. Failure and Result Mapping

The shared helper returns `@[]` when any condition below is true:

```text
result == nil
result.spawnError != 0
result.runnerError != 0
result.timedOut == YES
result.exitedNormally == NO
result.stdoutTruncated == YES
result.stderrTruncated == YES
```

This ensures timeout, signal termination, spawn/runner failure or either-stream truncation never produces a partial destructive path list.

A failure emits one concise structured diagnostic containing:

```text
resultNil
spawnError
runnerError
timedOut
exitedNormally
terminationSignal
exitCode
stdoutTruncated
stderrTruncated
```

The diagnostic does not include arguments, stdout, stderr or returned paths.

### 6.1 Normal non-zero exit

There is no `result.exitCode != 0` failure check.

When execution exits normally and both captured streams are complete, stdout is parsed even when `exitCode` is non-zero. This preserves legacy behavior for `find` traversals that emit valid matches before reporting a local traversal error.

A normal non-zero exit with stderr only produces `@[]`, because only stdout is parsed.

## 7. Stdout-only Path Parsing

The helper uses only:

```objc
NSString *output = result.stdoutString ?: @"";
```

`result.stderrString` is never parsed or merged into the returned paths.

Parsing policy:

1. nil stdout becomes `@""`;
2. split with `[NSCharacterSet newlineCharacterSet]`;
3. filter only elements that are not `NSString` or have `length == 0`;
4. preserve original find output order;
5. preserve duplicate path lines;
6. preserve leading/trailing spaces in non-empty lines;
7. do not trim each path;
8. do not sort;
9. do not deduplicate;
10. do not canonicalize or standardize;
11. do not resolve symlinks;
12. do not introduce `-print0`.

An empty stdout returns `@[]`.

## 8. Exact Argv Contracts

### 8.1 `findPathsMatchingPattern:`

The existing selector and return type remain:

```objc
- (NSArray *)findPathsMatchingPattern:(NSString *)pattern;
```

New fail-closed input guard:

```objc
if (![pattern isKindOfClass:[NSString class]] || pattern.length == 0) {
    return @[];
}
```

The pattern is not trimmed. Whitespace-only or special-character content remains exact argument data.

Exact arguments:

```objc
NSArray<NSString *> *arguments = @[
    @"-L",
    searchRoot,
    @"-path",
    pattern
];
```

Equivalent process shape:

```text
/usr/bin/find -L <searchRoot> -path <pattern>
```

`@"find"` is not supplied; the runner owns `argv[0]`.

### 8.2 `findPathsUnderRoot:directories:namePatterns:`

The existing selector and return type remain:

```objc
- (NSArray<NSString *> *)findPathsUnderRoot:(NSString *)root
                               directories:(BOOL)directories
                              namePatterns:(NSArray<NSString *> *)namePatterns;
```

Exact constructed sequence:

```text
-L
<root>
-type
f or d
(
-name
<pattern 1>
-o
-name
<pattern 2>
...
)
-print
```

`@"find"` is not supplied. Root and every pattern remain separate exact `NSString` argv elements.

## 9. Compatibility Proof

### 9.1 Search-root optimization

The source block from the existing search-root comment through the end of the optimization was compared before and after TASK-0.7.

```text
Exact source equality: YES
SHA-256:
EE889CBB97B68923B893F02E145F202E912C8A4D1E253A10A0370CC724CD663C
```

Therefore the following remain unchanged:

- default `/` root;
- first `*`, `?` or `[` selection;
- static prefix derivation;
- containing-directory selection;
- absolute-path and `length > 1` checks;
- existing-directory requirement;
- fallback to `/`.

### 9.2 Root and pattern filtering

The `findPathsUnderRoot:` validation/filter block was compared before and after TASK-0.7.

```text
Exact source equality: YES
SHA-256:
8F1963BE1005F076FB35EBBFBC9F534D24DBC4315F0EF561257DFAA6FE320B2C
```

Preserved behavior:

- invalid/empty root returns `@[]`;
- invalid/empty `namePatterns` returns `@[]`;
- root must exist and be a directory;
- non-string patterns are ignored;
- empty string patterns are ignored;
- no trimming is added;
- remaining pattern order is preserved;
- no execution occurs when no valid pattern remains.

### 9.3 Caller source fingerprints

```text
findPathsMatchingPattern:
Before count: 23
After count:  23
Context source exact equality: YES
SHA-256: 9AB2CB470BE35AE25C04838ABAB70CF35086AD158F9546989183F3EA5057CA1E

findPathsUnderRoot:directories:namePatterns:
Before count: 5
After count:  5
Context source exact equality: YES
SHA-256: 543ED0319AFE73511A636770FB87DCC3238AA20B51ED88BF298F5FC19DD45BAB
```

No caller selector, pattern string, loop, deletion action or business decision was modified.

## 10. Complete Caller Audit — `findPathsMatchingPattern:`

All rows preserve find output order and duplicates. A duplicate can repeat the existing caller action, exactly as before. Returning `@[]` is fail-closed because it prevents the caller from performing a destructive operation on an incomplete or untrusted path list.

| # | Caller | Pattern source | Expected path kind | Existing action | Why `@[]` is fail-closed | Caller unchanged |
|---:|---|---|---|---|---|---|
| 1 | `clearSpotlightIndexes:` | Each entry of `spotlightPaths`; bundle-derived Spotlight paths and literal Spotlight cache globs | Files or directories | `securelyWipeFile:` | Skips manual Spotlight deletion when discovery is incomplete | YES |
| 2 | `cleanRootHideVarData:` | Each entry of `rootHidePaths`; bundle-derived preferences, cache, tmp, WebKit, support and cookie paths | Files or directories | `securelyWipeFile:` | Skips RootHide path deletion | YES |
| 3 | `clearPluginKitData:` | `basePath + **/ + bundleID + *` | Files or directories | `securelyWipeFile:` | Skips PluginKit deletion for untrusted results | YES |
| 4 | `clearPluginKitData:` | `basePath + **/* + bundle component + *` | Files or directories | `securelyWipeFile:` | Skips component-based PluginKit deletion | YES |
| 5 | `clearThumbnailCaches:` | Each bundle-derived thumbnail-services/QuickLook cache pattern | Files or directories | `securelyWipeFile:` | Skips thumbnail-cache deletion | YES |
| 6 | `clearSystemLogs:` | Each bundle-derived crash/diagnostic/ASL/system-log pattern | Primarily files; pattern may match directories | `securelyWipeFile:` | Skips log deletion | YES |
| 7 | `_internalClearEncryptedData:` | `/var/mobile/Library/Preferences/<bundle>*.enc*` | Primarily files | Accumulate, then `securelyWipeFile:` | Skips encrypted-preference deletion | YES |
| 8 | `_internalClearEncryptedData:` | `/var/mobile/Library/Preferences/<bundle>*.encrypted*` | Primarily files | Accumulate, then `securelyWipeFile:` | Skips encrypted-preference deletion | YES |
| 9 | `_internalClearEncryptedData:` | `/var/mobile/Library/Preferences/<bundle>*.secure*` | Primarily files | Accumulate, then `securelyWipeFile:` | Skips secure-preference deletion | YES |
| 10 | `_internalClearEncryptedData:` | `<pref base>/<bundle>*.enc*` for each alternate preference base | Primarily files | Accumulate, then `securelyWipeFile:` | Skips alternate encrypted-preference deletion | YES |
| 11 | `_internalClearEncryptedData:` | `<pref base>/<bundle>*.encrypted*` | Primarily files | Accumulate, then `securelyWipeFile:` | Skips alternate encrypted-preference deletion | YES |
| 12 | `_internalClearEncryptedData:` | `<pref base>/<bundle>*.secure*` | Primarily files | Accumulate, then `securelyWipeFile:` | Skips alternate secure-preference deletion | YES |
| 13 | `findExtensionContainers:` | Literal `/var/mobile/Containers/Data/PluginKitPlugin/*` | Directories | Read metadata and append verified extension info; no immediate deletion in this method | Prevents unverified container discovery from feeding later cleanup | YES |
| 14 | `findExtensionContainers:` | Literal `/containers/Data/PluginKitPlugin/*` | Directories | Read metadata and append verified rootless extension info | Prevents unverified rootless container discovery | YES |
| 15 | `clearExtensionContainers:forApp:` | `<dataPath>/Library/**/*.sqlite*` | Database files and sidecars | `securelyWipeFile:` for result and related journal/WAL/SHM paths | Skips database deletion | YES |
| 16 | `clearAppReceiptData:` | Bundle-UUID-derived standard receipt pattern | Receipt directories | `wipeDirectoryContents:keepDirectoryStructure:YES` | Skips receipt-content deletion | YES |
| 17 | `clearAppReceiptData:` | Alternate bundle-UUID receipt pattern | Receipt directories | `wipeDirectoryContents:keepDirectoryStructure:YES` | Skips alternate receipt-content deletion | YES |
| 18 | `clearAppReceiptData:` | Rootless bundle-UUID receipt pattern | Receipt directories | `wipeDirectoryContents:keepDirectoryStructure:YES` | Skips rootless receipt-content deletion | YES |
| 19 | `cleanLaunchServicesDatabase:` | Literal `/var/mobile/Library/Caches/com.apple.LaunchServices-*` | Cache files or directories | Existing privileged `rm -rf` per returned path | Skips LaunchServices cache deletion | YES |
| 20 | `cleanLaunchServicesDatabase:` | Same existing literal pattern in the rootless compatibility pass | Cache files or directories | Existing privileged `rm -rf` per returned path | Skips second-pass cache deletion | YES |
| 21 | `clearAppIssuesForIOS15:` | Wildcard entries from `locationPaths` | Files or directories | `securelyWipeFile:` | Skips location-cache deletion | YES |
| 22 | `clearAppIssuesForIOS15:` | Wildcard entries from `uiStatePaths` | Primarily plist files | `securelyWipeFile:` | Skips UI-state deletion | YES |
| 23 | `clearAppIssuesForIOS15:` | Non-deny-list wildcard entries from `snapshotPaths` | Snapshot files or directories | `securelyWipeFile:` | Skips snapshot deletion | YES |

Aggregate:

```text
23 source call sites before
23 source call sites after
11 caller methods/groups
```

## 11. Complete Caller Audit — `findPathsUnderRoot:directories:namePatterns:`

All five calls are in `_internalClearEncryptedData:`. Root and pattern arrays remain unchanged. The returned order and duplicates are preserved, so the existing loops retain their prior action order and possible repeated action behavior.

| # | Root/pattern source | `directories` | Expected path kind | Existing action | Why `@[]` is fail-closed | Caller unchanged |
|---:|---|---:|---|---|---|---|
| 1 | `dataPath`, local `encryptionPatterns` array | `NO` | Files | `securelyWipeFile:` | Skips deletion when file discovery is incomplete | YES |
| 2 | `dataPath`, `@[@"Google*", @"google*"]` | `YES` | Directories | `fastWipeDirectoryContents:keepDirectoryStructure:YES` | Skips Google auth-directory wipe | YES |
| 3 | `dataPath`, `@[@"Firebase*", @"firebase*"]` | `YES` | Directories | `fastWipeDirectoryContents:keepDirectoryStructure:YES` | Skips Firebase-directory wipe | YES |
| 4 | `dataPath`, `@[@"*oauth*", @"*OAuth*"]` | `YES` | Directories | `fastWipeDirectoryContents:keepDirectoryStructure:YES` | Skips OAuth-directory wipe | YES |
| 5 | `groupPath`, group-local `encryptionPatterns` array | `NO` | Files | `securelyWipeFile:` | Skips app-group encrypted-file deletion | YES |

Aggregate:

```text
5 source call sites before
5 source call sites after
1 caller method, 5 logical operations
```

## 12. Process Primitive Inventory

### 12.1 Before TASK-0.7

| Active token/path | Count | Location |
|---|---:|---|
| `NSTask` | 0 | none |
| `NSPipe` | 0 | none |
| `posix_spawn(` | 2 | one in each old find helper |
| `posix_spawn_file_actions*` | 10 references | old local find setup/cleanup |
| `waitpid(` | 2 | one in each old find helper |
| `pipe(pipefds...)` | 2 | one in each old find helper |
| raw `read(pipefds...)` loop | 2 | one in each old find helper |
| `runExecutableAndCapture:` | 0 | none in `AppDataCleaner.m` |

### 12.2 After TASK-0.7

| Active token/path | Count | Evidence |
|---|---:|---|
| `NSTask` | 0 | full-file static search |
| `NSPipe` | 0 | full-file static search |
| `waitUntilExit` | 0 | full-file static search |
| `readDataToEndOfFile` | 0 | full-file static search |
| `posix_spawn(` | 0 | full-file static search |
| `posix_spawn_file_actions` | 0 | full-file static search |
| `waitpid(` | 0 | full-file static search |
| `pipe(pipefds...)` | 0 | full-file static search |
| `read(pipefds...)` | 0 | full-file static search |
| find `char **argv` | 0 | full-file static search |
| `posix_spawnp` | 0 | full-file static search |
| `system(` | 0 | full-file static search |
| `popen(` | 0 | full-file static search |
| `runExecutableAndCapture:` | 1 | only in `runBoundedFindWithArguments:` |

The remaining process implementation is delegated to `CommandRunner`. Existing process-name termination remains delegated to `PXProcessKiller`; TASK-0.7 did not modify that subsystem.

The now-unused local process headers `<spawn.h>` and `<sys/wait.h>` were removed from `AppDataCleaner.m`.

## 13. Protected-file Verification

Final SHA-256 values:

```text
CommandRunner.h    63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF
CommandRunner.m    2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030
AppDataCleaner.h   B32A62280C2DF60A33658E7EC9193B76802D989C984C42193F045A94365C915E
```

They match the initial values exactly.

```text
git diff --exit-code -- AppDataCleaner.h CommandRunner.h CommandRunner.m
Exit: 0
```

No modifications were made to `AppDataCleaner.h` or `CommandRunner.h/.m`.

## 14. Helper Fingerprints After Migration

```text
findPathsMatchingPattern:
BD439CAA12B2CB8A183FA0B7FA6A25E8C199E72D9D21B6D7795926588B30AD91

findPathsUnderRoot:directories:namePatterns:
412DD56E5E3FD686731DE5B798149FE30159AF8CF91AC1C50952D9931203D63A

runBoundedFindWithArguments:
BA7A5CA382615D24299E617C81DA02C64F2B06C57D57FA5E9E2D98F87EF1923A
```

The old helper hashes changed because their local engines were intentionally replaced. The separately fingerprinted search-root and root/filter compatibility blocks remained exactly equal, as recorded in section 9.

## 15. Acceptance Checklist

- [x] Only `AppDataCleaner.m` and the required report are changed by the agent.
- [x] Both existing find selectors remain unchanged.
- [x] Private constants are added with exact required values.
- [x] `runBoundedFindWithArguments:` exists only in `.m`.
- [x] Shared helper uses exact `/usr/bin/find` direct execution.
- [x] Shared helper uses a 120-second deadline.
- [x] Shared helper uses a 4 MiB cap per stream.
- [x] No shell is involved.
- [x] Runner creates argv[0]; `@"find"` is not supplied in arguments.
- [x] Invalid arguments fail closed without spawn.
- [x] Timeout, signal, runner/spawn error and truncation return `@[]`.
- [x] No partial output is returned on incomplete execution.
- [x] Normal non-zero exit is not rejected solely by exit code.
- [x] Only stdout is parsed as paths.
- [x] stderr is never inserted into the returned array.
- [x] Path order and duplicates are preserved.
- [x] No line trimming, sorting, canonicalization or deduplication is added.
- [x] `findPathsMatchingPattern:` preserves search-root optimization.
- [x] Exact `-L root -path pattern` argument order is preserved.
- [x] `findPathsUnderRoot:` preserves input filtering and root check.
- [x] Exact `-type`, parentheses, `-name`, `-o`, `-print` order is preserved.
- [x] Manual C argv allocation is removed.
- [x] Borrowed UTF-8 argv pointers are removed.
- [x] Local pipe/spawn/read/wait implementations are removed.
- [x] Full-file `posix_spawn` and `waitpid` counts become zero.
- [x] Existing 23 plus 5 caller sites remain unchanged.
- [x] Protected source files remain unchanged.
- [x] No Clear/Backup/Restore/Keychain/UI behavior is changed.
- [x] `git diff --check` passes.
- [x] Required report is created.
- [x] GitHub Actions is recorded as PENDING.
- [x] Suggested status is READY_FOR_REVIEW.
- [x] Agent stops after TASK-0.7.

## 16. Verification Performed

| Check/command | Result | Evidence/notes |
|---|---|---|
| Required-source reading | PASS | README, STATUS, DECISIONS, TASK-0.4/0.5/0.6 reviews, TASK-0.6 report, template, headers, full CommandRunner and full AppDataCleaner source read |
| Initial `git status --short` | RECORDED | See section 2 |
| Initial protected checksums | RECORDED | See section 2 |
| Initial helper fingerprints | RECORDED | See section 2 |
| Caller count before | PASS | 23 pattern calls, 5 under-root calls |
| Full 28-call-site audit | PASS | Sections 10 and 11 |
| Search-root exact-source comparison | PASS | Exact equality; SHA-256 in section 9.1 |
| Root/filter exact-source comparison | PASS | Exact equality; SHA-256 in section 9.2 |
| Caller context comparison | PASS | Exact equality for 23 + 5 contexts |
| Exact constants search | PASS | Each required constant occurs exactly once |
| Private helper declaration/implementation search | PASS | One declaration and one implementation, both in `.m` |
| Exact direct runner call search | PASS | One local `runExecutableAndCapture:` call |
| `@"find"` argument audit | PASS | Zero occurrences in shared/pattern/root helper argument construction |
| stdout/stderr parse audit | PASS | `stdoutString` once; `stderrString` zero in shared helper |
| Normal non-zero audit | PASS | Zero `result.exitCode != 0` checks in shared helper |
| Incomplete-result audit | PASS | All required status/truncation fields fail closed |
| Forbidden APIs in three find methods | PASS | All required forbidden token counts are zero |
| Full-file process primitive gate | PASS | All local process primitive counts zero; see section 12 |
| `git diff --exit-code -- AppDataCleaner.h CommandRunner.h CommandRunner.m` | PASS | Exit 0 |
| `git diff --check` | PASS | Exit 0 |
| Full `git diff -- AppDataCleaner.m` review | PASS | Hunks limited to obsolete imports, exact constants/private declaration, shared helper and two find migrations |
| `git diff --stat -- AppDataCleaner.m` | REVIEWED | `76 insertions(+), 149 deletions(-)` |
| Generated/binary file audit | PASS | No generated or binary file was created or modified by the task |
| Local Objective-C/iOS build | NOT RUN | `clang` and `make` are unavailable; GitHub Actions is the build gate |
| Runtime target scenarios | NOT RUN | No compiled iOS target/device execution was available |

## 17. Static/Runtime Scenario Matrix

No runtime scenario is claimed as executed. Each row is a source-level `STATIC REVIEW` against the implemented contract.

| # | Scenario | Review type | Static result/evidence |
|---:|---|---|---|
| 1 | Exact valid pattern with no matches | STATIC REVIEW | Empty stdout splits to empty elements, which are filtered to `@[]` |
| 2 | Valid pattern with one match | STATIC REVIEW | One non-empty stdout line is retained as one path |
| 3 | Valid pattern with multiple matches | STATIC REVIEW | Newline split preserves source order |
| 4 | Pattern contains spaces | STATIC REVIEW | Pattern remains one exact `NSArray` element |
| 5 | Pattern contains quotes or semicolon | STATIC REVIEW | Direct argv only; no shell parsing or execution |
| 6 | Pattern contains `*`, `?` or `[` | STATIC REVIEW | Exact value follows `-path`; interpreted by `find`, while existing search-root derivation is preserved |
| 7 | Invalid nil/non-string/empty pattern | STATIC REVIEW | Explicit guard returns `@[]` before helper invocation |
| 8 | Optimized prefix directory exists | STATIC REVIEW | Existing exact search-root block selects the derived directory |
| 9 | Optimized prefix directory missing | STATIC REVIEW | Existing exact block leaves search root as `/` |
| 10 | Valid root with one name pattern | STATIC REVIEW | Builds `-L root -type f|d ( -name pattern ) -print` |
| 11 | Multiple name patterns | STATIC REVIEW | Inserts ordered `-o -name` pairs between original filtered patterns |
| 12 | Mixed invalid pattern entries | STATIC REVIEW | Existing filter ignores non-string/empty entries and preserves remaining order |
| 13 | No valid name pattern remains | STATIC REVIEW | Existing `patterns.count == 0` guard returns `@[]` without execution |
| 14 | Root missing or not directory | STATIC REVIEW | Existing file-manager root check returns `@[]` before execution |
| 15 | `directories == YES` | STATIC REVIEW | Exact `@"d"` follows `-type` |
| 16 | `directories == NO` | STATIC REVIEW | Exact `@"f"` follows `-type` |
| 17 | Normal non-zero find exit with complete stdout | STATIC REVIEW | No exit-code rejection; stdout is parsed |
| 18 | Normal non-zero find exit with only stderr | STATIC REVIEW | stderr is ignored; empty stdout returns `@[]` |
| 19 | Timeout | STATIC REVIEW | `timedOut` returns `@[]`; partial stdout is not parsed |
| 20 | Signal termination | STATIC REVIEW | `exitedNormally == NO` returns `@[]` |
| 21 | stdout truncation | STATIC REVIEW | `stdoutTruncated` returns `@[]` |
| 22 | stderr truncation | STATIC REVIEW | `stderrTruncated` returns `@[]` |
| 23 | Spawn/runner failure | STATIC REVIEW | `spawnError` or `runnerError` returns `@[]` |
| 24 | Unicode root/pattern | STATIC REVIEW | Root and patterns remain separate exact NSString arguments; CommandRunner owns UTF-8 conversion |
| 25 | Newline-delimited stdout | STATIC REVIEW | Uses the legacy `newlineCharacterSet` split and empty-only filtering |
| 26 | Duplicate paths in stdout | STATIC REVIEW | No set/deduplication operation exists; duplicates remain |
| 27 | Path line with spaces | STATIC REVIEW | No per-line trim; non-empty line is retained exactly |
| 28 | All 28 caller sites | STATIC REVIEW | Counts remain 23 + 5 and context fingerprints are identical |

## 18. Diff Review

Tracked code diff:

```text
AppDataCleaner.m | 225 +++++++++++++++++++------------------------------------
1 file changed, 76 insertions(+), 149 deletions(-)
```

Reviewed changes:

1. removed obsolete `<spawn.h>` and `<sys/wait.h>` imports;
2. added the three exact private constants;
3. added one private helper declaration;
4. added one shared bounded direct-find helper;
5. added the required invalid-pattern guard to `findPathsMatchingPattern:`;
6. replaced its local process engine with exact four-element argv construction;
7. replaced `findPathsUnderRoot:` C argv and local process engine with exact Objective-C argv construction.

Diff conclusions:

- no caller hunk exists;
- no pattern string changed;
- no selector or return type changed;
- no format-only churn outside the touched helper regions;
- no generated or binary file changed;
- no public API was added or removed;
- no behavior belonging to TASK-1.1 was implemented;
- no `PXResolvedContainer` or Clear path validator was introduced.

## 19. Safety Notes

- The task does not add any destructive target or deletion command.
- Existing callers still own all destructive actions and were not modified.
- Execution failure is converted to `@[]`, so incomplete output cannot expand the deletion target set.
- Timeout and output caps can cause a cleanup step to skip matches, but cannot cause partial captured paths to be acted upon.
- Search-root derivation, `-L` symlink-following behavior, pattern strings, find expression and result ordering remain unchanged.
- stderr is no longer capable of becoming a returned path; the old local implementations also captured stdout only.
- Complete normal non-zero stdout remains usable, preserving legacy compatibility rather than converting it into an artificial failure.
- Clear completion/result, Backup, Restore, Keychain and UI behavior were not intentionally changed.

## 20. Not Changed

Intentionally unchanged:

- `AppDataCleaner.h`;
- `CommandRunner.h` and `CommandRunner.m`;
- `PXProcessKiller`;
- all 23 `findPathsMatchingPattern:` caller sites;
- all 5 `findPathsUnderRoot:directories:namePatterns:` caller sites;
- caller pattern/root data;
- caller loops, deletion operations and business decisions;
- Clear completion/result policy;
- destructive path-safety policy;
- application bundle writes;
- Backup/Restore logic;
- Keychain helper and commands;
- UI text/state;
- existing shell-based helpers unrelated to these direct find selectors;
- newline-delimited output contract;
- TASK-1.1;
- `PXResolvedContainer`.

## 21. Remaining Risks

- Runtime compilation and execution on an iOS target were not available locally.
- The fixed `/usr/bin/find` path remains an environmental dependency, intentionally matching the legacy implementations.
- A traversal exceeding 120 seconds or either 4 MiB stream cap now returns `@[]`; this is the required fail-closed behavior but may leave data uncleaned.
- Newline characters inside filesystem names remain unsupported because `-print0` is explicitly out of scope.
- `-L` continues following symbolic links exactly as before; TASK-0.7 does not alter path-safety policy.
- Existing caller duplicates can cause repeated best-effort deletion, because duplicate preservation is part of the compatibility contract.
- GitHub Actions and on-device tests remain necessary before marking TASK-0.7 completed.

## 22. GitHub Actions Handoff

```text
Build requested: YES
Workflow expected: .github/workflows/build-ios-arm.yml
Build result: PENDING
Build URL/run ID: PENDING
```

GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
