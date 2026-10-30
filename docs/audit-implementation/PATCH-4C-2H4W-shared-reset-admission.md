# 4C.2H4W — Shared admission for live Reset controllers

Ngày 2026-10-29. Người dùng xác nhận H4V build pass trước bước này.

Follow-up: người dùng xác nhận H4W build pass ngày 2026-10-29. H4X tiếp tục standalone
publication boundary của settings/scope save helpers; xem
[báo cáo H4X](PATCH-4C-2H4X-standalone-settings-saves.md).

## Finding

Confirmed cross-controller admission gap, severity High/P1, tại
`beginDashboardResetInPhase:`. H4M chỉ kiểm tra `self.dashboardResetToken`, nên hai
controller còn sống có thể cùng bắt đầu backup/filter sync/clear. Gate của
ProfileManager bắt đầu ở create, sau các destructive service submissions này.
H4V cho released owner ngừng callback nhưng không chặn hai owner cùng còn sống.

Reproduce bằng tạo hai controller, bắt đầu Reset hoặc Save RRS Then Reset ở A,
giữ completion pending, rồi gọi một trong hai entry points ở B. Trước H4W, cả hai
có token riêng và có thể gửi work chồng nhau. Source/profile/scope là shared state;
không thể dùng per-controller once guard để bảo đảm một UI Reset đang chạy.
Không claim đã quan sát race này trên device hay mọi overlap đều gây mất dữ liệu.

## Implementation

Thêm Foundation-only `PXDashboardResetAdmission.h/.m` với ba C entry points:
begin, matches và finish. State gồm một weak owner và một strong identity token
không có owner back-reference. Tất cả operations chỉ chạy trên main; off-main
reject trước khi đọc/ghi shared state, không tự dispatch hoặc chờ lock.

- Begin từ chối khi đang có owner còn sống, kể cả same owner. Owner đã dealloc
  được reclaim ở begin kế tiếp, không giữ view graph chỉ để giữ admission.
- Matches yêu cầu đúng owner và token pointer; finish sai owner/token hoặc stale
  token không ảnh hưởng đến owner mới. Successful finish là one-shot.
- UI validate/detach input như trước rồi acquire shared admission trước HUD,
  scope/filter, backup hay clear. Contender nhận thông báo chờ Reset hiện tại;
  không có local token/input state hoặc service submission mới.
- Advance và per-app phase checks yêu cầu cả local state lẫn shared admission.
  Giữ admission qua create/switch/apply và scheduled restart. Các terminal paths
  hiện tại release qua finish, gồm restart finally và failure paths.
- Finish có thể dọn stale local state nhưng shared release vẫn identity-checked,
  nên không nhả admission của controller khác. Release trước khi nil local token
  để token còn có owner trong lúc kiểm tra.

Không đổi service options, captured app/note/hardware requests, artifact generation,
selection/source transactions, restart delay, generic backup/restore hay hot hooks.
Không giữ source/lifecycle/file lock xuyên service callbacks.

## Limits và behavior

Thay đổi cần thiết: một controller còn sống đang Reset sẽ chặn controller khác
bắt đầu Reset trong cùng app process. Existing single-owner flow và generic
nil-token backups không acquire gate này; generic operations vẫn có policy cũ.

Đây là UI admission, không phải lock toàn bộ submitted service jobs. Khi UI owner
dealloc, H4V loại late UI callbacks và H4W cho owner mới acquire; service đã submit
từ owner cũ vẫn có thể đang chạy. Không claim serialize orphaned jobs, generic
restore/backup, command-line writers hoặc process khác. Không rollback/cancel work.
Cross-operation service coordination và target capture vẫn cần protocol riêng.

Nếu callback không bao giờ đến nhưng controller vẫn có external owner, admission
vẫn bận như local Reset đang pending. Không thêm timeout/retry giả định worker đã
dừng; missing-callback recovery vẫn pending. Không cancel do view tạm disappear.

## Cost, memory và threading

Begin/matches/finish chỉ có main-thread check, identity comparisons và một token
allocation khi acquire thành công. Expected relative cost negligible, chưa benchmark;
không thêm I/O, IPC, notification, timer, busy polling hay synchronization primitive.
Existing main serialization là thread-safety boundary, không truy cập state off-main.

Owner zeroing weak không giữ controller; token bare NSObject không giữ request/UI.
Sau deallocation có thể còn một stale token đến begin kế tiếp, bounded một object,
không tăng theo số request và không giữ view graph. Explicit finish release ngay.
H4V weak callback semantics giữ nguyên; admission không tạo retain cycle mới.

## Verification

Native profile recipe link real coordinator implementation và import header trong
fixture; AST guard kiểm tra source thật nằm trong native compile list. Production
Makefile app/tweak đã dùng common wildcard. Không thêm framework; RootHide-defined
và rootful lanes giữ ba executions/lane. Extraction giữ 53 ProfileManager + Profile
model + 28 actual UI methods; group fixture giữ 43 IdentifierManager methods.

Fixture thêm:

- One live owner, same/different contender, nil inputs, wrong owner/token, stale
  release, one-shot release và off-main rejection không mutate owner hiện tại.
- Weak owner deallocation/reclaim và stale token không revoke owner mới.
- Hai live controllers, cả bốn combinations của hai Reset buttons: contender không
  HUD/filter/backup/clear; terminal release cho controller khác admit.
- Giữ admission qua pending create/switch và delayed restart; restart finally mở
  admission, replay của owner cũ không ảnh hưởng owner mới.
- Controlled revocation: phase guard chặn local state đã mất shared admission và
  stale local finish không release another owner.
- Owner dealloc cho UI run mới, late callback owner cũ không submit profile hoặc
  release token mới. Submitted service cancellation không được mô phỏng/claim.

Windows local: 62/63 Python suites + 4/4 Node pass; bridge-shell vẫn lỗi quyền
`mkdir /c/Users/ADMIN: Permission denied`. Exact extraction, CHECK macro arity,
negative source controls, source hardening, RootHide package/build static và diff
checks pass. MacOS Foundation/native concurrency/deallocation, actual UIKit,
services, Theos/package và device H4W còn chờ CI.

Manifest `4C.2H4W-partial`. Whole Reset/defaults/cache authority/durability,
orphaned service overlap, missing callbacks và backup/metadata target capture vẫn
partial. Patch 5–8 chưa triển khai.
