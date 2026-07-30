# IOS-05 — Hoàn thiện `uname`

## Ánh xạ dữ liệu

`uname()` lấy đúng một publication từ `PXIdentitySnapshot` và ánh xạ:

| `struct utsname` | Nguồn | Toggle |
|---|---|---|
| `sysname` | `Darwin` | `IOSVersion` |
| `nodename` | `DeviceName` | `DeviceName` |
| `release` | `Darwin` | `IOSVersion` |
| `version` | `KernelVersion` | `IOSVersion` |
| `machine` | `DeviceModel` | `DeviceModel` |

`IOSBuild` không có trường tương ứng trong `struct utsname`; dữ liệu này tiếp tục được cung cấp qua `kern.osversion`/`sysctl`.

## Quy tắc an toàn

- Gọi `uname` gốc trước và giữ nguyên return code cùng `errno`.
- Không dereference buffer khi lời gọi gốc thất bại hoặc buffer là `NULL`.
- Chỉ spoof trong process được scope cho phép.
- Tôn trọng riêng từng toggle `IOSVersion`, `DeviceName`, `DeviceModel`.
- Dữ liệu thiếu, sai kiểu hoặc vượt capacity sẽ giữ nguyên field native tương ứng.
- Mỗi nhóm field được dựng trên bản sao `struct utsname`; chỉ publish về buffer sau khi nhóm hợp lệ hoàn toàn.
- Copy theo capacity, luôn NUL-terminate và không dùng `strcpy`.
- Có thread-local recursion guard để tránh vòng lặp khi Foundation gọi ngược `uname`.
- Cài hook tối đa một lần và chỉ đánh dấu ownership khi nhận được original function hợp lệ.

## Tính nhất quán

- `machine` đồng nhất với `hw.machine` và `DeviceModel`.
- `release` đồng nhất với `kern.osrelease`/`Darwin`.
- `version` đồng nhất với `kern.version`/`KernelVersion`.
- `nodename` đồng nhất với `gethostname`, `kern.hostname` và `DeviceName`.
