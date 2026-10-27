# Patch 4C.2H3H — battery persistence và publication ordering

Người dùng xác nhận build H3G pass. H3H xử lý standalone BatteryManager source/mirror/notification flow. Patch 4 vẫn partial; đây không phải full cache/authority rollout.

## Vấn đề đã xác định từ code

Battery save ghi global mirror trước khi commit profile battery_info/device_ids; source commit fail vẫn có thể để global mirror chứa candidate mới. Generate và LPM setter còn phát notifications sau void save bất kể persistence có thành công. Profile path helper được gọi từ reads lại tạo identity directory, nên một read có thể tái tạo target đã bị delete. Getter sửa missing/out-of-range level gọi generateBatteryLevel (đã save qua randomize) rồi save lại lần nữa.

Các đường chạy trên có bằng chứng source rõ ràng. Chưa có số benchmark hoặc device race reproducer; native fault fixtures mới cần macOS CI xác nhận.

## Flow mới

`batteryRecordForLevel:lowPowerMode:` tạo một immutable packet với level đã copy, LPM và một timestamp. Generate dùng packet lấy từ UI candidate, LPM setter lấy requested Boolean, ordinary save lấy cache. Không đọc lại cache để tạo mirror hoặc local-notification level sau source commit. Giữ level distribution, percentage UI, LPM non-randomization và source field types cũ.

`persistBatteryRecord:` acquire nonblocking lifecycle ownership, kiểm tra configured root/pending deletion rồi đọc canonical selection một lần. Valid active ID phải có existing identity; scope giữ directory FD và validate trước battery_info/device_ids stage. Profile commit thành công mới đi tới mirror. Failure, busy, invalid ID, missing target hoặc pending recovery giữ source/mirror cũ và không phát success notification. Không tạo directory profile hoặc downgrade một intended target lỗi thành global-only success.

Không có canonical active ID vẫn là nhánh global-only, giữ authority cũ (không chọn legacy active ID làm write target). Nhánh này cũng phải acquire ownership và vượt qua recovery preflight. Mirror write là intended persistence của nhánh global-only; mirror failure trả NO/error và không notify. Namespace không tồn tại/không truy cập được nay khiến mutation fail trước mirror, không tạo profiles root để hợp thức hóa write. Global **read** fallback vẫn hoạt động khi root unavailable. Đây là fail-closed constraint mới cho coordination, không phải thay đổi chính sách giá trị.

Scope và lease được invalidate trong finally trước standalone mirror/log/notification. Mirror là compatibility output, không phải source transaction hoặc snapshot field. Mirror lỗi sau profile commit không được undo source hoặc báo profile rollback: source success vẫn notify, warning được log. Với global-only thì chưa có committed profile để dựa vào, nên mirror failure là failure thực sự.

Generate vẫn cache-first và trả UI candidate khi persist fail; setters cũng giữ cache changes theo contract cũ. lastError là persistence outcome; candidate không phải acknowledgement. Chỉ generate/LPM success paths phát notifications như trước, với payload shape/topic giữ nguyên. Randomize/plain save không thêm notifications. Không compensate khi observer callback sau commit có lỗi; source đã commit vẫn tồn tại.

## Borrowed capability và cleanup

Battery cần giữ ownership trong khi phân biệt active-profile với global-only branch. Identity scope acquire riêng sẽ tự conflict. `borrowWithLifecycleLease:identityResolver:error:` mới dùng capability đã có, validate đúng configured root và pin identity mà không acquire lại. `ownsLease` chỉ true cho existing owned factories; invalidate/dealloc luôn đóng directory FD, nhưng chỉ invalidate lifecycle nếu scope tự sở hữu nó.

Nil/released/wrong-root capability bị reject; failed/throwing resolver hoặc directory/journal conflict không nhả lease của caller. Battery kết thúc borrowed scope rồi invalidate parent lease. API borrow là synchronous cooperation contract: caller phải giữ sống/giữ lock, không invalidate đồng thời với scope. Không thêm thread-local implicit reentrancy hoặc silent lease reuse.

## Read path và performance

Profile-path helper nay chỉ đọc canonical selection và resolve validated path, không mkdir, không writer lock hoặc log lỗi no-active mỗi read. Load giữ canonical identity → pre-identity legacy → global fallback, cùng missing-LPM default. Không thêm TTL/cache policy hoặc thay stored-value validation ở mốc này. Initializer vẫn không gọi UIDevice.batteryLevel, giữ recursion avoidance trước đây.

Getter repair bỏ hai explicit duplicate saves vì generateBatteryLevel đã persist qua randomize. Mỗi repair branch nay một profile commit/mirror thay vì hai; đây là giảm duplicate work chứng minh từ call flow, không phải benchmark throughput. Một packet/timestamp được dùng chung cho profile/mirror, giảm dictionary/timestamp preparation trùng.

Cold writes có thêm lifecycle/pending-state reads và directory checkpoints, expected cost low–moderate, chưa benchmark. Active operation giữ tối đa hai lease FDs và một scope FD; global-only chỉ giữ lease. Không giữ source gate qua mirror hoặc callback, không thêm timer, polling, network hoặc persistent queue. Live-file read I/O, mutable cache races và source/mirror total ordering vẫn là boundary riêng.

## Kiểm chứng và compatibility

Preparation runner thêm exact production battery getter/load/save/generate/setter/record/mirror methods vào owned fixture; scope/lease/journal/source engine compile thật. UIKit init được để ngoài Foundation fixture, giữ fake cache defaults; Darwin delivery được intercept để không phát production IPC. Pure preparation/cache-adoption fixture cũ vẫn kiểm tra one-save generation và post-commit publisher; publisher dùng lại mirror helper nhưng không acquire hoặc start source write mới.

Cases mới kiểm tra profile commit trước mirror/notifications, source rollback giữ mirror và suppress notifications, busy/pending, invalid/missing active target không fallback, real filesystem mirror failure sau commit, global-only success/failure, immutable level packet, absent device_ids không bị tạo thêm, readonly legacy/global fallback và root-unavailable read/write split, nil packet failure, một save khi getter repair. Callback/mirror probes xác nhận standalone lease/source gate đã nhả.

Borrowed-scope cases dùng actual staging/commit, kiểm tra invalidate/fail/throw không nhả caller, nil/wrong-root/released lease, replaced identity và late journal chặn staging. Các owned Network/WiFi/Storage/Uptime tests giữ nguyên để bắt regression từ factory thay đổi. Host macro validation bao fixture và exact fragment extraction vẫn dùng production methods, không copy commit logic.

Windows đã pass 15 source/host gates, macro validation, exact native-fragment extraction và git diff check. Foundation/Theos native H3H chưa chạy trên máy này; cần macOS CI. RootHide define fixture không xác nhận actual SDK/namespace hoặc iOS device behavior.

Sau phản hồi CI: owned battery fragment gọi PXRequireNoPendingProfileDeletion nhưng fixture chưa import PXProfileDeletionJournal.h. Runner đã link implementation, tuy nhiên compile vẫn cần declaration trước include method bodies. Đã thêm header thật vào fixture và source regression kiểm tra import đứng trước PXOwnedBatteryMethods.inc; không thêm forward declaration giả hoặc tắt implicit-function-declaration error. Bốn source/host gates liên quan, exact battery-fragment extraction và diff check pass sau sửa. Production BatteryManager đã có import này và không đổi; native compile/runtime sau sửa vẫn chờ macOS CI.

## Giới hạn và tiếp theo

Global mirror ghi sau release vẫn có thể bị publisher mới hơn vượt qua; mirror/notifications không có total ordering hoặc durable crash-retry. Process exit sau source commit nhưng trước mirror/notify vẫn là convergence concern. Batch/create publication có caller ordering riêng từ H2/H3D; H3H không reorder các adapters hoặc invalidate lease của caller publishCommittedBatteryInfo. Không claim mọi battery callback đều chạy khi mọi caller lease đã nhả.

Mutable cache/thread safety, malformed stored-field type handling, cross-process memory freshness, standalone IdentifierManager writers/migration, dashboard preview, metadata/defaults/security authority, rootful captured reader rollout, full directory cleanup/durability và device matrix còn partial/pending. Scope checks không namespace-isolate writer bỏ qua lease sau checkpoint. Không thêm recursive cleanup, fsync/power-loss guarantee hoặc automatic recovery retry. Patch 5–8 chưa triển khai.
