# Patch 4A.1 — Runtime reader core và BootTime RootHide

Ngày: 2026-10-24. Baseline: `85f8c9a`. Người dùng xác nhận build Patch 3 pass trước lượt triển khai này.
Trạng thái: source implemented, host gates PASS; native fixture/Logos build mới chưa chạy trên Windows. Đây là bước đầu của 4A, chưa hoàn tất migration hoặc transactional publication model.

## Phạm vi và lý do chia bước

Các accessor `PXRuntimeSnapshot*` hiện load plist riêng cho từng field. BootTime RootHide trước đây đọc bootTime, systemUptime và profileID độc lập, rồi ghi vào cache thứ hai; một publication xen giữa có thể tạo tuple từ nhiều file generations. Scope, identifier state và các consumer khác cũng còn những nhóm accessor riêng biệt.

4A.1 xây reader có native fixture độc lập và đưa BootTime qua reader đó trước khi migrate toàn bộ scope/identity/other hooks ở 4A.2. Giữ legacy accessors và privileged `PXLoadRuntimeSnapshot` ở behavior cũ để tránh âm thầm đổi tất cả consumers khi reader mới chưa có kết quả native. Không coi việc thêm API này là đã giải quyết mọi mixed-operation hoặc hot-path I/O trong repo.

## Reader API và ownership

`PXRuntimeReadSnapshot` giữ detached immutable property-list graph, global/security/tlink/profile settings, profileID, deviceIDs và profile artifacts. Caller capture một lần, giữ strong reference và truyền view vào helper liên quan. Getter không tự acquire view mới.

Deep freeze dùng Foundation binary property-list serialization/deserialization với immutable containers/leaves. Công việc này nằm trên worker queue, không ở hot capture. Dictionary field sai type trả dictionary rỗng theo convention hiện tại; không đổi tiêu chí identity validation/dependency gating của `PXIdentitySnapshot`.

Schema 1 không có publication identity vẫn đọc được: `hasPublicationIdentity=false`, epoch=nil, revision=0. Không tự tạo UUID hoặc dùng DeviceIDs.GenerationCounter làm publisher revision. Core cũng đọc schema 2 khi có UUID epoch và integer uint64 revision hợp lệ; canonicalize UUID casing, reject partial/malformed identity. Publisher hiện vẫn emit schema 1. Emit identity thật và ownership/acknowledgement thuộc 4B.

`readerGeneration` là sequence process-local cho reload/invalidation, tách khỏi revision publisher. Reader chỉ so revision khi cùng canonical epoch; epoch đổi được nhận mà không sắp thứ tự UUID. Metadata anti-rollback không giữ các enabled fields cũ để trả lại sau failure. Legacy schema 1 vẫn được chấp nhận và không có ordering guarantee này; policy kết thúc legacy acceptance phải đi cùng publisher migration ở 4B, không được coi reader hiện tại là một security/transaction boundary hoàn chỉnh.

## Refresh, notifications và hot path

- `PXRuntimeSnapshotReader.capture` giữ strong view dưới short lock rồi trả về, không chờ loader hoặc parse file. Chưa load/đang invalidation trả nil; load lỗi/absent/corrupt trả invalid view rỗng.
- Loader chạy trên serial dispatch queue. Requested generation + dirty flag coalesce notification burst; kết quả đang load bị invalidation làm stale sẽ không publish. Không dùng chung mutable candidate giữa worker và reader.
- Explicit invalidation xóa current view trước khi async reload, không tiếp tục phục vụ last-known-good enablement cho operation mới. View đã capture vẫn còn sống và nhất quán cho operation đang chạy.
- Fallback mất notification chạy on-demand khi có capture, tối đa một request sau mỗi 5 giây theo CLOCK_MONOTONIC; không thêm timer hoặc wakeup khi idle. Capture trong lúc worker đang load không tự restart worker vì TTL. Khi fallback fail, publish invalid view, không giữ last-good vô thời hạn.
- Old view được giữ bằng precise lifetime đến sau unlock để destruction graph không diễn ra dưới publication lock. Capture giữ errno của caller. Không gọi external loader/provider khi đang giữ publication lock.
- Wait API có deadline, từ chối chờ chính loader queue. Chỉ bootstrap/tests dùng wait; hot hook không dùng. Bootstrap RootHide chờ tối đa một giây, timeout để reader tiếp tục async và BootTime đi native tạm thời.

`PXPrepareRuntimeSnapshotReader` đăng ký Darwin runtimeSnapshotChanged/profileChanged/settings.changed/scopedAppsChanged một lần, trong constructor BootTime sau bootstrap/process/scope gates. Không thêm observer/I/O ở constructor bị từ chối. Observer/store này có process lifetime; worker block giữ store đến khi hoàn tất, production loader không capture store.

Source selection riêng cho captured reader giữ local mirror ưu tiên trên RootHide, global path fallback khi local file không tồn tại. Local file có nhưng corrupt không được bỏ qua để hồi sinh enablement từ một global source có thể cũ. Legacy accessors không đổi rule cũ trong bước này.

## BootTime migration

RootHide boot/uptime getters capture một view và truyền vào `PXCapturedBootValues`. Helper đọc cả bootTime và systemUptime từ view đó, giữ checks NSDate/uptime > 0 hiện tại. Không còn copy tuple RootHide vào cache BootTime riêng, không còn format profile cache key hoặc load plist khi đọc giá trị qua adapter này.

Pending/invalid/incomplete pair trả nil/0 để hook dùng native fallback thay vì dùng lại tuple cache cũ. Rootful giữ đường UptimeManager/cache cũ. Scope/identifier checks của BootTime vẫn thuộc legacy policy path trong bước này: consistency xuyên suốt policy + data là việc bắt buộc của 4A.2, chưa được chứng minh bởi việc capture cặp giá trị.

## Consumer manifest còn lại — bắt buộc cho 4A.2

| Consumer | Migration còn lại |
| --- | --- |
| `TLinkIOSTweak/PXScope.m` | Một captured input cho toàn bộ security flags + scope, cache gắn reader identity, invalidation/fail-closed và bootstrap parity |
| `common/PXIdentitySnapshot.m` | Capture identity/profile settings chung; đổi refresh notification khỏi inline disk build; giữ existing validation policy |
| `common/IdentifierManager.m` | Capture IDs/security/tlink/artifacts chung cho inferred enablement; loadSettings/settings+scope chung; giữ manager-app live writer bypass |
| `BatteryHooks.x` | Battery artifact + IDs, TTL/generation coherence và current toggle |
| `NetworkConnectionTypeHooks.x` | Security/pinned overrides/ISO, network/IDs fallback và carrier/network/IDs từ cùng view |
| `StorageHooks.x` | TLink setting + storage artifact chung với policy |
| `ThemeHooks.x` | Device IDs + artifact fallback, cache invalidation theo captured identity |
| `UserDefaultsHooks.x`, `PasteboardHooks.x` | IDs/artifact fallback, callback/recursive dictionary operation giữ cùng view |
| `Tweak.x` | Hai security-setting readers và policy/data boundaries liên quan |
| Các indirect identity/scope callers | Pass captured context qua logical operation; audit cache generation, không chỉ sửa tên accessor |

`WeaponXDaemon.m` đọc raw file lại sau publish để dựng debug status vẫn là vấn đề publisher/result identity của 4B; không migrate sang cached reader để che vấn đề đó. Rootful source capture/file reads, process-shared source transaction và writer manifest đầy đủ thuộc rollout tiếp theo/4C theo plan.

## Performance và giới hạn

Reader capture thêm một short lock + monotonic clock lookup; không parse plist, IPC hoặc file stat inline. Worker có thêm deep-freeze serialization trong memory, relative cost moderate cho snapshot lớn; chỉ diễn ra khi refresh. Bootstrap vẫn có một bounded wait và worker disk read. Chưa có device profiling để ghi mức tiết kiệm CPU/latency hoặc con số benchmark.

Snapshot/view fields không tự làm publisher capture nhiều file thành transaction. Stale mirror, multiple publishers, same-identity payload reuse và distribution failures cần 4B/4C. Không khẳng định toàn hệ thống đã không còn mixed generations hoặc hot-path disk I/O. Legacy readers vẫn có behavior cũ cho tới 4A.2.

## Verification

Native fixture `tests/PXRuntimeSnapshotReaderTests.m` compile production reader trực tiếp, không Python model. Fixtures dùng loader có semaphore barriers: deep immutable descendants, schema/metadata validation, queue identity/reentrant wait, cold nonblocking capture, preserved errno, 2000 hot captures không gọi loader, 100 invalidations coalesce/stale build discard, held-view consistency, missing/throwing source không last-good, same/different epoch revisions, lost-notification fallback và 2000 concurrent captures khi writer đổi publication.

CI chạy `scripts/test_runtime_snapshot_reader.py --native`, compile Foundation/CoreFoundation rồi chạy fixture trong ba process. Host gate kiểm tra wiring và nói rõ không chứng minh native runtime. Explicit daemon source list đã thêm reader; app/tweak dùng wildcard common như trước.

Host gates đã chạy: captured-reader contracts; RootHide build contracts; P3 thread safety 80/80; bootstrap topology 27 constructors; Phase-10 release hardening; native OS runtime safety; Phase-B regression; Security UI; WebKit zero interference; bootstrap policy; Phase-11 cleanup; iFake parity; Domain task và location delegate source contracts; diff whitespace. Tất cả PASS.

Backup/restore audit PASS 2536/2536; tăng 12 per-file checks từ ba header/source/fixture mới, không đổi semantic guards. Native fixture, Logos/Objective-C rootful/RootHide và device tests của thay đổi mới chưa xác minh tại host Windows.

Gate tiếp theo: native reader fixture + build mới, sau đó 4A.2 consumer migration và semantic operation fixtures. 4A chỉ được đánh dấu hoàn tất khi toàn bộ consumer list/operation boundaries và runtime exit criteria đạt, trước khi chốt 4B/4C là transactional publication hoàn chỉnh.
