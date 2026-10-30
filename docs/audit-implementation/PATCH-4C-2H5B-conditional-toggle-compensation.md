# 4C.2H5B — Cooperative source CAS for toggle compensation

Ngày 2026-10-30. Người dùng xác nhận H5A build pass trước bước này.

## Finding — confirmed unsafe composition, Medium / P1

H5A bỏ blind compensation khi primary chưa acknowledge. Nhánh primary đã commit
vẫn save toàn bộ manager settings/scope và ghi security riêng khi apply fail.
Một instance khác hoặc cooperative writer có thể commit từ primary notification,
secondary mirror hoặc khoảng giữa các bước recovery. H4Z token không bao writer
khác; matching bool cũng không chứng minh ownership sau ABA. Stale rollback có
thể ghi đè newer state và publish compatibility effects cho stale snapshot.

Reproduce: primary WiFi commit; callback dùng manager khác đổi WiFi, hoặc đổi rồi
trở lại giá trị cũ; làm secondary fail/verification mismatch. Trước H5B, older
verified caller có thể save lại toàn bộ bag và rollback secondary. Không có device
trace để kết luận tần suất ngoài thực tế.

## Implementation

`PXRuntimeSourceTransaction` thêm admission marker read, poisoned marker precondition
và lazy prospective commit identifier. Admission marker được lấy sau source recovery
dưới exclusive gate; commit dùng đúng candidate đã capture trong body. Không đổi
journal/marker schema hoặc thêm file. Helpers reject escaped/wrong-thread use.
Candidate chỉ là receipt khi standalone call trả YES **và** đã stage source write;
no-op không advance marker. Code consumer mới đều stage trước capture candidate.

Private settings helper xuất exact primary receipt sau commit, trước notifications.
Public void save/setter giữ signature và legacy path. Verified setter dùng receipt
và `PXWriteSecurityBoolWithRollbackAuthority`: secondary merge vẫn commit/mirror
như cũ; chỉ xuất rollback authority khi admission marker trùng primary receipt.
Nếu có commit chen vào, BOOL vẫn acknowledge secondary write, authority nil. Không
borrow marker của successor từ readback sau callback. Khác identifier vẫn có thể
reenter và thành công; không reject mọi forward merge vì unrelated commit.

Khi verified apply fail sau primary acknowledgement, private compensation helper:

- Đọc current flag, kiểm tra exact marker/authority dưới cùng source gate trước
  staging. Mismatch hoặc nil authority abort, không writes/cache/notification.
- Stage riêng requested EnabledIdentifiers flag, StorageSystemEnabled nếu cần và
  optional secondary security flag trong **một** transaction. Merge existing maps;
  không save whole manager bag, không rewrite global scope hoặc unrelated flags.
- Nếu failure/conflict, adopt valid observed requested flag vào manager memory;
  malformed/unavailable value dùng captured previous-memory fallback. Không gửi
  success notification cho failed compensation. Forward error vẫn được giữ.
- Sau commit/release, cập nhật memory, clear caches và notify settings. Rollback
  security publisher kiểm tra marker trước và sau mirrors; stale publication bỏ
  secondary topic. H4Z token checks vẫn chặn same-instance reentry giữa callbacks.

Primary readback/secondary verification chỉ gọi boolValue cho NSNumber/NSString;
malformed plist scalar không còn nhận unsafe selector trong các checks này.

## Intentional behavior changes and limits

Error/conflict path bỏ stale compensation thay vì ghi đè cooperative successor.
Compensation primary/security nay atomic; settings observer thấy cả hai đã restore.
Rollback không còn flush unrelated uncommitted manager state/scope. Forward payload,
merge policy, topics và optional generation policy bình thường giữ nguyên; H5A
unacknowledged-primary path vẫn không source compensation.

CAS dùng global source marker nên conservative: commit không liên quan cũng có thể
revoke compensation authority. Forward thành công/readback trùng vẫn trả YES;
failure trả NO, giữ current sources, có thể còn partial primary/secondary state.
Caller cần xử lý lỗi/retry, không suy NO nghĩa là mọi source đã trở lại previous.
Previous vẫn là legacy captured manager bool, không phải canonical disk before-image.

Chỉ cooperative writers advance marker/join gate mới được bảo vệ. cfprefsd, raw
file writers, old binaries và manual edits ngoài gate không được biến thành CAS
participants. Per-manager mutable memory chưa thread-safe; captured/readopted value
có thể stale sau gate release. Không claim linearizable memory/cache/defaults,
full generation transaction hoặc nguyên tử giữa mirror và từng notification.
Mirror callback có thể làm remaining legacy suites stale; post-check chỉ chặn
secondary topic tiếp theo, không undo mirror đã chạy. Forward Darwin notification
vẫn là legacy invalidation signal; có thể phát sau newer source commit.

Không giữ source lock qua providers/mirrors/notifications; không retry-loop hoặc
busy wait. Exceptions giữ legacy propagation, committed source không tự undo khi
observer throw. Không chạm RootHide bootstrap/injection hoặc backup/restore service.

## Performance / lifecycle

Normal verified primary/secondary vẫn cùng số source commits như trước; marker read
tận dụng admission đang có, UUID capture reuse candidate của commit. Thêm local
string references/BOOL checks, expected cost negligible/low, chưa benchmark. Lazy
candidate tránh UUID allocation cho ordinary no-op admission.

Compensation dùng một commit cho primary/security, bỏ scope rewrite; rollback mirror
có hai read-only admissions/marker reads quanh mirrors. Error-path cost low/moderate
phụ thuộc flock/I/O; không khẳng định overall latency giảm bằng số thiếu benchmark.
Không thêm hot hook, queue, polling, timer hoặc retained callback. Transactions vẫn
không escape; receipts là immutable strings, token finally cleanup giữ nguyên.

## Verification

Group native recipe extract 55 actual IdentifierManager methods; source và security
fixtures chạy production implementations. Source fixture thêm cross-process marker
invalidation, second-store ABA, ignored-precondition poisoning, no-op candidate,
escaped/wrong-thread checks và physical-failure marker preservation. Security fixture
kiểm tra owned receipt, intervening commit revokes authority nhưng giữ merge,
mirror successor không bị borrow marker, stale publish skip và post-mirror recheck.

Group fixture kiểm tra foreign primary/ABA/malformed successors, successor sau
secondary commit, fault từng file của atomic compensation, rollback notification
successor, StorageSystem alias và scope byte invariants. H4Y/H4Z rollback fixtures
được đổi count/hook theo one-commit compensation và separate mirror phase; không
còn giả định rollback gọi một secondary writer riêng. Different-key success,
same-instance ABA, H5A failure/absence/late-writer cases tiếp tục chạy.

Windows verification: 62/63 Python suites và 4/4 Node suites pass. Suite bridge
retirement vẫn fail do Git Bash `mkdir /c/Users/ADMIN: Permission denied` (4 failures,
1 error, 1 skip trong 10 tests), cùng environment limitation đã có trước H5B.
Release source gate, RootHide metadata/negative controls 6/6, exact native fragments,
CHECK macro arity và git diff whitespace checks pass. Bốn in-memory negative
mutations bỏ rollback precondition, thay marker binding, bỏ chain ownership hoặc
bỏ post-mirror check đều bị source contracts bắt. Sau chỉnh capture BOOL thay vì
out-pointer trong save block, affected source/group contracts đã chạy lại pass.
Các checks này không thay cho native execution hoặc benchmark.

Native Foundation/Theos/package/device behavior vẫn cần CI macOS; host RootHide
define không chứng minh device injection. SourceStore post-marker exception/unknown
outcome policy chưa đổi: chỉ acknowledged successful staged write mới promote
receipt; memory observation vẫn là snapshot tại read point, không phải durable
post-failure/global memory guarantee. User-reported H5A build pass được ghi riêng.
