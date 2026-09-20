# iFakePro vs x-new — Backlog hợp nhất theo mức ưu tiên

## 1. Phạm vi và nguồn đối chiếu

Báo cáo này hợp nhất hai lần đối chiếu:

1. Danh sách `GenerateCC generate -> dyldCode` và bảng hook ở các mục 11–13, tập trung vào MobileGestalt, IOKit, UIDevice, Telephony, Location, LaunchServices, Apple private identity, User-Agent/header, push token và các hook theo ứng dụng.
2. Báo cáo `iFakePro_Hooks_Analysis.md`, bao phủ toàn bộ 21 constructor `InitFunc_0…InitFunc_20`, 789 hook Objective-C theo đường chính, 158 hook C/native, các hook runtime, `class_addMethod` và phạm vi inject daemon.
3. Mã nguồn x-new hiện tại trong `TLinkIOSTweak`, `common`, `Tests/tests` và các static contract trong `scripts`.

Đây là backlog theo **hành vi quan sát được**, không phải yêu cầu sao chép số lượng hook. Một owner/coordinator của x-new có thể thay thế nhiều call-site iFakePro; ngược lại, có symbol hook nhưng thiếu key/selector hoặc sai semantics vẫn được tính là chưa hoàn chỉnh.

## 2. Quy ước ưu tiên

| Mức | Ý nghĩa |
|---|---|
| **P0** | Đường đọc phổ biến có thể trả dữ liệu thật hoặc làm hồ sơ thiết bị tự mâu thuẫn. Nên xử lý trước. |
| **P1** | Tăng độ phủ đáng kể cho fingerprinting/compatibility nhưng không phải đường lõi trong mọi ứng dụng. |
| **P2** | Tính năng sản phẩm hoặc compatibility theo ứng dụng; chỉ làm khi có nhu cầu/fixture cụ thể. |
| **EVIDENCE-GATED** | Không thêm chỉ để đạt hook-count parity; cần failing fixture trên thiết bị trước. |
| **DO NOT PORT** | Rủi ro bảo mật/ổn định cao hoặc nằm ngoài phạm vi identity spoofing an toàn. |

## 3. Những phần đã có — không nên tạo hook trùng

x-new đã có owner hoặc hành vi tương đương cho các nhóm sau:

- `sysctl`, `sysctlbyname`, `sysctlnametomib`, `uname` và boot-time projection.
- Ba API IOKit: `IORegistryEntryCreateCFProperty`, `IORegistryEntrySearchCFProperty`, `IORegistryEntryCreateCFProperties`.
- `getifaddrs`, `CNCopyCurrentNetworkInfo`, reachability, proxy settings và phần lớn Wi-Fi identity.
- `statfs/statvfs`, disk-total/free-space và storage projection.
- Public IDFA/IDFV, ATT status/request path.
- ManagedConfiguration 6 getter và CoreTelephony server V1/V2.
- UserDefaults selective projection, OS version, locale/timezone và `preferredLocalizations`.
- Location coordinate + năm delegate callback chính.
- Accelerometer, gyro, magnetometer, `CMDeviceMotion`, `CMAttitude`, async handlers và `CMAltimeter` callback.
- Foundation/JB coverage chính: file/path, app enumeration, URL scheme, call stack và runtime image-name filtering.
- `SCIsRunningWithDebugger`, nhiều libc/dyld/JB query hook an toàn và 31 rule detector SDK phổ biến.
- Canvas/WebGL ở biên JavaScript-observable.

Các nhóm trên chỉ cần mở rộng key/selector hoặc sửa semantics được nêu bên dưới; không nên cài thêm một hook owner thứ hai.

## 4. P0 — nên bổ sung trước

### P0-01 — Mở rộng MobileGestalt key parity có kiểu dữ liệu

**Hiện trạng:** x-new đã có `MGCopyAnswer`, `MGCopyAnswerWithError`, `MGCopyMultipleAnswers` và bool path, nhưng registry MobileGestalt chính chỉ ánh xạ trực tiếp một tập key hẹp. Danh sách thứ nhất cho thấy một resolver lớn hơn nhiều; báo cáo thứ hai cũng xác nhận MobileGestalt là một surface trung tâm.

**Nên bổ sung trước:** các key đã có nguồn canonical rõ ràng và có thể giữ đúng kiểu trả về:

- `MLBSerialNumber`, `UniqueChipID` và các alias String/Data hợp lệ.
- `InternationalMobileEquipmentIdentity2`, `IMSI`, `ICCID`, phone/subscriber identifiers khi profile thật sự có dữ liệu.
- Wi-Fi/Bluetooth/Ethernet MAC và Data variants dùng chung canonical MAC owner.
- `RegionCode`, `RegionInfo`, carrier bundle/subscriber codes dùng chung region/carrier snapshot.
- Baseband version/serial/unique-id nếu x-new đã có trường profile tương ứng.
- Main-screen width/height/pitch, marketing name, screen dimensions khi có typed device-spec snapshot.
- Battery serial/capacity và các hardware serial chỉ khi có nguồn profile độc lập, không alias nhầm sang device serial.

**Tác dụng:** đóng đường đọc phổ biến nhất của private framework; tránh tình trạng `UIDevice` trả hồ sơ giả nhưng `MGCopyAnswer` vẫn lộ model, chip, carrier hoặc hardware identity thật.

**Yêu cầu triển khai:** map qua `PXIdentitySurfaceRegistry`, giữ đúng `CFString`/`CFData`/`CFNumber`/`CFBoolean`, missing field phải gọi original, và cùng logical key phải dùng chung snapshot/toggle với IOKit/private wrapper.

**Tiêu chí hoàn thành:** test table-driven cho từng key, alias, kiểu ABI, toggle-off, missing-field và `MGCopyMultipleAnswers` mixed known/unknown keys.

### P0-02 — Khóa tính nhất quán IDFA/IDFV/LaunchServices/private identity

**Hiện trạng:** public `ASIdentifierManager`, `UIDevice.identifierForVendor` và ATT đã có. Danh sách thứ nhất còn dùng:

- `LSApplicationWorkspace.deviceIdentifierForVendor/Advertising`.
- `LSApplicationProxy.deviceIdentifierForVendor/Advertising`.
- Các wrapper AA/AK/AMS/DMF/IC/IS/SS/CT.

x-new đã có allowlist private-wrapper khá tốt, nhưng chưa phủ hết LaunchServices identity và một số selector/alias trong danh sách đầu.

**Nên bổ sung:** LaunchServices IDFA/IDFV selectors nếu tồn tại runtime; rà và bổ sung chỉ các wrapper có semantics ánh xạ sạch sang `IDFA`, `IDFV`, `UDID`, serial, IMEI/MEID, model, OS/build và device name.

**Tác dụng:** ngăn cùng process quan sát hai advertising/vendor ID khác nhau qua API public và LaunchServices/private SDK; đây là lỗi consistency dễ bị fingerprinting phát hiện.

**Yêu cầu triển khai:** runtime class/selector/type gate, allowlist tường minh, original-first/fail-open, không synthesize selector không tồn tại trên OS thật.

**Không bao gồm:** Secure Element/PassKit SEID, attestation, entitlement hoặc payment identity.

### P0-03 — Hoàn thiện Location direct surface và sửa semantics callback

**Đã có:** `CLLocationManager.setDelegate:`, `CLLocation.coordinate` và năm callback runtime.

**Còn thiếu exact selector:**

- `CLLocationManager.delegate`, `location`, `heading`.
- `CLLocationSourceInformation.isSimulatedBySoftware`, `isProducedByAccessory`.
- `CLHeading.headingAccuracy`, `trueHeading`.
- `CLRegion.center`, `containsCoordinate:`.

**Semantic cần sửa/ra quyết định:** x-new hiện suppress enter/exit-region trong khi iFakePro forward callback; heading callback hiện passthrough thay vì dùng cùng heading snapshot giả.

**Tác dụng:** đóng các đường polling trực tiếp bỏ qua callback và làm location/heading/region/source-info đồng nhất. Đặc biệt quan trọng với app vừa đọc `manager.location` vừa nghe delegate.

**Yêu cầu triển khai:** dùng chung location snapshot và jitter generation; một update phải tạo cùng coordinate/heading cho getter và callback; OFF/out-of-scope phải giữ nguyên object/arguments.

### P0-04 — Bổ sung Pedometer và direct altitude data getters

**Hiện trạng:** motion sensor chính và `CMAltimeter` callback đã được xử lý, nhưng chưa thấy exact hook cho `CMPedometerData` và direct `CMAltitudeData` getters.

**Nên bổ sung:**

- 13 getter `CMPedometerData`: active time, steps, distance, pace, cadence, floors, elevation, pushes, workout type…
- `CMAltitudeData.pressure` và `relativeAltitude`.

**Tác dụng:** tránh app đọc dữ liệu vận động/độ cao thật hoặc dữ liệu không khớp với GPS/location giả. Đây cũng là nguồn fingerprint theo hành vi thiết bị.

**Yêu cầu triển khai:** dữ liệu deterministic theo profile/session thay vì random độc lập mỗi getter; giữ timestamp, pointer/object semantics và tính đơn điệu của step/distance/active-time.

### P0-05 — Đóng VPN manager và discovery side channels

**Hiện trạng:** x-new đã có VPN/network detection bypass tổng quát, reachability và network-type projection. Tuy nhiên chưa thấy exact family:

- `NEVPNManager.sharedManager`, `loadedManagers`, `connection`, `isEnabled`.
- `NETunnelProviderManager.loadAllFromPreferencesWithCompletionHandler:`.
- `NEVPNConnection.status`.
- `MCNearbyServiceBrowser` browse methods.
- `CBCentralManager.scanForPeripheralsWithServices:options:`.
- `NSNetServiceBrowser` search methods.

**Tác dụng:** ngăn app suy ra VPN/tunnel hoặc môi trường thiết bị qua manager discovery, Bluetooth, Multipeer và Bonjour dù network status/reachability đã được spoof ở lớp khác.

**Yêu cầu triển khai:** capability riêng, default-off cho discovery suppression; completion callback phải được gọi đúng queue/cardinality; không trả trạng thái giả mâu thuẫn với NWPath/reachability hiện tại.

## 5. P1 — độ phủ cao, nên làm sau P0

### P1-01 — Device/process scalar còn thiếu

| Surface | Tác dụng khi bổ sung |
|---|---|
| `NSProcessInfo.activeProcessorCount` | Đồng nhất với `processorCount`, `hw.ncpu` và `hw.availcpu`; tránh lộ CPU topology thật. |
| `UIScreen.brightness` | Đóng fingerprint/UI telemetry nếu profile thực sự quản lý brightness. |
| `AVAudioSession.outputVolume` | Đồng nhất audio environment; chỉ nên có toggle riêng và original fallback. |
| `SKStorefront.countryCode` | Đồng nhất Storefront với locale, SIM/carrier và target region. |
| LS advertising/vendor selectors | Phần consistency của P0-02 nếu class chỉ tồn tại trên một số OS. |
| Status-bar network KVC | Chỉ cần nếu có fixture chứng minh app đọc private status-bar surface. |

Không nên sao chép behavior random/hardcode của iFakePro. Các giá trị phải đến từ canonical profile hoặc giữ original.

### P1-02 — WebKit Objective-C parity

**Nên xem xét bổ sung:**

- `WKWebView.init`, `initWithFrame:`, `initWithCoder:`, `dealloc` lifecycle.
- `_userAgent`, `_customUserAgent`, `_setCustomUserAgent:`.
- `evaluateJavaScript:completionHandler:` nếu cần giữ JS injection sau navigation/runtime reset.
- `WKWebpagePreferences` UA path và `WKPreferences` feature path khi có fixture.
- Legacy `WebView`/`UIWebView` chỉ nếu product còn hỗ trợ app cũ.

**Tác dụng:** giữ User-Agent, injected JS và WebKit fingerprint projection nhất quán trên nhiều initializer/private path; tránh một webview được tạo qua coder/plain-frame bỏ qua owner hiện tại.

**Không thuộc P1:** native WebCore/OpenGL hooks được giữ evidence-gated ở mục 7.

### P1-03 — Foundation loader variants

**Nên bổ sung có chọn lọc:**

- `NSCharacterSet.characterSetWithContentsOfFile:/URL:`.
- Các `NSAttributedString` file/URL/HTML loaders có path-bearing input.
- Một số dictionary/data/string loader variant chỉ khi chúng đi vòng qua transformer hiện tại.

**Tác dụng:** đóng các đường đọc file/plist/JB artifact gián tiếp mà `NSFileManager` hoặc current path transformer có thể không quan sát.

**Yêu cầu:** path-provenance trước khi lọc; không blanket-hook parser theo nội dung.

### P1-04 — User-Agent và HTTP header consistency

Danh sách thứ nhất có nhiều `setValue:/addValue:` path theo Apple daemon và app. x-new đã có UA/WebKit/NSURLRequest handling nhưng chưa clone toàn bộ exact call-site.

**Nên bổ sung:** một transformer header dùng chung cho `NSMutableURLRequest`, request builders và WebKit navigation, chỉ áp dụng trong scoped app/helper hiện có.

**Tác dụng:** đồng nhất iOS version, model, hardware platform và build trong UA/header với hồ sơ hệ thống; tránh UA thật xuất hiện ở request được tạo ngoài WKWebView.

**Không nên:** mở rộng injection sang `accountsd`, `appstored`, `identityservicesd`, `storekitd` chỉ để giống filter iFakePro.

### P1-05 — Random-MAC private manager paths

**Còn thiếu đáng chú ý từ danh sách thứ nhất:**

- `WFNetworkListRandomMACManager.setRandomMAC:forNetwork:enabled:shouldAlwaysDisplayRandomAddress:`.
- `WFClient.setEnableRandomMACForNetwork:enable:randomMAC:`.

**Tác dụng:** giữ MAC được đọc từ IOKit/Wi-Fi APIs nhất quán với private Wi-Fi configuration path.

**Yêu cầu:** cùng canonical MAC snapshot; không tạo MAC mới mỗi lần gọi; preserve enable/state semantics khi spoofing tắt.

### P1-06 — Chốt chính sách Lockdown/release

`LockdownIdentityHooks.x` tồn tại nhưng bị loại khỏi release bởi `INTERNAL_SECURITY_RESEARCH=0`.

**Khuyến nghị:** không đơn giản bật research hook hoặc inject `lockdownd`. Hãy chọn một trong hai contract rõ ràng:

1. Lockdown không thuộc production scope và static/runtime audit phải báo `unsupported` rõ ràng; hoặc
2. Cung cấp app-side, capability-gated owner cho consumer cụ thể đã được chứng minh, không mở rộng sang sensitive daemon.

**Tác dụng:** tránh hiểu nhầm “có source = production đã phủ”, đồng thời giữ release hardening nhất quán.

## 6. P2 — chỉ làm khi thuộc phạm vi sản phẩm

### P2-01 — Virtual camera/microphone

Các surface còn thiếu:

- `AVCaptureVideoDataOutput.setSampleBufferDelegate:queue:`.
- Runtime `captureOutput:didOutputSampleBuffer:fromConnection:`.
- `AVCaptureVideoPreviewLayer.addSublayer:` và lifecycle helper.
- `AudioUnitRender`.

**Tác dụng:** cung cấp camera/microphone ảo. Đây là subsystem độc lập, không phải core identity parity.

**Điều kiện:** chỉ triển khai khi có yêu cầu sản phẩm; default-off, media-type validation, retain/release sample buffer đúng và passthrough tuyệt đối khi không active.

### P2-02 — Safari private controller

- `BrowserRootViewController`.
- `TabDocument` navigation/certificate path.
- `BrowserWindowController` restore state.

**Tác dụng:** Safari automation/state restore, không làm tăng core fingerprint parity. Private selector rất dễ vỡ theo iOS version.

### P2-03 — SpringBoard mouse/UI bridge

iFakePro có 15 SpringBoard/UI hooks và bốn method mouse-pointer được thêm động. x-new chủ động dùng SpringBoard minimal mode.

**Khuyến nghị:** nếu cần mouse bridge, tách thành module nhỏ, không kéo toàn bộ spoof/JB/network stack vào SpringBoard.

### P2-04 — Push-token consistency

Danh sách thứ nhất hook device token và `PKPushCredentials.token`.

**Tác dụng:** phục vụ profile migration/testing push/CallKit nếu đây là tính năng sản phẩm.

**Điều kiện:** chỉ trong app được người dùng scope; token phải có lifecycle/rotation rõ ràng. Không giả token ở daemon hoặc dịch vụ Apple.

### P2-05 — Compatibility theo ứng dụng/SDK

Các nhóm Facebook/Messenger, Gmail, TextFree, Pinger, Phoner, OneSignal, Bugsnag, AppsFlyer, ByteDance/TikTok… chỉ nên thêm dưới dạng adapter riêng khi:

- ứng dụng mục tiêu nằm trong phạm vi sản phẩm;
- generic owner hiện tại bị bypass bởi một selector đã tái hiện;
- adapter được allowlist theo class + selector + type encoding;
- có fixture chứng minh OFF/passthrough và không ảnh hưởng app khác.

**Tác dụng:** compatibility cho app cụ thể. Không được coi đây là yêu cầu để đạt core device-identity parity.

## 7. EVIDENCE-GATED — chưa nên triển khai

| Candidate | Lý do chưa nên thêm | Điều kiện mở lại |
|---|---|---|
| `CFPropertyListCreateWithData` | Global content parser hook quá rộng; path-bearing SystemVersion transformer đã sở hữu observable path hiện tại. | Fixture chứng minh parser nhận nội dung cần sửa mà không còn path/provenance. |
| Native WebCore `HTMLCanvasElement::toDataURL` | Private symbol/build-fragile; JS layer đang giữ observable behavior. | On-device fixture vượt qua JS owner. |
| `glReadPixels`, `glGetString` | Process-global OpenGL interception dễ phá rendering và ABI. | Concrete fingerprint path không qua current WebGL projection. |
| `NXMapGet`, `NXHashGet` | Private collection primitives quá rộng; current app-list/path/runtime-image owners đã hẹp hơn. | Detector cụ thể bypass tất cả owner hiện tại. |
| Hai SBS launch C functions | Higher-level `SpringBoardLaunchHook` đã sở hữu behavior chính. | Failing launch fixture chỉ đi qua SBS symbols. |
| `MSHookMemory` code scanner | Rủi ro build-specific, patch sai instruction và khó audit. | Detector binary cụ thể không thể xử lý bằng symbol/ObjC hook. |
| Side-effect FS mutation hooks | Có thể thay đổi/fake kết quả thao tác thật. | Provenance-qualified fixture và semantics lỗi an toàn. |

## 8. DO NOT PORT — không đưa vào backlog triển khai

### 8.1. Security/attestation/secure identity

- `SecTaskCopyValueForEntitlement`.
- `SecCodeCopySigningInformation`.
- `SecStaticCodeCreateWithPath`.
- `SecStaticCodeCheckValidity`.
- `SecStaticCodeCheckValidityWithErrors`.
- Secure Element/PassKit SEID/pfSEID/payment identity.
- DeviceCheck/App Attest, AMFI, code-signing hoặc entitlement falsification.

Các hook này không phải device-profile consistency; chúng làm sai trust/attestation boundary.

### 8.2. Credential/payment/account manipulation

- Hook thu thập hoặc thay thế username/iCloud login input.
- IAP unarchive/decode hoặc sửa receipt/purchase state.
- Pairing/trust/Activation Lock manipulation.
- TLS/certificate weakening.

### 8.3. Global high-risk native interception

Không thêm process-wide chỉ để đạt parity:

- `syscall`, `sandbox_check`, `strstr`.
- `read`, `write`, `pread`, `pwrite`.
- `mmap`, `mprotect`, `ioctl`, variadic `fcntl`.
- `vm_region_64`, `vm_region_recurse_64`, `mach_vm_read_overwrite`.
- `thread_get_state`, `task_for_pid`, `task_set_special_port`.
- `bootstrap_check_in`, broad XPC create hooks.
- `_dyld_image_count`, `_dyld_get_image_header`, `_dyld_get_image_vmaddr_slide`.

### 8.4. Sensitive-daemon injection

Không copy filter 40 bundle + 34 executable của iFakePro. Đặc biệt không mở rộng production injection sang `lockdownd`, `MobileGestaltHelper`, `devicecheckd`, `nfcd`, `tccd`, `fairplayd`, App Store/account daemons hoặc location daemons chỉ để tăng hook count.

## 9. Danh sách 45 native exact gaps — phân loại để theo dõi, không phải backlog mặc định

### 9.1. Side-effect/evidence-gated

`chdir`, `chroot`, `mkdir`, `mkdirat`, `chmod`, `fchmod`, `fchmodat`, `chown`, `fchown`, `fchownat`, `unlinkat`, `renameat`, `symlinkat`, `linkat`, `getfh`, `mknod`, `fchdir`, `execve`, `setxattr`, `removexattr`, `freopen`.

### 9.2. High-risk/global

`syscall`, `read`, `pread`, `pwrite`, `write`, `ioctl`, `mmap`, `mprotect`, `fcntl`, `strstr`, `vm_region_64`, `vm_region_recurse_64`, `mach_vm_read_overwrite`, `bootstrap_check_in`, `sandbox_check`, `xpc_connection_create_mach_service`, `xpc_connection_create`, `thread_get_state`, `task_for_pid`, `task_set_special_port`, `_dyld_shared_cache_contains_path`, `_dyld_image_count`, `_dyld_get_image_vmaddr_slide`, `_dyld_get_image_header`.

Tổng: 21 side-effect/evidence-gated + 24 high-risk/global = 45 exact symbols.

## 10. Thứ tự triển khai đề xuất

1. **P0-01 MobileGestalt typed key parity.** Đây là owner trung tâm và tạo hiệu quả consistency lớn nhất.
2. **P0-02 LaunchServices/private identity consistency.** Đóng đường IDFA/IDFV/UDID/serial song song.
3. **P0-03 Location direct surface + semantics.** Loại bỏ polling/callback divergence.
4. **P0-04 Pedometer/altitude.** Đóng sensor side channel còn rõ nhất.
5. **P0-05 VPN/discovery.** Thêm capability riêng và kiểm tra consistency với network owner.
6. **P1-01 device/process scalars** và **P1-05 random MAC**.
7. **P1-02 WebKit ObjC lifecycle/UA** và **P1-04 HTTP header consistency**.
8. **P1-03 Foundation loader variants** theo failing fixtures.
9. **P1-06 Lockdown production contract** — quyết định supported/unsupported, không bật research wholesale.
10. Chỉ sau đó mới xem xét các module **P2** theo phạm vi sản phẩm.

## 11. Tiêu chuẩn hoàn thành chung cho mỗi hạng mục

Mỗi hook/adapter mới phải có:

- Một owner duy nhất; không cài duplicate hook trên cùng entry point.
- Scope gate, feature toggle và capability audit.
- Original-first hoặc typed original fallback khi profile thiếu/không hợp lệ.
- Không synthesize class/selector/API không tồn tại trên OS vật lý.
- Cùng logical field lấy từ một canonical snapshot và cùng generation.
- Test enabled, disabled, out-of-scope, missing field, partial profile và unsupported API.
- Cross-surface consistency test, ví dụ model/serial/ID phải khớp giữa UIDevice, MG, IOKit, LS và private wrapper.
- Runtime test trên thiết bị cho callback queue, object ownership, ABI struct/data type và lifecycle teardown.

## 12. Kết luận

Khoảng trống đáng bổ sung nhất không nằm ở việc sao chép hàng trăm vendor hook, mà ở năm nhóm có khả năng tạo dữ liệu thật hoặc mâu thuẫn quan sát được: **MobileGestalt key coverage, LaunchServices/private identity, Location direct surface, Pedometer/Altitude và VPN/Discovery**.

WebKit lifecycle/UA, Foundation loader, random MAC và device/process scalar là lớp tiếp theo. Camera/microphone, Safari controller, SpringBoard mouse, push token và adapter theo ứng dụng chỉ nên được xem là tính năng tùy chọn. Security/attestation, credential/payment manipulation, broad native interception và sensitive-daemon injection phải tiếp tục bị loại khỏi production backlog.
