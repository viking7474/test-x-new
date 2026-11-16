#import "TLinkIOSLogging.h"
#import <Foundation/Foundation.h>
#import <os/log.h>
#include <stdarg.h>

static const unsigned long long PXLogFileMaxBytes = 1ULL * 1024ULL * 1024ULL;
static __thread BOOL gPXInsideDiagnosticLog;
static __thread BOOL gPXInsideErrorLog;
static dispatch_queue_t PXLogFileQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ queue = dispatch_queue_create("com.hydra.tlinkios.logging.file", DISPATCH_QUEUE_SERIAL); });
    return queue;
}
static os_log_t PXLogObject(void) {
    static os_log_t logObject;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ logObject = os_log_create("com.hydra.tlinkios", "general"); });
    return logObject;
}
static BOOL PXFileLoggingEnabled(void) {
    NSUserDefaults *defaults = nil;
    @try { defaults = [NSUserDefaults standardUserDefaults];return [defaults boolForKey:@"tlinkios.fileLoggingEnabled"]; }
    @finally { defaults = nil; }
}
static NSString *PXLogFilePath(void) {
    static NSString *path;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *files = nil;
        NSArray *directories = nil;
        NSString *directory = nil, *fallback = nil;
        @try {
            files = [NSFileManager defaultManager];
            directories = @[@"/var/mobile/Library/Logs/TLinkIOS",@"/private/var/mobile/Library/Logs/TLinkIOS",@"/var/LIB/var/mobile/Library/Logs/TLinkIOS"];
            for (NSUInteger index = 0; index < directories.count; index++) {
                directory = directories[index];BOOL isDirectory = NO;
                if ([files fileExistsAtPath:directory isDirectory:&isDirectory] && isDirectory) {
                    path = [directory stringByAppendingPathComponent:@"TLinkIOS.log"];return;
                }
            }
            fallback = [NSTemporaryDirectory() stringByAppendingPathComponent:@"TLinkIOSLogs"];
            if ([files createDirectoryAtPath:fallback withIntermediateDirectories:YES attributes:nil error:NULL])
                path = [fallback stringByAppendingPathComponent:@"TLinkIOS.log"];
        } @catch (__unused NSException *exception) { path = nil; }
        @finally { files = nil;directories = nil;directory = nil;fallback = nil; }
    });
    return path;
}
static NSString *PXRedactSensitiveValues(NSString *message) {
    NSString *redacted = nil;
    @try {
        if (!message.length) return message ?: @"";
        static NSRegularExpression *ipv4Regex, *uuidRegex;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSRegularExpression *ipv4 = nil, *uuid = nil;
            @try {
                ipv4 = [NSRegularExpression regularExpressionWithPattern:@"\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b" options:0 error:NULL];
                uuid = [NSRegularExpression regularExpressionWithPattern:@"\\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\\b" options:0 error:NULL];
                ipv4Regex = ipv4;uuidRegex = uuid;
            } @catch (__unused NSException *exception) { ipv4Regex = nil;uuidRegex = nil; }
            @finally { ipv4 = nil;uuid = nil; }
        });
        if (!ipv4Regex || !uuidRegex) return nil; // Never fall back to raw diagnostics.
        redacted = [ipv4Regex stringByReplacingMatchesInString:message options:0 range:NSMakeRange(0,message.length) withTemplate:@"<redacted-ip>"];
        redacted = [uuidRegex stringByReplacingMatchesInString:redacted options:0 range:NSMakeRange(0,redacted.length) withTemplate:@"<redacted-id>"];
        return redacted;
    } @finally { message = nil;redacted = nil; }
}
static void PXWriteQueuedLog(NSString *message) {
    NSString *path = nil, *rotated = nil, *timestamp = nil, *line = nil;
    NSFileManager *files = nil;
    NSDictionary *attributes = nil;
    NSDateFormatter *formatter = nil;
    NSDate *date = nil;
    NSData *data = nil;
    NSFileHandle *handle = nil;
    BOOL previous = gPXInsideDiagnosticLog;
    @autoreleasepool {
        @try {
            if (previous) return;
            gPXInsideDiagnosticLog = YES;
            if (!message.length) return;
            path = PXLogFilePath();if (!path.length) return;
            files = [NSFileManager defaultManager];attributes = [files attributesOfItemAtPath:path error:NULL];
            if ([attributes[NSFileSize] unsignedLongLongValue] >= PXLogFileMaxBytes) {
                rotated = [path stringByAppendingString:@".1"];
                [files removeItemAtPath:rotated error:NULL];[files moveItemAtPath:path toPath:rotated error:NULL];
            }
            // Keep per-record locale/time-zone behavior of a fresh formatter.
            formatter = [NSDateFormatter new];[formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
            date = [NSDate date];timestamp = [formatter stringFromDate:date];
            line = [NSString stringWithFormat:@"[TLinkIOS %@] %@\n",timestamp,message];data = [line dataUsingEncoding:NSUTF8StringEncoding];
            if (!data.length) return;
            if ([files fileExistsAtPath:path]) {
                handle = [NSFileHandle fileHandleForWritingAtPath:path];if (!handle) return;
                [handle seekToEndOfFile];[handle writeData:data];
            } else [data writeToFile:path atomically:YES];
        } @catch (__unused NSException *exception) { }
        @finally {
            if (handle) { @try { [handle closeFile]; } @catch (__unused NSException *exception) { } }
            handle = nil;message = nil;path = nil;rotated = nil;timestamp = nil;line = nil;
            files = nil;attributes = nil;formatter = nil;date = nil;data = nil;gPXInsideDiagnosticLog = previous;
        }
    }
}
static void PXAppendToLogFile(NSString *message) {
    dispatch_block_t job = nil;
    @try {
        if (!message.length) return;
        { job = ^{ PXWriteQueuedLog(message); }; }
        dispatch_async(PXLogFileQueue(),job);
    } @finally { message = nil;job = nil; }
}
void PXLog(NSString *format, ...) {
    NSString *message = nil, *redacted = nil;
    BOOL previous = gPXInsideDiagnosticLog;
    @autoreleasepool {
        @try {
            if (previous) return;
            gPXInsideDiagnosticLog = YES;
            if (![format isKindOfClass:NSString.class] || !format.length) return;
            va_list args;va_start(args,format);
            @try { message = [[NSString alloc] initWithFormat:format arguments:args]; }
            @finally { va_end(args); }
            redacted = PXRedactSensitiveValues(message);if (!redacted) return;
            if (@available(iOS 10.0, *)) os_log_with_type(PXLogObject(),OS_LOG_TYPE_DEFAULT,"%{private}@",redacted);
            if (PXFileLoggingEnabled()) PXAppendToLogFile(redacted);
        } @catch (__unused NSException *exception) { }
        @finally { format = nil;message = nil;redacted = nil;gPXInsideDiagnosticLog = previous; }
    }
}
void PXLogError(NSError *error, NSString *context) {
    NSString *description = nil, *domain = nil;
    NSUserDefaults *defaults = nil;
    BOOL previous = gPXInsideErrorLog;
    @try {
        if (previous || !error) return;
        gPXInsideErrorLog = YES;
        NSInteger code = error.code;description = error.localizedDescription;
        PXLog(@"[%@] Error %ld: %@",context,(long)code,description);
        switch (code) {
            case 4001:
                defaults = [NSUserDefaults standardUserDefaults];[defaults synchronize];break;
            case 3001:case 3002:break;
            default:
                domain = error.domain;
                if ([domain isEqualToString:NSCocoaErrorDomain]) { /* Existing no-op permission observation. */ }
                break;
        }
    } @catch (__unused NSException *exception) { }
    @finally { error = nil;context = nil;description = nil;domain = nil;defaults = nil;gPXInsideErrorLog = previous; }
}
