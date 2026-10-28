# 4C.2H4P — Reset selection checkpoints

Ngày 2026-10-28. Người dùng xác nhận H4O build pass trước bước này.

## Findings và giới hạn của patch

Confirmed queued-flow defect, severity High, trong
`TLinkIOSViewController.m`, `createNextProfileAndRandomizeWithWarnings:`: success
create đã activate profile, nhưng UI vẫn gọi switch sau một main-queue turn mà
không xác minh selection. Nếu observer/user writer đã chọn profile khác trong gap,
same-profile Reset switch có thể chọn lại request cũ.

Potential continuation/feedback defect, severity Medium: generation/preview callbacks
và queued feedback không checkpoint active ID; delayed restart chỉ biết Reset token,
không biết selection đã đổi sau success feedback. Token xác định run trên controller,
không xác định active profile của hệ thống.

Controlled reproduction: giữ create/switch callback, đổi active ID trước UI delivery;
đổi selection từ toggle/generation/preview/persist collaborator; hoặc đổi trong delay
restart. Không tuyên bố đã tái hiện trên thiết bị, và các checkpoints dưới đây không
giải quyết toàn bộ cross-process target race.

## Implementation

UI copy createdProfileID tại successful create delivery. Trước switch, gọi existing
`ProfileManager.validateCurrentProfileID:error:` qua read-only UI adapter. Mismatch
hoặc unavailable selection dừng run, release token/HUD và báo lỗi thay vì chọn lại
old profile. Success feedback dùng copied ID, không reread mutable input Profile.

Target-aware preparation overload checkpoint bốn lần: trước required flags, sau
flags/trước generation, sau generation/trước preview và sau preview. Mismatch dừng
phase tiếp theo. Generic old selector giữ current-target semantics qua nil expected
ID, không thêm selection I/O cho các caller đó.

Queued success block checkpoint trước gọi feedback helper. Delayed restart checkpoint
lần nữa sau token/phase claim; nếu fail, nhả run và log một lần, không kill/respring.
Không tạo error modal thứ hai tại timer vì success feedback cũ có thể còn hiển thị;
creation/source success đã xảy ra trước đó không bị đổi thành rollback giả.

Giữ same-profile switch khi checkpoint còn match, Reset generation/preview order,
options/counters/storage, success notification và delay ba giây. Không đổi source
schema, IdentifierManager writer implementations, hook/ctor/RootHide bootstrap hoặc
package dependencies. Prior clear/activation/toggles/generation có thể đã commit;
không rollback hoặc tự retry khi checkpoint fail.

## Verification

Native fixture extract hai methods mới: tổng 53 ProfileManager methods + Profile
model + 25 controller methods. Preparation fixture compile actual checkpoint adapter
với controlled ProfileManager collaborator; shared current-ID implementation vẫn
có actual temporary-source coverage từ H4J, không thay bằng mutable UI memory.

Cases thêm:

- Selection đổi trước queued create delivery: không switch, flags, generation/preview.
- Selection đổi trước switch delivery hoặc trong toggle/generation/preview: đúng
  downstream stages dừng, new ID không bị tự reselect.
- Selection đổi trong persistence trước feedback: không success UI/restart schedule;
  earlier final notice và committed work không được giả vờ undo.
- Selection đổi sau success feedback: delayed timer không restart, release inputs/token.
- Input Profile ID bị sửa sau checkpoint: feedback và restart dùng frozen created ID.
- Existing nil-target preparation, all failure gates, duplicate/stale run, list/note
  capture và per-item regressions vẫn giữ trong cùng fixture.

Windows local: 62/63 Python suites và 4/4 Node pass. Bridge-shell suite vẫn lỗi
`mkdir /c/Users/ADMIN: Permission denied`. Source hardening, RootHide build/package
static checks, exact extraction, CHECK macro và diff checks pass. Native compilation,
Foundation/runtime, Theos và UIKit/device H4P cần macOS CI/thiết bị. Recipe giữ hai
lanes rootful/RootHide-defined, ba executions/lane; không thêm source/framework.

## Performance và remaining work

Matching full Reset thêm bảy bounded current-ID checkpoint calls trên cold path:
trước switch, bốn preparation boundaries, feedback và restart. Chúng đọc selection
pair dưới existing source contract, nên có I/O/ownership cost, expected low/moderate
theo source size và contention; chưa benchmark main latency. Không polling/timer
mới hoặc hot-hook overhead; không gọi lookup hàng nghìn lần/giây.

Đây là checkpoint hardening, không phải atomic target pinning. Writer khác vẫn có
thể đổi selection sau check nhưng trước generation/preview owner capture hoặc kill.
Same-ID generation changes/ABA không được phát hiện bằng ID equality. Global flags
có thể đã commit sau một reentrant selection change trước boundary kế tiếp. Existing
feedback helper còn async presentation, không freeze selection tới lúc alert hiện.

Bước tiếp theo cần expected profile ID đi vào generation/preview ownership và được
kiểm tra trước target lookup/commit, thay vì tiếp tục coi UI checkpoints là full CAS.
Original-hardware capture trước create, backup/clear metadata target, global scope
ordering, cross-instance admission, owner teardown/missing callback, source/defaults/
directory durability và daemon acknowledgement vẫn riêng. Manifest `4C.2H4P-partial`;
whole Reset và toàn Patch 4 chưa hoàn tất, Patch 5–8 chưa triển khai.
