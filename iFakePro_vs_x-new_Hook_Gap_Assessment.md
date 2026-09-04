# iFakePro vs x-new — Exhaustive Hook Gap Assessment

> Mục tiêu: dùng inventory iFakePro đã khóa làm golden set, đối chiếu với source hiện tại của `x-new`, xác định hook nào **đã có**, **có theo cách khác**, **còn thiếu nên bổ sung**, hoặc **có trong iFake nhưng không nên port**.
>
> Phạm vi của báo cáo này là **đánh giá / crosswalk**, chưa sửa source `x-new`.

---

## 1. Kết luận chính — trạng thái sau Phase A/B/C evidence

`x-new` hiện đã đóng các **core observable gaps** được chọn từ golden inventory mà không sao chép wholesale kiến trúc iFake. Phase A đã bổ sung ManagedConfiguration, CTServer V1/V2, `sysctlnametomib`, C locale/time và generic private-wrapper dispatcher trên cùng canonical snapshot/registry. Phase B đã bổ sung nhóm low-level query an toàn (`__opendir2`, stat64, pathconf, attr/xattr read, `readdir_r`, process/socket queries), PAC proxy và secondary ObjC surfaces. C-01 đã bổ sung `SCIsRunningWithDebugger` theo capability; C-02/C-03 kết thúc bằng **evidence-gated omission** vì fixture không chứng minh cần global parser/native WebCore/OpenGL hook.

Golden comparison cuối cho thấy:

1. **Core identity Phase A: COVERED/DIFFERENT** — 6 ManagedConfiguration getters, 2 CTServer variants, `sysctlnametomib`, `localtime/localtime_r/setlocale` và allowlisted private-wrapper fan-out đều đã có canonical projection + fail-open.
2. **Safe Phase-B native queries: COVERED** — 18/63 InitFunc_18 non-Security exact gaps ban đầu đã được đóng bằng query-only/capability-gated adapters; 45 exact symbols còn lại chủ yếu là side-effect mutation hoặc process-global/high-risk primitives.
3. **Secondary ObjC/PAC: COVERED/DIFFERENT** — call stack giữ cardinality, `_LSCanOpenURLManager`, `NSProcessInfo.arguments`, `NSBundle.preferredLocalizations` và PAC proxy đều đã có narrower/shared-policy implementation.
4. **SC anti-debug scalar: COVERED** — `SCIsRunningWithDebugger` đã có runtime capability audit + master/JB policy gate.
5. **`CFPropertyListCreateWithData`: EVIDENCE-GATED ABSENT** — SystemVersion bytes đã được transform ở path-bearing upstream owners; generic same-key plist fixture chứng minh global parser rewrite là quá rộng.
6. **Native WebCore/OpenGL trio: EVIDENCE-GATED ABSENT / NOT NEEDED CURRENTLY** — current scoped Canvas/WebGL script covers JS-observable `toDataURL`, GL string pnames và `readPixels`; Stage-1 evidence không kích hoạt native Stage 2.
7. **SBS/NX C-04: CLOSED / EVIDENCE-GATED-OPTIONAL** — không có production hook; launch behavior đã có owner lớp cao hơn, còn NX chỉ mở lại với failing on-device fixture. Camera/microphone, Safari private controller và SpringBoard mouse vẫn là optional product features.
8. **BLOCKED vẫn BLOCKED** — 5 Security.framework falsification hooks, vendor anti-fraud selector batches, TLS weakening, sensitive-daemon injection, attestation/AMFI/pairing/Activation Lock và generic process-global syscall/string/memory interception không có evidence.

Vì vậy parity còn lại không còn là “thiếu core identity”, mà chủ yếu là **intentional exact-symbol gaps** nơi x-new chọn safety/ABI stability/provenance thay vì raw hook-count parity.

---

## 2. Golden set iFake dùng để so sánh

Nguồn chuẩn:

- `iFakePro_Hooks_Analysis.md`
- `iFakePro_Full_Hook_List.md`
- `iFakePro_ObjC_Hook_Callsite_Inventory.md`

### 2.1. Số lượng chính xác

| Cơ chế | iFake inventory | Ghi chú |
|---|---:|---|
| Constructor-direct `MSHookMessageEx` | **784** | 17 constructor có direct ObjC hook |
| Runtime CLLocation delegate | **5** | thuộc main path |
| Main ObjC path | **789 = 784 + 5** | locked |
| Optional runtime camera delegate | **+1** | chỉ cài khi điều kiện camera/delegate thỏa |
| ObjC call-site thực nếu optional camera được cài | **790** | 789 main + 1 optional |
| `MSHookFunction` | **158** | exact constructor/call-site inventory |
| `class_addMethod` | **5** | 4 mouse + 1 preview-layer `step:` |
| `MSHookMemory` | **1 installer path** | có thể patch nhiều runtime match |

Lưu ý: `iFakePro_Full_Hook_List.md` chốt **790 ObjC call-site thực** khi tính optional camera, còn main inventory được khóa ở **789**. Không dùng 790 như main count để tránh double-count optional path.

### 2.2. Native constructor counts

- InitFunc_2: 27
- InitFunc_4: 2
- InitFunc_7: 3
- InitFunc_14: 1
- InitFunc_17: 7
- InitFunc_18: 117
- InitFunc_19: 1

Tổng = 158.

---

## 3. Thang trạng thái dùng trong crosswalk

- **COVERED** — x-new có cùng entry point hoặc surface tương đương rõ ràng.
- **STRONGER/DIFFERENT** — x-new không clone iFake nhưng có coordinator/dispatcher rộng hoặc an toàn hơn.
- **PARTIAL** — có phần lớn chức năng nhưng còn đường gọi khác đi vòng qua.
- **MISSING-ADD** — thiếu và nên bổ sung nếu mục tiêu là fingerprint/JB parity.
- **OPTIONAL-FEATURE** — chỉ nên thêm nếu muốn feature tương ứng (camera, mouse, Safari automation...).
- **BLOCKED** — iFake có nhưng x-new policy hiện tại chủ động không cho port.
- **HIGH-RISK-GATED** — có thể nghiên cứu nhưng không nên cài global mặc định.

---

## 4. Crosswalk toàn bộ InitFunc_0 ... InitFunc_20

| iFake constructor | Inventory iFake | x-new hiện tại | Đánh giá / hành động |
|---|---|---|---|
| **InitFunc_0** | `MSHookMemory` dynamic added-image scanner/patcher | Có dyld lifecycle/add-image blocker nhưng không `MSHookMemory` clone | **HIGH-RISK-GATED**. Không cần port mặc định; chỉ dùng khi có detector binary cụ thể không thể xử lý bằng symbol/ObjC hook. |
| **InitFunc_1** | Xây central FS detector: ~227 prefix + 23 exact path; không direct hook | `JailbreakBypassHooks.x` có matcher/path filtering riêng | **COVERED/DIFFERENT**. Nên hợp nhất semantic/path corpus nếu có marker iFake mà x-new chưa có; không cần copy installer. |
| **InitFunc_2** | 218 ObjC + 27 native device/env | Core identity + ManagedConfiguration + CTServer + sysctlnametomib + C locale/time + generic private wrapper dispatcher đã có; `CFPropertyListCreateWithData` giữ evidence-gated absent | **COVERED/DIFFERENT cho core observable surface**. Parser-only exact gap là intentional omission sau C-02. Chi tiết §5/§7. |
| **InitFunc_3** | 11 direct CLLocation + 5 runtime delegates | x-new có location spoof và đủ 5 delegate selector: `didUpdateLocations`, legacy update, enter/exit region, heading | **COVERED/DIFFERENT**. Cần semantic regression, không cần clone installer. |
| **InitFunc_4** | 23 ObjC OS/plist/process + 2 SBS launch native | `IOSVersionHooks`, `UserDefaultsHooks`, JB `NSProcessInfo.environment`... phủ phần lớn; một số loader/process selectors còn thiếu; exact SBS C symbols intentionally absent sau C-04 nhưng launch behavior đã có higher-level owner | **PARTIAL / DIFFERENT**. Bổ sung loader/process có chọn lọc; không cần private SBS hook nếu chưa có failing fixture. |
| **InitFunc_5** | 4 MobileSafari private class hooks | Không thấy exact `BrowserRootViewController`, `TabDocument`, `BrowserWindowController` hooks | **OPTIONAL-FEATURE**. Chỉ port nếu cần Safari automation/restore/cert UI behavior; không phải identity core. |
| **InitFunc_6** | 15 SpringBoard/UI + 4 mouse `class_addMethod` | x-new cố ý SpringBoard minimal init (`Tweak.x` ~4297+) để tránh freeze; không thấy 4 mouse methods | **OPTIONAL-FEATURE / architecture conflict**. Không port toàn bộ stack vào SpringBoard. |
| **InitFunc_7** | 20 WebKit ObjC + 3 native canvas/OpenGL | WK/UIWebView/Canvas/WebGL scoped JS layer đã có; exact native `HTMLCanvasElement::toDataURL`, `glReadPixels`, `glGetString` vẫn vắng mặt có chủ ý | **COVERED/DIFFERENT + EVIDENCE-GATED ABSENT**. C-03 Stage 1 không chứng minh JS/WebGL bypass, nên không cài process-global native hooks. |
| **InitFunc_8** | 118 SDK anti-JB/tamper selectors | x-new có generic JB stack, không clone hàng loạt SDK-specific classes | **PARTIAL by design**. Generic detector parity nên giữ; anti-fraud-specific targeting **BLOCKED**. |
| **InitFunc_9** | 24 SDK detector selectors | Không clone exact app SDK classes | **BLOCKED/NOT REQUIRED** nếu selector nhằm anti-fraud-specific bypass. Generic jailbreak/passcode/biometric semantics có thể xử lý ở framework-safe layers. |
| **InitFunc_10** | 2 GULNetwork debug selectors | Không thấy exact | **OPTIONAL**, thấp ưu tiên; tránh vendor-specific hardcoding nếu generic debug state đủ. |
| **InitFunc_11** | 5 SSO/Keychain access-group/IDFA config selectors | x-new có Keychain bridge/identity handling theo kiến trúc riêng | **DIFFERENT/PARTIAL**. Không cần clone vendor classes; kiểm tra access-group consistency qua bridge. |
| **InitFunc_12** | 1 `PAGDeviceHelper` JB selector | Không thấy exact | **BLOCKED/NOT REQUIRED** nếu app/anti-fraud-specific. |
| **InitFunc_13** | 26 SDK root/VPN/fresh-install selectors | x-new generic JB/VPN stack | **PARTIAL by design**. Không port vendor-specific selector family. |
| **InitFunc_14** | 125 anti-debug/anti-fraud/IDFA/etc ObjC + `SCIsRunningWithDebugger` | Generic security stack + capability-gated `SCIsRunningWithDebugger` đã có; exact vendor targets vẫn không port | **Framework scalar COVERED; ObjC vendor part BLOCKED by design**. |
| **InitFunc_15** | 6 SDK detector selectors | Không exact | **BLOCKED/NOT REQUIRED** vendor-specific. |
| **InitFunc_16** | 4 SDK detector selectors | Không exact | **BLOCKED/NOT REQUIRED** vendor-specific. |
| **InitFunc_17** | 180 Foundation/FS ObjC + 7 native | Foundation/FS coverage rộng; Phase B đã thêm call-stack, `_LSCanOpenURLManager`, argv/localization và safe query companions; C-04 giữ SBS/NX private symbols intentionally absent | **STRONG PARTIAL / EVIDENCE-GATED-OPTIONAL remainder**. Core query gaps đã đóng; SBS có higher-level owner, NX chỉ mở lại với failing fixture. |
| **InitFunc_18** | 117 native anti-JB/system | Phase B đóng 18/63 non-Security exact gaps ban đầu; còn **45 non-Security exact-symbol gaps + 5 Security gaps** | **PARTIAL by design**. 45 gap còn lại chủ yếu side-effect/high-risk/global; 5 Security **BLOCKED**. Chi tiết §8. |
| **InitFunc_19** | 2 direct camera ObjC + optional runtime camera delegate + `AudioUnitRender` + `step:` | Không thấy exact media substitution path | **OPTIONAL-FEATURE**, P1 nếu mục tiêu sản phẩm cần virtual camera/mic. |
| **InitFunc_20** | cleanup/no direct hook | N/A | Không có gap cần port. |

=> Tất cả **21 constructor** đã được đưa vào crosswalk; không bỏ qua constructor “không hook” vì chúng vẫn có thể cung cấp detector/installer state.

---

## 5. P0/P1 — Device identity gaps nên xử lý trước

### 5.1. ManagedConfiguration private getters — **COVERED / A-01**

Sáu symbol `MCCTIMEI`, `MCIOSerialString`, `MCProductVersion`, `MCProductBuildVersion`, `MCGestaltGetProductName`, `MCGestaltGetDeviceUUID` hiện được runtime-resolve trong `ManagedConfigurationIdentityHooks.x`. Projection lấy từ `PXCurrentIdentitySnapshot` + central surface registry, có scope/toggle gate, typed original fallback và không cần daemon injection. Host/static contracts khóa cả positive, missing, scope-off, toggle-off và generation-change semantics.

### 5.2. CoreTelephony server dictionary — **COVERED / A-02**

`_CTServerConnectionCopyMobileEquipmentInfo` và V2 hiện được hook original-first. x-new giữ đúng shape-oriented contract: chỉ overlay các field iFake đã chứng minh khi key thực sự tồn tại, giữ unknown keys, giữ nguyên status/original dictionary ownership và không synthesize IMEI2 field không có trong source dictionary.

### 5.3. `sysctlnametomib` — **COVERED / A-03**

`sysctlnametomib` hiện do `PXNativeHookCoordinator` sở hữu cùng `sysctl/sysctlbyname`. Adapter giữ transparent name→MIB semantics, buffer/errno contract và không fabricate MIB; consistency tests khóa indirect `sysctlnametomib → sysctl` với direct `sysctlbyname` cho các key canonical.

### 5.4. C runtime locale/time — **COVERED / A-04**

`localtime`, `localtime_r` và `setlocale` hiện nằm trong `LocaleTimeZoneHooks.x` và dùng cùng canonical locale/timezone source với Foundation/CF/WebKit. `localtime_r` giữ caller buffer/return semantics; `setlocale(category, NULL)` query không bị mutate, explicit locale giữ nguyên, chỉ canonicalize môi trường locale ở nhánh input phù hợp và luôn fail-open.

### 5.5. `CFPropertyListCreateWithData` — **EVIDENCE-GATED ABSENT / C-02 CLOSED**

iFake có exact parser hook, nhưng C-02 evidence cho thấy x-new đã transform SystemVersion ở các path-bearing upstream owners (`NSData`/`NSDictionary`/`NSString` loaders và `CFCopySystemVersionDictionary`) trước khi parser downstream quan sát dữ liệu. XML/binary SystemVersion fixtures nhận canonical values, còn generic app-owned plist có cùng key family vẫn giữ nguyên; malformed bytes giữ native parser failure contract.

**Decision:** không thêm global `CFPropertyListCreateWithData` hook. Reopen chỉ khi fixture cụ thể chứng minh một lower-level read/mmap path bypass toàn bộ provenance-bearing owners hiện tại.

### 5.6. Private/SDK identity fan-out — **COVERED/DIFFERENT / A-05**

iFake InitFunc_2 có ~98 private/SDK wrapper call-site, nhưng x-new không clone hàng chục vendor replacements. `PrivateIdentityWrapperHooks.x` dùng một capability-gated dispatcher với explicit class+selector allowlist, runtime method-encoding validation, class/metaclass provenance, system-image ownership check, late-load handling và dedupe.

Allowlisted generic/system surfaces gồm các key/getter family như `deviceInfoForKey:`, `sf_productType`, `sf_serialNumber`, `sf_udidString`, `sf_uuidString`, `applicationDSID`, `MLBSerialNumber`, IMEI/IMEI2/MEID/UDID/serial wrappers và AMS `_iOSComponent*` getters khi binary/source registry chứng minh mapping. `sf_uuidString` đã được sửa byte-exact sang canonical **IDFA** sau khi replay config key `ads_tracking`.

Secure Element/PassKit/trusted-enrollment selectors, class quá generic `Device` và vendor anti-fraud classes vẫn **không được allowlist**. Đây là intentional safety boundary, không phải implementation omission cần raw-count parity.

---

## 6. Objective-C/Foundation parity gaps

### 6.1. Những family x-new đã phủ mạnh

Search source hiện tại xác nhận:

- `LSApplicationWorkspace`: `allInstalledApplications`, `installedApplications`, `allApplications` (`JailbreakBypassHooks.x` ~3902+).
- `NSFileHandle` (`~3961+`).
- `UIImage` (`~4012+`).
- `NSFileWrapper` (`~4576+`).
- `NSFileVersion` (`~4622+`).
- `NSProcessInfo.environment` (`~3762+`).
- `NSProcessInfo.operatingSystemVersion` và `operatingSystemVersionString` (`IOSVersionHooks.x` ~855+, ~937+).
- `NSUserDefaults.objectForKey:` / KVC selector-specific UUID handling (`UserDefaultsHooks.x` ~165+, ~375+).
- Location runtime delegates đủ 5 iFake callbacks (`Tweak.x` ~2279, 2339, 2606, 2635, 2663).
- CoreMotion data objects và `CMMotionManager` có typed spoofing (`Tweak.x` ~3150+ / ~3240+).

Do đó không nên nhìn vào count iFake rồi thêm duplicate hooks vào các family này.

### 6.2. Secondary ObjC status sau Phase B

Các surface ưu tiên trước đây hiện đã **COVERED/DIFFERENT**:

- `NSThread.callStackReturnAddresses` / `callStackSymbols`: original-first, chỉ redact frame có `dladdr` provenance trỏ vào hidden image; giữ cardinality và element class thay vì hard-empty/remove như iFake.
- `_LSCanOpenURLManager canOpenURL:publicSchemes:privateSchemes:XPCConnection:error:`: runtime class/selector + exact arity/type gate; dùng shared 18-fragment URL corpus và không mutate error out-param khi block.
- `NSProcessInfo.arguments`: dùng đúng 5 marker iFake đã recover (`jailbreak`, `dyld`, `roothide`, `theos`, `substrate`), case-sensitive và giữ visible order.
- `NSBundle.preferredLocalizations`: projection từ canonical LocaleTimeZone owner, fail-open khi scope/profile không hợp lệ.

Các exact ObjC variants còn vắng như `NSCharacterSet.characterSetWithContentsOfFile:/URL:` và một số `NSAttributedString` file/HTML URL loaders được giữ **P2/evidence-gated**. SystemVersion/plist behavior hiện ưu tiên path-bearing transformer thay vì mở rộng blanket loader/parser hooks.

### 6.3. Remaining ObjC action

Không còn P1 secondary ObjC backlog từ Phase B. Chỉ mở thêm `NSCharacterSet`/`NSAttributedString`/loader variants nếu detector fixture cụ thể chứng minh current filesystem/path-bearing owners bị bypass; vendor/private anti-fraud class families vẫn BLOCKED.

---

## 7. Native parity — exact gaps

### 7.1. InitFunc_2 device/env — post-Phase-A exact status

Trong 13 exact gaps ban đầu:

- **12 đã COVERED**: `sysctlnametomib`; 6 ManagedConfiguration getters; `localtime`, `localtime_r`, `setlocale`; `_CTServerConnectionCopyMobileEquipmentInfo` V1/V2.
- **1 vẫn exact-absent có chủ ý**: `CFPropertyListCreateWithData`, classified **EVIDENCE-GATED ABSENT** sau C-02 vì path-bearing SystemVersion transforms đã đóng observable parser path mà không cần global content-based hook.

Cùng với IOKit trio, `uname`, `sysctl/sysctlbyname`, MobileGestalt, `getifaddrs`, Wi‑Fi/reachability, CF timezone và Lockdown đã có từ trước, device/env core observable surface hiện không còn unconditional implementation gap trong baseline.

### 7.2. InitFunc_7 WebKit/OpenGL — 3 exact native omissions, evidence-gated

- WebCore `HTMLCanvasElement::toDataURL` native symbol path
- `glReadPixels`
- `glGetString`

C-03 Stage-1 fixture lấy **actual injected script** từ `CanvasFingerprintHooks.x` và kiểm tra JS-observable boundary cho cả ba family. Current scoped layer giữ canvas source pixels, deterministic export, configured GL string projection và original-first `readPixels` buffer semantics; unsupported format/type/overload pass-through. Fixture không chứng minh bypass cần native process-global hook.

**Status:** `EVIDENCE-GATED ABSENT / NOT NEEDED CURRENTLY`. Không implement Stage 2; reopen chỉ với on-device failing fixture.

### 7.3. InitFunc_14 — framework scalar COVERED

`SCIsRunningWithDebugger` hiện được runtime-resolve/capability-audit trong JB owner với exact `Boolean(void)` adapter. Khi master/effective capability active nó projects false; ngoài scope/policy/capability thì gọi original. Vendor anti-debug ObjC selector families vẫn BLOCKED.

### 7.4. InitFunc_17 native — **C-04 CLOSED / EVIDENCE-GATED ABSENT**

Bốn unique exact private symbols vẫn intentionally absent:

- `SBSLaunchApplicationWithIdentifierAndURLAndLaunchOptions`
- `SBSLaunchApplicationWithIdentifierAndLaunchOptions`
- `NXMapGet`
- `NXHashGet`

**SBS launch pair:** iFake dùng private C layer để chặn/giả launch result. x-new đã có product-specific launch owner ở lớp cao hơn trong `SpringBoardLaunchHook.x`: SpringBoard-only hooks cho process launch, `LSApplicationWorkspace openApplicationWithBundleID:`, URL opening và activation. App-side launch paths cũng dùng `UIApplication` / `LSApplicationWorkspace`. Vì vậy exact SBS C symbols là **DIFFERENT/OPTIONAL**, không phải core parity blocker.

**NXMapGet/NXHashGet:** iFake gọi original lookup rồi dùng central hidden-path detector để ép hidden-context lookup về `0`. x-new đã có installed-app filtering, `_LSCanOpenURLManager`, `objc_copyClassNamesForImage`, `objc_copyImageNames`, `class_getImageName` và central path/image policy ở các narrower observable surfaces. Không có source consumer hay failing fixture chứng minh một detector hiện tại đi qua NX lookup và bypass các owner này.

T-0097 thêm static evidence gate để 4 private candidates tiếp tục absent khỏi production và pin các owner hiện tại. **Decision:** không thêm production hooks; reopen chỉ khi on-device fixture chứng minh concrete SBS/NX bypass. Hai SBS symbol vẫn chỉ count một unique symbol pair dù iFake có nhiều installer call-site.

### 7.5. InitFunc_19 — 1 exact native gap

- `AudioUnitRender`

Chỉ thêm khi feature virtual microphone/audio substitution nằm trong product scope.

---

## 8. InitFunc_18 — 117 native hooks: exact x-new comparison

`iFakePro_Full_Hook_List.md` khóa InitFunc_18 ở **117/117**: 112 non-Security + 5 Security.framework.

### 8.1. x-new đã có nhiều surface tương đương

Hiện source có các family như:

- stat/lstat/access/open/openat/fopen
- opendir/readdir
- readlink/realpath
- connect/getaddrinfo
- getenv/system/popen
- ptrace/fork/vfork/csops
- uid/gid/ppid
- posix_spawn/posix_spawnp
- statfs/getfsstat coordinator
- fstat/fstatat/faccessat/readlinkat
- symlink/rename/link/unlink/rmdir
- getmntinfo
- `CFNetworkCopySystemProxySettings`
- bootstrap lookup
- xpc pipe
- task_info
- dlopen/dlsym/dladdr/dlopen_preflight
- dyld image-name sanitation
- runtime class/image-name hiding

### 8.2. **45 non-Security exact symbol gaps remain after Phase B**

Baseline had 63 exact non-Security InitFunc_18 symbol gaps. Phase B closed exactly 18 query-safe gaps:

`__opendir2`, `fstat64`, `fstatat64`, `fstatfs64`, `pathconf`, `fpathconf`, `getattrlist`, `fgetattrlist`, `getxattr`, `fgetxattr`, `listxattr`, `flistxattr`, `readdir_r`, `getpeername`, `getsockname`, `issetugid`, `getgroups`, `CFNetworkCopyProxiesForAutoConfigurationScript`.

The remaining **45 exact-symbol gaps** are below. Source audit distinguishes hook installation from ordinary internal calls (for example x-new may call `write`, `fcntl` or dyld getters without intercepting those entry points).

#### File/FS/path — 24

- `syscall`
- `read`
- `chdir`
- `chroot`
- `mkdir`
- `chmod`
- `chown`
- `getfh`
- `mknod`
- `unlinkat`
- `mkdirat`
- `renameat`
- `symlinkat`
- `linkat`
- `fchmodat`
- `fchownat`
- `pread`
- `pwrite`
- `fchmod`
- `fchown`
- `write`
- `fchdir`
- `execve`
- `freopen`

#### Attr/xattr/process/network — 7

- `ioctl`
- `setxattr`
- `removexattr`
- `mmap`
- `mprotect`
- `fcntl`
- `strstr`

#### Mach / IPC / dyld — 14

- `vm_region_64`
- `vm_region_recurse_64`
- `mach_vm_read_overwrite`
- `bootstrap_check_in`
- `sandbox_check`
- `xpc_connection_create_mach_service`
- `xpc_connection_create`
- `thread_get_state`
- `task_for_pid`
- `task_set_special_port`
- `_dyld_shared_cache_contains_path`
- `_dyld_image_count`
- `_dyld_get_image_vmaddr_slide`
- `_dyld_get_image_header`

Count = **24 + 7 + 14 = 45**.

### 8.3. Classification of the remaining 45

#### SIDE-EFFECT / EVIDENCE-GATED — do not add merely for count parity

- `chdir`, `chroot`
- `mkdir`, `mkdirat`
- `chmod`, `fchmod`, `fchmodat`
- `chown`, `fchown`, `fchownat`
- `unlinkat`, `renameat`, `symlinkat`, `linkat`
- `getfh`, `mknod`, `fchdir`, `execve`
- `setxattr`, `removexattr`
- `freopen`

These operations mutate process/filesystem state or have nontrivial failure semantics. They remain exact-symbol gaps until a concrete detector fixture demonstrates a safe, provenance-qualified need. Normal operations must never be fake-succeeded/failed just to resemble iFake.

#### HIGH-RISK-GATED — intentionally no process-global installer

- `read`, `pread`, `pwrite`, `write`
- `ioctl`
- `mmap`, `mprotect`
- `fcntl`
- `strstr`
- `syscall`
- `sandbox_check`
- `vm_region_64`, `vm_region_recurse_64`, `mach_vm_read_overwrite`
- `thread_get_state`, `task_for_pid`, `task_set_special_port`
- `bootstrap_check_in`
- `xpc_connection_create_mach_service`, `xpc_connection_create`
- `_dyld_shared_cache_contains_path`
- `_dyld_image_count`, `_dyld_get_image_vmaddr_slide`, `_dyld_get_image_header`

Final source/static audits preserve the important negative contracts: generic `syscall` and `sandbox_check` remain unhooked variadic entry points; `fcntl` is resolved only for verified internal `F_GETPATH` calls and is not intercepted; dyld count/header/slide may be read internally but are not hooked, preserving cardinality/index identity; vm/task/memory/xpc broad interception remains evidence-gated. These are intentional architecture choices, not unfinished Phase-B work.

### 8.4. 5 Security.framework exact gaps — **BLOCKED**

- `SecTaskCopyValueForEntitlement`
- `SecCodeCopySigningInformation`
- `SecStaticCodeCreateWithPath`
- `SecStaticCodeCheckValidity`
- `SecStaticCodeCheckValidityWithErrors`

Đây là parity gap nhưng **không nên port**. `x-new/new-plan.md` dòng ~7 và ~152–159 / ~511–520 cấm attestation, AMFI/code-signing, entitlement falsification và anti-fraud targeting.

---

## 9. MobileGestalt: x-new không thiếu, thậm chí rộng hơn iFake ở ABI surface

Không nên kết luận “x-new cần thêm MobileGestalt” chỉ vì iFake có resolver/obfuscated key path.

x-new hiện đã có MobileGestalt coordinator và các đường:

- `MGCopyAnswer`
- `MGCopyAnswerWithError`
- `MGCopyMultipleAnswers`
- bool/alternate projected answer paths
- mapping key canonical vào profile

Trong khi iFake có resolver fan-out nhiều encrypted lookup → same canonical logical key, x-new gom ở coordinator. Đây là ví dụ điển hình cho việc **1 hook x-new có thể thay nhiều iFake call-site**.

Điểm cần làm là mở rộng **key parity + wrapper parity**, không copy số hook.

---

## 10. IOKit, uname/sysctl, Lockdown, network: phần đã mạnh

### IOKit

x-new có đủ coordinator cho:

- `IORegistryEntryCreateCFProperty`
- `IORegistryEntrySearchCFProperty`
- `IORegistryEntryCreateCFProperties`

Không có gap chính ở installer; chỉ cần tiếp tục parity key/value.

### uname

x-new hook `uname` và project nhiều field (`sysname`, `release`, `version`, `nodename`, `machine`) thay vì chỉ một field. Không nên thêm duplicate hook.

### Lockdown

`LockdownIdentityHooks.x` có map identity/software keys (`UniqueDeviceID`, `SerialNumber`, `MLBSerialNumber`, `ProductVersion`, ...). `lockdown_copy_value` đã có surface. Không nên inject lockdown daemon để mimic iFake; giữ app-side controlled path.

### Network/Wi‑Fi

`getifaddrs`, `CNCopyCurrentNetworkInfo`, reachability, Wi‑Fi identity và `CFNetworkCopySystemProxySettings` đã có/được coordinator. Gap nổi bật còn lại là PAC proxy function.

---

## 11. WebKit/Canvas — observable coverage strong; native trio intentionally absent

### iFake

- 20 WebKit ObjC hooks.
- 3 native WebCore/OpenGL hooks.

### x-new sau C-03

- WKWebView/legacy web UA handling.
- Scoped Canvas fingerprint script wrapping `HTMLCanvasElement.toDataURL`/`toBlob` and 2D readback-related behavior.
- WebGL `getParameter` projection for vendor/renderer/version-style pnames.
- Original-first `readPixels` projection for the supported RGBA/U8 client-memory shape, with unsupported overloads pass-through.
- C-03 fixture extracts and exercises the actual production script; no separate mock implementation is treated as evidence.

No Stage-1 evidence proved that observable web fingerprinting bypasses these owners, so native WebCore private symbol + `glReadPixels` + `glGetString` remain **EVIDENCE-GATED ABSENT**. This avoids iOS-build-fragile/private process-global hooks until a device fixture demonstrates necessity.

---

## 12. Camera/microphone — feature gap rõ nhưng không phải identity core

### iFake

- `AVCaptureVideoDataOutput setSampleBufferDelegate:queue:`
- runtime `captureOutput:didOutputSampleBuffer:fromConnection:`
- `AVCaptureVideoPreviewLayer addSublayer:`
- injected `step:` method
- `AudioUnitRender`

### x-new

Không thấy exact surface trên trong `TLinkIOSTweak`.

Nếu mục tiêu của x-new có virtual camera/mic thì đây là **một subsystem thiếu hoàn chỉnh**, không phải thêm 1–2 hook lẻ. Nên làm module riêng, lifecycle/dedupe đúng, passthrough khi media type không phù hợp, retain/release sample buffer đúng và capability default-off.

Nếu product không cần media substitution thì để OPTIONAL.

---

## 13. SpringBoard/Safari — không copy wholesale

### SpringBoard

iFake có 15 hook UI/system + 4 injected mouse methods. x-new `Tweak.x` hiện chủ động dùng **SpringBoard minimal init** vì full spoof stack gây app launch chậm/freeze.

=> Không nên lấy “iFake có” làm lý do inject toàn bộ vào SpringBoard. Nếu cần mouse bridge thì tách 4 method vào module cực nhỏ, không kéo device/JB/network stack theo.

### Safari

iFake có 4 private Safari hooks. x-new có Safari/WebKit data handling và scope riêng nhưng không clone private controller methods.

=> Chỉ port khi cần đúng feature Safari control/state restore; không phải requirement để đạt core fingerprint parity.

---

## 14. Những hook iFake **không nên** mang sang x-new

Theo `x-new/new-plan.md`:

1. 5 Security.framework entitlement/code-signing hooks.
2. Attestation/DeviceCheck/App Attest bypass.
3. AMFI/code-signing/entitlement falsification.
4. Vendor/anti-fraud-specific selector targeting (InitFunc_8–16 rows nào thuộc anti-fraud-specific).
5. TLS/certificate weakening.
6. Sensitive-daemon injection / copy iFake 40 bundles + 34 executables wholesale.
7. Pairing/trust/Activation Lock modifications.
8. Global `strstr` marker interception chỉ để che 155 marker — quá rộng, dễ phá logic app; thay bằng provenance-specific filtering.
9. Generic `read/write/mmap/mprotect/syscall` interception process-wide nếu chưa có exact capability/test target.

---

## 15. Khác biệt kiến trúc injection scope rất quan trọng

iFake dùng fixed filters rộng, bao gồm nhiều bundle/executable hệ thống. `x-new` hiện theo user-selected/global scope + app extensions/WebKit helpers, và cố ý tránh sensitive-daemon injection.

Điều này có nghĩa:

- Một hook iFake chạy trong daemon có thể thấy giá trị trước app.
- Cùng hook copy vào x-new nhưng tweak không inject daemon thì **không tạo cùng behavior**.
- Giải pháp đúng của x-new là ưu tiên app-side API interception/coordinator, không mở rộng filter sang daemon chỉ để đạt raw count parity.

Đây là lý do báo cáo phân loại theo **observable surface** thay vì chỉ so số `MSHookFunction`/`MSHookMessageEx`.

---

## 16. Implementation status after the planned parity work

### Phase A — COMPLETE

ManagedConfiguration, CTServer V1/V2, `sysctlnametomib`, C locale/time, generic private-wrapper dispatcher and the cross-surface consistency gate are complete.

### Phase B — COMPLETE for the approved safe surface

Directory/stat64, pathconf/fpathconf, attr/xattr read queries, `readdir_r`, process/socket queries, PAC proxy, secondary ObjC surfaces and the Phase-B regression gate are complete. The remaining 45 InitFunc_18 exact symbols are intentionally outside the approved query-safe Phase-B set.

### Phase C — COMPLETE for current evidence

1. `SCIsRunningWithDebugger`: implemented capability-gated.
2. `CFPropertyListCreateWithData`: evidence task closed **without hook**; upstream provenance-bearing SystemVersion owners are sufficient for current fixtures.
3. Native WebCore/OpenGL trio: evidence task closed **without native hooks**; current scoped JS/WebGL boundary covers the tested observable paths.
4. SBS/NX private symbols: C-04 evidence task closed **without production hooks**. The SBS launch pair is DIFFERENT/OPTIONAL because x-new already owns launch behavior above the private C layer; `NXMapGet/NXHashGet` remain evidence-gated absent until an on-device bypass fixture exists.

### Phase D — OPTIONAL / not part of core parity closure

1. Virtual camera/sample-buffer/preview layer.
2. `AudioUnitRender` virtual mic/audio.
3. SpringBoard mouse bridge isolated module.
4. Safari private controller features.

### Keep blocked

Security.framework falsification, attestation/AMFI/anti-fraud/TLS/sensitive-daemon paths and generic global syscall/string/memory interception without concrete evidence.

---

## 17. Verification requirements khi triển khai từng gap

Mỗi hook mới nên có cùng checklist:

1. **Resolve audit**: symbol/class/selector tồn tại hay không; không có thì không crash.
2. **Original passthrough**: profile/key/gate không hợp lệ → original 100%.
3. **Type/ABI**: đúng ownership và return type (CF Create/Copy ownership, ObjC object lifetime, struct size, variadic restrictions).
4. **Cross-surface consistency**: cùng field phải giống nhau ở MobileGestalt, Lockdown, uname/sysctl, MC/CT/private wrappers.
5. **Scope**: chỉ app/process được chọn; không mở rộng daemon mặc định.
6. **No cardinality corruption**: đặc biệt dyld arrays/count/header, callstack arrays, app lists.
7. **No global string rewriting**: marker filtering phải có provenance/context.
8. **Runtime tests**: enabled/disabled, missing profile field, partial profile, WebKit helper, app extension, SpringBoard minimal mode.
9. **Static gate**: test script phải assert cả hook install lẫn intentional omission.
10. **Compatibility telemetry**: log capability installed/absent, không log secret identity plaintext nếu không cần.

---

## 18. Final classification after T-0095 audit

### COVERED / completed approved parity

- 6 ManagedConfiguration getters.
- 2 CTServer MobileEquipmentInfo variants.
- `sysctlnametomib`.
- `localtime/localtime_r/setlocale`.
- Generic allowlisted private identity wrapper layer.
- Safe native FS/stat64/pathconf/attr/xattr query set approved in Phase B.
- `readdir_r`, `issetugid`, `getgroups`, `getpeername`, `getsockname`.
- PAC proxy API.
- `NSThread` callstack, `_LSCanOpenURLManager`, `NSProcessInfo.arguments`, `NSBundle.preferredLocalizations`.
- `SCIsRunningWithDebugger`.
- Existing strong surfaces: MobileGestalt, IOKit, uname/sysctl, Lockdown, location delegates, CoreMotion, major Foundation JB/file, dyld image-name lifecycle, Wi‑Fi/reachability/network.

### EVIDENCE-GATED ABSENT / closed as not needed for current fixtures

- `CFPropertyListCreateWithData` global parser interception.
- native WebCore `HTMLCanvasElement::toDataURL`.
- `glReadPixels`.
- `glGetString`.
- `NXMapGet`.
- `NXHashGet`.

These are not unconditional backlog items; reopening requires a concrete failing fixture that bypasses the narrower current owner. For `NXMapGet/NXHashGet`, the required evidence is an on-device detector path that escapes current app-list/runtime-image/path owners.

### OPTIONAL / product-feature remainder

- virtual camera/microphone (`AVCapture*`, preview/sample-buffer path, `AudioUnitRender`).
- isolated SpringBoard mouse bridge.
- Safari private UI/controller hooks.
- SBS launch private C pair (`SBSLaunchApplicationWithIdentifierAndURLAndLaunchOptions`, `SBSLaunchApplicationWithIdentifierAndLaunchOptions`) — DIFFERENT/OPTIONAL because higher-level launch ownership already exists.
- `MSHookMemory` dynamic patcher.
- remaining side-effect filesystem mutations only if a concrete detector needs them.

### HIGH-RISK-GATED / intentionally absent

- generic `syscall`, `sandbox_check`, variadic `fcntl` interception.
- global `read/write/pread/pwrite`, `mmap/mprotect`, `ioctl`, `strstr` interception.
- broad vm/task/xpc/dyld-cardinality hooks listed in §8.2.

### BLOCKED / do not port

- 5 Security.framework falsification hooks.
- anti-fraud-specific selector batches.
- TLS/certificate weakening.
- sensitive-daemon injection.
- attestation/AMFI/pairing/Activation Lock paths.

---

## 19. Độ tin cậy / giới hạn của kết luận

- iFake side dùng locked inventories, gồm full ObjC call-site inventory và full native inventory; không suy từ tài liệu cũ rút gọn.
- x-new side dùng **source hiện tại**, không dùng các docs stale làm ground truth. Ví dụ source `VPNDetectionBypass.x` hiện có implementation dù report cũ từng nói file rỗng.
- `x-new/Makefile` dùng wildcard cho `TLinkIOSTweak/*.x`, nên các module `.x` hiện tại nằm trong build surface.
- Một exact symbol không xuất hiện trong x-new được ghi là **exact gap**, không tự động suy rằng behavior hoàn toàn thiếu; coordinator/wrapper equivalents được tách riêng.
- Không cố ép một con số “ObjC missing = N” giả tạo vì iFake có hàng trăm app/SDK-specific call-site còn x-new dùng generic dispatch/coordinator. Crosswalk theo toàn bộ 21 constructor + behavior family chính xác hơn cho quyết định kỹ thuật.

**Bottom line sau final audit:** Phase A và phần safe của Phase B đã được triển khai; Phase C hiện cũng đã đóng theo evidence: C-01 implement scalar framework, C-02/C-03 giữ parser/WebCore/OpenGL absent có chủ ý, và C-04 giữ SBS/NX private symbols absent với taxonomy tách bạch (SBS = higher-level DIFFERENT/OPTIONAL; NX = EVIDENCE-GATED ABSENT). Các exact gaps còn lại không còn là một lớp core identity compatibility cần port hàng loạt: chúng được phân loại thành 45 InitFunc_18 side-effect/high-risk exact-symbol omissions, 5 Security.framework BLOCKED hooks, evidence-gated parser/WebCore/OpenGL/NX omissions và optional product-feature families. x-new hiện gần iFake hơn ở các đường fingerprint/JB observable quan trọng nhưng vẫn giữ deliberate boundaries về ABI, provenance, TLS/Security và injection scope.
