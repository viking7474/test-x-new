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
