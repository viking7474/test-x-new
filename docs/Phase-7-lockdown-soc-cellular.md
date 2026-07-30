# Phase 7 — Lockdown SoC/cellular providers

Phase 7 hiện thực L3 trong kế hoạch: provider Lockdown cho **SoC identity** và **cellular/baseband**, nằm hoàn toàn sau safety foundation của Phase 4. Provider không can thiệp pairing, trust, activation, attestation hoặc daemon hệ thống.

## Registry và expected type

| Lockdown key | Snapshot field | Nhóm | Kiểu |
|---|---|---|---|
| `kLockdownUniqueChipIDKey` | `UniqueChipID` | SoC identity | Giữ CFType gốc |
| `kLockdownIMEIKey` | `IMEI` | Cellular/baseband | String |
| `kLockdownSecondaryIMEIKey` | `IMEI2` | Cellular/baseband | String |
| `kLockdownMobileEquipmentIdentifierKey` | `MEID` | Cellular/baseband | String |
| `kLockdownBasebandVersionKey` | `BasebandVersion` | Cellular/baseband | String |

Tên key IMEI2/MEID phụ thuộc firmware. Registry Phase 7 dùng tên tương đương nội bộ, chỉ có hiệu lực nếu lookup được adapter hỗ trợ; provider không giả định mọi firmware export cùng constant.

## Option nguyên tử

Phase 7 chỉ có hai option group, mặc định OFF và chỉ nhận `@YES` strict:

- `lockdownSoCIdentityEnabled`: điều khiển toàn bộ UniqueChipID.
- `lockdownCellularBasebandEnabled`: điều khiển nguyên tử IMEI1/IMEI2/MEID/BasebandVersion.

Không tồn tại per-key toggle cho ChipID, IMEI2, MEID hoặc baseband; điều này ngăn snapshot công bố cellular schema dở dang.

## Capability-aware validator

`PXLockdownSoCCellularSchemaValidate` kiểm tra toàn bộ tuple trước khi sử dụng:

1. `ProductType ↔ SoC` phải có trong bảng model được biết; model không biết bị fail closed.
2. `UniqueChipID` phải là CFNumber khác 0 hoặc chuỗi hex hợp lệ.
3. `CellularCapable` phải đồng thuận với capability của model.
4. Model Wi-Fi-only không được chứa IMEI, IMEI2, MEID hoặc BasebandVersion.
5. Model cellular phải có IMEI1 15 chữ số với Luhn hợp lệ và baseband version đúng hình thức.
6. Dual-SIM (`AdvertisedSIMCount >= 2`) bắt buộc có IMEI2 hợp lệ; single-SIM không được công bố IMEI2.
7. MEID, nếu có, phải là 14-hex viết hoa hoặc 18 chữ số.
8. `BasebandFamily` phải phù hợp ProductType.

Provider không tự tạo ngẫu nhiên IMEI, ChipID hoặc baseband khi dữ liệu thiếu.

## Resolve và fallback

`PXLockdownSoCCellularResolve` chỉ thay original khi key thuộc scope, group đang ON, safety decision cho phép profile-backed, capability phù hợp, hình thức hợp lệ và dependency validator thông qua. IMEI/MEID còn được đối chiếu với các telephony/IORegistry surfaces trong shared identity registry.

- UniqueChipID chọn expected class từ giá trị original, nên CFType mismatch luôn trả original.
- IMEI/IMEI2/MEID/BasebandVersion luôn giữ String.
- Observe-only, ngoài allowlist, hết TTL, option OFF, model Wi-Fi-only hoặc validation lỗi đều trả original.

## Model table scope

Phase 7 dùng bảng fixture nhỏ để thực thi fail-closed và kiểm thử quan hệ model/SoC/baseband. Việc mở rộng production database thuộc IOS-03/CELL-01; ProductType chưa biết không được suy đoán. Điều này tránh hard-code một baseband hoặc SoC cho mọi model.

## Tests

Static contracts trên mọi host:

```sh
python scripts/test_phase7_lockdown_soc_cellular_static.py
```

Foundation harness trên macOS:

```sh
clang -fobjc-arc -DINTERNAL_SECURITY_RESEARCH=1 -framework Foundation -I research -I common \
  common/PXIdentitySurfaceRegistry.m \
  research/PXLockdownResearchSafety.m \
  research/PXLockdownSoCCellularProvider.m \
  tests/PXLockdownSoCCellularTests.m \
  tests/PXLockdownSoCCellularMain.m \
  -o /tmp/phase7-lockdown-soc-cellular
/tmp/phase7-lockdown-soc-cellular
```

Negative fixtures bao phủ Wi-Fi-only, IMEI sai Luhn, dual-SIM thiếu IMEI2, single-SIM lộ IMEI2, ProductType/SoC sai và baseband family sai.
