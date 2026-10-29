# 4C.2H4T — Expected Reset required identifier flags

Hoàn tất local ngày 2026-10-29. Người dùng xác nhận H4S build pass trước bước này.

## Finding

Confirmed target-admission gap, severity High, trong bước
`ensureDashboardFakeOptionsEnableRequiredIdentifiers:error:` của Reset Data.
Trước H4T, UI validate created profile A rồi gọi từng
`setIdentifierEnabledAndPersist:forType:`. Setter cũ gọi tiếp
`setIdentifierEnabled:forType:`, có thể tự generate missing DeviceName, grouped
model/iOS hoặc storage theo current target; nó còn ensure baseline DeviceModel.
Nếu B được chọn giữa UI checkpoint và setter, artifacts có thể được ghi vào B
trước khi expected-active generation/preview của H4Q phát hiện mismatch.

H4S chỉ bảo vệ publication của generation, nên không đóng lỗ hổng này. Reproduce
bằng selection handoff ngay trước required toggle có missing artifact. Đây là
đường gọi thực có side effects; chưa đo tần suất interleaving trên device và không
kết luận mọi Reset đều ghi nhầm profile.

Ngoài target risk, required toggles từng có thể tạo artifacts tạm rồi generation
ngay phía sau tạo lại. Một failure ở toggle sau còn để các toggle trước đã lưu.

## Implementation

Thêm `IdentifierManager.enableRequiredIdentifiers:forExpectedActiveProfileID:error:`:

- Chỉ nhận tối đa bốn identifier từ IOSVersion/DeviceModel/StorageSystem/DeviceName;
  không nhận secondary security toggles như WiFi/Battery/DeviceTheme. Copy ID,
  array và mutable strings trước source callbacks/ownership.
- Acquire nonblocking lifecycle; validate configured root, pending deletion và
  authoritative canonical/legacy selection trước thay đổi flags.
- Giữ enable-only policy và dirty in-memory canonical flag/scope flush của
  saveSettings. Detach payload trước staging; không tắt các flag khác do options
  false và không gọi target resolver, migration, provider hoặc artifact setter.
- Một standalone source transaction kiểm tra lại lease, deletion và exact
  selection pair rồi stage settings/scope qua existing generation-settings helper.
  EnabledIdentifiers, legacy StorageSystemEnabled và SettingsInitialized đi cùng
  commit; unrelated top-level settings được merge như trước.
- Already-enabled/empty request vẫn validate selection và final receipt, nhưng
  không stage file, tạo commit marker hay notify. Standalone admission áp dụng cả
  no-op để không acknowledge một outer transaction chưa commit; nested attempt
  poisons outer staging khi đến standalone admission, dù caller nuốt lỗi.
- Chỉ sau successful commit và release lease mới update requested memory flags,
  invalidate caches và gửi một settings notification. Source failure giữ memory
  và notification nguyên trạng. Observer exception sau commit không đổi YES/nil
  error thành rollback giả.

UI required-options helper có overload nhận expected ID. Targeted Reset gửi một
packet theo cùng defaults/mapping: Fake Model bật DeviceModel và StorageSystem,
Fake iOS mặc định bật, Fake Name mặc định tắt. Sau đó generation/preview vẫn chạy
đúng thứ tự với expected ID của H4Q và publication checks H4R/H4S.
Nil-target wrapper và generic toggle APIs giữ code path cũ.

## Behavior boundary

Thay đổi có chủ đích trong targeted Reset: bỏ temporary artifact generation từ
required toggles; failure trong gói flags rollback cả settings/scope thay vì giữ
một phần toggles. Đây là cách ngăn wrong-target side effects, không chỉ refactor
để code gọn. Artifact generation kế tiếp vẫn thực hiện như trước. Nếu generation
hoặc preview sau đó fail, packet flags đã commit vẫn được giữ; không rollback app
clearing, profile activation hoặc source commit trước đó.

Các random values và GenerationCounter increments tạm từ legacy setters không còn;
counter của owned generation vẫn theo implementation hiện tại. Settings notifications
được gom còn một lần cho packet thay vì từng toggle; không đổi notification topic.

No-op dựa trên live manager flags, giống policy skip already-enabled trước đây;
không tự repair sparse/inconsistent persisted defaults. Packet không mkdir hay
repair preferences directories. Generic toggles và source/defaults authority vẫn
cần review riêng. Freeze full canonical map/scope không phải per-key merge/CAS với
mọi writer bên ngoài; cfprefsd và post-release cache ordering chưa được giải quyết.

## Performance và lifecycle

Không còn provider/random generation và nhiều saveSettings transactions từ tối đa
bốn required toggles trong targeted path. Khi cần đổi flags, có một settings/scope
commit; admission/final validation thêm bounded reads của selection/deletion.
No-op vẫn có validation I/O, không phải zero-cost call. Cost dự kiến low/moderate
theo source size/contention; chưa benchmark latency/main-thread cost trên device.
Không thêm hot hook, polling, timer, queue hay retry.

Không giữ source/lifecycle gate qua notification. Blocks chỉ chạy đồng bộ, không
lưu trên manager và không tạo retain cycle. Không bổ sung thread-safety cho toàn
mutable IdentifierManager; Reset adapter tiếp tục yêu cầu main thread.

## Verification

Group native recipe extract 42 actual IdentifierManager methods, thêm exact new
writer cùng fixture standalone wrapper gọi real SourceStore backend. Production
app/tweak đều lấy common sources qua Makefile; không thêm source/framework build
dependency. UI/profile recipe extract 53 ProfileManager + Profile model + 26 UI
methods. Rootful/RootHide-defined lanes vẫn có ba executions mỗi lane trong CI.

Fixture bổ sung:

- One commit, one notify; không resolve target, migrate, prepare, adopt hay thay
  profile artifact bytes dù cached resolver B và authoritative source A.
- Enable-only/unrelated flags, top-level fields, scope và atomic storage alias.
- Already enabled no-op; authoritative mismatch kể cả no-op; invalid/unsupported
  request không ghi source.
- Fault sau mỗi file rollback bytes và absent scope, giữ memory/notify.
- Canonical B, same-ID revision, legacy-only drift, late deletion; busy/early
  pending deletion trước selection capture.
- Copy mutable ID/type/container; notification callback acquire fresh lease rồi
  throw vẫn giữ committed success.
- Changed và no-op packets đều reject nested source acknowledgement, poison outer
  staged write, không publish uncommitted flags.
- UI defaults/options matrix route đúng một packet, packet failure không fallback
  legacy setters. Existing generic partial-failure và Reset checkpoints giữ tests.

Windows local: 62/63 Python suites + 4/4 Node pass. Bridge-shell suite còn lỗi
`mkdir /c/Users/ADMIN: Permission denied` như trước. Exact extraction, CHECK macro
arity, source hardening, RootHide build/package static và diff checks pass.
Không có macOS/xcrun/Theos local; native compile/runtime, package và device H4T
vẫn chờ CI. Static/extraction pass không thay thế native verification.

Manifest `4C.2H4T-partial`. Whole Reset, earlier backup/metadata/hardware target
capture, global cache/defaults ordering, cross-instance/lifetime/cancellation,
directory durability và daemon ack vẫn partial. Patch 5–8 chưa triển khai.

## Native build follow-up — 2026-10-29

CI báo chuỗi FAIL bắt đầu tại `expected owners seed independent targets and newer
selection`. Đọc call order của shared native fixture xác định hai lỗi test:

1. `TestTelephony` kết thúc bằng case ghi malformed `identity/imei.plist` rồi kiểm
   tra production từ chối overwrite, nhưng không restore bytes gốc. Suite kế tiếp
   `TestExpectedActiveOwners` gọi SeedDashboard; Seed muốn overwrite sidecar hỏng,
   SourceStore từ chối malformed before-image đúng contract. Vì shared store vẫn
   bị nhiễm fixture corruption, preview/generation baselines phía sau cũng fail.
   Sửa bằng save raw bytes trước injection, restore trong `@finally` của test và
   assert toàn snapshot/commit identity trở về baseline trước khi rời suite. Không
   cho production writer repair hay bỏ qua malformed source.
2. Successful expected-owner A commit từng so toàn `Snapshot(b)` để kiểm tra B
   không đổi. Capture còn chứa global sourceCommitID, nên A commit hợp lệ cũng làm
   snapshot B khác dù B bytes nguyên vẹn. Sửa oracle so riêng `files`, đồng thời
   assert global marker có tiến lên. Những failure/rollback assertions vẫn so cả
   snapshot để bảo vệ invariant không có commit ngoài ý muốn.

Thêm source regression guards trong telephony/generation suites. Negative controls
gỡ restoration hoặc đưa lại whole-snapshot oracle đều bị guard từ chối, kể cả khi
đặt lại token đúng ở ngoài function. Exact extraction và CHECK macro arity pass.
Không đổi production, manifest phase hay RootHide packaging. Native recipe chạy
rootful trước và dừng khi binary fail; log rootful không chứng minh lỗi chỉ có ở
rootful. Hai lane dùng cùng fixture sửa này. Native/Foundation rerun vẫn cần macOS
CI; Windows source checks không xác nhận toàn bộ chuỗi runtime đã pass.
