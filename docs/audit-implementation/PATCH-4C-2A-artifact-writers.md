# Patch 4C.2A — artifact writers theo target profile cố định

Người dùng xác nhận build 4C.1 và sửa helper rootful pass. Lượt này chuyển NetworkManager, WiFiManager, BatteryManager, UptimeManager và storage persistence vào source gate. Đây là **một phần của 4C.2**, chưa hoàn tất source-writer coverage hoặc toàn bộ Patch 4.

## Thay đổi và behavior

`PXRuntimeArtifactWriter` chứa production staging functions thuần Foundation. Input là explicit identity directory và dữ liệu đã chuẩn bị. Không lookup active profile, generate giá trị, tạo directory, gọi notification, dispatch hoặc sửa manager cache trong staging functions. Các nhóm stage có thể compose trong cùng outer transaction, RMW đọc được dữ liệu đã stage trước đó.

| Writer | Boundary mới | Quy tắc được giữ |
| --- | --- | --- |
| Network address pair | network_settings + device_ids | nil là giữ nguyên field, explicit IPv6 vẫn được phép thay; giữ unrelated keys |
| Single IPv4 | check/stage với IPv6 đang có; nếu thiếu thì prepare ngoài gate và recheck khi stage | ưu tiên network IPv6, rồi deviceIDs; chỉ generate khi cần; value vừa được writer khác commit thắng prepared fallback |
| Carrier | carrier_details + network_settings + device_ids | nil name/MCC/MNC chuẩn hóa thành chuỗi rỗng như trước; giữ network fields không liên quan |
| Wi-Fi | wifi_info + device_ids | SSID/BSSID mappings giữ nguyên; legacy payload thiếu key vẫn remove ID key như trước |
| Battery | battery_info + device_ids khi IDs tồn tại | không tự tạo IDs chỉ vì battery update; global legacy battery plist vẫn nằm ngoài nhóm này |
| Uptime | boot_time + system_uptime + device_ids | NSDate boot value, string uptime/boot timestamp, version và LastUpdated giữ schema cũ; cache chỉ cập nhật sau commit thành công |
| Storage | storage.plist dưới source gate | giữ các giá trị capacity/free/filesystem; NSUserDefaults enablement authority vẫn pending |

Thêm `dictionaryAtPath:exists:error:` vào transaction để phân biệt absent với existing empty dictionary, kể cả staged presence. API cũ delegate tới cùng implementation. Điều này giữ đúng battery semantics mà không thêm một lượt file read chỉ để stat/check existence.

NetworkManager chốt identity path một lần và truyền vào private persistence methods. Forced refresh/fallback getters cũng dùng target đã chốt: profile switch giữa lúc generation không đẩy dữ liệu của operation cũ vào profile mới. Prepare IPv6 không nằm trong source gate; fast path IPv6 đã có chỉ đọc mỗi source một lần rồi stage. Nếu cần fallback, lượt đầu no-op, prepare bên ngoài, lượt sau recheck trước merge.

Caller-supplied profile/path được kiểm tra trước tạo directory ở các đường đã sửa; không tạo identity directory từ một profile ID không hợp lệ. Storage/Uptime giữ target cụ thể. Profile deletion/creation đồng thời vẫn cần lifecycle contract riêng trong lượt sau; Network không tự tạo lại directory đã mất.

Không thêm hooks/swizzles/observers/timers hoặc notification mới. Những writer này vốn không có notification publication riêng; daemon vẫn thấy changes qua cơ chế đang có. Failure không log commit thành công; Network getter vẫn có thể trả prepared value khi persist lỗi như behavior cũ, chưa đổi return policy. Wi-Fi/Battery void APIs ghi lastError trên failure; caller propagation cho toàn bộ identifier/profile workflow vẫn pending. Successful profile persistence xóa error cũ của manager đó.

Legacy global battery write vẫn giữ vị trí ngoài profile transaction và có thể thành công khi profile commit lỗi; file đó không nằm trong runtime snapshot sources. Malformed existing artifact/IDs làm cả nhóm fail, không reset từng file thành dictionary rỗng rồi ghi một phần.

## Coverage còn thiếu

[Manifest](runtime-source-writers.json) đánh dấu năm manager writer groups enrolled. Fields có producer khác như deviceIDs, batteryInfo, network/carrier và boot/uptime vẫn partial. IdentifierManager generators/migrations, ProfileManager async create/switch/delete/default initialization, Dashboard model/storage group, direct security/defaults/cfprefsd writers chưa migrate.

Storage setters có thể gọi persistence nhiều lần cho một thay đổi model: lượt này chỉ enroll file writer, chưa coi model + ba storage setters là một transaction. Source commit metadata ghi `settings-scope-and-manager-artifacts-partial`; token không chứng minh consistency của writer chưa tham gia.

RootHide runtime hot consumers vẫn dùng captured views. Rootful legacy readers chưa chuyển authority và không được tuyên bố coherent chỉ vì writer đã dùng gate. Manager mutable caches chưa được tuyên bố thread-safe toàn diện. Khi migrate outer profile workflows, dùng pure staging APIs với explicit target và publish memory effects/notifications sau outer commit; không bọc generation/manager wrappers tùy ý vào transaction vì chúng còn side effects ngoài staging.

## Cost

Nhóm hai file thêm journal + commit marker (hai atomic writes và before-images); carrier/uptime ba file cũng thêm hai control writes. Relative cost moderate trên cold generation/persistence, không phải performance optimization. Existing IPv6 fast path tránh generation và tránh đọc lại cùng pair; missing IPv6 cần hai source-gate entries, lượt đầu không ghi journal. Không có benchmark mới, không thêm I/O vào captured hot hook API. Legacy rootful getter fallback khi artifact thiếu vẫn có thể gọi writer đồng bộ, nên I/O latency/permissions trên device cần xác nhận.

## Kiểm chứng

`test_runtime_artifact_writers.py --native` compile production NetworkManager, CarrierDB, stage helpers và source engine. Fixture backend chỉ định temp paths/source-store selection, deterministic interface/carrier generation subclass và log sink; không viết lại merge/commit logic. Cases: IPv6 precedence/fallback/no regeneration, nil/empty behavior, fixed target khi profile đổi trong prepare, competing IPv6 fill, carrier refresh target, staged composition, battery absent IDs, Wi-Fi key removal, exact field types/aliases, rollback/commit identity, malformed sibling, concurrent address/carrier merges không mất fields. Không gọi network request hay mutate device/app data trong fixture.

Native fixture chạy ba process mới trong CI. Wi-Fi/Battery/Uptime/Storage manager UI/platform paths vẫn cần Theos build và device tests; native pure-stage tests không thay bằng chứng đó. Header compile check rootful/RootHide cũng include staging header. Windows không có xcrun/Foundation/Theos để tự chạy native gate mới.

Kết quả host: 24 source/regression gates pass; backup audit PASS 2588/2588; ba bộ Node canvas/web/WebGL và git diff --check pass. Không commit/push/deploy hoặc terminate ứng dụng trên thiết bị. Sau native/build gate mới, tiếp tục IdentifierManager + ProfileManager orchestration và defaults authority theo manifest, không bỏ qua các writer pending.
