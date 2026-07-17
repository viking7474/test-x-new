#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import "PXBackupArchiveValidator.h"
#import "PXBackupArtifactVerifier.h"

#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

@interface PXVerifiedBackupArtifactSet ()
@property (nonatomic, copy, readwrite) NSArray<NSString *> *artifactNames;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSString *> *canonicalPathsByName;
- (instancetype)initWithCanonicalPathsByName:(NSDictionary<NSString *, NSString *> *)paths;
@end

@implementation PXVerifiedBackupArtifactSet

- (instancetype)initWithCanonicalPathsByName:(NSDictionary<NSString *, NSString *> *)paths {
    self = [super init];
    if (self) {
        _canonicalPathsByName = [paths copy];
        _artifactNames = [[_canonicalPathsByName allKeys] sortedArrayUsingSelector:@selector(compare:)];
    }
    return self;
}

- (NSString *)pathForArtifactName:(NSString *)artifactName {
    if (![artifactName isKindOfClass:[NSString class]] || artifactName.length == 0) {
        return nil;
    }
    id value = self.canonicalPathsByName[artifactName];
    return [value isKindOfClass:[NSString class]] && [value length] > 0 ? value : nil;
}

- (id)copyWithZone:(NSZone *)zone {
    (void)zone;
    return self;
}

@end

static NSString *PXFixtureSHA256ForData(NSData *data) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    static const char hex[] = "0123456789abcdef";
    char output[CC_SHA256_DIGEST_LENGTH * 2 + 1];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        output[index * 2] = hex[(digest[index] >> 4) & 0x0f];
        output[index * 2 + 1] = hex[digest[index] & 0x0f];
    }
    output[CC_SHA256_DIGEST_LENGTH * 2] = '\0';
    return [NSString stringWithUTF8String:output];
}

static NSString *PXFixtureSHA256ForFile(NSString *path, NSString **message) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) {
        if (message) {
            *message = @"regular file could not be opened";
        }
        return nil;
    }
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    @try {
        for (;;) {
            NSData *chunk = [handle readDataOfLength:64 * 1024];
            if (chunk.length == 0) {
                break;
            }
            CC_SHA256_Update(&context, chunk.bytes, (CC_LONG)chunk.length);
        }
        [handle closeFile];
    } @catch (__unused NSException *exception) {
        @try {
            [handle closeFile];
        } @catch (__unused NSException *closeException) {
        }
        if (message) {
            *message = @"regular file could not be read";
        }
        return nil;
    }
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    NSData *digestData = [NSData dataWithBytes:digest length:sizeof(digest)];
    NSMutableString *result = [NSMutableString stringWithCapacity:64];
    const unsigned char *bytes = digestData.bytes;
    for (NSUInteger index = 0; index < digestData.length; index++) {
        [result appendFormat:@"%02x", bytes[index]];
    }
    return result;
}

static BOOL PXFixtureStringHasNUL(NSString *value) {
    unichar nul = 0;
    NSString *nulString = [NSString stringWithCharacters:&nul length:1];
    return [value rangeOfString:nulString].location != NSNotFound;
}

static BOOL PXFixtureSafeString(id value) {
    return [value isKindOfClass:[NSString class]] &&
           [(NSString *)value length] > 0 &&
           !PXFixtureStringHasNUL((NSString *)value);
}

static BOOL PXFixtureExactInteger(id value, uint64_t *number) {
    if (![value isKindOfClass:[NSNumber class]] ||
        CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) {
        return NO;
    }
    const char *type = [(NSNumber *)value objCType];
    if (!type || type[0] == '\0' || type[1] != '\0') {
        return NO;
    }
    switch (type[0]) {
        case 'c':
        case 's':
        case 'i':
        case 'l':
        case 'q': {
            long long signedValue = [(NSNumber *)value longLongValue];
            if (signedValue < 0) {
                return NO;
            }
            if (number) {
                *number = (uint64_t)signedValue;
            }
            return YES;
        }
        case 'C':
        case 'S':
        case 'I':
        case 'L':
        case 'Q':
            if (number) {
                *number = [(NSNumber *)value unsignedLongLongValue];
            }
            return YES;
        default:
            return NO;
    }
}

static BOOL PXFixtureDigestValid(id value) {
    if (![value isKindOfClass:[NSString class]] || [(NSString *)value length] != 64) {
        return NO;
    }
    NSString *digest = value;
    for (NSUInteger index = 0; index < digest.length; index++) {
        unichar character = [digest characterAtIndex:index];
        if (!((character >= '0' && character <= '9') ||
              (character >= 'a' && character <= 'f'))) {
            return NO;
        }
    }
    return YES;
}

static BOOL PXFixtureExactKeys(NSDictionary *dictionary, NSArray<NSString *> *keys) {
    NSSet *actual = [NSSet setWithArray:dictionary.allKeys];
    NSSet *expected = [NSSet setWithArray:keys];
    return [actual isEqualToSet:expected];
}

static NSString *PXFixtureCanonicalPath(NSString *path) {
    const char *raw = path.fileSystemRepresentation;
    if (!raw) {
        return nil;
    }
    char resolved[PATH_MAX];
    if (!realpath(raw, resolved)) {
        return nil;
    }
    return [[NSFileManager defaultManager]
        stringWithFileSystemRepresentation:resolved
                                    length:strlen(resolved)];
}

static NSString *PXFixtureObjectType(mode_t mode) {
    if (S_ISREG(mode)) {
        return @"file";
    }
    if (S_ISDIR(mode)) {
        return @"directory";
    }
    if (S_ISLNK(mode)) {
        return @"symlink";
    }
    if (S_ISFIFO(mode)) {
        return @"fifo";
    }
    if (S_ISCHR(mode)) {
        return @"character-device";
    }
    if (S_ISBLK(mode)) {
        return @"block-device";
    }
    if (S_ISSOCK(mode)) {
        return @"socket";
    }
    return @"other";
}

static NSDictionary *PXFixtureStatRecord(NSString *root,
                                         NSString *relativePath,
                                         NSString **message) {
    NSString *fullPath = [relativePath isEqualToString:@"."]
        ? root
        : [root stringByAppendingPathComponent:relativePath];
    struct stat status;
    if (lstat(fullPath.fileSystemRepresentation, &status) != 0) {
        if (message) {
            *message = @"snapshot metadata could not be read";
        }
        return nil;
    }
#if defined(__APPLE__)
    int64_t mtimeSec = status.st_mtimespec.tv_sec;
    int64_t mtimeNSec = status.st_mtimespec.tv_nsec;
    int64_t ctimeSec = status.st_ctimespec.tv_sec;
    int64_t ctimeNSec = status.st_ctimespec.tv_nsec;
#else
    int64_t mtimeSec = status.st_mtim.tv_sec;
    int64_t mtimeNSec = status.st_mtim.tv_nsec;
    int64_t ctimeSec = status.st_ctim.tv_sec;
    int64_t ctimeNSec = status.st_ctim.tv_nsec;
#endif
    NSMutableDictionary *record = [@{
        @"type": PXFixtureObjectType(status.st_mode),
        @"mode": @((uint64_t)status.st_mode),
        @"uid": @((uint64_t)status.st_uid),
        @"gid": @((uint64_t)status.st_gid),
        @"nlink": @((uint64_t)status.st_nlink),
        @"device": @((uint64_t)status.st_dev),
        @"inode": @((uint64_t)status.st_ino),
        @"size": @((int64_t)status.st_size),
        @"mtimeSec": @(mtimeSec),
        @"mtimeNSec": @(mtimeNSec),
        @"ctimeSec": @(ctimeSec),
        @"ctimeNSec": @(ctimeNSec),
    } mutableCopy];
    if (S_ISREG(status.st_mode)) {
        NSString *digest = PXFixtureSHA256ForFile(fullPath, message);
        if (!digest) {
            return nil;
        }
        record[@"sha256"] = digest;
    }
    return [record copy];
}

static NSDictionary *PXFixtureSnapshot(NSString *root, NSString **message) {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [manager enumeratorAtPath:root];
    if (!enumerator) {
        if (message) {
            *message = @"fixture root could not be enumerated";
        }
        return nil;
    }
    NSMutableArray<NSString *> *paths = [NSMutableArray arrayWithObject:@"."];
    for (id value in enumerator) {
        if (![value isKindOfClass:[NSString class]]) {
            if (message) {
                *message = @"fixture root contained an invalid entry";
            }
            return nil;
        }
        [paths addObject:value];
    }
    [paths sortUsingSelector:@selector(compare:)];
    NSMutableDictionary *snapshot = [NSMutableDictionary dictionaryWithCapacity:paths.count];
    for (NSString *relativePath in paths) {
        NSDictionary *record = PXFixtureStatRecord(root, relativePath, message);
        if (!record) {
            return nil;
        }
        snapshot[relativePath] = record;
    }
    return [snapshot copy];
}

static BOOL PXFixtureCollectionMutationRejected(void (^operation)(void)) {
    @try {
        operation();
        return NO;
    } @catch (__unused NSException *exception) {
        return YES;
    }
}

static void PXFixtureAddFailure(NSMutableArray<NSDictionary *> *failures,
                                NSString *fixtureID,
                                NSString *assertion,
                                NSString *message) {
    [failures addObject:@{
        @"id": fixtureID ?: @"<suite>",
        @"assertion": assertion ?: @"assertion",
        @"message": message ?: @"failed",
    }];
}

static NSArray<NSDictionary *> *PXFixtureSortedFailures(NSArray<NSDictionary *> *failures) {
    return [failures sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left,
                                                                    NSDictionary *right) {
        NSComparisonResult idOrder = [left[@"id"] compare:right[@"id"]];
        if (idOrder != NSOrderedSame) {
            return idOrder;
        }
        NSComparisonResult assertionOrder = [left[@"assertion"] compare:right[@"assertion"]];
        if (assertionOrder != NSOrderedSame) {
            return assertionOrder;
        }
        return [left[@"message"] compare:right[@"message"]];
    }];
}

static BOOL PXFixtureErrorContainsToken(NSError *error, NSString *token) {
    if (![token isKindOfClass:[NSString class]] || token.length < 2) {
        return NO;
    }
    NSMutableArray<NSString *> *values = [NSMutableArray array];
    if ([error.domain isKindOfClass:[NSString class]]) {
        [values addObject:error.domain];
    }
    if ([error.localizedDescription isKindOfClass:[NSString class]]) {
        [values addObject:error.localizedDescription];
    }
    for (id value in error.userInfo.allValues) {
        if ([value isKindOfClass:[NSString class]]) {
            [values addObject:value];
        }
    }
    NSString *lowerToken = token.lowercaseString;
    for (NSString *value in values) {
        if ([value rangeOfString:token].location != NSNotFound ||
            [value.lowercaseString rangeOfString:lowerToken].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static BOOL PXFixtureArchiveNameSafe(NSString *name) {
    if (!PXFixtureSafeString(name) ||
        [name rangeOfString:@"/"].location != NSNotFound ||
        [name rangeOfString:@"\\"].location != NSNotFound ||
        [name isEqualToString:@"."] ||
        [name isEqualToString:@".."] ||
        [name hasPrefix:@"."]) {
        return NO;
    }
    return YES;
}

static BOOL PXFixtureValidateChecksumFile(NSString *root,
                                          NSSet<NSString *> *expectedNames,
                                          NSString **message) {
    NSString *path = [root stringByAppendingPathComponent:@"corpus.sha256"];
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:nil];
    NSString *text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    if (!text || [text rangeOfString:@"\r"].location != NSNotFound || ![text hasSuffix:@"\n"]) {
        if (message) {
            *message = @"checksum list encoding is invalid";
        }
        return NO;
    }
    NSArray<NSString *> *rawLines = [text componentsSeparatedByString:@"\n"];
    if (rawLines.count == 0 || ![[rawLines lastObject] isEqualToString:@""]) {
        if (message) {
            *message = @"checksum list terminator is invalid";
        }
        return NO;
    }
    NSArray<NSString *> *lines = [rawLines subarrayWithRange:NSMakeRange(0, rawLines.count - 1)];
    if (lines.count != expectedNames.count) {
        if (message) {
            *message = @"checksum list count is invalid";
        }
        return NO;
    }
    NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:lines.count];
    for (NSString *line in lines) {
        if (line.length < 67 || ![[line substringWithRange:NSMakeRange(64, 2)] isEqualToString:@"  "]) {
            if (message) {
                *message = @"checksum list row is invalid";
            }
            return NO;
        }
        NSString *digest = [line substringToIndex:64];
        NSString *name = [line substringFromIndex:66];
        if (!PXFixtureDigestValid(digest) || ![expectedNames containsObject:name]) {
            if (message) {
                *message = @"checksum list entry is invalid";
            }
            return NO;
        }
        NSString *actual = PXFixtureSHA256ForFile([root stringByAppendingPathComponent:name], message);
        if (!actual || ![actual isEqualToString:digest]) {
            if (message && !*message) {
                *message = @"checksum list digest mismatch";
            }
            return NO;
        }
        [names addObject:name];
    }
    NSArray<NSString *> *sorted = [names sortedArrayUsingSelector:@selector(compare:)];
    if (![names isEqualToArray:sorted] || [NSSet setWithArray:names].count != names.count) {
        if (message) {
            *message = @"checksum list ordering is invalid";
        }
        return NO;
    }
    return YES;
}

static NSArray<NSDictionary *> *PXFixtureLoadCases(NSString *metadataPath,
                                                    NSString **rootOut,
                                                    NSString **message) {
    NSString *canonicalMetadata = PXFixtureCanonicalPath(metadataPath);
    if (!canonicalMetadata) {
        if (message) {
            *message = @"metadata file is unavailable";
        }
        return nil;
    }
    NSString *root = [canonicalMetadata stringByDeletingLastPathComponent];
    if (![[canonicalMetadata lastPathComponent] isEqualToString:@"fixtures.json"]) {
        if (message) {
            *message = @"metadata file name is invalid";
        }
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:canonicalMetadata options:0 error:nil];
    if (!data || data.length == 0) {
        if (message) {
            *message = @"metadata file could not be read";
        }
        return nil;
    }
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![object isKindOfClass:[NSDictionary class]]) {
        if (message) {
            *message = @"metadata root is invalid";
        }
        return nil;
    }
    NSDictionary *metadata = object;
    NSArray *topKeys = @[@"schemaVersion", @"fixtureCount", @"acceptedCount", @"rejectedCount", @"cases"];
    if (!PXFixtureExactKeys(metadata, topKeys)) {
        if (message) {
            *message = @"metadata keys are invalid";
        }
        return nil;
    }
    uint64_t schemaVersion = 0;
    uint64_t fixtureCount = 0;
    uint64_t acceptedCount = 0;
    uint64_t rejectedCount = 0;
    if (!PXFixtureExactInteger(metadata[@"schemaVersion"], &schemaVersion) || schemaVersion != 1 ||
        !PXFixtureExactInteger(metadata[@"fixtureCount"], &fixtureCount) || fixtureCount != 86 ||
        !PXFixtureExactInteger(metadata[@"acceptedCount"], &acceptedCount) || acceptedCount != 20 ||
        !PXFixtureExactInteger(metadata[@"rejectedCount"], &rejectedCount) || rejectedCount != 66 ||
        ![metadata[@"cases"] isKindOfClass:[NSArray class]] ||
        [(NSArray *)metadata[@"cases"] count] != 86) {
        if (message) {
            *message = @"metadata counts are invalid";
        }
        return nil;
    }
    NSArray *cases = metadata[@"cases"];
    NSMutableSet<NSString *> *archiveNames = [NSMutableSet set];
    NSMutableSet<NSString *> *checksumNames = [NSMutableSet setWithObject:@"fixtures.json"];
    NSArray *commonKeys = @[@"id", @"archiveName", @"expectedDisposition", @"declaredSize",
                            @"declaredSHA256", @"forbiddenErrorFragments"];
    for (NSUInteger index = 0; index < cases.count; index++) {
        id caseObject = cases[index];
        if (![caseObject isKindOfClass:[NSDictionary class]]) {
            if (message) {
                *message = @"fixture case is invalid";
            }
            return nil;
        }
        NSDictionary *record = caseObject;
        NSString *expectedID = index < 20
            ? [NSString stringWithFormat:@"A%03lu", (unsigned long)(index + 1)]
            : [NSString stringWithFormat:@"R%03lu", (unsigned long)(index - 19)];
        NSString *fixtureID = record[@"id"];
        NSString *archiveName = record[@"archiveName"];
        NSString *disposition = record[@"expectedDisposition"];
        NSArray *extraKeys = [disposition isEqualToString:@"accepted"]
            ? @[@"expectedMemberCount", @"expectedRegularFileBytes"]
            : @[@"expectedErrorCode", @"expectedErrorFieldPath"];
        NSMutableArray *exactKeys = [commonKeys mutableCopy];
        [exactKeys addObjectsFromArray:extraKeys];
        if (!PXFixtureExactKeys(record, exactKeys) ||
            ![fixtureID isEqualToString:expectedID] ||
            !PXFixtureArchiveNameSafe(archiveName) ||
            ![archiveName isEqualToString:[fixtureID stringByAppendingString:@".tar.gz"]] ||
            [archiveNames containsObject:archiveName] ||
            !([disposition isEqualToString:@"accepted"] || [disposition isEqualToString:@"rejected"]) ||
            !PXFixtureDigestValid(record[@"declaredSHA256"])) {
            if (message) {
                *message = @"fixture case identity is invalid";
            }
            return nil;
        }
        uint64_t declaredSize = 0;
        if (!PXFixtureExactInteger(record[@"declaredSize"], &declaredSize)) {
            if (message) {
                *message = @"fixture declaration size is invalid";
            }
            return nil;
        }
        id fragmentsObject = record[@"forbiddenErrorFragments"];
        if (![fragmentsObject isKindOfClass:[NSArray class]]) {
            if (message) {
                *message = @"fixture privacy fragments are invalid";
            }
            return nil;
        }
        NSArray *fragments = fragmentsObject;
        for (id fragment in fragments) {
            if (![fragment isKindOfClass:[NSString class]] || [(NSString *)fragment length] < 2) {
                if (message) {
                    *message = @"fixture privacy fragment is invalid";
                }
                return nil;
            }
        }
        NSString *archivePath = [root stringByAppendingPathComponent:archiveName];
        struct stat archiveStatus;
        if (lstat(archivePath.fileSystemRepresentation, &archiveStatus) != 0 ||
            S_ISLNK(archiveStatus.st_mode) || !S_ISREG(archiveStatus.st_mode)) {
            if (message) {
                *message = @"fixture archive is not a regular file";
            }
            return nil;
        }
        if ([disposition isEqualToString:@"accepted"]) {
            uint64_t members = 0;
            uint64_t regularBytes = 0;
            if (!PXFixtureExactInteger(record[@"expectedMemberCount"], &members) ||
                !PXFixtureExactInteger(record[@"expectedRegularFileBytes"], &regularBytes)) {
                if (message) {
                    *message = @"accepted fixture expectation is invalid";
                }
                return nil;
            }
        } else {
            uint64_t code = 0;
            NSString *fieldPath = record[@"expectedErrorFieldPath"];
            if (!PXFixtureExactInteger(record[@"expectedErrorCode"], &code) ||
                code < 1 || code > 16 ||
                !PXFixtureSafeString(fieldPath) ||
                fragments.count == 0) {
                if (message) {
                    *message = @"rejected fixture expectation is invalid";
                }
                return nil;
            }
        }
        [archiveNames addObject:archiveName];
        [checksumNames addObject:archiveName];
    }
    if (![PXFixtureValidateChecksumFile(root, checksumNames, message)]) {
        return nil;
    }
    if (rootOut) {
        *rootOut = root;
    }
    return cases;
}

static NSDictionary *PXFixtureManifest(NSDictionary *record) {
    NSString *archiveName = record[@"archiveName"];
    return @{
        @"artifacts": @[
            @{
                @"name": archiveName,
                @"size": record[@"declaredSize"],
                @"sha256": record[@"declaredSHA256"],
            }
        ],
        @"data": @{
            @"archive": archiveName,
        },
        @"appGroups": @[],
        @"profileAppData": @{
            @"included": @NO,
        },
        @"globalSafari": @{
            @"included": @NO,
        },
    };
}

static NSArray<NSString *> *PXFixturePrivacyTokens(NSDictionary *record,
                                                   NSString *root,
                                                   NSString *archivePath,
                                                   NSString *actualDigest,
                                                   uint64_t actualSize) {
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    NSArray *candidates = @[
        root ?: @"",
        archivePath ?: @"",
        record[@"archiveName"] ?: @"",
        record[@"declaredSHA256"] ?: @"",
        actualDigest ?: @"",
        [record[@"declaredSize"] description] ?: @"",
        [NSString stringWithFormat:@"%llu", (unsigned long long)actualSize],
    ];
    for (NSString *candidate in candidates) {
        if ([candidate isKindOfClass:[NSString class]] && candidate.length >= 2) {
            [tokens addObject:candidate];
        }
    }
    for (id fragment in record[@"forbiddenErrorFragments"]) {
        if ([fragment isKindOfClass:[NSString class]] && [fragment length] >= 2) {
            [tokens addObject:fragment];
        }
    }
    return tokens;
}

static void PXFixtureAssertAccepted(NSDictionary *record,
                                    PXValidatedBackupArchiveSet *result,
                                    NSError *error,
                                    NSMutableArray<NSDictionary *> *failures) {
    NSString *fixtureID = record[@"id"];
    NSString *archiveName = record[@"archiveName"];
    if (!result) {
        PXFixtureAddFailure(failures, fixtureID, @"accepted.result", @"result was nil");
        return;
    }
    if (error) {
        PXFixtureAddFailure(failures, fixtureID, @"accepted.error", @"unexpected error");
    }
    if (![result.archiveNames isEqualToArray:@[archiveName]]) {
        PXFixtureAddFailure(failures, fixtureID, @"accepted.archiveNames", @"archive names differed");
    }
    if (![result containsArchiveName:archiveName]) {
        PXFixtureAddFailure(failures, fixtureID, @"accepted.containsKnown", @"known archive was absent");
    }
    if ([result containsArchiveName:@"unknown.tar.gz"]) {
        PXFixtureAddFailure(failures, fixtureID, @"accepted.containsUnknown", @"unknown archive was present");
    }
    if (![result.memberCountsByArchiveName[archiveName] isEqual:record[@"expectedMemberCount"]]) {
        PXFixtureAddFailure(failures, fixtureID, @"accepted.memberCount", @"member count differed");
    }
    if (![result.regularFileBytesByArchiveName[archiveName] isEqual:record[@"expectedRegularFileBytes"]]) {
        PXFixtureAddFailure(failures, fixtureID, @"accepted.regularBytes", @"regular byte count differed");
    }
    if ([result copyWithZone:nil] != result) {
        PXFixtureAddFailure(failures, fixtureID, @"accepted.copyIdentity", @"copy did not preserve identity");
    }
    if (!PXFixtureCollectionMutationRejected(^{
            [(NSMutableArray *)result.archiveNames addObject:@"mutation.tar.gz"];
        })) {
        PXFixtureAddFailure(failures, fixtureID, @"accepted.archiveNamesImmutable", @"archive names were mutable");
    }
    if (!PXFixtureCollectionMutationRejected(^{
            [(NSMutableDictionary *)result.memberCountsByArchiveName setObject:@0 forKey:@"mutation.tar.gz"];
        })) {
        PXFixtureAddFailure(failures, fixtureID, @"accepted.memberCountsImmutable", @"member counts were mutable");
    }
    if (!PXFixtureCollectionMutationRejected(^{
            [(NSMutableDictionary *)result.regularFileBytesByArchiveName setObject:@0 forKey:@"mutation.tar.gz"];
        })) {
        PXFixtureAddFailure(failures, fixtureID, @"accepted.regularBytesImmutable", @"regular byte counts were mutable");
    }
}

static void PXFixtureAssertRejected(NSDictionary *record,
                                    PXValidatedBackupArchiveSet *result,
                                    NSError *error,
                                    NSString *root,
                                    NSString *archivePath,
                                    NSString *actualDigest,
                                    uint64_t actualSize,
                                    NSMutableArray<NSDictionary *> *failures) {
    NSString *fixtureID = record[@"id"];
    if (result) {
        PXFixtureAddFailure(failures, fixtureID, @"rejected.result", @"result was non-nil");
    }
    if (!error) {
        PXFixtureAddFailure(failures, fixtureID, @"rejected.error", @"error was nil");
        return;
    }
    if (![error.domain isEqualToString:PXBackupArchiveValidatorErrorDomain]) {
        PXFixtureAddFailure(failures, fixtureID, @"rejected.domain", @"error domain differed");
    }
    if (error.code != [record[@"expectedErrorCode"] integerValue]) {
        PXFixtureAddFailure(failures, fixtureID, @"rejected.code", @"error code differed");
    }
    NSString *fieldPath = error.userInfo[PXBackupArchiveValidatorErrorFieldPathKey];
    if (![fieldPath isEqualToString:record[@"expectedErrorFieldPath"]]) {
        PXFixtureAddFailure(failures, fixtureID, @"rejected.fieldPath", @"error field differed");
    }
    NSSet *actualKeys = [NSSet setWithArray:error.userInfo.allKeys];
    NSSet *expectedKeys = [NSSet setWithArray:@[
        NSLocalizedDescriptionKey,
        PXBackupArchiveValidatorErrorFieldPathKey,
    ]];
    if (![actualKeys isEqualToSet:expectedKeys]) {
        PXFixtureAddFailure(failures, fixtureID, @"rejected.userInfoKeys", @"error userInfo keys differed");
    }
    if (![error.localizedDescription isKindOfClass:[NSString class]] || error.localizedDescription.length == 0) {
        PXFixtureAddFailure(failures, fixtureID, @"rejected.description", @"error description was invalid");
    }
    NSArray<NSString *> *tokens = PXFixturePrivacyTokens(record, root, archivePath, actualDigest, actualSize);
    for (NSString *token in tokens) {
        if (PXFixtureErrorContainsToken(error, token)) {
            PXFixtureAddFailure(failures, fixtureID, @"rejected.privacy", @"error exposed a forbidden value");
            break;
        }
    }
}

static int PXFixtureRun(NSString *metadataPath) {
    NSString *metadataMessage = nil;
    NSString *fixtureRoot = nil;
    NSArray<NSDictionary *> *cases = PXFixtureLoadCases(metadataPath, &fixtureRoot, &metadataMessage);
    if (!cases || !fixtureRoot) {
        fprintf(stderr, "archive fixtures: metadata error: %s\n",
                (metadataMessage ?: @"invalid corpus").UTF8String);
        return 2;
    }

    NSString *snapshotMessage = nil;
    NSDictionary *baselineSnapshot = PXFixtureSnapshot(fixtureRoot, &snapshotMessage);
    if (!baselineSnapshot) {
        fprintf(stderr, "archive fixtures: corpus error: %s\n",
                (snapshotMessage ?: @"snapshot failed").UTF8String);
        return 2;
    }

    NSMutableArray<NSDictionary *> *failures = [NSMutableArray array];
    NSUInteger passed = 0;
    for (NSDictionary *record in cases) {
        NSString *fixtureID = record[@"id"];
        NSString *archiveName = record[@"archiveName"];
        NSString *archivePath = [fixtureRoot stringByAppendingPathComponent:archiveName];
        struct stat status;
        if (lstat(archivePath.fileSystemRepresentation, &status) != 0 || !S_ISREG(status.st_mode)) {
            fprintf(stderr, "archive fixtures: corpus error: archive metadata changed\n");
            return 2;
        }
        NSString *digestMessage = nil;
        NSString *actualDigest = PXFixtureSHA256ForFile(archivePath, &digestMessage);
        if (!actualDigest) {
            fprintf(stderr, "archive fixtures: corpus error: archive digest failed\n");
            return 2;
        }
        NSString *canonicalArchive = PXFixtureCanonicalPath(archivePath);
        if (!canonicalArchive) {
            fprintf(stderr, "archive fixtures: corpus error: archive path failed\n");
            return 2;
        }
        PXVerifiedBackupArtifactSet *verifiedSet = [[PXVerifiedBackupArtifactSet alloc]
            initWithCanonicalPathsByName:@{ archiveName: canonicalArchive }];
        NSDictionary *manifest = PXFixtureManifest(record);

        NSError *error = nil;
        PXValidatedBackupArchiveSet *result =
            [PXBackupArchiveValidator validatedArchivesForManifest:manifest
                                                   backupDirectory:fixtureRoot
                                                 verifiedArtifacts:verifiedSet
                                                             error:&error];

        NSUInteger failureCountBefore = failures.count;
        if ([record[@"expectedDisposition"] isEqualToString:@"accepted"]) {
            PXFixtureAssertAccepted(record, result, error, failures);
        } else {
            PXFixtureAssertRejected(record,
                                    result,
                                    error,
                                    fixtureRoot,
                                    archivePath,
                                    actualDigest,
                                    (uint64_t)status.st_size,
                                    failures);
        }

        NSString *afterMessage = nil;
        NSDictionary *afterSnapshot = PXFixtureSnapshot(fixtureRoot, &afterMessage);
        if (!afterSnapshot) {
            PXFixtureAddFailure(failures, fixtureID, @"mutation.snapshot", @"post-run snapshot failed");
        } else if (![afterSnapshot isEqualToDictionary:baselineSnapshot]) {
            PXFixtureAddFailure(failures, fixtureID, @"mutation.corpus", @"fixture corpus changed");
        }
        if (failures.count == failureCountBefore) {
            passed++;
        }
    }

    NSString *finalMessage = nil;
    NSDictionary *finalSnapshot = PXFixtureSnapshot(fixtureRoot, &finalMessage);
    if (!finalSnapshot || ![finalSnapshot isEqualToDictionary:baselineSnapshot]) {
        PXFixtureAddFailure(failures, @"<suite>", @"mutation.final", @"final corpus snapshot differed");
    }

    if (failures.count != 0) {
        NSArray<NSDictionary *> *sorted = PXFixtureSortedFailures(failures);
        printf("archive fixtures: FAIL (%lu failed, %lu passed)\n",
               (unsigned long)sorted.count,
               (unsigned long)passed);
        for (NSDictionary *failure in sorted) {
            printf("[%s] %s: %s\n",
                   [failure[@"id"] UTF8String],
                   [failure[@"assertion"] UTF8String],
                   [failure[@"message"] UTF8String]);
        }
        return 1;
    }

    printf("archive fixtures: PASS (86/86; accepted=20 rejected=66)\n");
    return 0;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2 || !argv[1] || argv[1][0] != '/') {
            fprintf(stderr, "archive fixtures: usage: px-archive-fixture-tests <absolute-path-to-fixtures.json>\n");
            return 2;
        }
        @try {
            NSString *metadataPath = [NSString stringWithUTF8String:argv[1]];
            if (!metadataPath) {
                fprintf(stderr, "archive fixtures: metadata error: path encoding is invalid\n");
                return 2;
            }
            return PXFixtureRun(metadataPath);
        } @catch (__unused NSException *exception) {
            fprintf(stderr, "archive fixtures: internal error\n");
            return 2;
        }
    }
}
