#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, PXBackupArtifactKind) {
    PXBackupArtifactKindApplicationData = 1,
    PXBackupArtifactKindAppGroup = 2,
    PXBackupArtifactKindProfileAppData = 3,
    PXBackupArtifactKindGlobalSafari = 4,
    PXBackupArtifactKindSystemGlobal = 5,
    PXBackupArtifactKindSharedSystemDatabase = 6,
    PXBackupArtifactKindPreferences = 7,
    PXBackupArtifactKindKeychain = 8,
};

typedef NS_ENUM(NSUInteger, PXBackupArtifactRequirement) {
    PXBackupArtifactRequirementRequired = 1,
    PXBackupArtifactRequirementOptional = 2,
};

typedef NS_ENUM(NSUInteger, PXBackupArtifactFailureDisposition) {
    PXBackupArtifactFailureDispositionAbortBackup = 1,
    PXBackupArtifactFailureDispositionWarnAndContinue = 2,
    PXBackupArtifactFailureDispositionContinueWithoutWarning = 3,
};

typedef NS_ENUM(NSUInteger, PXBackupArtifactEmptyFilePolicy) {
    PXBackupArtifactEmptyFilePolicyReject = 1,
    PXBackupArtifactEmptyFilePolicyAllow = 2,
};

__attribute__((objc_subclassing_restricted))
@interface PXBackupArtifactPolicy : NSObject <NSCopying>

@property (nonatomic, readonly) PXBackupArtifactKind kind;
@property (nonatomic, readonly) PXBackupArtifactRequirement requirement;
@property (nonatomic, readonly) PXBackupArtifactFailureDisposition failureDisposition;
@property (nonatomic, readonly) PXBackupArtifactEmptyFilePolicy emptyFilePolicy;

+ (nullable instancetype)policyForKind:(PXBackupArtifactKind)kind;

- (BOOL)acceptsFileSize:(unsigned long long)fileSize;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
