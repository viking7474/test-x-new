# Patch 4C.2H4A — profile display metadata update

Người dùng xác nhận build H3Z pass. H4A tiếp tục lifecycle/metadata boundary của
Patch 4 trên source chung rootful/RootHide; giữ bootstrap và injection hooks.

## Lỗi và tác động

`ProfileManager.updateProfileUnderLease:index:error:` gọi writeToFile bốn lần cho
profile Info.plist, appdata/Info.plist, identifiers.plist và scoped-apps.plist nhưng
bỏ qua toàn bộ BOOL results. Sau đó thay manager array/current slot rồi lưu registry.
Vì vậy registry save thành công có thể dẫn tới completion/notification success dù
một phần display files chưa ghi được. Scoped file hỏng còn tạo nil dictionary,
messages tới nil bỏ qua updates và không có error. Các writes không có rollback
nhóm. Đây là lỗi thực sự khi I/O/serialization thất bại, không phải benchmark hoặc
khẳng định thiết bị đã gặp lỗi này.

Reproduce trong fixture: fault sau từng file của nhóm, hoặc corrupt scoped plist.
Đường cũ không kiểm tra các return values; đường mới trả failure, giữ raw before
bytes/presence và không chuyển sang registry/memory success effects.

## Thay đổi

`PXWriteProfileDisplayMetadata` là Foundation helper nhận fields đã validate/copy,
mượn lifecycle lease đang có và pin existing profile root qua
`PXProfileArtifactMutation`. Borrowed root adapter không yêu cầu identity child,
không reacquire hay invalidate parent capability. Root/pending-deletion checks được
dùng lại từ artifact scope.

Appdata preflight dùng mkdirat/openat từ root descriptor, O_NOFOLLOW, pin appdata
descriptor và so device/inode với current path trước staging. Chỉ appdata thiếu
được tạo; không recursively recreate profile root đã mất. New appdata giữ mode 0755.
Descriptors và borrowed scope được nhả trong finally ở success/failure/exception.

Bốn dictionaries stage trong một source transaction. Scoped Apps/extra keys được
giữ, thiếu Apps vẫn thành empty array như trước. Các file khác vẫn thay whole
dictionary với legacy key casing/name/date fields. Corrupt source bị từ chối thay
vì silently repair. Outer standalone boundary ngăn high-level helper báo committed
success khi bị gọi trong một transaction chưa commit; inner artifact operation
thực hiện namespace/journal validation. Chỉ có một actual source commit.

Source allowlist thêm đúng ba leaf filenames và appdata/Info.plist dưới validated
profile ID, giữ canonical symlink resolution. Đây là ancillary display files,
không thêm runtime snapshot fields/schema. Creation/reservation và legacy profile
zero writers chưa chuyển sang helper này; manifest giữ artifact coverage partial.

Caller validate target/index, encode registry candidate trước mọi metadata write.
Sau metadata commit mới thực hiện registry byte/presence CAS. Chỉ registry success
mới cập nhật registry receipt, manager array/current slot và success notification.
Không thay active selection, scope hoặc terminate app khi edit metadata.

## Boundary còn lại

Display group và registry archive là hai commit phases riêng. Registry CAS/I/O
failure sau display commit trả failure, giữ manager slot/receipt cũ và không notify
success; display files mới vẫn còn. Không tự rollback archive mới hơn của writer
khác. Reload/retry là hành động explicit; không thêm auto repair hoặc delete.
Archive/source crash atomicity và whole update recovery chưa hoàn tất.

Caller có thể đã sửa một Profile object được manager chia sẻ trước khi gọi API;
late slot adoption không undo mutation đó. Không claim mọi live Profile objects
immutable/thread-safe hoặc full in-memory rollback. Initial appdata creation nằm
ngoài byte journal rollback, không tự xóa directory sau failure. Namespace checks
là checkpoints cho cooperating lifecycle writers, không khóa filesystem namespace
đối với bypass writers. Raw display readers không acquire source gate nên không
có bảo đảm atomic visibility giữa bốn reads. Không claim power-loss durability.

## Kiểm chứng và hiệu năng

Existing native profile fixture link actual metadata helper và artifact scope;
extract 33 exact production methods cùng Profile model như trước. Thêm explicit
helper header và standalone/path backend. Runner giữ rootful và RootHide-defined
lanes, ba executions mỗi lane; không cần UIKit shim/dependency mới cho helper.

Cases: fault sau mỗi file giữ bytes/presence, registry và manager slot; successful
single group commit cùng scoped extras, unchanged selection/termination policy;
registry drift sau display writes trả partial failure; corrupt scoped root;
registry encoding failure trước metadata; appdata symlink không ghi target;
borrowed root không yêu cầu/tạo identity child, không nhả parent lease; nested
high-level write rejection; missing root không recreate; expired lease và descriptor
counts sau success/rejection. Public completion/notification ordering dùng producer
oracle hiện có. Không chạy native cases tại Windows.

Local: 62/63 Python suites và 4/4 Node suites pass. Suite bridge migration shell
còn Permission denied `/c/Users/ADMIN` như trước. Source hardening, RootHide build/
package metadata, macro arity, extraction và diff checks pass. Native compile,
Theos/package và device H4A chờ macOS CI; chưa có native runtime pass cho patch này.

Expected cold-update cost moderate: vẫn bốn file writes và một archive, thêm journal/
commit và namespace checks. Archive encoding diễn ra một lần trước display I/O;
source gate không bao quanh encoding hoặc registry write. Operations vẫn synchronous
trên main theo policy cũ; chưa benchmark latency, không gọi đây là performance
optimization. Không thêm timer/network/queue hoặc hot hook work. Manifest rollout
`4C.2H4A-partial`; preferences authority, directory/registry durability, remaining
metadata producers, rootful reader rollout và toàn Patch 4 vẫn chưa hoàn tất.
