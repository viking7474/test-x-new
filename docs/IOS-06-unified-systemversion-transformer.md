# IOS-06 — Unified SystemVersion transformer

## Mục tiêu

Một transformer duy nhất xử lý mọi biểu diễn của `SystemVersion.plist` thay vì mỗi hook tự sửa dictionary, data hoặc chuỗi XML.

## Nguồn canonical

Mỗi lần transform tạo `PXSystemVersionProjection` từ đúng một `PXIdentitySnapshot` generation:

- `ProductVersion` ← `IOSVersion`
- `ProductBuildVersion` ← `IOSBuild`
- `ReleaseType` ← `User`

Projection chỉ hợp lệ khi cả version và build cùng tồn tại, đúng kiểu và thuộc cùng snapshot. Không publish từng field riêng lẻ.

## Surface sử dụng

- `CFCopySystemVersionDictionary`
- `NSDictionary dictionaryWithContentsOfFile:`
- `NSData dataWithContentsOfFile:`
- `NSString stringWithContentsOfFile:encoding:error:`

## Contract an toàn

- Chỉ transform sau khi hook đã kiểm tra scope và toggle `IOSVersion`.
- Không mutate object đầu vào.
- Giữ nguyên toàn bộ key không được quản lý.
- Dictionary được cập nhật version/build/release type nguyên tử.
- Data giữ nguyên loại plist nguồn: XML, binary hoặc OpenStep.
- Chuỗi plist được parse theo cấu trúc; không regex thay XML.
- Parse, validation hoặc serialization lỗi đều fail-open và trả object gốc.
- Path matcher chỉ nhận đúng component `/System/Library/CoreServices/SystemVersion.plist`, bao gồm prefix rootless/preboot hợp lệ.
