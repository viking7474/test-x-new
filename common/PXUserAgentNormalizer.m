#import "PXUserAgentNormalizer.h"

static NSString *PXWebTrimmedString(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *trimmed = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length ? trimmed : nil;
}

static NSString *PXReplacePattern(NSString *source, NSString *pattern, NSString *replacement) {
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    return expression ? [expression stringByReplacingMatchesInString:source options:0 range:NSMakeRange(0, source.length) withTemplate:replacement] : source;
}

NSString *PXNormalizeUserAgent(NSString *baseUserAgent,
                               NSString *productVersion,
                               NSString *productBuild,
                               BOOL replaceMobileBuild) {
    NSString *base = PXWebTrimmedString(baseUserAgent);
    NSString *version = PXWebTrimmedString(productVersion);
    if (!base || !version || ![version rangeOfString:@"^[0-9]+(?:\\.[0-9]+){1,2}$" options:NSRegularExpressionSearch].length) return nil;
    NSString *underscored = [version stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    NSString *updated = base;
    updated = PXReplacePattern(updated, @"(CPU(?: iPhone)? OS\\s+)[0-9]+(?:[_\\.][0-9]+){1,2}(\\s+like)", [NSString stringWithFormat:@"$1%@$2", underscored]);
    updated = PXReplacePattern(updated, @"(OS\\s+)[0-9]+(?:[_\\.][0-9]+){1,2}(\\s+like\\s+Mac)", [NSString stringWithFormat:@"$1%@$2", underscored]);
    updated = PXReplacePattern(updated, @"(Version/)[0-9]+(?:\\.[0-9]+){1,2}", [NSString stringWithFormat:@"$1%@", version]);
    if (replaceMobileBuild) {
        NSString *build = PXWebTrimmedString(productBuild);
        if (build && [build rangeOfString:@"^[0-9]+[A-Z][0-9A-Za-z]+$" options:NSRegularExpressionSearch].length) {
            updated = PXReplacePattern(updated, @"(Mobile/)[0-9]+[A-Z][0-9A-Za-z]+", [NSString stringWithFormat:@"$1%@", build]);
        }
    }
    return updated;
}

NSDictionary<NSString *, NSString *> *PXCanonicalWebIdentityHeaders(NSDictionary *headers,
                                                                      NSString *localeIdentifier,
                                                                      BOOL mobilePlatform) {
    NSMutableDictionary<NSString *, NSString *> *result = [NSMutableDictionary dictionary];
    if ([headers isKindOfClass:[NSDictionary class]]) {
        [headers enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            (void)stop;
            NSString *name = PXWebTrimmedString(key);
            NSString *content = PXWebTrimmedString(value);
            if (name && content && [name caseInsensitiveCompare:@"Accept-Language"] != NSOrderedSame &&
                     [name caseInsensitiveCompare:@"Sec-CH-UA-Platform"] != NSOrderedSame &&
                     [name caseInsensitiveCompare:@"Sec-CH-UA-Mobile"] != NSOrderedSame) result[name] = content;
        }];
    }
    NSString *locale = PXWebTrimmedString(localeIdentifier);
    if (locale) result[@"Accept-Language"] = [[locale stringByReplacingOccurrencesOfString:@"_" withString:@"-"] lowercaseString];
    result[@"Sec-CH-UA-Platform"] = @"\"iOS\"";
    result[@"Sec-CH-UA-Mobile"] = mobilePlatform ? @"?1" : @"?0";
    return [result copy];
}

BOOL PXWebKitHelperProcessIsInScope(NSString *bundleIdentifier,
                                    NSString *processName,
                                    BOOL explicitSafariStackPermission) {
    NSString *bundle = PXWebTrimmedString(bundleIdentifier).lowercaseString;
    NSString *process = PXWebTrimmedString(processName).lowercaseString;
    if (!bundle.length || !process.length) return NO;
    NSArray *forbidden = @[@"securityd", @"trustd", @"accountsd", @"authkit", @"akd"];
    for (NSString *token in forbidden) if ([bundle containsString:token] || [process containsString:token]) return NO;
    BOOL helper = [process containsString:@"webkit"] || [process containsString:@"webcontent"] ||
                  [bundle containsString:@"webkit"] || [bundle containsString:@"safari"];
    return helper ? explicitSafariStackPermission : YES;
}
