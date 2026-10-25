# Patch 4B — single runtime publisher và publication identity

Ngày: 2026-10-24. Patch 4A.2 và bootstrap fixture dependency đã được người dùng xác nhận build pass. Báo cáo này ghi thay đổi publisher tiếp theo; không thay thế release/device acceptance của Patch 4.

## Behavior và ownership

`PXRuntimePublisher` thực hiện capture -> detach/freeze -> global write -> mirror -> notify trên một queue serial. Darwin callbacks chỉ enqueue, `DISPATCH_SOURCE_TYPE_DATA_OR` coalesce burst thành một lượt tiếp theo nếu lượt trước đang chạy. Cơ chế này theo [Apple dispatch_source_merge_data](https://developer.apple.com/documentation/dispatch/dispatch_source_merge_data).

Daemon lấy exclusive `flock(LOCK_EX | LOCK_NB)` trước khi start; giữ descriptor trong suốt ownership. Lock nằm tại `<resolved runtime directory>/publisher/publisher.lock`, thư mục 0700, lock 0600, thuộc effective UID của privileged process. Lock inode ổn định, không unlink; open dùng O_NOFOLLOW/O_CLOEXEC, kiểm tra regular file, owner và link count. App/tweak không tạo publisher trong ctor hay reader. `PXCreateRuntimeSnapshotPublisher` chỉ được gọi từ daemon main. Semantics close/process-exit releasing ownership dựa trên [Apple flock(2)](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/flock.2.html); fixture mới kiểm tra process thực.

Mỗi incarnation lấy ownership có epoch UUID mới, revision uint64 tăng riêng, bắt đầu 1, không dùng profile generation hay wall clock làm identity. Lượt lỗi có thể bỏ qua revision; không reuse. Schema 2 được reader 4A hỗ trợ sẵn; compatibility loader nay validate cả schema 1/2 bằng cùng production view validator. Injected rootful vẫn giữ live-source authority hiện hành; thay đổi publisher không tự migrate các reader rootful.

Ghi global/mirror dùng `mkstemp` cùng thư mục target, write đầy đủ với EINTR handling, fchown/fchmod trước rename, cleanup đúng temp của chính lần ghi. Không dùng lại `.tmp.<pid>`. Đây là atomic namespace replacement; chưa hứa power-loss durability/fsync hay atomic transaction bao mọi mirror.

## Sync-once và acknowledgement

- Khi không có owner, CLI lấy lease rồi publish. Self-test standalone giữ bước sync filter trước publication.
- Nếu owner đang chạy, CLI đặt UUID request trong thư mục publisher và đợi ack tương ứng. Darwin notification chỉ là wakeup hint; timer daemon 0.5s đã có cũng service requests. Không thêm daemon polling timer.
- Daemon capture danh sách request trước lượt publication, ghi ack với chính structured result của lượt đó; request đến sau được xử lý lượt sau. Hai CLI có thể cùng nhận một publication nếu requests được batch trước capture.
- Deadline chờ ack ở daemon main là 10s, engine giới hạn tối đa 30s, dùng monotonic clock. Khoảng ngủ 50ms chỉ nằm trên CLI đang chờ có deadline, không nằm trên hooks.
- Nếu owner chết, flock được giải phóng; contender có thể lấy ownership và publish trong epoch mới. Không publish nếu chưa lấy được lease. Timeout/partial mirror/notification failure exit nonzero. Ack/request bỏ dở quá 120s được dọn khi daemon service.
- Ack xác nhận **runtime publication**, không phải bằng chứng mọi filter installation thành công: filter sync là subsystem cũ, chưa có structured success contract. Khi daemon nhận wakeup, filter sync vẫn được chạy; fallback timer vẫn theo staging fingerprint. Không mở rộng lời hứa của `--sync-once` sang các bước chưa có kết quả kiểm chứng.

`DEBIAN/postinst` đã bootout/unload daemon cũ trước self-test từ Patch 1; giữ thứ tự đó vì binary cũ không tham gia lock mới. Chưa có bằng chứng device rằng legacy launchctl fallback đã dừng mọi binary cũ trong tất cả môi trường. Không dùng lock mới để tuyên bố serialize được publisher cũ không hợp tác.

## Structured result và convergence

Result gồm `snapshot`, `globalCommitted`, `distributionComplete`, `notified`, `success`, `stats`, `error`. Daemon dùng đúng result để ghi debug; bỏ API publish không cần lease và global LastPublishStats/read-after-write. `success` chỉ true khi global đã commit, distribution complete và notify thành công.

RootHide distribution ghi nhận scan/parent creation/permissions/write/removal failures và enabled bundles không có container. Missing target được đánh dấu incomplete; không âm thầm tính là full success. Bundle đã uninstall nhưng còn scope cần được dọn scope hoặc chờ container xuất hiện. Giữ policy xóa mirror của bundle bị disable; xóa lỗi phải ghi nhận và retry. Không giữ thêm profile data trong container bị bỏ scope chỉ để thay policy.

Notification được post sau mirror attempts, kể cả partial distribution, để containers đã cập nhật hoặc đã thu hồi scope được refresh. Không đánh đồng `notified=YES` với full success. Target không thể ghi/xóa vẫn có thể giữ mirror cũ; không hứa revocation ngay lập tức trên target đang lỗi I/O. Trạng thái incomplete và retry là bằng chứng cần xử lý.

Retry mirror/notify dùng **cùng immutable committed snapshot**, không recapture hoặc ghi global lại. Backoff 2..32s, được kích bởi timer đã có. New publication thay thế pending retry, tránh snapshot cũ ghi đè sau snapshot mới. Capture/global write failure được retry bằng lượt mới/identity mới dù không có source notification tiếp theo. Thêm profile `settings.plist` vào fingerprint fallback vốn đã theo dõi các nguồn khác.

## Tests và giới hạn

`scripts/test_runtime_snapshot_publisher.py --native` link production engine **và** runtime/paths/reader/scope adapters để không bỏ sót transitive linker dependencies. Fixture dùng filesystem tạm và child processes của chính fixture, không chạm target apps hoặc production `/Library` paths. Scenarios: immutable detach, schema 2 reader, 32 concurrent explicit publications, revision gaps, loader exception recovery, reentry, partial/notify/global failures, retry/supersession, 128-event burst, hai CLI ack, partial nonzero exit, ack timeout, owner process exit/new epoch, 64 concurrent atomic writes và rejected symlink ownership directory. Chạy 3 process fixture mới trong CI.

Native engine fixture inject loader/distributor/notifier; không tự chứng minh actual iOS container enumeration/permissions hay Darwin delivery qua RootHide bootstrap. Adapter sources được compile/link trong macOS fixture; RootHide mirror branch cần build lane và device tests riêng. Không chạy native Foundation/Theos tại Windows.

Host verification: publisher/reader/consumer contracts, bootstrap topology/policy, RootHide build, Phase 10/Phase B, WebKit zero-interference, P3, security UI/iOS12, native OS safety, iFake parity, missing hooks, device/hardware/WebGL, domain/location và canvas controls pass. Backup audit PASS 2560/2560 và audit self-test PASS 55/55. Bộ retirement migration cũ chạy trên host này gặp Git Bash `/c/Users/ADMIN` permission/path mapping; source contract của bộ đó pass, chưa kết luận full shell fixture pass.

Chưa commit/push/deploy hoặc terminate app. Gate kế tiếp: CI compile/native fixture mới và RootHide/rootful build; device simultaneous CLI/daemon restart/partial mirror/scope disable/container reset. Source writers vẫn chưa tham gia transaction: 4C phải lập manifest writer và capture dưới shared source commit contract. Không coi ordered publication là multi-file source consistency. Container mới/reset sau một lượt distribution complete vẫn cần event/sync để remirror; chưa thêm periodic full container rewrite khi chưa có device evidence cho cadence thích hợp.
