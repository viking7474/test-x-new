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
#import <string.h>
#import <sqlite3.h>
#import <notify.h>

#import "AppEntitlementsReader.h"
#import "CommandRunner.h"
#import "PXDataContainerResolver.h"
#import "PXDestructivePathValidator.h"
#import "PXClearRequest.h"
#import "PXClearResult.h"
#import "AppGroupContainerResolver.h"
#import "FreezeManager.h"
#import "common/PXProcessKiller.h"

static const NSUInteger PXPrivilegedCommandMaxOutputBytes = 1024 * 1024;
static const NSTimeInterval PXOutputQueryDefaultTimeoutSec = 60.0;
static NSString * const PXFindExecutablePath = @"/usr/bin/find";
static const NSTimeInterval PXFindCommandTimeoutSec = 120.0;
static const NSUInteger PXFindCommandMaxOutputBytes = 4 * 1024 * 1024;

// Add SearchableIndex framework if available
#import <CoreSpotlight/CoreSpotlight.h>

@class PXKeychainClearPlan;

@interface AppDataCleaner ()
- (NSString *)runCommandAndGetOutput:(NSString *)command
                          timeoutSec:(NSTimeInterval)timeoutSec;
- (NSArray<NSString *> *)runBoundedFindWithArguments:(NSArray<NSString *> *)arguments;
- (PXClearResult *)_completeDataWipeForMigratedRequest:(PXClearRequest *)request;
- (PXClearComponentResult *)_completeAppDataWipeForApplicationDataRequest:(PXClearRequest *)request;
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

@interface PXKeychainClearPlan : NSObject {
@private
    NSString *_bundleIdentifier;
    BOOL _enabled;
    BOOL _systemApplication;
    BOOL _systemPolicyAllowed;
    NSArray<NSString *> *_selectedGroups;
    NSArray<NSString *> *_authorizedGroups;
    NSString *_applicationIdentifier;
    NSUInteger _plannedPassCount;
    NSString *_skipDetail;
    NSInteger _planningFailureCode;
    NSString *_planningFailureMessage;
}
@property (nonatomic, copy, readonly) NSString *bundleIdentifier;
@property (nonatomic, assign, readonly, getter=isEnabled) BOOL enabled;
@property (nonatomic, assign, readonly, getter=isSystemApplication) BOOL systemApplication;
@property (nonatomic, assign, readonly, getter=isSystemPolicyAllowed) BOOL systemPolicyAllowed;
@property (nonatomic, copy, readonly) NSArray<NSString *> *selectedGroups;
@property (nonatomic, copy, readonly) NSArray<NSString *> *authorizedGroups;
@property (nonatomic, copy, readonly) NSString *applicationIdentifier;
@property (nonatomic, assign, readonly) NSUInteger plannedPassCount;
@property (nonatomic, copy, readonly) NSString *skipDetail;
@property (nonatomic, assign, readonly) NSInteger planningFailureCode;
@property (nonatomic, copy, readonly) NSString *planningFailureMessage;
- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                                 enabled:(BOOL)enabled
                       systemApplication:(BOOL)systemApplication
                     systemPolicyAllowed:(BOOL)systemPolicyAllowed
                          selectedGroups:(NSArray<NSString *> *)selectedGroups
                        authorizedGroups:(NSArray<NSString *> *)authorizedGroups
                   applicationIdentifier:(NSString *)applicationIdentifier
                        plannedPassCount:(NSUInteger)plannedPassCount
                              skipDetail:(NSString *)skipDetail
                     planningFailureCode:(NSInteger)planningFailureCode
                  planningFailureMessage:(NSString *)planningFailureMessage;
@end

@implementation PXKeychainClearPlan
@synthesize bundleIdentifier = _bundleIdentifier;
@synthesize enabled = _enabled;
@synthesize systemApplication = _systemApplication;
@synthesize systemPolicyAllowed = _systemPolicyAllowed;
@synthesize selectedGroups = _selectedGroups;
@synthesize authorizedGroups = _authorizedGroups;
@synthesize applicationIdentifier = _applicationIdentifier;
@synthesize plannedPassCount = _plannedPassCount;
@synthesize skipDetail = _skipDetail;
@synthesize planningFailureCode = _planningFailureCode;
@synthesize planningFailureMessage = _planningFailureMessage;
- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                                 enabled:(BOOL)enabled
                       systemApplication:(BOOL)systemApplication
                     systemPolicyAllowed:(BOOL)systemPolicyAllowed
                          selectedGroups:(NSArray<NSString *> *)selectedGroups
                        authorizedGroups:(NSArray<NSString *> *)authorizedGroups
                   applicationIdentifier:(NSString *)applicationIdentifier
                        plannedPassCount:(NSUInteger)plannedPassCount
                              skipDetail:(NSString *)skipDetail
                     planningFailureCode:(NSInteger)planningFailureCode
                  planningFailureMessage:(NSString *)planningFailureMessage {
    self = [super init];
    if (self) {
        _bundleIdentifier = [bundleIdentifier copy] ?: @"";
        _enabled = enabled;
        _systemApplication = systemApplication;
        _systemPolicyAllowed = systemPolicyAllowed;
        _selectedGroups = [selectedGroups copy] ?: @[];
        _authorizedGroups = [authorizedGroups copy] ?: @[];
        _applicationIdentifier = [applicationIdentifier copy];
        _plannedPassCount = plannedPassCount;
        _skipDetail = [skipDetail copy];
        _planningFailureCode = planningFailureCode;
        _planningFailureMessage = [planningFailureMessage copy];
    }
    return self;
}
@end

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

    char *errMsg = NULL;
    rc = sqlite3_exec(db, sql.UTF8String, NULL, NULL, &errMsg);
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
    char *errMsg = NULL;
    int rc = sqlite3_exec(db, sql.UTF8String, NULL, NULL, &errMsg);
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

    // 1) Try kill by executable name from bundle container
    NSString *bundleUUID = [selfRef findBundleContainerUUID:bundleID];
    if (bundleUUID.length) {
        NSString *bundleRoot = [NSString stringWithFormat:@"/var/mobile/Containers/Bundle/Application/%@", bundleUUID];
        NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bundleRoot error:nil];
        for (NSString *item in items) {
            if ([item hasSuffix:@".app"]) {
                NSString *plistPath = [[bundleRoot stringByAppendingPathComponent:item] stringByAppendingPathComponent:@"Info.plist"]; 
                NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:plistPath];
                NSString *exeName = [info[@"CFBundleExecutable"] isKindOfClass:[NSString class]] ? info[@"CFBundleExecutable"] : nil;
                if (exeName.length) {
                    PXKillallTermThenKill(exeName, 0.15);
                }
                break;
            }
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
        @"accountsd",
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
    if (!selfRef || !procName.length) return YES;
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    while (YES) {
        NSTimeInterval elapsed = CFAbsoluteTimeGetCurrent() - start;
        NSTimeInterval remaining = timeout - elapsed;
        if (remaining <= 0) {
            break;
        }

        NSTimeInterval probeTimeout = MIN(1.0, remaining);
        if (probeTimeout <= 0) {
            break;
        }

        NSString *cmd = [NSString stringWithFormat:@"pgrep -x '%@' 2>/dev/null | head -n 1", procName];
        NSString *out = [selfRef runCommandAndGetOutput:cmd timeoutSec:probeTimeout];
        if ([out isKindOfClass:[NSString class]] && out.length == 0) {
            return YES;
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

static BOOL PXNumberIsBooleanTrue(id value) {
    if (![value isKindOfClass:[NSNumber class]]) return NO;
    CFTypeRef cfValue = (__bridge CFTypeRef)value;
    return CFGetTypeID(cfValue) == CFBooleanGetTypeID() && [(NSNumber *)value boolValue];
}

static BOOL PXReadNonnegativeInteger(id value, NSUInteger *outValue) {
    if (![value isKindOfClass:[NSNumber class]]) return NO;
    CFTypeRef cfValue = (__bridge CFTypeRef)value;
    if (CFGetTypeID(cfValue) == CFBooleanGetTypeID()) return NO;
    const char *type = [(NSNumber *)value objCType];
    if (!type || !strchr("cCsSiIlLqQ", type[0])) return NO;
    long long signedValue = [(NSNumber *)value longLongValue];
    if (signedValue < 0) return NO;
    unsigned long long unsignedValue = [(NSNumber *)value unsignedLongLongValue];
    if (unsignedValue > (unsigned long long)NSUIntegerMax) return NO;
    if (outValue) *outValue = (NSUInteger)unsignedValue;
    return YES;
}

static BOOL PXKeychainBridgeResponseIsValid(id value,
                                            NSString *bundleIdentifier,
                                            NSString *nonce) {
    if (![value isKindOfClass:[NSDictionary class]] ||
        ![bundleIdentifier isKindOfClass:[NSString class]] ||
        ![nonce isKindOfClass:[NSString class]]) {
        return NO;
    }
    NSDictionary *response = (NSDictionary *)value;
    if (![response[@"nonce"] isKindOfClass:[NSString class]] ||
        ![response[@"nonce"] isEqualToString:nonce] ||
        ![response[@"bundleID"] isKindOfClass:[NSString class]] ||
        ![response[@"bundleID"] isEqualToString:bundleIdentifier] ||
        ![response[@"action"] isKindOfClass:[NSString class]] ||
        ![response[@"action"] isEqualToString:@"wipe"] ||
        !PXNumberIsBooleanTrue(response[@"ok"])) {
        return NO;
    }
    NSUInteger attempted = 0, succeeded = 0, failed = 0;
    if (!PXReadNonnegativeInteger(response[@"attempted"], &attempted) ||
        !PXReadNonnegativeInteger(response[@"succeeded"], &succeeded) ||
        !PXReadNonnegativeInteger(response[@"failed"], &failed) ||
        attempted == 0 ||
        succeeded > attempted ||
        failed != attempted - succeeded ||
        failed != 0 ||
        succeeded != attempted) {
        return NO;
    }
    return YES;
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

static NSDictionary *PXReadKeychainBridgeResponseIfValid(NSFileManager *fm, NSString *respPath, NSString *nonce) {
    if (!fm || !respPath.length || !nonce.length) return nil;
    if (![fm fileExistsAtPath:respPath]) return nil;
    NSDictionary *candidate = [NSDictionary dictionaryWithContentsOfFile:respPath];
    if (![candidate isKindOfClass:[NSDictionary class]]) return nil;
    NSString *n = [candidate[@"nonce"] isKindOfClass:[NSString class]] ? candidate[@"nonce"] : nil;
    if (!n.length || ![n isEqualToString:nonce]) return nil;
    return candidate;
}

static NSDictionary *PXWaitForKeychainBridgeResponse(NSString *safeBundle, NSString *respPath, NSString *nonce, NSTimeInterval timeoutSec) {
    if (!safeBundle.length || !respPath.length || !nonce.length) return nil;
    if (timeoutSec <= 0) timeoutSec = 20.0;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *immediate = PXReadKeychainBridgeResponseIfValid(fm, respPath, nonce);
    if (immediate) return immediate;

    NSString *notifyName = [NSString stringWithFormat:@"com.hydra.weaponx.keychain.resp.%@", safeBundle];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    dispatch_queue_t q = dispatch_queue_create("com.weaponx.keychainbridge.wait.cleaner", DISPATCH_QUEUE_SERIAL);
    __block NSDictionary *resp = nil;

    int token = 0;
    uint32_t st = notify_register_dispatch([notifyName UTF8String], &token, q, ^(int t) {
        (void)t;
        if (resp) return;
        NSDictionary *r = PXReadKeychainBridgeResponseIfValid(fm, respPath, nonce);
        if (r) {
            resp = r;
            dispatch_semaphore_signal(sema);
        }
    });

    if (st != NOTIFY_STATUS_OK) {
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        while ((CFAbsoluteTimeGetCurrent() - start) < timeoutSec) {
            NSDictionary *r = PXReadKeychainBridgeResponseIfValid(fm, respPath, nonce);
            if (r) return r;
            [NSThread sleepForTimeInterval:0.2];
        }
        return nil;
    }

    NSDictionary *afterReg = PXReadKeychainBridgeResponseIfValid(fm, respPath, nonce);
    if (afterReg) {
        notify_cancel(token);
        return afterReg;
    }

    dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeoutSec * NSEC_PER_SEC));
    (void)dispatch_semaphore_wait(sema, deadline);
    notify_cancel(token);

    if (resp) return resp;
    return PXReadKeychainBridgeResponseIfValid(fm, respPath, nonce);
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
                                               plannedPassCount:(systemApplication ? 1u : 2u)
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
    if (!systemApplication && !PXKeychainExactStringIsValid(applicationIdentifier)) {
        PXAssignKeychainNSError(error,
                                PXKeychainClearFailureCodeAuthorizationFailed,
                                @"Signed application identifier is required");
        return NO;
    }

    if (systemApplication) {
        NSString *safeBundle = [[bundleIdentifier componentsSeparatedByCharactersInSet:
            [[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@"_"];
        NSString *nonce = [[NSUUID UUID] UUIDString];
        NSString *requestPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_request_%@.plist", safeBundle];
        NSString *responsePath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_response_%@_%@.plist", safeBundle, nonce];
        NSString *logPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_bridge_%@_%@.log", safeBundle, nonce];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL success = NO;
        @try {
            [fileManager removeItemAtPath:requestPath error:nil];
            [fileManager removeItemAtPath:responsePath error:nil];
            NSDictionary *request = @{
                @"action": @"wipe",
                @"bundleID": bundleIdentifier,
                @"groups": selectedGroups,
                @"nonce": nonce,
                @"respPath": responsePath,
                @"logPath": logPath,
                @"bridgeOnly": @YES,
            };
            if (![request writeToFile:requestPath atomically:YES]) {
                PXAssignKeychainNSError(error,
                                        PXKeychainClearFailureCodeConfigurationFailed,
                                        @"Keychain bridge request could not be created");
                return NO;
            }

            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                (__bridge CFStringRef)[NSString stringWithFormat:@"com.hydra.weaponx.keychain.req.%@", safeBundle],
                NULL, NULL, true);
            Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
            BOOL opened = NO;
            if (workspaceClass) {
                id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
                if (workspace && [workspace respondsToSelector:@selector(openApplicationWithBundleID:)]) {
                    opened = ((BOOL (*)(id, SEL, id))objc_msgSend)(workspace,
                                                                  @selector(openApplicationWithBundleID:),
                                                                  bundleIdentifier);
                    NSString *selfBundle = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
                    if (selfBundle.length) {
                        ((BOOL (*)(id, SEL, id))objc_msgSend)(workspace,
                                                             @selector(openApplicationWithBundleID:),
                                                             selfBundle);
                    }
                }
            }
            NSDictionary *response = PXWaitForKeychainBridgeResponse(safeBundle,
                                                                      responsePath,
                                                                      nonce,
                                                                      opened ? 30.0 : 6.0);
            PXKillAppProcessBestEffort(self, bundleIdentifier);
            success = PXKeychainBridgeResponseIsValid(response, bundleIdentifier, nonce);
            if (!success) {
                PXAssignKeychainNSError(error,
                                        PXKeychainClearFailureCodeInternalResultFailure,
                                        @"Keychain bridge returned incomplete execution evidence");
            }
            return success;
        } @catch (__unused NSException *exception) {
            PXAssignKeychainNSError(error,
                                    PXKeychainClearFailureCodeInternalResultFailure,
                                    @"Keychain bridge execution failed");
            return NO;
        } @finally {
            PXKillAppProcessBestEffort(self, bundleIdentifier);
            [fileManager removeItemAtPath:requestPath error:nil];
            [fileManager removeItemAtPath:responsePath error:nil];
            [fileManager removeItemAtPath:[responsePath stringByAppendingString:@".tmp"] error:nil];
            [fileManager removeItemAtPath:logPath error:nil];
        }
    }

    CommandRunner *runner = [CommandRunner shared];
    NSString *ldidPath = [runner firstExistingPath:@[
        @"/usr/bin/ldid",
        @"/var/jb/usr/bin/ldid",
        @"/private/preboot/jb/usr/bin/ldid",
        @"/bin/ldid"
    ]];
    if (!ldidPath.length || ![ldidPath hasPrefix:@"/"]) {
        PXAssignKeychainNSError(error,
                                PXKeychainClearFailureCodeConfigurationFailed,
                                @"Keychain signing tool is unavailable");
        return NO;
    }
    NSString *helperPath = [runner firstExistingPath:@[
        @"/Library/WeaponX/backup_helper",
        @"/var/jb/Library/WeaponX/backup_helper",
        @"/private/var/jb/Library/WeaponX/backup_helper"
    ]];
    if (!helperPath.length || ![helperPath hasPrefix:@"/"]) {
        PXAssignKeychainNSError(error,
                                PXKeychainClearFailureCodeConfigurationFailed,
                                @"Keychain helper is unavailable");
        return NO;
    }

    NSString *temporaryDirectory = [NSString stringWithFormat:@"/tmp/keychain_wipe_%d_%@",
                                    getpid(), [[NSUUID UUID] UUIDString]];
    NSString *workingHelper = [temporaryDirectory stringByAppendingPathComponent:@"backup_helper"];
    NSString *entitlementsPath = [temporaryDirectory stringByAppendingPathComponent:@"helper_ent.plist"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL success = NO;
    @try {
        NSError *directoryError = nil;
        if (![fileManager createDirectoryAtPath:temporaryDirectory
                    withIntermediateDirectories:NO
                                     attributes:@{NSFilePosixPermissions: @0700}
                                          error:&directoryError]) {
            PXAssignKeychainNSError(error,
                                    PXKeychainClearFailureCodeConfigurationFailed,
                                    @"Temporary Keychain workspace could not be created");
            return NO;
        }
        NSError *copyError = nil;
        if (![fileManager copyItemAtPath:helperPath toPath:workingHelper error:&copyError]) {
            PXAssignKeychainNSError(error,
                                    PXKeychainClearFailureCodeConfigurationFailed,
                                    @"Keychain helper could not be prepared");
            return NO;
        }
        chmod(workingHelper.fileSystemRepresentation, 0755);

        NSDictionary *helperEntitlements = @{
            @"platform-application": @YES,
            @"application-identifier": applicationIdentifier,
            @"com.apple.private.security.no-sandbox": @YES,
            @"com.apple.private.security.no-container": @YES,
            @"com.apple.private.security.container-required": @NO,
            @"com.apple.keystore.access-keychain-keys": @YES,
            @"com.apple.keystore.device": @YES,
            @"keychain-access-groups": selectedGroups,
        };
        NSError *serializationError = nil;
        NSData *entitlementsData = [NSPropertyListSerialization dataWithPropertyList:helperEntitlements
                                                                               format:NSPropertyListXMLFormat_v1_0
                                                                              options:0
                                                                                error:&serializationError];
        NSError *writeError = nil;
        if (!entitlementsData.length || serializationError ||
            ![entitlementsData writeToFile:entitlementsPath
                                   options:NSDataWritingAtomic
                                     error:&writeError]) {
            PXAssignKeychainNSError(error,
                                    PXKeychainClearFailureCodeConfigurationFailed,
                                    @"Keychain helper authorization could not be prepared");
            return NO;
        }

        CommandResult *signResult = [runner runExecutableAndCapture:ldidPath
                                                           arguments:@[
                                                               [@"-S" stringByAppendingString:entitlementsPath],
                                                               workingHelper
                                                           ]
                                                          timeoutSec:60.0
                                                      maxOutputBytes:1024 * 1024];
        if (!PXBoundedCommandSucceeded(signResult)) {
            PXAssignKeychainNSError(error,
                                    PXKeychainClearFailureCodeInitialPassFailed,
                                    @"Keychain helper signing failed");
            return NO;
        }

        NSString *groupsCSV = [selectedGroups componentsJoinedByString:@","];
        CommandResult *wipeResult = [runner runExecutableAndCapture:workingHelper
                                                           arguments:@[
                                                               @"--action", @"wipe",
                                                               @"--groups", groupsCSV
                                                           ]
                                                          timeoutSec:120.0
                                                      maxOutputBytes:1024 * 1024];
        success = PXBoundedCommandSucceeded(wipeResult);
        NSDictionary *diagnostic = @{
            @"success": @(success),
            @"exitCode": @(wipeResult ? wipeResult.exitCode : -1),
            @"timedOut": @(wipeResult ? wipeResult.timedOut : NO),
            @"stdoutTruncated": @(wipeResult ? wipeResult.stdoutTruncated : NO),
            @"stderrTruncated": @(wipeResult ? wipeResult.stderrTruncated : NO),
            @"groupCount": @(selectedGroups.count),
        };
        [[NSUserDefaults standardUserDefaults] setObject:diagnostic
                                                  forKey:[NSString stringWithFormat:@"DataCleaningKeychainResult_%@",
                                                                                     bundleIdentifier]];
        [[NSUserDefaults standardUserDefaults] synchronize];
        if (!success) {
            PXAssignKeychainNSError(error,
                                    PXKeychainClearFailureCodeInitialPassFailed,
                                    @"Keychain helper execution failed");
        }
        return success;
    } @catch (__unused NSException *exception) {
        PXAssignKeychainNSError(error,
                                PXKeychainClearFailureCodeInternalResultFailure,
                                @"Keychain helper execution failed");
        return NO;
    } @finally {
        [fileManager removeItemAtPath:workingHelper error:nil];
        [fileManager removeItemAtPath:entitlementsPath error:nil];
        [fileManager removeItemAtPath:temporaryDirectory error:nil];
    }
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
    if ((plan.plannedPassCount != 1 && plan.plannedPassCount != 2) ||
        passResults.count != plan.plannedPassCount) {
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

    NSUInteger succeeded = 0;
    PXClearFailure *firstFailure = nil;
    for (NSUInteger index = 0; index < passResults.count; index++) {
        BOOL passSucceeded = [passResults[index] respondsToSelector:@selector(boolValue)] &&
                             [passResults[index] boolValue];
        if (passSucceeded) {
            succeeded++;
        } else if (!firstFailure) {
            PXKeychainClearFailureCode code = index == 0
                ? PXKeychainClearFailureCodeInitialPassFailed
                : PXKeychainClearFailureCodeFinalPassFailed;
            firstFailure = PXKeychainFailure(code,
                index == 0 ? @"Initial keychain wipe pass failed" : @"Final keychain wipe pass failed");
        }
    }
    NSUInteger failed = plan.plannedPassCount - succeeded;
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
                                               deepClean:request.deepClean];
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

    _wipeCacheExtensionDataCanonicalPaths = [extensionCanonicalPaths copy] ?: @[];
    _wipeCacheAppGroupCanonicalPaths = [appGroupCanonicalPaths copy] ?: @[];
    _wipeCachePluginKitDataCanonicalPaths = [pluginKitCanonicalPaths copy] ?: @[];

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
    [self logMessage:@"[AppDataCleaner] === STARTING data clearing for %@ ===", bundleID];

    BOOL deepClean = [self _deepCleanEnabled];
    PXClearRequest *fullRequest = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                            scopes:PXMigratedFullClearScopes
                                                                         deepClean:deepClean];
    PXClearRequest *dataRequest = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                            scopes:PXMigratedDataClearScopes
                                                                         deepClean:deepClean];
    if (!fullRequest || !dataRequest) {
        NSError *requestError = PXMigratedInternalError(@"Invalid full Clear request");
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(NO, requestError);
        });
        return;
    }

    __block BOOL completionCalled = NO;
    __block dispatch_semaphore_t completionLock = dispatch_semaphore_create(1);
    FreezeManager *freezer = [FreezeManager sharedManager];
    __block BOOL wasFrozen = [freezer isApplicationFrozen:bundleID];
    __block BOOL frozeForThisClear = NO;
    __weak typeof(self) weakSelf = self;
    __block UIBackgroundTaskIdentifier bgTask = UIBackgroundTaskInvalid;
    dispatch_async(dispatch_get_main_queue(), ^{
        bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"AppDataCleaner"
                                                              expirationHandler:^{}];
    });
    __block dispatch_source_t watchdogTimer = nil;

    void (^safeCompletion)(BOOL, NSError *) = ^(BOOL success, NSError *error) {
        dispatch_semaphore_wait(completionLock, DISPATCH_TIME_FOREVER);
        if (!completionCalled) {
            completionCalled = YES;
            dispatch_semaphore_signal(completionLock);
            if (frozeForThisClear) {
                @try { [freezer unfreezeApplication:bundleID]; }
                @catch (__unused NSException *exception) {}
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
            [weakSelf logMessage:@"[AppDataCleaner] Calling completion handler (success=%d)", success];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(success, error);
            });
        } else {
            dispatch_semaphore_signal(completionLock);
        }
    };

    BOOL isSystemApp = [bundleID hasPrefix:@"com.apple."];
    int timeoutSec = (deepClean || isSystemApp) ? (30 * 60) : 120;
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
        [weakSelf logMessage:@"[AppDataCleaner] WATCHDOG: %d second timeout reached", timeoutSec];
        safeCompletion(NO, [NSError errorWithDomain:@"AppDataCleaner"
                                               code:-100
                                           userInfo:@{NSLocalizedDescriptionKey: @"Clear Data timed out"}]);
    });
    dispatch_resume(watchdogTimer);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @autoreleasepool {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf logMessage:@"[AppDataCleaner] Background cleaning started for %@", bundleID];
            @try {
                [strongSelf logMessage:@"[AppDataCleaner] Step 0: Kill application..."];
                [strongSelf logMessage:@"[AppDataCleaner] Deep Clean (verify scan) = %@", deepClean ? @"ON" : @"OFF"];
                PXKillAppProcessBestEffort(strongSelf, bundleID);
                [NSThread sleepForTimeInterval:0.5];
                if ([bundleID isEqualToString:@"com.apple.mobilesafari"]) {
                    [strongSelf logMessage:@"[AppDataCleaner] MobileSafari: stopping WebKit/Safari helper processes..."];
                    PXStopSafariDaemonsBestEffort(strongSelf);
                }

                [strongSelf logMessage:@"[AppDataCleaner] Step 1: Planning and running initial Keychain pass..."];
                PXKeychainClearPlan *keychainPlan =
                    [strongSelf _keychainClearPlanForBundleIdentifier:fullRequest.bundleIdentifier];
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

                [strongSelf logMessage:@"[AppDataCleaner] Step 2: Clearing URL credentials..."];
                [strongSelf clearURLCredentialsForBundleID:bundleID];
                [strongSelf logMessage:@"[AppDataCleaner] Step 3: Clearing app state data..."];
                [strongSelf _internalClearAppStateData:bundleID];

                if (!wasFrozen) {
                    [strongSelf logMessage:@"[AppDataCleaner] Freezing app launch to prevent relaunch during wipe..."];
                    @try { [freezer freezeApplication:bundleID]; }
                    @catch (__unused NSException *exception) {}
                    frozeForThisClear = [freezer isApplicationFrozen:bundleID];
                }

                [strongSelf logMessage:@"[AppDataCleaner] Step 4: Running four-scope data aggregate..."];
                PXClearResult *dataResult = [strongSelf _completeDataWipeForMigratedRequest:dataRequest];
                NSArray<PXClearComponentResult *> *dataComponents = nil;
                if (PXMigratedDataClearResultIsStructurallyValid(dataResult)) {
                    dataComponents = dataResult.componentResults;
                } else {
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

                [strongSelf logMessage:@"[AppDataCleaner] Step 5: Clearing HTTP cookies from memory..."];
                NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
                NSArray *allCookies = [[cookieStorage cookies] copy];
                for (NSHTTPCookie *cookie in allCookies) [cookieStorage deleteCookie:cookie];
                [strongSelf logMessage:@"[AppDataCleaner] Cleared %lu cookies from memory",
                    (unsigned long)allCookies.count];

                [strongSelf logMessage:@"[AppDataCleaner] Step 6: Running planned final Keychain pass..."];
                if (keychainPlan.planningFailureCode == 0 &&
                    keychainPlan.skipDetail.length == 0 &&
                    keychainPlan.plannedPassCount == 2) {
                    NSError *finalPassError = nil;
                    BOOL finalPassSucceeded = [strongSelf
                        _executeKeychainWipeForBundleIdentifier:keychainPlan.bundleIdentifier
                                                selectedGroups:keychainPlan.selectedGroups
                                         applicationIdentifier:keychainPlan.applicationIdentifier
                                            systemApplication:keychainPlan.systemApplication
                                                        error:&finalPassError];
                    [keychainPassResults addObject:@(finalPassSucceeded)];
                    if (!finalPassSucceeded) {
                        [strongSelf logMessage:@"[AppDataCleaner] Final Keychain pass failed (%@:%ld)",
                            finalPassError.domain ?: PXKeychainClearFailureDomain,
                            (long)finalPassError.code];
                    }
                }

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

                [strongSelf logMessage:@"[AppDataCleaner] Step 7: Syncing filesystem..."];
                sync();
                [strongSelf logMessage:@"[AppDataCleaner] Step 8: Verifying clear result (log-only)..."];
                BOOL clearVerified = [strongSelf verifyDataCleared:bundleID];
                if (!clearVerified) {
                    [strongSelf logMessage:@"[AppDataCleaner] WARNING: broad verification found residual data"];
                }

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
            }
        }
    });

    [self logMessage:@"[AppDataCleaner] clearDataForBundleID returned immediately"];
}

#pragma mark - Improved Rootless-Compatible App Data Wiping

- (void)completeAppDataWipe:(NSString *)bundleID {
    BOOL deepClean = [self _deepCleanEnabled];
    PXClearRequest *request = [[PXClearRequest alloc] initWithBundleIdentifier:bundleID
                                                                        scopes:PXMigratedDataClearScopes
                                                                     deepClean:deepClean];
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

    // Cache canonical paths in rootful/rootless order; never reconstruct them from UUIDs.
    _wipeCacheBundleID = [bundleID copy];
    _wipeCacheApplicationDataCanonicalPaths = [canonicalApplicationDataPaths copy] ?: @[];

    [self logMessage:@"[AppDataCleaner] ApplicationData roots attempted=%lu succeeded=%lu failed=%lu",
          (unsigned long)attemptedUnits,
          (unsigned long)succeededUnits,
          (unsigned long)failedUnits];

    // Clear App Store receipt
    [self clearAppReceiptData:bundleID withBundleUUID:nil];
    
    // Extra cleanup for MobileMail: email/account display is primarily system-scoped (Accounts3 + /var/mobile/Library/Mail).
    if ([bundleID isEqualToString:@"com.apple.mobilemail"]) {
        [self logMessage:@"[AppDataCleaner] MobileMail: wiping /var/mobile/Library/Mail and mail prefs"]; 

        // Stop mail-related daemons and wait for exit to avoid maild SIGABRT on detached DB.
        PXStopMailDaemonsBestEffort(self);
        if (!PXWaitForProcessExit(self, @"maild", 5.0)) {
            [self logMessage:@"[AppDataCleaner] MobileMail: maild still running; forcing kill"]; 
            PXKillallByName(@"maild", SIGKILL);
            (void)PXWaitForProcessExit(self, @"maild", 2.0);
        }
        (void)PXWaitForProcessExit(self, @"Mail", 2.0);

        // Avoid detaching an open sqlite DB: quarantine the Mail directory via rename.
        // If any lingering maild instance still holds files open, rename is safe; rm -rf can trigger SIGABRT later.
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

        // Keep maild stopped while accounts cleanup runs.
        PXStopMailDaemonsBestEffort(self);

        // Best-effort remove Mail account rows from Accounts3 (schema varies by iOS; keep scoped to mail-type identifiers).
        NSString *accountsDB = @"/var/mobile/Library/Accounts/Accounts3.sqlite";
        if ([_fileManager fileExistsAtPath:accountsDB]) {
            // Stop accountsd before touching DB (avoid "database is locked").
            // Use TERM first to reduce crash reports.
            PXKillallTermThenKill(@"accountsd", 0.15);
            [NSThread sleepForTimeInterval:0.2];

            // Use one RW connection for before/delete/after to avoid transient CANTOPEN.
            sqlite3 *db = NULL;
            int rc = sqlite3_open_v2(accountsDB.UTF8String, &db, SQLITE_OPEN_READWRITE, NULL);
            if (rc != SQLITE_OK || !db) {
                NSString *msg = db ? [NSString stringWithUTF8String:sqlite3_errmsg(db)] : @"open failed";
                [self logMessage:@"[AppDataCleaner] MobileMail: Accounts3 open failed rc=%d %@", rc, msg ?: @""];
                if (db) sqlite3_close(db);
            } else {
                sqlite3_busy_timeout(db, 3000);

                NSString *beforeCount = PXSQLiteScalar(db, @"SELECT count(*) FROM ZACCOUNT;");
                [self logMessage:@"[AppDataCleaner] MobileMail: Accounts3 ZACCOUNT count before=%@", beforeCount ?: @"(nil)"];

                // Identify mail-related account types.
                NSString *typeCount = PXSQLiteScalar(db,
                    @"SELECT count(*) FROM ZACCOUNTTYPE WHERE "
                    "ZIDENTIFIER LIKE '%mail%' OR ZIDENTIFIER LIKE '%imap%' OR ZIDENTIFIER LIKE '%smtp%' OR ZIDENTIFIER LIKE '%exchange%' OR "
                    "ZIDENTIFIER LIKE '%google%' OR ZIDENTIFIER LIKE '%gmail%';");
                [self logMessage:@"[AppDataCleaner] MobileMail: mail-ish/google-ish account types=%@", typeCount ?: @"(nil)"];

                NSString *errMsg = nil;
                PXSQLiteExec(db, @"PRAGMA busy_timeout=3000;", NULL);
                PXSQLiteExec(db, @"BEGIN IMMEDIATE;", &errMsg);
                if (errMsg.length) {
                    [self logMessage:@"[AppDataCleaner] MobileMail: BEGIN IMMEDIATE failed %@", errMsg];
                    errMsg = nil;
                }

                // Delete matching accounts and best-effort related rows.
                // We intentionally ignore errors for tables that may not exist on some iOS versions.
                // For Gmail accounts configured in Mail, the underlying account type is often Google-based
                // (e.g. com.apple.account.Google) and may not match mail/imap/smtp identifiers.
                NSString *deleteAccounts =
                    @"DELETE FROM ZACCOUNT WHERE ZACCOUNTTYPE IN (SELECT Z_PK FROM ZACCOUNTTYPE WHERE "
                    "ZIDENTIFIER LIKE '%mail%' OR ZIDENTIFIER LIKE '%imap%' OR ZIDENTIFIER LIKE '%smtp%' OR ZIDENTIFIER LIKE '%exchange%' OR "
                    "ZIDENTIFIER LIKE '%google%' OR ZIDENTIFIER LIKE '%gmail%');";
                BOOL delOK = PXSQLiteExec(db, deleteAccounts, &errMsg);
                int changes = sqlite3_changes(db);
                [self logMessage:@"[AppDataCleaner] MobileMail: ZACCOUNT delete ok=%d changes=%d %@", delOK, changes, errMsg.length ? errMsg : @""];
                errMsg = nil;

                // Companion tables are schema-dependent. Try deletes if they exist; ignore failures.
                // (We do not assume these tables exist on all iOS versions.)
                PXSQLiteExec(db, @"DELETE FROM ZACCOUNTPROPERTY WHERE ZOWNER IN (SELECT Z_PK FROM ZACCOUNT);", NULL);
                PXSQLiteExec(db, @"DELETE FROM ZCREDENTIALITEM WHERE ZOWNER IN (SELECT Z_PK FROM ZACCOUNT);", NULL);

                PXSQLiteExec(db, @"COMMIT;", &errMsg);
                if (errMsg.length) {
                    [self logMessage:@"[AppDataCleaner] MobileMail: COMMIT failed %@", errMsg];
                    errMsg = nil;
                }
                PXSQLiteExec(db, @"PRAGMA wal_checkpoint(TRUNCATE);", NULL);

                NSString *afterCount = PXSQLiteScalar(db, @"SELECT count(*) FROM ZACCOUNT;");
                [self logMessage:@"[AppDataCleaner] MobileMail: Accounts3 ZACCOUNT count after=%@", afterCount ?: @"(nil)"];

                // If accounts remain, log a few account type identifiers for debugging.
                NSString *sample = nil;
                sqlite3_stmt *st = NULL;
                if (sqlite3_prepare_v2(db, "SELECT ZIDENTIFIER FROM ZACCOUNTTYPE LIMIT 12;", -1, &st, NULL) == SQLITE_OK && st) {
                    NSMutableArray *ids = [NSMutableArray array];
                    while (sqlite3_step(st) == SQLITE_ROW) {
                        const unsigned char *txt = sqlite3_column_text(st, 0);
                        if (txt) [ids addObject:[NSString stringWithUTF8String:(const char *)txt]];
                    }
                    sqlite3_finalize(st);
                    sample = [ids componentsJoinedByString:@", "];
                } else if (st) {
                    sqlite3_finalize(st);
                }
                if (sample.length) {
                    [self logMessage:@"[AppDataCleaner] MobileMail: ZACCOUNTTYPE sample=%@", sample];
                }

                sqlite3_close(db);
            }
        }

        // Restart accounts daemons (best-effort) so UI reflects removal.
        PXKillallByName(@"accountsd", SIGTERM);
        PXKillallByName(@"Mail", SIGTERM);
        [NSThread sleepForTimeInterval:0.15];
        PXKillallByName(@"accountsd", SIGKILL);
        PXKillallByName(@"Mail", SIGKILL);

        // Do not auto-restart maild; let launchd bring it back when needed.

        // IMPORTANT: Do not delete the quarantined old store in the same run.
        // maild can still have open sqlite connections or scheduled vacuum activities; deleting can cause SIGABRT
        // (detached database IO error). Leaving it avoids crashes; user can delete later (e.g. after reboot).
        if ([trashPath hasPrefix:@"/var/mobile/Library/Mail.WeaponXTrash."]) {
            [self logMessage:@"[AppDataCleaner] MobileMail: kept old store at %@ (safe).", trashPath];
        }
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

    // Clear iCloud-related data
    [self logMessage:@"[AppDataCleaner] Clearing iCloud-related data"]; 
    CFAbsoluteTime t0 = CFAbsoluteTimeGetCurrent();
    [self clearICloudData:bundleID];
    [self logMessage:@"[AppDataCleaner] iCloud cleanup took %.2fs", CFAbsoluteTimeGetCurrent() - t0];
    
    // Clear app state data - SKIP second call to avoid respring
    // [self _internalClearAppStateData:bundleID];
    
    // URL credentials are cleared by clearDataForBundleID.
    
    // Clear encrypted data 
    [self logMessage:@"[AppDataCleaner] DEBUG: Clearing encrypted data..."];
    [self _internalClearEncryptedDataOutsideMainApplicationContainer:bundleID deepClean:request.deepClean];
    
    // Clear Spotlight data
    [self logMessage:@"[AppDataCleaner] DEBUG: Clearing Spotlight indexes..."];
    [self clearSpotlightIndexes:bundleID];
    
    // Skip slow media/health/safari clearing for now
    [self logMessage:@"[AppDataCleaner] DEBUG: Skipping media/health/safari (optimization)"];
    // [self clearMediaData:bundleID];
    // [self clearHealthData:bundleID];

    // Safari is special: it uses system-scoped stores under /var/mobile/Library.
    // Without clearing those, sessions/cookies can persist even after wiping the app container.
    if ([bundleID isEqualToString:@"com.apple.mobilesafari"]) {
        [self _wipeMobileSafariSystemStores];
    }
    
    // Clean SiriAnalytics
    [self logMessage:@"[AppDataCleaner] DEBUG: Cleaning Siri analytics..."];
    [self cleanSiriAnalyticsDatabase:bundleID];
    
    // Skip these - they modify system state and can cause respring:
    // [self cleanIconStatePlist:bundleID];
    // [self cleanLaunchServicesDatabase:bundleID];
    
    // SAFE to run now (modified to avoid respring)
    [self refreshSystemServices];
    
    [self logMessage:@"[AppDataCleaner] Skipped unsafe system state modifications"];
    
    // NOTE: Universal keychain wipe removed (too broad / can delete unrelated items).

    // Sweep for crash logs and system logs.
    [self removeCrashLogsForBundleID:bundleID];

    // Main application-data final sweep is read-only and consumes the canonical path cache directly.
    for (NSString *canonicalPath in (_wipeCacheApplicationDataCanonicalPaths ?: @[])) {
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
    NSArray *crashLogDirs = @[
        @"/var/mobile/Library/Logs/CrashReporter",
        @"/private/var/logs/CrashReporter"
    ];
    for (NSString *dir in crashLogDirs) {
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *file in contents) {
            if ([file containsString:bundleID]) {
                NSString *fullPath = [dir stringByAppendingPathComponent:file];
                [self fixPermissionsAndRemovePath:fullPath];
                if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
                    NSLog(@"[AppDataCleaner][CrashLogSweep] Could not delete crash log: %@", fullPath);
                }
            }
        }
    }
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
    NSLog(@"[AppDataCleaner] Clearing Spotlight indexes for %@", bundleID);
    
    // Use reflection to check if CoreSpotlight is available
    Class csSearchableIndexClass = NSClassFromString(@"CSSearchableIndex");
    if (csSearchableIndexClass) {
        // Use performSelector to avoid direct link dependency
        id defaultIndex = [csSearchableIndexClass performSelector:@selector(defaultSearchableIndex)];
        if (defaultIndex && [defaultIndex respondsToSelector:@selector(deleteSearchableItemsWithDomainIdentifiers:completionHandler:)]) {
            NSLog(@"[AppDataCleaner] Using CSSearchableIndex to clear Spotlight data");
            
            // Create dispatch group to wait for completion
            dispatch_group_t group = dispatch_group_create();
            dispatch_group_enter(group);
            
            // Delete searchable items
            [defaultIndex performSelector:@selector(deleteSearchableItemsWithDomainIdentifiers:completionHandler:) 
                               withObject:@[bundleID]
                               withObject:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"[AppDataCleaner] Error clearing Spotlight indexes: %@", error.localizedDescription);
                } else {
                    NSLog(@"[AppDataCleaner] Spotlight indexes cleared successfully");
                }
                dispatch_group_leave(group);
            }];
            
            // Wait for completion with timeout
            dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC);
            dispatch_group_wait(group, timeout);
        }
    }
    
    // Also manually clear Spotlight directories regardless of API result
    NSArray *spotlightPaths = @[
        [NSString stringWithFormat:@"/var/mobile/Library/Spotlight/%@*", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Spotlight/%@*", bundleID],
        @"/var/mobile/Library/Caches/com.apple.Spotlight*",
        @"/var/mobile/Library/Caches/com.apple.Spotlight*"
    ];
    
    for (NSString *pattern in spotlightPaths) {
            NSArray *matches = [self findPathsMatchingPattern:pattern];
            for (NSString *path in matches) {
            NSLog(@"[AppDataCleaner] Removing Spotlight file: %@", path);
                [self securelyWipeFile:path];
        }
    }
}

#pragma mark - UUID Finding Methods

- (NSString *)findBundleUUID:(NSString *)bundleID {
    NSArray *bundleDirs = [self listDirectoriesInPath:@"/var/containers/Bundle/Application"];
    
    for (NSString *uuid in bundleDirs) {
        NSString *appPath = [NSString stringWithFormat:@"/var/containers/Bundle/Application/%@", uuid];
        NSArray *appContents = [self listDirectoriesInPath:appPath];
        
        for (NSString *item in appContents) {
            if ([item hasSuffix:@".app"]) {
                NSString *infoPlistPath = [NSString stringWithFormat:@"/var/containers/Bundle/Application/%@/%@/Info.plist", 
                                          uuid, item];
                NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
                NSString *itemBundleID = infoPlist[@"CFBundleIdentifier"];
                
                if ([itemBundleID isEqualToString:bundleID]) {
                    return uuid;
                }
            }
        }
    }
    
    // Try rootless path if standard path didn't work
    if ([self directoryHasContent:@"/containers/Bundle/Application"]) {
        NSArray *bundleDirs = [self listDirectoriesInPath:@"/containers/Bundle/Application"];
        
        for (NSString *uuid in bundleDirs) {
            NSString *appPath = [NSString stringWithFormat:@"/containers/Bundle/Application/%@", uuid];
            NSArray *appContents = [self listDirectoriesInPath:appPath];
            
            for (NSString *item in appContents) {
                if ([item hasSuffix:@".app"]) {
                    NSString *infoPlistPath = [NSString stringWithFormat:@"/containers/Bundle/Application/%@/%@/Info.plist", 
                                              uuid, item];
                    NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
                    NSString *itemBundleID = infoPlist[@"CFBundleIdentifier"];
                    
                    if ([itemBundleID isEqualToString:bundleID]) {
                        return uuid;
                    }
                }
            }
        }
    }
    
    return nil;
}

- (NSString *)findDataContainerUUID:(NSString *)bundleID aggressive:(BOOL)aggressive {
    // Extract company and app short name
    NSArray *parts = [bundleID componentsSeparatedByString:@"."];
    NSString *company = parts.count > 1 ? parts[1] : @"";
    NSString *shortName = parts.lastObject;
    NSArray *dataDirs = [self listDirectoriesInPath:@"/var/mobile/Containers/Data/Application"];
    for (NSString *uuid in dataDirs) {
        NSString *metadataPath = [NSString stringWithFormat:@"/var/mobile/Containers/Data/Application/%@/.com.apple.mobile_container_manager.metadata.plist", uuid];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        NSString *containerBundleID = metadata[@"MCMMetadataIdentifier"];
        // 1. Exact match
        if ([containerBundleID isEqualToString:bundleID]) return uuid;
        // 2. Aggressive/fuzzy matching
        if (aggressive) {
            if ([containerBundleID containsString:bundleID] ||
                (company.length && [containerBundleID containsString:company]) ||
                (shortName.length && [containerBundleID containsString:shortName])) {
                NSLog(@"[AppDataCleaner][Aggressive] Matched data container %@ by fuzzy metadata: %@", uuid, containerBundleID);
                return uuid;
            }
            // 3. Scan for app-named files/dirs
            NSString *containerPath = [NSString stringWithFormat:@"/var/mobile/Containers/Data/Application/%@", uuid];
            NSArray *contents = [self listDirectoriesInPath:containerPath];
            for (NSString *item in contents) {
                if (([item containsString:bundleID] ||
                     (company.length && [item containsString:company]) ||
                     (shortName.length && [item containsString:shortName]))) {
                    NSLog(@"[AppDataCleaner][Aggressive] Matched data container %@ by file/dir: %@", uuid, item);
                    return uuid;
                }
            }
        }
    }
    return nil;
}

// Backwards compatibility: default aggressive to YES
- (NSString *)findDataContainerUUID:(NSString *)bundleID {
    return [self findDataContainerUUID:bundleID aggressive:YES];
    NSLog(@"[AppDataCleaner] Searching for data container UUID for %@", bundleID);
    
    NSArray *dataDirs = [self listDirectoriesInPath:@"/var/mobile/Containers/Data/Application"];
    NSLog(@"[AppDataCleaner] Found %lu application data containers", (unsigned long)dataDirs.count);
    
    for (NSString *uuid in dataDirs) {
        NSString *metadataPath = [NSString stringWithFormat:@"/var/mobile/Containers/Data/Application/%@/.com.apple.mobile_container_manager.metadata.plist", uuid];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        NSString *containerBundleID = metadata[@"MCMMetadataIdentifier"];
        
        if ([containerBundleID isEqualToString:bundleID]) {
            NSLog(@"[AppDataCleaner] Found data container UUID: %@ for %@", uuid, bundleID);
            return uuid;
        }
    }
    
    NSLog(@"[AppDataCleaner] No data container found for %@", bundleID);
    return nil;
}

- (NSString *)findRootlessDataContainerUUID:(NSString *)bundleID aggressive:(BOOL)aggressive {
    NSArray *parts = [bundleID componentsSeparatedByString:@"."];
    NSString *company = parts.count > 1 ? parts[1] : @"";
    NSString *shortName = parts.lastObject;
    if (![_fileManager fileExistsAtPath:@"/containers/Data/Application"]) return nil;
    NSArray *dataDirs = [self listDirectoriesInPath:@"/containers/Data/Application"];
    for (NSString *uuid in dataDirs) {
        NSString *metadataPath = [NSString stringWithFormat:@"/containers/Data/Application/%@/.com.apple.mobile_container_manager.metadata.plist", uuid];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        NSString *containerBundleID = metadata[@"MCMMetadataIdentifier"];
        if ([containerBundleID isEqualToString:bundleID]) return uuid;
        if (aggressive) {
            if ([containerBundleID containsString:bundleID] ||
                (company.length && [containerBundleID containsString:company]) ||
                (shortName.length && [containerBundleID containsString:shortName])) {
                NSLog(@"[AppDataCleaner][Aggressive] Matched rootless data container %@ by fuzzy metadata: %@", uuid, containerBundleID);
                return uuid;
            }
            NSString *containerPath = [NSString stringWithFormat:@"/containers/Data/Application/%@", uuid];
            NSArray *contents = [self listDirectoriesInPath:containerPath];
            for (NSString *item in contents) {
                if (([item containsString:bundleID] ||
                     (company.length && [item containsString:company]) ||
                     (shortName.length && [item containsString:shortName]))) {
                    NSLog(@"[AppDataCleaner][Aggressive] Matched rootless data container %@ by file/dir: %@", uuid, item);
                    return uuid;
                }
            }
        }
    }
    return nil;
}

- (NSString *)findRootlessDataContainerUUID:(NSString *)bundleID {
    return [self findRootlessDataContainerUUID:bundleID aggressive:YES];
    NSLog(@"[AppDataCleaner] Searching for rootless data container UUID for %@", bundleID);
    
    if (![_fileManager fileExistsAtPath:@"/containers/Data/Application"]) {
        NSLog(@"[AppDataCleaner] Rootless data containers directory doesn't exist");
        return nil;
    }
    
    NSArray *dataDirs = [self listDirectoriesInPath:@"/containers/Data/Application"];
    NSLog(@"[AppDataCleaner] Found %lu rootless application data containers", (unsigned long)dataDirs.count);
    
    for (NSString *uuid in dataDirs) {
        NSString *metadataPath = [NSString stringWithFormat:@"/containers/Data/Application/%@/.com.apple.mobile_container_manager.metadata.plist", uuid];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        NSString *containerBundleID = metadata[@"MCMMetadataIdentifier"];
        
        if ([containerBundleID isEqualToString:bundleID]) {
            NSLog(@"[AppDataCleaner] Found rootless data container UUID: %@ for %@", uuid, bundleID);
            return uuid;
        }
    }
    
    NSLog(@"[AppDataCleaner] No rootless data container found for %@", bundleID);
    return nil;
}

- (NSArray *)findAppGroupUUIDs:(NSString *)bundleID aggressive:(BOOL)aggressive {
    NSMutableArray *groupUUIDs = [NSMutableArray array];
    NSArray *groupDirs = [self listDirectoriesInPath:@"/var/mobile/Containers/Shared/AppGroup"];
    NSArray *parts = [bundleID componentsSeparatedByString:@"."];
    NSString *company = parts.count > 1 ? parts[1] : @"";
    NSString *shortName = parts.lastObject;
    for (NSString *uuid in groupDirs) {
        NSString *metadataPath = [NSString stringWithFormat:@"/var/mobile/Containers/Shared/AppGroup/%@/.com.apple.mobile_container_manager.metadata.plist", uuid];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        id groupIdentifier = metadata[@"MCMMetadataIdentifier"];
        if ([groupIdentifier isKindOfClass:[NSArray class]]) {
            if ([(NSArray *)groupIdentifier containsObject:bundleID]) {
                [groupUUIDs addObject:uuid];
                continue;
            }
        } else if ([groupIdentifier isKindOfClass:[NSString class]]) {
            if ([(NSString *)groupIdentifier containsString:bundleID]) {
                [groupUUIDs addObject:uuid];
                continue;
            }
        }
        if (aggressive) {
            // Fuzzy match company/app name
            if (([groupIdentifier isKindOfClass:[NSString class]] &&
                 ((company.length && [groupIdentifier containsString:company]) ||
                  (shortName.length && [groupIdentifier containsString:shortName])))) {
                NSLog(@"[AppDataCleaner][Aggressive] Matched app group %@ by fuzzy metadata: %@", uuid, groupIdentifier);
                [groupUUIDs addObject:uuid];
                continue;
            }
            // Scan for files/dirs
            NSString *containerPath = [NSString stringWithFormat:@"/var/mobile/Containers/Shared/AppGroup/%@", uuid];
            NSArray *contents = [self listDirectoriesInPath:containerPath];
            for (NSString *item in contents) {
                if (([item containsString:bundleID] ||
                     (company.length && [item containsString:company]) ||
                     (shortName.length && [item containsString:shortName]))) {
                    NSLog(@"[AppDataCleaner][Aggressive] Matched app group %@ by file/dir: %@", uuid, item);
                    [groupUUIDs addObject:uuid];
                    break;
                }
            }
        }
    }
    return groupUUIDs;
}

- (NSArray *)findAppGroupUUIDs:(NSString *)bundleID {
    return [self findAppGroupUUIDs:bundleID aggressive:YES];
    NSMutableArray *groupUUIDs = [NSMutableArray array];
    NSArray *groupDirs = [self listDirectoriesInPath:@"/var/mobile/Containers/Shared/AppGroup"];
    
    for (NSString *uuid in groupDirs) {
        NSString *metadataPath = [NSString stringWithFormat:@"/var/mobile/Containers/Shared/AppGroup/%@/.com.apple.mobile_container_manager.metadata.plist", uuid];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        
        // App groups may have different metadata structure
        id groupIdentifier = metadata[@"MCMMetadataIdentifier"];
        
        if ([groupIdentifier isKindOfClass:[NSArray class]]) {
            // Check if bundle ID is in the apps array
            if ([(NSArray *)groupIdentifier containsObject:bundleID]) {
                [groupUUIDs addObject:uuid];
            }
        } else if ([groupIdentifier isKindOfClass:[NSString class]]) {
            // Some older iOS versions store just the group ID
            // Check if bundle ID is part of the group ID
            if ([(NSString *)groupIdentifier containsString:bundleID]) {
                [groupUUIDs addObject:uuid];
            }
        }
    }
    
    return groupUUIDs;
}

- (NSArray *)findRootlessAppGroupUUIDs:(NSString *)bundleID {
    if (!bundleID.length) return @[];

    // Use entitlements + resolver; filter only /containers-based results.
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
    NSMutableArray<NSString *> *uuids = [NSMutableArray array];
    for (AppGroupContainerInfo *info in infos) {
        if (![info.path isKindOfClass:[NSString class]] || !info.path.length) continue;
        if (![info.path hasPrefix:@"/containers/Shared/AppGroup/"]) continue;
        [uuids addObject:[info.path lastPathComponent]];
    }
    return uuids;
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
    NSLog(@"[AppDataCleaner] Clearing URL credentials for %@", bundleID);
    
    // Get URL credential storage
    NSURLCredentialStorage *storage = [NSURLCredentialStorage sharedCredentialStorage];
    
    // Get all the host/protection space combinations
    NSDictionary *allCredentials = [storage allCredentials];
    
    // Parse out domain names from the bundle ID (like 'uber' from 'com.ubercab.UberClient')
    NSArray *bundleComponents = [bundleID componentsSeparatedByString:@"."];
    NSMutableArray *possibleDomains = [NSMutableArray array];
    for (NSString *component in bundleComponents) {
        if (component.length > 3 && ![component isEqualToString:@"com"] && 
            ![component isEqualToString:@"org"] && ![component isEqualToString:@"net"]) {
            [possibleDomains addObject:component];
        }
    }
    
    // Loop through all credentials and remove any that might be related to this app
    for (NSURLProtectionSpace *protectionSpace in allCredentials.allKeys) {
        BOOL shouldClear = NO;
        
        // Check if host matches any possible domain
        for (NSString *domain in possibleDomains) {
            if ([protectionSpace.host containsString:domain]) {
                shouldClear = YES;
                break;
            }
        }
        
        // Also check for matches in the realm
        if (!shouldClear && protectionSpace.realm) {
            for (NSString *domain in possibleDomains) {
                if ([protectionSpace.realm containsString:domain]) {
                    shouldClear = YES;
                    break;
                }
            }
        }
        
        if (shouldClear) {
            NSDictionary *credentials = [storage credentialsForProtectionSpace:protectionSpace];
            for (NSString *username in credentials.allKeys) {
                NSURLCredential *credential = credentials[username];
                [storage removeCredential:credential forProtectionSpace:protectionSpace];
                NSLog(@"[AppDataCleaner] Removed credential for %@ at %@", username, protectionSpace.host);
            }
        }
    }
}

- (void)cleanRootHideVarData:(NSString *)bundleID {
    NSLog(@"[AppDataCleaner] Cleaning RootHide var data for %@", bundleID);
    
    // RootHide stores some data in these locations
    NSArray *rootHidePaths = @[
        [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@*.plist", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Caches/%@", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Caches/%@*", bundleID],
        [NSString stringWithFormat:@"/var/tmp/%@*", bundleID],
        [NSString stringWithFormat:@"/tmp/%@*", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/WebKit/WebsiteData/%@*", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Application Support/%@*", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Cookies/%@*", bundleID],
        // RootHide specific paths
        [NSString stringWithFormat:@"/var/root/Library/Preferences/%@*.plist", bundleID],
        [NSString stringWithFormat:@"/private/var/mobile/Library/Preferences/%@*.plist", bundleID]
    ];
    
    for (NSString *pattern in rootHidePaths) {
        NSArray *matches = [self findPathsMatchingPattern:pattern];
        for (NSString *path in matches) {
            NSLog(@"[AppDataCleaner] Wiping RootHide path: %@", path);
            [self securelyWipeFile:path];
        }
    }
    
    // Use elevated permissions to ensure clean var
    [self runCommandWithPrivileges:[NSString stringWithFormat:@"rm -rf /var/mobile/Library/Caches/%@*", bundleID]];
    [self runCommandWithPrivileges:[NSString stringWithFormat:@"rm -rf /var/mobile/Library/Preferences/%@*", bundleID]];
    [self runCommandWithPrivileges:[NSString stringWithFormat:@"rm -rf /var/root/Library/Preferences/%@*", bundleID]];
    [self runCommandWithPrivileges:[NSString stringWithFormat:@"rm -rf /private/var/mobile/Library/Preferences/%@*", bundleID]];
}

- (void)clearPluginKitData:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)clearThumbnailCaches:(NSString *)bundleID {
    NSArray *paths = @[
        [NSString stringWithFormat:@"/var/mobile/Library/Caches/com.apple.thumbnailservices/%@*", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Caches/com.apple.QuickLook.thumbnailcache/%@*", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Caches/com.apple.thumbnailservices/%@*", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Caches/com.apple.QuickLook.thumbnailcache/%@*", bundleID]
    ];
    
    for (NSString *pattern in paths) {
        NSArray *matches = [self findPathsMatchingPattern:pattern];
        for (NSString *path in matches) {
            NSLog(@"[AppDataCleaner] Wiping thumbnail cache: %@", path);
            [self securelyWipeFile:path];
        }
    }
}

- (void)clearICloudData:(NSString *)bundleID {
    [self logMessage:@"[AppDataCleaner] Clearing iCloud-related data for %@", bundleID];

    // Keep the broad iCloud/CloudKit/CloudDocs/Accounts cleanup behavior, but optimize it:
    // - avoid repeated deep "**" scans with many find calls
    // - fast mode (Deep Clean OFF): shallow maxdepth scan (still wipes top-level app containers)
    // - deep mode (Deep Clean ON): deeper scan

    BOOL deep = [self _deepCleanEnabled];
    int maxDepth = deep ? 8 : 2;
    int findTimeout = deep ? (25 * 60) : (8 * 60);

    NSArray *bundleComponents = [bundleID componentsSeparatedByString:@"."];
    NSString *tildeID = [[bundleID stringByReplacingOccurrencesOfString:@"." withString:@"~"] stringByReplacingOccurrencesOfString:@"-" withString:@"~"]; 
    NSString *iCloudTilde = tildeID.length ? [NSString stringWithFormat:@"iCloud~%@", tildeID] : @"";

    NSMutableOrderedSet<NSString *> *searchSet = [NSMutableOrderedSet orderedSet];
    if (bundleID.length) [searchSet addObject:bundleID];
    if (tildeID.length) [searchSet addObject:tildeID];
    if (iCloudTilde.length) [searchSet addObject:iCloudTilde];

    for (NSString *component in bundleComponents) {
        if (component.length > 3 && ![component isEqualToString:@"com"] && ![component isEqualToString:@"org"] && ![component isEqualToString:@"net"]) {
            [searchSet addObject:component];
            [searchSet addObject:[NSString stringWithFormat:@"iCloud.%@", component]];
            [searchSet addObject:[NSString stringWithFormat:@"%@.icloud", component]];
            [searchSet addObject:[NSString stringWithFormat:@"com.apple.CloudDocs.%@", component]];
        }
    }

    // Dedupe lowercased variants
    NSMutableOrderedSet<NSString *> *finalTerms = [NSMutableOrderedSet orderedSet];
    for (NSString *t in searchSet) {
        if (![t isKindOfClass:[NSString class]] || t.length < 3) continue;
        [finalTerms addObject:t];
        [finalTerms addObject:[t lowercaseString]];
    }

    NSArray<NSString *> *bases = @[
        @"/var/mobile/Library/Mobile Documents",
        @"/var/mobile/Library/Application Support/CloudDocs",
        @"/var/mobile/Library/Application Support/CloudKit",
        @"/var/mobile/Library/Accounts"
    ];

    // One find per base path.
    for (NSString *basePath in bases) {
        if (![_fileManager fileExistsAtPath:basePath]) continue;

        NSMutableString *expr = [NSMutableString string];
        for (NSString *t in finalTerms.array) {
            if (expr.length) [expr appendString:@" -o "];
            // Match common iCloud directory naming; keep broad for compatibility.
            [expr appendFormat:@"-iname '*%@*'", t];
        }
        if (!expr.length) continue;

        // Escape parentheses for /bin/sh
        NSString *cmd = [NSString stringWithFormat:
                         @"find '%@' -mindepth 1 -maxdepth %d \\( %@ \\) -exec rm -rf {} + 2>/dev/null || true",
                         basePath, maxDepth, expr];
        [self runCommandWithPrivileges:cmd timeoutSec:findTimeout];
    }

    // Clear iCloud accounts info (batch, in-process sqlite to avoid missing sqlite3 tool)
    NSString *accountsDBPath = @"/var/mobile/Library/Accounts/Accounts3.sqlite";
    if ([_fileManager fileExistsAtPath:accountsDBPath] && finalTerms.count) {
        sqlite3 *db = NULL;
        int rc = sqlite3_open_v2(accountsDBPath.UTF8String, &db, SQLITE_OPEN_READWRITE, NULL);
        if (rc == SQLITE_OK && db) {
            sqlite3_busy_timeout(db, 3000);

            // Build a predicate using only columns that exist on this iOS schema.
            NSMutableDictionary<NSString *, NSSet<NSString *> *> *colCache = [NSMutableDictionary dictionary];
            NSMutableArray<NSString *> *cols = [NSMutableArray array];
            for (NSString *c in @[@"ZIDENTIFIER", @"ZOWNINGBUNDLEID", @"ZUSERNAME", @"ZACCOUNTDESCRIPTION", @"ZDISPLAYNAME", @"ZEMAILADDRESS"]) {
                if (PXSQLiteTableHasColumnCached(db, @"ZACCOUNT", c, colCache)) {
                    [cols addObject:c];
                }
            }
            if (!cols.count) {
                sqlite3_close(db);
            } else {
                NSString *errMsg = nil;
                PXSQLiteExec(db, @"PRAGMA busy_timeout=3000;", NULL);
                PXSQLiteExec(db, @"BEGIN IMMEDIATE;", &errMsg);
                if (errMsg.length) {
                    errMsg = nil;
                }

                for (NSString *term in finalTerms.array) {
                    NSString *t = [term stringByReplacingOccurrencesOfString:@"'" withString:@"''"]; 
                    NSMutableArray<NSString *> *preds = [NSMutableArray array];
                    for (NSString *c in cols) {
                        [preds addObject:[NSString stringWithFormat:@"%@ LIKE '%%%%%@%%%%'", c, t]];
                    }
                    NSString *where = [preds componentsJoinedByString:@" OR "];
                    NSString *del = [NSString stringWithFormat:@"DELETE FROM ZACCOUNT WHERE %@;", where];
                    PXSQLiteExec(db, del, NULL);
                }

                PXSQLiteExec(db, @"COMMIT;", NULL);
                PXSQLiteExec(db, @"PRAGMA wal_checkpoint(TRUNCATE);", NULL);
                sqlite3_close(db);
            }
        } else {
            if (db) sqlite3_close(db);
        }
    }
}

- (void)fastWipeDirectoryContents:(NSString *)path keepDirectoryStructure:(BOOL)keepStructure timeoutSec:(int)timeoutSec {
    (void)path;
    (void)keepStructure;
    (void)timeoutSec;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (void)clearSystemLogs:(NSString *)bundleID {
    NSArray *logPaths = @[
        [NSString stringWithFormat:@"/var/mobile/Library/Logs/CrashReporter/%@*", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Logs/DiagnosticReports/%@*", bundleID],
        [NSString stringWithFormat:@"/var/log/asl/*%@*", bundleID],
        [NSString stringWithFormat:@"/var/log/system.log.*%@*", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Logs/CrashReporter/%@*", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Logs/DiagnosticReports/%@*", bundleID]
    ];
    
    for (NSString *pattern in logPaths) {
        NSArray *matches = [self findPathsMatchingPattern:pattern];
        for (NSString *path in matches) {
            NSLog(@"[AppDataCleaner] Wiping system log: %@", path);
            [self securelyWipeFile:path];
        }
    }
}

#pragma mark - Helper Methods

- (NSArray *)listDirectoriesInPath:(NSString *)path {
    NSError *error;
    NSArray *contents = [_fileManager contentsOfDirectoryAtPath:path error:&error];
    if (error) {
        NSLog(@"[AppDataCleaner] Error listing directory %@: %@", path, error.localizedDescription);
        return @[];
    }
    return contents;
}

- (BOOL)directoryHasContent:(NSString *)path {
    if (![_fileManager fileExistsAtPath:path]) {
        NSLog(@"[AppDataCleaner] Directory does not exist: %@", path);
        return NO;
    }
    
    NSError *error;
    NSArray *contents = [_fileManager contentsOfDirectoryAtPath:path error:&error];
    
    if (error) {
        NSLog(@"[AppDataCleaner] Error reading directory %@: %@", path, error.localizedDescription);
        return NO;
    }
    
    // Filter out system files that start with .com.apple
    NSMutableArray *nonSystemFiles = [NSMutableArray array];
    for (NSString *item in contents) {
        if (![item hasPrefix:@".com.apple"]) {
            [nonSystemFiles addObject:item];
        }
    }
    
    NSLog(@"[AppDataCleaner] Directory %@ has %lu non-system files", path, (unsigned long)nonSystemFiles.count);
    if (nonSystemFiles.count > 0) {
        NSLog(@"[AppDataCleaner] First few files: %@", [nonSystemFiles subarrayWithRange:NSMakeRange(0, MIN(5, nonSystemFiles.count))]);
    }
    
    return (nonSystemFiles.count > 0);
}

- (NSArray<NSString *> *)runBoundedFindWithArguments:(NSArray<NSString *> *)arguments {
    if (![arguments isKindOfClass:[NSArray class]] || arguments.count == 0) {
        return @[];
    }

    for (id argument in arguments) {
        if (![argument isKindOfClass:[NSString class]] || [(NSString *)argument length] == 0) {
            return @[];
        }
    }

    CommandResult *result =
        [[CommandRunner shared] runExecutableAndCapture:PXFindExecutablePath
                                              arguments:arguments
                                             timeoutSec:PXFindCommandTimeoutSec
                                         maxOutputBytes:PXFindCommandMaxOutputBytes];

    if (result == nil ||
        result.spawnError != 0 ||
        result.runnerError != 0 ||
        result.timedOut ||
        !result.exitedNormally ||
        result.stdoutTruncated ||
        result.stderrTruncated) {
        NSLog(@"[AppDataCleaner] Find command failed: resultNil=%d spawnError=%d runnerError=%d timedOut=%d exitedNormally=%d terminationSignal=%d exitCode=%d stdoutTruncated=%d stderrTruncated=%d",
              result == nil,
              result.spawnError,
              result.runnerError,
              result.timedOut,
              result.exitedNormally,
              result.terminationSignal,
              result.exitCode,
              result.stdoutTruncated,
              result.stderrTruncated);
        return @[];
    }

    NSString *output = result.stdoutString ?: @"";
    NSArray<NSString *> *parts =
        [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    return [parts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        (void)bindings;
        return [object isKindOfClass:[NSString class]] && [(NSString *)object length] > 0;
    }]];
}

- (NSArray *)findPathsMatchingPattern:(NSString *)pattern {
    if (![pattern isKindOfClass:[NSString class]] || pattern.length == 0) {
        return @[];
    }

    // Optimize search root: Default to /, but if pattern starts with exact path prefix, use that
    NSString *searchRoot = @"/";
    
    // Find the first wildcard char to determine static prefix
    NSRange rangeStar = [pattern rangeOfString:@"*"];
    NSRange rangeQ = [pattern rangeOfString:@"?"];
    NSRange rangeBrack = [pattern rangeOfString:@"["];
    
    NSUInteger firstWildcard = NSNotFound;
    if (rangeStar.location != NSNotFound) firstWildcard = rangeStar.location;
    if (rangeQ.location != NSNotFound && (firstWildcard == NSNotFound || rangeQ.location < firstWildcard)) firstWildcard = rangeQ.location;
    if (rangeBrack.location != NSNotFound && (firstWildcard == NSNotFound || rangeBrack.location < firstWildcard)) firstWildcard = rangeBrack.location;
    
    if (firstWildcard != NSNotFound && firstWildcard > 1) {
        // Get the path up to the last slash before the wildcard
        NSString *prefix = [pattern substringToIndex:firstWildcard];
        NSString *directory = [prefix stringByDeletingLastPathComponent];
        
        // Ensure we have a valid absolute path to start from
        if (directory.length > 1 && [directory hasPrefix:@"/"]) {
            // Check if directory exists
            BOOL isDir = NO;
            if ([[NSFileManager defaultManager] fileExistsAtPath:directory isDirectory:&isDir] && isDir) {
                searchRoot = directory;
                // NSLog(@"[AppDataCleaner] Optimized find search root: %@", searchRoot);
            }
        }
    }
    
    NSArray<NSString *> *arguments = @[
        @"-L",
        searchRoot,
        @"-path",
        pattern
    ];
    return [self runBoundedFindWithArguments:arguments];
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

// Optimized: find files/dirs under root matching any basename pattern (single traversal).
- (NSArray<NSString *> *)findPathsUnderRoot:(NSString *)root
                               directories:(BOOL)directories
                              namePatterns:(NSArray<NSString *> *)namePatterns {
    if (![root isKindOfClass:[NSString class]] || root.length == 0) return @[];
    if (![namePatterns isKindOfClass:[NSArray class]] || namePatterns.count == 0) return @[];

    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:root isDirectory:&isDir] || !isDir) return @[];

    NSMutableArray<NSString *> *patterns = [NSMutableArray array];
    for (id p in namePatterns) {
        if (![p isKindOfClass:[NSString class]]) continue;
        NSString *s = (NSString *)p;
        if (s.length) [patterns addObject:s];
    }
    if (patterns.count == 0) return @[];

    NSMutableArray<NSString *> *arguments = [NSMutableArray array];
    [arguments addObject:@"-L"];
    [arguments addObject:root];
    [arguments addObject:@"-type"];
    [arguments addObject:(directories ? @"d" : @"f")];
    [arguments addObject:@"("];

    for (NSUInteger index = 0; index < patterns.count; index++) {
        if (index > 0) {
            [arguments addObject:@"-o"];
        }
        [arguments addObject:@"-name"];
        [arguments addObject:patterns[index]];
    }

    [arguments addObject:@")"];
    [arguments addObject:@"-print"];
    return [self runBoundedFindWithArguments:arguments];
}

- (CommandResult *)runCommandWithPrivilegesResult:(NSString *)command
                                        timeoutSec:(NSTimeInterval)timeoutSec {
    if (![command isKindOfClass:[NSString class]] || command.length == 0 || !isfinite(timeoutSec)) {
        CommandResult *result = [[CommandResult alloc] init];
        result.runnerError = EINVAL;
        return result;
    }

    NSTimeInterval effectiveTimeout = timeoutSec <= 0 ? 60.0 : timeoutSec;
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

    // Main application-data verification consumes only canonical validator outputs from the wipe pass.
    BOOL useWipeCache = (_wipeCacheBundleID.length && bundleID.length &&
                         [_wipeCacheBundleID isEqualToString:bundleID]);

    // 1. Main-wipe verification uses canonical paths. Standalone verification keeps its legacy read-only fallback.
    if (useWipeCache) {
        for (NSString *canonicalPath in (_wipeCacheApplicationDataCanonicalPaths ?: @[])) {
            [self verifyClearedPath:canonicalPath reportingTo:unclearedPaths seen:verifiedPaths];
        }
    } else {
        NSString *dataContainerUUID = [self findDataContainerUUID:bundleID];
        if (dataContainerUUID) {
            NSString *dataContainerPath = [NSString stringWithFormat:@"/var/mobile/Containers/Data/Application/%@", dataContainerUUID];
            [self verifyClearedPath:dataContainerPath reportingTo:unclearedPaths seen:verifiedPaths];
        }

        NSString *rootlessDataContainerUUID = [self findRootlessDataContainerUUID:bundleID];
        if (rootlessDataContainerUUID) {
            NSString *rootlessDataContainerPath = [NSString stringWithFormat:@"/containers/Data/Application/%@", rootlessDataContainerUUID];
            [self verifyClearedPath:rootlessDataContainerPath reportingTo:unclearedPaths seen:verifiedPaths];
        }
        [self logMessage:@"[AppDataCleaner] Standalone verification used the legacy read-only application-data fallback"];
    }
    
    // 2. Main-wipe App Group verification consumes canonical validator outputs directly.
    if (useWipeCache) {
        for (NSString *canonicalPath in (_wipeCacheAppGroupCanonicalPaths ?: @[])) {
            [self verifyClearedPath:canonicalPath reportingTo:unclearedPaths seen:verifiedPaths];
        }
    } else {
        // Standalone compatibility remains read-only and cannot authorize mutation.
        NSArray *groupContainerUUIDs = [self findGroupContainerUUIDsForBundleID:bundleID];
        for (NSString *groupUUID in groupContainerUUIDs) {
            NSString *groupContainerPath = [NSString stringWithFormat:@"/var/mobile/Containers/Shared/AppGroup/%@", groupUUID];
            [self verifyClearedPath:groupContainerPath reportingTo:unclearedPaths seen:verifiedPaths];
        }
        NSArray *resolvedGroupUUIDs = [self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:NO];
        for (NSString *groupUUID in resolvedGroupUUIDs) {
            NSString *groupContainerPath = [NSString stringWithFormat:@"/var/mobile/Containers/Shared/AppGroup/%@", groupUUID];
            [self verifyClearedPath:groupContainerPath reportingTo:unclearedPaths seen:verifiedPaths];
        }
        NSArray *rootlessGroupContainerUUIDs =
            [self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:YES];
        for (NSString *groupUUID in rootlessGroupContainerUUIDs) {
            NSString *groupContainerPath = [NSString stringWithFormat:@"/containers/Shared/AppGroup/%@", groupUUID];
            [self verifyClearedPath:groupContainerPath reportingTo:unclearedPaths seen:verifiedPaths];
        }
        [self logMessage:@"[AppDataCleaner] Standalone verification used legacy read-only App Group discovery"];
    }
    
    // 3. Verify extension and PluginKit data containers.
    if (useWipeCache) {
        for (NSString *canonicalPath in (_wipeCacheExtensionDataCanonicalPaths ?: @[])) {
            [self verifyClearedPath:canonicalPath reportingTo:unclearedPaths seen:verifiedPaths];
        }
        for (NSString *canonicalPath in (_wipeCachePluginKitDataCanonicalPaths ?: @[])) {
            [self verifyClearedPath:canonicalPath reportingTo:unclearedPaths seen:verifiedPaths];
        }
        NSLog(@"[AppDataCleaner] Verify reusing canonical migrated wipe cache for %@", bundleID);
    } else {
        // Standalone verifier compatibility: legacy discovery is read-only and never feeds mutation.
        NSArray *extensionDataUUIDs = [self findExtensionDataContainersForBundleID:bundleID];
        for (NSString *extensionUUID in extensionDataUUIDs) {
            NSString *extensionPath = [NSString stringWithFormat:@"/var/mobile/Containers/Data/Application/%@", extensionUUID];
            [self verifyClearedPath:extensionPath reportingTo:unclearedPaths seen:verifiedPaths];
        }

        NSArray *dataDirs = [self listDirectoriesInPath:@"/var/mobile/Containers/Data/Application"];
        NSArray *rootlessDataDirs = [self listDirectoriesInPath:@"/containers/Data/Application"];
        NSArray *bundleDirs = [self listDirectoriesInPath:@"/var/containers/Bundle/Application"];
        NSArray *rootlessBundleDirs = [self listDirectoriesInPath:@"/containers/Bundle/Application"];
        NSArray *legacyExtensionContainers = [self optimized_findExtensionContainers:bundleID
                                                                            dataDirs:dataDirs
                                                                    rootlessDataDirs:rootlessDataDirs
                                                                          bundleDirs:bundleDirs
                                                                  rootlessBundleDirs:rootlessBundleDirs];
        for (NSDictionary *extInfo in legacyExtensionContainers) {
            NSString *extDataUUID = extInfo[@"dataUUID"];
            if (!extDataUUID.length) continue;
            BOOL rootless = [extInfo[@"rootless"] boolValue];
            NSString *basePath = rootless ? @"/containers/Data/Application" : @"/var/mobile/Containers/Data/Application";
            [self verifyClearedPath:[basePath stringByAppendingPathComponent:extDataUUID]
                       reportingTo:unclearedPaths
                              seen:verifiedPaths];
        }
        [self logMessage:@"[AppDataCleaner] Standalone verification used legacy read-only extension inspection"];
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
    
    // 5. Verify keychain items
    if ([self hasKeychainItemsForBundleID:bundleID]) {
        [unclearedPaths addObject:@{
            @"path": @"Keychain",
            @"info": @"Keychain still contains items for this bundle ID"
        }];
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
    NSArray *secClasses = @[
        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecClassInternetPassword,
        (__bridge id)kSecClassCertificate,
        (__bridge id)kSecClassKey,
        (__bridge id)kSecClassIdentity
    ];
    
    for (id secClass in secClasses) {
        NSDictionary *query = @{
            (__bridge id)kSecClass: secClass,
            (__bridge id)kSecReturnAttributes: @YES,
            (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll
        };
        
        CFTypeRef result = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
        
        if (status == errSecSuccess && result != NULL) {
            NSArray *items = (__bridge_transfer NSArray *)result;
            
            for (NSDictionary *item in items) {
                NSString *service = item[(__bridge id)kSecAttrService];
                NSString *account = item[(__bridge id)kSecAttrAccount];
                NSString *accessGroup = item[(__bridge id)kSecAttrAccessGroup];
                NSString *label = item[(__bridge id)kSecAttrLabel];
                
                // Check for any keychain items related to our bundle ID
                if (([service containsString:bundleID]) ||
                    ([account containsString:bundleID]) ||
                    ([accessGroup containsString:bundleID]) ||
                    ([label containsString:bundleID])) {
                    
                    [unclearedPaths addObject:@{
                        @"path": @"Keychain",
                        @"info": [NSString stringWithFormat:@"Item still exists: service=%@, account=%@, group=%@, label=%@",
                                 service ?: @"nil", account ?: @"nil", accessGroup ?: @"nil", label ?: @"nil"]
                    }];
                }
                
                // Also check component matches (like "uber" from "com.ubercab.UberClient")
                NSArray *components = [bundleID componentsSeparatedByString:@"."];
                for (NSString *component in components) {
                    if (component.length > 3 && ![component isEqualToString:@"com"] && 
                        ![component isEqualToString:@"org"] && ![component isEqualToString:@"net"]) {
                        
                        if (([service containsString:component]) ||
                            ([account containsString:component]) ||
                            ([accessGroup containsString:component]) ||
                            ([label containsString:component])) {
                            
                            [unclearedPaths addObject:@{
                                @"path": @"Keychain",
                                @"info": [NSString stringWithFormat:@"Item with component '%@' still exists: service=%@, account=%@, group=%@, label=%@",
                                         component, service ?: @"nil", account ?: @"nil", accessGroup ?: @"nil", label ?: @"nil"]
                            }];
                        }
                    }
                }
            }
        }
    }
}

// Verify SQLite databases don't have references to the app
- (void)verifySQLiteReferencesCleared:(NSString *)bundleID reportingTo:(NSMutableArray *)unclearedPaths {
    NSArray *systemDBs = @[
        @"/var/mobile/Library/SpringBoard/ApplicationHistory.sqlite",
        @"/var/mobile/Library/Assistant/SiriAnalytics.db",
        @"/var/mobile/Library/SpringBoard/IconState.plist"
    ];
    
    for (NSString *dbPath in systemDBs) {
        if ([_fileManager fileExistsAtPath:dbPath]) {
            // For plist files
            if ([dbPath hasSuffix:@".plist"]) {
                NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:dbPath];
                NSString *plistStr = [plist description];
                
                if ([plistStr containsString:bundleID]) {
                    [unclearedPaths addObject:@{
                        @"path": dbPath,
                        @"info": @"Plist still contains references to app"
                    }];
                }
            }
            // For SQLite we'll just mark the file for manual inspection
            else if ([dbPath hasSuffix:@".sqlite"] || [dbPath hasSuffix:@".db"]) {
                // We can't easily check SQLite content without sqlite3 libraries
                // So we'll just report these files for manual inspection
                [unclearedPaths addObject:@{
                    @"path": dbPath,
                    @"info": @"SQLite database requires manual inspection"
                }];
            }
        }
    }
}

// Helper to run a command and get its output
- (NSString *)runCommandAndGetOutput:(NSString *)command {
    return [self runCommandAndGetOutput:command
                                timeoutSec:PXOutputQueryDefaultTimeoutSec];
}

- (NSString *)runCommandAndGetOutput:(NSString *)command
                          timeoutSec:(NSTimeInterval)timeoutSec {
    NSLog(@"[AppDataCleaner] Running command: %@", command);

    if (![command isKindOfClass:[NSString class]] ||
        command.length == 0 ||
        !isfinite(timeoutSec)) {
        NSLog(@"[AppDataCleaner] Command query failed: invalid input");
        return @"error";
    }

    NSTimeInterval effectiveTimeout = timeoutSec <= 0
        ? PXOutputQueryDefaultTimeoutSec
        : timeoutSec;
    CommandResult *result = [self runCommandWithPrivilegesResult:command
                                                       timeoutSec:effectiveTimeout];

    BOOL failed = result.runnerError != 0 ||
                  result.spawnError != 0 ||
                  result.timedOut ||
                  !result.exitedNormally ||
                  result.stdoutTruncated ||
                  result.stderrTruncated;
    if (failed) {
        NSLog(@"[AppDataCleaner] Command query failed: spawnError=%d runnerError=%d timedOut=%d exitedNormally=%d terminationSignal=%d stdoutTruncated=%d stderrTruncated=%d",
              result.spawnError,
              result.runnerError,
              result.timedOut,
              result.exitedNormally,
              result.terminationSignal,
              result.stdoutTruncated,
              result.stderrTruncated);
        return @"error";
    }

    NSString *stdoutString = result.stdoutString ?: @"";
    NSString *stderrString = result.stderrString ?: @"";
    NSMutableString *mergedOutput = [NSMutableString stringWithString:stdoutString];
    if (stderrString.length > 0) {
        if (mergedOutput.length > 0 && ![mergedOutput hasSuffix:@"\n"]) {
            [mergedOutput appendString:@"\n"];
        }
        [mergedOutput appendString:stderrString];
    }

    return [mergedOutput stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
#pragma mark - Public Header Methods

- (BOOL)hasDataToClear:(NSString *)bundleID {
    NSLog(@"[AppDataCleaner] Checking for data to clear for %@", bundleID);
    
    // Force system to flush pending disk operations
    [self runCommandWithPrivileges:@"sync"];
    
    // Check if there's any data to clear for this bundle ID
    NSString *appDataUUID = [self findDataContainerUUID:bundleID];
    NSString *rootlessDataUUID = [self findRootlessDataContainerUUID:bundleID];
    NSMutableArray *appGroupUUIDs = [NSMutableArray array];
    [appGroupUUIDs addObjectsFromArray:[self findAppGroupUUIDs:bundleID] ?: @[]];
    [appGroupUUIDs addObjectsFromArray:[self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:NO] ?: @[]];
    appGroupUUIDs = [[[NSOrderedSet orderedSetWithArray:appGroupUUIDs] array] mutableCopy];
    NSMutableArray *rootlessGroupUUIDs = [NSMutableArray array];
    [rootlessGroupUUIDs addObjectsFromArray:[self findRootlessAppGroupUUIDs:bundleID] ?: @[]];
    [rootlessGroupUUIDs addObjectsFromArray:[self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:YES] ?: @[]];
    rootlessGroupUUIDs = [[[NSOrderedSet orderedSetWithArray:rootlessGroupUUIDs] array] mutableCopy];
    
    NSLog(@"[AppDataCleaner] Found UUIDs - Data: %@, Rootless: %@, Groups: %@, Rootless Groups: %@", 
          appDataUUID ?: @"Not found", 
          rootlessDataUUID ?: @"Not found", 
          appGroupUUIDs, 
          rootlessGroupUUIDs);
    
    // IMPROVEMENT: If we found any containers at all, assume there's data to clear
    // This avoids the "no data" message when containers exist but appear empty
    if (appDataUUID || rootlessDataUUID || appGroupUUIDs.count > 0 || rootlessGroupUUIDs.count > 0) {
        NSLog(@"[AppDataCleaner] Found containers - assuming app has data to clear");
        
        // Calculate usage for UI display
        NSDictionary *usage = [self getDataUsage:bundleID];
        
        // Store this information in UserDefaults for the ProjectXViewController to access
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:usage forKey:[NSString stringWithFormat:@"DataUsage_%@", bundleID]];
        [defaults synchronize];
        
        return YES;
    }
    
    BOOL hasData = NO;
    
    // Standard data container checks - more aggressive
    if (appDataUUID) {
        NSString *containerPath = [NSString stringWithFormat:@"/var/mobile/Containers/Data/Application/%@", appDataUUID];
        if ([self directoryExistsAndHasAnyContent:containerPath]) {
            NSLog(@"[AppDataCleaner] Found data in application container: %@", containerPath);
            hasData = YES;
        }
    }
    
    // Rootless data container - more aggressive
    if (rootlessDataUUID) {
        NSString *containerPath = [NSString stringWithFormat:@"/containers/Data/Application/%@", rootlessDataUUID];
        if ([self directoryExistsAndHasAnyContent:containerPath]) {
            NSLog(@"[AppDataCleaner] Found data in rootless application container: %@", containerPath);
            hasData = YES;
        }
    }
    
    // App groups - check entire container, not just top level
    for (NSString *groupUUID in appGroupUUIDs) {
        NSString *groupPath = [NSString stringWithFormat:@"/var/mobile/Containers/Shared/AppGroup/%@", groupUUID];
        if ([self directoryExistsAndHasAnyContent:groupPath]) {
            NSLog(@"[AppDataCleaner] Found data in App Group: %@", groupPath);
            hasData = YES;
        }
    }
    
    // Rootless app groups - check entire container
    for (NSString *groupUUID in rootlessGroupUUIDs) {
        NSString *groupPath = [NSString stringWithFormat:@"/containers/Shared/AppGroup/%@", groupUUID];
        if ([self directoryExistsAndHasAnyContent:groupPath]) {
            NSLog(@"[AppDataCleaner] Found data in rootless App Group: %@", groupPath);
            hasData = YES;
        }
    }
    
    // Check preferences
    NSString *prefsPath = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", bundleID];
    if ([_fileManager fileExistsAtPath:prefsPath]) {
        NSLog(@"[AppDataCleaner] Found preference file: %@", prefsPath);
        hasData = YES;
    }
    
    // Check rootless preferences
    NSString *rootlessPrefsPath = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", bundleID];
    if ([_fileManager fileExistsAtPath:rootlessPrefsPath]) {
        NSLog(@"[AppDataCleaner] Found rootless preference file: %@", rootlessPrefsPath);
        hasData = YES;
    }
    
    // NEW: Check for keychain items even if no files found
    if (!hasData && [self hasKeychainItemsForBundleID:bundleID]) {
        NSLog(@"[AppDataCleaner] Found keychain items for %@", bundleID);
        hasData = YES;
    }
    
    // NEW: Check for system database references as a last resort
    if (!hasData) {
        if ([self hasSystemDatabaseReferencesForBundleID:bundleID]) {
            NSLog(@"[AppDataCleaner] Found system database references for %@", bundleID);
            hasData = YES;
        }
    }
    
    // If we have data, calculate size for UI display
    if (hasData) {
        NSDictionary *usage = [self getDataUsage:bundleID];
        
        // Store this information in UserDefaults for the ProjectXViewController to access
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:usage forKey:[NSString stringWithFormat:@"DataUsage_%@", bundleID]];
        [defaults synchronize];
    } else {
        NSLog(@"[AppDataCleaner] No data found to clear for %@", bundleID);
    }
    
    return hasData;
}

// --- Optimized lookup helpers (local to this file, do not break existing API) ---

- (NSString *)optimized_findDataContainerUUID:(NSString *)bundleID inDirectories:(NSArray *)dataDirs {
    NSArray *parts = [bundleID componentsSeparatedByString:@"."];
    NSString *company = parts.count > 1 ? parts[1] : @"";
    NSString *shortName = parts.lastObject;
    __block NSString *result = nil;
    dispatch_apply(dataDirs.count, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t i) {
        if (result) return;
        NSString *uuid = dataDirs[i];
        NSString *metadataPath = [NSString stringWithFormat:@"/var/mobile/Containers/Data/Application/%@/.com.apple.mobile_container_manager.metadata.plist", uuid];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        NSString *containerBundleID = metadata[@"MCMMetadataIdentifier"];
        if ([containerBundleID isEqualToString:bundleID]) { result = uuid; return; }
        // Aggressive/fuzzy matching
        if ([containerBundleID containsString:bundleID] ||
            (company.length && [containerBundleID containsString:company]) ||
            (shortName.length && [containerBundleID containsString:shortName])) {
            result = uuid; return;
        }
        // Scan for app-named files/dirs (first match wins)
        NSString *containerPath = [NSString stringWithFormat:@"/var/mobile/Containers/Data/Application/%@", uuid];
        NSArray *contents = [self listDirectoriesInPath:containerPath];
        for (NSString *item in contents) {
            if (([item containsString:bundleID] ||
                 (company.length && [item containsString:company]) ||
                 (shortName.length && [item containsString:shortName]))) {
                result = uuid; return;
            }
        }
    });
    return result;
}

- (NSString *)optimized_findRootlessDataContainerUUID:(NSString *)bundleID inDirectories:(NSArray *)dataDirs {
    NSArray *parts = [bundleID componentsSeparatedByString:@"."];
    NSString *company = parts.count > 1 ? parts[1] : @"";
    NSString *shortName = parts.lastObject;
    __block NSString *result = nil;
    dispatch_apply(dataDirs.count, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t i) {
        if (result) return;
        NSString *uuid = dataDirs[i];
        NSString *metadataPath = [NSString stringWithFormat:@"/containers/Data/Application/%@/.com.apple.mobile_container_manager.metadata.plist", uuid];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        NSString *containerBundleID = metadata[@"MCMMetadataIdentifier"];
        if ([containerBundleID isEqualToString:bundleID]) { result = uuid; return; }
        if ([containerBundleID containsString:bundleID] ||
            (company.length && [containerBundleID containsString:company]) ||
            (shortName.length && [containerBundleID containsString:shortName])) {
            result = uuid; return;
        }
        NSString *containerPath = [NSString stringWithFormat:@"/containers/Data/Application/%@", uuid];
        NSArray *contents = [self listDirectoriesInPath:containerPath];
        for (NSString *item in contents) {
            if (([item containsString:bundleID] ||
                 (company.length && [item containsString:company]) ||
                 (shortName.length && [item containsString:shortName]))) {
                result = uuid; return;
            }
        }
    });
    return result;
}

- (NSArray *)optimized_findAppGroupUUIDs:(NSString *)bundleID inDirectories:(NSArray *)groupDirs {
    NSArray *parts = [bundleID componentsSeparatedByString:@"."];
    NSString *company = parts.count > 1 ? parts[1] : @"";
    NSString *shortName = parts.lastObject;
    NSMutableArray *groupUUIDs = [NSMutableArray array];
    
    dispatch_apply(groupDirs.count, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t i) {
        NSString *uuid = groupDirs[i];
        NSString *metadataPath = [NSString stringWithFormat:@"/var/mobile/Containers/Shared/AppGroup/%@/.com.apple.mobile_container_manager.metadata.plist", uuid];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        id groupIdentifier = metadata[@"MCMMetadataIdentifier"];
        BOOL matched = NO;
        if ([groupIdentifier isKindOfClass:[NSArray class]]) {
            if ([(NSArray *)groupIdentifier containsObject:bundleID]) matched = YES;
        } else if ([groupIdentifier isKindOfClass:[NSString class]]) {
            if ([(NSString *)groupIdentifier containsString:bundleID]) matched = YES;
        }
        if (!matched) {
            // Fuzzy
            if (([groupIdentifier isKindOfClass:[NSString class]] &&
                 ((company.length && [groupIdentifier containsString:company]) ||
                  (shortName.length && [groupIdentifier containsString:shortName])))) matched = YES;
            else {
                // Scan for files/dirs
                NSString *containerPath = [NSString stringWithFormat:@"/var/mobile/Containers/Shared/AppGroup/%@", uuid];
                NSArray *contents = [self listDirectoriesInPath:containerPath];
                for (NSString *item in contents) {
                    if (([item containsString:bundleID] ||
                         (company.length && [item containsString:company]) ||
                         (shortName.length && [item containsString:shortName]))) {
                        matched = YES; break;
                    }
                }
            }
        }
        if (matched) @synchronized(groupUUIDs) { [groupUUIDs addObject:uuid]; }
    });
    return groupUUIDs;
}

- (NSString *)optimized_findBundleContainerUUID:(NSString *)bundleID inDirectories:(NSArray *)bundleDirs rootlessDirs:(NSArray *)rootlessDirs {
    __block NSString *result = nil;
    // Standard
    dispatch_apply(bundleDirs.count, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t i) {
        if (result) return;
        NSString *uuid = bundleDirs[i];
        NSString *appPath = [NSString stringWithFormat:@"/var/containers/Bundle/Application/%@", uuid];
        NSArray *appContents = [self listDirectoriesInPath:appPath];
        for (NSString *item in appContents) {
            if ([item hasSuffix:@".app"]) {
                NSString *infoPlistPath = [NSString stringWithFormat:@"/var/containers/Bundle/Application/%@/%@/Info.plist", uuid, item];
                NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
                NSString *itemBundleID = infoPlist[@"CFBundleIdentifier"];
                if ([itemBundleID isEqualToString:bundleID]) { result = uuid; return; }
            }
        }
    });
    if (result) return result;
    // Rootless
    dispatch_apply(rootlessDirs.count, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t i) {
        if (result) return;
        NSString *uuid = rootlessDirs[i];
        NSString *appPath = [NSString stringWithFormat:@"/containers/Bundle/Application/%@", uuid];
        NSArray *appContents = [self listDirectoriesInPath:appPath];
        for (NSString *item in appContents) {
            if ([item hasSuffix:@".app"]) {
                NSString *infoPlistPath = [NSString stringWithFormat:@"/containers/Bundle/Application/%@/%@/Info.plist", uuid, item];
                NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
                NSString *itemBundleID = infoPlist[@"CFBundleIdentifier"];
                if ([itemBundleID isEqualToString:bundleID]) { result = uuid; return; }
            }
        }
    });
    return result;
}

- (NSArray *)optimized_findExtensionContainers:(NSString *)bundleID dataDirs:(NSArray *)dataDirs rootlessDataDirs:(NSArray *)rootlessDataDirs bundleDirs:(NSArray *)bundleDirs rootlessBundleDirs:(NSArray *)rootlessBundleDirs {
    NSMutableArray *extensionInfo = [NSMutableArray array];
    // 1. Find extension data containers by checking metadata files (standard)
    dispatch_apply(dataDirs.count, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t i) {
        NSString *uuid = dataDirs[i];
        NSString *metadataPath = [NSString stringWithFormat:@"/var/mobile/Containers/Data/Application/%@/.com.apple.mobile_container_manager.metadata.plist", uuid];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        NSString *containerBundleID = metadata[@"MCMMetadataIdentifier"];
        if (containerBundleID && [containerBundleID hasPrefix:bundleID] && ![containerBundleID isEqualToString:bundleID]) {
            // Find bundle UUID for extension
            NSString *extBundleUUID = [self optimized_findBundleContainerUUID:containerBundleID inDirectories:bundleDirs rootlessDirs:rootlessBundleDirs];
            @synchronized(extensionInfo) {
                [extensionInfo addObject:@{ @"bundleID": containerBundleID, @"dataUUID": uuid, @"bundleUUID": extBundleUUID ?: @"", @"type": @"extension" }];
            }
        }
    });
    // Rootless
    dispatch_apply(rootlessDataDirs.count, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t i) {
        NSString *uuid = rootlessDataDirs[i];
        NSString *metadataPath = [NSString stringWithFormat:@"/containers/Data/Application/%@/.com.apple.mobile_container_manager.metadata.plist", uuid];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        NSString *containerBundleID = metadata[@"MCMMetadataIdentifier"];
        if (containerBundleID && [containerBundleID hasPrefix:bundleID] && ![containerBundleID isEqualToString:bundleID]) {
            NSString *extBundleUUID = [self optimized_findBundleContainerUUID:containerBundleID inDirectories:bundleDirs rootlessDirs:rootlessBundleDirs];
            @synchronized(extensionInfo) {
                [extensionInfo addObject:@{ @"bundleID": containerBundleID, @"dataUUID": uuid, @"bundleUUID": extBundleUUID ?: @"", @"type": @"extension", @"rootless": @YES }];
            }
        }
    });
    return extensionInfo;
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
- (void)clearSharedContainers:(NSString *)bundleID { [self clearAppGroupData:bundleID]; }
- (void)clearUserDefaults:(NSString *)bundleID { [self clearAppPreferences:bundleID]; }
- (void)clearSQLiteDatabases:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearPrivateVarData:(NSString *)bundleID { [self cleanRootHideVarData:bundleID]; }
- (void)clearDeviceDatabase:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearInstallationLogs:(NSString *)bundleID { [self clearSystemLogs:bundleID]; }
- (void)clearNetworkConfigurations:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearCarrierData:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearNetworkData:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearDNSCache:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearCrashReports:(NSString *)bundleID { [self clearSystemLogs:bundleID]; }
- (void)clearDiagnosticData:(NSString *)bundleID { [self clearSystemLogs:bundleID]; }
- (void)clearBluetoothData:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearPushNotificationData:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearThumbnailCache:(NSString *)bundleID { [self clearThumbnailCaches:bundleID]; }
- (void)clearWebCache:(NSString *)bundleID { [self clearAppWebKitData:bundleID]; }
- (void)clearGameData:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearTemporaryFiles:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearBinaryPlists:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearEncryptedData:(NSString *)bundleID { 
    [self _internalClearEncryptedData:bundleID];
}
- (void)clearJailbreakDetectionLogs:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearSpotlightData:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearSiriData:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearSystemLoggerData:(NSString *)bundleID { [self clearSystemLogs:bundleID]; }
- (void)clearASLLogs:(NSString *)bundleID { [self clearSystemLogs:bundleID]; }
- (void)clearClipboard { 
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [pasteboard setItems:@[]];
}
- (void)clearPasteboardData:(NSString *)bundleID { [self clearClipboard]; }
- (void)clearURLCache:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearBackgroundAssets:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearSharedStorage:(NSString *)bundleID { [self completeAppDataWipe:bundleID]; }
- (void)clearAppStateData:(NSString *)bundleID {
    [self _internalClearAppStateData:bundleID];
}
- (void)secureDataWipe:(NSString *)bundleID {
    (void)bundleID;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

- (NSDictionary *)getDataUsage:(NSString *)bundleID {
    NSMutableDictionary *usage = [NSMutableDictionary dictionary];
    
    // Calculate app data usage
    long long dataSize = 0;
    NSString *appDataUUID = [self findDataContainerUUID:bundleID];
    if (appDataUUID) {
        NSString *dataPath = [NSString stringWithFormat:@"/var/mobile/Containers/Data/Application/%@", appDataUUID];
        dataSize += [self calculateDirectorySize:dataPath];
    }

    NSString *rootlessDataUUID = [self findRootlessDataContainerUUID:bundleID];
    if (rootlessDataUUID) {
        NSString *dataPath = [NSString stringWithFormat:@"/containers/Data/Application/%@", rootlessDataUUID];
        dataSize += [self calculateDirectorySize:dataPath];
    }
    usage[@"dataSize"] = @(dataSize);
    
    // Calculate app bundle size
    NSString *bundleUUID = [self findBundleUUID:bundleID];
    if (bundleUUID) {
        NSString *bundlePath = [NSString stringWithFormat:@"/var/containers/Bundle/Application/%@", bundleUUID];
        usage[@"bundleSize"] = @([self calculateDirectorySize:bundlePath]);
    }
    
    // Calculate shared data size
    NSMutableSet<NSString *> *seenGroups = [NSMutableSet set];
    long long sharedSize = 0;

    NSMutableArray<NSString *> *appGroupUUIDs = [NSMutableArray array];
    [appGroupUUIDs addObjectsFromArray:[self findAppGroupUUIDs:bundleID] ?: @[]];
    [appGroupUUIDs addObjectsFromArray:[self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:NO] ?: @[]];
    for (NSString *groupUUID in appGroupUUIDs) {
        if (!groupUUID.length || [seenGroups containsObject:groupUUID]) continue;
        [seenGroups addObject:groupUUID];
        NSString *groupPath = [NSString stringWithFormat:@"/var/mobile/Containers/Shared/AppGroup/%@", groupUUID];
        sharedSize += [self calculateDirectorySize:groupPath];
    }

    NSMutableArray<NSString *> *rootlessGroupUUIDs = [NSMutableArray array];
    [rootlessGroupUUIDs addObjectsFromArray:[self findRootlessAppGroupUUIDs:bundleID] ?: @[]];
    [rootlessGroupUUIDs addObjectsFromArray:[self _resolvedAppGroupUUIDsFromEntitlements:bundleID rootless:YES] ?: @[]];
    for (NSString *groupUUID in rootlessGroupUUIDs) {
        NSString *key = [@"rootless:" stringByAppendingString:groupUUID ?: @""];
        if (!groupUUID.length || [seenGroups containsObject:key]) continue;
        [seenGroups addObject:key];
        NSString *groupPath = [NSString stringWithFormat:@"/containers/Shared/AppGroup/%@", groupUUID];
        sharedSize += [self calculateDirectorySize:groupPath];
    }
    usage[@"sharedSize"] = @(sharedSize);
    
    // Total size
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
    [self logMessage:@"[AppDataCleaner] Clearing app state data for %@", bundleID];
    
    // 1. Direct file paths (Fastest)
    NSArray *directPaths = @[
        [NSString stringWithFormat:@"/var/mobile/Library/SpringBoard/ApplicationState/%@.plist", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Preferences/com.apple.UIKit.SplitView.%@.plist", bundleID]
    ];
    
    for (NSString *path in directPaths) {
        [self securelyWipeFile:path];
    }
    
    // 2. Scan specific directories for files containing bundleID (Much faster than find /)
    
    // FrontBoard
    [self scanAndWipeInDirectory:@"/var/mobile/Library/FrontBoard" matching:bundleID];
    
    // LiveActivities
    [self scanAndWipeInDirectory:@"/var/mobile/Library/LiveActivities" matching:bundleID];
    
    // SpringBoard RecentlyTerminatedAppState
    [self scanAndWipeInDirectory:@"/var/mobile/Library/SpringBoard/RecentlyTerminatedAppState" matching:bundleID];
    
    // BackgroundTasks - recursive scan needed but limited depth
    [self scanAndWipeInDirectory:@"/var/mobile/Library/BackgroundTasks" matching:bundleID];
    
    // TCC
    [self scanAndWipeInDirectory:@"/var/mobile/Library/TCC" matching:bundleID];
    
    // 3. Special handling for difficult paths (Containers)
    // Instead of scanning all containers, we use a targeted approach if possible, or skip deeply nested widely scattered scans if not critical.
    // For com.apple.nsurlsessiond, we can try a more limited scan if essential, but often the main cleanup handles the app's own container.
    // We will skip scanning /var/mobile/Library/Containers/*/Data/System/... to avoid timeout as it involves iterating thousands of folders.
}

// Helper to scan a directory and wipe files/folders matching a string
- (void)scanAndWipeInDirectory:(NSString *)directory matching:(NSString *)matchString {
    if (![_fileManager fileExistsAtPath:directory]) return;
    
    NSDirectoryEnumerator *enumerator = [_fileManager enumeratorAtURL:[NSURL fileURLWithPath:directory]
                                           includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                                                              options:NSDirectoryEnumerationSkipsHiddenFiles
                                                         errorHandler:nil];
    
    for (NSURL *fileURL in enumerator) {
        NSString *filename = [fileURL lastPathComponent];
        if ([filename containsString:matchString]) {
            NSString *path = [fileURL path];
            [self logMessage:@"[AppDataCleaner] Wiping matched state file: %@", path];
            [self securelyWipeFile:path];
            // If we deleted a directory, stick to standard enumeration or beware of modification during enumeration
            // securelyWipeFile handles file deletion.
        }
    }
}

// Override the existing clearAppStateData method to call our internal implementation

// Fix for line ~1757 - Replace the duplicate clearEncryptedData
- (void)_internalClearEncryptedDataOutsideMainApplicationContainer:(NSString *)bundleID
                                                         deepClean:(BOOL)deepClean {
    NSLog(@"[AppDataCleaner] Clearing encrypted data outside the migrated main application-data container for %@", bundleID);

    NSArray *encryptedPrefs = [self findPathsMatchingPattern:[NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@*.enc*", bundleID]];
    encryptedPrefs = [encryptedPrefs arrayByAddingObjectsFromArray:
                     [self findPathsMatchingPattern:[NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@*.encrypted*", bundleID]]];
    encryptedPrefs = [encryptedPrefs arrayByAddingObjectsFromArray:
                     [self findPathsMatchingPattern:[NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@*.secure*", bundleID]]];
    for (NSString *path in encryptedPrefs) {
        [self securelyWipeFile:path];
    }

    NSArray<NSString *> *prefBases = @[
        @"/private/var/mobile/Library/Preferences",
        @"/var/jb/var/mobile/Library/Preferences",
        @"/private/var/jb/var/mobile/Library/Preferences"
    ];
    NSMutableArray *rootlessEncryptedPrefs = [NSMutableArray array];
    for (NSString *base in prefBases) {
        if (![_fileManager fileExistsAtPath:base]) continue;
        [rootlessEncryptedPrefs addObjectsFromArray:[self findPathsMatchingPattern:[NSString stringWithFormat:@"%@/%@*.enc*", base, bundleID]]];
        [rootlessEncryptedPrefs addObjectsFromArray:[self findPathsMatchingPattern:[NSString stringWithFormat:@"%@/%@*.encrypted*", base, bundleID]]];
        [rootlessEncryptedPrefs addObjectsFromArray:[self findPathsMatchingPattern:[NSString stringWithFormat:@"%@/%@*.secure*", base, bundleID]]];
    }
    for (NSString *path in rootlessEncryptedPrefs) {
        [self securelyWipeFile:path];
    }

    if (!deepClean) {
        NSLog(@"[AppDataCleaner] Deep Clean OFF: skipping deep non-main encrypted/token scans");
        return;
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
    NSLog(@"[AppDataCleaner] Finding extension containers for %@", bundleID);
    NSMutableArray *extensionInfo = [NSMutableArray array];
    
    // 1. Find extension data containers by checking metadata files (standard)
    NSArray *allDataContainers = [self listDirectoriesInPath:@"/var/mobile/Containers/Data/Application"];
    
    for (NSString *uuid in allDataContainers) {
        NSString *metadataPath = [NSString stringWithFormat:@"/var/mobile/Containers/Data/Application/%@/.com.apple.mobile_container_manager.metadata.plist", uuid];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        NSString *containerBundleID = metadata[@"MCMMetadataIdentifier"];
        
        // Check if this is an extension of our app (extensions often have the app's bundle ID as a prefix)
        if (containerBundleID && 
            [containerBundleID hasPrefix:bundleID] && 
            ![containerBundleID isEqualToString:bundleID]) {
            
            NSLog(@"[AppDataCleaner] Found extension data container: %@ for %@", uuid, containerBundleID);
            
            // Also search for the corresponding bundle UUID
            NSString *extBundleUUID = [self findBundleUUIDForExtension:containerBundleID];
            
            [extensionInfo addObject:@{
                @"bundleID": containerBundleID,
                @"dataUUID": uuid,
                @"bundleUUID": extBundleUUID ?: @"",
                @"type": @"extension"
            }];
        }
    }
    
    // 2. Check rootless path too
    if ([self directoryHasContent:@"/containers/Data/Application"]) {
        NSArray *rootlessDataContainers = [self listDirectoriesInPath:@"/containers/Data/Application"];
        
        for (NSString *uuid in rootlessDataContainers) {
            NSString *metadataPath = [NSString stringWithFormat:@"/containers/Data/Application/%@/.com.apple.mobile_container_manager.metadata.plist", uuid];
            NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
            NSString *containerBundleID = metadata[@"MCMMetadataIdentifier"];
            
            if (containerBundleID && 
                [containerBundleID hasPrefix:bundleID] && 
                ![containerBundleID isEqualToString:bundleID]) {
                
                NSLog(@"[AppDataCleaner] Found rootless extension data container: %@ for %@", uuid, containerBundleID);
                
                // Find rootless bundle UUID
                NSString *extBundleUUID = [self findRootlessBundleUUIDForExtension:containerBundleID];
                
                [extensionInfo addObject:@{
                    @"bundleID": containerBundleID,
                    @"dataUUID": uuid,
                    @"bundleUUID": extBundleUUID ?: @"",
                    @"type": @"extension",
                    @"rootless": @YES
                }];
            }
        }
    }
    
    // 3. Also check PluginKitPlugin containers which can contain extension data
    NSArray *pluginKitPaths = [self findPathsMatchingPattern:@"/var/mobile/Containers/Data/PluginKitPlugin/*"];
    for (NSString *pluginPath in pluginKitPaths) {
        NSString *metadataPath = [pluginPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        
        NSString *containerID = metadata[@"MCMMetadataIdentifier"];
        if (containerID && [containerID hasPrefix:bundleID]) {
            NSString *uuid = [pluginPath lastPathComponent];
            NSLog(@"[AppDataCleaner] Found PluginKit container: %@ for %@", uuid, containerID);
            
            [extensionInfo addObject:@{
                @"bundleID": containerID,
                @"dataUUID": uuid,
                @"type": @"pluginkit"
            }];
        }
    }
    
    // 4. Check rootless PluginKitPlugin containers
    pluginKitPaths = [self findPathsMatchingPattern:@"/containers/Data/PluginKitPlugin/*"];
    for (NSString *pluginPath in pluginKitPaths) {
        NSString *metadataPath = [pluginPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
        
        NSString *containerID = metadata[@"MCMMetadataIdentifier"];
        if (containerID && [containerID hasPrefix:bundleID]) {
            NSString *uuid = [pluginPath lastPathComponent];
            NSLog(@"[AppDataCleaner] Found rootless PluginKit container: %@ for %@", uuid, containerID);
            
            [extensionInfo addObject:@{
                @"bundleID": containerID,
                @"dataUUID": uuid,
                @"type": @"pluginkit",
                @"rootless": @YES
            }];
        }
    }
    
    NSLog(@"[AppDataCleaner] Found %lu extension containers for %@", (unsigned long)extensionInfo.count, bundleID);
    return extensionInfo;
}

// Find bundle UUID for an extension
- (NSString *)findBundleUUIDForExtension:(NSString *)extensionBundleID {
    NSArray *bundleDirs = [self listDirectoriesInPath:@"/var/containers/Bundle/Application"];
    
    for (NSString *uuid in bundleDirs) {
        NSString *appPath = [NSString stringWithFormat:@"/var/containers/Bundle/Application/%@", uuid];
        NSArray *appContents = [self listDirectoriesInPath:appPath];
        
        // Extensions are often in a Plugins or PlugIns directory
        for (NSString *item in appContents) {
            if ([item hasSuffix:@".app"] || [item hasSuffix:@".appex"] || 
                [item isEqualToString:@"PlugIns"] || [item isEqualToString:@"Plugins"]) {
                
                // Check if this is the extension's bundle
                if ([item hasSuffix:@".appex"]) {
                    NSString *infoPlistPath = [NSString stringWithFormat:@"/var/containers/Bundle/Application/%@/%@/Info.plist", 
                                             uuid, item];
                    NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
                    NSString *itemBundleID = infoPlist[@"CFBundleIdentifier"];
                    
                    if ([itemBundleID isEqualToString:extensionBundleID]) {
                        return uuid;
                    }
                } 
                // Check in Plugins/PlugIns directory for extension bundles
                else if ([item isEqualToString:@"PlugIns"] || [item isEqualToString:@"Plugins"]) {
                    NSString *pluginsPath = [NSString stringWithFormat:@"/var/containers/Bundle/Application/%@/%@", uuid, item];
                    NSArray *plugins = [self listDirectoriesInPath:pluginsPath];
                    
                    for (NSString *plugin in plugins) {
                        if ([plugin hasSuffix:@".appex"]) {
                            NSString *infoPlistPath = [NSString stringWithFormat:@"/var/containers/Bundle/Application/%@/%@/%@/Info.plist", 
                                                     uuid, item, plugin];
                            NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
                            NSString *itemBundleID = infoPlist[@"CFBundleIdentifier"];
                            
                            if ([itemBundleID isEqualToString:extensionBundleID]) {
                                return uuid;
                            }
                        }
                    }
                }
            }
        }
    }
    
    return nil;
}

// Find rootless bundle UUID for an extension
- (NSString *)findRootlessBundleUUIDForExtension:(NSString *)extensionBundleID {
    if (![self directoryHasContent:@"/containers/Bundle/Application"]) {
        return nil;
    }
    
    NSArray *bundleDirs = [self listDirectoriesInPath:@"/containers/Bundle/Application"];
    
    for (NSString *uuid in bundleDirs) {
        NSString *appPath = [NSString stringWithFormat:@"/containers/Bundle/Application/%@", uuid];
        NSArray *appContents = [self listDirectoriesInPath:appPath];
        
        // Same logic as standard bundle, but with rootless paths
        for (NSString *item in appContents) {
            if ([item hasSuffix:@".app"] || [item hasSuffix:@".appex"] || 
                [item isEqualToString:@"PlugIns"] || [item isEqualToString:@"Plugins"]) {
                
                if ([item hasSuffix:@".appex"]) {
                    NSString *infoPlistPath = [NSString stringWithFormat:@"/containers/Bundle/Application/%@/%@/Info.plist", 
                                             uuid, item];
                    NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
                    NSString *itemBundleID = infoPlist[@"CFBundleIdentifier"];
                    
                    if ([itemBundleID isEqualToString:extensionBundleID]) {
                        return uuid;
                    }
                } 
                else if ([item isEqualToString:@"PlugIns"] || [item isEqualToString:@"Plugins"]) {
                    NSString *pluginsPath = [NSString stringWithFormat:@"/containers/Bundle/Application/%@/%@", uuid, item];
                    NSArray *plugins = [self listDirectoriesInPath:pluginsPath];
                    
                    for (NSString *plugin in plugins) {
                        if ([plugin hasSuffix:@".appex"]) {
                            NSString *infoPlistPath = [NSString stringWithFormat:@"/containers/Bundle/Application/%@/%@/%@/Info.plist", 
                                                     uuid, item, plugin];
                            NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
                            NSString *itemBundleID = infoPlist[@"CFBundleIdentifier"];
                            
                            if ([itemBundleID isEqualToString:extensionBundleID]) {
                                return uuid;
                            }
                        }
                    }
                }
            }
        }
    }
    
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
    NSLog(@"[AppDataCleaner] Searching for bundle container UUID for %@", bundleID);
    
    // 1. Check standard app bundle containers path
    NSString *bundlesPath = @"/var/containers/Bundle/Application";
    if (![_fileManager fileExistsAtPath:bundlesPath]) {
        bundlesPath = @"/var/mobile/Containers/Bundle/Application";
    }
    
    NSError *error;
    NSArray *contents = [_fileManager contentsOfDirectoryAtPath:bundlesPath error:&error];
    
    if (error) {
        NSLog(@"[AppDataCleaner] Error listing app bundle containers: %@", error.localizedDescription);
        return nil;
    }
    
    // 2. Iterate through UUIDs to find our app
    for (NSString *uuid in contents) {
        NSString *appPath = [bundlesPath stringByAppendingPathComponent:uuid];
        NSArray *appContents = [_fileManager contentsOfDirectoryAtPath:appPath error:nil];
        
        for (NSString *item in appContents) {
            if ([item hasSuffix:@".app"]) {
                NSString *infoPlistPath = [NSString stringWithFormat:@"%@/%@/Info.plist", appPath, item];
                NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
                
                if ([infoPlist[@"CFBundleIdentifier"] isEqualToString:bundleID]) {
                    NSLog(@"[AppDataCleaner] Found bundle container UUID: %@ for %@", uuid, bundleID);
                    return uuid;
                }
            }
        }
    }
    
    // 3. Also check rootless path
    NSString *rootlessBundlesPath = @"/containers/Bundle/Application";
    if ([_fileManager fileExistsAtPath:rootlessBundlesPath]) {
        contents = [_fileManager contentsOfDirectoryAtPath:rootlessBundlesPath error:&error];
        
        if (error) {
            NSLog(@"[AppDataCleaner] Error listing rootless app bundle containers: %@", error.localizedDescription);
            return nil;
        }
        
        for (NSString *uuid in contents) {
            NSString *appPath = [rootlessBundlesPath stringByAppendingPathComponent:uuid];
            NSArray *appContents = [_fileManager contentsOfDirectoryAtPath:appPath error:nil];
            
            for (NSString *item in appContents) {
                if ([item hasSuffix:@".app"]) {
                    NSString *infoPlistPath = [NSString stringWithFormat:@"%@/%@/Info.plist", appPath, item];
                    NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
                    
                    if ([infoPlist[@"CFBundleIdentifier"] isEqualToString:bundleID]) {
                        NSLog(@"[AppDataCleaner] Found rootless bundle container UUID: %@ for %@", uuid, bundleID);
                        return uuid;
                    }
                }
            }
        }
    }
    
    NSLog(@"[AppDataCleaner] No bundle container UUID found for %@", bundleID);
    return nil;
}

// Add these methods to our collection for the most comprehensive clearing

// MEDIA STORAGE: Add method to clean media traces that apps sometimes leave behind
- (void)clearMediaData:(NSString *)bundleID {
    NSLog(@"[AppDataCleaner] Clearing media data for %@", bundleID);
    
    // Parse app name from bundle ID
    NSArray *components = [bundleID componentsSeparatedByString:@"."];
    NSString *appName = [components lastObject];
    
    if (appName.length > 3) {  // Skip short/generic names
        // Check Camera Roll for app-generated photos
        NSString *dcimPath = @"/var/mobile/Media/DCIM/100APPLE/";
        if ([_fileManager fileExistsAtPath:dcimPath]) {
            NSString *command = [NSString stringWithFormat:@"find '%@' -name '*%@*' -exec rm -f {} \\; 2>/dev/null || true", 
                                dcimPath, appName];
            [self runCommandWithPrivileges:command];
        }
        
        // Check Downloads folder
        NSString *downloadsPath = @"/var/mobile/Media/Downloads/";
        if ([_fileManager fileExistsAtPath:downloadsPath]) {
            NSString *command = [NSString stringWithFormat:@"find '%@' -name '*%@*' -exec rm -f {} \\; 2>/dev/null || true", 
                                downloadsPath, appName];
            [self runCommandWithPrivileges:command];
        }
        
        // Check for attachments in Messages
        NSString *attachmentsPath = @"/var/mobile/Library/SMS/Attachments/";
        if ([_fileManager fileExistsAtPath:attachmentsPath]) {
            NSString *command = [NSString stringWithFormat:@"find '%@' -name '*%@*' -exec rm -f {} \\; 2>/dev/null || true", 
                                attachmentsPath, appName];
            [self runCommandWithPrivileges:command];
        }
    }
    
    // Check for app's media in general Library locations
    NSArray *mediaPaths = @[
        @"/var/mobile/Media/PhotoData/LocalItems/",
        @"/var/mobile/Media/PhotoData/Caches/",
        @"/var/mobile/Media/PhotoData/Thumbnails/",
        @"/var/mobile/Media/PhotoStreamsData/",
        @"/var/mobile/Media/Photos/Thumbnails/",
        @"/var/mobile/Library/Photos/"
    ];
    
    for (NSString *basePath in mediaPaths) {
        if ([_fileManager fileExistsAtPath:basePath]) {
            NSString *command = [NSString stringWithFormat:@"find '%@' -name '*%@*' -exec rm -f {} \\; 2>/dev/null || true", 
                                basePath, bundleID];
            [self runCommandWithPrivileges:command];
            
            if (appName.length > 3) {
                command = [NSString stringWithFormat:@"find '%@' -name '*%@*' -exec rm -f {} \\; 2>/dev/null || true", 
                          basePath, appName];
                [self runCommandWithPrivileges:command];
            }
        }
    }
}

// HEALTH DATA: Some apps like fitness trackers can store health data
- (void)clearHealthData:(NSString *)bundleID {
    NSLog(@"[AppDataCleaner] Clearing health data for %@", bundleID);
    
    NSArray *healthPaths = @[
        @"/var/mobile/Library/Health/",
        @"/var/mobile/Library/HealthKit/",
        @"/var/mobile/Library/Health/",
        @"/var/mobile/Library/HealthKit/"
    ];
    
    for (NSString *basePath in healthPaths) {
        if ([_fileManager fileExistsAtPath:basePath]) {
            NSString *command = [NSString stringWithFormat:@"find '%@' -name '*%@*' -exec rm -f {} \\; 2>/dev/null || true", 
                                basePath, bundleID];
            [self runCommandWithPrivileges:command];
        }
    }
}

// SAFARI DATA: Some apps use SafariViewController and leave data there
- (void)clearSafariData:(NSString *)bundleID {
    NSLog(@"[AppDataCleaner] Clearing Safari data for %@", bundleID);
    
    NSArray *components = [bundleID componentsSeparatedByString:@"."];
    NSString *appName = [components lastObject];
    
    NSArray *safariPaths = @[
        @"/var/mobile/Library/Safari/History.db",
        @"/var/mobile/Library/Safari/Bookmarks.db",
        @"/var/mobile/Library/Safari/TopSites.db",
        @"/var/mobile/Library/Safari/RecentlyClosedTabs.plist",
        @"/var/mobile/Library/Safari/Tabs/"
    ];
    
    for (NSString *path in safariPaths) {
        if ([_fileManager fileExistsAtPath:path]) {
            if ([path hasSuffix:@".db"]) {
                // Use sqlite3 to delete records related to the app
                NSString *sqlCommand = [NSString stringWithFormat:
                                      @"sqlite3 '%@' \"DELETE FROM history_items WHERE url LIKE '%%%@%%';\"",
                                      path, bundleID];
                [self runCommandWithPrivileges:sqlCommand];
                
                if (appName.length > 3) {
                    sqlCommand = [NSString stringWithFormat:
                                @"sqlite3 '%@' \"DELETE FROM history_items WHERE title LIKE '%%%@%%';\"",
                                path, appName];
                    [self runCommandWithPrivileges:sqlCommand];
                }
                
                // Vacuum database
                sqlCommand = [NSString stringWithFormat:@"sqlite3 '%@' \"VACUUM;\"", path];
                [self runCommandWithPrivileges:sqlCommand];
            } else if ([path.lastPathComponent isEqualToString:@"Tabs"]) {
                // Find and delete tab files related to the app
                NSString *command = [NSString stringWithFormat:@"find '%@' -name '*%@*' -exec rm -f {} \\; 2>/dev/null || true", 
                                    path, bundleID];
                [self runCommandWithPrivileges:command];
                
                if (appName.length > 3) {
                    command = [NSString stringWithFormat:@"find '%@' -name '*%@*' -exec rm -f {} \\; 2>/dev/null || true", 
                              path, appName];
                    [self runCommandWithPrivileges:command];
                }
            }
        }
    }
}

// NEW: Method to completely wipe a container directory
- (void)completelyWipeContainer:(NSString *)containerPath {
    (void)containerPath;
    PXLogQuarantinedLegacyClearSelector(_cmd);
}

// NEW: Method to clean IconState.plist
- (void)cleanIconStatePlist:(NSString *)bundleID {
    NSLog(@"[AppDataCleaner] Cleaning SpringBoard IconState.plist for %@", bundleID);
    
    // First, backup the original plist
    [self runCommandWithPrivileges:@"cp '/var/mobile/Library/SpringBoard/IconState.plist' '/var/tmp/IconState.plist'"];
    [self runCommandWithPrivileges:@"chmod 644 '/var/tmp/IconState.plist'"];
    
    // Convert binary plist to XML format for easy text processing
    [self runCommandWithPrivileges:@"plutil -convert xml1 '/var/tmp/IconState.plist'"];
    
    // Aggressively remove any references to this app by bundle ID
    [self runCommandWithPrivileges:[NSString stringWithFormat:@"grep -v '%@' '/var/tmp/IconState.plist' > '/var/tmp/IconState_filtered.plist'", bundleID]];
    
    // Convert back to binary format
    [self runCommandWithPrivileges:@"plutil -convert binary1 '/var/tmp/IconState_filtered.plist'"];
    
    // Replace the original plist with the filtered one
    [self runCommandWithPrivileges:@"cp '/var/tmp/IconState_filtered.plist' '/var/mobile/Library/SpringBoard/IconState.plist'"];
    
    // Clean up the temporary files
    [self runCommandWithPrivileges:@"rm -f '/var/tmp/IconState.plist' '/var/tmp/IconState_filtered.plist'"];
    
    // Additional aggressive cleanup of IconState
    // Use a more comprehensive approach to also clean any partial fragments
    // Extract app name from bundle ID (e.g., "UberClient" from "com.ubercab.UberClient")
    NSArray *components = [bundleID componentsSeparatedByString:@"."];
    NSString *appName = components.lastObject;
    
    // Dump, filter, and restore method  
    [self runCommandWithPrivileges:@"cp '/var/mobile/Library/SpringBoard/IconState.plist' '/var/tmp/IconState2.plist'"];
    [self runCommandWithPrivileges:@"chmod 644 '/var/tmp/IconState2.plist'"];
    [self runCommandWithPrivileges:@"plutil -convert xml1 '/var/tmp/IconState2.plist'"];
    
    if (appName && appName.length > 0) {
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"grep -v '%@' '/var/tmp/IconState2.plist' > '/var/tmp/IconState2_filtered.plist'", appName]];
        [self runCommandWithPrivileges:@"plutil -convert binary1 '/var/tmp/IconState2_filtered.plist'"];
        [self runCommandWithPrivileges:@"cp '/var/tmp/IconState2_filtered.plist' '/var/mobile/Library/SpringBoard/IconState.plist'"];
        [self runCommandWithPrivileges:@"rm -f '/var/tmp/IconState2.plist' '/var/tmp/IconState2_filtered.plist'"];
    }
    
    // Also clean up DefaultIconState.plist as a safety measure
    if ([_fileManager fileExistsAtPath:@"/var/mobile/Library/SpringBoard/DefaultIconState.plist"]) {
        [self runCommandWithPrivileges:@"cp '/var/mobile/Library/SpringBoard/DefaultIconState.plist' '/var/tmp/DefaultIconState.plist'"];
        [self runCommandWithPrivileges:@"chmod 644 '/var/tmp/DefaultIconState.plist'"];
        [self runCommandWithPrivileges:@"plutil -convert xml1 '/var/tmp/DefaultIconState.plist'"];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"grep -v '%@' '/var/tmp/DefaultIconState.plist' > '/var/tmp/DefaultIconState_filtered.plist'", bundleID]];
        [self runCommandWithPrivileges:@"plutil -convert binary1 '/var/tmp/DefaultIconState_filtered.plist'"];
        [self runCommandWithPrivileges:@"cp '/var/tmp/DefaultIconState_filtered.plist' '/var/mobile/Library/SpringBoard/DefaultIconState.plist'"];
        [self runCommandWithPrivileges:@"rm -f '/var/tmp/DefaultIconState.plist' '/var/tmp/DefaultIconState_filtered.plist'"];
    }
}

// NEW: Method to clean SiriAnalytics database
- (void)cleanSiriAnalyticsDatabase:(NSString *)bundleID {
    NSLog(@"[AppDataCleaner] Cleaning SiriAnalytics database for %@", bundleID);
    
    // Extract app name from bundle ID (e.g., "UberClient" from "com.ubercab.UberClient")
    NSArray *components = [bundleID componentsSeparatedByString:@"."];
    NSString *appName = components.lastObject;
    
    // Delete from main table
    [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '/var/mobile/Library/Assistant/SiriAnalytics.db' \"DELETE FROM main WHERE bundleid = '%@';\"", bundleID]];
    [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '/var/mobile/Library/Assistant/SiriAnalytics.db' \"DELETE FROM main WHERE app_id = '%@';\"", bundleID]];
    [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '/var/mobile/Library/Assistant/SiriAnalytics.db' \"DELETE FROM app_usage WHERE bundleid = '%@';\"", bundleID]];
    [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '/var/mobile/Library/Assistant/SiriAnalytics.db' \"DELETE FROM usage_contexts WHERE data LIKE '%%%@%%';\"", bundleID]];
    [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '/var/mobile/Library/Assistant/SiriAnalytics.db' \"DELETE FROM analytics WHERE data LIKE '%%%@%%';\"", bundleID]];
    
    // Also check by app name
    [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '/var/mobile/Library/Assistant/SiriAnalytics.db' \"DELETE FROM main WHERE bundleid LIKE '%%%@%%';\"", appName]];
    [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '/var/mobile/Library/Assistant/SiriAnalytics.db' \"DELETE FROM main WHERE app_id LIKE '%%%@%%';\"", appName]];
    [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '/var/mobile/Library/Assistant/SiriAnalytics.db' \"DELETE FROM app_usage WHERE bundleid LIKE '%%%@%%';\"", appName]];
    [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '/var/mobile/Library/Assistant/SiriAnalytics.db' \"DELETE FROM usage_contexts WHERE data LIKE '%%%@%%';\"", appName]];
    [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '/var/mobile/Library/Assistant/SiriAnalytics.db' \"DELETE FROM analytics WHERE data LIKE '%%%@%%';\"", appName]];
    
    // Also delete by company name if available (e.g., "ubercab" from "com.ubercab.UberClient")
    if (components.count > 1) {
        NSString *companyName = components[1];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '/var/mobile/Library/Assistant/SiriAnalytics.db' \"DELETE FROM main WHERE bundleid LIKE '%%%@%%';\"", companyName]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '/var/mobile/Library/Assistant/SiriAnalytics.db' \"DELETE FROM app_usage WHERE bundleid LIKE '%%%@%%';\"", companyName]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '/var/mobile/Library/Assistant/SiriAnalytics.db' \"DELETE FROM usage_contexts WHERE data LIKE '%%%@%%';\"", companyName]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '/var/mobile/Library/Assistant/SiriAnalytics.db' \"DELETE FROM analytics WHERE data LIKE '%%%@%%';\"", companyName]];
    }
    
    // Force data flush by running VACUUM
    [self runCommandWithPrivileges:@"sqlite3 '/var/mobile/Library/Assistant/SiriAnalytics.db' \"VACUUM;\""];
    
}

// NEW: Method to clean LaunchServices database
- (void)cleanLaunchServicesDatabase:(NSString *)bundleID {
    NSLog(@"[AppDataCleaner] Cleaning LaunchServices database for %@", bundleID);
    
    // Remove SBAppTagsFileManager which stores app categorization
    [self runCommandWithPrivileges:@"rm -rf /var/mobile/Library/CoreServices/SpringBoard.app/SBAppTagsFileManager"];
    [self runCommandWithPrivileges:@"rm -rf /var/mobile/Library/CoreServices/SpringBoard.app/SBIconModelCache.plist"];
    
    // Also remove rootless versions
    [self runCommandWithPrivileges:@"rm -rf /var/mobile/Library/CoreServices/SpringBoard.app/SBAppTagsFileManager"];
    [self runCommandWithPrivileges:@"rm -rf /var/mobile/Library/CoreServices/SpringBoard.app/SBIconModelCache.plist"];
    
    // Find and remove LaunchServices caches
    NSArray *lsCachePaths = [self findPathsMatchingPattern:@"/var/mobile/Library/Caches/com.apple.LaunchServices-*"];
    for (NSString *path in lsCachePaths) {
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"rm -rf '%@'", path]];
    }
    
    // Find and remove rootless LaunchServices caches
    lsCachePaths = [self findPathsMatchingPattern:@"/var/mobile/Library/Caches/com.apple.LaunchServices-*"];
    for (NSString *path in lsCachePaths) {
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"rm -rf '%@'", path]];
    }
}

// NEW: Method to refresh system services to apply changes
- (void)refreshSystemServices {
    [self logMessage:@"[AppDataCleaner] Refreshing system services (SAFE MODE)..."];
    
    // REMOVED: Send HUP signal to SpringBoard - CAUSES RESPRING
    // [self runCommandWithPrivileges:@"killall -HUP SpringBoard 2>/dev/null || true"];
    
    // Enhanced: Force system caches to be cleared
    [self runCommandWithPrivileges:@"sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true"];
    
    // Enhanced: Clear application launch cache (Safe to restart cfprefsd)
    PXKillallByName(@"cfprefsd", SIGTERM);
    
    // Enhanced: Clear system connectivity caches
    PXKillallByName(@"nsurlsessiond", SIGTERM);
    
    // REMOVED: Force cache regen in filesystem - MAY CAUSE RESPRING
    // [self runCommandWithPrivileges:@"rm -rf /var/mobile/Library/Caches/com.apple.LaunchServices-* 2>/dev/null || true"];
    
    // Enhanced: Force database vacuum on key databases to remove deleted data
    NSArray *dbsToVacuum = @[
        @"/var/mobile/Library/SpringBoard/ApplicationState.db"
    ];
    
    for (NSString *dbPath in dbsToVacuum) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:dbPath]) {
            [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"VACUUM;\" 2>/dev/null || true", dbPath]];
        }
    }
}

#pragma mark - Container Discovery Methods

- (BOOL)hasKeychainItemsForBundleID:(NSString *)bundleID {
    // This will require Security.framework access
    // For now we'll use a simple check to see if there are any keychain items for this app
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    query[(__bridge id)kSecAttrService] = bundleID;
    query[(__bridge id)kSecReturnAttributes] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitAll;
    
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    
    if (status == errSecSuccess) {
        NSArray *items = (__bridge_transfer NSArray *)result;
        return items.count > 0;
    }
    
    // Try again with a different approach - check for access groups
    query = [NSMutableDictionary dictionary];
    query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    query[(__bridge id)kSecAttrAccessGroup] = bundleID;
    query[(__bridge id)kSecReturnAttributes] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitAll;
    
    result = NULL;
    status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    
    if (status == errSecSuccess) {
        NSArray *items = (__bridge_transfer NSArray *)result;
        return items.count > 0;
    }
    
    return NO;
}

// Support methods (aliases for backwards compatibility)
- (NSString *)findDataContainerUUIDForBundleID:(NSString *)bundleID {
    return [self findDataContainerUUID:bundleID];
}

- (NSString *)findBundleContainerUUIDForBundleID:(NSString *)bundleID {
    return [self findBundleContainerUUID:bundleID];
}

- (NSArray *)findGroupContainerUUIDsForBundleID:(NSString *)bundleID {
    if (!bundleID.length) return @[];

    // Resolve app groups from entitlements (authoritative), then map to UUID/path.
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
    NSMutableArray<NSString *> *uuids = [NSMutableArray array];
    for (AppGroupContainerInfo *info in infos) {
        if ([info.uuid isKindOfClass:[NSString class]] && info.uuid.length) {
            [uuids addObject:info.uuid];
        } else if ([info.path isKindOfClass:[NSString class]] && info.path.length) {
            [uuids addObject:[info.path lastPathComponent]];
        }
    }
    return uuids;
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

- (void)_wipeMobileSafariSystemStores {
    [self logMessage:@"[AppDataCleaner] MobileSafari: wiping global Safari/WebKit/Cookies stores..."];

    // Ensure processes are stopped first to avoid sqlite "database is locked" and detached DB crashes.
    PXStopSafariDaemonsBestEffort(self);

    // Google sign-in can surface "Continue as <gmail>" from system Accounts even when cookies are gone.
    // For Safari clear-data, we treat it as web session state and remove Google account rows best-effort.
    {
        NSString *accountsDB = PXFirstExistingPath(_fileManager, @[
            @"/var/mobile/Library/Accounts/Accounts3.sqlite",
            @"/private/var/mobile/Library/Accounts/Accounts3.sqlite",
            @"/var/jb/var/mobile/Library/Accounts/Accounts3.sqlite",
            @"/private/var/jb/var/mobile/Library/Accounts/Accounts3.sqlite"
        ]);
        if (accountsDB.length && [_fileManager fileExistsAtPath:accountsDB]) {
            [self logMessage:@"[AppDataCleaner] MobileSafari: removing Google accounts from Accounts3 (shared) ..."]; 

            // Stop accountsd before touching DB (avoid "database is locked").
            PXKillallByName(@"accountsd", SIGTERM);
            [NSThread sleepForTimeInterval:0.2];
            PXKillallByName(@"accountsd", SIGKILL);
            [NSThread sleepForTimeInterval:0.2];

            sqlite3 *db = NULL;
            int rc = sqlite3_open_v2(accountsDB.UTF8String, &db, SQLITE_OPEN_READWRITE, NULL);
            if (rc != SQLITE_OK || !db) {
                NSString *msg = db ? [NSString stringWithUTF8String:sqlite3_errmsg(db)] : @"open failed";
                [self logMessage:@"[AppDataCleaner] MobileSafari: Accounts3 open failed rc=%d %@", rc, msg ?: @""];
                if (db) sqlite3_close(db);
            } else {
                sqlite3_busy_timeout(db, 3000);

                NSString *beforeCount = PXSQLiteScalar(db, @"SELECT count(*) FROM ZACCOUNT;");
                [self logMessage:@"[AppDataCleaner] MobileSafari: Accounts3 ZACCOUNT count before=%@", beforeCount ?: @"(nil)"];
                PXSQLiteLogAccountsSample(self, db, @"MobileSafari(before)");

                NSString *typeCount = PXSQLiteScalar(db, @"SELECT count(*) FROM ZACCOUNTTYPE WHERE ZIDENTIFIER LIKE '%google%' OR ZIDENTIFIER LIKE '%gmail%';");
                if (typeCount.length) {
                    [self logMessage:@"[AppDataCleaner] MobileSafari: google-ish account types=%@", typeCount];
                }

                NSMutableDictionary<NSString *, NSSet<NSString *> *> *colCache = [NSMutableDictionary dictionary];
                BOOL hasZAccountType = PXSQLiteTableHasColumnCached(db, @"ZACCOUNT", @"ZACCOUNTTYPE", colCache);

                NSMutableArray<NSString *> *preds = [NSMutableArray array];
                if (hasZAccountType) {
                    [preds addObject:@"ZACCOUNTTYPE IN (SELECT Z_PK FROM ZACCOUNTTYPE WHERE ZIDENTIFIER LIKE '%google%' OR ZIDENTIFIER LIKE '%gmail%')"]; 
                }
                // Match on any existing identifier-like columns.
                NSArray<NSString *> *maybeCols = @[
                    @"ZIDENTIFIER",
                    @"ZUSERNAME",
                    @"ZACCOUNTDESCRIPTION",
                    @"ZDISPLAYNAME",
                    @"ZEMAILADDRESS",
                    @"ZOWNINGBUNDLEID"
                ];
                for (NSString *c in maybeCols) {
                    if (PXSQLiteTableHasColumnCached(db, @"ZACCOUNT", c, colCache)) {
                        [preds addObject:[NSString stringWithFormat:@"%@ LIKE '%%google%%' OR %@ LIKE '%%gmail%%'", c, c]];
                    }
                }

                NSString *where = preds.count ? [preds componentsJoinedByString:@" OR "] : nil;

                NSString *errMsg = nil;
                PXSQLiteExec(db, @"PRAGMA busy_timeout=3000;", NULL);
                PXSQLiteExec(db, @"BEGIN IMMEDIATE;", &errMsg);
                if (errMsg.length) {
                    [self logMessage:@"[AppDataCleaner] MobileSafari: BEGIN IMMEDIATE failed %@", errMsg];
                    errMsg = nil;
                }

                if (where.length) {
                    NSString *del = [NSString stringWithFormat:@"DELETE FROM ZACCOUNT WHERE %@;", where];
                    BOOL ok = PXSQLiteExec(db, del, &errMsg);
                    int changes = sqlite3_changes(db);
                    [self logMessage:@"[AppDataCleaner] MobileSafari: ZACCOUNT delete ok=%d changes=%d %@", ok, changes, errMsg.length ? errMsg : @""];
                    errMsg = nil;
                } else {
                    [self logMessage:@"[AppDataCleaner] MobileSafari: Accounts3 schema unknown; skip delete"]; 
                }

                // Best-effort cleanup of orphan rows (ignore failures if tables don't exist).
                PXSQLiteExec(db, @"DELETE FROM ZACCOUNTPROPERTY WHERE ZOWNER NOT IN (SELECT Z_PK FROM ZACCOUNT);", NULL);
                PXSQLiteExec(db, @"DELETE FROM ZCREDENTIALITEM WHERE ZOWNER NOT IN (SELECT Z_PK FROM ZACCOUNT);", NULL);

                PXSQLiteExec(db, @"COMMIT;", &errMsg);
                if (errMsg.length) {
                    [self logMessage:@"[AppDataCleaner] MobileSafari: COMMIT failed %@", errMsg];
                    errMsg = nil;
                    PXSQLiteExec(db, @"ROLLBACK;", NULL);
                }
                PXSQLiteExec(db, @"PRAGMA wal_checkpoint(TRUNCATE);", NULL);

                NSString *afterCount = PXSQLiteScalar(db, @"SELECT count(*) FROM ZACCOUNT;");
                [self logMessage:@"[AppDataCleaner] MobileSafari: Accounts3 ZACCOUNT count after=%@", afterCount ?: @"(nil)"];
                PXSQLiteLogAccountsSample(self, db, @"MobileSafari(after)");

                // Debug sample of account types (helps tune predicates across iOS versions)
                sqlite3_stmt *st = NULL;
                if (sqlite3_prepare_v2(db, "SELECT ZIDENTIFIER FROM ZACCOUNTTYPE LIMIT 12;", -1, &st, NULL) == SQLITE_OK && st) {
                    NSMutableArray *ids = [NSMutableArray array];
                    while (sqlite3_step(st) == SQLITE_ROW) {
                        const unsigned char *txt = sqlite3_column_text(st, 0);
                        if (txt) [ids addObject:[NSString stringWithUTF8String:(const char *)txt]];
                    }
                    sqlite3_finalize(st);
                    if (ids.count) {
                        [self logMessage:@"[AppDataCleaner] MobileSafari: ZACCOUNTTYPE sample=%@", [ids componentsJoinedByString:@", "]];
                    }
                } else if (st) {
                    sqlite3_finalize(st);
                }

                sqlite3_close(db);
            }

            // Restart accountsd so UI refreshes.
            PXKillallByName(@"accountsd", SIGTERM);
        } else {
            [self logMessage:@"[AppDataCleaner] MobileSafari: Accounts3.sqlite not found; skipping Google accounts cleanup"]; 
        }
    }

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

    sync();
}

- (NSArray *)findExtensionDataContainersForBundleID:(NSString *)bundleID {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *containersPath = @"/var/mobile/Containers/Data/Application";
    NSMutableArray *extensionContainers = [NSMutableArray array];
    NSError *error = nil;
    
    if (![fileManager fileExistsAtPath:containersPath]) {
        NSLog(@"[AppDataCleaner] Directory does not exist: %@", containersPath);
        return extensionContainers;
    }
    
    NSArray *containers = [fileManager contentsOfDirectoryAtPath:containersPath error:&error];
    if (error) {
        NSLog(@"[AppDataCleaner] Error listing data containers: %@", error);
        return extensionContainers;
    }
    
    // Get the base app identifier component (e.g., "com.company" from "com.company.appname")
    NSArray *bundleComponents = [bundleID componentsSeparatedByString:@"."];
    NSString *baseIdentifier = @"";
    if (bundleComponents.count >= 2) {
        baseIdentifier = [NSString stringWithFormat:@"%@.%@", bundleComponents[0], bundleComponents[1]];
    }
    
    for (NSString *container in containers) {
        if ([container hasPrefix:@"."]) continue;
        
        NSString *containerPath = [containersPath stringByAppendingPathComponent:container];
        NSString *metadataPath = [containerPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        
        if ([fileManager fileExistsAtPath:metadataPath]) {
                NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
                NSString *containerBundleID = metadata[@"MCMMetadataIdentifier"];
                
            // Check if this is an extension of our app
            if (containerBundleID && ![containerBundleID isEqualToString:bundleID] &&
                [containerBundleID hasPrefix:baseIdentifier] && 
                ([containerBundleID containsString:@".extension."] || 
                 [containerBundleID hasSuffix:@".extension"] ||
                 [containerBundleID containsString:@".appex."] ||
                 [containerBundleID hasSuffix:@".appex"] ||
                 [containerBundleID containsString:@".plugin."] ||
                 [containerBundleID hasSuffix:@".plugin"])) {
                
                NSLog(@"[AppDataCleaner] Found extension container UUID: %@ for %@", container, containerBundleID);
                [extensionContainers addObject:container];
            }
        }
    }
    
    NSLog(@"[AppDataCleaner] Found %lu extension containers for %@", (unsigned long)extensionContainers.count, bundleID);
    return extensionContainers;
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
    // Check if this is an SQLite database
    if ([dbPath hasSuffix:@".sqlite"] || [dbPath hasSuffix:@".db"]) {
        NSLog(@"[AppDataCleaner] Cleaning SQLite database: %@", dbPath);
        
        // Try common table and column names that might contain app-specific data
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM main WHERE bundleid = '%@';\" 2>/dev/null || true", dbPath, bundleID]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM apps WHERE bundleid = '%@';\" 2>/dev/null || true", dbPath, bundleID]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM data WHERE bundleid = '%@';\" 2>/dev/null || true", dbPath, bundleID]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM items WHERE bundleid = '%@';\" 2>/dev/null || true", dbPath, bundleID]];
        
        // Add specific cleaning for Lyft and Zimride names in tables
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM main WHERE data LIKE '%%lyft%%' OR bundleid LIKE '%%lyft%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM apps WHERE data LIKE '%%lyft%%' OR bundleid LIKE '%%lyft%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM data WHERE data LIKE '%%lyft%%' OR bundleid LIKE '%%lyft%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM items WHERE data LIKE '%%lyft%%' OR bundleid LIKE '%%lyft%%';\" 2>/dev/null || true", dbPath]];
        
        // Specific case for com.lyft.ios bundle ID
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM main WHERE bundleid = 'com.lyft.ios' OR data LIKE '%%com.lyft.ios%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM apps WHERE bundleid = 'com.lyft.ios' OR data LIKE '%%com.lyft.ios%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM data WHERE bundleid = 'com.lyft.ios' OR data LIKE '%%com.lyft.ios%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM items WHERE bundleid = 'com.lyft.ios' OR data LIKE '%%com.lyft.ios%%';\" 2>/dev/null || true", dbPath]];
        
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM main WHERE data LIKE '%%zimride%%' OR bundleid LIKE '%%zimride%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM apps WHERE data LIKE '%%zimride%%' OR bundleid LIKE '%%zimride%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM data WHERE data LIKE '%%zimride%%' OR bundleid LIKE '%%zimride%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM items WHERE data LIKE '%%zimride%%' OR bundleid LIKE '%%zimride%%';\" 2>/dev/null || true", dbPath]];
        // Add specific cleaning for Uber and Helix names in tables
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM main WHERE data LIKE '%%uber%%' OR bundleid LIKE '%%uber%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM apps WHERE data LIKE '%%uber%%' OR bundleid LIKE '%%uber%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM data WHERE data LIKE '%%uber%%' OR bundleid LIKE '%%uber%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM items WHERE data LIKE '%%uber%%' OR bundleid LIKE '%%uber%%';\" 2>/dev/null || true", dbPath]];
        
        // Specific case for com.ubercab.UberClient bundle ID
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM main WHERE bundleid = 'com.ubercab.UberClient' OR data LIKE '%%com.ubercab.UberClient%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM apps WHERE bundleid = 'com.ubercab.UberClient' OR data LIKE '%%com.ubercab.UberClient%%';\" 2>/dev/null || true", dbPath]];
//         [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' "DELETE FROM main WHERE bundleid = 'com.ubercab.UberClient' OR data LIKE '%%com.ubercab.UberClient%%';\" 2>/dev/null || true", dbPath]];
//         [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' "DELETE FROM apps WHERE bundleid = 'com.ubercab.UberClient' OR data LIKE '%%com.ubercab.UberClient%%';\" 2>/dev/null || true", dbPath]];
//         [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' "DELETE FROM data WHERE bundleid = 'com.ubercab.UberClient' OR data LIKE '%%com.ubercab.UberClient%%';\" 2>/dev/null || true", dbPath]];
//         [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' "DELETE FROM items WHERE bundleid = 'com.ubercab.UberClient' OR data LIKE '%%com.ubercab.UberClient%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM main WHERE data LIKE '%%helix%%' OR bundleid LIKE '%%helix%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM apps WHERE data LIKE '%%helix%%' OR bundleid LIKE '%%helix%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM data WHERE data LIKE '%%helix%%' OR bundleid LIKE '%%helix%%';\" 2>/dev/null || true", dbPath]];
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM items WHERE data LIKE '%%helix%%' OR bundleid LIKE '%%helix%%';\" 2>/dev/null || true", dbPath]];         
        // Also try to delete data based on app name and company name
        if (appName.length > 0) {
            [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM main WHERE data LIKE '%%%@%%';\" 2>/dev/null || true", dbPath, appName]];
            [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM apps WHERE data LIKE '%%%@%%';\" 2>/dev/null || true", dbPath, appName]];
            [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM data WHERE data LIKE '%%%@%%';\" 2>/dev/null || true", dbPath, appName]];
            [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM items WHERE data LIKE '%%%@%%';\" 2>/dev/null || true", dbPath, appName]];
        }
        
        if (companyName.length > 0) {
            [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM main WHERE data LIKE '%%%@%%';\" 2>/dev/null || true", dbPath, companyName]];
            [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM apps WHERE data LIKE '%%%@%%';\" 2>/dev/null || true", dbPath, companyName]];
            [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM data WHERE data LIKE '%%%@%%';\" 2>/dev/null || true", dbPath, companyName]];
            [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"DELETE FROM items WHERE data LIKE '%%%@%%';\" 2>/dev/null || true", dbPath, companyName]];
        }
        
        // Try to vacuum the database
        [self runCommandWithPrivileges:[NSString stringWithFormat:@"sqlite3 '%@' \"VACUUM;\" 2>/dev/null || true", dbPath]];
    } else if ([dbPath hasSuffix:@".sqlite-shm"] || [dbPath hasSuffix:@".sqlite-wal"] || 
               [dbPath hasSuffix:@".db-shm"] || [dbPath hasSuffix:@".db-wal"]) {
        // These are SQLite auxiliary files - clear them if main database also exists
        NSString *mainDbPath = [dbPath stringByReplacingOccurrencesOfString:@"-shm" withString:@""];
        mainDbPath = [mainDbPath stringByReplacingOccurrencesOfString:@"-wal" withString:@""];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:mainDbPath]) {
            // If the main database doesn't exist, we can safely remove these files
            NSLog(@"[AppDataCleaner] Removing SQLite auxiliary file: %@", dbPath);
            [self runCommandWithPrivileges:[NSString stringWithFormat:@"rm -f '%@'", dbPath]];
        }
    }
}

- (void)clearAppIssuesForIOS15:(NSString *)bundleID {
    NSLog(@"[AppDataCleaner] Fixing iOS 15+ specific issues for %@", bundleID);
    
    // Fix location services registration issues
    NSArray *locationPaths = @[
        // Location caches that might contain bad registrations
        [NSString stringWithFormat:@"/var/mobile/Library/Caches/locationd/%@*", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Caches/locationd/%@*", bundleID],
        // Special case for Lyft/Zimride
        @"/var/mobile/Library/Caches/locationd/*lyft*",
        @"/var/mobile/Library/Caches/locationd/*lyft*",
        @"/var/mobile/Library/Caches/locationd/*zimride*",
        @"/var/mobile/Library/Caches/locationd/*zimride*",
        // Extra case for com.lyft.ios specifically
        @"/var/mobile/Library/Caches/locationd/com.lyft.ios*",
        @"/var/mobile/Library/Caches/locationd/com.lyft.ios*",
        // Special case for Uber/Helix
        @"/var/mobile/Library/Caches/locationd/*uber*",
        @"/var/mobile/Library/Caches/locationd/*uber*",
        @"/var/mobile/Library/Caches/locationd/*helix*",
        @"/var/mobile/Library/Caches/locationd/*helix*",
        // Location client registrations
        [NSString stringWithFormat:@"/var/mobile/Library/locationd/clients.plist"],
        [NSString stringWithFormat:@"/var/mobile/Library/locationd/clients.plist"],
        // Extra case for com.ubercab.UberClient specifically
        @"/var/mobile/Library/Caches/locationd/com.ubercab.UberClient*",
        @"/var/mobile/Library/Caches/locationd/com.ubercab.UberClient*",
        // Special case for Uber/Helix
        @"/var/mobile/Library/Caches/locationd/*uber*",
        @"/var/mobile/Library/Caches/locationd/*uber*",
        @"/var/mobile/Library/Caches/locationd/*helix*",
        @"/var/mobile/Library/Caches/locationd/*helix*",
        // Extra case for com.ubercab.UberClient specifically
        @"/var/mobile/Library/Caches/locationd/com.ubercab.UberClient*",
        @"/var/mobile/Library/Caches/locationd/com.ubercab.UberClient*",
        // Location client registrations
        [NSString stringWithFormat:@"/var/mobile/Library/locationd/clients.plist"],
        [NSString stringWithFormat:@"/var/mobile/Library/locationd/clients.plist"]
    ];
    
    // Clear location cache files
    for (NSString *pattern in locationPaths) {
        if ([pattern hasSuffix:@".plist"]) {
            // For plist files, we need to modify them rather than delete
            if ([_fileManager fileExistsAtPath:pattern]) {
                NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"clients.plist.temp"];
                [_fileManager copyItemAtPath:pattern toPath:tempPath error:nil];
                
                NSMutableDictionary *clients = [NSMutableDictionary dictionaryWithContentsOfFile:tempPath];
                if (clients) {
                    // Remove any entries for this bundle ID
                    NSMutableArray *keysToRemove = [NSMutableArray arrayWithArray:[clients.allKeys filteredArrayUsingPredicate:
                                           [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@", bundleID]]];
                    
                    // Also remove Lyft and Zimride entries
                    [keysToRemove addObjectsFromArray:[clients.allKeys filteredArrayUsingPredicate:
                                           [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@", @"lyft"]]];
                    [keysToRemove addObjectsFromArray:[clients.allKeys filteredArrayUsingPredicate:
                                           [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@", @"zimride"]]];
                    
                    // Also remove Uber and Helix entries
                    [keysToRemove addObjectsFromArray:[clients.allKeys filteredArrayUsingPredicate:
                                           [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@", @"uber"]]];
                    [keysToRemove addObjectsFromArray:[clients.allKeys filteredArrayUsingPredicate:
                                           [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@", @"helix"]]];
                    
                    if (keysToRemove.count > 0) {
                        NSLog(@"[AppDataCleaner] Found %lu location client registrations to remove", (unsigned long)keysToRemove.count);
                        [keysToRemove enumerateObjectsUsingBlock:^(id key, NSUInteger idx, BOOL *stop) {
                            [clients removeObjectForKey:key];
                        }];
                        
                        [clients writeToFile:tempPath atomically:YES];
                        [self runCommandWithPrivileges:[NSString stringWithFormat:@"cp '%@' '%@'", tempPath, pattern]];
                    }
                }
                
                [_fileManager removeItemAtPath:tempPath error:nil];
            }
        } else {
            // Pattern-based file deletion
            NSArray *matches = [self findPathsMatchingPattern:pattern];
            for (NSString *path in matches) {
                NSLog(@"[AppDataCleaner] Wiping location cache file: %@", path);
                [self securelyWipeFile:path];
            }
        }
    }
    
    // Fix UI state issues specific to iOS 15+
    NSArray *uiStatePaths = @[
        // UISplitViewController state
        [NSString stringWithFormat:@"/var/mobile/Library/Preferences/com.apple.UIKit.plist"],
        [NSString stringWithFormat:@"/var/mobile/Library/Preferences/com.apple.UIKit.plist"],
        // App-specific UI state 
        [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@-UI-State.plist", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@-UI-State.plist", bundleID],
        // Special case for Lyft/Zimride
        @"/var/mobile/Library/Preferences/*lyft*-UI-State.plist",
        @"/var/mobile/Library/Preferences/*lyft*-UI-State.plist",
        @"/var/mobile/Library/Preferences/*zimride*-UI-State.plist",
        @"/var/mobile/Library/Preferences/*zimride*-UI-State.plist",
        // Extra case for com.lyft.ios specifically
        @"/var/mobile/Library/Preferences/com.lyft.ios-UI-State.plist",
        @"/var/mobile/Library/Preferences/com.lyft.ios-UI-State.plist",
        // Special case for Uber/Helix
        @"/var/mobile/Library/Preferences/*uber*-UI-State.plist",
        @"/var/mobile/Library/Preferences/*uber*-UI-State.plist",
        @"/var/mobile/Library/Preferences/*helix*-UI-State.plist",
        // Extra case for com.ubercab.UberClient specifically
        @"/var/mobile/Library/Preferences/com.ubercab.UberClient-UI-State.plist",
        @"/var/mobile/Library/Preferences/com.ubercab.UberClient-UI-State.plist",
        @"/var/mobile/Library/Preferences/*helix*-UI-State.plist",
        // SplitView controller state
        [NSString stringWithFormat:@"/var/mobile/Library/Preferences/com.apple.UIKit.SplitView.%@.plist", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Preferences/com.apple.UIKit.SplitView.%@.plist", bundleID],
        @"/var/mobile/Library/Preferences/com.apple.UIKit.SplitView.*lyft*.plist",
        @"/var/mobile/Library/Preferences/com.apple.UIKit.SplitView.*lyft*.plist",
        @"/var/mobile/Library/Preferences/com.apple.UIKit.SplitView.*zimride*.plist",
        @"/var/mobile/Library/Preferences/com.apple.UIKit.SplitView.*zimride*.plist",
        @"/var/mobile/Library/Preferences/com.apple.UIKit.SplitView.*uber*.plist",
        @"/var/mobile/Library/Preferences/com.apple.UIKit.SplitView.*uber*.plist",
        @"/var/mobile/Library/Preferences/com.apple.UIKit.SplitView.*helix*.plist",
        @"/var/mobile/Library/Preferences/com.apple.UIKit.SplitView.*helix*.plist"
    ];
    
    for (NSString *path in uiStatePaths) {
        // For patterns with wildcards, use findPathsMatchingPattern
        if ([path containsString:@"*"]) {
            NSArray *matches = [self findPathsMatchingPattern:path];
            for (NSString *matchPath in matches) {
                NSLog(@"[AppDataCleaner] Wiping UI state file: %@", matchPath);
                [self securelyWipeFile:matchPath];
            }
        } else if ([_fileManager fileExistsAtPath:path]) {
            NSLog(@"[AppDataCleaner] Wiping UI state file: %@", path);
            [self securelyWipeFile:path];
        }
    }
    
    // Fix snapshot denylisting for iOS 15+
    NSArray *snapshotPaths = @[
        [NSString stringWithFormat:@"/var/mobile/Library/SplashBoard/Snapshots/%@*", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/SplashBoard/Snapshots/%@*", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Caches/Snapshots/%@*", bundleID],
        [NSString stringWithFormat:@"/var/mobile/Library/Caches/Snapshots/%@*", bundleID],
        // Special case for Lyft/Zimride
        @"/var/mobile/Library/SplashBoard/Snapshots/*lyft*",
        @"/var/mobile/Library/SplashBoard/Snapshots/*lyft*",
        @"/var/mobile/Library/Caches/Snapshots/*lyft*",
        @"/var/mobile/Library/Caches/Snapshots/*lyft*",
        @"/var/mobile/Library/SplashBoard/Snapshots/*zimride*",
        @"/var/mobile/Library/SplashBoard/Snapshots/*zimride*",
        @"/var/mobile/Library/Caches/Snapshots/*zimride*",
        @"/var/mobile/Library/Caches/Snapshots/*zimride*",
        // Extra case for com.lyft.ios specifically
        @"/var/mobile/Library/SplashBoard/Snapshots/com.lyft.ios*",
        @"/var/mobile/Library/SplashBoard/Snapshots/com.lyft.ios*",
        @"/var/mobile/Library/Caches/Snapshots/com.lyft.ios*",
        @"/var/mobile/Library/Caches/Snapshots/com.lyft.ios*",
        // Special case for Uber/Helix
        @"/var/mobile/Library/SplashBoard/Snapshots/*uber*",
        @"/var/mobile/Library/SplashBoard/Snapshots/*uber*",
        @"/var/mobile/Library/Caches/Snapshots/*uber*",
        @"/var/mobile/Library/Caches/Snapshots/*uber*",
        @"/var/mobile/Library/SplashBoard/Snapshots/*helix*",
        // Extra case for com.ubercab.UberClient specifically
        @"/var/mobile/Library/SplashBoard/Snapshots/com.ubercab.UberClient*",
        @"/var/mobile/Library/SplashBoard/Snapshots/com.ubercab.UberClient*",
        @"/var/mobile/Library/Caches/Snapshots/com.ubercab.UberClient*",
        @"/var/mobile/Library/Caches/Snapshots/com.ubercab.UberClient*",
        @"/var/mobile/Library/SplashBoard/Snapshots/*helix*",
        @"/var/mobile/Library/Caches/Snapshots/*helix*",
        @"/var/mobile/Library/Caches/Snapshots/*helix*",
        // Snapshot deny list
        @"/var/mobile/Library/SpringBoard/ApplicationDenyList.plist",
        @"/var/mobile/Library/SpringBoard/ApplicationDenyList.plist"
    ];
    
    for (NSString *pattern in snapshotPaths) {
        if ([pattern hasSuffix:@"DenyList.plist"]) {
            // For deny list, we need to modify it rather than delete
            if ([_fileManager fileExistsAtPath:pattern]) {
                NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"denylist.plist.temp"];
                [_fileManager copyItemAtPath:pattern toPath:tempPath error:nil];
                
                NSMutableDictionary *denyList = [NSMutableDictionary dictionaryWithContentsOfFile:tempPath];
                if (denyList) {
                    // Create list of keys to remove
                    NSMutableArray *keysToRemove = [NSMutableArray array];
                    
                    // Remove this app from the deny list
                    if ([denyList objectForKey:bundleID]) {
                        [keysToRemove addObject:bundleID];
                    }
                    
                    // Check for Lyft and Zimride entries
                    for (NSString *key in denyList.allKeys) {
                        if ([key containsString:@"lyft"] || [key containsString:@"zimride"]) {
                            [keysToRemove addObject:key];
                        }
                    }
                    
                    // Also remove Uber and Helix entries
                    for (NSString *key in denyList.allKeys) {
                        if ([key containsString:@"uber"] || [key containsString:@"helix"]) {
                            [keysToRemove addObject:key];
                        }
                    }
                    
                    if (keysToRemove.count > 0) {
                        NSLog(@"[AppDataCleaner] Removing %lu entries from snapshot deny list", (unsigned long)keysToRemove.count);
                        for (NSString *key in keysToRemove) {
                            [denyList removeObjectForKey:key];
                        }
                        [denyList writeToFile:tempPath atomically:YES];
                        [self runCommandWithPrivileges:[NSString stringWithFormat:@"cp '%@' '%@'", tempPath, pattern]];
                    }
                }
                
                [_fileManager removeItemAtPath:tempPath error:nil];
            }
        } else {
            // Pattern-based file deletion
            NSArray *matches = [self findPathsMatchingPattern:pattern];
            for (NSString *path in matches) {
                NSLog(@"[AppDataCleaner] Wiping snapshot file: %@", path);
                [self securelyWipeFile:path];
            }
        }
    }
}

// Helper method to check if directory exists and has any content at all, ignoring system files
- (BOOL)directoryExistsAndHasAnyContent:(NSString *)path {
    if (!path.length) {
        return NO;
    }
    if (![_fileManager fileExistsAtPath:path]) {
        NSLog(@"[AppDataCleaner] Directory does not exist: %@", path);
        return NO;
    }

    // Check for any regular file (ignore dotpaths) up to a shallow depth.
    NSString *command = [NSString stringWithFormat:@"find '%@' -maxdepth 3 -type f -not -path '*/\\.*' -print | head -n 1", path];
    NSString *result = [self runCommandAndGetOutput:command];
    if (result.length > 0 && ![result isEqualToString:@"error"]) {
        NSLog(@"[AppDataCleaner] Found at least one file in directory: %@", path);
        return YES;
    }

    // Backup: check for any non-system subdirectory (ignore .com.apple*).
    command = [NSString stringWithFormat:@"find '%@' -mindepth 1 -maxdepth 2 -type d -not -path '*/\\.*' -print | grep -v '\\.?com\\.apple' | head -n 1", path];
    result = [self runCommandAndGetOutput:command];
    if (result.length > 0 && ![result isEqualToString:@"error"]) {
        NSLog(@"[AppDataCleaner] Found subdirectories in: %@", path);
        return YES;
    }

    return NO;
}

// Helper method to check if the app has any references in system databases
- (BOOL)hasSystemDatabaseReferencesForBundleID:(NSString *)bundleID {
    NSArray *parts = [bundleID componentsSeparatedByString:@"."];
    NSString *appName = parts.lastObject;
    NSString *company = parts.count > 1 ? parts[1] : @"";
    
    // Check for entry in launch services database
    NSArray *dbPaths = @[
        @"/var/mobile/Library/MobileInstallation/LastLaunchServicesMap.plist",
        @"/var/mobile/Library/MobileInstallation/LastLaunchServicesMap.plist"
    ];
    
    for (NSString *dbPath in dbPaths) {
        if ([_fileManager fileExistsAtPath:dbPath]) {
            NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:dbPath];
            if (plist[@"System"] && [plist[@"System"] objectForKey:bundleID]) {
                NSLog(@"[AppDataCleaner] Found reference in LaunchServices database: %@", bundleID);
                return YES;
            }
            
            if (plist[@"User"] && [plist[@"User"] objectForKey:bundleID]) {
                NSLog(@"[AppDataCleaner] Found reference in LaunchServices database: %@", bundleID);
                return YES;
            }
        }
    }
    
    // Check for entries in IconState.plist
    NSArray *iconStatePaths = @[
        @"/var/mobile/Library/SpringBoard/IconState.plist",
        @"/var/mobile/Library/SpringBoard/IconState.plist"
    ];
    
    for (NSString *iconPath in iconStatePaths) {
        if ([_fileManager fileExistsAtPath:iconPath]) {
            NSString *command = [NSString stringWithFormat:@"cat '%@' | grep -q '%@' && echo 'found' || echo 'not found'", iconPath, bundleID];
            NSString *result = [self runCommandAndGetOutput:command];
            if ([result containsString:@"found"]) {
                NSLog(@"[AppDataCleaner] Found reference in IconState.plist: %@", bundleID);
                return YES;
            }
        }
    }
    
    // Check for app in notification settings
    NSArray *notifPaths = @[
        @"/var/mobile/Library/Preferences/com.apple.notifyd.plist",
        @"/var/mobile/Library/Preferences/com.apple.notifyd.plist"
    ];
    
    for (NSString *notifPath in notifPaths) {
        if ([_fileManager fileExistsAtPath:notifPath]) {
            NSString *command = [NSString stringWithFormat:@"cat '%@' | grep -q '%@' && echo 'found' || echo 'not found'", notifPath, bundleID];
            NSString *result = [self runCommandAndGetOutput:command];
            if ([result containsString:@"found"]) {
                NSLog(@"[AppDataCleaner] Found reference in notification settings: %@", bundleID);
                return YES;
            }
        }
    }
    
    // Check for any references in SQLite databases
    NSArray *sqlitePaths = @[
        @"/var/mobile/Library/SpringBoard/ApplicationHistory.sqlite",
        @"/var/mobile/Library/Assistant/SiriAnalytics.db",
        @"/var/mobile/Library/SpringBoard/ApplicationHistory.sqlite",
        @"/var/mobile/Library/Assistant/SiriAnalytics.db"
    ];
    
    for (NSString *sqlitePath in sqlitePaths) {
        if ([_fileManager fileExistsAtPath:sqlitePath]) {
            // Check for bundle ID
            NSString *command = [NSString stringWithFormat:@"sqlite3 '%@' \"SELECT count(*) FROM sqlite_master WHERE type='table' AND sql LIKE '%%%@%%';\" 2>/dev/null || echo '0'", sqlitePath, bundleID];
            NSString *result = [self runCommandAndGetOutput:command];
            if (![result isEqualToString:@"0"] && ![result isEqualToString:@"error"]) {
                NSLog(@"[AppDataCleaner] Found reference in database: %@", sqlitePath);
                return YES;
            }
            
            // Also check for app name or company if bundle ID not found
            if (appName.length > 3) {
                command = [NSString stringWithFormat:@"sqlite3 '%@' \"SELECT count(*) FROM sqlite_master WHERE type='table' AND sql LIKE '%%%@%%';\" 2>/dev/null || echo '0'", sqlitePath, appName];
                result = [self runCommandAndGetOutput:command];
                if (![result isEqualToString:@"0"] && ![result isEqualToString:@"error"]) {
                    NSLog(@"[AppDataCleaner] Found reference to app name in database: %@", sqlitePath);
                    return YES;
                }
            }
            
            if (company.length > 3) {
                command = [NSString stringWithFormat:@"sqlite3 '%@' \"SELECT count(*) FROM sqlite_master WHERE type='table' AND sql LIKE '%%%@%%';\" 2>/dev/null || echo '0'", sqlitePath, company];
                result = [self runCommandAndGetOutput:command];
                if (![result isEqualToString:@"0"] && ![result isEqualToString:@"error"]) {
                    NSLog(@"[AppDataCleaner] Found reference to company name in database: %@", sqlitePath);
                    return YES;
                }
            }
        }
    }
    
    // If we didn't find anything in system databases, return false
    return NO;
}

// NEW: Method to check if there are keychain items for a bundle ID
@end
