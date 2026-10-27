# Patch 4C.2H3R — TargetRegion and timezone security writers

Người dùng xác nhận build H3Q pass. H3R enroll phần security writes của pin region và timezone callbacks, dùng chung production code cho rootful/RootHide. Patch 4 và canonical preferences authority vẫn partial; không coi toàn thao tác pin GPS/region là một transaction.

## Vấn đề và flow cũ

`syncTargetRegionFromIPTapped:` ghi nhiều pin fields vào NSUserDefaults, sau đó ghi networkISOCountryCode bằng shared store riêng và cuối cùng synchronize defaults. Khi network ISO commit fail, callback return nhưng các defaults values trước đó đã dirty và có thể flush sau. Source capture cũng không có một packet chứa cả pin identity và legacy network ISO. Toggle follows-IP không kiểm tra persistence trước ba notifications. Ba timezone callbacks trong Security/Time detail ghi defaults trực tiếp rồi notify dù không có verified source acknowledgement.

## Thay đổi

`persistPinnedTargetRegionFromResponse:error:` nhận typed geo response, require success/nonempty country+zone/numeric coordinates như callback cũ; lấy catalogue defaults qua helper hiện hành. Require các mandatory carrier/locale values là NSString trước tạo dictionary, tránh nil/unsafe dictionary construction nếu catalogue bị lỗi. Sau đó merge tất cả region security keys và conditional legacy network ISO qua một `PXWriteSecuritySettings` packet. Shared writer deep-detach trước gate và giữ rollback bytes/source token khi commit fail.

Giữ country uppercase, double coordinates/timestamp, catalogue fallback và successful value policy. preferredLanguages chỉ ghi nếu là NSArray; optional source IP thiếu/rỗng và languages không phải array không xóa giá trị cũ. Carrier ISO rỗng vẫn được ghi vào pin field nhưng không overwrite legacy network ISO. Không thêm strict country/coordinate/timezone validation hoặc thay fallback carrier values; invalid property-list graph được shared serializer reject toàn packet.

Callback sync chỉ đi tiếp sang IPStatusCacheManager, GPS plist, notifications và final UI success sau primary security commit. Failure không để lại một phần primary security fields và không chạy downstream steps. Helper không tự notify: thứ tự các GPS/cache compatibility steps trước ba topics của callback cũ được giữ.

Toggle dùng verified bool writer; failure restore previous switch và return trước publish. Success dùng `publishTargetRegionChanged` với ba topics/settings/carrier/networkISO và số lần cũ cho cả bật và tắt.

Security pinned-location/IP discovery dùng `persistTimeZoneName:forKey:`; Time detail dùng `persistLocationTimeZoneName:`. Mỗi adapter chỉ notify settings-changed sau successful shared source write. Existing IP callback vẫn skip write nếu discovered name bằng saved name; location callbacks vẫn ghi/notify mỗi valid result như trước. Informational timezone display/currentTimeZoneId vẫn giữ candidate behavior khi persistence fail; không giả UI display là committed source. Time detail bỏ private defaults instance đã không còn consumer.

## Boundary còn partial

Primary security packet không bao GPS spoofing plist và IPStatusCacheManager. Các compatibility steps sau commit còn có void/unchecked write APIs; GPS/cache failure không rollback primary commit và existing final feedback chưa có structured whole-operation receipt. RootHide GPS path/namespace, location cache authority và multi-file pin durability chưa sửa trong mốc này.

Không đổi endpoint/request/timeout, geocoder lifetime, thread routing hoặc request generation. Concurrent sync/geocoder callbacks vẫn có thể về khác thứ tự, callback cũ có thể overwrite intent mới; cần lifecycle guards riêng. Một vài display callbacks còn có UIKit/main-thread assumptions. Mode selection và discovery timezone là các phases riêng; không claim location/mode/zone coherence là atomic. Generic defaults mirrors/cfprefsd và unenrolled writers vẫn ngoài full source authority, cache ordering/convergence còn pending.

## Performance

Một primary pin packet có một source commit, không có separate commit cho network ISO. Flow cũ không có một journaled transaction cho mỗi defaults setter: chỉ network ISO đi qua source engine, các pin fields là defaults writes riêng. Lợi ích đã chứng minh là related fields join một commit/capture boundary, không phải benchmark I/O giảm theo số key.

Packet thêm dictionary/detach/journal work; generic writer mirror cả ba legacy suites, nên nhiều pin fields nay cũng được mirror sang compatibility suites. Expected low–moderate cost trên explicit sync hoặc timezone discovery, chưa có CPU/latency benchmark. Không thêm queue/timer/polling/hot hooks. Xóa một defaults allocation trong Time detail là cleanup nhỏ, không phải performance claim chính.

## Kiểm chứng

Existing security native runner extract catalogue-fallback/primary packet/toggle/notifications/timezone adapters vào hai fragments mới, tổng security fixture sáu fragments. Actual source engine/store được link; CarrierDB provider, UIKit switch/toast và defaults mirrors được mô phỏng, notifications bị intercept. RootHide host fixture vẫn mô phỏng manager-role live read; không suy thành captured injected-reader/device proof. Không gọi geolocation endpoints, geocoder hoặc ghi GPS/preference domains thật.

Cases mới: full packet + network ISO một commit, frozen mutable timezone/MCC/source-IP trước mirrors, unrelated-field preservation, optional omission/empty ISO policy, typed malformed payload/status/catalogue error, non-property-list language rejection, legacy catalogue fallback, source-written fault rollback bytes/token/mirrors/notifications cho primary pin và ba timezone adapters, failed enable/disable switch rollback, successful toggle giữ ba topics, timezone success chỉ notify sau commit, nil/empty zone no-op. Macro arity gate bao fixture này. Source gate extract actual sync callback để kiểm tra verified helper/failure return trước GPS/cache/publish và không còn defaults writes trong primary block.

Windows: toàn bộ 63 release-inventory Python/Node suites và ba extras RootHide/iOS DB/backup audit đạt 65/66 pass. Suite Keychain Bridge migration vẫn fail do Git Bash Permission denied tại `/c/Users/ADMIN`; không claim full release pass. Relevant source/macro gates và diff check pass. Exact extraction pass: security 6, IP lifecycle 4, device-group 3, identifier 4, artifact-preparation 6, profile-creation 3.

Native runner hiện có trong CI compile/run rootful và RootHide-defined configurations. Windows không có Foundation/xcrun/Theos: native compile/runtime/package H3R cần macOS CI xác nhận. Source checks/extraction không thay thế native tests, physical cfprefsd behavior, catalogue fidelity hay UI/network/device matrix.

## Tiếp theo

Region/timezone callback lifecycle và GPS/cache consistency cần bước riêng; remaining UI/indicator/metrics/defaults writers, canonical preferences authority, metadata, whole Reset Data, rootful captured readers và directory durability vẫn pending/partial. Không đưa security source lên enrolled toàn phần chỉ vì một adapter mới đã join transaction contract.
