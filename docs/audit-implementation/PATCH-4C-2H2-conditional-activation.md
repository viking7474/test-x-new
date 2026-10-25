# Patch 4C.2H2 — activation sau prepare và conditional recovery

Người dùng xác nhận build H1 pass. H2 thay thứ tự create/switch, thêm activation proof và sửa startup/UI writers có thể đưa selection về state cũ. Build/native H2 vẫn chờ macOS CI; không coi toàn bộ directory lifecycle hoặc Patch 4 hoàn tất.

## Flow mới

Create capture selection pair có presence và revision, giữ target ID/network options, rồi generate vào profile **chưa active**. API `commitRuntimeGenerationForProfileID:networkArtifacts:error:` commit artifacts và trả `PXCommittedRuntimeGeneration`; không publish cache/notification hoặc ghi global settings/scope. Receipt chứa payload, model packet, target và proof của các source records, kể cả absence; tất cả được detach trước physical commit. Lỗi xây receipt không thể xảy ra sau commit rồi báo giả rằng generation chưa ghi.

Trên main, kiểm tra lại target, selection và proof, thêm ready profile vào registry rồi lưu archive. Metadata fail gỡ đúng object vừa thêm khỏi memory, giữ selection/global settings/defaults/cache trước đó. Files của target chưa active vẫn tồn tại; không recursive delete hoặc reuse ID khi chưa có ownership/recovery contract.

Sau metadata thành công, preflight trước termination adapter; nhả gate rồi mới gọi adapter. Final source transaction kiểm tra proof và compare-and-swap selection một lần nữa, commit deferred settings/scope + canonical/legacy selection cùng journal. Có writer mới trong lúc prepare/archive/termination thì trả conflict; không dùng unconditional rollback ghi lại selection cũ. Nếu conflict sau khi archive đã lưu, ready profile có thể ở registry nhưng chưa active; completion trả NO.

Sau activation commit: cập nhật current-profile memory → defaults mirror → compatibility caches → canvas/profile notifications/completion. Compatibility publication kiểm tra lại artifact proof, bỏ settings/scope khỏi lần so sánh này vì chính activation vừa advance chúng. Candidate stale thì bỏ cache adoption và wake snapshot readers cho state mới nhất. Post-commit callback failure không đổi success thành false rollback. Đây không phải total ordering giữa cache publishers của nhiều process.

Switch cũng lưu metadata trước activation. Nó dùng target ID cố định, yêu cầu registered profile/directory, capture selection basis và recheck sau termination. Metadata failure không đổi selection; source failure không đổi current-profile pointer/defaults. Same-profile refresh giữ policy không terminate/randomize hoặc phát profile-changed event. LastUsed/registration đã lưu trước một activation conflict không được rollback mù qua archive của producer khác.

## Revision và startup

Các cooperating selection writes có `SelectionRevision` UUID, nên A→B→A không trở thành match chỉ vì ProfileId/timestamp giống nhau. So sánh full record + existence cho cả canonical/legacy; không chỉ so ID hoặc mtime. Producer ngoài contract vẫn được ghi rõ là partial.

Startup không ghi selection về 0 chỉ vì thiếu directory 0. Bootstrap seed 0 chỉ khi cần, giữ device_ids hiện có; CAS tạo/repair selection từ canonical hoặc legacy alias. Record malformed/recovery fail được giữ nguyên, không đoán profile khác. Archive load ưu tiên committed selection thay cho CurrentProfileID trong defaults: crash sau activation nhưng trước mirror sẽ restore đúng profile. Mirror được queue sang main và kiểm tra lại selection trước khi ghi, tránh mirror cũ đè activation mới.

Archive corrupt không bị ghi đè bằng một default archive. Selection và registry có failure guards riêng; một label read hợp lệ không được xóa guard của archive lỗi. Getter currentProfile không viết fallback selection và có thể trả nil khi restore unavailable; mutation bị từ chối cho tới một lần reload hợp lệ. Call sites UI/common đã kiểm tra dùng nil-safe paths; header thể hiện nullable.

## Transitive UI writers

Rà lại ProfileManagerViewController tìm **bốn** read/render/load paths gọi update selection: view appearance, load list, label và cell mismatch repair. Chúng chuyển sang refresh chỉ đọc committed selection để adopt memory. Hai explicit name/description edits giữ helper metadata, nhưng helper chỉ update đúng current ID trong source transaction; stale object không được chọn lại một profile khác. Public compatibility/raw-selection APIs và private legacy methods chưa có in-repository production caller vẫn là phạm vi cần inventory/reconciliation tiếp; không claim mọi external selector invocation đã join CAS.

## Performance và lifetime

Không thêm hook, timer, polling hoặc queue thường trực. Providers/entropy/interface enumeration và termination chạy ngoài source gate. Receipt detach/proof comparison có thêm serialization, allocation và file reads trong cold create/activation; expected cost moderate, chưa benchmark. Một detach của receipt diễn ra khi staging, trước physical writes, để giữ correctness; không gọi nó là zero-overhead hoặc hoàn toàn ngoài lock.

Không giữ source lock qua callback/dispatch/defaults/cache publication. UI canonical reads load legacy lazily để không tăng từ một file read thành hai trong common case. Main-thread archive/version I/O vẫn có. Receipt không giữ transaction hay completion, failed receipt không publish; pending asynchronous creation giữ self tới completion theo lifetime hiện tại.

## Giới hạn còn lại

Directory creation/archive/artifact generation/activation không phải một filesystem transaction duy nhất. Crash trước activation có thể để inactive directories hoặc ready registry entries; ID scan tránh reuse, nhưng cleanup/reconciliation cần ownership journal ở bước tiếp theo. Delete, private legacy initialization helpers, metadata edits ngoài main actor, defaults/security authority, cross-process cache ordering và rootful live readers vẫn partial/pending. Không có fsync/power-loss durability claim.

Termination/version/canvas side effects không rollback được. Writer có thể đổi selection trong termination adapter: final CAS bảo vệ files nhưng app có thể đã bị terminate. Artifact/global proof so sánh whole records có thể reject cả disjoint edits sau generation; đây là policy bảo thủ cho activation, không tự regenerate/retry hoặc merge candidate chưa được review.

## Kiểm chứng

Native profile fixture extract exact production create/finish/switch/activation/bootstrap/load/read-only UI-refresh methods và Profile secure coding. Generation provider là fixture backend dùng real staging/proof/receipt/source journal; metadata archive thật trong temp directory; termination/defaults/network/cache callbacks dùng spies. Group fixture extract real IdentifierManager deferred API/core/publisher, real preparation/staging/proof, và kiểm tra global settings/scope được defer tới activation.

Cases gồm pending create không đổi active/global/cache/app state; generation/metadata failure; selection drift và ABA; changes sau generation; writer trong termination adapter; rollback cả selection/settings/scope; immutable receipt; stale metadata guard; read-only UI refresh; restart với defaults cũ; stale deferred mirror; corrupt archive không đoán selection; preserve profile-zero identity và legacy alias repair. Fixture extraction/source gates không chứng minh native execution.

Host: **34/34 source gates**, **3/3 Node regressions**, backup/restore audit **2648/2648**, production fragment extraction cho profile/group/artifact fixtures và `git diff --check` pass. Windows không có Foundation/xcrun/Theos; chưa báo native/build H2 pass. macOS CI chạy rootful + RootHide, ba process mỗi variant.

## CI follow-up — CHECK macro compile error

Log macOS dừng ở PXProfileCreationFlowTests.m:314: macro CHECK có quá nhiều arguments. Dictionary literal hai keys nằm trong block truyền trực tiếp vào CHECK; C preprocessor chỉ dùng parentheses để nhóm macro arguments, không dùng Objective-C brackets/braces, nên dấu phẩy dictionary bị hiểu là separator. Nullability/unused-parameter lines trong log là warnings, không phải lỗi chặn compile này.

Tách performWrite thành biến BOOL trước CHECK, giữ nguyên transaction, short-circuit của bootstrap assertion và production behavior. Source gate thêm kiểm tra lexical arity cho CHECK trong profile/group fixtures, có broken/protected-literal regression cases; không suppress compiler warnings hoặc nới assertion runtime.

Host follow-up: checker tái hiện fixture HEAD tại dòng 310 là ba arguments, bản sửa pass; **7/7 related source gates**, exact profile production fragment extraction và git diff --check pass. Native macOS chưa chạy tại Windows; cần CI compile/runtime lại.

## Trạng thái sau CI follow-up

Người dùng đã xác nhận build pass sau macro fix. Tiếp tục directory ownership theo [H3A](PATCH-4C-2H3A-directory-reservation.md); xác nhận build không thay thế device/runtime matrix của toàn Patch 4.
