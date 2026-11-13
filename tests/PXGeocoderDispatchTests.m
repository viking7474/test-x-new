#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <dispatch/dispatch.h>
#include <stdio.h>
#include <stdlib.h>

typedef void (^PXCompletion)(NSArray<CLPlacemark *> *, NSError *);
static NSUInteger gChecks,gFailures,gRequests,gCallbacks,gModifications;
static BOOL gActive=YES,gGateThrows,gPrepareThrows,gOriginalThrows,gClientThrows,gDeferred;
static CLLocation *gSpoofed,*gReceivedLocation;
static NSString *gReceivedAddress;
static NSArray *gResponse;
static NSError *gError;
static PXCompletion gPending;
static NSThread *gCallbackThread;
#define CHECK(v,label) do { gChecks++; if(!(v)){gFailures++;fprintf(stderr,"FAIL: %s\n",label);} } while(0)
#define PX_RUNTIME_READ_OPERATION do {} while(0)
static void PXFixtureLog(NSString *format,...) { (void)format; }
#define PXLog PXFixtureLog
@interface PXGeoManagerFacade : NSObject
+ (instancetype)sharedManager;
- (CLLocation *)modifySpoofedLocation:(CLLocation *)location;
@end
@implementation PXGeoManagerFacade
+ (instancetype)sharedManager { static PXGeoManagerFacade *value;static dispatch_once_t once;dispatch_once(&once,^{value=[PXGeoManagerFacade new];});return value; }
- (CLLocation *)modifySpoofedLocation:(CLLocation *)location { (void)location;gModifications++;if(gPrepareThrows)@throw[NSException exceptionWithName:@"PrepareFixture" reason:nil userInfo:nil];return gSpoofed; }
@end
static BOOL PXLocationManagerShouldSpoof(id manager,NSString *bundle) {
    @try { if(gGateThrows)@throw[NSException exceptionWithName:@"GateFixture" reason:nil userInfo:nil];return gActive; }
    @finally { manager=nil;bundle=nil; }
}
static void NativeCompletion(PXCompletion completion) {
    NSArray *response=nil;NSError *error=nil;
    @try {
        response=gResponse;error=gError;
        if(gOriginalThrows)@throw[NSException exceptionWithName:@"OriginalFixture" reason:nil userInfo:nil];
        if(gDeferred)gPending=[completion copy];else if(completion)completion(response,error);
    } @finally { response=nil;error=nil;completion=nil; }
}
static void PXNativeReverse(CLLocation *location,PXCompletion completion) {
    @try { gRequests++;gReceivedLocation=location;NativeCompletion(completion); }
    @finally { location=nil;completion=nil; }
}
static void PXNativeForward(NSString *address,PXCompletion completion) {
    @try { gRequests++;gReceivedAddress=address;NativeCompletion(completion); }
    @finally { address=nil;completion=nil; }
}
@interface PXGeoFixture : NSObject
#include "PXGeocoderDeclarations.inc"
@end
@implementation PXGeoFixture
#define LocationSpoofingManager PXGeoManagerFacade
#include "PXGeocoderBodies.inc"
#undef LocationSpoofingManager
@end
static PXGeoFixture *gFixture;
static void Reset(void) {
    gPending=nil;gReceivedLocation=nil;gReceivedAddress=nil;gResponse=nil;gError=nil;gCallbackThread=nil;
    gRequests=0;gCallbacks=0;gModifications=0;gActive=YES;gGateThrows=NO;gPrepareThrows=NO;gOriginalThrows=NO;gClientThrows=NO;gDeferred=NO;
    gSpoofed=[[CLLocation alloc]initWithLatitude:40 longitude:60];
}
static PXCompletion Client(id token) {
    PXCompletion completion=nil;
    @try {
        {
            completion=^(NSArray<CLPlacemark *> *places,NSError *error){
                @try {
                    (void)[token description];gCallbacks++;gCallbackThread=NSThread.currentThread;
                    CHECK(places==gResponse && error==gError,"completion receives the exact native result tuple");
                    if(gClientThrows)@throw[NSException exceptionWithName:@"ClientFixture" reason:nil userInfo:nil];
                } @finally { places=nil;error=nil; }
            };
        }
        return completion;
    } @finally { completion=nil;token=nil; }
}
static void Invoke(BOOL forward,NSString *address,CLLocation *location,PXCompletion completion) {
    @try {
        if(forward)[gFixture geocodeAddressString:address completionHandler:completion];
        else[gFixture reverseGeocodeLocation:location completionHandler:completion];
    } @finally { address=nil;location=nil;completion=nil; }
}
static void Deliver(void) {
    PXCompletion completion=nil;NSArray *response=nil;NSError *error=nil;
    @try { completion=gPending;gPending=nil;response=gResponse;error=gError;if(completion)completion(response,error); }
    @finally { completion=nil;response=nil;error=nil; }
}
static void TestCardinalityAndPayloads(void) {
    CLLocation *original=[[CLLocation alloc]initWithLatitude:1 longitude:2];
    for(NSUInteger forward=0;forward<2;forward++) {
        Reset();PXCompletion client=Client(nil);
        Invoke(forward,@"address",original,client);
        CHECK(gRequests==1 && gCallbacks==1 && gCallbackThread==NSThread.currentThread,"synchronous native delivery remains once on its original thread");
        CHECK(forward?[gReceivedAddress isEqual:@"address"]:gReceivedLocation==gSpoofed,"active request preserves address or uses the prepared location");
        Reset();gActive=NO;Invoke(forward,@"address",original,client);
        CHECK(gRequests==1 && gCallbacks==1 && gModifications==0,"inactive request forwards once without location preparation");
        CHECK(forward?[gReceivedAddress isEqual:@"address"]:gReceivedLocation==original,"inactive native payload identity is preserved");
        Reset();gGateThrows=YES;Invoke(forward,@"address",original,client);
        CHECK(gRequests==1 && gCallbacks==1,"admission preparation failure falls back to one native request");
        Reset();gOriginalThrows=YES;BOOL caught=NO;
        @try { Invoke(forward,@"address",original,client); } @catch(NSException *e){caught=[e.name isEqual:@"OriginalFixture"];}
        CHECK(caught && gRequests==1 && gCallbacks==0,"original exception propagates without a second request");
        Reset();gClientThrows=YES;caught=NO;
        @try { Invoke(forward,@"address",original,client); } @catch(NSException *e){caught=[e.name isEqual:@"ClientFixture"];}
        CHECK(caught && gRequests==1 && gCallbacks==1,"synchronous client exception propagates without request or callback replay");
        Reset();gDeferred=YES;Invoke(forward,@"address",original,client);
        CHECK(gRequests==1 && gCallbacks==0 && gPending!=nil,"native geocoder can own deferred completion after hook returns");
        Deliver();CHECK(gCallbacks==1 && gPending==nil,"deferred completion preserves result and is released");
        Reset();gDeferred=YES;Invoke(forward,@"address",original,client);
        dispatch_semaphore_t delivered=dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{
            @autoreleasepool { Deliver(); }
            dispatch_semaphore_signal(delivered);
        });
        long waited=dispatch_semaphore_wait(delivered,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC));
        CHECK(waited==0,"native background callback completed");if(waited)exit(1);
        CHECK(gCallbacks==1 && gCallbackThread!=NSThread.mainThread,"wrapper preserves native background callback queue without redispatch");
        Reset();gDeferred=YES;gClientThrows=YES;Invoke(forward,@"address",original,client);caught=NO;
        @try{Deliver();}@catch(NSException *e){caught=[e.name isEqual:@"ClientFixture"];}
        CHECK(caught && gCallbacks==1 && gRequests==1 && gPending==nil,"deferred client exception never replays the request");
        Reset();Invoke(forward,@"address",original,nil);
        CHECK(gRequests==1 && gCallbacks==0 && gModifications==0,"nil client completion is passed through once");
        client=nil;
    }
    Reset();gPrepareThrows=YES;PXCompletion client=Client(nil);
    Invoke(NO,@"address",original,client);
    CHECK(gRequests==1 && gCallbacks==1 && gReceivedLocation==original,"projection failure preserves one native request with the original location");
    Reset();gSpoofed=nil;Invoke(NO,@"address",original,client);
    CHECK(gRequests==1 && gReceivedLocation==original,"missing prepared location keeps original payload");
    Reset();Invoke(YES,nil,original,client);
    CHECK(gRequests==1 && gReceivedAddress==nil && gCallbacks==1,"nil address follows original API without fabricated validation or retry");
}
static void TestNativeCompletionRelease(void) {
    for(NSUInteger forward=0;forward<2;forward++) {
        __weak NSObject *weakToken;
        @autoreleasepool {
            Reset();gDeferred=YES;
            NSObject *token=[NSObject new];weakToken=token;
            PXCompletion completion=Client(token);
            CLLocation *location=[[CLLocation alloc]initWithLatitude:1 longitude:2];
            Invoke(forward,@"address",location,completion);
            completion=nil;token=nil;location=nil;
        }
        CHECK(weakToken!=nil && gCallbacks==0,"native pending request retains client capture after caller scope ends");
        gPending=nil;gReceivedAddress=nil;gReceivedLocation=nil;
        CHECK(weakToken==nil && gCallbacks==0,"native completion release frees wrapper captures without fabricating delivery");
    }
}
static void TestOwnedCaptureLifetime(void) {
    for(NSUInteger forward=0;forward<2;forward++) {
        for(NSUInteger fault=0;fault<3;fault++) {
            __weak NSObject *weakToken;
            __weak NSString *weakAddress;
            __weak NSArray *weakResponse;
            __weak NSError *weakError;
            @autoreleasepool {
                Reset();
                NSObject *token=[NSObject new];weakToken=token;
                NSString *address=[[NSString alloc]initWithFormat:@"owned-address-%lu-%lu",(unsigned long)forward,(unsigned long)fault];weakAddress=address;
                gResponse=[[NSArray alloc]initWithObjects:[NSObject new],nil];weakResponse=gResponse;
                gError=[[NSError alloc]initWithDomain:@"Fixture" code:1 userInfo:@{ @"unique": [NSObject new] }];weakError=gError;
                PXCompletion completion=Client(token);
                CLLocation *location=[[CLLocation alloc]initWithLatitude:1 longitude:2];
                if(fault==0)gOriginalThrows=YES;
                else if(fault==1)gClientThrows=YES;
                else {gDeferred=YES;gClientThrows=YES;}
                @try {
                    Invoke(forward,address,location,completion);
                    if(gDeferred)Deliver();
                } @catch(NSException *e){(void)e;}
                @finally {
                    completion=nil;token=nil;address=nil;location=nil;
                    gPending=nil;gReceivedAddress=nil;gReceivedLocation=nil;gResponse=nil;gError=nil;
                }
            }
            CHECK(weakToken==nil && weakAddress==nil && weakResponse==nil && weakError==nil,"exceptional original or client paths release copied handler input tuple and stack capture roots after pool drain");
        }
    }
}
int main(void) {
    @autoreleasepool {gFixture=[PXGeoFixture new];TestCardinalityAndPayloads();TestNativeCompletionRelease();TestOwnedCaptureLifetime();Reset();gFixture=nil;gSpoofed=nil;}
    printf("Geocoder dispatch: %lu/%lu checks passed\n",(unsigned long)(gChecks-gFailures),(unsigned long)gChecks);return gFailures?1:0;
}
