#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Immutable result of the Phase-2 cross-field validator. Unlike the format
/// validator, a dependency failure rejects the complete publication: providers
/// must keep using the last known-good snapshot or return original values.
@interface PXIdentityDependencyValidationResult : NSObject
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *issues;
@property (nonatomic, readonly, getter=isValid) BOOL valid;
@end

/// Validates the canonical profile against one coherent IOS-03 database set.
/// `buildRoot` is the iosBuildDB root and `modelRoot` is iphoneModelDB.
FOUNDATION_EXPORT PXIdentityDependencyValidationResult *
PXValidateIdentityDependencies(NSDictionary * _Nullable deviceIDs,
                               NSDictionary * _Nullable buildRoot,
                               NSDictionary * _Nullable modelRoot);

NS_ASSUME_NONNULL_END
