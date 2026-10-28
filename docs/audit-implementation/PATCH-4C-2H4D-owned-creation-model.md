# Patch 4C.2H4D — owned creation model and registered switch aliases

Người dùng xác nhận build H4C pass. H4D tiếp tục mutable-model boundary trong
asynchronous create trên source chung rootful/RootHide; giữ bootstrap và hook setup.

## Lỗi và thay đổi

Create cũ capture một Profile caller-owned qua worker rồi dùng chính object đó cho
registry và activation. Target ID đã copy nhưng name/description/icon/dates/settings
vẫn mutable. Caller sửa chúng khi worker pause có thể làm registry/selection khác
initial display metadata. H4C xác nhận bytes của file, không xác nhận object caller
vẫn cùng state. Đây là logical lifetime issue khi input đổi sau admission, không
phải khẳng định thiết bị đã có một concurrent-property crash.

Thêm `detachedProfileForCreation:expectedID:error:`. Sau khi assign ID/timestamps cho
caller như trước, create secure-archive/decode một Profile riêng trước reservation
hoặc provider dispatch. Dùng cùng allowed classes của registry decoder (kể cả nested
Profile, dates/data/collections), không thay bằng plist-only settings policy. Decoder
error, unsupported graph, wrong decoded root/target hoặc invalid name fail trước
filesystem effects; exception thành NSError, ownership nhả trước completion.

Reservation metadata, fixed target và finish/registry/activation dùng owned model.
Worker không đọc properties của caller input; queued operation không giữ input model
ngoài những reference caller tự capture trong completion. Caller edits sau snapshot
không được ghi đè ngược và không thay operation đang pending. Không ép caller object
về captured state khi hoàn tất. Input ID/timestamps vẫn có thể đã assign nếu capture
thất bại, tương tự preflight/reservation failure cũ.

Public create API không trả Profile qua completion. Các UI call sites được kiểm tra
dùng ID và gọi switch với input object sau success. Để giữ flow đó, switch resolve
registered record theo exact validated ID trước mọi lastUsed/archive/activation work.
Alias fields không đổi registered metadata; unknown/invalid IDs vẫn error 21 và không
persist. Caller dùng explicit update API nếu muốn sửa metadata.

Điều này cũng sửa legacy alias switch: trước đây lastUsed đổi trên alias trong khi
saveProfiles encode manager array khác, nên timestamp đó không được persist đúng.
Giờ canonical registered object được update/rollback theo existing save result, và
active memory/selection dùng cùng record. Normal same-object switch, same-target
termination/notification policy và ID semantics được giữ.

## Kiểm chứng

Existing native profile fixture extract 36 exact manager methods và actual Profile
coding model, giữ rootful/RootHide-defined lanes, ba executions mỗi lane. Không thêm
native dependency hoặc private API. Source checks kiểm tra secure class policy,
snapshot-before-reserve, worker không đọc input và canonical switch ordering.

Cases mới: khi worker pause, đổi mutable name/description/icon, dates, readonly ID qua
test KVC, nested arrays/dictionary/data và nested allowed Profile, rồi thay settings
root. Creation vẫn hoàn tất theo captured ID/values; display/registry/selection và
generation đồng nhất, caller edits vẫn giữ trên input. Kiểm tra deep isolation của
nested Profile để không vô tình siết settings sang plist-only schema.

Thêm alias switch với fields khác và lastUsed cố định: current record phải là canonical
object, archive giữ canonical fields/timestamp, alias không bị sửa và same-target
không terminate thêm. Unregistered alias không persistence effects. Weak input dealloc
khi worker đang pending nhưng owned creation vẫn hoàn tất. Unsupported settings fail
trước reserve/provider/registry/publication và callback thấy lifecycle đã release.

Local Windows: 62/63 Python suites và 4/4 Node suites pass; suite bridge migration shell
vẫn Permission denied `/c/Users/ADMIN` như trước. Source hardening, RootHide build/
package metadata, macro/diff checks và 36-method/model extraction pass. Native compile/
runtime, Theos/package và device H4D chờ macOS CI; không claim native pass từ Windows.

## Performance và phạm vi

Thêm một secure archive/decode trên main ở cold admission trước existing final registry
encoding. Expected CPU/allocation cost moderate, có thể high với settings graph lớn;
chưa benchmark. Có thể giữ cả input graph và owned graph trong lúc caller còn giữ
input. Không giữ serialized buffer như một cache lâu dài. Early capture chọn correctness
thay vì background-read một mutable object; không thêm queue, timer, polling hoặc hook work.

Main handoff vẫn diễn ra trước capture: off-main input được giữ tới admission trên main.
Caller phải synchronize mutation trong chính lúc capture; snapshot không sửa data races
của mọi nonatomic Profile property. Sau khi manager register/expose owned record qua
getters, external edits/reentrant callbacks trên record đó vẫn là boundary riêng. Các
Profile objects không được chuyển thành immutable toàn cục; arbitrary custom coding/
cyclic input graphs cũng chưa có một ownership/validation model mới ở đây.

Directory/artifact/registry/selection vẫn là các phases có receipts riêng. Không tự
rollback registered inactive profiles hoặc orphan reservations. Defaults authority,
post-registration mutable state, archive/source crash atomicity và rootful reader
rollout vẫn partial. Manifest `4C.2H4D-partial`; toàn Patch 4 chưa hoàn tất.

## Follow-up — deletion archive value comparison

CI compile thành công nhưng native rootful chỉ đạt 423/451. Fail đầu tiên ở inactive
deletion, sau đó active delete, drift/recovery và legacy timestamps bị kéo theo.
Không phải lỗi nullability warning hay package scheme.

H4D giữ một legal nested Profile trong registry settings để kiểm tra secure class
compatibility. Deletion validator decode Before/After riêng, rồi dùng NSArray/
NSDictionary.isEqual cho settings. Profile không override isEqual/hash, nên nested
instances có cùng persisted fields vẫn bị coi là khác do object identity. Prepare
deletion bị reject trước checkpoint mong đợi, gây các failure/callback lệch nhịp sau
đó. Đây là bug production của validator được fixture mới làm lộ, không sửa bằng cách
xóa nested Profile test hoặc thu hẹp allowed secure classes.

Thêm private registry value comparer: giữ Foundation primitive/key equality và
ordered-array/dictionary-value rules, nhưng so sánh Profile theo ID, name, description,
icon, settings và dates. Nested Profile dùng cùng before-missing/after-present timestamp
provenance policy như root validator. Object-pair memo dùng pointer personality để
tránh collection hash recursion và terminate value/container cycles. Memo chỉ thuộc
một comparison; không override global Profile equality hoặc tạo cache lâu dài.

Giữ nguyên exact one-profile removal, selected target presence, top-level metadata/
dates, raw archive CAS, journal schema và recovery ownership checks. Không thay Before/
After bytes hoặc replay authority. Dictionary key semantics vẫn theo NSDictionary;
đây là sửa value comparison, không thêm một normalized-key policy.

Native regression gọi actual validator với hai archive chứa cùng nested values,
rồi thay lần lượt bảy nested fields (ID/name/description/icon/createdAt/lastUsed/
settings) và yêu cầu reject. Thêm memo reset và cyclic container equality/inequality
cases; giữ nguyên toàn bộ integration delete/recovery fixtures đã fail. Comparator
work/allocation tăng theo visited graph pairs ở cold delete/recovery, chưa benchmark;
không chạy trên hook hot path hoặc dưới source gate của commit/notification.

Host: 62/63 Python + 4/4 Node pass, lỗi còn lại là bridge-shell Windows permission
như trước; source hardening, RootHide build/package, macro/diff và 37-method extraction
pass. Native rerun sau fix vẫn chờ macOS CI; không báo native delete/recovery pass từ
Windows.

Người dùng xác nhận build deletion-comparer follow-up pass ngày 2026-10-28.
Selected-model proof sau registration được triển khai riêng tại
[H4E](PATCH-4C-2H4E-activation-model-proof.md); giới hạn thread-safety và tổng
source/defaults/durability model vẫn partial.
