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
│   ├── TASK-0.6-bounded-output-query-helper.md
│   ├── TASK-0.7-bounded-direct-find-helpers.md
│   ├── TASK-1.1-immutable-resolved-container.md
│   ├── TASK-1.2-exact-application-data-container-resolver.md
│   ├── TASK-1.3-canonical-destructive-path-validator.md
│   ├── TASK-1.4-remove-application-bundle-writes.md
│   ├── TASK-1.5-typed-clear-request.md
│   ├── TASK-1.6-structured-clear-result.md
│   ├── TASK-1.7-migrate-main-application-data-clear.md
│   ├── TASK-1.8-migrate-extension-and-pluginkit-data-clear.md
│   ├── TASK-1.8A-restore-resolver-contract-and-report-gates.md
│   ├── TASK-1.9-migrate-app-group-clear.md
│   ├── TASK-1.10-integrate-keychain-clear-result.md
│   ├── TASK-1.11-remove-unsafe-permission-and-marker-behavior.md
│   ├── TASK-1.12-quarantine-ambiguous-legacy-clear-apis.md
│   ├── TASK-2.1-add-manifest-schema-validator.md
│   ├── TASK-2.2-enforce-supported-manifest-versions.md
│   ├── TASK-2.3-enforce-exact-restore-bundle-identity.md
│   ├── TASK-2.4-remove-recorded-destination-fallbacks.md
│   ├── TASK-2.5-add-common-artifact-verifier.md
│   ├── TASK-2.6-add-archive-entry-safety-validator.md
│   ├── TASK-2.6A-fix-archive-validator-compatibility-and-bounds.md
│   ├── TASK-2.7-build-immutable-restore-plan.md
│   ├── TASK-2.8-stage-and-validate-main-data.md
│   ├── TASK-2.9-stage-and-validate-app-groups.md
│   ├── TASK-2.10-stage-and-validate-optional-components.md
│   ├── TASK-2.11-transactional-main-data-commit-and-rollback.md
│   ├── TASK-2.11A-fix-pre-recovery-proof-and-durability.md
│   ├── TASK-2.12-transactional-app-group-commit-and-rollback.md
│   ├── TASK-2.13-transactional-optional-component-handling.md
│   ├── TASK-2.13A-fix-missing-directory-tree-verifier.md
│   └── TASK-2.14-add-structured-restore-result.md
|   |-- TASK-2.14A-fix-assertion-elided-result-state.md
|   |-- TASK-3.1-create-unique-partial-transaction-directory.md
|   |-- TASK-3.2-add-per-bundle-backup-serialization.md
|   |-- TASK-3.3-add-common-verified-artifact-writer.md
|   |-- TASK-3.4-derive-preferences-inclusion-from-verified-output.md
|   |-- TASK-3.5-define-required-and-optional-artifact-policy.md
|   |-- TASK-3.6-introduce-manifest-schema-v4.md
|   |-- TASK-3.6A-fix-v4-malformed-type-exception-safety.md
|   |-- TASK-3.7-write-and-validate-manifest-atomically.md
|   |-- TASK-3.8-publish-completed-backup-atomically.md
|   |-- TASK-3.8A-enforce-atomic-no-replace-directory-publication.md
|   |-- TASK-3.9-centralize-backup-failure-cleanup.md
|   |-- TASK-3.9A-make-cleanup-removal-race-safe.md
|   |-- TASK-3.10-harden-backup-discovery-and-stale-partial-cleanup.md
|   |-- TASK-3.10A-fix-top-level-name-classification-and-rollback-errors.md
|   |-- TASK-4.1-add-structured-keychain-helper-result.md
|   |-- TASK-4.2-define-reliable-keychain-helper-exit-codes.md
|   |-- TASK-4.3-remove-broad-pre-delete-from-keychain-restore.md
|   |-- TASK-4.4-define-exact-keychain-item-identity.md
├── reports/
│   ├── README.md
│   └── TASK-x.y-REPORT.md                 # agent tạo
├── reviews/
│   ├── TASK-1.10-REVIEW.md
│   ├── TASK-1.11-REVIEW.md
│   ├── TASK-1.12-REVIEW.md
│   ├── TASK-2.1-REVIEW.md
│   ├── TASK-2.2-REVIEW.md
│   ├── TASK-2.3-REVIEW.md
│   ├── TASK-2.4-REVIEW.md
│   ├── TASK-2.5-REVIEW.md
│   ├── TASK-2.6-REVIEW.md
│   ├── TASK-2.6A-REVIEW.md
│   ├── TASK-2.7-REVIEW.md
│   ├── TASK-2.8-REVIEW.md
│   ├── TASK-2.9-REVIEW.md
│   ├── TASK-2.10-REVIEW.md
│   ├── TASK-2.11-REVIEW.md
│   ├── TASK-2.11A-REVIEW.md
│   ├── TASK-2.12-REVIEW.md
│   ├── TASK-2.13-REVIEW.md
│   ├── TASK-2.13A-REVIEW.md
|   |-- TASK-2.14-REVIEW.md
|   |-- TASK-2.14A-REVIEW.md
|   |-- TASK-3.1-REVIEW.md
|   |-- TASK-3.2-REVIEW.md
|   |-- TASK-3.3-REVIEW.md
|   |-- TASK-3.4-REVIEW.md
|   |-- TASK-3.5-REVIEW.md
|   |-- TASK-3.6-REVIEW.md
|   |-- TASK-3.6A-REVIEW.md
|   |-- TASK-3.7-REVIEW.md
|   |-- TASK-3.8-REVIEW.md
|   |-- TASK-3.8A-REVIEW.md
|   |-- TASK-3.9-REVIEW.md
|   |-- TASK-3.9A-REVIEW.md
|   |-- TASK-3.10-REVIEW.md
|   |-- TASK-3.10A-REVIEW.md
|   |-- TASK-4.1-REVIEW.md
|   |-- TASK-4.2-REVIEW.md
|   |-- TASK-4.3-REVIEW.md
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
