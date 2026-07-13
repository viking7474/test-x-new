# TASK-0.3 Agent Report

## Metadata

```text
Task ID: TASK-0.3
Task title: Spawn-Time Process Group and Group-Scoped Termination
Task specification: docs/backup-restore-hardening/tasks/TASK-0.3-spawn-process-group-termination.md
Agent: GPT-5.6 Thinking
Started at: 2026-07-13 (Asia/Ho_Chi_Minh)
Finished at: 2026-07-13 (Asia/Ho_Chi_Minh)
Suggested status: READY_FOR_REVIEW
Commit hash: chưa commit
```

## 1. Summary

Đã nâng internal bounded capture path từ direct-child termination sang owned process-group termination mà không thay đổi public API hoặc caller.

Chỉ overload bounded:

```objc
- (CommandResult *)runAndCapture:(NSString *)command
                     timeoutSec:(NSTimeInterval)timeoutSec
                 maxOutputBytes:(NSUInteger)maxOutputBytes;
```

bật process-group policy. Process group được tạo atomically trong `posix_spawn` bằng `POSIX_SPAWN_SETPGROUP` và pgroup `0`. Khi timeout hoặc timing subsystem thất bại sau spawn, cleanup dùng thứ tự:

```text
owned group SIGTERM
→ bounded grace chỉ drain output, không reap leader
→ final owned group SIGKILL
→ bounded WNOHANG direct-child reap
→ final nonblocking drain và đóng pipes
```

`run:` và `runAndCapture:` legacy vẫn không tạo process group mới. Không sửa `CommandRunner.h`, caller, Clear, Backup, Restore, Keychain hoặc UI. Không triển khai TASK-0.4.

## 2. Files Changed

| File | Change | Why required |
|---|---|---|
| `CommandRunner.m` | Thêm internal process-group option/state, spawn attributes, owned group signaling, defer-reap policy và group-aware timeout cleanup. | Triển khai behavior bắt buộc của TASK-0.3 mà không đổi public API. |
| `docs/backup-restore-hardening/reports/TASK-0.3-REPORT.md` | Tạo agent report. | Report bắt buộc của task. |

Không sửa `CommandRunner.h` hoặc file code nào khác.

Các thay đổi coordinator trong `README.md`, `ROADMAP.md`, `STATUS.md`, `DECISIONS.md`, TASK-0.2 review và TASK-0.3 specification đã tồn tại trong working tree trước khi triển khai. Agent không sửa các file đó.

## 3. Contract Changes

### Public contract

Không thêm, xóa hoặc thay đổi public method/property. `CommandRunner.h` không có diff.

Các API giữ nguyên:

```objc
- (CommandResult *)run:(NSString *)command;
- (CommandResult *)runAndCapture:(NSString *)command;
- (CommandResult *)runAndCapture:(NSString *)command
                     timeoutSec:(NSTimeInterval)timeoutSec
                 maxOutputBytes:(NSUInteger)maxOutputBytes;
```

Toàn bộ `CommandResult` semantics từ TASK-0.1/TASK-0.2 được giữ nguyên:

- timeout dùng `timedOut`;
- không dùng synthetic exit code;
- actual direct-child normal/signal status vẫn map vào `exitCode`, `terminationSignal`, `exitedNormally`;
- partial stdout/stderr, per-stream cap, truncation flags, UTF-8 conversion và duration được giữ.

### Internal option được thêm

`PXCaptureOptions` có thêm:

```c
BOOL processGroupEnabled;
```

Policy được đặt rõ ràng tại entry point:

```text
run:                                      không dùng shared capture group option; spawn attrs NULL
runAndCapture: legacy                     processGroupEnabled = NO
runAndCapture:timeoutSec:maxOutputBytes:  processGroupEnabled = YES
```

Không suy luận process-group policy từ output cap.

### Internal ownership state được thêm

```c
typedef struct {
    BOOL enabled;
    BOOL configured;
    pid_t childPID;
    pid_t processGroupID;
    int lastGroupSignal;
    BOOL finalGroupSignalSent;
} PXProcessGroupState;
```

State không được public hóa qua `CommandResult`.

## 4. Implementation Notes

### Exact spawn attribute calls

Bounded path thực hiện đúng các call:

```c
posix_spawnattr_init(&attributes);
posix_spawnattr_setflags(&attributes, POSIX_SPAWN_SETPGROUP);
posix_spawnattr_setpgroup(&attributes, 0);
```

Sau đó truyền attributes vào capture-engine `posix_spawn`:

```c
const posix_spawnattr_t *spawnAttributes = attributesInitialized
    ? &attributes
    : NULL;

posix_spawn(&pid,
            argv[0],
            &actions,
            spawnAttributes,
            (char *const *)argv,
            NULL);
```

Legacy capture có `attributesInitialized = NO`, nên truyền `NULL`. `run:` tiếp tục gọi `posix_spawn` trực tiếp với attributes `NULL` như trước.

Không có `setpgid` trong `CommandRunner.m` hoặc diff TASK-0.3. Repo đã có một `setpgid` cũ, ngoài phạm vi, trong `AppDataCleaner.m`; file đó không bị sửa.

### Spawn attribute error mapping

Return value của toàn bộ operation được kiểm tra:

- `posix_spawnattr_init`;
- `posix_spawnattr_setflags`;
- `posix_spawnattr_setpgroup`;
- `posix_spawnattr_destroy`.

Nếu init/setflags/setpgroup thất bại:

- đặt `runnerError` bằng status trả về;
- không spawn child;
- destroy attributes nếu init đã thành công;
- đóng toàn bộ pipe ends;
- return qua duration finalizer.

Nếu destroy thất bại sau spawn success, lỗi được ghi theo first-error precedence nhưng runner vẫn tiếp tục quản lý capture, timeout cleanup và child reap; không return sớm để orphan child.

### Attribute lifecycle

`attributesInitialized` là ownership flag. Helper:

```c
PXDestroySpawnAttributes(...)
```

chỉ destroy khi flag đang `YES`, sau đó luôn đặt flag về `NO`, kể cả khi destroy trả lỗi. Vì vậy một initialized attribute object được destroy đúng một lần trên các path:

- attribute setup failure;
- file-action setup failure;
- pre-spawn monotonic clock failure;
- pre-spawn deadline expiration;
- `posix_spawn` failure;
- `posix_spawn` success.

Không destroy object chưa init và không double-destroy.

### processGroupID establishment

`PXProcessGroupState` ban đầu có `configured = NO`, child/PGID `-1`.

Chỉ sau `posix_spawn` success:

```text
childPID = returned pid
processGroupID = returned pid
configured = YES, chỉ khi processGroupEnabled và pid > 1
```

Điều này phản ánh semantics của `POSIX_SPAWN_SETPGROUP` với pgroup `0`: child là group leader và PGID bằng child PID.

### Group signal validation

Trước mỗi group signal, helper xác nhận:

```text
enabled == YES
configured == YES
processGroupID > 1
childPID == spawned child PID
processGroupID == spawned child PID
processGroupID != getpgrp()
direct child chưa được reap
finalGroupSignalSent == NO
```

Chỉ sau các guard mới gọi:

```c
kill(-groupState->processGroupID, signalNumber);
```

Do PGID phải lớn hơn `1` và khác current runner group, code không thể phát:

```text
kill(0, signal)
kill(-1, signal)
kill(-getpgrp(), signal)
```

### SIGTERM/SIGKILL order

Group-enabled termination path có exact source order:

1. `result.timedOut = YES` nếu user deadline đã được xác nhận hết;
2. validate owned process group;
3. `kill(-processGroupID, SIGTERM)`;
4. `PXRunBoundedDrainPhase(PXTerminationGraceSec, ...)`;
5. `kill(-processGroupID, SIGKILL)` và đánh dấu final group signal;
6. `PXRunBoundedReapPhase(PXKillReapGraceSec, ...)`;
7. final drain/close.

Constants từ TASK-0.2 được giữ nguyên:

```text
poll quantum: 50 ms
SIGTERM grace: 350 ms
post-SIGKILL bounded reap grace: 750 ms
per-stream drain budget per cycle: 64 KiB
```

### Defer leader reap

Main capture loop tính:

```text
capturePipeOpen = stdout open OR stderr open
mayReapDirectChild = process group disabled OR no capture pipe open
```

Vì vậy trong bounded/group-enabled path:

- stdout hoặc stderr còn mở: không gọi `waitpid` cho direct child;
- cả hai pipe đóng: được poll/reap normal bằng `waitpid(..., WNOHANG)`;
- nếu drain làm cả hai pipe chuyển từ open sang closed trong cùng iteration, loop poll child ngay trước khi kiểm tra deadline để tránh false timeout tại EOF boundary.

Legacy capture có `processGroupEnabled = NO`, nên giữ policy polling trước TASK-0.3.

### Vì sao final group signal phải trước leader reap

PGID bằng child PID. Nếu leader được reap trong lúc descendant còn giữ pipe, PID/PGID có thể được hệ thống tái sử dụng. Một group signal muộn tới `-oldPID` khi đó có thể tác động một process group không còn thuộc command.

Source mới giữ leader unreaped khi capture pipe còn mở. TERM grace cũng chỉ drain, hoàn toàn không gọi `waitpid`. Final group `SIGKILL` được phát khi leader ownership vẫn được giữ; chỉ sau đó direct child mới được poll/reap.

### Bounded reap behavior

Sau final group SIGKILL, `PXRunBoundedReapPhase`:

- dùng `waitpid(pid, ..., WNOHANG)`;
- tiếp tục drain output;
- dùng monotonic phase deadline;
- có bounded attempt fallback nếu monotonic clock trong phase bị lỗi;
- giữ actual child wait status qua `PXApplyWaitStatus`;
- không gọi blocking `waitpid(..., 0)`.

Nếu child chưa reap sau bounded window, giữ `timedOut` theo deadline state và đặt `runnerError = ETIMEDOUT` nếu chưa có lỗi runner có ý nghĩa hơn. Pipes sau đó được final-drain nonblocking và đóng.

Blocking `waitpid(..., 0)` duy nhất trong `CommandRunner.m` vẫn thuộc `run:` legacy.

### ESRCH behavior

Group signal hoặc emergency direct-PID signal trả `ESRCH` không tự động tạo `runnerError`. Process/group có thể vừa kết thúc hoặc leader có thể đang là zombie không nhận signal.

Group path vẫn tiếp tục đúng sequence, bao gồm final SIGKILL attempt và bounded reap. Signal error khác được ghi vào `runnerError`, nhưng cleanup không dừng sớm.

### Timing-failure cleanup

Nếu monotonic timing thất bại sau group-enabled child spawn:

- original timing error được giữ trong `runnerError`;
- `timedOut` vẫn `NO` nếu user deadline chưa được xác nhận hết;
- cleanup vẫn dùng group SIGTERM → bounded drain grace → group SIGKILL → bounded reap;
- final group signal vẫn xảy ra trước leader reap;
- không fallback sang blocking wait vô hạn.

Nếu timing lỗi xảy ra trong termination/reap phase, attempt count dựa trên poll quantum vẫn giới hạn thời gian return.

### Invalid ownership emergency path

Nếu owned-group invariant không hợp lệ, runner:

- đặt `runnerError = EINVAL` nếu chưa có lỗi trước;
- không phát negative-PGID signal;
- dùng bounded direct-child emergency cleanup bằng direct PID;
- emergency target phải lớn hơn `1` và không được bằng `getpid()`;
- final drain/close và return hữu hạn.

Emergency path có thể không terminate descendant vì ownership group không đủ tin cậy. Đây là lựa chọn safety để không signal một group không chắc chắn.

### Error precedence

- `spawnError` chỉ nhận `posix_spawn` failure.
- Attribute/setup/clock/read/select/signal errors dùng `runnerError`.
- Lỗi runner thông thường giữ lỗi đầu tiên bằng `PXSetRunnerErrorIfUnset`.
- Wait/reap state loss tiếp tục có thể override qua critical error mapping từ TASK-0.2.
- Deadline thành công về mặt runner chỉ dùng `timedOut`, không tự gán `ETIMEDOUT`.
- `ETIMEDOUT` chỉ dùng khi bounded termination/reap không thu được child status.
- Child non-zero exit không phải runner error.

### Escaped descendant limitation

Process group bao phủ shell, pipeline, background child và grandchildren còn giữ inherited PGID.

Không bảo đảm terminate process cố ý escape bằng:

- `setsid`;
- chuyển sang process group khác;
- daemonization/session change;
- external privileged process manager.

Không có process-tree scanning, `ps` parsing, private process API hoặc kill theo tên. Nếu escaped descendant giữ pipe, method vẫn return bounded sau post-KILL reap budget bằng final drain/close.

## 5. Acceptance Checklist

- [x] Chỉ sửa `CommandRunner.m` và tạo report.
- [x] Không đổi public API/header.
- [x] Bổ sung internal process-group option/state rõ ràng.
- [x] Chỉ bounded overload bật process group.
- [x] Legacy APIs giữ process-group policy cũ.
- [x] Dùng `POSIX_SPAWN_SETPGROUP` và pgroup `0` tại spawn time.
- [x] Không dùng `setpgid` sau spawn.
- [x] Mọi spawn attribute operation được check.
- [x] Attribute lifecycle cleanup đúng mọi path.
- [x] Owned PGID bằng spawned child PID và lớn hơn 1.
- [x] Có guard không signal parent/current process group.
- [x] Timeout gửi group SIGTERM.
- [x] Timeout gửi final group SIGKILL trước khi reap leader.
- [x] Không signal group sau khi leader đã reap.
- [x] Bounded/group-enabled loop defer direct-child reap khi pipe còn mở.
- [x] Pipes đóng thì normal reap vẫn hoạt động.
- [x] Post-KILL direct-child reap có giới hạn.
- [x] Partial output/cap/truncation behavior được giữ.
- [x] Timeout/result mapping giữ actual direct-child status.
- [x] `ESRCH` không tự động trở thành runner failure.
- [x] Signal/setup/reap error vẫn cleanup hữu hạn.
- [x] Không thêm synthetic exit code.
- [x] Không sửa caller.
- [x] Không sửa Clear/Backup/Restore/Keychain/UI.
- [x] Đã audit toàn bộ `posix_spawn`, `waitpid`, `kill` path.
- [x] `git diff --check` pass.
- [x] Tạo `TASK-0.3-REPORT.md` đúng template.
- [x] Ghi GitHub Actions là PENDING.
- [x] Dừng sau TASK-0.3.

## 6. Verification Performed

### Static/source checks

| Check/command | Result | Evidence/notes |
|---|---|---|
| Required reading | PASS | Đã đọc README, STATUS, DECISIONS, TASK-0.1/TASK-0.2 reviews, TASK-0.2 specification/report, report template và `CommandRunner.h/.m`. |
| Caller audit | PASS | `run:` được dùng trong `AppDataBackupManager.m`; legacy `runAndCapture:` được dùng trong `AppDataBackupManager.m`, `AppDataCleaner.m`, `AppEntitlementsReader.m`; bounded overload không có caller. |
| Header diff | PASS | `git diff --exit-code -- CommandRunner.h` trả `0`. |
| Caller diff | PASS | `git diff --exit-code -- AppDataCleaner.m AppDataBackupManager.m AppEntitlementsReader.m` trả `0`. |
| `POSIX_SPAWN_SETPGROUP` | PASS | Có đúng một bounded attribute setup. |
| `posix_spawnattr_init` | PASS | Return status được kiểm tra. |
| `posix_spawnattr_setflags` | PASS | Dùng `POSIX_SPAWN_SETPGROUP`, return status được kiểm tra. |
| `posix_spawnattr_setpgroup` | PASS | Dùng pgroup `0`, return status được kiểm tra. |
| `posix_spawnattr_destroy` | PASS | Chỉ gọi qua ownership helper; return status được kiểm tra. |
| Bounded spawn attrs | PASS | Capture `posix_spawn` nhận conditional attributes; bounded policy bảo đảm attributes initialized. |
| Legacy spawn attrs | PASS | Legacy capture truyền `NULL`; `run:` truyền `NULL`. |
| No new `setpgid` | PASS | `CommandRunner.m` và TASK-0.3 diff không chứa `setpgid`. Existing unrelated `AppDataCleaner.m` usage pre-exists and was not touched. |
| Group target | PASS | Exact call `kill(-groupState->processGroupID, signalNumber)`. |
| Unsafe kill targets | PASS | Không có `kill(0, ...)`, `kill(-1, ...)` hoặc `kill(-getpgrp(), ...)` trong `CommandRunner.m`. |
| Signal order | PASS | Source offset order: SIGTERM → bounded drain → SIGKILL → bounded reap. |
| Reap deferral | PASS | Group-enabled loop chỉ poll khi cả stdout/stderr đã đóng. |
| Blocking wait audit | PASS | Một blocking wait helper chỉ do `run:` gọi; capture path dùng WNOHANG. |
| Synthetic exit-code search | PASS | Không có assignment `exitCode = 124` hoặc `137`. |
| Structural source check | PASS | Braces cân bằng; spawn attribute operations mỗi loại xuất hiện đúng một implementation site. |
| `git diff --check -- CommandRunner.m` | PASS | Exit code `0`. |
| Local Objective-C build/runtime | NOT RUN | Workspace Windows thiếu `clang`, Objective-C/iOS SDK và `make`. |
| GitHub Actions | PENDING | Workflow expected: `.github/workflows/build-ios-arm.yml`. |

### Runtime/static scenario matrix

Không chạy runtime process-group scenarios trong workspace vì không có iOS/Objective-C toolchain và không có môi trường cleanup orphan an toàn.

| # | Scenario | Static review | Runtime | Evidence/notes |
|---|---|---|---|---|
| 1 | `echo ok` normal completion | PASS | NOT RUN | Pipes EOF cho phép normal WNOHANG reap và actual exit 0. |
| 2 | Child exit non-zero | PASS | NOT RUN | `PXApplyWaitStatus` giữ actual `WEXITSTATUS`. |
| 3 | Child chết bởi signal không do timeout | PASS | NOT RUN | Khi pipes đóng, normal poll giữ actual `WTERMSIG`. |
| 4 | `sleep` vượt deadline | PASS | NOT RUN | Deadline dẫn vào owned group TERM/KILL và bounded reap. |
| 5 | Pipeline vượt deadline | PASS | NOT RUN | Spawn-time group được inherited; negative PGID signals toàn group. |
| 6 | Background descendant giữ stdout/stderr sau shell exit | PASS | NOT RUN | Leader không reap khi pipe còn mở; deadline group cleanup giữ PGID ownership. |
| 7 | Descendant xử lý SIGTERM và thoát trong grace | PASS | NOT RUN | Grace chỉ drain; final KILL attempt xảy ra trước leader reap; actual leader status giữ khi reap. |
| 8 | Descendant bỏ qua SIGTERM | PASS | NOT RUN | Final group SIGKILL sau 350 ms, reap bounded 750 ms. |
| 9 | stdout vượt cap trong timeout | PASS | NOT RUN | Existing per-stream cap/drain-discard path được dùng trong grace/reap. |
| 10 | stderr vượt cap trong timeout | PASS | NOT RUN | Independent stderr cap/truncation path được giữ. |
| 11 | Shell exit sớm, descendant giữ pipe đến deadline | PASS | NOT RUN | Leader defer-reap; final group signal trước waitpid; actual leader status thu sau KILL attempt. |
| 12 | Group signal trả `ESRCH` | PASS | NOT RUN | Không set runnerError chỉ vì ESRCH; sequence vẫn tiếp tục. |
| 13 | Attribute setup failure | PASS by source/fault reasoning | NOT RUN | Không spawn; guarded destroy và full FD cleanup. |
| 14 | Timing failure sau spawn | PASS by source reasoning | NOT RUN | `timedOut` không bị giả; group TERM → grace → KILL → bounded reap. |
| 15 | Legacy `runAndCapture:` | PASS | NOT RUN | `processGroupEnabled = NO`, attrs `NULL`; legacy deadline/cap/group policy không đổi. |
| 16 | `run:` | PASS | NOT RUN | Separate spawn tiếp tục truyền attributes `NULL` và dùng legacy blocking wait. |

## 7. Diff Review

- Có thay đổi ngoài task không? **Không.** Code diff chỉ có `CommandRunner.m`; report là artifact bắt buộc.
- `CommandRunner.h` có đổi không? **Không.**
- Caller có đổi không? **Không.**
- Có format-only churn không? **Không.** Diff tập trung vào attributes, ownership, signaling và reap order.
- Có generated/binary file thay đổi không? **Không.**
- Có direct executable/argv API không? **Không.**
- Có process-tree scan/ps parsing/kill-by-name không? **Không.**
- Có asynchronous API không? **Không.**
- Có TASK-0.4 implementation không? **Không.**

`git diff --stat -- CommandRunner.m`:

```text
 CommandRunner.m | 516 ++++++++++++++++++++++++++++++++++++++++++++++++--------
 1 file changed, 443 insertions(+), 73 deletions(-)
```

Các phần diff đáng chú ý:

- thêm một internal option và ownership struct;
- thêm attribute destroy ownership helper;
- thêm safe negative-PGID validation/signal helper;
- tách pre-KILL drain phase khỏi post-KILL reap phase;
- giữ direct-PID cleanup chỉ làm emergency fallback khi group invariant không an toàn;
- thêm spawn-time attributes chỉ cho bounded path;
- defer direct child reap khi bounded capture pipes còn mở;
- không đổi public methods hoặc result fields.

## 8. Safety Notes

- Task có thêm destructive behavior không? **Bounded overload giờ terminate owned command group thay vì chỉ direct shell PID khi caller chủ động dùng deadline.** Không caller hiện tại dùng bounded overload.
- Có thay đổi path resolution không? **Không.**
- Có thay đổi Clear/Backup/Restore/Keychain/UI không? **Không.**
- Có signal current/parent process group không? **Không; PGID được validate khác `getpgrp()` và lớn hơn 1.**
- Có signal target từ command string hoặc uninitialized data không? **Không.** Target chỉ từ returned child PID sau successful spawn.
- Có swallow error hoặc biến failure thành success không? **Không.** Setup/signal/reap failures được ghi có cấu trúc và cleanup vẫn bounded.
- Có synthetic timeout exit code không? **Không.**
- Có group signal sau leader reap không? **Không trong owned group path.**

## 9. Not Changed

- Không sửa `CommandRunner.h`.
- Không sửa `AppDataCleaner.m`.
- Không sửa `AppDataBackupManager.m`.
- Không sửa `AppEntitlementsReader.m`.
- Không sửa bất kỳ caller nào.
- Không migrate caller sang bounded overload.
- Không áp deadline/cap/group policy mặc định cho legacy APIs.
- Không đổi `/bin/sh -c`.
- Không đổi output cap, truncation hoặc UTF-8 strategy.
- Không đổi timeout constants.
- Không thêm `setpgid` fallback.
- Không thêm `POSIX_SPAWN_SETSID_NP`.
- Không triển khai argv API.
- Không triển khai process-tree enumeration.
- Không thêm cancellation/asynchronous API.
- Không sửa Clear, Backup, Restore, Keychain hoặc UI.
- Không thực hiện TASK-0.4.

## 10. Remaining Risks

- GitHub Actions chưa chạy cho TASK-0.3; target SDK availability và declaration/link compatibility của spawn attributes vẫn cần build gate xác nhận.
- Runtime group/pipeline/background-descendant matrix chưa chạy trên thiết bị. Static review không thay thế runtime validation.
- Process cố ý escape group/session có thể sống sau timeout. Final pipe close vẫn bảo đảm bounded return nhưng không bảo đảm terminate escaped process.
- Nếu ownership invariant bất thường thất bại, emergency cleanup chỉ target direct PID để tránh signal nhầm group; descendant có thể còn sống.
- Nếu final group signal bị từ chối bởi lỗi khác `ESRCH`, runner ghi lỗi và tiếp tục bounded reap, nhưng không thể bảo đảm mọi descendant đã dừng.
- Nếu direct child không reap trong post-KILL budget, method return bounded với runner error; external cleanup có thể cần thiết.
- Repo có một implementation `setpgid` cũ trong `AppDataCleaner.m`; TASK-0.3 không sửa hoặc dựa vào code đó.

## 11. GitHub Actions Handoff

```text
Build requested: YES
Workflow expected: .github/workflows/build-ios-arm.yml
Build result: PENDING
Build URL/run ID: PENDING
```

Agent dừng tại TASK-0.3. Suggested status: `READY_FOR_REVIEW`.
