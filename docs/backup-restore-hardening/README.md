# Backup / Restore Hardening — Agent Workflow

Tài liệu này quản lý quá trình ổn định các luồng Clear Data, Backup, Restore và Keychain theo từng task nhỏ, độc lập và có build gate.

## Nguyên tắc chính

- Mỗi thời điểm chỉ có **một task được phép triển khai**.
- Mỗi task có một file Markdown riêng trong `tasks/`.
- Agent không được tự chuyển sang task kế tiếp.
- Agent không được thay đổi nội dung task specification sau khi bắt đầu.
- Sau khi hoàn thành code, agent phải tạo report riêng trong `reports/`.
- Chủ dự án tự build bằng GitHub Actions.
- Task chỉ được xem là hoàn thành sau khi:
  1. Agent report đầy đủ.
  2. Diff được review.
  3. GitHub Actions build thành công.
  4. Không có regression hoặc thay đổi ngoài phạm vi.
- Nếu build thất bại, chỉ sửa task hiện tại. Không mở task mới.

## Cấu trúc thư mục

```text
docs/backup-restore-hardening/
├── README.md
├── ROADMAP.md
├── STATUS.md
├── DECISIONS.md
├── tasks/
│   ├── TASK-0.1-command-result-contract.md
│   ├── TASK-0.2-bounded-capture-deadline.md
│   ├── TASK-0.3-spawn-process-group-termination.md
│   ├── TASK-0.4-direct-executable-argv-api.md
│   ├── TASK-0.5-app-data-cleaner-command-result-wrapper.md
│   └── TASK-0.6-bounded-output-query-helper.md
├── reports/
│   ├── README.md
│   └── TASK-x.y-REPORT.md                 # agent tạo
├── reviews/
│   └── TASK-x.y-REVIEW.md                 # coordinator tạo sau review/build
└── templates/
    └── AGENT_REPORT_TEMPLATE.md
```

## Trạng thái task

Các trạng thái hợp lệ:

```text
DRAFT
READY
IN_PROGRESS
READY_FOR_REVIEW
BUILD_FAILED
CHANGES_REQUESTED
BUILD_PASSED
COMPLETED
BLOCKED
```

Ý nghĩa:

- `READY`: task đã được duyệt và có thể giao agent.
- `IN_PROGRESS`: agent đang triển khai.
- `READY_FOR_REVIEW`: agent đã hoàn thành code và report, chưa có kết quả build.
- `BUILD_FAILED`: GitHub Actions thất bại; chỉ được sửa trong phạm vi task hiện tại.
- `CHANGES_REQUESTED`: review phát hiện sai scope, thiếu acceptance hoặc regression.
- `BUILD_PASSED`: GitHub Actions thành công, đang chờ xác nhận cuối.
- `COMPLETED`: task đã qua review và build gate.
- `BLOCKED`: chưa thể tiếp tục do dependency hoặc quyết định chưa được chốt.

## Quy trình giao task

### Bước 1 — Coordinator mở task

Coordinator cập nhật `STATUS.md` và đặt task hiện tại thành `READY`.

### Bước 2 — Agent đọc tài liệu

Agent bắt buộc đọc:

1. `docs/backup-restore-hardening/README.md`
2. `docs/backup-restore-hardening/STATUS.md`
3. File task hiện tại được chỉ định trong `STATUS.md`
4. `docs/backup-restore-hardening/templates/AGENT_REPORT_TEMPLATE.md`

Không được tự chọn task khác.

### Bước 3 — Agent triển khai

Agent phải:

- chỉ sửa file nằm trong phạm vi;
- giữ compatibility được yêu cầu;
- không refactor ngoài phạm vi;
- không che lỗi để build qua;
- không triển khai trước task kế tiếp;
- kiểm tra toàn bộ diff trước khi kết thúc.

### Bước 4 — Agent tạo report

Agent tạo đúng đường dẫn được ghi trong task, ví dụ:

```text
docs/backup-restore-hardening/reports/TASK-0.1-REPORT.md
```

Agent không được ghi `COMPLETED`. Trạng thái cao nhất agent có thể đề xuất là `READY_FOR_REVIEW`.

### Bước 5 — Review và GitHub Actions

Chủ dự án gửi lại:

- report của agent;
- diff hoặc commit hash;
- kết quả GitHub Actions;
- log lỗi nếu build thất bại.

Coordinator review trước khi tạo task tiếp theo.

## Quy tắc khi build thất bại

- Giữ nguyên task ID.
- Report được bổ sung mục `Build Failure Follow-up`.
- Chỉ sửa nguyên nhân thuộc task hiện tại.
- Nếu lỗi nằm ngoài task, ghi rõ bằng chứng và dừng để review.
- Không dùng workaround làm thay đổi behavior chỉ để build xanh.

## Quy tắc commit

Khuyến nghị mỗi task một commit:

```text
phase0(task-0.1): stabilize CommandResult contract
```

Nếu phải sửa sau build failure, có thể dùng commit bổ sung nhưng không được gộp task kế tiếp.

## Quyền cập nhật tài liệu

- Agent được tạo và cập nhật file report của task hiện tại.
- Agent không được tự sửa acceptance criteria của task.
- Agent không được tự mở task mới.
- `STATUS.md`, `DECISIONS.md` và task specification do coordinator quản lý, trừ khi task yêu cầu rõ ràng khác.
