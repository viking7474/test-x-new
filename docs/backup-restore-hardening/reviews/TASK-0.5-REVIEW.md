# TASK-0.5 Coordinator Review

## Metadata

```text
Task: TASK-0.5 — AppDataCleaner CommandResult Compatibility Wrapper
Reviewed commit: 77bcce4a689587719ee199a15fe70f97aba59301
Review status: ACCEPTED
Build gate: COMPLETED/PASSED as reported by project owner
Reviewed at: 2026-07-13 (Asia/Ho_Chi_Minh)
```

## Decision

TASK-0.5 is accepted and may be marked `COMPLETED`.

The task correctly replaced the race-prone custom shell execution loop inside `AppDataCleaner` with a private `CommandResult`-returning compatibility wrapper backed by bounded `CommandRunner` execution.

## Scope review

Commit `77bcce4` changes only:

- `AppDataCleaner.m`
- `docs/backup-restore-hardening/reports/TASK-0.5-REPORT.md`

No diff exists for:

- `AppDataCleaner.h`
- `CommandRunner.h`
- `CommandRunner.m`
- Backup/Restore code
- Keychain helper code
- UI code

The working tree is clean and the commit is present on `origin/newok`.

## Contract review

Accepted implementation:

```objc
- (CommandResult *)runCommandWithPrivilegesResult:(NSString *)command
                                        timeoutSec:(NSTimeInterval)timeoutSec;
```

Verified properties:

- the method is private to `AppDataCleaner.m`;
- invalid command or non-finite timeout returns `runnerError = EINVAL` before spawn;
- finite non-positive timeout becomes 60 seconds;
- command text is not trimmed or rewritten;
- execution delegates to bounded shell `CommandRunner`;
- stdout and stderr each use a 1 MiB retained-output cap;
- the existing `void` selectors and all caller control flow remain unchanged;
- timeout logging remains bounded to a 240-character command preview;
- no direct executable/argv migration was mixed into the task.

## Removed unsafe implementation

The old timed wrapper no longer contains:

- direct `posix_spawn`;
- post-spawn `setpgid`;
- polling `waitpid(..., WNOHANG)` loop;
- `usleep` polling/grace logic;
- direct negative-PGID `kill` calls;
- blocking final `waitpid`.

Process-group ownership, total deadline, bounded draining and termination are now delegated to the already-reviewed `CommandRunner` implementation.

## Static verification

The following coordinator checks passed:

```text
git show --check 77bcce4
git diff 77bcce4^ 77bcce4 -- AppDataCleaner.h CommandRunner.h CommandRunner.m
git status --short
```

The accepted source contains:

```text
PXPrivilegedCommandMaxOutputBytes = 1024 * 1024
runCommandWithPrivilegesResult:timeoutSec:
runAndCapture:timeoutSec:maxOutputBytes:
```

No `setpgid` remains in `AppDataCleaner.m`.

## Remaining launch-path finding

TASK-0.5 correctly identified three remaining local execution paths that are not yet hardened:

1. `runCommandAndGetOutput:`
   - uses `NSTask`;
   - redirects stdout and stderr to one pipe;
   - calls `waitUntilExit` before draining the pipe;
   - can deadlock when pipe output fills;
   - has no total timeout or output cap.

2. `findPathsMatchingPattern:`
   - direct `posix_spawn` and blocking pipe read/wait;
   - no timeout;
   - unbounded output accumulation.

3. `findPathsUnderRoot:directories:namePatterns:`
   - direct `posix_spawn` and blocking pipe read/wait;
   - no timeout;
   - unbounded output accumulation;
   - manually constructed argv.

The keychain legacy capture and `PXProcessKiller` are real remaining risks but belong to later scoped work and are not blockers for the immediate `AppDataCleaner` compatibility sequence.

## Follow-up decision

Phase 0 is extended with two additional tasks:

```text
TASK-0.6 — Bound runCommandAndGetOutput and remove NSTask deadlock
TASK-0.7 — Migrate direct find helpers to bounded executable/argv execution
```

TASK-0.6 is opened first because `waitUntilExit` before pipe draining is the most direct deadlock risk and is used by clear/verification-related callers.

TASK-1.1 remains locked until TASK-0.6 and TASK-0.7 have passed review and GitHub Actions.

## Final status

```text
TASK-0.5: COMPLETED
Review: ACCEPTED
Build: COMPLETED/PASSED reported by owner
Next authorized task: TASK-0.6
```
