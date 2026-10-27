# Patch 4C.2H3S — pinned timezone lookup lifecycle

Người dùng xác nhận build H3R pass. H3S xử lý hai reverse-geocode timezone adapters trong Time detail/Security. Source dùng chung rootful/RootHide. Region sync HTTP worker và IP/country display callbacks không được coi là đã sửa lifecycle ở mốc này.

## Vấn đề và scope

Geocoder cũ là local object, không có owner capability để revoke lookup trước; callback Time detail chỉ kiểm tra self/name rồi ghi timezone. Mode hoặc pin có thể đổi trong lúc request chạy. Security refresh cũng không gắn kết quả với pin hiện tại và completion capture controller mạnh; kết quả cũ có thể cập nhật timezone/display mới. Lifetime chính xác của request bên trong CLGeocoder cần runtime evidence, không kết luận chỉ local variable đã chứng minh một leak hay cancellation bug của framework.

Không chuyển toàn bộ `syncTargetRegionFromIPTapped:` lên main: callback này đang có source/GPS/cache I/O. Cần một worker ordering/acknowledgement design riêng để vừa xử lý newer intent vừa không đưa toàn bộ I/O vào UI thread. H3S giới hạn ở lookup, currentness checks và main-thread consumer handoff của timezone.

## Thay đổi

`PXPinnedTimeZoneLookup` giữ một CLGeocoder và một NSObject token cho request mới nhất của từng owner. Resolve/cancel route main nếu caller ở background; resolve revoke/cancel lookup trước, validate coordinates và chỉ tạo backend khi có completion hợp lệ. Completion backend dispatch main, check token/weak lookup, clear old request state trước khi gọi consumer để re-entry không xóa request mới. Cancel/superseded/duplicate callbacks không gọi consumer. Error/empty/malformed placemark trả error trên main, không gửi selector tới payload sai kiểu.

Lookup không capture self mạnh trong backend block; hai consumers capture owner yếu. Dealloc chỉ cleanup backend; nếu owner release từ background, block cancel giữ geocoder riêng để chạy trên main, không resurrect lookup/self. Header ghi consumer owning lookup phải weak-capture owner: utility không thể ngăn một arbitrary caller tự tạo cycle bằng completion mạnh.

Time detail chỉ bắt đầu khi stored mode là Use Location và pin có NSNumber coordinates. Trước persistence recheck mode và pin bằng pure `PXPinnedCoordinateMatchesLocation`. Successful mode selection cancel request trước publish/resolve mới; failed mode persistence vẫn giữ lookup cũ của persisted mode. Không đổi mode write/notification/haptic policy của successful handler.

Security refresh cancel lookup trước khi thay view/đọc pin, dùng typed numeric coordinates và weak timezone consumer. `getTimeZoneForLocation:completion:` dùng cùng lookup, recheck actual pin trước callback và luôn deliver consumer trên main; nil completion không tạo geocoder. Security vẫn lookup/display pin kể cả khi Time Spoof mode không bật như behavior cũ. Active valid result vẫn dùng timezone.name và H3R verified persistence adapters/notification policy.

Malformed/nonfinite/out-of-range coordinates fail trước backend request. Numeric pin policy ở Time detail giữ nguyên; Security không còn coi string/NSNull coordinates là valid numeric pin. Không thay geography provider, không thêm endpoint, retry, polling, rounding, persistent cache hoặc process hooks.

## Kiểm chứng

Native fixture include actual utility `.m` sau khi pre-import SDK headers, alias chỉ CLGeocoder/CLPlacemark backend sang controlled doubles. CLLocation/coordinate validation, NSTimeZone, GCD/main-run-loop và ARC/weak lifetime là Foundation/CoreLocation thật. Hai UI adapter methods được extract nguyên source thành hai fragments. Mode/current pin providers và persistence consumer được mô phỏng; H3R source-store/notification fixture vẫn kiểm tra verified write adapters riêng. Không thực hiện geocoding/network/permission request hoặc ghi preferences/GPS thật.

Cases: latest lookup/cancel/late error/duplicate result, current result đúng một lần/main, consumer re-entry start mới, backend error/empty/malformed response, invalid coordinate/nil completion không launch backend, background resolve/cancel, background owner release cleanup trên main, core/controller dealloc khi backend còn pending, pin/mode đổi trước callback, latest Time detail persist, Security pin freshness và main completion, background UI-adapter entry, missing pin/inactive mode, typed coordinate comparison. Mode-handler/refresh cancellation và weak caller capture được source gate kiểm tra; không thay thế UIKit/device smoke test.

CI đăng ký `test_pinned_timezone_lifecycle.py --native`; runner thử rootful và RootHide-defined lanes độc lập, tổng hợp lỗi sau cả hai, mỗi binary chạy ba lần. RootHide-defined host fixture không phải real injected-process/namespace validation. Windows không có Foundation/xcrun/Theos: native compile/runtime/package H3S chờ macOS CI.

Windows chạy toàn bộ 64 release-inventory Python/Node suites và ba extras RootHide/iOS DB/backup audit: 66/67 pass. Suite Keychain Bridge migration còn vướng Git Bash Permission denied tại `/c/Users/ADMIN`; không claim full release pass. Source/macro checks và diff check pass. Exact adapter extraction: pinned timezone 2, security 6, IP lifecycle 4, device-group 3, identifier 4, artifact-preparation 6, profile-creation 3; utility được native fixture include nguyên source.

## Performance và boundaries

Một reused lookup owner/UIViewController, một token/lookup và tối đa một backend được tracked cho owner đó. Supersession yêu cầu cancel backend cũ; không chứng minh socket/geocoding service dừng ngay khi cancel trả về. Các callback stale bị loại trước persistence/consumer pin reads. Main handoff và token compare expected low overhead trên cold UI action, chưa có CPU/memory/latency benchmark.

Currentness guards thêm live mode/pin reads; source persistence vẫn synchronous trong main consumer và có contention/deadline của store hiện hành. Không claim main-thread I/O hoặc latency đã được giải quyết. Không coalesce giữa hai controllers hoặc cache geography results. Old local request sẽ bị hủy khi owner/new intent revoke; chuyển sang completion trên main là thread-safety correction, không đổi valid timezone selection.

Pin comparison là value check trước persistence, không atomic với GPS file hay cross-process source write. Equivalent-coordinate/mode ABA và updates qua controller/process khác không có global intent revision; một global workflow receipt/CAS vẫn là boundary riêng. Existing country/IP callbacks còn có ordering/lifetime/parser/cache concerns, và có thể giữ Security controller cho request của chúng dù geocoder branch đã weak. Full `syncTargetRegionFromIPTapped:` stale response/worker ordering, GPS/cache consistency, defaults/cfprefsd authority, metadata/indicator/metrics writers, rootful captured readers và directory durability tiếp tục theo plan.
