# Patch 4C.2H3F — standalone Storage/Uptime lifecycle ownership

Người dùng xác nhận build H3E và native RootHide header fix pass. H3F tiếp tục writer enrollment với Uptime và Storage, giữ nguyên chính sách giá trị/đơn vị và pure batch composition. Patch 4 chưa hoàn tất.

## Vấn đề và boundary mới

Uptime/Storage đã có source transactions, nhưng chưa tham gia lifecycle ownership trong khoảng target resolution/preparation/persistence. Uptime còn gọi createDirectory trước source commit, có thể tạo lại identity directory sau một delete. Đây là cửa sổ concurrency suy ra trực tiếp từ code; chưa có benchmark hoặc runtime race reproducer trên iOS.

Uptime generation nay acquire identity scope trước sysctl và random preparation, giữ lease cùng target FD qua boot_time/system_uptime/device_ids commit. Directory bị thiếu/replaced/symlink hoặc pending deletion chặn operation. Bỏ createDirectory ở mutation này; registry/create lifecycle là nơi quản lý directory. Mutable explicit path được copy trước preparation, không retarget khi caller sửa string. Source fault hoặc provider exception giữ cache cũ; successful commit nhả scope trước cache setters/logging. Catch nhả scope trước error logging, finally là cleanup chung.

Storage current/explicit saves dùng private `persistStorageToProfile:current:error:`. Scope được acquire trước current selection-file read và cache snapshot. Current writer tiếp tục lấy ID từ canonical current_profile_info, không tự đổi sang legacy/default/current-memory authority. Explicit writer không tra lại active profile và vẫn hỗ trợ inactive target. Sau snapshot, full storage record được stage một lần theo replacement behavior cũ; không thay thành merge hoặc đổi policy unknown keys.

## Profile-root scope và compatibility

Storage ghi `<profile>/storage.plist`, không phụ thuộc `<profile>/identity`. Dùng thẳng identity scope của H3E sẽ reject một legacy storage-only profile hợp lệ. `acquireWithProfileIDResolver:error:` mới pin profile root, không yêu cầu hoặc tạo identity child. Identity factory cho Network/Uptime vẫn pin identity directory. Cả hai dùng chung acquire/validate/journal/source-stage flow, cùng held-directory FD và raw parent proof, không nhân đôi lock/cleanup logic.

Resolver chỉ chạy sau nonblocking lifecycle acquisition và initial pending-delete check. Trước stage, scope kiểm tra configured root/lease, profile proof, held descriptor so với target pathname và journal absence. Source body chỉ stage dữ liệu; provider/cache/logging không chạy bên trong source gate. Cuối operation đóng directory FD và hai lease descriptors; explicit invalidate và dealloc đều có cleanup.

Existing profile root có thể lưu storage dù thiếu identity; Uptime phải có identity hiện hữu. Missing profile roots không được writer tái tạo. Invalid canonical storage ID trả error ở internal persistence helper trước snapshot. Public void APIs giữ contract hiện có và log save failure; không thêm approval/retry flow hoặc public success callback.

## Những behavior giữ nguyên và phần chưa giải quyết

- Giữ uptime distribution, real-uptime cap, legacy minimum, timestamp sampling và persisted BootTime/SystemUptime types/version. Không đổi fallback return policy của legacy Uptime getters: sau generation failure chúng vẫn có thể trả giá trị đã lưu hoặc safe default, không phải persistence acknowledgement.
- Storage setters vẫn sửa mutable cache trước từng autosave; ba setters là ba operations riêng. Không claim atomic tuple giữa setter calls, storage với model/device_ids, hoặc rollback cache khi save fail. Dashboard preview vẫn pending.
- Pure prepare/adopt/stage APIs dùng trong batch/create không acquire lease mới, tránh self-conflict với ownership của caller. Không đổi activation ordering hay battery/global mirror.
- Explicit inactive Uptime generation vẫn cập nhật global manager cache theo behavior cũ. Cache adoption sau release không có total ordering với writer kế tiếp. Mutable manager caches, concurrent setter/read races, caller-side migration/creation trước API này và live-file readers vẫn là boundary riêng.
- Scope checks là cooperation checkpoints, không descriptor-relative source writes hoặc namespace isolation với old binaries/direct external writers sau check. Không thêm recursive cleanup, reconciliation retry hoặc power-loss durability claim.

## Kiểm chứng

Native preparation fixture trích xuất exact Storage/Uptime production methods và link scope, lifecycle lease, delete journal, selection helpers, source engine thật. Không subclass Foundation class clusters: storage snapshot spy là NSObject/NSCopying để quan sát capture boundary; Uptime sysctl adapter giữ real sysctl call và thêm fault/callback observation. Fixture paths/role và log/notification sinks tiếp tục là test backends, không thay commit algorithm.

Các case mới kiểm tra:

- Storage explicit inactive/current target, một source commit, busy/pending trước snapshot, canonical-only authority khi legacy record tồn tại, malformed selection, fixed target khi bypass writer đổi selection trong preparation.
- Storage-only profile không có identity, absence/replacement/symlink của profile root, cache-copy exception, late journal, source rollback và public setter autosave/units.
- Uptime busy/pending trước sysctl, thiếu identity không recreate, exception giữ cache và release trước log, reentrant Storage writer bị busy, mutable caller path không redirect, late journal và identity removal/replacement/symlink không stage/adopt cache.
- Uptime cache setter quan sát committed tuple khi lease đã nhả; legacy source-fault cache-preservation fixture vẫn giữ. Profile-root factory đóng descriptor trên success/failure/invalidate/dealloc.

Macro arity guard được mở rộng sang preparation fixture. Artifact writer fixture thêm PXProfileRootPath backend cho dependency mới; Network cases H3E và RootHide header support vẫn giữ. Preparation runner link đầy đủ scope/lease/journal/selection và giữ cả rootful/RootHide define matrices. Nó không kéo CarrierDB/PXJailbreakCompat vào, không cần RootHide namespace shim mới.

Windows đã pass 14 source/host gates liên quan, macro validation, exact native-fragment extraction và git diff check. Chưa chạy Foundation/Theos native trên máy này. Build/native H3F cần macOS CI; real RootHide SDK/path mapping và iOS process/device acceptance vẫn tách biệt.

## Performance và tiếp theo

Cold persistence thêm nonblocking flock, root/target stat, pending-state reads và một held directory FD. Expected overhead low–moderate, chưa benchmark; không thêm hook/hot-path cache lock, timer, persistent queue, polling hoặc network. Uptime không giữ source gate khi sysctl/preparation; Storage copy cũng nằm ngoài gate. Other lifecycle operations có thể trả busy trong khoảng preparation. Số held descriptors mỗi operation vẫn ba như H3E; profile-root mode thay directory được pin, không mở thêm identity FD.

Standalone IdentifierManager scalar/model/telephony/migration, WiFi/Battery, dashboard preview, metadata sidecars, preferences/security authority, total cache ordering, rootful snapshot readers và directory cleanup/durability vẫn partial/pending. Các mốc tiếp theo phải giải quyết chúng trước khi tuyên bố full source/directory consistency. Patch 5–8 chưa triển khai.
