#import "PXBackupManifestV4.h"
#import "PXBackupArtifactWriter.h"
#import "PXBackupArtifactPolicy.h"

#include <limits.h>

NSInteger const PXBackupManifestV4Version = 4;
NSString * const PXBackupManifestV4SchemaIdentifier =
    @"com.hydra.projectx.backup-manifest";
NSInteger const PXBackupManifestV4SchemaRevision = 1;
NSString * const PXBackupManifestV4DigestAlgorithm = @"sha256";
NSString * const PXBackupManifestV4PublicationProtocol = @"atomic-directory-v1";
NSString * const PXBackupManifestV4ContentStateComplete = @"complete";
NSErrorDomain const PXBackupManifestV4ErrorDomain =
    @"com.hydra.projectx.backup-manifest-v4";
NSString * const PXBackupManifestV4ErrorFieldPathKey = @"fieldPath";

static const NSUInteger PXV4MaximumDepth = 64;
static const NSUInteger PXV4MaximumVisitedNodes = 500000;
static const NSUInteger PXV4MaximumDictionaryKeys = 100000;
static const NSUInteger PXV4MaximumArrayItems = 500000;
static const NSUInteger PXV4MaximumStringBytes = 1024 * 1024;
static const NSUInteger PXV4MaximumArtifacts = 4096;

static NSArray<NSString *> *PXV4InputFieldKeys(void) {
    return @[
        @"bundleID", @"appName", @"createdAt", @"timestamp", @"iosVersion",
        @"toolVersion", @"toolBuild", @"profileId", @"backupMode",
        @"sourceDataContainerPath", @"sourceDataContainerUUID", @"warnings",
        @"restoreCompatibility", @"data", @"applicationGroups", @"appGroups",
        @"preferences", @"keychain", @"profileAppData", @"globalSafari",
        @"systemGlobalLibrary", @"sharedSystemDB", @"options"
    ];
}

static BOOL PXV4Fail(NSError **error,
                     PXBackupManifestV4ErrorCode code,
                     NSString *fieldPath,
                     NSString *description) {
    if (error) {
        *error = [NSError errorWithDomain:PXBackupManifestV4ErrorDomain
                                     code:code
                                 userInfo:@{
            NSLocalizedDescriptionKey: description,
            PXBackupManifestV4ErrorFieldPathKey: fieldPath,
        }];
    }
    return NO;
}

static BOOL PXV4ExactKeys(NSDictionary *dictionary,
                          NSArray<NSString *> *keys) {
    if (![dictionary isKindOfClass:[NSDictionary class]] ||
        dictionary.count != keys.count) {
        return NO;
    }
    NSSet *actual = [NSSet setWithArray:dictionary.allKeys];
    NSSet *expected = [NSSet setWithArray:keys];
    return [actual isEqualToSet:expected];
}

static BOOL PXV4StringContainsNUL(NSString *value) {
    for (NSUInteger index = 0; index < value.length; index++) {
        if ([value characterAtIndex:index] == 0) return YES;
    }
    return NO;
}

static BOOL PXV4StringHasText(NSString *value) {
    NSCharacterSet *set =
        [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
    return [value rangeOfCharacterFromSet:set].location != NSNotFound;
}

static BOOL PXV4StringWithinLimit(NSString *value) {
    if (![value isKindOfClass:[NSString class]] || PXV4StringContainsNUL(value)) {
        return NO;
    }
    NSData *bytes = [value dataUsingEncoding:NSUTF8StringEncoding
                         allowLossyConversion:NO];
    return bytes && bytes.length <= PXV4MaximumStringBytes;
}

static BOOL PXV4ReadRequiredString(id value, NSString **outValue) {
    if (![value isKindOfClass:[NSString class]]) return NO;
    NSString *stringValue = (NSString *)value;
    if (stringValue.length == 0 ||
        !PXV4StringHasText(stringValue) ||
        !PXV4StringWithinLimit(stringValue)) return NO;
    if (outValue) *outValue = stringValue;
    return YES;
}

static BOOL PXV4ReadOptionalString(id value, NSString **outValue) {
    if (![value isKindOfClass:[NSString class]]) return NO;
    NSString *stringValue = (NSString *)value;
    if (!PXV4StringWithinLimit(stringValue)) return NO;
    if (outValue) *outValue = stringValue;
    return YES;
}

static BOOL PXV4RequiredString(id value) {
    return PXV4ReadRequiredString(value, NULL);
}

static BOOL PXV4OptionalString(id value) {
    return PXV4ReadOptionalString(value, NULL);
}

static BOOL PXV4ReadExactBoolean(id value, BOOL *outValue) {
    if (![value isKindOfClass:[NSNumber class]]) return NO;
    if (CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) return NO;
    BOOL booleanValue = [(NSNumber *)value boolValue];
    if (outValue) *outValue = booleanValue;
    return YES;
}

static BOOL PXV4LowercaseDigest(id value) {
    if (![value isKindOfClass:[NSString class]] || [(NSString *)value length] != 64) {
        return NO;
    }
    for (NSUInteger index = 0; index < 64; index++) {
        unichar character = [(NSString *)value characterAtIndex:index];
        if (!((character >= '0' && character <= '9') ||
              (character >= 'a' && character <= 'f'))) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXV4CanonicalBackupIdentifier(id value) {
    if (![value isKindOfClass:[NSString class]]) return NO;
    NSString *string = value;
    NSData *bytes = [string dataUsingEncoding:NSASCIIStringEncoding
                          allowLossyConversion:NO];
    if (!bytes || bytes.length != 36 || string.length != 36) return NO;
    for (NSUInteger index = 0; index < 36; index++) {
        unichar character = [string characterAtIndex:index];
        if (index == 8 || index == 13 || index == 18 || index == 23) {
            if (character != '-') return NO;
        } else if (!((character >= '0' && character <= '9') ||
                     (character >= 'a' && character <= 'f'))) {
            return NO;
        }
    }
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:string];
    return uuid && [uuid.UUIDString.lowercaseString isEqualToString:string];
}

static BOOL PXV4SafeRelativePath(id value) {
    if (!PXV4RequiredString(value)) return NO;
    NSString *path = value;
    NSData *pathBytes = [path dataUsingEncoding:NSUTF8StringEncoding
                            allowLossyConversion:NO];
    if (!pathBytes || pathBytes.length > 4096 ||
        [path hasPrefix:@"/"] || [path hasSuffix:@"/"] ||
        [path containsString:@"\\"]) return NO;
    NSArray<NSString *> *components = [path componentsSeparatedByString:@"/"];
    if (components.count == 0 || components.count > 32) return NO;
    for (NSString *component in components) {
        NSData *componentBytes =
            [component dataUsingEncoding:NSUTF8StringEncoding
                     allowLossyConversion:NO];
        if (!componentBytes || componentBytes.length == 0 ||
            componentBytes.length > 255 || [component isEqualToString:@"."] ||
            [component isEqualToString:@".."] || PXV4StringContainsNUL(component) ||
            [component isEqualToString:@".weaponx-backup.lock"] ||
            [component isEqualToString:@"manifest.plist"] ||
            [component hasPrefix:@".weaponx-backup-partial-"] ||
            [component hasPrefix:@".weaponx-artifact-partial-"]) return NO;
        NSCharacterSet *controls = [NSCharacterSet controlCharacterSet];
        if ([component rangeOfCharacterFromSet:controls].location != NSNotFound) return NO;
    }
    return YES;
}

@interface PXV4SnapshotFrame : NSObject
@property (nonatomic, strong) id source;
@property (nonatomic, strong) id output;
@property (nonatomic, copy) NSArray *keys;
@property (nonatomic) NSUInteger index;
@property (nonatomic) NSUInteger depth;
@property (nonatomic) NSUInteger expectedCount;
@property (nonatomic) Class expectedClass;
@property (nonatomic, strong) id parentOutput;
@property (nonatomic, strong) id parentSlot;
@end
@implementation PXV4SnapshotFrame @end

static id PXV4CopyLeaf(id value) {
    if ([value isKindOfClass:[NSString class]] && PXV4StringWithinLimit(value)) {
        return [(NSString *)value copy];
    }
    if ([value isKindOfClass:[NSNumber class]] ||
        [value isKindOfClass:[NSDate class]] ||
        [value isKindOfClass:[NSData class]]) {
        return [value copy];
    }
    return nil;
}

static BOOL PXV4AssignSnapshotValue(id parent, id slot, id value) {
    if ([parent isKindOfClass:[NSMutableDictionary class]] &&
        [slot isKindOfClass:[NSString class]]) {
        [(NSMutableDictionary *)parent setObject:value forKey:slot];
        return YES;
    }
    if ([parent isKindOfClass:[NSMutableArray class]] &&
        [slot isKindOfClass:[NSNumber class]]) {
        NSUInteger index = [(NSNumber *)slot unsignedIntegerValue];
        if (index >= [(NSMutableArray *)parent count]) return NO;
        [(NSMutableArray *)parent replaceObjectAtIndex:index withObject:value];
        return YES;
    }
    return NO;
}

static id PXV4ImmutableSnapshot(id root, NSError **error) {
    if (!root) {
        PXV4Fail(error, PXBackupManifestV4ErrorSnapshotFailed,
                 @"$.fields", @"The metadata snapshot could not be created");
        return nil;
    }
    id leaf = PXV4CopyLeaf(root);
    if (leaf) return leaf;
    BOOL rootDictionary = [root isKindOfClass:[NSDictionary class]];
    BOOL rootArray = [root isKindOfClass:[NSArray class]];
    if (!rootDictionary && !rootArray) {
        PXV4Fail(error, PXBackupManifestV4ErrorSnapshotFailed,
                 @"$.fields", @"The metadata graph contains an unsupported value");
        return nil;
    }

    NSMutableArray<PXV4SnapshotFrame *> *stack = [NSMutableArray array];
    NSHashTable *active =
        [NSHashTable hashTableWithOptions:NSHashTableObjectPointerPersonality];
    NSUInteger visited = 0, dictionaryKeys = 0, arrayItems = 0;
    PXV4SnapshotFrame *rootFrame = [PXV4SnapshotFrame new];
    rootFrame.source = root;
    rootFrame.depth = 1;
    rootFrame.expectedClass = [root class];
    rootFrame.expectedCount = [root count];
    if (rootDictionary) {
        NSArray *keys = [(NSDictionary *)root allKeys];
        for (id key in keys) {
            if (![key isKindOfClass:[NSString class]] || !PXV4StringWithinLimit(key)) {
                PXV4Fail(error, PXBackupManifestV4ErrorSnapshotFailed,
                         @"$.fields", @"The metadata graph contains an invalid dictionary key");
                return nil;
            }
        }
        rootFrame.keys = [keys sortedArrayUsingSelector:@selector(compare:)];
        rootFrame.output = [NSMutableDictionary dictionaryWithCapacity:keys.count];
    } else {
        rootFrame.output = [NSMutableArray arrayWithCapacity:rootFrame.expectedCount];
        for (NSUInteger i = 0; i < rootFrame.expectedCount; i++) {
            [(NSMutableArray *)rootFrame.output addObject:[NSNull null]];
        }
    }
    [stack addObject:rootFrame];
    [active addObject:root];

    while (stack.count > 0) {
        PXV4SnapshotFrame *frame = stack.lastObject;
        if (frame.depth > PXV4MaximumDepth || visited >= PXV4MaximumVisitedNodes ||
            [frame.source class] != frame.expectedClass ||
            [frame.source count] != frame.expectedCount) {
            PXV4Fail(error, PXBackupManifestV4ErrorSnapshotFailed,
                     @"$.fields", @"The metadata snapshot exceeded bounds or changed during capture");
            return nil;
        }
        BOOL dictionary = [frame.source isKindOfClass:[NSDictionary class]];
        if (frame.index >= frame.expectedCount) {
            if ([frame.source class] != frame.expectedClass ||
                [frame.source count] != frame.expectedCount ||
                ![frame.source isEqual:frame.output]) {
                PXV4Fail(error, PXBackupManifestV4ErrorSnapshotFailed,
                         @"$.fields", @"The metadata graph changed during capture");
                return nil;
            }
            id immutable = dictionary
                ? [(NSDictionary *)frame.output copy]
                : [(NSArray *)frame.output copy];
            [active removeObject:frame.source];
            [stack removeLastObject];
            if (!frame.parentOutput) return immutable;
            if (!PXV4AssignSnapshotValue(frame.parentOutput, frame.parentSlot, immutable)) {
                PXV4Fail(error, PXBackupManifestV4ErrorSnapshotFailed,
                         @"$.fields", @"The metadata snapshot could not be assembled");
                return nil;
            }
            continue;
        }

        id slot = dictionary ? frame.keys[frame.index] : @(frame.index);
        id value = dictionary
            ? [(NSDictionary *)frame.source objectForKey:slot]
            : [(NSArray *)frame.source objectAtIndex:frame.index];
        frame.index += 1;
        visited += 1;
        if (visited > PXV4MaximumVisitedNodes) {
            PXV4Fail(error, PXBackupManifestV4ErrorSnapshotFailed,
                     @"$.fields", @"The metadata graph exceeded the visited-node limit");
            return nil;
        }
        if (dictionary) {
            dictionaryKeys += 1;
            if (dictionaryKeys > PXV4MaximumDictionaryKeys) {
                PXV4Fail(error, PXBackupManifestV4ErrorSnapshotFailed,
                         @"$.fields", @"The metadata graph exceeded the dictionary-key limit");
                return nil;
            }
        } else {
            arrayItems += 1;
            if (arrayItems > PXV4MaximumArrayItems) {
                PXV4Fail(error, PXBackupManifestV4ErrorSnapshotFailed,
                         @"$.fields", @"The metadata graph exceeded the array-item limit");
                return nil;
            }
        }
        id copiedLeaf = PXV4CopyLeaf(value);
        if (copiedLeaf) {
            if (!PXV4AssignSnapshotValue(frame.output, slot, copiedLeaf)) return nil;
            continue;
        }
        BOOL childDictionary = [value isKindOfClass:[NSDictionary class]];
        BOOL childArray = [value isKindOfClass:[NSArray class]];
        if ((!childDictionary && !childArray) || [active containsObject:value]) {
            PXV4Fail(error, PXBackupManifestV4ErrorSnapshotFailed,
                     @"$.fields", @"The metadata graph contains a cycle or unsupported value");
            return nil;
        }
        PXV4SnapshotFrame *child = [PXV4SnapshotFrame new];
        child.source = value;
        child.parentOutput = frame.output;
        child.parentSlot = slot;
        child.depth = frame.depth + 1;
        child.expectedClass = [value class];
        child.expectedCount = [value count];
        if (childDictionary) {
            NSArray *keys = [(NSDictionary *)value allKeys];
            for (id key in keys) {
                if (![key isKindOfClass:[NSString class]] || !PXV4StringWithinLimit(key)) {
                    PXV4Fail(error, PXBackupManifestV4ErrorSnapshotFailed,
                             @"$.fields", @"The metadata graph contains an invalid dictionary key");
                    return nil;
                }
            }
            child.keys = [keys sortedArrayUsingSelector:@selector(compare:)];
            child.output = [NSMutableDictionary dictionaryWithCapacity:keys.count];
        } else {
            child.output = [NSMutableArray arrayWithCapacity:child.expectedCount];
            for (NSUInteger i = 0; i < child.expectedCount; i++) {
                [(NSMutableArray *)child.output addObject:[NSNull null]];
            }
        }
        [active addObject:value];
        [stack addObject:child];
    }
    return nil;
}

static NSString *PXV4KindString(PXBackupArtifactKind kind) {
    switch (kind) {
        case PXBackupArtifactKindApplicationData: return @"applicationData";
        case PXBackupArtifactKindAppGroup: return @"appGroup";
        case PXBackupArtifactKindProfileAppData: return @"profileAppData";
        case PXBackupArtifactKindGlobalSafari: return @"globalSafari";
        case PXBackupArtifactKindSystemGlobal: return @"systemGlobal";
        case PXBackupArtifactKindSharedSystemDatabase: return @"sharedSystemDatabase";
        case PXBackupArtifactKindPreferences: return @"preferences";
        case PXBackupArtifactKindKeychain: return @"keychain";
    }
    return nil;
}

static NSString *PXV4RequirementString(PXBackupArtifactRequirement value) {
    return value == PXBackupArtifactRequirementRequired ? @"required" :
           value == PXBackupArtifactRequirementOptional ? @"optional" : nil;
}
static NSString *PXV4DispositionString(PXBackupArtifactFailureDisposition value) {
    switch (value) {
        case PXBackupArtifactFailureDispositionAbortBackup: return @"abortBackup";
        case PXBackupArtifactFailureDispositionWarnAndContinue: return @"warnAndContinue";
        case PXBackupArtifactFailureDispositionContinueWithoutWarning: return @"continueWithoutWarning";
    }
    return nil;
}
static NSString *PXV4EmptyString(PXBackupArtifactEmptyFilePolicy value) {
    return value == PXBackupArtifactEmptyFilePolicyReject ? @"reject" :
           value == PXBackupArtifactEmptyFilePolicyAllow ? @"allow" : nil;
}

static BOOL PXV4AddReference(NSMutableSet<NSString *> *references,
                             NSDictionary<NSString *, PXVerifiedBackupArtifact *> *records,
                             NSString *name,
                             PXBackupArtifactKind kind,
                             NSString *fieldPath,
                             NSError **error) {
    if (!PXV4SafeRelativePath(name)) {
        return PXV4Fail(error, PXBackupManifestV4ErrorMissingReference,
                        fieldPath, @"The artifact reference is invalid");
    }
    PXVerifiedBackupArtifact *record = records[name];
    if (!record) {
        return PXV4Fail(error, PXBackupManifestV4ErrorMissingReference,
                        fieldPath, @"The artifact reference is missing");
    }
    if (record.policy.kind != kind) {
        return PXV4Fail(error, PXBackupManifestV4ErrorInvalidArtifactPolicy,
                        fieldPath, @"The artifact reference has an invalid policy kind");
    }
    if ([references containsObject:name]) {
        return PXV4Fail(error, PXBackupManifestV4ErrorDuplicateReference,
                        fieldPath, @"The artifact reference is duplicated");
    }
    [references addObject:name];
    return YES;
}

static PXBackupManifestV4 *PXV4FailureResult(NSError **error) {
    if (error && !*error) {
        PXV4Fail(error,
                 PXBackupManifestV4ErrorInvalidFieldValue,
                 @"$.fields",
                 @"A manifest field or component is invalid");
    }
    return nil;
}

@interface PXBackupManifestV4 ()
- (instancetype)initWithBackupIdentifier:(NSString *)backupIdentifier
                   manifestRepresentation:(NSDictionary<NSString *, id> *)representation
                            artifactCount:(NSUInteger)artifactCount
                                 totalSize:(unsigned long long)totalSize
                   applicationDataChecksum:(NSString *)checksum;
@end

@implementation PXBackupManifestV4 {
    NSString *_backupIdentifier;
    NSDictionary<NSString *, id> *_manifestRepresentation;
    NSUInteger _artifactCount;
    unsigned long long _totalSize;
    NSString *_applicationDataChecksum;
}

+ (nullable instancetype)
    manifestWithBackupIdentifier:(NSString *)backupIdentifier
                          fields:(NSDictionary<NSString *, id> *)fields
               verifiedArtifacts:(NSArray<PXVerifiedBackupArtifact *> *)verifiedArtifacts
                           error:(NSError * _Nullable * _Nullable)error {
    if (error) {
        *error = nil;
    }
    @try {
    if (![fields isKindOfClass:[NSDictionary class]] ||
        ![verifiedArtifacts isKindOfClass:[NSArray class]]) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidInput,
                 @"$", @"The manifest inputs are invalid");
        return PXV4FailureResult(error);
    }
    if (!PXV4CanonicalBackupIdentifier(backupIdentifier)) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidBackupIdentifier,
                 @"$.backupID", @"The backup identifier is invalid");
        return PXV4FailureResult(error);
    }
    if (!PXV4ExactKeys(fields, PXV4InputFieldKeys())) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldSet,
                 @"$.fields", @"The manifest field set is invalid");
        return PXV4FailureResult(error);
    }
    NSDictionary *snapshot = PXV4ImmutableSnapshot(fields, error);
    if (![snapshot isKindOfClass:[NSDictionary class]]) return PXV4FailureResult(error);

    NSString *bundleIdentifier = nil;
    NSString *backupMode = nil;
    if (!PXV4ReadRequiredString(snapshot[@"bundleID"], &bundleIdentifier) ||
        !PXV4OptionalString(snapshot[@"appName"]) ||
        ![snapshot[@"createdAt"] isKindOfClass:[NSDate class]] ||
        !PXV4RequiredString(snapshot[@"timestamp"]) ||
        !PXV4OptionalString(snapshot[@"iosVersion"]) ||
        !PXV4OptionalString(snapshot[@"toolVersion"]) ||
        !PXV4OptionalString(snapshot[@"toolBuild"]) ||
        !PXV4OptionalString(snapshot[@"profileId"]) ||
        !PXV4ReadRequiredString(snapshot[@"backupMode"], &backupMode) ||
        ![backupMode isEqualToString:@"strict"] ||
        !PXV4OptionalString(snapshot[@"sourceDataContainerPath"]) ||
        !PXV4OptionalString(snapshot[@"sourceDataContainerUUID"]) ||
        ![snapshot[@"warnings"] isKindOfClass:[NSArray class]]) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                 @"$.fields", @"A manifest field value is invalid");
        return PXV4FailureResult(error);
    }
    for (id warning in snapshot[@"warnings"]) {
        if (!PXV4RequiredString(warning)) {
            PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                     @"$.warnings", @"The warnings section is invalid");
            return PXV4FailureResult(error);
        }
    }

    NSDictionary *restore = snapshot[@"restoreCompatibility"];
    NSDictionary *data = snapshot[@"data"];
    NSArray *applicationGroups = snapshot[@"applicationGroups"];
    NSArray *appGroups = snapshot[@"appGroups"];
    NSDictionary *preferences = snapshot[@"preferences"];
    NSDictionary *keychain = snapshot[@"keychain"];
    NSDictionary *profile = snapshot[@"profileAppData"];
    NSDictionary *safari = snapshot[@"globalSafari"];
    NSDictionary *system = snapshot[@"systemGlobalLibrary"];
    NSDictionary *shared = snapshot[@"sharedSystemDB"];
    NSDictionary *options = snapshot[@"options"];

    NSString *restoreTargetBundleIdentifier = nil;
    BOOL requiresSameBundleIdentifier = NO;
    BOOL requiresInstalledContainer = NO;
    if (!PXV4ExactKeys(restore, @[@"targetBundleID", @"requiresSameBundleID",
                                  @"requiresInstalledAppContainer", @"notes"]) ||
        !PXV4ReadRequiredString(restore[@"targetBundleID"],
                                &restoreTargetBundleIdentifier) ||
        ![restoreTargetBundleIdentifier isEqualToString:bundleIdentifier] ||
        !PXV4ReadExactBoolean(restore[@"requiresSameBundleID"],
                              &requiresSameBundleIdentifier) ||
        !PXV4ReadExactBoolean(restore[@"requiresInstalledAppContainer"],
                              &requiresInstalledContainer) ||
        ![restore[@"notes"] isKindOfClass:[NSArray class]] ||
        !PXV4ExactKeys(data, @[@"uuid", @"archive", @"containerPath"]) ||
        !PXV4RequiredString(data[@"uuid"]) || !PXV4SafeRelativePath(data[@"archive"]) ||
        !PXV4RequiredString(data[@"containerPath"]) ||
        ![applicationGroups isKindOfClass:[NSArray class]] ||
        ![appGroups isKindOfClass:[NSArray class]] ||
        !PXV4ExactKeys(preferences, @[@"included", @"archive"]) ||
        !PXV4ExactKeys(keychain, @[@"included", @"archive", @"groupsSelected", @"method"]) ||
        !PXV4ExactKeys(profile, @[@"included", @"archive", @"path"]) ||
        !PXV4ExactKeys(safari, @[@"included", @"archive", @"path"]) ||
        !PXV4ExactKeys(system, @[@"included", @"items"]) ||
        !PXV4ExactKeys(shared, @[@"included", @"files"]) ||
        !PXV4ExactKeys(options, @[@"includeAppGroups", @"includePreferences", @"includeKeychain"])) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                 @"$.fields", @"A manifest component is invalid");
        return PXV4FailureResult(error);
    }
    (void)requiresSameBundleIdentifier;
    (void)requiresInstalledContainer;
    for (id note in restore[@"notes"]) {
        if (!PXV4RequiredString(note)) return PXV4FailureResult(error);
    }
    BOOL requestGroups = NO;
    BOOL requestPreferences = NO;
    BOOL requestKeychain = NO;
    if (!PXV4ReadExactBoolean(options[@"includeAppGroups"], &requestGroups) ||
        !PXV4ReadExactBoolean(options[@"includePreferences"], &requestPreferences) ||
        !PXV4ReadExactBoolean(options[@"includeKeychain"], &requestKeychain)) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                 @"$.options", @"The requested options are invalid");
        return PXV4FailureResult(error);
    }

    NSMutableSet *applicationGroupSet = [NSMutableSet set];
    for (id groupID in applicationGroups) {
        if (!PXV4RequiredString(groupID) || [applicationGroupSet containsObject:groupID]) {
            PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                     @"$.applicationGroups", @"The application group snapshot is invalid");
            return PXV4FailureResult(error);
        }
        [applicationGroupSet addObject:groupID];
    }

    if (verifiedArtifacts.count < 1 || verifiedArtifacts.count > PXV4MaximumArtifacts) {
        PXV4Fail(error, PXBackupManifestV4ErrorMissingRequiredArtifact,
                 @"$.artifacts", @"The verified artifact set is invalid");
        return PXV4FailureResult(error);
    }
    NSMutableDictionary<NSString *, PXVerifiedBackupArtifact *> *records = [NSMutableDictionary dictionary];
    NSMutableArray<NSDictionary *> *artifactDeclarations = [NSMutableArray array];
    unsigned long long totalSize = 0;
    NSUInteger requiredCount = 0, applicationDataCount = 0;
    NSUInteger profileCount = 0, safariCount = 0, preferencesCount = 0, keychainCount = 0;
    PXBackupArtifactKind previousKind = 0;
    NSString *applicationDataChecksum = nil;

    for (NSUInteger index = 0; index < verifiedArtifacts.count; index++) {
        id rawRecord = verifiedArtifacts[index];
        if (![rawRecord isMemberOfClass:[PXVerifiedBackupArtifact class]]) {
            PXV4Fail(error, PXBackupManifestV4ErrorInvalidArtifact,
                     @"$.artifacts", @"A verified artifact is invalid");
            return PXV4FailureResult(error);
        }
        PXVerifiedBackupArtifact *record = rawRecord;
        PXBackupArtifactPolicy *policy = record.policy;
        if (![policy isMemberOfClass:[PXBackupArtifactPolicy class]]) {
            PXV4Fail(error, PXBackupManifestV4ErrorInvalidArtifactPolicy,
                     @"$.artifacts.policy", @"An artifact policy is invalid");
            return PXV4FailureResult(error);
        }
        PXBackupArtifactPolicy *canonical = [PXBackupArtifactPolicy policyForKind:policy.kind];
        if (!canonical || ![policy isEqual:canonical] ||
            ![policy acceptsFileSize:record.size]) {
            PXV4Fail(error, PXBackupManifestV4ErrorInvalidArtifactPolicy,
                     @"$.artifacts.policy", @"An artifact policy is invalid");
            return PXV4FailureResult(error);
        }
        if (!PXV4SafeRelativePath(record.relativePath) ||
            !PXV4LowercaseDigest(record.sha256) || records[record.relativePath]) {
            PXV4Fail(error, PXBackupManifestV4ErrorInvalidArtifact,
                     @"$.artifacts", @"An artifact declaration is invalid");
            return PXV4FailureResult(error);
        }
        if (policy.kind < previousKind) {
            PXV4Fail(error, PXBackupManifestV4ErrorInvalidArtifactOrder,
                     @"$.artifacts", @"The artifact order is invalid");
            return PXV4FailureResult(error);
        }
        previousKind = policy.kind;
        if (totalSize > ULLONG_MAX - record.size) {
            PXV4Fail(error, PXBackupManifestV4ErrorSizeOverflow,
                     @"$.totalSize", @"The artifact size total overflowed");
            return PXV4FailureResult(error);
        }
        totalSize += record.size;
        if (policy.requirement == PXBackupArtifactRequirementRequired) requiredCount += 1;
        switch (policy.kind) {
            case PXBackupArtifactKindApplicationData:
                applicationDataCount += 1;
                applicationDataChecksum = record.sha256;
                if (index != 0) {
                    PXV4Fail(error, PXBackupManifestV4ErrorInvalidArtifactOrder,
                             @"$.artifacts[0]", @"The required artifact must be first");
                    return PXV4FailureResult(error);
                }
                break;
            case PXBackupArtifactKindProfileAppData: profileCount += 1; break;
            case PXBackupArtifactKindGlobalSafari: safariCount += 1; break;
            case PXBackupArtifactKindPreferences: preferencesCount += 1; break;
            case PXBackupArtifactKindKeychain: keychainCount += 1; break;
            default: break;
        }
        NSString *kind = PXV4KindString(policy.kind);
        NSString *requirement = PXV4RequirementString(policy.requirement);
        NSString *disposition = PXV4DispositionString(policy.failureDisposition);
        NSString *empty = PXV4EmptyString(policy.emptyFilePolicy);
        if (!kind || !requirement || !disposition || !empty) return PXV4FailureResult(error);
        NSDictionary *declaration = @{
            @"name": record.relativePath,
            @"path": record.relativePath,
            @"size": @(record.size),
            @"sha256": record.sha256,
            @"policy": @{
                @"kind": kind,
                @"requirement": requirement,
                @"failureDisposition": disposition,
                @"emptyFilePolicy": empty,
            },
        };
        records[record.relativePath] = record;
        [artifactDeclarations addObject:declaration];
    }
    if (applicationDataCount != 1 || requiredCount != 1 ||
        profileCount > 1 || safariCount > 1 || preferencesCount > 1 || keychainCount > 1) {
        PXV4Fail(error, PXBackupManifestV4ErrorMissingRequiredArtifact,
                 @"$.artifacts", @"The required artifact contract is invalid");
        return PXV4FailureResult(error);
    }

    NSMutableSet<NSString *> *references = [NSMutableSet set];
    if (!PXV4AddReference(references, records, data[@"archive"],
                          PXBackupArtifactKindApplicationData, @"$.data.archive", error)) return PXV4FailureResult(error);

    NSMutableSet *successfulGroupIDs = [NSMutableSet set];
    for (NSUInteger index = 0; index < appGroups.count; index++) {
        id raw = appGroups[index];
        if (!PXV4ExactKeys(raw, @[@"groupID", @"uuid", @"archive"]) ||
            !PXV4RequiredString(raw[@"groupID"]) || !PXV4RequiredString(raw[@"uuid"]) ||
            ![applicationGroupSet containsObject:raw[@"groupID"]] ||
            [successfulGroupIDs containsObject:raw[@"groupID"]] ||
            !PXV4AddReference(references, records, raw[@"archive"],
                              PXBackupArtifactKindAppGroup, @"$.appGroups.archive", error)) {
            if (!error || !*error) PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                                            @"$.appGroups", @"The App Group section is invalid");
            return PXV4FailureResult(error);
        }
        [successfulGroupIDs addObject:raw[@"groupID"]];
    }
    if (!requestGroups && appGroups.count != 0) {
        PXV4Fail(error, PXBackupManifestV4ErrorInconsistentOptions,
                 @"$.options.includeAppGroups", @"The App Group request is inconsistent");
        return PXV4FailureResult(error);
    }

    BOOL preferencesIncluded = NO;
    NSString *preferencesArchive = nil;
    if (!PXV4ReadExactBoolean(preferences[@"included"], &preferencesIncluded) ||
        !PXV4ReadOptionalString(preferences[@"archive"], &preferencesArchive)) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                 @"$.preferences", @"The Preferences section is invalid");
        return PXV4FailureResult(error);
    }
    if (preferencesIncluded) {
        if (!PXV4AddReference(references, records, preferencesArchive,
                              PXBackupArtifactKindPreferences,
                              @"$.preferences.archive", error)) {
            return PXV4FailureResult(error);
        }
    } else if (![preferencesArchive isEqualToString:@""]) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                 @"$.preferences.archive", @"The Preferences section is invalid");
        return PXV4FailureResult(error);
    }
    if (!requestPreferences && preferencesIncluded) {
        PXV4Fail(error, PXBackupManifestV4ErrorInconsistentOptions,
                 @"$.options.includePreferences", @"The Preferences request is inconsistent");
        return PXV4FailureResult(error);
    }

    BOOL keychainIncluded = NO;
    NSString *keychainArchive = nil;
    NSString *keychainMethod = nil;
    if (!PXV4ReadExactBoolean(keychain[@"included"], &keychainIncluded) ||
        !PXV4ReadOptionalString(keychain[@"archive"], &keychainArchive) ||
        !PXV4ReadOptionalString(keychain[@"method"], &keychainMethod) ||
        ![keychain[@"groupsSelected"] isKindOfClass:[NSArray class]]) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                 @"$.keychain", @"The Keychain section is invalid");
        return PXV4FailureResult(error);
    }
    if (keychainIncluded) {
        if (!PXV4ReadRequiredString(keychainMethod, NULL) ||
            !PXV4AddReference(references, records, keychainArchive,
                              PXBackupArtifactKindKeychain,
                              @"$.keychain.archive", error)) {
            return PXV4FailureResult(error);
        }
    } else if (![keychainArchive isEqualToString:@""] ||
               ![keychainMethod isEqualToString:@""]) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                 @"$.keychain", @"The Keychain section is invalid");
        return PXV4FailureResult(error);
    }
    NSMutableSet<NSString *> *selectedGroupSet = [NSMutableSet set];
    for (id group in keychain[@"groupsSelected"]) {
        if (!PXV4RequiredString(group) || [selectedGroupSet containsObject:group]) {
            PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                     @"$.keychain.groupsSelected",
                     @"The selected Keychain group snapshot is invalid");
            return PXV4FailureResult(error);
        }
        [selectedGroupSet addObject:group];
    }
    if (!requestKeychain && keychainIncluded) {
        PXV4Fail(error, PXBackupManifestV4ErrorInconsistentOptions,
                 @"$.options.includeKeychain", @"The Keychain request is inconsistent");
        return PXV4FailureResult(error);
    }

    BOOL profileIncluded = NO;
    NSString *profileArchive = nil;
    NSString *profileRecordedPath = nil;
    if (!PXV4ReadExactBoolean(profile[@"included"], &profileIncluded) ||
        !PXV4ReadOptionalString(profile[@"archive"], &profileArchive) ||
        !PXV4ReadOptionalString(profile[@"path"], &profileRecordedPath)) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                 @"$.profileAppData", @"The profile AppData section is invalid");
        return PXV4FailureResult(error);
    }
    if (profileIncluded) {
        if (!PXV4ReadRequiredString(profileRecordedPath, NULL) ||
            !PXV4AddReference(references, records, profileArchive,
                              PXBackupArtifactKindProfileAppData,
                              @"$.profileAppData.archive", error)) {
            return PXV4FailureResult(error);
        }
    } else if (![profileArchive isEqualToString:@""]) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                 @"$.profileAppData.archive", @"The profile AppData section is invalid");
        return PXV4FailureResult(error);
    }

    BOOL safariIncluded = NO;
    NSString *safariArchive = nil;
    NSString *safariRecordedPath = nil;
    if (!PXV4ReadExactBoolean(safari[@"included"], &safariIncluded) ||
        !PXV4ReadOptionalString(safari[@"archive"], &safariArchive) ||
        !PXV4ReadOptionalString(safari[@"path"], &safariRecordedPath)) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                 @"$.globalSafari", @"The global Safari section is invalid");
        return PXV4FailureResult(error);
    }
    if (safariIncluded) {
        if (!PXV4ReadRequiredString(safariRecordedPath, NULL) ||
            !PXV4AddReference(references, records, safariArchive,
                              PXBackupArtifactKindGlobalSafari,
                              @"$.globalSafari.archive", error)) {
            return PXV4FailureResult(error);
        }
    } else if (![safariArchive isEqualToString:@""]) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                 @"$.globalSafari.archive", @"The global Safari section is invalid");
        return PXV4FailureResult(error);
    }

    NSArray *systemItems = system[@"items"];
    BOOL systemIncluded = NO;
    if (!PXV4ReadExactBoolean(system[@"included"], &systemIncluded) ||
        ![systemItems isKindOfClass:[NSArray class]] ||
        systemIncluded != (systemItems.count > 0)) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                 @"$.systemGlobalLibrary", @"The system-global section is invalid");
        return PXV4FailureResult(error);
    }
    NSMutableSet *subdirs = [NSMutableSet set];
    for (id item in systemItems) {
        if (!PXV4ExactKeys(item, @[@"subdir", @"archive"]) ||
            !PXV4RequiredString(item[@"subdir"]) || [subdirs containsObject:item[@"subdir"]] ||
            !PXV4AddReference(references, records, item[@"archive"],
                              PXBackupArtifactKindSystemGlobal,
                              @"$.systemGlobalLibrary.items.archive", error)) {
            return PXV4FailureResult(error);
        }
        [subdirs addObject:item[@"subdir"]];
    }

    NSArray *sharedFiles = shared[@"files"];
    BOOL sharedIncluded = NO;
    if (!PXV4ReadExactBoolean(shared[@"included"], &sharedIncluded) ||
        ![sharedFiles isKindOfClass:[NSArray class]] ||
        sharedIncluded != (sharedFiles.count > 0)) {
        PXV4Fail(error, PXBackupManifestV4ErrorInvalidFieldValue,
                 @"$.sharedSystemDB", @"The shared database section is invalid");
        return PXV4FailureResult(error);
    }
    NSMutableSet *libraryPaths = [NSMutableSet set];
    for (id item in sharedFiles) {
        if (!PXV4ExactKeys(item, @[@"libraryRel", @"archive"]) ||
            !PXV4RequiredString(item[@"libraryRel"]) || [libraryPaths containsObject:item[@"libraryRel"]] ||
            !PXV4AddReference(references, records, item[@"archive"],
                              PXBackupArtifactKindSharedSystemDatabase,
                              @"$.sharedSystemDB.files.archive", error)) {
            return PXV4FailureResult(error);
        }
        [libraryPaths addObject:item[@"libraryRel"]];
    }

    if (references.count != records.count) {
        PXV4Fail(error, PXBackupManifestV4ErrorUnreferencedArtifact,
                 @"$.artifacts", @"An artifact declaration is not referenced exactly once");
        return PXV4FailureResult(error);
    }

    NSMutableArray *includedOptions = [NSMutableArray arrayWithObject:@"DataContainer"];
    NSMutableArray *excludedOptions = [NSMutableArray array];
    if (appGroups.count > 0) [includedOptions addObject:@"AppGroups"];
    else [excludedOptions addObject:@"AppGroups"];
    if (preferencesIncluded) [includedOptions addObject:@"GlobalPreferences"];
    else [excludedOptions addObject:@"GlobalPreferences"];
    if (keychainIncluded) [includedOptions addObject:@"Keychain"];
    else [excludedOptions addObject:@"Keychain"];

    NSMutableDictionary *representation = [snapshot mutableCopy];
    representation[@"manifestVersion"] = @(PXBackupManifestV4Version);
    representation[@"schema"] = @{
        @"identifier": PXBackupManifestV4SchemaIdentifier,
        @"revision": @(PXBackupManifestV4SchemaRevision),
        @"digestAlgorithm": PXBackupManifestV4DigestAlgorithm,
    };
    representation[@"backupID"] = [backupIdentifier copy];
    representation[@"publication"] = @{
        @"protocol": PXBackupManifestV4PublicationProtocol,
        @"contentState": PXBackupManifestV4ContentStateComplete,
    };
    representation[@"includedOptions"] = [includedOptions copy];
    representation[@"excludedOptions"] = [excludedOptions copy];
    representation[@"artifactCount"] = @(verifiedArtifacts.count);
    representation[@"totalSize"] = @(totalSize);
    representation[@"archiveChecksum"] = applicationDataChecksum;
    representation[@"artifacts"] = [artifactDeclarations copy];
    NSDictionary *immutableRepresentation = [representation copy];
    if (immutableRepresentation.count != 33) {
        PXV4Fail(error, PXBackupManifestV4ErrorSnapshotFailed,
                 @"$", @"The manifest snapshot field set is invalid");
        return PXV4FailureResult(error);
    }
    PXBackupManifestV4 *result = [[self alloc]
        initWithBackupIdentifier:backupIdentifier
          manifestRepresentation:immutableRepresentation
                   artifactCount:verifiedArtifacts.count
                        totalSize:totalSize
          applicationDataChecksum:applicationDataChecksum];
    if (!result) {
        PXV4Fail(error, PXBackupManifestV4ErrorSnapshotFailed,
                 @"$", @"The manifest snapshot could not be retained");
        return PXV4FailureResult(error);
    }
    if (error) *error = nil;
    return result;
    } @catch (NSException *exception) {
        (void)exception;
        PXV4Fail(error,
                 PXBackupManifestV4ErrorInvalidFieldValue,
                 @"$.fields",
                 @"A manifest field or component is invalid");
        return nil;
    }
}

- (instancetype)initWithBackupIdentifier:(NSString *)backupIdentifier
                   manifestRepresentation:(NSDictionary<NSString *,id> *)representation
                            artifactCount:(NSUInteger)artifactCount
                                 totalSize:(unsigned long long)totalSize
                   applicationDataChecksum:(NSString *)checksum {
    self = [super init];
    if (self) {
        _backupIdentifier = [backupIdentifier copy];
        _manifestRepresentation = [representation copy];
        _artifactCount = artifactCount;
        _totalSize = totalSize;
        _applicationDataChecksum = [checksum copy];
    }
    return self;
}

- (NSString *)backupIdentifier { return _backupIdentifier; }
- (NSDictionary<NSString *,id> *)manifestRepresentation { return _manifestRepresentation; }
- (NSUInteger)artifactCount { return _artifactCount; }
- (unsigned long long)totalSize { return _totalSize; }
- (NSString *)applicationDataChecksum { return _applicationDataChecksum; }
- (id)copyWithZone:(NSZone *)zone { (void)zone; return self; }

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isMemberOfClass:[PXBackupManifestV4 class]]) return NO;
    PXBackupManifestV4 *other = object;
    return self.artifactCount == other.artifactCount &&
           self.totalSize == other.totalSize &&
           [self.backupIdentifier isEqualToString:other.backupIdentifier] &&
           [self.manifestRepresentation isEqual:other.manifestRepresentation] &&
           [self.applicationDataChecksum isEqualToString:other.applicationDataChecksum];
}

- (NSUInteger)hash {
    NSUInteger value = self.backupIdentifier.hash;
    value ^= self.manifestRepresentation.hash + (NSUInteger)0x9e3779b9 + (value << 6) + (value >> 2);
    value ^= self.artifactCount + (NSUInteger)0x9e3779b9 + (value << 6) + (value >> 2);
    value ^= (NSUInteger)self.totalSize + (NSUInteger)0x9e3779b9 + (value << 6) + (value >> 2);
    value ^= self.applicationDataChecksum.hash + (NSUInteger)0x9e3779b9 + (value << 6) + (value >> 2);
    return value;
}

@end
