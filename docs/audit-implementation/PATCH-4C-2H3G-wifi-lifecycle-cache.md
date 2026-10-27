# Patch 4C.2H3G — WiFi persistence, cache reload và observer lifetime

Người dùng xác nhận build H3F pass. H3G tiếp tục với WiFiManager; battery/global mirror vẫn để mốc riêng vì ordering và compatibility cần xử lý cùng nhau. Patch 4 chưa hoàn tất.

## Lỗi đã xác định từ code

1. WiFi persistence chưa tham gia lifecycle lease và tự create identity directory trước source commit. Target có thể bị delete/replace trong khoảng đó; source transaction không bảo vệ preparation/path lifetime.
2. Loader đặt currentProfileId mới nhưng giữ wifiInfo cũ khi file đích không tồn tại/không đọc được. Ví dụ A có saved WiFi, chuyển sang B chưa có wifi_info: currentWiFiInfo vẫn có thể trả SSID/BSSID của A vì cache count khác zero. Đây là logic bug trực tiếp; chưa có device reproducer.
3. NotificationCenter giữ block, block giữ mạnh manager; manager chỉ remove token trong dealloc. Với non-singleton instances, dealloc không tới được khi center còn giữ observer. Register lặp còn thêm nhiều observers; token property weak không cung cấp ownership rõ ràng cho cleanup.

## Boundary persistence

Save dùng existing `PXProfileArtifactMutation`: acquire nonblocking ownership, resolve validated target, copy cache ngoài source gate, rồi stage wifi_info/device_ids cùng nhau. Pending deletion, missing/replaced/symlink identity chặn stage; không create directory. Snapshot exception vẫn propagate theo policy cũ nhưng finally nhả lease/FD. Source fault giữ pair và source token cũ; error logging chạy sau release.

Optional ProfileManager handle được lấy trước acquire. Cold ProfileManager initializer có bootstrap/load cần lifecycle ownership, nên gọi sharedManager lần đầu từ resolver dưới lease có thể tự conflict. Resolver dưới lease chỉ dùng handle đã warm để đọc currentProfile, rồi file fallback như trước; không gọi lại sharedManager bên trong scope. Thêm respondsToSelector cho class method trước dynamic dispatch.

Target authority vẫn manager-first, sau đó canonical file fallback với numeric-to-string conversion và legacy `default` cache key. Không âm thầm đổi authority sang PXActiveProfileID hoặc dùng snapshot của daemon cho writer. Điều này cũng có nghĩa stale manager memory do process khác đổi selection chưa được giải quyết ở mốc này. Lease đảm bảo cooperating lifecycle exclusion trong persistence, không tự làm mọi memory mirror đồng bộ.

Generate/custom setter vẫn là **cache-first** API: prepare/validation/cache mutation precede save; lỗi persist không tự rollback cache và generation có thể trả candidate chưa ghi đĩa. Scope enrollment ở persistence boundary, không bao random preparation hoặc toàn currentWiFiInfo getter. Pure batch prepare/adopt/stage không acquire lease lồng, không đổi activation ordering. Đây là giới hạn có chủ ý để giữ API compatibility; không dùng return dictionary làm persistence acknowledgement.

## Loader và observer

Loader nhận một captured ID, reset cache trước khi đọc target, chỉ resolve filesystem path từ validated ID. Missing/unreadable dictionary để cache rỗng, không trả lại A như B. Current getter capture ID một lần cho nhánh reload, không lặp getCurrentProfileID qua public loader. Nếu thiếu data, fallback generation tiếp tục dùng policy cũ. Không mở rộng stored-field validation: một dictionary đọc được vẫn theo behavior cũ, SSID/MAC validation giữ ở custom setter.

Giữ raw string cache key (bao gồm `default`) để ephemeral candidate không bị generate lại vô hạn khi không có persistable active profile. Invalid key không được dùng tạo/read arbitrary directory. Các individual accessors như currentSSID/currentBSSID giữ cache-only behavior; chúng chưa có captured profile/thread-safety guarantee độc lập với notification/currentWiFiInfo refresh.

Observer token giữ strong để có thể remove trong dealloc; block giữ weak owner và strongify chỉ trong callback. Register guard dưới synchronized(self) đảm bảo idempotent, không nhân observer khi gọi lặp. Notification vẫn ở mainQueue; queued event chỉ kích hoạt reload current authority, không adopt event ID như source authority. Không giữ lock khi deliver callback/load hoặc remove trong dealloc.

## Kiểm chứng

Preparation runner thêm exact production WiFi init/dealloc/observer/resolver/loader/getter/save/setter/validation methods vào một fixture riêng; fixture prepare/cache-adoption cũ vẫn giữ để bảo vệ compatibility. NetworkManager, Uptime/Storage cases trước đó không bị thay bằng mocks. Native sources tiếp tục link scope/source engine thật, rootful và RootHide define matrices.

Optional ProfileManager trong WiFi fixture là seam backend cho sharedManager/currentProfile vì không link UIKit/ProfileManager đầy đủ vào Foundation binary; warmup probe kiểm tra call order ngoài lease. Cache-copy spy là NSObject/NSCopying. Full iOS cold initializer/thread matrix vẫn cần device acceptance, không suy ra từ seam test.

Các case mới kiểm tra A→B missing WiFi không giữ cache A, corrupt plist reload, cache-hit không thêm source transaction, idempotent token, weak-owner deallocation, queued stale notification đọc current selection, busy/pending trước target/copy, missing identity không create, reentrant Storage exclusion, fixed target trong copy, pair rollback, exception cleanup, late journal và missing/replaced/symlink identity. Custom setter field/MAC validation, manager-first authority, numeric fallback và ephemeral `default` cache được giữ. Source contracts bảo vệ warmup/acquire ordering và observer ownership; macro arity guard bao cả fixture mới.

Windows đã pass 15 source/host gates, macro validation, exact native-fragment extraction và git diff check. Foundation/Theos native H3G chưa chạy trên máy này; cần macOS CI xác nhận. RootHide define fixture không thay cho actual SDK/namespace/device validation.

## Performance và phần còn lại

Persistence thêm lifecycle/source coordination và held identity FD như H3E/H3F: expected cost low–moderate ở cold writes, chưa benchmark. Saved cache hits không thêm lifecycle/source transaction; bỏ per-hit WiFi log và redundant reload target lookup. Synchronized observer registration chỉ là cold path. Không thêm timer, polling, queue thường trực hoặc network request.

Mutable manager-cache races, candidate-return semantics, inter-process memory freshness và total cache publication ordering vẫn partial; không claim WiFiManager đã hoàn toàn thread-safe. Battery source/global mirror ordering, standalone IdentifierManager writers/migration, dashboard preview, metadata/defaults/security authority, rootful captured readers, directory cleanup/durability và device matrix còn pending. Scope checks không cô lập namespace khỏi external writers sau checkpoint, không có power-loss durability hoặc automatic cleanup claim. Patch 5–8 chưa triển khai.
