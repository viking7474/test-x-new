# 4C.2H5A — No compensation without primary acknowledgement

Ngày 2026-10-29. Người dùng xác nhận H4Z build pass trước bước này.

## Finding — confirmed bug, Medium / P1

`IdentifierManager.setIdentifierEnabledAndPersist:forType:` chạy cùng rollback
sequence cho mọi apply failure: khôi phục memory flag, save toàn bộ settings/scope,
rồi ghi secondary/security flag và notification. Nhưng primary source write có
thể đã fail, source store phục hồi exact before-images/absence, hoặc đang giữ
journal chờ recovery. Trường hợp đó không có acknowledged primary mutation để
high-level wrapper bù lại bằng snapshot của manager.

Reproduce 1: settings/scope chưa tồn tại; fault một physical source write trong
primary transaction; source store phục hồi absence; fault chỉ xảy ra một lần.
Trước patch, compensating save kế tiếp có thể tạo lại cả settings/scope và publish
notification dù public operation trả NO.

Reproduce 2: primary fail, sau gate release một manager khác/direct writer commit
settings/scope/security mới; wrapper cũ tiếp tục unconditional compensation từ
stale memory. Full settings/scope save và secondary write có thể ghi đè newer
intent. H4Z token map không bao instance khác hoặc direct writer.

Tác động: false side effects sau failed operation, mất newer state, file creation
ngoài expected failed-transaction rollback, redundant I/O/cache invalidation/
notifications. Chưa có device trace để kết luận tần suất thực tế.

## Implementation

Private apply overload trả thêm `primaryCommitted` output, độc lập với BOOL apply
success và manager.error. Output reset NO trước owner validation, chỉ đổi YES sau
`saveSettingsWithError:` trả thành công, trước readback/secondary steps. Generic
void path truyền NULL; public API signatures giữ nguyên.

Verified wrapper vẫn restore requested memory flag khi invocation còn current.
Disk compensation chỉ chạy khi primary được acknowledge commit. Khi primary
chưa acknowledge, không gọi saveSettings, không secondary rollback/mirror/topic,
không invalidate caches hay publish compatibility notification từ recovery path.
Giữ source error và trả NO; không suy primary commit từ matching old bool.

Nếu primary commit thành công nhưng secondary/verification fail, output vẫn YES
và existing best-effort compensation giữ nguyên. H4Z token checks và finally
cleanup vẫn bảo vệ reentry ở forward/rollback boundaries. Log ghi rõ primary
acknowledgement thay vì ngụ ý đã hoàn tất persisted rollback cho mọi failure.

## Boundaries

BOOL output là invocation-local acknowledgement trên normal return, không phải
durable commit identifier hoặc CAS receipt. Không làm source-store schema/API,
transaction/journal policy hoặc callback exception policy thay đổi. Nếu source
recovery còn pending hoặc outcome chưa được acknowledge, để source owner xử lý;
không dùng stale high-level settings save làm recovery retry.

SourceStore normal pre-commit faults trong fixture phục hồi exact bytes/absence.
Không khẳng định mọi failure trên thiết bị luôn phục hồi được ngay khi I/O tiếp
tục lỗi hoặc có post-marker exception. Primary observer throw vẫn propagate theo
legacy policy; wrapper không tự compensate khi exception đang unwind.

Đây chỉ đóng blind compensation của nhánh primary chưa acknowledge. Sau primary
đã commit, compensation vẫn thiếu cross-instance/process CAS, vẫn có thể gặp
newer writer; cần xử lý riêng. Source/defaults authority, manager thread-safety,
global cache ordering và stale memory khi writer ngoài instance commit vẫn partial.
Token guard không thay transactional source ownership.

Generation chạy trước primary có thể đã commit artifact/cache riêng; patch không
undo hay thay generation policy. Không claim whole-operation artifact atomicity.
Không chạm RootHide bootstrap/injection/dependencies hoặc backup/restore service.

## Performance / lifecycle

Success path chỉ thêm local BOOL/output assignment và error-path branch; expected
relative overhead negligible, chưa benchmark. Primary failure bỏ một full paired
source save và tối đa một secondary write/defaults mirror/topic, cùng cache clear
và notification tương ứng. Relative saving low/moderate trên error path, phụ thuộc
I/O và observers; không đưa số latency/CPU thiếu dữ liệu. Readback checks hiện có
vẫn giữ. Không thêm hook, queue, lock, timer, polling hay object lifetime owner.

## Verification

Group recipe giữ 53 actual IdentifierManager methods; đổi private selector và cả
caller/declaration tương ứng. Rootful và RootHide-defined macOS host lanes vẫn
chạy ba lần/lane. Real SourceStore/Publisher, controlled providers/security;
không chạy defaults daemon hoặc device injection trong Foundation fixture.

Native scenarios:

- One-shot fault ở từng physical primary file, cho IDFA/WiFi/Battery/DeviceTheme:
  đúng một source attempt; exact snapshot/commit token/cache giữ nguyên; memory
  flag restore; không secondary write/topic hay settings notification.
- Fault khi settings/scope absent: giữ exact absence, không tạo rollback files.
- Adapter mô phỏng scheduling sau failed primary/gate release; manager khác hoặc
  direct transactional writer commit tuple mới. Old operation trả NO nhưng giữ
  exact newer snapshot/token, không thêm write/notification/cache effects.
- Output reset trước rejected token, và vẫn YES khi primary thành công rồi
  secondary fail. Existing secondary compensation/H4Z reentry fixtures vẫn chạy.
- H4Y one-shot primary failure oracle đổi có chủ đích: không còn kỳ vọng một
  compensating commit/notification. Static UI guard dùng actual method boundary
  thay fixed 4300-character window; required tokens không bị bỏ.

Windows verification: 62/63 Python suites và 4/4 Node suites pass. Suite bridge
retirement vẫn fail do Git Bash `mkdir /c/Users/ADMIN: Permission denied` (4 failures,
1 error, 1 skip trong 10 tests), cùng environment limitation đã có trước H5A.
Release source gate, RootHide metadata/negative controls 6/6, exact native fragments,
CHECK macro arity và git diff whitespace checks pass. Ba in-memory negative
mutations bỏ compensation guard, đổi output reset thành YES hoặc bỏ caller output
đều bị source contracts bắt. Source checks không thay native execution/benchmark.

Native Foundation/Theos/package/device behavior cần CI; không suy RootHide runtime
pass từ host compile define. User-reported H4Z build pass được ghi riêng.

Người dùng xác nhận H5A build pass ngày 2026-10-30. H5B bổ sung cooperative commit-chain proof và conditional post-primary compensation. Build do người dùng báo, không phải native execution từ Windows.
