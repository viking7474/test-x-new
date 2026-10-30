# 4C.2H5C — Preserve an acknowledged source commit through housekeeping errors

Ngày 2026-10-30. Người dùng xác nhận H5B build pass trước bước này.

## Finding — confirmed contract bug, Medium / P1

`PXRuntimeSourceStore.commitTransaction:error:` coi marker là commit boundary,
nhưng `commit-written`/journal cleanup exception vẫn escape tới owner catch và
return NO. Exception từ `[self recover:NULL]` trong finally cũng override pending
return YES. Source tuple/marker có thể đã committed trong khi caller hiểu là fail,
không publish caches/mirrors hoặc không promote exact receipt. Với compensation,
memory có thể tiếp tục reflect forward state dù source đã được restore.

Reproduce: stage tuple + capture prospective identifier, inject NSException tại
`commit-written` hoặc housekeeping sau acknowledged marker write. Trước patch,
write API trả NO mặc dù committed marker và source tuple mới còn nguyên. Consumer
không thể phân biệt với pre-marker abort. Chưa có device trace chứng minh tần suất;
fixture fault injection xác định control-flow regression, không phải benchmark.

## Implementation

Local `markerCommitted` khởi tạo NO cho transaction đang commit. Chỉ set YES sau
`PXRuntimeWritePropertyList(commit, commitPath, ...)` trả thành công, trước mọi
post-marker checkpoint/cleanup. Commit catch rethrow nếu flag còn NO; nếu YES,
giữ successful outcome. Finally recovery có catch riêng, cùng rule: pre-marker
exception vẫn propagate tới owner để fail closed; post-marker housekeeping exception
không thay acknowledged result. Owner finally vẫn deactivate transaction, release
file lock và thread gate như trước.

Không suy success từ prospective candidate, old marker, transaction trước, global
flag hoặc readback ngoài gate. `PXRuntimeWritePropertyList` hiện close/rename rồi
return; local flag theo đúng return YES của marker writer. Không thêm marker read,
retry, callback hoặc source mutation để phân loại exception.

Write entry clear supplied NSError output trước admission. Failed paths vẫn ghi
failure; một successful call không giữ stale caller error từ lần trước. Điều này
chỉ áp dụng source write API output, không tự clear IdentifierManager.error hoặc
optional provider errors trên high-level success.

Thêm test-only checkpoints trước direct journal cleanup và finally recovery để
inject independently/cùng lúc. Release build không có các checkpoint calls này.

## Behavior boundaries

Thay đổi có chủ đích: acknowledged marker write trả YES xuyên qua later housekeeping
exceptions, đúng contract marker boundary đã có. Consumers được phép adopt receipt,
clear caches và publish compatibility effects sau return. Public signatures, source
allowlist, schema, tuple payload, journal validation và source lock order giữ nguyên.

Pre-marker body exception, physical source failure, failed marker rename và recovery
exception vẫn trả NO. Nếu recovery chưa xong, journal ở lại và capture fail closed.
Recovery exception có thể là failure được owner report thay vì original pre-marker
exception, theo existing policy; patch không thêm rollback retry loop.

Nếu cả cleanup attempts sau commit fail, valid matching journal có thể ở lại.
Capture vẫn validate toàn bộ journal và matching marker; subsequent writer xử lý
cleanup trước admission. Acknowledgement không đảm bảo housekeeping cuối cùng luôn
thành công hoặc future source corruption không xảy ra.

Đây là logical rename acknowledgement. Existing writer không thêm fsync file/dir,
nên không claim power-loss durability, complete distributed runtime publication,
cfprefsd authority, mirror ordering hoặc full multi-file writer enrollment. C signals,
process termination, raw noncooperative writers và high-level observer exceptions
ngoài source gate không được catch bởi rule này. Không chạm RootHide bootstrap,
injection scope, backup/restore service hoặc generation policy.

## Performance / lifecycle

Normal path thêm local BOOL và exception guards; expected relative overhead
negligible/low, chưa benchmark. Existing cleanup/recovery attempts không tăng;
không thêm file read/write, lock, queue, polling, timer hoặc production logging.
Không thêm retained callback/global last-result state. Marker flag sống đúng một
commit invocation, nên committed transaction cũ không thể acknowledge body mới fail.

## Verification

Production SourceStore được native fixtures dùng trực tiếp. Source cases bao phủ
commit-written/direct-cleanup/finally exception, hai cleanup faults cùng lúc để
giữ matching journal, exact receipt/new tuple, không restore committed sources,
nil error output, second-store capture/write chứng minh gate release và cleanup
ở subsequent owner. Candidate + throwing body sau earlier commit vẫn fail.

Negative cases: source write + recovery cùng throw giữ pending/unavailable; retry
phục hồi old tuple. Marker rename failure được tạo bằng directory tại marker path,
không dựa vào chmod/root behavior; finally teardown restore exact marker bytes/mode
rồi kiểm tra recovery. Fixture dùng riêng generated temporary directory.

Security fixture kiểm tra source acknowledgement, exact rollback authority và cả
ba mirror domains sau post-marker fault. Group fixture kiểm tra verified toggle
commit cả primary/secondary, không spurious compensation; compensation đã commit
vẫn publish restored tuple và giữ original forward error. Group extraction giữ
55 actual methods; SourceStore/security fixtures không dùng mock commit algorithm.

Windows verification: 62/63 Python suites và 4/4 Node suites pass. Suite bridge
retirement vẫn fail do Git Bash `mkdir /c/Users/ADMIN: Permission denied` (4 failures,
1 error, 1 skip trong 10 tests), cùng environment limitation trước H5C. Release
source gate, RootHide metadata/negative controls 6/6, exact native fragments,
CHECK macro arity và git diff whitespace checks pass. Bốn in-memory negative
mutations bỏ marker acknowledgement, pre-marker rethrow, finally rethrow hoặc
write-entry error reset đều bị source contracts bắt. Rà existing testCheckpoint
callbacks không thấy callback bỏ qua phase filtering; stages mới không thay old
phase names. Source checks không thay native execution hoặc benchmark.

Native Foundation/Theos/package/device behavior cần CI macOS; host RootHide define
không chứng minh device injection. User-reported H5B build pass được ghi riêng.

Người dùng xác nhận H5C build pass ngày 2026-10-30. H5D xử lý canonical scalar before-images cho compensation; marker acknowledgement của H5C giữ nguyên. Đây là build do người dùng báo, không phải native execution từ Windows.
