#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const PXIdentityValidationErrorDomain;

typedef NS_ENUM(NSInteger, PXIdentityValueKind) {
    PXIdentityValueKindUUID = 1,
    PXIdentityValueKindUDID,
    PXIdentityValueKindIMEI,
    PXIdentityValueKindMEID,
    PXIdentityValueKindSerialNumber,
    PXIdentityValueKindDeviceModel,
    PXIdentityValueKindMACAddress,
    PXIdentityValueKindSSID,
    PXIdentityValueKindDeviceName,
    PXIdentityValueKindIOSVersion,
    PXIdentityValueKindIOSBuild,
    PXIdentityValueKindUnsignedDecimal,
};

/// Immutable output of the unified profile validator. Invalid managed fields are
/// omitted from deviceIDs so runtime hooks fail open instead of publishing malformed
/// spoof values. Unknown fields are preserved for forward compatibility.
@interface PXIdentityValidationResult : NSObject {
@private
    NSDictionary *_deviceIDs;
    NSDictionary *_issues;
    BOOL _inputValid;
}
@property (nonatomic, copy, readonly) NSDictionary *deviceIDs;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *issues;
@property (nonatomic, readonly, getter=isInputValid) BOOL inputValid;
@end

/// Returns a canonical string or nil. UUIDs become uppercase 8-4-4-4-12,
/// UDIDs lowercase hex, MEIDs/MAC/build values uppercase, and whitespace is trimmed.
FOUNDATION_EXPORT NSString * _Nullable PXCanonicalIdentityValue(id _Nullable value,
                                                                PXIdentityValueKind kind,
                                                                BOOL allowZeroUUID);
FOUNDATION_EXPORT BOOL PXValidateIdentityValue(id _Nullable value,
                                               PXIdentityValueKind kind,
                                               BOOL allowZeroUUID);

/// Validates and canonicalizes every managed field in device_ids.plist in one pass.
/// Cross-field rules (currently ATT/IDFA and iOS version/build) are applied here.
FOUNDATION_EXPORT PXIdentityValidationResult *PXValidateDeviceIDs(NSDictionary * _Nullable deviceIDs);

NS_ASSUME_NONNULL_END
