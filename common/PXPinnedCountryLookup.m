#import "PXPinnedCountryLookup.h"
#import <dispatch/dispatch.h>

@interface PXPinnedCountryLookup ()
@property (nonatomic, strong) NSURLSessionDataTask *task;
@property (nonatomic, strong) NSObject *token;
@end

@implementation PXPinnedCountryLookup

- (void)cancel {
    if (!NSThread.isMainThread) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf cancel]; });
        return;
    }
    self.token = nil;
    NSURLSessionDataTask *task = self.task;
    self.task = nil;
    [task cancel];
}

- (void)resolveCoordinate:(CLLocationCoordinate2D)coordinate completion:(PXPinnedCountryCompletion)completion {
    if (!NSThread.isMainThread) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf resolveCoordinate:coordinate completion:completion]; });
        return;
    }
    [self cancel];
    if (!completion) return;
    if (!CLLocationCoordinate2DIsValid(coordinate)) { completion(nil); return; }
    NSString *urlString = [NSString stringWithFormat:
        @"https://nominatim.openstreetmap.org/reverse?format=json&lat=%.6f&lon=%.6f&zoom=18&addressdetails=1",
        coordinate.latitude, coordinate.longitude];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setValue:@"WeaponX iOS App" forHTTPHeaderField:@"User-Agent"];
    request.timeoutInterval = 10.0;
    NSObject *token = [NSObject new];
    self.token = token;
    __weak typeof(self) weakSelf = self;
    self.task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        (void)response;
        // Parsing stays on the transport callback; no controller/cache access.
        id json = !error && data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
        id address = [json isKindOfClass:NSDictionary.class] ? json[@"address"] : nil;
        id rawCode = [address isKindOfClass:NSDictionary.class] ? address[@"country_code"] : nil;
        NSString *code = [rawCode isKindOfClass:NSString.class] ? [rawCode uppercaseString] : nil;
        if (code.length != 2 || [code characterAtIndex:0] < 'A' || [code characterAtIndex:0] > 'Z' ||
            [code characterAtIndex:1] < 'A' || [code characterAtIndex:1] > 'Z') code = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.token != token) return;
            // Clear before consumer reentry; never invalidate the shared session.
            self.token = nil;
            self.task = nil;
            completion(code);
        });
    }];
    [self.task resume];
}

- (void)dealloc {
    [_task cancel];
}

@end
