# TASK-0.5 Agent Report

## Metadata

```text
Task ID: TASK-0.5
Task title: AppDataCleaner CommandResult Wrapper
Task specification: docs/backup-restore-hardening/tasks/TASK-0.5-app-data-cleaner-command-result-wrapper.md
Agent: GPT-5.6 Thinking
Started at: 2026-07-13 (Asia/Ho_Chi_Minh)
Finished at: 2026-07-13 (Asia/Ho_Chi_Minh)
Suggested status: READY_FOR_REVIEW
Commit hash: chưa commit
```

## 1. Summary

Đã thay implementation tự quản lý process của `AppDataCleaner` bằng một private result-returning wrapper sử dụng bounded shell API đã được hoàn thiện trong TASK-0.2/TASK-0.3:

```objc
- (CommandResult *)runCommandWithPrivilegesResult:(NSString *)command
                                        timeoutSec:(NSTimeInterval)timeoutSec;
```

Wrapper mới:

- giữ nguyên command string và `/bin/sh -c` semantics;
- dùng total monotonic deadline và owned process-group cleanup của `CommandRunner`;
- capture stdout và stderr với cap riêng 1 MiB mỗi stream;
- trả nguyên `CommandResult` từ `CommandRunner`, không rewrite field;
- reject command nil/non-string/empty và timeout không finite bằng `runnerError = EINVAL` trước spawn;
- mặc định timeout `<= 0` thành 60 giây;
- không trim command, nên whitespace-only command tiếp tục được chuyển cho shell.

Ba compatibility selector `void` được giữ nguyên. Timed void wrapper chỉ delegate sang private result method, đọc `timedOut` để giữ diagnostic log với preview tối đa 240 ký tự, rồi không dùng result để thay đổi Clear success/failure hoặc caller control flow.

Implementation cũ gồm direct `posix_spawn`, post-spawn `setpgid`, `waitpid(..., WNOHANG)` loop, `usleep`, group `kill` và blocking final wait đã bị xóa khỏi timed wrapper.

Không migrate sang direct executable API. Không sửa caller, command string, timeout call-site value, batch filtering/composition, Clear/Backup/Restore/Keychain/UI hoặc TASK-1.1.

## 2. Working-Tree Baseline

Trước khi sửa code, đã ghi nhận:

```text
git status --short: clean, không có output
branch: newok
```

Checksum baseline:

```text
CommandRunner.h SHA-256:
63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF

CommandRunner.m SHA-256:
2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030
```

`git diff --stat -- CommandRunner.h CommandRunner.m` không có output tại baseline.

Sau implementation, hai checksum vẫn giống tuyệt đối:

```text
CommandRunner.h SHA-256:
63B88CF788FA8C981419F2C36F9375D1ED6E55190143C3C4E16B0972FE1D52BF

CommandRunner.m SHA-256:
2D5D68CD307AB150D85A28DB69DD5A6169C40F78B3EB6FE49468BDAAE2475030
```

Không stage, revert, format hoặc sửa hai file `CommandRunner`.

## 3. Files Changed

| File | Change | Why required |
|---|---|---|
| `AppDataCleaner.m` | Thêm private cap constant, private result wrapper và chuyển timed void wrapper sang delegation. Xóa custom spawn/poll/kill implementation khỏi wrapper cũ. | Triển khai TASK-0.5 trong phạm vi cho phép. |
| `docs/backup-restore-hardening/reports/TASK-0.5-REPORT.md` | Tạo agent report. | Artifact bắt buộc của task. |

Không sửa file code nào khác.

## 4. Contract Changes

### Exact private selector

```objc
- (CommandResult *)runCommandWithPrivilegesResult:(NSString *)command
                                        timeoutSec:(NSTimeInterval)timeoutSec;
```

Method chỉ được định nghĩa trong `AppDataCleaner.m`. `AppDataCleaner.h` không có declaration hoặc diff.

### Public/legacy selectors giữ nguyên

```objc
- (void)runCommandWithPrivileges:(NSString *)command;
- (void)runCommandWithPrivileges:(NSString *)command
                      timeoutSec:(int)timeoutSec;
- (void)runBatchedCommandsWithPrivileges:(NSArray<NSString *> *)commands
                              timeoutSec:(int)timeoutSec;
```

Không caller nào được đổi sang selector mới.

### Delegation graph

```text
runCommandWithPrivileges:
    → runCommandWithPrivileges:timeoutSec:60
        → runCommandWithPrivilegesResult:timeoutSec:
            → CommandRunner runAndCapture:timeoutSec:maxOutputBytes:

runBatchedCommandsWithPrivileges:timeoutSec:
    → giữ nguyên filter/order/composition
    → một command: runCommandWithPrivileges:timeoutSec:
    → nhiều command: join bằng "; " rồi runCommandWithPrivileges:timeoutSec:
```

### Business-flow compatibility

Result hiện có sẵn cho task sau nhưng chưa được dùng để thay đổi business result:

- timed void wrapper chỉ đọc `result.timedOut` để log;
- không branch theo `exitCode`, `spawnError`, `runnerError`, truncation hoặc captured output;
- không thay đổi success/failure của Clear;
- không return failure mới tới caller;
- không đổi thứ tự lệnh hoặc control flow caller.

## 5. Implementation Notes

### Fixed output policy

Private constant:

```objc
static const NSUInteger PXPrivilegedCommandMaxOutputBytes = 1024 * 1024;
```

Bounded call:

```objc
return [[CommandRunner shared] runAndCapture:command
                                  timeoutSec:effectiveTimeout
                              maxOutputBytes:PXPrivilegedCommandMaxOutputBytes];
```

Theo `CommandRunner` contract:

- stdout retain cap: 1 MiB;
- stderr retain cap: 1 MiB độc lập;
- sau cap vẫn drain/discard để tránh child block vì pipe đầy;
- `stdoutTruncated` và `stderrTruncated` giữ semantics hiện tại.

### Input validation

Private method reject trước `CommandRunner` call khi:

```text
command == nil
command runtime type không phải NSString
command.length == 0
timeoutSec là NaN hoặc ±Infinity
```

Failure result:

```objc
CommandResult *result = [[CommandResult alloc] init];
result.runnerError = EINVAL;
return result;
```

Không spawn trong các path trên.

Method không gọi:

```text
stringByTrimmingCharactersInSet:
trim
normalization command string
```

Do đó command chứa toàn whitespace nhưng có `length > 0` vẫn được truyền nguyên vẹn cho `/bin/sh -c`, giống wrapper cũ.

### Timeout normalization

```objc
NSTimeInterval effectiveTimeout = timeoutSec <= 0 ? 60.0 : timeoutSec;
```

Policy:

- finite `timeoutSec > 0`: giữ nguyên exact value;
- finite `timeoutSec <= 0`: dùng 60 giây;
- NaN hoặc ±Infinity: `EINVAL`, không spawn.

`isfinite` được lấy từ `<math.h>`.

### Shell semantics

Wrapper cố ý dùng bounded shell API, không dùng:

```objc
runExecutableAndCapture:arguments:timeoutSec:maxOutputBytes:
```

Các command hiện có tiếp tục hỗ trợ:

- pipeline;
- glob expansion;
- redirect;
- command separator;
- shell variable/loop;
- `|| true`.

Command được truyền trực tiếp, không trim, quote lại, join lại hoặc rewrite.

### Result/error mapping

Private result method trả trực tiếp `CommandResult` từ `CommandRunner` trên execution path. Không sửa:

```text
exitCode
stdoutString
stderrString
spawnError
runnerError
terminationSignal
exitedNormally
timedOut
duration
stdoutTruncated
stderrTruncated
```

Input validation nội bộ là exception duy nhất: tạo result mới và đặt `runnerError = EINVAL` vì chưa gọi runner/spawn.

Child non-zero exit, spawn error, timeout, signal termination và truncation tiếp tục có structured mapping của `CommandRunner`.

### Timeout diagnostic compatibility

Timed void wrapper:

1. gọi private result wrapper;
2. nếu `result.timedOut == YES`, tính effective timeout theo policy 60 giây;
3. dùng command gốc làm preview;
4. cắt preview tại tối đa 240 UTF-16 code units bằng `substringToIndex:240`;
5. phát một `NSLog` ngắn;
6. không thay caller control flow.

Log giữ wording tương thích:

```text
[AppDataCleaner] Command timed out after ... sec, killing: <preview>
```

Không log toàn stdout/stderr hoặc command dài không giới hạn.

### Old code removed from timed wrapper

Đã xóa khỏi `runCommandWithPrivileges:timeoutSec:`:

```text
posix_spawn
setpgid
manual WNOHANG wait loop
usleep(100 ms) polling
negative-PID SIGTERM
250 ms sleep
negative-PID SIGKILL
blocking final waitpid(..., 0)
custom process-group ownership logic
```

Timeout/group lifecycle hiện chỉ đến từ bounded `CommandRunner`:

```text
spawn-time POSIX_SPAWN_SETPGROUP
monotonic deadline
group SIGTERM
bounded drain grace
final group SIGKILL trước leader reap
bounded WNOHANG reap
final nonblocking drain/close
```

Không duplicate bounded execution engine trong `AppDataCleaner`.

## 6. Caller Audit

### Aggregate selector audit

Static source scan sau thay đổi:

| Selector | Declarations | Active calls | Comment-only occurrences |
|---|---:|---:|---:|
| `runCommandWithPrivileges:` gồm default/timed syntax | 2 | 182 | 7 |
| `runBatchedCommandsWithPrivileges:timeoutSec:` | 1 | 5 | 0 |
| `runCommandWithPrivilegesResult:timeoutSec:` | 1 | 1 | 0 |

182 active compatibility-wrapper calls được phân loại:

```text
170 one-argument calls
12 explicit timeout calls, bao gồm:
  - 9 business/helper call sites;
  - 2 calls từ batch wrapper;
  - 1 call từ default wrapper với timeout 60.
```

Không caller hunk nào xuất hiện trong diff.

### One-argument wrapper callers

| Caller | Calls |
|---|---:|
| `PXStopMailDaemonsBestEffort` | 2 |
| `hasDataToClear:` | 1 |
| `securelyWipeFile:` | 1 |
| `_wipeMobileSafariSystemStores` | 3 |
| `cleanDatabaseFile:bundleID:appName:companyName:` | 36 |
| `cleanIconStatePlist:` | 21 |
| `cleanLaunchServicesDatabase:` | 6 |
| `cleanRootHideVarData:` | 4 |
| `cleanSiriAnalyticsDatabase:` | 16 |
| `clearAppCache:` | 2 |
| `clearAppGroupContainers:withGroupUUIDs:isRootless:` | 1 |
| `clearAppIssuesForIOS15:` | 2 |
| `clearHealthData:` | 1 |
| `clearKeychainItemsForBundleID:` | 3 |
| `clearMediaData:` | 5 |
| `clearPluginKitData:` | 2 |
| `clearSafariData:` | 5 |
| `completeAppDataWipe:` | 1 |
| `deepCleanSystemSharedContainer:bundleID:appName:companyName:` | 34 |
| `fixPermissionsForPath:` | 2 |
| `performAggressiveCleanupFor:` | 8 |
| `performFullCleanup:` | 2 |
| `refreshSystemServices` | 2 |
| `universalKeychainWipeForBundleID:` | 2 |
| `wipeDirectoryContents:keepDirectoryStructure:` | 2 |
| `wipeWebKitDirectoryContents:` | 6 |

### Explicit-timeout wrapper callers

| Caller | Calls |
|---|---:|
| `clearICloudData:` | 1 |
| `completeAppDataWipe:` | 3 |
| `completelyWipeContainer:` | 1 |
| `fastWipeDirectoryContents:keepDirectoryStructure:timeoutSec:` | 1 |
| `finalSweepForContainer:` | 1 |
| `fixPermissionsAndRemovePath:` | 2 |
| `runBatchedCommandsWithPrivileges:timeoutSec:` | 2 |
| `runCommandWithPrivileges:` default compatibility wrapper | 1 |

### Batch-wrapper callers

| Caller | Calls |
|---|---:|
| `_scrubWebKitStateInSharedContainerBase:tag:` | 1 |
| `_wipeMobileSafariSystemStores` | 1 |
| `completeAppDataWipe:` | 3 |

Batch source remains unchanged:

- non-string entries vẫn bị bỏ qua;
- mỗi string vẫn được trim để lọc batch part như trước;
- empty part vẫn bị bỏ qua;
- one-item batch vẫn gọi timed wrapper trực tiếp;
- multi-item batch vẫn giữ order và join bằng exact delimiter `"; "`;
- timeout argument vẫn được chuyển nguyên giá trị từ caller.

Lưu ý: command trimming trong batch là pre-existing batch behavior và không phải trimming trong private result wrapper.

## 7. Remaining Process-Launch Inventory

TASK-0.5 không tuyên bố loại bỏ mọi direct process launch trong `AppDataCleaner.m`.

### Token search result after implementation

| Token/API | Remaining source occurrences relevant to execution |
|---|---:|
| `posix_spawn(` | 2 |
| `posix_spawnp(` | 0 |
| `setpgid(` | 0 |
| `waitpid(` | 2 |
| `NSTask` execution | 1, cộng private compatibility declaration |
| `system(` | 0 |
| `popen(` | 0 |
| direct `kill(` | 0 |
| direct `usleep(` | 0 |

Các delegated `PXProcessKiller` calls không chứa token `kill(` trong file này nhưng vẫn là process-control paths và được liệt kê riêng.

### Complete inventory

| Path | Purpose | Capture behavior | Timeout behavior | Output bound | Process-group behavior | Callers | Risk | Recommended follow-up |
|---|---|---|---|---|---|---|---|---|
| `runCommandWithPrivilegesResult:timeoutSec:` | Chạy privileged cleaner shell snippets, gồm rm/find/sqlite/pipeline/redirection/batch commands. | Capture stdout và stderr riêng qua `CommandRunner`; void business wrappers hiện bỏ qua captured data. | Total monotonic deadline; non-positive thành 60 giây; group TERM/KILL bounded cleanup. | 1 MiB riêng mỗi stream, tiếp tục drain/discard. | Spawn-time owned group, safe negative-PGID termination theo TASK-0.3. | 170 default calls, 12 timed calls gián tiếp/trực tiếp qua compatibility wrappers. | Caller chưa quan sát structured failure; destructive flow vẫn best-effort như trước. | TASK sau có thể chọn critical call sites để propagate/aggregate `CommandResult`, không làm trong TASK-0.5. |
| `_wipeSelectedKeychainForBundleID:error:` legacy `CommandRunner runAndCapture:` for `ldid` and keychain helper | Resign helper rồi chạy selective keychain wipe. | Capture stdout/stderr; caller đọc exit code/error text và lưu report. | Legacy unbounded capture, không default deadline. | Không cap theo legacy API. | Legacy capture không tạo process group mới. | 2 calls trong cùng method. | Helper hoặc `ldid` có thể treo/ghi output lớn; đây là Keychain behavior ngoài scope. | Task Keychain riêng nên cân nhắc bounded shell/direct argv migration sau contract review. |
| `findPathsMatchingPattern:` | Chạy exact `/usr/bin/find -L ... -path ...` để trả danh sách path. | Chỉ stdout qua pipe; stderr inherited; parent đọc toàn bộ đến EOF. | Không timeout; blocking read và blocking `waitpid`. | `NSMutableData` không giới hạn. | Spawn attrs `NULL`; không owned group. | 23 calls từ 11 caller methods: extension lookup/clear, encrypted-data cleanup, LaunchServices, RootHide, receipts, plugins, Spotlight, logs, thumbnails và iOS 15 cleanup. | Có thể block vô hạn; output có thể tăng không giới hạn; setup return values chưa được check đầy đủ. | Task riêng migrate sang bounded direct executable API với argv ownership và bounded capture. |
| `findPathsUnderRoot:directories:namePatterns:` | Chạy exact `/usr/bin/find` với dynamic argv để tìm file/directory theo nhiều name patterns. | Chỉ stdout qua pipe; stderr inherited; parent đọc toàn bộ đến EOF. | Không timeout; blocking read và blocking final `waitpid`. | `NSMutableData` không giới hạn. | Spawn attrs `NULL`; không owned group. | 5 calls từ `_internalClearEncryptedData:`. | Có thể block; output unbounded; argv dùng borrowed `UTF8String` pointers; arithmetic/setup checks chưa theo direct API contract. | Task riêng migrate sang `runExecutableAndCapture:arguments:timeoutSec:maxOutputBytes:` và parse bounded output. |
| `runCommandAndGetOutput:` | Chạy shell query/inspection commands và trả trimmed combined output. | `NSTask`; stdout và stderr cùng một `NSPipe`; `waitUntilExit` xảy ra trước read-to-EOF. | Không timeout; blocking wait. | Pipe/data không giới hạn. | Không có explicit owned group. | 9 calls: `PXWaitForProcessExit`, `cleanAppSpecificFilesInSharedContainer`, `directoryExistsAndHasAnyContent`, `hasSystemDatabaseReferencesForBundleID`. | Deadlock risk nếu combined pipe đầy trước child exit; unbounded wait/output; exception-based error string. | Task riêng chuyển sang bounded CommandRunner capture, sau khi review combined-output/trim/error compatibility. |
| Delegated `PXKillallByName`, `PXKillallTermThenKill`, `PXKillallTermThenKillMany` | Dừng app/daemon như maild, Mail, accountsd, Safari helpers, cfprefsd, nsurlsessiond. | Helper ngoài file redirect stdout/stderr sang `/dev/null`; không capture. | Mỗi `killall` spawn có polling timeout 10 giây; TERM/KILL helpers còn có grace sleep. | Output bị discard, memory bounded. | Helper spawn `killall` direct PID, không process group; timeout force-kill direct `killall` child. | 19 calls từ 7 callers: `PXKillAppProcessBestEffort`, `PXStopMailDaemonsBestEffort`, `PXStopSafariDaemonsBestEffort`, `completeAppDataWipe:`, `performAggressiveCleanupFor:`, `refreshSystemServices`, `_wipeMobileSafariSystemStores`. | Helper riêng còn manual spawn/wait/usleep/direct-PID timeout logic và borrowed UTF-8 argv; kill-by-name có broad targeting semantics. | Hardening riêng cho `common/PXProcessKiller`; không sửa trong TASK-0.5. |

### Direct-path caller details

`findPathsMatchingPattern:` callers:

```text
findExtensionContainers:                                      2
_internalClearEncryptedData:                                  6
cleanLaunchServicesDatabase:                                  2
cleanRootHideVarData:                                         1
clearAppIssuesForIOS15:                                       3
clearAppReceiptData:                                          3
clearExtensionContainers:forApp:                              1
clearPluginKitData:                                           2
clearSpotlightIndexes:                                        1
clearSystemLogs:                                              1
clearThumbnailCaches:                                         1
```

`findPathsUnderRoot:directories:namePatterns:` callers:

```text
_internalClearEncryptedData:                                  5
```

`runCommandAndGetOutput:` callers:

```text
PXWaitForProcessExit                                           1
directoryExistsAndHasAnyContent:                               2
hasSystemDatabaseReferencesForBundleID:                        5
cleanAppSpecificFilesInSharedContainer:...                     1
```

## 8. Acceptance Checklist

- [x] Only `AppDataCleaner.m` and the required report are changed.
- [x] `AppDataCleaner.h` is unchanged.
- [x] `CommandRunner.h/.m` are unchanged.
- [x] Private `runCommandWithPrivilegesResult:timeoutSec:` exists.
- [x] Private method returns `CommandResult`.
- [x] Private method uses bounded shell `CommandRunner` API.
- [x] Fixed output cap is 1 MiB per stream.
- [x] Invalid command returns EINVAL without spawn.
- [x] Non-positive timeout defaults to 60 seconds.
- [x] Non-finite timeout returns EINVAL.
- [x] Whitespace-only command compatibility is preserved.
- [x] Existing `void` method signatures remain unchanged.
- [x] Default wrapper still uses 60 seconds.
- [x] Timed void wrapper delegates to result wrapper.
- [x] Timeout logging remains concise and command preview is bounded.
- [x] Existing caller control flow is unchanged.
- [x] Batch helper behavior is unchanged.
- [x] No command strings are changed.
- [x] No timeout values at call sites are changed.
- [x] Old direct spawn/poll/kill implementation is removed from the timed wrapper.
- [x] No post-spawn `setpgid` remains in that wrapper.
- [x] No blocking final wait remains in that wrapper.
- [x] No direct executable migration is performed.
- [x] No Clear/Backup/Restore/Keychain/UI behavior is intentionally changed.
- [x] Remaining direct launch paths are fully inventoried in the report.
- [x] Full diff and diff stat are reviewed.
- [x] `git diff --check` passes.
- [x] `TASK-0.5-REPORT.md` is created.
- [x] GitHub Actions is recorded as PENDING.
- [x] Suggested status is READY_FOR_REVIEW.
- [x] Agent stops after TASK-0.5.

## 9. Verification Performed

### Source and scope checks

| Check | Result | Evidence/notes |
|---|---|---|
| Required reading | PASS | Đã đọc README, STATUS, DECISIONS, reviews TASK-0.1 đến TASK-0.4, TASK-0.4 report, report template, `CommandRunner.h/.m`, `AppDataCleaner.h/.m`. |
| Baseline status/checksum | PASS | Working tree ban đầu clean; SHA-256 của `CommandRunner.h/.m` đã ghi trước sửa. |
| Wrapper caller search | PASS | 170 one-argument calls, 12 explicit-timeout calls, 5 batch calls; grouped by caller trong report. |
| Caller diff | PASS | Không caller hunk nào thay đổi; diff chỉ import/constant và wrapper implementation. |
| `AppDataCleaner.h` diff | PASS | `git diff --exit-code -- AppDataCleaner.h` trả 0. |
| `CommandRunner.h/.m` diff | PASS | `git diff --exit-code -- CommandRunner.h CommandRunner.m` trả 0. |
| CommandRunner checksum after | PASS | Cả hai SHA-256 trùng baseline tuyệt đối. |
| Allowed code scope | PASS | Code diff chỉ có `AppDataCleaner.m`; report là artifact bắt buộc. |

### Wrapper checks

| Check | Result | Evidence/notes |
|---|---|---|
| Private result method count | PASS | Exact implementation occurrence = 1. |
| Header selector count | PASS | `AppDataCleaner.h` occurrence = 0. |
| Bounded shell call | PASS | Source có `runAndCapture:command timeoutSec:effectiveTimeout maxOutputBytes:PXPrivilegedCommandMaxOutputBytes`. |
| Fixed cap | PASS | Exact private constant `1024 * 1024`. |
| No direct API migration | PASS | Result wrapper occurrence of `runExecutableAndCapture:` = 0. |
| Invalid input mapping | PASS | New initialized result, `runnerError = EINVAL`, return trước runner call. |
| Non-finite timeout | PASS | Explicit `!isfinite(timeoutSec)`. |
| Non-positive timeout | PASS | Exact normalization `timeoutSec <= 0 ? 60.0 : timeoutSec`. |
| Whitespace-only compatibility | PASS | Result method có 0 trim calls; validation chỉ kiểm tra runtime type và raw length. |
| Result field rewriting | PASS | Execution path trả direct runner result; timed wrapper có 0 assignments vào result fields. |
| Timeout preview | PASS | Guard `length > 240`, `substringToIndex:240`. |
| Timed wrapper delegation | PASS | Exact call tới `runCommandWithPrivilegesResult:timeoutSec:`. |
| Forbidden old logic in timed wrapper | PASS | Counts cho `posix_spawn`, `setpgid`, `waitpid`, `kill`, `usleep` đều 0. |
| Duplicate engine | PASS | Không thêm capture/deadline/process-group loop; lifecycle đến từ `CommandRunner`. |
| Batch composition | PASS | Exact `componentsJoinedByString:@"; "` vẫn tồn tại và batch method không có diff. |

### Remaining-process search

| Search | Result |
|---|---|
| `posix_spawn` | Hai direct find helper paths còn lại, đã inventory. |
| `posix_spawnp` | Không có. |
| `setpgid` | Không còn trong `AppDataCleaner.m`. |
| `waitpid` | Hai blocking waits trong direct find helpers, đã inventory. |
| `NSTask` | Một execution helper và compatibility interface declaration, đã inventory. |
| `system(` | Không có. |
| `popen(` | Không có. |
| direct `kill(` | Không có. |
| direct `usleep` | Không có. |
| delegated `PXProcessKiller` | 19 calls từ 7 callers, đã inventory riêng. |

### Diff/build checks

| Check/command | Result | Evidence/notes |
|---|---|---|
| `git diff --check` | PASS | Exit code 0. |
| Full `git diff -- AppDataCleaner.m` review | PASS | Chỉ import `math.h`, private cap constant và wrapper replacement. |
| Diff stat review | PASS | `AppDataCleaner.m`: 23 insertions, 39 deletions. |
| Generated/binary files | PASS | Không có. |
| Local Objective-C/Theos build | NOT RUN | Workspace Windows thiếu `clang`, Apple/iOS SDK và `make`. GitHub Actions là build gate. |
| Runtime process scenarios | NOT RUN | Không có compiled iOS target/runtime an toàn trong workspace. |
| GitHub Actions | PENDING | Workflow expected: `.github/workflows/build-ios-arm.yml`. |

## 10. Verification Scenario Matrix

Không scenario runtime nào được tuyên bố PASS. Cột source/static mô tả contract đã review; runtime là `NOT RUN`.

| # | Scenario | Source/static review | Runtime | Evidence/expected result |
|---:|---|---|---|---|
| 1 | command `true` | PASS | NOT RUN | Direct runner result được trả; normal exit 0 map thành structured success. |
| 2 | command `false` | PASS | NOT RUN | Không rewrite result; normal non-zero child exit được giữ. |
| 3 | command writes stdout | PASS | NOT RUN | Bounded runner captures stdout; void caller flow không đổi. |
| 4 | command writes stderr | PASS | NOT RUN | Bounded runner captures stderr; void caller flow không đổi. |
| 5 | stdout exceeds 1 MiB | PASS | NOT RUN | Per-stream cap/truncation và continued drain từ CommandRunner. |
| 6 | stderr exceeds 1 MiB | PASS | NOT RUN | Independent stderr cap/truncation và continued drain. |
| 7 | command exceeds timeout | PASS | NOT RUN | `timedOut = YES`; bounded owned-group cleanup. |
| 8 | shell pipeline exceeds timeout | PASS | NOT RUN | Shell bounded path tạo process group và signal inherited group. |
| 9 | command nil | PASS | NOT RUN | Runtime type/length guard tạo EINVAL result trước runner call. |
| 10 | command empty | PASS | NOT RUN | Raw length 0 tạo EINVAL result, no spawn. |
| 11 | whitespace-only command | PASS | NOT RUN | Length > 0 và không trim; truyền nguyên command cho shell. |
| 12 | timeout 0 | PASS | NOT RUN | Normalized thành 60.0. |
| 13 | timeout negative | PASS | NOT RUN | Normalized thành 60.0. |
| 14 | timeout NaN/Inf via result method | PASS | NOT RUN | `!isfinite` tạo EINVAL trước spawn. |
| 15 | default void wrapper | PASS | NOT RUN | Source vẫn delegate exact timeout 60. |
| 16 | timed void wrapper success | PASS | NOT RUN | Delegate, không branch thay đổi flow khi không timeout. |
| 17 | timed void wrapper child failure | PASS | NOT RUN | Result bị bỏ qua sau optional timeout diagnostic; caller flow cũ giữ nguyên. |
| 18 | timed void wrapper timeout | PASS | NOT RUN | `timedOut` tạo một concise log, preview tối đa 240. |
| 19 | batch one command | PASS | NOT RUN | Existing one-part branch gọi timed wrapper với same part/timeout. |
| 20 | batch multiple commands | PASS | NOT RUN | Existing order và exact delimiter `; ` giữ nguyên. |
| 21 | concurrent calls from final sweep | PASS | NOT RUN | Mỗi invocation gọi independent `CommandRunner` execution state; không thêm shared mutable wrapper state. |
| 22 | existing command with `|| true` | PASS | NOT RUN | Bounded shell API giữ `/bin/sh -c` semantics. |

## 11. Diff Review

`git diff --stat -- AppDataCleaner.m`:

```text
 AppDataCleaner.m | 62 +++++++++++++++++++++-----------------------------------
 1 file changed, 23 insertions(+), 39 deletions(-)
```

Các phần diff:

1. thêm `#import <math.h>` cho `isfinite`;
2. thêm private cap constant 1 MiB;
3. thêm private result-returning wrapper;
4. thay custom timed void implementation bằng delegation + bounded timeout log.

Self-review:

- Có thay đổi ngoài task không? **Không.**
- Có caller edit không? **Không.**
- Có command string edit không? **Không.**
- Có timeout value edit tại call site không? **Không.**
- Có batch source edit không? **Không.**
- Có header/public API edit không? **Không.**
- Có `CommandRunner` edit không? **Không.**
- Có direct executable migration không? **Không.**
- Có Keychain/Backup/Restore/UI edit không? **Không.**
- Có TASK-1.1 implementation không? **Không.**
- Có format-only churn không? **Không.**
- Có generated/binary file không? **Không.**

## 12. Safety Notes

- Wrapper mới thay đổi process lifecycle của cùng shell command từ race-prone custom post-spawn group setup sang accepted bounded `CommandRunner` lifecycle.
- Command content, order và shell interpretation không đổi.
- Timeout giờ là total monotonic deadline, thay vì integer polling loop gần đúng.
- Group ownership được thiết lập atomically tại spawn time bởi `CommandRunner`; không còn post-spawn `setpgid` race trong wrapper.
- stdout/stderr giờ được drain và bounded, giảm deadlock/memory-growth risk cho wrapper này.
- Existing void APIs vẫn best-effort: result không làm Clear fail hoặc abort.
- Invalid command trước đây return void im lặng; private result method giờ biểu diễn failure bằng EINVAL, nhưng compatibility void wrapper vẫn không propagate nên caller flow không đổi.
- Không swallow runner result bên trong private method; compatibility layer chủ ý bỏ qua result theo D-020, ngoại trừ timeout diagnostic.

## 13. Not Changed

- Không sửa `AppDataCleaner.h`.
- Không sửa `CommandRunner.h`.
- Không sửa `CommandRunner.m`.
- Không sửa `AppDataBackupManager`.
- Không sửa `AppEntitlementsReader`.
- Không sửa UI.
- Không sửa keychain helper hoặc keychain flow.
- Không sửa Backup/Restore.
- Không sửa Clear success/failure propagation.
- Không sửa command strings.
- Không sửa command ordering.
- Không sửa timeout values tại caller.
- Không sửa batch filtering hoặc `; ` composition.
- Không sửa direct find helpers.
- Không sửa `NSTask` output helper.
- Không sửa delegated `PXProcessKiller` implementation/callers.
- Không dùng direct executable API.
- Không thêm async/cancellation/custom environment/cwd/stdin API.
- Không thực hiện TASK-1.1.

## 14. Remaining Risks

- Compatibility void wrappers chưa expose failure cho business flow; critical command propagation thuộc task sau.
- Hai direct `find` helpers vẫn có blocking wait, unbounded output và không có process group/deadline.
- `runCommandAndGetOutput:` vẫn có potential pipe deadlock do `waitUntilExit` trước read và không có timeout/output cap.
- Hai legacy keychain `runAndCapture:` calls vẫn unbounded; ngoài scope vì thay đổi Keychain bị cấm.
- `PXProcessKiller` vẫn có manual direct-PID spawn/wait/kill lifecycle ở module khác.
- Runtime behavior chưa được chạy trên thiết bị; static review không thay thế process-group/timeout/output tests.
- GitHub Actions chưa xác nhận compile với `<math.h>`/`isfinite` trên target SDK.

## 15. GitHub Actions Handoff

```text
Build requested: YES
Workflow expected: .github/workflows/build-ios-arm.yml
Build result: PENDING
Build URL/run ID: PENDING
```

Agent dừng tại TASK-0.5. Suggested status: `READY_FOR_REVIEW`.
