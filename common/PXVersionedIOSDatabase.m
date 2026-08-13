#import "PXVersionedIOSDatabase.h"
#import "DBDebugLogger.h"
#import <CommonCrypto/CommonDigest.h>
#import <CoreFoundation/CoreFoundation.h>

NSString *const PXVersionedIOSDatabaseErrorDomain = @"com.hydra.tlinkios.versioned-ios-database";
NSInteger const PXVersionedIOSDatabaseReaderVersion = 1;

static NSError *PXIOSDBError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:PXVersionedIOSDatabaseErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Unknown iOS database error"}];
}

static NSDictionary *PXIOSDBReadJSON(NSString *path, NSError **error) {
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!data) return nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![object isKindOfClass:[NSDictionary class]]) {
        if (error && !*error) *error = PXIOSDBError(2, @"Invalid JSON root; expected dictionary");
        return nil;
    }
    return object;
}

static NSString *PXIOSDBSHA256(NSString *path, NSError **error) {
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:error];
    if (!data) return nil;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        [result appendFormat:@"%02x", digest[index]];
    }
    return result;
}

static BOOL PXIOSDBExactInteger(id value, NSInteger minimum, NSInteger *result) {
    if (![value isKindOfClass:[NSNumber class]] ||
        CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return NO;
    double number = [value doubleValue];
    NSInteger integer = [value integerValue];
    if (number < (double)minimum || number != (double)integer) return NO;
    if (result) *result = integer;
    return YES;
}

static NSString *PXIOSDBVersionString(id value) {
    if ([value isKindOfClass:[NSString class]]) {
        NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        return trimmed.length ? trimmed : nil;
    }
    if ([value isKindOfClass:[NSNumber class]] &&
        CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) return [value stringValue];
    return nil;
}

static NSString *PXIOSDBSafeRelativePath(id value) {
    if (![value isKindOfClass:[NSString class]] || ![value length]) return nil;
    NSString *path = [(NSString *)value stringByStandardizingPath];
    if ([path isAbsolutePath] || [path isEqualToString:@"."] || [path isEqualToString:@".."] ||
        [path hasPrefix:@"../"] || [path rangeOfString:@"/../"].location != NSNotFound ||
        [path rangeOfString:@"\\"].location != NSNotFound) return nil;
    return path;
}

static BOOL PXIOSDBValidateCoherentRoots(NSDictionary<NSString *, NSDictionary *> *roots, NSError **error) {
    NSDictionary *buildRoot = roots[@"iosBuildDB"];
    NSDictionary *modelRoot = roots[@"iphoneModelDB"];
    NSDictionary *buildToMeta = [buildRoot[@"buildToMeta"] isKindOfClass:[NSDictionary class]] ? buildRoot[@"buildToMeta"] : nil;
    NSDictionary *deviceToBuilds = [buildRoot[@"deviceToBuilds"] isKindOfClass:[NSDictionary class]] ? buildRoot[@"deviceToBuilds"] : nil;
    NSArray *models = [modelRoot[@"models"] isKindOfClass:[NSArray class]] ? modelRoot[@"models"] : nil;
    if (!buildToMeta.count || !deviceToBuilds.count || !models.count) {
        if (error) *error = PXIOSDBError(12, @"iOS database set is missing required payloads");
        return NO;
    }

    NSMutableSet<NSString *> *productTypes = [NSMutableSet set];
    for (id item in models) {
        if (![item isKindOfClass:[NSDictionary class]]) {
            if (error) *error = PXIOSDBError(13, @"iPhone model database contains a non-dictionary row");
            return NO;
        }
        NSString *productType = item[@"productType"];
        if (![productType isKindOfClass:[NSString class]] || ![productType hasPrefix:@"iPhone"] ||
            [productTypes containsObject:productType]) {
            if (error) *error = PXIOSDBError(14, @"iPhone model database contains an invalid or duplicate productType");
            return NO;
        }
        [productTypes addObject:productType];
    }

    for (id productType in deviceToBuilds) {
        NSArray *builds = [productType isKindOfClass:[NSString class]] && [deviceToBuilds[productType] isKindOfClass:[NSArray class]] ? deviceToBuilds[productType] : nil;
        if (!builds.count || ![productTypes containsObject:productType]) {
            if (error) *error = PXIOSDBError(15, @"Build database references an unknown device or empty build list");
            return NO;
        }
        for (id build in builds) {
            NSDictionary *meta = [build isKindOfClass:[NSString class]] && [buildToMeta[build] isKindOfClass:[NSDictionary class]] ? buildToMeta[build] : nil;
            if (!meta || ![meta[@"version"] isKindOfClass:[NSString class]] ||
                ![meta[@"darwin"] isKindOfClass:[NSString class]] ||
                ![meta[@"xnu"] isKindOfClass:[NSString class]] ||
                ![meta[@"kernel_version"] isKindOfClass:[NSString class]]) {
                if (error) *error = PXIOSDBError(16, @"Build database contains a dangling or malformed build reference");
                return NO;
            }
        }
    }
    return YES;
}

@interface PXVersionedIOSDatabase ()
@property (nonatomic, copy, readwrite) NSString *databaseVersion;
@property (nonatomic, copy, readwrite) NSString *sourcePath;
@property (nonatomic, copy, readwrite) NSDictionary *metadata;
@property (nonatomic, assign, readwrite, getter=isLegacy) BOOL legacy;
@property (nonatomic, copy) NSDictionary<NSString *, NSDictionary *> *roots;
@property (nonatomic, copy) NSString *highestDatabaseVersion;
@end

@implementation PXVersionedIOSDatabase

+ (instancetype)sharedDatabase {
    static PXVersionedIOSDatabase *database;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ database = [[self alloc] init]; });
    return database;
}

- (BOOL)publishManifestAtPath:(NSString *)manifestPath error:(NSError **)error {
    NSError *localError = nil;
    NSDictionary *manifest = PXIOSDBReadJSON(manifestPath, &localError);
    if (!manifest) {
        if (error) *error = localError;
        return NO;
    }

    NSInteger schemaVersion = 0;
    NSInteger minimumReader = 1;
    if (!PXIOSDBExactInteger(manifest[@"schemaVersion"], 1, &schemaVersion) || schemaVersion != 1) {
        if (error) *error = PXIOSDBError(3, @"Unsupported iOS database manifest schemaVersion");
        return NO;
    }
    id minimumValue = manifest[@"minimumReaderVersion"];
    if (minimumValue && !PXIOSDBExactInteger(minimumValue, 1, &minimumReader)) {
        if (error) *error = PXIOSDBError(4, @"Invalid minimumReaderVersion");
        return NO;
    }
    if (minimumReader > PXVersionedIOSDatabaseReaderVersion) {
        if (error) *error = PXIOSDBError(5, @"iOS database requires a newer reader");
        return NO;
    }

    NSString *databaseVersion = PXIOSDBVersionString(manifest[@"databaseVersion"]);
    NSString *generatedAt = PXIOSDBVersionString(manifest[@"generatedAt"]);
    NSDictionary *files = [manifest[@"files"] isKindOfClass:[NSDictionary class]] ? manifest[@"files"] : nil;
    if (!databaseVersion || !generatedAt || !files) {
        if (error) *error = PXIOSDBError(6, @"Manifest is missing databaseVersion, generatedAt, or files");
        return NO;
    }
    if (self.highestDatabaseVersion &&
        [databaseVersion compare:self.highestDatabaseVersion options:NSNumericSearch] == NSOrderedAscending) {
        if (error) *error = PXIOSDBError(18, @"Refusing iOS database downgrade");
        return NO;
    }

    NSString *basePath = [manifestPath stringByDeletingLastPathComponent];
    NSMutableDictionary *candidateRoots = [NSMutableDictionary dictionaryWithCapacity:2];
    NSMutableDictionary *resolvedFiles = [NSMutableDictionary dictionaryWithCapacity:2];
    for (NSString *key in @[@"iosBuildDB", @"iphoneModelDB"]) {
        NSDictionary *entry = [files[key] isKindOfClass:[NSDictionary class]] ? files[key] : nil;
        NSString *relativePath = PXIOSDBSafeRelativePath(entry[@"path"]);
        if (!entry || !relativePath) {
            if (error) *error = PXIOSDBError(7, [NSString stringWithFormat:@"Invalid manifest file entry: %@", key]);
            return NO;
        }
        NSString *path = [basePath stringByAppendingPathComponent:relativePath];
        NSDictionary *root = PXIOSDBReadJSON(path, &localError);
        if (!root) {
            if (error) *error = localError ?: PXIOSDBError(8, [NSString stringWithFormat:@"Cannot load %@", key]);
            return NO;
        }
        NSInteger fileSchema = 0;
        if (!PXIOSDBExactInteger(root[@"schemaVersion"], 1, &fileSchema) || fileSchema != 1) {
            if (error) *error = PXIOSDBError(9, [NSString stringWithFormat:@"Unsupported schemaVersion in %@", key]);
            return NO;
        }
        NSString *fileVersion = PXIOSDBVersionString(root[@"databaseVersion"]);
        if (fileVersion && ![fileVersion isEqualToString:databaseVersion]) {
            if (error) *error = PXIOSDBError(17, [NSString stringWithFormat:@"databaseVersion mismatch in %@", key]);
            return NO;
        }
        NSString *expectedHash = [entry[@"sha256"] isKindOfClass:[NSString class]] ? [entry[@"sha256"] lowercaseString] : nil;
        NSCharacterSet *nonHex = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet];
        if (expectedHash.length != 64 || [expectedHash rangeOfCharacterFromSet:nonHex].location != NSNotFound) {
            if (error) *error = PXIOSDBError(19, [NSString stringWithFormat:@"Missing or invalid SHA-256 for %@", key]);
            return NO;
        }
        NSString *actualHash = PXIOSDBSHA256(path, &localError);
        if (!actualHash || ![actualHash isEqualToString:expectedHash]) {
            if (error) *error = localError ?: PXIOSDBError(10, [NSString stringWithFormat:@"SHA-256 mismatch for %@", key]);
            return NO;
        }
        candidateRoots[key] = root;
        resolvedFiles[key] = @{ @"path": path, @"sha256": expectedHash };
    }

    if (!PXIOSDBValidateCoherentRoots(candidateRoots, error)) return NO;

    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    metadata[@"schemaVersion"] = @(schemaVersion);
    metadata[@"databaseVersion"] = databaseVersion;
    metadata[@"minimumReaderVersion"] = @(minimumReader);
    metadata[@"readerVersion"] = @(PXVersionedIOSDatabaseReaderVersion);
    metadata[@"manifestPath"] = manifestPath;
    metadata[@"files"] = [resolvedFiles copy];
    metadata[@"legacy"] = @NO;
    if ([manifest[@"generatedAt"] isKindOfClass:[NSString class]]) metadata[@"generatedAt"] = manifest[@"generatedAt"];

    self.roots = [candidateRoots copy];
    self.databaseVersion = databaseVersion;
    self.sourcePath = manifestPath;
    self.metadata = [metadata copy];
    self.legacy = NO;
    self.highestDatabaseVersion = databaseVersion;
    PXDBLog(@"VersionedIOSDB: published version=%@ manifest=%@", databaseVersion, manifestPath);
    return YES;
}

- (BOOL)publishLegacyFromDataPath:(NSString *)dataPath error:(NSError **)error {
    if (self.highestDatabaseVersion) {
        if (error) *error = PXIOSDBError(18, @"Refusing fallback from a versioned database to legacy-v1");
        return NO;
    }
    NSError *localError = nil;
    NSString *buildPath = [dataPath stringByAppendingPathComponent:@"ios_build_db.json"];
    NSString *modelPath = [dataPath stringByAppendingPathComponent:@"iphone_model_db.json"];
    NSDictionary *buildRoot = PXIOSDBReadJSON(buildPath, &localError);
    NSDictionary *modelRoot = PXIOSDBReadJSON(modelPath, &localError);
    if (!buildRoot || !modelRoot) {
        if (error) *error = localError ?: PXIOSDBError(1, @"Legacy iOS database files not found");
        return NO;
    }
    NSInteger buildSchema = 0, modelSchema = 0;
    if (!PXIOSDBExactInteger(buildRoot[@"schemaVersion"], 1, &buildSchema) || buildSchema != 1 ||
        !PXIOSDBExactInteger(modelRoot[@"schemaVersion"], 1, &modelSchema) || modelSchema != 1) {
        if (error) *error = PXIOSDBError(9, @"Unsupported legacy iOS database schemaVersion");
        return NO;
    }
    NSDictionary *legacyRoots = @{ @"iosBuildDB": buildRoot, @"iphoneModelDB": modelRoot };
    self.roots = legacyRoots;
    self.databaseVersion = @"legacy-v1";
    self.sourcePath = dataPath;
    self.metadata = @{
        @"schemaVersion": @1,
        @"databaseVersion": @"legacy-v1",
        @"readerVersion": @(PXVersionedIOSDatabaseReaderVersion),
        @"legacy": @YES,
        @"files": @{ @"iosBuildDB": buildPath, @"iphoneModelDB": modelPath }
    };
    self.legacy = YES;
    PXDBLog(@"VersionedIOSDB: published legacy database path=%@", dataPath);
    return YES;
}

- (BOOL)loadIfNeeded:(NSError **)error {
    @synchronized (self) {
        if (self.roots) return YES;
        NSArray *dataPaths = @[
            @"/var/mobile/Library/WeaponX/Data",
            @"/private/var/mobile/Library/WeaponX/Data"
        ];
        NSError *lastError = nil;
        BOOL foundManifest = NO;
        for (NSString *dataPath in dataPaths) {
            NSString *manifestPath = [dataPath stringByAppendingPathComponent:@"ios_database_manifest.json"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:manifestPath]) {
                foundManifest = YES;
                if ([self publishManifestAtPath:manifestPath error:&lastError]) return YES;
            }
        }
        // A present but invalid manifest must fail closed; never silently mix it
        // with legacy files from a different database generation.
        if (foundManifest) {
            if (error) *error = lastError;
            PXDBLog(@"VersionedIOSDB: manifest rejected err=%@", lastError.localizedDescription ?: @"nil");
            return NO;
        }
        for (NSString *dataPath in dataPaths) {
            if ([self publishLegacyFromDataPath:dataPath error:&lastError]) return YES;
        }
        if (error) *error = lastError ?: PXIOSDBError(1, @"iOS database not found");
        return NO;
    }
}

- (NSDictionary *)rootForKey:(NSString *)key error:(NSError **)error {
    if (![self loadIfNeeded:error]) return nil;
    @synchronized (self) {
        NSDictionary *root = self.roots[key];
        if (!root && error) *error = PXIOSDBError(11, [NSString stringWithFormat:@"Unknown database key: %@", key ?: @"nil"]);
        return root;
    }
}

- (NSDictionary *)metadata {
    @synchronized (self) { return [_metadata copy] ?: @{}; }
}

- (BOOL)reload:(NSError **)error {
    @synchronized (self) {
        NSDictionary *oldRoots = self.roots;
        NSString *oldVersion = self.databaseVersion;
        NSString *oldSourcePath = self.sourcePath;
        NSDictionary *oldMetadata = self.metadata;
        BOOL oldLegacy = self.legacy;

        self.roots = nil;
        self.databaseVersion = nil;
        self.sourcePath = nil;
        _metadata = @{};
        self.legacy = NO;
        if ([self loadIfNeeded:error]) return YES;

        // Candidate failed: restore the exact last-known-good publication.
        self.roots = oldRoots;
        self.databaseVersion = oldVersion;
        self.sourcePath = oldSourcePath;
        _metadata = oldMetadata ?: @{};
        self.legacy = oldLegacy;
        PXDBLog(@"VersionedIOSDB: reload rejected; retained version=%@", oldVersion ?: @"none");
        return NO;
    }
}

- (void)invalidate {
    @synchronized (self) {
        self.roots = nil;
        self.databaseVersion = nil;
        self.sourcePath = nil;
        _metadata = @{};
        self.legacy = NO;
    }
}

@end
