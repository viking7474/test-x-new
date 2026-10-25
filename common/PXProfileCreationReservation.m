#import "PXProfileCreationReservation.h"
#import "PXPaths.h"
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

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

static BOOL PXWriteNewProfileRecord(int directoryFD, NSString *name, NSDictionary *record, NSData **writtenData, NSError **error) {
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:record format:NSPropertyListXMLFormat_v1_0 options:0 error:error];
    if (!data) return NO;
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
    if (!failure && writtenData) *writtenData = data;
    // A partial new file/directory is retained, never unlinked as compensation.
    return !failure || PXReservationError(error, @"Could not write new profile metadata", failure);
}

@interface PXProfileCreationReservation () {
    int _rootFD, _profileFD, _identityFD, _markerFD;
}
@property (nonatomic, copy) NSString *profilesDirectory;
@property (nonatomic, copy, readwrite) NSString *profileID;
@property (nonatomic, copy, readwrite) NSString *identityDirectory;
@property (nonatomic, copy) NSData *markerData;
- (instancetype)initForReservation;
@end

@implementation PXProfileCreationReservation

- (instancetype)initForReservation {
    if ((self = [super init])) _rootFD = _profileFD = _identityFD = _markerFD = -1;
    return self;
}

+ (instancetype)reserveProfileID:(NSString *)profileID inProfilesDirectory:(NSString *)directory metadata:(NSDictionary *)metadata error:(NSError **)error {
    if (![PXValidatedProfileID(profileID) isEqualToString:profileID] || !directory.isAbsolutePath) {
        PXReservationError(error, @"Invalid new profile directory target", EINVAL); return nil;
    }
    profileID = [profileID copy];
    directory = [directory copy];
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
    NSDictionary *marker = @{ @"schemaVersion": @1, @"operationID": NSUUID.UUID.UUIDString,
        @"profileID": profileID, @"createdAt": NSDate.date, @"state": @"reserved" };
    NSData *markerData = nil;
    if (!PXWriteNewProfileRecord(reservation->_profileFD, PXCreationMarker, marker, &markerData, error) ||
        !PXWriteNewProfileRecord(reservation->_profileFD, @"identifiers.plist", metadata, NULL, error)) return nil;
    reservation->_markerFD = openat(reservation->_profileFD, PXCreationMarker.fileSystemRepresentation, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
    reservation.markerData = markerData;
    if (![reservation validateWithError:error]) return nil;
    return reservation;
}

- (BOOL)validateWithError:(NSError **)error {
    struct stat root, rootPath, profile, profilePath, identity, identityPath, marker, markerPath;
    if (_rootFD < 0 || _profileFD < 0 || _identityFD < 0 || _markerFD < 0 || !self.markerData.length ||
        fstat(_rootFD, &root) != 0 || stat(self.profilesDirectory.fileSystemRepresentation, &rootPath) != 0 || !PXSameDirectory(root, rootPath) ||
        fstat(_profileFD, &profile) != 0 || fstatat(_rootFD, self.profileID.fileSystemRepresentation, &profilePath, AT_SYMLINK_NOFOLLOW) != 0 || !PXSameDirectory(profile, profilePath) ||
        fstat(_identityFD, &identity) != 0 || fstatat(_profileFD, "identity", &identityPath, AT_SYMLINK_NOFOLLOW) != 0 || !PXSameDirectory(identity, identityPath) ||
        fstat(_markerFD, &marker) != 0 || fstatat(_profileFD, PXCreationMarker.fileSystemRepresentation, &markerPath, AT_SYMLINK_NOFOLLOW) != 0 ||
        !S_ISREG(marker.st_mode) || !S_ISREG(markerPath.st_mode) || marker.st_nlink != 1 ||
        marker.st_dev != markerPath.st_dev || marker.st_ino != markerPath.st_ino || marker.st_size != (off_t)self.markerData.length)
        return PXReservationError(error, @"Profile directory ownership changed during creation", ESTALE);
    NSMutableData *bytes = [NSMutableData dataWithLength:self.markerData.length];
    NSUInteger offset = 0;
    while (offset < bytes.length) {
        ssize_t count = pread(_markerFD, (uint8_t *)bytes.mutableBytes + offset, bytes.length - offset, (off_t)offset);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return PXReservationError(error, @"Profile ownership marker is unreadable", ESTALE);
        offset += (NSUInteger)count;
    }
    return [bytes isEqualToData:self.markerData] || PXReservationError(error, @"Profile ownership marker changed", ESTALE);
}

- (void)dealloc {
    if (_markerFD >= 0) close(_markerFD);
    if (_identityFD >= 0) close(_identityFD);
    if (_profileFD >= 0) close(_profileFD);
    if (_rootFD >= 0) close(_rootFD);
}
@end
