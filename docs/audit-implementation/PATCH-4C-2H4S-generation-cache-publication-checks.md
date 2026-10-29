# 4C.2H4S — Expected generation cache publication checks

Ngày 2026-10-28. Người dùng xác nhận H4R build pass trước bước này.

## Finding

Confirmed missing checkpoint, severity Medium, trong
`IdentifierManager.publishRuntimeGeneration:identityDirectory:model:` và hai nhóm
callback model/software, battery adopt/publish. Full generation proof chỉ được
kiểm tra trước publication; phần tiếp theo chủ yếu kiểm tra `PXActiveProfileID()`.
Cached active ID có thể chậm hơn canonical/legacy selection. Ngoài ra callback đầu
có thể reenter một writer, chọn B hoặc thay dữ liệu của A rồi outer callback tiếp
tục cài cache/mirror từ receipt cũ.

Ví dụ reproduce: commit generation A, đổi authoritative selection sang B trước
publication nhưng giữ resolver cache A; hoặc trong software setter chọn B trước
model setter; hoặc trong battery adoption ghi battery source mới trước mirror và
notifications. Source A đã commit hợp lệ, nhưng publication phía sau dùng dữ liệu
cũ. Đây là lỗi freshness của cache, không phải bằng chứng mọi Reset đều lỗi, source
commit bị hỏng hay có crash/leak. Fixture kiểm tra các interleaving này; tần suất
trên thiết bị thực chưa được đo.

## Implementation

Expected-active generation dùng checked publication sau khi lifecycle đã release.
Generic/explicit creation và deferred activation giữ publication policy trước đây.
Không thêm public API, schema field hoặc dependency cho native build.

- Giữ full receipt proof check một lần trước publication.
- Dùng chung `runtimePublicationHasCurrentIdentity:transaction:error:` với H4R:
  validate identity path, đọc authoritative selection; canonical tồn tại thì thắng,
  canonical vắng mới dùng legacy. Missing/invalid/read failure bỏ publication.
- Trước mỗi callback, `runtimeGenerationPublicationIsCurrent:identifierKeys:artifactPaths:`
  so riêng source inputs với detached receipt dưới read-only source transaction.
  Gate nhả trước setter, không giữ lifecycle/source lock qua callback.
- Software callback kiểm tra model và software tuple; model callback kiểm tra lại
  DeviceModel. Reentry giữa hai callback không tự động cho phép callback phía sau.
- Scalar kiểm tra field và sidecar của chính type đó. Field/sidecar mới của IDFA
  không buộc loại IDFV còn đúng. Không phụ thuộc dictionary iteration order.
- WiFi kiểm tra SSID/BSSID và wifi_info; storage kiểm tra DeviceModel và toàn
  storage dictionary; uptime kiểm tra BootTime/SystemUptime cùng hai sidecars.
- Battery kiểm tra BatteryLevel/LowPowerMode và identity battery_info trước adopt,
  rồi kiểm tra lại trước mirror/notification callback.
- Same-ID metadata/revision hoặc unrelated ID-field update vẫn cho callback có
  inputs còn khớp. Source success vẫn YES/nil error khi bỏ stale publication hay
  gặp compatibility exception; settings notification giữ một lần như trước.

Existing nil-guard helpers giữ generic behavior và không thêm source checkpoint
reads cho generic generation, standalone dependency setters hay creation. H4R chỉ
factor phần authoritative ID read sang helper chung, không đổi preview policy.

## Performance và lifecycle

Expected path thêm một admission checkpoint và checkpoint theo callback: tối đa
model/software hai lần, một lần mỗi scalar được bật, WiFi/storage/uptime, hai lần
battery. Mỗi lần đọc selection pair và device_ids cùng sidecar liên quan; đọc key
không có nghĩa là filesystem chỉ đọc một key, plist vẫn được decode cả dictionary.
Không replay toàn bộ receipt ở mỗi scalar, không thêm provider/random generation,
write, commit, retry, dispatch, timer hay hot-hook I/O. Read-only transactions vẫn
có gate/file-validation cost; relative cost low/moderate tùy source size/contention,
chưa benchmark trên main thread/device. Không tuyên bố latency đã cải thiện.

Guard blocks chỉ dùng đồng bộ trong publication stack, không lưu trên manager và
không tạo retain cycle. Manager lookup nằm trước checkpoint của callback tương
ứng để không dùng một checkpoint đã cũ vì singleton initialization reentered.

## Verification

Native group recipe extract 41 actual IdentifierManager methods, thêm năm helper/
overload, cùng real SourceStore/receipt implementations. Hai lanes rootful và
RootHide-defined vẫn chạy ba lần mỗi lane trong macOS CI, không thêm framework.
UI/profile recipe giữ 53 ProfileManager + Profile model + 25 UI methods.

Fixture mới kiểm tra:

- Post-commit B/missing selection, cùng committed acknowledgement và source bytes.
- Same-ID metadata hoặc unrelated ID merge vẫn publish matching values.
- Scalar field/sidecar, WiFi field/sidecar, storage, uptime field/sidecar,
  battery field/sidecar, software và model drift loại đúng callback group.
- Software callback đổi selection/model; callback throws sau handoff.
- Scalar reentry thay inputs còn lại; battery adopt đổi selection/source trước publish.
- Source A với cached resolver B vẫn publish đúng A; generic bypass không gọi guard.
- Fresh lifecycle acquisition tại checkpoints/callback reentry, chứng minh không giữ
  lifecycle/source gate qua controlled callbacks.

Windows local: 62/63 Python suites + 4/4 Node pass. Một suite bridge-shell còn lỗi
`mkdir /c/Users/ADMIN: Permission denied` như trước. Exact fragment extraction,
CHECK macro arity, source hardening, RootHide build/package static và diff checks
pass. Không có macOS/xcrun/Theos ở local; native compile/runtime, package và device
H4S còn chờ CI. Static/extraction pass không thay thế native verification.

## Remaining boundaries

Đây là value checkpoint trước callback, không phải global ordering hoặc atomic
cache unit. Source vẫn có thể đổi sau check và trước setter; admitted callback có
thể mutate cache trước khi reenter. Không undo cache, tự reload cache mới, rollback
source, hoặc đồng bộ cache-only changes không reflected trong source. Bên trong
battery publish, mirror và từng notification vẫn là các effect riêng; checkpoint
không bảo vệ interleaving giữa các effect nội bộ đó.

Generic generation/creation/standalone dependency publication, cache thread-safety,
scope/defaults authority, earlier Reset metadata/hardware targets, cross-instance
admission, cancellation/missing callbacks, directory durability và daemon ack còn
partial. Manifest `4C.2H4S-partial`; toàn Patch 4 chưa hoàn tất, Patch 5–8 chưa triển khai.
