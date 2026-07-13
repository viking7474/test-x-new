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

## D-011 — Process groups are created atomically at spawn time

- Status: Accepted
- Decision: Bounded command dùng `POSIX_SPAWN_SETPGROUP` với pgroup `0`; không dùng `setpgid` sau spawn.
- Reason: Post-spawn `setpgid` có race nơi child hoặc descendant chạy trước khi group ownership được thiết lập.

## D-012 — Process-group policy remains opt-in

- Status: Accepted
- Decision: Chỉ overload bounded bật process-group creation và group-scoped termination. `run:` và `runAndCapture:` legacy giữ nguyên policy.
- Reason: Thay đổi process group của API legacy có thể làm thay đổi signal/job-control semantics trước khi caller migration được review riêng.

## D-013 — Final group signal precedes leader reap

- Status: Accepted
- Decision: Trong timeout path, final group `SIGKILL` phải được gửi trước khi direct child/group leader được reap. Khi descendant còn giữ capture pipe, bounded loop defer direct-child reap.
- Reason: PGID bằng child PID. Reap leader quá sớm cho phép PID/PGID tái sử dụng, tạo nguy cơ signal nhầm process group khác.

## D-014 — Process-group termination is not process-tree enumeration

- Status: Accepted
- Decision: TASK-0.3 chỉ terminate process còn trong inherited command group; process cố ý escape bằng `setsid`, group khác hoặc daemonization nằm ngoài scope.
- Reason: Process-tree scanning/kill-by-name không đáng tin cậy, dễ tác động process không thuộc command và cần thiết kế riêng.

## D-015 — Direct execution is bounded-only

- Status: Accepted
- Decision: Public direct-executable API đầu tiên luôn yêu cầu `timeoutSec` và `maxOutputBytes`; không thêm unbounded direct convenience API trong TASK-0.4.
- Reason: API mới dành cho critical operations nên phải dùng deadline, bounded output và process-group cleanup ngay từ contract đầu tiên.

## D-016 — Direct API receives argv, not a command line

- Status: Accepted
- Decision: Caller truyền absolute executable path và `arguments` tương ứng `argv[1...]`; runner tự tạo `argv[0]`. Không shell parsing, quoting, PATH search hoặc argument joining.
- Reason: Tách data khỏi command syntax, tránh ambiguity và tạo nền tảng migration có thể kiểm chứng.

## D-017 — argv memory is owned and validated

- Status: Accepted
- Decision: Runner tạo owned lossless UTF-8 copies, reject embedded NUL/non-string input, kiểm tra overflow và cleanup partial allocation trên mọi path.
- Reason: Không dựa vào lifetime ngầm của `UTF8String` và không cho C argv bị truncate âm thầm tại embedded NUL.

## D-018 — Direct API inherits environment without changing shell compatibility

- Status: Accepted
- Decision: Direct executable API truyền current process environment bằng `environ`; shell APIs hiện hữu giữ environment-pointer behavior hiện tại trong TASK-0.4.
- Reason: Executable trực tiếp cần environment ổn định, nhưng thay đổi shell API hiện hữu phải được tránh trong task contract mới.

## D-019 — Contract before caller migration

- Status: Accepted
- Decision: TASK-0.4 chỉ thêm/refactor command-runner infrastructure; không chuyển `tar`, `ldid`, keychain helper hoặc destructive caller sang API mới.
- Reason: Tách API correctness khỏi thay đổi nghiệp vụ và giúp xác định regression theo từng task.

## D-020 — AppDataCleaner void APIs remain compatibility shims

- Status: Accepted
- Decision: TASK-0.5 giữ nguyên các selector `void` hiện tại và cho chúng delegate sang một private method trả `CommandResult`.
- Reason: Hàng trăm caller hiện không xử lý result; thay đồng thời signature và control flow sẽ làm diff quá rộng và khó xác định regression.

## D-021 — Cleaner shell wrapper uses bounded capture

- Status: Accepted
- Decision: Private result wrapper trong `AppDataCleaner` dùng bounded shell API với deadline hiện có và cap cố định 1 MiB cho từng stream.
- Reason: Các command hiện tại phụ thuộc shell syntax, nhưng vẫn cần deadline, bounded memory và spawn-time process-group cleanup từ `CommandRunner`.

## D-022 — Result availability precedes failure propagation

- Status: Accepted
- Decision: TASK-0.5 chỉ làm structured result khả dụng; existing Clear flow vẫn bỏ qua result và không thay đổi success/failure/UI decision.
- Reason: Failure propagation phải được thực hiện cùng typed Clear result và component policy trong Phase 1, không trộn vào compatibility migration.

## D-023 — Remaining launch paths must be inventoried

- Status: Accepted
- Decision: TASK-0.5 phải liệt kê mọi `posix_spawn`, `NSTask`, wait và process-launch path còn lại trong `AppDataCleaner.m`; coordinator quyết định có cần thêm Phase 0 task hay không.
- Reason: Hoàn thành một wrapper không đồng nghĩa toàn bộ file đã loại bỏ hang, unbounded output hoặc duplicate execution logic.
