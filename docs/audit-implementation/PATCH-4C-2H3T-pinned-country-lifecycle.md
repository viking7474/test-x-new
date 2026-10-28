# Patch 4C.2H3T — pinned country callback lifecycle

Tiếp tục Patch 4 sau khi người dùng xác nhận RootHide/AIDA64 đã ổn. Giữ nguyên
logic bootstrap đã sửa và các chú thích regression; H3T chỉ xử lý lookup quốc gia
cho tọa độ ghim trong Security. Source dùng chung rootful/RootHide.

## Lỗi và thay đổi

Request Nominatim cũ không có owner theo dõi/hủy task. Completion giữ controller
mạnh, còn consumer có thể cập nhật nhãn cũ và ghi pinned-location cache sau khi
pin/refresh đã đổi. Không khẳng định đây là permanent leak: network completion
có thể nhả reference khi kết thúc, nhưng controller lifetime bị kéo dài không cần
thiết. Parser chỉ kiểm tra JSON root, chưa kiểm tra dictionary `address` hay string
`country_code`, nên payload sai kiểu có thể nhận selector không hỗ trợ.

`PXPinnedCountryLookup` giữ một task và một token mới nhất theo owner. Main-thread
resolve/cancel revoke token trước cancellation; background entry handoff main bằng
weak owner, không dispatch sync. Backend callback weak-capture lookup, parse/type
check trên transport callback, rồi main delivery kiểm tra token, clear task/token
trước consumer để hỗ trợ re-entry. Duplicate/stale/cancelled callbacks không gọi
consumer. Dealloc cancel task còn pending. Dùng shared NSURLSession như cũ, không
invalidate shared session hoặc tạo session mới cho từng request.

Security adapter weak-capture controller, tiếp tục cache theo bốn chữ số thập phân
và countLimit 50. Cache-hit path hủy lookup trước và trả trên main; nil completion
không launch task. Mỗi refresh hủy country lookup cũ kể cả khi pin mới không tồn
tại. Consumer recheck typed current pin bằng helper của H3S trước cập nhật nhãn
hoặc `savePinnedLocation`. Cancel/token bảo vệ refresh generations trong controller;
pin comparison bổ sung bảo vệ khi pin đổi bên ngoài mà controller chưa refresh.

Giữ endpoint Nominatim, sáu chữ số tọa độ trong request, zoom/addressdetails,
User-Agent, timeout 10 giây, chính sách cache và dữ liệu successful lookup. Missing,
malformed hoặc nonalphabetic country code trả nil; invalid/nonfinite coordinate
không gửi request. Đây là defensive correction cho dữ liệu không hợp lệ. Không
thêm provider, polling, retry hoặc thay đổi scope/hook.

## Kiểm chứng

`test_pinned_country_lifecycle.py --native` đăng ký vào CI hiện hành, thử hai lanes
rootful/RootHide-defined độc lập và chạy mỗi binary ba lần. Fixture include nguyên
utility production sau SDK imports; chỉ alias NSURLSession/task sang controlled
transport. Foundation parsing/requests, CoreLocation coordinate validation, GCD,
main run-loop và ARC/weak ownership là thật. UI adapter được extract nguyên method;
flag rendering dùng stub, không mô phỏng UIKit hay dịch vụ geocoding thật.

Cases: supersession/task cancellation, late success/error, duplicate callback,
main completion, consumer re-entry, request policy, wrong JSON root/address/field
types, malformed/missing data, invalid coordinate/nil completion, lookup/controller
dealloc, background resolve/cancel, cache hit/same rounded key, stale result không
ghi owner cache. Source gate kiểm tra refresh cancellation và pin guard đứng trước
UI/pinned-cache effects; toàn bộ refresh/UILabel/cache file chưa chạy trong fixture.
Macro-arity validator bao gồm fixture mới.

Windows: 60/61 Python suites và 4/4 Node suites trong release inventory pass;
source hardening, RootHide build contracts và package metadata checks pass.
Exact production adapter extraction, macro arity và diff check pass. Không có
Foundation/xcrun/Theos nên không báo native compile/package/device pass. Suite
bridge migration shell còn lỗi Permission denied `/c/Users/ADMIN` của môi trường
này; không ghi nhận full release gate pass.

## Performance và phần còn lại

Tối đa một task tracked cho mỗi lookup owner, một token cho mỗi cache miss. Cancel
là yêu cầu tới transport; không chứng minh server hay socket dừng ngay. Expected
cost thấp trên UI action; không có số benchmark CPU/latency. Cache hit không tạo
task, shared session giữ connection reuse, JSON parsing không chuyển lên main.

Lookup không tự giữ owning controller; các nhánh IP/time/region khác vẫn có thể giữ
controller riêng. Consumer completion tùy ý vẫn có thể tự tạo strong owner cycle,
nên header yêu cầu weak capture. Background controls chỉ có hiệu lực khi block
được xử lý trên main, không phải synchronous cancellation.

Rounded-coordinate cache policy cũ và value-based pin ABA vẫn tồn tại; không thêm
global intent revision, cross-controller cancellation, HTTP status/body-size policy
hoặc cache expiry. Pin check không atomic với GPS/cache writers khác. Existing
pinned cache I/O vẫn ở main consumer như trước; chưa giải quyết multi-writer lost
update hay file durability của IPStatusCacheManager.

IP display primary/fallback callback lifecycle, sync-region HTTP worker ordering,
GPS/security/cache consistency, cfprefsd/defaults authority, remaining metadata/
indicator/metrics writers và rootful reader rollout còn pending/partial. Không
đánh dấu toàn bộ security source contract hoặc Patch 4 hoàn tất. Manifest rollout:
`4C.2H3T-partial`.
