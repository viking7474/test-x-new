#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#import "LocationSpoofingManager.h"
#include <math.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#include "PXLocationSnapshotValue.inc"
static NSUInteger gChecks, gFailures, gSnapshots, gAdvance, gAccuracyCalls, gContainsCalls;
static id gObservedRegion;
static NSUInteger gReceiverContains;
static BOOL gEnabled = YES, gThrowEvaluation, gRawThrows;
static double gAccuracy = 12.5, gNativeHeading = -1, gRadiusOverride = -1;
static PXLocationSpoofSnapshot *gSnapshot;
#define CHECK(v, label) do { gChecks++; if (!(v)) { gFailures++; fprintf(stderr,"FAIL: %s\n",label); } } while (0)
#define PX_RUNTIME_READ_OPERATION do {} while (0)
static PXLocationSpoofSnapshot *PXActiveLocationSnapshot(BOOL advance) { gSnapshots++; if (advance) gAdvance++; return gEnabled ? gSnapshot : nil; }
static CLLocationDirection PXNativeAccuracy(id receiver, SEL command) { (void)receiver; (void)command; gAccuracyCalls++; return gAccuracy; }
static CLLocationDirection PXNativeMagnetic(id receiver, SEL command) { (void)receiver; (void)command; return gNativeHeading; }
static CLLocationDirection PXNativeTrue(id receiver, SEL command) { (void)receiver; (void)command; return gNativeHeading; }
static BOOL PXNativeSource(id receiver, SEL command) { (void)receiver; (void)command; return YES; }
static CLLocationCoordinate2D (*gRealCenter)(id,SEL);
static BOOL (*gRealContains)(id,SEL,CLLocationCoordinate2D);
static CLLocationDistance (*gRealRadius)(id,SEL);
static CLLocationCoordinate2D PXNativeCenter(id receiver, SEL command) { return gRealCenter(receiver, command); }
static BOOL PXNativeContains(id receiver, SEL command, CLLocationCoordinate2D coordinate) {
    gContainsCalls++; if(receiver==gObservedRegion)gReceiverContains++;
    if (gThrowEvaluation && PXLocationProjectionBypassActive()) @throw [NSException exceptionWithName:@"GeometryFixture" reason:nil userInfo:nil];
    return gRealContains(receiver, command, coordinate);
}
static CLLocationDistance PXRadius(id receiver,SEL command) { return gRadiusOverride == -1 ? gRealRadius(receiver,command) : gRadiusOverride; }
#include "PXLocationDirectBodies.inc"
static IMP Replace(Class cls, SEL selector, IMP replacement) {
    Method method=class_getInstanceMethod(cls,selector); IMP original=method_getImplementation(method);
    if (!class_addMethod(cls,selector,replacement,method_getTypeEncoding(method))) method_setImplementation(class_getInstanceMethod(cls,selector),replacement);
    return original;
}
static BOOL SameCoordinate(CLLocationCoordinate2D a,CLLocationCoordinate2D b) { return a.latitude==b.latitude && a.longitude==b.longitude; }
static PXLocationSpoofSnapshot *Snapshot(CLLocationCoordinate2D coordinate,double heading) {
    PXLocationSpoofSnapshot *value=[PXLocationSpoofSnapshot new]; value.coordinate=coordinate; value.heading=heading; return value;
}
static void TestHeadingAndAssociations(void) {
    NSObject *object=[NSObject new];
    gSnapshot=Snapshot(CLLocationCoordinate2DMake(1,2),137); gEnabled=YES;
    CHECK(PXHookMagnetic(object,NULL)==137 && PXHookTrue(object,NULL)==137,"heading angles still use active snapshot");
    PXLocationSpoofSnapshot *attached=Snapshot(CLLocationCoordinate2DMake(3,4),42);
    PXAttachLocationSpoofSnapshot(object,attached);
    CHECK(PXHookMagnetic(object,NULL)==42 && PXHookTrue(object,NULL)==42,"attached heading generation stays stable while projection is active");
    NSUInteger before=gSnapshots;
    CHECK(PXHookAccuracy(object,NULL)==12.5 && gAccuracyCalls==1 && gSnapshots==before,"accuracy remains native without a manager query");
    gAccuracy=-1;
    CHECK(PXHookAccuracy(object,NULL)==-1,"negative native accuracy sentinel is preserved");
    gEnabled=NO;
    CHECK(PXHookMagnetic(object,NULL)==gNativeHeading && PXHookTrue(object,NULL)==gNativeHeading && PXHookSimulated(object,NULL),"off state ignores attached projected metadata");
    gEnabled=YES;
    CHECK(!PXHookSimulated(object,NULL) && !PXHookAccessory(object,NULL),"active source-information policy remains unchanged");
    PXLocationSpoofSnapshot *a=gSnapshot,*b=attached;
    __block atomic_bool failed; atomic_init(&failed,false);
    dispatch_apply(64,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^(size_t index){
        @autoreleasepool {
            PXAttachLocationSpoofSnapshot(object,index%2?a:b);
            PXLocationSpoofSnapshot *value=PXLocationSpoofSnapshotForObject(object);
            if(value!=a && value!=b) atomic_store(&failed,true);
        }
    });
    CHECK(!atomic_load(&failed),"concurrent association replacement returns a retained whole snapshot");
}
@interface PXValidRegionShape : NSObject
- (CLLocationCoordinate2D)center;
- (CLLocationDistance)radius;
- (BOOL)containsCoordinate:(CLLocationCoordinate2D)coordinate;
@end
@implementation PXValidRegionShape
- (CLLocationCoordinate2D)center { return CLLocationCoordinate2DMake(1,2); }
- (CLLocationDistance)radius { return 100; }
- (BOOL)containsCoordinate:(CLLocationCoordinate2D)c { return c.latitude==1; }
@end
@interface PXWrongRegionShape : NSObject
- (id)center;
- (NSInteger)radius;
- (id)containsCoordinate:(id)coordinate;
@end
@implementation PXWrongRegionShape
- (id)center { return nil; }
- (NSInteger)radius { return 1; }
- (id)containsCoordinate:(id)c { return c; }
@end
@interface PXInheritedCircle : CLCircularRegion @end
@implementation PXInheritedCircle @end
@interface PXCircleSubclass : CLCircularRegion @end
@implementation PXCircleSubclass
- (CLLocationCoordinate2D)center { return CLLocationCoordinate2DMake(7,8); }
- (BOOL)containsCoordinate:(CLLocationCoordinate2D)c { return c.longitude>0; }
@end
static BOOL Oracle(CLLocationCoordinate2D center,double radius,CLLocationCoordinate2D query) {
    BOOL enabled=gEnabled; gEnabled=NO;
    @try {
        CLCircularRegion *region=[[CLCircularRegion alloc]initWithCenter:center radius:radius identifier:@"oracle"];
        return gRealContains(region,@selector(containsCoordinate:),query);
    } @finally { gEnabled=enabled; }
}
static void TestCircularGeometry(void) {
    Class cls=objc_getClass("CLCircularRegion"),base=objc_getClass("CLRegion"),beacon=objc_getClass("CLBeaconRegion");
    BOOL supported=PXLocationCircularRegionMethodsMatch(cls);
    CHECK(PXLocationCircularRegionMethodsMatch(PXValidRegionShape.class) && !PXLocationCircularRegionMethodsMatch(PXWrongRegionShape.class) && !PXLocationCircularRegionMethodsMatch(Nil),"ABI admission rejects missing or incompatible selectors");
    if(!supported) { fprintf(stdout,"DETAIL: host circular ABI is unsupported; guarded geometry installation declined\n");return; }
    IMP baseContains=class_getMethodImplementation(base,@selector(containsCoordinate:));
    Method beaconMethod=beacon?class_getInstanceMethod(beacon,@selector(containsCoordinate:)):NULL;
    IMP beaconContains=beaconMethod?method_getImplementation(beaconMethod):NULL;
    // Seed every original before any replacement becomes callable.
    gRealCenter=(CLLocationCoordinate2D (*)(id,SEL))method_getImplementation(class_getInstanceMethod(cls,@selector(center)));
    gRealContains=(BOOL (*)(id,SEL,CLLocationCoordinate2D))method_getImplementation(class_getInstanceMethod(cls,@selector(containsCoordinate:)));
    gRealRadius=(CLLocationDistance (*)(id,SEL))method_getImplementation(class_getInstanceMethod(cls,@selector(radius)));
    Replace(cls,@selector(center),(IMP)PXHookCenter);Replace(cls,@selector(containsCoordinate:),(IMP)PXHookContains);Replace(cls,@selector(radius),(IMP)PXRadius);
    @try {
        CLCircularRegion *region=[[CLCircularRegion alloc]initWithCenter:CLLocationCoordinate2DMake(10,20) radius:500 identifier:@"original"];
        gSnapshot=Snapshot(CLLocationCoordinate2DMake(40,60),90);gEnabled=YES;
        if (!PXLocationIsKnownCircularRegion(region)) {
            fprintf(stdout,"DETAIL: native circle uses unknown concrete class; projection intentionally declined\n");
            BOOL result=YES;
            CHECK(!PXLocationProjectedCircularContains(region,gSnapshot.coordinate,gSnapshot.coordinate,&result),"unknown concrete native class falls through safely");
        } else {
            CHECK(SameCoordinate(region.center,gSnapshot.coordinate),"known circle center follows the current projected coordinate");
            CHECK([region containsCoordinate:gSnapshot.coordinate],"projected center is inside its native radius");
            CHECK(![region containsCoordinate:CLLocationCoordinate2DMake(-40,-60)],"far-away coordinate is no longer unconditionally inside");
            CLLocationCoordinate2D centers[]={ {0,179.999}, {89.99,30}, {-89.99,-170}, {0,0} };
            CLLocationCoordinate2D queries[]={ {0,-179.999}, {89.9901,31}, {-89.98,170}, {0.01,0} };
            for(NSUInteger i=0;i<4;i++) {
                gSnapshot=Snapshot(centers[i],45);
                BOOL native=Oracle(centers[i],region.radius,queries[i]);
                CHECK([region containsCoordinate:queries[i]]==native,"projected containment matches native dateline polar and ordinary geometry");
            }
            CLCircularRegion *larger=[[CLCircularRegion alloc]initWithCenter:CLLocationCoordinate2DMake(10,20) radius:1000 identifier:@"larger"];
            if(PXLocationIsKnownCircularRegion(larger)) {
                gSnapshot=Snapshot(CLLocationCoordinate2DMake(0,0),45);
                CLLocationCoordinate2D between=CLLocationCoordinate2DMake(0,0.006);
                BOOL smallExpected=Oracle(gSnapshot.coordinate,region.radius,between),largeExpected=Oracle(gSnapshot.coordinate,larger.radius,between);
                CHECK([region containsCoordinate:between]==smallExpected && [larger containsCoordinate:between]==largeExpected && smallExpected!=largeExpected,"multiple region instances retain their own native radii");
            }
            BOOL untouched=YES;
            CHECK(!PXLocationProjectedCircularContains(region,kCLLocationCoordinate2DInvalid,queries[0],&untouched) && untouched,"invalid projected coordinate leaves fallback result untouched");
            CHECK(!PXLocationProjectedCircularContains(region,centers[0],kCLLocationCoordinate2DInvalid,&untouched),"invalid query declines projection");
            CHECK(!PXLocationProjectedCircularContains(region,centers[0],queries[0],NULL),"missing output pointer declines projection");
            for(NSUInteger i=0;i<3;i++) {
                gRadiusOverride=i==0?NAN:i==1?0:-2;
                CHECK(!PXLocationProjectedCircularContains(region,centers[0],queries[0],&untouched) && !PXLocationProjectionBypassActive(),"invalid native radius restores bypass and declines projection");
            }
            gRadiusOverride=-1;gSnapshot=Snapshot(CLLocationCoordinate2DMake(40,60),90);
            BOOL native=Oracle(CLLocationCoordinate2DMake(10,20),500,CLLocationCoordinate2DMake(10,20));
            gEnabled=NO;
            CHECK([region containsCoordinate:CLLocationCoordinate2DMake(10,20)]==native && SameCoordinate(region.center,CLLocationCoordinate2DMake(10,20)),"inactive circle returns native geometry");
            gEnabled=YES;gThrowEvaluation=YES;
            BOOL failed=NO;
            @try { (void)PXLocationProjectedCircularContains(region,gSnapshot.coordinate,gSnapshot.coordinate,&untouched); }
            @catch(NSException *exception) { failed=[exception.name isEqual:@"GeometryFixture"]; }
            CHECK(failed && !PXLocationProjectionBypassActive(),"native evaluation exception releases its scope and restores bypass");
            // Through the hook, that preparation failure keeps its original
            // result rather than retrying native containment on the receiver.
            NSUInteger count=gContainsCalls, receiverCalls=gReceiverContains;
            gObservedRegion=region;
            (void)[region containsCoordinate:CLLocationCoordinate2DMake(10,20)];
            CHECK(!PXLocationProjectionBypassActive() && gContainsCalls>=count+2 && gReceiverContains==receiverCalls+1,"hook fallback calls receiver original once without retrying it");
            gThrowEvaluation=NO;
        }
        PXCircleSubclass *unknown=[[PXCircleSubclass alloc]initWithCenter:CLLocationCoordinate2DMake(1,2) radius:10 identifier:@"subclass"];
        if(object_getClass(unknown)==PXCircleSubclass.class) {
            CHECK(!PXLocationIsKnownCircularRegion(unknown) && SameCoordinate(unknown.center,CLLocationCoordinate2DMake(7,8)) && [unknown containsCoordinate:CLLocationCoordinate2DMake(0,1)],"unknown subclass preserves its own native contract");
        } else fprintf(stdout,"DETAIL: native initializer normalizes subclass; custom-subclass case unavailable\n");
        PXInheritedCircle *inherited=[[PXInheritedCircle alloc]initWithCenter:CLLocationCoordinate2DMake(1,2) radius:10 identifier:@"inherited"];
        if(object_getClass(inherited)==PXInheritedCircle.class) {
            CHECK(!PXLocationIsKnownCircularRegion(inherited) && SameCoordinate(inherited.center,CLLocationCoordinate2DMake(1,2)) && ![inherited containsCoordinate:CLLocationCoordinate2DMake(-40,-60)],"inherited unknown subclass bypasses parent projection and keeps native geometry");
        } else fprintf(stdout,"DETAIL: native initializer normalizes subclass; inherited-subclass case unavailable\n");
        CHECK(class_getMethodImplementation(base,@selector(containsCoordinate:))==baseContains,"base region implementation is untouched");
        Method after=beacon?class_getInstanceMethod(beacon,@selector(containsCoordinate:)):NULL;
        CHECK((after?method_getImplementation(after):NULL)==beaconContains,"beacon capability is not fabricated or replaced");
    } @finally {
        Replace(cls,@selector(center),(IMP)gRealCenter);Replace(cls,@selector(containsCoordinate:),(IMP)gRealContains);Replace(cls,@selector(radius),(IMP)gRealRadius);
        gThrowEvaluation=NO;gRadiusOverride=-1;gObservedRegion=nil;
    }
}
static void (*gProbe)(void);
@interface PXRawLocation : NSObject
- (CLLocationCoordinate2D)coordinate;
- (CLLocationSpeed)speed;
- (CLLocationDirection)course;
@end
@implementation PXRawLocation
- (CLLocationCoordinate2D)coordinate { if(gProbe) gProbe(); if(gRawThrows) @throw [NSException exceptionWithName:@"RawFixture" reason:nil userInfo:nil]; return CLLocationCoordinate2DMake(11,12); }
- (CLLocationSpeed)speed { if(gRawThrows) @throw [NSException exceptionWithName:@"RawFixture" reason:nil userInfo:nil]; return 13; }
- (CLLocationDirection)course { if(gRawThrows) @throw [NSException exceptionWithName:@"RawFixture" reason:nil userInfo:nil]; return 14; }
@end
static void ProbeBypass(void) {
    NSUInteger before=gSnapshots;
    CHECK(PXLocationProjectionBypassActive() && PXHookMagnetic(nil,NULL)==gNativeHeading && PXHookTrue(nil,NULL)==gNativeHeading && PXHookSimulated(nil,NULL) && PXHookAccessory(nil,NULL),"canonical reads bypass all heading and source-information projection");
    PXRawLocation *nested=[PXRawLocation new];
    CHECK(PXLocationOriginalSpeed((id)nested)==13 && PXLocationProjectionBypassActive(),"nested raw read restores its outer bypass depth");
    dispatch_semaphore_t done=dispatch_semaphore_create(0);__block BOOL otherThread=YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{otherThread=PXLocationProjectionBypassActive();dispatch_semaphore_signal(done);});
    long waited=dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC));
    CHECK(waited==0,"independent thread completed its bypass observation");if(waited)exit(1);
    CHECK(!otherThread && PXLocationProjectionBypassActive(),"bypass is thread-local while the calling thread keeps its outer depth");
    CHECK(gSnapshots==before,"bypass does not resolve a new active snapshot");
}
static void TestBypassLifetime(void) {
    PXRawLocation *raw=[PXRawLocation new];gProbe=ProbeBypass;
    CHECK(SameCoordinate(PXLocationOriginalCoordinate((id)raw),CLLocationCoordinate2DMake(11,12)) && !PXLocationProjectionBypassActive(),"coordinate bypass returns and restores canonical data");gProbe=NULL;
    CHECK(PXLocationOriginalSpeed((id)raw)==13 && PXLocationOriginalCourse((id)raw)==14,"raw speed and course retain their original values");raw=nil;
    for(NSUInteger kind=0;kind<3;kind++) {
        __weak PXRawLocation *weak;
        @autoreleasepool {
            PXRawLocation *owner=[PXRawLocation new];weak=owner;gRawThrows=YES;BOOL caught=NO;
            @try { if(kind==0)(void)PXLocationOriginalCoordinate((id)owner);else if(kind==1)(void)PXLocationOriginalSpeed((id)owner);else(void)PXLocationOriginalCourse((id)owner); }
            @catch(NSException *exception) { caught=YES;(void)exception; }
            @finally { owner=nil;gRawThrows=NO; }
            CHECK(caught && !PXLocationProjectionBypassActive(),"raw getter exception restores bypass exactly once");
        }
        CHECK(weak==nil,"raw getter exceptional path releases its retained location parameter");
    }
}
int main(void) {
    @autoreleasepool { TestHeadingAndAssociations();TestCircularGeometry();TestBypassLifetime();CHECK(gAdvance==0,"direct geometry and heading never advance location generation"); }
    printf("Location projection semantics: %lu/%lu checks passed\n",(unsigned long)(gChecks-gFailures),(unsigned long)gChecks);return gFailures?1:0;
}
