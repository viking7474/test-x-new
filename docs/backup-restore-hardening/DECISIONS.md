# Decision Log

Tài liệu này ghi các quyết định đã chốt trong quá trình triển khai. Agent không được tự thay đổi quyết định đã chốt; mọi đề xuất thay đổi phải ghi trong report để coordinator review.

## D-001 — One task at a time

- Status: Accepted
- Decision: Chỉ một task được mở tại mỗi thời điểm.
- Reason: Giảm phạm vi diff và xác định chính xác nguyên nhân khi build/runtime thất bại.

## D-002 — GitHub Actions is the build gate

- Status: Accepted
- Decision: Chủ dự án tự chạy build bằng GitHub Actions và gửi kết quả lại.
- Reason: Môi trường hiện tại không được xem là nguồn xác nhận build cuối cùng.

## D-003 — Separate task specification and agent report

- Status: Accepted
- Decision: Agent không sửa task specification để mô tả kết quả. Kết quả phải nằm trong file `reports/TASK-x.y-REPORT.md`.
- Reason: Giữ nguyên yêu cầu ban đầu để có thể đối chiếu với diff và report.

## D-004 — No automatic progression

- Status: Accepted
- Decision: Agent phải dừng sau task hiện tại. Task kế tiếp chỉ được tạo hoặc mở sau review và build gate.
- Reason: Ngăn thay đổi dây chuyền khi nền tảng trước chưa ổn định.

## D-005 — Compatibility before migration

- Status: Accepted
- Decision: Các API mới phải được thêm theo hướng tương thích trước; caller chỉ migrate trong task chuyên biệt.
- Reason: Tránh vừa đổi contract vừa đổi behavior trong cùng một diff.

## D-006 — Build success is necessary but not sufficient

- Status: Accepted
- Decision: Build xanh không tự động đồng nghĩa task hoàn thành. Vẫn cần review scope, contract và safety behavior.
- Reason: Nhiều regression destructive vẫn có thể compile thành công.

## D-007 — Deadline API is opt-in until process-group hardening

- Status: Accepted
- Decision: TASK-0.2 thêm overload deadline/output-cap thật nhưng không áp policy mới cho `runAndCapture:` legacy và không migrate caller.
- Reason: Trước TASK-0.3, timeout chỉ có thể terminate direct child PID; áp mặc định cho shell command hiện tại có thể để lại pipeline/background descendant.

## D-008 — Output limit is per stream and must keep draining

- Status: Accepted
- Decision: `maxOutputBytes` giới hạn riêng stdout và stderr. Khi đạt cap, runner tiếp tục đọc rồi discard để child không block vì pipe đầy.
- Reason: Dừng đọc sau cap sẽ biến cơ chế bảo vệ bộ nhớ thành một deadlock mới.

## D-009 — Timeout is a dedicated result state

- Status: Accepted
- Decision: Timeout thành công về mặt runner được biểu diễn bằng `timedOut = YES`, không dùng synthetic exit code và không tự động gán `runnerError = ETIMEDOUT`.
- Reason: Phân biệt deadline policy với child exit, spawn failure và runner failure.

## D-010 — Deadlines and duration use monotonic time

- Status: Accepted
- Decision: Deadline và `duration` phải dùng monotonic clock; không dùng wall clock hoặc `NSDate`.
- Reason: Thay đổi giờ hệ thống, timezone hoặc clock synchronization không được kéo dài hay rút ngắn command deadline.
