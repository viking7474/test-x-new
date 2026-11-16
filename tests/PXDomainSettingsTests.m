#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdio.h>
static NSString *root;
static NSFileManager *PXFixtureFiles(void);
static NSString *PXFixturePath(NSUInteger index) { return [root stringByAppendingPathComponent:index == 1 ? @"alternate.plist" : @"primary.plist"]; }
#include "PXDomainSettings.inc"
static NSUInteger checks, failures;
static BOOL deniedMetadata, throwMetadata, singletonReentry, singletonDeclined;
#define CHECK(value,label) do { checks++;if (!(value)) { failures++;fprintf(stderr,"FAIL: %s\n",label); } } while (0)
static void Raise(void) { [NSException raise:@"fixture" format:@"domain settings fault"]; }
@interface PXDomainFiles : NSObject
- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)fileExistsAtPath:(NSString *)path;
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)intermediate attributes:(NSDictionary *)attributes error:(NSError **)error;
@end
@implementation PXDomainFiles
- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error {
    @try { if (singletonReentry) singletonDeclined = [DomainBlockingSettings sharedSettings] == nil;if (throwMetadata) Raise();if (deniedMetadata) { if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoPermissionError userInfo:nil];return nil; }return [[NSFileManager defaultManager] attributesOfItemAtPath:path error:error]; }
    @finally { path = nil; }
}
- (BOOL)fileExistsAtPath:(NSString *)path { @try { return [[NSFileManager defaultManager] fileExistsAtPath:path]; } @finally { path = nil; } }
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)intermediate attributes:(NSDictionary *)attributes error:(NSError **)error {
    @try { return [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:intermediate attributes:attributes error:error]; }
    @finally { path = nil;attributes = nil; }
}
@end
static NSFileManager *PXFixtureFiles(void) { static PXDomainFiles *files;static dispatch_once_t once;dispatch_once(&once,^{files=[PXDomainFiles new];});return (id)files; }
@interface PXControlledDomains : DomainBlockingSettings
@property (nonatomic) BOOL failWrite;
@property (nonatomic) BOOL throwWrite;
@property (nonatomic) NSUInteger writes;
@property (nonatomic, copy) dispatch_block_t beforeWrite;
@end
@implementation PXControlledDomains
- (BOOL)writePolicy:(PXDomainPolicy *)policy {
    dispatch_block_t callback = nil;
    @try { self.writes++;callback = self.beforeWrite;if (callback) callback();if (self.throwWrite) Raise();return self.failWrite ? NO : [super writePolicy:policy]; }
    @finally { policy = nil;callback = nil; }
}
@end
static void ResetFiles(void) { [[NSFileManager defaultManager] removeItemAtPath:PXFixturePath(0) error:NULL];[[NSFileManager defaultManager] removeItemAtPath:PXFixturePath(1) error:NULL]; }
static void Seed(NSDictionary *settings) { @try { CHECK([settings writeToFile:PXFixturePath(0) atomically:YES],"fixture source seeded"); } @finally { settings = nil; } }
static NSData *Bytes(void) { return [NSData dataWithContentsOfFile:PXFixturePath(0)]; }
// Reference matcher from 286db57; exact/subdomain semantics are the oracle.
static BOOL Legacy(BOOL enabled,NSArray *rules,NSString *domain) {
    if (!domain || !domain.length || !enabled) return NO;
    NSString *lower = domain.lowercaseString;if ([lower hasSuffix:@"."]) lower = [lower substringToIndex:lower.length-1];
    for (NSString *rule in rules) { NSString *b = rule.lowercaseString;if ([b hasSuffix:@"."]) b = [b substringToIndex:b.length-1];if ([lower isEqualToString:b] || [lower hasSuffix:[@"." stringByAppendingString:b]]) return YES; }
    return NO;
}
static void Matcher(void) {
    DomainBlockingSettings *settings = [DomainBlockingSettings new];
    NSArray *rules = @[@"Example.COM",@"example.com.",@"com",@".",@"..",@".odd",@"a..b",@"é.test",@"e\u0301.test",@" localhost ",@"http://x",@"192.0.2.1"];
    NSArray *hosts = @[@"",@"example.com",@"WWW.EXAMPLE.COM.",@"badexample.com",@"a.example.com..",@"a.example.com.",@".",@"..",@"odd",@"x..odd",@"a..b",@"x.a..b",@"é.test",@"x.e\u0301.test",@"x.é.test",@" localhost ",@"localhost",@"http://x",@"x.192.0.2.1",@"192.0.2.1",@"com",@"x.comx"];
    for (NSString *rule in rules) {
        settings.blockedDomains = [@[rule] mutableCopy];
        for (NSString *host in hosts) CHECK([settings isDomainBlocked:host] == Legacy(YES,@[rule],host),"compiled matcher preserves the legacy case/dot/boundary/Unicode policy");
    }
    settings.blockedDomains = [rules mutableCopy];
    for (NSString *host in hosts) CHECK([settings isDomainBlocked:host] == Legacy(YES,rules,host),"combined matcher preserves legacy alternatives");
    settings.isEnabled = NO;CHECK(![settings isDomainBlocked:@"example.com"],"disabled packet skips matching");settings.isEnabled = YES;
    NSMutableString *input = [@"frozen.test" mutableCopy];NSMutableArray *domains = [NSMutableArray arrayWithObject:input];settings.blockedDomains = domains;
    [input setString:@"changed.test"];[domains removeAllObjects];[[settings blockedDomains] removeAllObjects];
    CHECK(([settings isDomainBlocked:@"frozen.test"] && ![settings isDomainBlocked:@"changed.test"]),"setter detaches input and getter never exposes a mutable policy alias");
    CHECK((![settings isDomainBlocked:nil] && ![settings isDomainBlocked:(id)@[]]),"invalid query is contained");
}
static void Load(void) {
    ResetFiles();PXControlledDomains *settings = [PXControlledDomains new];
    CHECK(([settings loadSettings] && [settings isDomainBlocked:@"devicecheck.apple.com"] && [settings isDomainBlocked:@"appattest.apple.com"]),"first run preserves and persists both default domains");
    Seed(@{@"isEnabled":@NO,@"customDomains":@{@"Raw.TEST.":@"YES",@"off.test":@NO},@"blockedDomains":@[@"ignored.test"]});
    CHECK(([settings loadSettings] && !settings.isEnabled && [settings isCustomDomainEnabled:@"Raw.TEST."] && ![settings isCustomDomain:@"ignored.test"]),"custom dictionary and global false take precedence");
    settings.isEnabled = YES;CHECK(([settings isDomainBlocked:@"x.raw.test"] && ![settings isDomainBlocked:@"off.test"]),"load compiles enabled raw keys and keeps false entries");
    for (id invalid in @[@[@"invalid-root"],@{@"isEnabled":@[]},@{@"customDomains":@[]},@{@"customDomains":@{@"bad.test":@[]}}]) {
        CHECK([invalid writeToFile:PXFixturePath(0) atomically:YES],"malformed source seeded");PXDomainPolicy *before = [settings capturedPolicy];NSData *bytes = Bytes();
        CHECK((![settings loadSettings] && [settings capturedPolicy] == before && [Bytes() isEqual:bytes]),"malformed load preserves complete old packet and source bytes");
    }
    [@"not a plist" writeToFile:PXFixturePath(0) atomically:YES encoding:NSUTF8StringEncoding error:NULL];NSData *bad = Bytes();
    CHECK((![settings loadSettings] && [Bytes() isEqual:bad]),"corrupt present source is never overwritten as defaults");
    deniedMetadata = YES;CHECK((![settings loadSettings] && [Bytes() isEqual:bad]),"unreadable metadata does not permit first-run overwrite");deniedMetadata = NO;
    Seed(@{@"blockedDomains":@[@"legacy.test",@42,@""],@"isEnabled":@YES});
    PXDomainPolicy *before = [settings capturedPolicy];NSData *bytes = Bytes();settings.failWrite = YES;
    CHECK((![settings loadSettings] && [settings capturedPolicy] == before && [Bytes() isEqual:bytes]),"failed legacy migration publishes no partial state");
    settings.failWrite = NO;CHECK(([settings loadSettings] && [settings isDomainBlocked:@"legacy.test"] && [NSDictionary dictionaryWithContentsOfFile:PXFixturePath(0)][@"customDomains"] != nil),"legacy migration merges prior defaults/statuses and saves before adoption");
    Seed(@{@"customDomains":@{}});CHECK(([settings loadSettings] && settings.isEnabled && !settings.blockedDomains.count),"empty custom map replaces prior defaults; absent master means enabled");
    ResetFiles();CHECK(([@{@"isEnabled":@NO,@"customDomains":@{}} writeToFile:PXFixturePath(1) atomically:YES]),"alternate seeded");
    CHECK(([settings loadSettings] && !settings.isEnabled && ![[NSFileManager defaultManager] fileExistsAtPath:PXFixturePath(0)]),"existing alternate path is read without creating primary");
    ResetFiles();throwMetadata = YES;before = [settings capturedPolicy];CHECK((![settings loadSettings] && [settings capturedPolicy] == before),"metadata exception leaves policy usable");throwMetadata = NO;
}
static void Mutations(void) {
    ResetFiles();PXControlledDomains *settings = [PXControlledDomains new];CHECK([settings saveSettings],"mutation baseline persisted");
    CHECK([settings addDomain:@"a.test"],"add persists and publishes");NSUInteger writes = settings.writes;
    CHECK(([settings addDomain:@"a.test"] && [settings removeDomain:@"missing.test"] && settings.writes == writes),"existing enabled/absent disable no-ops do not write");
    CHECK((![settings setCustomDomainEnabled:@"absent" enabled:YES] && ![settings removeCustomDomain:@"absent"] && ![settings replaceCustomDomain:@"a.test" withDomain:@"devicecheck.apple.com"]),"invalid edits preserve old missing/duplicate results");
    for (NSUInteger op = 0; op < 6; op++) for (NSUInteger throwing = 0; throwing < 2; throwing++) {
        PXDomainPolicy *before = [settings capturedPolicy];NSData *bytes = Bytes();settings.failWrite = !throwing;settings.throwWrite = throwing;
        BOOL result = NO;
        switch (op) {
            case 0: result=[settings addDomain:@"pending.test"];break;
            case 1: result=[settings removeDomain:@"a.test"];break;
            case 2: result=[settings setCustomDomainEnabled:@"a.test" enabled:NO];break;
            case 3: result=[settings removeCustomDomain:@"a.test"];break;
            case 4: result=[settings replaceCustomDomain:@"a.test" withDomain:@"new.test"];break;
            case 5: result=[settings setEnabledAndSave:NO];break;
        }
        CHECK((!result && [settings capturedPolicy] == before && [Bytes() isEqual:bytes] && [settings isDomainBlocked:@"a.test"]),"every failed/throwing edit retains packet and disk without transient adoption");
        settings.failWrite = settings.throwWrite = NO;
    }
    CHECK(([settings removeDomain:@"a.test"] && [settings isCustomDomain:@"a.test"] && ![settings isDomainBlocked:@"a.test"]),"removeDomain disables without deleting");
    CHECK(([settings replaceCustomDomain:@"a.test" withDomain:@"b.test"] && ![settings isCustomDomainEnabled:@"b.test"] && [settings setCustomDomainEnabled:@"b.test" enabled:YES]),"replace preserves false and explicit toggle enables");
    CHECK(([settings removeCustomDomain:@"b.test"] && ![settings isCustomDomain:@"b.test"]),"custom remove deletes entry");
    CHECK(([settings setEnabledAndSave:NO] && ![settings isDomainBlocked:@"devicecheck.apple.com"] && ![[NSDictionary dictionaryWithContentsOfFile:PXFixturePath(0)][@"isEnabled"] boolValue]),"master commit adopts false only after disk success");
}
static void ConcurrentReaders(void) {
    ResetFiles();PXControlledDomains *settings = [PXControlledDomains new];CHECK([settings saveSettings],"concurrent baseline persisted");
    __weak PXControlledDomains *weakSettings = settings;
    settings.beforeWrite = ^{
        PXControlledDomains *owner = weakSettings;
        CHECK((![owner addDomain:@"nested.test"] && ![owner loadSettings] && ![owner saveSettings]),"same-thread nested writers are rejected before effects");
        owner.isEnabled = NO;CHECK(owner.isEnabled,"compatibility setter cannot interleave with pending save");
        dispatch_semaphore_t done = dispatch_semaphore_create(0);__block atomic_bool old;atomic_init(&old,false);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ @autoreleasepool { atomic_store(&old,[owner isDomainBlocked:@"devicecheck.apple.com"] && ![owner isDomainBlocked:@"pending.test"]);dispatch_semaphore_signal(done); } });
        CHECK((dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC)) == 0 && atomic_load(&old)),"network reader finishes with old packet while writer monitor holds I/O admission");
        owner = nil;
    };
    CHECK([settings addDomain:@"pending.test"],"outer write commits after independent reader");settings.beforeWrite = nil;
    CHECK([settings isDomainBlocked:@"pending.test"],"next reader observes committed matcher");
    dispatch_group_t group = dispatch_group_create();__block atomic_uint wrong;atomic_init(&wrong,0);
    for (NSUInteger i = 0; i < 24; i++) dispatch_group_async(group,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ @autoreleasepool {
        for (NSUInteger j = 0; j < 64; j++) if (![settings isDomainBlocked:@"devicecheck.apple.com"] || [settings isDomainBlocked:@"not-devicecheck.apple.com"]) atomic_fetch_add(&wrong,1);
    }});
    for (NSUInteger i = 0; i < 8; i++) dispatch_group_async(group,dispatch_get_global_queue(QOS_CLASS_DEFAULT,0),^{ @autoreleasepool {
        if (![settings addDomain:[NSString stringWithFormat:@"writer-%lu.test",(unsigned long)i]]) atomic_fetch_add(&wrong,1);
    }});
    CHECK((dispatch_group_wait(group,dispatch_time(DISPATCH_TIME_NOW,15*NSEC_PER_SEC)) == 0 && !atomic_load(&wrong)),"concurrent readers never see torn enabled/rule packets");
    for (NSUInteger i = 0; i < 8; i++) CHECK(([settings isCustomDomain:[NSString stringWithFormat:@"writer-%lu.test",(unsigned long)i]]),"concurrent writers preserve every committed independent edit");
}
@interface PXDomainBadInput : NSObject
@property (nonatomic,strong) DomainBlockingSettings *settings;
@property (nonatomic,strong) NSObject *token;
@property (nonatomic) BOOL throwing;
@property (nonatomic) BOOL nestedAccepted;
@property (nonatomic) BOOL writer;
@end
@implementation PXDomainBadInput
- (BOOL)isKindOfClass:(Class)type { (void)type;self.nestedAccepted=self.writer ? [self.settings addDomain:@"must-not-persist.test"] : [self.settings isDomainBlocked:@"devicecheck.apple.com"];if (self.throwing) Raise();return NO; }
@end
static void Lifetime(void) {
    DomainBlockingSettings *settings = [DomainBlockingSettings new];
    for (NSUInteger mode = 0; mode < 4; mode++) {
        __weak id weakInput, weakToken;
        @autoreleasepool {
            PXDomainBadInput *input = [PXDomainBadInput new];NSObject *token = [NSObject new];input.settings = settings;input.token = token;input.throwing = mode % 2;input.writer = mode >= 2;weakInput=input;weakToken=token;
            BOOL accepted = input.writer ? [settings addDomain:(id)input] : [settings isDomainBlocked:(id)input];
            CHECK((!accepted && !input.nestedAccepted),"foreign query/writer reentry and faults are contained before recursive effects");input = nil;token = nil;
        }
        CHECK((!weakInput && !weakToken && [settings isDomainBlocked:@"devicecheck.apple.com"]),"query fault releases owner graph and restores matcher admission after pool drain");
    }
    __weak id weakPacket;DomainBlockingSettings *replacementOwner = nil;
    @autoreleasepool { replacementOwner=[DomainBlockingSettings new];PXDomainPolicy *packet=[replacementOwner capturedPolicy];weakPacket=packet;replacementOwner.isEnabled=NO;packet=nil; }
    CHECK(!weakPacket,"replaced packet is released after capture owner and pool drain");
    replacementOwner = nil;
    ResetFiles();singletonReentry = YES;DomainBlockingSettings *singleton = [DomainBlockingSettings sharedSettings];singletonReentry = NO;
    CHECK((singleton && singletonDeclined && singleton == [DomainBlockingSettings sharedSettings]),"same-thread singleton reentry declines before waiting on its own once token");
}
int main(void) {
    @autoreleasepool {
        root=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"px-domain-settings-" stringByAppendingString:NSUUID.UUID.UUIDString]];
        CHECK([[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:NO attributes:nil error:NULL],"isolated fixture directory created");
        @try { Matcher();Load();Mutations();ConcurrentReaders();Lifetime(); }
        @finally { [[NSFileManager defaultManager] removeItemAtPath:root error:NULL];root=nil; }
    }
    fprintf(stdout,"Domain settings: %lu/%lu checks passed\n",(unsigned long)(checks-failures),(unsigned long)checks);return failures ? 1 : 0;
}
