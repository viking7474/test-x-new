# TASK-0.5 — AppDataCleaner CommandResult Compatibility Wrapper

## Metadata

- Phase: Phase 0 — Reliable Command Execution
- Status: READY
- Dependency: TASK-0.4 accepted and project-owner build gate completed
- Required report: `docs/backup-restore-hardening/reports/TASK-0.5-REPORT.md`
- Build gate: GitHub Actions by project owner
- Suggested commit: `phase0(task-0.5): route cleaner shell commands through CommandRunner`

## Objective

Replace the private race-prone `void` shell runner inside `AppDataCleaner.m` with a private result-returning compatibility wrapper backed by the bounded `CommandRunner` API.

This task establishes a structured result boundary for existing cleaner shell commands without changing their call sites or business decisions.

After this task:

- `AppDataCleaner` has a private method returning `CommandResult`;
- the existing `void` methods remain available and preserve their signatures;
- existing callers continue to run the same `/bin/sh -c` command strings;
- timeout, output bounding and process-group cleanup are delegated to `CommandRunner`;
- the old post-spawn `setpgid` race and custom kill/wait loop are removed from this helper;
- command failures are not yet propagated into Clear result/UI behavior.

This is a compatibility-infrastructure task. It must not change which files or containers are cleared.

## Required reading

Agent must read:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-0.1-REVIEW.md`
5. `docs/backup-restore-hardening/reviews/TASK-0.2-REVIEW.md`
6. `docs/backup-restore-hardening/reviews/TASK-0.3-REVIEW.md`
7. `docs/backup-restore-hardening/reviews/TASK-0.4-REVIEW.md`
8. `docs/backup-restore-hardening/reports/TASK-0.4-REPORT.md`
9. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
10. `CommandRunner.h`
11. `CommandRunner.m`
12. `AppDataCleaner.h`
13. `AppDataCleaner.m`
14. Every call site of:
    - `runCommandWithPrivileges:`
    - `runCommandWithPrivileges:timeoutSec:`
    - `runBatchedCommandsWithPrivileges:timeoutSec:`
15. Every remaining direct process-launch path in `AppDataCleaner.m`.

## Allowed files

Code changes are restricted to:

- `AppDataCleaner.m`

The agent must then create:

- `docs/backup-restore-hardening/reports/TASK-0.5-REPORT.md`

Do not modify:

- `AppDataCleaner.h`
- `CommandRunner.h`
- `CommandRunner.m`
- `AppDataBackupManager.h/.m`
- `AppEntitlementsReader.h/.m`
- any UI file
- any keychain helper file
- any task specification, status file or decision log

If another code file appears necessary for compilation, stop and report the dependency instead of expanding scope.

## Working-tree baseline note

At the time this task was opened, the connected workspace still showed uncommitted TASK-0.4 changes in `CommandRunner.h`, `CommandRunner.m` and TASK-0.4 documentation.

Preferred workflow:

1. commit and push TASK-0.4 before starting TASK-0.5;
2. start TASK-0.5 from that clean baseline.

If the agent is intentionally started before that cleanup, it must:

- record the initial `git status --short` in the report;
- treat pre-existing TASK-0.4 diffs as baseline, not as TASK-0.5 work;
- record a checksum or exact diff state for `CommandRunner.h/.m` before editing;
- prove those files are byte-for-byte unchanged at task completion;
- inspect TASK-0.5 scope with file-specific diff commands for `AppDataCleaner.m` and the new report;
- not stage, rewrite, revert or reformat pre-existing TASK-0.4 files.

The agent must not claim a globally clean working tree unless it is actually clean.

## Current source facts

The current private compatibility method is:

```objc
- (void)runCommandWithPrivileges:(NSString *)command timeoutSec:(int)timeoutSec
```

Its implementation currently:

1. validates the command;
2. defaults non-positive timeout to 60 seconds;
3. calls `posix_spawn` with `/bin/sh -c`;
4. calls `setpgid(pid, pid)` after spawn;
5. polls `waitpid(..., WNOHANG)` every 100 ms;
6. on timeout sends `SIGTERM` and `SIGKILL` to `-pid`;
7. performs a blocking final `waitpid`;
8. returns `void`, discarding spawn, exit, signal and timeout state.

Problems addressed by this task:

- post-spawn `setpgid` is race-prone;
- process-group ownership is not guaranteed before shell descendants start;
- the final blocking wait is not governed by the shared bounded engine;
- errors are not represented as a structured result;
- execution logic is duplicated from `CommandRunner`.

The following compatibility methods already exist and must retain their signatures:

```objc
- (void)runCommandWithPrivileges:(NSString *)command;
- (void)runCommandWithPrivileges:(NSString *)command timeoutSec:(int)timeoutSec;
- (void)runBatchedCommandsWithPrivileges:(NSArray<NSString *> *)commands
                               timeoutSec:(int)timeoutSec;
```

`AppDataCleaner.h` does not expose these methods. They remain private implementation details.

## Required private contract

Add this private result-returning method in `AppDataCleaner.m` only:

```objc
- (CommandResult *)runCommandWithPrivilegesResult:(NSString *)command
                                        timeoutSec:(NSTimeInterval)timeoutSec;
```

The method must not be declared in `AppDataCleaner.h`.

A private class extension declaration is allowed if used only to make the private contract explicit:

```objc
@interface AppDataCleaner ()
- (CommandResult *)runCommandWithPrivilegesResult:(NSString *)command
                                        timeoutSec:(NSTimeInterval)timeoutSec;
@end
```

Do not expose it publicly and do not add another public selector.

## Fixed output policy

Define a private per-stream output cap:

```objc
static const NSUInteger PXPrivilegedCommandMaxOutputBytes = 1024 * 1024;
```

Semantics:

- cap is 1 MiB for stdout;
- cap is independently 1 MiB for stderr;
- the underlying `CommandRunner` continues to drain/discard after the cap;
- the constant is private to `AppDataCleaner.m`;
- caller cannot override the cap in this task.

Do not use an unlimited output capture path.

## Input and timeout compatibility

### Valid command

A valid command must be an `NSString` with `length > 0`.

Do not trim the command before execution. A whitespace-only non-empty string was previously passed to `/bin/sh -c`; preserve that behavior.

### Invalid command

For a nil, non-string or empty command, the result-returning method must:

- not spawn a process;
- return a newly initialized `CommandResult`;
- set `runnerError = EINVAL`;
- preserve the normal default state for all other fields.

The legacy `void` wrapper continues to behave externally as a no-op because it discards this result.

Do not throw an exception.

### Timeout normalization

Preserve existing compatibility:

```text
timeoutSec <= 0  => effective timeout is 60 seconds
```

For a non-finite `NSTimeInterval` value:

- do not spawn;
- return a result with `runnerError = EINVAL`.

For a finite positive value:

- pass the exact value to `CommandRunner`;
- do not round or convert it to integer inside the result-returning method.

The legacy `void` timeout method still accepts `int`, so existing callers remain source-compatible.

## Required execution path

The private result-returning method must call exactly the bounded shell API:

```objc
[[CommandRunner shared] runAndCapture:command
                           timeoutSec:effectiveTimeout
                       maxOutputBytes:PXPrivilegedCommandMaxOutputBytes];
```

This intentionally preserves current shell semantics because existing cleaner commands use:

- pipelines;
- redirects;
- glob expansion;
- command separators;
- `|| true`;
- shell variables;
- `find -exec` expressions.

Do not migrate this wrapper to the direct executable API from TASK-0.4.

The bounded shell API already provides:

- monotonic total deadline;
- bounded stdout and stderr;
- spawn-time process group;
- group `SIGTERM` then final group `SIGKILL`;
- final group signal before leader reap;
- bounded `WNOHANG` reap;
- actual exit/signal mapping;
- structured spawn/runner/timeout state;
- partial output retention;
- no synthetic timeout exit code.

Do not duplicate any of this behavior in `AppDataCleaner.m`.

## Legacy wrapper delegation

### Default wrapper

Keep:

```objc
- (void)runCommandWithPrivileges:(NSString *)command
```

Its compatibility behavior remains:

```objc
[self runCommandWithPrivileges:command timeoutSec:60];
```

Do not make it call `CommandRunner` through a second independent path.

### Timed void wrapper

Keep the exact existing signature:

```objc
- (void)runCommandWithPrivileges:(NSString *)command
                      timeoutSec:(int)timeoutSec;
```

It must:

1. call `runCommandWithPrivilegesResult:timeoutSec:`;
2. receive the returned `CommandResult`;
3. preserve timeout diagnostic logging;
4. discard the result after logging;
5. not alter caller control flow.

The wrapper must not contain:

- `posix_spawn`;
- `setpgid`;
- `waitpid`;
- `kill`;
- `usleep`;
- custom polling;
- process-group calculations;
- pipe setup;
- file-action setup.

### Timeout log compatibility

If `result.timedOut == YES`, emit one concise log containing:

- the effective timeout;
- a safely shortened command preview.

Keep the existing command preview ceiling of 240 UTF-16 characters or an equivalent no-larger ceiling.

Do not log the full command when it is longer than the preview ceiling.

Do not append stdout/stderr to the timeout message.

### Non-timeout result logging

To minimize behavior and log-volume changes:

- do not add routine logging for successful commands;
- do not add routine logging for normal non-zero child exit in this task;
- do not dump stdout or stderr;
- optional one-line logging for `spawnError` or `runnerError` is not required and should be avoided unless needed for an existing diagnostic contract.

The structured result is added now so later migration tasks can inspect it explicitly.

## Batch wrapper compatibility

Keep the existing method and behavior:

```objc
- (void)runBatchedCommandsWithPrivileges:(NSArray<NSString *> *)commands
                               timeoutSec:(int)timeoutSec;
```

Do not change:

- filtering of non-string entries;
- trimming used to determine empty batch snippets;
- single-command fast path;
- joining multiple snippets with `"; "`;
- timeout argument passed to the timed wrapper;
- execution order;
- shell semantics.

The method automatically gains the new command engine because it delegates to the existing timed wrapper.

Do not make the batch helper return a result in this task.

## Result semantics

The private result-returning method must preserve the `CommandResult` received from `CommandRunner` without rewriting it.

### Normal success

```text
spawnError = 0
runnerError = 0
exitedNormally = YES
exitCode = 0
timedOut = NO
succeeded = YES
```

### Normal child failure

```text
exitedNormally = YES
exitCode = actual child exit code
succeeded = NO
```

Do not convert non-zero exit into runner error.

### Signal termination

```text
exitedNormally = NO
terminationSignal = actual signal
exitCode = -1
```

### Timeout

```text
timedOut = YES
no synthetic exit code
actual child wait status retained when available
```

### Spawn failure

```text
spawnError = posix_spawn return code
exitCode = -1
```

### Runner failure

```text
runnerError = structured internal error
```

Do not set `exitCode = 0` for compatibility and do not overwrite any error field.

## Behavioral compatibility boundary

This task changes command-execution infrastructure, but must not change business decisions.

Existing call sites still ignore command results. Therefore this task must not:

- abort a clear operation because a command failed;
- change `safeCompletion` success/failure;
- convert command failure into an `NSError` in Clear flow;
- alter verification behavior;
- alter which command strings execute;
- remove `|| true` from existing commands;
- change command ordering;
- change timeout values at call sites;
- change UI messages;
- change keychain behavior;
- change backup or restore behavior.

Propagation of command failure into typed clear results belongs to Phase 1 result/migration tasks.

## Required removal from the legacy helper

Remove from the implementation of `runCommandWithPrivileges:timeoutSec:`:

- direct `/bin/sh -c` argv construction;
- direct `posix_spawn`;
- post-spawn `setpgid(pid, pid)`;
- custom WNOHANG polling loop;
- timeout iteration arithmetic;
- direct group `kill` calls;
- final blocking `waitpid`;
- custom `usleep` grace period.

Do not remove process-related imports globally if they are still used by other methods in `AppDataCleaner.m`.

## Remaining process-launch inventory

The agent must audit and report all remaining process-launch implementations in `AppDataCleaner.m` after the task.

At minimum, inspect:

- `findPathsMatchingPattern:`;
- `findPathsUnderRoot:directories:namePatterns:`;
- `runCommandAndGetOutput:`;
- any remaining `posix_spawn`, `NSTask`, `waitpid`, `kill`, `setpgid`, `system` or `popen` call.

Do not modify those paths in TASK-0.5 unless they are part of the exact legacy wrapper body being replaced.

The report must classify each remaining path as:

```text
purpose
capture behavior
timeout behavior
output bound
process-group behavior
current callers
risk
recommended follow-up
```

This inventory will determine whether the coordinator opens an additional Phase 0 task before Phase 1.

## Explicitly out of scope

Do not perform any of the following:

- modify `AppDataCleaner.h`;
- expose command helpers publicly;
- migrate any command to `runExecutableAndCapture`;
- modify `runCommandAndGetOutput:`;
- replace `NSTask` usage;
- modify find helper implementations;
- refactor other direct `posix_spawn` sites;
- modify any command string;
- modify batch composition;
- change output parsing;
- change Clear completion/error propagation;
- add `PXClearRequest` or `PXClearResult`;
- change path resolution;
- remove bundle-container writes;
- fix fuzzy resolver behavior;
- change app-group behavior;
- change keychain behavior;
- change backup/restore code;
- change UI;
- add asynchronous command APIs;
- add cancellation tokens;
- start TASK-1.1;
- unrelated formatting cleanup.

## Required verification

Agent must perform and report these checks.

### Source and scope checks

1. Search all call sites of `runCommandWithPrivileges:`.
2. Search all call sites of `runCommandWithPrivileges:timeoutSec:`.
3. Search all call sites of `runBatchedCommandsWithPrivileges:timeoutSec:`.
4. Confirm no call site changed.
5. Confirm `AppDataCleaner.h` has no diff.
6. Confirm `CommandRunner.h/.m` have no diff.
7. Confirm only `AppDataCleaner.m` and the report are changed.

### Wrapper checks

8. Confirm the private result method exists exactly once.
9. Confirm it calls bounded `CommandRunner runAndCapture:timeoutSec:maxOutputBytes:`.
10. Confirm fixed cap is 1 MiB per stream.
11. Confirm it does not use direct executable API.
12. Confirm invalid command returns `runnerError = EINVAL` without spawn.
13. Confirm non-positive timeout defaults to 60 seconds.
14. Confirm non-finite timeout returns `EINVAL`.
15. Confirm whitespace-only commands are not trimmed/rejected.
16. Confirm the result is returned without field rewriting.

### Legacy compatibility checks

17. Confirm default `void` wrapper still delegates with 60 seconds.
18. Confirm timed `void` wrapper signature is unchanged.
19. Confirm timed wrapper delegates to the result method.
20. Confirm timed wrapper retains bounded command preview logging on timeout.
21. Confirm timed wrapper does not contain spawn/wait/kill/group logic.
22. Confirm batch helper semantics and source call sites remain unchanged.
23. Confirm no command string or timeout call-site value changed.

### Race and lifecycle checks

24. Confirm no post-spawn `setpgid` remains in the replaced helper.
25. Confirm no blocking final wait remains in the replaced helper.
26. Confirm timeout/group lifecycle comes only from `CommandRunner`.
27. Confirm no duplicate bounded execution engine was added.

### Remaining-path audit

28. Search `AppDataCleaner.m` for:

```text
posix_spawn
posix_spawnp
setpgid
waitpid
NSTask
system(
popen(
kill(
usleep
```

29. List every remaining execution path in the report.
30. Do not claim Phase 0 has eliminated every direct spawn unless the search proves it.

### Diff checks

31. Run `git diff --check`.
32. Review full diff.
33. Review `git diff --stat`.
34. Confirm no generated/binary file changed.

Full iOS/Theos compilation is performed by the project owner through `.github/workflows/build-ios-arm.yml`.

## Verification scenario matrix

The report must include at least this matrix, using runtime evidence when available and otherwise clearly marking static review.

| # | Scenario | Expected result |
|---|---|---|
| 1 | command `true` | structured success result |
| 2 | command `false` | normal non-zero child exit preserved |
| 3 | command writes stdout | stdout captured, caller behavior unchanged |
| 4 | command writes stderr | stderr captured, caller behavior unchanged |
| 5 | stdout exceeds 1 MiB | stdout truncated flag set, command still drained |
| 6 | stderr exceeds 1 MiB | stderr truncated flag set, command still drained |
| 7 | command exceeds timeout | `timedOut = YES`, bounded group cleanup |
| 8 | shell pipeline exceeds timeout | whole inherited command group targeted |
| 9 | command nil | EINVAL result, no spawn |
| 10 | command empty | EINVAL result, no spawn |
| 11 | whitespace-only command | passed to shell, not rejected by wrapper |
| 12 | timeout 0 | normalized to 60 seconds |
| 13 | timeout negative | normalized to 60 seconds |
| 14 | timeout NaN/Inf via result method | EINVAL, no spawn |
| 15 | default void wrapper | still uses 60-second policy |
| 16 | timed void wrapper success | returns void and does not alter caller flow |
| 17 | timed void wrapper child failure | returns void and does not alter caller flow |
| 18 | timed void wrapper timeout | emits concise timeout diagnostic |
| 19 | batch one command | same single-command path |
| 20 | batch multiple commands | same `; ` composition and order |
| 21 | concurrent calls from final sweep | each call uses independent CommandRunner execution state |
| 22 | existing command with `|| true` | shell semantics preserved |

Do not invent runtime results. Mark unexecuted cases as static review.

## Acceptance criteria

Agent must copy this checklist into the report.

- [ ] Only `AppDataCleaner.m` and the required report are changed.
- [ ] `AppDataCleaner.h` is unchanged.
- [ ] `CommandRunner.h/.m` are unchanged.
- [ ] Private `runCommandWithPrivilegesResult:timeoutSec:` exists.
- [ ] Private method returns `CommandResult`.
- [ ] Private method uses bounded shell `CommandRunner` API.
- [ ] Fixed output cap is 1 MiB per stream.
- [ ] Invalid command returns EINVAL without spawn.
- [ ] Non-positive timeout defaults to 60 seconds.
- [ ] Non-finite timeout returns EINVAL.
- [ ] Whitespace-only command compatibility is preserved.
- [ ] Existing `void` method signatures remain unchanged.
- [ ] Default wrapper still uses 60 seconds.
- [ ] Timed void wrapper delegates to result wrapper.
- [ ] Timeout logging remains concise and command preview is bounded.
- [ ] Existing caller control flow is unchanged.
- [ ] Batch helper behavior is unchanged.
- [ ] No command strings are changed.
- [ ] No timeout values at call sites are changed.
- [ ] Old direct spawn/poll/kill implementation is removed from the timed wrapper.
- [ ] No post-spawn `setpgid` remains in that wrapper.
- [ ] No blocking final wait remains in that wrapper.
- [ ] No direct executable migration is performed.
- [ ] No Clear/Backup/Restore/Keychain/UI behavior is intentionally changed.
- [ ] Remaining direct launch paths are fully inventoried in the report.
- [ ] Full diff and diff stat are reviewed.
- [ ] `git diff --check` passes.
- [ ] `TASK-0.5-REPORT.md` is created.
- [ ] GitHub Actions is recorded as PENDING.
- [ ] Suggested status is READY_FOR_REVIEW.
- [ ] Agent stops after TASK-0.5.

## Required report content

Create:

```text
docs/backup-restore-hardening/reports/TASK-0.5-REPORT.md
```

The report must include:

- exact private selector added;
- output cap constant and per-stream semantics;
- input validation behavior;
- timeout normalization behavior;
- legacy wrapper delegation graph;
- old code removed from the timed wrapper;
- timeout log compatibility;
- result/error mapping;
- confirmation that business flow does not inspect the result yet;
- complete caller audit;
- complete remaining process-launch inventory;
- source/static verification matrix;
- files changed;
- files intentionally not changed;
- remaining risks;
- GitHub Actions marked `PENDING`;
- suggested status `READY_FOR_REVIEW`.

## Agent handoff prompt

```text
Thực hiện duy nhất TASK-0.5 theo file:

docs/backup-restore-hardening/tasks/TASK-0.5-app-data-cleaner-command-result-wrapper.md

Bắt buộc đọc README, STATUS, DECISIONS, reviews TASK-0.1 đến TASK-0.4, TASK-0.4 report, report template, CommandRunner.h/.m và AppDataCleaner.h/.m trước khi sửa code.

Chỉ được sửa AppDataCleaner.m.

Sau khi hoàn thành phải tạo:

docs/backup-restore-hardening/reports/TASK-0.5-REPORT.md

Yêu cầu chính:

- thêm private method runCommandWithPrivilegesResult:timeoutSec: trả CommandResult;
- dùng bounded CommandRunner runAndCapture:timeoutSec:maxOutputBytes:;
- output cap cố định 1 MiB cho mỗi stream;
- timeout <= 0 tiếp tục mặc định 60 giây;
- timeout không finite trả EINVAL;
- command nil/non-string/empty trả EINVAL và không spawn;
- không trim/reject whitespace-only command;
- giữ nguyên hai void method signatures;
- void timed wrapper chỉ delegate, giữ timeout log ngắn và bỏ qua result;
- xóa custom posix_spawn/setpgid/waitpid/kill/usleep loop khỏi wrapper cũ;
- giữ nguyên batch composition và toàn bộ call site;
- không đổi command string hoặc timeout call-site;
- không migrate sang direct executable API;
- không đổi Clear/Backup/Restore/Keychain/UI behavior;
- audit và liệt kê mọi direct process-launch path còn lại trong AppDataCleaner.m;
- không sửa các path còn lại trong task này;
- không thực hiện TASK-1.1.

Tự review full diff, chạy git diff --check, điền đầy đủ acceptance checklist, ghi GitHub Actions PENDING, đề xuất READY_FOR_REVIEW và dừng lại.
```

## Gate after TASK-0.5

After report, review and GitHub Actions pass, the coordinator must:

1. inspect the remaining direct process-launch inventory;
2. decide whether an additional Phase 0 task is required;
3. only open TASK-1.1 if no blocking command-execution defect remains for the upcoming Clear safety work.

TASK-1.1 is not automatically opened merely because TASK-0.5 builds successfully.
