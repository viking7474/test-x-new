#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <dispatch/dispatch.h>
#import "PXRuntimeScalarPreparation.h"
#import "SerialNumberManager.h"
#import "PXIdentityValidator.h"
#import "TLinkIOSLogging.h"
#include <stdatomic.h>
#include <stdint.h>
#include <string.h>

static NSUInteger gChecks, gFailures;
static _Atomic NSUInteger gSecureCalls, gTapeIndex, gFailAt;
static _Atomic uint32_t gUUIDRandomWord = 5;
static NSArray<NSNumber *> *gTape;
static BOOL gSerialAllowed = YES;
#define CHECK(value, message) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", message); } } while (0)
uint32_t PXScalarFixtureRandom(void) { return atomic_load(&gUUIDRandomWord); }
uint32_t PXScalarFixtureUniform(uint32_t bound) { return bound > 1 ? 1 : 0; }
OSStatus PXScalarFixtureSecure(SecRandomRef random, size_t count, void *bytes) {
    (void)random;
    NSUInteger call = atomic_fetch_add(&gSecureCalls, 1) + 1;
    if (atomic_load(&gFailAt) == call) return errSecNotAvailable;
    NSUInteger index = atomic_fetch_add(&gTapeIndex, 1);
    uint32_t word = index < gTape.count ? gTape[index].unsignedIntValue : 5;
    if (count == sizeof(word)) memcpy(bytes, &word, count);
    else memset(bytes, 5, count);
    return errSecSuccess;
}
void PXLog(NSString *format, ...) { (void)format; }
static void Tape(NSArray<NSNumber *> *values, NSUInteger failAt) {
    gTape = [values copy]; atomic_store(&gSecureCalls, 0); atomic_store(&gTapeIndex, 0); atomic_store(&gFailAt, failAt);
}
static NSString *Invoke(id object, NSString *method) {
    SEL selector = NSSelectorFromString(method);
    NSString *(*call)(id, SEL) = (NSString *(*)(id, SEL))[object methodForSelector:selector];
    return call(object, selector);
}
@interface PXAllowedSerialFixture : SerialNumberManager
@end
@implementation PXAllowedSerialFixture
- (BOOL)isEnvironmentSecure { return gSerialAllowed; }
@end

static void TestFactories(void) {
    NSArray *uuidTypes = @[@"SystemBootUUID", @"DyldCacheUUID", @"PasteboardUUID", @"KeychainUUID", @"UserDefaultsUUID",
        @"AppGroupUUID", @"CoreDataUUID", @"AppInstallUUID", @"AppContainerUUID"];
    // Independent expected values cover all four variants, lowercase hex and
    // the unsigned RNG boundary. Runtime class membership is not a mutability
    // contract for Foundation class clusters; the factory returns [uuid copy].
    NSArray *uuidCases = @[
        @[@0, @"00000000-0000-4000-8000-000000000000"],
        @[@1, @"11111111-1111-4111-9111-111111111111"],
        @[@2, @"22222222-2222-4222-a222-222222222222"],
        @[@3, @"33333333-3333-4333-b333-333333333333"],
        @[@5, @"55555555-5555-4555-9555-555555555555"],
        @[@10, @"aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa"],
        @[@(UINT32_MAX), @"ffffffff-ffff-4fff-bfff-ffffffffffff"]
    ];
    for (NSString *type in uuidTypes) {
        for (NSArray *testCase in uuidCases) {
            uint32_t word = [testCase[0] unsignedIntValue];
            atomic_store(&gUUIDRandomWord, word);
            NSError *error = nil; NSString *value = PXPrepareRuntimeScalar(type, &error);
            BOOL valid = value.length == 36 && error == nil && [value isEqual:testCase[1]] &&
                [value isEqual:value.lowercaseString] && [value characterAtIndex:14] == '4' &&
                [[NSCharacterSet characterSetWithCharactersInString:@"89ab"] characterIsMember:[value characterAtIndex:19]] &&
                PXValidateIdentityValue(value, PXIdentityValueKindUUID, NO);
            if (!valid) fprintf(stderr, "UUID fixture: type=%s word=%lu value=%s class=%s error=%s\n",
                type.UTF8String, (unsigned long)word, (value ?: @"(nil)").UTF8String,
                NSStringFromClass(value.class).UTF8String ?: "(nil)", error.description.UTF8String ?: "(none)");
            CHECK(valid, "scalar formats preserve case version and variant");
        }
        atomic_store(&gUUIDRandomWord, 5);
        NSError *error = nil; NSString *value = PXPrepareRuntimeScalar(type, &error);
        NSMutableString *editable = [value mutableCopy];
        [editable setString:@"edited independently"];
        atomic_store(&gUUIDRandomWord, 10);
        NSString *next = PXPrepareRuntimeScalar(type, &error);
        CHECK([value isEqual:@"55555555-5555-4555-9555-555555555555"] &&
              [next isEqual:@"aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa"] && error == nil &&
              [editable isEqual:@"edited independently"], "scalar results stay detached across mutable copies and subsequent generation");
    }
    atomic_store(&gUUIDRandomWord, 5);
    for (NSString *type in @[@"IDFA", @"IDFV"]) {
        Tape(@[], 0); NSError *error = nil;
        NSString *value = PXPrepareRuntimeScalar(type, &error);
        CHECK(value.length == 36 && [value isEqual:value.uppercaseString] && atomic_load(&gSecureCalls) == 32 && error == nil,
              "upper UUID generation retains secure nibble policy");
        Tape(@[], 17);
        CHECK(PXPrepareRuntimeScalar(type, &error) == nil && [error.domain isEqual:@"com.hydra.tlinkios"] &&
              error.code == ([type isEqual:@"IDFA"] ? 1001 : 2001), "upper UUID entropy failure reports legacy error code");
    }
    NSArray *tapes = @[@[@0, @0], @[@1, @0, @1], @[@2, @0, @0], @[@3, @0], @[@4, @0, @0]];
    NSArray *names = @[@"Michael's iPhone", @"iPhone-Michael", @"Michael Smith's iPhone", @"iPhone NYC", @"iPhone 8 Plus Personal"];
    for (NSUInteger i = 0; i < tapes.count; i++) {
        Tape(tapes[i], 0); NSError *error = nil;
        CHECK([PXPrepareRuntimeScalar(@"DeviceName", &error) isEqual:names[i]] && error == nil, "device name patterns retain legacy templates");
    }
    Tape(@[], 1); NSError *error = nil;
    CHECK(PXPrepareRuntimeScalar(@"DeviceName", &error) == nil && error.code == 3001, "device name first entropy failure remains fail closed");
    Tape(@[@0], 2);
    CHECK(PXPrepareRuntimeScalar(@"DeviceName", &error) != nil && error == nil, "device name secondary entropy failure retains time fallback");
    Tape(@[], 0);
    NSString *udid = PXPrepareRuntimeScalar(@"UDID", &error);
    CHECK(udid.length == 40 && [udid isEqual:udid.lowercaseString] && PXValidateIdentityValue(udid, PXIdentityValueKindUDID, NO), "UDID keeps forty lowercase hex characters");
    CHECK(PXPrepareRuntimeScalar(@"IMEI", &error) == nil && error != nil && PXPrepareRuntimeScalar(@"SerialNumber", &error) == nil,
          "scalar factory never bypasses telephony or serial policy adapters");
    for (NSString *prefix in @[@"C02", @"FVF", @"DLXJ", @"GG78", @"HC79"]) {
        NSString *value = PXPrepareRuntimeSerial(prefix, &error);
        CHECK(value.length == 11 && [value hasPrefix:prefix] && error == nil, "serial factory retains supported prefix lengths");
    }
    CHECK(PXPrepareRuntimeSerial(nil, &error) == nil && error != nil && PXPrepareRuntimeSerial(@"BAD", &error) == nil,
          "serial factory rejects unsupported prefix without generating");
}
static void TestStandaloneProviders(void) {
    NSArray *rows = @[
        @[@"IDFAManager", @"generateIDFA", @"currentIDFA"], @[@"IDFVManager", @"generateIDFV", @"currentIDFV"],
        @[@"DeviceNameManager", @"generateDeviceName", @"currentDeviceName"],
        @[@"SystemUUIDManager", @"generateBootUUID", @"currentBootUUID"],
        @[@"DyldCacheUUIDManager", @"generateDyldCacheUUID", @"currentDyldCacheUUID"],
        @[@"PasteboardUUIDManager", @"generatePasteboardUUID", @"currentPasteboardUUID"],
        @[@"KeychainUUIDManager", @"generateKeychainUUID", @"currentKeychainUUID"],
        @[@"UserDefaultsUUIDManager", @"generateUserDefaultsUUID", @"currentUserDefaultsUUID"],
        @[@"AppGroupUUIDManager", @"generateAppGroupUUID", @"currentAppGroupUUID"],
        @[@"CoreDataUUIDManager", @"generateCoreDataUUID", @"currentCoreDataUUID"],
        @[@"AppInstallUUIDManager", @"generateAppInstallUUID", @"currentAppInstallUUID"],
        @[@"AppContainerUUIDManager", @"generateAppContainerUUID", @"currentAppContainerUUID"] ];
    for (NSArray *row in rows) {
        id provider = [NSClassFromString(row[0]) new]; Tape(@[], 0);
        NSString *value = Invoke(provider, row[1]);
        CHECK(value != nil && [Invoke(provider, row[2]) isEqual:value], "standalone provider still publishes generated value");
        if ([row[0] isEqual:@"IDFAManager"] || [row[0] isEqual:@"IDFVManager"] || [row[0] isEqual:@"DeviceNameManager"]) {
            Tape(@[], 1);
            CHECK(Invoke(provider, row[1]) == nil && [Invoke(provider, row[2]) isEqual:value], "secure entropy failure preserves provider cache");
        }
    }
}
static void TestSerial(void) {
    Tape(@[], 0); gSerialAllowed = YES;
    PXAllowedSerialFixture *serial = [PXAllowedSerialFixture new];
    NSString *borrowedOwner = @"FVF23456789";
    [serial setCurrentSerialNumber:borrowedOwner];
    NSString *prepared = [serial prepareSerialNumber];
    CHECK([prepared hasPrefix:@"FVF"] && [[serial currentSerialNumber] isEqual:borrowedOwner], "serial prepare leaves existing identifier intact");
    const char *borrowed = borrowedOwner.UTF8String;
    [serial clearSensitiveData];
    CHECK([serial currentSerialNumber] == nil && strcmp(borrowed, "FVF23456789") == 0 && [borrowedOwner isEqual:@"FVF23456789"],
          "serial clear never modifies borrowed immutable bytes");
    CHECK([serial generateSerialNumber] != nil && [serial currentSerialNumber] != nil, "serial standalone generation still publishes");
    NSString *current = [serial currentSerialNumber]; Tape(@[], 1);
    CHECK([serial prepareSerialNumber] == nil && serial.lastError.code == 4001 && [[serial currentSerialNumber] isEqual:current], "serial entropy failure leaves cache intact");
    Tape(@[], 0); gSerialAllowed = NO;
    CHECK([serial prepareSerialNumber] == nil && atomic_load(&gSecureCalls) == 0, "serial environment guard precedes preparation entropy");
    gSerialAllowed = YES;
    CHECK([[serial currentSerialNumber] isEqual:current], "denied preparation preserves previous cached serial");
    Tape(@[], 0);
    dispatch_group_t group = dispatch_group_create();
    NSMutableDictionary *counts = [NSMutableDictionary dictionary];
    NSArray *prefixes = @[@"C02", @"FVF", @"DLXJ", @"GG78", @"HC79"];
    for (NSUInteger i = 0; i < 20; i++) dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            PXAllowedSerialFixture *instance = [PXAllowedSerialFixture new];
            NSString *value = [instance prepareSerialNumber];
            NSString *prefix = @"failure";
            for (NSString *candidate in prefixes) if ([value hasPrefix:candidate]) { prefix = candidate; break; }
            @synchronized (counts) { counts[prefix] = @([counts[prefix] unsignedIntegerValue] + 1); }
        }
    });
    BOOL complete = dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0;
    BOOL balanced = NO;
    @synchronized (counts) {
        balanced = complete && counts.count == 5;
        for (NSString *prefix in prefixes) balanced = balanced && [counts[prefix] isEqual:@4];
    }
    CHECK(balanced, "serial prefix reservations remain balanced across threads");
}
int main(void) {
    @autoreleasepool {
        TestFactories(); TestStandaloneProviders(); TestSerial();
        printf("Runtime scalar preparation: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
