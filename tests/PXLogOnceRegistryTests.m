#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#include <stdatomic.h>
#include <stdio.h>
#import "../common/PXRuntimeUtilities.m"
static NSUInteger checks, failures;
#define CHECK(value,label) do { checks++;if (!(value)) { failures++;fprintf(stderr,"FAIL: %s\n",label); } } while (0)
static void Raise(void) { [NSException raise:@"fixture" format:@"registry input fault"]; }
@interface PXLogInput : NSObject
@property (nonatomic) BOOL throws;
@property (nonatomic) NSUInteger calls;
@property (nonatomic, strong) NSObject *token;
@end
@implementation PXLogInput
- (BOOL)isKindOfClass:(Class)type {
    (void)type;self.calls++;
    (void)PXLogOnceSnapshot();
    if (PXLogOnceClaim((id)self,@"nested")) Raise();
    PXLogOnceResetNamespace((id)self);
    if (self.throws) Raise();return NO;
}
@end
// A real NSString subclass exercises Foundation's string-copy path. An NSObject
// pretending to be NSString could enter unsupported CoreFoundation internals.
@interface PXThrowLogString : NSString
@property (nonatomic) NSUInteger calls;
@property (nonatomic, strong) NSObject *token;
@end
@implementation PXThrowLogString
- (NSUInteger)length { self.calls++;return 32; }
- (void)getCharacters:(unichar *)characters range:(NSRange)range { (void)characters;(void)range;(void)PXLogOnceSnapshot();Raise(); }
- (void)getCharacters:(unichar *)characters { (void)characters;Raise(); }
- (unichar)characterAtIndex:(NSUInteger)index { (void)index;Raise();return 0; }
@end
static void Basics(void) {
    CHECK(PXLogOnceClaim(@"n",@"key"),"first namespace/key claim succeeds");
    CHECK(!PXLogOnceClaim(@"n",@"key"),"duplicate claim declines");
    CHECK(PXLogOnceClaim(@"other",@"key"),"same key in independent namespace succeeds");
    PXLogOnceResetNamespace(@"n");CHECK(PXLogOnceClaim(@"n",@"key"),"reset allows a new claim in the same namespace");
    CHECK(!PXLogOnceClaim(@"other",@"key"),"reset preserves independent namespace");
    CHECK((!PXLogOnceClaim(@"",@"x") && !PXLogOnceClaim(@"x",@"") && !PXLogOnceClaim((id)@[],@"x")),"empty and invalid inputs remain no-op");
    NSString *spaceA = @"a", *keyA = @"b\x1f" @"c", *spaceB = @"a\x1f" @"b", *keyB = @"c";
    CHECK((PXLogOnceClaim(spaceA,keyA) && PXLogOnceClaim(spaceB,keyB)),"delimiter-containing pairs do not collide");
    PXLogOnceResetNamespace(spaceA);
    CHECK((PXLogOnceClaim(spaceA,keyA) && !PXLogOnceClaim(spaceB,keyB)),"exact namespace reset never removes a delimiter-prefixed namespace");
    NSMutableString *space = [@"mutable-space" mutableCopy], *key = [@"mutable-key" mutableCopy];
    CHECK(PXLogOnceClaim(space,key),"mutable input can claim");[space setString:@"changed"];[key setString:@"changed"];
    CHECK(!PXLogOnceClaim(@"mutable-space",@"mutable-key"),"published packet detaches both mutable inputs");
    PXLogOnceResetNamespace(@"absent");
    NSDictionary *basis = PXLogOnceSnapshot();CHECK(!PXLogOnceClaim(@"n",@"key"),"warm duplicate remains declined");
    CHECK(basis == PXLogOnceSnapshot(),"warm duplicate reuses immutable packet without publication");
}
static void Concurrency(void) {
    dispatch_group_t group = dispatch_group_create();__block atomic_uint winners;atomic_init(&winners,0);
    PXLogOnceResetNamespace(@"parallel");
    for (NSUInteger i = 0; i < 64; i++) dispatch_group_async(group,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ @autoreleasepool {
        if (PXLogOnceClaim(@"parallel",@"one")) atomic_fetch_add(&winners,1);
    }});
    CHECK(dispatch_group_wait(group,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC)) == 0,"parallel claimers finish");
    CHECK(atomic_load(&winners) == 1,"one winner for concurrent identical pair");
    for (NSUInteger i = 0; i < 64; i++) dispatch_group_async(group,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ @autoreleasepool {
        NSString *key = [NSString stringWithFormat:@"key-%lu",(unsigned long)i];
        (void)PXLogOnceClaim(@"unrelated",key);PXLogOnceResetNamespace(@"parallel");
    }});
    CHECK(dispatch_group_wait(group,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC)) == 0,"concurrent resets and unrelated insertions finish");
    BOOL preserved = YES;
    for (NSUInteger i = 0; i < 64; i++) if (PXLogOnceClaim(@"unrelated",[NSString stringWithFormat:@"key-%lu",(unsigned long)i])) preserved = NO;
    CHECK(preserved,"reset publication never loses another namespace's concurrent keys");
    CHECK((PXLogOnceClaim(@"parallel",@"one") && !PXLogOnceClaim(@"parallel",@"one")),"reset makes one new winner and preserves dedup afterward");
}
static void Faults(void) {
    for (int mode = 0; mode < 3; mode++) {
        __weak NSObject *weakToken;__weak id weakInput;
        @autoreleasepool {
            id input = mode == 2 ? (id)[PXThrowLogString new] : [PXLogInput new];
            NSObject *token = [NSObject new];[input setToken:token];weakToken = token;weakInput = input;
            if (mode != 2) [input setThrows:mode == 1];
            BOOL caught = NO, result = NO;
            @try { result = PXLogOnceClaim((id)input,@"fault"); } @catch (__unused NSException *e) { caught = YES; }
            CHECK((!result && !gPXLogOncePreparing && (mode == 0 ? !caught : caught)),"foreign validation/copy failure restores preparation and publishes nothing");
            CHECK([input calls] > 0,"foreign input probe executed");
            input = nil;token = nil;
        }
        CHECK((!weakToken && !weakInput),"plain ARC releases input owner and token after exceptional exit/pool drain");
        CHECK(PXLogOnceClaim(@"after-fault",[NSString stringWithFormat:@"%d",mode]),"registry stays usable after input faults");
    }
}
int main(void) {
    @autoreleasepool { Basics();Concurrency();Faults(); }
    fprintf(stdout,"Log-once registry: %lu/%lu checks passed\n",(unsigned long)(checks-failures),(unsigned long)checks);
    return failures ? 1 : 0;
}
