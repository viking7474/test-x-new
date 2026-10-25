# Patch 4C.2H3A — exclusive create-directory reservation

Người dùng xác nhận build H2 và CI macro fix đã pass. H3A là bước đầu của directory ownership, chưa hoàn tất directory recovery/delete hoặc Patch 4. Native/build của H3A cần macOS CI chạy lại.

## Vấn đề và thay đổi

`createProfile:completion:` trước đây dùng `fileExistsAtPath:` rồi `createDirectoryIfNeeded:`. Hai instance có thể cùng thấy ID chưa tồn tại; instance thua vẫn dùng directory của instance thắng vì create-if-needed coi existing directory là thành công. `creationInProgress` chỉ bảo vệ một instance, không bảo vệ nhiều instance/process. Đây là cửa sổ race có trong source; chưa có báo cáo reproducer trên thiết bị.

`PXProfileCreationReservation` dùng `mkdirat` để reserve một child mới: existing directory/file/symlink đều là conflict, không adopt hoặc overwrite. Root theo configured path để giữ jailbreak aliases; child profile/identity mở tương đối qua descriptor với `O_NOFOLLOW`. Initial identifiers.plist và `.creation-owner.plist` dùng descriptor-relative exclusive creation. Permissions giữ 0755 cho directories và 0644 cho records. Directory timestamps theo filesystem creation; profile createdAt/lastUsed và nội dung identifiers giữ flow cũ.

Reservation giữ bốn descriptors (root/profile/identity/marker), so device/inode của held descriptors với namespace hiện hành, kiểm tra marker regular/single-link/size và exact bytes bằng pread. Operation UUID + ID + timestamp + state=reserved là evidence của lượt create, **không phải ready/activation proof hoặc quyền xóa**. Không thay readiness bằng sự tồn tại của marker. Initial directory failures vẫn trả WeaponXProfileError code 13 (invalid/conflict) hoặc 11 (initialization), kèm underlying reservation error.

Create giữ reservation trong worker và manager; kiểm tra trước network preparation, trước generation, trước metadata/termination và trong activation source transaction. Directory/identity/marker đã thay tại điểm kiểm tra thì không register/activate candidate hoặc publish success. Recheck sau termination vẫn cần thiết. Marker/file bytes được giữ từ lần serialize thực tế, không dựa vào dictionary serialization order của lần gọi thứ hai.

Các nhánh generation failure, metadata failure và activation completion nhả reservation trước completion; descriptors được đóng trong dealloc. Không retain transaction/completion, không thêm hook/timer/polling/queue. Failed hoặc exited creator để lại directory; lượt sau không reuse hoặc tự xóa nó.

## Giới hạn và bước tiếp theo

Đây là exclusive reservation + detection tại checkpoints, không phải filesystem isolation xuyên suốt lifecycle. Legacy delete/rename không tham gia directory lock và vẫn có thể đổi path sau check hoặc trong path-based generation/physical source commit. Holding descriptors không ngăn unlink/rename. Chưa claim chặn mọi directory substitution hoặc rollback các write vào path đã đổi. Startup seed-zero và legacy helpers chưa chuyển sang reservation này.

Archive vẫn có authority riêng: các create khác ID có thể tranh registry; directory/artifacts/archive/selection chưa là một atomic transaction. Recovery phải đối chiếu registry + committed selection + operation ownership/readiness trước bất kỳ reconciliation hoặc cleanup nào. Marker=reserved có thể tồn tại cả sau activation thành công nên tuyệt đối không dùng marker này làm orphan-deletion criterion. H3B còn phải định nghĩa lifecycle ownership chung cho delete/reconciliation/registry producers; không recursive delete dữ liệu chỉ vì một create trả NO.

Performance chỉ ảnh hưởng cold create/activation: thêm một marker nhỏ, vài open/stat/pread calls và bốn descriptors trong thời gian create đang pending. Expected cost low so với generation/archive, chưa benchmark. Checks trong source gate có I/O cục bộ giới hạn theo marker cố định; không gọi provider, notification hoặc chờ queue dưới gate.

## Kiểm chứng

Native profile fixture link module production mới, vẫn extract exact production create/finish/activation methods. Thêm 8 subprocess cạnh tranh cùng ID (một winner, bảy conflicts), exited-creator reservation, file/symlink/traversal rejection, descriptor lifetime trên success/failure, directory/identity/marker inode replacement giữ nguyên bytes, in-place marker corruption, root aliases/root replacement, và path drift sau generation/trong termination adapter. Các adapters không terminate app thật.

Host Windows: **11/11 source gates liên quan pass**, exact production profile-fragment extraction pass và `git diff --check` pass. Gates bao gồm profile flow, generation, identifier/device-group/telephony/artifact/preparation/source transactions, release contracts và RootHide contracts. Không có xcrun/Foundation/Theos tại local; native subprocess/runtime/descriptor assertions mới chưa chạy. CI hiện có chạy fixture rootful + RootHide, ba lượt mỗi variant; không thêm native assertion giả lập bằng Python để báo runtime đã pass.
