# Phase 6 — Lockdown device identity providers

Phase 6 hiện thực provider Lockdown cho nhóm **device identity** (LOCK-04), dựa trên safety foundation của Phase 4 và cross-surface registry của Phase 3. SoC và cellular (UniqueChipID/IMEI/Baseband) vẫn ngoài phạm vi (Phase 7).

## Key trong phạm vi

| Lockdown key | Nguồn snapshot | Kiểu | Cross-surface |
|---|---|---|---|
| `kLockdownUniqueDeviceIDKey` | `UDID` | String | (không có MG/IORegistry surface — form + presence) |
| `kLockdownSerialNumberKey` | `SerialNumber` | String | IORegistry `IOPlatformSerialNumber`, `serial-number` |
| `kLockdownMLBSerialNumberKey` | `MLBSerialNumber` | String | IORegistry `mlb-serial-number` |

Provider không sửa trực tiếp constant Lockdown; chỉ thay kết quả lookup theo snapshot.

## Nhóm option nguyên tử

Theo kế hoạch §4.5, UDID / serial / MLB **không** được bật riêng lẻ. Cả ba dùng chung **một** cờ:

- `lockdownDeviceIdentifiersEnabled` — bật/tắt nguyên tử cho cả trio.

Mặc định OFF, chỉ nhận `@YES` strict. Điều này tránh rò rỉ một bộ identity mâu thuẫn (ví dụ serial mới nhưng UDID cũ).

## Thứ tự quyết định

`PXLockdownDeviceIdentityResolve` trả giá trị gốc trừ khi **tất cả** điều kiện được thỏa:

1. Key thuộc phạm vi Phase 6.
2. Nhóm `deviceIdentifiers` đang ON.
3. Safety decision (Phase 4) cho phép ở chế độ profile-backed — observe-only/denied/expired/kill-switch đều trả original.
4. Snapshot có giá trị String **đúng hình thức** (`PXLockdownDeviceIdentityValueIsWellFormed`): UDID là 40-hex hoặc UUID; serial/MLB là alphanumeric viết hoa đúng độ dài.
5. Mọi surface MobileGestalt/IORegistry đăng ký cho field đó resolve cùng một giá trị với candidate và không bị partial.

Kiểu String luôn được bảo toàn; bất kỳ thất bại nào trả về original.

## Đồng nhất theo generation

`PXLockdownDeviceIdentityStableAcrossGeneration` thực thi hợp đồng ȁn định trong phiên:

- Cùng generation ⇒ cả ba giá trị identity phải **giống hệt** giữa hai snapshot (không đổi giữa phiên).
- Khác generation ⇒ giá trị được phép đổi (profile switch).

Provider là hàm thuần của `(key, deviceIDs)` nên cùng một snapshot luôn cho cùng kết quả.

## Giới hạn đã biết

- Cross-surface hiện chỉ phủ IORegistry cho serial/MLB vì surface registry chung chưa có entry MobileGestalt cho SerialNumber/MLB/UDID. Bổ sung MG surface là việc của HOOK-02 (Phase 3 backlog) và sẽ đổi hành vi hook production, nên cố tình hoãn để giữ Phase 6 nằm sau research gate.
- UDID không có surface MG/IORegistry nên consistency dựa trên form + presence (§4.7: profile UDID == API UDID).

## Tests

Static test trên mọi host:

```sh
python scripts/test_phase6_lockdown_device_identity_static.py
```

Foundation test trên macOS:

```sh
clang -fobjc-arc -DINTERNAL_SECURITY_RESEARCH=1 -framework Foundation -I research -I common \
  common/PXIdentitySurfaceRegistry.m \
  research/PXLockdownResearchSafety.m \
  research/PXLockdownDeviceIdentityProvider.m \
  tests/PXLockdownDeviceIdentityTests.m \
  tests/PXLockdownDeviceIdentityMain.m \
  -o /tmp/phase6-lockdown-device-identity
/tmp/phase6-lockdown-device-identity
```
