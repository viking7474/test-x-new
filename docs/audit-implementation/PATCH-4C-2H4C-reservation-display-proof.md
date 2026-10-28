# Patch 4C.2H4C — reservation metadata preflight and display proof

Người dùng xác nhận build H4B pass. H4C kiểm tra remaining creation-reservation
metadata path trên source chung rootful/RootHide; không đổi hooks hoặc bootstrap.

## Vấn đề và quyết định

`PXProfileCreationReservation.reserveProfileID:inProfilesDirectory:metadata:error:`
cũ tạo profile/identity directory và marker trước khi serialize display metadata.
Input metadata sai kiểu hoặc không serialize được có thể fail sau khi đã chiếm ID,
để lại reservation không dùng được. Đây là defect về ordering với malformed input;
không khẳng định UI bình thường đã tạo loại input đó trên thiết bị.

`validateWithError:` chỉ kiểm tra directory/identity/ownership marker. Display file
identifiers.plist có thể bị xóa, thay inode hoặc sửa tại chỗ trong lúc create đang
pending mà mọi checkpoint vẫn coi ownership hợp lệ. Kết quả có thể register/activate
profile với metadata khác initial create record. Đây là rủi ro khi có file drift,
được kiểm tra bằng controlled mutation trong native fixture, chưa là device incident.

Reservation đã dùng descriptor-relative O_EXCL writes, kiểm tra return values và
không adopt existing directory. Giữ contract này; không thay bằng generic source
transaction vốn không bảo đảm exclusive initial creation. H4C là preflight/proof
hardening, không enroll exclusive reservation writes vào shared source journal.

## Thay đổi

Factory clear NSError output, validate root types/ID/path rồi serialize metadata
thành legacy XML bytes trước filesystem side effects. Decode immutable record để
validate chính bytes sẽ được ghi: DisplayName và matching Identifier là strings,
Description là optional string, extra fields vẫn nhận valid plist values. Bad
types, mismatched IDs, unsupported values hoặc serialization exceptions trả error
trước mkdir. Không đặt length limit hay thay name/description generation policy.

Marker cũng serialize trước mkdir. Exclusive writer nhận sẵn NSData, dùng đúng bytes
đã prepare cho cả writes và proof, không serialize lại dictionary theo order khác.
Không thay XML format, reserved marker state, operation identity hoặc mode 0644/0755.

Reservation giữ thêm display descriptor và NSData snapshot. Validation so regular
file, inode/device, single-link và size với current leaf rồi so raw bytes của cả
marker/display. Missing file, inode replacement dù cùng bytes, symlink, same-size
content mutation, truncate, hardlink hoặc extension làm reservation invalid.
Comparison dùng 4096-byte stack buffer, pread/EINTR loop và EOF probe; không allocate
full-size mutable buffer mỗi checkpoint. Thêm string.h cho memcmp declaration.

Các create/finish/activation checkpoints hiện có tự nhận display proof mới; không
thêm queue, timer hoặc callback. Display FD đóng trong dealloc cùng bốn FD cũ; NSData
không giữ callback/self cycle. Malformed preflight không giữ descriptors/reserve ID.

## Kiểm chứng

Existing native fixture link actual reservation module và 35 exact manager methods
như H4B, giữ rootful/RootHide-defined lanes và ba executions/lane. Không thêm native
recipe dependencies. Eight-process exclusive reservation, root/identity/marker drift
và existing lifecycle cases vẫn giữ nguyên.

Cases mới: chín malformed metadata inputs fail trước directory/marker; mutable ID,
name/description/extra container đổi sau factory không đổi persisted/proof bytes;
bảy display mutations ở trên; payload nhiều chunks với mutation cuối file; success/
rejection descriptor counts trở về baseline. Integration sửa display sau generation
và trong termination adapter, yêu cầu completion failure, unchanged active selection
và không publish cache/defaults/success notification. Failure sau generation không
ghi registry/terminate; failure sau registry/termination có thể giữ inactive entry,
không activate. Reserved directory vẫn được giữ, không auto cleanup.

Local Windows: 62/63 Python suites và 4/4 Node suites pass. Suite bridge migration
shell vẫn Permission denied `/c/Users/ADMIN` như trước. Source hardening, RootHide
build/package metadata, macro/diff checks và 35-method/model extraction pass. Native
compile/runtime, Theos/package và device H4C chờ macOS CI; không claim native pass.

## Performance và giới hạn

Cold reservation thêm một XML decode và giữ một display NSData + FD trong reservation
lifetime (năm FD thay vì bốn). Checkpoint thêm stat/pread work theo metadata size;
expected low cost với display labels thông thường, có thể moderate với payload lớn,
chưa benchmark. Bounded comparison tránh thêm full-payload allocation mỗi lần, không
biến cả operation thành constant-memory: prepared NSData vẫn tỷ lệ payload size.
Một số checkpoints nằm dưới source gate, nên metadata lớn vẫn có thể tăng hold time.

Proof là checkpoint detection, không ngăn bypass rename/write sau check hoặc bảo đảm
một filesystem snapshot khi có concurrent non-cooperating writers. Marker reserved
vẫn không chứng minh ready/orphan và không cấp quyền xóa directory. Partial physical
write/failed create vẫn có thể để directory/file; patch chỉ loại preflight-invalid
side effects. Không tự sửa metadata hoặc rollback archive mới hơn.

Snapshot byte proof không làm Profile objects bất biến: caller mutation của object
được chia sẻ trong async create vẫn là boundary riêng. Current record proof chỉ xác
nhận display file khớp initial serialized metadata, không claim mọi model/cache có
global order. Shared source capture, registry/directory durability, defaults authority
và rootful reader rollout vẫn partial. Manifest `4C.2H4C-partial`; toàn Patch 4 chưa
hoàn tất.
