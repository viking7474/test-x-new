#import "common/PXUIKitCompat.h"
#import "AppDataBackupRestoreViewController.h"
#import "common/UIButton+SafeConfiguration.h"
#import "AppDataBackupManager.h"
#import "BackupKeychainGroupsViewController.h"
#import <objc/message.h>
#import <CoreFoundation/CoreFoundation.h>

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
@end

static NSString *PXBackupKeychainGroupsKey(NSString *bundleID) {
    return [NSString stringWithFormat:@"dataBackupKeychainGroups_%@", bundleID ?: @""];
}

static NSString * const PXBackupKeychainGroupsSavedNotification = @"com.hydra.tlinkios.backupKeychainGroupsSaved";

typedef NS_ENUM(NSUInteger, PXBackupAlertOutcome) {
    PXBackupAlertOutcomeSuccessful = 1,
    PXBackupAlertOutcomeCompletedWithWarnings = 2,
    PXBackupAlertOutcomeFailed = 3,
};

static BOOL PXBackupResultIsValidForPresentation(PXBackupResult *result) {
    if (![result isKindOfClass:[PXBackupResult class]]) {
        return NO;
    }

    id backupDirectory = result.backupDirectory;
    if (![backupDirectory isKindOfClass:[NSString class]] || [(NSString *)backupDirectory length] == 0) {
        return NO;
    }

    id manifestPath = result.manifestPath;
    if (![manifestPath isKindOfClass:[NSString class]] || [(NSString *)manifestPath length] == 0) {
        return NO;
    }

    id warningsValue = result.warnings;
    if (![warningsValue isKindOfClass:[NSArray class]]) {
        return NO;
    }

    for (id warning in (NSArray *)warningsValue) {
        if (![warning isKindOfClass:[NSString class]] || [(NSString *)warning length] == 0) {
            return NO;
        }
    }

    return YES;
}

static PXBackupAlertOutcome PXBackupAlertOutcomeForResult(PXBackupResult *result, NSError *error) {
    if (error != nil) {
        return PXBackupAlertOutcomeFailed;
    }
    if (!PXBackupResultIsValidForPresentation(result)) {
        return PXBackupAlertOutcomeFailed;
    }
    if (result.warnings.count > 0) {
        return PXBackupAlertOutcomeCompletedWithWarnings;
    }
    return PXBackupAlertOutcomeSuccessful;
}

static NSString *PXBackupAlertTitleForOutcome(PXBackupAlertOutcome outcome) {
    switch (outcome) {
        case PXBackupAlertOutcomeSuccessful:
            return @"Backup Successful";
        case PXBackupAlertOutcomeCompletedWithWarnings:
            return @"Backup Completed with Warnings";
        case PXBackupAlertOutcomeFailed:
        default:
            return @"Backup Failed";
    }
}

@interface AppDataBackupRestoreViewController ()
@property (nonatomic, strong) UILabel *appLabel;
@property (nonatomic, strong) UISwitch *includeGroupsSwitch;
@property (nonatomic, strong) UISwitch *includePrefsSwitch;
@property (nonatomic, strong) UISwitch *includeKeychainSwitch;
@property (nonatomic, strong) UIButton *keychainGroupsButton;

@property (nonatomic, copy) NSString *pendingAlertTitle;
@property (nonatomic, copy) NSString *pendingAlertMessage;
@property (nonatomic, copy) NSString *pendingCopyPath;
@end

typedef NS_OPTIONS(NSUInteger, PXAdvancedDataScope) {
    PXAdvancedDataScopeAppGroups = 1 << 0,
    PXAdvancedDataScopePreferences = 1 << 1,
    PXAdvancedDataScopeKeychain = 1 << 2,
    PXAdvancedDataScopeProfileAppData = 1 << 3,
    PXAdvancedDataScopeGlobalSafari = 1 << 4,
    PXAdvancedDataScopeSystemGlobal = 1 << 5,
    PXAdvancedDataScopeSharedSystemDatabases = 1 << 6,
};

static const PXAdvancedDataScope PXAdvancedDataScopeAll =
    PXAdvancedDataScopeAppGroups |
    PXAdvancedDataScopePreferences |
    PXAdvancedDataScopeKeychain |
    PXAdvancedDataScopeProfileAppData |
    PXAdvancedDataScopeGlobalSafari |
    PXAdvancedDataScopeSystemGlobal |
    PXAdvancedDataScopeSharedSystemDatabases;

static const PXAdvancedDataScope PXAdvancedDataScopePresentationOrder[] = {
    PXAdvancedDataScopeProfileAppData,
    PXAdvancedDataScopeGlobalSafari,
    PXAdvancedDataScopeAppGroups,
    PXAdvancedDataScopeSystemGlobal,
    PXAdvancedDataScopeSharedSystemDatabases,
    PXAdvancedDataScopePreferences,
    PXAdvancedDataScopeKeychain,
};

static NSString *PXAdvancedDataScopeDisplayName(PXAdvancedDataScope scope) {
    switch (scope) {
        case PXAdvancedDataScopeProfileAppData:
            return @"Profile App Data";
        case PXAdvancedDataScopeGlobalSafari:
            return @"Global Safari";
        case PXAdvancedDataScopeAppGroups:
            return @"App Groups";
        case PXAdvancedDataScopeSystemGlobal:
            return @"System Global";
        case PXAdvancedDataScopeSharedSystemDatabases:
            return @"Shared System Databases";
        case PXAdvancedDataScopePreferences:
            return @"Global Preferences";
        case PXAdvancedDataScopeKeychain:
            return @"Keychain";
        default:
            return nil;
    }
}

static NSString *PXAdvancedDataScopeList(PXAdvancedDataScope scopes) {
    if (((NSUInteger)scopes & ~(NSUInteger)PXAdvancedDataScopeAll) != 0) {
        return nil;
    }
    if (scopes == 0) {
        return @"";
    }

    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithCapacity:7];
    NSUInteger scopeCount =
        sizeof(PXAdvancedDataScopePresentationOrder) /
        sizeof(PXAdvancedDataScopePresentationOrder[0]);
    for (NSUInteger index = 0; index < scopeCount; index++) {
        PXAdvancedDataScope scope = PXAdvancedDataScopePresentationOrder[index];
        if ((scopes & scope) == 0) {
            continue;
        }
        NSString *name = PXAdvancedDataScopeDisplayName(scope);
        if (name.length == 0) {
            return nil;
        }
        [lines addObject:[NSString stringWithFormat:@"- %@", name]];
    }
    return [lines componentsJoinedByString:@"\n"];
}

static PXBackupOptions PXKnownDirectBackupOptions(void) {
    return PXBackupOptionIncludeAppGroups |
           PXBackupOptionIncludePreferences |
           PXBackupOptionIncludeKeychain;
}

static BOOL PXBackupOptionsAreKnown(PXBackupOptions options) {
    return ((NSUInteger)options & ~(NSUInteger)PXKnownDirectBackupOptions()) == 0;
}

static PXAdvancedDataScope PXAdvancedDataScopesForBackupOptions(PXBackupOptions options) {
    if (!PXBackupOptionsAreKnown(options)) {
        return (PXAdvancedDataScope)(PXAdvancedDataScopeAll + 1);
    }

    PXAdvancedDataScope scopes = 0;
    if ((options & PXBackupOptionIncludeAppGroups) != 0) {
        scopes |= PXAdvancedDataScopeAppGroups;
    }
    if ((options & PXBackupOptionIncludePreferences) != 0) {
        scopes |= PXAdvancedDataScopePreferences;
    }
    if ((options & PXBackupOptionIncludeKeychain) != 0) {
        scopes |= PXAdvancedDataScopeKeychain;
    }
    return scopes;
}

static BOOL PXReadExactManifestBoolean(id value, BOOL *resultOut) {
    if (resultOut == NULL || value == nil ||
        CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) {
        return NO;
    }
    *resultOut = [(NSNumber *)value boolValue];
    return YES;
}

static BOOL PXReadSupportedManifestVersion(id value, NSUInteger *versionOut) {
    if (versionOut == NULL || ![value isKindOfClass:[NSNumber class]] ||
        CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) {
        return NO;
    }
    double raw = [(NSNumber *)value doubleValue];
    NSUInteger version = [(NSNumber *)value unsignedIntegerValue];
    if (raw != (double)version || version < 2 || version > 5) {
        return NO;
    }
    *versionOut = version;
    return YES;
}

static BOOL PXReadIncludedManifestSection(id value, BOOL *includedOut) {
    if (![value isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    return PXReadExactManifestBoolean([(NSDictionary *)value objectForKey:@"included"],
                                      includedOut);
}

static BOOL PXAdvancedDataScopesForValidatedManifest(NSDictionary *manifest,
                                                     NSString *expectedBundleIdentifier,
                                                     PXAdvancedDataScope *scopesOut) {
    if (scopesOut == NULL ||
        ![manifest isKindOfClass:[NSDictionary class]] ||
        ![expectedBundleIdentifier isKindOfClass:[NSString class]] ||
        expectedBundleIdentifier.length == 0) {
        return NO;
    }

    NSUInteger manifestVersion = 0;
    if (!PXReadSupportedManifestVersion(manifest[@"manifestVersion"], &manifestVersion)) {
        return NO;
    }
    (void)manifestVersion;

    id bundleIdentifierValue = manifest[@"bundleID"];
    if (![bundleIdentifierValue isKindOfClass:[NSString class]] ||
        [(NSString *)bundleIdentifierValue length] == 0 ||
        ![(NSString *)bundleIdentifierValue isEqualToString:expectedBundleIdentifier]) {
        return NO;
    }

    id appGroups = manifest[@"appGroups"];
    if (![appGroups isKindOfClass:[NSArray class]]) {
        return NO;
    }

    BOOL profileIncluded = NO;
    BOOL safariIncluded = NO;
    BOOL preferencesIncluded = NO;
    BOOL keychainIncluded = NO;
    if (!PXReadIncludedManifestSection(manifest[@"profileAppData"], &profileIncluded) ||
        !PXReadIncludedManifestSection(manifest[@"globalSafari"], &safariIncluded) ||
        !PXReadIncludedManifestSection(manifest[@"preferences"], &preferencesIncluded) ||
        !PXReadIncludedManifestSection(manifest[@"keychain"], &keychainIncluded)) {
        return NO;
    }

    BOOL systemIncluded = NO;
    id systemSection = manifest[@"systemGlobalLibrary"];
    if (systemSection != nil) {
        if (![systemSection isKindOfClass:[NSDictionary class]] ||
            !PXReadExactManifestBoolean([(NSDictionary *)systemSection objectForKey:@"included"],
                                        &systemIncluded)) {
            return NO;
        }
        id items = [(NSDictionary *)systemSection objectForKey:@"items"];
        if (![items isKindOfClass:[NSArray class]] ||
            systemIncluded != ([(NSArray *)items count] > 0)) {
            return NO;
        }
    }

    BOOL sharedIncluded = NO;
    id sharedSection = manifest[@"sharedSystemDB"];
    if (sharedSection != nil) {
        if (![sharedSection isKindOfClass:[NSDictionary class]] ||
            !PXReadExactManifestBoolean([(NSDictionary *)sharedSection objectForKey:@"included"],
                                        &sharedIncluded)) {
            return NO;
        }
        id files = [(NSDictionary *)sharedSection objectForKey:@"files"];
        if (![files isKindOfClass:[NSArray class]] ||
            sharedIncluded != ([(NSArray *)files count] > 0)) {
            return NO;
        }
    }

    PXAdvancedDataScope scopes = 0;
    if (profileIncluded) scopes |= PXAdvancedDataScopeProfileAppData;
    if (safariIncluded) scopes |= PXAdvancedDataScopeGlobalSafari;
    if ([(NSArray *)appGroups count] > 0) scopes |= PXAdvancedDataScopeAppGroups;
    if (systemIncluded) scopes |= PXAdvancedDataScopeSystemGlobal;
    if (sharedIncluded) scopes |= PXAdvancedDataScopeSharedSystemDatabases;
    if (preferencesIncluded) scopes |= PXAdvancedDataScopePreferences;
    if (keychainIncluded) scopes |= PXAdvancedDataScopeKeychain;

    *scopesOut = scopes;
    return YES;
}

static NSDictionary *PXImmutableManifestConfirmationSnapshot(NSDictionary *manifest) {
    if (![manifest isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSError *serializationError = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:manifest
                                                               format:NSPropertyListBinaryFormat_v1_0
                                                              options:0
                                                                error:&serializationError];
    if (data.length == 0 || serializationError != nil) {
        return nil;
    }

    NSError *deserializationError = nil;
    id snapshot = [NSPropertyListSerialization propertyListWithData:data
                                                            options:NSPropertyListImmutable
                                                             format:NULL
                                                              error:&deserializationError];
    if (deserializationError != nil || ![snapshot isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    return snapshot;
}

static NSString *PXBackupConfirmationTitle(PXAdvancedDataScope scopes) {
    return scopes == 0 ? @"Confirm Backup" : @"Confirm Advanced Backup";
}

static NSString *PXBackupConfirmationActionTitle(PXAdvancedDataScope scopes) {
    return scopes == 0 ? @"Backup" : @"Back Up Advanced Data";
}

static NSString *PXBackupConfirmationMessage(NSString *application,
                                              PXAdvancedDataScope scopes) {
    if (![application isKindOfClass:[NSString class]] || application.length == 0 ||
        ((NSUInteger)scopes & ~(NSUInteger)PXAdvancedDataScopeAll) != 0) {
        return nil;
    }
    if (scopes == 0) {
        return [NSString stringWithFormat:@"Back up Application Data for %@?", application];
    }
    NSString *scopeList = PXAdvancedDataScopeList(scopes);
    if (scopeList.length == 0) {
        return nil;
    }
    return [NSString stringWithFormat:
        @"Back up Application Data for %@ together with these advanced scopes:\n\n%@\n\n"
        @"Advanced scopes may contain shared or sensitive data. Continue?",
        application,
        scopeList];
}

static NSString *PXRestoreConfirmationTitle(PXAdvancedDataScope scopes) {
    return scopes == 0 ? @"Confirm Restore" : @"Confirm Advanced Restore";
}

static NSString *PXRestoreConfirmationActionTitle(PXAdvancedDataScope scopes) {
    return scopes == 0 ? @"Restore" : @"Restore Advanced Data";
}

static NSString *PXRestoreConfirmationMessage(NSString *application,
                                               PXAdvancedDataScope scopes) {
    if (![application isKindOfClass:[NSString class]] || application.length == 0 ||
        ((NSUInteger)scopes & ~(NSUInteger)PXAdvancedDataScopeAll) != 0) {
        return nil;
    }
    if (scopes == 0) {
        return [NSString stringWithFormat:
            @"Restore Application Data for %@? This replaces the current app data and cannot be undone.",
            application];
    }
    NSString *scopeList = PXAdvancedDataScopeList(scopes);
    if (scopeList.length == 0) {
        return nil;
    }
    return [NSString stringWithFormat:
        @"Restore Application Data for %@ together with these advanced scopes:\n\n%@\n\n"
        @"Advanced scopes may replace shared or sensitive data and can affect other apps or system services. This operation cannot be undone. Continue?",
        application,
        scopeList];
}

static NSString *PXUsableErrorDescription(NSError *error) {
    if (![error isKindOfClass:[NSError class]]) {
        return nil;
    }
    id description = error.localizedDescription;
    if (![description isKindOfClass:[NSString class]] ||
        [(NSString *)description length] == 0) {
        return nil;
    }
    return description;
}

typedef NS_ENUM(NSUInteger, PXRestoreAlertOutcome) {
    PXRestoreAlertOutcomeSuccessful = 1,
    PXRestoreAlertOutcomeCompletedWithWarnings = 2,
    PXRestoreAlertOutcomeCompletedWithComponentFailures = 3,
    PXRestoreAlertOutcomeFailed = 4,
    PXRestoreAlertOutcomeFailedWithCompletedRollback = 5,
    PXRestoreAlertOutcomeFailedWithIncompleteRollback = 6,
};

static BOOL PXRestoreWarningArrayIsValidForPresentation(id value) {
    if (![value isKindOfClass:[NSArray class]]) {
        return NO;
    }
    for (id warning in (NSArray *)value) {
        if (![warning isKindOfClass:[NSString class]] || [(NSString *)warning length] == 0) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXRestoreComponentIsKnownSingleBitForPresentation(PXRestoreComponent component) {
    NSUInteger value = (NSUInteger)component;
    return value != 0 &&
           (value & (value - 1)) == 0 &&
           (value & ~(NSUInteger)PXRestoreComponentAll) == 0;
}

static BOOL PXRestoreRollbackStatusIsKnownForPresentation(PXRestoreRollbackStatus rollbackStatus) {
    switch (rollbackStatus) {
        case PXRestoreRollbackStatusNotPerformed:
        case PXRestoreRollbackStatusCompleted:
        case PXRestoreRollbackStatusIncomplete:
            return YES;
    }
    return NO;
}

static BOOL PXRestoreResultIsValidForPresentation(PXRestoreResult *result) {
    if (result == nil || [result class] != [PXRestoreResult class]) {
        return NO;
    }

    id componentResultsValue = result.componentResults;
    if (![componentResultsValue isKindOfClass:[NSArray class]] ||
        [(NSArray *)componentResultsValue count] != 8) {
        return NO;
    }
    if (!PXRestoreWarningArrayIsValidForPresentation(result.warnings)) {
        return NO;
    }

    PXRestoreComponent requestedComponents = result.requestedComponents;
    if (requestedComponents == 0 ||
        ((NSUInteger)requestedComponents & ~(NSUInteger)PXRestoreComponentAll) != 0 ||
        (requestedComponents & PXRestoreComponentApplicationData) == 0) {
        return NO;
    }

    PXRestoreComponent observedSucceeded = 0;
    PXRestoreComponent observedSkipped = 0;
    PXRestoreComponent observedNotAttempted = 0;
    PXRestoreComponent observedFailed = 0;
    PXRestoreComponent seenComponents = 0;
    BOOL observedIncompleteRollback = NO;

    for (id value in (NSArray *)componentResultsValue) {
        if ([value class] != [PXRestoreComponentResult class]) {
            return NO;
        }
        PXRestoreComponentResult *componentResult = value;
        PXRestoreComponent component = componentResult.component;
        if (!PXRestoreComponentIsKnownSingleBitForPresentation(component) ||
            (seenComponents & component) != 0) {
            return NO;
        }
        seenComponents |= component;

        if (!PXRestoreWarningArrayIsValidForPresentation(componentResult.warnings)) {
            return NO;
        }
        id failure = componentResult.failure;
        if (failure != nil && [failure class] != [PXRestoreFailure class]) {
            return NO;
        }

        BOOL requested = (requestedComponents & component) != 0;
        switch (componentResult.status) {
            case PXRestoreComponentStatusSkipped:
                if (requested ||
                    componentResult.plannedUnitCount != 0 ||
                    componentResult.committedUnitCount != 0 ||
                    componentResult.rollbackStatus != PXRestoreRollbackStatusNotPerformed ||
                    componentResult.warnings.count != 0 ||
                    failure != nil) {
                    return NO;
                }
                observedSkipped |= component;
                break;

            case PXRestoreComponentStatusNotAttempted:
                if (!requested ||
                    componentResult.plannedUnitCount < 1 ||
                    componentResult.committedUnitCount != 0 ||
                    componentResult.rollbackStatus != PXRestoreRollbackStatusNotPerformed ||
                    failure != nil) {
                    return NO;
                }
                observedNotAttempted |= component;
                break;

            case PXRestoreComponentStatusSucceeded:
                if (!requested ||
                    componentResult.plannedUnitCount < 1 ||
                    componentResult.committedUnitCount != componentResult.plannedUnitCount ||
                    componentResult.rollbackStatus != PXRestoreRollbackStatusNotPerformed ||
                    failure != nil) {
                    return NO;
                }
                observedSucceeded |= component;
                break;

            case PXRestoreComponentStatusFailed:
                if (!requested ||
                    componentResult.plannedUnitCount < 1 ||
                    componentResult.committedUnitCount != 0 ||
                    failure == nil ||
                    !PXRestoreRollbackStatusIsKnownForPresentation(componentResult.rollbackStatus)) {
                    return NO;
                }
                observedFailed |= component;
                if (componentResult.rollbackStatus == PXRestoreRollbackStatusIncomplete) {
                    observedIncompleteRollback = YES;
                }
                break;

            default:
                return NO;
        }
    }

    if (seenComponents != PXRestoreComponentAll) {
        return NO;
    }

    PXRestoreComponent succeededComponents = result.succeededComponents;
    PXRestoreComponent skippedComponents = result.skippedComponents;
    PXRestoreComponent notAttemptedComponents = result.notAttemptedComponents;
    PXRestoreComponent failedComponents = result.failedComponents;
    PXRestoreComponent aggregateUnion =
        succeededComponents |
        skippedComponents |
        notAttemptedComponents |
        failedComponents;
    BOOL masksAreKnown =
        (((NSUInteger)succeededComponents & ~(NSUInteger)PXRestoreComponentAll) == 0) &&
        (((NSUInteger)skippedComponents & ~(NSUInteger)PXRestoreComponentAll) == 0) &&
        (((NSUInteger)notAttemptedComponents & ~(NSUInteger)PXRestoreComponentAll) == 0) &&
        (((NSUInteger)failedComponents & ~(NSUInteger)PXRestoreComponentAll) == 0);
    BOOL masksAreDisjoint =
        (succeededComponents & skippedComponents) == 0 &&
        (succeededComponents & notAttemptedComponents) == 0 &&
        (succeededComponents & failedComponents) == 0 &&
        (skippedComponents & notAttemptedComponents) == 0 &&
        (skippedComponents & failedComponents) == 0 &&
        (notAttemptedComponents & failedComponents) == 0;
    PXRestoreComponent expectedSkipped =
        (PXRestoreComponent)((NSUInteger)PXRestoreComponentAll &
                             ~(NSUInteger)requestedComponents);

    if (!masksAreKnown ||
        !masksAreDisjoint ||
        aggregateUnion != PXRestoreComponentAll ||
        succeededComponents != observedSucceeded ||
        skippedComponents != observedSkipped ||
        notAttemptedComponents != observedNotAttempted ||
        failedComponents != observedFailed ||
        requestedComponents != (succeededComponents |
                                notAttemptedComponents |
                                failedComponents) ||
        skippedComponents != expectedSkipped) {
        return NO;
    }

    if (result.hasWarnings != (result.warnings.count > 0) ||
        result.hasFailures != (failedComponents != 0) ||
        result.hasIncompleteRollback != observedIncompleteRollback ||
        result.allRequestedComponentsSucceeded !=
            (succeededComponents == requestedComponents)) {
        return NO;
    }

    return YES;
}

static BOOL PXRestoreResultHasCompletedRollback(PXRestoreResult *result) {
    for (PXRestoreComponentResult *componentResult in result.componentResults) {
        if (componentResult.status == PXRestoreComponentStatusFailed &&
            componentResult.rollbackStatus == PXRestoreRollbackStatusCompleted) {
            return YES;
        }
    }
    return NO;
}

static BOOL PXRestoreResultHasIncompleteRollback(PXRestoreResult *result) {
    for (PXRestoreComponentResult *componentResult in result.componentResults) {
        if (componentResult.status == PXRestoreComponentStatusFailed &&
            componentResult.rollbackStatus == PXRestoreRollbackStatusIncomplete) {
            return YES;
        }
    }
    return NO;
}

static PXRestoreAlertOutcome PXRestoreAlertOutcomeForResult(PXRestoreResult *result,
                                                             NSError *error) {
    BOOL validResult = PXRestoreResultIsValidForPresentation(result);
    if (validResult && PXRestoreResultHasIncompleteRollback(result)) {
        return PXRestoreAlertOutcomeFailedWithIncompleteRollback;
    }
    if (validResult && PXRestoreResultHasCompletedRollback(result)) {
        return PXRestoreAlertOutcomeFailedWithCompletedRollback;
    }
    if (error != nil) {
        return PXRestoreAlertOutcomeFailed;
    }
    if (!validResult) {
        return PXRestoreAlertOutcomeFailed;
    }
    if (result.hasFailures) {
        return PXRestoreAlertOutcomeCompletedWithComponentFailures;
    }
    if (!result.allRequestedComponentsSucceeded) {
        return PXRestoreAlertOutcomeFailed;
    }
    if (result.hasWarnings) {
        return PXRestoreAlertOutcomeCompletedWithWarnings;
    }
    return PXRestoreAlertOutcomeSuccessful;
}

static NSString *PXRestoreAlertTitleForOutcome(PXRestoreAlertOutcome outcome) {
    switch (outcome) {
        case PXRestoreAlertOutcomeSuccessful:
            return @"Restore Successful";
        case PXRestoreAlertOutcomeCompletedWithWarnings:
            return @"Restore Completed with Warnings";
        case PXRestoreAlertOutcomeCompletedWithComponentFailures:
            return @"Restore Completed with Component Failures";
        case PXRestoreAlertOutcomeFailedWithCompletedRollback:
            return @"Restore Failed: Component Rollback Completed";
        case PXRestoreAlertOutcomeFailedWithIncompleteRollback:
            return @"Restore Failed: Rollback Incomplete";
        case PXRestoreAlertOutcomeFailed:
        default:
            return @"Restore Failed";
    }
}

static void PXAppendRestoreWarnings(NSMutableString *message,
                                    NSArray<NSString *> *warnings) {
    if (warnings.count == 0) {
        return;
    }
    [message appendString:@"\n\nWarnings:\n"];
    for (NSString *warning in warnings) {
        [message appendFormat:@"- %@\n", warning];
    }
}

static const PXRestoreComponent PXRestorePresentationComponentOrder[] = {
    PXRestoreComponentApplicationData,
    PXRestoreComponentProfileAppData,
    PXRestoreComponentGlobalSafari,
    PXRestoreComponentAppGroups,
    PXRestoreComponentSystemGlobal,
    PXRestoreComponentSharedSystemDatabases,
    PXRestoreComponentPreferences,
    PXRestoreComponentKeychain,
};

static NSString *PXRestoreComponentDisplayName(PXRestoreComponent component) {
    switch (component) {
        case PXRestoreComponentApplicationData:
            return @"Application Data";
        case PXRestoreComponentProfileAppData:
            return @"Profile App Data";
        case PXRestoreComponentGlobalSafari:
            return @"Global Safari";
        case PXRestoreComponentAppGroups:
            return @"App Groups";
        case PXRestoreComponentSystemGlobal:
            return @"System Global";
        case PXRestoreComponentSharedSystemDatabases:
            return @"Shared System Databases";
        case PXRestoreComponentPreferences:
            return @"Preferences";
        case PXRestoreComponentKeychain:
            return @"Keychain";
        default:
            return nil;
    }
}

static NSString *PXRestoreComponentStatusDisplayName(PXRestoreComponentStatus status) {
    switch (status) {
        case PXRestoreComponentStatusSucceeded:
            return @"Succeeded";
        case PXRestoreComponentStatusSkipped:
            return @"Skipped";
        case PXRestoreComponentStatusNotAttempted:
            return @"Not Attempted";
        case PXRestoreComponentStatusFailed:
            return @"Failed";
        default:
            return nil;
    }
}

static NSString *PXRestoreRollbackDisplayName(PXRestoreRollbackStatus rollbackStatus) {
    switch (rollbackStatus) {
        case PXRestoreRollbackStatusNotPerformed:
            return @"Rollback Not Performed";
        case PXRestoreRollbackStatusCompleted:
            return @"Rollback Completed";
        case PXRestoreRollbackStatusIncomplete:
            return @"Rollback Incomplete";
        default:
            return nil;
    }
}

static NSString *PXRestoreUnitProgressDescription(NSUInteger committedUnitCount,
                                                   NSUInteger plannedUnitCount) {
    NSString *unitLabel = plannedUnitCount == 1 ? @"unit" : @"units";
    return [NSString stringWithFormat:@"%lu/%lu %@",
            (unsigned long)committedUnitCount,
            (unsigned long)plannedUnitCount,
            unitLabel];
}

static NSString *PXRestoreWarningCountDescription(NSUInteger warningCount) {
    if (warningCount == 0) {
        return nil;
    }
    if (warningCount == 1) {
        return @"1 warning";
    }
    return [NSString stringWithFormat:@"%lu warnings", (unsigned long)warningCount];
}

static NSString *PXRestoreComponentResultEntry(PXRestoreComponentResult *componentResult) {
    if ([componentResult class] != [PXRestoreComponentResult class]) {
        return nil;
    }

    NSString *componentName = PXRestoreComponentDisplayName(componentResult.component);
    NSString *statusName = PXRestoreComponentStatusDisplayName(componentResult.status);
    if (componentName.length == 0 || statusName.length == 0) {
        return nil;
    }

    if (componentResult.status == PXRestoreComponentStatusSkipped) {
        return [NSString stringWithFormat:@"- %@: %@", componentName, statusName];
    }

    NSString *unitProgress =
        PXRestoreUnitProgressDescription(componentResult.committedUnitCount,
                                         componentResult.plannedUnitCount);
    if (unitProgress.length == 0) {
        return nil;
    }

    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:unitProgress];
    if (componentResult.status == PXRestoreComponentStatusFailed) {
        NSString *rollbackName = PXRestoreRollbackDisplayName(componentResult.rollbackStatus);
        id failure = componentResult.failure;
        id failureMessage = [failure class] == [PXRestoreFailure class]
            ? [(PXRestoreFailure *)failure message]
            : nil;
        if (rollbackName.length == 0 ||
            ![failureMessage isKindOfClass:[NSString class]] ||
            [(NSString *)failureMessage length] == 0) {
            return nil;
        }
        [details addObject:rollbackName];

        NSString *warningCount =
            PXRestoreWarningCountDescription(componentResult.warnings.count);
        if (warningCount.length > 0) {
            [details addObject:warningCount];
        }

        NSString *statusLine = [NSString stringWithFormat:@"- %@: %@ (%@)",
                                componentName,
                                statusName,
                                [details componentsJoinedByString:@"; "]];
        NSString *failureLine = [NSString stringWithFormat:@"  Failure: %@", failureMessage];
        return [NSString stringWithFormat:@"%@\n%@", statusLine, failureLine];
    }

    NSString *warningCount =
        PXRestoreWarningCountDescription(componentResult.warnings.count);
    if (warningCount.length > 0) {
        [details addObject:warningCount];
    }
    return [NSString stringWithFormat:@"- %@: %@ (%@)",
            componentName,
            statusName,
            [details componentsJoinedByString:@"; "]];
}

static NSString *PXRestoreComponentResultsSection(PXRestoreResult *result) {
    if (!PXRestoreResultIsValidForPresentation(result)) {
        return nil;
    }

    NSMutableArray<NSString *> *entries = [NSMutableArray arrayWithCapacity:8];
    NSUInteger componentCount =
        sizeof(PXRestorePresentationComponentOrder) /
        sizeof(PXRestorePresentationComponentOrder[0]);
    for (NSUInteger index = 0; index < componentCount; index++) {
        PXRestoreComponent component = PXRestorePresentationComponentOrder[index];
        PXRestoreComponentResult *componentResult =
            [result componentResultForComponent:component];
        NSString *entry = PXRestoreComponentResultEntry(componentResult);
        if (entry.length == 0) {
            return nil;
        }
        [entries addObject:entry];
    }

    if (entries.count != 8) {
        return nil;
    }
    NSString *header = @"Component Results:";
    return [NSString stringWithFormat:@"\n\n%@\n%@",
            header,
            [entries componentsJoinedByString:@"\n"]];
}

@implementation AppDataBackupRestoreViewController

static void PXAttemptBringTLinkIOSToFront(void) {
    NSString *selfBundle = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    if (!selfBundle.length) return;
    Class wsCls = NSClassFromString(@"LSApplicationWorkspace");
    if (!wsCls) return;
    id ws = [wsCls performSelector:@selector(defaultWorkspace)];
    if (!ws) return;
    if ([ws respondsToSelector:@selector(openApplicationWithBundleID:)]) {
        BOOL (*msgSend)(id, SEL, id) = (BOOL (*)(id, SEL, id))objc_msgSend;
        msgSend(ws, @selector(openApplicationWithBundleID:), selfBundle);
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = PXSystemBackgroundColor();

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_deliverPendingAlertIfPossible)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    // Set title based on whether we have a specific app
    if (self.appName) {
        self.title = [NSString stringWithFormat:@"%@ Backup & Restore", self.appName];
    } else {
        self.title = @"App Data Backup & Restore";
    }

    // Add Done button for the navigation bar
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                               target:self
                                                                               action:@selector(dismissVC)];
    self.navigationItem.rightBarButtonItem = doneButton;

    // Create an app name/ID label to make it clear which app we're working with
    self.appLabel = [[UILabel alloc] init];
    if (self.bundleID) {
        NSString *displayText = self.appName ?
            [NSString stringWithFormat:@"App: %@\nBundle ID: %@", self.appName, self.bundleID] :
            [NSString stringWithFormat:@"Bundle ID: %@", self.bundleID];

        NSMutableAttributedString *attributedText = [[NSMutableAttributedString alloc] initWithString:displayText];

        // Add styling - make app name bold if we have it
        if (self.appName) {
            NSRange appNameRange = [displayText rangeOfString:self.appName];
            [attributedText addAttribute:NSFontAttributeName
                                   value:[UIFont boldSystemFontOfSize:17]
                                   range:appNameRange];
        }

        self.appLabel.attributedText = attributedText;
    } else {
        self.appLabel.text = @"No app selected";
    }

    self.appLabel.textAlignment = NSTextAlignmentCenter;
    self.appLabel.numberOfLines = 0;
    self.appLabel.font = [UIFont systemFontOfSize:16];
    self.appLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.appLabel];

    UILabel *descLabel = [[UILabel alloc] init];
    descLabel.text = @"Backup and Restore your app data easily.\n\nSelect an option below:";
    descLabel.textAlignment = NSTextAlignmentCenter;
    descLabel.numberOfLines = 0;
    descLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    descLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:descLabel];

    // Options
    UIStackView *optionsStack = [[UIStackView alloc] init];
    optionsStack.axis = UILayoutConstraintAxisVertical;
    optionsStack.spacing = 12;
    optionsStack.alignment = UIStackViewAlignmentFill;
    optionsStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:optionsStack];

    UIView *(^makeOptionRow)(NSString *, UISwitch * __strong *) = ^UIView *(NSString *title, UISwitch * __strong *outSwitch) {
        UIView *row = [[UIView alloc] init];
        row.translatesAutoresizingMaskIntoConstraints = NO;

        UILabel *label = [[UILabel alloc] init];
        label.text = title;
        label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
        label.translatesAutoresizingMaskIntoConstraints = NO;

        UISwitch *sw = [[UISwitch alloc] init];
        sw.translatesAutoresizingMaskIntoConstraints = NO;

        [row addSubview:label];
        [row addSubview:sw];

        [NSLayoutConstraint activateConstraints:@[
            [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
            [label.centerYAnchor constraintEqualToAnchor:sw.centerYAnchor],
            [sw.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
            [sw.topAnchor constraintEqualToAnchor:row.topAnchor],
            [sw.bottomAnchor constraintEqualToAnchor:row.bottomAnchor]
        ]];

        if (outSwitch) {
            *outSwitch = sw;
        }

        return row;
    };

    UIView *groupsRow = makeOptionRow(@"Include App Groups (via entitlements)", &_includeGroupsSwitch);
    self.includeGroupsSwitch.on = YES;
    [optionsStack addArrangedSubview:groupsRow];

    UIView *prefsRow = makeOptionRow(@"Include Global Preferences (rare)", &_includePrefsSwitch);
    self.includePrefsSwitch.on = YES;
    [optionsStack addArrangedSubview:prefsRow];

    UIView *keychainRow = makeOptionRow(@"Include Keychain Items", &_includeKeychainSwitch);
    self.includeKeychainSwitch.on = NO; // Off by default - keychain backup is sensitive
    [optionsStack addArrangedSubview:keychainRow];

    // Keychain groups selector (enabled only when keychain toggle is on)
    self.keychainGroupsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    if ([UIButton buttonConfigurationClassExists]) {
        UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
        cfg.title = @"Keychain Groups";
        cfg.image = PXSystemImageNamed(@"key.fill");
        cfg.imagePlacement = NSDirectionalRectEdgeLeading;
        cfg.imagePadding = 6;
        cfg.baseForegroundColor = [UIColor systemBlueColor];
        [self.keychainGroupsButton safeSetConfiguration:cfg];
    } else {
        [self.keychainGroupsButton setTitle:@"Keychain Groups" forState:UIControlStateNormal];
    }
    self.keychainGroupsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.keychainGroupsButton addTarget:self action:@selector(keychainGroupsTapped) forControlEvents:UIControlEventTouchUpInside];
    [optionsStack addArrangedSubview:self.keychainGroupsButton];

    [self.includeKeychainSwitch addTarget:self action:@selector(includeKeychainChanged:) forControlEvents:UIControlEventValueChanged];
    [self refreshKeychainGroupsButton];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keychainGroupsSaved:)
                                                 name:PXBackupKeychainGroupsSavedNotification
                                               object:nil];

    UIStackView *buttonStack = [[UIStackView alloc] init];
    buttonStack.axis = UILayoutConstraintAxisVertical;
    buttonStack.spacing = 24;
    buttonStack.alignment = UIStackViewAlignmentCenter;
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:buttonStack];

    // Create stylish buttons with icons using UIButtonConfiguration (iOS 15+)
    UIButton *backupButton = [UIButton buttonWithType:UIButtonTypeSystem];
    if ([UIButton buttonConfigurationClassExists]) {
        UIButtonConfiguration *backupConfig = [UIButtonConfiguration filledButtonConfiguration];
        backupConfig.title = @"Backup App Data";
        backupConfig.image = PXSystemImageNamed(@"arrow.down.doc.fill");
        backupConfig.imagePlacement = NSDirectionalRectEdgeLeading;
        backupConfig.imagePadding = 8;
        backupConfig.contentInsets = NSDirectionalEdgeInsetsMake(12, 20, 12, 20);
        backupConfig.cornerStyle = UIButtonConfigurationCornerStyleMedium;
        backupConfig.baseBackgroundColor = [UIColor clearColor];
        backupConfig.baseForegroundColor = [UIColor systemBlueColor];
        [backupButton safeSetConfiguration:backupConfig];
    } else {
        [backupButton setTitle:@"Backup App Data" forState:UIControlStateNormal];
        [backupButton setImage:PXSystemImageNamed(@"arrow.down.doc.fill") forState:UIControlStateNormal];
        backupButton.tintColor = [UIColor systemBlueColor];
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        backupButton.contentEdgeInsets = UIEdgeInsetsMake(12, 20, 12, 20);
        #pragma clang diagnostic pop
    }

    // Add rounded corners and border
    backupButton.layer.cornerRadius = 10;
    backupButton.layer.borderWidth = 1;
    backupButton.layer.borderColor = [UIColor systemBlueColor].CGColor;

    [backupButton addTarget:self action:@selector(backupButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonStack addArrangedSubview:backupButton];

    // Create restore button with UIButtonConfiguration (iOS 15+)
    UIButton *restoreButton = [UIButton buttonWithType:UIButtonTypeSystem];
    if ([UIButton buttonConfigurationClassExists]) {
        UIButtonConfiguration *restoreConfig = [UIButtonConfiguration filledButtonConfiguration];
        restoreConfig.title = @"Restore App Data";
        restoreConfig.image = PXSystemImageNamed(@"arrow.up.doc.fill");
        restoreConfig.imagePlacement = NSDirectionalRectEdgeLeading;
        restoreConfig.imagePadding = 8;
        restoreConfig.contentInsets = NSDirectionalEdgeInsetsMake(12, 20, 12, 20);
        restoreConfig.cornerStyle = UIButtonConfigurationCornerStyleMedium;
        restoreConfig.baseBackgroundColor = [UIColor clearColor];
        restoreConfig.baseForegroundColor = [UIColor systemGreenColor];
        [restoreButton safeSetConfiguration:restoreConfig];
    } else {
        [restoreButton setTitle:@"Restore App Data" forState:UIControlStateNormal];
        [restoreButton setImage:PXSystemImageNamed(@"arrow.up.doc.fill") forState:UIControlStateNormal];
        restoreButton.tintColor = [UIColor systemGreenColor];
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        restoreButton.contentEdgeInsets = UIEdgeInsetsMake(12, 20, 12, 20);
        #pragma clang diagnostic pop
    }

    // Add rounded corners and border
    restoreButton.layer.cornerRadius = 10;
    restoreButton.layer.borderWidth = 1;
    restoreButton.layer.borderColor = [UIColor systemGreenColor].CGColor;

    [restoreButton addTarget:self action:@selector(restoreButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonStack addArrangedSubview:restoreButton];

    [NSLayoutConstraint activateConstraints:@[
        // App label constraints
        [self.appLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.appLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:30],
        [self.appLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-30],

        // Description label constraints
        [descLabel.topAnchor constraintEqualToAnchor:self.appLabel.bottomAnchor constant:20],
        [descLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:30],
        [descLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-30],

        // Options stack constraints
        [optionsStack.topAnchor constraintEqualToAnchor:descLabel.bottomAnchor constant:20],
        [optionsStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:30],
        [optionsStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-30],

        // Button stack constraints
        [buttonStack.topAnchor constraintEqualToAnchor:optionsStack.bottomAnchor constant:30],
        [buttonStack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]
    ]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self _deliverPendingAlertIfPossible];
}

- (void)_deliverPendingAlertIfPossible {
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        return;
    }
    if (!self.pendingAlertTitle.length || !self.pendingAlertMessage.length) {
        return;
    }
    if (self.presentedViewController) {
        return;
    }
    NSString *t = self.pendingAlertTitle;
    NSString *m = self.pendingAlertMessage;
    NSString *p = self.pendingCopyPath;
    self.pendingAlertTitle = nil;
    self.pendingAlertMessage = nil;
    self.pendingCopyPath = nil;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:t
                                                                   message:m
                                                            preferredStyle:UIAlertControllerStyleAlert];
    if (p.length) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Copy Path"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = p;
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)_presentResultAlertBestEffortWithTitle:(NSString *)title message:(NSString *)message copyPath:(NSString *)copyPath {
    if (!title.length || !message.length) return;
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive && !self.presentedViewController) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        if (copyPath.length) {
            [alert addAction:[UIAlertAction actionWithTitle:@"Copy Path"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(__unused UIAlertAction * _Nonnull action) {
                [UIPasteboard generalPasteboard].string = copyPath;
            }]];
        }
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // Queue and try to bring TLinkIOS back.
    self.pendingAlertTitle = title;
    self.pendingAlertMessage = message;
    self.pendingCopyPath = copyPath;
    PXAttemptBringTLinkIOSToFront();
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)includeKeychainChanged:(UISwitch *)sender {
    if (sender.isOn && self.bundleID.length) {
        // Default selection: ALL groups (resolved lazily by picker on first open)
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (![defaults objectForKey:PXBackupKeychainGroupsKey(self.bundleID)]) {
            // Leave empty until picker resolves; still show button enabled.
        }
    }
    [self refreshKeychainGroupsButton];
}

- (void)keychainGroupsSaved:(NSNotification *)note {
    [self refreshKeychainGroupsButton];
}

- (void)refreshKeychainGroupsButton {
    BOOL enabled = self.includeKeychainSwitch.isOn;
    self.keychainGroupsButton.enabled = enabled;
    self.keychainGroupsButton.alpha = enabled ? 1.0 : 0.5;

    NSUInteger count = 0;
    if (self.bundleID.length) {
        id v = [[NSUserDefaults standardUserDefaults] objectForKey:PXBackupKeychainGroupsKey(self.bundleID)];
        if ([v isKindOfClass:[NSArray class]]) {
            count = [(NSArray *)v count];
        }
    }

    NSString *title = (count > 0) ? [NSString stringWithFormat:@"Keychain Groups (%lu)", (unsigned long)count] : @"Keychain Groups";
    if ([UIButton buttonConfigurationClassExists]) {
        if (self.keychainGroupsButton.configuration) {
            UIButtonConfiguration *cfg = [self.keychainGroupsButton.configuration copy];
            cfg.title = title;
            [self.keychainGroupsButton setConfiguration:cfg];
            return;
        }
    }
    [self.keychainGroupsButton setTitle:title forState:UIControlStateNormal];
}

- (void)keychainGroupsTapped {
    if (!self.includeKeychainSwitch.isOn) {
        return;
    }
    if (!self.bundleID.length) {
        return;
    }
    BackupKeychainGroupsViewController *vc = [[BackupKeychainGroupsViewController alloc] initWithBundleID:self.bundleID];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)dismissVC {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)backupButtonTapped {
    NSString *appIdentifier = self.appName ?: self.bundleID ?: @"this app";

    PXBackupOptions options = 0;
    BOOL includeGroups = self.includeGroupsSwitch.on;
    BOOL includePreferences = self.includePrefsSwitch.on;
    BOOL includeKeychain = self.includeKeychainSwitch.on;
    if (includeGroups) {
        options |= PXBackupOptionIncludeAppGroups;
    }
    if (includePreferences) {
        options |= PXBackupOptionIncludePreferences;
    }
    if (includeKeychain) {
        options |= PXBackupOptionIncludeKeychain;
    }
    if (!PXBackupOptionsAreKnown(options)) {
        return;
    }

    PXAdvancedDataScope advancedScopes =
        PXAdvancedDataScopesForBackupOptions(options);
    NSString *confirmationTitle = PXBackupConfirmationTitle(advancedScopes);
    NSString *confirmationMessage =
        PXBackupConfirmationMessage(appIdentifier, advancedScopes);
    NSString *confirmationActionTitle =
        PXBackupConfirmationActionTitle(advancedScopes);
    if (confirmationTitle.length == 0 ||
        confirmationMessage.length == 0 ||
        confirmationActionTitle.length == 0) {
        return;
    }

    PXBackupOptions capturedOptions = options;
    UIAlertController *confirmAlert =
        [UIAlertController alertControllerWithTitle:confirmationTitle
                                            message:confirmationMessage
                                     preferredStyle:UIAlertControllerStyleAlert];

    [confirmAlert addAction:
        [UIAlertAction actionWithTitle:@"Cancel"
                                 style:UIAlertActionStyleCancel
                               handler:nil]];
    [confirmAlert addAction:
        [UIAlertAction actionWithTitle:confirmationActionTitle
                                 style:UIAlertActionStyleDefault
                               handler:^(__unused UIAlertAction * _Nonnull action) {
        UIAlertController *processingAlert =
            [UIAlertController alertControllerWithTitle:@"Backing Up"
                                                message:@"Please wait while we backup your app data..."
                                         preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:processingAlert animated:YES completion:nil];

         [[AppDataBackupManager shared] createBackupForBundleID:self.bundleID
                                                       appName:self.appName
                                                       options:capturedOptions
                                                    completion:^(PXBackupResult *result, NSError *error) {
             [processingAlert dismissViewControllerAnimated:YES completion:^{
                 PXBackupAlertOutcome outcome = PXBackupAlertOutcomeForResult(result, error);
                 NSString *title = PXBackupAlertTitleForOutcome(outcome);
                 NSString *message = nil;
                 NSString *copyPath = nil;

                 if (outcome == PXBackupAlertOutcomeFailed) {
                     NSString *errorDescription = nil;
                     if ([error isKindOfClass:[NSError class]] && error.localizedDescription.length > 0) {
                         errorDescription = error.localizedDescription;
                     }
                     message = errorDescription ?: @"Backup failed without a valid result.";
                 } else if (outcome == PXBackupAlertOutcomeSuccessful ||
                            outcome == PXBackupAlertOutcomeCompletedWithWarnings) {
                     NSMutableString *msg = [NSMutableString stringWithFormat:@"Backup created for %@.\n\nPath:\n%@",
                                             appIdentifier,
                                             result.backupDirectory];
                     if (outcome == PXBackupAlertOutcomeCompletedWithWarnings) {
                         [msg appendString:@"\n\nWarnings:\n"];
                         for (NSString *warning in result.warnings) {
                             [msg appendFormat:@"- %@\n", warning];
                         }
                     }
                     message = msg;
                     copyPath = result.backupDirectory;
                 } else {
                     message = @"Backup failed without a valid result.";
                 }

                 [self _presentResultAlertBestEffortWithTitle:title
                                                     message:message
                                                    copyPath:copyPath];
             }];
         }];
    }]];

    [self presentViewController:confirmAlert animated:YES completion:nil];
}

- (void)restoreButtonTapped {
    NSString *appIdentifier = self.appName ?: self.bundleID ?: @"this app";
    NSString *bundleIdentifier = [self.bundleID copy];
    NSString *applicationName = [self.appName copy];
    if (bundleIdentifier.length == 0) {
        return;
    }

    NSArray<NSString *> *backups =
        [[AppDataBackupManager shared] listBackupDirectoriesForBundleID:bundleIdentifier];
    if (!backups.count) {
        UIAlertController *noAlert =
            [UIAlertController alertControllerWithTitle:@"No Backups Found"
                                                message:@"No backups were found for this bundle ID. Create a backup first."
                                         preferredStyle:UIAlertControllerStyleAlert];
        [noAlert addAction:
            [UIAlertAction actionWithTitle:@"OK"
                                     style:UIAlertActionStyleDefault
                                   handler:nil]];
        [self presentViewController:noAlert animated:YES completion:nil];
        return;
    }

    UIAlertController *picker =
        [UIAlertController alertControllerWithTitle:@"Select Backup"
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    NSUInteger limit = MIN((NSUInteger)10, backups.count);
    for (NSUInteger i = 0; i < limit; i++) {
        NSString *dir = backups[i];
        NSString *title = dir.lastPathComponent;
        NSError *mErr = nil;
        NSDictionary *manifest =
            [[AppDataBackupManager shared] readManifestAtBackupDirectory:dir
                                                                    error:&mErr];
        if ([manifest isKindOfClass:[NSDictionary class]]) {
            NSString *ts = manifest[@"timestamp"];
            if ([ts isKindOfClass:[NSString class]] && ts.length) {
                title = ts;
            }
        }

        [picker addAction:
            [UIAlertAction actionWithTitle:title
                                     style:UIAlertActionStyleDefault
                                   handler:^(__unused UIAlertAction * _Nonnull action) {
            NSError *selectionError = nil;
            NSDictionary *selectedManifest =
                [[AppDataBackupManager shared] readManifestAtBackupDirectory:dir
                                                                        error:&selectionError];
            PXAdvancedDataScope selectedScopes = 0;
            BOOL scopesValid =
                PXAdvancedDataScopesForValidatedManifest(selectedManifest,
                                                         bundleIdentifier,
                                                         &selectedScopes);
            NSDictionary *confirmedManifestSnapshot = scopesValid
                ? PXImmutableManifestConfirmationSnapshot(selectedManifest)
                : nil;
            NSString *confirmationTitle = scopesValid
                ? PXRestoreConfirmationTitle(selectedScopes)
                : nil;
            NSString *confirmationMessage = scopesValid
                ? PXRestoreConfirmationMessage(appIdentifier, selectedScopes)
                : nil;
            NSString *confirmationActionTitle = scopesValid
                ? PXRestoreConfirmationActionTitle(selectedScopes)
                : nil;

            if (!scopesValid ||
                confirmedManifestSnapshot == nil ||
                confirmationTitle.length == 0 ||
                confirmationMessage.length == 0 ||
                confirmationActionTitle.length == 0) {
                NSString *unavailableMessage =
                    PXUsableErrorDescription(selectionError) ?:
                    @"The selected backup could not be validated for Restore.";
                UIAlertController *unavailableAlert =
                    [UIAlertController alertControllerWithTitle:@"Restore Unavailable"
                                                        message:unavailableMessage
                                                 preferredStyle:UIAlertControllerStyleAlert];
                [unavailableAlert addAction:
                    [UIAlertAction actionWithTitle:@"OK"
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
                [self presentViewController:unavailableAlert animated:YES completion:nil];
                return;
            }

            PXAdvancedDataScope confirmedScopes = selectedScopes;
            UIAlertController *confirmAlert =
                [UIAlertController alertControllerWithTitle:confirmationTitle
                                                    message:confirmationMessage
                                             preferredStyle:UIAlertControllerStyleAlert];
            [confirmAlert addAction:
                [UIAlertAction actionWithTitle:@"Cancel"
                                         style:UIAlertActionStyleCancel
                                       handler:nil]];
            [confirmAlert addAction:
                [UIAlertAction actionWithTitle:confirmationActionTitle
                                         style:UIAlertActionStyleDestructive
                                       handler:^(__unused UIAlertAction * _Nonnull confirmAction) {
                NSError *currentManifestError = nil;
                NSDictionary *currentManifest =
                    [[AppDataBackupManager shared] readManifestAtBackupDirectory:dir
                                                                            error:&currentManifestError];
                PXAdvancedDataScope currentScopes = 0;
                BOOL currentScopesValid =
                    PXAdvancedDataScopesForValidatedManifest(currentManifest,
                                                             bundleIdentifier,
                                                             &currentScopes);
                BOOL selectionUnchanged =
                    currentScopesValid &&
                    [currentManifest isEqual:confirmedManifestSnapshot] &&
                    currentScopes == confirmedScopes;
                if (!selectionUnchanged) {
                    UIAlertController *changedAlert =
                        [UIAlertController alertControllerWithTitle:@"Restore Selection Changed"
                                                            message:@"The selected backup changed after confirmation. Select it again and review its scopes before restoring."
                                                     preferredStyle:UIAlertControllerStyleAlert];
                    [changedAlert addAction:
                        [UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:nil]];
                    [self presentViewController:changedAlert animated:YES completion:nil];
                    return;
                }
                (void)currentManifestError;

                UIAlertController *processingAlert =
                    [UIAlertController alertControllerWithTitle:@"Restoring"
                                                        message:@"Please wait while we restore your app data..."
                                                 preferredStyle:UIAlertControllerStyleAlert];
                [self presentViewController:processingAlert animated:YES completion:nil];

                 [[AppDataBackupManager shared] restoreBackupAtDirectory:dir
                                                                bundleID:bundleIdentifier
                                                                 appName:applicationName
                                                              completion:^(PXRestoreResult *result, NSError *error) {
                     [processingAlert dismissViewControllerAnimated:YES completion:^{
                         BOOL validResult = PXRestoreResultIsValidForPresentation(result);
                         PXRestoreAlertOutcome outcome = PXRestoreAlertOutcomeForResult(result, error);
                         NSString *title = PXRestoreAlertTitleForOutcome(outcome);
                         NSMutableString *message = nil;

                         NSString *errorDescription = nil;
                         if ([error isKindOfClass:[NSError class]]) {
                             id localizedDescription = [(NSError *)error localizedDescription];
                             if ([localizedDescription isKindOfClass:[NSString class]] &&
                                 [(NSString *)localizedDescription length] > 0) {
                                 errorDescription = localizedDescription;
                             }
                         }
                         NSString *failureMessage =
                             errorDescription ?: @"Restore failed without a valid result.";

                         switch (outcome) {
                             case PXRestoreAlertOutcomeSuccessful:
                             case PXRestoreAlertOutcomeCompletedWithWarnings:
                                 message = [NSMutableString stringWithFormat:
                                     @"Data for %@ has been restored.",
                                     appIdentifier];
                                 break;

                             case PXRestoreAlertOutcomeCompletedWithComponentFailures:
                                 message = [NSMutableString stringWithFormat:
                                     @"Restore processing for %@ completed, but one or more requested components failed.",
                                     appIdentifier];
                                 break;

                             case PXRestoreAlertOutcomeFailedWithCompletedRollback:
                                 message = [NSMutableString stringWithString:failureMessage];
                                 [message appendString:
                                     @"\n\nThe failed component reported a completed rollback. Components restored earlier were not rolled back."];
                                 break;

                             case PXRestoreAlertOutcomeFailedWithIncompleteRollback:
                                 message = [NSMutableString stringWithString:failureMessage];
                                 [message appendString:
                                     @"\n\nRollback did not complete safely. Some data may remain changed."];
                                 break;

                             case PXRestoreAlertOutcomeFailed:
                             default:
                                 message = [NSMutableString stringWithString:failureMessage];
                                 break;
                         }

                         if (validResult) {
                             NSString *componentSection =
                                 PXRestoreComponentResultsSection(result);
                             if (componentSection.length > 0) {
                                 [message appendString:componentSection];
                             }
                         }

                         if (validResult && result.warnings.count > 0) {
                             PXAppendRestoreWarnings(message, result.warnings);
                         }

                         [self _presentResultAlertBestEffortWithTitle:title
                                                             message:message
                                                            copyPath:nil];
                     }];
                 }];
            }]];

            [self presentViewController:confirmAlert animated:YES completion:nil];
        }]];
    }

    [picker addAction:
        [UIAlertAction actionWithTitle:@"Cancel"
                                 style:UIAlertActionStyleCancel
                               handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        picker.popoverPresentationController.sourceView = self.view;
        picker.popoverPresentationController.sourceRect =
            CGRectMake(self.view.bounds.size.width / 2.0,
                       self.view.bounds.size.height,
                       1,
                       1);
    }
    [self presentViewController:picker animated:YES completion:nil];
}

@end
