/**
 * backup_helper - iOS Keychain Backup/Restore CLI Tool
 *
 * This tool must be resigned with the target app's keychain-access-groups
 * entitlements before running. Use the keychain_backup.sh wrapper script.
 *
 * Exit codes:
 *   0  - Completed
 *   10 - Partial
 *   20 - Invalid arguments
 *   21 - Invalid input
 *   30 - Access denied
 *   40 - Operation failed
 *   50 - Structured-result protocol failure
 */

#import <Foundation/Foundation.h>
#import <sys/stat.h>
#import "KeychainBackupHelper.h"
#import "PXKeychainHelperExitCode.h"
#import "PXKeychainHelperResult.h"

typedef NS_ENUM(NSInteger, PXHelperAction) {
    PXHelperActionUnknown = 0,
    PXHelperActionBackup,
    PXHelperActionRestore,
    PXHelperActionWipe,
    PXHelperActionList,
};

static const NSUInteger PXHelperMaximumAccessGroups = 128;
static const NSUInteger PXHelperMaximumAccessGroupBytes = 512;
static const NSUInteger PXHelperMaximumAccessGroupCSVBytes = 8 * 1024;
static const NSUInteger PXHelperMaximumEntitlementsFileBytes = 64 * 1024;
static const NSUInteger PXHelperMaximumPathBytes = 4 * 1024;

static void printUsage(const char *progname) {
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, "  %s --action backup --file <path> --groups <groups> --requested-groups <groups> --effective-entitlements-file <path>\n", progname);
    fprintf(stderr, "  %s --action restore --file <path> --requested-groups <groups> --effective-entitlements-file <path> [--overwrite]\n", progname);
    fprintf(stderr, "  %s --action wipe --groups <groups> --requested-groups <groups> --effective-entitlements-file <path>\n", progname);
    fprintf(stderr, "  %s --action list --groups <groups> --requested-groups <groups> --effective-entitlements-file <path>\n", progname);
    fprintf(stderr, "\nOptions:\n");
    fprintf(stderr, "  --action <action>                     Action: backup, restore, wipe, list\n");
    fprintf(stderr, "  --file <path>                         Backup/restore plist path\n");
    fprintf(stderr, "  --groups <groups>                     Canonical operational access groups\n");
    fprintf(stderr, "  --requested-groups <groups>           Canonical requested access-group report\n");
    fprintf(stderr, "  --effective-entitlements-file <path>  Signed-helper entitlement snapshot\n");
    fprintf(stderr, "  --overwrite                           Restore exact existing items in place\n");
    fprintf(stderr, "  --verbose                             Print detailed progress information\n");
    fprintf(stderr, "  --help                                Show this help message\n");
}

static PXHelperAction parseAction(NSString *actionStr) {
    if ([actionStr isEqualToString:@"backup"]) return PXHelperActionBackup;
    if ([actionStr isEqualToString:@"restore"]) return PXHelperActionRestore;
    if ([actionStr isEqualToString:@"wipe"]) return PXHelperActionWipe;
    if ([actionStr isEqualToString:@"list"]) return PXHelperActionList;
    return PXHelperActionUnknown;
}

static void logVerbose(BOOL verbose, NSString *format, ...) {
    if (!verbose) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    fprintf(stdout, "[INFO] %s\n", [message UTF8String]);
}

static void logError(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    fprintf(stderr, "[ERROR] %s\n", [message UTF8String]);
}

static void logSuccess(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    fprintf(stdout, "[OK] %s\n", [message UTF8String]);
}

static NSString *PXHexStringFromData(NSData *data) {
    if (![data isKindOfClass:[NSData class]] || data.length == 0) return @"";
    const unsigned char *bytes = (const unsigned char *)data.bytes;
    NSUInteger len = data.length;
    NSUInteger maxLen = MIN(len, 32);
    NSMutableString *hex = [NSMutableString stringWithCapacity:maxLen * 2];
    for (NSUInteger i = 0; i < maxLen; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
    }
    if (len > maxLen) {
        [hex appendString:@"..."];
    }
    return hex;
}

static NSString *PXSafeString(id value) {
    if (!value || value == (id)kCFNull) return @"";
    if ([value isKindOfClass:[NSString class]]) return (NSString *)value;
    if ([value isKindOfClass:[NSData class]]) {
        NSString *string = [[NSString alloc] initWithData:(NSData *)value encoding:NSUTF8StringEncoding];
        if (string.length) return string;
        return [NSString stringWithFormat:@"<data:%@>", PXHexStringFromData((NSData *)value)];
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        NSString *string = [value performSelector:@selector(stringValue)];
        if ([string isKindOfClass:[NSString class]] && string.length) return string;
    }
    return [[value description] ?: @"" copy];
}

static BOOL PXHelperAddWithoutOverflow(NSUInteger left,
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

static BOOL PXHelperAccessGroupIsValid(NSString *group, NSUInteger *byteCountOut) {
    if (![group isKindOfClass:[NSString class]] || group.length == 0) {
        return NO;
    }
    NSData *utf8 = [group dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if (!utf8 || utf8.length == 0 || utf8.length > PXHelperMaximumAccessGroupBytes) {
        return NO;
    }
    NSString *roundTrip = [[NSString alloc] initWithData:utf8 encoding:NSUTF8StringEncoding];
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
    if (![[group stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
          isEqualToString:group]) {
        return NO;
    }
    if (byteCountOut) {
        *byteCountOut = utf8.length;
    }
    return YES;
}

static NSArray<NSString *> *PXCanonicalAccessGroupsFromCSV(NSString *csv,
                                                            NSError **error) {
    if (error) *error = nil;
    if (![csv isKindOfClass:[NSString class]] || csv.length == 0) {
        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                                code:PXKeychainBackupErrorInvalidArguments
                                            userInfo:nil];
        return nil;
    }
    NSData *csvBytes = [csv dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if (!csvBytes || csvBytes.length == 0 || csvBytes.length > PXHelperMaximumAccessGroupCSVBytes ||
        [csv rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound) {
        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                                code:PXKeychainBackupErrorInvalidArguments
                                            userInfo:nil];
        return nil;
    }

    NSArray<NSString *> *parts = [csv componentsSeparatedByString:@","];
    if (parts.count == 0 || parts.count > PXHelperMaximumAccessGroups) {
        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                                code:PXKeychainBackupErrorInvalidArguments
                                            userInfo:nil];
        return nil;
    }
    NSMutableArray<NSString *> *groups = [NSMutableArray arrayWithCapacity:parts.count];
    NSMutableSet<NSString *> *seen = [NSMutableSet setWithCapacity:parts.count];
    NSUInteger totalBytes = 0;
    for (NSString *part in parts) {
        NSString *trimmed = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSUInteger groupBytes = 0;
        if (!PXHelperAccessGroupIsValid(trimmed, &groupBytes)) {
            if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                                    code:PXKeychainBackupErrorInvalidArguments
                                                userInfo:nil];
            return nil;
        }
        NSUInteger nextTotal = 0;
        if (!PXHelperAddWithoutOverflow(totalBytes,
                                        groupBytes,
                                        PXHelperMaximumAccessGroupCSVBytes,
                                        &nextTotal)) {
            if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                                    code:PXKeychainBackupErrorInvalidArguments
                                                userInfo:nil];
            return nil;
        }
        totalBytes = nextTotal;
        NSString *immutableGroup = [trimmed copy];
        if (![seen containsObject:immutableGroup]) {
            [seen addObject:immutableGroup];
            [groups addObject:immutableGroup];
        }
    }
    if (groups.count == 0 || groups.count > PXHelperMaximumAccessGroups) {
        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                                code:PXKeychainBackupErrorInvalidArguments
                                            userInfo:nil];
        return nil;
    }
    return [groups copy];
}

static NSArray<NSString *> *PXEffectiveAccessGroupsFromEntitlementsFile(NSString *filePath,
                                                                         NSError **error) {
    if (error) *error = nil;
    if (![filePath isKindOfClass:[NSString class]] || filePath.length == 0) {
        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                                code:PXKeychainBackupErrorInvalidBackupFile
                                            userInfo:nil];
        return nil;
    }
    NSData *pathBytes = [filePath dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if (!pathBytes || pathBytes.length == 0 || pathBytes.length > PXHelperMaximumPathBytes ||
        [filePath rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound) {
        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                                code:PXKeychainBackupErrorInvalidBackupFile
                                            userInfo:nil];
        return nil;
    }

    struct stat fileStatus;
    if (lstat(filePath.fileSystemRepresentation, &fileStatus) != 0 ||
        !S_ISREG(fileStatus.st_mode) || fileStatus.st_size <= 0 ||
        (unsigned long long)fileStatus.st_size > PXHelperMaximumEntitlementsFileBytes) {
        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                                code:PXKeychainBackupErrorInvalidBackupFile
                                            userInfo:nil];
        return nil;
    }

    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfFile:filePath options:0 error:&readError];
    if (!data || readError || data.length == 0 || data.length > PXHelperMaximumEntitlementsFileBytes ||
        data.length != (NSUInteger)fileStatus.st_size) {
        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                                code:PXKeychainBackupErrorInvalidBackupFile
                                            userInfo:nil];
        return nil;
    }

    NSPropertyListFormat format = NSPropertyListOpenStepFormat;
    NSError *plistError = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:NSPropertyListImmutable
                                                          format:&format
                                                           error:&plistError];
    if (plistError || ![plist isKindOfClass:[NSDictionary class]]) {
        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                                code:PXKeychainBackupErrorInvalidBackupFile
                                            userInfo:nil];
        return nil;
    }
    id rawGroups = ((NSDictionary *)plist)[@"keychain-access-groups"];
    if (![rawGroups isKindOfClass:[NSArray class]] || [(NSArray *)rawGroups count] == 0 ||
        [(NSArray *)rawGroups count] > PXHelperMaximumAccessGroups) {
        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                                code:PXKeychainBackupErrorInvalidBackupFile
                                            userInfo:nil];
        return nil;
    }

    NSMutableArray<NSString *> *groups = [NSMutableArray arrayWithCapacity:[(NSArray *)rawGroups count]];
    NSMutableSet<NSString *> *seen = [NSMutableSet setWithCapacity:[(NSArray *)rawGroups count]];
    NSUInteger totalBytes = 0;
    for (id value in (NSArray *)rawGroups) {
        NSUInteger groupBytes = 0;
        if (!PXHelperAccessGroupIsValid(value, &groupBytes)) {
            if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                                    code:PXKeychainBackupErrorInvalidBackupFile
                                                userInfo:nil];
            return nil;
        }
        NSUInteger nextTotal = 0;
        if (!PXHelperAddWithoutOverflow(totalBytes,
                                        groupBytes,
                                        PXHelperMaximumAccessGroupCSVBytes,
                                        &nextTotal)) {
            if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                                    code:PXKeychainBackupErrorInvalidBackupFile
                                                userInfo:nil];
            return nil;
        }
        totalBytes = nextTotal;
        NSString *immutableGroup = [(NSString *)value copy];
        if (![seen containsObject:immutableGroup]) {
            [seen addObject:immutableGroup];
            [groups addObject:immutableGroup];
        }
    }
    if (groups.count == 0) {
        if (error) *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                                code:PXKeychainBackupErrorInvalidBackupFile
                                            userInfo:nil];
        return nil;
    }
    return [groups copy];
}

static BOOL PXRequestedGroupsAreSubsetOfEffectiveGroups(
    NSArray<NSString *> *requested,
    NSArray<NSString *> *effective) {
    NSSet<NSString *> *effectiveSet = [NSSet setWithArray:effective];
    for (NSString *group in requested) {
        if (![effectiveSet containsObject:group]) {
            return NO;
        }
    }
    return YES;
}

static PXKeychainHelperOperation PXStructuredOperationForAction(PXHelperAction action) {
    switch (action) {
        case PXHelperActionBackup: return PXKeychainHelperOperationBackup;
        case PXHelperActionRestore: return PXKeychainHelperOperationRestore;
        case PXHelperActionWipe: return PXKeychainHelperOperationWipe;
        case PXHelperActionList: return PXKeychainHelperOperationList;
        case PXHelperActionUnknown: return PXKeychainHelperOperationUnknown;
    }
    return PXKeychainHelperOperationUnknown;
}

static PXKeychainHelperCompletion PXStructuredCompletionForResult(PXKeychainBackupResult *result) {
    if (!result) return PXKeychainHelperCompletionFailed;
    if (result.itemsFailed > 0 || result.warnings.count > 0 || result.errors.count > 0) {
        return PXKeychainHelperCompletionPartial;
    }
    return PXKeychainHelperCompletionCompleted;
}

static NSError *PXStructuredSyntheticError(PXKeychainBackupErrorCode code) {
    return [NSError errorWithDomain:PXKeychainBackupErrorDomain code:code userInfo:nil];
}

static PXKeychainHelperExitCode PXExitCodeForFatalError(PXKeychainHelperOperation operation,
                                                         NSError *fatalError) {
    if (![fatalError.domain isEqualToString:PXKeychainBackupErrorDomain]) {
        return PXKeychainHelperExitCodeOperationFailed;
    }
    switch ((PXKeychainBackupErrorCode)fatalError.code) {
        case PXKeychainBackupErrorInvalidArguments:
        case PXKeychainBackupErrorNoAccessGroups:
            return PXKeychainHelperExitCodeInvalidArguments;
        case PXKeychainBackupErrorSecurityFramework:
            return PXKeychainHelperExitCodeAccessDenied;
        case PXKeychainBackupErrorFileIO:
        case PXKeychainBackupErrorInvalidBackupFile:
            return operation == PXKeychainHelperOperationRestore
                ? PXKeychainHelperExitCodeInvalidInput
                : PXKeychainHelperExitCodeOperationFailed;
        case PXKeychainBackupErrorUnknown:
            return PXKeychainHelperExitCodeOperationFailed;
    }
    return PXKeychainHelperExitCodeOperationFailed;
}

static PXKeychainHelperResult *PXCreateStructuredResult(
    PXKeychainHelperOperation operation,
    PXKeychainHelperCompletion completion,
    PXKeychainBackupResult *result,
    NSUInteger listCount,
    NSArray<NSString *> *requestedAccessGroups,
    NSArray<NSString *> *effectiveAccessGroups,
    NSError *fatalError) {
    NSUInteger attemptedCount = 0;
    NSUInteger succeededCount = 0;
    NSUInteger failedCount = 0;
    NSUInteger warningCount = 0;
    NSUInteger errorCount = 0;
    if (operation == PXKeychainHelperOperationList &&
        completion == PXKeychainHelperCompletionCompleted) {
        attemptedCount = listCount;
        succeededCount = listCount;
    } else if (result) {
        attemptedCount = result.itemsProcessed;
        succeededCount = result.itemsSucceeded;
        failedCount = result.itemsFailed;
        warningCount = result.warnings.count;
        errorCount = result.errors.count;
    }

    NSError *constructionError = nil;
    PXKeychainHelperResult *structuredResult =
        [PXKeychainHelperResult resultWithOperation:operation
                                         completion:completion
                                     attemptedCount:attemptedCount
                                     succeededCount:succeededCount
                                        failedCount:failedCount
                                       skippedCount:0
                                       warningCount:warningCount
                                         errorCount:errorCount
                              requestedAccessGroups:requestedAccessGroups ?: @[]
                              effectiveAccessGroups:effectiveAccessGroups ?: @[]
                                         fatalError:fatalError
                                              error:&constructionError];
    (void)constructionError;
    return structuredResult;
}

static void PXEmitStructuredResult(PXKeychainHelperResult *result) {
    NSString *line = result.machineReadableLine;
    if (!line.length) {
        line = @"PXKEYCHAIN_HELPER_RESULT_V2=INVALID";
    }
    fprintf(stdout, "%s\n", [line UTF8String] ?: "");
    fflush(stdout);
}

static PXKeychainHelperExitCode PXFinalizeStructuredResult(
    PXKeychainHelperResult *result,
    PXKeychainHelperExitCode intendedExitCode) {
    NSString *line = result.machineReadableLine;
    BOOL compatible = result != nil &&
                      line.length > PXKeychainHelperResultOutputPrefix.length &&
                      [line hasPrefix:PXKeychainHelperResultOutputPrefix] &&
                      [line rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location == NSNotFound;
    if (compatible) {
        switch (result.completion) {
            case PXKeychainHelperCompletionCompleted:
                compatible = intendedExitCode == PXKeychainHelperExitCodeCompleted;
                break;
            case PXKeychainHelperCompletionPartial:
                compatible = intendedExitCode == PXKeychainHelperExitCodePartial;
                break;
            case PXKeychainHelperCompletionFailed:
                compatible = intendedExitCode == PXKeychainHelperExitCodeInvalidArguments ||
                             intendedExitCode == PXKeychainHelperExitCodeInvalidInput ||
                             intendedExitCode == PXKeychainHelperExitCodeAccessDenied ||
                             intendedExitCode == PXKeychainHelperExitCodeOperationFailed;
                break;
            default:
                compatible = NO;
                break;
        }
    }
    PXEmitStructuredResult(compatible ? result : nil);
    return compatible ? intendedExitCode : PXKeychainHelperExitCodeProtocolFailure;
}

static PXKeychainHelperExitCode PXFinalizeFailure(
    PXKeychainHelperOperation operation,
    PXKeychainHelperExitCode exitCode,
    NSArray<NSString *> *requestedAccessGroups,
    NSArray<NSString *> *effectiveAccessGroups,
    PXKeychainBackupErrorCode errorCode) {
    return PXFinalizeStructuredResult(
        PXCreateStructuredResult(operation,
                                 PXKeychainHelperCompletionFailed,
                                 nil,
                                 0,
                                 requestedAccessGroups ?: @[],
                                 effectiveAccessGroups ?: @[],
                                 PXStructuredSyntheticError(errorCode)),
        exitCode);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSMutableDictionary<NSString *, id> *args = [NSMutableDictionary dictionary];
        NSMutableSet<NSString *> *seenOptions = [NSMutableSet set];
        NSSet<NSString *> *valueOptions = [NSSet setWithArray:@[
            @"action",
            @"file",
            @"groups",
            @"requested-groups",
            @"effective-entitlements-file",
        ]];
        BOOL argumentParseFailed = NO;

        for (int i = 1; i < argc; i++) {
            NSString *argument = @(argv[i]);
            if ([argument isEqualToString:@"--help"] || [argument isEqualToString:@"-h"]) {
                printUsage(argv[0]);
                return PXKeychainHelperExitCodeCompleted;
            }
            if ([argument isEqualToString:@"--verbose"] || [argument isEqualToString:@"-v"] ||
                [argument isEqualToString:@"--overwrite"]) {
                NSString *key = [argument isEqualToString:@"--overwrite"] ? @"overwrite" : @"verbose";
                if ([seenOptions containsObject:key]) {
                    argumentParseFailed = YES;
                    break;
                }
                [seenOptions addObject:key];
                args[key] = @YES;
                continue;
            }
            if (![argument hasPrefix:@"--"]) {
                argumentParseFailed = YES;
                break;
            }
            NSString *key = [argument substringFromIndex:2];
            if (![valueOptions containsObject:key] || [seenOptions containsObject:key] ||
                i + 1 >= argc) {
                argumentParseFailed = YES;
                break;
            }
            NSString *value = @(argv[i + 1]);
            [seenOptions addObject:key];
            args[key] = value;
            i++;
        }

        NSString *actionString = args[@"action"];
        PXHelperAction action = parseAction(actionString);
        PXKeychainHelperOperation structuredOperation = PXStructuredOperationForAction(action);
        NSArray<NSString *> *emptyGroups = @[];
        if (argumentParseFailed) {
            logError(@"Invalid or duplicate command-line argument");
            return PXFinalizeFailure(structuredOperation,
                                     PXKeychainHelperExitCodeInvalidArguments,
                                     emptyGroups,
                                     emptyGroups,
                                     PXKeychainBackupErrorInvalidArguments);
        }
        if (!actionString.length) {
            logError(@"Missing required --action argument");
            printUsage(argv[0]);
            return PXFinalizeFailure(PXKeychainHelperOperationUnknown,
                                     PXKeychainHelperExitCodeInvalidArguments,
                                     emptyGroups,
                                     emptyGroups,
                                     PXKeychainBackupErrorInvalidArguments);
        }
        if (action == PXHelperActionUnknown) {
            logError(@"Unknown action");
            printUsage(argv[0]);
            return PXFinalizeFailure(PXKeychainHelperOperationUnknown,
                                     PXKeychainHelperExitCodeInvalidArguments,
                                     emptyGroups,
                                     emptyGroups,
                                     PXKeychainBackupErrorInvalidArguments);
        }

        NSString *requestedCSV = args[@"requested-groups"];
        NSString *effectiveEntitlementsPath = args[@"effective-entitlements-file"];
        if (![requestedCSV isKindOfClass:[NSString class]] ||
            ![effectiveEntitlementsPath isKindOfClass:[NSString class]]) {
            logError(@"Missing required group-report metadata");
            return PXFinalizeFailure(structuredOperation,
                                     PXKeychainHelperExitCodeInvalidArguments,
                                     emptyGroups,
                                     emptyGroups,
                                     PXKeychainBackupErrorInvalidArguments);
        }

        NSError *metadataError = nil;
        NSArray<NSString *> *requestedAccessGroups =
            PXCanonicalAccessGroupsFromCSV(requestedCSV, &metadataError);
        if (!requestedAccessGroups) {
            logError(@"Invalid requested access-group metadata");
            return PXFinalizeFailure(structuredOperation,
                                     PXKeychainHelperExitCodeInvalidArguments,
                                     emptyGroups,
                                     emptyGroups,
                                     PXKeychainBackupErrorInvalidArguments);
        }
        NSArray<NSString *> *effectiveAccessGroups =
            PXEffectiveAccessGroupsFromEntitlementsFile(effectiveEntitlementsPath, &metadataError);
        if (!effectiveAccessGroups ||
            !PXRequestedGroupsAreSubsetOfEffectiveGroups(requestedAccessGroups, effectiveAccessGroups)) {
            logError(@"Invalid effective access-group metadata");
            return PXFinalizeFailure(structuredOperation,
                                     PXKeychainHelperExitCodeInvalidInput,
                                     emptyGroups,
                                     emptyGroups,
                                     PXKeychainBackupErrorInvalidBackupFile);
        }

        NSString *filePath = args[@"file"];
        NSString *operationalCSV = args[@"groups"];
        NSArray<NSString *> *operationalGroups = nil;
        if (action == PXHelperActionRestore && operationalCSV != nil) {
            logError(@"Restore does not accept operational access groups");
            return PXFinalizeFailure(structuredOperation,
                                     PXKeychainHelperExitCodeInvalidArguments,
                                     requestedAccessGroups,
                                     effectiveAccessGroups,
                                     PXKeychainBackupErrorInvalidArguments);
        }
        if (action == PXHelperActionBackup || action == PXHelperActionWipe || action == PXHelperActionList) {
            operationalGroups = PXCanonicalAccessGroupsFromCSV(operationalCSV, &metadataError);
            if (!operationalGroups ||
                ![operationalGroups isEqualToArray:requestedAccessGroups]) {
                logError(@"Operational access groups do not match requested metadata");
                return PXFinalizeFailure(structuredOperation,
                                         PXKeychainHelperExitCodeInvalidArguments,
                                         requestedAccessGroups,
                                         effectiveAccessGroups,
                                         PXKeychainBackupErrorInvalidArguments);
            }
        }

        BOOL verbose = [args[@"verbose"] boolValue];
        BOOL overwrite = [args[@"overwrite"] boolValue];
        logVerbose(verbose, @"Group-report metadata accepted");

        NSError *error = nil;
        PXKeychainBackupResult *result = nil;
        switch (action) {
            case PXHelperActionBackup: {
                if (!filePath.length) {
                    logError(@"--file is required for backup");
                    return PXFinalizeFailure(structuredOperation,
                                             PXKeychainHelperExitCodeInvalidArguments,
                                             requestedAccessGroups,
                                             effectiveAccessGroups,
                                             PXKeychainBackupErrorInvalidArguments);
                }
                logVerbose(verbose, @"Starting keychain backup...");
                result = [KeychainBackupHelper backupKeychainToFile:filePath
                                                       accessGroups:operationalGroups
                                                        itemClasses:PXKeychainItemClassAll
                                                              error:&error];
                if (!result) {
                    logError(@"Backup failed: %@", error.localizedDescription);
                    NSError *fatalError = error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown);
                    PXKeychainHelperExitCode exitCode = PXExitCodeForFatalError(structuredOperation, fatalError);
                    return PXFinalizeStructuredResult(
                        PXCreateStructuredResult(structuredOperation,
                                                 PXKeychainHelperCompletionFailed,
                                                 nil,
                                                 0,
                                                 requestedAccessGroups,
                                                 effectiveAccessGroups,
                                                 fatalError),
                        exitCode);
                }
                logSuccess(@"Backup complete: %lu items processed, %lu succeeded, %lu failed",
                           (unsigned long)result.itemsProcessed,
                           (unsigned long)result.itemsSucceeded,
                           (unsigned long)result.itemsFailed);
                for (id warningObject in result.warnings) {
                    NSString *warning = PXSafeString(warningObject);
                    fprintf(stderr, "[WARN] %s\n", [warning UTF8String] ?: "");
                }
                PXKeychainHelperCompletion completion = PXStructuredCompletionForResult(result);
                PXKeychainHelperExitCode exitCode = completion == PXKeychainHelperCompletionCompleted
                    ? PXKeychainHelperExitCodeCompleted : PXKeychainHelperExitCodePartial;
                return PXFinalizeStructuredResult(
                    PXCreateStructuredResult(structuredOperation,
                                             completion,
                                             result,
                                             0,
                                             requestedAccessGroups,
                                             effectiveAccessGroups,
                                             nil),
                    exitCode);
            }

            case PXHelperActionRestore: {
                if (!filePath.length) {
                    logError(@"--file is required for restore");
                    return PXFinalizeFailure(structuredOperation,
                                             PXKeychainHelperExitCodeInvalidArguments,
                                             requestedAccessGroups,
                                             effectiveAccessGroups,
                                             PXKeychainBackupErrorInvalidArguments);
                }
                logVerbose(verbose, @"Starting keychain restore (overwrite requested: %@)...",
                           overwrite ? @"YES" : @"NO");
                result = [KeychainBackupHelper restoreKeychainFromFile:filePath
                                                             overwrite:overwrite
                                                                 error:&error];
                if (!result) {
                    logError(@"Restore failed: %@", error.localizedDescription);
                    NSError *fatalError = error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown);
                    PXKeychainHelperExitCode exitCode = PXExitCodeForFatalError(structuredOperation, fatalError);
                    return PXFinalizeStructuredResult(
                        PXCreateStructuredResult(structuredOperation,
                                                 PXKeychainHelperCompletionFailed,
                                                 nil,
                                                 0,
                                                 requestedAccessGroups,
                                                 effectiveAccessGroups,
                                                 fatalError),
                        exitCode);
                }
                logSuccess(@"Restore complete: %lu items processed, %lu succeeded, %lu failed",
                           (unsigned long)result.itemsProcessed,
                           (unsigned long)result.itemsSucceeded,
                           (unsigned long)result.itemsFailed);
                for (id warningObject in result.warnings) {
                    NSString *warning = PXSafeString(warningObject);
                    fprintf(stderr, "[WARN] %s\n", [warning UTF8String] ?: "");
                }
                for (id errorObject in result.errors) {
                    NSString *itemError = PXSafeString(errorObject);
                    fprintf(stderr, "[ERR] %s\n", [itemError UTF8String] ?: "");
                }
                PXKeychainHelperCompletion completion = PXStructuredCompletionForResult(result);
                PXKeychainHelperExitCode exitCode = completion == PXKeychainHelperCompletionCompleted
                    ? PXKeychainHelperExitCodeCompleted : PXKeychainHelperExitCodePartial;
                return PXFinalizeStructuredResult(
                    PXCreateStructuredResult(structuredOperation,
                                             completion,
                                             result,
                                             0,
                                             requestedAccessGroups,
                                             effectiveAccessGroups,
                                             nil),
                    exitCode);
            }

            case PXHelperActionWipe: {
                logVerbose(verbose, @"Starting keychain wipe...");
                result = [KeychainBackupHelper wipeKeychainForAccessGroups:operationalGroups
                                                               itemClasses:PXKeychainItemClassAll
                                                                     error:&error];
                NSUInteger processed = result ? result.itemsProcessed : 0;
                NSUInteger succeeded = result ? result.itemsSucceeded : 0;
                NSUInteger failed = result ? result.itemsFailed : 0;
                NSUInteger warningCount = result ? result.warnings.count : 0;
                fprintf(stdout,
                        "PXKEYCHAIN_WIPE_RESULT processed=%lu succeeded=%lu failed=%lu warnings=%lu\n",
                        (unsigned long)processed,
                        (unsigned long)succeeded,
                        (unsigned long)failed,
                        (unsigned long)warningCount);
                if (!result) {
                    logError(@"Wipe failed: %@", error.localizedDescription);
                    NSError *fatalError = error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown);
                    PXKeychainHelperExitCode exitCode = PXExitCodeForFatalError(structuredOperation, fatalError);
                    return PXFinalizeStructuredResult(
                        PXCreateStructuredResult(structuredOperation,
                                                 PXKeychainHelperCompletionFailed,
                                                 nil,
                                                 0,
                                                 requestedAccessGroups,
                                                 effectiveAccessGroups,
                                                 fatalError),
                        exitCode);
                }
                for (id warningObject in result.warnings) {
                    NSString *warning = PXSafeString(warningObject);
                    fprintf(stderr, "[WARN] %s\n", [warning UTF8String] ?: "");
                }
                PXKeychainHelperCompletion completion = PXStructuredCompletionForResult(result);
                PXKeychainHelperExitCode exitCode = completion == PXKeychainHelperCompletionCompleted
                    ? PXKeychainHelperExitCodeCompleted : PXKeychainHelperExitCodePartial;
                if (completion == PXKeychainHelperCompletionCompleted) {
                    logSuccess(@"Wipe complete: %lu items deleted", (unsigned long)result.itemsSucceeded);
                }
                return PXFinalizeStructuredResult(
                    PXCreateStructuredResult(structuredOperation,
                                             completion,
                                             result,
                                             0,
                                             requestedAccessGroups,
                                             effectiveAccessGroups,
                                             nil),
                    exitCode);
            }

            case PXHelperActionList: {
                logVerbose(verbose, @"Diagnosing keychain access...");
                if (verbose) {
                    NSArray<NSDictionary *> *diagnostics =
                        [KeychainBackupHelper diagnoseKeychainAccessForGroups:operationalGroups
                                                                  itemClasses:PXKeychainItemClassAll];
                    for (NSDictionary *diagnostic in diagnostics) {
                        fprintf(stdout, "[DIAG] group=%s class=%s status=%d (%s) count=%lu\n",
                                [[diagnostic[@"accessGroup"] description] UTF8String] ?: "",
                                [[diagnostic[@"class"] description] UTF8String] ?: "",
                                [diagnostic[@"status"] intValue],
                                [[diagnostic[@"statusDesc"] description] UTF8String] ?: "",
                                (unsigned long)[diagnostic[@"count"] unsignedIntegerValue]);
                    }
                }
                logVerbose(verbose, @"Listing keychain items...");
                NSArray<NSDictionary *> *items =
                    [KeychainBackupHelper listKeychainItemsForAccessGroups:operationalGroups
                                                                itemClasses:PXKeychainItemClassAll];
                fprintf(stdout, "Found %lu keychain items:\n", (unsigned long)items.count);
                for (NSDictionary *item in items) {
                    NSString *itemClass = PXSafeString(item[@"class"]);
                    NSString *service = PXSafeString(item[@"service"]);
                    NSString *account = PXSafeString(item[@"account"]);
                    fprintf(stdout, "  - [%s] %s/%s\n",
                            itemClass.length ? [itemClass UTF8String] : "?",
                            [service UTF8String] ?: "",
                            [account UTF8String] ?: "");
                }
                return PXFinalizeStructuredResult(
                    PXCreateStructuredResult(structuredOperation,
                                             PXKeychainHelperCompletionCompleted,
                                             nil,
                                             items.count,
                                             requestedAccessGroups,
                                             effectiveAccessGroups,
                                             nil),
                    PXKeychainHelperExitCodeCompleted);
            }

            case PXHelperActionUnknown:
                break;
        }
        return PXFinalizeFailure(PXKeychainHelperOperationUnknown,
                                 PXKeychainHelperExitCodeInvalidArguments,
                                 emptyGroups,
                                 emptyGroups,
                                 PXKeychainBackupErrorInvalidArguments);
    }
}
