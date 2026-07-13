# TASK-0.3 — Spawn-Time Process Group and Group-Scoped Termination

## Metadata

- Phase: Phase 0 — Reliable Command Execution
- Status: READY
- Dependency: TASK-0.2 accepted and GitHub Actions passed
- Required report: `docs/backup-restore-hardening/reports/TASK-0.3-REPORT.md`
- Build gate: GitHub Actions by project owner
- Suggested commit: `phase0(task-0.3): terminate bounded commands by process group`

## Objective

Nâng overload bounded:

```objc
- (CommandResult *)runAndCapture:(NSString *)command
                     timeoutSec:(NSTimeInterval)timeoutSec
                 maxOutputBytes:(NSUInteger)maxOutputBytes;
```

 từ cơ chế terminate direct child PID sang cơ chế sở hữu và terminate toàn bộ process group được tạo riêng cho command.

Task phải bảo đảm:

- process group được thiết lập atomically ngay trong `posix_spawn`;
- `/bin/sh` là process-group leader;
- pipeline và background descendant thông thường của shell nằm trong cùng group;
- timeout signal group bằng `SIGTERM`, sau grace period dùng `SIGKILL`;
- không dùng `setpgid` sau spawn;
- không signal nhầm process group sau khi direct child PID/PGID có thể được tái sử dụng;
- direct child vẫn được reap có giới hạn;
- partial output và structured result từ TASK-0.2 được giữ nguyên;
- legacy APIs và caller hiện tại không đổi behavior.

## Safety boundary

Process-group policy chỉ áp dụng cho overload bounded có deadline.

Không áp dụng process-group creation cho:

```objc
- (CommandResult *)run:(NSString *)command;
- (CommandResult *)runAndCapture:(NSString *)command;
```

Lý do: thay đổi process group của API legacy có thể làm thay đổi signal/job-control semantics của caller hiện tại dù không có timeout. Việc migrate caller và policy mặc định thuộc task riêng.

## Required reading

Agent bắt buộc đọc:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-0.1-REVIEW.md`
5. `docs/backup-restore-hardening/reviews/TASK-0.2-REVIEW.md`
6. `docs/backup-restore-hardening/tasks/TASK-0.2-bounded-capture-deadline.md`
7. `docs/backup-restore-hardening/reports/TASK-0.2-REPORT.md`
8. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`
9. `CommandRunner.h`
10. `CommandRunner.m`
11. Tất cả call site của `run:`, `runAndCapture:` và overload bounded.

## Allowed files

Chỉ sửa code:

- `CommandRunner.m`

Sau đó tạo report:

- `docs/backup-restore-hardening/reports/TASK-0.3-REPORT.md`

Không cần thay đổi `CommandRunner.h` vì task này không thêm public API hoặc public result field.

Nếu agent cho rằng header hoặc caller bắt buộc phải đổi, không tự mở rộng phạm vi. Ghi lý do trong report/proposal và dừng để review.

## Current source facts

Sau TASK-0.2:

- `PXCaptureOptions` có deadline/cap policy.
- Legacy capture và bounded capture dùng chung `PXRunCaptureCommand`.
- Bounded timeout gọi direct-child termination:

```c
kill(pid, SIGTERM);
kill(pid, SIGKILL);
```

- Capture engine spawn `/bin/sh -c` mà không truyền `posix_spawnattr_t`.
- Direct child được poll/reap bằng `waitpid(pid, ..., WNOHANG)` trong main capture loop.
- Nếu shell exit nhưng descendant giữ stdout/stderr pipe, direct child có thể được reap trước deadline trong source hiện tại.
- Sau khi leader được reap, PID/PGID có thể về sau được tái sử dụng. Signal `kill(-pgid, ...)` sau thời điểm đó có nguy cơ signal nhầm một group không còn thuộc command ban đầu.

TASK-0.3 phải giải quyết đồng thời process-group ownership và thứ tự signal/reap.

## Required internal design

### 1. Capture option

Mở rộng internal capture options bằng một flag rõ nghĩa, ví dụ:

```c
BOOL processGroupEnabled;
```

Policy bắt buộc:

```text
run:                                      process group disabled
runAndCapture: legacy                     process group disabled
runAndCapture:timeoutSec:maxOutputBytes:  process group enabled
```

Không suy luận process-group policy ngầm từ output cap. Có thể liên kết với deadline internally, nhưng code/report phải thể hiện policy rõ ràng.

### 2. Internal process ownership state

Bổ sung internal state phù hợp, tối thiểu biểu diễn được:

```text
processGroupEnabled
processGroupConfigured
processGroupID
lastGroupSignal
finalGroupSignalSent
```

Tên struct/property do agent chọn. Không public hóa state này trong `CommandResult`.

Invariant:

```text
processGroupConfigured == YES
=> spawn thành công với POSIX_SPAWN_SETPGROUP
=> processGroupID == spawned child pid
=> processGroupID > 1
```

Không được tạo signal target từ dữ liệu chưa được initialize hoặc từ command string.

## Spawn-time process-group setup

### Required POSIX spawn attributes

Khi `processGroupEnabled == YES`, phải dùng:

```c
posix_spawnattr_t attributes;
posix_spawnattr_init(&attributes);
posix_spawnattr_setflags(&attributes, POSIX_SPAWN_SETPGROUP);
posix_spawnattr_setpgroup(&attributes, 0);
```

Sau đó truyền attributes vào `posix_spawn`.

Semantics bắt buộc:

- `pgroup = 0` yêu cầu spawned child trở thành leader của group có PGID bằng child PID.
- Sau spawn success, internal `processGroupID` được đặt bằng returned `pid`.
- Không dùng `setpgid(pid, pid)` sau spawn.
- Không dùng sleep/retry để vá race process group.
- Không dùng `POSIX_SPAWN_SETSID_NP` hoặc API private/non-portable khác.

Nếu target SDK không cung cấp `POSIX_SPAWN_SETPGROUP`, agent không được thêm fallback race-prone. Ghi build failure rõ ràng để coordinator quyết định.

### Attribute setup errors

Các lỗi từ:

```text
posix_spawnattr_init
posix_spawnattr_setflags
posix_spawnattr_setpgroup
posix_spawnattr_destroy
```

phải được kiểm tra.

Trước khi child spawn:

- setup failure đặt `runnerError`;
- không spawn child;
- cleanup pipe/file actions/attributes đã initialize;
- không signal gì.

Sau khi child spawn thành công:

- destroy failure được ghi vào `runnerError` theo existing error precedence;
- runner vẫn phải quản lý, terminate nếu cần và reap child;
- không return sớm làm orphan process.

### Attribute lifecycle

Mỗi initialized `posix_spawnattr_t` phải được destroy đúng một lần trên mọi path:

- file-action setup failure;
- pre-spawn deadline expiration;
- clock failure trước spawn;
- spawn failure;
- spawn success.

Không destroy object chưa init và không double-destroy.

## Signal target validation

Tạo helper nội bộ cho group signal. Trước mọi group signal phải kiểm tra:

```text
processGroupEnabled == YES
processGroupConfigured == YES
processGroupID > 1
processGroupID == spawned child pid
processGroupID != getpgrp()
final group signal chưa bị gửi nếu helper cấm lặp
```

Không bao giờ gọi:

```c
kill(0, signal)
kill(-1, signal)
kill(-getpgrp(), signal)
```

Group signal dùng:

```c
kill(-processGroupID, signal)
```

hoặc `killpg(processGroupID, signal)` nếu agent chứng minh semantics tương đương trên deployment target. Ưu tiên negative-PGID `kill` để contract rõ ràng.

Error mapping:

- return `0`: signal request accepted;
- `ESRCH`: không tự động là runner failure; group có thể vừa kết thúc;
- lỗi khác: ghi `runnerError`, nhưng vẫn tiếp tục cleanup/reap hữu hạn;
- không đổi `spawnError`;
- không tạo synthetic exit code.

## Critical ownership rule: signal before reaping leader

Đây là acceptance bắt buộc.

### Problem

PGID bằng direct child PID. Nếu direct child được reap trong khi descendant vẫn giữ pipe, PID/PGID có thể được tái sử dụng trước khi timeout handler gửi group signal. Khi đó `kill(-pgid, ...)` có thể tác động nhầm process group khác.

### Required behavior for bounded/group-enabled path

Khi stdout hoặc stderr pipe vẫn còn mở:

- không reap direct child trong normal capture loop;
- vẫn drain output và kiểm tra deadline;
- direct child có thể tạm thời ở zombie state cho đến khi pipes đóng hoặc timeout cleanup bắt đầu;
- việc giữ leader unreaped trong khoảng bounded này là chủ ý để giữ PID/PGID ownership đến final group signal.

Khi cả stdout và stderr đã EOF/đóng:

- có thể poll/reap direct child;
- nếu child vẫn chạy nhưng đã đóng pipes, tiếp tục poll theo deadline;
- nếu child reap thành công trước deadline, return theo normal result.

Policy defer-reap này chỉ bắt buộc cho group-enabled bounded path. Legacy path có thể giữ behavior hiện tại.

## Required timeout termination sequence

Khi deadline hết trong group-enabled path:

### Phase A — Mark timeout and validate ownership

1. Đặt `result.timedOut = YES`.
2. Xác nhận internal process-group invariant.
3. Không reap direct child trước group signaling.

Nếu invariant sai:

- đặt `runnerError = EINVAL` hoặc error phù hợp;
- nếu direct child chưa reap và PID vẫn thuộc child hiện tại, terminate direct PID như emergency cleanup có giới hạn;
- không group-kill target không chắc chắn;
- report phải nêu path này.

### Phase B — Group SIGTERM

1. Gửi `SIGTERM` tới `-processGroupID`.
2. Trong `PXTerminationGraceSec`:
   - tiếp tục drain stdout/stderr;
   - kiểm tra monotonic phase deadline;
   - không reap direct child nếu final group signal chưa được gửi;
   - không reset total timeout semantics.

### Phase C — Final group SIGKILL

Sau SIGTERM grace, gửi `SIGKILL` tới cùng process group trước khi direct child được reap.

Đây là final group signal.

Gửi SIGKILL ngay cả khi shell có thể đã exit trong grace period, vì leader chưa được reap nên PGID chưa được tái sử dụng. Signal lên zombie/no-longer-live group có thể trả `ESRCH` và không phải failure tự động.

Không gửi thêm group signal sau khi direct child đã được reap.

### Phase D — Bounded direct-child reap

Sau final group SIGKILL:

1. Poll/reap direct child bằng `waitpid(pid, ..., WNOHANG)`.
2. Tiếp tục drain output trong existing bounded reap window.
3. Giữ actual direct-child wait status:
   - normal exit;
   - signal exit;
   - exit trong TERM grace;
   - signal do KILL.
4. Nếu direct child không reap trong bounded window:
   - `timedOut` vẫn true;
   - đặt `runnerError = ETIMEDOUT` nếu chưa có lỗi critical phù hợp hơn;
   - đóng pipe và return bounded.

### Phase E — Final drain and close

- Drain nonblocking phần dữ liệu đang sẵn có.
- Giữ per-stream cap/truncation behavior.
- Đóng mọi read FD còn mở.
- Không chờ descendant tùy ý sau bounded reap window.

## Timing-failure cleanup

Nếu monotonic clock hoặc internal timing thất bại sau khi group-enabled child đã spawn:

- không đặt `timedOut` nếu user deadline chưa được xác định là hết;
- vẫn dùng cùng safe group termination order:
  `group SIGTERM → bounded grace → group SIGKILL → bounded direct-child reap`;
- final group signal phải xảy ra trước direct child reap;
- giữ original timing error trong `runnerError` theo precedence;
- không fallback sang blocking wait vô hạn.

## Result semantics

### Timeout with shell killed by signal

```text
timedOut = YES
terminationSignal = actual direct-child WTERMSIG
exitCode = -1
exitedNormally = NO
```

### Timeout where shell exited normally during TERM grace

```text
timedOut = YES
exitedNormally = YES
exitCode = actual WEXITSTATUS
terminationSignal = 0
```

### Shell exited before deadline, descendant held pipe, group killed at deadline

Direct child status phải được giữ nếu reap được:

```text
timedOut = YES
exitedNormally/exitCode/terminationSignal = actual direct-child status
```

Group-descendant status không được giả làm direct-child status.

### Group signal error

```text
timedOut = YES when deadline expired
runnerError = signal/ownership error when meaningful
child wait fields = actual status if available
```

### Success

`succeeded` contract không đổi. Timeout luôn làm `succeeded == NO`.

## Descendant scope

Process group bao phủ:

- shell;
- normal shell pipeline;
- background children không tự đổi group/session;
- grandchildren giữ nguyên inherited PGID.

Không đảm bảo terminate process cố ý escape bằng:

```text
setsid
setpgid sang group khác
daemonization thay session/group
external privileged process manager
```

Task không được triển khai process-tree scanning, `ps` parsing, private process APIs hoặc kill theo tên.

Nếu escaped descendant giữ pipe, API vẫn phải return bounded bằng final drain/close behavior từ TASK-0.2.

## Compatibility requirements

- Không thay public method declaration.
- Không thêm `CommandResult` field.
- Không sửa caller.
- Không migrate caller sang overload bounded.
- Không áp deadline/cap/group policy cho legacy APIs.
- Không đổi `/bin/sh -c`.
- Không thay child exit-code semantics.
- Không đổi output-cap semantics.
- Không đổi UTF-8 conversion strategy ngoài khi compile/safety bắt buộc.
- Không đổi timeout constants trừ khi có bằng chứng rõ ràng và report giải thích.
- Không thay UI hoặc nghiệp vụ Clear/Backup/Restore/Keychain.

## Out of scope

Không triển khai:

- direct executable/argv API;
- caller migration;
- default timeout policy;
- `AppDataCleaner` wrapper;
- process-tree enumeration;
- `setpgid` post-spawn fallback;
- new public cancellation API;
- asynchronous command API;
- changes to AppDataCleaner;
- changes to AppDataBackupManager;
- changes to AppEntitlementsReader;
- changes to keychain helper;
- UI changes;
- TASK-0.4 hoặc task Phase 1.

## Implementation guidance

Agent có thể refactor internal helpers để tránh duplicate code, nhưng phải giữ diff tập trung.

Gợi ý internal shape, không bắt buộc tên:

```c
typedef struct {
    BOOL enabled;
    BOOL configured;
    pid_t childPID;
    pid_t processGroupID;
    BOOL finalSignalSent;
} PXProcessGroupState;
```

Có thể thay `PXTerminateDirectChild` bằng helper trung tính hơn, ví dụ:

```text
PXTerminateSpawnedCommand
PXSignalOwnedProcessGroup
PXRunPreKillDrainPhase
PXRunPostKillReapPhase
```

Không được giữ helper tên “DirectChild” nhưng bên trong group-kill nếu tên gây hiểu nhầm trong report/source.

## Required verification

Agent phải thực hiện static/source verification sau:

### Spawn attribute checks

1. Search có `POSIX_SPAWN_SETPGROUP`.
2. Search có `posix_spawnattr_init`.
3. Search có `posix_spawnattr_setflags`.
4. Search có `posix_spawnattr_setpgroup(..., 0)`.
5. Search mọi `posix_spawnattr_destroy` path.
6. Xác nhận bounded spawn truyền attributes.
7. Xác nhận legacy spawn truyền `NULL` attributes.
8. Search toàn repo bảo đảm không thêm `setpgid`.

### Signal checks

1. Group signal target dùng negative owned PGID.
2. Có guard chống PGID `0`, `1`, `-1` và parent process group.
3. `SIGTERM` xảy ra trước `SIGKILL`.
4. Final group signal xảy ra trước direct child reap trong timeout path.
5. Không group signal sau direct child reap.
6. `ESRCH` được xử lý như race-to-exit, không tự động failure.
7. Error khác được ghi nhưng không bỏ cleanup.

### Reap checks

1. Group-enabled loop không gọi `waitpid` khi capture pipe còn mở.
2. Khi pipes đóng, direct child có thể được reap bình thường.
3. Post-KILL reap vẫn bounded.
4. Không có blocking `waitpid(..., 0)` trong bounded path.
5. `run:` có thể giữ blocking wait legacy.

### Compatibility checks

1. `CommandRunner.h` không đổi.
2. Caller diff rỗng.
3. Legacy option đặt process group disabled.
4. Bounded option đặt process group enabled.
5. Không sửa business/UI files.
6. `git diff --check` pass.
7. Review full diff và diff stat.

## Runtime scenario matrix for report

Agent không được tuyên bố runtime PASS nếu không thực sự chạy. Report phải đánh dấu `STATIC REVIEW`, `RUNTIME PASS`, `NOT RUN` rõ ràng cho từng scenario:

1. `echo ok` hoàn tất bình thường.
2. Child exit non-zero được giữ nguyên.
3. Child chết bởi signal không do timeout.
4. `sleep` vượt deadline.
5. Pipeline vượt deadline, ví dụ shell pipeline có process giữ pipe.
6. Background descendant giữ stdout/stderr sau khi shell exit.
7. Descendant xử lý SIGTERM và thoát trong grace.
8. Descendant bỏ qua SIGTERM và cần SIGKILL.
9. stdout vượt cap trong khi timeout.
10. stderr vượt cap trong khi timeout.
11. Shell exit sớm nhưng descendant giữ pipe đến deadline.
12. Group signal trả `ESRCH`.
13. Attribute setup failure cleanup path bằng source/fault-injection reasoning.
14. Timing failure cleanup bằng source reasoning.
15. Legacy `runAndCapture:` không tạo process group policy mới.
16. `run:` không đổi.

Không chạy test tạo orphan dài hạn nếu môi trường không có cleanup chắc chắn.

## Acceptance criteria

Agent phải sao chép checklist này vào report:

- [ ] Chỉ sửa `CommandRunner.m` và tạo report.
- [ ] Không đổi public API/header.
- [ ] Bổ sung internal process-group option/state rõ ràng.
- [ ] Chỉ bounded overload bật process group.
- [ ] Legacy APIs giữ process-group policy cũ.
- [ ] Dùng `POSIX_SPAWN_SETPGROUP` và pgroup `0` tại spawn time.
- [ ] Không dùng `setpgid` sau spawn.
- [ ] Mọi spawn attribute operation được check.
- [ ] Attribute lifecycle cleanup đúng mọi path.
- [ ] Owned PGID bằng spawned child PID và lớn hơn 1.
- [ ] Có guard không signal parent/current process group.
- [ ] Timeout gửi group SIGTERM.
- [ ] Timeout gửi final group SIGKILL trước khi reap leader.
- [ ] Không signal group sau khi leader đã reap.
- [ ] Bounded/group-enabled loop defer direct-child reap khi pipe còn mở.
- [ ] Pipes đóng thì normal reap vẫn hoạt động.
- [ ] Post-KILL direct-child reap có giới hạn.
- [ ] Partial output/cap/truncation behavior được giữ.
- [ ] Timeout/result mapping giữ actual direct-child status.
- [ ] `ESRCH` không tự động trở thành runner failure.
- [ ] Signal/setup/reap error vẫn cleanup hữu hạn.
- [ ] Không thêm synthetic exit code.
- [ ] Không sửa caller.
- [ ] Không sửa Clear/Backup/Restore/Keychain/UI.
- [ ] Đã audit toàn bộ `posix_spawn`, `waitpid`, `kill` path.
- [ ] `git diff --check` pass.
- [ ] Tạo `TASK-0.3-REPORT.md` đúng template.
- [ ] Ghi GitHub Actions là PENDING.
- [ ] Dừng sau TASK-0.3.

## Required report details

Report bắt buộc nêu:

- file đã sửa;
- public contract không đổi;
- internal option/state được thêm;
- exact spawn attribute calls;
- cách map attribute errors;
- processGroupID được xác lập lúc nào;
- signal target validation;
- exact SIGTERM/SIGKILL order;
- vì sao leader phải chưa reap trước final group signal;
- main-loop reap policy khi pipes mở/đóng;
- bounded reap behavior;
- `ESRCH` behavior;
- timing-failure cleanup;
- escaped-descendant limitation;
- caller audit;
- full runtime/static scenario matrix;
- GitHub Actions `PENDING`;
- suggested status `READY_FOR_REVIEW`.

## Agent handoff prompt

```text
Thực hiện duy nhất TASK-0.3 theo file:
docs/backup-restore-hardening/tasks/TASK-0.3-spawn-process-group-termination.md

Bắt buộc đọc README, STATUS, DECISIONS, TASK-0.1/TASK-0.2 reviews, TASK-0.2 report và report template trước khi sửa code.

Chỉ sửa CommandRunner.m. Không sửa CommandRunner.h hoặc caller.

Yêu cầu cốt lõi:
- bounded overload tạo process group atomically bằng POSIX_SPAWN_SETPGROUP và pgroup 0;
- legacy APIs không bật process-group policy;
- timeout signal negative owned PGID;
- group SIGTERM rồi group SIGKILL;
- final group signal phải xảy ra trước direct child reap;
- group-enabled capture loop không reap leader khi stdout/stderr pipe còn mở;
- post-KILL reap phải bounded;
- không dùng setpgid sau spawn;
- không triển khai argv API hoặc task tiếp theo.

Tạo report:
docs/backup-restore-hardening/reports/TASK-0.3-REPORT.md

Tự review full diff, điền acceptance checklist, ghi GitHub Actions PENDING, đề xuất READY_FOR_REVIEW và dừng lại.
```

## Gate to TASK-0.4

TASK-0.4 chỉ được mở khi:

- report TASK-0.3 đầy đủ;
- source/diff review xác nhận group ownership an toàn;
- không có post-spawn `setpgid`;
- GitHub Actions build thành công;
- không có header/caller regression;
- coordinator chấp nhận timeout group semantics.
