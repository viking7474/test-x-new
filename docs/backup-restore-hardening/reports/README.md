# Agent Reports

Mỗi task có một report riêng theo tên:

```text
TASK-x.y-REPORT.md
```

Report phải được tạo từ `../templates/AGENT_REPORT_TEMPLATE.md`.

Agent chỉ được tạo hoặc cập nhật report của task hiện tại. Không được dùng report để thay đổi acceptance criteria trong task specification.

Trạng thái cao nhất agent được đề xuất là `READY_FOR_REVIEW`. Build result do chủ dự án bổ sung sau khi chạy GitHub Actions.
