# Phase 2 — Snapshot/validator hardening

## Phạm vi tiếp tục

Bổ sung lớp dependency validator sau format validator IOS-02 để thực thi exit criteria của Phase 2: profile sai không được publish và mọi provider tiếp tục đọc cùng một snapshot/generation.

## Luồng publication

1. Đọc `device_ids.plist` và `settings.plist` đúng một lần.
2. Deep-copy thành immutable input.
3. Canonicalize/kiểm tra định dạng bằng `PXValidateDeviceIDs`.
4. Lấy đồng thời `iosBuildDB` và `iphoneModelDB` từ một publication IOS-03.
5. Chạy `PXValidateIdentityDependencies`.
6. Chỉ publish candidate khi cả format và dependency validation đều hợp lệ.
7. Nếu reload cùng profile thất bại, giữ nguyên last-known-good snapshot; khi đổi profile thì không giữ snapshot profile cũ.

## Dependency rules

- Software tuple là nguyên tử: `IOSVersion`, `IOSBuild`, `Darwin`, `XNU`, `KernelVersion` phải cùng có hoặc cùng vắng.
- Build phải tồn tại và mọi thành phần phải khớp chính xác metadata trong database.
- Kernel banner phải chứa đúng Darwin và XNU.
- `DeviceModel` phải tồn tại trong model database.
- Build phải nằm trong `deviceToBuilds[DeviceModel]`.
- `BoardID`/`HwModel` phải khớp cùng một hardware variant.
- Model khai báo không có cellular không được mang IMEI/MEID/ICCID/IMSI/baseband.
- IMEI2 không được tồn tại nếu thiếu IMEI1.
- Profile có model/software tuple nhưng thiếu coherent IOS-03 database sẽ fail closed.

## Tests

`tests/PXPhase2ValidatorTests.m` bao phủ happy path và các negative fixture: version/build mismatch, tuple thiếu thành phần, hardware variant sai, cellular trên model Wi-Fi-only và thiếu database.

Trên macOS/iOS toolchain:

```sh
clang -fobjc-arc -framework Foundation -I common \
  common/PXIdentityValidator.m \
  common/PXIdentityDependencyValidator.m \
  tests/PXPhase2ValidatorTests.m \
  tests/PXPhase2ValidatorMain.m \
  -o /tmp/phase2-validator-tests
/tmp/phase2-validator-tests
```
