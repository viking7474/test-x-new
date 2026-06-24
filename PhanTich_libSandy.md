# Phân tích vai trò của libSandy trong mã nguồn ProjectX

Dựa trên việc phân tích mã nguồn, **libSandy** (một thư viện nổi tiếng trên iOS jailbreak, do opa334 phát triển) được sử dụng để mở rộng quyền truy cập sandbox (Sandbox Extensions) một cách an toàn cho các ứng dụng trên iOS.

Trong ngữ cảnh của ProjectX (hoặc WeaponX), các ứng dụng iOS gốc bị giới hạn bởi cơ chế Sandbox rất nghiêm ngặt của Apple. Khi ProjectX tiêm (inject) các mã giả mạo (hook) vào một ứng dụng, phần mã đó chạy dưới quyền của chính ứng dụng đó. Do vậy, nó sẽ không thể đọc/ghi được các tệp tin cấu hình chung của tweak hoặc can thiệp vào các đường dẫn hệ thống bên ngoài Sandbox. libSandy được sử dụng để giải quyết triệt để vấn đề này.

Dưới đây là phân tích chi tiết về cách libSandy được sử dụng trong mã nguồn:

### 1. Cấu hình quyền truy cập qua `projectx_filesystem_access.plist`
File cấu hình chính của libSandy được định nghĩa tại `layout/Library/libSandy/projectx_filesystem_access.plist`. File này chứa các chỉ thị quan trọng:

- **`AllowedProcesses`**: Được đặt là `*` (tất cả). Điều này nghĩa là profile này sẽ được libSandy áp dụng cho **tất cả các tiến trình/ứng dụng** trên hệ thống khi có tải các hook của ProjectX.
- **`sandbox-extensions`**: Cấp quyền `com.apple.app-sandbox.read-write` (đọc-ghi) cho 2 đường dẫn cụ thể ngoài Sandbox:
  - `/var/jb/var/mobile/Library/WeaponX`: Đây là thư mục lưu trữ cấu hình chung (ví dụ: Immutable Snapshots) và log của ProjectX. Nhờ có quyền này, các ứng dụng bị hook mới có thể đọc được cấu hình spoofing mới nhất do App điều khiển (PXConfigProvider) sinh ra mà không bị văng lỗi (Crash do sandbox denial).
  - `/var/mobile/Library/Keychains`: Cấp quyền truy cập trực tiếp vào Keychain của iOS. Việc này cho phép ProjectX can thiệp, đọc, giả mạo hoặc xóa dữ liệu Keychain của các ứng dụng (rất cần thiết trong quá trình thay đổi Device ID hoặc xóa dữ liệu cũ của App).
- **`extensions` (SANDBOX_REDIRECTED_PATH)**:
  Khai báo hàng loạt các quy tắc `file-read*` và `file-write*` cho các đường dẫn biến số `SANDBOX_REDIRECTED_PATH`. Nó mở quyền để các ứng dụng có thể đọc/ghi vào các thư mục ảo/giả mạo (như `Containers/Data/Application`, `Library/Preferences`, `Caches`, `tmp`). Đây là thành phần cốt lõi để ProjectX thực hiện tính năng **cách ly ứng dụng (App Isolation)** hoặc **giả mạo hệ thống tệp (File System Spoofing)**.

### 2. Quá trình triển khai cài đặt (`DEBIAN/postinst`)
Trong file script chạy sau khi cài tweak (`DEBIAN/postinst`), các lệnh liên quan đến libSandy được thực hiện tự động:
- Script tự động tạo thư mục `/Library/libSandy/` và `/Library/Sandbox/Profile/` với quyền chuẩn xác (`root:wheel`).
- File profile `projectx_filesystem_access.plist` sẽ được sao chép vào các thư mục này một cách tự động.
- Mục đích của các thao tác này là để đảm bảo ngay sau khi cài đặt ProjectX, daemon của thiết bị hoặc thư viện libSandy sẽ nhận diện và nạp các quy tắc nới lỏng Sandbox này ngay lập tức.

### Tóm tắt lại
Trong cấu trúc của mã nguồn ProjectX, **libSandy đóng vai trò là "chìa khóa" phá vỡ rào cản Sandbox của Apple một cách có chủ đích**. Nó cấp cho các mã giả mạo được nhúng trong ứng dụng "tấm thẻ bài" để:
1. Truy cập vào cấu hình điều khiển chung của tweak.
2. Can thiệp vào hệ thống tệp và Keychain để giả mạo thông tin.
3. Cho phép hệ thống chuyển hướng đường dẫn (Redirected paths) hoạt động mà không bị hệ điều hành chặn lại.