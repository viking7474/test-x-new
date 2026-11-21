#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <os/lock.h>
#import <dispatch/dispatch.h>
#import "PXP1AFilters.h"
#include <stdio.h>
#include <string.h>
#include <stdatomic.h>
@interface UIImage : NSObject
@property (nonatomic,strong) NSData *data;
@end
@implementation UIImage
@end
@interface UIPasteboard : NSObject
@property (nonatomic,strong) UIImage *image;
@property (nonatomic,strong) NSURL *URL;
@property (nonatomic,strong) NSString *text;
@property (nonatomic) NSUInteger imageReads,urlReads;
- (BOOL)containsPasteboardTypes:(NSArray *)types;
- (id)valueForPasteboardType:(NSString *)type;
@end
static NSData *UIImagePNGRepresentation(UIImage *image) { @try { return image.data; } @finally { image=nil; } }
static NSUInteger checks,failures,calls[10],policyReads,scopeInvalidations;
static BOOL enabled=YES,policyThrows,nativeThrows,lastPersistent;
static NSString *uuidString=@"abcd1234-1111-2222-3333-444444444444";
static NSString *lastName;static NSURL *lastURL;static id lastInput;
static UIPasteboard *board;static dispatch_block_t duringNative,duringPolicy,duringHash;
#define PX_RUNTIME_READ_OPERATION do {} while (0)
#define CHECK(value,label) do { checks++;if (!(value)) { failures++;fprintf(stderr,"FAIL: %s\n",label); } } while (0)
static void Raise(void) { [NSException raise:@"fixture" format:@"pasteboard fault"]; }
static void Deliver(dispatch_block_t *slot) { dispatch_block_t callback=nil;@try { callback=*slot;*slot=nil;if (callback) callback(); } @finally { callback=nil; } }
static void PXInvalidateScopeDecisionCache(void) { scopeInvalidations++; }
#include "PXPasteboardBoundaries.inc"
static NSString *getCurrentBundleID(void) { return @"fixture.app"; }
static NSDictionary *loadScopedApps(void) { return @{}; }
static BOOL isInScopedAppsList(void) { return enabled; }
static BOOL shouldSpoofForBundle(NSString *bundle) { @try { (void)bundle;policyReads++;Deliver(&duringPolicy);if (policyThrows) Raise();return enabled; } @finally { bundle=nil; } }
static NSString *getSpoofedPasteboardUUID(void) { return uuidString; }
@implementation UIPasteboard
- (UIImage *)image { self.imageReads++;return _image; }
- (NSURL *)URL { self.urlReads++;return _URL; }
- (BOOL)containsPasteboardTypes:(NSArray *)types { @try { (void)types;Deliver(&duringHash);return self.text!=nil; } @finally { types=nil; } }
- (id)valueForPasteboardType:(NSString *)type { @try { return hook_valueForPasteboardType(self,_cmd,type); } @finally { type=nil; } }
@end
static void Reset(void) { clearCacheCallback(NULL,NULL,NULL,NULL,NULL);lastName=nil;lastURL=nil;lastInput=nil; }
static void Before(NSUInteger route) { calls[route]++;Deliver(&duringNative);if (nativeThrows) Raise(); }
static NSUUID *NativeUUID(id receiver,SEL cmd) { (void)receiver;(void)cmd;Before(0);return [NSUUID UUID]; }
static NSString *NativeName(id receiver,SEL cmd) { (void)receiver;(void)cmd;Before(1);return @"fixture.board"; }
static UIPasteboard *NativeNamed(id receiver,SEL cmd,NSString *name,BOOL create) { @try { (void)receiver;(void)cmd;(void)create;Before(2);lastName=name;return board; } @finally { name=nil; } }
static UIPasteboard *NativeURL(id receiver,SEL cmd,NSURL *url,BOOL create) { @try { (void)receiver;(void)cmd;(void)create;Before(3);lastURL=url;return board; } @finally { url=nil; } }
static NSInteger NativeCount(id receiver,SEL cmd) { (void)receiver;(void)cmd;Before(4);return 7; }
static void NativeSetPersistent(id receiver,SEL cmd,BOOL persistent) { (void)receiver;(void)cmd;Before(5);lastPersistent=persistent; }
static BOOL NativePersistent(id receiver,SEL cmd) { (void)receiver;(void)cmd;Before(6);return NO; }
static id NativeValue(id receiver,SEL cmd,NSString *type) { @try { (void)receiver;(void)cmd;Before(7);return [type isEqual:@"public.text"] || [type containsString:@"text"] ? board.text : @"native-value"; } @finally { type=nil; } }
static void NativeData(id receiver,SEL cmd,NSData *data,NSString *type) { @try { (void)receiver;(void)cmd;(void)type;Before(8);lastInput=data;board.text=@"data-written"; } @finally { data=nil;type=nil; } }
static void NativeItems(id receiver,SEL cmd,NSArray *items) { @try { (void)receiver;(void)cmd;Before(9);lastInput=items;board.text=@"items-written"; } @finally { items=nil; } }
static id Call(NSUInteger route) {
    switch (route) {
        case 0:return hook_uniquePasteboardUUID(board,@selector(uniquePasteboardUUID));
        case 1:return hook_name(board,@selector(name));
        case 2:return hook_pasteboardWithNameCreate(board,@selector(pasteboardWithName:create:),@"fixture.board",YES);
        case 3:return hook_pasteboardWithURLCreate(board,@selector(pasteboardWithURL:create:),[NSURL URLWithString:@"https://fixture.test/p"],YES);
        case 4:return @(hook_changeCount(board,@selector(changeCount)));
        case 5:hook_setPersistent(board,@selector(setPersistent:),NO);return nil;
        case 6:return @(hook_isPersistent(board,@selector(isPersistent)));
        case 7:return hook_valueForPasteboardType(board,@selector(valueForPasteboardType:),@"com.apple.uikit.pboard-uuid");
        case 8:hook_setDataForPasteboardType(board,@selector(setData:forPasteboardType:),[NSData data],@"public.text");return nil;
        default:hook_setItems(board,@selector(setItems:),@[]);return nil;
    }
}
static void Boundaries(void) {
    for (NSUInteger i=0;i<10;i++) {
        enabled=NO;NSUInteger before=calls[i];(void)Call(i);CHECK((calls[i]==before+1 && !gPXInsidePasteboard),"ten disabled routes forward exactly once and restore admission");
        nativeThrows=YES;BOOL caught=NO;before=calls[i];@try { (void)Call(i); } @catch (__unused NSException *e) { caught=YES; }nativeThrows=NO;
        CHECK((caught && calls[i]==before+1 && !gPXInsidePasteboard),"native failure propagates once without retry or poisoned TLS");
        policyThrows=YES;before=calls[i];(void)Call(i);policyThrows=NO;CHECK((calls[i]==before+1 && !gPXInsidePasteboard),"preparation failure keeps one native invocation");
    }
    enabled=YES;Reset();CHECK([Call(0) isKindOfClass:NSUUID.class],"UUID override remains an NSUUID");
    for (NSNumber *route in @[@2,@3,@5]) {
        NSUInteger index=route.unsignedIntegerValue,before=calls[index];BOOL caught=NO;nativeThrows=YES;
        @try { (void)Call(index); } @catch (__unused NSException *e) { caught=YES; }nativeThrows=NO;
        CHECK((caught && calls[index]==before+1 && !gPXInsidePasteboard),"transformed factory/persistence native failure is never retried with raw arguments");
    }
    CHECK([Call(1) isEqual:@"fixture.abcd1234"],"name uses real deterministic helper");
    (void)Call(2);CHECK([lastName isEqual:@"fixture.abcd1234"],"factory submits transformed name once");
    (void)Call(3);CHECK([lastURL.absoluteString isEqual:@"https://fixture.test/p?uuid=abcd1234"],"URL factory retains existing query construction");
    hook_pasteboardWithNameCreate(board,@selector(pasteboardWithName:create:),@"com.apple.UIKit.pboard.general",YES);CHECK([lastName isEqual:@"com.apple.UIKit.pboard.general"],"general pasteboard name remains unchanged");
    (void)Call(5);CHECK(lastPersistent,"scoped persistence setter still forces YES");CHECK([Call(6) boolValue],"scoped persistence getter still returns YES");
    CHECK([Call(7) isKindOfClass:NSData.class],"UUID type still returns archived data");
    duringNative=^{ (void)hook_name(board,@selector(name)); };
    NSUInteger before=policyReads;(void)Call(2);CHECK(policyReads==before+1,"native nested getter bypasses optional scope work");
    duringPolicy=^{ (void)hook_isPersistent(board,@selector(isPersistent)); };
    before=policyReads;(void)Call(1);CHECK(policyReads==before+1,"foreign policy reentry reaches native without recursive preparation");
}
static void Counters(void) {
    Reset();board.text=@"one";CHECK(hook_changeCount(board,@selector(changeCount))==8,"first hash observation preserves native-plus-one seed");
    NSDictionary *basis=PXCapturePasteboardState();CHECK((hook_changeCount(board,@selector(changeCount))==8 && PXCapturePasteboardState()==basis),"unchanged hash reuses packet without COW allocation");
    board.text=@"two";CHECK(hook_changeCount(board,@selector(changeCount))==9,"changed content increments once");
    NSUInteger images=board.imageReads,urls=board.urlReads;(void)hook_changeCount(board,@selector(changeCount));CHECK((board.imageReads==images+1 && board.urlReads==urls+1),"one image and URL getter read per hash");
    nativeThrows=YES;BOOL caught=NO;@try { (void)Call(9); } @catch (__unused NSException *e) { caught=YES; }nativeThrows=NO;
    CHECK((caught && PXCapturePasteboardState()[@"entries"][@"fixture.app"][@"count"] && [PXCapturePasteboardState()[@"entries"][@"fixture.app"][@"count"] integerValue]==9),"throwing setter never advances virtual counter");
    duringNative=^{ clearCacheCallback(NULL,NULL,NULL,NULL,NULL); };(void)Call(9);
    CHECK([PXCapturePasteboardState()[@"entries"] count]==0,"native invalidation prevents stale setter accounting");
    duringHash=^{ clearCacheCallback(NULL,NULL,NULL,NULL,NULL); };CHECK(hook_changeCount(board,@selector(changeCount))==7,"hash invalidation drops obsolete observation and returns native count");
    Reset();duringNative=^{ (void)Call(8); };(void)Call(9);CHECK([PXCapturePasteboardState()[@"entries"][@"fixture.app"][@"count"] integerValue]==1,"nested native setter delegation is accounted once after outer ACK");
    Reset();orig_setItems=NULL;(void)Call(9);CHECK([PXCapturePasteboardState()[@"entries"] count]==0,"missing setter cannot acknowledge an increment");orig_setItems=NativeItems;
    id epoch=PXCapturePasteboardState()[@"epoch"];(void)PXUpdatePasteboardState(@"overflow",NSIntegerMax,@"a",NO,epoch);
    CHECK([PXUpdatePasteboardState(@"overflow",0,nil,YES,epoch) integerValue]==NSIntegerMax,"NSIntegerMax counter saturates without signed overflow");
    clearCacheCallback(NULL,NULL,NULL,NULL,NULL);CHECK(PXUpdatePasteboardState(@"stale",0,nil,YES,epoch)==nil,"old epoch cannot republish after reset");
    epoch=PXCapturePasteboardState()[@"epoch"];dispatch_group_t group=dispatch_group_create();
    for (NSUInteger i=0;i<32;i++) dispatch_group_async(group,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ @autoreleasepool { (void)PXUpdatePasteboardState(@"parallel",0,nil,YES,epoch); } });
    CHECK((dispatch_group_wait(group,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC))==0 && [PXCapturePasteboardState()[@"entries"][@"parallel"][@"count"] integerValue]==32),"concurrent counter commits lose no increments");
    UIImage *image=[UIImage new];image.data=[@"fixture-image" dataUsingEncoding:NSUTF8StringEncoding];NSURL *url=[NSURL URLWithString:@"https://fixture.test/value"];
    board.image=image;board.URL=url;board.text=@"payload";
    NSString *input=[NSString stringWithFormat:@"%@%@%@IMG:%lu%@",board.text,board.text,board.text,(unsigned long)image.data.hash,url.absoluteString];
    NSString *expected=[NSString stringWithFormat:@"%lu",(unsigned long)input.hash];
    CHECK([getPasteboardContentHash(board) isEqual:expected],"image/data-hash and URL preserve the legacy text/PNG input composition");board.image=nil;board.URL=nil;
}
@interface PXBoardPayload : NSObject
@property (nonatomic,strong) NSObject *token;
@end
@implementation PXBoardPayload
@end
static void LifetimeAndABI(void) {
    __weak id weakInput,weakToken;
    @autoreleasepool {
        PXBoardPayload *input=[PXBoardPayload new];NSObject *token=[NSObject new];input.token=token;weakInput=input;weakToken=token;
        nativeThrows=YES;@try { hook_setItems(board,@selector(setItems:),(id)input); } @catch (__unused NSException *e) { }nativeThrows=NO;input=nil;token=nil;
    }
    lastInput=nil;CHECK((!weakInput && !weakToken && !gPXInsidePasteboard),"plain ARC native failure releases caller graph after pool drain");
    CHECK(typeEncodingCompatible("@24@0:8@16","@@:@"),"object argument ABI accepts offsets");
    CHECK(!typeEncodingCompatible("@24@0:8i16","@@:@"),"same return type does not hide incompatible argument");
    CHECK(!typeEncodingCompatible("@@:","@@:@"),"argument count must match");
    CHECK(!typeEncodingCompatible("{Point=dd}@:","@@:"),"struct return never enters object hook");
    CHECK(typeEncodingCompatible("rc@:rc","B@:B"),"qualified byte BOOL remains ABI-compatible");
    CHECK(typeEncodingCompatible("@\"NSString\"@:@\"NSString\"","@@:@"),"annotated object ABI remains compatible");
    CHECK(!typeEncodingCompatible("@?@:","@@:"),"block return does not impersonate generic object contract");
}
int main(void) {
    @autoreleasepool {
        board=[UIPasteboard new];board.text=@"native";
        orig_uniquePasteboardUUID=NativeUUID;orig_name=NativeName;orig_pasteboardWithNameCreate=NativeNamed;orig_pasteboardWithURLCreate=NativeURL;
        orig_changeCount=NativeCount;orig_setPersistent=NativeSetPersistent;orig_isPersistent=NativePersistent;orig_valueForPasteboardType=NativeValue;orig_setDataForPasteboardType=NativeData;orig_setItems=NativeItems;
        Boundaries();Counters();LifetimeAndABI();lastInput=nil;lastName=nil;lastURL=nil;board=nil;
    }
    fprintf(stdout,"Pasteboard boundary facades: %lu/%lu checks passed\n",(unsigned long)(checks-failures),(unsigned long)checks);return failures ? 1 : 0;
}
