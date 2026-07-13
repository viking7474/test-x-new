# TASK-x.y Agent Report

> Agent phải sao chép template này sang đúng report path được chỉ định trong task. Không sửa task specification để thay thế report.

## Metadata

```text
Task ID:
Task title:
Task specification:
Agent:
Started at:
Finished at:
Suggested status: READY_FOR_REVIEW
Commit hash: chưa commit / <hash>
```

## 1. Summary

Mô tả ngắn gọn thay đổi đã thực hiện và kết quả chính.

## 2. Files Changed

| File | Change | Why required |
|---|---|---|
| | | |

Nếu sửa file ngoài `Allowed files`, phải ghi rõ lý do compile bắt buộc. Việc sửa ngoài phạm vi không được tự xem là hợp lệ.

## 3. Contract Changes

Ghi rõ:

- API/property được thêm.
- API/property giữ nguyên.
- Semantics trước và sau.
- Compatibility wrapper nếu có.
- Call site có bị thay đổi hay không.

## 4. Implementation Notes

Mô tả các quyết định triển khai quan trọng, đặc biệt:

- initialization path;
- error mapping;
- exit/signal behavior;
- resource cleanup;
- thread/process behavior nếu liên quan.

## 5. Acceptance Checklist

Sao chép toàn bộ acceptance criteria từ task và đánh dấu từng mục:

```text
- [x] Passed
- [ ] Not passed — explanation
- [ ] Not applicable — explanation
```

Không được bỏ qua tiêu chí chưa đạt.

## 6. Verification Performed

| Check/command | Result | Evidence/notes |
|---|---|---|
| Source inspection | | |
| Static search | | |
| Local syntax/build check | | |

Nếu không thể chạy build đầy đủ, ghi rõ `Not run; GitHub Actions is the build gate`.

## 7. Diff Review

Agent phải tự kiểm tra và báo:

- Có thay đổi ngoài task không?
- Có format-only churn không?
- Có generated/binary file thay đổi không?
- Có API cũ bị xóa không?
- Có behavior thuộc task sau bị triển khai sớm không?

Liệt kê output tóm tắt của `git diff --stat` và các phần diff đáng chú ý.

## 8. Safety Notes

Trả lời rõ:

- Task có thêm hoặc thay đổi destructive behavior không?
- Task có thay đổi path resolution không?
- Task có thay đổi Clear/Backup/Restore/Keychain behavior không?
- Task có swallow error hoặc biến failure thành success không?

## 9. Not Changed

Liệt kê các phần cố ý không thay đổi để chứng minh agent giữ đúng scope.

## 10. Remaining Risks

Liệt kê rủi ro còn lại, dependency cho task sau và điều chưa thể xác minh nếu chưa chạy trên thiết bị.

## 11. GitHub Actions Handoff

```text
Build requested: YES
Workflow expected: .github/workflows/build-ios-arm.yml
Build result: PENDING
Build URL/run ID: PENDING
```

Agent phải dừng ở đây. Không bắt đầu task kế tiếp.

## 12. Build Failure Follow-up

Chỉ bổ sung phần này nếu chủ dự án báo GitHub Actions thất bại.

```text
Failure summary:
Relevant log excerpt:
Root cause:
Files changed for fix:
Why fix remains inside current task:
Verification after fix:
New commit hash:
```
