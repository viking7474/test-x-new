#import "PXConsistencyMatrix.h"

@interface PXConsistencyMatrixEntry ()
@property (nonatomic, copy, readwrite) NSString *surface;
@property (nonatomic, copy, readwrite) NSString *key;
@property (nonatomic, copy, readwrite) NSString *group;
@property (nonatomic, copy, readwrite) NSString *toggle;
@property (nonatomic, readwrite) PXConsistencySourceKind sourceKind;
@property (nonatomic, copy, readwrite, nullable) NSString *deviceIDKey;
@property (nonatomic, copy, readwrite, nullable) NSString *constantValue;
@end

@implementation PXConsistencyMatrixEntry
@end

static PXConsistencyMatrixEntry *PXKeyEntry(NSString *surface, NSString *key,
                                            NSString *group, NSString *toggle,
                                            NSString *deviceIDKey) {
    PXConsistencyMatrixEntry *entry = [[PXConsistencyMatrixEntry alloc] init];
    entry.surface = surface;
    entry.key = key;
    entry.group = group;
    entry.toggle = toggle;
    entry.sourceKind = PXConsistencySourceDeviceIDKey;
    entry.deviceIDKey = deviceIDKey;
    return entry;
}

static PXConsistencyMatrixEntry *PXConstEntry(NSString *surface, NSString *key,
                                              NSString *group, NSString *toggle,
                                              NSString *constantValue) {
    PXConsistencyMatrixEntry *entry = [[PXConsistencyMatrixEntry alloc] init];
    entry.surface = surface;
    entry.key = key;
    entry.group = group;
    entry.toggle = toggle;
    entry.sourceKind = PXConsistencySourceConstant;
    entry.constantValue = constantValue;
    return entry;
}

NSArray<PXConsistencyMatrixEntry *> *PXConsistencyMatrixEntries(void) {
    static NSArray<PXConsistencyMatrixEntry *> *entries = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        entries = @[
            // --- ProductVersion (marketing iOS version) ---
            PXKeyEntry(@"CFSystem", @"ProductVersion", @"ProductVersion", @"IOSVersion", @"IOSVersion"),
            PXKeyEntry(@"SystemVersion.plist", @"ProductVersion", @"ProductVersion", @"IOSVersion", @"IOSVersion"),
            PXKeyEntry(@"sysctlbyname", @"kern.osproductversion", @"ProductVersion", @"IOSVersion", @"IOSVersion"),

            // --- ProductBuildVersion (build number) ---
            PXKeyEntry(@"CFSystem", @"ProductBuildVersion", @"ProductBuildVersion", @"IOSVersion", @"IOSBuild"),
            PXKeyEntry(@"SystemVersion.plist", @"ProductBuildVersion", @"ProductBuildVersion", @"IOSVersion", @"IOSBuild"),
            PXKeyEntry(@"sysctl", @"CTL_KERN/KERN_OSVERSION", @"ProductBuildVersion", @"IOSVersion", @"IOSBuild"),
            PXKeyEntry(@"sysctlbyname", @"kern.osversion", @"ProductBuildVersion", @"IOSVersion", @"IOSBuild"),
            PXKeyEntry(@"MG", @"ProductBuildVersion", @"ProductBuildVersion", @"IOSVersion", @"IOSBuild"),
            PXKeyEntry(@"MG", @"BuildVersion", @"ProductBuildVersion", @"IOSVersion", @"IOSBuild"),

            // --- ReleaseType (always "User" for a shipping device) ---
            PXConstEntry(@"CFSystem", @"ReleaseType", @"ReleaseType", @"IOSVersion", @"User"),
            PXConstEntry(@"SystemVersion.plist", @"ReleaseType", @"ReleaseType", @"IOSVersion", @"User"),
            PXConstEntry(@"MG", @"ReleaseType", @"ReleaseType", @"IOSVersion", @"User"),

            // --- Darwin (kernel release string, e.g. 23.5.0) ---
            PXKeyEntry(@"sysctl", @"CTL_KERN/KERN_OSRELEASE", @"Darwin", @"IOSVersion", @"Darwin"),
            PXKeyEntry(@"sysctlbyname", @"kern.osrelease", @"Darwin", @"IOSVersion", @"Darwin"),
            PXKeyEntry(@"uname", @"release", @"Darwin", @"IOSVersion", @"Darwin"),

            // --- KernelVersion (full kernel version banner) ---
            PXKeyEntry(@"sysctl", @"CTL_KERN/KERN_VERSION", @"KernelVersion", @"IOSVersion", @"KernelVersion"),
            PXKeyEntry(@"sysctlbyname", @"kern.version", @"KernelVersion", @"IOSVersion", @"KernelVersion"),
            PXKeyEntry(@"uname", @"version", @"KernelVersion", @"IOSVersion", @"KernelVersion"),

            // --- OSType (kernel name; always "Darwin") ---
            PXConstEntry(@"sysctlbyname", @"kern.ostype", @"OSType", @"IOSVersion", @"Darwin"),
            PXConstEntry(@"uname", @"sysname", @"OSType", @"IOSVersion", @"Darwin"),

            // --- DeviceModel (product identifier, e.g. iPhone15,3) ---
            PXKeyEntry(@"sysctl", @"CTL_HW/HW_MACHINE", @"DeviceModel", @"DeviceModel", @"DeviceModel"),
            PXKeyEntry(@"sysctlbyname", @"hw.machine", @"DeviceModel", @"DeviceModel", @"DeviceModel"),
            PXKeyEntry(@"sysctlbyname", @"hw.product", @"DeviceModel", @"DeviceModel", @"DeviceModel"),
            PXKeyEntry(@"MG", @"ProductType", @"DeviceModel", @"DeviceModel", @"DeviceModel"),
            PXKeyEntry(@"IOKit", @"device-model", @"DeviceModel", @"DeviceModel", @"DeviceModel"),
            PXKeyEntry(@"uname", @"machine", @"DeviceModel", @"DeviceModel", @"DeviceModel"),

            // --- HwModel (board/marketing hw string, e.g. D74AP) ---
            PXKeyEntry(@"sysctl", @"CTL_HW/HW_MODEL", @"HwModel", @"DeviceModel", @"HwModel"),
            PXKeyEntry(@"sysctlbyname", @"hw.model", @"HwModel", @"DeviceModel", @"HwModel"),
            PXKeyEntry(@"MG", @"HWModel", @"HwModel", @"DeviceModel", @"HwModel"),
            PXKeyEntry(@"MG", @"HWModelStr", @"HwModel", @"DeviceModel", @"HwModel"),
            PXKeyEntry(@"IOKit", @"model", @"HwModel", @"DeviceModel", @"HwModel"),

            // --- BoardID ---
            PXKeyEntry(@"MG", @"BoardId", @"BoardID", @"DeviceModel", @"BoardID"),
            PXKeyEntry(@"IOKit", @"board-id", @"BoardID", @"DeviceModel", @"BoardID"),

            // --- ModelNumber (Axxxx) ---
            PXKeyEntry(@"MG", @"ModelNumber", @"ModelNumber", @"DeviceModel", @"ModelNumber"),
            PXKeyEntry(@"IOKit", @"model-number", @"ModelNumber", @"DeviceModel", @"ModelNumber"),

            // --- DeviceName (user-facing hostname) ---
            PXKeyEntry(@"sysctlbyname", @"kern.hostname", @"DeviceName", @"DeviceName", @"DeviceName"),
            PXKeyEntry(@"gethostname", @"gethostname", @"DeviceName", @"DeviceName", @"DeviceName"),
            PXKeyEntry(@"uname", @"nodename", @"DeviceName", @"DeviceName", @"DeviceName"),
        ];
    });
    return entries;
}

NSString *PXConsistencyResolveEntryValue(PXConsistencyMatrixEntry *entry, NSDictionary *deviceIDs) {
    if (![entry isKindOfClass:[PXConsistencyMatrixEntry class]]) return nil;
    if (entry.sourceKind == PXConsistencySourceConstant) {
        return entry.constantValue.length ? entry.constantValue : nil;
    }
    if (![deviceIDs isKindOfClass:[NSDictionary class]]) return nil;
    id raw = deviceIDs[entry.deviceIDKey];
    if (![raw isKindOfClass:[NSString class]]) return nil;
    NSString *value = (NSString *)raw;
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length ? value : nil;
}

static NSArray<NSString *> *PXOrderedGroups(void) {
    NSMutableArray<NSString *> *groups = [NSMutableArray array];
    for (PXConsistencyMatrixEntry *entry in PXConsistencyMatrixEntries()) {
        if (![groups containsObject:entry.group]) [groups addObject:entry.group];
    }
    return groups;
}

static NSArray<PXConsistencyMatrixEntry *> *PXEntriesForGroup(NSString *group) {
    NSMutableArray<PXConsistencyMatrixEntry *> *result = [NSMutableArray array];
    for (PXConsistencyMatrixEntry *entry in PXConsistencyMatrixEntries()) {
        if ([entry.group isEqualToString:group]) [result addObject:entry];
    }
    return result;
}

BOOL PXConsistencyMatrixIsWellFormed(NSArray<NSString *> **outFailures) {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    for (NSString *group in PXOrderedGroups()) {
        NSArray<PXConsistencyMatrixEntry *> *entries = PXEntriesForGroup(group);
        NSString *expectedKey = nil;
        NSString *expectedConst = nil;
        NSString *expectedToggle = nil;
        PXConsistencySourceKind expectedKind = entries.firstObject.sourceKind;
        for (PXConsistencyMatrixEntry *entry in entries) {
            if (entry.sourceKind != expectedKind) {
                [failures addObject:[NSString stringWithFormat:
                    @"group %@: mixes deviceID-key and constant sources", group]];
                break;
            }
            if (entry.sourceKind == PXConsistencySourceDeviceIDKey) {
                if (entry.deviceIDKey.length == 0) {
                    [failures addObject:[NSString stringWithFormat:
                        @"group %@: %@/%@ has empty deviceIDKey", group, entry.surface, entry.key]];
                } else if (!expectedKey) {
                    expectedKey = entry.deviceIDKey;
                } else if (![expectedKey isEqualToString:entry.deviceIDKey]) {
                    [failures addObject:[NSString stringWithFormat:
                        @"group %@: deviceIDKey diverges (%@ vs %@)", group, expectedKey, entry.deviceIDKey]];
                }
            } else {
                if (entry.constantValue.length == 0) {
                    [failures addObject:[NSString stringWithFormat:
                        @"group %@: %@/%@ has empty constant", group, entry.surface, entry.key]];
                } else if (!expectedConst) {
                    expectedConst = entry.constantValue;
                } else if (![expectedConst isEqualToString:entry.constantValue]) {
                    [failures addObject:[NSString stringWithFormat:
                        @"group %@: constant diverges (%@ vs %@)", group, expectedConst, entry.constantValue]];
                }
            }
            if (!expectedToggle) {
                expectedToggle = entry.toggle;
            } else if (![expectedToggle isEqualToString:entry.toggle]) {
                [failures addObject:[NSString stringWithFormat:
                    @"group %@: toggle diverges (%@ vs %@)", group, expectedToggle, entry.toggle]];
            }
        }
    }
    if (outFailures) *outFailures = failures;
    return failures.count == 0;
}

BOOL PXValidateConsistencyMatrix(NSDictionary *deviceIDs, NSArray<NSString *> **outFailures) {
    NSMutableArray<NSString *> *failures = [NSMutableArray array];
    for (NSString *group in PXOrderedGroups()) {
        NSArray<PXConsistencyMatrixEntry *> *entries = PXEntriesForGroup(group);
        NSString *expected = nil;
        PXConsistencyMatrixEntry *expectedFrom = nil;
        NSUInteger resolvedCount = 0;
        for (PXConsistencyMatrixEntry *entry in entries) {
            NSString *value = PXConsistencyResolveEntryValue(entry, deviceIDs);
            if (!value) continue;
            resolvedCount += 1;
            if (!expected) {
                expected = value;
                expectedFrom = entry;
            } else if (![expected isEqualToString:value]) {
                [failures addObject:[NSString stringWithFormat:
                    @"group %@: %@/%@=\"%@\" != %@/%@=\"%@\"",
                    group, expectedFrom.surface, expectedFrom.key, expected,
                    entry.surface, entry.key, value]];
            }
        }
        // A group that resolves for some surfaces but not all indicates a partial
        // projection: the profile would look self-inconsistent to an app.
        if (resolvedCount > 0 && resolvedCount < entries.count) {
            [failures addObject:[NSString stringWithFormat:
                @"group %@: partial projection (%lu of %lu surfaces resolvable)",
                group, (unsigned long)resolvedCount, (unsigned long)entries.count]];
        }
    }
    if (outFailures) *outFailures = failures;
    return failures.count == 0;
}
