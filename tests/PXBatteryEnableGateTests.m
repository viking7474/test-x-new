#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <string.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

// Declarations match the real public interface used by the exact gate.
@interface IdentifierManager : NSObject
+ (instancetype)sharedManager;
- (BOOL)isIdentifierEnabled:(NSString *)type;
@end
static NSUInteger gChecks, gFailures, gLookups, gScopeReads, gFactoryCalls, gEnabledCalls, gSignatures, gInvocations, gWrongArguments;
static BOOL gAllowed, gEnabled, gThrowFactory, gThrowEnabled, gThrowSignature, gThrowBundle, gThrowScope, gFreshForwardedManager;
static NSString *gBundleID;
static Class gFactoryClass;
static __weak id gLastBundle, gLastForwardedManager;
static id gManager, gFactorySignature, gEnabledSignature;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)
#define PX_RUNTIME_READ_OPERATION do {} while (0)
#define PXScopeOptionNone 0
// The throwing collaborator borrows inputs so lifetime checks isolate gate ownership.
static BOOL PXProcessIsAllowedForSpoofing(NSString * __unsafe_unretained bundle, NSString * __unsafe_unretained process, NSUInteger options) {
    (void)process; gScopeReads++;
    if (gThrowScope) [NSException raise:@"fixture.scope" format:@"scope failed"];
    if (options != PXScopeOptionNone) gWrongArguments++;
    return bundle.length && gAllowed;
}
@interface PXGateBundle : NSObject
+ (instancetype)mainBundle;
- (NSString *)bundleIdentifier;
@end
@implementation PXGateBundle
+ (instancetype)mainBundle { id value = [self new]; gLastBundle = value; return value; }
- (NSString *)bundleIdentifier {
    if (gThrowBundle) [NSException raise:@"fixture.bundle" format:@"bundle failed"];
    return gBundleID;
}
@end
static Class PXGateClassFromString(NSString *name) {
    gLookups++; if (![name isEqual:@"IdentifierManager"]) gWrongArguments++;
    return gFactoryClass;
}
@interface PXGateInvocationFactory : NSInvocation
+ (instancetype)invocationWithMethodSignature:(NSMethodSignature *)signature;
@end
@implementation PXGateInvocationFactory
+ (instancetype)invocationWithMethodSignature:(NSMethodSignature *)signature {
    gInvocations++; return (id)[NSInvocation invocationWithMethodSignature:signature];
}
@end
@interface PXGoodManager : NSObject
- (BOOL)isIdentifierEnabled:(NSString *)type;
@end
@implementation PXGoodManager
- (BOOL)isIdentifierEnabled:(NSString *)type {
    gEnabledCalls++; if (![type isEqual:@"Battery"]) gWrongArguments++;
    if (gThrowEnabled) [NSException raise:@"fixture.enabled" format:@"enabled failed"];
    return gEnabled;
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    gSignatures++; return [super methodSignatureForSelector:selector];
}
@end
@interface PXGoodFactory : NSObject
+ (id)sharedManager;
@end
@implementation PXGoodFactory
+ (id)sharedManager {
    gFactoryCalls++;
    if (gThrowFactory) [NSException raise:@"fixture.factory" format:@"factory failed"];
    return gManager;
}
+ (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    gSignatures++; return [super methodSignatureForSelector:selector];
}
@end
@interface PXForwardFactory : NSObject @end
@implementation PXForwardFactory
+ (BOOL)respondsToSelector:(SEL)selector { return selector == @selector(sharedManager) || [super respondsToSelector:selector]; }
+ (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    gSignatures++;
    if (gThrowSignature) [NSException raise:@"fixture.signature" format:@"signature failed"];
    return selector == @selector(sharedManager) ? gFactorySignature : [super methodSignatureForSelector:selector];
}
+ (void)forwardInvocation:(NSInvocation *)invocation {
    if (invocation.selector != @selector(sharedManager)) { [super forwardInvocation:invocation]; return; }
    gFactoryCalls++;
    if (gThrowFactory) [NSException raise:@"fixture.factory" format:@"forwarded factory failed"];
    if (gFreshForwardedManager) {
        // A forwarded +0 object result must remain valid after forwardInvocation.
        __autoreleasing id result = [PXGoodManager new]; gLastForwardedManager = result;
        [invocation setReturnValue:&result]; return;
    }
    __unsafe_unretained id result = gManager; [invocation setReturnValue:&result];
}
@end
@interface PXForwardManager : NSProxy @end
@implementation PXForwardManager
- (BOOL)respondsToSelector:(SEL)selector { return selector == @selector(isIdentifierEnabled:); }
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    gSignatures++;
    if (gThrowSignature) [NSException raise:@"fixture.signature" format:@"signature failed"];
    return selector == @selector(isIdentifierEnabled:) ? gEnabledSignature : nil;
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    gEnabledCalls++;
    __unsafe_unretained id argument = nil; [invocation getArgument:&argument atIndex:2];
    if (![argument isEqual:@"Battery"]) gWrongArguments++;
    if (gThrowEnabled) [NSException raise:@"fixture.enabled" format:@"forwarded enabled failed"];
    BOOL value = gEnabled; [invocation setReturnValue:&value];
}
@end
#define NSBundle PXGateBundle
#define NSClassFromString PXGateClassFromString
#define NSInvocation PXGateInvocationFactory
#include "PXBatteryEnableGate.inc"
#undef NSInvocation
#undef NSClassFromString
#undef NSBundle

static const char *BoolMethodType(void) { return @encode(BOOL)[0] == 'B' ? "B@:@" : "c@:@"; }
static NSString *NativeEncoding(const char *encoding) {
    if (encoding[0] == 'B') return [NSString stringWithFormat:@"%s%s", @encode(BOOL), encoding + 1];
    return [NSString stringWithUTF8String:encoding];
}
static BOOL EnabledIMP(id receiver, SEL selector, id argument) {
    (void)receiver; (void)selector; gEnabledCalls++;
    if (![argument isEqual:@"Battery"]) gWrongArguments++;
    return gEnabled;
}
static BOOL DisabledIMP(id receiver, SEL selector, id argument) { (void)receiver; (void)selector; (void)argument; gEnabledCalls++; return NO; }
static id FactoryIMP(id receiver, SEL selector) { (void)receiver; (void)selector; gFactoryCalls++; return gManager; }
static uint64_t WideIMP(id receiver, SEL selector, id argument) { (void)receiver; (void)selector; (void)argument; gEnabledCalls++; return UINT64_MAX; }
static uint64_t WideFactoryIMP(id receiver, SEL selector) { (void)receiver; (void)selector; gFactoryCalls++; return UINT64_MAX; }
static Class DynamicClass(BOOL factory, const char *encoding, IMP implementation) {
    static NSUInteger serial = 0;
    NSString *name = [NSString stringWithFormat:@"PXBatteryGateDynamic%lu", (unsigned long)++serial];
    Class cls = objc_allocateClassPair(NSObject.class, name.UTF8String, 0);
    if (!cls || !class_addMethod(factory ? object_getClass(cls) : cls, factory ? @selector(sharedManager) : @selector(isIdentifierEnabled:), implementation, encoding)) {
        fprintf(stderr, "FAIL: dynamic battery gate fixture installation\n"); exit(1);
    }
    objc_registerClassPair(cls); return cls;
}
static void Reset(void) {
    gLookups = gScopeReads = gFactoryCalls = gEnabledCalls = gSignatures = gInvocations = gWrongArguments = 0;
    gAllowed = gEnabled = YES;
    gThrowFactory = gThrowEnabled = gThrowSignature = gThrowBundle = gThrowScope = gFreshForwardedManager = NO;
    gBundleID = @"fixture.app"; gFactoryClass = PXGoodFactory.class; gManager = [PXGoodManager new];
    gFactorySignature = [NSMethodSignature signatureWithObjCTypes:"@@:"];
    gEnabledSignature = [NSMethodSignature signatureWithObjCTypes:BoolMethodType()];
}
static void TestFastPath(void) {
    Reset();
    for (NSUInteger index = 0; index < 100; index++) CHECK(isBatterySpoofingEnabled(), "concrete battery gate returns live enabled value");
    CHECK(gFactoryCalls == 100 && gEnabledCalls == 100 && gLookups == 100 && gScopeReads == 100 && !gSignatures && !gInvocations && !gWrongArguments,
          "concrete battery gate avoids provider signature requests and invocation factory calls while preserving one call per read");
    gEnabled = NO;
    CHECK(!isBatterySpoofingEnabled() && gEnabledCalls == 101, "battery gate never caches enabled YES");
    gEnabled = YES; gFactoryClass = Nil;
    CHECK(!isBatterySpoofingEnabled() && gFactoryCalls == 101, "battery gate handles missing runtime class");
    gFactoryClass = PXGoodFactory.class;
    CHECK(isBatterySpoofingEnabled() && gFactoryCalls == 102, "battery gate recovers when runtime class becomes available");
    gManager = nil; CHECK(!isBatterySpoofingEnabled(), "battery gate handles nil manager");
    gManager = [NSObject new]; CHECK(!isBatterySpoofingEnabled(), "battery gate handles missing enable selector");
    gFactoryClass = NSObject.class; CHECK(!isBatterySpoofingEnabled(), "battery gate handles missing factory selector");
    Reset(); gAllowed = NO;
    CHECK(!isBatterySpoofingEnabled() && gScopeReads == 1 && !gLookups && !gFactoryCalls && !gEnabledCalls,
          "battery scope rejection precedes every manager lookup and call");
    Reset(); gBundleID = nil;
    CHECK(!isBatterySpoofingEnabled() && !gScopeReads && !gLookups, "missing battery bundle stops before scope or manager work");
    Reset(); gThrowBundle = YES;
    @autoreleasepool { CHECK(!isBatterySpoofingEnabled() && !gLookups, "battery bundle exception remains disabled"); }
    CHECK(!gLastBundle, "battery bundle preparation releases its owned root after a getter exception");
    Reset(); gThrowScope = YES; __weak NSString *bundle = nil;
    @autoreleasepool {
        gBundleID = [NSString stringWithFormat:@"fixture.dynamic.%@", NSUUID.UUID.UUIDString]; bundle = gBundleID;
        CHECK(!isBatterySpoofingEnabled() && !gLookups, "battery scope exception remains disabled");
        gBundleID = nil;
    }
    CHECK(!bundle, "battery scope preparation releases its owned input after a predicate exception");
    Reset(); gThrowFactory = YES; CHECK(!isBatterySpoofingEnabled() && gFactoryCalls == 1 && !gEnabledCalls, "battery factory exception remains disabled without retry");
    Reset(); gThrowEnabled = YES; CHECK(!isBatterySpoofingEnabled() && gEnabledCalls == 1, "battery enable exception remains disabled without retry");
}
static void TestRuntimeABI(void) {
    const char *badReturns[] = {"Q@:@", "d@:@", "@@:@", "v@:@", "{Pair=QQ}@:@"};
    for (NSUInteger index = 0; index < sizeof(badReturns)/sizeof(*badReturns); index++) {
        Reset(); Class cls = DynamicClass(NO, badReturns[index], (IMP)WideIMP); gManager = [cls new];
        CHECK(!isBatterySpoofingEnabled() && !gEnabledCalls && !gInvocations && !gSignatures,
              "battery concrete return ABI mismatch rejects before method or invocation");
    }
    const char *badArguments[] = {"B@:", "B@:@@", "B@:Q", "B@:@?", "B@:^@", "BQ:@", "B@Q@"};
    for (NSUInteger index = 0; index < sizeof(badArguments)/sizeof(*badArguments); index++) {
        Reset(); Class cls = DynamicClass(NO, NativeEncoding(badArguments[index]).UTF8String, (IMP)WideIMP); gManager = [cls new];
        CHECK(!isBatterySpoofingEnabled() && !gEnabledCalls && !gInvocations,
              "battery concrete arguments and hidden ABI reject before invocation");
    }
    const char *badFactories[] = {"Q@:", "d@:", "v@:", "@?@:", "@@:@", "{Pair=QQ}@:"};
    for (NSUInteger index = 0; index < sizeof(badFactories)/sizeof(*badFactories); index++) {
        Reset(); gFactoryClass = DynamicClass(YES, badFactories[index], (IMP)WideFactoryIMP);
        CHECK(!isBatterySpoofingEnabled() && !gFactoryCalls && !gEnabledCalls && !gInvocations,
              "battery factory ABI mismatch rejects before unsafe object return send");
    }
    Reset(); const char *otherBool = @encode(BOOL)[0] == 'B' ? "c@:@" : "B@:@";
    Class other = DynamicClass(NO, otherBool, (IMP)WideIMP); gManager = [other new];
    CHECK(!isBatterySpoofingEnabled() && !gEnabledCalls, "battery ABI requires the platform BOOL encoding rather than same-width scalar guesses");
    Reset(); Class cls = DynamicClass(NO, BoolMethodType(), (IMP)EnabledIMP); gManager = [cls new];
    CHECK(isBatterySpoofingEnabled(), "battery gate accepts newly registered concrete manager ABI");
    Method entry = class_getInstanceMethod(cls, @selector(isIdentifierEnabled:));
    IMP previous = method_setImplementation(entry, (IMP)DisabledIMP);
    CHECK(!isBatterySpoofingEnabled() && gEnabledCalls == 2, "battery gate dispatches current swizzle rather than cached IMP");
    method_setImplementation(entry, previous);
    CHECK(isBatterySpoofingEnabled(), "battery gate observes restored implementation");
    Reset(); gFactoryClass = DynamicClass(YES, "@\"NSObject\"@:", (IMP)FactoryIMP);
    NSString *annotated = [NSString stringWithFormat:@"r%s@:@\"NSString\"", @encode(BOOL)];
    cls = DynamicClass(NO, annotated.UTF8String, (IMP)EnabledIMP); gManager = [cls new];
    Method annotatedFactory = class_getClassMethod(gFactoryClass, @selector(sharedManager));
    Method annotatedEnabled = class_getInstanceMethod(cls, @selector(isIdentifierEnabled:));
    CHECK(PXBatteryMethodHasABI(annotatedFactory, NO), "battery ABI validates annotated factory metadata independently");
    CHECK(PXBatteryMethodHasABI(annotatedEnabled, YES), "battery ABI validates qualified annotated enable metadata independently");
    BOOL accepted = isBatterySpoofingEnabled();
    if (!accepted || gSignatures || gInvocations || gWrongArguments) {
        fprintf(stderr, "ABI annotation diagnostic: factory=%s enable=%s calls=%lu/%lu signatures=%lu invocations=%lu wrongArguments=%lu\n",
                method_getTypeEncoding(annotatedFactory), method_getTypeEncoding(annotatedEnabled),
                (unsigned long)gFactoryCalls, (unsigned long)gEnabledCalls, (unsigned long)gSignatures,
                (unsigned long)gInvocations, (unsigned long)gWrongArguments);
    }
    CHECK(accepted && !gSignatures && !gInvocations && !gWrongArguments,
          "battery ABI preserves qualified bool and annotated object compatibility");
}
static void TestAnnotatedRuntimeABI(void) {
    Reset(); NSString *qualified = [NSString stringWithFormat:@"r%s@:@", @encode(BOOL)];
    Class qualifiedClass = DynamicClass(NO, qualified.UTF8String, (IMP)EnabledIMP); gManager = [qualifiedClass new];
    CHECK(isBatterySpoofingEnabled() && !gInvocations && !gSignatures,
          "battery ABI preserves const scalar qualifiers without provider signature lookup or invocation");
    Reset(); gFactoryClass = DynamicClass(YES, "R@@:", (IMP)FactoryIMP);
    CHECK(isBatterySpoofingEnabled() && !gInvocations && !gSignatures,
          "battery ABI preserves byref object factory qualifier through validated signature");
    Reset(); qualified = [NSString stringWithFormat:@"%s@:R@", @encode(BOOL)];
    qualifiedClass = DynamicClass(NO, qualified.UTF8String, (IMP)EnabledIMP); gManager = [qualifiedClass new];
    CHECK(isBatterySpoofingEnabled() && !gInvocations && !gSignatures,
          "battery ABI preserves byref object argument qualifier through validated signature");
    Reset(); size_t pointer = sizeof(id);
    NSString *factoryEncoding = [NSString stringWithFormat:@"@\"NSObject\"%zu@0:%zu", 2 * pointer, pointer];
    NSString *enabledEncoding = [NSString stringWithFormat:@"r%s%zu@0:%zu@\"NSString\"%zu", @encode(BOOL), 3 * pointer, pointer, 2 * pointer];
    gFactoryClass = DynamicClass(YES, factoryEncoding.UTF8String, (IMP)FactoryIMP);
    Class cls = DynamicClass(NO, enabledEncoding.UTF8String, (IMP)EnabledIMP); gManager = [cls new];
    CHECK(isBatterySpoofingEnabled() && !gInvocations && !gSignatures && !gWrongArguments,
          "battery annotated metadata accepts native frame and argument offsets");
    Reset(); NSString *name = [@"PXBattery" stringByPaddingToLength:160 withString:@"LongName" startingAtIndex:0];
    factoryEncoding = [NSString stringWithFormat:@"@\"%@\"@:", name];
    enabledEncoding = [NSString stringWithFormat:@"%s@:@\"%@\"", @encode(BOOL), name];
    gFactoryClass = DynamicClass(YES, factoryEncoding.UTF8String, (IMP)FactoryIMP);
    cls = DynamicClass(NO, enabledEncoding.UTF8String, (IMP)EnabledIMP); gManager = [cls new];
    CHECK(isBatterySpoofingEnabled() && !gInvocations && !gSignatures,
          "battery annotated metadata is not truncated to fixed runtime type buffers");
    Reset(); NSString *otherBool = [NSString stringWithFormat:@"%s@:@\"NSString\"", @encode(BOOL)[0] == 'B' ? "c" : "B"];
    cls = DynamicClass(NO, otherBool.UTF8String, (IMP)WideIMP); gManager = [cls new];
    CHECK(!isBatterySpoofingEnabled() && !gEnabledCalls && !gInvocations,
          "battery annotated metadata still requires exact platform BOOL rather than byte width alone");
    const char *badEnabled[] = {"Q@:@\"NSString\"", "v@:@\"NSString\"", "@\"NSNumber\"@:@", "B@:@@\"NSString\"", "B@Q@\"NSString\"", "B^@:@\"NSString\"", "B@:@?@\"NSString\""};
    for (NSUInteger index = 0; index < sizeof(badEnabled)/sizeof(*badEnabled); index++) {
        Reset(); cls = DynamicClass(NO, NativeEncoding(badEnabled[index]).UTF8String, (IMP)WideIMP); gManager = [cls new];
        CHECK(!isBatterySpoofingEnabled() && !gEnabledCalls && !gInvocations,
              "battery annotated incompatible ABI remains rejected before enable invocation");
    }
    const char *badFactories[] = {"Q@:@\"NSString\"", "@\"NSObject\"Q:", "@@:@\"NSString\"", "@?@:@\"NSString\""};
    for (NSUInteger index = 0; index < sizeof(badFactories)/sizeof(*badFactories); index++) {
        Reset(); gFactoryClass = DynamicClass(YES, badFactories[index], (IMP)WideFactoryIMP);
        CHECK(!isBatterySpoofingEnabled() && !gFactoryCalls && !gEnabledCalls && !gInvocations,
              "battery annotated incompatible factory remains rejected before object result send");
    }
}
static void TestForwarding(void) {
    Reset(); gManager = [PXForwardManager alloc];
    CHECK(isBatterySpoofingEnabled() && gEnabledCalls == 1 && gInvocations == 1 && !gWrongArguments,
          "battery enable full forwarding remains compatible with validated BOOL object signature");
    gEnabled = NO;
    CHECK(!isBatterySpoofingEnabled() && gEnabledCalls == 2 && gInvocations == 2,
          "battery forwarded enable keeps live false without caching or retry");
    Reset(); gFactoryClass = PXForwardFactory.class;
    CHECK(isBatterySpoofingEnabled() && gFactoryCalls == 1 && gEnabledCalls == 1 && gInvocations == 1,
          "battery factory full forwarding preserves object return ownership and invocation");
    Reset(); gFactoryClass = PXForwardFactory.class; gManager = [PXForwardManager alloc];
    CHECK(isBatterySpoofingEnabled() && gInvocations == 2 && !gWrongArguments,
          "battery factory and enable may both forward without duplicate provider calls");
    Reset(); gFactoryClass = PXForwardFactory.class; gManager = nil; gFreshForwardedManager = YES;
    @autoreleasepool {
        CHECK(isBatterySpoofingEnabled() && gLastForwardedManager && gEnabledCalls == 1,
              "battery forwarded autoreleased manager survives through its enable query");
    }
    CHECK(!gLastForwardedManager, "battery forwarded autoreleased manager is released after gate and pool cleanup");
    Reset(); gFactoryClass = PXForwardFactory.class; gManager = nil;
    CHECK(!isBatterySpoofingEnabled() && gFactoryCalls == 1 && !gEnabledCalls && gInvocations == 1,
          "battery forwarded factory may return nil without an enable call");
    const char *badEnabled[] = {"Q@:@", "d@:@", "@@:@", "v@:@", "{Pair=QQ}@:@", "B@:", "B@:@@", "B@:Q", "B@:@?", "BQ:@", "B@Q@"};
    for (NSUInteger index = 0; index < sizeof(badEnabled)/sizeof(*badEnabled); index++) {
        Reset(); gManager = [PXForwardManager alloc]; gEnabledSignature = [NSMethodSignature signatureWithObjCTypes:NativeEncoding(badEnabled[index]).UTF8String];
        CHECK(!isBatterySpoofingEnabled() && !gEnabledCalls && !gInvocations,
              "battery forwarded ABI mismatch rejects before return-buffer copy or invocation");
    }
    Reset(); gFactoryClass = PXForwardFactory.class; gFactorySignature = [NSMethodSignature signatureWithObjCTypes:"Q@:"];
    CHECK(!isBatterySpoofingEnabled() && !gFactoryCalls && !gInvocations, "battery forwarded factory rejects scalar object result");
    Reset(); gManager = [PXForwardManager alloc]; gEnabledSignature = nil;
    CHECK(!isBatterySpoofingEnabled() && !gInvocations, "battery forwarding handles missing signature");
    Reset(); gManager = [PXForwardManager alloc]; gEnabledSignature = NSNull.null;
    CHECK(!isBatterySpoofingEnabled() && !gInvocations, "battery forwarding handles unsupported signature object");
    Reset(); gManager = [PXForwardManager alloc]; gThrowSignature = YES;
    CHECK(!isBatterySpoofingEnabled() && !gInvocations, "battery forwarding signature exception remains disabled");
    Reset(); gFactoryClass = PXForwardFactory.class; gThrowFactory = YES;
    CHECK(!isBatterySpoofingEnabled() && gInvocations == 1 && !gEnabledCalls, "battery forwarded factory exception is not retried");
    Reset(); gManager = [PXForwardManager alloc]; gThrowEnabled = YES;
    CHECK(!isBatterySpoofingEnabled() && gInvocations == 1 && gEnabledCalls == 1, "battery forwarded enable exception is not retried");
}
int main(void) {
    @autoreleasepool {
        @try { TestFastPath(); TestRuntimeABI(); TestAnnotatedRuntimeABI(); TestForwarding(); }
        @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected battery enable exception: %s\n", exception.description.UTF8String); }
        printf("Battery enable gate: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
