#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "TLinkIOSLogging.h"
#import "PasteboardUUIDManager.h"
#import "IdentifierManager.h"
// #import <ellekit/ellekit.h> // Removed for rootful - using Substrate

#import "PXScope.h"
#import "PXRuntimeUtilities.h"
#import "PXRuntimeSnapshot.h"
#import "PXPaths.h"
#import "PXP1AFilters.h"
#import <os/lock.h>
#include <string.h>



// One immutable packet; collection work and retirement stay outside the lock.
static os_unfair_lock gPasteboardStateLock = OS_UNFAIR_LOCK_INIT;
static NSDictionary *gPasteboardState;
static __thread BOOL gPXInsidePasteboard;
static BOOL PXPublishPasteboardState(NSDictionary *basis, NSDictionary *candidate) {
    __attribute__((objc_precise_lifetime)) NSDictionary *retired = nil;BOOL published = NO;
    @try {
        os_unfair_lock_lock(&gPasteboardStateLock);
        @try { if (gPasteboardState == basis) { retired=gPasteboardState;gPasteboardState=candidate;published=YES; } }
        @finally { os_unfair_lock_unlock(&gPasteboardStateLock); }
        return published;
    } @finally { basis=nil;candidate=nil;retired=nil; }
}
static NSDictionary *PXCapturePasteboardState(void) {
    NSDictionary *state=nil,*initial=nil;
    @try { for (;;) {
        os_unfair_lock_lock(&gPasteboardStateLock);
        @try { state=gPasteboardState; } @finally { os_unfair_lock_unlock(&gPasteboardStateLock); }
        if (state) return state;
        initial=@{@"epoch":[NSObject new],@"entries":@{}};if (PXPublishPasteboardState(nil,initial)) return initial;initial=nil;
    }} @finally { state=nil;initial=nil; }
}
static void PXEnsurePasteboardState(void) { (void)PXCapturePasteboardState(); }
static NSNumber *PXUpdatePasteboardState(NSString *bundleID, NSInteger nativeCount, NSString *hash, BOOL increment, id epoch) {
    NSDictionary *basis=nil,*entry=nil,*candidate=nil;NSMutableDictionary *entries=nil,*working=nil,*next=nil;NSNumber *result=nil;
    @try { for (;;) {
        basis=PXCapturePasteboardState();if (basis[@"epoch"]!=epoch) return nil;
        entry=basis[@"entries"][bundleID];NSInteger count=entry[@"count"] ? [entry[@"count"] integerValue] : nativeCount;
        BOOL changed=hash && (!entry[@"hash"] || ![entry[@"hash"] isEqualToString:hash]);
        if (entry[@"count"] && !increment && !changed) return entry[@"count"];
        if ((increment || changed) && count<NSIntegerMax) count++;
        result=@(count);next=entry ? [entry mutableCopy] : [NSMutableDictionary dictionary];next[@"count"]=result;if (hash) next[@"hash"]=hash;
        entries=[basis[@"entries"] mutableCopy];entries[bundleID]=[next copy];working=[basis mutableCopy];working[@"entries"]=[entries copy];candidate=[working copy];
        if (PXPublishPasteboardState(basis,candidate)) return result;
        basis=nil;entry=nil;candidate=nil;entries=nil;working=nil;next=nil;result=nil;
    }} @finally { bundleID=nil;hash=nil;epoch=nil;basis=nil;entry=nil;candidate=nil;entries=nil;working=nil;next=nil;result=nil; }
}
static NSString *getCurrentBundleID(void);
static NSDictionary *loadScopedApps(void);
static BOOL isInScopedAppsList(void);
static NSString *getSpoofedPasteboardUUID(void);
static BOOL shouldSpoofForBundle(NSString *bundleID);
static NSString *deterministicPasteboardName(NSString *originalName, NSString *uuidString);
static void clearCacheCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    (void)center;(void)observer;(void)name;(void)object;(void)userInfo;
    NSDictionary *basis=nil,*candidate=nil;
    @try {
        candidate=@{@"epoch":[NSObject new],@"entries":@{}};
        do { basis=PXCapturePasteboardState(); } while (!PXPublishPasteboardState(basis,candidate));
        PXInvalidateScopeDecisionCache();
    } @catch (__unused NSException *exception) { }
    @finally { basis=nil;candidate=nil; }
}

#pragma mark - Scoped Apps Helper Functions

static NSString *getCurrentBundleID(void) {
    @try {
        NSBundle *mainBundle = [NSBundle mainBundle];
        if (!mainBundle) {
            return nil;
        }
        return [mainBundle bundleIdentifier];
    } @catch (NSException *e) {
        return nil;
    }
}

static NSDictionary *loadScopedApps(void) {
    PX_RUNTIME_READ_OPERATION;
    return PXScopedAppsSnapshot();
}

static BOOL isInScopedAppsList(void) {
    PX_RUNTIME_READ_OPERATION;
    @try {
        NSString *bundleID = getCurrentBundleID();
        if (!bundleID || [bundleID length] == 0) {
            return NO;
        }
        
        NSDictionary *scopedApps = loadScopedApps();
        if (!scopedApps || scopedApps.count == 0) {
            return NO;
        }
        
        id appEntry = scopedApps[bundleID];
        if (!appEntry || ![appEntry isKindOfClass:[NSDictionary class]]) {
            return NO;
        }
        
        return [appEntry[@"enabled"] boolValue];
        
    } @catch (NSException *e) {
        return NO;
    }
}

static BOOL shouldSpoofForBundle(NSString *bundleID) {
    PX_RUNTIME_READ_OPERATION;
    if (!bundleID) return NO;
    if (!PXProcessIsAllowedForSpoofing(bundleID, [NSProcessInfo processInfo].processName, PXScopeOptionAllowSafariAuthStack)) {
        return NO;
    }
    // Prefer IdentifierManager when available; fall back to scope-only if class missing
    Class imClass = NSClassFromString(@"IdentifierManager");
    if (imClass) {
        IdentifierManager *manager = [imClass sharedManager];
        if (manager && ![manager isIdentifierEnabled:@"PasteboardUUID"]) {
            return NO;
        }
    }
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    return getSpoofedPasteboardUUID().length > 0;
#else
    return YES;
#endif
}

static NSString *getSpoofedPasteboardUUID(void) {
    PX_RUNTIME_READ_OPERATION;
#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)
    PXRuntimeReadSnapshot *runtimeView = PXCaptureRuntimeSnapshot();
    NSDictionary *runtimeIDs = runtimeView.deviceIDs;
    NSString *runtimeUUID = [runtimeIDs[@"PasteboardUUID"] isKindOfClass:NSString.class]
        ? runtimeIDs[@"PasteboardUUID"] : nil;
    if (!runtimeUUID.length) {
        NSDictionary *runtimeArtifact = [runtimeView profileArtifact:@"pasteboardUUID"];
        runtimeUUID = [runtimeArtifact[@"value"] isKindOfClass:NSString.class]
            ? runtimeArtifact[@"value"] : nil;
    }
    if (runtimeUUID.length) return runtimeUUID;
    return nil;
#endif
    PasteboardUUIDManager *manager = [PasteboardUUIDManager sharedManager];
    NSString *uuid = [manager currentPasteboardUUID];
    
    if (uuid && uuid.length > 0) {
        return uuid;
    }
    
    uuid = [manager generatePasteboardUUID];
    if (uuid && uuid.length > 0) {
        return uuid;
    }
    
    NSString *identityDir = PXActiveProfileIdentityPath();
    NSString *deviceIdsPath = PXActiveProfileDeviceIDsPath();

    if (identityDir.length) {
        NSDictionary *deviceIds = deviceIdsPath.length ? [NSDictionary dictionaryWithContentsOfFile:deviceIdsPath] : nil;
        NSString *value = deviceIds[@"PasteboardUUID"];
        
        if (value) {
            PXLog(@"[WeaponX] 🔄 Got PasteboardUUID from device_ids.plist: %@", value);
            return value;
        }
        
        NSString *uuidPath = [identityDir stringByAppendingPathComponent:@"pasteboard_uuid.plist"];
        NSDictionary *uuidDict = [NSDictionary dictionaryWithContentsOfFile:uuidPath];
        if (uuidDict && uuidDict[@"value"]) {
            PXLog(@"[WeaponX] 🔄 Got PasteboardUUID from pasteboard_uuid.plist: %@", uuidDict[@"value"]);
            return uuidDict[@"value"];
        }
    }
    
    uuid = [[NSUUID UUID] UUIDString];
    PXLog(@"[WeaponX] 🔄 Generated fallback PasteboardUUID: %@", uuid);
    return uuid;
}

static NSString *getPasteboardContentHash(UIPasteboard *pasteboard) {
    NSMutableString *input=nil;NSArray *types=nil,*probe=nil;NSString *type=nil,*urlString=nil;id value=nil;UIImage *image=nil;NSData *data=nil;NSURL *url=nil;
    @try {
        input=[NSMutableString string];types=@[@"public.text",@"public.plain-text",@"public.utf8-plain-text"];
        for (NSUInteger i=0;i<types.count;i++) { type=types[i];probe=@[type];if ([pasteboard containsPasteboardTypes:probe]) { value=[pasteboard valueForPasteboardType:type];if ([value isKindOfClass:NSString.class]) [input appendString:value]; } }
        image=pasteboard.image;if (image) { data=UIImagePNGRepresentation(image);if (data) [input appendFormat:@"IMG:%lu",(unsigned long)data.hash]; }
        url=pasteboard.URL;if (url) { urlString=url.absoluteString;[input appendString:urlString]; }
        return [NSString stringWithFormat:@"%lu",(unsigned long)input.hash];
    } @catch (__unused NSException *exception) { return @"ERROR"; }
    @finally { pasteboard=nil;input=nil;types=nil;probe=nil;type=nil;urlString=nil;value=nil;image=nil;data=nil;url=nil; }
}

// Build deterministic custom pasteboard name from PasteboardUUID.
// General pasteboard name must never be rewritten by callers.
static NSString *deterministicPasteboardName(NSString *originalName, NSString *uuidString) {
    // Delegate to the shared, host-testable helper (P1-A, no drift with tests).
    return PXPasteboardDeterministicName(originalName, uuidString);
}

#pragma mark - Per-selector original IMPs

// Instance methods
static NSUUID *(*orig_uniquePasteboardUUID)(id, SEL) = NULL;
static NSString *(*orig_name)(id, SEL) = NULL;
static NSInteger (*orig_changeCount)(id, SEL) = NULL;
static void (*orig_setPersistent)(id, SEL, BOOL) = NULL;
static BOOL (*orig_isPersistent)(id, SEL) = NULL;
static id (*orig_valueForPasteboardType)(id, SEL, NSString *) = NULL;
static void (*orig_setDataForPasteboardType)(id, SEL, NSData *, NSString *) = NULL;
static void (*orig_setItems)(id, SEL, NSArray *) = NULL;

// Class methods
static UIPasteboard *(*orig_pasteboardWithNameCreate)(id, SEL, NSString *, BOOL) = NULL;
static UIPasteboard *(*orig_pasteboardWithURLCreate)(id, SEL, NSURL *, BOOL) = NULL;

#pragma mark - Hook implementations

static NSUUID *hook_uniquePasteboardUUID(id self, SEL _cmd) {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver=self;NSString *bundleID=nil,*uuidString=nil;NSUUID *projected=nil;BOOL previous=gPXInsidePasteboard;
    @try {
        if (previous) return orig_uniquePasteboardUUID ? orig_uniquePasteboardUUID(receiver,_cmd) : nil;
        gPXInsidePasteboard=YES;
        @try { bundleID=getCurrentBundleID();if (shouldSpoofForBundle(bundleID)) { uuidString=getSpoofedPasteboardUUID();projected=[[NSUUID alloc] initWithUUIDString:uuidString]; } } @catch (__unused NSException *exception) { }
        if (projected) return projected;
        return orig_uniquePasteboardUUID ? orig_uniquePasteboardUUID(receiver,_cmd) : nil;
    } @finally { receiver=nil;bundleID=nil;uuidString=nil;projected=nil;gPXInsidePasteboard=previous; }
}

static NSString *hook_name(id self, SEL _cmd) {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver=self;
    BOOL previous=gPXInsidePasteboard;NSString *bundleID=nil,*uuidString=nil;NSString *projected=nil;
    NSString *original=nil,*result=original;
    @try {
        if (previous) return orig_name ? orig_name(receiver, _cmd) : nil;
        gPXInsidePasteboard=YES;
        original=orig_name ? orig_name(receiver, _cmd) : nil;result=original;
        @try { bundleID=getCurrentBundleID();if (shouldSpoofForBundle(bundleID) && [original isKindOfClass:NSString.class] && ![original isEqualToString:@"com.apple.UIKit.pboard.general"]) { uuidString=getSpoofedPasteboardUUID();projected=deterministicPasteboardName(original,uuidString);if (projected) result=projected; } } @catch (__unused NSException *exception) { result=original; }
        return result;
    } @finally { receiver=nil;bundleID=nil;uuidString=nil;gPXInsidePasteboard=previous;original=nil;result=nil; projected=nil; }
}

static UIPasteboard *hook_pasteboardWithNameCreate(id self, SEL _cmd, NSString *pasteboardName, BOOL create) {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver=self;
    BOOL previous=gPXInsidePasteboard;NSString *bundleID=nil,*uuidString=nil;NSString *effective=pasteboardName,*projected=nil;
    UIPasteboard *original=nil,*result=original;
    @try {
        if (previous) return orig_pasteboardWithNameCreate ? orig_pasteboardWithNameCreate(receiver, _cmd, effective, create) : nil;
        gPXInsidePasteboard=YES;
        @try { bundleID=getCurrentBundleID();if (shouldSpoofForBundle(bundleID) && [pasteboardName isKindOfClass:NSString.class] && pasteboardName.length && ![pasteboardName isEqualToString:@"com.apple.UIKit.pboard.general"]) { uuidString=getSpoofedPasteboardUUID();projected=deterministicPasteboardName(pasteboardName,uuidString);if (projected.length) effective=projected; } } @catch (__unused NSException *exception) { }
        result=orig_pasteboardWithNameCreate ? orig_pasteboardWithNameCreate(receiver, _cmd, effective, create) : nil;
        return result;
    } @finally { receiver=nil;bundleID=nil;uuidString=nil;gPXInsidePasteboard=previous;original=nil;result=nil; pasteboardName=nil;effective=nil;projected=nil; }
}

static UIPasteboard *hook_pasteboardWithURLCreate(id self, SEL _cmd, NSURL *url, BOOL create) {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver=self;
    BOOL previous=gPXInsidePasteboard;NSString *bundleID=nil,*uuidString=nil;NSURL *effective=url,*projected=nil;NSString *text=nil,*shortID=nil;NSArray *parts=nil;
    UIPasteboard *original=nil,*result=original;
    @try {
        if (previous) return orig_pasteboardWithURLCreate ? orig_pasteboardWithURLCreate(receiver, _cmd, effective, create) : nil;
        gPXInsidePasteboard=YES;
        @try { bundleID=getCurrentBundleID();if (shouldSpoofForBundle(bundleID) && url) { uuidString=getSpoofedPasteboardUUID();parts=[uuidString componentsSeparatedByString:@"-"];shortID=parts.firstObject;text=url.absoluteString;projected=[NSURL URLWithString:[NSString stringWithFormat:[text containsString:@"?"] ? @"%@&uuid=%@" : @"%@?uuid=%@",text,shortID]];if (projected) effective=projected; } } @catch (__unused NSException *exception) { }
        result=orig_pasteboardWithURLCreate ? orig_pasteboardWithURLCreate(receiver, _cmd, effective, create) : nil;
        return result;
    } @finally { receiver=nil;bundleID=nil;uuidString=nil;gPXInsidePasteboard=previous;original=nil;result=nil; url=nil;effective=nil;projected=nil;text=nil;shortID=nil;parts=nil; }
}

static NSInteger hook_changeCount(id self, SEL _cmd) {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver=self;
    BOOL previous=gPXInsidePasteboard;NSString *bundleID=nil,*uuidString=nil;NSDictionary *ticket=nil;NSString *hash=nil;NSNumber *count=nil;
    NSInteger original=0,result=original;
    @try {
        if (previous) return orig_changeCount ? orig_changeCount(receiver, _cmd) : 0;
        gPXInsidePasteboard=YES;
        original=orig_changeCount ? orig_changeCount(receiver, _cmd) : 0;result=original;
        @try { bundleID=getCurrentBundleID();if (shouldSpoofForBundle(bundleID)) { ticket=PXCapturePasteboardState();hash=getPasteboardContentHash((UIPasteboard *)receiver);count=PXUpdatePasteboardState(bundleID,original,hash,NO,ticket[@"epoch"]);if (count) result=count.integerValue; } } @catch (__unused NSException *exception) { result=original; }
        return result;
    } @finally { receiver=nil;bundleID=nil;uuidString=nil;gPXInsidePasteboard=previous; ticket=nil;hash=nil;count=nil; }
}

static void hook_setPersistent(id self, SEL _cmd, BOOL persistent) {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver=self;
    BOOL previous=gPXInsidePasteboard;NSString *bundleID=nil,*uuidString=nil;BOOL effective=persistent;
    @try {
        if (previous) { if (orig_setPersistent) orig_setPersistent(receiver,_cmd, effective);return; }
        gPXInsidePasteboard=YES;
        @try { bundleID=getCurrentBundleID();if (shouldSpoofForBundle(bundleID)) effective=YES; } @catch (__unused NSException *exception) { }
        if (orig_setPersistent) { orig_setPersistent(receiver,_cmd, effective); }
    } @finally { receiver=nil;bundleID=nil;uuidString=nil;gPXInsidePasteboard=previous;  }
}

static BOOL hook_isPersistent(id self, SEL _cmd) {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver=self;
    BOOL previous=gPXInsidePasteboard;NSString *bundleID=nil,*uuidString=nil;
    BOOL original=NO,result=original;
    @try {
        if (previous) return orig_isPersistent ? orig_isPersistent(receiver, _cmd) : NO;
        gPXInsidePasteboard=YES;
        original=orig_isPersistent ? orig_isPersistent(receiver, _cmd) : NO;result=original;
        @try { bundleID=getCurrentBundleID();if (shouldSpoofForBundle(bundleID)) result=YES; } @catch (__unused NSException *exception) { result=original; }
        return result;
    } @finally { receiver=nil;bundleID=nil;uuidString=nil;gPXInsidePasteboard=previous;  }
}

static id hook_valueForPasteboardType(id self, SEL _cmd, NSString *pasteboardType) {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver=self;
    BOOL previous=gPXInsidePasteboard;NSString *bundleID=nil,*uuidString=nil;NSUUID *uuid=nil;NSData *data=nil;NSError *__autoreleasing error=nil;
    id original=nil,result=original;
    @try {
        if (previous) return orig_valueForPasteboardType ? orig_valueForPasteboardType(receiver, _cmd, pasteboardType) : nil;
        gPXInsidePasteboard=YES;
        original=orig_valueForPasteboardType ? orig_valueForPasteboardType(receiver, _cmd, pasteboardType) : nil;result=original;
        @try { if ([pasteboardType isEqualToString:@"com.apple.uikit.pboard-uuid"]) { bundleID=getCurrentBundleID();if (shouldSpoofForBundle(bundleID)) { uuidString=getSpoofedPasteboardUUID();uuid=[[NSUUID alloc] initWithUUIDString:uuidString];if (uuid) { data=[NSKeyedArchiver archivedDataWithRootObject:uuid requiringSecureCoding:NO error:&error];if (data) result=data; } } } } @catch (__unused NSException *exception) { result=original; }
        return result;
    } @finally { receiver=nil;bundleID=nil;uuidString=nil;gPXInsidePasteboard=previous;original=nil;result=nil; pasteboardType=nil;uuid=nil;data=nil; }
}

static void hook_setDataForPasteboardType(id self, SEL _cmd, NSData *data, NSString *pasteboardType) {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver=self;
    BOOL previous=gPXInsidePasteboard;NSString *bundleID=nil,*uuidString=nil;NSDictionary *ticket=nil;BOOL enabled=NO;
    @try {
        if (previous) { if (orig_setDataForPasteboardType) orig_setDataForPasteboardType(receiver,_cmd, data, pasteboardType);return; }
        gPXInsidePasteboard=YES;
        @try { ticket=PXCapturePasteboardState();bundleID=getCurrentBundleID();enabled=shouldSpoofForBundle(bundleID); } @catch (__unused NSException *exception) { }
        if (orig_setDataForPasteboardType) { orig_setDataForPasteboardType(receiver,_cmd, data, pasteboardType); @try { if (enabled) (void)PXUpdatePasteboardState(bundleID,0,nil,YES,ticket[@"epoch"]); } @catch (__unused NSException *exception) { } }
    } @finally { receiver=nil;bundleID=nil;uuidString=nil;gPXInsidePasteboard=previous; data=nil;pasteboardType=nil;ticket=nil; }
}

static void hook_setItems(id self, SEL _cmd, NSArray *items) {
    PX_RUNTIME_READ_OPERATION;
    __attribute__((objc_precise_lifetime)) id receiver=self;
    BOOL previous=gPXInsidePasteboard;NSString *bundleID=nil,*uuidString=nil;NSDictionary *ticket=nil;BOOL enabled=NO;
    @try {
        if (previous) { if (orig_setItems) orig_setItems(receiver,_cmd, items);return; }
        gPXInsidePasteboard=YES;
        @try { ticket=PXCapturePasteboardState();bundleID=getCurrentBundleID();enabled=shouldSpoofForBundle(bundleID); } @catch (__unused NSException *exception) { }
        if (orig_setItems) { orig_setItems(receiver,_cmd, items); @try { if (enabled) (void)PXUpdatePasteboardState(bundleID,0,nil,YES,ticket[@"epoch"]); } @catch (__unused NSException *exception) { } }
    } @finally { receiver=nil;bundleID=nil;uuidString=nil;gPXInsidePasteboard=previous; items=nil;ticket=nil; }
}

#pragma mark - Runtime installer

// Log unsupported-selector once, then continue.
static void logUnsupportedSelectorOnce(NSString *selectorName) {
    if (PXLogOnceClaim(@"PasteboardHooks.unsupportedSelector", selectorName)) {
        PXLog(@"[PasteboardHooks] unsupported-selector: %@", selectorName);
    }
}

// Validate every argument and return ABI; accept qualified objects and byte BOOLs.
// Does not add selectors that don't exist.
static const char *PXUnqualifiedPasteboardType(const char *type) {
    while (type && *type && strchr("rnNoORV",*type)) type++;
    return type;
}
static BOOL PXPasteboardABIType(const char *actual, const char *expected) {
    actual=PXUnqualifiedPasteboardType(actual);expected=PXUnqualifiedPasteboardType(expected);
    if (!actual || !expected) return NO;
    if (*expected=='@') return *actual=='@' && actual[1]!='?';
    if (*expected=='B') return (*actual=='B' || *actual=='c') && !actual[1];
    return strcmp(actual,expected)==0;
}
static BOOL typeEncodingCompatible(const char *existing, const char *expected) {
    NSMethodSignature *actual=nil,*wanted=nil;
    @try {
        if (!existing || !expected) return NO;
        actual=[NSMethodSignature signatureWithObjCTypes:existing];wanted=[NSMethodSignature signatureWithObjCTypes:expected];
        if (!actual || !wanted || actual.numberOfArguments!=wanted.numberOfArguments || !PXPasteboardABIType(actual.methodReturnType,wanted.methodReturnType)) return NO;
        for (NSUInteger i=0;i<actual.numberOfArguments;i++) if (!PXPasteboardABIType([actual getArgumentTypeAtIndex:i],[wanted getArgumentTypeAtIndex:i])) return NO;
        return YES;
    } @catch (__unused NSException *exception) { return NO; }
    @finally { actual=nil;wanted=nil; }
}

// Install instance method hook if method exists and encoding is compatible.
// Stores original IMP in *outOrig. Never class_addMethod for missing selectors.
static BOOL installInstanceHook(Class cls, SEL sel, IMP replacement, IMP *outOrig, const char *expectedEncoding, NSString *label) {
    if (!cls || !sel || !replacement || !outOrig) return NO;
    
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) {
        logUnsupportedSelectorOnce(label ?: NSStringFromSelector(sel));
        return NO;
    }
    
    const char *encoding = method_getTypeEncoding(method);
    if (expectedEncoding && !typeEncodingCompatible(encoding, expectedEncoding)) {
        PXLog(@"[PasteboardHooks] type encoding mismatch for %@ (have=%s expected=%s)",
              label ?: NSStringFromSelector(sel), encoding ? encoding : "(null)", expectedEncoding);
        logUnsupportedSelectorOnce([NSString stringWithFormat:@"%@ (encoding)", label ?: NSStringFromSelector(sel)]);
        return NO;
    }
    
    MSHookMessageEx(cls, sel, replacement, outOrig);
    return (*outOrig != NULL);
}

// Install class method hook if method exists and encoding is compatible.
static BOOL installClassHook(Class cls, SEL sel, IMP replacement, IMP *outOrig, const char *expectedEncoding, NSString *label) {
    if (!cls || !sel || !replacement || !outOrig) return NO;
    
    Method method = class_getClassMethod(cls, sel);
    if (!method) {
        logUnsupportedSelectorOnce(label ?: NSStringFromSelector(sel));
        return NO;
    }
    
    const char *encoding = method_getTypeEncoding(method);
    if (expectedEncoding && !typeEncodingCompatible(encoding, expectedEncoding)) {
        PXLog(@"[PasteboardHooks] type encoding mismatch for +%@ (have=%s expected=%s)",
              label ?: NSStringFromSelector(sel), encoding ? encoding : "(null)", expectedEncoding);
        logUnsupportedSelectorOnce([NSString stringWithFormat:@"+%@ (encoding)", label ?: NSStringFromSelector(sel)]);
        return NO;
    }
    
    // Class methods live on the metaclass
    Class meta = object_getClass(cls);
    if (!meta) {
        logUnsupportedSelectorOnce(label ?: NSStringFromSelector(sel));
        return NO;
    }
    
    MSHookMessageEx(meta, sel, replacement, outOrig);
    return (*outOrig != NULL);
}

static void installPasteboardHooks(void) {
    Class pasteboardClass = objc_getClass("UIPasteboard");
    if (!pasteboardClass) {
        PXLog(@"[PasteboardHooks] unsupported-selector: UIPasteboard class missing");
        return;
    }
    
    // Public / commonly available paths
    
    installClassHook(pasteboardClass,
                     @selector(pasteboardWithName:create:),
                     (IMP)hook_pasteboardWithNameCreate,
                     (IMP *)&orig_pasteboardWithNameCreate,
                     "@@:@B",
                     @"+pasteboardWithName:create:");
    
    
    installInstanceHook(pasteboardClass,
                        @selector(name),
                        (IMP)hook_name,
                        (IMP *)&orig_name,
                        "@@:",
                        @"-name");
    
    installInstanceHook(pasteboardClass,
                        @selector(changeCount),
                        (IMP)hook_changeCount,
                        (IMP *)&orig_changeCount,
                        sizeof(NSInteger)==8 ? "q@:" : "i@:",
                        @"-changeCount");
    
    
    installInstanceHook(pasteboardClass,
                        @selector(valueForPasteboardType:),
                        (IMP)hook_valueForPasteboardType,
                        (IMP *)&orig_valueForPasteboardType,
                        "@@:@",
                        @"-valueForPasteboardType:");
    
    installInstanceHook(pasteboardClass,
                        @selector(setData:forPasteboardType:),
                        (IMP)hook_setDataForPasteboardType,
                        (IMP *)&orig_setDataForPasteboardType,
                        "v@:@@",
                        @"-setData:forPasteboardType:");
    
    installInstanceHook(pasteboardClass,
                        @selector(setItems:),
                        (IMP)hook_setItems,
                        (IMP *)&orig_setItems,
                        "v@:@",
                        @"-setItems:");
    
    // Optional / private / version-dependent selectors — install only if present
    // uniquePasteboardUUID is not guaranteed on all runtimes
    installInstanceHook(pasteboardClass,
                        @selector(uniquePasteboardUUID),
                        (IMP)hook_uniquePasteboardUUID,
                        (IMP *)&orig_uniquePasteboardUUID,
                        "@@:",
                        @"-uniquePasteboardUUID");
    
    // pasteboardWithURL:create: is not available on all iOS versions
    SEL urlSel = NSSelectorFromString(@"pasteboardWithURL:create:");
    installClassHook(pasteboardClass,
                     urlSel,
                     (IMP)hook_pasteboardWithURLCreate,
                     (IMP *)&orig_pasteboardWithURLCreate,
                     "@@:@B",
                     @"+pasteboardWithURL:create:");
    
    installInstanceHook(pasteboardClass,
                        @selector(setPersistent:),
                        (IMP)hook_setPersistent,
                        (IMP *)&orig_setPersistent,
                        "v@:B",
                        @"-setPersistent:");
    
    installInstanceHook(pasteboardClass,
                        @selector(isPersistent),
                        (IMP)hook_isPersistent,
                        (IMP *)&orig_isPersistent,
                        "B@:",
                        @"-isPersistent");
    
    
    
    PXLog(@"[PasteboardHooks] Runtime installer finished");
}

#pragma mark - Constructor

%ctor {
    @autoreleasepool {
        if (!PXBootstrapAllows(PXHookCapabilityNative)) return;
        // Skip for system processes
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSString *proc = [NSProcessInfo processInfo].processName;
        if (PXIsWebKitHelperProcess(bundleID, proc)) {
            return;
        }
        if (!bundleID || !PXProcessIsAllowedForSpoofing(bundleID, proc, PXScopeOptionAllowSafariAuthStack)) {
            return;
        }
        
        PXEnsurePasteboardState();
        
        // Register for settings change notifications
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            clearCacheCallback,
            CFSTR("com.hydra.tlinkios.settings.changed"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        
        // Register for profile change notifications
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            clearCacheCallback,
            CFSTR("com.hydra.tlinkios.profileChanged"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            clearCacheCallback,
            CFSTR("com.hydra.tlinkios.scopedAppsChanged"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
        
        // Install only selectors that exist; never blind %init of optional private APIs
        installPasteboardHooks();
        
        PXLog(@"[WeaponX] 📋 Initialized PasteboardHooks for %@", bundleID);
    }
}
