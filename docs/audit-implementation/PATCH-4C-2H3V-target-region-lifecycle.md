# Patch 4C.2H3V — TargetRegion request and toggle ordering

Người dùng xác nhận build H3U pass. H3V tiếp tục Patch 4 trên source chung
rootful/RootHide; không đổi bootstrap RootHide, injection scope hoặc hook policy.

## Lỗi và thay đổi

Sync cũ tạo ephemeral NSURLSession nhưng không finish/invalidate rõ ràng, giữ
controller qua completion và không có generation guard. Response sync A có thể
ghi đè sync B mới hơn, cập nhật toast/switch sau khi owner đổi intent. Một sync đã
vào source write còn có thể ghi `targetRegionFollowsIPEnabled=YES` sau toggle OFF
độc lập trên main. Chỉ hủy task/check token ở network completion không giải quyết
được trường hợp source write đã bắt đầu.

`PXTargetRegionSync` giữ session/request token và intent token trên main, worker
token dưới short unfair lock, cùng một serial work queue theo owner. New sync hoặc
toggle revoke intent cũ trước cancellation. JSON parsing giữ ở transport callback;
main admission xác nhận request/intent và finish session trước queued apply.
Duplicate/stale/error callback không chạy apply hoặc cập nhật UI cũ. Root/status/
field type checks và các error messages giữ policy trước; endpoint HTTPS ip-api,
fields, ephemeral configuration và timeout request/resource 10/15 giây không đổi.

Queued work kiểm tra token trước effects. Admitted work có thể hoàn tất sau một
intent mới; queue bảo đảm toggle mới chạy sau toàn bộ admitted sync source/GPS/
cache/notification effects. Nếu toggle OFF commit thành công thì trạng thái cuối
của chính controller này là OFF; source failure trả rollback state thực tế đã đọc
trên worker, không báo thành công hoặc giả rollback sync đã commit.

UI toggle acknowledgement nay bất đồng bộ: switch thể hiện lựa chọn ngay như
UIKit thông thường, worker commit rồi main xác nhận/restore. Không chờ worker hoặc
giữ intent lock qua I/O trên main. Superseded queued toggles cũng bị bỏ trước
commit; chỉ current intent nhận feedback. Đây là thay đổi cần thiết cho thứ tự
giữa admitted sync và explicit toggle, không phải chỉ đổi code cho đẹp.

## Lifetime và các effects

Network/apply callbacks weak-capture controller. Owner mất khi đang chờ network
thì session bị cancel; queued apply không làm sống lại UI. Controller chỉ được giữ
tạm khi admitted callback thực sự đang xử lý source/GPS/cache I/O.

Explicit toggle copy BOOL vào source-only work block, không capture controller
hoặc switch mạnh. Coordinator tự được giữ đến lúc queued explicit command xử lý,
nên pop/dealloc UI không làm mất lựa chọn đã nhận. Supersession bởi intent mới
vẫn được phép bỏ command cũ. "Survive owner release" chỉ là lifetime trong process,
không phải crash durability hoặc guaranteed persistence khi process bị kill.

`PXPublishTargetRegionSettings` tập trung ba Darwin topics cũ; method wrapper và
toggle commit dùng chung helper. Publish sau source success và ngoài source gate.
`applyTargetRegionResponse` giữ thứ tự primary security commit -> pinned cache ->
GPS plist -> notify -> main success feedback. GPS path tách thành accessor để native
fixture dùng temporary directory, production path không thay đổi.

GPS/cache vẫn là compatibility phases riêng. Chưa xử lý GPS write failure, atomic
security/GPS/cache receipt, IPStatusCacheManager multi-writer races hoặc directory
durability. Không claim "sync transaction" bao toàn bộ nhóm effects.

## Kiểm chứng

`scripts/test_target_region_lifecycle.py --native` thử rootful và RootHide-defined
lanes độc lập, ba lần/binary, đăng ký trong CI. Fixture include nguyên production
coordinator; chỉ alias NSURLSession transport sau SDK imports. Ba C helpers và bốn
controller adapters extract nguyên source. Foundation JSON/GCD/lock/weak ownership,
CoreLocation coordinate values và GPS plist I/O trên temporary path là thật.
Primary security store/cache/UI dùng controlled stubs; không gọi API mạng thật.

Cases: stale/duplicate response, session cleanup/request policy, pending sync rồi
toggle, queued sync/rapid toggles superseded, admitted sync rồi OFF, failed primary
commit không chạy downstream effects, failed toggle restore trên main, malformed
service JSON/error feedback, weak network owner/dealloc, detached explicit toggle
survive UI release và background entry. Macro-arity checker bao gồm fixture mới.

H3R actual-source fixture tiếp tục chạy actual security transaction/fault injection
và ba notification topics bằng extracted commit/publisher helpers mới. Những cases
đó kiểm tra returned rollback state thay cho gọi UI action đồng bộ đã retire.
New lifecycle fixture chạy chính UI adapter bất đồng bộ và kiểm tra switch restore;
không bỏ persistence failure assertions để làm gate pass.

Source/host checks, exact fragment extraction và macro/diff checks chạy trên Windows.
Foundation native compile/Theos/package/device H3V chờ macOS CI. Controlled fixture
không chứng minh actual network service, UIKit, sandbox hoặc full device matrix.

Local regression inventory: 62/63 Python suites và 4/4 Node suites pass. Suite
bridge migration shell còn Permission denied tại `/c/Users/ADMIN`; không ghi nhận
full release pass. Source hardening, RootHide build contracts và package metadata
checks pass. Exact fragments: region lifecycle 2 files (ba helpers/bốn adapters),
security actual-source 7 files; macro arity và diff checks pass. Native results
không được suy ra từ các source checks này.

## Performance và boundaries còn lại

Một lazy coordinator/serial queue mỗi controller và tối đa một tracked request.
Short token lock chỉ compare/publish ownership, old token destruction ngoài lock.
Expected overhead thấp trên cold UI actions; không có latency/CPU benchmark.
Explicit cleanup giảm lifetime không cần thiết, không khẳng định server/socket
dừng ngay khi cancel. Không thêm polling, retry, global cache hoặc daemon work.

Per-owner ordering không bảo vệ controller/process khác, active source authority,
cfprefsd mirrors, equivalent-value ABA hoặc concurrent GPS/cache writers. Typed
numeric coordinates không đồng nghĩa đã validate geography bounds; H3R validation
policy không được thay rộng trong lifecycle patch. Remaining writer enrollment,
metadata/indicator/metrics, durability và rootful captured readers vẫn partial.
Manifest rollout: `4C.2H3V-partial`; Patch 4 chưa hoàn tất.
