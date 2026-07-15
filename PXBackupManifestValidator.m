#import "PXBackupManifestValidator.h"

NSString * const PXBackupManifestValidatorErrorDomain =
    @"PXBackupManifestValidatorErrorDomain";

NSString * const PXBackupManifestValidatorErrorFieldPathKey =
    @"PXBackupManifestValidatorErrorFieldPath";

static const NSUInteger PXBackupManifestMaximumContainerDepth = 32;
static const NSUInteger PXBackupManifestMaximumVisitedObjects = 100000;
static const NSUInteger PXBackupManifestMaximumContainerEntries = 10000;

static BOOL PXManifestFail(NSError **error,
                           PXBackupManifestValidatorErrorCode code,
                           NSString *fieldPath,
                           NSString *description) {
    if (error) {
        *error = [NSError errorWithDomain:PXBackupManifestValidatorErrorDomain
                                     code:code
                                 userInfo:@{
            NSLocalizedDescriptionKey: description,
            PXBackupManifestValidatorErrorFieldPathKey: fieldPath
        }];
    }
    return NO;
}

static NSString *PXManifestFieldPath(NSString *parent, NSString *field) {
    return [[parent stringByAppendingString:@"."] stringByAppendingString:field];
}

static NSString *PXManifestIndexedPath(NSString *parent, NSUInteger index) {
    NSString *indexText = [@(index) stringValue];
    NSString *prefix = [parent stringByAppendingString:@"["];
    return [[prefix stringByAppendingString:indexText] stringByAppendingString:@"]"];
}

static BOOL PXManifestStringContainsNUL(NSString *value) {
    for (NSUInteger index = 0; index < value.length; index++) {
        if ([value characterAtIndex:index] == 0) {
            return YES;
        }
    }
    return NO;
}

static BOOL PXManifestStringHasNonWhitespace(NSString *value) {
    NSCharacterSet *nonWhitespace =
        [[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
    return [value rangeOfCharacterFromSet:nonWhitespace].location != NSNotFound;
}

static BOOL PXManifestValidateRequiredString(id value,
                                             NSString *fieldPath,
                                             NSError **error) {
    if (![value isKindOfClass:[NSString class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              fieldPath,
                              @"The field must be a string.");
    }

    NSString *stringValue = (NSString *)value;
    if (stringValue.length == 0 ||
        !PXManifestStringHasNonWhitespace(stringValue) ||
        PXManifestStringContainsNUL(stringValue)) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldValue,
                              fieldPath,
                              @"The field must be nonempty, contain non-whitespace text, and contain no NUL character.");
    }

    return YES;
}

static BOOL PXManifestValidateOptionalString(id value,
                                             NSString *fieldPath,
                                             NSError **error) {
    if (![value isKindOfClass:[NSString class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              fieldPath,
                              @"The field must be a string.");
    }

    if (PXManifestStringContainsNUL((NSString *)value)) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldValue,
                              fieldPath,
                              @"The field must contain no NUL character.");
    }

    return YES;
}

static BOOL PXManifestIsExactBoolean(id value) {
    if (![value isKindOfClass:[NSNumber class]]) {
        return NO;
    }
    return CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

static BOOL PXManifestValidateBoolean(id value,
                                      NSString *fieldPath,
                                      NSError **error) {
    if (!PXManifestIsExactBoolean(value)) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              fieldPath,
                              @"The field must be an exact Boolean value.");
    }
    return YES;
}

static BOOL PXManifestExtractIntegralNumber(id value,
                                            NSString *fieldPath,
                                            unsigned long long *magnitude,
                                            NSError **error) {
    if (![value isKindOfClass:[NSNumber class]] || PXManifestIsExactBoolean(value)) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              fieldPath,
                              @"The field must be a non-Boolean integral number.");
    }

    NSNumber *number = (NSNumber *)value;
    const char *type = number.objCType;
    if (!type || type[0] == '\0' || type[1] != '\0') {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              fieldPath,
                              @"The field must use an integral Objective-C numeric type.");
    }

    switch (type[0]) {
        case 'c':
        case 's':
        case 'i':
        case 'l':
        case 'q': {
            long long signedValue = number.longLongValue;
            if (signedValue < 0) {
                return PXManifestFail(error,
                                      PXBackupManifestValidatorErrorInvalidFieldValue,
                                      fieldPath,
                                      @"The field must not be negative.");
            }
            if (magnitude) {
                *magnitude = (unsigned long long)signedValue;
            }
            return YES;
        }
        case 'C':
        case 'S':
        case 'I':
        case 'L':
        case 'Q':
            if (magnitude) {
                *magnitude = number.unsignedLongLongValue;
            }
            return YES;
        default:
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorInvalidFieldType,
                                  fieldPath,
                                  @"The field must use an integral Objective-C numeric type.");
    }
}

static BOOL PXManifestValidatePositiveVersion(id value,
                                              NSString *fieldPath,
                                              NSError **error) {
    unsigned long long magnitude = 0;
    if (!PXManifestExtractIntegralNumber(value, fieldPath, &magnitude, error)) {
        return NO;
    }
    if (magnitude == 0 || magnitude > (unsigned long long)NSIntegerMax) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldValue,
                              fieldPath,
                              @"The manifest version must be positive and fit within NSInteger.");
    }
    return YES;
}

static BOOL PXManifestValidateNonnegativeIntegral(id value,
                                                  NSString *fieldPath,
                                                  unsigned long long *magnitude,
                                                  NSError **error) {
    return PXManifestExtractIntegralNumber(value, fieldPath, magnitude, error);
}

static BOOL PXManifestConsumeVisited(NSUInteger amount,
                                     NSUInteger *visited,
                                     NSError **error) {
    if (amount > PXBackupManifestMaximumVisitedObjects - *visited) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldValue,
                              @"$",
                              @"The manifest graph exceeds the visited-object limit.");
    }
    *visited += amount;
    return YES;
}

static BOOL PXManifestValidateGraphObject(id object,
                                          NSUInteger containerDepth,
                                          NSUInteger *visited,
                                          NSHashTable *activeContainers,
                                          NSError **error) {
    if (!PXManifestConsumeVisited(1, visited, error)) {
        return NO;
    }

    BOOL isDictionary = [object isKindOfClass:[NSDictionary class]];
    BOOL isArray = [object isKindOfClass:[NSArray class]];

    if (!isDictionary && !isArray) {
        if ([object isKindOfClass:[NSString class]] ||
            [object isKindOfClass:[NSNumber class]] ||
            [object isKindOfClass:[NSDate class]] ||
            [object isKindOfClass:[NSData class]]) {
            return YES;
        }
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              @"$",
                              @"The manifest graph contains an unsupported value type.");
    }

    if (containerDepth > PXBackupManifestMaximumContainerDepth) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldValue,
                              @"$",
                              @"The manifest graph exceeds the container-depth limit.");
    }

    NSUInteger entryCount = isDictionary
        ? ((NSDictionary *)object).count
        : ((NSArray *)object).count;
    if (entryCount > PXBackupManifestMaximumContainerEntries) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldValue,
                              @"$",
                              @"A manifest container exceeds the entry-count limit.");
    }

    if ([activeContainers containsObject:object]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldValue,
                              @"$",
                              @"The manifest graph contains a container cycle.");
    }

    [activeContainers addObject:object];

    if (isArray) {
        NSArray *array = (NSArray *)object;
        for (id value in array) {
            if (!PXManifestValidateGraphObject(value,
                                               containerDepth + 1,
                                               visited,
                                               activeContainers,
                                               error)) {
                [activeContainers removeObject:object];
                return NO;
            }
        }
        [activeContainers removeObject:object];
        return YES;
    }

    NSDictionary *dictionary = (NSDictionary *)object;
    NSArray *allKeys = dictionary.allKeys;
    if (!PXManifestConsumeVisited(allKeys.count, visited, error)) {
        [activeContainers removeObject:object];
        return NO;
    }

    for (id key in allKeys) {
        if (![key isKindOfClass:[NSString class]]) {
            [activeContainers removeObject:object];
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorInvalidFieldType,
                                  @"$",
                                  @"Every manifest dictionary key must be a string.");
        }
    }

    NSArray<NSString *> *sortedKeys =
        [(NSArray<NSString *> *)allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *key in sortedKeys) {
        if (key.length == 0 ||
            !PXManifestStringHasNonWhitespace(key) ||
            PXManifestStringContainsNUL(key)) {
            [activeContainers removeObject:object];
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorInvalidFieldValue,
                                  @"$",
                                  @"Every manifest dictionary key must be nonempty, contain non-whitespace text, and contain no NUL character.");
        }

        id value = [dictionary objectForKey:key];
        if (!PXManifestValidateGraphObject(value,
                                           containerDepth + 1,
                                           visited,
                                           activeContainers,
                                           error)) {
            [activeContainers removeObject:object];
            return NO;
        }
    }

    [activeContainers removeObject:object];
    return YES;
}

static BOOL PXManifestRequireKeys(NSDictionary *dictionary,
                                  NSArray<NSString *> *keys,
                                  NSString *parentPath,
                                  NSError **error) {
    for (NSString *key in keys) {
        if ([dictionary objectForKey:key] == nil) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorMissingRequiredField,
                                  PXManifestFieldPath(parentPath, key),
                                  @"A required manifest field is missing.");
        }
    }
    return YES;
}

static BOOL PXManifestValidateStringArray(id value,
                                          NSString *fieldPath,
                                          BOOL rejectDuplicates,
                                          NSSet<NSString *> **validatedSet,
                                          NSError **error) {
    if (![value isKindOfClass:[NSArray class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              fieldPath,
                              @"The field must be an array.");
    }

    NSArray *array = (NSArray *)value;
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (NSUInteger index = 0; index < array.count; index++) {
        NSString *itemPath = PXManifestIndexedPath(fieldPath, index);
        id item = array[index];
        if (!PXManifestValidateRequiredString(item, itemPath, error)) {
            return NO;
        }

        NSString *stringItem = (NSString *)item;
        if (rejectDuplicates && [seen containsObject:stringItem]) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorDuplicateEntry,
                                  itemPath,
                                  @"The array contains an exact duplicate entry.");
        }
        [seen addObject:stringItem];
    }

    if (validatedSet) {
        *validatedSet = [seen copy];
    }
    return YES;
}

static BOOL PXManifestValidateDataSection(id value, NSError **error) {
    NSString *sectionPath = @"$.data";
    if (![value isKindOfClass:[NSDictionary class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              sectionPath,
                              @"The data section must be a dictionary.");
    }

    NSDictionary *section = (NSDictionary *)value;
    if (!PXManifestRequireKeys(section,
                               @[@"uuid", @"archive", @"containerPath"],
                               sectionPath,
                               error)) {
        return NO;
    }

    return PXManifestValidateRequiredString(section[@"uuid"], @"$.data.uuid", error) &&
           PXManifestValidateRequiredString(section[@"archive"], @"$.data.archive", error) &&
           PXManifestValidateRequiredString(section[@"containerPath"], @"$.data.containerPath", error);
}

static BOOL PXManifestValidateApplicationGroups(id value, NSError **error) {
    return PXManifestValidateStringArray(value,
                                         @"$.applicationGroups",
                                         YES,
                                         NULL,
                                         error);
}

static BOOL PXManifestValidateAppGroups(id value, NSError **error) {
    NSString *sectionPath = @"$.appGroups";
    if (![value isKindOfClass:[NSArray class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              sectionPath,
                              @"The appGroups section must be an array.");
    }

    NSArray *entries = (NSArray *)value;
    NSMutableSet<NSString *> *groupIdentifiers = [NSMutableSet set];
    NSMutableSet<NSString *> *archives = [NSMutableSet set];

    for (NSUInteger index = 0; index < entries.count; index++) {
        NSString *entryPath = PXManifestIndexedPath(sectionPath, index);
        id rawEntry = entries[index];
        if (![rawEntry isKindOfClass:[NSDictionary class]]) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorInvalidFieldType,
                                  entryPath,
                                  @"Each appGroups entry must be a dictionary.");
        }

        NSDictionary *entry = (NSDictionary *)rawEntry;
        if (!PXManifestRequireKeys(entry,
                                   @[@"groupID", @"uuid", @"archive"],
                                   entryPath,
                                   error)) {
            return NO;
        }

        NSString *groupPath = PXManifestFieldPath(entryPath, @"groupID");
        if (!PXManifestValidateRequiredString(entry[@"groupID"], groupPath, error)) {
            return NO;
        }
        NSString *groupIdentifier = entry[@"groupID"];
        if ([groupIdentifiers containsObject:groupIdentifier]) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorDuplicateEntry,
                                  groupPath,
                                  @"The appGroups section contains a duplicate group identifier.");
        }
        [groupIdentifiers addObject:groupIdentifier];

        if (!PXManifestValidateRequiredString(entry[@"uuid"],
                                              PXManifestFieldPath(entryPath, @"uuid"),
                                              error)) {
            return NO;
        }

        NSString *archivePath = PXManifestFieldPath(entryPath, @"archive");
        if (!PXManifestValidateRequiredString(entry[@"archive"], archivePath, error)) {
            return NO;
        }
        NSString *archive = entry[@"archive"];
        if ([archives containsObject:archive]) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorDuplicateEntry,
                                  archivePath,
                                  @"The appGroups section contains a duplicate archive reference.");
        }
        [archives addObject:archive];
    }

    return YES;
}

static BOOL PXManifestValidatePreferences(id value, NSError **error) {
    NSString *sectionPath = @"$.preferences";
    if (![value isKindOfClass:[NSDictionary class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              sectionPath,
                              @"The preferences section must be a dictionary.");
    }

    NSDictionary *section = (NSDictionary *)value;
    if (!PXManifestRequireKeys(section, @[@"included", @"archive"], sectionPath, error)) {
        return NO;
    }

    return PXManifestValidateBoolean(section[@"included"], @"$.preferences.included", error) &&
           PXManifestValidateRequiredString(section[@"archive"], @"$.preferences.archive", error);
}

static BOOL PXManifestValidateKeychain(id value, NSError **error) {
    NSString *sectionPath = @"$.keychain";
    if (![value isKindOfClass:[NSDictionary class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              sectionPath,
                              @"The keychain section must be a dictionary.");
    }

    NSDictionary *section = (NSDictionary *)value;
    if (!PXManifestRequireKeys(section,
                               @[@"included", @"archive", @"groupsSelected"],
                               sectionPath,
                               error)) {
        return NO;
    }

    if (!PXManifestValidateBoolean(section[@"included"], @"$.keychain.included", error) ||
        !PXManifestValidateOptionalString(section[@"archive"], @"$.keychain.archive", error) ||
        !PXManifestValidateStringArray(section[@"groupsSelected"],
                                       @"$.keychain.groupsSelected",
                                       YES,
                                       NULL,
                                       error)) {
        return NO;
    }

    id method = section[@"method"];
    if (method && !PXManifestValidateOptionalString(method, @"$.keychain.method", error)) {
        return NO;
    }

    if ([(NSNumber *)section[@"included"] boolValue] &&
        !PXManifestStringHasNonWhitespace(section[@"archive"])) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInconsistentField,
                              @"$.keychain.archive",
                              @"An included keychain section requires a nonempty archive reference.");
    }

    return YES;
}

static BOOL PXManifestValidateOptionalArchiveSection(id value,
                                                     NSString *sectionPath,
                                                     NSError **error) {
    if (![value isKindOfClass:[NSDictionary class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              sectionPath,
                              @"The section must be a dictionary.");
    }

    NSDictionary *section = (NSDictionary *)value;
    if (!PXManifestRequireKeys(section,
                               @[@"included", @"archive", @"path"],
                               sectionPath,
                               error)) {
        return NO;
    }

    NSString *includedPath = PXManifestFieldPath(sectionPath, @"included");
    NSString *archivePath = PXManifestFieldPath(sectionPath, @"archive");
    NSString *valuePath = PXManifestFieldPath(sectionPath, @"path");
    if (!PXManifestValidateBoolean(section[@"included"], includedPath, error) ||
        !PXManifestValidateOptionalString(section[@"archive"], archivePath, error) ||
        !PXManifestValidateOptionalString(section[@"path"], valuePath, error)) {
        return NO;
    }

    if ([(NSNumber *)section[@"included"] boolValue]) {
        if (!PXManifestStringHasNonWhitespace(section[@"archive"])) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorInconsistentField,
                                  archivePath,
                                  @"An included section requires a nonempty archive reference.");
        }
        if (!PXManifestStringHasNonWhitespace(section[@"path"])) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorInconsistentField,
                                  valuePath,
                                  @"An included section requires a nonempty recorded path.");
        }
    }

    return YES;
}

static BOOL PXManifestValidateArtifacts(id value,
                                        NSUInteger *artifactCount,
                                        NSError **error) {
    NSString *sectionPath = @"$.artifacts";
    if (![value isKindOfClass:[NSArray class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              sectionPath,
                              @"The artifacts section must be an array.");
    }

    NSArray *entries = (NSArray *)value;
    NSMutableSet<NSString *> *names = [NSMutableSet set];
    NSMutableSet<NSString *> *paths = [NSMutableSet set];

    for (NSUInteger index = 0; index < entries.count; index++) {
        NSString *entryPath = PXManifestIndexedPath(sectionPath, index);
        id rawEntry = entries[index];
        if (![rawEntry isKindOfClass:[NSDictionary class]]) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorInvalidFieldType,
                                  entryPath,
                                  @"Each artifact entry must be a dictionary.");
        }

        NSDictionary *entry = (NSDictionary *)rawEntry;
        if (!PXManifestRequireKeys(entry,
                                   @[@"name", @"path", @"size", @"sha256"],
                                   entryPath,
                                   error)) {
            return NO;
        }

        NSString *namePath = PXManifestFieldPath(entryPath, @"name");
        if (!PXManifestValidateRequiredString(entry[@"name"], namePath, error)) {
            return NO;
        }
        NSString *name = entry[@"name"];
        if ([names containsObject:name]) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorDuplicateEntry,
                                  namePath,
                                  @"The artifacts section contains a duplicate name.");
        }
        [names addObject:name];

        NSString *recordedPath = PXManifestFieldPath(entryPath, @"path");
        if (!PXManifestValidateRequiredString(entry[@"path"], recordedPath, error)) {
            return NO;
        }
        NSString *pathValue = entry[@"path"];
        if ([paths containsObject:pathValue]) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorDuplicateEntry,
                                  recordedPath,
                                  @"The artifacts section contains a duplicate path.");
        }
        [paths addObject:pathValue];

        if (!PXManifestValidateNonnegativeIntegral(entry[@"size"],
                                                   PXManifestFieldPath(entryPath, @"size"),
                                                   NULL,
                                                   error) ||
            !PXManifestValidateOptionalString(entry[@"sha256"],
                                              PXManifestFieldPath(entryPath, @"sha256"),
                                              error)) {
            return NO;
        }
    }

    if (artifactCount) {
        *artifactCount = entries.count;
    }
    return YES;
}

static BOOL PXManifestValidateOptions(id value, NSError **error) {
    NSString *sectionPath = @"$.options";
    if (![value isKindOfClass:[NSDictionary class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              sectionPath,
                              @"The options section must be a dictionary.");
    }

    NSDictionary *section = (NSDictionary *)value;
    NSArray<NSString *> *keys = @[
        @"includeAppGroups",
        @"includePreferences",
        @"includeKeychain"
    ];
    if (!PXManifestRequireKeys(section, keys, sectionPath, error)) {
        return NO;
    }

    for (NSString *key in keys) {
        if (!PXManifestValidateBoolean(section[key],
                                       PXManifestFieldPath(sectionPath, key),
                                       error)) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXManifestValidateRestoreCompatibility(id value,
                                                   NSString *rootBundleIdentifier,
                                                   NSError **error) {
    NSString *sectionPath = @"$.restoreCompatibility";
    if (![value isKindOfClass:[NSDictionary class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              sectionPath,
                              @"The restoreCompatibility section must be a dictionary.");
    }

    NSDictionary *section = (NSDictionary *)value;
    if (!PXManifestRequireKeys(section,
                               @[@"targetBundleID",
                                 @"requiresSameBundleID",
                                 @"requiresInstalledAppContainer",
                                 @"notes"],
                               sectionPath,
                               error)) {
        return NO;
    }

    if (!PXManifestValidateRequiredString(section[@"targetBundleID"],
                                          @"$.restoreCompatibility.targetBundleID",
                                          error) ||
        !PXManifestValidateBoolean(section[@"requiresSameBundleID"],
                                   @"$.restoreCompatibility.requiresSameBundleID",
                                   error) ||
        !PXManifestValidateBoolean(section[@"requiresInstalledAppContainer"],
                                   @"$.restoreCompatibility.requiresInstalledAppContainer",
                                   error) ||
        !PXManifestValidateStringArray(section[@"notes"],
                                       @"$.restoreCompatibility.notes",
                                       NO,
                                       NULL,
                                       error)) {
        return NO;
    }

    if (![section[@"targetBundleID"] isEqualToString:rootBundleIdentifier]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInconsistentField,
                              @"$.restoreCompatibility.targetBundleID",
                              @"The compatibility target must exactly match the manifest bundle identifier.");
    }

    return YES;
}

static BOOL PXManifestValidateSystemGlobalLibrary(id value, NSError **error) {
    NSString *sectionPath = @"$.systemGlobalLibrary";
    if (![value isKindOfClass:[NSDictionary class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              sectionPath,
                              @"The systemGlobalLibrary section must be a dictionary.");
    }

    NSDictionary *section = (NSDictionary *)value;
    if (!PXManifestRequireKeys(section, @[@"included", @"items"], sectionPath, error)) {
        return NO;
    }
    if (!PXManifestValidateBoolean(section[@"included"],
                                   @"$.systemGlobalLibrary.included",
                                   error)) {
        return NO;
    }
    if (![section[@"items"] isKindOfClass:[NSArray class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              @"$.systemGlobalLibrary.items",
                              @"The items field must be an array.");
    }

    NSArray *items = section[@"items"];
    NSMutableSet<NSString *> *subdirectories = [NSMutableSet set];
    NSMutableSet<NSString *> *archives = [NSMutableSet set];
    for (NSUInteger index = 0; index < items.count; index++) {
        NSString *itemPath = PXManifestIndexedPath(@"$.systemGlobalLibrary.items", index);
        id rawItem = items[index];
        if (![rawItem isKindOfClass:[NSDictionary class]]) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorInvalidFieldType,
                                  itemPath,
                                  @"Each systemGlobalLibrary item must be a dictionary.");
        }

        NSDictionary *item = (NSDictionary *)rawItem;
        if (!PXManifestRequireKeys(item, @[@"subdir", @"archive"], itemPath, error)) {
            return NO;
        }

        NSString *subdirPath = PXManifestFieldPath(itemPath, @"subdir");
        if (!PXManifestValidateRequiredString(item[@"subdir"], subdirPath, error)) {
            return NO;
        }
        NSString *subdir = item[@"subdir"];
        if ([subdirectories containsObject:subdir]) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorDuplicateEntry,
                                  subdirPath,
                                  @"The systemGlobalLibrary section contains a duplicate subdirectory.");
        }
        [subdirectories addObject:subdir];

        NSString *archivePath = PXManifestFieldPath(itemPath, @"archive");
        if (!PXManifestValidateRequiredString(item[@"archive"], archivePath, error)) {
            return NO;
        }
        NSString *archive = item[@"archive"];
        if ([archives containsObject:archive]) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorDuplicateEntry,
                                  archivePath,
                                  @"The systemGlobalLibrary section contains a duplicate archive reference.");
        }
        [archives addObject:archive];
    }

    BOOL included = [(NSNumber *)section[@"included"] boolValue];
    if ((included && items.count == 0) || (!included && items.count != 0)) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInconsistentField,
                              @"$.systemGlobalLibrary.items",
                              @"The items count is inconsistent with the included flag.");
    }
    return YES;
}

static BOOL PXManifestValidateSharedSystemDB(id value, NSError **error) {
    NSString *sectionPath = @"$.sharedSystemDB";
    if (![value isKindOfClass:[NSDictionary class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              sectionPath,
                              @"The sharedSystemDB section must be a dictionary.");
    }

    NSDictionary *section = (NSDictionary *)value;
    if (!PXManifestRequireKeys(section, @[@"included", @"files"], sectionPath, error)) {
        return NO;
    }
    if (!PXManifestValidateBoolean(section[@"included"],
                                   @"$.sharedSystemDB.included",
                                   error)) {
        return NO;
    }
    if (![section[@"files"] isKindOfClass:[NSArray class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              @"$.sharedSystemDB.files",
                              @"The files field must be an array.");
    }

    NSArray *files = section[@"files"];
    NSMutableSet<NSString *> *relativeLocations = [NSMutableSet set];
    NSMutableSet<NSString *> *archives = [NSMutableSet set];
    for (NSUInteger index = 0; index < files.count; index++) {
        NSString *itemPath = PXManifestIndexedPath(@"$.sharedSystemDB.files", index);
        id rawItem = files[index];
        if (![rawItem isKindOfClass:[NSDictionary class]]) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorInvalidFieldType,
                                  itemPath,
                                  @"Each sharedSystemDB entry must be a dictionary.");
        }

        NSDictionary *item = (NSDictionary *)rawItem;
        if (!PXManifestRequireKeys(item, @[@"libraryRel", @"archive"], itemPath, error)) {
            return NO;
        }

        NSString *relativePath = PXManifestFieldPath(itemPath, @"libraryRel");
        if (!PXManifestValidateRequiredString(item[@"libraryRel"], relativePath, error)) {
            return NO;
        }
        NSString *relativeLocation = item[@"libraryRel"];
        if ([relativeLocations containsObject:relativeLocation]) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorDuplicateEntry,
                                  relativePath,
                                  @"The sharedSystemDB section contains a duplicate relative location.");
        }
        [relativeLocations addObject:relativeLocation];

        NSString *archivePath = PXManifestFieldPath(itemPath, @"archive");
        if (!PXManifestValidateRequiredString(item[@"archive"], archivePath, error)) {
            return NO;
        }
        NSString *archive = item[@"archive"];
        if ([archives containsObject:archive]) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorDuplicateEntry,
                                  archivePath,
                                  @"The sharedSystemDB section contains a duplicate archive reference.");
        }
        [archives addObject:archive];
    }

    BOOL included = [(NSNumber *)section[@"included"] boolValue];
    if ((included && files.count == 0) || (!included && files.count != 0)) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInconsistentField,
                              @"$.sharedSystemDB.files",
                              @"The files count is inconsistent with the included flag.");
    }
    return YES;
}



static BOOL PXManifestPeekPositiveVersion(id value,
                                          unsigned long long *magnitude) {
    if (![value isKindOfClass:[NSNumber class]] || PXManifestIsExactBoolean(value)) return NO;
    const char *type = [(NSNumber *)value objCType];
    if (!type || !type[0] || type[1]) return NO;
    unsigned long long result = 0;
    switch (type[0]) {
        case 'c': case 's': case 'i': case 'l': case 'q': {
            long long signedValue = [(NSNumber *)value longLongValue];
            if (signedValue <= 0) return NO;
            result = (unsigned long long)signedValue;
            break;
        }
        case 'C': case 'S': case 'I': case 'L': case 'Q':
            result = [(NSNumber *)value unsignedLongLongValue];
            if (result == 0) return NO;
            break;
        default:
            return NO;
    }
    if (result > (unsigned long long)NSIntegerMax) return NO;
    if (magnitude) *magnitude = result;
    return YES;
}

static BOOL PXManifestValidateGraphObjectV4(id object,
                                            NSUInteger depth,
                                            NSUInteger *visited,
                                            NSUInteger *dictionaryKeys,
                                            NSUInteger *arrayItems,
                                            NSHashTable *activeContainers,
                                            NSError **error) {
    if (*visited >= 500000) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldValue,
                              @"$",
                              @"The manifest v4 graph exceeds the visited-object limit.");
    }
    *visited += 1;
    if ([object isKindOfClass:[NSString class]]) {
        NSData *bytes = [(NSString *)object dataUsingEncoding:NSUTF8StringEncoding
                                         allowLossyConversion:NO];
        if (!bytes || bytes.length > 1024 * 1024 || PXManifestStringContainsNUL(object)) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorInvalidFieldValue,
                                  @"$",
                                  @"The manifest v4 graph contains an invalid string.");
        }
        return YES;
    }
    if ([object isKindOfClass:[NSNumber class]] ||
        [object isKindOfClass:[NSDate class]] ||
        [object isKindOfClass:[NSData class]]) return YES;
    BOOL dictionary = [object isKindOfClass:[NSDictionary class]];
    BOOL array = [object isKindOfClass:[NSArray class]];
    if (!dictionary && !array) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              @"$",
                              @"The manifest v4 graph contains an unsupported value type.");
    }
    if (depth > 64 || [activeContainers containsObject:object]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldValue,
                              @"$",
                              @"The manifest v4 graph exceeds depth limits or contains a cycle.");
    }
    [activeContainers addObject:object];
    if (array) {
        NSArray *values = object;
        if (values.count > 500000 - *arrayItems) {
            [activeContainers removeObject:object];
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorInvalidFieldValue,
                                  @"$",
                                  @"The manifest v4 graph exceeds the array-item limit.");
        }
        *arrayItems += values.count;
        for (id value in values) {
            if (!PXManifestValidateGraphObjectV4(value, depth + 1, visited,
                                                 dictionaryKeys, arrayItems,
                                                 activeContainers, error)) {
                [activeContainers removeObject:object];
                return NO;
            }
        }
    } else {
        NSDictionary *values = object;
        if (values.count > 100000 - *dictionaryKeys) {
            [activeContainers removeObject:object];
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorInvalidFieldValue,
                                  @"$",
                                  @"The manifest v4 graph exceeds the dictionary-key limit.");
        }
        *dictionaryKeys += values.count;
        for (id key in values.allKeys) {
            if (![key isKindOfClass:[NSString class]] ||
                !PXManifestValidateGraphObjectV4(key, depth + 1, visited,
                                                 dictionaryKeys, arrayItems,
                                                 activeContainers, error) ||
                !PXManifestValidateGraphObjectV4(values[key], depth + 1, visited,
                                                 dictionaryKeys, arrayItems,
                                                 activeContainers, error)) {
                [activeContainers removeObject:object];
                return NO;
            }
        }
    }
    [activeContainers removeObject:object];
    return YES;
}

static BOOL PXManifestExactKeys(NSDictionary *dictionary,
                                NSArray<NSString *> *keys,
                                NSString *fieldPath,
                                NSError **error) {
    if (![dictionary isKindOfClass:[NSDictionary class]] ||
        dictionary.count != keys.count ||
        ![[NSSet setWithArray:dictionary.allKeys] isEqualToSet:[NSSet setWithArray:keys]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInconsistentField,
                              fieldPath,
                              @"The manifest field set is invalid.");
    }
    return YES;
}

static BOOL PXManifestV4CanonicalUUID(id value) {
    if (![value isKindOfClass:[NSString class]] || [(NSString *)value length] != 36) return NO;
    NSString *text = value;
    NSData *bytes = [text dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO];
    if (!bytes || bytes.length != 36) return NO;
    for (NSUInteger index = 0; index < 36; index++) {
        unichar character = [text characterAtIndex:index];
        if (index == 8 || index == 13 || index == 18 || index == 23) {
            if (character != '-') return NO;
        } else if (!((character >= '0' && character <= '9') ||
                     (character >= 'a' && character <= 'f'))) return NO;
    }
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:text];
    return uuid && [uuid.UUIDString.lowercaseString isEqualToString:text];
}

static BOOL PXManifestV4Digest(id value) {
    if (![value isKindOfClass:[NSString class]] || [(NSString *)value length] != 64) return NO;
    for (NSUInteger index = 0; index < 64; index++) {
        unichar character = [(NSString *)value characterAtIndex:index];
        if (!((character >= '0' && character <= '9') ||
              (character >= 'a' && character <= 'f'))) return NO;
    }
    return YES;
}

static BOOL PXManifestV4RelativePath(id value) {
    if (!PXManifestValidateRequiredString(value, @"$", NULL)) return NO;
    NSString *path = value;
    NSData *bytes = [path dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if (!bytes || bytes.length == 0 || bytes.length > 4096 ||
        [path hasPrefix:@"/"] || [path hasSuffix:@"/"] || [path containsString:@"\\"]) return NO;
    NSArray<NSString *> *components = [path componentsSeparatedByString:@"/"];
    if (components.count == 0 || components.count > 32) return NO;
    for (NSString *component in components) {
        NSData *componentBytes = [component dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
        if (!componentBytes || componentBytes.length == 0 || componentBytes.length > 255 ||
            [component isEqualToString:@"."] || [component isEqualToString:@".."] ||
            [component isEqualToString:@".weaponx-backup.lock"] ||
            [component isEqualToString:@"manifest.plist"] ||
            [component hasPrefix:@".weaponx-backup-partial-"] ||
            [component hasPrefix:@".weaponx-artifact-partial-"] ||
            [component rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound) return NO;
    }
    return YES;
}

static NSInteger PXManifestV4KindOrder(NSString *kind) {
    NSArray *kinds = @[@"applicationData", @"appGroup", @"profileAppData",
                       @"globalSafari", @"systemGlobal", @"sharedSystemDatabase",
                       @"preferences", @"keychain"];
    NSUInteger index = [kinds indexOfObject:kind];
    return index == NSNotFound ? 0 : (NSInteger)index + 1;
}

static BOOL PXManifestV4PolicyMatches(NSDictionary *policy,
                                      unsigned long long size,
                                      NSInteger *kindOrder) {
    if (![policy isKindOfClass:[NSDictionary class]] ||
        policy.count != 4 ||
        ![[NSSet setWithArray:policy.allKeys] isEqualToSet:
          [NSSet setWithArray:@[@"kind", @"requirement", @"failureDisposition", @"emptyFilePolicy"]]]) return NO;
    NSString *kind = policy[@"kind"];
    NSInteger order = PXManifestV4KindOrder(kind);
    if (order == 0) return NO;
    NSString *requirement = policy[@"requirement"];
    NSString *disposition = policy[@"failureDisposition"];
    NSString *empty = policy[@"emptyFilePolicy"];
    BOOL valid = NO;
    switch (order) {
        case 1:
            valid = [requirement isEqualToString:@"required"] &&
                    [disposition isEqualToString:@"abortBackup"] &&
                    [empty isEqualToString:@"reject"];
            break;
        case 2: case 3: case 4: case 5:
            valid = [requirement isEqualToString:@"optional"] &&
                    [disposition isEqualToString:@"warnAndContinue"] &&
                    [empty isEqualToString:@"reject"];
            break;
        case 6:
            valid = [requirement isEqualToString:@"optional"] &&
                    [disposition isEqualToString:@"continueWithoutWarning"] &&
                    [empty isEqualToString:@"allow"];
            break;
        case 7: case 8:
            valid = [requirement isEqualToString:@"optional"] &&
                    [disposition isEqualToString:@"continueWithoutWarning"] &&
                    [empty isEqualToString:@"reject"];
            break;
    }
    if (!valid || (size == 0 && ![empty isEqualToString:@"allow"])) return NO;
    if (kindOrder) *kindOrder = order;
    return YES;
}

static BOOL PXManifestV4AddReference(NSMutableSet<NSString *> *references,
                                     NSDictionary<NSString *, NSNumber *> *kindByName,
                                     id name,
                                     NSInteger expectedKind,
                                     NSString *fieldPath,
                                     NSError **error) {
    if (!PXManifestV4RelativePath(name) || !kindByName[name]) {
        return PXManifestFail(error, PXBackupManifestValidatorErrorInconsistentField,
                              fieldPath, @"The artifact reference is missing.");
    }
    if (kindByName[name].integerValue != expectedKind) {
        return PXManifestFail(error, PXBackupManifestValidatorErrorInconsistentField,
                              fieldPath, @"The artifact reference policy is inconsistent.");
    }
    if ([references containsObject:name]) {
        return PXManifestFail(error, PXBackupManifestValidatorErrorDuplicateEntry,
                              fieldPath, @"The artifact reference is duplicated.");
    }
    [references addObject:name];
    return YES;
}

static BOOL PXManifestValidateV4(NSDictionary *manifest, NSError **error) {
    if (error && !*error) {
        PXManifestFail(error,
                       PXBackupManifestValidatorErrorInconsistentField,
                       @"$",
                       @"The manifest v4 structure is inconsistent.");
    }
    NSArray *rootKeys = @[
        @"manifestVersion", @"schema", @"backupID", @"publication", @"bundleID",
        @"appName", @"createdAt", @"timestamp", @"iosVersion", @"toolVersion",
        @"toolBuild", @"profileId", @"backupMode", @"sourceDataContainerPath",
        @"sourceDataContainerUUID", @"includedOptions", @"excludedOptions",
        @"artifactCount", @"totalSize", @"archiveChecksum", @"warnings",
        @"restoreCompatibility", @"data", @"applicationGroups", @"appGroups",
        @"preferences", @"keychain", @"profileAppData", @"globalSafari",
        @"systemGlobalLibrary", @"sharedSystemDB", @"artifacts", @"options"
    ];
    if (!PXManifestExactKeys(manifest, rootKeys, @"$", error)) return NO;
    NSDictionary *schema = manifest[@"schema"];
    NSDictionary *publication = manifest[@"publication"];
    unsigned long long schemaRevision = 0;
    if (!PXManifestExactKeys(schema, @[@"identifier", @"revision", @"digestAlgorithm"], @"$.schema", error) ||
        !PXManifestValidateNonnegativeIntegral(schema[@"revision"],
                                               @"$.schema.revision",
                                               &schemaRevision,
                                               error) ||
        schemaRevision != 1 ||
        ![schema[@"identifier"] isEqualToString:@"com.hydra.projectx.backup-manifest"] ||
        ![schema[@"digestAlgorithm"] isEqualToString:@"sha256"] ||
        !PXManifestExactKeys(publication, @[@"protocol", @"contentState"], @"$.publication", error) ||
        ![publication[@"protocol"] isEqualToString:@"atomic-directory-v1"] ||
        ![publication[@"contentState"] isEqualToString:@"complete"] ||
        !PXManifestV4CanonicalUUID(manifest[@"backupID"]) ||
        ![manifest[@"backupMode"] isEqualToString:@"strict"]) {
        return PXManifestFail(error, PXBackupManifestValidatorErrorInvalidFieldValue,
                              @"$", @"The manifest v4 schema metadata is invalid.");
    }
    if (!PXManifestValidateRequiredString(manifest[@"bundleID"], @"$.bundleID", error) ||
        !PXManifestValidateOptionalString(manifest[@"appName"], @"$.appName", error) ||
        ![manifest[@"createdAt"] isKindOfClass:[NSDate class]] ||
        !PXManifestValidateRequiredString(manifest[@"timestamp"], @"$.timestamp", error) ||
        !PXManifestValidateOptionalString(manifest[@"iosVersion"], @"$.iosVersion", error) ||
        !PXManifestValidateOptionalString(manifest[@"toolVersion"], @"$.toolVersion", error) ||
        !PXManifestValidateOptionalString(manifest[@"toolBuild"], @"$.toolBuild", error) ||
        !PXManifestValidateOptionalString(manifest[@"profileId"], @"$.profileId", error) ||
        !PXManifestValidateOptionalString(manifest[@"sourceDataContainerPath"], @"$.sourceDataContainerPath", error) ||
        !PXManifestValidateOptionalString(manifest[@"sourceDataContainerUUID"], @"$.sourceDataContainerUUID", error) ||
        !PXManifestValidateStringArray(manifest[@"warnings"], @"$.warnings", NO, NULL, error)) return NO;

    NSDictionary *restore = manifest[@"restoreCompatibility"];
    NSDictionary *data = manifest[@"data"];
    NSArray *applicationGroups = manifest[@"applicationGroups"];
    NSArray *appGroups = manifest[@"appGroups"];
    NSDictionary *preferences = manifest[@"preferences"];
    NSDictionary *keychain = manifest[@"keychain"];
    NSDictionary *profile = manifest[@"profileAppData"];
    NSDictionary *safari = manifest[@"globalSafari"];
    NSDictionary *system = manifest[@"systemGlobalLibrary"];
    NSDictionary *shared = manifest[@"sharedSystemDB"];
    NSDictionary *options = manifest[@"options"];
    if (!PXManifestExactKeys(restore, @[@"targetBundleID", @"requiresSameBundleID", @"requiresInstalledAppContainer", @"notes"], @"$.restoreCompatibility", error) ||
        ![restore[@"targetBundleID"] isEqualToString:manifest[@"bundleID"]] ||
        !PXManifestValidateBoolean(restore[@"requiresSameBundleID"], @"$.restoreCompatibility.requiresSameBundleID", error) ||
        !PXManifestValidateBoolean(restore[@"requiresInstalledAppContainer"], @"$.restoreCompatibility.requiresInstalledAppContainer", error) ||
        !PXManifestValidateStringArray(restore[@"notes"], @"$.restoreCompatibility.notes", NO, NULL, error) ||
        !PXManifestExactKeys(data, @[@"uuid", @"archive", @"containerPath"], @"$.data", error) ||
        !PXManifestValidateRequiredString(data[@"uuid"], @"$.data.uuid", error) ||
        !PXManifestV4RelativePath(data[@"archive"]) ||
        !PXManifestValidateRequiredString(data[@"containerPath"], @"$.data.containerPath", error) ||
        !PXManifestValidateStringArray(applicationGroups, @"$.applicationGroups", YES, NULL, error) ||
        ![appGroups isKindOfClass:[NSArray class]] ||
        !PXManifestExactKeys(preferences, @[@"included", @"archive"], @"$.preferences", error) ||
        !PXManifestExactKeys(keychain, @[@"included", @"archive", @"groupsSelected", @"method"], @"$.keychain", error) ||
        !PXManifestExactKeys(profile, @[@"included", @"archive", @"path"], @"$.profileAppData", error) ||
        !PXManifestExactKeys(safari, @[@"included", @"archive", @"path"], @"$.globalSafari", error) ||
        !PXManifestExactKeys(system, @[@"included", @"items"], @"$.systemGlobalLibrary", error) ||
        !PXManifestExactKeys(shared, @[@"included", @"files"], @"$.sharedSystemDB", error) ||
        !PXManifestExactKeys(options, @[@"includeAppGroups", @"includePreferences", @"includeKeychain"], @"$.options", error)) return NO;
    for (NSString *key in @[@"includeAppGroups", @"includePreferences", @"includeKeychain"]) {
        if (!PXManifestValidateBoolean(options[key], PXManifestFieldPath(@"$.options", key), error)) return NO;
    }

    NSArray *artifacts = manifest[@"artifacts"];
    if (![artifacts isKindOfClass:[NSArray class]] || artifacts.count < 1 || artifacts.count > 4096) {
        return PXManifestFail(error, PXBackupManifestValidatorErrorInvalidFieldValue,
                              @"$.artifacts", @"The artifacts section is invalid.");
    }
    NSMutableDictionary<NSString *, NSNumber *> *kindByName = [NSMutableDictionary dictionary];
    NSMutableSet *paths = [NSMutableSet set];
    unsigned long long actualTotal = 0;
    NSInteger previousKind = 0;
    NSUInteger requiredCount = 0, dataCount = 0, profileCount = 0, safariCount = 0, prefsCount = 0, keychainCount = 0;
    NSString *dataChecksum = nil;
    for (NSUInteger index = 0; index < artifacts.count; index++) {
        NSDictionary *artifact = artifacts[index];
        NSString *entryPath = PXManifestIndexedPath(@"$.artifacts", index);
        if (!PXManifestExactKeys(artifact, @[@"name", @"path", @"size", @"sha256", @"policy"], entryPath, error) ||
            !PXManifestV4RelativePath(artifact[@"name"]) ||
            ![artifact[@"path"] isEqualToString:artifact[@"name"]] ||
            !PXManifestV4Digest(artifact[@"sha256"]) || kindByName[artifact[@"name"]] ||
            [paths containsObject:artifact[@"path"]]) return NO;
        unsigned long long size = 0;
        if (!PXManifestValidateNonnegativeIntegral(artifact[@"size"], PXManifestFieldPath(entryPath, @"size"), &size, error)) return NO;
        NSInteger kind = 0;
        if (!PXManifestV4PolicyMatches(artifact[@"policy"], size, &kind) || kind < previousKind) {
            return PXManifestFail(error, PXBackupManifestValidatorErrorInconsistentField,
                                  PXManifestFieldPath(entryPath, @"policy"), @"The artifact policy or order is invalid.");
        }
        previousKind = kind;
        if (actualTotal > ULLONG_MAX - size) return PXManifestFail(error, PXBackupManifestValidatorErrorInvalidFieldValue, @"$.totalSize", @"The total artifact size overflowed.");
        actualTotal += size;
        NSString *requirement = artifact[@"policy"][@"requirement"];
        if ([requirement isEqualToString:@"required"]) requiredCount += 1;
        if (kind == 1) { dataCount += 1; dataChecksum = artifact[@"sha256"]; if (index != 0) return NO; }
        if (kind == 3) profileCount += 1; if (kind == 4) safariCount += 1;
        if (kind == 7) prefsCount += 1; if (kind == 8) keychainCount += 1;
        kindByName[artifact[@"name"]] = @(kind); [paths addObject:artifact[@"path"]];
    }
    unsigned long long declaredCount = 0, declaredTotal = 0;
    if (dataCount != 1 || requiredCount != 1 || profileCount > 1 || safariCount > 1 || prefsCount > 1 || keychainCount > 1 ||
        !PXManifestValidateNonnegativeIntegral(manifest[@"artifactCount"], @"$.artifactCount", &declaredCount, error) ||
        declaredCount != artifacts.count ||
        !PXManifestValidateNonnegativeIntegral(manifest[@"totalSize"], @"$.totalSize", &declaredTotal, error) ||
        declaredTotal != actualTotal || ![manifest[@"archiveChecksum"] isEqualToString:dataChecksum]) return NO;

    NSMutableSet *references = [NSMutableSet set];
    if (!PXManifestV4AddReference(references, kindByName, data[@"archive"], 1, @"$.data.archive", error)) return NO;
    NSSet *applicationGroupSet = [NSSet setWithArray:applicationGroups];
    NSMutableSet *groupIDs = [NSMutableSet set];
    for (NSUInteger index = 0; index < appGroups.count; index++) {
        NSDictionary *item = appGroups[index];
        NSString *itemPath = PXManifestIndexedPath(@"$.appGroups", index);
        if (!PXManifestExactKeys(item, @[@"groupID", @"uuid", @"archive"], itemPath, error) ||
            !PXManifestValidateRequiredString(item[@"groupID"], PXManifestFieldPath(itemPath, @"groupID"), error) ||
            !PXManifestValidateRequiredString(item[@"uuid"], PXManifestFieldPath(itemPath, @"uuid"), error) ||
            ![applicationGroupSet containsObject:item[@"groupID"]] || [groupIDs containsObject:item[@"groupID"]] ||
            !PXManifestV4AddReference(references, kindByName, item[@"archive"], 2, PXManifestFieldPath(itemPath, @"archive"), error)) return NO;
        [groupIDs addObject:item[@"groupID"]];
    }
    if (![options[@"includeAppGroups"] boolValue] && appGroups.count != 0) return NO;
    BOOL prefsIncluded = [preferences[@"included"] boolValue];
    if (!PXManifestValidateBoolean(preferences[@"included"], @"$.preferences.included", error) ||
        !PXManifestValidateOptionalString(preferences[@"archive"], @"$.preferences.archive", error) ||
        (prefsIncluded && !PXManifestV4AddReference(references, kindByName, preferences[@"archive"], 7, @"$.preferences.archive", error)) ||
        (!prefsIncluded && ![preferences[@"archive"] isEqualToString:@""]) ||
        (![options[@"includePreferences"] boolValue] && prefsIncluded)) return NO;
    BOOL keychainIncluded = [keychain[@"included"] boolValue];
    if (!PXManifestValidateBoolean(keychain[@"included"], @"$.keychain.included", error) ||
        !PXManifestValidateOptionalString(keychain[@"archive"], @"$.keychain.archive", error) ||
        !PXManifestValidateOptionalString(keychain[@"method"], @"$.keychain.method", error) ||
        !PXManifestValidateStringArray(keychain[@"groupsSelected"], @"$.keychain.groupsSelected", YES, NULL, error) ||
        (keychainIncluded && (!PXManifestStringHasNonWhitespace(keychain[@"method"]) ||
         !PXManifestV4AddReference(references, kindByName, keychain[@"archive"], 8, @"$.keychain.archive", error))) ||
        (!keychainIncluded && (![(NSString *)keychain[@"archive"] isEqualToString:@""] || ![(NSString *)keychain[@"method"] isEqualToString:@""])) ||
        (![options[@"includeKeychain"] boolValue] && keychainIncluded)) return NO;
    NSArray *singleSections = @[profile, safari]; NSArray *singleKinds = @[@3, @4]; NSArray *singlePaths = @[@"$.profileAppData", @"$.globalSafari"];
    for (NSUInteger index = 0; index < 2; index++) {
        NSDictionary *section = singleSections[index]; BOOL included = [section[@"included"] boolValue]; NSString *path = singlePaths[index];
        if (!PXManifestValidateBoolean(section[@"included"], PXManifestFieldPath(path, @"included"), error) ||
            !PXManifestValidateOptionalString(section[@"archive"], PXManifestFieldPath(path, @"archive"), error) ||
            !PXManifestValidateOptionalString(section[@"path"], PXManifestFieldPath(path, @"path"), error) ||
            (included && (!PXManifestStringHasNonWhitespace(section[@"path"]) || !PXManifestV4AddReference(references, kindByName, section[@"archive"], [singleKinds[index] integerValue], PXManifestFieldPath(path, @"archive"), error))) ||
            (!included && ![section[@"archive"] isEqualToString:@""])) return NO;
    }
    NSArray *systemItems = system[@"items"];
    if (!PXManifestValidateBoolean(system[@"included"], @"$.systemGlobalLibrary.included", error) || ![systemItems isKindOfClass:[NSArray class]] || ([system[@"included"] boolValue] != (systemItems.count > 0))) return NO;
    NSMutableSet *subdirs = [NSMutableSet set];
    for (NSUInteger index = 0; index < systemItems.count; index++) {
        NSDictionary *item = systemItems[index]; NSString *path = PXManifestIndexedPath(@"$.systemGlobalLibrary.items", index);
        if (!PXManifestExactKeys(item, @[@"subdir", @"archive"], path, error) || !PXManifestValidateRequiredString(item[@"subdir"], PXManifestFieldPath(path, @"subdir"), error) || [subdirs containsObject:item[@"subdir"]] || !PXManifestV4AddReference(references, kindByName, item[@"archive"], 5, PXManifestFieldPath(path, @"archive"), error)) return NO;
        [subdirs addObject:item[@"subdir"]];
    }
    NSArray *sharedFiles = shared[@"files"];
    if (!PXManifestValidateBoolean(shared[@"included"], @"$.sharedSystemDB.included", error) || ![sharedFiles isKindOfClass:[NSArray class]] || ([shared[@"included"] boolValue] != (sharedFiles.count > 0))) return NO;
    NSMutableSet *libraryRels = [NSMutableSet set];
    for (NSUInteger index = 0; index < sharedFiles.count; index++) {
        NSDictionary *item = sharedFiles[index]; NSString *path = PXManifestIndexedPath(@"$.sharedSystemDB.files", index);
        if (!PXManifestExactKeys(item, @[@"libraryRel", @"archive"], path, error) || !PXManifestValidateRequiredString(item[@"libraryRel"], PXManifestFieldPath(path, @"libraryRel"), error) || [libraryRels containsObject:item[@"libraryRel"]] || !PXManifestV4AddReference(references, kindByName, item[@"archive"], 6, PXManifestFieldPath(path, @"archive"), error)) return NO;
        [libraryRels addObject:item[@"libraryRel"]];
    }
    if (references.count != artifacts.count) return PXManifestFail(error, PXBackupManifestValidatorErrorInconsistentField, @"$.artifacts", @"The artifact reference coverage is incomplete.");
    NSMutableArray *expectedIncluded = [NSMutableArray arrayWithObject:@"DataContainer"];
    NSMutableArray *expectedExcluded = [NSMutableArray array];
    if (appGroups.count) [expectedIncluded addObject:@"AppGroups"]; else [expectedExcluded addObject:@"AppGroups"];
    if (prefsIncluded) [expectedIncluded addObject:@"GlobalPreferences"]; else [expectedExcluded addObject:@"GlobalPreferences"];
    if (keychainIncluded) [expectedIncluded addObject:@"Keychain"]; else [expectedExcluded addObject:@"Keychain"];
    if (![manifest[@"includedOptions"] isEqual:expectedIncluded] || ![manifest[@"excludedOptions"] isEqual:expectedExcluded]) return NO;
    if (error) *error = nil;
    return YES;
}

@implementation PXBackupManifestValidator

+ (BOOL)validateManifestObject:(nullable id)object
                         error:(NSError * _Nullable * _Nullable)error {
    if (error) {
        *error = nil;
    }

    if (![object isKindOfClass:[NSDictionary class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidRoot,
                              @"$",
                              @"The manifest root must be a dictionary.");
    }

    NSDictionary *manifest = (NSDictionary *)object;
    unsigned long long versionMagnitude = 0;
    BOOL hasPositiveVersion =
        PXManifestPeekPositiveVersion(manifest[@"manifestVersion"],
                                      &versionMagnitude);
    if (hasPositiveVersion && versionMagnitude == 4) {
        NSUInteger visitedV4 = 0;
        NSUInteger dictionaryKeysV4 = 0;
        NSUInteger arrayItemsV4 = 0;
        NSHashTable *activeV4 =
            [NSHashTable hashTableWithOptions:NSHashTableObjectPointerPersonality];
        if (!PXManifestValidateGraphObjectV4(object,
                                             1,
                                             &visitedV4,
                                             &dictionaryKeysV4,
                                             &arrayItemsV4,
                                             activeV4,
                                             error)) {
            return NO;
        }
        return PXManifestValidateV4(manifest, error);
    }
    NSUInteger visited = 0;
    NSHashTable *activeContainers =
        [NSHashTable hashTableWithOptions:NSHashTableObjectPointerPersonality];
    if (!PXManifestValidateGraphObject(object,
                                       1,
                                       &visited,
                                       activeContainers,
                                       error)) {
        return NO;
    }
    if (hasPositiveVersion && versionMagnitude != 2 && versionMagnitude != 3) {
        return YES;
    }
    NSArray<NSString *> *requiredRootKeys = @[
        @"manifestVersion",
        @"bundleID",
        @"appName",
        @"timestamp",
        @"iosVersion",
        @"profileId",
        @"data",
        @"applicationGroups",
        @"appGroups",
        @"preferences",
        @"keychain",
        @"profileAppData",
        @"globalSafari",
        @"artifacts",
        @"options"
    ];
    if (!PXManifestRequireKeys(manifest, requiredRootKeys, @"$", error)) {
        return NO;
    }

    if (!PXManifestValidatePositiveVersion(manifest[@"manifestVersion"],
                                           @"$.manifestVersion",
                                           error) ||
        !PXManifestValidateRequiredString(manifest[@"bundleID"],
                                          @"$.bundleID",
                                          error) ||
        !PXManifestValidateOptionalString(manifest[@"appName"],
                                          @"$.appName",
                                          error) ||
        !PXManifestValidateRequiredString(manifest[@"timestamp"],
                                          @"$.timestamp",
                                          error) ||
        !PXManifestValidateOptionalString(manifest[@"iosVersion"],
                                          @"$.iosVersion",
                                          error) ||
        !PXManifestValidateOptionalString(manifest[@"profileId"],
                                          @"$.profileId",
                                          error)) {
        return NO;
    }

    if (!PXManifestValidateDataSection(manifest[@"data"], error) ||
        !PXManifestValidateApplicationGroups(manifest[@"applicationGroups"], error) ||
        !PXManifestValidateAppGroups(manifest[@"appGroups"], error) ||
        !PXManifestValidatePreferences(manifest[@"preferences"], error) ||
        !PXManifestValidateKeychain(manifest[@"keychain"], error) ||
        !PXManifestValidateOptionalArchiveSection(manifest[@"profileAppData"],
                                                  @"$.profileAppData",
                                                  error) ||
        !PXManifestValidateOptionalArchiveSection(manifest[@"globalSafari"],
                                                  @"$.globalSafari",
                                                  error)) {
        return NO;
    }

    NSUInteger artifactCount = 0;
    if (!PXManifestValidateArtifacts(manifest[@"artifacts"], &artifactCount, error) ||
        !PXManifestValidateOptions(manifest[@"options"], error)) {
        return NO;
    }

    id createdAt = manifest[@"createdAt"];
    if (createdAt && ![createdAt isKindOfClass:[NSDate class]]) {
        return PXManifestFail(error,
                              PXBackupManifestValidatorErrorInvalidFieldType,
                              @"$.createdAt",
                              @"The createdAt field must be a date.");
    }

    NSArray<NSString *> *optionalStringFields = @[
        @"toolVersion",
        @"toolBuild"
    ];
    for (NSString *field in optionalStringFields) {
        id value = manifest[field];
        if (value && !PXManifestValidateOptionalString(value,
                                                       PXManifestFieldPath(@"$", field),
                                                       error)) {
            return NO;
        }
    }

    id backupMode = manifest[@"backupMode"];
    if (backupMode &&
        !PXManifestValidateRequiredString(backupMode, @"$.backupMode", error)) {
        return NO;
    }

    optionalStringFields = @[
        @"sourceDataContainerPath",
        @"sourceDataContainerUUID"
    ];
    for (NSString *field in optionalStringFields) {
        id value = manifest[field];
        if (value && !PXManifestValidateOptionalString(value,
                                                       PXManifestFieldPath(@"$", field),
                                                       error)) {
            return NO;
        }
    }

    NSSet<NSString *> *includedOptions = nil;
    id includedOptionsValue = manifest[@"includedOptions"];
    if (includedOptionsValue &&
        !PXManifestValidateStringArray(includedOptionsValue,
                                       @"$.includedOptions",
                                       YES,
                                       &includedOptions,
                                       error)) {
        return NO;
    }

    NSSet<NSString *> *excludedOptions = nil;
    id excludedOptionsValue = manifest[@"excludedOptions"];
    if (excludedOptionsValue &&
        !PXManifestValidateStringArray(excludedOptionsValue,
                                       @"$.excludedOptions",
                                       YES,
                                       &excludedOptions,
                                       error)) {
        return NO;
    }

    if (includedOptions && excludedOptions) {
        NSArray *excludedArray = (NSArray *)excludedOptionsValue;
        for (NSUInteger index = 0; index < excludedArray.count; index++) {
            if ([includedOptions containsObject:excludedArray[index]]) {
                return PXManifestFail(error,
                                      PXBackupManifestValidatorErrorInconsistentField,
                                      PXManifestIndexedPath(@"$.excludedOptions", index),
                                      @"Included and excluded option arrays must be disjoint.");
            }
        }
    }

    id artifactCountValue = manifest[@"artifactCount"];
    if (artifactCountValue) {
        unsigned long long declaredCount = 0;
        if (!PXManifestValidateNonnegativeIntegral(artifactCountValue,
                                                   @"$.artifactCount",
                                                   &declaredCount,
                                                   error)) {
            return NO;
        }
        if (declaredCount != (unsigned long long)artifactCount) {
            return PXManifestFail(error,
                                  PXBackupManifestValidatorErrorInconsistentField,
                                  @"$.artifactCount",
                                  @"The declared artifact count must equal the artifacts array count.");
        }
    }

    id totalSize = manifest[@"totalSize"];
    if (totalSize &&
        !PXManifestValidateNonnegativeIntegral(totalSize,
                                               @"$.totalSize",
                                               NULL,
                                               error)) {
        return NO;
    }

    id archiveChecksum = manifest[@"archiveChecksum"];
    if (archiveChecksum &&
        !PXManifestValidateOptionalString(archiveChecksum,
                                          @"$.archiveChecksum",
                                          error)) {
        return NO;
    }

    id warnings = manifest[@"warnings"];
    if (warnings &&
        !PXManifestValidateStringArray(warnings,
                                       @"$.warnings",
                                       NO,
                                       NULL,
                                       error)) {
        return NO;
    }

    id restoreCompatibility = manifest[@"restoreCompatibility"];
    if (restoreCompatibility &&
        !PXManifestValidateRestoreCompatibility(restoreCompatibility,
                                                manifest[@"bundleID"],
                                                error)) {
        return NO;
    }

    id systemGlobalLibrary = manifest[@"systemGlobalLibrary"];
    if (systemGlobalLibrary &&
        !PXManifestValidateSystemGlobalLibrary(systemGlobalLibrary, error)) {
        return NO;
    }

    id sharedSystemDB = manifest[@"sharedSystemDB"];
    if (sharedSystemDB &&
        !PXManifestValidateSharedSystemDB(sharedSystemDB, error)) {
        return NO;
    }

    return YES;
}

@end
