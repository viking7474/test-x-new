# 4C.2H4Z — Identifier toggle reentry and stale rollback

Ngày 2026-10-29. Người dùng xác nhận H4Y build pass trước bước này.

## Finding — confirmed unsafe flow, Medium / P1

`IdentifierManager.setIdentifierEnabledAndPersist:forType:` giữ `previous` của
invocation cũ rồi rollback không kiểm tra xem callback có gọi một toggle mới trên
cùng manager hay chưa. H4Y xác nhận được kết quả từng lần ghi nhưng không trao
ownership cho các lần gọi lồng nhau. Vì primary notification và security mirrors
chạy đồng bộ sau source commit, đây là reentry boundary thực sự trong control flow.
Chưa có device trace để kết luận tần suất lỗi ngoài thực tế.

Reproduce: WiFi ban đầu NO; gọi verified NO; primary notification gọi verified
YES trên cùng manager. Inner commit primary/security YES. Outer readback mismatch
và rollback về captured NO, ghi đè newer intent. Nếu inner đổi NO rồi YES để final
value khớp outer, value comparison cũng không phân biệt được ABA: outer có thể
tiếp tục secondary publication. Reentry giữa các bước rollback còn có thể gây
stale security write/notification hoặc ghi đè manager.error của successor.

## Implementation

- Tạo bare NSObject token cho mỗi invocation, lưu trong private dictionary theo
  immutable identifier key. New token thay thế old token; inner completion không
  phục hồi token cũ. So identity thay vì bool nên bắt được ABA.
- Void setter và verified setter cùng tham gia. Verified setter truyền cùng token
  qua private apply overload, giữ ownership tới hết verification/rollback.
- Kiểm tra token quanh current-value/provider phase, trước settings save, sau
  primary notification, sau secondary writer và secondary notification. Khi bị
  supersede, dừng các bước kế tiếp, trả NO; private error output dùng code 6035.
- Verified wrapper kiểm tra trước final verification và trước rollback. Nếu
  successor xuất hiện trong rollback primary notification thì bỏ secondary rollback;
  nếu xuất hiện trong secondary writer thì bỏ stale notification. Shared forward
  error chỉ được ghi khi token vẫn current, giữ shared error của newer invocation.
- `@finally` ở cả hai owner wrappers dọn đúng token của mình, kể cả provider hoặc
  observer throw. Old cleanup không thể revoke token mới. Bare token không retain
  manager; completed keys được xóa khỏi registry.
- Hai UI switch handlers và auto-enable caller đồng bộ switch về trạng thái
  hiện tại của manager sau NO, thay vì đảo bool của old request. Status labels/
  colors cập nhật theo switch; legacy label lookup dùng một presentation helper
  chung cho manual/auto paths, giữ first matching tag 100. Không chạy tiếp
  success-only identifier value refresh khi verified call trả NO.
- `@synchronized(self)` chỉ bao get/set/remove token map. Không giữ lock qua source
  I/O, provider, defaults mirror hoặc notification; không thêm chờ callback/queue.

## Behavior boundaries

Normal non-reentrant payload, generator selection, storage alias, settings/security
write acknowledgement, readback guard, notification topics và best-effort rollback
giữ nguyên. Different identifiers trên cùng manager không supersede nhau.

Thay đổi có chủ đích: cùng identifier gọi lại sẽ supersede invocation cũ, kể cả
successor cuối cùng có cùng bool value hoặc successor fail. Older call trả NO và
không tự rollback successor. Đây là invocation ownership policy, không khẳng định
successor đã commit. Invalid input được reject trước admission như H4Y.

Không sửa được cross-instance/process/direct source writers hoặc cfprefsd: chúng
không tham gia token map. Mutable manager state và check-to-write gaps chưa
thread-safe toàn cục; map lock chỉ bảo vệ registry. Không claim CAS/linearizability,
full artifact atomicity, global UI event ordering hay global defaults/cache authority.
Provider đã chạy có thể đã commit artifacts; token chỉ ngăn bước tiếp theo sau
provider return, không hủy hoặc rollback công việc đang chạy bên trong provider.
Notification đã phát trước reentry không thể thu hồi. Observer exception policy
vẫn propagate; source đã commit không bị tự động undo khi observer throw.

Primary/security vẫn commit riêng. Direct source write trong observer được
existing readback guard phát hiện nếu bool thay đổi; rollback path đó chưa có CAS.
Không chạm backup/restore service/task spec, RootHide bootstrap hoặc hook scope.

## Performance / lifecycle

Đây là cold UI/settings path. Thêm một token allocation/invocation, một dictionary
lazily allocated/manager, và các short token-map lock/checks; relative cost low,
chưa benchmark. Success path không thêm preferences read, IPC hoặc file write.
Superseded call bỏ bớt remaining reads/writes/notifications. Không thêm hot hook,
timer, polling, worker queue, object observer hoặc retain cycle.

## Verification

Group native recipe extract 53 actual IdentifierManager methods, thêm apply overload
và ba token helpers; real source store/publisher, controlled providers/security
collaborator, intercepted Darwin delivery như H4Y. Cả rootful và RootHide-defined
macOS host lanes chạy ba lần theo existing CI recipe.

Fixture cases: same-key primary observer successor giữ exact newer snapshot/cache/
shared error; ABA; different-key success; provider successor ngăn older settings
commit; secondary failed/success return callback; successor ở primary/secondary
rollback; secondary notification successor; provider/observer exception cleanup;
stale finish không xóa token mới; completed registry empty; bare token không giữ owner.
H4Y acknowledgement/fault fixtures tiếp tục kiểm tra normal success/failure policy.
Source guards kiểm tra cả ba UI failure/resync paths; UIKit runtime behavior cần
CI/device, không thuộc Foundation host fixture.

Windows verification: 62/63 Python suites và 4/4 Node suites pass. Suite bridge
retirement vẫn fail do Git Bash `mkdir /c/Users/ADMIN: Permission denied` (4 failures,
1 error, 1 skip trong 10 tests), cùng environment limitation trước H4Z. Release
source gate, RootHide metadata/negative controls 6/6, exact native fragments,
CHECK macro arity và git diff whitespace checks pass. Bốn in-memory negative
mutations (ABA identity comparison, stale cleanup, rollback-secondary guard và
provider-to-save guard) đều bị source contracts bắt. Các source checks không thay
cho native execution hoặc benchmark.

Native Foundation/Theos/package/device behavior chờ CI; không suy RootHide device
pass từ host compile define. User-reported H4Y build pass được ghi riêng.
