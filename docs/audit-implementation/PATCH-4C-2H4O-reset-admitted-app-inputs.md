# 4C.2H4O — Admitted Reset app lists and note

Ngày 2026-10-28. Người dùng xác nhận H4N build pass trước bước này.

## Findings

Confirmed live-input dependency, potential correctness edge case, severity Medium,
trong `TLinkIOSViewController.m`:

- Save RRS + Reset giữ shallow backup-array copy nhưng đọc reset selection sau
  backup; clear dùng mutable selection array. Replacement trước clear hoặc in-place
  array/string edits có thể làm một run dùng input khác với lúc được nhận.
- Backup callback đọc live note cho từng app. Hai backups trong cùng Reset có thể
  nhận hai notes nếu text đổi trong lúc chờ service.
- Filter sync đọc live selectedResetAppIDs riêng với clear. Hai bước chưa nhận cùng
  admitted packet; thiếu type validation trước thao tác với persisted list sai kiểu.

Reproduce bằng controlled pending backup, thay UI list/note hoặc mutate aliases rồi
deliver callback. Chưa đo tần suất trên thiết bị; HUD có thể chặn phần lớn thao tác
touch thông thường, không bảo vệ programmatic updates. Backup list và reset list
vốn là hai lựa chọn độc lập: patch không ép chúng bằng nhau.

## Implementation

Admission H4M capture `dashboardResetInputs` trên main trước token/HUD/service.
Packet gồm resetApps, backupApps và note; array container cùng từng NSString được
copy. Giữ order, duplicates, case và literal IDs, không trim/deduplicate. Nil lists
thành empty, nil note thành empty string. Wrong list root, nonstring/empty ID hoặc
wrong note type trả error trước admission, filter hoặc service.

Direct Reset chỉ capture resetApps, bỏ qua unused RRS list/note để không gây failure
do input không dùng. Save RRS + Reset capture cả hai lists và note một lần. Empty
selection messages giữ policy cũ; empty reset list vẫn có thể được phát hiện sau
backup, còn malformed input bị reject trước work.

Backup và clear callers lấy đúng lists từ owned packet. New scope adapter
`syncHookScopeToResetAppIDs:waitingForDaemon:` nhận cùng resetApps với clear, rồi
giữ nguyên eligibility filter, extension expansion, scope write và filter waiter.
MobileMail vẫn có trong clear list và bị loại khỏi spoof scope bằng existing policy.
Startup/picker compatibility methods tiếp tục forward live selected list như cũ.

Explicit Reset backup worker dùng captured note; generic nil-token backup giữ live
note behavior từ trước. Live UI selections/note không bị overwrite hoặc rollback;
matching finish nhả packet, stale finish không xóa packet của run mới. H4L fake
preview snapshots và H4N per-app main/once/token guards giữ nguyên.

## Verification

Native fixture extract hai helper mới: tổng 53 ProfileManager methods + Profile
model + 23 controller methods. Scope transport được mock tại UI boundary; source
contracts kiểm tra explicit IDs đi qua actual eligibility/extension/scope/writer
flow. Existing clear-only MobileMail/startup nonblocking assertions được chuyển
sang packet forwarding thay raw selected-array access.

Native cases thêm:

- Copy mutable array/string IDs, giữ order/duplicates và separate backup list.
- Replace UI selections/note và mutate originals trong pending backup: scope và
  clear nhận admitted reset list, live newer choices vẫn giữ nguyên.
- Hai actual per-app backup callbacks nhận cùng captured note sau UI text change;
  generic live-note regression H4N vẫn giữ.
- Wrong roots, invalid members/empty IDs và wrong note type dừng trước admission,
  HUD, filter và services. Direct Reset bỏ qua malformed unused RRS inputs.
- Nil/default packet, NULL error output, matching/stale finish và off-main capture.

Windows local: 62/63 Python suites và 4/4 Node pass; bridge-shell suite vẫn lỗi
`mkdir /c/Users/ADMIN: Permission denied`. Profile/source guards, source hardening,
RootHide build/package static checks, exact extraction, CHECK macro và diff checks
pass. Native compile/Foundation, Theos, UIKit/real scope expansion, backup/clear
và device H4O cần macOS CI/thiết bị. Không thêm compiled source/framework dependency.

## Cost và boundaries

Snapshot một lần mỗi admitted run, O(number of IDs + mutable string/note size).
Expected low với selections thông thường, không benchmark latency. Không clone
list trong mỗi recursive item, không thêm timer/polling/IPC hoặc hot-hook overhead.
Extra owned packet được giữ tới terminal/restart; service không callback vẫn có
lifetime limitation cũ, không tự timeout rồi admit overlap.

Chỉ app lists và Reset note được capture tại admission. Fake options/preview vẫn
capture ở profile-preparation phase theo H4L; không claim full tap-time transaction.
Không bảo vệ concurrent mutation đúng lúc capture, generic backup input aliases,
warnings hoặc arbitrary producer payload. Active profile/metadata target chưa pin
qua toàn workflow. Scope sync và clear dùng cùng packet ở bước sync; writer khác
(kể cả picker/startup) vẫn có thể đổi global scope sau đó, chưa có global ordering
hoặc whole-run scope lock. Cross-instance admission, cancellation/owner teardown,
defaults/directory durability, crash recovery và daemon acknowledgement vẫn riêng.
Manifest `4C.2H4O-partial`; whole Reset và toàn Patch 4 vẫn partial, Patch 5–8 chưa
triển khai.

Người dùng xác nhận build H4O pass ngày 2026-10-28. Reset selection checkpoint
hardening được triển khai tiếp tại [H4P](PATCH-4C-2H4P-reset-selection-checkpoints.md);
atomic target pinning và whole Reset/device matrix vẫn partial.
