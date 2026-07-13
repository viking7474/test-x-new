# TASK-0.7 — Bounded Direct Find Helpers

## Metadata

- Phase: Phase 0 — Reliable Command Execution
- Status: READY
- Dependency: TASK-0.6 accepted and project-owner build gate completed
- Required report: `docs/backup-restore-hardening/reports/TASK-0.7-REPORT.md`
- Build gate: GitHub Actions by project owner
- Suggested commit: `phase0(task-0.7): bound direct find helpers`

## Objective

Migrate the final two direct process-launch implementations in `AppDataCleaner.m`:

```objc
- (NSArray *)findPathsMatchingPattern:(NSString *)pattern;

- (NSArray<NSString *> *)findPathsUnderRoot:(NSString *)root
                               directories:(BOOL)directories
                              namePatterns:(NSArray<NSString *> *)namePatterns;
```

from local `pipe` / `posix_spawn` / blocking `read` / blocking `waitpid` code to the bounded direct executable/argv API introduced in TASK-0.4.

After this task:

- both helpers execute exact `/usr/bin/find` without `/bin/sh`;
- arguments remain separate argv elements;
- execution has a total monotonic deadline;
- stdout and stderr capture are bounded;
- timeout cleanup uses the accepted process-group lifecycle;
- no local `posix_spawn`, pipe capture or blocking `waitpid` remains in `AppDataCleaner.m`;
- incomplete output is never consumed as a destructive path list;
- existing callers, path patterns, find expressions and result ordering remain unchanged.

This task finishes local process-execution hardening in `AppDataCleaner.m`. It must not begin Clear Data safety work.

## Required reading

Agent must read before editing:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-0.4-REVIEW.md`
5. `docs/backup-restore-hardening/reviews/TASK-0.5-REVIEW.md`
6. `docs/backup-restore-hardening/reviews/TASK-0.6-REVIEW.md`
7. `docs/backup-restore-hardening/reports/TASK-0.6-REPORT.md`
8. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
9. `CommandRunner.h`
10. `CommandRunner.m`
11. `AppDataCleaner.h`
12. the complete `AppDataCleaner.m`
13. all 23 callers of `findPathsMatchingPattern:`
14. all 5 callers of `findPathsUnderRoot:directories:namePatterns:`
15. current implementations of both find helpers

## Allowed files

Code changes are restricted to:

- `AppDataCleaner.m`

The agent must then create:

- `docs/backup-restore-hardening/reports/TASK-0.7-REPORT.md`

Do not modify:

- `AppDataCleaner.h`
- `CommandRunner.h`
- `CommandRunner.m`
- `AppDataBackupManager.*`
- `AppEntitlementsReader.*`
- `common/PXProcessKiller.*`
- any UI file
- any keychain helper
- any task specification, review, status file, roadmap or decision log

If another code file appears necessary for compilation, stop and report the dependency instead of expanding scope.

## Baseline process inventory

At task start, `AppDataCleaner.m` must contain exactly:

```text
posix_spawn(: 2
waitpid(: 2
pipe(: 2
read(pipefds...): 2
```

These occurrences must belong only to:

- `findPathsMatchingPattern:`
- `findPathsUnderRoot:directories:namePatterns:`

There must be no active `NSTask`, `NSPipe`, `waitUntilExit` or `readDataToEndOfFile` path after TASK-0.6.

Record the initial counts and method-body fingerprints in the report before editing.

## Fixed execution policy

Add private constants in `AppDataCleaner.m`:

```objc
static NSString * const PXFindExecutablePath = @"/usr/bin/find";
static const NSTimeInterval PXFindCommandTimeoutSec = 120.0;
static const NSUInteger PXFindCommandMaxOutputBytes = 4 * 1024 * 1024;
```

Contract:

- executable path is exactly `/usr/bin/find`;
- timeout is exactly 120 seconds per helper invocation;
- output cap is 4 MiB independently for stdout and stderr;
- no caller-specific timeout or cap is introduced in TASK-0.7;
- no unbounded fallback is allowed.

Do not use `firstExistingPath:` or add alternate find locations. Preserve the exact executable path used by the old implementations.

## Shared private execution helper

Add one private helper in `AppDataCleaner.m`:

```objc
- (NSArray<NSString *> *)runBoundedFindWithArguments:(NSArray<NSString *> *)arguments;
```

Declare it only in the existing private class extension.

This helper must call:

```objc
CommandResult *result =
    [[CommandRunner shared] runExecutableAndCapture:PXFindExecutablePath
                                          arguments:arguments
                                         timeoutSec:PXFindCommandTimeoutSec
                                     maxOutputBytes:PXFindCommandMaxOutputBytes];
```

Do not create a second capture engine.

### Input validation

Before calling `CommandRunner`, return `@[]` when:

- `arguments` is nil;
- `arguments` is not an `NSArray` at runtime;
- `arguments.count == 0`;
- any element is not an `NSString`;
- any element is an empty string.

Do not trim, normalize, quote, join or reinterpret argument strings.

The direct API remains authoritative for UTF-8, embedded-NUL, overflow, allocation and spawn validation.

### Failure mapping

Return `@[]` when any of these is true:

```objc
result == nil
result.spawnError != 0
result.runnerError != 0
result.timedOut == YES
result.exitedNormally == NO
result.stdoutTruncated == YES
result.stderrTruncated == YES
```

This is a fail-closed destructive-path policy. Never parse partial output after timeout, signal termination, capture truncation or runner failure.

Emit one concise diagnostic containing structured status fields. Do not log full stdout, stderr or the complete path list.

### Normal non-zero exit

Do not reject a complete normal execution solely because:

```objc
result.exitCode != 0
```

The previous helpers parsed captured stdout without checking exit status. Preserve complete stdout from a normal non-zero `find` exit, for example when `find` reports a local traversal error after emitting valid matches.

### stdout/stderr policy

Path parsing must use only:

```objc
result.stdoutString
```

Do not merge stderr into the path list.

Captured stderr is diagnostic data only. Its content must not become an array element. A non-empty but non-truncated stderr stream does not by itself invalidate complete stdout.

This preserves the old stdout-only business contract while preventing inherited stderr noise.

### Path parsing

Parse stdout exactly as the previous implementations did:

1. treat nil stdout as `@""`;
2. split with `[NSCharacterSet newlineCharacterSet]`;
3. keep only objects that are `NSString` instances with `length > 0`;
4. preserve find output order;
5. preserve duplicate paths;
6. preserve leading/trailing spaces inside non-empty path strings;
7. do not sort;
8. do not canonicalize;
9. do not standardize paths;
10. do not resolve symlinks;
11. do not deduplicate;
12. do not trim each line.

An empty stdout returns `@[]`.

The legacy newline-delimited path limitation remains unchanged. Do not introduce `-print0` in this task.

## `findPathsMatchingPattern:` migration

### Validation

Add an explicit fail-closed guard:

```objc
if (![pattern isKindOfClass:[NSString class]] || pattern.length == 0) {
    return @[];
}
```

Do not trim the pattern.

### Search-root optimization

Preserve the existing search-root algorithm exactly:

- default root is `/`;
- locate the first `*`, `?` or `[`;
- derive the static prefix before the first wildcard;
- use the containing directory only when it is an existing absolute directory longer than `/`;
- otherwise keep `/`.

Do not change wildcard semantics or optimize using another algorithm.

### Exact argv contract

Build exactly these arguments:

```objc
NSArray<NSString *> *arguments = @[
    @"-L",
    searchRoot,
    @"-path",
    pattern
];
```

Then return:

```objc
return [self runBoundedFindWithArguments:arguments];
```

The runner creates `argv[0]`. Do not include `@"find"` in `arguments`.

Equivalent process shape:

```text
/usr/bin/find -L <searchRoot> -path <pattern>
```

No shell is involved. Characters such as spaces, quotes, `$`, `;`, `|`, `&&`, `*`, `?` and `[` remain data in their exact argv element. Wildcards are interpreted by `find -path`, not by a shell.

### Forbidden implementation

Remove from this method:

- `pipe`;
- `posix_spawn`;
- `posix_spawn_file_actions_*`;
- raw `read` loop;
- raw `close` calls for capture pipe ownership;
- blocking `waitpid`;
- borrowed `[NSString UTF8String]` argv pointers;
- local `NSMutableData` capture;
- local PID/status management.

## `findPathsUnderRoot:directories:namePatterns:` migration

### Preserve current validation

Keep the existing behavior:

- invalid/empty root returns `@[]`;
- invalid/empty `namePatterns` returns `@[]`;
- missing or non-directory root returns `@[]`;
- non-string pattern entries are ignored;
- empty string pattern entries are ignored;
- order of remaining patterns is preserved;
- no trimming is added;
- no spawn occurs when no valid pattern remains.

### Exact argv construction

Build an Objective-C argument array equivalent to:

```text
-L <root> -type <f|d> ( -name <p1> -o -name <p2> ... ) -print
```

Required construction order:

```objc
NSMutableArray<NSString *> *arguments = [NSMutableArray array];
[arguments addObject:@"-L"];
[arguments addObject:root];
[arguments addObject:@"-type"];
[arguments addObject:(directories ? @"d" : @"f")];
[arguments addObject:@"("];

for each pattern in original filtered order:
    before every pattern except the first, add @"-o"
    add @"-name"
    add the exact pattern string

[arguments addObject:@")"];
[arguments addObject:@"-print"];
```

Then return:

```objc
return [self runBoundedFindWithArguments:arguments];
```

Do not include `@"find"` as an argument. The runner creates `argv[0]`.

Do not change `-L`, `-type`, parentheses, `-name`, `-o` or `-print` ordering.

### Forbidden implementation

Remove from this method:

- argument-count arithmetic;
- `calloc` for argv;
- `char **argv`;
- borrowed `UTF8String` pointers;
- `pipe`;
- `posix_spawn`;
- `posix_spawn_file_actions_*`;
- raw read loop;
- capture-pipe close logic;
- blocking `waitpid`;
- manual `free(argv)`;
- local PID/status ownership.

## Compatibility requirements

Do not change:

- either existing public/private selector;
- return types;
- the 23 `findPathsMatchingPattern:` call sites;
- the 5 `findPathsUnderRoot:directories:namePatterns:` call sites;
- pattern strings at callers;
- caller iteration or deletion behavior;
- search-root optimization;
- `-L` symlink-following behavior;
- find expression structure;
- newline splitting;
- result order;
- duplicate handling;
- any Clear success/failure or UI behavior.

No caller may be migrated to another selector.

## Direct-execution requirements

Both helpers must ultimately use only:

```objc
runExecutableAndCapture:arguments:timeoutSec:maxOutputBytes:
```

They must not use:

- `/bin/sh -c`;
- `runAndCapture:`;
- `runCommandWithPrivilegesResult:`;
- `runCommandAndGetOutput:`;
- `system`;
- `popen`;
- `NSTask`;
- `posix_spawnp`;
- PATH lookup;
- shell quoting;
- command-string construction;
- shell glob expansion;
- redirection;
- pipeline parsing.

## Full-file process primitive gate

After the task, source audit of `AppDataCleaner.m` must show:

```text
active NSTask: 0
active NSPipe: 0
active waitUntilExit: 0
active readDataToEndOfFile: 0
posix_spawn(: 0
posix_spawn_file_actions: 0
waitpid(: 0
pipe(pipefds...): 0
read(pipefds...): 0
char **argv for find: 0
runExecutableAndCapture: exactly 1 local shared-helper call
```

Do not remove unrelated `close`, `calloc` or `free` operations used for file I/O, SQLite or other non-process purposes.

The report must distinguish direct process primitives from delegated calls to `CommandRunner` and `PXProcessKiller`.

## Caller audit

The report must enumerate all caller groups for both helpers.

For each caller group record:

- caller method;
- number of calls;
- pattern/root source;
- whether returned paths are files or directories;
- destructive action performed on each result;
- why `@[]` is fail-closed for that caller;
- whether duplicates/order matter;
- confirmation that caller source did not change.

Expected aggregate counts at task start and completion:

```text
findPathsMatchingPattern: 23 calls
findPathsUnderRoot:directories:namePatterns: 5 calls
```

## Error and diagnostic policy

On invalid helper input, return `@[]` without spawn.

On execution failure, log one concise line with fields such as:

```text
spawnError
runnerError
timedOut
exitedNormally
terminationSignal
exitCode
stdoutTruncated
stderrTruncated
```

Do not log:

- complete stdout;
- complete stderr;
- every returned path;
- unbounded argument arrays;
- secrets from path names.

A normal non-zero exit with complete capture may optionally produce one concise diagnostic, but must still parse stdout.

## Required scenario matrix

The report must mark each scenario as STATIC REVIEW or actual runtime execution. Do not claim runtime PASS without a compiled target.

| # | Scenario | Required result |
|---:|---|---|
| 1 | exact valid pattern with no matches | `@[]` |
| 2 | valid pattern with one match | one path |
| 3 | valid pattern with multiple matches | ordered paths |
| 4 | pattern contains spaces | one exact argv element |
| 5 | pattern contains quotes or semicolon | data only; no shell execution |
| 6 | pattern contains `*`, `?` or `[` | interpreted by `find -path` |
| 7 | invalid nil/non-string/empty pattern | `@[]`, no spawn |
| 8 | optimized prefix directory exists | derived search root preserved |
| 9 | optimized prefix directory missing | root remains `/` |
| 10 | valid root with one name pattern | exact find expression |
| 11 | multiple name patterns | ordered `-name/-o` expression |
| 12 | mixed invalid pattern entries | invalid entries filtered as before |
| 13 | no valid name pattern remains | `@[]`, no spawn |
| 14 | root missing or not directory | `@[]`, no spawn |
| 15 | directories YES | `-type d` |
| 16 | directories NO | `-type f` |
| 17 | normal non-zero find exit with complete stdout | parse stdout |
| 18 | normal non-zero find exit with only stderr | `@[]` |
| 19 | timeout | `@[]`; no partial path list |
| 20 | signal termination | `@[]` |
| 21 | stdout truncation | `@[]` |
| 22 | stderr truncation | `@[]` |
| 23 | spawn/runner failure | `@[]` |
| 24 | Unicode root/pattern | separate exact NSString arguments |
| 25 | newline-delimited stdout | split/filter exactly as legacy |
| 26 | duplicate paths in stdout | duplicates preserved |
| 27 | path line with spaces | spaces preserved, line not trimmed |
| 28 | all 28 caller sites | source unchanged |

## Verification requirements

Before completion, agent must:

1. record initial `git status --short`;
2. record checksums for `AppDataCleaner.h`, `CommandRunner.h` and `CommandRunner.m`;
3. fingerprint both helper bodies before editing;
4. count both helper call sites;
5. review all 28 caller sites;
6. implement only the shared direct-find helper and two migrations;
7. search for forbidden APIs in both methods;
8. confirm full-file process primitive counts reach the required values;
9. confirm exactly one direct runner call exists in the shared helper;
10. confirm no `/bin/sh` or shell wrapper is used by the find path;
11. confirm `arguments` does not include `@"find"`;
12. confirm pattern and root strings are separate argv elements;
13. confirm stderr is not parsed as a path;
14. confirm normal non-zero exit is not rejected solely by exit code;
15. confirm timeout/truncation never returns partial paths;
16. confirm all caller source remains unchanged;
17. confirm protected source files remain byte-for-byte unchanged;
18. run `git diff --check`;
19. review full file-specific diff;
20. review diff stat and generated/binary files.

## Required report

Create:

```text
docs/backup-restore-hardening/reports/TASK-0.7-REPORT.md
```

The report must include:

1. metadata and suggested status;
2. working-tree baseline;
3. files changed;
4. exact constants;
5. shared helper selector and implementation policy;
6. failure/result mapping;
7. stdout-only parsing policy;
8. exact argv for both helper types;
9. search-root compatibility proof;
10. pattern filtering compatibility proof;
11. caller audit with aggregate counts;
12. process primitive before/after inventory;
13. protected-file checksums;
14. scenario matrix;
15. full diff review;
16. remaining risks;
17. GitHub Actions handoff.

End the report with:

```text
GitHub Actions: PENDING
Suggested status: READY_FOR_REVIEW
```

## Acceptance checklist

- [ ] Only `AppDataCleaner.m` and the required report are changed by the agent.
- [ ] Both existing find selectors remain unchanged.
- [ ] Private constants are added with exact required values.
- [ ] `runBoundedFindWithArguments:` exists only in `.m`.
- [ ] Shared helper uses exact `/usr/bin/find` direct execution.
- [ ] Shared helper uses a 120-second deadline.
- [ ] Shared helper uses a 4 MiB cap per stream.
- [ ] No shell is involved.
- [ ] Runner creates argv[0]; `@"find"` is not supplied in arguments.
- [ ] Invalid arguments fail closed without spawn.
- [ ] Timeout, signal, runner/spawn error and truncation return `@[]`.
- [ ] No partial output is returned on incomplete execution.
- [ ] Normal non-zero exit is not rejected solely by exit code.
- [ ] Only stdout is parsed as paths.
- [ ] stderr is never inserted into the returned array.
- [ ] Path order and duplicates are preserved.
- [ ] No line trimming, sorting, canonicalization or deduplication is added.
- [ ] `findPathsMatchingPattern:` preserves search-root optimization.
- [ ] Exact `-L root -path pattern` argument order is preserved.
- [ ] `findPathsUnderRoot:` preserves input filtering and root check.
- [ ] Exact `-type`, parentheses, `-name`, `-o`, `-print` order is preserved.
- [ ] Manual C argv allocation is removed.
- [ ] Borrowed UTF-8 argv pointers are removed.
- [ ] Local pipe/spawn/read/wait implementations are removed.
- [ ] Full-file `posix_spawn` and `waitpid` counts become zero.
- [ ] Existing 23 plus 5 caller sites remain unchanged.
- [ ] Protected source files remain unchanged.
- [ ] No Clear/Backup/Restore/Keychain/UI behavior is changed.
- [ ] `git diff --check` passes.
- [ ] Required report is created.
- [ ] GitHub Actions is recorded as PENDING.
- [ ] Suggested status is READY_FOR_REVIEW.
- [ ] Agent stops after TASK-0.7.

## Explicitly forbidden follow-on work

Do not:

- start TASK-1.1;
- introduce `PXResolvedContainer`;
- modify any destructive path validator;
- change Clear targets;
- remove application bundle writes;
- propagate command failures into Clear results;
- modify Backup, Restore, Keychain or UI;
- harden `PXProcessKiller`;
- migrate keychain commands;
- change `find` to `-print0`;
- add async APIs or cancellation tokens;
- add alternate executable lookup.

## Gate after TASK-0.7

After the agent stops:

1. coordinator reviews source, report and process primitive inventory;
2. project owner runs GitHub Actions;
3. TASK-0.7 becomes `COMPLETED` only after both pass;
4. Phase 0 may then be closed;
5. TASK-1.1 may then be specified and opened separately.
