#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <UIKit/UIKit.h>
#import "TLinkIOSLogging.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import <substrate.h>
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate
#import <netinet/in.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import "CarrierDB.h"

#import "PXScope.h"
#import "PXPaths.h"
#import "PXRuntimeSnapshot.h"
#import "PXNativeHookCoordinator.h"
#import <os/lock.h>
#import <math.h>
#import <time.h>
#import <stdint.h>

// Constants for connection types
typedef NS_ENUM(NSInteger, NetworkConnectionType) {
    NetworkConnectionTypeAuto = 0,
    NetworkConnectionTypeWiFi = 1,
    NetworkConnectionTypeCellular = 2,
    NetworkConnectionTypeNone = 3
};

// Path to security settings plist
static NSString *const kSecuritySettingsPath = @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist";

// All network cache values/timestamps are protected by one process-local lock.
static os_unfair_lock gNetworkCacheLock = OS_UNFAIR_LOCK_INIT;

#pragma mark - Read cache declarations

typedef NS_ENUM(NSUInteger, PXNetworkReadCacheKind) {
    PXNetworkReadMode, PXNetworkReadISO, PXNetworkReadPinned, PXNetworkReadCarrier,
    PXNetworkReadCacheCount
};
typedef struct {
    double loadedAt;
    BOOL hasTime;
    uint64_t revision;
} PXNetworkReadCacheStamp;
static PXNetworkReadCacheStamp gNetworkReadStamps[PXNetworkReadCacheCount];
static id gNetworkModeValue, gNetworkISOValue, gNetworkPinnedValue, gNetworkCarrierValue;
static const NSTimeInterval kCacheValidDuration = 5.0;
static const NSTimeInterval kISOCountryCodeCacheValidDuration = 60.0;
static const NSTimeInterval kCarrierDetailsCacheValidDuration = 60.0;
static const NSTimeInterval kTargetRegionCacheValidDuration = 5.0;

#pragma mark - End read cache declarations

// Default cellular identity (US T-Mobile) — never use product name "TLinkIOS" as carrier.
// Profile/target-region values override these when present.
static NSString *const kFakeCarrierName = @"T-Mobile";
static NSString *const kFakeMobileCountryCode = @"310";
static NSString *const kFakeMobileNetworkCode = @"260";

// Fallback WiFi identity (realistic-looking; profile WiFi info should override when set)
static NSString *const kFakeWiFiSSID = @"HomeWiFi";
static NSString *const kFakeBSSID = @"00:11:22:33:44:55";

// Carrier name from CarrierDB (JSON) when available; never product branding.
static NSString *PXCarrierNameForMCCMNC(NSString *mcc, NSString *mnc) {
    if (!mcc.length || !mnc.length) return kFakeCarrierName;
    NSString *name = [[CarrierDB sharedManager] carrierNameForMCC:mcc mnc:mnc];
    if ([name isKindOfClass:[NSString class]] && name.length &&
        ![name isEqualToString:@"TLinkIOS"] && ![name hasPrefix:@"TLinkIOS"]) {
        return name;
    }
    return kFakeCarrierName;
}

#pragma mark - Signal cache state

// Scalar-only state: no Foundation calls, allocation or object destruction under
// gNetworkCacheLock. Each value owns its own interval and publication revision.
typedef struct {
    int value;
    double updatedAt;
    BOOL hasTime;
    uint64_t revision;
} PXNetworkSignalState;
static PXNetworkSignalState gWiFiSignal = { .value = -65 };
static PXNetworkSignalState gCellularSignal = { .value = 4 };

typedef NS_ENUM(int, PXNetworkRadio) {
    PXNetworkRadioLTE, PXNetworkRadioNR, PXNetworkRadioNRNSA
};
static struct {
    PXNetworkRadio value;
    double changedAt;
    BOOL hasTime;
    uint64_t revision;
} gNetworkRadio;
static const NSTimeInterval kMinNetworkTypeChangeDuration = 120.0;

static double PXNetworkSignalNow(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) return NAN;
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1000000000.0;
}

static BOOL PXNetworkSignalFresh(double now, double then, BOOL hasTime, double ttl) {
    return hasTime && isfinite(now) && isfinite(then) &&
        now >= then && now - then < ttl;
}

// Caller holds gNetworkCacheLock. Keep gradual signal values across invalidation,
// but revoke all in-flight candidates and reset the radio to its legacy LTE base.
static void PXNetworkInvalidateSignalCachesLocked(void) {
    gWiFiSignal.hasTime = NO;
    gWiFiSignal.revision++;
    gCellularSignal.hasTime = NO;
    gCellularSignal.revision++;
    gNetworkRadio.hasTime = NO;
    gNetworkRadio.value = PXNetworkRadioLTE;
    gNetworkRadio.revision++;
}

#pragma mark - End signal cache state

#pragma mark - Read cache publication

// Only internal enum constants reach these helpers. No Objective-C messages or
// allocation in the critical sections; retaining the captured root is allowed.
static id __strong *PXNetworkReadCacheSlot(PXNetworkReadCacheKind kind) {
    switch (kind) {
        case PXNetworkReadMode: return &gNetworkModeValue;
        case PXNetworkReadISO: return &gNetworkISOValue;
        case PXNetworkReadPinned: return &gNetworkPinnedValue;
        case PXNetworkReadCarrier: return &gNetworkCarrierValue;
        default: return NULL;
    }
}

static id PXNetworkReadCached(PXNetworkReadCacheKind kind, double now, double ttl,
                              uint64_t *revision, BOOL *hit) {
    id __strong *slot = PXNetworkReadCacheSlot(kind);
    if (!slot) { if (hit) *hit = NO; return nil; }
    id result = nil;
    os_unfair_lock_lock(&gNetworkCacheLock);
    PXNetworkReadCacheStamp stamp = gNetworkReadStamps[kind];
    BOOL valid = PXNetworkSignalFresh(now, stamp.loadedAt, stamp.hasTime, ttl);
    if (valid) result = *slot;
    if (revision) *revision = stamp.revision;
    if (hit) *hit = valid; // A valid nil is the pinned-region negative cache.
    os_unfair_lock_unlock(&gNetworkCacheLock);
    return result;
}

static BOOL PXNetworkPublishReadCache(PXNetworkReadCacheKind kind, id value,
                                     double loadedAt, uint64_t revision) {
    id __strong *slot = PXNetworkReadCacheSlot(kind);
    if (!slot) return NO;
    __attribute__((objc_precise_lifetime)) id retired = nil;
    BOOL published = NO;
    @try {
        os_unfair_lock_lock(&gNetworkCacheLock);
        if (gNetworkReadStamps[kind].revision == revision) {
            retired = *slot;
            *slot = value;
            gNetworkReadStamps[kind].loadedAt = loadedAt;
            gNetworkReadStamps[kind].hasTime = isfinite(loadedAt);
            gNetworkReadStamps[kind].revision++;
            published = YES;
        }
        os_unfair_lock_unlock(&gNetworkCacheLock);
        return published;
    } @finally {
        // Destructors may re-enter a reader/invalidation; never run under lock.
        retired = nil; value = nil;
    }
}

static NSNumber *PXNetworkCurrentModePacket(void) {
    os_unfair_lock_lock(&gNetworkCacheLock);
    NSNumber *mode = gNetworkModeValue;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    return mode;
}

static BOOL PXNetworkDataSpoofEnabledCached(void) {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    return PXRuntimeReadBool(PXCaptureRuntimeSnapshot().securitySettings[@"networkDataSpoofEnabled"]);
#else
    NSNumber *mode = nil;
    @try {
        mode = PXNetworkCurrentModePacket();
        // Enabled is encoded in the same mode packet: -1 means disabled.
        return mode && mode.integerValue >= NetworkConnectionTypeAuto;
    } @finally { mode = nil; }
#endif
}

static void PXNetworkInvalidateCaches(void) {
    __attribute__((objc_precise_lifetime)) id mode = nil;
    __attribute__((objc_precise_lifetime)) id iso = nil;
    __attribute__((objc_precise_lifetime)) id pinned = nil;
    __attribute__((objc_precise_lifetime)) id carrier = nil;
    @try {
        os_unfair_lock_lock(&gNetworkCacheLock);
        mode = gNetworkModeValue; iso = gNetworkISOValue;
        pinned = gNetworkPinnedValue; carrier = gNetworkCarrierValue;
        gNetworkModeValue = nil; gNetworkISOValue = nil;
        gNetworkPinnedValue = nil; gNetworkCarrierValue = nil;
        for (NSUInteger index = 0; index < PXNetworkReadCacheCount; index++) {
            gNetworkReadStamps[index].hasTime = NO;
            gNetworkReadStamps[index].revision++;
        }
        PXNetworkInvalidateSignalCachesLocked();
        os_unfair_lock_unlock(&gNetworkCacheLock);
    } @finally {
        mode = nil; iso = nil; pinned = nil; carrier = nil;
    }
}

#pragma mark - End read cache publication

#pragma mark - Helper Functions

// Get the current bundle ID
static NSString *getCurrentBundleID() {
    NSBundle *mainBundle = [NSBundle mainBundle];
    if (!mainBundle) {
        return nil;
    }
    
    NSString *bundleID = [mainBundle bundleIdentifier];
    return bundleID;
}

static NSDictionary *PXNetworkDictionary(id value) {
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}

static NSString *PXNetworkString(id value) {
    return [value isKindOfClass:NSString.class] ? value : nil;
}

static NSDictionary *PXNetworkCarrierSource(id carrierValue, id networkValue, id deviceValue) {
    NSDictionary *carrier = PXNetworkDictionary(carrierValue);
    NSDictionary *network = PXNetworkDictionary(networkValue);
    NSDictionary *deviceIDs = PXNetworkDictionary(deviceValue);
    return carrier.count ? carrier : (network.count ? network : deviceIDs);
}

static NSString *PXNetworkCarrierField(NSDictionary *source, NSString *key, NSString *legacyKey) {
    return PXNetworkString(source[key]) ?: PXNetworkString(source[legacyKey]);
}

#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
static NSDictionary *PXNetworkCarrierSourceAtIdentity(NSString *identityDir) {
    NSString *path = nil;
    NSDictionary *carrier = nil, *network = nil, *deviceIDs = nil;
    @try {
        if (!identityDir.length) return nil;
        path = [identityDir stringByAppendingPathComponent:@"carrier_details.plist"];
        carrier = [NSDictionary dictionaryWithContentsOfFile:path];
        path = [identityDir stringByAppendingPathComponent:@"network_settings.plist"];
        network = [NSDictionary dictionaryWithContentsOfFile:path];
        // Resolve the active identity once. A profile switch must not mix the
        // first two files with device_ids.plist from the newly active profile.
        path = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
        deviceIDs = [NSDictionary dictionaryWithContentsOfFile:path];
        return PXNetworkCarrierSource(carrier, network, deviceIDs);
    } @finally {
        path = nil; carrier = nil; network = nil; deviceIDs = nil;
        identityDir = nil;
    }
}
#endif

static NSDictionary *PXNetworkSecuritySettings(void) {
    PX_RUNTIME_READ_OPERATION;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    PXRuntimeReadSnapshot *runtimeView = PXCaptureRuntimeSnapshot();
    return PXNetworkDictionary(runtimeView.securitySettings) ?: @{};
#else
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:kSecuritySettingsPath];
    return [settings isKindOfClass:NSDictionary.class] ? settings : @{};
#endif
}

// Get the current ISO country code from security settings
static NSString *getCurrentISOCountryCode() {
    PX_RUNTIME_READ_OPERATION;
    NSDictionary *settings = nil;
    NSString *isoCode = nil, *pinnedISO = nil, *configured = nil, *cached = nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    static char isoResultKey;
    PXRuntimeReadSnapshot *operationView = PXCaptureRuntimeSnapshot();
#else
    double now = PXNetworkSignalNow();
    uint64_t revision = 0;
    BOOL hit = NO;
#endif
    @try {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        cached = objc_getAssociatedObject(operationView, &isoResultKey);
#else
        cached = PXNetworkReadCached(PXNetworkReadISO, now, kISOCountryCodeCacheValidDuration, &revision, &hit);
#endif
        if (cached) return cached;
        settings = PXNetworkSecuritySettings();
        if (PXRuntimeReadBool(settings[@"targetRegionFollowsIPEnabled"])) {
            pinnedISO = PXNetworkString(settings[@"targetRegionPinnedCarrierISO"]);
            if (pinnedISO.length) isoCode = [pinnedISO lowercaseString];
        }
        if (!isoCode.length) {
            configured = PXNetworkString(settings[@"networkISOCountryCode"]);
            isoCode = configured.length ? [configured lowercaseString] : @"us";
        }
        isoCode = [isoCode copy];
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        if (operationView) objc_setAssociatedObject(operationView, &isoResultKey, isoCode, OBJC_ASSOCIATION_RETAIN);
#else
        PXNetworkPublishReadCache(PXNetworkReadISO, isoCode, now, revision);
#endif
        return isoCode;
    } @finally {
        settings = nil; isoCode = nil; pinnedISO = nil; configured = nil; cached = nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        operationView = nil;
#endif
    }
}

static NSDictionary *getTargetRegionPinnedOverrides(void) {
    PX_RUNTIME_READ_OPERATION;
    NSDictionary *settings = nil, *resolved = nil;
    NSString *mcc = nil, *mnc = nil, *iso = nil, *name = nil, *resolvedName = nil;
    id cached = nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    static char pinnedResultKey;
    PXRuntimeReadSnapshot *operationView = PXCaptureRuntimeSnapshot();
#else
    double now = PXNetworkSignalNow();
    uint64_t revision = 0;
    BOOL hit = NO;
#endif
    @try {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        cached = objc_getAssociatedObject(operationView, &pinnedResultKey);
        if (cached) return cached == NSNull.null ? nil : cached;
#else
        cached = PXNetworkReadCached(PXNetworkReadPinned, now, kTargetRegionCacheValidDuration, &revision, &hit);
        if (hit) return cached;
#endif
        settings = PXNetworkSecuritySettings();
        if (PXRuntimeReadBool(settings[@"targetRegionFollowsIPEnabled"])) {
            mcc = PXNetworkString(settings[@"targetRegionPinnedCarrierMCC"]);
            mnc = PXNetworkString(settings[@"targetRegionPinnedCarrierMNC"]);
            iso = PXNetworkString(settings[@"targetRegionPinnedCarrierISO"]);
            name = PXNetworkString(settings[@"targetRegionPinnedCarrierName"]);
            if (mcc.length && mnc.length) {
                resolvedName = name.length ? name : PXCarrierNameForMCCMNC(mcc, mnc);
                if ([resolvedName isEqualToString:@"TLinkIOS"] || [resolvedName hasPrefix:@"TLinkIOS"]) {
                    resolvedName = PXCarrierNameForMCCMNC(mcc, mnc);
                }
                resolved = @{ @"carrierName": resolvedName ?: kFakeCarrierName,
                              @"mobileCountryCode": mcc, @"mobileNetworkCode": mnc,
                              @"carrierISO": iso ?: @"" };
            }
        }
        resolved = [resolved copy];
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        if (operationView) objc_setAssociatedObject(operationView, &pinnedResultKey, resolved ?: NSNull.null, OBJC_ASSOCIATION_RETAIN);
#else
        PXNetworkPublishReadCache(PXNetworkReadPinned, resolved, now, revision);
#endif
        return resolved;
    } @finally {
        settings = nil; resolved = nil; mcc = nil; mnc = nil; iso = nil;
        name = nil; resolvedName = nil; cached = nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        operationView = nil;
#endif
    }
}

static BOOL shouldForceCarrierSpoof(void) {
    PX_RUNTIME_READ_OPERATION;
    NSDictionary *settings = PXNetworkSecuritySettings();
    if (![settings isKindOfClass:[NSDictionary class]]) return NO;
    if (PXRuntimeReadBool(settings[@"targetRegionFollowsIPEnabled"])) return YES;
    if (PXRuntimeReadBool(settings[@"fullSpoofTestModeEnabled"])) return YES;
    return NO;
}

// Get the path to the current profile's identity directory
static NSString *getProfileIdentityPath() {
    return PXActiveProfileIdentityPath();
}

// Read persisted profile IP values without generating or writing from inside native hooks.
static NSString *getProfileStoredIPAddress(NSString *networkKey, NSString *deviceIDsKey) {
    PX_RUNTIME_READ_OPERATION;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    PXRuntimeReadSnapshot *runtimeView = PXCaptureRuntimeSnapshot();
    NSDictionary *networkDict = [runtimeView profileArtifact:@"networkSettings"];
    id networkValue = PXNetworkDictionary(networkDict)[networkKey];
    if ([networkValue isKindOfClass:NSString.class] && [(NSString *)networkValue length] > 0) return networkValue;
    NSDictionary *deviceIds = runtimeView.deviceIDs;
    id deviceValue = PXNetworkDictionary(deviceIds)[deviceIDsKey];
    return [deviceValue isKindOfClass:NSString.class] && [(NSString *)deviceValue length] > 0 ? deviceValue : nil;
#else
    NSString *identityDir = getProfileIdentityPath();
    if (!identityDir.length) return nil;

    NSString *networkPath = [identityDir stringByAppendingPathComponent:@"network_settings.plist"];
    NSDictionary *networkDict = [NSDictionary dictionaryWithContentsOfFile:networkPath];
    id networkValue = PXNetworkDictionary(networkDict)[networkKey];
    if ([networkValue isKindOfClass:[NSString class]] && [(NSString *)networkValue length] > 0) {
        return networkValue;
    }

    NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
    NSDictionary *deviceIds = [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath];
    id deviceValue = PXNetworkDictionary(deviceIds)[deviceIDsKey];
    if ([deviceValue isKindOfClass:[NSString class]] && [(NSString *)deviceValue length] > 0) {
        return deviceValue;
    }

    return nil;
#endif
}

static NSString *getProfileLocalIPAddress() {
    PX_RUNTIME_READ_OPERATION;
    return getProfileStoredIPAddress(@"localIPAddress", @"LocalIPAddress");
}

static NSString *getProfileLocalIPv6Address() {
    PX_RUNTIME_READ_OPERATION;
    return getProfileStoredIPAddress(@"localIPv6Address", @"LocalIPv6Address");
}

static BOOL PXNetworkParseIPv4(NSString *value, struct in_addr *outAddress) {
    if (!value.length || !outAddress) return NO;
    return inet_pton(AF_INET, value.UTF8String, outAddress) == 1;
}

static BOOL PXNetworkParseIPv6(NSString *value, struct in6_addr *outAddress) {
    if (!value.length || !outAddress) return NO;
    return inet_pton(AF_INET6, value.UTF8String, outAddress) == 1;
}

// Load scoped apps from the plist file
static NSDictionary *loadScopedApps(void) {
    PX_RUNTIME_READ_OPERATION;
    return PXScopedAppsSnapshot();
}

// Check if the current app is in the scoped apps list
static BOOL isInScopedAppsList() {
    PX_RUNTIME_READ_OPERATION;
    NSString *bundleID = getCurrentBundleID();
    if (!bundleID) {
        return NO;
    }
    
    NSDictionary *scopedApps = loadScopedApps();
    if (!scopedApps || scopedApps.count == 0) {
        return NO;
    }
    
    // Check if this bundle ID is in the scoped apps dictionary
    NSDictionary *appEntry = scopedApps[bundleID];
    if (!appEntry) {
        // Also try case-insensitive match
        NSString *lowercaseBundleID = [bundleID lowercaseString];
        for (NSString *key in scopedApps) {
            if ([[key lowercaseString] isEqualToString:lowercaseBundleID]) {
                appEntry = scopedApps[key];
                break;
            }
        }
        
        if (!appEntry) {
            return NO;
        }
    }
    
    // Check if the app is enabled
    BOOL isEnabled = [appEntry[@"enabled"] boolValue];
    return isEnabled;
}

// Get the current connection type setting from the plist
static NetworkConnectionType getNetworkConnectionType() {
    PX_RUNTIME_READ_OPERATION;
    NSDictionary *settings = nil;
    NSNumber *packet = nil;
    id raw = nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    static char typeKey;
    PXRuntimeReadSnapshot *operationView = PXCaptureRuntimeSnapshot();
#else
    double now = PXNetworkSignalNow();
    uint64_t revision = 0;
    BOOL hit = NO;
#endif
    @try {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        packet = objc_getAssociatedObject(operationView, &typeKey);
#else
        packet = PXNetworkReadCached(PXNetworkReadMode, now, kCacheValidDuration, &revision, &hit);
#endif
        if (packet) return (NetworkConnectionType)packet.integerValue;
        settings = PXNetworkSecuritySettings();
        BOOL enabled = PXRuntimeReadBool(settings[@"networkDataSpoofEnabled"]);
        raw = settings[@"networkConnectionType"];
        NSInteger rawType = [raw respondsToSelector:@selector(integerValue)] ? [raw integerValue] : NetworkConnectionTypeAuto;
        if (rawType < NetworkConnectionTypeAuto || rawType > NetworkConnectionTypeNone) rawType = NetworkConnectionTypeAuto;
        NetworkConnectionType type = enabled ? (NetworkConnectionType)rawType : (NetworkConnectionType)-1;
        packet = @(type);
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        if (operationView) objc_setAssociatedObject(operationView, &typeKey, packet, OBJC_ASSOCIATION_RETAIN);
#else
        // A losing cold reader adopts the current winner, avoiding an accidental
        // real-value passthrough merely because another reader finished first.
        // If invalidation left no winner, discard the revoked enablement.
        if (!PXNetworkPublishReadCache(PXNetworkReadMode, packet, now, revision)) {
            packet = PXNetworkCurrentModePacket();
            return packet ? (NetworkConnectionType)packet.integerValue : (NetworkConnectionType)-1;
        }
#endif
        return type;
    } @finally {
        settings = nil; packet = nil; raw = nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        operationView = nil;
#endif
    }
}

// For Auto mode, decide randomly between WiFi and Cellular
static BOOL shouldUseWiFiForAutoMode() {
    // Use a persistent seed for the current process to ensure consistent behavior
    static BOOL isWiFi = NO;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        isWiFi = arc4random_uniform(2) == 0; // 50% chance
        PXLog(@"[NetworkHook] Auto mode initialized as: %@", isWiFi ? @"WiFi" : @"Cellular");
    });
    
    return isWiFi;
}

// Master runtime gate shared by all Network Data Spoof hooks.
// Hooks remain installed for scoped apps so Security UI changes can take effect live,
// but they must become transparent whenever the authoritative setting is disabled.
static BOOL shouldApplyNetworkSpoofing() {
    PX_RUNTIME_READ_OPERATION;
    NetworkConnectionType type = getNetworkConnectionType();
    if (type == (NetworkConnectionType)-1 || !PXNetworkDataSpoofEnabledCached()) {
        return NO;
    }
    return isInScopedAppsList();
}

// Connection type "None" is an active spoofing mode: report no connection.
static BOOL shouldSpoofConnectionType() {
    PX_RUNTIME_READ_OPERATION;
    return shouldApplyNetworkSpoofing();
}

// Helper to check if we should show as WiFi
static BOOL shouldShowAsWiFi() {
    PX_RUNTIME_READ_OPERATION;
    if (!shouldApplyNetworkSpoofing()) return NO;
    NetworkConnectionType type = getNetworkConnectionType();
    
    if (type == NetworkConnectionTypeWiFi) {
        return YES;
    } else if (type == NetworkConnectionTypeAuto && shouldUseWiFiForAutoMode()) {
        return YES;
    }
    
    return NO;
}

// Helper to check if we should show as Cellular
static BOOL shouldShowAsCellular() {
    PX_RUNTIME_READ_OPERATION;
    if (!shouldApplyNetworkSpoofing()) return NO;
    NetworkConnectionType type = getNetworkConnectionType();
    if (type == NetworkConnectionTypeCellular) {
        return YES;
    } else if (type == NetworkConnectionTypeAuto && !shouldUseWiFiForAutoMode()) {
        return YES;
    }
    return NO;
}

static BOOL shouldShowAsNoConnection() {
    PX_RUNTIME_READ_OPERATION;
    return shouldApplyNetworkSpoofing() && getNetworkConnectionType() == NetworkConnectionTypeNone;
}

// Freeze the same three fields the legacy cache copied individually. Prepare
// this complete packet outside the lock, including for pinned overrides.
static NSDictionary *PXNetworkCarrierPacket(NSString *name, NSString *mcc, NSString *mnc) {
    NSString *frozenName = nil, *frozenMCC = nil, *frozenMNC = nil;
    @try {
        frozenName = [name copy] ?: kFakeCarrierName;
        frozenMCC = [mcc copy] ?: kFakeMobileCountryCode;
        frozenMNC = [mnc copy] ?: kFakeMobileNetworkCode;
        return @{ @"carrierName": frozenName, @"mobileCountryCode": frozenMCC, @"mobileNetworkCode": frozenMNC };
    } @finally {
        frozenName = nil; frozenMCC = nil; frozenMNC = nil;
        name = nil; mcc = nil; mnc = nil;
    }
}

// Get carrier details from the current profile.
static NSDictionary *getCarrierDetailsFromProfile() {
    PX_RUNTIME_READ_OPERATION;
    NSDictionary *pinned = nil, *cached = nil, *source = nil, *result = nil;
    NSDictionary *carrier = nil, *network = nil, *deviceIDs = nil;
    NSString *identityDir = nil, *carrierName = nil, *mcc = nil, *mnc = nil;
    NSString *sourceName = nil, *sourceMCC = nil, *sourceMNC = nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    static char carrierResultKey;
    PXRuntimeReadSnapshot *operationView = PXCaptureRuntimeSnapshot();
#else
    double now = PXNetworkSignalNow();
    uint64_t revision = 0;
    BOOL hit = NO;
#endif
    @try {
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        cached = objc_getAssociatedObject(operationView, &carrierResultKey);
        if (cached) return cached;
#else
        // Capture the revision BEFORE the nested pinned lookup: invalidation
        // during that provider must also revoke this carrier candidate.
        cached = PXNetworkReadCached(PXNetworkReadCarrier, now, kCarrierDetailsCacheValidDuration, &revision, &hit);
#endif
        pinned = getTargetRegionPinnedOverrides();
        if (pinned) {
            sourceName = pinned[@"carrierName"];
            sourceMCC = pinned[@"mobileCountryCode"];
            sourceMNC = pinned[@"mobileNetworkCode"];
            result = PXNetworkCarrierPacket(sourceName, sourceMCC, sourceMNC);
        } else {
#if !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
            if (hit) return cached;
#endif
            carrierName = kFakeCarrierName; mcc = kFakeMobileCountryCode; mnc = kFakeMobileNetworkCode;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
            carrier = [operationView profileArtifact:@"carrierDetails"];
            network = [operationView profileArtifact:@"networkSettings"];
            deviceIDs = operationView.deviceIDs;
            source = PXNetworkCarrierSource(carrier, network, deviceIDs);
#else
            identityDir = getProfileIdentityPath();
            source = PXNetworkCarrierSourceAtIdentity(identityDir);
#endif
            sourceName = PXNetworkCarrierField(source, @"carrierName", @"CarrierName");
            sourceMCC = PXNetworkCarrierField(source, @"mcc", @"CarrierMCC");
            sourceMNC = PXNetworkCarrierField(source, @"mnc", @"CarrierMNC");
            if (sourceName.length) carrierName = sourceName;
            if (sourceMCC.length) mcc = sourceMCC;
            if (sourceMNC.length) mnc = sourceMNC;
            if (!carrierName.length || [carrierName isEqualToString:@"TLinkIOS"] || [carrierName hasPrefix:@"TLinkIOS"]) {
                carrierName = PXCarrierNameForMCCMNC(mcc, mnc);
            }
            result = PXNetworkCarrierPacket(carrierName, mcc, mnc);
        }
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        if (operationView) objc_setAssociatedObject(operationView, &carrierResultKey, result, OBJC_ASSOCIATION_RETAIN);
#else
        PXNetworkPublishReadCache(PXNetworkReadCarrier, result, now, revision);
#endif
        return result;
    } @finally {
        pinned = nil; cached = nil; source = nil; result = nil;
        carrier = nil; network = nil; deviceIDs = nil; identityDir = nil;
        carrierName = nil; mcc = nil; mnc = nil;
        sourceName = nil; sourceMCC = nil; sourceMNC = nil;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
        operationView = nil;
#endif
    }
}

// Compute policy/RNG outside the lock. Only a matching revision may publish; a
// notification or another reader wins over an older candidate without retrying.
static int getWiFiSignalStrength() {
    PX_RUNTIME_READ_OPERATION;
    os_unfair_lock_lock(&gNetworkCacheLock);
    PXNetworkSignalState before = gWiFiSignal;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    double now = PXNetworkSignalNow();
    if (PXNetworkSignalFresh(now, before.updatedAt, before.hasTime, 30.0)) return before.value;

    NetworkConnectionType type = getNetworkConnectionType();
    int target;
    if (type == NetworkConnectionTypeWiFi || (type == NetworkConnectionTypeAuto && shouldUseWiFiForAutoMode())) {
        target = -45 - (int)arc4random_uniform(20);
    } else if (type == NetworkConnectionTypeCellular || (type == NetworkConnectionTypeAuto && !shouldUseWiFiForAutoMode())) {
        target = -60 - (int)arc4random_uniform(25);
    } else {
        target = -45 - (int)arc4random_uniform(45);
    }
    int current = before.value;
    int diff = target - current;
    if (diff > 3) current += 3;
    else if (diff < -3) current -= 3;
    else current = target;
    current += (int)arc4random_uniform(3) - 1;
    current = MAX(-90, MIN(-40, current));

    os_unfair_lock_lock(&gNetworkCacheLock);
    if (gWiFiSignal.revision == before.revision) {
        gWiFiSignal.value = current;
        gWiFiSignal.updatedAt = now;
        gWiFiSignal.hasTime = isfinite(now);
        gWiFiSignal.revision++;
    }
    int published = gWiFiSignal.value;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    return published;
}

static int getCellularSignalBars() {
    PX_RUNTIME_READ_OPERATION;
    os_unfair_lock_lock(&gNetworkCacheLock);
    PXNetworkSignalState before = gCellularSignal;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    double now = PXNetworkSignalNow();
    if (PXNetworkSignalFresh(now, before.updatedAt, before.hasTime, 30.0)) return before.value;

    NetworkConnectionType type = getNetworkConnectionType();
    int target;
    if (type == NetworkConnectionTypeCellular || (type == NetworkConnectionTypeAuto && !shouldUseWiFiForAutoMode())) {
        target = 3 + (int)arc4random_uniform(3);
    } else if (type == NetworkConnectionTypeWiFi || (type == NetworkConnectionTypeAuto && shouldUseWiFiForAutoMode())) {
        target = 1 + (int)arc4random_uniform(4);
    } else {
        target = 1 + (int)arc4random_uniform(5);
    }
    int current = before.value;
    if (target > current) current += 1;
    else if (target < current) current -= 1;
    current = MAX(1, MIN(5, current));

    os_unfair_lock_lock(&gNetworkCacheLock);
    if (gCellularSignal.revision == before.revision) {
        gCellularSignal.value = current;
        gCellularSignal.updatedAt = now;
        gCellularSignal.hasTime = isfinite(now);
        gCellularSignal.revision++;
    }
    int published = gCellularSignal.value;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    return published;
}

static NSString *getCurrentCellularNetworkType() {
    os_unfair_lock_lock(&gNetworkCacheLock);
    PXNetworkRadio radio = gNetworkRadio.value;
    double last = gNetworkRadio.changedAt;
    BOOL hasTime = gNetworkRadio.hasTime;
    uint64_t revision = gNetworkRadio.revision;
    int bars = gCellularSignal.value;
    os_unfair_lock_unlock(&gNetworkCacheLock);
    double now = PXNetworkSignalNow();

    if (!PXNetworkSignalFresh(now, last, hasTime, kMinNetworkTypeChangeDuration)) {
        if (arc4random_uniform(100) < 10) {
            double probability = bars >= 5 ? 0.85 : bars == 4 ? 0.65 : bars == 3 ? 0.40 : bars == 2 ? 0.15 : 0.05;
            double random = (double)arc4random_uniform(100) / 100.0;
            radio = random < probability
                ? (arc4random_uniform(100) < 70 ? PXNetworkRadioNRNSA : PXNetworkRadioNR)
                : PXNetworkRadioLTE;
            last = now;
            hasTime = isfinite(now);
        } else if (!hasTime || !isfinite(now) || now < last) {
            last = now;
            hasTime = isfinite(now);
        }
        // Preserve the 10% retry policy after 120s: a failed roll with a valid
        // previous timestamp does not start a new 120-second interval.
        os_unfair_lock_lock(&gNetworkCacheLock);
        if (gNetworkRadio.revision == revision) {
            gNetworkRadio.value = radio;
            gNetworkRadio.changedAt = last;
            gNetworkRadio.hasTime = hasTime;
            gNetworkRadio.revision++;
        }
        radio = gNetworkRadio.value;
        os_unfair_lock_unlock(&gNetworkCacheLock);
    }
    // NSString literals have process lifetime; no copy or destructor under lock.
    switch (radio) {
        case PXNetworkRadioNR: return @"CTRadioAccessTechnologyNR";
        case PXNetworkRadioNRNSA: return @"CTRadioAccessTechnologyNRNSA";
        default: return @"CTRadioAccessTechnologyLTE";
    }
}

#pragma mark - SCNetworkReachability Hooks

// Hook SCNetworkReachabilityGetFlags to modify network type
static Boolean (*original_SCNetworkReachabilityGetFlags)(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags *flags);

Boolean hooked_SCNetworkReachabilityGetFlags(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags *flags) {
    PX_RUNTIME_READ_OPERATION;
    Boolean result = original_SCNetworkReachabilityGetFlags(target, flags);
    if (!result || !flags || !shouldSpoofConnectionType()) {
        return result;
    }

    @try {
        if (shouldShowAsWiFi()) {
            *flags |= kSCNetworkReachabilityFlagsReachable;
            *flags &= ~kSCNetworkReachabilityFlagsIsWWAN;
        } else if (shouldShowAsCellular()) {
            *flags |= kSCNetworkReachabilityFlagsReachable;
            *flags |= kSCNetworkReachabilityFlagsIsWWAN;
        } else if (shouldShowAsNoConnection()) {
            *flags &= ~kSCNetworkReachabilityFlagsReachable;
            *flags &= ~kSCNetworkReachabilityFlagsIsWWAN;
        }
    } @catch (__unused NSException *exception) {}
    return result;
}

#pragma mark - CoreTelephony Hooks

// Hook for CTTelephonyNetworkInfo
%hook CTTelephonyNetworkInfo

- (NSDictionary<NSString *, CTCarrier *> *)serviceSubscriberCellularProviders {
    PX_RUNTIME_READ_OPERATION;
    if (shouldShowAsWiFi()) {
        return %orig;
    }
    
    NSDictionary<NSString *, CTCarrier *> *origDict = %orig;
    return origDict;
}

- (CTCarrier *)subscriberCellularProvider {
    PX_RUNTIME_READ_OPERATION;
    if (shouldShowAsWiFi()) {
        return %orig;
    }
    
    return %orig;
}

- (NSString *)currentRadioAccessTechnology {
    PX_RUNTIME_READ_OPERATION;
    if (shouldShowAsWiFi()) {
        return %orig;
    } else if (shouldShowAsCellular()) {
        return getCurrentCellularNetworkType();
    }
    return %orig;
}

- (NSDictionary<NSString *, NSString *> *)serviceCurrentRadioAccessTechnology {
    PX_RUNTIME_READ_OPERATION;
    if (shouldShowAsWiFi()) {
        return %orig;
    } else if (shouldShowAsCellular()) {
        return @{ @"0": getCurrentCellularNetworkType() };
    }
    return %orig;
}

%end

// Hook for CTCarrier
%hook CTCarrier

- (NSString *)carrierName {
    PX_RUNTIME_READ_OPERATION;
    if (shouldShowAsWiFi() && !shouldForceCarrierSpoof()) {
        return %orig;
    } else if (shouldShowAsCellular()) {
        return getCarrierDetailsFromProfile()[@"carrierName"];
    }
    if (shouldForceCarrierSpoof()) {
        return getCarrierDetailsFromProfile()[@"carrierName"];
    }
    return %orig;
}

- (NSString *)mobileCountryCode {
    PX_RUNTIME_READ_OPERATION;
    if (shouldShowAsWiFi() && !shouldForceCarrierSpoof()) {
        return %orig;
    } else if (shouldShowAsCellular()) {
        return getCarrierDetailsFromProfile()[@"mobileCountryCode"];
    }
    if (shouldForceCarrierSpoof()) {
        return getCarrierDetailsFromProfile()[@"mobileCountryCode"];
    }
    return %orig;
}

- (NSString *)mobileNetworkCode {
    PX_RUNTIME_READ_OPERATION;
    if (shouldShowAsWiFi() && !shouldForceCarrierSpoof()) {
        return %orig;
    } else if (shouldShowAsCellular()) {
        return getCarrierDetailsFromProfile()[@"mobileNetworkCode"];
    }
    if (shouldForceCarrierSpoof()) {
        return getCarrierDetailsFromProfile()[@"mobileNetworkCode"];
    }
    return %orig;
}

- (NSString *)isoCountryCode {
    PX_RUNTIME_READ_OPERATION;
    if (shouldShowAsWiFi() && !shouldForceCarrierSpoof()) {
        return %orig;
    } else if (shouldShowAsCellular()) {
        return getCurrentISOCountryCode();
    }
    if (shouldForceCarrierSpoof()) {
        return getCurrentISOCountryCode();
    }
    return %orig;
}

- (BOOL)allowsVOIP {
    PX_RUNTIME_READ_OPERATION;
    if (!shouldApplyNetworkSpoofing() || shouldShowAsWiFi() || shouldShowAsNoConnection()) {
        return %orig;
    }

    // Preserve the existing spoof behavior only while Network Data Spoof is active.
    return YES;
}

%end

#pragma mark - NSURLSession and CFNetwork Hooks

// Hook for cellular detection in NSURLSession
%hook NSURLSessionConfiguration

- (BOOL)allowsCellularAccess {
    PX_RUNTIME_READ_OPERATION;
    if (shouldShowAsWiFi()) {
        return %orig;
    }
    
    return %orig;
}

- (BOOL)isDiscretionary {
    PX_RUNTIME_READ_OPERATION;
    if (!shouldApplyNetworkSpoofing() || shouldShowAsWiFi() || shouldShowAsNoConnection()) {
        return %orig;
    }

    // Discretionary transfers are typically used for background transfers
    // that prefer WiFi. Preserve the legacy cellular-mode behavior only while active.
    return NO;
}

%end

#pragma mark - getifaddrs Hook for Local IP Address

// Enable getifaddrs hook for local IP spoofing
static void PXNetworkPostGetifaddrs(struct ifaddrs **ifap, int *inoutResult) {
    PX_RUNTIME_READ_OPERATION;
    if (!inoutResult || *inoutResult != 0 || !ifap || !*ifap || !shouldApplyNetworkSpoofing()) {
        return;
    }

    NetworkConnectionType type = getNetworkConnectionType();
    BOOL noConnection = (type == NetworkConnectionTypeNone);
    BOOL useWiFiInterface = (type == NetworkConnectionTypeWiFi ||
                             (type == NetworkConnectionTypeAuto && shouldUseWiFiForAutoMode()));
    const char *targetInterface = useWiFiInterface ? "en0" : "pdp_ip0";
    const char *clearInterface = useWiFiInterface ? "pdp_ip0" : "en0";

    NSString *spoofedIPv4 = getProfileLocalIPAddress();
    NSString *spoofedIPv6 = getProfileLocalIPv6Address();
    struct in_addr parsedIPv4;
    struct in6_addr parsedIPv6;
    BOOL hasSpoofedIPv4 = PXNetworkParseIPv4(spoofedIPv4, &parsedIPv4);
    BOOL hasSpoofedIPv6 = PXNetworkParseIPv6(spoofedIPv6, &parsedIPv6);

    if ((spoofedIPv4.length && !hasSpoofedIPv4) || (spoofedIPv6.length && !hasSpoofedIPv6)) {
        PXLog(@"[NetworkHook] Ignoring invalid stored local IP value(s)");
    }

    for (struct ifaddrs *ifa = *ifap; ifa; ifa = ifa->ifa_next) {
        if (!ifa->ifa_addr || !ifa->ifa_name) continue;

        BOOL isWiFi = strcmp(ifa->ifa_name, "en0") == 0;
        BOOL isCellular = strcmp(ifa->ifa_name, "pdp_ip0") == 0;
        if (!isWiFi && !isCellular) continue;

        sa_family_t family = ifa->ifa_addr->sa_family;
        if (noConnection) {
            if (family == AF_INET) {
                ((struct sockaddr_in *)ifa->ifa_addr)->sin_addr.s_addr = 0;
            } else if (family == AF_INET6) {
                memset(&((struct sockaddr_in6 *)ifa->ifa_addr)->sin6_addr, 0, sizeof(struct in6_addr));
            }
            continue;
        }

        BOOL isTarget = strcmp(ifa->ifa_name, targetInterface) == 0;
        BOOL isClear = strcmp(ifa->ifa_name, clearInterface) == 0;

        if (family == AF_INET) {
            struct sockaddr_in *sin = (struct sockaddr_in *)ifa->ifa_addr;
            if (isTarget && hasSpoofedIPv4) {
                sin->sin_addr = parsedIPv4;
            } else if (isClear) {
                sin->sin_addr.s_addr = 0;
            }
        } else if (family == AF_INET6) {
            struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)ifa->ifa_addr;
            if (isTarget && hasSpoofedIPv6) {
                sin6->sin6_addr = parsedIPv6;
            } else if (isClear) {
                memset(&sin6->sin6_addr, 0, sizeof(sin6->sin6_addr));
            }
        }
    }
}

#pragma mark - Network.framework Hooks (iOS 12+)

// Attempt to hook NWPathMonitor for newer iOS versions
%group NetworkFrameworkHooks

%hook NWPath

- (BOOL)isExpensive {
    PX_RUNTIME_READ_OPERATION;
    if (!shouldApplyNetworkSpoofing() || shouldShowAsNoConnection()) {
        return %orig;
    }

    // WiFi is not expensive, cellular is.
    return shouldShowAsCellular();
}

- (BOOL)usesInterfaceType:(NSInteger)type {
    PX_RUNTIME_READ_OPERATION;
    if (!shouldApplyNetworkSpoofing()) {
        return %orig;
    }

    if (shouldShowAsNoConnection()) {
        if (type == 1 || type == 2) return NO;
        return %orig;
    }

    if (shouldShowAsWiFi()) {
        if (type == 1) return YES;
        if (type == 2) return NO;
    } else if (shouldShowAsCellular()) {
        if (type == 1) return NO;
        if (type == 2) return YES;
    }

    return %orig;
}

%end

%end

// Notification callback for settings changes
static void networkSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXNetworkInvalidateCaches();
}

// Notification callback for ISO country code changes
static void isoCountryCodeChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXNetworkInvalidateCaches();
}

// Notification callback for scoped apps changes
static void scopedAppsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXNetworkInvalidateCaches();
    PXInvalidateScopeDecisionCache();
}

// Notification callback for carrier details changes
static void carrierDetailsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXNetworkInvalidateCaches();
}

// Notification callback for signal strength settings changes
static void signalStrengthSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    PXNetworkInvalidateCaches();
}

// Hook for WiFi signal strength (CNCopyCurrentNetworkInfo)
static CFDictionaryRef (*original_CNCopyCurrentNetworkInfo)(CFStringRef interfaceName);

static CFDictionaryRef hooked_CNCopyCurrentNetworkInfo(CFStringRef interfaceName) {
    PX_RUNTIME_READ_OPERATION;
    if (!shouldApplyNetworkSpoofing() || shouldShowAsWiFi() || shouldShowAsNoConnection()) {
        return original_CNCopyCurrentNetworkInfo(interfaceName);
    }
    // Always call the original so WiFiHook.x can spoof as needed
    CFDictionaryRef originalDict = original_CNCopyCurrentNetworkInfo(interfaceName);
    if (!originalDict) return originalDict;
    // Existing WiFi signal strength spoofing logic
    CFMutableDictionaryRef newDict = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, originalDict);
    int signalStrength = getWiFiSignalStrength();
    CFNumberRef rssiNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &signalStrength);
    CFDictionarySetValue(newDict, CFSTR("RSSI"), rssiNumber);
    CFRelease(originalDict);
    CFRelease(rssiNumber);
    return newDict;
}

// Add hooks for CoreTelephony signal strength
%hook CTServiceDescriptor

- (NSString *)signalStrengthBars {
    PX_RUNTIME_READ_OPERATION;
    if (!shouldApplyNetworkSpoofing() || shouldShowAsWiFi() || shouldShowAsNoConnection()) {
        return %orig;
    }

    int bars = getCellularSignalBars();
    NSString *barsString = [NSString stringWithFormat:@"%d", bars];
    PXLog(@"[NetworkHook] Spoofed cellular signal bars to %@", barsString);
    return barsString;
}

%end

%hook UIStatusBarSignalStrengthItemView

- (void)setCellularSignalStrengthBars:(int)bars {
    PX_RUNTIME_READ_OPERATION;
    if (!shouldApplyNetworkSpoofing() || shouldShowAsWiFi() || shouldShowAsNoConnection()) {
        %orig;
        return;
    }

    int spoofedBars = getCellularSignalBars();
    PXLog(@"[NetworkHook] Spoofed UI cellular signal bars from %d to %d", bars, spoofedBars);
    %orig(spoofedBars);
}

%end

#pragma mark - Initialization

%ctor {
    @autoreleasepool {
        if (!PXBootstrapAllows(PXHookCapabilityNative)) return;
        if (PXIsSpringBoardProcess()) return;

        NSString *bundleID = getCurrentBundleID();
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (PXIsCriticalSystemProcess(bundleID, proc)) return;
        if (PXIsWebKitHelperProcess(bundleID, proc)) return;

        BOOL isScoped = PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack);
        if (!isScoped) return;
        PXLog(@"[NetworkHook] Installing network hooks for %@", bundleID ?: @"(unknown)");

        {
            // Initialize CoreTelephony hooks
            %init;
            
            // Initialize Network.framework hooks if available
            Class NWPathClass = NSClassFromString(@"NWPath");
            if (NWPathClass) {
                %init(NetworkFrameworkHooks);
                PXLog(@"[NetworkHook] Successfully initialized Network.framework hooks");
            }
            
            // Setup the SCNetworkReachabilityGetFlags hook
            void *SCNetworkReachabilityGetFlagsPtr = dlsym(RTLD_DEFAULT, "SCNetworkReachabilityGetFlags");
            if (SCNetworkReachabilityGetFlagsPtr) {
                // Use ElleKit for hooking (preferred for iOS 15+)
                MSHookFunction(SCNetworkReachabilityGetFlagsPtr, 
                       (void *)hooked_SCNetworkReachabilityGetFlags, 
                       (void **)&original_SCNetworkReachabilityGetFlags);
                PXLog(@"[NetworkHook] Successfully hooked SCNetworkReachabilityGetFlags");
            } else {
                PXLog(@"[NetworkHook] ERROR: Could not find SCNetworkReachabilityGetFlags function!");
            }
            
            // getifaddrs is coordinator-owned — skip direct MSHookFunction (Tweak/network providers).
            PXNativeHookCoordinator *nativeCoordinator = [PXNativeHookCoordinator sharedCoordinator];
            [nativeCoordinator registerGetifaddrsProvider:@"network.local-ip"
                                                  priority:PXNativeHookPriorityNetworkStorage
                                                       pre:nil
                                                      post:^(struct ifaddrs **ifap, int *result) {
    PX_RUNTIME_READ_OPERATION;
                PXNetworkPostGetifaddrs(ifap, result);
            }];
            [nativeCoordinator installOwnedSymbolsIfNeeded];
            
            // Note: We don't hook CNCopySupportedInterfaces or CNCopyCurrentNetworkInfo
            // as they are already handled by WiFiHook.x for SSID/BSSID spoofing
            
            // Register for notification when settings change
            CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
            CFNotificationCenterAddObserver(darwinCenter, NULL, networkSettingsChanged,
                                           CFSTR("com.hydra.tlinkios.settings.changed"), NULL,
                                           CFNotificationSuspensionBehaviorDeliverImmediately);
            CFNotificationCenterAddObserver(darwinCenter, NULL, networkSettingsChanged,
                                           CFSTR("com.hydra.tlinkios.profileChanged"), NULL,
                                           CFNotificationSuspensionBehaviorDeliverImmediately);
            CFNotificationCenterAddObserver(darwinCenter, NULL, networkSettingsChanged,
                                           CFSTR("com.hydra.tlinkios.networkDataSpoofChanged"), NULL,
                                           CFNotificationSuspensionBehaviorDeliverImmediately);
            CFNotificationCenterAddObserver(darwinCenter,
                                           NULL,
                                           networkSettingsChanged,
                                           CFSTR("com.hydra.tlinkios.networkConnectionTypeChanged"),
                                           NULL,
                                           CFNotificationSuspensionBehaviorDeliverImmediately);
            
            // Register for notification when ISO country code changes
            CFNotificationCenterAddObserver(darwinCenter,
                                           NULL,
                                           isoCountryCodeChanged,
                                           CFSTR("com.hydra.tlinkios.networkISOCountryCodeChanged"),
                                           NULL,
                                           CFNotificationSuspensionBehaviorDeliverImmediately);
            
            // Register for notification when scoped apps change
            CFNotificationCenterAddObserver(darwinCenter,
                                           NULL,
                                           scopedAppsChanged,
                                           CFSTR("com.hydra.tlinkios.scopedAppsChanged"),
                                           NULL,
                                           CFNotificationSuspensionBehaviorDeliverImmediately);
            
            // Register for notification when carrier details change
            CFNotificationCenterAddObserver(darwinCenter,
                                           NULL,
                                           carrierDetailsChanged,
                                           CFSTR("com.hydra.tlinkios.carrierDetailsChanged"),
                                           NULL,
                                           CFNotificationSuspensionBehaviorDeliverImmediately);
            
            // Register for notification when signal strength settings change
            CFNotificationCenterAddObserver(darwinCenter,
                                           NULL,
                                           signalStrengthSettingsChanged,
                                           CFSTR("com.hydra.tlinkios.signalStrengthSettingsChanged"),
                                           NULL,
                                           CFNotificationSuspensionBehaviorDeliverImmediately);
            
            // Log initial state
            NetworkConnectionType initialType = getNetworkConnectionType();
            if (initialType != -1) {
                NSString *connectionName;
                switch (initialType) {
                    case NetworkConnectionTypeNone:
                        connectionName = @"None";
                        break;
                    case NetworkConnectionTypeWiFi:
                        connectionName = @"WiFi";
                        break;
                    case NetworkConnectionTypeCellular:
                        connectionName = @"Cellular";
                        break;
                    case NetworkConnectionTypeAuto:
                        connectionName = @"Auto";
                        break;
                    default:
                        connectionName = @"Unknown";
                        break;
                }
                
                if (initialType == NetworkConnectionTypeWiFi || 
                    (initialType == NetworkConnectionTypeAuto && shouldUseWiFiForAutoMode())) {
                    NSString *localIP = getProfileLocalIPAddress();
                    PXLog(@"[NetworkHook] Network connection type spoofing enabled with type: %@ (Local IP: %@) for scoped app: %@", 
                          connectionName, localIP, bundleID);
                } else if (initialType == NetworkConnectionTypeCellular ||
                          (initialType == NetworkConnectionTypeAuto && !shouldUseWiFiForAutoMode())) {
                    NSString *isoCode = getCurrentISOCountryCode();
                    PXLog(@"[NetworkHook] Network connection type spoofing enabled with type: %@ (ISO: %@) for scoped app: %@", 
                          connectionName, isoCode, bundleID);
                } else {
                    PXLog(@"[NetworkHook] Network connection type spoofing enabled with type: %@ for scoped app: %@", 
                          connectionName, bundleID);
                }
            } else {
                PXLog(@"[NetworkHook] Network connection type spoofing disabled");
            }
            
            // CNCopyCurrentNetworkInfo: WiFi module builds final dictionary; network provides policy only.
            // Do not install a second MSHookFunction — coordinator owns the symbol.
            PXLog(@"[NetworkHook] Skipping direct CNCopyCurrentNetworkInfo hook (coordinator/WiFi owns; policy-only)");
        }
    }
} 
