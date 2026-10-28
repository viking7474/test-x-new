# Patch 4C.2H3Z — storage preference writer

Người dùng xác nhận build H3Y pass. H3Z tiếp tục writer còn pending trong manifest:
`StorageManager.setStorageSpoofingEnabled:`. Source chung áp dụng cho rootful và
RootHide; bootstrap/injection/hook registration không đổi.

## Vấn đề và phạm vi

Setter cũ đổi `_isEnabled` trước, gọi setBool/synchronize trên suite settings và
không có acknowledgement cho caller. Khi persistence lỗi, cache vẫn báo giá trị
mới. Writer bypass source gate trong khi IdentifierManager và runtime generation
cũng ghi cùng physical settings file. Getter/setter scalar không có synchronization
nếu gọi từ nhiều threads. Đây là defect khi persistence thất bại và concurrency
risk khi có nhiều callers, không phải bằng chứng một crash/overlap đang xảy ra.

Inspection không tìm thấy direct in-repository callers ngoài declaration và
implementation của hai status selectors; selector callers ngoài repo vẫn có thể
tồn tại. Không gọi writer này là active hot-path bottleneck. Primary UI/identifier
toggle có đường ghi riêng. RootHide storage hook ưu tiên
`EnabledIdentifiers.StorageSystem`; rootful có legacy secondary/defaults và
IdentifierManager fallback. Patch không hợp nhất các policy này hoặc tự ghi thêm
primary toggle.

## Thay đổi

Thêm verified overload `setStorageSpoofingEnabled:error:`. Nó merge đúng legacy
top-level key `StorageSystemEnabled` qua standalone source transaction, giữ các
settings khác và từ chối corrupt root. Không tạo profile, không lấy profile lease,
không đổi scope/primary identifier flags hoặc thêm notification.

Cache chỉ đổi sau primary commit. Legacy void API gọi overload và log failure;
source failure giữ cache cũ, suppress compatibility mirror. Canonical suite vẫn là
`com.hydra.tlinkios.settings`, dùng setBool/synchronize sau source unlock như trước.
Mirror exception được log nhưng không biến primary commit thành aborted result.
Source write không được join một outer transaction rồi chạy mirror sớm.

Per-instance admission flag từ chối overlap/re-entry với NSError busy trước source
entry. Guard giữ hiệu lực qua cache adoption/mirror và được clear bằng finally.
Object monitor chỉ bảo vệ admission/scalar operations, không bao quanh source I/O,
mirror hoặc logging callbacks. Getter lấy cùng short monitor nên có thể đọc cache
trong lúc worker đang mirror. Không thêm queue, timer, dispatch_sync hoặc retry.
Caller nhận busy có thể gọi lại sau; void caller chỉ có failure log. Đây là thay
đổi có chủ ý để thay concurrent cache/mirror interleaving bằng lỗi rõ ràng.

## Kiểm chứng

Existing artifact preparation fixture extract exact ba status method bodies, dùng
actual source engine và temporary settings file; controlled defaults adapter tránh
ghi host preferences. Source header và path/standalone backend được cung cấp rõ
ràng. Runner hiện có compile cả rootful/RootHide-defined lanes, ba lần mỗi lane;
không thêm dependency SDK/private API.

Cases: một source commit trước cache/mirror; key/suite và primary/unrelated fields
giữ nguyên; không thêm notice; fault sau source write giữ exact file bytes/cache và
không mirror; admission release sau failure; void success/failure; mirror exception
vẫn acknowledged commit; nested high-level writer rejection; rollback original
absence; missing source tạo đúng một legacy key; corrupt source không repair; reentry
từ mirror fail busy; concurrent caller bị từ chối khi mirror đang chờ và getter vẫn
đọc được; request sau completion được chấp nhận.

Windows local: 62/63 Python suites và 4/4 Node suites pass; suite bridge migration
shell còn Permission denied `/c/Users/ADMIN` như trước. Source hardening, RootHide
build/package metadata, macro arity và diff checks pass. Sáu artifact production
fragments generate được. Native compile/runtime, Theos/package và device H3Z chờ
macOS CI; source checks không thay thế native concurrency hoặc device evidence.

## Performance và giới hạn

Setter vẫn synchronous trên calling thread. Journal/commit thêm I/O so với chỉ
defaults setter; expected cost moderate ở cold write, chưa benchmark. Không giữ
monitor rộng để đổi source latency thành getter contention. Admission/getter scalar
guard cost thấp; không có bằng chứng cần lock-free publication hoặc async dispatch
cho API chưa thấy direct callers. Storage generation/profile artifact writers và
hook hot paths giữ nguyên.

Per-instance ordering không bao phủ các StorageManager instances khác hoặc
IdentifierManager/process khác. Source gate serialize cooperating primary writes,
nhưng cache/mirror sau unlock không có global total order. Init vẫn đọc legacy
defaults; cfprefsd vẫn có thể flush physical settings file ngoài source contract,
và synchronize failure không phủ định primary commit. Không claim full preferences
authority, cross-process lost-update freedom hoặc power-loss durability. Mutable
storage payload/cache và whole Reset workflow là boundary khác.

Manifest chuyển adapter `storage-preference` sang enrolled, rollout
`4C.2H3Z-partial`; `tlinkSettings`, preferences authority và toàn Patch 4 vẫn partial.
