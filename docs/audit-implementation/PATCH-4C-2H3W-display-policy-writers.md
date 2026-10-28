# Patch 4C.2H3W — WebCompat/UI Scale verified writes and scalar reader guards

Người dùng xác nhận build H3V pass. H3W tiếp tục Patch 4; source dùng chung rootful
và RootHide. Không đổi bootstrap, scope, hook installation hoặc region coordinator.

## Lỗi và thay đổi

Hai actions `webCompatIOSRangeToggleChanged:` và `displayUIScaleSpoofToggleChanged:`
còn gọi trực tiếp NSUserDefaults setBool/synchronize rồi phát settings notification
mà không kiểm tra persistence. Chúng không tham gia source transaction; UI/warning
có thể báo đã đổi khi source chưa lưu thành công. H3W dùng `PXWriteSecurityBool`
như các verified writers đã enroll, cùng source gate và post-commit mirrors.

Action capture giá trị cũ qua shared reader trước write. Failure khôi phục switch,
hiện toast và return trước version lookup, warning mutation hoặc notification.
Không ghi lại giá trị cũ bằng một write thứ hai để giả rollback. Missing-key policy
giữ WebCompat OFF, configured Display UI Scale ON. Successful action giữ một settings
notification, warning threshold strict `> 16.3.1`, master dependency và height 24/0.
WebCompat đọc master qua canonical reader, tránh warning phụ thuộc suite cache cũ.

Background entry chuyển lên main bằng weak controller trước settings/UI access;
main callers tiếp tục được xử lý đồng bộ. Không thêm queue/request token hoặc đổi
success ordering sang async acknowledgement cho hai toggles này.

### Shared scalar reader hardening

Các rollback reads mới cần an toàn với malformed stored values. Shared Bool/Integer
readers cũ gửi boolValue/integerValue trực tiếp cho mọi non-nil object; array/dict
từ plist hoặc unexpected captured value có thể gây unrecognized selector. Readers
nay chỉ chuyển đổi NSNumber/NSString; các kiểu khác/missing dùng caller default.
Giữ conversion cũ của các giá trị hợp lệ, không đổi preference precedence, source
selection hoặc số lần đọc storage. Đây không phải hoàn tất canonical authority.

## Kiểm chứng

Mở rộng `test_runtime_security_writers.py --native` hiện có cho hai schemes, ba
lần/binary. Hai UI methods và hai scalar reader bodies được extract nguyên source.
VersionCompare.m thực sự được link vào fixture; không stub threshold comparator.
Security source store, transaction/fault injection, raw-byte rollback và ba defaults
mirrors dùng fixture hiện hành. UIKit controls/warning/manager version là controlled
boundaries; không chạm preferences thật hay gửi Darwin IPC.

Cases: enable/disable faults cho cả hai flags, persisted-value rollback thay vì
inverse sender, missing-key defaults/absence, warning/version không thay sau failure,
successful one commit/three mirrors/one settings notice và giữ unrelated keys.
Warning matrix gồm master ON/OFF, exact 16.3.1, 16.3.2, empty/missing version và nil
height constraint. Background entry của cả hai actions kiểm tra main persistence,
warning/feedback và không dispatch sync.

Scalar cases dùng exact bodies với raw getter seam trong cả hai host lanes: array,
dictionary, null, date/data/arbitrary object không nhận selector conversion; numeric/
string conversion và caller defaults được giữ. Rootful có thêm actual live file
reader với malformed field types. RootHide host CLI không được coi là real injected
app: writer fixture tiếp tục dùng manager-read boundary cho UI, còn captured source/
sandbox/device behavior vẫn cần QA riêng.

Existing macOS CI step đã bao fixture này; generator thêm display/scalar fragments
và compile dependency VersionCompare.m. Macro arity, exact extraction và source
contracts kiểm tra tại Windows. Native Foundation/Theos/package H3W chờ CI; không
suy ra runtime pass từ source checks.

Local regression: 62/63 Python suites và 4/4 Node suites pass; suite bridge
migration shell còn Permission denied `/c/Users/ADMIN`. Source hardening, RootHide
build contracts và package metadata checks pass. Generator tạo 9 security fragments,
gồm hai display actions và hai scalar readers nguyên source; macro/diff checks pass.
Không ghi nhận full release pass hoặc native runtime pass tại Windows.

## Performance và phần còn lại

Success có thêm canonical reads và source transaction/journal cùng ba compatibility
mirrors thay cho một suite write. Đây là chi phí correctness trên cold UI action,
expected I/O cost moderate so với setBool đơn lẻ; chưa benchmark CPU/latency.
Source contention/synchronous persistence vẫn có thể làm chậm main như các verified
toggle khác. Không thêm background persistence thiếu ordering chỉ để gọi là tối ưu.
Scalar type guards thêm các class checks, expected low cost; không thêm I/O/cache.

Rollback value được capture trước attempt; không phải atomic CAS với mọi process
khác. cfprefsd/canonical domain, mirror total ordering, setup/effective-state reads,
indicator position, clear metrics và remaining writers vẫn partial. Không tuyên bố
toàn bộ SecurityTab hoặc shared source authority đã hoàn tất. Manifest rollout:
`4C.2H3W-partial`; Patch 4 chưa đạt toàn bộ acceptance matrix.
