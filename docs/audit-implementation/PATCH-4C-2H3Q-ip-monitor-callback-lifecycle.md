# Patch 4C.2H3Q — IP Monitor callback and session lifecycle

Người dùng xác nhận build H3P pass. H3Q tiếp tục lifecycle của IP Monitor, dùng chung source cho rootful/RootHide. Security/defaults authority và Patch 4 tổng thể vẫn partial; không đổi policy chọn IP để làm refactor.

## Vấn đề được xác định từ flow

Initial, adaptive và reachability/manual requests không có start-generation identity. Stop chỉ invalidate timer: request đang chạy vẫn hoàn tất; adaptive callback gọi startAdaptivePolling và có thể tạo lại timer, update cache/interval hoặc alert sau stop hay sau lần start kế tiếp. Queued alert presentation cũng thiếu check khi chạy trên main queue.

Mỗi fetch tạo NSURLSession riêng nhưng không finish/invalidate sau group completion. Không thể coi việc các tasks đã xong là session đã được invalidate. Timer dùng target=self tạo ownership service → timer → service; callbacks capture self qua batch có thể kéo dài lifetime. Reachability context là raw self không retained/weak-safe. Parser assume JSON dictionary và ip có selector length; body dạng array hoặc ip là NSNull/NSNumber có thể gửi selector không phù hợp. Data nil không có transport NSError cũng thiếu guard.

## Thay đổi

Mỗi actual start có một NSObject token riêng. Stop revoke token trước cancellation, lấy/cắt tập sessions đang chạy rồi invalidateAndCancel chúng. Terminal group work trên main remove/finishTasksAndInvalidate session nếu batch vẫn thuộc registry, rồi mới kiểm tra token và effective enabled state trước consensus/caller callbacks. Batch đã cancel không finish lần nữa. Callback cũ không đổi source, counters, interval, timer hoặc baseline của lần start sau. Adaptive callback recheck token sau cache save để synchronous re-entry không làm nó reschedule vào generation mới.

Polling entry kiểm tra effective state, token và đúng timer identity. Timer block giữ weak service; callback initial/adaptive/manual/group cũng dùng weak owner. Dealloc trực tiếp invalidate timer/cancel remaining sessions, không dispatch một method tới object đang dealloc. Reachability giữ một context object qua CFRetain/CFRelease, context chỉ weak-reference service; callback lấy strong local owner trong thời gian forward. Dealloc clear callback trước unschedule/release.

Control flow được giữ trên main thread: startup setup route main khi init từ background, void start/stop route async main, persisted BOOL setter reject off-main trước source write để không giả synchronous acknowledgement hoặc dùng dispatch_sync. Public state getter trả NO ngoài main, phù hợp contract main-thread read đã ghi ở header. Các UI callers hiện hành chạy main. Cache preparation/read APIs không được tuyên bố tự thread-safe chỉ vì control flow đã serialize.

lastCheckedIP chuyển từ function-static sang instance property để không chia baseline giữa nhiều service instances. Singleton vẫn giữ baseline qua stop/start như trước. Endpoints, ba requests mỗi batch, 8s/20s timeout, connection limit 3, 5s throttle, consensus >=2 và fallback, 30–300s adaptive policy không đổi. Start khi preference disabled và callback stale bị bỏ qua là corrective behavior. Queued alert kiểm tra token khi thực thi; alert đã hiển thị vẫn có các user actions cũ.

Parser chỉ nhận dictionary và ip là nonempty NSString cho JSON response; missing/invalid shape hoặc data nil trả error qua completion, không gửi unsafe selector. Plain-text nil data cũng fail như empty response. Không thêm HTTP-status hoặc IP-format policy mới; arbitrary nonempty string/fallback selection vẫn theo behavior hiện tại.

## Kiểm chứng và giới hạn

`test_ip_monitor_lifecycle.py --native` extract 10 production methods, weak context class và callback thành bốn fragments. Fixture dùng transport doubles tại NSURLSession/task boundary, actual parser/aggregation/GCD, actual NSTimer không đợi interval, CF main-run-loop pumping có deadline và weak context retain/release. Không gọi endpoints hoặc ghi preference domains thật. Group-notify wrapper chỉ ghi nhận completion của actual main-queue block. Store writer/service side effects và UIKit presentation được stub; source gate kiểm tra guard trước UIAlertController creation.

Cases: duplicate start, initial response sau stop, adaptive/manual response sau stop/start, stale timer, disabled controls không launch transport, normal consensus finish, disabled preference vẫn finish nhưng không publish, changed/unchanged interval policy, owner dealloc khi requests/timer còn pending, background void controls, off-main persisted setter, malformed JSON/missing data, all failures/single-result fallback, mỗi controlled session close đúng một lần, retained weak reachability proxy không giữ owner và forward sau owner dealloc an toàn, independent-instance baselines và cache callback re-entry stop/start không để old work đổi timer/baseline mới. Existing H3P transaction/UI fixture được cập nhật cho resource registry và vẫn chạy native runner riêng.

Windows chạy 63 release-inventory Python/Node suites và ba checks bổ sung RootHide/iOS DB/backup audit: 65/66 pass. Suite Keychain Bridge migration vẫn vướng Git Bash Permission denied tại `/c/Users/ADMIN`; không claim full release regression pass. Source/macro checks và exact extraction pass: lifecycle 4 fragments/10 methods, security 4, device-group 3, identifier 4, artifact-preparation 6, profile-creation 3. Diff check sạch.

CI đăng ký native lifecycle runner. Runner mới thử rootful và RootHide-defined lanes độc lập, in nhãn từng lane và tổng hợp failures sau khi thử cả hai; một lane lỗi không che compile/runtime kết quả lane còn lại của runner này. Mỗi lane chạy fixture ba lần. Không đổi thứ tự hoặc tuyên bố coverage tương đương của các legacy native runners khác.

Windows không có Foundation/xcrun/Theos. Native compile/runtime/package H3Q vẫn cần macOS CI. Controlled transport kiểm tra lời gọi cancel/finish và callback-after-cancel handling, không chứng minh thời điểm socket ngừng traffic hoặc NSURLSession OS scheduling thực tế. Reachability proxy forwarding/lifetime được fixture kiểm tra nhưng actual SystemConfiguration registration/delivery và UIKit alert presentation cần device matrix. RootHide-defined host lane không thay thế real SDK/jbroot/injected-process validation.

## Performance và phần còn lại

Token allocation một lần/start, session set insertion/removal mỗi batch và weak timer callback có expected low overhead. Stop không để callback cũ tạo thêm polling; invalidation đóng session lifecycle theo owner. Không đưa benchmark CPU/memory/latency chưa đo, không claim immediate memory/socket reclamation sau invalidateAndCancel: Foundation hoàn tất cancellation asynchronously. Vẫn tạo một session và aggregation queue mỗi batch; chưa coalesce active-generation requests hoặc đổi tie/fallback/order policy.

Các batch cùng generation vẫn có thể hoàn tất khác thứ tự và overwrite newer observation theo behavior cũ; source transaction chỉ bảo vệ commit, không xếp thứ tự observations. External preference rewrites không join token lifecycle, defaults/cfprefsd authority và compatibility mirror ordering vẫn partial. Startup cache type/age validation, logging I/O và true network/device integration là các phần audit còn lại. Remaining security/timezone/indicator/metadata writers, rootful captured readers, whole Reset Data atomicity và directory durability tiếp tục theo plan.
