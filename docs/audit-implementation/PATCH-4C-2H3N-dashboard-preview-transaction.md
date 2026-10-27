# Patch 4C.2H3N — dashboard preview transaction

Người dùng xác nhận build H3M pass. H3N enroll dashboard preview apply vào source transaction/lifecycle contract. Patch 4 vẫn partial; whole Reset Data workflow và Patch 5–8 chưa hoàn tất.

## Vấn đề đã xác định

`applyFakePreviewToCurrentProfile:` trước đây prepare storage rồi gọi model/name/serial setters ghi riêng, đọc lại device_ids và ghi trực tiếp final tuple, sau đó gọi ba storage setters autosave. Failure cuối flow không rollback các setter trước; final raw write còn nằm ngoài source commit token và có thể overwrite một target/basis cũ. Storage autosaves resolve current selection độc lập, nên không đảm bảo cùng target với model/tuple. Final counter `generation + 1` không guard signed overflow. Serial setter return bị bỏ qua: serial ngắn vẫn có thể vào final device_ids mà không có corresponding sidecar/counter update.

Các flow trên có bằng chứng source; chưa có device race/latency benchmark. H3N sửa source ownership và failure boundaries, không thiết kế lại value/catalog policy của dashboard.

## Flow mới

UI method giữ selector cũ và delegate sang `IdentifierManager.applyDashboardPreview:error:`. Coordinator copy các recognized NSString values trước provider callbacks, acquire current artifact scope trước target lookup, capture device_ids basis qua source gate rồi prepare ngoài gate. Existing tuple-completion và IOSProductType restoration logic được chuyển vào coordinator. Meta phải là dictionary và đủ typed tuple fields; missing target/model hoặc incomplete DB result fail trước mutation.

Custom model membership validation và hardware preparation được tách thành private helpers. Prepare-only builder trả `PXPreparedDeviceProfileGroup` đã deep-detach, không ghi source/identity cache. Standalone custom setter vẫn validate trước ownership, giữ scope qua preparation/commit và release trước model cache setter như H3K. Không thêm DB membership lookup thứ hai hoặc thay model/hardware/variant policy.

Storage vẫn chọn capacity theo model và dùng generator cũ. `currentStorageInfo` lấy snapshot cache; coordinator chỉ merge TotalStorage/FreeStorage/FilesystemType như ba setter cũ, giữ extra cached fields. Sau preparation, updates/storage packet được serialize thành immutable property-list graph trước stage. Snapshot API là shallow copy; concurrent mutation của manager cache vẫn là boundary riêng, không được coi là thread-safe chỉ vì có lifecycle lease.

Một guarded source block kiểm tra captured DeviceModel dependency nếu software resolution dựa vào model cũ, stage optional model replacement/legacy cellular sidecar removal, DeviceName/SerialNumber sidecars, final preview fields/counter/CommittedAt và optional profile storage. Không gọi persistence setters trong block. Related writes cùng rollback, gồm bytes/schema counter/source token; unrelated device_ids fields merge từ state hiện tại trong transaction.

Finally release scope trước compatibility cache publication. Model cache và storage adoption là best-effort, riêng từng callback. Callback exception sau commit được log và không đổi committed acknowledgement thành NO hoặc compensation. Dashboard không thêm name/serial provider-cache publication: manual setters trước đây dùng includeNameAndSerial:NO, policy đó giữ nguyên. Không thêm notification trong coordinator; existing caller gửi profileChanged sau success như trước.

## Value policy và corrective behavior

Giữ recognized preview keys, MACAddress → WiFiAddress alias, complete iOS tuple, model hardware preparation và IOSProductType nội bộ không ghi vào device_ids. Software-only marker vẫn restore model mà preview tuple được chuẩn bị cho. Country/carrier fields vẫn là device_ids overrides; không enroll thêm carrier_details hoặc giải quyết lại baseband/catalog authority ở mốc này.

Giữ counter increments của successful old path: name +1 nếu có, serial +1 nếu có, final apply +1; custom model không tăng counter. Mọi increment đi qua overflow-checked staging helper. Counter exhaustion nay reject toàn candidate, không wrap hoặc để lại setter writes. Serial nonempty dưới 8 ký tự reject toàn candidate thay vì ghi invalid final scalar sau setter failure. Incomplete/malformed tuple hoặc requested version không có model cũng reject trước source effects. Non-string preview fields được bỏ qua; malformed MAC không còn nhận selector length không phù hợp.

Storage giữ legacy **cache authority**, không đổi thành merge theo persisted disk authority: extra cached fields được giữ, disk-only fields vắng khỏi cache vẫn có thể mất như behavior cũ. Chỉ ba generated fields được áp dụng; không adopt toàn bộ generated storage packet để vô tình thêm/thay field khác. Storage disabled hoặc preview không chọn model vẫn không prepare/save storage.

## Lifecycle, performance và giới hạn

Existing scope pin target, validate root/profile/identity và pending deletion trước staging. Busy/pending/missing/replaced target fail trước source commit; resolver/provider exceptions cleanup scope. Preparations không giữ source gate. Storage initializer đọc cache/settings nhưng không acquire profile lifecycle hoặc autosave, nên không thêm warm-up hoặc implicit recursive reuse.

Full model+name+serial+storage preview trước đây có sáu source transactions qua setters và một raw IDs write; candidate apply nay một source transaction, với device_ids và storage mỗi file được commit một lần. Không phải một physical filesystem write: source journal và nhiều source files vẫn có I/O riêng. Chuẩn bị immutable packets thêm serialization/allocation trên cold UI action; expected low–moderate CPU cost, giảm repeated commit/I/O phases là lợi ích chứng minh từ flow, chưa có benchmark latency. Không thêm queue, timer, polling hoặc hot hook work.

Create/switch/regenerate trước apply, settings/scope/defaults changes và notifications sau apply vẫn là các phases riêng. Regenerate có publication riêng trước preview apply; không claim mọi Reset Data failure giữ nguyên toàn bộ workflow hoặc chưa từng phát snapshot. Schema/path preflight có thể commit trước preview candidate và không rollback cùng candidate. Lease không namespace-isolate bypass writer sau checkpoint; cache settings/catalog synchronization, source/cache total ordering và power-loss/directory durability vẫn partial.

## Kiểm chứng

Thêm source gate `test_runtime_dashboard_preview.py`, đăng ký trong CI và manual release hardening. Native coverage chạy cùng existing device-group runner trên rootful/RootHide-defined fixtures, extract exact coordinator/validation/custom-model builders và link actual source/scope/staging engines. UI adapter được kiểm tra không còn raw writes hoặc setter chaining. Artifact-preparation fixture extract actual storage snapshot getter và kiểm tra không autosave.

Native cases mới: prepare-only custom model, busy/pending, một commit trước cache callbacks, counter policy +3 của full candidate, storage cached extras, fault tại từng source-written checkpoint với rollback toàn bộ bytes/token, storage/model/DB tuple failures, mutable intent, fixed target và disjoint merge, re-entry, provider exception, late deletion, identity removed/replaced/symlink, captured model drift, counter exhaustion, short serial, scalar-only/metadata/invalid-MAC counters, software-only restoration marker, disabled storage và callback exception sau commit.

Một successful A commit thay đổi global source token; B-target invariance case so raw B file bytes, không so global token như thể không có commit. Rollback/failure cases vẫn so full snapshot bao token. Macro arity validation bao native fixtures; exact fragment extraction pass cho device-group (3), artifact preparation (6), identifier (4), profile creation (3).

Windows pass 17 source/host gates: dashboard preview, device-group, profile creation, generation, identifier, artifact preparation/writers, identity preparation, source transactions, telephony, snapshot reader/consumers/publisher, release hardening, RootHide static, thread-safety cleanup (80/80) và iOS DB regression. Whole-generation inventory assertion được cập nhật dashboard=enrolled, vẫn giữ defaults/security writers pending. Git diff check sạch.

Foundation/xcrun/Theos không có trên máy Windows; native compile/runtime và package H3N cần macOS CI. RootHide-defined host fixtures không xác minh actual SDK paths, injected process hoặc iOS device behavior.

## CI follow-up — hardware/storage gate (2026-10-27)

CI báo `Reset reapplies storage from the final fake model` fail vì hardware gate vẫn tìm lời gọi chọn capacity trong UI method cũ. Sau H3N, UI delegate sang `IdentifierManager.applyDashboardPreview:error:`; coordinator vẫn resolve final model trước chọn capacity và stage storage cùng identifiers. Đây là source assertion lỗi thời; follow-up không sửa production code hoặc storage/value policy.

Gate nay extract đúng hai methods, kiểm tra UI delegation, explicit model và software-only marker resolution, enabled/model guard, model-aware capacity/generation, storage staging cùng transaction và cache adoption sau success/release. Năm negative source cases xác nhận token nằm ngoài method không che được delegation/model/staging/publication bị hỏng. Native fixture ghi lại model/count truyền vào capacity selector, kiểm tra preview model khác persisted model, software-only restoration marker, và không gọi selector ở scalar-only/disabled-storage paths. Fixture vẫn dùng capacity generator giả; không coi đây là device benchmark hoặc proof cho toàn bộ storage tier database.

Windows pass hardware 17/17, negative gate 5/5, WebGL 70/70, dashboard/device-group/profile-creation source contracts (bao macro arity), iOS DB và Phase-10 release hardening. Exact native fragment extraction pass cho device-group/identifier/artifact-preparation/profile-creation. Native fixture mới chưa compile/run tại Windows; chờ macOS CI rootful/RootHide-defined runs. H3O native/package status vẫn pending.

## Tiếp theo

Metadata/defaults/security authority, remaining profile producers, cache/thread safety/publication ordering, rootful captured readers và directory cleanup/durability vẫn pending/partial. Whole Reset Data atomicity, catalogue dependency redesign và automatic recovery cleanup không thuộc mốc này.
