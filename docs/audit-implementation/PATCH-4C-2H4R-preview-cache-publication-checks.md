# 4C.2H4R — Expected preview cache publication checks

Ngày 2026-10-28. Người dùng xác nhận H4Q build pass trước bước này.

## Finding

Confirmed missing post-commit guard, severity Medium, tại
`IdentifierManager.applyDashboardPreview:expectedActiveProfileID:error:`. H4Q pin
target/selection trong source operation nhưng sau invalidate owner, code vẫn adopt
model và storage caches vô điều kiện. B có thể được chọn sau A commit; hoặc model
callback có thể publish nguồn/cache mới rồi old preview tiếp tục overwrite storage.

Tác động trực tiếp là shared caches trong process manager không còn tương ứng với
active source hoặc newer storage publication. Downstream UI/providers đọc caches
có thể dùng old values. Không kết luận host snapshots đã bị ghi sai, memory leak,
crash hoặc mọi lần Reset đều gặp lỗi; source commit của A vẫn có thể hoàn toàn hợp lệ.
Reproduce bằng controlled handoff trước cache check hoặc reentrant model callback
commit selection/storage mới trước khi outer storage adoption chạy.

## Implementation

Chỉ expected-target preview path thêm `dashboardPreviewPublicationIsCurrentAtIdentity:model:storage:`.
Sau source success và lifecycle release, giữ copied committed identity rồi checkpoint
trước model adoption và lại trước storage adoption. Helper chạy một read-only source
transaction, nhả gate trước callbacks:

- Validate expected identity path, đọc canonical/legacy pair theo authority policy
  hiện tại và yêu cầu active ID còn đúng target.
- Model cache chỉ adopt nếu `device_ids.DeviceModel` còn bằng candidate model.
- Storage cache còn yêu cầu persisted storage dictionary bằng toàn candidate map,
  vì adoption thay toàn `_storageSettings`, gồm cả cached extra fields.
- Missing/unreadable source hoặc mismatch bỏ adoption tương ứng, không repair source.

Publication dùng current target/values, không ép old selection revision còn nguyên:
rename/metadata-only change trên cùng profile vẫn cho adopt values còn đúng. Đây là
khác biệt có chủ đích với H4Q commit receipt, vốn so full selection pair trước source
staging. Không invalidate cache update chỉ vì unrelated metadata thay đổi sau commit.

Source success vẫn trả YES/nil error khi cache publication bị bỏ qua hoặc callback
throws; không biến committed operation thành rollback giả. Generic nil-expected
preview không thêm checkpoint I/O và giữ behavior cũ. Generation publication và các
standalone dependency setters chưa đổi trong H4R. Không giữ source/lifecycle lock
qua model/storage callbacks, không thêm notify, retry, timer hay schema field.

## Verification

Existing group native recipe extract 36 actual IdentifierManager methods; UI/profile
recipe giữ 53 ProfileManager + Profile model + 25 UI methods. Subclass collaborator
inject source changes ngay trước actual publication helper rồi gọi super để kiểm tra
real source predicate. Model callback collaborator vẫn có thể acquire fresh lease và
ghi source sau release; không dùng production test hook hoặc swizzle.

Cases thêm:

- Sau commit: new active ID, model field mới hoặc missing selection loại stale cache
  publication; source ack/error và post-injection source bytes được giữ.
- Storage source đổi riêng: vẫn adopt matching model, không adopt stale storage.
- Same-ID revision/metadata-only change: matching model/storage vẫn adopt một lần.
- Model callback commit newer selection/storage hoặc same-profile newer model/storage:
  outer storage không overwrite newer cache. Callback throws sau thay đổi vẫn giữ
  source success và skip stale tail.
- Matching normal path adopt model/storage đúng một lần; generic preview không gọi
  targeted checkpoint hoặc thêm lookup.

Windows local: 62/63 Python suites + 4/4 Node pass; bridge-shell suite vẫn lỗi
`mkdir /c/Users/ADMIN: Permission denied`. Source hardening, RootHide build/package
static checks, exact extraction, CHECK macro và diff checks pass. Native recipe vẫn
rootful/RootHide-defined, ba executions/lane, không thêm source/framework dependency.
Native compile/Foundation, real cache callbacks, Theos và device H4R chờ macOS CI.

## Cost và remaining boundaries

Expected model+storage preview thêm hai bounded checkpoints, đọc pair/model ở mỗi
lần và storage ở lần thứ hai. Cost expected low/moderate theo source size/contention,
chưa benchmark latency; không hot-hook I/O hoặc polling. Generic path chỉ thêm
short conditional, không có source read mới. Không build thêm full-generation
receipt chỉ để so cache members không dùng.

Đây là stale-value checkpoint, không phải atomic publication ordering. Selection
hoặc source vẫn có thể đổi sau check và trước setter; admitted model callback cũng
có thể đã mutate cache trước khi nó reenter writer. Không undo cache hoặc guarantee
model/storage cache unit atomic. Cache-only newer intent không reflected trong source,
nonatomic/cache-thread races và writers bypass source contract chưa được coordinate.
Suppression không tự reload latest cache; cache convergence vẫn cần protocol riêng.

Whole-generation publication còn dùng existing active-ID/cache semantics và chưa có
new helper này. Global cache/defaults ordering, earlier backup/metadata/hardware
targets, cross-instance admission, owner cancellation, source/directory durability
và daemon acknowledgement vẫn partial. Manifest `4C.2H4R-partial`; whole Reset và
toàn Patch 4 chưa hoàn tất, Patch 5–8 chưa triển khai.
