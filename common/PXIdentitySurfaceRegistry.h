#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// HOOK-02 / HOOK-03: one registry for MobileGestalt and IORegistry aliases.
typedef NS_OPTIONS(NSUInteger, PXIdentitySurfaceMask) {
    PXIdentitySurfaceMobileGestalt = 1u << 0,
    PXIdentitySurfaceIORegistry = 1u << 1,
    PXIdentitySurfaceManagedConfiguration = 1u << 2,
    PXIdentitySurfaceCoreTelephonyServer = 1u << 3,
    PXIdentitySurfacePrivateWrapper = 1u << 4,
};

typedef NS_ENUM(NSUInteger, PXIdentityExpectedType) {
    PXIdentityExpectedTypeString = 1,
    PXIdentityExpectedTypeData,
    PXIdentityExpectedTypeStringOrData,
    PXIdentityExpectedTypeStringOrDataArray,
};

@interface PXIdentitySurfaceEntry : NSObject
@property (nonatomic, copy, readonly) NSString *canonicalKey;
@property (nonatomic, copy, readonly) NSArray<NSString *> *aliases;
@property (nonatomic, copy, readonly) NSString *toggle;
@property (nonatomic, copy, readonly, nullable) NSString *deviceIDKey;
@property (nonatomic, copy, readonly, nullable) NSString *constantValue;
@property (nonatomic, readonly) PXIdentitySurfaceMask surfaces;
@property (nonatomic, readonly) PXIdentityExpectedType expectedType;
@end

FOUNDATION_EXPORT NSArray<PXIdentitySurfaceEntry *> *PXIdentitySurfaceRegistryEntries(void);
FOUNDATION_EXPORT PXIdentitySurfaceEntry * _Nullable PXIdentitySurfaceEntryForKey(NSString *key,
                                                                                  PXIdentitySurfaceMask surface);
FOUNDATION_EXPORT NSString * _Nullable PXIdentitySurfaceResolveValue(PXIdentitySurfaceEntry *entry,
                                                                      NSDictionary *deviceIDs);
FOUNDATION_EXPORT BOOL PXIdentitySurfaceRegistryIsWellFormed(NSArray<NSString *> * _Nullable * _Nullable failures);

NS_ASSUME_NONNULL_END
