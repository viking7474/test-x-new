#import "DeviceModelManager.h"
#import "TLinkIOSLogging.h"
#import "PXDeviceProfileSchema.h"
#import "PXIdentityValidator.h"
#import <Security/Security.h>
#import <UIKit/UIKit.h>

@interface DeviceModelManager ()
@property (nonatomic, strong) NSString *currentIdentifier;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSDictionary *deviceSpecifications;
@end

// Hardware capability fields that are not part of the legacy display/GPU
// table.  Keeping them beside the model table gives RootHide snapshots and
// rootful direct-profile readers one canonical source.
static NSDictionary *PXHardwareCapabilitiesForModel(NSString *model) {
    if (![model hasPrefix:@"iPhone"]) return @{};

    BOOL isSE = [model isEqualToString:@"iPhone8,4"] || [model isEqualToString:@"iPhone12,8"] || [model isEqualToString:@"iPhone14,6"];
    BOOL isModernSingleRear = [model isEqualToString:@"iPhone17,5"] || [model isEqualToString:@"iPhone18,4"] || [model isEqualToString:@"iPhone18,5"];
    BOOL isPro = [@[@"iPhone12,3", @"iPhone12,5", @"iPhone13,3", @"iPhone13,4",
                    @"iPhone14,2", @"iPhone14,3", @"iPhone15,2", @"iPhone15,3",
                    @"iPhone16,1", @"iPhone16,2", @"iPhone17,1", @"iPhone17,2",
                    @"iPhone18,1", @"iPhone18,2"] containsObject:model];
    BOOL isSingleRear = [model hasPrefix:@"iPhone8"] || [model isEqualToString:@"iPhone9,3"] ||
                        [model isEqualToString:@"iPhone10,4"] || [model isEqualToString:@"iPhone11,8"] ||
                        isSE || isModernSingleRear;
    BOOL isEarlyDual = [model isEqualToString:@"iPhone9,4"] ||
                       [@[@"iPhone10,2", @"iPhone10,3", @"iPhone10,5", @"iPhone10,6"] containsObject:model] ||
                       [model isEqualToString:@"iPhone11,2"] ||
                       [model isEqualToString:@"iPhone11,6"];
    BOOL hasUltraWide = ([model hasPrefix:@"iPhone12"] && !isSE) ||
                        [model hasPrefix:@"iPhone13"] ||
                        ([model hasPrefix:@"iPhone14"] && !isSE) ||
                        [model hasPrefix:@"iPhone15"] || [model hasPrefix:@"iPhone16"] ||
                        ([@[@"iPhone17,1", @"iPhone17,2", @"iPhone17,3", @"iPhone17,4",
                            @"iPhone18,1", @"iPhone18,2", @"iPhone18,3"] containsObject:model]);
    BOOL hasTelephoto = isPro || isEarlyDual;
    BOOL hasLiDAR = [@[@"iPhone13,3", @"iPhone13,4", @"iPhone14,2", @"iPhone14,3",
                       @"iPhone15,2", @"iPhone15,3", @"iPhone16,1", @"iPhone16,2",
                       @"iPhone17,1", @"iPhone17,2", @"iPhone18,1", @"iPhone18,2"] containsObject:model];
    NSInteger rearCount = isSingleRear ? 1 : (isPro ? 3 : 2);
    double frontMP = [model isEqualToString:@"iPhone18,5"] ? 12.0 :
                     ([model hasPrefix:@"iPhone18"] ? 18.0 :
                     ([model hasPrefix:@"iPhone8"] ? ([model isEqualToString:@"iPhone8,4"] ? 1.2 : 5.0) :
                      (([model hasPrefix:@"iPhone9"] || [model hasPrefix:@"iPhone10"] ||
                        [model hasPrefix:@"iPhone11"] || isSE) ? 7.0 : 12.0)));
    NSInteger rearMP = ([model hasPrefix:@"iPhone15"] || [model hasPrefix:@"iPhone16"] ||
                         [model hasPrefix:@"iPhone17"] || [model hasPrefix:@"iPhone18"]) ? 48 : 12;

    NSArray *capacities = nil;
    if ([model hasPrefix:@"iPhone8"]) capacities = @[@16, @32, @64, @128];
    else if ([model hasPrefix:@"iPhone9"]) capacities = @[@32, @128, @256];
    else if ([model hasPrefix:@"iPhone10"]) capacities = @[@64, @256];
    else if ([model isEqualToString:@"iPhone11,8"]) capacities = @[@64, @128, @256];
    else if ([model hasPrefix:@"iPhone11"]) capacities = @[@64, @256, @512];
    else if ([model isEqualToString:@"iPhone12,1"] || isSE) capacities = @[@64, @128, @256];
    else if ([model hasPrefix:@"iPhone12"]) capacities = @[@64, @256, @512];
    else if ([model isEqualToString:@"iPhone13,1"] || [model isEqualToString:@"iPhone13,2"]) capacities = @[@64, @128, @256];
    else if ([model hasPrefix:@"iPhone13"]) capacities = @[@128, @256, @512];
    else if ([model isEqualToString:@"iPhone14,6"]) capacities = @[@64, @128, @256];
    else if ([model hasPrefix:@"iPhone14"] && isPro) capacities = @[@128, @256, @512, @1024];
    else if ([model hasPrefix:@"iPhone14"]) capacities = @[@128, @256, @512];
    else if ([model isEqualToString:@"iPhone16,2"] || [model isEqualToString:@"iPhone17,2"]) capacities = @[@256, @512, @1024];
    else if ([model isEqualToString:@"iPhone18,2"]) capacities = @[@256, @512, @1024, @2048];
    else if ([model isEqualToString:@"iPhone18,1"] || [model isEqualToString:@"iPhone18,4"]) capacities = @[@256, @512, @1024];
    else if ([model isEqualToString:@"iPhone18,3"] || [model isEqualToString:@"iPhone18,5"]) capacities = @[@256, @512];
    else if (([model hasPrefix:@"iPhone15"] || [model hasPrefix:@"iPhone16"] ||
              [model hasPrefix:@"iPhone17"]) && isPro) capacities = @[@128, @256, @512, @1024];
    else capacities = @[@128, @256, @512];

    return @{
        @"frontCameraMegapixels": @(frontMP),
        @"rearCameraMegapixels": @(rearMP),
        @"rearCameraCount": @(rearCount),
        @"hasFrontCamera": @YES,
        @"hasRearCamera": @YES,
        @"hasPanoramaCamera": @YES,
        @"hasUltraWideCamera": @(hasUltraWide),
        @"hasTelephotoCamera": @(hasTelephoto),
        @"hasLiDARScanner": @(hasLiDAR),
        @"supports4KVideo": @YES,
        @"storageCapacitiesGB": capacities ?: @[@128]
    };
}

@implementation DeviceModelManager

- (instancetype)init {
    if (self = [super init]) {
        [self setupDeviceSpecifications];
    }
    return self;
}

- (void)setupDeviceSpecifications {
    // This method initializes all the device specifications in a dictionary
    
    // Build a comprehensive database of device specifications
    NSMutableDictionary *specs = [NSMutableDictionary dictionary];

    [self addSpecsForDevice:@"iPhone8,1" name:@"iPhone 6s"
                  resolution:@"1334x750" viewportResolution:@"1334x750"
              devicePixelRatio:2.0 screenDensity:326
                cpuArchitecture:@"Apple A9" toDict:specs];

    [self addSpecsForDevice:@"iPhone8,2" name:@"iPhone 6s Plus"
                  resolution:@"1920x1080" viewportResolution:@"2208x1242"
              devicePixelRatio:3.0 screenDensity:401
                cpuArchitecture:@"Apple A9" toDict:specs];

    [self addSpecsForDevice:@"iPhone8,4" name:@"iPhone SE (1st Gen)"
                  resolution:@"1136x640" viewportResolution:@"1136x640"
              devicePixelRatio:2.0 screenDensity:326
                cpuArchitecture:@"Apple A9" toDict:specs];

    [self addSpecsForDevice:@"iPhone9,3" name:@"iPhone 7"
                  resolution:@"1334x750" viewportResolution:@"1334x750"
              devicePixelRatio:2.0 screenDensity:326
                cpuArchitecture:@"Apple A10 Fusion" toDict:specs];

    [self addSpecsForDevice:@"iPhone9,4" name:@"iPhone 7 Plus"
                  resolution:@"1920x1080" viewportResolution:@"2208x1242"
              devicePixelRatio:3.0 screenDensity:401
                cpuArchitecture:@"Apple A10 Fusion" toDict:specs];
    
    // iPhone models from iPhone 8 Plus to iPhone 15 Pro Max
    [self addSpecsForDevice:@"iPhone10,2" name:@"iPhone 8 Plus" 
                  resolution:@"1920x1080" viewportResolution:@"2208x1242" 
              devicePixelRatio:3.0 screenDensity:401 
                cpuArchitecture:@"Apple A11 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone10,3" name:@"iPhone X" 
                  resolution:@"2436x1125" viewportResolution:@"2436x1125" 
              devicePixelRatio:3.0 screenDensity:458 
                cpuArchitecture:@"Apple A11 Bionic" toDict:specs];

    [self addSpecsForDevice:@"iPhone10,4" name:@"iPhone 8"
                  resolution:@"1334x750" viewportResolution:@"1334x750"
              devicePixelRatio:2.0 screenDensity:326
                cpuArchitecture:@"Apple A11 Bionic" toDict:specs];

    [self addSpecsForDevice:@"iPhone10,5" name:@"iPhone 8 Plus"
                  resolution:@"1920x1080" viewportResolution:@"2208x1242"
              devicePixelRatio:3.0 screenDensity:401
                cpuArchitecture:@"Apple A11 Bionic" toDict:specs];

    [self addSpecsForDevice:@"iPhone10,6" name:@"iPhone X"
                  resolution:@"2436x1125" viewportResolution:@"2436x1125"
              devicePixelRatio:3.0 screenDensity:458
                cpuArchitecture:@"Apple A11 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone11,8" name:@"iPhone XR" 
                  resolution:@"1792x828" viewportResolution:@"1792x828" 
              devicePixelRatio:2.0 screenDensity:326 
                cpuArchitecture:@"Apple A12 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone11,2" name:@"iPhone XS" 
                  resolution:@"2436x1125" viewportResolution:@"2436x1125" 
              devicePixelRatio:3.0 screenDensity:458 
                cpuArchitecture:@"Apple A12 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone11,6" name:@"iPhone XS Max" 
                  resolution:@"2688x1242" viewportResolution:@"2688x1242" 
              devicePixelRatio:3.0 screenDensity:458 
                cpuArchitecture:@"Apple A12 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone12,1" name:@"iPhone 11" 
                  resolution:@"1792x828" viewportResolution:@"1792x828" 
              devicePixelRatio:2.0 screenDensity:326 
                cpuArchitecture:@"Apple A13 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone12,3" name:@"iPhone 11 Pro" 
                  resolution:@"2436x1125" viewportResolution:@"2436x1125" 
              devicePixelRatio:3.0 screenDensity:458 
                cpuArchitecture:@"Apple A13 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone12,5" name:@"iPhone 11 Pro Max" 
                  resolution:@"2688x1242" viewportResolution:@"2688x1242" 
              devicePixelRatio:3.0 screenDensity:458 
                cpuArchitecture:@"Apple A13 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone12,8" name:@"iPhone SE (2nd Gen)" 
                  resolution:@"1334x750" viewportResolution:@"1334x750" 
              devicePixelRatio:2.0 screenDensity:326 
                cpuArchitecture:@"Apple A13 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone13,1" name:@"iPhone 12 mini" 
                  resolution:@"2340x1080" viewportResolution:@"2340x1080" 
              devicePixelRatio:3.0 screenDensity:476 
                cpuArchitecture:@"Apple A14 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone13,2" name:@"iPhone 12" 
                  resolution:@"2532x1170" viewportResolution:@"2532x1170" 
              devicePixelRatio:3.0 screenDensity:460 
                cpuArchitecture:@"Apple A14 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone13,3" name:@"iPhone 12 Pro" 
                  resolution:@"2532x1170" viewportResolution:@"2532x1170" 
              devicePixelRatio:3.0 screenDensity:460 
                cpuArchitecture:@"Apple A14 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone13,4" name:@"iPhone 12 Pro Max" 
                  resolution:@"2778x1284" viewportResolution:@"2778x1284" 
              devicePixelRatio:3.0 screenDensity:458 
                cpuArchitecture:@"Apple A14 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone14,4" name:@"iPhone 13 mini" 
                  resolution:@"2340x1080" viewportResolution:@"2340x1080" 
              devicePixelRatio:3.0 screenDensity:476 
                cpuArchitecture:@"Apple A15 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone14,5" name:@"iPhone 13" 
                  resolution:@"2532x1170" viewportResolution:@"2532x1170" 
              devicePixelRatio:3.0 screenDensity:460 
                cpuArchitecture:@"Apple A15 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone14,2" name:@"iPhone 13 Pro" 
                  resolution:@"2532x1170" viewportResolution:@"2532x1170" 
              devicePixelRatio:3.0 screenDensity:460 
                cpuArchitecture:@"Apple A15 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone14,3" name:@"iPhone 13 Pro Max" 
                  resolution:@"2778x1284" viewportResolution:@"2778x1284" 
              devicePixelRatio:3.0 screenDensity:458 
                cpuArchitecture:@"Apple A15 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone14,6" name:@"iPhone SE (3rd Gen)" 
                  resolution:@"1334x750" viewportResolution:@"1334x750" 
              devicePixelRatio:2.0 screenDensity:326 
                cpuArchitecture:@"Apple A15 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone14,7" name:@"iPhone 14" 
                  resolution:@"2532x1170" viewportResolution:@"2532x1170" 
              devicePixelRatio:3.0 screenDensity:460 
                cpuArchitecture:@"Apple A15 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone14,8" name:@"iPhone 14 Plus" 
                  resolution:@"2778x1284" viewportResolution:@"2778x1284" 
              devicePixelRatio:3.0 screenDensity:458 
                cpuArchitecture:@"Apple A15 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone15,2" name:@"iPhone 14 Pro" 
                  resolution:@"2556x1179" viewportResolution:@"2556x1179" 
              devicePixelRatio:3.0 screenDensity:460 
                cpuArchitecture:@"Apple A16 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone15,3" name:@"iPhone 14 Pro Max" 
                  resolution:@"2796x1290" viewportResolution:@"2796x1290" 
              devicePixelRatio:3.0 screenDensity:460 
                cpuArchitecture:@"Apple A16 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone15,4" name:@"iPhone 15" 
                  resolution:@"2556x1179" viewportResolution:@"2556x1179" 
              devicePixelRatio:3.0 screenDensity:460 
                cpuArchitecture:@"Apple A16 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone15,5" name:@"iPhone 15 Plus" 
                  resolution:@"2796x1290" viewportResolution:@"2796x1290" 
              devicePixelRatio:3.0 screenDensity:460 
                cpuArchitecture:@"Apple A16 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone16,1" name:@"iPhone 15 Pro" 
                  resolution:@"2556x1179" viewportResolution:@"2556x1179" 
              devicePixelRatio:3.0 screenDensity:460 
                cpuArchitecture:@"Apple A17 Pro" toDict:specs];
    
    [self addSpecsForDevice:@"iPhone16,2" name:@"iPhone 15 Pro Max" 
                  resolution:@"2796x1290" viewportResolution:@"2796x1290" 
              devicePixelRatio:3.0 screenDensity:460 
                cpuArchitecture:@"Apple A17 Pro" toDict:specs];

    [self addSpecsForDevice:@"iPhone17,1" name:@"iPhone 16 Pro"
                  resolution:@"2622x1206" viewportResolution:@"2622x1206"
              devicePixelRatio:3.0 screenDensity:460
                cpuArchitecture:@"Apple A18 Pro" toDict:specs];

    [self addSpecsForDevice:@"iPhone17,2" name:@"iPhone 16 Pro Max"
                  resolution:@"2868x1320" viewportResolution:@"2868x1320"
              devicePixelRatio:3.0 screenDensity:460
                cpuArchitecture:@"Apple A18 Pro" toDict:specs];

    [self addSpecsForDevice:@"iPhone17,3" name:@"iPhone 16"
                  resolution:@"2556x1179" viewportResolution:@"2556x1179"
              devicePixelRatio:3.0 screenDensity:460
                cpuArchitecture:@"Apple A18" toDict:specs];

    [self addSpecsForDevice:@"iPhone17,4" name:@"iPhone 16 Plus"
                  resolution:@"2796x1290" viewportResolution:@"2796x1290"
              devicePixelRatio:3.0 screenDensity:460
                cpuArchitecture:@"Apple A18" toDict:specs];

    [self addSpecsForDevice:@"iPhone17,5" name:@"iPhone 16e"
                  resolution:@"2532x1170" viewportResolution:@"2532x1170"
              devicePixelRatio:3.0 screenDensity:460
                cpuArchitecture:@"Apple A18" toDict:specs];

    [self addSpecsForDevice:@"iPhone18,1" name:@"iPhone 17 Pro"
                  resolution:@"2622x1206" viewportResolution:@"2622x1206"
              devicePixelRatio:3.0 screenDensity:460
                cpuArchitecture:@"Apple A19 Pro" toDict:specs];

    [self addSpecsForDevice:@"iPhone18,2" name:@"iPhone 17 Pro Max"
                  resolution:@"2868x1320" viewportResolution:@"2868x1320"
              devicePixelRatio:3.0 screenDensity:460
                cpuArchitecture:@"Apple A19 Pro" toDict:specs];

    [self addSpecsForDevice:@"iPhone18,3" name:@"iPhone 17"
                  resolution:@"2622x1206" viewportResolution:@"2622x1206"
              devicePixelRatio:3.0 screenDensity:460
                cpuArchitecture:@"Apple A19" toDict:specs];

    [self addSpecsForDevice:@"iPhone18,4" name:@"iPhone Air"
                  resolution:@"2736x1260" viewportResolution:@"2736x1260"
              devicePixelRatio:3.0 screenDensity:460
                cpuArchitecture:@"Apple A19 Pro" toDict:specs];

    [self addSpecsForDevice:@"iPhone18,5" name:@"iPhone 17e"
                  resolution:@"2532x1170" viewportResolution:@"2532x1170"
              devicePixelRatio:3.0 screenDensity:460
                cpuArchitecture:@"Apple A19" toDict:specs];
    
    // iPad models
    [self addSpecsForDevice:@"iPad7,5" name:@"iPad (6th Gen)" 
                  resolution:@"2048x1536" viewportResolution:@"2048x1536" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple A10 Fusion" toDict:specs];
    
    [self addSpecsForDevice:@"iPad7,11" name:@"iPad (7th Gen)" 
                  resolution:@"2160x1620" viewportResolution:@"2160x1620" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple A10 Fusion" toDict:specs];
    
    [self addSpecsForDevice:@"iPad11,6" name:@"iPad (8th Gen)" 
                  resolution:@"2160x1620" viewportResolution:@"2160x1620" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple A12 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPad12,1" name:@"iPad (9th Gen)" 
                  resolution:@"2160x1620" viewportResolution:@"2160x1620" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple A13 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPad13,18" name:@"iPad (10th Gen)" 
                  resolution:@"2360x1640" viewportResolution:@"2360x1640" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple A14 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPad11,3" name:@"iPad Air (3rd Gen)" 
                  resolution:@"2224x1668" viewportResolution:@"2224x1668" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple A12 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPad13,1" name:@"iPad Air (4th Gen)" 
                  resolution:@"2360x1640" viewportResolution:@"2360x1640" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple A14 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPad13,16" name:@"iPad Air (5th Gen)" 
                  resolution:@"2360x1640" viewportResolution:@"2360x1640" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple M1" toDict:specs];
    
    [self addSpecsForDevice:@"iPad8,1" name:@"iPad Pro 11\" (1st Gen)" 
                  resolution:@"2388x1668" viewportResolution:@"2388x1668" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple A12X Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPad8,9" name:@"iPad Pro 11\" (2nd Gen)" 
                  resolution:@"2388x1668" viewportResolution:@"2388x1668" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple A12Z Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPad13,4" name:@"iPad Pro 11\" (3rd Gen)" 
                  resolution:@"2388x1668" viewportResolution:@"2388x1668" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple M1" toDict:specs];
    
    [self addSpecsForDevice:@"iPad14,3" name:@"iPad Pro 11\" (4th Gen)" 
                  resolution:@"2388x1668" viewportResolution:@"2388x1668" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple M2" toDict:specs];
    
    [self addSpecsForDevice:@"iPad8,5" name:@"iPad Pro 12.9\" (3rd Gen)" 
                  resolution:@"2732x2048" viewportResolution:@"2732x2048" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple A12X Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPad8,11" name:@"iPad Pro 12.9\" (4th Gen)" 
                  resolution:@"2732x2048" viewportResolution:@"2732x2048" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple A12Z Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPad13,8" name:@"iPad Pro 12.9\" (5th Gen)" 
                  resolution:@"2732x2048" viewportResolution:@"2732x2048" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple M1" toDict:specs];
    
    [self addSpecsForDevice:@"iPad14,5" name:@"iPad Pro 12.9\" (6th Gen)" 
                  resolution:@"2732x2048" viewportResolution:@"2732x2048" 
              devicePixelRatio:2.0 screenDensity:264 
                cpuArchitecture:@"Apple M2" toDict:specs];
    
    [self addSpecsForDevice:@"iPad11,1" name:@"iPad Mini (5th Gen)" 
                  resolution:@"2048x1536" viewportResolution:@"2048x1536" 
              devicePixelRatio:2.0 screenDensity:326 
                cpuArchitecture:@"Apple A12 Bionic" toDict:specs];
    
    [self addSpecsForDevice:@"iPad14,1" name:@"iPad Mini (6th Gen)" 
                  resolution:@"2266x1488" viewportResolution:@"2266x1488" 
              devicePixelRatio:2.0 screenDensity:326 
                cpuArchitecture:@"Apple A15 Bionic" toDict:specs];
                
    // Store all specifications
    self.deviceSpecifications = [specs copy];
}

- (void)addSpecsForDevice:(NSString *)modelIdentifier 
                     name:(NSString *)name 
               resolution:(NSString *)resolution 
       viewportResolution:(NSString *)viewportResolution 
        devicePixelRatio:(CGFloat)devicePixelRatio 
           screenDensity:(NSInteger)screenDensity 
         cpuArchitecture:(NSString *)cpuArchitecture 
                 toDict:(NSMutableDictionary *)specs {
                 
    // Add device memory and GPU info based on model
    NSInteger deviceMemory = 0;
    NSString *gpuFamily = nil;
    NSDictionary *webGLInfo = nil;
    NSInteger webGLMaxTextureSize = 0;
    NSInteger webGLMaxRenderbufferSize = 0;
    NSInteger cpuCoreCount = 0;
    NSString *metalFeatureSet = nil;
    
    // BoardID and HwModel are independent optional fields.
    NSString *boardID = nil;
    NSString *hwModel = nil;
    
    // Map device identifiers to Board IDs and hw.model values
    // This follows Apple's internal mapping for different device variants
    if ([modelIdentifier isEqualToString:@"iPhone10,2"]) { // iPhone 8 Plus
        boardID = @"D211AP";
        hwModel = @"D211AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone10,3"]) { // iPhone X
        boardID = @"D221AP";
        hwModel = @"D221AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone11,8"]) { // iPhone XR
        boardID = @"N841AP";
        hwModel = @"D331AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone11,2"]) { // iPhone XS
        boardID = @"D321AP";
        hwModel = @"D321AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone11,6"]) { // iPhone XS Max
        boardID = @"D331AP";
        hwModel = @"D331AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone12,1"]) { // iPhone 11
        boardID = @"N104AP";
        hwModel = @"D421AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone12,3"]) { // iPhone 11 Pro
        boardID = @"D431AP";
        hwModel = @"D431AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone12,5"]) { // iPhone 11 Pro Max
        boardID = @"D441AP";
        hwModel = @"D441AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone12,8"]) { // iPhone SE 2nd Gen
        boardID = @"D79AP";
        hwModel = @"D79AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone13,1"]) { // iPhone 12 mini
        boardID = @"D52gAP";
        hwModel = @"D52gAP";
    } else if ([modelIdentifier isEqualToString:@"iPhone13,2"]) { // iPhone 12
        boardID = @"D53gAP";
        hwModel = @"D53gAP";
    } else if ([modelIdentifier isEqualToString:@"iPhone13,3"]) { // iPhone 12 Pro
        boardID = @"D53pAP";
        hwModel = @"D53pAP";
    } else if ([modelIdentifier isEqualToString:@"iPhone13,4"]) { // iPhone 12 Pro Max
        boardID = @"D54pAP";
        hwModel = @"D54pAP";
    } else if ([modelIdentifier isEqualToString:@"iPhone14,4"]) { // iPhone 13 mini
        boardID = @"D16AP";
        hwModel = @"D16AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone14,5"]) { // iPhone 13
        boardID = @"D17AP";
        hwModel = @"D17AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone14,2"]) { // iPhone 13 Pro
        boardID = @"D63AP";
        hwModel = @"D63AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone14,3"]) { // iPhone 13 Pro Max
        boardID = @"D64AP";
        hwModel = @"D64AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone14,6"]) { // iPhone SE 3rd Gen
        boardID = @"D49AP";
        hwModel = @"D49AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone14,7"]) { // iPhone 14
        boardID = @"D27AP";
        hwModel = @"D27AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone14,8"]) { // iPhone 14 Plus
        boardID = @"D28AP";
        hwModel = @"D28AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone15,2"]) { // iPhone 14 Pro
        boardID = @"D73AP";
        hwModel = @"D73AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone15,3"]) { // iPhone 14 Pro Max
        boardID = @"D74AP";
        hwModel = @"D74AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone15,4"]) { // iPhone 15
        boardID = @"D37AP";
        hwModel = @"D37AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone15,5"]) { // iPhone 15 Plus
        boardID = @"D38AP";
        hwModel = @"D38AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone16,1"]) { // iPhone 15 Pro
        boardID = @"D83AP";
        hwModel = @"D83AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone16,2"]) { // iPhone 15 Pro Max
        boardID = @"D84AP";
        hwModel = @"D84AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone17,1"]) { // iPhone 16 Pro
        boardID = @"D93AP";
        hwModel = @"D93AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone17,2"]) { // iPhone 16 Pro Max
        boardID = @"D94AP";
        hwModel = @"D94AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone17,3"]) { // iPhone 16
        boardID = @"D47AP";
        hwModel = @"D47AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone17,4"]) { // iPhone 16 Plus
        boardID = @"D48AP";
        hwModel = @"D48AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone17,5"]) { // iPhone 16e
        boardID = @"V59AP";
        hwModel = @"V59AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone18,1"]) { // iPhone 17 Pro
        boardID = @"V53AP";
        hwModel = @"V53AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone18,2"]) { // iPhone 17 Pro Max
        boardID = @"V54AP";
        hwModel = @"V54AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone18,3"]) { // iPhone 17
        boardID = @"V57AP";
        hwModel = @"V57AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone18,4"]) { // iPhone Air
        boardID = @"D23AP";
        hwModel = @"D23AP";
    } else if ([modelIdentifier isEqualToString:@"iPhone18,5"]) { // iPhone 17e
        boardID = @"V159AP";
        hwModel = @"V159AP";
    }
    // iPad Board IDs
    else if ([modelIdentifier isEqualToString:@"iPad7,5"]) { // iPad 6th Gen
        boardID = @"J71bAP";
        hwModel = @"J71bAP";
    } else if ([modelIdentifier isEqualToString:@"iPad7,11"]) { // iPad 7th Gen
        boardID = @"J171AP";
        hwModel = @"J171AP";
    } else if ([modelIdentifier isEqualToString:@"iPad11,6"]) { // iPad 8th Gen
        boardID = @"J171aAP";
        hwModel = @"J171aAP";
    } else if ([modelIdentifier isEqualToString:@"iPad12,1"]) { // iPad 9th Gen
        boardID = @"J181AP";
        hwModel = @"J181AP";
    } else if ([modelIdentifier isEqualToString:@"iPad13,18"]) { // iPad 10th Gen
        boardID = @"J181fAP";
        hwModel = @"J181fAP";
    } else if ([modelIdentifier isEqualToString:@"iPad11,3"]) { // iPad Air 3rd Gen
        boardID = @"J217AP";
        hwModel = @"J217AP";
    } else if ([modelIdentifier isEqualToString:@"iPad13,1"]) { // iPad Air 4th Gen
        boardID = @"J307AP";
        hwModel = @"J307AP";
    } else if ([modelIdentifier isEqualToString:@"iPad13,16"]) { // iPad Air 5th Gen
        boardID = @"J407AP";
        hwModel = @"J407AP";
    } else if ([modelIdentifier isEqualToString:@"iPad8,1"]) { // iPad Pro 11" 1st Gen
        boardID = @"J317AP";
        hwModel = @"J317AP";
    } else if ([modelIdentifier isEqualToString:@"iPad8,9"]) { // iPad Pro 11" 2nd Gen
        boardID = @"J417AP";
        hwModel = @"J417AP";
    } else if ([modelIdentifier isEqualToString:@"iPad13,4"]) { // iPad Pro 11" 3rd Gen
        boardID = @"J517AP";
        hwModel = @"J517AP";
    } else if ([modelIdentifier isEqualToString:@"iPad14,3"]) { // iPad Pro 11" 4th Gen
        boardID = @"J617AP";
        hwModel = @"J617AP";
    } else if ([modelIdentifier isEqualToString:@"iPad8,5"]) { // iPad Pro 12.9" 3rd Gen
        boardID = @"J320AP";
        hwModel = @"J320AP";
    } else if ([modelIdentifier isEqualToString:@"iPad8,11"]) { // iPad Pro 12.9" 4th Gen
        boardID = @"J420AP";
        hwModel = @"J420AP";
    } else if ([modelIdentifier isEqualToString:@"iPad13,8"]) { // iPad Pro 12.9" 5th Gen
        boardID = @"J522AP";
        hwModel = @"J522AP";
    } else if ([modelIdentifier isEqualToString:@"iPad14,5"]) { // iPad Pro 12.9" 6th Gen
        boardID = @"J620AP";
        hwModel = @"J620AP";
    } else if ([modelIdentifier isEqualToString:@"iPad11,1"]) { // iPad Mini 5th Gen
        boardID = @"J210AP";
        hwModel = @"J210AP";
    } else if ([modelIdentifier isEqualToString:@"iPad14,1"]) { // iPad Mini 6th Gen
        boardID = @"J310AP";
        hwModel = @"J310AP";
    }
    
    // Set appropriate memory and GPU values based on model
    if ([modelIdentifier hasPrefix:@"iPhone8"]) {
        deviceMemory = 2;
        cpuCoreCount = 2;
        gpuFamily = @"Apple A9 GPU";
        metalFeatureSet = @"Metal 2.2";
        webGLMaxTextureSize = 8192;
        webGLMaxRenderbufferSize = 8192;
    }
    else if ([modelIdentifier hasPrefix:@"iPhone9"]) {
        deviceMemory = [modelIdentifier isEqualToString:@"iPhone9,4"] ? 3 : 2;
        cpuCoreCount = 4;
        gpuFamily = @"Apple A10 GPU";
        metalFeatureSet = @"Metal 2.2";
        webGLMaxTextureSize = 8192;
        webGLMaxRenderbufferSize = 8192;
    }
    else if ([modelIdentifier hasPrefix:@"iPhone10"]) { // iPhone 8, 8 Plus, X
        deviceMemory = [modelIdentifier isEqualToString:@"iPhone10,4"] ? 2 : 3;
        cpuCoreCount = 6; // A11: 2 performance + 4 efficiency cores
        gpuFamily = @"Apple A11 GPU";
        metalFeatureSet = @"Metal 2.3";
        webGLInfo = @{
            @"unmaskedVendor": @"Apple Inc.",
            @"unmaskedRenderer": [gpuFamily copy],
            @"webglVendor": @"Apple",
            @"webglRenderer": @"Apple GPU",
            @"webglVersion": @"WebGL 2.0",
            @"maxTextureSize": @(8192),
            @"maxRenderbufferSize": @(8192)
        };
    }
    else if ([modelIdentifier hasPrefix:@"iPhone11"]) { // iPhone XR, XS, XS Max
        deviceMemory = [modelIdentifier isEqualToString:@"iPhone11,8"] ? 3 : 4;
        cpuCoreCount = 6; // A12: 2 performance + 4 efficiency cores
        gpuFamily = @"Apple A12 GPU";
        metalFeatureSet = @"Metal 2.4";
        webGLInfo = @{
            @"unmaskedVendor": @"Apple Inc.",
            @"unmaskedRenderer": [gpuFamily copy],
            @"webglVendor": @"Apple",
            @"webglRenderer": @"Apple GPU",
            @"webglVersion": @"WebGL 2.0",
            @"maxTextureSize": @(8192),
            @"maxRenderbufferSize": @(8192)
        };
    }
    else if ([modelIdentifier hasPrefix:@"iPhone12"]) { // iPhone 11, 11 Pro, 11 Pro Max, SE 2nd gen
        deviceMemory = [modelIdentifier isEqualToString:@"iPhone12,8"] ? 3 : 4;
        cpuCoreCount = 6; // A13: 2 performance + 4 efficiency cores
        gpuFamily = @"Apple A13 GPU";
        metalFeatureSet = @"Metal 3.0";
        webGLInfo = @{
            @"unmaskedVendor": @"Apple Inc.",
            @"unmaskedRenderer": [gpuFamily copy],
            @"webglVendor": @"Apple",
            @"webglRenderer": @"Apple GPU",
            @"webglVersion": @"WebGL 2.0",
            @"maxTextureSize": @(16384),
            @"maxRenderbufferSize": @(16384)
        };
    }
    else if ([modelIdentifier hasPrefix:@"iPhone13"]) { // iPhone 12 mini, 12, 12 Pro, 12 Pro Max
        if ([modelIdentifier hasSuffix:@"3"] || [modelIdentifier hasSuffix:@"4"]) { // Pro models
            deviceMemory = 6;
        } else {
            deviceMemory = 4;
        }
        cpuCoreCount = 6; // A14: 2 performance + 4 efficiency cores
        gpuFamily = @"Apple A14 GPU";
        metalFeatureSet = @"Metal 3.0";
        webGLInfo = @{
            @"unmaskedVendor": @"Apple Inc.",
            @"unmaskedRenderer": [gpuFamily copy],
            @"webglVendor": @"Apple",
            @"webglRenderer": @"Apple GPU",
            @"webglVersion": @"WebGL 2.0",
            @"maxTextureSize": @(16384),
            @"maxRenderbufferSize": @(16384)
        };
    }
    else if ([modelIdentifier hasPrefix:@"iPhone14"]) { // iPhone 13 series, 14, 14 Plus, SE 3rd gen
        if ([modelIdentifier isEqualToString:@"iPhone14,2"] || [modelIdentifier isEqualToString:@"iPhone14,3"]) { // Pro models
            deviceMemory = 6;
        } else {
            deviceMemory = 4;
        }
        cpuCoreCount = 6; // A15: 2 performance + 4 efficiency cores
        gpuFamily = @"Apple A15 GPU";
        metalFeatureSet = @"Metal 3.0";
        webGLInfo = @{
            @"unmaskedVendor": @"Apple Inc.",
            @"unmaskedRenderer": [gpuFamily copy],
            @"webglVendor": @"Apple",
            @"webglRenderer": @"Apple GPU",
            @"webglVersion": @"WebGL 2.0",
            @"maxTextureSize": @(16384),
            @"maxRenderbufferSize": @(16384)
        };
    }
    else if ([modelIdentifier hasPrefix:@"iPhone15"]) { // iPhone 14 Pro, 14 Pro Max, 15, 15 Plus
        if ([modelIdentifier isEqualToString:@"iPhone15,2"] || [modelIdentifier isEqualToString:@"iPhone15,3"]) { // Pro models
            deviceMemory = 6;
            metalFeatureSet = @"Metal 3.1"; // A16 Pro GPU has Metal 3.1
        } else {
            deviceMemory = 6; // iPhone 15, 15 Plus also 6GB
            metalFeatureSet = @"Metal 3.0"; // A16 in non-Pro models has Metal 3.0
        }
        cpuCoreCount = 6; // A16: 2 performance + 4 efficiency cores
        gpuFamily = [modelIdentifier hasPrefix:@"iPhone15,4"] || [modelIdentifier hasPrefix:@"iPhone15,5"] ? @"Apple A16 GPU" : @"Apple A16 Pro GPU";
        webGLInfo = @{
            @"unmaskedVendor": @"Apple Inc.",
            @"unmaskedRenderer": [gpuFamily copy],
            @"webglVendor": @"Apple",
            @"webglRenderer": @"Apple GPU",
            @"webglVersion": @"WebGL 2.0",
            @"maxTextureSize": @(16384),
            @"maxRenderbufferSize": @(16384)
        };
    }
    else if ([modelIdentifier hasPrefix:@"iPhone16"]) { // iPhone 15 Pro, 15 Pro Max
        deviceMemory = 8;
        cpuCoreCount = 6; // A17 Pro: 2 performance + 4 efficiency cores
        gpuFamily = @"Apple A17 Pro GPU";
        metalFeatureSet = @"Metal 3.1";
        webGLInfo = @{
            @"unmaskedVendor": @"Apple Inc.",
            @"unmaskedRenderer": [gpuFamily copy],
            @"webglVendor": @"Apple",
            @"webglRenderer": @"Apple GPU",
            @"webglVersion": @"WebGL 2.0",
            @"maxTextureSize": @(16384),
            @"maxRenderbufferSize": @(16384)
        };
    }
    else if ([modelIdentifier hasPrefix:@"iPhone17"]) { // iPhone 16 family
        deviceMemory = 8;
        cpuCoreCount = 6;
        BOOL pro = [modelIdentifier isEqualToString:@"iPhone17,1"] || [modelIdentifier isEqualToString:@"iPhone17,2"];
        gpuFamily = pro ? @"Apple A18 Pro GPU" : @"Apple A18 GPU";
        metalFeatureSet = @"Metal 3.1";
        webGLInfo = @{
            @"unmaskedVendor": @"Apple Inc.",
            @"unmaskedRenderer": [gpuFamily copy],
            @"webglVendor": @"Apple",
            @"webglRenderer": @"Apple GPU",
            @"webglVersion": @"WebGL 2.0",
            @"maxTextureSize": @(16384),
            @"maxRenderbufferSize": @(16384)
        };
    }
    else if ([modelIdentifier hasPrefix:@"iPhone18"]) { // iPhone 17 / 17e / Air / Pro family
        BOOL standard = [modelIdentifier isEqualToString:@"iPhone18,3"] || [modelIdentifier isEqualToString:@"iPhone18,5"];
        deviceMemory = standard ? 8 : 12;
        cpuCoreCount = 6;
        gpuFamily = standard ? @"Apple A19 GPU" : @"Apple A19 Pro GPU";
        metalFeatureSet = @"Metal 3.1";
        webGLInfo = @{
            @"unmaskedVendor": @"Apple Inc.",
            @"unmaskedRenderer": [gpuFamily copy],
            @"webglVendor": @"Apple",
            @"webglRenderer": @"Apple GPU",
            @"webglVersion": @"WebGL 2.0",
            @"maxTextureSize": @(16384),
            @"maxRenderbufferSize": @(16384)
        };
    }
    // iPad models
    else if ([modelIdentifier hasPrefix:@"iPad"]) {
        if ([modelIdentifier hasPrefix:@"iPad7"]) { // iPad 6th, 7th gen
            deviceMemory = 2;
            cpuCoreCount = 4; // A10: 2 performance + 2 efficiency cores
            gpuFamily = @"Apple A10 GPU";
            metalFeatureSet = @"Metal 2.2";
            webGLMaxTextureSize = 8192;
            webGLMaxRenderbufferSize = 8192;
        } 
        else if ([modelIdentifier hasPrefix:@"iPad8"]) { // iPad Pro models (3rd, 4th gen)
            deviceMemory = 4;
            cpuCoreCount = 8; // A12X/Z: 8 cores
            gpuFamily = [modelIdentifier hasPrefix:@"iPad8,1"] || [modelIdentifier hasPrefix:@"iPad8,5"] ? @"Apple A12X GPU" : @"Apple A12Z GPU";
            metalFeatureSet = @"Metal 2.4";
            webGLMaxTextureSize = 16384;
            webGLMaxRenderbufferSize = 16384;
        }
        else if ([modelIdentifier hasPrefix:@"iPad11"]) { // iPad 8th gen, iPad Air 3rd gen, iPad Mini 5th gen
            deviceMemory = 3;
            cpuCoreCount = 6; // A12: 2 performance + 4 efficiency cores
            gpuFamily = @"Apple A12 GPU";
            metalFeatureSet = @"Metal 2.4";
            webGLMaxTextureSize = 8192;
            webGLMaxRenderbufferSize = 8192;
        }
        else if ([modelIdentifier hasPrefix:@"iPad12"]) { // iPad 9th gen
            deviceMemory = 3;
            cpuCoreCount = 6; // A13: 2 performance + 4 efficiency cores
            gpuFamily = @"Apple A13 GPU";
            metalFeatureSet = @"Metal 3.0";
            webGLMaxTextureSize = 16384;
            webGLMaxRenderbufferSize = 16384;
        }
        else if ([modelIdentifier hasPrefix:@"iPad13"]) { // iPad 10th gen, iPad Air 4th gen, iPad Pro 11"/12.9" 3rd/5th gen
            if ([modelIdentifier hasPrefix:@"iPad13,4"] || [modelIdentifier hasPrefix:@"iPad13,8"]) { // M1 iPad Pros
                deviceMemory = 8;
                cpuCoreCount = 8; // M1: 4 performance + 4 efficiency cores
                gpuFamily = @"Apple M1 GPU";
                metalFeatureSet = @"Metal 3.0";
            } else { // A14-based iPads
                deviceMemory = 4;
                cpuCoreCount = 6; // A14: 2 performance + 4 efficiency cores
                gpuFamily = @"Apple A14 GPU";
                metalFeatureSet = @"Metal 3.0";
            }
            webGLMaxTextureSize = 16384;
            webGLMaxRenderbufferSize = 16384;
        }
        else if ([modelIdentifier hasPrefix:@"iPad14"]) { // iPad Mini 6th gen, iPad Pro 11"/12.9" 4th/6th gen
            if ([modelIdentifier hasPrefix:@"iPad14,3"] || [modelIdentifier hasPrefix:@"iPad14,5"]) { // M2 iPad Pros
                deviceMemory = 8;
                cpuCoreCount = 8; // M2: 4 performance + 4 efficiency cores
                gpuFamily = @"Apple M2 GPU";
                metalFeatureSet = @"Metal 3.1";
            } else { // A15-based iPad Mini
                deviceMemory = 4;
                cpuCoreCount = 6; // A15: 2 performance + 4 efficiency cores
                gpuFamily = @"Apple A15 GPU";
                metalFeatureSet = @"Metal 3.0";
            }
            webGLMaxTextureSize = 16384;
            webGLMaxRenderbufferSize = 16384;
        }

        if (PXProfileString(gpuFamily) && webGLMaxTextureSize > 0 && webGLMaxRenderbufferSize > 0) {
            webGLInfo = @{
                @"unmaskedVendor": @"Apple Inc.",
                @"unmaskedRenderer": [gpuFamily copy],
                @"webglVendor": @"Apple",
                @"webglRenderer": @"Apple GPU",
                @"webglVersion": @"WebGL 2.0",
                @"maxTextureSize": @(webGLMaxTextureSize),
                @"maxRenderbufferSize": @(webGLMaxRenderbufferSize)
            };
        }
    }
    
    if (!webGLInfo && PXProfileString(gpuFamily) && webGLMaxTextureSize > 0 && webGLMaxRenderbufferSize > 0) {
        webGLInfo = @{
            @"unmaskedVendor": @"Apple Inc.",
            @"unmaskedRenderer": [gpuFamily copy],
            @"webglVendor": @"Apple",
            @"webglRenderer": @"Apple GPU",
            @"webglVersion": @"WebGL 2.0",
            @"maxTextureSize": @(webGLMaxTextureSize),
            @"maxRenderbufferSize": @(webGLMaxRenderbufferSize)
        };
    }

    NSMutableDictionary *deviceSpecs = [NSMutableDictionary dictionary];
    deviceSpecs[@"value"] = modelIdentifier;
    if (PXProfileString(name)) deviceSpecs[@"name"] = PXProfileString(name);
    if (PXProfileString(resolution)) deviceSpecs[@"screenResolution"] = PXProfileString(resolution);
    if (PXProfileString(viewportResolution)) deviceSpecs[@"viewportResolution"] = PXProfileString(viewportResolution);
    if (devicePixelRatio > 0.0) deviceSpecs[@"devicePixelRatio"] = @(devicePixelRatio);
    if (screenDensity > 0) deviceSpecs[@"screenDensity"] = @(screenDensity);
    if (PXProfileString(cpuArchitecture)) deviceSpecs[@"cpuArchitecture"] = PXProfileString(cpuArchitecture);
    if (deviceMemory > 0) deviceSpecs[@"deviceMemory"] = @(deviceMemory);
    if (PXProfileString(gpuFamily)) deviceSpecs[@"gpuFamily"] = PXProfileString(gpuFamily);
    if (cpuCoreCount > 0) deviceSpecs[@"cpuCoreCount"] = @(cpuCoreCount);
    if (PXProfileString(metalFeatureSet)) deviceSpecs[@"metalFeatureSet"] = PXProfileString(metalFeatureSet);
    NSDictionary *canonicalWebGL = PXCanonicalWebGLInfo(webGLInfo);
    if (canonicalWebGL.count) deviceSpecs[PXDeviceSpecWebGLInfoKey] = canonicalWebGL;
    if (PXProfileString(boardID)) deviceSpecs[@"boardID"] = PXProfileString(boardID);
    if (PXProfileString(hwModel)) deviceSpecs[@"hwModel"] = PXProfileString(hwModel);
    [deviceSpecs addEntriesFromDictionary:PXHardwareCapabilitiesForModel(modelIdentifier)];

    specs[modelIdentifier] = [deviceSpecs copy];
}

#pragma mark - Device Specifications

- (NSDictionary *)deviceSpecificationsForModel:(NSString *)deviceString {
    NSString *model = PXProfileString(deviceString);
    if (!model.length) return nil;
    NSDictionary *rawSpecs = self.deviceSpecifications[model];
    return PXCanonicalDeviceSpecifications(rawSpecs, model);
}

- (NSString *)screenResolutionForModel:(NSString *)deviceString {
    NSDictionary *specs = [self deviceSpecificationsForModel:deviceString];
    return PXProfileString(specs[@"screenResolution"]);
}

- (NSString *)viewportResolutionForModel:(NSString *)deviceString {
    NSDictionary *specs = [self deviceSpecificationsForModel:deviceString];
    return PXProfileString(specs[@"viewportResolution"]);
}

- (CGFloat)devicePixelRatioForModel:(NSString *)deviceString {
    NSDictionary *specs = [self deviceSpecificationsForModel:deviceString];
    return specs ? [specs[@"devicePixelRatio"] floatValue] : 0.0;
}

- (NSInteger)screenDensityForModel:(NSString *)deviceString {
    NSDictionary *specs = [self deviceSpecificationsForModel:deviceString];
    return specs ? [specs[@"screenDensity"] integerValue] : 0;
}

- (NSString *)cpuArchitectureForModel:(NSString *)deviceString {
    NSDictionary *specs = [self deviceSpecificationsForModel:deviceString];
    return PXProfileString(specs[@"cpuArchitecture"]);
}

- (NSInteger)deviceMemoryForModel:(NSString *)deviceString {
    NSDictionary *specs = [self deviceSpecificationsForModel:deviceString];
    return specs ? [specs[@"deviceMemory"] integerValue] : 0;
}

- (NSString *)gpuFamilyForModel:(NSString *)deviceString {
    NSDictionary *specs = [self deviceSpecificationsForModel:deviceString];
    return PXProfileString(specs[@"gpuFamily"]);
}

- (NSInteger)cpuCoreCountForModel:(NSString *)deviceString {
    NSDictionary *specs = [self deviceSpecificationsForModel:deviceString];
    return specs ? [specs[@"cpuCoreCount"] integerValue] : 0;
}

- (NSString *)metalFeatureSetForModel:(NSString *)deviceString {
    NSDictionary *specs = [self deviceSpecificationsForModel:deviceString];
    return PXProfileString(specs[@"metalFeatureSet"]);
}

- (NSDictionary *)webGLInfoForModel:(NSString *)deviceString {
    NSDictionary *specs = [self deviceSpecificationsForModel:deviceString];
    return PXCanonicalWebGLInfo(specs);
}

// NEW: Board ID and hw.model getter methods
- (NSString *)boardIDForModel:(NSString *)deviceString {
    NSDictionary *specs = [self deviceSpecificationsForModel:deviceString];
    return PXProfileString(specs[@"boardID"]);
}

- (NSString *)hwModelForModel:(NSString *)deviceString {
    NSDictionary *specs = [self deviceSpecificationsForModel:deviceString];
    return PXProfileString(specs[@"hwModel"]);
}

// Processor name getter
- (NSString *)processorNameForModel:(NSString *)deviceString {
    NSDictionary *specs = [self deviceSpecificationsForModel:deviceString];
    if (!specs) {
        return @"Unknown";
    }
    
    NSString *cpuArchitecture = specs[@"cpuArchitecture"];
    if (!PXProfileString(cpuArchitecture)) {
        // Fallback to a default processor name if not found
        return @"Apple ARM64";
    }
    
    return cpuArchitecture;
}

// Add a method to get detailed CPU information
- (NSDictionary *)cpuInfoForModel:(NSString *)deviceString {
    NSDictionary *specs = [self deviceSpecificationsForModel:deviceString];
    if (!specs) {
        return @{};
    }
    
    NSString *cpuArchitecture = specs[@"cpuArchitecture"];
    NSInteger cpuCoreCount = [specs[@"cpuCoreCount"] integerValue];
    
    return @{
        @"name": cpuArchitecture ?: @"Apple ARM64",
        @"brand": cpuArchitecture ?: @"Apple ARM64", 
        @"architecture": @"ARM64",
        @"cores": @(cpuCoreCount),
        @"family": cpuArchitecture ?: @"Apple ARM64"
    };
}

- (NSString *)deviceModelNameForString:(NSString *)deviceString {
    if (!deviceString) return @"";
    
    // Clean up the device string in case it has extra characters
    NSString *cleanedDeviceString = [deviceString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSDictionary *specs = [self deviceSpecificationsForModel:cleanedDeviceString];
    if (specs) {
        return specs[@"name"];
        }
    
    // If we don't have specs for this exact model, try to find a close match
    // This handles cases where minor variations exist (like iPhone10,3 vs iPhone10,6)
    NSString *prefix = nil;
    if ([cleanedDeviceString hasPrefix:@"iPhone"]) {
        // Extract the major version number (e.g., "iPhone10" from "iPhone10,3")
        NSRange commaRange = [cleanedDeviceString rangeOfString:@","];
        if (commaRange.location != NSNotFound) {
            prefix = [cleanedDeviceString substringToIndex:commaRange.location];
        }
    } else if ([cleanedDeviceString hasPrefix:@"iPad"]) {
        NSRange commaRange = [cleanedDeviceString rangeOfString:@","];
        if (commaRange.location != NSNotFound) {
            prefix = [cleanedDeviceString substringToIndex:commaRange.location];
        }
    }
    
    // If we have a prefix, look for any model that starts with it
    if (prefix.length > 0) {
        NSArray *allKeys = [self.deviceSpecifications allKeys];
        for (NSString *key in allKeys) {
            if ([key hasPrefix:prefix]) {
                NSDictionary *altSpecs = self.deviceSpecifications[key];
                if (altSpecs && altSpecs[@"name"]) {
                    PXLog(@"[model] Found similar model %@ for unknown model %@, using name: %@", 
                          key, cleanedDeviceString, altSpecs[@"name"]);
                    return altSpecs[@"name"];
                }
            }
        }
    }
    
    // If everything fails, return the model identifier itself
    return cleanedDeviceString;
}

+ (instancetype)sharedManager {
    static DeviceModelManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (NSString *)generateDeviceModel {
    self.error = nil;
    
    // Check if current device is an iPad
    BOOL isIPad = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
    
    // Filter device models by type
    NSMutableArray *deviceModels = [NSMutableArray array];
    
    for (NSString *modelId in self.deviceSpecifications) {
        BOOL isIPadModel = [modelId hasPrefix:@"iPad"];
        if ((isIPad && isIPadModel) || (!isIPad && !isIPadModel)) {
            [deviceModels addObject:modelId];
        }
    }
    
    // If no models available (should never happen), return nil
    if (deviceModels.count == 0) {
        self.error = [NSError errorWithDomain:@"com.weaponx.device" code:1 userInfo:@{NSLocalizedDescriptionKey: @"No device models available for current device type"}];
        return nil;
    }
    
    // Pick a random device model
    NSUInteger idx = arc4random_uniform((uint32_t)deviceModels.count);
    NSString *modelString = deviceModels[idx];
    self.currentIdentifier = modelString;
    return self.currentIdentifier;
}

- (NSString *)currentDeviceModel {
    return self.currentIdentifier;
}

- (void)setCurrentDeviceModel:(NSString *)deviceModel {
    if ([self isValidDeviceModel:deviceModel]) {
        self.currentIdentifier = [deviceModel copy];
    }
}

- (BOOL)isValidDeviceModel:(NSString *)deviceModel {
    // Validation must describe the spoof target, not the physical host idiom.
    return PXValidateIdentityValue(deviceModel, PXIdentityValueKindDeviceModel, NO);
}

- (NSError *)lastError {
    return self.error;
}

@end
