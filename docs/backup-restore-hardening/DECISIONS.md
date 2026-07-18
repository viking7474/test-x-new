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

## D-063 — Clear result is an immutable final snapshot

- Status: Accepted
- Decision: `PXClearResult` and its nested models represent final structured outcomes only; they contain no pending/running state, callbacks, locks or execution methods.
- Reason: A value result must remain stable after publication and must not become a second orchestration engine.

## D-064 — Component status is closed to succeeded, skipped and failed

- Status: Accepted
- Decision: Per-scope status has exactly `Succeeded`, `Skipped` and `Failed`. Partial success is represented as `Failed` with both succeeded and failed unit counts greater than zero.
- Reason: A separate partial enum would duplicate count information and complicate aggregate masks; any failed unit must remain visible in `failedScopes`.

## D-065 — Failures are stable domain/code/message snapshots

- Status: Accepted
- Decision: Result state stores immutable `PXClearFailure` values rather than retaining `NSError` and arbitrary `userInfo` graphs.
- Reason: Mutable or non-value userInfo content would weaken copy/equality semantics and could retain unrelated objects across async boundaries.

## D-066 — Component counts form an exact partition

- Status: Accepted
- Decision: Every component enforces `succeeded <= attempted` and `failed == attempted - succeeded`; validation uses subtraction after an upper-bound check.
- Reason: Exact counts support multi-container scopes and partial outcomes while avoiding overflow-prone addition checks.

## D-067 — Aggregate coverage is exact and canonical

- Status: Accepted
- Decision: `PXClearResult` contains exactly one component for every requested scope, rejects duplicates/unrequested/missing scopes and stores components sorted by numeric scope.
- Reason: Exact coverage prevents silent omission and canonical ordering makes equality independent of caller array order.

## D-068 — Skipped is distinct from both failure and full success

- Status: Accepted
- Decision: A skipped component does not set `hasFailures`, but it prevents `allRequestedScopesSucceeded` from being true.
- Reason: No attempted work is not equivalent to failure, but it also cannot be reported as completed success.

## D-069 — Result predicates do not define legacy completion policy

- Status: Accepted
- Decision: TASK-1.6 exposes derived masks and explicit predicates but does not map them to the current `BOOL success` callback.
- Reason: Completion compatibility must be decided alongside real component migration and failure propagation, not inside a standalone model task.

## D-070 — Structured result precedes destructive caller migration

- Status: Accepted
- Decision: TASK-1.6 adds only `PXClearResult.h/.m`; existing production callers remain unchanged until TASK-1.7.
- Reason: Result invariants must be reviewed and built independently before they influence destructive control flow.

## D-071 — Main application-data roots are independent result units

- Status: Accepted
- Decision: TASK-1.7 processes rootful then rootless application-data roots independently. A missing exact container is not an attempted unit; resolver, validator, execution or postcondition failure is a failed unit.
- Reason: Independent units preserve partial outcomes and prevent one root failure from hiding or blocking the other root.

## D-072 — Main application-data selection has no legacy fallback

- Status: Accepted
- Decision: The main Clear path may select application-data targets only through `PXDataContainerResolver`; fuzzy finders, content heuristics, first-match behavior and raw UUID caches are not fallback authorization.
- Reason: A canonical validator cannot repair an identity decision already made by an ambiguous legacy resolver.

## D-073 — Canonical validator output is the only main mutation path

- Status: Accepted
- Decision: Every migrated application-data mutation uses the exact canonical path returned by `PXDestructivePathValidator`. Raw candidate paths, UUID reconstruction and `/var/mobile` aliases are forbidden after validation.
- Reason: Returning to caller-built paths after validation discards the safety boundary and reopens alias or target-substitution risk.

## D-074 — Main application-data commands are root-specific and result-returning

- Status: Accepted
- Decision: TASK-1.7 runs one bounded `CommandResult`-returning wipe per validated root and does not batch rootful/rootless into one shell invocation.
- Reason: Per-root execution is required to attribute success/failure counts and to avoid a successful command masking another root's failure.

## D-075 — Shell exit alone is not proof of a successful wipe

- Status: Accepted
- Decision: The migrated wipe uses a dedicated status-accumulating script, post-command validator recheck and strict filesystem postcondition. Required remove/recreate operations may not be hidden by unconditional `|| true` behavior.
- Reason: Existing compatibility scripts can exit zero after failed operations; a structured Succeeded result requires observable postconditions, not merely shell completion.

## D-076 — Main verification caches canonical paths, not UUIDs

- Status: Accepted
- Decision: TASK-1.7 replaces rootful/rootless main UUID cache fields with copied canonical application-data paths and uses those paths directly for main verification and final read-only sweep.
- Reason: Reconstructing a path from cached UUID state after validation loses canonical spelling and can reintroduce legacy aliases.

## D-077 — Application-data failure becomes a legacy completion failure

- Status: Accepted
- Decision: A Failed `PXClearScopeApplicationData` component causes `clearDataForBundleID:completion:` to return `success = NO`. Succeeded or Skipped application-data results continue the existing remaining completion policy.
- Reason: The primary destructive component must not be reported as successful when exact resolution, validation, execution or postcondition checking fails.

## D-078 — Application-data failure has callback-error precedence

- Status: Accepted
- Decision: When application-data and existing Keychain logic both fail in TASK-1.7, the application-data failure snapshot is converted to the callback `NSError`; the Keychain failure is still logged.
- Reason: Failure of the primary container reset is the most direct explanation that Clear did not complete. Full multi-component precedence remains for later aggregate orchestration.

## D-079 — Migration remains internal and component-scoped

- Status: Accepted
- Decision: TASK-1.7 preserves public `AppDataCleaner` selectors, emits only an internal ApplicationData component result and does not add a public typed Clear API or full five-scope aggregate.
- Reason: Extension, PluginKit, App Group and Keychain components still use legacy behavior and cannot yet be represented honestly as a complete typed operation.

## D-080 — Installed extension identity comes from contained app-extension bundles

- Status: Accepted
- Decision: TASK-1.8 derives extension identifiers only from exact `CFBundleIdentifier` values of real `.appex` bundles physically contained in the exact installed main `.app`; parent-bundle prefix matching is not ownership proof.
- Reason: Extension identifiers are not required to share a string prefix with the parent app, while unrelated identifiers can share one. Physical containment in the exact read-only app bundle provides a stronger identity source.

## D-081 — Data-container resolution is generalized by explicit kind

- Status: Accepted
- Decision: `PXDataContainerResolver` gains one generic exact resolver for ApplicationData, ExtensionData and PluginKitData. The existing application-data API remains and delegates to the generic method. AppGroup is rejected.
- Reason: All three kinds use exact string `MCMMetadataIdentifier` semantics, while App Group metadata can be an array and remains owned by its specialized resolver.

## D-082 — Duplicate installed extension identifiers fail closed

- Status: Accepted
- Decision: If the same extension bundle identifier appears at two distinct `.appex` paths inside the selected main app bundle, migrated extension discovery fails instead of silently deduplicating or choosing one path.
- Reason: Two code locations claiming one extension identity are ambiguous authorization input for destructive container selection.

## D-083 — ExtensionData and PluginKitData use independent identifier-root units

- Status: Accepted
- Decision: TASK-1.8 processes sorted extension identifiers with rootful then rootless units separately for ExtensionData and PluginKitData. Missing exact containers are not attempted; every resolver/validation/execution/postcondition failure is one failed unit.
- Reason: Independent units preserve exact partial outcomes across multiple extensions, roots and container kinds.

## D-084 — PluginKitData means only validated PluginKitPlugin containers

- Status: Accepted
- Decision: The PluginKitData component covers only exact validated containers under the fixed rootful/rootless `Containers/Data/PluginKitPlugin` bases. Global PlugInKit databases or wildcard-matched library files are outside this component.
- Reason: Global PlugInKit state is not represented by `PXResolvedContainerKindPluginKitData` and cannot be authorized through container metadata identity.

## D-085 — Migrated extension containers use the TASK-1.7 strict wipe boundary

- Status: Accepted
- Decision: ExtensionData and PluginKitData reuse the same canonical-path-only bounded command, post-command validator and strict filesystem postcondition as ApplicationData; raw UUID paths, permission-fixing helpers and batched void commands are forbidden.
- Reason: All mutable data-container kinds require the same proof that exact resolution, canonical authorization, execution and final layout succeeded.

## D-086 — The internal migrated aggregate grows to three scopes

- Status: Accepted
- Decision: TASK-1.8 constructs an internal request/result aggregate containing exactly ApplicationData, ExtensionData and PluginKitData. AppGroups and Keychain remain legacy side effects until their dedicated migration tasks.
- Reason: The aggregate must cover only components whose structured outcomes are truthful and reviewable at the current gate.

## D-087 — Migrated callback failure precedence is component ordered

- Status: Accepted
- Decision: Legacy callback error precedence after TASK-1.8 is ApplicationData, ExtensionData, PluginKitData, then Keychain. Lower-precedence simultaneous failures are logged.
- Reason: Deterministic precedence prevents callback behavior from depending on execution order while preserving the most foundational container failure.

## D-088 — Extension verification caches canonical paths by scope

- Status: Accepted
- Decision: Raw extension dictionaries and UUID cache state are replaced in the migrated flow by separate copied canonical path arrays for ExtensionData and PluginKitData.
- Reason: Verification must consume validator outputs directly and must not reconstruct destructive identities from legacy UUID/type/root dictionaries.

## D-089 — Generic resolver expansion must preserve TASK-1.2 input compatibility

- Status: Accepted
- Decision: Adding `resolveDataContainerForIdentifier:kind:root:error:` must not narrow the accepted identifier-input contract of the existing ApplicationData resolver. Public resolver input remains runtime NSString, nonempty, non-whitespace-only and free of U+0000, with no bundle-syntax normalization or whitelist.
- Reason: The existing public selector delegates to the generic method. Applying the stricter `PXClearRequest` bundle syntax inside the resolver would be a backwards-incompatible behavior change unrelated to exact metadata identity.

## D-090 — Strict extension identifier syntax belongs at installed-code discovery

- Status: Accepted
- Decision: TASK-1.8 keeps `PXClearRequest`-equivalent strict identifier validation in the private read-only `.appex` discovery boundary, not in the public data-container resolver.
- Reason: Installed extension code identity is expected to be a valid bundle identifier, while the generic resolver's job is exact metadata lookup under its previously accepted string contract.

## D-091 — Cumulative whitespace evidence is part of task acceptance

- Status: Accepted
- Decision: A task report that claims whitespace verification passed cannot be accepted when `git show --check` or the cumulative baseline-to-HEAD diff reports added trailing whitespace. Corrective commits must clean the evidence and rerun both gates.
- Reason: False verification evidence weakens review trust even when production source is otherwise correct.

## D-092 — Typed App Group resolution coexists with the legacy resolver API

- Status: Accepted
- Decision: TASK-1.9 adds a root-specific typed App Group resolver returning `PXResolvedContainerKindAppGroup` while preserving `resolveGroupContainersForGroupIDs:` and `AppGroupContainerInfo` for current Backup/Restore callers.
- Reason: Clear requires exact error-bearing destructive identity, but changing the legacy model and Backup/Restore behavior in the same task would exceed the migration boundary.

## D-093 — Signed application entitlements are the only App Group identity source

- Status: Accepted
- Decision: Migrated AppGroups discovery reads only `com.apple.security.application-groups` and the compatibility key `application-groups` from the target application's signed entitlements. Prefix, company-name, metadata substring and content heuristics cannot authorize a group.
- Reason: App Group identifiers are declared capabilities. Filesystem similarity or naming conventions do not prove that the target app is entitled to mutate a shared container.

## D-094 — App Group metadata supports one exact string or one exact array occurrence

- Status: Accepted
- Decision: The typed App Group resolver accepts a metadata string equal to the requested group identifier or an array containing that identifier exactly once. Duplicate exact occurrences are invalid metadata; multiple physical exact matches in one root are ambiguous.
- Reason: The validator already enforces this live metadata policy. Resolution must produce a candidate compatible with the same exact identity rules.

## D-095 — App Group execution units are unique canonical physical containers

- Status: Accepted
- Decision: Multiple entitled group identifiers that resolve and validate to the same canonical App Group path are collapsed into one physical execution unit. Every associated identity model is retained and revalidated after the single command.
- Reason: App Group metadata arrays can legitimately associate several exact identifiers with one container. Wiping the same physical directory multiple times would distort result counts and increase race exposure.

## D-096 — AppGroups use the common strict data-container mutation boundary

- Status: Accepted
- Decision: Each unique canonical App Group container receives one bounded strict wipe, post-command identity revalidation and strict postcondition. Raw UUID reconstruction, batched void commands, permission-fixing helpers and destructive final sweeps are forbidden in the migrated path.
- Reason: Shared containers require the same canonical authorization and observable completion proof as ApplicationData, ExtensionData and PluginKitData.

## D-097 — The migrated aggregate grows to four scopes

- Status: Accepted
- Decision: TASK-1.9 aggregates exactly ApplicationData, ExtensionData, AppGroups and PluginKitData. Legacy callback failure precedence becomes ApplicationData, ExtensionData, AppGroups, PluginKitData, then Keychain.
- Reason: AppGroups becomes a truthful structured component while Keychain remains outside the typed aggregate until TASK-1.10.

## D-098 — App Group verification caches canonical paths, not root-specific UUIDs

- Status: Accepted
- Decision: `_wipeCacheGroupUUIDs` and `_wipeCacheRootlessGroupUUIDs` are replaced with one deterministic canonical App Group path array used directly by cache-hit verification.
- Reason: A root flag plus UUID reconstructs pre-validation state. Verification must consume the exact paths authorized by the validator.

## D-099 — Typed AppGroups must be the only reachable main-flow App Group mutation

- Status: Accepted
- Decision: After TASK-1.9, the migrated main Clear flow cannot mutate App Group containers through deep encrypted scans, fuzzy legacy resolvers, group final sweeps or MobileSafari substring/structure fallbacks. MobileSafari SystemGroup and global store cleanup remain separate.
- Reason: A later legacy mutation would bypass typed identity, canonical authorization and component accounting even if the initial AppGroups operation was correct.

## D-100 — Keychain configuration is snapshotted once per full Clear

- Status: Accepted
- Decision: TASK-1.10 reads the per-app enable flag, saved selection, signed Keychain authorization and system-app policy once before the initial Keychain pass. The same immutable snapshot drives every planned pass.
- Reason: Re-reading mutable defaults or entitlements between passes can silently change scope and make two executions impossible to represent as one stable component.

## D-101 — Exact signed access groups are the only typed Keychain authorization

- Status: Accepted
- Decision: The typed Keychain plan accepts only exact selected groups that are members of the target application's signed `keychain-access-groups` plus valid `application-identifier`. Hard-coded vendor groups, service names, account labels and bundle-prefix heuristics are excluded.
- Reason: Keychain access group entitlement is the capability boundary. Similar names or legacy aggressive matching do not authorize deletion of shared credentials.

## D-102 — Explicit empty Keychain selection is preserved

- Status: Accepted
- Decision: A saved empty group array means the user selected no groups and produces a Skipped Keychain component. Only an absent saved object may default to all exact authorized groups.
- Reason: Treating an empty selection as missing configuration silently broadens a destructive operation and contradicts the UI's Select None action.

## D-103 — Keychain pass invocations are structured units

- Status: Accepted
- Decision: Non-system applications have two planned Keychain units, initial and final; system applications have one bridge unit. Planning failures use one synthetic failed unit, while disabled or empty policy uses zero-unit Skipped.
- Reason: Unit counts must distinguish skipped policy, complete success, partial two-pass failure and total failure without inventing a separate partial status.

## D-104 — Full Clear produces a five-scope result while completeAppDataWipe remains data-only

- Status: Accepted
- Decision: `clearDataForBundleID:completion:` builds a final aggregate containing ApplicationData, ExtensionData, AppGroups, PluginKitData and Keychain. `completeAppDataWipe:` remains a four-scope data-only compatibility selector.
- Reason: Full Clear needs one truthful final result, but adding Keychain side effects to the existing data-only compatibility selector would be an unrelated public behavior change.

## D-105 — Keychain helper and bridge success require complete execution evidence

- Status: Accepted
- Decision: Non-system signing/helper execution uses bounded direct executable APIs and fails on incomplete/truncated results. The CLI returns nonzero for wipe warnings or failed items. The system bridge reports attempted/succeeded/failed delete operations and may set `ok` only when the partition is complete and failure-free.
- Reason: Process exit zero or an unconditional bridge boolean does not prove that selected Keychain classes were deleted successfully.

## D-106 — Legacy callback outcome derives only from the final five-scope result

- Status: Accepted
- Decision: After TASK-1.10, callback error precedence is ApplicationData, ExtensionData, AppGroups, PluginKitData, then Keychain. No separate Keychain boolean branch may override or bypass the final aggregate.
- Reason: One final structured result prevents divergence between logged component outcomes and the legacy `BOOL/NSError` callback while preserving Skipped as non-failure.

## D-107 — Recursive world-writable permission repair is not a Clear prerequisite

- Status: Accepted
- Decision: TASK-1.11 removes every compatibility-path `chmod -R`, directory-wide `find -exec chmod` and arbitrary-tree world-writable preparation from `AppDataCleaner.m`.
- Reason: Clear must not make an unvalidated caller-supplied tree writable merely to improve deletion success. Permission mutation expands the impact of an identity mistake and remains outside structured result accounting.

## D-108 — Permission-only public compatibility becomes non-mutating

- Status: Accepted
- Decision: `fixPermissionsForPath:` keeps its public selector for ABI/source compatibility but becomes a concise log-only no-op. `fixPermissionsAndRemovePath:` retains deletion compatibility while dropping all chmod/chown/chflags preparation.
- Reason: Removing selectors belongs to TASK-1.12, but preserving their historical recursive permission side effects would keep the unsafe behavior reachable during the compatibility period.

## D-109 — Marker and timestamp mutation cannot represent successful Clear

- Status: Accepted
- Decision: TASK-1.11 removes `.nomedia`, `.initialized`, substitute wipe markers and the SiriAnalytics `touch -r` write to the AssistantServices system framework executable.
- Reason: Marker existence or timestamp disguise does not prove deletion, identity or postcondition success and can mutate unrelated system/code state outside the five-scope result.

## D-110 — Narrow task-owned modes remain allowed

- Status: Accepted
- Decision: The Keychain pass may retain mode `0700` on its unique temporary directory and non-recursive mode `0755` on its copied helper executable. Narrow modes on task-owned temporary compatibility files are not removed by TASK-1.11.
- Reason: These operations prepare newly created task-owned artifacts with bounded scope; they are not recursive permission repair of application or shared data trees.

## D-111 — Recreated fixed directories require only non-recursive ownership

- Status: Accepted
- Decision: The recreated fixed Mail and MobileSafari WebKit directories use ownership assignment on the directory itself, not `chown -R` traversal.
- Reason: The same command sequence has just recreated an empty directory. Recursive ownership traversal is unnecessary and could affect concurrently recreated descendants.

## D-112 — Canonical strict-child flag preparation is preserved separately from legacy helpers

- Status: Accepted
- Decision: TASK-1.11 preserves the single accepted best-effort `chflags -R` operation inside `PXShellValidatedApplicationDataWipe`, limited to immediate non-metadata children of a canonical validator-authorized container. Every generic/raw-path `chflags` operation is removed.
- Reason: The strict typed script and its postcondition were accepted in TASK-1.7 through TASK-1.9. Changing that device-sensitive behavior is distinct from removing unbounded legacy permission helpers and must not be mixed into TASK-1.11.

## D-113 — Permission cleanup precedes API quarantine

- Status: Accepted
- Decision: TASK-1.11 preserves public selectors and remaining deletion compatibility; TASK-1.12 alone decides deprecation, caller replacement, no-op quarantine or removal of ambiguous raw-path Clear APIs.
- Reason: Separating side-effect removal from API quarantine keeps the current diff reviewable and prevents permission hardening from becoming an uncontrolled public-interface redesign.

## D-114 — The typed five-scope flow is the only approved full Clear authority

- Status: Accepted
- Decision: After TASK-1.12, only `clearDataForBundleID:completion:` may own a full Clear operation and only `completeAppDataWipe:` may own the accepted four-scope data-only compatibility operation.
- Reason: Those paths alone bind exact typed requests, canonical authorization, structured component results, Keychain planning and deterministic callback policy into one reviewable operation.

## D-115 — Raw-path compatibility selectors become non-mutating shims

- Status: Accepted
- Decision: Arbitrary-path helpers such as `completelyWipeContainer:`, `securelyWipeFile:`, `fixPermissionsAndRemovePath:`, directory wipe helpers and final-sweep helpers retain their selectors but perform no filesystem inspection or mutation.
- Reason: A caller-supplied path does not carry resolved-container identity or canonical validator evidence. Preserving deletion behind the old selector would keep an authorization bypass available after typed migration.

## D-116 — A quarantined BOOL deletion API cannot report success

- Status: Accepted
- Decision: `securelyWipeFile:` returns `NO` after selector-only quarantine logging and never returns success based on invalid input, absence or read-only inspection.
- Reason: No deletion attempt or postcondition proof exists in the shim. Returning `YES` would recreate the false-success behavior that structured results were introduced to eliminate.

## D-117 — Fuzzy and structure-based container selection is removed, not upgraded locally

- Status: Accepted
- Decision: Prefix, substring, company-name, hard-coded UUID and filesystem-structure mutation helpers become non-mutating shims. They are not replaced with local allow-lists or ad hoc validator calls.
- Reason: Exact ownership belongs to the accepted typed resolver and entitlement boundaries. A legacy helper cannot safely reconstruct that authority from approximate signals.

## D-118 — Detached Keychain aliases are quarantined

- Status: Accepted
- Decision: Public legacy Keychain aliases perform no Keychain work outside `clearDataForBundleID:completion:`. They do not read settings, derive groups, call the helper/bridge or invoke `_wipeSelectedKeychainForBundleID:`.
- Reason: The immutable request-scoped Keychain plan, pass accounting and final component result cannot be reproduced by a detached void selector.

## D-119 — Quarantine logs selector identity only

- Status: Accepted
- Decision: Quarantine shims may emit one concise log containing the selector name but no path, bundle ID, UUID, group, entitlement, command or target value.
- Reason: Inputs can be sensitive and are unnecessary once the operation is intentionally rejected. Selector-only logging proves reachability without persisting target data.

## D-120 — Public API removal remains Phase 6 work

- Status: Accepted
- Decision: TASK-1.12 keeps `AppDataCleaner.h` byte-identical and preserves implementation symbols. Deprecation attributes, declaration removal, selector renaming and public-surface reduction remain TASK-6.1/TASK-6.2.
- Reason: Runtime safety can be closed by non-mutating shims without combining it with source/ABI migration across unknown external callers.

## D-121 — Phase 1 closes only after ambiguous Clear mutation is quarantined

- Status: Accepted
- Decision: Phase 1 is complete after TASK-1.12 because the full five-scope Clear has exact typed authority and every specified raw-path, raw-UUID, fuzzy or detached-Keychain compatibility selector is non-mutating.
- Reason: Canonical typed execution is not a complete safety boundary while an alternate public or private mutation route can bypass it.

## D-122 — Manifest schema validation is a standalone in-memory contract

- Status: Accepted
- Decision: TASK-2.1 adds `PXBackupManifestValidator.h/.m` only. It validates an already-loaded object and is not imported by Backup, Restore, listing or UI in the same task.
- Reason: Schema correctness must be reviewed independently before it can reject existing Restore requests or change user-visible compatibility.

## D-123 — Structural version shape precedes supported-version policy

- Status: Accepted
- Decision: `manifestVersion` must be a positive integral non-Boolean number, but TASK-2.1 does not restrict it to a supported set. TASK-2.2 alone decides which positive versions Restore accepts.
- Reason: Type/range validation and product compatibility policy are separate contracts. Combining them would make it impossible to review schema handling independently from version migration decisions.

## D-124 — Manifest bundle shape precedes requested-target identity

- Status: Accepted
- Decision: TASK-2.1 requires a nonempty NUL-free manifest `bundleID` but accepts no expected bundle argument and performs no comparison with the requested restore target.
- Reason: Exact requested bundle enforcement belongs to TASK-2.3 and must not be hidden inside a generic schema validator.

## D-125 — The common version-2/version-3 envelope is required

- Status: Accepted
- Decision: TASK-2.1 requires the common operational fields emitted by existing version-2 and version-3 manifests, while version-3-only metadata remains optional and strictly typed when present.
- Reason: Restore should not silently invent defaults for missing operational sections, but the structural validator must still distinguish common schema from later additive metadata.

## D-126 — Boolean and integer fields use exact runtime categories

- Status: Accepted
- Decision: Manifest Boolean fields accept only CFBoolean-backed values. Integral fields reject CFBoolean and floating/decimal representations even when broad `boolValue` or `integerValue` conversion would succeed.
- Reason: Coercion hides malformed manifests and allows one serialized value to change meaning depending on the consumer.

## D-127 — Unknown manifest fields are graph-safe and bounded

- Status: Accepted
- Decision: Unknown keys are allowed for forward-compatible metadata only when the full value graph is property-list-safe, acyclic and within fixed depth, per-container and aggregate traversal limits.
- Reason: Forward compatibility does not require accepting custom objects, cycles or unbounded structures that can make preflight nondeterministic or resource-exhausting.

## D-128 — Ambiguous duplicate lookup keys fail schema validation

- Status: Accepted
- Decision: Exact duplicate artifact names/paths, group identities, archive names and other specified lookup keys are rejected at the later occurrence. Shared App Group UUID metadata remains allowed where distinct exact identities can refer to one physical container.
- Reason: Later dictionary construction must not silently overwrite one manifest entry with another, while legitimate physical aliasing must not be mistaken for duplicate identity.

## D-129 — Schema errors expose stable field paths, not values

- Status: Accepted
- Decision: Manifest validation errors contain a fixed domain/code, a deterministic schema field path and a non-sensitive description. Raw manifest values and object excerpts are not placed in `NSError.userInfo`.
- Reason: Preflight errors need precise attribution without leaking bundle IDs, paths, UUIDs, archive names or checksums into persistent error graphs or logs.

## D-130 — Supported manifest versions are an exact closed set

- Status: Accepted
- Decision: TASK-2.2 accepts exactly manifest versions 2 and 3. Version 1 and all future positive versions are rejected until an explicit compatibility task approves them.
- Reason: Repository history contains writers for v2 and v3 only. A numeric range or future-version fallback would let Restore consume semantics that have not been reviewed.

## D-131 — Structural validity precedes version compatibility

- Status: Accepted
- Decision: `PXBackupManifestValidator` runs before supported-version policy. Missing, Boolean, floating, zero or otherwise malformed version values remain schema errors; only a structurally valid positive version can become an unsupported-version error.
- Reason: Malformed representation and unsupported product compatibility are different failure classes and must remain diagnosable.

## D-132 — Manifest read is the common schema/version boundary

- Status: Accepted
- Decision: `readManifestAtBackupDirectory:error:` loads the dictionary once, validates its structure once and applies the exact version policy once. Restore and existing UI readers consume that same boundary.
- Reason: Separate checks in UI and Restore can drift and allow a manifest displayed as valid to be rejected differently—or accepted unsafely—during execution.

## D-133 — Validator errors are propagated without manager wrapping

- Status: Accepted
- Decision: TASK-2.1 validation errors pass through the manifest-read API unchanged, preserving validator domain, code and field path. Unsupported structurally valid versions use private manager code 201.
- Reason: Wrapping would discard precise schema attribution, while version support is manager policy rather than structural validation.

## D-134 — Restore rejects manifest incompatibility before operational setup

- Status: Accepted
- Decision: Restore must complete manifest read, schema validation and supported-version enforcement before debug writes, tar discovery, process termination, target lookup, artifact verification or extraction.
- Reason: An unsupported manifest must not be masked by an unrelated environment failure and must not trigger any target-affecting work.

## D-135 — Requested bundle mismatch remains separate from version policy

- Status: Accepted
- Decision: TASK-2.2 preserves current warning-only requested bundle mismatch behavior. Exact requested-target rejection remains TASK-2.3.
- Reason: Version compatibility does not prove destination identity; combining the gates would hide the behavioral change assigned to the next review task.

## D-136 — Supported version does not authorize recorded destinations

- Status: Accepted
- Decision: TASK-2.2 leaves manifest `containerPath` and UUID fallback behavior unchanged for TASK-2.4 and does not treat a supported version as path authorization.
- Reason: Version provenance and destination safety are independent. Removing or trusting recorded destinations requires exact bundle identity and a dedicated migration.

## D-137 — Requested Restore identity uses exact case-sensitive equality

- Status: Accepted
- Decision: TASK-2.3 requires `manifest[@"bundleID"]` to equal the caller-requested Restore `bundleID` through exact `isEqualToString:` semantics. No case folding, trimming, Unicode normalization, prefix, suffix, substring, app-name or company-name matching is allowed.
- Reason: Restore destination identity must not be broadened by presentation or naming heuristics. A backup for one identifier cannot authorize mutation of a different requested target.

## D-138 — Bundle mismatch is an early Restore preflight failure

- Status: Accepted
- Decision: Exact bundle comparison runs immediately after schema/version acceptance and before warnings, debug writes, runner/tar setup, process termination, target lookup, artifact checks, extraction or mutation.
- Reason: A mismatched backup must not trigger target-side work and must not be masked by an unrelated environment or artifact failure.

## D-139 — The public manifest reader remains target-agnostic

- Status: Accepted
- Decision: `readManifestAtBackupDirectory:error:` continues to validate only manifest readability, structure and supported version. It does not gain an expected bundle argument or requested-target comparison.
- Reason: Listing and inspection callers need a common manifest validity boundary without pretending to know which Restore target a later operation will request.

## D-140 — Bundle mismatch errors are non-sensitive and stable

- Status: Accepted
- Decision: TASK-2.3 uses private manager error code 304 with a generic localized description and does not include either bundle identifier, backup directory, path, UUID or manifest excerpt in the error graph or mismatch log.
- Reason: Exact mismatch attribution does not require persisting potentially sensitive identifiers, and a stable generic error avoids divergent caller-visible formatting.

## D-141 — Restore must preserve the caller-requested target

- Status: Accepted
- Decision: `AppDataBackupManager` may not replace the requested bundle ID with the manifest bundle ID to make the comparison pass. Existing callers that intentionally request the manifest's exact ID continue to work naturally; selected-target callers receive a mismatch failure when identities differ.
- Reason: Silently rewriting the target would turn validation into target selection by untrusted manifest data and defeat the purpose of the requested-target gate.

## D-142 — Exact bundle identity does not authorize recorded path or UUID

- Status: Accepted
- Decision: TASK-2.3 leaves LaunchServices lookup, metadata scan and manifest path/UUID fallback behavior unchanged for TASK-2.4.
- Reason: Matching the logical app identifier is necessary but not sufficient to prove that a recorded filesystem destination is current, canonical or safe.

## D-143 — Backup-recorded paths and UUIDs are source history, not destination authority

- Status: Accepted
- Decision: TASK-2.4 removes manifest `data.containerPath`, `data.uuid`, `sourceDataContainerPath` and `sourceDataContainerUUID` from Restore destination selection. The fields remain schema/writer metadata for compatibility.
- Reason: A path or UUID recorded on another installation or before container recreation does not prove the current destructive target.

## D-144 — Restore ApplicationData destination uses the common typed safety boundary

- Status: Accepted
- Decision: Restore resolves rootful and rootless ApplicationData models through `PXDataContainerResolver`, validates every match through `PXDestructivePathValidator` and uses only the returned canonical path.
- Reason: Restore should share the exact identity and canonical authorization boundary already accepted for Clear instead of maintaining a weaker local first-match resolver.

## D-145 — Destination root errors and distinct canonical ambiguity fail closed

- Status: Accepted
- Decision: Any resolver or validator error in either known root fails destination preflight. Same-canonical aliases collapse to one physical target, while two distinct canonical paths are ambiguous and rejected.
- Reason: An unreadable root can hide a second target, and arbitrary root preference cannot safely decide between distinct exact containers.

## D-146 — Restore destination identity is revalidated immediately before mutation

- Status: Accepted
- Decision: TASK-2.4 retains the chosen immutable model and re-runs canonical validation immediately before the first main-container wipe, requiring the canonical path to remain exactly unchanged.
- Reason: Artifact verification and staging create a time interval between initial resolution and destructive use. A changed filesystem identity must stop Restore before mutation.

## D-147 — LaunchServices and legacy metadata helpers lose Restore authority only

- Status: Accepted
- Decision: Existing LaunchServices and first-match metadata helpers may remain for Backup and read-only diagnostics, but they cannot select or override the Restore destination after TASK-2.4.
- Reason: TASK-2.4 closes destructive destination bypasses without combining that work with Backup resolver migration or diagnostic cleanup.

## D-148 — Destination failure precedes Restore operational setup

- Status: Accepted
- Decision: Exact destination resolution follows manifest/schema/version and requested-bundle checks but precedes warnings, debug writes, tar lookup, process termination, artifact checks and extraction.
- Reason: A missing, invalid or ambiguous destination is a preflight failure and must not be masked by environment failures or trigger target-side work.

## D-149 — TASK-2.4 does not redefine artifact or archive trust

- Status: Accepted
- Decision: Destination hardening leaves current artifact checks, archive extraction, staging, App Group handling and transaction semantics unchanged for TASK-2.5 and later tasks.
- Reason: Destination identity and backup-content trust are independent safety boundaries that require separate review and build gates.

## D-150 — Artifact `name` is current relative identity; recorded `path` is history only

- Status: Accepted
- Decision: TASK-2.5 locates artifacts only through a safe relative `name` beneath the currently selected backup directory. The manifest `path` field is never opened, canonicalized, compared or used as fallback.
- Reason: Backups can be moved, copied or restored on another device. An absolute source path records where a file was created, not where trusted Restore input now resides.

## D-151 — Every included component reference requires an exact artifact declaration

- Status: Accepted
- Decision: Data, App Group, preferences, Keychain, profile, global Safari, system-global and shared-system-DB archive references must exact-match one declared artifact name. Duplicate cross-section references and missing declarations fail preflight.
- Reason: A section must not consume an undeclared or ambiguously shared file outside the common integrity boundary.

## D-152 — Artifact filesystem traversal is descriptor-relative and no-follow

- Status: Accepted
- Decision: Artifact verification walks relative components under an opened canonical backup root and rejects symlink parents, symlink final files and non-regular objects. Path existence or string prefix checks alone are insufficient.
- Reason: A manifest-safe lexical path can still escape or change identity through a symlink in the backup tree.

## D-153 — Artifact size and SHA-256 are complete fail-closed evidence

- Status: Accepted
- Decision: Every supported v2/v3 artifact must match its exact declared size, including zero, and provide a complete 64-character lowercase SHA-256 verified by streaming the opened file descriptor. Missing, malformed, unreadable or mismatching digest evidence fails Restore.
- Reason: Warning-only checks, zero-skipping and silent hash-read failure allow incomplete or substituted backup content to reach destructive Restore work.

## D-154 — Artifact identity must remain stable during verification

- Status: Accepted
- Decision: The verifier compares file descriptor identity and relevant metadata before and after hashing and rejects a file that changes during the verification interval.
- Reason: A digest is not trustworthy when it may combine bytes from a file modified or replaced while being read.

## D-155 — Verified artifact paths are immutable Restore inputs

- Status: Accepted
- Decision: The verifier returns an immutable exact-name to canonical-path index, and current Restore consumers obtain every artifact source from that result instead of reconstructing `backupDir + archive` paths.
- Reason: Verification and consumption must refer to the same resolved source identity; rebuilding paths independently can bypass the verifier or select a different file.

## D-156 — Artifact preflight precedes Restore operational side effects

- Status: Accepted
- Decision: Common artifact verification runs after manifest, requested-bundle and destination preflight but before warnings/debug setup, tar discovery, process termination, extraction or mutation. Verifier errors propagate unchanged.
- Reason: Invalid backup content must not kill the target app, create diagnostic files or begin any restore operation, and precise verifier errors should not be flattened into manager warnings.

## D-157 — Artifact-file trust precedes archive-entry trust

- Status: Accepted
- Decision: TASK-2.5 verifies the archive file as a regular exact-size exact-hash artifact but does not inspect member names, links, compression behavior or extracted layout. TASK-2.6 owns archive-entry safety.
- Reason: Whole-file integrity and safe archive semantics are distinct contracts. A correctly hashed malicious archive can still contain unsafe entries.

## D-158 — Operational section semantics select archive artifacts

- Status: Accepted
- Decision: TASK-2.6 parses only artifact names referenced by tar-bearing Restore sections: main data, App Groups, included profile app data, included global Safari and included system-global libraries. Preferences, Keychain, shared-system DBs and unreferenced declarations are not classified by filename extension.
- Reason: Archive interpretation is part of the component contract. Treating every `.tar.gz`-looking name as an archive gives untrusted naming conventions authority over parser scope.

## D-159 — Archive validation is streaming and in-process

- Status: Accepted
- Decision: The archive validator reads safely opened descriptors through zlib and a bounded tar state machine. It does not invoke `tar -t`, parse human-readable listing output, extract to a temporary directory or depend on an external helper.
- Reason: Tar implementations and listing formats differ across jailbreak layouts, and external listing cannot provide one portable structured proof for PAX metadata, links, limits and stream completeness.

## D-160 — Restore archives accept only regular files and directories

- Status: Accepted
- Decision: Real archive members are limited to regular files and directories. Symbolic links, hard links, devices, FIFOs, sparse encodings, dump/contiguous and unknown entry types fail before extraction.
- Reason: Link and special-file semantics can redirect writes, affect objects outside staging or create filesystem behavior that current Restore planning and transaction boundaries do not represent.

## D-161 — Archive member identity is normalized only at the tar root boundary

- Status: Accepted
- Decision: The validator permits the writer's leading `./` root marker and directory trailing slash, then rejects absolute paths, backslashes, empty/internal dot components, `..`, invalid UTF-8, controls and oversized names without case folding or Unicode normalization.
- Reason: Current GNU/BSD writers emit root-relative names, but lexical cleanup must not broaden identity or silently reinterpret traversal-bearing member paths.

## D-162 — PAX and GNU name metadata are bounded parser inputs

- Status: Accepted
- Decision: TASK-2.6 structurally parses bounded POSIX PAX `x/g` and GNU `L/K` metadata, supports safe path/size overrides, rejects entry-specific global overrides and GNU sparse metadata, and ignores only well-formed inert vendor metadata.
- Reason: Current tar writers may use PAX for long paths, ACLs and xattrs. Rejecting all metadata breaks valid backups, while trusting unbounded or ambiguous overrides defeats member-path and size checks.

## D-163 — Duplicate and conflicting archive topology fails closed

- Status: Accepted
- Decision: Duplicate normalized paths, duplicate root markers, file/directory identity conflicts, a file used as a parent and a child beneath a declared file are rejected in physical stream order.
- Reason: Extraction overwrite order is not authorization. One logical destination must not be represented by multiple or structurally contradictory archive entries.

## D-164 — Archive expansion has fixed non-configurable limits

- Status: Accepted
- Decision: TASK-2.6 applies fixed archive-count, physical-header, member-count, path, metadata, single-file and dynamic/absolute inflated-byte budgets with overflow-checked arithmetic.
- Reason: A valid compressed hash does not prevent decompression bombs, metadata floods or member-count exhaustion. Limits must apply before staging or external extraction.

## D-165 — Archive parsing rechecks compressed artifact identity

- Status: Accepted
- Decision: While inflating, the validator recomputes the compressed artifact SHA-256 from the same descriptor reads, compares declared compressed size and digest, and verifies descriptor/path identity before and after parsing.
- Reason: TASK-2.5 is a prior snapshot. Archive semantics must be attributed to the same exact compressed bytes that remain selected during TASK-2.6 validation.

## D-166 — Archive-entry rejection precedes Restore operational setup

- Status: Accepted
- Decision: Archive validation runs immediately after TASK-2.5 artifact verification and before warnings, debug writes, CommandRunner, tar discovery, process termination, staging, extraction or mutation. Exact archive-validator errors propagate unchanged.
- Reason: A malicious or resource-abusive member stream must not trigger target-side work and must not be masked by environment failures such as a missing tar executable.

## D-167 — Archive validation remains a preflight snapshot, not a Restore plan

- Status: Accepted
- Decision: TASK-2.6 returns immutable archive summaries but does not retain descriptors, create staging, replace extraction helpers or define component commit/rollback. TASK-2.7 still owns immutable Restore planning.
- Reason: Member safety and operation planning are separate gates. Combining them would obscure archive-parser correctness and prematurely redesign transaction flow.

## D-168 — Optional additive manifest sections remain optional downstream

- Status: Accepted
- Decision: A downstream artifact or archive validator may validate `systemGlobalLibrary` strictly when present but may not require it when the common manifest schema treats the section as optional.
- Reason: A later preflight layer must not silently narrow the accepted version-2/version-3 compatibility envelope established by the common schema boundary.

## D-169 — Well-formed non-reserved PAX metadata is ignored

- Status: Accepted
- Decision: After strict record framing/key validation, PAX `path`, `size` and `linkpath` keep their explicit semantics, every `GNU.sparse` key remains rejected, and other bounded non-reserved metadata is consumed and ignored without retention.
- Reason: Unknown metadata must not gain identity or extraction authority, but rejecting every future/vendor inert key contradicts the frozen compatibility policy and valid tar producers.

## D-170 — Implicit archive topology state is explicitly bounded

- Status: Accepted
- Decision: Unique implicit-directory identities retained by the tar parser are capped at the existing 200,000 logical-member limit, with an atomic pre-mutation count check.
- Reason: A real-member limit does not bound the number of derived parent strings. Unbounded implicit topology state can turn a streaming validator into a memory-amplification path.

## D-171 — POSIX and GNU tar header spellings are classified separately

- Status: Accepted
- Decision: Exact POSIX `ustar\0`/`00`, GNU `ustar `/` \0` and legacy empty-magic headers use separate private format classification. POSIX prefix composition applies only to POSIX ustar.
- Reason: GNU old headers reuse the POSIX prefix region for extension state. Treating every `ustar` prefix as POSIX can create a false member path from unrelated bytes.

## D-172 — Archive traversal descriptors remain close-on-exec

- Status: Accepted
- Decision: Root-descriptor duplication for archive traversal must preserve or explicitly set `FD_CLOEXEC` before the first `openat`, and setup failure is fail-closed.
- Reason: Raw `dup` clears the close-on-exec descriptor flag and weakens the fixed descriptor-lifetime boundary if the process later executes another image.

## D-173 — TASK-2.7 remains locked until TASK-2.6A passes

- Status: Accepted
- Decision: TASK-2.6 is `CHANGES_REQUESTED`; only the narrow TASK-2.6A validator correction may proceed. Immutable Restore-plan work cannot begin until the corrected archive boundary passes source review and the owner build gate.
- Reason: A Restore plan must not be built on an archive validator that rejects accepted manifests, contradicts its PAX policy or retains unbounded topology state.

## D-174 — TASK-2.6 is completed through TASK-2.6A

- Status: Accepted
- Decision: Commit `2bb8473bd16ac097ae03d0e83e42b28987af1495` closes all five blocking findings from TASK-2.6 review. TASK-2.6 and TASK-2.6A are completed and TASK-2.7 is unlocked.
- Reason: Optional-section compatibility, frozen PAX policy, bounded topology, exact tar-format classification and close-on-exec traversal state now match the accepted archive boundary.

## D-175 — Restore planning freezes semantic authority once

- Status: Accepted
- Decision: TASK-2.7 creates one immutable `PXRestorePlan` immediately after manifest, target, artifact and archive preflight. Later operational code consumes the plan instead of reading the manifest or verifier/archive snapshots again.
- Reason: Recomputing component decisions during mutation creates multiple authorities and allows semantic drift between preflight and execution.

## D-176 — PXRestorePlan is pure in-memory planning

- Status: Accepted
- Decision: `PXRestorePlan.m` consumes only accepted in-memory objects. It may not read filesystem state, invoke resolvers, execute commands, stage content or mutate targets.
- Reason: Plan correctness must be reviewable independently from environment discovery and transaction mechanics.

## D-177 — Recorded paths remain metadata, including optional components

- Status: Accepted
- Decision: The plan freezes verified artifact sources but does not authorize destination paths from manifest `data.containerPath`, optional section `path` fields or recorded UUIDs.
- Reason: Recorded source-device locations are not current-device destination authority.

## D-178 — Advanced relative destinations are lexically constrained in the plan

- Status: Accepted
- Decision: System-global subdirectories must be safe single components, while shared-system-DB locations must be safe bounded relative paths with no absolute, empty, dot, dot-dot, backslash or control components.
- Reason: These manifest-derived identities are later combined with the mobile Library root. Unsafe lexical identity must fail before any path composition or mutation.

## D-179 — App Group plan items are semantic, not destination authorization

- Status: Accepted
- Decision: TASK-2.7 freezes exact App Group identifier-to-verified-archive mappings but does not resolve or authorize installed App Group destination containers. TASK-2.9 retains that responsibility.
- Reason: Planning source intent and proving current destructive destination identity are separate review gates.

## D-180 — Restore plan precedes operational setup

- Status: Accepted
- Decision: Plan construction and exact plan-error propagation occur before warnings, debug writes, CommandRunner use, tar discovery, process termination, staging, extraction or mutation.
- Reason: Snapshot inconsistency or unsafe relative destination identity must not trigger target-side work or be masked by environment failures.

## D-181 — TASK-2.7 closes semantic Restore authority

- Status: Accepted
- Decision: Commit `d9ab9013b5d637ceb71695003bbc7153ac78151c` is accepted. After plan construction, operational Restore has zero direct manifest reads and zero direct verified-artifact or validated-archive lookups.
- Reason: Main and optional component execution now consumes one immutable semantic snapshot, allowing staging and transaction tasks to build on a single reviewed authority.

## D-182 — Main staging uses one private unique fixed-parent workspace

- Status: Accepted
- Decision: TASK-2.8 creates a `mkdtemp` workspace only under the fixed real parent `/private/var/tmp`, retains parent/root/data descriptors and exact identities, and removes the predictable PID-only staging path.
- Reason: Path-based remove/recreate of a predictable `/tmp` location permits substitution and cleanup ambiguity before destructive Restore work.

## D-183 — Staged main data is validated descriptor-relatively

- Status: Accepted
- Decision: The staged tree is traversed from retained directory descriptors with no-follow opens, deterministic UTF-8 ordering, fixed path/depth/entry limits and regular-file/directory-only policy. Symlinks, hard links, special files, mount crossings and setid entries fail closed.
- Reason: Safe archive member metadata does not by itself prove that an external extractor produced an equivalent safe filesystem tree.

## D-184 — Staging cannot replace target container identity metadata

- Status: Accepted
- Decision: Root-level `.com.apple.mobile_container_manager.metadata.plist` and `.com.apple.containermanagerd.metadata.plist` entries are forbidden in the validated main stage.
- Reason: Main target wiping intentionally preserves current-device container metadata. A staged archive must not overwrite that retained destination identity.

## D-185 — Main staged bytes are bound to the accepted archive summary

- Status: Accepted
- Decision: TASK-2.8 obtains logical-member and regular-file-byte summaries only through `PXRestorePlan.validatedArchives`, streams every staged regular file with before/after identity checks, requires exact total regular bytes and emits a deterministic staged-tree SHA-256 snapshot.
- Reason: Staging must remain tied to the accepted archive snapshot without reopening manifest or recorded-path authority.

## D-186 — Extraction failure remains failure and target termination is delayed

- Status: Accepted
- Decision: A nonzero main archive extraction result may not be converted to success because partial staged content exists. The first Restore process kill occurs only after the complete staged tree passes validation.
- Reason: Partial extraction is not a valid source, and staging failure should not terminate the target application or begin target-side mutation.

## D-187 — Staging cleanup is owned, bounded and descriptor-relative

- Status: Accepted
- Decision: The staging workspace cleans only its retained unique root through parent-relative no-follow operations, enforces a fixed cleanup limit and is idempotent. Manager path-based recursive staging deletion and shell fallbacks are forbidden.
- Reason: Cleanup must not become a second destructive path capable of following a substituted name or deleting an unrelated directory.

## D-188 — Main staging validation is not main-data transaction commit

- Status: Accepted
- Decision: TASK-2.8 keeps the existing post-validation target wipe and clone policy. It does not quarantine the current target, atomically swap data or implement rollback; TASK-2.11 retains those responsibilities.
- Reason: Proving the source stage and providing transactional destination recovery are separate safety gates.

## D-197 — TASK-2.9 closes exact App Group Restore authority

- Status: Accepted
- Decision: Commit `48cb463b9f1bb6b1244237c227fa890f3020071d` is accepted. Signed entitlements, typed rootful/rootless resolution, canonical target collapse, per-archive staging, source equivalence and immediate model revalidation now govern App Group Restore.
- Reason: Restore no longer trusts legacy aggregate resolver output or recorded App Group destination values.

## D-198 — Optional destinations derive from one exact current-device mobile Library

- Status: Accepted
- Decision: TASK-2.10 resolves the fixed mobile Library candidate set, collapses aliases and rejects zero or multiple distinct physical roots. Manifest paths and first-existing helper order have zero optional-destination authority.
- Reason: Optional global destinations must be tied to one reviewed current-device root before any path composition or mutation.

## D-199 — Optional directory and file sources use separate validated staging forms

- Status: Accepted
- Decision: Profile AppData, global Safari and system-global archives reuse validated directory staging, while shared DB, Preferences and Keychain artifacts use a new secure streaming file workspace.
- Reason: Tar trees require post-extraction topology validation; ordinary artifacts require stable descriptor-relative copy and digest equality rather than archive extraction.

## D-200 — Optional file staging is unique, no-follow and digest-bound

- Status: Accepted
- Decision: Each optional file is copied into a unique `/private/var/tmp` workspace, with source and payload identity checks, independent streaming SHA-256 and descriptor-relative cleanup.
- Reason: A verified backup path is a prior snapshot, not permanent operational byte authority for later helper or destination writes.

## D-201 — Optional destination collisions fail before mutation

- Status: Accepted
- Decision: Exact duplicate, file/directory conflict and ancestor/descendant overlap across optional destinations are rejected by the destination plan. The intentional Safari duplicate is removed semantically before collision checking.
- Reason: Two optional components must not independently mutate the same physical namespace or a parent/child target.

## D-202 — Shared-system DB sources are staged before daemon termination

- Status: Accepted
- Decision: All shared DB artifacts and destinations must be staged and revalidated before accounts, calendar, messaging or related daemons are stopped.
- Reason: Source or destination failure should not disrupt system services when no safe commit source exists.

## D-203 — Validated optional stages become operational source authority

- Status: Accepted
- Decision: After staging, optional directory clones, file copies and Keychain helper input use only validated stage paths. Restore-plan source paths remain semantic identity but are not direct target-write authority.
- Reason: Mutation must consume the inspected staged snapshot, not reopen the original artifact path at commit time.

## D-204 — Keychain execution semantics remain unchanged behind file staging

- Status: Accepted
- Decision: TASK-2.10 stages the Keychain input file but preserves plan-frozen groups, method selection, in-app decision, overwrite behavior and warning-only helper failure.
- Reason: Source stability and Keychain item semantics are separate gates; Phase 4 retains Keychain protocol and upsert hardening.

## D-205 — Optional staging and destination validation are not optional-component rollback

- Status: Accepted
- Decision: TASK-2.10 may preserve existing trash rename behavior but does not claim transaction safety. TASK-2.13 owns journaled commit and rollback for advanced components.
- Reason: Validating source bytes and destination identity does not recover already-mutated optional targets after a later failure.

## D-189 — TASK-2.8 closes the validated main-stage boundary

- Status: Accepted
- Decision: Commit `9aaa575c7ce0e62aeb155c459879043e1ea5acfb` is accepted. Main ApplicationData Restore now uses a unique retained workspace, fail-closed external extraction, descriptor-relative staged-tree validation and clone authority only from the immutable validated-stage result.
- Reason: Main target mutation must consume a complete safe filesystem snapshot rather than trusting a successful archive preflight or partial external extraction.

## D-190 — Signed App Group entitlements are mandatory Restore authorization

- Status: Accepted
- Decision: When `PXRestorePlan` contains App Group items, TASK-2.9 requires every planned group identifier to exact-match the target application's signed App Group entitlement set. Entitlement read or shape failure is a hard pre-mutation error rather than a warning.
- Reason: A manifest-declared group identity and filesystem metadata do not prove that the requested application is authorized to mutate a shared container.

## D-191 — Restore App Group destinations use typed root-specific resolution

- Status: Accepted
- Decision: Each planned group is resolved rootful then rootless through `resolveAppGroupContainerForGroupIdentifier:root:error:` and every non-nil model is passed through `PXDestructivePathValidator`. Legacy aggregate `AppGroupContainerInfo` results cannot authorize Restore mutation.
- Reason: Root-specific resolver errors, missing targets and distinct canonical ambiguity must remain visible instead of being flattened into a mutable first-match path list.

## D-192 — Canonical physical App Group targets are collapsed once

- Status: Accepted
- Decision: Exact group identifiers that canonical-validate to the same physical App Group path are represented by one immutable target containing all associated identities and models in deterministic plan/root order.
- Reason: Live App Group metadata can legitimately bind several exact identifiers to one container. Repeating destructive work per logical identity increases risk and distorts outcome semantics.

## D-193 — Every App Group source is staged before target wipe

- Status: Accepted
- Decision: TASK-2.9 stages and validates each planned App Group archive with the accepted `PXMainDataStagingWorkspace` boundary before the corresponding physical target is revalidated or wiped. Backup archives are never extracted directly into an App Group target.
- Reason: Archive-member validation is a preflight snapshot; an external extractor can still produce an unsafe or incomplete filesystem tree that must be rejected before shared-container mutation.

## D-194 — Shared-target App Group archives must be semantically identical

- Status: Accepted
- Decision: When several planned group identifiers map to one physical target, all staged sources must match exactly on tree digest, entry/file/directory counts and regular-file bytes. Conflicting sources fail before target mutation; no first/last archive wins.
- Reason: Applying multiple distinct archives sequentially to one shared container makes final content order-dependent and cannot be represented as one deterministic physical-target operation.

## D-195 — All App Group identity models are revalidated before one wipe

- Status: Accepted
- Decision: Immediately before an App Group target wipe, every retained `PXResolvedContainer` model must revalidate to the exact stored canonical path. The path is not replaced by a later validator output, and one physical target receives at most one wipe/clone pass.
- Reason: Staging creates a time interval after target planning. Every logical identity that authorized a shared physical target must still refer to that exact target at destructive use time.

## D-196 — TASK-2.9 is staged but nontransactional

- Status: Accepted
- Decision: TASK-2.9 preserves the current component order and direct post-validation wipe/clone behavior. It does not quarantine App Group targets, coordinate an atomic multi-target commit or roll back a previously restored target; TASK-2.12 retains those responsibilities.
- Reason: Exact authorization and safe staged-source validation are prerequisites for transaction design but do not themselves provide recovery after a later commit failure.
## D-206 - TASK-2.10 closes optional staging authority

- Status: Accepted
- Decision: Commit `96f93882876c59fdb0ded5feb98456be7daf5ec6` is accepted for optional destination planning, secure directory/file staging and pre-mutation revalidation. Main, App Group and optional rollback remain separate tasks.
- Reason: Optional target writes must consume retained validated stages and exact current-device destinations before transaction policy can be layered on top.

## D-207 - Main-data transaction uses same-filesystem rename states

- Status: Accepted after TASK-2.11A source review and owner continuation
- Decision: Main ApplicationData commit rejects a stage on another device and transitions top-level entries only with descriptor-relative `renameat` between target, `original/`, `new/` and the retained stage.
- Reason: Copy/delete cannot provide the identity-preserving rollback boundary required after target mutation begins.

## D-208 - Durable journal precedes mutation and committed phase precedes success

- Status: Accepted after TASK-2.11A source review and owner continuation
- Decision: A bounded binary journal containing raw names and device/inode/type identities is published before the first quarantine move. Restore success is exposed only after durable `committed` publication.
- Reason: Recovery must distinguish pre-mutation, partial quarantine, partial install and accepted commit after process interruption.

## D-209 - Same-name old/new entries are identity-disambiguated

- Status: Accepted after TASK-2.11A source review and owner continuation
- Decision: Rollback treats an entry as staged or original only when its journaled device/inode/type identity matches; name equality alone has no rollback authority.
- Reason: During partial quarantine, an original name can remain in target while the staged tree contains a different object with the same name.

## D-210 - Main-data transaction is serialized and exact-namespace checked

- Status: Accepted after TASK-2.11A source review and owner continuation
- Decision: A dedicated target descriptor holds an exclusive nonblocking `flock`. Target namespaces are compared exactly with the journal after quarantine, install and rollback.
- Reason: Advisory serialization and exact namespace gates prevent concurrent Restore work or unplanned target entries from being silently accepted.

## D-211 - Transaction cleanup cannot cross mounts or expose recovery data

- Status: Accepted after TASK-2.11A source review and owner continuation
- Decision: Cleanup is no-follow, bounded, same-filesystem and journal-last. When committed cleanup remains incomplete, manager ownership correction is skipped so the root-owned recovery workspace is not recursively transferred to mobile.
- Reason: Post-commit cleanup failure must remain recoverable without deleting through nested mounts or weakening journal/quarantine confidentiality.

## D-212 - TASK-2.11 requires corrective source work

- Status: Accepted
- Decision: Commit `e38db4081e849ed80b10e7fafaac70f2a4943646` remains the corrective baseline but is not accepted as completed. TASK-2.12 stays locked while TASK-2.11A addresses pre-recovery authority and durability blockers.
- Reason: The transaction architecture is valuable, but stale recovery currently precedes stage same-filesystem proof and unsupported directory synchronization is treated as success.

## D-213 - Recovery requires direct target, lock and stage proof first

- Status: Accepted
- Decision: Before any stale rollback or cleanup can mutate the target, the implementation must prove direct target/lock device-inode equality, hold the exclusive lock for that exact identity, bind the validated stage and require exact target-stage same-filesystem equality.
- Reason: Separate path checks at different moments do not prove that the held lock serializes the descriptor being recovered, and a cross-device stage must fail with zero target mutation.

## D-214 - Directory durability cannot be inferred from unsupported synchronization

- Status: Accepted
- Decision: A required transaction directory sync succeeds only after an actual synchronization primitive returns success. `EINVAL`, `ENOTSUP`, `EOPNOTSUPP` and similar unsupported results must fail closed rather than being translated into success.
- Reason: Durable journal phases and namespace transitions cannot be claimed when the containing directory was not synchronized.

## D-215 - TASK-2.11A is a one-file corrective boundary

- Status: Accepted
- Decision: TASK-2.11A may modify only `PXMainDataRestoreTransaction.m` plus its report. The public header, manager integration, journal schema, rollback model, App Group flow and optional-component flow remain byte-identical.
- Reason: The review blockers are localized to factory ordering, descriptor identity proof and synchronization semantics; widening scope would obscure regression evidence.

## D-216 - TASK-2.11 completes only after TASK-2.11A

- Status: Accepted
- Decision: Commit `9790a22ebee3b617a6fdd6cab0e0bba6b61dc45d` closes all TASK-2.11 source-review blockers. Main-data transaction and corrective task are both completed.
- Reason: Target, lock and stage are now proven before recovery, post-recovery authority is repeated, and unsupported synchronization can no longer create false durability.

## D-217 - App Group transaction is one physical-target batch

- Status: Accepted for TASK-2.12 implementation
- Decision: All exact physical App Group targets in one Restore operation are staged first and committed through one batch transaction. A later target failure must roll back every earlier App Group target affected by that batch.
- Reason: Per-target transactions still permit a partially restored App Group set and do not close the failure mode retained by TASK-2.9.

## D-218 - App Group locks are deterministic but commit order remains semantic

- Status: Accepted for TASK-2.12 implementation
- Decision: Target locks are acquired by exact canonical UTF-8 byte order to avoid multi-process deadlock, while quarantine/install order preserves immutable target-plan order.
- Reason: Serialization order must be globally deterministic; semantic execution order must remain stable and independent of filesystem enumeration.

## D-219 - One leader journal is the App Group batch decision

- Status: Accepted for TASK-2.12 implementation
- Decision: Every physical target owns a participant workspace, while the deterministic ordinal-zero target owns the sole durable batch decision journal. Durable `committed` in that leader journal decides the whole batch.
- Reason: Publishing independent committed decisions in several targets cannot be atomic. One leader decision allows crash recovery to distinguish rollback from cleanup without guessing from partial participant state.

## D-220 - Complete target and stage proof precedes App Group recovery

- Status: Accepted for TASK-2.12 implementation
- Decision: Every target, independent lock and validated stage in the complete batch must be descriptor-bound, locked and same-filesystem-proven before any stale App Group rollback or cleanup mutates a target.
- Reason: A failure in a later target or cross-device stage must not occur after an earlier target was already changed by recovery.

## D-221 - App Group cleanup controls ownership correction

- Status: Accepted for TASK-2.12 implementation
- Decision: Recursive mobile ownership correction runs only after the committed batch has removed every private participant workspace. If committed cleanup is incomplete, Restore emits a generic warning and leaves recovery state root-owned.
- Reason: `chown -R` over a target containing journal/quarantine data would expose recovery evidence and weaken the private transaction boundary.

## D-222 - TASK-2.12 completes the App Group batch transaction

- Status: Accepted
- Decision: Commit `9e83a053c4d4e2e42e0eac0a207467a5df2b3251` is accepted. Every exact physical App Group target is staged first and then committed or rolled back through one leader-journaled batch transaction.
- Reason: Deterministic locking, complete target/stage proof, exact stale binding, durable phase publication and reverse whole-batch rollback now close the partial App Group commit boundary retained by TASK-2.9.

## D-223 - Optional filesystem atomicity is domain-scoped

- Status: Accepted for TASK-2.13 specification
- Decision: Profile AppData, global Safari, system-global items, shared-system databases and Preferences use separate transaction domains in existing Restore order. A later domain failure does not roll back an earlier durably committed domain.
- Reason: One global transaction across unrelated filesystems, service boundaries and already accepted main/App Group transactions is not represented by the current architecture and must not be claimed implicitly.

## D-224 - Keychain remains outside Phase 2 filesystem rollback

- Status: Accepted for TASK-2.13 specification
- Decision: Keychain continues to consume a validated staged input and keeps its accepted groups/method/in-app/overwrite semantics, but it is not an optional filesystem transaction item.
- Reason: Current Keychain helper and bridge operations do not expose reversible per-item identity or rollback state. Pretending they participate in filesystem rename transactions would create false atomicity.

## D-225 - Optional transaction kinds model distinct destination semantics

- Status: Accepted for TASK-2.13 specification
- Decision: Optional transactions distinguish directory contents, complete directory objects and complete file objects. Profile/Safari preserve an existing root directory, system-global replaces a final directory object, and shared DB/Preferences replace a final regular file object.
- Reason: These targets have different authority, workspace, absence and rollback semantics. One untyped path operation would either weaken existing directory identity or fail to restore exact prior absence/object state.

## D-226 - Optional locks collapse by physical authority directory

- Status: Accepted for TASK-2.13 specification
- Decision: Lock order is exact destination UTF-8 order, but items sharing one physical parent or destination authority directory use one collapsed independent lock for that device/inode.
- Reason: Acquiring several advisory locks on the same inode inside one transaction is unnecessary and can create incorrect lock-lifetime assumptions. Physical authority, not path spelling count, determines serialization.

## D-227 - Optional file transaction prepares a private replacement copy

- Status: Accepted for TASK-2.13 specification
- Decision: File-object transactions copy the retained validated file stage into a private same-filesystem replacement and independently verify byte count and SHA-256 before prepared publication. The original staging payload remains intact until accepted workspace cleanup.
- Reason: Atomic destination replacement requires a sibling object on the destination filesystem, while `PXOptionalFileStagingWorkspace` cleanup requires its retained payload identity to remain present.

## D-228 - TASK-2.14 remains locked behind optional transaction review

- Status: Accepted
- Decision: Structured Restore result work cannot begin until TASK-2.13 passes source review and owner build confirmation.
- Reason: Component outcomes cannot be represented truthfully while optional filesystem domains still have nontransactional partial-commit behavior.

## D-229 - TASK-2.13 requires a corrective verifier implementation

- Status: Accepted
- Decision: Commit `08d23dd0a9fa41a39efd5b62680974f23e75fe45` remains CHANGES_REQUESTED because `PXOptionalRestoreVerifyDirectoryTree` has two production call sites and no declaration or definition.
- Reason: A permissive frontend cannot turn an absent implementation into a linkable symbol, and DirectoryObject replacement safety cannot be claimed without the required tree proof.

## D-230 - Optional directory replacement must reproduce the accepted staged-tree digest

- Status: Accepted for TASK-2.13A implementation
- Decision: The corrective verifier must reproduce the exact `PXMainDataStageTreeV1` binary digest format, including the terminating NUL in the domain prefix, and must compare all five accepted snapshot fields.
- Reason: Top-level inode equality alone does not prove nested replacement contents. Digest, entry counts and byte totals must remain identical to the stage already accepted by TASK-2.8.

## D-231 - TASK-2.13A is a one-file corrective boundary

- Status: Accepted
- Decision: TASK-2.13A may modify only `PXOptionalRestoreTransaction.m` plus its report. The public header, manager integration, journal schema, rollback state machine, accepted transactions and Keychain boundary remain byte-identical.
- Reason: The review blocker is localized to a missing private function. Widening scope would obscure link evidence and create unnecessary regression risk.

## D-232 - TASK-2.14 remains locked until the corrective task closes TASK-2.13

- Status: Accepted
- Decision: Structured Restore result work cannot begin while TASK-2.13A is open. TASK-2.13 completes only after the verifier compiles, links and passes source review.
- Reason: A structured success result would be misleading while one optional transaction path contains an unresolved symbol and cannot prove its prepared replacement tree.

## D-233 - TASK-2.13 completes through TASK-2.13A

- Status: Accepted
- Decision: Commit `9d046a406a5a346cab2a66d3fc27c71d702b9321` closes the missing optional directory-tree verifier and completes both TASK-2.13A and TASK-2.13.
- Reason: The two retained DirectoryObject verification sites now resolve to one real file-local implementation that reproduces the accepted staged-tree digest, count, byte, topology and stability contract without widening production scope.

## D-234 - Restore result is one immutable eight-component final snapshot

- Status: Accepted for TASK-2.14 specification
- Decision: `PXRestoreResult` represents exactly ApplicationData, ProfileAppData, GlobalSafari, AppGroups, SystemGlobal, SharedSystemDatabases, Preferences and Keychain, with one final immutable result for every known component.
- Reason: Exact coverage prevents omitted optional outcomes, while a closed canonical component set gives Phase 5 a stable value model without turning the result into another orchestration engine.

## D-235 - Requested but unexecuted is distinct from skipped

- Status: Accepted for TASK-2.14 specification
- Decision: A component absent from the accepted plan is `Skipped`; a requested component stopped by an earlier hard failure is `NotAttempted`. These states must not be merged.
- Reason: Configuration intent and execution reachability are different facts. Treating both as skipped would hide that a requested Restore domain never ran because another domain failed first.

## D-236 - Structured result availability begins after accepted Restore planning

- Status: Accepted for TASK-2.14 specification
- Decision: Manifest, identity, artifact, archive, Restore-plan, tar, App Group target-plan and optional destination-plan failures preserve `nil result + error`. After those authorities exist and component planning succeeds, every hard failure returns `result + error`.
- Reason: Before accepted planning there is no trustworthy complete component set or planned-unit count. After planning, returning only an error discards already committed domains, rollback state and later not-attempted intent.

## D-237 - Rollback outcome is explicit component state

- Status: Accepted for TASK-2.14 specification
- Decision: Transaction failures record rollback as NotPerformed, Completed or Incomplete from the retained typed transaction flags. Rollback state is never inferred from an error code, message or target contents.
- Reason: A failed component that rolled back safely differs materially from one with incomplete recovery evidence, and neither is equivalent to a committed success.

## D-238 - Keychain warning-only compatibility remains truthful in the result

- Status: Accepted for TASK-2.14 specification
- Decision: A Keychain helper or bridge execution failure continues Restore with `completion error == nil`, but the Keychain component is Failed with a stable synthetic failure snapshot and rollback NotPerformed.
- Reason: Phase 4 has not introduced reversible per-item Keychain semantics, so the legacy warning-only callback policy remains; nevertheless, a structured result must not misreport failed Keychain work as success.

## D-239 - Legacy warnings and current UI callers remain compatible

- Status: Accepted for TASK-2.14 specification
- Decision: `PXRestoreResult.warnings` remains available as an immutable readonly array preserving exact current warning text and append order. TASK-2.14 does not modify UI/controller callers or presentation.
- Reason: Result truth can be added without coupling Phase 2 to alert-title, message, RRS-flow or component-display changes reserved for Phase 5.

## D-240 - Phase 2 closes only after structured result acceptance

- Status: Accepted
- Decision: TASK-2.14 is the final Phase 2 task. Phase 3 and later phases remain locked until its source, report and owner build gate are accepted.
- Reason: Atomic Backup publication should not begin until Restore exposes a stable final account of committed, failed, rolled-back, skipped and not-attempted domains.
## D-241 - Structured result mutations cannot depend on assertion evaluation

- Status: Accepted
- Decision: Calls that mark component success/failure or attach component warnings must execute outside NSCAssert and NSAssert condition expressions.
- Reason: NS_BLOCK_ASSERTIONS may remove assertion condition evaluation. A release build must not publish a different Restore result from the same executed transactions merely because diagnostic assertions are disabled.

## D-242 - TASK-2.14A is a manager-only corrective boundary

- Status: Accepted
- Decision: TASK-2.14A may modify only AppDataBackupManager.m plus its report. PXRestoreResult.h/.m, the manager header, accepted transaction/staging/planning source, UI callers, warning text/order, and Keychain execution semantics remain unchanged.
- Reason: The defect is localized to ten manager call sites. Widening the correction would obscure release-mode proof and create unnecessary regression risk in the accepted immutable model.

## D-243 - Phase 3 remains locked until assertion-independent result publication is accepted

- Status: Accepted
- Decision: TASK-2.14 remains CHANGES_REQUESTED and Phase 3 cannot open until TASK-2.14A proves identical accumulator mutations with assertions enabled and disabled.
- Reason: Atomic Backup publication must not begin while Restore can report committed work as NotAttempted in a final-package configuration.

## D-244 - TASK-2.14 completes through TASK-2.14A

- Status: Accepted
- Decision: Commit `0ef0631af3696531251ee4a4dfbfb953e9f2bc81` closes the assertion-elision defect and completes TASK-2.14A, TASK-2.14 and Phase 2.
- Reason: All eleven accumulator mutations now execute independently of assertion evaluation while the immutable model, warning sequence, completion contract and protected production source remain unchanged.

## D-245 - New Backup output begins in a private reserved partial namespace

- Status: Accepted for TASK-3.1 specification
- Decision: Each Backup run writes into one direct per-bundle child created from .weaponx-backup-partial-XXXXXX; it must not write directly into the timestamp directory intended for eventual publication.
- Reason: Unique private workspaces prevent timestamp collisions and keep incomplete work outside the final public namespace required by later atomic publication.

## D-246 - Partial workspaces are explicit but undiscoverable

- Status: Accepted for TASK-3.1 specification
- Decision: During TASK-3.1, successful completion may return the explicit partial workspace path for immediate callers, but normal profile and legacy discovery must skip every direct child beginning with .weaponx-backup-partial- before manifest inspection.
- Reason: Immediate RRS/Restore callers need a usable path while Phase 3 is built incrementally, but a partial workspace must never be mistaken for an atomically published backup merely because it contains a manifest.

## D-247 - Partial workspace identity is descriptor-bound before Backup writes

- Status: Accepted for TASK-3.1 specification
- Decision: Backup root, per-bundle directory and unique workspace must be no-follow/CLOEXEC descriptor-bound with exact device/inode/type proof and same-filesystem relationships. The manager revalidates the retained identity before output setup, before manifest write and before success-result construction.
- Reason: A unique path string alone does not prevent path replacement. Later writers and publication require a stable source namespace anchored to retained filesystem objects.

## D-248 - TASK-3.1 does not publish or centrally clean partial work

- Status: Accepted
- Decision: TASK-3.1 introduces no final rename/move, no publication marker, no per-bundle lock, no recursive stale cleanup and no schema/artifact policy changes. TASK-3.8 owns final publication, TASK-3.9 owns centralized failure cleanup and TASK-3.10 owns stale partial cleanup.
- Reason: Separating workspace creation from serialization, verified writing, manifest policy, publication and cleanup keeps each safety boundary independently reviewable.
## D-249 - TASK-3.1 establishes the private Backup workspace boundary

- Status: Accepted
- Decision: Commit `2db8d448f1e89e74979a64f38e48ae3304ab353e` completes TASK-3.1. Backup output now begins in one descriptor-bound `.weaponx-backup-partial-XXXXXX` workspace, normal discovery excludes partial names, and no final publication occurs.
- Reason: The accepted source proves unique workspace identity and keeps incomplete output outside the normal discovery namespace without prematurely implementing later publication or cleanup tasks.

## D-250 - Per-bundle Backup serialization uses a persistent kernel lock file

- Status: Accepted for TASK-3.2 specification
- Decision: Each canonical per-bundle Backup directory owns one persistent `.weaponx-backup.lock` regular file. An exclusive flock on the retained file descriptor is the only serialization authority; file existence or file contents are not lock state.
- Reason: Kernel descriptor ownership survives thread/process concurrency correctly and is automatically released on process death, while a stable file inode allows root aliases to converge on the same serialization domain.

## D-251 - Backup lock contention fails fast before operational work

- Status: Accepted for TASK-3.2 specification
- Decision: TASK-3.2 uses `LOCK_EX | LOCK_NB`. `EWOULDBLOCK` or `EAGAIN` is a hard exact lock-domain failure before tar discovery, source resolution, workspace creation, process kill, or output creation. The implementation does not wait, sleep, or continue unlocked.
- Reason: An unbounded wait has no cancellation/deadline contract and can hang Backup indefinitely. Failing before side effects preserves a deterministic caller-visible boundary.

## D-252 - Serialization scope is the exact canonical backup-root and bundle pair

- Status: Accepted for TASK-3.2 specification
- Decision: Lexical root aliases resolving to the same physical per-bundle directory share one lock. Different exact bundle directories may proceed concurrently. Physically distinct backup roots remain separate lock domains.
- Reason: The lock protects one publication namespace without introducing a global bottleneck or silently coupling different profile roots.

## D-253 - TASK-3.2 preserves TASK-3.1 and later publication boundaries

- Status: Accepted
- Decision: The TASK-3.1 workspace implementation and discovery exclusions remain byte-identical. TASK-3.2 adds no artifact writer, manifest policy, publication rename, centralized cleanup, or stale partial deletion.
- Reason: Serialization is an independent concurrency boundary. Mixing it with artifact correctness or publication would make lock behavior and failure ordering harder to review.
## D-254 - TASK-3.2 establishes the per-bundle serialization boundary

- Status: Accepted
- Decision: Commit `dbfeb65ce709bbe4c9698c7cf0ad06b779bf147b` completes TASK-3.2. Backup now retains one persistent `.weaponx-backup.lock` inode and exclusive nonblocking flock for the exact canonical bundle Backup directory through result construction.
- Reason: The accepted source proves pre-side-effect contention failure, exact descriptor identity, four ownership validations, crash-safe kernel release, and TASK-3.1 byte identity.

## D-255 - A Backup artifact is authoritative only after common writer finalization

- Status: Accepted for TASK-3.3 specification
- Decision: Producer success or path existence is insufficient. An artifact becomes manifest-authoritative only after the common writer verifies stable regular-file identity, exact size, streaming SHA-256, strict durability, descriptor-relative final rename, final namespace identity, and temporary cleanup.
- Reason: Current path rescans can emit empty hashes, tolerate missing metadata, and observe a different file after production. A retained writer boundary creates one auditable acceptance point.

## D-256 - Producers write only into artifact-local temporary directories

- Status: Accepted for TASK-3.3 specification
- Decision: Each semantic producer receives only `.weaponx-artifact-partial-XXXXXX/payload`. The common writer publishes the payload to the requested relative artifact name with `renameat` only after verification.
- Reason: A temporary directory supports tar, copy, helper, and in-app producers that create or replace their output path while preserving a descriptor-bound parent and preventing direct writes to a manifest-authoritative final name.

## D-257 - Verified artifact records replace path-based metadata and re-verification

- Status: Accepted for TASK-3.3 specification
- Decision: `PXFileSHA256`, `PXHexString`, `PXArtifactInfo`, and `PXVerifyArtifact` are removed from Backup authority. Manifest artifact dictionaries, total size, artifact count, component mappings, and the data archive checksum derive only from immutable verified records.
- Reason: Reopening artifacts later by string path creates race windows and lets incomplete metadata enter the manifest. A finalized immutable record binds the accepted path, size, and digest snapshot.

## D-258 - TASK-3.3 does not decide policy or publish the Backup

- Status: Accepted
- Decision: Preferences remains option-based until TASK-3.4; formal required/optional handling remains TASK-3.5; manifest v4 and atomic manifest handling remain TASK-3.6/TASK-3.7; only TASK-3.8 may rename the partial workspace into the final Backup namespace.
- Reason: Artifact correctness, component policy, manifest protocol, and directory publication are separate safety boundaries and must remain independently reviewable.
## D-259 - TASK-3.3 establishes verified artifact authority

- Status: Accepted
- Decision: Commit `849b2825c0cffc60db33f11ac769f35aae6c78e3` completes TASK-3.3. Only immutable records returned after stable streaming verification, strict durability, descriptor-relative rename, final identity proof and temporary cleanup may enter the Backup manifest.
- Reason: The accepted writer removes path-rescan metadata races and gives all eight producer classes one auditable artifact-acceptance boundary.

## D-260 - Preferences request and inclusion are separate facts

- Status: Accepted for TASK-3.4 specification
- Decision: `options.includePreferences` records the caller request. `preferences.included` is true only when the common writer returned a nonnil verified Preferences artifact record.
- Reason: An option bit cannot prove that the source existed, copying succeeded, durability completed or a restorable artifact was finalized.

## D-261 - Excluded Preferences retain a manifest-v3 locator without artifact authority

- Status: Accepted for TASK-3.4 specification
- Decision: When Preferences is not included, `preferences.archive` remains the exact nonempty `preferences/<bundleID>.plist` locator required by manifest v3, while no verified artifact declaration is emitted and Restore ignores the locator because `included` is false.
- Reason: This keeps current schema validation valid without falsely declaring or restoring an artifact that was not produced.

## D-262 - GlobalPreferences option reporting follows verified inclusion

- Status: Accepted for TASK-3.4 specification
- Decision: `includedOptions` contains `GlobalPreferences` only after verified Preferences success; otherwise `excludedOptions` contains it. App Group and Keychain option-name behavior remains unchanged in this task.
- Reason: Top-level inclusion reporting must describe the produced Backup, while the nested raw options dictionary preserves the original request for diagnostics.

## D-263 - TASK-3.4 does not define optional-artifact failure policy

- Status: Accepted
- Decision: Missing Preferences retains its existing warning, copy/writer failure adds no new warning, and Backup continues. TASK-3.5 remains the owner of formal required/optional and zero-length policy.
- Reason: Correcting factual inclusion is independent from deciding whether failure to produce an optional artifact should fail the whole Backup.
## D-264 - TASK-3.4 closes Preferences factual inclusion

- Status: Accepted
- Decision: Commit `339ca0129da1af9a87cd5e3bbca7ffff17085352` completes TASK-3.4. The raw Preferences option records the request, while `preferences.included` and `GlobalPreferences` option reporting reflect only a verified TASK-3.3 record.
- Reason: A requested copy is not a produced, durable or restorable artifact.

## D-265 - Artifact policy is bound before writer finalization

- Status: Accepted for TASK-3.5 specification
- Decision: Every TASK-3.3 writer call must receive an immutable canonical artifact policy, and the writer must reject disallowed zero-length output before file sync, final rename, record construction or accepted-set mutation.
- Reason: Rejecting an artifact after rename would leave unreferenced finalized content in the partial workspace and weaken the single acceptance boundary.

## D-266 - ApplicationData is the only required Backup artifact

- Status: Accepted for TASK-3.5 specification
- Decision: ApplicationData is required and aborts Backup on any producer, verification, policy, durability or finalization failure. App Group, profile, Safari, system-global, shared DB, Preferences and Keychain artifacts are optional with explicit warn-or-silent dispositions.
- Reason: A Backup without ApplicationData cannot satisfy the minimum Restore contract, while optional domains may be absent without invalidating the main container snapshot.

## D-267 - Shared-system DB files are the zero-length exception

- Status: Accepted for TASK-3.5 specification
- Decision: Zero-byte output is rejected for data/App Group/profile/Safari/system-global archives and Preferences/Keychain plists. Shared-system DB files may be zero bytes because exact SQLite database, WAL and SHM snapshots can legitimately be empty.
- Reason: A global nonempty rule would reject valid sidecar state, while accepting empty tar or plist output would describe unusable artifacts as successful.

## D-268 - Failure visibility is part of the canonical artifact policy

- Status: Accepted for TASK-3.5 specification
- Decision: App Group, profile, Safari and system-global writer failures preserve their exact warnings. Preferences and Keychain add no new generic writer warning. Shared DB per-file failure remains silent and is represented by the existing aggregate warning. ApplicationData returns the existing hard error.
- Reason: Formalizing policy must make every failure branch explicit without introducing duplicate or destabilizing user-visible messages.

## D-269 - Manifest v3 does not carry policy metadata

- Status: Accepted for TASK-3.5 specification
- Decision: Verified records retain their applied policy for in-process audit, but manifest v3 artifact dictionaries remain exactly `name`, `path`, `size` and `sha256`. Manifest policy serialization belongs to TASK-3.6 or later only if the v4 contract requires it.
- Reason: Artifact production policy and manifest schema evolution are separate review boundaries.
## D-270 - TASK-3.5 closes artifact production policy

- Status: Accepted
- Decision: Commit `5366c503a3946faafc7a107c4e411255ece3e0f3` completes TASK-3.5. Every artifact is produced under one immutable canonical policy, rejected before finalization when disallowed, and audited before manifest construction.
- Reason: Required/optional, warning and zero-length behavior are now explicit and no longer implicit in eight unrelated branches.

## D-271 - V4 artifact paths are relative publication-stable locators

- Status: Accepted for TASK-3.6 specification
- Decision: Every v4 artifact declaration stores `path == name`, both as the exact safe relative path. The absolute `PXVerifiedBackupArtifact.filePath` is never serialized into v4.
- Reason: Absolute paths under the private partial workspace become stale when TASK-3.8 renames the completed directory and must not be portable artifact metadata.

## D-272 - V4 persists canonical artifact policy as strings

- Status: Accepted for TASK-3.6 specification
- Decision: Each v4 artifact declaration contains a four-field policy dictionary using exact stable strings for kind, requirement, failure disposition and empty-file policy. Numeric Objective-C enum values are not serialized.
- Reason: Persisted policy lets structural validation prove the same minimum contract after disk read without coupling the schema to compiler-specific enum representation.

## D-273 - V4 requires exact declaration-reference coverage

- Status: Accepted for TASK-3.6 specification
- Decision: Every declared v4 artifact must be referenced by exactly one matching Restore component, every included component must reference one declared artifact of the correct kind, and orphan or multiply referenced artifacts are rejected.
- Reason: A verified file that is not represented in the Restore graph is not part of the Backup snapshot and must not silently increase count or size.

## D-274 - V4 ends the excluded Preferences locator exception

- Status: Accepted for TASK-3.6 specification
- Decision: Manifest v3 retains its nonempty excluded Preferences locator for backward schema compatibility. Manifest v4 requires `preferences.archive == ""` when excluded and an exact Preferences declaration name when included.
- Reason: V4 can express exclusion directly and no longer needs a syntactically required locator for an artifact that does not exist.

## D-275 - V4 separates content completeness from directory visibility

- Status: Accepted for TASK-3.6 specification
- Decision: The v4 publication section records protocol `atomic-directory-v1` and content state `complete`. This means the immutable manifest snapshot contains all required content; it does not assert that the partial directory is already visible in the final Backup namespace.
- Reason: TASK-3.7 writes the completed manifest inside private work, while TASK-3.8 alone owns the visibility transition by directory rename.

## D-276 - V4 introduces one stable Backup identifier

- Status: Accepted for TASK-3.6 specification
- Decision: Backup creates one canonical lowercase UUID independent of timestamp, PID, bundle identifier and workspace name. The UUID is stored as `backupID` and may later participate in collision-safe final publication naming.
- Reason: Timestamp-only identity is not unique enough for durable publication and recovery protocols.

## D-277 - V2 and V3 validation remain legacy-isolated

- Status: Accepted for TASK-3.6 specification
- Decision: `PXBackupManifestValidator` keeps one accepted legacy path for versions 2 and 3 and adds a separate strict v4 path. Other positive integral versions remain structurally separable so the manager continues to return existing unsupported-version code 201.
- Reason: Introducing v4 must not silently reinterpret old manifests or break the established structural-versus-support-policy boundary.

## D-278 - TASK-3.6 does not change manifest file publication

- Status: Accepted
- Decision: TASK-3.6 constructs and validates the immutable v4 dictionary in memory but retains the current `writeToFile:atomically:` call and warning behavior. Descriptor-relative manifest temp creation, fsync, read-back and rename remain TASK-3.7.
- Reason: Schema correctness and durable file publication are independent safety boundaries.
## D-279 - TASK-3.6 requires corrective exception-safety work

- Status: Accepted
- Decision: Commit `c11ac70d2389eb9a9722396336a4ff92826d9e31` remains CHANGES_REQUESTED until TASK-3.6A proves malformed v4 field types cannot trigger Objective-C selector exceptions.
- Reason: A schema validator is a trust boundary. Returning the correct result for valid fixtures is insufficient when wrong-type values can bypass NSError handling and crash the application.

## D-280 - Runtime type proof precedes type-specific selectors

- Status: Accepted for TASK-3.6A
- Decision: Both the public v4 builder and on-disk v4 validator must prove exact runtime type before sending `boolValue`, `isEqualToString:`, string-prefix, encoding or similar type-dependent selectors.
- Reason: Static Objective-C pointer declarations do not validate dynamic objects read from dictionaries.

## D-281 - Exact Boolean extraction is centralized

- Status: Accepted for TASK-3.6A
- Decision: V4 inclusion and request fields are read only through one exact-CFBoolean helper per implementation. Integer `0`/`1`, strings and arbitrary objects are rejected before `boolValue` is called.
- Reason: Boolean policy must remain exact and exception-safe across builder and validator paths.

## D-282 - V4 validation errors are created on demand

- Status: Accepted for TASK-3.6A
- Decision: The validator must not pre-populate a generic placeholder error at the beginning of valid v4 validation. Every failure branch must create or preserve a specific nonnil error; success must return with a nil error.
- Reason: Eager placeholder errors obscure which branch actually failed and make bare failure paths harder to audit.
## D-283 - TASK-3.6A closes malformed-type exception safety

- Status: Accepted
- Decision: Commit `3a7d3f8fe8a98747fe6c823167250e43b8159e9f` completes TASK-3.6A and the parent TASK-3.6. Builder and validator now prove runtime types before type-specific selectors and contain unexpected exceptions at public v4 boundaries.
- Reason: Malformed on-disk metadata must return bounded errors rather than crash Backup or Restore.

## D-284 - Manifest file publication is a dedicated retained authority

- Status: Accepted for TASK-3.7
- Decision: Introduce `PXBackupManifestWriter`, bound to the exact TASK-3.1 workspace, as the sole authority that may create, validate, rename and retain `manifest.plist`.
- Reason: Manager path strings and `writeToFile:atomically:` do not prove namespace identity, strict durability or read-back equivalence.

## D-285 - Manifest serialization uses bounded binary plist

- Status: Accepted for TASK-3.7
- Decision: Serialize only the immutable v4 representation using binary property-list format with a hard 128-MiB limit.
- Reason: Binary plist provides one deterministic property-list payload suitable for exact bounded write and read-back without changing schema semantics.

## D-286 - Manifest acceptance requires validation before and after rename

- Status: Accepted for TASK-3.7
- Decision: The temporary manifest and the final `manifest.plist` are each independently parsed, passed through `PXBackupManifestValidator`, and deep-equality checked against the immutable v4 snapshot.
- Reason: Serialization success and atomic rename alone do not prove that the durable file represents the accepted in-memory snapshot.

## D-287 - Manifest write failure is a hard Backup failure

- Status: Accepted for TASK-3.7
- Decision: Remove the `Failed to write manifest` warning-and-continue path. Any manifest serialization, durability, validation, rename or cleanup failure completes Backup with nil result and the exact manifest-writer error.
- Reason: A Backup without one accepted manifest cannot be safely discovered, restored or published.

## D-288 - Manifest temp names are random descriptor-relative children

- Status: Accepted for TASK-3.7
- Decision: Temporary manifest files use `.weaponx-manifest-partial-` plus 32 lowercase hexadecimal characters from 16 random bytes and are created with descriptor-relative `openat(O_EXCL|O_NOFOLLOW|O_CLOEXEC)`.
- Reason: Predictable or path-based temporary names create avoidable collision and symlink-race authority.

## D-289 - TASK-3.7 publishes a file, not the Backup directory

- Status: Accepted
- Decision: TASK-3.7 atomically exposes `manifest.plist` only inside the private partial workspace. TASK-3.8 remains the sole owner of the whole-directory visibility transition.
- Reason: File completeness and Backup namespace publication are separate durability boundaries.
## D-290 - TASK-3.7 closes atomic manifest-file publication

- Status: Accepted
- Decision: Commit `bf9e51852b06ab3bfa7d85a3e5b880a64500ba3a` completes TASK-3.7. The final manifest is accepted only after bounded binary serialization, strict durability, pre/post rename validation and retained final-descriptor proof.
- Reason: A successful Backup may no longer depend on best-effort path writing or warning-and-continue manifest failure.

## D-291 - Published directory names combine UTC timestamp and backup UUID

- Status: Accepted for TASK-3.8
- Decision: The visible final name is exactly `<yyyyMMdd-HHmmss UTC>-<canonical lowercase backup UUID>`.
- Reason: The timestamp prefix preserves current newest-first lexical sorting while the UUID suffix prevents same-second collisions.

## D-292 - Whole-directory publication has a dedicated retained authority

- Status: Accepted for TASK-3.8
- Decision: Introduce `PXBackupDirectoryPublisher`, created before output side effects, which retains exact parent and workspace descriptors through final result construction.
- Reason: TASK-3.1 workspace paths become stale after rename; directory publication must be proven using retained inode authority rather than reconstructed paths.

## D-293 - Forward publication and rollback share one rename authority

- Status: Accepted for TASK-3.8
- Decision: One file-local helper contains the sole production `renameat` call site and is used for both partial-to-final publication and final-to-partial rollback.
- Reason: A single audited same-parent rename primitive reduces divergent publication behavior and supports exact post-rename rollback.

## D-294 - Post-rename failure returns the directory to the partial namespace

- Status: Accepted for TASK-3.8
- Decision: Any failure after forward rename but before accepted publication must reverse-rename the exact retained directory to its original `.weaponx-backup-partial-*` name and strict-sync the parent.
- Reason: The existing discovery exclusion then keeps failed publication evidence hidden without adding premature discovery logic.

## D-295 - Final publication replays manifest authority under the new path

- Status: Accepted for TASK-3.8
- Decision: After directory rename, independently open the final directory and `manifest.plist`, then verify manifest size, digest, validator result and deep representation equality against TASK-3.7 retained state.
- Reason: Rename identity alone does not prove that the publicly visible directory exposes the accepted manifest snapshot.

## D-296 - TASK-3.8 returns only published paths

- Status: Accepted
- Decision: Successful `PXBackupResult.backupDirectory` and `manifestPath` come only from the accepted directory publisher. Partial workspace paths are no longer successful results.
- Reason: Immediate RRS/Restore callers must consume the same final namespace that normal discovery will expose.

## D-297 - TASK-3.8 does not add a publication marker or discovery changes

- Status: Accepted
- Decision: Atomic same-parent directory rename is the visibility transition. TASK-3.8 leaves discovery source byte-identical and adds no marker/index/sidecar protocol.
- Reason: TASK-3.10 remains responsible for broader discovery validation and stale or indeterminate publication recovery.
## D-298 - TASK-3.8 remains open because plain rename is not no-replace

- Status: Accepted
- Decision: Commit `494cae02f042bb0e115fa780f2683e124467fda9` is CHANGES_REQUESTED. Its final absence check followed by plain `renameat` does not atomically prevent replacement of a competing empty destination directory.
- Reason: Namespace collision policy must hold at the filesystem commit operation, not only at a preceding observation.

## D-299 - Atomic no-replace rename is the publication collision authority

- Status: Accepted for TASK-3.8A
- Decision: Both forward publication and reverse rollback use `renameatx_np(..., RENAME_EXCL)` through one file-local helper.
- Reason: Darwin no-replace semantics preserve both source and destination when the destination exists at syscall time.

## D-300 - Publication prechecks are diagnostic, not commit authority

- Status: Accepted
- Decision: Retain destination-absence checks for early failure and race reduction, but do not cite them as proof of no-overwrite behavior.
- Reason: A competing namespace entry can appear after any separate `fstatat` check.

## D-301 - Forward no-replace collisions have a distinct public result

- Status: Accepted for TASK-3.8A
- Decision: Forward `EEXIST` or `ENOTEMPTY` maps to the existing `FinalDirectoryAlreadyExists` error and does not enter reverse rollback.
- Reason: The forward rename did not occur, so the partial workspace remains authoritative and no rollback is needed.

## D-302 - Reverse no-replace collisions preserve both namespace entries

- Status: Accepted for TASK-3.8A
- Decision: If the original partial name appears before reverse rollback commits, return `RollbackFailed` and leave both final and competing partial entries untouched.
- Reason: Recovery must never overwrite evidence or an independently created namespace entry.

## D-303 - No overwrite-capable fallback is allowed

- Status: Accepted for TASK-3.8A
- Decision: If the Apple SDK cannot provide `renameatx_np` and `RENAME_EXCL`, compilation must fail. No plain `renameat`, path-based move, copy/delete, private syscall or shell fallback is permitted.
- Reason: Availability failure is safer than silently weakening the atomic publication contract.
## D-304 - TASK-3.8A closes the atomic no-replace publication gap

- Status: Accepted
- Decision: Commit `e55e9d682a4b6d6de480f277f686a81e17b7498b` completes TASK-3.8A and TASK-3.8.
- Reason: Forward and reverse namespace transitions now use one `renameatx_np(..., RENAME_EXCL)` authority with no overwrite-capable fallback.

## D-305 - TASK-3.9 cleans only the current retained partial workspace

- Status: Accepted for TASK-3.9
- Decision: Operation-level cleanup is bound to the exact parent/workspace descriptors created for the current Backup operation.
- Reason: Historical sibling scanning belongs to TASK-3.10; current-operation identity is strongest while the per-bundle lock and descriptors remain retained.

## D-306 - All post-workspace failures use one cleanup completion funnel

- Status: Accepted for TASK-3.9
- Decision: The 33 baseline failure exits after workspace creation must call one manager failure funnel containing the sole `cleanupWithError:` call site.
- Reason: Distributed completion paths currently bypass cleanup and make coverage difficult to prove.

## D-307 - Original operation errors survive successful cleanup

- Status: Accepted
- Decision: When partial-tree cleanup succeeds, deliver the exact original NSError object without wrapping or replacement.
- Reason: Cleanup is operational hygiene and must not erase the actual Backup failure cause.

## D-308 - Cleanup errors take precedence when cleanup is incomplete

- Status: Accepted
- Decision: When cleanup fails, deliver the exact cleanup NSError and preserve unsafe or ambiguous evidence.
- Reason: A remaining partial or indeterminate publication state requires explicit attention and is more operationally important than the initiating failure.

## D-309 - Operation cleanup deletes only proven ordinary tree entries

- Status: Accepted for TASK-3.9
- Decision: Descriptor-relative traversal may remove only exact regular files and ordinary directories on the retained filesystem. Symlinks, special files, hard links, setid entries, cross-filesystem entries and changed identities stop cleanup.
- Reason: Centralization must not weaken the no-follow and evidence-preservation rules established by earlier writers.

## D-310 - Published final directories are outside cleanup authority

- Status: Accepted
- Decision: If the original partial name is absent or no longer maps to the retained workspace, TASK-3.9 must fail and preserve evidence rather than search for or delete a timestamp/UUID final directory.
- Reason: A rollback-failed or already published directory may be visible and valid; automatic deletion would cross the publication commit boundary.

## D-311 - Cleanup is explicitly disarmed after accepted publication

- Status: Accepted for TASK-3.9
- Decision: After publisher success and post-publication identity validation, the cleanup object must validate the exact publisher and enter a disarmed state before result construction.
- Reason: Explicit disarm makes the success/cleanup boundary auditable and prevents deallocation behavior from becoming deletion authority.

## D-312 - TASK-3.9 uses bounded post-order descriptor traversal

- Status: Accepted
- Decision: Cleanup uses a maximum depth of 64, 16,384 visited entries and 8 MiB of accumulated component-name bytes, with post-order removal and strict directory synchronization.
- Reason: Current output can contain thousands of verified artifacts and parent directories, but cleanup must remain resource-bounded and fail closed.
## D-313 - TASK-3.9 remains open because check-then-unlink can delete a replacement

- Status: Accepted
- Decision: Commit `aa47468a1bb6944aa3ad304e24a74483f16944c3` is CHANGES_REQUESTED.
- Reason: Final namespace revalidation and `unlinkat` are separate operations. A replacement can appear in that gap and be deleted before the retained-descriptor post-check detects the mismatch.

## D-314 - Cleanup must atomically capture before destructive removal

- Status: Accepted for TASK-3.9A
- Decision: Regular files, subdirectories and the root partial workspace must first move from their original name to a private random quarantine name using `renameatx_np(..., RENAME_EXCL)`.
- Reason: Atomic source capture lets cleanup verify which inode crossed the commit boundary before unlink/rmdir.

## D-315 - Quarantine mismatches are restored, not deleted

- Status: Accepted for TASK-3.9A
- Decision: If a captured quarantine entry does not equal the retained descriptor identity, cleanup must attempt a no-replace move back to the original name and return an error.
- Reason: A replacement race must preserve the unproven entry and all ambiguous evidence.

## D-316 - Quarantine names use 128 bits of random state

- Status: Accepted for TASK-3.9A
- Decision: Current-operation quarantine names use `.weaponx-cleanup-quarantine-` followed by 32 lowercase hexadecimal characters generated from 16 random bytes, with at most 16 collision retries.
- Reason: Private unpredictable names minimize interference while remaining bounded and auditable.

## D-317 - Factory cleanup uses the same capture-before-delete rule

- Status: Accepted for TASK-3.9A
- Decision: Empty-workspace cleanup after factory setup failure must atomically quarantine the exact retained workspace before `AT_REMOVEDIR`.
- Reason: Factory failure is not exempt from the root replacement race.

## D-318 - Funnel counts exclude the block definition

- Status: Accepted
- Decision: The TASK-3.9 audit requires one funnel definition and exactly 33 invocation sites. The definition itself is never counted as a call.
- Reason: Static evidence must describe actual branch coverage rather than token occurrences.

## D-319 - Initial cleanup and workspace validation remain separate failure branches

- Status: Accepted for TASK-3.9A
- Decision: Cleanup-object identity validation and publication-workspace identity validation each call the common failure funnel independently.
- Reason: This restores the exact 33-branch inventory while preserving the required validation order and exact NSError identity.

## D-320 - TASK-3.10 does not open until cleanup commit safety is accepted

- Status: Accepted
- Decision: Stale partial cleanup and discovery hardening remain locked until TASK-3.9A closes both the removal race and funnel-count blockers.
- Reason: Prior-process cleanup must build on a safe current-operation deletion primitive.
## D-321 - TASK-3.9A completes centralized current-operation cleanup

- Status: Accepted
- Decision: Commit `aa01f73b761682f3142c10b03ad5ff792331e68e` completes TASK-3.9A and TASK-3.9.
- Reason: Every destructive removal first atomically captures the current namespace entry under a private `RENAME_EXCL` quarantine name; the manager also contains 33 actual failure-funnel invocation sites.

## D-322 - TASK-3.10 separates read-only discovery from stale mutation

- Status: Accepted for TASK-3.10
- Decision: Published Backup discovery and stale reserved-workspace cleanup use separate classes and APIs.
- Reason: Listing across current and legacy roots requires no mutation authority, while stale cleanup requires the exact current per-bundle lock and canonical bundle-directory descriptor.

## D-323 - The per-bundle lock, not elapsed time, defines stale ownership

- Status: Accepted for TASK-3.10
- Decision: An exact reserved partial/quarantine direct child is stale when the exclusive per-bundle lock is held and cleanup runs before creation of the current workspace. No mtime, ctime, PID, boot-time or wall-clock threshold is used.
- Reason: Time metadata does not prove liveness. The accepted lock is the serialization authority for compliant Backup operations in one canonical bundle directory.

## D-324 - Stale cleanup mutates only the current canonical Backup root

- Status: Accepted for TASK-3.10
- Decision: TASK-3.10 may clean exact reserved entries only under the canonical bundle directory represented by the retained current `PXBackupBundleLock`.
- Reason: The legacy global root has no matching current-operation lock authority and therefore remains read-only.

## D-325 - Published directories are never stale-cleanup targets

- Status: Accepted
- Decision: Timestamp/UUID directories, legacy published directories and every nonreserved direct child are excluded from stale mutation regardless of manifest presence or apparent corruption.
- Reason: Reserved namespace ownership is the cleanup authorization boundary; publication validity is a discovery concern, not deletion authority.

## D-326 - Prior-process cleanup quarantine entries are recoverable stale roots

- Status: Accepted for TASK-3.10
- Decision: A top-level `.weaponx-cleanup-quarantine-<32 lowercase hex>` directory is an exact stale candidate under the current lock. Nested quarantine names inside an already-proven stale tree are processed as ordinary current entries.
- Reason: A process can die after atomic capture but before unlink/rmdir; the next serialized operation must be able to complete that cleanup safely.

## D-327 - Discovery is descriptor-relative and manifest validated

- Status: Accepted for TASK-3.10
- Decision: The public list method delegates to a read-only utility that opens roots, bundle directories, candidates and `manifest.plist` with no-follow descriptors and requires bounded stable reads plus `PXBackupManifestValidator` success.
- Reason: Path existence of `manifest.plist` alone does not prove a published Backup directory is safe or coherent.

## D-328 - V4 final names are bound to manifest timestamp and Backup ID

- Status: Accepted for TASK-3.10
- Decision: A v4 directory is discoverable only when its name equals exactly `<manifest.timestamp>-<manifest.backupID>`, with strict TASK-3.8 timestamp and canonical lowercase UUID forms.
- Reason: Atomic publication names and manifest identity must describe the same immutable Backup snapshot.

## D-329 - V2 and V3 discovery compatibility is retained

- Status: Accepted
- Decision: Validated v2/v3 Backups require exact bundle identity and a safe nonhidden directory but are not forced into the v4 UUID-suffixed name or v4 mode/publication fields.
- Reason: Discovery hardening must not silently strand legitimate legacy backups that predate atomic-directory-v1.

## D-330 - Physical aliases are returned once with current-root precedence

- Status: Accepted for TASK-3.10
- Decision: Discovery deduplicates candidate directories by device/inode across the current and legacy roots, keeping the first root supplied by the manager.
- Reason: Lexical aliases must not present one physical Backup twice, and current-profile storage has precedence over legacy compatibility storage.

## D-331 - Malformed candidates are skipped; systemic traversal failures fail discovery

- Status: Accepted for TASK-3.10
- Decision: Individual nonpublished candidates, malformed manifests, unsupported versions and identity mismatches are not returned. Invalid existing roots/bundle directories, traversal failures or global limit failures terminate the discovery call.
- Reason: One bad Backup should not hide other valid backups, but loss of root-level traversal authority makes the whole listing untrustworthy.

## D-332 - TASK-3.10 is the final Phase-3 gate

- Status: Accepted
- Decision: Phase 4 remains locked until TASK-3.10 has owner build confirmation and coordinator acceptance.
- Reason: Keychain redesign must begin only after Backup creation, publication, cleanup and discovery form a closed fail-closed lifecycle.
## D-333 - TASK-3.10 requires corrective stale-cleanup work

- Status: Accepted
- Decision: Commit `5e70a8ff5572dd343c8a16eb566277ab662e307f` is CHANGES_REQUESTED while its discovery utility and manager integration become protected foundations.
- Reason: Top-level nonreserved opaque names are rejected by the strict recursive name decoder, and failed first rollback is reported as `EntryChanged` or `LimitExceeded` instead of `RollbackFailed`.

## D-334 - Top-level stale classification uses raw bytes before string decoding

- Status: Accepted for TASK-3.10A
- Decision: Direct children of the retained bundle directory are classified against the two ASCII reserved prefixes using bounded raw `d_name` bytes before any NSString conversion.
- Reason: Nonreserved names are outside stale-cleanup mutation authority and must remain ignorable even when their bytes are not valid UTF-8.

## D-335 - Recursive deletion names remain strict lossless UTF-8

- Status: Accepted
- Decision: The raw top-level exception does not apply inside a proven stale workspace. Recursive names remain bounded, control-free and lossless UTF-8 before any deletion attempt.
- Reason: A deletion target requires an exact safe representation; weakening recursive validation would expand destructive authority.

## D-336 - Failed no-replace rollback has an explicit error state

- Status: Accepted for TASK-3.10A
- Decision: A rollback that cannot be proved returns `RollbackFailed` when no earlier destructive mutation occurred, or `CleanupIncomplete` after earlier mutation. A proved rollback retains the operation-specific `EntryChanged` or `LimitExceeded` error.
- Reason: `EntryChanged` describes a safely restored mismatch, not ambiguous preserved evidence after rollback failure.

## D-337 - Phase 3 remains open until TASK-3.10A acceptance

- Status: Accepted
- Decision: Phase 4 remains locked until the top-level raw-name and rollback-error blockers are corrected, built and accepted.
- Reason: Phase 3 is not closed while an unrelated opaque name can deny Backup or the stale-cleanup result misstates an unproved rollback.
## D-338 - TASK-3.10A completes Phase 3

- Status: Accepted
- Decision: Commit `02770e21bb1b7c7d691a8ac27c3f0fefabad135b` completes TASK-3.10A, TASK-3.10 and Phase 3.
- Reason: Top-level nonreserved opaque names are ignored before decoding, malformed reserved names remain fail-closed, recursive names remain strict and rollback failure now has explicit evidence-preserving error states.

## D-339 - Phase 4 begins with protocol before behavior changes

- Status: Accepted for TASK-4.1
- Decision: The first Keychain task adds a structured helper result envelope without changing Security operations, exit codes, restore pre-delete, per-item mutation, temporary workspace, access-group selection or manager behavior.
- Reason: Reliable later policy requires a stable factual result protocol before operational semantics are changed.

## D-340 - The helper result is an immutable bounded fact snapshot

- Status: Accepted for TASK-4.1
- Decision: `PXKeychainHelperResult` snapshots operation, completion, attempted/succeeded/failed/skipped counts, warning/error counts and optional fatal NSError domain/code into an exact immutable ten-key property-list graph.
- Reason: Mutable arrays and human logs are not a safe cross-process authority. A small fixed graph is independently parseable and testable.

## D-341 - Machine framing uses one prefixed base64 binary-plist line

- Status: Accepted for TASK-4.1
- Decision: Every non-help helper invocation emits exactly one stdout line beginning `PXKEYCHAIN_HELPER_RESULT_V1=` followed by a bounded base64 binary plist; construction failure emits the same prefix plus `INVALID`.
- Reason: The existing shell wrapper transparently passes stdout. Unique line framing allows future parsing without adding an untrusted result-file path before TASK-4.6.

## D-342 - Structured completion does not redefine process exit status

- Status: Accepted
- Decision: TASK-4.1 reports `failed`, `completed` or `partial` but preserves every existing numeric exit branch. TASK-4.2 alone defines reliable exit-code policy.
- Reason: Mixing protocol introduction with exit-policy changes would make compatibility and partial-result review ambiguous.

## D-343 - Machine results exclude Keychain identity and sensitive diagnostics

- Status: Accepted
- Decision: The result envelope contains no bundle ID, access group, class, service, account, label, secret data, entitlement, path, command line or human warning/error message.
- Reason: TASK-4.1 needs operational facts, not a second sensitive logging channel. Exact identity and requested/effective groups belong to TASK-4.4 and TASK-4.7.

## D-344 - Script, manager and bridge remain protocol consumers-in-waiting

- Status: Accepted
- Decision: `scripts/keychain_backup.sh` passes the new stdout line unchanged, while `AppDataBackupManager` and `WeaponXKeychainBridge` remain byte-identical and do not parse it in TASK-4.1.
- Reason: Manager partial-result integration belongs to TASK-4.8, and the bridge has a separate current response protocol.

## D-345 - Existing Keychain core result and algorithms remain protected in TASK-4.1

- Status: Accepted
- Decision: `KeychainBackupHelper.h/.m`, including mutable `PXKeychainBackupResult`, current backup/restore/wipe behavior and broad restore pre-wipe, remain byte-identical.
- Reason: The new object is a CLI-boundary envelope. Core mutation redesign is deliberately sequenced into TASK-4.3 through TASK-4.5.

## D-346 - TASK-4.1 is accepted as the Phase-4 protocol foundation

- Status: Accepted
- Decision: Commit `1a59e96258651aa9c6aa8d77a1e6debea67ab524` completes TASK-4.1 and opens TASK-4.2.
- Reason: The direct helper now emits one bounded immutable result line for every non-help terminal path while preserving Security operations, legacy exit decisions and protected callers.

## D-347 - Exit codes are a coarse projection of the structured result

- Status: Accepted for TASK-4.2
- Decision: Completed maps to `0`, Partial maps to `10`, and Failed maps to stable typed failure categories; the process exit must agree with the emitted TASK-4.1 completion.
- Reason: The machine result remains factual authority, while callers that cannot yet parse it need a stable fail-closed process status.

## D-348 - Direct-helper and wrapper-only exit ranges are disjoint

- Status: Accepted for TASK-4.2
- Decision: The direct helper may emit only `0,10,20,21,30,40,50`; wrapper setup failures use only `60...65`.
- Reason: A caller can distinguish operation outcomes from failures that occurred before the dynamically resigned helper executed.

## D-349 - Partial Keychain work is nonzero before manager integration

- Status: Accepted
- Decision: Backup, restore and wipe Partial results return `10`; current zero/nonzero callers therefore fail closed until TASK-4.8 consumes structured partial facts.
- Reason: Reporting partial work as process success repeats the ambiguity TASK-4.2 is intended to remove.

## D-350 - Protocol failure overrides business exit selection

- Status: Accepted
- Decision: Missing/invalid result construction, framing or result/exit consistency emits `PXKEYCHAIN_HELPER_RESULT_V1=INVALID` and returns `50`.
- Reason: A business status cannot be trusted when its machine evidence could not be emitted consistently.

## D-351 - Wrapper passes recognized helper codes and normalizes unknown statuses

- Status: Accepted
- Decision: `scripts/keychain_backup.sh` passes direct-helper codes unchanged; legacy, launch, signal-derived or future unknown child statuses normalize to `OperationFailed` (`40`) with a bounded human diagnostic.
- Reason: Raw shell statuses must not silently expand the public exit-code contract or collide with wrapper-only categories.

## D-352 - TASK-4.2 does not parse or extend the result payload

- Status: Accepted
- Decision: The script, manager, cleaner and bridge remain non-parsers; TASK-4.1 result schema, ten-key graph and privacy boundary remain byte-identical.
- Reason: Exit-code stabilization and structured partial-result consumption are separate review gates; parsing belongs to TASK-4.8.

## D-353 - Wrapper setup mapping does not authorize workspace redesign

- Status: Accepted
- Decision: TASK-4.2 assigns typed codes only to already-detected helper, target, entitlement, workspace, signing and dependency failures; it does not add path, ownership, symlink, race or temporary-directory checks.
- Reason: Secure workspace and path validation remain exclusively owned by TASK-4.6.

## D-354 - TASK-4.2 is accepted as the exit-policy foundation

- Status: Accepted
- Decision: Commit `5c6e70ac4ecd815727c50216c80176d1cf9f80f2` completes TASK-4.2 and opens TASK-4.3.
- Reason: Direct helper completion, typed fatal categories, protocol failure and wrapper setup failures now have stable non-overlapping process codes while the machine-result schema and callers remain unchanged.

## D-355 - Restore overwrite no longer authorizes group/class deletion

- Status: Accepted for TASK-4.3
- Decision: `overwrite == YES` must not cause any access-group/class-wide `SecItemDelete` before restore item processing.
- Reason: Backup metadata is not a complete inventory of target Keychain state, so broad deletion can destroy unrelated items that are absent from the backup.

## D-356 - Duplicate target items are preserved until safe upsert exists

- Status: Accepted for TASK-4.3
- Decision: Both overwrite modes preserve an existing duplicate item, increment the failed-item count and append one bounded human warning; no delete or update is attempted.
- Reason: TASK-4.4 has not yet defined exact per-class identity and TASK-4.5 has not yet implemented safe per-item upsert.

## D-357 - Explicit wipe remains the sole group/class-wide deletion authority

- Status: Accepted for TASK-4.3
- Decision: After TASK-4.3 the only `SecItemDelete` site remains inside `wipeKeychainForAccessGroups:itemClasses:error:`.
- Reason: Destructive group/class deletion is valid only for the explicit wipe operation, not as an implicit restore preparation step.

## D-358 - Overwrite request alone does not make an all-new restore partial

- Status: Accepted for TASK-4.3
- Decision: TASK-4.3 adds no blanket warning for `overwrite == YES`; a restore containing only new successfully added items may still complete with exit `0`.
- Reason: The safety boundary is preservation of existing duplicates, not rejection of the compatibility flag itself.

## D-359 - Help and API documentation must describe transitional overwrite semantics

- Status: Accepted for TASK-4.3
- Decision: Header, direct-helper help and wrapper help must state that overwrite is a replacement request while existing duplicates are preserved; they must not claim broad deletion or guaranteed replacement.
- Reason: Retaining a compatibility flag is acceptable only if public and operator-facing text does not promise behavior that has intentionally been removed.

## D-360 - TASK-4.3 is accepted as the non-destructive restore baseline

- Status: Accepted
- Decision: Commit `4c7000289186a4d7cb3772bc7c4b80b24ab4c3f1` completes TASK-4.3 and opens TASK-4.4.
- Reason: Restore no longer performs group/class-wide deletion, duplicate target items are preserved for both overwrite modes, and explicit wipe remains the sole core delete authority.

## D-361 - TASK-4.4 is a foundation-only identity task

- Status: Accepted for TASK-4.4
- Decision: TASK-4.4 adds an immutable class-specific identity object and exact match-query snapshot but does not call Security APIs or integrate with current restore.
- Reason: Identity correctness must be reviewed independently before it is allowed to drive lookup or mutation in TASK-4.5.

## D-362 - Keychain identity is class-specific and includes access group and synchronizable state

- Status: Accepted for TASK-4.4
- Decision: Every identity includes exact Security class, access group and synchronizable state plus one fixed class-specific tuple for generic password, internet password, certificate, key or identity.
- Reason: Class-only, account-only, label-only and group-only queries are wildcard deletion/update hazards rather than exact item identities.

## D-363 - Missing identity attributes fail closed without alternate fallback

- Status: Accepted for TASK-4.4
- Decision: The identity builder rejects incomplete or ambiguous tuples and may not substitute label, value data, persistent reference, public-key hash or another best-available subset.
- Reason: A fallback query can match more than the backed-up item and would make later upsert destructive or nondeterministic.

## D-364 - Absent synchronizable canonicalizes to false; malformed values are rejected

- Status: Accepted for TASK-4.4
- Decision: Missing `kSecAttrSynchronizable` becomes exact false, while a present value must be an exact CFBoolean. `kSecAttrSynchronizableAny` and numeric/string lookalikes are rejected.
- Reason: The identity query must distinguish synchronizable and non-synchronizable records without using wildcard semantics.

## D-365 - Identity snapshots exclude values and query-control keys

- Status: Accepted for TASK-4.4
- Decision: `matchQuery` contains only class, access group, synchronizable and the exact class tuple; it excludes value data, persistent references, return controls, match limits and authentication controls.
- Reason: Identity is a bounded match authority, not a secret container or an executable query configuration.

## D-366 - TASK-4.5 exclusively owns identity consumption and per-item upsert

- Status: Accepted
- Decision: Keychain core, CLI and wrapper remain byte-identical in TASK-4.4. TASK-4.5 may consume the identity object only after TASK-4.4 build confirmation and coordinator acceptance.
- Reason: This preserves a reviewable boundary between defining identity and using identity to mutate existing Keychain items.