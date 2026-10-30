# 4C.2H4V — Weak UI ownership for Reset callbacks

Ngày 2026-10-29. Người dùng xác nhận H4U build pass trước bước này.

## Finding

Confirmed extended ownership, severity Medium/P1, trong Reset callbacks tại
`saveRRSThenResetTapped`, `performResetAndPrepareNextProfileWithWarnings:`,
`createNextProfileAndRandomizeWithWarnings:` và token-aware backup/clear helpers.
Các service completion và main/timer blocks capture self mạnh. Backup/clear làm
việc async, ProfileManager giữ completion qua worker và restart chờ ba giây; những
block đó có thể trở thành owner cuối của cả controller/view graph.

Token/phase checks H4M/H4N ngăn duplicate/stale results nhưng không giải phóng
controller còn bị block giữ. Khi external UI ownership kết thúc, callback cũ vẫn
có thể tiếp tục tạo/switch/apply/restart vì controller chưa dealloc và token cũ vẫn
hợp lệ. Nếu service lâu hoặc không release callback, UI lifetime kéo dài theo nó.
Không khẳng định có permanent production retain cycle/leak trong mọi service;
đây là confirmed strong capture, còn thời gian giữ tùy producer và các owner khác.

Reproduce bằng giữ producer callback ngoài autoreleasepool, thả UI reference rồi
kiểm tra weak owner; hoặc thả owner khi chờ timer và thử callback sau đó. Native
fixture giữ callbacks để kiểm tra chính graph này, không dựa vào benchmark memory.

## Implementation

- Reset backup terminal và clear terminal callbacks chỉ capture weakSelf. Chỉ
  promote trên main trước khi kiểm tra token/phase và xử lý synchronous delivery.
- Create/switch completions, queued feedback và delayed restart có promotion riêng
  ở mỗi main boundary. Nested callback không capture promoted self của callback
  bên ngoài. Off-main creation bounce cũng weak.
- Per-app backup/clear helpers capture weak owner cho Reset token. `retainedOwner`
  chỉ nhận self khi token nil, giữ strong lifetime policy trước đây cho generic
  backup/clear callers. Off-main bounce áp dụng cùng policy.
- Main/once guard vẫn nhận mỗi per-app result đúng một lần. Owner mất thì return
  trước metadata/warnings, recursive next submission và terminal UI callback.
  Owner sống vẫn đi qua token/phase/expected-profile checks như trước.
- Không thêm class, public selector, observer, cancellation registry, queue, timer
  hoặc service/source dependency. Restart delay vẫn ba giây; live-owner flow giữ
  thứ tự, failure handling, snapshot intent và source acknowledgement hiện tại.

## Behavior boundary

Reset nay không được các callback của chính nó giữ sống UI owner vô thời hạn.
Khi controller thực sự dealloc, các late callbacks và timer còn lại không tạo
thêm phase, sửa RRS metadata, publish UI feedback hoặc yêu cầu restart.

Không cancel khi `viewDidDisappear`: modal/navigation có thể tạm che màn hình mà
controller vẫn có owner hợp lệ. Nếu controller vẫn còn được window/navigation hay
owner khác giữ, Reset tiếp tục như cũ. External completion tự capture UI mạnh vẫn
có thể giữ nó; patch không thể xóa ownership do caller khác tạo ra.

Đã submit backup/clear/create/switch thì producer vẫn có thể hoàn tất/commit dù
UI mất. Không rollback app clearing, source changes/profile activation; không xóa
backup hay directory tự động. Admitted synchronous delivery giữ strong owner đến
khi xử lý xong, không ngắt giữa một source operation. Request payload, warnings,
token/profile có thể còn do producer giữ đến khi callback được release.

Generic nil-token backup/clear vẫn giữ owner tới callback release và giao completion
như trước; không chuyển tất cả RRS operations sang implicit cancellation. Đây là
deallocation-based lifetime gating cho Reset, không phải process-wide admission,
visible-screen cancellation hay cancellation của submitted worker.

## Performance và memory

Memory impact có thể moderate nếu callback từng giữ controller/view/icon cache qua
backup lâu; không có số MB/benchmark để kết luận. Khi UI vẫn được navigation giữ,
không kỳ vọng giải phóng thêm view graph. Không còn forced retention chỉ để chờ
restart ba giây khi owner ngoài đã thả.

Thêm ARC weak store/load và transient strong promotion mỗi callback, expected cost
negligible so với service I/O. Không thêm dispatch, locks, polling hay timer so với
implementation trước. Dead-owner delivery vẫn dùng existing main queue rồi return;
không claim đã cancel transport hoặc ngăn mọi duplicate block được enqueue.
Zeroing weak tránh dangling object; strong local bảo vệ lifetime trong synchronous
delivery. Main-thread admission/phase/once assumptions H4M/H4N giữ nguyên.

## Verification

Native recipe vẫn extract 53 ProfileManager + Profile model + 28 actual UI methods;
group recipe giữ 43 IdentifierManager methods. Không thêm source/framework build
dependencies. Rootful và RootHide-defined vẫn chạy ba lần mỗi lane trong CI.

Native fixture thêm:

- External callbacks giữ qua UI pool: owner release tại backup, clear, create,
  switch và delayed restart; late/duplicate callbacks không tạo UI effects hoặc
  submit phase tiếp. Producer vẫn còn callback, chứng minh graph không giữ UI.
- Thả owner trong admitted persist: generation/notification đã xảy ra được giữ,
  queued feedback không giữ owner và không schedule restart sau release.
- Actual per-app backup/clear producer với pending và already-queued delivery;
  cả Reset terminal closure và per-app closure đều không giữ controller. Late
  duplicates không sửa metadata hoặc submit app tiếp.
- Generic nil-token vẫn giữ owner khi caller thả reference, deliver terminal một
  lần, rồi release khi producer bỏ callbacks.
- Worker enqueue rồi main chưa drain: off-main backup/clear/creation bounce không
  giữ owner hoặc submit service/profile sau release. Worker pool nhả local trước
  signal để không phụ thuộc race lúc worker callback kết thúc. Bounded wait chỉ
  thuộc fixture, không phải production blocking wait.

Existing duplicate/phase/selection/partial-failure cases vẫn giữ. Source guards
kiểm tra weak promotion ở từng boundary và explicit generic strong-owner policy.
Windows local: 62/63 Python suites + 4/4 Node pass; bridge-shell suite còn lỗi
`mkdir /c/Users/ADMIN: Permission denied` như trước. Extraction, CHECK macro arity,
source hardening, RootHide build/package static và diff checks pass.
Không có macOS/xcrun/Theos local: native deallocation/runtime, actual UIKit/service
ownership và package/device H4V còn chờ CI; source checks không chứng minh native
weak lifetime assertions đã pass.

Manifest `4C.2H4V-partial`; cross-instance overlap khi nhiều owner còn sống, missing
callbacks/admission timeout, service cancellation, backup/metadata target capture,
source/defaults/cache ordering và directory durability vẫn partial. Patch 5–8 chưa
triển khai.
