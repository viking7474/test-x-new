#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Cold create-path ownership only. A reservation never removes a directory,
/// adopts an existing path, or treats its marker as proof of a ready profile.
@interface PXProfileCreationReservation : NSObject
@property (nonatomic, copy, readonly) NSString *profileID;
@property (nonatomic, copy, readonly) NSString *identityDirectory;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
/// Validate/freeze display metadata before creating anything. DisplayName and
/// matching Identifier are strings; Description is an optional string. Extra
/// fields must be property-list values. Keeps the historical XML file format.
+ (nullable instancetype)reserveProfileID:(NSString *)profileID
                     inProfilesDirectory:(NSString *)directory
                                metadata:(NSDictionary *)metadata
                                   error:(NSError * _Nullable * _Nullable)error;
/// Checks root/profile/identity plus marker and display-file inode/raw bytes
/// against held descriptors. A changed display record invalidates creation too.
/// Does not lock out legacy deletion/path mutation after this check returns.
- (BOOL)validateWithError:(NSError * _Nullable * _Nullable)error;
@end

NS_ASSUME_NONNULL_END
