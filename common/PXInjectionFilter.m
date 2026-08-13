#import "PXInjectionFilter.h"

NSString * const PXInjectionPlaceholderBundleID = @"com.hydra.tlinkios.no-injection-placeholder";
NSString * const PXInjectionSpringBoardBundleID = @"com.apple.springboard";
static NSString * const PXInjectionLegacyPlaceholderBundleID = @"com.hydra.projectx.no-injection-placeholder";

NSArray<NSString *> *PXInjectionNormalizeBundleList(NSArray *bundles) {
    NSMutableOrderedSet<NSString *> *set = [NSMutableOrderedSet orderedSet];
    for (id obj in bundles) {
        if (![obj isKindOfClass:[NSString class]]) continue;
        NSString *bid = (NSString *)obj;
        if (!bid.length) continue;
        [set addObject:bid];
    }
    return [set.array sortedArrayUsingSelector:@selector(compare:)];
}

BOOL PXInjectionBundleIsTLinkIOSApp(NSString *bundleID) {
    if (![bundleID isKindOfClass:[NSString class]]) return NO;
    return [bundleID isEqualToString:@"com.hydra.tlinkios"] ||
           [bundleID isEqualToString:@"com.hydra.projectx"] ||
           [bundleID isEqualToString:@"com.hydra.weaponx"];
}

BOOL PXInjectionBundleIsAppleOrWebKit(NSString *bundleID) {
    if (![bundleID isKindOfClass:[NSString class]] || !bundleID.length) return YES;
    if ([bundleID hasPrefix:@"com.apple."]) return YES;
    // Defensive: any WebKit-named helper outside the com.apple. prefix set.
    if ([bundleID rangeOfString:@"WebKit" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    return NO;
}

NSArray<NSString *> *PXInjectionDefaultWebKitHelperBundleIDs(void) {
    return @[
        @"com.apple.SafariViewService",
        @"com.apple.WebKit.WebContent",
        @"com.apple.WebKit.Networking",
        @"com.apple.WebKit.GPU"
    ];
}

NSArray<NSString *> *PXInjectionEnabledMainBundlesFromScopePlist(NSDictionary *scopePlist) {
    NSDictionary *scopedApps = [scopePlist[@"ScopedApps"] isKindOfClass:[NSDictionary class]] ? scopePlist[@"ScopedApps"] : nil;
    NSMutableArray<NSString *> *bundleIDs = [NSMutableArray array];
    [scopedApps enumerateKeysAndObjectsUsingBlock:^(NSString *bundleID, NSDictionary *entry, BOOL *stop) {
        (void)stop;
        if (![bundleID isKindOfClass:[NSString class]] || !bundleID.length) return;
        if (PXInjectionBundleIsTLinkIOSApp(bundleID)) return;
        if ([bundleID hasPrefix:@"com.apple.WebKit"] || [bundleID isEqualToString:@"com.apple.SafariViewService"]) return;
        if ([entry isKindOfClass:[NSDictionary class]] && ![entry[@"enabled"] boolValue]) return;
        [bundleIDs addObject:bundleID];
    }];
    return PXInjectionNormalizeBundleList(bundleIDs);
}

NSArray<NSString *> *PXInjectionComputeTweakBundles(NSArray<NSString *> *expandedEnabledBundles) {
    NSArray<NSString *> *normalizedEnabled = PXInjectionNormalizeBundleList(expandedEnabledBundles ?: @[]);
    // Empty state (no scoped apps): write the no-injection placeholder ONLY — never Bundles=[]
    // and never SpringBoard — so the tweak filter matches the keychain bridge and the daemon
    // accepts a placeholder-only plist (Newplan: "remove all apps -> installed filter only placeholder").
    if (normalizedEnabled.count == 0) {
        return @[PXInjectionPlaceholderBundleID];
    }
    // Non-empty scope: Profile Indicator runs inside SpringBoard, so add it alongside the scoped
    // apps. The list is guaranteed non-empty here, so it must never carry the placeholder.
    NSMutableArray<NSString *> *withSystem = [NSMutableArray arrayWithArray:normalizedEnabled];
    if (![withSystem containsObject:PXInjectionSpringBoardBundleID]) {
        [withSystem addObject:PXInjectionSpringBoardBundleID];
    }
    return PXInjectionNormalizeBundleList(withSystem);
}

NSArray<NSString *> *PXInjectionComputeBridgeBundles(NSArray<NSString *> *tweakBundles) {
    NSMutableArray<NSString *> *builder = [NSMutableArray array];
    for (NSString *bundleID in tweakBundles) {
        if (![bundleID isKindOfClass:[NSString class]]) continue;
        if ([bundleID isEqualToString:PXInjectionPlaceholderBundleID] ||
            [bundleID isEqualToString:PXInjectionLegacyPlaceholderBundleID]) continue;
        if (PXInjectionBundleIsAppleOrWebKit(bundleID)) continue;
        [builder addObject:bundleID];
    }
    NSArray<NSString *> *bridge = PXInjectionNormalizeBundleList(builder);
    if (bridge.count == 0) {
        return @[PXInjectionPlaceholderBundleID];
    }
    return bridge;
}

NSDictionary *PXInjectionFilterPlistDictionary(NSArray<NSString *> *bundles) {
    return @{
        @"Filter": @{
            @"Bundles": PXInjectionNormalizeBundleList(bundles),
            @"Mode": @"Any"
        }
    };
}

BOOL PXInjectionFilterPlistIsValid(NSDictionary *plist,
                                   NSArray<NSString *> * _Nullable *outBundles,
                                   NSString * _Nullable *outReason) {
    if (![plist isKindOfClass:[NSDictionary class]]) {
        if (outReason) *outReason = @"plist-not-dictionary";
        return NO;
    }
    NSDictionary *filter = [plist[@"Filter"] isKindOfClass:[NSDictionary class]] ? plist[@"Filter"] : nil;
    if (!filter) {
        if (outReason) *outReason = @"missing-Filter";
        return NO;
    }
    NSString *mode = [filter[@"Mode"] isKindOfClass:[NSString class]] ? filter[@"Mode"] : nil;
    if (mode.length && ![mode isEqualToString:@"Any"]) {
        if (outReason) *outReason = @"invalid-Mode";
        return NO;
    }
    NSArray *bundles = [filter[@"Bundles"] isKindOfClass:[NSArray class]] ? filter[@"Bundles"] : nil;
    if (!bundles.count) {
        if (outReason) *outReason = @"empty-Bundles";
        return NO;
    }
    for (id obj in bundles) {
        if (![obj isKindOfClass:[NSString class]] || ![(NSString *)obj length]) {
            if (outReason) *outReason = @"invalid-bundle-item";
            return NO;
        }
        NSString *bundleID = (NSString *)obj;
        if ([bundleID isEqualToString:@"com.apple.UIKit"]) {
            if (outReason) *outReason = @"blocked-com.apple.UIKit";
            return NO;
        }
        if ([bundleID containsString:@"*"]) {
            if (outReason) *outReason = @"wildcard-not-allowed";
            return NO;
        }
        BOOL isPlaceholder = [bundleID isEqualToString:PXInjectionPlaceholderBundleID] ||
                             [bundleID isEqualToString:PXInjectionLegacyPlaceholderBundleID];
        if (isPlaceholder && bundles.count > 1) {
            if (outReason) *outReason = @"placeholder-with-real-bundles";
            return NO;
        }
    }
    if (outBundles) *outBundles = bundles;
    return YES;
}

NSString *PXInjectionBundlesChecksum(NSArray *bundles) {
    NSMutableArray<NSString *> *items = [NSMutableArray array];
    for (id obj in bundles) {
        if ([obj isKindOfClass:[NSString class]] && [(NSString *)obj length]) {
            [items addObject:(NSString *)obj];
        }
    }
    [items sortUsingSelector:@selector(compare:)];
    NSString *joined = [items componentsJoinedByString:@","];
    return [NSString stringWithFormat:@"%lu:%@", (unsigned long)items.count, joined ?: @""];
}
