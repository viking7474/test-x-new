# Patch 4C.2H4H — verified profile list and UI deletion

Người dùng xác nhận build H4G pass. H4H dùng source chung rootful/RootHide; bootstrap
priming, runtime hooks và source snapshot schema giữ nguyên.

## Findings và phạm vi behavior

High / P1: ProfileManagerViewController.trailingSwipeActions..., showDeleteConfirmationForProfile:
và deleteAllProfiles xóa thư mục trực tiếp, không unregister registry, không tham gia
lifecycle/delete journal và dựa vào active ID đã capture trước confirmation/batch.
Một profile có thể trở thành active hoặc có generation đang chạy trước lúc folder bị
xóa. Swipe còn gọi completionHandler(YES) khi removeItem thất bại. Đây là lỗi source
ordering rõ ràng; chưa có incident thiết bị được cung cấp.

Medium / P1: loadProfilesFromDisk có raw archive decoder riêng và fallback quét folder,
không dùng secure class/validation/recovery policy của manager. Folder/reservation hoặc
directory còn sau logical deletion có thể xuất hiện thành profile giả. intValue==0 còn
loại alphabetic IDs. UI enrichment sửa các model vừa load từ display files độc lập.

Behavior thay đổi có chủ đích: danh sách dựa vào registry đã được manager xác minh,
không tự import thư mục. Delete All chỉ xóa inactive registered IDs, giữ 0/profile_0,
orphans/reservations và IDs mới tạo sau snapshot. Không xóa dữ liệu legacy chưa đăng ký;
việc import/reconcile các folder đó cần workflow có bằng chứng riêng. Cần kiểm tra
upgrade với installations thiếu/corrupt registry; không dùng directory enumeration để
che lỗi load. Selected-profile recovery hiện có của manager vẫn được giữ.

## Thay đổi

UI loader gọi loadProfilesWithCompletion rồi dùng manager.profiles membership copy.
Giữ page đầu 10, search và exact 0/profile_0 exclusion; IDs hợp lệ khác không bị ép qua
intValue. Khi verified load fail, list rỗng thay vì đoán từ filesystem. Không gọi legacy
display enrichment trên manager models. Các legacy extraction/enrichment selectors
vẫn tồn tại, nhưng không tham gia loader mới.

Thêm deleteInactiveProfileID:completion: với shared delete admission. Nó resolve ID và
kiểm tra committed selection dưới lifecycle trước prepare/journal decision; active
target trả error 32. Existing deleteProfile: vẫn cho phép generic active deletion với
fallback như trước. Current-memory state hoặc dialog index không cấp quyền xóa.

Single button và swipe dùng một confirmation/adapter, stable copied ID, weak owner,
manager result và one-shot acknowledgement. Không remove local array/table rows theo
index cũ; reload verified list sau completion. Cancel/failure acknowledge NO, success
acknowledge logical unregistering. Delete swipe/canEdit dùng section 3 và bounds của
profile rows; nút delete kiểm tra tag trước access.

Trước physical cleanup, delete core đọc lại registry receipt và kiểm tra full expected
selection pair. Drift sau journal settlement giữ folder, set registryUnavailable và
trả partial failure để caller reload. Không phát success notification cho nhánh đó.
Directory replacement proof vẫn chạy khi receipts khớp. Physical cleanup failure khác
vẫn là best effort sau logical unregister; không tự retry trên reload.

Bulk API freeze copied registered IDs trên main. Mỗi item dùng inactive-only API,
reacquire/release lifecycle và kiểm tra active state mới. Yield qua main queue giữa
items; không giữ lifecycle suốt batch hoặc lặp retry. Protected/active/already-removed
targets được skip; lỗi khác được ghi một lần theo ID. Result immutable membership
arrays/dictionary chứa deleted/skipped/failed/error. New creations không nằm trong
snapshot. Explicit batch giữ manager/state tới completion; UI owner là weak reference.

UI xác nhận phạm vi registered-only và báo số logical removals/kept/failures, không
khẳng định mọi physical file đã được xóa. Batch không atomic: progress trước lỗi được
giữ, không rollback target/selection mới hơn. Không thêm orphan cleanup policy.

## Kiểm chứng

Native fixture extract 48 exact manager methods (gồm actual profiles getter và batch
state machine) cùng Profile model; vẫn hai schemes, ba executions/lane. Test mới dùng
namespace/store riêng và drain callbacks trước đổi/khôi phục root, giữ suite cũ nguyên.

- Membership chỉ gồm registered models; orphan/reserved directories không được adopt.
- Stale current memory và activation sau confirmation không vượt inactive-only guard.
- Decision source fault giữ raw registry/selection/directory và nhả lifecycle trước
  callback; success unregister trước cleanup, captured membership array vẫn giữ nguyên.
- Selection drift tại settled checkpoint giữ newly active folder, trả partial failure
  và explicit reload giữ target, không retry deletion.
- Bulk interleave activation và creation giữa items: live active, zero aliases,
  orphan/reservation và newly-created IDs đều còn; đúng một logical removal.
- Busy batch có một failure/ID và không mutate/retry; invalid registry dừng trước
  cleanup; background single deletion completion về main sau release.

UI source guards cấm raw delete/directory fallback/stale index removals trong các entry
points mới và kiểm tra ack theo kết quả. UIKit presentation, swipe dismiss/deallocation
và pagination/search interactions cần device tests; Foundation fixture không xác minh
UIKit runtime.

Local Windows: 62/63 Python suites và 4/4 Node suites pass. Remaining bridge migration
shell vẫn Permission denied `/c/Users/ADMIN`. Source hardening, RootHide build/package
metadata, source/macro/48-method extraction và diff checks pass. Native compile/runtime,
Theos/package và device H4H chờ macOS CI; không claim native pass từ source extraction.

## Performance, concurrency và giới hạn

Verified list bỏ raw UI decode/folder fallback/enrichment I/O; backend vẫn decode full
archive ở cold reload. Delete thêm một registry read và pair check trước cleanup.
Expected low/moderate checkpoint I/O, phụ thuộc archive/filesystem; chưa benchmark.

Bulk hiện chạy journal/encode/validation cho từng item trên main theo existing manager
contract. Yield giúp UI nhận events giữa items, không bảo đảm latency trong mỗi item.
Cost có thể high với nhiều profiles hoặc directory lớn; repeated full registry work
có thể gần quadratic theo số records khi xóa phần lớn list. So với raw background
folder sweep cũ, không khẳng định nhanh hơn. Async cleanup/batched journal cần protocol
và runtime validation riêng; không parallelize deletes để bỏ lifecycle ordering.

Lease bảo vệ cooperating writers; final receipt/directory checks vẫn là checkpoints,
không loại TOCTOU với non-cooperating rename/write sau check. Mutable model aliases,
other defaults/security writers, full directory durability, raw runtime readers và
rootful captured-reader rollout còn riêng. Manifest `4C.2H4H-partial`; toàn Patch 4
chưa hoàn tất, Patch 5–8 chưa triển khai.

Người dùng xác nhận build H4H pass ngày 2026-10-28. ID allocation được harden
riêng tại [H4I](PATCH-4C-2H4I-verified-profile-id-allocation.md); full UIKit/device
runtime matrix và toàn Patch 4 vẫn partial.
