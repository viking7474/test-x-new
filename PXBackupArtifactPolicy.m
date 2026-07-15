#import "PXBackupArtifactPolicy.h"

@interface PXBackupArtifactPolicy ()

- (instancetype)initWithKind:(PXBackupArtifactKind)kind
                 requirement:(PXBackupArtifactRequirement)requirement
          failureDisposition:(PXBackupArtifactFailureDisposition)failureDisposition
             emptyFilePolicy:(PXBackupArtifactEmptyFilePolicy)emptyFilePolicy;

@end

@implementation PXBackupArtifactPolicy {
    PXBackupArtifactKind _kind;
    PXBackupArtifactRequirement _requirement;
    PXBackupArtifactFailureDisposition _failureDisposition;
    PXBackupArtifactEmptyFilePolicy _emptyFilePolicy;
}

+ (nullable instancetype)policyForKind:(PXBackupArtifactKind)kind {
    PXBackupArtifactRequirement requirement = PXBackupArtifactRequirementOptional;
    PXBackupArtifactFailureDisposition failureDisposition =
        PXBackupArtifactFailureDispositionContinueWithoutWarning;
    PXBackupArtifactEmptyFilePolicy emptyFilePolicy =
        PXBackupArtifactEmptyFilePolicyReject;

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
        case PXBackupArtifactKindKeychain:
            requirement = PXBackupArtifactRequirementOptional;
            failureDisposition =
                PXBackupArtifactFailureDispositionContinueWithoutWarning;
            emptyFilePolicy = PXBackupArtifactEmptyFilePolicyReject;
            break;
        default:
            return nil;
    }

    return [[PXBackupArtifactPolicy alloc] initWithKind:kind
                         requirement:requirement
                  failureDisposition:failureDisposition
                     emptyFilePolicy:emptyFilePolicy];
}

- (instancetype)initWithKind:(PXBackupArtifactKind)kind
                 requirement:(PXBackupArtifactRequirement)requirement
          failureDisposition:(PXBackupArtifactFailureDisposition)failureDisposition
             emptyFilePolicy:(PXBackupArtifactEmptyFilePolicy)emptyFilePolicy {
    self = [super init];
    if (self) {
        _kind = kind;
        _requirement = requirement;
        _failureDisposition = failureDisposition;
        _emptyFilePolicy = emptyFilePolicy;
    }
    return self;
}

- (PXBackupArtifactKind)kind { return _kind; }
- (PXBackupArtifactRequirement)requirement { return _requirement; }
- (PXBackupArtifactFailureDisposition)failureDisposition {
    return _failureDisposition;
}
- (PXBackupArtifactEmptyFilePolicy)emptyFilePolicy { return _emptyFilePolicy; }

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
           self.emptyFilePolicy == other.emptyFilePolicy;
}

- (NSUInteger)hash {
    NSUInteger value = (NSUInteger)self.kind;
    value ^= (NSUInteger)self.requirement + (NSUInteger)0x9e3779b9 +
             (value << 6) + (value >> 2);
    value ^= (NSUInteger)self.failureDisposition + (NSUInteger)0x9e3779b9 +
             (value << 6) + (value >> 2);
    value ^= (NSUInteger)self.emptyFilePolicy + (NSUInteger)0x9e3779b9 +
             (value << 6) + (value >> 2);
    return value;
}

@end
