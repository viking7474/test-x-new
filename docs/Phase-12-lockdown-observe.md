# Phase 12 — Lockdown L0 observe-only layer

Hoàn thiện **giai đoạn L0 (Observe only)** trong kế hoạch §4.6 ("Thứ tự triển khai Lockdown theo rủi ro").

L1/L2/L3 đã được triển khai từ trước:

| Giai đoạn | Phạm vi | Provider |
|---|---|---|
| L1 | software / presentation (Build/Product/DeviceName) | `PXLockdownSoftwareModelProvider` (Phase 5) |
| L2 | device identity (UDID/serial/MLB) | `PXLockdownDeviceIdentityProvider` (Phase 6) |
| L3 | SoC / cellular (ChipID/IMEI/MEID/baseband) | `PXLockdownSoCCellularProvider` (Phase 7) |

L0 trước đó chỉ được phủ một phần bởi Phase 4 (`PXLockdownResearchModeObserveOnly` + `PXLockdownRedactedAuditEvent`). Phase này bổ sung lớp quan sát **chỉ-đọc** còn thiếu.

## Phạm vi

`research/PXLockdownObservability.{h,m}` — không bao giờ thay đổi một giá trị Lockdown; mọi thay thế chủ động vẫn thuộc các provider L1/L2/L3.

1. **Inventory hợp nhất** — `PXLockdownObservedKeyInventory()` tổng hợp mọi key từ ba provider (`PXLockdownSoftwareModelEntries` / `PXLockdownDeviceIdentityEntries` / `PXLockdownSoCCellularEntries`), mỗi key kèm domain, source provider, expected type và cờ sensitive. `PXLockdownObservabilityInventoryIsWellFormed` tự kiểm tra đủ số lượng, không trùng key, provider/class không rỗng.
2. **Observation record có redact** — `PXLockdownObservationRecord(process, key, value, domain)` trả metadata (process, key, expectedType, sourceProvider, domain, mode=`observe`). Payload luôn `<redacted>` cho các định danh nhạy cảm (UDID/serial/MLB/IMEI/IMEI2/MEID/ChipID); key presentation chỉ lộ tên class, không bao giờ lộ giá trị thô.
3. **Từ chối domain cấm** — `PXLockdownObservationDomainIsForbidden` chặn pair record, certificate, private key và escrow; `PXLockdownObservationRecord` trả `nil` cho các domain này.
4. **Metrics** — `PXLockdownAccessMetrics` đo tần suất truy cập, timeout và cache hit/miss theo từng key, kèm `redactedSnapshot` chỉ chứa tên key và bộ đếm.

Provider tuân thủ build gate `INTERNAL_SECURITY_RESEARCH` (có `#error` khi thiếu gate) và không dùng `NSLog`/`PXLog`/`PXDBLog`.

## Tests

Static test trên mọi host:

```sh
python scripts/test_phase12_lockdown_observe_static.py
```

Foundation test trên macOS (build nội bộ):

```sh
clang -fobjc-arc -DINTERNAL_SECURITY_RESEARCH=1 -framework Foundation -I research \
  research/PXLockdownResearchSafety.m \
  research/PXLockdownSoftwareModelProvider.m \
  research/PXLockdownDeviceIdentityProvider.m \
  research/PXLockdownSoCCellularProvider.m \
  research/PXLockdownObservability.m \
  tests/PXLockdownObservabilityTests.m \
  tests/PXLockdownObservabilityMain.m \
  -o /tmp/phase12-lockdown-observe
/tmp/phase12-lockdown-observe
```
