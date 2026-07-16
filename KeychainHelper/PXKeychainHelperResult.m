#import "PXKeychainHelperResult.h"
#import <CoreFoundation/CoreFoundation.h>

NSInteger const PXKeychainHelperResultSchemaVersion = 1;
NSString * const PXKeychainHelperResultOutputPrefix = @"PXKEYCHAIN_HELPER_RESULT_V1=";
NSErrorDomain const PXKeychainHelperResultErrorDomain = @"com.hydra.projectx.keychain-helper-result";
NSString * const PXKeychainHelperResultErrorFieldPathKey = @"fieldPath";

static const NSUInteger PXKeychainHelperResultMaximumCount = 1000000;
static const NSUInteger PXKeychainHelperResultMaximumFatalDomainBytes = 255;
static const NSUInteger PXKeychainHelperResultMaximumBinaryPlistBytes = 16 * 1024;
static const NSUInteger PXKeychainHelperResultMaximumBase64Bytes = 24 * 1024;
static const NSUInteger PXKeychainHelperResultMaximumOutputLineBytes = 25 * 1024;

static void PXKeychainHelperResultSetError(NSError **error,
                                            PXKeychainHelperResultErrorCode code,
                                            NSString *fieldPath,
                                            NSString *description) {
    if (!error) {
        return;
    }
    *error = [NSError errorWithDomain:PXKeychainHelperResultErrorDomain
                                 code:code
                             userInfo:@{
                                 NSLocalizedDescriptionKey: description,
                                 PXKeychainHelperResultErrorFieldPathKey: fieldPath,
                             }];
}

static NSString *PXKeychainHelperOperationString(PXKeychainHelperOperation operation) {
    switch (operation) {
        case PXKeychainHelperOperationUnknown:
            return @"unknown";
        case PXKeychainHelperOperationBackup:
            return @"backup";
        case PXKeychainHelperOperationRestore:
            return @"restore";
        case PXKeychainHelperOperationWipe:
            return @"wipe";
        case PXKeychainHelperOperationList:
            return @"list";
    }
    return nil;
}

static NSString *PXKeychainHelperCompletionString(PXKeychainHelperCompletion completion) {
    switch (completion) {
        case PXKeychainHelperCompletionFailed:
            return @"failed";
        case PXKeychainHelperCompletionCompleted:
            return @"completed";
        case PXKeychainHelperCompletionPartial:
            return @"partial";
    }
    return nil;
}

static BOOL PXKeychainHelperResultCountIsWithinLimit(NSUInteger count) {
    return count <= PXKeychainHelperResultMaximumCount;
}

static BOOL PXKeychainHelperResultCountsFitAttempted(NSUInteger attemptedCount,
                                                      NSUInteger succeededCount,
                                                      NSUInteger failedCount,
                                                      NSUInteger skippedCount) {
    if (succeededCount > attemptedCount) {
        return NO;
    }
    NSUInteger remaining = attemptedCount - succeededCount;
    if (failedCount > remaining) {
        return NO;
    }
    remaining -= failedCount;
    return skippedCount <= remaining;
}

static BOOL PXKeychainHelperResultFatalDomainIsValid(NSString *domain,
                                                      NSUInteger *byteCountOut) {
    if (![domain isKindOfClass:[NSString class]] || domain.length == 0) {
        return NO;
    }
    NSData *utf8 = [domain dataUsingEncoding:NSUTF8StringEncoding
                        allowLossyConversion:NO];
    if (!utf8 || utf8.length == 0) {
        return NO;
    }
    NSString *roundTrip = [[NSString alloc] initWithData:utf8
                                                 encoding:NSUTF8StringEncoding];
    if (!roundTrip || ![roundTrip isEqualToString:domain]) {
        return NO;
    }
    unichar nulCharacter = 0;
    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
    if ([domain rangeOfString:nulString].location != NSNotFound ||
        [domain rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound) {
        return NO;
    }
    if (byteCountOut) {
        *byteCountOut = utf8.length;
    }
    return YES;
}

static BOOL PXKeychainHelperResultIsNumber(id value) {
    return [value isKindOfClass:[NSNumber class]] &&
           CFGetTypeID((__bridge CFTypeRef)value) == CFNumberGetTypeID();
}

static BOOL PXKeychainHelperResultIsBoolean(id value) {
    return [value isKindOfClass:[NSNumber class]] &&
           CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

static BOOL PXKeychainHelperResultRepresentationMatchesState(
    NSDictionary<NSString *, id> *representation,
    PXKeychainHelperOperation operation,
    PXKeychainHelperCompletion completion,
    NSUInteger attemptedCount,
    NSUInteger succeededCount,
    NSUInteger failedCount,
    NSUInteger skippedCount,
    NSUInteger warningCount,
    NSUInteger errorCount,
    BOOL fatalErrorPresent,
    NSString *fatalErrorDomain,
    NSInteger fatalErrorCode) {
    if (![representation isKindOfClass:[NSDictionary class]] || representation.count != 10) {
        return NO;
    }
    NSSet<NSString *> *rootKeys = [NSSet setWithArray:@[
        @"schemaVersion",
        @"operation",
        @"completion",
        @"attemptedCount",
        @"succeededCount",
        @"failedCount",
        @"skippedCount",
        @"warningCount",
        @"errorCount",
        @"fatalError",
    ]];
    if (![[NSSet setWithArray:representation.allKeys] isEqualToSet:rootKeys]) {
        return NO;
    }

    NSNumber *schemaNumber = representation[@"schemaVersion"];
    NSString *operationString = representation[@"operation"];
    NSString *completionString = representation[@"completion"];
    NSNumber *attemptedNumber = representation[@"attemptedCount"];
    NSNumber *succeededNumber = representation[@"succeededCount"];
    NSNumber *failedNumber = representation[@"failedCount"];
    NSNumber *skippedNumber = representation[@"skippedCount"];
    NSNumber *warningNumber = representation[@"warningCount"];
    NSNumber *errorNumber = representation[@"errorCount"];
    NSDictionary<NSString *, id> *fatalRepresentation = representation[@"fatalError"];

    if (!PXKeychainHelperResultIsNumber(schemaNumber) ||
        schemaNumber.integerValue != PXKeychainHelperResultSchemaVersion ||
        ![operationString isEqualToString:PXKeychainHelperOperationString(operation)] ||
        ![completionString isEqualToString:PXKeychainHelperCompletionString(completion)] ||
        !PXKeychainHelperResultIsNumber(attemptedNumber) ||
        attemptedNumber.unsignedIntegerValue != attemptedCount ||
        !PXKeychainHelperResultIsNumber(succeededNumber) ||
        succeededNumber.unsignedIntegerValue != succeededCount ||
        !PXKeychainHelperResultIsNumber(failedNumber) ||
        failedNumber.unsignedIntegerValue != failedCount ||
        !PXKeychainHelperResultIsNumber(skippedNumber) ||
        skippedNumber.unsignedIntegerValue != skippedCount ||
        !PXKeychainHelperResultIsNumber(warningNumber) ||
        warningNumber.unsignedIntegerValue != warningCount ||
        !PXKeychainHelperResultIsNumber(errorNumber) ||
        errorNumber.unsignedIntegerValue != errorCount ||
        ![fatalRepresentation isKindOfClass:[NSDictionary class]] ||
        fatalRepresentation.count != 3) {
        return NO;
    }

    NSSet<NSString *> *fatalKeys = [NSSet setWithArray:@[
        @"present",
        @"domain",
        @"code",
    ]];
    if (![[NSSet setWithArray:fatalRepresentation.allKeys] isEqualToSet:fatalKeys]) {
        return NO;
    }

    NSNumber *presentNumber = fatalRepresentation[@"present"];
    NSString *domain = fatalRepresentation[@"domain"];
    NSNumber *codeNumber = fatalRepresentation[@"code"];
    return PXKeychainHelperResultIsBoolean(presentNumber) &&
           presentNumber.boolValue == fatalErrorPresent &&
           [domain isKindOfClass:[NSString class]] &&
           [domain isEqualToString:fatalErrorDomain] &&
           PXKeychainHelperResultIsNumber(codeNumber) &&
           codeNumber.integerValue == fatalErrorCode;
}

@interface PXKeychainHelperResult ()

- (instancetype)px_initWithOperation:(PXKeychainHelperOperation)operation
                          completion:(PXKeychainHelperCompletion)completion
                      attemptedCount:(NSUInteger)attemptedCount
                      succeededCount:(NSUInteger)succeededCount
                         failedCount:(NSUInteger)failedCount
                        skippedCount:(NSUInteger)skippedCount
                        warningCount:(NSUInteger)warningCount
                          errorCount:(NSUInteger)errorCount
                   fatalErrorPresent:(BOOL)fatalErrorPresent
                    fatalErrorDomain:(NSString *)fatalErrorDomain
                      fatalErrorCode:(NSInteger)fatalErrorCode
          propertyListRepresentation:(NSDictionary<NSString *, id> *)propertyListRepresentation
                 machineReadableLine:(NSString *)machineReadableLine;

@end

@implementation PXKeychainHelperResult

+ (instancetype)resultWithOperation:(PXKeychainHelperOperation)operation
                         completion:(PXKeychainHelperCompletion)completion
                     attemptedCount:(NSUInteger)attemptedCount
                     succeededCount:(NSUInteger)succeededCount
                        failedCount:(NSUInteger)failedCount
                       skippedCount:(NSUInteger)skippedCount
                       warningCount:(NSUInteger)warningCount
                         errorCount:(NSUInteger)errorCount
                         fatalError:(NSError *)fatalError
                              error:(NSError **)error {
    if (error) {
        *error = nil;
    }

    NSString *operationString = PXKeychainHelperOperationString(operation);
    if (!operationString) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorInvalidOperation,
                                       @"$.operation",
                                       @"The helper operation is invalid.");
        return nil;
    }
    NSString *completionString = PXKeychainHelperCompletionString(completion);
    if (!completionString) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorInvalidCompletion,
                                       @"$.completion",
                                       @"The helper completion is invalid.");
        return nil;
    }

    if (!PXKeychainHelperResultCountIsWithinLimit(attemptedCount) ||
        !PXKeychainHelperResultCountIsWithinLimit(succeededCount) ||
        !PXKeychainHelperResultCountIsWithinLimit(failedCount) ||
        !PXKeychainHelperResultCountIsWithinLimit(skippedCount) ||
        !PXKeychainHelperResultCountIsWithinLimit(warningCount) ||
        !PXKeychainHelperResultCountIsWithinLimit(errorCount)) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorLimitExceeded,
                                       @"$.counts",
                                       @"A helper result count exceeds the fixed limit.");
        return nil;
    }
    if (!PXKeychainHelperResultCountsFitAttempted(attemptedCount,
                                                  succeededCount,
                                                  failedCount,
                                                  skippedCount)) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorInvalidCounts,
                                       @"$.counts",
                                       @"The helper result counts are inconsistent.");
        return nil;
    }

    if (operation == PXKeychainHelperOperationUnknown &&
        completion != PXKeychainHelperCompletionFailed) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorInvalidOperation,
                                       @"$.operation",
                                       @"An unknown operation must report failed completion.");
        return nil;
    }
    if (completion == PXKeychainHelperCompletionFailed &&
        ![fatalError isKindOfClass:[NSError class]]) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorInvalidFatalError,
                                       @"$.fatalError",
                                       @"Failed completion requires a fatal error.");
        return nil;
    }
    if ((completion == PXKeychainHelperCompletionCompleted ||
         completion == PXKeychainHelperCompletionPartial) && fatalError != nil) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorInvalidFatalError,
                                       @"$.fatalError",
                                       @"Nonfailed completion cannot retain a fatal error.");
        return nil;
    }
    if (completion == PXKeychainHelperCompletionCompleted &&
        (failedCount != 0 || skippedCount != 0 || warningCount != 0 || errorCount != 0)) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorInvalidCompletion,
                                       @"$.completion",
                                       @"Completed completion cannot contain issue counts.");
        return nil;
    }
    if (completion == PXKeychainHelperCompletionPartial &&
        failedCount == 0 && skippedCount == 0 && warningCount == 0 && errorCount == 0) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorInvalidCompletion,
                                       @"$.completion",
                                       @"Partial completion requires at least one issue count.");
        return nil;
    }

    BOOL fatalErrorPresent = fatalError != nil;
    NSString *fatalErrorDomain = @"";
    NSInteger fatalErrorCode = 0;
    if (fatalErrorPresent) {
        NSString *domain = fatalError.domain;
        NSUInteger domainByteCount = 0;
        if (!PXKeychainHelperResultFatalDomainIsValid(domain, &domainByteCount)) {
            PXKeychainHelperResultSetError(error,
                                           PXKeychainHelperResultErrorInvalidFatalError,
                                           @"$.fatalError.domain",
                                           @"The fatal error domain is invalid.");
            return nil;
        }
        if (domainByteCount > PXKeychainHelperResultMaximumFatalDomainBytes) {
            PXKeychainHelperResultSetError(error,
                                           PXKeychainHelperResultErrorLimitExceeded,
                                           @"$.fatalError.domain",
                                           @"The fatal error domain exceeds the fixed limit.");
            return nil;
        }
        fatalErrorDomain = [domain copy];
        fatalErrorCode = fatalError.code;
    }

    NSDictionary<NSString *, id> *fatalRepresentation = @{
        @"present": @(fatalErrorPresent),
        @"domain": [fatalErrorDomain copy],
        @"code": @(fatalErrorCode),
    };
    NSDictionary<NSString *, id> *snapshot = @{
        @"schemaVersion": @(PXKeychainHelperResultSchemaVersion),
        @"operation": [operationString copy],
        @"completion": [completionString copy],
        @"attemptedCount": @(attemptedCount),
        @"succeededCount": @(succeededCount),
        @"failedCount": @(failedCount),
        @"skippedCount": @(skippedCount),
        @"warningCount": @(warningCount),
        @"errorCount": @(errorCount),
        @"fatalError": [fatalRepresentation copy],
    };
    snapshot = [snapshot copy];

    if (!PXKeychainHelperResultRepresentationMatchesState(snapshot,
                                                           operation,
                                                           completion,
                                                           attemptedCount,
                                                           succeededCount,
                                                           failedCount,
                                                           skippedCount,
                                                           warningCount,
                                                           errorCount,
                                                           fatalErrorPresent,
                                                           fatalErrorDomain,
                                                           fatalErrorCode)) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorInternalInvariantFailed,
                                       @"$",
                                       @"The helper result snapshot is inconsistent.");
        return nil;
    }

    NSError *serializationError = nil;
    NSData *binaryPlist = [NSPropertyListSerialization dataWithPropertyList:snapshot
                                                                     format:NSPropertyListBinaryFormat_v1_0
                                                                    options:0
                                                                      error:&serializationError];
    if (!binaryPlist || serializationError) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorSerializationFailed,
                                       @"$",
                                       @"The helper result could not be serialized.");
        return nil;
    }
    if (binaryPlist.length == 0 ||
        binaryPlist.length > PXKeychainHelperResultMaximumBinaryPlistBytes) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorLimitExceeded,
                                       @"$",
                                       @"The binary helper result exceeds the fixed limit.");
        return nil;
    }

    NSString *base64 = [binaryPlist base64EncodedStringWithOptions:0];
    NSData *base64Bytes = [base64 dataUsingEncoding:NSUTF8StringEncoding
                               allowLossyConversion:NO];
    if (!base64Bytes || base64Bytes.length == 0 ||
        base64Bytes.length > PXKeychainHelperResultMaximumBase64Bytes ||
        [base64 rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorLimitExceeded,
                                       @"$",
                                       @"The encoded helper result exceeds the fixed limit.");
        return nil;
    }

    NSData *decodedBinaryPlist = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
    if (![decodedBinaryPlist isEqualToData:binaryPlist]) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorInternalInvariantFailed,
                                       @"$",
                                       @"The encoded helper result failed round-trip validation.");
        return nil;
    }

    NSError *readError = nil;
    NSPropertyListFormat decodedFormat = NSPropertyListOpenStepFormat;
    id decodedObject = [NSPropertyListSerialization propertyListWithData:decodedBinaryPlist
                                                                  options:NSPropertyListImmutable
                                                                   format:&decodedFormat
                                                                    error:&readError];
    if (readError || decodedFormat != NSPropertyListBinaryFormat_v1_0 ||
        ![decodedObject isKindOfClass:[NSDictionary class]] ||
        ![(NSDictionary *)decodedObject isEqualToDictionary:snapshot] ||
        !PXKeychainHelperResultRepresentationMatchesState(decodedObject,
                                                           operation,
                                                           completion,
                                                           attemptedCount,
                                                           succeededCount,
                                                           failedCount,
                                                           skippedCount,
                                                           warningCount,
                                                           errorCount,
                                                           fatalErrorPresent,
                                                           fatalErrorDomain,
                                                           fatalErrorCode)) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorInternalInvariantFailed,
                                       @"$",
                                       @"The helper result failed immutable read-back validation.");
        return nil;
    }

    NSDictionary<NSString *, id> *immutableSnapshot = [(NSDictionary *)decodedObject copy];
    NSString *machineReadableLine =
        [PXKeychainHelperResultOutputPrefix stringByAppendingString:base64];
    NSData *lineBytes = [machineReadableLine dataUsingEncoding:NSUTF8StringEncoding
                                          allowLossyConversion:NO];
    NSRange firstPrefix = [machineReadableLine rangeOfString:PXKeychainHelperResultOutputPrefix];
    NSRange remainingRange = NSMakeRange(PXKeychainHelperResultOutputPrefix.length,
                                         machineReadableLine.length - PXKeychainHelperResultOutputPrefix.length);
    NSRange repeatedPrefix = [machineReadableLine rangeOfString:PXKeychainHelperResultOutputPrefix
                                                       options:0
                                                         range:remainingRange];
    if (!lineBytes || lineBytes.length == 0 ||
        lineBytes.length > PXKeychainHelperResultMaximumOutputLineBytes ||
        firstPrefix.location != 0 || firstPrefix.length != PXKeychainHelperResultOutputPrefix.length ||
        repeatedPrefix.location != NSNotFound ||
        [machineReadableLine hasSuffix:@"\n"] ||
        [machineReadableLine hasSuffix:@"\r"]) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorLimitExceeded,
                                       @"$",
                                       @"The complete helper result line exceeds the fixed limit.");
        return nil;
    }

    PXKeychainHelperResult *result =
        [[PXKeychainHelperResult alloc] px_initWithOperation:operation
                                                 completion:completion
                                             attemptedCount:attemptedCount
                                             succeededCount:succeededCount
                                                failedCount:failedCount
                                               skippedCount:skippedCount
                                               warningCount:warningCount
                                                 errorCount:errorCount
                                          fatalErrorPresent:fatalErrorPresent
                                           fatalErrorDomain:fatalErrorDomain
                                             fatalErrorCode:fatalErrorCode
                                 propertyListRepresentation:immutableSnapshot
                                        machineReadableLine:machineReadableLine];
    if (!result) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorInternalInvariantFailed,
                                       @"$",
                                       @"The immutable helper result could not be initialized.");
    }
    return result;
}

- (instancetype)px_initWithOperation:(PXKeychainHelperOperation)operation
                          completion:(PXKeychainHelperCompletion)completion
                      attemptedCount:(NSUInteger)attemptedCount
                      succeededCount:(NSUInteger)succeededCount
                         failedCount:(NSUInteger)failedCount
                        skippedCount:(NSUInteger)skippedCount
                        warningCount:(NSUInteger)warningCount
                          errorCount:(NSUInteger)errorCount
                   fatalErrorPresent:(BOOL)fatalErrorPresent
                    fatalErrorDomain:(NSString *)fatalErrorDomain
                      fatalErrorCode:(NSInteger)fatalErrorCode
          propertyListRepresentation:(NSDictionary<NSString *, id> *)propertyListRepresentation
                 machineReadableLine:(NSString *)machineReadableLine {
    self = [super init];
    if (self) {
        _schemaVersion = PXKeychainHelperResultSchemaVersion;
        _operation = operation;
        _completion = completion;
        _attemptedCount = attemptedCount;
        _succeededCount = succeededCount;
        _failedCount = failedCount;
        _skippedCount = skippedCount;
        _warningCount = warningCount;
        _errorCount = errorCount;
        _fatalErrorPresent = fatalErrorPresent;
        _fatalErrorDomain = [fatalErrorDomain copy];
        _fatalErrorCode = fatalErrorCode;
        _propertyListRepresentation = [propertyListRepresentation copy];
        _machineReadableLine = [machineReadableLine copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isMemberOfClass:[PXKeychainHelperResult class]]) {
        return NO;
    }
    PXKeychainHelperResult *other = object;
    return self.schemaVersion == other.schemaVersion &&
           self.operation == other.operation &&
           self.completion == other.completion &&
           self.attemptedCount == other.attemptedCount &&
           self.succeededCount == other.succeededCount &&
           self.failedCount == other.failedCount &&
           self.skippedCount == other.skippedCount &&
           self.warningCount == other.warningCount &&
           self.errorCount == other.errorCount &&
           self.fatalErrorPresent == other.fatalErrorPresent &&
           [self.fatalErrorDomain isEqualToString:other.fatalErrorDomain] &&
           self.fatalErrorCode == other.fatalErrorCode &&
           [self.propertyListRepresentation isEqualToDictionary:other.propertyListRepresentation] &&
           [self.machineReadableLine isEqualToString:other.machineReadableLine];
}

- (NSUInteger)hash {
    NSUInteger value = self.propertyListRepresentation.hash;
    value ^= self.machineReadableLine.hash;
    value ^= self.fatalErrorDomain.hash;
    value ^= (NSUInteger)self.schemaVersion;
    value ^= (NSUInteger)self.operation;
    value ^= (NSUInteger)self.completion;
    value ^= self.attemptedCount;
    value ^= self.succeededCount;
    value ^= self.failedCount;
    value ^= self.skippedCount;
    value ^= self.warningCount;
    value ^= self.errorCount;
    value ^= (NSUInteger)self.fatalErrorPresent;
    value ^= (NSUInteger)self.fatalErrorCode;
    return value;
}

@end
