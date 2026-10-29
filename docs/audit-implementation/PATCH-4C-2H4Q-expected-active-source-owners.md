# 4C.2H4Q — Expected active target inside source owners

Ngày 2026-10-28. Người dùng xác nhận H4P build pass trước bước này.

## Finding

Confirmed target-admission gap, severity High, giữa Reset UI checkpoint và các
current-target APIs của IdentifierManager. Generation/preview acquire lifecycle
đúng cách nhưng trước patch vẫn tự resolve profile hiện tại. Nếu B được chọn sau
UI check của A nhưng trước ownership, operation có thể resolve/migrate/write B.
UI check sau operation chỉ phát hiện muộn, không undo được source đã commit.

H4P cũng chỉ so ID ở UI; thay selection revision trong preparation chưa được gắn
với artifact commit. Reproduce bằng source selection B trước admission hoặc đổi
canonical/legacy record trong controlled provider callback. Không cần thay hook
hoặc giả định Foundation APIs gọi hàng nghìn lần/giây.

## Implementation

Thêm generation API `regenerateAllEnabledIdentifiersForExpectedActiveProfileID:error:`
và preview overload `applyDashboardPreview:expectedActiveProfileID:error:`. Reset
truyền frozen created ID từ H4P. Nil preview expectation giữ legacy behavior;
expected-generation API yêu cầu valid nonnil ID. Generic/current và explicit
inactive creation APIs giữ semantics cũ.

Expected owner sequence:

1. Validate/copy requested ID; acquire existing nonblocking lifecycle ownership và
   giữ pending-deletion/root guards.
2. Dưới source gate, capture canonical/legacy selection pair và yêu cầu authoritative
   ID còn bằng expected. Canonical presence được ưu tiên, chỉ missing canonical mới
   fallback legacy, theo policy H4J; không rewrite selection hoặc đoán profile zero.
3. Resolve/migrate đúng explicit expected directory dưới held lease. Không gọi
   current-target resolver/cache để chọn lại B. Existing no-follow directory proof,
   migration composition và artifact owner validation vẫn giữ.
4. Generation recheck pair trong basis capture trước providers, rồi trong final
   transaction trước staging. Preview recheck pair trong artifact transaction trước
   model/name/serial/storage staging. Pair comparison gồm values và file presence,
   không chỉ ID; new revision hoặc legacy-only change cũng abort.
5. Release ownership trước existing compatibility publication. Source success không
   trở thành rollback giả nếu callback sau commit lỗi.

Selection receipt chỉ là private in-memory condition, không thêm runtime schema,
artifact fields, C exports, locks, timer hoặc Makefile/library dependencies. Providers
vẫn chạy ngoài source gate. Public/private compatibility wrappers truyền nil proof;
generic calls không thêm selection I/O. Cold migration vẫn là phase có thể commit
trước candidate rollback như policy cũ.

UI giữ các H4P checkpoints cho gaps giữa commits/publication/feedback/restart. Preview
owner errors được propagate về UI; generic preview adapter và normal counter/random/
hardware/storage policy không đổi. RootHide constructor/priming và package runtime
không bị sửa.

## Verification

Group native recipe extract 35 actual IdentifierManager methods; UI/profile recipe
giữ 53 ProfileManager methods + Profile model + 25 controller methods. Các wrappers,
new admission/capture helper, owned target resolver và actual source staging bodies
đều compile trong group fixture, dùng real temporary SourceStore/lifecycle modules.
UI collaborators kiểm tra frozen expected ID được truyền xuống đúng API.

Cases thêm cho cả generation và preview:

- Source chọn B nhưng cached current resolver vẫn A: reject trước lookup, migration,
  providers, artifact writes/caches/notices; ownership được release.
- Busy lifecycle, invalid ID, NULL error output; invalid/absent selection không tạo
  default hoặc repair source.
- Source A nhưng cached resolver B: explicit A commit, không gọi current resolver
  hoặc chạm files của B. Mutable caller ID bị đổi trong provider không retarget.
- Raw target switch, same-ID revision change, A→B→A với new revision và legacy-only
  change trong preparation: toàn candidate abort trước commit/publication, giữ exact
  competitor source files. Provider vẫn thấy lifecycle đang held.
- Fault sau source write thứ hai rollback toàn candidate, không cache/notice effects.
- Legacy-only source fallback thành công mà không tạo canonical selection file.
- Existing generic/explicit/borrowed creation, dependency/telephony, preview rollback
  và post-commit callback tests vẫn nằm trong cùng recipes.

Local Windows: 62/63 Python suites + 4/4 Node pass. Remaining bridge-shell suite vẫn
lỗi `mkdir /c/Users/ADMIN: Permission denied`. Source hardening, RootHide build/package
static checks, exact extraction, CHECK macro và diff checks pass. Recipes giữ rootful
và RootHide-defined lanes, ba executions/lane. Native/Foundation/Theos, real DB/cache
publication và device H4Q cần macOS CI/thiết bị; extraction không phải native pass.

## Cost và remaining boundaries

Expected APIs thêm bounded pair reads/CAS vào existing ownership/source transactions:
generation có admission, basis và commit checks; preview có admission và commit
checks. Cost expected low/moderate theo file size/contention, chưa benchmark; không
hot-hook I/O hay polling. Giữ H4P UI checks làm tăng cold reads nhưng không optimize
dựa trên latency đoán. Generic paths chỉ thêm wrapper/conditional overhead negligible.

Mỗi artifact operation có expected-selection admission/commit; không giữ một lease
qua toàn Reset. Global required flags có thể đã commit trước rejection. A migration
có thể đã persist trước late source drift, nhưng không dùng B làm replacement target.
Value-equal restore của nguyên pair không thể phân biệt bằng receipt equality; đây
không phải universal monotonic revision hoặc raw-byte compare.

Cooperating source gate/lifecycle writers được coordinate; file writers bypass cả
contract vẫn ngoài guarantee. Cache/defaults/notification effects sau release còn
separate, đặc biệt preview compatibility caches chưa có total publication ordering.
Expected source APIs không pin feedback/restart hoặc active metadata/hardware capture
trước create. Backup/clear target, global scope authority, cross-instance admission,
owner cancellation, defaults/directory durability và daemon acknowledgement vẫn
partial. Manifest `4C.2H4Q-partial`; whole Reset và toàn Patch 4 chưa hoàn tất,
Patch 5–8 chưa triển khai.

Người dùng xác nhận build H4Q pass ngày 2026-10-28. Expected-preview cache
publication checkpoints được triển khai tiếp tại
[H4R](PATCH-4C-2H4R-preview-cache-publication-checks.md); global ordering/whole Reset
và device matrix vẫn partial.
