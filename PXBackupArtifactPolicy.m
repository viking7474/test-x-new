#import "PXBackupArtifactPolicy.h"

@interface PXBackupArtifactPolicy ()

- (instancetype)initWithKind:(PXBackupArtifactKind)kind
                 requirement:(PXBackupArtifactRequirement)requirement
          failureDisposition:(PXBackupArtifactFailureDisposition)failureDisposition
             emptyFilePolicy:(PXBackupArtifactEmptyFilePolicy)emptyFilePolicy
           requiredPOSIXMode:(NSUInteger)requiredPOSIXMode
   dataProtectionRequirement:(PXBackupArtifactDataProtectionRequirement)dataProtectionRequirement;

@end

@implementation PXBackupArtifactPolicy {
    PXBackupArtifactKind _kind;
    PXBackupArtifactRequirement _requirement;
    PXBackupArtifactFailureDisposition _failureDisposition;
    PXBackupArtifactEmptyFilePolicy _emptyFilePolicy;
    NSUInteger _requiredPOSIXMode;
    PXBackupArtifactDataProtectionRequirement _dataProtectionRequirement;
}

+ (nullable instancetype)policyForKind:(PXBackupArtifactKind)kind {
    PXBackupArtifactRequirement requirement = PXBackupArtifactRequirementOptional;
    PXBackupArtifactFailureDisposition failureDisposition =
        PXBackupArtifactFailureDispositionContinueWithoutWarning;
    PXBackupArtifactEmptyFilePolicy emptyFilePolicy =
        PXBackupArtifactEmptyFilePolicyReject;
    NSUInteger requiredPOSIXMode = 0600;
    PXBackupArtifactDataProtectionRequirement dataProtectionRequirement =
        PXBackupArtifactDataProtectionRequirementUnspecified;

    switch (kind) {
        case PXBackupArtifactKindApplicationData:
            requirement = PXBackupArtifactRequirementRequired;
            failureDisposition = PXBackupArtifactFailureDispositionAbortBackup;
            emptyFilePolicy = PXBackupArtifactEmptyFilePolicyReject;
            break;
        case PXBackupArtifactKindAppGroup:
        case PXBackupArtifactKindProfileAppData:
        case PXBackupArtifactKindGlobalSafari:
        case PXBackupArtifactKindSystemGlobal:
            requirement = PXBackupArtifactRequirementOptional;
            failureDisposition = PXBackupArtifactFailureDispositionWarnAndContinue;
            emptyFilePolicy = PXBackupArtifactEmptyFilePolicyReject;
            break;
        case PXBackupArtifactKindSharedSystemDatabase:
            requirement = PXBackupArtifactRequirementOptional;
            failureDisposition =
                PXBackupArtifactFailureDispositionContinueWithoutWarning;
            emptyFilePolicy = PXBackupArtifactEmptyFilePolicyAllow;
            break;
        case PXBackupArtifactKindPreferences:
            requirement = PXBackupArtifactRequirementOptional;
            failureDisposition =
                PXBackupArtifactFailureDispositionContinueWithoutWarning;
            emptyFilePolicy = PXBackupArtifactEmptyFilePolicyReject;
            break;
        case PXBackupArtifactKindKeychain:
            requirement = PXBackupArtifactRequirementOptional;
            failureDisposition = PXBackupArtifactFailureDispositionWarnAndContinue;
            emptyFilePolicy = PXBackupArtifactEmptyFilePolicyReject;
            dataProtectionRequirement =
                PXBackupArtifactDataProtectionRequirementComplete;
            break;
        default:
            return nil;
    }

    return [[PXBackupArtifactPolicy alloc] initWithKind:kind
                         requirement:requirement
                  failureDisposition:failureDisposition
                     emptyFilePolicy:emptyFilePolicy
                   requiredPOSIXMode:requiredPOSIXMode
           dataProtectionRequirement:dataProtectionRequirement];
}

- (instancetype)initWithKind:(PXBackupArtifactKind)kind
                 requirement:(PXBackupArtifactRequirement)requirement
          failureDisposition:(PXBackupArtifactFailureDisposition)failureDisposition
             emptyFilePolicy:(PXBackupArtifactEmptyFilePolicy)emptyFilePolicy
           requiredPOSIXMode:(NSUInteger)requiredPOSIXMode
   dataProtectionRequirement:(PXBackupArtifactDataProtectionRequirement)dataProtectionRequirement {
    self = [super init];
    if (self) {
        _kind = kind;
        _requirement = requirement;
        _failureDisposition = failureDisposition;
        _emptyFilePolicy = emptyFilePolicy;
        _requiredPOSIXMode = requiredPOSIXMode;
        _dataProtectionRequirement = dataProtectionRequirement;
    }
    return self;
}

- (PXBackupArtifactKind)kind { return _kind; }
- (PXBackupArtifactRequirement)requirement { return _requirement; }
- (PXBackupArtifactFailureDisposition)failureDisposition {
    return _failureDisposition;
}
- (PXBackupArtifactEmptyFilePolicy)emptyFilePolicy { return _emptyFilePolicy; }
- (NSUInteger)requiredPOSIXMode { return _requiredPOSIXMode; }
- (PXBackupArtifactDataProtectionRequirement)dataProtectionRequirement {
    return _dataProtectionRequirement;
}

- (BOOL)acceptsFileSize:(unsigned long long)fileSize {
    return fileSize > 0 ||
           self.emptyFilePolicy == PXBackupArtifactEmptyFilePolicyAllow;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[PXBackupArtifactPolicy class]]) {
        return NO;
    }
    PXBackupArtifactPolicy *other = object;
    return self.kind == other.kind &&
           self.requirement == other.requirement &&
           self.failureDisposition == other.failureDisposition &&
           self.emptyFilePolicy == other.emptyFilePolicy &&
           self.requiredPOSIXMode == other.requiredPOSIXMode &&
           self.dataProtectionRequirement == other.dataProtectionRequirement;
}

- (NSUInteger)hash {
    NSUInteger value = (NSUInteger)self.kind;
    value ^= (NSUInteger)self.requirement + (NSUInteger)0x9e3779b9 +
             (value << 6) + (value >> 2);
    value ^= (NSUInteger)self.failureDisposition + (NSUInteger)0x9e3779b9 +
             (value << 6) + (value >> 2);
    value ^= (NSUInteger)self.emptyFilePolicy + (NSUInteger)0x9e3779b9 +
             (value << 6) + (value >> 2);
    value ^= self.requiredPOSIXMode + (NSUInteger)0x9e3779b9 +
             (value << 6) + (value >> 2);
    value ^= (NSUInteger)self.dataProtectionRequirement + (NSUInteger)0x9e3779b9 +
             (value << 6) + (value >> 2);
    return value;
}

@end
