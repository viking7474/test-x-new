# Patch 4C.2H4J — manual profile creation acknowledgement

Người dùng xác nhận build H4I pass. H4J cập nhật các UI tạo thủ công trên source
chung rootful/RootHide. Giữ bootstrap priming, hooks và riêng flow Reset Data.

## Findings

High / P1: TLinkIOSViewController.showProfileCreation gọi switch sau core create,
rồi regenerate toàn bộ identifiers trước khi kiểm tra switchSuccess. Khi switch
thất bại hoặc selection đã đổi, batch dùng current target có thể tác động profile
khác với request ban đầu. Popup còn gọi showSuccessMessage cho switch failure.

Medium / P1: Device Specific gọi void addProfileWithName: rồi lập tức đọc/generate
model/theme và refresh UI. Create hiện async, nên các reads có thể còn thuộc profile
cũ; lifecycle guards có thể từ chối các writes này nhưng caller bỏ qua kết quả và
không refresh theo completion hoặc báo lỗi creation.

Medium / P1: hai popup chính dùng switch lặp và dispatch_after 1 giây làm readiness
signal. Core create đã commit generation + activation trước success; batch chuẩn bị
baseline model khi thiếu và theme khi chưa có. Popup chính regenerate lần nữa làm
thay random values/counters và publish thêm, không phải chờ generation cũ hoàn tất.
Timer không chứng minh daemon distribution đã xong.

Medium / P1: ProfileCreationViewController disable nút trong lúc pending nhưng text
selection callback bật lại Create, cho phép duplicate request và callback busy của
request sau dừng indicator/khôi phục controls trước request đầu hoàn tất.

Đây là lỗi ordering/control flow trên source, chưa có incident thiết bị được cung
cấp cho các caller này. Strong completion/alert captures còn có lifetime/retain-cycle
risk; không khẳng định permanent UIKit leak khi chưa kiểm tra cleanup trên thiết bị.

## Thay đổi

Device panel có submit adapter dùng createProfile:completion:, per-controller busy
gate và copied name/description. Disable profile overlay trong lúc pending, restore
sau completion; failure báo lỗi, current success refresh. Không còn void-create rồi
chạy generators tức thời. Giữ name validation cũ của panel, optional description và
normal-success refresh behavior.

Hai popup chính giữ entry selectors, preview/trim/rounded-field policy nhưng dùng
chung dialog và submit adapter. Core success là completion boundary, không gọi switch,
full regenerate hoặc model/theme fallback lần nữa. Bỏ fixed one-second delay; chỉ
dispatch một main turn để input alert dismiss xong trước result presentation. Current
success cập nhật profiles/indicator/values và báo active; failure restore UI rồi báo
error. Không đổi enabled flags hoặc baseline/theme preparation policy của backend.

Thêm validateCurrentProfileID:error:, read-only checkpoint trên main. Nó đọc canonical/
legacy selection qua capture gate, dùng existing canonical precedence, trả error khi
requested ID không còn current hoặc context không xác minh được. Không repair memory,
write archive/selection, mirror defaults hay tự switch lại. Manual adapters kiểm tra
ngay trước active-success effects; nếu create đã success nhưng checkpoint fail, UI
ghi nhận profile đã được tạo và yêu cầu refresh, không tuyên bố nó vẫn active.

Standalone form có pending flag chống duplicate/reentry, text callbacks không bật
lại Create và cancel không dismiss request đang pending. Controls restore trên main;
delegate chỉ nhận captured name một lần khi core success. Core operation không bị hủy
chỉ vì UI owner biến mất.

Các submit adapters và dialog entry marshal về main khi cần. Alert actions dùng weak
alert/owner; completion giữ weak UI owner, late delivery bỏ UI effects khi owner đã
dealloc. Không giữ controller chỉ để chờ provider. Data input vẫn có lifetime cần
thiết cho request/ack; không tạo một cancellation protocol mới.

## Verification

Native profile fixture extract 53 exact manager methods + Profile model và thêm năm
exact controller methods trong ba fragments. Foundation collaborators thay UIKit và
singleton dependency bằng controlled producer; actual controller bodies được compile
trong fixture. Native recipe vẫn rootful/RootHide-defined, ba executions/lane, không
thêm source/library dependency.

- Device/main adapters giữ pending tới callback, không refresh/success sớm, chỉ một
  submission, copied text không bị caller edit sau đó thay đổi.
- Failure và supersession giữa producer callback/main delivery restore controls;
  không refresh created state hoặc báo active success sai.
- Form text changes/duplicate taps/cancel trong pending không tạo request thứ hai;
  delegate nhận đúng captured name khi success, failure chỉ hiện error.
- Controller dealloc khi producer pending: producer vẫn complete, không giữ UI owner
  hoặc gọi UI/current-check sau release.
- Off-main submission và controlled producer callback vẫn có main-thread UI ack.
- Actual current-ID helper dùng committed selection thay stale memory; raw selection,
  archive, memory/defaults counters không bị repair. Newer selection được giữ nguyên.

Source guards cấm switch/generator/fixed-delay trong manual adapters, bảo vệ core
baseline/theme prerequisite và pending/weak/current-ID gates. UIKit presentation,
navigation/dismissal và immediate device app launches vẫn cần runtime verification;
Foundation stubs không thay thế UIKit behavior.

Local Windows: 62/63 Python suites và 4/4 Node suites pass; remaining bridge migration
shell vẫn Permission denied `/c/Users/ADMIN`. Source hardening, RootHide build/package
metadata, macro/fragment/diff checks pass. Native compile/runtime, Theos/package và
device H4J chờ macOS CI; không báo native pass từ extraction.

## Performance và remaining boundaries

Bỏ một duplicate full generation ở popup chính cùng repeated same-profile switch/
registry-selection persistence và readiness timer ở hai popup. Avoided cold CPU,
allocations và I/O có thể moderate/high khi nhiều identifiers bật; chưa benchmark
tổng latency. Một main-turn delivery phục vụ alert lifecycle, không có polling/timer
mới. UI checkpoint thêm cold source-pair read; không nằm trên hot hook.

Core completion chứng minh generation/activation tại commit, checkpoint chỉ xác nhận
current ID tại lần read. Không freeze selection sau check hoặc chứng minh generation
vẫn mới nhất, reader caches đã converge, hay daemon đã mirror tới mọi app. UI getters
và post-commit observers vẫn có contracts riêng. Device tests cần kiểm tra launch ngay
sau create trên RootHide, thay vì dùng một delay giả như distribution acknowledgement.

Reset Data vẫn có fake-options/prepared-preview/app-reset intent riêng và chưa chuyển
trong H4J. Generic void convenience selectors còn giữ compatibility; manual UI không
dùng chúng như completion API. Remaining producers, defaults/security authority,
directory durability và rootful reader rollout vẫn partial. Manifest
`4C.2H4J-partial`; toàn Patch 4 chưa hoàn tất, Patch 5–8 chưa triển khai.
