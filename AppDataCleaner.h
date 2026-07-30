#import <Foundation/Foundation.h>
#import "PXClearRequest.h"

@interface AppDataCleaner : NSObject

+ (instancetype)sharedManager;

#pragma mark - Main Public Methods

// Clear all data for a specific app using the persisted Full/Deep preference.
- (void)clearDataForBundleID:(NSString *)bundleID
                 completion:(void (^)(BOOL success, NSError *error))completion;

// Explicit Phase-8 Quick/Full/Deep execution policy.
- (void)clearDataForBundleID:(NSString *)bundleID
                        mode:(PXClearMode)mode
                  completion:(void (^)(BOOL success, NSError *error))completion;

// Check if app has any data to clear
- (BOOL)hasDataToClear:(NSString *)bundleID;

#pragma mark - Comprehensive Cleanup Methods

- (void)completeAppDataWipe:(NSString *)bundleID;

#pragma mark - Enhanced Container Cleaning
- (void)cleanIconStatePlist:(NSString *)bundleID;
- (void)cleanSiriAnalyticsDatabase:(NSString *)bundleID;
- (void)cleanLaunchServicesDatabase:(NSString *)bundleID;
- (void)refreshSystemServices;

#pragma mark - Standard App Data Cleaning
- (void)clearAppReceiptData:(NSString *)bundleID withBundleUUID:(NSString *)bundleUUID;

#pragma mark - System Storage Cleaning

#pragma mark - Hidden Storage Cleaning
- (void)clearSystemLogs:(NSString *)bundleID;

#pragma mark - Network & Carrier Cleaning

#pragma mark - Additional Storage Cleaning
- (void)clearICloudData:(NSString *)bundleID;
- (void)clearMediaData:(NSString *)bundleID;
- (void)clearHealthData:(NSString *)bundleID;
- (void)clearSafariData:(NSString *)bundleID;

#pragma mark - Cache & Residual Cleaning

#pragma mark - Advanced Cleaning Methods
- (void)clearURLCredentialsForBundleID:(NSString *)bundleID;
- (void)clearSpotlightIndexes:(NSString *)bundleID;

#pragma mark - System Integration

#pragma mark - Data Persistence
- (void)clearClipboard;

#pragma mark - State Management
- (void)_internalClearAppStateData:(NSString *)bundleID;

#pragma mark - Security Methods
- (BOOL)verifyDataCleared:(NSString *)bundleID;
- (NSDictionary *)getDataUsage:(NSString *)bundleID;

#pragma mark - Container Discovery Methods
- (NSString *)findDataContainerUUIDForBundleID:(NSString *)bundleID;
- (NSString *)findBundleContainerUUIDForBundleID:(NSString *)bundleID;
- (NSArray *)findGroupContainerUUIDsForBundleID:(NSString *)bundleID;
- (NSArray *)findExtensionDataContainersForBundleID:(NSString *)bundleID;
- (BOOL)hasKeychainItemsForBundleID:(NSString *)bundleID;

@end
