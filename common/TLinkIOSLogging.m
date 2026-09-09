#import "TLinkIOSLogging.h"
#import <Foundation/Foundation.h>
#import <os/log.h>

static const unsigned long long PXLogFileMaxBytes = 1ULL * 1024ULL * 1024ULL;

static dispatch_queue_t PXLogFileQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.hydra.tlinkios.logging.file", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

static os_log_t PXLogObject(void) {
    static os_log_t logObject;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logObject = os_log_create("com.hydra.tlinkios", "general");
    });
    return logObject;
}

static BOOL PXFileLoggingEnabled(void) {
    // File logging is diagnostic-only. Keep it disabled by default and opt in explicitly.
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"tlinkios.fileLoggingEnabled"];
}

static NSString *PXLogFilePath(void) {
    static NSString *path;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray<NSString *> *directories = @[
            @"/var/mobile/Library/Logs/TLinkIOS",
            @"/private/var/mobile/Library/Logs/TLinkIOS",
            @"/var/LIB/var/mobile/Library/Logs/TLinkIOS"
        ];

        for (NSString *directory in directories) {
            BOOL isDirectory = NO;
            if ([fm fileExistsAtPath:directory isDirectory:&isDirectory] && isDirectory) {
                path = [directory stringByAppendingPathComponent:@"TLinkIOS.log"];
                return;
            }
        }

        NSString *fallbackDirectory =
            [NSTemporaryDirectory() stringByAppendingPathComponent:@"TLinkIOSLogs"];
        if ([fm createDirectoryAtPath:fallbackDirectory
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:nil]) {
            path = [fallbackDirectory stringByAppendingPathComponent:@"TLinkIOS.log"];
        }
    });
    return path;
}

static NSString *PXRedactSensitiveValues(NSString *message) {
    if (!message.length) {
        return message ?: @"";
    }

    static NSRegularExpression *ipv4Regex;
    static NSRegularExpression *uuidRegex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ipv4Regex = [NSRegularExpression regularExpressionWithPattern:@"\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b"
                                                               options:0
                                                                 error:nil];
        uuidRegex = [NSRegularExpression regularExpressionWithPattern:@"\\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\\b"
                                                               options:0
                                                                 error:nil];
    });

    NSString *redacted = [ipv4Regex stringByReplacingMatchesInString:message
                                                                 options:0
                                                                   range:NSMakeRange(0, message.length)
                                                            withTemplate:@"<redacted-ip>"];
    redacted = [uuidRegex stringByReplacingMatchesInString:redacted
                                                     options:0
                                                       range:NSMakeRange(0, redacted.length)
                                                withTemplate:@"<redacted-id>"];
    return redacted;
}

static void PXAppendToLogFile(NSString *message) {
    if (!message.length) {
        return;
    }

    dispatch_async(PXLogFileQueue(), ^{
        @autoreleasepool {
            NSString *path = PXLogFilePath();
            if (!path.length) {
                return;
            }

            NSFileManager *fm = [NSFileManager defaultManager];
            NSDictionary *attributes = [fm attributesOfItemAtPath:path error:nil];
            unsigned long long fileSize = [attributes[NSFileSize] unsignedLongLongValue];

            if (fileSize >= PXLogFileMaxBytes) {
                NSString *rotatedPath = [path stringByAppendingString:@".1"];
                [fm removeItemAtPath:rotatedPath error:nil];
                [fm moveItemAtPath:path toPath:rotatedPath error:nil];
            }

            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
            NSString *timestamp = [formatter stringFromDate:[NSDate date]];
            NSString *line = [NSString stringWithFormat:@"[TLinkIOS %@] %@\n", timestamp, message];
            NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
            if (!data.length) {
                return;
            }

            if ([fm fileExistsAtPath:path]) {
                NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
                if (!fileHandle) {
                    return;
                }
                @try {
                    [fileHandle seekToEndOfFile];
                    [fileHandle writeData:data];
                } @catch (__unused NSException *exception) {
                    // Diagnostic logging must never affect application behavior.
                }
                @try {
                    [fileHandle closeFile];
                } @catch (__unused NSException *exception) {
                }
            } else {
                [data writeToFile:path atomically:YES];
            }
        }
    });
}

void PXLog(NSString *format, ...) {
    if (!format.length) {
        return;
    }

    @autoreleasepool {
        @try {
            va_list args;
            va_start(args, format);
            NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
            va_end(args);

            NSString *redactedMessage = PXRedactSensitiveValues(message);

            // Use os_log's private interpolation so dynamic diagnostics are not exposed as public data.
            if (@available(iOS 10.0, *)) {
                os_log_with_type(PXLogObject(), OS_LOG_TYPE_DEFAULT, "%{private}@", redactedMessage);
            }

            if (PXFileLoggingEnabled()) {
                PXAppendToLogFile(redactedMessage);
            }
        } @catch (__unused NSException *exception) {
            // Logging must never affect application behavior.
        }
    }
}

void PXLogError(NSError *error, NSString *context) {
    if (!error) {
        return;
    }

    PXLog(@"[%@] Error %ld: %@", context, (long)error.code, error.localizedDescription);

    switch (error.code) {
        case 4001: // Settings save error
            [[NSUserDefaults standardUserDefaults] synchronize];
            break;

        case 3001: // Invalid bundle ID
        case 3002: // App not found
            break;

        default:
            if ([error.domain isEqualToString:NSCocoaErrorDomain]) {
                // Check permissions silently
            }
            break;
    }
}
