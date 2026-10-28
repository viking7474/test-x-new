# Patch 4C.2H3Y — indicator position writer

Người dùng xác nhận build H3X pass. H3Y tiếp tục source writer rollout trên code
chung rootful/RootHide. Bootstrap, injection filter và hook registration không đổi.

## Vấn đề và thay đổi

Drag-end cũ ghi hai float preferences rồi synchronize, sau đó ghi riêng
`indicator_position.plist` trên main thread. File này lại có ưu tiên khi restore:
nếu ghi file lỗi thì lần mở tiếp theo có thể dùng vị trí cũ dù preferences đã đổi.
Các bước không có cùng commit boundary; filesystem/defaults work chặn SpringBoard
main thread. Đây là đường drag-end, không phải từng gesture update.

`PXWriteProfileIndicatorPosition` merge hai preference coordinates và stage
dedicated position dictionary trong một standalone source transaction. Giữ float
precision của legacy preferences và double precision/timestamp của dedicated file.
Source engine rollback cả hai files khi partial write lỗi; corrupt root không bị
ghi đè để repair ngầm. Chỉ mirror canonical security suite sau commit/unlock,
không thêm settings notification hoặc mở rộng sang các suite khác.

`PXProfileIndicatorPositionPath()` dùng mobile-library resolver hiện có, cùng
WeaponX path trong môi trường thông thường. Fixed ancillary file được allowlist
trong production source store; không mở wildcard, không thêm snapshot field hoặc
đổi runtime schema. Production path binding vẫn kiểm tra symlink resolution.

UI giữ legacy void selector `savePositionToFile:y:`. Method handoff main khi cần,
validate finite/float-range coordinates rồi enqueue trên lazy per-owner serial
queue. Window clamp/animation vẫn thực hiện ngay trên main. Gesture Began/Changed
không ghi source hoặc tạo queue. Không thêm timer/polling/retry.

Main-owned pending point giữ kết quả hide/show trong lúc chờ lưu. Mỗi save có token;
acknowledgement cũ không xóa pending point của save mới hơn. Worker giữ scalars và
token, chỉ weak-reference UI owner; save đã enqueue vẫn hoàn tất khi owner dealloc.
Nếu save lỗi, log failure và clear matching pending token, không báo đã persist và
không kéo ngược cửa sổ đang hiển thị về vị trí trước đó.

## Behavior và phạm vi bảo đảm

Reader vẫn ưu tiên dedicated file, dùng preferences khi cả hai file coordinates
bằng zero, chỉ restore khi cả hai dương; thiếu/sai loại/nonfinite geometry dùng
fallback an toàn. NSNumber/NSString float conversion được giữ. Known legacy bug:
drag clamp cho phép X=0 nhưng restore không chấp nhận X=0; vị trí sát mép trái có
thể trở về default khi tạo lại window. Ghi riêng để sửa semantic bằng patch/test
độc lập, không thay quy tắc tọa độ trong writer migration này. Rotation/offscreen
restore, toàn bộ indicator timer/observer/window lifecycle chưa được sửa ở đây.

Directory preflight và legacy chmod 0644 nằm ngoài transaction byte rollback.
Existing parent creation khi đọc được giữ. Raw UI/defaults readers không acquire
source capture gate, nên có thể thấy intermediate state của hai file trong lúc
commit; không claim global atomic reads. Post-commit defaults mirror và cfprefsd
physical-file authority vẫn partial, không claim cross-process total ordering
hoặc power-loss durability. Async save có pending interval; process bị kill trước
khi worker commit có thể mất vị trí mới, cần đánh giá trên device như các async
persistence flows khác.

## Kiểm chứng

Existing native security fixture include nguyên production store và source engine,
extract exact decoder/restore/path/pan/save bodies; dùng actual CoreGraphics
geometry, temporary files, controlled UIKit/defaults adapters. Runner link
CoreGraphics và giữ hai rootful/RootHide-defined lanes, mỗi lane chạy ba lần.

Cases bổ sung: paired commit và precision/timestamp, canonical-only mirror sau
unlock, unrelated settings, faults sau từng file, original file absence, corrupt
root, invalid/nonfinite/oversized input trước source entry, file-first/fallback và
zero sentinel, latest pending hide/show, old acknowledgement trong lúc newer save
chưa commit, drag clamp/animation khi worker bị chặn, Began/Changed không I/O,
queued failure và queued save sau UI owner release. Host adapters không chứng minh
UIKit hoặc SpringBoard runtime acceptance.

Local source/fragment/macro/diff checks được chạy trên Windows. Native compile,
Theos/package và device H3Y chờ macOS CI. Full local regression inventory: 62/63
Python suites và 4/4 Node suites pass; bridge migration shell fixture vẫn lỗi môi
trường Permission denied `/c/Users/ADMIN` đã tồn tại trước patch. Source hardening,
RootHide build/package contracts pass; 11 production security fragments generate
được. Không coi đây là full release gate hoặc native runtime pass.

Expected cost: journal/two-file write thêm I/O so với legacy independent writes;
moderate trên cold drag-end, chưa benchmark. Main thread loại bỏ source lock/file
write/defaults synchronize của save; queue/token allocation cost thấp theo một lần
thả tay. Restore vẫn có synchronous read như trước. Không cache runtime settings
hoặc đổi hot hook behavior trong patch này. Manifest `4C.2H3Y-partial`; toàn Patch
4 và authority rollout chưa hoàn tất.
