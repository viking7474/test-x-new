# Kế hoạch xử lý ownership, identity, dead hooks, fingerprint consistency và scope/JB gating

## Tóm tắt

Triển khai theo 5 workstream, ưu tiên loại bỏ hook trùng và sửa đường inject trước khi bật thêm hook đang dead. Các mặc định được khóa như sau:

- ATT và Low Power Mode được lưu theo profile.
- Refactor ownership áp dụng cho mọi native symbol đang bị nhiều module hook.
- Jailbreak hook chỉ được cài khi master toggle bật lúc process launch; tắt có hiệu lực ngay, bật lại yêu cầu relaunch.
- Release target chính là rootful MobileSubstrate, iOS 12+, arm64/arm64e; ATT chỉ kích hoạt khi API tồn tại.
- Không mở rộng sang DeviceCheck/App Attest, signed receipt, passkey hoặc biometry.

## 1. P0 — Native hook ownership và filter state

### Native hook coordinator

- Tạo `PXNativeHookCoordinator.h/.m` làm nơi duy nhất gọi `MSHookFunction` cho các symbol bị trùng.
- Coordinator giữ original pointer duy nhất bằng `dispatch_once`; provider không được tự cài hook.
- API đăng ký provider gồm hai pha:
  - `pre`: có thể trả kết quả hoàn chỉnh và ngăn gọi original.
  - `post`: nhận kết quả original để chỉnh buffer/struct.
- Registry phải thread-safe, dùng provider ID duy nhất, priority cố định và từ chối đăng ký trùng ID.
- Thứ tự xử lý:
  1. Scope và ABI validation.
  2. Identity/model/iOS/SystemBoot/BootTime.
  3. Network/storage transformations.
  4. Jailbreak sanitizer dạng post-processing.
  5. Original fallback.
- Hợp nhất ownership cho:
  - `sysctl`, `sysctlbyname`
  - `gethostname`, `getifaddrs`
  - `IORegistryEntryCreateCFProperty`, `...CreateCFProperties`, `...SearchCFProperty`
  - `CFCopySystemVersionDictionary`
  - `statfs/statfs64/getfsstat/getfsstat64`
  - `CNCopyCurrentNetworkInfo`
- Phân vai:
  - Core `Tweak`: model, hostname, serial, cellular identifiers và IOKit routing.
  - `IOSVersionHooks`: iOS/build/CF system dictionary provider.
  - `BootTimeHooks`: boot-time provider, không cài symbol.
  - `UUIDHooks`: chỉ `gethostuuid` và dyld UUID API riêng.
  - `StorageHooks`: statfs postprocessor.
  - Network module: owner logic `getifaddrs` và WiFi dictionary.
  - Jailbreak module: chỉ đăng ký sanitizer khi master/group tương ứng bật.
- Với `CNCopyCurrentNetworkInfo`, WiFi module dựng dictionary cuối; NetworkConnectionType chỉ cung cấp policy, không cài hook thứ hai.
- Với IOKit, coordinator gọi original đúng một lần rồi áp dụng lần lượt identity và storage transformations.
- Xóa `HookOwnership.h`, toàn bộ `gOwner*` và mọi `%hookf`/`MSHookFunction` trùng sau khi provider đã chuyển xong.
- Thêm script audit source, fail khi một native symbol xuất hiện ở nhiều điểm cài hook ngoài coordinator.

### Filter union và empty state

- Dùng `global_scope.plist/ScopedApps` làm nguồn chân lý; chỉ lấy entry `enabled=YES`.
- Khi thêm app, extension hoặc thay reset selection:
  1. Lưu scope.
  2. Đọc lại toàn bộ enabled main bundles.
  3. Expand chính xác app extensions.
  4. Thêm WebKit helper cluster nếu có ít nhất một app.
  5. Deduplicate và sort để output ổn định.
- Không truyền riêng `expandedBundles` của app vừa thêm vào writer.
- Khi không có app:
  - Ghi duy nhất `com.hydra.tlinkios.no-injection-placeholder` cho cả tweak và keychain bridge.
  - Không ghi `Bundles=[]`.
- Bridge filter loại Apple/WebKit bundles nhưng giữ toàn bộ app/extensions bên thứ ba.
- Daemon chấp nhận placeholder-only, từ chối placeholder trộn với bundle thật, cài atomically và ghi checksum/debug state.
- Sau ghi, đối chiếu normalized bundles giữa global scope, staging plist và installed plist; log `in_sync`, `staging_mismatch` hoặc `installed_mismatch`.

## 2. P0 — HardwareUUID, MEID, UDID và UUID semantics

### Canonical identity keys

- Canonical key là `SystemBootUUID`.
- Khi load profile:
  - Nếu thiếu `SystemBootUUID` nhưng có legacy `HardwareUUID`, migrate giá trị sang canonical key.
  - Chỉ đọc legacy alias trong một chiều; mọi lần ghi mới chỉ ghi `SystemBootUUID`.
- IOKit `IOPlatformUUID` và `system-id` dùng toggle/value `SystemBootUUID`.
- `gethostuuid` trả đúng 16 UUID bytes.
- `sysctlbyname("kern.uuid")` dùng NUL-terminated UUID string và hỗ trợ đúng two-call buffer sizing.
- Không dùng cùng serializer cho `gethostuuid` và `kern.uuid`.

### IMEI và MEID

- `InternationalMobileEquipmentIdentity` và `kIMEIKey` chỉ dùng `IMEI`.
- `MobileEquipmentIdentifier` và alias MEID IOKit/MG chỉ dùng `MEID`.
- Mỗi nhánh kiểm tra toggle riêng, validation riêng và fallback original nếu profile thiếu/không hợp lệ.
- Thêm test đảm bảo bật riêng MEID không làm thay đổi IMEI và ngược lại.

### UDID hoàn chỉnh

- Bổ sung public manager API:
  - `generateUDID`
  - `setCustomUDID:`
  - `isValidUDID:`
- Format canonical: 40 ký tự hexadecimal lowercase.
- Lưu `udid.plist` với trường `value`; đồng bộ `device_ids.plist["UDID"]`.
- Thêm `UDID` vào `availableIdentifiers`, regenerate flow, custom edit flow và advanced UI.
- Nếu profile cũ có toggle UDID bật nhưng thiếu giá trị, migration sinh đúng một UDID và tăng `GenerationCounter`.
- MG `UniqueDeviceID` trả string; `UniqueDeviceIDData` trả data tương ứng ABI gốc, không trả string cho cả hai.

### Gỡ blanket UUID hooks

- Xóa hook `CFUUIDCreate` và `+[NSUUID UUID]`.
- Không spoof `NSUUID.UUIDString`, `description` hoặc `initWithUUIDBytes:` bằng heuristic platform UUID.
- Giữ các query có semantics rõ: `gethostuuid`, `kern.uuid`, IOKit platform UUID và dyld cache UUID.
- Acceptance: 100 lần gọi `NSUUID.UUID` và `CFUUIDCreate` phải tạo 100 giá trị khác nhau khi SystemBootUUID bật.

### Profile migration

- Thêm `ProfileSchemaVersion=2` trong `device_ids.plist`.
- Migration v1→v2 thực hiện atomically, tối đa một lần:
  - `HardwareUUID` → `SystemBootUUID` nếu canonical thiếu.
  - Sinh UDID nếu toggle đã bật và giá trị thiếu.
  - Khởi tạo ATT và Low Power Mode theo quy tắc ở workstream 4.
- Chỉ tăng `GenerationCounter` một lần cho toàn bộ migration.

## 3. P1 — Kích hoạt an toàn UserDefaults, DeviceModel và Pasteboard

### UserDefaults

- Đưa toàn bộ `NSUserDefaults` hooks vào `%group UserDefaultsHooks`; constructor chỉ `%init(UserDefaultsHooks)` sau scope check.
- Đổi recursion guard thành `static __thread BOOL`.
- Chỉ thay giá trị khi:
  - Identifier `UserDefaultsUUID` bật.
  - Key khớp UUID allowlist/heuristic hiện có.
  - Giá trị gốc có type và UUID shape hợp lệ.
- Không thay arbitrary strings, numbers, settings/security suite hoặc TLinkIOS preferences.
- Read và write path phải trả cùng UUID profile; collection processing giữ nguyên type và immutable/mutable contract.
- Cache invalidated bởi settings/profile notifications.

### DeviceModel

- Tạo `%group DeviceModelFoundation`.
- Chỉ giữ `UIDevice.model` và `localizedModel`; bỏ duplicate `name`, MG, sysctl, uname và IOKit khỏi module này.
- Không trả machine identifier như `iPhone15,3` qua `UIDevice.model`.
- Mapping:
  - Prefix `iPhone` → `iPhone`
  - Prefix `iPad` → `iPad`
  - Prefix `iPod` → `iPod touch`
  - Unknown prefix → original
- `localizedModel` dùng cùng generic Apple product family; không tự tạo tên model chi tiết.
- Bỏ hook `NSDictionary` liên quan file có chữ “device/model”; nó không phải device-model query surface.
- Constructor kiểm tra scope, toggle và profile value rồi mới `%init(DeviceModelFoundation)`.

### Pasteboard

- Không chỉ thêm `%init` cho toàn file.
- Thay private/optional selectors bằng runtime installer:
  - Kiểm tra class tồn tại.
  - Kiểm tra instance/class method tồn tại.
  - Kiểm tra type encoding trước khi hook.
  - Không add selector mới nếu selector không tồn tại.
- Public path được phép hook: named pasteboard creation, `name`, `changeCount`, general/unique pasteboard accessors khi method tồn tại.
- `uniquePasteboardUUID` chỉ hook trên iOS/runtime có selector thực.
- Original IMP lưu riêng cho từng selector, không dùng chung pointer.
- Không hook `NSNotificationCenter` chỉ để logging.
- General pasteboard không bị đổi tên; chỉ custom/unique pasteboards dùng deterministic name từ `PasteboardUUID`.
- Khi selector private không tồn tại, module phải log `unsupported-selector` một lần và tiếp tục chạy bình thường.

## 4. P1 — Hostname, app version, ATT và Low Power Mode

### gethostname

- Coordinator cài `gethostname` trên MobileSubstrate và ElleKit-compatible runtime, không phụ thuộc `EKMethodsEqual`.
- Không gate bằng `jailbreakDetectionEnabled`.
- Khi scoped + `DeviceName` bật, trả đúng DeviceName profile.
- Nếu buffer null/size 0 hoặc profile value không hợp lệ, gọi original.
- Copy có giới hạn, luôn NUL-terminate khi buffer cho phép và giữ errno/return contract của original.
- `UIDevice.name`, `NSHost` và `kern.hostname` phải trả cùng giá trị trong một profile.

### App Version full dictionary

- Giữ `objectForInfoDictionaryKey:` và `CFBundleGetValueForInfoDictionaryKey`.
- Bổ sung:
  - `-[NSBundle infoDictionary]`
  - `-[NSBundle localizedInfoDictionary]`
  - `CFBundleGetInfoDictionary`
  - `CFBundleGetLocalInfoDictionary`
- Chỉ sửa main bundle và chỉ khi app-version spoof active.
- Trả immutable copy; không mutate dictionary hệ thống tại chỗ.
- CF full-dictionary hooks dùng retained cache ổn định theo bundle ID/profile generation; release khi invalidation/process teardown.
- Đồng bộ `CFBundleShortVersionString` và `CFBundleVersion` trên mọi access path.
- Invalidate cache khi profile, settings hoặc app-version mapping thay đổi.

### ATT consistency theo profile

- Thêm `tracking_info.plist` và `device_ids["ATTAuthorizationStatus"]`.
- Giá trị là enum số `0...3`: notDetermined, restricted, denied, authorized.
- ATT spoof active khi identifier `IDFA` bật; không thêm master toggle thứ hai.
- Migration mặc định:
  - IDFA bật và profile IDFA non-zero → authorized.
  - IDFA không bật → notDetermined, nhưng runtime pass-through vì ATT spoof inactive.
- Thêm status picker trong IDFA card.
- Runtime:
  - `ATTrackingManager.trackingAuthorizationStatus` trả status profile.
  - `requestTrackingAuthorizationWithCompletionHandler:` khi spoof active không gọi system prompt; callback async trên main queue với status profile.
  - Legacy `ASIdentifierManager.isAdvertisingTrackingEnabled` trả `YES` chỉ khi status authorized.
  - `advertisingIdentifier` trả profile IDFA khi authorized; trả zero UUID khi restricted/denied/notDetermined.
- Chỉ cài ATT selectors nếu class/method tồn tại; iOS cũ tiếp tục dùng legacy path.

### Low Power Mode theo profile

- Mở rộng `BatteryManager`:
  - `lowPowerModeEnabled`
  - `setLowPowerModeEnabled:`
- Lưu Boolean `LowPowerMode` trong `battery_info.plist` và `device_ids.plist`; default migration là `NO`.
- `generateBatteryInfo` giữ LPM hiện tại, không randomize.
- Thêm switch Low Power Mode trong Battery card.
- Hook `-[NSProcessInfo isLowPowerModeEnabled]` khi Battery identifier bật.
- Khi profile/settings đổi và LPM quan sát được thay đổi, post `NSProcessInfoPowerStateDidChangeNotification` trên main queue.
- Battery level/state và LPM dùng cùng profile snapshot, không đọc file độc lập trên mỗi hot-path call.

## 5. P1 — PXScope thread safety và Jailbreak groups

### PXScope immutable snapshot

- Thay các mutable global cache bằng immutable `PXScopeSnapshot` chứa:
  - Device/Safari/display toggles.
  - Enabled scoped-app map.
  - Scope generation và expiration time.
- Dùng `os_unfair_lock`:
  - Lock ngắn để lấy/publish snapshot.
  - Không giữ lock khi đọc plist, log hoặc gọi Objective-C code có thể re-enter scope.
- Dùng refresh lock riêng để chỉ một thread reload disk; thread khác tiếp tục dùng snapshot hợp lệ gần nhất.
- Darwin notification:
  - Atomically invalidate snapshot.
  - Tăng generation.
  - Không mutate dictionary đang được reader sử dụng.
- Bảo vệ `gDecisionLogTimes` bằng lock riêng hoặc chỉ tạo trong debug mode.
- WebKit host bundle cache dùng immutable process-lifetime value; host không tìm thấy phải fail closed.
- Scope hot path không ghi file/NSLog khi debug flags tắt.

### Jailbreak hook groups

- Chia thành:
  - `JBSafeFoundation`: Foundation/UIKit checks và file/process query wrappers.
  - `JBAppSpecific`: các class detector cụ thể.
  - `JBAggressiveRuntime`: dyld, dlsym/dlopen, task info, sandbox, syscall và experimental hooks.
- Constructor:
  1. Kiểm tra critical process.
  2. Kiểm tra scope.
  3. Đọc `jailbreakDetectionEnabled`.
  4. Nếu master tắt: không init Logos groups và không register native JB providers.
  5. Nếu bật: init safe + app-specific; aggressive chỉ init/register theo toggle riêng.
- Mọi hook body, kể cả các method đang trả `NO` trực tiếp, phải gọi common gate:
  - Gate false → `%orig`/original function.
  - Gate true → spoof/sanitize.
- Tắt master trong khi app chạy làm mọi installed handler pass-through sau cache TTL/notification.
- Bật master từ OFF không cố cài hook động; UI hiển thị “cần relaunch app”.
- Các experimental toggle cũng chỉ cài khi launch; tắt runtime vẫn pass-through.
- JB sysctl/statfs/getifaddrs logic trở thành provider của coordinator, không tự gọi `MSHookFunction`.

## Public interface và schema thay đổi

- `PXNativeHookCoordinator`: provider registration, deterministic pre/post routing và diagnostics.
- `IdentifierManager`: thêm generate/validate/set UDID và getter/setter ATT status.
- `BatteryManager`: thêm getter/setter Low Power Mode.
- Profile schema v2 thêm:
  - `UDID`
  - `ATTAuthorizationStatus`
  - `LowPowerMode`
  - `ProfileSchemaVersion`
- `HardwareUUID` trở thành read-only legacy alias; không ghi mới.
- Hook diagnostics phải xuất: symbol, owner/coordinator, original pointer present, registered providers, install count và active scope.

## Test plan và acceptance criteria

### Static/build checks

- Build sạch iOS 12 deployment target cho arm64 và arm64e.
- Audit không còn custom `%ctor` + Logos hook thiếu `%init` ở các module được sửa.
- Audit không còn native symbol trùng điểm cài ngoài coordinator.
- Không còn tham chiếu runtime đến `HardwareUUID`, generic `CFUUIDCreate` replacement hoặc `+[NSUUID UUID]` replacement.

### Runtime matrix

- Scope OFF: mọi API trả original; JB/ATT/LPM/UserDefaults/Pasteboard không thay đổi hành vi.
- Scope ON, feature OFF: pass-through.
- Scope ON, feature ON: tất cả API cùng domain trả cùng profile value.
- Chuyển profile: process được relaunch theo flow hiện tại; cache generation và values cập nhật đúng.
- WebKit helper chỉ được phép khi host app scoped.

### Identity tests

- SystemBootUUID nhất quán giữa IOKit, `gethostuuid` và `kern.uuid`.
- IMEI/MEID không dùng nhầm toggle/value.
- UDID đúng 40 hex, ổn định trong profile và đổi giữa profile.
- Generic UUID generation vẫn unique.
- Device model Foundation trả generic family; low-level APIs trả machine identifier.

### Filter tests

- Thêm A rồi B: filter chứa A+B+extensions+WebKit helpers.
- Xóa A: B vẫn còn.
- Xóa tất cả: installed filter chỉ còn placeholder.
- Bridge không chứa Apple/WebKit bundles.
- Daemon restart vẫn đồng bộ staging → installed chính xác.

### Consistency tests

- DeviceName giống nhau qua UIDevice/NSHost/kern.hostname/gethostname.
- App version giống nhau qua mọi NSBundle/CFBundle access path.
- ATT status, completion callback, legacy tracking flag và IDFA zero/non-zero khớp nhau.
- LPM getter và notification khớp profile.
- UserDefaults không sửa non-UUID keys.
- Pasteboard không crash trên runtime thiếu private selector.

### Concurrency/JB tests

- Chạy nhiều thread gọi scope/network/location hooks đồng thời trong lúc post profile/settings notifications; không crash, race hoặc mutable-collection exception.
- JB master OFF từ launch: không cài group/provider.
- JB master ON: safe/app-specific hoạt động; aggressive chỉ theo toggle.
- Tắt master runtime: tất cả handler pass-through.
- Bật master sau launch: UI yêu cầu relaunch và không tạo trạng thái half-installed.
