# IOS-07 / CONS-01 — Consistency Matrix Test

## Mục tiêu

Mỗi "sự thật" về thiết bị (phiên bản iOS, build, model, tên máy…) bị đọc qua
nhiều API khác nhau: `uname`, `sysctl`, `sysctlbyname`, MobileGestalt (`MGCopyAnswer`),
IOKit, `CFCopySystemVersionDictionary` và file `SystemVersion.plist`.

Nếu hai bề mặt (surface) mô tả **cùng một sự thật** nhưng trả về **giá trị khác nhau**,
ứng dụng phát hiện mâu thuẫn và biết đang bị spoof. CONS-01 đảm bảo mọi bề mặt
luôn chiếu (project) cùng một giá trị từ đúng một trường canonical của profile.

Ma trận nhất quán là **nguồn sự thật duy nhất** cho các nhóm này:

- `common/PXConsistencyMatrix.h` / `.m` — bảng ma trận + validator.
- `tests/PXConsistencyMatrixTests.m` — bài test.
- `tests/PXConsistencyMatrixMain.m` — điểm chạy độc lập.

## Cấu trúc ma trận

Mỗi hàng (`PXConsistencyMatrixEntry`) mô tả một bề mặt:

| Trường | Ý nghĩa |
| --- | --- |
| `surface` | Họ hook: `uname`, `sysctl`, `sysctlbyname`, `MG`, `IOKit`, `CFSystem`, `SystemVersion.plist` |
| `key` | Khóa cụ thể app đọc, ví dụ `kern.osproductversion`, `ProductType` |
| `group` | Nhóm nhất quán — mọi hàng cùng `group` phải ra một giá trị |
| `toggle` | Toggle định danh khống chế: `IOSVersion`, `DeviceModel`, `DeviceName` |
| `sourceKind` | Lấy từ `deviceIDs[key]` hay hằng số cố định |
| `deviceIDKey` / `constantValue` | Trường canonical hoặc hằng số |

### Các nhóm nhất quán hiện tại

| Group | Nguồn | Bề mặt |
| --- | --- | --- |
| ProductVersion | `IOSVersion` | CFSystem, SystemVersion.plist, `kern.osproductversion` |
| ProductBuildVersion | `IOSBuild` | CFSystem, SystemVersion.plist, `KERN_OSVERSION`, `kern.osversion`, MG ProductBuildVersion/BuildVersion |
| ReleaseType | hằng `User` | CFSystem, SystemVersion.plist, MG ReleaseType |
| Darwin | `Darwin` | `KERN_OSRELEASE`, `kern.osrelease`, `uname.release` |
| KernelVersion | `KernelVersion` | `KERN_VERSION`, `kern.version`, `uname.version` |
| OSType | hằng `Darwin` | `kern.ostype`, `uname.sysname` |
| DeviceModel | `DeviceModel` | `HW_MACHINE`, `hw.machine`, `hw.product`, MG ProductType, IOKit device-model, `uname.machine` |
| HwModel | `HwModel` | `HW_MODEL`, `hw.model`, MG HWModel/HWModelStr, IOKit model |
| BoardID | `BoardID` | MG BoardId, IOKit board-id |
| ModelNumber | `ModelNumber` | MG ModelNumber, IOKit model-number |
| DeviceName | `DeviceName` | `kern.hostname`, `gethostname`, `uname.nodename` |

## Bài test kiểm tra gì

1. **Well-formed**: `PXConsistencyMatrixIsWellFormed` — mỗi nhóm chỉ dùng một
   nguồn duy nhất (cùng `deviceIDKey`, hoặc cùng hằng số, không trộn) và cùng một
   `toggle`. Không phụ thuộc profile.
2. **Consistent**: `PXValidateConsistencyMatrix` với một profile canonical —
   mọi bề mặt trong một nhóm ra đúng một giá trị; không có nhóm bị chiếu một phần
   (partial projection).
3. **Spot-check**: từng hàng resolve đúng giá trị kỳ vọng của nhóm.
4. **Liên kết IOS-06**: `PXTransformSystemVersionDictionary` cho ProductVersion /
   ProductBuildVersion / ReleaseType phải khớp ma trận, nên bề mặt CoreFoundation /
   plist không thể lệch khỏi sysctl/MG.
5. **Partial guard**: làm rỗng trọn một nhóm (tắt toggle) vẫn nhất quán.
6. **Single-source guard**: hai bề mặt cùng nguồn luôn bằng nhau.

## Cách chạy

Cần macOS/iOS toolchain có `clang` + Foundation. Từ thư mục gốc repo:

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

Kỳ vọng: in `[CONS-01] all consistency tests passed` và thoát mã 0. Bất kỳ
`NSCAssert` nào thất bại sẽ abort kèm nhóm/bề mặt sai.

> Trên Windows/CI không có clang, chạy static contract check thay thế (xem phần dưới).
> Trong repo hiện tại `make`/`clang` chưa có nên build native chưa chạy được.

## Thêm bề mặt mới

1. Thêm một `PXKeyEntry(...)` hoặc `PXConstEntry(...)` vào
   `PXConsistencyMatrixEntries()` với đúng `group` và nguồn.
2. Nếu là sự thật mới, tạo `group` mới và bổ sung kỳ vọng trong
   `expectedByGroup` của test.
3. Chạy lại test. `IsWellFormed` sẽ báo nếu bạn vô tình trộn nguồn trong một nhóm.

## Chẩn đoán khi thất bại

- `group X: deviceIDKey diverges` → hai bề mặt cùng nhóm trỏ khác trường canonical.
- `group X: partial projection` → profile thiếu một trường mà nhóm cần; kiểm tra
  validator (IOS-02) và database (IOS-03).
- `transformer ... diverges from matrix` → IOS-06 và ma trận lệch nhau; đồng bộ lại.
