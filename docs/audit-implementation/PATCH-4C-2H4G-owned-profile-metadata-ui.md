# Patch 4C.2H4G — owned profile metadata edits from UI

Người dùng xác nhận build H4F pass. H4G dùng source chung cho rootful/RootHide,
giữ bootstrap priming và hook behavior đã được xác nhận.

## Findings

High / P1: ProfileManagerViewController.showRenameDialogForProfile: và infoTapped:
vẫn sửa shared Profile trước khi lưu, tự đọc/ghi bốn display plists, cập nhật active
selection trước registry và dùng didUpdateAnyFile để quyết định thông báo success.
Description callback bỏ qua BOOL/error từ updateProfile; rename dùng void API nên
không biết kết quả registry save. Busy/CAS/I/O failure vẫn có thể đổi UI/files/label
và báo thành công. Các writes này đi vòng qua lifecycle/source group của H4A/H4F.

Medium / P1: rename sửa profile.name trước rồi tra lại theo new name, có thể chọn
nhầm record khác khi display names trùng. Compatibility rename cũng mutate shared
record trước persistence. Đây là lỗi ordering/selection trên source, chưa có incident
thiết bị được cung cấp. Controlled native regressions đã thêm; chờ macOS execution.

## Implementation

Thêm editProfileID:name:shortDescription:completion:. Nil field nghĩa là giữ giá trị
hiện có; description rỗng vẫn hợp lệ, rename UI vẫn trim/reject empty text. Không
thêm unique-name rule. Resolve exact registered ID, kiểm tra admission, acquire
existing lifecycle và secure encode/decode riêng registered graph thành owned
candidate. Chỉ candidate nhận requested string copies; không sửa dialog model cũ.

Candidate đi qua updateProfileUnderLease và H4F exact-byte preflight. Inactive edit
không ghi selection. Nếu target đang active theo committed selection captured dưới
lease, canonical/legacy label pair CAS chạy sau registry persistence, so toàn bộ
expected pair/revision. Giữ label fields/LastSelected/revision policy. Không terminate
apps, regenerate identifiers, publish generation caches hoặc thêm settings notification.

Lifecycle release ở finally trước mirror, profileChanged notification và completion
trên main. Chỉ overall success phát profileChanged. Mirror là best effort sau pair
commit; mirror exception không giả rollback. Exception sau metadata phase clear success
và trả failure, tránh giữ success của phase trước khi label phase chưa hoàn tất.

Lỗi source group trước registry giữ archive/manager slots/model input. Registry CAS
fail sau metadata commit hoặc selected label CAS/I/O fail sau registry commit là
partial failure: phần đã commit có thể còn, không rollback archive hoặc selection
mới hơn. UI báo lỗi và reload; không giả toàn operation atomic. Raw updateProfile:
giữ contract cũ, không tự thêm active-selection effects cho mọi caller.

Hai dialog chỉ capture ID/text và gọi shared UI adapter. Adapter quyết định thông báo
từ completion BOOL/error, cleanup indicator và reload; explicit rename delegate chỉ
notify khi success. Alert actions dùng weak alert/controller, completion không giữ UI
owner. Bỏ direct plist I/O, pre-save shared mutations và didUpdateAnyFile heuristic.
Compatibility rename giữ selector/name lookup cũ nhưng route owned edit bằng ID.

Shared metadata writer stage cả scoped ProfileDescription và legacy Description alias
trong cùng source group, thay cho alias write riêng trong description UI. Scoped extras
và Apps vẫn giữ. Các fixed Info/appdata/identifiers shapes còn lại không đổi.

## Verification

Native fixture extract 42 exact manager methods và actual Profile model, giữ hai lanes
rootful/RootHide-defined và ba executions/lane. Không thêm native source dependencies.

- Fault sau từng display file: raw bytes/absence, archive/receipt, shared input và
  current selection giữ nguyên; callback một lần trên main sau lifecycle release.
- Successful inactive edit: owned nested Profile graph, empty description và hai
  scoped aliases; active files/caches/termination giữ nguyên.
- Active edit: hai source commits, archive đã persisted tại label commit, pair khớp,
  mirror/notification chỉ sau các phase cần thiết.
- Fault tại từng selection file: metadata/archive đã lưu, pair rollback đúng, failure
  không mirror/publish success. Exception sau registry và explicit reload được kiểm tra.
- External selection drift sau archive: CAS không ghi đè newer target; unknown/invalid/
  busy admission không persist; background delivery về main, compatibility rename và
  duplicate display names vẫn edit đúng ID.

Source guards kiểm tra ba UI bodies không có raw writes/shared setters, weak captures,
completion-driven result và manager phase ordering. UIKit presentation/delegate behavior
chưa chạy native trong Foundation fixture; cần Theos compile và device UI verification.

Local Windows: 62/63 Python suites, 4/4 Node suites pass; bridge-shell migration vẫn
Permission denied `/c/Users/ADMIN` như trước. Source hardening, RootHide build/package
metadata, source/macro/42-method extraction và diff checks pass. Native/runtime/package
H4G chờ macOS CI; không dùng source guards/extraction thay native execution.

## Performance và remaining boundaries

Bỏ tối đa bốn UI plist reads/writes lặp trước manager persistence, cùng các production
logs của những lượt ghi đó. Thêm encode/decode một target graph để sở hữu edit; H4F
full-registry validation vẫn chạy. Expected cold CPU/allocation moderate, có thể high
với settings lớn; chưa benchmark nên không khẳng định tổng latency giảm. File work vẫn
trên main như contract cũ; không thêm worker/timer/polling hoặc giữ source gate qua UI.

Đây chưa là một transaction cho display/archive/selection hoặc global immutable model.
Callback/concurrent mutation sau candidate adoption, raw readers, crash windows, other
direct writers, defaults/security authority và full directory durability còn riêng.
Ownership snapshot diễn ra khi admission trên main, không đồng bộ mọi nonatomic property
của caller. UIKit deallocation/presentation và device runtime matrix vẫn cần kiểm tra.
Manifest `4C.2H4G-partial`; toàn Patch 4 chưa hoàn tất, Patch 5–8 chưa triển khai.

Người dùng xác nhận build H4G pass ngày 2026-10-28. Verified UI list và
UI delete producers được chuyển tại [H4H](PATCH-4C-2H4H-verified-profile-ui-deletion.md);
full device/runtime matrix và toàn Patch 4 vẫn partial.
