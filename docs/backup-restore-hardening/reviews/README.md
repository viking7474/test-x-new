# Coordinator Reviews

Mỗi task đã qua agent handoff và GitHub Actions phải có một review riêng:

```text
TASK-x.y-REVIEW.md
```

Review ghi:

- agent report được đối chiếu;
- build result do project owner cung cấp;
- scope/contract/safety decision;
- remaining risks chuyển sang task sau;
- quyết định cuối: `ACCEPTED` hoặc `CHANGES_REQUESTED`.

Agent không được tạo hoặc sửa coordinator review.
