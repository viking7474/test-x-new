# Patch 4A.2 — Captured runtime consumers (RootHide)

Ngày: 2026-10-24. Baseline: `6de5251`. Người dùng xác nhận build 4A.1 pass trước lượt này.
Trạng thái: source implemented, host regression checks PASS; native Foundation fixture mới, build Logos và device behavior chưa được xác minh tại host Windows. Chưa đóng toàn bộ Patch 4/transactional publication acceptance.

## Behavior và phạm vi

RootHide readers nay dùng captured view cho scope, identifier state và dữ liệu của một synchronous operation. Không đổi file format publisher schema 1, identity validation dependency gate hoặc chính sách manager-app live writer. Không thêm method hooks/swizzles; các hooks hiện có được thêm context ở entry point/helper và callback cần thiết.

Rootful giữ live-source/file readers và cache hiện hành, ngoại trừ các guard loại dữ liệu malformed không làm đổi input hợp lệ. Macro operation là no-op ở rootful. Rootful source capture, writer manifest/transactions, cùng các thiết lập chưa nằm trong runtime schema (ví dụ custom app-version overrides, location/domain rule stores) vẫn cần 4C/rollout tương ứng; không tuyên bố mọi file I/O trong repo đã chuyển khỏi hot path.

## Một view cho policy + data

`PXRuntimeReadScope` là frame trên stack với TLS parent và cleanup attribute. Root frame capture/retain một view; synchronous child dùng view của parent, kể cả khi view=nil vì publication đang pending. Child borrow lifetime đã được parent giữ, tránh retain/release lại cho từng helper hoặc từng node dictionary recursion. Frame không được đưa sang async callback.

`PXCaptureRuntimeSnapshot` trả view của operation nếu đang có scope, không tự lấy publication mới giữa chừng. Data loaders giữ view local khi đọc nhiều field và truyền view vào helper (ví dụ inferred identifier enablement). C coordinator entry points giữ cùng context qua các priority providers. Các asynchronous callbacks bắt đầu operation mới khi chạy; không capture pointer tới frame của caller.

Cleanup khôi phục TLS trước khi release view. Production app/tweak/CLI compile với `-fexceptions -fobjc-exceptions`. [Clang cleanup attribute](https://clang.llvm.org/docs/AttributeReference.html#cleanup) quy định cleanup khi biến hết lexical scope; native fixture dùng macro production để kiểm tra return, exception và lifetime, thay vì suy diễn từ regex. Kết quả native của implementation mới vẫn là gate bắt buộc, chưa có tại Windows.

Một operation đã capture A có thể hoàn thành bằng A khi B publish; operation tiếp theo phải thấy B hoặc pending/invalid, không ghép policy A với data B. Đây là read-side contract; không khẳng định A/B được publisher capture transactionally từ nhiều source files.

## Scope, bootstrap và identity

- Scope RootHide đọc security flags/scoped map từ cùng view và memoize immutable scope decision inputs trên chính view. Không reuse TTL snapshot của publication khác. Pending/invalid trả scope disabled, không fallback cfprefsd/rootfs. Numeric/string boolean conventions giữ nguyên; unsupported types fail closed.
- Process-role filtering chạy trước cold prime. Unscoped/denied constructors không đăng ký observers hoặc chuẩn bị identity. Cold classification có bounded wait; hot context chỉ capture. Constructor bị deny vẫn cần restart theo policy hiện hành.
- WebKit owner metadata trên RootHide chuyển sang reader serial queue với on-demand fallback một giây và cold bootstrap prime. Giữ container-path restriction và conflict=>nil; getter sau bootstrap không parse metadata file trên caller thread. Rootful resolver giữ path cũ.
- Identity validation/spec mapping/dependency diagnostics chạy trong preparation handler của runtime reader trước publication. Hook getter lấy immutable projection associated với đúng view, không lazy-build database/file state trên caller thread. Giữ `valid = profileID.length > 0 && validation.inputValid && deviceIDs.count > 0`; không biến dependency mismatch thành hard gate.
- Preparation handler và invalidation đổi dưới cùng lock/request generation. In-flight build dùng handler cũ không thể publish sau khi đổi handler. Old handler/view được giữ đến sau unlock để destruction không nằm dưới publication lock.
- Bootstrap chung chuẩn bị identity sau khi capability được cấp, kể cả WebKit helpers không chạy native-only ctors. Canonical notifications và slow fallback thuộc process reader. RootHide identity notification không còn inline rebuild; rootful/manager path vẫn có behavior cũ.

## Consumer manifest đã migrate

| Nhóm | Thay đổi RootHide |
| --- | --- |
| `PXScope.m` | Captured security/scope, view-bound decision cache; async WebKit metadata; shared bootstrap identity preparation |
| `PXIdentitySnapshot.m` | Pre-publication identity projection; hook read không disk/DB build; không fallback live files khi pending |
| `IdentifierManager.m` | Captured primary toggle + secondary/artifact inference; explicit false authoritative; active profile/current values từ cùng view; bỏ injected TTL scope-cache authority |
| `PXSecuritySettingsStore.m`, `Tweak.x` | Injected security reads từ view; manager app đọc live store; policy/data entries giữ operation scope |
| Battery + BootTime | Battery level/LPM và boot/uptime cùng view; bypass RootHide cache tuple của generation khác |
| Network/carrier | Security/pinned ISO, mode, carrier/network/IDs fallback cùng view; parsed results memoized trên view; network enabled gate không đọc shared boolean của thread/publication khác |
| Wi‑Fi | Artifact/IDs/legacy WiFi-string từ view; không gọi generator hoặc ghi file trong injected read; kết quả cache theo view |
| Storage | EnabledIdentifiers/secondary flag/storage artifact cùng view; giữ explicit-false và enabled-but-artifact-missing placeholder behavior; không reuse legacy TTL trên RootHide |
| Theme | IDs/artifact fallback cùng view, bỏ reuse theme TTL từ profile trước |
| UserDefaults/Pasteboard | UUID/artifact cùng view; không đọc/generate persistent fallback của source khác; missing UUID giữ original values/collection shape thay vì ghi nil/xóa key |
| SystemBootUUID/DyldCacheUUID | IDs/artifact của view, giữ format UUID 8-4-4-4-12 case-insensitive; không rootfs read hoặc update manager từ hook |
| DeviceModel, iOS version | Current identity projection; parsed iOS info memo theo view. RootHide `UIDevice.systemVersion` bỏ throttle-value cache cũ; rootful cache defect vẫn thuộc Patch 5 |
| DeviceSpec | Derived snapshot memo theo view, không last-good/counter cache của profile khác; script staging dùng local reader generation + effective values |
| Canvas/Missing/ManagedConfiguration/CoreTelephony/Lockdown/private wrappers | Policy + identity helpers và callbacks dùng read scope, Canvas settings từ captured security dictionary |
| Native coordinator | Một context cho toàn bộ C request/provider chain; signatures/priority/original forwarding giữ nguyên |

Manager app `com.hydra.tlinkios` vẫn dùng live active-profile/settings và writer paths. IdentifierManager chỉ bỏ mutable loaded settings/scoped containers khỏi authority trong injected path; case-insensitive app lookup và extension-pattern matching giữ semantics cho input hợp lệ. Không kết luận mọi CLI/legacy process đã được device-test.

## Cache và web edge cases

Publication identity mới có thể đổi khi DeviceIDs.GenerationCounter giữ nguyên hoặc reset. RootHide derived caches gắn với view object, không dùng counter đó để chọn data từ profile trước. Compatibility per-field getters còn tồn tại, nhưng RootHide dùng captured view; rootful giữ historical raw loader.

Web capability scripts cần thêm rule riêng: reader fallback tạo view mới dù CPU/memory không đổi, nên không dùng mỗi refresh làm lý do thêm script. Mỗi content controller kiểm tra newest owned script. Equal effective values không thêm script; incoming source generation cũ không được override script mới hơn trong controller đó. Một controller mới vẫn có thể hoàn thành staging bằng operation đã capture trước đó; không dùng global counter để làm mất script của controller khác. Rootful generation logic cũ giữ nguyên.

RootHide sparse/missing data không còn rơi xuống managers có thể read/generate/write profile files. Khi thiếu UUID/iOS tuple, giữ native result thay vì ghép dữ liệu từ source khác. RootHide missing-version log không chạy mỗi lần getter khi tuple chưa đủ. Không đổi behavior valid configured values.

## Performance, lifecycle và giới hạn

Hot operation thêm TLS frame, một capture/retain ở root và cleanup. Nested helpers không acquire publication mới hoặc thêm retains. Lookup/association có relative cost thấp; nhiều tiny hooks cần device profiling để biết tổng overhead. Không có con số benchmark CPU/latency được suy đoán.

Identity processing chuyển sang serial worker; deep freeze + validation mỗi refresh có cost moderate tùy payload. Parsed carrier/iOS/Wi-Fi/spec results theo view tránh rebuild trên mỗi query. Không thêm timer, busy polling hoặc per-call network. Web metadata refresh là on-demand; reader không wake khi idle.

View owns derived projections/fields, các projection không retain ngược view. Frame ownership chỉ trong synchronous lexical lifetime; async callbacks tạo frame mới. Không proxy/retain delegate, không dispatch UIKit work sang background. Validation modules đã kiểm tra không gọi UIKit/UIScreen/UIDevice/UIView; vẫn cần native stress/lifetime evidence thực tế.

Các giới hạn còn lại:

1. Source notification có thể đến trước daemon commit. Reader invalidates rồi chỉ đọc file committed đang có; khi publisher chưa commit mới, đó vẫn có thể là publication cũ. Không thể suy ra source intent/ack từ schema 1. Ordered publication/ack và notification-after-commit là việc bắt buộc của 4B; source transactions thuộc 4C. Không tuyên bố immediate global revocation/atomic distribution đã đạt.
2. Multi-file capture, multiple publisher processes, stale mirrors, mirror removal/container reset và epoch incarnation vẫn cần 4B/4C. Reader coherence không thay writer ownership.
3. Rootful live readers và settings ngoài runtime schema vẫn còn I/O/cache behavior cũ. Existing page/script teardown và mọi profile-dependent source không được coi đã sửa chỉ vì thêm context.
4. Cold bootstrap/metadata/preparation có deadline một giây; slow/unavailable source có thể deny constructor theo fail-closed policy. Cần device cold-launch/fault tests; chưa khẳng định mọi iOS/architecture/hook runtime pass.

## Verification

Host PASS: captured-reader/consumer source contracts; RootHide build contracts; bootstrap topology (27 ctors) và policy; P3 thread safety (80/80); Security UI/iOS12 contract; DeviceSpec P1.1 (81/81), P1.2 (79/79), hardware/WebGL P2 (70/70); native OS runtime safety; parity; Phase-10/Phase-B; missing-hook completion; WebKit zero-interference; canonical hardware; domain-task and location-delegate source gates. Các source-contract assertions gắn với old accessor được chuyển sang captured-view/absence contracts, không xóa coverage.

Node runtime/source tests PASS: canvas fingerprint protection, web spoof P1 và WebGL profile P2.

Backup/restore audit PASS 2548/2548; tăng 12 per-file guards do scope header/implementation/native fixture mới, không đổi semantic guards của audit. Diff whitespace PASS.

`PXRuntimeReadScopeTests.m` compile production reader + scope engine + macro RootHide. Fixture backend chỉ chọn test loader thay storage path; không tự viết lại TLS/cleanup logic. Cases: A->B giữa operation, nested view inheritance, pending nil không resurrect, return-value lifetime sau old-view release, ObjC exception cleanup, 128 thread scopes, concurrent profile/toggle updates, preparation-before-publication/handler replacement và controller web-staging decisions. Chạy ba process mới trong CI bằng `scripts/test_runtime_snapshot_consumers.py --native`.

Chưa tự chạy Foundation/Logos trên Windows, chưa install/terminate app/device, chưa commit/push. Gate kế tiếp: build/native fixture mới, cold launch + profile/toggle/container-reset tests trên scoped/unscoped app/extensions/WebKit cho RootHide và rootful parity. Sau đó tiếp tục 4B theo plan; chưa đánh dấu toàn bộ transactional publication model hoàn tất.
