#import "AppDataBackupManager.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <CoreFoundation/CoreFoundation.h>

#import "AppDataCleaner.h"
#import "FreezeManager.h"

#import "AppEntitlementsReader.h"
#import "AppGroupContainerResolver.h"
#import "PXBackupManifestValidator.h"
#import "PXBackupArtifactVerifier.h"
#import "PXBackupArchiveValidator.h"
#import "PXRestorePlan.h"
#import "PXAppGroupRestoreTargetPlan.h"
#import "PXOptionalRestoreStaging.h"
#import "PXMainDataStaging.h"
#import "PXMainDataRestoreTransaction.h"
#import "PXDataContainerResolver.h"
#import "PXDestructivePathValidator.h"
#import "CommandRunner.h"
#import "common/PXProcessKiller.h"
#import "common/PXPaths.h"

#import <CommonCrypto/CommonDigest.h>
#import <notify.h>

static NSString * const PXBackupErrorDomain = @"com.hydra.projectx.backup";
static NSString * const PXExactRestoreDestinationErrorDescription =
    @"Exact application data container could not be resolved safely";

static BOOL PXReadUnsignedIntegralSummaryNumber(id value,
                                                unsigned long long *numberOut) {
    if (![value isKindOfClass:[NSNumber class]] ||
        CFGetTypeID((__bridge CFTypeRef)value) != CFNumberGetTypeID()) {
        return NO;
    }
    const char *type = [(NSNumber *)value objCType];
    if (!type || !type[0]) {
        return NO;
    }
    unsigned long long unsignedValue = 0;
    switch (type[0]) {
        case 'C':
        case 'S':
        case 'I':
        case 'L':
        case 'Q':
            unsignedValue = [(NSNumber *)value unsignedLongLongValue];
            break;
        case 'c':
        case 's':
        case 'i':
        case 'l':
        case 'q': {
            long long signedValue = [(NSNumber *)value longLongValue];
            if (signedValue < 0) {
                return NO;
            }
            unsignedValue = (unsigned long long)signedValue;
            break;
        }
        default:
            return NO;
    }
    if (numberOut) {
        *numberOut = unsignedValue;
    }
    return YES;
}

static BOOL PXValidatedMainDataStagesAreEquivalent(PXValidatedMainDataStage *left,
                                                    PXValidatedMainDataStage *right) {
    if (![left isKindOfClass:[PXValidatedMainDataStage class]] ||
        ![right isKindOfClass:[PXValidatedMainDataStage class]]) {
        return NO;
    }
    return [left.treeSHA256 isEqualToString:right.treeSHA256] &&
           left.entryCount == right.entryCount &&
           left.regularFileCount == right.regularFileCount &&
           left.directoryCount == right.directoryCount &&
           left.regularFileBytes == right.regularFileBytes;
}

static BOOL PXCleanupOptionalFileWorkspaces(
    NSArray<PXOptionalFileStagingWorkspace *> *workspaces) {
    BOOL allCleaned = YES;
    for (PXOptionalFileStagingWorkspace *workspace in workspaces) {
        NSError *cleanupError = nil;
        if (![workspace cleanupWithError:&cleanupError]) {
            allCleaned = NO;
        }
    }
    return allCleaned;
}

static BOOL PXBackupManifestVersionIsSupported(NSNumber *version) {
    if (![version isKindOfClass:[NSNumber class]]) {
        return NO;
    }

    NSInteger value = version.integerValue;
    return value == 2 || value == 3;
}

static BOOL PXResolveExactRestoreApplicationDataTarget(
    NSString *bundleID,
    PXResolvedContainer **containerOut,
    NSString **canonicalPathOut,
    NSError **error) {
    if (containerOut) {
        *containerOut = nil;
    }
    if (canonicalPathOut) {
        *canonicalPathOut = nil;
    }
    if (error) {
        *error = nil;
    }

    BOOL resolved = NO;
    do {
        if (![bundleID isKindOfClass:[NSString class]] || bundleID.length == 0) {
            break;
        }

        PXDataContainerResolver *resolver = [[PXDataContainerResolver alloc] init];
        PXDestructivePathValidator *validator = [[PXDestructivePathValidator alloc] init];

        PXResolvedContainer *selectedModel = nil;
        NSString *selectedCanonicalPath = nil;

        NSError *rootfulResolverError = nil;
        PXResolvedContainer *rootfulModel =
            [resolver resolveApplicationDataContainerForIdentifier:bundleID
                                                              root:PXResolvedContainerRootRootful
                                                             error:&rootfulResolverError];
        if (rootfulResolverError) {
            break;
        }
        if (rootfulModel) {
            NSError *rootfulValidationError = nil;
            NSString *rootfulCanonicalPath =
                [validator validatedCanonicalPathForContainer:rootfulModel
                                                        error:&rootfulValidationError];
            if (rootfulValidationError || rootfulCanonicalPath.length == 0) {
                break;
            }
            selectedModel = rootfulModel;
            selectedCanonicalPath = rootfulCanonicalPath;
        }

        NSError *rootlessResolverError = nil;
        PXResolvedContainer *rootlessModel =
            [resolver resolveApplicationDataContainerForIdentifier:bundleID
                                                              root:PXResolvedContainerRootRootless
                                                             error:&rootlessResolverError];
        if (rootlessResolverError) {
            break;
        }
        if (rootlessModel) {
            NSError *rootlessValidationError = nil;
            NSString *rootlessCanonicalPath =
                [validator validatedCanonicalPathForContainer:rootlessModel
                                                        error:&rootlessValidationError];
            if (rootlessValidationError || rootlessCanonicalPath.length == 0) {
                break;
            }
            if (!selectedModel) {
                selectedModel = rootlessModel;
                selectedCanonicalPath = rootlessCanonicalPath;
            } else if (![selectedCanonicalPath isEqualToString:rootlessCanonicalPath]) {
                break;
            }
        }

        if (!selectedModel || selectedCanonicalPath.length == 0) {
            break;
        }

        if (containerOut) {
            *containerOut = selectedModel;
        }
        if (canonicalPathOut) {
            *canonicalPathOut = selectedCanonicalPath;
        }
        resolved = YES;
    } while (NO);

    if (resolved) {
        return YES;
    }

    if (error) {
        *error = [NSError errorWithDomain:PXBackupErrorDomain
                                     code:303
                                 userInfo:@{NSLocalizedDescriptionKey: PXExactRestoreDestinationErrorDescription}];
    }
    return NO;
}

@implementation PXBackupResult
@end

@implementation PXRestoreResult
@end

@implementation AppDataBackupManager

static NSString *PXDataContainerPathFromLaunchServices(NSString *bundleID);

static void PXDebugAppendLine(NSString *path, NSString *line) {
    if (!path.length || !line.length) return;
    @autoreleasepool {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *dir = [path stringByDeletingLastPathComponent];
        if (dir.length) {
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSString *out = [line stringByAppendingString:@"\n"];
        NSData *data = [out dataUsingEncoding:NSUTF8StringEncoding];
        if (!data) return;

        if (![fm fileExistsAtPath:path]) {
            [data writeToFile:path atomically:YES];
            return;
        }
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!fh) {
            [data writeToFile:path atomically:YES];
            return;
        }
        @try {
            [fh seekToEndOfFile];
            [fh writeData:data];
        } @catch (__unused NSException *e) {
        }
        [fh closeFile];
    }
}

static void PXDebugHeader(NSString *path, NSString *title) {
    PXDebugAppendLine(path, @"----------------------------------------");
    PXDebugAppendLine(path, [NSString stringWithFormat:@"[%@] %@", [NSDate date], title ?: @""]);
}

static void PXDebugRun(CommandRunner *runner, NSString *path, NSString *label, NSString *cmd) {
    if (!runner || !path.length || !cmd.length) return;
    PXDebugAppendLine(path, [NSString stringWithFormat:@"> %@", label ?: @"cmd"]);
    PXDebugAppendLine(path, [NSString stringWithFormat:@"$ %@", cmd]);
    CommandResult *res = [runner runAndCapture:cmd];
    PXDebugAppendLine(path, [NSString stringWithFormat:@"exit=%d", (int)res.exitCode]);
    if (res.stdoutString.length) {
        PXDebugAppendLine(path, @"[stdout]");
        PXDebugAppendLine(path, res.stdoutString);
    }
    if (res.stderrString.length) {
        PXDebugAppendLine(path, @"[stderr]");
        PXDebugAppendLine(path, res.stderrString);
    }
}

static NSDictionary *PXResolvePathsForBundleID(NSString *bundleID) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    out[@"bundleID"] = bundleID ?: @"";

    NSString *dataPath = PXDataContainerPathFromLaunchServices(bundleID);
    if (dataPath) out[@"lsDataContainerPath"] = dataPath;

    // Also capture containerURL for debugging (may be bundle container).
    NSString *containerURLPath = nil;
    @autoreleasepool {
        Class LSApplicationProxyClass = NSClassFromString(@"LSApplicationProxy");
        SEL sel = NSSelectorFromString(@"applicationProxyForIdentifier:");
        if (LSApplicationProxyClass && [LSApplicationProxyClass respondsToSelector:sel]) {
            id proxy = ((id (*)(id, SEL, id))objc_msgSend)(LSApplicationProxyClass, sel, bundleID);
            if (proxy) {
                id url = nil;
                @try { url = [proxy valueForKey:@"containerURL"]; } @catch (__unused NSException *e) {}
                if ([url isKindOfClass:[NSURL class]]) {
                    containerURLPath = [(NSURL *)url path];
                } else if ([url isKindOfClass:[NSString class]]) {
                    containerURLPath = (NSString *)url;
                }
            }
        }
    }
    if (containerURLPath) out[@"lsContainerURLPath"] = containerURLPath;

    return out;
}

+ (instancetype)shared {
    static AppDataBackupManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

static NSString *PXShellQuote(NSString *s) {
    NSString *escaped = [s stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]; 
    return [NSString stringWithFormat:@"'%@'", escaped];
}

static NSString *PXSanitizeFilenameComponent(NSString *s) {
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_"].invertedSet;
    NSString *out = [[s componentsSeparatedByCharactersInSet:allowed] componentsJoinedByString:@"_"];
    return out.length ? out : @"unknown";
}

static NSString *PXDataContainerPathFromLaunchServices(NSString *bundleID) {
    if (!bundleID.length) return nil;
    Class LSApplicationProxyClass = NSClassFromString(@"LSApplicationProxy");
    if (!LSApplicationProxyClass) return nil;

    SEL sel = NSSelectorFromString(@"applicationProxyForIdentifier:");
    if (![LSApplicationProxyClass respondsToSelector:sel]) return nil;

    id proxy = ((id (*)(id, SEL, id))objc_msgSend)(LSApplicationProxyClass, sel, bundleID);
    if (!proxy) return nil;

    id url = nil;
    @try {
        url = [proxy valueForKey:@"dataContainerURL"]; 
        if (!url) {
            url = [proxy valueForKey:@"containerURL"]; 
        }
    } @catch (__unused NSException *e) {
        url = nil;
    }
    if ([url isKindOfClass:[NSURL class]]) {
        return [(NSURL *)url path];
    }
    if ([url isKindOfClass:[NSString class]]) {
        return (NSString *)url;
    }
    return nil;
}

static NSString *PXBackupKeychainGroupsKey(NSString *bundleID) {
    return [NSString stringWithFormat:@"dataBackupKeychainGroups_%@", bundleID ?: @""];
}

static NSData *PXFileSHA256(NSString *path) {
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!fh) return nil;
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);
    for (;;) {
        @autoreleasepool {
            NSData *data = [fh readDataOfLength:(1024 * 1024)];
            if (!data.length) {
                break;
            }
            CC_SHA256_Update(&ctx, data.bytes, (CC_LONG)data.length);
        }
    }
    [fh closeFile];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &ctx);
    return [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
}

static NSString *PXHexString(NSData *data) {
    if (!data.length) return @"";
    const unsigned char *bytes = data.bytes;
    NSMutableString *out = [NSMutableString stringWithCapacity:data.length * 2];
    for (NSUInteger i = 0; i < data.length; i++) {
        [out appendFormat:@"%02x", bytes[i]];
    }
    return out;
}

static NSDictionary *PXArtifactInfo(NSString *path, NSString *name) {
    if (!path.length) return nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
    NSNumber *size = attrs[NSFileSize];
    NSData *sha = PXFileSHA256(path);
    return @{
        @"name": name ?: path.lastPathComponent ?: @"",
        @"path": path,
        @"size": size ?: @0,
        @"sha256": sha ? PXHexString(sha) : @""
    };
}

static unsigned long long PXArtifactsTotalSize(NSArray<NSDictionary *> *artifacts) {
    unsigned long long total = 0;
    for (NSDictionary *artifact in artifacts) {
        if (![artifact isKindOfClass:[NSDictionary class]]) continue;
        NSNumber *size = artifact[@"size"];
        if ([size respondsToSelector:@selector(unsignedLongLongValue)]) {
            total += [size unsignedLongLongValue];
        }
    }
    return total;
}

static NSArray<NSString *> *PXIncludedOptionNames(PXBackupOptions options) {
    NSMutableArray<NSString *> *out = [NSMutableArray arrayWithObject:@"DataContainer"];
    if (options & PXBackupOptionIncludeAppGroups) [out addObject:@"AppGroups"];
    if (options & PXBackupOptionIncludePreferences) [out addObject:@"GlobalPreferences"];
    if (options & PXBackupOptionIncludeKeychain) [out addObject:@"Keychain"];
    return out;
}

static NSArray<NSString *> *PXExcludedOptionNames(PXBackupOptions options) {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    if (!(options & PXBackupOptionIncludeAppGroups)) [out addObject:@"AppGroups"];
    if (!(options & PXBackupOptionIncludePreferences)) [out addObject:@"GlobalPreferences"];
    if (!(options & PXBackupOptionIncludeKeychain)) [out addObject:@"Keychain"];
    return out;
}

static NSString *PXVerifyArtifact(NSString *backupDir, NSDictionary *artifact) {
    if (!backupDir.length || ![artifact isKindOfClass:[NSDictionary class]]) return @"invalid artifact metadata";
    NSString *name = [artifact[@"name"] isKindOfClass:[NSString class]] ? artifact[@"name"] : nil;
    if (!name.length) return @"artifact missing name";
    NSString *path = [backupDir stringByAppendingPathComponent:name];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return [NSString stringWithFormat:@"artifact missing: %@", name];
    }
    NSNumber *expectedSize = artifact[@"size"];
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSNumber *actualSize = attrs[NSFileSize];
    if ([expectedSize respondsToSelector:@selector(unsignedLongLongValue)] && [actualSize respondsToSelector:@selector(unsignedLongLongValue)] &&
        [expectedSize unsignedLongLongValue] != [actualSize unsignedLongLongValue]) {
        return [NSString stringWithFormat:@"artifact size mismatch: %@", name];
    }
    NSString *expectedHash = [artifact[@"sha256"] isKindOfClass:[NSString class]] ? artifact[@"sha256"] : nil;
    if (expectedHash.length) {
        NSString *actualHash = PXHexString(PXFileSHA256(path));
        if (actualHash.length && ![actualHash isEqualToString:expectedHash]) {
            return [NSString stringWithFormat:@"artifact sha256 mismatch: %@", name];
        }
    }
    return nil;
}

static BOOL PXContainerUUIDMatchesBundleID(NSFileManager *fm, NSString *baseDir, NSString *uuid, NSString *bundleID) {
    if (!baseDir.length || !uuid.length || !bundleID.length) return NO;
    NSString *containerPath = [baseDir stringByAppendingPathComponent:uuid];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:containerPath isDirectory:&isDir] || !isDir) return NO;
    NSString *metadataPath = [containerPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
    NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
    id ident = [meta isKindOfClass:[NSDictionary class]] ? meta[@"MCMMetadataIdentifier"] : nil;
    if ([ident isKindOfClass:[NSString class]]) {
        return [(NSString *)ident isEqualToString:bundleID];
    }
    if ([ident isKindOfClass:[NSArray class]]) {
        return [(NSArray *)ident containsObject:bundleID];
    }
    return NO;
}

static NSString *PXFindDataContainerUUIDByMetadata(NSFileManager *fm, NSString *baseDir, NSString *bundleID) {
    if (!baseDir.length || !bundleID.length) return nil;
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:baseDir isDirectory:&isDir] || !isDir) return nil;
    NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:baseDir error:nil];
    for (NSString *uuid in items) {
        if (![uuid isKindOfClass:[NSString class]] || uuid.length < 8) continue;
        if ([uuid hasPrefix:@"."]) continue;
        if (PXContainerUUIDMatchesBundleID(fm, baseDir, uuid, bundleID)) {
            return uuid;
        }
    }
    return nil;
}

- (void)_killRelatedProcessesForBundleID:(NSString *)bundleID {
    // Always kill the main app process via existing manager.
    [[FreezeManager sharedManager] killApplication:bundleID];

    // Best-effort hard kill by executable name (helps when the app is SIGSTOP'd).
    @try {
        if (bundleID.length) {
            Class proxyCls = NSClassFromString(@"LSApplicationProxy");
            SEL sel = NSSelectorFromString(@"applicationProxyForIdentifier:");
            id proxy = (proxyCls && [proxyCls respondsToSelector:sel]) ? ((id (*)(id, SEL, id))objc_msgSend)(proxyCls, sel, bundleID) : nil;
            NSString *exe = nil;
            if (proxy && [proxy respondsToSelector:@selector(bundleExecutable)]) {
                exe = [proxy performSelector:@selector(bundleExecutable)];
            }
            if ([exe isKindOfClass:[NSString class]] && exe.length) {
                PXKillallByName(exe, SIGKILL);
            }
        }
    } @catch (__unused NSException *e) {
    }

    // Safari has multiple helper processes that can keep databases open.
    if ([bundleID isEqualToString:@"com.apple.mobilesafari"]) {
        NSArray<NSString *> *names = @[
            @"MobileSafari",
            @"SafariViewService",
            @"com.apple.WebKit.WebContent",
            @"com.apple.WebKit.Networking"
        ];
        PXKillallTermThenKillMany(names, 0.1);
    }

    // Generic extra stopping for system apps: many have an associated daemon named <exe> + "d".
    @try {
        Class proxyCls = NSClassFromString(@"LSApplicationProxy");
        SEL sel = NSSelectorFromString(@"applicationProxyForIdentifier:");
        id proxy = (proxyCls && [proxyCls respondsToSelector:sel]) ? ((id (*)(id, SEL, id))objc_msgSend)(proxyCls, sel, bundleID) : nil;
        NSString *appType = nil;
        NSString *exe = nil;
        if (proxy) {
            @try { appType = [proxy valueForKey:@"applicationType"]; } @catch (__unused NSException *e) {}
            @try { exe = [proxy valueForKey:@"bundleExecutable"]; } @catch (__unused NSException *e) {}
        }

        BOOL isSystem = ([appType isKindOfClass:[NSString class]] && [(NSString *)appType isEqualToString:@"System"]);
        if (isSystem && [exe isKindOfClass:[NSString class]] && exe.length) {
            NSString *daemon = [[(NSString *)exe lowercaseString] stringByAppendingString:@"d"]; 
            NSArray<NSString *> *names = @[ (NSString *)exe, daemon ];
            PXKillallTermThenKillMany(names, 0.15);
        }
    } @catch (__unused NSException *e) {
    }
}

- (NSString *)_globalSafariLibraryPath {
    CommandRunner *runner = [CommandRunner shared];
    return [runner firstExistingPath:@[
        @"/var/mobile/Library/Safari",
        @"/private/var/mobile/Library/Safari",
        @"/var/jb/var/mobile/Library/Safari",
        @"/private/var/jb/var/mobile/Library/Safari"
    ]];
}

- (CommandResult *)_tarCreate:(NSString *)tarPath fromDir:(NSString *)sourceDir toArchive:(NSString *)archivePath {
    CommandRunner *runner = [CommandRunner shared];

    // Prefer preserving extended attributes (file protection class), ACLs and numeric owners.
    NSString *cmd = [NSString stringWithFormat:@"%@ --xattrs --acls --numeric-owner -czf %@ --exclude '.com.apple.mobile_container_manager.metadata.plist' --exclude '.com.apple.containermanagerd.metadata.plist' -C %@ .",
                     PXShellQuote(tarPath),
                     PXShellQuote(archivePath),
                     PXShellQuote(sourceDir)];
    CommandResult *res = [runner runAndCapture:cmd];
    if (res.exitCode == 0) {
        return res;
    }

    // Fallback for tar variants without these flags.
    NSString *fallback = [NSString stringWithFormat:@"%@ -czf %@ --exclude '.com.apple.mobile_container_manager.metadata.plist' --exclude '.com.apple.containermanagerd.metadata.plist' -C %@ .",
                          PXShellQuote(tarPath),
                          PXShellQuote(archivePath),
                          PXShellQuote(sourceDir)];
    return [runner runAndCapture:fallback];
}

static NSString *PXTimestampSuffix(void) {
    return [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
}

- (NSString *)_mobileLibraryBasePath {
    // Support rootful + common jailbreak layouts.
    CommandRunner *runner = [CommandRunner shared];
    NSString *dir = [runner firstExistingPath:@[
        @"/var/mobile/Library",
        @"/private/var/mobile/Library",
        @"/var/jb/var/mobile/Library",
        @"/private/var/jb/var/mobile/Library"
    ]];
    return dir ?: @"/var/mobile/Library";
}

- (BOOL)_isSystemAppBundleID:(NSString *)bundleID {
    if (!bundleID.length) return NO;
    @try {
        Class proxyCls = NSClassFromString(@"LSApplicationProxy");
        SEL sel = NSSelectorFromString(@"applicationProxyForIdentifier:");
        id proxy = (proxyCls && [proxyCls respondsToSelector:sel]) ? ((id (*)(id, SEL, id))objc_msgSend)(proxyCls, sel, bundleID) : nil;
        NSString *appType = nil;
        if (proxy) {
            @try { appType = [proxy valueForKey:@"applicationType"]; } @catch (__unused NSException *e) {}
        }
        return ([appType isKindOfClass:[NSString class]] && [(NSString *)appType isEqualToString:@"System"]);
    } @catch (__unused NSException *e) {
        return NO;
    }
}

static NSArray<NSDictionary *> *PXSharedSystemDBSpecs(void) {
    // Shared, system-scoped databases that are commonly used by multiple system apps.
    // Paths are relative to /var/mobile/Library.
    return @[
        @{ @"libraryRel": @"Accounts/Accounts3.sqlite", @"backupName": @"Accounts3.sqlite" },
        @{ @"libraryRel": @"SMS/sms.db", @"backupName": @"sms.db" },
        @{ @"libraryRel": @"Calendar/Calendar.sqlitedb", @"backupName": @"Calendar.sqlitedb" },
        @{ @"libraryRel": @"AddressBook/AddressBook.sqlitedb", @"backupName": @"AddressBook.sqlitedb" },

        // Notes database name varies by iOS.
        @{ @"libraryRel": @"Notes/NoteStore.sqlite", @"backupName": @"NoteStore.sqlite" },
        @{ @"libraryRel": @"Notes/notes.sqlite", @"backupName": @"notes.sqlite" },
    ];
}

static NSArray<NSDictionary *> *PXExpandSQLiteSidecars(NSDictionary *spec) {
    // For sqlite DBs, also include -wal and -shm if they exist.
    NSString *rel = [spec[@"libraryRel"] isKindOfClass:[NSString class]] ? spec[@"libraryRel"] : nil;
    NSString *bn = [spec[@"backupName"] isKindOfClass:[NSString class]] ? spec[@"backupName"] : nil;
    if (!rel.length || !bn.length) return @[];

    return @[
        @{ @"libraryRel": rel, @"backupName": bn },
        @{ @"libraryRel": [rel stringByAppendingString:@"-wal"], @"backupName": [bn stringByAppendingString:@"-wal"] },
        @{ @"libraryRel": [rel stringByAppendingString:@"-shm"], @"backupName": [bn stringByAppendingString:@"-shm"] },
    ];
}

static NSString *PXCleanSubdirName(NSString *s) {
    if (![s isKindOfClass:[NSString class]] || !s.length) return nil;
    NSString *name = [s lastPathComponent];
    if (!name.length) return nil;
    if ([name containsString:@"/"] || [name containsString:@"\\"]) return nil;
    if ([name isEqualToString:@"."] || [name isEqualToString:@".."]) return nil;
    return name;
}

- (NSArray<NSDictionary *> *)_systemGlobalLibraryItemsForBundleID:(NSString *)bundleID {
    if (!bundleID.length) return @[];

    NSString *appType = nil;
    NSString *exe = nil;
    NSString *localized = nil;
    @autoreleasepool {
        Class proxyCls = NSClassFromString(@"LSApplicationProxy");
        SEL sel = NSSelectorFromString(@"applicationProxyForIdentifier:");
        id proxy = (proxyCls && [proxyCls respondsToSelector:sel]) ? ((id (*)(id, SEL, id))objc_msgSend)(proxyCls, sel, bundleID) : nil;
        if (proxy) {
            @try { appType = [proxy valueForKey:@"applicationType"]; } @catch (__unused NSException *e) {}
            @try { exe = [proxy valueForKey:@"bundleExecutable"]; } @catch (__unused NSException *e) {}
            @try { localized = [proxy valueForKey:@"localizedName"]; } @catch (__unused NSException *e) {}
        }
    }

    BOOL isSystem = ([appType isKindOfClass:[NSString class]] && [(NSString *)appType isEqualToString:@"System"]);
    if (!isSystem) return @[];

    NSMutableOrderedSet<NSString *> *candidates = [NSMutableOrderedSet orderedSet];
    NSString *a = PXCleanSubdirName(localized);
    NSString *b = PXCleanSubdirName(exe);
    if (a.length) [candidates addObject:a];
    if (b.length) [candidates addObject:b];

    NSString *base = [self _mobileLibraryBasePath];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
    for (NSString *subdir in candidates.array) {
        NSString *p = [base stringByAppendingPathComponent:subdir];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:p isDirectory:&isDir] && isDir) {
            [items addObject:@{ @"subdir": subdir, @"path": p }];
        }
    }
    return items;
}

- (CommandResult *)_tarExtract:(NSString *)tarPath archive:(NSString *)archivePath toDir:(NSString *)destDir {
    CommandRunner *runner = [CommandRunner shared];

    NSString *cmd = [NSString stringWithFormat:@"%@ --xattrs --acls -xzf %@ -C %@",
                     PXShellQuote(tarPath),
                     PXShellQuote(archivePath),
                     PXShellQuote(destDir)];
    CommandResult *res = [runner runAndCapture:cmd];
    if (res.exitCode == 0) {
        return res;
    }

    NSString *fallback = [NSString stringWithFormat:@"%@ -xzf %@ -C %@",
                          PXShellQuote(tarPath),
                          PXShellQuote(archivePath),
                          PXShellQuote(destDir)];
    return [runner runAndCapture:fallback];
}

- (CommandResult *)_tarExtractDataArchive:(NSString *)tarPath
                                  archive:(NSString *)archivePath
                                    toDir:(NSString *)destDir
                                 warnings:(NSMutableArray<NSString *> *)warnings {
    (void)warnings;
    return [self _tarExtract:tarPath archive:archivePath toDir:destDir];
}

- (NSString *)_preferencesDirectory {
    // Support rootful + common jailbreak layouts.
    CommandRunner *runner = [CommandRunner shared];
    NSString *dir = [runner firstExistingPath:@[
        @"/var/mobile/Library/Preferences",
        @"/private/var/mobile/Library/Preferences",
        @"/var/jb/var/mobile/Library/Preferences",
        @"/private/var/jb/var/mobile/Library/Preferences"
    ]];
    return dir ?: @"/var/mobile/Library/Preferences";
}

- (NSString *)_profileAppDataPathForBundleID:(NSString *)bundleID {
    NSString *profileId = [self _activeProfileId];
    if (!profileId.length || !bundleID.length) {
        return nil;
    }

    CommandRunner *runner = [CommandRunner shared];
    NSString *path = [runner firstExistingPath:@[
        [[[PXProfilesPath() stringByAppendingPathComponent:profileId] stringByAppendingPathComponent:@"appdata"] stringByAppendingPathComponent:bundleID],
        [NSString stringWithFormat:@"/private/var/mobile/Library/WeaponX/Profiles/%@/appdata/%@", profileId, bundleID]
    ]];
    return path;
}

- (void)_wipeDirectoryContents:(NSString *)dirPath {
    if (!dirPath.length) {
        return;
    }
    // Wipe everything inside the directory, but preserve container metadata files.
    // Deleting these can break MCM/LaunchServices container mapping (especially for App Groups).
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *listErr = nil;
    NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:dirPath error:&listErr];
    if (!items.count) {
        return;
    }
    NSSet<NSString *> *preserve = [NSSet setWithArray:@[
        @".com.apple.mobile_container_manager.metadata.plist",
        @".com.apple.containermanagerd.metadata.plist"
    ]];
    for (NSString *name in items) {
        if (![name isKindOfClass:[NSString class]] || !name.length) continue;
        if ([preserve containsObject:name]) {
            continue;
        }
        NSString *p = [dirPath stringByAppendingPathComponent:name];
        [fm removeItemAtPath:p error:nil];
    }
}

- (NSString *)_preferencesPlistPathForBundleID:(NSString *)bundleID {
    NSString *prefsDir = [self _preferencesDirectory];
    return [prefsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", bundleID]];
}

#pragma mark - Keychain Backup/Restore Helpers

- (NSString *)_keychainBackupScriptPath {
    CommandRunner *runner = [CommandRunner shared];
    return [runner firstExistingPath:@[
        @"/Library/WeaponX/keychain_backup.sh",
        @"/var/jb/Library/WeaponX/keychain_backup.sh",
        @"/private/var/jb/Library/WeaponX/keychain_backup.sh"
    ]];
}

static BOOL PXGroupsContainPlatformFamily(NSArray<NSString *> *groups) {
    for (NSString *g in groups) {
        if (![g isKindOfClass:[NSString class]]) continue;
        if ([g hasSuffix:@".platformFamily"] || [g containsString:@"platformFamily"]) {
            return YES;
        }
    }
    return NO;
}

static NSUInteger PXKeychainPlistItemCount(NSString *plistPath) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    if (![d isKindOfClass:[NSDictionary class]]) return 0;
    id items = d[@"items"];
    if ([items isKindOfClass:[NSArray class]]) {
        return [(NSArray *)items count];
    }
    return 0;
}

static BOOL PXOpenApplication(NSString *bundleID) {
    if (!bundleID.length) return NO;
    Class wsCls = NSClassFromString(@"LSApplicationWorkspace");
    if (!wsCls) return NO;
    id ws = [wsCls performSelector:@selector(defaultWorkspace)];
    if (!ws) return NO;
    if ([ws respondsToSelector:@selector(openApplicationWithBundleID:)]) {
        BOOL (*msgSend)(id, SEL, id) = (BOOL (*)(id, SEL, id))objc_msgSend;
        return msgSend(ws, @selector(openApplicationWithBundleID:), bundleID);
    }
    return NO;
}

static NSString *PXSafeBundleString(NSString *bundleID) {
    if (!bundleID.length) return @"unknown";
    NSCharacterSet *allowed = [NSCharacterSet alphanumericCharacterSet];
    NSMutableString *out = [NSMutableString stringWithCapacity:bundleID.length];
    for (NSUInteger i = 0; i < bundleID.length; i++) {
        unichar c = [bundleID characterAtIndex:i];
        if ([allowed characterIsMember:c]) {
            [out appendFormat:@"%C", c];
        } else {
            [out appendString:@"_"];
        }
    }
    return out;
}

static void PXDarwinNotifyPost(NSString *name) {
    if (!name.length) return;
    CFNotificationCenterRef c = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(c, (__bridge CFStringRef)name, NULL, NULL, true);
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
    dispatch_queue_t q = dispatch_queue_create("com.weaponx.keychainbridge.wait.backup", DISPATCH_QUEUE_SERIAL);
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

- (BOOL)_inAppKeychainBackupForBundleID:(NSString *)bundleID
                          containerPath:(NSString *)dataContainerPath
                                 groups:(NSArray<NSString *> *)groups
                                 toFile:(NSString *)destFile
                              debugPath:(NSString *)debugKeychain
                               warnings:(NSMutableArray<NSString *> *)warnings {
    if (!bundleID.length || !dataContainerPath.length || !destFile.length) return NO;
    if (!groups.count) return NO;

    NSString *safeBundle = PXSafeBundleString(bundleID);
    NSString *reqPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_request_%@.plist", safeBundle];
    NSString *respPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_response_%@.plist", safeBundle];
    NSString *outPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_export_%@.plist", safeBundle];
    NSString *logPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_bridge_%@.log", safeBundle];

    NSString *nonce = [[NSUUID UUID] UUIDString];

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:reqPath error:nil];
    [fm removeItemAtPath:respPath error:nil];
    [fm removeItemAtPath:outPath error:nil];

    NSDictionary *req = @{
        @"action": @"backup",
        @"bundleID": bundleID,
        @"groups": groups,
        @"nonce": nonce,
        @"outPath": outPath,
        @"respPath": respPath,
        @"logPath": logPath,
        @"bridgeOnly": @YES,
    };
    if (![req writeToFile:reqPath atomically:YES]) {
        [warnings addObject:@"In-app keychain backup: failed to write request" ];
        return NO;
    }

    PXDebugHeader(debugKeychain, @"In-App Keychain Backup");
    PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"request=%@", reqPath]);
    PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"tmpOut=%@", outPath]);
    PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"nonce=%@", nonce]);

    // Notify bridge (best-effort)
    PXDarwinNotifyPost([NSString stringWithFormat:@"com.hydra.weaponx.keychain.req.%@", safeBundle]);

    __block BOOL opened = NO;
    if ([NSThread isMainThread]) {
        opened = PXOpenApplication(bundleID);
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            opened = PXOpenApplication(bundleID);
        });
    }
    PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"openApplication=%@", opened ? @"YES" : @"NO"]);

    // Wait via Darwin notify (avoid polling). Use shorter timeout if open failed.
    NSTimeInterval waitSec = opened ? 30.0 : 6.0;
    NSDictionary *resp = PXWaitForKeychainBridgeResponse(safeBundle, respPath, nonce, waitSec);

    // Always capture bridge log + tmp dir state (best-effort)
    {
        NSString *bridgeLog = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil] ?: @"";
        if (bridgeLog.length) {
            PXDebugHeader(debugKeychain, @"In-App Bridge Log");
            PXDebugAppendLine(debugKeychain, bridgeLog);
        }
        PXDebugRun([CommandRunner shared], debugKeychain, @"ls /tmp (keychain bridge)",
                   @"ls -la /tmp 2>/dev/null || true");
    }

    if (![resp isKindOfClass:[NSDictionary class]]) {
        [warnings addObject:@"In-app keychain backup: no response (timeout?)" ];
        [self _killRelatedProcessesForBundleID:bundleID];
        return NO;
    }

    PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"resp=%@", resp]);

    BOOL ok = [resp[@"ok"] respondsToSelector:@selector(boolValue)] ? [resp[@"ok"] boolValue] : NO;
    if (!ok) {
        NSString *err = [resp[@"error"] isKindOfClass:[NSString class]] ? resp[@"error"] : @"";
        if (err.length) [warnings addObject:[NSString stringWithFormat:@"In-app keychain backup failed: %@", err]];
        [self _killRelatedProcessesForBundleID:bundleID];
        return NO;
    }

    if (![fm fileExistsAtPath:outPath]) {
        [warnings addObject:@"In-app keychain backup: export file missing" ];
        [self _killRelatedProcessesForBundleID:bundleID];
        return NO;
    }

    [fm removeItemAtPath:destFile error:nil];
    if (![fm copyItemAtPath:outPath toPath:destFile error:nil]) {
        [warnings addObject:@"In-app keychain backup: failed to copy export to destination" ];
        [self _killRelatedProcessesForBundleID:bundleID];
        return NO;
    }

    [self _killRelatedProcessesForBundleID:bundleID];
    [fm removeItemAtPath:reqPath error:nil];
    [fm removeItemAtPath:respPath error:nil];
    [fm removeItemAtPath:outPath error:nil];

    // Keep bridge log for debugging.

    return YES;
}

- (BOOL)_inAppKeychainRestoreForBundleID:(NSString *)bundleID
                           containerPath:(NSString *)dataContainerPath
                                  groups:(NSArray<NSString *> *)groups
                                fromFile:(NSString *)srcFile
                               overwrite:(BOOL)overwrite
                               debugPath:(NSString *)debugKeychain
                                warnings:(NSMutableArray<NSString *> *)warnings {
    if (!bundleID.length || !dataContainerPath.length || !srcFile.length) return NO;
    if (!groups.count) return NO;

    NSString *safeBundle = PXSafeBundleString(bundleID);
    NSString *reqPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_request_%@.plist", safeBundle];
    NSString *respPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_response_%@.plist", safeBundle];
    NSString *inPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_import_%@.plist", safeBundle];
    NSString *logPath = [NSString stringWithFormat:@"/tmp/weaponx_keychain_bridge_%@.log", safeBundle];

    NSString *nonce = [[NSUUID UUID] UUIDString];

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:reqPath error:nil];
    [fm removeItemAtPath:respPath error:nil];
    [fm removeItemAtPath:inPath error:nil];

    if (![fm copyItemAtPath:srcFile toPath:inPath error:nil]) {
        [warnings addObject:@"In-app keychain restore: failed to stage import file" ];
        return NO;
    }

    NSDictionary *req = @{
        @"action": @"restore",
        @"bundleID": bundleID,
        @"groups": groups,
        @"inPath": inPath,
        @"overwrite": @(overwrite),
        @"respPath": respPath,
        @"logPath": logPath,
        @"nonce": nonce,
        @"bridgeOnly": @YES,
    };
    if (![req writeToFile:reqPath atomically:YES]) {
        [warnings addObject:@"In-app keychain restore: failed to write request" ];
        return NO;
    }

    PXDebugHeader(debugKeychain, @"In-App Keychain Restore");
    PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"request=%@", reqPath]);
    PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"tmpIn=%@", inPath]);
    PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"nonce=%@", nonce]);

    PXDarwinNotifyPost([NSString stringWithFormat:@"com.hydra.weaponx.keychain.req.%@", safeBundle]);

    __block BOOL opened = NO;
    if ([NSThread isMainThread]) {
        opened = PXOpenApplication(bundleID);
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            opened = PXOpenApplication(bundleID);
        });
    }
    PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"openApplication=%@", opened ? @"YES" : @"NO"]);

    NSTimeInterval waitSec = opened ? 30.0 : 6.0;
    NSDictionary *resp = PXWaitForKeychainBridgeResponse(safeBundle, respPath, nonce, waitSec);

    // Always capture bridge log + tmp dir state (best-effort)
    {
        NSString *bridgeLog = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil] ?: @"";
        if (bridgeLog.length) {
            PXDebugHeader(debugKeychain, @"In-App Bridge Log");
            PXDebugAppendLine(debugKeychain, bridgeLog);
        }
        PXDebugRun([CommandRunner shared], debugKeychain, @"ls /tmp (keychain bridge)",
                   @"ls -la /tmp 2>/dev/null || true");
    }

    if (![resp isKindOfClass:[NSDictionary class]]) {
        [warnings addObject:@"In-app keychain restore: no response (timeout?)" ];
        [self _killRelatedProcessesForBundleID:bundleID];
        return NO;
    }

    PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"resp=%@", resp]);
    BOOL ok = [resp[@"ok"] respondsToSelector:@selector(boolValue)] ? [resp[@"ok"] boolValue] : NO;
    if (!ok) {
        NSString *err = [resp[@"error"] isKindOfClass:[NSString class]] ? resp[@"error"] : @"";
        if (err.length) [warnings addObject:[NSString stringWithFormat:@"In-app keychain restore failed: %@", err]];
        [self _killRelatedProcessesForBundleID:bundleID];
        return NO;
    }

    [self _killRelatedProcessesForBundleID:bundleID];
    [fm removeItemAtPath:reqPath error:nil];
    [fm removeItemAtPath:respPath error:nil];
    [fm removeItemAtPath:inPath error:nil];
    return YES;
}

- (BOOL)_backupKeychainForBundleID:(NSString *)bundleID
                            groups:(NSArray<NSString *> *)groups
                            toFile:(NSString *)backupFile
                          warnings:(NSMutableArray<NSString *> *)warnings {
    NSString *scriptPath = [self _keychainBackupScriptPath];
    if (!scriptPath) {
        [warnings addObject:@"Keychain backup script not found; skipping keychain backup"];
        return NO;
    }
    
    CommandRunner *runner = [CommandRunner shared];
    NSString *groupsArg = groups.count ? [NSString stringWithFormat:@" --groups %@", PXShellQuote([groups componentsJoinedByString:@","])] : @"";
    NSString *cmd = [NSString stringWithFormat:@"%@ backup %@ %@%@",
                     PXShellQuote(scriptPath),
                     PXShellQuote(bundleID),
                     PXShellQuote(backupFile),
                     groupsArg];
    
    CommandResult *res = [runner runAndCapture:cmd];
    if (res.exitCode != 0) {
        NSString *stderrMsg = res.stderrString.length ? res.stderrString : @"";
        NSString *stdoutMsg = res.stdoutString.length ? res.stdoutString : @"";
        NSMutableString *msg = [NSMutableString stringWithString:@"Keychain backup failed"]; 
        if (stderrMsg.length) {
            [msg appendFormat:@"\nstderr: %@", stderrMsg];
        }
        if (stdoutMsg.length) {
            [msg appendFormat:@"\nstdout: %@", stdoutMsg];
        }
        [warnings addObject:[NSString stringWithFormat:@"Keychain backup: %@", msg]];
        return NO;
    }
    
    return [[NSFileManager defaultManager] fileExistsAtPath:backupFile];
}

- (BOOL)_restoreKeychainForBundleID:(NSString *)bundleID
                             groups:(NSArray<NSString *> *)groups
                           fromFile:(NSString *)backupFile
                          overwrite:(BOOL)overwrite
                           warnings:(NSMutableArray<NSString *> *)warnings {
    NSString *scriptPath = [self _keychainBackupScriptPath];
    if (!scriptPath) {
        [warnings addObject:@"Keychain backup script not found; skipping keychain restore"];
        return NO;
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:backupFile]) {
        [warnings addObject:@"Keychain backup file not found; skipping keychain restore"];
        return NO;
    }
    
    CommandRunner *runner = [CommandRunner shared];
    NSString *overwriteArg = overwrite ? @"--overwrite" : @"";
    NSString *groupsArg = groups.count ? [NSString stringWithFormat:@" --groups %@", PXShellQuote([groups componentsJoinedByString:@","])] : @"";
    NSString *cmd = [NSString stringWithFormat:@"%@ restore %@ %@ %@%@",
                     PXShellQuote(scriptPath),
                     PXShellQuote(bundleID),
                     PXShellQuote(backupFile),
                     overwriteArg,
                     groupsArg];
    
    CommandResult *res = [runner runAndCapture:cmd];
    // Store last keychain restore output for debugging
    NSDictionary *report = @{
        @"bundleID": bundleID ?: @"",
        @"groups": groups ?: @[],
        @"cmd": cmd ?: @"",
        @"exitCode": @(res.exitCode),
        @"stdout": res.stdoutString ?: @"",
        @"stderr": res.stderrString ?: @"",
    };
    [[NSUserDefaults standardUserDefaults] setObject:report forKey:[NSString stringWithFormat:@"PXKeychainRestoreResult_%@", bundleID]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if (res.exitCode != 0) {
        NSString *stderrMsg = res.stderrString.length ? res.stderrString : @"";
        NSString *stdoutMsg = res.stdoutString.length ? res.stdoutString : @"";
        NSMutableString *msg = [NSMutableString stringWithString:@"Keychain restore failed"]; 
        if (stderrMsg.length) {
            [msg appendFormat:@"\nstderr: %@", stderrMsg];
        }
        if (stdoutMsg.length) {
            [msg appendFormat:@"\nstdout: %@", stdoutMsg];
        }
        [warnings addObject:[NSString stringWithFormat:@"Keychain restore: %@", msg]];
        return NO;
    }
    
    return YES;
}

- (NSString *)_backupRoot {
    NSString *profileId = [self _activeProfileId];
    if (profileId.length) {
        return [[PXProfilesPath() stringByAppendingPathComponent:profileId] stringByAppendingPathComponent:@"backups"];
    }
    // Fallback to legacy global backups directory
    return [PXWeaponXBasePath() stringByAppendingPathComponent:@"Backups"];
}

// Central profile ID helper (profile switch integration)
- (NSString *)_activeProfileId {
    // Read from the same central store used across the project.
    NSString *centralInfoPath = PXCurrentProfileInfoPath();
    NSDictionary *centralInfo = [NSDictionary dictionaryWithContentsOfFile:centralInfoPath];
    NSString *profileId = [centralInfo isKindOfClass:[NSDictionary class]] ? centralInfo[@"ProfileId"] : nil;
    if ([profileId isKindOfClass:[NSString class]] && profileId.length) {
        return profileId;
    }

    NSString *fallbackPath = PXLegacyActiveProfileInfoPath();
    NSDictionary *fallbackInfo = [NSDictionary dictionaryWithContentsOfFile:fallbackPath];
    profileId = [fallbackInfo isKindOfClass:[NSDictionary class]] ? fallbackInfo[@"ProfileId"] : nil;
    if (![profileId isKindOfClass:[NSString class]] || !profileId.length) {
        profileId = [fallbackInfo isKindOfClass:[NSDictionary class]] ? fallbackInfo[@"currentProfileId"] : nil;
    }
    if ([profileId isKindOfClass:[NSString class]] && profileId.length) {
        return profileId;
    }

    return nil;
}

- (NSString *)_timestampString {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    fmt.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"]; 
    fmt.dateFormat = @"yyyyMMdd-HHmmss";
    return [fmt stringFromDate:[NSDate date]];
}

- (NSArray<NSString *> *)listBackupDirectoriesForBundleID:(NSString *)bundleID {
    if (!bundleID.length) {
        return @[];
    }
    NSString *dir = [[self _backupRoot] stringByAppendingPathComponent:bundleID];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSMutableArray<NSString *> *dirs = [NSMutableArray array];

    BOOL isDir = NO;
    if ([fm fileExistsAtPath:dir isDirectory:&isDir] && isDir) {
        NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *item in items) {
            NSString *path = [dir stringByAppendingPathComponent:item];
            BOOL itemIsDir = NO;
            if ([fm fileExistsAtPath:path isDirectory:&itemIsDir] && itemIsDir) {
                NSString *manifest = [path stringByAppendingPathComponent:@"manifest.plist"];
                if ([fm fileExistsAtPath:manifest]) {
                    [dirs addObject:path];
                }
            }
        }
    }

    // Also include legacy global backups if present (so users can migrate smoothly)
    NSString *legacyDir = [[PXWeaponXBasePath() stringByAppendingPathComponent:@"Backups"] stringByAppendingPathComponent:bundleID];
    BOOL legacyIsDir = NO;
    if (![legacyDir isEqualToString:dir] && [fm fileExistsAtPath:legacyDir isDirectory:&legacyIsDir] && legacyIsDir) {
        NSArray<NSString *> *legacyItems = [fm contentsOfDirectoryAtPath:legacyDir error:nil];
        for (NSString *item in legacyItems) {
            NSString *path = [legacyDir stringByAppendingPathComponent:item];
            BOOL itemIsDir = NO;
            if ([fm fileExistsAtPath:path isDirectory:&itemIsDir] && itemIsDir) {
                NSString *manifest = [path stringByAppendingPathComponent:@"manifest.plist"];
                if ([fm fileExistsAtPath:manifest]) {
                    [dirs addObject:path];
                }
            }
        }
    }

    [dirs sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        // Sort newest-first based on the last path component (timestamp folder convention).
        return [b.lastPathComponent compare:a.lastPathComponent];
    }];
    return dirs;
}

- (NSDictionary *)readManifestAtBackupDirectory:(NSString *)backupDir
                                          error:(NSError **)error {
    if (error) {
        *error = nil;
    }

    NSString *manifest = [backupDir stringByAppendingPathComponent:@"manifest.plist"];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:manifest];
    if (![dict isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [NSError errorWithDomain:PXBackupErrorDomain
                                         code:200
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to read manifest"}];
        }
        return nil;
    }

    NSError *validationError = nil;
    if (![PXBackupManifestValidator validateManifestObject:dict error:&validationError]) {
        if (error) {
            *error = validationError;
        }
        return nil;
    }

    NSNumber *manifestVersion = dict[@"manifestVersion"];
    if (!PXBackupManifestVersionIsSupported(manifestVersion)) {
        if (error) {
            *error = [NSError errorWithDomain:PXBackupErrorDomain
                                         code:201
                                     userInfo:@{NSLocalizedDescriptionKey: @"Unsupported backup manifest version"}];
        }
        return nil;
    }

    return dict;
}

- (void)createBackupForBundleID:(NSString *)bundleID
                        appName:(NSString *)appName
                        options:(PXBackupOptions)options
                     completion:(void (^)(PXBackupResult *, NSError *))completion {
    if (!bundleID.length) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:PXBackupErrorDomain
                                                code:100
                                            userInfo:@{NSLocalizedDescriptionKey: @"Missing bundleID"}]);
        }
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray<NSString *> *warnings = [NSMutableArray array];
        NSFileManager *fm = [NSFileManager defaultManager];
        CommandRunner *runner = [CommandRunner shared];

        NSString *profileId = [self _activeProfileId];

        // Prefer jailbreak/Procursus tar first (often has xattrs/acl support); /usr/bin/tar on iOS may not.
        NSString *tarPath = [runner firstExistingPath:@[
            @"/var/jb/usr/bin/gtar",
            @"/private/preboot/jb/usr/bin/gtar",
            @"/usr/local/bin/gtar",
            @"/usr/bin/gtar",
            @"/var/jb/usr/bin/bsdtar",
            @"/private/preboot/jb/usr/bin/bsdtar",
            @"/usr/local/bin/bsdtar",
            @"/usr/bin/bsdtar",
            @"/var/jb/usr/bin/tar",
            @"/private/preboot/jb/usr/bin/tar",
            @"/usr/bin/tar",
            @"/bin/tar"
        ]];
        if (!tarPath) {
            NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                               code:101
                                           userInfo:@{NSLocalizedDescriptionKey: @"tar not found"}];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        // Prefer LaunchServices-reported container path (active container).
        NSString *dataContainerPath = nil;
        NSString *dataUUID = nil;
        {
            NSString *lsPath = PXDataContainerPathFromLaunchServices(bundleID);
            BOOL isDir = NO;
            if (lsPath.length && [fm fileExistsAtPath:lsPath isDirectory:&isDir] && isDir) {
                dataContainerPath = lsPath;
                dataUUID = lsPath.lastPathComponent;
            }
        }

        if (!dataContainerPath) {
            NSArray<NSString *> *bases = @[@"/var/mobile/Containers/Data/Application", @"/private/var/mobile/Containers/Data/Application", @"/containers/Data/Application", @"/private/var/containers/Data/Application"]; 
            for (NSString *base in bases) {
                NSString *found = PXFindDataContainerUUIDByMetadata(fm, base, bundleID);
                if (found.length) {
                    NSString *p = [base stringByAppendingPathComponent:found];
                    BOOL isDir = NO;
                    if ([fm fileExistsAtPath:p isDirectory:&isDir] && isDir) {
                        dataUUID = found;
                        dataContainerPath = p;
                        break;
                    }
                }
            }
            if (!dataContainerPath.length) {
                NSString *lsPath = PXDataContainerPathFromLaunchServices(bundleID) ?: @"";
                NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                   code:102
                                               userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Data container not found (bundleID=%@ lsPath=%@)", bundleID, lsPath]}];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                return;
            }
        }

        if (!dataContainerPath.length) {
            NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                               code:103
                                           userInfo:@{NSLocalizedDescriptionKey: @"Data container path missing"}];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        NSString *timestamp = [self _timestampString];
        NSString *backupDir = [[[self _backupRoot] stringByAppendingPathComponent:bundleID] stringByAppendingPathComponent:timestamp];
        NSString *debugBefore = [backupDir stringByAppendingPathComponent:@"debug_before_backup.txt"];
        NSString *debugAfter = [backupDir stringByAppendingPathComponent:@"debug_after_backup.txt"];
        NSString *debugKeychain = [backupDir stringByAppendingPathComponent:@"debug_keychain.txt"];
        NSString *groupsDir = [backupDir stringByAppendingPathComponent:@"groups"]; 
        NSString *prefsDir = [backupDir stringByAppendingPathComponent:@"preferences"]; 

        NSError *mkErr = nil;
        if (![fm createDirectoryAtPath:groupsDir withIntermediateDirectories:YES attributes:nil error:&mkErr]) {
            NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                               code:104
                                           userInfo:@{NSLocalizedDescriptionKey: mkErr.localizedDescription ?: @"Failed to create backup directory"}];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }
        [fm createDirectoryAtPath:prefsDir withIntermediateDirectories:YES attributes:nil error:nil];

        // Restrict permissions best-effort
        [runner run:[NSString stringWithFormat:@"chmod 700 %@ 2>/dev/null || true", PXShellQuote(backupDir)]];
        [runner run:[NSString stringWithFormat:@"chmod 700 %@ 2>/dev/null || true", PXShellQuote(groupsDir)]];
        [runner run:[NSString stringWithFormat:@"chmod 700 %@ 2>/dev/null || true", PXShellQuote(prefsDir)]];

        // Debug snapshot: before backup
        {
            PXDebugHeader(debugBefore, @"Backup Start");
            NSDictionary *rp = PXResolvePathsForBundleID(bundleID);
            PXDebugAppendLine(debugBefore, [NSString stringWithFormat:@"bundleID=%@", bundleID]);
            PXDebugAppendLine(debugBefore, [NSString stringWithFormat:@"profileId=%@", profileId ?: @""]);
            PXDebugAppendLine(debugBefore, [NSString stringWithFormat:@"timestamp=%@", timestamp]);
            PXDebugAppendLine(debugBefore, [NSString stringWithFormat:@"tarPath=%@", tarPath ?: @""]);
            PXDebugAppendLine(debugBefore, [NSString stringWithFormat:@"lsDataContainerPath=%@", rp[@"lsDataContainerPath"] ?: @""]);
            PXDebugAppendLine(debugBefore, [NSString stringWithFormat:@"lsContainerURLPath=%@", rp[@"lsContainerURLPath"] ?: @""]);
            PXDebugAppendLine(debugBefore, [NSString stringWithFormat:@"chosenDataContainerPath=%@", dataContainerPath ?: @""]);
            PXDebugAppendLine(debugBefore, [NSString stringWithFormat:@"chosenDataUUID=%@", dataUUID ?: @""]);
            PXDebugRun(runner, debugBefore, @"du data", [NSString stringWithFormat:@"du -sk %@ 2>/dev/null || true", PXShellQuote(dataContainerPath)]);
            PXDebugRun(runner, debugBefore, @"du library", [NSString stringWithFormat:@"du -sk %@ 2>/dev/null || true", PXShellQuote([dataContainerPath stringByAppendingPathComponent:@"Library"]) ]);
            PXDebugRun(runner, debugBefore, @"ls root", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote(dataContainerPath)]);
            PXDebugRun(runner, debugBefore, @"ls library", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote([dataContainerPath stringByAppendingPathComponent:@"Library"]) ]);
            PXDebugRun(runner, debugBefore, @"ls prefs", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote([dataContainerPath stringByAppendingPathComponent:@"Library/Preferences"]) ]);
            PXDebugRun(runner, debugBefore, @"ls cookies", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote([dataContainerPath stringByAppendingPathComponent:@"Library/Cookies"]) ]);
            PXDebugRun(runner, debugBefore, @"ls webkit", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote([dataContainerPath stringByAppendingPathComponent:@"Library/WebKit"]) ]);

            // Snapshot-only (system-wide) paths for debugging (restore does NOT touch these by default)
            PXDebugHeader(debugBefore, @"System Snapshot (Debug Only)");
            PXDebugRun(runner, debugBefore, @"ls Accounts3", @"ls -lh /var/mobile/Library/Accounts/Accounts3.sqlite 2>/dev/null || true");
            PXDebugRun(runner, debugBefore, @"ls Cookies", @"ls -la /var/mobile/Library/Cookies 2>/dev/null || true");
            PXDebugRun(runner, debugBefore, @"ls WebKit WebsiteData", @"ls -la /var/mobile/Library/WebKit/WebsiteData 2>/dev/null || true");
        }

        // Initialize keychain debug file (even if keychain option is off)
        {
            PXDebugHeader(debugKeychain, @"Keychain Debug");
            PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"bundleID=%@", bundleID]);
            PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"profileId=%@", profileId ?: @""]);
            PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"backupDir=%@", backupDir]);
        }

        // Ensure target app is not running while archiving.
        [self _killRelatedProcessesForBundleID:bundleID];

        NSString *dataArchivePath = [backupDir stringByAppendingPathComponent:@"data.tar.gz"];
        CommandResult *tarRes = [self _tarCreate:tarPath fromDir:dataContainerPath toArchive:dataArchivePath];
        if (tarRes.exitCode != 0 || ![fm fileExistsAtPath:dataArchivePath]) {
            NSString *msg = tarRes.stderrString.length ? tarRes.stderrString : @"tar failed for data container";
            NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                               code:105
                                           userInfo:@{NSLocalizedDescriptionKey: msg}];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        NSMutableArray<NSDictionary *> *groupManifests = [NSMutableArray array];
        NSArray<AppGroupContainerInfo *> *groupContainers = @[];
        NSArray<NSString *> *groupIDs = @[];

        if (options & PXBackupOptionIncludeAppGroups) {
            NSError *entErr = nil;
            AppEntitlementsReader *reader = [[AppEntitlementsReader alloc] init];
            groupIDs = [reader applicationGroupsForBundleID:bundleID error:&entErr];
            if (entErr) {
                [warnings addObject:[NSString stringWithFormat:@"Entitlements read failed: %@", entErr.localizedDescription]];
            }

            if (groupIDs.count) {
                AppGroupContainerResolver *resolver = [[AppGroupContainerResolver alloc] init];
                groupContainers = [resolver resolveGroupContainersForGroupIDs:groupIDs];
                if (!groupContainers.count) {
                    [warnings addObject:@"No App Group containers matched entitlements"];
                }
            }
        }

        // Debug snapshot: groups resolution
        {
            PXDebugHeader(debugBefore, @"App Groups Resolve");
            PXDebugAppendLine(debugBefore, [NSString stringWithFormat:@"groupIDs=%@", groupIDs ?: @[]]);
            NSMutableArray *paths = [NSMutableArray array];
            for (AppGroupContainerInfo *info in groupContainers) {
                [paths addObject:[NSString stringWithFormat:@"%@ => %@ (%@)", info.groupID ?: @"", info.path ?: @"", info.uuid ?: @""]];
                PXDebugRun(runner, debugBefore, [NSString stringWithFormat:@"du group %@", info.groupID ?: @""], [NSString stringWithFormat:@"du -sk %@ 2>/dev/null || true", PXShellQuote(info.path)]);
                PXDebugRun(runner, debugBefore, [NSString stringWithFormat:@"ls group %@", info.groupID ?: @""], [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote(info.path)]);
            }
            PXDebugAppendLine(debugBefore, [NSString stringWithFormat:@"groupPaths=%@", paths]);
        }

        for (AppGroupContainerInfo *info in groupContainers) {
            NSString *archiveName = [NSString stringWithFormat:@"%@.tar.gz", PXSanitizeFilenameComponent(info.groupID)];
            NSString *archivePath = [groupsDir stringByAppendingPathComponent:archiveName];

            CommandResult *r = [self _tarCreate:tarPath fromDir:info.path toArchive:archivePath];
            if (r.exitCode != 0 || ![fm fileExistsAtPath:archivePath]) {
                [warnings addObject:[NSString stringWithFormat:@"Failed to archive group %@ (%@)", info.groupID, info.uuid]];
                continue;
            }

            [groupManifests addObject:@{
                @"groupID": info.groupID,
                @"uuid": info.uuid,
                @"archive": [@"groups" stringByAppendingPathComponent:archiveName]
            }];
        }

        // Profile redirected appdata (system apps like Safari may store most data here)
        NSString *profileAppDataPath = [self _profileAppDataPathForBundleID:bundleID];
        NSString *profileAppDataArchivePath = nil;
        if (profileAppDataPath.length) {
            BOOL isDir = NO;
            if ([fm fileExistsAtPath:profileAppDataPath isDirectory:&isDir] && isDir) {
                profileAppDataArchivePath = [backupDir stringByAppendingPathComponent:@"profile_appdata.tar.gz"];
                CommandResult *r = [self _tarCreate:tarPath fromDir:profileAppDataPath toArchive:profileAppDataArchivePath];
                if (r.exitCode != 0 || ![fm fileExistsAtPath:profileAppDataArchivePath]) {
                    [warnings addObject:@"Failed to archive profile appdata; continuing" ];
                    profileAppDataArchivePath = nil;
                }
            }
        }

        // Global Library storage for Safari (history/bookmarks live under /var/mobile/Library/Safari)
        NSString *globalSafariPath = nil;
        NSString *globalSafariArchivePath = nil;
        if ([bundleID isEqualToString:@"com.apple.mobilesafari"]) {
            globalSafariPath = [self _globalSafariLibraryPath];
            if (globalSafariPath.length) {
                BOOL isDir = NO;
                if ([fm fileExistsAtPath:globalSafariPath isDirectory:&isDir] && isDir) {
                    globalSafariArchivePath = [backupDir stringByAppendingPathComponent:@"global_safari.tar.gz"];
                    CommandResult *r = [self _tarCreate:tarPath fromDir:globalSafariPath toArchive:globalSafariArchivePath];
                    if (r.exitCode != 0 || ![fm fileExistsAtPath:globalSafariArchivePath]) {
                        [warnings addObject:@"Failed to archive global Safari library; continuing"];
                        globalSafariArchivePath = nil;
                    }
                }
            }
        }

        BOOL prefsIncluded = (options & PXBackupOptionIncludePreferences) != 0;
        NSString *prefSourcePath = [self _preferencesPlistPathForBundleID:bundleID];
        NSString *prefDestPath = [prefsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", bundleID]];
        if (prefsIncluded) {
            if ([fm fileExistsAtPath:prefSourcePath]) {
                NSString *cpCmd = [NSString stringWithFormat:@"cp -f %@ %@ 2>/dev/null || true", PXShellQuote(prefSourcePath), PXShellQuote(prefDestPath)];
                [runner run:cpCmd];
                [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true", PXShellQuote(prefDestPath)]];
            } else {
                [warnings addObject:@"Global preferences plist not found (OK for most apps); skipping"];
            }
        }

        // Keychain backup
        BOOL keychainIncluded = (options & PXBackupOptionIncludeKeychain) != 0;
        NSString *keychainBackupPath = nil;
        NSString *keychainMethod = nil;
        NSArray<NSString *> *selectedKeychainGroups = @[];
        if (keychainIncluded) {
            keychainBackupPath = [backupDir stringByAppendingPathComponent:@"keychain.plist"];
            // Default selection: ALL groups from entitlements if no saved preference.
            id saved = [[NSUserDefaults standardUserDefaults] objectForKey:PXBackupKeychainGroupsKey(bundleID)];
            if ([saved isKindOfClass:[NSArray class]] && [(NSArray *)saved count] > 0) {
                NSMutableArray<NSString *> *tmp = [NSMutableArray array];
                for (id v in (NSArray *)saved) {
                    if ([v isKindOfClass:[NSString class]] && [(NSString *)v length] > 0) {
                        [tmp addObject:(NSString *)v];
                    }
                }
                selectedKeychainGroups = tmp;
            } else {
                NSError *entErr = nil;
                AppEntitlementsReader *reader = [[AppEntitlementsReader alloc] init];
                NSArray<NSString *> *entGroups = [reader keychainAccessGroupsForBundleID:bundleID error:&entErr];
                if (entGroups.count) {
                    selectedKeychainGroups = entGroups;
                    [[NSUserDefaults standardUserDefaults] setObject:entGroups forKey:PXBackupKeychainGroupsKey(bundleID)];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                } else if (entErr) {
                    [warnings addObject:[NSString stringWithFormat:@"Keychain groups read failed: %@", entErr.localizedDescription]];
                }
            }

            // Ensure default keychain group (application-identifier) is included even when the user has a saved subset.
            // Many apps store keychain items under this group even when it is not listed in keychain-access-groups.
            {
                NSError *entErr = nil;
                AppEntitlementsReader *reader = [[AppEntitlementsReader alloc] init];
                NSDictionary *ent = [reader fullEntitlementsForBundleID:bundleID error:&entErr];
                id appIdent = [ent isKindOfClass:[NSDictionary class]] ? ent[@"application-identifier"] : nil;
                if ([appIdent isKindOfClass:[NSString class]] && [(NSString *)appIdent length] > 0) {
                    NSMutableOrderedSet<NSString *> *set = [NSMutableOrderedSet orderedSetWithArray:selectedKeychainGroups ?: @[]];
                    [set addObject:(NSString *)appIdent];
                    selectedKeychainGroups = set.array;
                }
            }

            // Debug: list keychain items before backup
            {
                PXDebugHeader(debugKeychain, @"Keychain Before Backup");
                PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"selectedGroups=%@", selectedKeychainGroups ?: @[]]);
                NSString *scriptPath = [runner firstExistingPath:@[@"/Library/WeaponX/keychain_backup.sh",
                                                                  @"/var/jb/Library/WeaponX/keychain_backup.sh",
                                                                  @"/private/var/jb/Library/WeaponX/keychain_backup.sh"]];
                if (scriptPath.length && selectedKeychainGroups.count) {
                    NSString *csv = [selectedKeychainGroups componentsJoinedByString:@","];
                    PXDebugRun(runner, debugKeychain, @"list", [NSString stringWithFormat:@"%@ list %@ --groups %@", PXShellQuote(scriptPath), PXShellQuote(bundleID), PXShellQuote(csv)]);
                }
            }

            BOOL keychainSuccess = [self _backupKeychainForBundleID:bundleID
                                                            groups:selectedKeychainGroups
                                                            toFile:keychainBackupPath
                                                          warnings:warnings];
            if (!keychainSuccess) {
                keychainBackupPath = nil; // Mark as not included if failed
            } else {
                keychainMethod = @"helper";
                [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true", PXShellQuote(keychainBackupPath)]];
                PXDebugHeader(debugKeychain, @"Keychain Backup Result");
                PXDebugAppendLine(debugKeychain, @"status=ok");
                PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"archive=%@", keychainBackupPath]);
                PXDebugRun(runner, debugKeychain, @"ls keychain.plist", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote(keychainBackupPath)]);

                // If helper cannot access restricted groups (e.g. *.platformFamily), fallback to in-app export.
                NSUInteger count = PXKeychainPlistItemCount(keychainBackupPath);
                PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"plistItems=%lu", (unsigned long)count]);
                if (count == 0 && PXGroupsContainPlatformFamily(selectedKeychainGroups)) {
                    PXDebugAppendLine(debugKeychain, @"helper returned 0 items; trying in-app export");
                    BOOL inAppOK = [self _inAppKeychainBackupForBundleID:bundleID
                                                           containerPath:dataContainerPath
                                                                  groups:selectedKeychainGroups
                                                                  toFile:keychainBackupPath
                                                               debugPath:debugKeychain
                                                                warnings:warnings];
                    if (inAppOK) {
                        keychainMethod = @"in_app";
                        [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true", PXShellQuote(keychainBackupPath)]];
                        PXDebugRun(runner, debugKeychain, @"ls keychain.plist (after in-app)", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote(keychainBackupPath)]);
                        PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"plistItemsAfterInApp=%lu", (unsigned long)PXKeychainPlistItemCount(keychainBackupPath)]);
                    } else {
                        PXDebugAppendLine(debugKeychain, @"in-app export failed");
                    }
                }
            }
        }

        // Generic system app global data: many system apps store most data under /var/mobile/Library/<AppName>.
        NSArray<NSDictionary *> *systemGlobalItems = [self _systemGlobalLibraryItemsForBundleID:bundleID];
        NSMutableArray<NSDictionary *> *systemGlobalManifests = [NSMutableArray array];
        if (systemGlobalItems.count) {
            PXDebugHeader(debugBefore, @"System App Global Library");
        }
        for (NSDictionary *it in systemGlobalItems) {
            NSString *subdir = [it[@"subdir"] isKindOfClass:[NSString class]] ? it[@"subdir"] : nil;
            NSString *srcPath = [it[@"path"] isKindOfClass:[NSString class]] ? it[@"path"] : nil;
            if (!subdir.length || !srcPath.length) continue;

            // Avoid double-archiving Safari which is handled explicitly.
            if ([bundleID isEqualToString:@"com.apple.mobilesafari"] && [subdir isEqualToString:@"Safari"]) {
                continue;
            }

            NSString *archiveName = [NSString stringWithFormat:@"global_library_%@.tar.gz", PXSanitizeFilenameComponent(subdir)];
            NSString *archivePath = [backupDir stringByAppendingPathComponent:archiveName];

            [self _killRelatedProcessesForBundleID:bundleID];
            PXDebugAppendLine(debugBefore, [NSString stringWithFormat:@"item=%@ path=%@", subdir, srcPath]);
            CommandResult *r = [self _tarCreate:tarPath fromDir:srcPath toArchive:archivePath];
            if (r.exitCode != 0 || ![fm fileExistsAtPath:archivePath]) {
                [warnings addObject:[NSString stringWithFormat:@"Failed to archive system global library %@; continuing", subdir]];
                continue;
            }

            [systemGlobalManifests addObject:@{ @"subdir": subdir, @"archive": archiveName }];
        }

        // Shared system DBs: back up for system apps (can impact multiple apps).
        NSMutableArray<NSDictionary *> *sharedSystemDBFiles = [NSMutableArray array];
        if ([self _isSystemAppBundleID:bundleID]) {
            NSString *libBase = [self _mobileLibraryBasePath];
            NSString *sharedDir = [backupDir stringByAppendingPathComponent:@"shared_db"];
            [fm createDirectoryAtPath:sharedDir withIntermediateDirectories:YES attributes:nil error:nil];
            [runner run:[NSString stringWithFormat:@"chmod 700 %@ 2>/dev/null || true", PXShellQuote(sharedDir)]];

            PXDebugHeader(debugBefore, @"Shared System DBs");
            PXDebugAppendLine(debugBefore, [NSString stringWithFormat:@"libraryBase=%@", libBase ?: @""]);

            for (NSDictionary *spec in PXSharedSystemDBSpecs()) {
                for (NSDictionary *entry in PXExpandSQLiteSidecars(spec)) {
                    NSString *rel = [entry[@"libraryRel"] isKindOfClass:[NSString class]] ? entry[@"libraryRel"] : nil;
                    NSString *bn = [entry[@"backupName"] isKindOfClass:[NSString class]] ? entry[@"backupName"] : nil;
                    if (!rel.length || !bn.length) continue;

                    NSString *src = [libBase stringByAppendingPathComponent:rel];
                    if (![fm fileExistsAtPath:src]) {
                        continue;
                    }
                    NSString *dstRel = [@"shared_db" stringByAppendingPathComponent:bn];
                    NSString *dst = [backupDir stringByAppendingPathComponent:dstRel];

                    // Best-effort stop associated daemons first.
                    [self _killRelatedProcessesForBundleID:bundleID];
                    PXKillallByName(@"accountsd", SIGTERM);
                    PXKillallByName(@"calaccessd", SIGTERM);
                    PXKillallByName(@"imagent", SIGTERM);
                    PXKillallByName(@"MobileSMS", SIGTERM);
                    [NSThread sleepForTimeInterval:0.15];

                    PXDebugAppendLine(debugBefore, [NSString stringWithFormat:@"copy %@ -> %@", src, dstRel]);
                    [runner run:[NSString stringWithFormat:@"cp -a %@ %@ 2>/dev/null || true", PXShellQuote(src), PXShellQuote(dst)]];
                    [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true", PXShellQuote(dst)]];
                    if ([fm fileExistsAtPath:dst]) {
                        [sharedSystemDBFiles addObject:@{ @"libraryRel": rel, @"archive": dstRel }];
                    }
                }
            }

            if (!sharedSystemDBFiles.count) {
                [warnings addObject:@"System app: no shared system DBs were found to back up"];
            } else {
                [warnings addObject:@"System app: included shared system DBs (this may affect multiple apps)"];
            }
        }

        UIDevice *device = [UIDevice currentDevice];
        NSString *iosVersion = device.systemVersion ?: @"";
        // profileId already computed above

        NSMutableArray *artifacts = [NSMutableArray array];
        NSDictionary *dataArtifact = PXArtifactInfo(dataArchivePath, @"data.tar.gz");
        if (dataArtifact) [artifacts addObject:dataArtifact];
        for (NSDictionary *g in groupManifests) {
            NSString *rel = g[@"archive"]; // groups/<name>.tar.gz
            if ([rel isKindOfClass:[NSString class]]) {
                NSString *abs = [backupDir stringByAppendingPathComponent:(NSString *)rel];
                NSDictionary *gi = PXArtifactInfo(abs, rel);
                if (gi) [artifacts addObject:gi];
            }
        }
        if (profileAppDataArchivePath) {
            NSDictionary *a = PXArtifactInfo(profileAppDataArchivePath, @"profile_appdata.tar.gz");
            if (a) [artifacts addObject:a];
        }
        if (globalSafariArchivePath) {
            NSDictionary *a = PXArtifactInfo(globalSafariArchivePath, @"global_safari.tar.gz");
            if (a) [artifacts addObject:a];
        }
        for (NSDictionary *g in systemGlobalManifests) {
            NSString *rel = g[@"archive"]; // global_library_*.tar.gz
            if ([rel isKindOfClass:[NSString class]] && rel.length) {
                NSString *abs = [backupDir stringByAppendingPathComponent:(NSString *)rel];
                NSDictionary *gi = PXArtifactInfo(abs, rel);
                if (gi) [artifacts addObject:gi];
            }
        }
        for (NSDictionary *d in sharedSystemDBFiles) {
            NSString *rel = [d[@"archive"] isKindOfClass:[NSString class]] ? d[@"archive"] : nil;
            if (!rel.length) continue;
            NSString *abs = [backupDir stringByAppendingPathComponent:rel];
            NSDictionary *di = PXArtifactInfo(abs, rel);
            if (di) [artifacts addObject:di];
        }
        if (prefDestPath && [[NSFileManager defaultManager] fileExistsAtPath:prefDestPath]) {
            NSDictionary *a = PXArtifactInfo(prefDestPath, [NSString stringWithFormat:@"preferences/%@.plist", bundleID]);
            if (a) [artifacts addObject:a];
        }
        if (keychainBackupPath && [[NSFileManager defaultManager] fileExistsAtPath:keychainBackupPath]) {
            NSDictionary *a = PXArtifactInfo(keychainBackupPath, @"keychain.plist");
            if (a) [artifacts addObject:a];
        }

        for (NSDictionary *artifact in artifacts) {
            NSString *verifyWarning = PXVerifyArtifact(backupDir, artifact);
            if (verifyWarning.length) {
                [warnings addObject:[@"Backup artifact verification: " stringByAppendingString:verifyWarning]];
            }
        }

        NSString *toolVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
        NSString *toolBuild = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey] ?: @"";
        NSMutableArray<NSString *> *restoreNotes = [NSMutableArray array];
        if (keychainBackupPath) {
            [restoreNotes addObject:@"Keychain restore intentionally omits system-managed attributes such as access-control, dates and persistent refs when required by Security.framework."];
        }
        if (systemGlobalManifests.count || sharedSystemDBFiles.count) {
            [restoreNotes addObject:@"This backup includes system/global data that may affect more than one app."];
        }

        unsigned long long totalArtifactSize = PXArtifactsTotalSize(artifacts);

        NSDictionary *manifest = @{
            @"manifestVersion": @3,
            @"bundleID": bundleID,
            @"appName": appName ?: @"",
            @"createdAt": [NSDate date],
            @"timestamp": timestamp,
            @"iosVersion": iosVersion,
            @"toolVersion": toolVersion,
            @"toolBuild": toolBuild,
            @"profileId": profileId,
            @"backupMode": @"strict",
            @"sourceDataContainerPath": dataContainerPath ?: @"",
            @"sourceDataContainerUUID": dataUUID ?: @"",
            @"includedOptions": PXIncludedOptionNames(options),
            @"excludedOptions": PXExcludedOptionNames(options),
            @"artifactCount": @(artifacts.count),
            @"totalSize": @(totalArtifactSize),
            @"archiveChecksum": dataArtifact[@"sha256"] ?: @"",
            @"warnings": [warnings copy],
            @"restoreCompatibility": @{
                @"targetBundleID": bundleID ?: @"",
                @"requiresSameBundleID": @YES,
                @"requiresInstalledAppContainer": @YES,
                @"notes": restoreNotes
            },
            @"data": @{
                @"uuid": dataUUID,
                @"archive": @"data.tar.gz",
                @"containerPath": dataContainerPath
            },
            @"applicationGroups": groupIDs ?: @[],
            @"appGroups": groupManifests,
            @"preferences": @{
                @"included": @(prefsIncluded),
                @"archive": [NSString stringWithFormat:@"preferences/%@.plist", bundleID]
            },
            @"keychain": @{
                @"included": @(keychainBackupPath != nil),
                @"archive": keychainBackupPath ? @"keychain.plist" : @"",
                @"groupsSelected": selectedKeychainGroups ?: @[],
                @"method": keychainMethod ?: @""
            },
            @"profileAppData": @{
                @"included": @(profileAppDataArchivePath != nil),
                @"archive": profileAppDataArchivePath ? @"profile_appdata.tar.gz" : @"",
                @"path": profileAppDataPath ?: @""
            },
            @"globalSafari": @{
                @"included": @(globalSafariArchivePath != nil),
                @"archive": globalSafariArchivePath ? @"global_safari.tar.gz" : @"",
                @"path": globalSafariPath ?: @""
            },
            @"systemGlobalLibrary": @{
                @"included": @(systemGlobalManifests.count > 0),
                @"items": systemGlobalManifests
            },
            @"sharedSystemDB": @{
                @"included": @(sharedSystemDBFiles.count > 0),
                @"files": sharedSystemDBFiles
            },
            @"artifacts": artifacts,
            @"options": @{
                @"includeAppGroups": @((options & PXBackupOptionIncludeAppGroups) != 0),
                @"includePreferences": @(prefsIncluded),
                @"includeKeychain": @(keychainIncluded)
            }
        };

        // Debug snapshot: after backup artifacts
        {
            PXDebugHeader(debugAfter, @"Backup Artifacts");
            PXDebugAppendLine(debugAfter, [NSString stringWithFormat:@"backupDir=%@", backupDir]);
            PXDebugRun(runner, debugAfter, @"ls backupDir", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote(backupDir)]);
            PXDebugRun(runner, debugAfter, @"ls groupsDir", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote(groupsDir)]);
            PXDebugRun(runner, debugAfter, @"ls prefsDir", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote(prefsDir)]);
            PXDebugRun(runner, debugAfter, @"ls data.tar.gz", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote(dataArchivePath)]);
            if (keychainBackupPath) {
                PXDebugRun(runner, debugAfter, @"ls keychain.plist", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote(keychainBackupPath)]);
            }
            PXDebugRun(runner, debugAfter, @"cat manifest.plist", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote([backupDir stringByAppendingPathComponent:@"manifest.plist"]) ]);
        }

        NSString *manifestPath = [backupDir stringByAppendingPathComponent:@"manifest.plist"];
        if (![manifest writeToFile:manifestPath atomically:YES]) {
            [warnings addObject:@"Failed to write manifest"];
        } else {
            [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true", PXShellQuote(manifestPath)]];
        }

        PXBackupResult *out = [[PXBackupResult alloc] init];
        out.backupDirectory = backupDir;
        out.manifestPath = manifestPath;
        out.warnings = warnings;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(out, nil);
            }
        });
    });
}

- (BOOL)_stageOptionalDirectoryArchiveName:(NSString *)archiveName
                                sourcePath:(NSString *)sourcePath
                               restorePlan:(PXRestorePlan *)restorePlan
                                   tarPath:(NSString *)tarPath
                               failureCode:(NSInteger)failureCode
                        failureDescription:(NSString *)failureDescription
                              workspaceOut:(PXMainDataStagingWorkspace **)workspaceOut
                                  stageOut:(PXValidatedMainDataStage **)stageOut
                                     error:(NSError **)error {
    if (workspaceOut) {
        *workspaceOut = nil;
    }
    if (stageOut) {
        *stageOut = nil;
    }
    if (error) {
        *error = nil;
    }

    NSNumber *memberCountSummary =
        restorePlan.validatedArchives.memberCountsByArchiveName[archiveName];
    NSNumber *regularByteSummary =
        restorePlan.validatedArchives.regularFileBytesByArchiveName[archiveName];
    unsigned long long memberCountValue = 0;
    unsigned long long regularByteValue = 0;
    if (![archiveName isKindOfClass:[NSString class]] || archiveName.length == 0 ||
        ![sourcePath isKindOfClass:[NSString class]] || sourcePath.length == 0 ||
        !PXReadUnsignedIntegralSummaryNumber(memberCountSummary, &memberCountValue) ||
        !PXReadUnsignedIntegralSummaryNumber(regularByteSummary, &regularByteValue) ||
        memberCountValue > NSUIntegerMax) {
        if (error) {
            *error = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                         code:PXOptionalRestoreStagingErrorInconsistentPlan
                                     userInfo:@{
                                         NSLocalizedDescriptionKey: @"The accepted optional archive summary is inconsistent.",
                                         PXOptionalRestoreStagingErrorFieldPathKey: @"$"
                                     }];
        }
        return NO;
    }

    NSError *workspaceError = nil;
    PXMainDataStagingWorkspace *workspace =
        [PXMainDataStagingWorkspace createWorkspaceWithError:&workspaceError];
    if (!workspace) {
        if (error) {
            *error = workspaceError ?: [NSError errorWithDomain:PXMainDataStagingErrorDomain
                                                            code:PXMainDataStagingErrorWorkspaceCreationFailed
                                                        userInfo:@{
                                                            NSLocalizedDescriptionKey: @"The optional directory staging workspace could not be created.",
                                                            PXMainDataStagingErrorFieldPathKey: @"$.workspace"
                                                        }];
        }
        return NO;
    }

    NSError *emptyError = nil;
    if (![workspace validateEmptyDataDirectoryWithError:&emptyError]) {
        [workspace cleanupWithError:nil];
        if (error) {
            *error = emptyError ?: [NSError errorWithDomain:PXMainDataStagingErrorDomain
                                                        code:PXMainDataStagingErrorInvalidInput
                                                    userInfo:@{
                                                        NSLocalizedDescriptionKey: @"The optional directory staging workspace failed empty validation.",
                                                        PXMainDataStagingErrorFieldPathKey: @"$.data"
                                                    }];
        }
        return NO;
    }

    CommandResult *extractResult =
        [self _tarExtract:tarPath archive:sourcePath toDir:workspace.dataPath];
    if (extractResult.exitCode != 0) {
        [workspace cleanupWithError:nil];
        if (error) {
            *error = [NSError errorWithDomain:PXBackupErrorDomain
                                         code:failureCode
                                     userInfo:@{NSLocalizedDescriptionKey: failureDescription}];
        }
        return NO;
    }

    NSError *validationError = nil;
    PXValidatedMainDataStage *stage =
        [workspace validatedStageWithExpectedLogicalMemberCount:(NSUInteger)memberCountValue
                                        expectedRegularFileBytes:regularByteValue
                                                            error:&validationError];
    if (!stage) {
        [workspace cleanupWithError:nil];
        if (error) {
            *error = validationError ?: [NSError errorWithDomain:PXMainDataStagingErrorDomain
                                                             code:PXMainDataStagingErrorInvalidInput
                                                         userInfo:@{
                                                             NSLocalizedDescriptionKey: @"The optional directory stage failed validation.",
                                                             PXMainDataStagingErrorFieldPathKey: @"$.data"
                                                         }];
        }
        return NO;
    }

    if (workspaceOut) {
        *workspaceOut = workspace;
    }
    if (stageOut) {
        *stageOut = stage;
    }
    return YES;
}

- (BOOL)_cloneOptionalDirectoryStageAtPath:(NSString *)stagePath
                              destination:(NSString *)destination
                                   tarPath:(NSString *)tarPath
                                    runner:(CommandRunner *)runner
                                 debugPath:(NSString *)debugPath
                                debugLabel:(NSString *)debugLabel {
    BOOL shouldUseCopy =
        [tarPath isEqualToString:@"/usr/bin/tar"] ||
        [tarPath isEqualToString:@"/bin/tar"];
    CommandResult *tarCloneResult = nil;
    if (!shouldUseCopy) {
        NSString *cloneCommand =
            [NSString stringWithFormat:@"%@ --xattrs --acls -cf - -C %@ . | %@ --xattrs --acls -xf - -C %@",
             PXShellQuote(tarPath),
             PXShellQuote(stagePath),
             PXShellQuote(tarPath),
             PXShellQuote(destination)];
        tarCloneResult = [runner runAndCapture:cloneCommand];
        PXDebugAppendLine(debugPath,
                          [NSString stringWithFormat:@"%@TarPipeExit=%d",
                           debugLabel,
                           (int)tarCloneResult.exitCode]);
        if (tarCloneResult.stderrString.length) {
            PXDebugAppendLine(debugPath,
                              [NSString stringWithFormat:@"%@TarPipeStderrPresent=1",
                               debugLabel]);
        }
        if (tarCloneResult.exitCode != 0 ||
            (tarCloneResult.stderrString.length &&
             [tarCloneResult.stderrString containsString:@"XATTR support is not available"])) {
            shouldUseCopy = YES;
        }
    } else {
        PXDebugAppendLine(debugPath,
                          [NSString stringWithFormat:@"%@TarPipeSkipped=1", debugLabel]);
    }

    if (!shouldUseCopy) {
        return YES;
    }
    NSString *copyCommand =
        [NSString stringWithFormat:@"cp -a %@/. %@/ 2>/dev/null",
         PXShellQuote(stagePath),
         PXShellQuote(destination)];
    CommandResult *copyResult = [runner runAndCapture:copyCommand];
    PXDebugAppendLine(debugPath,
                      [NSString stringWithFormat:@"%@CpExit=%d",
                       debugLabel,
                       (int)copyResult.exitCode]);
    if (copyResult.stderrString.length) {
        PXDebugAppendLine(debugPath,
                          [NSString stringWithFormat:@"%@CpStderrPresent=1", debugLabel]);
    }
    return copyResult.exitCode == 0;
}

- (void)restoreBackupAtDirectory:(NSString *)backupDir
                        bundleID:(NSString *)bundleID
                         appName:(NSString *)appName
                     completion:(void (^)(PXRestoreResult *, NSError *))completion {
    if (!backupDir.length || !bundleID.length) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:PXBackupErrorDomain
                                                code:300
                                            userInfo:@{NSLocalizedDescriptionKey: @"Missing parameters"}]);
        }
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *manifestError = nil;
        NSDictionary *manifest =
            [self readManifestAtBackupDirectory:backupDir
                                              error:&manifestError];
        if (!manifest) {
            NSError *err = manifestError ?: [NSError errorWithDomain:PXBackupErrorDomain
                                                                  code:302
                                                              userInfo:@{NSLocalizedDescriptionKey: @"Manifest missing or invalid"}];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        NSString *manifestBundleID = manifest[@"bundleID"];
        if (![manifestBundleID isEqualToString:bundleID]) {
            NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                               code:304
                                           userInfo:@{NSLocalizedDescriptionKey: @"Backup manifest bundle identifier does not match restore target"}];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        PXResolvedContainer *dataContainerModel = nil;
        NSString *dataContainerPath = nil;
        NSError *destinationError = nil;
        if (!PXResolveExactRestoreApplicationDataTarget(bundleID,
                                                        &dataContainerModel,
                                                        &dataContainerPath,
                                                        &destinationError)) {
            NSError *err = destinationError ?: [NSError errorWithDomain:PXBackupErrorDomain
                                                                    code:303
                                                                userInfo:@{NSLocalizedDescriptionKey: PXExactRestoreDestinationErrorDescription}];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }
        NSError *artifactError = nil;
        PXVerifiedBackupArtifactSet *verifiedArtifacts =
            [PXBackupArtifactVerifier verifiedArtifactsForManifest:manifest
                                                    backupDirectory:backupDir
                                                              error:&artifactError];
        if (!verifiedArtifacts) {
            NSError *err = artifactError ?: [NSError errorWithDomain:PXBackupArtifactVerifierErrorDomain
                                                                 code:PXBackupArtifactVerifierErrorInvalidInput
                                                             userInfo:@{
                                                                 NSLocalizedDescriptionKey: @"Backup artifact verification failed",
                                                                 PXBackupArtifactVerifierErrorFieldPathKey: @"$"
                                                             }];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        NSError *archiveError = nil;
        __attribute__((objc_precise_lifetime))
        PXValidatedBackupArchiveSet *validatedArchives =
            [PXBackupArchiveValidator validatedArchivesForManifest:manifest
                                                   backupDirectory:backupDir
                                                 verifiedArtifacts:verifiedArtifacts
                                                             error:&archiveError];
        if (!validatedArchives) {
            NSError *err = archiveError ?: [NSError errorWithDomain:PXBackupArchiveValidatorErrorDomain
                                                                code:PXBackupArchiveValidatorErrorInvalidInput
                                                            userInfo:@{
                                                                NSLocalizedDescriptionKey: @"Backup archive validation failed",
                                                                PXBackupArchiveValidatorErrorFieldPathKey: @"$"
                                                            }];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        NSError *planError = nil;
        __attribute__((objc_precise_lifetime))
        PXRestorePlan *restorePlan =
            [PXRestorePlan planForManifest:manifest
                 requestedBundleIdentifier:bundleID
                   applicationDataContainer:dataContainerModel
                        applicationDataPath:dataContainerPath
                          verifiedArtifacts:verifiedArtifacts
                          validatedArchives:validatedArchives
                                      error:&planError];
        if (!restorePlan) {
            NSError *err = planError ?: [NSError errorWithDomain:PXRestorePlanErrorDomain
                                                              code:PXRestorePlanErrorInvalidInput
                                                          userInfo:@{
                                                              NSLocalizedDescriptionKey: @"Restore plan construction failed",
                                                              PXRestorePlanErrorFieldPathKey: @"$"
                                                          }];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        dataContainerModel = restorePlan.applicationDataContainer;
        dataContainerPath = restorePlan.applicationDataPath;
        NSString *dataUUID = restorePlan.applicationDataUUID;

        NSMutableArray<NSString *> *warnings = [NSMutableArray array];
        NSFileManager *fm = [NSFileManager defaultManager];
        CommandRunner *runner = [CommandRunner shared];

        NSString *debugPre = [backupDir stringByAppendingPathComponent:@"debug_before_restore.txt"];
        NSString *debugPost = [backupDir stringByAppendingPathComponent:@"debug_after_restore.txt"];
        NSString *debugKeychain = [backupDir stringByAppendingPathComponent:@"debug_keychain.txt"];

        // Debug snapshot: restore start
        {
            PXDebugHeader(debugPre, @"Restore Start");
            PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"bundleID=%@", bundleID]);
            PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"appName=%@", appName ?: @""]);
            PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"backupDir=%@", backupDir]);
            NSDictionary *rp = PXResolvePathsForBundleID(bundleID);
            PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"lsDataContainerPath=%@", rp[@"lsDataContainerPath"] ?: @""]);
            PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"lsContainerURLPath=%@", rp[@"lsContainerURLPath"] ?: @""]);
            PXDebugRun(runner, debugPre, @"ls backupDir", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote(backupDir)]);

            PXDebugHeader(debugPre, @"System Snapshot (Debug Only)");
            PXDebugRun(runner, debugPre, @"ls Accounts3", @"ls -lh /var/mobile/Library/Accounts/Accounts3.sqlite 2>/dev/null || true");
            PXDebugRun(runner, debugPre, @"ls Cookies", @"ls -la /var/mobile/Library/Cookies 2>/dev/null || true");
            PXDebugRun(runner, debugPre, @"ls WebKit WebsiteData", @"ls -la /var/mobile/Library/WebKit/WebsiteData 2>/dev/null || true");

            PXDebugHeader(debugKeychain, @"Keychain Debug");
            PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"bundleID=%@", bundleID]);
            PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"backupDir=%@", backupDir]);
        }

        // Prefer jailbreak/Procursus tar first (often has xattrs/acl support); /usr/bin/tar on iOS may not.
        NSString *tarPath = [runner firstExistingPath:@[
            @"/var/jb/usr/bin/gtar",
            @"/private/preboot/jb/usr/bin/gtar",
            @"/usr/local/bin/gtar",
            @"/usr/bin/gtar",
            @"/var/jb/usr/bin/bsdtar",
            @"/private/preboot/jb/usr/bin/bsdtar",
            @"/usr/local/bin/bsdtar",
            @"/usr/bin/bsdtar",
            @"/var/jb/usr/bin/tar",
            @"/private/preboot/jb/usr/bin/tar",
            @"/usr/bin/tar",
            @"/bin/tar"
        ]];
        if (!tarPath) {
            NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                               code:301
                                           userInfo:@{NSLocalizedDescriptionKey: @"tar not found"}];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"tarPath=%@", tarPath]);

        NSArray<NSString *> *entitledGroupIdentifiers = @[];
        if (restorePlan.includesAppGroups && restorePlan.appGroupItems.count > 0) {
            NSError *entitlementReadError = nil;
            AppEntitlementsReader *entitlementReader = [[AppEntitlementsReader alloc] init];
            id entitlementResult =
                [entitlementReader applicationGroupsForBundleID:bundleID
                                                           error:&entitlementReadError];
            if (entitlementReadError || ![entitlementResult isKindOfClass:[NSArray class]]) {
                NSError *err = [NSError errorWithDomain:PXAppGroupRestoreTargetPlanErrorDomain
                                                   code:PXAppGroupRestoreTargetPlanErrorInvalidEntitlementSet
                                               userInfo:@{
                                                   NSLocalizedDescriptionKey: @"The signed App Group entitlement set could not be read safely.",
                                                   PXAppGroupRestoreTargetPlanErrorFieldPathKey: @"$.entitlements"
                                               }];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                return;
            }
            entitledGroupIdentifiers = [(NSArray *)entitlementResult copy];
        }

        NSError *appGroupTargetPlanError = nil;
        __attribute__((objc_precise_lifetime))
        PXAppGroupRestoreTargetPlan *appGroupTargetPlan =
            [PXAppGroupRestoreTargetPlan targetPlanForRestorePlan:restorePlan
                                         entitledGroupIdentifiers:entitledGroupIdentifiers
                                                            error:&appGroupTargetPlanError];
        if (!appGroupTargetPlan) {
            NSError *err = appGroupTargetPlanError ?:
                [NSError errorWithDomain:PXAppGroupRestoreTargetPlanErrorDomain
                                    code:PXAppGroupRestoreTargetPlanErrorInvalidInput
                                userInfo:@{
                                    NSLocalizedDescriptionKey: @"The App Group restore target plan could not be constructed.",
                                    PXAppGroupRestoreTargetPlanErrorFieldPathKey: @"$"
                                }];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        NSString *activeProfileId = [self _activeProfileId];
        NSError *optionalDestinationPlanError = nil;
        __attribute__((objc_precise_lifetime))
        PXOptionalRestoreDestinationPlan *optionalDestinationPlan =
            [PXOptionalRestoreDestinationPlan destinationPlanForRestorePlan:restorePlan
                                                            bundleIdentifier:bundleID
                                                     activeProfileIdentifier:activeProfileId
                                                                       error:&optionalDestinationPlanError];
        if (!optionalDestinationPlan) {
            NSError *err = optionalDestinationPlanError ?:
                [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                    code:PXOptionalRestoreStagingErrorInvalidInput
                                userInfo:@{
                                    NSLocalizedDescriptionKey: @"The optional Restore destination plan could not be constructed.",
                                    PXOptionalRestoreStagingErrorFieldPathKey: @"$"
                                }];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        if (restorePlan.manifestWarningCount > 0) {
            [warnings addObject:[NSString stringWithFormat:@"Backup manifest contains %lu warning(s); review manifest before relying on full fidelity restore", (unsigned long)restorePlan.manifestWarningCount]];
        }

        NSString *manifestProfileId = restorePlan.manifestProfileIdentifier;
        if (manifestProfileId.length && activeProfileId.length && ![manifestProfileId isEqualToString:activeProfileId]) {
            [warnings addObject:[NSString stringWithFormat:@"Backup profileId %@ != active profileId %@", manifestProfileId, activeProfileId]];
        }

        PXDebugHeader(debugPre, @"Chosen Container");
        PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"chosenDataContainerPath=%@", dataContainerPath ?: @""]);
        PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"chosenDataUUID=%@", dataUUID ?: @""]);
        PXDebugRun(runner, debugPre, @"du data", [NSString stringWithFormat:@"du -sk %@ 2>/dev/null || true", PXShellQuote(dataContainerPath)]);
        PXDebugRun(runner, debugPre, @"ls prefs", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote([dataContainerPath stringByAppendingPathComponent:@"Library/Preferences"]) ]);

        NSString *dataArchiveName = restorePlan.dataArchiveName;
        NSString *dataArchive = restorePlan.dataArchivePath;
        NSNumber *logicalMemberSummary =
            restorePlan.validatedArchives.memberCountsByArchiveName[dataArchiveName];
        NSNumber *regularFileByteSummary =
            restorePlan.validatedArchives.regularFileBytesByArchiveName[dataArchiveName];
        unsigned long long logicalMemberValue = 0;
        unsigned long long expectedRegularFileBytes = 0;
        if (!PXReadUnsignedIntegralSummaryNumber(logicalMemberSummary, &logicalMemberValue) ||
            !PXReadUnsignedIntegralSummaryNumber(regularFileByteSummary, &expectedRegularFileBytes) ||
            logicalMemberValue > NSUIntegerMax) {
            NSError *err = [NSError errorWithDomain:PXMainDataStagingErrorDomain
                                               code:PXMainDataStagingErrorInvalidInput
                                           userInfo:@{
                                               NSLocalizedDescriptionKey: @"The accepted main archive summary is invalid.",
                                               PXMainDataStagingErrorFieldPathKey: @"$.data"
                                           }];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }
        NSUInteger expectedLogicalMemberCount = (NSUInteger)logicalMemberValue;

        NSError *workspaceError = nil;
        __attribute__((objc_precise_lifetime))
        PXMainDataStagingWorkspace *mainDataWorkspace =
            [PXMainDataStagingWorkspace createWorkspaceWithError:&workspaceError];
        if (!mainDataWorkspace) {
            NSError *err = workspaceError ?: [NSError errorWithDomain:PXMainDataStagingErrorDomain
                                                                  code:PXMainDataStagingErrorWorkspaceCreationFailed
                                                              userInfo:@{
                                                                  NSLocalizedDescriptionKey: @"The private main-data staging workspace could not be created.",
                                                                  PXMainDataStagingErrorFieldPathKey: @"$.workspace"
                                                              }];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        NSError *emptyStageError = nil;
        if (![mainDataWorkspace validateEmptyDataDirectoryWithError:&emptyStageError]) {
            [mainDataWorkspace cleanupWithError:nil];
            NSError *err = emptyStageError ?: [NSError errorWithDomain:PXMainDataStagingErrorDomain
                                                                    code:PXMainDataStagingErrorInvalidInput
                                                                userInfo:@{
                                                                    NSLocalizedDescriptionKey: @"The private main-data staging workspace failed empty validation.",
                                                                    PXMainDataStagingErrorFieldPathKey: @"$.data"
                                                                }];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        CommandResult *stx = [self _tarExtractDataArchive:tarPath
                                                   archive:dataArchive
                                                     toDir:mainDataWorkspace.dataPath
                                                  warnings:warnings];
        if (stx.exitCode != 0) {
            [mainDataWorkspace cleanupWithError:nil];
            NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                               code:316
                                           userInfo:@{NSLocalizedDescriptionKey: @"Failed to extract data archive to staging"}];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        NSError *stageValidationError = nil;
        __attribute__((objc_precise_lifetime))
        PXValidatedMainDataStage *validatedStage =
            [mainDataWorkspace validatedStageWithExpectedLogicalMemberCount:expectedLogicalMemberCount
                                                     expectedRegularFileBytes:expectedRegularFileBytes
                                                                         error:&stageValidationError];
        if (!validatedStage) {
            [mainDataWorkspace cleanupWithError:nil];
            NSError *err = stageValidationError ?: [NSError errorWithDomain:PXMainDataStagingErrorDomain
                                                                        code:PXMainDataStagingErrorInvalidInput
                                                                    userInfo:@{
                                                                        NSLocalizedDescriptionKey: @"The extracted main-data stage failed validation.",
                                                                        PXMainDataStagingErrorFieldPathKey: @"$.data"
                                                                    }];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        PXDebugHeader(debugPre, @"Data Restore (Validated Staging -> Transactional Container Commit)");
        PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"stagedEntryCount=%lu", (unsigned long)validatedStage.entryCount]);
        PXDebugAppendLine(debugPre, [NSString stringWithFormat:@"stagedRegularFileCount=%lu", (unsigned long)validatedStage.regularFileCount]);
        PXDebugRun(runner, debugPre, @"ls container (before transaction)", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote(dataContainerPath)]);

        // The target process is not terminated until the complete staged tree is accepted.
        [self _killRelatedProcessesForBundleID:bundleID];

        PXDestructivePathValidator *preMutationValidator = [[PXDestructivePathValidator alloc] init];
        NSError *preMutationValidationError = nil;
        NSString *preMutationCanonicalPath =
            [preMutationValidator validatedCanonicalPathForContainer:dataContainerModel
                                                               error:&preMutationValidationError];
        if (preMutationValidationError ||
            preMutationCanonicalPath.length == 0 ||
            ![preMutationCanonicalPath isEqualToString:dataContainerPath]) {
            [mainDataWorkspace cleanupWithError:nil];
            NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                               code:303
                                           userInfo:@{NSLocalizedDescriptionKey: PXExactRestoreDestinationErrorDescription}];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        NSError *preCommitStageValidationError = nil;
        PXValidatedMainDataStage *preCommitValidatedStage =
            [mainDataWorkspace validatedStageWithExpectedLogicalMemberCount:expectedLogicalMemberCount
                                                    expectedRegularFileBytes:expectedRegularFileBytes
                                                                        error:&preCommitStageValidationError];
        if (!preCommitValidatedStage ||
            !PXValidatedMainDataStagesAreEquivalent(validatedStage, preCommitValidatedStage)) {
            [mainDataWorkspace cleanupWithError:nil];
            NSError *err = preCommitStageValidationError ?:
                [NSError errorWithDomain:PXMainDataStagingErrorDomain
                                    code:PXMainDataStagingErrorFilesystemChanged
                                userInfo:@{
                                    NSLocalizedDescriptionKey: @"The validated main-data stage changed before transaction commit.",
                                    PXMainDataStagingErrorFieldPathKey: @"$.data"
                                }];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }

        NSError *mainTransactionPrepareError = nil;
        __attribute__((objc_precise_lifetime))
        PXMainDataRestoreTransaction *mainDataTransaction =
            [PXMainDataRestoreTransaction transactionForContainer:dataContainerModel
                                                     canonicalPath:dataContainerPath
                                                    validatedStage:preCommitValidatedStage
                                                             error:&mainTransactionPrepareError];
        if (!mainDataTransaction) {
            [mainDataWorkspace cleanupWithError:nil];
            NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                               code:317
                                           userInfo:@{
                                               NSLocalizedDescriptionKey: @"Failed to prepare transactional main-data commit"
                                           }];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }
        PXDebugAppendLine(debugPre,
                          [NSString stringWithFormat:@"recoveredStaleMainTransactions=%lu",
                           (unsigned long)mainDataTransaction.recoveredStaleTransactionCount]);

        NSError *mainTransactionCleanupWarning = nil;
        NSError *mainTransactionError = nil;
        if (![mainDataTransaction commitWithCleanupWarning:&mainTransactionCleanupWarning
                                                     error:&mainTransactionError]) {
            [mainDataWorkspace cleanupWithError:nil];
            PXDebugAppendLine(debugPre,
                              [NSString stringWithFormat:@"mainTransactionRollbackPerformed=%d rollbackComplete=%d",
                               mainDataTransaction.rollbackPerformed ? 1 : 0,
                               mainDataTransaction.rollbackComplete ? 1 : 0]);
            NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                               code:317
                                           userInfo:@{
                                               NSLocalizedDescriptionKey: @"Failed to commit validated main-data stage transactionally"
                                           }];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
            return;
        }
        PXDebugAppendLine(debugPre, @"mainTransactionCommitted=1");
        if (mainTransactionCleanupWarning) {
            [warnings addObject:@"Main-data transaction cleanup failed; ownership correction was skipped"];
        }
        PXDebugRun(runner, debugPre, @"ls container (after transaction)", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote(dataContainerPath)]);

        // Never recurse through a retained private journal/quarantine workspace.
        if (!mainTransactionCleanupWarning) {
            [runner run:[NSString stringWithFormat:@"chown -R mobile:mobile %@ 2>/dev/null || true", PXShellQuote(dataContainerPath)]];
        }

        NSError *mainDataCleanupError = nil;
        if (![mainDataWorkspace cleanupWithError:&mainDataCleanupError]) {
            [warnings addObject:@"Main-data staging cleanup failed"];
        }

        // Post-restore hygiene: refresh preferences daemon caches.
        // Some apps read state via cfprefsd and may not notice external file writes immediately.
        PXKillallByName(@"cfprefsd", SIGTERM);

        // Data container restored.

        // Restore profile redirected appdata (if present)
        if (restorePlan.includesProfileAppData) {
            PXMainDataStagingWorkspace *profileWorkspace = nil;
            PXValidatedMainDataStage *profileStage = nil;
            NSError *profileStageError = nil;
            if (![self _stageOptionalDirectoryArchiveName:restorePlan.profileAppDataArchiveName
                                               sourcePath:restorePlan.profileAppDataSourcePath
                                              restorePlan:restorePlan
                                                  tarPath:tarPath
                                              failureCode:307
                                       failureDescription:@"Failed to restore validated profile AppData stage"
                                             workspaceOut:&profileWorkspace
                                                 stageOut:&profileStage
                                                    error:&profileStageError]) {
                NSError *err = profileStageError;
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                return;
            }

            NSError *profileDestinationError = nil;
            NSString *profileDestination =
                [optionalDestinationPlan revalidatedProfileAppDataPathWithError:&profileDestinationError];
            if (!profileDestination) {
                [profileWorkspace cleanupWithError:nil];
                NSError *err = profileDestinationError ?:
                    [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                        code:PXOptionalRestoreStagingErrorInvalidDestinationIdentity
                                    userInfo:@{
                                        NSLocalizedDescriptionKey: @"The profile AppData destination could not be revalidated.",
                                        PXOptionalRestoreStagingErrorFieldPathKey: @"$.profileAppData.destination"
                                    }];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                return;
            }

            [self _wipeDirectoryContents:profileDestination];
            if (![self _cloneOptionalDirectoryStageAtPath:profileStage.dataPath
                                              destination:profileDestination
                                                   tarPath:tarPath
                                                    runner:runner
                                                 debugPath:debugPre
                                                debugLabel:@"profileOptionalStage"]) {
                [profileWorkspace cleanupWithError:nil];
                NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                   code:307
                                               userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore validated profile AppData stage"}];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                return;
            }
            [runner run:[NSString stringWithFormat:@"chown -R mobile:mobile %@ 2>/dev/null || true",
                         PXShellQuote(profileDestination)]];
            NSError *profileCleanupError = nil;
            if (![profileWorkspace cleanupWithError:&profileCleanupError]) {
                [warnings addObject:@"Optional-directory staging cleanup failed"];
            }
        }

        // Restore global Safari library (if present)
        if (restorePlan.includesGlobalSafari) {
            PXMainDataStagingWorkspace *safariWorkspace = nil;
            PXValidatedMainDataStage *safariStage = nil;
            NSError *safariStageError = nil;
            if (![self _stageOptionalDirectoryArchiveName:restorePlan.globalSafariArchiveName
                                               sourcePath:restorePlan.globalSafariSourcePath
                                              restorePlan:restorePlan
                                                  tarPath:tarPath
                                              failureCode:311
                                       failureDescription:@"Failed to restore validated global Safari stage"
                                             workspaceOut:&safariWorkspace
                                                 stageOut:&safariStage
                                                    error:&safariStageError]) {
                NSError *err = safariStageError;
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                return;
            }

            NSError *safariDestinationError = nil;
            NSString *safariDestination =
                [optionalDestinationPlan revalidatedGlobalSafariPathWithError:&safariDestinationError];
            if (!safariDestination) {
                [safariWorkspace cleanupWithError:nil];
                NSError *err = safariDestinationError ?:
                    [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                        code:PXOptionalRestoreStagingErrorInvalidDestinationIdentity
                                    userInfo:@{
                                        NSLocalizedDescriptionKey: @"The global Safari destination could not be revalidated.",
                                        PXOptionalRestoreStagingErrorFieldPathKey: @"$.globalSafari.destination"
                                    }];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                return;
            }

            [self _wipeDirectoryContents:safariDestination];
            if (![self _cloneOptionalDirectoryStageAtPath:safariStage.dataPath
                                              destination:safariDestination
                                                   tarPath:tarPath
                                                    runner:runner
                                                 debugPath:debugPre
                                                debugLabel:@"safariOptionalStage"]) {
                [safariWorkspace cleanupWithError:nil];
                NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                   code:311
                                               userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore validated global Safari stage"}];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                return;
            }
            [runner run:[NSString stringWithFormat:@"chown -R mobile:mobile %@ 2>/dev/null || true",
                         PXShellQuote(safariDestination)]];
            NSError *safariCleanupError = nil;
            if (![safariWorkspace cleanupWithError:&safariCleanupError]) {
                [warnings addObject:@"Optional-directory staging cleanup failed"];
            }
        }

        // Restore each exact physical App Group target from validated staged content.
        NSUInteger appGroupTargetIndex = 0;
        for (PXAppGroupRestoreTarget *target in appGroupTargetPlan.targets) {
            appGroupTargetIndex++;
            __attribute__((objc_precise_lifetime))
            PXMainDataStagingWorkspace *retainedGroupWorkspace = nil;
            __attribute__((objc_precise_lifetime))
            PXValidatedMainDataStage *retainedGroupStage = nil;

            NSMutableArray<NSNumber *> *targetMemberCounts =
                [NSMutableArray arrayWithCapacity:target.planItems.count];
            NSMutableArray<NSNumber *> *targetRegularFileBytes =
                [NSMutableArray arrayWithCapacity:target.planItems.count];
            for (PXRestorePlanAppGroupItem *plannedItem in target.planItems) {
                NSString *archiveName = plannedItem.archiveName;
                NSNumber *memberCountSummary =
                    restorePlan.validatedArchives.memberCountsByArchiveName[archiveName];
                NSNumber *regularByteSummary =
                    restorePlan.validatedArchives.regularFileBytesByArchiveName[archiveName];
                unsigned long long memberCountValue = 0;
                unsigned long long regularByteValue = 0;
                if (!PXReadUnsignedIntegralSummaryNumber(memberCountSummary, &memberCountValue) ||
                    !PXReadUnsignedIntegralSummaryNumber(regularByteSummary, &regularByteValue) ||
                    memberCountValue > NSUIntegerMax) {
                    NSError *err = [NSError errorWithDomain:PXAppGroupRestoreTargetPlanErrorDomain
                                                       code:PXAppGroupRestoreTargetPlanErrorInconsistentPlan
                                                   userInfo:@{
                                                       NSLocalizedDescriptionKey: @"The accepted App Group archive summary is inconsistent.",
                                                       PXAppGroupRestoreTargetPlanErrorFieldPathKey: @"$.appGroups"
                                                   }];
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }
                [targetMemberCounts addObject:@(memberCountValue)];
                [targetRegularFileBytes addObject:@(regularByteValue)];
            }

            for (NSUInteger sourceIndex = 0; sourceIndex < target.planItems.count; sourceIndex++) {
                PXRestorePlanAppGroupItem *plannedItem = target.planItems[sourceIndex];
                NSString *archivePath = plannedItem.sourcePath;
                NSUInteger memberCountValue =
                    (NSUInteger)[targetMemberCounts[sourceIndex] unsignedLongLongValue];
                unsigned long long regularByteValue =
                    [targetRegularFileBytes[sourceIndex] unsignedLongLongValue];

                NSError *workspaceError = nil;
                __attribute__((objc_precise_lifetime))
                PXMainDataStagingWorkspace *currentGroupWorkspace =
                    [PXMainDataStagingWorkspace createWorkspaceWithError:&workspaceError];
                if (!currentGroupWorkspace) {
                    [retainedGroupWorkspace cleanupWithError:nil];
                    NSError *err = workspaceError ?:
                        [NSError errorWithDomain:PXMainDataStagingErrorDomain
                                            code:PXMainDataStagingErrorWorkspaceCreationFailed
                                        userInfo:@{
                                            NSLocalizedDescriptionKey: @"The private App Group staging workspace could not be created.",
                                            PXMainDataStagingErrorFieldPathKey: @"$.workspace"
                                        }];
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }

                NSError *emptyError = nil;
                if (![currentGroupWorkspace validateEmptyDataDirectoryWithError:&emptyError]) {
                    [currentGroupWorkspace cleanupWithError:nil];
                    [retainedGroupWorkspace cleanupWithError:nil];
                    NSError *err = emptyError ?:
                        [NSError errorWithDomain:PXMainDataStagingErrorDomain
                                            code:PXMainDataStagingErrorInvalidInput
                                        userInfo:@{
                                            NSLocalizedDescriptionKey: @"The private App Group staging workspace failed empty validation.",
                                            PXMainDataStagingErrorFieldPathKey: @"$.data"
                                        }];
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }

                CommandResult *extractResult =
                    [self _tarExtract:tarPath
                              archive:archivePath
                                toDir:currentGroupWorkspace.dataPath];
                if (extractResult.exitCode != 0) {
                    [currentGroupWorkspace cleanupWithError:nil];
                    [retainedGroupWorkspace cleanupWithError:nil];
                    NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                       code:310
                                                   userInfo:@{
                                                       NSLocalizedDescriptionKey: @"Failed to extract App Group archive to staging"
                                                   }];
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }

                NSError *validationError = nil;
                __attribute__((objc_precise_lifetime))
                PXValidatedMainDataStage *currentGroupStage =
                    [currentGroupWorkspace validatedStageWithExpectedLogicalMemberCount:memberCountValue
                                                                 expectedRegularFileBytes:regularByteValue
                                                                                     error:&validationError];
                if (!currentGroupStage) {
                    [currentGroupWorkspace cleanupWithError:nil];
                    [retainedGroupWorkspace cleanupWithError:nil];
                    NSError *err = validationError ?:
                        [NSError errorWithDomain:PXMainDataStagingErrorDomain
                                            code:PXMainDataStagingErrorInvalidInput
                                        userInfo:@{
                                            NSLocalizedDescriptionKey: @"The extracted App Group stage failed validation.",
                                            PXMainDataStagingErrorFieldPathKey: @"$.data"
                                        }];
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }

                if (!retainedGroupWorkspace) {
                    retainedGroupWorkspace = currentGroupWorkspace;
                    retainedGroupStage = currentGroupStage;
                    continue;
                }

                if (!PXValidatedMainDataStagesAreEquivalent(retainedGroupStage, currentGroupStage)) {
                    [currentGroupWorkspace cleanupWithError:nil];
                    [retainedGroupWorkspace cleanupWithError:nil];
                    NSError *err = [NSError errorWithDomain:PXAppGroupRestoreTargetPlanErrorDomain
                                                       code:PXAppGroupRestoreTargetPlanErrorInconsistentPlan
                                                   userInfo:@{
                                                       NSLocalizedDescriptionKey: @"App Group archives for one physical target are inconsistent.",
                                                       PXAppGroupRestoreTargetPlanErrorFieldPathKey: @"$.appGroups"
                                                   }];
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }

                NSError *duplicateCleanupError = nil;
                if (![currentGroupWorkspace cleanupWithError:&duplicateCleanupError]) {
                    [retainedGroupWorkspace cleanupWithError:nil];
                    NSError *err = duplicateCleanupError ?:
                        [NSError errorWithDomain:PXMainDataStagingErrorDomain
                                            code:PXMainDataStagingErrorCleanupFailed
                                        userInfo:@{
                                            NSLocalizedDescriptionKey: @"A duplicate App Group staging workspace could not be cleaned safely.",
                                            PXMainDataStagingErrorFieldPathKey: @"$.workspace"
                                        }];
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }
            }

            if (!retainedGroupWorkspace || !retainedGroupStage || target.planItems.count == 0) {
                [retainedGroupWorkspace cleanupWithError:nil];
                NSError *err = [NSError errorWithDomain:PXAppGroupRestoreTargetPlanErrorDomain
                                                   code:PXAppGroupRestoreTargetPlanErrorInconsistentPlan
                                               userInfo:@{
                                                   NSLocalizedDescriptionKey: @"The accepted App Group restore target has no validated source.",
                                                   PXAppGroupRestoreTargetPlanErrorFieldPathKey: @"$.appGroups"
                                               }];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                return;
            }

            BOOL targetRevalidated = target.canonicalPath.length > 0 && target.containerModels.count > 0;
            PXDestructivePathValidator *groupTargetValidator = [[PXDestructivePathValidator alloc] init];
            for (PXResolvedContainer *containerModel in target.containerModels) {
                NSError *targetValidationError = nil;
                NSString *revalidatedCanonicalPath =
                    [groupTargetValidator validatedCanonicalPathForContainer:containerModel
                                                                       error:&targetValidationError];
                if (targetValidationError ||
                    revalidatedCanonicalPath.length == 0 ||
                    ![revalidatedCanonicalPath isEqualToString:target.canonicalPath]) {
                    targetRevalidated = NO;
                    break;
                }
            }
            if (!targetRevalidated) {
                [retainedGroupWorkspace cleanupWithError:nil];
                NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                   code:319
                                               userInfo:@{
                                                   NSLocalizedDescriptionKey: @"Exact App Group restore target could not be revalidated safely"
                                               }];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                return;
            }

            PXDebugHeader(debugPre, @"App Group Restore (Validated Stage -> Target)");
            PXDebugAppendLine(debugPre,
                              [NSString stringWithFormat:@"appGroupTargetIndex=%lu targetCount=%lu",
                               (unsigned long)appGroupTargetIndex,
                               (unsigned long)appGroupTargetPlan.targets.count]);
            PXDebugAppendLine(debugPre,
                              [NSString stringWithFormat:@"appGroupStagedEntryCount=%lu",
                               (unsigned long)retainedGroupStage.entryCount]);

            NSString *canonicalTargetPath = target.canonicalPath;
            [self _wipeDirectoryContents:canonicalTargetPath];

            BOOL shouldPreferGroupCpClone =
                [tarPath isEqualToString:@"/usr/bin/tar"] ||
                [tarPath isEqualToString:@"/bin/tar"];
            CommandResult *groupCloneResult = nil;
            if (!shouldPreferGroupCpClone) {
                NSString *cloneCommand =
                    [NSString stringWithFormat:@"%@ --xattrs --acls -cf - -C %@ . | %@ --xattrs --acls -xf - -C %@",
                     PXShellQuote(tarPath),
                     PXShellQuote(retainedGroupStage.dataPath),
                     PXShellQuote(tarPath),
                     PXShellQuote(canonicalTargetPath)];
                groupCloneResult = [runner runAndCapture:cloneCommand];
                PXDebugAppendLine(debugPre,
                                  [NSString stringWithFormat:@"appGroupTarPipeCloneExit=%d",
                                   (int)groupCloneResult.exitCode]);
                if (groupCloneResult.stderrString.length) {
                    PXDebugAppendLine(debugPre, @"appGroupTarPipeCloneStderrPresent=1");
                }
                if (groupCloneResult.exitCode != 0 ||
                    (groupCloneResult.stderrString.length &&
                     [groupCloneResult.stderrString containsString:@"XATTR support is not available"])) {
                    shouldPreferGroupCpClone = YES;
                }
            } else {
                PXDebugAppendLine(debugPre, @"appGroupTarPipeCloneSkipped=1");
            }

            if (shouldPreferGroupCpClone) {
                NSString *fallbackCommand =
                    [NSString stringWithFormat:@"cp -a %@/. %@/ 2>/dev/null",
                     PXShellQuote(retainedGroupStage.dataPath),
                     PXShellQuote(canonicalTargetPath)];
                CommandResult *copyResult = [runner runAndCapture:fallbackCommand];
                PXDebugAppendLine(debugPre,
                                  [NSString stringWithFormat:@"appGroupCpCloneExit=%d",
                                   (int)copyResult.exitCode]);
                if (copyResult.stderrString.length) {
                    PXDebugAppendLine(debugPre, @"appGroupCpCloneStderrPresent=1");
                }
                if (copyResult.exitCode != 0) {
                    [retainedGroupWorkspace cleanupWithError:nil];
                    NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                       code:310
                                                   userInfo:@{
                                                       NSLocalizedDescriptionKey: @"Failed to restore validated App Group stage"
                                                   }];
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }
            }

            [runner run:[NSString stringWithFormat:@"chown -R mobile:mobile %@ 2>/dev/null || true",
                         PXShellQuote(canonicalTargetPath)]];

            NSError *groupCleanupError = nil;
            if (![retainedGroupWorkspace cleanupWithError:&groupCleanupError]) {
                [warnings addObject:@"App Group staging cleanup failed"];
            }
        }

        // Restore generic system app global Library folders (if present)
        if (restorePlan.systemGlobalItems.count) {
            for (PXRestorePlanSystemGlobalItem *plannedItem in restorePlan.systemGlobalItems) {
                NSString *subdir = plannedItem.librarySubdirectory;
                if ([bundleID isEqualToString:@"com.apple.mobilesafari"] &&
                    [subdir isEqualToString:@"Safari"] &&
                    restorePlan.includesGlobalSafari) {
                    continue;
                }

                NSString *plannedDestination =
                    [optionalDestinationPlan systemGlobalPathForSubdirectory:subdir];
                if (!plannedDestination.length) {
                    NSError *err = [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                                       code:PXOptionalRestoreStagingErrorInconsistentPlan
                                                   userInfo:@{
                                                       NSLocalizedDescriptionKey: @"The system-global destination plan is inconsistent.",
                                                       PXOptionalRestoreStagingErrorFieldPathKey: @"$"
                                                   }];
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }

                PXMainDataStagingWorkspace *systemWorkspace = nil;
                PXValidatedMainDataStage *systemStage = nil;
                NSError *systemStageError = nil;
                if (![self _stageOptionalDirectoryArchiveName:plannedItem.archiveName
                                                   sourcePath:plannedItem.sourcePath
                                                  restorePlan:restorePlan
                                                      tarPath:tarPath
                                                  failureCode:318
                                           failureDescription:@"Failed to restore validated system-global stage"
                                                 workspaceOut:&systemWorkspace
                                                     stageOut:&systemStage
                                                        error:&systemStageError]) {
                    NSError *err = systemStageError;
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }

                NSError *destinationError = nil;
                NSString *destination =
                    [optionalDestinationPlan revalidatedSystemGlobalPathForSubdirectory:subdir
                                                                                  error:&destinationError];
                if (!destination) {
                    [systemWorkspace cleanupWithError:nil];
                    NSError *err = destinationError ?:
                        [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                            code:PXOptionalRestoreStagingErrorInvalidDestinationIdentity
                                        userInfo:@{
                                            NSLocalizedDescriptionKey: @"The system-global destination could not be revalidated.",
                                            PXOptionalRestoreStagingErrorFieldPathKey: @"$"
                                        }];
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }

                [self _killRelatedProcessesForBundleID:bundleID];
                BOOL destinationExisted = [fm fileExistsAtPath:destination];
                if (destinationExisted) {
                    NSString *trash = [NSString stringWithFormat:@"%@.WeaponXTrash.%@",
                                       destination,
                                       PXTimestampSuffix()];
                    CommandResult *moveResult =
                        [runner runAndCapture:[NSString stringWithFormat:@"mv %@ %@ 2>/dev/null",
                                               PXShellQuote(destination),
                                               PXShellQuote(trash)]];
                    if (moveResult.exitCode != 0) {
                        [systemWorkspace cleanupWithError:nil];
                        NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                           code:318
                                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore validated system-global stage"}];
                        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                        return;
                    }
                }

                CommandResult *mkdirResult =
                    [runner runAndCapture:[NSString stringWithFormat:@"mkdir %@ 2>/dev/null",
                                           PXShellQuote(destination)]];
                if (mkdirResult.exitCode != 0) {
                    [systemWorkspace cleanupWithError:nil];
                    NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                       code:318
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore validated system-global stage"}];
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }

                if (![self _cloneOptionalDirectoryStageAtPath:systemStage.dataPath
                                                  destination:destination
                                                       tarPath:tarPath
                                                        runner:runner
                                                     debugPath:debugPre
                                                    debugLabel:@"systemGlobalOptionalStage"]) {
                    [systemWorkspace cleanupWithError:nil];
                    NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                       code:318
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore validated system-global stage"}];
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }
                [runner run:[NSString stringWithFormat:@"chown -R mobile:mobile %@ 2>/dev/null || true",
                             PXShellQuote(destination)]];
                NSError *systemCleanupError = nil;
                if (![systemWorkspace cleanupWithError:&systemCleanupError]) {
                    [warnings addObject:@"Optional-directory staging cleanup failed"];
                }
            }
        }

        // Restore shared system DBs (if present)
        if (restorePlan.sharedDatabaseItems.count) {
            NSMutableArray<PXOptionalFileStagingWorkspace *> *sharedWorkspaces =
                [NSMutableArray arrayWithCapacity:restorePlan.sharedDatabaseItems.count];
            NSMutableArray<PXValidatedOptionalFileStage *> *sharedStages =
                [NSMutableArray arrayWithCapacity:restorePlan.sharedDatabaseItems.count];
            NSMutableArray<NSString *> *sharedDestinations =
                [NSMutableArray arrayWithCapacity:restorePlan.sharedDatabaseItems.count];

            for (PXRestorePlanSharedDatabaseItem *plannedItem in restorePlan.sharedDatabaseItems) {
                NSError *fileStageError = nil;
                PXOptionalFileStagingWorkspace *workspace =
                    [PXOptionalFileStagingWorkspace workspaceByStagingSourceFileAtPath:plannedItem.sourcePath
                                                                                 error:&fileStageError];
                if (!workspace) {
                    PXCleanupOptionalFileWorkspaces(sharedWorkspaces);
                    NSError *err = fileStageError ?:
                        [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                            code:PXOptionalRestoreStagingErrorInvalidInput
                                        userInfo:@{
                                            NSLocalizedDescriptionKey: @"The shared database source could not be staged.",
                                            PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
                                        }];
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }
                [sharedWorkspaces addObject:workspace];
                [sharedStages addObject:workspace.validatedStage];
            }

            for (PXRestorePlanSharedDatabaseItem *plannedItem in restorePlan.sharedDatabaseItems) {
                NSError *destinationError = nil;
                NSString *destination =
                    [optionalDestinationPlan revalidatedSharedDatabasePathForRelativePath:plannedItem.libraryRelativePath
                                                                                    error:&destinationError];
                if (!destination) {
                    PXCleanupOptionalFileWorkspaces(sharedWorkspaces);
                    NSError *err = destinationError ?:
                        [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                            code:PXOptionalRestoreStagingErrorInvalidDestinationIdentity
                                        userInfo:@{
                                            NSLocalizedDescriptionKey: @"A shared database destination could not be revalidated.",
                                            PXOptionalRestoreStagingErrorFieldPathKey: @"$"
                                        }];
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }
                [sharedDestinations addObject:destination];
            }

            PXKillallByName(@"accountsd", SIGTERM);
            PXKillallByName(@"calaccessd", SIGTERM);
            PXKillallByName(@"imagent", SIGTERM);
            PXKillallByName(@"MobileSMS", SIGTERM);
            [NSThread sleepForTimeInterval:0.2];
            PXKillallByName(@"accountsd", SIGKILL);
            PXKillallByName(@"calaccessd", SIGKILL);
            PXKillallByName(@"imagent", SIGKILL);
            PXKillallByName(@"MobileSMS", SIGKILL);

            for (NSUInteger index = 0; index < restorePlan.sharedDatabaseItems.count; index++) {
                NSString *destination = sharedDestinations[index];
                PXValidatedOptionalFileStage *stage = sharedStages[index];
                if ([fm fileExistsAtPath:destination]) {
                    NSString *trash = [NSString stringWithFormat:@"%@.WeaponXTrash.%@",
                                       destination,
                                       PXTimestampSuffix()];
                    CommandResult *moveResult =
                        [runner runAndCapture:[NSString stringWithFormat:@"mv %@ %@ 2>/dev/null",
                                               PXShellQuote(destination),
                                               PXShellQuote(trash)]];
                    if (moveResult.exitCode != 0) {
                        PXCleanupOptionalFileWorkspaces(sharedWorkspaces);
                        NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                           code:320
                                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore staged optional file"}];
                        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                        return;
                    }
                }
                CommandResult *copyResult =
                    [runner runAndCapture:[NSString stringWithFormat:@"cp -a %@ %@ 2>/dev/null",
                                           PXShellQuote(stage.filePath),
                                           PXShellQuote(destination)]];
                if (copyResult.exitCode != 0) {
                    PXCleanupOptionalFileWorkspaces(sharedWorkspaces);
                    NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                       code:320
                                                   userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore staged optional file"}];
                    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                    return;
                }
                [runner run:[NSString stringWithFormat:@"chown mobile:mobile %@ 2>/dev/null || true",
                             PXShellQuote(destination)]];
                [runner run:[NSString stringWithFormat:@"chmod 600 %@ 2>/dev/null || true",
                             PXShellQuote(destination)]];
            }

            if (!PXCleanupOptionalFileWorkspaces(sharedWorkspaces)) {
                [warnings addObject:@"Optional-file staging cleanup failed"];
            }
            [warnings addObject:@"Restored shared system DBs (this may affect multiple apps)"];
            PXKillallByName(@"accountsd", SIGTERM);
            PXKillallByName(@"calaccessd", SIGTERM);
            PXKillallByName(@"imagent", SIGTERM);
            PXKillallByName(@"MobileSMS", SIGTERM);
        }

        // Preferences restore
        if (restorePlan.includesPreferences) {
            NSError *preferencesStageError = nil;
            PXOptionalFileStagingWorkspace *preferencesWorkspace =
                [PXOptionalFileStagingWorkspace workspaceByStagingSourceFileAtPath:restorePlan.preferencesSourcePath
                                                                             error:&preferencesStageError];
            if (!preferencesWorkspace) {
                NSError *err = preferencesStageError ?:
                    [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                        code:PXOptionalRestoreStagingErrorInvalidInput
                                    userInfo:@{
                                        NSLocalizedDescriptionKey: @"The Preferences source could not be staged.",
                                        PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
                                    }];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                return;
            }
            NSError *preferencesDestinationError = nil;
            NSString *preferencesDestination =
                [optionalDestinationPlan revalidatedPreferencesPathWithError:&preferencesDestinationError];
            if (!preferencesDestination) {
                [preferencesWorkspace cleanupWithError:nil];
                NSError *err = preferencesDestinationError ?:
                    [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                        code:PXOptionalRestoreStagingErrorInvalidDestinationIdentity
                                    userInfo:@{
                                        NSLocalizedDescriptionKey: @"The Preferences destination could not be revalidated.",
                                        PXOptionalRestoreStagingErrorFieldPathKey: @"$.preferences.destination"
                                    }];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                return;
            }
            CommandResult *copyResult =
                [runner runAndCapture:[NSString stringWithFormat:@"cp -f %@ %@ 2>/dev/null",
                                       PXShellQuote(preferencesWorkspace.validatedStage.filePath),
                                       PXShellQuote(preferencesDestination)]];
            if (copyResult.exitCode != 0) {
                [preferencesWorkspace cleanupWithError:nil];
                NSError *err = [NSError errorWithDomain:PXBackupErrorDomain
                                                   code:320
                                               userInfo:@{NSLocalizedDescriptionKey: @"Failed to restore staged optional file"}];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                return;
            }
            [runner run:[NSString stringWithFormat:@"chown mobile:mobile %@ 2>/dev/null || true",
                         PXShellQuote(preferencesDestination)]];
            [runner run:[NSString stringWithFormat:@"chmod 644 %@ 2>/dev/null || true",
                         PXShellQuote(preferencesDestination)]];
            PXKillallByName(@"cfprefsd", SIGTERM);
            NSError *preferencesCleanupError = nil;
            if (![preferencesWorkspace cleanupWithError:&preferencesCleanupError]) {
                [warnings addObject:@"Optional-file staging cleanup failed"];
            }
        }

        // Keychain restore (warning-only on execution failure)
        if (restorePlan.includesKeychain) {
            NSError *keychainStageError = nil;
            PXOptionalFileStagingWorkspace *keychainWorkspace =
                [PXOptionalFileStagingWorkspace workspaceByStagingSourceFileAtPath:restorePlan.keychainSourcePath
                                                                             error:&keychainStageError];
            if (!keychainWorkspace) {
                NSError *err = keychainStageError ?:
                    [NSError errorWithDomain:PXOptionalRestoreStagingErrorDomain
                                        code:PXOptionalRestoreStagingErrorInvalidInput
                                    userInfo:@{
                                        NSLocalizedDescriptionKey: @"The Keychain input source could not be staged.",
                                        PXOptionalRestoreStagingErrorFieldPathKey: @"$.source"
                                    }];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, err); });
                return;
            }

            NSString *keychainBackupPath = keychainWorkspace.validatedStage.filePath;
            NSArray<NSString *> *groups = restorePlan.keychainGroups;
            NSString *method = restorePlan.keychainMethod;
            (void)method;
            BOOL shouldUseInApp = restorePlan.keychainUsesInAppMethod;
            BOOL ok = NO;
            if (shouldUseInApp) {
                ok = [self _inAppKeychainRestoreForBundleID:bundleID
                                              containerPath:dataContainerPath
                                                     groups:groups
                                                   fromFile:keychainBackupPath
                                                  overwrite:YES
                                                  debugPath:debugKeychain
                                                   warnings:warnings];
            } else {
                ok = [self _restoreKeychainForBundleID:bundleID
                                              groups:groups
                                            fromFile:keychainBackupPath
                                           overwrite:YES
                                            warnings:warnings];
            }
            if (!ok) {
                [warnings addObject:@"Keychain restore failed (continuing)" ];
            }

            NSError *keychainCleanupError = nil;
            if (![keychainWorkspace cleanupWithError:&keychainCleanupError]) {
                [warnings addObject:@"Optional-file staging cleanup failed"];
            }

            PXDebugHeader(debugKeychain, @"Keychain After Restore");
            PXDebugAppendLine(debugKeychain, [NSString stringWithFormat:@"groups=%@", groups ?: @[]]);
            if (!shouldUseInApp) {
                NSString *scriptPath = [runner firstExistingPath:@[@"/Library/WeaponX/keychain_backup.sh",
                                                                  @"/var/jb/Library/WeaponX/keychain_backup.sh",
                                                                  @"/private/var/jb/Library/WeaponX/keychain_backup.sh"]];
                if (scriptPath.length && groups.count) {
                    NSString *csv = [groups componentsJoinedByString:@","];
                    PXDebugRun(runner, debugKeychain, @"list", [NSString stringWithFormat:@"%@ list %@ --groups %@", PXShellQuote(scriptPath), PXShellQuote(bundleID), PXShellQuote(csv)]);
                }
            } else {
                PXDebugAppendLine(debugKeychain, @"post-restore list skipped (used in-app keychain method)" );
            }
        }

        // Debug snapshot: after restore
        {
            PXDebugHeader(debugPost, @"Restore Done");
            NSDictionary *rp = PXResolvePathsForBundleID(bundleID);
            NSString *lsDataPath = rp[@"lsDataContainerPath"];
            PXDebugAppendLine(debugPost, [NSString stringWithFormat:@"lsDataContainerPath=%@", lsDataPath ?: @""]);
            PXDebugAppendLine(debugPost, [NSString stringWithFormat:@"chosenDataContainerPath=%@", dataContainerPath ?: @""]);
            PXDebugRun(runner, debugPost, @"du data", [NSString stringWithFormat:@"du -sk %@ 2>/dev/null || true", PXShellQuote(dataContainerPath)]);
            PXDebugRun(runner, debugPost, @"ls prefs", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote([dataContainerPath stringByAppendingPathComponent:@"Library/Preferences"]) ]);
            NSString *prefDest = optionalDestinationPlan.preferencesPath;
            if (prefDest.length) {
                PXDebugRun(runner, debugPost, @"ls global prefs", [NSString stringWithFormat:@"ls -lh %@ 2>/dev/null || true", PXShellQuote(prefDest)]);
            }

            if ([lsDataPath isKindOfClass:[NSString class]] && lsDataPath.length && ![lsDataPath isEqualToString:dataContainerPath]) {
                PXDebugHeader(debugPost, @"WARNING: Active Container Differs");
                PXDebugRun(runner, debugPost, @"du lsDataContainerPath", [NSString stringWithFormat:@"du -sk %@ 2>/dev/null || true", PXShellQuote(lsDataPath)]);
                PXDebugRun(runner, debugPost, @"ls lsDataContainerPath/Library/Preferences", [NSString stringWithFormat:@"ls -la %@ 2>/dev/null || true", PXShellQuote([lsDataPath stringByAppendingPathComponent:@"Library/Preferences"]) ]);
            }
        }

        NSString *metadataPath = [dataContainerPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        if (![fm fileExistsAtPath:metadataPath]) {
            [warnings addObject:@"Post-restore verification: data container metadata plist is missing"];
        }
        NSString *libraryPath = [dataContainerPath stringByAppendingPathComponent:@"Library"];
        BOOL libraryIsDir = NO;
        if (![fm fileExistsAtPath:libraryPath isDirectory:&libraryIsDir] || !libraryIsDir) {
            [warnings addObject:@"Post-restore verification: Library directory missing after restore"];
        }

        [self _killRelatedProcessesForBundleID:bundleID];

        PXRestoreResult *out = [[PXRestoreResult alloc] init];
        out.warnings = warnings;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(out, nil);
            }
        });
    });
}

@end
