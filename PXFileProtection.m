#import "PXFileProtection.h"

#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#if defined(PROTECTION_CLASS_A)
static const int PXFileProtectionCompleteClass = PROTECTION_CLASS_A;
#else
// Apple exposes the fcntl data-protection commands in public SDK headers,
// while the symbolic class identifiers may remain gated behind PRIVATE.
// XNU's content-protection ABI defines class A as value 1.
static const int PXFileProtectionCompleteClass = 1;
#endif

NSErrorDomain const PXFileProtectionErrorDomain =
    @"com.hydra.projectx.file-protection";
NSString * const PXFileProtectionErrorFieldPathKey = @"fieldPath";

static NSString * const PXFileProtectionDescriptorField = @"$.descriptor";
static NSString * const PXFileProtectionIdentityField = @"$.descriptor.identity";
static NSString * const PXFileProtectionModeField = @"$.descriptor.mode";
static NSString * const PXFileProtectionClassField = @"$.descriptor.protectionClass";
static NSString * const PXFileProtectionDurabilityField = @"$.descriptor.durability";

static BOOL PXFileProtectionFail(NSError **error,
                                 PXFileProtectionErrorCode code,
                                 NSString *fieldPath,
                                 NSString *description) {
    if (error) {
        *error = [NSError errorWithDomain:PXFileProtectionErrorDomain
                                     code:code
                                 userInfo:@{
                                     NSLocalizedDescriptionKey: description,
                                     PXFileProtectionErrorFieldPathKey: fieldPath,
                                 }];
    }
    return NO;
}

static int PXFileProtectionGetDescriptorFlags(int descriptor) {
    int result = -1;
    do {
        result = fcntl(descriptor, F_GETFD);
    } while (result < 0 && errno == EINTR);
    return result;
}

static BOOL PXFileProtectionDescriptorHasCloseOnExec(int descriptor) {
    int flags = PXFileProtectionGetDescriptorFlags(descriptor);
    return flags >= 0 && (flags & FD_CLOEXEC) != 0;
}

static BOOL PXFileProtectionStatDescriptor(int descriptor,
                                           struct stat *status) {
    if (!status) {
        return NO;
    }
    int result = -1;
    do {
        result = fstat(descriptor, status);
    } while (result < 0 && errno == EINTR);
    return result == 0;
}

static BOOL PXFileProtectionSetMode(int descriptor, mode_t mode) {
    int result = -1;
    do {
        result = fchmod(descriptor, mode);
    } while (result < 0 && errno == EINTR);
    return result == 0;
}

static BOOL PXFileProtectionSetCompleteClass(int descriptor) {
    int result = -1;
    do {
        result = fcntl(descriptor,
                       F_SETPROTECTIONCLASS,
                       PXFileProtectionCompleteClass);
    } while (result < 0 && errno == EINTR);
    return result == 0;
}

static BOOL PXFileProtectionGetClass(int descriptor,
                                     int *protectionClassOut) {
    int result = -1;
    do {
        result = fcntl(descriptor, F_GETPROTECTIONCLASS);
    } while (result < 0 && errno == EINTR);
    if (result < 0) {
        return NO;
    }
    if (protectionClassOut) {
        *protectionClassOut = result;
    }
    return YES;
}

static BOOL PXFileProtectionSyncDescriptor(int descriptor) {
    int result = -1;
    do {
        result = fsync(descriptor);
    } while (result < 0 && errno == EINTR);
    return result == 0;
}

static BOOL PXFileProtectionBasicIdentityMatches(const struct stat *left,
                                                  const struct stat *right) {
    return left && right &&
           left->st_dev == right->st_dev &&
           left->st_ino == right->st_ino &&
           ((left->st_mode & S_IFMT) == (right->st_mode & S_IFMT));
}

static BOOL PXFileProtectionVerifyCommon(int descriptor,
                                         const struct stat *expectedIdentity,
                                         BOOL requireSameSize,
                                         struct stat *verifiedIdentityOut,
                                         NSError **error) {
    if (descriptor < 0 ||
        !PXFileProtectionDescriptorHasCloseOnExec(descriptor)) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorInvalidDescriptor,
                                    PXFileProtectionDescriptorField,
                                    @"The file descriptor is invalid.");
    }

    struct stat status;
    if (!PXFileProtectionStatDescriptor(descriptor, &status)) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorInspectionFailed,
                                    PXFileProtectionIdentityField,
                                    @"The protected file could not be inspected.");
    }
    if (!S_ISREG(status.st_mode)) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorInvalidFileType,
                                    PXFileProtectionIdentityField,
                                    @"The protected object must be a regular file.");
    }
    if (status.st_nlink != 1) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorInvalidLinkCount,
                                    PXFileProtectionIdentityField,
                                    @"The protected file link count is invalid.");
    }
    if (status.st_uid != geteuid() || status.st_gid != getegid()) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorOwnershipMismatch,
                                    PXFileProtectionIdentityField,
                                    @"The protected file ownership is invalid.");
    }
    if ((status.st_mode & 07777) != 0600 ||
        (status.st_mode & (S_ISUID | S_ISGID)) != 0) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorPermissionUpdateFailed,
                                    PXFileProtectionModeField,
                                    @"The protected file permissions are invalid.");
    }
    if (expectedIdentity &&
        (!PXFileProtectionBasicIdentityMatches(expectedIdentity, &status) ||
         (requireSameSize && expectedIdentity->st_size != status.st_size))) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorIdentityChanged,
                                    PXFileProtectionIdentityField,
                                    @"The protected file identity changed.");
    }

    int protectionClass = 0;
    if (!PXFileProtectionGetClass(descriptor, &protectionClass)) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorClassInspectionFailed,
                                    PXFileProtectionClassField,
                                    @"The file protection class could not be inspected.");
    }
    if (protectionClass != PXFileProtectionCompleteClass) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorClassMismatch,
                                    PXFileProtectionClassField,
                                    @"The file protection class is invalid.");
    }
    if (verifiedIdentityOut) {
        *verifiedIdentityOut = status;
    }
    return YES;
}

BOOL PXApplyCompleteFileProtectionToDescriptor(int descriptor,
                                               NSError **error) {
    if (error) {
        *error = nil;
    }
    if (descriptor < 0 ||
        !PXFileProtectionDescriptorHasCloseOnExec(descriptor)) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorInvalidDescriptor,
                                    PXFileProtectionDescriptorField,
                                    @"The file descriptor is invalid.");
    }

    struct stat initialStatus;
    if (!PXFileProtectionStatDescriptor(descriptor, &initialStatus)) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorInspectionFailed,
                                    PXFileProtectionIdentityField,
                                    @"The file could not be inspected before protection.");
    }
    if (!S_ISREG(initialStatus.st_mode)) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorInvalidFileType,
                                    PXFileProtectionIdentityField,
                                    @"The protected object must be a regular file.");
    }
    if (initialStatus.st_nlink != 1) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorInvalidLinkCount,
                                    PXFileProtectionIdentityField,
                                    @"The protected file link count is invalid.");
    }
    if (initialStatus.st_uid != geteuid() ||
        initialStatus.st_gid != getegid()) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorOwnershipMismatch,
                                    PXFileProtectionIdentityField,
                                    @"The protected file ownership is invalid.");
    }
    if ((initialStatus.st_mode & (S_ISUID | S_ISGID | S_ISVTX)) != 0) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorPermissionUpdateFailed,
                                    PXFileProtectionModeField,
                                    @"The protected file permissions are invalid.");
    }
    if (!PXFileProtectionSetMode(descriptor, 0600)) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorPermissionUpdateFailed,
                                    PXFileProtectionModeField,
                                    @"The protected file permissions could not be applied.");
    }
    if (!PXFileProtectionSetCompleteClass(descriptor)) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorClassUpdateFailed,
                                    PXFileProtectionClassField,
                                    @"The file protection class could not be applied.");
    }
    if (!PXFileProtectionSyncDescriptor(descriptor)) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorDurabilityFailed,
                                    PXFileProtectionDurabilityField,
                                    @"The protected file could not be synchronized.");
    }

    struct stat finalStatus;
    if (!PXFileProtectionVerifyCommon(descriptor,
                                      &initialStatus,
                                      YES,
                                      &finalStatus,
                                      error)) {
        return NO;
    }
    if (!PXFileProtectionBasicIdentityMatches(&initialStatus, &finalStatus) ||
        initialStatus.st_size != finalStatus.st_size) {
        return PXFileProtectionFail(error,
                                    PXFileProtectionErrorIdentityChanged,
                                    PXFileProtectionIdentityField,
                                    @"The protected file identity changed.");
    }
    return YES;
}

BOOL PXVerifyCompleteFileProtectionOnDescriptor(int descriptor,
                                                NSError **error) {
    if (error) {
        *error = nil;
    }
    return PXFileProtectionVerifyCommon(descriptor,
                                        NULL,
                                        NO,
                                        NULL,
                                        error);
}
