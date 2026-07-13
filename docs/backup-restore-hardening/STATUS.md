# Implementation Status

## Current Gate

```text
Program: Backup / Restore Hardening
Current phase: Phase 0 — Reliable Command Execution
Current task: TASK-0.3 — Spawn-Time Process Group and Group-Scoped Termination
Task file: docs/backup-restore-hardening/tasks/TASK-0.3-spawn-process-group-termination.md
Expected report: docs/backup-restore-hardening/reports/TASK-0.3-REPORT.md
Status: READY
Build owner: Project owner via GitHub Actions
Next task: TASK-0.4 remains LOCKED
```

## Gate Rules

TASK-0.3 chỉ được chuyển thành `COMPLETED` khi đáp ứng đủ:

- [ ] Agent tạo report đúng template.
- [ ] Chỉ sửa `CommandRunner.m` và report.
- [ ] Không thay đổi public API hoặc `CommandRunner.h`.
- [ ] Chỉ bounded overload bật process group.
- [ ] Process group được tạo bằng `POSIX_SPAWN_SETPGROUP` tại spawn time.
- [ ] Không có post-spawn `setpgid`.
- [ ] Owned PGID bằng spawned child PID và được validate trước signal.
- [ ] Timeout signal group bằng SIGTERM rồi SIGKILL.
- [ ] Final group signal xảy ra trước direct child reap.
- [ ] Group-enabled loop không reap leader khi descendant còn giữ capture pipe.
- [ ] Post-KILL direct-child reap có giới hạn.
- [ ] Legacy APIs và caller không đổi behavior.
- [ ] Không sửa Clear, Backup, Restore, Keychain hoặc UI.
- [ ] GitHub Actions build thành công.
- [ ] Coordinator review và chấp nhận.

## Task History

| Task | Status | Agent report | Build | Review |
|---|---|---|---|---|
| TASK-0.1 | COMPLETED | `reports/TASK-0.1-REPORT.md` | PASSED | `reviews/TASK-0.1-REVIEW.md` — ACCEPTED |
| TASK-0.2 | COMPLETED | `reports/TASK-0.2-REPORT.md` | PASSED | `reviews/TASK-0.2-REVIEW.md` — ACCEPTED |
| TASK-0.3 | READY | Chưa có | Chưa chạy | Chưa review |

## Blocked Work

Các task sau chưa được phép triển khai:

- TASK-0.4 — Direct executable/argv API.
- TASK-0.5 — Compatibility result-returning wrapper trong `AppDataCleaner`.
- Tất cả task thuộc Phase 1 trở đi.

Agent không được tạo code cho task bị khóa trong diff của TASK-0.3.
