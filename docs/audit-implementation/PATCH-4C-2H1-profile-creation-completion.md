# Patch 4C.2H1 — fixed-target create generation và completion

Người dùng đã xác nhận build sau 4C.2G/scalar-fixture fix pass. H1 xử lý worker target, completion và selection pair; **không** hoàn tất profile lifecycle transaction. Native/build mới chờ macOS CI.

## Các lỗi được sửa

**High — createProfile:completion:** flow cũ dispatch generation rồi lưu metadata/call success ngay, nên caller có thể switch hoặc regenerate trong lúc worker còn chạy. Worker gọi API chọn active profile một lần nữa, do đó carrier/IP ghi vào profile A nhưng identifier batch có thể ghi vào B. Một số giá trị được lấy qua NSInvocation với unsafe-unretained return storage; có nhiều lượt ghi carrier/network/IDs ngoài source gate và Wi-Fi bị generate lại trước batch.

Flow mới capture targetID và network options trước dispatch. Worker chỉ prepare carrier/IP, rồi gọi `regenerateAllEnabledIdentifiersForProfileID:networkArtifacts:error:`. API kiểm tra explicit directory, migrate đúng target, rồi gọi lại batch core của G; không lấy active profile làm write target. Default current-target API vẫn giữ một lookup và cùng core. Native group fixture có backend migration riêng; migration production được kiểm chứng bởi suite identifier-writers hiện có.

Carrier + IPv4/IPv6 được stage cùng identifier/artifact/settings/scope batch, có dependency checks cho field thay thế và giữ existing IPv6 theo contract NetworkManager trước đó. Không còn direct plist writes hay saving NetworkManager callback trong creation worker. Giữ policy: carrier tạo ở Auto/Cellular kể cả Network Data Spoof off; IPv4 chỉ tạo khi bật spoof và mode 0/1/2; không có current IPv4 thì bỏ qua pair, không fallback sang real IP. Schema migration vẫn là operation riêng trước generation boundary, như G.

Main block chờ worker xong mới lưu metadata. `success = generated && saved`; error hoặc exception không phát profile-success notification/canvas reset. Completion chạy một lần trên main sau bước lưu metadata, trả generation error trước nếu cả hai bước fail. Canvas/profile observer exception hậu commit được log, không báo giả rollback hoặc bỏ mất completion. Caller completion exception không bị bắt rồi gọi lại.

**High — selection persistence:** helper mới stage canonical + legacy selection record trong một source transaction. update/switch không cập nhật CurrentProfileID mirror hoặc current-profile pointer khi pair commit thất bại. Compatibility defaults chạy sau commit, ngoài source gate. Hai selection files không còn lệch nhau do write failure trong các entry point này. Legacy selection nay theo canonical ở các lần update này; startup/profile-zero writers trực tiếp vẫn pending.

**High — archive fallback:** flow cũ dùng chung `temp_profiles.plist`, unlink archive hiện có rồi move file tạm. Move/permission error sau unlink có thể làm mất archive tốt. Giờ dùng NSDataWritingAtomic tại destination, trả lỗi và giữ destination khi fail; không unlink-before-replace hoặc fallback dùng temp name chung. Exception khi encode/write trở thành metadata error, callback ở ngoài catch.

**Medium — overlap/threading:** create/update/delete/switch marshal entry sang main, từ chối với busy error khi creation đang pending. Guard đặt trước termination/callback adapters và giữ tới metadata save callback; failure selection cũng release guard. Đây là single-manager guard cho entry points, không phải process-shared directory lock hoặc bảo vệ mọi getter/setter/convenience API.

**Medium — ID allocation và secure archive:** ID scan trước chỉ xét directories khi archive không có IDs, nên directory-only IDs từ failed operations có thể bị reuse. Nay luôn xét filesystem, reject existing new-profile destination và kiểm tra identity directory/metadata write trước khi dispatch. Root unarchiver cho phép bounded class set của Profile/property-list settings; kiểm tra root array và từng Profile/ID trước load. Settings decode giữ nested property-list types và fallback dictionary nếu sai shape. Không nới sang arbitrary NSObject classes. Đây không phải crash-recoverable ID/directory reservation; generator lỗi vẫn fail closed nếu candidate đã tồn tại.

## Giới hạn phải giữ rõ

H1 **vẫn giữ thứ tự legacy: chọn profile mới trước generation**. Generation fail có thể để selection trỏ vào profile vừa tạo chưa đủ artifacts; metadata vẫn được lưu để phản ánh profile đã tạo, nhưng completion trả NO và không phát success effects. Switch đã commit selection rồi metadata save fail cũng không tự rollback selection. Caller không được hiểu failure là mọi file/cache/app termination đã rollback. Directory files, app-version randomization, archive, shared defaults và canvas preference không nằm chung source transaction.

Do đó bước tiếp theo là prepare profile chưa active → commit generation/selection theo lifecycle context → publish memory/cache/completion, kèm conditional recovery và directory ownership. Không thêm rollback đọc-lại-active rồi ghi đè vì có thể clobber selection mới của producer khác. Startup/default/profile-zero/delete, external writers và cfprefsd authority vẫn pending; manifest giữ profile-lifecycle pending, profile-create-completion partial, selection coverage partial.

Identifier flags/scope capture một lần khi batch core chạy; network options capture trước dispatch. Không claim hai preferences authorities đã có một atomic snapshot. Mutable singleton settings/cache ordering và IdentifierManager compatibility callbacks trên worker vẫn theo boundary G; chỉ profile completion/metadata/canvas/profile notification được marshal main ở H1.

## Performance

Không thêm hook/timer/polling hay runtime network request. Bỏ reflection/NSInvocation ở create worker, duplicate Wi-Fi generation và nhiều lượt network save; interface enumeration/provider work ở ngoài source lock. Completion có thêm main hop để thực hiện metadata/UI effects đúng queue. Expected impact low–moderate cho cold create; archive/app-version I/O trên main vẫn có, chưa benchmark latency.

## Kiểm chứng

- Source gate mới `test_profile_creation_flow.py`, đã nối CI/release-hardening. Native fixture extract production create/switch/update/delete dispatch guards, completion flow, archive save/ID generation, Profile secure-coding implementation, network preparation và selection helpers.
- Fake IdentifierManager là backend generation cho orchestration tests; real SourceStore/selection helper chạy ở temp directory, real archive encode/decode. Termination, version randomization, defaults mirror và network interface/carrier providers dùng spies/backends; không kill app hoặc phát production IPC.
- Existing group fixture extract explicit-target wrapper + real generation core, real preparation/staging/journal; kiểm tra network joins single commit, target drift, rollback, malformed target/payload và preserve IPv6.
- Native matrix rootful + RootHide, ba process mỗi variant; Windows không chạy Foundation/xcrun/Theos. Source gate pass không chứng minh native queue/callback hoặc package runtime.
- Host: **34/34 source gates**, **3/3 Node regressions**, backup/restore audit **2648/2648**, exact production fragment extraction cho profile/group/artifact fixtures và `git diff --check` pass. Build/native H1 chờ macOS CI; chưa có runtime queue/disk-fault evidence từ Windows.
