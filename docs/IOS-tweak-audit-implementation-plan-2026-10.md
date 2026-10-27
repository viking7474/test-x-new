# Kế hoạch triển khai sau audit iOS tweak

Ngày chốt: 2026-10-24. Baseline source: `b0d35c6`.
Trạng thái cập nhật 2026-10-27: Patch 1–3, 4A.1, 4A.2, 4B, 4C.1 và 4C.2A–H3E đã được người dùng xác nhận build pass, gồm các sửa fixture legacy timestamps, notification memory oracle và native RootHide header support. 4C.2H3F đưa standalone Uptime/Storage persistence vào lifecycle ownership; profile-root scope giữ compatibility với storage-only legacy profiles. Build/native H3F chờ macOS CI. Recovery không retry directory cleanup. Directory ownership/cleanup, remaining artifact producers, metadata/defaults/security authority, cache ordering, rootful reader rollout và device/runtime matrix vẫn pending/partial. Patch 5–8 chưa triển khai.
Tài liệu này thay thế các khuyến nghị tương ứng trong trao đổi audit, không thay thế roadmap backup/restore khác trong repo.

## 1. Kết luận và quy tắc triển khai

- Ưu tiên correctness, stability và loại bỏ surface không còn nhiệm vụ trước optimization.
- Mỗi finding ghi riêng: lỗi đã chứng minh, đường chạy production đã chứng minh, hoặc rủi ro cần runtime evidence. Priority là thứ tự xử lý, không đồng nghĩa đã có exploit/reproducer trên thiết bị.
- Retire WeaponXKeychainBridge; giữ resigned helper và compatibility với archive cũ `method=in_app`. Không xây IPC keychain mới khi chưa có workflow cần nó.
- Movement simulator có bug implementation nhưng chưa tìm thấy caller production. LocationSpoofing group và delegate hooks là surface riêng, thực sự được khởi tạo sau ctor gates.
- Không thay chính sách scope, giá trị profile, tiêu chí identity validation hoặc behavior app không được scope chỉ để refactor.
- Mỗi patch đi cùng regression tests và cập nhật contract test cũ nếu contract đó đang bảo vệ behavior cần retire/sửa. Không chỉ xóa assertion để làm gate xanh.
- Không tự terminate app trên thiết bị trong giai đoạn sửa code. Việc restart target apps là một bước migration/release được kiểm soát; không dùng killall diện rộng.

## 2. Các bổ sung được chấp nhận

### Publication phải có serialization và ownership

`WeaponXDaemon.m` gọi publish từ start, Darwin callbacks, fingerprint fallback và self-test. Chưa có serialization rõ ràng bao quanh toàn pipeline. Ngoài ra `--sync-once` chạy trong process khác; `DEBIAN/postinst:156` gọi nó trước khi bootout daemon cũ ở dòng 173.

Do đó cần bảo vệ cả intra-process lẫn inter-process publication. Chưa khẳng định các Darwin callbacks hiện đã race trên thiết bị; nhiều entry points và process thứ hai đủ để yêu cầu ownership rõ ràng.

Pipeline cần serialize:

`capture nguồn nhất quán -> tạo immutable candidate + publication identity -> atomic global write -> mirror -> kết quả distribution -> notify`.

### Hai lớp consistency khác nhau

- Reader-side: một logical operation phải giữ một snapshot duy nhất. BootTime đọc boot/uptime/profileID độc lập là ví dụ cụ thể.
- Publisher-side: nhiều file nguồn được đọc nối tiếp; atomic rename đầu ra không làm các file nguồn thành transaction. Đây là cửa sổ inconsistency từ source, chưa có runtime reproducer.
- Serialization publisher không tự serialize app/helper đang ghi các file nguồn. Cần một source-transaction contract riêng với các writer liên quan.
- Publication revision độc lập với `device_ids.plist/GenerationCounter`, schemaVersion và wall-clock timestamp.
- Global file và nhiều container mirrors không thể được xem là một atomic filesystem transaction. Phải phân biệt ordered publication với partial distribution/convergence.

### Provider registry

Ưu tiên copy-on-write immutable lists lúc registration, reader giữ strong reference dưới short lock rồi iterate ngoài lock. Không freeze trước install: BootTime và các ctor khác có thể install coordinator trước register provider. Không triển khai lock-free ObjC lifetime nếu chưa có profiling cần thiết.

## 3. Thứ tự patch và tiêu chí hoàn tất

### Patch 1 — P0-A: retire Keychain Bridge toàn diện

Tiến độ và bằng chứng: [báo cáo Patch 1](audit-implementation/PATCH-1-keychain-bridge-retirement.md).

Phạm vi: Makefile; `WeaponXKeychainBridge/` và plist; `common/PXInjectionFilter.*`; UI filter writer/verification/debug; daemon fingerprint/sanitize/install; `DEBIAN/` upgrade scripts; tests và CI.

1. Bỏ bridge khỏi build, relocation, staging và production artifact. Loại bỏ production consumer/helper chỉ phục vụ bridge.
2. Bỏ bridgeBundles, bridge filter writes, verification polling và dependency/debug status tương ứng trong UI/daemon.
3. Giữ legacy archive parser và migration `in_app -> resigned_helper`; không xóa backup hoặc keychain dữ liệu người dùng.
4. Upgrade cleanup idempotent trên danh sách tên/path artifact bridge chính xác, với rootful/rootless/RootHide resolution đã kiểm tra. Dọn cả staged filter và injector plist/dylib cũ; ngăn UI/daemon cũ tái tạo trong migration.
5. Ghi rõ restart target apps đã nạp bridge; file cleanup không unload image hoặc remove observer đang sống. Không tuyên bố migration runtime hoàn tất trước bước này.
6. Đổi injection/Phase-B/RootHide/static CI contract sang bridge-absent. Kiểm tra cả package giải nén và nội dung build staging cũ.

Acceptance: fresh install và upgrade từ bản có bridge; không có bridge dylib/plist trong package/injector sau migration; UI mở lại không tái tạo; empty/scoped/extensions/WebKit/SpringBoard vẫn giữ filter policy hiện hành; legacy archive restore vẫn chạy helper, không launch target app.

Gates: `audit_backup_restore_hardening.py`, `test_phase_b_regression_static.py`, `test_roothide_build_static.py`, `test_bootstrap_policy.py`, `test_bootstrap_topology.py`, `test_webkit_unscoped_zero_interference.py`; native injection fixtures và CI package verification tương ứng.

### Patch 2 — P0-B: sửa NSURLSession blocking lifecycle

Phạm vi: `DomainBlockingHooks.x`, phần blocking adapter cần thiết và runtime regression fixture.

Tiến độ và bằng chứng: [báo cáo Patch 2](audit-implementation/PATCH-2-domain-task-lifecycle.md).

1. Bỏ dispatch_after completion từ task factory và các task giả đã cancel trả về. Không thêm delay hoặc kết nối localhost để mô phỏng lỗi.
2. Blocking phải gắn với lifecycle thật của task và giữ session delegate/completion queue, original task/request metadata và cancellation semantics.
3. Đã điều chỉnh hướng triển khai sau kiểm tra tài liệu Apple: custom NSURLProtocol không hỗ trợ background sessions. Adapter giữ task thật, đánh giá policy tại `resume`, gọi native `cancel` khi cần chặn rồi forward original resume đúng một lần. Foundation quyết định completion/delegate queue và state; lỗi chặn chuyển thành `NSURLErrorCancelled`. Không rewrite request của NSURLSession, không sửa session configuration. Native fixture phải xác nhận contract; hỗ trợ selector không đồng nghĩa đã xác minh mọi loại task trên iOS.
4. Shared/default/ephemeral, background, data/upload/download và các hook khác cùng process phải được đối chiếu. Không ship một refactor làm mất coverage đã xác nhận; surface chưa được hỗ trợ phải có kết luận và phương án cụ thể trong report của patch, không giả callback để che khoảng trống.
5. Requests ngoài scope hoặc không bị block giữ nguyên. Bảo vệ against recursion và không chạy completion khi task chưa resume, ngoại trừ behavior cancellation vốn có của Foundation đã được fixture xác nhận.

Acceptance runtime: create/no resume; resume; cancel trước resume; cancel khi đang chạy; suspend/resume; invalidated session; custom serial delegate queue; nil/valid handlers theo API contract; callback đúng số lần/queue/error/task state; blocked request không phát network traffic; unblocked request không bị thay đổi.

Gate hoàn tất là runtime Foundation/iOS fixture và build Logos thực tế; source regex hoặc Python model riêng không đủ để tuyên bố lifecycle đúng.

### Patch 3 — P0-C: bỏ delegate interception trên NSObject

Phạm vi: LocationSpoofing group trong `Tweak.x`, delegate installation registry/helper và location tests.

Tiến độ và bằng chứng: [báo cáo Patch 3](audit-implementation/PATCH-3-concrete-location-delegates.md).

1. Không thêm/hook CoreLocation optional delegate selectors trên NSObject.
2. Khi setDelegate, chỉ intercept class/selector thực tế có implementation; xử lý inherited implementation bằng class-local installation để không sửa superclass ngoài phạm vi.
3. Lưu original IMP theo class + selector; validate đầy đủ ABI; installation idempotent và thread-safe. Không fabricate method mà delegate vốn không implement.
4. Giữ identity delegate, location objects, batch array, callback arguments/queue và forwarding đúng một lần; xử lý subclass override gọi super để không advance generation hai lần.
5. Không giữ strong reference không cần thiết tới delegate hoặc manager. Delegate change/nil/dealloc không để lại callback tới object chết.

Acceptance: concrete/inherited/override+super delegates; nhiều manager và delegate classes; setDelegate lặp lại; nil; optional selector absent; scope/toggle đổi; callback đang chạy; ABI mismatch. NSObject selector surface không thay đổi.

Cập nhật `test_location_direct_semantics_static.py` từ ràng buộc source Logos cũ sang semantic contracts mới; bổ sung native/runtime fixture thay vì chỉ sửa regex cho pass.

### Patch 4 — P1-A: runtime snapshot transactional publication model

Chia thành 4A/4B/4C để review được, nhưng chỉ tuyên bố hoàn tất khi cả reader, publisher và source writer contracts cùng đạt.

**4A — Captured reader API**

Triển khai qua hai bước để native fixture kiểm chứng reader trước khi chuyển toàn bộ hooks. [Báo cáo 4A.1](audit-implementation/PATCH-4A-1-runtime-reader-core.md) ghi reader core/BootTime và [báo cáo 4A.2](audit-implementation/PATCH-4A-2-captured-runtime-consumers.md) ghi rollout scope/identity/identifier state, data consumers và operation boundaries trên RootHide. Rootful giữ các live-file readers hiện hành để không đổi authority trước source-writer contract 4C. Không coi 4A/runtime acceptance hoặc toàn bộ transactional model đã đạt chỉ dựa vào build/source checks.

- Tạo immutable runtime snapshot có publisherEpoch, uint64 revision, schemaVersion và dữ liệu đã validate/deep-copy cần thiết.
- Mỗi logical operation acquire một lần, giữ strong reference tới snapshot rồi đọc fields/artifacts từ nó; truyền snapshot vào helper liên quan thay vì helper acquire lại.
- Migrate tất cả runtime consumers liên quan: scope, identifier state, boot/uptime, carrier/network, theme, battery, storage, UserDefaults và các accessors còn lại. Cập nhật source-contract tests đòi exact accessor strings.
- Refresh trên queue riêng có coalescing/in-flight generation guard; disk parse không nằm trên hot hook. Có fallback refresh chậm cho notification bị mất.
- Giữ chính sách scope revocation/fail-closed hiện hành. Không dùng last-known-good để tiếp tục enable scope/toggle đã bị tắt; không tự siết identity validation ngoài phạm vi audit.

**4B — Single publisher và publication identity**

Tiến độ, policy partial distribution và giới hạn: [báo cáo 4B](audit-implementation/PATCH-4B-runtime-publisher.md). Native fixtures/CI và device matrix của lượt mới vẫn pending.

- Daemon dùng serial publication queue và process-shared ownership lease/lock tại path package/data đã resolve đúng và có permission phù hợp. Không dùng lock chỉ tồn tại trong memory.
- `--sync-once`: nếu daemon có ownership, request daemon thực hiện một sync và đợi acknowledgement có deadline; nếu chưa có daemon, chỉ publish sau khi lấy được ownership. Không tạo publisher cạnh tranh với daemon đang chạy.
- Upgrade từ daemon cũ chưa biết ownership lock: đổi thứ tự postinst để dừng publisher cũ trước khi chạy self-test/publisher mới. Không giả định lock mới có thể serialize binary cũ không tham gia protocol. `--sync-once` chỉ exit success khi operation được xác nhận thành công; timeout/partial failure phải được phản ánh đúng.
- Một epoch UUID cho mỗi incarnation sở hữu publisher; revision tăng trong epoch, gắn với publication candidate. Bỏ candidate thất bại có thể tạo khoảng trống revision nhưng không được reuse identity hoặc notify success sai.
- Giữ thứ tự capture/build/global write/mirror/notify trên cùng publication pipeline; coalesce notification burst. Reader so revision chỉ khi cùng epoch; epoch đổi phải đọc lại nguồn committed, không so UUID theo thứ tự hoặc nhận candidate stale từ refresh cũ.
- Dùng temp file riêng an toàn cho mỗi publication và atomic rename; không để hai call dùng chung `.tmp.<pid>`.
- Publication trả về chính snapshot và structured result vừa xuất, không đọc lại disk để suy đoán lần xuất của mình.
- Phân biệt global commit, mirror thành công, mirror lỗi/missing target và notified state. Retry mirror cùng publication có kiểm soát, tránh publication cũ overwrite publication mới. Có policy rõ cho disabled scope/stale mirror; không ghi nhận full success khi distribution còn lỗi.

**4C — Consistent source capture**

Chia 4C.1 core + settings/scope và 4C.2 writer rollout/authority để native fixtures kiểm chứng boundary trước async profile flows. [Báo cáo 4C.1](audit-implementation/PATCH-4C-1-source-transactions.md) và [manifest writers](audit-implementation/runtime-source-writers.json) ghi coverage thực tế; token source commit không bao phủ writer còn pending/external.

[Báo cáo 4C.2A](audit-implementation/PATCH-4C-2A-artifact-writers.md) ghi rollout manager artifacts và explicit-target stage functions. [Báo cáo 4C.2B](audit-implementation/PATCH-4C-2B-identifier-writers.md) ghi scalar pairs và schema migration. [Báo cáo 4C.2C](audit-implementation/PATCH-4C-2C-device-group-writers.md) ghi model/iOS/cellular dependencies và journaled deletion. [Báo cáo 4C.2D](audit-implementation/PATCH-4C-2D-telephony-writers.md) ghi standalone telephony validation/persistence; fields có producer trùng vẫn partial. Identifier/profile workflow và defaults authority là phần tiếp theo của 4C.2.

[Báo cáo 4C.2E](audit-implementation/PATCH-4C-2E-artifact-preparation.md) ghi preparation APIs không auto-save cho Wi-Fi/battery/uptime/storage, Battery một save mỗi batch và Wi-Fi signed time offset. Đây là prerequisite dùng lại trong production wrappers; whole-regenerate/profile commit và completion ordering vẫn pending, source coverage chưa tăng.

[Báo cáo 4C.2F](audit-implementation/PATCH-4C-2F-identity-preparation.md) ghi immutable model packet, scalar factories, Serial policy adapter và cache publication sau commit. Người dùng đã xác nhận build pass. Whole-regenerate composition được triển khai ở 4C.2G; profile lifecycle/completion vẫn là boundary riêng.

[Báo cáo 4C.2G](audit-implementation/PATCH-4C-2G-whole-regenerate.md) ghi một target/options, dependency compare trước staging, một source commit cho toàn batch + settings/scope, cache-only adoption và notifications sau commit. Giữ unconditional Wi-Fi, canonical model/cellular policy, gộp duplicate theme/uptime/storage saves. API void cũ giữ tương thích, thêm BOOL/error API cho lifecycle callers ở patch tiếp theo. Manifest enroll whole-regenerate; profile lifecycle/dashboard/security/defaults vẫn pending hoặc external. Build/native mới chờ macOS CI.

[Báo cáo 4C.2H1](audit-implementation/PATCH-4C-2H1-profile-creation-completion.md) ghi fixed profile ID/network packet cho worker create, completion success chỉ sau generation + metadata, main-thread entry routing/busy guard và canonical/legacy selection pair. Bỏ direct network writes/NSInvocation và unlink-before-replace archive fallback; ID allocation xét cả directories khi archive đã có IDs. H1 vẫn chọn profile trước generation: không claim toàn create/switch/directory lifecycle atomic, không tự rollback selection khi generation/metadata fail. Phần tiếp theo là activation sau prepared generation và recovery có ownership. Build/native H1 chờ CI.

[Báo cáo 4C.2H2](audit-implementation/PATCH-4C-2H2-conditional-activation.md) ghi inactive committed receipt, deferred settings/scope, metadata trước activation, full-record/presence proof và SelectionRevision CAS. Activation commit trước memory/defaults/cache/success effects; fail không tự ghi đè selection cũ. Startup ưu tiên committed selection, mirror cũ có guard, bootstrap không reset active profile; bốn UI read/render repairs chuyển sang read-only refresh, metadata edits chỉ cập nhật đúng current ID. Directory/registry cleanup và remaining writer authority vẫn cần bước tiếp theo; H2 không claim full lifecycle atomic. Người dùng đã xác nhận build H2 và CI macro fix pass; device/runtime matrix riêng vẫn cần kiểm chứng.

[Báo cáo 4C.2H3A](audit-implementation/PATCH-4C-2H3A-directory-reservation.md) ghi exclusive mkdirat reservation, descriptor-relative initial metadata, operation marker và inode/marker checks trước generation/metadata/activation. Không adopt existing directory, không tự xóa target khi create fail. Marker reserved không chứng minh orphan/ready và không cấp quyền cleanup. H3B tiếp theo cần lifecycle ownership chung cho registry/reconciliation/delete, vì legacy delete và path-based generation vẫn có cửa sổ thay path sau check. Người dùng xác nhận build H3A pass; device matrix riêng vẫn cần kiểm chứng.

[Báo cáo 4C.2H3B](audit-implementation/PATCH-4C-2H3B-lifecycle-coordination.md) ghi nonblocking lifecycle lease qua async create và các registry/selection producers, raw archive byte/presence CAS, load exclusion và legacy helper routing. Delete resolve theo ID + committed selection, commit fallback trước unregister, cleanup cuối cùng có directory proof; failure không rollback selection mới hơn. Registry/source/directory chưa là durable transaction, orphan cleanup tự động và remaining artifact-writer enrollment vẫn pending. Người dùng xác nhận build H3B pass; device matrix riêng vẫn cần kiểm chứng.

[Báo cáo 4C.2H3C](audit-implementation/PATCH-4C-2H3C-delete-decision-recovery.md) ghi write-ahead delete journal với source-atomic fallback/decision, registry installation marker và compensation phase. Archive After encode/validate trước activation; known-state replay chạy trước load, giữ source selection mới hơn và chặn unknown records. Recovery không retry recursive cleanup hoặc adopt reserved directories. First successful load yêu cầu publication để bao phủ settled-before-notify exit. Người dùng xác nhận build H3C và các sửa fixture pass; full directory/remaining writer contract vẫn pending.

[Báo cáo 4C.2H3D](audit-implementation/PATCH-4C-2H3D-generation-lifecycle.md) ghi whole-regenerate acquire lifecycle lease trước target lookup/migration, giữ qua preparation/source commit, rồi nhả trước compatibility publication. Create worker mượn capability đang có, không acquire lại hoặc invalidate lease của ProfileManager. Configured-root identity, target directory proof và pending delete journal được kiểm tra trước staging. Người dùng xác nhận build H3D pass; đây chưa phải full directory transaction hoặc total cache ordering.

[Báo cáo 4C.2H3E](audit-implementation/PATCH-4C-2H3E-network-lifecycle.md) ghi lifecycle ownership cho NetworkManager saves, forced refresh và getter tự persist khi thiếu dữ liệu. Scope giữ identity descriptor, kiểm tra parent/identity/journal trước staging, finally release khi provider throw. Saved read hits giữ đường đọc cũ; read miss recheck cùng active target sau acquire, không generate khi busy/pending. IPv6 precedence, paired commit và candidate-return contract cũ được giữ. Người dùng xác nhận build H3E và fixture RootHide header fix pass; device/runtime matrix riêng vẫn cần kiểm chứng.

[Báo cáo 4C.2H3F](audit-implementation/PATCH-4C-2H3F-storage-uptime-lifecycle.md) ghi existing-target ownership cho Uptime tuple và Storage current/explicit persistence. Storage pin profile root, không yêu cầu identity child ở legacy profiles; current lookup giữ canonical-file authority và chạy sau acquire. Uptime giữ identity FD xuyên sysctl/preparation/commit, nhả trước cache adoption/error logging, không tạo lại directory bị thiếu. Pure batch/create stages không acquire lồng. Standalone IdentifierManager, WiFi/Battery, dashboard preview, cache/thread-safety và preferences authority còn partial/pending. Build/native H3F chờ CI.

- Lập manifest mọi source file và writer trước khi đổi code: active profile selection, scope/security/settings, device IDs và profile artifacts.
- Đưa writer liên quan vào source transaction dùng process-shared lock/commit contract. Multi-file profile update và profile switch phải có commit boundary bao toàn bộ nhóm liên quan.
- Publisher capture nguồn dưới cùng contract, tạo detached immutable candidate rồi nhả source lock trước container scan/mirror. Lock order: publisher ownership -> source transaction; source writers không acquire publisher ownership hoặc gọi notification/callback bên ngoài khi đang giữ source lock.
- Validate profile/source commit identity và có bounded retry/recovery. Chỉ stat/mtime trước-sau chưa đủ chứng minh multi-file consistency nếu writers chưa tham gia contract.
- Giữ snapshot committed trước khi transient source update lỗi, nhưng publish explicit disable/revocation theo policy; phân biệt legacy source migration với malformed input, không âm thầm ghép từng field từ hai generation.

Acceptance: notification burst; simultaneous reader refresh; daemon restart/new epoch; `--sync-once` khi daemon đang sống; hai CLI đồng thời; source write/profile switch giữa capture; process crash giữa source transaction/global rename/mirror; disk full/permission error; partial mirrors; stale/corrupt/legacy snapshots; scope disable; container reset. Không mixed tuple trong một operation, không publish vượt thứ tự, không báo success giả.

### Patch 5 — P1-B: active UIDevice.systemVersion cache

- Bảo vệ value/time/publication identity như một cache unit, kể cả invalidation và destructor.
- Dùng monotonic time đúng đơn vị; tính giá trị ngoài publication lock và ngăn candidate cũ overwrite invalidation mới.
- Profile/scope/toggle change không trả cache cũ chỉ vì throttle chưa hết.
- Legacy IOSVersion hooked_sysctlbyname chưa có registration được retire riêng sau khi xác nhận call graph/generated artifact; không sửa thread-safety cho đường chưa chạy thay cho active hook.

Acceptance: concurrent getters/invalidation; active/off/out-of-scope; profile switch trong throttle window; arm64/arm64e timebase; original gọi đúng điều kiện/số lần; không recursive hook.

### Patch 6 — P1: sửa semantic defects nhỏ, tách patch độc lập

- CLHeading.headingAccuracy không trả heading angle; giữ original accuracy khi chưa có accuracy model riêng.
- CLRegion.containsCoordinate không trả YES vô điều kiện. Với circular region đã xác định rõ center/radius, đánh giá point theo projected region đúng mô hình; unknown region/subclass giữ original và không fabricate capability. Test trên concrete runtime classes.
- Wi-Fi/cellular có timestamps độc lập; giữ publication đồng bộ của từng cache unit.
- DNS `*res = NULL` chỉ là defensive hardening với res hợp lệ, không ghi như confirmed contract violation.

### Patch 7 — P1/P2: quyết định movement simulator

- Xác nhận runtime selector/JS/API callers ngoài static call sites nếu có; không dùng absence từ search như bằng chứng tuyệt đối không thể gọi.
- Nếu inactive: retire implementation và dependency thực sự không dùng, giữ active location projection/delegate behavior.
- Nếu active: sửa cả validation speed/nonfinite, bounded hoặc lazy generation và caller failure handling, startIndex/index reset/bounds, timer queue/lifecycle, completion exactly-once ngoài lock, reentrancy và persistence frequency.
- Không ship chỉ một guard speed <= 0 rồi coi cả state machine đã xong.

### Patch 8 — P2: performance sau profiling

Đo baseline và cùng workload sau sửa: launch, scroll/layout, request burst, sysctl/file activity, scope/profile changes và idle daemon. Thu CPU/time profiler, allocations, memory growth, filesystem activity, wakeups và callback latency.

Ưu tiên theo kết quả: hot-path logging; Theme trait allocation; normalized domain matcher; copy-on-write provider registry với short lock; notification + slow fallback/backoff cho polling; daemon log rotation và C-string serial lifetime.

Mỗi optimization có relative cost/workload, before/after evidence và off/out-of-scope parity. Không mặc định thay Theme hook bằng UI override hoặc đổi domain policy khi chưa chứng minh tương đương. Không thực hiện lock-free publication chỉ để bỏ một lock chưa đo.

## 4. Verification và release

- Local Windows: source inspection, host-independent gates và fixtures phù hợp. Chỉ tài liệu được thay đổi ở thời điểm chốt plan; không chạy lại toàn bộ gates chỉ vì thêm tài liệu.
- macOS/Theos CI: compile Logos/Objective-C thật, rootful arm64/arm64e và RootHide lane, extracted-package contracts, entitlement/path checks. Không dùng Python model như thay thế native compilation.
- Device: ít nhất một rootful lane còn hỗ trợ và một RootHide lane; app scoped/unscoped, extension, SpringBoard minimal, WebKit shared helpers. Ghi OS/architecture/jailbreak/hook runtime và kết quả thực tế; không tuyên bố matrix iOS 12+ đã pass nếu chưa có thiết bị tương ứng.
- Source/static tests hiện có phải giữ intent; thay assertions gắn với implementation đã retire bằng behavioral/absence contracts và runtime coverage cần thiết.
- Mỗi patch độc lập, reviewable, ghi rõ files/behavior/test evidence/limitations. Không squash nhiều subsystem thành một thay đổi không thể khoanh vùng regression.
- Release gate cuối: package bridge-absent + fresh/upgrade/reinstall tests, legacy helper restore, network lifecycle, delegate selector invariants, snapshot concurrency/fault injection và scope parity.
- Migration đang còn app nạp bridge phải được ghi trạng thái pending restart; không báo tất cả đã sạch chỉ dựa vào file absence.
- Không merge/deploy/publish hoặc terminate app trên thiết bị trong phạm vi chốt plan này.

## 5. Trình tự triển khai đã chốt

`Patch 1 -> Patch 2 -> Patch 3 -> Patch 4A/4B/4C -> Patch 5 -> Patch 6 -> Patch 7 -> Patch 8 -> release gate`.

Các điều kiện runtime/CI là exit criteria của từng patch; nếu environment chưa cung cấp phép kiểm tra đó, patch có thể được review nhưng phải giữ trạng thái chưa đạt release gate tương ứng.
