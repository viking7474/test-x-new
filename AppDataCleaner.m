#import "AppDataCleaner.h"
#import <Security/Security.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <errno.h>
#import <unistd.h>
#import <sys/stat.h>
#import <signal.h>
#import <math.h>
#import <float.h>
#import <string.h>
#import <sqlite3.h>
#import <notify.h>
#import <stdatomic.h>

#import "AppEntitlementsReader.h"
#import "CommandRunner.h"
#import "PXDataContainerResolver.h"
#import "PXDestructivePathValidator.h"
#import "PXClearRequest.h"
#import "PXClearResult.h"
#import "PXKeychainClearPlan.h"
#import "KeychainHelper/PXKeychainHelperExitCode.h"
#import "KeychainHelper/PXKeychainHelperResult.h"
#import "AppGroupContainerResolver.h"
#import "FreezeManager.h"
#import "common/PXProcessKiller.h"
#import "common/PXSecuritySettingsStore.h"

static const NSUInteger PXPrivilegedCommandMaxOutputBytes = 1024 * 1024;

// 7.4 Clear Data metrics: process-lifetime cumulative counters. The Clear entry
// point snapshots these before a run and reports per-run deltas in a [metric] line.
static _Atomic(uint_fast64_t) gPXClearShellProcessCount = 0;
static _Atomic(uint_fast64_t) gPXClearPathsScannedCount = 0;
static _Atomic(uint_fast64_t) gPXClearSqliteNanos = 0;

static NSString * const PXClearOperationThreadContextKey = @"PXClearOperationThreadContext";
static NSString * const PXClearOperationErrorDomain = @"PXClearOperation";

typedef NS_ENUM(NSInteger, PXClearOperationErrorCode) {
    PXClearOperationErrorCodeCancelled = 1,
    PXClearOperationErrorCodeDeadlineExceeded = 2,
};

@interface PXClearOperationContext : NSObject
@property (nonatomic, copy, readonly) NSString *operationID;
@property (nonatomic, strong, readonly) PXClearRequest *fullRequest;
@property (nonatomic, strong, readonly) PXClearRequest *dataRequest;
@property (nonatomic, copy) NSArray<NSString *> *applicationDataCanonicalPaths;
@property (nonatomic, copy) NSArray<NSString *> *appGroupCanonicalPaths;
@property (nonatomic, copy) NSArray<NSString *> *extensionDataCanonicalPaths;
@property (nonatomic, copy) NSArray<NSString *> *pluginKitDataCanonicalPaths;
@property (nonatomic, strong) PXKeychainClearPlan *keychainPlanSnapshot;
@property (nonatomic, assign) BOOL wasFrozenBeforeOperation;
@property (nonatomic, assign) BOOL ownsFreezeLease;
@property (nonatomic, assign) double resolveContainerMs;
@property (nonatomic, assign) uint_fast64_t timeoutFallbackCount;
@property (nonatomic, assign, readonly) NSTimeInterval startedUptime;
@property (nonatomic, assign, readonly) NSTimeInterval deadlineUptime;
- (instancetype)initWithFullRequest:(PXClearRequest *)fullRequest
                        dataRequest:(PXClearRequest *)dataRequest;
- (void)beginWithTimeout:(NSTimeInterval)timeoutSec;
- (void)requestCancellationWithReason:(NSString *)reason;
- (BOOL)isCancellationRequested;
- (NSString *)cancellationReason;
- (NSTimeInterval)remainingTime;
- (NSTimeInterval)clampedTimeoutForStepLimit:(NSTimeInterval)stepLimit;
@end

@implementation PXClearOperationContext {
    BOOL _cancellationRequested;
    NSString *_cancellationReason;
    NSTimeInterval _startedUptime;
    NSTimeInterval _deadlineUptime;
}

- (instancetype)initWithFullRequest:(PXClearRequest *)fullRequest
                        dataRequest:(PXClearRequest *)dataRequest {
    self = [super init];
    if (self) {
        _operationID = [[[NSUUID UUID] UUIDString] copy];
        _fullRequest = fullRequest;
        _dataRequest = dataRequest;
        _applicationDataCanonicalPaths = @[];
        _appGroupCanonicalPaths = @[];
        _extensionDataCanonicalPaths = @[];
        _pluginKitDataCanonicalPaths = @[];
    }
    return self;
}

- (void)beginWithTimeout:(NSTimeInterval)timeoutSec {
    @synchronized (self) {
        if (_startedUptime > 0.0) return;
        NSTimeInterval now = [NSProcessInfo processInfo].systemUptime;
        _startedUptime = now;
        _deadlineUptime = now + MAX(0.001, timeoutSec);
    }
}

- (NSTimeInterval)startedUptime {
    @synchronized (self) { return _startedUptime; }
}

- (NSTimeInterval)deadlineUptime {
    @synchronized (self) { return _deadlineUptime; }
}

- (void)requestCancellationWithReason:(NSString *)reason {
    @synchronized (self) {
        if (_cancellationRequested) return;
        _cancellationRequested = YES;
        _cancellationReason = [reason.length ? reason : @"cancelled" copy];
    }
}

- (BOOL)isCancellationRequested {
    @synchronized (self) { return _cancellationRequested; }
}

- (NSString *)cancellationReason {
    @synchronized (self) { return [_cancellationReason copy]; }
}

- (NSTimeInterval)remainingTime {
    @synchronized (self) {
        if (_cancellationRequested) return 0.0;
        if (_deadlineUptime <= 0.0) return DBL_MAX;
        return MAX(0.0, _deadlineUptime - [NSProcessInfo processInfo].systemUptime);
    }
}

- (NSTimeInterval)clampedTimeoutForStepLimit:(NSTimeInterval)stepLimit {
    if (![self isCancellationRequested]) {
        NSTimeInterval remaining = [self remainingTime];
        if (remaining <= 0.0) {
            [self requestCancellationWithReason:@"deadline"];
            return 0.0;
        }
        NSTimeInterval normalizedStep = (isfinite(stepLimit) && stepLimit > 0.0) ? stepLimit : remaining;
        return MIN(normalizedStep, remaining);
    }
    return 0.0;
}
@end

static dispatch_queue_t PXClearCoordinatorQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.weaponx.app-data-cleaner.clear-coordinator", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

static PXClearOperationContext *PXCurrentClearOperationContext(void) {
    id value = [[[NSThread currentThread] threadDictionary] objectForKey:PXClearOperationThreadContextKey];
    return [value isKindOfClass:[PXClearOperationContext class]] ? value : nil;
}

static void PXSetCurrentClearOperationContext(PXClearOperationContext *context) {
    NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    if (context) {
        threadDictionary[PXClearOperationThreadContextKey] = context;
    } else {
        [threadDictionary removeObjectForKey:PXClearOperationThreadContextKey];
    }
}

static NSError *PXClearOperationCancellationError(PXClearOperationContext *context) {
    BOOL deadline = [[context cancellationReason] isEqualToString:@"deadline"];
    return [NSError errorWithDomain:PXClearOperationErrorDomain
                               code:(deadline ? PXClearOperationErrorCodeDeadlineExceeded : PXClearOperationErrorCodeCancelled)
                           userInfo:@{NSLocalizedDescriptionKey:
                                          deadline ? @"Clear Data deadline exceeded" : @"Clear Data cancelled"}];
}

// Add SearchableIndex framework if available
#import <CoreSpotlight/CoreSpotlight.h>

@interface AppDataCleaner ()
// CLEAR-01: dry-run capable execution (internal). When dryRun is YES the clear
// only plans and journals the work and performs no destructive operations.
- (void)clearDataForBundleID:(NSString *)bundleID
                        mode:(PXClearMode)mode
                      dryRun:(BOOL)dryRun
                  completion:(void (^)(BOOL success, NSError *error))completion;
- (NSString *)runCommandAndGetOutput:(NSString *)command
                          timeoutSec:(NSTimeInterval)timeoutSec;
- (NSArray<NSString *> *)runBoundedFindWithArguments:(NSArray<NSString *> *)arguments;
- (PXClearResult *)_completeDataWipeForMigratedRequest:(PXClearRequest *)request;
- (PXClearComponentResult *)_completeAppDataWipeForApplicationDataRequest:(PXClearRequest *)request;
- (void)_clearAuthorizedICloudDataForRequest:(PXClearRequest *)request;
- (void)_clearExactAccountsOwnedByBundleIdentifier:(NSString *)bundleIdentifier;
- (void)_wipeMobileMailSharedStoreForRequest:(PXClearRequest *)request;
- (NSArray<NSString *> *)_exactInstalledExtensionIdentifiersForApplicationIdentifier:(NSString *)bundleIdentifier
                                                                                error:(NSError **)error;
- (NSArray<NSString *> *)_exactApplicationGroupIdentifiersForBundleIdentifier:(NSString *)bundleIdentifier
                                                                         error:(NSError **)error;
- (PXClearComponentResult *)_clearExactDataContainerComponentForIdentifiers:(NSArray<NSString *> *)identifiers
                                                                       kind:(PXResolvedContainerKind)kind
                                                                      scope:(PXClearScope)scope
                                                                 timeoutSec:(NSTimeInterval)timeoutSec
                                                             canonicalPaths:(NSArray<NSString *> **)canonicalPaths
                                                   successfulCanonicalPaths:(NSSet<NSString *> **)successfulCanonicalPaths;
- (PXClearComponentResult *)_componentByApplyingFinalPostconditionToResult:(PXClearComponentResult *)result
                                                            canonicalPaths:(NSArray<NSString *> *)canonicalPaths
                                                  successfulCanonicalPaths:(NSSet<NSString *> *)successfulCanonicalPaths;
- (PXClearComponentResult *)_clearExactAppGroupsComponentForIdentifiers:(NSArray<NSString *> *)identifiers
                                                              timeoutSec:(NSTimeInterval)timeoutSec
                                                          canonicalPaths:(NSArray<NSString *> **)canonicalPaths
                                                successfulCanonicalPaths:(NSSet<NSString *> **)successfulCanonicalPaths;
- (PXClearComponentResult *)_appGroupsComponentByApplyingFinalPostconditionToResult:(PXClearComponentResult *)result
                                                                     canonicalPaths:(NSArray<NSString *> *)canonicalPaths
                                                           successfulCanonicalPaths:(NSSet<NSString *> *)successfulCanonicalPaths;
- (void)_internalClearEncryptedDataOutsideMainApplicationContainer:(NSString *)bundleID
                                                         deepClean:(BOOL)deepClean;
- (PXKeychainClearPlan *)_keychainClearPlanForBundleIdentifier:(NSString *)bundleIdentifier;
- (PXKeychainHelperResult *)_readOnlyKeychainListResultForBundleIdentifier:(NSString *)bundleIdentifier
                                                              accessGroups:(NSArray<NSString *> *)accessGroups;
- (BOOL)_hasExactKeychainItemsForBundleIdentifier:(NSString *)bundleIdentifier
                                     accessGroups:(NSArray<NSString *> *)accessGroups
                                            known:(BOOL *)known;
- (BOOL)_executeKeychainWipeForBundleIdentifier:(NSString *)bundleIdentifier
                                  selectedGroups:(NSArray<NSString *> *)selectedGroups
                           applicationIdentifier:(NSString *)applicationIdentifier
                              systemApplication:(BOOL)systemApplication
                                          error:(NSError **)error;
- (PXClearComponentResult *)_keychainComponentForPlan:(PXKeychainClearPlan *)plan
                                          passResults:(NSArray<NSNumber *> *)passResults;

- (void)performFullCleanup:(NSString *)bundleID;
- (void)performAggressiveCleanupFor:(NSString *)bundleID;
- (void)completelyWipeContainer:(NSString *)containerPath;
- (BOOL)securelyWipeFile:(NSString *)path;
- (void)fixPermissionsAndRemovePath:(NSString *)path;
- (void)fixPermissionsForPath:(NSString *)path;
- (void)clearAppCache:(NSString *)bundleID;
- (void)clearAppPreferences:(NSString *)bundleID;
- (void)clearAppCookies:(NSString *)bundleID;
- (void)clearAppWebKitData:(NSString *)bundleID;
- (void)clearAppGroupData:(NSString *)bundleID;
- (void)clearPluginKitData:(NSString *)bundleID;
- (void)_internalClearEncryptedData:(NSString *)bundleID;
- (void)secureDataWipe:(NSString *)bundleID;
- (void)clearAppKeychain:(NSString *)bundleID;
- (void)clearKeychainData:(NSString *)bundleID;
- (void)clearKeychainItemsForBundleID:(NSString *)bundleID;
- (void)universalKeychainWipeForBundleID:(NSString *)bundleID;

- (void)performSecondaryCleanup:(NSString *)bundleID;
- (void)clearAppData:(NSString *)bundleID;
- (void)clearSharedContainers:(NSString *)bundleID;
- (void)clearUserDefaults:(NSString *)bundleID;
- (void)clearSQLiteDatabases:(NSString *)bundleID;
- (void)clearPrivateVarData:(NSString *)bundleID;
- (void)clearDeviceDatabase:(NSString *)bundleID;
- (void)clearInstallationLogs:(NSString *)bundleID;
- (void)clearNetworkConfigurations:(NSString *)bundleID;
- (void)clearCarrierData:(NSString *)bundleID;
- (void)clearNetworkData:(NSString *)bundleID;
- (void)clearDNSCache:(NSString *)bundleID;
- (void)clearCrashReports:(NSString *)bundleID;
- (void)clearDiagnosticData:(NSString *)bundleID;
- (void)clearBluetoothData:(NSString *)bundleID;
- (void)clearPushNotificationData:(NSString *)bundleID;
- (void)clearThumbnailCache:(NSString *)bundleID;
- (void)clearWebCache:(NSString *)bundleID;
- (void)clearGameData:(NSString *)bundleID;
- (void)clearTemporaryFiles:(NSString *)bundleID;
- (void)clearBinaryPlists:(NSString *)bundleID;
- (void)clearEncryptedData:(NSString *)bundleID;
- (void)clearJailbreakDetectionLogs:(NSString *)bundleID;
- (void)clearSpotlightData:(NSString *)bundleID;
- (void)clearSiriData:(NSString *)bundleID;
- (void)clearSystemLoggerData:(NSString *)bundleID;
- (void)clearASLLogs:(NSString *)bundleID;
- (void)clearPasteboardData:(NSString *)bundleID;
- (void)clearURLCache:(NSString *)bundleID;
- (void)clearBackgroundAssets:(NSString *)bundleID;
- (void)clearSharedStorage:(NSString *)bundleID;
- (void)clearAppStateData:(NSString *)bundleID;
@end


static NSString *PXClearJournalDirectory(void) {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *base = paths.firstObject ?: NSTemporaryDirectory();
    return [base stringByAppendingPathComponent:@"PXClearJournal"];
}

// CLEAR-01: append-only transaction journal for Clear Data runs. Records phase
// transitions (begin / dry_run_plan / dry_run_commit) as atomic binary plists.
// Stores only bundle id, mode, scopes, phase and a small non-secret info dict.
static BOOL PXClearWriteJournal(NSString *bundleID, PXClearMode mode, PXClearScope scopes, BOOL dryRun, NSString *phase, NSDictionary *info) {
    if (bundleID.length == 0 || phase.length == 0) return NO;
    NSString *dir = PXClearJournalDirectory();
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *dirError = nil;
    if (![fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&dirError]) {
        return NO;
    }
    NSMutableDictionary *journalEntry = [NSMutableDictionary dictionary];
    journalEntry[@"schemaVersion"] = @1;
    journalEntry[@"bundleID"] = bundleID;
    journalEntry[@"mode"] = PXClearModeName(mode) ?: @"unknown";
    journalEntry[@"scopes"] = @((unsigned long long)scopes);
    journalEntry[@"dryRun"] = @(dryRun);
    journalEntry[@"phase"] = phase;
    journalEntry[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
    if (info) journalEntry[@"info"] = info;
    NSError *plistError = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:journalEntry
                                                             format:NSPropertyListBinaryFormat_v1_0
                                                            options:0
                                                              error:&plistError];
    if (!data) return NO;
    NSString *safeBundle = [bundleID stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    NSString *fileName = [NSString stringWithFormat:@"clear-%@-%@-%.0f.plist", safeBundle, phase, [[NSDate date] timeIntervalSince1970] * 1000.0];
    NSString *path = [dir stringByAppendingPathComponent:fileName];
    return [data writeToFile:path atomically:YES];
}

static void PXLogQuarantinedLegacyClearSelector(SEL selector) {
    NSLog(@"[AppDataCleaner] Legacy Clear selector %@ is quarantined; use clearDataForBundleID:completion:.",
          NSStringFromSelector(selector));
}

@implementation AppDataCleaner {
    NSFileManager *_fileManager;
    // Per-wipe discovery cache: main application-data paths remain canonical validator outputs.
    NSString *_wipeCacheBundleID;
    NSArray<NSString *> *_wipeCacheApplicationDataCanonicalPaths;
    NSArray<NSString *> *_wipeCacheAppGroupCanonicalPaths;
    NSArray<NSString *> *_wipeCacheExtensionDataCanonicalPaths;
    NSArray<NSString *> *_wipeCachePluginKitDataCanonicalPaths;
}

- (BOOL)_sqliteExecAtPath:(NSString *)dbPath sql:(NSString *)sql errorOut:(NSString **)errorOut {
    if (!dbPath.length || !sql.length) {
        if (errorOut) *errorOut = @"invalid args";
        return NO;
    }
    sqlite3 *db = NULL;
    int rc = sqlite3_open_v2(dbPath.UTF8String, &db, SQLITE_OPEN_READWRITE, NULL);
    if (rc != SQLITE_OK || !db) {
        if (errorOut) {
            const char *msg = db ? sqlite3_errmsg(db) : "open failed";
            *errorOut = [NSString stringWithFormat:@"sqlite open rc=%d %s", rc, msg];
        }
        if (db) sqlite3_close(db);
        return NO;
    }
    sqlite3_busy_timeout(db, 3000);

    CFAbsoluteTime pxSqliteExecStart = CFAbsoluteTimeGetCurrent();
    char *errMsg = NULL;
    rc = sqlite3_exec(db, sql.UTF8String, NULL, NULL, &errMsg);
    atomic_fetch_add(&gPXClearSqliteNanos, (uint_fast64_t)((CFAbsoluteTimeGetCurrent() - pxSqliteExecStart) * 1e9));
    BOOL ok = (rc == SQLITE_OK);
    if (!ok && errorOut) {
        NSString *e = errMsg ? [NSString stringWithUTF8String:errMsg] : @"sqlite exec failed";
        *errorOut = [NSString stringWithFormat:@"sqlite exec rc=%d %@", rc, e ?: @""];
    }
    if (errMsg) sqlite3_free(errMsg);
    sqlite3_close(db);
    return ok;
}

// Execute SQL on an already-open sqlite handle.
static BOOL PXSQLiteExec(sqlite3 *db, NSString *sql, NSString **errorOut) {
    if (!db || !sql.length) {
        if (errorOut) *errorOut = @"invalid args";
        return NO;
    }
    CFAbsoluteTime pxSqliteStaticExecStart = CFAbsoluteTimeGetCurrent();
    char *errMsg = NULL;
    int rc = sqlite3_exec(db, sql.UTF8String, NULL, NULL, &errMsg);
    atomic_fetch_add(&gPXClearSqliteNanos, (uint_fast64_t)((CFAbsoluteTimeGetCurrent() - pxSqliteStaticExecStart) * 1e9));
    BOOL ok = (rc == SQLITE_OK);
    if (!ok && errorOut) {
        NSString *e = errMsg ? [NSString stringWithUTF8String:errMsg] : @"sqlite exec failed";
        *errorOut = [NSString stringWithFormat:@"sqlite exec rc=%d %@", rc, e ?: @""];
    }
    if (errMsg) sqlite3_free(errMsg);
    return ok;
}

static NSString *PXSQLiteScalar(sqlite3 *db, NSString *sql) {
    if (!db || !sql.length) return nil;
    sqlite3_stmt *stmt = NULL;
    int rc = sqlite3_prepare_v2(db, sql.UTF8String, -1, &stmt, NULL);
    if (rc != SQLITE_OK || !stmt) return nil;
    NSString *out = nil;
    rc = sqlite3_step(stmt);
    if (rc == SQLITE_ROW) {
        const unsigned char *txt = sqlite3_column_text(stmt, 0);
        if (txt) out = [NSString stringWithUTF8String:(const char *)txt];
    }
    sqlite3_finalize(stmt);
    return out;
}

static BOOL PXSQLiteTableHasColumn(sqlite3 *db, NSString *table, NSString *column) {
    if (!db || !table.length || !column.length) return NO;
    NSString *t = [table stringByReplacingOccurrencesOfString:@"'" withString:@"''"]; 
    NSString *sql = [NSString stringWithFormat:@"PRAGMA table_info('%@');", t];
    sqlite3_stmt *st = NULL;
    int rc = sqlite3_prepare_v2(db, sql.UTF8String, -1, &st, NULL);
    if (rc != SQLITE_OK || !st) {
        if (st) sqlite3_finalize(st);
        return NO;
    }
    BOOL found = NO;
    while (sqlite3_step(st) == SQLITE_ROW) {
        const unsigned char *name = sqlite3_column_text(st, 1); // column name
        if (name) {
            NSString *n = [NSString stringWithUTF8String:(const char *)name];
            if ([n isEqualToString:column]) {
                found = YES;
                break;
            }
        }
    }
    sqlite3_finalize(st);
    return found;
}

static BOOL PXSQLiteIsSafeIdentifier(NSString *s) {
    if (![s isKindOfClass:[NSString class]] || s.length == 0) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"];
    return ([[s stringByTrimmingCharactersInSet:allowed] length] == 0);
}

static NSSet<NSString *> *PXSQLiteColumnsForTableCached(sqlite3 *db,
                                                        NSString *table,
                                                        NSMutableDictionary<NSString *, NSSet<NSString *> *> *cache) {
    if (!db || !table.length) return [NSSet set];
    if (!cache) return [NSSet set];
    NSSet *cached = cache[table];
    if ([cached isKindOfClass:[NSSet class]]) return cached;

    if (!PXSQLiteIsSafeIdentifier(table)) {
        cache[table] = [NSSet set];
        return cache[table];
    }

    NSString *sql = [NSString stringWithFormat:@"PRAGMA table_info('%@');", table];
    sqlite3_stmt *st = NULL;
    int rc = sqlite3_prepare_v2(db, sql.UTF8String, -1, &st, NULL);
    if (rc != SQLITE_OK || !st) {
        if (st) sqlite3_finalize(st);
        cache[table] = [NSSet set];
        return cache[table];
    }

    NSMutableSet<NSString *> *cols = [NSMutableSet set];
    while (sqlite3_step(st) == SQLITE_ROW) {
        const unsigned char *name = sqlite3_column_text(st, 1);
        if (name) {
            NSString *n = [NSString stringWithUTF8String:(const char *)name];
            if (n.length) [cols addObject:n];
        }
    }
    sqlite3_finalize(st);

    cache[table] = [cols copy];
    return cache[table];
}

static BOOL PXSQLiteTableHasColumnCached(sqlite3 *db,
                                        NSString *table,
                                        NSString *column,
                                        NSMutableDictionary<NSString *, NSSet<NSString *> *> *cache) {
    if (!db || !table.length || !column.length) return NO;
    NSSet<NSString *> *cols = PXSQLiteColumnsForTableCached(db, table, cache);
    return [cols containsObject:column];
}

static void PXSQLiteLogAccountsSample(AppDataCleaner *selfRef, sqlite3 *db, NSString *label) {
    if (!selfRef || !db) return;

    NSMutableDictionary<NSString *, NSSet<NSString *> *> *colCache = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *cols = [NSMutableArray array];
    // Always include primary key if present.
    if (PXSQLiteTableHasColumnCached(db, @"ZACCOUNT", @"Z_PK", colCache)) [cols addObject:@"Z_PK"]; 
    if (PXSQLiteTableHasColumnCached(db, @"ZACCOUNT", @"ZACCOUNTTYPE", colCache)) [cols addObject:@"ZACCOUNTTYPE"]; 
    for (NSString *c in @[@"ZIDENTIFIER", @"ZUSERNAME", @"ZEMAILADDRESS", @"ZDISPLAYNAME", @"ZACCOUNTDESCRIPTION", @"ZOWNINGBUNDLEID"]) {
        if (PXSQLiteTableHasColumnCached(db, @"ZACCOUNT", c, colCache)) [cols addObject:c];
    }
    if (!cols.count) return;

    NSString *select = [NSString stringWithFormat:@"SELECT %@ FROM ZACCOUNT ORDER BY Z_PK LIMIT 10;", [cols componentsJoinedByString:@", "]];
    sqlite3_stmt *st = NULL;
    int rc = sqlite3_prepare_v2(db, select.UTF8String, -1, &st, NULL);
    if (rc != SQLITE_OK || !st) {
        if (st) sqlite3_finalize(st);
        return;
    }

    NSMutableArray *rows = [NSMutableArray array];
    while (sqlite3_step(st) == SQLITE_ROW) {
        NSMutableDictionary *row = [NSMutableDictionary dictionary];
        for (int i = 0; i < (int)cols.count; i++) {
            const unsigned char *txt = sqlite3_column_text(st, i);
            if (txt) {
                row[cols[i]] = [NSString stringWithUTF8String:(const char *)txt];
            } else {
                // Integers can come back as NULL in text; try int64.
                sqlite3_int64 v = sqlite3_column_int64(st, i);
                row[cols[i]] = [NSString stringWithFormat:@"%lld", v];
            }
        }
        [rows addObject:row];
    }
    sqlite3_finalize(st);
    if (rows.count) {
        [selfRef logMessage:@"[AppDataCleaner] %@ Accounts3 ZACCOUNT sample=%@", label ?: @"", rows];
    }
}

static void PXSQLiteLogMailAccountsDiagnostic(AppDataCleaner *selfRef, NSString *dbPath) {
    if (!selfRef || !dbPath.length) return;

    sqlite3 *db = NULL;
    int rc = sqlite3_open_v2(dbPath.UTF8String, &db, SQLITE_OPEN_READONLY, NULL);
    if (rc != SQLITE_OK || !db) {
        NSString *msg = db ? [NSString stringWithUTF8String:sqlite3_errmsg(db)] : @"open failed";
        [selfRef logMessage:@"[AppDataCleaner] MobileMail Accounts3 diagnostic: read-only open failed rc=%d %@", rc, msg ?: @""];
        if (db) sqlite3_close(db);
        return;
    }

    sqlite3_busy_timeout(db, 3000);
    NSMutableDictionary<NSString *, NSSet<NSString *> *> *colCache = [NSMutableDictionary dictionary];
    for (NSString *table in @[@"ZACCOUNT", @"ZACCOUNTTYPE", @"ZACCOUNTPROPERTY", @"ZCREDENTIALITEM"]) {
        NSArray<NSString *> *cols = [[PXSQLiteColumnsForTableCached(db, table, colCache) allObjects]
                                     sortedArrayUsingSelector:@selector(compare:)];
        [selfRef logMessage:@"[AppDataCleaner] MobileMail Accounts3 diagnostic: table=%@ columns=%@",
                            table, cols.count ? [cols componentsJoinedByString:@","] : @"(missing/none)"];
    }

    NSString *accountCount = PXSQLiteScalar(db, @"SELECT count(*) FROM ZACCOUNT;");
    NSString *typeCount = PXSQLiteScalar(db, @"SELECT count(*) FROM ZACCOUNTTYPE;");
    [selfRef logMessage:@"[AppDataCleaner] MobileMail Accounts3 diagnostic: accounts=%@ accountTypes=%@",
                        accountCount ?: @"(nil)", typeCount ?: @"(nil)"];

    BOOL hasAccountPK = PXSQLiteTableHasColumnCached(db, @"ZACCOUNT", @"Z_PK", colCache);
    BOOL hasAccountTypeFK = PXSQLiteTableHasColumnCached(db, @"ZACCOUNT", @"ZACCOUNTTYPE", colCache);
    BOOL hasTypePK = PXSQLiteTableHasColumnCached(db, @"ZACCOUNTTYPE", @"Z_PK", colCache);
    BOOL hasTypeIdentifier = PXSQLiteTableHasColumnCached(db, @"ZACCOUNTTYPE", @"ZIDENTIFIER", colCache);
    BOOL hasOwningBundle = PXSQLiteTableHasColumnCached(db, @"ZACCOUNT", @"ZOWNINGBUNDLEID", colCache);

    if (hasAccountPK && hasAccountTypeFK && hasTypePK && hasTypeIdentifier) {
        NSString *sql = hasOwningBundle
            ? @"SELECT a.Z_PK, t.ZIDENTIFIER, a.ZOWNINGBUNDLEID FROM ZACCOUNT a LEFT JOIN ZACCOUNTTYPE t ON a.ZACCOUNTTYPE=t.Z_PK ORDER BY a.Z_PK LIMIT 32;"
            : @"SELECT a.Z_PK, t.ZIDENTIFIER FROM ZACCOUNT a LEFT JOIN ZACCOUNTTYPE t ON a.ZACCOUNTTYPE=t.Z_PK ORDER BY a.Z_PK LIMIT 32;";
        sqlite3_stmt *st = NULL;
        if (sqlite3_prepare_v2(db, sql.UTF8String, -1, &st, NULL) == SQLITE_OK && st) {
            NSMutableArray<NSString *> *rows = [NSMutableArray array];
            while (sqlite3_step(st) == SQLITE_ROW) {
                sqlite3_int64 pk = sqlite3_column_int64(st, 0);
                const unsigned char *typeText = sqlite3_column_text(st, 1);
                NSString *typeID = typeText ? [NSString stringWithUTF8String:(const char *)typeText] : @"(nil)";
                if (hasOwningBundle) {
                    const unsigned char *ownerText = sqlite3_column_text(st, 2);
                    NSString *owner = ownerText ? [NSString stringWithUTF8String:(const char *)ownerText] : @"(nil)";
                    [rows addObject:[NSString stringWithFormat:@"pk=%lld type=%@ owner=%@", pk, typeID, owner]];
                } else {
                    [rows addObject:[NSString stringWithFormat:@"pk=%lld type=%@", pk, typeID]];
                }
            }
            sqlite3_finalize(st);
            [selfRef logMessage:@"[AppDataCleaner] MobileMail Accounts3 diagnostic: accountMap=%@",
                                rows.count ? [rows componentsJoinedByString:@" | "] : @"(empty)"];
        } else if (st) {
            sqlite3_finalize(st);
        }
    }

    if (hasAccountPK && PXSQLiteTableHasColumnCached(db, @"ZACCOUNTPROPERTY", @"ZOWNER", colCache)) {
        NSString *orphans = PXSQLiteScalar(db,
            @"SELECT count(*) FROM ZACCOUNTPROPERTY p LEFT JOIN ZACCOUNT a ON p.ZOWNER=a.Z_PK WHERE a.Z_PK IS NULL;");
        [selfRef logMessage:@"[AppDataCleaner] MobileMail Accounts3 diagnostic: orphan ZACCOUNTPROPERTY=%@", orphans ?: @"(nil)"];
    }
    if (hasAccountPK && PXSQLiteTableHasColumnCached(db, @"ZCREDENTIALITEM", @"ZOWNER", colCache)) {
        NSString *orphans = PXSQLiteScalar(db,
            @"SELECT count(*) FROM ZCREDENTIALITEM c LEFT JOIN ZACCOUNT a ON c.ZOWNER=a.Z_PK WHERE a.Z_PK IS NULL;");
        [selfRef logMessage:@"[AppDataCleaner] MobileMail Accounts3 diagnostic: orphan ZCREDENTIALITEM=%@", orphans ?: @"(nil)"];
    }

    sqlite3_close(db);
}

- (NSString *)_sqliteScalarAtPath:(NSString *)dbPath sql:(NSString *)sql errorOut:(NSString **)errorOut {
    if (!dbPath.length || !sql.length) {
        if (errorOut) *errorOut = @"invalid args";
        return nil;
    }
    sqlite3 *db = NULL;
    int rc = sqlite3_open_v2(dbPath.UTF8String, &db, SQLITE_OPEN_READONLY, NULL);
    if (rc != SQLITE_OK || !db) {
        if (errorOut) {
            const char *msg = db ? sqlite3_errmsg(db) : "open failed";
            *errorOut = [NSString stringWithFormat:@"sqlite open rc=%d %s", rc, msg];
        }
        if (db) sqlite3_close(db);
        return nil;
    }
    sqlite3_busy_timeout(db, 3000);

    sqlite3_stmt *stmt = NULL;
    rc = sqlite3_prepare_v2(db, sql.UTF8String, -1, &stmt, NULL);
    if (rc != SQLITE_OK || !stmt) {
        if (errorOut) {
            *errorOut = [NSString stringWithFormat:@"sqlite prepare rc=%d %s", rc, sqlite3_errmsg(db)];
        }
        if (stmt) sqlite3_finalize(stmt);
        sqlite3_close(db);
        return nil;
    }

    NSString *out = nil;
    rc = sqlite3_step(stmt);
    if (rc == SQLITE_ROW) {
        const unsigned char *txt = sqlite3_column_text(stmt, 0);
        if (txt) out = [NSString stringWithUTF8String:(const char *)txt];
    } else if (rc != SQLITE_DONE) {
        if (errorOut) {
            *errorOut = [NSString stringWithFormat:@"sqlite step rc=%d %s", rc, sqlite3_errmsg(db)];
        }
    }

    sqlite3_finalize(stmt);
    sqlite3_close(db);
    return out;
}

- (NSArray<NSString *> *)_resolvedAppGroupUUIDsFromEntitlements:(NSString *)bundleID rootless:(BOOL)rootless {
    if (!bundleID.length) return @[];

    AppEntitlementsReader *reader = [[AppEntitlementsReader alloc] init];
    NSError *entErr = nil;
    NSDictionary *ent = [reader fullEntitlementsForBundleID:bundleID error:&entErr];

    NSArray *groups = nil;
    if ([ent isKindOfClass:[NSDictionary class]]) {
        id v = ent[@"com.apple.security.application-groups"];
        if ([v isKindOfClass:[NSArray class]]) {
            groups = (NSArray *)v;
        } else {
            v = ent[@"application-groups"];
            if ([v isKindOfClass:[NSArray class]]) {
                groups = (NSArray *)v;
            }
        }
    }
    if (!groups.count) {
        return @[];
    }

    NSMutableArray<NSString *> *groupIDs = [NSMutableArray array];
    for (id g in groups) {
        if ([g isKindOfClass:[NSString class]] && [(NSString *)g length] > 0) {
            [groupIDs addObject:(NSString *)g];
        }
    }
    if (!groupIDs.count) {
        return @[];
    }

    AppGroupContainerResolver *resolver = [[AppGroupContainerResolver alloc] init];
    NSArray<AppGroupContainerInfo *> *infos = [resolver resolveGroupContainersForGroupIDs:groupIDs];
    NSMutableOrderedSet<NSString *> *uuids = [NSMutableOrderedSet orderedSet];
    for (AppGroupContainerInfo *info in infos) {
        if (![info.path isKindOfClass:[NSString class]] || !info.path.length) continue;
        BOOL isRootless = [info.path hasPrefix:@"/containers/Shared/AppGroup/"];
        if (rootless != isRootless) continue;
        NSString *uuid = [info.path lastPathComponent];
        if (uuid.length) {
            [uuids addObject:uuid];
        }
    }
    return uuids.array;
}

static BOOL PXReadOnlyRealDirectoryAtPath(NSString *path);
static BOOL PXReadOnlyRegularNonSymlinkFileAtPath(NSString *path);

static void PXKillAppProcessBestEffort(AppDataCleaner *selfRef, NSString *bundleID) {
    if (!bundleID.length || !selfRef) return;

    // 0) Best-effort kill by LaunchServices executable name (works for system apps too)
    @try {
        Class proxyCls = NSClassFromString(@"LSApplicationProxy");
        SEL sel = NSSelectorFromString(@"applicationProxyForIdentifier:");
        id proxy = (proxyCls && [proxyCls respondsToSelector:sel]) ? ((id (*)(id, SEL, id))objc_msgSend)(proxyCls, sel, bundleID) : nil;
        NSString *exe = nil;
        if (proxy && [proxy respondsToSelector:@selector(bundleExecutable)]) {
            exe = [proxy performSelector:@selector(bundleExecutable)];
        }
        if ([exe isKindOfClass:[NSString class]] && exe.length) {
            PXKillallTermThenKill(exe, 0.15);
        }
    } @catch (__unused NSException *e) {
    }

    // 1) Exact fallback: derive the bundle UUID from verified LaunchServices identity,
    // then accept only an .app whose Info.plist identifier exactly matches bundleID.
    NSString *bundleUUID = [selfRef findBundleContainerUUIDForBundleID:bundleID];
    if (bundleUUID.length) {
        NSArray<NSString *> *bundleBases = @[
            @"/var/containers/Bundle/Application",
            @"/var/mobile/Containers/Bundle/Application",
            @"/containers/Bundle/Application",
        ];
        BOOL killedExactBundle = NO;
        for (NSString *bundleBase in bundleBases) {
            NSString *bundleRoot = [bundleBase stringByAppendingPathComponent:bundleUUID];
            if (!PXReadOnlyRealDirectoryAtPath(bundleRoot)) continue;
            NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bundleRoot error:nil];
            for (NSString *item in items) {
                if (![[item pathExtension] isEqualToString:@"app"]) continue;
                NSString *appPath = [bundleRoot stringByAppendingPathComponent:item];
                if (!PXReadOnlyRealDirectoryAtPath(appPath)) continue;
                NSString *plistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
                if (!PXReadOnlyRegularNonSymlinkFileAtPath(plistPath)) continue;
                NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:plistPath];
                NSString *exactBundleID = [info[@"CFBundleIdentifier"] isKindOfClass:[NSString class]] ? info[@"CFBundleIdentifier"] : nil;
                if (![exactBundleID isEqualToString:bundleID]) continue;
                NSString *exeName = [info[@"CFBundleExecutable"] isKindOfClass:[NSString class]] ? info[@"CFBundleExecutable"] : nil;
                if (exeName.length) {
                    PXKillallTermThenKill(exeName, 0.15);
                    killedExactBundle = YES;
                }
                break;
            }
            if (killedExactBundle) break;
        }
    }
}

static void PXStopMailDaemonsBestEffort(AppDataCleaner *selfRef) {
    if (!selfRef) return;
    // Try to stop launchd jobs first to prevent immediate respawn.
    NSArray<NSString *> *labels = @[
        @"gui/501/com.apple.maild",
        @"gui/501/com.apple.mobilemail.maild",
        @"system/com.apple.maild",
        @"system/com.apple.mobilemail.maild"
    ];
    for (NSString *label in labels) {
        [selfRef runCommandWithPrivileges:[NSString stringWithFormat:@"launchctl kill SIGTERM %@ 2>/dev/null || true", label]];
        [selfRef runCommandWithPrivileges:[NSString stringWithFormat:@"launchctl stop %@ 2>/dev/null || true", label]];
    }

    // Fallback to process kills.
    PXKillallByName(@"maild", SIGTERM);
    PXKillallByName(@"Mail", SIGTERM);
}

static void PXStopSafariDaemonsBestEffort(AppDataCleaner *selfRef) {
    if (!selfRef) return;
    // Safari uses multiple helper processes that can keep databases open.
    NSArray<NSString *> *names = @[
        @"MobileSafari",
        @"SafariViewService",
        @"com.apple.WebKit.WebContent",
        @"com.apple.WebKit.Networking",
        @"com.apple.WebKit.GPU",
        @"nsurlsessiond",
        @"webbookmarksd"
    ];
    (void)selfRef;
    PXKillallTermThenKillMany(names, 0.2);
}

static NSString *PXFirstExistingPath(NSFileManager *fm, NSArray<NSString *> *paths) {
    if (!fm || ![paths isKindOfClass:[NSArray class]]) return nil;
    for (NSString *p in paths) {
        if ([p isKindOfClass:[NSString class]] && p.length && [fm fileExistsAtPath:p]) {
            return p;
        }
    }
    return nil;
}

static BOOL PXWaitForProcessExit(AppDataCleaner *selfRef, NSString *procName, NSTimeInterval timeout) {
    if (!selfRef || ![procName isKindOfClass:[NSString class]] || procName.length == 0 || timeout <= 0.0) {
        return NO;
    }
    CommandRunner *runner = [CommandRunner shared];
    NSString *pgrepPath = [runner firstExistingPath:@[@"/usr/bin/pgrep", @"/bin/pgrep"]];
    if (!pgrepPath.length) return NO;

    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    while (YES) {
        NSTimeInterval remaining = timeout - (CFAbsoluteTimeGetCurrent() - start);
        if (remaining <= 0.0) break;
        NSTimeInterval probeTimeout = MIN(1.0, remaining);

        CommandResult *probe = [runner runExecutableAndCapture:pgrepPath
                                                     arguments:@[@"-x", procName]
                                                    timeoutSec:probeTimeout
                                                maxOutputBytes:4096];
        if (probe &&
            probe.spawnError == 0 &&
            probe.runnerError == 0 &&
            !probe.timedOut &&
            probe.exitedNormally &&
            !probe.stdoutTruncated &&
            !probe.stderrTruncated) {
            if (probe.exitCode == 1 && probe.stdoutString.length == 0) {
                return YES;
            }
            if (probe.exitCode != 0 && probe.exitCode != 1) {
                return NO;
            }
        }
        [NSThread sleepForTimeInterval:0.1];
    }
    return NO;
}

- (BOOL)_deepCleanEnabled {
    NSUserDefaults *sec = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    if (!sec) {
        return NO;
    }
    // Default OFF
    if (![sec objectForKey:@"deepCleanEnabled"]) {
        return NO;
    }
    return [sec boolForKey:@"deepCleanEnabled"];
}

static NSString *PXShellQuote(NSString *s) {
    if (!s.length) return @"''";
    NSString *escaped = [s stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]; 
    return [NSString stringWithFormat:@"'%@'", escaped];
}

typedef NS_ENUM(NSInteger, PXApplicationDataClearFailureCode) {
    PXApplicationDataClearFailureCodeInvalidRequest = 1,
    PXApplicationDataClearFailureCodeResolutionFailed = 2,
    PXApplicationDataClearFailureCodeValidationFailed = 3,
    PXApplicationDataClearFailureCodeExecutionFailed = 4,
    PXApplicationDataClearFailureCodePostconditionFailed = 5,
    PXApplicationDataClearFailureCodeInternalResultFailure = 6,
};

static NSString * const PXApplicationDataClearFailureDomain = @"PXApplicationDataClear";
static NSString * const PXApplicationDataClearSkippedDetail = @"No exact application-data container exists in either supported root";

static void PXApplicationDataAssignError(NSError **error,
                                         PXApplicationDataClearFailureCode code,
                                         NSString *message) {
    if (!error) return;
    *error = [NSError errorWithDomain:PXApplicationDataClearFailureDomain
                                 code:code
                             userInfo:@{NSLocalizedDescriptionKey: message ?: @"Application-data clear failed"}];
}

static PXClearFailure *PXApplicationDataFailure(PXApplicationDataClearFailureCode code,
                                                NSString *message) {
    return [[PXClearFailure alloc] initWithDomain:PXApplicationDataClearFailureDomain
                                            code:code
                                         message:message ?: @"Application-data clear failed"];
}

static PXClearComponentResult *PXApplicationDataFailedComponent(PXApplicationDataClearFailureCode code,
                                                                NSString *message) {
    PXClearFailure *failure = PXApplicationDataFailure(code, message);
    return [[PXClearComponentResult alloc] initWithScope:PXClearScopeApplicationData
                                                  status:PXClearComponentStatusFailed
                                      attemptedUnitCount:1
                                      succeededUnitCount:0
                                         failedUnitCount:1
                                                  detail:@"Application-data clear could not produce a valid component result"
                                                 failure:failure];
}

static BOOL PXApplicationDataComponentResultIsStructurallyValid(id value) {
    if (![value isKindOfClass:[PXClearComponentResult class]]) return NO;
    PXClearComponentResult *result = (PXClearComponentResult *)value;
    if (result.scope != PXClearScopeApplicationData ||
        result.succeededUnitCount > result.attemptedUnitCount ||
        result.failedUnitCount != result.attemptedUnitCount - result.succeededUnitCount) {
        return NO;
    }

    switch (result.status) {
        case PXClearComponentStatusSucceeded:
            return result.attemptedUnitCount > 0 &&
                   result.succeededUnitCount == result.attemptedUnitCount &&
                   result.failedUnitCount == 0 &&
                   result.failure == nil;
        case PXClearComponentStatusSkipped:
            return result.attemptedUnitCount == 0 &&
                   result.succeededUnitCount == 0 &&
                   result.failedUnitCount == 0 &&
                   result.failure == nil &&
                   result.detail != nil;
        case PXClearComponentStatusFailed:
            return result.attemptedUnitCount > 0 &&
                   result.failedUnitCount > 0 &&
                   [result.failure isKindOfClass:[PXClearFailure class]];
    }
    return NO;
}

static NSError *PXApplicationDataLegacyErrorForFailure(PXClearFailure *failure) {
    if (![failure isKindOfClass:[PXClearFailure class]]) {
        return [NSError errorWithDomain:PXApplicationDataClearFailureDomain
                                   code:PXApplicationDataClearFailureCodeInternalResultFailure
                               userInfo:@{NSLocalizedDescriptionKey: @"Application-data clear returned an invalid failure result"}];
    }
    return [NSError errorWithDomain:failure.domain
                               code:failure.code
                           userInfo:@{NSLocalizedDescriptionKey: failure.message}];
}

static BOOL PXApplicationDataCommandResultSucceeded(CommandResult *result) {
    return result != nil &&
           result.isSucceeded &&
           !result.stdoutTruncated &&
           !result.stderrTruncated;
}

static NSString *PXShellValidatedApplicationDataWipe(NSString *canonicalPath) {
    if (![canonicalPath isKindOfClass:[NSString class]] || canonicalPath.length == 0) return @"";
    NSString *q = PXShellQuote(canonicalPath);
    return [NSString stringWithFormat:
            @"container=%@; status=0; "
             "for item in \"$container\"/* \"$container\"/.[!.]* \"$container\"/..?*; do "
             "if [ ! -e \"$item\" ] && [ ! -L \"$item\" ]; then continue; fi; "
             "name=${item##*/}; "
             "case \"$name\" in "
             "'.com.apple.mobile_container_manager.metadata.plist'|'.com.apple.containermanagerd.metadata.plist') continue ;; "
             "esac; "
             "chflags -R nouchg,noschg \"$item\" 2>/dev/null || true; "
             "rm -rf \"$item\" 2>/dev/null || status=1; "
             "done; "
             "for dir in Documents Library tmp; do "
             "mkdir -p \"$container/$dir\" 2>/dev/null || status=1; "
             "done; "
             "exit \"$status\"",
            q];
}

static BOOL PXApplicationDataPostconditionIsValid(NSString *canonicalPath, NSError **error) {
    if (![canonicalPath isKindOfClass:[NSString class]] || canonicalPath.length == 0) {
        PXApplicationDataAssignError(error,
                                     PXApplicationDataClearFailureCodePostconditionFailed,
                                     @"Application-data postcondition received an invalid canonical path");
        return NO;
    }

    const char *containerFS = canonicalPath.fileSystemRepresentation;
    struct stat containerStat;
    if (!containerFS || lstat(containerFS, &containerStat) != 0 || !S_ISDIR(containerStat.st_mode)) {
        PXApplicationDataAssignError(error,
                                     PXApplicationDataClearFailureCodePostconditionFailed,
                                     @"Application-data container is missing or is not a real directory");
        return NO;
    }

    NSError *contentsError = nil;
    NSArray<NSString *> *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:canonicalPath
                                                                                       error:&contentsError];
    if (![contents isKindOfClass:[NSArray class]] || contentsError) {
        PXApplicationDataAssignError(error,
                                     PXApplicationDataClearFailureCodePostconditionFailed,
                                     @"Application-data container inspection failed");
        return NO;
    }

    NSSet<NSString *> *allowed = [NSSet setWithArray:@[
        @".com.apple.mobile_container_manager.metadata.plist",
        @".com.apple.containermanagerd.metadata.plist",
        @"Documents",
        @"Library",
        @"tmp"
    ]];
    NSSet<NSString *> *metadataNames = [NSSet setWithArray:@[
        @".com.apple.mobile_container_manager.metadata.plist",
        @".com.apple.containermanagerd.metadata.plist"
    ]];

    for (NSString *entry in contents) {
        if (![entry isKindOfClass:[NSString class]] || ![allowed containsObject:entry]) {
            PXApplicationDataAssignError(error,
                                         PXApplicationDataClearFailureCodePostconditionFailed,
                                         @"Application-data container contains an unexpected top-level entry");
            return NO;
        }
        NSString *entryPath = [canonicalPath stringByAppendingPathComponent:entry];
        const char *entryFS = entryPath.fileSystemRepresentation;
        struct stat entryStat;
        if (!entryFS || lstat(entryFS, &entryStat) != 0 || S_ISLNK(entryStat.st_mode)) {
            PXApplicationDataAssignError(error,
                                         PXApplicationDataClearFailureCodePostconditionFailed,
                                         @"Application-data top-level entry inspection failed or found a symlink");
            return NO;
        }
        if ([metadataNames containsObject:entry] && !S_ISREG(entryStat.st_mode)) {
            PXApplicationDataAssignError(error,
                                         PXApplicationDataClearFailureCodePostconditionFailed,
                                         @"Application-data metadata entry is not a regular file");
            return NO;
        }
    }

    for (NSString *directoryName in @[@"Documents", @"Library", @"tmp"]) {
        NSString *directoryPath = [canonicalPath stringByAppendingPathComponent:directoryName];
        const char *directoryFS = directoryPath.fileSystemRepresentation;
        struct stat directoryStat;
        if (!directoryFS ||
            lstat(directoryFS, &directoryStat) != 0 ||
            !S_ISDIR(directoryStat.st_mode) ||
            S_ISLNK(directoryStat.st_mode)) {
            PXApplicationDataAssignError(error,
                                         PXApplicationDataClearFailureCodePostconditionFailed,
                                         @"Required application-data directory is missing or is not a real directory");
            return NO;
        }
        NSError *directoryError = nil;
        NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath
                                                                                         error:&directoryError];
        if (![directoryContents isKindOfClass:[NSArray class]] || directoryError) {
            PXApplicationDataAssignError(error,
                                         PXApplicationDataClearFailureCodePostconditionFailed,
                                         @"Required application-data directory inspection failed");
            return NO;
        }
        if (directoryContents.count != 0) {
            PXApplicationDataAssignError(error,
                                         PXApplicationDataClearFailureCodePostconditionFailed,
                                         @"Required application-data directory is not empty");
            return NO;
        }
    }

    return YES;
}

static NSString *PXApplicationDataStatusName(PXClearComponentStatus status) {
    switch (status) {
        case PXClearComponentStatusSucceeded: return @"Succeeded";
        case PXClearComponentStatusSkipped: return @"Skipped";
        case PXClearComponentStatusFailed: return @"Failed";
    }
    return @"Invalid";
}

static const PXClearScope PXMigratedDataClearScopes =
    PXClearScopeApplicationData |
    PXClearScopeExtensionData |
    PXClearScopeAppGroups |
    PXClearScopePluginKitData;

static const PXClearScope PXMigratedFullClearScopes =
    PXClearScopeApplicationData |
    PXClearScopeExtensionData |
    PXClearScopeAppGroups |
    PXClearScopePluginKitData |
    PXClearScopeKeychain;

typedef NS_ENUM(NSInteger, PXKeychainClearFailureCode) {
    PXKeychainClearFailureCodeInvalidRequest = 1,
    PXKeychainClearFailureCodeConfigurationFailed = 2,
    PXKeychainClearFailureCodeAuthorizationFailed = 3,
    PXKeychainClearFailureCodeInitialPassFailed = 4,
    PXKeychainClearFailureCodeFinalPassFailed = 5,
    PXKeychainClearFailureCodeInternalResultFailure = 6,
};

static NSString * const PXKeychainClearFailureDomain = @"PXKeychainClear";
static NSString * const PXKeychainDisabledDetail = @"Keychain wipe is disabled for this app";
static NSString * const PXKeychainNoSelectionDetail = @"No keychain access groups are selected";
static NSString * const PXKeychainNoAuthorizedGroupsDetail = @"No authorized keychain access groups were discovered";
static NSString * const PXKeychainSuccessDetail = @"All planned keychain wipe passes succeeded";
static NSString * const PXKeychainFailureDetail = @"One or more keychain wipe passes failed";

typedef NS_ENUM(NSInteger, PXExactDataClearFailureCode) {
    PXExactDataClearFailureCodeInvalidRequest = 1,
    PXExactDataClearFailureCodeDiscoveryFailed = 2,
    PXExactDataClearFailureCodeResolutionFailed = 3,
    PXExactDataClearFailureCodeValidationFailed = 4,
    PXExactDataClearFailureCodeExecutionFailed = 5,
    PXExactDataClearFailureCodePostconditionFailed = 6,
    PXExactDataClearFailureCodeInternalResultFailure = 7,
};

static BOOL PXKeychainExactStringIsValid(id value) {
    if (![value isKindOfClass:[NSString class]]) return NO;
    NSString *string = (NSString *)value;
    if (string.length == 0 || [string rangeOfString:@","].location != NSNotFound) return NO;
    unichar nulCharacter = 0;
    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
    if ([string rangeOfString:nulString].location != NSNotFound) return NO;
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    if ([string rangeOfCharacterFromSet:[whitespace invertedSet]].location == NSNotFound) return NO;
    NSString *trimmed = [string stringByTrimmingCharactersInSet:whitespace];
    return [trimmed isEqualToString:string];
}

static PXClearFailure *PXKeychainFailure(PXKeychainClearFailureCode code, NSString *message) {
    return [[PXClearFailure alloc] initWithDomain:PXKeychainClearFailureDomain
                                            code:code
                                         message:message ?: @"Keychain clear failed"];
}

static void PXAssignKeychainNSError(NSError **error,
                                    PXKeychainClearFailureCode code,
                                    NSString *message) {
    if (!error) return;
    *error = [NSError errorWithDomain:PXKeychainClearFailureDomain
                                 code:code
                             userInfo:@{NSLocalizedDescriptionKey: message ?: @"Keychain clear failed"}];
}

static BOOL PXBoundedCommandSucceeded(CommandResult *result) {
    return [result isKindOfClass:[CommandResult class]] &&
           result.isSucceeded &&
           !result.stdoutTruncated &&
           !result.stderrTruncated;
}
static NSString *PXKeychainDiagnosticTokenForMarker(CommandResult *result, NSString *marker) {
    if (![result isKindOfClass:[CommandResult class]] || !marker.length) return nil;
    NSString *stderrString = result.stderrString ?: @"";
    NSRange markerRange = [stderrString rangeOfString:marker];
    if (markerRange.location == NSNotFound) return nil;
    NSUInteger start = NSMaxRange(markerRange);
    if (start >= stderrString.length) return nil;
    NSRange searchRange = NSMakeRange(start, stderrString.length - start);
    NSRange newlineRange = [stderrString rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]
                                                         options:0
                                                           range:searchRange];
    NSUInteger end = newlineRange.location == NSNotFound ? stderrString.length : newlineRange.location;
    if (end <= start || end - start > 64) return nil;
    NSString *token = [stderrString substringWithRange:NSMakeRange(start, end - start)];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-"];
    if ([token rangeOfCharacterFromSet:[allowed invertedSet]].location != NSNotFound) return nil;
    return token;
}

static NSString *PXKeychainDependencyDiagnosticToken(CommandResult *result) {
    if (![result isKindOfClass:[CommandResult class]] ||
        result.exitCode != PXKeychainHelperExitCodeDependencyUnavailable) return nil;
    return PXKeychainDiagnosticTokenForMarker(result, @"PXKEYCHAIN_DEPENDENCY=");
}

static NSString *PXKeychainFailureStageDiagnosticToken(CommandResult *result) {
    return PXKeychainDiagnosticTokenForMarker(result, @"PXKEYCHAIN_FAILURE_STAGE=");
}

static NSString *PXKeychainFailureReasonDiagnosticToken(CommandResult *result) {
    return PXKeychainDiagnosticTokenForMarker(result, @"PXKEYCHAIN_FAILURE_REASON=");
}

typedef NS_ENUM(NSInteger, PXInstalledExtensionDiscoveryErrorCode) {
    PXInstalledExtensionDiscoveryErrorCodeInvalidRequest = 1,
    PXInstalledExtensionDiscoveryErrorCodeEnumerationFailed = 2,
    PXInstalledExtensionDiscoveryErrorCodeAmbiguousMatch = 3,
    PXInstalledExtensionDiscoveryErrorCodeInvalidCandidate = 4,
};

static NSString * const PXExtensionDataClearFailureDomain = @"PXExtensionDataClear";
static NSString * const PXPluginKitDataClearFailureDomain = @"PXPluginKitDataClear";
static NSString * const PXMigratedDataClearFailureDomain = @"PXMigratedDataClear";
static NSString * const PXInstalledExtensionDiscoveryErrorDomain = @"PXInstalledExtensionDiscovery";
static NSString * const PXNoInstalledExtensionsDetail = @"No installed application extensions were discovered";
static NSString * const PXNoExactExtensionDataContainersDetail = @"No exact extension-data containers were found";
static NSString * const PXNoExactPluginKitDataContainersDetail = @"No exact PluginKit data containers were found";
static NSString * const PXAppGroupsClearFailureDomain = @"PXAppGroupsClear";
static NSString * const PXAppGroupEntitlementDiscoveryErrorDomain = @"PXAppGroupEntitlementDiscovery";
static NSString * const PXNoDeclaredAppGroupsDetail = @"No application-group identifiers were declared by the app";
static NSString * const PXNoExactAppGroupContainersDetail = @"No exact App Group containers were found";

typedef NS_ENUM(NSInteger, PXAppGroupsClearFailureCode) {
    PXAppGroupsClearFailureCodeInvalidRequest = 1,
    PXAppGroupsClearFailureCodeEntitlementDiscoveryFailed = 2,
    PXAppGroupsClearFailureCodeResolutionFailed = 3,
    PXAppGroupsClearFailureCodeValidationFailed = 4,
    PXAppGroupsClearFailureCodeExecutionFailed = 5,
    PXAppGroupsClearFailureCodePostconditionFailed = 6,
    PXAppGroupsClearFailureCodeInternalResultFailure = 7,
};

typedef NS_ENUM(NSInteger, PXAppGroupEntitlementDiscoveryErrorCode) {
    PXAppGroupEntitlementDiscoveryErrorCodeInvalidRequest = 1,
    PXAppGroupEntitlementDiscoveryErrorCodeExtractionFailed = 2,
    PXAppGroupEntitlementDiscoveryErrorCodeInvalidStructure = 3,
};

static BOOL PXAppGroupIdentifierStringContainsNUL(NSString *value) {
    unichar nulCharacter = 0;
    NSString *nulString =
        [NSString stringWithCharacters:&nulCharacter length:1];
    return [value rangeOfString:nulString].location != NSNotFound;
}

static BOOL PXAppGroupIdentifierStringContainsNonWhitespace(NSString *value) {
    NSCharacterSet *whitespace =
        [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [value rangeOfCharacterFromSet:[whitespace invertedSet]].location
        != NSNotFound;
}

static BOOL PXAppGroupIdentifierIsValid(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }
    NSString *identifier = (NSString *)value;
    return identifier.length > 0 &&
           PXAppGroupIdentifierStringContainsNonWhitespace(identifier) &&
           !PXAppGroupIdentifierStringContainsNUL(identifier);
}

static void PXAppGroupEntitlementDiscoveryAssignError(NSError **error,
                                                       PXAppGroupEntitlementDiscoveryErrorCode code,
                                                       NSString *message) {
    if (!error) return;
    *error = [NSError errorWithDomain:PXAppGroupEntitlementDiscoveryErrorDomain
                                 code:code
                             userInfo:@{NSLocalizedDescriptionKey:
                                            message ?: @"Application-group entitlement discovery failed"}];
}

static PXClearFailure *PXAppGroupsFailure(PXAppGroupsClearFailureCode code,
                                          NSString *message) {
    return [[PXClearFailure alloc] initWithDomain:PXAppGroupsClearFailureDomain
                                            code:code
                                         message:message ?: @"App Groups clear failed"];
}

static PXClearComponentResult *PXAppGroupsFailedComponent(PXAppGroupsClearFailureCode code,
                                                          NSString *message) {
    PXClearFailure *failure = PXAppGroupsFailure(code, message);
    return [[PXClearComponentResult alloc] initWithScope:PXClearScopeAppGroups
                                                  status:PXClearComponentStatusFailed
                                      attemptedUnitCount:1
                                      succeededUnitCount:0
                                         failedUnitCount:1
                                                  detail:@"App Groups clear could not produce a valid component result"
                                                 failure:failure];
}

static BOOL PXAppGroupsComponentResultIsStructurallyValid(id value) {
    if (![value isKindOfClass:[PXClearComponentResult class]]) return NO;
    PXClearComponentResult *result = (PXClearComponentResult *)value;
    if (result.scope != PXClearScopeAppGroups ||
        result.succeededUnitCount > result.attemptedUnitCount ||
        result.failedUnitCount != result.attemptedUnitCount - result.succeededUnitCount) {
        return NO;
    }

    switch (result.status) {
        case PXClearComponentStatusSucceeded:
            return result.attemptedUnitCount > 0 &&
                   result.succeededUnitCount == result.attemptedUnitCount &&
                   result.failedUnitCount == 0 &&
                   result.failure == nil;
        case PXClearComponentStatusSkipped:
            return result.attemptedUnitCount == 0 &&
                   result.succeededUnitCount == 0 &&
                   result.failedUnitCount == 0 &&
                   result.failure == nil &&
                   result.detail != nil;
        case PXClearComponentStatusFailed:
            return result.attemptedUnitCount > 0 &&
                   result.failedUnitCount > 0 &&
                   [result.failure isKindOfClass:[PXClearFailure class]] &&
                   [result.failure.domain isEqualToString:PXAppGroupsClearFailureDomain];
    }
    return NO;
}

static BOOL PXStrictBundleIdentifierCharacterIsAllowed(unichar character) {
    return (character >= (unichar)'A' && character <= (unichar)'Z') ||
           (character >= (unichar)'a' && character <= (unichar)'z') ||
           (character >= (unichar)'0' && character <= (unichar)'9') ||
           character == (unichar)'-' ||
           character == (unichar)'.';
}

static BOOL PXStrictBundleIdentifierIsValid(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }
    NSString *identifier = (NSString *)value;
    if (identifier.length == 0 ||
        [identifier characterAtIndex:0] == (unichar)'.' ||
        [identifier characterAtIndex:(identifier.length - 1)] == (unichar)'.') {
        return NO;
    }

    NSUInteger componentLength = 0;
    for (NSUInteger index = 0; index < identifier.length; index++) {
        unichar character = [identifier characterAtIndex:index];
        if (!PXStrictBundleIdentifierCharacterIsAllowed(character)) {
            return NO;
        }
        if (character == (unichar)'.') {
            if (componentLength == 0) {
                return NO;
            }
            componentLength = 0;
        } else {
            componentLength++;
        }
    }
    return componentLength > 0;
}

static BOOL PXReadOnlyRealDirectoryAtPath(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || path.length == 0) {
        return NO;
    }
    const char *fileSystemPath = path.fileSystemRepresentation;
    struct stat pathStat;
    return fileSystemPath != NULL &&
           lstat(fileSystemPath, &pathStat) == 0 &&
           S_ISDIR(pathStat.st_mode) &&
           !S_ISLNK(pathStat.st_mode);
}

static BOOL PXReadOnlyRegularNonSymlinkFileAtPath(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || path.length == 0) {
        return NO;
    }
    const char *fileSystemPath = path.fileSystemRepresentation;
    struct stat pathStat;
    return fileSystemPath != NULL &&
           lstat(fileSystemPath, &pathStat) == 0 &&
           S_ISREG(pathStat.st_mode) &&
           !S_ISLNK(pathStat.st_mode);
}


// Exact-file primitive only. Authorization belongs to the caller; this helper refuses
// directories and symlinks and never expands globs, follows links, or mutates parents.
static BOOL PXRemoveExactRegularNonSymlinkFile(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || path.length == 0) return NO;
    const char *fileSystemPath = path.fileSystemRepresentation;
    if (!fileSystemPath) return NO;

    struct stat pathStat;
    if (lstat(fileSystemPath, &pathStat) != 0) {
        return errno == ENOENT;
    }
    if (!S_ISREG(pathStat.st_mode) || S_ISLNK(pathStat.st_mode)) {
        return NO;
    }
    if (unlink(fileSystemPath) == 0) return YES;
    return errno == ENOENT;
}

static NSString *PXExactInstalledApplicationBundlePathFromLaunchServices(NSString *bundleIdentifier) {
    if (!PXStrictBundleIdentifierIsValid(bundleIdentifier)) {
        return nil;
    }

    @try {
        Class proxyClass = NSClassFromString(@"LSApplicationProxy");
        SEL proxySelector = NSSelectorFromString(@"applicationProxyForIdentifier:");
        if (!proxyClass || ![proxyClass respondsToSelector:proxySelector]) {
            return nil;
        }

        id proxy = ((id (*)(id, SEL, id))objc_msgSend)(proxyClass,
                                                       proxySelector,
                                                       bundleIdentifier);
        SEL bundleURLSelector = NSSelectorFromString(@"bundleURL");
        if (!proxy || ![proxy respondsToSelector:bundleURLSelector]) {
            return nil;
        }

        id bundleURLObject = ((id (*)(id, SEL))objc_msgSend)(proxy,
                                                             bundleURLSelector);
        if (![bundleURLObject isKindOfClass:[NSURL class]]) {
            return nil;
        }

        NSString *bundlePath = [(NSURL *)bundleURLObject path];
        if (!PXReadOnlyRealDirectoryAtPath(bundlePath)) {
            return nil;
        }

        NSString *infoPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
        if (!PXReadOnlyRegularNonSymlinkFileAtPath(infoPath)) {
            return nil;
        }
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
        id exactIdentifier = [info isKindOfClass:[NSDictionary class]]
            ? info[@"CFBundleIdentifier"]
            : nil;
        if (![exactIdentifier isKindOfClass:[NSString class]] ||
            ![(NSString *)exactIdentifier isEqualToString:bundleIdentifier]) {
            return nil;
        }
        return [bundlePath copy];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSString *PXExactInstalledApplicationBundlePathWithFilesystemFallback(NSString *bundleIdentifier) {
    NSString *launchServicesPath = PXExactInstalledApplicationBundlePathFromLaunchServices(bundleIdentifier);
    if (launchServicesPath.length) return launchServicesPath;
    if (!PXStrictBundleIdentifierIsValid(bundleIdentifier)) return nil;

    NSArray<NSString *> *bundleRoots = @[
        @"/var/containers/Bundle/Application",
        @"/var/mobile/Containers/Bundle/Application",
        @"/containers/Bundle/Application",
    ];
    NSMutableOrderedSet<NSString *> *matches = [NSMutableOrderedSet orderedSet];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    for (NSString *bundleRoot in bundleRoots) {
        if (!PXReadOnlyRealDirectoryAtPath(bundleRoot)) continue;
        NSError *rootError = nil;
        NSArray<NSString *> *uuidEntries = [fileManager contentsOfDirectoryAtPath:bundleRoot error:&rootError];
        if (![uuidEntries isKindOfClass:[NSArray class]] || rootError) continue;
        NSString *standardRoot = [bundleRoot stringByStandardizingPath];

        for (NSString *uuidEntry in uuidEntries) {
            if (![uuidEntry isKindOfClass:[NSString class]] || uuidEntry.length == 0 || [uuidEntry containsString:@"/"]) continue;
            NSString *uuidPath = [[bundleRoot stringByAppendingPathComponent:uuidEntry] stringByStandardizingPath];
            if (![[uuidPath stringByDeletingLastPathComponent] isEqualToString:standardRoot] ||
                !PXReadOnlyRealDirectoryAtPath(uuidPath)) continue;

            NSError *uuidError = nil;
            NSArray<NSString *> *appEntries = [fileManager contentsOfDirectoryAtPath:uuidPath error:&uuidError];
            if (![appEntries isKindOfClass:[NSArray class]] || uuidError) continue;
            for (NSString *appEntry in appEntries) {
                if (![appEntry isKindOfClass:[NSString class]] || ![[appEntry pathExtension] isEqualToString:@"app"] || [appEntry containsString:@"/"]) continue;
                NSString *appPath = [[uuidPath stringByAppendingPathComponent:appEntry] stringByStandardizingPath];
                if (![[appPath stringByDeletingLastPathComponent] isEqualToString:uuidPath] ||
                    !PXReadOnlyRealDirectoryAtPath(appPath)) continue;
                NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
                if (!PXReadOnlyRegularNonSymlinkFileAtPath(infoPath)) continue;
                NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
                NSString *exactIdentifier = [info[@"CFBundleIdentifier"] isKindOfClass:[NSString class]]
                    ? info[@"CFBundleIdentifier"]
                    : nil;
                if ([exactIdentifier isEqualToString:bundleIdentifier]) {
                    [matches addObject:appPath];
                }
            }
        }
    }

    return matches.count == 1 ? matches.firstObject : nil;
}

static NSArray<NSString *> *PXExactReadOnlyApplicationDataPathsForBundleID(NSString *bundleIdentifier) {
    if (!PXStrictBundleIdentifierIsValid(bundleIdentifier)) return @[];

    PXDataContainerResolver *resolver = [[PXDataContainerResolver alloc] init];
    NSMutableOrderedSet<NSString *> *paths = [NSMutableOrderedSet orderedSet];
    const PXResolvedContainerRoot roots[] = {
        PXResolvedContainerRootRootful,
        PXResolvedContainerRootRootless,
    };
    for (NSUInteger index = 0; index < sizeof(roots) / sizeof(roots[0]); index++) {
        NSError *error = nil;
        PXResolvedContainer *container =
            [resolver resolveApplicationDataContainerForIdentifier:bundleIdentifier
                                                              root:roots[index]
                                                             error:&error];
        if (!container || error || !PXReadOnlyRealDirectoryAtPath(container.containerPath)) continue;
        [paths addObject:[container.containerPath stringByStandardizingPath]];
    }
    return paths.array;
}

static NSString *PXExactInstalledApplicationExecutablePathFromLaunchServices(
    NSString *bundleIdentifier,
    NSString **bundlePathOut) {
    if (bundlePathOut) *bundlePathOut = nil;
    NSString *bundlePath = PXExactInstalledApplicationBundlePathFromLaunchServices(bundleIdentifier);
    if (!bundlePath.length) return nil;

    NSString *infoPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
    if (!PXReadOnlyRegularNonSymlinkFileAtPath(infoPath)) return nil;
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    id executableObject = [info isKindOfClass:[NSDictionary class]]
        ? info[@"CFBundleExecutable"]
        : nil;
    if (![executableObject isKindOfClass:[NSString class]]) return nil;
    NSString *executableName = (NSString *)executableObject;
    if (executableName.length == 0 ||
        [executableName containsString:@"/"] ||
        [executableName isEqualToString:@"."] ||
        [executableName isEqualToString:@".."]) return nil;

    NSString *executablePath = [bundlePath stringByAppendingPathComponent:executableName];
    if (!PXReadOnlyRegularNonSymlinkFileAtPath(executablePath)) return nil;
    if (bundlePathOut) *bundlePathOut = [bundlePath copy];
    return [executablePath copy];
}

static void PXInstalledExtensionDiscoveryAssignError(NSError **error,
                                                      PXInstalledExtensionDiscoveryErrorCode code,
                                                      NSString *message) {
    if (!error) return;
    *error = [NSError errorWithDomain:PXInstalledExtensionDiscoveryErrorDomain
                                 code:code
                             userInfo:@{NSLocalizedDescriptionKey: message ?: @"Installed extension discovery failed"}];
}

static NSString *PXExactDataFailureDomainForScope(PXClearScope scope) {
    if (scope == PXClearScopeExtensionData) {
        return PXExtensionDataClearFailureDomain;
    }
    if (scope == PXClearScopePluginKitData) {
        return PXPluginKitDataClearFailureDomain;
    }
    return PXMigratedDataClearFailureDomain;
}

static NSString *PXExactDataComponentName(PXClearScope scope) {
    return scope == PXClearScopePluginKitData ? @"PluginKitData" : @"ExtensionData";
}

static NSString *PXMigratedComponentName(PXClearScope scope) {
    switch (scope) {
        case PXClearScopeApplicationData: return @"ApplicationData";
        case PXClearScopeExtensionData: return @"ExtensionData";
        case PXClearScopeAppGroups: return @"AppGroups";
        case PXClearScopePluginKitData: return @"PluginKitData";
        case PXClearScopeKeychain: return @"Keychain";
        default: return @"Unknown";
    }
}

static PXClearFailure *PXExactDataFailure(PXClearScope scope,
                                          PXExactDataClearFailureCode code,
                                          NSString *message) {
    return [[PXClearFailure alloc] initWithDomain:PXExactDataFailureDomainForScope(scope)
                                            code:code
                                         message:message ?: @"Exact extension data clear failed"];
}

static PXClearComponentResult *PXExactDataFailedComponent(PXClearScope scope,
                                                          PXExactDataClearFailureCode code,
                                                          NSString *message) {
    PXClearFailure *failure = PXExactDataFailure(scope, code, message);
    NSString *detail = scope == PXClearScopePluginKitData
        ? @"PluginKitData clear could not produce a valid component result"
        : @"ExtensionData clear could not produce a valid component result";
    return [[PXClearComponentResult alloc] initWithScope:scope
                                                  status:PXClearComponentStatusFailed
                                      attemptedUnitCount:1
                                      succeededUnitCount:0
                                         failedUnitCount:1
                                                  detail:detail
                                                 failure:failure];
}

static BOOL PXExactDataComponentResultIsStructurallyValid(id value,
                                                          PXClearScope expectedScope) {
    if (![value isKindOfClass:[PXClearComponentResult class]]) return NO;
    PXClearComponentResult *result = (PXClearComponentResult *)value;
    if (result.scope != expectedScope ||
        (expectedScope != PXClearScopeExtensionData && expectedScope != PXClearScopePluginKitData) ||
        result.succeededUnitCount > result.attemptedUnitCount ||
        result.failedUnitCount != result.attemptedUnitCount - result.succeededUnitCount) {
        return NO;
    }

    switch (result.status) {
        case PXClearComponentStatusSucceeded:
            return result.attemptedUnitCount > 0 &&
                   result.succeededUnitCount == result.attemptedUnitCount &&
                   result.failedUnitCount == 0 &&
                   result.failure == nil;
        case PXClearComponentStatusSkipped:
            return result.attemptedUnitCount == 0 &&
                   result.succeededUnitCount == 0 &&
                   result.failedUnitCount == 0 &&
                   result.failure == nil &&
                   result.detail != nil;
        case PXClearComponentStatusFailed:
            return result.attemptedUnitCount > 0 &&
                   result.failedUnitCount > 0 &&
                   [result.failure isKindOfClass:[PXClearFailure class]] &&
                   [result.failure.domain isEqualToString:PXExactDataFailureDomainForScope(expectedScope)];
    }
    return NO;
}

static BOOL PXMigratedDataClearResultIsStructurallyValid(id value) {
    if (![value isKindOfClass:[PXClearResult class]]) return NO;
    PXClearResult *result = (PXClearResult *)value;
    if (![result.request isKindOfClass:[PXClearRequest class]] ||
        result.request.scopes != PXMigratedDataClearScopes ||
        result.componentResults.count != 4) {
        return NO;
    }

    PXClearComponentResult *applicationData = result.componentResults[0];
    PXClearComponentResult *extensionData = result.componentResults[1];
    PXClearComponentResult *appGroups = result.componentResults[2];
    PXClearComponentResult *pluginKitData = result.componentResults[3];
    return applicationData.scope == PXClearScopeApplicationData &&
           extensionData.scope == PXClearScopeExtensionData &&
           appGroups.scope == PXClearScopeAppGroups &&
           pluginKitData.scope == PXClearScopePluginKitData &&
           PXApplicationDataComponentResultIsStructurallyValid(applicationData) &&
           PXExactDataComponentResultIsStructurallyValid(extensionData, PXClearScopeExtensionData) &&
           PXAppGroupsComponentResultIsStructurallyValid(appGroups) &&
           PXExactDataComponentResultIsStructurallyValid(pluginKitData, PXClearScopePluginKitData);
}

static BOOL PXKeychainComponentResultIsStructurallyValid(id value) {
    if (![value isKindOfClass:[PXClearComponentResult class]]) return NO;
    PXClearComponentResult *result = (PXClearComponentResult *)value;
    if (result.scope != PXClearScopeKeychain ||
        result.succeededUnitCount > result.attemptedUnitCount ||
        result.failedUnitCount != result.attemptedUnitCount - result.succeededUnitCount) {
        return NO;
    }
    switch (result.status) {
        case PXClearComponentStatusSucceeded:
            return (result.attemptedUnitCount == 1 || result.attemptedUnitCount == 2) &&
                   result.succeededUnitCount == result.attemptedUnitCount &&
                   result.failedUnitCount == 0 &&
                   result.failure == nil &&
                   [result.detail isEqualToString:PXKeychainSuccessDetail];
        case PXClearComponentStatusSkipped:
            return result.attemptedUnitCount == 0 &&
                   result.succeededUnitCount == 0 &&
                   result.failedUnitCount == 0 &&
                   result.failure == nil &&
                   ([result.detail isEqualToString:PXKeychainDisabledDetail] ||
                    [result.detail isEqualToString:PXKeychainNoSelectionDetail] ||
                    [result.detail isEqualToString:PXKeychainNoAuthorizedGroupsDetail]);
        case PXClearComponentStatusFailed:
            return (result.attemptedUnitCount == 1 || result.attemptedUnitCount == 2) &&
                   result.failedUnitCount > 0 &&
                   [result.failure isKindOfClass:[PXClearFailure class]] &&
                   [result.failure.domain isEqualToString:PXKeychainClearFailureDomain] &&
                   [result.detail isEqualToString:PXKeychainFailureDetail];
    }
    return NO;
}

static BOOL PXMigratedFullClearResultIsStructurallyValid(id value) {
    if (![value isKindOfClass:[PXClearResult class]]) return NO;
    PXClearResult *result = (PXClearResult *)value;
    if (![result.request isKindOfClass:[PXClearRequest class]] ||
        result.request.scopes != PXMigratedFullClearScopes ||
        result.componentResults.count != 5) {
        return NO;
    }
    PXClearComponentResult *applicationData = result.componentResults[0];
    PXClearComponentResult *extensionData = result.componentResults[1];
    PXClearComponentResult *appGroups = result.componentResults[2];
    PXClearComponentResult *pluginKitData = result.componentResults[3];
    PXClearComponentResult *keychain = result.componentResults[4];
    return applicationData.scope == PXClearScopeApplicationData &&
           extensionData.scope == PXClearScopeExtensionData &&
           appGroups.scope == PXClearScopeAppGroups &&
           pluginKitData.scope == PXClearScopePluginKitData &&
           keychain.scope == PXClearScopeKeychain &&
           PXApplicationDataComponentResultIsStructurallyValid(applicationData) &&
           PXExactDataComponentResultIsStructurallyValid(extensionData, PXClearScopeExtensionData) &&
           PXAppGroupsComponentResultIsStructurallyValid(appGroups) &&
           PXExactDataComponentResultIsStructurallyValid(pluginKitData, PXClearScopePluginKitData) &&
           PXKeychainComponentResultIsStructurallyValid(keychain);
}

static NSError *PXMigratedInternalError(NSString *message) {
    return [NSError errorWithDomain:PXMigratedDataClearFailureDomain
                               code:PXExactDataClearFailureCodeInternalResultFailure
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Migrated data clear returned an invalid internal result"}];
}

static NSError *PXMigratedNSErrorForFailure(PXClearFailure *failure) {
    if (![failure isKindOfClass:[PXClearFailure class]]) {
        return PXMigratedInternalError(@"Migrated data clear returned an invalid component failure");
    }
    return [NSError errorWithDomain:failure.domain
                               code:failure.code
                           userInfo:@{NSLocalizedDescriptionKey: failure.message}];
}

/// Shell fragment: wipe container children except MCM metadata, then recreate minimal layout.
static NSString *PXShellWipeContainerKeepMetadata(NSString *containerPath) {
    if (!containerPath.length) return @"";
    NSString *q = PXShellQuote(containerPath);
    return [NSString stringWithFormat:
            @"find %@ -mindepth 1 -maxdepth 1 "
            @"-not -name '.com.apple.mobile_container_manager.metadata.plist' "
            @"-not -name '.com.apple.containermanagerd.metadata.plist' "
            @"-exec rm -rf {} + 2>/dev/null || true; "
            @"mkdir -p %@/Documents %@/Library/Caches %@/Library/Preferences %@/tmp 2>/dev/null || true",
            q, q, q, q, q];
}

/// Shell fragment: fast data-container wipe (top-level dirs + hidden non-Apple + recreate).
static NSString *PXShellFastDataContainerWipe(NSString *containerPath) {
    if (!containerPath.length) return @"";
    NSString *q = PXShellQuote(containerPath);
    return [NSString stringWithFormat:
            @"rm -rf %@/Documents %@/Library %@/tmp %@/StoreKit %@/SystemData 2>/dev/null || true; "
            @"mkdir -p %@/Documents %@/Library/Caches %@/Library/Preferences %@/tmp 2>/dev/null || true; "
            @"find %@ -mindepth 1 -maxdepth 1 -name '.*' ! -name '.com.apple*' -exec rm -rf {} \\; 2>/dev/null || true",
            q, q, q, q, q,
            q, q, q, q,
            q];
}


static NSString *PXTimestampSuffix(void) {
    return [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
}

static NSString *PXKeychainWipeEnabledKey(NSString *bundleID) {
    return [NSString stringWithFormat:@"dataCleanerKeychainWipeEnabled_%@", bundleID ?: @""];
}

static NSString *PXKeychainWipeGroupsKey(NSString *bundleID) {
    return [NSString stringWithFormat:@"dataCleanerKeychainWipeGroups_%@", bundleID ?: @""];
}

+ (instancetype)sharedManager {
    static AppDataCleaner *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _fileManager = [NSFileManager defaultManager];
        // Clear old log file on init
        NSString *logPath = @"/var/mobile/Documents/AppDataCleaner.log";
        [@"=== AppDataCleaner Log Started ===\n" writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    return self;
}

// Helper to log to both console and file
- (void)logMessage:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    // Log to console
    NSLog(@"%@", message);
    
    // Also append to file for easy reading on device
    NSString *logPath = @"/var/mobile/Documents/AppDataCleaner.log";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    NSString *logLine = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (fileHandle) {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[logLine dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    } else {
        // File doesn't exist, create it
        [logLine writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

#pragma mark - Keychain Wipe Settings

- (PXKeychainHelperResult *)_readOnlyKeychainListResultForBundleIdentifier:(NSString *)bundleIdentifier
                                                              accessGroups:(NSArray<NSString *> *)accessGroups {
    if (!PXStrictBundleIdentifierIsValid(bundleIdentifier)) return nil;

    NSArray<NSString *> *requestedGroups = nil;
    if (accessGroups != nil) {
        if (![accessGroups isKindOfClass:[NSArray class]] || accessGroups.count == 0 || accessGroups.count > 128) {
            return nil;
        }
        NSMutableSet<NSString *> *uniqueGroups = [NSMutableSet set];
        for (id group in accessGroups) {
            if (!PXKeychainExactStringIsValid(group)) return nil;
            [uniqueGroups addObject:(NSString *)group];
        }
        requestedGroups = [[uniqueGroups allObjects] sortedArrayUsingSelector:@selector(compare:)];
        if (requestedGroups.count != accessGroups.count) return nil;
    }

    CommandRunner *runner = [CommandRunner shared];
    NSString *scriptPath = [runner firstExistingPath:@[
        @"/Library/WeaponX/keychain_backup.sh",
        @"/var/jb/Library/WeaponX/keychain_backup.sh",
        @"/private/var/jb/Library/WeaponX/keychain_backup.sh"
    ]];
    if (!scriptPath.length || ![scriptPath hasPrefix:@"/"]) return nil;

    NSMutableArray<NSString *> *arguments = [NSMutableArray arrayWithObjects:@"list", bundleIdentifier, nil];
    if (requestedGroups.count > 0) {
        [arguments addObjectsFromArray:@[
            @"--groups",
            [requestedGroups componentsJoinedByString:@","]
        ]];
    }

    PXClearOperationContext *operationContext = PXCurrentClearOperationContext();
    NSTimeInterval timeout = operationContext
        ? [operationContext clampedTimeoutForStepLimit:60.0]
        : 60.0;
    if (operationContext && timeout <= 0.0) return nil;

    CommandResult *commandResult = [runner runExecutableAndCapture:scriptPath
                                                          arguments:arguments
                                                         timeoutSec:timeout
                                                     maxOutputBytes:1024 * 1024];
    if (!PXBoundedCommandSucceeded(commandResult)) return nil;

    NSString *machineLine = nil;
    for (NSString *line in [commandResult.stdoutString ?: @"" componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        if (![line hasPrefix:PXKeychainHelperResultOutputPrefix]) continue;
        if (machineLine != nil) return nil;
        machineLine = line;
    }
    if (!machineLine.length) return nil;

    NSError *parseError = nil;
    PXKeychainHelperResult *result =
        [PXKeychainHelperResult resultFromMachineReadableLine:machineLine error:&parseError];
    if (!result || parseError ||
        result.operation != PXKeychainHelperOperationList ||
        result.completion != PXKeychainHelperCompletionCompleted ||
        result.fatalErrorPresent ||
        result.failedCount != 0 ||
        result.errorCount != 0 ||
        result.attemptedCount != result.succeededCount) {
        return nil;
    }

    if (requestedGroups != nil) {
        if (![result.requestedAccessGroups isEqualToArray:requestedGroups]) return nil;
        NSSet<NSString *> *effectiveMembership = [NSSet setWithArray:result.effectiveAccessGroups];
        for (NSString *group in requestedGroups) {
            if (![effectiveMembership containsObject:group]) return nil;
        }
    }
    return result;
}

- (BOOL)_hasExactKeychainItemsForBundleIdentifier:(NSString *)bundleIdentifier
                                     accessGroups:(NSArray<NSString *> *)accessGroups
                                            known:(BOOL *)known {
    if (known) *known = NO;
    if (accessGroups != nil && accessGroups.count == 0) {
        if (known) *known = YES;
        return NO;
    }

    PXKeychainHelperResult *result =
        [self _readOnlyKeychainListResultForBundleIdentifier:bundleIdentifier accessGroups:accessGroups];
    if (!result) return NO;
    if (known) *known = YES;
    return result.attemptedCount > 0;
}

- (PXKeychainClearPlan *)_keychainClearPlanForBundleIdentifier:(NSString *)bundleIdentifier {
    BOOL systemApplication = [bundleIdentifier hasPrefix:@"com.apple."];
    if (!PXStrictBundleIdentifierIsValid(bundleIdentifier)) {
        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
                                                            enabled:NO
                                                  systemApplication:systemApplication
                                                systemPolicyAllowed:NO
                                                     selectedGroups:@[]
                                                   authorizedGroups:@[]
                                              applicationIdentifier:nil
                                                   plannedPassCount:0
                                                         skipDetail:nil
                                                planningFailureCode:PXKeychainClearFailureCodeInvalidRequest
                                             planningFailureMessage:@"Invalid Keychain clear request"];
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id enabledObject = [defaults objectForKey:PXKeychainWipeEnabledKey(bundleIdentifier)];
    id selectedObject = [defaults objectForKey:PXKeychainWipeGroupsKey(bundleIdentifier)];
    BOOL enabled = [enabledObject respondsToSelector:@selector(boolValue)] && [enabledObject boolValue];
    if (!enabled) {
        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
                                                            enabled:NO
                                                  systemApplication:systemApplication
                                                systemPolicyAllowed:YES
                                                     selectedGroups:@[]
                                                   authorizedGroups:@[]
                                              applicationIdentifier:nil
                                                   plannedPassCount:0
                                                         skipDetail:PXKeychainDisabledDetail
                                                planningFailureCode:0
                                             planningFailureMessage:nil];
    }

    BOOL systemPolicyAllowed = YES;
    if (systemApplication) {
        NSUserDefaults *securityDefaults =
            [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
        id policyObject = [securityDefaults objectForKey:@"allowSystemKeychainWipeEnabled"];
        systemPolicyAllowed = [policyObject respondsToSelector:@selector(boolValue)] &&
                              [policyObject boolValue];
    }

    AppEntitlementsReader *reader = [[AppEntitlementsReader alloc] init];
    NSError *entitlementsError = nil;
    id entitlementsObject = [reader fullEntitlementsForBundleID:bundleIdentifier
                                                          error:&entitlementsError];
    if (entitlementsError || ![entitlementsObject isKindOfClass:[NSDictionary class]]) {
        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
                                                            enabled:YES
                                                  systemApplication:systemApplication
                                                systemPolicyAllowed:systemPolicyAllowed
                                                     selectedGroups:@[]
                                                   authorizedGroups:@[]
                                              applicationIdentifier:nil
                                                   plannedPassCount:0
                                                         skipDetail:nil
                                                planningFailureCode:PXKeychainClearFailureCodeConfigurationFailed
                                             planningFailureMessage:@"Signed Keychain authorization could not be read"];
    }

    NSDictionary *entitlements = (NSDictionary *)entitlementsObject;
    NSMutableSet<NSString *> *authorizedSet = [NSMutableSet set];
    id signedGroupsObject = entitlements[@"keychain-access-groups"];
    if (signedGroupsObject && ![signedGroupsObject isKindOfClass:[NSArray class]]) {
        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
                                                            enabled:YES
                                                  systemApplication:systemApplication
                                                systemPolicyAllowed:systemPolicyAllowed
                                                     selectedGroups:@[]
                                                   authorizedGroups:@[]
                                              applicationIdentifier:nil
                                                   plannedPassCount:0
                                                         skipDetail:nil
                                                planningFailureCode:PXKeychainClearFailureCodeAuthorizationFailed
                                             planningFailureMessage:@"Signed Keychain authorization is malformed"];
    }
    for (id groupObject in (NSArray *)(signedGroupsObject ?: @[])) {
        if (!PXKeychainExactStringIsValid(groupObject)) {
            return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
                                                                enabled:YES
                                                      systemApplication:systemApplication
                                                    systemPolicyAllowed:systemPolicyAllowed
                                                         selectedGroups:@[]
                                                       authorizedGroups:@[]
                                                  applicationIdentifier:nil
                                                       plannedPassCount:0
                                                             skipDetail:nil
                                                    planningFailureCode:PXKeychainClearFailureCodeAuthorizationFailed
                                                 planningFailureMessage:@"Signed Keychain authorization is malformed"];
        }
        [authorizedSet addObject:(NSString *)groupObject];
    }

    NSString *applicationIdentifier = nil;
    id applicationIdentifierObject = entitlements[@"application-identifier"];
    if (applicationIdentifierObject) {
        if (!PXKeychainExactStringIsValid(applicationIdentifierObject)) {
            return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
                                                                enabled:YES
                                                      systemApplication:systemApplication
                                                    systemPolicyAllowed:systemPolicyAllowed
                                                         selectedGroups:@[]
                                                       authorizedGroups:@[]
                                                  applicationIdentifier:nil
                                                       plannedPassCount:0
                                                             skipDetail:nil
                                                    planningFailureCode:PXKeychainClearFailureCodeAuthorizationFailed
                                                 planningFailureMessage:@"Signed Keychain authorization is malformed"];
        }
        applicationIdentifier = (NSString *)applicationIdentifierObject;
        [authorizedSet addObject:applicationIdentifier];
    }

    NSArray<NSString *> *authorizedGroups =
        [[authorizedSet allObjects] sortedArrayUsingSelector:@selector(compare:)];

    NSArray<NSString *> *selectedGroups = nil;
    BOOL selectedObjectWasExplicit = selectedObject != nil;
    if (!selectedObjectWasExplicit) {
        selectedGroups = authorizedGroups;
    } else if (![selectedObject isKindOfClass:[NSArray class]]) {
        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
                                                            enabled:YES
                                                  systemApplication:systemApplication
                                                systemPolicyAllowed:systemPolicyAllowed
                                                     selectedGroups:@[]
                                                   authorizedGroups:authorizedGroups
                                              applicationIdentifier:applicationIdentifier
                                                   plannedPassCount:0
                                                         skipDetail:nil
                                                planningFailureCode:PXKeychainClearFailureCodeConfigurationFailed
                                             planningFailureMessage:@"Saved Keychain selection is malformed"];
    } else {
        NSMutableSet<NSString *> *selectedSet = [NSMutableSet set];
        for (id selectedObjectValue in (NSArray *)selectedObject) {
            if (!PXKeychainExactStringIsValid(selectedObjectValue)) {
                return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
                                                                    enabled:YES
                                                          systemApplication:systemApplication
                                                        systemPolicyAllowed:systemPolicyAllowed
                                                             selectedGroups:@[]
                                                           authorizedGroups:authorizedGroups
                                                      applicationIdentifier:applicationIdentifier
                                                           plannedPassCount:0
                                                                 skipDetail:nil
                                                        planningFailureCode:PXKeychainClearFailureCodeConfigurationFailed
                                                     planningFailureMessage:@"Saved Keychain selection is malformed"];
            }
            [selectedSet addObject:(NSString *)selectedObjectValue];
        }
        selectedGroups = [[selectedSet allObjects] sortedArrayUsingSelector:@selector(compare:)];
    }

    if (systemApplication && !systemPolicyAllowed) {
        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
                                                            enabled:YES
                                                  systemApplication:YES
                                                systemPolicyAllowed:NO
                                                     selectedGroups:selectedGroups ?: @[]
                                                   authorizedGroups:authorizedGroups
                                              applicationIdentifier:applicationIdentifier
                                                   plannedPassCount:0
                                                         skipDetail:nil
                                                planningFailureCode:PXKeychainClearFailureCodeConfigurationFailed
                                             planningFailureMessage:@"System Keychain wipe policy denied the request"];
    }

    if (authorizedGroups.count == 0) {
        if (selectedObjectWasExplicit && selectedGroups.count > 0) {
            return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
                                                                enabled:YES
                                                      systemApplication:systemApplication
                                                    systemPolicyAllowed:systemPolicyAllowed
                                                         selectedGroups:selectedGroups
                                                       authorizedGroups:@[]
                                                  applicationIdentifier:applicationIdentifier
                                                       plannedPassCount:0
                                                             skipDetail:nil
                                                    planningFailureCode:PXKeychainClearFailureCodeAuthorizationFailed
                                                 planningFailureMessage:@"Saved Keychain selection is not authorized"];
        }
        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
                                                            enabled:YES
                                                  systemApplication:systemApplication
                                                systemPolicyAllowed:systemPolicyAllowed
                                                     selectedGroups:@[]
                                                   authorizedGroups:@[]
                                              applicationIdentifier:applicationIdentifier
                                                   plannedPassCount:0
                                                         skipDetail:PXKeychainNoAuthorizedGroupsDetail
                                                planningFailureCode:0
                                             planningFailureMessage:nil];
    }

    if (selectedObjectWasExplicit && selectedGroups.count == 0) {
        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
                                                            enabled:YES
                                                  systemApplication:systemApplication
                                                systemPolicyAllowed:systemPolicyAllowed
                                                     selectedGroups:@[]
                                                   authorizedGroups:authorizedGroups
                                              applicationIdentifier:applicationIdentifier
                                                   plannedPassCount:0
                                                         skipDetail:PXKeychainNoSelectionDetail
                                                planningFailureCode:0
                                             planningFailureMessage:nil];
    }

    NSSet<NSString *> *authorizedMembership = [NSSet setWithArray:authorizedGroups];
    for (NSString *selectedGroup in selectedGroups) {
        if (![authorizedMembership containsObject:selectedGroup]) {
            return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
                                                                enabled:YES
                                                      systemApplication:systemApplication
                                                    systemPolicyAllowed:systemPolicyAllowed
                                                         selectedGroups:selectedGroups
                                                       authorizedGroups:authorizedGroups
                                                  applicationIdentifier:applicationIdentifier
                                                       plannedPassCount:0
                                                             skipDetail:nil
                                                    planningFailureCode:PXKeychainClearFailureCodeAuthorizationFailed
                                                 planningFailureMessage:@"Saved Keychain selection is not authorized"];
        }
    }

    if (!systemApplication && !PXKeychainExactStringIsValid(applicationIdentifier)) {
        return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
                                                            enabled:YES
                                                  systemApplication:NO
                                                systemPolicyAllowed:YES
                                                     selectedGroups:selectedGroups
                                                   authorizedGroups:authorizedGroups
                                              applicationIdentifier:nil
                                                   plannedPassCount:0
                                                         skipDetail:nil
                                                planningFailureCode:PXKeychainClearFailureCodeAuthorizationFailed
                                             planningFailureMessage:@"Signed application identifier is required"];
    }

    return [[PXKeychainClearPlan alloc] initWithBundleIdentifier:bundleIdentifier
                                                        enabled:YES
                                              systemApplication:systemApplication
                                            systemPolicyAllowed:systemPolicyAllowed
                                                 selectedGroups:selectedGroups
                                               authorizedGroups:authorizedGroups
                                          applicationIdentifier:applicationIdentifier
                                               plannedPassCount:1u
                                                     skipDetail:nil
                                            planningFailureCode:0
                                         planningFailureMessage:nil];
}

- (BOOL)_executeKeychainWipeForBundleIdentifier:(NSString *)bundleIdentifier
                                  selectedGroups:(NSArray<NSString *> *)selectedGroups
                           applicationIdentifier:(NSString *)applicationIdentifier
                              systemApplication:(BOOL)systemApplication
                                          error:(NSError **)error {
    if (error) *error = nil;
    if (!PXStrictBundleIdentifierIsValid(bundleIdentifier) ||
        ![selectedGroups isKindOfClass:[NSArray class]] ||
        selectedGroups.count == 0) {
        PXAssignKeychainNSError(error,
                                PXKeychainClearFailureCodeInvalidRequest,
                                @"Invalid Keychain execution request");
        return NO;
    }
    for (id group in selectedGroups) {
        if (!PXKeychainExactStringIsValid(group)) {
            PXAssignKeychainNSError(error,
                                    PXKeychainClearFailureCodeInvalidRequest,
                                    @"Invalid Keychain execution request");
            return NO;
        }
    }

    // Hard no-launch invariant: Keychain clear never starts the target application.
    // The wrapper re-reads the target's signed entitlements, prepares a private
    // resigned helper, validates its effective access groups, and performs the wipe
    // headlessly. Planning still supplies applicationIdentifier/systemApplication,
    // but execution authority comes from the signed target + exact selected groups.
    (void)applicationIdentifier;
    (void)systemApplication;

    CommandRunner *runner = [CommandRunner shared];
    NSString *scriptPath = [runner firstExistingPath:@[
        @"/Library/WeaponX/keychain_backup.sh",
        @"/var/jb/Library/WeaponX/keychain_backup.sh",
        @"/private/var/jb/Library/WeaponX/keychain_backup.sh"
    ]];
    if (!scriptPath.length || ![scriptPath hasPrefix:@"/"]) {
        PXAssignKeychainNSError(error,
                                PXKeychainClearFailureCodeConfigurationFailed,
                                @"Headless Keychain helper wrapper is unavailable");
        return NO;
    }

    NSString *groupsCSV = [selectedGroups componentsJoinedByString:@","];
    NSString *resolvedBundlePath = nil;
    NSString *resolvedExecutablePath =
        PXExactInstalledApplicationExecutablePathFromLaunchServices(bundleIdentifier,
                                                                    &resolvedBundlePath);
    NSMutableArray<NSString *> *wipeArguments = [NSMutableArray arrayWithObjects:
                                                  @"wipe",
                                                  bundleIdentifier,
                                                  nil];
    if (resolvedBundlePath.length && resolvedExecutablePath.length) {
        [wipeArguments addObjectsFromArray:@[
            @"--target-bundle", resolvedBundlePath,
            @"--target-executable", resolvedExecutablePath,
        ]];
    }
    [wipeArguments addObjectsFromArray:@[
        @"--groups", groupsCSV,
    ]];

    [self logMessage:@"[AppDataCleaner] Keychain wipe method=resigned_helper noLaunch=1 bundle=%@ groups=%lu nativeTarget=%d",
                     bundleIdentifier,
                     (unsigned long)selectedGroups.count,
                     (resolvedBundlePath.length && resolvedExecutablePath.length) ? 1 : 0];
    PXClearOperationContext *operationContext = PXCurrentClearOperationContext();
    NSTimeInterval keychainTimeout = operationContext
        ? [operationContext clampedTimeoutForStepLimit:120.0]
        : 120.0;
    CommandResult *wipeResult = nil;
    if (operationContext && keychainTimeout <= 0.0) {
        wipeResult = [[CommandResult alloc] init];
        wipeResult.runnerError = [[operationContext cancellationReason] isEqualToString:@"deadline"] ? ETIMEDOUT : ECANCELED;
    } else {
        wipeResult = [runner runExecutableAndCapture:scriptPath
                                            arguments:wipeArguments
                                           timeoutSec:keychainTimeout
                                       maxOutputBytes:1024 * 1024];
    }
    BOOL success = PXBoundedCommandSucceeded(wipeResult);
    NSString *dependencyToken = PXKeychainDependencyDiagnosticToken(wipeResult);
    NSString *stageToken = PXKeychainFailureStageDiagnosticToken(wipeResult);
    NSString *reasonToken = PXKeychainFailureReasonDiagnosticToken(wipeResult);
    NSMutableDictionary *diagnostic = [@{
        @"method": @"resigned_helper",
        @"noLaunch": @YES,
        @"success": @(success),
        @"exitCode": @(wipeResult ? wipeResult.exitCode : -1),
        @"timedOut": @(wipeResult ? wipeResult.timedOut : NO),
        @"stdoutTruncated": @(wipeResult ? wipeResult.stdoutTruncated : NO),
        @"stderrTruncated": @(wipeResult ? wipeResult.stderrTruncated : NO),
        @"groupCount": @(selectedGroups.count),
    } mutableCopy];
    if (dependencyToken.length) diagnostic[@"dependency"] = dependencyToken;
    if (stageToken.length) diagnostic[@"stage"] = stageToken;
    if (reasonToken.length) diagnostic[@"reason"] = reasonToken;
    [[NSUserDefaults standardUserDefaults] setObject:diagnostic
                                              forKey:[NSString stringWithFormat:@"DataCleaningKeychainResult_%@",
                                                                                 bundleIdentifier]];
    [[NSUserDefaults standardUserDefaults] synchronize];

    if (!success) {
        NSString *dependencySuffix = dependencyToken.length
            ? [NSString stringWithFormat:@" dependency=%@", dependencyToken]
            : @"";
        NSString *stageSuffix = stageToken.length
            ? [NSString stringWithFormat:@" stage=%@", stageToken]
            : @"";
        NSString *reasonSuffix = reasonToken.length
            ? [NSString stringWithFormat:@" reason=%@", reasonToken]
            : @"";
        NSString *message = [NSString stringWithFormat:@"Headless Keychain helper failed (exit=%d timeout=%d)%@%@%@",
                             wipeResult ? wipeResult.exitCode : -1,
                             wipeResult ? wipeResult.timedOut : NO,
                             dependencySuffix,
                             stageSuffix,
                             reasonSuffix];
        [self logMessage:@"[AppDataCleaner] Keychain wipe failed method=resigned_helper noLaunch=1 bundle=%@ %@",
                         bundleIdentifier, message];
        PXAssignKeychainNSError(error,
                                PXKeychainClearFailureCodeInitialPassFailed,
                                message);
    }
    return success;
}
- (PXClearComponentResult *)_keychainComponentForPlan:(PXKeychainClearPlan *)plan
                                          passResults:(NSArray<NSNumber *> *)passResults {
    if (![plan isKindOfClass:[PXKeychainClearPlan class]] ||
        ![passResults isKindOfClass:[NSArray class]]) {
        PXClearFailure *failure = PXKeychainFailure(PXKeychainClearFailureCodeInternalResultFailure,
                                                    @"Keychain result construction failed");
        return [[PXClearComponentResult alloc] initWithScope:PXClearScopeKeychain
                                                     status:PXClearComponentStatusFailed
                                         attemptedUnitCount:1
                                         succeededUnitCount:0
                                            failedUnitCount:1
                                                     detail:PXKeychainFailureDetail
                                                    failure:failure];
    }
    if (plan.planningFailureCode != 0) {
        PXClearFailure *failure = PXKeychainFailure((PXKeychainClearFailureCode)plan.planningFailureCode,
                                                    plan.planningFailureMessage ?: @"Keychain planning failed");
        PXClearComponentResult *result = [[PXClearComponentResult alloc] initWithScope:PXClearScopeKeychain
                                                                                status:PXClearComponentStatusFailed
                                                                    attemptedUnitCount:1
                                                                    succeededUnitCount:0
                                                                       failedUnitCount:1
                                                                                detail:PXKeychainFailureDetail
                                                                               failure:failure];
        return PXKeychainComponentResultIsStructurallyValid(result) ? result : nil;
    }
    if (plan.skipDetail.length) {
        PXClearComponentResult *result = [[PXClearComponentResult alloc] initWithScope:PXClearScopeKeychain
                                                                                status:PXClearComponentStatusSkipped
                                                                    attemptedUnitCount:0
                                                                    succeededUnitCount:0
                                                                       failedUnitCount:0
                                                                                detail:plan.skipDetail
                                                                               failure:nil];
        return PXKeychainComponentResultIsStructurallyValid(result) ? result : nil;
    }
    if (plan.plannedPassCount != 1 || passResults.count != 1) {
        PXClearFailure *failure = PXKeychainFailure(PXKeychainClearFailureCodeInternalResultFailure,
                                                    @"Keychain execution accounting is incomplete");
        PXClearComponentResult *result = [[PXClearComponentResult alloc] initWithScope:PXClearScopeKeychain
                                                                                status:PXClearComponentStatusFailed
                                                                    attemptedUnitCount:1
                                                                    succeededUnitCount:0
                                                                       failedUnitCount:1
                                                                                detail:PXKeychainFailureDetail
                                                                               failure:failure];
        return PXKeychainComponentResultIsStructurallyValid(result) ? result : nil;
    }

    BOOL passSucceeded = [passResults.firstObject respondsToSelector:@selector(boolValue)] &&
                         [passResults.firstObject boolValue];
    NSUInteger succeeded = passSucceeded ? 1u : 0u;
    PXClearFailure *firstFailure = passSucceeded ? nil : PXKeychainFailure(
        PXKeychainClearFailureCodeInitialPassFailed,
        @"Single keychain wipe pass failed");
    NSUInteger failed = 1u - succeeded;
    PXClearComponentResult *result = [[PXClearComponentResult alloc]
        initWithScope:PXClearScopeKeychain
               status:(failed == 0 ? PXClearComponentStatusSucceeded : PXClearComponentStatusFailed)
   attemptedUnitCount:plan.plannedPassCount
   succeededUnitCount:succeeded
      failedUnitCount:failed
               detail:(failed == 0 ? PXKeychainSuccessDetail : PXKeychainFailureDetail)
              failure:firstFailure];
    if (!PXKeychainComponentResultIsStructurallyValid(result)) {
        PXClearFailure *failure = PXKeychainFailure(PXKeychainClearFailureCodeInternalResultFailure,
                                                    @"Keychain result construction failed");
        return [[PXClearComponentResult alloc] initWithScope:PXClearScopeKeychain
                                                     status:PXClearComponentStatusFailed
                                         attemptedUnitCount:1
                                         succeededUnitCount:0
                                            failedUnitCount:1
                                                     detail:PXKeychainFailureDetail
                                                    failure:failure];
    }
    return result;
}

- (BOOL)_wipeSelectedKeychainForBundleID:(NSString *)bundleID
                                   error:(NSError **)error {
    if (error) *error = nil;
    PXKeychainClearPlan *plan = [self _keychainClearPlanForBundleIdentifier:bundleID];
    if (![plan isKindOfClass:[PXKeychainClearPlan class]]) {
        PXAssignKeychainNSError(error,
                                PXKeychainClearFailureCodeInternalResultFailure,
                                @"Keychain plan construction failed");
        return NO;
    }
    if (plan.skipDetail.length) return YES;
    if (plan.planningFailureCode != 0) {
        PXAssignKeychainNSError(error,
                                (PXKeychainClearFailureCode)plan.planningFailureCode,
                                plan.planningFailureMessage ?: @"Keychain planning failed");
        return NO;
    }
    return [self _executeKeychainWipeForBundleIdentifier:plan.bundleIdentifier
                                          selectedGroups:plan.selectedGroups
                                   applicationIdentifier:plan.applicationIdentifier
                                      systemApplication:plan.systemApplication
                                                  error:error];
}

#pragma mark - Exact Installed Extension Discovery

- (NSArray<NSString *> *)_exactInstalledExtensionIdentifiersForApplicationIdentifier:(NSString *)bundleIdentifier
                                                                                error:(NSError **)error {
    if (error) *error = nil;
    if (!PXStrictBundleIdentifierIsValid(bundleIdentifier)) {
        PXInstalledExtensionDiscoveryAssignError(error,
                                                 PXInstalledExtensionDiscoveryErrorCodeInvalidRequest,
                                                 @"Invalid application identifier for installed extension discovery");
        return nil;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray<NSString *> *bundleRoots = @[
        @"/var/containers/Bundle/Application",
        @"/containers/Bundle/Application"
    ];
    NSMutableArray<NSString *> *matchingApplicationBundles = [NSMutableArray array];
    NSString *launchServicesBundlePath =
        PXExactInstalledApplicationBundlePathFromLaunchServices(bundleIdentifier);
    if (launchServicesBundlePath.length) {
        [matchingApplicationBundles addObject:launchServicesBundlePath];
    }

    if (matchingApplicationBundles.count == 0) {
        for (NSString *bundleRoot in bundleRoots) {
        struct stat rootStat;
        if (lstat(bundleRoot.fileSystemRepresentation, &rootStat) != 0) {
            int savedErrno = errno;
            if (savedErrno == ENOENT || savedErrno == ENOTDIR) {
                continue;
            }
            PXInstalledExtensionDiscoveryAssignError(error,
                                                     PXInstalledExtensionDiscoveryErrorCodeEnumerationFailed,
                                                     @"Application bundle root inspection failed");
            return nil;
        }
        if (!S_ISDIR(rootStat.st_mode) || S_ISLNK(rootStat.st_mode)) {
            PXInstalledExtensionDiscoveryAssignError(error,
                                                     PXInstalledExtensionDiscoveryErrorCodeEnumerationFailed,
                                                     @"Application bundle root is not a real directory");
            return nil;
        }

        NSError *rootEnumerationError = nil;
        NSArray<NSString *> *uuidEntries = [fileManager contentsOfDirectoryAtPath:bundleRoot
                                                                            error:&rootEnumerationError];
        if (![uuidEntries isKindOfClass:[NSArray class]] || rootEnumerationError) {
            PXInstalledExtensionDiscoveryAssignError(error,
                                                     PXInstalledExtensionDiscoveryErrorCodeEnumerationFailed,
                                                     @"Application bundle root enumeration failed");
            return nil;
        }
        uuidEntries = [uuidEntries sortedArrayUsingSelector:@selector(compare:)];

        for (NSString *uuidEntry in uuidEntries) {
            if (![uuidEntry isKindOfClass:[NSString class]] || uuidEntry.length == 0 ||
                [uuidEntry characterAtIndex:0] == (unichar)'.' ||
                [[NSUUID alloc] initWithUUIDString:uuidEntry] == nil) {
                continue;
            }
            NSString *uuidContainerPath = [bundleRoot stringByAppendingPathComponent:uuidEntry];
            if (!PXReadOnlyRealDirectoryAtPath(uuidContainerPath)) {
                continue;
            }

            NSError *containerEnumerationError = nil;
            NSArray<NSString *> *appEntries = [fileManager contentsOfDirectoryAtPath:uuidContainerPath
                                                                               error:&containerEnumerationError];
            if (![appEntries isKindOfClass:[NSArray class]] || containerEnumerationError) {
                PXInstalledExtensionDiscoveryAssignError(error,
                                                         PXInstalledExtensionDiscoveryErrorCodeEnumerationFailed,
                                                         @"Application bundle container enumeration failed");
                return nil;
            }
            appEntries = [appEntries sortedArrayUsingSelector:@selector(compare:)];

            for (NSString *appEntry in appEntries) {
                if (![appEntry isKindOfClass:[NSString class]] ||
                    ![[appEntry pathExtension] isEqualToString:@"app"]) {
                    continue;
                }
                NSString *appBundlePath = [uuidContainerPath stringByAppendingPathComponent:appEntry];
                if (!PXReadOnlyRealDirectoryAtPath(appBundlePath)) {
                    continue;
                }
                NSString *infoPath = [appBundlePath stringByAppendingPathComponent:@"Info.plist"];
                if (!PXReadOnlyRegularNonSymlinkFileAtPath(infoPath)) {
                    continue;
                }
                NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
                id installedIdentifier = [info isKindOfClass:[NSDictionary class]]
                    ? info[@"CFBundleIdentifier"]
                    : nil;
                if ([installedIdentifier isKindOfClass:[NSString class]] &&
                    [(NSString *)installedIdentifier isEqualToString:bundleIdentifier]) {
                    [matchingApplicationBundles addObject:[appBundlePath copy]];
                }
            }
        }
        if (matchingApplicationBundles.count > 0) {
            break;
        }
    }
    }

    if (matchingApplicationBundles.count == 0 &&
        [bundleIdentifier hasPrefix:@"com.apple."]) {
        [self logMessage:
            @"[AppDataCleaner] No exact system application bundle path was available for %@; treating extension discovery as empty",
            bundleIdentifier];
        return @[];
    }

    if (matchingApplicationBundles.count == 0) {
        PXInstalledExtensionDiscoveryAssignError(error,
                                                 PXInstalledExtensionDiscoveryErrorCodeInvalidCandidate,
                                                 @"No exact installed application bundle match was found");
        return nil;
    }
    if (matchingApplicationBundles.count > 1) {
        PXInstalledExtensionDiscoveryAssignError(error,
                                                 PXInstalledExtensionDiscoveryErrorCodeAmbiguousMatch,
                                                 @"Multiple exact installed application bundle matches were found");
        return nil;
    }

    NSString *applicationBundlePath = matchingApplicationBundles.firstObject;
    NSArray<NSString *> *extensionLocations = @[
        applicationBundlePath,
        [applicationBundlePath stringByAppendingPathComponent:@"PlugIns"],
        [applicationBundlePath stringByAppendingPathComponent:@"Plugins"]
    ];
    NSMutableArray<NSString *> *extensionIdentifiers = [NSMutableArray array];
    NSMutableSet<NSString *> *seenIdentifiers = [NSMutableSet set];

    for (NSUInteger locationIndex = 0; locationIndex < extensionLocations.count; locationIndex++) {
        NSString *extensionLocation = extensionLocations[locationIndex];
        struct stat locationStat;
        if (lstat(extensionLocation.fileSystemRepresentation, &locationStat) != 0) {
            int savedErrno = errno;
            if (locationIndex > 0 && (savedErrno == ENOENT || savedErrno == ENOTDIR)) {
                continue;
            }
            PXInstalledExtensionDiscoveryAssignError(error,
                                                     PXInstalledExtensionDiscoveryErrorCodeEnumerationFailed,
                                                     @"Extension bundle location inspection failed");
            return nil;
        }
        if (!S_ISDIR(locationStat.st_mode) || S_ISLNK(locationStat.st_mode)) {
            PXInstalledExtensionDiscoveryAssignError(error,
                                                     PXInstalledExtensionDiscoveryErrorCodeInvalidCandidate,
                                                     @"Extension bundle location is not a real directory");
            return nil;
        }

        NSError *locationEnumerationError = nil;
        NSArray<NSString *> *extensionEntries = [fileManager contentsOfDirectoryAtPath:extensionLocation
                                                                                  error:&locationEnumerationError];
        if (![extensionEntries isKindOfClass:[NSArray class]] || locationEnumerationError) {
            PXInstalledExtensionDiscoveryAssignError(error,
                                                     PXInstalledExtensionDiscoveryErrorCodeEnumerationFailed,
                                                     @"Extension bundle location enumeration failed");
            return nil;
        }
        extensionEntries = [extensionEntries sortedArrayUsingSelector:@selector(compare:)];

        for (NSString *extensionEntry in extensionEntries) {
            if (![extensionEntry isKindOfClass:[NSString class]] ||
                ![[extensionEntry pathExtension] isEqualToString:@"appex"]) {
                continue;
            }
            NSString *extensionBundlePath = [extensionLocation stringByAppendingPathComponent:extensionEntry];
            if (!PXReadOnlyRealDirectoryAtPath(extensionBundlePath)) {
                PXInstalledExtensionDiscoveryAssignError(error,
                                                         PXInstalledExtensionDiscoveryErrorCodeInvalidCandidate,
                                                         @"An extension bundle is not a real directory");
                return nil;
            }
            NSString *extensionInfoPath = [extensionBundlePath stringByAppendingPathComponent:@"Info.plist"];
            if (!PXReadOnlyRegularNonSymlinkFileAtPath(extensionInfoPath)) {
                PXInstalledExtensionDiscoveryAssignError(error,
                                                         PXInstalledExtensionDiscoveryErrorCodeInvalidCandidate,
                                                         @"An extension bundle Info.plist is not a regular file");
                return nil;
            }
            NSDictionary *extensionInfo = [NSDictionary dictionaryWithContentsOfFile:extensionInfoPath];
            id extensionIdentifier = [extensionInfo isKindOfClass:[NSDictionary class]]
                ? extensionInfo[@"CFBundleIdentifier"]
                : nil;
            if (!PXStrictBundleIdentifierIsValid(extensionIdentifier)) {
                PXInstalledExtensionDiscoveryAssignError(error,
                                                         PXInstalledExtensionDiscoveryErrorCodeInvalidCandidate,
                                                         @"An extension bundle identifier is invalid");
                return nil;
            }

            NSString *exactIdentifier = (NSString *)extensionIdentifier;
            if ([seenIdentifiers containsObject:exactIdentifier]) {
                PXInstalledExtensionDiscoveryAssignError(error,
                                                         PXInstalledExtensionDiscoveryErrorCodeAmbiguousMatch,
                                                         @"An extension identifier is present in multiple extension bundles");
                return nil;
            }
            [seenIdentifiers addObject:exactIdentifier];
            [extensionIdentifiers addObject:[exactIdentifier copy]];
        }
    }

    return [extensionIdentifiers sortedArrayUsingSelector:@selector(compare:)];
}

#pragma mark - Exact Application Group Entitlements

- (NSArray<NSString *> *)_exactApplicationGroupIdentifiersForBundleIdentifier:(NSString *)bundleIdentifier
                                                                         error:(NSError **)error {
    if (error) *error = nil;
    if (!PXStrictBundleIdentifierIsValid(bundleIdentifier)) {
        PXAppGroupEntitlementDiscoveryAssignError(error,
                                                  PXAppGroupEntitlementDiscoveryErrorCodeInvalidRequest,
                                                  @"Invalid application identifier for App Group entitlement discovery");
        return nil;
    }

    AppEntitlementsReader *reader = [[AppEntitlementsReader alloc] init];
    NSError *extractionError = nil;
    NSDictionary *entitlements = [reader fullEntitlementsForBundleID:bundleIdentifier
                                                               error:&extractionError];
    if (extractionError || ![entitlements isKindOfClass:[NSDictionary class]]) {
        PXAppGroupEntitlementDiscoveryAssignError(error,
                                                  PXAppGroupEntitlementDiscoveryErrorCodeExtractionFailed,
                                                  @"Application entitlements could not be extracted");
        return nil;
    }

    NSArray<NSString *> *keys = @[
        @"com.apple.security.application-groups",
        @"application-groups"
    ];
    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];

    for (NSString *key in keys) {
        id declaredValue = [entitlements objectForKey:key];
        if (!declaredValue) {
            continue;
        }
        if (![declaredValue isKindOfClass:[NSArray class]]) {
            PXAppGroupEntitlementDiscoveryAssignError(error,
                                                      PXAppGroupEntitlementDiscoveryErrorCodeInvalidStructure,
                                                      @"An application-group entitlement has an invalid type");
            return nil;
        }
        for (id element in (NSArray *)declaredValue) {
            if (!PXAppGroupIdentifierIsValid(element)) {
                PXAppGroupEntitlementDiscoveryAssignError(error,
                                                          PXAppGroupEntitlementDiscoveryErrorCodeInvalidStructure,
                                                          @"An application-group entitlement contains an invalid identifier");
                return nil;
            }
            [identifiers addObject:[(NSString *)element copy]];
        }
    }

    return [[identifiers allObjects] sortedArrayUsingSelector:@selector(compare:)];
}

#pragma mark - Exact Extension Data Components

- (PXClearComponentResult *)_clearExactDataContainerComponentForIdentifiers:(NSArray<NSString *> *)identifiers
                                                                       kind:(PXResolvedContainerKind)kind
                                                                      scope:(PXClearScope)scope
                                                                 timeoutSec:(NSTimeInterval)timeoutSec
                                                             canonicalPaths:(NSArray<NSString *> **)canonicalPaths
                                                   successfulCanonicalPaths:(NSSet<NSString *> **)successfulCanonicalPaths {
    if (canonicalPaths) *canonicalPaths = @[];
    if (successfulCanonicalPaths) *successfulCanonicalPaths = [NSSet set];

    BOOL kindAndScopeMatch =
        (kind == PXResolvedContainerKindExtensionData && scope == PXClearScopeExtensionData) ||
        (kind == PXResolvedContainerKindPluginKitData && scope == PXClearScopePluginKitData);
    if (!kindAndScopeMatch ||
        ![identifiers isKindOfClass:[NSArray class]] ||
        timeoutSec <= 0.0) {
        return PXExactDataFailedComponent(scope,
                                          PXExactDataClearFailureCodeInvalidRequest,
                                          @"Invalid exact data-container clear request");
    }
    for (id identifier in identifiers) {
        if (!PXStrictBundleIdentifierIsValid(identifier)) {
            return PXExactDataFailedComponent(scope,
                                              PXExactDataClearFailureCodeInvalidRequest,
                                              @"Invalid exact extension identifier list");
        }
    }

    NSArray<NSString *> *sortedIdentifiers = [identifiers sortedArrayUsingSelector:@selector(compare:)];
    if (sortedIdentifiers.count == 0) {
        PXClearComponentResult *skipped = [[PXClearComponentResult alloc] initWithScope:scope
                                                                                 status:PXClearComponentStatusSkipped
                                                                     attemptedUnitCount:0
                                                                     succeededUnitCount:0
                                                                        failedUnitCount:0
                                                                                 detail:PXNoInstalledExtensionsDetail
                                                                                failure:nil];
        return skipped ?: PXExactDataFailedComponent(scope,
                                                     PXExactDataClearFailureCodeInternalResultFailure,
                                                     @"Skipped exact data-container result construction failed");
    }

    PXDataContainerResolver *resolver = [[PXDataContainerResolver alloc] init];
    PXDestructivePathValidator *validator = [[PXDestructivePathValidator alloc] init];
    NSMutableArray<NSString *> *validatedCanonicalPaths = [NSMutableArray array];
    NSMutableSet<NSString *> *successfulPaths = [NSMutableSet set];
    NSUInteger attemptedUnits = 0;
    NSUInteger succeededUnits = 0;
    NSUInteger failedUnits = 0;
    PXClearFailure *firstFailure = nil;

    const PXResolvedContainerRoot roots[] = {
        PXResolvedContainerRootRootful,
        PXResolvedContainerRootRootless,
    };
    NSArray<NSString *> *rootLabels = @[@"rootful", @"rootless"];
    NSString *componentName = PXExactDataComponentName(scope);

    for (NSString *identifier in sortedIdentifiers) {
        for (NSUInteger rootIndex = 0; rootIndex < 2; rootIndex++) {
            PXResolvedContainerRoot root = roots[rootIndex];
            NSError *resolutionError = nil;
            PXResolvedContainer *resolved = [resolver resolveDataContainerForIdentifier:identifier
                                                                                    kind:kind
                                                                                    root:root
                                                                                   error:&resolutionError];
            if (!resolved) {
                if (!resolutionError) {
                    continue;
                }
                attemptedUnits++;
                failedUnits++;
                if (!firstFailure) {
                    firstFailure = PXExactDataFailure(scope,
                                                      PXExactDataClearFailureCodeResolutionFailed,
                                                      [NSString stringWithFormat:@"%@ exact resolution failed for %@", componentName, rootLabels[rootIndex]]);
                }
                continue;
            }

            attemptedUnits++;
            NSError *validationError = nil;
            NSString *canonicalPath = [validator validatedCanonicalPathForContainer:resolved
                                                                               error:&validationError];
            if (canonicalPath.length == 0) {
                failedUnits++;
                if (!firstFailure) {
                    firstFailure = PXExactDataFailure(scope,
                                                      PXExactDataClearFailureCodeValidationFailed,
                                                      [NSString stringWithFormat:@"%@ validation failed for %@", componentName, rootLabels[rootIndex]]);
                }
                continue;
            }
            [validatedCanonicalPaths addObject:[canonicalPath copy]];

            NSString *wipeCommand = PXShellValidatedApplicationDataWipe(canonicalPath);
            CommandResult *commandResult = [self runCommandWithPrivilegesResult:wipeCommand
                                                                      timeoutSec:timeoutSec];
            if (!PXApplicationDataCommandResultSucceeded(commandResult)) {
                failedUnits++;
                if (!firstFailure) {
                    firstFailure = PXExactDataFailure(scope,
                                                      PXExactDataClearFailureCodeExecutionFailed,
                                                      [NSString stringWithFormat:@"%@ bounded execution failed for %@", componentName, rootLabels[rootIndex]]);
                }
                continue;
            }

            NSError *postValidationError = nil;
            NSString *postCanonicalPath = [validator validatedCanonicalPathForContainer:resolved
                                                                                    error:&postValidationError];
            if (postCanonicalPath.length == 0 || ![postCanonicalPath isEqualToString:canonicalPath]) {
                failedUnits++;
                if (!firstFailure) {
                    firstFailure = PXExactDataFailure(scope,
                                                      PXExactDataClearFailureCodeValidationFailed,
                                                      [NSString stringWithFormat:@"%@ post-command validation failed for %@", componentName, rootLabels[rootIndex]]);
                }
                continue;
            }

            NSError *postconditionError = nil;
            if (!PXApplicationDataPostconditionIsValid(postCanonicalPath, &postconditionError)) {
                failedUnits++;
                if (!firstFailure) {
                    firstFailure = PXExactDataFailure(scope,
                                                      PXExactDataClearFailureCodePostconditionFailed,
                                                      [NSString stringWithFormat:@"%@ strict postcondition failed for %@", componentName, rootLabels[rootIndex]]);
                }
                continue;
            }

            succeededUnits++;
            [successfulPaths addObject:[canonicalPath copy]];
        }
    }

    if (canonicalPaths) *canonicalPaths = [validatedCanonicalPaths copy];
    if (successfulCanonicalPaths) *successfulCanonicalPaths = [successfulPaths copy];

    if (attemptedUnits == 0) {
        NSString *detail = scope == PXClearScopePluginKitData
            ? PXNoExactPluginKitDataContainersDetail
            : PXNoExactExtensionDataContainersDetail;
        PXClearComponentResult *skipped = [[PXClearComponentResult alloc] initWithScope:scope
                                                                                 status:PXClearComponentStatusSkipped
                                                                     attemptedUnitCount:0
                                                                     succeededUnitCount:0
                                                                        failedUnitCount:0
                                                                                 detail:detail
                                                                                failure:nil];
        return skipped ?: PXExactDataFailedComponent(scope,
                                                     PXExactDataClearFailureCodeInternalResultFailure,
                                                     @"Absent exact data-container result construction failed");
    }

    PXClearComponentStatus status = failedUnits > 0
        ? PXClearComponentStatusFailed
        : PXClearComponentStatusSucceeded;
    NSString *detail = failedUnits > 0
        ? [NSString stringWithFormat:@"One or more exact %@ units failed", componentName]
        : [NSString stringWithFormat:@"All exact %@ units succeeded", componentName];
    PXClearComponentResult *result = [[PXClearComponentResult alloc] initWithScope:scope
                                                                            status:status
                                                                attemptedUnitCount:attemptedUnits
                                                                succeededUnitCount:succeededUnits
                                                                   failedUnitCount:failedUnits
                                                                            detail:detail
                                                                           failure:firstFailure];
    if (!PXExactDataComponentResultIsStructurallyValid(result, scope)) {
        return PXExactDataFailedComponent(scope,
                                          PXExactDataClearFailureCodeInternalResultFailure,
                                          @"Exact data-container accounting produced an invalid result");
    }
    return result;
}

- (PXClearComponentResult *)_componentByApplyingFinalPostconditionToResult:(PXClearComponentResult *)result
                                                            canonicalPaths:(NSArray<NSString *> *)canonicalPaths
                                                  successfulCanonicalPaths:(NSSet<NSString *> *)successfulCanonicalPaths {
    PXClearScope scope = result.scope;
    if (!PXExactDataComponentResultIsStructurallyValid(result, scope) ||
        ![canonicalPaths isKindOfClass:[NSArray class]] ||
        ![successfulCanonicalPaths isKindOfClass:[NSSet class]]) {
        return PXExactDataFailedComponent(scope,
                                          PXExactDataClearFailureCodeInternalResultFailure,
                                          @"Final exact data-container verification received invalid state");
    }
    if (result.status == PXClearComponentStatusSkipped || canonicalPaths.count == 0) {
        return result;
    }

    NSUInteger succeededUnits = result.succeededUnitCount;
    NSUInteger failedUnits = result.failedUnitCount;
    PXClearFailure *firstFailure = result.failure;
    BOOL changed = NO;

    for (NSString *canonicalPath in canonicalPaths) {
        NSError *postconditionError = nil;
        if (PXApplicationDataPostconditionIsValid(canonicalPath, &postconditionError)) {
            continue;
        }
        if ([successfulCanonicalPaths containsObject:canonicalPath]) {
            if (succeededUnits > 0) succeededUnits--;
            failedUnits++;
            changed = YES;
            if (!firstFailure) {
                firstFailure = PXExactDataFailure(scope,
                                                  PXExactDataClearFailureCodePostconditionFailed,
                                                  [NSString stringWithFormat:@"%@ final strict postcondition failed", PXExactDataComponentName(scope)]);
            }
        } else {
            [self logMessage:@"[AppDataCleaner] %@ final read-only verification remains failed for an already-failed unit",
                  PXExactDataComponentName(scope)];
        }
    }

    if (!changed) {
        return result;
    }

    PXClearComponentResult *finalResult = [[PXClearComponentResult alloc] initWithScope:scope
                                                                                 status:PXClearComponentStatusFailed
                                                                     attemptedUnitCount:result.attemptedUnitCount
                                                                     succeededUnitCount:succeededUnits
                                                                        failedUnitCount:failedUnits
                                                                                 detail:[NSString stringWithFormat:@"%@ final strict verification failed", PXExactDataComponentName(scope)]
                                                                                failure:firstFailure];
    if (!PXExactDataComponentResultIsStructurallyValid(finalResult, scope)) {
        return PXExactDataFailedComponent(scope,
                                          PXExactDataClearFailureCodeInternalResultFailure,
                                          @"Final exact data-container accounting produced an invalid result");
    }
    return finalResult;
}

#pragma mark - Exact App Group Component

- (PXClearComponentResult *)_clearExactAppGroupsComponentForIdentifiers:(NSArray<NSString *> *)identifiers
                                                              timeoutSec:(NSTimeInterval)timeoutSec
                                                          canonicalPaths:(NSArray<NSString *> **)canonicalPaths
                                                successfulCanonicalPaths:(NSSet<NSString *> **)successfulCanonicalPaths {
    if (canonicalPaths) *canonicalPaths = @[];
    if (successfulCanonicalPaths) *successfulCanonicalPaths = [NSSet set];

    if (![identifiers isKindOfClass:[NSArray class]] || timeoutSec <= 0.0) {
        return PXAppGroupsFailedComponent(PXAppGroupsClearFailureCodeInvalidRequest,
                                          @"Invalid exact App Groups clear request");
    }
    for (id identifier in identifiers) {
        if (!PXAppGroupIdentifierIsValid(identifier)) {
            return PXAppGroupsFailedComponent(PXAppGroupsClearFailureCodeInvalidRequest,
                                              @"Invalid exact application-group identifier list");
        }
    }

    NSArray<NSString *> *sortedIdentifiers =
        [identifiers sortedArrayUsingSelector:@selector(compare:)];
    if (sortedIdentifiers.count == 0) {
        PXClearComponentResult *skipped =
            [[PXClearComponentResult alloc] initWithScope:PXClearScopeAppGroups
                                                   status:PXClearComponentStatusSkipped
                                       attemptedUnitCount:0
                                       succeededUnitCount:0
                                          failedUnitCount:0
                                                   detail:PXNoDeclaredAppGroupsDetail
                                                  failure:nil];
        return skipped ?: PXAppGroupsFailedComponent(
            PXAppGroupsClearFailureCodeInternalResultFailure,
            @"Skipped App Groups result construction failed");
    }

    AppGroupContainerResolver *resolver = [[AppGroupContainerResolver alloc] init];
    PXDestructivePathValidator *validator = [[PXDestructivePathValidator alloc] init];
    NSMutableDictionary<NSString *, NSMutableArray<PXResolvedContainer *> *> *modelsByPath =
        [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *physicalPathOrder = [NSMutableArray array];
    NSMutableSet<NSString *> *successfulPaths = [NSMutableSet set];
    NSUInteger attemptedUnits = 0;
    NSUInteger succeededUnits = 0;
    NSUInteger failedUnits = 0;
    PXClearFailure *firstFailure = nil;

    const PXResolvedContainerRoot roots[] = {
        PXResolvedContainerRootRootful,
        PXResolvedContainerRootRootless,
    };
    NSArray<NSString *> *rootLabels = @[@"rootful", @"rootless"];

    for (NSString *identifier in sortedIdentifiers) {
        for (NSUInteger rootIndex = 0; rootIndex < 2; rootIndex++) {
            PXResolvedContainerRoot root = roots[rootIndex];
            NSError *resolutionError = nil;
            NSArray<PXResolvedContainer *> *resolvedModels =
                [resolver resolveAllAppGroupContainersForGroupIdentifier:identifier
                                                                    root:root
                                                                   error:&resolutionError];
            if (!resolvedModels) {
                attemptedUnits++;
                failedUnits++;
                NSString *resolverDescription = resolutionError.localizedDescription.length
                    ? resolutionError.localizedDescription
                    : @"Unknown App Group resolver failure";
                NSString *resolutionMessage = [NSString stringWithFormat:
                    @"App Groups exact resolution failed for %@ (%@:%ld): %@",
                    rootLabels[rootIndex],
                    resolutionError.domain ?: @"unknown",
                    (long)resolutionError.code,
                    resolverDescription];
                if (!firstFailure) {
                    firstFailure = PXAppGroupsFailure(
                        PXAppGroupsClearFailureCodeResolutionFailed,
                        resolutionMessage);
                }
                [self logMessage:
                    @"[AppDataCleaner] AppGroups %@ resolution failed for %@ (%@:%ld): %@",
                    rootLabels[rootIndex],
                    identifier,
                    resolutionError.domain ?: @"unknown",
                    (long)resolutionError.code,
                    resolverDescription];
                continue;
            }

            if (resolvedModels.count > 1) {
                [self logMessage:
                    @"[AppDataCleaner] AppGroups %@ found %lu exact physical containers for %@; validating every container",
                    rootLabels[rootIndex],
                    (unsigned long)resolvedModels.count,
                    identifier];
            }

            for (PXResolvedContainer *resolved in resolvedModels) {
                NSError *validationError = nil;
                NSString *canonicalPath =
                    [validator validatedCanonicalPathForContainer:resolved error:&validationError];
                if (canonicalPath.length == 0) {
                    attemptedUnits++;
                    failedUnits++;
                    if (!firstFailure) {
                        NSString *validationDescription = validationError.localizedDescription.length
                            ? validationError.localizedDescription
                            : @"Unknown App Group validation failure";
                        firstFailure = PXAppGroupsFailure(
                            PXAppGroupsClearFailureCodeValidationFailed,
                            [NSString stringWithFormat:
                                @"App Groups validation failed for %@ (%@:%ld): %@",
                                rootLabels[rootIndex],
                                validationError.domain ?: @"unknown",
                                (long)validationError.code,
                                validationDescription]);
                    }
                    continue;
                }

                NSMutableArray<PXResolvedContainer *> *models = modelsByPath[canonicalPath];
                if (!models) {
                    models = [NSMutableArray array];
                    modelsByPath[[canonicalPath copy]] = models;
                    [physicalPathOrder addObject:[canonicalPath copy]];
                }
                [models addObject:resolved];
            }
        }
    }

    for (NSString *canonicalPath in physicalPathOrder) {
        attemptedUnits++;
        NSArray<PXResolvedContainer *> *models = [modelsByPath[canonicalPath] copy];
        NSString *wipeCommand = PXShellValidatedApplicationDataWipe(canonicalPath);
        CommandResult *commandResult =
            [self runCommandWithPrivilegesResult:wipeCommand timeoutSec:timeoutSec];
        if (!PXApplicationDataCommandResultSucceeded(commandResult)) {
            failedUnits++;
            if (!firstFailure) {
                firstFailure = PXAppGroupsFailure(
                    PXAppGroupsClearFailureCodeExecutionFailed,
                    @"App Groups bounded execution failed");
            }
            continue;
        }

        BOOL allModelsStillAuthorizePath = YES;
        for (PXResolvedContainer *model in models) {
            NSError *postValidationError = nil;
            NSString *postCanonicalPath =
                [validator validatedCanonicalPathForContainer:model error:&postValidationError];
            if (postCanonicalPath.length == 0 ||
                ![postCanonicalPath isEqualToString:canonicalPath]) {
                allModelsStillAuthorizePath = NO;
                break;
            }
        }
        if (!allModelsStillAuthorizePath) {
            failedUnits++;
            if (!firstFailure) {
                firstFailure = PXAppGroupsFailure(
                    PXAppGroupsClearFailureCodeValidationFailed,
                    @"App Groups post-command identity validation failed");
            }
            continue;
        }

        NSError *postconditionError = nil;
        if (!PXApplicationDataPostconditionIsValid(canonicalPath, &postconditionError)) {
            failedUnits++;
            if (!firstFailure) {
                firstFailure = PXAppGroupsFailure(
                    PXAppGroupsClearFailureCodePostconditionFailed,
                    @"App Groups strict postcondition failed");
            }
            continue;
        }

        succeededUnits++;
        [successfulPaths addObject:[canonicalPath copy]];
    }

    if (canonicalPaths) *canonicalPaths = [physicalPathOrder copy];
    if (successfulCanonicalPaths) *successfulCanonicalPaths = [successfulPaths copy];

    if (attemptedUnits == 0) {
        PXClearComponentResult *skipped =
            [[PXClearComponentResult alloc] initWithScope:PXClearScopeAppGroups
                                                   status:PXClearComponentStatusSkipped
                                       attemptedUnitCount:0
                                       succeededUnitCount:0
                                          failedUnitCount:0
                                                   detail:PXNoExactAppGroupContainersDetail
                                                  failure:nil];
        return skipped ?: PXAppGroupsFailedComponent(
            PXAppGroupsClearFailureCodeInternalResultFailure,
            @"Absent App Groups result construction failed");
    }

    PXClearComponentStatus status = failedUnits > 0
        ? PXClearComponentStatusFailed
        : PXClearComponentStatusSucceeded;
    NSString *detail = failedUnits > 0
        ? @"One or more exact App Group physical units failed"
        : @"All exact App Group physical units succeeded";
    PXClearComponentResult *result =
        [[PXClearComponentResult alloc] initWithScope:PXClearScopeAppGroups
                                               status:status
                                   attemptedUnitCount:attemptedUnits
                                   succeededUnitCount:succeededUnits
                                      failedUnitCount:failedUnits
                                               detail:detail
                                              failure:firstFailure];
    if (!PXAppGroupsComponentResultIsStructurallyValid(result)) {
        return PXAppGroupsFailedComponent(
            PXAppGroupsClearFailureCodeInternalResultFailure,
            @"App Groups accounting produced an invalid result");
    }
    return result;
}

- (PXClearComponentResult *)_appGroupsComponentByApplyingFinalPostconditionToResult:(PXClearComponentResult *)result
                                                                     canonicalPaths:(NSArray<NSString *> *)canonicalPaths
                                                           successfulCanonicalPaths:(NSSet<NSString *> *)successfulCanonicalPaths {
    if (!PXAppGroupsComponentResultIsStructurallyValid(result) ||
        ![canonicalPaths isKindOfClass:[NSArray class]] ||
        ![successfulCanonicalPaths isKindOfClass:[NSSet class]]) {
        return PXAppGroupsFailedComponent(
            PXAppGroupsClearFailureCodeInternalResultFailure,
            @"Final App Groups verification received invalid state");
    }
    if (result.status == PXClearComponentStatusSkipped || canonicalPaths.count == 0) {
        return result;
    }

    NSUInteger succeededUnits = result.succeededUnitCount;
    NSUInteger failedUnits = result.failedUnitCount;
    PXClearFailure *firstFailure = result.failure;
    BOOL changed = NO;

    for (NSString *canonicalPath in canonicalPaths) {
        NSError *postconditionError = nil;
        if (PXApplicationDataPostconditionIsValid(canonicalPath, &postconditionError)) {
            continue;
        }
        if ([successfulCanonicalPaths containsObject:canonicalPath]) {
            if (succeededUnits > 0) succeededUnits--;
            failedUnits++;
            changed = YES;
            if (!firstFailure) {
                firstFailure = PXAppGroupsFailure(
                    PXAppGroupsClearFailureCodePostconditionFailed,
                    @"App Groups final strict postcondition failed");
            }
        } else {
            [self logMessage:@"[AppDataCleaner] AppGroups final read-only verification remains failed for an already-failed physical unit"];
        }
    }

    if (!changed) {
        return result;
    }

    PXClearComponentResult *finalResult =
        [[PXClearComponentResult alloc] initWithScope:PXClearScopeAppGroups
                                               status:PXClearComponentStatusFailed
                                   attemptedUnitCount:result.attemptedUnitCount
                                   succeededUnitCount:succeededUnits
                                      failedUnitCount:failedUnits
                                               detail:@"App Groups final strict verification failed"
                                              failure:firstFailure];
    if (!PXAppGroupsComponentResultIsStructurallyValid(finalResult)) {
        return PXAppGroupsFailedComponent(
            PXAppGroupsClearFailureCodeInternalResultFailure,
            @"Final App Groups accounting produced an invalid result");
    }
    return finalResult;
}

- (PXClearResult *)_completeDataWipeForMigratedRequest:(PXClearRequest *)request {
    if (![request isKindOfClass:[PXClearRequest class]] ||
        request.scopes != PXMigratedDataClearScopes) {
        return nil;
    }

    // CLEAR-05: Quick remains inside the canonical four-scope authority but
    // executes only application data. The other exact scopes are represented
    // explicitly as skipped so result ordering/accounting stays stable.
    if (!PXClearModeIncludesExtendedContainers(request.mode)) {
        PXClearRequest *applicationRequest =
            [[PXClearRequest alloc] initWithBundleIdentifier:request.bundleIdentifier
                                                      scopes:PXClearScopeApplicationData
                                                        mode:request.mode
                                                     options:request.options];
        PXClearComponentResult *applicationResult = applicationRequest
            ? [self _completeAppDataWipeForApplicationDataRequest:applicationRequest]
            : nil;
        if (!PXApplicationDataComponentResultIsStructurallyValid(applicationResult)) {
            applicationResult = PXApplicationDataFailedComponent(
                PXApplicationDataClearFailureCodeInternalResultFailure,
                @"ApplicationData internal result validation failed");
        }
        PXClearComponentResult *extensionResult = [[PXClearComponentResult alloc]
            initWithScope:PXClearScopeExtensionData status:PXClearComponentStatusSkipped
            attemptedUnitCount:0 succeededUnitCount:0 failedUnitCount:0
            detail:@"Quick mode excludes extension-data containers" failure:nil];
        PXClearComponentResult *appGroupsResult = [[PXClearComponentResult alloc]
            initWithScope:PXClearScopeAppGroups status:PXClearComponentStatusSkipped
            attemptedUnitCount:0 succeededUnitCount:0 failedUnitCount:0
            detail:@"Quick mode excludes App Group containers" failure:nil];
        PXClearComponentResult *pluginKitResult = [[PXClearComponentResult alloc]
            initWithScope:PXClearScopePluginKitData status:PXClearComponentStatusSkipped
            attemptedUnitCount:0 succeededUnitCount:0 failedUnitCount:0
            detail:@"Quick mode excludes PluginKit containers" failure:nil];
        PXClearResult *quickResult = [[PXClearResult alloc] initWithRequest:request
            componentResults:@[applicationResult, extensionResult, appGroupsResult, pluginKitResult]];
        return PXMigratedDataClearResultIsStructurallyValid(quickResult) ? quickResult : nil;
    }

    NSError *extensionDiscoveryError = nil;
    NSArray<NSString *> *extensionIdentifiers =
        [self _exactInstalledExtensionIdentifiersForApplicationIdentifier:request.bundleIdentifier
                                                                     error:&extensionDiscoveryError];

    NSError *appGroupDiscoveryError = nil;
    NSArray<NSString *> *appGroupIdentifiers =
        [self _exactApplicationGroupIdentifiersForBundleIdentifier:request.bundleIdentifier
                                                             error:&appGroupDiscoveryError];

    PXClearRequest *applicationRequest =
        [[PXClearRequest alloc] initWithBundleIdentifier:request.bundleIdentifier
                                                  scopes:PXClearScopeApplicationData
                                                    mode:request.mode
                                                 options:request.options];
    PXClearComponentResult *applicationResult = applicationRequest
        ? [self _completeAppDataWipeForApplicationDataRequest:applicationRequest]
        : nil;
    if (!PXApplicationDataComponentResultIsStructurallyValid(applicationResult)) {
        applicationResult = PXApplicationDataFailedComponent(
            PXApplicationDataClearFailureCodeInternalResultFailure,
            @"ApplicationData internal result validation failed");
    }

    BOOL isSystemApplication = [request.bundleIdentifier hasPrefix:@"com.apple."];
    NSTimeInterval timeoutSec = (request.deepClean || isSystemApplication)
        ? (NSTimeInterval)(15 * 60)
        : (NSTimeInterval)(5 * 60);

    NSArray<NSString *> *extensionCanonicalPaths = @[];
    NSArray<NSString *> *appGroupCanonicalPaths = @[];
    NSArray<NSString *> *pluginKitCanonicalPaths = @[];
    NSSet<NSString *> *successfulExtensionPaths = [NSSet set];
    NSSet<NSString *> *successfulAppGroupPaths = [NSSet set];
    NSSet<NSString *> *successfulPluginKitPaths = [NSSet set];
    PXClearComponentResult *extensionResult = nil;
    PXClearComponentResult *appGroupsResult = nil;
    PXClearComponentResult *pluginKitResult = nil;

    if (!extensionIdentifiers && extensionDiscoveryError) {
        extensionResult = PXExactDataFailedComponent(
            PXClearScopeExtensionData,
            PXExactDataClearFailureCodeDiscoveryFailed,
            @"Exact installed extension discovery failed");
        pluginKitResult = PXExactDataFailedComponent(
            PXClearScopePluginKitData,
            PXExactDataClearFailureCodeDiscoveryFailed,
            @"Exact installed extension discovery failed");
    } else {
        extensionResult =
            [self _clearExactDataContainerComponentForIdentifiers:extensionIdentifiers ?: @[]
                                                             kind:PXResolvedContainerKindExtensionData
                                                            scope:PXClearScopeExtensionData
                                                       timeoutSec:timeoutSec
                                                   canonicalPaths:&extensionCanonicalPaths
                                         successfulCanonicalPaths:&successfulExtensionPaths];
        pluginKitResult =
            [self _clearExactDataContainerComponentForIdentifiers:extensionIdentifiers ?: @[]
                                                             kind:PXResolvedContainerKindPluginKitData
                                                            scope:PXClearScopePluginKitData
                                                       timeoutSec:timeoutSec
                                                   canonicalPaths:&pluginKitCanonicalPaths
                                         successfulCanonicalPaths:&successfulPluginKitPaths];
    }

    if (!appGroupIdentifiers && appGroupDiscoveryError) {
        appGroupsResult = PXAppGroupsFailedComponent(
            PXAppGroupsClearFailureCodeEntitlementDiscoveryFailed,
            @"Exact application-group entitlement discovery failed");
    } else {
        appGroupsResult =
            [self _clearExactAppGroupsComponentForIdentifiers:appGroupIdentifiers ?: @[]
                                                   timeoutSec:timeoutSec
                                               canonicalPaths:&appGroupCanonicalPaths
                                     successfulCanonicalPaths:&successfulAppGroupPaths];
    }

    extensionResult =
        [self _componentByApplyingFinalPostconditionToResult:extensionResult
                                              canonicalPaths:extensionCanonicalPaths
                                    successfulCanonicalPaths:successfulExtensionPaths];
    pluginKitResult =
        [self _componentByApplyingFinalPostconditionToResult:pluginKitResult
                                              canonicalPaths:pluginKitCanonicalPaths
                                    successfulCanonicalPaths:successfulPluginKitPaths];
    appGroupsResult =
        [self _appGroupsComponentByApplyingFinalPostconditionToResult:appGroupsResult
                                                        canonicalPaths:appGroupCanonicalPaths
                                              successfulCanonicalPaths:successfulAppGroupPaths];

    PXClearOperationContext *operationContext = PXCurrentClearOperationContext();
    if (operationContext) {
        operationContext.extensionDataCanonicalPaths = [extensionCanonicalPaths copy] ?: @[];
        operationContext.appGroupCanonicalPaths = [appGroupCanonicalPaths copy] ?: @[];
        operationContext.pluginKitDataCanonicalPaths = [pluginKitCanonicalPaths copy] ?: @[];
    } else {
        _wipeCacheExtensionDataCanonicalPaths = [extensionCanonicalPaths copy] ?: @[];
        _wipeCacheAppGroupCanonicalPaths = [appGroupCanonicalPaths copy] ?: @[];
        _wipeCachePluginKitDataCanonicalPaths = [pluginKitCanonicalPaths copy] ?: @[];
    }

    if (!PXExactDataComponentResultIsStructurallyValid(extensionResult,
                                                       PXClearScopeExtensionData)) {
        extensionResult = PXExactDataFailedComponent(
            PXClearScopeExtensionData,
            PXExactDataClearFailureCodeInternalResultFailure,
            @"ExtensionData internal result validation failed");
    }
    if (!PXAppGroupsComponentResultIsStructurallyValid(appGroupsResult)) {
        appGroupsResult = PXAppGroupsFailedComponent(
            PXAppGroupsClearFailureCodeInternalResultFailure,
            @"AppGroups internal result validation failed");
    }
    if (!PXExactDataComponentResultIsStructurallyValid(pluginKitResult,
                                                       PXClearScopePluginKitData)) {
        pluginKitResult = PXExactDataFailedComponent(
            PXClearScopePluginKitData,
            PXExactDataClearFailureCodeInternalResultFailure,
            @"PluginKitData internal result validation failed");
    }

    PXClearResult *aggregate =
        [[PXClearResult alloc] initWithRequest:request
                             componentResults:@[
                                 applicationResult,
                                 extensionResult,
                                 appGroupsResult,
                                 pluginKitResult
                             ]];
    return PXMigratedDataClearResultIsStructurallyValid(aggregate) ? aggregate : nil;
}

#pragma mark - Main Public Methods

- (void)clearDataForBundleID:(NSString *)bundleID completion:(void (^)(BOOL, NSError *))completion {
    PXClearMode persistedMode = [self _deepCleanEnabled] ? PXClearModeDeep : PXClearModeFull;
    [self clearDataForBundleID:bundleID mode:persistedMode completion:completion];
}

// CLEAR-01: dry-run capable Clear entry point. When dryRun is YES this only
// plans and journals the intended work; it performs no destructive operations.
// When dryRun is NO it delegates to the canonical Full/Deep clear authority.
- (void)clearDataForBundleID:(NSString *)bundleID mode:(PXClearMode)mode dryRun:(BOOL)dryRun completion:(void (^)(BOOL success, NSError *error))completion {
    if (!dryRun) {
        [self clearDataForBundleID:bundleID mode:mode completion:completion];
        return;
    }
    CFAbsoluteTime dryRunStartedAt = CFAbsoluteTimeGetCurrent();
    [self logMessage:@"[AppDataCleaner] DRY-RUN: planning %@ clear for %@ (no destructive operations)",
        PXClearModeName(mode), bundleID];
    PXClearWriteJournal(bundleID, mode, PXMigratedFullClearScopes, YES, @"dry_run_plan",
                        @{ @"deepClean": @(PXClearModeIncludesDeepDiagnostics(mode)) });
    PXClearOptions dryRunOptions = PXClearOptionNone;
    if (PXReadSecurityBool(@"clearICloudDataEnabled", NO)) {
        dryRunOptions |= PXClearOptionICloudData;
    }
    if (PXReadSecurityBool(@"clearSafariSharedWebDataEnabled", NO)) {
        dryRunOptions |= PXClearOptionSafariSharedWebData;
    }
    if (PXReadSecurityBool(@"clearMailSharedStoreEnabled", NO)) {
        dryRunOptions |= PXClearOptionMailSharedStore;
    }
    NSDictionary *pxDryRunPlan = @{
        @"mode": PXClearModeName(mode) ?: @"unknown",
        @"scopes": @((unsigned long long)PXMigratedFullClearScopes),
        @"wouldKillApp": @YES,
        @"wouldClearKeychain": @YES,
        @"wouldClearURLCredentials": @NO,
        @"wouldRunDataAggregate": @YES,
        @"wouldClearICloudData": @(PXClearModeIncludesExtendedContainers(mode) &&
                                     ((dryRunOptions & PXClearOptionICloudData) != 0)),
        @"wouldClearSafariSharedWebData": @(mode == PXClearModeDeep &&
                                              [bundleID isEqualToString:@"com.apple.mobilesafari"] &&
                                              ((dryRunOptions & PXClearOptionSafariSharedWebData) != 0)),
        @"wouldClearMailSharedStore": @(mode == PXClearModeDeep &&
                                        [bundleID isEqualToString:@"com.apple.mobilemail"] &&
                                        ((dryRunOptions & PXClearOptionMailSharedStore) != 0)),
        @"wouldRunDeepResidualScan": @(PXClearModeIncludesDeepDiagnostics(mode))
    };
    PXClearWriteJournal(bundleID, mode, PXMigratedFullClearScopes, YES, @"dry_run_commit", pxDryRunPlan);
    [self logMessage:@"[AppDataCleaner][metric] mode=%@ dry_run=1 total_ms=%.0f success=1",
        PXClearModeName(mode),
        (CFAbsoluteTimeGetCurrent() - dryRunStartedAt) * 1000.0];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (completion) completion(YES, nil);
    });
}

- (void)clearDataForBundleID:(NSString *)bundleID
                        mode:(PXClearMode)mode
                  completion:(void (^)(BOOL, NSError *))completion {
    CFAbsoluteTime requestStartedAt = CFAbsoluteTimeGetCurrent();
    [self logMessage:@"[AppDataCleaner] === STARTING %@ data clearing for %@ ===",
        PXClearModeName(mode), bundleID];

    if (!PXClearModeIsValid(mode)) {
        NSError *modeError = PXMigratedInternalError(@"Invalid Clear mode");
        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(NO, modeError); });
        return;
    }
    BOOL deepClean = PXClearModeIncludesDeepDiagnostics(mode);
    PXClearOptions clearOptions = PXClearOptionNone;
    if (PXReadSecurityBool(@"clearICloudDataEnabled", NO)) {
        clearOptions |= PXClearOptionICloudData;
    }
    if (PXReadSecurityBool(@"clearSafariSharedWebDataEnabled", NO)) {
        clearOptions |= PXClearOptionSafariSharedWebData;
    }
    if (PXReadSecurityBool(@"clearMailSharedStoreEnabled", NO)) {
        clearOptions |= PXClearOptionMailSharedStore;
    }
    PXClearRequest *fullRequest = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                            scopes:PXMigratedFullClearScopes
                                                                              mode:mode
                                                                           options:clearOptions];
    PXClearRequest *dataRequest = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                            scopes:PXMigratedDataClearScopes
                                                                              mode:mode
                                                                           options:clearOptions];
    if (!fullRequest || !dataRequest) {
        NSError *requestError = PXMigratedInternalError(@"Invalid full Clear request");
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(NO, requestError);
        });
        return;
    }

    PXClearOperationContext *operationContext = [[PXClearOperationContext alloc]
        initWithFullRequest:fullRequest dataRequest:dataRequest];

    // 7.4: snapshot cumulative metric counters so this run reports per-run deltas.
    uint_fast64_t pxMetricShellAtStart = atomic_load(&gPXClearShellProcessCount);
    uint_fast64_t pxMetricPathsAtStart = atomic_load(&gPXClearPathsScannedCount);
    uint_fast64_t pxMetricSqliteNanosAtStart = atomic_load(&gPXClearSqliteNanos);
    __block double pxResolveContainerMs = 0.0;
    __block uint_fast64_t pxTimeoutFallbackCount = 0;

    // CLEAR-01: write the transaction begin journal before any destructive step.
    PXClearWriteJournal(bundleID, mode, fullRequest.scopes, NO, @"begin",
                        @{ @"deepClean": @(deepClean),
                           @"clearICloudData": @((clearOptions & PXClearOptionICloudData) != 0),
                           @"clearSafariSharedWebData": @((clearOptions & PXClearOptionSafariSharedWebData) != 0),
                           @"clearMailSharedStore": @((clearOptions & PXClearOptionMailSharedStore) != 0) });

    __block BOOL completionCalled = NO;
    __block dispatch_semaphore_t completionLock = dispatch_semaphore_create(1);
    FreezeManager *freezer = [FreezeManager sharedManager];
    operationContext.wasFrozenBeforeOperation = [freezer isApplicationFrozen:bundleID];
    __weak typeof(self) weakSelf = self;
    __block UIBackgroundTaskIdentifier bgTask = UIBackgroundTaskInvalid;
    dispatch_async(dispatch_get_main_queue(), ^{
        bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"AppDataCleaner"
                                                              expirationHandler:^{
            [operationContext requestCancellationWithReason:@"background-expiration"];
        }];
    });
    __block dispatch_source_t watchdogTimer = nil;

    void (^safeCompletion)(BOOL, NSError *) = ^(BOOL success, NSError *error) {
        dispatch_semaphore_wait(completionLock, DISPATCH_TIME_FOREVER);
        if (!completionCalled) {
            completionCalled = YES;
            dispatch_semaphore_signal(completionLock);
            if (operationContext.ownsFreezeLease) {
                @try { [freezer unfreezeApplication:bundleID]; }
                @catch (__unused NSException *exception) {}
                operationContext.ownsFreezeLease = NO;
            }
            if (watchdogTimer) {
                dispatch_source_cancel(watchdogTimer);
                watchdogTimer = nil;
            }
            if (bgTask != UIBackgroundTaskInvalid) {
                UIBackgroundTaskIdentifier taskToEnd = bgTask;
                bgTask = UIBackgroundTaskInvalid;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] endBackgroundTask:taskToEnd];
                });
            }
            [PXDataContainerResolver invalidateCachedContainerForIdentifier:bundleID];
            [weakSelf logMessage:@"[AppDataCleaner][metric] mode=%@ total_ms=%.0f success=%d",
                PXClearModeName(mode),
                (CFAbsoluteTimeGetCurrent() - requestStartedAt) * 1000.0,
                success];
            {
                // 7.4: per-run granular metrics computed as deltas from the pre-run snapshot.
                uint_fast64_t pxShellProcesses = atomic_load(&gPXClearShellProcessCount) - pxMetricShellAtStart;
                uint_fast64_t pxPathsScanned = atomic_load(&gPXClearPathsScannedCount) - pxMetricPathsAtStart;
                double pxSqliteMs = (double)(atomic_load(&gPXClearSqliteNanos) - pxMetricSqliteNanosAtStart) / 1e6;
                NSUserDefaults *pxMetricStore = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
                NSUInteger pxTotalAttempts = 0;
                NSUInteger pxFirstAttemptSuccesses = 0;
                if (pxMetricStore) {
                    pxTotalAttempts = (NSUInteger)[pxMetricStore integerForKey:@"clearAttemptCount"] + 1;
                    pxFirstAttemptSuccesses = (NSUInteger)[pxMetricStore integerForKey:@"clearFirstAttemptSuccessCount"];
                    if (success && pxTimeoutFallbackCount == 0) {
                        pxFirstAttemptSuccesses += 1;
                    }
                    [pxMetricStore setInteger:(NSInteger)pxTotalAttempts forKey:@"clearAttemptCount"];
                    [pxMetricStore setInteger:(NSInteger)pxFirstAttemptSuccesses forKey:@"clearFirstAttemptSuccessCount"];
                }
                double pxFirstAttemptSuccessPct = pxTotalAttempts > 0 ? ((double)pxFirstAttemptSuccesses / (double)pxTotalAttempts) * 100.0 : 0.0;
                [weakSelf logMessage:@"[AppDataCleaner][metric] mode=%@ resolve_container_ms=%.0f sqlite_ms=%.0f shell_processes=%llu paths_scanned=%llu timeout_fallback_count=%llu first_attempt_success=%d first_attempt_success_pct=%.1f",
                    PXClearModeName(mode),
                    pxResolveContainerMs,
                    pxSqliteMs,
                    (unsigned long long)pxShellProcesses,
                    (unsigned long long)pxPathsScanned,
                    (unsigned long long)pxTimeoutFallbackCount,
                    (success && pxTimeoutFallbackCount == 0),
                    pxFirstAttemptSuccessPct];
            }
            [weakSelf logMessage:@"[AppDataCleaner] Calling completion handler (success=%d)", success];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(success, error);
            });
        } else {
            dispatch_semaphore_signal(completionLock);
        }
    };

    BOOL isSystemApp = [bundleID hasPrefix:@"com.apple."];
    int timeoutSec = (deepClean || isSystemApp) ? (30 * 60)
        : (mode == PXClearModeQuick ? 90 : 300);
    [operationContext beginWithTimeout:(NSTimeInterval)timeoutSec];
    watchdogTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    dispatch_source_set_timer(watchdogTimer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)timeoutSec * NSEC_PER_SEC),
                              DISPATCH_TIME_FOREVER,
                              1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(watchdogTimer, ^{
        dispatch_semaphore_wait(completionLock, DISPATCH_TIME_FOREVER);
        BOOL alreadyCompleted = completionCalled;
        dispatch_semaphore_signal(completionLock);
        if (alreadyCompleted) return;
        pxTimeoutFallbackCount += 1;
        operationContext.timeoutFallbackCount += 1;
        [operationContext requestCancellationWithReason:@"deadline"];
        [weakSelf logMessage:@"[AppDataCleaner][metric] timeout_fallback event=watchdog timeout_sec=%d operation=%@",
            timeoutSec, operationContext.operationID];
        [weakSelf logMessage:@"[AppDataCleaner] WATCHDOG: cancellation requested after %d seconds; waiting for worker quiescence", timeoutSec];
    });
    dispatch_resume(watchdogTimer);

    dispatch_async(PXClearCoordinatorQueue(), ^{
        @autoreleasepool {
            PXSetCurrentClearOperationContext(operationContext);
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf logMessage:@"[AppDataCleaner] Serialized cleaning started operation=%@ bundle=%@", operationContext.operationID, bundleID];
            @try {
                if ([operationContext isCancellationRequested]) {
                    safeCompletion(NO, PXClearOperationCancellationError(operationContext));
                    PXSetCurrentClearOperationContext(nil);
                    return;
                }
                CFAbsoluteTime pxResolveStartedAt = CFAbsoluteTimeGetCurrent();
                NSString *pxResolvedDataUUID = [strongSelf findDataContainerUUIDForBundleID:bundleID];
                pxResolveContainerMs = (CFAbsoluteTimeGetCurrent() - pxResolveStartedAt) * 1000.0;
                [strongSelf logMessage:@"[AppDataCleaner][metric] step=resolve_container duration_ms=%.0f found=%d",
                    pxResolveContainerMs, (pxResolvedDataUUID.length > 0)];
                CFAbsoluteTime killStartedAt = CFAbsoluteTimeGetCurrent();
                [strongSelf logMessage:@"[AppDataCleaner] Step 0: Kill application (mode=%@)...", PXClearModeName(mode)];
                PXKillAppProcessBestEffort(strongSelf, bundleID);
                [NSThread sleepForTimeInterval:(mode == PXClearModeQuick ? 0.1 : 0.5)];
                [strongSelf logMessage:@"[AppDataCleaner][metric] step=kill duration_ms=%.0f",
                    (CFAbsoluteTimeGetCurrent() - killStartedAt) * 1000.0];
                if ([operationContext isCancellationRequested]) {
                    safeCompletion(NO, PXClearOperationCancellationError(operationContext));
                    return;
                }
                CFAbsoluteTime keychainStartedAt = CFAbsoluteTimeGetCurrent();
                [strongSelf logMessage:@"[AppDataCleaner] Step 1: Planning and running single Keychain pass..."];
                PXKeychainClearPlan *keychainPlan =
                    [strongSelf _keychainClearPlanForBundleIdentifier:fullRequest.bundleIdentifier];
                operationContext.keychainPlanSnapshot = keychainPlan;
                NSMutableArray<NSNumber *> *keychainPassResults = [NSMutableArray array];
                if (keychainPlan.planningFailureCode == 0 &&
                    keychainPlan.skipDetail.length == 0 &&
                    keychainPlan.plannedPassCount > 0) {
                    NSError *initialPassError = nil;
                    BOOL initialPassSucceeded = [strongSelf
                        _executeKeychainWipeForBundleIdentifier:keychainPlan.bundleIdentifier
                                                selectedGroups:keychainPlan.selectedGroups
                                         applicationIdentifier:keychainPlan.applicationIdentifier
                                            systemApplication:keychainPlan.systemApplication
                                                        error:&initialPassError];
                    [keychainPassResults addObject:@(initialPassSucceeded)];
                    if (!initialPassSucceeded) {
                        [strongSelf logMessage:@"[AppDataCleaner] Initial Keychain pass failed (%@:%ld)",
                            initialPassError.domain ?: PXKeychainClearFailureDomain,
                            (long)initialPassError.code];
                    }
                }

                [strongSelf logMessage:@"[AppDataCleaner][metric] step=keychain duration_ms=%.0f passes=%lu",
                    (CFAbsoluteTimeGetCurrent() - keychainStartedAt) * 1000.0,
                    (unsigned long)keychainPassResults.count];
                if ([operationContext isCancellationRequested]) {
                    safeCompletion(NO, PXClearOperationCancellationError(operationContext));
                    return;
                }

                if (mode != PXClearModeQuick) {
                    [strongSelf logMessage:@"[AppDataCleaner] URL credential cleanup skipped (ownership boundary)"];
                }
                [strongSelf logMessage:@"[AppDataCleaner] Step 3: Clearing exact app state files..."];
                [strongSelf _internalClearAppStateData:bundleID];

                if (!operationContext.wasFrozenBeforeOperation) {
                    [strongSelf logMessage:@"[AppDataCleaner] Freezing app launch to prevent relaunch during wipe..."];
                    @try { [freezer freezeApplication:bundleID]; }
                    @catch (__unused NSException *exception) {}
                    operationContext.ownsFreezeLease = [freezer isApplicationFrozen:bundleID];
                }
                if ([operationContext isCancellationRequested]) {
                    safeCompletion(NO, PXClearOperationCancellationError(operationContext));
                    return;
                }

                CFAbsoluteTime dataStartedAt = CFAbsoluteTimeGetCurrent();
                [strongSelf logMessage:@"[AppDataCleaner] Step 4: Running canonical data aggregate..."];
                PXClearResult *dataResult = [strongSelf _completeDataWipeForMigratedRequest:dataRequest];
                NSArray<PXClearComponentResult *> *dataComponents = nil;
                if (PXMigratedDataClearResultIsStructurallyValid(dataResult)) {
                    dataComponents = dataResult.componentResults;
                } else {
                    pxTimeoutFallbackCount += 1;
                    [strongSelf logMessage:@"[AppDataCleaner] Four-scope data aggregate is structurally invalid"];
                    dataComponents = @[
                        PXApplicationDataFailedComponent(
                            PXApplicationDataClearFailureCodeInternalResultFailure,
                            @"ApplicationData aggregate result was invalid"),
                        PXExactDataFailedComponent(
                            PXClearScopeExtensionData,
                            PXExactDataClearFailureCodeInternalResultFailure,
                            @"ExtensionData aggregate result was invalid"),
                        PXAppGroupsFailedComponent(
                            PXAppGroupsClearFailureCodeInternalResultFailure,
                            @"AppGroups aggregate result was invalid"),
                        PXExactDataFailedComponent(
                            PXClearScopePluginKitData,
                            PXExactDataClearFailureCodeInternalResultFailure,
                            @"PluginKitData aggregate result was invalid")
                    ];
                }

                [strongSelf logMessage:@"[AppDataCleaner][metric] step=data_aggregate duration_ms=%.0f",
                    (CFAbsoluteTimeGetCurrent() - dataStartedAt) * 1000.0];
                if ([operationContext isCancellationRequested]) {
                    safeCompletion(NO, PXClearOperationCancellationError(operationContext));
                    return;
                }
                // The target application's container cleanup owns its cookies.
                // Never delete this process's global in-memory cookie jar.

                PXClearComponentResult *keychainComponent =
                    [strongSelf _keychainComponentForPlan:keychainPlan passResults:keychainPassResults];
                if (!PXKeychainComponentResultIsStructurallyValid(keychainComponent)) {
                    PXClearFailure *failure = PXKeychainFailure(
                        PXKeychainClearFailureCodeInternalResultFailure,
                        @"Keychain component result was invalid");
                    keychainComponent = [[PXClearComponentResult alloc]
                        initWithScope:PXClearScopeKeychain
                               status:PXClearComponentStatusFailed
                   attemptedUnitCount:1
                   succeededUnitCount:0
                      failedUnitCount:1
                               detail:PXKeychainFailureDetail
                              failure:failure];
                }

                // CLEAR-07/08: no process-wide sync and no redundant broad scan
                // for Quick/Full. Exact component postconditions are the manifest.
                NSMutableArray<PXClearComponentResult *> *fullComponents =
                    [NSMutableArray arrayWithArray:dataComponents ?: @[]];
                [fullComponents addObject:keychainComponent];
                PXClearResult *fullResult = [[PXClearResult alloc] initWithRequest:fullRequest
                                                                  componentResults:fullComponents];
                if (!PXMigratedFullClearResultIsStructurallyValid(fullResult)) {
                    [strongSelf logMessage:@"[AppDataCleaner] Final five-scope aggregate is structurally invalid"];
                    safeCompletion(NO, PXMigratedInternalError(@"Full Clear returned an invalid aggregate result"));
                    return;
                }

                CFAbsoluteTime verificationStartedAt = CFAbsoluteTimeGetCurrent();
                BOOL manifestVerified = YES; // structural validation + exact component postconditions
                if (PXClearModeIncludesDeepDiagnostics(mode)) {
                    manifestVerified = [strongSelf verifyDataCleared:bundleID];
                    if (!manifestVerified) {
                        [strongSelf logMessage:@"[AppDataCleaner] Deep residual scan reported remaining data"];
                    }
                }
                [strongSelf logMessage:@"[AppDataCleaner][metric] step=verification duration_ms=%.0f strategy=%@ passed=%d",
                    (CFAbsoluteTimeGetCurrent() - verificationStartedAt) * 1000.0,
                    PXClearModeIncludesDeepDiagnostics(mode) ? @"deep_residual_scan" : @"component_manifest",
                    manifestVerified];

                NSError *callbackError = nil;
                NSArray<NSNumber *> *failurePrecedence = @[
                    @(PXClearScopeApplicationData),
                    @(PXClearScopeExtensionData),
                    @(PXClearScopeAppGroups),
                    @(PXClearScopePluginKitData),
                    @(PXClearScopeKeychain)
                ];
                for (NSNumber *scopeNumber in failurePrecedence) {
                    PXClearScope scope = (PXClearScope)scopeNumber.unsignedIntegerValue;
                    PXClearComponentResult *component = [fullResult componentResultForScope:scope];
                    [strongSelf logMessage:@"[AppDataCleaner] %@ result %@ attempted=%lu succeeded=%lu failed=%lu",
                        PXMigratedComponentName(scope),
                        PXApplicationDataStatusName(component.status),
                        (unsigned long)component.attemptedUnitCount,
                        (unsigned long)component.succeededUnitCount,
                        (unsigned long)component.failedUnitCount];
                    if (component.status == PXClearComponentStatusFailed) {
                        NSError *componentError = PXMigratedNSErrorForFailure(component.failure);
                        [strongSelf logMessage:@"[AppDataCleaner] %@ failed (%@:%ld)",
                            PXMigratedComponentName(scope),
                            componentError.domain,
                            (long)componentError.code];
                        if (!callbackError) callbackError = componentError;
                    }
                }

                [strongSelf logMessage:@"[AppDataCleaner] === COMPLETED data clearing for %@ ===", bundleID];
                safeCompletion(callbackError == nil, callbackError);
            } @catch (NSException *exception) {
                [strongSelf logMessage:@"[AppDataCleaner] EXCEPTION: %@", exception];
                safeCompletion(NO, [NSError errorWithDomain:@"AppDataCleaner"
                                                      code:-1
                                                  userInfo:@{NSLocalizedDescriptionKey:
                                                                 exception.reason ?: @"Unknown error"}]);
            } @finally {
                PXSetCurrentClearOperationContext(nil);
            }
        }
    });

    [self logMessage:@"[AppDataCleaner] clearDataForBundleID returned immediately"];
}

#pragma mark - Improved Rootless-Compatible App Data Wiping

- (void)completeAppDataWipe:(NSString *)bundleID {
    dispatch_sync(PXClearCoordinatorQueue(), ^{
        @autoreleasepool {
            BOOL deepClean = [self _deepCleanEnabled];
            PXClearMode mode = deepClean ? PXClearModeDeep : PXClearModeFull;
            PXClearOptions clearOptions = PXClearOptionNone;
            if (PXReadSecurityBool(@"clearICloudDataEnabled", NO)) {
                clearOptions |= PXClearOptionICloudData;
            }
            if (PXReadSecurityBool(@"clearSafariSharedWebDataEnabled", NO)) {
                clearOptions |= PXClearOptionSafariSharedWebData;
            }
            if (PXReadSecurityBool(@"clearMailSharedStoreEnabled", NO)) {
                clearOptions |= PXClearOptionMailSharedStore;
            }
            PXClearRequest *request = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                                scopes:PXMigratedDataClearScopes
                                                                                  mode:mode
                                                                               options:clearOptions];
            PXClearResult *result = request ? [self _completeDataWipeForMigratedRequest:request] : nil;
            if (!PXMigratedDataClearResultIsStructurallyValid(result)) {
                [self logMessage:@"[AppDataCleaner] completeAppDataWipe produced an invalid migrated aggregate"];
                return;
            }

            for (PXClearComponentResult *component in result.componentResults) {
                NSString *componentName = PXMigratedComponentName(component.scope);
                [self logMessage:@"[AppDataCleaner] completeAppDataWipe %@ status=%@ attempted=%lu succeeded=%lu failed=%lu",
                      componentName,
                      PXApplicationDataStatusName(component.status),
                      (unsigned long)component.attemptedUnitCount,
                      (unsigned long)component.succeededUnitCount,
                      (unsigned long)component.failedUnitCount];
            }
        }
    });
}

- (PXClearComponentResult *)_completeAppDataWipeForApplicationDataRequest:(PXClearRequest *)request {
    if (![request isKindOfClass:[PXClearRequest class]] ||
        request.scopes != PXClearScopeApplicationData) {
        return PXApplicationDataFailedComponent(PXApplicationDataClearFailureCodeInvalidRequest,
                                                @"Invalid application-data clear request");
    }

    NSString *bundleID = request.bundleIdentifier;
    [self logMessage:@"[AppDataCleaner] Starting complete wipe for %@", bundleID];

    BOOL isSystemApp = [bundleID hasPrefix:@"com.apple."];
    int rmTimeout = (request.deepClean || isSystemApp) ? (15 * 60) : (5 * 60);

    PXDataContainerResolver *resolver = [[PXDataContainerResolver alloc] init];
    PXDestructivePathValidator *validator = [[PXDestructivePathValidator alloc] init];
    NSArray<NSNumber *> *roots = @[@(PXResolvedContainerRootRootful), @(PXResolvedContainerRootRootless)];
    NSMutableArray<NSString *> *canonicalApplicationDataPaths = [NSMutableArray arrayWithCapacity:2];
    NSMutableArray<NSDictionary *> *successfulApplicationDataRoots = [NSMutableArray arrayWithCapacity:2];
    NSMutableArray<NSString *> *rootSummaries = [@[@"rootful: absent", @"rootless: absent"] mutableCopy];
    NSUInteger attemptedUnits = 0;
    NSUInteger succeededUnits = 0;
    NSUInteger failedUnits = 0;
    PXClearFailure *firstFailure = nil;

    for (NSUInteger rootIndex = 0; rootIndex < roots.count; rootIndex++) {
        PXResolvedContainerRoot root = (PXResolvedContainerRoot)[roots[rootIndex] unsignedIntegerValue];
        NSString *rootLabel = rootIndex == 0 ? @"rootful" : @"rootless";
        NSError *resolutionError = nil;
        PXResolvedContainer *container = [resolver resolveApplicationDataContainerForIdentifier:request.bundleIdentifier
                                                                                            root:root
                                                                                           error:&resolutionError];
        if (!container) {
            if (!resolutionError) {
                rootSummaries[rootIndex] = [NSString stringWithFormat:@"%@: absent", rootLabel];
                continue;
            }
            attemptedUnits++;
            failedUnits++;
            rootSummaries[rootIndex] = [NSString stringWithFormat:@"%@: resolution failed", rootLabel];
            if (!firstFailure) {
                firstFailure = PXApplicationDataFailure(PXApplicationDataClearFailureCodeResolutionFailed,
                                                        rootIndex == 0
                                                            ? @"Rootful application-data resolution failed"
                                                            : @"Rootless application-data resolution failed");
            }
            [self logMessage:@"[AppDataCleaner] ApplicationData %@ resolution failed (%@:%ld)",
                  rootLabel, resolutionError.domain ?: @"unknown", (long)resolutionError.code];
            continue;
        }

        attemptedUnits++;
        NSError *validationError = nil;
        NSString *canonicalPath = [validator validatedCanonicalPathForContainer:container error:&validationError];
        if (canonicalPath.length == 0) {
            failedUnits++;
            NSInteger validatorCode = validationError ? validationError.code : 0;
            NSString *validatorDescription = validationError.localizedDescription.length
                ? validationError.localizedDescription
                : @"Unknown validator failure";
            rootSummaries[rootIndex] = [NSString stringWithFormat:@"%@: validation failed (%ld)",
                                                                  rootLabel,
                                                                  (long)validatorCode];
            if (!firstFailure) {
                NSString *rootName = rootIndex == 0 ? @"Rootful" : @"Rootless";
                NSString *failureMessage = [NSString stringWithFormat:
                    @"%@ application-data validation failed (validator=%ld): %@",
                    rootName,
                    (long)validatorCode,
                    validatorDescription];
                firstFailure = PXApplicationDataFailure(PXApplicationDataClearFailureCodeValidationFailed,
                                                        failureMessage);
            }
            [self logMessage:@"[AppDataCleaner] ApplicationData %@ validation failed (%@:%ld): %@",
                  rootLabel,
                  validationError.domain ?: @"unknown",
                  (long)validatorCode,
                  validatorDescription];
            continue;
        }

        // Validation is immediately followed by script construction and one bounded command for this root.
        NSString *wipeCommand = PXShellValidatedApplicationDataWipe(canonicalPath);
        CommandResult *commandResult = [self runCommandWithPrivilegesResult:wipeCommand
                                                                  timeoutSec:(NSTimeInterval)rmTimeout];
        [canonicalApplicationDataPaths addObject:[canonicalPath copy]];
        if (!PXApplicationDataCommandResultSucceeded(commandResult)) {
            failedUnits++;
            rootSummaries[rootIndex] = [NSString stringWithFormat:@"%@: execution failed", rootLabel];
            if (!firstFailure) {
                firstFailure = PXApplicationDataFailure(PXApplicationDataClearFailureCodeExecutionFailed,
                                                        rootIndex == 0
                                                            ? @"Rootful application-data execution failed"
                                                            : @"Rootless application-data execution failed");
            }
            [self logMessage:@"[AppDataCleaner] ApplicationData %@ command failed spawn=%d runner=%d timeout=%d normal=%d exit=%d signal=%d stdoutTruncated=%d stderrTruncated=%d",
                  rootLabel,
                  commandResult ? commandResult.spawnError : EINVAL,
                  commandResult ? commandResult.runnerError : EINVAL,
                  commandResult ? commandResult.timedOut : NO,
                  commandResult ? commandResult.exitedNormally : NO,
                  commandResult ? commandResult.exitCode : -1,
                  commandResult ? commandResult.terminationSignal : 0,
                  commandResult ? commandResult.stdoutTruncated : NO,
                  commandResult ? commandResult.stderrTruncated : NO];
            continue;
        }

        NSError *postValidationError = nil;
        NSString *postCanonicalPath = [validator validatedCanonicalPathForContainer:container
                                                                               error:&postValidationError];
        if (postCanonicalPath.length == 0 || ![postCanonicalPath isEqualToString:canonicalPath]) {
            failedUnits++;
            rootSummaries[rootIndex] = [NSString stringWithFormat:@"%@: post-command validation failed", rootLabel];
            if (!firstFailure) {
                firstFailure = PXApplicationDataFailure(PXApplicationDataClearFailureCodeValidationFailed,
                                                        rootIndex == 0
                                                            ? @"Rootful application-data post-command validation failed"
                                                            : @"Rootless application-data post-command validation failed");
            }
            [self logMessage:@"[AppDataCleaner] ApplicationData %@ post-command validation failed or canonical identity changed (%@:%ld)",
                  rootLabel, postValidationError.domain ?: @"unknown", (long)postValidationError.code];
            continue;
        }

        NSError *postconditionError = nil;
        if (!PXApplicationDataPostconditionIsValid(postCanonicalPath, &postconditionError)) {
            failedUnits++;
            rootSummaries[rootIndex] = [NSString stringWithFormat:@"%@: postcondition failed", rootLabel];
            if (!firstFailure) {
                firstFailure = PXApplicationDataFailure(PXApplicationDataClearFailureCodePostconditionFailed,
                                                        rootIndex == 0
                                                            ? @"Rootful application-data postcondition failed"
                                                            : @"Rootless application-data postcondition failed");
            }
            [self logMessage:@"[AppDataCleaner] ApplicationData %@ postcondition failed (%@:%ld)",
                  rootLabel, postconditionError.domain ?: @"unknown", (long)postconditionError.code];
            continue;
        }

        succeededUnits++;
        rootSummaries[rootIndex] = [NSString stringWithFormat:@"%@: succeeded", rootLabel];
        [successfulApplicationDataRoots addObject:@{ @"path": [canonicalPath copy], @"index": @(rootIndex) }];
    }

    // Cache canonical paths in rootful/rootless order; canonical Clear owns them per operation.
    PXClearOperationContext *operationContext = PXCurrentClearOperationContext();
    if (operationContext) {
        operationContext.applicationDataCanonicalPaths = [canonicalApplicationDataPaths copy] ?: @[];
    } else {
        _wipeCacheBundleID = [bundleID copy];
        _wipeCacheApplicationDataCanonicalPaths = [canonicalApplicationDataPaths copy] ?: @[];
    }

    [self logMessage:@"[AppDataCleaner] ApplicationData roots attempted=%lu succeeded=%lu failed=%lu",
          (unsigned long)attemptedUnits,
          (unsigned long)succeededUnits,
          (unsigned long)failedUnits];

    // Clear App Store receipt
    [self clearAppReceiptData:bundleID withBundleUUID:nil];
    
    // MobileMail shared Mail store is system-scoped and requires an explicit immutable policy.
    if (request.mode == PXClearModeDeep && [bundleID isEqualToString:@"com.apple.mobilemail"]) {
        if ((request.options & PXClearOptionMailSharedStore) != 0) {
            [self logMessage:@"[AppDataCleaner] Clear Mail Shared Store policy ON; wiping shared MobileMail store/prefs"];
            [self _wipeMobileMailSharedStoreForRequest:request];
        } else {
            [self logMessage:@"[AppDataCleaner] Clear Mail Shared Store policy OFF; shared /var/mobile/Library/Mail preserved"];
        }

        // Accounts3 remains a separate shared system account database. Keep mutation blocked
        // regardless of the Mail shared-store option; only emit read-only diagnostics.
        [self logMessage:@"[AppDataCleaner] MobileMail: Accounts3 destructive cleanup BLOCKED (shared account ownership policy)"];
        PXSQLiteLogMailAccountsDiagnostic(self, @"/var/mobile/Library/Accounts/Accounts3.sqlite");
    }
    
    // Clear preferences and cookies only (SAFE paths, no SpringBoard state!) — one shell for all paths.
    [self logMessage:@"[AppDataCleaner] Clearing preferences and cookies (batched shell)"];
    NSString *bEsc = [bundleID stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
    [self runCommandWithPrivileges:[NSString stringWithFormat:
        @"rm -f '/var/mobile/Library/Preferences/%@.plist' 2>/dev/null || true; "
        @"rm -rf '/var/mobile/Library/Caches/%@' 2>/dev/null || true; "
        @"rm -f '/var/mobile/Library/Cookies/%@.binarycookies' 2>/dev/null || true; "
        @"rm -rf '/var/mobile/Library/Caches/%@' 2>/dev/null || true; "
        @"rm -rf '/var/mobile/Library/Preferences/%@.plist' 2>/dev/null || true; "
        @"rm -rf '/var/root/Library/Preferences/%@.plist' 2>/dev/null || true; "
        @"rm -rf '/private/var/mobile/Library/Preferences/%@.plist' 2>/dev/null || true",
        bEsc, bEsc, bEsc, bEsc, bEsc, bEsc, bEsc] timeoutSec:120];
    
    // NOTE: Removed SpringBoard/ApplicationState deletion - it causes RESPRING!
    // NOTE: Removed PluginKit clearing - it uses slow findPathsMatchingPattern
    
    // Keychain wipe is handled by clearDataForBundleID using selected groups.
    // Avoid running legacy heuristic wipes here.
    
    // Skip RootHide var data clearing - uses slow findPathsMatchingPattern
    [self logMessage:@"[AppDataCleaner] Skipping RootHide cleaning (optimization)"];

    // Optional iCloud/Accounts policy is immutable for this Clear request.
    if (PXClearModeIncludesExtendedContainers(request.mode) &&
        ((request.options & PXClearOptionICloudData) != 0)) {
        [self logMessage:@"[AppDataCleaner] Clearing exact-authorized iCloud/Accounts data"];
        CFAbsoluteTime t0 = CFAbsoluteTimeGetCurrent();
        [self _clearAuthorizedICloudDataForRequest:request];
        [self logMessage:@"[AppDataCleaner] exact iCloud/Accounts cleanup took %.2fs", CFAbsoluteTimeGetCurrent() - t0];
    } else if (PXClearModeIncludesExtendedContainers(request.mode)) {
        [self logMessage:@"[AppDataCleaner] Clear iCloud Data policy OFF; skipping iCloud/Accounts cleanup"];
    }
    
    // Clear app state data - SKIP second call to avoid respring
    // [self _internalClearAppStateData:bundleID];
    
    // URL credentials are cleared by clearDataForBundleID.
    
    // Clear encrypted data 
    if (PXClearModeIncludesExtendedContainers(request.mode)) {
        [self logMessage:@"[AppDataCleaner] DEBUG: Clearing exact-boundary encrypted preferences..."];
        [self _internalClearEncryptedDataOutsideMainApplicationContainer:bundleID deepClean:request.deepClean];
        [self logMessage:@"[AppDataCleaner] Spotlight cleanup skipped (ownership boundary)"];
    }
    
    // Skip slow media/health/safari clearing for now
    [self logMessage:@"[AppDataCleaner] DEBUG: Skipping media/health/safari (optimization)"];
    // [self clearMediaData:bundleID];
    // [self clearHealthData:bundleID];

    // Shared Safari/WebKit/Cookie stores cross the normal per-app ownership boundary.
    // They require an explicit immutable policy in addition to Deep + MobileSafari.
    if (request.mode == PXClearModeDeep &&
        [bundleID isEqualToString:@"com.apple.mobilesafari"] &&
        ((request.options & PXClearOptionSafariSharedWebData) != 0)) {
        [self logMessage:@"[AppDataCleaner] Clear Safari Shared Web Data policy ON; wiping shared Safari/WebKit stores"];
        [self _wipeMobileSafariSystemStoresForRequest:request];
    } else if (request.mode == PXClearModeDeep && [bundleID isEqualToString:@"com.apple.mobilesafari"]) {
        [self logMessage:@"[AppDataCleaner] Clear Safari Shared Web Data policy OFF; shared Safari/WebKit stores preserved"];
    }
    // SiriAnalytics.db is shared system state. App ownership cannot be proven from
    // bundle/app/company-name substrings, so canonical Clear does not mutate it.
    if (request.mode == PXClearModeDeep) {
        [self logMessage:@"[AppDataCleaner] Siri analytics cleanup skipped (ownership boundary)"];
    }
    
    // Skip these - they modify system state and can cause respring:
    // [self cleanIconStatePlist:bundleID];
    // [self cleanLaunchServicesDatabase:bundleID];
    // Canonical Clear must not mutate global system state. Historically this
    // called refreshSystemServices, which dropped global VM caches, killed shared
    // daemons, and VACUUMed SpringBoard state unrelated to the selected app.
    [self logMessage:@"[AppDataCleaner] Global system refresh skipped (ownership boundary)"];
    
    // NOTE: Universal keychain wipe removed (too broad / can delete unrelated items).

    if (request.mode == PXClearModeDeep) {
        [self logMessage:@"[AppDataCleaner] CrashReporter cleanup skipped (ownership boundary)"];
    }

    // Main application-data final sweep is read-only and consumes this operation's canonical paths.
    NSArray<NSString *> *finalApplicationPaths = operationContext
        ? operationContext.applicationDataCanonicalPaths
        : (_wipeCacheApplicationDataCanonicalPaths ?: @[]);
    for (NSString *canonicalPath in finalApplicationPaths) {
        NSDictionary *successfulRoot = nil;
        for (NSDictionary *candidate in successfulApplicationDataRoots) {
            if ([candidate[@"path"] isEqualToString:canonicalPath]) {
                successfulRoot = candidate;
                break;
            }
        }

        NSError *finalPostconditionError = nil;
        if (!PXApplicationDataPostconditionIsValid(canonicalPath, &finalPostconditionError)) {
            if (!successfulRoot) {
                [self logMessage:@"[AppDataCleaner] ApplicationData final read-only verification remains failed for an already-failed root (%@:%ld)",
                      finalPostconditionError.domain ?: @"unknown",
                      (long)finalPostconditionError.code];
                continue;
            }

            NSUInteger rootIndex = [successfulRoot[@"index"] unsignedIntegerValue];
            if (succeededUnits > 0) succeededUnits--;
            failedUnits++;
            rootSummaries[rootIndex] = rootIndex == 0
                ? @"rootful: final read-only verification failed"
                : @"rootless: final read-only verification failed";
            if (!firstFailure) {
                firstFailure = PXApplicationDataFailure(PXApplicationDataClearFailureCodePostconditionFailed,
                                                        rootIndex == 0
                                                            ? @"Rootful application-data final verification failed"
                                                            : @"Rootless application-data final verification failed");
            }
            [self logMessage:@"[AppDataCleaner] ApplicationData %@ final read-only verification failed (%@:%ld)",
                  rootIndex == 0 ? @"rootful" : @"rootless",
                  finalPostconditionError.domain ?: @"unknown",
                  (long)finalPostconditionError.code];
        }
    }

    NSString *componentDetail = [rootSummaries componentsJoinedByString:@"; "];
    PXClearComponentResult *componentResult = nil;
    if (attemptedUnits == 0) {
        componentResult = [[PXClearComponentResult alloc] initWithScope:PXClearScopeApplicationData
                                                                 status:PXClearComponentStatusSkipped
                                                     attemptedUnitCount:0
                                                     succeededUnitCount:0
                                                        failedUnitCount:0
                                                                 detail:PXApplicationDataClearSkippedDetail
                                                                failure:nil];
    } else if (failedUnits > 0) {
        if (!firstFailure) {
            firstFailure = PXApplicationDataFailure(PXApplicationDataClearFailureCodeInternalResultFailure,
                                                    @"Application-data clear failed without a failure snapshot");
        }
        componentResult = [[PXClearComponentResult alloc] initWithScope:PXClearScopeApplicationData
                                                                 status:PXClearComponentStatusFailed
                                                     attemptedUnitCount:attemptedUnits
                                                     succeededUnitCount:succeededUnits
                                                        failedUnitCount:failedUnits
                                                                 detail:componentDetail
                                                                failure:firstFailure];
    } else {
        componentResult = [[PXClearComponentResult alloc] initWithScope:PXClearScopeApplicationData
                                                                 status:PXClearComponentStatusSucceeded
                                                     attemptedUnitCount:attemptedUnits
                                                     succeededUnitCount:succeededUnits
                                                        failedUnitCount:0
                                                                 detail:componentDetail
                                                                failure:nil];
    }

    if (!PXApplicationDataComponentResultIsStructurallyValid(componentResult)) {
        componentResult = PXApplicationDataFailedComponent(PXApplicationDataClearFailureCodeInternalResultFailure,
                                                           @"Application-data clear could not construct a valid component result");
    }
    NSLog(@"[AppDataCleaner] Completed wipe for %@", bundleID);
    return componentResult;
}

// FINAL SWEEP: Recursively remove all files/folders except .com.apple* or system files
- (void)finalSweepForContainer:(NSString *)containerPath {
    (void)containerPath;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// Remove crash logs and system logs for this bundleID
- (void)removeCrashLogsForBundleID:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}


// NEW: Method to clear app store receipt data
- (void)clearAppReceiptData:(NSString *)bundleID withBundleUUID:(NSString *)bundleUUID {
    (void)bundleUUID;
    NSLog(@"[AppDataCleaner] Skipping receipt mutation for %@ because the application bundle is read-only.",
          bundleID ?: @"(unknown)");
}

// NEW: Enhanced method to clear app group containers with better subfolder handling
- (void)clearAppGroupContainers:(NSString *)bundleID withGroupUUIDs:(NSArray *)groupUUIDs isRootless:(BOOL)isRootless {
    (void)bundleID;
    (void)groupUUIDs;
    (void)isRootless;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// Helper for app group cleaning with default rootless setting
- (void)clearAppGroupContainers:(NSString *)bundleID withGroupUUIDs:(NSArray *)groupUUIDs {
    (void)bundleID;
    (void)groupUUIDs;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// Compatibility helper: remove a path without permission or flag mutation.
- (void)fixPermissionsAndRemovePath:(NSString *)path {
    (void)path;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// Add the Spotlight indexes clearing method
- (void)clearSpotlightIndexes:(NSString *)bundleID {
    (void)bundleID;
    // Retained for public selector compatibility. CoreSpotlight domain identifiers and
    // filesystem cache names are not proven app-owned by a Clear request, so this path
    // deliberately performs no mutation.
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

#pragma mark - UUID Finding Methods

- (NSString *)findBundleUUID:(NSString *)bundleID {
    return [self findBundleContainerUUIDForBundleID:bundleID];
}

- (NSString *)findDataContainerUUID:(NSString *)bundleID aggressive:(BOOL)aggressive {
    (void)aggressive;
    if (!PXStrictBundleIdentifierIsValid(bundleID)) return nil;
    PXDataContainerResolver *resolver = [[PXDataContainerResolver alloc] init];
    NSError *error = nil;
    PXResolvedContainer *container =
        [resolver resolveApplicationDataContainerForIdentifier:bundleID
                                                          root:PXResolvedContainerRootRootful
                                                         error:&error];
    if (!container || error || !PXReadOnlyRealDirectoryAtPath(container.containerPath)) return nil;
    return container.containerUUID;
}

- (NSString *)findDataContainerUUID:(NSString *)bundleID {
    return [self findDataContainerUUID:bundleID aggressive:NO];
}

- (NSString *)findRootlessDataContainerUUID:(NSString *)bundleID aggressive:(BOOL)aggressive {
    (void)aggressive;
    if (!PXStrictBundleIdentifierIsValid(bundleID)) return nil;
    PXDataContainerResolver *resolver = [[PXDataContainerResolver alloc] init];
    NSError *error = nil;
    PXResolvedContainer *container =
        [resolver resolveApplicationDataContainerForIdentifier:bundleID
                                                          root:PXResolvedContainerRootRootless
                                                         error:&error];
    if (!container || error || !PXReadOnlyRealDirectoryAtPath(container.containerPath)) return nil;
    return container.containerUUID;
}

- (NSString *)findRootlessDataContainerUUID:(NSString *)bundleID {
    return [self findRootlessDataContainerUUID:bundleID aggressive:NO];
}

- (NSArray *)findAppGroupUUIDs:(NSString *)bundleID aggressive:(BOOL)aggressive {
    (void)aggressive;
    if (!PXStrictBundleIdentifierIsValid(bundleID)) return @[];
    return [self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:NO] ?: @[];
}

- (NSArray *)findAppGroupUUIDs:(NSString *)bundleID {
    return [self findAppGroupUUIDs:bundleID aggressive:NO];
}

- (NSArray *)findRootlessAppGroupUUIDs:(NSString *)bundleID {
    if (!PXStrictBundleIdentifierIsValid(bundleID)) return @[];
    return [self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:YES] ?: @[];
}

#pragma mark - Cleaning Methods

- (void)wipeDirectoryContents:(NSString *)path keepDirectoryStructure:(BOOL)keepStructure {
    (void)path;
    (void)keepStructure;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (BOOL)securelyWipeFile:(NSString *)path {
    (void)path;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return NO;
}

- (void)clearKeychainItemsForBundleID:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// Universal keychain wipe - very aggressive approach
- (void)universalKeychainWipeForBundleID:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)clearURLCredentialsForBundleID:(NSString *)bundleID {
    (void)bundleID;
    // Retained for public selector compatibility. Shared URL credential storage does not
    // expose an app-ownership key that can be proven from a target bundle identifier.
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)cleanRootHideVarData:(NSString *)bundleID {
    (void)bundleID;
    // RootHide compatibility cleanup historically used bundle-prefix wildcards across
    // shared mobile/root preferences, caches, WebKit, cookies and temporary directories.
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)clearPluginKitData:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)clearThumbnailCaches:(NSString *)bundleID {
    (void)bundleID;
    // ThumbnailServices/QuickLook caches are shared system stores; filename prefixes do
    // not prove ownership by the selected application.
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)_clearExactAccountsOwnedByBundleIdentifier:(NSString *)bundleID {
    if (!bundleID.length) return;
    if ([bundleID hasPrefix:@"com.apple."]) {
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup BLOCKED for system app; shared system-account policy required"];
        return;
    }

    PXClearOperationContext *operationContext = PXCurrentClearOperationContext();
    if (operationContext && [operationContext isCancellationRequested]) {
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup skipped: operation cancelled"];
        return;
    }
    int (^boundedSQLiteBusyTimeoutMs)(void) = ^int {
        if (!operationContext) return 3000;
        NSTimeInterval remaining = [operationContext remainingTime];
        if (remaining <= 0.0) return 0;
        double remainingMs = floor(remaining * 1000.0);
        return (int)MAX(1.0, MIN(3000.0, remainingMs));
    };

    NSString *accountsDBPath = PXFirstExistingPath(_fileManager, @[
        @"/var/mobile/Library/Accounts/Accounts3.sqlite",
        @"/private/var/mobile/Library/Accounts/Accounts3.sqlite"
    ]);
    if (!accountsDBPath.length) {
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup: database not found"];
        return;
    }

    NSArray<NSNumber *> *(^readPrimaryKeys)(sqlite3 *, BOOL, BOOL *) =
        ^NSArray<NSNumber *> *(sqlite3 *db, BOOL matchingOwner, BOOL *okOut) {
            if (okOut) *okOut = NO;
            const char *sql = matchingOwner
                ? "SELECT Z_PK FROM ZACCOUNT WHERE ZOWNINGBUNDLEID = ? ORDER BY Z_PK;"
                : "SELECT Z_PK FROM ZACCOUNT WHERE ZOWNINGBUNDLEID IS NULL OR ZOWNINGBUNDLEID <> ? ORDER BY Z_PK;";
            sqlite3_stmt *stmt = NULL;
            if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) != SQLITE_OK || !stmt) {
                if (stmt) sqlite3_finalize(stmt);
                return @[];
            }
            if (sqlite3_bind_text(stmt, 1, bundleID.UTF8String, -1, SQLITE_TRANSIENT) != SQLITE_OK) {
                sqlite3_finalize(stmt);
                return @[];
            }
            NSMutableArray<NSNumber *> *keys = [NSMutableArray array];
            int step = SQLITE_OK;
            while ((step = sqlite3_step(stmt)) == SQLITE_ROW) {
                [keys addObject:@(sqlite3_column_int64(stmt, 0))];
            }
            sqlite3_finalize(stmt);
            if (step != SQLITE_DONE) return @[];
            if (okOut) *okOut = YES;
            return [keys copy];
        };

    // Plan read-only first. accountsd is not disturbed unless exact ownership exists.
    sqlite3 *planDB = NULL;
    int planRC = sqlite3_open_v2(accountsDBPath.UTF8String, &planDB, SQLITE_OPEN_READONLY, NULL);
    if (planRC != SQLITE_OK || !planDB) {
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup: read-only open failed rc=%d", planRC];
        if (planDB) sqlite3_close(planDB);
        return;
    }
    int planBusyTimeoutMs = boundedSQLiteBusyTimeoutMs();
    if (planBusyTimeoutMs <= 0) { sqlite3_close(planDB); return; }
    sqlite3_busy_timeout(planDB, planBusyTimeoutMs);
    NSMutableDictionary<NSString *, NSSet<NSString *> *> *planColumns = [NSMutableDictionary dictionary];
    BOOL exactSchema = PXSQLiteTableHasColumnCached(planDB, @"ZACCOUNT", @"Z_PK", planColumns) &&
                       PXSQLiteTableHasColumnCached(planDB, @"ZACCOUNT", @"ZOWNINGBUNDLEID", planColumns);
    if (!exactSchema) {
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup: Z_PK/ZOWNINGBUNDLEID unavailable; fail closed"];
        sqlite3_close(planDB);
        return;
    }
    BOOL planReadOK = NO;
    NSArray<NSNumber *> *plannedTargets = readPrimaryKeys(planDB, YES, &planReadOK);
    sqlite3_close(planDB);
    if (!planReadOK) {
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup: ownership query failed; fail closed"];
        return;
    }
    if (plannedTargets.count == 0) {
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup: no rows exactly owned by target bundle"];
        return;
    }

    if (operationContext && [operationContext isCancellationRequested]) return;
    [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup: authorized target rows=%lu", (unsigned long)plannedTargets.count];
    PXKillallTermThenKill(@"accountsd", 0.2);
    if (operationContext && [operationContext isCancellationRequested]) return;

    sqlite3 *db = NULL;
    int rc = sqlite3_open_v2(accountsDBPath.UTF8String, &db, SQLITE_OPEN_READWRITE, NULL);
    if (rc != SQLITE_OK || !db) {
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup: read-write open failed rc=%d", rc];
        if (db) sqlite3_close(db);
        return;
    }
    int mutationBusyTimeoutMs = boundedSQLiteBusyTimeoutMs();
    if (mutationBusyTimeoutMs <= 0) { sqlite3_close(db); return; }
    sqlite3_busy_timeout(db, mutationBusyTimeoutMs);

    NSMutableDictionary<NSString *, NSSet<NSString *> *> *columns = [NSMutableDictionary dictionary];
    if (!PXSQLiteTableHasColumnCached(db, @"ZACCOUNT", @"Z_PK", columns) ||
        !PXSQLiteTableHasColumnCached(db, @"ZACCOUNT", @"ZOWNINGBUNDLEID", columns)) {
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup: schema changed before mutation; fail closed"];
        sqlite3_close(db);
        return;
    }

    NSString *transactionError = nil;
    if (!PXSQLiteExec(db, @"BEGIN IMMEDIATE;", &transactionError)) {
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup: BEGIN IMMEDIATE failed %@", transactionError ?: @""];
        sqlite3_close(db);
        return;
    }

    BOOL mutationOK = YES;
    BOOL readOK = NO;
    NSArray<NSNumber *> *targetsNow = readPrimaryKeys(db, YES, &readOK);
    NSSet<NSNumber *> *plannedSet = [NSSet setWithArray:plannedTargets];
    NSSet<NSNumber *> *targetSet = [NSSet setWithArray:targetsNow];
    if (!readOK || ![plannedSet isEqualToSet:targetSet]) {
        mutationOK = NO;
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup: target ownership changed before mutation; rolling back"];
    }

    BOOL unrelatedReadOK = NO;
    NSArray<NSNumber *> *unrelatedBefore = mutationOK ? readPrimaryKeys(db, NO, &unrelatedReadOK) : @[];
    if (mutationOK && !unrelatedReadOK) mutationOK = NO;
    NSSet<NSNumber *> *unrelatedBeforeSet = [NSSet setWithArray:unrelatedBefore];

    if (mutationOK && operationContext && [operationContext isCancellationRequested]) {
        mutationOK = NO;
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup: cancelled before mutation; rolling back"];
    }

    BOOL (^deleteCompanionOwner)(NSString *, sqlite3_int64) = ^BOOL(NSString *table, sqlite3_int64 ownerPK) {
        if (!PXSQLiteTableHasColumnCached(db, table, @"ZOWNER", columns)) return YES;
        if (!PXSQLiteIsSafeIdentifier(table)) return NO;
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE ZOWNER = ?;", table];
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(db, sql.UTF8String, -1, &stmt, NULL) != SQLITE_OK || !stmt) {
            if (stmt) sqlite3_finalize(stmt);
            return NO;
        }
        sqlite3_bind_int64(stmt, 1, ownerPK);
        int step = sqlite3_step(stmt);
        sqlite3_finalize(stmt);
        return step == SQLITE_DONE;
    };

    sqlite3_stmt *deleteAccount = NULL;
    if (mutationOK &&
        sqlite3_prepare_v2(db, "DELETE FROM ZACCOUNT WHERE Z_PK = ? AND ZOWNINGBUNDLEID = ?;", -1, &deleteAccount, NULL) != SQLITE_OK) {
        mutationOK = NO;
    }

    if (mutationOK) {
        for (NSNumber *pkNumber in plannedTargets) {
            if (operationContext && [operationContext isCancellationRequested]) {
                mutationOK = NO;
                [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup: cancelled during target mutation; rolling back"];
                break;
            }
            sqlite3_int64 pk = (sqlite3_int64)pkNumber.longLongValue;
            if (!deleteCompanionOwner(@"ZACCOUNTPROPERTY", pk) ||
                !deleteCompanionOwner(@"ZCREDENTIALITEM", pk)) {
                mutationOK = NO;
                break;
            }
            sqlite3_reset(deleteAccount);
            sqlite3_clear_bindings(deleteAccount);
            if (sqlite3_bind_int64(deleteAccount, 1, pk) != SQLITE_OK ||
                sqlite3_bind_text(deleteAccount, 2, bundleID.UTF8String, -1, SQLITE_TRANSIENT) != SQLITE_OK ||
                sqlite3_step(deleteAccount) != SQLITE_DONE ||
                sqlite3_changes(db) != 1) {
                mutationOK = NO;
                break;
            }
        }
    }
    if (deleteAccount) sqlite3_finalize(deleteAccount);

    BOOL targetAfterOK = NO;
    NSArray<NSNumber *> *targetsAfter = mutationOK ? readPrimaryKeys(db, YES, &targetAfterOK) : @[];
    if (mutationOK && (!targetAfterOK || targetsAfter.count != 0)) mutationOK = NO;

    BOOL unrelatedAfterOK = NO;
    NSArray<NSNumber *> *unrelatedAfter = mutationOK ? readPrimaryKeys(db, NO, &unrelatedAfterOK) : @[];
    NSSet<NSNumber *> *unrelatedAfterSet = [NSSet setWithArray:unrelatedAfter];
    if (mutationOK && (!unrelatedAfterOK || ![unrelatedBeforeSet isEqualToSet:unrelatedAfterSet])) {
        mutationOK = NO;
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup: unrelated account PK set changed; rolling back"];
    }

    if (mutationOK && operationContext && [operationContext isCancellationRequested]) {
        mutationOK = NO;
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup: cancelled before commit; rolling back"];
    }

    if (!mutationOK) {
        PXSQLiteExec(db, @"ROLLBACK;", NULL);
        sqlite3_close(db);
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup failed closed; no transaction committed"];
        return;
    }

    NSString *commitError = nil;
    if (!PXSQLiteExec(db, @"COMMIT;", &commitError)) {
        PXSQLiteExec(db, @"ROLLBACK;", NULL);
        sqlite3_close(db);
        [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup COMMIT failed %@", commitError ?: @""];
        return;
    }
    PXSQLiteExec(db, @"PRAGMA wal_checkpoint(TRUNCATE);", NULL);
    sqlite3_close(db);
    [self logMessage:@"[AppDataCleaner] Accounts3 exact cleanup committed rows=%lu", (unsigned long)plannedTargets.count];
}

- (void)_clearAuthorizedICloudDataForRequest:(PXClearRequest *)request {
    if (![request isKindOfClass:[PXClearRequest class]] ||
        !PXClearModeIncludesExtendedContainers(request.mode) ||
        ((request.options & PXClearOptionICloudData) == 0)) {
        [self logMessage:@"[AppDataCleaner] iCloud exact cleanup rejected: request is not authorized"];
        return;
    }

    NSString *bundleID = request.bundleIdentifier;
    if ([bundleID hasPrefix:@"com.apple."]) {
        [self logMessage:@"[AppDataCleaner] iCloud exact cleanup BLOCKED for system app; dedicated system-cloud policy required"];
        return;
    }
    PXClearOperationContext *operationContext = PXCurrentClearOperationContext();
    if (operationContext && [operationContext isCancellationRequested]) return;

    NSError *entitlementError = nil;
    NSDictionary *entitlements = [[[AppEntitlementsReader alloc] init] fullEntitlementsForBundleID:bundleID
                                                                                              error:&entitlementError];
    if (![entitlements isKindOfClass:[NSDictionary class]] || entitlementError) {
        [self logMessage:@"[AppDataCleaner] iCloud exact cleanup: signed entitlements unavailable; fail closed"];
        return;
    }

    NSArray<NSString *> *keys = @[
        @"com.apple.developer.ubiquity-container-identifiers",
        @"com.apple.developer.icloud-container-identifiers"
    ];
    NSMutableOrderedSet<NSString *> *containerIDs = [NSMutableOrderedSet orderedSet];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-_"];
    NSCharacterSet *disallowed = [allowed invertedSet];

    for (NSString *key in keys) {
        id raw = entitlements[key];
        if (!raw) continue;
        if (![raw isKindOfClass:[NSArray class]]) {
            [self logMessage:@"[AppDataCleaner] iCloud exact cleanup: entitlement %@ has unsupported shape; fail closed", key];
            return;
        }
        for (id value in (NSArray *)raw) {
            if (![value isKindOfClass:[NSString class]]) {
                [self logMessage:@"[AppDataCleaner] iCloud exact cleanup: non-string container entitlement; fail closed"];
                return;
            }
            NSString *identifier = (NSString *)value;
            BOOL valid = identifier.length > 0 && identifier.length <= 255 &&
                         [identifier rangeOfCharacterFromSet:disallowed].location == NSNotFound &&
                         [identifier rangeOfString:@".."].location == NSNotFound &&
                         ![identifier hasPrefix:@"."] && ![identifier hasSuffix:@"."];
            if (!valid) {
                [self logMessage:@"[AppDataCleaner] iCloud exact cleanup: invalid signed container identifier; fail closed"];
                return;
            }
            [containerIDs addObject:identifier];
        }
    }

    NSString *mobileDocuments = PXFirstExistingPath(_fileManager, @[
        @"/var/mobile/Library/Mobile Documents",
        @"/private/var/mobile/Library/Mobile Documents"
    ]);
    NSUInteger authorizedCount = 0;
    NSUInteger clearedCount = 0;
    NSUInteger skippedCount = 0;

    if (mobileDocuments.length && containerIDs.count) {
        NSString *resolvedBase = [mobileDocuments stringByResolvingSymlinksInPath];
        for (NSString *identifier in containerIDs.array) {
            if (operationContext && [operationContext isCancellationRequested]) break;
            // Only iCloud.* identifiers have a stable direct-child Mobile Documents mapping.
            if (![identifier hasPrefix:@"iCloud."]) {
                skippedCount++;
                continue;
            }
            authorizedCount++;
            NSString *directoryName = [identifier stringByReplacingOccurrencesOfString:@"." withString:@"~"];
            NSString *candidate = [mobileDocuments stringByAppendingPathComponent:directoryName];
            NSString *standardCandidate = [candidate stringByStandardizingPath];
            NSString *standardBase = [mobileDocuments stringByStandardizingPath];
            if (![[standardCandidate stringByDeletingLastPathComponent] isEqualToString:standardBase]) {
                skippedCount++;
                continue;
            }

            NSError *attributesError = nil;
            NSDictionary *attributes = [_fileManager attributesOfItemAtPath:candidate error:&attributesError];
            if (!attributes) {
                // Exact entitled container is simply not materialized on this device.
                skippedCount++;
                continue;
            }
            NSString *fileType = attributes[NSFileType];
            if (![fileType isEqualToString:NSFileTypeDirectory] || [fileType isEqualToString:NSFileTypeSymbolicLink]) {
                skippedCount++;
                continue;
            }
            NSString *resolvedCandidate = [candidate stringByResolvingSymlinksInPath];
            if (![[resolvedCandidate stringByDeletingLastPathComponent] isEqualToString:resolvedBase]) {
                skippedCount++;
                continue;
            }

            NSString *command = [NSString stringWithFormat:
                @"find %@ -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null",
                PXShellQuote(resolvedCandidate)];
            CommandResult *result = [self runCommandWithPrivilegesResult:command timeoutSec:120.0];
            if (result.isSucceeded) {
                clearedCount++;
            } else {
                skippedCount++;
                [self logMessage:@"[AppDataCleaner] iCloud exact container wipe failed exit=%d timeout=%d runnerError=%d",
                                 result.exitCode, result.timedOut, result.runnerError];
            }
        }
    }

    [self logMessage:@"[AppDataCleaner] iCloud exact authorization: signed=%lu mapped=%lu cleared=%lu skipped=%lu",
                     (unsigned long)containerIDs.count,
                     (unsigned long)authorizedCount,
                     (unsigned long)clearedCount,
                     (unsigned long)skippedCount];

    if (!(operationContext && [operationContext isCancellationRequested])) {
        [self _clearExactAccountsOwnedByBundleIdentifier:bundleID];
    }
}

- (void)clearICloudData:(NSString *)bundleID {
    // Public compatibility selector remains, but no longer re-reads mutable settings
    // or performs fuzzy deletion. Only an active immutable Clear request can authorize it.
    PXClearOperationContext *operationContext = PXCurrentClearOperationContext();
    PXClearRequest *request = operationContext.dataRequest;
    if (!request || ![request.bundleIdentifier isEqualToString:bundleID] ||
        ((request.options & PXClearOptionICloudData) == 0)) {
        [self logMessage:@"[AppDataCleaner] clearICloudData compatibility call blocked: no authorized request snapshot"];
        return;
    }
    [self _clearAuthorizedICloudDataForRequest:request];
}

- (void)fastWipeDirectoryContents:(NSString *)path keepDirectoryStructure:(BOOL)keepStructure timeoutSec:(int)timeoutSec {
    (void)path;
    (void)keepStructure;
    (void)timeoutSec;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)clearSystemLogs:(NSString *)bundleID {
    (void)bundleID;
    // CrashReporter/DiagnosticReports/ASL/system logs are shared diagnostic stores and
    // bundle-name wildcard matching is not an ownership boundary.
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

#pragma mark - Helper Methods

- (NSArray *)listDirectoriesInPath:(NSString *)path {
    (void)path;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return @[];
}

- (BOOL)directoryHasContent:(NSString *)path {
    (void)path;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return NO;
}

- (NSArray<NSString *> *)runBoundedFindWithArguments:(NSArray<NSString *> *)arguments {
    (void)arguments;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return @[];
}

- (NSArray *)findPathsMatchingPattern:(NSString *)pattern {
    (void)pattern;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return @[];
}

- (void)runCommandWithPrivileges:(NSString *)command {
    [self runCommandWithPrivileges:command timeoutSec:60];
}

/// Batch multiple shell snippets into a single `/bin/sh -c` spawn.
/// Same semantics as sequential `runCommandWithPrivileges:` (each piece still runs; failures are non-fatal via `|| true` in callers).
/// Cuts posix_spawn + shell startup cost that dominates Reset Data when many small `rm`/`mkdir`/`find` are issued.
- (void)runBatchedCommandsWithPrivileges:(NSArray<NSString *> *)commands timeoutSec:(int)timeoutSec {
    if (![commands isKindOfClass:[NSArray class]] || commands.count == 0) {
        return;
    }
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:commands.count];
    for (id c in commands) {
        if (![c isKindOfClass:[NSString class]]) continue;
        NSString *s = [(NSString *)c stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (s.length == 0) continue;
        [parts addObject:s];
    }
    if (parts.count == 0) return;
    if (parts.count == 1) {
        [self runCommandWithPrivileges:parts[0] timeoutSec:timeoutSec];
        return;
    }
    // Join with `;` so every step runs even if a prior command fails (matches prior independent spawns).
    NSString *batched = [parts componentsJoinedByString:@"; "];
    [self runCommandWithPrivileges:batched timeoutSec:timeoutSec];
}

// Legacy wildcard traversal helper retained only for source compatibility.
- (NSArray<NSString *> *)findPathsUnderRoot:(NSString *)root
                               directories:(BOOL)directories
                              namePatterns:(NSArray<NSString *> *)namePatterns {
    (void)root;
    (void)directories;
    (void)namePatterns;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return @[];
}

- (CommandResult *)runCommandWithPrivilegesResult:(NSString *)command
                                        timeoutSec:(NSTimeInterval)timeoutSec {
    if (![command isKindOfClass:[NSString class]] || command.length == 0 || !isfinite(timeoutSec)) {
        CommandResult *result = [[CommandResult alloc] init];
        result.runnerError = EINVAL;
        return result;
    }

    NSTimeInterval effectiveTimeout = timeoutSec <= 0 ? 60.0 : timeoutSec;
    PXClearOperationContext *operationContext = PXCurrentClearOperationContext();
    if (operationContext) {
        effectiveTimeout = [operationContext clampedTimeoutForStepLimit:effectiveTimeout];
        if (effectiveTimeout <= 0.0) {
            CommandResult *cancelled = [[CommandResult alloc] init];
            cancelled.runnerError = [[operationContext cancellationReason] isEqualToString:@"deadline"] ? ETIMEDOUT : ECANCELED;
            return cancelled;
        }
    }
    atomic_fetch_add(&gPXClearShellProcessCount, 1);
    return [[CommandRunner shared] runAndCapture:command
                                      timeoutSec:effectiveTimeout
                                  maxOutputBytes:PXPrivilegedCommandMaxOutputBytes];
}

- (void)runCommandWithPrivileges:(NSString *)command timeoutSec:(int)timeoutSec {
    CommandResult *result = [self runCommandWithPrivilegesResult:command
                                                       timeoutSec:(NSTimeInterval)timeoutSec];
    if (result.timedOut) {
        NSTimeInterval effectiveTimeout = timeoutSec <= 0 ? 60.0 : (NSTimeInterval)timeoutSec;
        NSString *shortCmd = [command isKindOfClass:[NSString class]] ? command : @"";
        if (shortCmd.length > 240) {
            shortCmd = [shortCmd substringToIndex:240];
        }
        NSLog(@"[AppDataCleaner] Command timed out after %.3f sec, killing: %@", effectiveTimeout, shortCmd);
    }
}

- (BOOL)verifyDataCleared:(NSString *)bundleID {
    NSLog(@"[AppDataCleaner] Verifying data cleared for %@", bundleID);
    
    // Create an array to store paths that weren't cleared properly
    NSMutableArray *unclearedPaths = [NSMutableArray array];
    NSMutableSet<NSString *> *verifiedPaths = [NSMutableSet set];

    // Main verification consumes only canonical validator outputs from this operation when available.
    PXClearOperationContext *operationContext = PXCurrentClearOperationContext();
    BOOL useOperationContext = operationContext != nil &&
        [operationContext.fullRequest.bundleIdentifier isEqualToString:bundleID];
    BOOL useWipeCache = !useOperationContext &&
        (_wipeCacheBundleID.length && bundleID.length && [_wipeCacheBundleID isEqualToString:bundleID]);
    NSArray<NSString *> *verificationApplicationPaths = useOperationContext
        ? operationContext.applicationDataCanonicalPaths : (_wipeCacheApplicationDataCanonicalPaths ?: @[]);
    NSArray<NSString *> *verificationAppGroupPaths = useOperationContext
        ? operationContext.appGroupCanonicalPaths : (_wipeCacheAppGroupCanonicalPaths ?: @[]);
    NSArray<NSString *> *verificationExtensionPaths = useOperationContext
        ? operationContext.extensionDataCanonicalPaths : (_wipeCacheExtensionDataCanonicalPaths ?: @[]);
    NSArray<NSString *> *verificationPluginKitPaths = useOperationContext
        ? operationContext.pluginKitDataCanonicalPaths : (_wipeCachePluginKitDataCanonicalPaths ?: @[]);

    // 1. Main-wipe verification uses canonical paths. Standalone verification uses exact read-only resolution.
    if (useOperationContext || useWipeCache) {
        for (NSString *canonicalPath in verificationApplicationPaths) {
            [self verifyClearedPath:canonicalPath reportingTo:unclearedPaths seen:verifiedPaths];
        }
    } else {
        for (NSString *exactPath in PXExactReadOnlyApplicationDataPathsForBundleID(bundleID)) {
            [self verifyClearedPath:exactPath reportingTo:unclearedPaths seen:verifiedPaths];
        }
        [self logMessage:@"[AppDataCleaner] Standalone verification used exact application-data resolution"];
    }
    
    // 2. Main-wipe App Group verification consumes canonical validator outputs directly.
    if (useOperationContext || useWipeCache) {
        for (NSString *canonicalPath in verificationAppGroupPaths) {
            [self verifyClearedPath:canonicalPath reportingTo:unclearedPaths seen:verifiedPaths];
        }
    } else {
        NSError *groupDiscoveryError = nil;
        NSArray<NSString *> *groupIdentifiers =
            [self _exactApplicationGroupIdentifiersForBundleIdentifier:bundleID error:&groupDiscoveryError];
        if (!groupIdentifiers && groupDiscoveryError) {
            [unclearedPaths addObject:@{ @"path": @"AppGroups",
                                         @"info": @"Exact App Group entitlement discovery failed" }];
        } else {
            AppGroupContainerResolver *groupResolver = [[AppGroupContainerResolver alloc] init];
            const PXResolvedContainerRoot roots[] = {
                PXResolvedContainerRootRootful,
                PXResolvedContainerRootRootless,
            };
            for (NSString *groupIdentifier in groupIdentifiers ?: @[]) {
                for (NSUInteger rootIndex = 0; rootIndex < sizeof(roots) / sizeof(roots[0]); rootIndex++) {
                    NSError *resolutionError = nil;
                    NSArray<PXResolvedContainer *> *resolved =
                        [groupResolver resolveAllAppGroupContainersForGroupIdentifier:groupIdentifier
                                                                                 root:roots[rootIndex]
                                                                                error:&resolutionError];
                    if (!resolved && resolutionError) {
                        [unclearedPaths addObject:@{ @"path": @"AppGroups",
                                                     @"info": @"Exact App Group resolution failed" }];
                        continue;
                    }
                    for (PXResolvedContainer *container in resolved ?: @[]) {
                        if (!PXReadOnlyRealDirectoryAtPath(container.containerPath)) {
                            [unclearedPaths addObject:@{ @"path": @"AppGroups",
                                                         @"info": @"Resolved App Group path failed read-only validation" }];
                            continue;
                        }
                        [self verifyClearedPath:[container.containerPath stringByStandardizingPath]
                                   reportingTo:unclearedPaths
                                          seen:verifiedPaths];
                    }
                }
            }
        }
        [self logMessage:@"[AppDataCleaner] Standalone verification used exact App Group resolution"];
    }
    
    // 3. Verify extension and PluginKit data containers.
    if (useOperationContext || useWipeCache) {
        for (NSString *canonicalPath in verificationExtensionPaths) {
            [self verifyClearedPath:canonicalPath reportingTo:unclearedPaths seen:verifiedPaths];
        }
        for (NSString *canonicalPath in verificationPluginKitPaths) {
            [self verifyClearedPath:canonicalPath reportingTo:unclearedPaths seen:verifiedPaths];
        }
        NSLog(@"[AppDataCleaner] Verify reusing canonical migrated wipe cache for %@", bundleID);
    } else {
        NSError *extensionDiscoveryError = nil;
        NSArray<NSString *> *extensionIdentifiers =
            [self _exactInstalledExtensionIdentifiersForApplicationIdentifier:bundleID
                                                                        error:&extensionDiscoveryError];
        if (!extensionIdentifiers && extensionDiscoveryError) {
            [unclearedPaths addObject:@{ @"path": @"ExtensionData",
                                         @"info": @"Exact installed-extension discovery failed" }];
        } else {
            PXDataContainerResolver *resolver = [[PXDataContainerResolver alloc] init];
            const PXResolvedContainerRoot roots[] = {
                PXResolvedContainerRootRootful,
                PXResolvedContainerRootRootless,
            };
            const PXResolvedContainerKind kinds[] = {
                PXResolvedContainerKindExtensionData,
                PXResolvedContainerKindPluginKitData,
            };
            for (NSString *identifier in extensionIdentifiers ?: @[]) {
                for (NSUInteger kindIndex = 0; kindIndex < sizeof(kinds) / sizeof(kinds[0]); kindIndex++) {
                    for (NSUInteger rootIndex = 0; rootIndex < sizeof(roots) / sizeof(roots[0]); rootIndex++) {
                        NSError *resolutionError = nil;
                        PXResolvedContainer *resolved =
                            [resolver resolveDataContainerForIdentifier:identifier
                                                                   kind:kinds[kindIndex]
                                                                   root:roots[rootIndex]
                                                                  error:&resolutionError];
                        if (!resolved) {
                            if (resolutionError) {
                                [unclearedPaths addObject:@{ @"path": @"ExtensionData",
                                                             @"info": @"Exact extension data resolution failed" }];
                            }
                            continue;
                        }
                        if (!PXReadOnlyRealDirectoryAtPath(resolved.containerPath)) {
                            [unclearedPaths addObject:@{ @"path": @"ExtensionData",
                                                         @"info": @"Resolved extension path failed read-only validation" }];
                            continue;
                        }
                        [self verifyClearedPath:[resolved.containerPath stringByStandardizingPath]
                                   reportingTo:unclearedPaths
                                          seen:verifiedPaths];
                    }
                }
            }
        }
        [self logMessage:@"[AppDataCleaner] Standalone verification used exact extension/PluginKit resolution"];
    }
    
    // 4. Verify system paths. SpringBoard ApplicationState is intentionally not deleted (respring risk).
    NSArray *systemPaths = @[
        [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Caches/%@", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Cookies/%@.binarycookies", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Application Support/%@", bundleID]
    ];
    
    for (NSString *path in systemPaths) {
        if ([_fileManager fileExistsAtPath:path]) {
            [unclearedPaths addObject:@{
                @"path": path,
                @"info": @"System path still exists"
            }];
        }
    }
    
    // 5. Verify only the exact Keychain groups captured by this operation's immutable plan.
    // Standalone verification has no operation snapshot, so it may construct a live read-only plan.
    PXKeychainClearPlan *keychainVerificationPlan = useOperationContext
        ? operationContext.keychainPlanSnapshot
        : [self _keychainClearPlanForBundleIdentifier:bundleID];
    if (useOperationContext && ![keychainVerificationPlan isKindOfClass:[PXKeychainClearPlan class]]) {
        [unclearedPaths addObject:@{
            @"path": @"Keychain",
            @"info": @"Canonical Keychain verification snapshot is unavailable"
        }];
    } else if (keychainVerificationPlan.planningFailureCode != 0) {
        [unclearedPaths addObject:@{
            @"path": @"Keychain",
            @"info": @"Exact Keychain verification plan could not be authorized"
        }];
    } else if (keychainVerificationPlan.plannedPassCount > 0 &&
               keychainVerificationPlan.selectedGroups.count > 0) {
        BOOL keychainKnown = NO;
        BOOL keychainItemsRemain =
            [self _hasExactKeychainItemsForBundleIdentifier:bundleID
                                               accessGroups:keychainVerificationPlan.selectedGroups
                                                      known:&keychainKnown];
        if (!keychainKnown) {
            [unclearedPaths addObject:@{
                @"path": @"Keychain",
                @"info": @"Exact selected-group Keychain verification was unavailable"
            }];
        } else if (keychainItemsRemain) {
            [unclearedPaths addObject:@{
                @"path": @"Keychain",
                @"info": @"Selected Keychain access groups still contain items"
            }];
        }
    }
    
    // 6. Filter out special paths and expected system-created directories before reporting
    NSMutableArray *filteredPaths = [NSMutableArray array];
    for (NSDictionary *item in unclearedPaths) {
        NSString *path = item[@"path"];
        NSString *info = item[@"info"];
        
        // Skip SiriAnalytics.db which we've specially cleaned
        if ([path containsString:@"SiriAnalytics.db"]) {
            continue;
        }
        
        // Skip IconState.plist which we've specially cleaned
        if ([path containsString:@"IconState.plist"]) {
            continue;
        }
        
        // Skip app container paths that only contain system directories
        if (([path containsString:@"/var/mobile/Containers/Data/Application"] ||
             [path containsString:@"/containers/Data/Application"] ||
             [path containsString:@"/private/var/mobile/Containers/Data/PluginKitPlugin"] ||
             [path containsString:@"/containers/Data/PluginKitPlugin"] ||
             [path containsString:@"/private/var/mobile/Containers/Shared/AppGroup"] ||
             [path containsString:@"/containers/Shared/AppGroup"]) &&
            ([info containsString:@"StoreKit"] || 
             [info containsString:@"Directory has 0 non-system files"] ||
             [info containsString:@"Directory has 1 non-system files: Documents"] ||
             [info containsString:@"Directory has 2 non-system files: Documents, Library"] ||
             [info containsString:@"Directory has 3 non-system files: Documents, Library, tmp"] ||
             [info containsString:@"Directory has 4 non-system files: StoreKit, Documents, Library, tmp"])) {
            continue;
        }
        
        [filteredPaths addObject:item];
    }
    
    // 7. Final verification summary
    BOOL ok = (filteredPaths.count == 0);
    if (!ok) {
        NSLog(@"[AppDataCleaner] ⚠️ WARNING: Verification found %lu uncleared data paths:", (unsigned long)filteredPaths.count);
        for (NSDictionary *item in filteredPaths) {
            NSLog(@"[AppDataCleaner] - UNCLEARED: %@ (%@)", item[@"path"], item[@"info"]);
        }
    } else {
        NSLog(@"[AppDataCleaner] ✅ All data successfully cleared for %@", bundleID);
    }

    // Drop wipe discovery cache after consume (next clear rebuilds it).
    if (useWipeCache) {
        _wipeCacheBundleID = nil;
        _wipeCacheApplicationDataCanonicalPaths = nil;
        _wipeCacheAppGroupCanonicalPaths = nil;
        _wipeCacheExtensionDataCanonicalPaths = nil;
        _wipeCachePluginKitDataCanonicalPaths = nil;
    }
    return ok;
}

- (void)verifyClearedPath:(NSString *)path reportingTo:(NSMutableArray *)unclearedPaths seen:(NSMutableSet<NSString *> *)seenPaths {
    if (!path.length) return;
    if ([seenPaths containsObject:path]) return;
    [seenPaths addObject:path];
    [self verifyClearedPath:path reportingTo:unclearedPaths];
}

// Helper method to verify a path is properly cleaned
- (void)verifyClearedPath:(NSString *)path reportingTo:(NSMutableArray *)unclearedPaths {
    if (![_fileManager fileExistsAtPath:path]) {
        return; // Path doesn't exist, so it's clean
    }
    
    // Check if it's a directory
    BOOL isDirectory = NO;
    [_fileManager fileExistsAtPath:path isDirectory:&isDirectory];
    
    if (isDirectory) {
        NSError *error;
        NSArray *contents = [_fileManager contentsOfDirectoryAtPath:path error:&error];
        
        if (error) {
            [unclearedPaths addObject:@{
                @"path": path,
                @"info": [NSString stringWithFormat:@"Error listing directory: %@", error.localizedDescription]
            }];
            return;
        }
        
        NSMutableArray *nonSystemFiles = [NSMutableArray array];
        
        for (NSString *item in contents) {
            // Skip system metadata files and empty system-created directories
            if ([item hasPrefix:@".com.apple"] || 
                [item isEqualToString:@"StoreKit"] || 
                [item isEqualToString:@"Documents"] || 
                [item isEqualToString:@"Library"] || 
                [item isEqualToString:@"tmp"]) {
                continue;
            }
            
            NSString *fullPath = [path stringByAppendingPathComponent:item];
            BOOL itemIsDirectory = NO;
            [_fileManager fileExistsAtPath:fullPath isDirectory:&itemIsDirectory];
            
            // Check if it's an empty directory (system created)
            if (itemIsDirectory) {
                NSArray *subContents = [_fileManager contentsOfDirectoryAtPath:fullPath error:nil];
                if (subContents.count == 0 || [self containsOnlySystemFiles:subContents]) {
                    continue; // Skip empty directories or directories with only system files
                }
            }
            
            [nonSystemFiles addObject:item];
        }
        
        if (nonSystemFiles.count > 0) {
            // Directory has non-system files
            NSString *infoString = [NSString stringWithFormat:@"Directory has %lu non-system files: %@", 
                                   (unsigned long)nonSystemFiles.count, 
                                   [nonSystemFiles count] > 4 ? 
                                   [[nonSystemFiles subarrayWithRange:NSMakeRange(0, MIN(4, nonSystemFiles.count))] componentsJoinedByString:@", "] : 
                                   [nonSystemFiles componentsJoinedByString:@", "]];
            
            [unclearedPaths addObject:@{
                @"path": path,
                @"info": infoString
            }];
        }
    } else {
        // It's a file, report it
        [unclearedPaths addObject:@{
            @"path": path,
            @"info": @"File exists"
        }];
    }
}

// Helper to check if an array contains only system files
- (BOOL)containsOnlySystemFiles:(NSArray *)files {
    for (NSString *file in files) {
        if (![file hasPrefix:@".com.apple"]) {
            return NO;
        }
    }
    return YES;
}

// Verify keychain items are properly cleared
- (void)verifyKeychainClearedForBundleID:(NSString *)bundleID reportingTo:(NSMutableArray *)unclearedPaths {
    (void)bundleID;
    (void)unclearedPaths;
    // Legacy verifier inferred ownership from service/account/label substrings.
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)verifySQLiteReferencesCleared:(NSString *)bundleID reportingTo:(NSMutableArray *)unclearedPaths {
    (void)bundleID;
    (void)unclearedPaths;
    // Shared system databases are outside the exact Clear ownership boundary.
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// Helper to run a command and get its output
- (NSString *)runCommandAndGetOutput:(NSString *)command {
    (void)command;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return @"";
}

- (NSString *)runCommandAndGetOutput:(NSString *)command
                          timeoutSec:(NSTimeInterval)timeoutSec {
    (void)command;
    (void)timeoutSec;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return @"";
}
#pragma mark - Public Header Methods

- (BOOL)hasDataToClear:(NSString *)bundleID {
    if (!PXStrictBundleIdentifierIsValid(bundleID)) {
        NSLog(@"[AppDataCleaner] hasDataToClear rejected invalid bundle identifier");
        return NO;
    }

    NSArray<NSString *> *applicationDataPaths = PXExactReadOnlyApplicationDataPathsForBundleID(bundleID);
    NSArray<NSString *> *appGroupUUIDs = [self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:NO] ?: @[];
    NSArray<NSString *> *rootlessGroupUUIDs = [self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:YES] ?: @[];

    BOOL hasData = applicationDataPaths.count > 0 || appGroupUUIDs.count > 0 || rootlessGroupUUIDs.count > 0;
    if (!hasData) {
        NSArray<NSString *> *exactPreferencePaths = @[
            [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", bundleID],
            [NSString stringWithFormat:@"/private/var/mobile/Library/Preferences/%@.plist", bundleID],
            [NSString stringWithFormat:@"/var/jb/var/mobile/Library/Preferences/%@.plist", bundleID],
            [NSString stringWithFormat:@"/private/var/jb/var/mobile/Library/Preferences/%@.plist", bundleID],
        ];
        for (NSString *path in exactPreferencePaths) {
            if (PXReadOnlyRegularNonSymlinkFileAtPath(path)) {
                hasData = YES;
                break;
            }
        }
    }

    if (!hasData && [self hasKeychainItemsForBundleID:bundleID]) {
        hasData = YES;
    }

    if (hasData) {
        NSDictionary *usage = [self getDataUsage:bundleID];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:usage forKey:[NSString stringWithFormat:@"DataUsage_%@", bundleID]];
        [defaults synchronize];
    } else {
        NSLog(@"[AppDataCleaner] No exact-owned data found to clear for %@", bundleID);
    }
    return hasData;
}

// --- Optimized lookup helpers (local to this file, do not break existing API) ---

- (NSString *)optimized_findDataContainerUUID:(NSString *)bundleID inDirectories:(NSArray *)dataDirs {
    (void)bundleID;
    (void)dataDirs;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return nil;
}

- (NSString *)optimized_findRootlessDataContainerUUID:(NSString *)bundleID inDirectories:(NSArray *)dataDirs {
    (void)bundleID;
    (void)dataDirs;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return nil;
}

- (NSArray *)optimized_findAppGroupUUIDs:(NSString *)bundleID inDirectories:(NSArray *)groupDirs {
    (void)bundleID;
    (void)groupDirs;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return @[];
}

- (NSString *)optimized_findBundleContainerUUID:(NSString *)bundleID inDirectories:(NSArray *)bundleDirs rootlessDirs:(NSArray *)rootlessDirs {
    (void)bundleID;
    (void)bundleDirs;
    (void)rootlessDirs;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return nil;
}

- (NSArray *)optimized_findExtensionContainers:(NSString *)bundleID dataDirs:(NSArray *)dataDirs rootlessDataDirs:(NSArray *)rootlessDataDirs bundleDirs:(NSArray *)bundleDirs rootlessBundleDirs:(NSArray *)rootlessBundleDirs {
    (void)bundleID;
    (void)dataDirs;
    (void)rootlessDataDirs;
    (void)bundleDirs;
    (void)rootlessBundleDirs;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return @[];
}

// Helper method to create human-readable file sizes
- (NSString *)humanReadableFileSize:(long long)size {
    NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
    formatter.countStyle = NSByteCountFormatterCountStyleFile;
    return [formatter stringFromByteCount:size];
}

// Implementation of helper methods that map to the main cleaning function
- (void)performFullCleanup:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)performSecondaryCleanup:(NSString *)bundleID {
    [self completeAppDataWipe:bundleID];
}

// Implementation of specialized cleanup methods
- (void)clearAppData:(NSString *)bundleID {
    [self completeAppDataWipe:bundleID];
}

- (void)clearAppCache:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)clearAppPreferences:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)clearAppCookies:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)clearAppWebKitData:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)clearAppKeychain:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)clearAppGroupData:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// Map the remaining methods to the main function
- (void)clearKeychainData:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}
- (void)clearSharedContainers:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearUserDefaults:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearSQLiteDatabases:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearPrivateVarData:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearDeviceDatabase:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearInstallationLogs:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearNetworkConfigurations:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearCarrierData:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearNetworkData:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearDNSCache:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearCrashReports:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearDiagnosticData:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearBluetoothData:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearPushNotificationData:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearThumbnailCache:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearWebCache:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearGameData:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearTemporaryFiles:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearBinaryPlists:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearEncryptedData:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearJailbreakDetectionLogs:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearSpotlightData:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearSiriData:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearSystemLoggerData:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearASLLogs:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearClipboard {
    // The general pasteboard is device-wide shared state and has no target bundle owner.
    PXLogQuarantinedLegacyClearSelector(_cmd);
}
- (void)clearPasteboardData:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearURLCache:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearBackgroundAssets:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearSharedStorage:(NSString *)bundleID { (void)bundleID; PXLogQuarantinedLegacyClearSelector(_cmd); }
- (void)clearAppStateData:(NSString *)bundleID {
    [self _internalClearAppStateData:bundleID];
}
- (void)secureDataWipe:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (NSDictionary *)getDataUsage:(NSString *)bundleID {
    NSMutableDictionary *usage = [@{
        @"dataSize": @0,
        @"bundleSize": @0,
        @"sharedSize": @0,
        @"totalSize": @0,
    } mutableCopy];
    if (!PXStrictBundleIdentifierIsValid(bundleID)) return usage;

    long long dataSize = 0;
    for (NSString *path in PXExactReadOnlyApplicationDataPathsForBundleID(bundleID)) {
        dataSize += [self calculateDirectorySize:path];
    }
    usage[@"dataSize"] = @(dataSize);

    NSString *bundlePath = PXExactInstalledApplicationBundlePathFromLaunchServices(bundleID);
    if (bundlePath.length) {
        usage[@"bundleSize"] = @([self calculateDirectorySize:bundlePath]);
    }

    long long sharedSize = 0;
    NSMutableSet<NSString *> *seenPaths = [NSMutableSet set];
    NSArray<NSString *> *rootfulGroups = [self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:NO] ?: @[];
    for (NSString *groupUUID in rootfulGroups) {
        if (!groupUUID.length) continue;
        NSString *path = [[@"/var/mobile/Containers/Shared/AppGroup" stringByAppendingPathComponent:groupUUID] stringByStandardizingPath];
        if ([seenPaths containsObject:path]) continue;
        [seenPaths addObject:path];
        sharedSize += [self calculateDirectorySize:path];
    }
    NSArray<NSString *> *rootlessGroups = [self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:YES] ?: @[];
    for (NSString *groupUUID in rootlessGroups) {
        if (!groupUUID.length) continue;
        NSString *path = [[@"/containers/Shared/AppGroup" stringByAppendingPathComponent:groupUUID] stringByStandardizingPath];
        if ([seenPaths containsObject:path]) continue;
        [seenPaths addObject:path];
        sharedSize += [self calculateDirectorySize:path];
    }
    usage[@"sharedSize"] = @(sharedSize);

    long long total = [usage[@"dataSize"] longLongValue] +
                      [usage[@"bundleSize"] longLongValue] +
                      [usage[@"sharedSize"] longLongValue];
    usage[@"totalSize"] = @(total);
    return usage;
}

// Helper method for getDataUsage
- (long long)calculateDirectorySize:(NSString *)path {
    if (![_fileManager fileExistsAtPath:path]) {
        return 0;
    }
    
    NSError *error = nil;
    NSDictionary *attributes = [_fileManager attributesOfItemAtPath:path error:&error];
    if (error) {
        return 0;
    }
    
    if ([attributes[NSFileType] isEqualToString:NSFileTypeRegular]) {
        return [attributes[NSFileSize] longLongValue];
    }
    
    NSArray *contents = [_fileManager contentsOfDirectoryAtPath:path error:&error];
    if (error) {
        return 0;
    }
    
    long long size = 0;
    for (NSString *item in contents) {
        NSString *fullPath = [path stringByAppendingPathComponent:item];
        NSDictionary *itemAttribs = [_fileManager attributesOfItemAtPath:fullPath error:&error];
        if (error) {
            continue;
        }
        
        if ([itemAttribs[NSFileType] isEqualToString:NSFileTypeDirectory]) {
            size += [self calculateDirectorySize:fullPath];
        } else {
            size += [itemAttribs[NSFileSize] longLongValue];
        }
    }
    
    return size;
}

// Add a specialized method for WebKit directories to handle the recursion issues
- (void)wipeWebKitDirectoryContents:(NSString *)path {
    (void)path;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// Add new method to handle app state data cleaning for modern apps
// Add new method to handle app state data cleaning for modern apps
- (void)_internalClearAppStateData:(NSString *)bundleID {
    if (!PXStrictBundleIdentifierIsValid(bundleID)) {
        [self logMessage:@"[AppDataCleaner] Exact app-state cleanup rejected invalid bundle identifier"];
        return;
    }

    PXClearOperationContext *operationContext = PXCurrentClearOperationContext();
    if (operationContext && [operationContext isCancellationRequested]) return;

    [self logMessage:@"[AppDataCleaner] Clearing exact app state files for %@", bundleID];
    NSArray<NSString *> *directPaths = @[
        [NSString stringWithFormat:@"/var/mobile/Library/SpringBoard/ApplicationState/%@.plist", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Preferences/com.apple.UIKit.SplitView.%@.plist", bundleID]
    ];

    for (NSString *path in directPaths) {
        if (operationContext && [operationContext isCancellationRequested]) return;
        if (!PXRemoveExactRegularNonSymlinkFile(path)) {
            [self logMessage:@"[AppDataCleaner] Exact app-state file refused/failed: %@", path];
        }
    }
}

// Helper to scan a directory and wipe files/folders matching a string
- (void)scanAndWipeInDirectory:(NSString *)directory matching:(NSString *)matchString {
    (void)directory;
    (void)matchString;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)_wipeMobileMailSharedStoreForRequest:(PXClearRequest *)request {
    if (![request isKindOfClass:[PXClearRequest class]] ||
        request.mode != PXClearModeDeep ||
        ![request.bundleIdentifier isEqualToString:@"com.apple.mobilemail"] ||
        ((request.options & PXClearOptionMailSharedStore) == 0)) {
        [self logMessage:@"[AppDataCleaner] MobileMail shared-store wipe rejected: missing explicit immutable policy"];
        return;
    }

    PXClearOperationContext *operationContext = PXCurrentClearOperationContext();
    if (operationContext && [operationContext isCancellationRequested]) return;

    PXStopMailDaemonsBestEffort(self);
    if (!PXWaitForProcessExit(self, @"maild", 5.0)) {
        [self logMessage:@"[AppDataCleaner] MobileMail: maild still running; forcing kill"];
        PXKillallByName(@"maild", SIGKILL);
        (void)PXWaitForProcessExit(self, @"maild", 2.0);
    }
    (void)PXWaitForProcessExit(self, @"Mail", 2.0);
    if (operationContext && [operationContext isCancellationRequested]) return;

    NSString *mailPath = @"/var/mobile/Library/Mail";
    NSString *trashPath = [NSString stringWithFormat:@"/var/mobile/Library/Mail.WeaponXTrash.%@", PXTimestampSuffix()];
    NSMutableArray<NSString *> *mailShell = [NSMutableArray array];
    if ([_fileManager fileExistsAtPath:mailPath]) {
        [mailShell addObject:[NSString stringWithFormat:@"mv '%@' '%@' 2>/dev/null || true", mailPath, trashPath]];
    }
    [mailShell addObject:@"mkdir -p '/var/mobile/Library/Mail' 2>/dev/null || true"];
    [mailShell addObject:@"chown mobile:mobile '/var/mobile/Library/Mail' 2>/dev/null || true"];
    [mailShell addObject:@"rm -f '/var/mobile/Library/Preferences/com.apple.mail.plist' 2>/dev/null || true"];
    [mailShell addObject:@"rm -f '/var/mobile/Library/Preferences/com.apple.mobilemail.plist' 2>/dev/null || true"];
    [mailShell addObject:@"rm -f '/private/var/mobile/Library/Preferences/com.apple.mail.plist' 2>/dev/null || true"];
    [mailShell addObject:@"rm -f '/private/var/mobile/Library/Preferences/com.apple.mobilemail.plist' 2>/dev/null || true"];
    [self runBatchedCommandsWithPrivileges:mailShell timeoutSec:120];

    if (operationContext && [operationContext isCancellationRequested]) return;
    PXStopMailDaemonsBestEffort(self);
    PXKillallByName(@"Mail", SIGTERM);
    [NSThread sleepForTimeInterval:0.15];
    PXKillallByName(@"Mail", SIGKILL);

    if ([trashPath hasPrefix:@"/var/mobile/Library/Mail.WeaponXTrash."]) {
        [self logMessage:@"[AppDataCleaner] MobileMail: kept old store at %@ for deferred cleanup", trashPath];
    }
}

// Override the existing clearAppStateData method to call our internal implementation

// Fix for line ~1757 - Replace the duplicate clearEncryptedData
- (void)_internalClearEncryptedDataOutsideMainApplicationContainer:(NSString *)bundleID
                                                         deepClean:(BOOL)deepClean {
    if (!PXStrictBundleIdentifierIsValid(bundleID)) {
        [self logMessage:@"[AppDataCleaner] Encrypted preference cleanup rejected invalid bundle identifier"];
        return;
    }

    PXClearOperationContext *operationContext = PXCurrentClearOperationContext();
    NSArray<NSString *> *preferenceBases = @[
        @"/var/mobile/Library/Preferences",
        @"/private/var/mobile/Library/Preferences",
        @"/var/jb/var/mobile/Library/Preferences",
        @"/private/var/jb/var/mobile/Library/Preferences"
    ];
    NSArray<NSString *> *authorizedPrefixes = @[
        [bundleID stringByAppendingString:@".enc"],
        [bundleID stringByAppendingString:@".encrypted"],
        [bundleID stringByAppendingString:@".secure"]
    ];

    [self logMessage:@"[AppDataCleaner] Clearing exact-boundary encrypted preferences for %@", bundleID];
    for (NSString *base in preferenceBases) {
        if (operationContext && [operationContext isCancellationRequested]) return;
        if (!PXReadOnlyRealDirectoryAtPath(base)) continue;

        NSError *enumerationError = nil;
        NSArray<NSString *> *entries = [_fileManager contentsOfDirectoryAtPath:base error:&enumerationError];
        if (![entries isKindOfClass:[NSArray class]] || enumerationError) {
            [self logMessage:@"[AppDataCleaner] Encrypted preference enumeration failed for %@", base];
            continue;
        }

        NSString *standardBase = [base stringByStandardizingPath];
        for (NSString *entry in entries) {
            if (operationContext && [operationContext isCancellationRequested]) return;
            if (![entry isKindOfClass:[NSString class]] || entry.length == 0 || [entry containsString:@"/"]) continue;

            BOOL authorizedName = NO;
            for (NSString *prefix in authorizedPrefixes) {
                if ([entry hasPrefix:prefix]) {
                    authorizedName = YES;
                    break;
                }
            }
            if (!authorizedName) continue;

            NSString *path = [base stringByAppendingPathComponent:entry];
            NSString *standardPath = [path stringByStandardizingPath];
            if (![[standardPath stringByDeletingLastPathComponent] isEqualToString:standardBase]) continue;
            if (!PXRemoveExactRegularNonSymlinkFile(standardPath)) {
                [self logMessage:@"[AppDataCleaner] Encrypted preference file refused/failed: %@", standardPath];
            }
        }
    }

    if (!deepClean) {
        [self logMessage:@"[AppDataCleaner] Deep Clean OFF: exact encrypted preference cleanup complete"];
    }
}

- (void)_internalClearEncryptedData:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// Override the existing clearEncryptedData method to call our internal implementation

// Add this method to handle clearing secure storage

// Add this new method to explicitly find extension containers
- (NSArray *)findExtensionContainers:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return @[];
}

- (NSString *)findBundleUUIDForExtension:(NSString *)extensionBundleID {
    (void)extensionBundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return nil;
}

- (NSString *)findRootlessBundleUUIDForExtension:(NSString *)extensionBundleID {
    (void)extensionBundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return nil;
}

// Method to clear extension containers
- (void)clearExtensionContainers:(NSArray *)extensionInfo forApp:(NSString *)bundleID {
    (void)extensionInfo;
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// Compatibility no-op: recursive permission mutation is intentionally disabled.
- (void)fixPermissionsForPath:(NSString *)path {
    (void)path;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// Add a new method for aggressive cleanup of stubborn files
- (void)performAggressiveCleanupFor:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (NSString *)findBundleContainerUUID:(NSString *)bundleID {
    return [self findBundleContainerUUIDForBundleID:bundleID];
}

// Add these methods to our collection for the most comprehensive clearing

// MEDIA STORAGE: Add method to clean media traces that apps sometimes leave behind
- (void)clearMediaData:(NSString *)bundleID {
    (void)bundleID;
    // Camera Roll, Downloads, Messages attachments and Photos databases are shared user
    // media. App-name/bundle substring matching cannot authorize destructive deletion.
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// HEALTH DATA: Some apps like fitness trackers can store health data
- (void)clearHealthData:(NSString *)bundleID {
    (void)bundleID;
    // Health/HealthKit are shared protected stores. A filename containing a bundle id
    // is not proof that the target application owns the health record or database row.
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// SAFARI DATA: Some apps use SafariViewController and leave data there
- (void)clearSafariData:(NSString *)bundleID {
    (void)bundleID;
    // Shared Safari history/bookmark/tab databases must not be edited by fuzzy URL/title
    // matching. Explicit MobileSafari shared-web cleanup is separately policy-gated.
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// NEW: Method to completely wipe a container directory
- (void)completelyWipeContainer:(NSString *)containerPath {
    (void)containerPath;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// NEW: Method to clean IconState.plist
- (void)cleanIconStatePlist:(NSString *)bundleID {
    // Retained only for source/API compatibility. SpringBoard icon-state files are
    // shared system state and are outside a single app Clear ownership boundary.
    [self logMessage:@"[AppDataCleaner] cleanIconStatePlist quarantined for %@", bundleID ?: @"(nil)"];
}

// NEW: Method to clean SiriAnalytics database
- (void)cleanSiriAnalyticsDatabase:(NSString *)bundleID {
    // Retained only for source/API compatibility. The analytics store is shared system
    // state and this selector must not infer row ownership from bundle/name substrings.
    [self logMessage:@"[AppDataCleaner] cleanSiriAnalyticsDatabase quarantined for %@", bundleID ?: @"(nil)"];
}

// NEW: Method to clean LaunchServices database
- (void)cleanLaunchServicesDatabase:(NSString *)bundleID {
    // Retained only for source/API compatibility. LaunchServices/SpringBoard caches
    // are shared system state and must not be globally removed by app Clear.
    [self logMessage:@"[AppDataCleaner] cleanLaunchServicesDatabase quarantined for %@", bundleID ?: @"(nil)"];
}

// NEW: Method to refresh system services to apply changes
- (void)refreshSystemServices {
    // Retained only for source/API compatibility. Global cache flushing, shared-daemon
    // termination, and shared-database maintenance are intentionally quarantined because
    // they are not owned by a single app Clear request.
    [self logMessage:@"[AppDataCleaner] refreshSystemServices quarantined: no global mutations performed"];
}

#pragma mark - Container Discovery Methods

- (BOOL)hasKeychainItemsForBundleID:(NSString *)bundleID {
    BOOL known = NO;
    BOOL hasItems = [self _hasExactKeychainItemsForBundleIdentifier:bundleID
                                                       accessGroups:nil
                                                              known:&known];
    if (!known) {
        [self logMessage:@"[AppDataCleaner] Exact Keychain presence probe unavailable for %@; failing closed",
                         bundleID ?: @"(nil)"];
        return NO;
    }
    return hasItems;
}

// Support methods (aliases for backwards compatibility)
- (NSString *)findDataContainerUUIDForBundleID:(NSString *)bundleID {
    NSArray<NSString *> *paths = PXExactReadOnlyApplicationDataPathsForBundleID(bundleID);
    return paths.count > 0 ? [paths.firstObject lastPathComponent] : nil;
}

- (NSString *)findBundleContainerUUIDForBundleID:(NSString *)bundleID {
    NSString *bundlePath = PXExactInstalledApplicationBundlePathWithFilesystemFallback(bundleID);
    if (!bundlePath.length) return nil;
    NSString *uuid = [[bundlePath stringByDeletingLastPathComponent] lastPathComponent];
    return uuid.length ? uuid : nil;
}

- (NSArray *)findGroupContainerUUIDsForBundleID:(NSString *)bundleID {
    if (!PXStrictBundleIdentifierIsValid(bundleID)) return @[];
    NSMutableOrderedSet<NSString *> *uuids = [NSMutableOrderedSet orderedSet];
    [uuids addObjectsFromArray:[self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:NO] ?: @[]];
    [uuids addObjectsFromArray:[self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:YES] ?: @[]];
    return uuids.array;
}

- (void)_wipeRelatedDataContainersForBundleIDs:(NSArray<NSString *> *)bundleIDs {
    (void)bundleIDs;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)_wipeRelatedSystemGroupContainersForIdentifiers:(NSArray<NSString *> *)idents {
    (void)idents;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)_wipeContainersInBasePaths:(NSArray<NSString *> *)bases
               matchingSubstrings:(NSArray<NSString *> *)needles
                             tag:(NSString *)tag {
    (void)bases;
    (void)needles;
    (void)tag;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)_wipeDataContainersByIdentifierPrefixOrSubstring:(NSArray<NSString *> *)prefixes
                                              substrings:(NSArray<NSString *> *)substrings
                                                    tag:(NSString *)tag {
    (void)prefixes;
    (void)substrings;
    (void)tag;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)_scrubWebKitStateInSharedContainerBase:(NSString *)base tag:(NSString *)tag {
    (void)base;
    (void)tag;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)_wipeMobileSafariSystemStoresForRequest:(PXClearRequest *)request {
    if (![request isKindOfClass:[PXClearRequest class]] ||
        request.mode != PXClearModeDeep ||
        ![request.bundleIdentifier isEqualToString:@"com.apple.mobilesafari"] ||
        ((request.options & PXClearOptionSafariSharedWebData) == 0)) {
        [self logMessage:@"[AppDataCleaner] MobileSafari shared-store wipe rejected: missing explicit immutable policy"];
        return;
    }
    [self logMessage:@"[AppDataCleaner] MobileSafari: wiping explicitly authorized shared Safari/WebKit/Cookies stores..."];

    // Ensure processes are stopped first to avoid sqlite "database is locked" and detached DB crashes.
    PXStopSafariDaemonsBestEffort(self);

    // Accounts3 is shared system state, not Safari-owned web state. Never infer
    // account ownership from provider/name substrings during an app Clear operation.
    [self logMessage:@"[AppDataCleaner] MobileSafari: shared Accounts3 mutation skipped (exact-ownership policy)"];

    NSArray<NSString *> *libraryBases = @[
        @"/var/mobile/Library",
        @"/private/var/mobile/Library",
        @"/var/jb/var/mobile/Library",
        @"/private/var/jb/var/mobile/Library"
    ];

    for (NSString *base in libraryBases) {
        if (![_fileManager fileExistsAtPath:base]) {
            continue;
        }

        // One shell per library base: same paths as before, far fewer posix_spawn.
        NSMutableArray<NSString *> *parts = [NSMutableArray array];

        // Preferences that affect Safari session/cookies.
        NSString *prefsDir = [base stringByAppendingPathComponent:@"Preferences"];
        if ([_fileManager fileExistsAtPath:prefsDir]) {
            NSArray<NSString *> *prefs = @[
                @"com.apple.Safari.plist",
                @"com.apple.mobilesafari.plist",
                @"com.apple.SafariViewService.plist",
                @"com.apple.WebKit.WebContent.plist",
                @"com.apple.WebKit.Networking.plist",
                @"com.apple.WebKit.GPU.plist",
                @"com.apple.WebKit.plist"
            ];
            for (NSString *p in prefs) {
                NSString *full = [prefsDir stringByAppendingPathComponent:p];
                [parts addObject:[NSString stringWithFormat:@"rm -f %@ 2>/dev/null || true", PXShellQuote(full)]];
            }
        }

        // Caches that can carry session state.
        NSString *cachesDir = [base stringByAppendingPathComponent:@"Caches"];
        if ([_fileManager fileExistsAtPath:cachesDir]) {
            NSString *cq = PXShellQuote(cachesDir);
            [parts addObject:[NSString stringWithFormat:@"rm -rf %@/com.apple.Safari 2>/dev/null || true", cq]];
            [parts addObject:[NSString stringWithFormat:@"rm -rf %@/com.apple.mobilesafari 2>/dev/null || true", cq]];
            [parts addObject:[NSString stringWithFormat:@"rm -rf %@/com.apple.SafariViewService 2>/dev/null || true", cq]];
            // Handle both dot and dash variants.
            [parts addObject:[NSString stringWithFormat:@"rm -rf %@/com.apple.WebKit.* %@/com.apple.WebKit-* 2>/dev/null || true", cq, cq]];
            [parts addObject:[NSString stringWithFormat:@"rm -rf %@/com.apple.nsurlsessiond 2>/dev/null || true", cq]];
        }

        NSString *safariDir = [base stringByAppendingPathComponent:@"Safari"];
        if ([_fileManager fileExistsAtPath:safariDir]) {
            // Preserve bookmarks DB by default; nuke session/history/website data.
            [parts addObject:[NSString stringWithFormat:
                @"find %@ -mindepth 1 -maxdepth 1 -not -name 'Bookmarks.db' -not -name 'Bookmarks.db-wal' -not -name 'Bookmarks.db-shm' -exec rm -rf {} + 2>/dev/null || true",
                PXShellQuote(safariDir)]];
        }

        // WebKit global stores are the main source of persistent web sessions.
        NSString *webKitDir = [base stringByAppendingPathComponent:@"WebKit"];
        if ([_fileManager fileExistsAtPath:webKitDir]) {
            NSString *wq = PXShellQuote(webKitDir);
            [parts addObject:[NSString stringWithFormat:@"rm -rf %@ 2>/dev/null || true", wq]];
            [parts addObject:[NSString stringWithFormat:@"mkdir -p %@ 2>/dev/null || true", wq]];
            [parts addObject:[NSString stringWithFormat:@"chown mobile:mobile %@ 2>/dev/null || true", wq]];
        }

        NSString *cookiesDir = [base stringByAppendingPathComponent:@"Cookies"];
        if ([_fileManager fileExistsAtPath:cookiesDir]) {
            // Cookie stores can be global. Removing them clears Safari sessions/cookies.
            NSString *kq = PXShellQuote(cookiesDir);
            [parts addObject:[NSString stringWithFormat:@"rm -f %@/Cookies.binarycookies 2>/dev/null || true", kq]];
            [parts addObject:[NSString stringWithFormat:@"rm -f %@/Cookies.sqlite %@/Cookies.sqlite-wal %@/Cookies.sqlite-shm 2>/dev/null || true", kq, kq, kq]];
            [parts addObject:[NSString stringWithFormat:@"rm -f %@/*.binarycookies 2>/dev/null || true", kq]];
        }

        if (parts.count > 0) {
            [self runBatchedCommandsWithPrivileges:parts timeoutSec:8 * 60];
        }
    }

    // Flush preference/caches used by Safari.
    PXKillallByName(@"cfprefsd", SIGTERM);
    PXKillallByName(@"webbookmarksd", SIGTERM);

    // Also wipe data containers for WebKit helper services; cookies/session can live there.
    [self _wipeRelatedDataContainersForBundleIDs:@[
        @"com.apple.SafariViewService",
        @"com.apple.WebKit.Networking",
        @"com.apple.WebKit.WebContent",
        @"com.apple.WebKit.GPU"
    ]];

    // Fallback: on some builds these WebKit service containers do not use the exact bundle id.
    // Wipe any data container whose identifier clearly belongs to Apple WebKit/Safari services.
    [self _wipeDataContainersByIdentifierPrefixOrSubstring:@[
        @"com.apple.WebKit.",
        @"com.apple.safariviewservice",
        @"com.apple.mobilesafari"
    ] substrings:@[
        @"com.apple.webkit",
        @"safariviewservice"
    ] tag:@"MobileSafari(webkit-data)"];

    // Also wipe SystemGroup containers used by WebKit (common for Safari/SafariViewService).
    [self _wipeRelatedSystemGroupContainersForIdentifiers:@[
        @"systemgroup.com.apple.WebKit",
        @"systemgroup.com.apple.WebKit.Networking",
        @"systemgroup.com.apple.WebKit.WebContent",
        @"systemgroup.com.apple.WebKit.GPU",
        @"systemgroup.com.apple.SafariViewService",
        @"systemgroup.com.apple.mobilesafari",
        @"com.apple.WebKit",
        @"com.apple.SafariViewService"
    ]];

    // Broader scan: some iOS versions store WebKit state in AppGroup/SystemGroup containers with different identifiers.
    // This is intentionally aggressive for Safari clear-data.
    [self _wipeContainersInBasePaths:@[@"/var/mobile/Containers/Shared/SystemGroup", @"/containers/Shared/SystemGroup"]
                  matchingSubstrings:@[@"webkit", @"safariviewservice", @"mobilesafari"]
                                tag:@"MobileSafari(systemgroup)"];

    // Final fallback remains limited to SystemGroup containers.
    [self _scrubWebKitStateInSharedContainerBase:@"/var/mobile/Containers/Shared/SystemGroup" tag:@"MobileSafari(systemgroup-scrub)"];
    [self _scrubWebKitStateInSharedContainerBase:@"/containers/Shared/SystemGroup" tag:@"MobileSafari(systemgroup-scrub)"];

    // Optional: SafeBrowsing can persist per-user browsing state.
    [self runCommandWithPrivileges:@"rm -rf /var/mobile/Library/SafariSafeBrowsing 2>/dev/null || true"]; 

    // CFNetwork caches can hold cookie/state caches outside WebKit dir.
    [self runCommandWithPrivileges:@"rm -rf /var/mobile/Library/Caches/com.apple.CFNetwork 2>/dev/null || true"]; 
    [self runCommandWithPrivileges:@"rm -rf /private/var/mobile/Library/Caches/com.apple.CFNetwork 2>/dev/null || true"]; 

    // CLEAR-07 (Phase 11): removed process-wide sync(). This legacy Safari-specific cleanup
    // relies on the per-command rm results above and must not block on a global filesystem flush.
}

- (NSArray *)findExtensionDataContainersForBundleID:(NSString *)bundleID {
    if (!PXStrictBundleIdentifierIsValid(bundleID)) return @[];

    NSError *discoveryError = nil;
    NSArray<NSString *> *extensionIdentifiers =
        [self _exactInstalledExtensionIdentifiersForApplicationIdentifier:bundleID
                                                                    error:&discoveryError];
    if (!extensionIdentifiers || discoveryError) {
        [self logMessage:@"[AppDataCleaner] Exact extension discovery failed for %@", bundleID];
        return @[];
    }

    PXDataContainerResolver *resolver = [[PXDataContainerResolver alloc] init];
    NSMutableOrderedSet<NSString *> *uuids = [NSMutableOrderedSet orderedSet];
    for (NSString *extensionIdentifier in extensionIdentifiers) {
        NSError *resolutionError = nil;
        PXResolvedContainer *resolved =
            [resolver resolveDataContainerForIdentifier:extensionIdentifier
                                                   kind:PXResolvedContainerKindExtensionData
                                                   root:PXResolvedContainerRootRootful
                                                  error:&resolutionError];
        if (!resolved || resolutionError || !PXReadOnlyRealDirectoryAtPath(resolved.containerPath)) continue;
        if (resolved.containerUUID.length) [uuids addObject:resolved.containerUUID];
    }
    return uuids.array;
}

- (void)cleanAppGroupContainers:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}



- (void)cleanAppSpecificFilesInSharedContainer:(NSString *)containerPath bundleID:(NSString *)bundleID appName:(NSString *)appName companyName:(NSString *)companyName {
    (void)containerPath;
    (void)bundleID;
    (void)appName;
    (void)companyName;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)deepCleanSystemSharedContainer:(NSString *)containerPath bundleID:(NSString *)bundleID appName:(NSString *)appName companyName:(NSString *)companyName {
    (void)containerPath;
    (void)bundleID;
    (void)appName;
    (void)companyName;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)cleanDatabaseFile:(NSString *)dbPath bundleID:(NSString *)bundleID appName:(NSString *)appName companyName:(NSString *)companyName {
    (void)dbPath;
    (void)bundleID;
    (void)appName;
    (void)companyName;
    // Legacy generic SQL mutation had no schema/row ownership proof.
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// Legacy shell-based content probe retained only for source compatibility.
- (BOOL)directoryExistsAndHasAnyContent:(NSString *)path {
    (void)path;
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return NO;
}

// Helper method to check if the app has any references in system databases
- (BOOL)hasSystemDatabaseReferencesForBundleID:(NSString *)bundleID {
    (void)bundleID;
    // Shared system-database references are not app-owned data and fuzzy name/schema
    // matching must not influence whether Clear is offered or considered complete.
    PXLogQuarantinedLegacyClearSelector(_cmd);
    return NO;
}

// NEW: Method to check if there are keychain items for a bundle ID
@end
