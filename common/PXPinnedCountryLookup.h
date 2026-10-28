#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^PXPinnedCountryCompletion)(NSString * _Nullable countryCode);

/// Latest reverse-country request per owner. Controls/completions use main;
/// superseded/cancelled results are dropped. Consumers must weak-capture owners.
@interface PXPinnedCountryLookup : NSObject
- (void)resolveCoordinate:(CLLocationCoordinate2D)coordinate
               completion:(nullable PXPinnedCountryCompletion)completion;
- (void)cancel;
@end

NS_ASSUME_NONNULL_END
