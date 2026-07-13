# TASK-0.6 Coordinator Review

## Metadata

```text
Task: TASK-0.6 — Bound Output Query Helper and Remove NSTask Deadlock
Implementation commit: c9833a0
Commit message: 0.7
Agent report: docs/backup-restore-hardening/reports/TASK-0.6-REPORT.md
Build gate: PASSED — reported completed by project owner in chat
Review result: ACCEPTED
```

The commit message does not match the task identifier. This is a traceability issue only; the reviewed source and report implement TASK-0.6, not TASK-0.7.

## Scope review

The implementation changes only the intended local process-query path in `AppDataCleaner.m`, plus the required report and coordinator documentation that was already present as the task baseline.

Protected source files remain unchanged:

- `AppDataCleaner.h`
- `CommandRunner.h`
- `CommandRunner.m`
- `AppDataBackupManager.*`
- `AppEntitlementsReader.*`
- `common/PXProcessKiller.*`

No Backup, Restore, Keychain or UI behavior was changed.

## Accepted findings

### Bounded output-query path

The existing selector remains:

```objc
- (NSString *)runCommandAndGetOutput:(NSString *)command;
```

A private timed overload was added in `AppDataCleaner.m`:

```objc
- (NSString *)runCommandAndGetOutput:(NSString *)command
                          timeoutSec:(NSTimeInterval)timeoutSec;
```

The default selector delegates with a 60-second timeout. The timed overload delegates to the accepted TASK-0.5 result-returning wrapper rather than creating another spawn or pipe engine.

### Deadlock removal

The old sequence:

```text
NSTask launch
→ waitUntilExit
→ readDataToEndOfFile
```

was removed. `AppDataCleaner.m` no longer contains active uses of:

- `NSTask`
- `NSPipe`
- `waitUntilExit`
- `readDataToEndOfFile`
- the local NSTask compatibility declaration

This removes the pipe-fill deadlock where a child could block before exit while the parent waited without draining output.

### Result mapping

The implementation correctly maps these states to the legacy `@"error"` sentinel:

- invalid command or non-finite timeout;
- `spawnError`;
- `runnerError`;
- timeout;
- signal/non-normal termination;
- stdout or stderr truncation.

A normal non-zero exit is not rejected solely due to `exitCode`, preserving the previous helper's captured-output behavior.

### Output compatibility

For a complete normal execution:

1. stdout is used first;
2. stderr is appended after a newline when required;
3. the merged output is trimmed once;
4. empty output remains `@""`.

The command text is not rewritten with `2>&1`.

### `PXWaitForProcessExit`

Each `pgrep` probe now uses the timed overload with a positive timeout no greater than one second and no greater than the current outer remaining time.

The probe is fail-closed:

- actual empty output confirms process exit;
- `@"error"` does not confirm exit;
- a PID continues polling;
- outer expiration returns `NO`.

### Deferred direct find paths

The two direct helpers remain byte-for-byte unchanged:

- `findPathsMatchingPattern:`
- `findPathsUnderRoot:directories:namePatterns:`

After TASK-0.6, exactly two `posix_spawn` calls and two blocking `waitpid` calls remain in `AppDataCleaner.m`, all belonging to those helpers.

## Static verification

```text
git show --check c9833a0: PASS
NSTask active occurrences: 0
NSPipe active occurrences: 0
waitUntilExit active occurrences: 0
readDataToEndOfFile active occurrences: 0
posix_spawn occurrences: 2
waitpid occurrences: 2
findPathsMatchingPattern call sites: 23
findPathsUnderRoot call sites: 5
```

## Non-blocking observations

- `PXWaitForProcessExit` still uses `CFAbsoluteTimeGetCurrent` for its outer compatibility timeout. Per-probe execution is bounded, so this is not accepted as a blocker for TASK-0.6.
- Existing text-oriented callers may now receive captured stderr after stdout. This is the explicitly approved TASK-0.6 contract.
- Existing caller bugs such as `containsString:@"found"` also matching `@"not found"` remain outside this infrastructure task.
- The commit message should use the actual task identifier in future commits.

## Decision

TASK-0.6 is accepted and may be marked `COMPLETED`.

TASK-0.7 may be opened to migrate the two remaining direct `find` helpers to bounded direct executable/argv execution.

TASK-1.1 remains locked until TASK-0.7 passes source review and the project-owner GitHub Actions gate.
