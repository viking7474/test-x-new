# Phase 5 — Lockdown software/model providers

Phase 5 hiện thực các provider Lockdown cho nhóm **software/model** (LOCK-03/LOCK-05), dựa trên safety foundation của Phase 4. Chưa đụng tới device identity, SoC hoặc cellular (thuộc Phase 6/7).

## Key trong phạm vi

| Lockdown key | Nguồn snapshot | Consistency group | Kiểu |
|---|---|---|---|
| `kLockdownProductVersionKey` | `IOSVersion` | `ProductVersion` | String |
| `kLockdownBuildVersionKey` | `IOSBuild` | `ProductBuildVersion` | String |
| `kLockdownProductTypeKey` | `DeviceModel` | `DeviceModel` | String |
| `kLockdownDeviceNameKey` | `DeviceName` | `DeviceName` | String |

Provider không sửa trực tiếp các constant firmware; chỉ thay kết quả lookup theo snapshot.

## Nhóm option

- `lockdownSoftwareVersionEnabled` — nguyên tử cho cả ProductVersion và BuildVersion. Không bật riêng từng key.
- `lockdownProductModelEnabled` — ProductType.
- `lockdownDeviceNameEnabled` — DeviceName.

Tất cả mặc định OFF và chỉ nhận `@YES` strict; giá trị thiếu/sai type coi như OFF.

## Thứ tự quyết định

`PXLockdownSoftwareModelResolve` trả giá trị gốc trừ khi **tất cả** điều kiện đợc thỏa:

1. Key thuộc phạm vi Phase 5.
2. Nhóm option tương ứng đang ON.
3. Safety decision (Phase 4) cho phép ở chế độ profile-backed — observe-only/denied/expired/kill-switch đều trả original.
4. Snapshot có giá trị String không rỗng.
5. Cross-surface consistency: mọi surface trong group (SystemVersion / MobileGestalt / IORegistry / sysctl) đều resolve cùng một giá trị và group không bị partial.

Kiểu String luôn được bảo toàn; bất kỳ thất bại nào trả về original.

## Tests

Static test trên mọi host:

```sh
python scripts/test_phase5_lockdown_software_model_static.py
```

Foundation test trên macOS:

```sh
clang -fobjc-arc -DINTERNAL_SECURITY_RESEARCH=1 -framework Foundation -I research -I common \
  common/PXConsistencyMatrix.m \
  research/PXLockdownResearchSafety.m \
  research/PXLockdownSoftwareModelProvider.m \
  tests/PXLockdownSoftwareModelTests.m \
  tests/PXLockdownSoftwareModelMain.m \
  -o /tmp/phase5-lockdown-software-model
/tmp/phase5-lockdown-software-model
```
