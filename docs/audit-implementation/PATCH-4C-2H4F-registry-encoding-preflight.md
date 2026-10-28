# Patch 4C.2H4F — validate registry bytes before persistence

Người dùng xác nhận build H4E pass. H4F áp dụng trên source chung rootful/RootHide,
giữ nguyên bootstrap priming và các hook đã được xác nhận.

## Finding và tác động

High / P1, lỗi correctness khi nhận malformed model. Trong ProfileManager,
saveProfilesWithCompletion: và updateProfileUnderLease:index:error: chỉ yêu cầu
NSKeyedArchiver encode thành công trước khi ghi registry. Secure encoding không
kiểm tra schema: một NSArray đặt vào iconName/settings, nested Profile có field
sai kiểu, duplicate IDs hoặc root member sai class vẫn có thể encode được.

Reader decodeRegistryRecord:error: từ chối các bytes đó. Common save có thể thay
archive đọc được bằng archive không load được; đường edit còn commit display files
trước đó và có thể báo success. Lần reload sau bật registryUnavailable, chặn profile
changes. H4E phát hiện ở activation sau save không thể bảo vệ archive đã thay.

Đây là thiếu validation thể hiện trực tiếp trong source; chưa có bằng chứng incident
thiết bị do malformed model. Native regression thêm controlled input để kiểm tra
đường encode-success/decode-failure, chờ thực thi macOS.

## Thay đổi và compatibility

Thêm private preparedRegistryRecordForProfiles:error:. Helper encode một lần, tạo
exists/bytes record và yêu cầu chính decodeRegistryRecord:error: hiện hành chấp nhận
record đó. Nếu hợp lệ, trả lại đúng record/bytes đã kiểm tra; không encode lại,
normalize hoặc thay live objects bằng decoded copies.

Common save chỉ gọi registry CAS khi helper thành công. Edit chuẩn bị/validate
candidate trước PXWriteProfileDisplayMetadata, rồi dùng cùng bytes cho registry CAS
và receipt. Invalid candidate không thay archive, receipt, manager slots hoặc phát
success notification qua update. Existing catches/finally vẫn trả failure và release
lifecycle; failed direct save không tự sửa collection mà caller đã làm sai.

Giữ nguyên allowed secure classes, root/ID uniqueness policy và optional-field/date/
settings fallbacks của reader. Legal nested Profile vẫn được chấp nhận. Nil legacy
dates có thể tiếp tục được reader gán fallback; helper không ghi các fallback đó
ngược vào original bytes. Delete/recovery đã có archive validator riêng và không
đổi ordering/schema trong bước này.

Validation graph nằm trong một autorelease pool riêng. NSError được giữ bằng strong
local bên ngoài pool rồi chuyển cho caller, tránh trả error đã hết lifetime. Helper
không có filesystem, source-gate, notification hoặc manager-adoption effects.

## Kiểm chứng

Native profile fixture tiếp tục hai lanes rootful/RootHide-defined, ba executions
mỗi lane. Extraction hiện gồm 40 exact manager methods và actual Profile model;
không thêm native recipe/header dependencies.

- Mười candidate secure-encodable nhưng reader-invalid: sáu metadata field types,
  wrong ID type, malformed nested Profile, duplicate ID và unexpected root member.
- Common save phải fail một lần, giữ raw archive/receipt, display/active files,
  current slot/publication counters và nhả lifecycle. Các input có typed metadata
  sai còn đi qua public update để kiểm tra fail trước display/source writes.
- Error description còn đọc được sau validation pool; legacy nil fields/dates/
  settings vẫn decode bằng fallback cũ.
- Valid update vẫn adopt đúng caller object, giữ legal nested Profile values và
  registry receipt khớp persisted bytes. Existing create/switch, callback drift,
  deletion/recovery và metadata fault suites giữ nguyên.

Source guards kiểm tra validate-before-I/O, exact-byte reuse, helper không có write
effects và native CHECK macro arity. Local Windows: 62/63 Python suites, 4/4 Node
suites pass; remaining bridge migration shell vẫn Permission denied `/c/Users/ADMIN`.
Source hardening, RootHide build/package metadata, extraction và diff checks pass.
Native compile/runtime, Theos/package và device H4F chờ macOS CI; extraction không
thay thế native execution.

## Performance và giới hạn

Thêm một full registry decode mỗi common save hoặc metadata edit, trước side effects,
trên cold main-thread operation dưới lifecycle ownership nhưng ngoài source gate.
CPU/allocation tỷ lệ archive size; expected moderate, có thể high với registry lớn,
chưa benchmark. Autorelease pool giới hạn lifetime của temporary validation objects;
không giữ cache/decoded registry lâu dài, không thêm disk read hoặc encode lần hai.

Validation chỉ chứng minh encoded bytes được current reader chấp nhận. Nó không
chứng minh mọi live alias còn khớp bytes sau reentrant/concurrent mutation; H4E vẫn
bảo vệ selected activation tại các checkpoints riêng. Không đổi mọi nonatomic
property thành thread-safe hoặc giải quyết arbitrary coding/accessor side effects.

Registry, display source group, selection và directories vẫn nhiều phases. Metadata
đã commit mà subsequent registry CAS thất bại vẫn là partial failure; không rollback
archive mới hơn. Defaults/security authority, cleanup/durability, raw readers và
rootful captured-reader rollout còn riêng. Manifest `4C.2H4F-partial`; toàn Patch 4
chưa hoàn tất, Patch 5–8 chưa triển khai.

Người dùng xác nhận build H4F pass ngày 2026-10-28. Remaining UI metadata
writers được chuyển riêng tại [H4G](PATCH-4C-2H4G-owned-profile-metadata-ui.md);
full device/runtime matrix và toàn Patch 4 vẫn partial.
