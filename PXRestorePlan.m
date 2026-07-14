#import "PXRestorePlan.h"
#import "PXResolvedContainer.h"
#import "PXBackupArtifactVerifier.h"
#import "PXBackupArchiveValidator.h"

NSString * const PXRestorePlanErrorDomain = @"PXRestorePlanErrorDomain";
NSString * const PXRestorePlanErrorFieldPathKey = @"PXRestorePlanErrorFieldPathKey";

static const NSUInteger PXRestorePlanMaximumItemRecords = 100000;

static BOOL PXRestorePlanFail(NSError **error,
                              PXRestorePlanErrorCode code,
                              NSString *fieldPath,
                              NSString *description) {
    if (error) {
        *error = [NSError errorWithDomain:PXRestorePlanErrorDomain
                                     code:code
                                 userInfo:@{
                                     NSLocalizedDescriptionKey: description,
                                     PXRestorePlanErrorFieldPathKey: fieldPath
                                 }];
    }
    return NO;
}

static BOOL PXRestorePlanStringIsNULFree(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }
    NSString *string = (NSString *)value;
    for (NSUInteger index = 0; index < string.length; index++) {
        if ([string characterAtIndex:index] == 0) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXRestorePlanStringIsNonemptyAndNULFree(id value) {
    return PXRestorePlanStringIsNULFree(value) && [(NSString *)value length] > 0;
}

static BOOL PXRestorePlanStringContainsASCIIControlCharacter(NSString *string) {
    for (NSUInteger index = 0; index < string.length; index++) {
        unichar character = [string characterAtIndex:index];
        if (character < 0x20 || character == 0x7f) {
            return YES;
        }
    }
    return NO;
}

static BOOL PXRestorePlanStringContainsControlCharacter(NSString *string) {
    return [string rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound;
}

static BOOL PXRestorePlanStringIsAllWhitespace(NSString *string) {
    NSCharacterSet *nonWhitespace = [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
    return [string rangeOfCharacterFromSet:nonWhitespace].location == NSNotFound;
}

static NSUInteger PXRestorePlanUTF8Length(NSString *string, BOOL *valid) {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if (!data) {
        if (valid) {
            *valid = NO;
        }
        return 0;
    }
    if (valid) {
        *valid = YES;
    }
    return data.length;
}

static BOOL PXRestorePlanReadExactBoolean(id value, BOOL *result) {
    if (![value isKindOfClass:[NSNumber class]] ||
        CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) {
        return NO;
    }
    if (result) {
        *result = [(NSNumber *)value boolValue];
    }
    return YES;
}

static NSString *PXRestorePlanIndexedFieldPath(NSString *base, NSUInteger index, NSString *field) {
    return [NSString stringWithFormat:@"%@[%lu].%@", base, (unsigned long)index, field];
}

static NSString *PXRestorePlanVerifiedSource(NSString *artifactName,
                                             NSString *fieldPath,
                                             PXVerifiedBackupArtifactSet *verifiedArtifacts,
                                             NSError **error) {
    if (!PXRestorePlanStringIsNonemptyAndNULFree(artifactName)) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInvalidComponent,
                          fieldPath,
                          @"Restore component contains an invalid artifact name.");
        return nil;
    }

    NSString *sourcePath = [verifiedArtifacts pathForArtifactName:artifactName];
    if (!PXRestorePlanStringIsNonemptyAndNULFree(sourcePath)) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorMissingArtifact,
                          fieldPath,
                          @"Restore component is missing from the verified artifact snapshot.");
        return nil;
    }
    return [sourcePath copy];
}

static NSString *PXRestorePlanVerifiedTarSource(NSString *artifactName,
                                                NSString *fieldPath,
                                                PXVerifiedBackupArtifactSet *verifiedArtifacts,
                                                PXValidatedBackupArchiveSet *validatedArchives,
                                                NSError **error) {
    NSString *sourcePath = PXRestorePlanVerifiedSource(artifactName,
                                                        fieldPath,
                                                        verifiedArtifacts,
                                                        error);
    if (!sourcePath) {
        return nil;
    }
    if (![validatedArchives containsArchiveName:artifactName]) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorUnvalidatedArchive,
                          fieldPath,
                          @"Restore archive is missing from the validated archive snapshot.");
        return nil;
    }
    return sourcePath;
}

static BOOL PXRestorePlanValidateSystemSubdirectory(id value,
                                                    NSString *fieldPath,
                                                    NSError **error) {
    if (!PXRestorePlanStringIsNonemptyAndNULFree(value)) {
        return PXRestorePlanFail(error,
                                 PXRestorePlanErrorUnsafeRelativeDestination,
                                 fieldPath,
                                 @"System-global destination identity is invalid.");
    }

    NSString *subdirectory = (NSString *)value;
    if (PXRestorePlanStringIsAllWhitespace(subdirectory) ||
        PXRestorePlanStringContainsASCIIControlCharacter(subdirectory) ||
        [subdirectory rangeOfString:@"/"].location != NSNotFound ||
        [subdirectory rangeOfString:@"\\"].location != NSNotFound ||
        [subdirectory isEqualToString:@"."] ||
        [subdirectory isEqualToString:@".."]) {
        return PXRestorePlanFail(error,
                                 PXRestorePlanErrorUnsafeRelativeDestination,
                                 fieldPath,
                                 @"System-global destination identity is unsafe.");
    }

    BOOL validUTF8 = NO;
    NSUInteger byteLength = PXRestorePlanUTF8Length(subdirectory, &validUTF8);
    if (!validUTF8 || byteLength > 255) {
        return PXRestorePlanFail(error,
                                 PXRestorePlanErrorUnsafeRelativeDestination,
                                 fieldPath,
                                 @"System-global destination identity exceeds its safe UTF-8 length.");
    }
    return YES;
}

static BOOL PXRestorePlanValidateSharedRelativePath(id value,
                                                    NSString *fieldPath,
                                                    NSError **error) {
    if (!PXRestorePlanStringIsNonemptyAndNULFree(value)) {
        return PXRestorePlanFail(error,
                                 PXRestorePlanErrorUnsafeRelativeDestination,
                                 fieldPath,
                                 @"Shared database destination identity is invalid.");
    }

    NSString *relativePath = (NSString *)value;
    if (PXRestorePlanStringIsAllWhitespace(relativePath) ||
        PXRestorePlanStringContainsControlCharacter(relativePath) ||
        [relativePath hasPrefix:@"/"] ||
        [relativePath hasSuffix:@"/"] ||
        [relativePath rangeOfString:@"//"].location != NSNotFound ||
        [relativePath rangeOfString:@"\\"].location != NSNotFound) {
        return PXRestorePlanFail(error,
                                 PXRestorePlanErrorUnsafeRelativeDestination,
                                 fieldPath,
                                 @"Shared database destination identity is unsafe.");
    }

    BOOL validUTF8 = NO;
    NSUInteger fullByteLength = PXRestorePlanUTF8Length(relativePath, &validUTF8);
    if (!validUTF8 || fullByteLength > 4096) {
        return PXRestorePlanFail(error,
                                 PXRestorePlanErrorUnsafeRelativeDestination,
                                 fieldPath,
                                 @"Shared database destination identity exceeds its safe UTF-8 length.");
    }

    NSArray<NSString *> *components = [relativePath componentsSeparatedByString:@"/"];
    for (NSString *component in components) {
        if (component.length == 0 ||
            [component isEqualToString:@"."] ||
            [component isEqualToString:@".."]) {
            return PXRestorePlanFail(error,
                                     PXRestorePlanErrorUnsafeRelativeDestination,
                                     fieldPath,
                                     @"Shared database destination identity contains an unsafe component.");
        }
        BOOL componentValidUTF8 = NO;
        NSUInteger componentByteLength = PXRestorePlanUTF8Length(component, &componentValidUTF8);
        if (!componentValidUTF8 || componentByteLength > 255) {
            return PXRestorePlanFail(error,
                                     PXRestorePlanErrorUnsafeRelativeDestination,
                                     fieldPath,
                                     @"Shared database destination component exceeds its safe UTF-8 length.");
        }
    }
    return YES;
}

static BOOL PXRestorePlanAddRecordCount(NSUInteger count,
                                        NSUInteger *total,
                                        NSString *fieldPath,
                                        NSError **error) {
    if (!total || *total > PXRestorePlanMaximumItemRecords ||
        count > PXRestorePlanMaximumItemRecords - *total) {
        return PXRestorePlanFail(error,
                                 PXRestorePlanErrorLimitExceeded,
                                 fieldPath,
                                 @"Restore plan contains too many item records.");
    }
    *total += count;
    return YES;
}

@interface PXRestorePlanAppGroupItem ()
- (instancetype)initWithGroupIdentifier:(NSString *)groupIdentifier
                             archiveName:(NSString *)archiveName
                              sourcePath:(NSString *)sourcePath;
@end

@implementation PXRestorePlanAppGroupItem

- (instancetype)initWithGroupIdentifier:(NSString *)groupIdentifier
                             archiveName:(NSString *)archiveName
                              sourcePath:(NSString *)sourcePath {
    self = [super init];
    if (self) {
        _groupIdentifier = [groupIdentifier copy];
        _archiveName = [archiveName copy];
        _sourcePath = [sourcePath copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end

@interface PXRestorePlanSystemGlobalItem ()
- (instancetype)initWithLibrarySubdirectory:(NSString *)librarySubdirectory
                                 archiveName:(NSString *)archiveName
                                  sourcePath:(NSString *)sourcePath;
@end

@implementation PXRestorePlanSystemGlobalItem

- (instancetype)initWithLibrarySubdirectory:(NSString *)librarySubdirectory
                                 archiveName:(NSString *)archiveName
                                  sourcePath:(NSString *)sourcePath {
    self = [super init];
    if (self) {
        _librarySubdirectory = [librarySubdirectory copy];
        _archiveName = [archiveName copy];
        _sourcePath = [sourcePath copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end

@interface PXRestorePlanSharedDatabaseItem ()
- (instancetype)initWithLibraryRelativePath:(NSString *)libraryRelativePath
                                artifactName:(NSString *)artifactName
                                 sourcePath:(NSString *)sourcePath;
@end

@implementation PXRestorePlanSharedDatabaseItem

- (instancetype)initWithLibraryRelativePath:(NSString *)libraryRelativePath
                                artifactName:(NSString *)artifactName
                                  sourcePath:(NSString *)sourcePath {
    self = [super init];
    if (self) {
        _libraryRelativePath = [libraryRelativePath copy];
        _artifactName = [artifactName copy];
        _sourcePath = [sourcePath copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end

@interface PXRestorePlan ()
@property (nonatomic, copy, readonly) NSDictionary<NSString *, PXRestorePlanAppGroupItem *> *appGroupItemsByIdentifier;

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                applicationDataContainer:(PXResolvedContainer *)applicationDataContainer
                     applicationDataPath:(NSString *)applicationDataPath
                     applicationDataUUID:(NSString *)applicationDataUUID
                         dataArchiveName:(NSString *)dataArchiveName
                         dataArchivePath:(NSString *)dataArchivePath
                       includesAppGroups:(BOOL)includesAppGroups
                          appGroupItems:(NSArray<PXRestorePlanAppGroupItem *> *)appGroupItems
              appGroupItemsByIdentifier:(NSDictionary<NSString *, PXRestorePlanAppGroupItem *> *)appGroupItemsByIdentifier
                    includesPreferences:(BOOL)includesPreferences
                 preferencesArtifactName:(NSString * _Nullable)preferencesArtifactName
                 preferencesSourcePath:(NSString * _Nullable)preferencesSourcePath
                       includesKeychain:(BOOL)includesKeychain
                    keychainArtifactName:(NSString * _Nullable)keychainArtifactName
                    keychainSourcePath:(NSString * _Nullable)keychainSourcePath
                         keychainGroups:(NSArray<NSString *> *)keychainGroups
                         keychainMethod:(NSString *)keychainMethod
                keychainUsesInAppMethod:(BOOL)keychainUsesInAppMethod
                 includesProfileAppData:(BOOL)includesProfileAppData
              profileAppDataArchiveName:(NSString * _Nullable)profileAppDataArchiveName
              profileAppDataSourcePath:(NSString * _Nullable)profileAppDataSourcePath
                   includesGlobalSafari:(BOOL)includesGlobalSafari
                globalSafariArchiveName:(NSString * _Nullable)globalSafariArchiveName
                globalSafariSourcePath:(NSString * _Nullable)globalSafariSourcePath
                      systemGlobalItems:(NSArray<PXRestorePlanSystemGlobalItem *> *)systemGlobalItems
                    sharedDatabaseItems:(NSArray<PXRestorePlanSharedDatabaseItem *> *)sharedDatabaseItems
                   manifestWarningCount:(NSUInteger)manifestWarningCount
              manifestProfileIdentifier:(NSString * _Nullable)manifestProfileIdentifier
                      verifiedArtifacts:(PXVerifiedBackupArtifactSet *)verifiedArtifacts
                      validatedArchives:(PXValidatedBackupArchiveSet *)validatedArchives;
@end

@implementation PXRestorePlan

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                applicationDataContainer:(PXResolvedContainer *)applicationDataContainer
                     applicationDataPath:(NSString *)applicationDataPath
                     applicationDataUUID:(NSString *)applicationDataUUID
                         dataArchiveName:(NSString *)dataArchiveName
                         dataArchivePath:(NSString *)dataArchivePath
                       includesAppGroups:(BOOL)includesAppGroups
                          appGroupItems:(NSArray<PXRestorePlanAppGroupItem *> *)appGroupItems
              appGroupItemsByIdentifier:(NSDictionary<NSString *, PXRestorePlanAppGroupItem *> *)appGroupItemsByIdentifier
                    includesPreferences:(BOOL)includesPreferences
                 preferencesArtifactName:(NSString *)preferencesArtifactName
                 preferencesSourcePath:(NSString *)preferencesSourcePath
                       includesKeychain:(BOOL)includesKeychain
                    keychainArtifactName:(NSString *)keychainArtifactName
                    keychainSourcePath:(NSString *)keychainSourcePath
                         keychainGroups:(NSArray<NSString *> *)keychainGroups
                         keychainMethod:(NSString *)keychainMethod
                keychainUsesInAppMethod:(BOOL)keychainUsesInAppMethod
                 includesProfileAppData:(BOOL)includesProfileAppData
              profileAppDataArchiveName:(NSString *)profileAppDataArchiveName
              profileAppDataSourcePath:(NSString *)profileAppDataSourcePath
                   includesGlobalSafari:(BOOL)includesGlobalSafari
                globalSafariArchiveName:(NSString *)globalSafariArchiveName
                globalSafariSourcePath:(NSString *)globalSafariSourcePath
                      systemGlobalItems:(NSArray<PXRestorePlanSystemGlobalItem *> *)systemGlobalItems
                    sharedDatabaseItems:(NSArray<PXRestorePlanSharedDatabaseItem *> *)sharedDatabaseItems
                   manifestWarningCount:(NSUInteger)manifestWarningCount
              manifestProfileIdentifier:(NSString *)manifestProfileIdentifier
                      verifiedArtifacts:(PXVerifiedBackupArtifactSet *)verifiedArtifacts
                      validatedArchives:(PXValidatedBackupArchiveSet *)validatedArchives {
    self = [super init];
    if (self) {
        _bundleIdentifier = [bundleIdentifier copy];
        _applicationDataContainer = applicationDataContainer;
        _applicationDataPath = [applicationDataPath copy];
        _applicationDataUUID = [applicationDataUUID copy];
        _dataArchiveName = [dataArchiveName copy];
        _dataArchivePath = [dataArchivePath copy];
        _includesAppGroups = includesAppGroups;
        _appGroupItems = [appGroupItems copy];
        _appGroupItemsByIdentifier = [appGroupItemsByIdentifier copy];
        _includesPreferences = includesPreferences;
        _preferencesArtifactName = [preferencesArtifactName copy];
        _preferencesSourcePath = [preferencesSourcePath copy];
        _includesKeychain = includesKeychain;
        _keychainArtifactName = [keychainArtifactName copy];
        _keychainSourcePath = [keychainSourcePath copy];
        _keychainGroups = [keychainGroups copy];
        _keychainMethod = [keychainMethod copy];
        _keychainUsesInAppMethod = keychainUsesInAppMethod;
        _includesProfileAppData = includesProfileAppData;
        _profileAppDataArchiveName = [profileAppDataArchiveName copy];
        _profileAppDataSourcePath = [profileAppDataSourcePath copy];
        _includesGlobalSafari = includesGlobalSafari;
        _globalSafariArchiveName = [globalSafariArchiveName copy];
        _globalSafariSourcePath = [globalSafariSourcePath copy];
        _systemGlobalItems = [systemGlobalItems copy];
        _sharedDatabaseItems = [sharedDatabaseItems copy];
        _manifestWarningCount = manifestWarningCount;
        _manifestProfileIdentifier = [manifestProfileIdentifier copy];
        _verifiedArtifacts = verifiedArtifacts;
        _validatedArchives = validatedArchives;
    }
    return self;
}

+ (instancetype)planForManifest:(NSDictionary *)manifest
      requestedBundleIdentifier:(NSString *)bundleIdentifier
        applicationDataContainer:(PXResolvedContainer *)applicationDataContainer
             applicationDataPath:(NSString *)applicationDataPath
               verifiedArtifacts:(PXVerifiedBackupArtifactSet *)verifiedArtifacts
               validatedArchives:(PXValidatedBackupArchiveSet *)validatedArchives
                           error:(NSError **)error {
    if (error) {
        *error = nil;
    }

    if (![manifest isKindOfClass:[NSDictionary class]]) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInvalidInput,
                          @"$",
                          @"Restore plan requires an accepted manifest dictionary.");
        return nil;
    }
    if (!PXRestorePlanStringIsNonemptyAndNULFree(bundleIdentifier)) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInvalidInput,
                          @"$.bundleID",
                          @"Restore plan requires a valid requested bundle identifier.");
        return nil;
    }

    id manifestBundleIdentifier = manifest[@"bundleID"];
    if (!PXRestorePlanStringIsNonemptyAndNULFree(manifestBundleIdentifier) ||
        ![(NSString *)manifestBundleIdentifier isEqualToString:bundleIdentifier]) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInconsistentSnapshot,
                          @"$.bundleID",
                          @"Manifest and requested bundle identity snapshots are inconsistent.");
        return nil;
    }

    if (![applicationDataContainer isKindOfClass:[PXResolvedContainer class]]) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInvalidInput,
                          @"$.applicationDataContainer",
                          @"Restore plan requires an accepted application-data container model.");
        return nil;
    }
    if (applicationDataContainer.kind != PXResolvedContainerKindApplicationData) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInconsistentSnapshot,
                          @"$.applicationDataContainer.kind",
                          @"Application-data container kind is inconsistent.");
        return nil;
    }
    if (![applicationDataContainer.requestedIdentifier isEqualToString:bundleIdentifier]) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInconsistentSnapshot,
                          @"$.applicationDataContainer.requestedIdentifier",
                          @"Application-data requested identity is inconsistent.");
        return nil;
    }
    if (![applicationDataContainer.metadataIdentifier isEqualToString:bundleIdentifier]) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInconsistentSnapshot,
                          @"$.applicationDataContainer.metadataIdentifier",
                          @"Application-data metadata identity is inconsistent.");
        return nil;
    }
    if (!PXRestorePlanStringIsNonemptyAndNULFree(applicationDataContainer.containerPath)) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInconsistentSnapshot,
                          @"$.applicationDataContainer.containerPath",
                          @"Application-data container path snapshot is invalid.");
        return nil;
    }
    if (!PXRestorePlanStringIsNonemptyAndNULFree(applicationDataContainer.containerUUID)) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInconsistentSnapshot,
                          @"$.applicationDataContainer.containerUUID",
                          @"Application-data container UUID snapshot is invalid.");
        return nil;
    }
    if (!PXRestorePlanStringIsNonemptyAndNULFree(applicationDataPath) ||
        ![applicationDataPath isEqualToString:applicationDataContainer.containerPath]) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInconsistentSnapshot,
                          @"$.applicationDataPath",
                          @"Supplied application-data path is inconsistent with the accepted model.");
        return nil;
    }
    if (![verifiedArtifacts isKindOfClass:[PXVerifiedBackupArtifactSet class]]) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInvalidInput,
                          @"$.verifiedArtifacts",
                          @"Restore plan requires an accepted verified artifact snapshot.");
        return nil;
    }
    if (![validatedArchives isKindOfClass:[PXValidatedBackupArchiveSet class]]) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInvalidInput,
                          @"$.validatedArchives",
                          @"Restore plan requires an accepted validated archive snapshot.");
        return nil;
    }

    NSDictionary *dataSection = [manifest[@"data"] isKindOfClass:[NSDictionary class]] ? manifest[@"data"] : nil;
    NSString *dataArchiveName = [dataSection[@"archive"] isKindOfClass:[NSString class]] ? dataSection[@"archive"] : nil;
    NSString *dataArchivePath = PXRestorePlanVerifiedTarSource(dataArchiveName,
                                                               @"$.data.archive",
                                                               verifiedArtifacts,
                                                               validatedArchives,
                                                               error);
    if (!dataArchivePath) {
        return nil;
    }

    NSDictionary *optionsSection = [manifest[@"options"] isKindOfClass:[NSDictionary class]] ? manifest[@"options"] : nil;
    BOOL includesAppGroups = NO;
    if (!optionsSection || !PXRestorePlanReadExactBoolean(optionsSection[@"includeAppGroups"], &includesAppGroups)) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInvalidComponent,
                          @"$.options.includeAppGroups",
                          @"App Group inclusion decision is invalid.");
        return nil;
    }

    NSArray *rawAppGroups = [manifest[@"appGroups"] isKindOfClass:[NSArray class]] ? manifest[@"appGroups"] : nil;
    if (includesAppGroups && !rawAppGroups) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInvalidComponent,
                          @"$.appGroups",
                          @"Included App Group plan requires an item array.");
        return nil;
    }

    NSDictionary *preferencesSection = [manifest[@"preferences"] isKindOfClass:[NSDictionary class]] ? manifest[@"preferences"] : nil;
    BOOL includesPreferences = NO;
    if (!preferencesSection || !PXRestorePlanReadExactBoolean(preferencesSection[@"included"], &includesPreferences)) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInvalidComponent,
                          @"$.preferences.included",
                          @"Preferences inclusion decision is invalid.");
        return nil;
    }

    NSDictionary *keychainSection = [manifest[@"keychain"] isKindOfClass:[NSDictionary class]] ? manifest[@"keychain"] : nil;
    BOOL includesKeychain = NO;
    if (!keychainSection || !PXRestorePlanReadExactBoolean(keychainSection[@"included"], &includesKeychain)) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInvalidComponent,
                          @"$.keychain.included",
                          @"Keychain inclusion decision is invalid.");
        return nil;
    }

    NSDictionary *profileSection = [manifest[@"profileAppData"] isKindOfClass:[NSDictionary class]] ? manifest[@"profileAppData"] : nil;
    BOOL includesProfileAppData = NO;
    if (!profileSection || !PXRestorePlanReadExactBoolean(profileSection[@"included"], &includesProfileAppData)) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInvalidComponent,
                          @"$.profileAppData.included",
                          @"Profile AppData inclusion decision is invalid.");
        return nil;
    }

    NSDictionary *globalSafariSection = [manifest[@"globalSafari"] isKindOfClass:[NSDictionary class]] ? manifest[@"globalSafari"] : nil;
    BOOL includesGlobalSafari = NO;
    if (!globalSafariSection || !PXRestorePlanReadExactBoolean(globalSafariSection[@"included"], &includesGlobalSafari)) {
        PXRestorePlanFail(error,
                          PXRestorePlanErrorInvalidComponent,
                          @"$.globalSafari.included",
                          @"Global Safari inclusion decision is invalid.");
        return nil;
    }

    NSDictionary *systemGlobalSection = nil;
    NSArray *rawSystemGlobalItems = nil;
    BOOL includesSystemGlobal = NO;
    id rawSystemGlobalSection = manifest[@"systemGlobalLibrary"];
    if (rawSystemGlobalSection) {
        if (![rawSystemGlobalSection isKindOfClass:[NSDictionary class]]) {
            PXRestorePlanFail(error,
                              PXRestorePlanErrorInvalidComponent,
                              @"$.systemGlobalLibrary",
                              @"System-global section is invalid.");
            return nil;
        }
        systemGlobalSection = (NSDictionary *)rawSystemGlobalSection;
        if (!PXRestorePlanReadExactBoolean(systemGlobalSection[@"included"], &includesSystemGlobal)) {
            PXRestorePlanFail(error,
                              PXRestorePlanErrorInvalidComponent,
                              @"$.systemGlobalLibrary.included",
                              @"System-global inclusion decision is invalid.");
            return nil;
        }
        if (includesSystemGlobal) {
            rawSystemGlobalItems = [systemGlobalSection[@"items"] isKindOfClass:[NSArray class]] ? systemGlobalSection[@"items"] : nil;
            if (!rawSystemGlobalItems) {
                PXRestorePlanFail(error,
                                  PXRestorePlanErrorInvalidComponent,
                                  @"$.systemGlobalLibrary.items",
                                  @"Included system-global plan requires an item array.");
                return nil;
            }
        }
    }

    NSDictionary *sharedDatabaseSection = nil;
    NSArray *rawSharedDatabaseItems = nil;
    BOOL includesSharedDatabase = NO;
    id rawSharedDatabaseSection = manifest[@"sharedSystemDB"];
    if (rawSharedDatabaseSection) {
        if (![rawSharedDatabaseSection isKindOfClass:[NSDictionary class]]) {
            PXRestorePlanFail(error,
                              PXRestorePlanErrorInvalidComponent,
                              @"$.sharedSystemDB",
                              @"Shared database section is invalid.");
            return nil;
        }
        sharedDatabaseSection = (NSDictionary *)rawSharedDatabaseSection;
        if (!PXRestorePlanReadExactBoolean(sharedDatabaseSection[@"included"], &includesSharedDatabase)) {
            PXRestorePlanFail(error,
                              PXRestorePlanErrorInvalidComponent,
                              @"$.sharedSystemDB.included",
                              @"Shared database inclusion decision is invalid.");
            return nil;
        }
        if (includesSharedDatabase) {
            rawSharedDatabaseItems = [sharedDatabaseSection[@"files"] isKindOfClass:[NSArray class]] ? sharedDatabaseSection[@"files"] : nil;
            if (!rawSharedDatabaseItems) {
                PXRestorePlanFail(error,
                                  PXRestorePlanErrorInvalidComponent,
                                  @"$.sharedSystemDB.files",
                                  @"Included shared database plan requires a file array.");
                return nil;
            }
        }
    }

    NSUInteger totalItemRecords = 0;
    if (!PXRestorePlanAddRecordCount(includesAppGroups ? rawAppGroups.count : 0,
                                     &totalItemRecords,
                                     @"$.appGroups",
                                     error) ||
        !PXRestorePlanAddRecordCount(includesSystemGlobal ? rawSystemGlobalItems.count : 0,
                                     &totalItemRecords,
                                     @"$.systemGlobalLibrary.items",
                                     error) ||
        !PXRestorePlanAddRecordCount(includesSharedDatabase ? rawSharedDatabaseItems.count : 0,
                                     &totalItemRecords,
                                     @"$.sharedSystemDB.files",
                                     error)) {
        return nil;
    }

    NSMutableArray<PXRestorePlanAppGroupItem *> *appGroupItemsBuilder = [NSMutableArray array];
    NSMutableDictionary<NSString *, PXRestorePlanAppGroupItem *> *appGroupLookupBuilder = [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *seenGroupIdentifiers = [NSMutableSet set];
    if (includesAppGroups) {
        for (NSUInteger index = 0; index < rawAppGroups.count; index++) {
            id rawEntry = rawAppGroups[index];
            NSString *entryPath = [NSString stringWithFormat:@"$.appGroups[%lu]", (unsigned long)index];
            if (![rawEntry isKindOfClass:[NSDictionary class]]) {
                PXRestorePlanFail(error,
                                  PXRestorePlanErrorInvalidComponent,
                                  entryPath,
                                  @"App Group item is invalid.");
                return nil;
            }
            NSDictionary *entry = (NSDictionary *)rawEntry;
            NSString *groupIdentifier = [entry[@"groupID"] isKindOfClass:[NSString class]] ? entry[@"groupID"] : nil;
            NSString *groupFieldPath = PXRestorePlanIndexedFieldPath(@"$.appGroups", index, @"groupID");
            if (!PXRestorePlanStringIsNonemptyAndNULFree(groupIdentifier)) {
                PXRestorePlanFail(error,
                                  PXRestorePlanErrorInvalidComponent,
                                  groupFieldPath,
                                  @"App Group identifier is invalid.");
                return nil;
            }
            if ([seenGroupIdentifiers containsObject:groupIdentifier]) {
                PXRestorePlanFail(error,
                                  PXRestorePlanErrorDuplicateDestination,
                                  groupFieldPath,
                                  @"App Group identifier is duplicated.");
                return nil;
            }

            NSString *archiveName = [entry[@"archive"] isKindOfClass:[NSString class]] ? entry[@"archive"] : nil;
            NSString *archiveFieldPath = PXRestorePlanIndexedFieldPath(@"$.appGroups", index, @"archive");
            NSString *sourcePath = PXRestorePlanVerifiedTarSource(archiveName,
                                                                  archiveFieldPath,
                                                                  verifiedArtifacts,
                                                                  validatedArchives,
                                                                  error);
            if (!sourcePath) {
                return nil;
            }

            PXRestorePlanAppGroupItem *item = [[PXRestorePlanAppGroupItem alloc]
                initWithGroupIdentifier:groupIdentifier
                            archiveName:archiveName
                             sourcePath:sourcePath];
            [seenGroupIdentifiers addObject:groupIdentifier];
            [appGroupItemsBuilder addObject:item];
            appGroupLookupBuilder[groupIdentifier] = item;
        }
    }

    NSString *preferencesArtifactName = nil;
    NSString *preferencesSourcePath = nil;
    if (includesPreferences) {
        preferencesArtifactName = [preferencesSection[@"archive"] isKindOfClass:[NSString class]] ? preferencesSection[@"archive"] : nil;
        preferencesSourcePath = PXRestorePlanVerifiedSource(preferencesArtifactName,
                                                            @"$.preferences.archive",
                                                            verifiedArtifacts,
                                                            error);
        if (!preferencesSourcePath) {
            return nil;
        }
    }

    NSString *keychainArtifactName = nil;
    NSString *keychainSourcePath = nil;
    NSArray<NSString *> *keychainGroups = @[];
    NSString *keychainMethod = @"";
    BOOL keychainUsesInAppMethod = NO;
    if (includesKeychain) {
        keychainArtifactName = [keychainSection[@"archive"] isKindOfClass:[NSString class]] ? keychainSection[@"archive"] : nil;
        keychainSourcePath = PXRestorePlanVerifiedSource(keychainArtifactName,
                                                         @"$.keychain.archive",
                                                         verifiedArtifacts,
                                                         error);
        if (!keychainSourcePath) {
            return nil;
        }

        id rawGroups = keychainSection[@"groupsSelected"];
        if (![rawGroups isKindOfClass:[NSArray class]]) {
            PXRestorePlanFail(error,
                              PXRestorePlanErrorInvalidComponent,
                              @"$.keychain.groupsSelected",
                              @"Keychain group selection is invalid.");
            return nil;
        }
        NSMutableArray<NSString *> *groupsBuilder = [NSMutableArray arrayWithCapacity:[(NSArray *)rawGroups count]];
        for (NSUInteger index = 0; index < [(NSArray *)rawGroups count]; index++) {
            id rawGroup = ((NSArray *)rawGroups)[index];
            if (!PXRestorePlanStringIsNonemptyAndNULFree(rawGroup)) {
                PXRestorePlanFail(error,
                                  PXRestorePlanErrorInvalidComponent,
                                  @"$.keychain.groupsSelected",
                                  @"Keychain group selection contains an invalid item.");
                return nil;
            }
            NSString *group = (NSString *)rawGroup;
            [groupsBuilder addObject:[group copy]];
            if ([group rangeOfString:@"platformFamily"].location != NSNotFound) {
                keychainUsesInAppMethod = YES;
            }
        }
        keychainGroups = [groupsBuilder copy];

        id rawMethod = keychainSection[@"method"];
        if (rawMethod) {
            if (!PXRestorePlanStringIsNULFree(rawMethod)) {
                PXRestorePlanFail(error,
                                  PXRestorePlanErrorInvalidComponent,
                                  @"$.keychain.method",
                                  @"Keychain restore method is invalid.");
                return nil;
            }
            keychainMethod = [(NSString *)rawMethod copy];
        }
        if ([keychainMethod isEqualToString:@"in_app"]) {
            keychainUsesInAppMethod = YES;
        }
    }

    NSString *profileAppDataArchiveName = nil;
    NSString *profileAppDataSourcePath = nil;
    if (includesProfileAppData) {
        profileAppDataArchiveName = [profileSection[@"archive"] isKindOfClass:[NSString class]] ? profileSection[@"archive"] : nil;
        profileAppDataSourcePath = PXRestorePlanVerifiedTarSource(profileAppDataArchiveName,
                                                                  @"$.profileAppData.archive",
                                                                  verifiedArtifacts,
                                                                  validatedArchives,
                                                                  error);
        if (!profileAppDataSourcePath) {
            return nil;
        }
    }

    NSString *globalSafariArchiveName = nil;
    NSString *globalSafariSourcePath = nil;
    if (includesGlobalSafari) {
        globalSafariArchiveName = [globalSafariSection[@"archive"] isKindOfClass:[NSString class]] ? globalSafariSection[@"archive"] : nil;
        globalSafariSourcePath = PXRestorePlanVerifiedTarSource(globalSafariArchiveName,
                                                                @"$.globalSafari.archive",
                                                                verifiedArtifacts,
                                                                validatedArchives,
                                                                error);
        if (!globalSafariSourcePath) {
            return nil;
        }
    }

    NSMutableArray<PXRestorePlanSystemGlobalItem *> *systemGlobalItemsBuilder = [NSMutableArray array];
    NSMutableSet<NSString *> *seenSystemSubdirectories = [NSMutableSet set];
    if (includesSystemGlobal) {
        for (NSUInteger index = 0; index < rawSystemGlobalItems.count; index++) {
            id rawItem = rawSystemGlobalItems[index];
            NSString *entryPath = [NSString stringWithFormat:@"$.systemGlobalLibrary.items[%lu]", (unsigned long)index];
            if (![rawItem isKindOfClass:[NSDictionary class]]) {
                PXRestorePlanFail(error,
                                  PXRestorePlanErrorInvalidComponent,
                                  entryPath,
                                  @"System-global item is invalid.");
                return nil;
            }
            NSDictionary *itemDictionary = (NSDictionary *)rawItem;
            NSString *subdirectory = [itemDictionary[@"subdir"] isKindOfClass:[NSString class]] ? itemDictionary[@"subdir"] : nil;
            NSString *subdirectoryFieldPath = PXRestorePlanIndexedFieldPath(@"$.systemGlobalLibrary.items", index, @"subdir");
            if (!PXRestorePlanValidateSystemSubdirectory(subdirectory,
                                                         subdirectoryFieldPath,
                                                         error)) {
                return nil;
            }
            if ([seenSystemSubdirectories containsObject:subdirectory]) {
                PXRestorePlanFail(error,
                                  PXRestorePlanErrorDuplicateDestination,
                                  subdirectoryFieldPath,
                                  @"System-global destination identity is duplicated.");
                return nil;
            }

            NSString *archiveName = [itemDictionary[@"archive"] isKindOfClass:[NSString class]] ? itemDictionary[@"archive"] : nil;
            NSString *archiveFieldPath = PXRestorePlanIndexedFieldPath(@"$.systemGlobalLibrary.items", index, @"archive");
            NSString *sourcePath = PXRestorePlanVerifiedTarSource(archiveName,
                                                                  archiveFieldPath,
                                                                  verifiedArtifacts,
                                                                  validatedArchives,
                                                                  error);
            if (!sourcePath) {
                return nil;
            }

            PXRestorePlanSystemGlobalItem *item = [[PXRestorePlanSystemGlobalItem alloc]
                initWithLibrarySubdirectory:subdirectory
                                archiveName:archiveName
                                 sourcePath:sourcePath];
            [seenSystemSubdirectories addObject:subdirectory];
            [systemGlobalItemsBuilder addObject:item];
        }
    }

    NSMutableArray<PXRestorePlanSharedDatabaseItem *> *sharedDatabaseItemsBuilder = [NSMutableArray array];
    NSMutableSet<NSString *> *seenSharedRelativePaths = [NSMutableSet set];
    if (includesSharedDatabase) {
        for (NSUInteger index = 0; index < rawSharedDatabaseItems.count; index++) {
            id rawItem = rawSharedDatabaseItems[index];
            NSString *entryPath = [NSString stringWithFormat:@"$.sharedSystemDB.files[%lu]", (unsigned long)index];
            if (![rawItem isKindOfClass:[NSDictionary class]]) {
                PXRestorePlanFail(error,
                                  PXRestorePlanErrorInvalidComponent,
                                  entryPath,
                                  @"Shared database item is invalid.");
                return nil;
            }
            NSDictionary *itemDictionary = (NSDictionary *)rawItem;
            NSString *relativePath = [itemDictionary[@"libraryRel"] isKindOfClass:[NSString class]] ? itemDictionary[@"libraryRel"] : nil;
            NSString *relativePathFieldPath = PXRestorePlanIndexedFieldPath(@"$.sharedSystemDB.files", index, @"libraryRel");
            if (!PXRestorePlanValidateSharedRelativePath(relativePath,
                                                         relativePathFieldPath,
                                                         error)) {
                return nil;
            }
            if ([seenSharedRelativePaths containsObject:relativePath]) {
                PXRestorePlanFail(error,
                                  PXRestorePlanErrorDuplicateDestination,
                                  relativePathFieldPath,
                                  @"Shared database destination identity is duplicated.");
                return nil;
            }

            NSString *artifactName = [itemDictionary[@"archive"] isKindOfClass:[NSString class]] ? itemDictionary[@"archive"] : nil;
            NSString *artifactFieldPath = PXRestorePlanIndexedFieldPath(@"$.sharedSystemDB.files", index, @"archive");
            NSString *sourcePath = PXRestorePlanVerifiedSource(artifactName,
                                                               artifactFieldPath,
                                                               verifiedArtifacts,
                                                               error);
            if (!sourcePath) {
                return nil;
            }

            PXRestorePlanSharedDatabaseItem *item = [[PXRestorePlanSharedDatabaseItem alloc]
                initWithLibraryRelativePath:relativePath
                               artifactName:artifactName
                                 sourcePath:sourcePath];
            [seenSharedRelativePaths addObject:relativePath];
            [sharedDatabaseItemsBuilder addObject:item];
        }
    }

    NSUInteger manifestWarningCount = 0;
    id rawWarnings = manifest[@"warnings"];
    if (rawWarnings) {
        if (![rawWarnings isKindOfClass:[NSArray class]]) {
            PXRestorePlanFail(error,
                              PXRestorePlanErrorInvalidComponent,
                              @"$.warnings",
                              @"Manifest warning metadata is invalid.");
            return nil;
        }
        manifestWarningCount = [(NSArray *)rawWarnings count];
    }

    NSString *manifestProfileIdentifier = nil;
    id rawProfileIdentifier = manifest[@"profileId"];
    if (rawProfileIdentifier) {
        if (!PXRestorePlanStringIsNULFree(rawProfileIdentifier)) {
            PXRestorePlanFail(error,
                              PXRestorePlanErrorInvalidComponent,
                              @"$.profileId",
                              @"Manifest profile identity is invalid.");
            return nil;
        }
        if ([(NSString *)rawProfileIdentifier length] > 0) {
            manifestProfileIdentifier = [(NSString *)rawProfileIdentifier copy];
        }
    }

    return [[self alloc]
        initWithBundleIdentifier:bundleIdentifier
        applicationDataContainer:applicationDataContainer
        applicationDataPath:applicationDataContainer.containerPath
        applicationDataUUID:applicationDataContainer.containerUUID
        dataArchiveName:dataArchiveName
        dataArchivePath:dataArchivePath
        includesAppGroups:includesAppGroups
        appGroupItems:[appGroupItemsBuilder copy]
        appGroupItemsByIdentifier:[appGroupLookupBuilder copy]
        includesPreferences:includesPreferences
        preferencesArtifactName:preferencesArtifactName
        preferencesSourcePath:preferencesSourcePath
        includesKeychain:includesKeychain
        keychainArtifactName:keychainArtifactName
        keychainSourcePath:keychainSourcePath
        keychainGroups:keychainGroups
        keychainMethod:keychainMethod
        keychainUsesInAppMethod:keychainUsesInAppMethod
        includesProfileAppData:includesProfileAppData
        profileAppDataArchiveName:profileAppDataArchiveName
        profileAppDataSourcePath:profileAppDataSourcePath
        includesGlobalSafari:includesGlobalSafari
        globalSafariArchiveName:globalSafariArchiveName
        globalSafariSourcePath:globalSafariSourcePath
        systemGlobalItems:[systemGlobalItemsBuilder copy]
        sharedDatabaseItems:[sharedDatabaseItemsBuilder copy]
        manifestWarningCount:manifestWarningCount
        manifestProfileIdentifier:manifestProfileIdentifier
        verifiedArtifacts:verifiedArtifacts
        validatedArchives:validatedArchives];
}

- (PXRestorePlanAppGroupItem *)appGroupItemForIdentifier:(NSString *)groupIdentifier {
    if (![groupIdentifier isKindOfClass:[NSString class]] || groupIdentifier.length == 0) {
        return nil;
    }
    return self.appGroupItemsByIdentifier[groupIdentifier];
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end
