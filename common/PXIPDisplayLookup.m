#import "PXIPDisplayLookup.h"
#import <dispatch/dispatch.h>
#import <os/lock.h>

static NSDictionary *PXIPDisplayPayload(NSData *data, BOOL fallback) {
    if (!data.length) return nil;
    if (fallback) {
        NSString *ip = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        return ip.length ? @{ @"ip": ip } : nil;
    }
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![json isKindOfClass:NSDictionary.class]) return nil;
    id ip = json[@"ip"];
    if (![ip isKindOfClass:NSString.class] || ![ip length]) return nil;
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithObject:ip forKey:@"ip"];
    if ([json[@"country_code"] isKindOfClass:NSString.class]) payload[@"countryCode"] = json[@"country_code"];
    id zone = json[@"timezone"];
    if ([zone isKindOfClass:NSDictionary.class]) zone = zone[@"id"] ?: zone[@"name"];
    if ([zone isKindOfClass:NSString.class]) payload[@"timeZoneName"] = zone;
    if ([json[@"timezone_gmt"] isKindOfClass:NSString.class]) payload[@"timeZoneGMT"] = json[@"timezone_gmt"];
    return [payload copy];
}

@interface PXIPDisplayLookup () {
    os_unfair_lock _intentLock;
    NSObject *_workerToken;
}
@property (nonatomic, strong) NSObject *token;
@property (nonatomic, strong) NSObject *attemptToken;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) dispatch_queue_t preparationQueue;
- (void)startAttemptUsingFallback:(BOOL)fallback token:(NSObject *)token
                         prepare:(PXIPDisplayPreparation)prepare completion:(PXIPDisplayCompletion)completion;
@end

@implementation PXIPDisplayLookup
- (instancetype)init {
    if ((self = [super init])) {
        _intentLock = (os_unfair_lock){0};
        _preparationQueue = dispatch_queue_create("com.hydra.tlinkios.ip-display", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)updateWorkerToken:(NSObject *)token {
    __attribute__((objc_precise_lifetime)) NSObject *previous = nil;
    os_unfair_lock_lock(&_intentLock);
    previous = _workerToken;
    _workerToken = token;
    os_unfair_lock_unlock(&_intentLock);
    (void)previous;
}

- (BOOL)workerTokenIsCurrent:(NSObject *)token {
    os_unfair_lock_lock(&_intentLock);
    BOOL current = _workerToken == token;
    os_unfair_lock_unlock(&_intentLock);
    return current;
}

- (void)cancel {
    if (!NSThread.isMainThread) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf cancel]; });
        return;
    }
    self.token = nil;
    self.attemptToken = nil;
    [self updateWorkerToken:nil];
    NSURLSession *session = self.session;
    self.session = nil;
    [session invalidateAndCancel];
}

- (void)resolveUsingFallback:(BOOL)fallbackOnly prepare:(PXIPDisplayPreparation)prepare completion:(PXIPDisplayCompletion)completion {
    if (!NSThread.isMainThread) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf resolveUsingFallback:fallbackOnly prepare:prepare completion:completion]; });
        return;
    }
    [self cancel];
    if (!completion) return;
    NSObject *token = [NSObject new]; self.token = token;
    [self updateWorkerToken:token];
    [self startAttemptUsingFallback:fallbackOnly token:token prepare:prepare completion:completion];
}

- (void)deliverPayload:(NSDictionary *)payload token:(NSObject *)token
              prepare:(PXIPDisplayPreparation)prepare completion:(PXIPDisplayCompletion)completion {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.preparationQueue, ^{
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || ![self workerTokenIsCurrent:token]) return;
        // Short admission check only: do not hold _intentLock across persistence.
        // An admitted write may finish after cancel; serial preparation prevents
        // it overtaking a newer write. Main still drops its stale UI result.
        NSDictionary *prepared = payload && prepare ? prepare(payload) : payload;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) owner = weakSelf;
            if (!owner || owner.token != token) return;
            owner.token = nil;
            [owner updateWorkerToken:nil];
            completion(prepared);
        });
    });
}

- (void)startAttemptUsingFallback:(BOOL)fallback token:(NSObject *)token
                         prepare:(PXIPDisplayPreparation)prepare completion:(PXIPDisplayCompletion)completion {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = fallback ? 5.0 : 8.0;
    if (!fallback) config.timeoutIntervalForResource = 15.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    self.session = session;
    NSObject *attempt = [NSObject new]; self.attemptToken = attempt;
    NSURL *url = [NSURL URLWithString:(fallback ? @"https://api.ipify.org" : @"https://ipwhois.app/json/")];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    if (!fallback) [request setValue:@"WeaponX iOS App" forHTTPHeaderField:@"User-Agent"];
    __weak typeof(self) weakSelf = self;
    [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        (void)response;
        NSDictionary *payload = error ? nil : PXIPDisplayPayload(data, fallback);
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.token != token || self.attemptToken != attempt) return;
            // Clear the attempt before fallback/delivery; duplicate callbacks
            // cannot start another fallback or finish a newer session.
            self.attemptToken = nil;
            NSURLSession *finished = self.session;
            self.session = nil;
            [finished finishTasksAndInvalidate];
            if (!payload && !fallback) [self startAttemptUsingFallback:YES token:token prepare:prepare completion:completion];
            else [self deliverPayload:payload token:token prepare:prepare completion:completion];
        });
    }] resume];
}

- (void)dealloc { [_session invalidateAndCancel]; }
@end
