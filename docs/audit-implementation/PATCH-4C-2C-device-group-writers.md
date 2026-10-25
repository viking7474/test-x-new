# Patch 4C.2C — model/iOS/cellular dependency writers

Ngày cập nhật: 2026-10-25. Người dùng xác nhận build 4C.2B pass. Lượt này enroll bốn writer trong IdentifierManager; whole-regenerate/profile workflow, standalone telephony validation và defaults authority vẫn **pending**. Không coi toàn bộ 4C hoặc Patch 4 đã hoàn tất.

## Boundary và behavior

| Entry point | Contract mới | Policy được giữ |
| --- | --- | --- |
| regenerateDeviceProfileGroup | Chọn target một lần; prepare owned fields ngoài gate; merge lên IDs mới nhất và xóa legacy cellular sidecars trong cùng commit | Canonical hardware/variant/A-number/build selection; IMEI/MEID generation và toggles; GenerationCounter tăng một lần, CommittedAt cập nhật |
| setCustomDeviceModel | Cùng ownership set cho replacement; xóa dependent software/cellular fields và sidecars trong transaction | iPhone phải có DB record; non-iPhone compatibility như trước; không tự tăng GenerationCounter |
| generateIOSVersion | Capture current IDs dưới gate; chuẩn bị software + cellular/baseband theo build mới; kiểm tra dependencies trước commit | Version range/WebCompat, normalized components, giữ IMEI/MEID đang hợp lệ theo tuple/toggle; không tự tăng counter |
| refreshCanonicalCellularIdentityForCurrentProfile | Capture tuple, prepare ngoài gate, compare dependencies rồi merge đúng cellular fields | Unknown/disabled fail-closed; giữ valid regional identities; tăng counter một lần |

Các fallback cần seed một model group nay dùng private generator nhận identity directory đã capture, không chọn lại active profile. Dữ liệu không thuộc ownership set (ví dụ SSID vừa được writer khác cập nhật) được giữ ở thời điểm commit. Full group generation độc lập với old managed fields; software/cellular refresh phụ thuộc old tuple nên phải compare DeviceModel, RegulatoryModelNumber, IOSBuild và cellular fields, kể cả absence, trước khi ghi. Conflict trả nil/NO + NSError; không tự retry/poll hoặc ghi đè candidate của writer khác.

DB lookup, secure/random generation, validation, logging và compatibility-manager callbacks nằm ngoài source gate. Cold capture dùng một no-change source operation để recover pending journal và đọc IDs; sau khi unlock mới chuẩn bị dữ liệu. Callbacks chạy sau top-level commit thành công, không chạy khi persistence fail.

## Lỗi được sửa có thay đổi failure behavior

1. Trước đây model group/refresh ghi IDs rồi mới remove `imei.plist`/`meid.plist` ngoài transaction và bỏ qua lỗi remove. Crash/I/O error ở giữa có thể để legacy fallback của model cũ. Nay delete và IDs chung một journal/commit marker; rollback phục hồi exact bytes, mode và absence.
2. generateIOSVersion trước đây đổi IOSBuild nhưng giữ BasebandVersion cũ. Nay chuẩn bị baseband cho build mới và refresh/clear cellular group theo cùng resolver. Known enabled cellular thiếu firmware phải fail trước commit, thay vì persist mixed tuple. Đây là sửa correctness có chủ đích, không phải cosmetic refactor.
3. Các writer trước đây RMW một copy đọc ngoài gate có thể mất unrelated updates/counter increments. Nay chỉ merge ownership set trên current dictionary; counter increment có overflow guard. Malformed before-image không bị thay bằng dictionary rỗng.
4. Software generation đọc model từ captured authoritative IDs; nếu IDs thiếu model thì seed cả nhóm trên cùng target. Không lấy compatibility cache của profile khác để tạo orphan software identity.

## Journaled deletion

Source transaction thêm `removeDictionaryAtPath:error:`. Removal chỉ được stage; read trong transaction thấy empty dictionary với exists=NO. Set sau remove hoặc remove sau set dùng last staged operation và cập nhật byte accounting. In-memory NSNull marker không đi vào plist/journal.

Commit validate toàn bộ paths/before-images, ghi journal trước, rồi apply write/unlink và commit marker. Unlink ENOENT là thành công; lỗi khác abort và recover. Journal schema v1 không đổi vì recovery chỉ cần before-images/existed, không cần serialize forward operation. Existing malformed files vẫn bị từ chối, kể cả khi yêu cầu delete; không nới allowlist hay bỏ validate để dọn chúng.

Đây là process-crash recovery contract, chưa phải fsync/power-loss durability. Filesystem actor không tham gia gate và directory create/delete vẫn nằm ngoài guarantee.

## Performance và giới hạn

Không thay hot hooks hoặc reader authority. Prepare nặng nằm ngoài gate; compare/merge và journal I/O nằm dưới gate. Relative cost: low cho in-memory compare/merge; moderate cho cold persistence với before-images và commit marker. Không có benchmark latency/CPU trên thiết bị và không claim cải thiện throughput. Cold callers vẫn có thể chạy synchronous trên UI thread; thay async flow thuộc profile orchestration tiếp theo.

Cache publication sau commit chưa có total ordering giữa hai concurrent callers. Source contract cũng không bảo vệ toàn bộ mutable settings/singleton state hoặc một lần reload nhiều DB providers. Không bọc nguyên manager workflow trong outer source transaction: pure staging helpers dùng cho composition, callbacks phải được dời sau outer commit.

Pending: regenerateAllEnabledIdentifiers, standalone generate/set IMEI/MEID validation và target selection, ProfileManager directory/switch/async lifecycle, Dashboard final apply, actual storage/model workflow, security/defaults authority và rootful reader rollout. Manifest vẫn đánh dấu deviceIDs partial và có producer pending/external.

## Kiểm chứng

- Native source-store fixture mới: staged absence, repeated removal/set composition, unapproved path taint; child process crash sau unlink và sau commit marker; owner recovery giữ committed absence hoặc khôi phục đúng bytes/mode cùng paired write.
- Native dependency fixture trích **đúng production method bodies và static helpers**, compile cùng real source engine, identifier staging, DeviceProfileSchema, IdentityValidator, VersionCompare và Security random API. Stub chỉ DB/value providers, config/path selection và log sink; không thay persistence bằng model Python.
- Cases gồm target đổi trong prepare, unrelated merge, counter policy/exhaustion, valid/distinct regional IMEI + MEID, rollback sau deletion, cache callbacks sau commit, custom model invalidation, missing hardware/DB/firmware, unknown cellular, software/baseband pair, dependency drift ở cả software và cellular, fixed-target fallback khi thiếu model.
- CI thêm `test_runtime_device_group_writers.py --native`, ba process mới cho rootful và RootHide defines. Đây không thay full UIKit/Theos build, real DB integration hoặc device runtime matrix; Windows chưa chạy native fixture.

Host result: **29/29** source/regression gates, **3/3** Node suites, backup audit **2604/2604**, generated production fragments và git diff --check pass. Native/build mới chờ macOS CI. Không commit, push, deploy hoặc terminate app trên thiết bị.

Phần tiếp theo: transaction boundary cho regeneration/profile workflow và standalone telephony dependency validation, sau đó defaults authority theo manifest.
