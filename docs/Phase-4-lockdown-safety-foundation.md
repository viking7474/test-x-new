# Phase 4 — Lockdown safety foundation

Phase này chỉ bổ sung **safety foundation** cho nghiên cứu nội bộ. Chưa hook private Lockdown API và không can thiệp pairing/trust, attestation, AMFI, Activation Lock hoặc anti-fraud.

## Build gate

- `INTERNAL_SECURITY_RESEARCH` mặc định bằng `0`.
- Source Research nằm ngoài `common/` và `ProjectXTweak/`, được thêm bằng danh sách tường minh chỉ khi build nội bộ đặt `INTERNAL_SECURITY_RESEARCH=1`.
- `FINALPACKAGE=1` kết hợp Research sẽ làm build thất bại.
- Bản thân source có compile-time `#error` nếu bị compile mà thiếu gate.

Ví dụ build nội bộ:

```sh
make INTERNAL_SECURITY_RESEARCH=1 FINALPACKAGE=0 DEBUG=1
```

## Runtime gates

`PXLockdownResearchRuntime` fail closed theo thứ tự:

1. Master switch phải bật; thiếu hoặc sai type mặc định là OFF.
2. Phiên phải được arm lại trong process sau mỗi lần launch/reboot.
3. TTL tối đa 15 phút; hết hạn xóa trạng thái phiên.
4. Bundle phải khớp allowlist chính xác, không wildcard.
5. Nếu có process allowlist, process cũng phải khớp chính xác.
6. Daemon bảo mật/activation/trust quan trọng luôn bị từ chối.
7. Observe-only luôn trả original.
8. Validation hoặc expected type thất bại luôn trả original.

Kill switch `disableAllAndClearSnapshot` vô hiệu hóa ngay phiên process-local và xóa expiration/session state. Không có `Apply to all processes` hoặc `Persist after reboot`.

## Audit privacy

Audit event chỉ chứa key, mode, reason code và class của giá trị. Payload luôn là `<redacted>`; API không trả raw identifier.

## Tests

Static test trên mọi host:

```sh
python scripts/test_phase4_lockdown_safety_static.py
```

Foundation test trên macOS:

```sh
clang -fobjc-arc -DINTERNAL_SECURITY_RESEARCH=1 -framework Foundation -I research \
  research/PXLockdownResearchSafety.m \
  tests/PXLockdownResearchSafetyTests.m \
  tests/PXLockdownResearchSafetyMain.m \
  -o /tmp/phase4-lockdown-safety
/tmp/phase4-lockdown-safety
```
