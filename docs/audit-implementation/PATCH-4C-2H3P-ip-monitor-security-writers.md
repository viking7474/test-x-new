# Patch 4C.2H3P — IP Monitor security writes and disable cleanup

Người dùng xác nhận build H3O cùng các CI gate fixes pass. H3P tiếp tục enroll writer; Patch 4 và security/defaults authority vẫn partial. Code production dùng chung rootful/RootHide, không thêm conditional bypass cho một scheme.

## Vấn đề và flow

`IPMonitorService.saveLastKnownIP:` ghi lastKnownIP rồi gọi saveIPToCache ghi CachedIP/IPCacheTime qua hai defaults synchronization phases. Các key chia sẻ security preference domain với runtime capture nhưng không tham gia source token/journal. Cache IP và timestamp không được stage thành một source packet. UI toggle và nút tắt trong IP-change alert ghi defaults trực tiếp, không kiểm tra kết quả trước service changes/success feedback.

Ngoài writer coverage, stop có lỗi logic cụ thể: getter `isMonitoring` trả `_isMonitoring && storedEnabled`. Hai caller tắt preference trước rồi gọi stop; guard `if (!self.isMonitoring)` vì vậy return khi timer còn valid và raw running flag còn YES. Timer tiếp tục nằm trong run loop. Không cần giả định timing/race để đi vào nhánh này.

## Thay đổi

Observed IP, CachedIP và IPCacheTime nay cùng một detached packet qua `PXWriteSecuritySettings`. Private cache-only adapter giữ selector, chỉ ghi hai cache fields và không sửa lastKnownIP. Nil candidate là no-op. Void APIs giữ semantics cũ: caller đã cập nhật candidate trong memory vẫn có thể giữ candidate nếu source write fail; lỗi được log, không báo persistence thành công hay thêm IPC.

`setMonitoringEnabledAndPersist:error:` được export và ghi enabled flag qua shared verified store trước start/stop. Đây là main-thread service API như các UI callers hiện tại; không thêm queue hop hoặc giả thread safety cho mutable service state. Security tab lấy previous effective setting trước call, restore switch và báo failure khi commit fail; success toast/count chỉ sau YES. Nút tắt từ alert dùng cùng API và không tạo confirmation nếu source write fail.

`stopMonitoring` dựa vào raw running flag và timer resource. Chỉ return nếu cả flag đã off và timer không còn. Preference đã off vẫn cleanup flag/timer; leftover timer được invalidate dù raw flag đã off; repeated stop không có resource effects. Không đổi interval, throttling, consensus policy hoặc notification topics.

## Authority, lifecycle và performance còn giới hạn

Enrolled entry `ip-monitor` chỉ bảo đảm các writes kể trên qua source transaction. Generic store vẫn mirror ba legacy suites sau unlock; physical preference domain/cfprefsd/direct writers và mirror total ordering còn partial. Các read adapters trong service vẫn dùng defaults suite hiện hành; fixture không chứng minh cfprefsd convergence hoặc stale-cache behavior trên RootHide.

Singleton initialization có thể restore monitoring trước khi UI thực hiện một toggle; writer không bao initialization này trong source transaction. BOOL success xác nhận commit trước service action; không phải atomic filesystem/network operation. Provider/start exceptions sau commit không có rollback. In-flight network callbacks sau stop còn có thể cập nhật cache hoặc restart polling qua existing callback flow; cancellation/generation guard, NSURLSession lifetime, service main-thread enforcement và full timer/network lifecycle là boundary riêng chưa sửa ở H3P. Không coi đây là hoàn tất toàn bộ IP Monitor audit.

Một observed-IP update chỉ có một source commit; legacy policy có hai defaults synchronize phases, không tương đương hai journaled source transactions. Source packet thêm serialization/journal/lock I/O, generic store vẫn mirror ba suites. Expected low–moderate cost trên callback ghi settings, chưa benchmark latency/CPU; không claim net I/O giảm hoặc main-thread latency đã cải thiện. Timer cleanup loại resource còn sống sau disable trong flow đã xác định.

## Kiểm chứng

Existing security runner extract exact production cache/toggle/stop/effective-getter và UI handler thành hai fragments mới, bên cạnh Canvas fragments. Link actual shared source engine/store; defaults backend nằm trong memory, notification intercept giữ nguyên. Fixture start là stub, timer là Foundation NSTimer không schedule, UI là Foundation-only doubles; không phát network/IPC hoặc chạm preference domains thật. Manager-role bool read adapter được mô phỏng từ fixture disk ở cả host lanes vì bundle identity của macOS command-line không phải RootHide manager app. Không coi fixture là injected reader/device proof.

Cases: một commit cho observed/cache/timestamp, preserve unrelated keys và cache-only lastKnownIP policy, nil no-op, source-written fault giữ bytes/token/mirrors/notifications, start quan sát committed source ngoài gate, persisted disable invalidate timer dù effective getter false, leftover timer và repeated stop, failure giữ active timer, UI failed enable/disable restore previous state và không service success, UI successful enable/disable feedback sau commit. Existing Canvas/security fault, nonce concurrency và macro arity checks vẫn giữ.

Windows chạy toàn bộ 62 release-inventory Python/Node suites và ba checks bổ sung RootHide/iOS DB/backup audit: 64/65 pass. Suite Keychain Bridge retirement migration vẫn fail do Git Bash không thể tạo/access `/c/Users/ADMIN` trong môi trường local (Permission denied); không claim full release pass. Macro arity trong profile-creation gate pass. Exact native extraction pass cho security 4 fragments, device-group 3, identifier 4, artifact-preparation 6 và profile-creation 3. Git diff check sạch.

Native runner hiện có đăng ký CI `test_runtime_security_writers.py --native` cho rootful và RootHide-defined host fixtures. Native compile/runtime/package H3P cần macOS CI; Windows chỉ kiểm tra source contracts và exact extraction, không dùng build H3O pass làm bằng chứng H3P đã pass.

## Tiếp theo

Remaining direct timezone/region/indicator/metrics writers, preferences authority/mirrors, profile metadata/defaults, whole Reset Data atomicity, cache publication ordering, rootful captured readers và directory durability vẫn pending/partial. IP polling/session/callback lifecycle cần riêng một bước có runtime fixtures trước khi thay cancellation hoặc timer scheduling policy.
