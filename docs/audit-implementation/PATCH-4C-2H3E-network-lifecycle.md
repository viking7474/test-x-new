# Patch 4C.2H3E — standalone network lifecycle ownership

Người dùng xác nhận build H3D pass. H3E enroll các source writers trong NetworkManager vào lifecycle ownership hiện có. Chỉ nhóm network/carrier được thêm ở mốc này; Patch 4 vẫn partial.

## Vấn đề và thay đổi

NetworkManager đã commit network/carrier/device_ids dưới source transaction nhưng chưa giữ lifecycle ownership qua target resolution, interface/carrier preparation và persistence. Các getters có đường generate-and-save khi thiếu dữ liệu, nên chỉ bọc ba API save công khai chưa đủ. Cooperating delete/switch/recovery có thể chạy giữa lookup và write; source gate không tự bảo vệ khoảng thời gian đó.

`PXProfileArtifactMutation` là synchronous scope mới cho standalone artifact mutation. Scope acquire nonblocking lifecycle lease trên configured profiles root, kiểm tra pending delete journal rồi mới gọi target resolver ngoài source gate. Scope chỉ nhận canonical identity path của một profile directory đang tồn tại, giữ identity descriptor với O_DIRECTORY/O_NOFOLLOW/O_CLOEXEC và parent directory proof. Không tạo/adopt directory bị thiếu.

Mỗi source write qua scope kiểm tra configured root/lease, parent proof, identity pathname so với held descriptor và journal absence **trước** staging body. Context không acquire ownership trong source gate và không gọi providers, log, notification hoặc cache publication tại đó. Descriptor được giữ tới invalidate/dealloc để inode identity cũ chưa thể được reuse trong scope. Checks không biến path-based source engine thành descriptor-relative namespace isolation; external writer thay path sau checkpoint vẫn nằm ngoài cooperation contract.

NetworkManager nay có ba persistence helpers nhận scope sẵn có, không acquire lại. Public IPv4, IPv4/IPv6 và carrier save acquire trước active-target lookup; optional IPv6 provider chạy khi lifecycle held nhưng source gate đã nhả. Stage helpers vẫn pure/composable để batch regenerate và create dùng mà không tự conflict với lease đang giữ.

Forced IP/carrier refresh acquire trước lookup/provider và commit đúng target đã capture. Non-forced getters giữ nguyên saved-value read precedence; read hit không acquire lifecycle hoặc source lock mới. Khi miss, getter acquire rồi re-resolve active target để kiểm tra vẫn đúng path vừa đọc. Selection đổi trước acquire khiến fallback trả nil, không generate vào profile cũ hoặc redirect candidate sang profile mới. Một miss có thêm lần target lookup; không thêm lookup này vào read hit hoặc forced-refresh target capture.

## Behavior và error handling

- Busy lease hoặc pending recovery trước generation: saves trả NO; generating getters trả nil trước provider. Saved read hits vẫn hoạt động theo contract đọc cũ.
- Lease được giữ xuyên provider và commit, nhả trong finally trên normal return và provider exception. Không swallow exception mà API provider trước đây đã propagate. Factory resolver throw cũng nhả ownership/descriptors.
- Một khi generation đã bắt đầu, getter vẫn trả candidate theo behavior cũ kể cả source commit fail; không coi return value này là persistence acknowledgement. BOOL saves phản ánh kết quả commit.
- Giữ IPv6 precedence: network_settings trước device_ids; existing IPv6 tránh generation; single-IPv4 update rechecks và giữ IPv6 do bypass writer vừa commit. Giữ nil-address/no-change semantics, empty-single-IPv4 rejection, carrier nil-to-empty fields và interface generation policy hiện có.
- Không thêm lock quanh generate-only API: batch/create tiếp tục dùng pure network preparation dưới ownership của chính chúng. Caller UI tự generate trước khi gọi save chưa phải một lifecycle operation chung; H3E chỉ enroll các mutation entry points của NetworkManager.

## Kiểm chứng và giới hạn

Native runner compile NetworkManager, CarrierDB, source store, pure stage helpers và ownership scope thật; fixture thay paths/role, provider outputs, log sink và hai RootHide namespace adapters như mô tả bên dưới. Runner build cả rootful và RootHide defines, chạy mỗi binary ba lần trên macOS CI. Các case cũ về merge, IPv6 precedence, fixed target, rollback, malformed artifact và concurrent disjoint updates vẫn giữ. Lượt define RootHide là fixture trên macOS, không phải kiểm chứng RootHide SDK/namespace thực tế.

Fixture mới kiểm tra busy/pending trước lookup/provider/source gate; saved reads dưới competing lease không vào writer gate; busy read miss không generate; provider reentry trả busy; lease held qua IPv6 preparation; release trước save log/return; exception trong single-address/forced-IP/IPv6/carrier; selection đổi giữa read miss và ownership; late delete journal; identity missing/replaced/symlink; absent profile không được tái tạo; invalidated capability không gọi stage body; malformed/throwing resolver; descriptor closure qua success/failure/exception/dealloc. Fault injection còn kiểm tra candidate-return compatibility khi forced-refresh persistence rollback.

Concurrent fixture có bounded caller retries cho nonblocking busy, không thêm retry vào production. Fixture target tree dùng `<profiles>/<id>/identity` và allowlist thêm selection/journal paths đúng dependency của production ownership. Macro argument guard bao phủ cả artifact fixture để chặn lỗi CHECK với Objective-C literals/blocks trước native compile.

Windows đã pass 14 source/host gates liên quan, macro validation, exact native-fragment extraction cho các fixtures phụ thuộc và git diff check. Không chạy được Foundation/Theos native ở máy này; build/native H3E chờ macOS CI. Build pass của H3D không thay cho kết quả H3E hoặc iOS device matrix.

### Sửa dependency của native fixture sau phản hồi CI

Lượt native RootHide ban đầu fail khi compile CarrierDB: define `THEOS_PACKAGE_SCHEME_ROOTHIDE` làm PXJailbreakCompat import `<roothide.h>`, nhưng bước Foundation fixture chạy trước Theos/RootHide SDK setup. Đây là thiếu dependency trong runner mới, không phải lý do để thêm fallback vào production compatibility header hoặc bỏ lượt kiểm thử.

Runner dùng chung `native_compile_command` và copy `tests/native/roothide/roothide.h` vào include directory tạm riêng cho lượt RootHide. Header có hard error nếu thiếu source-transaction-testing hoặc RootHide define; Makefile production không thêm directory này. Shim cung cấp identity adapters cho NSString `jbroot`/`rootfs`, vì profiles/path backend của lifecycle fixture đã dùng temporary tree. Không mô phỏng hoặc xác nhận randomized jbroot translation. CarrierDB thật vẫn được compile; không thay source dependency bằng class giả. Production tiếp tục bắt buộc RootHide SDK thật, và Theos/package/device gates vẫn có boundary riêng.

Host regression gọi đúng command builder, kiểm tra header thật được copy vào include path, RootHide define và testing guard có mặt, rootful command không nhận shim, và source list vẫn có CarrierDB/NetworkManager. Artifact writer, profile flow/macro validation, RootHide build static và release hardening static gates đã pass sau sửa, cùng git diff check. Native compile/runtime sau sửa vẫn chờ macOS CI; host regression không được coi là native pass.

Cold network mutations thêm lifecycle flock, target/directory stat, một identity FD và pending-state reads. Relative overhead dự kiến low–moderate, chưa benchmark; source gate vẫn không bao provider/interface enumeration. Read hits không nhận thêm flock/source transaction. Scope tăng ba descriptor trong thời gian operation (hai từ lease, một identity FD), không thêm timer, queue thường trực, network request hoặc polling. Lifecycle operations khác có thể trả busy trong lúc provider chạy.

Standalone IdentifierManager scalar/model/telephony/migration, WiFi/Battery/Uptime/Storage, dashboard preview, metadata sidecars, preferences/security authority, total cache ordering, rootful reader rollout và directory cleanup/durability vẫn partial/pending. Read hits vẫn là legacy live-file readers, chưa có atomic captured-snapshot guarantee. Không claim protection với old binaries/direct external writers, không recursive cleanup/retry và không claim power-loss durability. Các bước tiếp theo cần enroll remaining writers trước khi kết luận full source/directory consistency.
