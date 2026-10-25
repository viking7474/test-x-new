# Patch 4C.2D — standalone IMEI/MEID validation và persistence

Người dùng xác nhận build 4C.2C pass. Lượt này enroll bốn API public `setCustomIMEI:`, `setCustomMEID:`, `generateIMEI`, `generateMEID`. Whole-regenerate/profile lifecycle và defaults authority vẫn pending; source coverage tiếp tục **partial**.

## Lỗi source và boundary mới

Trước patch, setter lấy profile để validate TAC/CDMA, rồi gọi saveCustomValue chọn profile lần nữa để ghi. Generator còn gọi setter để resolve/validate lại. Nếu active selection hoặc model tuple đổi giữa các bước, giá trị được chuẩn bị cho A có thể ghi sang B hoặc ghi trên tuple đã đổi. Các lookup lặp được xác nhận trong source; chưa có bằng chứng reproducer trên thiết bị.

Flow mới dùng chung implementation với type cụ thể cho từng call:

1. Copy input nhập tay và validate format trước target lookup. Input giữ nguyên case đã được chấp nhận, kể cả MEID lowercase.
2. Chọn identity directory một lần; capture IDs bằng cold source operation đã có từ 4C.2C.
3. Resolve một regional spec và generate/validate ngoài source gate. Manual format đã validate trên bản copy không bị validate lặp lại; giá trị mới generate vẫn qua validator production.
4. Dùng captured dependency values của model/A-number/build/cellular fields để compare ở commit. Conflict trả lỗi, giữ nguyên tuple của writer vừa commit; unrelated fields như SSID được merge từ current IDs.
5. Stage đúng identifier key và sidecar tương ứng, tăng GenerationCounter một lần trong cùng transaction. Identifier còn lại và sidecar của nó giữ nguyên. Không reselect profile qua setter/generic writer.

`PXStageRuntimeIdentifierValueWithDependencies` thuần staging; không DB lookup, generation, notification hoặc queue hop. Helper reuse replacement contract và journal từ 4C.2C. Counter exhaustion, malformed sidecar hoặc lỗi ghi trước commit trả failure và không publish partial pair.

## Policy và failure behavior

- Giữ validators/checksum hiện tại; iPhone manual writes yêu cầu exact regional slot và allowed TAC/MEID prefix. MEID yêu cầu enabled CDMA; IMEI không phụ thuộc CDMA.
- Generation vẫn cần model + regulatory slot và authoritative prefixes, không có generic fallback. Unknown/disabled capability hoặc thiếu prefix không tạo dữ liệu mới.
- Manual non-iPhone compatibility vẫn được giữ như trước; không tự siết thành iPhone-only hoặc tự normalize dữ liệu nhập.
- Thành công vẫn ghi `{value,lastUpdated}` sidecar, canonical ID key và counter tăng một lần. Operation có schema migration trước đó vẫn có migration counter policy riêng từ 4C.2B.
- Clear lastError khi bắt đầu và set NSError cụ thể khi validation/policy/persistence fail; trước đây một số early returns giữ stale/nil error. Dependency conflict là failure path có chủ đích để tránh ghi đè trên validation basis đã đổi.

Policy boundary của patch là bốn public APIs. Generic internal registry/staging giữ compatibility từ 4C.2B; các public telephony APIs hiện dùng flow validated riêng. Không tuyên bố mọi lời gọi Objective-C private selector đều là policy API.

## Concurrency, lifecycle và performance

Input copy giữ giá trị ổn định khi callback trong quá trình prepare làm thay đổi mutable input; không thay contract thread-safety của object do caller đang mutate đồng thời. Captured source dictionary được giữ strong sau khi transaction đọc kết thúc; transaction object không escape. Source commit chứa compare/merge/journal I/O; provider calls nằm ngoài gate.

Một canonical call hiện resolve target một lần và regional spec một lần. Native fixture đếm các lượt lookup để bảo vệ contract; đây không phải benchmark latency. Relative cost của compare/input copy thấp; journal và source capture là I/O cold path với chi phí moderate. Không thêm timer, polling, notification hoặc work vào hot hooks. Singleton error/settings và DB catalog reload không có total ordering mới; dependency compare kiểm tra source values, không pin toàn bộ database generation.

## Kiểm chứng

`test_runtime_device_group_writers.py` được mở rộng để trích đúng production flow, bốn wrappers và validators vào Foundation fixture có sẵn. Chạy cùng real staging/source engine, identity/schema helpers, VersionCompare và Security random API; chỉ DB/path/config providers và log sink là fixture backend. CI chạy native program ba process mới cho mỗi bộ rootful/RootHide defines. `test_runtime_telephony_writers.py` thêm source gate riêng và có `--native` để gọi cùng fixture, không tạo Python model thay production logic.

Cases bổ sung: cả bốn APIs giữ target khi selection đổi; một regional lookup; unrelated merge/counter một lần; hai identifier/sidecar độc lập; dependency drift ở A-number/model/build/identity, kể cả absent field vừa xuất hiện; fault sau write đầu tiên rollback pair/commit identity; input mutation callback; lowercase MEID; invalid formats; unknown/disabled/non-CDMA; wrong/missing prefixes; missing regulatory slot; manual non-iPhone compatibility; counter exhaustion; malformed sidecar không bị thay âm thầm.

Host verification: **30/30** source/regression gates, **3/3** Node suites, backup audit **2604/2604**, production fragment generation và git diff --check pass. Native fixture và full Theos/UIKit build mới chờ macOS CI; Windows không có Foundation/xcrun. Các defines trong fixture không thay real process/package/device matrix.

## Regenerate/profile workflow tiếp theo

Đã đọc các create/switch/generation call sites. `ProfileManager.createProfile` hiện ghi active selection rồi dispatch generation, nhưng save/completion không chờ generation. Callback background có WiFiManager/IdentifierManager chọn active profile, cùng raw carrier/IPv4 writes và một NetworkManager path chọn lại target. `regenerateAllEnabledIdentifiers` cũng gọi nhiều manager có auto-save/callbacks và nhiều lần chọn profile. Các đường này vẫn pending trong manifest, chưa được source token bao phủ đầy đủ.

Boundary tiếp theo cần prepared generation có explicit profile target và captured options; pure stage toàn bộ artifacts trước commit; active selection/publication chỉ phản ánh state đã chuẩn bị; UI/cache/notifications/completion sau outer commit. Directory create/delete và recovery cần boundary riêng. Không bọc nguyên async workflow hoặc manager auto-save/callbacks trong lexical source lock.

Không commit, push, deploy hoặc terminate ứng dụng trên thiết bị trong lượt này.
