# TASK-0.6 — Bound Output Query Helper and Remove NSTask Deadlock

## Metadata

- Phase: Phase 0 — Reliable Command Execution
- Status: READY
- Dependency: TASK-0.5 accepted and project-owner build gate completed
- Required report: `docs/backup-restore-hardening/reports/TASK-0.6-REPORT.md`
- Build gate: GitHub Actions by project owner
- Suggested commit: `phase0(task-0.6): bound cleaner output queries`

## Objective

Replace the private `NSTask` implementation of:

```objc
- (NSString *)runCommandAndGetOutput:(NSString *)command;
```

with a bounded compatibility implementation backed by the accepted `CommandRunner`/`CommandResult` infrastructure.

The task must remove the current pipe-deadlock path caused by:

```text
child writes stdout/stderr into one pipe
→ parent calls waitUntilExit
→ parent does not drain pipe until child exits
→ child can block forever when pipe fills
```

After this task:

- no `NSTask`, `NSPipe`, `waitUntilExit` or `readDataToEndOfFile` execution path remains in `AppDataCleaner.m`;
- `runCommandAndGetOutput:` keeps its existing selector and string-return contract;
- output queries have a total deadline and bounded retained output;
- shell syntax and all existing query command strings remain unchanged;
- normal non-zero shell exits continue to return captured output rather than automatically becoming the legacy `@"error"` sentinel;
- incomplete or runner-level failure results cannot be mistaken for trustworthy query output;
- `PXWaitForProcessExit` cannot become unbounded because one `pgrep` probe hangs;
- the two direct `find` helpers remain untouched for TASK-0.7.

This is still a compatibility-infrastructure task. It must not change Clear/Backup/Restore/Keychain/UI business decisions.

## Required reading

Agent must read before editing:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-0.5-REVIEW.md`
5. `docs/backup-restore-hardening/reports/TASK-0.5-REPORT.md`
6. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
7. `CommandRunner.h`
8. `CommandRunner.m`
9. `AppDataCleaner.h`
10. `AppDataCleaner.m`
11. Every caller of `runCommandAndGetOutput:`
12. `PXWaitForProcessExit`
13. The two remaining direct find helpers, only to prove they were not changed:
    - `findPathsMatchingPattern:`
    - `findPathsUnderRoot:directories:namePatterns:`

## Allowed files

Code changes are restricted to:

- `AppDataCleaner.m`

The agent must create:

- `docs/backup-restore-hardening/reports/TASK-0.6-REPORT.md`

Do not modify:

- `AppDataCleaner.h`
- `CommandRunner.h`
- `CommandRunner.m`
- `AppDataBackupManager.h/.m`
- `AppEntitlementsReader.h/.m`
- `common/PXProcessKiller.h/.m`
- any UI file
- any keychain helper file
- any task specification, status, roadmap, review or decision file

If another code file appears necessary for compilation, stop and report the dependency instead of expanding scope.

## Current unsafe implementation

The current helper uses:

```objc
NSTask *task = [[NSTask alloc] init];
[task setLaunchPath:@"/bin/sh"];
[task setArguments:@[@"-c", command]];

NSPipe *pipe = [NSPipe pipe];
[task setStandardOutput:pipe];
[task setStandardError:pipe];

[task launch];
[task waitUntilExit];
NSData *data = [file readDataToEndOfFile];
```

Problems:

- the parent waits before draining the pipe;
- stdout and stderr can fill the pipe and deadlock child plus parent;
- no timeout exists;
- retained output is unbounded;
- process-group cleanup is absent;
- exception handling collapses launch failure into a string sentinel;
- one stalled query can block clear or verification indefinitely.

## Required compatibility API

Keep the existing selector unchanged:

```objc
- (NSString *)runCommandAndGetOutput:(NSString *)command;
```

Add one private timed overload in `AppDataCleaner.m` only:

```objc
- (NSString *)runCommandAndGetOutput:(NSString *)command
                          timeoutSec:(NSTimeInterval)timeoutSec;
```

Do not expose either selector in `AppDataCleaner.h`.

The existing selector must delegate exactly once to the timed overload with the default query timeout:

```objc
static const NSTimeInterval PXOutputQueryDefaultTimeoutSec = 60.0;
```

The default of 60 seconds is intentionally conservative to preserve compatibility for existing filesystem and sqlite queries while still preventing indefinite hangs.

## Execution source of truth

The timed overload must not create a new process engine.

It must delegate to the accepted private result wrapper from TASK-0.5:

```objc
CommandResult *result = [self runCommandWithPrivilegesResult:command
                                                   timeoutSec:effectiveTimeout];
```

Do not call:

```objc
NSTask
NSPipe
posix_spawn
waitpid
kill
setpgid
system
popen
runExecutableAndCapture:arguments:timeoutSec:maxOutputBytes:
```

inside either output-query selector.

Do not duplicate deadline, pipe, signal or process-group logic.

## Timeout contract

For the timed string overload:

- finite `timeoutSec > 0`: use the exact value;
- finite `timeoutSec <= 0`: use `PXOutputQueryDefaultTimeoutSec`;
- NaN or ±Infinity: return `@"error"` without spawning;
- default selector: pass `PXOutputQueryDefaultTimeoutSec`.

The method may rely on `runCommandWithPrivilegesResult:timeoutSec:` to produce `runnerError = EINVAL`, but the string compatibility layer must map invalid input to `@"error"`.

## Output cap

The timed overload must inherit the TASK-0.5 bounded shell wrapper cap:

```text
stdout retained cap: 1 MiB
stderr retained cap: 1 MiB
```

Do not add a second, larger cap and do not call an unbounded `CommandRunner` API.

## Result-to-string mapping

The timed overload returns a trimmed `NSString` for compatibility.

### Return `@"error"` when any of these is true

- command is nil;
- command is not an `NSString` at runtime;
- command length is zero;
- timeout is non-finite;
- `result.runnerError != 0`;
- `result.spawnError != 0`;
- `result.timedOut == YES`;
- `result.exitedNormally == NO`;
- `result.stdoutTruncated == YES`;
- `result.stderrTruncated == YES`.

Rationale: callers must not make filesystem/process/reference decisions from incomplete, timed-out or runner-failed output.

### Normal non-zero exit compatibility

Do not map a normal non-zero `exitCode` to `@"error"` by itself.

The old `NSTask` method returned whatever bytes were written even when the shell exited non-zero. Preserve that behavior:

```text
exitedNormally == YES
exitCode != 0
no spawn/runner/timeout/truncation failure
→ return merged captured output
```

If both captured streams are empty, return `@""`.

### Deterministic stdout/stderr merge

The old implementation placed stdout and stderr in one pipe. `CommandRunner` captures them separately, so exact byte-level interleaving cannot be reconstructed.

Use this deterministic compatibility merge:

1. append `stdoutString` first when non-empty;
2. if stderr is non-empty and stdout does not end in a newline, append one newline;
3. append `stderrString`;
4. trim leading/trailing whitespace and newline characters exactly once;
5. return the resulting string.

Do not:

- append shell redirection such as `2>&1` to the command;
- wrap or rewrite the command;
- parse output as JSON/plist;
- discard stderr silently;
- change output based solely on `exitCode`.

## Logging contract

Preserve the existing diagnostic intent:

```objc
NSLog(@"[AppDataCleaner] Running command: %@", command);
```

For failure paths, add at most one concise diagnostic line containing structured status fields such as:

```text
spawnError
runnerError
timedOut
terminationSignal
stdoutTruncated
stderrTruncated
```

Do not log full captured stdout or stderr.

Do not log the same failure multiple times in nested wrappers.

## PXWaitForProcessExit hardening

`PXWaitForProcessExit` currently has an outer timeout but one `runCommandAndGetOutput:` call can exceed it indefinitely.

Update only this caller to use the timed overload.

Required behavior:

1. preserve the existing outer loop and return meaning;
2. calculate remaining outer time before each probe;
3. stop when remaining time is `<= 0`;
4. use a per-probe timeout no greater than one second and no greater than remaining time;
5. use a minimum positive probe timeout to avoid passing zero through the default-timeout normalization;
6. call:

```objc
[selfRef runCommandAndGetOutput:cmd timeoutSec:probeTimeout]
```

Recommended calculation:

```objc
NSTimeInterval remaining = timeout - elapsed;
NSTimeInterval probeTimeout = MIN(1.0, MAX(0.1, remaining));
```

Compatibility behavior for the returned string:

- empty string means no PID was reported, so return `YES`;
- `@"error"` does not mean the process exited; continue until the outer timeout;
- non-empty non-error output means the process still appears present; sleep and retry;
- preserve the existing final `NO` when the process did not disappear before the outer timeout.

This task must not replace `pgrep`, change the process name match mode, or migrate the query to a direct executable API.

## Caller compatibility

Except for `PXWaitForProcessExit` selecting the new timed overload, all existing callers of:

```objc
runCommandAndGetOutput:
```

must remain source-compatible and keep their existing command strings and decision logic.

Known callers include:

- `cleanAppSpecificFilesInSharedContainer:bundleID:appName:companyName:`
- `directoryExistsAndHasAnyContent:`
- `hasSystemDatabaseReferencesForBundleID:`
- `PXWaitForProcessExit`

Do not rewrite these callers to consume `CommandResult` in this task.

Do not change the existing `@"error"` sentinel checks.

## Remove obsolete NSTask compatibility declaration

After migrating the only `NSTask` execution helper, remove the local compatibility declaration block near the top of `AppDataCleaner.m`:

```objc
@interface NSTask : NSObject
...
@end
```

Remove it only if source audit confirms there are no remaining `NSTask` references in `AppDataCleaner.m`.

After completion, these tokens must have zero active occurrences in `AppDataCleaner.m`:

```text
NSTask
NSPipe
waitUntilExit
readDataToEndOfFile
setLaunchPath:
setArguments:
setStandardOutput:
setStandardError:
```

## Explicitly out of scope

Do not modify:

### Direct find helpers

- `findPathsMatchingPattern:`
- `findPathsUnderRoot:directories:namePatterns:`

Their direct `posix_spawn`, pipe and `waitpid` implementations remain for TASK-0.7.

### Keychain commands

Do not migrate the legacy `runAndCapture:` calls used by `ldid` or keychain helper execution.

### Process killer

Do not modify `PXProcessKiller` or kill-by-name policy.

### Business behavior

Do not change:

- clear targets;
- container discovery heuristics;
- verification policy;
- keychain policy;
- success/failure completion;
- UI text or state;
- Backup/Restore behavior.

### Command text

Do not change any command string, shell quoting, redirect, pipeline, grep, find, sqlite or `pgrep` expression.

## Required source audit

The report must list every active `runCommandAndGetOutput:` caller after the task and record:

- caller name;
- command purpose;
- whether stderr is suppressed by the command itself;
- expected output shape;
- behavior for empty output;
- behavior for `@"error"`;
- whether normal non-zero exit output remains meaningful.

The report must also prove that the two direct find helper bodies are byte-for-byte or diff-wise unchanged.

## Verification commands

Agent must perform and record equivalent checks for:

```text
git status --short
git diff --check
git diff --stat
git diff -- AppDataCleaner.m
git diff -- AppDataCleaner.h CommandRunner.h CommandRunner.m
```

Search `AppDataCleaner.m` for:

```text
runCommandAndGetOutput:
NSTask
NSPipe
waitUntilExit
readDataToEndOfFile
posix_spawn(
waitpid(
findPathsMatchingPattern:
findPathsUnderRoot:
runExecutableAndCapture:
```

Required post-task expectations:

```text
NSTask active occurrences: 0
NSPipe active occurrences: 0
waitUntilExit active occurrences: 0
readDataToEndOfFile active occurrences: 0
setpgid active occurrences: 0
runExecutableAndCapture in output-query helper: 0
posix_spawn active occurrences: still exactly 2, only in direct find helpers
waitpid active occurrences: still exactly 2, only in direct find helpers
```

## Static scenario matrix

The report must evaluate these scenarios without claiming runtime PASS unless actually tested on a compiled target:

| # | Scenario | Required result |
|---:|---|---|
| 1 | command `printf test` | returns `test` |
| 2 | command writes only stderr and exits 0 | returns trimmed stderr text |
| 3 | command writes stdout and stderr | returns stdout, newline when needed, then stderr |
| 4 | command exits non-zero with stdout | returns stdout, not `error` solely due exit code |
| 5 | command exits non-zero with no output | returns empty string |
| 6 | invalid/nil/empty command | returns `error`, no spawn |
| 7 | timeout 0 or negative | uses 60-second default |
| 8 | timeout NaN/Infinity | returns `error`, no spawn |
| 9 | child exceeds deadline | returns `error` after bounded cleanup |
| 10 | stdout exceeds cap | returns `error` because output is incomplete |
| 11 | stderr exceeds cap | returns `error` because output is incomplete |
| 12 | child terminates by signal | returns `error` |
| 13 | both streams empty on normal exit | returns empty string |
| 14 | whitespace around output | trimmed once as before |
| 15 | `PXWaitForProcessExit` probe returns empty | returns YES |
| 16 | probe returns `error` | does not treat process as exited |
| 17 | probe hangs | per-probe deadline prevents indefinite block |
| 18 | legacy caller command text | byte-for-byte unchanged |

## Acceptance checklist

- [ ] Only `AppDataCleaner.m` and required TASK-0.6 report are changed.
- [ ] Existing `runCommandAndGetOutput:` selector remains.
- [ ] Private timed overload is added only in `.m`.
- [ ] Default query timeout is 60 seconds.
- [ ] Timed overload delegates to `runCommandWithPrivilegesResult:timeoutSec:`.
- [ ] No duplicate process execution engine is introduced.
- [ ] No unbounded `CommandRunner` API is used.
- [ ] Invalid/non-finite input maps to `@"error"` without spawn.
- [ ] Spawn/runner/timeout/signal/truncation failure maps to `@"error"`.
- [ ] Normal non-zero exit is not automatically mapped to `@"error"`.
- [ ] stdout and stderr are merged deterministically.
- [ ] Output is trimmed once.
- [ ] Empty successful output returns `@""`.
- [ ] `PXWaitForProcessExit` uses a bounded per-probe timeout.
- [ ] Probe `@"error"` is not interpreted as process exit.
- [ ] All other caller command strings and decision logic remain unchanged.
- [ ] `NSTask` compatibility declaration is removed.
- [ ] No active `NSTask`, `NSPipe`, `waitUntilExit` or `readDataToEndOfFile` remains.
- [ ] Direct find helpers remain unchanged.
- [ ] Exactly two direct `posix_spawn`/`waitpid` paths remain for TASK-0.7.
- [ ] No Clear/Backup/Restore/Keychain/UI behavior is intentionally changed.
- [ ] `AppDataCleaner.h` and `CommandRunner.h/.m` are unchanged.
- [ ] Full caller audit is included in TASK-0.6 report.
- [ ] `git diff --check` passes.
- [ ] GitHub Actions is recorded as PENDING.
- [ ] Suggested status is `READY_FOR_REVIEW`.
- [ ] Agent stops after TASK-0.6.

## Required report format

Create:

```text
docs/backup-restore-hardening/reports/TASK-0.6-REPORT.md
```

The report must contain:

1. Metadata
2. Summary
3. Working-tree baseline
4. Files changed
5. Exact contract changes
6. Result-to-string mapping
7. Timeout behavior
8. stdout/stderr merge behavior
9. `PXWaitForProcessExit` behavior
10. Complete caller audit
11. Proof direct find helpers were unchanged
12. Acceptance checklist
13. Verification commands/results
14. Static/runtime scenario matrix
15. Diff review
16. Safety notes
17. Not changed
18. Remaining risks
19. GitHub Actions handoff

Use:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

Do not claim local Objective-C/iOS runtime tests passed unless they were actually run.

## Agent handoff prompt

```text
Thực hiện duy nhất TASK-0.6 theo file:

docs/backup-restore-hardening/tasks/TASK-0.6-bounded-output-query-helper.md

Bắt buộc đọc README, STATUS, DECISIONS, TASK-0.5 review/report, report template, CommandRunner.h/.m và toàn bộ AppDataCleaner.h/.m trước khi sửa.

Chỉ được sửa AppDataCleaner.m và tạo:

docs/backup-restore-hardening/reports/TASK-0.6-REPORT.md

Mục tiêu:
- thay NSTask/NSPipe implementation của runCommandAndGetOutput: bằng bounded CommandRunner compatibility path;
- thêm private timed overload;
- default timeout 60 giây;
- giữ selector cũ, command string và caller business logic;
- merge stdout trước, stderr sau, trim một lần;
- trả "error" cho invalid input, spawn/runner failure, timeout, signal hoặc truncation;
- không coi normal non-zero exit là error nếu execution vẫn hoàn tất bình thường;
- sửa riêng PXWaitForProcessExit để mỗi pgrep probe có deadline tối đa 1 giây và không coi "error" là process đã thoát;
- xóa NSTask compatibility declaration khi không còn reference;
- không sửa hai direct find helpers;
- không thực hiện TASK-0.7 hoặc TASK-1.1.

Dừng sau TASK-0.6 và tạo report đầy đủ với GitHub Actions PENDING.
```

## Gate after TASK-0.6

After the agent stops:

1. coordinator reviews report and exact diff;
2. project owner runs GitHub Actions;
3. TASK-0.6 is marked completed only after both pass;
4. TASK-0.7 may then be opened;
5. TASK-1.1 remains locked.
