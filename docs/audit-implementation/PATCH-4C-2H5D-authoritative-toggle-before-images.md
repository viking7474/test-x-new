# 4C.2H5D — Canonical before-images for toggle compensation

Ngày 2026-10-30. Người dùng xác nhận H5C build pass trước bước này.

## Finding — confirmed bug, Medium / P1

Verified toggle capture `previous` từ manager memory. H5B CAS chứng minh source
version còn thuộc invocation nhưng không chứng minh memory trước gọi trùng canonical
source. Compensation dùng một BOOL đó cho primary, storage alias và security key.
Manager stale hoặc primary/security vốn khác nhau làm recovery ghi sai giá trị;
missing key bị materialize thành NSNumber, raw NSString bị normalize ngoài ý muốn.

Reproduce: canonical primary YES, security NO, manager memory NO; yêu cầu YES,
inject secondary failure. Old compensation ghi primary NO dù trước primary write
nó là YES. Tương tự primary NO/security YES/memory YES với yêu cầu NO. Sparse source
hoặc StorageSystem alias khác primary cũng bị thay presence/value khi recovery.
Đây là confirmed data-flow issue; chưa có device trace để kết luận tần suất.

## Implementation

Private Foundation helpers capture before-image **trong primary standalone source
transaction**, trước staging, sau provider phase. Packet chỉ giữ immutable scalar
và presence cho requested EnabledIdentifiers key, independent StorageSystemEnabled
nếu cần, optional secondary security key và security-file presence. NSNumber/NSString
giữ raw representation; absent có bit riêng. Malformed container/scalar fail closed
trước primary staging. Không serialize packet/NSNull marker ra source/journal schema.

Packet và receipt chỉ promote sau primary commit, trước notification. Verified
caller truyền packet tới conditional compensation. Nếu secondary được acknowledge
commit thì packet ghi nhận secondaryWritten. Source commit chain đã mất vẫn không
được bù, theo H5B; không dùng memory BOOL để tái tạo missing packet.

Compensation merge current maps và restore từng field từ canonical before-image,
remove field khi nó vốn absent. Primary/storage alias độc lập, không ép cùng BOOL.
Nếu security file vốn absent và map sau restore rỗng, stage removal để phục hồi
namespace tại source commit; existing empty file vẫn được giữ. Unrelated fields,
scope và top-level settings vẫn giữ boundary H5B, không whole-file undo.

Sau success, manager flag nhận normalized source bool hoặc xóa memory key nếu
canonical key vốn absent. Conflict refresh vẫn đọc valid current source; missing
current key được giữ missing trong memory. Unacknowledged primary chỉ restore
original memory scalar/presence, không materialize false và không ghi source.

`PXPublishSecurityValueForSourceCommit` giữ before/after marker checks, hỗ trợ raw
scalar hoặc remove defaults key. Existing BOOL publisher delegate với NSNumber.
Nếu security key vốn absent và secondary chưa commit/mirror thì validation-only,
không đụng legacy defaults fallback. Nếu secondary đã commit, removal mirror có
thể gỡ forward value. Topic/order và original forward error giữ existing policy.

## Intentional changes and limits

Failure path restore canonical field state thay vì stale memory và giữ absence/
representation. Malformed canonical input không còn được verified save silently
repair/overwrite; operation trả NO. Generic void saves vẫn giữ policy trước đó,
không yêu cầu packet. Public method signatures không đổi; chỉ private selectors
và một internal C publisher được mở rộng.

Đây là before-image của primary write, **sau providers**. Optional generation có
thể đã commit artifacts/flags riêng trước snapshot; không claim whole-toggle undo.
Primary forward vẫn flush legacy manager bag/scope; không giải quyết stale unrelated
forward fields. Parent container/SettingsInitialized do primary tạo không bị xóa
chỉ vì một target key vốn absent. Rollback chỉ owner-scoped fields.

Canonical source là đối tượng before-image; không capture prior object của từng
NSUserDefaults suite. Mirrors align với restored canonical scalar/absence, không
claim exact per-suite cache undo, cfprefsd authority hoặc global mirror ordering.
Default domains có thể persist lại namespace ngoài source gate. File absence chỉ
được bảo vệ tại cooperative source commit, không guarantee sau mọi daemon effect.
RootHide sparse-key inference vẫn giữ semantics hiện có khi canonical key absent.

H5B cooperative CAS và H5C acknowledged-marker policy giữ nguyên. Raw writers,
manager-wide thread safety, source/defaults total ordering và durability vẫn riêng.
Không thêm process injection, hot hook, generation hoặc backup/restore behavior.

## Performance / lifecycle

Primary dictionary đã được đọc; reuse nó để capture requested scalar/alias. Verified
WiFi/Battery/Theme cần thêm một security-file read trong existing gate để capture
consistent before-image, không thêm source admission/queue. Packet vài scalar/maps
sống trong invocation, không giữ cả manager/provider callback hay transaction.
Normal immutable scalar copies rẻ; relative cost low/moderate chủ yếu do extra read,
chưa benchmark. Generic save/non-secondary path không thêm security-file read.

Rollback/mirror chỉ ở error path; validation-only bỏ defaults work khi key vốn
missing và chưa bị secondary ghi. Không thêm timer, polling, worker, lock hoặc
source journal/schema. Không giữ gate qua defaults/observers; không retry-loop.

## Verification

Group recipe giữ 55 actual methods và thêm hai actual static helpers. Real source
store với controlled providers/security publisher; raw mirror semantics chạy qua
production security implementation và in-memory defaults backend.

Native scenarios: stale memory vs divergent canonical primary/security; NSString
representation; key absence; transient readback failure sau secondary commit với
existing-empty và absent security file; 3x3 independent storage primary/alias values;
malformed scalar/container rejection; provider commit trước primary admission;
missing packet fail closed; exact memory undo khi primary chưa acknowledge.

Security fixture kiểm tra validation-only giữ legacy fallback, removal cả configured
domains không source writes, raw string mirror và marker recheck sau removal reentry.
Existing H5B CAS/H5C post-marker acknowledgement fixtures vẫn thực thi cùng recipe.

Windows verification: 62/63 Python suites và 4/4 Node suites pass. Suite bridge
retirement vẫn fail do Git Bash `mkdir /c/Users/ADMIN: Permission denied` (4 failures,
1 error, 1 skip trong 10 tests), cùng environment limitation trước H5D. Release
source gate, RootHide metadata/negative controls 6/6, exact native fragments,
CHECK macro arity và git diff whitespace checks pass. Năm in-memory negative
mutations dùng memory thay canonical capture, restore BOOL thay raw primary,
materialize missing field, ép alias theo primary hoặc xóa untouched fallback
đều bị source contracts bắt. Source checks không thay native execution/benchmark.

Native Foundation/Theos/package/device behavior cần CI macOS; host RootHide define
không chứng minh device injection. User-reported H5C build pass được ghi riêng.


## Build follow-up — foreign-thread source fixture

User CI report: `source commit helpers reject wrong thread without poisoning owner`,
126/127 source checks. Finding is a test construction bug introduced with H5B:
`dispatch_sync(globalQueue, ...)` can execute on the submitting/owner thread, so it
was not a valid wrong-thread probe. Production checkCommitAccess correctly permits
that thread; short-circuit `&&` could also skip testing the prospective helper.

[Apple dispatch_sync documentation](https://developer.apple.com/documentation/dispatch/dispatchqueue/sync%28execute%3A%29-3segw?language=objc)
and [libdispatch queue.h](https://github.com/swiftlang/swift-corelibs-libdispatch/blob/main/dispatch/queue.h)
explain the current-thread execution optimization. No runtime thread guard is changed.

Fixture now submits async work, waits at most three seconds via semaphore, asserts
NSThread identity differs, independently tests require/base/prospective helpers with
non-nil errors, then validates the owner still succeeds and source snapshot/marker
is unchanged. Timeout paths do not read still-running worker result fields. The
worker touches only the immutable thread guard on rejection, retains its transaction
until it finishes, and uses a local autorelease pool.

Added a scoped source contract rejecting sync substitution/missing off-owner check;
SourceStore fixture is also enrolled in the existing CHECK macro-arity scan. Native
result remains pending macOS CI; Windows cannot reproduce Darwin inline scheduling.

Follow-up verification trên Windows: test_runtime_source_transactions.py,
test_profile_creation_flow.py, release_hardening.py source và git diff --check pass.
Ba negative mutations thay async bằng sync, bỏ thread identity hoặc bỏ independent
base-reader check đều bị source contracts bắt. Không chạy native Foundation trên
Windows; cần CI macOS xác nhận lại binary. Không thay production source/guard.
