#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSInteger const PXKeychainItemIdentitySchemaVersion;
FOUNDATION_EXPORT NSErrorDomain const PXKeychainItemIdentityErrorDomain;
FOUNDATION_EXPORT NSString * const PXKeychainItemIdentityErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXKeychainItemIdentityClass) {
    PXKeychainItemIdentityClassUnknown = 0,
    PXKeychainItemIdentityClassGenericPassword = 1,
    PXKeychainItemIdentityClassInternetPassword = 2,
    PXKeychainItemIdentityClassCertificate = 3,
    PXKeychainItemIdentityClassKey = 4,
    PXKeychainItemIdentityClassIdentity = 5,
};

typedef NS_ERROR_ENUM(PXKeychainItemIdentityErrorDomain,
                      PXKeychainItemIdentityErrorCode) {
    PXKeychainItemIdentityErrorInvalidInput = 1,
    PXKeychainItemIdentityErrorUnsupportedClass = 2,
    PXKeychainItemIdentityErrorMissingAccessGroup = 3,
    PXKeychainItemIdentityErrorInvalidAccessGroup = 4,
    PXKeychainItemIdentityErrorMissingIdentityAttribute = 5,
    PXKeychainItemIdentityErrorInvalidIdentityAttributeType = 6,
    PXKeychainItemIdentityErrorInvalidIdentityAttributeValue = 7,
    PXKeychainItemIdentityErrorInvalidSynchronizable = 8,
    PXKeychainItemIdentityErrorAmbiguousIdentity = 9,
    PXKeychainItemIdentityErrorLimitExceeded = 10,
    PXKeychainItemIdentityErrorSnapshotFailed = 11,
    PXKeychainItemIdentityErrorInternalInvariantFailed = 12,
};

__attribute__((objc_subclassing_restricted))
@interface PXKeychainItemIdentity : NSObject <NSCopying>

@property (nonatomic, readonly) NSInteger schemaVersion;
@property (nonatomic, readonly) PXKeychainItemIdentityClass itemClass;
@property (nonatomic, copy, readonly) NSString *className;
@property (nonatomic, copy, readonly) NSString *accessGroup;
@property (nonatomic, readonly, getter=isSynchronizable) BOOL synchronizable;
@property (nonatomic, copy, readonly) NSArray<NSString *> *identityAttributeNames;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *identityAttributes;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *matchQuery;

+ (nullable instancetype)identityForSecurityItemAttributes:(NSDictionary<NSString *, id> *)attributes
                                                     error:(NSError **)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
