# Patch 4C.2H4I — verified, collision-aware profile ID allocation

Người dùng xác nhận build H4H pass. H4I dùng source chung rootful/RootHide; không
đổi bootstrap priming, hooks, profile archive format hoặc runtime snapshot schema.

## Findings

Medium / P1, confirmed logic defects trong ProfileManager.generateProfileID:

- Mọi nonnumeric folder bị đưa vào alpha ordering. Với 999/A01 và z-foreign,
  parser có thể quay về A01 đã tồn tại, làm create fail lặp lại.
- Plain file hoặc dangling symlink trùng ID kế tiếp không được tính là occupied.
  Reservation vẫn bảo vệ khỏi overwrite, nhưng allocator cứ trả cùng candidate lỗi.
- Read/enumeration exception hoặc missing root fallback về 1, che lỗi nguồn thay
  vì báo rằng chưa thể xác minh namespace. Đây không phải overwrite đã chứng minh:
  existing exclusive reservation vẫn là barrier cuối cùng.
- Sau Z99, char increment sinh prefix ngoài A..Z thay vì failure rõ ràng. Empty
  string/Unicode decimal và narrow intValue cũng tạo parser boundary không rõ;
  không giả định một giá trị overflow cụ thể khi chưa chạy native.

Các findings dựa trên source flow và controlled fixtures mới, chưa có incident
thiết bị được cung cấp cho allocator này.

## Thay đổi

generateProfileIDWithError: là read-only candidate API trên main. Nó mượn existing
lifecycle capability của create hoặc acquire một owner tạm cho standalone preview.
Configured-root validation và pending-delete gate chạy trước inventory; raw registry
receipt phải khớp manager receipt nếu có, rồi qua shared decodeRegistryRecord:error:.
Read failure/corruption/stale receipt/busy trả nil + NSError, không đoán ID.

Lease inventory enumerate qua held root: openat(".") + fdopendir/readdir/fstatat
AT_SYMLINK_NOFOLLOW. All leaf names chiếm chỗ; chỉ plain directories tham gia sequence
basis, không follow child symlinks. Registered IDs vẫn chiếm chỗ khi directory thiếu.
Independent directory stream tránh shared offset của dup; finally đóng stream, không
invalidate borrowed parent. Inventory không tạo/xóa/adopt profile directories.

Ordering dùng một max scan và NSSet occupancy, thay numeric/alpha sorts cùng boxed
intValue comparator. Giữ numeric precedence tới 999; ASCII leading zeros và numbers
lớn được parse với cap trước multiplication. Nhánh alpha chỉ nhận A01..Z99. Other
custom IDs vẫn đọc/switch/edit bình thường và chiếm exact names, nhưng không định
nghĩa alpha ordering. Không renumber hoặc xóa legacy IDs.

Candidates được probe bằng actual filesystem namespace, no-follow leaf check, để
xử lý case/normalization aliases và entries mới xuất hiện sau inventory. Probe là
synchronous borrowed callback: mỗi candidate tối đa một lần, không rescan basis,
poll cùng ID hoặc follow/delete blocker. Probe error dừng ngay. Numeric/alpha scan
có bound rõ; khi hết đuôi sequence, trả error 33, không sinh prefix sau Z. Không
thêm UUID/AA01 policy hoặc tự backfill gaps trước maximum của nhánh đang dùng.

Legacy generateProfileID giữ selector, trả nullable candidate và log failure. Create
gọi verified API và chỉ assign caller ID/timestamps khi allocation thành công. Failure
trước bước này không reserve directory, chạy provider hoặc thay selection. Candidate
không phải reservation: O_EXCL factory vẫn quyết định ownership; late collision vẫn
trả existing error 13, không overwrite/retry không giới hạn.

Rà tracked call sites bằng git grep: hai create dialogs dùng nullable, nonbinding
preview text; auto-profile naming trả allocation error thay vì tạo Auto (null).
createNextProfileAndRandomizeWithWarnings: handoff main trước mutable state/UI work
nếu caller off-main, giữ copied warnings. Preview và actual creation vẫn là hai
admissions riêng, nên một candidate preview không bảo đảm actual assigned ID.

## Kiểm chứng

Native profile fixture extract 52 exact manager methods + actual Profile model;
actual lease implementation đã nằm trong recipe. Giữ rootful/RootHide-defined,
ba executions/lane; không thêm native source dependency.

- Pure matrix: numeric priority, 999/A01, A99/B01, Z98/Z99, exhaustion, leading
  zeros/huge ASCII, foreign/Unicode names và occupied numeric/alpha gaps.
- Probe progression/error: distinct attempts, không rescan discovery hoặc retry
  cùng candidate; namespace errors propagate ngay.
- Isolated filesystem: plain files, dangling/live directory symlinks, missing
  registered directory, actual filesystem case policy và blocker-byte preservation.
- Repeated borrowed inventories giữ cùng membership, parent ownership và FD count;
  expired/busy capability và missing root fail không recreate/fallback.
- Stale/unreadable registry fail qua shared policy; create completion thấy lifecycle
  release, caller ID/dates và active files giữ nguyên, provider chưa chạy.
- Collision sau discovery nhưng trước reservation vẫn bị O_EXCL từ chối; exhausted
  sequence giữ mọi dữ liệu. Off-main allocation bị từ chối trước namespace access.

Source guards kiểm tra UI caller handling, phase ordering, no-follow/FD cleanup và
native CHECK arity. UI preview/Reset Data adapters chưa được runtime-test bằng UIKit
trong Foundation fixture. Local Windows: 62/63 Python suites và 4/4 Node suites pass;
bridge-shell migration vẫn Permission denied `/c/Users/ADMIN`. Source hardening,
RootHide build/package metadata, source/macro/52-method extraction và diff checks
pass. Native compile/runtime, Theos/package và device H4I chờ macOS CI.

## Performance và giới hạn

Sequence discovery giảm từ sorting O(N log N) sang scan O(total ID characters), bỏ
NSNumber comparator churn. Inventory vẫn stat mỗi leaf và decode full registry;
standalone preview thêm lifecycle/pending-delete checks. Expected cold CPU/I/O cost
low/moderate, có thể high với namespace/registry lớn; chưa benchmark tổng latency.
Candidate scan tối đa 3573 sequence positions, actual probes chỉ chạy cho tên chưa
bị exact occupancy loại; không có busy polling, timer, network hoặc hot-hook work.

Memory O(namespace + registry graph), temporary directory/read descriptors đóng
trước return. Không cache candidate hoặc giữ lease qua dialog. Lease serialize
cooperating writers; inventory/probe không tạo filesystem snapshot và không loại
TOCTOU với bypass writers. Exclusive reservation cùng later registry/proof checks
vẫn bắt buộc. Filesystem entries không biểu diễn/đọc được gây failure để retry thay
vì được bỏ qua âm thầm.

Generated sequence kết thúc ở Z99 khi đã vào alpha branch; existing custom prefixes
vẫn hợp lệ theo existing decoder. Cần kiểm tra installations dùng naming tùy biến,
missing registry và busy preview trên thiết bị. Whole Reset Data orchestration,
remaining producers/defaults/security authority, cleanup/durability và rootful reader
rollout vẫn partial. Manifest `4C.2H4I-partial`; toàn Patch 4 chưa hoàn tất.

Người dùng xác nhận build H4I pass ngày 2026-10-28. Manual creation caller
acknowledgement được chuyển tại [H4J](PATCH-4C-2H4J-manual-creation-acknowledgement.md);
full UIKit/device runtime matrix và toàn Patch 4 vẫn partial.
