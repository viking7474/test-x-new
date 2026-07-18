#import "KeychainBackupHelper.h"
#import "PXKeychainItemIdentity.h"
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>

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
        if (error) {
            *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                         code:PXKeychainBackupErrorInvalidArguments
                                     userInfo:@{NSLocalizedDescriptionKey: @"Backup file path is required"}];
        }
        return nil;
    }
    
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
    NSMutableArray<NSString *> *errors = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *allItems = [NSMutableArray array];
    
    // Iterate through each keychain class.
    for (NSNumber *classNum in PXAllKeychainClasses()) {
        PXKeychainItemClass classType = [classNum unsignedIntegerValue];
        if (!(itemClasses & classType)) {
            continue;
        }
        
        CFTypeRef secClass = PXSecItemClassFromType(classType);
        if (!secClass) continue;
        
        // Query for all items of this class with matching access groups.
        NSMutableDictionary *query = [@{
            (__bridge id)kSecClass: (__bridge id)secClass,
            (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll,
            (__bridge id)kSecReturnAttributes: @YES,
            (__bridge id)kSecReturnData: @YES,
            (__bridge id)kSecAttrSynchronizable: (__bridge id)kSecAttrSynchronizableAny,
            (__bridge id)kSecAttrAccessGroup: groups.firstObject, // Primary group
        } mutableCopy];
        PXAddAuthUIFlags(query);
        
        CFTypeRef cfResult = NULL;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &cfResult);
        
        if (status == errSecItemNotFound) {
            // No items of this class - not an error.
            continue;
        }
        
        if (status != errSecSuccess) {
            NSString *msg = [NSString stringWithFormat:@"Failed to query %@: %@",
                            PXKeychainClassName(secClass), PXSecurityErrorDescription(status)];
            [warnings addObject:msg];
            continue;
        }
        
        NSArray *items = (__bridge_transfer NSArray *)cfResult;
        if (![items isKindOfClass:[NSArray class]]) {
            items = @[items];
        }
        
        for (NSDictionary *item in items) {
            result.itemsProcessed++;
            
            // Create a serializable copy of the item.
            NSMutableDictionary *exportItem = [NSMutableDictionary dictionary];
            exportItem[@"_class"] = PXKeychainClassName(secClass);
            exportItem[@"_secClass"] = (__bridge id)secClass;
            
            for (NSString *key in item) {
                id value = item[key];
                
                // Convert NSData to base64 for serialization.
                if ([value isKindOfClass:[NSData class]]) {
                    exportItem[key] = @{
                        @"_type": @"data",
                        @"_base64": [(NSData *)value base64EncodedStringWithOptions:0]
                    };
                } else if ([value isKindOfClass:[NSDate class]]) {
                    exportItem[key] = @{
                        @"_type": @"date",
                        @"_timestamp": @([(NSDate *)value timeIntervalSince1970])
                    };
                } else if ([value isKindOfClass:[NSNumber class]] ||
                           [value isKindOfClass:[NSString class]]) {
                    exportItem[key] = value;
                }
                // Skip non-serializable types
            }
            
            [allItems addObject:exportItem];
            result.itemsSucceeded++;
        }
    }
    
    // Also try querying without access group restriction if we have special entitlements.
    // This catches items that might use different access groups we're also entitled to.
    for (NSString *group in groups) {
        if ([group isEqualToString:groups.firstObject]) continue; // Already queried
        
        for (NSNumber *classNum in PXAllKeychainClasses()) {
            PXKeychainItemClass classType = [classNum unsignedIntegerValue];
            if (!(itemClasses & classType)) continue;
            
            CFTypeRef secClass = PXSecItemClassFromType(classType);
            if (!secClass) continue;
            
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
            OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &cfResult);
            
            if (status != errSecSuccess) continue;
            
            NSArray *items = (__bridge_transfer NSArray *)cfResult;
            if (![items isKindOfClass:[NSArray class]]) {
                items = @[items];
            }
            
            for (NSDictionary *item in items) {
                result.itemsProcessed++;
                
                NSMutableDictionary *exportItem = [NSMutableDictionary dictionary];
                exportItem[@"_class"] = PXKeychainClassName(secClass);
                exportItem[@"_secClass"] = (__bridge id)secClass;
                
                for (NSString *key in item) {
                    id value = item[key];
                    if ([value isKindOfClass:[NSData class]]) {
                        exportItem[key] = @{
                            @"_type": @"data",
                            @"_base64": [(NSData *)value base64EncodedStringWithOptions:0]
                        };
                    } else if ([value isKindOfClass:[NSDate class]]) {
                        exportItem[key] = @{
                            @"_type": @"date",
                            @"_timestamp": @([(NSDate *)value timeIntervalSince1970])
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
    
    // Create backup dictionary.
    NSDictionary *backup = @{
        @"version": @1,
        @"created": @([[NSDate date] timeIntervalSince1970]),
        @"accessGroups": groups,
        @"items": allItems,
    };
    
    // Write to file.
    NSError *writeError = nil;
    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:backup
                                                                   format:NSPropertyListXMLFormat_v1_0
                                                                  options:0
                                                                    error:&writeError];
    if (!plistData) {
        if (error) {
            *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                         code:PXKeychainBackupErrorFileIO
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to serialize backup",
                                               NSUnderlyingErrorKey: writeError ?: [NSNull null]}];
        }
        return nil;
    }
    
    BOOL written = [plistData writeToFile:filePath options:NSDataWritingAtomic error:&writeError];
    if (!written) {
        if (error) {
            *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                         code:PXKeychainBackupErrorFileIO
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to write backup file",
                                               NSUnderlyingErrorKey: writeError ?: [NSNull null]}];
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

    NSData *plistData = [NSData dataWithContentsOfFile:filePath];
    if (!plistData.length) {
        if (error) {
            *error = [NSError errorWithDomain:PXKeychainBackupErrorDomain
                                         code:PXKeychainBackupErrorFileIO
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to read backup file or file is empty"}];
        }
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
            } mutableCopy];
            PXAddAuthUIFlags(query);
            
            // First count items.
            NSMutableDictionary *countQuery = [@{
                (__bridge id)kSecClass: (__bridge id)secClass,
                (__bridge id)kSecAttrAccessGroup: group,
                (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll,
                (__bridge id)kSecReturnAttributes: @YES,
                (__bridge id)kSecAttrSynchronizable: (__bridge id)kSecAttrSynchronizableAny,
            } mutableCopy];
            PXAddAuthUIFlags(countQuery);
            
            CFTypeRef countResult = NULL;
            OSStatus countStatus = SecItemCopyMatching((__bridge CFDictionaryRef)countQuery, &countResult);
            
            NSUInteger itemCount = 0;
            if (countStatus == errSecSuccess && countResult) {
                NSArray *matches = (__bridge_transfer NSArray *)countResult;
                if ([matches isKindOfClass:[NSArray class]]) {
                    itemCount = matches.count;
                } else {
                    itemCount = 1;
                }
            }
            
            result.itemsProcessed += itemCount;
            
            // Delete all matching items.
            OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
            
            if (status == errSecSuccess || status == errSecItemNotFound) {
                result.itemsSucceeded += itemCount;
            } else {
                [warnings addObject:[NSString stringWithFormat:@"Failed to delete %@ items in group %@: %@",
                                   PXKeychainClassName(secClass), group, PXSecurityErrorDescription(status)]];
                result.itemsFailed += itemCount;
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
