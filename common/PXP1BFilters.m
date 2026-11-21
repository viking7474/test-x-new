// PXP1BFilters.m
// Implementation of pure, host-testable P1-B helpers.

#import "PXP1BFilters.h"
#import <string.h>

NSString * const PXATTZeroIDFAUUIDString = @"00000000-0000-0000-0000-000000000000";

#pragma mark - App Version

NSDictionary *PXAppVersionApplyToInfoDictionary(NSDictionary *original,
                                                NSString *version,
                                                NSString *build) {
    NSMutableDictionary *mutable = nil;
    @try {
        if (![original isKindOfClass:[NSDictionary class]]) return original;
        mutable = [original mutableCopy];if (!mutable) return original;
        if (version.length) mutable[@"CFBundleShortVersionString"] = version;
        if (build.length) mutable[@"CFBundleVersion"] = build;
        return [mutable copy];
    } @finally { original = nil;version = nil;build = nil;mutable = nil; }
}

NSString *PXAppVersionSafeBundleFilename(NSString *bundleID) {
    NSString *safe = nil;
    @try { if (!bundleID.length) return nil;safe = [bundleID stringByReplacingOccurrencesOfString:@"." withString:@"_"];return [safe stringByAppendingString:@"_version.plist"]; }
    @finally { bundleID = nil;safe = nil; }
}

#pragma mark - gethostname

BOOL PXGethostnameWriteValue(char *name, size_t namelen, const char *value) {
    if (!name || namelen == 0) return NO;
    if (!value || value[0] == '\0') return NO;
    size_t len = strlen(value);
    size_t copyLen = (len < namelen - 1) ? len : (namelen - 1);
    memcpy(name, value, copyLen);
    name[copyLen] = '\0';
    return YES;
}

#pragma mark - ATT

NSInteger PXATTClampStatus(NSInteger status) {
    if (status < 0) return 0;
    if (status > 3) return 3;
    return status;
}

BOOL PXATTStatusIsAuthorized(NSInteger status) {
    return PXATTClampStatus(status) == 3;
}
