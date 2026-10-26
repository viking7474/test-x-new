# Patch 4C.2H3D — whole-regenerate lifecycle ownership

Người dùng xác nhận build H3C và các sửa native fixture pass. H3D bổ sung ownership cho batch regenerate hiện có; chưa thay chính sách giá trị identity, chưa triển khai dashboard preview hoặc toàn bộ artifact-writer enrollment.

## Vấn đề và boundary

Whole-regenerate đã prepare/compare/commit source ở một target cố định, nhưng trước H3D không tham gia lifecycle lease của ProfileManager. Source transaction bảo vệ từng commit, không bảo vệ khoảng thời gian target lookup/migration/preparation trước commit. Một instance khác có thể switch/delete/recover profile trong khoảng này. Đây là cửa sổ concurrency xác định từ code; chưa có bằng chứng race trên thiết bị.

Các API standalone `regenerateAllEnabledIdentifiersWithError:`, `regenerateAllEnabledIdentifiersForProfileID:networkArtifacts:error:` và inactive `commitRuntimeGenerationForProfileID:networkArtifacts:error:` nay acquire nonblocking lease trước target lookup/migration, kiểm tra không có pending delete journal, và giữ ownership qua preparation đến source commit. Busy/pending recovery trả NSError trước provider callbacks; không spin, wait hoặc retry tự động. Void wrapper vẫn log lỗi theo API cũ.

Core nhận capability bắt buộc, kiểm tra root configured bằng device/inode, target profile-directory proof và canonical identity path. Trước staging trong source gate, core kiểm tra lại lease/root/directory và journal absence. Writer bỏ qua lease mà tạo journal hoặc đổi profile directory giữa preparation/commit sẽ bị reject ở checkpoint này. Không acquire lifecycle lease bên trong source gate.

## Create worker và lifetime

Create đã giữ lease xuyên main/worker/metadata/activation. Acquire một lease riêng trong IdentifierManager sẽ tự conflict. Overload mới nhận borrowed `lifecycleLease:`; ProfileManager capture strong local trên main trước dispatch và truyền cùng capability sang worker. Worker không đọc property nonatomic để lấy lease, không acquire lại và không invalidate capability của caller. Invalidated/wrong-root capability bị reject trước migration/providers. Root aliases vẫn hợp lệ khi stat trỏ cùng inode.

Owned helper invalidate trong finally cả khi provider raise exception; exception chuyển thành NSError và không xuất bản success. Borrowed API chuyển lỗi tương tự nhưng giữ caller lease. ProfileManager tiếp tục nhả ownership ở endProfileOperation theo lifecycle hiện có. Không đưa provider callbacks hoặc dispatch vào source gate.

## Publication và behavior

Standalone owned batch nhả lease trước compatibility publication. Việc này cho phép lazy singleton initialization và callback reentry mà không tự giữ lifecycle lock. Publication dùng receipt proof check hiện có trước khi adopt cache; stale receipt chỉ yêu cầu reader refresh. Active-ID guards và post-commit callback exception handling được giữ.

Sau nhả lease, một lifecycle operation khác có thể tiến hành. Vì vậy không claim cache publication và source selection có total ordering; receipt recheck/active-ID guards là checkpoints, không phải atomic cache installation. Create vẫn giữ caller lease qua các activation adapters như trước; H3D không thay ordering của chúng.

Không đổi scalar formats, model/telephony rules, unconditional WiFi, optional theme, frozen options/scope, generation counter, inactive deferred settings hoặc source rollback policy. Existing migration/directory creation vẫn precede batch source commit, nay nằm dưới lease; chúng chưa nằm trong rollback của generated candidate. Borrowed capability là internal cooperation contract, caller phải giữ sống và không đồng thời invalidate/reuse trên operation khác.

## Kiểm chứng

Native fixture tiếp tục trích xuất exact production IdentifierManager/ProfileManager methods; runner link thêm lifecycle lease và delete journal thật. Các case mới kiểm tra:

- Cả ba standalone APIs reject busy trước target lookup/migration/provider/source/cache effects.
- Borrowed generation thành công dưới caller lease; success/exception/pending không invalidate caller. Invalidated/wrong-root capability bị reject; configured root alias được chấp nhận.
- Pending delete journal chặn cả owned/borrowed trước preparation.
- Provider exception không ghi source và owned lease được nhả trước return.
- Provider chạy khi lease held; compatibility cache callback chạy sau owned lease release.
- Writer bypass tạo journal hoặc thay profile directory trong preparation: candidate bị reject, giữ nguyên competing state, không publish caches.
- Create worker fixture kiểm tra lease thật đang held và vẫn valid sau generation; các profile completion/activation/notification cases cũ tiếp tục chạy.

Windows đã pass 13 source/host gates liên quan, macro argument validation và exact native-method extraction cho cả hai fixtures; git diff check sạch. Chưa chạy native Foundation/Theos trên máy này vì thiếu macOS/xcrun. CI hiện có chạy rootful/RootHide native fixture; kết quả runtime/build H3D vẫn chờ CI và device matrix riêng.

## Performance và phần còn lại

Không thêm hook/hot-path lookup, timer, network, persistent queue hoặc polling. Cold regenerate thêm nonblocking flock, root/directory stat checkpoints, delete-state reads và receipt proof read trước publication. Expected overhead low–moderate so với toàn bộ regeneration, chưa benchmark. Lease giữ qua provider preparation (kể cả serial generation) làm lifecycle operation khác trả busy trong thời gian đó; không làm source gate giữ qua provider. Không coi đây là tối ưu CPU/latency.

Chỉ whole-regenerate và create worker được enrollment ở mốc này. Standalone scalar/model/telephony/battery/network/WiFi/uptime/storage setters, dashboard preview, metadata sidecars, preferences/security authority, full cache ordering, rootful readers và device/runtime matrix vẫn partial/pending. Inode checks không cô lập namespace khỏi writer không hợp tác, không chống mọi identity-child replacement hoặc external file write sau check. Không thêm recursive cleanup/recovery retry, không claim fsync/power-loss durability. Patch 4 chưa hoàn tất; Patch 5–8 chưa triển khai.
