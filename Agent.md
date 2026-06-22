# Tài liệu Agent - Dự án ProjectX (Kiến trúc Chi tiết & Toàn diện)

Tài liệu này cung cấp cái nhìn chi tiết về kiến trúc mã nguồn, phân loại chức năng và vị trí chính xác của các thành phần trong dự án ProjectX (WeaponX).

## 1. Hệ thống Giả lập Định danh (Identifier Spoofing Framework)
Thành phần trung tâm quản lý việc tạo, lưu trữ và cung cấp các giá trị giả lập cho thiết bị.

- **Quản lý logic chính:** `common/IdentifierManager.m`
- **Định danh cơ bản:**
  - IDFA: `common/IDFAManager.m`
  - IDFV: `common/IDFVManager.m`
  - Số Serial: `common/SerialNumberManager.m`
  - Tên thiết bị: `common/DeviceNameManager.m`
- **Thông tin thiết bị & Phần cứng:**
  - Model Manager: `common/DeviceModelManager.m`
  - Cơ sở dữ liệu Model: `common/IPhoneModelDB.m` (Lưu ý chữ hoa: **IPhone**)
- **Nhóm quản lý định danh UUID (Đầy đủ):**
  - Hệ thống (System): `common/SystemUUIDManager.m`
  - Keychain: `common/KeychainUUIDManager.m`
  - Nhóm ứng dụng (App Group): `common/AppGroupUUIDManager.m`
  - Container ứng dụng: `common/AppContainerUUIDManager.m`
  - Cài đặt (Install): `common/AppInstallUUIDManager.m`
  - Core Data: `common/CoreDataUUIDManager.m`
  - Dyld Cache: `common/DyldCacheUUIDManager.m`
  - Bảng nhớ tạm (Pasteboard): `common/PasteboardUUIDManager.m`
  - User Defaults: `common/UserDefaultsUUIDManager.m`
- **Quản lý Phiên bản & Thời gian:**
  - Thông tin iOS: `common/IOSVersionInfo.m`
  - Cơ sở dữ liệu Build iOS: `common/IOSBuildDB.m`
  - Logic so sánh phiên bản: `common/VersionCompare.m`
  - Thời gian hoạt động (Uptime/BootTime): `common/UptimeManager.m`

## 2. Công cụ Hooking và Can thiệp Hệ thống (System Hooking Engine)
Hệ thống can thiệp API hệ thống tại runtime sử dụng Substrate/ElleKit. Các hook được đồng bộ cấu hình qua một nguồn duy nhất để tránh việc đọc file I/O trùng lặp.

- **Hạ tầng Hooking cốt lõi (Kiến trúc quan trọng):**
  - `ProjectXTweak/MethodSwizzler.m` (và `.h`)
  - `ProjectXTweak/PXScope.m` (và `.h`)
  - `ProjectXTweak/PXConfigProvider.m` (và `PXConfigProviderC.h`): **Quản lý đồng bộ và Cache cấu hình spoofing duy nhất** (tránh I/O liên tục ở tầng Tweak).
  - `ProjectXTweak/HookOwnership.h` (Quản lý trạng thái quyền sở hữu hook)
  - `ProjectXTweak/MobileGestalt.h`
  - `ProjectXTweak/AAA_TestCtor.m` (Mô-đun kiểm tra cơ chế khởi tạo +load/constructor)
- **Logic Hooking thực tế (Các module đã hoàn thiện):**
  - Khởi tạo chính: `ProjectXTweak/Tweak.x`
  - Phiên bản iOS: `ProjectXTweak/IOSVersionHooks.x`
  - Phiên bản App: `ProjectXTweak/AppVersionHooks.x` (Quản lý phiên bản ứng dụng - liên kết `AppVersionManager.m`)
  - Bypass phát hiện Jailbreak: `ProjectXTweak/JailbreakBypassHooks.x`
  - Dữ liệu người dùng: `ProjectXTweak/UserDefaultsHooks.x`
  - Pin/Năng lượng: `ProjectXTweak/BatteryHooks.x` (Liên kết với `common/BatteryManager.m`)
  - Cấu hình thiết bị: `ProjectXTweak/DeviceSpecHooks.x`
  - Mạng/WiFi: `ProjectXTweak/WiFiHook.x` (Liên kết `common/WiFiManager.m`), `ProjectXTweak/NetworkConnectionTypeHooks.x`
  - Dấu vân tay Canvas: `ProjectXTweak/CanvasFingerprintHooks.x`
  - Thời gian khởi động: `ProjectXTweak/BootTimeHooks.x`
  - Ngôn ngữ & Múi giờ: `ProjectXTweak/LocaleTimeZoneHooks.x`
  - Model thiết bị: `ProjectXTweak/DeviceModelHooks.x`
  - Chặn tên miền: `ProjectXTweak/DomainBlockingHooks.x` (Liên kết `common/DomainBlockingSettings.m`)
  - Bảng nhớ tạm (Pasteboard): `ProjectXTweak/PasteboardHooks.x`
  - Hệ thống lưu trữ: `ProjectXTweak/StorageHooks.x`
  - Chủ đề (Theme): `ProjectXTweak/ThemeHooks.x`
  - Các loại UUID: `ProjectXTweak/UUIDHooks.x`
  - Giả lập bổ sung: `ProjectXTweak/MissingSpoofHooks.x` (Bổ sung giả lập cấu hình GPU, Màn hình,...)
  - Hook khởi chạy SpringBoard: `ProjectXTweak/SpringBoardLaunchHook.x`
  - Vô hiệu hóa Firebase Perf: `ProjectXTweak/FirebasePerfDisableScoped.x`
  - Bảo vệ lớp ObjC: `ProjectXTweak/ObjcClassPairGuard.x`
- **Hook ứng dụng cụ thể (App-Specific Hooks):**
  - Uber/DoorDash URL Hook: `ProjectXTweak/UberURLHooks.x` (Chặn và can thiệp URL để lấy Order ID)
- **File rỗng / Placeholder (Chưa triển khai logic):**
  - `ProjectXTweak/KeychainHooks.x` ⚠️
  - `ProjectXTweak/AppContainerHooks.x` ⚠️
  - `ProjectXTweak/AppGroupHooks.x` ⚠️
  - `ProjectXTweak/AppInstallHooks.x` ⚠️
  - `ProjectXTweak/CoreDataHooks.x` ⚠️
  - `ProjectXTweak/VPNDetectionBypass.x` ⚠️

## 3. Giả lập Vị trí và Cảm biến (Location & Sensor Spoofing)
- **Quản lý GPS:** `common/LocationSpoofingManager.m`
- **Hook Cảm biến (Phân tán):** `ProjectXTweak/BatteryHooks.x`, `ProjectXTweak/DeviceSpecHooks.x` (Thay đổi thông tin pin, phần cứng).
- **Quản lý trạng thái Pin:** `common/BatteryManager.m`

## 4. Cô lập Sandbox và Điều hướng Đường dẫn (Path Redirection)
- **Logic chuyển hướng chính:** `ContainerManager.m` (Nằm ở Root)
- **Trình phân giải App Group:** `AppGroupContainerResolver.m`
- **Quản lý lưu trữ:** `common/StorageManager.m`
- **Quản lý đường dẫn (Paths):** `common/PXPaths.m`
- **Placeholder (Chưa triển khai):** `ProjectXTweak/AppContainerHooks.x` ⚠️

## 5. Quản lý Vòng đời Profile (Profile Lifecycle Management)
- **Logic nghiệp vụ:** `common/ProfileManager.m`
- **Giao diện & Hiển thị (UI/Views):**
  - `common/ProfileIndicatorView.m` (Trạng thái)
  - `ProfileCreationViewController.m` (Tạo mới)
  - `ProfileManagerViewController.m` (Danh sách Profile)
  - `ProfileButtonsView.m` (Nút thao tác)
  - `BottomButtons.m` (Các nút điều hướng ở dưới)
  - `common/ScoreMeterView.m` (Biểu đồ điểm số)

## 6. Làm sạch Dữ liệu Nâng cao (Advanced Data Cleaning)
- **Thành phần chính:** `AppDataCleaner.m` (Nằm ở Root)
- **Quản lý ngắt tiến trình (Process Killer):** `common/PXProcessKiller.m`
- **Đóng băng ứng dụng (Freeze):** `FreezeManager.m`
- **Cơ chế phối hợp:** Liên kết trực tiếp với `ContainerManager.m` để xóa thư mục profile và các module dọn dẹp Keychain chuyên sâu.

## 7. Hệ thống Sao lưu và Phục hồi (Backup & Restore System)
- **Logic quản lý file:** `AppDataBackupManager.m` (Root)
- **Trợ giúp Keychain:** `KeychainHelper/KeychainBackupHelper.m`, `KeychainHelper/backup_helper.m`
- **Script hệ thống:** `scripts/keychain_backup.sh`
- **Giao diện quản lý (UI - Nằm ở Root):**
  - Màn hình chính Sao lưu/Phục hồi: `AppDataBackupRestoreViewController.m`
  - Màn hình quản lý nhóm Keychain: `BackupKeychainGroupsViewController.m`, `KeychainGroupsViewController.m`

## 8. Daemon và Thành phần Duy trì Trạng thái
- **System Daemon:** `WeaponXMountDaemon/WeaponXDaemon.m` (hoặc `WeaponXMountDaemon.m`)
- **App Guardian (Bảo vệ ứng dụng):** `WeaponXGuardian.m`
- **Cầu nối Keychain:** `WeaponXKeychainBridge/Tweak.m`

## 9. Giám sát Mạng và Cấu hình (Network & Configuration Monitoring)
- **URL Monitor:** `URLMonitor.m`, `ProjectXTweak/UberURLHooks.x`
- **Quản lý kết nối & IP:** `common/NetworkManager.m`, `common/IPMonitorService.m`
- **Bộ đệm trạng thái IP:** `common/IPStatusCacheManager.m`
- **Quản lý cấu hình Wifi:** `common/WiFiManager.m`
- **Chặn Tên miền:** `common/DomainBlockingSettings.m`

## 10. Giao diện Người dùng và Công cụ Điều khiển (UI & Tools)
- **Core / Main:** `main.m`, `ProjectXSceneDelegate.m`, `ProjectXViewController.m`, `TabBarController.m`, `TabBarController+DeviceAlerts.m`
- **Quản lý Phiên bản Ứng dụng/Thiết bị:** `AppVersionManager.m`, `VersionManagementViewController.m`, `FixVersionAppsViewController.m`, `AppVersionSpoofingViewController.m`, `DeviceSpecificSpoofingViewController.m` (và các categories/extensions của nó)
- **Quản lý Thiết bị:** `DevicesViewController.m`
- **Quản lý Tên miền (Domain):** `DomainManagementViewController.m`
- **Quản lý Bảo mật & IP:** `SecurityTabViewController.m`, `SecurityTabViewController+IPMonitorInfo.m`, `common/IPStatusViewController.m`
- **Công cụ & Tiện ích Khác:**
  - `ToolViewController.m` (Màn hình công cụ chung)
  - `FileManagerViewController.m` (Quản lý tệp)
  - `DownloadResourcesViewController.m` (Tải tài nguyên)
  - `PlistViewerViewController.m` (Xem tệp Plist)
  - `UberOrderViewController.m`, `DoorDashOrderViewController.m` (Giao diện xem đơn hàng lấy được từ hook)
  - Các tiện ích UI: `common/PassThroughWindow.m`, `common/UIButton+SafeConfiguration.m`, `common/UIButtonCompat.m`, `ProgressHUDView.m`
- **Hệ thống & Cài đặt:**
  - Phân tích Quyền hạn (Entitlements): `AppEntitlementsReader.m` (Dùng ldid phân tích entitlements của app mục tiêu)
  - Chạy lệnh (Command Runner): `CommandRunner.m`
  - Tiện ích Sao chép (Copy Helper): `CopyHelper.m`
  - Cài đặt hệ thống: `ProjectXInstaller.m`

## 11. Core Logging & Utilities
- **Hệ thống Log:** `common/ProjectXLogging.m`, `common/DBDebugLogger.m`

---
