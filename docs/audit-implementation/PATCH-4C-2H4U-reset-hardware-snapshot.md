# 4C.2H4U — Coherent hardware snapshot for iOS-only Reset

Ngày 2026-10-29. Người dùng xác nhận H4T và native fixture follow-up đã build pass.

## Finding

Confirmed mixed-read window, severity Medium/P1, trong
`createNextProfileAndRandomizeWithWarnings:` và `generateFakePreviewFromOptions:`.
Với Fake iOS bật, Fake Model tắt, preflight đọc model qua current-value API để
validate preview marker; generator lại có thể đọc current model cho iOS DB lookup;
sau đó Reset resolve current identity path và raw-read device_ids để giữ variant.
Các lần đọc không chia sẻ cùng source checkpoint.

Nếu cached resolver chậm hơn selection, hoặc profile/source đổi giữa các lần đọc,
preview có thể mang IOSProductType của A nhưng hardware/variant từ B. Trường hợp
marker/model khác nhau thường bị owned preview validation chặn muộn, sau khi đã
clear apps và tạo/activate profile mới. Không kết luận mọi mismatch đều commit
được, có crash, hoặc lỗi này đã được quan sát trên device của người dùng.

Reproduce bằng controlled cache/source A/B disagreement hoặc đổi live current
model trong provider callback. Native fixtures bổ sung cả source capture và actual
preview generator, thay vì chỉ kiểm tra mock producer hay tokens ở file khác.

## Implementation

Thêm cold manager API `captureCurrentDashboardHardwareWithError:`:

- Đọc canonical/legacy selection pair theo authority policy hiện tại, validate ID,
  rồi đọc device_ids của đúng target dưới cùng standalone source transaction.
- Yêu cầu device_ids tồn tại và DeviceModel là nonempty string. Missing/invalid
  canonical selection không fallback qua legacy; canonical vắng vẫn hỗ trợ legacy.
- Capture DeviceModel, DeviceModelName, RegulatoryModelNumber, BoardID và HwModel.
  Các optional fields giữ policy cũ: chỉ copy nonempty strings, bỏ missing/bad type.
- Detach property-list packet trước khi nhả gate. Không resolve cache/current path,
  migrate, mkdir, stage settings/artifact, gọi provider, invalidate cache hay notify.
  Error chỉ trả qua output, không thay shared manager.error.
- Standalone admission loại nested uncommitted source view và poison outer staging.
  Read-only transaction không tạo source commit marker; source recovery thông thường
  của store vẫn có thể chạy khi admission cần recover một journal trước đó.

Chỉ iOS-only Reset gọi API một lần ở preflight. Cùng packet được dùng để validate
cached IOSProductType, truyền model cho iOS lookup qua overload
`generateFakePreviewFromOptions:currentDeviceIDs:`, rồi copy hardware variant vào
final preview. Bỏ current path/raw plist reread sau provider work. Final request vẫn
được detach bằng H4L trước create.

Generic preview wrapper truyền nil vào overload để giữ existing live lookup policy.
Fake Model hoặc Fake iOS tắt không thêm hardware capture. Model/iOS DB selection,
random pools/ranges, names/carrier/MAC/serial, required flags và source commit order
H4Q–H4T giữ implementation hiện tại.

## Behavior boundary

iOS-only Reset nay dừng trước ID allocation/profile creation khi không capture được
selection hoặc persisted DeviceModel hợp lệ. Trước đây missing raw identity có thể
bị bỏ qua và flow tiếp tục với fallback/cache data. Đây là thay đổi cần thiết để
không tuyên bố giữ hardware khi không có baseline đáng tin cậy. App clearing đã
hoàn tất trước profile preflight vẫn không được rollback.

Hardware có snapshot semantics tại preflight: source/profile đổi sau capture không
làm packet đổi theo. Không giữ lifecycle qua DB/providers/create và không reselect
profile cũ. Không claim active selection được pin cho toàn Reset, chống mọi raw
writer hoặc giải quyết hardware/backup target tại thời điểm tap. Optional missing
variant fields vẫn theo legacy policy; không thêm stricter catalog validation.

## Performance và lifecycle

Mỗi iOS-only Reset thêm một bounded standalone read transaction: selection pair,
device_ids và detach tối đa năm fields. Source store dùng exclusive gate cho API
transaction này dù không stage write; có lock/file validation cost và contention
timeout hiện tại. Các read bên trong vẫn decode dictionary đầy đủ, không chỉ đọc
năm key từ disk. Bù lại targeted path không resolve/migrate current path hoặc đọc
lại current model/hardware sau provider.

Relative cost dự kiến low/moderate, chưa benchmark main-thread/device latency.
Không thêm hot-hook I/O, IPC, polling, timers, queue, retry hay persistent cache.
Providers chạy sau gate release. Packet immutable, blocks dùng đồng bộ, không lưu
owner/callback và không tạo retain cycle. Mutable IdentifierManager thread-safety
toàn cục vẫn ngoài scope; UI Reset tiếp tục yêu cầu main thread.

## Verification

Group native recipe extract 43 actual IdentifierManager methods, thêm exact source
capture API và dùng real SourceStore. Profile recipe giữ 53 ProfileManager methods
và Profile model, nâng lên 28 UI methods, gồm wrapper và toàn body preview generator.
Controlled IPhoneModelDB/IOSBuildDB/DeviceModelManager collaborators dùng cho actual
generator; actual catalogs/device APIs không được chứng minh bởi fixture này.
Không thêm source/framework vào native build recipes; rootful và RootHide-defined
vẫn có ba executions mỗi lane trong macOS CI.

Cases:

- Source A/cached resolver B: capture đủ tuple A; không resolve/migrate/prepare/adopt,
  notify hay thay source bytes/commit marker. Packet không đổi sau source handoff.
- Legacy fallback; invalid canonical không bị bypass; missing selection/identity,
  missing/empty/bad model, corrupt source đều fail không repair hoặc tạo profile.
- Optional type omission; nested uncommitted view bị reject/outer staging poisoned.
- Corrupt test restores raw bytes trong finally và assert clean shared snapshot,
  giữ fixture isolation của follow-up H4T.
- Actual Reset empty/stale/matching preview dùng cùng snapshot để refresh/validate
  và giữ model/regulatory/board/hw; không raw path/current-value lookup trong nhánh.
- Capture failure stop trước create/required flags/generation/preview; modes khác
  không gọi new capture.
- Actual preview generator dùng supplied model cho iOS provider dù live cache khác;
  generic wrapper vẫn có hai live model lookups như implementation trước đó.

Windows local: 62/63 Python suites + 4/4 Node pass; bridge-shell suite vẫn lỗi quyền
`mkdir /c/Users/ADMIN: Permission denied`. Exact extraction, CHECK macro arity,
source hardening, RootHide build/package static và diff checks pass. Native compile,
Foundation runtime, actual catalogs, Theos/package và device H4U chờ macOS CI.

Manifest `4C.2H4U-partial`; Patch 4 và whole Reset/defaults/cache/durability/cancellation
vẫn partial. Patch 5–8 chưa triển khai.
