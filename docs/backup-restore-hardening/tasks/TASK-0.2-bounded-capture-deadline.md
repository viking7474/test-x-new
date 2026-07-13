# TASK-0.2 — Bounded Capture and Deterministic Deadline

## Metadata

- Phase: Phase 0 — Reliable Command Execution
- Status: READY
- Dependency: TASK-0.1 accepted and GitHub Actions passed
- Required report: `docs/backup-restore-hardening/reports/TASK-0.2-REPORT.md`
- Build gate: GitHub Actions by project owner
- Suggested commit: `phase0(task-0.2): add bounded capture and deadline`

## Objective

Bổ sung một API capture mới có deadline tổng, giới hạn byte cho stdout/stderr và kết quả timeout có cấu trúc.

Task này phải bảo đảm method mới:

- không treo vô hạn khi child không đóng pipe;
- không tăng RAM vô hạn do stdout/stderr lớn;
- đo duration bằng monotonic clock;
- trả về trong thời gian hữu hạn sau deadline;
- giữ lại output đã capture trước timeout/truncation;
- biểu diễn timeout qua `CommandResult.timedOut` thay vì giả thành child exit code.

Task này **không** triển khai process group. Timeout trong TASK-0.2 chỉ terminate direct child PID. Shell descendants/pipeline/background process sẽ được xử lý trong TASK-0.3.

Không migrate caller hiện tại trong task này.

## Required reading

Agent phải đọc:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. `docs/backup-restore-hardening/reviews/TASK-0.1-REVIEW.md`
5. File task này
6. `CommandRunner.h`
7. `CommandRunner.m`
8. Tất cả call site của `runAndCapture:`

## Allowed files

Chỉ sửa:

- `CommandRunner.h`
- `CommandRunner.m`

Sau đó tạo report:

- `docs/backup-restore-hardening/reports/TASK-0.2-REPORT.md`

Không sửa task specification, status, decision log, caller hoặc file nghiệp vụ.

Nếu compile bắt buộc phải sửa file ngoài phạm vi, agent phải dừng và ghi blocker; không tự mở rộng scope.

## Current source facts

Sau TASK-0.1:

- `CommandResult` đã có `timedOut`, `duration`, `stdoutTruncated`, `stderrTruncated`.
- `runAndCapture:` vẫn dùng loop `select` với timeout từng vòng 1 giây nhưng không có total deadline.
- stdout/stderr vẫn được append không giới hạn.
- child chỉ được `waitpid` sau khi cả hai pipe đóng.
- background descendant có thể giữ pipe mở và làm loop không kết thúc.
- chưa có process-group setup.
- caller hiện tại vẫn gọi API legacy `runAndCapture:`.

## Public API to add

Bổ sung API thật, không phải placeholder:

```objc
- (CommandResult *)runAndCapture:(NSString *)command
                     timeoutSec:(NSTimeInterval)timeoutSec
                 maxOutputBytes:(NSUInteger)maxOutputBytes;
```

Semantics:

- `timeoutSec` là execution/capture deadline tính từ khi method bắt đầu. Khi deadline này hết, bounded termination sequence mới bắt đầu.
- Tổng thời gian return được phép vượt `timeoutSec` chỉ bởi termination/reap budget hữu hạn đã định nghĩa trong task.
- Deadline phải dùng monotonic clock, không dùng `NSDate`, system wall clock hoặc timezone-sensitive time.
- `maxOutputBytes` là giới hạn **riêng cho mỗi stream**:
  - stdout có tối đa `maxOutputBytes` byte được giữ;
  - stderr có tối đa `maxOutputBytes` byte được giữ.
- Method là synchronous như API hiện tại.

## Compatibility contract

Giữ nguyên:

```objc
- (CommandResult *)run:(NSString *)command;
- (CommandResult *)runAndCapture:(NSString *)command;
```

Trong TASK-0.2:

- Không migrate caller sang overload mới.
- Không đặt deadline mặc định mới cho caller hiện tại.
- Không đặt output cap mới cho caller hiện tại.
- `runAndCapture:` legacy phải giữ behavior tương thích và dùng chung capture engine nếu có thể, nhưng không được âm thầm timeout command hiện tại.
- `run:` không được đổi sang API capture.
- `/bin/sh -c` vẫn giữ nguyên.

Lý do: process-group termination chưa có cho shell descendants. API bounded/deadline mới được hoàn thiện trước, sau đó TASK-0.3 mới harden termination scope.

## Input validation

Method mới phải validate trước khi spawn:

### `command`

Giữ contract nullability hiện tại. Không thêm exception. Nếu runtime nhận command không dùng được hoặc UTF-8 conversion thất bại, trả structured runner failure thay vì crash.

### `timeoutSec`

Hợp lệ khi:

```text
isfinite(timeoutSec)
timeoutSec > 0
```

Không hợp lệ:

- `0`;
- số âm;
- NaN;
- positive/negative infinity.

Khi không hợp lệ:

```text
runnerError = EINVAL
spawnError = 0
exitCode = -1
exitedNormally = NO
timedOut = NO
```

Không spawn child.

### `maxOutputBytes`

Hợp lệ khi:

```text
maxOutputBytes > 0
```

`0` không có nghĩa là unlimited.

Khi không hợp lệ, trả `runnerError = EINVAL` và không spawn child.

Không tự nâng cap hoặc đổi giá trị caller truyền vào.

## Monotonic timing contract

Agent có thể dùng `clock_gettime(CLOCK_MONOTONIC, ...)` hoặc primitive monotonic tương đương có trên deployment target.

Không dùng wall clock.

`duration` phải:

- được đo cho `run:`;
- được đo cho `runAndCapture:` legacy;
- được đo cho overload mới;
- được set cả trên success, spawn failure, runner/setup failure, validation failure và timeout;
- là số giây không âm;
- bao gồm setup, spawn, capture, wait và timeout termination time.

Một helper tập trung nên chịu trách nhiệm lấy monotonic time và tính elapsed time.

Nếu monotonic clock call thất bại:

- command runner không được crash;
- trả hoặc ghi `runnerError` có nghĩa;
- không dùng wall clock làm fallback im lặng.

## Capture limit contract

Đối với overload mới:

- chỉ giữ tối đa `maxOutputBytes` byte cho mỗi stream;
- `stdoutString` và `stderrString` chứa phần đã giữ;
- nếu có ít nhất một byte bị discard vì cap, đặt flag tương ứng thành `YES`;
- nếu tổng output đúng bằng cap và không có byte vượt cap, flag vẫn là `NO`;
- cap của stdout không làm giảm cap của stderr và ngược lại.

Điểm bắt buộc:

**Sau khi stream đạt cap, runner vẫn phải tiếp tục đọc và discard dữ liệu từ pipe.**

Không được ngừng đọc stream chỉ vì đã đủ byte, vì child có thể block khi pipe đầy.

Không được terminate command chỉ vì output vượt cap.

Không append thông báo synthetic vào stdout/stderr. Truncation chỉ được biểu diễn bằng flags.

Agent phải review UTF-8 decoding ở boundary cap. Không được để toàn bộ captured string trở thành empty chỉ vì cap cắt giữa một multibyte sequence. Có thể:

- trim phần đuôi UTF-8 chưa hoàn chỉnh trước khi decode; hoặc
- dùng một conversion strategy có loss handling rõ ràng.

Không được silently thay toàn bộ output bằng empty string khi data prefix vẫn có thể biểu diễn.

## Capture loop requirements

Overload mới không được dựa vào “1 giây timeout mỗi `select`” như total deadline.

Capture loop phải theo dõi đồng thời:

- stdout pipe state;
- stderr pipe state;
- child wait state;
- monotonic deadline.

Yêu cầu:

1. Pipe read ends ở nonblocking mode.
2. stdout/stderr được drain trong cùng một event loop hoặc cơ chế đồng thời tương đương.
3. `select`/poll wait không được vượt remaining deadline.
4. Loop phải poll child bằng `waitpid(..., WNOHANG)` hoặc cơ chế bounded tương đương.
5. Không gọi blocking `waitpid(..., 0)` ở một path có thể làm overload mới vượt deadline không giới hạn.
6. Nếu child exit nhưng descendant giữ pipe mở, total deadline vẫn phải có hiệu lực.
7. Nếu pipe EOF trước child exit, vẫn chờ child trong remaining deadline.
8. EINTR phải được retry đúng chỗ mà không reset total deadline.
9. Read/select/wait failure phải được map vào `runnerError` và resource phải được đóng.

Không duplicate toàn bộ capture implementation giữa legacy và overload mới. Nên có internal shared engine với options rõ ràng, trong đó legacy mode có thể tắt deadline/cap để giữ compatibility.

## Timeout detection

Khi monotonic deadline hết trước khi operation hoàn tất:

```text
timedOut = YES
```

Timeout không tự động đặt:

```text
runnerError = ETIMEDOUT
```

nếu timeout được nhận diện và direct child được terminate/reap đúng như thiết kế. `timedOut` là field chuyên biệt cho trạng thái này.

`isSucceeded` đã tự false khi `timedOut == YES`.

Không thay timeout thành child `exitCode = 124`, `137` hoặc mã shell synthetic.

## Direct-child termination sequence for TASK-0.2

Do process group chưa thuộc task này, chỉ target direct child PID.

Sequence bắt buộc:

1. Đánh dấu `timedOut = YES` đúng một lần.
2. Gửi `SIGTERM` đến direct child nếu child chưa được reap.
3. Poll `waitpid(..., WNOHANG)` trong grace period hữu hạn.
4. Nếu child vẫn sống, gửi `SIGKILL` đến direct child.
5. Poll/reap trong khoảng hữu hạn.
6. Drain phần output đang sẵn có mà không block.
7. Đóng pipe còn mở và return.

Agent được chọn constants nhỏ, tập trung và được ghi rõ trong report. Khuyến nghị:

```text
poll quantum: <= 100 ms
SIGTERM grace: 250–500 ms
post-SIGKILL reap grace: <= 1 second
```

Overload mới phải có bounded return. Không có vòng `waitpid` hoặc pipe-drain vô hạn sau deadline.

Nếu `kill` trả `ESRCH`, không coi ngay là runner failure; child có thể vừa exit. Phải poll/reap.

Nếu `kill` thất bại với lỗi khác hoặc child không thể được reap trong bounded termination window:

- giữ `timedOut = YES`;
- set `runnerError` có nghĩa nếu chưa có lỗi runner nghiêm trọng hơn;
- không giả success.

## Result state after timeout

### Child bị signal do timeout

Sau wait status:

```text
timedOut = YES
exitedNormally = NO
exitCode = -1
terminationSignal = actual signal from wait status
```

### Child tự exit trong grace period

Giữ actual wait status:

```text
timedOut = YES
exitedNormally = YES hoặc NO theo wait status
exitCode/terminationSignal = actual values
```

Timeout vẫn là true vì deadline đã bị vượt.

### Child đã exit nhưng descendant giữ pipe

Nếu direct child wait status đã có nhưng pipe không đóng đến deadline:

- giữ actual direct-child wait state;
- đặt `timedOut = YES`;
- drain nonblocking phần đang có;
- đóng pipe;
- return bounded.

Report phải nêu đây là limitation tạm thời cho đến TASK-0.3.

## Resource ownership and cleanup

Mọi return path phải review:

- stdout read/write FDs;
- stderr read/write FDs;
- `posix_spawn_file_actions_t`;
- child reap state;
- captured mutable data;
- duration finalization.

Không double-close FD.

Không leave zombie direct child trên path timeout bình thường.

Không thêm global mutable state.

## Error precedence

Giữ nguyên nguyên tắc từ TASK-0.1:

- `spawnError` chỉ chứa `posix_spawn` failure.
- `runnerError` chứa validation/setup/read/select/wait/termination failure.
- child non-zero exit không phải `runnerError`.
- timeout thành công về mặt runner được biểu diễn bằng `timedOut`, không phải synthetic runner error.

Nếu nhiều runner error xảy ra, giữ lỗi đầu tiên, ngoại trừ lỗi làm mất khả năng xác định/reap child có thể được ưu tiên. Agent phải ghi policy chính xác trong report.

## Out of scope

Không triển khai:

- `posix_spawnattr` process-group setup;
- `POSIX_SPAWN_SETPGROUP`;
- `setpgid`;
- `kill(-pgid, ...)`;
- cleanup toàn bộ shell descendants;
- direct executable/argv API;
- caller migration;
- timeout policy riêng cho tar/keychain/ldid;
- changes trong `AppDataCleaner`;
- changes trong `AppDataBackupManager`;
- changes trong `AppEntitlementsReader`;
- Keychain/UI/Clear/Backup/Restore behavior changes;
- unrelated refactor hoặc formatting churn.

## Required verification scenarios

Agent phải review hoặc chạy được càng nhiều càng tốt các case sau và ghi rõ RUN/PASS hoặc NOT RUN:

### Validation

1. `timeoutSec = 0` không spawn và trả `EINVAL`.
2. `timeoutSec < 0` không spawn và trả `EINVAL`.
3. `timeoutSec = NaN/Inf` không spawn và trả `EINVAL`.
4. `maxOutputBytes = 0` không spawn và trả `EINVAL`.

### Normal result

5. stdout nhỏ hơn cap được giữ đầy đủ, không truncated.
6. stderr nhỏ hơn cap được giữ đầy đủ, không truncated.
7. child exit code 0 và non-zero được giữ đúng.
8. signal termination không do timeout vẫn map đúng.

### Bounded output

9. stdout vượt cap: length giữ không quá cap, stdoutTruncated true, command không deadlock.
10. stderr vượt cap: tương tự.
11. cả hai stream vượt cap đồng thời: cả hai flag đúng và không deadlock.
12. output đúng bằng cap: truncated false.
13. UTF-8 multibyte tại boundary không làm mất toàn bộ captured prefix.

### Deadline

14. command ngủ lâu hơn deadline: timedOut true và method return hữu hạn.
15. partial stdout trước sleep vẫn được trả lại sau timeout.
16. child xử lý SIGTERM và tự exit trong grace: actual status được giữ, timedOut vẫn true.
17. child bỏ qua SIGTERM: runner dùng SIGKILL và return hữu hạn.
18. EINTR không reset deadline.

### Compatibility

19. `run:` API vẫn tồn tại và duration được set.
20. `runAndCapture:` legacy vẫn tồn tại.
21. Không caller nào được sửa.
22. Legacy API không bị áp deadline/cap mới trong task này.

Không chạy test tạo background descendant lâu sống hoặc pipeline orphan nếu không có cleanup thủ công. Chỉ ghi limitation; process-group matrix thuộc TASK-0.3.

## Acceptance criteria

Agent phải sao chép checklist này vào report:

- [ ] Thêm overload `runAndCapture:timeoutSec:maxOutputBytes:`.
- [ ] Validate timeout finite và lớn hơn 0.
- [ ] Validate maxOutputBytes lớn hơn 0.
- [ ] Dùng monotonic clock cho deadline và duration.
- [ ] `duration` được set trên mọi execution/return path.
- [ ] stdout và stderr có cap riêng.
- [ ] Tiếp tục drain/discard sau cap.
- [ ] Truncation flags chỉ true khi thực tế discard byte.
- [ ] UTF-8 prefix không bị mất toàn bộ tại cap boundary.
- [ ] Capture loop theo dõi child và pipe trong total deadline.
- [ ] Không có blocking wait vô hạn trong overload mới.
- [ ] Timeout đặt `timedOut = YES` và không tạo exit code synthetic.
- [ ] Có bounded SIGTERM → SIGKILL → reap sequence cho direct child.
- [ ] Partial output được giữ sau timeout.
- [ ] Resource cleanup đầy đủ.
- [ ] API legacy vẫn tồn tại.
- [ ] Legacy API chưa bị áp policy timeout/cap mới.
- [ ] Không sửa caller.
- [ ] Không triển khai process group.
- [ ] Không sửa nghiệp vụ Clear/Backup/Restore/Keychain/UI.
- [ ] Agent đã tự review full diff và `git diff --check`.
- [ ] Tạo report đúng đường dẫn.
- [ ] Dừng sau TASK-0.2.

## Required report content

Ngoài report template, agent phải nêu rõ:

- public API chính xác đã thêm;
- internal engine design;
- monotonic clock primitive;
- timeout measurement point;
- cap là per-stream;
- cách discard sau cap;
- UTF-8 boundary strategy;
- poll quantum;
- SIGTERM grace;
- SIGKILL/reap grace;
- error precedence;
- state mapping cho ba timeout cases;
- mọi caller được audit và xác nhận không sửa;
- limitation direct-child-only trước TASK-0.3;
- GitHub Actions là `PENDING`.

## Agent handoff prompt

```text
Thực hiện duy nhất TASK-0.2 theo file:
docs/backup-restore-hardening/tasks/TASK-0.2-bounded-capture-deadline.md

Đọc README.md, STATUS.md, DECISIONS.md, TASK-0.1 review và report template trước khi sửa code.

Chỉ sửa CommandRunner.h và CommandRunner.m, sau đó tạo:
docs/backup-restore-hardening/reports/TASK-0.2-REPORT.md

Không sửa caller.
Không áp timeout/cap mặc định cho API legacy trong task này.
Không triển khai process group, argv API hoặc task tiếp theo.

Sau khi hoàn thành:
- review full diff;
- điền đủ acceptance checklist;
- ghi rõ direct-child-only limitation;
- ghi GitHub Actions là PENDING;
- đề xuất READY_FOR_REVIEW;
- dừng lại.
```

## Gate to TASK-0.3

TASK-0.3 chỉ được mở khi:

- report TASK-0.2 đầy đủ;
- diff đúng phạm vi;
- overload mới thực sự có deadline/cap;
- timeout return bounded;
- không zombie direct child trong normal timeout path;
- legacy API không bị đổi policy ngoài ý muốn;
- GitHub Actions build thành công;
- coordinator review chấp nhận.
