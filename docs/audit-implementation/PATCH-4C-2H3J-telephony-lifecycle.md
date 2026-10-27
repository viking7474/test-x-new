# Patch 4C.2H3J — standalone IMEI/MEID lifecycle

Người dùng xác nhận build H3I pass. H3J đưa `setCustomIMEI:`, `setCustomMEID:`, `generateIMEI` và `generateMEID` vào profile lifecycle ownership hiện có. Patch 4 vẫn partial; Patch 5–8 chưa triển khai.

## Vấn đề và flow mới

Standalone telephony đã ghi identifier sidecar/device_ids/counter trong cùng source transaction và so captured dependencies trước stage. Nhưng lookup target, đọc source basis và regional DB preparation chưa giữ profile lifecycle lease. Source serialization không ngăn cooperating delete/switch/create đi qua khoảng này. Đây là khoảng trống xác định từ source; chưa có device race reproducer hoặc latency benchmark.

`prepareAndPersistTelephonyValue:type:generate:` copy type và manual value, giữ format validation trước target lookup như cũ. Sau đó gọi H3I `currentIdentifierMutation`: acquire nonblocking root lease, kiểm tra root/pending deletion rồi resolve target bằng `profileIdentityPath`. Scope pin identity directory/profile proof và giữ sống xuyên source capture, regional DB lookup, identifier preparation và source commit.

Commit dùng `mutation performSourceWrite:` để kiểm tra lại root/profile/identity và late deletion journal trước staging. Dependency comparison cũ vẫn cần thiết vì writer ngoài lifecycle contract có thể đổi model/regulatory/build/existing identity trong preparation. Sidecar, device_ids và generation counter vẫn thành công hoặc rollback cùng nhau. Finally invalidate scope trên success, policy failure, source failure, early return hoặc exception. Factory tự cleanup nếu target resolver throw trước khi scope được trả về.

Busy ownership trả error 12, pending deletion trả error 27 trước target/DB work. Invalid manual format vẫn trả format error trước acquire. Exceptions từ provider/resolver vẫn propagate như trước; finally bảo đảm không giữ lock. Return nil/BOOL tiếp tục biểu thị persistence failure/success theo API cũ. Không thêm compatibility setter, notification, queue hoặc retry.

## Behavior và giới hạn

Không đổi checksum, TAC/prefix/region/cellular/CDMA rules, generated formats, manual lowercase MEID spelling, non-iPhone manual compatibility, independence giữa IMEI và MEID hoặc counter semantics. Type được copy để callback không thể đổi key đã chọn giữa validation và persistence. Mỗi operation vẫn resolve một target và một regional lookup; unrelated source fields được merge như trước.

Existing `profileIdentityPath` vẫn có path repair/schema migration preflight dưới root lease. Preflight có thể tạo identity/commit migration trước khi scope pin target và trước final telephony transaction. Candidate fail sau đó không rollback migration. Không claim whole-operation rollback hoặc bảo vệ namespace against bypass writers trong preflight. Direct/read-triggered migration chưa enroll lifecycle riêng; readers current-schema không thêm lock ở mốc này.

Whole batch/create chuẩn bị cellular bằng pure helpers và stage cùng generation contract riêng, không gọi bốn standalone APIs trong lease đang giữ. Không thêm silent capability reuse hoặc recursive acquisition. Model/software/cellular-refresh fallbacks gọi lẫn nhau nên cần enrollment riêng; chưa bọc thêm ownership tùy tiện ở các nhánh đó.

## Performance và lifetime

Đây là write-path coordination: thêm root lease acquire, deletion-state reads và directory checks, expected relative cost low–moderate, chưa benchmark. Manual invalid input không trả chi phí acquire. Provider/DB work giữ lifecycle ownership nhưng nằm ngoài source gate; competing cooperating writer fail busy, không chờ thêm trong vòng polling. Không có thay đổi hot-path hook/read hay repeated per-identifier DB lookup mới.

Scope dùng root lease và pinned identity FD hiện có, invalidate rõ ràng trong finally; không phụ thuộc ARC/autorelease để nhả lock kịp thời. Source transaction vẫn bao staging/commit riêng. Không claim thread safety của `IdentifierManager.error`, mutable settings hoặc DB catalog generation; các manager states đó là boundary riêng.

## Kiểm chứng

Device-group native fixture extract thêm exact production `currentIdentifierMutation`; import artifact scope header thật và link `PXProfileArtifactMutation.m` cùng lifecycle/journal/profile-selection/source implementations đã có. Thêm fixture path backend cho `PXProfileRootPath`, không thay bằng fake ownership. Existing CI `test_runtime_device_group_writers.py --native` bao cả telephony tests trên rootful và RootHide-defined host fixtures.

Native cases mới kiểm tra cả bốn APIs: busy và pending deletion trước target/provider; lease giữ trong resolver/provider nhưng source gate đã nhả; provider re-entry fail busy, outer commit clear error và tăng counter đúng một lần; provider exception; late deletion journal; missing/replaced/symlink identity giữa preparation và commit; resolver exception; missing selection; mutable type bị sửa trong provider. Competing-source snapshots bao raw file bytes và source commit token. Lease-free probes chạy sau success/failure/exception. Các test checksum, regional policy, dependency drift, transaction rollback, counter exhaustion, malformed sidecar và mutable manual value cũ được giữ.

Fixture device-group dùng stub target resolver; actual path/schema preflight và migration exception cleanup vẫn có exact-method coverage trong identifier-writer fixture H3I. Không suy từ stub sang full path/durability guarantee.

Windows pass 15 source/host gates: telephony writers, device-group writers, profile creation, identifier writers, identity preparation, artifact writers/preparation, source transactions, generation, snapshot reader/consumers/publisher, release hardening, RootHide static và thread-safety cleanup (80/80). Macro arity validation pass; exact native fragment extraction pass cho device-group (3 files) và identifier (4 files); git diff check sạch.

Máy Windows không có Foundation/xcrun/Theos nên H3J native compile/runtime và package build cần macOS CI xác nhận. RootHide-defined fixture không xác nhận actual jailbreak paths, SDK integration hoặc iOS injected-process behavior.

## Tiếp theo

Model/software/cellular-refresh lifecycle, uptime/boot compatibility wrappers, direct migration, dashboard preview, metadata/defaults/security authority, cache/publication ordering, rootful captured readers và directory cleanup/durability vẫn partial/pending. Không thêm power-loss guarantee, fsync contract, automatic cleanup/recovery retry hoặc thay policy của các nhánh chưa enroll.
