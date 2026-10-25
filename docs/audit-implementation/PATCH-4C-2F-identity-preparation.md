# Patch 4C.2F — model/scalar preparation và deferred cache publication

Người dùng xác nhận build 4C.2E pass. Lượt này tách model/scalar preparation, đưa các wrapper IdentifierManager qua prepare → persist → publish cache, và sửa Serial object-lifetime issue. Whole-regenerate transaction và profile lifecycle/completion vẫn **pending**; source coverage chưa tăng chỉ vì có preparation APIs.

## Model packet

prepareDeviceProfileGroupWithOptions:error: nhận flags webCompat/wantsIMEI/wantsMEID đã capture, kiểm tra shape và copy options trước provider work. Giữ canonical DB/model/build/variant/regulatory/cellular policy, required-field checks và bounded WebCompat attempts. Builder không chọn profile, không viết runtime sources, không sửa self.error hoặc publish identifier/version caches. DB reads/metadata initialization và failure diagnostics vẫn có thể có I/O, nằm ngoài source gate; không gọi builder là mathematically pure.

`PXPreparedDeviceProfileGroup` chứa updates, replacedKeys và versionInfo. Constructor dùng một immutable property-list detach cho cả graph, nên mutable string/array/dictionary từ provider không thay đổi candidate sau prepare. Packet không giữ transaction, provider instance, callback hay active-profile selection.

Wrapper hiện tại chọn target một lần, prepare packet, stage replacement/legacy cellular deletion/counter bằng source transaction rồi gọi publishPreparedDeviceProfileGroup. Callbacks IOSVersionInfo và DeviceModelManager vẫn ở sau commit; counter/CommittedAt và successful tuple policy được giữ. Các flags của operation được capture trước DB work thay vì đọc lại trong quá trình generate.

## Scalar factory và đường production

`PXRuntimeScalarPreparation.h/.m` chuẩn bị IDFA, IDFV, DeviceName, chín UUID v4 và UDID mà không tạo provider, sửa cache, ghi source/preferences hoặc notify. Các standalone provider generate APIs dùng lại factory và vẫn publish cache khi gọi trực tiếp, theo contract cũ.

IdentifierManager dùng factory trực tiếp, hoặc Serial policy adapter, rồi commit sidecar + IDs. Chỉ sau top-level commit mới gọi compatibility setters. Disk failure không còn để lại prepared scalar trong provider cache của đường IdentifierManager này. Custom-value publisher giữ subset legacy: không tự thêm DeviceName/Serial cache update vào custom API vốn không làm việc đó.

Formats/policy được giữ:

- IDFA/IDFV uppercase hex và legacy format validation, 32 secure-nibble calls, các entropy error codes 1001/2001.
- DeviceName giữ templates, indices, validation, primary entropy failure 3001 và secondary time fallback.
- Chín UUID giữ lowercase v4/version/variant, arc4random policy và error-domain mapping của từng provider. Immutable domain registry khởi tạo một lần.
- UDID giữ 40 lowercase hex. Không hợp nhất IMEI/MEID vào scalar generation hoặc bỏ regional policy adapter.

## Serial: memory safety và concurrency

**High — clearSensitiveData:** trước đây cast UTF8String của NSString sang char* và memset vào buffer do NSString sở hữu. Với immutable/shared/constant/tagged storage, thao tác này có thể gây crash hoặc làm hỏng giá trị đang được object khác giữ. Nay chỉ bỏ strong reference của manager. Đây không phải secure zeroization; NSString immutable không cung cấp quyền ghi/erase vào borrowed UTF-8 storage. Nếu cần zeroization thật phải có một mutable byte buffer có ownership rõ ràng, không ép ghi qua NSString.

**Medium — prefix rotation:** static int patternIndex trước đây có data race. Policy adapter dùng atomic compare/exchange cho chu kỳ modulo 5, giữ first prefix/order cũ. Reservation vẫn tiêu thụ một prefix khi entropy hoặc persistence về sau fail, giống thứ tự generation cũ; không coi reservation là rollbackable source state.

prepareSerialNumber giữ environment/integrity checks, delay 0–50ms và validation; trả candidate mà không thay cached identifier. Factory PXPrepareRuntimeSerial chỉ tạo giá trị cho explicit prefix được chấp nhận, không tự bypass các checks đó. Standalone generateSerialNumber vẫn publish khi gọi trực tiếp; IdentifierManager publish setter sau commit. Nếu environment đổi trước setter, cache có thể từ chối publication theo policy hiện tại; source commit vẫn là operation đã commit, không báo giả là rollback.

## Performance và giới hạn

Không thêm hook, timer, polling hoặc queue. Heavy DB/entropy/generation nằm ngoài source gate. Deep detach model graph có allocation/serialization cost moderate ở cold path; không có benchmark latency/throughput. UUID error-domain registry tránh tạo lại dictionary cho từng value. Serial delay vẫn được giữ, không claim đã tối ưu latency của policy đó.

After-commit ordering được bảo đảm cho từng wrapper; chưa có total ordering giữa hai concurrent cache publishers, chưa làm toàn bộ singleton settings/error/cache state thread-safe. Builder không pin toàn bộ catalog generation của nhiều DB providers. Profile selection/directory lifecycle, defaults authority và rootful reader rollout vẫn có coverage riêng đang pending.

## Kiểm chứng

- Existing identifier native fixture dùng exact production flow/publisher với real scalar factory và entropy backend. Các case target switch, rollback, custom policy và generation counter tiếp tục được giữ; thêm assertion cache chỉ publish sau complete commit và không publish khi persistence fail.
- Existing model native fixture trích cả builder/publisher production: prepare không source write/profile lookup/cache publication; mutable options không đổi intent đã capture; independent staging rồi explicit publication; deep detach nested provider graph; malformed ownership keys/flags bị từ chối.
- New `test_runtime_identity_preparation.py --native` compile real scalar factory, validator và 13 lower-level providers, với entropy backend. Kiểm tra formats/case/version/variant, DeviceName templates/fallback, entropy error codes và cache preservation, Serial prepare/clear và 20 concurrent prefix reservations trên các instances riêng. Serial policy được điều khiển bằng subclass test adapter; không coi đó là kiểm chứng debugger/integrity detection trên thiết bị.
- Native suites chạy ba process mới cho cả rootful và RootHide defines. Header mới vào strict nullability compile check. Các selected-method fixtures không thay full UIKit/Theos build hoặc runtime process matrix.

Host result: **32/32** source/regression gates, **3/3** Node suites, backup audit **2628/2628**, generated fragments và git diff --check pass. Native fixture/build mới chờ macOS CI; Windows không có Foundation/xcrun/Theos.

## Phần tiếp theo

Artifact preparation từ 4C.2E và model/scalar preparation từ 4C.2F hiện được dùng trong production wrappers. Bước kế tiếp là captured profile/options context, compose tất cả prepared stages trong một outer commit, rồi deferred cache/notifications. Sau đó mới chuyển create/switch completion và active-selection ordering, cùng directory recovery boundary. regenerateAllEnabledIdentifiers và ProfileManager vẫn pending trong manifest; không bọc các standalone auto-save/callback APIs trong lexical source lock.

Không commit, push, deploy hoặc terminate ứng dụng trên thiết bị trong lượt này.

## CI follow-up — scalar fixture class-cluster assertion

CI báo native scalar suite **41/50**, với đúng chín lỗi `scalar formats preserve case version and variant`. Assertion cũ ghép format/version/variant với `![value isKindOfClass:NSMutableString.class]`. Class membership không phải phép kiểm tra mutability đáng tin cậy cho Foundation class clusters; xem [Apple Object Mutability](https://developer.apple.com/library/archive/documentation/General/Conceptual/DevPedia-CocoaCore/ObjectMutability.html). Production factory vẫn trả `[uuid copy]`; không thay RNG, format, validator hoặc provider/cache behavior để ép test pass.

Fixture bỏ suy luận mutability từ class, giữ validation và thêm oracle UUID literal cho bảy RNG words trên cả chín type: đủ variants 8/9/a/b, lowercase a–f và UINT32_MAX. Kiểm tra mutable-copy edit và lần generate kế tiếp không thay giá trị trước đó; diagnostics khi fail ghi type, word, value, class và error. Source gate giữ contract production `[uuid copy]` và chặn đưa assertion class membership này trở lại.

Kiểm chứng follow-up trên Windows: **7/7 related source gates**, **7/7 fixture vectors** được kiểm tra độc lập bằng Python UUID, `git diff --check` pass. Đây không phải native execution: macOS rootful/RootHide native suite cần chạy lại trong CI. Không đổi coverage manifest hoặc mở sang profile lifecycle ở fix này.
