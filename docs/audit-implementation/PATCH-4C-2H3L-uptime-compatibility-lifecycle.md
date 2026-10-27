# Patch 4C.2H3L — uptime/boot compatibility lifecycle

Người dùng xác nhận build H3K pass. H3L enroll `IdentifierManager.generateSystemUptime` và `generateBootTime` vào lifecycle ownership. Direct/read-triggered schema migration vẫn là boundary riêng; Patch 4 vẫn partial, Patch 5–8 chưa triển khai.

## Vấn đề và thiết kế

Hai wrappers resolve target, gọi UptimeManager getter rồi ghi lại selected sidecar/device_ids trong source transaction. Getter có thể tự generate một cặp boot/uptime bằng H3F owned writer. Bọc lease trực tiếp quanh flow cũ sẽ khiến getter tự acquire lồng và fail busy. Khi chưa bọc, directory lifetime không được giữ xuyên lookup/read/final write; missing-data flow có hai source commits, cache có thể nhận generation đầu dù final wrapper commit lỗi. Nếu generation fail, legacy getter còn trả safe default mà wrapper có thể tiếp tục persist như success.

UptimeManager thêm `currentUptimeForProfile:generateIfMissing:` và `currentBootTimeForProfile:generateIfMissing:`. Với NO, read miss trả 0/nil trước generation/log/fallback, không persist hoặc adopt cache. Existing public getter signatures là adapters dùng YES, giữ auto-generation và safe-default policy cũ. Shared `prepareConsistentUptimeInfo` tách nguyên sysctl/clock/PXPrepareRuntimeUptime policy khỏi persistence; H3F standalone generation dùng lại helper, vẫn acquire trước provider và release trước cache setters.

Hai IdentifierManager wrappers dùng một private flow `generateUptimeCompatibilityForBootTime:`. Acquire current mutation trước target/schema lookup, đọc với NO dưới ownership. Nếu miss, gọi provider preparation ngoài source gate; commit init cả boot/uptime và selected scalar/sidecar trong cùng `mutation performSourceWrite:`. Directory/journal validation có trước staging. Finally release trên success/return/exception; chỉ missing-pair success mới adopt cache sau release. Read hits không thêm adoption hoặc reset cặp còn lại.

## Correctness và behavior

Boot sidecar vẫn chứa NSDate; device_ids BootTime là rounded epoch string. Uptime persisted seconds string và display hours giữ formats; boot display vẫn dùng NSDateFormatter medium styles hiện có. Counter không tăng. Existing source precedence giữ boot date → uptime value/date → device_ids cho uptime; boot date → device_ids cho boot. Generated candidate dùng một clock/preparation packet, thay vì commit rồi đọc lại để cộng thêm I/O elapsed time; không thay random range, minimum, real-uptime cap hoặc type policy.

Missing pair và selected scalar nay cùng rollback; source failure trả nil/error, không persist một safe default sau generation failure và không adopt candidate cache. Đây là deliberate stability correction của writer, không đổi public legacy getter fallback policy. Current-schema success có một candidate source commit cả trên hit và miss; path/schema preflight có thể commit riêng như các mốc trước, nên không claim whole-operation one-commit/rollback.

Getter type guards kiểm tra value có doubleValue và lastUpdated là NSDate trước elapsed calculation; device_ids uptime/boot cũng kiểm tra scalar selector. Array/dictionary field sai kiểu nay fall through thay vì crash vì unrecognized selector hoặc invalid date argument. Không claim full semantic/nonfinite/range validation của mọi stored value ở mốc này. Date validity/read precedence của record hợp lệ không đổi.

Cache adoption/formatter xảy ra sau release. Exception sau committed source không compensation source; không claim total cache/notification ordering. Existing UptimeManager error/mutable cache synchronization vẫn là boundary riêng.

## Lifecycle và performance

Không truyền silent borrowed capability hoặc dùng thread-local reentrancy. Nested writer từ read/provider nhận busy. Singleton acquisition nằm trong try để constructor exception cũng release mutation. Scope giữ root lease/pinned identity FD hiện có, không tạo thêm persistent queue/timer/polling/network.

Read hits của legacy getters thêm một Objective-C adapter dispatch, expected negligible so với file I/O đã có; không thêm lock/source gate vào getter hit. Owned wrappers thêm lifecycle/deletion/directory checks, expected low–moderate relative cost, chưa benchmark. Missing current-schema writer giảm hai candidate commits thành một, bỏ generation-success rồi partial wrapper-failure window. Preparation chỉ gọi khi read miss; boot NSDateFormatter vẫn chỉ tạo theo yêu cầu như cũ.

Read-only mode vẫn đọc legacy files nối tiếp, không phải captured source snapshot. Lifecycle ownership chỉ serialize cooperating lifecycle writers; bypass source writers/direct migration và post-checkpoint namespace changes vẫn là giới hạn. Existing `profileIdentityPath` preflight migration/path repair dưới root lease có thể commit trước target pin/candidate transaction và không rollback cùng candidate. Không claim root creation, directory durability hoặc power-loss guarantees.

## Kiểm chứng

Identifier native runner extract exact wrapper/helper production methods và link actual artifact preparation/staging engines cùng scope/lifecycle/source store. Fake provider giữ deterministic read hits/misses để fault-inject timing; không copy commit logic. Artifact-preparation runner extract actual generation-disabled getters/adapters/provider helper để kiểm tra precedence, miss/fallback và malformed fields, bên cạnh H3F ownership tests cũ.

Native scenarios mới bao uptime/boot × hit/miss: busy/pending trước target/read/provider; read re-entry fail busy; đúng một candidate commit, unchanged counter và adoption sau release; formats và cả hai records trên miss; read/provider exceptions; late deletion; missing/replaced/symlink identity; source-written fault rollback bytes/pair/scalar/commit token và suppress adoption. Callback probes xem committed pair sau lease release.

Actual read-only getter cases giữ competing root owner nhưng không acquire/generate/persist/adopt: boot precedence, uptime sidecar và device_ids fallback, malformed sidecar/scalar fields, absent profile, legacy safe default khi generation busy. Clock-dependent assertions dùng before/after read bounds, không dùng fixed benchmark hoặc timestamp tolerance tùy ý. Macro validation bao hai fixtures.

Windows pass 15 source/host gates: identifier, artifact preparation/writers, profile creation, device-group, identity preparation, generation, source transactions, telephony, snapshot reader/consumers/publisher, release hardening, RootHide static và thread-safety cleanup (80/80). Exact native extraction pass: identifier 4 fragments, artifact preparation 6, device-group 3, profile creation 3. Git diff check sạch.

Foundation/xcrun/Theos không có trên máy Windows; native compile/runtime và package build H3L cần macOS CI. RootHide-defined fixture không xác minh actual SDK paths, jailbreak namespace hoặc injected iOS process behavior.

## Phần còn lại

Direct/read-triggered migration cần explicit ownership/composition design để không acquire lồng từ reader, batch hoặc resolver. Dashboard preview, metadata/defaults/security authority, cache/thread safety/publication ordering, rootful captured readers và directory cleanup/durability vẫn pending/partial. Không thêm recovery cleanup retry hoặc thay behavior của các writer chưa enroll.
