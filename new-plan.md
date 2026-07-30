# Kế hoạch triển khai và Backlog kỹ thuật

> Tài liệu tổng hợp kết quả đối chiếu tài liệu iFakePro V8 với mã nguồn hiện tại, các nhận định đã hiệu chỉnh, kế hoạch cải thiện Clear Data và phương án cho hạng mục 14/Lockdown Identity Hooks.
>
> **Phạm vi:** kế hoạch kỹ thuật và thứ tự triển khai. Chưa bao gồm thay đổi mã nguồn.
>
> **Nguyên tắc an toàn:** các chức năng nghiên cứu liên quan trạng thái bảo mật chỉ được phép trong bản build nội bộ, theo allowlist và mặc định tắt. Không triển khai cơ chế bỏ qua attestation, AMFI/code-signing, Activation Lock, pairing/trust hoặc anti-fraud.

---

## 1. Mục tiêu

1. Hợp nhất tất cả bề mặt thông tin thiết bị vào một profile snapshot nhất quán.
2. Bảo đảm bộ iOS version/build/Darwin/XNU/kernel/model/SoC hợp lệ.
3. Loại bỏ hook trùng, cache phân mảnh và đường build không kiểm soát.
4. Bổ sung Lockdown Identity Hooks cho các key đã thống nhất.
5. Cải thiện Clear Data theo hướng nhanh, có phạm vi rõ và có thể kiểm chứng.
6. Thiết lập kiểm thử consistency liên bề mặt trước khi mở rộng độ phủ hook.
7. Giữ các chức năng nghiên cứu rủi ro cao ngoài bản Release.

## 2. Kết luận sau khi rà soát lại

### 2.1. Các nhận định đã được xác nhận

- `uname` hiện chỉ thay `machine`, chưa đồng bộ `release` và `version` với bộ kernel đã chọn.
- Database iOS hiện dừng ở iOS 18.5 và chứa kernel suffix gắn cứng với một số SoC; có nguy cơ chọn iOS/model không tương thích.
- Validator hiện chưa bao phủ đầy đủ quan hệ iOS version, build, Darwin, XNU, kernel suffix, model và SoC.
- Audit script chưa kiểm tra đầy đủ `uname`, hook Objective-C trùng selector và các khai báo hook nhiều dòng.
- Có nguy cơ hook Objective-C trùng giữa các module.
- MobileGestalt/IORegistry alias và expected type chưa được quản lý tập trung.
- UA/header/WebKit helper chưa có một normalizer dùng chung cho toàn bộ đường đi.
- Cellular schema cần bao phủ dual-SIM/eSIM, IMEI2, ICCID và IMSI theo capability của model.
- Cấu hình build Release hiện có wildcard source inclusion; có nguy cơ đưa file test/debug vào package.
- `DEBUG=1` và `FINALPACKAGE=0` không phù hợp với Release.
- Clear Data chậm do nhiều lượt xử lý nối tiếp, hai Keychain pass, resolve container lặp lại, nhiều shell process, SQLite `VACUUM`, verify cuối và `sync()` toàn hệ thống.

### 2.2. Hai nhận định cần hiệu chỉnh

#### Snapshot/generation đã tồn tại

Dự án đã có nền tảng snapshot/generation, bao gồm luồng lấy snapshot và generation counter. Vì vậy không cần tạo lại từ đầu.

Việc cần làm là:

- chuẩn hóa snapshot hiện có thành nguồn dữ liệu duy nhất;
- bắt buộc mọi module dùng cùng `profileId + generation`;
- loại bỏ cache TTL riêng không gắn với generation;
- vô hiệu hóa cache nguyên tử khi đổi profile.

#### `uname` không thuộc coordinator là quyết định có chủ đích

`uname` đang được coi là symbol độc quyền do Tweak sở hữu. Đây không tự thân là lỗi kiến trúc.

Do đó:

- không bắt buộc chuyển `uname` vào coordinator;
- audit phải biết đây là ngoại lệ có chủ sở hữu;
- ưu tiên thực tế là hoàn thiện `uname.release`/`uname.version` và kiểm thử consistency.

## 3. Kiến trúc mục tiêu

### 3.1. Profile snapshot duy nhất

Mọi provider phải đọc từ một immutable snapshot:

```text
PXDeviceIdentitySnapshot
├── profileId
├── generation
├── software
│   ├── ProductVersion
│   ├── BuildVersion
│   ├── Darwin
│   ├── XNU
│   └── KernelVersion
├── hardware
│   ├── ProductType
│   ├── HardwareModel
│   ├── HardwarePlatform
│   ├── SoC
│   ├── UniqueChipID
│   └── MLBSerialNumber
├── identity
│   ├── UDID
│   ├── SerialNumber
│   └── DeviceName
├── network
│   ├── WiFiAddress
│   └── BluetoothAddress
└── cellular
    ├── capabilities
    ├── IMEI1/IMEI2
    ├── MEID
    ├── ICCID/IMSI
    └── BasebandVersion
```

Yêu cầu:

- snapshot bất biến trong cùng generation;
- publish snapshot mới theo thao tác nguyên tử;
- provider không tự sinh fallback khác nhau;
- dữ liệu thiếu phải trả về original hoặc báo validation error;
- không tự tạo ngẫu nhiên IMEI, serial, ChipID hoặc baseband.

### 3.2. Provider và coordinator

```text
Profile Store
    ↓
Snapshot Builder
    ↓
Consistency Validator
    ↓
Atomic Snapshot Publisher
    ↓
Provider Registry
    ├── uname/sysctl
    ├── SystemVersion
    ├── MobileGestalt
    ├── IORegistry
    ├── UIKit/Foundation
    ├── Web/UA headers
    ├── Cellular
    └── Lockdown identity
```

Mỗi registry entry cần có:

- key/symbol/selector;
- expected return type;
- source field trong snapshot;
- process scope;
- minimum OS/availability;
- fallback policy;
- owner module;
- sensitivity/risk level.

## 4. Hạng mục 14 — Security Research và Lockdown Identity

### 4.1. Phạm vi được triển khai

Hạng mục 14 gồm:

1. Chẩn đoán read-only.
2. Consistency validator.
3. Test mocks trong ứng dụng hoặc harness do đội ngũ sở hữu.
4. Lockdown Identity Hooks cho các key nhận dạng đã thống nhất.

Không bao gồm:

- bỏ qua DeviceCheck/App Attest;
- giả token/chứng cứ attestation;
- vô hiệu hóa AMFI hoặc code-signing;
- giả entitlement như `get-task-allow`;
- hook selector chuyên biệt để né anti-fraud;
- can thiệp TLS/pinning;
- inject rộng vào daemon nhạy cảm;
- sửa pairing/trust record, escrow bag hoặc Activation Lock.

### 4.2. Safety foundation bắt buộc

Trước khi có bất kỳ option runtime nào, phải hoàn thành:

- compile-time gate `INTERNAL_SECURITY_RESEARCH`;
- loại toàn bộ module khỏi Release target;
- master switch mặc định `OFF`;
- process/bundle allowlist;
- session TTL, reboot hoặc hết hạn sẽ tự tắt;
- audit log có redaction;
- nút `Disable all and restore`;
- fail closed: validation lỗi thì trả giá trị gốc;
- không có `Apply to all processes`;
- không có `Persist after reboot`;
- không inject vào daemon hệ thống trong bản phân phối.

### 4.3. Các Lockdown keys trong phạm vi

| Nhóm | Lockdown key | Kiểu cần giữ | Nguồn snapshot |
|---|---|---|---|
| Device identity | `kLockdownUniqueDeviceIDKey` | String | UDID |
| Device identity | `kLockdownSerialNumberKey` | String | SerialNumber |
| Cellular | `kLockdownIMEIKey` | String | IMEI1 |
| Hardware identity | `kLockdownMLBSerialNumberKey` | String | MLBSerialNumber |
| Hardware model | `kLockdownProductTypeKey` | String | ProductType |
| User identity | `kLockdownDeviceNameKey` | String | DeviceName |
| SoC identity | `kLockdownUniqueChipIDKey` | Giữ CFType gốc | UniqueChipID |
| Baseband | `kLockdownBasebandVersionKey` | String | BasebandVersion |
| Software | `kLockdownBuildVersionKey` | String | BuildVersion |

Các key nên bổ sung để hoàn thiện consistency:

- `kLockdownProductVersionKey`;
- `kLockdownHardwareModelKey`;
- `kLockdownHardwarePlatformKey`;
- `kLockdownWiFiAddressKey`;
- `kLockdownBluetoothAddressKey`;
- key IMEI2/MEID khi firmware và model hỗ trợ.

Không giả định mọi firmware export cùng constant. Registry phải kiểm tra availability và hỗ trợ tên key tương đương khi phù hợp.

### 4.4. Nguyên tắc xử lý Lockdown key

Không sửa trực tiếp các constant. Provider chỉ thay kết quả lookup khi đồng thời thỏa mãn:

1. Master switch đang bật.
2. Build thuộc kênh Internal/Research.
3. Process nằm trong allowlist.
4. Key có trong registry.
5. Snapshot hợp lệ và đúng generation.
6. Expected type khớp với kiểu giá trị gốc.
7. Dependency validator thông qua.
8. Option nhóm tương ứng đang bật.

Nếu bất kỳ điều kiện nào thất bại, trả về giá trị gốc và ghi diagnostic event đã redaction.

### 4.5. Option đề xuất

```text
Lockdown Identity Hooks                      OFF
├── Mode
│   ├── Observe only
│   └── Profile-backed internal test
├── Software version                         OFF
├── Product model                            OFF
├── Device display name                      OFF
├── Device identifiers                       OFF
├── SoC identity                             OFF
├── Cellular and baseband                    OFF
├── Strict consistency                       ON
├── Return original on validation failure    ON
├── Process allowlist
├── Session duration                         15 minutes
└── Disable and clear snapshot
```

Không nên cho phép bật riêng lẻ UDID, serial và MLB trong giao diện thông thường. Chúng thuộc một nhóm identity nguyên tử để tránh giá trị mâu thuẫn.

### 4.6. Thứ tự triển khai Lockdown theo rủi ro

#### Giai đoạn L0 — Observe only

- inventory key/domain được truy vấn;
- log process, key, expected type và source provider;
- che UDID, serial, IMEI, ChipID trong log;
- không log pair record, certificate, private key hoặc escrow data;
- đo tần suất, timeout và cache behavior.

#### Giai đoạn L1 — Software và presentation

Triển khai trước:

- `kLockdownBuildVersionKey`;
- `kLockdownProductVersionKey` nếu khả dụng;
- `kLockdownProductTypeKey`;
- `kLockdownDeviceNameKey`.

Điều kiện:

- ProductVersion/BuildVersion phải tồn tại trong version database;
- ProductType phải khớp hardware model/SoC;
- DeviceName là tên do người dùng đặt, không đồng nhất máy móc với ProductType.

#### Giai đoạn L2 — Device identity

- `kLockdownUniqueDeviceIDKey`;
- `kLockdownSerialNumberKey`;
- `kLockdownMLBSerialNumberKey`.

Yêu cầu:

- lấy từ cùng snapshot/generation;
- nhất quán với MobileGestalt và IORegistry;
- không thay đổi trong cùng phiên;
- không tự tạo fallback mới khi thiếu dữ liệu.

#### Giai đoạn L3 — SoC và cellular

- `kLockdownUniqueChipIDKey`;
- `kLockdownIMEIKey`;
- `kLockdownBasebandVersionKey`;
- mở rộng IMEI2/MEID theo capability.

Validator phải chặn:

- model Wi-Fi-only có IMEI/baseband;
- ChipID không tương ứng SoC/ProductType;
- IMEI sai hình thức;
- dual-SIM schema thiếu IMEI2 nhưng bề mặt khác công bố hai SIM;
- baseband family không phù hợp model.

### 4.7. Ma trận consistency Lockdown

| Lockdown value | Bề mặt cần đối chiếu |
|---|---|
| UniqueDeviceID | Profile UDID và API UDID thuộc phạm vi hỗ trợ |
| SerialNumber | MobileGestalt SerialNumber, IOPlatformSerialNumber |
| IMEI | Telephony provider, SIM slot và cellular capability |
| MLBSerialNumber | MobileGestalt MLBSerialNumber |
| ProductType | DeviceModel, `hw.model`, hardware database |
| DeviceName | Profile/user-configured device name |
| UniqueChipID | MobileGestalt ChipID và SoC của ProductType |
| BasebandVersion | Cellular capability, modem/baseband family |
| BuildVersion | ProductVersion, Darwin, XNU và kernel tuple |

## 5. Kế hoạch iOS identity và kernel

### P0 — Tính đúng đắn

#### IOS-01 — Chuẩn hóa snapshot/generation hiện có

- dùng snapshot hiện có làm nguồn duy nhất;
- loại cache TTL độc lập hoặc gắn cache với generation;
- publish nguyên tử;
- thêm stale-generation guard.

#### IOS-02 — Unified validator

Kiểm tra:

- iOS version ↔ build;
- build ↔ Darwin;
- Darwin ↔ XNU/kernel;
- model ↔ hardware platform/SoC;
- kernel suffix ↔ SoC;
- cellular schema ↔ model capability.

#### IOS-03 — Versioned iOS database

- chuyển database hard-code sang file versioned;
- có schema version;
- có provenance/source metadata;
- không gắn kernel suffix của một SoC cho mọi model;
- validator từ chối tuple không đầy đủ;
- bổ sung test dữ liệu trước khi đóng gói.

#### IOS-05 — Hoàn thiện `uname`

- giữ mô hình Tweak-owned nếu vẫn chỉ có một owner;
- đồng bộ `machine`, `release`, `version`;
- bảo đảm kết quả khớp `sysctl kern.osrelease` và `kern.version`;
- thêm `uname` vào audit với ownership exception rõ ràng.

#### IOS-06 — Unified SystemVersion transformer

Dùng cùng snapshot cho:

- `CFCopySystemVersionDictionary`;
- các API Foundation/UIKit liên quan;
- bundle/SystemVersion lookup trong phạm vi đã định.

#### IOS-07/CONS-01 — Consistency matrix test

Test ít nhất:

```text
uname
↔ sysctl/sysctlbyname
↔ NSProcessInfo/UIDevice
↔ CFCopySystemVersionDictionary
↔ MobileGestalt
↔ IORegistry
↔ Lockdown provider
```

#### IOS-08 — Injection filter

- xác minh generated filter;
- kiểm tra allowlist/denylist;
- có test bảo đảm module không load ngoài scope.

### P2 — Kiến trúc tùy chọn

#### IOS-04 — Đánh giá lại ownership của `uname`

Chỉ chuyển vào coordinator nếu có nhu cầu nhiều provider cùng sở hữu symbol. Nếu không, giữ Tweak-owned và làm audit ownership rõ ràng.

## 6. Hook, Web, Cellular và Build backlog

### Hook registry

- **HOOK-01/P0:** audit hook Objective-C trùng class/selector.
- **HOOK-02/P1:** registry MobileGestalt/IORegistry alias kèm expected type.
- **HOOK-03/P1:** bổ sung alias MAC/IODeviceTree còn thiếu; xác minh `CFData` so với String.
- **AUDIT-01/P0:** hỗ trợ multiline declaration, duplicate native symbol, duplicate selector và ownership exception.

### Web identity

- **WEB-01/P1:** central User-Agent normalizer.
- **WEB-02/P1:** đồng bộ các header bổ sung và WebKit helper scope.
- Không làm yếu TLS hoặc certificate validation.

### Cellular

- **CELL-01/P1:** schema capability-aware cho physical SIM, eSIM và dual-SIM.
- Bao phủ IMEI1/IMEI2, MEID, ICCID, IMSI và BasebandVersion khi phù hợp.
- Không công bố telephony identifier trên model Wi-Fi-only.

### Build/release

- **BUILD-01/P0:** loại `AAA_TestCtor.m` khỏi Release.
- **BUILD-02/P0:** bỏ wildcard Release inclusion; dùng danh sách source tường minh.
- **BUILD-03/P0:** Release dùng `DEBUG=0`, `FINALPACKAGE=1`.
- **BUILD-04/P1:** thêm CI gate chạy audit và consistency tests.

## 7. Clear Data — phân tích và kế hoạch cải thiện

### 7.1. Nguyên nhân chậm đã xác định

Luồng hiện tại thực hiện nhiều bước nối tiếp:

1. Dừng process.
2. Keychain plan/pass đầu.
3. URL credentials.
4. App state.
5. Wipe application, extension, AppGroups và PluginKit.
6. Cookies.
7. Keychain pass cuối.
8. `sync()`.
9. Verify dữ liệu đã clear.

Các điểm tốn thời gian:

- hai Keychain pass cộng verify;
- bridge/helper có timeout dài;
- resolve application/extension/AppGroup/container lặp lại;
- quét rootful và rootless;
- nhiều shell command chạy tuần tự;
- SQLite checkpoint, nhiều `LIKE '%...%'` và `VACUUM`;
- logic SQL hard-code theo ứng dụng;
- chờ process/daemon thoát và nhiều sleep cố định;
- `sync()` toàn hệ thống;
- verify lặp lại những nội dung vừa kiểm tra trong từng bước.

### 7.2. Ba mức Clear Data

#### Quick

Dùng cho thao tác thường ngày:

- kill app mục tiêu;
- resolve container từ cache có validation;
- clear application data theo scope;
- clear app-scoped defaults/cookies cần thiết;
- một Keychain pass nếu người dùng chọn;
- verify tối thiểu.

Không chạy mặc định:

- deep SQLite cleanup;
- `VACUUM`;
- quét toàn hệ thống;
- daemon refresh diện rộng;
- `sync()` toàn hệ thống.

#### Full

- toàn bộ Quick;
- extension, AppGroups và PluginKit được xác định;
- URL credentials/cookies theo app/domain;
- Keychain một pass đã tổng hợp;
- manifest và targeted verification;
- refresh service có phạm vi.

#### Deep

- chỉ dùng khi Full thất bại hoặc người dùng yêu cầu;
- filesystem fallback;
- SQLite cleanup chuyên sâu;
- kiểm tra migrated/rootless/rootful paths;
- timeout dài hơn;
- report từng bước và lỗi chi tiết.

### 7.3. Backlog Clear Data

- **CLEAR-01/P0:** dry-run và transaction journal.
- **CLEAR-02/P0:** giới hạn cookie/credential theo app hoặc domain.
- **CLEAR-03/P1:** cache `bundleID → containerPath` có invalidation.
- **CLEAR-04/P1:** hợp nhất Keychain thành một pass.
- **CLEAR-05/P1:** Quick/Full/Deep modes.
- **CLEAR-06/P1:** batch shell và SQLite; hạn chế `VACUUM` và wildcard query.
- **CLEAR-07/P2:** loại hoặc thu hẹp `sync()` toàn hệ thống.
- **CLEAR-08/P1:** manifest-driven verification, tránh verify trùng.
- **CLEAR-09/P2:** cô lập hoặc loại SQL/bundle logic hard-code cho Uber/Lyft/Helix.
- **CLEAR-10/P1:** instrumentation thời gian cho từng step.

### 7.4. Chỉ số cần đo

- tổng thời gian Quick/Full/Deep;
- resolve-container duration;
- Keychain duration;
- số shell process;
- số path được quét;
- SQLite duration;
- verify duration;
- timeout/fallback count;
- phần trăm clear thành công ngay lần đầu.

## 8. Backup và dữ liệu

- **BACKUP-01/P1:** authenticated encryption và provenance cho backup.
- Manifest phải ghi schema version, app version, profile generation và thời điểm.
- Restore phải validate manifest trước khi ghi.
- Không lưu khóa bí mật cùng backup payload.
- Không mở rộng dữ liệu từ app này sang app khác ngoài scope đã chọn.

## 9. Các hạng mục không khuyến nghị

Không triển khai thành option runtime hoặc tính năng Release:

- attestation bypass;
- giả DeviceCheck/App Attest token;
- AMFI/code-signing falsification;
- giả entitlement;
- anti-fraud-specific targeting;
- TLS weakening;
- sensitive-daemon injection;
- Lockdown pairing/trust bypass;
- sửa pair record, HostID/SystemBUID, certificate hoặc escrow bag;
- Activation/Activation Lock override.

Option bật/tắt không làm giảm bản chất rủi ro của các chức năng này.

## 10. Thứ tự triển khai tổng thể

### Phase 0 — Baseline và đo lường

1. Đóng băng baseline hiện tại.
2. Thêm CI build Release chuẩn.
3. Chạy audit hiện có và lưu báo cáo.
4. Thêm timing cho Clear Data.
5. Inventory tất cả hook owner và Lockdown key lookup.

**Exit criteria:** có build tái lập được, báo cáo baseline và số đo Clear Data theo bước.

### Phase 1 — Build safety và audit

1. BUILD-01/02/03.
2. AUDIT-01 và HOOK-01.
3. Xác minh injection filter IOS-08.
4. Thiết lập ownership registry.

**Exit criteria:** Release không chứa test ctor/debug source; CI bắt được symbol/selector trùng.

### Phase 2 — Snapshot và validator

1. IOS-01 chuẩn hóa snapshot/generation.
2. IOS-02 unified validator.
3. IOS-03 versioned database.
4. Atomic cache invalidation.

**Exit criteria:** profile không hợp lệ bị từ chối trước khi publish; mọi provider đọc cùng generation.

### Phase 3 — Native/SystemVersion consistency

1. IOS-05 hoàn thiện `uname`.
2. IOS-06 SystemVersion transformer.
3. IOS-07/CONS-01 test matrix.
4. HOOK-02/03 registry alias/type.

**Exit criteria:** uname/sysctl/SystemVersion/MG/IORegistry trả về tuple nhất quán cho bộ profile test.

### Phase 4 — Lockdown safety foundation

1. Compile-time Research gate.
2. Master switch, allowlist, TTL.
3. Observe-only và redacted logs.
4. Original fallback và kill switch.

**Exit criteria:** module không có trong Release; ngoài allowlist luôn trả original; log không lộ identifier đầy đủ.

### Phase 5 — Lockdown software/model

1. BuildVersion/ProductVersion.
2. ProductType.
3. DeviceName.
4. Cross-check với SystemVersion/model database.

**Exit criteria:** software/model tuple vượt consistency tests và giữ đúng kiểu dữ liệu.

### Phase 6 — Lockdown device identity

1. UDID.
2. SerialNumber.
3. MLBSerialNumber.
4. Generation-stability tests.

**Exit criteria:** ba key dùng cùng snapshot, không thay đổi trong phiên và khớp MG/IORegistry.

### Phase 7 — Lockdown SoC/cellular

1. UniqueChipID.
2. IMEI1/IMEI2/MEID theo capability.
3. BasebandVersion.
4. Negative tests cho Wi-Fi-only và schema thiếu.

**Exit criteria:** validator chặn mọi tổ hợp model/SoC/cellular không hợp lệ.

### Phase 8 — Clear Data Quick/Full/Deep

1. CLEAR-10 instrumentation.
2. CLEAR-03 container cache.
3. CLEAR-04 single Keychain pass.
4. CLEAR-05 mode split.
5. CLEAR-06 batching.
6. CLEAR-08 manifest verify.
7. CLEAR-07/09 cleanup tech debt.

**Exit criteria:** Quick giảm thời gian rõ rệt so với baseline; Full giữ tỷ lệ thành công; Deep có báo cáo lỗi theo bước.

### Phase 9 — Web, Cellular, Backup

1. WEB-01/02.
2. CELL-01.
3. BACKUP-01.
4. End-to-end profile-switch tests.

### Phase 10 — Release hardening

1. Regression suite trên nhiều model/iOS.
2. Crash/performance testing.
3. Xác minh không có Research module trong package.
4. Kiểm tra redaction và privacy.
5. Ký release checklist.

## 11. Backlog ưu tiên cuối cùng

### P0

- BUILD-01, BUILD-02, BUILD-03.
- AUDIT-01, HOOK-01.
- IOS-01, IOS-02, IOS-03, IOS-05, IOS-06, IOS-07, IOS-08.
- CONS-01.
- LOCK-01 registry và expected type.
- LOCK-02 provider dùng snapshot/generation.
- LOCK-03 software tuple.
- LOCK-04 identity consistency.
- LOCK-05 ProductType/SoC validator.
- LOCK-07 safety toggles/allowlist/TTL.
- LOCK-09 type preservation/original fallback.
- LOCK-10 atomic cache invalidation.
- CLEAR-01, CLEAR-02.

### P1

- HOOK-02, HOOK-03.
- WEB-01, WEB-02.
- CELL-01.
- LOCK-06 cellular validator.
- LOCK-08 diagnostics/redaction.
- CLEAR-03, CLEAR-04, CLEAR-05, CLEAR-06, CLEAR-08, CLEAR-10.
- BACKUP-01.
- BUILD-04.

### P2

- IOS-04 đánh giá coordinator ownership.
- TIME-01 opt-in time-offset module.
- CLEAR-07 loại/thu hẹp `sync()`.
- CLEAR-09 loại hard-code app SQL.
- App-owned test mocks trong test harness.

### Blocked

- Attestation/anti-fraud bypass.
- AMFI/code-signing/entitlement falsification.
- TLS weakening.
- Sensitive-daemon injection.
- Lockdown pairing/trust/activation bypass.

## 12. Chiến lược kiểm thử

### Unit tests

- version/build/kernel database validation;
- model/SoC mapping;
- expected type conversion;
- profile snapshot immutability;
- generation invalidation;
- cellular capability rules;
- redaction.

### Integration tests

- đổi profile trong khi process đang hoạt động;
- nhiều API đọc cùng generation;
- original fallback khi key thiếu;
- process ngoài allowlist;
- hết TTL;
- build không export key/symbol tùy chọn;
- Lockdown software → identity → cellular group toggles.

### Consistency tests

Mỗi profile fixture phải thu thập và so sánh:

- `uname`;
- `sysctl`/`sysctlbyname`;
- Foundation/UIKit version/model;
- SystemVersion dictionary;
- MobileGestalt;
- IORegistry;
- Lockdown identity provider;
- telephony/network surfaces.

### Clear Data tests

- app không extension/AppGroup;
- app có nhiều extension;
- app dùng shared AppGroup;
- keychain có/không có item;
- Quick/Full/Deep;
- timeout/helper failure;
- interrupted transaction;
- verify và rollback/report.

## 13. Definition of Done chung

Một hạng mục chỉ hoàn thành khi:

1. Có owner và tài liệu scope.
2. Có expected type và fallback policy.
3. Có unit/integration test.
4. Không làm phát sinh duplicate hook.
5. Không tạo cache ngoài generation policy.
6. Có audit log phù hợp và redaction nếu chứa identifier.
7. Không mở rộng process scope ngoài allowlist.
8. Release package không chứa code Research bị cấm.
9. Regression suite vượt qua.
10. Có số đo hiệu năng trước/sau đối với thay đổi Clear Data.

## 14. Giới hạn của đánh giá hiện tại

- Kết luận dựa chủ yếu trên phân tích mã tĩnh và các lần tìm kiếm trong source.
- Chưa có build/runtime probe trên thiết bị trong tài liệu này.
- Các kết luận “không có” nên hiểu là “chưa quan sát thấy trong phạm vi source đã rà soát”.
- Trước khi chốt estimate, cần chạy build, audit và instrumentation baseline trên thiết bị đại diện.

## 15. Kết luận

Trọng tâm triển khai nên theo thứ tự:

1. Build safety và audit.
2. Snapshot/generation và validator.
3. iOS/kernel/native consistency.
4. Lockdown safety foundation.
5. Lockdown software/model.
6. Lockdown device identity.
7. Lockdown SoC/cellular.
8. Clear Data Quick/Full/Deep và tối ưu hiệu năng.
9. Web/cellular/backup hardening.
10. Regression và Release hardening.

Cách sắp xếp này xử lý lỗi nền tảng trước, giảm nguy cơ profile mâu thuẫn, đồng thời giữ Lockdown Identity Hooks trong phạm vi có kiểm soát. Những chức năng tác động pairing, attestation, AMFI, anti-fraud hoặc Activation Lock không được đưa vào kế hoạch triển khai.
