#import "KeychainBackupHelper.h"
#import "PXKeychainItemIdentity.h"
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <errno.h>
#import <fcntl.h>
#import <math.h>
#import <stdlib.h>
#import <sys/stat.h>
#import <unistd.h>

NSString * const PXKeychainBackupErrorDomain = @"com.hydra.projectx.keychain";

@implementation PXKeychainBackupResult
- (instancetype)init {
    self = [super init];
    if (self) {
        _warnings = @[];
        _errors = @[];
    }
    return self;
}
@end

#pragma mark - Private Helpers

static const NSUInteger PXKeychainBackupMaximumAccessGroups = 128;
static const NSUInteger PXKeychainBackupMaximumAccessGroupBytes = 512;
static const NSUInteger PXKeychainBackupMaximumAccessGroupArrayBytes = 8 * 1024;
static const NSUInteger PXKeychainBackupPlistMaximumBytes = 64 * 1024 * 1024;

static void PXAssignKeychainBackupError(NSError **error,
                                        PXKeychainBackupErrorCode code,
                                        NSString *description,
                                        int posixError) {
    if (!error) {
        return;
    }
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:
        description ?: @"Keychain backup operation failed"
                                                                  forKey:NSLocalizedDescriptionKey];
    if (posixError != 0) {
        userInfo[NSUnderlyingErrorKey] =
            [NSError errorWithDomain:NSPOSIXErrorDomain code:posixError userInfo:nil];
    }
    *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                 code:code
                             userInfo:userInfo];
}

static NSArray<NSString *> *PXCanonicalKeychainAccessGroups(id value,
                                                             NSError **error) {
    if (![value isKindOfClass:[NSArray class]]) {
        PXAssignKeychainBackupError(error,
                                    PXKeychainBackupErrorInvalidArguments,
                                    @"Access groups must be an array",
                                    0);
        return nil;
    }

    NSArray *input = (NSArray *)value;
    if (input.count == 0) {
        PXAssignKeychainBackupError(error,
                                    PXKeychainBackupErrorNoAccessGroups,
                                    @"At least one access group is required",
                                    0);
        return nil;
    }
    if (input.count > PXKeychainBackupMaximumAccessGroups) {
        PXAssignKeychainBackupError(error,
                                    PXKeychainBackupErrorInvalidArguments,
                                    @"The access-group array exceeds the fixed count limit",
                                    0);
        return nil;
    }

    NSMutableArray<NSString *> *canonical =
        [NSMutableArray arrayWithCapacity:input.count];
    NSMutableSet<NSString *> *seen = [NSMutableSet setWithCapacity:input.count];
    NSCharacterSet *edgeWhitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSCharacterSet *controlCharacters = [NSCharacterSet controlCharacterSet];
    NSUInteger totalBytes = 0;

    for (id candidate in input) {
        if (![candidate isKindOfClass:[NSString class]]) {
            PXAssignKeychainBackupError(error,
                                        PXKeychainBackupErrorInvalidArguments,
                                        @"An access-group value is not a string",
                                        0);
            return nil;
        }

        NSString *trimmed = [(NSString *)candidate
            stringByTrimmingCharactersInSet:edgeWhitespace];
        NSData *utf8 = [trimmed dataUsingEncoding:NSUTF8StringEncoding
                              allowLossyConversion:NO];
        NSString *roundTrip = utf8
            ? [[NSString alloc] initWithData:utf8 encoding:NSUTF8StringEncoding]
            : nil;
        if (trimmed.length == 0 ||
            !utf8 || utf8.length == 0 ||
            utf8.length > PXKeychainBackupMaximumAccessGroupBytes ||
            ![roundTrip isEqualToString:trimmed] ||
            [trimmed rangeOfCharacterFromSet:controlCharacters].location != NSNotFound ||
            [trimmed rangeOfString:@","].location != NSNotFound) {
            PXAssignKeychainBackupError(error,
                                        PXKeychainBackupErrorInvalidArguments,
                                        @"An access-group value violates the canonical contract",
                                        0);
            return nil;
        }
        if ([seen containsObject:trimmed]) {
            continue;
        }
        if (totalBytes > PXKeychainBackupMaximumAccessGroupArrayBytes ||
            utf8.length > PXKeychainBackupMaximumAccessGroupArrayBytes - totalBytes) {
            PXAssignKeychainBackupError(error,
                                        PXKeychainBackupErrorInvalidArguments,
                                        @"The access-group array exceeds the fixed byte limit",
                                        0);
            return nil;
        }
        totalBytes += utf8.length;
        NSString *snapshot = [trimmed copy];
        [seen addObject:snapshot];
        [canonical addObject:snapshot];
    }

    if (canonical.count == 0) {
        PXAssignKeychainBackupError(error,
                                    PXKeychainBackupErrorNoAccessGroups,
                                    @"The canonical access-group array is empty",
                                    0);
        return nil;
    }
    return [canonical copy];
}

static NSData *PXReadBoundedKeychainBackupFile(NSString *filePath,
                                                NSError **error) {
    if (![filePath isKindOfClass:[NSString class]] || filePath.length == 0) {
        PXAssignKeychainBackupError(error,
                                    PXKeychainBackupErrorInvalidArguments,
                                    @"Backup file path is required",
                                    0);
        return nil;
    }

    const char *path = filePath.fileSystemRepresentation;
    if (!path) {
        PXAssignKeychainBackupError(error,
                                    PXKeychainBackupErrorInvalidArguments,
                                    @"Backup file path cannot be represented safely",
                                    EINVAL);
        return nil;
    }

    errno = 0;
    int descriptor = open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (descriptor < 0) {
        int capturedError = errno;
        PXAssignKeychainBackupError(error,
                                    PXKeychainBackupErrorFileIO,
                                    @"Backup file could not be opened safely",
                                    capturedError);
        return nil;
    }

    struct stat initialStatus;
    errno = 0;
    if (fstat(descriptor, &initialStatus) != 0) {
        int capturedError = errno;
        close(descriptor);
        PXAssignKeychainBackupError(error,
                                    PXKeychainBackupErrorFileIO,
                                    @"Backup file could not be inspected safely",
                                    capturedError);
        return nil;
    }
    if (!S_ISREG(initialStatus.st_mode) ||
        initialStatus.st_size <= 0 ||
        (unsigned long long)initialStatus.st_size > PXKeychainBackupPlistMaximumBytes) {
        close(descriptor);
        PXAssignKeychainBackupError(error,
                                    PXKeychainBackupErrorInvalidBackupFile,
                                    @"Backup file must be a nonempty regular file no larger than 64 MiB",
                                    0);
        return nil;
    }

    NSUInteger expectedLength = (NSUInteger)initialStatus.st_size;
    void *buffer = malloc(expectedLength);
    if (!buffer) {
        close(descriptor);
        PXAssignKeychainBackupError(error,
                                    PXKeychainBackupErrorFileIO,
                                    @"Backup file buffer allocation failed",
                                    ENOMEM);
        return nil;
    }

    NSUInteger offset = 0;
    while (offset < expectedLength) {
        errno = 0;
        ssize_t amount = read(descriptor,
                              (unsigned char *)buffer + offset,
                              expectedLength - offset);
        if (amount < 0) {
            int capturedError = errno;
            if (capturedError == EINTR) {
                continue;
            }
            free(buffer);
            close(descriptor);
            PXAssignKeychainBackupError(error,
                                        PXKeychainBackupErrorFileIO,
                                        @"Backup file could not be read safely",
                                        capturedError);
            return nil;
        }
        if (amount == 0) {
            free(buffer);
            close(descriptor);
            PXAssignKeychainBackupError(error,
                                        PXKeychainBackupErrorInvalidBackupFile,
                                        @"Backup file ended before the verified size was read",
                                        0);
            return nil;
        }
        offset += (NSUInteger)amount;
    }

    struct stat finalStatus;
    errno = 0;
    if (fstat(descriptor, &finalStatus) != 0) {
        int capturedError = errno;
        free(buffer);
        close(descriptor);
        PXAssignKeychainBackupError(error,
                                    PXKeychainBackupErrorFileIO,
                                    @"Backup file could not be revalidated safely",
                                    capturedError);
        return nil;
    }
    close(descriptor);

    BOOL unchanged =
        S_ISREG(finalStatus.st_mode) &&
        finalStatus.st_dev == initialStatus.st_dev &&
        finalStatus.st_ino == initialStatus.st_ino &&
        finalStatus.st_size == initialStatus.st_size &&
        finalStatus.st_mtimespec.tv_sec == initialStatus.st_mtimespec.tv_sec &&
        finalStatus.st_mtimespec.tv_nsec == initialStatus.st_mtimespec.tv_nsec &&
        finalStatus.st_ctimespec.tv_sec == initialStatus.st_ctimespec.tv_sec &&
        finalStatus.st_ctimespec.tv_nsec == initialStatus.st_ctimespec.tv_nsec;
    if (!unchanged) {
        free(buffer);
        PXAssignKeychainBackupError(error,
                                    PXKeychainBackupErrorInvalidBackupFile,
                                    @"Backup file changed while it was being read",
                                    0);
        return nil;
    }

    NSData *data = [[NSData alloc] initWithBytesNoCopy:buffer
                                                length:expectedLength
                                          freeWhenDone:YES];
    if (!data) {
        free(buffer);
        PXAssignKeychainBackupError(error,
                                    PXKeychainBackupErrorFileIO,
                                    @"Backup file data could not be constructed",
                                    ENOMEM);
        return nil;
    }
    return data;
}

/// Convert keychain item class to SecItemClass CFTypeRef.
static CFTypeRef PXSecItemClassFromType(PXKeychainItemClass itemClass) {
    switch (itemClass) {
        case PXKeychainItemClassGenericPassword:
            return kSecClassGenericPassword;
        case PXKeychainItemClassInternetPassword:
            return kSecClassInternetPassword;
        case PXKeychainItemClassCertificate:
            return kSecClassCertificate;
        case PXKeychainItemClassKey:
            return kSecClassKey;
        case PXKeychainItemClassIdentity:
            return kSecClassIdentity;
        default:
            return NULL;
    }
}

/// Get human-readable name for a keychain class.
static NSString *PXKeychainClassName(CFTypeRef secClass) {
    if (secClass == kSecClassGenericPassword) return @"GenericPassword";
    if (secClass == kSecClassInternetPassword) return @"InternetPassword";
    if (secClass == kSecClassCertificate) return @"Certificate";
    if (secClass == kSecClassKey) return @"Key";
    if (secClass == kSecClassIdentity) return @"Identity";
    return @"Unknown";
}

/// Get OSStatus error description.
static NSString *PXSecurityErrorDescription(OSStatus status) {
    CFStringRef message = SecCopyErrorMessageString(status, NULL);
    NSString *desc = message ? (__bridge_transfer NSString *)message : [NSString stringWithFormat:@"OSStatus %d", (int)status];
    return desc;
}

// Optional query knobs to avoid UI prompts and to surface errors.
static void PXAddAuthUIFlags(NSMutableDictionary *query) {
    if (!query) return;
    // iOS 9+: control whether SecItem may prompt.
    // Using FAIL ensures we get a clear error instead of UI/blocks.
    if (@available(iOS 9.0, *)) {
        query[(__bridge id)kSecUseAuthenticationUI] = (__bridge id)kSecUseAuthenticationUIFail;
    }
}

static OSStatus PXCountKeychainItemsMatchingQuery(NSDictionary *baseQuery,
                                                   NSUInteger *countOut) {
    if (countOut) {
        *countOut = 0;
    }
    if (![baseQuery isKindOfClass:[NSDictionary class]] || !countOut) {
        return errSecParam;
    }

    NSMutableDictionary *countQuery = [baseQuery mutableCopy];
    countQuery[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitAll;
    countQuery[(__bridge id)kSecReturnAttributes] = @YES;

    CFTypeRef countResult = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)countQuery,
                                          &countResult);
    if (status == errSecItemNotFound) {
        return status;
    }
    if (status != errSecSuccess) {
        if (countResult) {
            CFRelease(countResult);
        }
        return status;
    }

    if (!countResult) {
        return errSecDecode;
    }
    id resultObject = (__bridge_transfer id)countResult;
    if ([resultObject isKindOfClass:[NSArray class]]) {
        *countOut = [(NSArray *)resultObject count];
    } else if ([resultObject isKindOfClass:[NSDictionary class]]) {
        *countOut = 1;
    } else {
        return errSecDecode;
    }
    return errSecSuccess;
}

/// List of all keychain classes to iterate.
static NSArray<NSNumber *> *PXAllKeychainClasses(void) {
    return @[
        @(PXKeychainItemClassGenericPassword),
        @(PXKeychainItemClassInternetPassword),
        @(PXKeychainItemClassCertificate),
        @(PXKeychainItemClassKey),
        @(PXKeychainItemClassIdentity),
    ];
}

/// Attributes that should NOT be included when adding items back (system-managed).
static NSSet<NSString *> *PXExcludedRestoreAttributes(void) {
    static NSSet *excluded = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        excluded = [NSSet setWithObjects:
            (__bridge NSString *)kSecAttrAccessControl,
            (__bridge NSString *)kSecAttrCreationDate,
            (__bridge NSString *)kSecAttrModificationDate,
            (__bridge NSString *)kSecAttrPersistentReference,
            (__bridge NSString *)kSecValuePersistentRef,
            @"tomb",   // Internal attribute
            @"UUID",   // Internal
            @"sha1",   // Internal
            nil
        ];
    });
    return excluded;
}

typedef NS_ENUM(NSInteger, PXRestoreItemOutcome) {
    PXRestoreItemOutcomeSucceeded = 1,
    PXRestoreItemOutcomeFailedWarning = 2,
    PXRestoreItemOutcomeFailedError = 3,
};

static BOOL PXRestoreValueIsExactString(id value) {
    return [value isKindOfClass:[NSString class]] &&
           CFGetTypeID((__bridge CFTypeRef)value) == CFStringGetTypeID();
}

static BOOL PXRestoreValueIsExactData(id value) {
    return [value isKindOfClass:[NSData class]] &&
           CFGetTypeID((__bridge CFTypeRef)value) == CFDataGetTypeID();
}

static BOOL PXRestoreValueIsExactNumber(id value) {
    return [value isKindOfClass:[NSNumber class]] &&
           CFGetTypeID((__bridge CFTypeRef)value) == CFNumberGetTypeID();
}

static CFTypeRef PXCanonicalSecurityClassForSerializedValue(id value) {
    if (!PXRestoreValueIsExactString(value)) {
        return NULL;
    }

    CFStringRef serializedClass = (__bridge CFStringRef)value;
    CFStringRef candidates[] = {
        kSecClassGenericPassword,
        kSecClassInternetPassword,
        kSecClassCertificate,
        kSecClassKey,
        kSecClassIdentity,
    };
    CFTypeRef resolvedClass = NULL;
    NSUInteger matchCount = 0;
    for (NSUInteger index = 0; index < sizeof(candidates) / sizeof(candidates[0]); index++) {
        if (CFEqual(serializedClass, candidates[index])) {
            resolvedClass = candidates[index];
            matchCount++;
        }
    }
    return matchCount == 1 ? resolvedClass : NULL;
}

static BOOL PXSerializedClassMetadataIsConsistent(NSDictionary *item,
                                                   CFTypeRef canonicalClass) {
    id classMetadata = item[@"_class"];
    if (!classMetadata) {
        return YES;
    }
    if (!PXRestoreValueIsExactString(classMetadata)) {
        return NO;
    }
    NSString *expectedName = PXKeychainClassName(canonicalClass);
    return [(NSString *)classMetadata isEqualToString:expectedName];
}

static BOOL PXDecodeRestoreValue(id serializedValue,
                                 id *decodedValueOut) {
    if (!serializedValue || !decodedValueOut) {
        return NO;
    }

    id decodedValue = serializedValue;
    if ([serializedValue isKindOfClass:[NSDictionary class]]) {
        NSDictionary *wrapped = (NSDictionary *)serializedValue;
        id typeValue = wrapped[@"_type"];
        if (typeValue) {
            if (!PXRestoreValueIsExactString(typeValue)) {
                return NO;
            }
            NSString *type = (NSString *)typeValue;
            if ([type isEqualToString:@"data"]) {
                id base64Value = wrapped[@"_base64"];
                if (!PXRestoreValueIsExactString(base64Value)) {
                    return NO;
                }
                NSData *data = [[NSData alloc] initWithBase64EncodedString:(NSString *)base64Value
                                                                   options:0];
                if (!data) {
                    return NO;
                }
                decodedValue = data;
            } else if ([type isEqualToString:@"date"]) {
                id timestampValue = wrapped[@"_timestamp"];
                if (!PXRestoreValueIsExactNumber(timestampValue)) {
                    return NO;
                }
                double timestamp = [(NSNumber *)timestampValue doubleValue];
                if (!isfinite(timestamp)) {
                    return NO;
                }
                NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
                if (!date) {
                    return NO;
                }
                decodedValue = date;
            }
        }
    }

    *decodedValueOut = decodedValue;
    return YES;
}

static NSDictionary *PXCreateRestoreAddQuery(NSDictionary *item) {
    if (![item isKindOfClass:[NSDictionary class]] || item.count > 256) {
        return nil;
    }

    id serializedClass = item[@"_secClass"];
    CFTypeRef canonicalClass = PXCanonicalSecurityClassForSerializedValue(serializedClass);
    if (!canonicalClass || !PXSerializedClassMetadataIsConsistent(item, canonicalClass)) {
        return nil;
    }

    NSSet<NSString *> *excluded = PXExcludedRestoreAttributes();
    NSMutableDictionary *addQuery = [NSMutableDictionary dictionaryWithCapacity:item.count];
    addQuery[(__bridge id)kSecClass] = (__bridge id)canonicalClass;

    for (id keyObject in item) {
        if (!PXRestoreValueIsExactString(keyObject)) {
            return nil;
        }
        NSString *key = (NSString *)keyObject;
        if ([key hasPrefix:@"_"] ||
            [key isEqualToString:(__bridge NSString *)kSecClass] ||
            [excluded containsObject:key]) {
            continue;
        }

        id decodedValue = nil;
        if (!PXDecodeRestoreValue(item[key], &decodedValue) || !decodedValue) {
            return nil;
        }
        addQuery[key] = decodedValue;
    }

    return [NSDictionary dictionaryWithDictionary:addQuery];
}

static PXKeychainItemIdentity *PXCreateRestoreIdentity(NSDictionary *addQuery,
                                                        NSError **error) {
    return [PXKeychainItemIdentity identityForSecurityItemAttributes:addQuery
                                                               error:error];
}

static OSStatus PXCopyUniquePersistentReferenceForIdentity(
    PXKeychainItemIdentity *identity,
    NSData **persistentReferenceOut) {
    if (persistentReferenceOut) {
        *persistentReferenceOut = nil;
    }
    if (![identity isKindOfClass:[PXKeychainItemIdentity class]] ||
        !persistentReferenceOut) {
        return errSecParam;
    }

    @try {
        NSDictionary *matchQuery = identity.matchQuery;
        if (![matchQuery isKindOfClass:[NSDictionary class]] ||
            matchQuery.count == 0 || matchQuery.count > 10) {
            return errSecParam;
        }

        NSMutableDictionary *lookupQuery =
            [NSMutableDictionary dictionaryWithDictionary:matchQuery];
        lookupQuery[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitAll;
        lookupQuery[(__bridge id)kSecReturnPersistentRef] = @YES;
        PXAddAuthUIFlags(lookupQuery);

        CFTypeRef rawResult = NULL;
        OSStatus lookupStatus = SecItemCopyMatching((__bridge CFDictionaryRef)lookupQuery,
                                                     &rawResult);
        id lookupResult = rawResult ? CFBridgingRelease(rawResult) : nil;
        if (lookupStatus != errSecSuccess) {
            return lookupStatus;
        }

        NSData *persistentReference = nil;
        if (PXRestoreValueIsExactData(lookupResult)) {
            persistentReference = (NSData *)lookupResult;
        } else if ([lookupResult isKindOfClass:[NSArray class]] &&
                   CFGetTypeID((__bridge CFTypeRef)lookupResult) == CFArrayGetTypeID()) {
            NSArray *matches = (NSArray *)lookupResult;
            if (matches.count == 0) {
                return errSecItemNotFound;
            }
            if (matches.count != 1) {
                return errSecDuplicateItem;
            }
            id onlyMatch = matches.firstObject;
            if (!PXRestoreValueIsExactData(onlyMatch)) {
                return errSecDecode;
            }
            persistentReference = (NSData *)onlyMatch;
        } else if (!lookupResult) {
            return errSecItemNotFound;
        } else {
            return errSecDecode;
        }

        if (persistentReference.length == 0) {
            return errSecDecode;
        }
        NSData *snapshot = [[NSData alloc] initWithData:persistentReference];
        if (!snapshot || snapshot.length == 0 ||
            ![snapshot isEqualToData:persistentReference]) {
            return errSecDecode;
        }

        *persistentReferenceOut = snapshot;
        return errSecSuccess;
    } @catch (__unused NSException *exception) {
        return errSecDecode;
    }
}

static NSDictionary *PXCreateUpdateAttributesFromAddQuery(
    NSDictionary *addQuery,
    PXKeychainItemIdentity *identity) {
    if (![addQuery isKindOfClass:[NSDictionary class]] ||
        ![identity isKindOfClass:[PXKeychainItemIdentity class]] ||
        addQuery.count == 0 || addQuery.count > 256) {
        return nil;
    }

    @try {
        NSMutableDictionary *updateAttributes =
            [NSMutableDictionary dictionaryWithDictionary:addQuery];

        NSArray *alwaysExcludedKeys = @[
            (__bridge id)kSecClass,
            (__bridge id)kSecAttrAccessGroup,
            (__bridge id)kSecAttrSynchronizable,
            (__bridge id)kSecAttrAccessControl,
            (__bridge id)kSecAttrCreationDate,
            (__bridge id)kSecAttrModificationDate,
            (__bridge id)kSecAttrPersistentReference,
            (__bridge id)kSecMatchLimit,
            (__bridge id)kSecReturnAttributes,
            (__bridge id)kSecReturnData,
            (__bridge id)kSecReturnRef,
            (__bridge id)kSecReturnPersistentRef,
            (__bridge id)kSecUseAuthenticationUI,
            (__bridge id)kSecUseOperationPrompt,
            (__bridge id)kSecValueRef,
            (__bridge id)kSecValuePersistentRef,
        ];
        for (id key in alwaysExcludedKeys) {
            [updateAttributes removeObjectForKey:key];
        }
        for (id key in PXExcludedRestoreAttributes()) {
            [updateAttributes removeObjectForKey:key];
        }
        for (id key in identity.identityAttributeNames) {
            if (!PXRestoreValueIsExactString(key)) {
                return nil;
            }
            [updateAttributes removeObjectForKey:key];
        }

        return [NSDictionary dictionaryWithDictionary:updateAttributes];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static OSStatus PXUpdateExistingRestoreItem(NSData *persistentReference,
                                             NSDictionary *updateAttributes) {
    if (!PXRestoreValueIsExactData(persistentReference) ||
        persistentReference.length == 0 ||
        ![updateAttributes isKindOfClass:[NSDictionary class]] ||
        updateAttributes.count == 0) {
        return errSecParam;
    }

    @try {
        NSMutableDictionary *updateQuery = [@{
            (__bridge id)kSecValuePersistentRef: persistentReference,
        } mutableCopy];
        PXAddAuthUIFlags(updateQuery);
        return SecItemUpdate((__bridge CFDictionaryRef)updateQuery,
                             (__bridge CFDictionaryRef)updateAttributes);
    } @catch (__unused NSException *exception) {
        return errSecParam;
    }
}

static PXRestoreItemOutcome PXProcessRestoreItem(NSDictionary *item,
                                                  BOOL overwrite,
                                                  NSString **diagnosticOut) {
    if (diagnosticOut) {
        *diagnosticOut = nil;
    }

    @try {
        NSDictionary *addQuery = PXCreateRestoreAddQuery(item);
        if (!addQuery) {
            if (diagnosticOut) {
                *diagnosticOut = @"A Keychain restore item could not be decoded safely.";
            }
            return PXRestoreItemOutcomeFailedError;
        }

        OSStatus addStatus = SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
        if (addStatus == errSecSuccess) {
            return PXRestoreItemOutcomeSucceeded;
        }
        if (addStatus != errSecDuplicateItem) {
            if (diagnosticOut) {
                *diagnosticOut = [NSString stringWithFormat:@"Keychain restore add failed (status=%d).",
                                  (int)addStatus];
            }
            return PXRestoreItemOutcomeFailedError;
        }

        if (!overwrite) {
            if (diagnosticOut) {
                *diagnosticOut = @"An existing Keychain item was preserved because overwrite was not requested.";
            }
            return PXRestoreItemOutcomeFailedWarning;
        }

        NSError *identityError = nil;
        PXKeychainItemIdentity *identity = PXCreateRestoreIdentity(addQuery, &identityError);
        if (!identity) {
            if (diagnosticOut) {
                *diagnosticOut = [NSString stringWithFormat:@"Exact Keychain item identity could not be constructed (code=%ld).",
                                  (long)identityError.code];
            }
            return PXRestoreItemOutcomeFailedError;
        }

        NSData *persistentReference = nil;
        OSStatus lookupStatus =
            PXCopyUniquePersistentReferenceForIdentity(identity, &persistentReference);
        if (lookupStatus != errSecSuccess) {
            if (diagnosticOut) {
                *diagnosticOut = [NSString stringWithFormat:@"Exact Keychain item lookup failed (status=%d).",
                                  (int)lookupStatus];
            }
            return PXRestoreItemOutcomeFailedError;
        }

        NSDictionary *updateAttributes =
            PXCreateUpdateAttributesFromAddQuery(addQuery, identity);
        if (!updateAttributes) {
            if (diagnosticOut) {
                *diagnosticOut = @"Exact Keychain item update attributes could not be created safely.";
            }
            return PXRestoreItemOutcomeFailedError;
        }
        if (updateAttributes.count == 0) {
            return PXRestoreItemOutcomeSucceeded;
        }

        OSStatus updateStatus =
            PXUpdateExistingRestoreItem(persistentReference, updateAttributes);
        if (updateStatus == errSecSuccess) {
            return PXRestoreItemOutcomeSucceeded;
        }
        if (diagnosticOut) {
            *diagnosticOut = [NSString stringWithFormat:@"Exact Keychain item update failed (status=%d).",
                              (int)updateStatus];
        }
        return PXRestoreItemOutcomeFailedError;
    } @catch (__unused NSException *exception) {
        if (diagnosticOut) {
            *diagnosticOut = @"A Keychain restore item could not be processed safely.";
        }
        return PXRestoreItemOutcomeFailedError;
    }
}

#pragma mark - Implementation

@implementation KeychainBackupHelper

#pragma mark - Backup

+ (PXKeychainBackupResult *)backupKeychainToFile:(NSString *)filePath
                                    accessGroups:(NSArray<NSString *> *)groups
                                     itemClasses:(PXKeychainItemClass)itemClasses
                                           error:(NSError **)error {
    if (!filePath.length) {
        PXAssignKeychainBackupError(error,
                                    PXKeychainBackupErrorInvalidArguments,
                                    @"Backup file path is required",
                                    0);
        return nil;
    }

    NSError *canonicalGroupError = nil;
    NSArray<NSString *> *canonicalGroups =
        PXCanonicalKeychainAccessGroups(groups, &canonicalGroupError);
    if (!canonicalGroups) {
        if (error) {
            *error = canonicalGroupError;
        }
        return nil;
    }

    PXKeychainBackupResult *result = [[PXKeychainBackupResult alloc] init];
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];
    NSMutableArray<NSString *> *errors = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *allItems = [NSMutableArray array];

    for (NSString *group in canonicalGroups) {
        for (NSNumber *classNum in PXAllKeychainClasses()) {
            PXKeychainItemClass classType = [classNum unsignedIntegerValue];
            if (!(itemClasses & classType)) {
                continue;
            }

            CFTypeRef secClass = PXSecItemClassFromType(classType);
            if (!secClass) {
                continue;
            }

            NSMutableDictionary *query = [@{
                (__bridge id)kSecClass: (__bridge id)secClass,
                (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll,
                (__bridge id)kSecReturnAttributes: @YES,
                (__bridge id)kSecReturnData: @YES,
                (__bridge id)kSecAttrSynchronizable: (__bridge id)kSecAttrSynchronizableAny,
                (__bridge id)kSecAttrAccessGroup: group,
            } mutableCopy];
            PXAddAuthUIFlags(query);

            CFTypeRef cfResult = NULL;
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query,
                                                   &cfResult);
            if (status == errSecItemNotFound) {
                continue;
            }
            if (status != errSecSuccess) {
                [warnings addObject:[NSString stringWithFormat:
                    @"Failed to query %@ in access group %@: %@",
                    PXKeychainClassName(secClass),
                    group,
                    PXSecurityErrorDescription(status)]];
                continue;
            }

            id resultObject = (__bridge_transfer id)cfResult;
            NSArray *items = [resultObject isKindOfClass:[NSArray class]]
                ? (NSArray *)resultObject
                : (resultObject ? @[resultObject] : @[]);

            for (id itemObject in items) {
                if (![itemObject isKindOfClass:[NSDictionary class]]) {
                    result.itemsProcessed++;
                    result.itemsFailed++;
                    [warnings addObject:[NSString stringWithFormat:
                        @"A %@ item in access group %@ had an invalid result type",
                        PXKeychainClassName(secClass),
                        group]];
                    continue;
                }

                NSDictionary *item = (NSDictionary *)itemObject;
                result.itemsProcessed++;
                NSMutableDictionary *exportItem = [NSMutableDictionary dictionary];
                exportItem[@"_class"] = PXKeychainClassName(secClass);
                exportItem[@"_secClass"] = (__bridge id)secClass;

                for (NSString *key in item) {
                    id value = item[key];
                    if ([value isKindOfClass:[NSData class]]) {
                        exportItem[key] = @{
                            @"_type": @"data",
                            @"_base64": [(NSData *)value base64EncodedStringWithOptions:0],
                        };
                    } else if ([value isKindOfClass:[NSDate class]]) {
                        exportItem[key] = @{
                            @"_type": @"date",
                            @"_timestamp": @([(NSDate *)value timeIntervalSince1970]),
                        };
                    } else if ([value isKindOfClass:[NSNumber class]] ||
                               [value isKindOfClass:[NSString class]]) {
                        exportItem[key] = value;
                    }
                }

                [allItems addObject:exportItem];
                result.itemsSucceeded++;
            }
        }
    }

    NSDictionary *backup = @{
        @"version": @1,
        @"created": @([[NSDate date] timeIntervalSince1970]),
        @"accessGroups": canonicalGroups,
        @"items": allItems,
    };

    NSError *writeError = nil;
    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:backup
                                                                   format:NSPropertyListXMLFormat_v1_0
                                                                  options:0
                                                                    error:&writeError];
    if (!plistData) {
        if (error) {
            *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                         code:PXKeychainBackupErrorFileIO
                                     userInfo:@{
                NSLocalizedDescriptionKey: @"Failed to serialize backup",
                NSUnderlyingErrorKey: writeError ?: [NSNull null],
            }];
        }
        return nil;
    }

    BOOL written = [plistData writeToFile:filePath
                                  options:NSDataWritingAtomic
                                    error:&writeError];
    if (!written) {
        if (error) {
            *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                         code:PXKeychainBackupErrorFileIO
                                     userInfo:@{
                NSLocalizedDescriptionKey: @"Failed to write backup file",
                NSUnderlyingErrorKey: writeError ?: [NSNull null],
            }];
        }
        return nil;
    }

    result.warnings = warnings;
    result.errors = errors;
    return result;
}

#pragma mark - Restore

+ (PXKeychainBackupResult *)restoreKeychainFromFile:(NSString *)filePath
                                           overwrite:(BOOL)overwrite
                                               error:(NSError **)error {
    if (!filePath.length) {
        if (error) {
            *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                         code:PXKeychainBackupErrorInvalidArguments
                                     userInfo:@{NSLocalizedDescriptionKey: @"Backup file path is required"}];
        }
        return nil;
    }

    NSData *plistData = PXReadBoundedKeychainBackupFile(filePath, error);
    if (!plistData) {
        return nil;
    }

    NSError *parseError = nil;
    NSDictionary *backup = [NSPropertyListSerialization propertyListWithData:plistData
                                                                     options:NSPropertyListImmutable
                                                                      format:NULL
                                                                       error:&parseError];
    if (!backup || ![backup isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                         code:PXKeychainBackupErrorInvalidBackupFile
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid backup file format",
                                               NSUnderlyingErrorKey: parseError ?: [NSNull null]}];
        }
        return nil;
    }

    NSArray *items = backup[@"items"];
    if (![items isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                         code:PXKeychainBackupErrorInvalidBackupFile
                                     userInfo:@{NSLocalizedDescriptionKey: @"Backup file contains no items"}];
        }
        return nil;
    }

    PXKeychainBackupResult *result = [[PXKeychainBackupResult alloc] init];
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];
    NSMutableArray<NSString *> *errors = [NSMutableArray array];

    for (id itemObject in items) {
        if (![itemObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        result.itemsProcessed++;
        NSString *diagnostic = nil;
        PXRestoreItemOutcome outcome = PXProcessRestoreItem((NSDictionary *)itemObject,
                                                            overwrite,
                                                            &diagnostic);
        switch (outcome) {
            case PXRestoreItemOutcomeSucceeded:
                result.itemsSucceeded++;
                break;
            case PXRestoreItemOutcomeFailedWarning:
                result.itemsFailed++;
                [warnings addObject:diagnostic ?: @"An existing Keychain item was preserved."];
                break;
            case PXRestoreItemOutcomeFailedError:
                result.itemsFailed++;
                [errors addObject:diagnostic ?: @"A Keychain restore item failed safely."];
                break;
        }
    }

    result.warnings = warnings;
    result.errors = errors;
    return result;
}

#pragma mark - Wipe

+ (PXKeychainBackupResult *)wipeKeychainForAccessGroups:(NSArray<NSString *> *)groups
                                            itemClasses:(PXKeychainItemClass)itemClasses
                                                  error:(NSError **)error {
    if (!groups.count) {
        if (error) {
            *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                         code:PXKeychainBackupErrorNoAccessGroups
                                     userInfo:@{NSLocalizedDescriptionKey: @"At least one access group is required"}];
        }
        return nil;
    }
    
    PXKeychainBackupResult *result = [[PXKeychainBackupResult alloc] init];
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];
    
    for (NSString *group in groups) {
        for (NSNumber *classNum in PXAllKeychainClasses()) {
            PXKeychainItemClass classType = [classNum unsignedIntegerValue];
            if (!(itemClasses & classType)) continue;
            
            CFTypeRef secClass = PXSecItemClassFromType(classType);
            if (!secClass) continue;
            
            NSMutableDictionary *query = [@{
                (__bridge id)kSecClass: (__bridge id)secClass,
                (__bridge id)kSecAttrAccessGroup: group,
                (__bridge id)kSecAttrSynchronizable: (__bridge id)kSecAttrSynchronizableAny,
            } mutableCopy];
            PXAddAuthUIFlags(query);

            NSUInteger itemCount = 0;
            OSStatus countStatus = PXCountKeychainItemsMatchingQuery(query, &itemCount);
            if (countStatus != errSecSuccess && countStatus != errSecItemNotFound) {
                [warnings addObject:[NSString stringWithFormat:@"Failed to count %@ items in group %@ before deletion: %@",
                                   PXKeychainClassName(secClass), group, PXSecurityErrorDescription(countStatus)]];
            }
            result.itemsProcessed += itemCount;

            OSStatus deleteStatus = SecItemDelete((__bridge CFDictionaryRef)query);
            if (deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound) {
                [warnings addObject:[NSString stringWithFormat:@"Failed to delete %@ items in group %@: %@",
                                   PXKeychainClassName(secClass), group, PXSecurityErrorDescription(deleteStatus)]];
                result.itemsFailed += itemCount;
                continue;
            }

            NSUInteger residualCount = 0;
            OSStatus verificationStatus = PXCountKeychainItemsMatchingQuery(query, &residualCount);
            BOOL verifiedEmpty = verificationStatus == errSecItemNotFound ||
                                 (verificationStatus == errSecSuccess && residualCount == 0);
            if (verifiedEmpty) {
                result.itemsSucceeded += itemCount;
            } else {
                result.itemsFailed += itemCount;
                if (verificationStatus == errSecSuccess) {
                    [warnings addObject:[NSString stringWithFormat:@"Keychain wipe left %lu residual %@ items in group %@",
                                       (unsigned long)residualCount,
                                       PXKeychainClassName(secClass),
                                       group]];
                } else {
                    [warnings addObject:[NSString stringWithFormat:@"Failed to verify %@ items in group %@ after deletion: %@",
                                       PXKeychainClassName(secClass),
                                       group,
                                       PXSecurityErrorDescription(verificationStatus)]];
                }
            }
        }
    }
    
    result.warnings = warnings;
    return result;
}

#pragma mark - List

+ (NSArray<NSDictionary *> *)listKeychainItemsForAccessGroups:(NSArray<NSString *> *)groups
                                                   itemClasses:(PXKeychainItemClass)itemClasses {
    NSMutableArray<NSDictionary *> *allItems = [NSMutableArray array];
    
    for (NSString *group in groups) {
        for (NSNumber *classNum in PXAllKeychainClasses()) {
            PXKeychainItemClass classType = [classNum unsignedIntegerValue];
            if (!(itemClasses & classType)) continue;
            
            CFTypeRef secClass = PXSecItemClassFromType(classType);
            if (!secClass) continue;
            
            NSMutableDictionary *query = [@{
                (__bridge id)kSecClass: (__bridge id)secClass,
                (__bridge id)kSecAttrAccessGroup: group,
                (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll,
                (__bridge id)kSecReturnAttributes: @YES,
                (__bridge id)kSecAttrSynchronizable: (__bridge id)kSecAttrSynchronizableAny,
            } mutableCopy];
            PXAddAuthUIFlags(query);
            
            CFTypeRef cfResult = NULL;
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &cfResult);
            
            if (status != errSecSuccess) continue;
            
            NSArray *items = (__bridge_transfer NSArray *)cfResult;
            if (![items isKindOfClass:[NSArray class]]) {
                items = @[items];
            }
            
            for (NSDictionary *item in items) {
                NSMutableDictionary *info = [NSMutableDictionary dictionary];
                info[@"class"] = PXKeychainClassName(secClass);
                info[@"accessGroup"] = group;
                
                // Copy safe attributes for display.
                if (item[(__bridge id)kSecAttrAccount]) {
                    info[@"account"] = item[(__bridge id)kSecAttrAccount];
                }
                if (item[(__bridge id)kSecAttrService]) {
                    info[@"service"] = item[(__bridge id)kSecAttrService];
                }
                if (item[(__bridge id)kSecAttrLabel]) {
                    info[@"label"] = item[(__bridge id)kSecAttrLabel];
                }
                if (item[(__bridge id)kSecAttrCreationDate]) {
                    info[@"created"] = item[(__bridge id)kSecAttrCreationDate];
                }
                
                [allItems addObject:info];
            }
        }
    }
    
    return allItems;
}

+ (NSArray<NSDictionary *> *)diagnoseKeychainAccessForGroups:(NSArray<NSString *> *)groups
                                                 itemClasses:(PXKeychainItemClass)itemClasses {
    NSMutableArray<NSDictionary *> *out = [NSMutableArray array];
    for (NSString *group in groups) {
        for (NSNumber *classNum in PXAllKeychainClasses()) {
            PXKeychainItemClass classType = [classNum unsignedIntegerValue];
            if (!(itemClasses & classType)) continue;

            CFTypeRef secClass = PXSecItemClassFromType(classType);
            if (!secClass) continue;

            NSMutableDictionary *query = [@{
                (__bridge id)kSecClass: (__bridge id)secClass,
                (__bridge id)kSecAttrAccessGroup: group,
                (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll,
                (__bridge id)kSecReturnAttributes: @YES,
                (__bridge id)kSecAttrSynchronizable: (__bridge id)kSecAttrSynchronizableAny,
            } mutableCopy];
            PXAddAuthUIFlags(query);

            CFTypeRef cfResult = NULL;
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &cfResult);
            NSUInteger count = 0;
            if (status == errSecSuccess && cfResult) {
                id v = (__bridge_transfer id)cfResult;
                if ([v isKindOfClass:[NSArray class]]) {
                    count = [(NSArray *)v count];
                } else {
                    count = 1;
                }
            }

            [out addObject:@{
                @"accessGroup": group ?: @"",
                @"class": PXKeychainClassName(secClass),
                @"status": @((int)status),
                @"statusDesc": PXSecurityErrorDescription(status) ?: @"",
                @"count": @(count),
            }];
        }
    }
    return out;
}

@end
