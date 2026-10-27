# Patch 4C.2H3M — schema migration lifecycle

Người dùng xác nhận build H3L pass. H3M đưa direct/current schema migration và cold-reader directory repair/migration vào lifecycle ownership; cập nhật writer/batch callers để truyền capability hiện có. Patch 4 vẫn partial; Patch 5–8 chưa triển khai.

## Vấn đề và flow

Migration cũ giữ source transaction cho legacy reads, sidecars, schema marker và generation bump, nhưng direct/read-triggered calls chưa giữ directory lifecycle. `profileIdentityPath` còn tạo identity trước coordination. Writer/batch đã giữ root lease rồi gọi path/migration helpers, nên thêm acquire vào mọi helper sẽ tự conflict. Thread-local migration flag chỉ tránh recursion trong một thread; nó không biểu thị ownership hoặc directory lifetime.

`migrateProfileSchemaAtIdentityDirectory:` nay tự acquire owned identity scope. Variant có `lifecycleLease:` borrow scope từ parent capability; invalidate chỉ đóng child directory FD, không nhả root của caller. Cả hai gọi exact migration body trong `commitProfileSchemaWithMutation:` qua guarded source write, với directory/root/pending-journal validation trước staging. `migrateProfileSchemaIfNeeded` acquire trước active lookup và vẫn không tạo target không tồn tại.

Factory thêm `acquireWithIdentityResolverUsingLease:`: resolver nhận held lease tường minh để compose schema preflight, sau đó factory pin target cho caller. Resolver không được invalidate hoặc lưu capability ngoài synchronous call. Existing factory signatures giữ adapter behavior; failed/throwing resolver vẫn cleanup trong finally. Current identifier writer và current/explicit batch/create dùng lease-aware path/migration helpers, không acquire lồng.

## Reader và behavior

`profileIdentityPath` đọc schema như trước. Schema >=2 trả live path ngay, không lifecycle acquire hoặc source gate, kể cả root đang busy. Cold path acquire nonblocking lease, kiểm tra active ID vẫn giống lần đọc ban đầu, rồi repair/migrate qua shared helper. Selection move trả error 20; busy trả error 12; pending deletion trả error 27 trước directory creation/staging. Không thêm polling, auto retry hoặc implicit lease reuse. Thread-local recursion bypass được bỏ; re-entry muốn mutate phải truyền capability rõ ràng hoặc nhận busy.

Legacy identity repair giữ mode/owner policy, nhưng chỉ chạy khi configured profiles namespace có thể acquire/validate lease và deletion recovery không pending. Cold read không tự tạo profiles root để vượt qua coordination failure. Repair thành công với owner `mobile` cần iOS/device validation; host fixtures pre-create normal identities, kiểm tra busy/pending không tạo missing target. Reader dùng live schema path không trở thành captured snapshot hoặc filesystem capability.

Không đổi HardwareUUID → SystemBootUUID, UDID generation, ATT/LPM defaults, legacy battery handling, schema >=2 no-op hoặc một generation bump cho schema migration. Source transaction vẫn recheck schema sau acquire; concurrent direct migrations có thể nhận busy, caller retry sau đó là no-op nếu schema đã được migrate. Source failure rollback toàn bộ staged sidecars/schema/counter/token. Exceptions release owned scope hoặc đóng child scope và giữ parent lease như caller yêu cầu.

Migration vẫn là preflight commit riêng: candidate preparation/commit về sau fail không rollback migration hoặc directory repair. Không thêm cache publication/notification. Migration log chạy sau source gate nhưng có thể vẫn nằm trong caller-held lifecycle lease; không claim mọi callback/log đều chạy khi parent đã nhả.

## Performance và giới hạn

Current-schema reader không thêm lock hoặc allocation packet; bỏ fileExists check riêng vì schema read đã quyết định fast path. Cold migration/repair thêm root/deletion checks, target recheck và pinned directory scope; nested preflight có thể đọc recovery state nhiều lần để kiểm tra trước filesystem effect và trước source stage. Expected relative cost low–moderate cho cold writes/migration, chưa benchmark. Giữ existing migration work trong source transaction; không thay entropy/value policy chỉ để tối ưu.

Explicit parent capability tránh recursive acquire và thể hiện ai được nhả lease. Scope/factory không lưu resolver để gọi về sau; finally cleanup bảo vệ return/exception paths. Concurrent manager settings/error/cache safety vẫn là boundary riêng.

Guards serialize cooperating lifecycle writers, không namespace-isolate writer bỏ qua lease sau checkpoint. Directory repair xảy ra trước migration pin; migration pin và candidate pin cũng là hai phases dưới cùng root lease. Bypass namespace replacement giữa phases vẫn là giới hạn. Reader fast path không thêm symlink/namespace hardening hoặc canonical selection CAS; cold selection recheck chỉ bảo vệ move đã xảy ra trước ownership. RootHide snapshot authority và rootful captured-reader rollout không đổi.

## Kiểm chứng

Identifier native runner extract actual owned/borrowed migration, core, reader/path helpers và writer resolver. Migration exception fixture override core commit boundary, không giữ bản migration logic riêng. Native scenarios thêm busy direct/current/cold reader; pending deletion; missing-target repair suppression; cold selection drift; borrowed commit/re-entry/rollback/exception; nil/released/wrong-root capability; late journal; removed/replaced/symlink identity trước staging; current-schema read dưới contention không source gate; cold/current migration retry và one-bump schema result. Concurrent fixture chấp nhận documented busy outcome, kiểm tra không có failure khác và successful retry không tăng counter lần hai.

Device-group/batch fixture nhận parent lease vào path/migration adapters; source contracts kiểm tra actual production borrowed selectors. Existing batch/create capability, artifact scope, snapshot và RootHide gates tiếp tục giữ. RootHide static test dùng exact method definition boundary để private helper declarations mới không làm slice sai vùng getActiveProfileId.

Windows pass 15 source/host gates: identifier, generation, device-group, profile creation, artifact writers/preparation, identity preparation, source transactions, telephony, snapshot reader/consumers/publisher, release hardening, RootHide static và thread-safety cleanup (80/80). Sau bổ sung current-migration success case, identifier/profile macro gates vẫn pass. Exact native extraction: identifier 4 fragments, device-group 3, artifact preparation 6, profile creation 3. Git diff check sạch.

Không có Foundation/xcrun/Theos trên máy Windows. Native compile/runtime và package H3M cần macOS CI; RootHide-defined host fixture không xác minh actual SDK/namespace hoặc injected-process/device behavior.

## Tiếp theo

Dashboard preview, metadata/defaults/security authority, cache/thread safety/publication ordering, rootful captured readers và directory cleanup/durability vẫn pending/partial. Full migration plus candidate rollback, power-loss/fsync guarantee và automatic recovery cleanup không thuộc mốc này.
