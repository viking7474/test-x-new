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
- Thiết kế cơ chế khóa an toàn (`NSLock`) cho toàn bộ thuộc tính hoặc dùng cờ nguyên tử (Atomic).
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

## 3. Lợi ích Đạt được
1. **Zero I/O bottleneck:** Dữ liệu được đọc hoàn toàn từ RAM thay vì ổ cứng mỗi lần hệ thống bị hook.
2. **Nhanh chóng & Đồng nhất:** Một thay đổi ở ứng dụng WeaponX sẽ phản ánh đồng thời lập tức trên toàn bộ các hooks thông qua cơ chế Cache Reloading.
3. **Mã nguồn sạch (Clean Code):** Gỡ bỏ hàng trăm dòng code xử lý file/path bị lặp lại, tập trung vào `PXConfigProvider.m`.

## 4. Các Bước Thực thi Kế tiếp (Roadmap)
1. **Bước 1:** Định nghĩa và bổ sung đầy đủ thuộc tính vào `PXConfigProvider.h` và `PXConfigProviderC.h`.
2. **Bước 2:** Cập nhật `PXConfigProvider.m` để load tất cả các `.plist` cần thiết.
3. **Bước 3:** Refactor `UUIDHooks.x` và `WiFiHook.x` (đây là 2 file chịu tải I/O nặng nhất).
4. **Bước 4:** Xử lý refactor hàng loạt cho các file hooks còn lại.
5. **Bước 5:** Biên dịch (Build) qua theos và kiểm tra chức năng.
