# Patch 1 — Keychain Bridge retirement

Ngày: 2026-10-24. Baseline: `b0d35c6`. Trạng thái: source implemented, host checks passed; native CI/package/device gates pending.

## Thay đổi

- Xóa listener `WeaponXKeychainBridge/Tweak.m` và injection plist khỏi source production; bỏ target/link/build/relocation rules. Các file được quản lý bởi Git nên vẫn có thể phục hồi từ baseline.
- Bỏ bridge filter computation API và classifier chỉ dùng cho bridge. UI/daemon chỉ ghi, fingerprint, sanitize, install và verify `TLinkIOSTweak.plist`.
- Giữ main app/extensions, SpringBoard/UIKit/WebKit coverage và placeholder-only empty state theo thuật toán cũ.
- Giữ nguyên resigned helper, clear no-launch và legacy archive `method=in_app` conversion; không sửa keychain data, profile hoặc backup.
- Clean các plist/dylib bridge đúng tên trong build staging cũ. CI kiểm tra extracted package bridge-absent cho rootful và RootHide.
- Cùng implementation migration chạy dưới dạng `DEBIAN/preinst` và installed `retire_keychain_bridge.sh`; postinst dừng daemon cũ rồi chạy lại sau legacy data copy, trước self-test/bootstrap.
- Migration không recurse, không terminate target apps, không chạm helper/backup. Status failure không được báo artifactsRemoved=true.
- Status nằm tại `/var/mobile/Library/Preferences/com.hydra.tlinkios.bridge-retirement.plist` (rootfs-prefixed khi chạy trong bootstrap RootHide). Không tạo `Library/TLinkIOS` từ preinst vì việc đó sẽ vô tình bỏ qua first-upgrade ProjectX data migration.
- Có artifact cũ: status `pending-target-restart` được giữ qua rerun. Không có artifact: `no-artifacts-detected`; cả hai đều `runtimeVerified=false`.
- Thay regression assertions về bridge tồn tại bằng source/package absence checks; giữ native main-filter/extension/helper round-trip tests.

## Verification đã chạy

| Kiểm tra | Kết quả |
| --- | --- |
| `test_keychain_bridge_retirement.py` | 10 tests: 9 pass, 1 skip |
| `test_phase_b_regression_static.py` | PASS |
| `test_roothide_build_static.py` | PASS |
| `test_webkit_unscoped_zero_interference.py` | PASS |
| `test_bootstrap_policy.py` | PASS: 72 capability combinations, revocation, unknown roles |
| `test_bootstrap_topology.py` | PASS: 27 constructor gates và lifecycle contracts |
| `audit_backup_restore_hardening.py` | PASS: 2500/2500 |
| `test_phase10_release_hardening_static.py` | PASS |
| `test_phase8_clear_modes_static.py` | PASS |
| `test_freeze_scope_independence_static.py` | PASS |
| `test_reset_picker_freeze_ui_static.py` | PASS |
| Shell syntax `DEBIAN/preinst`, `DEBIAN/postinst` | PASS |
| `git diff --check` | PASS |

Các migration tests thực thi shell script thật trên filesystem fixture tạm cho rootful/rootless/RootHide, fresh install, all known old injector layouts, preserved unrelated helper/profile/archive files, repeat upgrade, failed deletion, invalid fixture roots và status-path failure. Fixture mode đòi canonical non-root path và explicit fixture marker.

Leaf symlink test bị skip vì Windows không cấp privilege tạo symlink; CI macOS có test đó. Lần chạy sandbox ban đầu không cho child shell ghi fixture; chạy ngoài sandbox trên cùng disposable fixtures đã pass.

Backup/restore audit script không bị sửa. Tổng 2504 -> 2500 vì source listener bị xóa, bỏ bốn per-file environment checks cho file đó; không giảm semantic backup/restore guards.

## Gate chưa có bằng chứng

- Windows hiện không có xcrun/Theos/Foundation toolchain: chưa build Logos/Objective-C native hoặc package thật trong lượt này.
- Native injection fixtures và extracted-package absence đã được nối vào CI nhưng chưa có kết quả CI mới.
- Chưa install/upgrade lên thiết bị, chưa inspect/unload process, chưa chạy restore hoặc terminate app nào.

## Device acceptance trước release

1. Fresh install: package chỉ chứa main tweak; helper/daemon hoạt động và empty scope vẫn placeholder-only.
2. Upgrade từ package có bridge: preinst ghi restart requirement trước unpack; postinst loại staged/injector remnants kể cả dữ liệu ProjectX vừa migrate.
3. Mở lại phiên bản TLinkIOS mới và thay scope: không tái tạo bridge filter; native main/extension/WebKit/SpringBoard policies giữ nguyên.
4. Restart TLinkIOS và từng target app đã nạp bridge trong flow upgrade được kiểm soát; xác minh không có bridge image/listener trong process mới. File absence không thay thế bước này.
5. Restore archive cũ `method=in_app` qua resigned helper, không launch app để dùng entitlement context.
6. Kiểm tra rootful và RootHide thật; filesystem fixtures chỉ chứng minh migration mechanics, không chứng minh jailbreak/injector integration.

Patch tiếp theo theo plan: P0-B — NSURLSession blocked-task/completion lifecycle.
