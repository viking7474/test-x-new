# Patch 4C.2H3K — model/software/cellular lifecycle

Người dùng xác nhận build H3J pass. H3K enroll standalone model regeneration, custom model, software version generation và canonical cellular refresh vào lifecycle scope hiện có. Patch 4 vẫn partial; Patch 5–8 chưa triển khai.

## Vấn đề và thay đổi

Các writer đã có source transaction, owned-key replacement và journaled legacy sidecar removal; software/cellular refresh còn so captured dependencies trước stage. Tuy nhiên target lookup, source capture và preparation chưa giữ profile lifecycle ownership. Source gate không bảo vệ directory lifetime trong khoảng preparation. Nếu chỉ bọc từng method bằng lease, missing-model/software/cellular fallback gọi model regeneration sẽ acquire lồng và tự fail busy.

`regenerateDeviceProfileGroup`, `setCustomDeviceModel:`, `generateIOSVersion` và `refreshCanonicalCellularIdentityForCurrentProfile` nay dùng `currentIdentifierMutation`. Scope acquire trước target/schema lookup, pin identity/profile proof và giữ qua source capture, preparation tới commit. Commit đi qua `mutation performSourceWrite:` để revalidate root/profile/identity và absence của pending deletion trước staging. Mọi early return hoặc exception đều invalidate trong finally.

Private path-only regenerate helper được thay bằng `commitDeviceProfileGroupWithMutation:`. Helper nhận scope của caller, chuẩn bị và commit model tuple, trả immutable prepared packet. Helper không acquire, invalidate hoặc publish cache. Software/cellular thiếu model/regulatory/build truyền cùng scope vào helper nên không có recursive ownership. Top-level wrappers nhả scope trước compatibility publication. Whole batch/create vẫn gọi pure preparation/staging API riêng; không đổi capability/completion/activation flow của các mốc trước.

Custom model copy NSString input trước validation/DB callbacks. Membership validation vẫn đứng trước acquire như cũ: invalid input giữ error 2003 và không resolve target. Validation iPhone có thể đọc canonical DB trước acquire; scope bao target-dependent preparation sau đó. Không claim busy writer tránh toàn bộ DB work hoặc cold DB allocation. Normal software success clear error trước publication, tránh để error của một provider re-entry đã bị reject busy tồn tại dù outer commit thành công.

## Behavior được giữ

Không đổi canonical model/hardware selection, web-compat range, non-iPhone compatibility table, regional/baseband rules, missing-tuple fallback policy hoặc returned value shapes. Regenerate và cellular refresh/fallback tăng generation một lần; custom model và normal software refresh giữ counter. Owned-key replacement, stale-field clearing, paired legacy sidecar removal và dependency comparison với bypass-writer drift vẫn giữ nguyên.

Source commit thành công mới publish cache. Group publisher tiếp tục bắt exception theo policy cũ; normal software/custom model callbacks vẫn có thể propagate exception như trước. Source đã commit không bị compensation nếu post-commit callback lỗi. Software fallback vẫn publish rồi đọc lại fixed-target device_ids để tạo response như implementation cũ; scope đã nhả trước publication/read này. Không biến return dictionary thành captured transaction receipt hoặc claim callback/response total ordering.

## Boundary và performance

`profileIdentityPath` giữ path repair/schema migration preflight dưới root lease. Preflight có thể tạo directory/commit migration trước target pin và candidate transaction; candidate fail không rollback preflight. Direct/read-triggered migration chưa enroll lifecycle riêng. Root phải tồn tại để acquire; không thêm root creation để bỏ qua coordination. Scope checkpoints không namespace-isolate writers bỏ qua lease sau checkpoint.

Không thêm lock vào current-schema readers/hook hot paths, queue, timer, polling, network hoặc DB lookup lặp trong fallback. Cold writes thêm lifecycle acquire, deletion-state reads và directory validation, expected relative cost low–moderate, chưa benchmark. Existing DB load, model search và hardware table preparation có thể kéo dài thời gian giữ lifecycle scope; competing cooperating writer nhận busy thay vì chờ lifecycle lock. Provider/DB preparation chạy ngoài source gate. DB catalog synchronization, mutable manager settings/error và post-release cache ordering vẫn là boundary riêng.

Scope giữ root lease/pinned identity FD hiện có. Explicit invalidation trước success publication đi cùng idempotent finally cleanup để callback re-entry/exception không giữ ownership. Helper không giữ scope trong persistent block/queue. Initializers của DeviceModelManager/IPhoneModelDB/IOSBuildDB được kiểm tra: không gọi profile lifecycle mutation từ init; không cần thêm warm-up hoặc silent lease reuse ở mốc này.

## Kiểm chứng

Device-group runner extract exact production methods với signature helper mới; fixture vẫn link actual artifact scope/lifecycle/deletion/source engines. Macro arity validation bao native fixture. Existing source contracts được chuyển sang scope-aware commit/fallback/publication assertions; pure builder và batch/create contracts tiếp tục giữ.

Native regression thêm tám modes: regenerate, custom model, normal software, normal cellular, software missing-model fallback, cellular missing-model/regulatory/build fallbacks. Các modes kiểm tra busy/pending deletion trước target-dependent preparation/publication; resolver/provider giữ lifecycle nhưng không giữ source gate; provider re-entry fail busy; success clear error/counter đúng policy; provider exception; late journal; identity missing/replaced/symlink; source-written fault rollback tuple/sidecar bytes/counter/commit token/cache. Có lease-free probes và kiểm tra competing capability không bị invalidate.

Callback probes chỉ bật cho standalone tests, không suy caller-held create lease đã nhả. Callback re-entry sau publication release thực hiện cellular refresh mới; normal software publication exception vẫn giữ committed source. Tests còn kiểm tra mutable custom model input, non-iPhone compatibility, invalid-input validation precedence và missing selection ở bốn entry points. Existing dependency-drift, fixed-target, unrelated merge, counter exhaustion, canonical firmware failure và batch/create cases vẫn giữ.

Fixture dùng stub profile resolver; actual schema/path preflight và exception cleanup vẫn được bao bởi identifier-writer H3I exact-method fixture. Không suy từ stub thành full directory durability guarantee.

Windows pass 15 source/host gates: device-group, profile creation, telephony, generation, identifier, identity preparation, artifact writers/preparation, source transactions, snapshot reader/consumers/publisher, release hardening, RootHide static và thread-safety cleanup (80/80). Macro validation, exact device-group native extraction (3 fragments) và git diff check pass. Sau bổ sung non-iPhone/invalid-input/missing-selection cases, hai gates device-group/profile macro tiếp tục pass.

Máy Windows không có Foundation/xcrun/Theos. H3K native compile/runtime và package build cần macOS CI xác nhận; RootHide-defined fixture không xác minh SDK paths hoặc actual injected-process/iOS behavior.

## Tiếp theo

Uptime/boot compatibility wrappers, direct/read-triggered migration, dashboard preview, metadata/defaults/security authority, cache/thread safety/publication ordering, rootful captured readers và directory cleanup/durability vẫn pending/partial. Chưa thêm automatic recovery cleanup, fsync/power-loss guarantee hoặc thay behavior của các writer chưa enroll.
