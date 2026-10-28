# Patch 4C.2H4E — activation model proof around callbacks

Người dùng xác nhận build H4D và deletion-comparer follow-up pass. H4E xử lý
remaining model consistency boundary trên source chung rootful/RootHide.

## Vấn đề đã xác định

H4D tách caller input trước asynchronous creation, nhưng sau registration, manager
expose Profile qua collection/getters. Trong create/switch, registry lưu trước
termination và activation. Một callback sửa registered model sau save có thể làm
selection label/current memory khác archive đã xác nhận, dù registry byte CAS,
directory proof, generation proof và expected selection vẫn hợp lệ.

Đây là thiếu checkpoint có thể tái hiện bằng controlled callback mutation; chưa
có bằng chứng một app cụ thể đã gặp trên thiết bị. Native fixture dùng filesystem
adapter sau archive và termination adapter để chèn mutation đúng hai boundaries.

## Thay đổi

Thêm private activationProfile:matchesRegistry:error: dùng secure-decoded registry
và private structural comparer để kiểm tra selected target theo persisted values:
ID, name, description, icon, settings và createdAt/lastUsed, kể cả nested Profile.
Giữ allowed archive classes; không đổi global Profile.isEqual/hash hoặc schema.

Create finish và switch save callback kiểm tra target với saved registry receipt
trước termination. activateProfile đọc observed registry một lần, giữ raw byte CAS
với manager receipt, rồi kiểm tra model với observed archive trước source commit.
Graph decoding/comparison nằm ngoài source gate. Existing lifecycle, reservation,
generation và selection checks vẫn chạy; model proof không thay thế chúng.

Comparer nhận date policy riêng. Deletion wrapper giữ directional legacy fallback:
missing-date provenance trong Before cho phép ngày fallback được encode vào After.
Activation so actual date values chính xác, không nới equality vì provenance flag.
Các flag có thể còn trên model đã load sau một lần save hợp lệ nên không bắt buộc
chúng phải false. Name/Description trong selection packet được copy trước staging.

Model drift trả error 31 và không activate, mirror defaults, publish cache hoặc
success notification. Archive đã commit có thể giữ ready inactive candidate; model
đã bị external code sửa vẫn có thể khác archive cho tới explicit reload. Không tự
rollback archive hoặc ghi đè external edits. Drift trước termination ngăn termination;
drift sau termination chỉ chặn activation tiếp theo, không hoàn tác termination đã chạy.

## Kiểm chứng

Existing native profile fixture extract 39 exact manager methods cùng actual Profile
coding model; vẫn compile rootful và RootHide-defined, ba executions/lane trong CI.
Không thêm native source/header dependency hoặc private runtime API.

Cases mới:

- Equal persisted dates được chấp nhận dù transient provenance flags còn true.
- Activation từ chối date drift mà deletion legacy policy có chủ đích cho qua.
- Tám thay đổi độc lập ở ID/name/description/icon/createdAt/lastUsed/settings/nested
  Profile date đều phải bị từ chối.
- Create và switch, mỗi flow có mutation sau archive hoặc trong termination:
  completion failure đúng một lần, active selection/settings/current slot và
  publication counters giữ nguyên; lifecycle/reservation được release.
- Termination count phân biệt hai boundaries; acknowledged archive vẫn giữ accepted
  values; explicit reload khôi phục registered model từ archive. Fixture drain
  deferred startup/reload mirrors trước baseline tiếp theo.

Giữ toàn bộ deletion/recovery và nested-profile/cycle regression của H4D. Source
guards kiểm tra date policy/ordering, selection string copies, one registry read
và native CHECK macro arity. Exact fragment generation không phải native compilation.

Local Windows: 62/63 Python suites và 4/4 Node suites pass. Suite bridge migration
shell vẫn lỗi Permission denied `/c/Users/ADMIN` như trước. Source hardening,
RootHide build/package metadata, macro/diff checks và 39-method/model extraction
pass. Native compile/runtime, Theos/package và device H4E chờ macOS CI.

## Performance và giới hạn

Thêm hai secure decodes của registry mỗi successful create/switch activation, cộng
comparison selected graph tại hai checkpoints. Cost tỷ lệ archive size và graph
được thăm, chạy trên main ở cold profile operation: expected moderate, có thể high
với registry/settings lớn; chưa benchmark. Không thêm disk read trước termination;
activate tái dùng đúng một observed registry read. Không giữ decoded graph/memo lâu
dài hoặc thêm queue, timer, polling hay hook work.

Checkpoint không làm nonatomic Profile properties thread-safe: caller vẫn cần
synchronize mutation. Non-cooperating mutation sau check, arbitrary coding/accessor
side effects và callbacks sau successful source commit còn ngoài boundary này.
Only selected target được so với archive; không tạo immutable global model hoặc
coherent snapshot của mọi object exposed bởi manager.

Directory/artifact/archive/selection vẫn nhiều phases; defaults/security authority,
raw-reader/cross-process atomicity, cleanup/durability và rootful reader rollout còn
partial. Giữ bootstrap priming đã xác nhận trên RootHide iOS 15.8.8/AIDA64. Manifest
`4C.2H4E-partial`; toàn Patch 4 chưa hoàn tất, Patch 5–8 chưa triển khai.
