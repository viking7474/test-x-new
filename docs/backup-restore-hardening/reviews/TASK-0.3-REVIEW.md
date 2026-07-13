# TASK-0.3 Coordinator Review

## Metadata

```text
Task: TASK-0.3 — Spawn-Time Process Group and Group-Scoped Termination
Agent report: docs/backup-restore-hardening/reports/TASK-0.3-REPORT.md
Reviewed source: CommandRunner.m
Reviewed commit: 3046fc3303d42e3f3e4ca8b9c683509d60a70edc
Build gate: reported completed by project owner
Decision: ACCEPTED
```

## Review Summary

TASK-0.3 được chấp nhận để làm dependency cho TASK-0.4.

Source đã thực hiện đúng các yêu cầu trọng yếu:

- chỉ bounded overload bật process group;
- process group được tạo tại spawn time bằng `POSIX_SPAWN_SETPGROUP` và pgroup `0`;
- không thêm post-spawn `setpgid` trong `CommandRunner`;
- PGID được lấy từ PID của direct child sau spawn thành công;
- negative-PGID signal có ownership validation;
- timeout gửi group `SIGTERM`, drain trong grace period, sau đó gửi final group `SIGKILL`;
- final group signal xảy ra trước direct-child/group-leader reap;
- bounded path dùng `waitpid(..., WNOHANG)` và bounded reap;
- partial output, output cap, truncation flags, duration và structured result được giữ;
- `CommandRunner.h` và caller không thay đổi.

## Compatibility Review

- `run:` giữ spawn attributes `NULL`.
- `runAndCapture:` legacy đặt `processGroupEnabled = NO`.
- Chỉ `runAndCapture:timeoutSec:maxOutputBytes:` đặt `processGroupEnabled = YES`.
- Không có caller migration.

## Remaining Risks Carried Forward

- Process cố ý escape process group bằng `setsid`, đổi group hoặc daemonization không thuộc contract.
- Runtime matrix pipeline/background descendant chưa được tự động hóa trong repo.
- Repo còn các `posix_spawn`/`setpgid` implementation khác ngoài `CommandRunner`; TASK-0.3 không thay đổi chúng.
- Caller hiện vẫn chủ yếu xây shell command string; direct argv API thuộc TASK-0.4.

## Gate Decision

```text
TASK-0.3: COMPLETED
TASK-0.4: may be opened
```
