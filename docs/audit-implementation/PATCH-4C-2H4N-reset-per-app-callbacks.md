# 4C.2H4N — Reset per-app callback delivery

Ngày 2026-10-28. Người dùng xác nhận H4M build pass trước bước này.

## Findings và scope

Potential correctness/concurrency issues, severity Medium, tại `backupApps:...` và
`clearApps:...` trong `TLinkIOSViewController.m`:

- Mỗi callback trước đây luôn ghi warnings/metadata và gọi app kế tiếp. Duplicate
  result của app A có thể tạo hai requests cho B và ghi metadata nhiều lần trước
  khi H4M terminal phase guard kịp loại duplicate batch completion.
- Callback không kiểm tra Reset token trước metadata hoặc next submission. H4M
  chỉ bảo vệ phase boundary; child batch vẫn có thể tiếp tục sau khi token/phase
  không còn tương ứng.
- UI note read, warning accumulator và metadata effects dựa vào callback thread.
  Normal service paths thường deliver main, nhưng adapter chưa có main contract.
  Backup service có synchronous early-error path; synchronous callbacks còn có thể
  tạo recursive stack theo số apps. Chưa có device evidence rằng normal services
  đang gửi duplicate results hoặc background UI callbacks.

Reproduce bằng controlled producer gửi success/error hai lần cho một app, gửi từ
background, hoặc trả synchronous results cho nhiều apps. Retire token khi app A
còn pending rồi deliver callback để kiểm tra child batch không submit app B.

## Implementation

Hai generic selectors giữ API cũ và route tới token-aware overload với nil token.
Reset backup/clear callers truyền token H4M tường minh. Luồng save RRS trước restore
không tự nhận token của một Reset không liên quan đang sống trên controller.

Token-aware workers handoff main trước đọc UI, progress, submit hoặc terminal
completion. Mỗi submitted app có một `__block BOOL completed`; flag chỉ được đọc/
ghi trong main delivery. First accepted result thắng; callbacks còn lại không ghi
warning/metadata hoặc recurse. Callback luôn dispatch main, nên cả synchronous
service result cũng không nối call stack từ app này qua app tiếp theo.

`isDashboardReset:inPhase:` là read-only main guard. Explicit Reset batch kiểm tra
đúng token và phase ở entry, rồi kiểm tra lại sau callback claim trước metadata,
warning hoặc next item. Token được giữ qua recursion; stale/wrong-phase batch
không gọi terminal callback để advance run khác. Đây không phải cancellation của
service đang chạy, và không rollback backup/clear đã được submit.

Giữ thứ tự apps, savedCount chỉ tăng sau metadata success, provider warnings,
missing directory/error messages, live RRS note policy, progress calculation và
clear-continues-with-warnings behavior. Không đổi backup option bits, endpoints,
scope, profile generation, bootstrap hoặc restart. Nil completion được kiểm tra ở
terminal thay vì gọi block NULL.

## Verification

Existing native profile fixture extract thêm năm actual batch/helper methods,
tổng 53 manager methods + Profile model + 21 controller methods. Fixture import
actual `AppDataBackupManager.h`/result/options declarations; controlled services
thay implementation, metadata/progress/UI effects dùng collaborators. H4M flow
fixture thêm token overload stubs để giữ riêng phase-boundary coverage.

Native cases thêm:

- Background duplicate backup results: một metadata attempt/app, một next request,
  một terminal; metadata failure và provider warnings giữ savedCount policy.
- Background duplicate clear results: một warning, một next request, một terminal;
  failed app không ngăn clear app tiếp theo.
- Retired token/newer run và wrong phase: không metadata/warnings/remaining service
  submission, không clear newer token hoặc publish old terminal.
- Generic nil-token backup vẫn chạy khi có một Reset khác; không tự bind/cancel.
- 64-app synchronous duplicate backup và clear chains, producer stack depth 1;
  all-app metadata/savedCount và callback counts không nhân đôi.
- Backup error, nil result, missing directory và metadata failure; empty suffix,
  existing saved count, NULL completion và off-main initial entry.

Không chạy real backup/clear, metadata persistence hoặc UIKit. Native recipe vẫn
rootful và RootHide-defined, ba executions/lane; không thêm compiled source hoặc
framework dependency. Windows local: 62/63 Python + 4/4 Node pass. Bridge-shell suite
vẫn lỗi `mkdir /c/Users/ADMIN: Permission denied`. Source hardening, RootHide build/
package static checks, exact extraction, CHECK macro và diff checks pass. Native
compile/runtime, Theos và device H4N chờ macOS CI/thiết bị.

## Performance và remaining boundaries

Một flag và main-delivery block cho mỗi submitted result; checks expected negligible,
queue/allocation cost low trên cold per-app workflow, chưa benchmark latency.
Duplicate results vẫn enqueue một delivery trước khi bị loại, nhưng tránh repeated
metadata và downstream backup/clear I/O có thể moderate/high. Không thêm timer,
polling, lock hoặc hot-hook overhead; không move existing normal main metadata I/O
ra worker trong patch này.

Guarantee là at-most-one accepted result mỗi submitted invocation. Không force
completion nếu service im lặng, không arbitrate hai independent generic batches,
không claim malicious/mutating producer payload safety. Strong owner retention và
service cancellation vẫn riêng. App list/string/warning aliases, live RRS notes,
full tap-time intent và active-profile target pinning chưa freeze/coordinate toàn
workflow. Metadata đang được apply có thể hoàn tất sau reentrant state change;
next item sẽ recheck token. Cross-instance admission, defaults/directory durability,
crash recovery và daemon acknowledgement vẫn partial. Manifest `4C.2H4N-partial`;
whole Reset và toàn Patch 4 chưa hoàn tất, Patch 5–8 chưa triển khai.

Người dùng xác nhận build H4N pass ngày 2026-10-28. Admitted Reset app IDs/note và
explicit scope forwarding được triển khai tiếp tại
[H4O](PATCH-4C-2H4O-reset-admitted-app-inputs.md); full device/whole Reset vẫn partial.
