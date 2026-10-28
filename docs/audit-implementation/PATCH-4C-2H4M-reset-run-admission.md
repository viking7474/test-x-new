# 4C.2H4M — Reset run admission and phase callbacks

Ngày 2026-10-28. Người dùng xác nhận H4L build pass trước bước này.

## Findings

Confirmed missing admission, severity High, tại hai entry actions
`resetDataTapped` và `saveRRSThenResetTapped` trong `TLinkIOSViewController.m`.
Trước patch, gọi hai actions khi callback clear/backup còn pending tạo hai chains.
ProfileManager chỉ chặn create sau đó; nó không ngăn backup/clear đã chạy trước
create. HUD được show qua async dispatch nên không phải synchronization primitive.
Tác động có thể gồm repeated clear/backup I/O, tranh HUD, create failure muộn và
nhiều success/restart tails. Không đo tần suất double tap thực tế trên thiết bị.

Potential duplicate/stale phase callbacks, severity Medium: completion và delayed
restart không có run identity hoặc phase claim. Một callback terminal lặp có thể
tiếp tục cùng downstream chain; restart cũ không có guard để loại tác động vào run
mới. Services hiện tại thường đưa completion về main; entry actions và callback
boundaries vẫn cần contract rõ ràng.

Reproduce bằng controlled producer giữ terminal callback, gọi cả hai entry actions
liên tiếp, hoặc deliver cùng callback hai lần; giữ delayed restart cũ rồi admit run
mới trong fixture. Không clear hoặc restart thiết bị trong quá trình kiểm tra này.

## Implementation

Per-controller token và phase chỉ được admit/advance/finish trên main. Token dùng
object identity, không phải mutable options equality hoặc một counter có thể wrap.
Hai nút dùng cùng admission trước HUD và trước backup/clear. Off-main actions handoff
main bằng weak owner; overlapping tap trở thành no-op khi run còn giữ admission.

Phase boundaries:

`backup (optional) → clear → clearing → preparing → preflight → create → switch → apply → restart → restarting`

Backup/clear/create/switch completions handoff main rồi claim đúng expected phase
và token trước effects tiếp theo. First accepted terminal callback tiến phase;
duplicate hoặc callback thuộc token cũ không advance. Profile-preparation entry
claim preflight trước providers, giữ H4K failure gates và H4L detached intent.

Missing selections, backup-count mismatch, filter failure, request capture/provider/
allocation failure, create/switch/preparation failure release admission trước error
feedback. Success giữ token khi HUD đã ẩn và trong delay ba giây hiện có. Timer chỉ
restart nếu còn matching token/phase; finally release token khi restart method trả
về hoặc throws. Không thực hiện thêm respring, retry, timeout, timer hay polling.

Chưa đổi create → switch → enable → regenerate → preview policy, app clear result,
model/storage/counter behavior, scope filter diagnostics hoặc success notification.
RootHide bootstrap và package runtime giữ nguyên; code admission dùng chung hai
schemes. Không rollback các effects đã commit trước failure.

## Verification

Native profile fixture extract đúng bảy workflow methods mới, gồm full actions,
filter/clear orchestrator và profile-create/switch/restart tail. Tổng 53 manager
methods + Profile model + 16 controller methods. Controlled collaborators thay
backup/clear/profile producer, HUD/presentation, final Darwin notification và
delayed restart; không chạy destructive services hoặc real timer.

Cases thêm:

- Hai nút bị loại overlap từ clear tới delayed restart; retry chỉ sau terminal.
- Duplicate clear/create/switch callbacks từ background chạy một create, switch,
  apply, final notice và restart trên main.
- Old backup/clear/create/switch/timer callbacks và old finish không tác động run mới.
- Tám failure points: initial intent, missing preview, final provider snapshot,
  allocation, create, switch, generation và preview. Không success/persist/final
  notice/restart tail, admission được nhả để user retry.
- Missing RRS/reset selections, backup mismatch, duplicate successful backup và
  filter failure; later explicit reset vẫn admit được.
- Restart exception vẫn nhả đúng token; off-main public entries chỉ admit một run.

Đây là actual adapter bodies với Foundation collaborators, không phải full UIKit,
actual app-clearing, process-kill hoặc device acceptance. Native recipe giữ hai
lanes rootful/RootHide-defined, ba executions/lane, không thêm compile dependency.

Windows local: 62/63 Python suites và 4/4 Node pass; bridge-shell suite vẫn lỗi
`mkdir /c/Users/ADMIN: Permission denied`. Source hardening, RootHide build/package
static checks, exact extraction, CHECK macro arity và diff checks pass. Native
compile/runtime/Theos và UIKit/device H4M cần macOS CI/thiết bị xác nhận.

## Cost và remaining boundaries

Một token allocation và vài scalar/string checks trên cold run, expected negligible.
Main delivery thêm một queue turn tại các callback boundaries; latency phụ thuộc
main workload, chưa benchmark. Loại repeated clear/generation có thể tránh high I/O
trong duplicate workload; không claim cải thiện hot hook hoặc benchmark launch.

Admission thuộc một controller, không phải process-wide/cross-instance lock. Restore,
save-only RRS và actions khác chưa dùng token này. Token không pin active selection
qua source commits, không chụp full tap-time app lists/notes/options và không phải
daemon distribution acknowledgement. Callback identity chỉ bảo vệ phase boundaries;
per-app recursion bên trong backupApps/clearApps chưa được chuyển sang exactly-once
state machine.

Strong owner retention trong admitted operation vẫn là behavior cũ; token không giữ
back-reference. Không claim đã loại mọi retain cycle hoặc xử lý controller teardown.
Service không callback hoặc unexpected exception ngoài restart có thể giữ busy;
không tự timeout rồi admit destructive overlap. Crash recovery, cancellation và
cross-phase target pinning cần riêng. Whole Reset và toàn Patch 4 vẫn partial,
manifest `4C.2H4M-partial`; Patch 5–8 chưa triển khai.
