#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <os/log.h>
#import "TLinkIOSLogging.h"
#import "DBDebugLogger.h"
#include <stdarg.h>
#include <stdatomic.h>
#include <stdio.h>
#include <string.h>
static NSUserDefaults *PXFixtureDefaults(void);
static NSFileManager *PXFixtureFiles(void);
static NSFileHandle *PXFixtureOpen(NSString *path);
static NSRegularExpression *PXFixtureRegex(NSString *pattern);
static NSDateFormatter *PXFixtureDBFormatter(void);
static NSString *PXFixtureTemp(void);
static NSString *PXFixtureDirectory(BOOL mainLog,NSUInteger index);
static void PXFixtureEmit(NSString *message);
static void PXFixtureSchedule(dispatch_block_t job);
#include "PXPrimaryLogging.inc"
#include "PXDBLogging.inc"

static NSUInteger checks, failures, synchronizations;
static atomic_ulong closes;
static NSString *root, *fault;
static const char *scenario;
static BOOL fileEnabled, scheduleThrows, realDispatch, defaultsReentry, syncReentry, ioReentry;
static NSMutableArray *records, *pending;
static id errorInput;
#define CHECK(value,label) do { checks++;if (!(value)) { failures++;fprintf(stderr,"FAIL: %s\n",label); } } while (0)
static void Raise(void) { [NSException raise:@"fixture" format:@"diagnostic fault"]; }
static BOOL Case(const char *name) { return strcmp(scenario,name) == 0; }
static void Maybe(NSString *stage) {
    @try { if (ioReentry) PXLog(@"nested file callback");if ([fault isEqual:stage]) Raise(); }
    @finally { stage = nil; }
}
@interface PXLogDefaults : NSObject
- (BOOL)boolForKey:(NSString *)key;
- (BOOL)synchronize;
@end
@implementation PXLogDefaults
- (BOOL)boolForKey:(NSString *)key {
    @try { (void)key;if (defaultsReentry) PXLog(@"nested defaults callback");Maybe(@"defaults");return fileEnabled; }
    @finally { key = nil; }
}
- (BOOL)synchronize { synchronizations++;if (syncReentry) PXLogError(errorInput,@"nested sync");Maybe(@"sync");return YES; }
@end
static NSUserDefaults *PXFixtureDefaults(void) { static PXLogDefaults *defaults;if (!defaults) defaults = [PXLogDefaults new];return (id)defaults; }
@interface PXLogFiles : NSObject
- (BOOL)fileExistsAtPath:(NSString *)path;
- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)directory;
- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)intermediate attributes:(NSDictionary *)attributes error:(NSError **)error;
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)moveItemAtPath:(NSString *)path toPath:(NSString *)target error:(NSError **)error;
@end
@implementation PXLogFiles
- (BOOL)fileExistsAtPath:(NSString *)path { @try { Maybe(@"exists");return [[NSFileManager defaultManager] fileExistsAtPath:path]; } @finally { path = nil; } }
- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)directory { @try { Maybe(@"directory");return [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:directory]; } @finally { path = nil; } }
- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error { @try { Maybe(@"attributes");return [[NSFileManager defaultManager] attributesOfItemAtPath:path error:error]; } @finally { path = nil; } }
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)intermediate attributes:(NSDictionary *)attributes error:(NSError **)error {
    @try { Maybe(@"create");return [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:intermediate attributes:attributes error:error]; }
    @finally { path = nil;attributes = nil; }
}
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error { @try { Maybe(@"remove");return [[NSFileManager defaultManager] removeItemAtPath:path error:error]; } @finally { path = nil; } }
- (BOOL)moveItemAtPath:(NSString *)path toPath:(NSString *)target error:(NSError **)error { @try { Maybe(@"move");return [[NSFileManager defaultManager] moveItemAtPath:path toPath:target error:error]; } @finally { path = nil;target = nil; } }
@end
static NSFileManager *PXFixtureFiles(void) { static PXLogFiles *files;if (!files) files = [PXLogFiles new];return (id)files; }
@interface PXLogHandle : NSObject
@property (nonatomic,strong) NSFileHandle *actual;
- (unsigned long long)seekToEndOfFile;
- (void)writeData:(NSData *)data;
- (void)closeFile;
@end
@implementation PXLogHandle
- (unsigned long long)seekToEndOfFile { Maybe(@"seek");return [self.actual seekToEndOfFile]; }
- (void)writeData:(NSData *)data { @try { Maybe(@"write");[self.actual writeData:data]; } @finally { data = nil; } }
- (void)closeFile { closes++;[self.actual closeFile];Maybe(@"close"); }
@end
static NSFileHandle *PXFixtureOpen(NSString *path) {
    NSFileHandle *handle = nil;PXLogHandle *proxy = nil;
    @try { if ([fault isEqual:@"open-nil"]) return nil;Maybe(@"open");handle = [NSFileHandle fileHandleForWritingAtPath:path];if (!handle) return nil;proxy = [PXLogHandle new];proxy.actual = handle;return (id)proxy; }
    @finally { path = nil;handle = nil;proxy = nil; }
}
static NSRegularExpression *PXFixtureRegex(NSString *pattern) { @try { if (Case("regex-fault")) Raise();return [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL]; } @finally { pattern = nil; } }
static NSDateFormatter *PXFixtureDBFormatter(void) { if (Case("db-formatter-fault")) Raise();return [NSDateFormatter new]; }
static NSString *PXFixtureTemp(void) { return root; }
static NSString *PXFixtureDirectory(BOOL mainLog,NSUInteger index) { return [root stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%lu",mainLog ? @"main" : @"db",(unsigned long)index]]; }
static void PXFixtureEmit(NSString *message) { @try { @synchronized(records) { [records addObject:message ?: NSNull.null]; } } @finally { message = nil; } }
static void PXFixtureSchedule(dispatch_block_t job) {
    @try { if (scheduleThrows) Raise();if (realDispatch) dispatch_async(PXLogFileQueue(),job);else [pending addObject:[job copy]]; }
    @finally { job = nil; }
}
static void Drain(void) {
    dispatch_block_t job = nil;
    @try { while (pending.count) { job = pending[0];[pending removeObjectAtIndex:0];job();job = nil; } }
    @finally { job = nil; }
}
static NSString *MainPath(void) { return [PXFixtureDirectory(YES,0) stringByAppendingPathComponent:@"TLinkIOS.log"]; }
static NSString *DBPath(void) { return [PXFixtureDirectory(NO,0) stringByAppendingPathComponent:@"db_debug.log"]; }
static NSString *Text(NSString *path) { @try { return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL]; } @finally { path = nil; } }
@interface PXLogPayload : NSObject
@property (nonatomic) BOOL throws;
@property (nonatomic) BOOL db;
@property (nonatomic,strong) NSObject *token;
@end
@implementation PXLogPayload
- (NSUInteger)length { return 40; } // Private append lifetime probe, not a public NSString input.
- (NSString *)description { if (self.db) PXDBLog(@"nested description");else PXLog(@"nested description");if (self.throws) Raise();return @"payload-description"; }
@end
@interface PXLogErrorInput : NSObject
@property (nonatomic) NSInteger value;
@property (nonatomic) NSUInteger reads;
- (NSInteger)code;
- (NSString *)localizedDescription;
- (NSString *)domain;
@end
@implementation PXLogErrorInput
- (NSInteger)code { self.reads++;return self.value; }
- (NSString *)localizedDescription { PXLogError((id)self,@"recursive error getter");return @"error-description"; }
- (NSString *)domain { return NSCocoaErrorDomain; }
@end
static void EntryTests(void) {
    fileEnabled = NO;defaultsReentry = YES;
    PXLog(@"source %@ %@",@"192.0.2.1",@"12345678-1234-1234-1234-123456789abc");
    CHECK((records.count == 1 && [records[0] containsString:@"<redacted-ip>"] && [records[0] containsString:@"<redacted-id>"] && !pending.count),"private sink receives redacted output and file opt-out never schedules");
    defaultsReentry = NO;PXLog(nil);PXLog(@"");PXLog((id)@[]);CHECK(records.count == 1,"invalid and empty main formats are contained");
    __weak id weakPayload, weakToken;
    @autoreleasepool {
        PXLogPayload *payload = [PXLogPayload new];NSObject *token = [NSObject new];payload.token = token;weakPayload = payload;weakToken = token;
        payload.throws = YES;PXLog(@"%@",payload);payload = nil;token = nil;
    }
    CHECK((!weakPayload && !weakToken && !gPXInsideDiagnosticLog),"format exception releases caller payload and restores logger admission");
    @autoreleasepool {
        PXLogPayload *payload = [PXLogPayload new];NSObject *token = [NSObject new];payload.token = token;weakPayload = payload;weakToken = token;
        payload.db = YES;payload.throws = YES;PXDBLog(@"%@",payload);payload = nil;token = nil;
    }
    CHECK((!weakPayload && !weakToken && !gPXInsideDBLog),"DB format exception releases caller payload and restores logger admission");
    PXLog(@"after format fault");CHECK(records.count == 2,"subsequent logger call works after formatting failure");
    fileEnabled = YES;fault = @"defaults";PXLog(@"preference fault");fault = nil;
    CHECK((records.count == 3 && !pending.count && !gPXInsideDiagnosticLog),"preferences exception preserves prior private emission and submits no file job");
    PXLogError(nil,@"nil");PXLogError((id)[PXLogErrorInput new],@"ordinary");
    PXLogErrorInput *error = [PXLogErrorInput new];error.value = 4001;errorInput = error;syncReentry = YES;
    NSUInteger before = synchronizations;PXLogError((id)error,@"sync");
    CHECK((synchronizations == before+1 && error.reads == 1 && !gPXInsideErrorLog),"error code snapshot and recovery synchronize once despite recursive error callback");
    fault = @"sync";PXLogError((id)error,@"sync fault");fault = nil;syncReentry = NO;errorInput = nil;
    CHECK(!gPXInsideErrorLog,"recovery exception is contained and error guard resets");Drain();
}
static void FileTests(void) {
    fileEnabled = YES;PXLog(@"file-first");CHECK(pending.count == 1,"main file log is deferred");Drain();CHECK([Text(MainPath()) containsString:@"file-first"],"main worker creates first UTF8 record");
    NSUInteger before = closes;PXLog(@"file-second");Drain();CHECK((closes == before+1 && [Text(MainPath()) containsString:@"file-second"]),"main append closes its handle");
    for (NSString *stage in @[@"attributes",@"exists",@"open",@"seek",@"write",@"close"]) {
        before = closes;fault = stage;PXLog(@"worker-fault");Drain();fault = nil;
        BOOL acquired = [stage isEqual:@"seek"] || [stage isEqual:@"write"] || [stage isEqual:@"close"];
        CHECK((closes == before+(acquired ? 1 : 0) && !gPXInsideDiagnosticLog && !pending.count),"each worker fault is contained and acquired handles receive one close attempt");
        NSString *recovery = [NSString stringWithFormat:@"worker-recovered-%@",stage];
        PXLog(@"%@",recovery);Drain();CHECK([Text(MainPath()) containsString:recovery],"worker continues after each failed record");
    }
    before = records.count;ioReentry = YES;PXLog(@"no file recursion");Drain();ioReentry = NO;
    CHECK((records.count == before+1 && !pending.count),"worker-generated recursive logs cannot enqueue another cascade");
    NSMutableData *large = [NSMutableData dataWithLength:(NSUInteger)PXLogFileMaxBytes];[large writeToFile:MainPath() atomically:YES];
    PXLog(@"rotation");Drain();
    CHECK(([[NSData dataWithContentsOfFile:[MainPath() stringByAppendingString:@".1"]] length] == PXLogFileMaxBytes && [Text(MainPath()) containsString:@"rotation"]),"existing size threshold and one-backup rotation remain");
    PXDBLog(@"db-first");PXDBLog(@"db-second");CHECK(([Text(DBPath()) containsString:@"db-first"] && [Text(DBPath()) containsString:@"db-second"]),"DB sink remains synchronous and appends existing history");
    PXDBLog(@"");CHECK([Text(DBPath()) hasSuffix:@"] \n"],"valid empty DB format retains timestamped empty record behavior");
    for (NSString *stage in @[@"seek",@"write",@"close"]) {
        before = closes;fault = stage;PXDBLog(@"db-fault");fault = nil;CHECK((closes == before+1 && !gPXInsideDBLog),"DB exceptional append closes once and restores guard");
    }
    NSData *original = [NSData dataWithContentsOfFile:DBPath()];fault = @"open-nil";PXDBLog(@"must-not-replace-history");fault = nil;
    CHECK([original isEqual:[NSData dataWithContentsOfFile:DBPath()]],"failed DB append admission never atomically replaces existing log history");
    PXLogPayload *payload = [PXLogPayload new];payload.db = YES;PXDBLog(@"outer %@",payload);
    CHECK([Text(DBPath()) containsString:@"outer payload-description"],"DB description callback recursion is bounded");
}
static void LifetimeTests(void) {
    __weak id owner, token;
    @autoreleasepool {
        PXLogPayload *message = [PXLogPayload new];NSObject *payload = [NSObject new];message.token = payload;owner = message;token = payload;
        PXAppendToLogFile((id)message);message = nil;payload = nil;
    }
    CHECK((owner != nil && token != nil),"scheduled private append owns its input graph until delivery");
    @autoreleasepool { Drain(); }
    CHECK((!owner && !token),"completed job releases input and callback capture after pool drain");
    @autoreleasepool {
        PXLogPayload *message = [PXLogPayload new];NSObject *payload = [NSObject new];message.token = payload;owner = message;token = payload;
        scheduleThrows = YES;BOOL caught = NO;
        @try { PXAppendToLogFile((id)message); } @catch (__unused NSException *e) { caught = YES; }
        @finally { message = nil;payload = nil;scheduleThrows = NO; }
        CHECK((caught && !pending.count),"private scheduling fault propagates to its logger boundary without submission");
    }
    CHECK((!owner && !token),"plain ARC scheduling failure releases both input and heap block capture");
    scheduleThrows = YES;PXLog(@"public scheduling fault");scheduleThrows = NO;CHECK(!gPXInsideDiagnosticLog,"public scheduling fault is contained");
}
static void ConcurrentFiles(void) {
    fileEnabled = YES;realDispatch = YES;
    dispatch_group_t group = dispatch_group_create();
    for (NSUInteger index = 0; index < 24; index++) dispatch_group_async(group,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ @autoreleasepool { PXLog(@"queued-%lu",(unsigned long)index);PXDBLog(@"sync-%lu",(unsigned long)index); } });
    CHECK(dispatch_group_wait(group,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC)) == 0,"concurrent log callers finish");
    dispatch_sync(PXLogFileQueue(),^{});realDispatch = NO;
    NSString *main = Text(MainPath()), *db = Text(DBPath());BOOL complete = YES;
    for (NSUInteger index = 0; index < 24; index++) if (![main containsString:[NSString stringWithFormat:@"queued-%lu\n",(unsigned long)index]] || ![db containsString:[NSString stringWithFormat:@"sync-%lu\n",(unsigned long)index]]) complete = NO;
    CHECK(complete,"real serial worker and synchronized DB sink retain complete concurrent records");
}
int main(int argc,const char *argv[]) {
    if (argc != 2) return 2;scenario = argv[1];
    @autoreleasepool {
        root = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"px-diagnostic-" stringByAppendingString:NSUUID.UUID.UUIDString]];
        [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:NO attributes:nil error:NULL];
        [[NSFileManager defaultManager] createDirectoryAtPath:PXFixtureDirectory(YES,0) withIntermediateDirectories:NO attributes:nil error:NULL];
        [[NSFileManager defaultManager] createDirectoryAtPath:PXFixtureDirectory(NO,0) withIntermediateDirectories:NO attributes:nil error:NULL];
        records = [NSMutableArray array];pending = [NSMutableArray array];
        @try {
            if (Case("regex-fault")) { PXLog(@"sensitive 192.0.2.1");PXLog(@"retry");CHECK((!records.count && !pending.count && !gPXInsideDiagnosticLog),"regex initializer failure completes once and drops records without raw fallback"); }
            else if (Case("path-fault")) { fileEnabled = YES;fault = @"directory";PXLog(@"first");Drain();fault = nil;PXLog(@"second");Drain();CHECK((![[NSFileManager defaultManager] fileExistsAtPath:MainPath()] && !gPXInsideDiagnosticLog),"path initialization exception does not poison once or escape later worker"); }
            else if (Case("db-formatter-fault")) { PXDBLog(@"first");PXDBLog(@"second");CHECK((![[NSFileManager defaultManager] fileExistsAtPath:DBPath()] && !gPXInsideDBLog),"formatter initialization failure completes once without recursive wait or writes"); }
            else { EntryTests();FileTests();LifetimeTests();ConcurrentFiles(); }
        } @finally {
            dispatch_sync(PXLogFileQueue(),^{});[[NSFileManager defaultManager] removeItemAtPath:root error:NULL];
            root = fault = nil;records = pending = nil;errorInput = nil;
        }
    }
    fprintf(stdout,"Diagnostic sinks %s: %lu/%lu checks passed\n",scenario,(unsigned long)(checks-failures),(unsigned long)checks);
    return failures ? 1 : 0;
}
