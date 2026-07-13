# TASK-0.2 Coordinator Review

## Result

```text
Task: TASK-0.2 — Bounded Capture and Deterministic Deadline
Agent report: docs/backup-restore-hardening/reports/TASK-0.2-REPORT.md
Source reviewed: CommandRunner.h, CommandRunner.m
GitHub Actions: PASSED (reported by project owner)
Review decision: ACCEPTED
Final status: COMPLETED
```

## Scope review

- Public overload `runAndCapture:timeoutSec:maxOutputBytes:` được thêm đúng specification.
- Legacy `run:` và `runAndCapture:` vẫn tồn tại.
- Không caller nào được migrate.
- Không sửa Clear, Backup, Restore, Keychain hoặc UI.
- Không triển khai process group sớm.
- Code diff tập trung vào `CommandRunner.h/.m` và report bắt buộc.

## Contract review

- Deadline và duration dùng `CLOCK_MONOTONIC`.
- stdout/stderr có cap riêng và tiếp tục drain/discard sau cap.
- Capture engine dùng `waitpid(..., WNOHANG)` thay vì blocking wait trong overload bounded.
- Timeout được biểu diễn bằng `timedOut`, không dùng synthetic exit code.
- Partial output được giữ.
- Chuỗi direct-child termination có giới hạn thời gian.
- Validation failure không spawn child.

## Accepted limitations

- Timeout hiện chỉ signal direct `/bin/sh` PID.
- Pipeline hoặc background descendant có thể tiếp tục sống sau khi direct shell bị terminate.
- Legacy capture vẫn có thể chờ vô hạn vì chưa nhận deadline mặc định.
- Runtime timeout/process tests chưa được chạy trong workspace; GitHub Actions mới xác nhận compile/link.

Các limitation trên là phạm vi trực tiếp của TASK-0.3, không phải lý do giữ TASK-0.2 mở.

## Follow-up gate

TASK-0.3 phải:

- tạo process group ngay trong `posix_spawn`;
- chỉ bật policy này cho overload bounded;
- signal cả command group khi timeout;
- tránh `setpgid` sau spawn;
- tránh signal nhầm PGID sau khi direct child đã được reap;
- giữ API và caller hiện tại không đổi.
