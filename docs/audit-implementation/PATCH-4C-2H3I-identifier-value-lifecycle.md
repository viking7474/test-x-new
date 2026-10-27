# Patch 4C.2H3I — standalone identifier value lifecycle

Người dùng xác nhận build H3H pass, gồm native header và XML timestamp fixture fixes. H3I đưa standalone scalar/UUID/UDID generators, custom scalar persistence, ATT và theme setters vào lifecycle ownership hiện có. Patch 4 vẫn partial; chưa triển khai Patch 5–8.

## Vấn đề và phạm vi

Các writer này đã có source transaction cho paired sidecar/device_ids, nhưng target lookup và preparation nằm ngoài profile lifecycle ownership. Cooperating deletion/switch/create có thể đi qua khoảng giữa lookup và commit. Source serialization riêng không bảo vệ profile namespace hoặc target lifetime trong khoảng đó. Đây là khoảng trống chứng minh từ call flow; chưa có device race benchmark/reproducer.

`currentIdentifierMutation` acquire nonblocking root lease, kiểm tra configured root/pending deletion rồi mới gọi `profileIdentityPath`. Scope pin identity directory và profile proof; trước staging, scope revalidate root/profile/identity và late deletion journal. Busy trả error 12; pending recovery trả error 27. Không thêm implicit recursive ownership hoặc wait/retry loop.

Generators giữ scope qua provider và source commit. Custom value/type được copy trước lookup; theme value cũng copy trước validation. ATT clamp 0–3, Light/Dark validation, formats, generation-counter policy và sidecar registry giữ nguyên. Failure không publish compatibility cache. Finally invalidate trên success, early return hoặc exception, trước standalone compatibility setters/logging. Provider exceptions vẫn propagate; source commit đã thành công không bị compensation vì callback về sau lỗi.

## Schema preflight và reader boundary

`profileIdentityPath` giữ nguyên path repair/schema migration hiện có. Writer gọi nó sau khi lấy root lease; schema migration hoặc tạo identity có thể xảy ra trước final candidate transaction và trước identity FD được pin. Nếu scalar preparation sau đó fail, migration đã commit vẫn tồn tại. Không claim whole-operation rollback, missing-target-never-recreated, hoặc namespace isolation chống writer bỏ qua lease trong preflight.

Current-schema live reader không acquire lifecycle lease và vẫn không vào writer gate. Direct/read-triggered migration chưa được enroll lifecycle riêng: thêm lock ở đó ngay sẽ có nguy cơ acquire lồng từ resolver/batch. Configured profiles root phải tồn tại để acquire lease; writer không dựng root mới nhằm bỏ qua coordination failure. Existing resolver errors được giữ thay vì bị generic target error che mất.

ProfileManager create vẫn gọi `commitRuntimeGenerationForProfileID:networkArtifacts:lifecycleLease:error:`; batch/create dùng pure preparation/staging và capability riêng, không gọi các standalone scalar entry points mới bên trong lease. Không thay batch/create completion/activation contract.

## Performance và lifetime

Cold writes thêm lifecycle acquire, deletion-state reads và directory validation, expected relative cost low–moderate, chưa benchmark. Provider chạy ngoài source gate nhưng trong lifecycle scope để không đổi target giữa preparation và commit. Serial policy delay hiện có vẫn giữ; trong thời gian đó cooperating writer nhận busy thay vì block. Không thêm lock vào current-schema reads, timer, polling, network hoặc queue.

Scope giữ root lease và pinned identity FD; mọi nonnil scope của các entry points mới đều invalidate trong finally. Factory tự cleanup khi resolver fail/throw. Không giữ ownership qua standalone post-commit compatibility publication. Cache races/total ordering sau release vẫn là boundary riêng; không đổi active-ID publication policy của scalar setters trong mốc này.

## Kiểm chứng

Native identifier runner extract đúng production methods, import header thật cho artifact scope/lifecycle/deletion journal và link implementations cùng profile-selection/source/publisher engine. Chạy rootful và RootHide-defined fixtures; không dùng fake ownership implementation. Macro validation bao native identifier fixture để bắt CHECK arguments chứa Objective-C literal commas.

Cases thêm: mọi generator và custom/ATT/theme fail busy trước lookup/preparation; pending deletion; provider re-entry không deadlock; source gate không bao provider; provider/resolver exceptions nhả lease; late journal và identity missing/replaced/symlink reject trước staging; mutable custom value/type giữ cùng candidate cho source/publication; lease nhả trước compatibility callbacks/log; schema preflight vẫn tồn tại khi scalar prepare fail; exception unwinding reset migration guard. Các formatter, counter, migration rollback và current-schema read contracts trước đó vẫn giữ.

Windows pass 15 source/host gates: identifier writers, identity preparation, artifact writers/preparation, profile creation, source transactions, generation, device-group writers, telephony writers, snapshot reader/consumers/publisher, release hardening, RootHide static và thread-safety cleanup (80/80). Exact native fragments của identifier/device-group/profile/artifact preparation được tạo thành công; macro validation và git diff check pass.

Foundation compile/runtime và Theos build chưa chạy trên máy Windows này; mốc H3I cần macOS CI. RootHide-defined host fixture không xác nhận actual SDK paths, injected process behavior hoặc iOS device matrix.

## Phần còn lại

IdentifierManager uptime/boot compatibility wrappers chưa đổi: getters của UptimeManager có thể tự generate và lấy H3F lease; bọc thêm root lease sẽ tự conflict. Cần tách pure/read-only API hoặc truyền capability rõ ràng trước khi enroll wrappers. Theme generate/toggle vẫn trả candidate theo contract cũ, không biến return value thành persistence acknowledgement.

Standalone model/telephony, direct migration, dashboard preview, metadata/defaults/security authority, cache/thread safety/publication ordering, rootful captured readers và directory cleanup/durability vẫn partial/pending. Scope checkpoints không bảo vệ against external namespace changes sau checkpoint nếu writer bỏ qua ownership; không thêm power-loss/fsync guarantee hoặc automatic cleanup retry.
