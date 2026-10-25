# Patch 4C.1 — source manifest, journal và settings/scope transaction

Ngày: 2026-10-24. Người dùng xác nhận build Patch 4B pass. 4C được chia để core/recovery có native gate trước khi chuyển profile creation và artifact generators có async flows. **4C.1 không hoàn tất 4C hoặc toàn bộ Patch 4.**

## Manifest và finding

[runtime-source-writers.json](runtime-source-writers.json) liệt kê 19 source paths/fields, producer groups, status và boundary cần migrate. Không suy producer từ tên file: `ProfileManager.saveSettings:` ghi `WeaponX/settings.plist`, khác `<profile>/settings.plist` mà snapshot đang đọc; chưa tìm được in-repo producer cho file sau. AppDataBackupManager dùng selection để chọn backup root, không phải producer chỉ vì có reference tới path.

Đã xác minh `IdentifierManager.saveSettings` ghi canonical settings rồi global scope thành hai lần độc lập. Ghi lần hai lỗi không rollback lần đầu; daemon có thể capture giữa chúng. Đã xác minh `createProfile` đổi active selection trước `dispatch_async` tạo artifacts. Không bọc lexical lock quanh cả method rồi cho rằng block nền nằm trong transaction. Flow này được giữ ở nhóm pending để migrate boundary đúng trong 4C.2.

Security cần xử lý cả `NSUserDefaults`/`CFPreferences`, kể cả IP cache, metrics và indicator coordinates chia sẻ cùng physical plist. Lock quanh setter/synchronize không khiến cfprefsd tham gia lock. Không tuyên bố file security đã transactional khi còn những writer này.

## Core và lock order

- `PXRuntimeSourceStore` giữ một stable lock descriptor với O_CLOEXEC/O_NOFOLLOW, regular-file/owner/link-count/mode validation. NSRecursiveLock bảo vệ threads dùng cùng descriptor. Flock bảo vệ processes. Lock inode không bị unlink bởi engine.
- Cả thread gate và file gate chia sẻ một deadline contention monotonic 1s. Sleep 5ms chỉ trong bounded cold contention wait; không có timer/polling nền mới. Deadline này không hứa giới hạn tổng thời gian filesystem I/O.
- Production state nằm dưới `PXWeaponXBasePath()/RuntimeSource`, owner mobile 501, directory 0700, lock/journal/marker 0600. Root daemon được đọc/lock, không được gọi write/recovery do owner check. Root không replay một mobile-controlled journal để sửa arbitrary source paths.
- Allowlist gồm exact global paths và profile ID/file names đã validate; đối chiếu canonical path để không theo per-profile/file symlink escape. Không thêm generic filesystem hooks/swizzles.
- Order: publisher ownership -> source gate -> capture + deep immutable detach -> release source gate -> global write/mirrors/notify. Writers không acquire publisher ownership; notifications/callbacks/dispatch waits nằm ngoài source transaction block.

## Stage, commit và recovery

Writer block chỉ đọc/stage dictionaries, không sửa live files. Nested writes trên cùng store dùng cùng stage; inner failure taint outer kể cả caller bỏ qua kết quả. Transaction hết scope hoặc dùng sai thread bị từ chối. Reentrant capture và write trong capture bị từ chối, tránh lock upgrade/deadlock. Exception trả failure và nhả gate.

Outer success thực hiện:

1. Validate sources, capture before-images gồm exact bytes, mode và absence; từ chối malformed existing source thay vì tự reset thành dictionary rỗng.
2. Atomic `pending.plist` với transaction UUID và toàn bộ before-images.
3. Atomic replace từng source bằng staged dictionary.
4. Atomic `commit.plist` với UUID đó; đây là commit boundary.
5. Xóa journal. Dữ liệu/property list và count đều có giới hạn; staged/before-image payload tối đa 32 MiB, tối đa 256 file; journal reader cho metadata overhead tới 64 MiB. Existing source modes được giữ, file mới mặc định 0644.

Lỗi/exception trước marker: restore exact before-images; file trước đó absent được unlink đúng leaf, không recursive delete directory. Validate **toàn bộ** journal paths và dictionary before-images trước bất kỳ restore nào. Restore lỗi để journal lại; capture từ chối uncommitted state. Lần writer owner tiếp theo recover trước khi body chạy. Malformed journal/commit không bị xóa hoặc tự chấp nhận làm legacy.

Crash sau marker: journal có thể còn nhưng validated transactionID trùng commitID, nên capture được phép đọc completed state, không phải đợi journal cleanup mới publish scope disable. Reader không sửa/xóa journal. Writer sau đó chỉ cleanup, không rollback committed state. Native checkpoint fixture phân biệt đúng hai phía boundary này.

Chưa claim power-loss durability/fsync; contract hiện tại xử lý process crash/atomic rename và I/O failure. Trường hợp source rollback cũng lỗi hoặc journal hỏng cần recovery/repair, không tự ghép field hoặc bless partial files. Orphan `.tmp.*` do process chết ngay trong atomic write chưa có collector mới; engine chỉ cleanup temp của lượt lỗi bình thường qua atomic writer 4B.

## Production rollout 4C.1

`IdentifierManager.saveSettings` stage settings/scope trong một outer transaction, RMW settings diễn ra trong gate, giữ các top-level flags/StorageSystemEnabled và scope policy. `saveScopedApps` cũng tham gia source gate. Cache invalidation và settings notification vẫn sau success, ngoài lock. Failed transaction không phát notification thành công.

Manager `loadSettings`/`loadScopedApps` recover trước load; settings/scope load từ một capture. Điều này tránh khởi động lại rồi load uncommitted partial files vào RAM, sau đó ghi lại chúng như một commit mới. RootHide injected early return và rootful injected legacy reads giữ nguyên; không đưa recovery vào hot hooks. Recovery no-op không tạo commit mới.

Publisher loader đã qua source gate và immutable detach. Source identity (`sourceState`, `sourceCommitID`) độc lập publisher epoch/revision; daemon debug ghi cả hai cùng `sourceContractCoverage=settings-scope-only`. Marker là commit của **enrolled writers**, không phải bằng chứng profile/artifact/security writers còn pending đã tuân thủ. Marker/pending paths được thêm vào existing fingerprint fallback, không có timer mới.

Các gaps còn nguyên: profile switch/create/delete/initialization, identifier/artifact generators/migrations, battery/network/Wi-Fi/uptime/storage pairs, Dashboard preview group, direct security writes, defaults/cfprefsd authority và upgrade writers ngoài steady state. `StorageManager` còn NSUserDefaults writer vào chính canonical settings domain, nên coverage của cả physical settings file vẫn partial. Rootful live-source authority chưa rollout; không dùng source token để tuyên bố rootful read consistency.

Cost của cặp settings/scope tăng từ hai atomic file writes thành bốn (journal, hai sources, marker), thêm đọc before-images/control records và immutable detach. Relative cost low/moderate trên cold writer/publisher, không có I/O/lock mới trong hot capture hooks. Before-image dùng đúng buffer đã parse, không đọc source lần hai chỉ để journal. Main-thread callers vẫn có synchronous I/O và có thể chờ contention tối đa 1s; chưa đo latency trên thiết bị, không coi đây là performance optimization. Chuyển UI writer sang async queue cần boundary/callback review riêng.

## Verification và gate kế tiếp

Thêm `scripts/test_runtime_source_transactions.py --native`, link production source engine và adapters/paths/publisher/reader/scope, chạy ba fixture processes mới. Cases: staged abort, nested commit/taint, immutable capture, escaped/wrong-thread use, reentry/lock upgrade, exception cleanup, mid-group rollback exact bytes/mode, path allowlist validation trước recovery, corrupt state, crash tại journal/first file/last file/marker và trong rollback, absence rollback, hai writer processes increment không mất update, concurrent paired capture và lock timeout/process exit. Chỉ subprocess của fixture bị terminate trong test; không terminate app trên thiết bị.

Publisher fixture runner cũng link hai implementation sources mới để tránh lỗi missing transitive symbols. Native fixtures không thay bằng Python model. Windows không có Foundation/xcrun/Theos để chạy chúng; CI build/native fixture và RootHide permission/path/device tests vẫn cần xác nhận.

23 host source/regression gates pass, gồm source core/publisher/reader/consumer, RootHide build, bootstrap, P3/security UI/iOS12, Phase B/10, native OS safety, iFake parity, missing hooks, hardware/device/WebGL, domain/location và canvas controls. Backup audit PASS 2576/2576; ba Node canvas/web/WebGL suites pass; git diff --check pass. Đây không phải native runtime evidence. Không commit/push/deploy. Sau khi native core/build gate pass, triển khai 4C.2 theo manifest: chọn explicit target profile, prepare ngoài transaction, stage multi-file artifacts + selection dưới một boundary, chuyển notifications ra sau unlock; giải quyết defaults authority trước khi claim full source coverage.
