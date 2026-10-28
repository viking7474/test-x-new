#import "PXTargetRegionSync.h"
#import <dispatch/dispatch.h>
#import <os/lock.h>

static NSDictionary *PXTargetRegionFailure(NSString *message) {
    return @{ @"success": @NO, @"message": message };
}

static NSDictionary *PXTargetRegionResponse(NSData *data, NSError *error, NSDictionary **failure) {
    if (error || !data.length) { *failure = PXTargetRegionFailure(@"IP geo fetch failed"); return nil; }
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![json isKindOfClass:NSDictionary.class]) { *failure = PXTargetRegionFailure(@"IP geo parse failed"); return nil; }
    if (![json[@"status"] isKindOfClass:NSString.class] || ![json[@"status"] isEqualToString:@"success"]) {
        *failure = PXTargetRegionFailure(@"IP geo service error"); return nil;
    }
    if (![json[@"countryCode"] isKindOfClass:NSString.class] || ![json[@"countryCode"] length] ||
        ![json[@"lat"] isKindOfClass:NSNumber.class] || ![json[@"lon"] isKindOfClass:NSNumber.class] ||
        ![json[@"timezone"] isKindOfClass:NSString.class] || ![json[@"timezone"] length]) {
        *failure = PXTargetRegionFailure(@"IP geo missing fields"); return nil;
    }
    return json;
}

@interface PXTargetRegionSync () {
    os_unfair_lock _intentLock;
    NSObject *_workerToken;
}
@property (nonatomic, strong) NSObject *token;
@property (nonatomic, strong) NSObject *requestToken;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) dispatch_queue_t workQueue;
@end

@implementation PXTargetRegionSync
- (instancetype)init {
    if ((self = [super init])) {
        _intentLock = (os_unfair_lock){0};
        _workQueue = dispatch_queue_create("com.hydra.tlinkios.target-region", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
- (NSObject *)beginIntent {
    NSObject *token = [NSObject new];
    self.token = token;
    self.requestToken = nil;
    __attribute__((objc_precise_lifetime)) NSObject *previous = nil;
    os_unfair_lock_lock(&_intentLock);
    previous = _workerToken; _workerToken = token;
    os_unfair_lock_unlock(&_intentLock);
    (void)previous;
    NSURLSession *old = self.session; self.session = nil;
    [old invalidateAndCancel];
    return token;
}
- (BOOL)admitsToken:(NSObject *)token {
    os_unfair_lock_lock(&_intentLock);
    BOOL current = _workerToken == token;
    os_unfair_lock_unlock(&_intentLock);
    return current;
}
- (void)complete:(NSDictionary *)result token:(NSObject *)token completion:(PXTargetRegionCompletion)completion {
    if (self.token != token) return;
    self.token = nil;
    __attribute__((objc_precise_lifetime)) NSObject *previous = nil;
    os_unfair_lock_lock(&_intentLock);
    previous = _workerToken; _workerToken = nil;
    os_unfair_lock_unlock(&_intentLock);
    (void)previous;
    if (result) completion(result);
}
- (void)enqueueWork:(PXTargetRegionWork)work token:(NSObject *)token
           durable:(BOOL)durable completion:(PXTargetRegionCompletion)completion {
    // Only explicit detached setting changes outlive UI ownership. A pending
    // network/apply callback must not keep the controller alive.
    PXTargetRegionSync *keepAlive = durable ? self : nil;
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.workQueue, ^{
        __strong typeof(weakSelf) self = keepAlive ?: weakSelf;
        if (!self || ![self admitsToken:token]) return;
        // Never hold _intentLock across source/GPS/cache I/O. A newer toggle
        // is serialized after admitted sync effects, including its enable write.
        NSDictionary *result = work();
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf complete:result token:token completion:completion]; });
    });
}
- (void)performChange:(PXTargetRegionWork)work completion:(PXTargetRegionCompletion)completion {
    if (!NSThread.isMainThread) {
        // Keep the explicit command alive until main accepts it.
        dispatch_async(dispatch_get_main_queue(), ^{ [self performChange:work completion:completion]; });
        return;
    }
    if (!work || !completion) return;
    NSObject *token = [self beginIntent];
    [self enqueueWork:work token:token durable:YES completion:completion];
}
- (void)syncWithApply:(PXTargetRegionApply)apply completion:(PXTargetRegionCompletion)completion {
    if (!NSThread.isMainThread) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf syncWithApply:apply completion:completion]; });
        return;
    }
    if (!apply || !completion) return;
    NSObject *token = [self beginIntent]; self.requestToken = token;
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest = 10.0; cfg.timeoutIntervalForResource = 15.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg]; self.session = session;
    NSURL *url = [NSURL URLWithString:@"https://ip-api.com/json/?fields=status,message,countryCode,lat,lon,timezone,query"];
    __weak typeof(self) weakSelf = self;
    [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        (void)response;
        NSDictionary *failure = nil;
        NSDictionary *json = PXTargetRegionResponse(data, error, &failure);
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.token != token || self.requestToken != token) return;
            self.requestToken = nil;
            NSURLSession *finished = self.session; self.session = nil;
            [finished finishTasksAndInvalidate];
            if (!json) [self complete:failure token:token completion:completion];
            else [self enqueueWork:^NSDictionary *{ return apply(json); } token:token durable:NO completion:completion];
        });
    }] resume];
}
- (void)dealloc { [_session invalidateAndCancel]; }
@end
