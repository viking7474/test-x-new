# TASK-0.1 Agent Report

## Metadata

```text
Task ID: TASK-0.1
Task title: Stabilize CommandResult Contract
Task specification: docs/backup-restore-hardening/tasks/TASK-0.1-command-result-contract.md
Agent: GPT-5.6 Thinking
Started at: 2026-07-13 (Asia/Ho_Chi_Minh)
Finished at: 2026-07-13 (Asia/Ho_Chi_Minh)
Suggested status: READY_FOR_REVIEW
Commit hash: chưa commit
```

## 1. Summary

Đã chuẩn hóa `CommandResult` thành contract có cấu trúc cho spawn failure, runner/setup failure, normal exit và signal termination, đồng thời giữ nguyên ba property cũ cùng hai API `run:` và `runAndCapture:`.

Mọi instance `CommandResult` hiện đi qua một initialization path duy nhất. `waitpid` được retry khi gặp `EINTR`, và các wait macro chỉ được đọc sau khi xác nhận `waitpid` thành công. Không sửa caller, không thêm timeout API và không thay đổi `/bin/sh -c` hoặc synchronous execution behavior.

## 2. Files Changed

| File | Change | Why required |
|---|---|---|
| `CommandRunner.h` | Bổ sung structured result properties và readonly `succeeded`. | Công khai contract bắt buộc của TASK-0.1 trong khi giữ nguyên API/property cũ. |
| `CommandRunner.m` | Thêm initialization path, `isSucceeded`, structured error/exit mapping, checked setup operations và checked `waitpid`. | Triển khai contract cho cả `run:` và `runAndCapture:`. |
| `docs/backup-restore-hardening/reports/TASK-0.1-REPORT.md` | Tạo agent report. | Report bắt buộc của task. |

Không sửa file code nào ngoài `Allowed files`. Thư mục `docs/` đã ở trạng thái untracked trước khi bắt đầu; trong task này chỉ tạo report được yêu cầu và không sửa README, STATUS, DECISIONS, template hoặc task specification.

## 3. Contract Changes

### API/property được thêm

```objc
@property (nonatomic, assign) int spawnError;
@property (nonatomic, assign) int runnerError;
@property (nonatomic, assign) int terminationSignal;
@property (nonatomic, assign) BOOL exitedNormally;
@property (nonatomic, assign) BOOL timedOut;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) BOOL stdoutTruncated;
@property (nonatomic, assign) BOOL stderrTruncated;
@property (nonatomic, readonly, getter=isSucceeded) BOOL succeeded;
```

### API/property giữ nguyên

```objc
@property (nonatomic, assign) int exitCode;
@property (nonatomic, copy) NSString *stdoutString;
@property (nonatomic, copy) NSString *stderrString;

- (CommandResult *)run:(NSString *)command;
- (CommandResult *)runAndCapture:(NSString *)command;
```

### Semantics trước và sau

- Spawn failure trước đây đặt `exitCode = spawnStatus`; hiện đặt `spawnError = spawnStatus`, giữ `exitCode = -1`, `exitedNormally = NO` và `terminationSignal = 0`.
- Child exit bình thường đặt `exitedNormally = YES`, giữ nguyên exact child exit code trong `exitCode`, và đặt `terminationSignal = 0`.
- Child bị signal đặt `terminationSignal = WTERMSIG(waitStatus)`, `exitedNormally = NO` và `exitCode = -1`.
- Setup/runner/wait failure đặt mã lỗi có nghĩa trong `runnerError`, giữ `exitCode = -1` và `exitedNormally = NO`.
- `timedOut`, `stdoutTruncated`, `stderrTruncated` được initialize thành `NO`; `duration` được initialize thành `0`. Task này không triển khai behavior tương ứng.
- `isSucceeded` chỉ trả về `YES` khi toàn bộ điều kiện contract đều đạt: không có spawn/runner error, child exit bình thường, không timeout, không signal và `exitCode == 0`.

Không có compatibility wrapper mới vì API hiện hữu được giữ nguyên trực tiếp. Không thay đổi call site.

## 4. Implementation Notes

### Initialization path

`CommandResult -init` thiết lập rõ ràng:

```text
exitCode = -1
stdoutString = empty string
stderrString = empty string
spawnError = 0
runnerError = 0
terminationSignal = 0
exitedNormally = NO
timedOut = NO
duration = 0
stdoutTruncated = NO
stderrTruncated = NO
```

Cả `run:` và `runAndCapture:` đều tạo result bằng `[[CommandResult alloc] init]` và không tự lặp lại default initialization.

### Error mapping

- `posix_spawn` failure được lưu trong `spawnError` bằng chính return code của `posix_spawn`.
- `pipe`, nonblocking `fcntl` và `posix_spawn_file_actions_*` setup failure được lưu trong `runnerError`.
- `select` hoặc `read` failure không phải `EINTR`/`EAGAIN` được lưu trong `runnerError`; error đầu tiên được giữ, trừ khi sau đó `waitpid` thất bại thì wait error được ưu tiên vì trạng thái kết thúc child không thể xác nhận.
- Setup failure đóng toàn bộ pipe/file descriptor đã mở trước khi return.

### Exit/signal/wait behavior

- `waitpid(pid, ..., 0)` được retry trong vòng lặp hẹp khi trả về `-1` với `errno == EINTR`.
- Nếu `waitpid` vẫn thất bại, `runnerError` nhận `errno` và không gọi `WIFEXITED`, `WIFSIGNALED`, `WEXITSTATUS` hoặc `WTERMSIG`.
- Nếu wait thành công nhưng status không thuộc normal-exit hoặc signal-exit, result được biểu diễn là runner observation failure với `runnerError = EINVAL`, `exitCode = -1`, `exitedNormally = NO`, `terminationSignal = 0`.

### Process/thread behavior

Không thay đổi `/bin/sh -c`, synchronous behavior hoặc command execution policy. Không thêm deadline, timeout parameter, output cap, process group hoặc argv API.

## 5. Acceptance Checklist

- [x] Giữ đủ ba property cũ.
- [x] Bổ sung đủ structured state properties.
- [x] Có initialization path thống nhất.
- [x] `isSucceeded` đúng contract.
- [x] `run:` map đúng spawn, normal exit, signal và wait failure.
- [x] `runAndCapture:` map đúng setup, spawn, normal exit, signal và wait failure.
- [x] Không dùng wait macros sau khi `waitpid` thất bại.
- [x] API cũ vẫn tồn tại.
- [x] Không sửa call site.
- [x] Không thêm timeout API giả.
- [x] Không thay đổi execution policy.
- [x] Không sửa Clear, Backup, Restore, Keychain hoặc UI.
- [x] Không có format-only churn ngoài vùng sửa.
- [x] Đã audit toàn bộ caller của `exitCode`.
- [x] Đã tạo report đúng đường dẫn.
- [x] Đã dừng sau TASK-0.1.

## 6. Verification Performed

| Check/command | Result | Evidence/notes |
|---|---|---|
| Required document/source inspection | PASS | Đã đọc README, STATUS, DECISIONS, task specification, report template, `CommandRunner.h` và `CommandRunner.m`. |
| Search toàn repo cho `exitCode` | PASS | Caller được audit: `AppDataBackupManager.m`, `AppDataCleaner.m`, `AppEntitlementsReader.m`, cùng implementation trong `CommandRunner.m`. |
| Caller dependency audit | PASS | Caller chỉ log/store `exitCode`, so sánh với `0`, hoặc trong một compatibility case đặt normal child `exitCode` về `0`; không caller nào so sánh hay phụ thuộc exact numeric `posix_spawn` status. |
| Search toàn repo cho `CommandResult` creation | PASS | Chỉ `CommandRunner.m` trực tiếp tạo `CommandResult`; caller nhận result từ API runner/helper và không có alternate initialization path. |
| Search field mới | PASS | `spawnError`, `runnerError`, `terminationSignal`, `exitedNormally`, truncation/timeout fields và `isSucceeded` chỉ xuất hiện trong `CommandRunner.h/.m`; không có call-site migration. |
| Review `waitpid`/wait macros | PASS | Chỉ một helper gọi `waitpid`; wait macros chỉ nằm trong helper apply status được gọi sau wait thành công. |
| `git diff --check -- CommandRunner.h CommandRunner.m` | PASS | Exit code `0`, không có whitespace error. |
| Local Objective-C syntax/build | NOT RUN | Workspace Windows không có `clang` hoặc `make`; full build thuộc GitHub Actions gate. |
| GitHub Actions build | PENDING | Workflow expected: `.github/workflows/build-ios-arm.yml`. |

### Caller list audited

- `AppDataBackupManager.m`: các nhánh log/report, tar create/extract, backup/restore/keychain checks và fallback checks sử dụng `exitCode == 0` hoặc `exitCode != 0`; một nhánh compatibility đổi `exitCode` thành `0` sau normal tar extraction warning. Không có exact spawn-error comparison.
- `AppDataCleaner.m`: signing và keychain wipe kiểm tra `exitCode != 0`, đồng thời lưu exit code vào debug report. Không có exact spawn-error comparison.
- `AppEntitlementsReader.m`: kiểm tra `exitCode != 0`. Không có exact spawn-error comparison.

## 7. Diff Review

- Có thay đổi ngoài task không? **Không.** Tracked code diff chỉ gồm `CommandRunner.h` và `CommandRunner.m`; report là file bắt buộc.
- Có format-only churn không? **Không.** Diff chỉ nằm ở declaration và implementation contract/error mapping.
- Có generated/binary file thay đổi không? **Không.**
- Có API cũ bị xóa không? **Không.**
- Có behavior thuộc task sau bị triển khai sớm không? **Không.** Không có total deadline, timeout API, output cap, process group hoặc argv API.

`git diff --stat -- CommandRunner.h CommandRunner.m`:

```text
 CommandRunner.h |   9 +++
 CommandRunner.m | 184 ++++++++++++++++++++++++++++++++++++++++++++------------
 2 files changed, 156 insertions(+), 37 deletions(-)
```

Các phần diff đáng chú ý:

- Thêm 9 property contract trong header.
- Thêm default initializer và `isSucceeded`.
- Tập trung wait handling vào helper retry `EINTR` và helper map status.
- Kiểm tra lỗi setup pipe/fcntl/file-actions và đóng resource trước khi return.
- Giữ nguyên kiến trúc capture đồng thời, shell invocation và synchronous API; chỉ bổ sung kiểm tra lỗi/retry `EINTR` cần thiết cho structured runner error mapping.

## 8. Safety Notes

- Task có thêm hoặc thay đổi destructive behavior không? **Không.**
- Task có thay đổi path resolution không? **Không.**
- Task có thay đổi Clear/Backup/Restore/Keychain behavior không? **Không sửa caller hoặc workflow nghiệp vụ.**
- Task có swallow error hoặc biến failure thành success không? **Không.** Các failure trước đây thiếu cấu trúc hiện được ghi vào `spawnError` hoặc `runnerError`; `isSucceeded` yêu cầu toàn bộ điều kiện thành công.

## 9. Not Changed

- Không sửa `AppDataBackupManager.m`.
- Không sửa `AppDataCleaner.m`.
- Không sửa `AppEntitlementsReader.m`.
- Không sửa keychain helper, UI hoặc bất kỳ caller nào.
- Không đổi `/bin/sh -c`.
- Không đổi synchronous execution.
- Không thêm timeout/deadline parameter hoặc timeout method.
- Không triển khai output cap/truncation behavior.
- Không triển khai process-group management.
- Không triển khai direct executable/argv API.
- Không đo duration thực tế trong task này.
- Không sửa `STATUS.md`, không đánh dấu task `COMPLETED`, không mở task tiếp theo.

## 10. Remaining Risks

- Chưa có local iOS/Theos compile vì workspace hiện tại thiếu `clang`, SDK và `make`; declaration/implementation compatibility cuối cùng phải được xác nhận bởi GitHub Actions.
- Caller hiện vẫn dùng legacy `exitCode` checks theo yêu cầu compatibility; structured fields chưa được caller tiêu thụ trong task này.
- `duration`, timeout và truncation flags mới chỉ có default state theo contract; behavior thật thuộc task sau.
- Capture loop vẫn không có total deadline/output cap/process-group handling, đúng phạm vi nhưng vẫn là rủi ro còn lại cho TASK-0.2/TASK-0.3.

## 11. GitHub Actions Handoff

```text
Build requested: YES
Workflow expected: .github/workflows/build-ios-arm.yml
Build result: PENDING
Build URL/run ID: PENDING
```

Agent dừng tại TASK-0.1. Suggested status: `READY_FOR_REVIEW`.
