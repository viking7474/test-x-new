#import "CarrierDB.h"
#import "ProjectXLogging.h"
#import <Security/Security.h>

static NSString *const kCarrierDBErrorDomain = @"com.hydra.projectx.carrier_db";

static NSUInteger PXCarrierRandomIndex(NSUInteger upper) {
    if (upper == 0) return 0;
    uint32_t r = 0;
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(r), (uint8_t *)&r) == errSecSuccess) {
        return (NSUInteger)(r % (uint32_t)upper);
    }
    return (NSUInteger)arc4random_uniform((uint32_t)upper);
}

static NSDictionary * _Nullable PXLoadJSONDict(NSString *path, NSError **error) {
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!data) return nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![obj isKindOfClass:[NSDictionary class]]) {
        if (error && !*error) {
            *error = [NSError errorWithDomain:kCarrierDBErrorDomain code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid carrier_db.json root"}];
        }
        return nil;
    }
    return obj;
}

static NSString *PXNormCC(NSString *cc) {
    return [[cc ?: @"" uppercaseString]
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *PXNormMNC(NSString *mnc) {
    // Normalize "01" / "1" → keep original preferred; also try zero-padded 2/3 digit variants in lookup.
    return [[mnc ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
}

@interface CarrierDB ()
@property (nonatomic, strong) NSDictionary *db;
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary *> *countries; // CC → entry
@property (nonatomic, strong) NSDictionary<NSString *, NSDictionary *> *mccMncIndex; // "MCC-MNC" → carrier+country
@property (nonatomic, assign) BOOL usedFallback;
@end

@implementation CarrierDB

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

- (void)indexFromCountries:(NSDictionary *)countries {
    NSMutableDictionary *byCC = [NSMutableDictionary dictionary];
    NSMutableDictionary *byMccMnc = [NSMutableDictionary dictionary];

    [countries enumerateKeysAndObjectsUsingBlock:^(NSString *ccKey, id entry, BOOL *stop) {
        (void)stop;
        if (![ccKey isKindOfClass:[NSString class]] || ![entry isKindOfClass:[NSDictionary class]]) return;
        NSString *cc = PXNormCC(ccKey);
        if (cc.length != 2) return;
        byCC[cc] = entry;

        NSArray *carriers = entry[@"carriers"];
        if (![carriers isKindOfClass:[NSArray class]]) return;
        for (id c in carriers) {
            if (![c isKindOfClass:[NSDictionary class]]) continue;
            NSString *mcc = [c[@"mcc"] description];
            NSString *mnc = [c[@"mnc"] description];
            NSString *name = c[@"name"];
            if (!mcc.length || !mnc.length || ![name isKindOfClass:[NSString class]] || !name.length) continue;
            NSString *key = [NSString stringWithFormat:@"%@-%@", mcc, mnc];
            NSMutableDictionary *row = [@{
                @"name": name,
                @"mcc": mcc,
                @"mnc": mnc,
                @"country": cc
            } mutableCopy];
            byMccMnc[key] = row;
            // Also index zero-padded MNC variants (1 → 01 / 001)
            NSInteger mncVal = mnc.integerValue;
            if (mncVal >= 0) {
                NSString *mnc2 = [NSString stringWithFormat:@"%02ld", (long)mncVal];
                NSString *mnc3 = [NSString stringWithFormat:@"%03ld", (long)mncVal];
                byMccMnc[[NSString stringWithFormat:@"%@-%@", mcc, mnc2]] = row;
                byMccMnc[[NSString stringWithFormat:@"%@-%@", mcc, mnc3]] = row;
            }
        }
    }];

    self.countries = [byCC copy];
    self.mccMncIndex = [byMccMnc copy];
}

- (BOOL)loadIfNeeded:(NSError **)error {
    if (self.db) return YES;

    NSArray<NSString *> *paths = @[
        @"/var/mobile/Library/WeaponX/Data/carrier_db.json",
        @"/private/var/mobile/Library/WeaponX/Data/carrier_db.json",
        // Bundled copy inside app (optional)
        [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"carrier_db.json"] ?: @"",
        // Package path under /Library/WeaponX
        @"/Library/WeaponX/Data/carrier_db.json",
        @"/var/jb/Library/WeaponX/Data/carrier_db.json"
    ];

    NSError *lastErr = nil;
    NSDictionary *root = nil;
    for (NSString *p in paths) {
        if (!p.length) continue;
        if (![[NSFileManager defaultManager] fileExistsAtPath:p]) continue;
        root = PXLoadJSONDict(p, &lastErr);
        if (root) {
            PXLog(@"[CarrierDB] Loaded %@", p);
            break;
        }
    }

    if (!root) {
        PXLog(@"[CarrierDB] JSON missing — using built-in fallback (%@)", lastErr.localizedDescription ?: @"no file");
        root = [self builtInFallbackDB];
        self.usedFallback = YES;
    } else {
        self.usedFallback = NO;
    }

    NSNumber *schema = root[@"schemaVersion"];
    if (![schema isKindOfClass:[NSNumber class]] || schema.integerValue < 1) {
        if (error) {
            *error = [NSError errorWithDomain:kCarrierDBErrorDomain code:3
                                     userInfo:@{NSLocalizedDescriptionKey: @"Unsupported carrier_db schemaVersion"}];
        }
        // Still try fallback
        root = [self builtInFallbackDB];
        self.usedFallback = YES;
    }

    NSDictionary *countries = root[@"countries"];
    if (![countries isKindOfClass:[NSDictionary class]] || countries.count == 0) {
        root = [self builtInFallbackDB];
        countries = root[@"countries"];
        self.usedFallback = YES;
    }

    self.db = root;
    [self indexFromCountries:countries];
    return YES;
}

#pragma mark - Queries

- (NSArray<NSDictionary *> *)carriersForCountry:(NSString *)countryCode {
    [self loadIfNeeded:nil];
    NSString *cc = PXNormCC(countryCode);
    NSDictionary *entry = self.countries[cc];
    NSArray *carriers = entry[@"carriers"];
    if ([carriers isKindOfClass:[NSArray class]] && carriers.count > 0) {
        return carriers;
    }
    // Fallback US
    entry = self.countries[@"US"];
    carriers = entry[@"carriers"];
    return [carriers isKindOfClass:[NSArray class]] ? carriers : @[];
}

- (NSDictionary *)randomCarrierForCountry:(NSString *)countryCode {
    NSArray *carriers = [self carriersForCountry:countryCode];
    if (carriers.count == 0) {
        return @{@"name": @"T-Mobile", @"mcc": @"310", @"mnc": @"260"};
    }
    id pick = carriers[PXCarrierRandomIndex(carriers.count)];
    if ([pick isKindOfClass:[NSDictionary class]] && pick[@"name"] && pick[@"mcc"] && pick[@"mnc"]) {
        return pick;
    }
    return @{@"name": @"T-Mobile", @"mcc": @"310", @"mnc": @"260"};
}

- (NSDictionary *)carrierForMCC:(NSString *)mcc mnc:(NSString *)mnc {
    [self loadIfNeeded:nil];
    mcc = [mcc description];
    mnc = PXNormMNC(mnc);
    if (!mcc.length || !mnc.length) return nil;

    NSString *key = [NSString stringWithFormat:@"%@-%@", mcc, mnc];
    NSDictionary *hit = self.mccMncIndex[key];
    if (hit) return hit;

    // Try padded MNC
    NSInteger mncVal = mnc.integerValue;
    if (mncVal >= 0) {
        hit = self.mccMncIndex[[NSString stringWithFormat:@"%@-%02ld", mcc, (long)mncVal]];
        if (hit) return hit;
        hit = self.mccMncIndex[[NSString stringWithFormat:@"%@-%03ld", mcc, (long)mncVal]];
        if (hit) return hit;
    }
    return nil;
}

- (NSString *)carrierNameForMCC:(NSString *)mcc mnc:(NSString *)mnc {
    NSDictionary *row = [self carrierForMCC:mcc mnc:mnc];
    NSString *name = row[@"name"];
    if ([name isKindOfClass:[NSString class]] && name.length &&
        ![name isEqualToString:@"ProjectX"] && ![name hasPrefix:@"ProjectX"]) {
        return name;
    }
    // Last resort: US default name (never product branding)
    return @"T-Mobile";
}

- (NSDictionary *)regionDefaultsForCountryCode:(NSString *)countryCode {
    [self loadIfNeeded:nil];
    NSString *cc = PXNormCC(countryCode);
    if (cc.length != 2) cc = @"US";

    NSDictionary *entry = self.countries[cc];
    if (![entry isKindOfClass:[NSDictionary class]]) {
        entry = self.countries[@"US"];
        cc = @"US";
    }

    NSDictionary *carrier = [self randomCarrierForCountry:cc];
    NSString *iso = entry[@"iso"];
    if (![iso isKindOfClass:[NSString class]] || !iso.length) {
        iso = [cc lowercaseString];
    }
    NSString *locale = entry[@"localeIdentifier"];
    if (![locale isKindOfClass:[NSString class]] || !locale.length) {
        locale = [NSString stringWithFormat:@"en_%@", cc];
    }
    NSArray *langs = entry[@"preferredLanguages"];
    if (![langs isKindOfClass:[NSArray class]] || langs.count == 0) {
        langs = @[ @"en-US" ];
    }

    return @{
        @"carrierISO": iso,
        @"mcc": carrier[@"mcc"] ?: @"310",
        @"mnc": carrier[@"mnc"] ?: @"260",
        @"carrierName": carrier[@"name"] ?: @"T-Mobile",
        @"localeIdentifier": locale,
        @"preferredLanguages": langs
    };
}

- (NSArray<NSString *> *)availableCountryCodes {
    [self loadIfNeeded:nil];
    return [[self.countries allKeys] sortedArrayUsingSelector:@selector(compare:)];
}

@end
