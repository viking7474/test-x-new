# Patch 4C.2H3U — IP display primary/fallback lifecycle

Người dùng xác nhận build H3T pass sau sửa fixture `Point` collision. H3U tiếp tục
Patch 4, dùng chung source cho rootful/RootHide. Bootstrap RootHide đã xác nhận ổn
không thay đổi trong patch này.

## Lỗi và phạm vi

`fetchCurrentIP` và `fetchSimpleIP` tạo session nhưng không finish/invalidate rõ
ràng, completion giữ Security controller mạnh và không có generation guard.
Primary cũ lỗi có thể khởi động fallback sau một refresh mới; kết quả cũ có thể
ghi timezone/cập nhật UI/cache sau kết quả mới. Root JSON/IP/country/GMT thiếu type
checks khiến payload sai kiểu nhận selector không hỗ trợ. Đây là lifetime/order/
parser defects; không khẳng định mọi session cũ là permanent memory leak khi chưa
có runtime allocation trace.

## Thay đổi

`PXIPDisplayLookup` owns một primary/fallback chain mới nhất. Resolve/cancel chạy
trên main (background entry async handoff bằng weak owner). Mỗi chain có token;
mỗi attempt có token riêng để duplicate primary không tạo nhiều fallback và late
attempt không finish nhầm session mới. Supersession/dealloc cancel session; normal
attempt finish/invalidate trước fallback hoặc final handoff. Backend không giữ
lookup/controller mạnh trong suốt request.

Parser chạy trên transport callback, kiểm tra dictionary root, nonempty string IP
và optional country/timezone/GMT fields trước khi tạo detached display payload.
Primary thiếu IP hợp lệ gọi fallback, không persist timezone từ một response IP
không hợp lệ. Empty/malformed fallback không cập nhật UI như trước. Giữ endpoint,
User-Agent primary, request timeout 8s/resource 15s; fallback request 5s và default
resource timeout; fallback trim whitespace/newlines. Không thêm IP syntax policy,
endpoint/retry/polling/cache/HTTP status policy.

Security giữ hai selectors cũ qua adapter chung. Timezone validation, comparison
với stored value, verified persistence và formatter `h:mm a` chạy trên serial
preparation queue của lookup, không chuyển source I/O lên main. Main completion
mới gọi `updateIPLabelWithIP`, giữ existing cache/display behavior. Consumer capture
controller yếu; chỉ giữ owner tạm thời khi thực sự xử lý callback.

### Admission và giới hạn cancellation

Một short `os_unfair_lock` chỉ bảo vệ worker token giữa main và worker. Generation
được kiểm tra ngay trước preparation; queued obsolete work bị loại trước source
effects. Lock được nhả trước persistence/formatter và old token destruction ngoài
lock; main không chờ serial worker.

Cancellation không rollback preparation đã qua admission check: write đó có thể
hoàn tất sau refresh/cancel. Một serial queue bảo đảm nó không vượt qua preparation
mới hơn của cùng lookup, và main token check loại UI result của nó. Đây không phải
atomic CAS giữa UI intent và security commit hoặc ordering giữa controllers/processes.
Invariant này ghi trong source/header và có fixture cho cả queued và in-flight
work. Không giữ lock qua source I/O chỉ để tuyên bố strict cancellation.

## Kiểm chứng

CI chạy `scripts/test_ip_display_lifecycle.py --native`: thử rootful và
RootHide-defined lanes độc lập, ba lần/binary. Fixture include nguyên production
lookup sau platform headers; alias chỉ NSURLSession transport. Foundation parsing,
requests/config, timezone formatting, GCD/main loop, lock, queue và ARC là thật.
Ba controller methods extract nguyên source; preferences/persistence/UI consumers
là stubs. H3R native fixture tiếp tục kiểm tra actual verified persistence riêng.

Cases: latest generation, stale primary không fallback, fallback một lần, duplicate
primary/fallback, late old fallback, request/timeout/header policy, typed/malformed
JSON, empty fallback, queued preparation bị cancel trước effects, admitted old
preparation trước new effects nhưng không cập nhật UI cũ, worker timezone writes,
unchanged timezone không ghi lại, direct fallback, weak owner/dealloc/session
cancellation, consumer re-entry và background controls. Macro validator bao gồm
fixture mới; helpers dùng PXD prefix tránh SDK symbol collision.

Windows chạy source checks, exact adapter extraction và macro/diff checks. Native
Foundation/Theos/package/device H3U cần macOS CI; controlled transport không xác nhận
network service, UIKit, root namespace hoặc real injected-process behavior.

Kết quả local: 61/62 Python regression suites và 4/4 Node suites pass. Suite bridge
migration shell còn Permission denied tại `/c/Users/ADMIN`, không phải native build
đã kiểm chứng. Source hardening, RootHide build contracts và package metadata checks
pass; exact ba production adapters và macro arity được kiểm tra. Không ghi nhận
full release gate hoặc native runtime pass tại Windows.

## Performance và phần còn lại

Một lazy lookup/serial queue theo controller, tối đa một tracked session, token
theo chain/attempt. Primary/fallback session allocation giữ policy cũ nhưng thêm
explicit cleanup. Short token check expected low overhead so với network/source
I/O; chưa có latency/CPU benchmark. Bỏ full-response debug formatting ở flow cũ;
không tuyên bố tối ưu logging toàn subsystem.

Preparation queue không giải quyết source contention/deadline, cfprefsd authority,
timezone mode/global intent ABA, concurrent controllers, hoặc multi-writer IP cache
durability. In-flight source work có thể giữ owner tới khi callback xử lý xong;
không giữ owner trong thời gian chờ network. Caller tùy ý vẫn có thể tạo cycle bằng
strong capture nên header yêu cầu weak consumer. HTTP response size/status policy,
region-sync HTTP/GPS/security/cache workflow và remaining writers vẫn pending.
Manifest: `4C.2H3U-partial`; không đánh dấu Patch 4 hoàn tất.
