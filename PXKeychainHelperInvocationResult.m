#import "PXKeychainHelperInvocationResult.h"

NSErrorDomain const PXKeychainHelperInvocationResultErrorDomain =
    @"com.hydra.tlinkios.keychain-helper-invocation-result";
NSString * const PXKeychainHelperInvocationResultErrorFieldPathKey = @"fieldPath";

static const NSUInteger PXKeychainHelperInvocationMaximumAccessGroups = 128;
static const NSUInteger PXKeychainHelperInvocationMaximumAccessGroupBytes = 512;
static const NSUInteger PXKeychainHelperInvocationMaximumAccessGroupArrayBytes = 8 * 1024;
static const NSUInteger PXKeychainHelperInvocationMaximumStdoutBytes = 1024 * 1024;
static NSString * const PXKeychainHelperInvocationGenericResultToken =
    @"PXKEYCHAIN_HELPER_RESULT_";

typedef NS_ENUM(NSInteger, PXKeychainHelperMachineScanStatus) {
    PXKeychainHelperMachineScanStatusNone = 0,
    PXKeychainHelperMachineScanStatusResult,
    PXKeychainHelperMachineScanStatusInvalidMarker,
    PXKeychainHelperMachineScanStatusInvalid,
};

static void PXKeychainHelperInvocationSetError(
    NSError **error,
    PXKeychainHelperInvocationResultErrorCode code,
    NSString *fieldPath,
    NSString *description) {
    if (!error) {
        return;
    }
    *error = [NSError errorWithDomain:PXKeychainHelperInvocationResultErrorDomain
                                 code:code
                             userInfo:@{
                                 NSLocalizedDescriptionKey: description,
                                 PXKeychainHelperInvocationResultErrorFieldPathKey: fieldPath,
                             }];
}

static BOOL PXKeychainHelperInvocationOperationIsSupported(
    PXKeychainHelperOperation operation) {
    return operation == PXKeychainHelperOperationBackup ||
           operation == PXKeychainHelperOperationRestore;
}

static BOOL PXKeychainHelperInvocationStringHasControlCharacter(NSString *value) {
    return [value rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location !=
        NSNotFound;
}

static NSArray<NSString *> *PXKeychainHelperInvocationCanonicalAccessGroups(
    id value,
    NSError **error) {
    if (![value isKindOfClass:[NSArray class]]) {
        PXKeychainHelperInvocationSetError(
            error,
            PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups,
            @"$.expectedRequestedAccessGroups",
            @"The expected access groups must be an array.");
        return nil;
    }
    NSArray *input = value;
    if (input.count == 0 ||
        input.count > PXKeychainHelperInvocationMaximumAccessGroups) {
        PXKeychainHelperInvocationSetError(
            error,
            PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups,
            @"$.expectedRequestedAccessGroups",
            @"The expected access-group array violates the fixed count limit.");
        return nil;
    }

    NSMutableArray<NSString *> *canonical = [NSMutableArray arrayWithCapacity:input.count];
    NSMutableSet<NSString *> *seen = [NSMutableSet setWithCapacity:input.count];
    NSUInteger totalBytes = 0;
    NSCharacterSet *edgeWhitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (id candidate in input) {
        if (![candidate isKindOfClass:[NSString class]] ||
            [(NSString *)candidate length] == 0 ||
            PXKeychainHelperInvocationStringHasControlCharacter(candidate)) {
            PXKeychainHelperInvocationSetError(
                error,
                PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups,
                @"$.expectedRequestedAccessGroups",
                @"An expected access-group value is invalid.");
            return nil;
        }
        NSData *sourceUTF8 = [(NSString *)candidate
            dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
        NSString *sourceRoundTrip = sourceUTF8
            ? [[NSString alloc] initWithData:sourceUTF8 encoding:NSUTF8StringEncoding]
            : nil;
        if (!sourceUTF8 ||
            ![sourceRoundTrip isEqualToString:(NSString *)candidate]) {
            PXKeychainHelperInvocationSetError(
                error,
                PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups,
                @"$.expectedRequestedAccessGroups",
                @"An expected access-group value is not valid UTF-8.");
            return nil;
        }

        NSString *trimmed = [(NSString *)candidate
            stringByTrimmingCharactersInSet:edgeWhitespace];
        NSData *utf8 = [trimmed dataUsingEncoding:NSUTF8StringEncoding
                             allowLossyConversion:NO];
        NSString *roundTrip = utf8
            ? [[NSString alloc] initWithData:utf8 encoding:NSUTF8StringEncoding]
            : nil;
        if (trimmed.length == 0 ||
            !utf8 ||
            utf8.length == 0 ||
            utf8.length > PXKeychainHelperInvocationMaximumAccessGroupBytes ||
            ![roundTrip isEqualToString:trimmed] ||
            PXKeychainHelperInvocationStringHasControlCharacter(trimmed) ||
            [trimmed rangeOfString:@","].location != NSNotFound) {
            PXKeychainHelperInvocationSetError(
                error,
                PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups,
                @"$.expectedRequestedAccessGroups",
                @"An expected access-group value violates the canonical contract.");
            return nil;
        }
        if ([seen containsObject:trimmed]) {
            continue;
        }
        if (totalBytes > PXKeychainHelperInvocationMaximumAccessGroupArrayBytes ||
            utf8.length > PXKeychainHelperInvocationMaximumAccessGroupArrayBytes - totalBytes) {
            PXKeychainHelperInvocationSetError(
                error,
                PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups,
                @"$.expectedRequestedAccessGroups",
                @"The expected access groups exceed the fixed byte limit.");
            return nil;
        }
        totalBytes += utf8.length;
        NSString *snapshot = [trimmed copy];
        [seen addObject:snapshot];
        [canonical addObject:snapshot];
    }
    if (canonical.count == 0) {
        PXKeychainHelperInvocationSetError(
            error,
            PXKeychainHelperInvocationResultErrorInvalidExpectedAccessGroups,
            @"$.expectedRequestedAccessGroups",
            @"The canonical expected access-group array is empty.");
        return nil;
    }
    return [canonical copy];
}

static PXKeychainHelperMachineScanStatus PXKeychainHelperInvocationScanStdout(
    id stdoutValue,
    NSString **machineLineOut) {
    if (machineLineOut) {
        *machineLineOut = nil;
    }
    if (![stdoutValue isKindOfClass:[NSString class]]) {
        return PXKeychainHelperMachineScanStatusInvalid;
    }
    NSString *stdoutString = stdoutValue;
    NSData *stdoutBytes = [stdoutString dataUsingEncoding:NSUTF8StringEncoding
                                     allowLossyConversion:NO];
    if (!stdoutBytes ||
        stdoutBytes.length > PXKeychainHelperInvocationMaximumStdoutBytes) {
        return PXKeychainHelperMachineScanStatusInvalid;
    }

    NSString *invalidMarker =
        [PXKeychainHelperResultOutputPrefix stringByAppendingString:@"INVALID"];
    PXKeychainHelperMachineScanStatus candidateStatus =
        PXKeychainHelperMachineScanStatusNone;
    NSString *candidateLine = nil;
    NSArray<NSString *> *lines = [stdoutString componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSRange genericToken = [line rangeOfString:PXKeychainHelperInvocationGenericResultToken];
        if (genericToken.location == NSNotFound) {
            continue;
        }
        if (genericToken.location != 0 ||
            ![line hasPrefix:PXKeychainHelperResultOutputPrefix] ||
            [line rangeOfString:@"\r"].location != NSNotFound ||
            candidateStatus != PXKeychainHelperMachineScanStatusNone) {
            return PXKeychainHelperMachineScanStatusInvalid;
        }
        candidateStatus = [line isEqualToString:invalidMarker]
            ? PXKeychainHelperMachineScanStatusInvalidMarker
            : PXKeychainHelperMachineScanStatusResult;
        candidateLine = [line copy];
    }
    if (candidateStatus == PXKeychainHelperMachineScanStatusResult && machineLineOut) {
        *machineLineOut = candidateLine;
    }
    return candidateStatus;
}

static BOOL PXKeychainHelperInvocationExitIsHelperFailure(NSInteger exitCode) {
    return exitCode == 20 || exitCode == 21 ||
           exitCode == 30 || exitCode == 40;
}

static BOOL PXKeychainHelperInvocationExitIsWrapperFailure(NSInteger exitCode) {
    return exitCode >= 60 && exitCode <= 65;
}

@interface PXKeychainHelperInvocationResult ()

- (instancetype)initWithStatus:(PXKeychainHelperInvocationStatus)status
                expectedOperation:(PXKeychainHelperOperation)expectedOperation
                         exitCode:(NSInteger)exitCode
                     helperResult:(PXKeychainHelperResult * _Nullable)helperResult
 additionalEffectiveAccessGroupCount:(NSUInteger)additionalEffectiveAccessGroupCount
        diagnosticOutputTruncated:(BOOL)diagnosticOutputTruncated;

@end

@implementation PXKeychainHelperInvocationResult

+ (NSArray<NSString *> *)canonicalAccessGroupsFromArray:(NSArray<NSString *> *)accessGroups
                                                   error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    return PXKeychainHelperInvocationCanonicalAccessGroups(accessGroups, error);
}

+ (instancetype)resultWithCommandResult:(CommandResult *)commandResult
                      expectedOperation:(PXKeychainHelperOperation)expectedOperation
         expectedRequestedAccessGroups:(NSArray<NSString *> *)expectedRequestedAccessGroups
                                  error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (!PXKeychainHelperInvocationOperationIsSupported(expectedOperation)) {
        PXKeychainHelperInvocationSetError(
            error,
            PXKeychainHelperInvocationResultErrorInvalidExpectedOperation,
            @"$.expectedOperation",
            @"The expected helper operation is invalid.");
        return nil;
    }
    NSError *groupError = nil;
    NSArray<NSString *> *canonicalExpectedGroups =
        PXKeychainHelperInvocationCanonicalAccessGroups(
            expectedRequestedAccessGroups,
            &groupError);
    if (!canonicalExpectedGroups) {
        if (error) {
            *error = groupError;
        }
        return nil;
    }

    BOOL validCommandResult = [commandResult isKindOfClass:[CommandResult class]];
    NSInteger exitCode = validCommandResult ? commandResult.exitCode : -1;
    int spawnError = validCommandResult ? commandResult.spawnError : -1;
    int runnerError = validCommandResult ? commandResult.runnerError : -1;
    BOOL exitedNormally = validCommandResult && commandResult.exitedNormally;
    BOOL timedOut = validCommandResult && commandResult.timedOut;
    int terminationSignal = validCommandResult ? commandResult.terminationSignal : 0;
    BOOL stdoutTruncated = validCommandResult && commandResult.stdoutTruncated;
    BOOL diagnosticOutputTruncated = validCommandResult && commandResult.stderrTruncated;
    NSString *stdoutSnapshot = validCommandResult &&
        [commandResult.stdoutString isKindOfClass:[NSString class]]
            ? [commandResult.stdoutString copy]
            : nil;
    NSString *stderrSnapshot = validCommandResult &&
        [commandResult.stderrString isKindOfClass:[NSString class]]
            ? [commandResult.stderrString copy]
            : nil;
    BOOL processUsable = validCommandResult &&
        stdoutSnapshot != nil &&
        stderrSnapshot != nil &&
        spawnError == 0 &&
        runnerError == 0 &&
        exitedNormally &&
        !timedOut &&
        terminationSignal == 0 &&
        !stdoutTruncated;
    if (!processUsable) {
        return [[PXKeychainHelperInvocationResult alloc]
            initWithStatus:PXKeychainHelperInvocationStatusProcessFailed
            expectedOperation:expectedOperation
            exitCode:exitCode
            helperResult:nil
            additionalEffectiveAccessGroupCount:0
            diagnosticOutputTruncated:diagnosticOutputTruncated];
    }

    if (PXKeychainHelperInvocationExitIsWrapperFailure(exitCode)) {
        return [[PXKeychainHelperInvocationResult alloc]
            initWithStatus:PXKeychainHelperInvocationStatusWrapperFailed
            expectedOperation:expectedOperation
            exitCode:exitCode
            helperResult:nil
            additionalEffectiveAccessGroupCount:0
            diagnosticOutputTruncated:diagnosticOutputTruncated];
    }
    BOOL recognizedDirectExit = exitCode == 0 || exitCode == 10 ||
        PXKeychainHelperInvocationExitIsHelperFailure(exitCode) || exitCode == 50;
    if (!recognizedDirectExit) {
        return [[PXKeychainHelperInvocationResult alloc]
            initWithStatus:PXKeychainHelperInvocationStatusProtocolFailed
            expectedOperation:expectedOperation
            exitCode:exitCode
            helperResult:nil
            additionalEffectiveAccessGroupCount:0
            diagnosticOutputTruncated:diagnosticOutputTruncated];
    }

    NSString *machineLine = nil;
    PXKeychainHelperMachineScanStatus scanStatus =
        PXKeychainHelperInvocationScanStdout(stdoutSnapshot, &machineLine);
    if (exitCode == 50) {
        if (scanStatus != PXKeychainHelperMachineScanStatusInvalidMarker) {
            return [[PXKeychainHelperInvocationResult alloc]
                initWithStatus:PXKeychainHelperInvocationStatusProtocolFailed
                expectedOperation:expectedOperation
                exitCode:exitCode
                helperResult:nil
                additionalEffectiveAccessGroupCount:0
                diagnosticOutputTruncated:diagnosticOutputTruncated];
        }
        return [[PXKeychainHelperInvocationResult alloc]
            initWithStatus:PXKeychainHelperInvocationStatusProtocolFailed
            expectedOperation:expectedOperation
            exitCode:exitCode
            helperResult:nil
            additionalEffectiveAccessGroupCount:0
            diagnosticOutputTruncated:diagnosticOutputTruncated];
    }
    if (scanStatus != PXKeychainHelperMachineScanStatusResult ||
        machineLine.length == 0) {
        return [[PXKeychainHelperInvocationResult alloc]
            initWithStatus:PXKeychainHelperInvocationStatusProtocolFailed
            expectedOperation:expectedOperation
            exitCode:exitCode
            helperResult:nil
            additionalEffectiveAccessGroupCount:0
            diagnosticOutputTruncated:diagnosticOutputTruncated];
    }

    NSError *decodeError = nil;
    PXKeychainHelperResult *helperResult =
        [PXKeychainHelperResult resultFromMachineReadableLine:machineLine
                                                       error:&decodeError];
    (void)decodeError;
    if (!helperResult ||
        helperResult.operation != expectedOperation ||
        ![helperResult.requestedAccessGroups isEqualToArray:canonicalExpectedGroups]) {
        return [[PXKeychainHelperInvocationResult alloc]
            initWithStatus:PXKeychainHelperInvocationStatusProtocolFailed
            expectedOperation:expectedOperation
            exitCode:exitCode
            helperResult:nil
            additionalEffectiveAccessGroupCount:0
            diagnosticOutputTruncated:diagnosticOutputTruncated];
    }

    PXKeychainHelperInvocationStatus status =
        PXKeychainHelperInvocationStatusProtocolFailed;
    if (exitCode == 0 &&
        helperResult.completion == PXKeychainHelperCompletionCompleted) {
        status = PXKeychainHelperInvocationStatusCompleted;
    } else if (exitCode == 10 &&
               helperResult.completion == PXKeychainHelperCompletionPartial) {
        status = PXKeychainHelperInvocationStatusPartial;
    } else if (PXKeychainHelperInvocationExitIsHelperFailure(exitCode) &&
               helperResult.completion == PXKeychainHelperCompletionFailed &&
               helperResult.fatalErrorPresent) {
        status = PXKeychainHelperInvocationStatusHelperFailed;
    }
    if (status == PXKeychainHelperInvocationStatusProtocolFailed) {
        return [[PXKeychainHelperInvocationResult alloc]
            initWithStatus:status
            expectedOperation:expectedOperation
            exitCode:exitCode
            helperResult:nil
            additionalEffectiveAccessGroupCount:0
            diagnosticOutputTruncated:diagnosticOutputTruncated];
    }

    NSUInteger additionalEffectiveAccessGroupCount =
        helperResult.effectiveAccessGroups.count -
        helperResult.requestedAccessGroups.count;
    return [[PXKeychainHelperInvocationResult alloc]
        initWithStatus:status
        expectedOperation:expectedOperation
        exitCode:exitCode
        helperResult:helperResult
        additionalEffectiveAccessGroupCount:additionalEffectiveAccessGroupCount
        diagnosticOutputTruncated:diagnosticOutputTruncated];
}

- (instancetype)initWithStatus:(PXKeychainHelperInvocationStatus)status
                expectedOperation:(PXKeychainHelperOperation)expectedOperation
                         exitCode:(NSInteger)exitCode
                     helperResult:(PXKeychainHelperResult *)helperResult
 additionalEffectiveAccessGroupCount:(NSUInteger)additionalEffectiveAccessGroupCount
        diagnosticOutputTruncated:(BOOL)diagnosticOutputTruncated {
    self = [super init];
    if (self) {
        _status = status;
        _expectedOperation = expectedOperation;
        _exitCode = exitCode;
        _helperResult = [helperResult copy];
        _additionalEffectiveAccessGroupCount = additionalEffectiveAccessGroupCount;
        _diagnosticOutputTruncated = diagnosticOutputTruncated;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end
