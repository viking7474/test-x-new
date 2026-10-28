# 4C.2H4L — Reset profile request snapshots

Ngày 2026-10-28. Người dùng xác nhận H4K build pass trước bước này.

## Findings

Hai correctness edge cases, severity Medium, tại
`TLinkIOSViewController.m`, `createNextProfileAndRandomizeWithWarnings:`:

- Options lấy thẳng từ strong property; preview giữ dictionary/string từ UI hoặc
  provider. Callback create/switch có thể đọc nội dung đã đổi sau khi request được
  gửi. Copy container nông vẫn chia sẻ mutable values. Đây là missing isolation
  có thể tái hiện bằng mutable caller/provider; chưa đo tần suất trên thiết bị.
- Success gán `self.nextFakePreview = nil` vô điều kiện. Preview/options được thay
  hoặc sửa trong lúc create pending có thể bị completion cũ tiêu thụ nhầm.

Reproduce: giữ create pending, sửa mutable options hoặc provider preview, rồi cho
callback tiếp tục; hoặc gán một preview/options mới trước callback success.
HUD có thể hạn chế tương tác thông thường nhưng không bảo vệ programmatic updates
hoặc aliases của payload. Không kết luận mọi lần Reset đều có lỗi.

## Implementation

`captureResetIntentWithOptions:preview:error:` serialize rồi decode immutable
binary property list của cả hai dictionary. Detached strings và nested containers
không còn dùng chung với caller. Nil options/preview thành empty dictionary,
giữ defaults ở consumers và giữ unknown property-list fields. NSNumber/NSString
vẫn hợp lệ cho ba bool flags và hai model indices; container/date/data ở những
scalar positions bị từ chối trước boolValue/integerValue. Wrong root hoặc payload
không serialize được trả NSError, kể cả exception; NULL error output vẫn hợp lệ.

Profile-preparation entry chụp `submittedIntent` trước khi đọc flags hoặc gọi
preview providers. Sau random preview và hardware-preservation bước cũ, chụp
`preparedIntent` lần nữa trước allocation/create, vì provider có thể trả mutable
strings/containers. Async completion chỉ dùng final detached options/preview.

`discardConsumedResetPreviewForIntent:` chạy trên main, chỉ clear preview khi live
options và preview còn bằng giá trị packet ban đầu. Preview mới khác giá trị hoặc
options đã đổi được giữ, kể cả in-place mutation; existing persistence tiếp tục
ghi live selections. Empty submitted preview không được dùng để clear một preview
mới sinh trong lúc create pending. Không rollback hoặc reselect target.

Giữ nguyên random/model/iOS/storage policy, nil defaults, required identifiers,
create/switch/regenerate/preview order và H4K failure gates. Không đổi bootstrap,
hook/runtime schema, package dependency, timer hoặc notification success path.

## Verification

Existing native profile recipe extract hai helper mới: tổng 53 ProfileManager
methods + Profile model + 9 controller methods. Controlled fixture kiểm tra:

- Deep detach mutable flags, range/model strings, array/dictionary extras.
- Nil/default input, recognized scalar type rejection, wrong roots, non-plist
  object, NULL error output và preserved unknown date/data fields.
- Equal packet consumption; replaced preview/options và in-place mutations được
  giữ; nil baseline không tiêu thụ newer preview.
- Final provider preview/options được sửa sau capture nhưng queued preparation
  vẫn dùng captured model và storage flags.
- Off-main consumption không đọc/mutate pending UI intent.

Đây là exact-helper fixture với controlled collaborators/queued consumption;
không chạy full UIKit create/reset/device pipeline. Source guards chứng minh hai
capture sites nằm trước flag reads/providers và allocation/create, cùng conditional
consumption sau H4K success. Existing native recipe có rootful và RootHide-defined
lanes, ba executions/lane, không thêm source/framework dependency.

Windows: 62/63 Python suites và 4/4 Node pass; bridge-shell suite vẫn lỗi
`mkdir /c/Users/ADMIN: Permission denied`. Source hardening, RootHide build/package
static checks, exact extraction, CHECK macro và diff checks pass. Native compile,
Foundation behavior, Theos và UIKit/device H4L chờ macOS CI/thiết bị.

## Cost và remaining boundaries

Hai encode/decode passes trên cold create path, cost O(payload size), thêm detached
graphs/data tạm thời. Expected low với options/preview nhỏ; payload lớn có cost cao
hơn và chưa benchmark. Đây là isolation fix, không phải latency optimization.
Không thêm polling, timer, lock hoặc I/O; serialization chỉ ở memory.

Capture bắt đầu tại profile-preparation phase, sau backup/clear hiện tại. Chưa chụp
toàn bộ app lists/RRS notes/options từ lúc tap, chưa ngăn overlap giữa hai Reset.
Value equality không phải request revision: thay packet rồi đổi về cùng giá trị
không được phân biệt như newer intent. Không serialize concurrent mutation đang
xảy ra trên thread khác, không claim arbitrary cyclic object-graph support.

Callback controller ownership, target pinning/supersession giữa các commits,
directory/defaults authority/durability và daemon distribution acknowledgement
vẫn riêng. Clear/app/profile/toggle effects đã commit trước lỗi không bị rollback.
Manifest `4C.2H4L-partial`; whole Reset và toàn Patch 4 vẫn partial, Patch 5–8 chưa
triển khai.
