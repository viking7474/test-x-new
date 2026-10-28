#import "PXProfileCreationReservation.h"
#import "PXPaths.h"
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>

static NSString *const PXCreationMarker = @".creation-owner.plist";

static BOOL PXReservationError(NSError **error, NSString *message, int code) {
    if (error) *error = [NSError errorWithDomain:@"WeaponXProfileDirectoryError" code:code
        userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}

static BOOL PXSameDirectory(struct stat first, struct stat second) {
    return S_ISDIR(first.st_mode) && S_ISDIR(second.st_mode) &&
        first.st_dev == second.st_dev && first.st_ino == second.st_ino;
}

static BOOL PXWriteNewProfileData(int directoryFD, NSString *name, NSData *data, NSError **error) {
    int fd = openat(directoryFD, name.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0644);
    if (fd < 0) return PXReservationError(error, @"Could not exclusively create profile metadata", errno);
    const uint8_t *bytes = data.bytes; NSUInteger remaining = data.length;
    int failure = 0;
    if (fchmod(fd, 0644) != 0) failure = errno;
    while (!failure && remaining) {
        ssize_t count = write(fd, bytes, remaining);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) { failure = count < 0 ? errno : EIO; break; }
        bytes += count; remaining -= (NSUInteger)count;
    }
    if (close(fd) != 0 && !failure) failure = errno;
    // A partial new file/directory is retained, never unlinked as compensation.
    return !failure || PXReservationError(error, @"Could not write new profile metadata", failure);
}

static BOOL PXReservationDataMatches(int fd, NSData *expected) {
    // Validation also runs inside activation's source gate. Compare bounded
    // chunks without allocating a second buffer the size of display metadata.
    uint8_t buffer[4096]; NSUInteger offset = 0, length = expected.length;
    const uint8_t *bytes = expected.bytes;
    while (offset < length) {
        NSUInteger amount = MIN(sizeof(buffer), length - offset);
        ssize_t count = pread(fd, buffer, amount, (off_t)offset);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0 || memcmp(buffer, bytes + offset, (size_t)count) != 0) return NO;
        offset += (NSUInteger)count;
    }
    // Reject a suffix appended after the initial size check as well.
    ssize_t tail;
    do { tail = pread(fd, buffer, 1, (off_t)length); } while (tail < 0 && errno == EINTR);
    return tail == 0;
}

@interface PXProfileCreationReservation () {
    int _rootFD, _profileFD, _identityFD, _markerFD, _metadataFD;
}
@property (nonatomic, copy) NSString *profilesDirectory;
@property (nonatomic, copy, readwrite) NSString *profileID;
@property (nonatomic, copy, readwrite) NSString *identityDirectory;
@property (nonatomic, copy) NSData *markerData;
@property (nonatomic, copy) NSData *metadataData;
- (instancetype)initForReservation;
@end

@implementation PXProfileCreationReservation

- (instancetype)initForReservation {
    if ((self = [super init])) _rootFD = _profileFD = _identityFD = _markerFD = _metadataFD = -1;
    return self;
}

+ (instancetype)reserveProfileID:(NSString *)profileID inProfilesDirectory:(NSString *)directory metadata:(NSDictionary *)metadata error:(NSError **)error {
    if (error) *error = nil;
    if (![PXValidatedProfileID(profileID) isEqualToString:profileID] || ![directory isKindOfClass:NSString.class] || !directory.isAbsolutePath) {
        PXReservationError(error, @"Invalid new profile directory target", EINVAL); return nil;
    }
    profileID = [profileID copy];
    directory = [directory copy];
    // Fail malformed/non-serializable input before reserving a filesystem ID.
    if (![metadata isKindOfClass:NSDictionary.class]) {
        PXReservationError(error, @"Invalid new profile display metadata", EINVAL); return nil;
    }
    NSData *metadataData = nil; NSDictionary *frozenMetadata = nil;
    @try {
        metadataData = [NSPropertyListSerialization dataWithPropertyList:metadata format:NSPropertyListXMLFormat_v1_0 options:0 error:error];
        if (metadataData) frozenMetadata = [NSPropertyListSerialization propertyListWithData:metadataData options:NSPropertyListImmutable format:NULL error:error];
    } @catch (__unused NSException *exception) {
        PXReservationError(error, @"New profile metadata is not a property list", EINVAL); return nil;
    }
    if (!metadataData) {
        if (error && !*error) PXReservationError(error, @"Could not serialize new profile metadata", EINVAL);
        return nil;
    }
    if (![frozenMetadata isKindOfClass:NSDictionary.class] || ![frozenMetadata[@"DisplayName"] isKindOfClass:NSString.class] ||
        ![frozenMetadata[@"Identifier"] isKindOfClass:NSString.class] || ![frozenMetadata[@"Identifier"] isEqual:profileID] ||
        (frozenMetadata[@"Description"] && ![frozenMetadata[@"Description"] isKindOfClass:NSString.class])) {
        PXReservationError(error, @"Invalid new profile display metadata", EINVAL); return nil;
    }
    NSDictionary *marker = @{ @"schemaVersion": @1, @"operationID": NSUUID.UUID.UUIDString,
        @"profileID": profileID, @"createdAt": NSDate.date, @"state": @"reserved" };
    NSData *markerData = [NSPropertyListSerialization dataWithPropertyList:marker format:NSPropertyListXMLFormat_v1_0 options:0 error:error];
    if (!markerData) {
        if (error && !*error) PXReservationError(error, @"Could not serialize profile ownership marker", EINVAL);
        return nil;
    }
    PXProfileCreationReservation *reservation = [[self alloc] initForReservation];
    reservation.profileID = profileID;
    reservation.profilesDirectory = directory;
    reservation.identityDirectory = [[directory stringByAppendingPathComponent:profileID] stringByAppendingPathComponent:@"identity"];
    // Follow the configured profiles root (jailbreak paths may contain aliases),
    // then require exact, non-symlink child directories via descriptor-relative IO.
    reservation->_rootFD = open(directory.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (reservation->_rootFD < 0 || mkdirat(reservation->_rootFD, profileID.fileSystemRepresentation, 0755) != 0) {
        PXReservationError(error, @"New profile directory is unavailable or already reserved", errno); return nil;
    }
    reservation->_profileFD = openat(reservation->_rootFD, profileID.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    if (reservation->_profileFD < 0 || mkdirat(reservation->_profileFD, "identity", 0755) != 0) {
        PXReservationError(error, @"Could not initialize the reserved profile directory", errno); return nil;
    }
    reservation->_identityFD = openat(reservation->_profileFD, "identity", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    if (reservation->_identityFD < 0 || fchmod(reservation->_profileFD, 0755) != 0 || fchmod(reservation->_identityFD, 0755) != 0) {
        PXReservationError(error, @"Could not open the reserved identity directory", errno); return nil;
    }
    if (!PXWriteNewProfileData(reservation->_profileFD, PXCreationMarker, markerData, error) ||
        !PXWriteNewProfileData(reservation->_profileFD, @"identifiers.plist", metadataData, error)) return nil;
    reservation->_markerFD = openat(reservation->_profileFD, PXCreationMarker.fileSystemRepresentation, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
    reservation->_metadataFD = openat(reservation->_profileFD, "identifiers.plist", O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
    reservation.markerData = markerData;
    reservation.metadataData = metadataData;
    if (![reservation validateWithError:error]) return nil;
    return reservation;
}

- (BOOL)validateWithError:(NSError **)error {
    struct stat root, rootPath, profile, profilePath, identity, identityPath, marker, markerPath, metadata, metadataPath;
    if (_rootFD < 0 || _profileFD < 0 || _identityFD < 0 || _markerFD < 0 || _metadataFD < 0 || !self.markerData.length || !self.metadataData.length ||
        fstat(_rootFD, &root) != 0 || stat(self.profilesDirectory.fileSystemRepresentation, &rootPath) != 0 || !PXSameDirectory(root, rootPath) ||
        fstat(_profileFD, &profile) != 0 || fstatat(_rootFD, self.profileID.fileSystemRepresentation, &profilePath, AT_SYMLINK_NOFOLLOW) != 0 || !PXSameDirectory(profile, profilePath) ||
        fstat(_identityFD, &identity) != 0 || fstatat(_profileFD, "identity", &identityPath, AT_SYMLINK_NOFOLLOW) != 0 || !PXSameDirectory(identity, identityPath) ||
        fstat(_markerFD, &marker) != 0 || fstatat(_profileFD, PXCreationMarker.fileSystemRepresentation, &markerPath, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISREG(marker.st_mode) || !S_ISREG(markerPath.st_mode) || marker.st_nlink != 1 ||
        marker.st_dev != markerPath.st_dev || marker.st_ino != markerPath.st_ino || marker.st_size != (off_t)self.markerData.length ||
        fstat(_metadataFD, &metadata) != 0 || fstatat(_profileFD, "identifiers.plist", &metadataPath, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISREG(metadata.st_mode) || !S_ISREG(metadataPath.st_mode) || metadata.st_nlink != 1 ||
        metadata.st_dev != metadataPath.st_dev || metadata.st_ino != metadataPath.st_ino || metadata.st_size != (off_t)self.metadataData.length)
        return PXReservationError(error, @"Profile directory ownership changed during creation", ESTALE);
    if (!PXReservationDataMatches(_markerFD, self.markerData)) return PXReservationError(error, @"Profile ownership marker changed", ESTALE);
    return PXReservationDataMatches(_metadataFD, self.metadataData) || PXReservationError(error, @"Profile display metadata changed", ESTALE);
}

- (void)dealloc {
    if (_metadataFD >= 0) close(_metadataFD);
    if (_markerFD >= 0) close(_markerFD);
    if (_identityFD >= 0) close(_identityFD);
    if (_profileFD >= 0) close(_profileFD);
    if (_rootFD >= 0) close(_rootFD);
}
@end
