# TASK-0.4 Coordinator Review

## Metadata

```text
Task ID: TASK-0.4
Task title: Direct Executable and argv Capture API
Agent report: docs/backup-restore-hardening/reports/TASK-0.4-REPORT.md
Build gate: COMPLETED/PASSED — reported by project owner after agent report
Review result: ACCEPTED
```

## Scope review

- Code changes are limited to `CommandRunner.h` and `CommandRunner.m`.
- The required report was created.
- No existing caller was migrated.
- No Clear, Backup, Restore, Keychain or UI business logic was changed.
- No TASK-0.5 implementation was included.

## Contract review

Accepted public API:

```objc
- (CommandResult *)runExecutableAndCapture:(NSString *)executablePath
                                 arguments:(NSArray<NSString *> *)arguments
                                timeoutSec:(NSTimeInterval)timeoutSec
                            maxOutputBytes:(NSUInteger)maxOutputBytes;
```

The implementation satisfies the intended separation between executable path and `argv[1...]`:

- exact absolute executable path is passed to `posix_spawn`;
- direct execution does not use `/bin/sh -c`;
- `argv[0]` is created by the runner;
- arguments are not joined or shell-parsed;
- direct execution uses the bounded capture/process-group engine from TASK-0.2 and TASK-0.3;
- current process environment is passed through `environ` for the direct API;
- existing shell APIs preserve their previous environment-pointer policy.

## Memory and validation review

The owned-argv implementation provides:

- lossless UTF-8 conversion;
- embedded-NUL rejection for direct execution;
- non-string argument rejection;
- absolute-path validation;
- integer-overflow checks;
- partial-allocation cleanup;
- terminal `NULL` argv entry;
- one ownership/cleanup path after `posix_spawn` returns.

Shell wrappers intentionally preserve legacy embedded-NUL/truncation behavior rather than changing old call semantics in this task.

## Compatibility review

- `run:` remains unchanged in public contract.
- Legacy `runAndCapture:` remains unbounded and without process-group policy.
- Bounded shell capture retains TASK-0.3 behavior.
- Direct execution is bounded-only.
- No current code path uses the new selector yet.

## Remaining risks

- Runtime argv edge cases were not exercised in the connected Windows workspace.
- The agent report still records GitHub Actions as pending because it was written before the project-owner build; the owner subsequently reported the task completed.
- Critical callers still construct shell command strings until dedicated migration tasks are opened.
- `AppDataCleaner` still contains a separate race-prone `void` command helper; this is the target of TASK-0.5.

## Decision

TASK-0.4 is accepted. TASK-0.5 may open.
