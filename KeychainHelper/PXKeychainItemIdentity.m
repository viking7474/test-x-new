#import "PXKeychainItemIdentity.h"
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>
#import <stdint.h>

NSInteger const PXKeychainItemIdentitySchemaVersion = 1;
NSErrorDomain const PXKeychainItemIdentityErrorDomain = @"com.hydra.projectx.keychain-item-identity";
NSString * const PXKeychainItemIdentityErrorFieldPathKey = @"fieldPath";

static const NSUInteger PXKeychainItemIdentityMaximumInputEntries = 256;
static const NSUInteger PXKeychainItemIdentityMaximumAccessGroupBytes = 1024;
static const NSUInteger PXKeychainItemIdentityMaximumOrdinaryStringBytes = 4096;
static const NSUInteger PXKeychainItemIdentityMaximumConstantStringBytes = 255;
static const NSUInteger PXKeychainItemIdentityMaximumIssuerBytes = 65536;
static const NSUInteger PXKeychainItemIdentityMaximumSerialNumberBytes = 1024;
static const NSUInteger PXKeychainItemIdentityMaximumApplicationLabelBytes = 1024;
static const NSUInteger PXKeychainItemIdentityMaximumAttributeCount = 10;
static const NSUInteger PXKeychainItemIdentityMaximumQueryKeyCount = 10;
static const NSUInteger PXKeychainItemIdentityMaximumAggregateBytes = 131072;

static NSString * const PXKeychainItemIdentityRootFieldPath = @"$";
static NSString * const PXKeychainItemIdentityClassFieldPath = @"$.kSecClass";
static NSString * const PXKeychainItemIdentityAccessGroupFieldPath = @"$.kSecAttrAccessGroup";
static NSString * const PXKeychainItemIdentitySynchronizableFieldPath = @"$.kSecAttrSynchronizable";
static NSString * const PXKeychainItemIdentityAccountFieldPath = @"$.kSecAttrAccount";
static NSString * const PXKeychainItemIdentityServiceFieldPath = @"$.kSecAttrService";
static NSString * const PXKeychainItemIdentityServerFieldPath = @"$.kSecAttrServer";
static NSString * const PXKeychainItemIdentityPortFieldPath = @"$.kSecAttrPort";
static NSString * const PXKeychainItemIdentityProtocolFieldPath = @"$.kSecAttrProtocol";
static NSString * const PXKeychainItemIdentityAuthenticationTypeFieldPath = @"$.kSecAttrAuthenticationType";
static NSString * const PXKeychainItemIdentityPathFieldPath = @"$.kSecAttrPath";
static NSString * const PXKeychainItemIdentitySecurityDomainFieldPath = @"$.kSecAttrSecurityDomain";
static NSString * const PXKeychainItemIdentityIssuerFieldPath = @"$.kSecAttrIssuer";
static NSString * const PXKeychainItemIdentitySerialNumberFieldPath = @"$.kSecAttrSerialNumber";
static NSString * const PXKeychainItemIdentityApplicationLabelFieldPath = @"$.kSecAttrApplicationLabel";
static NSString * const PXKeychainItemIdentityKeyClassFieldPath = @"$.kSecAttrKeyClass";
static NSString * const PXKeychainItemIdentityKeyTypeFieldPath = @"$.kSecAttrKeyType";
static NSString * const PXKeychainItemIdentityTupleFieldPath = @"$.identity";

typedef NS_ENUM(NSInteger, PXKeychainItemIdentityValueStatus) {
    PXKeychainItemIdentityValueStatusSuccess = 0,
    PXKeychainItemIdentityValueStatusMissing = 1,
    PXKeychainItemIdentityValueStatusWrongType = 2,
    PXKeychainItemIdentityValueStatusInvalidValue = 3,
    PXKeychainItemIdentityValueStatusLimitExceeded = 4,
    PXKeychainItemIdentityValueStatusSnapshotFailed = 5,
};

static void PXKeychainItemIdentitySetError(NSError **error,
                                            PXKeychainItemIdentityErrorCode code,
                                            NSString *fieldPath,
                                            NSString *description) {
    if (!error) {
        return;
    }
    *error = [NSError errorWithDomain:PXKeychainItemIdentityErrorDomain
                                 code:code
                             userInfo:@{
                                 NSLocalizedDescriptionKey: description,
                                 PXKeychainItemIdentityErrorFieldPathKey: fieldPath,
                             }];
}

static BOOL PXKeychainItemIdentityExtractExactCFBoolean(id value,
                                                         BOOL *booleanOut) {
    if (![value isKindOfClass:[NSNumber class]]) {
        return NO;
    }
    CFTypeRef cfValue = (__bridge CFTypeRef)value;
    if (CFGetTypeID(cfValue) != CFBooleanGetTypeID()) {
        return NO;
    }
    if (booleanOut) {
        *booleanOut = CFBooleanGetValue((__bridge CFBooleanRef)value);
    }
    return YES;
}

static BOOL PXKeychainItemIdentityIsString(id value) {
    return [value isKindOfClass:[NSString class]] &&
           CFGetTypeID((__bridge CFTypeRef)value) == CFStringGetTypeID();
}

static BOOL PXKeychainItemIdentityIsData(id value) {
    return [value isKindOfClass:[NSData class]] &&
           CFGetTypeID((__bridge CFTypeRef)value) == CFDataGetTypeID();
}

static BOOL PXKeychainItemIdentityStringContainsControlCharacter(NSString *string) {
    NSUInteger length = string.length;
    for (NSUInteger index = 0; index < length; index++) {
        unichar character = [string characterAtIndex:index];
        if (character <= 0x001F ||
            (character >= 0x007F && character <= 0x009F)) {
            return YES;
        }
    }
    return NO;
}

static PXKeychainItemIdentityValueStatus PXKeychainItemIdentityCopyString(
    id value,
    BOOL allowEmpty,
    NSUInteger maximumBytes,
    NSString **stringOut,
    NSUInteger *byteCountOut) {
    if (!value) {
        return PXKeychainItemIdentityValueStatusMissing;
    }
    if (!PXKeychainItemIdentityIsString(value)) {
        return PXKeychainItemIdentityValueStatusWrongType;
    }

    NSString *string = (NSString *)value;
    NSData *utf8 = [string dataUsingEncoding:NSUTF8StringEncoding
                        allowLossyConversion:NO];
    if (!utf8) {
        return PXKeychainItemIdentityValueStatusInvalidValue;
    }
    if (utf8.length > maximumBytes) {
        return PXKeychainItemIdentityValueStatusLimitExceeded;
    }

    NSString *snapshot = [[NSString alloc] initWithData:utf8
                                                 encoding:NSUTF8StringEncoding];
    if (!snapshot) {
        return PXKeychainItemIdentityValueStatusSnapshotFailed;
    }
    if (![snapshot isEqualToString:string] ||
        (!allowEmpty && snapshot.length == 0) ||
        PXKeychainItemIdentityStringContainsControlCharacter(snapshot)) {
        return PXKeychainItemIdentityValueStatusInvalidValue;
    }

    if (stringOut) {
        *stringOut = snapshot;
    }
    if (byteCountOut) {
        *byteCountOut = utf8.length;
    }
    return PXKeychainItemIdentityValueStatusSuccess;
}

static PXKeychainItemIdentityValueStatus PXKeychainItemIdentityCopyData(
    id value,
    NSUInteger maximumBytes,
    NSData **dataOut,
    NSUInteger *byteCountOut) {
    if (!value) {
        return PXKeychainItemIdentityValueStatusMissing;
    }
    if (!PXKeychainItemIdentityIsData(value)) {
        return PXKeychainItemIdentityValueStatusWrongType;
    }

    NSData *data = (NSData *)value;
    NSUInteger length = data.length;
    if (length == 0) {
        return PXKeychainItemIdentityValueStatusInvalidValue;
    }
    if (length > maximumBytes) {
        return PXKeychainItemIdentityValueStatusLimitExceeded;
    }

    NSData *snapshot = [[NSData alloc] initWithData:data];
    if (!snapshot || snapshot.length != length) {
        return PXKeychainItemIdentityValueStatusSnapshotFailed;
    }
    if (dataOut) {
        *dataOut = snapshot;
    }
    if (byteCountOut) {
        *byteCountOut = length;
    }
    return PXKeychainItemIdentityValueStatusSuccess;
}

static PXKeychainItemIdentityValueStatus PXKeychainItemIdentityCopyPort(
    id value,
    NSNumber **numberOut,
    NSUInteger *byteCountOut) {
    if (!value) {
        return PXKeychainItemIdentityValueStatusMissing;
    }
    if (![value isKindOfClass:[NSNumber class]] ||
        CFGetTypeID((__bridge CFTypeRef)value) != CFNumberGetTypeID()) {
        return PXKeychainItemIdentityValueStatusWrongType;
    }

    BOOL booleanValue = NO;
    if (PXKeychainItemIdentityExtractExactCFBoolean(value, &booleanValue)) {
        (void)booleanValue;
        return PXKeychainItemIdentityValueStatusWrongType;
    }

    double port = [(NSNumber *)value doubleValue];
    if (!isfinite(port) || floor(port) != port || port < 0.0 || port > 65535.0) {
        return PXKeychainItemIdentityValueStatusInvalidValue;
    }

    NSNumber *snapshot = [NSNumber numberWithUnsignedInteger:(NSUInteger)port];
    if (!snapshot) {
        return PXKeychainItemIdentityValueStatusSnapshotFailed;
    }
    if (numberOut) {
        *numberOut = snapshot;
    }
    if (byteCountOut) {
        *byteCountOut = sizeof(uint64_t);
    }
    return PXKeychainItemIdentityValueStatusSuccess;
}

static void PXKeychainItemIdentitySetAttributeError(
    PXKeychainItemIdentityValueStatus status,
    NSString *fieldPath,
    NSError **error) {
    switch (status) {
        case PXKeychainItemIdentityValueStatusMissing:
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorMissingIdentityAttribute,
                                            fieldPath,
                                            @"A required identity attribute is missing.");
            break;
        case PXKeychainItemIdentityValueStatusWrongType:
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorInvalidIdentityAttributeType,
                                            fieldPath,
                                            @"An identity attribute has an invalid type.");
            break;
        case PXKeychainItemIdentityValueStatusInvalidValue:
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorInvalidIdentityAttributeValue,
                                            fieldPath,
                                            @"An identity attribute has an invalid value.");
            break;
        case PXKeychainItemIdentityValueStatusLimitExceeded:
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorLimitExceeded,
                                            fieldPath,
                                            @"An identity attribute exceeds a fixed limit.");
            break;
        case PXKeychainItemIdentityValueStatusSnapshotFailed:
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorSnapshotFailed,
                                            fieldPath,
                                            @"An immutable identity attribute snapshot could not be created.");
            break;
        case PXKeychainItemIdentityValueStatusSuccess:
            break;
    }
}

static BOOL PXKeychainItemIdentitySafeAdd(NSUInteger *total,
                                           NSUInteger amount) {
    if (!total || amount > NSUIntegerMax - *total) {
        return NO;
    }
    *total += amount;
    return YES;
}

static NSUInteger PXKeychainItemIdentityStringByteCount(NSString *string) {
    NSData *utf8 = [string dataUsingEncoding:NSUTF8StringEncoding
                        allowLossyConversion:NO];
    return utf8 ? utf8.length : NSUIntegerMax;
}

static NSString *PXKeychainItemIdentityClassName(PXKeychainItemIdentityClass itemClass) {
    switch (itemClass) {
        case PXKeychainItemIdentityClassUnknown:
            return @"unknown";
        case PXKeychainItemIdentityClassGenericPassword:
            return @"generic-password";
        case PXKeychainItemIdentityClassInternetPassword:
            return @"internet-password";
        case PXKeychainItemIdentityClassCertificate:
            return @"certificate";
        case PXKeychainItemIdentityClassKey:
            return @"key";
        case PXKeychainItemIdentityClassIdentity:
            return @"identity";
    }
    return nil;
}

static BOOL PXKeychainItemIdentityResolveClass(
    id classValue,
    PXKeychainItemIdentityClass *itemClassOut,
    CFStringRef *securityClassOut,
    NSUInteger *expectedQueryCountOut) {
    if (!PXKeychainItemIdentityIsString(classValue)) {
        return NO;
    }

    PXKeychainItemIdentityClass itemClass = PXKeychainItemIdentityClassUnknown;
    CFStringRef securityClass = NULL;
    NSUInteger expectedQueryCount = 0;

    if (classValue == (__bridge id)kSecClassGenericPassword) {
        itemClass = PXKeychainItemIdentityClassGenericPassword;
        securityClass = kSecClassGenericPassword;
        expectedQueryCount = 5;
    } else if (classValue == (__bridge id)kSecClassInternetPassword) {
        itemClass = PXKeychainItemIdentityClassInternetPassword;
        securityClass = kSecClassInternetPassword;
        expectedQueryCount = 10;
    } else if (classValue == (__bridge id)kSecClassCertificate) {
        itemClass = PXKeychainItemIdentityClassCertificate;
        securityClass = kSecClassCertificate;
        expectedQueryCount = 5;
    } else if (classValue == (__bridge id)kSecClassKey) {
        itemClass = PXKeychainItemIdentityClassKey;
        securityClass = kSecClassKey;
        expectedQueryCount = 6;
    } else if (classValue == (__bridge id)kSecClassIdentity) {
        itemClass = PXKeychainItemIdentityClassIdentity;
        securityClass = kSecClassIdentity;
        expectedQueryCount = 6;
    } else {
        return NO;
    }

    if (itemClassOut) {
        *itemClassOut = itemClass;
    }
    if (securityClassOut) {
        *securityClassOut = securityClass;
    }
    if (expectedQueryCountOut) {
        *expectedQueryCountOut = expectedQueryCount;
    }
    return YES;
}

static BOOL PXKeychainItemIdentityHasInternetFallbackAttributes(NSDictionary *attributes) {
    return attributes[(__bridge id)kSecAttrAccount] != nil ||
           attributes[(__bridge id)kSecAttrServer] != nil ||
           attributes[(__bridge id)kSecAttrPort] != nil ||
           attributes[(__bridge id)kSecAttrProtocol] != nil ||
           attributes[(__bridge id)kSecAttrAuthenticationType] != nil ||
           attributes[(__bridge id)kSecAttrPath] != nil ||
           attributes[(__bridge id)kSecAttrSecurityDomain] != nil ||
           attributes[(__bridge id)kSecAttrLabel] != nil ||
           attributes[(__bridge id)kSecAttrDescription] != nil ||
           attributes[(__bridge id)kSecAttrComment] != nil;
}

static BOOL PXKeychainItemIdentityHasCertificateFallbackAttributes(NSDictionary *attributes) {
    return attributes[(__bridge id)kSecAttrLabel] != nil ||
           attributes[(__bridge id)kSecAttrSubject] != nil ||
           attributes[(__bridge id)kSecAttrSubjectKeyID] != nil ||
           attributes[(__bridge id)kSecAttrPublicKeyHash] != nil;
}

static BOOL PXKeychainItemIdentityHasKeyFallbackAttributes(NSDictionary *attributes) {
    return attributes[(__bridge id)kSecAttrApplicationTag] != nil ||
           attributes[(__bridge id)kSecAttrLabel] != nil ||
           attributes[(__bridge id)kSecAttrEffectiveKeySize] != nil ||
           attributes[(__bridge id)kSecAttrKeySizeInBits] != nil;
}

static BOOL PXKeychainItemIdentityHasIdentityFallbackAttributes(NSDictionary *attributes) {
    return PXKeychainItemIdentityHasCertificateFallbackAttributes(attributes) ||
           PXKeychainItemIdentityHasKeyFallbackAttributes(attributes) ||
           attributes[(__bridge id)kSecAttrKeyClass] != nil ||
           attributes[(__bridge id)kSecAttrKeyType] != nil;
}

static BOOL PXKeychainItemIdentityAppendAttribute(
    NSMutableArray<NSString *> *names,
    NSMutableDictionary<NSString *, id> *identityAttributes,
    CFStringRef key,
    id value,
    NSUInteger valueByteCount,
    NSUInteger *aggregateByteCount) {
    if (!names || !identityAttributes || !key || !value || !aggregateByteCount ||
        names.count >= PXKeychainItemIdentityMaximumAttributeCount) {
        return NO;
    }

    NSString *keySnapshot = [(__bridge NSString *)key copy];
    if (!keySnapshot || identityAttributes[keySnapshot] != nil) {
        return NO;
    }
    NSUInteger keyByteCount = PXKeychainItemIdentityStringByteCount(keySnapshot);
    if (keyByteCount == NSUIntegerMax ||
        !PXKeychainItemIdentitySafeAdd(aggregateByteCount, keyByteCount) ||
        !PXKeychainItemIdentitySafeAdd(aggregateByteCount, valueByteCount) ||
        *aggregateByteCount > PXKeychainItemIdentityMaximumAggregateBytes) {
        return NO;
    }

    [names addObject:keySnapshot];
    identityAttributes[keySnapshot] = value;
    return YES;
}

static BOOL PXKeychainItemIdentityValueIsImmutablePropertyListPrimitive(id value) {
    if (PXKeychainItemIdentityIsString(value)) {
        return ![value isKindOfClass:[NSMutableString class]];
    }
    if (PXKeychainItemIdentityIsData(value)) {
        return ![value isKindOfClass:[NSMutableData class]];
    }
    return [value isKindOfClass:[NSNumber class]];
}

static BOOL PXKeychainItemIdentitySnapshotMatchesState(
    PXKeychainItemIdentityClass itemClass,
    NSString *className,
    NSString *accessGroup,
    BOOL synchronizable,
    NSArray<NSString *> *identityAttributeNames,
    NSDictionary<NSString *, id> *identityAttributes,
    NSDictionary<NSString *, id> *matchQuery,
    CFStringRef securityClass,
    NSUInteger expectedQueryCount) {
    if (itemClass == PXKeychainItemIdentityClassUnknown ||
        ![className isEqualToString:PXKeychainItemIdentityClassName(itemClass)] ||
        !PXKeychainItemIdentityIsString(accessGroup) ||
        ![identityAttributeNames isKindOfClass:[NSArray class]] ||
        ![identityAttributes isKindOfClass:[NSDictionary class]] ||
        ![matchQuery isKindOfClass:[NSDictionary class]] ||
        identityAttributeNames.count == 0 ||
        identityAttributeNames.count > PXKeychainItemIdentityMaximumAttributeCount ||
        identityAttributes.count != identityAttributeNames.count ||
        matchQuery.count != expectedQueryCount ||
        matchQuery.count != identityAttributeNames.count + 1 ||
        matchQuery.count > PXKeychainItemIdentityMaximumQueryKeyCount) {
        return NO;
    }

    NSSet *uniqueNames = [NSSet setWithArray:identityAttributeNames];
    if (uniqueNames.count != identityAttributeNames.count) {
        return NO;
    }

    NSString *accessGroupKey = (__bridge NSString *)kSecAttrAccessGroup;
    NSString *synchronizableKey = (__bridge NSString *)kSecAttrSynchronizable;
    id retainedAccessGroup = identityAttributes[accessGroupKey];
    id retainedSynchronizable = identityAttributes[synchronizableKey];
    BOOL retainedBoolean = NO;
    if (!PXKeychainItemIdentityIsString(retainedAccessGroup) ||
        ![(NSString *)retainedAccessGroup isEqualToString:accessGroup] ||
        !PXKeychainItemIdentityExtractExactCFBoolean(retainedSynchronizable, &retainedBoolean) ||
        retainedBoolean != synchronizable) {
        return NO;
    }

    id retainedClass = matchQuery[(__bridge id)kSecClass];
    if (!PXKeychainItemIdentityIsString(retainedClass) ||
        retainedClass != (__bridge id)securityClass) {
        return NO;
    }

    for (id nameObject in identityAttributeNames) {
        if (!PXKeychainItemIdentityIsString(nameObject)) {
            return NO;
        }
        NSString *name = (NSString *)nameObject;
        id identityValue = identityAttributes[name];
        id queryValue = matchQuery[name];
        if (!identityValue || !queryValue ||
            ![identityValue isEqual:queryValue] ||
            !PXKeychainItemIdentityValueIsImmutablePropertyListPrimitive(identityValue)) {
            return NO;
        }
    }
    return YES;
}

@interface PXKeychainItemIdentity ()

- (instancetype)initWithItemClass:(PXKeychainItemIdentityClass)itemClass
                           className:(NSString *)className
                         accessGroup:(NSString *)accessGroup
                      synchronizable:(BOOL)synchronizable
              identityAttributeNames:(NSArray<NSString *> *)identityAttributeNames
                  identityAttributes:(NSDictionary<NSString *, id> *)identityAttributes
                          matchQuery:(NSDictionary<NSString *, id> *)matchQuery;

@end

@implementation PXKeychainItemIdentity

+ (instancetype)identityForSecurityItemAttributes:(NSDictionary<NSString *, id> *)attributes
                                             error:(NSError **)error {
    if (error) {
        *error = nil;
    }

    @try {
        if (![attributes isKindOfClass:[NSDictionary class]]) {
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorInvalidInput,
                                            PXKeychainItemIdentityRootFieldPath,
                                            @"The identity input must be a dictionary.");
            return nil;
        }
        if (attributes.count > PXKeychainItemIdentityMaximumInputEntries) {
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorLimitExceeded,
                                            PXKeychainItemIdentityRootFieldPath,
                                            @"The identity input exceeds the entry limit.");
            return nil;
        }

        NSDictionary<NSString *, id> *input =
            [[NSDictionary alloc] initWithDictionary:attributes copyItems:NO];
        if (!input) {
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorSnapshotFailed,
                                            PXKeychainItemIdentityRootFieldPath,
                                            @"The identity input snapshot could not be created.");
            return nil;
        }
        if (input.count > PXKeychainItemIdentityMaximumInputEntries) {
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorLimitExceeded,
                                            PXKeychainItemIdentityRootFieldPath,
                                            @"The identity input snapshot exceeds the entry limit.");
            return nil;
        }

        PXKeychainItemIdentityClass itemClass = PXKeychainItemIdentityClassUnknown;
        CFStringRef securityClass = NULL;
        NSUInteger expectedQueryCount = 0;
        if (!PXKeychainItemIdentityResolveClass(input[(__bridge id)kSecClass],
                                                 &itemClass,
                                                 &securityClass,
                                                 &expectedQueryCount)) {
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorUnsupportedClass,
                                            PXKeychainItemIdentityClassFieldPath,
                                            @"The Security item class is missing or unsupported.");
            return nil;
        }

        id accessGroupValue = input[(__bridge id)kSecAttrAccessGroup];
        if (!accessGroupValue) {
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorMissingAccessGroup,
                                            PXKeychainItemIdentityAccessGroupFieldPath,
                                            @"The access group is required.");
            return nil;
        }

        NSString *accessGroup = nil;
        NSUInteger accessGroupByteCount = 0;
        PXKeychainItemIdentityValueStatus accessGroupStatus =
            PXKeychainItemIdentityCopyString(accessGroupValue,
                                              NO,
                                              PXKeychainItemIdentityMaximumAccessGroupBytes,
                                              &accessGroup,
                                              &accessGroupByteCount);
        if (accessGroupStatus != PXKeychainItemIdentityValueStatusSuccess) {
            if (accessGroupStatus == PXKeychainItemIdentityValueStatusLimitExceeded) {
                PXKeychainItemIdentitySetError(error,
                                                PXKeychainItemIdentityErrorLimitExceeded,
                                                PXKeychainItemIdentityAccessGroupFieldPath,
                                                @"The access group exceeds the byte limit.");
            } else if (accessGroupStatus == PXKeychainItemIdentityValueStatusSnapshotFailed) {
                PXKeychainItemIdentitySetError(error,
                                                PXKeychainItemIdentityErrorSnapshotFailed,
                                                PXKeychainItemIdentityAccessGroupFieldPath,
                                                @"The immutable access-group snapshot could not be created.");
            } else {
                PXKeychainItemIdentitySetError(error,
                                                PXKeychainItemIdentityErrorInvalidAccessGroup,
                                                PXKeychainItemIdentityAccessGroupFieldPath,
                                                @"The access group has an invalid type or value.");
            }
            return nil;
        }

        BOOL synchronizable = NO;
        id synchronizableValue = input[(__bridge id)kSecAttrSynchronizable];
        if (synchronizableValue &&
            !PXKeychainItemIdentityExtractExactCFBoolean(synchronizableValue,
                                                         &synchronizable)) {
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorInvalidSynchronizable,
                                            PXKeychainItemIdentitySynchronizableFieldPath,
                                            @"The synchronizable attribute must be an exact Boolean.");
            return nil;
        }
        NSNumber *canonicalSynchronizable = @(synchronizable);

        NSString *className = PXKeychainItemIdentityClassName(itemClass);
        NSString *classNameSnapshot = [[NSString alloc] initWithString:className];
        if (!classNameSnapshot) {
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorSnapshotFailed,
                                            PXKeychainItemIdentityClassFieldPath,
                                            @"The immutable class-name snapshot could not be created.");
            return nil;
        }

        NSUInteger aggregateByteCount = PXKeychainItemIdentityStringByteCount(classNameSnapshot);
        if (aggregateByteCount == NSUIntegerMax ||
            aggregateByteCount > PXKeychainItemIdentityMaximumAggregateBytes) {
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorLimitExceeded,
                                            PXKeychainItemIdentityTupleFieldPath,
                                            @"The retained identity exceeds the aggregate byte limit.");
            return nil;
        }

        NSMutableArray<NSString *> *names = [NSMutableArray array];
        NSMutableDictionary<NSString *, id> *identityAttributes = [NSMutableDictionary dictionary];
        if (!PXKeychainItemIdentityAppendAttribute(names,
                                                    identityAttributes,
                                                    kSecAttrAccessGroup,
                                                    accessGroup,
                                                    accessGroupByteCount,
                                                    &aggregateByteCount) ||
            !PXKeychainItemIdentityAppendAttribute(names,
                                                    identityAttributes,
                                                    kSecAttrSynchronizable,
                                                    canonicalSynchronizable,
                                                    sizeof(BOOL),
                                                    &aggregateByteCount)) {
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorSnapshotFailed,
                                            PXKeychainItemIdentityTupleFieldPath,
                                            @"The common identity snapshot could not be created.");
            return nil;
        }

        switch (itemClass) {
            case PXKeychainItemIdentityClassGenericPassword: {
                NSString *account = nil;
                NSString *service = nil;
                NSUInteger accountBytes = 0;
                NSUInteger serviceBytes = 0;
                PXKeychainItemIdentityValueStatus accountStatus =
                    PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrAccount],
                                                      YES,
                                                      PXKeychainItemIdentityMaximumOrdinaryStringBytes,
                                                      &account,
                                                      &accountBytes);
                if (accountStatus != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(accountStatus,
                                                             PXKeychainItemIdentityAccountFieldPath,
                                                             error);
                    return nil;
                }
                PXKeychainItemIdentityValueStatus serviceStatus =
                    PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrService],
                                                      YES,
                                                      PXKeychainItemIdentityMaximumOrdinaryStringBytes,
                                                      &service,
                                                      &serviceBytes);
                if (serviceStatus != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(serviceStatus,
                                                             PXKeychainItemIdentityServiceFieldPath,
                                                             error);
                    return nil;
                }
                if (!PXKeychainItemIdentityAppendAttribute(names,
                                                            identityAttributes,
                                                            kSecAttrAccount,
                                                            account,
                                                            accountBytes,
                                                            &aggregateByteCount) ||
                    !PXKeychainItemIdentityAppendAttribute(names,
                                                            identityAttributes,
                                                            kSecAttrService,
                                                            service,
                                                            serviceBytes,
                                                            &aggregateByteCount)) {
                    PXKeychainItemIdentitySetError(error,
                                                    PXKeychainItemIdentityErrorSnapshotFailed,
                                                    PXKeychainItemIdentityTupleFieldPath,
                                                    @"The generic-password identity snapshot could not be created.");
                    return nil;
                }
                break;
            }

            case PXKeychainItemIdentityClassInternetPassword: {
                CFStringRef requiredKeys[] = {
                    kSecAttrAccount,
                    kSecAttrServer,
                    kSecAttrPort,
                    kSecAttrProtocol,
                    kSecAttrAuthenticationType,
                    kSecAttrPath,
                    kSecAttrSecurityDomain,
                };
                NSString *requiredPaths[] = {
                    PXKeychainItemIdentityAccountFieldPath,
                    PXKeychainItemIdentityServerFieldPath,
                    PXKeychainItemIdentityPortFieldPath,
                    PXKeychainItemIdentityProtocolFieldPath,
                    PXKeychainItemIdentityAuthenticationTypeFieldPath,
                    PXKeychainItemIdentityPathFieldPath,
                    PXKeychainItemIdentitySecurityDomainFieldPath,
                };
                for (NSUInteger index = 0; index < sizeof(requiredKeys) / sizeof(requiredKeys[0]); index++) {
                    if (!input[(__bridge id)requiredKeys[index]]) {
                        if (PXKeychainItemIdentityHasInternetFallbackAttributes(input)) {
                            PXKeychainItemIdentitySetError(error,
                                                            PXKeychainItemIdentityErrorAmbiguousIdentity,
                                                            PXKeychainItemIdentityTupleFieldPath,
                                                            @"The internet-password identity tuple is ambiguous.");
                        } else {
                            PXKeychainItemIdentitySetError(error,
                                                            PXKeychainItemIdentityErrorMissingIdentityAttribute,
                                                            requiredPaths[index],
                                                            @"A required identity attribute is missing.");
                        }
                        return nil;
                    }
                }

                NSString *account = nil;
                NSString *server = nil;
                NSString *protocol = nil;
                NSString *authenticationType = nil;
                NSString *path = nil;
                NSString *securityDomain = nil;
                NSNumber *port = nil;
                NSUInteger accountBytes = 0;
                NSUInteger serverBytes = 0;
                NSUInteger protocolBytes = 0;
                NSUInteger authenticationTypeBytes = 0;
                NSUInteger pathBytes = 0;
                NSUInteger securityDomainBytes = 0;
                NSUInteger portBytes = 0;

                PXKeychainItemIdentityValueStatus status =
                    PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrAccount],
                                                      YES,
                                                      PXKeychainItemIdentityMaximumOrdinaryStringBytes,
                                                      &account,
                                                      &accountBytes);
                if (status != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(status,
                                                             PXKeychainItemIdentityAccountFieldPath,
                                                             error);
                    return nil;
                }
                status = PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrServer],
                                                           NO,
                                                           PXKeychainItemIdentityMaximumOrdinaryStringBytes,
                                                           &server,
                                                           &serverBytes);
                if (status != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(status,
                                                             PXKeychainItemIdentityServerFieldPath,
                                                             error);
                    return nil;
                }
                status = PXKeychainItemIdentityCopyPort(input[(__bridge id)kSecAttrPort],
                                                         &port,
                                                         &portBytes);
                if (status != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(status,
                                                             PXKeychainItemIdentityPortFieldPath,
                                                             error);
                    return nil;
                }
                status = PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrProtocol],
                                                           NO,
                                                           PXKeychainItemIdentityMaximumConstantStringBytes,
                                                           &protocol,
                                                           &protocolBytes);
                if (status != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(status,
                                                             PXKeychainItemIdentityProtocolFieldPath,
                                                             error);
                    return nil;
                }
                status = PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrAuthenticationType],
                                                           NO,
                                                           PXKeychainItemIdentityMaximumConstantStringBytes,
                                                           &authenticationType,
                                                           &authenticationTypeBytes);
                if (status != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(status,
                                                             PXKeychainItemIdentityAuthenticationTypeFieldPath,
                                                             error);
                    return nil;
                }
                status = PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrPath],
                                                           YES,
                                                           PXKeychainItemIdentityMaximumOrdinaryStringBytes,
                                                           &path,
                                                           &pathBytes);
                if (status != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(status,
                                                             PXKeychainItemIdentityPathFieldPath,
                                                             error);
                    return nil;
                }
                status = PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrSecurityDomain],
                                                           YES,
                                                           PXKeychainItemIdentityMaximumOrdinaryStringBytes,
                                                           &securityDomain,
                                                           &securityDomainBytes);
                if (status != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(status,
                                                             PXKeychainItemIdentitySecurityDomainFieldPath,
                                                             error);
                    return nil;
                }

                if (!PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrAccount, account, accountBytes, &aggregateByteCount) ||
                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrServer, server, serverBytes, &aggregateByteCount) ||
                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrPort, port, portBytes, &aggregateByteCount) ||
                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrProtocol, protocol, protocolBytes, &aggregateByteCount) ||
                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrAuthenticationType, authenticationType, authenticationTypeBytes, &aggregateByteCount) ||
                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrPath, path, pathBytes, &aggregateByteCount) ||
                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrSecurityDomain, securityDomain, securityDomainBytes, &aggregateByteCount)) {
                    PXKeychainItemIdentitySetError(error,
                                                    PXKeychainItemIdentityErrorSnapshotFailed,
                                                    PXKeychainItemIdentityTupleFieldPath,
                                                    @"The internet-password identity snapshot could not be created.");
                    return nil;
                }
                break;
            }

            case PXKeychainItemIdentityClassCertificate: {
                id issuerValue = input[(__bridge id)kSecAttrIssuer];
                id serialNumberValue = input[(__bridge id)kSecAttrSerialNumber];
                if (!issuerValue || !serialNumberValue) {
                    if (issuerValue || serialNumberValue ||
                        PXKeychainItemIdentityHasCertificateFallbackAttributes(input)) {
                        PXKeychainItemIdentitySetError(error,
                                                        PXKeychainItemIdentityErrorAmbiguousIdentity,
                                                        PXKeychainItemIdentityTupleFieldPath,
                                                        @"The certificate identity tuple is ambiguous.");
                    } else {
                        PXKeychainItemIdentitySetError(error,
                                                        PXKeychainItemIdentityErrorMissingIdentityAttribute,
                                                        issuerValue ? PXKeychainItemIdentitySerialNumberFieldPath : PXKeychainItemIdentityIssuerFieldPath,
                                                        @"A required identity attribute is missing.");
                    }
                    return nil;
                }

                NSData *issuer = nil;
                NSData *serialNumber = nil;
                NSUInteger issuerBytes = 0;
                NSUInteger serialNumberBytes = 0;
                PXKeychainItemIdentityValueStatus status =
                    PXKeychainItemIdentityCopyData(issuerValue,
                                                    PXKeychainItemIdentityMaximumIssuerBytes,
                                                    &issuer,
                                                    &issuerBytes);
                if (status != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(status,
                                                             PXKeychainItemIdentityIssuerFieldPath,
                                                             error);
                    return nil;
                }
                status = PXKeychainItemIdentityCopyData(serialNumberValue,
                                                         PXKeychainItemIdentityMaximumSerialNumberBytes,
                                                         &serialNumber,
                                                         &serialNumberBytes);
                if (status != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(status,
                                                             PXKeychainItemIdentitySerialNumberFieldPath,
                                                             error);
                    return nil;
                }
                if (!PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrIssuer, issuer, issuerBytes, &aggregateByteCount) ||
                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrSerialNumber, serialNumber, serialNumberBytes, &aggregateByteCount)) {
                    PXKeychainItemIdentitySetError(error,
                                                    PXKeychainItemIdentityErrorSnapshotFailed,
                                                    PXKeychainItemIdentityTupleFieldPath,
                                                    @"The certificate identity snapshot could not be created.");
                    return nil;
                }
                break;
            }

            case PXKeychainItemIdentityClassKey: {
                id applicationLabelValue = input[(__bridge id)kSecAttrApplicationLabel];
                if (!applicationLabelValue) {
                    if (PXKeychainItemIdentityHasKeyFallbackAttributes(input)) {
                        PXKeychainItemIdentitySetError(error,
                                                        PXKeychainItemIdentityErrorAmbiguousIdentity,
                                                        PXKeychainItemIdentityTupleFieldPath,
                                                        @"The key identity tuple is ambiguous.");
                    } else {
                        PXKeychainItemIdentitySetError(error,
                                                        PXKeychainItemIdentityErrorMissingIdentityAttribute,
                                                        PXKeychainItemIdentityApplicationLabelFieldPath,
                                                        @"A required identity attribute is missing.");
                    }
                    return nil;
                }

                NSData *applicationLabel = nil;
                NSString *keyClass = nil;
                NSString *keyType = nil;
                NSUInteger applicationLabelBytes = 0;
                NSUInteger keyClassBytes = 0;
                NSUInteger keyTypeBytes = 0;
                PXKeychainItemIdentityValueStatus status =
                    PXKeychainItemIdentityCopyData(applicationLabelValue,
                                                    PXKeychainItemIdentityMaximumApplicationLabelBytes,
                                                    &applicationLabel,
                                                    &applicationLabelBytes);
                if (status != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(status,
                                                             PXKeychainItemIdentityApplicationLabelFieldPath,
                                                             error);
                    return nil;
                }
                status = PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrKeyClass],
                                                           NO,
                                                           PXKeychainItemIdentityMaximumConstantStringBytes,
                                                           &keyClass,
                                                           &keyClassBytes);
                if (status != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(status,
                                                             PXKeychainItemIdentityKeyClassFieldPath,
                                                             error);
                    return nil;
                }
                status = PXKeychainItemIdentityCopyString(input[(__bridge id)kSecAttrKeyType],
                                                           NO,
                                                           PXKeychainItemIdentityMaximumConstantStringBytes,
                                                           &keyType,
                                                           &keyTypeBytes);
                if (status != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(status,
                                                             PXKeychainItemIdentityKeyTypeFieldPath,
                                                             error);
                    return nil;
                }
                if (!PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrApplicationLabel, applicationLabel, applicationLabelBytes, &aggregateByteCount) ||
                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrKeyClass, keyClass, keyClassBytes, &aggregateByteCount) ||
                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrKeyType, keyType, keyTypeBytes, &aggregateByteCount)) {
                    PXKeychainItemIdentitySetError(error,
                                                    PXKeychainItemIdentityErrorSnapshotFailed,
                                                    PXKeychainItemIdentityTupleFieldPath,
                                                    @"The key identity snapshot could not be created.");
                    return nil;
                }
                break;
            }

            case PXKeychainItemIdentityClassIdentity: {
                id applicationLabelValue = input[(__bridge id)kSecAttrApplicationLabel];
                id issuerValue = input[(__bridge id)kSecAttrIssuer];
                id serialNumberValue = input[(__bridge id)kSecAttrSerialNumber];
                if (!applicationLabelValue || !issuerValue || !serialNumberValue) {
                    if (applicationLabelValue || issuerValue || serialNumberValue ||
                        PXKeychainItemIdentityHasIdentityFallbackAttributes(input)) {
                        PXKeychainItemIdentitySetError(error,
                                                        PXKeychainItemIdentityErrorAmbiguousIdentity,
                                                        PXKeychainItemIdentityTupleFieldPath,
                                                        @"The identity tuple is ambiguous.");
                    } else {
                        NSString *missingFieldPath = !applicationLabelValue
                            ? PXKeychainItemIdentityApplicationLabelFieldPath
                            : (!issuerValue
                                ? PXKeychainItemIdentityIssuerFieldPath
                                : PXKeychainItemIdentitySerialNumberFieldPath);
                        PXKeychainItemIdentitySetError(error,
                                                        PXKeychainItemIdentityErrorMissingIdentityAttribute,
                                                        missingFieldPath,
                                                        @"A required identity attribute is missing.");
                    }
                    return nil;
                }

                NSData *applicationLabel = nil;
                NSData *issuer = nil;
                NSData *serialNumber = nil;
                NSUInteger applicationLabelBytes = 0;
                NSUInteger issuerBytes = 0;
                NSUInteger serialNumberBytes = 0;
                PXKeychainItemIdentityValueStatus status =
                    PXKeychainItemIdentityCopyData(applicationLabelValue,
                                                    PXKeychainItemIdentityMaximumApplicationLabelBytes,
                                                    &applicationLabel,
                                                    &applicationLabelBytes);
                if (status != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(status,
                                                             PXKeychainItemIdentityApplicationLabelFieldPath,
                                                             error);
                    return nil;
                }
                status = PXKeychainItemIdentityCopyData(issuerValue,
                                                         PXKeychainItemIdentityMaximumIssuerBytes,
                                                         &issuer,
                                                         &issuerBytes);
                if (status != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(status,
                                                             PXKeychainItemIdentityIssuerFieldPath,
                                                             error);
                    return nil;
                }
                status = PXKeychainItemIdentityCopyData(serialNumberValue,
                                                         PXKeychainItemIdentityMaximumSerialNumberBytes,
                                                         &serialNumber,
                                                         &serialNumberBytes);
                if (status != PXKeychainItemIdentityValueStatusSuccess) {
                    PXKeychainItemIdentitySetAttributeError(status,
                                                             PXKeychainItemIdentitySerialNumberFieldPath,
                                                             error);
                    return nil;
                }
                if (!PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrApplicationLabel, applicationLabel, applicationLabelBytes, &aggregateByteCount) ||
                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrIssuer, issuer, issuerBytes, &aggregateByteCount) ||
                    !PXKeychainItemIdentityAppendAttribute(names, identityAttributes, kSecAttrSerialNumber, serialNumber, serialNumberBytes, &aggregateByteCount)) {
                    PXKeychainItemIdentitySetError(error,
                                                    PXKeychainItemIdentityErrorSnapshotFailed,
                                                    PXKeychainItemIdentityTupleFieldPath,
                                                    @"The identity snapshot could not be created.");
                    return nil;
                }
                break;
            }

            case PXKeychainItemIdentityClassUnknown:
                PXKeychainItemIdentitySetError(error,
                                                PXKeychainItemIdentityErrorInternalInvariantFailed,
                                                PXKeychainItemIdentityClassFieldPath,
                                                @"The resolved identity class is invalid.");
                return nil;
        }

        if (names.count > PXKeychainItemIdentityMaximumAttributeCount ||
            identityAttributes.count != names.count ||
            expectedQueryCount != names.count + 1 ||
            expectedQueryCount > PXKeychainItemIdentityMaximumQueryKeyCount) {
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorInternalInvariantFailed,
                                            PXKeychainItemIdentityTupleFieldPath,
                                            @"The identity tuple has an invalid canonical shape.");
            return nil;
        }

        NSString *classKey = [(__bridge NSString *)kSecClass copy];
        NSString *classValue = [(__bridge NSString *)securityClass copy];
        NSUInteger classKeyBytes = PXKeychainItemIdentityStringByteCount(classKey);
        NSUInteger classValueBytes = PXKeychainItemIdentityStringByteCount(classValue);
        if (!classKey || !classValue ||
            classKeyBytes == NSUIntegerMax || classValueBytes == NSUIntegerMax ||
            !PXKeychainItemIdentitySafeAdd(&aggregateByteCount, classKeyBytes) ||
            !PXKeychainItemIdentitySafeAdd(&aggregateByteCount, classValueBytes) ||
            aggregateByteCount > PXKeychainItemIdentityMaximumAggregateBytes) {
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorLimitExceeded,
                                            PXKeychainItemIdentityTupleFieldPath,
                                            @"The retained identity exceeds the aggregate byte limit.");
            return nil;
        }

        NSMutableDictionary<NSString *, id> *query =
            [NSMutableDictionary dictionaryWithCapacity:expectedQueryCount];
        query[classKey] = classValue;
        for (NSString *name in names) {
            id value = identityAttributes[name];
            if (!value) {
                PXKeychainItemIdentitySetError(error,
                                                PXKeychainItemIdentityErrorSnapshotFailed,
                                                PXKeychainItemIdentityTupleFieldPath,
                                                @"The match-query snapshot could not be completed.");
                return nil;
            }
            query[name] = value;
        }

        NSArray<NSString *> *immutableNames = [NSArray arrayWithArray:names];
        NSDictionary<NSString *, id> *immutableIdentityAttributes =
            [NSDictionary dictionaryWithDictionary:identityAttributes];
        NSDictionary<NSString *, id> *immutableQuery =
            [NSDictionary dictionaryWithDictionary:query];
        if (!immutableNames || !immutableIdentityAttributes || !immutableQuery) {
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorSnapshotFailed,
                                            PXKeychainItemIdentityTupleFieldPath,
                                            @"The immutable identity snapshot could not be created.");
            return nil;
        }

        if (!PXKeychainItemIdentitySnapshotMatchesState(itemClass,
                                                         classNameSnapshot,
                                                         accessGroup,
                                                         synchronizable,
                                                         immutableNames,
                                                         immutableIdentityAttributes,
                                                         immutableQuery,
                                                         securityClass,
                                                         expectedQueryCount)) {
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorInternalInvariantFailed,
                                            PXKeychainItemIdentityTupleFieldPath,
                                            @"The immutable identity snapshot failed validation.");
            return nil;
        }

        PXKeychainItemIdentity *identity =
            [[PXKeychainItemIdentity alloc] initWithItemClass:itemClass
                                                       className:classNameSnapshot
                                                     accessGroup:accessGroup
                                                  synchronizable:synchronizable
                                          identityAttributeNames:immutableNames
                                              identityAttributes:immutableIdentityAttributes
                                                      matchQuery:immutableQuery];
        if (!identity) {
            PXKeychainItemIdentitySetError(error,
                                            PXKeychainItemIdentityErrorSnapshotFailed,
                                            PXKeychainItemIdentityTupleFieldPath,
                                            @"The immutable identity object could not be created.");
            return nil;
        }
        return identity;
    } @catch (__unused NSException *exception) {
        PXKeychainItemIdentitySetError(error,
                                        PXKeychainItemIdentityErrorInternalInvariantFailed,
                                        PXKeychainItemIdentityRootFieldPath,
                                        @"The identity input could not be processed safely.");
        return nil;
    }
}

- (instancetype)initWithItemClass:(PXKeychainItemIdentityClass)itemClass
                           className:(NSString *)className
                         accessGroup:(NSString *)accessGroup
                      synchronizable:(BOOL)synchronizable
              identityAttributeNames:(NSArray<NSString *> *)identityAttributeNames
                  identityAttributes:(NSDictionary<NSString *, id> *)identityAttributes
                          matchQuery:(NSDictionary<NSString *, id> *)matchQuery {
    self = [super init];
    if (self) {
        _schemaVersion = PXKeychainItemIdentitySchemaVersion;
        _itemClass = itemClass;
        _className = [[NSString alloc] initWithString:className];
        _accessGroup = [[NSString alloc] initWithString:accessGroup];
        _synchronizable = synchronizable;
        _identityAttributeNames = [NSArray arrayWithArray:identityAttributeNames];
        _identityAttributes = [NSDictionary dictionaryWithDictionary:identityAttributes];
        _matchQuery = [NSDictionary dictionaryWithDictionary:matchQuery];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isMemberOfClass:[PXKeychainItemIdentity class]]) {
        return NO;
    }
    PXKeychainItemIdentity *other = object;
    return self.schemaVersion == other.schemaVersion &&
           self.itemClass == other.itemClass &&
           self.synchronizable == other.synchronizable &&
           [self.accessGroup isEqualToString:other.accessGroup] &&
           [self.identityAttributes isEqualToDictionary:other.identityAttributes] &&
           [self.matchQuery isEqualToDictionary:other.matchQuery];
}

- (NSUInteger)hash {
    NSUInteger value = (NSUInteger)self.schemaVersion;
    value ^= (NSUInteger)self.itemClass;
    value ^= (NSUInteger)self.synchronizable;
    value ^= self.accessGroup.hash;
    value ^= self.identityAttributes.hash;
    value ^= self.matchQuery.hash;
    return value;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<PXKeychainItemIdentity class=%@ synchronizable=%@ attributes=%lu>",
            self.className,
            self.isSynchronizable ? @"true" : @"false",
            (unsigned long)self.identityAttributeNames.count];
}

- (NSString *)debugDescription {
    return self.description;
}

@end
