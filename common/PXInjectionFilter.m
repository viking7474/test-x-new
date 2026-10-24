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

BOOL PXInjectionBundleIsSharedWebKitHelper(NSString *bundleID) {
    if (![bundleID isKindOfClass:[NSString class]] || !bundleID.length) return NO;
    return [bundleID isEqualToString:@"com.apple.SafariViewService"] ||
           [bundleID hasPrefix:@"com.apple.WebKit"];
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
        if (PXInjectionBundleIsSharedWebKitHelper(bundleID) ||
            [bundleID isEqualToString:@"com.apple.UIKit"] ||
            [bundleID isEqualToString:PXInjectionSpringBoardBundleID]) return;
        if (![entry isKindOfClass:[NSDictionary class]] || ![entry[@"enabled"] boolValue]) return;
        [bundleIDs addObject:bundleID];
    }];
    return PXInjectionNormalizeBundleList(bundleIDs);
}

NSArray<NSString *> *PXInjectionComputeTweakBundles(NSArray<NSString *> *expandedEnabledBundles) {
    NSArray<NSString *> *normalizedEnabled = PXInjectionNormalizeBundleList(expandedEnabledBundles ?: @[]);

    // Rebuild coverage targets from real scope anchors. Coverage-only/legacy input
    // must not keep UIKit injection alive after the last scoped app is removed.
    NSMutableArray<NSString *> *monolithicTargets = [NSMutableArray array];
    for (NSString *bundleID in normalizedEnabled) {
        if ([bundleID isEqualToString:PXInjectionPlaceholderBundleID] ||
            [bundleID isEqualToString:PXInjectionLegacyPlaceholderBundleID]) continue;
        if (PXInjectionBundleIsSharedWebKitHelper(bundleID)) continue;
        if (PXInjectionBundleIsTLinkIOSApp(bundleID) ||
            [bundleID isEqualToString:@"com.apple.UIKit"] ||
            [bundleID isEqualToString:PXInjectionSpringBoardBundleID]) continue;
        [monolithicTargets addObject:bundleID];
    }

    // Empty state (no scoped app/extension targets): placeholder only, never Bundles=[].
    if (monolithicTargets.count == 0) {
        return @[PXInjectionPlaceholderBundleID];
    }

    // Loading grants no spoofing permission: every active constructor is gated.
    [monolithicTargets addObject:PXInjectionSpringBoardBundleID];
    [monolithicTargets addObject:@"com.apple.UIKit"];
    [monolithicTargets addObjectsFromArray:PXInjectionDefaultWebKitHelperBundleIDs()];
    return PXInjectionNormalizeBundleList(monolithicTargets);
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
    for (id key in filter) {
        if (![key isEqual:@"Bundles"] && ![key isEqual:@"Mode"]) {
            if (outReason) *outReason = @"unsupported-filter-key";
            return NO; // no Executables/Classes escape from canonical bundle policy
        }
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
