# Implementation Status

## Current Gate

```text
Program: Backup / Restore Hardening
Current phase: Phase 0 — Reliable Command Execution
Current task: TASK-0.2 — Bounded Capture and Deterministic Deadline
Task file: docs/backup-restore-hardening/tasks/TASK-0.2-bounded-capture-deadline.md
Expected report: docs/backup-restore-hardening/reports/TASK-0.2-REPORT.md
Status: READY
Build owner: Project owner via GitHub Actions
Next task: TASK-0.3 remains LOCKED
```

## Gate Rules

TASK-0.2 chỉ được chuyển thành `COMPLETED` khi đáp ứng đủ:

- [ ] Agent đã tạo report đúng template.
- [ ] Diff chỉ tập trung vào `CommandRunner.h/.m` và report.
- [ ] API legacy vẫn tồn tại.
- [ ] Không có caller migration.
- [ ] Overload mới có total monotonic deadline thật.
- [ ] stdout/stderr được giới hạn riêng theo byte.
- [ ] Runner tiếp tục drain/discard sau khi đạt cap.
- [ ] Timeout return bounded và không leave zombie direct child trong path bình thường.
- [ ] Không triển khai process group trước TASK-0.3.
- [ ] Không thay đổi Clear, Backup, Restore, Keychain hoặc UI.
- [ ] GitHub Actions build thành công.
- [ ] Build log không có lỗi declaration/implementation mismatch.
- [ ] Coordinator review và chấp nhận.

## Task History

| Task | Status | Agent report | Build | Review |
|---|---|---|---|---|
| TASK-0.1 | COMPLETED | `reports/TASK-0.1-REPORT.md` | PASSED | `reviews/TASK-0.1-REVIEW.md` — ACCEPTED |
| TASK-0.2 | READY | Chưa có | Chưa chạy | Chưa review |

## Blocked Work

Các task sau chưa được phép triển khai:

- TASK-0.3 — Spawn-time process-group setup và group termination.
- TASK-0.4 — Direct executable/argv API.
- TASK-0.5 — Compatibility result-returning wrapper trong `AppDataCleaner`.
- Tất cả task thuộc Phase 1 trở đi.

Agent không được tạo code cho task bị khóa trong diff của TASK-0.2.
