#import "PXBackupArchiveValidator.h"
#import "PXBackupArtifactVerifier.h"
#import <CommonCrypto/CommonDigest.h>

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <zlib.h>

NSString * const PXBackupArchiveValidatorErrorDomain =
    @"PXBackupArchiveValidatorErrorDomain";
NSString * const PXBackupArchiveValidatorErrorFieldPathKey =
    @"PXBackupArchiveValidatorErrorFieldPathKey";

static const uint64_t PXArchiveMaximumReferences = UINT64_C(10000);
static const uint64_t PXArchiveMaximumPhysicalHeaders = UINT64_C(400000);
static const uint64_t PXArchiveMaximumLogicalMembers = UINT64_C(200000);
static const uint64_t PXArchiveMaximumRestoreLogicalMembers = UINT64_C(500000);
static const uint64_t PXArchiveMaximumPathBytes = UINT64_C(4096);
static const uint64_t PXArchiveMaximumComponentBytes = UINT64_C(255);
static const uint64_t PXArchiveMaximumMetadataPayload = UINT64_C(1) << 20;
static const uint64_t PXArchiveMaximumMetadataTotal = UINT64_C(16) << 20;
static const uint64_t PXArchiveMaximumRegularFileBytes = UINT64_C(64) << 30;
static const uint64_t PXArchiveMinimumInflatedBudget = UINT64_C(1) << 30;
static const uint64_t PXArchiveInflationMultiplier = UINT64_C(4096);
static const uint64_t PXArchiveMaximumInflatedBudget = UINT64_C(128) << 30;
static const uint64_t PXArchiveMaximumRestoreInflatedBytes = UINT64_C(256) << 30;
static const size_t PXTarBlockSize = 512;

typedef NS_ENUM(NSUInteger, PXArchiveTarHeaderFormat) {
    PXArchiveTarHeaderFormatLegacy = 0,
    PXArchiveTarHeaderFormatPOSIXUstar = 1,
    PXArchiveTarHeaderFormatGNU = 2,
};

@interface PXValidatedBackupArchiveSet ()
@property (nonatomic, copy, readwrite) NSArray<NSString *> *archiveNames;
@property (nonatomic, copy, readwrite)
    NSDictionary<NSString *, NSNumber *> *memberCountsByArchiveName;
@property (nonatomic, copy, readwrite)
    NSDictionary<NSString *, NSNumber *> *regularFileBytesByArchiveName;
- (instancetype)initWithMemberCounts:(NSDictionary<NSString *, NSNumber *> *)memberCounts
                    regularFileBytes:(NSDictionary<NSString *, NSNumber *> *)regularFileBytes;
@end

@implementation PXValidatedBackupArchiveSet

- (instancetype)initWithMemberCounts:(NSDictionary<NSString *, NSNumber *> *)memberCounts
                    regularFileBytes:(NSDictionary<NSString *, NSNumber *> *)regularFileBytes {
    self = [super init];
    if (self) {
        _memberCountsByArchiveName = [memberCounts copy];
        _regularFileBytesByArchiveName = [regularFileBytes copy];
        _archiveNames = [[_memberCountsByArchiveName allKeys]
            sortedArrayUsingSelector:@selector(compare:)];
    }
    return self;
}

- (BOOL)containsArchiveName:(NSString *)archiveName {
    if (![archiveName isKindOfClass:[NSString class]] || archiveName.length == 0) {
        return NO;
    }
    return self.memberCountsByArchiveName[archiveName] != nil;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end

@interface PXArchiveDeclaration : NSObject
@property (nonatomic, assign) NSUInteger originalIndex;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) uint64_t expectedCompressedSize;
@property (nonatomic, copy) NSString *expectedDigest;
@end

@implementation PXArchiveDeclaration
@end

@interface PXArchiveReference : NSObject
@property (nonatomic, copy) NSString *fieldPath;
@property (nonatomic, strong) PXArchiveDeclaration *declaration;
@property (nonatomic, copy) NSString *verifiedPath;
@end

@implementation PXArchiveReference
@end

static BOOL PXArchiveFail(NSError **error,
                          PXBackupArchiveValidatorErrorCode code,
                          NSString *fieldPath,
                          NSString *description) {
    if (error) {
        *error = [NSError errorWithDomain:PXBackupArchiveValidatorErrorDomain
                                     code:code
                                 userInfo:@{
                                     NSLocalizedDescriptionKey: description,
                                     PXBackupArchiveValidatorErrorFieldPathKey: fieldPath
                                 }];
    }
    return NO;
}

static NSString *PXArchiveIndexedPath(NSString *basePath, NSUInteger index) {
    return [NSString stringWithFormat:@"%@[%lu]", basePath, (unsigned long)index];
}

static NSString *PXArchiveFieldPath(NSString *basePath, NSString *field) {
    return [NSString stringWithFormat:@"%@.%@", basePath, field];
}

static BOOL PXArchiveStringContainsNUL(NSString *value) {
    unichar nul = 0;
    NSString *nulString = [NSString stringWithCharacters:&nul length:1];
    return [value rangeOfString:nulString].location != NSNotFound;
}

static BOOL PXArchiveStringContainsNonWhitespace(NSString *value) {
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [value rangeOfCharacterFromSet:[whitespace invertedSet]].location != NSNotFound;
}

static BOOL PXArchiveStringInputIsValid(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }
    NSString *string = (NSString *)value;
    return string.length > 0 &&
           PXArchiveStringContainsNonWhitespace(string) &&
           !PXArchiveStringContainsNUL(string);
}

static BOOL PXArchiveExactBoolean(id value, BOOL *result) {
    if (![value isKindOfClass:[NSNumber class]] ||
        CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) {
        return NO;
    }
    if (result) {
        *result = [(NSNumber *)value boolValue];
    }
    return YES;
}

static BOOL PXArchiveNonnegativeIntegralNumber(id value, uint64_t *result) {
    if (![value isKindOfClass:[NSNumber class]] ||
        CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) {
        return NO;
    }
    NSNumber *number = (NSNumber *)value;
    const char *type = number.objCType;
    if (!type || type[0] == '\0' || type[1] != '\0') {
        return NO;
    }
    switch (type[0]) {
        case 'c':
        case 's':
        case 'i':
        case 'l':
        case 'q': {
            long long signedValue = number.longLongValue;
            if (signedValue < 0) {
                return NO;
            }
            if (result) {
                *result = (uint64_t)signedValue;
            }
            return YES;
        }
        case 'C':
        case 'S':
        case 'I':
        case 'L':
        case 'Q':
            if (result) {
                *result = number.unsignedLongLongValue;
            }
            return YES;
        default:
            return NO;
    }
}

static BOOL PXArchiveDigestIsValid(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }
    NSString *digest = (NSString *)value;
    if (digest.length != CC_SHA256_DIGEST_LENGTH * 2) {
        return NO;
    }
    for (NSUInteger index = 0; index < digest.length; index++) {
        unichar character = [digest characterAtIndex:index];
        BOOL digit = character >= (unichar)'0' && character <= (unichar)'9';
        BOOL lowerHex = character >= (unichar)'a' && character <= (unichar)'f';
        if (!digit && !lowerHex) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXArchiveArtifactNameIsSafe(id value) {
    if (!PXArchiveStringInputIsValid(value)) {
        return NO;
    }
    NSString *name = (NSString *)value;
    if ([name hasPrefix:@"/"] || [name hasSuffix:@"/"] ||
        [name rangeOfString:@"//"].location != NSNotFound) {
        return NO;
    }
    NSArray<NSString *> *components = [name componentsSeparatedByString:@"/"];
    if (components.count == 0) {
        return NO;
    }
    for (NSString *component in components) {
        if (component.length == 0 ||
            [component isEqualToString:@"."] ||
            [component isEqualToString:@".."]) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXArchiveAddUInt64(uint64_t left, uint64_t right, uint64_t *result) {
    if (UINT64_MAX - left < right) {
        return NO;
    }
    if (result) {
        *result = left + right;
    }
    return YES;
}

static BOOL PXArchiveMultiplyUInt64(uint64_t left, uint64_t right, uint64_t *result) {
    if (left != 0 && right > UINT64_MAX / left) {
        return NO;
    }
    if (result) {
        *result = left * right;
    }
    return YES;
}

static uint64_t PXArchiveInflatedBudget(uint64_t compressedSize) {
    uint64_t multiplied = 0;
    if (!PXArchiveMultiplyUInt64(compressedSize,
                                 PXArchiveInflationMultiplier,
                                 &multiplied)) {
        multiplied = PXArchiveMaximumInflatedBudget;
    }
    if (multiplied < PXArchiveMinimumInflatedBudget) {
        multiplied = PXArchiveMinimumInflatedBudget;
    }
    if (multiplied > PXArchiveMaximumInflatedBudget) {
        multiplied = PXArchiveMaximumInflatedBudget;
    }
    return multiplied;
}

static NSString *PXArchiveHexDigest(const unsigned char digest[CC_SHA256_DIGEST_LENGTH]) {
    static const char hex[] = "0123456789abcdef";
    char output[CC_SHA256_DIGEST_LENGTH * 2 + 1];
    for (size_t index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        output[index * 2] = hex[(digest[index] >> 4) & 0x0f];
        output[index * 2 + 1] = hex[digest[index] & 0x0f];
    }
    output[CC_SHA256_DIGEST_LENGTH * 2] = '\0';
    return [[NSString alloc] initWithBytes:output
                                    length:CC_SHA256_DIGEST_LENGTH * 2
                                  encoding:NSASCIIStringEncoding];
}

static BOOL PXArchiveStatIdentityEqual(const struct stat *before,
                                       const struct stat *after) {
    return before->st_dev == after->st_dev &&
           before->st_ino == after->st_ino &&
           S_ISREG(before->st_mode) &&
           S_ISREG(after->st_mode) &&
           before->st_size == after->st_size &&
           before->st_mtimespec.tv_sec == after->st_mtimespec.tv_sec &&
           before->st_mtimespec.tv_nsec == after->st_mtimespec.tv_nsec &&
           before->st_ctimespec.tv_sec == after->st_ctimespec.tv_sec &&
           before->st_ctimespec.tv_nsec == after->st_ctimespec.tv_nsec;
}

static BOOL PXArchiveOpenCanonicalBackupRoot(NSString *backupDirectory,
                                             NSString **canonicalRootOut,
                                             int *rootDescriptorOut,
                                             NSError **error) {
    if (canonicalRootOut) {
        *canonicalRootOut = nil;
    }
    if (rootDescriptorOut) {
        *rootDescriptorOut = -1;
    }

    NSString *inspectionPath = backupDirectory;
    while (inspectionPath.length > 1 &&
           [inspectionPath characterAtIndex:inspectionPath.length - 1] == (unichar)'/') {
        inspectionPath = [inspectionPath substringToIndex:inspectionPath.length - 1];
    }
    const char *rawPath = inspectionPath.fileSystemRepresentation;
    if (!rawPath) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInvalidInput,
                             @"$",
                             @"The backup directory input is invalid.");
    }

    struct stat rawStatus;
    if (lstat(rawPath, &rawStatus) != 0) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorOpenFailed,
                             @"$",
                             @"The backup directory could not be inspected.");
    }
    if (S_ISLNK(rawStatus.st_mode) || !S_ISDIR(rawStatus.st_mode)) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorOpenFailed,
                             @"$",
                             @"The backup directory is not a safe directory.");
    }

    int rawDescriptor = open(rawPath,
                             O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (rawDescriptor < 0) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorOpenFailed,
                             @"$",
                             @"The backup directory could not be opened safely.");
    }

    struct stat openedRawStatus;
    if (fstat(rawDescriptor, &openedRawStatus) != 0 ||
        !S_ISDIR(openedRawStatus.st_mode)) {
        close(rawDescriptor);
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorOpenFailed,
                             @"$",
                             @"The backup directory descriptor is invalid.");
    }
    if (rawStatus.st_dev != openedRawStatus.st_dev ||
        rawStatus.st_ino != openedRawStatus.st_ino) {
        close(rawDescriptor);
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorFilesystemChanged,
                             @"$",
                             @"The backup directory changed while being opened.");
    }

    char canonicalBuffer[PATH_MAX];
    if (realpath(rawPath, canonicalBuffer) == NULL) {
        close(rawDescriptor);
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorOpenFailed,
                             @"$",
                             @"The backup directory could not be canonicalized.");
    }
    NSString *canonicalRoot = [[NSString alloc]
        initWithBytes:canonicalBuffer
               length:strlen(canonicalBuffer)
             encoding:NSUTF8StringEncoding];
    if (canonicalRoot.length == 0) {
        close(rawDescriptor);
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorOpenFailed,
                             @"$",
                             @"The canonical backup directory is invalid.");
    }

    int canonicalDescriptor = open(canonicalBuffer,
                                   O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (canonicalDescriptor < 0) {
        close(rawDescriptor);
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorOpenFailed,
                             @"$",
                             @"The canonical backup directory could not be opened.");
    }
    struct stat canonicalStatus;
    if (fstat(canonicalDescriptor, &canonicalStatus) != 0 ||
        !S_ISDIR(canonicalStatus.st_mode)) {
        close(canonicalDescriptor);
        close(rawDescriptor);
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorOpenFailed,
                             @"$",
                             @"The canonical backup directory descriptor is invalid.");
    }
    if (openedRawStatus.st_dev != canonicalStatus.st_dev ||
        openedRawStatus.st_ino != canonicalStatus.st_ino) {
        close(canonicalDescriptor);
        close(rawDescriptor);
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorFilesystemChanged,
                             @"$",
                             @"The backup directory identity changed during canonicalization.");
    }
    close(rawDescriptor);

    if (canonicalRootOut) {
        *canonicalRootOut = canonicalRoot;
    }
    if (rootDescriptorOut) {
        *rootDescriptorOut = canonicalDescriptor;
    } else {
        close(canonicalDescriptor);
    }
    return YES;
}

static BOOL PXArchiveOpenRelativeFile(int rootDescriptor,
                                      NSString *archiveName,
                                      NSString *fieldPath,
                                      int *fileDescriptorOut,
                                      struct stat *statusOut,
                                      NSError **error) {
    if (fileDescriptorOut) {
        *fileDescriptorOut = -1;
    }
    NSArray<NSString *> *components = [archiveName componentsSeparatedByString:@"/"];
    if (components.count == 0) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInvalidInput,
                             fieldPath,
                             @"The archive reference is invalid.");
    }

    int currentDescriptor = dup(rootDescriptor);
    if (currentDescriptor < 0) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorOpenFailed,
                             fieldPath,
                             @"The archive root descriptor could not be duplicated.");
    }
    int descriptorFlags = fcntl(currentDescriptor, F_GETFD);
    if (descriptorFlags < 0 ||
        fcntl(currentDescriptor,
              F_SETFD,
              descriptorFlags | FD_CLOEXEC) < 0) {
        close(currentDescriptor);
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorOpenFailed,
                             fieldPath,
                             @"The archive root descriptor could not be secured.");
    }
    int verifiedFlags = fcntl(currentDescriptor, F_GETFD);
    if (verifiedFlags < 0 || (verifiedFlags & FD_CLOEXEC) == 0) {
        close(currentDescriptor);
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorOpenFailed,
                             fieldPath,
                             @"The archive root descriptor close-on-exec state is invalid.");
    }

    for (NSUInteger index = 0; index + 1 < components.count; index++) {
        const char *component = [components[index] fileSystemRepresentation];
        if (!component) {
            close(currentDescriptor);
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorOpenFailed,
                                 fieldPath,
                                 @"An archive parent component is invalid.");
        }
        int nextDescriptor = openat(currentDescriptor,
                                    component,
                                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        close(currentDescriptor);
        if (nextDescriptor < 0) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorOpenFailed,
                                 fieldPath,
                                 @"An archive parent component could not be opened safely.");
        }
        currentDescriptor = nextDescriptor;
    }

    const char *finalComponent = [components.lastObject fileSystemRepresentation];
    if (!finalComponent) {
        close(currentDescriptor);
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorOpenFailed,
                             fieldPath,
                             @"The archive filename is invalid.");
    }
    int fileDescriptor = openat(currentDescriptor,
                                finalComponent,
                                O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
    close(currentDescriptor);
    if (fileDescriptor < 0) {
        PXBackupArchiveValidatorErrorCode code =
            errno == ENOENT
                ? PXBackupArchiveValidatorErrorMissingArchive
                : PXBackupArchiveValidatorErrorOpenFailed;
        return PXArchiveFail(error,
                             code,
                             fieldPath,
                             @"The archive could not be opened safely.");
    }

    struct stat status;
    if (fstat(fileDescriptor, &status) != 0 || !S_ISREG(status.st_mode)) {
        close(fileDescriptor);
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorOpenFailed,
                             fieldPath,
                             @"The archive is not a regular file.");
    }

    if (fileDescriptorOut) {
        *fileDescriptorOut = fileDescriptor;
    } else {
        close(fileDescriptor);
    }
    if (statusOut) {
        *statusOut = status;
    }
    return YES;
}

static NSData *PXArchiveBytesUntilNUL(const unsigned char *bytes, size_t length) {
    size_t used = 0;
    while (used < length && bytes[used] != 0) {
        used++;
    }
    return [NSData dataWithBytes:bytes length:used];
}

static BOOL PXArchiveBlockIsZero(const unsigned char *block) {
    for (size_t index = 0; index < PXTarBlockSize; index++) {
        if (block[index] != 0) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXArchiveParseOctal(const unsigned char *bytes,
                                size_t length,
                                uint64_t *result) {
    size_t index = 0;
    while (index < length && bytes[index] == ' ') {
        index++;
    }
    BOOL sawDigit = NO;
    uint64_t value = 0;
    for (; index < length; index++) {
        unsigned char byte = bytes[index];
        if (byte >= '0' && byte <= '7') {
            sawDigit = YES;
            if (value > (UINT64_MAX - (uint64_t)(byte - '0')) / 8) {
                return NO;
            }
            value = value * 8 + (uint64_t)(byte - '0');
            continue;
        }
        if (byte == 0 || byte == ' ') {
            for (size_t tail = index; tail < length; tail++) {
                if (bytes[tail] != 0 && bytes[tail] != ' ') {
                    return NO;
                }
            }
            break;
        }
        return NO;
    }
    if (!sawDigit) {
        return NO;
    }
    if (result) {
        *result = value;
    }
    return YES;
}

static BOOL PXArchiveParseSizeField(const unsigned char *bytes,
                                    size_t length,
                                    uint64_t *result) {
    if (length == 0) {
        return NO;
    }
    if ((bytes[0] & 0x80) == 0) {
        return PXArchiveParseOctal(bytes, length, result);
    }
    if ((bytes[0] & 0x40) != 0) {
        return NO;
    }
    uint64_t value = (uint64_t)(bytes[0] & 0x3f);
    for (size_t index = 1; index < length; index++) {
        if (value > (UINT64_MAX - bytes[index]) / 256) {
            return NO;
        }
        value = value * 256 + bytes[index];
    }
    if (result) {
        *result = value;
    }
    return YES;
}

static BOOL PXArchiveHeaderChecksumIsValid(const unsigned char *block) {
    uint64_t stored = 0;
    if (!PXArchiveParseOctal(block + 148, 8, &stored)) {
        return NO;
    }
    uint64_t unsignedSum = 0;
    int64_t signedSum = 0;
    for (size_t index = 0; index < PXTarBlockSize; index++) {
        unsigned char value = (index >= 148 && index < 156) ? (unsigned char)' ' : block[index];
        unsignedSum += value;
        signedSum += (int8_t)value;
    }
    return stored == unsignedSum ||
           (signedSum >= 0 && stored == (uint64_t)signedSum);
}

static BOOL PXArchiveClassifyHeaderFormat(const unsigned char *block,
                                          PXArchiveTarHeaderFormat *formatOut) {
    const unsigned char *magic = block + 257;
    const unsigned char *version = block + 263;
    BOOL legacy = YES;
    for (size_t index = 0; index < 6; index++) {
        if (magic[index] != 0) {
            legacy = NO;
            break;
        }
    }
    if (legacy) {
        if (formatOut) {
            *formatOut = PXArchiveTarHeaderFormatLegacy;
        }
        return YES;
    }
    if (memcmp(magic, "ustar\0", 6) == 0 &&
        version[0] == '0' && version[1] == '0') {
        if (formatOut) {
            *formatOut = PXArchiveTarHeaderFormatPOSIXUstar;
        }
        return YES;
    }
    if (memcmp(magic, "ustar ", 6) == 0 &&
        version[0] == ' ' && version[1] == 0) {
        if (formatOut) {
            *formatOut = PXArchiveTarHeaderFormatGNU;
        }
        return YES;
    }
    return NO;
}

static BOOL PXArchiveDecimalUInt64(const unsigned char *bytes,
                                   size_t length,
                                   uint64_t *result) {
    if (length == 0) {
        return NO;
    }
    uint64_t value = 0;
    for (size_t index = 0; index < length; index++) {
        unsigned char byte = bytes[index];
        if (byte < '0' || byte > '9') {
            return NO;
        }
        if (value > (UINT64_MAX - (uint64_t)(byte - '0')) / 10) {
            return NO;
        }
        value = value * 10 + (uint64_t)(byte - '0');
    }
    if (result) {
        *result = value;
    }
    return YES;
}

static NSString *PXArchiveStringFromUTF8Data(NSData *data) {
    if (![data isKindOfClass:[NSData class]]) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static NSString *PXArchiveNormalizeMemberPath(NSString *input,
                                              BOOL directory,
                                              BOOL *rootMarker,
                                              NSError **error,
                                              NSString *fieldPath) {
    if (rootMarker) {
        *rootMarker = NO;
    }
    if (![input isKindOfClass:[NSString class]] || input.length == 0 ||
        PXArchiveStringContainsNUL(input)) {
        PXArchiveFail(error,
                      PXBackupArchiveValidatorErrorUnsafeEntryPath,
                      fieldPath,
                      @"An archive member path is invalid.");
        return nil;
    }

    NSData *originalBytes = [input dataUsingEncoding:NSUTF8StringEncoding
                                allowLossyConversion:NO];
    if (!originalBytes) {
        PXArchiveFail(error,
                      PXBackupArchiveValidatorErrorUnsafeEntryPath,
                      fieldPath,
                      @"An archive member path is not valid UTF-8.");
        return nil;
    }
    const unsigned char *raw = originalBytes.bytes;
    for (NSUInteger index = 0; index < originalBytes.length; index++) {
        unsigned char byte = raw[index];
        if (byte == 0 || (byte >= 1 && byte <= 31) || byte == 127) {
            PXArchiveFail(error,
                          PXBackupArchiveValidatorErrorUnsafeEntryPath,
                          fieldPath,
                          @"An archive member path contains a control character.");
            return nil;
        }
    }

    NSString *path = input;
    if ([path hasPrefix:@"/"] || [path rangeOfString:@"\\"].location != NSNotFound ||
        [path rangeOfString:@"//"].location != NSNotFound) {
        PXArchiveFail(error,
                      PXBackupArchiveValidatorErrorUnsafeEntryPath,
                      fieldPath,
                      @"An archive member path is unsafe.");
        return nil;
    }

    while ([path hasPrefix:@"./"]) {
        path = [path substringFromIndex:2];
    }
    if ([path isEqualToString:@"."] || path.length == 0) {
        if (!directory) {
            PXArchiveFail(error,
                          PXBackupArchiveValidatorErrorUnsafeEntryPath,
                          fieldPath,
                          @"The archive root marker must be a directory.");
            return nil;
        }
        if (rootMarker) {
            *rootMarker = YES;
        }
        return @".";
    }

    if ([path hasSuffix:@"/"]) {
        if (!directory) {
            PXArchiveFail(error,
                          PXBackupArchiveValidatorErrorUnsafeEntryPath,
                          fieldPath,
                          @"A regular archive member must not end with a slash.");
            return nil;
        }
        path = [path substringToIndex:path.length - 1];
    }
    if (path.length == 0 || [path hasPrefix:@"/"] ||
        [path rangeOfString:@"//"].location != NSNotFound) {
        PXArchiveFail(error,
                      PXBackupArchiveValidatorErrorUnsafeEntryPath,
                      fieldPath,
                      @"An archive member path is unsafe.");
        return nil;
    }

    NSArray<NSString *> *components = [path componentsSeparatedByString:@"/"];
    for (NSString *component in components) {
        if (component.length == 0 ||
            [component isEqualToString:@"."] ||
            [component isEqualToString:@".."]) {
            PXArchiveFail(error,
                          PXBackupArchiveValidatorErrorUnsafeEntryPath,
                          fieldPath,
                          @"An archive member path contains an unsafe component.");
            return nil;
        }
        NSData *componentBytes = [component dataUsingEncoding:NSUTF8StringEncoding
                                         allowLossyConversion:NO];
        if (!componentBytes || componentBytes.length > PXArchiveMaximumComponentBytes) {
            PXArchiveFail(error,
                          PXBackupArchiveValidatorErrorLimitExceeded,
                          fieldPath,
                          @"An archive member path component exceeds the fixed limit.");
            return nil;
        }
    }
    NSData *normalizedBytes = [path dataUsingEncoding:NSUTF8StringEncoding
                                allowLossyConversion:NO];
    if (!normalizedBytes || normalizedBytes.length > PXArchiveMaximumPathBytes) {
        PXArchiveFail(error,
                      PXBackupArchiveValidatorErrorLimitExceeded,
                      fieldPath,
                      @"An archive member path exceeds the fixed limit.");
        return nil;
    }
    return path;
}

@interface PXArchiveTarParser : NSObject {
    NSUInteger _artifactIndex;
    uint64_t _archiveBudget;
    uint64_t *_restoreLogicalMembers;
    unsigned char _headerBlock[512];
    size_t _headerUsed;
    uint64_t _physicalHeaders;
    uint64_t _logicalMembers;
    uint64_t _regularFileBytes;
    uint64_t _metadataTotal;
    uint64_t _payloadRemaining;
    uint64_t _paddingRemaining;
    char _metadataType;
    uint64_t _currentHeaderIndex;
    NSMutableData *_metadataPayload;
    BOOL _metadataNeedsFinalize;
    NSUInteger _zeroBlockCount;
    BOOL _afterEnd;
    NSMutableDictionary<NSString *, NSString *> *_realTypesByPath;
    NSMutableSet<NSString *> *_implicitDirectories;
    NSMutableSet<NSString *> *_regularPaths;
    NSString *_pendingPAXPath;
    NSNumber *_pendingPAXSize;
    NSString *_pendingPAXLinkPath;
    NSString *_pendingGNUPath;
    NSString *_pendingGNULinkPath;
    BOOL _hasPendingPerEntryMetadata;
}
@property (nonatomic, assign, readonly) uint64_t logicalMembers;
@property (nonatomic, assign, readonly) uint64_t regularFileBytes;
- (instancetype)initWithArtifactIndex:(NSUInteger)artifactIndex
                        archiveBudget:(uint64_t)archiveBudget
               restoreLogicalMembers:(uint64_t *)restoreLogicalMembers;
- (BOOL)consumeBytes:(const unsigned char *)bytes
              length:(size_t)length
               error:(NSError **)error;
- (BOOL)finishWithError:(NSError **)error;
@end

@implementation PXArchiveTarParser

- (instancetype)initWithArtifactIndex:(NSUInteger)artifactIndex
                        archiveBudget:(uint64_t)archiveBudget
               restoreLogicalMembers:(uint64_t *)restoreLogicalMembers {
    self = [super init];
    if (self) {
        _artifactIndex = artifactIndex;
        _archiveBudget = archiveBudget;
        _restoreLogicalMembers = restoreLogicalMembers;
        _realTypesByPath = [NSMutableDictionary dictionary];
        _implicitDirectories = [NSMutableSet set];
        _regularPaths = [NSMutableSet set];
    }
    return self;
}

- (uint64_t)logicalMembers {
    return _logicalMembers;
}

- (uint64_t)regularFileBytes {
    return _regularFileBytes;
}

- (NSString *)memberPathForIndex:(uint64_t)index field:(NSString *)field {
    NSString *base = [NSString stringWithFormat:@"$.artifacts[%lu].members[%llu]",
                      (unsigned long)_artifactIndex,
                      (unsigned long long)index];
    return field.length ? PXArchiveFieldPath(base, field) : base;
}

- (void)clearPendingMetadata {
    _pendingPAXPath = nil;
    _pendingPAXSize = nil;
    _pendingPAXLinkPath = nil;
    _pendingGNUPath = nil;
    _pendingGNULinkPath = nil;
    _hasPendingPerEntryMetadata = NO;
}

- (BOOL)parsePAXPayload:(NSData *)payload
                 global:(BOOL)global
                  error:(NSError **)error {
    const unsigned char *bytes = payload.bytes;
    size_t length = payload.length;
    size_t offset = 0;
    NSMutableDictionary<NSString *, id> *known = [NSMutableDictionary dictionary];
    NSString *fieldPath = [self memberPathForIndex:_currentHeaderIndex field:nil];

    while (offset < length) {
        size_t recordStart = offset;
        size_t spaceIndex = offset;
        while (spaceIndex < length && bytes[spaceIndex] != ' ') {
            if (bytes[spaceIndex] < '0' || bytes[spaceIndex] > '9') {
                return PXArchiveFail(error,
                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                     fieldPath,
                                     @"A PAX record length is invalid.");
            }
            spaceIndex++;
        }
        if (spaceIndex == recordStart || spaceIndex >= length) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                 fieldPath,
                                 @"A PAX record length is invalid.");
        }
        uint64_t recordLength = 0;
        if (!PXArchiveDecimalUInt64(bytes + recordStart,
                                    spaceIndex - recordStart,
                                    &recordLength) ||
            recordLength == 0 || recordLength > SIZE_MAX ||
            recordStart > length || recordLength > length - recordStart) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                 fieldPath,
                                 @"A PAX record length is invalid.");
        }
        size_t recordEnd = recordStart + (size_t)recordLength;
        if (recordEnd <= spaceIndex + 2 || bytes[recordEnd - 1] != '\n') {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                 fieldPath,
                                 @"A PAX record terminator is invalid.");
        }
        size_t equalsIndex = spaceIndex + 1;
        while (equalsIndex < recordEnd - 1 && bytes[equalsIndex] != '=') {
            equalsIndex++;
        }
        if (equalsIndex == spaceIndex + 1 || equalsIndex >= recordEnd - 1) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                 fieldPath,
                                 @"A PAX record key/value separator is invalid.");
        }
        for (size_t index = recordStart; index < recordEnd; index++) {
            if (bytes[index] == 0) {
                return PXArchiveFail(error,
                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                     fieldPath,
                                     @"A PAX record contains a NUL byte.");
            }
        }
        for (size_t index = spaceIndex + 1; index < equalsIndex; index++) {
            unsigned char byte = bytes[index];
            if (byte < 0x21 || byte > 0x7e || byte == '=') {
                return PXArchiveFail(error,
                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                     fieldPath,
                                     @"A PAX record key is invalid.");
            }
        }
        NSData *keyData = [NSData dataWithBytes:bytes + spaceIndex + 1
                                         length:equalsIndex - (spaceIndex + 1)];
        NSString *key = [[NSString alloc] initWithData:keyData
                                              encoding:NSASCIIStringEncoding];
        if (key.length == 0) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                 fieldPath,
                                 @"A PAX record key is invalid.");
        }
        if ([key hasPrefix:@"GNU.sparse"]) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorUnsupportedEntryType,
                                 fieldPath,
                                 @"Sparse archive metadata is not supported.");
        }
        BOOL reserved = [key isEqualToString:@"path"] ||
                        [key isEqualToString:@"size"] ||
                        [key isEqualToString:@"linkpath"];
        if (global && reserved) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                 fieldPath,
                                 @"Global PAX metadata may not override member identity.");
        }
        if (!global && reserved) {
            if (known[key] != nil) {
                return PXArchiveFail(error,
                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                     fieldPath,
                                     @"A PAX override is duplicated.");
            }
            NSData *valueData = [NSData dataWithBytes:bytes + equalsIndex + 1
                                               length:(recordEnd - 1) - (equalsIndex + 1)];
            if ([key isEqualToString:@"size"]) {
                uint64_t sizeValue = 0;
                if (!PXArchiveDecimalUInt64(valueData.bytes,
                                            valueData.length,
                                            &sizeValue)) {
                    return PXArchiveFail(error,
                                         PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                         fieldPath,
                                         @"A PAX size override is invalid.");
                }
                known[key] = @(sizeValue);
            } else {
                NSString *stringValue = PXArchiveStringFromUTF8Data(valueData);
                if (!stringValue || PXArchiveStringContainsNUL(stringValue)) {
                    return PXArchiveFail(error,
                                         PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                         fieldPath,
                                         @"A PAX string override is invalid UTF-8.");
                }
                known[key] = stringValue;
            }
        }
        offset = recordEnd;
    }
    if (offset != length) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                             fieldPath,
                             @"A PAX payload is malformed.");
    }

    if (!global) {
        NSString *pathValue = known[@"path"];
        NSNumber *sizeValue = known[@"size"];
        NSString *linkValue = known[@"linkpath"];
        if (pathValue) {
            if (_pendingPAXPath || _pendingGNUPath) {
                return PXArchiveFail(error,
                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                     fieldPath,
                                     @"Conflicting archive path overrides are pending.");
            }
            _pendingPAXPath = pathValue;
        }
        if (sizeValue) {
            if (_pendingPAXSize) {
                return PXArchiveFail(error,
                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                     fieldPath,
                                     @"A size override is already pending.");
            }
            _pendingPAXSize = sizeValue;
        }
        if (linkValue) {
            if (_pendingPAXLinkPath || _pendingGNULinkPath) {
                return PXArchiveFail(error,
                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                     fieldPath,
                                     @"A link override is already pending.");
            }
            _pendingPAXLinkPath = linkValue;
        }
        _hasPendingPerEntryMetadata = YES;
    }
    return YES;
}

- (BOOL)parseGNULongPayload:(NSData *)payload
                       type:(char)type
                      error:(NSError **)error {
    const unsigned char *bytes = payload.bytes;
    size_t length = payload.length;
    while (length > 0 && (bytes[length - 1] == 0 || bytes[length - 1] == '\n')) {
        length--;
    }
    if (length == 0) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                             [self memberPathForIndex:_currentHeaderIndex field:nil],
                             @"A GNU long-name payload is empty.");
    }
    for (size_t index = 0; index < length; index++) {
        if (bytes[index] == 0) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                 [self memberPathForIndex:_currentHeaderIndex field:nil],
                                 @"A GNU long-name payload contains an interior NUL.");
        }
    }
    NSData *trimmed = [NSData dataWithBytes:bytes length:length];
    NSString *value = PXArchiveStringFromUTF8Data(trimmed);
    if (!value) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                             [self memberPathForIndex:_currentHeaderIndex field:nil],
                             @"A GNU long-name payload is not valid UTF-8.");
    }
    if (type == 'L') {
        if (_pendingGNUPath || _pendingPAXPath) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                 [self memberPathForIndex:_currentHeaderIndex field:nil],
                                 @"Conflicting archive path overrides are pending.");
        }
        _pendingGNUPath = value;
    } else {
        if (_pendingGNULinkPath || _pendingPAXLinkPath) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                 [self memberPathForIndex:_currentHeaderIndex field:nil],
                                 @"Conflicting archive link overrides are pending.");
        }
        _pendingGNULinkPath = value;
    }
    _hasPendingPerEntryMetadata = YES;
    return YES;
}

- (BOOL)finalizeMetadataWithError:(NSError **)error {
    if (!_metadataNeedsFinalize) {
        return YES;
    }
    NSData *payload = [_metadataPayload copy] ?: [NSData data];
    char type = _metadataType;
    _metadataPayload = nil;
    _metadataNeedsFinalize = NO;
    _metadataType = 0;
    if (type == 'x') {
        return [self parsePAXPayload:payload global:NO error:error];
    }
    if (type == 'g') {
        return [self parsePAXPayload:payload global:YES error:error];
    }
    if (type == 'L' || type == 'K') {
        return [self parseGNULongPayload:payload type:type error:error];
    }
    return PXArchiveFail(error,
                         PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                         [self memberPathForIndex:_currentHeaderIndex field:nil],
                         @"An archive metadata header type is invalid.");
}

- (NSString *)headerPathFromBlock:(const unsigned char *)block
                          format:(PXArchiveTarHeaderFormat)format
                           error:(NSError **)error {
    NSData *nameData = PXArchiveBytesUntilNUL(block, 100);
    NSMutableData *combined = [NSMutableData data];
    if (format == PXArchiveTarHeaderFormatPOSIXUstar) {
        NSData *prefixData = PXArchiveBytesUntilNUL(block + 345, 155);
        if (prefixData.length > 0) {
            [combined appendData:prefixData];
            unsigned char slash = '/';
            [combined appendBytes:&slash length:1];
        }
    }
    [combined appendData:nameData];
    NSString *path = PXArchiveStringFromUTF8Data(combined);
    if (!path) {
        PXArchiveFail(error,
                      PXBackupArchiveValidatorErrorUnsafeEntryPath,
                      [self memberPathForIndex:_currentHeaderIndex field:@"path"],
                      @"An archive header path is not valid UTF-8.");
        return nil;
    }
    return path;
}

- (BOOL)registerNormalizedPath:(NSString *)path
                     directory:(BOOL)directory
                         error:(NSError **)error {
    NSString *fieldPath = [self memberPathForIndex:_currentHeaderIndex field:@"path"];
    if (_realTypesByPath[path] != nil) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorDuplicateEntry,
                             fieldPath,
                             @"An archive member path is duplicated.");
    }

    if (![path isEqualToString:@"."]) {
        NSArray<NSString *> *components = [path componentsSeparatedByString:@"/"];
        NSMutableArray<NSString *> *parentComponents = [NSMutableArray array];
        NSMutableArray<NSString *> *newParents = [NSMutableArray array];
        for (NSUInteger index = 0; index + 1 < components.count; index++) {
            [parentComponents addObject:components[index]];
            NSString *parent = [parentComponents componentsJoinedByString:@"/"];
            if ([_regularPaths containsObject:parent]) {
                return PXArchiveFail(error,
                                     PXBackupArchiveValidatorErrorDuplicateEntry,
                                     fieldPath,
                                     @"An archive member is nested beneath a regular file.");
            }
            if (![_implicitDirectories containsObject:parent]) {
                [newParents addObject:parent];
            }
        }
        if (!directory && [_implicitDirectories containsObject:path]) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorDuplicateEntry,
                                 fieldPath,
                                 @"A regular file conflicts with an existing parent path.");
        }
        NSUInteger implicitCount = _implicitDirectories.count;
        NSUInteger newParentCount = newParents.count;
        if (newParentCount > NSUIntegerMax - implicitCount ||
            implicitCount + newParentCount > PXArchiveMaximumLogicalMembers) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorLimitExceeded,
                                 fieldPath,
                                 @"The archive implicit-directory limit was exceeded.");
        }
        [_implicitDirectories addObjectsFromArray:newParents];
    }

    _realTypesByPath[path] = directory ? @"d" : @"f";
    if (!directory) {
        [_regularPaths addObject:path];
    }
    return YES;
}

- (BOOL)processHeaderBlock:(const unsigned char *)block error:(NSError **)error {
    if (PXArchiveBlockIsZero(block)) {
        _zeroBlockCount++;
        if (_zeroBlockCount == 2) {
            if (_hasPendingPerEntryMetadata || _metadataNeedsFinalize) {
                return PXArchiveFail(error,
                                     PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                                     [self memberPathForIndex:_physicalHeaders field:nil],
                                     @"Archive metadata is pending at the end marker.");
            }
            _afterEnd = YES;
        }
        return YES;
    }
    if (_zeroBlockCount != 0) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInvalidHeader,
                             [self memberPathForIndex:_physicalHeaders field:nil],
                             @"A single zero block was not followed by the archive end marker.");
    }

    if (_physicalHeaders >= PXArchiveMaximumPhysicalHeaders) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorLimitExceeded,
                             [self memberPathForIndex:_physicalHeaders field:nil],
                             @"The archive physical-header limit was exceeded.");
    }
    _currentHeaderIndex = _physicalHeaders;
    _physicalHeaders++;
    NSString *headerPath = [self memberPathForIndex:_currentHeaderIndex field:nil];

    if (!PXArchiveHeaderChecksumIsValid(block)) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInvalidHeader,
                             headerPath,
                             @"An archive header checksum is invalid.");
    }
    PXArchiveTarHeaderFormat format = PXArchiveTarHeaderFormatLegacy;
    if (!PXArchiveClassifyHeaderFormat(block, &format)) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInvalidHeader,
                             headerPath,
                             @"An archive header format is unsupported.");
    }
    uint64_t headerSize = 0;
    uint64_t mode = 0;
    uint64_t userID = 0;
    uint64_t groupID = 0;
    uint64_t modificationTime = 0;
    if (!PXArchiveParseSizeField(block + 124, 12, &headerSize) ||
        !PXArchiveParseOctal(block + 100, 8, &mode) ||
        !PXArchiveParseOctal(block + 108, 8, &userID) ||
        !PXArchiveParseOctal(block + 116, 8, &groupID) ||
        !PXArchiveParseOctal(block + 136, 12, &modificationTime)) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInvalidHeader,
                             headerPath,
                             @"An archive numeric header field is invalid.");
    }
    (void)userID;
    (void)groupID;
    (void)modificationTime;
    char type = (char)block[156];

    if (type == 'x' || type == 'g' || type == 'L' || type == 'K') {
        if (headerSize > PXArchiveMaximumMetadataPayload) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorLimitExceeded,
                                 headerPath,
                                 @"An archive metadata payload exceeds the fixed limit.");
        }
        uint64_t metadataTotal = 0;
        if (!PXArchiveAddUInt64(_metadataTotal, headerSize, &metadataTotal) ||
            metadataTotal > PXArchiveMaximumMetadataTotal) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorLimitExceeded,
                                 headerPath,
                                 @"The archive metadata total exceeds the fixed limit.");
        }
        _metadataTotal = metadataTotal;
        _metadataType = type;
        _metadataPayload = [NSMutableData dataWithCapacity:(NSUInteger)headerSize];
        _metadataNeedsFinalize = YES;
        _payloadRemaining = headerSize;
        _paddingRemaining = (PXTarBlockSize - (headerSize % PXTarBlockSize)) % PXTarBlockSize;
        if (_payloadRemaining == 0 && _paddingRemaining == 0) {
            return [self finalizeMetadataWithError:error];
        }
        return YES;
    }

    BOOL directory = type == '5';
    BOOL regular = type == 0 || type == '0';
    if (!regular && !directory) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorUnsupportedEntryType,
                             [self memberPathForIndex:_currentHeaderIndex field:@"type"],
                             @"An archive member type is unsupported.");
    }
    if (_pendingPAXLinkPath || _pendingGNULinkPath) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                             [self memberPathForIndex:_currentHeaderIndex field:@"type"],
                             @"Link metadata cannot be attached to a regular or directory member.");
    }
    if ((mode & UINT64_C(06000)) != 0) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorUnsupportedEntryType,
                             [self memberPathForIndex:_currentHeaderIndex field:@"type"],
                             @"Set-user-ID and set-group-ID archive modes are unsupported.");
    }

    NSString *headerMemberPath = [self headerPathFromBlock:block
                                                      format:format
                                                       error:error];
    if (!headerMemberPath) {
        return NO;
    }
    NSString *effectivePath = _pendingPAXPath ?: _pendingGNUPath ?: headerMemberPath;
    BOOL rootMarker = NO;
    NSString *normalizedPath = PXArchiveNormalizeMemberPath(
        effectivePath,
        directory,
        &rootMarker,
        error,
        [self memberPathForIndex:_currentHeaderIndex field:@"path"]);
    if (!normalizedPath) {
        return NO;
    }
    (void)rootMarker;

    uint64_t effectiveSize = _pendingPAXSize
        ? _pendingPAXSize.unsignedLongLongValue
        : headerSize;
    if (directory && effectiveSize != 0) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInvalidHeader,
                             [self memberPathForIndex:_currentHeaderIndex field:@"type"],
                             @"A directory archive member must have zero size.");
    }
    if (regular && effectiveSize > PXArchiveMaximumRegularFileBytes) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorLimitExceeded,
                             [self memberPathForIndex:_currentHeaderIndex field:@"type"],
                             @"A regular archive member exceeds the fixed size limit.");
    }
    if (_logicalMembers >= PXArchiveMaximumLogicalMembers ||
        (_restoreLogicalMembers &&
         *_restoreLogicalMembers >= PXArchiveMaximumRestoreLogicalMembers)) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorLimitExceeded,
                             headerPath,
                             @"The archive logical-member limit was exceeded.");
    }
    if (![self registerNormalizedPath:normalizedPath directory:directory error:error]) {
        return NO;
    }

    _logicalMembers++;
    if (_restoreLogicalMembers) {
        (*_restoreLogicalMembers)++;
    }
    if (regular) {
        uint64_t regularTotal = 0;
        if (!PXArchiveAddUInt64(_regularFileBytes, effectiveSize, &regularTotal) ||
            regularTotal > _archiveBudget) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorLimitExceeded,
                                 headerPath,
                                 @"The archive regular-file byte total exceeds the fixed budget.");
        }
        _regularFileBytes = regularTotal;
    }

    [self clearPendingMetadata];
    _payloadRemaining = effectiveSize;
    _paddingRemaining = (PXTarBlockSize - (effectiveSize % PXTarBlockSize)) % PXTarBlockSize;
    _metadataNeedsFinalize = NO;
    _metadataPayload = nil;
    _metadataType = 0;
    return YES;
}

- (BOOL)completePayloadIfNeeded:(NSError **)error {
    if (_payloadRemaining != 0 || _paddingRemaining != 0) {
        return YES;
    }
    if (_metadataNeedsFinalize) {
        return [self finalizeMetadataWithError:error];
    }
    return YES;
}

- (BOOL)consumeBytes:(const unsigned char *)bytes
              length:(size_t)length
               error:(NSError **)error {
    size_t offset = 0;
    while (offset < length) {
        if (_afterEnd) {
            for (size_t index = offset; index < length; index++) {
                if (bytes[index] != 0) {
                    return PXArchiveFail(error,
                                         PXBackupArchiveValidatorErrorInvalidHeader,
                                         [self memberPathForIndex:_physicalHeaders field:nil],
                                         @"Nonzero decompressed data follows the archive end marker.");
                }
            }
            return YES;
        }

        if (![self completePayloadIfNeeded:error]) {
            return NO;
        }
        if (_payloadRemaining > 0) {
            size_t available = length - offset;
            size_t amount = _payloadRemaining < available
                ? (size_t)_payloadRemaining
                : available;
            if (_metadataNeedsFinalize && amount > 0) {
                [_metadataPayload appendBytes:bytes + offset length:amount];
            }
            _payloadRemaining -= amount;
            offset += amount;
            continue;
        }
        if (_paddingRemaining > 0) {
            size_t available = length - offset;
            size_t amount = _paddingRemaining < available
                ? (size_t)_paddingRemaining
                : available;
            _paddingRemaining -= amount;
            offset += amount;
            continue;
        }

        size_t available = length - offset;
        size_t needed = PXTarBlockSize - _headerUsed;
        size_t amount = available < needed ? available : needed;
        memcpy(_headerBlock + _headerUsed, bytes + offset, amount);
        _headerUsed += amount;
        offset += amount;
        if (_headerUsed == PXTarBlockSize) {
            _headerUsed = 0;
            if (![self processHeaderBlock:_headerBlock error:error]) {
                return NO;
            }
        }
    }
    return [self completePayloadIfNeeded:error];
}

- (BOOL)finishWithError:(NSError **)error {
    if (_payloadRemaining != 0 || _paddingRemaining != 0 ||
        _headerUsed != 0 || _metadataNeedsFinalize) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorTruncatedArchive,
                             [self memberPathForIndex:_physicalHeaders field:nil],
                             @"The archive ended within a header, payload or padding region.");
    }
    if (!_afterEnd || _zeroBlockCount < 2) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorTruncatedArchive,
                             [self memberPathForIndex:_physicalHeaders field:nil],
                             @"The archive is missing its two-block end marker.");
    }
    if (_hasPendingPerEntryMetadata || _pendingPAXPath || _pendingPAXSize ||
        _pendingPAXLinkPath || _pendingGNUPath || _pendingGNULinkPath) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInvalidExtendedHeader,
                             [self memberPathForIndex:_physicalHeaders field:nil],
                             @"Archive metadata is pending at end of stream.");
    }
    return YES;
}

@end

static BOOL PXArchiveInflateChunk(z_stream *stream,
                                  const unsigned char *input,
                                  size_t inputLength,
                                  PXArchiveTarParser *parser,
                                  uint64_t archiveBudget,
                                  uint64_t *archiveInflated,
                                  uint64_t *restoreInflated,
                                  BOOL *streamEnded,
                                  NSString *fieldPath,
                                  NSError **error) {
    stream->next_in = (Bytef *)input;
    stream->avail_in = (uInt)inputLength;
    unsigned char output[64 * 1024];

    for (;;) {
        uInt beforeInput = stream->avail_in;
        stream->next_out = output;
        stream->avail_out = (uInt)sizeof(output);
        int status = inflate(stream, Z_NO_FLUSH);
        size_t produced = sizeof(output) - stream->avail_out;
        if (produced > 0) {
            uint64_t nextArchiveInflated = 0;
            uint64_t nextRestoreInflated = 0;
            if (!PXArchiveAddUInt64(*archiveInflated,
                                    (uint64_t)produced,
                                    &nextArchiveInflated) ||
                nextArchiveInflated > archiveBudget ||
                !PXArchiveAddUInt64(*restoreInflated,
                                    (uint64_t)produced,
                                    &nextRestoreInflated) ||
                nextRestoreInflated > PXArchiveMaximumRestoreInflatedBytes) {
                return PXArchiveFail(error,
                                     PXBackupArchiveValidatorErrorLimitExceeded,
                                     fieldPath,
                                     @"The decompressed archive stream exceeds the fixed budget.");
            }
            *archiveInflated = nextArchiveInflated;
            *restoreInflated = nextRestoreInflated;
            if (![parser consumeBytes:output length:produced error:error]) {
                return NO;
            }
        }
        if (status == Z_STREAM_END) {
            if (stream->avail_in != 0) {
                return PXArchiveFail(error,
                                     PXBackupArchiveValidatorErrorUnsupportedCompression,
                                     fieldPath,
                                     @"The gzip stream contains concatenated or trailing data.");
            }
            *streamEnded = YES;
            return YES;
        }
        if (status == Z_BUF_ERROR) {
            if (stream->avail_in == 0 && produced == 0) {
                return YES;
            }
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorTruncatedArchive,
                                 fieldPath,
                                 @"The gzip stream is incomplete.");
        }
        if (status != Z_OK) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorUnsupportedCompression,
                                 fieldPath,
                                 @"The gzip stream is invalid.");
        }
        if (produced == 0 && stream->avail_in == beforeInput) {
            if (stream->avail_in == 0) {
                return YES;
            }
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorUnsupportedCompression,
                                 fieldPath,
                                 @"The gzip decoder made no progress.");
        }
        if (stream->avail_in == 0 && stream->avail_out != 0) {
            return YES;
        }
        // Continue when compressed input remains or a full output buffer may
        // have left additional decompressed bytes pending inside zlib.
    }
}

static ssize_t PXArchiveReadRetry(int descriptor, void *buffer, size_t length) {
    for (;;) {
        ssize_t result = read(descriptor, buffer, length);
        if (result < 0 && errno == EINTR) {
            continue;
        }
        return result;
    }
}

static BOOL PXArchiveValidateOne(PXArchiveReference *reference,
                                 NSString *canonicalRoot,
                                 int rootDescriptor,
                                 uint64_t *restoreInflated,
                                 uint64_t *restoreLogicalMembers,
                                 NSNumber **memberCountOut,
                                 NSNumber **regularFileBytesOut,
                                 NSError **error) {
    PXArchiveDeclaration *declaration = reference.declaration;
    NSString *fieldPath = reference.fieldPath;
    NSString *expectedCanonicalPath = [NSString stringWithFormat:@"%@/%@",
                                       canonicalRoot,
                                       declaration.name];
    if (![reference.verifiedPath isEqualToString:expectedCanonicalPath]) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInconsistentManifest,
                             fieldPath,
                             @"The verified archive path does not match the selected backup root.");
    }

    int descriptor = -1;
    struct stat beforeStatus;
    if (!PXArchiveOpenRelativeFile(rootDescriptor,
                                   declaration.name,
                                   fieldPath,
                                   &descriptor,
                                   &beforeStatus,
                                   error)) {
        return NO;
    }

    BOOL success = NO;
    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    BOOL inflateInitialized = NO;
    do {
        if (beforeStatus.st_size < 0 ||
            (uint64_t)beforeStatus.st_size != declaration.expectedCompressedSize) {
            PXArchiveFail(error,
                          PXBackupArchiveValidatorErrorSizeMismatch,
                          fieldPath,
                          @"The compressed archive size does not match its declaration.");
            break;
        }

        uint64_t archiveBudget = PXArchiveInflatedBudget(declaration.expectedCompressedSize);
        PXArchiveTarParser *parser = [[PXArchiveTarParser alloc]
            initWithArtifactIndex:declaration.originalIndex
                    archiveBudget:archiveBudget
           restoreLogicalMembers:restoreLogicalMembers];

        int initializeStatus = inflateInit2(&stream, 16 + MAX_WBITS);
        if (initializeStatus != Z_OK) {
            PXArchiveFail(error,
                          PXBackupArchiveValidatorErrorUnsupportedCompression,
                          fieldPath,
                          @"The gzip decoder could not be initialized.");
            break;
        }
        inflateInitialized = YES;

        CC_SHA256_CTX digestContext;
        CC_SHA256_Init(&digestContext);
        uint64_t compressedRead = 0;
        uint64_t archiveInflated = 0;
        BOOL streamEnded = NO;

        unsigned char prefix[3];
        size_t prefixUsed = 0;
        while (prefixUsed < sizeof(prefix)) {
            ssize_t amount = PXArchiveReadRetry(descriptor,
                                                prefix + prefixUsed,
                                                sizeof(prefix) - prefixUsed);
            if (amount < 0) {
                PXArchiveFail(error,
                              PXBackupArchiveValidatorErrorReadFailed,
                              fieldPath,
                              @"The compressed archive could not be read.");
                break;
            }
            if (amount == 0) {
                PXArchiveFail(error,
                              PXBackupArchiveValidatorErrorTruncatedArchive,
                              fieldPath,
                              @"The compressed archive ended before its gzip header.");
                break;
            }
            prefixUsed += (size_t)amount;
            if (!PXArchiveAddUInt64(compressedRead,
                                    (uint64_t)amount,
                                    &compressedRead) ||
                compressedRead > declaration.expectedCompressedSize) {
                PXArchiveFail(error,
                              PXBackupArchiveValidatorErrorSizeMismatch,
                              fieldPath,
                              @"The compressed archive byte count is inconsistent.");
                break;
            }
            CC_SHA256_Update(&digestContext,
                             prefix + (prefixUsed - (size_t)amount),
                             (CC_LONG)amount);
        }
        if (prefixUsed != sizeof(prefix)) {
            break;
        }
        if (prefix[0] != 0x1f || prefix[1] != 0x8b || prefix[2] != Z_DEFLATED) {
            PXArchiveFail(error,
                          PXBackupArchiveValidatorErrorUnsupportedCompression,
                          fieldPath,
                          @"The archive is not a supported gzip deflate stream.");
            break;
        }
        if (!PXArchiveInflateChunk(&stream,
                                   prefix,
                                   sizeof(prefix),
                                   parser,
                                   archiveBudget,
                                   &archiveInflated,
                                   restoreInflated,
                                   &streamEnded,
                                   fieldPath,
                                   error)) {
            break;
        }
        if (streamEnded) {
            PXArchiveFail(error,
                          PXBackupArchiveValidatorErrorTruncatedArchive,
                          fieldPath,
                          @"The gzip stream ended before a complete tar stream.");
            break;
        }

        unsigned char input[64 * 1024];
        BOOL readFailure = NO;
        while (!streamEnded) {
            ssize_t amount = PXArchiveReadRetry(descriptor, input, sizeof(input));
            if (amount < 0) {
                PXArchiveFail(error,
                              PXBackupArchiveValidatorErrorReadFailed,
                              fieldPath,
                              @"The compressed archive could not be read.");
                readFailure = YES;
                break;
            }
            if (amount == 0) {
                PXArchiveFail(error,
                              PXBackupArchiveValidatorErrorTruncatedArchive,
                              fieldPath,
                              @"The gzip stream ended before Z_STREAM_END.");
                readFailure = YES;
                break;
            }
            if (!PXArchiveAddUInt64(compressedRead,
                                    (uint64_t)amount,
                                    &compressedRead) ||
                compressedRead > declaration.expectedCompressedSize) {
                PXArchiveFail(error,
                              PXBackupArchiveValidatorErrorSizeMismatch,
                              fieldPath,
                              @"The compressed archive byte count is inconsistent.");
                readFailure = YES;
                break;
            }
            CC_SHA256_Update(&digestContext, input, (CC_LONG)amount);
            if (!PXArchiveInflateChunk(&stream,
                                       input,
                                       (size_t)amount,
                                       parser,
                                       archiveBudget,
                                       &archiveInflated,
                                       restoreInflated,
                                       &streamEnded,
                                       fieldPath,
                                       error)) {
                readFailure = YES;
                break;
            }
        }
        if (readFailure) {
            break;
        }
        if (compressedRead != declaration.expectedCompressedSize) {
            PXArchiveFail(error,
                          PXBackupArchiveValidatorErrorUnsupportedCompression,
                          fieldPath,
                          @"The gzip stream has trailing or concatenated compressed data.");
            break;
        }
        if (![parser finishWithError:error]) {
            break;
        }

        unsigned char compressedDigest[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256_Final(compressedDigest, &digestContext);
        NSString *actualDigest = PXArchiveHexDigest(compressedDigest);

        struct stat afterStatus;
        if (fstat(descriptor, &afterStatus) != 0 ||
            !PXArchiveStatIdentityEqual(&beforeStatus, &afterStatus)) {
            PXArchiveFail(error,
                          PXBackupArchiveValidatorErrorFilesystemChanged,
                          fieldPath,
                          @"The compressed archive changed during validation.");
            break;
        }
        if (compressedRead != (uint64_t)afterStatus.st_size) {
            PXArchiveFail(error,
                          PXBackupArchiveValidatorErrorSizeMismatch,
                          fieldPath,
                          @"The compressed archive byte count does not match its file size.");
            break;
        }
        if (![actualDigest isEqualToString:declaration.expectedDigest]) {
            PXArchiveFail(error,
                          PXBackupArchiveValidatorErrorDigestMismatch,
                          fieldPath,
                          @"The compressed archive digest does not match its declaration.");
            break;
        }

        struct stat pathStatus;
        const char *canonicalPath = expectedCanonicalPath.fileSystemRepresentation;
        if (!canonicalPath || lstat(canonicalPath, &pathStatus) != 0 ||
            S_ISLNK(pathStatus.st_mode) || !S_ISREG(pathStatus.st_mode) ||
            pathStatus.st_dev != afterStatus.st_dev ||
            pathStatus.st_ino != afterStatus.st_ino) {
            PXArchiveFail(error,
                          PXBackupArchiveValidatorErrorFilesystemChanged,
                          fieldPath,
                          @"The archive path identity changed during validation.");
            break;
        }

        if (memberCountOut) {
            *memberCountOut = @(parser.logicalMembers);
        }
        if (regularFileBytesOut) {
            *regularFileBytesOut = @(parser.regularFileBytes);
        }
        success = YES;
    } while (NO);

    if (inflateInitialized) {
        inflateEnd(&stream);
    }
    close(descriptor);
    return success;
}

static BOOL PXArchiveBuildDeclarations(NSDictionary *manifest,
                                       NSDictionary<NSString *, PXArchiveDeclaration *> **mapOut,
                                       NSError **error) {
    if (mapOut) {
        *mapOut = nil;
    }
    id artifactsObject = manifest[@"artifacts"];
    if (![artifactsObject isKindOfClass:[NSArray class]]) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInvalidInput,
                             @"$.artifacts",
                             @"The artifact declaration section is invalid.");
    }
    NSArray *artifacts = (NSArray *)artifactsObject;
    NSMutableDictionary<NSString *, PXArchiveDeclaration *> *map =
        [NSMutableDictionary dictionaryWithCapacity:artifacts.count];
    for (NSUInteger index = 0; index < artifacts.count; index++) {
        NSString *entryPath = PXArchiveIndexedPath(@"$.artifacts", index);
        id entryObject = artifacts[index];
        if (![entryObject isKindOfClass:[NSDictionary class]]) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidInput,
                                 entryPath,
                                 @"An artifact declaration is invalid.");
        }
        NSDictionary *entry = (NSDictionary *)entryObject;
        id nameObject = entry[@"name"];
        uint64_t expectedSize = 0;
        if (!PXArchiveArtifactNameIsSafe(nameObject)) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidInput,
                                 PXArchiveFieldPath(entryPath, @"name"),
                                 @"An artifact name is invalid.");
        }
        NSString *name = (NSString *)nameObject;
        if (map[name] != nil) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInconsistentManifest,
                                 PXArchiveFieldPath(entryPath, @"name"),
                                 @"An artifact declaration name is duplicated.");
        }
        if (!PXArchiveNonnegativeIntegralNumber(entry[@"size"], &expectedSize)) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidInput,
                                 PXArchiveFieldPath(entryPath, @"size"),
                                 @"An artifact compressed size is invalid.");
        }
        if (!PXArchiveDigestIsValid(entry[@"sha256"])) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidInput,
                                 PXArchiveFieldPath(entryPath, @"sha256"),
                                 @"An artifact compressed digest is invalid.");
        }
        PXArchiveDeclaration *declaration = [[PXArchiveDeclaration alloc] init];
        declaration.originalIndex = index;
        declaration.name = name;
        declaration.expectedCompressedSize = expectedSize;
        declaration.expectedDigest = entry[@"sha256"];
        map[name] = declaration;
    }
    if (mapOut) {
        *mapOut = [map copy];
    }
    return YES;
}

static BOOL PXArchiveAddReference(id nameObject,
                                  NSString *fieldPath,
                                  NSDictionary<NSString *, PXArchiveDeclaration *> *declarations,
                                  PXVerifiedBackupArtifactSet *verifiedArtifacts,
                                  NSMutableSet<NSString *> *seen,
                                  NSMutableArray<PXArchiveReference *> *references,
                                  NSError **error) {
    if (!PXArchiveArtifactNameIsSafe(nameObject)) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInvalidInput,
                             fieldPath,
                             @"An archive reference is invalid.");
    }
    NSString *name = (NSString *)nameObject;
    if ([seen containsObject:name]) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInconsistentManifest,
                             fieldPath,
                             @"An archive is referenced more than once.");
    }
    PXArchiveDeclaration *declaration = declarations[name];
    if (!declaration) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorMissingArchive,
                             fieldPath,
                             @"An archive reference has no artifact declaration.");
    }
    NSString *verifiedPath = [verifiedArtifacts pathForArtifactName:name];
    if (verifiedPath.length == 0) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorMissingArchive,
                             fieldPath,
                             @"An archive reference is absent from the verified artifact set.");
    }
    if (references.count >= PXArchiveMaximumReferences) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorLimitExceeded,
                             fieldPath,
                             @"The archive-reference count exceeds the fixed limit.");
    }
    PXArchiveReference *reference = [[PXArchiveReference alloc] init];
    reference.fieldPath = fieldPath;
    reference.declaration = declaration;
    reference.verifiedPath = verifiedPath;
    [references addObject:reference];
    [seen addObject:name];
    return YES;
}

static BOOL PXArchiveCollectReferences(NSDictionary *manifest,
                                       NSDictionary<NSString *, PXArchiveDeclaration *> *declarations,
                                       PXVerifiedBackupArtifactSet *verifiedArtifacts,
                                       NSArray<PXArchiveReference *> **referencesOut,
                                       NSError **error) {
    if (referencesOut) {
        *referencesOut = nil;
    }
    NSMutableArray<PXArchiveReference *> *references = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];

    id dataObject = manifest[@"data"];
    if (![dataObject isKindOfClass:[NSDictionary class]] ||
        !PXArchiveAddReference(((NSDictionary *)dataObject)[@"archive"],
                               @"$.data.archive",
                               declarations,
                               verifiedArtifacts,
                               seen,
                               references,
                               error)) {
        if (![dataObject isKindOfClass:[NSDictionary class]] && error && !*error) {
            PXArchiveFail(error,
                          PXBackupArchiveValidatorErrorInvalidInput,
                          @"$.data",
                          @"The data archive section is invalid.");
        }
        return NO;
    }

    id groupsObject = manifest[@"appGroups"];
    if (![groupsObject isKindOfClass:[NSArray class]]) {
        return PXArchiveFail(error,
                             PXBackupArchiveValidatorErrorInvalidInput,
                             @"$.appGroups",
                             @"The App Group archive section is invalid.");
    }
    NSArray *groups = (NSArray *)groupsObject;
    for (NSUInteger index = 0; index < groups.count; index++) {
        NSString *entryPath = PXArchiveIndexedPath(@"$.appGroups", index);
        id entryObject = groups[index];
        if (![entryObject isKindOfClass:[NSDictionary class]] ||
            !PXArchiveAddReference(((NSDictionary *)entryObject)[@"archive"],
                                   PXArchiveFieldPath(entryPath, @"archive"),
                                   declarations,
                                   verifiedArtifacts,
                                   seen,
                                   references,
                                   error)) {
            if (![entryObject isKindOfClass:[NSDictionary class]] && error && !*error) {
                PXArchiveFail(error,
                              PXBackupArchiveValidatorErrorInvalidInput,
                              entryPath,
                              @"An App Group archive entry is invalid.");
            }
            return NO;
        }
    }

    NSArray<NSString *> *optionalSections = @[@"profileAppData", @"globalSafari"];
    for (NSString *sectionName in optionalSections) {
        NSString *sectionPath = [@"$." stringByAppendingString:sectionName];
        id sectionObject = manifest[sectionName];
        if (![sectionObject isKindOfClass:[NSDictionary class]]) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidInput,
                                 sectionPath,
                                 @"An optional archive section is invalid.");
        }
        NSDictionary *section = (NSDictionary *)sectionObject;
        BOOL included = NO;
        if (!PXArchiveExactBoolean(section[@"included"], &included)) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidInput,
                                 PXArchiveFieldPath(sectionPath, @"included"),
                                 @"An optional archive inclusion flag is invalid.");
        }
        if (included &&
            !PXArchiveAddReference(section[@"archive"],
                                   PXArchiveFieldPath(sectionPath, @"archive"),
                                   declarations,
                                   verifiedArtifacts,
                                   seen,
                                   references,
                                   error)) {
            return NO;
        }
    }

    id systemObject = manifest[@"systemGlobalLibrary"];
    if (systemObject != nil) {
        if (![systemObject isKindOfClass:[NSDictionary class]]) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidInput,
                                 @"$.systemGlobalLibrary",
                                 @"The system-global archive section is invalid.");
        }
        NSDictionary *system = (NSDictionary *)systemObject;
        BOOL systemIncluded = NO;
        if (!PXArchiveExactBoolean(system[@"included"], &systemIncluded)) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidInput,
                                 @"$.systemGlobalLibrary.included",
                                 @"The system-global inclusion flag is invalid.");
        }
        id itemsObject = system[@"items"];
        if (![itemsObject isKindOfClass:[NSArray class]]) {
            return PXArchiveFail(error,
                                 PXBackupArchiveValidatorErrorInvalidInput,
                                 @"$.systemGlobalLibrary.items",
                                 @"The system-global archive items are invalid.");
        }
        if (systemIncluded) {
            NSArray *items = (NSArray *)itemsObject;
            for (NSUInteger index = 0; index < items.count; index++) {
                NSString *entryPath = PXArchiveIndexedPath(@"$.systemGlobalLibrary.items", index);
                id entryObject = items[index];
                if (![entryObject isKindOfClass:[NSDictionary class]] ||
                    !PXArchiveAddReference(((NSDictionary *)entryObject)[@"archive"],
                                           PXArchiveFieldPath(entryPath, @"archive"),
                                           declarations,
                                           verifiedArtifacts,
                                           seen,
                                           references,
                                           error)) {
                    if (![entryObject isKindOfClass:[NSDictionary class]] && error && !*error) {
                        PXArchiveFail(error,
                                      PXBackupArchiveValidatorErrorInvalidInput,
                                      entryPath,
                                      @"A system-global archive entry is invalid.");
                    }
                    return NO;
                }
            }
        }
    }

    [references sortUsingComparator:^NSComparisonResult(PXArchiveReference *left,
                                                         PXArchiveReference *right) {
        return [left.declaration.name compare:right.declaration.name];
    }];
    if (referencesOut) {
        *referencesOut = [references copy];
    }
    return YES;
}

@implementation PXBackupArchiveValidator

+ (PXValidatedBackupArchiveSet *)validatedArchivesForManifest:(NSDictionary *)manifest
                                              backupDirectory:(NSString *)backupDirectory
                                            verifiedArtifacts:(PXVerifiedBackupArtifactSet *)verifiedArtifacts
                                                        error:(NSError **)error {
    if (error) {
        *error = nil;
    }
    if (![manifest isKindOfClass:[NSDictionary class]] ||
        !PXArchiveStringInputIsValid(backupDirectory) ||
        ![verifiedArtifacts isKindOfClass:[PXVerifiedBackupArtifactSet class]]) {
        PXArchiveFail(error,
                      PXBackupArchiveValidatorErrorInvalidInput,
                      @"$",
                      @"The archive validation request is invalid.");
        return nil;
    }

    NSDictionary<NSString *, PXArchiveDeclaration *> *declarations = nil;
    if (!PXArchiveBuildDeclarations(manifest, &declarations, error)) {
        return nil;
    }
    NSArray<PXArchiveReference *> *references = nil;
    if (!PXArchiveCollectReferences(manifest,
                                    declarations,
                                    verifiedArtifacts,
                                    &references,
                                    error)) {
        return nil;
    }

    NSString *canonicalRoot = nil;
    int rootDescriptor = -1;
    if (!PXArchiveOpenCanonicalBackupRoot(backupDirectory,
                                          &canonicalRoot,
                                          &rootDescriptor,
                                          error)) {
        return nil;
    }

    NSMutableDictionary<NSString *, NSNumber *> *memberCounts =
        [NSMutableDictionary dictionaryWithCapacity:references.count];
    NSMutableDictionary<NSString *, NSNumber *> *regularFileBytes =
        [NSMutableDictionary dictionaryWithCapacity:references.count];
    uint64_t restoreInflated = 0;
    uint64_t restoreLogicalMembers = 0;
    BOOL valid = YES;
    for (PXArchiveReference *reference in references) {
        NSNumber *memberCount = nil;
        NSNumber *regularBytes = nil;
        if (!PXArchiveValidateOne(reference,
                                  canonicalRoot,
                                  rootDescriptor,
                                  &restoreInflated,
                                  &restoreLogicalMembers,
                                  &memberCount,
                                  &regularBytes,
                                  error)) {
            valid = NO;
            break;
        }
        memberCounts[reference.declaration.name] = memberCount;
        regularFileBytes[reference.declaration.name] = regularBytes;
    }
    close(rootDescriptor);
    if (!valid) {
        return nil;
    }

    return [[PXValidatedBackupArchiveSet alloc]
        initWithMemberCounts:memberCounts
            regularFileBytes:regularFileBytes];
}

@end
