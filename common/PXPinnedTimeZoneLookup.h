#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^PXPinnedTimeZoneCompletion)(NSTimeZone * _Nullable zone, NSError * _Nullable error);

/// Pure comparison against the current stored pin; does not read or mutate files.
FOUNDATION_EXPORT BOOL PXPinnedCoordinateMatchesLocation(CLLocationCoordinate2D coordinate, NSDictionary * _Nullable location);

/// One latest lookup per owner. Controls route to main; completions run on main.
/// Cancelled/superseded requests do not invoke the consumer completion.
/// Consumers owning this lookup should capture their owner weakly.
@interface PXPinnedTimeZoneLookup : NSObject
- (void)resolveCoordinate:(CLLocationCoordinate2D)coordinate completion:(PXPinnedTimeZoneCompletion _Nullable)completion;
- (void)cancel;
@end

NS_ASSUME_NONNULL_END
