# TASK-0.4 — Direct Executable and argv Capture API

## Metadata

- Phase: Phase 0 — Reliable Command Execution
- Status: READY
- Dependency: TASK-0.3 accepted and project-owner build gate completed
- Required report: `docs/backup-restore-hardening/reports/TASK-0.4-REPORT.md`
- Build gate: GitHub Actions by project owner
- Suggested commit: `phase0(task-0.4): add bounded direct executable argv API`

## Objective

Bổ sung một public API mới để chạy executable trực tiếp bằng `posix_spawn` và argv tách biệt, không đi qua `/bin/sh -c`, đồng thời tái sử dụng đầy đủ bounded capture engine đã hoàn thiện trong TASK-0.2/TASK-0.3.

API mới phải:

- nhận exact executable path;
- nhận arguments dưới dạng mảng, không ghép thành command string;
- không thực hiện shell parsing, quoting, expansion hoặc redirection;
- có total monotonic deadline;
- có per-stream output cap;
- tạo owned process group tại spawn time;
- timeout theo group `SIGTERM → SIGKILL → bounded reap`;
- giữ nguyên structured `CommandResult`;
- quản lý bộ nhớ argv có ownership rõ ràng;
- reject embedded NUL và invalid argument type trước khi spawn;
- không migrate bất kỳ caller nào trong task này.

TASK-0.4 là task xây contract và shared launch infrastructure. Việc chuyển các thao tác `tar`, `ldid`, keychain helper, `chmod`, `chown`, `cp`, `mv` hoặc destructive operations sang API mới thuộc các task migration riêng sau này.

## Required reading

Agent bắt buộc đọc:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-0.1-REVIEW.md`
5. `docs/backup-restore-hardening/reviews/TASK-0.2-REVIEW.md`
6. `docs/backup-restore-hardening/reviews/TASK-0.3-REVIEW.md`
7. `docs/backup-restore-hardening/reports/TASK-0.3-REPORT.md`
8. `docs/backup-restore-hardening/tasks/TASK-0.3-spawn-process-group-termination.md`
9. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
10. `CommandRunner.h`
11. `CommandRunner.m`
12. Tất cả caller của `CommandRunner`
13. Các implementation `posix_spawn` hiện có trong repo chỉ để audit, không sửa.

## Allowed files

Chỉ được sửa code:

- `CommandRunner.h`
- `CommandRunner.m`

Sau đó tạo report:

- `docs/backup-restore-hardening/reports/TASK-0.4-REPORT.md`

Không sửa caller hoặc file nghiệp vụ.

Nếu implementation yêu cầu sửa file khác để compile, không tự mở rộng scope. Ghi bằng chứng trong report và dừng để coordinator review.

## Current source facts

Sau TASK-0.3:

- `run:` chạy `/bin/sh -c` và blocking wait theo legacy behavior.
- `runAndCapture:` legacy chạy `/bin/sh -c`, không deadline, không cap, không process group mới.
- `runAndCapture:timeoutSec:maxOutputBytes:` chạy `/bin/sh -c`, có deadline/cap/process group.
- Bounded capture engine hiện tự dựng:

```c
const char *argv[] = {"/bin/sh", "-c", commandUTF8, NULL};
```

- Capture, deadline, output cap, spawn attributes, group termination và result mapping đã nằm trong shared internal engine.
- Chưa có public direct-executable API.
- Caller hiện vẫn xây shell command string.
- Repo đã có `extern char **environ;` trong một số module, nhưng `CommandRunner` shell APIs hiện truyền environment pointer theo behavior hiện tại của chúng.

## Public API to add

Thêm đúng một public method vào `CommandRunner.h`:

```objc
- (CommandResult *)runExecutableAndCapture:(NSString *)executablePath
                                 arguments:(NSArray<NSString *> *)arguments
                                timeoutSec:(NSTimeInterval)timeoutSec
                            maxOutputBytes:(NSUInteger)maxOutputBytes;
```

### Public contract

- `executablePath` là exact path của executable.
- `executablePath` bắt buộc là absolute path.
- `arguments` chứa `argv[1...]`.
- Caller không truyền `argv[0]`.
- Runner tự đặt `argv[0] = executablePath`.
- `arguments` được phép là mảng rỗng.
- Empty-string argument được phép và phải được giữ nguyên.
- API luôn capture stdout/stderr.
- API luôn yêu cầu deadline và output cap hợp lệ.
- API luôn bật spawn-time process group và group-scoped timeout cleanup.
- API không hỗ trợ custom environment, custom cwd, custom stdin hoặc asynchronous execution trong task này.

Không thêm convenience overload unbounded cho direct executable.

## Direct execution semantics

API mới phải gọi exact executable bằng:

```c
posix_spawn(... executablePath ..., argv, ...);
```

Không được dùng:

- `/bin/sh -c`;
- `system()`;
- `popen()`;
- `NSTask`;
- `posix_spawnp()`;
- PATH search;
- command-string concatenation;
- shell quote helper;
- `componentsJoinedByString:` để tạo command line;
- automatic wildcard expansion;
- environment-variable expansion;
- pipe/redirection parsing;
- automatic insertion của `--`.

Các argument như sau phải tới child dưới dạng literal argument riêng:

```text
a b
$HOME
*
;
&&
|
>
'quoted'
"quoted"
```

Runner không được tự diễn giải các ký tự trên.

## Validation contract

Validation phải xảy ra trước pipe creation/spawn nếu có thể và chắc chắn trước `posix_spawn`.

### executablePath

Reject với `runnerError = EINVAL`, không spawn, khi:

- nil;
- không phải `NSString` ở runtime;
- empty;
- không bắt đầu bằng `/`;
- không encode lossless sang UTF-8;
- chứa embedded NUL byte.

Không preflight bằng `fileExistsAtPath:`, `access(X_OK)` hoặc `stat` để quyết định thành công. Exact spawn result là authority cho executable-not-found, permission và format errors.

Không canonicalize, standardize hoặc resolve symlink trong `CommandRunner`.

### arguments

Reject với `runnerError = EINVAL`, không spawn, khi:

- array nil;
- object không phải `NSArray` ở runtime;
- bất kỳ item nào không phải `NSString`;
- bất kỳ string nào không encode lossless sang UTF-8;
- bất kỳ encoded argument nào chứa embedded NUL.

Cho phép:

- zero arguments;
- empty-string argument;
- Unicode argument;
- whitespace/newline/shell metacharacter trong argument.

Không gọi `description` để ép object không phải string thành argument.

### deadline/output cap

Giữ validation từ TASK-0.2:

- `timeoutSec` finite và `> 0`;
- `maxOutputBytes > 0`;
- validation failure dùng `runnerError = EINVAL`;
- không spawn child;
- không đặt `timedOut` chỉ vì input invalid.

## Owned argv construction

Không giữ một `char **argv` trỏ vào buffer tạm không có ownership rõ ràng.

Khuyến nghị internal type:

```c
typedef struct {
    char **items;
    size_t count;
} PXOwnedArgv;
```

Hoặc thiết kế tương đương với cùng ownership contract.

### Required layout

Với `N = arguments.count`:

```text
argv[0]     = owned UTF-8 copy of executablePath
argv[1]     = owned UTF-8 copy of arguments[0]
...
argv[N]     = owned UTF-8 copy of arguments[N - 1]
argv[N + 1] = NULL
```

### Allocation requirements

- Kiểm tra integer overflow khi tính `N + 2` và byte size của pointer array.
- Dùng zero-initialized pointer array hoặc initialization rõ ràng để partial cleanup an toàn.
- Mỗi string buffer phải có `length + 1` với overflow check.
- Copy exact UTF-8 bytes rồi thêm một terminal NUL duy nhất.
- Embedded NUL trong encoded data phải bị reject trước copy/spawn.
- Empty string phải trở thành buffer một byte chứa `\0`.
- Allocation failure dùng `runnerError = ENOMEM`.
- Nếu fail giữa quá trình build argv, free toàn bộ buffer đã tạo và pointer array.
- Mọi successful argv build phải được destroy đúng một lần sau `posix_spawn` return hoặc trên pre-spawn error path.
- Không leak argv trong setup failure, deadline-before-spawn, spawn failure hoặc spawn success.

Agent phải ghi rõ trong report cách kiểm tra overflow, embedded NUL và partial allocation cleanup.

## Internal launch refactor

Không duplicate toàn bộ bounded capture engine cho direct API.

Refactor shared capture engine để nhận launch target đã tách:

```text
executable path
arguments array / owned argv
environment policy
capture options
```

Một cấu trúc hợp lệ có thể là:

```objc
static CommandResult *PXRunCaptureExecutable(NSString *executablePath,
                                             NSArray<NSString *> *arguments,
                                             char *const environment[],
                                             PXCaptureOptions options);
```

Tên và cấu trúc có thể khác, nhưng phải đạt:

- chỉ một implementation cho pipe/capture/deadline/cap/process-group/termination;
- shell capture wrappers chỉ chuyển thành launch request `/bin/sh`, arguments `-c`, command;
- direct API chuyển exact executable và exact arguments;
- không có hai capture loop độc lập;
- không có hai process-group cleanup implementation độc lập.

## Shell wrapper compatibility

Sau refactor:

### Legacy shell capture

```objc
- (CommandResult *)runAndCapture:(NSString *)command;
```

phải tương đương:

```text
executable: /bin/sh
arguments:  -c, command
deadline:   disabled
cap:        disabled
pgroup:     disabled
```

### Bounded shell capture

```objc
- (CommandResult *)runAndCapture:(NSString *)command
                     timeoutSec:(NSTimeInterval)timeoutSec
                 maxOutputBytes:(NSUInteger)maxOutputBytes;
```

phải tương đương:

```text
executable: /bin/sh
arguments:  -c, command
deadline:   enabled
cap:        enabled
pgroup:     enabled
```

### Direct bounded capture

```objc
runExecutableAndCapture:arguments:timeoutSec:maxOutputBytes:
```

phải tương đương:

```text
executable: exact executablePath
arguments:  exact separate arguments
deadline:   enabled
cap:        enabled
pgroup:     enabled
shell:      none
```

### `run:`

`run:` có thể giữ implementation riêng trong task này. Không bắt buộc refactor `run:` sang generic engine nếu việc đó tăng scope hoặc thay đổi legacy behavior.

## Environment policy

TASK-0.4 không thêm public custom-environment API.

Policy phải rõ ràng trong source và report:

- direct executable API truyền current process environment bằng `environ`;
- thêm `extern char **environ;` trong `CommandRunner.m` nếu cần;
- shell APIs hiện hữu giữ nguyên environment-pointer behavior trước task này để tránh compatibility change ngoài phạm vi;
- không mutate environment;
- không xây environment từ `NSProcessInfo`;
- không thêm PATH lookup.

Nếu agent chứng minh target SDK/toolchain không hỗ trợ cách trên, không tự thay policy. Ghi build issue và dừng review.

## Process-group and timeout contract

Direct API phải dùng toàn bộ TASK-0.3 behavior:

- `processGroupEnabled = YES`;
- `POSIX_SPAWN_SETPGROUP`;
- pgroup `0`;
- PGID bằng returned child PID sau spawn success;
- ownership validation trước negative-PGID signal;
- deadline dùng monotonic time;
- group `SIGTERM`;
- bounded drain grace;
- final group `SIGKILL` trước leader reap;
- bounded `WNOHANG` reap;
- final nonblocking drain/close;
- escaped descendant limitation giữ nguyên.

Không được tạo một direct-executable path chỉ kill PID mà bỏ qua process group.

## Output and result contract

Giữ nguyên toàn bộ `CommandResult` semantics:

- `spawnError` chỉ chứa `posix_spawn` return code;
- `runnerError` chứa validation/setup/allocation/read/select/clock/signal/reap error;
- `timedOut` là dedicated deadline state;
- không dùng synthetic exit code;
- `exitCode` giữ actual child normal exit;
- `terminationSignal` giữ actual child signal termination;
- `exitedNormally` đúng wait status;
- `duration` dùng monotonic clock;
- stdout/stderr cap riêng;
- tiếp tục drain/discard sau cap;
- partial output được giữ;
- UTF-8 boundary strategy từ TASK-0.2 được giữ;
- `succeeded` contract không đổi.

## Error precedence

Giữ policy hiện tại:

1. Input validation và argv-construction failure: `runnerError`, không spawn.
2. `posix_spawn` failure: `spawnError`.
3. Child non-zero exit: không phải runner error.
4. Deadline: `timedOut`, không tự tạo runner error.
5. Cleanup/reap failure: structured `runnerError` theo existing precedence.
6. Allocation error: `ENOMEM`.
7. Embedded NUL/invalid type/relative path: `EINVAL`.

Nếu spawn action hoặc spawn attribute destroy lỗi sau child đã spawn, runner vẫn phải tiếp tục capture/cleanup; không return sớm để orphan command.

## Resource lifecycle audit

Agent phải audit và report ownership của:

- owned executable UTF-8 buffer;
- từng owned argument buffer;
- argv pointer array;
- stdout pipe ends;
- stderr pipe ends;
- spawn file actions;
- spawn attributes;
- child PID/state;
- process-group state;
- output data buffers.

Mỗi resource phải có:

- điểm acquire;
- ownership flag/state nếu cần;
- cleanup trên mọi early return;
- cleanup sau spawn success;
- không double free/destroy/close.

## Compatibility requirements

- Giữ nguyên toàn bộ public API cũ.
- Không sửa `CommandResult` fields hoặc `succeeded` contract.
- Không sửa caller.
- Không áp direct API ngầm cho shell APIs.
- Không thay shell parsing behavior của API cũ.
- Không áp deadline/cap/group cho `runAndCapture:` legacy.
- Không đổi `run:`.
- Không đổi timeout constants nếu không có compile reason bắt buộc.
- Không đổi UI hoặc nghiệp vụ.

## Explicitly out of scope

Không thực hiện trong TASK-0.4:

- migrate `AppDataCleaner`;
- migrate `AppDataBackupManager`;
- migrate `AppEntitlementsReader`;
- migrate tar create/extract;
- migrate keychain helper;
- migrate ldid;
- migrate chmod/chown/cp/mv/mkdir/rm;
- custom environment dictionary;
- custom cwd;
- stdin redirection policy;
- asynchronous API;
- cancellation token;
- shell pipeline builder;
- PATH search hoặc `posix_spawnp`;
- file existence/executable preflight;
- process-tree enumeration;
- task Phase 1;
- TASK-0.5.

## Required verification

Agent phải thực hiện static/source verification tối thiểu:

1. Search toàn repo cho `CommandRunner` caller; xác nhận không caller nào đổi.
2. Search selector mới; chỉ header, implementation, docs/report được phép xuất hiện.
3. Xác nhận direct implementation không chứa `/bin/sh`, `-c`, command concatenation hoặc shell quote.
4. Xác nhận shell wrappers vẫn dùng `/bin/sh`, `-c` dưới dạng arguments riêng.
5. Xác nhận direct API dùng `posix_spawn`, không dùng `posix_spawnp`.
6. Xác nhận arguments không được join thành string.
7. Xác nhận argv cuối có NULL terminator.
8. Xác nhận `argv[0]` do runner tạo từ executablePath.
9. Xác nhận empty argument không bị bỏ.
10. Xác nhận embedded NUL bị reject.
11. Xác nhận non-string argument bị reject.
12. Xác nhận relative executable path bị reject.
13. Xác nhận allocation overflow được kiểm tra.
14. Xác nhận partial argv allocation được cleanup.
15. Xác nhận owned argv được free sau spawn success/failure.
16. Xác nhận bounded direct API bật process group.
17. Xác nhận legacy shell capture không bật process group/deadline/cap ngoài policy cũ.
18. Xác nhận direct API truyền `environ` và shell APIs giữ existing environment-pointer behavior.
19. Xác nhận không có blocking wait vô hạn trong direct API.
20. Chạy `git diff --check`.
21. Review full diff và diff stat.

## Required scenario matrix

Agent phải đưa bảng static/runtime status cho ít nhất các scenario:

| # | Scenario | Expected result |
|---|---|---|
| 1 | Absolute executable, zero args, exit 0 | Spawn trực tiếp; success nếu child exit 0. |
| 2 | Relative executable | `runnerError = EINVAL`, no spawn. |
| 3 | Missing absolute executable | `spawnError = ENOENT` hoặc exact spawn error. |
| 4 | Empty executable path | `runnerError = EINVAL`, no spawn. |
| 5 | nil arguments | `runnerError = EINVAL`, no spawn. |
| 6 | Non-string argument | `runnerError = EINVAL`, no spawn. |
| 7 | Empty-string argument | Child nhận một argument rỗng. |
| 8 | Argument `a b` | Child nhận một argument, không tách. |
| 9 | Argument `$HOME` | Child nhận literal `$HOME`. |
| 10 | Argument `*` | Child nhận literal `*`. |
| 11 | Argument `;` hoặc `&&` | Child nhận literal, không chạy command thứ hai. |
| 12 | Unicode path/argument hợp lệ | Lossless UTF-8; spawn/result theo executable. |
| 13 | Embedded NUL trong path | `EINVAL`, no spawn. |
| 14 | Embedded NUL trong argument | `EINVAL`, no spawn. |
| 15 | timeoutSec invalid | `EINVAL`, no spawn. |
| 16 | maxOutputBytes zero | `EINVAL`, no spawn. |
| 17 | stdout vượt cap | Retain bounded, truncate flag true, tiếp tục drain. |
| 18 | stderr vượt cap | Independent bounded behavior. |
| 19 | Direct executable vượt deadline | Group TERM/KILL, bounded return, `timedOut = YES`. |
| 20 | Direct executable tạo descendant | Descendant trong group bị signal theo TASK-0.3. |
| 21 | Shell legacy command có pipe/redirection | Behavior cũ vẫn do `/bin/sh -c` xử lý. |
| 22 | Shell bounded command timeout | Behavior TASK-0.3 giữ nguyên. |
| 23 | Allocation fail/fault reasoning | Partial owned argv cleanup, `ENOMEM`. |
| 24 | Spawn attr/action failure reasoning | Full cleanup, no leak/orphan. |

Runtime test chỉ chạy khi môi trường an toàn và có cleanup chắc chắn. Nếu không chạy được, ghi `NOT RUN` thay vì tuyên bố PASS runtime.

## Acceptance criteria

Agent phải sao chép checklist này vào report:

- [ ] Thêm đúng một public direct-executable bounded capture API.
- [ ] API nhận absolute executable path và arguments array.
- [ ] Arguments được hiểu là `argv[1...]`.
- [ ] Runner tự đặt `argv[0]`.
- [ ] Empty argument được giữ.
- [ ] Không dùng shell cho direct API.
- [ ] Không dùng `posix_spawnp` hoặc PATH lookup.
- [ ] Không join arguments thành command string.
- [ ] Reject relative/empty/invalid executable path.
- [ ] Reject non-string argument.
- [ ] Reject embedded NUL trong path/argument.
- [ ] Có owned UTF-8 argv với NULL terminator.
- [ ] Có overflow và allocation failure handling.
- [ ] Partial argv allocation cleanup đầy đủ.
- [ ] Owned argv cleanup đúng mọi path.
- [ ] Shared capture engine được tái sử dụng; không duplicate capture loop.
- [ ] Direct API có deadline/cap/process group.
- [ ] Direct API dùng environment policy đã chốt.
- [ ] Shell API cũ giữ behavior.
- [ ] `run:` giữ behavior.
- [ ] Structured result semantics không đổi.
- [ ] Không sửa caller.
- [ ] Không sửa Clear/Backup/Restore/Keychain/UI.
- [ ] Không triển khai TASK-0.5.
- [ ] `git diff --check` pass.
- [ ] Tạo `TASK-0.4-REPORT.md` đúng template.
- [ ] GitHub Actions ghi PENDING trong agent report.
- [ ] Agent dừng sau TASK-0.4.

## Required report details

Ngoài template chung, report bắt buộc nêu:

- exact public selector;
- caller-supplied argument semantics;
- exact validation rules;
- direct vs shell launch path;
- shared engine refactor;
- owned argv type/layout;
- overflow checks;
- UTF-8 encoding strategy;
- embedded NUL detection;
- allocation cleanup strategy;
- environment pointer policy;
- process-group policy;
- result/error mapping;
- resource ownership table;
- caller audit;
- scenario matrix;
- file ngoài scope có thay đổi không;
- GitHub Actions là `PENDING`.

## Agent handoff prompt

```text
Thực hiện duy nhất TASK-0.4 theo file:
docs/backup-restore-hardening/tasks/TASK-0.4-direct-executable-argv-api.md

Bắt buộc đọc README, STATUS, DECISIONS, review TASK-0.1 đến TASK-0.3, report TASK-0.3 và report template trước khi sửa code.

Chỉ sửa:
- CommandRunner.h
- CommandRunner.m

Sau đó tạo:
docs/backup-restore-hardening/reports/TASK-0.4-REPORT.md

Thêm đúng một public API:
runExecutableAndCapture:arguments:timeoutSec:maxOutputBytes:

API mới phải:
- yêu cầu absolute executable path;
- nhận arguments là argv[1...];
- tự tạo argv[0];
- không qua shell;
- không join/quote/parse arguments;
- dùng owned UTF-8 argv;
- reject embedded NUL và non-string argument;
- có overflow/ENOMEM/partial-cleanup handling;
- dùng total deadline, per-stream cap và spawn-time process group hiện có;
- truyền current environment cho direct API bằng environ;
- tái sử dụng một shared capture engine;
- giữ nguyên shell APIs và run:;
- không sửa caller;
- không migrate nghiệp vụ;
- không thực hiện TASK-0.5.

Sau khi hoàn thành:
1. Audit full resource lifecycle.
2. Audit selector/caller/source searches.
3. Chạy git diff --check.
4. Điền đủ acceptance checklist và scenario matrix.
5. Ghi GitHub Actions là PENDING.
6. Đề xuất READY_FOR_REVIEW.
7. Dừng lại.
```

## Gate to TASK-0.5

TASK-0.5 chỉ được mở khi:

- report TASK-0.4 đầy đủ;
- GitHub Actions build thành công;
- direct API không qua shell;
- argv ownership/cleanup được review chấp nhận;
- shell APIs không regression;
- không caller migration ngoài scope;
- coordinator tạo review ACCEPTED.
