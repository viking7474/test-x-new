#import "DBDebugLogger.h"
#import <Foundation/Foundation.h>
#include <stdarg.h>

static __thread BOOL gPXInsideDBLog;
static NSString *PXDBDebugLogFilePath(void) {
    NSArray *directories = nil;
    NSFileManager *files = nil;
    NSString *directory = nil, *preferred = nil;
    NSError *__autoreleasing error = nil;
    @try {
        directories = @[@"/var/mobile/Library/WeaponX/Logs",@"/private/var/mobile/Library/WeaponX/Logs"];
        files = [NSFileManager defaultManager];
        for (NSUInteger index = 0; index < directories.count; index++) {
            directory = directories[index];BOOL exists = NO;
            if ([files fileExistsAtPath:directory isDirectory:&exists] && exists) return [directory stringByAppendingPathComponent:@"db_debug.log"];
        }
        preferred = directories.firstObject;
        if (preferred.length) {
            [files createDirectoryAtPath:preferred withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0755,NSFileOwnerAccountName:@"mobile"} error:&error];
            if (!error) return [preferred stringByAppendingPathComponent:@"db_debug.log"];
        }
        return [NSTemporaryDirectory() stringByAppendingPathComponent:@"db_debug.log"];
    } @finally { directories = nil;files = nil;directory = nil;preferred = nil; }
}
static NSDateFormatter *PXDBDateFormatter(void) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDateFormatter *candidate = nil;
        @try { candidate = [NSDateFormatter new];[candidate setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];formatter = candidate; }
        @catch (__unused NSException *exception) { formatter = nil; }
        @finally { candidate = nil; }
    });
    return formatter;
}
static NSObject *PXDBFileLock(void) {
    static NSObject *lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try { lock = [NSObject new]; }
        @catch (__unused NSException *exception) { lock = nil; }
    });
    return lock;
}
void PXDBLog(NSString *format, ...) {
    NSString *message = nil, *timestamp = nil, *line = nil, *path = nil;
    NSData *data = nil;
    NSDate *date = nil;
    NSDateFormatter *formatter = nil;
    NSFileManager *files = nil;
    NSFileHandle *handle = nil;
    NSObject *fileLock = nil;
    BOOL previous = gPXInsideDBLog;
    @autoreleasepool {
        @try {
            if (previous) return;
            gPXInsideDBLog = YES;
            if (![format isKindOfClass:NSString.class]) return;
            formatter = PXDBDateFormatter();if (!formatter) return;
            va_list args;va_start(args,format);
            @try { message = [[NSString alloc] initWithFormat:format arguments:args]; }
            @finally { va_end(args); }
            date = [NSDate date];timestamp = [formatter stringFromDate:date];
            line = [NSString stringWithFormat:@"[DB %@] %@\n",timestamp,message ?: @""];
            path = PXDBDebugLogFilePath();data = [line dataUsingEncoding:NSUTF8StringEncoding];
            if (!path.length || !data.length) return;
            files = [NSFileManager defaultManager];
            fileLock = PXDBFileLock();if (!fileLock) return;
            @synchronized(fileLock) {
                @try {
                    if (![files fileExistsAtPath:path]) [data writeToFile:path atomically:YES];
                    else {
                        handle = [NSFileHandle fileHandleForWritingAtPath:path];
                        // An existing log must not be atomically replaced just
                        // because append admission failed: that loses its history.
                        if (!handle) return;
                        [handle seekToEndOfFile];[handle writeData:data];
                    }
                } @finally {
                    if (handle) { @try { [handle closeFile]; } @catch (__unused NSException *exception) { } }
                    handle = nil;
                }
            }
        } @catch (__unused NSException *exception) { }
        @finally {
            if (handle) { @try { [handle closeFile]; } @catch (__unused NSException *exception) { } }
            handle = nil;format = nil;message = nil;timestamp = nil;line = nil;path = nil;
            data = nil;date = nil;formatter = nil;files = nil;fileLock = nil;gPXInsideDBLog = previous;
        }
    }
}
