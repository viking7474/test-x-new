#import <Foundation/Foundation.h>
#include <stdio.h>
static NSString *root, *suite;
static NSUserDefaults *fixtureDefaults;
static NSUInteger checks, failures;
#define CHECK(value, label) do { checks++;if (!(value)) { failures++;fprintf(stderr,"FAIL: %s\n",label); } } while (0)
NSString *PXTLinkIOSSettingsPath(void) { return [root stringByAppendingPathComponent:@"settings.plist"]; }
NSString *PXSecuritySettingsPath(void) { return [root stringByAppendingPathComponent:@"security.plist"]; }
NSString *PXPreferencesPath(void) { return root; }
static NSUserDefaults *PXFixtureSecurityDefaults(void) { return fixtureDefaults; }
#include "PXThemeEnablementWork.inc"
static NSString *Legacy(void) { return [root stringByAppendingPathComponent:@"com.hydra.tlinkios.plist"]; }
static void Write(id value, NSString *path) {
    @try { CHECK([value writeToFile:path atomically:YES],"fixture source written"); }
    @finally { value = nil;path = nil; }
}
static void Clear(void) {
    for (NSString *path in @[PXTLinkIOSSettingsPath(),PXSecuritySettingsPath(),Legacy()])
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    [fixtureDefaults removePersistentDomainForName:suite];
}
static NSDictionary *Bytes(void) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *path in @[PXTLinkIOSSettingsPath(),PXSecuritySettingsPath(),Legacy()]) result[path] = [NSData dataWithContentsOfFile:path] ?: (id)NSNull.null;
    result[@"files"] = [NSSet setWithArray:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:root error:NULL]];
    return result;
}
static void Expect(BOOL expected, const char *label) {
    NSDictionary *before = Bytes();id oldSuite = [fixtureDefaults objectForKey:@"deviceThemeSpoofEnabled"];
    BOOL result = NO;
    @try { result = PXThemeRootfulEnabled(); } @catch (__unused NSException *e) { result = NO; }
    CHECK(result == expected,label);
    CHECK(([before isEqual:Bytes()] && [(oldSuite ?: NSNull.null) isEqual:([fixtureDefaults objectForKey:@"deviceThemeSpoofEnabled"] ?: NSNull.null)]),"reader leaves source bytes absence directory contents and defaults unchanged");
}
static void Cases(void) {
    Clear();Expect(NO,"all sources absent defaults OFF");
    [fixtureDefaults setObject:@YES forKey:@"deviceThemeSpoofEnabled"];Expect(YES,"missing primary and disk key preserve defaults fallback");
    Write(@{@"deviceThemeSpoofEnabled":@NO},PXSecuritySettingsPath());Expect(NO,"disk false beats defaults true");
    Write(@{},PXSecuritySettingsPath());Expect(YES,"missing disk key can use defaults");
    Write(@{@"deviceThemeSpoofEnabled":@[]},PXSecuritySettingsPath());Expect(NO,"present malformed disk scalar blocks defaults fallback");
    Write(@[],PXSecuritySettingsPath());Expect(NO,"malformed disk root blocks defaults fallback");
    Clear();Write(@{@"deviceThemeSpoofEnabled":@YES},PXSecuritySettingsPath());
    Write(@{@"EnabledIdentifiers":@{@"DeviceTheme":@NO}},PXTLinkIOSSettingsPath());Expect(NO,"explicit primary false beats secondary true");
    Write(@{@"EnabledIdentifiers":@{@"DeviceTheme":@YES}},PXTLinkIOSSettingsPath());
    Write(@{@"deviceThemeSpoofEnabled":@NO},PXSecuritySettingsPath());Expect(YES,"primary true is authoritative over secondary false");
    Write(@{@"EnabledIdentifiers":@{}},PXTLinkIOSSettingsPath());Expect(NO,"missing primary uses secondary false");
    Write(@{@"deviceThemeSpoofEnabled":@YES},PXSecuritySettingsPath());Expect(YES,"missing primary uses secondary true");
    Write(@{@"EnabledIdentifiers":@[]},PXTLinkIOSSettingsPath());Expect(NO,"present malformed primary map blocks secondary true");
    Write(@[],PXTLinkIOSSettingsPath());Expect(NO,"present non-dictionary primary source blocks fallback");
    [@"broken plist" writeToFile:PXTLinkIOSSettingsPath() atomically:YES encoding:NSUTF8StringEncoding error:NULL];Expect(NO,"present corrupt primary source blocks fallback");
    Clear();Write(@{@"EnabledIdentifiers":@{@"DeviceTheme":@YES}},Legacy());Expect(YES,"legacy file is used when canonical source is absent");
    Write(@{@"EnabledIdentifiers":@{@"DeviceTheme":@NO}},PXTLinkIOSSettingsPath());Expect(NO,"canonical false beats legacy true");
    Write(@{},PXTLinkIOSSettingsPath());Expect(NO,"existing canonical dictionary never consults legacy");
    Write(@[],PXTLinkIOSSettingsPath());Expect(NO,"existing corrupt canonical source never consults legacy");
    Clear();NSArray *values = @[@YES,@NO,@0,@2,@"YES",@"NO",@"1",@"0",@[],@{}];
    BOOL expected[] = {YES,NO,NO,YES,YES,NO,YES,NO,NO,NO};
    for (NSUInteger i = 0; i < values.count; i++) {
        Write(@{@"EnabledIdentifiers":@{@"DeviceTheme":values[i]}},PXTLinkIOSSettingsPath());
        Write(@{@"deviceThemeSpoofEnabled":@YES},PXSecuritySettingsPath());Expect(expected[i],"primary typed scalar conversion with no fallback on invalid present value");
    }
    Clear();NSError *__autoreleasing error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:PXTLinkIOSSettingsPath() withIntermediateDirectories:NO attributes:nil error:&error];
    CHECK(error == nil,"directory negative fixture created");[fixtureDefaults setObject:@YES forKey:@"deviceThemeSpoofEnabled"];Expect(NO,"non-file primary is not treated as absence");
}
int main(void) {
    @autoreleasepool {
        suite = [@"com.example.px-theme-test." stringByAppendingString:NSUUID.UUID.UUIDString];
        root = [NSTemporaryDirectory() stringByAppendingPathComponent:suite];
        fixtureDefaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        NSError *__autoreleasing error = nil;
        CHECK([[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:NO attributes:nil error:&error],"isolated test directory created");
        @try { if (!error) Cases(); }
        @finally {
            [fixtureDefaults removePersistentDomainForName:suite];
            [[NSFileManager defaultManager] removeItemAtPath:root error:NULL];fixtureDefaults = nil;root = suite = nil;
        }
    }
    fprintf(stdout,"Theme enablement real files: %lu/%lu checks passed\n",(unsigned long)(checks-failures),(unsigned long)checks);
    return failures ? 1 : 0;
}
