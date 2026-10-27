# RootHide package injector dependency follow-up

Source `control.roothide` khai báo `mobilesubstrate (>= 0.9.5000)`, cùng dependency name với rootful. Đây là nguồn tên dependency mà package manager hiển thị. Không có file .deb/log resolver hoặc package inventory của thiết bị trong lượt kiểm tra, nên không kết luận máy thực sự thiếu injection engine hay đang dùng nhầm artifact.

RootHide official package index có ElleKit architecture iphoneos-arm64e và `Provides: mobilesubstrate (= 99)`. Vì vậy dependency cũ có thể được ElleKit thỏa mãn; nó không tự chứng minh phải cài Cydia Substrate thật. ElleKit cũng implement Substrate API, nên các header/calls MSHookFunction/MSHookMessageEx trong code không phải lý do để cài đồng thời hai engines. Nguồn: [RootHide Packages](https://raw.githubusercontent.com/roothide/roothide.github.io/main/Packages), [RootHide ElleKit README](https://github.com/roothide/ellekit#ellekit).

Build lane của project đã relocate sang ElleKit `/usr/lib/TweakInject`. Follow-up đổi riêng RootHide dependency thành `firmware (>= 15.0), ellekit`; rootful giữ nguyên metadata hiện hành. Không bỏ dependency injector hoặc thay hook ABI/implementation.

Một entry point khác cũng được bảo vệ: direct `make package THEOS_PACKAGE_SCHEME=roothide` trước đây không truyền alternate control giống các wrapper/CI. RootHide branch trong Makefile nay `override _THEOS_DEB_PACKAGE_CONTROL_PATH` để luôn dùng control.roothide. Cần override vì upstream [RootHide Theos deb.mk](https://github.com/roothide/theos/blob/master/makefiles/package/deb.mk) gán biến này bằng `:=`; một normal assignment trước include có thể bị ghi đè.

Thêm validator cho identity/name/architecture/firmware/mandatory ElleKit dependency và reject legacy mobilesubstrate ở Depends/Pre-Depends. Negative controls bao wrong source, legacy dependency, alternative injector, wrong architecture và duplicate fields; folded/additional unrelated dependencies vẫn được chấp nhận. CI chạy validator trên DEBIAN/control đã extract từ chính .deb, ngoài static source gate, để không chỉ kiểm tra template.

Windows pass source/negative metadata checks, CLI acceptance/rejection, RootHide build contracts và affected release/bootstrap source gates; diff sạch. Không có Theos/dpkg-deb hoặc .deb sẵn tại local để xác minh package build/install. Artifact mới cần clean/rebuild RootHide rồi kiểm tra CI; metadata trong .deb cũ không tự thay đổi. Không cài/gỡ/sửa package hoặc repository trên thiết bị. Audit rollout H3S vẫn giữ status native/package pending trước đó.
