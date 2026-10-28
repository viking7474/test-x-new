# Patch 4C.2H4B — default profile seed

Người dùng xác nhận build H4A và bản sửa absence snapshot fixture pass. H4B tiếp tục
seed profile 0 trên source chung rootful/RootHide; bootstrap hook registration và
snapshot cold priming không đổi.

## Lỗi và thay đổi

`createProfileZeroImmediately` cũ ghi identifiers.plist trực tiếp, bỏ qua BOOL rồi
seed device_ids.plist bằng một source transaction khác. Identity seed lỗi vẫn log
"Immediately created". Explicit createProfileZero tiếp tục bootstrap/reload dù seed
không thành công. Namespace preflight dùng recursive path creation và không kiểm
tra plain child directories; profile/identity symlink có thể bị follow.

Thêm verified `createProfileZeroWithError:` và Foundation helper
`PXSeedDefaultProfile`. Owner lấy nonblocking lifecycle capability trước preflight,
helper validate đúng configured profiles root và pending deletion, rồi giữ ownership
qua source commit. Success log chỉ sau commit và explicit lease release. Legacy void
selector vẫn synchronous để giữ init/caller contract, log failure qua verified API.
Explicit createProfileZero dừng trước bootstrap/load khi seed lỗi; init vẫn có thể
tiếp tục restore một active selection hợp lệ như trước, không abort toàn manager
chỉ vì optional zero-directory repair thất bại.

Preflight tạo đúng missing 0/identity qua mkdirat/openat từ held descriptors, không
recursively recreate profiles root. Existing profile proof được so device/inode,
child symlinks/non-directory bị từ chối. Borrowed artifact scope pin identity và
recheck profile/identity descriptors cùng pending journal trước staging. Finally
đóng scope/FDs ở mọi return; parent lease vẫn thuộc caller khi dùng helper trực tiếp.

Một standalone source commit stage legacy Default display record và chỉ stage
empty device_ids khi file chưa tồn tại. Existing identity dictionary được đọc để
validate nhưng không serialize/write lại, giữ raw bytes và keys. Corrupt display
hoặc IDs root làm toàn seed fail, không repair ngầm. Không tạo appdata/scoped-apps,
không đổi selection/registry/cache hoặc thêm notification/termination. Plain Default
display label vẫn được ghi theo policy cũ, kể cả khi profile 0 đã tồn tại; không
đổi semantic reset tên mặc định trong migration này.

Bỏ Profile object/NSDate local không được dùng trong payload. Root mới giữ mode
0755; identity chmod 0755 như legacy preflight. Display chmod 0644 là best-effort
post-commit compatibility effect, không phủ định primary commit đã acknowledged.
Source allowlist/schema không cần mở rộng vì hai paths đã được enroll trước đó.

## Kiểm chứng

Existing profile-flow native fixture link actual helper, extract 35 exact manager
methods cùng Profile model, giữ rootful/RootHide-defined lanes và ba executions mỗi
lane. Helper header/dependency được ghi rõ trong recipe. Default snapshot oracle
dùng exists + bytes, không dùng NSNull trong plist-only capture; kiểm tra nonnil
before fault matrix, tiếp tục bảo vệ absence regression đã sửa ở H4A.

Cases thêm: one commit với existing IDs byte preservation; failure sau từng file
khôi phục cả hai file absence; missing IDs phải decode thành valid empty dictionary;
corrupt display/identity không partial repair; busy acquire không side effects/leak;
borrowed/expired capability; pending deletion; explicit create không bootstrap/load
khi seed fail; profile/identity symlinks không ghi target; missing root tạo đúng legacy
directories/files; selection/archive, notifications, termination, manager slots giữ
nguyên và FD counts quay về baseline.

Local Windows: 62/63 Python suites và 4/4 Node suites pass. Suite bridge migration
shell còn Permission denied `/c/Users/ADMIN` như trước. Source hardening, RootHide
build/package metadata, macro/diff checks và exact 35-method extraction pass. Native
compile/runtime, Theos/package và device H4B chờ macOS CI; không claim native pass.

## Performance và boundary còn lại

Cold seed thêm journal/commit cho display record (trước đây chỉ identity miss đi
qua source stage); expected I/O cost moderate, chưa benchmark. Initial/repeated seed
vẫn synchronous. Không thêm timer, polling, network, queue hoặc work trên hot hook.
Giảm allocation local thừa là tác dụng phụ nhỏ, không phải performance claim chính.

Directory creation và identity chmod preflight nằm ngoài source byte rollback;
failure có thể để directories trống, không tự xóa hoặc adopt orphan reservations.
Display mode repair ở sau commit. Namespace checks là checkpoints giữa cooperating
writers, không phải isolation chống mọi bypass rename. Raw legacy readers không
acquire source gate nên không claim multi-file atomic visibility. Directory/source/
registry crash durability, creation reservation path, defaults authority và rootful
reader rollout vẫn là boundaries riêng. Manifest enroll default-profile-seed với
rollout `4C.2H4B-partial`; toàn Patch 4 chưa hoàn tất.
