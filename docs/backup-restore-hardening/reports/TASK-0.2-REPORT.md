# TASK-0.2 Agent Report

## Metadata

```text
Task ID: TASK-0.2
Task title: Bounded Capture and Deterministic Deadline
Task specification: docs/backup-restore-hardening/tasks/TASK-0.2-bounded-capture-deadline.md
Agent: GPT-5.6 Thinking
Started at: 2026-07-13 (Asia/Ho_Chi_Minh)
Finished at: 2026-07-13 (Asia/Ho_Chi_Minh)
Suggested status: READY_FOR_REVIEW
Commit hash: chưa commit
```

## 1. Summary

Đã bổ sung overload capture có deadline tổng và output cap thật:

```objc
- (CommandResult *)runAndCapture:(NSString *)command
                     timeoutSec:(NSTimeInterval)timeoutSec
                 maxOutputBytes:(NSUInteger)maxOutputBytes;
```

Overload mới dùng deadline monotonic tính từ lúc method bắt đầu, giới hạn riêng stdout/stderr, tiếp tục drain và discard sau cap, theo dõi đồng thời pipe state và direct-child wait state, đồng thời thực hiện bounded direct-child termination theo thứ tự `SIGTERM → grace → SIGKILL → bounded reap` khi deadline hết.

API legacy `run:` và `runAndCapture:` vẫn tồn tại. `runAndCapture:` legacy dùng chung capture engine nhưng tắt deadline và output cap, vì vậy không caller hiện tại nào tự động nhận policy mới. Không sửa caller, không triển khai process group, argv API hoặc TASK-0.3.

## 2. Files Changed

| File | Change | Why required |
|---|---|---|
| `CommandRunner.h` | Thêm public overload `runAndCapture:timeoutSec:maxOutputBytes:`. | Public API bắt buộc của TASK-0.2. |
| `CommandRunner.m` | Thêm monotonic timing, shared capture engine, per-stream bounded retention, child polling, timeout termination/reap và duration finalization. | Triển khai behavior thật của overload mới và duration cho toàn bộ execution path. |
| `docs/backup-restore-hardening/reports/TASK-0.2-REPORT.md` | Tạo agent report. | Report bắt buộc của task. |

Không sửa file code ngoài `CommandRunner.h` và `CommandRunner.m`. Không sửa `AppDataCleaner.m`, `AppDataBackupManager.m`, `AppEntitlementsReader.m`, task specification, status hoặc decision log.

Các thay đổi tài liệu coordinator đã tồn tại trong working tree trước task được giữ nguyên và không bị agent chỉnh sửa; agent chỉ tạo report TASK-0.2 được yêu cầu.

## 3. Contract Changes

### Public API được thêm

```objc
- (CommandResult *)runAndCapture:(NSString *)command
                     timeoutSec:(NSTimeInterval)timeoutSec
                 maxOutputBytes:(NSUInteger)maxOutputBytes;
```

### API/property giữ nguyên

```objc
- (CommandResult *)run:(NSString *)command;
- (CommandResult *)runAndCapture:(NSString *)command;
```

Toàn bộ property của `CommandResult` từ TASK-0.1 được giữ nguyên, bao gồm `timedOut`, `duration`, `stdoutTruncated`, `stderrTruncated`, `spawnError`, `runnerError`, `terminationSignal`, `exitedNormally` và `exitCode`.

### Semantics overload mới

- `timeoutSec` phải finite và lớn hơn `0`.
- `maxOutputBytes` phải lớn hơn `0`.
- Validation failure trả `runnerError = EINVAL`, không spawn child và không đặt `timedOut`.
- Deadline được tính từ monotonic timestamp lấy ngay khi shared engine bắt đầu, trước validation, pipe setup và spawn.
- `maxOutputBytes` là cap riêng cho stdout và riêng cho stderr.
- Byte vượt cap bị discard nhưng pipe vẫn tiếp tục được drain.
- Timeout đặt `timedOut = YES`; không gán `runnerError = ETIMEDOUT` nếu termination/reap thành công và không gán exit code synthetic.
- Actual child wait status được giữ nếu direct child exit hoặc bị signal trong termination window.
- Partial captured output được giữ sau timeout.

### Compatibility

- Không migrate caller sang overload mới.
- Legacy `runAndCapture:` truyền options với `deadlineEnabled = NO` và `outputCapEnabled = NO` vào cùng shared engine.
- Legacy API không nhận timeout mặc định hoặc output cap mặc định.
- `run:` vẫn dùng `/bin/sh -c` và synchronous blocking wait như trước.
- `/bin/sh -c` được giữ cho cả hai capture API.

## 4. Implementation Notes

### Shared capture engine

`PXRunCaptureCommand` là internal shared engine cho cả legacy và overload mới. `PXCaptureOptions` điều khiển riêng:

```text
deadlineEnabled
timeoutSec
outputCapEnabled
maxOutputBytes
```

Engine sở hữu toàn bộ lifecycle:

1. monotonic start time;
2. validation;
3. pipe và nonblocking setup;
4. `posix_spawn_file_actions_t`;
5. shell spawn;
6. concurrent stdout/stderr drain;
7. `waitpid(..., WNOHANG)` child polling;
8. total deadline;
9. timeout termination/reap;
10. UTF-8 conversion;
11. descriptor cleanup;
12. duration finalization.

Không duplicate capture implementation giữa API legacy và overload mới.

### Monotonic clock primitive

Dùng:

```c
clock_gettime(CLOCK_MONOTONIC, ...)
```

Không dùng `NSDate`, wall clock, timezone hoặc system calendar time.

`PXFinishResult` tập trung tính elapsed duration. `duration` được set cho:

- `run:`;
- `runAndCapture:` legacy;
- overload mới;
- validation failure;
- pipe/fcntl/spawn-actions failure;
- spawn failure;
- normal exit;
- signal exit;
- wait failure;
- timeout.

Nếu monotonic clock call thất bại, runner ghi mã lỗi vào `runnerError`, không dùng wall-clock fallback và giữ `duration` ở giá trị không âm `0` nếu elapsed time không thể xác định.

### Timeout measurement point

Start timestamp được lấy ngay sau khi tạo `CommandResult` trong shared engine. Absolute deadline là:

```text
method start monotonic time + timeoutSec
```

Validation, setup, spawn, capture và wait đều nằm trong cùng total deadline. Có thêm check ngay trước spawn; nếu setup đã dùng hết deadline thì method đặt `timedOut = YES`, cleanup spawn actions/pipes và không spawn child.

### Capture loop and child state

Loop theo dõi đồng thời:

- stdout pipe open/EOF/error state;
- stderr pipe open/EOF/error state;
- direct child running/reaped/wait-state-unavailable state;
- absolute monotonic deadline.

Direct child được poll bằng `waitpid(pid, ..., WNOHANG)`. Overload mới không gọi blocking `waitpid(..., 0)`.

Blocking wait helper chỉ được `run:` sử dụng. Capture engine, bao gồm legacy capture, dùng child polling.

`select` wait được giới hạn bởi giá trị nhỏ hơn giữa poll quantum và remaining deadline. `EINTR` quay lại outer loop nên không tạo lại hoặc kéo dài total deadline.

Mỗi drain cycle đọc tối đa `64 KiB` trên mỗi stream trước khi quay lại loop. Điều này ngăn một stream ghi liên tục giữ runner mãi trong read loop mà không kiểm tra deadline.

### Per-stream cap and drain/discard

Cap là độc lập:

```text
stdout retained bytes <= maxOutputBytes
stderr retained bytes <= maxOutputBytes
```

Khi chunk vượt phần cap còn lại:

- chỉ append số byte còn chỗ;
- đặt truncation flag tương ứng;
- discard phần còn lại;
- tiếp tục `read()` stream ở các cycle sau.

Nếu output đúng bằng cap và sau đó EOF, không byte nào bị discard nên truncation flag vẫn `NO`.

Không terminate child chỉ vì vượt cap và không append thông báo synthetic vào output.

### UTF-8 boundary strategy

Conversion thực hiện theo thứ tự:

1. decode toàn bộ retained bytes bằng UTF-8;
2. nếu thất bại, thử trim lần lượt tối đa 3 trailing bytes để loại phần cuối của UTF-8 multibyte sequence bị cap cắt giữa boundary;
3. nếu dữ liệu vẫn chứa invalid UTF-8 ở vị trí khác, dùng ISO Latin-1 fallback để không biến toàn bộ retained prefix thành empty string.

Vì UTF-8 sequence tối đa 4 byte, tối đa 3 byte trailing có thể là phần sequence chưa hoàn chỉnh. Valid prefix trước boundary được giữ.

### Poll and termination constants

```text
Capture/reap poll quantum: 50 ms
SIGTERM grace: 350 ms
Post-SIGKILL bounded reap grace: 750 ms
Per-stream drain budget per cycle: 64 KiB
```

Termination/reap phases dùng monotonic absolute phase deadline. Đồng thời có bounded attempt count dựa trên poll quantum để vẫn return hữu hạn nếu monotonic clock bất ngờ thất bại trong termination phase; clock failure được ghi vào `runnerError`.

### Direct-child timeout sequence

Khi total deadline hết:

1. đặt `timedOut = YES`;
2. poll direct child lần cuối để tránh signal một child vừa exit;
3. nếu chưa reap, gửi `SIGTERM` cho direct child PID;
4. poll/reap và drain trong `350 ms`;
5. nếu vẫn chưa reap, gửi `SIGKILL` cho direct child PID;
6. poll/reap và drain trong `750 ms`;
7. drain nonblocking phần output còn sẵn có;
8. đóng pipe còn mở và return.

`kill(...)=ESRCH` không tự động là runner failure; runner tiếp tục poll/reap vì child có thể vừa exit.

Nếu kill thất bại với lỗi khác hoặc child không reap được trong bounded window, `timedOut` vẫn `YES` và `runnerError` nhận lỗi có nghĩa. `ETIMEDOUT` chỉ được dùng cho failure không reap được sau bounded termination window, không dùng để biểu diễn timeout policy thành công.

### Timeout result mapping

**Child bị signal do timeout**

```text
timedOut = YES
exitedNormally = NO
exitCode = -1
terminationSignal = actual WTERMSIG status
```

**Child tự exit trong SIGTERM grace**

```text
timedOut = YES
exitedNormally / exitCode / terminationSignal = actual wait status
```

**Direct child đã reap nhưng descendant giữ pipe**

```text
timedOut = YES
actual direct-child wait state được giữ
data đang sẵn có được drain nonblocking
pipe được đóng để return bounded
```

Không có synthetic exit code `124`, `137` hoặc giá trị tương tự.

### Error precedence

Policy triển khai:

1. `spawnError` chỉ chứa return code của `posix_spawn`.
2. Validation/setup/read/select/clock/kill errors dùng `runnerError`.
3. Noncritical runner errors giữ lỗi đầu tiên qua `PXSetRunnerErrorIfUnset`.
4. Wait/reap failure hoặc wait status không thể diễn giải được xem là critical child-state error và được phép override lỗi runner trước đó, vì runner đã mất khả năng xác định hoặc reap direct child chính xác.
5. Child non-zero exit không phải runner error.
6. Timeout được nhận diện đúng không tự tạo runner error.
7. Failure không reap được trong bounded post-kill window dùng `ETIMEDOUT` nếu chưa có runner error có ý nghĩa hơn.

### Resource cleanup

Đã review các ownership path:

- stdout read/write descriptors;
- stderr read/write descriptors;
- spawn actions initialized/destroyed state;
- child running/reaped/unavailable state;
- captured mutable data;
- duration finalization.

Descriptor helper đặt FD về `-1` sau close để tránh double-close. Spawn action setup failure và pre-spawn deadline/clock failure đều destroy actions và đóng toàn bộ pipe ends đã mở.

### Direct-child-only limitation

TASK-0.2 chỉ gọi:

```c
kill(pid, SIGTERM)
kill(pid, SIGKILL)
```

Không có `POSIX_SPAWN_SETPGROUP`, `setpgid`, `posix_spawnattr`, negative PID kill hoặc process-group management.

Nếu `/bin/sh` đã exit nhưng pipeline/background descendant giữ stdout/stderr pipe, overload mới vẫn return bounded ở deadline bằng cách giữ direct-child status, drain phần đang sẵn có và đóng pipe. Descendant không bị terminate trong TASK-0.2. Limitation này được chuyển nguyên vẹn sang TASK-0.3.

## 5. Acceptance Checklist

- [x] Thêm overload `runAndCapture:timeoutSec:maxOutputBytes:`.
- [x] Validate timeout finite và lớn hơn 0.
- [x] Validate maxOutputBytes lớn hơn 0.
- [x] Dùng monotonic clock cho deadline và duration.
- [x] `duration` được set trên mọi execution/return path.
- [x] stdout và stderr có cap riêng.
- [x] Tiếp tục drain/discard sau cap.
- [x] Truncation flags chỉ true khi thực tế discard byte.
- [x] UTF-8 prefix không bị mất toàn bộ tại cap boundary.
- [x] Capture loop theo dõi child và pipe trong total deadline.
- [x] Không có blocking wait vô hạn trong overload mới.
- [x] Timeout đặt `timedOut = YES` và không tạo exit code synthetic.
- [x] Có bounded SIGTERM → SIGKILL → reap sequence cho direct child.
- [x] Partial output được giữ sau timeout.
- [x] Resource cleanup đầy đủ.
- [x] API legacy vẫn tồn tại.
- [x] Legacy API chưa bị áp policy timeout/cap mới.
- [x] Không sửa caller.
- [x] Không triển khai process group.
- [x] Không sửa nghiệp vụ Clear/Backup/Restore/Keychain/UI.
- [x] Agent đã tự review full diff và `git diff --check`.
- [x] Tạo report đúng đường dẫn.
- [x] Dừng sau TASK-0.2.

## 6. Verification Performed

### Commands and static checks

| Check/command | Result | Evidence/notes |
|---|---|---|
| Required reading | PASS | Đã đọc README, STATUS, DECISIONS, TASK-0.1 review, report template, TASK-0.2 specification, `CommandRunner.h/.m`. |
| Search all `runAndCapture:` caller | PASS | Audit 14 code occurrences: 11 trong `AppDataBackupManager.m`, 2 trong `AppDataCleaner.m`, 1 trong `AppEntitlementsReader.m`; không caller nào được sửa. |
| Search new `maxOutputBytes:` selector | PASS | Chỉ xuất hiện trong header, implementation và task specification; không có call-site migration. |
| Legacy policy inspection | PASS | Legacy options đặt deadline/cap disabled; không timeout/cap mặc định. |
| Blocking wait inspection | PASS | Một `waitpid(..., 0)` duy nhất nằm trong helper chỉ được `run:` gọi; capture engine dùng `WNOHANG`. |
| Process-group forbidden search | PASS | Không có `POSIX_SPAWN_SETPGROUP`, `setpgid`, `posix_spawnattr`, group kill hoặc negative PID kill. |
| Timing source inspection | PASS | Có `CLOCK_MONOTONIC`; không có `NSDate`. |
| Synthetic exit-code search | PASS | Không có assignment `exitCode = 124` hoặc `exitCode = 137`. |
| Structural source check | PASS | Header/implementation overload count đều bằng 1; `{` và `}` đều 133 tại thời điểm kiểm tra. |
| Caller diff | PASS | `git diff -- AppDataCleaner.m AppDataBackupManager.m AppEntitlementsReader.m` không có output. |
| `git diff --check -- CommandRunner.h CommandRunner.m` | PASS | Exit code `0`; không có whitespace error. |
| Local Objective-C build/runtime tests | NOT RUN | Workspace Windows không có `clang`, Objective-C/iOS SDK hoặc `make`; GitHub Actions là build gate. |
| GitHub Actions | PENDING | Workflow expected: `.github/workflows/build-ios-arm.yml`. |

### Required verification scenarios

| # | Scenario | Status | Evidence/notes |
|---|---|---|---|
| 1 | `timeoutSec = 0` | STATIC REVIEW PASS; runtime NOT RUN | `!isfinite(...) || timeoutSec <= 0` trả `EINVAL` trước pipe/spawn. |
| 2 | `timeoutSec < 0` | STATIC REVIEW PASS; runtime NOT RUN | Cùng validation path. |
| 3 | `timeoutSec = NaN/Inf` | STATIC REVIEW PASS; runtime NOT RUN | `isfinite` bắt NaN và ±Inf. |
| 4 | `maxOutputBytes = 0` | STATIC REVIEW PASS; runtime NOT RUN | Trả `EINVAL` trước pipe/spawn. |
| 5 | stdout nhỏ hơn cap | STATIC REVIEW PASS; runtime NOT RUN | Toàn bộ bytes được append, flag không đổi. |
| 6 | stderr nhỏ hơn cap | STATIC REVIEW PASS; runtime NOT RUN | Per-stream path tương đương và độc lập. |
| 7 | child exit 0/non-zero | STATIC REVIEW PASS; runtime NOT RUN | Actual `WEXITSTATUS` được giữ. |
| 8 | signal không do timeout | STATIC REVIEW PASS; runtime NOT RUN | `WIFSIGNALED/WTERMSIG` mapping được giữ. |
| 9 | stdout vượt cap | STATIC REVIEW PASS; runtime NOT RUN | Retained length bounded, overflow discard, tiếp tục read. |
| 10 | stderr vượt cap | STATIC REVIEW PASS; runtime NOT RUN | Per-stream path tương đương. |
| 11 | cả hai stream vượt cap | STATIC REVIEW PASS; runtime NOT RUN | Hai data buffer/cap/flag riêng, drain trong cùng loop. |
| 12 | output đúng bằng cap | STATIC REVIEW PASS; runtime NOT RUN | Flag chỉ true khi `keepLength < length`; exact cap không truncate nếu EOF tiếp theo. |
| 13 | UTF-8 multibyte boundary | STATIC REVIEW PASS; runtime NOT RUN | Trim tối đa 3 trailing bytes trước fallback. |
| 14 | sleep vượt deadline | STATIC REVIEW PASS; runtime NOT RUN | Absolute deadline dẫn vào bounded termination sequence. |
| 15 | partial stdout trước timeout | STATIC REVIEW PASS; runtime NOT RUN | Captured data không reset khi timeout và được decode trước return. |
| 16 | child xử lý SIGTERM | STATIC REVIEW PASS; runtime NOT RUN | Grace phase poll/reap giữ actual status; `timedOut` vẫn true. |
| 17 | child bỏ qua SIGTERM | STATIC REVIEW PASS; runtime NOT RUN | Sau 350 ms gửi SIGKILL, reap tối đa 750 ms. |
| 18 | EINTR không reset deadline | STATIC REVIEW PASS; runtime NOT RUN | EINTR quay về outer loop/attempt; deadline absolute không được tái tạo. |
| 19 | `run:` tồn tại và có duration | PASS by source inspection | API giữ nguyên, mọi return dùng duration finalizer hoặc explicit `0` khi start clock fail. |
| 20 | legacy `runAndCapture:` tồn tại | PASS by source inspection | Declaration và implementation giữ nguyên. |
| 21 | Không caller nào sửa | PASS | Caller diff rỗng. |
| 22 | Legacy không nhận deadline/cap | PASS by source inspection | Legacy options disable cả hai policy. |

Runtime behavior và iOS declaration/implementation compatibility vẫn cần GitHub Actions và, nếu có thể, test trên thiết bị/simulator phù hợp.

## 7. Diff Review

- Có thay đổi ngoài task không? **Không trong code.** Chỉ `CommandRunner.h`, `CommandRunner.m` và report bắt buộc.
- Có format-only churn không? **Không.** Diff tập trung vào shared engine, timing, capture, termination và public declaration.
- Có generated/binary file thay đổi không? **Không.**
- Có API cũ bị xóa không? **Không.**
- Có caller migration không? **Không.**
- Có behavior TASK-0.3 bị triển khai sớm không? **Không.** Không có process-group setup/kill.
- Có argv API không? **Không.**

`git diff --stat -- CommandRunner.h CommandRunner.m`:

```text
 CommandRunner.h |   3 +
 CommandRunner.m | 908 +++++++++++++++++++++++++++++++++++++++++++++-----------
 2 files changed, 745 insertions(+), 166 deletions(-)
```

Các phần diff đáng chú ý:

- thêm 3 dòng public selector trong header;
- thay capture loop cũ bằng shared engine có options;
- thêm monotonic duration/deadline helpers;
- thêm bounded per-cycle drain và per-stream retain cap;
- thêm WNOHANG child polling;
- thêm direct-child timeout termination/reap;
- giữ nguyên `CommandResult` initialization và `isSucceeded` contract từ TASK-0.1;
- giữ nguyên `firstExistingPath:`.

## 8. Safety Notes

- Task có thêm hoặc thay đổi destructive behavior không? **Overload mới có direct-child termination khi caller chủ động truyền deadline.** Không caller hiện tại dùng overload này, nên không thay đổi Clear/Backup/Restore/Keychain behavior hiện tại.
- Task có thay đổi path resolution không? **Không.**
- Task có thay đổi Clear/Backup/Restore/Keychain behavior không? **Không.** Không sửa caller và không áp policy mới cho API legacy.
- Task có swallow error hoặc biến failure thành success không? **Không.** Validation/setup/read/select/wait/clock/kill/reap failure được map vào structured fields; timeout không bị biến thành exit success.
- Task có kill process group hoặc descendant không? **Không.** Chỉ direct child PID.
- Timeout có synthetic exit code không? **Không.**

## 9. Not Changed

- Không sửa `AppDataCleaner.m`.
- Không sửa `AppDataBackupManager.m`.
- Không sửa `AppEntitlementsReader.m`.
- Không sửa bất kỳ caller nào.
- Không migrate caller sang overload mới.
- Không áp timeout/cap mặc định cho API legacy.
- Không đổi `/bin/sh -c`.
- Không triển khai `POSIX_SPAWN_SETPGROUP`.
- Không triển khai `setpgid`.
- Không triển khai process-group kill.
- Không triển khai cleanup shell descendants.
- Không triển khai direct executable/argv API.
- Không sửa Clear, Backup, Restore, Keychain hoặc UI.
- Không sửa task specification, STATUS hoặc DECISIONS.
- Không thực hiện TASK-0.3.

## 10. Remaining Risks

- Chưa compile bằng iOS/Theos toolchain tại workspace hiện tại; GitHub Actions phải xác nhận declaration/implementation compatibility và SDK availability của monotonic APIs.
- Runtime scenarios chưa chạy do thiếu Objective-C/iOS build environment. Static review bao phủ toàn bộ required scenario nhưng không thay thế device/runtime test.
- TASK-0.2 chỉ terminate direct `/bin/sh` child. Pipeline/background descendants có thể tiếp tục sống và chỉ bị mất pipe khi overload đóng descriptors ở deadline. Process-group ownership/termination vẫn thuộc TASK-0.3.
- Trong trường hợp bất thường direct child không reap được sau SIGKILL grace, method vẫn return bounded với `runnerError`; direct child có thể cần external cleanup. Normal timeout path poll/reap direct child trong cả hai grace phases.
- Legacy `runAndCapture:` cố ý vẫn có thể chờ vô hạn nếu command hoặc descendant không kết thúc/không đóng pipe, vì task cấm áp policy deadline mặc định trước TASK-0.3.
- Retained output được giới hạn, nhưng runner vẫn phải tiêu tốn I/O để drain/discard output vượt cap cho đến completion hoặc deadline; đây là behavior bắt buộc để tránh pipe deadlock.

## 11. GitHub Actions Handoff

```text
Build requested: YES
Workflow expected: .github/workflows/build-ios-arm.yml
Build result: PENDING
Build URL/run ID: PENDING
```

Agent dừng tại TASK-0.2. Suggested status: `READY_FOR_REVIEW`.
