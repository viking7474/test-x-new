# 4C.2H4K — Reset Data preparation failure gates

Ngày 2026-10-28. Người dùng xác nhận H4J build pass trước bước này.

## Findings và phạm vi

Hai confirmed logic bugs, severity High, nằm trong
`TLinkIOSViewController.m`:

- `ensureDashboardFakeOptionsEnableRequiredIdentifiers:` chỉ log khi
  `setIdentifierEnabledAndPersist:forType:` trả NO. Caller vẫn regenerate và áp
  preview; phần hardware/storage có thể không chạy với enable map cần thiết.
- `createNextProfileAndRandomizeWithWarnings:` dùng void regeneration wrapper.
  Khi underlying generation trả failure, caller vẫn áp preview rồi có thể báo
  “Hoàn tất” và lên lịch `killEnabledAppsAndRespring`. Preview success không
  chứng minh enabled groups trước đó đã generate thành công.

Reproduce bằng fault injection vào một required toggle hoặc runtime generation
sau khi create/switch thành công. Trước patch, lỗi không chặn phần còn lại nếu
preview vẫn thành công. Không cần giả định failure xảy ra thường xuyên trên device.

## Thay đổi

Required-identifier helper trả BOOL/NSError và dừng enumeration ở setter failure
đầu tiên. Error chỉ rõ key bị lỗi, giữ optional `lastError` làm diagnostic context;
vẫn có error khi setter không cung cấp nguyên nhân. Không tự rollback những key
đã thành công trước đó, không giả định NSDictionary enumeration có thứ tự cố định.

`prepareResetProfileWithOptions:preview:error:` là synchronous main-thread adapter:

1. Enable các required flags theo policy hiện tại.
2. Gọi `regenerateAllEnabledIdentifiersWithError:` và yêu cầu YES.
3. Áp preview bằng adapter/source coordinator hiện có và yêu cầu YES.

Failure trả NO cùng error, kể cả underlying generation không trả NSError. Caller
ẩn HUD, hiển thị lỗi và return trước khi xóa pending preview, persist dashboard
selections, gửi explicit final profileChanged, báo hoàn tất hoặc schedule restart.
Preview error không còn nói “Không phát hành snapshot mới”: create/switch,
toggle hoặc generation trước đó có thể đã commit và notify.

Giữ create → switch → enable → regenerate → preview, required flag defaults
(iOS/model ON, name OFF), StorageSystem theo Fake Model, enable-only behavior và
skip đã-enabled flag. Không bỏ extra Reset generation như manual create H4J vì
Reset có options/prepared-preview intent riêng. Không đổi model/storage selection,
counter, source journal, bootstrap, hook, package dependency hay timer success path.

## Verification

Existing Foundation profile fixture extract thêm đúng hai production adapters,
tổng 53 ProfileManager methods + Profile model + 7 controller methods. Controlled
identifier/preview collaborators kiểm tra:

- Tám tổ hợp options và nil/default options; số enable writes, storage dependency.
- Từng required key trả NO: không tiếp tục enable sau failure, không generation
  hoặc preview; error có key context/optional underlying diagnostic.
- Second-write failure giữ earlier successful flag; không rollback giả toàn workflow.
- Generation failure có/không có NSError đều dừng trước preview; NULL error output
  vẫn trả failure an toàn.
- Preview failure sau đúng một generation; successful order, skip existing enabled
  flags, unrelated flags và disabled fake options không tự tắt existing settings.
- Off-main preparation reject trước provider/persistence; public Reset entry vẫn
  giữ main handoff có từ H4I.

UI tail được source guard kiểm tra failure return trước success effects. Đây không
phải runtime UIKit/restart test. Existing native recipe chạy rootful và
RootHide-defined lanes, ba executions mỗi lane; không thêm compile dependency.

Local Windows: 62/63 Python suites, 4/4 Node suites pass. Remaining bridge-shell
suite vẫn lỗi Git Bash `mkdir /c/Users/ADMIN: Permission denied`. Source hardening,
RootHide build/package static checks, CHECK macro validation và extraction pass.
Native/Foundation/Theos H4K chưa chạy tại Windows; cần macOS CI và device checks.

## Cost và giới hạn

Success path chỉ thêm status propagation/function call, relative cost negligible.
Failure path tránh generation/preview I/O và restart không được phép chạy tiếp;
avoided work có thể moderate/high tùy enabled groups, chưa benchmark latency.
Không thêm polling, queue, lock, timer hoặc hot-path hook.

Các bước vẫn là separate commits. App data có thể đã clear, profile đã activate,
toggles/generation có thể đã persist trước failure. Không rollback app data hoặc
profile, không tự retry. Already-enabled flags vẫn skip theo live manager state;
không chứng minh settings/defaults authority hoặc cache convergence toàn cục.

Shared mutable reset options/preview, overlapping resets, callback ownership,
selection supersession và cross-phase target pinning còn cần xử lý riêng. Success
notification/timer không phải daemon distribution acknowledgement. Giữ RootHide
cold bootstrap đã xác nhận; không đổi snapshot priming hoặc package runtime.
Manifest `4C.2H4K-partial`; whole Reset và toàn Patch 4 vẫn partial, Patch 5–8 chưa
triển khai.
