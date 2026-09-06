#import "PXRuntimeOSCompatibility.h"
#import "PXSecuritySettingsStore.h"
#import <fcntl.h>
#import <sys/stat.h>
#import <unistd.h>

static NSString *PXRuntimeOSString(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *trimmed = [(NSString *)value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return trimmed.length ? trimmed : nil;
}

static NSArray<NSNumber *> *PXRuntimeOSVersionComponents(NSString *version) {
    NSString *v = PXRuntimeOSString(version);
    if (!v.length) return nil;
    NSArray<NSString *> *parts = [v componentsSeparatedByString:@"."];
    if (parts.count == 0) return nil;
    NSMutableArray<NSNumber *> *numbers = [NSMutableArray arrayWithCapacity:3];
    for (NSUInteger i = 0; i < 3; i++) {
        if (i >= parts.count) {
            [numbers addObject:@0];
            continue;
        }
        NSString *part = parts[i];
        if (!part.length) return nil;
        NSScanner *scanner = [NSScanner scannerWithString:part];
        NSInteger value = 0;
        if (![scanner scanInteger:&value] || !scanner.isAtEnd || value < 0) return nil;
        [numbers addObject:@(value)];
    }
    return numbers;
}

static NSComparisonResult PXRuntimeOSCompareVersions(NSString *lhs, NSString *rhs) {
    NSArray<NSNumber *> *a = PXRuntimeOSVersionComponents(lhs);
    NSArray<NSNumber *> *b = PXRuntimeOSVersionComponents(rhs);
    if (a.count != 3 || b.count != 3) return NSOrderedSame;
    for (NSUInteger i = 0; i < 3; i++) {
        NSInteger av = a[i].integerValue;
        NSInteger bv = b[i].integerValue;
        if (av < bv) return NSOrderedAscending;
        if (av > bv) return NSOrderedDescending;
    }
    return NSOrderedSame;
}

static NSDictionary<NSString *, NSString *> *PXReadRealRuntimeSystemVersionPlist(void) {
    static NSString *const path = @"/System/Library/CoreServices/SystemVersion.plist";
    int fd = open(path.fileSystemRepresentation, O_RDONLY);
    if (fd < 0) return nil;

    struct stat st = {0};
    if (fstat(fd, &st) != 0 || st.st_size <= 0 || st.st_size > (1024 * 1024)) {
        close(fd);
        return nil;
    }

    NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)st.st_size];
    uint8_t *bytes = data.mutableBytes;
    ssize_t remaining = st.st_size;
    ssize_t offset = 0;
    while (remaining > 0) {
        ssize_t count = read(fd, bytes + offset, (size_t)remaining);
        if (count <= 0) {
            close(fd);
            return nil;
        }
        offset += count;
        remaining -= count;
    }
    close(fd);

    NSError *error = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:NSPropertyListImmutable
                                                          format:NULL
                                                           error:&error];
    if (error || ![plist isKindOfClass:[NSDictionary class]]) return nil;
    NSString *version = PXRuntimeOSString(plist[@"ProductVersion"]);
    NSString *build = PXRuntimeOSString(plist[@"ProductBuildVersion"]);
    if (!version.length || !build.length || !PXRuntimeOSVersionComponents(version)) return nil;
    return @{ @"version": version, @"build": build };
}

NSDictionary<NSString *, NSString *> *PXRealRuntimeOSInfo(void) {
    static NSDictionary<NSString *, NSString *> *info = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        info = [PXReadRealRuntimeSystemVersionPlist() copy];
    });
    return info;
}

NSString *PXRealRuntimeIOSVersion(void) {
    return PXRealRuntimeOSInfo()[@"version"];
}

NSString *PXRealRuntimeIOSBuild(void) {
    return PXRealRuntimeOSInfo()[@"build"];
}

BOOL PXRealRuntimeIOSVersionIsAtLeast(NSString *minimumVersion) {
    NSString *real = PXRealRuntimeIOSVersion();
    NSString *minimum = PXRuntimeOSString(minimumVersion);
    if (!real.length || !minimum.length || !PXRuntimeOSVersionComponents(real) || !PXRuntimeOSVersionComponents(minimum)) {
        return NO;
    }
    return PXRuntimeOSCompareVersions(real, minimum) != NSOrderedAscending;
}

BOOL PXConfiguredIOSVersionExceedsRealRuntime(NSString *configuredVersion) {
    NSString *configured = PXRuntimeOSString(configuredVersion);
    NSString *real = PXRealRuntimeIOSVersion();
    if (!configured.length || !real.length || !PXRuntimeOSVersionComponents(configured) || !PXRuntimeOSVersionComponents(real)) {
        return NO;
    }
    return PXRuntimeOSCompareVersions(configured, real) == NSOrderedDescending;
}

BOOL PXFixVersionAppliesToBundle(NSString *bundleID) {
    NSString *bundle = PXRuntimeOSString(bundleID);
    if (!bundle.length || !PXReadSecurityBool(@"fixVersionEnabled", NO)) return NO;
    id rawApps = PXReadSecuritySetting(@"fixVersionApps");
    if (![rawApps isKindOfClass:[NSArray class]]) return NO;
    for (id item in (NSArray *)rawApps) {
        if ([item isKindOfClass:[NSString class]] && [(NSString *)item isEqualToString:bundle]) {
            return YES;
        }
    }
    return NO;
}

BOOL PXReportingIOSVersionBuildForBundle(NSString *configuredVersion,
                                         NSString *configuredBuild,
                                         NSString *bundleID,
                                         NSString **outVersion,
                                         NSString **outBuild) {
    (void)bundleID;
    NSString *configuredV = PXRuntimeOSString(configuredVersion);
    NSString *configuredB = PXRuntimeOSString(configuredBuild);
    if (!configuredV.length || !configuredB.length || !PXRuntimeOSVersionComponents(configuredV)) return NO;

    // Legacy Fix Version semantics are intentionally narrow: this reporting helper
    // always exposes the configured profile. The only per-app runtime fallback is
    // kern.osproductversion in Tweak.x, where selected apps leave that query unhandled.
    if (outVersion) *outVersion = configuredV;
    if (outBuild) *outBuild = configuredB;
    return YES;
}

NSString *PXReportingIOSValueForDeviceIDKey(NSString *key, NSDictionary *deviceIDs, NSString *bundleID) {
    if (![key isKindOfClass:[NSString class]] || ![deviceIDs isKindOfClass:[NSDictionary class]]) return nil;
    id raw = deviceIDs[key];
    if (![key isEqualToString:@"IOSVersion"] && ![key isEqualToString:@"IOSBuild"]) {
        return PXRuntimeOSString(raw);
    }

    NSString *reportedVersion = nil;
    NSString *reportedBuild = nil;
    if (!PXReportingIOSVersionBuildForBundle(deviceIDs[@"IOSVersion"],
                                              deviceIDs[@"IOSBuild"],
                                              bundleID,
                                              &reportedVersion,
                                              &reportedBuild)) {
        return nil;
    }
    return [key isEqualToString:@"IOSVersion"] ? reportedVersion : reportedBuild;
}

BOOL PXNativeIOSProfileMayExposeKernelTuple(NSString *configuredVersion, NSString *configuredBuild) {
    NSString *safeVersion = nil;
    NSString *safeBuild = nil;
    if (!PXNativeSafeIOSVersionBuild(configuredVersion, configuredBuild, &safeVersion, &safeBuild)) return NO;
    NSString *configuredV = PXRuntimeOSString(configuredVersion);
    NSString *configuredB = PXRuntimeOSString(configuredBuild);
    return configuredV.length && configuredB.length &&
           [safeVersion isEqualToString:configuredV] && [safeBuild isEqualToString:configuredB];
}

BOOL PXNativeSafeIOSVersionBuild(NSString *configuredVersion,
                                 NSString *configuredBuild,
                                 NSString **outVersion,
                                 NSString **outBuild) {
    NSString *configuredV = PXRuntimeOSString(configuredVersion);
    NSString *configuredB = PXRuntimeOSString(configuredBuild);
    NSString *realV = PXRealRuntimeIOSVersion();
    NSString *realB = PXRealRuntimeIOSBuild();
    if (!configuredV.length || !configuredB.length || !realV.length || !realB.length ||
        !PXRuntimeOSVersionComponents(configuredV) || !PXRuntimeOSVersionComponents(realV)) {
        return NO;
    }

    BOOL clampToRuntime = PXRuntimeOSCompareVersions(configuredV, realV) == NSOrderedDescending;
    NSString *safeV = clampToRuntime ? realV : configuredV;
    NSString *safeB = clampToRuntime ? realB : configuredB;
    if (outVersion) *outVersion = safeV;
    if (outBuild) *outBuild = safeB;
    return YES;
}

BOOL PXKernelIOSProfileMayExposeTupleForBundle(NSString *configuredVersion,
                                                NSString *configuredBuild,
                                                NSString *bundleID) {
    (void)bundleID;
    NSString *configuredV = PXRuntimeOSString(configuredVersion);
    NSString *configuredB = PXRuntimeOSString(configuredBuild);
    return configuredV.length && configuredB.length && PXRuntimeOSVersionComponents(configuredV) != nil;
}
