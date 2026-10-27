#import "PXPinnedTimeZoneLookup.h"
#import <dispatch/dispatch.h>

BOOL PXPinnedCoordinateMatchesLocation(CLLocationCoordinate2D coordinate, NSDictionary *location) {
    if (![location isKindOfClass:NSDictionary.class] || !CLLocationCoordinate2DIsValid(coordinate)) return NO;
    id latitude = location[@"latitude"], longitude = location[@"longitude"];
    return [latitude isKindOfClass:NSNumber.class] && [longitude isKindOfClass:NSNumber.class] &&
        [latitude doubleValue] == coordinate.latitude && [longitude doubleValue] == coordinate.longitude;
}

@interface PXPinnedTimeZoneLookup ()
@property (nonatomic, strong) CLGeocoder *geocoder;
@property (nonatomic, strong) NSObject *token;
@end

@implementation PXPinnedTimeZoneLookup

- (void)cancel {
    if (!NSThread.isMainThread) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf cancel]; });
        return;
    }
    self.token = nil;
    CLGeocoder *geocoder = self.geocoder;
    self.geocoder = nil;
    [geocoder cancelGeocode];
}

- (void)resolveCoordinate:(CLLocationCoordinate2D)coordinate completion:(PXPinnedTimeZoneCompletion)completion {
    if (!NSThread.isMainThread) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf resolveCoordinate:coordinate completion:completion]; });
        return;
    }
    [self cancel];
    if (!completion) return;
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        completion(nil, [NSError errorWithDomain:@"com.hydra.tlinkios.timezone-lookup" code:1
            userInfo:@{NSLocalizedDescriptionKey: @"Invalid pinned coordinates"}]);
        return;
    }
    NSObject *token = [NSObject new];
    self.token = token;
    self.geocoder = [CLGeocoder new];
    CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    __weak typeof(self) weakSelf = self;
    [self.geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || token != self.token) return;
            // Release this request before calling a consumer that may start another.
            self.token = nil;
            self.geocoder = nil;
            id placemark = [placemarks isKindOfClass:NSArray.class] ? placemarks.firstObject : nil;
            NSTimeZone *zone = [placemark isKindOfClass:CLPlacemark.class] ? [placemark timeZone] : nil;
            if (error) completion(nil, error);
            else if ([zone isKindOfClass:NSTimeZone.class]) completion(zone, nil);
            else completion(nil, [NSError errorWithDomain:@"com.hydra.tlinkios.timezone-lookup" code:2
                userInfo:@{NSLocalizedDescriptionKey: @"No time zone for pinned coordinates"}]);
        });
    }];
}

- (void)dealloc {
    CLGeocoder *geocoder = _geocoder;
    if (NSThread.isMainThread) [geocoder cancelGeocode];
    else if (geocoder) dispatch_async(dispatch_get_main_queue(), ^{ [geocoder cancelGeocode]; });
}

@end
