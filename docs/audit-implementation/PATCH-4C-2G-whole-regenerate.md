# Patch 4C.2G — whole-regenerate source transaction

Người dùng xác nhận build 4C.2F pass. Lượt này chuyển `regenerateAllEnabledIdentifiers` sang prepare → compare → commit → publish cho một target. Build/native runtime của 4C.2G vẫn chờ macOS CI; không coi Patch 4 hoàn tất.

## Boundary và correctness

`regenerateAllEnabledIdentifiersWithError:` trả kết quả **source commit**. API void cũ gọi lại API này và log lỗi, giữ tương thích với callers hiện tại. Capture identity directory một lần; detach flags và scoped-app intent trước provider callbacks. Dirty in-memory flags/scope vẫn được flush như `saveSettings` ở cuối flow cũ. Không tự đổi authority sang persisted-only options.

Một read-only source operation capture IDs, settings/scope và các artifact dependencies cần dùng. Security basis chỉ đọc khi cần chọn model; storage/battery chỉ đọc khi enabled. DB/model/scalar/Serial/storage/battery/Wi-Fi/uptime preparation chạy ngoài source gate. Model storage tiers dùng lại packet đã detach, tránh hỏi DB lần nữa cho model vừa chọn. Prepared payload được deep-detach bằng property-list serialization trước staging.

`PXStageRuntimeGeneration` kiểm tra tất cả field dependencies và battery source presence trước khi stage. Model/cellular group, enabled scalar sidecars + IDs, theme, Wi-Fi, boot/uptime, battery, storage và settings/scope cùng một journal/commit marker. Giữ latest generation counter và merge field không liên quan; thay đổi dependency trong lúc prepare làm operation fail với yêu cầu retry. Không tự retry entropy/model generation hoặc overwrite competitor.

Counter chỉ tăng một lần khi có model group hoặc cellular refresh, giữ policy của các writer trước đó. Counter exhausted, malformed beforeimage hoặc source-write failure không publish candidate caches/notifications. Journal core phục hồi bytes/modes/absence như các patch trước. Đây không phải filesystem transaction atomic đối với reader không tham gia source gate, cũng không có fsync/power-loss durability claim mới.

Schema migration và directory creation có thể xảy ra trong `profileIdentityPath` **trước** batch boundary. API này phải được gọi ngoài source transaction; provider callbacks/notifications không được đặt trong một outer lexical source lock. Existing call sites không bọc regenerate trong source transaction. Không mở rộng contract sang profile create/switch/delete ở lượt này.

## Successful-value policy và thay đổi có chủ đích

- Wi-Fi vẫn regenerate ngay cả khi WiFi toggle off, theo entry point cũ; bỏ lượt generate thứ hai khi toggle on.
- DeviceModel hoặc IOSVersion enabled chọn coherent canonical group. Thiếu baseline vẫn seed group; IMEI/MEID-only refresh tuple hiện có, fallback full group nếu thiếu regulatory/build. Không dùng generic telephony generator.
- Các scalar/UUID giữ factory và Serial policy adapter từ 4C.2F. Serial prefix reservation/delay không phải rollbackable source state.
- Theme tạo một lần nếu enabled hoặc chưa có giá trị string/number trong IDs; không gọi saving setter lặp lại.
- BootTime/SystemUptime enabled cùng chuẩn bị một consistent pair, thay vì generate pair hai lần khi bật cả hai.
- Storage giữ model tiers, tránh previous capacity và thuật toán free-space; previous lấy từ target đã capture, tránh cache của profile khác. Capacity selector kiểm tra kiểu previous trước khi dùng length.
- Battery giữ LowPowerMode của target: identity → legacy profile root → legacy global fallback. Không lấy nhầm LPM từ singleton của profile trước. Đây là correction cho stale cross-profile state, không randomize LPM.
- Nếu một nhóm prepare/commit fail, batch dừng và trả lỗi; không tiếp tục lưu các nhóm độc lập như flow cũ. Mục tiêu là không tạo partial generation.

## Cache và notifications

WiFi/Battery/Storage/Uptime có cache-only adoption API, không auto-save, không lookup target, không notify. Sau source commit, IdentifierManager invalidates lookup caches rồi publish model/scalar/artifact caches. Nếu target không còn active, bỏ global compatibility cache adoption; không chọn profile mới để ghi candidate.

Battery legacy mirror và local/Darwin notifications chạy sau adoption/commit, một lần. Mirror failure là diagnostic hậu commit, không báo giả rollback. Callback exception được log; source success vẫn là success và settings-changed notification vẫn được gửi. Fixture dùng backend mirror path tạm và notification spy, không phát production IPC.

Guard active profile chỉ tránh knowingly publishing inactive target. Nó **không** linearize profile switch với cache adoption; singleton initialization có thể thực hiện legacy reads/lifecycle work. Ordering giữa concurrent cache publishers, mutable manager settings/error/cache thread safety, cfprefsd/defaults authority và global battery fallback authority vẫn cần patch riêng. Không claim full profile consistency từ token này.

## Performance

Không thêm hook, timer, polling hoặc dispatch queue. Bỏ duplicate generation và các storage auto-saves; source I/O được gom thành một batch commit thay vì nhiều journal/commit cycles. Expected impact moderate trên cold regenerate, chưa benchmark latency/CPU trên thiết bị. Journal beforeimages vẫn phải đọc/ghi từng artifact; property-list detach và staged IDs serialization vẫn có allocation cost. Không claim speedup theo phần trăm hoặc đã loại hết main-thread I/O.

## Kiểm chứng

- Source gate mới `scripts/test_runtime_generation.py`, có trong CI và release-hardening extended suite. Source gate không chứng minh native execution.
- Native group fixture extract exact production orchestration/cellular builder, link production preparation/staging/journal core; provider/cache/selection backends là fixture. Chạy rootful + RootHide, mỗi variant ba lượt trên macOS CI.
- Cases: one target/one commit; scalar-sidecar pairing; artifact/settings/scope/counter pairing; fault injection nhiều vị trí; preparation failure; dependency/presence drift; detached options; disjoint update/latest counter merge; target switch; post-commit exception; exhausted counter; malformed beforeimage; disabled options; cellular-only và missing baseline.
- Artifact fixture extract exact production adoption methods và battery publisher; kiểm tra không auto-save/reselect profile, mirror path tạm, notify ordering và storage tier selection.
- Host: **33/33 source gates**, **3/3 Node regressions**, backup/restore audit **2636/2636**, exact production fragment extraction (group + artifact) pass và `git diff --check` pass. Windows không có xcrun/Foundation/Theos; không báo native hoặc package build pass tại đây.

## Tiếp theo

ProfileManager create/switch completion cần dùng error-returning generation result và một explicit-target lifecycle plan. Không trả success/dispatch completion chỉ vì đã gọi API void, không giữ source lock qua dispatch/completion. Dashboard preview và security/defaults writers vẫn pending trong manifest; rootful live readers vẫn cần rollout riêng.
