# 4C.2H4X — Standalone settings/scope publication boundary

Ngày 2026-10-29. Người dùng xác nhận H4W build pass trước bước này.

## Finding

Confirmed high-level API contract gap under nested use, severity Medium/P1, tại
`IdentifierManager.saveSettings` và `saveScopedApps`. Chúng dùng regular source
write, vốn cho phép join outer transaction rồi trả YES khi chỉ staging thành công.
Hai helper lại coi kết quả đó là committed và clear spoof/app-enabled caches,
notify settings changed; saveScopedApps còn sửa permissions trên scope file.

Reproduce: outer source transaction stage device_ids, gọi một trong hai helper,
rồi return NO, throw, hoặc nuốt inner failure. Trước patch, helper có thể phát
compatibility effects khi outer chưa commit; rollback bytes không undo notification
hoặc cache invalidation/permission side effect. Không kết luận mọi Reset hiện tại
đều gọi theo kiểu nested này: đây là confirmed unsafe composition của API, chưa
có device trace chứng minh tần suất thực tế. H3O/H4T đã áp dụng standalone rule
cho các high-level writer tương tự nhưng hai legacy helpers còn sót.

## Implementation

Đổi đúng hai calls sang `PXPerformStandaloneRuntimeSourceWrite`. Khi có active
outer transaction, source store reject trước khi chạy helper body và poison outer
staging. Helper đi vào existing error path (manager.error code 4006), return trước
permission repair/cache invalidation/notification. Outer không thể commit chỉ bằng
cách bỏ qua lỗi của void helper.

Regular nested low-level staging vẫn được source store hỗ trợ như trước. Không
đổi source gate implementation, new public API, schema, canonical toggle map,
storage alias, scope payload, top-level merge hoặc existing post-commit topics.
Direct saves vẫn commit settings/scope hoặc scope-only rồi publish sau gate release.

## Behavior boundaries

Thay đổi có chủ đích duy nhất: high-level save có compatibility effects không còn
được compose bằng implicit join vào outer transaction. Caller muốn compose phải
stage bằng transaction-aware helper và tự publish sau outer commit.

Existing directory preflight vẫn ở trước source admission: không claim mkdir/
directory permissions thuộc rollback hoặc bị chặn trước mọi preflight work. Scoped
file permission repair nằm sau success nên không chạy khi nested save bị reject.
Caller đã mutate in-memory settings/scopedApps trước save thì patch không rollback
candidate memory đó; chỉ giữ compatibility caches và notification khi source fail.

Giữ void signatures, error propagation và observer behavior cũ. Legacy boolean
wrappers suy success bằng persisted-value reads, stale manager.error trên một số
direct success paths, mutable manager concurrency, cache/defaults total ordering
và observer exceptions vẫn cần review riêng. Không claim mọi toggle acknowledgement
đã chuyển sang committed receipt.

## Performance và lifecycle

Direct-path gate/serialization/I/O không đổi; standalone admission chỉ thêm existing
active-transaction rejection policy, expected relative cost negligible. Nested use
không còn serialize/stage/publish rồi để outer rollback. Đây là correctness fix,
không có benchmark latency/CPU. Không thêm hook, class lookup, polling, timer, queue,
lock hoặc preference read. Existing source writer blocks vẫn dùng đồng bộ, không
thêm retain cycle hay lifetime owner mới.

## Verification

Group native recipe extract 45 actual IdentifierManager methods, thêm exact hai
save helpers; fixture cung cấp PXPreferencesPath và quan sát cả hai caches. Dùng
real SourceStore/Publisher; không thêm framework/source dependency. Profile recipe
giữ 53 ProfileManager + Profile model + 28 UI methods. Rootful/RootHide-defined
vẫn chạy ba executions/lane trong CI.

Fixture mới:

- Direct settings/scope save một commit, một notification; notification thấy scope
  đã commit và caches đã invalidate, existing source-gate probe chạy ngoài gate.
- Canonical flag sanitization, paired StorageSystemEnabled, SettingsInitialized,
  unrelated top-level fields; scope-only không thay settings bytes.
- Nested save với outer abort, swallowed failure và exception: code 4006, outer
  fail/poisoned, files/commit marker/caches/notification giữ nguyên; scope file
  mode 0600 không bị post-save repair đổi trước outer commit.
- Fault sau từng source file, gồm scope absence, rollback bytes/presence và marker
  trước compatibility effects.
- Malformed actual target source fail không repair/publish. Fixture khôi phục raw
  bytes trong finally rồi assert clean shared snapshot để không lặp lỗi isolation
  đã sửa ở H4T follow-up.

Windows local: 62/63 Python suites + 4/4 Node pass; bridge-shell còn lỗi quyền
`mkdir /c/Users/ADMIN: Permission denied` như trước. Exact extraction, CHECK macro
arity, source hardening, RootHide build/package static và diff checks pass.
Native Foundation/permissions/runtime, Theos/package và device H4X còn chờ macOS
CI; static/extraction pass không thay thế native verification.

## Separate backup roadmap finding

Đọc backup flow thấy createBackup lấy profileId rồi `_backupRoot` resolve active
profile lần nữa; profile appdata path còn có current lookup riêng. Điều này có thể
trộn attribution/root khi selection đổi. Chưa sửa service trong H4X: chương trình
backup/restore có gate riêng, STATUS đang mở TASK-4.4 Keychain identity và task kế
tiếp locked. Finding này được giữ để review đúng phạm vi, không đổi task spec,
STATUS hay implementation backup/restore trong audit patch này.

Manifest `4C.2H4X-partial`; toàn Patch 4/defaults authority/lifecycle/durability vẫn
partial. Patch 5–8 chưa triển khai.

Người dùng xác nhận H4X build pass ngày 2026-10-29 trước H4Y. Đây là kết quả build do người dùng báo; Windows không chạy native/package/device gate. H4Y xử lý riêng legacy toggle acknowledgement đã nêu ở trên.
