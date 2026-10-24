# Patch 2 — NSURLSession domain blocking lifecycle

Ngày: 2026-10-24. Baseline: `6ba80d7` (Patch 1 đã được commit và người dùng xác nhận build pass).
Trạng thái: source implemented; host source/regression gates pass. Đã sửa lỗi compile ARC ở switch, cancelled-state assertion và nested `%orig` trong Logos; người dùng xác nhận build pass sau các sửa đó, trước khi triển khai Patch 3. Chưa có log riêng để kết luận đầy đủ từng fixture/lane hoặc iOS device/runtime matrix.

## Vấn đề đã sửa

Các NSURLSession factory cũ tự dispatch completion và trả task đã cancel. Callback đó không thuộc lifecycle của task, có thể chạy trước khi caller resume, chạy trên global queue và không khớp error/state do Foundation quản lý. Hook NSURLRequest/NSMutableURLRequest còn đổi URL ngay khi tạo request, khiến task mất hostname/metadata ban đầu.

Patch bỏ các đường đó. Không tự gọi completion, không giả lỗi bằng delay hoặc localhost trong adapter NSURLSession.

## Thiết kế và thay đổi behavior có chủ đích

- Giữ kết quả gốc của ba class methods tạo/lấy session: shared, configuration và configuration/delegate/queue. Không tạo lại shared singleton hoặc sửa configuration.
- `PXDomainObserveURLSession` cài wrappers trên concrete session class. Chỉ cài selector tồn tại và có full argument/return ABI phù hợp. Registry class + selector có lock và installation idempotent; inherited implementation được cài class-local.
- Factory trả đúng task gốc với đúng request và completion gốc. Policy được gắn với task trước khi factory trả về; chưa cancel hoặc resume tại factory.
- Concrete task `resume` kiểm tra policy hiện hành, lấy host từ currentRequest/originalRequest hoặc hostname hint cho stream. Khi bị chặn, gọi native `cancel`, rồi gọi original resume đúng một lần. Foundation quản lý state/KVO, task.error và callbacks. Không tự phát KVO hoặc delegate events.
- Error của request bị chặn chuyển thành **NSURLErrorCancelled**, thay cho lỗi DNS/timeout giả trước đây. Task đã cancel hoặc completed không bị cancel thêm bởi adapter. Cancel trước resume do caller vẫn theo Foundation.
- Guard theo thread/task identity ngăn việc override gọi super làm policy/cancel chạy lại trên cùng stack. Guard được khôi phục bằng `@finally`.
- Original IMP được seed trước khi publish replacement và cập nhật atomic. Registry chỉ giữ class/hook records; không giữ session/task instances. Policy object đã publish không bị mutate; atomic associated-object ownership bảo vệ reader khi thay policy để bổ sung stream hostname. Observe kiểm tra lại session dưới lock để concurrent initialization không overwrite predicate đã cài.
- Giữ scope/bootstrap gates, settings observer và live policy cũ, kể cả hot enable/disable. Chưa thay domain matcher, cache hoặc source snapshot trong patch này.

Hướng NSURLProtocol trong plan được thay đổi vì Apple ghi rõ custom protocols không hỗ trợ background sessions. Cancellation là API task công khai và không cần thay transport hoặc completion queue. Đây là lý do chọn cơ chế này, chưa phải bằng chứng mọi background task trên iOS đã được kiểm chứng.

Nguồn: [Apple protocolClasses](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/protocolclasses), [Apple URLSessionTask.cancel](https://developer.apple.com/documentation/foundation/urlsessiontask/cancel()), [Apple URLSession](https://developer.apple.com/documentation/foundation/urlsession).

## Surface và giới hạn coverage

Adapter có bảng 19 factory selectors: data request/URL; upload data/file/streamed request; download request/URL/resume data; WebSocket request/URL/protocols; stream hostname/port; các completion variants tương ứng. Selector không tồn tại hoặc ABI không khớp được bỏ qua. Hàm observe trả success khi cài được ít nhất một factory; không có nghĩa toàn bộ bảng được hỗ trợ trên OS đó.

Không phụ thuộc tên private class cụ thể. Tuy nhiên, runtime interception vẫn cần kiểm tra trên hook runtime/iOS thật, đặc biệt khi nhiều tweak cùng swizzle. Không thể đảm bảo phối hợp với một third-party swizzle không giữ original chain hoặc sửa method đồng thời.

Các trường hợp chưa được chứng minh:

- Session tạo trước khi hooks được cài hoặc không qua các constructor công khai có thể chưa được observe. Task đã chạy, background transfer được daemon tiếp tục hoặc task được khôi phục từ lần chạy cũ không được retroactively chặn bằng adapter này.
- Task resume-data cần Foundation khôi phục host qua request accessor trước resume; patch không parse private resume-data format. Cần valid resume-data fixture trên iOS.
- Background, WebSocket, stream và upload streamed cần integration evidence riêng. Có selector wrapper không thay thế test vận chuyển thực tế.
- Redirect sang host khác sau resume cần đối chiếu các adapter mạng hiện có; patch này chỉ đánh giá task host tại resume, không thêm redirect delegate proxy.

DNS/CFHost/NWEndpoint, NSURLConnection, CFNetwork và WebKit adapters cũ vẫn còn. Một số vẫn có rewrite/error behavior riêng; không tuyên bố patch này đã sửa toàn bộ networking stack. Passive NSURLRequest construction nay giữ URL gốc cho mọi caller; legacy adapters giữ quyết định chặn ở entry points riêng của chúng và cần smoke test sau thay đổi này.

## Performance và lifecycle

Không thêm polling, timer, network request, file I/O hoặc logging. Cài method một lần cho mỗi concrete class/selector; session mới vẫn cần duyệt bảng selector dưới installation lock. Task factory thêm associated state và lock ngắn; mỗi observed task giữ một policy object đến khi task dealloc. Đây là overhead mới cần đo khi tạo request burst, kể cả feature đang tắt để hỗ trợ bật nóng.

Resume path lấy associated policy, đọc state/host và gọi policy cũ; không lấy installation lock. Predicate vẫn có chi phí settings/scope lookup hiện có, chưa có số profiling để gọi đây là optimization. Relative cost dự kiến thấp cho association/state và có thể moderate cho policy/settings lookup trong workload burst; chưa có benchmark.

Các class-local hook blocks/records tồn tại suốt process theo thiết kế runtime, số lượng bị giới hạn bởi class/selector gặp thực tế. Không có per-task completion wrapper hoặc capture task/session trong production predicate. Native fixture có weak-reference check cho registry và doubles, chưa thay thế Instruments leak test của Foundation trên thiết bị.

## Verification

Host gates đã chạy:

- `scripts/test_domain_task_lifecycle.py`: source wiring/ABI/reentrancy contracts PASS; thông báo rõ không chứng minh native runtime.
- `test_security_ui_logic_static.py`, `test_thread_safety_cleanup_p3.py` (80/80), `test_missing_hook_completion_static.py`, `test_phase_b_regression_static.py`, `test_roothide_build_static.py`, `test_webkit_unscoped_zero_interference.py`, `test_bootstrap_topology.py` (27 constructors): PASS.
- `test_phase10_release_hardening_static.py`: PASS sau khi thêm gate vào release runner.
- `audit_backup_restore_hardening.py`: PASS 2512/2512. Tăng 12 checks so với Patch 1 do ba source/header fixture mới, không thay semantic guards của audit.
- `git diff --check`: PASS.

`tests/PXDomainTaskLifecycleTests.m` dùng production helper trực tiếp. Native test config dùng test-only NSURLProtocol để đo transport-start, không đưa protocol đó vào production. Test gồm:

- Sáu completion factories data/upload/download; default/ephemeral, shared, delegate-only và custom serial queue.
- Mỗi completion factory có đối chứng unobserved session với native `cancel` rồi `resume`, bên cạnh domain-blocker case; cả hai phải giữ URL/queue/error, completion đúng một lần và transport-start=0.
- Create/no resume, cancel trước resume, repeated resume/cancel, invalidateAndCancel, suspended delegate queue, unblocked suspend/resume và live policy change.
- Callback count/queue/error, task state/error/URL, blocked transport-start=0, unobserved session pass-through và 24 concurrent task creations.
- Runtime doubles kiểm tra identity, stream host hint, inherited class isolation, override/super, invalid return/argument ABI và registry không retain instances.

CI macOS chạy `python3 scripts/test_domain_task_lifecycle.py --native`, compile production helper + fixture bằng xcrun/ARC/Foundation rồi chạy binary. `--native` báo lỗi rõ khi thiếu môi trường, không silently skip. Release regression runner chạy source gate; build Theos lấy helper mới qua wildcard `.m` hiện có.

### Sửa lỗi compile từ CI

Clang/ARC báo `cannot jump from switch statement to this case label` trong `PXDomainInstallFactory`: block temporaries capture strong `hook` có lifetime trong scope chung của switch. Thêm `{ ... }` cho từng nhóm case để lifetime kết thúc trước case tiếp theo; giữ nguyên factory signatures, IMP forwarding và policy. Đây là sửa compile, không thay lifecycle behavior. Source gate không thể phát hiện thay compiler lỗi này; native CI hiện có vẫn là gate bắt buộc và cần chạy lại.

### Sửa Logos và cancelled-state assertion từ CI tiếp theo

- RootHide: `PXDomainObservedSession(%orig)` được Logos preprocess thành lời gọi thiếu dấu đóng ngoặc. Cả ba constructor nay dùng `NSURLSession *session = %orig;` rồi mới gọi adapter. Original vẫn gọi đúng một lần với arguments cũ. Source gate được đổi để giữ contract này.
- Foundation fixture: CI báo 168/169 checks pass, fail ở `task.state == Completed` sau download completion. Assertion này giả định ordering/state quá chặt: [Apple về canceling](https://developer.apple.com/documentation/foundation/urlsessiontask/state-swift.enum/canceling) cho phép completion delegate message đã được gửi khi state vẫn là Canceling. Fixture nay chấp nhận Canceling hoặc Completed sau native cancellation, fail nếu Running/Suspended và in class/state/error/URL khi sai. Không thêm delay, polling hoặc ép state production để làm test pass.
- Thêm sáu native-cancel baselines để đối chiếu các factory. Giữ toàn bộ checks callback count, queue, error/task.error, metadata và zero transport. Những kiểm tra host được chạy lại: domain lifecycle source contracts, Phase-10 release hardening static, missing-hook completion static và diff whitespace đều PASS. Chưa chạy native fixture hoặc Logos compiler sau sửa trên Windows; không dùng kết quả 168/169 để coi native gate đã pass.

## Gate còn lại

1. Chạy native Foundation fixture trong CI và build Logos/Objective-C/package Patch 2. Native macOS pass vẫn chưa chứng minh iOS class cluster hoặc Logos wiring.
2. Device test scoped/unscoped và hot toggle; xác minh shared/default/ephemeral, background file upload/download, delegate nil/custom queue, stream/WebSocket khi OS có API, valid download resume-data.
3. Đo callback/KVO/task metadata, cancel khi transport đã chạy, redirect và network capture; đối chiếu unblocked parity cùng các adapter cũ.
4. Kiểm tra rootful/RootHide, arm64/arm64e và cùng các tweak khác; ghi chính xác OS/hook runtime có bằng chứng. Chưa tuyên bố iOS 12+ matrix pass.

Không commit/push, install package hoặc terminate app trong lượt triển khai này. Patch tiếp theo: P0-C — bỏ location delegate interception trên NSObject, sau gate build/runtime tương ứng.
