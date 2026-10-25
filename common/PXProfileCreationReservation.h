#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Cold create-path ownership only. A reservation never removes a directory,
/// adopts an existing path, or treats its marker as proof of a ready profile.
@interface PXProfileCreationReservation : NSObject
@property (nonatomic, copy, readonly) NSString *profileID;
@property (nonatomic, copy, readonly) NSString *identityDirectory;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
+ (nullable instancetype)reserveProfileID:(NSString *)profileID
                     inProfilesDirectory:(NSString *)directory
                                metadata:(NSDictionary *)metadata
                                   error:(NSError * _Nullable * _Nullable)error;
/// Checks the root, profile, identity and marker against the held descriptors.
/// Does not lock out legacy deletion/path mutation after this check returns.
- (BOOL)validateWithError:(NSError * _Nullable * _Nullable)error;
@end

NS_ASSUME_NONNULL_END
