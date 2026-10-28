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
