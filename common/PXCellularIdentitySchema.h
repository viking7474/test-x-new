#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, PXCellularCapability) {
    PXCellularCapabilityNone = 0,
    PXCellularCapabilityPhysicalSIM = 1UL << 0,
    PXCellularCapabilityESIM = 1UL << 1,
    PXCellularCapabilityDualSIM = 1UL << 2,
    PXCellularCapabilityCDMA = 1UL << 3,
};

@interface PXCellularIdentityValidationResult : NSObject
@property (nonatomic, readonly, getter=isValid) BOOL valid;
@property (nonatomic, readonly) PXCellularCapability capabilities;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *issues;
@property (nonatomic, copy, readonly) NSDictionary *canonicalDeviceIDs;
@end

FOUNDATION_EXPORT PXCellularIdentityValidationResult *PXValidateCellularIdentitySchema(NSDictionary * _Nullable deviceIDs,
                                                                                       NSDictionary * _Nullable modelRecord);

NS_ASSUME_NONNULL_END
