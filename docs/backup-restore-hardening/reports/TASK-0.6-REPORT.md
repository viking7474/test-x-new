# TASK-0.6 Report — Bounded Output Query Helper

## 1. Metadata

| Field | Value |
|---|---|
| Task | `TASK-0.6-bounded-output-query-helper.md` |
| Workspace | `C:\Users\VanVan\Documents\github\test-x` |
| Branch | `newok` |
| Implementation file | `AppDataCleaner.m` |
| Required report | `docs/backup-restore-hardening/reports/TASK-0.6-REPORT.md` |
| Local Objective-C/Theos build | NOT RUN — `clang` and `make` are unavailable in this workspace |
| GitHub Actions | PENDING |
| Suggested status | READY_FOR_REVIEW |

The agent stopped at TASK-0.6. TASK-0.7 and TASK-1.1 were not started.

## 2. Summary

TASK-0.6 replaces the unbounded `NSTask`/`NSPipe` implementation of the private output-query compatibility selector with the bounded shell execution path established by TASK-0.5.

Implemented behavior:

- preserved the existing selector:

```objc
- (NSString *)runCommandAndGetOutput:(NSString *)command;
```

- added a private timed overload in `AppDataCleaner.m` only:

```objc
- (NSString *)runCommandAndGetOutput:(NSString *)command
                          timeoutSec:(NSTimeInterval)timeoutSec;
```

- added the private default timeout constant:

```objc
static const NSTimeInterval PXOutputQueryDefaultTimeoutSec = 60.0;
```

- made the legacy selector delegate exactly once to the timed overload with the 60-second default;
- made the timed overload delegate to TASK-0.5's `runCommandWithPrivilegesResult:timeoutSec:` wrapper;
- removed the local `NSTask` compatibility declaration because no active `NSTask` reference remains;
- maps incomplete or unsafe execution results to the existing `@"error"` sentinel;
- deliberately does not map a normal non-zero child exit to `@"error"` solely because of `exitCode`;
- deterministically merges complete stdout before complete stderr and trims once;
- hardened only `PXWaitForProcessExit` to use bounded, at-most-one-second probes;
- left both direct find helpers unchanged for TASK-0.7.

No new process execution engine was added.

## 3. Working-tree Baseline

### 3.1 Baseline status before TASK-0.6 edits

```text
 M docs/backup-restore-hardening/DECISIONS.md
 M docs/backup-restore-hardening/README.md
 M docs/backup-restore-hardening/ROADMAP.md
 M docs/backup-restore-hardening/STATUS.md
?? docs/backup-restore-hardening/reviews/TASK-0.5-REVIEW.md
?? docs/backup-restore-hardening/tasks/TASK-0.6-bounded-output-query-helper.md
```

`AppDataCleaner.m` had no diff before TASK-0.6.

The documentation/review/task entries above were pre-existing coordinator state. TASK-0.6 did not edit, stage, revert or format those files.

### 3.2 Protected-file baseline checksums

```text
CommandRunner.h
63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF

CommandRunner.m
2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030

AppDataCleaner.h
B32A62280C2DF60A33658E7EC9193B76802D989C984C42193F045A94365C915E
```

The same checksums were confirmed after the implementation.

### 3.3 Direct find helper baseline fingerprints

Method bodies were fingerprinted before editing:

```text
findPathsMatchingPattern:
SHA-256 732767B47AC896C5522320BC98D8EFCBE638B6BB924326BE6B1E9B9F5D8C65E2

findPathsUnderRoot:directories:namePatterns:
SHA-256 6351FCF3B6FBA69F65B438D55F5330908C975E52126FCEB65F2AB5453E2AD349
```

The same method-body fingerprints were confirmed after TASK-0.6.

## 4. Files Changed

### Changed by TASK-0.6

- `AppDataCleaner.m`
- `docs/backup-restore-hardening/reports/TASK-0.6-REPORT.md`

### Intentionally not changed

- `AppDataCleaner.h`
- `CommandRunner.h`
- `CommandRunner.m`
- `AppDataBackupManager.m`
- `AppEntitlementsReader.m`
- `common/PXProcessKiller.h`
- `common/PXProcessKiller.m`
- UI files
- keychain helper files
- Backup/Restore files
- either direct find helper body
- any coordinator baseline file

No generated or binary file was changed.

## 5. Exact Contract Changes

### 5.1 Private timeout constant

```objc
static const NSTimeInterval PXOutputQueryDefaultTimeoutSec = 60.0;
```

The constant is private to `AppDataCleaner.m`.

### 5.2 Private timed overload declaration

A private class extension in `AppDataCleaner.m` declares:

```objc
@interface AppDataCleaner ()
- (NSString *)runCommandAndGetOutput:(NSString *)command
                          timeoutSec:(NSTimeInterval)timeoutSec;
@end
```

No declaration was added to `AppDataCleaner.h`.

### 5.3 Default selector delegation

```objc
- (NSString *)runCommandAndGetOutput:(NSString *)command {
    return [self runCommandAndGetOutput:command
                            timeoutSec:PXOutputQueryDefaultTimeoutSec];
}
```

The existing selector remains source-compatible and delegates exactly once.

### 5.4 Timed selector execution path

The timed overload preserves the existing diagnostic:

```objc
NSLog(@"[AppDataCleaner] Running command: %@", command);
```

For valid input, it executes through the TASK-0.5 wrapper:

```objc
NSTimeInterval effectiveTimeout = timeoutSec <= 0
    ? PXOutputQueryDefaultTimeoutSec
    : timeoutSec;
CommandResult *result = [self runCommandWithPrivilegesResult:command
                                                   timeoutSec:effectiveTimeout];
```

This path intentionally preserves `/bin/sh -c` behavior through `CommandRunner`. It does not migrate to `runExecutableAndCapture:arguments:timeoutSec:maxOutputBytes:` and does not modify command text by adding `2>&1`.

### 5.5 Removed unbounded local engine

The output-query methods no longer contain or reference:

- `NSTask`
- `NSPipe`
- `waitUntilExit`
- `readDataToEndOfFile`
- `setLaunchPath:`
- `setArguments:`
- `setStandardOutput:`
- `setStandardError:`
- `posix_spawn`
- `waitpid`
- `kill`
- `setpgid`
- `system`
- `popen`
- `runExecutableAndCapture`

The old local compatibility interface for `NSTask` was removed after the full-file search confirmed no remaining active reference.

## 6. Result-to-String Mapping

### 6.1 Input validation

The timed overload returns `@"error"` without calling the TASK-0.5 wrapper when:

- `command` is nil;
- `command` is not an `NSString` at runtime;
- `command.length == 0`;
- `timeoutSec` is NaN;
- `timeoutSec` is positive or negative Infinity.

The command is not trimmed. A whitespace-only non-empty command remains valid and is passed unchanged to the shell.

### 6.2 Execution failure mapping

The timed overload returns `@"error"` when any of these fields indicates incomplete execution:

```objc
result.runnerError != 0
result.spawnError != 0
result.timedOut
!result.exitedNormally
result.stdoutTruncated
result.stderrTruncated
```

This covers runner/setup failure, spawn failure, deadline cleanup, signal termination and incomplete captured output.

### 6.3 Normal non-zero child exit

There is deliberately no `result.exitCode` failure check in the output-query helper.

Therefore:

- normal exit with `exitCode == 0` returns merged captured output;
- normal exit with `exitCode != 0` also returns merged captured output;
- normal non-zero exit with no output returns `@""`.

This preserves the compatibility contract of the previous helper, which returned captured pipe data without inspecting termination status.

### 6.4 Failure diagnostics

Execution failure emits at most one concise structured line from the timed output helper, containing status fields only:

```text
spawnError
runnerError
timedOut
exitedNormally
terminationSignal
stdoutTruncated
stderrTruncated
```

Captured stdout and stderr are not logged. The TASK-0.5 result-returning wrapper does not log the same failure, so no nested duplicate failure diagnostic is introduced.

Invalid input emits one concise `invalid input` line and returns immediately.

## 7. Timeout Behavior

| Input timeout | Effective behavior |
|---|---|
| finite and greater than zero | preserved exactly |
| finite and equal to zero | normalized to `60.0` seconds |
| finite and less than zero | normalized to `60.0` seconds |
| NaN | `@"error"`, no spawn |
| positive Infinity | `@"error"`, no spawn |
| negative Infinity | `@"error"`, no spawn |

The default selector passes `PXOutputQueryDefaultTimeoutSec` directly to the timed overload.

The TASK-0.5 wrapper provides the fixed 1 MiB-per-stream cap and bounded `CommandRunner` deadline/process-group cleanup. TASK-0.6 does not duplicate that implementation.

## 8. stdout/stderr Merge Behavior

After a complete normal execution:

1. `stdoutString` is selected first, with nil treated as `@""`;
2. `stderrString` is selected second, with nil treated as `@""`;
3. the merged buffer starts with stdout;
4. when stderr is non-empty and non-empty stdout does not already end in `\n`, exactly one newline is inserted;
5. stderr is appended;
6. `whitespaceAndNewlineCharacterSet` trimming is performed exactly once on the final merged string.

Implementation shape:

```objc
NSString *stdoutString = result.stdoutString ?: @"";
NSString *stderrString = result.stderrString ?: @"";
NSMutableString *mergedOutput = [NSMutableString stringWithString:stdoutString];
if (stderrString.length > 0) {
    if (mergedOutput.length > 0 && ![mergedOutput hasSuffix:@"\n"]) {
        [mergedOutput appendString:@"\n"];
    }
    [mergedOutput appendString:stderrString];
}

return [mergedOutput stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceAndNewlineCharacterSet]];
```

Consequences:

- stdout only: trimmed stdout;
- stderr only: trimmed stderr;
- both streams: stdout, separator when needed, then stderr;
- both streams empty: `@""`;
- either stream truncated: `@"error"`, because the merged output would be incomplete.

The merge is deterministic rather than attempting to reconstruct cross-stream byte chronology.

## 9. `PXWaitForProcessExit` Behavior

Only this output-query caller was changed to select the timed overload.

The command remains byte-for-byte unchanged:

```objc
@"pgrep -x '%@' 2>/dev/null | head -n 1"
```

The updated loop:

- records the same start time;
- calculates elapsed and remaining outer time before each probe;
- stops when remaining time is `<= 0`;
- calculates `probeTimeout = MIN(1.0, remaining)`;
- never passes a zero/negative probe timeout because remaining is checked first;
- therefore each probe timeout is positive, no greater than one second and no greater than the current remaining outer time;
- calls the timed output-query overload;
- returns `YES` only for an actual empty `NSString`;
- treats `@"error"` as non-empty and continues polling;
- retains the 0.1-second polling sleep;
- retains final `NO` when the process was not confirmed gone before the outer deadline.

Meaning of outcomes:

| Probe output | Meaning in `PXWaitForProcessExit` |
|---|---|
| `@""` | no PID reported; return `YES` |
| `@"error"` | probe failed/incomplete; do not claim exit |
| non-empty PID text | process still appears present; retry |
| outer time exhausted | return `NO` |

A normal `pgrep` no-match exit can have a non-zero exit code with empty output. Because TASK-0.6 does not reject normal non-zero exits solely by `exitCode`, this still correctly produces `@""` and returns `YES`.

## 10. Complete Caller Audit

There are nine business/probe call sites of the compatibility helper after TASK-0.6, plus the internal default-selector delegation to the timed overload.

### 10.1 Internal delegation

| Caller | Purpose | Expected output | Empty behavior | `@"error"` behavior | stderr suppressed by command? |
|---|---|---|---|---|---|
| `runCommandAndGetOutput:` | preserve legacy selector and apply the 60-second default | whatever the timed overload returns | propagated | propagated | command-dependent |

### 10.2 `PXWaitForProcessExit`

| Item | Audit |
|---|---|
| Caller | `PXWaitForProcessExit(AppDataCleaner *, NSString *, NSTimeInterval)` |
| Command purpose | probe exact process name with `pgrep`, return at most one PID |
| Command | `pgrep -x '<name>' 2>/dev/null | head -n 1` |
| Expected output | PID text when present, empty when absent |
| Empty output | return `YES`, process considered exited |
| `@"error"` | not considered exited; retry until outer timeout |
| stderr suppression | yes, `pgrep` stderr is redirected to `/dev/null` |
| Normal non-zero output meaning | `pgrep` no-match commonly exits non-zero with empty output; empty remains meaningful and indicates exit |
| Source change | only this caller was changed to select the timed overload |

### 10.3 `cleanAppSpecificFilesInSharedContainer:bundleID:appName:companyName:`

| Item | Audit |
|---|---|
| Caller | `cleanAppSpecificFilesInSharedContainer:bundleID:appName:companyName:` |
| Command purpose | enumerate `.db`, `.sqlite` and `.sqlite-*` paths in a shared container |
| Command | `find '<container>' -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite-*'` |
| Expected output | newline-separated filesystem paths |
| Empty output | `output.length == 0`; no database loop is entered |
| `@"error"` | existing code splits the sentinel as text, but `fileExistsAtPath:@"error"` normally fails, so no database is cleaned |
| stderr suppression | no |
| Normal non-zero output meaning | partial stdout paths remain meaningful and are returned when execution exited normally and capture was complete |
| Source change | none |

The pre-existing sentinel handling in this caller was not rewritten.

### 10.4 `directoryExistsAndHasAnyContent:` — regular-file probe

| Item | Audit |
|---|---|
| Caller | `directoryExistsAndHasAnyContent:` |
| Command purpose | find the first non-dot regular file within depth 3 |
| Command | `find '<path>' -maxdepth 3 -type f -not -path '*/\.*' -print | head -n 1` |
| Expected output | one path or empty |
| Empty output | falls through to the directory probe |
| `@"error"` | explicitly rejected by existing sentinel check; falls through |
| stderr suppression | no |
| Normal non-zero output meaning | any returned first path remains meaningful |
| Source change | none |

### 10.5 `directoryExistsAndHasAnyContent:` — subdirectory probe

| Item | Audit |
|---|---|
| Caller | `directoryExistsAndHasAnyContent:` |
| Command purpose | find the first non-dot, non-Apple subdirectory within depth 2 |
| Command | `find '<path>' -mindepth 1 -maxdepth 2 -type d -not -path '*/\.*' -print | grep -v '\.?com\.apple' | head -n 1` |
| Expected output | one directory path or empty |
| Empty output | method returns `NO` |
| `@"error"` | explicitly rejected; method returns `NO` |
| stderr suppression | no |
| Normal non-zero output meaning | any returned first path remains meaningful |
| Source change | none |

### 10.6 `hasSystemDatabaseReferencesForBundleID:` — IconState probe

| Item | Audit |
|---|---|
| Caller | `hasSystemDatabaseReferencesForBundleID:` |
| Command purpose | search existing IconState plist text for the bundle ID |
| Command | `cat '<path>' | grep -q '<bundle>' && echo 'found' || echo 'not found'` |
| Expected output | `found` or `not found` |
| Empty output | `containsString:@"found"` is false; continue |
| `@"error"` | does not contain `found`; continue |
| stderr suppression | no |
| Normal non-zero output meaning | shell expression normally converts grep result to emitted status text; any normal captured text remains returned |
| Source change | none |

The caller's pre-existing `containsString:@"found"` decision was intentionally not changed.

### 10.7 `hasSystemDatabaseReferencesForBundleID:` — notification settings probe

| Item | Audit |
|---|---|
| Caller | `hasSystemDatabaseReferencesForBundleID:` |
| Command purpose | search notification preferences for the bundle ID |
| Command | `cat '<path>' | grep -q '<bundle>' && echo 'found' || echo 'not found'` |
| Expected output | `found` or `not found` |
| Empty output | no reference reported; continue |
| `@"error"` | no reference reported; continue |
| stderr suppression | no |
| Normal non-zero output meaning | shell expression normally emits explicit status text |
| Source change | none |

### 10.8 `hasSystemDatabaseReferencesForBundleID:` — SQLite bundle-ID probe

| Item | Audit |
|---|---|
| Caller | `hasSystemDatabaseReferencesForBundleID:` |
| Command purpose | query `sqlite_master.sql` for the full bundle ID |
| Command shape | `sqlite3 '<db>' "SELECT count(*) ... LIKE '%<bundle>%';" 2>/dev/null || echo '0'` |
| Expected output | count text, normally `0` when no match/failure fallback |
| Empty output | existing condition treats any value other than exact `0`/`error` as a reference; empty is therefore treated as a reference |
| `@"error"` | explicitly excluded; no reference reported from this probe |
| stderr suppression | yes, `2>/dev/null` |
| Normal non-zero output meaning | fallback `echo '0'` is part of the unchanged shell command; captured output remains authoritative |
| Source change | none |

The empty-output behavior is a pre-existing caller decision and was not altered.

### 10.9 `hasSystemDatabaseReferencesForBundleID:` — SQLite app-name probe

| Item | Audit |
|---|---|
| Caller | `hasSystemDatabaseReferencesForBundleID:` |
| Command purpose | query `sqlite_master.sql` for the derived app name |
| Command shape | same SQLite count query with app-name search term and `2>/dev/null || echo '0'` |
| Expected output | count text |
| Empty output | existing condition treats it as a reference |
| `@"error"` | explicitly excluded |
| stderr suppression | yes |
| Normal non-zero output meaning | fallback/captured count remains meaningful |
| Source change | none |

### 10.10 `hasSystemDatabaseReferencesForBundleID:` — SQLite company-name probe

| Item | Audit |
|---|---|
| Caller | `hasSystemDatabaseReferencesForBundleID:` |
| Command purpose | query `sqlite_master.sql` for the derived company name |
| Command shape | same SQLite count query with company-name search term and `2>/dev/null || echo '0'` |
| Expected output | count text |
| Empty output | existing condition treats it as a reference |
| `@"error"` | explicitly excluded |
| stderr suppression | yes |
| Normal non-zero output meaning | fallback/captured count remains meaningful |
| Source change | none |

### 10.11 Caller count summary

```text
Business/probe call sites: 9
Caller groups: 4
Internal default-to-timed delegation: 1
Business caller source changes: 0
PXWaitForProcessExit source changes: 1 timed-overload selection
```

No command string was changed.

## 11. Proof Direct Find Helpers Were Unchanged

TASK-0.6 did not modify:

```objc
- (NSArray *)findPathsMatchingPattern:(NSString *)pattern;

- (NSArray<NSString *> *)findPathsUnderRoot:(NSString *)root
                               directories:(BOOL)directories
                              namePatterns:(NSArray<NSString *> *)namePatterns;
```

Method-body fingerprints before and after are identical:

```text
findPathsMatchingPattern:
BEFORE 732767B47AC896C5522320BC98D8EFCBE638B6BB924326BE6B1E9B9F5D8C65E2
AFTER  732767B47AC896C5522320BC98D8EFCBE638B6BB924326BE6B1E9B9F5D8C65E2

findPathsUnderRoot:directories:namePatterns:
BEFORE 6351FCF3B6FBA69F65B438D55F5330908C975E52126FCEB65F2AB5453E2AD349
AFTER  6351FCF3B6FBA69F65B438D55F5330908C975E52126FCEB65F2AB5453E2AD349
```

Post-task active process primitive counts in `AppDataCleaner.m`:

```text
posix_spawn(: 2
waitpid(:     2
setpgid(:     0
```

Both `posix_spawn` calls and both `waitpid` calls remain only inside the two direct find helpers reserved for TASK-0.7.

## 12. Acceptance Checklist

- [x] Only `AppDataCleaner.m` and required TASK-0.6 report are changed by this task.
- [x] Existing `runCommandAndGetOutput:` selector remains.
- [x] Private timed overload is added only in `.m`.
- [x] Default query timeout is 60 seconds.
- [x] Timed overload delegates to `runCommandWithPrivilegesResult:timeoutSec:`.
- [x] No duplicate process execution engine is introduced.
- [x] No unbounded `CommandRunner` API is used.
- [x] Invalid/non-finite input maps to `@"error"` without spawn.
- [x] Spawn/runner/timeout/signal/truncation failure maps to `@"error"`.
- [x] Normal non-zero exit is not automatically mapped to `@"error"`.
- [x] stdout and stderr are merged deterministically.
- [x] Output is trimmed once.
- [x] Empty successful output returns `@""`.
- [x] `PXWaitForProcessExit` uses a bounded per-probe timeout.
- [x] Probe `@"error"` is not interpreted as process exit.
- [x] All other caller command strings and decision logic remain unchanged.
- [x] `NSTask` compatibility declaration is removed.
- [x] No active `NSTask`, `NSPipe`, `waitUntilExit` or `readDataToEndOfFile` remains.
- [x] Direct find helpers remain unchanged.
- [x] Exactly two direct `posix_spawn`/`waitpid` paths remain for TASK-0.7.
- [x] No Clear/Backup/Restore/Keychain/UI behavior is intentionally changed.
- [x] `AppDataCleaner.h` and `CommandRunner.h/.m` are unchanged.
- [x] Full caller audit is included in TASK-0.6 report.
- [x] `git diff --check` passes.
- [x] GitHub Actions is recorded as PENDING.
- [x] Suggested status is `READY_FOR_REVIEW`.
- [x] Agent stops after TASK-0.6.

## 13. Verification Commands and Results

### 13.1 Working tree

Command:

```text
git status --short
```

TASK-owned state after implementation/report creation:

```text
 M AppDataCleaner.m
?? docs/backup-restore-hardening/reports/TASK-0.6-REPORT.md
```

The coordinator baseline files remain present separately and were not touched by TASK-0.6.

### 13.2 Protected files

Command equivalent:

```text
git diff --exit-code -- AppDataCleaner.h CommandRunner.h CommandRunner.m
```

Result:

```text
protected_diff_exit=0
```

Checksums after implementation match the baseline checksums in section 3.2.

### 13.3 Output-helper contract checks

```text
default implementation count: 1
private timed declaration count: 1
private timed implementation count: 1
default timeout constant count: 1
default delegate call count: 1
TASK-0.5 result-wrapper delegation: present
result.exitCode checks in timed helper: 0
final output trim calls: 1
stdout-before-stderr merge: confirmed
conditional newline insertion: confirmed
```

Failure mapping checks present exactly in the timed helper:

```text
runnerError
spawnError
timedOut
exitedNormally
stdoutTruncated
stderrTruncated
```

### 13.4 Forbidden process APIs in the two output-query methods

```text
NSTask: 0
NSPipe: 0
posix_spawn: 0
waitpid: 0
kill: 0
setpgid: 0
system: 0
popen: 0
runExecutableAndCapture: 0
waitUntilExit: 0
readDataToEndOfFile: 0
setLaunchPath: 0
setArguments: 0
setStandardOutput: 0
setStandardError: 0
```

### 13.5 Full-file obsolete-token and direct-find counts

```text
NSTask active occurrences: 0
NSPipe active occurrences: 0
waitUntilExit active occurrences: 0
readDataToEndOfFile active occurrences: 0
setLaunchPath: active occurrences: 0
setArguments: active occurrences: 0
setStandardOutput: active occurrences: 0
setStandardError: active occurrences: 0
setpgid active occurrences: 0
runExecutableAndCapture active occurrences: 0
posix_spawn active occurrences: 2
waitpid active occurrences: 2
```

### 13.6 `PXWaitForProcessExit` static checks

```text
remaining-time calculation: present
probe timeout <= 1 second and <= remaining: present
timed overload probe call: present
empty actual NSString is the only exit-success condition: present
final return NO: present
pgrep command text: preserved
```

### 13.7 Diff whitespace validation

Command:

```text
git diff --check
```

Result:

```text
git_diff_check_exit=0
```

The line-ending warnings emitted for pre-existing coordinator Markdown files do not represent TASK-0.6 edits and did not cause `git diff --check` failure.

### 13.8 Toolchain availability

```text
clang=missing
make=missing
```

No local Objective-C/iOS/Theos compile or device runtime test was claimed.

## 14. Static/Runtime Scenario Matrix

All rows below are **STATIC REVIEW** unless stated otherwise. No compiled-target runtime test was run locally.

| # | Scenario | Required result | Evidence/status |
|---:|---|---|---|
| 1 | command `printf test` | returns `test` | STATIC REVIEW — normal result, stdout selected, final trim |
| 2 | command writes only stderr and exits 0 | returns trimmed stderr text | STATIC REVIEW — empty stdout plus stderr append and one final trim |
| 3 | command writes stdout and stderr | stdout, newline when needed, then stderr | STATIC REVIEW — deterministic merge branch confirmed |
| 4 | command exits non-zero with stdout | stdout, not `error` solely due exit code | STATIC REVIEW — zero `result.exitCode` checks |
| 5 | command exits non-zero with no output | empty string | STATIC REVIEW — normal completion passes failure filter; empty merge trims to empty |
| 6 | invalid/nil/empty command | `error`, no spawn | STATIC REVIEW — validation occurs before TASK-0.5 wrapper call |
| 7 | timeout 0 or negative | uses 60-second default | STATIC REVIEW — `timeoutSec <= 0` normalization |
| 8 | timeout NaN/Infinity | `error`, no spawn | STATIC REVIEW — `isfinite` validation before delegate |
| 9 | child exceeds deadline | `error` after bounded cleanup | STATIC REVIEW — TASK-0.5/CommandRunner result has `timedOut`, mapped to error |
| 10 | stdout exceeds cap | `error` because incomplete | STATIC REVIEW — `stdoutTruncated` maps to error |
| 11 | stderr exceeds cap | `error` because incomplete | STATIC REVIEW — `stderrTruncated` maps to error |
| 12 | child terminates by signal | `error` | STATIC REVIEW — `exitedNormally == NO` maps to error |
| 13 | both streams empty on normal exit | empty string | STATIC REVIEW — empty merged buffer and one trim |
| 14 | whitespace around output | trimmed once | STATIC REVIEW — exactly one final trimming call |
| 15 | process probe returns empty | `PXWaitForProcessExit` returns YES | STATIC REVIEW — explicit actual-string empty condition |
| 16 | process probe returns `error` | not interpreted as exit | STATIC REVIEW — sentinel length is non-zero; loop continues |
| 17 | process probe hangs | per-probe deadline prevents indefinite block | STATIC REVIEW — probe timeout `MIN(1.0, remaining)` |
| 18 | legacy caller command text | byte-for-byte unchanged | STATIC REVIEW — full diff contains only unchanged pgrep text and no other caller command edit |

## 15. Diff Review

### 15.1 AppDataCleaner.m diff stat

```text
 AppDataCleaner.m | 104 +++++++++++++++++++++++++++++++++++--------------------
 1 file changed, 66 insertions(+), 38 deletions(-)
```

Numeric stat:

```text
66  38  AppDataCleaner.m
```

### 15.2 Full diff review result

The full file-specific diff was reviewed. It contains only:

1. addition of `PXOutputQueryDefaultTimeoutSec`;
2. replacement of the obsolete `NSTask` compatibility interface with a private `AppDataCleaner` timed-overload declaration;
3. bounded-probe changes inside `PXWaitForProcessExit` while preserving its command string and outer return meaning;
4. replacement of the old `NSTask`/`NSPipe` helper with default and timed compatibility methods;
5. result validation, deterministic merge and concise failure diagnostics.

The diff does not contain:

- command-string edits;
- changes to the other eight business call sites;
- changes inside either direct find helper;
- changes to Clear completion or success/failure propagation;
- keychain changes;
- UI changes;
- Backup/Restore changes;
- direct executable migration;
- TASK-0.7 work;
- TASK-1.1 work.

## 16. Safety Notes

- The output-query compatibility helper is now bounded by both time and per-stream output size through the shared TASK-0.5/CommandRunner path.
- A truncated output is rejected instead of being consumed as a complete path list, count or status string.
- Signal termination is rejected through `exitedNormally == NO`.
- A normal non-zero exit remains compatible with commands such as `pgrep` no-match and commands that intentionally return useful output with a non-zero status.
- `PXWaitForProcessExit` fails closed: probe execution failure does not falsely confirm process exit.
- stdout and stderr are no longer captured into one shared pipe. The required deterministic stdout-first/stderr-second merge may expose stderr text to legacy callers whose command does not suppress stderr; caller decision logic itself was not changed.
- Commands that already redirect stderr retain their existing behavior.

## 17. Not Changed

TASK-0.6 intentionally did not change:

- any shell command text;
- any shell quoting, redirect, glob, pipe, separator, grep, find, sqlite or pgrep expression;
- caller business decisions or existing `@"error"` sentinel checks;
- keychain helper execution;
- unbounded legacy keychain `runAndCapture:` calls;
- process-killer behavior;
- direct find helper implementation;
- Clear targets, heuristics, completion semantics or verification policy;
- Backup/Restore behavior;
- UI behavior;
- public headers;
- `CommandRunner` implementation;
- TASK-0.7 or TASK-1.1.

## 18. Remaining Risks

- Runtime behavior has not been exercised on a compiled iOS target in this workspace.
- The two direct find helpers still have unbounded pipe reads and blocking `waitpid`; these are explicitly reserved for TASK-0.7.
- The output cap inherited from TASK-0.5 is 1 MiB independently for stdout and stderr. Queries that legitimately exceed that amount now return `@"error"` rather than partial data, as required.
- Legacy callers that do not suppress stderr may now receive deterministic stderr text after stdout. This is the required TASK-0.6 compatibility mapping, but it can affect pre-existing text-oriented caller decisions when commands emit diagnostics.
- `cleanAppSpecificFilesInSharedContainer:` does not explicitly check the `@"error"` sentinel. Its current file-existence guard normally prevents action on that sentinel; this pre-existing behavior was intentionally left unchanged.
- SQLite reference probes treat empty output as a reference because their existing logic only excludes exact `@"0"` and `@"error"`. This pre-existing business behavior was not changed.
- The IconState/notification probes use `containsString:@"found"`; the existing string `not found` also contains `found`. This pre-existing decision was not changed by TASK-0.6.
- GitHub Actions must confirm Objective-C compilation and target SDK compatibility.

## 19. GitHub Actions Handoff

```text
GitHub Actions: PENDING
Build requested: YES
Workflow expected: .github/workflows/build-ios-arm.yml
Build result: PENDING
Build URL/run ID: PENDING
Suggested status: READY_FOR_REVIEW
```

Agent stops after TASK-0.6. TASK-0.7 and TASK-1.1 remain unimplemented.
