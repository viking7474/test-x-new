# Patch 4C.2E — artifact preparation không auto-save

Người dùng xác nhận build 4C.2D pass. Lượt này bổ sung bước chuẩn bị Wi-Fi/battery/uptime/storage không ghi source hoặc sửa manager cache, dùng lại ngay trong các API standalone hiện tại. Đây là prerequisite cho whole-regenerate transaction; chưa enroll create/switch/profile lifecycle hoặc thay completion/publication ordering.

## Vì sao cần tách prepare trước orchestration

regenerateAllEnabledIdentifiers và createProfile gọi nhiều manager auto-save ngay khi tạo giá trị. Bọc nguyên workflow trong source lock sẽ giữ khóa qua random generation, manager initialization, callbacks/notifications và thậm chí queue hops. Khóa publisher hoặc trì hoãn completion cũng không tự làm các file nguồn thành một transaction.

`PXRuntimeArtifactPreparation.h/.m` cung cấp C APIs thuần Foundation cho cold preparation. Có RNG và clock sample cho Wi-Fi, nên đây là effect-free preparation đối với source/cache/IPC, không phải referentially transparent computation. Không lookup profile, tạo manager/singleton, đọc preferences, sysctl, tạo directory, ghi file hoặc phát notification trong factory. Returned records immutable và không chia sẻ mutable cache của manager.

| Factory | Caller production hiện dùng | Contract |
| --- | --- | --- |
| PXPrepareRuntimeWiFiInfo | WiFiManager.generateWiFiInfo | Giữ các bảng tên/OUI, branch selection, BSSID/network fields; wrapper vẫn update mutable cache rồi save như trước |
| PXPrepareRuntimeBatteryLevel / Info | BatteryManager.randomizeBatteryLevel / generateBatteryInfo | Giữ weighted distribution, level string, percentage và LPM được truyền vào; wrapper giữ side effects standalone |
| PXPrepareRuntimeStorage | StorageManager.generateStorageForCapacity | Giữ percentage/decimal variation/rounding cho capacity hợp lệ; gọi factory không cần init manager có profile/defaults I/O |
| PXPrepareRuntimeUptime | UptimeManager.generateConsistentUptimeAndBootTimeForProfile | Wrapper probe real boot ngoài gate; factory nhận clock/probe result, trả pair có một mốc now; persist rồi update cache như 4C.2A |

## Các sửa correctness/performance cụ thể

1. **Medium — Wi-Fi lastConnectionTime:** `-1 * arc4random_uniform(86400)` thực hiện unsigned arithmetic trước khi chuyển sang NSTimeInterval. Offset khác 0 có thể wrap thành thời điểm hàng tỷ giây trong tương lai. Cast sang NSTimeInterval trước unary minus; fixture dùng random endpoint 86399 để bắt đường lỗi này.
2. **Medium — Battery duplicate persistence:** generateBatteryInfo trước đây gọi randomizeBatteryLevel (có save), rồi save lần nữa. Nay prepare một record, update cache và gọi save một lần, sau đó vẫn có một local và một Darwin notification với payload cũ. Code giảm số lần gọi persistence từ 2 xuống 1 cho mỗi batch. Khi có target profile hợp lệ, bỏ một global battery write và một profile source transaction; không gọi đây là benchmark latency hay throughput.
3. **Medium — Storage invalid input:** nil capacity trước đây đi tới dictionary assignment không hợp lệ; zero/nonfinite/extreme input có thể tạo dữ liệu không dùng được hoặc vượt miền chuyển sang uint64 marketing bytes. Factory trả nil cho input không có positive finite capacity trong miền biểu diễn hoặc computed free space không hợp lý. Callers hiện đọc NSDictionary và kiểm tra/gán các field; không tìm thấy caller production mutate returned dictionary. Capacity spelling của input hợp lệ vẫn được giữ.
4. Uptime pair dùng cùng clock sample cho boot và lastUpdated. Giữ cả minimum 12h cũ sau real-uptime cap, kể cả khi real uptime thấp hơn; không âm thầm thay generation policy trong patch này.

Behavior còn lại của standalone wrappers được giữ: Wi-Fi/battery vẫn có cache mutation/persistence; Battery legacy global mirror và failure/notification semantics chưa được đổi authority. Source transaction và Uptime cache-after-commit giữ nguyên. Không khẳng định toàn bộ manager state đã thread-safe hoặc Battery notifications đã trở thành transaction acknowledgement.

## Performance và lifecycle

Không thêm hot hook, timer, polling hoặc queue. Prepare có thể gọi trước khi lấy source gate; provider initialization/I/O không bắt buộc cho việc tạo record nữa. Wi-Fi wrapper cần một mutable cache copy ngoài immutable prepared result, chi phí thấp ở cold path. Các bảng Wi-Fi và RNG policy giữ cách tạo như trước; chưa cache/optimize chúng khi chưa có profiling. Journal vẫn có chi phí I/O; chỉ claim loại bỏ một lần Battery save đã chứng minh bằng call graph và fixture count.

Prepared storage copy input mutable; Wi-Fi prepared record tách khỏi mutable manager cache. Uptime caller cung cấp now và real probe; factory không giữ callback, timer hoặc transaction object. Lock/commit contract của các staging helpers không thay đổi.

## Kiểm chứng

`test_runtime_artifact_preparation.py --native` compile production factory cùng real stage/source engine/validator và exact method bodies của bốn manager qua generated includes. Fixture backend thay path/store selection, RNG và log/notification delivery; không init UIKit managers hoặc phát production Darwin IPC.

RNG tape/endpoint injection điều khiển trực tiếp các lời gọi random của production factory, không implement lại generation bằng Python. Cases: Wi-Fi date quá khứ/schema/MAC; Battery bucket endpoints và preserved LPM; storage rounding, nil/nonfinite/extreme/unphysical input, mutable input; Uptime real cap/minimum/schema/clock consistency; preparation không ghi source/notify; standalone cache/save counts; Battery một save trước một local và một Darwin callback; composition tất cả prepared artifacts trong một transaction; fault sau hai source writes của candidate khác rollback cả tuple; Uptime cache không đổi khi commit fail.

CI chạy ba process mới cho cả rootful và RootHide defines. Header được thêm vào strict native nullability compile check. Common wildcard của manager app và tweak mang factory mới vào build; daemon không có consumer mới. Host source checks không thay compile Foundation/Theos/UIKit hoặc device runtime.

Kết quả host: **31/31** source/regression gates, **3/3** Node suites, backup audit **2616/2616**, generated fragments và git diff --check pass. Native fixture/build mới chờ macOS CI vì Windows không có xcrun/Foundation/Theos.

## Coverage và phần tiếp theo

Manifest ghi preparation `available-not-batch-enrolled`. Publication sourceContractCoverage giữ nguyên coverage partial từ 4C.2D: không có source writer mới được tuyên bố enroll chỉ vì đã tách factory.

Tiếp theo cần prepared model/cellular packet và scalar values với captured target/options; compose các stage functions thành một outer commit; deferred cache/notifications sau commit. Khi có boundary đó mới chuyển createProfile từ selection-before-generation sang prepared state và completion sau generation/commit. Directory lifecycle/recovery, switch/delete, shared defaults authority và rootful reader rollout vẫn pending. Không thay behavior create/switch/completion nửa chừng trong lượt này.

Không commit, push, deploy hoặc terminate ứng dụng trên thiết bị.
