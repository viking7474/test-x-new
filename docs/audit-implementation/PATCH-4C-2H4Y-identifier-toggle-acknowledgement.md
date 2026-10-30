# 4C.2H4Y — Identifier toggle write acknowledgement

Ngày 2026-10-29. Người dùng xác nhận H4X build pass trước bước này.

## Finding — confirmed bug, Medium / P1

`common/IdentifierManager.m`, `setIdentifierEnabledAndPersist:forType:` gọi void
setter rồi suy success từ primary và secondary persisted values. Khi giá trị cũ
đã trùng requested value, source write hoặc security write có thể fail nhưng
readback vẫn trùng và API trả YES. H4X standalone rejection cũng có thể gặp false
acknowledgement này khi caller dùng high-level toggle trong outer transaction.

Reproduce: seed IDFA=NO, inject settings/scope commit failure, gọi verified setter
NO. Hoặc seed WiFi primary/secondary=NO, chỉ fail secondary forward write, gọi NO.
Trước patch, matching readback đủ để trả YES. Tác động: UI/caller bỏ qua persistence
failure, stale scope hoặc paired state chưa được cập nhật, nested caller có thể
tưởng save thành công. Không có device trace để kết luận tần suất thực tế.

## Implementation

- Private `saveSettingsWithError:` trả trực tiếp standalone write result, giữ
  directory errors, existing payload/merge/storage alias, cache invalidation và
  notification order. Public void `saveSettings` delegate tới helper này.
- Private `applyIdentifierEnabled:forType:error:` giữ nguyên generation branches,
  model fallback và primary-before-secondary order. Primary failure return NO
  trước secondary write, kể cả khi old primary value đã trùng. Secondary failure
  cũng return NO trực tiếp; nil secondary error có fallback error.
- Public void setter delegate tới apply helper. Verified BOOL setter yêu cầu
  invocation-local write success **và** existing primary/secondary readback checks.
  Không dùng shared manager.error như last-write result: nó có thể stale hoặc bị
  callback thay đổi. Không xóa legacy shared error trên direct success.
- Giữ readback sau primary notification: synchronous observer có thể đổi primary
  trước secondary. Khi đó older invocation không được publish secondary như thể
  primary vẫn trùng. Verification mismatch trả error 6033.
- Copy caller type trước providers/callbacks; giữ original forward error qua
  best-effort rollback. Rollback failures vẫn log; rollback success không đổi NO
  thành YES. Public signatures không đổi.

## Behavior boundaries

BOOL chứng minh required settings và secondary writes thành công cùng readback
policy hiện có; không chứng minh optional generation thành công hoặc complete
artifact atomicity. Generation vẫn chạy trước settings như cũ. Primary/settings
và secondary/security vẫn là các commit khác nhau. Primary notification vẫn có
thể chạy trước secondary failure; rollback vẫn có compatibility notifications.

Rollback chưa có concurrent-writer CAS, có thể ghi đè newer intent; đây là existing
potential issue, chưa được giải quyết bằng receipt boolean. Mutable manager state
chưa thread-safe. Không claim coherent defaults daemon authority, global cache
ordering hoặc nguyên tử giữa source commit và callback. Observer exceptions vẫn
propagate theo legacy policy; patch không bổ sung catch-all hoặc rollback artifacts.

Nil/nonstring/empty type được reject trước mutation. Unknown nonempty string vẫn
qua legacy sanitizer/readback policy; không mở rộng canonical toggle namespace.
Directory preflight vẫn ngoài byte rollback. Không chạm backup/restore service,
RootHide bootstrap, injection filter, dependency package hay hook scope.

## Performance / memory

Success path không thêm disk read/write: giữ readback checks, source transactions
và topics hiện có. Thêm private method call, local BOOL/error và string copy
(immutable NSString thường chỉ retain): relative cost negligible/low, chưa benchmark.
Failed primary bỏ secondary forward work; failed matching-value operations nay
đi vào rollback cũ nên có thêm error-path I/O so với false-success trước đây.
Không thêm polling, timer, queue, lock, hook hoặc ownership cycle.

## Verification

Native group recipe extract 49 actual IdentifierManager methods, gồm hai private
helpers và hai public setters; real SourceStore/Publisher chạy cả rootful và
RootHide-defined host lanes, ba lần mỗi lane. Fixture controlled providers giữ
existing-value branches; IDFA missing-value path có callback mutate caller key.
Security collaborator dùng real standalone source commit, controlled failure,
không chạy defaults daemon; Darwin notification được intercept để assert topics
và gate release. Thêm explicit CoreFoundation host link dependency.

Các cases: fault mỗi primary source dù old value trùng; secondary failure dù old
value trùng cho WiFi/Battery/DeviceTheme; rollback success giữ forward error;
stale shared error không phủ nhận local success; primary failure skip secondary;
nested ignored failure poison outer; notification reentry đổi primary ngăn older
secondary publication; mutable key isolation; void setter existing-value policy;
storage alias; invalid inputs. H4X cache/byte/token/permission/corruption fixtures
vẫn chạy qua void wrapper mới.

Windows verification: 62/63 Python suites pass; chỉ bridge-retirement shell fixture
fail với `mkdir /c/Users/ADMIN: Permission denied` (4 failures, 1 error, 1 skip trong
10 tests), cùng environment limitation đã có trước H4Y. 4/4 Node suites pass.
Release source gate, RootHide metadata/negative controls 6/6, native fragment
extraction, CHECK macro arity và git diff whitespace checks pass. Ba in-memory
negative mutations bỏ verified receipt, primary receipt hoặc secondary failure
return đều bị source contracts bắt. Những checks này không thay native execution.

Native Foundation,
Theos packaging và device behavior chưa được chạy tại đây; CI cần xác nhận H4Y.
Không suy RootHide device support từ host `-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1`.
