# Patch 4C.2H3C — recoverable delete decisions

Người dùng xác nhận build H3B pass. H3C thêm write-ahead journal cho logical deletion và replay registry sau process exit. Build/native H3C cần macOS CI; Patch 4 và automatic orphan cleanup vẫn chưa hoàn tất.

## Boundary mới

`.profile-delete-journal.plist` là một fixed, canonical-checked path trong source allowlist. Đây là internal coordination record, không thêm field vào runtime snapshot. Lifecycle lease vẫn phải được acquire trước source gate. Journal giữ operation UUID, target ID, directory proof, full selection Before/After và exact secure archive Before/After bytes; không lấy path tùy ý từ file journal để ghi/xóa.

Delete encode archive After và validate quan hệ **remove đúng target, giữ các profiles khác** trước khi đổi selection. Encoding/validation failure giữ selection, archive và directory cũ. Đây là thay đổi so với H3B, nơi encoding failure có thể xảy ra sau khi fallback đã active.

| State | Decision / replay |
| --- | --- |
| prepared | Chưa commit delete. Reload bỏ intent, không đổi selection/archive/files. |
| committed | Fallback pair và delete decision đã commit trong **cùng source transaction**. Known Before archive có thể roll forward thành After; source selection không bị rollback. |
| archived | After archive đã được kiểm chứng và ghi nhận. Archive khác After, kể cả old Before bị producer khác ghi lại, phải giữ nguyên và báo conflict. |
| compensating | External selection drift đã dẫn tới quyết định hủy delete. Restore chỉ exact known Before/After archive dưới byte CAS, yêu cầu original directory proof còn đúng; replay tiếp tục compensation kể cả source đổi lần nữa. |

Recording `compensating` trước archive restoration tránh crash giữa restore và journal cleanup làm lần reload sau nhầm thành một forward deletion mới. Recording `archived` trước post-archive adapters phân biệt old Before chưa được ghi với Before do writer khác restore sau khi archive đã installed. Mỗi transition/cleanup so full intent và selection pair dưới source transaction; archive IO/decode nằm ngoài source gate.

Unknown archive bytes, malformed/unsupported journal, invalid archive relationship hoặc directory không còn phù hợp cho compensation đều fail closed: giữ file, giữ intent và chặn mutation tới khi có valid reload/repair. Không merge các records hoặc rewrite selection để làm recovery pass.

## Integration và lifecycle

Create/update/switch/save, raw selection/metadata writes và bootstrap/seed-zero dừng khi có pending intent. Load acquire lifecycle lease, resolve intent **trước** khi đọc/adopt registry và committed selection. Vì seed-zero cũng kiểm tra pending, startup không tái tạo directory đang thuộc một deletion chưa resolve.

Sau source decision commit, I/O failure có thể để fallback active với registry cũ và pending intent. API trả NO/error, không giả rollback; reload có thể hoàn tất deletion đã commit. Header ghi rõ semantics này. Memory/defaults được adopt từ committed selection; resolution/first successful load yêu cầu runtime publication sau khi nhả ownership. First-load wakeup còn bao phủ crash sau journal settlement nhưng trước notification. Không thêm timer/polling để retry.

Normal delete chỉ cleanup sau khi decision/registry đã settle. **Recovery không retry recursive removal**, không adopt directory từ marker reserved, và không dùng inode proof sau crash làm quyền xóa. Crash sau settle nhưng trước cleanup để inactive directory được giữ; ID scan tiếp tục tránh reuse khi directory còn tồn tại. Source decision/registry recovery không đồng nghĩa full directory transaction hoặc automatic orphan garbage collection.

## Archive validation và compatibility

Load và journal validation dùng chung secure decoder, kiểm tra duplicate/malformed IDs, individual field types và `decoder.error`. Invalid field không bị thay bằng default rồi âm thầm ghi mất metadata.

Profile giữ hai transient decode-provenance flags cho legacy missing createdAt/lastUsed. Flags không encode hoặc expose vào settings. Validator giữ nguyên persisted timestamps; chỉ cho phép existing decoder fallback khi Before thật sự thiếu timestamp. Điều này tránh reject một legacy archive chỉ vì hai lần decode tự bổ sung hai thời điểm khác nhau. Name/description/icon/settings của remaining profiles phải giữ nguyên. Profile settings vẫn theo allowed secure classes hiện hành, không siết policy identity generation.

Gộp lại adjacent duplicate registry preflights và duplicate fixture declarations trong baseline; source gate bảo vệ không tái xuất hiện.

## Performance, lifetime và giới hạn

Không thêm hook, queue thường trực, network hoặc polling. Cold delete có thêm full Before/After archive bytes, secure decode và nhiều journal phase commits. Expected cost **moderate; có thể high với archive lớn**, chưa benchmark. Journal/source before-images còn có thể copy các payload này; không gọi đây là một optimization. Nhiều IO vẫn trên main. Không giữ source gate qua archive encoding/decode, defaults, notification hoặc cleanup.

Validator blocks chỉ chạy đồng bộ ngoài source gate, không escape transaction. Test checkpoints chỉ tồn tại khi PX_SOURCE_TRANSACTION_TESTING bật. Lifecycle ownership vẫn invalidate trước completion; replay không giữ completion hoặc transaction. First successful manager load có thêm một publication wakeup, các reload bình thường sau đó không thêm wakeup nếu không recover intent.

Cooperation với old binaries/direct external writers và non-lifecycle artifact producers vẫn partial. Byte/inode checks là checkpoints, không phải namespace isolation cho writer bỏ qua lease. Không claim fsync/power-loss durability. Durable directory ownership, artifact-writer enrollment, metadata sidecar atomicity, preferences authority, rootful reader rollout và device matrix vẫn cần các bước tiếp theo.

## Kiểm chứng

Native fixture link journal production, extract **33 exact production methods** cùng Profile coding/provenance extension. Subprocess `_exit(77)` tại prepared/committed/archive-written/settled checkpoints và giữa recovery/archive compensation; checkpoint kiểm tra source gate đã nhả. Cases gồm prepared abort, committed forward replay, compensation restart, unknown registry, malformed schema/path/archive, field-type error, legacy timestamps, byte-CAS conflicts, no cleanup on replay và publication wakeup sau settled-before-notify exit.

Host Windows: **13/13 related source gates pass**, exact production fragment extraction và `git diff --check` pass. Native fixture mới chưa được compile/run tại local vì không có xcrun/Foundation/Theos. macOS CI hiện có chạy rootful + RootHide, ba lượt mỗi variant. Các source gates không chứng minh process-crash/runtime assertions đã pass.
