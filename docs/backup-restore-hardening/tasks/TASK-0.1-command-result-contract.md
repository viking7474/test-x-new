# TASK-0.1 — Stabilize CommandResult Contract

## Metadata

- Phase: Phase 0 — Reliable Command Execution
- Status: READY
- Dependencies: none
- Required report: `docs/backup-restore-hardening/reports/TASK-0.1-REPORT.md`
- Build gate: GitHub Actions by project owner
- Suggested commit: `phase0(task-0.1): stabilize CommandResult contract`

## Objective

Chuẩn hóa `CommandResult` để biểu diễn riêng biệt lỗi khởi chạy, lỗi nội bộ của runner, process kết thúc bình thường và process kết thúc bởi signal. Task này không triển khai timeout, output limit hoặc thay đổi nghiệp vụ của caller.

## Required reading

Agent phải đọc:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. `docs/backup-restore-hardening/DECISIONS.md`
4. File task này
5. `CommandRunner.h`
6. `CommandRunner.m`
7. Tất cả call site đọc `CommandResult.exitCode`

## Allowed files

Chỉ sửa:

- `CommandRunner.h`
- `CommandRunner.m`

Sau đó tạo report:

- `docs/backup-restore-hardening/reports/TASK-0.1-REPORT.md`

Nếu cần sửa file khác để compile, không tự mở rộng phạm vi. Ghi rõ lý do và dừng để review.

## Current source facts

- `CommandResult` hiện có `exitCode`, `stdoutString`, `stderrString`.
- Spawn failure hiện đang được ghi vào `exitCode`.
- Signal kết thúc process hiện chưa được lưu.
- Một số setup/wait failure chưa có field có cấu trúc.
- Audit ban đầu cho thấy caller chủ yếu so sánh `exitCode` với 0 hoặc ghi log. Agent phải xác minh lại và báo cáo.

## Required contract

Giữ nguyên:

```objc
@property (nonatomic, assign) int exitCode;
@property (nonatomic, copy) NSString *stdoutString;
@property (nonatomic, copy) NSString *stderrString;
```

Bổ sung:

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

Semantics:

- `spawnError`: mã lỗi do `posix_spawn` trả về.
- `runnerError`: lỗi setup hoặc lỗi quan sát process của command runner; không chứa child exit code.
- `terminationSignal`: signal kết thúc child khi trạng thái wait cho biết child bị signal.
- `exitedNormally`: chỉ true khi child exit bình thường.
- `timedOut`, `stdoutTruncated`, `stderrTruncated`: được initialize nhưng vẫn false trong task này.
- `duration`: được initialize rõ ràng; đo duration thật không bắt buộc trong task này.

`succeeded` chỉ true khi:

```text
spawnError == 0
runnerError == 0
exitedNormally == YES
timedOut == NO
terminationSignal == 0
exitCode == 0
```

## Default initialization

Mọi `CommandResult` phải dùng một initialization path thống nhất với các giá trị:

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

Không phụ thuộc vào zero-initialization ngầm cho contract công khai.

## State mapping

### Spawn failure

- `spawnError = spawnStatus`
- `runnerError = 0`
- `exitCode = -1`
- `exitedNormally = NO`
- `terminationSignal = 0`

### Normal child exit

- `spawnError = 0`
- `runnerError = 0`
- `exitedNormally = YES`
- `exitCode = WEXITSTATUS(waitStatus)`
- `terminationSignal = 0`

### Child terminated by signal

- `spawnError = 0`
- `runnerError = 0`
- `exitedNormally = NO`
- `exitCode = -1`
- `terminationSignal = WTERMSIG(waitStatus)`

### Runner/setup failure

Khi pipe setup hoặc thao tác nội bộ bắt buộc thất bại:

- `runnerError` nhận mã lỗi có nghĩa.
- `exitCode = -1`.
- `exitedNormally = NO`.
- Resource đã mở phải được đóng.

### waitpid failure

Agent phải kiểm tra return value của `waitpid` trước khi dùng wait macros.

- Retry khi bị gián đoạn bởi signal theo cách nhỏ và tập trung.
- Nếu wait vẫn thất bại, lưu lỗi vào `runnerError`.
- Không đọc `WIFEXITED`, `WIFSIGNALED`, `WEXITSTATUS` hoặc `WTERMSIG` từ wait status không hợp lệ.

Agent phải ghi trong report cách xử lý trạng thái wait bất thường không thuộc normal-exit hoặc signal-exit.

## Compatibility requirements

- Giữ nguyên `run:` và `runAndCapture:`.
- Không sửa call site.
- Không đổi `/bin/sh -c`.
- Không đổi synchronous behavior.
- Không thêm exception.
- Không đổi exit code của child khi child exit bình thường.
- Spawn failure được chuyển từ `exitCode = spawnStatus` sang `spawnError = spawnStatus` và `exitCode = -1`.
- Agent phải xác nhận không có caller phụ thuộc vào exact numeric spawn status.
- Không thêm method timeout placeholder. API timeout thật thuộc TASK-0.2.

## Out of scope

Không triển khai trong task này:

- total deadline hoặc timeout parameter;
- output byte cap;
- process-group management;
- direct executable/argv API;
- caller migration;
- thay đổi AppDataCleaner;
- thay đổi AppDataBackupManager;
- thay đổi keychain helper;
- thay đổi UI;
- thay đổi behavior Clear, Backup hoặc Restore;
- unrelated formatting cleanup.

## Acceptance criteria

Agent phải sao chép checklist này vào report:

- [ ] Giữ đủ ba property cũ.
- [ ] Bổ sung đủ structured state properties.
- [ ] Có initialization path thống nhất.
- [ ] `isSucceeded` đúng contract.
- [ ] `run:` map đúng spawn, normal exit, signal và wait failure.
- [ ] `runAndCapture:` map đúng setup, spawn, normal exit, signal và wait failure.
- [ ] Không dùng wait macros sau khi `waitpid` thất bại.
- [ ] API cũ vẫn tồn tại.
- [ ] Không sửa call site.
- [ ] Không thêm timeout API giả.
- [ ] Không thay đổi execution policy.
- [ ] Không sửa Clear, Backup, Restore, Keychain hoặc UI.
- [ ] Không có format-only churn ngoài vùng sửa.
- [ ] Đã audit toàn bộ caller của `exitCode`.
- [ ] Đã tạo report đúng đường dẫn.
- [ ] Đã dừng sau TASK-0.1.

## Required verification

Agent phải:

1. Search toàn repo cho `exitCode` usage.
2. Xác nhận task không tạo call site mới dùng field mới.
3. Review mọi nơi tạo `CommandResult`.
4. Review mapping exit và signal.
5. Review return value của `waitpid`.
6. Chạy static/syntax checks khả dụng.
7. Chạy `git diff --check`.
8. Review `git diff --stat` và full diff.

Build đầy đủ do chủ dự án chạy bằng workflow `.github/workflows/build-ios-arm.yml`.

Agent không được tuyên bố build thành công khi chưa có kết quả GitHub Actions.

## Required report

Tạo `docs/backup-restore-hardening/reports/TASK-0.1-REPORT.md` theo template `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`.

Report bắt buộc nêu:

- danh sách caller đã audit;
- caller có phụ thuộc exact spawn error trong `exitCode` hay không;
- cách xử lý interrupted wait;
- cách biểu diễn wait state bất thường;
- file ngoài phạm vi có bị sửa hay không;
- GitHub Actions là `PENDING`.

## Agent handoff prompt

```text
Thực hiện duy nhất TASK-0.1 theo file:
docs/backup-restore-hardening/tasks/TASK-0.1-command-result-contract.md

Đọc README.md, STATUS.md, DECISIONS.md và report template trước khi sửa code.

Chỉ sửa CommandRunner.h và CommandRunner.m, sau đó tạo report TASK-0.1-REPORT.md.

Không sửa caller. Không triển khai timeout, output cap, process-group management, argv API hoặc task tiếp theo.

Sau khi hoàn thành, tự review full diff, điền đủ acceptance checklist, ghi GitHub Actions là PENDING, đề xuất READY_FOR_REVIEW và dừng lại.
```

## Gate to TASK-0.2

TASK-0.2 chỉ được mở sau khi:

- report đầy đủ;
- diff đúng scope;
- GitHub Actions build thành công;
- không có API mismatch;
- coordinator xác nhận TASK-0.1 hoàn thành.
