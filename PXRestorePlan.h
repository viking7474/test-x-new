#import <Foundation/Foundation.h>

@class PXResolvedContainer;
@class PXVerifiedBackupArtifactSet;
@class PXValidatedBackupArchiveSet;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const PXRestorePlanErrorDomain;
FOUNDATION_EXPORT NSString * const PXRestorePlanErrorFieldPathKey;

typedef NS_ENUM(NSInteger, PXRestorePlanErrorCode) {
    PXRestorePlanErrorInvalidInput = 1,
    PXRestorePlanErrorInconsistentSnapshot = 2,
    PXRestorePlanErrorMissingArtifact = 3,
    PXRestorePlanErrorUnvalidatedArchive = 4,
    PXRestorePlanErrorUnsafeRelativeDestination = 5,
    PXRestorePlanErrorDuplicateDestination = 6,
    PXRestorePlanErrorInvalidComponent = 7,
    PXRestorePlanErrorLimitExceeded = 8,
};

__attribute__((objc_subclassing_restricted))
@interface PXRestorePlanAppGroupItem : NSObject <NSCopying>
@property (nonatomic, copy, readonly) NSString *groupIdentifier;
@property (nonatomic, copy, readonly) NSString *archiveName;
@property (nonatomic, copy, readonly) NSString *sourcePath;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

__attribute__((objc_subclassing_restricted))
@interface PXRestorePlanSystemGlobalItem : NSObject <NSCopying>
@property (nonatomic, copy, readonly) NSString *librarySubdirectory;
@property (nonatomic, copy, readonly) NSString *archiveName;
@property (nonatomic, copy, readonly) NSString *sourcePath;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

__attribute__((objc_subclassing_restricted))
@interface PXRestorePlanSharedDatabaseItem : NSObject <NSCopying>
@property (nonatomic, copy, readonly) NSString *libraryRelativePath;
@property (nonatomic, copy, readonly) NSString *artifactName;
@property (nonatomic, copy, readonly) NSString *sourcePath;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

__attribute__((objc_subclassing_restricted))
@interface PXRestorePlan : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *bundleIdentifier;

@property (nonatomic, strong, readonly) PXResolvedContainer *applicationDataContainer;
@property (nonatomic, copy, readonly) NSString *applicationDataPath;
@property (nonatomic, copy, readonly) NSString *applicationDataUUID;
@property (nonatomic, copy, readonly) NSString *dataArchiveName;
@property (nonatomic, copy, readonly) NSString *dataArchivePath;

@property (nonatomic, assign, readonly) BOOL includesAppGroups;
@property (nonatomic, copy, readonly) NSArray<PXRestorePlanAppGroupItem *> *appGroupItems;
- (nullable PXRestorePlanAppGroupItem *)appGroupItemForIdentifier:(NSString *)groupIdentifier;

@property (nonatomic, assign, readonly) BOOL includesPreferences;
@property (nonatomic, copy, nullable, readonly) NSString *preferencesArtifactName;
@property (nonatomic, copy, nullable, readonly) NSString *preferencesSourcePath;

@property (nonatomic, assign, readonly) BOOL includesKeychain;
@property (nonatomic, copy, nullable, readonly) NSString *keychainArtifactName;
@property (nonatomic, copy, nullable, readonly) NSString *keychainSourcePath;
@property (nonatomic, copy, readonly) NSArray<NSString *> *keychainGroups;
@property (nonatomic, copy, readonly) NSString *keychainMethod;
@property (nonatomic, assign, readonly) BOOL keychainUsesInAppMethod;

@property (nonatomic, assign, readonly) BOOL includesProfileAppData;
@property (nonatomic, copy, nullable, readonly) NSString *profileAppDataArchiveName;
@property (nonatomic, copy, nullable, readonly) NSString *profileAppDataSourcePath;

@property (nonatomic, assign, readonly) BOOL includesGlobalSafari;
@property (nonatomic, copy, nullable, readonly) NSString *globalSafariArchiveName;
@property (nonatomic, copy, nullable, readonly) NSString *globalSafariSourcePath;

@property (nonatomic, copy, readonly) NSArray<PXRestorePlanSystemGlobalItem *> *systemGlobalItems;
@property (nonatomic, copy, readonly) NSArray<PXRestorePlanSharedDatabaseItem *> *sharedDatabaseItems;

@property (nonatomic, assign, readonly) NSUInteger manifestWarningCount;
@property (nonatomic, copy, nullable, readonly) NSString *manifestProfileIdentifier;

@property (nonatomic, strong, readonly) PXVerifiedBackupArtifactSet *verifiedArtifacts;
@property (nonatomic, strong, readonly) PXValidatedBackupArchiveSet *validatedArchives;

+ (nullable instancetype)planForManifest:(NSDictionary *)manifest
               requestedBundleIdentifier:(NSString *)bundleIdentifier
                 applicationDataContainer:(PXResolvedContainer *)applicationDataContainer
                      applicationDataPath:(NSString *)applicationDataPath
                        verifiedArtifacts:(PXVerifiedBackupArtifactSet *)verifiedArtifacts
                        validatedArchives:(PXValidatedBackupArchiveSet *)validatedArchives
                                    error:(NSError * _Nullable * _Nullable)error;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
