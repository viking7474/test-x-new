# Patch 4C.2H3B — lifecycle ownership, registry CAS và ordered delete

Người dùng xác nhận build H3A pass. H3B triển khai phối hợp các ProfileManager instances/processes và sửa delete đang xóa directory trước khi cập nhật committed selection/registry. Native/build H3B cần macOS CI; full lifecycle recovery và Patch 4 chưa hoàn tất.

## Vấn đề đã sửa

- `creationInProgress` trước đây chỉ thuộc một instance. Một manager khác có thể load/save/delete trong lúc worker create đang generate; reload trên chính manager đang create cũng có thể thay mutableProfiles. Exclusive mkdir của H3A không serialize các registry edits ở ID khác nhau.
- `saveProfilesWithCompletion:` trước đây atomic-replace archive từ memory nhưng không so với archive đã load. Atomic rename không ngăn stale manager ghi mất profile do manager khác vừa thêm/sửa.
- Delete trước đây remove directory ngay, bỏ qua lỗi filesystem, remove object theo pointer, đổi current pointer trong memory và lưu archive. Canonical/legacy selection và defaults vẫn có thể trỏ vào profile đã mất; save failure xảy ra sau irreversible removal. Caller đưa Profile object khác cùng ID cũng có thể làm registry và directory lệch nhau.

## Ownership và registry

`PXProfileLifecycleLease` mở configured profiles root và `.profile-lifecycle.lock` với CLOEXEC/NOFOLLOW, kiểm tra regular/single-link/current-owner lock và lấy exclusive flock **nonblocking**. Root alias được giữ; child/root/lock inode checks phát hiện replacement tại checkpoints. Lease acquisition thất bại trả busy code 12 hoặc invalid/conflict code 25, không retry/poll/wait main thread.

Create/update/switch/delete giữ lease từ trước mutation đến cuối operation; async create giữ ownership trong manager qua worker. Load giữ lease khi đọc/decode/reconcile registry và từ chối chạy đè một operation đang pending. Raw selection/metadata writers, activation và bootstrap/seed-zero dùng ownership tương ứng; ephemeral writers không mượn lease của operation khác chỉ vì cùng instance. Lock order là **lifecycle lease → source transaction**; không acquire lifecycle lease từ source block.

Registry basis là exact NSData + existence, detached khỏi Profile objects. Begin operation so basis đã load với disk; save recheck trước atomic write và đọc lại bytes vừa ghi. Stale instance phải reload; không merge hoặc rollback archive của producer khác. Activation recheck registry basis sau external adapters; delete recheck registry trước cleanup và giữ files nếu producer ngoài lease đã đổi archive. Reader reject symlink/nonregular/multiple-link registry và archive IDs malformed/duplicate, giữ nguyên file lỗi. Các private legacy force-selection/default helpers chuyển sang create/load/bootstrap flows đã được guard, không tự ghi selection/defaults riêng.

Lease có explicit invalidate khi operation kết thúc, trước notification/completion. Factory dùng retained return convention, ephemeral leases có precise ARC lifetime; không dựa vào autorelease-pool drain để quyết định lúc nhả flock. Dealloc/process exit đóng descriptors. Preparation/update/delete/load exceptions có boundary nhả ownership; user completion nằm ngoài exception-catching body để không bị gọi lần hai nếu chính callback raise.

## Delete flow và failure semantics

1. Resolve registered profile theo ID, kiểm tra last-profile guard và registry basis. Capture directory device/inode/absence cùng selection pair. Committed selection quyết định profile active, thay vì mutableCurrentProfile có thể stale.
2. Nếu target active, chọn remaining profile đầu tiên có identity directory hợp lệ; source CAS commit canonical/legacy fallback rồi adopt memory/defaults. Giữ policy delete không terminate app hoặc randomize identity/version.
3. Sau đó unregister target và lưu archive bằng byte CAS. Save failure giữ target trong memory/registry và giữ toàn bộ directory. Fallback đã commit vẫn có thể active; API trả NO/error, phát settings notification cho selection thực sự đã đổi và không rollback selection.
4. Trước physical cleanup, so lại full selection pair. External drift thì giữ files, chỉ restore registry replacement của operation này nếu byte CAS vẫn match; conflict với registry khác không được overwrite và yêu cầu reload. Không bù selection bằng state cũ.
5. Cleanup cuối cùng chỉ dùng exact child ID và directory proof. Target bị replace thì giữ replacement. Như contract API cũ, cleanup failure không biến committed logical deletion thành rollback; ghi log, không tự retry một stale path.

Crash sau fallback nhưng trước unregister giữ old profile và directory, selection vẫn hợp lệ. Crash sau unregister nhưng trước cleanup để inactive directory chưa được registry tham chiếu; ID scan tránh reuse khi directory còn tồn tại. Load không adopt hoặc delete directory này dựa vào `state=reserved`: marker H3A có thể tồn tại cả sau một create đã active thành công. Đây là **ordered safety**, không phải atomic directory/archive/source transaction hoặc durable delete journal.

## Giới hạn còn lại

Lease chỉ bảo vệ cooperating producers. Binary cũ, direct external source writes và non-lifecycle artifact writers chưa nhận ownership này. Writer bỏ qua lease có thể đổi namespace/selection sau checkpoint; inode checks không tạo isolation xuyên suốt recursive removal hoặc path-based generation. Byte compare + rename cũng không phải atomic CAS đối với producer bỏ qua lease. Các tests cố ý bypass lease để giữ coverage selection drift/ABA và compensation safeguards.

Metadata sidecars trong update vẫn ngoài source journal; archive failure không rollback toàn bộ metadata files/edited object properties. Main-thread archive/read/cleanup I/O vẫn có. Defaults/security authority, cross-process cache ordering, rootful reader rollout và device matrix vẫn partial. Không có fsync/power-loss durability claim. Bước tiếp theo cần durable lifecycle/reconciliation contract và enrollment của remaining producers trước orphan cleanup tự động.

## Performance và kiểm chứng

Không thêm hook, timer, polling hay worker queue. Có thêm hai held descriptors trong thời gian lifecycle operation và các archive reads/byte copies để chống lost update; expected cost **moderate trên cold profile operations**, phụ thuộc archive size, chưa benchmark. Flock conflict trả ngay; source gate không bị giữ qua generation, archive encode, external adapters, notifications hoặc filesystem cleanup. Lưu một archive basis làm tăng memory của mỗi manager theo archive size; không đưa công việc này vào hot hook.

Native fixture link lease production, extract **31 exact production methods** và giữ real source transactions/NSKeyedArchiver/temp-directory IO. Thêm process lease contention/release, stale-manager rejection, reload/raw writer exclusion trong pending create, raw byte CAS, symlink/lock replacement, active/inactive/delete-by-ID, selection fault rollback, synchronous preparation exception, archive-encoding failure sau fallback, external selection/registry drift sau unregister, cleanup replacement, duplicate archive IDs và conservative restart. Test file-manager hook chỉ inject ở post-archive permissions step trong fixture; adapters không terminate app thật.

Host Windows: **11/11 source gates liên quan pass**, production fragment extraction (31 methods) và `git diff --check` pass. Gates cũ được cập nhật từ lifecycle pending sang partial, giữ dashboard/security/preferences pending và không nâng thành enrolled. Không có xcrun/Foundation/Theos local nên **native fixtures mới và build H3B chưa chạy**; macOS CI hiện có chạy rootful + RootHide, ba lượt mỗi variant.

## Trạng thái sau H3B

Người dùng đã xác nhận build H3B pass. [H3C](PATCH-4C-2H3C-delete-decision-recovery.md) bổ sung decision journal/replay; encoding failure chuyển về trước selection commit, còn post-commit I/O failure có pending recovery. Device matrix riêng vẫn cần kiểm chứng.
