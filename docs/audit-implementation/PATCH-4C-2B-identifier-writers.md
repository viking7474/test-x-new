# Patch 4C.2B — identifier values và schema migration

Người dùng xác nhận build 4C.2A pass. Lượt này chuyển các scalar/UUID wrappers và migration trong IdentifierManager sang source transaction. Đây vẫn là rollout **partial**; không tuyên bố toàn bộ 4C hoặc Patch 4 hoàn tất.

## Boundary đã triển khai

`PXRuntimeIdentifierWriter` là staging helper thuần Foundation: nhận identity directory cố định, merge IDs đang có dưới gate, stage sidecars và trả lỗi. Registry giữ đúng 16 loại custom value đã được hỗ trợ; không thêm HardwareUUID alias hoặc mở rộng custom API sang DeviceTheme. Production allowlist lấy thêm các tên chính xác từ registry, tracking_info và legacy profile-root battery_info; daemon và native runners đã thêm dependency link tương ứng.

| Nhóm | Thay đổi | Behavior thành công được giữ |
| --- | --- | --- |
| 13 scalar/UUID generators và UDID | Chọn target một lần trước generation; sidecar + device_ids commit cùng transaction | Provider/validation cũ; UDID 40 ký tự hex thường; không tự tăng GenerationCounter |
| saveCustomValue | Một pair commit; chỉ gọi compatibility setters khi persistence trả thành công | 16 mapping type/file/key; mỗi lần save tăng counter một lần |
| ATT và theme | tracking_info/device_theme cùng IDs trong một transaction | ATT clamp 0…3, theme Light/Dark, không tăng counter |
| Uptime/Boot wrappers | Target không bị chọn lại sau provider lookup; stage sidecar + canonical field | Seconds/timestamp dạng string, boot sidecar NSDate, display hours/date như trước |
| Schema v1 → v2 | Legacy reads, sidecars, schema marker và một counter bump trong cùng gate | Canonical boot ưu tiên hơn HardwareUUID; UDID theo toggle; ATT/LPM defaults và legacy battery compatibility |

GenerationCounter vẫn độc lập với publication revision và source commit UUID. Signed counter đạt NSIntegerMax trả lỗi trước staging thay vì overflow.

Failure behavior thay đổi có chủ đích: trước đây một số wrappers trả giá trị hoặc YES dù một file không ghi được. Nay trả nil/NO và lưu NSError; source engine rollback toàn nhóm hoặc giữ journal để từ chối capture khi recovery chưa xong. Plist malformed bị từ chối thay vì âm thầm reset thành dictionary rỗng. Không thay selection/validation policy khi operation thành công.

## Migration, concurrency và performance

Migration recheck schema sau khi lấy source gate, nên hai caller không cùng migrate từ một old copy và tăng counter hai lần. Reentry flag đổi từ process-wide BOOL sang thread-local, được phục hồi trong finally kể cả khi exception. Migration dùng directory đã chọn; không resolve lại active profile bên trong.

`profileIdentityPath` giữ read-only fast path khi schema đã >= 2. Rootful live readers vẫn đọc schema như trước và không acquire writer flock mỗi lần lấy path. Đây không phải bảo đảm reader consistency: rootful live readers chưa được chuyển authority, có thể vẫn nhìn thấy update đang diễn ra; publisher capture mới tham gia source contract.

Provider generation, uptime lookup, date formatter, log và custom compatibility callbacks nằm ngoài source gate. Riêng migration cũ thiếu UDID thực hiện bounded loop 40 lần sau schema/legacy checks dưới gate; không thêm DB load, network, queue hop hoặc callback trong gate. Không tạo random candidate mỗi lần đọc profile đã ở v2.

Chi phí writer tăng do journal before-images + commit marker và các atomic writes; relative cost moderate cho cold persistence, chưa có benchmark latency trên thiết bị. Không claim đây là tối ưu tốc độ. Registry dispatch_once tránh tái tạo mapping; phần giảm code lặp chủ yếu để giữ contract ghi nhất quán.

## Giới hạn còn lại

- Lower-level generators hiện cập nhật prepared cache của chính chúng trước persistence. Disk failure được báo và rollback file, nhưng không khẳng định toàn bộ provider cache rollback. Custom setters chỉ chạy sau top-level pair commit; cache publication chưa có ordering bảo đảm giữa hai caller đồng thời.
- Manager wrappers có generation/callbacks không được coi là composable trong một outer transaction. Profile/regenerate orchestration tiếp theo phải dùng pure stage helpers và thực hiện side effects sau outer commit; không bọc nguyên workflow trong một lexical lock.
- Model/iOS/cellular writers, legacy IMEI/MEID cleanup, whole regenerate, ProfileManager/Dashboard, security/defaults authority vẫn pending trong manifest. IMEI/MEID validation wrappers có lookup riêng trước save; transaction pair không tự chứng minh dependency validation và target selection của toàn workflow là atomic.
- Schema v2 đã bị ghi dở bởi binary cũ không có journal không thể tự suy ra/reconstruct chỉ từ version marker. Không có claim sửa dữ liệu mixed đã tồn tại trước protocol, hoặc durability khi mất điện.
- Profile directory create/delete và async generation/switch chưa có một lifecycle transaction. Source commit token chỉ bao phủ enrolled writers.

## Kiểm chứng

`scripts/test_runtime_identifier_writers.py --native` trích đúng production method bodies, static UUID helper và declarations vào Foundation fixture; compile cùng production staging/source engine/publisher. Chỉ path/backend, prepared-value providers và logging được stub. Fixture không thay thế compile toàn IdentifierManager/UIKit hoặc runtime iOS.

Cases: fixed target khi active profile đổi trong generation; current-schema path không vào writer gate; missing target/generation error; 16 custom mappings/counter policy; compatibility setter sau complete commit ngoài gate; pre-commit fault rollback và không publish custom cache; ATT/theme/uptime/boot schema; counter exhaustion; legacy boot/UDID/ATT/battery migration; corrupt input không bị thay; migration rollback/retry/idempotence; tám concurrent migrations tăng counter một lần; thread-local guard phục hồi sau exception. Concurrent fixture chỉ retry timeout contention có giới hạn. CI chạy ba process mới cho cả rootful và RootHide defines.

Host verification: **25/25** source/regression gates, **3/3** Node suites, backup audit **2600/2600**, generated fixture fragments và git diff --check pass. Windows không có xcrun/Foundation/Theos; native fixture và build mới còn chờ macOS CI. Native rootful/RootHide defines không thay thế package/build/device matrix riêng.

Không commit, push, deploy hoặc terminate ứng dụng trên thiết bị. Sau gate native/build, phần tiếp theo là model/iOS/cellular dependency group rồi profile workflow và defaults authority theo manifest.
