# Patch 3 — Concrete location delegates

Ngày: 2026-10-24. Baseline: `74c974b`. Trạng thái: source implemented; host source/regression gates PASS. Người dùng xác nhận build Patch 3 pass trước khi triển khai 4A.1. Host Windows không tự chạy native fixture; chưa có log riêng để xác nhận từng fixture/lane/device matrix.

## Vấn đề và thay đổi

Hai nhóm `%hook NSObject` trước đây thêm/intercept các CoreLocation optional callback trên root class. Điều này có thể làm thay đổi capability probing của objects không phải location delegate. Đồng thời, delegate có implementation override riêng không nhất thiết đi qua hook ở NSObject.

Patch xóa cả hai nhóm đó. `CLLocationManager.setDelegate:` nay gọi `PXInstallLocationDelegateHooks` trước original setter, để xử lý callback đồng bộ hoặc capability caching trong native setter. Original setter vẫn gọi một lần; getter trả đúng native delegate, không proxy/replace. Các log/jitter setup hiện có giữ nguyên.

`PXLocationDelegateHooks.m` chỉ intercept năm selector đang có implementation thực tế trên concrete runtime class: modern batch, legacy pair, heading, enter region và exit region. Chỉ forwarding/`respondsToSelector:` không đủ để fabricate method. Nếu thiếu method hoặc return/argument ABI không phù hợp, bỏ qua method đó. Root NSObject/NSProxy và metaclass bị loại trừ rõ ràng.

Registry dùng class + selector dưới installation lock. Với inherited method, `class_addMethod` tạo slot riêng trên concrete class; không mutate Method của superclass. Original IMP được seed trước publication và cập nhật atomic nếu runtime trả previous IMP khác. Installation idempotent và hỗ trợ nhiều delegate class/manager.

## Callback semantics

- Giữ nguyên manager, NSArray, từng location/heading/region object, argument order và thread gọi callback. Không copy array, redispatch hoặc tự tạo callback.
- Modern batch và legacy pair lấy một snapshot có advance generation cho mỗi callback hợp lệ; cả batch hoặc cặp new/old dùng cùng snapshot trước khi gọi original delegate.
- Heading dùng current snapshot; region vẫn đọc current snapshot và forward callback, không advance hoặc suppress callback.
- TLS stack phân biệt super-chain bằng receiver/manager/selector và quan hệ ancestor của hook class. Override gọi super không advance thêm; nested callback mới gọi lại cùng concrete class vẫn là event riêng. `@finally` khôi phục frame kể cả khi original delegate throw; exception của delegate tiếp tục propagate.
- Projection exception được bắt riêng trước original invocation, để lỗi của adapter không làm mất callback app. Không catch/suppress exception từ delegate gốc.
- Trước projection, kiểm tra native `manager.delegate == receiver`. Callback cũ sau thay/nil delegate vẫn forward; không advance hoặc gắn snapshot mới cho relationship đã hết hiệu lực. Đây là giới hạn có chủ đích cho callback cũ, thay cho interception process-wide trên NSObject. Callback đã vào original khi relationship/toggle đổi vẫn hoàn thành, không bị redispatch hoặc gọi lại.
- Provider gọi `PXActiveLocationSnapshot` hiện có ở mỗi callback; không cache enabled/scope decision. Off/out-of-scope vẫn forward original. Direct location/heading/getter hooks và MapKit projection giữ nguyên.

`common/LocationSpoofingManager.m` đổi snapshot association từ nonatomic retain sang atomic retain. Snapshot vẫn immutable sau publication; atomic association giúp getter giữ value sống qua concurrent replacement. Thay đổi này bảo vệ ownership của association, không biến toàn bộ LocationSpoofingManager thành một transaction hoặc sửa các source/cache races ngoài phạm vi Patch 3.

## Memory, threading và overhead

Registry/hook blocks giữ class và hook records suốt process; không giữ delegate/manager instances. Provider và attacher là function pointers, không capturing blocks. TLS chỉ chứa frame trên stack trong callback, không có async pointer hoặc cleanup callback tới object đã dealloc. Native delegate tiếp tục quản lý weak relationship của nó.

Installation lock chỉ nằm ở setter/installation path; callback không giữ lock này khi gọi provider, attach hoặc original delegate. Callback thêm state lookup qua native delegate getter và duyệt TLS/superclass chain; snapshot lookup/attachment là công việc cần thiết để giữ batch consistency. Không thêm timer, polling, queue, network/file I/O hoặc logging. Các settings/logging hiện có trong manager/setter chưa được tối ưu tại đây.

Relative cost dự kiến thấp cho class/stack checks; phần snapshot/scope có thể đáng kể ở workload nhiều callback và vẫn cần profiling. Không có số benchmark để kết luận net CPU/latency giảm. Bỏ root-class surface là sửa correctness/compatibility trước tiên.

## Verification đã chạy trên host

| Gate | Kết quả |
| --- | --- |
| Location source contracts | PASS; không hàm ý native runtime pass |
| iFake parity + final crosswalk | PASS; selector coverage chuyển sang concrete adapter, không xóa covered surface |
| Thread safety/cleanup P3 | PASS 80/80 |
| Security UI/runtime/iOS12 source contracts | PASS |
| Bootstrap topology | PASS 27 constructors |
| Missing-hook completion + native OS runtime safety source gates | PASS |
| Phase-B regression + RootHide source gate | PASS |
| WebKit unscoped zero interference | PASS |
| Phase-10 release hardening static | PASS |
| Backup/restore audit | PASS 2524/2524 |
| Diff whitespace | PASS |

Audit tăng 12 per-file checks so với Patch 2 vì thêm helper header/implementation và native fixture; không thay semantic guards của audit. Không giảm kiểm tra backup/restore.

## Native fixture và gate còn lại

`tests/PXLocationDelegateTests.m` compile trực tiếp production helper với Foundation/CoreLocation. Fake snapshot provider/manager/delegates dùng để điều khiển scope/toggle/generation và dispatch behavior; có thêm CLLocation value objects thật để kiểm tra identity, order và metadata sau attachment. Fixture không start GPS, request authorization hoặc network.

Coverage: absent optional selectors, forwarding-only delegates, invalid scalar/block/return ABI, inherited class isolation theo hai thứ tự installation, override/super, nested callbacks, multiple managers, repeated registration, nil/changed delegate, empty/nil location input, off/on policy, projection/delegate exceptions, 32 concurrent first installations/callbacks, weak lifetime và in-flight delegate/toggle change. Kiểm tra root NSObject selector surface trước/sau toàn bộ fixture.

CI chạy `python3 scripts/test_location_direct_semantics_static.py --native`: compile ARC/blocks + production helper, chạy fixture trong ba process mới để lặp lại first-install paths. Release regression runner chạy source contracts. Build Theos lấy helper qua wildcard `.m` hiện có.

Chưa có bằng chứng từ host Windows cho:

1. Build Patch 3 do người dùng xác nhận pass; chưa có log compile/run fixture theo từng case hoặc kết quả từng rootful/RootHide lane để ghi độc lập. Source checks không thay compiler/runtime.
2. Native CLLocationManager setter/callback delivery trên iOS, callback run loop thực tế, delegate capability caching và scope/toggle integration với manager thật.
3. arm64e/hook-runtime matrix, nhiều tweak cùng swizzle, class đổi động/KVO hoặc private framework delegate/proxy behavior. Class-local installation giữ original chain tại thời điểm cài; không bảo đảm một swizzler khác sau đó vẫn giữ chain.

Session location manager/delegate đã được gán trước khi setter hook được cài không tự động được enumerate để retrofit. Forwarding-only selectors không được synthesize; direct object getters vẫn theo cơ chế cũ. Nếu delegate thay runtime class sau registration, cần setter lại hoặc đánh giá riêng trên device, không mặc định mọi dynamic subclass đã được cover.

Không sửa headingAccuracy hoặc CLRegion.containsCoordinate trong patch này; hai semantic defects đó vẫn thuộc Patch 6. Không sửa movement simulator hoặc publication/snapshot pipeline của Patch 4. Patch tiếp theo: 4A — captured runtime reader API.
