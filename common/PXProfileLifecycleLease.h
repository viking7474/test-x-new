#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Nonblocking, process-shared ownership for cooperating profile lifecycle APIs.
/// Acquire before source transactions; never acquire from inside a source gate.
/// Keep the object alive across async creation, release before user completion.
@interface PXProfileLifecycleLease : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
+ (nullable instancetype)acquireInDirectory:(NSString *)directory error:(NSError * _Nullable * _Nullable)error NS_RETURNS_RETAINED;
/// Explicitly closes ownership before a completion/reentrant caller runs.
- (void)invalidate;
- (BOOL)validateWithError:(NSError * _Nullable * _Nullable)error;
/// Raw bytes plus explicit absence, independent of archive object mutation.
- (nullable NSDictionary *)readRegistryWithError:(NSError * _Nullable * _Nullable)error;
- (BOOL)writeRegistryData:(NSData *)data expected:(NSDictionary *)expected error:(NSError * _Nullable * _Nullable)error;
- (nullable NSDictionary *)directoryProofForProfileID:(NSString *)profileID error:(NSError * _Nullable * _Nullable)error;
/// Caller must first commit removal from registry and a selection away from ID.
/// Failure never authorizes deleting a replacement directory on a later retry.
- (BOOL)removeDirectoryForProfileID:(NSString *)profileID proof:(NSDictionary *)proof error:(NSError * _Nullable * _Nullable)error;
@end
NS_ASSUME_NONNULL_END
