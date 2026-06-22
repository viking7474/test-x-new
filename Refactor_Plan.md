# Kế hoạch Tái cấu trúc Toàn diện Hệ thống Đọc Cấu hình (ProjectXTweak)

## 1. Vấn đề Hiện tại (Thắt cổ chai I/O & Mất đồng bộ)
Qua rà soát mã nguồn, có tới **hơn 40 vị trí** trong 13 file `.x` (hooks) tự động mở và đọc trực tiếp các file `.plist` cấu hình giả lập (spoofing) từ đĩa.
- **Ví dụ các file bị ảnh hưởng:** `UUIDHooks.x`, `WiFiHook.x`, `NetworkConnectionTypeHooks.x`, `IOSVersionHooks.x`, `ThemeHooks.x`, `PasteboardHooks.x`, `StorageHooks.x`, `UserDefaultsHooks.x`, `MissingSpoofHooks.x`.
- **Hệ quả:**
  1. **Hiệu suất kém:** Gọi API `[NSDictionary dictionaryWithContentsOfFile:]` hàng ngàn lần mỗi giây trên các hàm hệ thống nóng (hot paths) gây hao pin và lag app.
  2. **Rò rỉ dữ liệu gốc (Leak):** Nếu file `.plist` đang được ứng dụng chính (`WeaponX`) ghi/chỉnh sửa, các hooks đọc lên có thể bị rỗng (`nil`), làm trả về giá trị thật của máy.
  3. **Mã nguồn phân mảnh:** Logic tìm đường dẫn `ProfileId`, đọc `.plist` bị lặp lại ở mọi file.

## 2. Giải pháp: Mở rộng `PXConfigProvider` làm Bộ nhớ đệm Trung tâm (Centralized In-Memory Cache)
Kế thừa kiến trúc của `PXConfigProvider` đã được giới thiệu, chúng ta sẽ mở rộng nó để quản lý toàn bộ các thuộc tính của thiết bị ảo.

### 2.1. Cập nhật `PXConfigProvider.h` và `PXConfigProvider.m`
- Nạp trước (Pre-load) toàn bộ các file cấu hình vào bộ nhớ RAM khi khởi tạo:
  - `device_ids.plist` (DeviceModel, SerialNumber, UUIDs, v.v.)
  - `wifi_info.plist` (BSSID, SSID)
  - `carrier_details.plist` / `network.plist` (Mạng viễn thông)
  - `settings.plist` (Các cờ bật/tắt tính năng theo profile)
  - `advertising_id.plist`, `vendor_id.plist`, v.v.
- Sử dụng cơ chế **Immutable Snapshot + Atomic Swap** thay vì dùng `NSLock` bao toàn bộ getter để tránh lock contention. Khi reload, đọc plist vào object tạm, copy thành immutable snapshot, rồi swap con trỏ để các hook đọc thẳng từ RAM không cần lock.
- Xử lý đồng bộ (Sync) tức thời thông qua `Darwin Notification Center`: Khi ứng dụng WeaponX đổi profile hoặc save cấu hình, nó sẽ post notification để `PXConfigProvider` reload dữ liệu vào RAM, đảm bảo các hooks lập tức sử dụng data mới mà không cần khởi động lại.

### 2.2. Xây dựng Interface Truy cập Siêu nhẹ (C-API: `PXConfigProviderC.h`)
- Cung cấp các hàm C tĩnh, nhanh, không qua Message Dispatch của Objective-C (nếu cần), hoặc bọc Obj-C trong hàm C cho dễ gọi từ `.x`:
  - `BOOL PXIsSpoofingEnabledForApp(NSString *bundleID)`
  - `NSString* PXGetSpoofedWiFiBSSID(void)`
  - `NSString* PXGetSpoofedUUID(NSString* uuidType)`
  - `NSDictionary* PXGetNetworkConfig(void)`
  - v.v.

### 2.3. Dọn dẹp Code Cũ tại các File `.x`
- Duyệt qua từng file: `UUIDHooks.x`, `WiFiHook.x`, `NetworkConnectionTypeHooks.x`, `IOSVersionHooks.x`, `ThemeHooks.x`, `PasteboardHooks.x`, `StorageHooks.x`, `UserDefaultsHooks.x`, `DomainBlockingHooks.x`.
- Xóa bỏ hoàn toàn các dòng `[NSDictionary dictionaryWithContentsOfFile:...]`.
- Gọi hàm từ `PXConfigProvider` thay thế.
- Tận dụng biến toàn cục cache ngắn hạn trong mỗi file `.x` nếu cần, nhưng phụ thuộc chính vào `PXConfigProvider`.


### 2.4. Chính sách Fail-Closed (Bắt buộc)
- Tuyệt đối không fallback về dữ liệu thật của máy nếu không đọc được config.
- Cung cấp dữ liệu fallback an toàn (Safe Default Fake Value) tại PXConfigProvider:
  - UUID thiếu → trả UUID fake ổn định.
  - BSSID thiếu → trả BSSID fake mặc định.
  - Model thiếu → trả model mặc định.

### 2.5. Cập nhật phía ứng dụng (WeaponX App)
- Đảm bảo cơ chế Atomic Write: Ghi cấu hình vào file tạm (temp file), sau đó rename đè lên file chính thức.
- Chỉ gọi Post Darwin Notification khi toàn bộ các file (settings, device_ids, wifi_info...) đã ghi và đóng hoàn tất.

## 3. Lợi ích Đạt được
1. **Zero I/O trong hot path của hook:** Dữ liệu được đọc hoàn toàn từ RAM thay vì ổ cứng mỗi lần hệ thống bị hook.
2. **Nhanh chóng & Đồng nhất:** Các process đang chạy sẽ reload gần như ngay khi nhận Darwin notification. Các process chưa chạy sẽ load config mới khi được inject.
3. **Mã nguồn sạch (Clean Code):** Gỡ bỏ hàng trăm dòng code xử lý file/path bị lặp lại, tập trung vào `PXConfigProvider.m`.

## 4. Roadmap Thực thi Tái cấu trúc
**Phase 0: Audit và đo lường**
- Lập bảng liệt kê các file hook, file plist liên quan, tần suất gọi, và trạng thái fallback hiện tại (xem xét nguy cơ leak).

**Phase 1: Xây dựng PXConfigProvider Snapshot**
- Tạo nền tảng `PXConfigProvider.h/m/C.h` sử dụng Immutable Snapshot và Atomic Swap.

**Phase 2: Hook Hot Path (Ưu tiên Cao)**
- Refactor các file I/O nặng nhất trước: `UUIDHooks.x`, `WiFiHook.x`, `NetworkConnectionTypeHooks.x`, `IOSVersionHooks.x`, `UserDefaultsHooks.x`.

**Phase 3: Refactor nhóm còn lại**
- Cập nhật các hooks ít gọi hơn: `ThemeHooks.x`, `PasteboardHooks.x`, `StorageHooks.x`, `MissingSpoofHooks.x`, `DomainBlockingHooks.x`.

**Phase 4: Sửa WeaponX write path (Ứng dụng chính)**
- Áp dụng Atomic write cho quá trình ghi Profile Plist và gom nhóm Darwin notification.

**Phase 5: Kiểm thử Toàn diện**
- Test cold start, đổi profile in background, test độ trễ Facebook/TikTok, fail-closed khi thiếu file.
