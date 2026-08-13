#import "PXKeychainHelperResult.h"
#import <CoreFoundation/CoreFoundation.h>

NSInteger const PXKeychainHelperResultSchemaVersion = 2;
NSString * const PXKeychainHelperResultOutputPrefix = @"PXKEYCHAIN_HELPER_RESULT_V2=";
NSErrorDomain const PXKeychainHelperResultErrorDomain = @"com.hydra.tlinkios.keychain-helper-result";
NSString * const PXKeychainHelperResultErrorFieldPathKey = @"fieldPath";

static const NSUInteger PXKeychainHelperResultMaximumCount = 1000000;
static const NSUInteger PXKeychainHelperResultMaximumFatalDomainBytes = 255;
static const NSUInteger PXKeychainHelperResultMaximumAccessGroupsPerArray = 128;
static const NSUInteger PXKeychainHelperResultMaximumAccessGroupBytes = 512;
static const NSUInteger PXKeychainHelperResultMaximumAccessGroupArrayBytes = 8 * 1024;
static const NSUInteger PXKeychainHelperResultMaximumCombinedAccessGroupBytes = 16 * 1024;
static const NSUInteger PXKeychainHelperResultMaximumBinaryPlistBytes = 32 * 1024;
static const NSUInteger PXKeychainHelperResultMaximumBase64Bytes = 48 * 1024;
static const NSUInteger PXKeychainHelperResultMaximumOutputLineBytes = 50 * 1024;

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

static BOOL PXKeychainHelperResultAddWithoutOverflow(NSUInteger left,
                                                      NSUInteger right,
                                                      NSUInteger limit,
                                                      NSUInteger *sumOut) {
    if (left > limit || right > limit || right > limit - left) {
        return NO;
    }
    if (sumOut) {
        *sumOut = left + right;
    }
    return YES;
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

static BOOL PXKeychainHelperResultAccessGroupStringIsValid(NSString *group,
                                                            NSUInteger *byteCountOut) {
    if (![group isKindOfClass:[NSString class]] || group.length == 0) {
        return NO;
    }
    NSData *utf8 = [group dataUsingEncoding:NSUTF8StringEncoding
                       allowLossyConversion:NO];
    if (!utf8 || utf8.length == 0 ||
        utf8.length > PXKeychainHelperResultMaximumAccessGroupBytes) {
        return NO;
    }
    NSString *roundTrip = [[NSString alloc] initWithData:utf8
                                                 encoding:NSUTF8StringEncoding];
    if (!roundTrip || ![roundTrip isEqualToString:group]) {
        return NO;
    }
    unichar nulCharacter = 0;
    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
    if ([group rangeOfString:nulString].location != NSNotFound ||
        [group rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound ||
        [group rangeOfString:@","].location != NSNotFound) {
        return NO;
    }
    NSCharacterSet *edgeWhitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    if (![[group stringByTrimmingCharactersInSet:edgeWhitespace] isEqualToString:group]) {
        return NO;
    }
    if (byteCountOut) {
        *byteCountOut = utf8.length;
    }
    return YES;
}

static NSArray<NSString *> *PXKeychainHelperResultValidatedGroupSnapshot(
    id value,
    NSString *fieldPath,
    NSUInteger *byteCountOut,
    NSError **error) {
    if (![value isKindOfClass:[NSArray class]]) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorInvalidAccessGroups,
                                       fieldPath,
                                       @"The access-group field must be an array.");
        return nil;
    }
    NSArray *input = (NSArray *)value;
    if (input.count > PXKeychainHelperResultMaximumAccessGroupsPerArray) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorLimitExceeded,
                                       fieldPath,
                                       @"The access-group array exceeds the fixed count limit.");
        return nil;
    }

    NSMutableArray<NSString *> *snapshot = [NSMutableArray arrayWithCapacity:input.count];
    NSMutableSet<NSString *> *seen = [NSMutableSet setWithCapacity:input.count];
    NSUInteger totalBytes = 0;
    for (NSUInteger index = 0; index < input.count; index++) {
        id candidate = input[index];
        NSString *elementPath = [NSString stringWithFormat:@"%@[%lu]",
                                 fieldPath,
                                 (unsigned long)index];
        NSUInteger groupBytes = 0;
        if (!PXKeychainHelperResultAccessGroupStringIsValid(candidate, &groupBytes)) {
            PXKeychainHelperResultSetError(error,
                                           PXKeychainHelperResultErrorInvalidAccessGroups,
                                           elementPath,
                                           @"An access-group element is invalid.");
            return nil;
        }
        NSString *immutableGroup = [(NSString *)candidate copy];
        if ([seen containsObject:immutableGroup]) {
            PXKeychainHelperResultSetError(error,
                                           PXKeychainHelperResultErrorDuplicateAccessGroup,
                                           elementPath,
                                           @"The access-group array contains a duplicate.");
            return nil;
        }
        NSUInteger nextTotal = 0;
        if (!PXKeychainHelperResultAddWithoutOverflow(totalBytes,
                                                      groupBytes,
                                                      PXKeychainHelperResultMaximumAccessGroupArrayBytes,
                                                      &nextTotal)) {
            PXKeychainHelperResultSetError(error,
                                           PXKeychainHelperResultErrorLimitExceeded,
                                           fieldPath,
                                           @"The access-group array exceeds the fixed byte limit.");
            return nil;
        }
        totalBytes = nextTotal;
        [seen addObject:immutableGroup];
        [snapshot addObject:immutableGroup];
    }
    if (byteCountOut) {
        *byteCountOut = totalBytes;
    }
    return [snapshot copy];
}

static BOOL PXKeychainHelperResultRequestedGroupsAreSubset(
    NSArray<NSString *> *requestedAccessGroups,
    NSArray<NSString *> *effectiveAccessGroups) {
    NSSet<NSString *> *effectiveSet = [NSSet setWithArray:effectiveAccessGroups];
    for (NSString *group in requestedAccessGroups) {
        if (![effectiveSet containsObject:group]) {
            return NO;
        }
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
    NSArray<NSString *> *requestedAccessGroups,
    NSArray<NSString *> *effectiveAccessGroups,
    BOOL fatalErrorPresent,
    NSString *fatalErrorDomain,
    NSInteger fatalErrorCode) {
    if (![representation isKindOfClass:[NSDictionary class]] || representation.count != 11) {
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
        @"accessGroups",
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
    NSDictionary<NSString *, id> *accessGroupsRepresentation = representation[@"accessGroups"];

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
        fatalRepresentation.count != 3 ||
        ![accessGroupsRepresentation isKindOfClass:[NSDictionary class]] ||
        accessGroupsRepresentation.count != 2) {
        return NO;
    }

    NSSet<NSString *> *fatalKeys = [NSSet setWithArray:@[
        @"present",
        @"domain",
        @"code",
    ]];
    NSSet<NSString *> *accessGroupKeys = [NSSet setWithArray:@[
        @"requested",
        @"effective",
    ]];
    if (![[NSSet setWithArray:fatalRepresentation.allKeys] isEqualToSet:fatalKeys] ||
        ![[NSSet setWithArray:accessGroupsRepresentation.allKeys] isEqualToSet:accessGroupKeys]) {
        return NO;
    }

    NSNumber *presentNumber = fatalRepresentation[@"present"];
    NSString *domain = fatalRepresentation[@"domain"];
    NSNumber *codeNumber = fatalRepresentation[@"code"];
    NSArray *requestedRepresentation = accessGroupsRepresentation[@"requested"];
    NSArray *effectiveRepresentation = accessGroupsRepresentation[@"effective"];
    return PXKeychainHelperResultIsBoolean(presentNumber) &&
           presentNumber.boolValue == fatalErrorPresent &&
           [domain isKindOfClass:[NSString class]] &&
           [domain isEqualToString:fatalErrorDomain] &&
           PXKeychainHelperResultIsNumber(codeNumber) &&
           codeNumber.integerValue == fatalErrorCode &&
           [requestedRepresentation isKindOfClass:[NSArray class]] &&
           [requestedRepresentation isEqualToArray:requestedAccessGroups] &&
           [effectiveRepresentation isKindOfClass:[NSArray class]] &&
           [effectiveRepresentation isEqualToArray:effectiveAccessGroups];
}

static BOOL PXKeychainHelperOperationFromString(NSString *value,
                                                  PXKeychainHelperOperation *operationOut) {
    if (![value isKindOfClass:[NSString class]]) return NO;
    PXKeychainHelperOperation operation = PXKeychainHelperOperationUnknown;
    if ([value isEqualToString:@"unknown"]) operation = PXKeychainHelperOperationUnknown;
    else if ([value isEqualToString:@"backup"]) operation = PXKeychainHelperOperationBackup;
    else if ([value isEqualToString:@"restore"]) operation = PXKeychainHelperOperationRestore;
    else if ([value isEqualToString:@"wipe"]) operation = PXKeychainHelperOperationWipe;
    else if ([value isEqualToString:@"list"]) operation = PXKeychainHelperOperationList;
    else return NO;
    if (operationOut) *operationOut = operation;
    return YES;
}

static BOOL PXKeychainHelperCompletionFromString(NSString *value,
                                                   PXKeychainHelperCompletion *completionOut) {
    if (![value isKindOfClass:[NSString class]]) return NO;
    PXKeychainHelperCompletion completion = PXKeychainHelperCompletionFailed;
    if ([value isEqualToString:@"failed"]) completion = PXKeychainHelperCompletionFailed;
    else if ([value isEqualToString:@"completed"]) completion = PXKeychainHelperCompletionCompleted;
    else if ([value isEqualToString:@"partial"]) completion = PXKeychainHelperCompletionPartial;
    else return NO;
    if (completionOut) *completionOut = completion;
    return YES;
}

static BOOL PXKeychainHelperResultReadSignedInteger(id value,
                                                     NSInteger *integerOut) {
    if (!PXKeychainHelperResultIsNumber(value) ||
        CFNumberIsFloatType((__bridge CFNumberRef)value)) return NO;
    int64_t parsed = 0;
    if (!CFNumberGetValue((__bridge CFNumberRef)value, kCFNumberSInt64Type, &parsed) ||
        parsed < (int64_t)NSIntegerMin ||
        parsed > (int64_t)NSIntegerMax) return NO;
    if (integerOut) *integerOut = (NSInteger)parsed;
    return YES;
}

static BOOL PXKeychainHelperResultReadUnsignedCount(id value,
                                                     NSUInteger *countOut) {
    if (!PXKeychainHelperResultIsNumber(value) ||
        CFNumberIsFloatType((__bridge CFNumberRef)value)) return NO;
    int64_t parsed = 0;
    if (!CFNumberGetValue((__bridge CFNumberRef)value, kCFNumberSInt64Type, &parsed) ||
        parsed < 0 || (uint64_t)parsed > (uint64_t)NSUIntegerMax) return NO;
    if (countOut) *countOut = (NSUInteger)parsed;
    return YES;
}

static BOOL PXKeychainHelperResultDictionaryHasExactKeys(id value,
                                                          NSArray<NSString *> *keys) {
    if (![value isKindOfClass:[NSDictionary class]]) return NO;
    NSDictionary *dictionary = value;
    return dictionary.count == keys.count &&
        [[NSSet setWithArray:dictionary.allKeys] isEqualToSet:[NSSet setWithArray:keys]];
}

static NSString *PXKeychainHelperResultDecoderFieldPath(NSError *constructionError) {
    NSString *path = constructionError.userInfo[PXKeychainHelperResultErrorFieldPathKey];
    if (![path isKindOfClass:[NSString class]]) return @"$";
    if ([path hasPrefix:@"$.accessGroups.requested"]) return @"$.accessGroups.requested";
    if ([path hasPrefix:@"$.accessGroups.effective"]) return @"$.accessGroups.effective";
    if ([path hasPrefix:@"$.accessGroups"]) return @"$.accessGroups";
    if ([path hasPrefix:@"$.fatalError"]) return @"$.fatalError";
    if ([path hasPrefix:@"$.counts"]) return @"$.counts";
    if ([path isEqualToString:@"$.schemaVersion"] ||
        [path isEqualToString:@"$.operation"] ||
        [path isEqualToString:@"$.completion"]) return path;
    return @"$";
}

@interface PXKeychainHelperResult ()

- (instancetype)initWithOperation:(PXKeychainHelperOperation)operation
                          completion:(PXKeychainHelperCompletion)completion
                      attemptedCount:(NSUInteger)attemptedCount
                      succeededCount:(NSUInteger)succeededCount
                         failedCount:(NSUInteger)failedCount
                        skippedCount:(NSUInteger)skippedCount
                        warningCount:(NSUInteger)warningCount
                          errorCount:(NSUInteger)errorCount
               requestedAccessGroups:(NSArray<NSString *> *)requestedAccessGroups
               effectiveAccessGroups:(NSArray<NSString *> *)effectiveAccessGroups
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
              requestedAccessGroups:(NSArray<NSString *> *)requestedAccessGroups
              effectiveAccessGroups:(NSArray<NSString *> *)effectiveAccessGroups
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

    NSUInteger requestedBytes = 0;
    NSArray<NSString *> *immutableRequested = PXKeychainHelperResultValidatedGroupSnapshot(
        requestedAccessGroups,
        @"$.accessGroups.requested",
        &requestedBytes,
        error);
    if (!immutableRequested) {
        return nil;
    }
    NSUInteger effectiveBytes = 0;
    NSArray<NSString *> *immutableEffective = PXKeychainHelperResultValidatedGroupSnapshot(
        effectiveAccessGroups,
        @"$.accessGroups.effective",
        &effectiveBytes,
        error);
    if (!immutableEffective) {
        return nil;
    }
    NSUInteger combinedBytes = 0;
    if (!PXKeychainHelperResultAddWithoutOverflow(requestedBytes,
                                                  effectiveBytes,
                                                  PXKeychainHelperResultMaximumCombinedAccessGroupBytes,
                                                  &combinedBytes)) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorLimitExceeded,
                                       @"$.accessGroups",
                                       @"The combined access-group fields exceed the fixed byte limit.");
        return nil;
    }
    (void)combinedBytes;
    if (!PXKeychainHelperResultRequestedGroupsAreSubset(immutableRequested, immutableEffective)) {
        PXKeychainHelperResultSetError(error,
                                       PXKeychainHelperResultErrorAccessGroupRelationInvalid,
                                       @"$.accessGroups.requested",
                                       @"The requested access-group set is not contained in the effective set.");
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

    NSDictionary<NSString *, id> *fatalRepresentation = [@{
        @"present": @(fatalErrorPresent),
        @"domain": [fatalErrorDomain copy],
        @"code": @(fatalErrorCode),
    } copy];
    NSDictionary<NSString *, id> *accessGroupsRepresentation = [@{
        @"requested": [immutableRequested copy],
        @"effective": [immutableEffective copy],
    } copy];
    NSDictionary<NSString *, id> *snapshot = [@{
        @"schemaVersion": @(PXKeychainHelperResultSchemaVersion),
        @"operation": [operationString copy],
        @"completion": [completionString copy],
        @"attemptedCount": @(attemptedCount),
        @"succeededCount": @(succeededCount),
        @"failedCount": @(failedCount),
        @"skippedCount": @(skippedCount),
        @"warningCount": @(warningCount),
        @"errorCount": @(errorCount),
        @"fatalError": fatalRepresentation,
        @"accessGroups": accessGroupsRepresentation,
    } copy];

    if (!PXKeychainHelperResultRepresentationMatchesState(snapshot,
                                                           operation,
                                                           completion,
                                                           attemptedCount,
                                                           succeededCount,
                                                           failedCount,
                                                           skippedCount,
                                                           warningCount,
                                                           errorCount,
                                                           immutableRequested,
                                                           immutableEffective,
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
                                                           immutableRequested,
                                                           immutableEffective,
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
        [[PXKeychainHelperResult alloc] initWithOperation:operation
                                                 completion:completion
                                             attemptedCount:attemptedCount
                                             succeededCount:succeededCount
                                                failedCount:failedCount
                                               skippedCount:skippedCount
                                               warningCount:warningCount
                                                 errorCount:errorCount
                                      requestedAccessGroups:immutableRequested
                                      effectiveAccessGroups:immutableEffective
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

+ (instancetype)resultFromMachineReadableLine:(NSString *)machineReadableLine
                                                 error:(NSError **)error {
    if (error) *error = nil;
    if (![machineReadableLine isKindOfClass:[NSString class]] || machineReadableLine.length == 0) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorInvalidMachineReadableLine,
                                       @"$", @"The helper result line is invalid.");
        return nil;
    }
    NSData *lineBytes = [machineReadableLine dataUsingEncoding:NSUTF8StringEncoding
                                          allowLossyConversion:NO];
    if (!lineBytes || lineBytes.length == 0 ||
        lineBytes.length > PXKeychainHelperResultMaximumOutputLineBytes ||
        [machineReadableLine rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorInvalidMachineReadableLine,
                                       @"$", @"The helper result line violates the fixed framing contract.");
        return nil;
    }
    NSRange prefix = [machineReadableLine rangeOfString:PXKeychainHelperResultOutputPrefix];
    if (prefix.location != 0 || prefix.length != PXKeychainHelperResultOutputPrefix.length) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorInvalidMachineReadableLine,
                                       @"$", @"The helper result line has an invalid prefix.");
        return nil;
    }
    NSRange suffixRange = NSMakeRange(PXKeychainHelperResultOutputPrefix.length,
                                      machineReadableLine.length - PXKeychainHelperResultOutputPrefix.length);
    if (suffixRange.length == 0 ||
        [machineReadableLine rangeOfString:PXKeychainHelperResultOutputPrefix
                                  options:0 range:suffixRange].location != NSNotFound) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorInvalidMachineReadableLine,
                                       @"$", @"The helper result line has ambiguous framing.");
        return nil;
    }
    NSString *base64 = [machineReadableLine substringWithRange:suffixRange];
    NSData *base64Bytes = [base64 dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if (!base64Bytes || base64Bytes.length == 0 ||
        base64Bytes.length > PXKeychainHelperResultMaximumBase64Bytes ||
        [base64 rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorInvalidMachineReadableLine,
                                       @"$", @"The encoded helper result is invalid.");
        return nil;
    }
    NSData *binaryPlist = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
    if (!binaryPlist || binaryPlist.length == 0 ||
        binaryPlist.length > PXKeychainHelperResultMaximumBinaryPlistBytes) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorDeserializationFailed,
                                       @"$", @"The encoded helper result could not be decoded.");
        return nil;
    }
    NSError *readError = nil;
    NSPropertyListFormat format = NSPropertyListOpenStepFormat;
    id decodedObject = [NSPropertyListSerialization propertyListWithData:binaryPlist
                                                                  options:NSPropertyListImmutable
                                                                   format:&format error:&readError];
    if (readError || format != NSPropertyListBinaryFormat_v1_0 ||
        ![decodedObject isKindOfClass:[NSDictionary class]]) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorDeserializationFailed,
                                       @"$", @"The helper result property list is invalid.");
        return nil;
    }
    NSDictionary<NSString *, id> *representation = decodedObject;
    NSArray<NSString *> *rootKeys = @[@"schemaVersion", @"operation", @"completion",
        @"attemptedCount", @"succeededCount", @"failedCount", @"skippedCount",
        @"warningCount", @"errorCount", @"fatalError", @"accessGroups"];
    if (!PXKeychainHelperResultDictionaryHasExactKeys(representation, rootKeys)) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
                                       @"$", @"The helper result graph is not canonical.");
        return nil;
    }
    NSInteger schemaVersion = 0;
    if (!PXKeychainHelperResultReadSignedInteger(representation[@"schemaVersion"], &schemaVersion) ||
        schemaVersion != PXKeychainHelperResultSchemaVersion) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
                                       @"$.schemaVersion", @"The helper result schema version is invalid.");
        return nil;
    }
    PXKeychainHelperOperation operation = PXKeychainHelperOperationUnknown;
    if (!PXKeychainHelperOperationFromString(representation[@"operation"], &operation)) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
                                       @"$.operation", @"The helper result operation is invalid.");
        return nil;
    }
    PXKeychainHelperCompletion completion = PXKeychainHelperCompletionFailed;
    if (!PXKeychainHelperCompletionFromString(representation[@"completion"], &completion)) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
                                       @"$.completion", @"The helper result completion is invalid.");
        return nil;
    }
    NSUInteger attemptedCount=0, succeededCount=0, failedCount=0, skippedCount=0;
    NSUInteger warningCount=0, errorCount=0;
    if (!PXKeychainHelperResultReadUnsignedCount(representation[@"attemptedCount"], &attemptedCount) ||
        !PXKeychainHelperResultReadUnsignedCount(representation[@"succeededCount"], &succeededCount) ||
        !PXKeychainHelperResultReadUnsignedCount(representation[@"failedCount"], &failedCount) ||
        !PXKeychainHelperResultReadUnsignedCount(representation[@"skippedCount"], &skippedCount) ||
        !PXKeychainHelperResultReadUnsignedCount(representation[@"warningCount"], &warningCount) ||
        !PXKeychainHelperResultReadUnsignedCount(representation[@"errorCount"], &errorCount)) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
                                       @"$.counts", @"A helper result count is invalid.");
        return nil;
    }
    NSDictionary *fatalGraph = representation[@"fatalError"];
    if (!PXKeychainHelperResultDictionaryHasExactKeys(fatalGraph, @[@"present", @"domain", @"code"])) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
                                       @"$.fatalError", @"The fatal error graph is invalid.");
        return nil;
    }
    id presentValue = fatalGraph[@"present"];
    NSString *fatalDomain = fatalGraph[@"domain"];
    NSInteger fatalCode = 0;
    if (!PXKeychainHelperResultIsBoolean(presentValue) ||
        ![fatalDomain isKindOfClass:[NSString class]] ||
        !PXKeychainHelperResultReadSignedInteger(fatalGraph[@"code"], &fatalCode)) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
                                       @"$.fatalError", @"The fatal error fields are invalid.");
        return nil;
    }
    NSDictionary *groupGraph = representation[@"accessGroups"];
    if (!PXKeychainHelperResultDictionaryHasExactKeys(groupGraph, @[@"requested", @"effective"])) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
                                       @"$.accessGroups", @"The access-group graph is invalid.");
        return nil;
    }
    id requestedGroups = groupGraph[@"requested"];
    id effectiveGroups = groupGraph[@"effective"];
    if (![requestedGroups isKindOfClass:[NSArray class]]) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
                                       @"$.accessGroups.requested", @"The requested access-group array is invalid.");
        return nil;
    }
    if (![effectiveGroups isKindOfClass:[NSArray class]]) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
                                       @"$.accessGroups.effective", @"The effective access-group array is invalid.");
        return nil;
    }
    NSError *fatalError = [presentValue boolValue]
        ? [NSError errorWithDomain:fatalDomain code:fatalCode userInfo:nil] : nil;
    NSError *constructionError = nil;
    PXKeychainHelperResult *result = [PXKeychainHelperResult
        resultWithOperation:operation completion:completion attemptedCount:attemptedCount
        succeededCount:succeededCount failedCount:failedCount skippedCount:skippedCount
        warningCount:warningCount errorCount:errorCount
        requestedAccessGroups:requestedGroups effectiveAccessGroups:effectiveGroups
        fatalError:fatalError error:&constructionError];
    if (!result) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
            PXKeychainHelperResultDecoderFieldPath(constructionError),
            @"The helper result graph failed canonical reconstruction.");
        return nil;
    }
    NSData *canonicalLineBytes = [result.machineReadableLine dataUsingEncoding:NSUTF8StringEncoding
                                                          allowLossyConversion:NO];
    if (![result.propertyListRepresentation isEqualToDictionary:representation] ||
        !canonicalLineBytes || ![canonicalLineBytes isEqualToData:lineBytes]) {
        PXKeychainHelperResultSetError(error, PXKeychainHelperResultErrorNoncanonicalRepresentation,
                                       @"$", @"The helper result is not in canonical form.");
        return nil;
    }
    return result;
}

- (instancetype)initWithOperation:(PXKeychainHelperOperation)operation
                          completion:(PXKeychainHelperCompletion)completion
                      attemptedCount:(NSUInteger)attemptedCount
                      succeededCount:(NSUInteger)succeededCount
                         failedCount:(NSUInteger)failedCount
                        skippedCount:(NSUInteger)skippedCount
                        warningCount:(NSUInteger)warningCount
                          errorCount:(NSUInteger)errorCount
               requestedAccessGroups:(NSArray<NSString *> *)requestedAccessGroups
               effectiveAccessGroups:(NSArray<NSString *> *)effectiveAccessGroups
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
        _requestedAccessGroups = [requestedAccessGroups copy];
        _effectiveAccessGroups = [effectiveAccessGroups copy];
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
           [self.requestedAccessGroups isEqualToArray:other.requestedAccessGroups] &&
           [self.effectiveAccessGroups isEqualToArray:other.effectiveAccessGroups] &&
           self.fatalErrorPresent == other.fatalErrorPresent &&
           [self.fatalErrorDomain isEqualToString:other.fatalErrorDomain] &&
           self.fatalErrorCode == other.fatalErrorCode &&
           [self.propertyListRepresentation isEqualToDictionary:other.propertyListRepresentation] &&
           [self.machineReadableLine isEqualToString:other.machineReadableLine];
}

- (NSUInteger)hash {
    NSUInteger value = self.propertyListRepresentation.hash;
    value ^= self.machineReadableLine.hash;
    value ^= self.requestedAccessGroups.hash;
    value ^= self.effectiveAccessGroups.hash;
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
