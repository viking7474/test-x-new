#import "CarrierDB.h"
#import "TLinkIOSLogging.h"
#import "PXJailbreakCompat.h"
#import <Security/Security.h>

static NSString *const kCarrierDBErrorDomain = @"com.hydra.tlinkios.carrier_db";

static NSUInteger PXCarrierRandomIndex(NSUInteger upper) {
    if (upper == 0) return 0;
    uint32_t r = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(r), (uint8_t *)&r) == errSecSuccess) {
        return (NSUInteger)(r % (uint32_t)upper);
    }
    return (NSUInteger)arc4random_uniform((uint32_t)upper);
}

static NSDictionary * _Nullable PXLoadJSONDict(NSString *path, NSError **error) {
    NSData *data = nil;
    id obj = nil;
    @try {
        data = [NSData dataWithContentsOfFile:path options:0 error:error];
        if (!data) return nil;
        obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
        if (![obj isKindOfClass:NSDictionary.class]) {
            if (error && !*error) *error = [NSError errorWithDomain:kCarrierDBErrorDomain code:2 userInfo:@{NSLocalizedDescriptionKey: @"Invalid carrier_db.json root"}];
            return nil;
        }
        return obj;
    } @finally { obj = nil; data = nil; path = nil; }
}

static NSString *PXCarrierScalar(id value) {
    @try {
        if ([value isKindOfClass:NSString.class]) return value;
        return [value isKindOfClass:NSNumber.class] ? [value stringValue] : nil;
    } @finally { value = nil; }
}
static BOOL PXCarrierMNCNumber(NSString *mnc, NSInteger *number) {
    @try {
        if (!mnc.length || mnc.length > 3) return NO;
        NSInteger value = 0;
        for (NSUInteger index = 0; index < mnc.length; index++) {
            unichar digit = [mnc characterAtIndex:index];
            if (digit < '0' || digit > '9') return NO;
            value = value * 10 + digit - '0';
        }
        if (number) *number = value;
        return YES;
    } @finally { mnc = nil; }
}
static NSString *PXNormCC(NSString *cc) {
    @try {
        if (![cc isKindOfClass:NSString.class]) return @"";
        return [[cc uppercaseString] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    } @finally { cc = nil; }
}

static NSString *PXNormMNC(NSString *mnc) {
    NSString *value = nil;
    @try {
        value = PXCarrierScalar(mnc);
        return [[value ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] copy];
    } @finally { value = nil; mnc = nil; }
}

@interface CarrierDB ()
- (NSDictionary *)carrierCatalog;
- (NSDictionary *)readyCarrierCatalog;
- (NSDictionary *)publishCarrierCatalogIfAbsent:(NSDictionary *)candidate;
- (NSDictionary *)indexesForCountries:(NSDictionary *)countries;
@end

@implementation CarrierDB {
    NSDictionary *_carrierCatalog;
}

+ (instancetype)sharedManager {
    static CarrierDB *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[CarrierDB alloc] init];
    });
    return shared;
}

#pragma mark - Built-in fallback (used only if JSON missing)

- (NSDictionary *)builtInFallbackDB {
    // Compact seed for offline / first-boot. Full coverage comes from carrier_db.json.
    return @{
        @"schemaVersion": @1,
        @"countries": @{
            @"US": @{
                @"iso": @"us",
                @"localeIdentifier": @"en_US",
                @"preferredLanguages": @[@"en-US"],
                @"carriers": @[
                    @{@"name": @"T-Mobile", @"mcc": @"310", @"mnc": @"260"},
                    @{@"name": @"T-Mobile", @"mcc": @"310", @"mnc": @"160"},
                    @{@"name": @"AT&T", @"mcc": @"310", @"mnc": @"410"},
                    @{@"name": @"AT&T", @"mcc": @"310", @"mnc": @"170"},
                    @{@"name": @"Verizon", @"mcc": @"311", @"mnc": @"480"},
                    @{@"name": @"Verizon", @"mcc": @"310", @"mnc": @"004"}
                ]
            },
            @"VN": @{
                @"iso": @"vn",
                @"localeIdentifier": @"vi_VN",
                @"preferredLanguages": @[@"vi-VN", @"en-US"],
                @"carriers": @[
                    @{@"name": @"Viettel", @"mcc": @"452", @"mnc": @"04"},
                    @{@"name": @"Vinaphone", @"mcc": @"452", @"mnc": @"02"},
                    @{@"name": @"MobiFone", @"mcc": @"452", @"mnc": @"01"},
                    @{@"name": @"Vietnamobile", @"mcc": @"452", @"mnc": @"05"}
                ]
            },
            @"CA": @{
                @"iso": @"ca",
                @"localeIdentifier": @"en_CA",
                @"preferredLanguages": @[@"en-CA", @"fr-CA"],
                @"carriers": @[
                    @{@"name": @"Rogers", @"mcc": @"302", @"mnc": @"720"},
                    @{@"name": @"Bell", @"mcc": @"302", @"mnc": @"610"},
                    @{@"name": @"Telus", @"mcc": @"302", @"mnc": @"220"}
                ]
            },
            @"IN": @{
                @"iso": @"in",
                @"localeIdentifier": @"en_IN",
                @"preferredLanguages": @[@"en-IN", @"hi-IN"],
                @"carriers": @[
                    @{@"name": @"Jio", @"mcc": @"405", @"mnc": @"840"},
                    @{@"name": @"Airtel", @"mcc": @"404", @"mnc": @"45"},
                    @{@"name": @"BSNL", @"mcc": @"404", @"mnc": @"34"}
                ]
            },
            @"GB": @{
                @"iso": @"gb",
                @"localeIdentifier": @"en_GB",
                @"preferredLanguages": @[@"en-GB"],
                @"carriers": @[
                    @{@"name": @"EE", @"mcc": @"234", @"mnc": @"30"},
                    @{@"name": @"O2", @"mcc": @"234", @"mnc": @"10"},
                    @{@"name": @"Vodafone", @"mcc": @"234", @"mnc": @"15"},
                    @{@"name": @"Three", @"mcc": @"234", @"mnc": @"20"}
                ]
            }
        }
    };
}

- (NSDictionary *)indexesForCountries:(NSDictionary *)countries {
    NSMutableDictionary *byCC = nil, *byMccMnc = nil;
    NSArray *keys = nil, *carriers = nil;
    NSString *cc = nil, *mcc = nil, *mnc = nil, *name = nil, *normalizedMNC = nil, *key = nil;
    NSDictionary *row = nil;
    id ccKey = nil, entry = nil, carrier = nil;
    @try {
        byCC = [NSMutableDictionary dictionary]; byMccMnc = [NSMutableDictionary dictionary];
        keys = [countries allKeys];
        for (NSUInteger countryIndex = 0; countryIndex < keys.count; countryIndex++) {
            ccKey = keys[countryIndex]; entry = countries[ccKey];
            if (![ccKey isKindOfClass:NSString.class] || ![entry isKindOfClass:NSDictionary.class]) continue;
            cc = PXNormCC(ccKey); if (cc.length != 2) continue;
            byCC[cc] = entry;
            carriers = entry[@"carriers"];
            if (![carriers isKindOfClass:NSArray.class]) continue;
            for (NSUInteger index = 0; index < carriers.count; index++) {
                carrier = carriers[index]; if (![carrier isKindOfClass:NSDictionary.class]) continue;
                mcc = PXCarrierScalar(carrier[@"mcc"]); mnc = PXCarrierScalar(carrier[@"mnc"]);
                name = [carrier[@"name"] isKindOfClass:NSString.class] ? carrier[@"name"] : nil;
                if (!mcc.length || !mnc.length || !name.length) continue;
                key = [NSString stringWithFormat:@"%@-%@", mcc, mnc];
                row = @{ @"name": name, @"mcc": mcc, @"mnc": mnc, @"country": cc };
                byMccMnc[key] = row;
                NSInteger number = 0;
                normalizedMNC = PXNormMNC(mnc);
                if (PXCarrierMNCNumber(normalizedMNC, &number)) {
                    byMccMnc[[NSString stringWithFormat:@"%@-%02ld", mcc, (long)number]] = row;
                    byMccMnc[[NSString stringWithFormat:@"%@-%03ld", mcc, (long)number]] = row;
                }
            }
        }
        return @{ @"countries": [byCC copy], @"index": [byMccMnc copy] };
    } @finally {
        row = nil; key = nil; normalizedMNC = nil; name = nil; mnc = nil; mcc = nil; cc = nil;
        carrier = nil; entry = nil; ccKey = nil; carriers = nil; keys = nil; byMccMnc = nil; byCC = nil; countries = nil;
    }
}

- (NSDictionary *)carrierCatalog {
    NSDictionary *catalog = nil;
    @try { @synchronized (self) { catalog = _carrierCatalog; } return catalog; }
    @finally { catalog = nil; }
}
- (NSDictionary *)readyCarrierCatalog {
    NSDictionary *catalog = nil;
    @try {
        catalog = [self carrierCatalog];
        if (!catalog) { [self loadIfNeeded:nil]; catalog = [self carrierCatalog]; }
        return catalog;
    } @finally { catalog = nil; }
}
- (NSDictionary *)publishCarrierCatalogIfAbsent:(NSDictionary *)candidate {
    NSDictionary *winner = nil;
    @try {
        @synchronized (self) {
            if (!_carrierCatalog) _carrierCatalog = candidate;
            winner = _carrierCatalog;
        }
        return winner;
    } @finally { winner = nil; candidate = nil; }
}

- (BOOL)loadIfNeeded:(NSError **)error {
    NSDictionary *catalog = nil, *root = nil, *countries = nil, *indexes = nil, *candidate = nil;
    NSArray<NSString *> *paths = nil;
    NSString *path = nil;
    NSError *lastErr = nil;
    NSNumber *schema = nil;
    BOOL usedFallback = NO;
    @try {
        catalog = [self carrierCatalog]; if (catalog) return YES;
        paths = PXJailbreakPathCandidates(@[
            @"/var/mobile/Library/WeaponX/Data/carrier_db.json",
            @"/private/var/mobile/Library/WeaponX/Data/carrier_db.json",
            [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"carrier_db.json"] ?: @"",
            @"/Library/WeaponX/Data/carrier_db.json",
            @"/var/jb/Library/WeaponX/Data/carrier_db.json"
        ]);
        for (NSUInteger index = 0; index < paths.count; index++) {
            path = paths[index];
            if (!path.length || ![NSFileManager.defaultManager fileExistsAtPath:path]) continue;
            root = PXLoadJSONDict(path, &lastErr);
            if (root) { PXLog(@"[CarrierDB] Loaded %@", path); break; }
        }
        if (!root) {
            PXLog(@"[CarrierDB] JSON missing — using built-in fallback (%@)", lastErr.localizedDescription ?: @"no file");
            root = [self builtInFallbackDB]; usedFallback = YES;
        }
        schema = root[@"schemaVersion"];
        if (![schema isKindOfClass:NSNumber.class] || schema.integerValue < 1) {
            if (error) *error = [NSError errorWithDomain:kCarrierDBErrorDomain code:3 userInfo:@{NSLocalizedDescriptionKey: @"Unsupported carrier_db schemaVersion"}];
            root = [self builtInFallbackDB]; usedFallback = YES;
        }
        countries = root[@"countries"];
        if (![countries isKindOfClass:NSDictionary.class] || countries.count == 0) {
            root = [self builtInFallbackDB]; countries = root[@"countries"]; usedFallback = YES;
        }
        indexes = [self indexesForCountries:countries];
        candidate = @{ @"root": root, @"countries": indexes[@"countries"], @"index": indexes[@"index"], @"usedFallback": @(usedFallback) };
        catalog = [self publishCarrierCatalogIfAbsent:candidate];
        return catalog != nil;
    } @finally { schema = nil; lastErr = nil; path = nil; paths = nil; candidate = nil; indexes = nil; countries = nil; root = nil; catalog = nil; }
}

#pragma mark - Queries

- (NSArray<NSDictionary *> *)carriersForCountry:(NSString *)countryCode {
    NSDictionary *catalog = nil, *countries = nil, *entry = nil;
    NSString *cc = nil;
    NSArray *carriers = nil;
    @try {
        cc = PXNormCC(countryCode); catalog = [self readyCarrierCatalog]; countries = catalog[@"countries"];
        entry = countries[cc]; carriers = entry[@"carriers"];
        if ([carriers isKindOfClass:NSArray.class] && carriers.count > 0) return carriers;
        entry = countries[@"US"]; carriers = entry[@"carriers"];
        return [carriers isKindOfClass:NSArray.class] ? carriers : @[];
    } @finally { carriers = nil; cc = nil; entry = nil; countries = nil; catalog = nil; countryCode = nil; }
}

- (NSDictionary *)randomCarrierForCountry:(NSString *)countryCode {
    NSArray *carriers = nil;
    id pick = nil;
    NSString *name = nil, *mcc = nil, *mnc = nil;
    NSMutableDictionary *normalized = nil;
    @try {
        carriers = [self carriersForCountry:countryCode];
        if (carriers.count) {
            pick = carriers[PXCarrierRandomIndex(carriers.count)];
            if ([pick isKindOfClass:NSDictionary.class]) {
                name = [pick[@"name"] isKindOfClass:NSString.class] ? pick[@"name"] : nil;
                mcc = PXCarrierScalar(pick[@"mcc"]); mnc = PXCarrierScalar(pick[@"mnc"]);
                if (name && mcc && mnc) {
                    if (mcc == pick[@"mcc"] && mnc == pick[@"mnc"]) return pick;
                    normalized = [pick mutableCopy]; normalized[@"mcc"] = mcc; normalized[@"mnc"] = mnc;
                    return [normalized copy];
                }
            }
        }
        return @{ @"name": @"T-Mobile", @"mcc": @"310", @"mnc": @"260" };
    } @finally { normalized = nil; mnc = nil; mcc = nil; name = nil; pick = nil; carriers = nil; countryCode = nil; }
}

- (NSDictionary *)carrierForMCC:(NSString *)mcc mnc:(NSString *)mnc {
    NSDictionary *catalog = nil, *index = nil, *hit = nil;
    NSString *key = nil;
    @try {
        mcc = [PXCarrierScalar(mcc) copy]; mnc = PXNormMNC(mnc);
        catalog = [self readyCarrierCatalog]; index = catalog[@"index"];
        if (!mcc.length || !mnc.length) return nil;
        key = [NSString stringWithFormat:@"%@-%@", mcc, mnc]; hit = index[key];
        if (hit) return hit;
        NSInteger number = 0;
        if (PXCarrierMNCNumber(mnc, &number)) {
            hit = index[[NSString stringWithFormat:@"%@-%02ld", mcc, (long)number]]; if (hit) return hit;
            hit = index[[NSString stringWithFormat:@"%@-%03ld", mcc, (long)number]]; if (hit) return hit;
        }
        return nil;
    } @finally { key = nil; hit = nil; index = nil; catalog = nil; mnc = nil; mcc = nil; }
}

- (NSString *)carrierNameForMCC:(NSString *)mcc mnc:(NSString *)mnc {
    NSDictionary *row = nil;
    NSString *name = nil;
    @try {
        row = [self carrierForMCC:mcc mnc:mnc]; name = row[@"name"];
        if ([name isKindOfClass:NSString.class] && name.length && ![name isEqualToString:@"TLinkIOS"] && ![name hasPrefix:@"TLinkIOS"]) return name;
        return @"T-Mobile";
    } @finally { name = nil; row = nil; mnc = nil; mcc = nil; }
}

- (NSDictionary *)regionDefaultsForCountryCode:(NSString *)countryCode {
    NSDictionary *catalog = nil, *entry = nil, *carrier = nil;
    NSString *cc = nil, *iso = nil, *locale = nil;
    NSArray *langs = nil;
    @try {
        cc = PXNormCC(countryCode);
        catalog = [self readyCarrierCatalog];
        if (cc.length != 2) cc = @"US";

        entry = catalog[@"countries"][cc];
        if (![entry isKindOfClass:[NSDictionary class]]) {
            entry = catalog[@"countries"][@"US"];
            cc = @"US";
        }

        carrier = [self randomCarrierForCountry:cc];
        iso = entry[@"iso"];
        if (![iso isKindOfClass:[NSString class]] || !iso.length) {
            iso = [cc lowercaseString];
        }
        locale = entry[@"localeIdentifier"];
        if (![locale isKindOfClass:[NSString class]] || !locale.length) {
            locale = [NSString stringWithFormat:@"en_%@", cc];
        }
        langs = entry[@"preferredLanguages"];
        if (![langs isKindOfClass:[NSArray class]] || langs.count == 0) {
            langs = @[ @"en-US" ];
        }
        for (NSUInteger index = 0; index < langs.count; index++) {
            if (![langs[index] isKindOfClass:NSString.class]) { langs = @[@"en-US"]; break; }
        }

        return @{
            @"carrierISO": iso,
            @"mcc": carrier[@"mcc"] ?: @"310",
            @"mnc": carrier[@"mnc"] ?: @"260",
            @"carrierName": carrier[@"name"] ?: @"T-Mobile",
            @"localeIdentifier": locale,
            @"preferredLanguages": langs
        };
    } @finally { langs = nil; locale = nil; iso = nil; cc = nil; carrier = nil; entry = nil; catalog = nil; countryCode = nil; }
}

- (NSArray<NSString *> *)availableCountryCodes {
    NSDictionary *catalog = nil;
    @try { catalog = [self readyCarrierCatalog]; return [[catalog[@"countries"] allKeys] sortedArrayUsingSelector:@selector(compare:)]; }
    @finally { catalog = nil; }
}

@end
