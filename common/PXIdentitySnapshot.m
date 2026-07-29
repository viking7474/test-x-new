#import "PXIdentitySnapshot.h"
#import "PXDeviceProfileSchema.h"
#import "PXPaths.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#import <errno.h>
#import <os/lock.h>

@interface PXIdentitySnapshot ()
- (instancetype)initWithProfileID:(NSString * _Nullable)profileID
                       generation:(uint64_t)generation
                        deviceIDs:(NSDictionary *)deviceIDs
                         settings:(NSDictionary *)settings
                            specs:(NSDictionary *)specs
                           source:(NSString *)source
                            valid:(BOOL)valid;
@end

@implementation PXIdentitySnapshot {
    NSString *_profileID;
    uint64_t _generation;
    NSNumber *_generationNumber;
    NSDictionary *_deviceIDs;
    NSDictionary *_settings;
    NSDictionary *_specs;
    NSString *_deviceModel;
    NSString *_source;
    BOOL _valid;
}

@synthesize profileID = _profileID;
@synthesize generation = _generation;
@synthesize generationNumber = _generationNumber;
@synthesize deviceIDs = _deviceIDs;
@synthesize settings = _settings;
@synthesize specs = _specs;
@synthesize deviceModel = _deviceModel;
@synthesize source = _source;
@synthesize valid = _valid;

- (instancetype)initWithProfileID:(NSString * _Nullable)profileID
                       generation:(uint64_t)generation
                        deviceIDs:(NSDictionary *)deviceIDs
                         settings:(NSDictionary *)settings
                            specs:(NSDictionary *)specs
                           source:(NSString *)source
                            valid:(BOOL)valid {
    self = [super init];
    if (self) {
        _profileID = [profileID copy];
        _generation = generation;
        _generationNumber = @(generation);
        _deviceIDs = [deviceIDs copy] ?: @{};
        _settings = [settings copy] ?: @{};
        _specs = [specs copy] ?: @{};
        _deviceModel = [PXProfileString(_deviceIDs[@"DeviceModel"]) copy];
        _source = [source copy] ?: @"unknown";
        _valid = valid;
    }
    return self;
}

@end

static os_unfair_lock gPXIdentitySnapshotLock = OS_UNFAIR_LOCK_INIT;
static PXIdentitySnapshot *gPXIdentitySnapshot;
static uint64_t gPXIdentityReloadSequence;
static uint64_t gPXIdentityPublishedSequence;
static __thread BOOL gPXIdentityBuildInProgress;

static id PXIdentityDeepImmutableCopy(id object) {
    if (!object || object == [NSNull null]) return object;
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[object count]];
        [(NSDictionary *)object enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            (void)stop;
            id copiedKey = [key conformsToProtocol:@protocol(NSCopying)] ? [key copy] : key;
            id copiedValue = PXIdentityDeepImmutableCopy(value);
            if (copiedKey && copiedValue) result[copiedKey] = copiedValue;
        }];
        return [result copy];
    }
    if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:[object count]];
        for (id value in (NSArray *)object) {
            id copiedValue = PXIdentityDeepImmutableCopy(value);
            if (copiedValue) [result addObject:copiedValue];
        }
        return [result copy];
    }
    if ([object isKindOfClass:[NSSet class]]) {
        NSMutableSet *result = [NSMutableSet setWithCapacity:[object count]];
        for (id value in (NSSet *)object) {
            id copiedValue = PXIdentityDeepImmutableCopy(value);
            if (copiedValue) [result addObject:copiedValue];
        }
        return [result copy];
    }
    return [object conformsToProtocol:@protocol(NSCopying)] ? [object copy] : object;
}

static PXIdentitySnapshot *PXBuildIdentitySnapshot(void) {
    NSString *profileID = PXActiveProfileID();
    NSString *rootPath = PXProfileRootPath(profileID);
    NSString *deviceIDsPath = PXProfileDeviceIDsPath(profileID);

    NSDictionary *diskDeviceIDs = deviceIDsPath.length
        ? [NSDictionary dictionaryWithContentsOfFile:deviceIDsPath]
        : nil;
    NSDictionary *diskSettings = rootPath.length
        ? [NSDictionary dictionaryWithContentsOfFile:[rootPath stringByAppendingPathComponent:@"settings.plist"]]
        : nil;

    NSDictionary *deviceIDs = [diskDeviceIDs isKindOfClass:[NSDictionary class]]
        ? PXIdentityDeepImmutableCopy(diskDeviceIDs)
        : @{};
    NSDictionary *settings = [diskSettings isKindOfClass:[NSDictionary class]]
        ? PXIdentityDeepImmutableCopy(diskSettings)
        : @{};

    uint64_t generation = 0;
    id generationValue = deviceIDs[@"GenerationCounter"];
    if ([generationValue respondsToSelector:@selector(unsignedLongLongValue)]) {
        generation = [generationValue unsignedLongLongValue];
    }

    NSDictionary *specs = PXDeviceSpecificationsFromDeviceIDs(deviceIDs) ?: @{};
    BOOL valid = profileID.length > 0 && deviceIDs.count > 0;
    NSString *source = valid ? (generation > 0 ? @"device_ids" : @"device_ids-legacy-generation")
                             : (profileID.length ? @"device_ids-unavailable" : @"missing-profile");

    return [[PXIdentitySnapshot alloc] initWithProfileID:profileID
                                              generation:generation
                                               deviceIDs:deviceIDs
                                                settings:settings
                                                   specs:specs
                                                  source:source
                                                   valid:valid];
}

PXIdentitySnapshot *PXReloadIdentitySnapshot(NSString *reason) {
    (void)reason;
    int incomingErrno = errno;

    if (gPXIdentityBuildInProgress) {
        os_unfair_lock_lock(&gPXIdentitySnapshotLock);
        PXIdentitySnapshot *existing = gPXIdentitySnapshot;
        os_unfair_lock_unlock(&gPXIdentitySnapshotLock);
        errno = incomingErrno;
        return existing ?: [[PXIdentitySnapshot alloc] initWithProfileID:nil
                                                               generation:0
                                                                deviceIDs:@{}
                                                                 settings:@{}
                                                                    specs:@{}
                                                                   source:@"recursive-build"
                                                                    valid:NO];
    }

    os_unfair_lock_lock(&gPXIdentitySnapshotLock);
    uint64_t requestSequence = ++gPXIdentityReloadSequence;
    os_unfair_lock_unlock(&gPXIdentitySnapshotLock);

    gPXIdentityBuildInProgress = YES;
    PXIdentitySnapshot *candidate = nil;
    @try {
        @autoreleasepool {
            candidate = PXBuildIdentitySnapshot();
        }
    } @catch (__unused NSException *exception) {
        candidate = [[PXIdentitySnapshot alloc] initWithProfileID:PXActiveProfileID()
                                                       generation:0
                                                        deviceIDs:@{}
                                                         settings:@{}
                                                            specs:@{}
                                                           source:@"exception"
                                                            valid:NO];
    } @finally {
        gPXIdentityBuildInProgress = NO;
    }

    os_unfair_lock_lock(&gPXIdentitySnapshotLock);
    if (requestSequence > gPXIdentityPublishedSequence) {
        BOOL sameProfile = gPXIdentitySnapshot &&
            ((gPXIdentitySnapshot.profileID == candidate.profileID) ||
             [gPXIdentitySnapshot.profileID isEqualToString:candidate.profileID]);
        BOOL transientFailure = !candidate.valid &&
            ([candidate.source isEqualToString:@"device_ids-unavailable"] ||
             [candidate.source isEqualToString:@"exception"]);

        // Keep the last complete generation only for a transient read of the same
        // active profile. Never leak the previous profile after a profile switch.
        if (!(transientFailure && sameProfile && gPXIdentitySnapshot.valid)) {
            gPXIdentitySnapshot = candidate;
        }
        gPXIdentityPublishedSequence = requestSequence;
    }
    PXIdentitySnapshot *published = gPXIdentitySnapshot ?: candidate;
    os_unfair_lock_unlock(&gPXIdentitySnapshotLock);

    errno = incomingErrno;
    return published;
}

PXIdentitySnapshot *PXCurrentIdentitySnapshot(void) {
    int incomingErrno = errno;
    os_unfair_lock_lock(&gPXIdentitySnapshotLock);
    PXIdentitySnapshot *snapshot = gPXIdentitySnapshot;
    os_unfair_lock_unlock(&gPXIdentitySnapshotLock);
    if (!snapshot) snapshot = PXReloadIdentitySnapshot(@"lazy");
    errno = incomingErrno;
    return snapshot;
}

void PXInvalidateIdentitySnapshot(void) {
    os_unfair_lock_lock(&gPXIdentitySnapshotLock);
    gPXIdentitySnapshot = nil;
    gPXIdentityPublishedSequence = ++gPXIdentityReloadSequence;
    os_unfair_lock_unlock(&gPXIdentitySnapshotLock);
}

static void PXIdentitySnapshotNotification(CFNotificationCenterRef center,
                                           void *observer,
                                           CFStringRef name,
                                           const void *object,
                                           CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)object; (void)userInfo;
    @autoreleasepool {
        PXReloadIdentitySnapshot((__bridge NSString *)name);
    }
}

void PXIdentitySnapshotStartObserving(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
        if (center) {
            for (NSString *name in @[@"com.hydra.projectx.settings.changed",
                                     @"com.hydra.projectx.profileChanged"]) {
                CFNotificationCenterAddObserver(center,
                                                NULL,
                                                PXIdentitySnapshotNotification,
                                                (__bridge CFStringRef)name,
                                                NULL,
                                                CFNotificationSuspensionBehaviorDeliverImmediately);
            }
        }
        (void)PXCurrentIdentitySnapshot();
    });
}

NSDictionary *PXDeviceIDsSnapshot(NSString **outProfileID, NSNumber **outGeneration) {
    PXIdentitySnapshot *snapshot = PXCurrentIdentitySnapshot();
    if (outProfileID) *outProfileID = snapshot.profileID;
    if (outGeneration) *outGeneration = snapshot.generationNumber;
    return snapshot.valid ? snapshot.deviceIDs : nil;
}
