/**
 * backup_helper - iOS Keychain Backup/Restore CLI Tool
 *
 * Usage:
 *   backup_helper --action backup --target <bundleID> --file <path>
 *   backup_helper --action restore --file <path> [--overwrite]
 *   backup_helper --action wipe --target <bundleID>
 *   backup_helper --action list --target <bundleID>
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

static void printUsage(const char *progname) {
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, "  %s --action backup --file <path> [--groups <group1,group2,...>]\n", progname);
    fprintf(stderr, "  %s --action restore --file <path> [--overwrite]\n", progname);
    fprintf(stderr, "  %s --action wipe --groups <group1,group2,...>\n", progname);
    fprintf(stderr, "  %s --action list --groups <group1,group2,...>\n", progname);
    fprintf(stderr, "\nOptions:\n");
    fprintf(stderr, "  --action <action>   Action to perform: backup, restore, wipe, list\n");
    fprintf(stderr, "  --file <path>       Path to backup/restore file (plist format)\n");
    fprintf(stderr, "  --groups <groups>   Comma-separated list of keychain access groups\n");
    fprintf(stderr, "  --overwrite         For restore: request replacement; existing duplicates are preserved\n");
    fprintf(stderr, "  --verbose           Print detailed progress information\n");
    fprintf(stderr, "  --help              Show this help message\n");
}

static PXHelperAction parseAction(NSString *actionStr) {
    if ([actionStr isEqualToString:@"backup"]) return PXHelperActionBackup;
    if ([actionStr isEqualToString:@"restore"]) return PXHelperActionRestore;
    if ([actionStr isEqualToString:@"wipe"]) return PXHelperActionWipe;
    if ([actionStr isEqualToString:@"list"]) return PXHelperActionList;
    return PXHelperActionUnknown;
}

static NSArray<NSString *> *parseGroups(NSString *groupsStr) {
    if (!groupsStr.length) return @[];
    NSArray *parts = [groupsStr componentsSeparatedByString:@","];
    NSMutableArray *groups = [NSMutableArray array];
    for (NSString *part in parts) {
        NSString *trimmed = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length) {
            [groups addObject:trimmed];
        }
    }
    return groups;
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
    // Cap to avoid huge logs
    NSUInteger maxLen = MIN(len, 32);
    NSMutableString *hex = [NSMutableString stringWithCapacity:maxLen * 2];
    for (NSUInteger i = 0; i < maxLen; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
    }
    if (len > maxLen) {
        [hex appendString:@"..." ];
    }
    return hex;
}

static NSString *PXSafeString(id v) {
    if (!v || v == (id)kCFNull) return @"";
    if ([v isKindOfClass:[NSString class]]) return (NSString *)v;
    if ([v isKindOfClass:[NSData class]]) {
        NSString *s = [[NSString alloc] initWithData:(NSData *)v encoding:NSUTF8StringEncoding];
        if (s.length) return s;
        return [NSString stringWithFormat:@"<data:%@>", PXHexStringFromData((NSData *)v)];
    }
    if ([v respondsToSelector:@selector(stringValue)]) {
        NSString *s = [v performSelector:@selector(stringValue)];
        if ([s isKindOfClass:[NSString class]] && s.length) return s;
    }
    return [[v description] ?: @"" copy];
}

static PXKeychainHelperOperation PXStructuredOperationForAction(PXHelperAction action) {
    switch (action) {
        case PXHelperActionBackup:
            return PXKeychainHelperOperationBackup;
        case PXHelperActionRestore:
            return PXKeychainHelperOperationRestore;
        case PXHelperActionWipe:
            return PXKeychainHelperOperationWipe;
        case PXHelperActionList:
            return PXKeychainHelperOperationList;
        case PXHelperActionUnknown:
            return PXKeychainHelperOperationUnknown;
    }
    return PXKeychainHelperOperationUnknown;
}

static PXKeychainHelperCompletion PXStructuredCompletionForResult(PXKeychainBackupResult *result) {
    if (!result) {
        return PXKeychainHelperCompletionFailed;
    }
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

static PXKeychainHelperResult *PXCreateStructuredResult(PXKeychainHelperOperation operation,
                                                        PXKeychainHelperCompletion completion,
                                                        PXKeychainBackupResult *result,
                                                        NSUInteger listCount,
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
                                         fatalError:fatalError
                                              error:&constructionError];
    (void)constructionError;
    return structuredResult;
}

static void PXEmitStructuredResult(PXKeychainHelperResult *result) {
    NSString *line = result.machineReadableLine;
    if (!line.length) {
        line = @"PXKEYCHAIN_HELPER_RESULT_V1=INVALID";
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

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        // Parse arguments.
        NSMutableDictionary *args = [NSMutableDictionary dictionary];
        
        for (int i = 1; i < argc; i++) {
            NSString *arg = @(argv[i]);
            
            if ([arg isEqualToString:@"--help"] || [arg isEqualToString:@"-h"]) {
                printUsage(argv[0]);
                return PXKeychainHelperExitCodeCompleted;
            } else if ([arg isEqualToString:@"--verbose"] || [arg isEqualToString:@"-v"]) {
                args[@"verbose"] = @YES;
            } else if ([arg isEqualToString:@"--overwrite"]) {
                args[@"overwrite"] = @YES;
            } else if ([arg hasPrefix:@"--"] && i + 1 < argc) {
                NSString *key = [arg substringFromIndex:2];
                NSString *value = @(argv[++i]);
                args[key] = value;
            }
        }
        
        BOOL verbose = [args[@"verbose"] boolValue];
        
        // Validate action.
        NSString *actionStr = args[@"action"];
        if (!actionStr.length) {
            logError(@"Missing required --action argument");
            printUsage(argv[0]);
            return PXFinalizeStructuredResult(
                PXCreateStructuredResult(PXKeychainHelperOperationUnknown,
                                         PXKeychainHelperCompletionFailed,
                                         nil,
                                         0,
                                         PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)),
                PXKeychainHelperExitCodeInvalidArguments);
        }
        
        PXHelperAction action = parseAction(actionStr);
        if (action == PXHelperActionUnknown) {
            logError(@"Unknown action: %@", actionStr);
            printUsage(argv[0]);
            return PXFinalizeStructuredResult(
                PXCreateStructuredResult(PXKeychainHelperOperationUnknown,
                                         PXKeychainHelperCompletionFailed,
                                         nil,
                                         0,
                                         PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)),
                PXKeychainHelperExitCodeInvalidArguments);
        }
        PXKeychainHelperOperation structuredOperation = PXStructuredOperationForAction(action);
        
        NSString *filePath = args[@"file"];
        NSArray<NSString *> *groups = parseGroups(args[@"groups"]);
        BOOL overwrite = [args[@"overwrite"] boolValue];
        
        logVerbose(verbose, @"Action: %@", actionStr);
        logVerbose(verbose, @"File: %@", filePath ?: @"(none)");
        logVerbose(verbose, @"Groups: %@", [groups componentsJoinedByString:@", "] ?: @"(none)");
        
        NSError *error = nil;
        PXKeychainBackupResult *result = nil;
        
        switch (action) {
            case PXHelperActionBackup: {
                if (!filePath.length) {
                    logError(@"--file is required for backup");
                    return PXFinalizeStructuredResult(
                        PXCreateStructuredResult(structuredOperation,
                                                 PXKeychainHelperCompletionFailed,
                                                 nil,
                                                 0,
                                                 PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)),
                        PXKeychainHelperExitCodeInvalidArguments);
                }
                if (!groups.count) {
                    logError(@"--groups is required for backup");
                    return PXFinalizeStructuredResult(
                        PXCreateStructuredResult(structuredOperation,
                                                 PXKeychainHelperCompletionFailed,
                                                 nil,
                                                 0,
                                                 PXStructuredSyntheticError(PXKeychainBackupErrorNoAccessGroups)),
                        PXKeychainHelperExitCodeInvalidArguments);
                }
                
                logVerbose(verbose, @"Starting keychain backup...");
                result = [KeychainBackupHelper backupKeychainToFile:filePath
                                                       accessGroups:groups
                                                        itemClasses:PXKeychainItemClassAll
                                                              error:&error];
                
                if (!result) {
                    logError(@"Backup failed: %@", error.localizedDescription);
                    NSError *fatalError = error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown);
                    PXKeychainHelperExitCode exitCode =
                        PXExitCodeForFatalError(structuredOperation, fatalError);
                    return PXFinalizeStructuredResult(
                        PXCreateStructuredResult(structuredOperation,
                                                 PXKeychainHelperCompletionFailed,
                                                 nil,
                                                 0,
                                                 fatalError),
                        exitCode);
                }
                
                logSuccess(@"Backup complete: %lu items processed, %lu succeeded, %lu failed",
                          (unsigned long)result.itemsProcessed,
                          (unsigned long)result.itemsSucceeded,
                          (unsigned long)result.itemsFailed);
                
                for (id warningObj in result.warnings) {
                    NSString *warning = PXSafeString(warningObj);
                    fprintf(stderr, "[WARN] %s\n", [warning UTF8String] ?: "");
                }
                PXKeychainHelperCompletion completion = PXStructuredCompletionForResult(result);
                PXKeychainHelperExitCode exitCode = completion == PXKeychainHelperCompletionCompleted
                    ? PXKeychainHelperExitCodeCompleted
                    : PXKeychainHelperExitCodePartial;
                return PXFinalizeStructuredResult(
                    PXCreateStructuredResult(structuredOperation, completion, result, 0, nil),
                    exitCode);
            }
                
            case PXHelperActionRestore: {
                if (!filePath.length) {
                    logError(@"--file is required for restore");
                    return PXFinalizeStructuredResult(
                        PXCreateStructuredResult(structuredOperation,
                                                 PXKeychainHelperCompletionFailed,
                                                 nil,
                                                 0,
                                                 PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)),
                        PXKeychainHelperExitCodeInvalidArguments);
                }
                
                logVerbose(verbose, @"Starting keychain restore (overwrite requested: %@)...",
                          overwrite ? @"YES" : @"NO");
                result = [KeychainBackupHelper restoreKeychainFromFile:filePath
                                                             overwrite:overwrite
                                                                 error:&error];
                
                if (!result) {
                    logError(@"Restore failed: %@", error.localizedDescription);
                    NSError *fatalError = error ?: PXStructuredSyntheticError(PXKeychainBackupErrorUnknown);
                    PXKeychainHelperExitCode exitCode =
                        PXExitCodeForFatalError(structuredOperation, fatalError);
                    return PXFinalizeStructuredResult(
                        PXCreateStructuredResult(structuredOperation,
                                                 PXKeychainHelperCompletionFailed,
                                                 nil,
                                                 0,
                                                 fatalError),
                        exitCode);
                }
                
                logSuccess(@"Restore complete: %lu items processed, %lu succeeded, %lu failed",
                          (unsigned long)result.itemsProcessed,
                          (unsigned long)result.itemsSucceeded,
                          (unsigned long)result.itemsFailed);
                
                for (id warningObj in result.warnings) {
                    NSString *warning = PXSafeString(warningObj);
                    fprintf(stderr, "[WARN] %s\n", [warning UTF8String] ?: "");
                }
                for (id errObj in result.errors) {
                    NSString *err = PXSafeString(errObj);
                    fprintf(stderr, "[ERR] %s\n", [err UTF8String] ?: "");
                }
                PXKeychainHelperCompletion completion = PXStructuredCompletionForResult(result);
                PXKeychainHelperExitCode exitCode = completion == PXKeychainHelperCompletionCompleted
                    ? PXKeychainHelperExitCodeCompleted
                    : PXKeychainHelperExitCodePartial;
                return PXFinalizeStructuredResult(
                    PXCreateStructuredResult(structuredOperation, completion, result, 0, nil),
                    exitCode);
            }
                
            case PXHelperActionWipe: {
                if (!groups.count) {
                    logError(@"--groups is required for wipe");
                    return PXFinalizeStructuredResult(
                        PXCreateStructuredResult(structuredOperation,
                                                 PXKeychainHelperCompletionFailed,
                                                 nil,
                                                 0,
                                                 PXStructuredSyntheticError(PXKeychainBackupErrorNoAccessGroups)),
                        PXKeychainHelperExitCodeInvalidArguments);
                }
                
                logVerbose(verbose, @"Starting keychain wipe...");
                result = [KeychainBackupHelper wipeKeychainForAccessGroups:groups
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
                    PXKeychainHelperExitCode exitCode =
                        PXExitCodeForFatalError(structuredOperation, fatalError);
                    return PXFinalizeStructuredResult(
                        PXCreateStructuredResult(structuredOperation,
                                                 PXKeychainHelperCompletionFailed,
                                                 nil,
                                                 0,
                                                 fatalError),
                        exitCode);
                }

                for (id warningObj in result.warnings) {
                    NSString *warning = PXSafeString(warningObj);
                    fprintf(stderr, "[WARN] %s\n", [warning UTF8String] ?: "");
                }
                if (result.itemsFailed > 0 || result.warnings.count > 0) {
                    return PXFinalizeStructuredResult(
                        PXCreateStructuredResult(structuredOperation,
                                                 PXKeychainHelperCompletionPartial,
                                                 result,
                                                 0,
                                                 nil),
                        PXKeychainHelperExitCodePartial);
                }

                logSuccess(@"Wipe complete: %lu items deleted",
                          (unsigned long)result.itemsSucceeded);
                PXKeychainHelperCompletion completion = PXStructuredCompletionForResult(result);
                PXKeychainHelperExitCode exitCode = completion == PXKeychainHelperCompletionCompleted
                    ? PXKeychainHelperExitCodeCompleted
                    : PXKeychainHelperExitCodePartial;
                return PXFinalizeStructuredResult(
                    PXCreateStructuredResult(structuredOperation, completion, result, 0, nil),
                    exitCode);
            }
                
            case PXHelperActionList: {
                if (!groups.count) {
                    logError(@"--groups is required for list");
                    return PXFinalizeStructuredResult(
                        PXCreateStructuredResult(structuredOperation,
                                                 PXKeychainHelperCompletionFailed,
                                                 nil,
                                                 0,
                                                 PXStructuredSyntheticError(PXKeychainBackupErrorNoAccessGroups)),
                        PXKeychainHelperExitCodeInvalidArguments);
                }

                logVerbose(verbose, @"Diagnosing keychain access...");
                if (verbose) {
                    NSArray<NSDictionary *> *diag = [KeychainBackupHelper diagnoseKeychainAccessForGroups:groups
                                                                                           itemClasses:PXKeychainItemClassAll];
                    for (NSDictionary *d in diag) {
                        fprintf(stdout, "[DIAG] group=%s class=%s status=%d (%s) count=%lu\n",
                                [[d[@"accessGroup"] description] UTF8String] ?: "",
                                [[d[@"class"] description] UTF8String] ?: "",
                                [d[@"status"] intValue],
                                [[d[@"statusDesc"] description] UTF8String] ?: "",
                                (unsigned long)[d[@"count"] unsignedIntegerValue]);
                    }
                }

                logVerbose(verbose, @"Listing keychain items...");
                NSArray<NSDictionary *> *items = [KeychainBackupHelper listKeychainItemsForAccessGroups:groups
                                                                                             itemClasses:PXKeychainItemClassAll];
                
                fprintf(stdout, "Found %lu keychain items:\n", (unsigned long)items.count);
                for (NSDictionary *item in items) {
                    NSString *cls = PXSafeString(item[@"class"]);
                    NSString *svc = PXSafeString(item[@"service"]);
                    NSString *acc = PXSafeString(item[@"account"]);
                    fprintf(stdout, "  - [%s] %s/%s\n",
                           cls.length ? [cls UTF8String] : "?",
                           [svc UTF8String] ?: "",
                           [acc UTF8String] ?: "");
                }
                return PXFinalizeStructuredResult(
                    PXCreateStructuredResult(structuredOperation,
                                             PXKeychainHelperCompletionCompleted,
                                             nil,
                                             items.count,
                                             nil),
                    PXKeychainHelperExitCodeCompleted);
            }
                
            default:
                return PXFinalizeStructuredResult(
                    PXCreateStructuredResult(PXKeychainHelperOperationUnknown,
                                             PXKeychainHelperCompletionFailed,
                                             nil,
                                             0,
                                             PXStructuredSyntheticError(PXKeychainBackupErrorInvalidArguments)),
                    PXKeychainHelperExitCodeInvalidArguments);
        }
    }
}
