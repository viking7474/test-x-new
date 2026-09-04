# iFakePro → x-new — Agent Implementation Plan

> Mục tiêu: biến `iFakePro_vs_x-new_Hook_Gap_Assessment.md` thành backlog kỹ thuật có thể giao trực tiếp cho agent triển khai từng phần, có dependency, file dự kiến sửa, kiểm thử và tiêu chí hoàn thành.
>
> Đây là plan triển khai **surface parity có kiểm soát**, không phải yêu cầu clone iFake 1:1 theo số hook.

---

## 0. Tài liệu bắt buộc agent phải đọc trước khi sửa code

Mỗi agent bắt đầu task phải đọc tối thiểu:

1. `x-new/iFakePro_vs_x-new_Hook_Gap_Assessment.md` — source gap assessment.
2. `x-new/new-plan.md` — policy/architecture và danh sách BLOCKED.
3. `iFakePro_Hooks_Analysis.md` — behavior source-of-truth phía iFake.
4. `iFakePro_ObjC_Hook_Callsite_Inventory.md` — exact ObjC call-sites.
5. `iFakePro_Full_Hook_List.md` — exact native inventory.
6. `x-new/common/PXIdentitySurfaceRegistry.h/.m`.
7. `x-new/common/PXConsistencyMatrix.h/.m`.
8. `x-new/TLinkIOSTweak/PXNativeHookCoordinator.h/.m`.
9. `x-new/TLinkIOSTweak/PXIdentitySnapshot.h/.m` hoặc implementation tương ứng trong `common` nếu path hiện tại thay đổi.
10. `x-new/TLinkIOSTweak/PXScope.h/.m`.

Nếu task liên quan Lockdown/cellular, đọc thêm:

- `x-new/TLinkIOSTweak/LockdownIdentityHooks.x`
- `x-new/research/PXLockdown*Provider.*`
- `x-new/tests/PXLockdown*Tests.m`

Nếu task liên quan filesystem/JB, đọc thêm:

- `x-new/TLinkIOSTweak/JailbreakBypassHooks.x`
- `x-new/TLinkIOSTweak/PXP1AFilters.*`
- `x-new/TLinkIOSTweak/PXP1BFilters.*`
- `x-new/TLinkIOSTweak/PXP1CFilters.*`

---

# 1. Luật triển khai chung

## 1.1. Một task = một thay đổi cô lập

Agent không được gom nhiều Phase vào một commit. Mỗi task phải có:

- diff nhỏ, tập trung;
- tests đi kèm trong cùng task;
- ghi lại exact hook/symbol/selector đã cài;
- không refactor rộng ngoài phạm vi task nếu không bắt buộc.

## 1.2. Canonical source bắt buộc

Không tạo plist/config/cache riêng cho từng hook mới nếu cùng giá trị đã nằm trong `PXIdentitySnapshot`.

Thứ tự source:

`PXIdentitySnapshot` → registry/resolver canonical → hook projection.

Không đọc lại file profile trực tiếp trên hot path nếu snapshot đã cung cấp dữ liệu.

## 1.3. Fail-open

Bất kỳ điều kiện nào dưới đây xảy ra thì trả/call original:

- process không thuộc scope;
- feature/toggle tắt;
- snapshot invalid;
- field profile thiếu hoặc malformed;
- runtime symbol/class/selector không tồn tại;
- type encoding không đúng kỳ vọng;
- original trả shape/type không tương thích với replacement;
- ABI chưa xác nhận.

Không “đoán” giá trị thay thế.

## 1.4. Không mở rộng injection scope

Không thêm daemon/system executable vào filter chỉ để đạt parity với iFake.

Đặc biệt không inject rộng vào:

- `lockdownd`;
- security/attestation daemon;
- trust/pairing service;
- daemon hệ thống nhạy cảm.

## 1.5. BLOCKED tuyệt đối

Agent không được triển khai:

- `SecTaskCopyValueForEntitlement` falsification;
- `SecCodeCopySigningInformation` falsification;
- `SecStaticCodeCreateWithPath` / `SecStaticCodeCheckValidity*` bypass;
- App Attest / DeviceCheck bypass;
- AMFI/code-signing/entitlement bypass;
- vendor/anti-fraud-specific selector packs từ InitFunc_8–16;
- TLS/pinning weakening;
- pairing/trust/Activation Lock manipulation;
- generic global `strstr`, `syscall`, `read/write`, `mmap/mprotect` interception nếu không có task evidence riêng.

Nếu trong lúc làm task phát hiện cần một mục BLOCKED để “pass test”, agent phải dừng và ghi blocker, không tự mở rộng scope.

---

# 2. Definition of Done áp dụng cho mọi task

Một task chỉ được đánh dấu DONE khi đủ 10 điểm:

1. Hook/symbol/selector được resolve an toàn.
2. Có recursion/reentrancy guard nếu hook có thể gọi lại cùng surface.
3. Original passthrough hoạt động 100% khi gate không thỏa.
4. Return type/CF ownership/ObjC lifetime/errno semantics đúng.
5. Không tạo identity source thứ hai ngoài canonical snapshot.
6. Scope check dùng helper canonical (`PXScope` hoặc policy hiện hữu), không tự invent bundle allowlist khác.
7. Có test positive + negative + missing-field + disabled/scope-off.
8. Identity task cập nhật `PXConsistencyMatrix` khi surface mô tả cùng một canonical truth.
9. Static test xác nhận hook được cài và BLOCKED hooks vẫn absent.
10. Docs/evidence cập nhật: exact files, exact symbols/selectors, test result, known limitations.

---

# 3. Dependency graph

```text
P0-00 Baseline & fixtures
    |
    v
P0-01 Registry + consistency surface expansion
    |
    +--> A-01 ManagedConfiguration
    +--> A-02 CTServer MobileEquipmentInfo
    +--> A-03 sysctlnametomib
    +--> A-04 C locale/time
    +--> A-05 Private identity wrapper dispatcher
                 |
                 v
              A-06 Phase-A consistency gate
                 |
                 v
              B-00 Native query sanitizer foundation
                 |
        +--------+---------+---------+---------+
        v                  v         v         v
      B-01               B-02      B-03      B-04
 directory/stat64      path/xattr process/socket PAC proxy
        \                  |         |         /
         +-----------------+---------+--------+
                           v
                         B-05 ObjC secondary surfaces
                           |
                           v
                         B-06 Phase-B regression gate
                           |
                 +---------+---------+
                 v                   v
               C-01                C-02
      SC debug scalar       plist parser gated

C-03/C-04 only after evidence.
Phase D optional and independent after Phase A is stable.
```

---

# 4. Phase P0 — baseline trước khi thêm hook

## P0-00 — Freeze baseline + create parity fixtures

### Mục tiêu

Tạo một baseline machine-readable để mọi agent sau biết source hiện tại đã cover gì và test nào phải tiếp tục pass.

### Không sửa behavior production

Task này chỉ thêm test/inventory/documentation.

### Việc phải làm

1. Tạo `x-new/tests/PXHookParityBaselineTests.m` + Main nếu pattern test hiện tại yêu cầu.
2. Encode các nhóm đã được xác nhận COVERED:
   - MG main/alternate entry points;
   - IOKit trio;
   - Lockdown identity;
   - `uname`;
   - `sysctl/sysctlbyname`;
   - 5 CLLocation delegate selectors;
   - CoreMotion main data objects;
   - major Foundation JB hooks;
   - `CFNetworkCopySystemProxySettings`.
3. Encode các exact gaps Phase A/B dưới dạng expected-missing baseline.
4. Encode BLOCKED symbols dưới dạng must-remain-absent assertions.
5. Tạo một fixture canonical profile có ít nhất:
   - DeviceModel/HwModel/BoardID/ModelNumber;
   - IOSVersion/IOSBuild/Darwin/KernelVersion;
   - Serial/MLB/UDID;
   - IMEI/IMEI2/MEID/IMSI/Baseband;
   - locale/language/timezone.

### File dự kiến

- `x-new/tests/PXHookParityBaselineTests.m`
- `x-new/tests/PXHookParityBaselineMain.m`
- `x-new/scripts/test_ifake_parity_static.py`
- docs mới hoặc append vào assessment.

### Tests

- `python x-new/scripts/test_phase3_hooks_static.py`
- `python x-new/scripts/test_ifake_parity_static.py`
- existing consistency tests trên macOS toolchain.

### Done khi

Baseline fail nếu một hook covered bị mất, hoặc một BLOCKED symbol xuất hiện.

### Execution evidence — T-0077 / P0-00

- Added machine-readable fixture: `tests/fixtures/ifake_parity_profile.json`.
- Added host-static parity contract: `scripts/test_ifake_parity_static.py`.
- Added Foundation baseline harness: `tests/PXHookParityBaselineTests.m` + `tests/PXHookParityBaselineMain.m`.
- Wired `test_ifake_parity_static.py` into `scripts/release_hardening.py` extended regression list.
- Covered assertions pin MG main/alternate routes, IOKit coordinator ownership, Lockdown interception, uname, all five CLLocation delegate selectors, CoreMotion, major Foundation JB surfaces, proxy settings, locale/timezone and Canvas/WebGL web-layer coverage.
- Expected-missing assertions pin Phase-A gaps (ManagedConfiguration six getters, CTServer V1/V2, `sysctlnametomib`, C locale/time install paths, PAC proxy, `SCIsRunningWithDebugger`).
- BLOCKED assertions pin all five Security.framework falsification targets and high-risk generic installers (`syscall`, `sandbox_check`, generic `fcntl`, dyld count/header/slide).
- Production hook behavior was not modified by P0-00.
- Workspace shell policy rejects direct `python3`, and `verify_project` reports no configured generic Python test runner; therefore the new static script could not be executed in this environment. Source/pattern contracts were reviewed with workspace search, and no PASS execution is claimed here.

---

## P0-01 — Extend identity surface registry + consistency matrix model

### Mục tiêu

Chuẩn bị registry để các surface mới không tự map key độc lập.

### Thiết kế đề xuất

Mở rộng `PXIdentitySurfaceMask` thêm surface semantic, ví dụ:

- `PXIdentitySurfaceManagedConfiguration`
- `PXIdentitySurfaceCoreTelephonyServer`
- `PXIdentitySurfacePrivateWrapper`

Không bắt buộc dùng đúng tên này nếu agent có tên tốt hơn, nhưng phải giữ một registry trung tâm.

### Việc phải làm

1. Mở rộng bitmask trong `common/PXIdentitySurfaceRegistry.h`.
2. Update validator loop trong `.m`; hiện loop upper-bound đang dựa vào `PXIdentitySurfaceIORegistry`, phải đổi sang max surface mới hoặc iteration table an toàn.
3. Thêm canonical mappings tối thiểu cho:
   - ProductType/DeviceModel;
   - SerialNumber;
   - UDID/System UUID mapping đúng semantics từng API;
   - ProductVersion;
   - ProductBuildVersion;
   - IMEI/IMEI2/MEID/IMSI.
4. Không collapse MLB serial vào SerialNumber.
5. Thêm surface rows tương ứng vào `PXConsistencyMatrix` cho những truth cùng source.
6. Extend `PXIdentitySurfaceRegistryTests` và `PXConsistencyMatrixTests`.

### Critical checks

- duplicate alias chỉ bị cấm trong cùng surface, không cấm cùng key ở hai surface khác nhau;
- expected type phải đúng từng API;
- group không được partial projection.

### Done khi

Registry/matrix tests pass trước khi bất kỳ hook mới nào được cài.

### Execution evidence — T-0078 / P0-01

- Extended `PXIdentitySurfaceMask` with `ManagedConfiguration`, `CoreTelephonyServer`, and `PrivateWrapper`; registry validation now iterates through the new highest bit.
- Added canonical registry rows for all six ManagedConfiguration getters and the exact six CTServer dictionary fields iFake rewrites.
- Added a deliberately narrow generic private-wrapper set for product/model/version/serial/UDID/IMEI/IMEI2/MEID; `secureElementIdentifier` / `primarySecureElementIdentifier` remain excluded from generic parity.
- Extended `PXConsistencyMatrix` with ProductVersion/Build, DeviceModel/HwModel, Serial/MLB, UDID/SystemBootUUID, IMEI/IMEI2/MEID/IMSI cross-surface groups before installing any new production hook.
- Byte-level iFake verification corrected an important semantic assumption: `MCGestaltGetProductName -> sub_ABF1C` decrypts its config key to exact `device_product_id`, so the canonical source is ProductType/`DeviceModel`, not marketing `DeviceModelName`. `MCGestaltGetDeviceUUID` decrypts to `device_udid`; `MCCTIMEI` decrypts to `device_imei`.
- Extended registry/matrix tests and Phase-3 static contracts for the new surfaces; production hook installation remains unchanged in P0-01.
- `git diff --check` passed. Direct Python/Foundation test execution is not available under the current CatDesk shell policy, so no runtime/static-script PASS is claimed yet.

---

# 5. Phase A — Core identity parity

## A-01 — ManagedConfiguration 6 getter compatibility module

### Exact targets

- `MCCTIMEI`
- `MCIOSerialString`
- `MCProductVersion`
- `MCProductBuildVersion`
- `MCGestaltGetProductName`
- `MCGestaltGetDeviceUUID`

### Mục tiêu

Đóng đường app gọi private ManagedConfiguration getter thay vì MG/Lockdown.

### File đề xuất

- mới: `x-new/TLinkIOSTweak/ManagedConfigurationIdentityHooks.x`
- tests: `PXManagedConfigurationIdentityTests.m`
- update static parity script.

### Cách triển khai

1. Runtime resolve từng symbol bằng `dlsym`; không hard-link nếu framework availability không ổn định.
2. Cài mỗi hook `dispatch_once`.
3. Chụp original function pointer riêng từng ABI.
4. Trước replacement:
   - check process scope;
   - snapshot valid;
   - registry entry/toggle valid;
   - canonical value well-formed.
5. Nếu bất kỳ bước nào fail → original.
6. Preserve CF/ObjC ownership đúng prototype; agent phải xác minh từng function signature trước khi code.
7. Không đọc profile file trực tiếp.

### Mapping yêu cầu

- `MCCTIMEI` → IMEI canonical.
- `MCIOSerialString` → SerialNumber.
- `MCProductVersion` → IOSVersion.
- `MCProductBuildVersion` → IOSBuild.
- `MCGestaltGetProductName` → DeviceModel/ProductType semantics theo exact iFake behavior/API contract.
- `MCGestaltGetDeviceUUID` → đúng UUID/UDID source theo API, không tự alias nếu chưa xác nhận.

### Tests bắt buộc

- symbol missing → no crash;
- scope off → original;
- toggle off → original;
- missing profile field → original;
- valid profile → projected value;
- generation change → new snapshot value without stale cache;
- sensitive values không log plaintext.

### Done khi

6/6 targets có install audit + tests + consistency rows.

### Execution evidence — T-0079 / A-01

- Added `TLinkIOSTweak/ManagedConfigurationIdentityHooks.x` with runtime `dlopen`/`dlsym` resolution for all six targets and six independent original function pointers.
- ABI was checked against the iFake installer/replacements: all six are no-argument pointer-return functions; the x-new adapter uses `id (*)(void)` without claiming a stronger Create/Copy ownership contract.
- Added thread-local reentrancy guard, canonical `PXProcessIsAllowedForSpoofing` scope gate, `PXCurrentIdentitySnapshot()` source, central ManagedConfiguration registry lookup and `IdentifierManager` toggle gate. Every uncertainty falls back to the saved original.
- Added pure shared resolver `common/PXManagedConfigurationIdentity.{h,m}` and dedicated positive/negative/missing/scope-off/toggle-off/generation-change tests `PXManagedConfigurationIdentityTests.m` + Main.
- Static parity baseline now treats the six MC getters as COVERED rather than expected-missing; Phase-3 static contracts pin the installer and registry usage.
- Sensitive projected values are never written to logs; install telemetry records symbol/capability names only.
- No new injection bundle/executable was added; absent framework/symbols are a safe no-op.
- `git diff --check` passed. Python/clang execution is blocked by the current CatDesk shell allowlist, so the newly added executable tests are source-reviewed but no local PASS execution is claimed.

---

## A-02 — CoreTelephony server MobileEquipmentInfo V1/V2

### Exact targets

- `_CTServerConnectionCopyMobileEquipmentInfo`
- `_CTServerConnectionCopyMobileEquipmentInfoV2`

### Mục tiêu

Đóng dictionary path mà app có thể dùng để lấy IMEI/MEID/IMSI trực tiếp.

### File đề xuất

- mới: `x-new/TLinkIOSTweak/CoreTelephonyServerIdentityHooks.x`
- tests: `PXCoreTelephonyServerIdentityTests.m`

### Implementation rule quan trọng

Không dựng dictionary giả từ đầu.

Flow:

1. gọi original trước;
2. nếu result không phải dictionary → trả nguyên;
3. mutable copy;
4. chỉ rewrite key **đang tồn tại** và có canonical value hợp lệ;
5. preserve unknown keys;
6. return immutable/correct CF ownership theo original ABI.

### Field family cần nghiên cứu/confirm từ iFake

- IMEI primary;
- IMEI secondary nếu V2 expose;
- MEID;
- IMSI;
- các key alias tương đương mà iFake replacement xử lý.

Không thêm field mà original không có.

### Tests

- unknown fields preserved;
- existing eligible fields rewritten;
- absent eligible fields stay absent;
- non-dictionary/nil original stays unchanged;
- partial profile chỉ rewrite field đủ dữ liệu;
- V1/V2 cùng canonical values.

### Done khi

V1/V2 output không mâu thuẫn Lockdown/IOKit/MG canonical fields.

### Execution evidence — T-0080 / A-02

- Added `common/PXCoreTelephonyServerIdentity.{h,m}` as a pure, testable six-field overlay using the central `PXIdentitySurfaceCoreTelephonyServer` registry. It rewrites only fields already present in the original mutable dictionary and preserves all unknown/absent fields.
- Added `TLinkIOSTweak/CoreTelephonyServerIdentityHooks.x` for exact runtime symbols `_CTServerConnectionCopyMobileEquipmentInfo` and `_CTServerConnectionCopyMobileEquipmentInfoV2`. ABI is source-bound to iFake `sub_B7948/sub_B8094`: opaque X0/X1 inputs, out-dictionary pointer in X2, original status returned unchanged.
- Both live hooks call original first and mutate the same output dictionary in place; they never replace the out pointer, preserving the caller's original ownership/lifetime contract.
- Runtime dictionary-key objects are resolved from CoreTelephony exported CFString globals with `dlsym`; an exact semantic-name fallback is accepted only when that exact key already exists in the original dictionary. No IMEI/IMSI/MEID string aliases are guessed.
- Exact iFake field set remains six keys: `kCTMobileEquipmentInfoCurrentMobileId`, `kCTMobileEquipmentInfoIMEI`, `kCTMobileEquipmentInfoIMSI`, `kCTMobileEquipmentInfoMEID`, `kCTPostponementInfoIMEI`, `kCTPostponementInfoMEID`. Mapping is MEID/IMEI/IMSI/MEID/IMEI/MEID. A separate IMEI2 value is deliberately not injected into this CTServer family because iFake does not expose an IMEI2 field here.
- Added `PXCoreTelephonyServerIdentityTests.m` + Main covering unknown-key preservation, absent-key non-synthesis, toggle isolation, malformed/partial profile fail-open, V1/V2 canonical agreement, explicit no-IMEI2-collapse and generation refresh/no stale cache.
- Updated `test_ifake_parity_static.py` and `test_phase3_hooks_static.py`: CTServer V1/V2 moved from expected-missing to covered contracts while all BLOCKED/high-risk assertions remain unchanged.
- `git diff --check` passed for A-02 files. Direct `python3` execution remains blocked by CatDesk allowlist shell policy (`SHELL_MODE_BLOCKED`), so no executable static/Foundation PASS is claimed in this environment.
- No injection scope was expanded; the new `.x` module is included by the existing `TLinkIOSTweak/*.x` wildcard only in already-selected injected processes.

---

## A-03 — `sysctlnametomib` consistency layer

### Mục tiêu

Đảm bảo name → MIB path không tạo discrepancy với `sysctlbyname`/`sysctl`.

### File nên sửa

Ưu tiên:

- `PXNativeHookCoordinator.h/.m` nếu đây là shared native symbol;
- module provider riêng chỉ xử lý identity/JB relevant names.

Không cài một direct hook độc lập nếu coordinator đã là owner pattern cho `sysctl*`.

### Việc phải làm

1. Add symbol constant + original pointer + typed provider API cho `sysctlnametomib` nếu coordinator model phù hợp.
2. Hook implementation phải preserve standard buffer-length/query semantics.
3. Không fabricate MIB cho key kernel không tồn tại.
4. Đối với name mà existing `sysctlbyname` provider spoof:
   - name resolution vẫn phải tương thích real kernel contract;
   - returned MIB sau đó gọi `sysctl` phải đi vào existing projection/sanitizer.
5. Add recursion guard.

### Tests

- two-pass length behavior;
- unknown key behavior/errno;
- known `hw.*` and `kern.*` key name→MIB→sysctl consistency;
- no duplicate original call.

### Done khi

Fixture so `sysctlbyname(key)` và `sysctlnametomib(key)+sysctl(mib)` không diverge.

### Execution evidence — T-0081 / A-03

- Added `sysctlnametomib` as a first-class coordinator-owned symbol (`kPXNativeSymbolSysctlNameToMIB`) beside `sysctl` and `sysctlbyname`; no direct hook was added to `Tweak.x` or another module.
- Added typed `PXSysctlNameToMIBPreBlock/PostBlock` registration API, one coordinator original pointer, install-once ownership and diagnostics tracking.
- `PXCoord_sysctlnametomib` is transparent by default, matching iFake `sub_ABAEC`: it forwards the exact `(name,mib,sizep)` arguments to the original and returns the original result/errno/buffer semantics unchanged. No MIB is fabricated or rewritten.
- Added a thread-local recursion guard and fail-open exception path that avoids double-calling the original after a post-provider exception.
- Updated `scripts/audit_native_hooks.sh` so any future `MSHookFunction/%hookf` installation of `sysctlnametomib` outside `PXNativeHookCoordinator.m` is an ownership violation.
- Added `PXSysctlNameToMIBContractTests.m` + Main. The macOS/Darwin harness resolves real `kern.osrelease` and `hw.machine` names, compares `sysctlbyname` size/value bytes with `sysctlnametomib + sysctl`, checks the short-MIB `ENOMEM` contract and checks that an unknown name fails rather than receiving a fabricated MIB.
- Updated Phase-3/parity static contracts and removed `sysctlnametomib` from expected-missing baseline.
- `git diff --check` passed. Direct Python/Foundation execution remains unavailable under current CatDesk shell policy, so no executable test PASS is claimed here.
- No injection scope or identity source changed.

---

## A-04 — C runtime locale/time layer

### Exact targets

- `localtime`
- `localtime_r`
- `setlocale`

### Mục tiêu

Đồng bộ C runtime với `NSLocale`/`NSTimeZone`/CF/JS layer hiện có.

### File đề xuất

- mới: `LocaleRuntimeHooks.x`, hoặc mở rộng `LocaleTimeZoneHooks.x` nếu không làm file này quá lớn.

### Cảnh báo recursion

`PXFileDebug.h` và `PXScope.m` hiện gọi `localtime_r` để logging. Hook mới bắt buộc có thread-local guard và logging path không được quay lại hook vô hạn.

### Semantics

- `localtime/localtime_r`: chỉ project timezone-relevant `struct tm` khi target region/time spoof thực sự active; preserve timestamp input.
- `setlocale`: không blanket-return locale giả cho category không liên quan. Tôn trọng category và original state; chỉ project categories có canonical locale setting.
- thread safety: `localtime` static-buffer semantics phải được giữ.

### Tests

- disabled → byte-equivalent original where practical;
- `localtime_r` output timezone offset/day rollover correct around boundary fixtures;
- `localtime` and `localtime_r` agree;
- `setlocale(LC_ALL,NULL)` query semantics preserved;
- logging path no recursion/deadlock.

### Done khi

C/ObjC/CF locale-time fixtures cùng canonical locale/timezone.

### Execution evidence — T-0082 / A-04

- Extended the existing canonical `LocaleTimeZoneHooks.x` instead of creating a second profile source. The C hooks reuse `LTZShouldApply`, target-region settings, `LTZEffectiveTimeZoneName`, and the existing process `TZ` + `tzset()` owner.
- Added exact C entry points `localtime`, `localtime_r`, and `setlocale` inside the existing `PXLocaleTimeZoneRuntime` group. A single thread-local guard stays active through the original libc call, so a libc implementation that internally crosses from `localtime` into `localtime_r` passes through without re-entering projection/logging.
- `localtime/localtime_r` do not shift timestamps or synthesize `struct tm`; they reassert the already-canonical process TZ before calling the original and return the original pointer/caller buffer exactly. This closes a caller that mutates `TZ` between profile notifications without double-applying an offset.
- Serialized x-new-owned `TZ`/`tzset()` mutations with `os_unfair_lock`; Foundation/profile reads occur before the lock so the lock is not held across re-entrant Objective-C work.
- Added `common/PXLocaleRuntimeProjection.{h,m}`. Locale projection is conservative: BCP-47 `-` is normalized to `_`, UTF-8 is appended only when no codeset is present, and only standard locale categories are accepted.
- Deliberately safer than iFake `sub_B0BF8`: `setlocale(category,NULL)` remains a pure query and explicit non-empty caller requests such as `"C"` remain caller-owned. Only `setlocale(category, "")` may try the canonical target-region locale; if that locale is unavailable, the hook calls original with the caller's `""` and fails open.
- Added `PXLocaleRuntimeProjectionTests.m` + Main covering locale-name normalization, category/input gating, `localtime` vs `localtime_r` agreement, caller-buffer identity, UTC fixture, Darwin `tm_gmtoff` vs `NSTimeZone` for `Asia/Ho_Chi_Minh`, and setlocale-query no-mutation behavior.
- Updated Phase-3/parity static contracts; the C locale/time trio moved from expected-missing to covered while BLOCKED/high-risk assertions remain unchanged.
- `git diff --check` passed. Direct Python/Foundation execution is still unavailable under current CatDesk shell policy, so no executable test PASS is claimed.
- No injection scope was expanded and no new locale/time configuration file/cache was introduced.

---

## A-05 — Generic private identity wrapper dispatcher

### Mục tiêu

Đóng các wrapper selector generic/private mà iFake hook trực tiếp, nhưng **không port vendor anti-fraud classes**.

### Selector candidates đầu tiên

- `deviceInfoForKey:`
- `_deviceInfoForKey:`
- `sf_productType`
- `sf_serialNumber`
- `sf_udidString`
- `sf_uuidString`
- `applicationDSID`
- `MLBSerialNumber`
- `internationalMobileEquipmentIdentity`
- `internationalMobileEquipmentIdentity2`
- `mobileEquipmentIdentifier`
- `uniqueDeviceIdentifier`
- `deviceGUID`
- `deviceUDID`
- `deviceSerialNumber`
- `platformIdentifier`
- `_iOSComponentHardwarePlatform`
- `_iOSComponentBuildVersion`
- `_iOSComponentDeviceModel`
- `secureElementIdentifier` / `primarySecureElementIdentifier` chỉ khi policy xác nhận đây là identity projection bình thường, không security/attestation evidence.

### Bước 1 bắt buộc — classification trước implementation

Agent phải lập table:

`selector | known system/generic classes | return encoding | canonical source | toggle | policy status`

Bất kỳ class nào vendor/anti-fraud-specific → EXCLUDED.

### File đề xuất

- `PrivateIdentityWrapperRegistry.h/.m`
- `PrivateIdentityWrapperHooks.x`
- tests tương ứng.

### Installer design

1. Runtime enumerate **allowlisted class names**, không hook `NSObject` blanket.
2. Verify selector tồn tại.
3. Verify method type encoding đúng adapter dự kiến.
4. Install via `MSHookMessageEx` only after validation.
5. Getter no-arg và key-based getter dùng adapter riêng.
6. Fallback original nếu missing canonical value.
7. Dedupe per class+selector.

### Không được làm

- không scan mọi class rồi hook mọi selector trùng tên;
- không hard false/true các anti-fraud booleans;
- không hook secure enclave/attestation evidence APIs.

### Tests

- fake fixture class có đúng encoding → hook installs;
- same selector wrong encoding → skip;
- unallowlisted class → skip;
- missing value → original;
- duplicate install → no double hook;
- class absent → no crash.

### Done khi

Có dispatcher generic có kiểm soát; không cần đạt “98 hooks” raw count.

### Execution evidence — T-0083 / A-05

- Added pure classification/projection helper `common/PXPrivateIdentityWrapperProjection.{h,m}`. The live installer and host tests consume the same explicit rule descriptors, preventing a separate test-only allowlist from drifting from production.
- Added `TLinkIOSTweak/PrivateIdentityWrapperHooks.x` with separate no-argument and one-object-argument adapters. Every install requires: launch/runtime scope allowed, non-SpringBoard process, exact allowlisted class, class image under `/System/Library/` or `/usr/lib/`, selector existence, object-return encoding, exact arity, and dedupe on `(targetClass, SEL, metaFlag)` before `MSHookMessageEx`.
- Late-loaded Apple private classes are handled by `_dyld_register_func_for_add_image` only as a scheduling signal; actual Objective-C discovery/install work runs on a dedicated serial queue. Hook bodies re-check scope, valid `PXIdentitySnapshot`, registry ownership and the owning `IdentifierManager` toggle on every call.
- The rule inventory is intentionally Apple/system-only (`UIDevice`, `LSApplicationProxy`, `AMSDevice`, `AADeviceInfo`, CoreTelephony/Accounts wrappers, `ICDeviceInfo`, `DMFDevice`, `AMSUserAgent`, etc.). Generic class `Device`, all `PK*`/`NF*` Secure Element/PassKit evidence classes, and vendor anti-fraud families are explicitly excluded and negative-tested.
- Keyed `UIDevice.deviceInfoForKey:` / `_deviceInfoForKey:` calls original exactly once, then project only keys recognized by the central MobileGestalt/IORegistry/private-wrapper registry. String/Data shape is preserved; unknown keys and unexpected object classes fail open.
- No-arg getters likewise call original exactly once and only replace NSString/NSData-compatible results. Missing registry row, toggle off, invalid snapshot, scope off, class/selector absence or encoding mismatch leaves original unchanged.
- Byte replay of iFake `sub_B17D8` corrected a pre-existing P0-01 mapping: `UIDevice.sf_uuidString` resolves exact config key `ads_tracking`, so x-new now maps `sf_uuidString -> IDFA`, not `SystemBootUUID`. `applicationDSID` is tied to the same IDFA group. Fixture, registry tests and consistency matrix were updated so this correction is locked.
- Added `PXPrivateIdentityWrapperProjectionTests.m` + Main for rule dedupe, negative class families, encoding validation, String/Data shape preservation, keyed lookup projection, unknown-key fail-open and the `sf_uuidString/applicationDSID -> IDFA` correction.
- Updated Phase-3/parity static contracts; A-05 is now a covered surface. No injection filter expansion was added.
- `git diff --check` passed. Direct Python/Foundation executable tests remain unavailable under the current CatDesk shell policy, so no executable PASS is claimed.

---

## A-06 — Phase-A consistency gate

### Mục tiêu

Không cho merge Phase A nếu cùng truth trả khác nhau ở các API.

### Mở rộng `PXConsistencyMatrix`

Ít nhất thêm surface rows cho:

- ManagedConfig ProductVersion/Build/ProductType/Serial/UUID;
- CT IMEI/MEID/IMSI;
- private wrapper model/version/serial/UDID/IMEI family;
- `sysctlnametomib+sysctl` indirect route như test scenario.

### Matrix groups tối thiểu

- DeviceModel;
- HwModel nếu exposed;
- ProductVersion;
- ProductBuildVersion;
- SerialNumber;
- MLBSerialNumber;
- UDID/UUID group riêng đúng semantics;
- IMEI;
- IMEI2;
- MEID;
- IMSI.

### Test modes

1. full canonical profile;
2. whole group blank → no partial projection;
3. one field malformed → all surfaces group fail-open;
4. toggles off;
5. scope off;
6. generation swap.

### Merge gate

Phase B không bắt đầu trước khi A-06 pass.

### Execution evidence — T-0084 / A-06

- Extended `common/PXConsistencyMatrix.m` so the matrix now mirrors the live A-05 wrapper inventory more completely (`productVersion`, `osVersion`, `buildVersion`, `productType`, `deviceModel`, `deviceName`, `name`, `hostName`, `localHostName`, serial/UDID/IMEI/MEID families) and models the A-03 indirect `sysctlnametomib+sysctl` route for `kern.osversion`, `kern.osrelease`, `hw.machine`, and `hw.model`.
- Added standalone host integration harness `tests/PXPhaseAConsistencyGateTests.m` + Main. It cross-checks matrix values against the actual pure A-01 ManagedConfiguration resolver, A-02 CTServer overlay, and every non-keyed A-05 private-wrapper rule descriptor; keyed UIDevice-style dispatch is spot-checked through central MG/IORegistry ownership.
- Canonical mode asserts one value per consistency group and verifies all six ManagedConfiguration getters, all six CTServer fields, every allowlisted private-wrapper getter, and the indirect sysctl rows against their direct `sysctlbyname` peers.
- Negative modes cover whole-group blank (`SerialNumber`), missing field (`UDID`), malformed field (`IMEI` as non-string), `DeviceModel` toggle-off, process scope-off, and generation swap. Blank/missing/malformed groups are required to resolve either all surfaces or none, never a partial group.
- The generation-swap fixture uses a second format-valid identity set rather than suffixing UUID/IMEI strings; A-01/A-02/A-05 pure resolvers are re-run against generation 2 to detect stale caching. The `sf_uuidString -> IDFA` correction is explicitly included in the generation check.
- Updated `scripts/test_phase3_hooks_static.py` to pin the A-06 integration harness, indirect sysctl matrix rows, and explicit private-wrapper live scope gate (`PXProcessIsAllowedForSpoofing` / `PXPrivateIdentityProjectionContext`). Existing CTServer and ManagedConfiguration scope/toggle contracts remain pinned.
- `git diff --check` passed for tracked A-06 changes. `git diff --no-index --check` on the new test reported only the expected no-index exit status plus LF→CRLF warning, with no whitespace error output. Direct Python execution is still blocked by CatDesk `SHELL_MODE_BLOCKED`, so no executable Python/Foundation PASS is claimed in this environment.
- No production hook, injection scope, Security.framework surface, vendor anti-fraud selector pack, TLS behavior, or generic syscall/memory interception was added by A-06.

---

# 6. Phase B — Safe low-level JB/query parity

## B-00 — Central native query sanitizer foundation

### Mục tiêu

Tránh mỗi hook mới tự implement path blacklist/errno rules.

### Trước khi tạo file mới

Agent phải kiểm tra `PXP1AFilters/PXP1BFilters/PXP1CFilters` và helper trong `JailbreakBypassHooks.x`. Nếu đã có function đủ generic, reuse.

### Nếu cần helper mới

Tạo một layer kiểu:

- normalize path safely;
- classify hidden/suspicious path;
- helper return contracts theo API family;
- preserve errno rules;
- no side-effect mutation.

### Tests

Canonical jailbreak/rootless paths, normal app paths, symlink-ish strings, nil, relative path.

### Execution evidence — T-0085 / B-00

- Audited the existing `PXP1AFilters`, `PXP1BFilters`, `PXP1CFilters` and `JailbreakBypassHooks.x` before adding anything. The live tweak already had one strong filesystem-policy owner: path provenance resolution, rootless/private-preboot rules, hidden-path trie/corpus, write-probe rules, and a four-state allow/hide/deny-write/unresolved classifier.
- Reused `common/PXP1CFilters.{h,m}` instead of creating another sanitizer module. It now owns the pure operation/disposition model, lexical absolute-path normalization, absolute-base + relative-child joining, write-denial-vs-hidden precedence, and API-independent ENOENT/EACCES mapping.
- `JailbreakBypassHooks.x` still exclusively owns the hidden-path corpus and runtime provenance (`getcwd`, original `fcntl(F_GETPATH)`, dirfd resolution). It delegates only pure normalization/final-disposition/errno semantics to `PXP1CFilters`, so no duplicate blacklist or second path truth was introduced.
- Fixed an existing exact-fit normalization bug: a buffer of exactly `strlen(normalizedPath)+1` bytes is now accepted. The shared join helper also rejects an absolute child path so a caller cannot silently bypass the supplied base provenance.
- Extended `tests/PXP1CFiltersTests.m` with rootless, normal app, symlink-ish lexical, nil, relative-path, missing-provenance, exact-fit, hidden-read, denied-write, and unresolved/fail-open cases. Denied writes retain EACCES priority even when the same path is also hidden; hidden reads map to ENOENT; unresolved paths synthesize no errno and do not block.
- Extended `scripts/test_phase3_hooks_static.py` to prove the live classifier delegates to the common contract while its existing Cydia/rootless/private-preboot corpus remains in `JailbreakBypassHooks.x`. The same gate explicitly forbids the B-01 targets `__opendir2`, `fstat64`, `fstatat64`, and `fstatfs64` from landing during B-00.
- No new production hook or injection scope was added. The four existing sanitizer source files were first captured in baseline commit `fb4cb44` solely because they were untracked in the newly bootstrapped root Git history; B-00 behavior remains isolated in the subsequent diff.
- `git diff --check` passed with only the workspace LF→CRLF notices. Direct `python x-new/scripts/test_phase3_hooks_static.py` remains blocked by CatDesk `SHELL_MODE_BLOCKED`, so no executable static/Foundation PASS is claimed here.

---

## B-01 — Directory + stat64 exact query gaps

### Targets

- `__opendir2`
- `fstat64`
- `fstatat64`
- `fstatfs64`

### Nguyên tắc

- reuse existing path/FD classifier;
- normal targets → original;
- hidden target → mimic same failure contract as closest existing hook;
- preserve errno;
- no global FD corruption.

### Special note

FD-based calls cần provenance. Nếu không xác định FD path an toàn, fail-open thay vì đoán.

### Tests

normal file, hidden path, invalid fd, relative dirfd, rootless path.

### Execution evidence — T-0086 / B-01

- Added runtime-resolved `__opendir2`, `fstat64`, `fstatat64`, and `fstatfs64` hooks inside the existing `JailbreakBypassHooks.x` owner; no second native sanitizer module or path corpus was introduced.
- `__opendir2` uses the same `PXJBClassifyFilesystemPathAt` contract as `opendir`: hidden paths return `NULL` with `ENOENT`, normal/unresolved paths call the saved original with the caller's exact flags. Direct `__opendir2` streams join the existing directory-stream registry; nested calls reached from hooked `opendir` are reentrancy-suppressed, preventing double filtering/registration.
- Added one `PXJBClassifyFileDescriptorPath` helper that resolves provenance only through the already-approved original `fcntl(F_GETPATH)` path. `fstat` was mechanically refactored to this helper, and `fstat64` reuses the same hidden-FD `EBADF/-1` contract. Invalid/unresolvable FDs return `UNRESOLVED` and fail open to the real API.
- `fstatat64` mirrors the existing safer x-new `fstatat` behavior: absolute paths and relative paths with resolvable `dirfd` provenance use the central classifier; hidden targets return `ENOENT/-1`, while unresolved provenance falls through to original. This is intentionally safer than guessing a path from an invalid/unknown dirfd.
- `fstatfs64` uses coordinator-owned `PXStatfs64Buf` (Darwin `struct statfs` ABI), blocks a known hidden FD with `EBADF/-1`, otherwise calls original and preserves original errno across the same read-only filesystem flag normalization used by existing `fstatfs`.
- All four symbols are runtime/capability optional (`FindSymbol` + `MSHookFunction`, audit `required=false`) so legacy symbol absence cannot disable the master bypass or crash startup.
- Extended `PXP1CFiltersTests.m` with B-01 normal-path, rootless, relative-dirfd, hidden-read, and missing-provenance/fail-open fixtures. Extended both static parity gates so the four symbols are COVERED and their classifier/errno/original-fallback relationships are pinned.
- `git diff --check` passed for the B-01 source/test/static changes with only workspace LF→CRLF notices. `python3 x-new/scripts/test_phase3_hooks_static.py` was attempted from the workspace root and CatDesk rejected `python3` under `SHELL_MODE_BLOCKED`; therefore no executable Python/Foundation PASS is claimed in this environment.
- No B-02 attr/xattr/pathconf surface, generic `fcntl` hook, raw `syscall`, Security.framework falsification, TLS behavior, or injection-scope change was added by B-01.

---

## B-02 — `pathconf/fpathconf` + attr/xattr read surfaces

### Targets

- `pathconf`
- `fpathconf`
- `getattrlist`
- `fgetattrlist`
- `getxattr`
- `fgetxattr`
- `listxattr`
- `flistxattr`

### Mục tiêu

Chỉ đóng **read/query** path; chưa làm mutation APIs.

### Nguyên tắc

- hidden path/known hidden FD → return API-correct failure/sanitized result;
- normal path → untouched original;
- do not strip arbitrary xattrs on normal files;
- preserve size-query behavior (`NULL` buffer/length only) của xattr APIs.

### Tests

2-pass buffer sizing, ENOENT/EINVAL behavior, normal xattr unchanged, hidden path blocked.

### Execution evidence — T-0087 / B-02

- Added runtime-resolved read/query wrappers for `pathconf`, `fpathconf`, `getattrlist`, `fgetattrlist`, `getxattr`, `fgetxattr`, `listxattr`, and `flistxattr` inside the existing `JailbreakBypassHooks.x` owner. No xattr mutation API was installed.
- All eight wrappers reuse the B-00/B-01 central path or FD classifier. A request is synthesized as failure only after provenance resolves to a known hidden artifact; normal and unresolved provenance fail open to the saved original.
- Added pure `PXJBHiddenReadErrnoPolicy` / `PXP1CJBErrnoForHiddenRead` so B-02 errno families are explicit and host-testable: path reads use `ENOENT`, FD reads use `EBADF`, and iFake-compatible hidden `listxattr` uses `EPERM`.
- `PXJBRejectHiddenPathReadQuery` and `PXJBRejectHiddenFDReadQuery` save/restore the caller's incoming `errno` whenever the classifier does not block. This is required for POSIX `pathconf/fpathconf`, where `-1` may mean an indeterminate value and callers distinguish it by whether `errno` changed.
- `fpathconf` intentionally uses the correct POSIX ABI `long fpathconf(int fd, int name)`. The iFake `sub_2043FC` decompile was re-checked and demonstrably treats argument 2 as a C-string/path before forwarding it, so that observed ABI anomaly is documented evidence, not behavior copied into x-new.
- Attr/xattr wrappers pass caller buffers, sizes, positions, names and options unchanged to original and do no post-call mutation. Therefore `NULL`/zero-size sizing probes, normal two-pass buffer flows, ordinary xattr contents, and original `EINVAL`/other libc failures remain owned by the real API.
- `fgetattrlist` deliberately does not port iFake's `device_boottime` packed-attribute timestamp rewrite in B-02; this task is limited to safe hidden-artifact read/query parity and avoids changing metadata on normal files.
- All eight symbols are `FindSymbol`/`MSHookFunction` capability-optional and are audited with `required=false`, so OS/SDK symbol availability cannot disable the core bypass.
- Extended `PXP1CFiltersTests.m` with explicit ENOENT/EBADF/EPERM and unresolved/fail-open contracts. Extended both static parity gates to pin all eight installers and exact original argument forwarding; the static gate also forbids `setxattr`, `fsetxattr`, `removexattr`, and `fremovexattr` installers.
- `git diff --check` passed for the B-02 source/test/static changes with only workspace LF→CRLF notices. Direct `python3` execution remains blocked by CatDesk `SHELL_MODE_BLOCKED`, so no executable Python/Foundation PASS is claimed.
- No generic `fcntl` interception, raw `syscall`, Security.framework falsification, TLS change, xattr mutation hook, or injection-scope expansion was added by B-02.

---

## B-03 — `readdir_r` + process identity queries + socket peer surfaces

### Targets

- `readdir_r`
- `issetugid`
- `getgroups`
- `getpeername`
- `getsockname`

### `readdir_r`

Phải dùng cùng filter semantics với `readdir`; không thay đổi order của entry không bị hidden.

### `issetugid/getgroups`

Chỉ sanitize nếu existing jailbreak policy thật sự cần và iFake semantics đã xác nhận. Không hardcode identity process rộng nếu không cần.

### socket

`getpeername/getsockname` chỉ project/sanitize fields mà network profile đã quản lý. Không fake remote endpoints ngẫu nhiên.

### Tests

readdir/readdir_r same visible entry set; group query sizing; IPv4/IPv6 socket struct lengths preserved.

### Execution evidence — T-0088 / B-03

- Added runtime-resolved `readdir_r`, `issetugid`, `getgroups`, `getpeername`, and `getsockname` hooks to the existing jailbreak owner; all five are capability-optional and audited with `required=false`.
- `readdir_r` reuses the same tracked `DIR*` lifecycle and exact `PXJBDirectoryEntryShouldHide` predicate as `readdir`. Hidden entries are consumed internally in encounter order, while the caller's supplied `struct dirent` buffer and `*result` contract are preserved for the next visible entry, EOF, or original error. Filesystem reentrancy suppresses nested `readdir` filtering if libc implements `readdir_r` through `readdir`.
- Added pure `PXP1CJBCompactNonRootGroups`: it removes only GID `0`, compacts in place, and preserves relative order. The live `getgroups` wrapper calls original first and leaves `getgroups(0,NULL)`/errors unchanged; only a populated successful result is compacted when the existing JB policy is active.
- `issetugid` is deliberately narrower than iFake's unconditional hard-zero: x-new calls original first and only converts a real nonzero result to `0` while the existing JB policy is active. Normal `0` stays byte-equivalent to original.
- Added pure `PXP1CJBEndpointPortShouldHide` for exact iFake peer/local endpoint evidence: only host-order ports `27042` and `27043` qualify. `getpeername/getsockname` call original first, inspect only a sufficiently sized IPv4 `sockaddr_in`, and return `ENOTCONN/-1` for those two ports while leaving the returned address bytes and `socklen_t` untouched. IPv6, short buffers, and all other ports pass through unchanged.
- The peer/local socket rule is intentionally narrower than the existing `connect` denylist; B-03 does not fabricate arbitrary remote endpoints and does not extend the two-port iFake evidence to IPv6.
- Extended `PXP1CFiltersTests.m` with ordered group compaction, sizing/error passthrough, exact 27042/27043 positive fixtures, and ordinary-port negative fixtures. Extended both static parity gates to pin all five installers, original-first policy gates, the shared readdir matcher, IPv4 length/family gate, and absence of `*addressLength` mutation.
- `git diff --check` is the executable source-hygiene gate available in this environment. Direct Python/Foundation runners remain blocked/not configured by CatDesk, so no executable host-test PASS is claimed unless a runner succeeds during final verification.
- No PAC/TLS behavior, generic syscall/fcntl interception, Security.framework surface, arbitrary process-identity fabrication, or B-04+ surface was added by B-03.

---

## B-04 — PAC proxy API

### Target

`CFNetworkCopyProxiesForAutoConfigurationScript`

### Mục tiêu

Đồng bộ PAC-result surface với `CFNetworkCopySystemProxySettings` và proxy profile hiện tại.

### Rules

1. call original first nếu cần script evaluation contract;
2. only transform proxy entries managed by profile;
3. preserve array/dictionary shape and unknown keys;
4. preserve CF Create ownership;
5. no TLS behavior changes.

### Tests

DIRECT-only, HTTP proxy, SOCKS, malformed PAC, profile off, nil original.

### Execution evidence — T-0089 / B-04

- Extended the existing `TLinkIOSTweak/VPNDetectionBypass.x` owner rather than creating a second proxy-policy module. The new runtime-resolved target is exact `CFNetworkCopyProxiesForAutoConfigurationScript`; the existing `vpnDetectionBypassEnabled` + `PXProcessIsAllowedForSpoofing` gate remains the sole control plane.
- ABI is bound to the CFNetwork Copy contract `CFArrayRef (CFStringRef script, CFURLRef targetURL, CFErrorRef *error)`. The hook calls the saved original first with the exact three arguments and uses a thread-local recursion guard.
- x-new intentionally does not clone iFake `sub_20DF2C`'s unconditional synthetic one-entry result / blanket error clearing. Original missing, scope/toggle off, NULL result, non-NULL original error, non-array result, malformed proxy entries, or Objective-C projection exceptions all fail open to the exact original result/error contract.
- Added pure `TLinkIOSTweak/PXPACProxySanitizer.{h,m}`. For a well-formed enabled PAC array it preserves array cardinality, dictionary shape and unknown keys, rewrites each proxy dictionary's exact `kCFProxyTypeKey` value to iFake-compatible `direct`, and removes only known proxy endpoint/configuration/credential fields (`kCFProxyHostNameKey`, `kCFProxyPortNumberKey`, PAC URL/JavaScript, username/password). Disabled or malformed input returns the exact original object.
- CF Create ownership is explicit: a successful Foundation projection is converted with `CFBridgingRetain` to a new +1 `CFArrayRef`; only then is the original Copy-owned array released. Every fail-open path returns the original +1 object without releasing/replacing it.
- Added `PXPACProxySanitizerTests.m` + Main covering profile-off identity, nil original, DIRECT-only shape, HTTP and SOCKS projection, PAC URL/JavaScript stripping, unknown-key preservation, same cardinality, and malformed/non-array fail-open.
- Updated both static parity gates: PAC moved from `EXPECTED_MISSING_RAW` to COVERED, original-first/error/type/ownership relationships are pinned, and `SecTrust`, `serverTrust`, and `NSURLAuthenticationChallenge` remain forbidden in the VPN module. `SCIsRunningWithDebugger` remains the next exact expected gap.
- Tracked `git diff --check` passed with only LF→CRLF notices. `git diff --no-index --check` on the new/untracked B-04 files returned the expected no-index difference status and only LF→CRLF notices, with no whitespace-error output. Direct `python3` static execution remains blocked by CatDesk `SHELL_MODE_BLOCKED`, so no executable Python/Foundation PASS is claimed.
- No TLS/certificate behavior, injection scope, Security.framework hook, generic syscall/fcntl interception, or B-05+ surface was added by B-04.

---

## B-05 — Objective-C secondary surfaces

Tách thành các subchanges trong cùng Phase nhưng agent có thể làm từng commit nếu diff lớn.

### B-05a `NSThread`

- `callStackSymbols`
- `callStackReturnAddresses`

Rule: preserve array cardinality/shape. Prefer sanitize/hide only entries proven to belong to hidden injected image. Không trả empty blanket.

### B-05b `_LSCanOpenURLManager`

Target:

`canOpenURL:publicSchemes:privateSchemes:XPCConnection:error:`

Runtime class+selector existence check. Reuse central scheme/path detector. Non-target URL → original.

### B-05c `NSProcessInfo.arguments`

Filter only explicit instrumentation/JB markers already represented by central corpus. Preserve order.

### B-05d `NSBundle.preferredLocalizations`

Project same language/locale used by LocaleTimeZoneHooks, only when canonical locale setting valid.

### Tests

shape preservation, scope off, marker/no-marker, locale partial profile.

### Execution evidence — T-0090 / B-05

- Added count-preserving `NSThread.callStackReturnAddresses` / `callStackSymbols` sanitation to the existing `JailbreakBypassHooks.x` owner. Both call original first; when the JB policy is active, only frames whose address resolves through `dladdr` to an image accepted by the existing `PXJBShouldHideImageName` central corpus are redacted. Return-address elements become `NSNumber(0)` and symbol elements become a redacted `NSString`, preserving array cardinality and element class rather than copying iFake's frame removal / blanket-empty behavior.
- `callStackSymbols` parses the first hexadecimal address from the native symbol line and requires `dladdr` provenance before redacting. Unknown/malformed lines and normal images remain unchanged; no arbitrary substring-only stack filtering was added.
- Recovered `NSProcessInfo.arguments` behavior byte-exact from iFake `sub_E60D4`: the dedicated marker set is `jailbreak`, `dyld`, `roothide`, `theos`, `substrate`. x-new preserves iFake's direct `containsString:` case-sensitive semantics, preserves visible argument order, lazily allocates only after the first match, and returns the exact original array when disabled or when no marker matches.
- Recovered and centralized the exact 18-entry iFake `off_5E4498` URL/app-availability corpus (`activator`, `aptbackup`, `checkra1n`, `com.example.package`, `cydia`, `dopamine`, `filza`, `ifile`, `installer`, `palera1n`, `sileo`, `sileosdk`, `trollinstallerx`, `trollstore`, `unc0ver`, `undecimus`, `zbra`, `zebra`). Existing `UIApplication.canOpenURL:` now uses this shared lowercase/substring decision helper instead of a narrower local list.
- Added capability-optional `_LSCanOpenURLManager canOpenURL:publicSchemes:privateSchemes:XPCConnection:error:` interception. Installation requires runtime class/selector existence and a seven-argument Objective-C encoding compatible with the observed BOOL/object/object-pointer ABI before calling `MSHookMessageEx`. Matching schemes return `NO` without modifying the error out-parameter, matching iFake `sub_1EAF6C`; non-target URLs forward all original arguments unchanged.
- XOR replay for iFake `NSBundle.preferredLocalizations` confirmed config key `country_locale` and `-` splitting with first-component projection. x-new maps this to the existing LocaleTimeZone canonical owner instead of adding an iFake-specific config cache: first valid `targetRegionPinnedPreferredLanguages` entry wins, otherwise the language component of `targetRegionPinnedLocaleIdentifier` is used. Scope/target-region off or partial/invalid locale state returns the exact original array.
- Extended `PXP1CFiltersTests.m` for exact five-marker argv filtering, case sensitivity, visible-order preservation, the shared 18-fragment URL corpus, and cardinality-preserving call-stack replacement. Extended `PXLocaleRuntimeProjectionTests.m` for disabled, preferred-language, hyphen/underscore locale fallback, and partial-profile fail-open cases.
- Extended both static parity gates to pin the four B-05 surfaces, shared corpora, runtime ABI guard, call-stack provenance requirement, locale canonical source, and the no-blanket-empty call-stack rule.
- `git diff --check` passed for all ten B-05 source/test/static files with only LF→CRLF notices. Direct `python3 x-new/scripts/test_phase3_hooks_static.py` remains blocked by CatDesk `SHELL_MODE_BLOCKED`, so no executable Python/Foundation PASS is claimed.
- No Security.framework falsification, TLS/certificate behavior, generic syscall/fcntl interception, vendor anti-fraud selector pack, injection-scope expansion, or B-06+ surface was added by B-05.

---

## B-06 — Phase-B regression gate

### Mục tiêu

Chứng minh các query hook mới không phá normal app behavior.

### Matrix

Run at least:

1. spoof disabled;
2. spoof enabled full profile;
3. JB bypass disabled;
4. JB bypass enabled;
5. missing snapshot;
6. app extension;
7. WebKit helper process if in supported scope;
8. SpringBoard minimal mode remains minimal.

### Static assertions

Must remain absent:

- `syscall` generic hook;
- `sandbox_check` hook;
- generic `fcntl` replacement;
- dyld count/header/slide hooks;
- Security.framework blocked hooks.

### Execution evidence — T-0091 / B-06

- Added host-oriented `tests/PXPhaseBRegressionGateTests.m` + Main covering the required eight Phase-B modes without changing production behavior: spoof disabled, spoof enabled/full profile, JB bypass disabled, JB bypass enabled with launch-only installed-mask enforcement, missing snapshot, scoped app extension, supported WebKit helper, and SpringBoard minimal mode.
- The B-06 matrix reuses the canonical pure helpers rather than cloning hook logic: `PXP1CScopeBundleEnabled`, `PXP1CWebKitHostScoped`, `PXP1CSnapshotNeedsRefresh`, JB requested/effective/feature-mask helpers, `PXInjectionComputeTweakBundles`, `PXInjectionComputeBridgeBundles`, the existing B-05 argv/locale projection helpers, and the central filesystem disposition contract.
- Full-profile identity consistency, scope-off, missing/malformed canonical fields and generation swap remain owned by the A-06 integration fixture and are asserted as B-06 prerequisites, avoiding a second identity test model.
- Added `scripts/test_phase_b_regression_static.py`. It pins the eight matrix cases, WebKit host fail-closed behavior, app-extension/bridge injection rules, SpringBoard's early `return` before `PXIdentitySnapshotStartObserving`, ordinary WebKit native-hook exclusion, and the JB master launch gate.
- The B-06 static gate explicitly requires Security.framework falsification symbols to remain absent and forbids hook installation for generic `syscall`, `sandbox_check`, generic `fcntl`, dyld image count/header/slide, and `MSHookMemory`. It also asserts the PAC/VPN owner remains free of `SecTrust`, `serverTrust`, and `NSURLAuthenticationChallenge` behavior.
- Added `scripts/test_phase_b_regression_static.py` to `release_hardening.py`'s extended Python regression list so the gate participates in the release suite when a Python runner is available.
- `git diff --check` passed for tracked B-06/release changes with only LF→CRLF notices. `git diff --no-index --check` on each of the three new files reported only the expected no-index exit status plus LF→CRLF notices, with no whitespace error output.
- Direct `python3 x-new/scripts/test_phase_b_regression_static.py` remains blocked by CatDesk `SHELL_MODE_BLOCKED`, so no executable Python/Foundation PASS is claimed in this environment.
- B-06 added no production hook, no injection-scope expansion, no Security.framework/vendor anti-fraud/TLS behavior, and no generic syscall/memory interception.

---

# 7. Phase C — evidence-driven compatibility only

## C-01 — `SCIsRunningWithDebugger`

### Target

`SCIsRunningWithDebugger`

### Rule

Capability-gated framework scalar only. Runtime resolve, fail-open. Không kéo theo vendor anti-debug selector packs.

### Tests

symbol absent, scope off, capability off/on, original true/false fixtures.

### Execution evidence — T-0092 / C-01

- Local iFake evidence locks the target and semantics: `InitFunc_14` resolves exact `SCIsRunningWithDebugger` with `dlsym`/`MSHookFunction`; replacement `sub_1AD454()` is a zero-argument scalar that returns `0` unconditionally. x-new binds the runtime adapter as `Boolean (*)(void)` without importing a private declaration.
- Extended the existing `TLinkIOSTweak/JailbreakBypassHooks.x` owner only. C-01 adds no vendor class/selector table. The constructor uses existing `FindSymbol`/`RTLD_DEFAULT`; it does not `dlopen` SystemConfiguration, so an unloaded/absent symbol remains untouched.
- Added internal policy/capability pair `kPXJBPolicySCDebuggerScalar` / `kPXJBCapabilitySCDebuggerScalar`. The existing JB master automatically requests this generic framework capability, but `PXJBFinalizeCapabilityRegistryAndAudit` only places the bit in the installed/effective mask when the `SCIsRunningWithDebugger` trampoline is actually available. Missing symbol disables C-01 alone and does not fail the core JB capability.
- `hook_SCIsRunningWithDebugger` returns `0` only while the audited effective C-01 capability is active. If scope/master policy is disabled at runtime it calls the saved original unchanged; symbol absence means the hook is never installed.
- Added pure `PXP1CJBProjectedDebuggerState` plus `testC01DebuggerScalarProjection` cases for scope/master off, symbol-absent installed mask, audited capability ready, and original true/false projection behavior.
- Updated `test_ifake_parity_static.py`: `SCIsRunningWithDebugger` moved from the final unconditional raw expected-gap bucket into COVERED; the bucket is now empty. Updated `test_phase3_hooks_static.py` to pin the zero-argument Boolean ABI, runtime-only resolution, separate capability bit/audit, original fallback, tests, and no C-01 SystemConfiguration `dlopen`.
- `git diff --check` passed for the six C-01 source/test/static files with only LF→CRLF notices. Direct `python3 x-new/scripts/test_ifake_parity_static.py` remains blocked by CatDesk `SHELL_MODE_BLOCKED`, so no executable Python/Foundation PASS is claimed.
- No Security.framework falsification, TLS/trust change, generic syscall/sandbox/fcntl/dyld-cardinality hook, injection-scope expansion, or new vendor anti-debug selector pack was added by C-01.

---

## C-02 — `CFPropertyListCreateWithData` provenance-gated transformer

### Điều kiện để implement

Chỉ làm nếu fixture chứng minh SystemVersion/device plist đọc qua parser này đi ngoài các loader hooks hiện có.

### Rule

Không global transform mọi plist.

Cần provenance gate rõ, ví dụ thread-local marker do known SystemVersion read path đặt trước parser call, hoặc source context khác đủ chặt.

Reuse `PXSystemVersionTransformer`.

### Tests

normal arbitrary plist unchanged; SystemVersion fixture transformed; invalid plist original behavior.

### Execution evidence — T-0093 / C-02

- Re-audited the existing SystemVersion owners before adding any parser interception. `IOSVersionHooks.x` already hooks the path-bearing `NSData +dataWithContentsOfFile:`, `NSDictionary +dictionaryWithContentsOfFile:` and `NSString +stringWithContentsOfFile:encoding:error:` surfaces. For exact/rootless `SystemVersion.plist` provenance, the raw-data path calls `PXTransformSystemVersionData` before any downstream property-list parser sees the bytes. `Tweak.x` separately routes `CFCopySystemVersionDictionary` through the same `PXSystemVersionTransformer` and preserves CF Copy ownership.
- Exact iFake evidence was checked at `sub_B0ED8`: it calls the original `CFPropertyListCreateWithData`, accepts only dictionary results, mutable-copies them, then conditionally overlays a fixed encrypted key family when those keys/config values are present. The replacement itself exposes no path/source provenance gate. Cloning that key-only behavior globally would violate the x-new C-02 rule.
- Added `tests/PXCFPropertyListParityEvidenceTests.m` + standalone Main. The fixture feeds XML and binary SystemVersion-shaped data through the same path-qualified upstream transformer and then calls the exact `CFPropertyListCreateWithData` API. The parser observes canonical projected version/build/release values while the original plist format and unknown keys are preserved.
- The same fixture includes a generic app-owned plist containing the same `ProductVersion` / `ProductBuildVersion` / `ReleaseType` key family. Because it lacks canonical SystemVersion provenance, its raw bytes remain the exact original object and the exact CF parser returns the original values. This is a concrete counterexample to any content/key-only global parser hook.
- Malformed SystemVersion bytes remain the exact original `NSData` at the upstream transformer and are then allowed to fail through the native `CFPropertyListCreateWithData` error contract. Rootless `/var/jb/System/Library/CoreServices/SystemVersion.plist` is positively covered; `/tmp/SystemVersion.plist` is deliberately rejected as filename-only provenance.
- Added `scripts/test_c02_propertylist_evidence_static.py` to pin the upstream raw-data/dictionary/string loaders, direct `CFCopySystemVersionDictionary` ownership path, exact CF parser evidence fixture, generic same-key non-match, malformed fail-open behavior, and continued production absence of `CFPropertyListCreateWithData` interception. Added the script to `release_hardening.py`.
- Updated the iFake parity baseline with `EVIDENCE_GATED_ABSENT_RAW = ["CFPropertyListCreateWithData"]`. C-02 is therefore classified as an intentional evidence-gated omission, not an unconditional missing implementation.
- No failing fixture proved a parser-only SystemVersion/device-plist path that bypasses the existing path-bearing loaders. Since `CFPropertyListCreateWithData` receives data/options rather than a source path, adding a provenance marker solely to hook the parser would duplicate an already-effective upstream transform. **Decision: do not add the production parser hook.** Reopen only if a concrete lower-level read/mmap fixture bypasses the current loaders.
- Tracked `git diff --check` passed with only LF→CRLF notices; no-index checks on the three new C-02 files reported only the expected difference exit status plus LF→CRLF notices and no whitespace errors. Direct Python execution remains blocked by CatDesk `SHELL_MODE_BLOCKED`, so no executable Python/Foundation PASS is claimed.
- C-02 adds no production hook, no global plist rewriting, no injection-scope expansion, and no change to Security.framework, TLS/trust, or blocked low-level interception policy.

---

## C-03 — Native WebCore/OpenGL evidence task

### Candidates

- native `HTMLCanvasElement::toDataURL` symbol;
- `glReadPixels`;
- `glGetString`.

### Đây là 2-stage task

**Stage 1:** viết fixture chứng minh current JS/WebGL layer bị bypass.

**Stage 2:** chỉ khi Stage 1 fail thật mới implement runtime symbol hooks.

### Rules

- runtime symbol/version detection;
- default off;
- no crash when symbol mangled name differs;
- preserve GL error/state semantics.

Nếu Stage 1 không chứng minh gap → close task as “not needed”, không code hook.

### Execution evidence — T-0094 / C-03

- Added Stage-1 fixture `scripts/test_c03_native_webgl_evidence.js` for all three native candidates at the JavaScript-observable boundary: WebCore `HTMLCanvasElement::toDataURL`, `glGetString`-equivalent WebGL vendor/renderer/version pnames, and `glReadPixels`-equivalent RGBA/U8 client-memory output.
- The fixture extracts the actual injected script from `CanvasFingerprintHooks.x` rather than copying a second implementation. It requires the live `toDataURL`, `getParameter`, and `readPixels` wrappers plus their original-call/pass-through guards before executing the mock browser surface.
- Canvas export evidence preserves source canvas pixels and deterministic output while still invoking the backing `toDataURL` exactly once per call. Managed WebGL string pnames are projected before the backing getter; unmanaged pnames call the native backing exactly once.
- `readPixels` evidence requires the backing call exactly once, preserves the native return value, deterministically perturbs only the supported 7-argument `RGBA/UNSIGNED_BYTE` client buffer, preserves alpha bytes, and leaves unsupported format/type plus WebGL2-style overloads unchanged. This locks the observable GL error/state/pass-through boundary without installing a process-global GL hook.
- Added the C-03 fixture to `release_hardening.py` `NODE_TESTS`. Updated `test_ifake_parity_static.py` so native `HTMLCanvasElement::toDataURL`, `glReadPixels`, and `glGetString` remain explicit evidence-gated omissions and the Stage-1 fixture itself is pinned as a required parity artifact.
- Source audit confirms no production installer for the three native candidates. Direct `node x-new/scripts/test_c03_native_webgl_evidence.js` was attempted but CatDesk `SHELL_MODE_BLOCKED` rejects interpreter execution, so no executable Node PASS is claimed in this environment.
- Stage 1 therefore provides no evidence requiring a new native hook beyond the already-scoped JS/WebGL owner. **Decision: close C-03 as NOT NEEDED for current evidence; do not implement Stage 2.** Reopen only if an on-device fixture demonstrates a caller that bypasses the injected JavaScript/WebGL boundary.
- C-03 adds no production hook, no WebCore private-symbol dependency, no OpenGL process-global interception, no injection-scope expansion, and no change to TLS/Security/BLOCKED policy.

---

## C-04 — SBS/NX private symbols evidence task

Candidates:

- `SBSLaunchApplicationWithIdentifierAndURLAndLaunchOptions`
- `SBSLaunchApplicationWithIdentifierAndLaunchOptions`
- `NXMapGet`
- `NXHashGet`

Không implement chỉ để match iFake count. Cần concrete feature/test requirement.

### Execution evidence — T-0097 / C-04

- Re-audited the authoritative iFake semantics: the SBS launch pair is a private launch-result/blocking layer, while `NXMapGet` / `NXHashGet` are original-first lookup wrappers that consult the same central hidden-path detector and force hidden-context lookups to `0`.
- Re-audited current x-new product behavior. `SpringBoardLaunchHook.x` already owns launch/activation behavior at the Objective-C layer (`FBApplicationProcess`, `LSApplicationWorkspace`, `SBUIController`, `SBApplicationProcessManager`) and is explicitly SpringBoard-only. App-side launch call sites use `UIApplication` / `LSApplicationWorkspace`, not the two SBS C symbols.
- Re-audited generic jailbreak/runtime hiding. `JailbreakBypassHooks.x` already owns installed-application filtering, `_LSCanOpenURLManager`, `objc_copyClassNamesForImage`, and `class_getImageName` with the central hidden-image/path policy. No x-new source consumer or failing fixture demonstrates a lookup that reaches `NXMapGet` / `NXHashGet` while bypassing those narrower owners.
- Added `scripts/test_c04_sbs_nx_evidence_static.py` and wired it into `release_hardening.py`. The gate requires all four private candidates to remain absent from production while pinning the existing launch and JB/runtime owners.
- **Decision: C-04 CLOSED / EVIDENCE-GATED ABSENT.** The SBS launch pair is `DIFFERENT/OPTIONAL` because x-new already has a product-specific higher-level launch owner; `NXMapGet/NXHashGet` are `EVIDENCE-GATED ABSENT` because there is no concrete bypass fixture. Reopen only with an on-device failing case and **do not add production hooks** merely to match iFake raw count.
- This closure adds no private native hook, no SpringBoard injection expansion, no Security/TLS/attestation behavior, and no generic process-wide memory/string/syscall interception.

---

# 8. Phase D — optional product subsystems

Các task này không thuộc core parity merge gate.

## D-01 — Virtual camera subsystem

### Scope

- `AVCaptureVideoDataOutput setSampleBufferDelegate:queue:`
- runtime `captureOutput:didOutputSampleBuffer:fromConnection:`
- preview-layer integration
- optional `step:` lifecycle helper.

### Architecture

Module riêng, default-off, delegate-class dedupe, media-type check, processed-buffer fallback to original, correct retain/release.

Không trộn vào `Tweak.x` core identity.

---

## D-02 — Virtual microphone/audio

### Target

`AudioUnitRender`

### Rule

Separate capability from camera. Must preserve AudioUnit buffer counts/formats/timestamps. Original passthrough on unsupported format.

---

## D-03 — SpringBoard mouse bridge

Chỉ port 4 injected methods/functionality nếu product cần.

Module phải cực nhỏ; không kéo identity/JB/network stack vào SpringBoard.

Regression bắt buộc: app launch latency, SpringBoard responsiveness, orientation changes.

---

## D-04 — Safari private controller features

Chỉ khi product cần Safari automation/state restore.

Runtime class/selector resolution cho `BrowserRootViewController`, `TabDocument`, `BrowserWindowController`; fail-open trên iOS khác version.

Không dùng private Safari hooks để weaken certificate/TLS validation.

---

# 9. Mutation/high-risk native gaps — backlog không làm mặc định

Các API dưới đây chỉ mở task riêng khi có concrete failing fixture:

- `chdir`, `chroot`;
- `mkdir/mkdirat`;
- `chmod/fchmod/fchmodat`;
- `chown/fchown/fchownat`;
- `unlinkat`, `renameat`, `symlinkat`, `linkat`;
- `getfh`, `mknod`, `fchdir`, `execve`;
- `setxattr`, `removexattr`;
- `freopen`.

Không triển khai batch chỉ vì iFake có hook.

Các mục global process-wide sau giữ **do-not-implement** cho đến khi architecture review riêng:

- `syscall`;
- `sandbox_check`;
- generic `fcntl`;
- `read/pread/write/pwrite`;
- `ioctl`;
- `mmap/mprotect`;
- `strstr`;
- `vm_region_64`, `vm_region_recurse_64`, `mach_vm_read_overwrite`;
- `thread_get_state`, `task_for_pid`, `task_set_special_port`;
- `bootstrap_check_in`;
- generic XPC connection interception;
- dyld count/header/slide interception.

---

# 10. Test commands / gates agent phải dùng

## Static Phase-3 hooks

Từ `x-new`:

```sh
python scripts/test_phase3_hooks_static.py
```

Sau P0-00:

```sh
python scripts/test_ifake_parity_static.py
```

## Consistency matrix native test

Trên macOS toolchain:

```sh
clang -fobjc-arc -framework Foundation \
  -I common \
  common/PXConsistencyMatrix.m \
  common/PXSystemVersionTransformer.m \
  common/PXIdentitySnapshot.m \
  common/PXDeviceProfileSchema.m \
  tests/PXSystemVersionTransformerTests.m \
  tests/PXConsistencyMatrixTests.m \
  tests/PXConsistencyMatrixMain.m \
  -o /tmp/consistency-tests
/tmp/consistency-tests
```

Kỳ vọng exit code 0 và PASS log.

## Identity registry test

Follow command documented in `docs/Phase-3-kernel-hardware-hooks.md` for:

- `common/PXIdentitySurfaceRegistry.m`
- `tests/PXIdentitySurfaceRegistryTests.m`
- `tests/PXIdentitySurfaceRegistryMain.m`

## Release static gate

Sau mỗi Phase lớn chạy các static tests mà `scripts/release_hardening.py` liệt kê, đặc biệt Phase 2/3/4/5 identity + Lockdown tests.

Nếu local environment không có clang/Foundation, agent vẫn phải chạy static contracts và ghi rõ native test “not executable in this environment”; không được claim PASS giả.

---

# 11. Agent handoff format cho từng task

Khi giao một task, dùng format:

```text
Task: <ID + title>
Read first: x-new/iFakePro_vs_x-new_Agent_Implementation_Plan.md section <...>
Dependencies: <IDs>
Allowed files: <expected files; deviations must be explained>
Do not touch: BLOCKED surfaces from section 1.5
Goal: <observable surface>
Required tests: <list>
Done only when: <acceptance criteria>
Deliverable: code diff + test diff + short evidence report listing exact installed symbols/selectors and fallback behavior.
```

Agent phải báo riêng:

- files changed;
- hooks installed;
- hooks intentionally skipped because symbol/class absent;
- tests run + exact results;
- any ABI uncertainty;
- whether consistency matrix changed;
- whether a new injection scope was required (expected answer normally là NO).

---

# 12. Suggested execution order / ownership

## Sprint 1 — foundation + identity

1. P0-00 baseline.
2. P0-01 registry/matrix extension.
3. A-01 ManagedConfiguration.
4. A-02 CTServer.
5. A-03 sysctlnametomib.
6. A-04 locale/time C.
7. A-05 private wrapper dispatcher.
8. A-06 consistency gate.

Không chia A-01/A-02/A-05 cho nhiều agent song song **trước khi P0-01 merge**, vì cả ba sẽ chạm registry/matrix và dễ conflict.

Sau P0-01 merge, A-01/A-02/A-03/A-04 có thể chạy song song nếu mỗi agent không sửa cùng coordinator/registry rows; tốt nhất assign owner cho registry merge.

## Sprint 2 — low-level queries

1. B-00 helper foundation.
2. B-01/B-02/B-03/B-04 song song.
3. B-05 ObjC secondary.
4. B-06 regression.

## Sprint 3 — compatibility

1. C-01.
2. C-02 only with evidence.
3. C-03/C-04 research fixtures; implementation conditional.

## Sprint 4 — optional product features

D-01..D-04 chỉ mở nếu product requirement xác nhận.

---

# 13. Final audit task

Sau khi Phase A + B hoàn tất, chạy lại full comparison với golden iFake inventory và cập nhật:

- `iFakePro_vs_x-new_Hook_Gap_Assessment.md`;
- bảng exact native gaps còn lại;
- crosswalk InitFunc_0..20;
- count không dùng như success metric, nhưng phải giải thích mọi remaining exact gap.

Expected final classification:

- core identity gaps Phase A → COVERED hoặc STRONGER/DIFFERENT;
- safe Phase-B query gaps → COVERED;
- high-risk/native mutation → intentionally gated/absent;
- Security/anti-fraud/TLS/daemon → BLOCKED;
- camera/mic/mouse/Safari → OPTIONAL unless product enabled.

Final report phải chứng minh **observable consistency**, không chỉ liệt kê số hook đã tăng.

### Execution evidence — T-0095 / FINAL

- Re-ran the golden crosswalk against the post-Phase-A/B/C source state and updated `iFakePro_vs_x-new_Hook_Gap_Assessment.md` in place rather than appending a contradictory historical summary. InitFunc_2/7/14/17/18 rows now reflect actual implemented/evidence-gated status.
- Phase A is classified complete for the approved core observable surfaces: six ManagedConfiguration getters, CTServer V1/V2, `sysctlnametomib`, C locale/time and the allowlisted private-wrapper dispatcher all share the canonical snapshot/registry/fail-open architecture.
- Recomputed InitFunc_18 exact non-Security gaps from the original 63-symbol baseline. Phase B closed exactly 18 safe/query symbols; the remaining exact inventory is **45 = 24 file/path + 7 attr/process + 14 Mach/IPC/dyld**. Ordinary internal calls to `write`, `fcntl` or dyld getters are explicitly not counted as hook coverage.
- The remaining 45 are now classified as side-effect/evidence-gated or high-risk/process-global, not unfinished safe Phase-B work. Five Security.framework falsification symbols remain BLOCKED/raw-absent.
- C-02 `CFPropertyListCreateWithData` and C-03 native WebCore/OpenGL trio remain explicit evidence-gated omissions; C-01 `SCIsRunningWithDebugger` is covered. Optional media/SpringBoard mouse/Safari/SBS-NX families remain optional and outside core parity closure.
- Added `scripts/test_ifake_final_crosswalk_static.py`: it pins the 18 Phase-B closures, asserts the 45 unique remaining symbols have no production hook installer while permitting ordinary internal calls, asserts the four C-02/C-03 evidence-gated symbols stay production-absent, asserts all five blocked Security symbols stay absent, and pins the final report arithmetic/classification. Added this gate to `release_hardening.py`.
- Final negative source audit continues to show no generic `syscall`/`sandbox_check` hook, no generic variadic `fcntl` replacement, no dyld count/header/slide hook, no Security.framework falsification, no TLS/trust weakening and no C-03 native WebCore/OpenGL installer.
- Executable Python/Node/Foundation tests cannot be run in the current CatDesk allowlist shell because interpreter execution is blocked (`SHELL_MODE_BLOCKED`); no executable PASS is claimed. Source/static contract review plus `git diff --check` are the available verification level for this final audit.
