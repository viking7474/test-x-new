#import "PXBackupArtifactVerifier.h"
#import "PXFileProtection.h"

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

NSString * const PXBackupArtifactVerifierErrorDomain =
    @"PXBackupArtifactVerifierErrorDomain";

NSString * const PXBackupArtifactVerifierErrorFieldPathKey =
    @"PXBackupArtifactVerifierErrorFieldPathKey";

@interface PXBackupArtifactDeclaration : NSObject

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, assign, readonly) uint64_t expectedSize;
@property (nonatomic, copy, readonly) NSString *expectedDigest;
@property (nonatomic, assign, readonly) NSUInteger originalIndex;
@property (nonatomic, assign, readonly) BOOL requiresCompleteProtection;

- (instancetype)initWithName:(NSString *)name
                expectedSize:(uint64_t)expectedSize
              expectedDigest:(NSString *)expectedDigest
               originalIndex:(NSUInteger)originalIndex
  requiresCompleteProtection:(BOOL)requiresCompleteProtection;

@end

@implementation PXBackupArtifactDeclaration

- (instancetype)initWithName:(NSString *)name
                expectedSize:(uint64_t)expectedSize
              expectedDigest:(NSString *)expectedDigest
               originalIndex:(NSUInteger)originalIndex
  requiresCompleteProtection:(BOOL)requiresCompleteProtection {
    self = [super init];
    if (self) {
        _name = [name copy];
        _expectedSize = expectedSize;
        _expectedDigest = [expectedDigest copy];
        _originalIndex = originalIndex;
        _requiresCompleteProtection = requiresCompleteProtection;
    }
    return self;
}

@end

@interface PXVerifiedBackupArtifactSet ()

@property (nonatomic, copy, readwrite) NSArray<NSString *> *artifactNames;
@property (nonatomic, copy, readwrite)
    NSDictionary<NSString *, NSString *> *canonicalPathsByName;

- (instancetype)initWithCanonicalPathsByName:
    (NSDictionary<NSString *, NSString *> *)canonicalPathsByName;

@end

@implementation PXVerifiedBackupArtifactSet

- (instancetype)initWithCanonicalPathsByName:
    (NSDictionary<NSString *, NSString *> *)canonicalPathsByName {
    self = [super init];
    if (self) {
        _canonicalPathsByName = [canonicalPathsByName copy];
        _artifactNames = [[_canonicalPathsByName allKeys]
            sortedArrayUsingSelector:@selector(compare:)];
    }
    return self;
}

- (NSString *)pathForArtifactName:(NSString *)artifactName {
    if (![artifactName isKindOfClass:[NSString class]] ||
        artifactName.length == 0) {
        return nil;
    }
    return self.canonicalPathsByName[artifactName];
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end

static BOOL PXArtifactFail(NSError **error,
                           PXBackupArtifactVerifierErrorCode code,
                           NSString *fieldPath,
                           NSString *description) {
    if (error) {
        *error = [NSError errorWithDomain:PXBackupArtifactVerifierErrorDomain
                                     code:code
                                 userInfo:@{
                                     NSLocalizedDescriptionKey: description,
                                     PXBackupArtifactVerifierErrorFieldPathKey: fieldPath
                                 }];
    }
    return NO;
}

static NSString *PXArtifactIndexedPath(NSString *basePath, NSUInteger index) {
    NSString *indexString = [[NSNumber numberWithUnsignedInteger:index] stringValue];
    NSString *prefix = [[basePath stringByAppendingString:@"["]
        stringByAppendingString:indexString];
    return [prefix stringByAppendingString:@"]"];
}

static NSString *PXArtifactFieldPath(NSString *basePath, NSString *field) {
    return [[basePath stringByAppendingString:@"."] stringByAppendingString:field];
}

static BOOL PXArtifactStringContainsNUL(NSString *value) {
    unichar nulCharacter = 0;
    NSString *nulString = [NSString stringWithCharacters:&nulCharacter length:1];
    return [value rangeOfString:nulString].location != NSNotFound;
}

static BOOL PXArtifactStringContainsNonWhitespace(NSString *value) {
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [value rangeOfCharacterFromSet:[whitespace invertedSet]].location
        != NSNotFound;
}

static BOOL PXArtifactBackupDirectoryStringIsValid(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }
    NSString *string = (NSString *)value;
    return string.length > 0 &&
           PXArtifactStringContainsNonWhitespace(string) &&
           !PXArtifactStringContainsNUL(string);
}

static BOOL PXArtifactRelativeNameIsSafe(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }

    NSString *name = (NSString *)value;
    if (name.length == 0 ||
        !PXArtifactStringContainsNonWhitespace(name) ||
        PXArtifactStringContainsNUL(name) ||
        [name characterAtIndex:0] == (unichar)'/' ||
        [name characterAtIndex:(name.length - 1)] == (unichar)'/' ||
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

static BOOL PXArtifactIsExactBoolean(id value) {
    if (![value isKindOfClass:[NSNumber class]]) {
        return NO;
    }
    return CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

static BOOL PXArtifactReadExactBoolean(id value, BOOL *result) {
    if (!PXArtifactIsExactBoolean(value)) {
        return NO;
    }
    if (result) {
        *result = [(NSNumber *)value boolValue];
    }
    return YES;
}

static BOOL PXArtifactReadUnsignedIntegral(id value,
                                           uint64_t maximum,
                                           uint64_t *result) {
    if (![value isKindOfClass:[NSNumber class]] ||
        PXArtifactIsExactBoolean(value)) {
        return NO;
    }

    NSNumber *number = (NSNumber *)value;
    const char *type = number.objCType;
    if (!type || type[0] == '\0' || type[1] != '\0') {
        return NO;
    }

    uint64_t parsed = 0;
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
            parsed = (uint64_t)signedValue;
            break;
        }
        case 'C':
        case 'S':
        case 'I':
        case 'L':
        case 'Q':
            parsed = number.unsignedLongLongValue;
            break;
        default:
            return NO;
    }

    if (parsed > maximum) {
        return NO;
    }
    if (result) {
        *result = parsed;
    }
    return YES;
}

static BOOL PXArtifactDigestIsCompleteLowercaseSHA256(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }

    NSString *digest = (NSString *)value;
    if (digest.length != CC_SHA256_DIGEST_LENGTH * 2) {
        return NO;
    }
    for (NSUInteger index = 0; index < digest.length; index++) {
        unichar character = [digest characterAtIndex:index];
        BOOL decimal = character >= (unichar)'0' && character <= (unichar)'9';
        BOOL lowercaseHex = character >= (unichar)'a' && character <= (unichar)'f';
        if (!decimal && !lowercaseHex) {
            return NO;
        }
    }
    return YES;
}

static NSString *PXArtifactHexDigest(
    const unsigned char digest[CC_SHA256_DIGEST_LENGTH]) {
    static const char alphabet[] = "0123456789abcdef";
    char output[CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        output[index * 2] = alphabet[(digest[index] >> 4) & 0x0f];
        output[(index * 2) + 1] = alphabet[digest[index] & 0x0f];
    }
    return [[NSString alloc] initWithBytes:output
                                    length:sizeof(output)
                                  encoding:NSASCIIStringEncoding];
}

static BOOL PXArtifactTimespecEqual(struct timespec left,
                                    struct timespec right) {
    return left.tv_sec == right.tv_sec && left.tv_nsec == right.tv_nsec;
}

static BOOL PXArtifactStatIdentityIsStable(const struct stat *before,
                                           const struct stat *after) {
    if (!before || !after) {
        return NO;
    }
    if (before->st_dev != after->st_dev ||
        before->st_ino != after->st_ino ||
        !S_ISREG(before->st_mode) ||
        !S_ISREG(after->st_mode) ||
        before->st_size != after->st_size) {
        return NO;
    }
#if defined(__APPLE__)
    return PXArtifactTimespecEqual(before->st_mtimespec, after->st_mtimespec) &&
           PXArtifactTimespecEqual(before->st_ctimespec, after->st_ctimespec);
#else
    return PXArtifactTimespecEqual(before->st_mtim, after->st_mtim) &&
           PXArtifactTimespecEqual(before->st_ctim, after->st_ctim);
#endif
}

static PXBackupArtifactVerifierErrorCode PXArtifactOpenErrorCode(int openError) {
    if (openError == ELOOP) {
        return PXBackupArtifactVerifierErrorSymlinkRejected;
    }
    if (openError == ENOENT) {
        return PXBackupArtifactVerifierErrorMissingArtifact;
    }
    return PXBackupArtifactVerifierErrorFilesystemInspectionFailed;
}

static BOOL PXArtifactOpenCanonicalBackupRoot(NSString *backupDirectory,
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
           [inspectionPath characterAtIndex:(inspectionPath.length - 1)] ==
               (unichar)'/') {
        inspectionPath = [inspectionPath substringToIndex:(inspectionPath.length - 1)];
    }

    const char *rawPath = inspectionPath.fileSystemRepresentation;
    if (!rawPath) {
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorInvalidInput,
                              @"$",
                              @"The backup directory input is invalid.");
    }

    struct stat rawStatus;
    errno = 0;
    if (lstat(rawPath, &rawStatus) != 0) {
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
                              @"$",
                              @"The backup directory could not be inspected.");
    }
    if (S_ISLNK(rawStatus.st_mode)) {
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorSymlinkRejected,
                              @"$",
                              @"The backup directory final component must not be a symbolic link.");
    }
    if (!S_ISDIR(rawStatus.st_mode)) {
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
                              @"$",
                              @"The backup directory must be a directory.");
    }

    int rawDescriptor = open(rawPath,
                             O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (rawDescriptor < 0) {
        PXBackupArtifactVerifierErrorCode code =
            errno == ELOOP
                ? PXBackupArtifactVerifierErrorSymlinkRejected
                : PXBackupArtifactVerifierErrorFilesystemInspectionFailed;
        return PXArtifactFail(error,
                              code,
                              @"$",
                              @"The backup directory could not be opened safely.");
    }

    struct stat openedRawStatus;
    if (fstat(rawDescriptor, &openedRawStatus) != 0 ||
        !S_ISDIR(openedRawStatus.st_mode)) {
        close(rawDescriptor);
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
                              @"$",
                              @"The backup directory descriptor could not be verified.");
    }
    if (rawStatus.st_dev != openedRawStatus.st_dev ||
        rawStatus.st_ino != openedRawStatus.st_ino) {
        close(rawDescriptor);
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorFilesystemChanged,
                              @"$",
                              @"The backup directory changed before it was opened.");
    }

    char canonicalBuffer[PATH_MAX];
    errno = 0;
    if (realpath(rawPath, canonicalBuffer) == NULL) {
        close(rawDescriptor);
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
                              @"$",
                              @"The backup directory could not be canonicalized.");
    }

    NSString *canonicalRoot = [[NSString alloc]
        initWithBytes:canonicalBuffer
               length:strlen(canonicalBuffer)
             encoding:NSUTF8StringEncoding];
    if (canonicalRoot.length == 0) {
        close(rawDescriptor);
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
                              @"$",
                              @"The canonical backup directory is invalid.");
    }

    int rootDescriptor = open(canonicalBuffer,
                              O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (rootDescriptor < 0) {
        PXBackupArtifactVerifierErrorCode code =
            errno == ELOOP
                ? PXBackupArtifactVerifierErrorSymlinkRejected
                : PXBackupArtifactVerifierErrorFilesystemInspectionFailed;
        close(rawDescriptor);
        return PXArtifactFail(error,
                              code,
                              @"$",
                              @"The canonical backup directory could not be opened safely.");
    }

    struct stat canonicalStatus;
    if (fstat(rootDescriptor, &canonicalStatus) != 0 ||
        !S_ISDIR(canonicalStatus.st_mode)) {
        close(rootDescriptor);
        close(rawDescriptor);
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
                              @"$",
                              @"The canonical backup directory could not be verified.");
    }
    if (openedRawStatus.st_dev != canonicalStatus.st_dev ||
        openedRawStatus.st_ino != canonicalStatus.st_ino) {
        close(rootDescriptor);
        close(rawDescriptor);
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorFilesystemChanged,
                              @"$",
                              @"The backup directory changed during canonicalization.");
    }
    close(rawDescriptor);

    if (canonicalRootOut) {
        *canonicalRootOut = canonicalRoot;
    }
    if (rootDescriptorOut) {
        *rootDescriptorOut = rootDescriptor;
    } else {
        close(rootDescriptor);
    }
    return YES;
}

static BOOL PXArtifactCanonicalPathIsWithinRoot(NSString *canonicalRoot,
                                                NSString *canonicalPath) {
    if (canonicalRoot.length == 0 || canonicalPath.length == 0) {
        return NO;
    }
    NSString *boundaryPrefix = [canonicalRoot stringByAppendingString:@"/"];
    return canonicalPath.length > boundaryPrefix.length &&
           [canonicalPath hasPrefix:boundaryPrefix];
}

static BOOL PXArtifactOpenRelativeFile(int rootDescriptor,
                                       NSString *relativeName,
                                       NSString *fieldPath,
                                       int *fileDescriptorOut,
                                       NSError **error) {
    if (fileDescriptorOut) {
        *fileDescriptorOut = -1;
    }

    NSArray<NSString *> *components =
        [relativeName componentsSeparatedByString:@"/"];
    int currentDescriptor = rootDescriptor;
    BOOL ownsCurrentDescriptor = NO;

    for (NSUInteger index = 0; index + 1 < components.count; index++) {
        NSString *component = components[index];
        const char *componentName = component.fileSystemRepresentation;
        if (!componentName) {
            if (ownsCurrentDescriptor) {
                close(currentDescriptor);
            }
            return PXArtifactFail(error,
                                  PXBackupArtifactVerifierErrorUnsafeRelativePath,
                                  fieldPath,
                                  @"The artifact name cannot be represented safely.");
        }

        int nextDescriptor = openat(currentDescriptor,
                                    componentName,
                                    O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (nextDescriptor < 0) {
            int capturedError = errno;
            if (ownsCurrentDescriptor) {
                close(currentDescriptor);
            }
            return PXArtifactFail(error,
                                  PXArtifactOpenErrorCode(capturedError),
                                  fieldPath,
                                  @"An artifact parent component could not be opened safely.");
        }
        if (ownsCurrentDescriptor) {
            close(currentDescriptor);
        }
        currentDescriptor = nextDescriptor;
        ownsCurrentDescriptor = YES;
    }

    NSString *finalComponent = components.lastObject;
    const char *finalName = finalComponent.fileSystemRepresentation;
    if (!finalName) {
        if (ownsCurrentDescriptor) {
            close(currentDescriptor);
        }
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorUnsafeRelativePath,
                              fieldPath,
                              @"The artifact name cannot be represented safely.");
    }

    int fileDescriptor = openat(currentDescriptor,
                                finalName,
                                O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC);
    int capturedError = errno;
    if (ownsCurrentDescriptor) {
        close(currentDescriptor);
    }
    if (fileDescriptor < 0) {
        return PXArtifactFail(error,
                              PXArtifactOpenErrorCode(capturedError),
                              fieldPath,
                              @"The artifact could not be opened safely.");
    }

    if (fileDescriptorOut) {
        *fileDescriptorOut = fileDescriptor;
    } else {
        close(fileDescriptor);
    }
    return YES;
}

static BOOL PXArtifactHashDescriptor(int fileDescriptor,
                                     NSString **digestOut,
                                     NSError **error,
                                     NSString *fieldPath) {
    if (digestOut) {
        *digestOut = nil;
    }

    CC_SHA256_CTX context;
    if (CC_SHA256_Init(&context) != 1) {
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorDigestReadFailed,
                              fieldPath,
                              @"The artifact digest could not be initialized.");
    }

    unsigned char buffer[64 * 1024];
    for (;;) {
        ssize_t count = read(fileDescriptor, buffer, sizeof(buffer));
        if (count > 0) {
            if (CC_SHA256_Update(&context, buffer, (CC_LONG)count) != 1) {
                return PXArtifactFail(error,
                                      PXBackupArtifactVerifierErrorDigestReadFailed,
                                      fieldPath,
                                      @"The artifact digest could not be updated.");
            }
            continue;
        }
        if (count == 0) {
            break;
        }
        if (errno == EINTR) {
            continue;
        }
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorDigestReadFailed,
                              fieldPath,
                              @"The artifact could not be read for digest verification.");
    }

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    if (CC_SHA256_Final(digest, &context) != 1) {
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorDigestReadFailed,
                              fieldPath,
                              @"The artifact digest could not be finalized.");
    }

    NSString *digestString = PXArtifactHexDigest(digest);
    if (digestString.length != CC_SHA256_DIGEST_LENGTH * 2) {
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorDigestReadFailed,
                              fieldPath,
                              @"The artifact digest result is invalid.");
    }
    if (digestOut) {
        *digestOut = digestString;
    }
    return YES;
}

static BOOL PXArtifactVerifyDeclaration(
    PXBackupArtifactDeclaration *declaration,
    int rootDescriptor,
    NSString *canonicalRoot,
    NSString **canonicalPathOut,
    NSString **actualDigestOut,
    uint64_t *actualSizeOut,
    NSError **error) {
    if (canonicalPathOut) {
        *canonicalPathOut = nil;
    }
    if (actualDigestOut) {
        *actualDigestOut = nil;
    }
    if (actualSizeOut) {
        *actualSizeOut = 0;
    }

    NSString *entryPath = PXArtifactIndexedPath(@"$.artifacts",
                                                 declaration.originalIndex);
    NSString *namePath = PXArtifactFieldPath(entryPath, @"name");
    NSString *sizePath = PXArtifactFieldPath(entryPath, @"size");
    NSString *digestPath = PXArtifactFieldPath(entryPath, @"sha256");
    NSString *protectionPath = PXArtifactFieldPath(
        PXArtifactFieldPath(entryPath, @"policy"), @"dataProtection");

    int fileDescriptor = -1;
    if (!PXArtifactOpenRelativeFile(rootDescriptor,
                                    declaration.name,
                                    namePath,
                                    &fileDescriptor,
                                    error)) {
        return NO;
    }

    struct stat beforeStatus;
    if (fstat(fileDescriptor, &beforeStatus) != 0) {
        close(fileDescriptor);
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
                              namePath,
                              @"The artifact could not be inspected.");
    }
    if (!S_ISREG(beforeStatus.st_mode)) {
        close(fileDescriptor);
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorNotRegularFile,
                              namePath,
                              @"The artifact must be a regular file.");
    }
    if (beforeStatus.st_size < 0 ||
        (uint64_t)beforeStatus.st_size != declaration.expectedSize) {
        close(fileDescriptor);
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorSizeMismatch,
                              sizePath,
                              @"The artifact size does not match the manifest.");
    }

    if (declaration.requiresCompleteProtection &&
        !PXVerifyCompleteFileProtectionOnDescriptor(fileDescriptor, NULL)) {
        close(fileDescriptor);
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorProtectionInvalid,
                              protectionPath,
                              @"The artifact protection policy is invalid.");
    }

    NSString *actualDigest = nil;
    if (!PXArtifactHashDescriptor(fileDescriptor,
                                  &actualDigest,
                                  error,
                                  digestPath)) {
        close(fileDescriptor);
        return NO;
    }

    struct stat afterStatus;
    BOOL finalProtectionValid =
        !declaration.requiresCompleteProtection ||
        PXVerifyCompleteFileProtectionOnDescriptor(fileDescriptor, NULL);
    if (fstat(fileDescriptor, &afterStatus) != 0 || !finalProtectionValid) {
        close(fileDescriptor);
        return PXArtifactFail(error,
                              declaration.requiresCompleteProtection
                                  ? PXBackupArtifactVerifierErrorProtectionInvalid
                                  : PXBackupArtifactVerifierErrorFilesystemInspectionFailed,
                              declaration.requiresCompleteProtection
                                  ? protectionPath : namePath,
                              declaration.requiresCompleteProtection
                                  ? @"The artifact protection policy is invalid."
                                  : @"The artifact could not be inspected after verification.");
    }
    close(fileDescriptor);

    if (!PXArtifactStatIdentityIsStable(&beforeStatus, &afterStatus)) {
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorFilesystemChanged,
                              namePath,
                              @"The artifact changed during verification.");
    }
    if (![actualDigest isEqualToString:declaration.expectedDigest]) {
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorDigestMismatch,
                              digestPath,
                              @"The artifact digest does not match the manifest.");
    }

    NSString *canonicalPath = [[canonicalRoot stringByAppendingString:@"/"]
        stringByAppendingString:declaration.name];
    if (!PXArtifactCanonicalPathIsWithinRoot(canonicalRoot, canonicalPath)) {
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorUnsafeRelativePath,
                              namePath,
                              @"The artifact path escapes the canonical backup directory.");
    }

    if (canonicalPathOut) {
        *canonicalPathOut = canonicalPath;
    }
    if (actualDigestOut) {
        *actualDigestOut = actualDigest;
    }
    if (actualSizeOut) {
        *actualSizeOut = (uint64_t)afterStatus.st_size;
    }
    return YES;
}

static BOOL PXArtifactAddRequiredReference(
    id value,
    NSString *fieldPath,
    NSDictionary<NSString *, PXBackupArtifactDeclaration *> *declarationsByName,
    NSMutableSet<NSString *> *referencedNames,
    NSString **acceptedNameOut,
    NSError **error) {
    if (acceptedNameOut) {
        *acceptedNameOut = nil;
    }
    if (!PXArtifactRelativeNameIsSafe(value)) {
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorUnsafeRelativePath,
                              fieldPath,
                              @"The artifact reference must be a safe relative name.");
    }

    NSString *name = (NSString *)value;
    if ([referencedNames containsObject:name]) {
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorInvalidReference,
                              fieldPath,
                              @"An artifact is referenced by more than one Restore component.");
    }
    if (!declarationsByName[name]) {
        return PXArtifactFail(error,
                              PXBackupArtifactVerifierErrorMissingArtifact,
                              fieldPath,
                              @"The referenced artifact is not declared.");
    }

    [referencedNames addObject:name];
    if (acceptedNameOut) {
        *acceptedNameOut = name;
    }
    return YES;
}

@implementation PXBackupArtifactVerifier

+ (PXVerifiedBackupArtifactSet *)verifiedArtifactsForManifest:(NSDictionary *)manifest
                                              backupDirectory:(NSString *)backupDirectory
                                                        error:(NSError **)error {
    if (error) {
        *error = nil;
    }

    if (![manifest isKindOfClass:[NSDictionary class]]) {
        PXArtifactFail(error,
                       PXBackupArtifactVerifierErrorInvalidInput,
                       @"$",
                       @"The manifest input must be a dictionary.");
        return nil;
    }
    if (!PXArtifactBackupDirectoryStringIsValid(backupDirectory)) {
        PXArtifactFail(error,
                       PXBackupArtifactVerifierErrorInvalidInput,
                       @"$",
                       @"The backup directory input is invalid.");
        return nil;
    }

    id artifactsValue = manifest[@"artifacts"];
    if (![artifactsValue isKindOfClass:[NSArray class]]) {
        PXArtifactFail(error,
                       PXBackupArtifactVerifierErrorInvalidInput,
                       @"$.artifacts",
                       @"The artifacts section must be an array.");
        return nil;
    }

    NSArray *artifactEntries = (NSArray *)artifactsValue;
    NSDictionary *schema = [manifest[@"schema"] isKindOfClass:[NSDictionary class]]
        ? manifest[@"schema"] : nil;
    uint64_t schemaRevision = 0;
    if (!schema ||
        !PXArtifactReadUnsignedIntegral(schema[@"revision"], 2, &schemaRevision) ||
        (schemaRevision != 1 && schemaRevision != 2)) {
        PXArtifactFail(error,
                       PXBackupArtifactVerifierErrorInconsistentManifest,
                       @"$.schema.revision",
                       @"The manifest schema revision is invalid.");
        return nil;
    }
    NSMutableArray<PXBackupArtifactDeclaration *> *declarations =
        [NSMutableArray arrayWithCapacity:artifactEntries.count];
    NSMutableDictionary<NSString *, PXBackupArtifactDeclaration *>
        *declarationsByName = [NSMutableDictionary dictionary];

    uint64_t declaredSizeSum = 0;
    BOOL declaredSizeOverflow = NO;
    uint64_t maximumFileSize = (uint64_t)LLONG_MAX;

    for (NSUInteger index = 0; index < artifactEntries.count; index++) {
        NSString *entryPath = PXArtifactIndexedPath(@"$.artifacts", index);
        id entryValue = artifactEntries[index];
        if (![entryValue isKindOfClass:[NSDictionary class]]) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorInvalidInput,
                           entryPath,
                           @"Each artifact declaration must be a dictionary.");
            return nil;
        }

        NSDictionary *entry = (NSDictionary *)entryValue;
        NSString *namePath = PXArtifactFieldPath(entryPath, @"name");
        id nameValue = entry[@"name"];
        if (!PXArtifactRelativeNameIsSafe(nameValue)) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorUnsafeRelativePath,
                           namePath,
                           @"The artifact name must be a safe relative path.");
            return nil;
        }
        NSString *name = (NSString *)nameValue;
        if (declarationsByName[name]) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorInconsistentManifest,
                           namePath,
                           @"The manifest contains a duplicate artifact declaration.");
            return nil;
        }

        NSString *sizePath = PXArtifactFieldPath(entryPath, @"size");
        uint64_t expectedSize = 0;
        if (!PXArtifactReadUnsignedIntegral(entry[@"size"],
                                            maximumFileSize,
                                            &expectedSize)) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorInvalidInput,
                           sizePath,
                           @"The artifact size must be a nonnegative integral value.");
            return nil;
        }

        NSString *digestPath = PXArtifactFieldPath(entryPath, @"sha256");
        id digestValue = entry[@"sha256"];
        if (!PXArtifactDigestIsCompleteLowercaseSHA256(digestValue)) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorInvalidDigest,
                           digestPath,
                           @"The artifact digest must be a complete lowercase SHA-256 value.");
            return nil;
        }

        NSDictionary *policy =
            [entry[@"policy"] isKindOfClass:[NSDictionary class]]
                ? entry[@"policy"] : nil;
        BOOL requiresCompleteProtection = schemaRevision == 2 &&
            [policy[@"kind"] isEqualToString:@"keychain"];
        if (schemaRevision == 2 &&
            ((!requiresCompleteProtection &&
              ![policy[@"dataProtection"] isEqualToString:@"unspecified"]) ||
             (requiresCompleteProtection &&
              (![policy[@"dataProtection"] isEqualToString:@"complete"] ||
               ![policy[@"posixMode"] isEqualToString:@"0600"])))) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorInconsistentManifest,
                           PXArtifactFieldPath(entryPath, @"policy"),
                           @"The artifact protection declaration is invalid.");
            return nil;
        }
        PXBackupArtifactDeclaration *declaration =
            [[PXBackupArtifactDeclaration alloc]
                initWithName:name
                expectedSize:expectedSize
                expectedDigest:(NSString *)digestValue
                originalIndex:index
                requiresCompleteProtection:requiresCompleteProtection];
        [declarations addObject:declaration];
        declarationsByName[name] = declaration;

        if (UINT64_MAX - declaredSizeSum < expectedSize) {
            declaredSizeOverflow = YES;
        } else if (!declaredSizeOverflow) {
            declaredSizeSum += expectedSize;
        }
    }

    NSMutableSet<NSString *> *referencedNames = [NSMutableSet set];
    NSString *dataArchiveName = nil;

    id dataValue = manifest[@"data"];
    if (![dataValue isKindOfClass:[NSDictionary class]]) {
        PXArtifactFail(error,
                       PXBackupArtifactVerifierErrorInvalidInput,
                       @"$.data",
                       @"The data section must be a dictionary.");
        return nil;
    }
    if (!PXArtifactAddRequiredReference(((NSDictionary *)dataValue)[@"archive"],
                                        @"$.data.archive",
                                        declarationsByName,
                                        referencedNames,
                                        &dataArchiveName,
                                        error)) {
        return nil;
    }

    id appGroupsValue = manifest[@"appGroups"];
    if (![appGroupsValue isKindOfClass:[NSArray class]]) {
        PXArtifactFail(error,
                       PXBackupArtifactVerifierErrorInvalidInput,
                       @"$.appGroups",
                       @"The App Groups section must be an array.");
        return nil;
    }
    NSArray *appGroups = (NSArray *)appGroupsValue;
    for (NSUInteger index = 0; index < appGroups.count; index++) {
        NSString *entryPath = PXArtifactIndexedPath(@"$.appGroups", index);
        id entryValue = appGroups[index];
        if (![entryValue isKindOfClass:[NSDictionary class]]) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorInvalidInput,
                           entryPath,
                           @"Each App Group entry must be a dictionary.");
            return nil;
        }
        if (!PXArtifactAddRequiredReference(((NSDictionary *)entryValue)[@"archive"],
                                            PXArtifactFieldPath(entryPath, @"archive"),
                                            declarationsByName,
                                            referencedNames,
                                            NULL,
                                            error)) {
            return nil;
        }
    }

    NSArray<NSString *> *singleArchiveSections = @[
        @"preferences",
        @"keychain",
        @"profileAppData",
        @"globalSafari"
    ];
    for (NSString *sectionName in singleArchiveSections) {
        NSString *sectionPath = PXArtifactFieldPath(@"$", sectionName);
        id sectionValue = manifest[sectionName];
        if (![sectionValue isKindOfClass:[NSDictionary class]]) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorInvalidInput,
                           sectionPath,
                           @"The Restore component section must be a dictionary.");
            return nil;
        }
        NSDictionary *section = (NSDictionary *)sectionValue;
        BOOL included = NO;
        if (!PXArtifactReadExactBoolean(section[@"included"], &included)) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorInvalidInput,
                           PXArtifactFieldPath(sectionPath, @"included"),
                           @"The Restore component inclusion flag must be Boolean.");
            return nil;
        }
        if (included &&
            !PXArtifactAddRequiredReference(section[@"archive"],
                                            PXArtifactFieldPath(sectionPath, @"archive"),
                                            declarationsByName,
                                            referencedNames,
                                            NULL,
                                            error)) {
            return nil;
        }
    }

    id systemGlobalValue = manifest[@"systemGlobalLibrary"];
    if (systemGlobalValue) {
        if (![systemGlobalValue isKindOfClass:[NSDictionary class]]) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorInvalidInput,
                           @"$.systemGlobalLibrary",
                           @"The system-global section must be a dictionary.");
            return nil;
        }
        NSDictionary *systemGlobal = (NSDictionary *)systemGlobalValue;
        BOOL included = NO;
        if (!PXArtifactReadExactBoolean(systemGlobal[@"included"], &included)) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorInvalidInput,
                           @"$.systemGlobalLibrary.included",
                           @"The system-global inclusion flag must be Boolean.");
            return nil;
        }
        if (included) {
            id itemsValue = systemGlobal[@"items"];
            if (![itemsValue isKindOfClass:[NSArray class]]) {
                PXArtifactFail(error,
                               PXBackupArtifactVerifierErrorInvalidInput,
                               @"$.systemGlobalLibrary.items",
                               @"The system-global items field must be an array.");
                return nil;
            }
            NSArray *items = (NSArray *)itemsValue;
            for (NSUInteger index = 0; index < items.count; index++) {
                NSString *entryPath = PXArtifactIndexedPath(
                    @"$.systemGlobalLibrary.items", index);
                id entryValue = items[index];
                if (![entryValue isKindOfClass:[NSDictionary class]]) {
                    PXArtifactFail(error,
                                   PXBackupArtifactVerifierErrorInvalidInput,
                                   entryPath,
                                   @"Each system-global item must be a dictionary.");
                    return nil;
                }
                if (!PXArtifactAddRequiredReference(
                        ((NSDictionary *)entryValue)[@"archive"],
                        PXArtifactFieldPath(entryPath, @"archive"),
                        declarationsByName,
                        referencedNames,
                        NULL,
                        error)) {
                    return nil;
                }
            }
        }
    }

    id sharedDBValue = manifest[@"sharedSystemDB"];
    if (sharedDBValue) {
        if (![sharedDBValue isKindOfClass:[NSDictionary class]]) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorInvalidInput,
                           @"$.sharedSystemDB",
                           @"The shared-system-DB section must be a dictionary.");
            return nil;
        }
        NSDictionary *sharedDB = (NSDictionary *)sharedDBValue;
        BOOL included = NO;
        if (!PXArtifactReadExactBoolean(sharedDB[@"included"], &included)) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorInvalidInput,
                           @"$.sharedSystemDB.included",
                           @"The shared-system-DB inclusion flag must be Boolean.");
            return nil;
        }
        if (included) {
            id filesValue = sharedDB[@"files"];
            if (![filesValue isKindOfClass:[NSArray class]]) {
                PXArtifactFail(error,
                               PXBackupArtifactVerifierErrorInvalidInput,
                               @"$.sharedSystemDB.files",
                               @"The shared-system-DB files field must be an array.");
                return nil;
            }
            NSArray *files = (NSArray *)filesValue;
            for (NSUInteger index = 0; index < files.count; index++) {
                NSString *entryPath = PXArtifactIndexedPath(
                    @"$.sharedSystemDB.files", index);
                id entryValue = files[index];
                if (![entryValue isKindOfClass:[NSDictionary class]]) {
                    PXArtifactFail(error,
                                   PXBackupArtifactVerifierErrorInvalidInput,
                                   entryPath,
                                   @"Each shared-system-DB file entry must be a dictionary.");
                    return nil;
                }
                if (!PXArtifactAddRequiredReference(
                        ((NSDictionary *)entryValue)[@"archive"],
                        PXArtifactFieldPath(entryPath, @"archive"),
                        declarationsByName,
                        referencedNames,
                        NULL,
                        error)) {
                    return nil;
                }
            }
        }
    }

    NSArray<PXBackupArtifactDeclaration *> *sortedDeclarations =
        [declarations sortedArrayUsingComparator:
            ^NSComparisonResult(PXBackupArtifactDeclaration *left,
                                PXBackupArtifactDeclaration *right) {
                return [left.name compare:right.name];
            }];

    NSString *canonicalRoot = nil;
    int rootDescriptor = -1;
    if (!PXArtifactOpenCanonicalBackupRoot(backupDirectory,
                                           &canonicalRoot,
                                           &rootDescriptor,
                                           error)) {
        return nil;
    }

    NSMutableDictionary<NSString *, NSString *> *canonicalPathsByName =
        [NSMutableDictionary dictionaryWithCapacity:sortedDeclarations.count];
    NSMutableDictionary<NSString *, NSString *> *actualDigestsByName =
        [NSMutableDictionary dictionaryWithCapacity:sortedDeclarations.count];
    uint64_t actualSizeSum = 0;
    BOOL actualSizeOverflow = NO;

    for (PXBackupArtifactDeclaration *declaration in sortedDeclarations) {
        NSString *canonicalPath = nil;
        NSString *actualDigest = nil;
        uint64_t actualSize = 0;
        if (!PXArtifactVerifyDeclaration(declaration,
                                         rootDescriptor,
                                         canonicalRoot,
                                         &canonicalPath,
                                         &actualDigest,
                                         &actualSize,
                                         error)) {
            close(rootDescriptor);
            return nil;
        }
        canonicalPathsByName[declaration.name] = canonicalPath;
        actualDigestsByName[declaration.name] = actualDigest;
        if (UINT64_MAX - actualSizeSum < actualSize) {
            actualSizeOverflow = YES;
        } else if (!actualSizeOverflow) {
            actualSizeSum += actualSize;
        }
    }
    close(rootDescriptor);

    id totalSizeValue = manifest[@"totalSize"];
    if (totalSizeValue) {
        uint64_t manifestTotalSize = 0;
        if (!PXArtifactReadUnsignedIntegral(totalSizeValue,
                                            UINT64_MAX,
                                            &manifestTotalSize) ||
            declaredSizeOverflow ||
            actualSizeOverflow ||
            manifestTotalSize != declaredSizeSum ||
            manifestTotalSize != actualSizeSum) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorInconsistentManifest,
                           @"$.totalSize",
                           @"The aggregate artifact size is inconsistent.");
            return nil;
        }
    }

    id archiveChecksumValue = manifest[@"archiveChecksum"];
    if (archiveChecksumValue) {
        if (!PXArtifactDigestIsCompleteLowercaseSHA256(archiveChecksumValue)) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorInconsistentManifest,
                           @"$.archiveChecksum",
                           @"The aggregate archive checksum is invalid.");
            return nil;
        }
        PXBackupArtifactDeclaration *dataDeclaration =
            declarationsByName[dataArchiveName];
        NSString *actualDataDigest = actualDigestsByName[dataArchiveName];
        if (!dataDeclaration ||
            !actualDataDigest ||
            ![(NSString *)archiveChecksumValue
                isEqualToString:dataDeclaration.expectedDigest] ||
            ![(NSString *)archiveChecksumValue
                isEqualToString:actualDataDigest]) {
            PXArtifactFail(error,
                           PXBackupArtifactVerifierErrorInconsistentManifest,
                           @"$.archiveChecksum",
                           @"The aggregate archive checksum is inconsistent.");
            return nil;
        }
    }

    return [[PXVerifiedBackupArtifactSet alloc]
        initWithCanonicalPathsByName:canonicalPathsByName];
}

@end
