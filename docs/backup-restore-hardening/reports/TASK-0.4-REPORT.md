# TASK-0.4 Agent Report

## Metadata

```text
Task ID: TASK-0.4
Task title: Direct Executable and argv Capture API
Task specification: docs/backup-restore-hardening/tasks/TASK-0.4-direct-executable-argv-api.md
Agent: GPT-5.6 Thinking
Started at: 2026-07-13 (Asia/Ho_Chi_Minh)
Finished at: 2026-07-13 (Asia/Ho_Chi_Minh)
Suggested status: READY_FOR_REVIEW
Commit hash: chưa commit
```

## 1. Summary

Đã thêm đúng một public API bounded để chạy executable trực tiếp bằng exact `posix_spawn` path và argv tách biệt, không đi qua shell:

```objc
- (CommandResult *)runExecutableAndCapture:(NSString *)executablePath
                                 arguments:(NSArray<NSString *> *)arguments
                                timeoutSec:(NSTimeInterval)timeoutSec
                            maxOutputBytes:(NSUInteger)maxOutputBytes;
```

API mới yêu cầu absolute executable path, xem `arguments` là `argv[1...]`, tự tạo owned `argv[0]`, truyền current process environment bằng `environ`, bật monotonic deadline, per-stream output cap và spawn-time process group.

Capture engine đã được refactor để nhận executable, arguments, environment pointer và `PXCaptureOptions`. Shell legacy, shell bounded và direct bounded dùng chung một implementation cho pipe setup, capture loop, cap/drain-discard, deadline, process-group setup, timeout cleanup và result mapping.

Không sửa `run:`, caller, Clear, Backup, Restore, Keychain hoặc UI. Không migrate tar, ldid, keychain helper hoặc file-operation commands. Không thực hiện TASK-0.5.

## 2. Files Changed

| File | Change | Why required |
|---|---|---|
| `CommandRunner.h` | Thêm đúng một public selector direct-executable bounded capture. | Public contract bắt buộc của TASK-0.4. |
| `CommandRunner.m` | Thêm owned argv validation/allocation, environment policy và refactor shared capture launch target. | Chạy executable trực tiếp mà vẫn tái sử dụng toàn bộ TASK-0.2/TASK-0.3 behavior. |
| `docs/backup-restore-hardening/reports/TASK-0.4-REPORT.md` | Tạo agent report. | Report bắt buộc của task. |

Không sửa code ngoài `CommandRunner.h` và `CommandRunner.m`.

Các thay đổi coordinator trong `README.md`, `ROADMAP.md`, `STATUS.md`, `DECISIONS.md`, TASK-0.3 review và TASK-0.4 specification đã tồn tại trong working tree trước TASK-0.4. Agent không sửa các file đó.

## 3. Contract Changes

### Exact public selector được thêm

```objc
- (CommandResult *)runExecutableAndCapture:(NSString *)executablePath
                                 arguments:(NSArray<NSString *> *)arguments
                                timeoutSec:(NSTimeInterval)timeoutSec
                            maxOutputBytes:(NSUInteger)maxOutputBytes;
```

Không thêm convenience overload hoặc public environment/cwd/stdin API.

### Semantics của `arguments`

- Caller truyền `arguments` tương ứng chính xác `argv[1...]`.
- Runner tự tạo `argv[0]` từ exact `executablePath`.
- Mảng rỗng hợp lệ và tạo argv chỉ gồm `argv[0]`, sau đó `NULL`.
- Empty-string argument hợp lệ và được giữ bằng một owned buffer một byte chứa terminal `NUL`.
- Whitespace, newline, wildcard và shell metacharacter được giữ như literal bytes trong một argument riêng.
- Không join arguments, không quote, không parse và không tự chèn `--`.

### Validation rules

Direct API trả `runnerError = EINVAL`, không spawn, khi:

- `executablePath == nil`;
- executable object không phải `NSString` ở runtime;
- executable path rỗng;
- path không bắt đầu bằng `/`;
- `arguments == nil`;
- arguments object không phải `NSArray` ở runtime;
- một item không phải `NSString`;
- path hoặc argument không encode lossless sang UTF-8;
- path hoặc argument chứa embedded NUL;
- `timeoutSec` không finite hoặc `<= 0`;
- `maxOutputBytes == 0`.

Arithmetic overflow trong owned argv construction dùng `runnerError = EOVERFLOW`. C allocation failure dùng `runnerError = ENOMEM`.

Không dùng `fileExistsAtPath:`, `access`, `stat`, path canonicalization hoặc symlink resolution để quyết định executable có chạy được hay không. `posix_spawn` return code là authority và được ghi vào `spawnError`.

`firstExistingPath:` vẫn có pre-existing `fileExistsAtPath:` cho chức năng path lookup riêng của API đó; direct/shared launch path không gọi method này và TASK-0.4 không sửa nó.

### Direct path và shell path

**Legacy shell capture**

```text
executable: /bin/sh
arguments:  ["-c", command]
environment pointer: NULL, giữ behavior hiện tại
deadline: disabled
cap: disabled
process group: disabled
embedded-NUL rejection policy: disabled để giữ shell compatibility
```

**Bounded shell capture**

```text
executable: /bin/sh
arguments:  ["-c", command]
environment pointer: NULL, giữ behavior hiện tại
deadline: enabled
cap: enabled
process group: enabled
embedded-NUL rejection policy: disabled để giữ shell compatibility
```

**Direct bounded capture**

```text
executable: exact executablePath
arguments: exact separate caller arguments
environment pointer: environ
deadline: enabled
cap: enabled
process group: enabled
embedded-NUL rejection policy: enabled
shell: none
```

### Compatibility

- `run:` implementation không đổi.
- Public shell APIs không bị xóa hoặc đổi selector.
- Shell command vẫn được `/bin/sh -c` diễn giải như trước.
- Legacy capture vẫn không nhận deadline/cap/process-group policy.
- Bounded shell giữ TASK-0.2/TASK-0.3 policy.
- Không caller nào được đổi hoặc migrate.

## 4. Implementation Notes

### Shared-engine refactor

Capture entry nội bộ đổi từ command-string-specific helper sang:

```objc
static CommandResult *PXRunCaptureExecutable(id executablePathObject,
                                              id argumentsObject,
                                              char *const environment[],
                                              BOOL rejectEmbeddedNUL,
                                              PXCaptureOptions options);
```

Helper này chịu trách nhiệm:

1. monotonic start timestamp;
2. timeout/cap validation;
3. executable/arguments validation;
4. owned argv construction;
5. pipe và nonblocking setup;
6. spawn attributes/file actions;
7. exact `posix_spawn`;
8. capture loop;
9. per-stream cap và drain/discard;
10. group timeout cleanup;
11. bounded WNOHANG reap;
12. output conversion và duration finalization.

Không tạo capture loop, cap implementation, deadline loop hoặc process-group cleanup thứ hai cho direct API.

### Owned argv type và layout

```c
typedef struct {
    char **items;
    size_t count;
} PXOwnedArgv;
```

Với `N = arguments.count`:

```text
items[0]     = owned UTF-8 copy của executablePath
items[1]     = owned UTF-8 copy của arguments[0]
...
items[N]     = owned UTF-8 copy của arguments[N - 1]
items[N + 1] = NULL
count        = N + 1 owned non-NULL string slots
```

Pointer array dùng `calloc`, vì vậy mọi chưa-được-allocate slot là `NULL` và partial cleanup có thể gọi `free(NULL)` an toàn.

`posix_spawn` nhận:

```c
posix_spawn(&pid,
            ownedArgv.items[0],
            &actions,
            spawnAttributes,
            (char *const *)ownedArgv.items,
            environment);
```

Executable path truyền cho `posix_spawn` và `argv[0]` là cùng exact owned path copy. Không dùng `posix_spawnp`.

### UTF-8 encoding strategy

Mỗi path/argument dùng:

```objc
dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO
```

Nếu conversion trả `nil`, input bị reject bằng `EINVAL`. Không giữ pointer mượn từ `UTF8String` trong shared capture engine.

`run:` legacy vẫn dùng implementation riêng và không bị refactor theo yêu cầu giữ scope.

### Embedded NUL detection

Sau lossless encoding, direct policy kiểm tra toàn bộ byte range bằng:

```c
memchr(utf8Data.bytes, '\0', byteLength)
```

Nếu có NUL trong encoded path/argument, direct API trả `EINVAL` trước pipe creation và trước spawn.

Terminal NUL do runner thêm sau copy không bị xem là embedded NUL.

### Empty-string argument

Empty string encode thành data length `0`. Runner vẫn:

- allocate `length + 1`, tức một byte;
- không bỏ argument khỏi argv;
- đặt byte đầu thành `\0`.

Do đó child nhận một argument rỗng thật sự, không phải thiếu argument.

### Overflow checks

Owned argv kiểm tra:

1. `argumentCount + 2` không vượt `SIZE_MAX`;
2. pointer count không vượt `SIZE_MAX / sizeof(char *)`;
3. mỗi UTF-8 byte length không vượt `SIZE_MAX - 1` trước `length + 1`;
4. index/counter conversion chỉ thực hiện sau các check trên.

Arithmetic overflow trả `EOVERFLOW`; không thử allocate với size đã wrap.

### Allocation and partial cleanup

- Pointer array allocation dùng `calloc`; failure trả `ENOMEM`.
- Mỗi string buffer dùng `malloc(length + 1)`; failure trả `ENOMEM`.
- `PXDestroyOwnedArgv` free từng string slot, sau đó pointer array, rồi reset state.
- Nếu path allocation/encoding fail, pointer array được cleanup.
- Nếu argument thứ `k` fail, mọi buffer từ executable đến argument `k - 1` được free.
- Pre-spawn pipe/fcntl/attribute/action/timing/deadline failure đều destroy owned argv.
- Sau `posix_spawn` return, owned argv được free đúng một lần cho cả spawn success và spawn failure.
- Không giữ argv đến capture completion vì POSIX spawn call đã trả và child launch đã tiêu thụ launch arguments.

### Environment policy

`CommandRunner.m` khai báo:

```c
extern char **environ;
```

Policy:

- direct API truyền `environ` vào exact `posix_spawn`;
- shell capture wrappers truyền `NULL` như implementation trước TASK-0.4;
- `run:` tiếp tục truyền `NULL`;
- runner không mutate environment;
- không tạo environment dictionary;
- không thực hiện PATH lookup.

Environment pointer là borrowed process-global pointer, không thuộc ownership của runner và không được free.

### Process-group policy

Direct API đặt:

```text
deadlineEnabled = YES
outputCapEnabled = YES
processGroupEnabled = YES
```

Vì dùng cùng engine, direct path giữ nguyên:

- `POSIX_SPAWN_SETPGROUP`;
- pgroup `0`;
- PGID bằng child PID sau spawn success;
- owned negative-PGID validation;
- group SIGTERM;
- bounded drain grace;
- final group SIGKILL trước leader reap;
- bounded `waitpid(..., WNOHANG)` reap;
- final nonblocking drain/close;
- escaped-descendant limitation.

Không có blocking wait trong direct/shared capture path. Blocking wait helper duy nhất vẫn chỉ do `run:` legacy gọi.

### Result and error mapping

- Invalid input: `runnerError = EINVAL`, không spawn.
- Size arithmetic overflow: `runnerError = EOVERFLOW`, không spawn.
- C allocation failure: `runnerError = ENOMEM`, không spawn.
- `posix_spawn` failure: exact status trong `spawnError`.
- File-action/attribute/clock/read/select/signal/reap failure: structured `runnerError` theo existing precedence.
- Child non-zero exit: actual `exitCode`, không phải runner error.
- Signal exit: actual `terminationSignal`.
- Deadline: `timedOut = YES`, không dùng synthetic exit code.
- `duration`: monotonic và bao gồm validation, argv construction, setup, spawn, capture và timeout cleanup.
- stdout/stderr cap, truncation flags, partial output và UTF-8 boundary conversion giữ nguyên.

### Resource ownership table

| Resource | Acquire | Owner/state | Cleanup |
|---|---|---|---|
| Executable UTF-8 buffer | `malloc(length + 1)` | `PXOwnedArgv.items[0]` | `PXDestroyOwnedArgv` trước return hoặc ngay sau spawn return |
| Argument UTF-8 buffers | Một `malloc` mỗi item | `PXOwnedArgv.items[1...]` | Partial/full `PXDestroyOwnedArgv` |
| argv pointer array | `calloc(N + 2, sizeof(char *))` | `PXOwnedArgv.items` | `PXDestroyOwnedArgv` |
| Environment pointer | `environ` hoặc `NULL` | Borrowed, không sở hữu | Không free/mutate |
| stdout pipe ends | `pipe` | FD integer, `-1` sau close | Mọi early return và capture finalization |
| stderr pipe ends | `pipe` | FD integer, `-1` sau close | Mọi early return và capture finalization |
| Spawn file actions | successful init flag | Local initialized state | Destroy đúng một lần; status checked |
| Spawn attributes | `attributesInitialized` | Local ownership flag | `PXDestroySpawnAttributes`, đúng một lần |
| Child PID/wait state | successful spawn | `PXChildState` | Normal or bounded WNOHANG reap |
| Process group state | successful group-enabled spawn | `PXProcessGroupState` | Group TERM/KILL policy; không heap allocation |
| stdout/stderr data | `NSMutableData` | ARC/local strong references | Method scope; strings assigned before return |

### Caller audit

Current callers:

- `AppDataBackupManager.m`: 26 `run:` occurrences và 9 legacy `runAndCapture:` occurrences.
- `AppDataCleaner.m`: 2 legacy `runAndCapture:` occurrences.
- `AppEntitlementsReader.m`: 1 legacy `runAndCapture:` occurrence.
- Bounded shell overload callers: 0.
- Direct executable selector callers: 0.

Không caller nào được sửa. Không migrate tar, ldid, keychain helper, chmod/chown/cp/mv/mkdir/rm hoặc destructive workflow.

Repo có các `posix_spawn` implementation khác ngoài `CommandRunner`; chỉ được audit và không bị chỉnh sửa trong TASK-0.4.

## 5. Acceptance Checklist

- [x] Thêm đúng một public direct-executable bounded capture API.
- [x] API nhận absolute executable path và arguments array.
- [x] Arguments được hiểu là `argv[1...]`.
- [x] Runner tự đặt `argv[0]`.
- [x] Empty argument được giữ.
- [x] Không dùng shell cho direct API.
- [x] Không dùng `posix_spawnp` hoặc PATH lookup.
- [x] Không join arguments thành command string.
- [x] Reject relative/empty/invalid executable path.
- [x] Reject non-string argument.
- [x] Reject embedded NUL trong path/argument.
- [x] Có owned UTF-8 argv với NULL terminator.
- [x] Có overflow và allocation failure handling.
- [x] Partial argv allocation cleanup đầy đủ.
- [x] Owned argv cleanup đúng mọi path.
- [x] Shared capture engine được tái sử dụng; không duplicate capture loop.
- [x] Direct API có deadline/cap/process group.
- [x] Direct API dùng environment policy đã chốt.
- [x] Shell API cũ giữ behavior.
- [x] `run:` giữ behavior.
- [x] Structured result semantics không đổi.
- [x] Không sửa caller.
- [x] Không sửa Clear/Backup/Restore/Keychain/UI.
- [x] Không triển khai TASK-0.5.
- [x] `git diff --check` pass.
- [x] Tạo `TASK-0.4-REPORT.md` đúng template.
- [x] GitHub Actions ghi PENDING trong agent report.
- [x] Agent dừng sau TASK-0.4.

## 6. Verification Performed

### Static/source checks

| Check/command | Result | Evidence/notes |
|---|---|---|
| Required reading | PASS | Đã đọc README, STATUS, DECISIONS, review TASK-0.1 đến TASK-0.3, report/spec TASK-0.3, TASK-0.4 spec, report template và `CommandRunner.h/.m`. |
| Search toàn repo cho `CommandRunner` caller | PASS | Caller chỉ nằm trong ba file đã audit; không caller diff. |
| New selector search | PASS | Trước report, selector chỉ có declaration, implementation và TASK-0.4 docs; không có call site. |
| Public API count | PASS | Header thêm đúng một selector; implementation có đúng một method tương ứng. |
| Direct method shell isolation | PASS | Direct method body không chứa `/bin/sh`, `-c`, join hoặc shell quote. |
| Shared engine shell isolation | PASS | Engine nhận exact executable/argv; shell chỉ được chọn bởi hai shell wrappers. |
| Exact spawn | PASS | Một shared capture `posix_spawn` dùng `ownedArgv.items[0]` và `ownedArgv.items`. |
| No `posix_spawnp` | PASS | `CommandRunner.m` không chứa `posix_spawnp`. |
| No command join | PASS | Không có `componentsJoinedByString:` trong `CommandRunner.m`. |
| argv NULL terminator | PASS | Explicit `ownedArgv.items[pointerCount - 1] = NULL`. |
| Runner-created argv[0] | PASS | Executable is encoded/allocated into `items[0]`; caller arguments begin at `items[1]`. |
| Empty argument preservation | PASS | Zero-length data allocates one byte and writes only terminal NUL; slot vẫn tồn tại. |
| Embedded NUL rejection | PASS | Direct policy uses `memchr` over encoded byte range before allocation/spawn. |
| Non-string rejection | PASS | Path/item runtime type checked bằng `isKindOfClass:`; không dùng `description`. |
| Relative path rejection | PASS | Path phải non-empty và `hasPrefix:@"/"`. |
| Overflow checks | PASS | Count+2, pointer byte size và string length+1 đều được guard. |
| Partial allocation cleanup | PASS | `calloc` zero-init cùng `PXDestroyOwnedArgv` cleanup mọi slot đã tạo. |
| Successful argv cleanup | PASS | Free ngay sau `posix_spawn` return, bất kể spawn success/failure. |
| Pre-spawn argv cleanup | PASS | Pipe/fcntl/attribute/action/timing/deadline early return đều destroy argv. |
| Direct process group | PASS | Direct options enable deadline/cap/process group và dùng shared TASK-0.3 path. |
| Shell policy | PASS | Legacy NO/NO/NO; bounded YES/YES/YES; cả hai env `NULL`. |
| Environment policy | PASS | Direct passes `environ`; shell and `run:` retain `NULL`. |
| Blocking wait audit | PASS | Blocking wait helper chỉ được `run:` gọi; shared/direct capture dùng WNOHANG. |
| Executable preflight audit | PASS | Shared launch engine không có `fileExistsAtPath`, `access` hoặc `stat`. |
| Caller diff | PASS | `git diff --exit-code -- AppDataCleaner.m AppDataBackupManager.m AppEntitlementsReader.m` trả `0`. |
| `git diff --check -- CommandRunner.h CommandRunner.m` | PASS | Exit code `0`. |
| Local Objective-C build/runtime | NOT RUN | Workspace Windows thiếu `clang`, Objective-C/iOS SDK và `make`. |
| GitHub Actions | PENDING | Workflow expected: `.github/workflows/build-ios-arm.yml`. |

### Scenario matrix

Runtime tests không chạy trong workspace vì không có iOS/Objective-C toolchain. Không scenario nào được tuyên bố runtime PASS.

| # | Scenario | Static review | Runtime | Evidence/expected mapping |
|---|---|---|---|---|
| 1 | Absolute executable, zero args, exit 0 | PASS | NOT RUN | argv layout `[path, NULL]`; actual exit 0 maps success. |
| 2 | Relative executable | PASS | NOT RUN | `hasPrefix:@"/"` false → `EINVAL`, no spawn. |
| 3 | Missing absolute executable | PASS | NOT RUN | Không preflight; exact `posix_spawn` error vào `spawnError`, thường ENOENT. |
| 4 | Empty executable path | PASS | NOT RUN | Length zero → `EINVAL`, no spawn. |
| 5 | nil arguments | PASS | NOT RUN | Non-NSArray validation → `EINVAL`, no spawn. |
| 6 | Non-string argument | PASS | NOT RUN | Per-item class check → `EINVAL`, partial argv cleanup. |
| 7 | Empty-string argument | PASS | NOT RUN | Một one-byte NUL buffer giữ nguyên argument slot. |
| 8 | Argument `a b` | PASS | NOT RUN | Một UTF-8 buffer/argv slot; không split. |
| 9 | Argument `$HOME` | PASS | NOT RUN | Literal bytes; không environment expansion. |
| 10 | Argument `*` | PASS | NOT RUN | Literal bytes; không glob expansion. |
| 11 | Argument `;` hoặc `&&` | PASS | NOT RUN | Literal argv item; không command thứ hai. |
| 12 | Unicode path/argument hợp lệ | PASS | NOT RUN | Lossless UTF-8 owned copy. |
| 13 | Embedded NUL trong path | PASS | NOT RUN | `memchr` → `EINVAL`, no spawn. |
| 14 | Embedded NUL trong argument | PASS | NOT RUN | `memchr` → `EINVAL`, partial cleanup. |
| 15 | timeoutSec invalid | PASS | NOT RUN | Existing finite/>0 validation → `EINVAL`, no argv/spawn. |
| 16 | maxOutputBytes zero | PASS | NOT RUN | Existing cap validation → `EINVAL`, no argv/spawn. |
| 17 | stdout vượt cap | PASS | NOT RUN | Existing per-stream retain cap, truncate flag và continued drain. |
| 18 | stderr vượt cap | PASS | NOT RUN | Independent stderr cap behavior giữ nguyên. |
| 19 | Direct executable vượt deadline | PASS | NOT RUN | Owned group TERM → drain grace → KILL → bounded reap; timedOut true. |
| 20 | Direct executable tạo descendant | PASS | NOT RUN | Descendant giữ inherited PGID được group-signal theo TASK-0.3. |
| 21 | Shell legacy có pipe/redirection | PASS | NOT RUN | `/bin/sh -c` wrapper giữ parsing behavior cũ. |
| 22 | Shell bounded timeout | PASS | NOT RUN | TASK-0.3 group cleanup path giữ nguyên. |
| 23 | Allocation fail/fault reasoning | PASS by source reasoning | NOT RUN | `ENOMEM`; zero-initialized partial argv cleanup. |
| 24 | Spawn attr/action failure reasoning | PASS by source reasoning | NOT RUN | Attributes/actions/FDs/argv cleanup; không spawn hoặc không orphan sau spawn. |

## 7. Diff Review

- Có thay đổi ngoài task không? **Không trong code.** Chỉ `CommandRunner.h`, `CommandRunner.m` và report bắt buộc.
- Có format-only churn không? **Không.** Diff tập trung vào selector, owned argv và shared launch refactor.
- Có generated/binary file thay đổi không? **Không.**
- Có API cũ bị xóa không? **Không.**
- Có caller migration không? **Không.**
- Có default timeout policy mới không? **Không.**
- Có custom environment/cwd/stdin/async/cancellation API không? **Không.**
- Có process-tree scanning không? **Không.**
- Có TASK-0.5 implementation không? **Không.**

`git diff --stat -- CommandRunner.h CommandRunner.m`:

```text
 CommandRunner.h |   4 ++
 CommandRunner.m | 196 +++++++++++++++++++++++++++++++++++++++++++++++++++-----
 2 files changed, 184 insertions(+), 16 deletions(-)
```

Các phần diff đáng chú ý:

- thêm bốn dòng declaration cho đúng một selector;
- thêm `PXOwnedArgv` và owned UTF-8 helpers;
- refactor command-specific capture engine thành executable/argv-aware engine;
- shell wrappers chuyển `/bin/sh`, `-c`, command dưới dạng arguments riêng;
- direct wrapper truyền exact path/args, `environ` và bounded group options;
- không thay capture loop, timeout constants, cap logic hoặc TASK-0.3 signal/reap helpers.

## 8. Safety Notes

- Task có thêm destructive behavior không? **Không cho caller hiện tại.** Direct API mới có bounded group termination khi một caller tương lai chủ động dùng deadline, nhưng TASK-0.4 không có call-site migration.
- Task có thay đổi path resolution không? **Direct API không resolve/canonicalize/preflight path; exact path được truyền cho `posix_spawn`.**
- Task có thay đổi Clear/Backup/Restore/Keychain behavior không? **Không.** Caller không đổi.
- Task có swallow error hoặc biến failure thành success không? **Không.** Validation/allocation/spawn/runner/child/timeout states được tách có cấu trúc.
- Direct API có shell injection surface không? **Không qua runner.** Arguments không được ghép hoặc diễn giải bởi shell.
- Có synthetic timeout exit code không? **Không.**

## 9. Not Changed

- Không sửa `AppDataCleaner.m`.
- Không sửa `AppDataBackupManager.m`.
- Không sửa `AppEntitlementsReader.m`.
- Không sửa bất kỳ caller nào.
- Không migrate tar create/extract.
- Không migrate ldid.
- Không migrate keychain helper.
- Không migrate chmod/chown/cp/mv/mkdir/rm.
- Không đổi `run:`.
- Không đổi `CommandResult` fields hoặc `succeeded` contract.
- Không áp deadline/cap/group cho legacy capture.
- Không đổi shell parsing semantics.
- Không dùng `posix_spawnp`.
- Không thêm PATH search.
- Không thêm file executable preflight.
- Không thêm custom environment dictionary.
- Không thêm custom cwd/stdin.
- Không thêm async/cancellation API.
- Không thêm process-tree scanning.
- Không sửa Clear, Backup, Restore, Keychain hoặc UI.
- Không thực hiện TASK-0.5.

## 10. Remaining Risks

- Chưa compile bằng Apple/Theos toolchain trong workspace; GitHub Actions phải xác nhận SDK declarations/linking cho `environ`, Foundation UTF-8 conversion và C allocation helpers.
- Runtime argv literal/empty/NUL/Unicode scenarios chưa chạy trên thiết bị; static review không thay thế runtime validation.
- Direct API kế thừa limitation TASK-0.3: process cố ý escape group/session có thể sống sau timeout.
- Objective-C collection mutation đồng thời trong lúc runner đọc arguments không thuộc contract; caller phải không mutate array concurrently.
- C allocation fault paths được review bằng source reasoning nhưng chưa fault-inject runtime.
- Existing callers vẫn xây shell command strings; migration và per-operation policy thuộc task riêng sau TASK-0.4.

## 11. GitHub Actions Handoff

```text
Build requested: YES
Workflow expected: .github/workflows/build-ios-arm.yml
Build result: PENDING
Build URL/run ID: PENDING
```

Agent dừng tại TASK-0.4. Suggested status: `READY_FOR_REVIEW`.
