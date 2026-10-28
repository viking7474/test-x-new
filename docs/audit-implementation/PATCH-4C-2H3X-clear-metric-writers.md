# Patch 4C.2H3X — clear metric counter pair

Người dùng xác nhận build H3W pass. H3X tiếp tục Patch 4 trên source chung
rootful/RootHide; không đổi bootstrap hoặc destructive clear policy. Indicator
position writer được đọc để đối chiếu nhưng chưa sửa trong patch này.

## Vấn đề và thay đổi

Central clear completion cũ đọc `clearAttemptCount` và
`clearFirstAttemptSuccessCount` qua NSUserDefaults rồi setInteger hai keys riêng.
Concurrent clear completions có thể cùng đọc một baseline và mất increment. Hai
fields không có cùng source commit boundary và vẫn chia sẻ physical security plist
với runtime settings; một mirror/flush khác có thể gặp intermediate state.

`PXRecordClearAttempt` đọc/validate hai counters dưới shared source gate, tăng
attempt một lần và tăng successes khi caller truyền true, rồi stage cả cặp trong
một candidate. Outputs chỉ thay sau primary commit. Giữ unrelated security fields,
missing count = 0 và điều kiện caller cũ `success && timeoutFallbackCount == 0`.

Chấp nhận nonnegative NSNumber integer types (kể cả legacy BOOL 0/1) và complete
decimal strings, optional whitespace/leading plus. Fractional, negative, malformed,
oversized hoặc successes > attempts bị từ chối, không reset source. Next value phải
fit NSInteger để giữ legacy readers; exhausted count không wrap. Parser kiểm tra
full UTF-8 token để embedded NUL không bị hiểu thành prefix hợp lệ. Không tự repair
legacy records lỗi hoặc thay bằng baseline mới.

Private mutation callback bổ sung NSError output để validation có thể fail trước
staging, không dùng exception làm normal validation flow. Existing packet/nonce
writers giữ ba mirror suites. Metrics giữ canonical-only legacy mirror scope
`com.weaponx.securitySettings`, sau source unlock; không mở rộng sang hai suite
khác và không thêm explicit runtime settings notification.

## Caller behavior

Clear completion vẫn gọi accounting một lần sau guard completionCalled và giữ
nguyên eligibility. Metrics error chỉ log, không đổi `success`, `error`, cleanup
hoặc completion của clear operation. Log có `counter_persisted=1` khi source commit
thành công. Nếu lưu metrics lỗi, log failure và `counter_persisted=0`, bỏ aggregate
percentage không sẵn sàng thay vì báo số 0 như một tỷ lệ đã commit. Operational
metrics/per-run first-attempt outcome vẫn log; valid percentage format giữ một chữ
số thập phân.

Không thêm retry, queue, timer hoặc IPC. Accounting chạy trên completion queue hiện
hành. Standard-defaults diagnostics/DataUsage khác của AppDataCleaner không phải
hai security-domain counters này và không được coi là đã enroll.

## Kiểm chứng

Mở rộng actual security native fixture hiện có, chạy cả rootful và RootHide-defined
lanes qua CI. Fixture include nguyên store implementation, actual source engine,
temporary file I/O/rollback; defaults backend vẫn controlled để không ghi preferences
thật. Không cần Foundation shim hoặc dependency project mới cho API.

Cases: initial missing counters, true/false eligibility, one commit/two legacy
mirror key updates, canonical-only mirror scope, unrelated values, legacy decimal/
numeric BOOL inputs, source fault/raw-byte and output preservation, malformed
values, embedded NUL, inconsistent pair, signed maximum boundary, overflow, corrupt
root preservation và 24 concurrent cooperating calls có unique attempt receipts,
24 attempts/12 first successes. Existing normal packet/nonce/Canvas/UI cases tiếp
tục kiểm tra ba-suite mirror contract không đổi.

AppDataCleaner caller được source gate kiểm tra đúng một API call, eligibility,
failure log và percentage chỉ có sau committed counters; không chạy một destructive
clear trong host fixture. Source contracts, macro arity, fragment extraction và diff
checks chạy tại Windows. Native compile/Theos/package/device H3X chờ macOS CI;
không suy ra full clear/device acceptance từ static checks.

Local regression inventory: 62/63 Python suites và 4/4 Node suites pass. Suite
bridge migration shell còn Permission denied `/c/Users/ADMIN`. Source hardening,
RootHide build contracts và package metadata checks pass; 9 existing production
security fragments vẫn generate được, macro/diff checks pass. Không ghi nhận full
release gate hoặc native runtime pass tại Windows.

## Performance và boundaries

Per completion có source journal/commit và legacy mirror thay cho hai lazy defaults
setters. Expected I/O cost moderate; CPU parsing hai fields/suffix log thấp trên
cold completion, chưa benchmark latency. Không cache counts ngoài gate để giảm I/O
vì sẽ đưa lại lost-update race. Burst clear workload và callback latency cần đo;
source contention/deadline vẫn có thể ảnh hưởng completion queue.

Native concurrency fixture chứng minh cooperating source writes trong một host
process với controlled mirrors, không chứng minh toàn bộ cross-process/cfprefsd
authority. Physical canonical domain và post-commit mirror ordering vẫn partial:
một stale external defaults flush có thể rewrite file sau commit. Không claim global
lost-update freedom hoặc power-loss durability. Indicator position, remaining
preferences/metadata writers và rootful reader rollout tiếp tục theo plan.
Manifest rollout `4C.2H3X-partial`; toàn Patch 4 chưa hoàn tất.
