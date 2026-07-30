# Phase 3 — Kernel và hardware hooks

Phase 3 hoàn tất IOS-05/06/07 đã có và harden HOOK-02/03 bằng một registry dùng chung cho MobileGestalt và IORegistry.

## Registry

`PXIdentitySurfaceRegistry` khai báo tập trung cho mỗi identity:

- canonical key và aliases;
- surface được phép (`MobileGestalt`, `IORegistry`);
- toggle sở hữu identity;
- source key trong immutable identity snapshot hoặc constant;
- expected ABI type (`String`, `Data`, `StringOrData`, `StringOrDataArray`).

Lookup luôn bị giới hạn theo surface, nên alias của MobileGestalt không tự động được dùng trên IORegistry. Validator phát hiện alias trùng, source mơ hồ, toggle/surface rỗng và expected type không hợp lệ.

## Hook integration

- MobileGestalt dùng registry cho product type, hardware model, board ID, model number và iOS version/build/release type.
- Cả ba đường IORegistry (`CreateCFProperty`, bulk `CreateCFProperties`, `SearchCFProperty`) đều resolve alias, toggle, snapshot source và expected type qua cùng registry.
- IORegistry replacement dùng expected type từ registry khi original property không tồn tại; nếu original tồn tại thì giữ ABI type thực tế.
- `serial-number` và `mlb-serial-number` dùng hai source độc lập (`SerialNumber`/`MLBSerialNumber`), không còn collapse MLB vào serial thiết bị.
- `compatible` tiếp tục giữ semantics array/data đặc thù.

## Kiểm thử

Static CI trên mọi host:

```sh
python scripts/test_phase3_hooks_static.py
```

Foundation test trên macOS:

```sh
clang -fobjc-arc -framework Foundation -I common \
  common/PXIdentitySurfaceRegistry.m \
  tests/PXIdentitySurfaceRegistryTests.m \
  tests/PXIdentitySurfaceRegistryMain.m \
  -o /tmp/phase3-registry-tests
/tmp/phase3-registry-tests
```
