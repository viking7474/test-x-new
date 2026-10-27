#import "PXProfileArtifactMutation.h"
#import "PXProfileLifecycleLease.h"
#import "PXProfileDeletionJournal.h"
#import "PXPaths.h"
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

static BOOL PXArtifactMutationError(NSError **error, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"WeaponXProfileError" code:25 userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}
@interface PXProfileArtifactMutation () {
    int _directoryFD;
}
@property (nonatomic, copy, readwrite) NSString *identityDirectory;
@property (nonatomic, copy, readwrite) NSString *profileDirectory;
@property (nonatomic, copy) NSString *targetDirectory;
@property (nonatomic, copy) NSString *profileID;
@property (nonatomic, copy) NSDictionary *directoryProof;
@property (nonatomic, strong) PXProfileLifecycleLease *lease;
@property (nonatomic) BOOL ownsLease;
- (instancetype)initForMutation;
- (BOOL)validateWithError:(NSError **)error;
+ (instancetype)acquireWithDirectoryResolver:(NSString *(^)(void))resolver identityTarget:(BOOL)identityTarget lifecycleLease:(PXProfileLifecycleLease *)borrowed error:(NSError **)error NS_RETURNS_RETAINED;
@end

@implementation PXProfileArtifactMutation
- (instancetype)initForMutation {
    if ((self = [super init])) _directoryFD = -1;
    return self;
}
+ (instancetype)acquireWithIdentityResolver:(NSString *(^)(void))resolver error:(NSError **)error {
    return [self acquireWithDirectoryResolver:resolver identityTarget:YES lifecycleLease:nil error:error];
}
+ (instancetype)acquireWithProfileIDResolver:(NSString *(^)(void))resolver error:(NSError **)error {
    return [self acquireWithDirectoryResolver:^NSString *{
        return PXProfileRootPath(PXValidatedProfileID(resolver ? resolver() : nil));
    } identityTarget:NO lifecycleLease:nil error:error];
}
+ (instancetype)borrowWithLifecycleLease:(PXProfileLifecycleLease *)lease identityResolver:(NSString *(^)(void))resolver error:(NSError **)error {
    if (error) *error = nil;
    if (![lease isKindOfClass:PXProfileLifecycleLease.class]) {
        PXArtifactMutationError(error, @"Missing borrowed artifact lifecycle capability"); return nil;
    }
    return [self acquireWithDirectoryResolver:resolver identityTarget:YES lifecycleLease:lease error:error];
}
+ (instancetype)acquireWithDirectoryResolver:(NSString *(^)(void))resolver identityTarget:(BOOL)identityTarget lifecycleLease:(PXProfileLifecycleLease *)borrowed error:(NSError **)error {
    if (error) *error = nil;
    PXProfileArtifactMutation *mutation = [[self alloc] initForMutation];
    mutation.ownsLease = borrowed == nil;
    mutation.lease = borrowed ?: [PXProfileLifecycleLease acquireInDirectory:PXProfilesPath() error:error];
    BOOL handedOff = NO;
    @try {
        if (!mutation.lease || ![mutation.lease validateForDirectory:PXProfilesPath() error:error] || !PXRequireNoPendingProfileDeletion(error)) return nil;
        id resolved = resolver ? resolver() : nil;
        NSString *target = [resolved isKindOfClass:NSString.class] ? [resolved copy] : nil;
        NSString *profileID = identityTarget ? target.stringByDeletingLastPathComponent.lastPathComponent : target.lastPathComponent;
        NSString *expected = identityTarget ? PXProfileIdentityPath(PXValidatedProfileID(profileID)) : PXProfileRootPath(PXValidatedProfileID(profileID));
        if (!target || ![expected isEqual:target]) {
            PXArtifactMutationError(error, @"Profile artifact target is invalid or selection changed before ownership"); return nil;
        }
        mutation.identityDirectory = PXProfileIdentityPath(profileID);
        mutation.profileDirectory = PXProfileRootPath(profileID);
        mutation.targetDirectory = target;
        mutation.profileID = profileID;
        mutation.directoryProof = [mutation.lease directoryProofForProfileID:profileID error:error];
        if (![mutation.directoryProof[@"exists"] boolValue]) {
            PXArtifactMutationError(error, @"Profile artifact target directory no longer exists"); return nil;
        }
        // Pin the writer's directory until release; reject replacement/symlinks
        // at commit checkpoints instead of recreating a removed target.
        mutation->_directoryFD = open(target.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
        if (![mutation validateWithError:error]) return nil;
        handedOff = YES;
        return mutation;
    } @finally {
        if (!handedOff) [mutation invalidate];
    }
}
- (BOOL)validateWithError:(NSError **)error {
    if (!self.lease) return PXArtifactMutationError(error, @"Profile artifact ownership has ended");
    if (![self.lease validateForDirectory:PXProfilesPath() error:error]) return NO;
    NSDictionary *observed = [self.lease directoryProofForProfileID:self.profileID error:error];
    if (!observed) return NO;
    if (![observed isEqual:self.directoryProof]) return PXArtifactMutationError(error, @"Profile directory changed during artifact preparation");
    struct stat held, current;
    if (_directoryFD < 0 || fstat(_directoryFD, &held) != 0 || lstat(self.targetDirectory.fileSystemRepresentation, &current) != 0 ||
        !S_ISDIR(held.st_mode) || !S_ISDIR(current.st_mode) || held.st_dev != current.st_dev || held.st_ino != current.st_ino)
        return PXArtifactMutationError(error, @"Profile artifact directory is unavailable or was replaced");
    return YES;
}
- (BOOL)performSourceWrite:(BOOL (^)(PXRuntimeSourceTransaction *, NSError **))body error:(NSError **)error {
    return PXPerformRuntimeSourceWrite(^BOOL(PXRuntimeSourceTransaction *tx, NSError **writeError) {
        if (![self validateWithError:writeError]) return NO;
        BOOL pending = NO;
        if (![tx dictionaryAtPath:PXProfileDeletionJournalPath() exists:&pending error:writeError]) return NO;
        if (pending) {
            if (writeError) *writeError = [NSError errorWithDomain:@"WeaponXProfileError" code:27 userInfo:@{NSLocalizedDescriptionKey: @"Deletion recovery started during artifact preparation"}];
            return NO;
        }
        return body(tx, writeError);
    }, error);
}
- (void)invalidate {
    if (_directoryFD >= 0) { close(_directoryFD); _directoryFD = -1; }
    if (self.ownsLease) [self.lease invalidate];
    self.lease = nil;
}
- (void)dealloc { [self invalidate]; }
@end
