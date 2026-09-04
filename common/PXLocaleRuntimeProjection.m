#import "PXLocaleRuntimeProjection.h"

NSString *PXCanonicalCLocaleName(NSString *localeIdentifier) {
    if (![localeIdentifier isKindOfClass:[NSString class]]) return nil;
    NSString *trimmed = [localeIdentifier stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) return nil;

    NSString *normalized = [trimmed stringByReplacingOccurrencesOfString:@"-"
                                                               withString:@"_"];
    if ([normalized containsString:@"."]) return normalized;
    return [normalized stringByAppendingString:@".UTF-8"];
}

BOOL PXSetlocaleCategorySupportsProjection(int category) {
    switch (category) {
        case LC_ALL:
        case LC_COLLATE:
        case LC_CTYPE:
        case LC_MONETARY:
        case LC_NUMERIC:
        case LC_TIME:
#ifdef LC_MESSAGES
        case LC_MESSAGES:
#endif
            return YES;
        default:
            return NO;
    }
}

BOOL PXSetlocaleShouldUseCanonicalInput(int category, const char *locale) {
    return locale != NULL && locale[0] == '\0' && PXSetlocaleCategorySupportsProjection(category);
}

static NSString *PXFirstValidPreferredLanguage(NSArray<NSString *> *preferredLanguages) {
    if (![preferredLanguages isKindOfClass:[NSArray class]]) return nil;
    for (id value in preferredLanguages) {
        if (![value isKindOfClass:[NSString class]]) continue;
        NSString *trimmed = [(NSString *)value stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmed.length) return trimmed;
    }
    return nil;
}

static NSString *PXLanguageComponentFromLocaleIdentifier(NSString *localeIdentifier) {
    if (![localeIdentifier isKindOfClass:[NSString class]]) return nil;
    NSString *trimmed = [localeIdentifier stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) return nil;
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@"-_"];
    NSRange separator = [trimmed rangeOfCharacterFromSet:separators];
    NSString *language = separator.location == NSNotFound
        ? trimmed
        : [trimmed substringToIndex:separator.location];
    return language.length ? language : nil;
}

NSArray<NSString *> *PXPreferredLocalizationsProjection(NSArray<NSString *> *originalLocalizations,
                                                         NSArray<NSString *> *preferredLanguages,
                                                         NSString *localeIdentifier,
                                                         BOOL projectionEnabled) {
    if (!projectionEnabled) return originalLocalizations;
    NSString *language = PXFirstValidPreferredLanguage(preferredLanguages);
    if (!language.length) language = PXLanguageComponentFromLocaleIdentifier(localeIdentifier);
    if (!language.length) return originalLocalizations;
    return @[language];
}
