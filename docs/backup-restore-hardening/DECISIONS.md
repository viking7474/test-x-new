# Decision Log

Tài liệu này ghi các quyết định đã chốt trong quá trình triển khai. Agent không được tự thay đổi quyết định đã chốt; mọi đề xuất thay đổi phải ghi trong report để coordinator review.

## D-001 — One task at a time

- Status: Accepted
- Decision: Chỉ một task được mở tại mỗi thời điểm.
- Reason: Giảm phạm vi diff và xác định chính xác nguyên nhân khi build/runtime thất bại.

## D-002 — GitHub Actions is the build gate

- Status: Accepted
- Decision: Chủ dự án tự chạy build bằng GitHub Actions và gửi kết quả lại.
- Reason: Môi trường hiện tại không được xem là nguồn xác nhận build cuối cùng.

## D-003 — Separate task specification and agent report

- Status: Accepted
- Decision: Agent không sửa task specification để mô tả kết quả. Kết quả phải nằm trong file `reports/TASK-x.y-REPORT.md`.
- Reason: Giữ nguyên yêu cầu ban đầu để có thể đối chiếu với diff và report.

## D-004 — No automatic progression

- Status: Accepted
- Decision: Agent phải dừng sau task hiện tại. Task kế tiếp chỉ được tạo hoặc mở sau review và build gate.
- Reason: Ngăn thay đổi dây chuyền khi nền tảng trước chưa ổn định.

## D-005 — Compatibility before migration

- Status: Accepted
- Decision: Các API mới phải được thêm theo hướng tương thích trước; caller chỉ migrate trong task chuyên biệt.
- Reason: Tránh vừa đổi contract vừa đổi behavior trong cùng một diff.

## D-006 — Build success is necessary but not sufficient

- Status: Accepted
- Decision: Build xanh không tự động đồng nghĩa task hoàn thành. Vẫn cần review scope, contract và safety behavior.
- Reason: Nhiều regression destructive vẫn có thể compile thành công.

## D-007 — Deadline API is opt-in until process-group hardening

- Status: Accepted
- Decision: TASK-0.2 thêm overload deadline/output-cap thật nhưng không áp policy mới cho `runAndCapture:` legacy và không migrate caller.
- Reason: Trước TASK-0.3, timeout chỉ có thể terminate direct child PID; áp mặc định cho shell command hiện tại có thể để lại pipeline/background descendant.

## D-008 — Output limit is per stream and must keep draining

- Status: Accepted
- Decision: `maxOutputBytes` giới hạn riêng stdout và stderr. Khi đạt cap, runner tiếp tục đọc rồi discard để child không block vì pipe đầy.
- Reason: Dừng đọc sau cap sẽ biến cơ chế bảo vệ bộ nhớ thành một deadlock mới.

## D-009 — Timeout is a dedicated result state

- Status: Accepted
- Decision: Timeout thành công về mặt runner được biểu diễn bằng `timedOut = YES`, không dùng synthetic exit code và không tự động gán `runnerError = ETIMEDOUT`.
- Reason: Phân biệt deadline policy với child exit, spawn failure và runner failure.

## D-010 — Deadlines and duration use monotonic time

- Status: Accepted
- Decision: Deadline và `duration` phải dùng monotonic clock; không dùng wall clock hoặc `NSDate`.
- Reason: Thay đổi giờ hệ thống, timezone hoặc clock synchronization không được kéo dài hay rút ngắn command deadline.

## D-011 — Process groups are created atomically at spawn time

- Status: Accepted
- Decision: Bounded command dùng `POSIX_SPAWN_SETPGROUP` với pgroup `0`; không dùng `setpgid` sau spawn.
- Reason: Post-spawn `setpgid` có race nơi child hoặc descendant chạy trước khi group ownership được thiết lập.

## D-012 — Process-group policy remains opt-in

- Status: Accepted
- Decision: Chỉ overload bounded bật process-group creation và group-scoped termination. `run:` và `runAndCapture:` legacy giữ nguyên policy.
- Reason: Thay đổi process group của API legacy có thể làm thay đổi signal/job-control semantics trước khi caller migration được review riêng.

## D-013 — Final group signal precedes leader reap

- Status: Accepted
- Decision: Trong timeout path, final group `SIGKILL` phải được gửi trước khi direct child/group leader được reap. Khi descendant còn giữ capture pipe, bounded loop defer direct-child reap.
- Reason: PGID bằng child PID. Reap leader quá sớm cho phép PID/PGID tái sử dụng, tạo nguy cơ signal nhầm process group khác.

## D-014 — Process-group termination is not process-tree enumeration

- Status: Accepted
- Decision: TASK-0.3 chỉ terminate process còn trong inherited command group; process cố ý escape bằng `setsid`, group khác hoặc daemonization nằm ngoài scope.
- Reason: Process-tree scanning/kill-by-name không đáng tin cậy, dễ tác động process không thuộc command và cần thiết kế riêng.

## D-015 — Direct execution is bounded-only

- Status: Accepted
- Decision: Public direct-executable API đầu tiên luôn yêu cầu `timeoutSec` và `maxOutputBytes`; không thêm unbounded direct convenience API trong TASK-0.4.
- Reason: API mới dành cho critical operations nên phải dùng deadline, bounded output và process-group cleanup ngay từ contract đầu tiên.

## D-016 — Direct API receives argv, not a command line

- Status: Accepted
- Decision: Caller truyền absolute executable path và `arguments` tương ứng `argv[1...]`; runner tự tạo `argv[0]`. Không shell parsing, quoting, PATH search hoặc argument joining.
- Reason: Tách data khỏi command syntax, tránh ambiguity và tạo nền tảng migration có thể kiểm chứng.

## D-017 — argv memory is owned and validated

- Status: Accepted
- Decision: Runner tạo owned lossless UTF-8 copies, reject embedded NUL/non-string input, kiểm tra overflow và cleanup partial allocation trên mọi path.
- Reason: Không dựa vào lifetime ngầm của `UTF8String` và không cho C argv bị truncate âm thầm tại embedded NUL.

## D-018 — Direct API inherits environment without changing shell compatibility

- Status: Accepted
- Decision: Direct executable API truyền current process environment bằng `environ`; shell APIs hiện hữu giữ environment-pointer behavior hiện tại trong TASK-0.4.
- Reason: Executable trực tiếp cần environment ổn định, nhưng thay đổi shell API hiện hữu phải được tránh trong task contract mới.

## D-019 — Contract before caller migration

- Status: Accepted
- Decision: TASK-0.4 chỉ thêm/refactor command-runner infrastructure; không chuyển `tar`, `ldid`, keychain helper hoặc destructive caller sang API mới.
- Reason: Tách API correctness khỏi thay đổi nghiệp vụ và giúp xác định regression theo từng task.

## D-020 — AppDataCleaner void APIs remain compatibility shims

- Status: Accepted
- Decision: TASK-0.5 giữ nguyên các selector `void` hiện tại và cho chúng delegate sang một private method trả `CommandResult`.
- Reason: Hàng trăm caller hiện không xử lý result; thay đồng thời signature và control flow sẽ làm diff quá rộng và khó xác định regression.

## D-021 — Cleaner shell wrapper uses bounded capture

- Status: Accepted
- Decision: Private result wrapper trong `AppDataCleaner` dùng bounded shell API với deadline hiện có và cap cố định 1 MiB cho từng stream.
- Reason: Các command hiện tại phụ thuộc shell syntax, nhưng vẫn cần deadline, bounded memory và spawn-time process-group cleanup từ `CommandRunner`.

## D-022 — Result availability precedes failure propagation

- Status: Accepted
- Decision: TASK-0.5 chỉ làm structured result khả dụng; existing Clear flow vẫn bỏ qua result và không thay đổi success/failure/UI decision.
- Reason: Failure propagation phải được thực hiện cùng typed Clear result và component policy trong Phase 1, không trộn vào compatibility migration.

## D-023 — Remaining launch paths must be inventoried

- Status: Accepted
- Decision: TASK-0.5 phải liệt kê mọi `posix_spawn`, `NSTask`, wait và process-launch path còn lại trong `AppDataCleaner.m`; coordinator quyết định có cần thêm Phase 0 task hay không.
- Reason: Hoàn thành một wrapper không đồng nghĩa toàn bộ file đã loại bỏ hang, unbounded output hoặc duplicate execution logic.

## D-024 — Remaining AppDataCleaner launch hardening is split into two tasks

- Status: Accepted
- Decision: `runCommandAndGetOutput:` được xử lý riêng trong TASK-0.6; hai direct `find` helper được giữ cho TASK-0.7.
- Reason: Tách deadlock `NSTask` khỏi direct-executable migration giúp diff nhỏ, build gate rõ và tránh thay nhiều output contract trong một commit.

## D-025 — Output query compatibility uses bounded shell execution

- Status: Accepted
- Decision: `runCommandAndGetOutput:` giữ selector/string contract nhưng delegate qua bounded `runCommandWithPrivilegesResult:timeoutSec:` với default timeout 60 giây.
- Reason: Caller hiện dùng shell pipeline, redirect và sqlite/find expressions; mục tiêu là loại deadlock và unbounded capture mà không đổi command syntax.

## D-026 — Incomplete query output is not trustworthy

- Status: Accepted
- Decision: Invalid input, spawn/runner failure, timeout, signal termination hoặc stdout/stderr truncation được map sang sentinel `@"error"`; normal non-zero exit không tự động trở thành error nếu execution hoàn tất bình thường.
- Reason: Caller không được ra quyết định từ output thiếu, nhưng behavior cũ vẫn trả output của command non-zero nên cần giữ tương thích đó.

## D-027 — Separate captures are merged deterministically

- Status: Accepted
- Decision: Output query merge stdout trước, thêm newline khi cần, rồi stderr và trim một lần; không rewrite command bằng `2>&1`.
- Reason: `CommandRunner` capture hai stream riêng nên không thể khôi phục interleaving byte-level; deterministic merge giữ cả hai stream mà không làm thay đổi shell command.

## D-028 — Process-exit probes have their own deadline

- Status: Accepted
- Decision: `PXWaitForProcessExit` dùng timed output-query overload với mỗi probe tối đa một giây và không coi `@"error"` là process đã thoát.
- Reason: Outer timeout không có ý nghĩa nếu một `pgrep` probe có thể block vô hạn; error phải fail closed thay vì tạo false exit detection.

## D-029 — Direct find helpers must use the shared direct-executable contract

- Status: Accepted
- Decision: TASK-0.7 chuyển cả hai helper `find` trong `AppDataCleaner.m` sang `runExecutableAndCapture:arguments:timeoutSec:maxOutputBytes:` với executable chính xác `/usr/bin/find`; không shell và không local spawn/pipe engine.
- Reason: Hai helper là các đường local process execution cuối cùng còn blocking, unbounded và duplicate lifecycle logic trước khi Phase 1 bắt đầu.

## D-030 — Find execution has one fixed bounded policy

- Status: Accepted
- Decision: Mỗi invocation của direct find helper dùng deadline 120 giây và cap 4 MiB riêng cho stdout/stderr.
- Reason: Một policy cố định giúp caller giữ nguyên, tránh unbounded traversal/output và tạo build gate rõ trước khi thay đổi destructive path semantics.

## D-031 — Incomplete find output fails closed

- Status: Accepted
- Decision: Invalid input, spawn/runner failure, timeout, signal termination hoặc stream truncation trả `@[]`; không parse hay trả path list một phần. Normal non-zero exit vẫn có thể dùng stdout hoàn chỉnh.
- Reason: Danh sách path thiếu không đủ tin cậy cho destructive operations, nhưng `find` có thể emit match hợp lệ rồi exit non-zero do lỗi cục bộ nên complete stdout vẫn giữ compatibility.

## D-032 — Find path parsing is stdout-only

- Status: Accepted
- Decision: Direct find helpers chỉ split `stdoutString`; stderr không được merge thành path. Order, duplicate và non-empty line content được giữ nguyên, không trim/sort/canonicalize/deduplicate.
- Reason: Implementations cũ chỉ đọc stdout. Captured stderr là diagnostic data, không phải filesystem path.

## D-033 — Phase 0 closes only after TASK-0.7 gate

- Status: Accepted
- Decision: TASK-1.1 chỉ được mở sau khi TASK-0.7 qua source review và GitHub Actions, đồng thời `AppDataCleaner.m` không còn local `posix_spawn`, pipe capture hoặc blocking `waitpid` process engine.
- Reason: Clear Data safety work không nên xây trên nền execution vẫn có thể treo hoặc trả output không đầy đủ.

## D-034 — Resolved container identity precedes resolver migration

- Status: Accepted
- Decision: TASK-1.1 chỉ thêm immutable `PXResolvedContainer`; không resolver hoặc caller hiện hữu nào được migrate trong cùng task.
- Reason: Tách correctness của value object khỏi filesystem discovery và destructive behavior giúp build/review gate xác định chính xác regression.

## D-035 — Application bundle is not a clearable resolved-container kind

- Status: Accepted
- Decision: `PXResolvedContainerKind` chỉ gồm application data, app group, extension data và PluginKit data; không có application bundle, unknown hoặc any kind.
- Reason: Application bundle là code/install content, không phải mutable data target. Phase 1 sẽ loại bỏ destructive writes vào bundle containers thay vì hợp thức hóa chúng trong model mới.

## D-036 — Resolved identity requires exact metadata equality

- Status: Accepted
- Decision: Một `PXResolvedContainer` chỉ được tạo khi requested identifier và metadata identifier bằng nhau chính xác, case-sensitive; fuzzy/prefix/suffix/substring match không thể được biểu diễn.
- Reason: Approximate identity không đủ an toàn để đi vào destructive path planning.

## D-037 — Immutable identity is not deletion authorization

- Status: Accepted
- Decision: `PXResolvedContainer` chỉ giữ immutable identity và candidate path. Nó không kiểm tra filesystem, canonical root, symlink, ownership hoặc quyền xóa.
- Reason: Canonical destructive-path policy phải được tập trung trong TASK-1.3, không phân tán vào constructor hay resolver.

## D-038 — Candidate paths receive lexical checks only in TASK-1.1

- Status: Accepted
- Decision: Initializer kiểm tra absolute/non-root/no-trailing-slash/no-dot-component/no-NUL/UUID-last-component, nhưng không standardize, resolve symlink hoặc áp base-path allow-list.
- Reason: Loại bỏ input cấu trúc rõ ràng nguy hiểm mà vẫn giữ ranh giới giữa immutable model và filesystem validator.

## D-039 — Immutable value semantics are explicit

- Status: Accepted
- Decision: `PXResolvedContainer` copy toàn bộ string input, không có setter/readwrite property, `copyWithZone:` trả self và equality/hash dùng toàn bộ identity fields.
- Reason: Snapshot phải ổn định khi truyền qua resolver, validator và plan; mutable alias hoặc identity-by-pointer sẽ tạo TOCTOU và dedup ambiguity.

## D-040 — Exact application-data resolution is root-specific

- Status: Accepted
- Decision: TASK-1.2 resolve một root mỗi lần qua `PXResolvedContainerRoot`; rootful dùng `/private/var/mobile/Containers/Data/Application`, rootless dùng `/containers/Data/Application`.
- Reason: Root-specific result tránh trộn namespace, giữ semantics rõ và cho phép caller tương lai xử lý rootful/rootless độc lập.

## D-041 — Resolver identity comes only from exact MCM metadata

- Status: Accepted
- Decision: TASK-1.2 chỉ đọc `.com.apple.mobile_container_manager.metadata.plist`, chỉ nhận string `MCMMetadataIdentifier` và chỉ match bằng case-sensitive `isEqualToString:`.
- Reason: Prefix, substring, company/app-name và content heuristics không đủ mạnh để tạo destructive identity.

## D-042 — Rootful resolver uses one canonical spelling

- Status: Accepted
- Decision: TASK-1.2 không scan thêm `/var/mobile/Containers/Data/Application`; rootful candidate được dựng từ `/private/var/mobile/Containers/Data/Application` duy nhất.
- Reason: Scan cả alias `/var` và `/private/var` có thể tạo duplicate giả và làm ambiguity phụ thuộc filesystem alias.

## D-043 — Multiple exact matches fail closed

- Status: Accepted
- Decision: Resolver trả tối đa một application-data container cho mỗi root. Hai hoặc nhiều exact match trong cùng root trả ambiguity error và không chọn first/newest/arbitrary match.
- Reason: Multiple exact metadata mappings là trạng thái không an toàn cho destructive selection; thứ tự directory không được quyết định target.

## D-044 — Exact resolution still does not authorize deletion

- Status: Accepted
- Decision: TASK-1.2 có thể enumerate filesystem và tạo candidate object nhưng không canonicalize symlink/mount/ownership hoặc cung cấp deletion eligibility.
- Reason: TASK-1.3 phải là một canonical safety boundary duy nhất trước khi bất kỳ caller phá hủy nào dùng resolver result.

## D-045 — Validator returns the canonical path to be used

- Status: Accepted
- Decision: TASK-1.3 trả canonical `NSString` path khi validation thành công; không trả BOOL và không yêu cầu caller tiếp tục dùng `PXResolvedContainer.containerPath` thô.
- Reason: Safety boundary phải truyền ra đúng filesystem target đã canonicalize. Trả BOOL rồi dùng lại raw path sẽ làm mất kết quả canonicalization và tái mở alias/symlink ambiguity.

## D-046 — Kind and root map to one fixed lexical base

- Status: Accepted
- Decision: Mỗi combination `PXResolvedContainerKind`/`PXResolvedContainerRoot` map tới đúng một base allow-list; raw candidate phải bằng chính xác `base + UUID` trước canonicalization. Application bundle không có mapping.
- Reason: Candidate do caller hoặc resolver dựng không được chọn base tùy ý, dùng `/var` alias hoặc đổi kind để mở rộng destructive namespace.

## D-047 — Canonical containment is immediate-child equality, not prefix matching

- Status: Accepted
- Decision: Canonical candidate phải có parent bằng chính xác canonical base và last component bằng UUID. Không dùng `hasPrefix:` để authorize containment.
- Reason: Prefix comparison nhận nhầm sibling như `/base2` và không chứng minh target là đúng một container child.

## D-048 — Symlink, mount, ownership and mode failures are fail-closed

- Status: Accepted
- Decision: Validator dùng `lstat`, `realpath` và `stat`; reject candidate/metadata symlink, cross-device child mount, non-mobile ownership và world-writable base/candidate/metadata.
- Reason: Exact metadata identity không đủ nếu filesystem object có thể redirect, bị mount thay thế hoặc được actor không phù hợp sửa đổi.

## D-049 — Live metadata identity is revalidated at the canonical target

- Status: Accepted
- Decision: Validator đọc lại `.com.apple.mobile_container_manager.metadata.plist` dưới canonical candidate và exact-match `MCMMetadataIdentifier`; AppGroup cho phép string hoặc array có đúng một exact occurrence.
- Reason: `PXResolvedContainer` là snapshot có thể được tạo trước đó hoặc thủ công. Destructive authorization phải dựa trên metadata hiện tại tại target đã canonicalize.

## D-050 — Validation includes final filesystem identity rechecks

- Status: Accepted
- Decision: Sau metadata read, validator `lstat` lại candidate và metadata, yêu cầu device/inode không đổi trước khi trả canonical path.
- Reason: Recheck giảm cửa sổ TOCTOU trong chính validation. Kết quả vẫn chỉ đúng tại thời điểm kiểm tra nên caller tương lai phải validate ngay trước thao tác.

## D-051 — Validator contract precedes destructive caller integration

- Status: Accepted
- Decision: TASK-1.3 chỉ thêm standalone validator; không existing caller nào được import hoặc dùng output để xóa trong cùng task.
- Reason: Review canonical safety correctness phải tách khỏi thay đổi behavior của application-bundle và Clear migration.

## D-052 — Application bundle containers are read-only Clear inputs

- Status: Accepted
- Decision: TASK-1.4 loại bỏ mọi active write của `AppDataCleaner` dưới `/var/containers/Bundle/Application`, `/var/mobile/Containers/Bundle/Application` và `/containers/Bundle/Application`.
- Reason: Bundle containers chứa installed code/resources, không phải mutable application data. Clear Data không được xóa receipt, extension code hoặc nội dung bundle để giả lập reset.

## D-053 — Receipt clear selector remains as a non-mutating compatibility shim

- Status: Accepted
- Decision: Public selector `clearAppReceiptData:withBundleUUID:` giữ nguyên ABI nhưng chỉ log việc bỏ qua receipt mutation và không truy cập filesystem hay chạy command.
- Reason: Xóa selector công khai trong cùng task có thể phá caller ngoài repo; compatibility no-op loại bỏ write mà không mở rộng API migration.

## D-054 — Read-only bundle discovery remains available

- Status: Accepted
- Decision: TASK-1.4 giữ các bundle UUID/Info.plist resolver, process-name lookup, extension discovery và bundle-size calculation nếu chúng chỉ đọc.
- Reason: Mục tiêu là loại write vào code container, không làm mất các chức năng inspection hiện hữu hoặc trộn resolver cleanup vào behavior-removal diff.

## D-055 — Application-bundle writes are removed, not validated

- Status: Accepted
- Decision: TASK-1.4 không import `PXDestructivePathValidator` để hợp thức hóa bundle mutation; application bundle không có `PXResolvedContainerKind` và không được đưa vào destructive allow-list.
- Reason: Validator dành cho mutable data containers. Code/install content phải read-only thay vì trở thành một target destructive được canonicalize.

## D-056 — Generic destructive helpers are not redesigned in TASK-1.4

- Status: Accepted
- Decision: `fixPermissionsAndRemovePath:`, `wipeDirectoryContents:` và các generic helper khác giữ nguyên; TASK-1.4 chỉ loại mọi in-file application-bundle path truyền vào chúng.
- Reason: Các helper còn phục vụ nhiều data path. Quarantine public destructive API và permission behavior thuộc TASK-1.11/TASK-1.12, không nên trộn vào bundle-write removal.

## D-057 — Clear scope is an explicit closed option set

- Status: Accepted
- Decision: `PXClearScope` chỉ gồm ApplicationData, ExtensionData, AppGroups, PluginKitData và Keychain. Zero mask và unknown bits bị reject.
- Reason: Request phải biểu diễn chính xác các component đã được lên kế hoạch migrate; open-ended/custom bits sẽ làm caller và result policy không thể kiểm chứng.

## D-058 — Application bundle is absent from the Clear request model

- Status: Accepted
- Decision: Không có application-bundle hoặc receipt scope trong `PXClearRequest`.
- Reason: TASK-1.4 đã thiết lập application bundle là read-only. Đưa bundle mutation trở lại dưới một scope mới sẽ phá safety boundary vừa đóng.

## D-059 — Default Clear request includes all approved typed components

- Status: Accepted
- Decision: `PXClearScopeDefaultMask` bằng union của cả năm known bits; default factory đặt `deepClean = NO`.
- Reason: Factory phải thay thế intent của legacy full Clear ở mức component đã được approve nhưng không tự kích hoạt deep/aggressive behavior.

## D-060 — Request validation is strict and non-normalizing

- Status: Accepted
- Decision: Bundle identifier phải là chuỗi ASCII bundle-safe, không NUL/slash/wildcard/empty component; accepted value được giữ nguyên, không trim/lowercase/normalize.
- Reason: Identity không được silently rewrite trước resolver/result correlation. Invalid input phải fail tại model boundary thay vì tạo target gần đúng.

## D-061 — Deep-clean intent is data, not behavior, in TASK-1.5

- Status: Accepted
- Decision: `PXClearRequest` lưu boolean deep-clean chính xác nhưng không đọc global setting và không thực thi policy.
- Reason: Loại hidden input khỏi orchestration tương lai, đồng thời giữ TASK-1.5 là value-object-only diff.

## D-062 — Typed request precedes typed result and caller migration

- Status: Accepted
- Decision: TASK-1.5 không được import vào existing production caller; TASK-1.6 xây result độc lập trước khi TASK-1.7 bắt đầu migration.
- Reason: Request validation/copy/equality, result semantics và destructive integration cần ba review gate riêng để tránh thay contract và behavior trong cùng diff.
