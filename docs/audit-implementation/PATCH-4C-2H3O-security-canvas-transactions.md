# Patch 4C.2H3O — security/Canvas source transactions

Người dùng xác nhận build H3N pass. H3O chuyển shared security writes và ba Canvas entry points sang shared source contract. Security source/store/direct writers chỉ được đánh dấu partial; chưa giải quyết physical preference-domain authority của cfprefsd. Patch 4 và Patch 5–8 chưa hoàn tất.

## Vấn đề và thay đổi

Shared store cũ có separate flock không deadline, không CLOEXEC/NOFOLLOW, và nằm ngoài source gate/token. Read/modify/write dùng dictionaryWithContentsOfFile rồi fallback empty nên malformed source có thể bị thay bằng dictionary mới. Canvas aliases/detail writes bỏ qua store; nonce reset đọc rồi tăng ngoài coordination, có thể mất increments giữa cooperating callers. NSUserDefaults exception sau source write có thể propagate dù primary source đã ghi xong.

Thêm `PXWriteSecuritySettings` cho multi-key update packet, deep-detach property-list graph trước source gate; API single key/Bool/Integer giữ signatures và delegate sang packet. Existing keys được merge trong transaction, malformed dictionary fail thay vì reset empty, unrelated keys giữ nguyên. Empty packet là no-op, invalid key/value/payload fail trước source entry. Security file dùng serializer của source engine; reader/property-list field types không đổi, không yêu cầu giữ XML formatting cũ.

`PXAdvanceSecurityNonce` đọc và advance trong cùng source transaction, giữ uint32 wrap UINT32_MAX → 1 và không sinh zero. Wrong-type nonce không nhận unsafe numeric selector, dùng missing/default-zero policy. Output parameter chỉ đổi khi commit thành công. Không generation timestamp hoặc caller-side read được dùng làm counter authority.

IdentifierManager Canvas toggle ghi hai aliases trong một packet; reset noise dùng atomic nonce helper. CanvasDetail persistValues cũng dùng packet. Các callers giữ topics/số notification như cũ và không notify trên source failure. Không thêm notification vào generic store hoặc đổi reader/default fallback policy.

## Standalone commit acknowledgement

Source engine cũ cho nested write chia sẻ staged state của outer transaction. Một high-level API gọi mirror ngay sau nested return sẽ phát compatibility effects trước outer commit, thậm chí outer sau đó abort. Vì vậy H3O thêm `performStandaloneWrite` và `PXPerformStandaloneRuntimeSourceWrite`: nested invocation bị reject và đánh dấu outer transaction failure, kể cả caller bỏ qua return. Write từ capture cũng bị reject.

Regular `performWrite` vẫn allow nested staging, giữ các semantics trước đây. Cả hai đi qua cùng implementation với một deadline hiện có, owner check, recovery, source lock/journal và finally cleanup; không thêm lock layer hay chờ thêm một deadline khác. Security store dùng standalone variant để YES biểu thị primary source đã commit trước mirror.

Compatibility mirrors giữ cả ba suite như cũ, set từng changed key và synchronize sau source gate release. Exception ở một suite không ngăn các suite khác và không phủ nhận committed result. Mirror callback có thể re-enter standalone API khi source gate đã nhả. Không compensation một primary commit đã thành công vì compatibility callback lỗi.

## Authority và compatibility còn partial

`PXSecuritySettingsPath` vẫn là physical com.weaponx.securitySettings preference plist. NSUserDefaults/cfprefsd và các direct writers chưa chuyển vẫn có thể ghi ngoài source contract; source token không bao phủ các lần ghi đó. Mirror ordering, crash giữa source/mirror/notify, stale defaults caches và cross-process convergence chưa được giải quyết. Không tuyên bố nonce globally monotonic hoặc không mất increment khi có unenrolled domain rewrite; concurrency guarantee của primitive chỉ áp dụng cho cooperating source transactions.

Không đổi đường dẫn/canonical precedence, các legacy suites, profile selection hoặc role classification ở mốc này. New writes tuân source-owner policy của engine (production mobile uid 501), có thể fail với role không được phép write/recover dù role đó đọc được settings. Cần device/process matrix; không tự cấp root writer capability. IP monitor/indicator position/timezone/metrics và các security direct writers khác vẫn pending trong entry partial.

Global security mutation không acquire profile lifecycle: không phụ thuộc active profile tồn tại. Source gate bảo vệ cooperative file state; không giải quyết synchronization của mutable UI/cache objects hoặc caller mutation trong lúc input đang được detach. Read APIs giữ nguyên, bao gồm các stored-type/range validation limitations chưa audit xong.

## Performance và lifecycle

Retire separate security lock; source gate có deadline/ownership/descriptor checks hiện có. Writer vẫn synchronous như trước, thêm binary packet detach/journal I/O và có thể contention với source writers khác. Expected cost low–moderate trên cold settings writes, chưa benchmark; không claim main-thread latency đã được đo. Generic store vẫn ba suite mirrors; CanvasDetail nay dùng shared compatibility policy nên có thêm mirrors so với đường ghi riêng trước đây. Không thêm timers/polling/queues/hot-hook reads.

Alias batch chỉ có một source commit và một mirror phase, không gọi single-key writer hai lần. Nonce work nằm trong source transaction, không public arbitrary callback dưới gate. Provider/defaults/notification effects xảy ra sau commit. Không giữ persistent blocks/capabilities hoặc thêm retain cycle; source FD lifecycle vẫn do existing engine quản lý.

## Kiểm chứng

Native fixture include actual production store source với NSUserDefaults backend alias chỉ trong test, không ghi user preference domains. Exact IdentifierManager Canvas methods và CanvasDetail method được extract thành hai fragments; Darwin/settings callbacks được intercept, không phát IPC. Actual source engine/publisher serializer được link, owner test là geteuid. RootHide-defined fixture kiểm tra compile/write path; captured RootHide reader behavior vẫn do existing reader fixtures kiểm tra, không suy từ nil snapshot backend sang device coverage.

Cases: empty/invalid packets, detached mutable input, một packet commit, unrelated merge, mirror-after-commit/gate release, mirror exception và re-entry, nested rejection/ignored-error outer abort, capture re-entry, write fault rollback bytes/token/nonce output, malformed source preservation, nonce wrap/type guard và 48 concurrent increments không duplicate trong cooperative fixture. Canvas aliases/detail/nonce success giữ topics; source failure suppress toàn bộ mirrors/notifications. Macro validation bao new fixture.

Windows pass 21 source/host checks: security writer, source transactions, security UI, native OS safety, profile creation, identifier, dashboard, device-group, generation, artifact preparation/writers, identity preparation, telephony, snapshot reader/consumers/publisher, release hardening, RootHide, thread-safety cleanup, iOS DB và Canvas JS. Thread-safety matrix giữ 80/80. Exact native fragments/production include và diff checks được xác nhận; tests không mô phỏng cfprefsd rewrites hoặc kernel crash/power loss.

New security native runner được đăng ký CI rootful và RootHide-defined lanes, cùng existing source-engine native regression suite. Máy Windows không có Foundation/xcrun/Theos: native compile/runtime và package H3O vẫn cần macOS CI xác nhận.

## CI follow-up — Canvas failure diagnostic gate (2026-10-27)

`test_canvas_noise_controls_static.py` còn yêu cầu nguyên văn log `Failed to persist Canvas Fingerprint Protection`. H3O dùng diagnostic `Failed to persist Canvas protection: %@`; actual setter vẫn log NSError, return NO trước notification khi packet write fail. Assertion cũ còn tìm `return NO;` ở toàn file, nên không chứng minh được failure branch của đúng setter. Đây là gate chưa đồng bộ, không cần đổi production behavior để giữ câu log cũ.

Gate nay extract đúng setter, kiểm tra paired alias packet qua shared writer, error logging/return NO trong guarded failure branch, không notify ở branch này và notify/return YES sau success. Toggle và nonce checks cũng giới hạn trong đúng methods. Bốn negative cases kiểm tra missing failure return, missing NSError diagnostic, inverted write result và success notification trong failure branch; một positive case xác nhận đổi wording diagnostic vẫn pass. Existing native writer fixture đã kiểm tra source-fault rollback và không mirror/notify cho cả Canvas alias/detail/nonce; follow-up không thay native production fragments.

Windows: Canvas controls và transactional security gates pass; exact Canvas native fragment extraction 2/2 và diff check pass. Chạy độc lập toàn bộ 62 Python/Node suites trong release inventory để không dừng ở lỗi đầu: 61 pass, riêng Keychain Bridge retirement migration suite fail khi Git Bash `mkdir` truy cập `/c/Users/ADMIN` (Permission denied), cả khi chuyển scratch directory vào workspace. Official two-iteration release runner dừng ở lỗi môi trường này; không claim complete release regression pass hoặc native/package validation. Native rootful/RootHide-defined compile/runtime và migration trên macOS CI vẫn cần xác nhận.

## Tiếp theo

Cần chốt canonical authority/import/mirror migration trước khi security source lên enrolled, đồng thời chuyển remaining direct/defaults/CFPreferences writers và đối chiếu legacy readers. Settings/defaults authority, whole Reset Data workflow, cache/publication ordering, rootful captured readers và directory durability vẫn partial. Không thêm automatic cleanup/retry hoặc thay behavior của các writers chưa chuyển.
