#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "MethodSwizzler.h"
#include <stdio.h>

static NSUInteger gChecks, gFailures, gClassIndex;
#define CHECK(value, label) do { gChecks++; if (!(value)) { gFailures++; fprintf(stderr, "FAIL: %s\n", label); } } while (0)

// Declarations only: the dynamically registered classes supply implementations.
@interface NSObject (PXSwizzleFixtureSelectors)
- (NSString *)px_value;
- (NSString *)px_alias;
+ (NSString *)px_value;
+ (NSString *)px_alias;
- (id)px_process:(id)value;
- (id)px_aliasProcess:(id)value;
@end
static id BaseValue(id self, SEL command) { (void)self; (void)command; return @"base"; }
static id ChildValue(id self, SEL command) { (void)self; (void)command; return @"child"; }
static id SiblingValue(id self, SEL command) { (void)self; (void)command; return @"sibling"; }
static id WrappedValue(id self, SEL command) { (void)command; return [NSString stringWithFormat:@"wrap(%@)", [self px_alias]]; }
static id ObjectArgument(id self, SEL command, id value) { (void)self; (void)command; return value; }
static id DoubleArgument(id self, SEL command, double value) { (void)self; (void)command; (void)value; return @"wrong ABI"; }
static Class NewClass(Class parent) {
    NSString *name = [NSString stringWithFormat:@"PXSwizzleDynamic%lu", (unsigned long)gClassIndex++];
    Class cls = objc_allocateClassPair(parent, name.UTF8String, 0);
    CHECK(cls != Nil, "runtime fixture class allocated");
    if (cls) objc_registerClassPair(cls);
    return cls;
}
static void Add(Class cls, SEL selector, IMP implementation, const char *types) {
    CHECK(class_addMethod(cls, selector, implementation, types), "runtime fixture method added");
}
static void Install(Class cls) { [MethodSwizzler swizzleClass:cls originalSelector:@selector(px_value) swizzledSelector:@selector(px_alias)]; }
static void InstallMeta(Class cls) { [MethodSwizzler swizzleClassMethod:cls originalSelector:@selector(px_value) swizzledSelector:@selector(px_alias)]; }

static void TestEncodings(void) {
    NSArray *cases = @[
        @[@"@@:", @"@24@0:8", @YES],
        @[@"@@:", @"@\"NSString\"16@0:8", @YES],
        @[@"r@@:", @"@@:", @YES],
        @[@"@@:@", @"@@:@", @YES],
        @[@"@@:@", @"@@:d", @NO],
        @[@"@@:@", @"@@:@?", @NO],
        @[@"v@:@?", @"v24@0:8@?16", @YES],
        @[@"v@:@?", @"v@:@", @NO],
        @[@"Q@:", @"q@:", @NO],
        @[@"{Pair=dd}@:", @"{Pair=qq}@:", @NO],
        @[@"^i@:", @"^d@:", @NO],
        @[@"@@:", @"@@:@", @NO],
        @[@"@@:", @"v@:", @NO]
    ];
    for (NSArray *row in cases) {
        Class cls = NewClass(NSObject.class);
        // These candidates are metadata only; mismatched IMPs are never called.
        Add(cls, @selector(px_value), (IMP)BaseValue, [row[0] UTF8String]);
        Method method = class_getInstanceMethod(cls, @selector(px_value));
        CHECK(PXMethodHasCompatibleTypeEncoding(method, [row[1] UTF8String]) == [row[2] boolValue],
              "ABI gate checks every argument return shape block distinction and frame offsets");
        CHECK(!PXMethodHasCompatibleTypeEncoding(method, NULL) && !PXMethodHasCompatibleTypeEncoding(method, ""),
              "missing and empty expected encodings fail before parsing");
    }
    CHECK(!PXMethodHasCompatibleTypeEncoding(NULL, "@@:"), "missing optional method fails closed");
    Class cls = NewClass(NSObject.class);
    Add(cls, @selector(px_process:), (IMP)ObjectArgument, "@@:@");
    Add(cls, @selector(px_aliasProcess:), (IMP)DoubleArgument, "@@:d");
    Method original = class_getInstanceMethod(cls, @selector(px_process:)); IMP before = method_getImplementation(original);
    [MethodSwizzler swizzleClass:cls originalSelector:@selector(px_process:) swizzledSelector:@selector(px_aliasProcess:)];
    CHECK(method_getImplementation(original) == before && [[[cls new] px_process:@"input"] isEqual:@"input"],
          "same return and argument count cannot admit an object-versus-double argument swizzle");
}
static void TestLocalInheritance(void) {
    Class parent = NewClass(NSObject.class);
    Add(parent, @selector(px_value), (IMP)BaseValue, "@@:");
    Add(parent, @selector(px_alias), (IMP)WrappedValue, "@@:");
    IMP parentAlias = method_getImplementation(class_getInstanceMethod(parent, @selector(px_alias)));
    Class child = NewClass(parent), sibling = NewClass(parent);
    Add(child, @selector(px_value), (IMP)ChildValue, "@@:");
    Add(sibling, @selector(px_value), (IMP)SiblingValue, "@@:");
    Install(child);
    CHECK([[[child new] px_value] isEqual:@"wrap(child)"] && [[[parent new] px_value] isEqual:@"base"] &&
          [[[sibling new] px_value] isEqual:@"sibling"] && method_getImplementation(class_getInstanceMethod(parent, @selector(px_alias))) == parentAlias,
          "local original and inherited alias never exchange the superclass method");
    Install(child); Install(child);
    [MethodSwizzler swizzleClass:child originalSelector:@selector(px_alias) swizzledSelector:@selector(px_value)];
    CHECK([[[child new] px_value] isEqual:@"wrap(child)"] && [[[child new] px_alias] isEqual:@"child"],
          "duplicate and reversed installation requests do not undo or recursively wrap hooks");
    Install(sibling);
    CHECK([[[sibling new] px_value] isEqual:@"wrap(sibling)"] && [[[parent new] px_value] isEqual:@"base"],
          "independent siblings can each localize the same inherited alias");
    Install(parent);
    CHECK([[[parent new] px_value] isEqual:@"base"] && [[[child new] px_value] isEqual:@"wrap(child)"],
          "later ancestor request cannot create a second owner for an already installed hierarchy pair");

    Class sharedParent = NewClass(NSObject.class);
    Add(sharedParent, @selector(px_value), (IMP)BaseValue, "@@:");
    Add(sharedParent, @selector(px_alias), (IMP)WrappedValue, "@@:");
    Class inherited = NewClass(sharedParent);
    Install(inherited);
    CHECK([[[inherited new] px_value] isEqual:@"wrap(base)"] && [[[sharedParent new] px_value] isEqual:@"base"] &&
          class_getInstanceMethod(inherited, @selector(px_value)) != class_getInstanceMethod(sharedParent, @selector(px_value)) &&
          class_getInstanceMethod(inherited, @selector(px_alias)) != class_getInstanceMethod(sharedParent, @selector(px_alias)),
          "both inherited methods become local without changing parent behavior");
}

@interface PXSwizzleSuperFixture : NSObject
- (NSString *)px_value;
- (NSString *)px_alias;
@end
@implementation PXSwizzleSuperFixture
- (NSString *)px_value { return @"base"; }
- (NSString *)px_alias { return [NSString stringWithFormat:@"wrap(%@)", [self px_alias]]; }
@end
@interface PXSwizzleCallsSuperFixture : PXSwizzleSuperFixture
@end
@implementation PXSwizzleCallsSuperFixture
- (NSString *)px_value { return [@"child-super:" stringByAppendingString:[super px_value]]; }
@end
static void TestHierarchySuper(void) {
    Install(PXSwizzleSuperFixture.class); Install(PXSwizzleCallsSuperFixture.class);
    CHECK([[[PXSwizzleSuperFixture new] px_value] isEqual:@"wrap(base)"] &&
          [[[PXSwizzleCallsSuperFixture new] px_value] isEqual:@"child-super:wrap(base)"],
          "shared alias is never installed again in a subclass whose original calls super");
}
static void TestClassMethods(void) {
    Class parent = NewClass(NSObject.class), child = NewClass(parent);
    Add(object_getClass((id)parent), @selector(px_value), (IMP)BaseValue, "@@:");
    Add(object_getClass((id)parent), @selector(px_alias), (IMP)WrappedValue, "@@:");
    Add(object_getClass((id)child), @selector(px_value), (IMP)ChildValue, "@@:");
    InstallMeta(child); InstallMeta(child);
    CHECK([[child px_value] isEqual:@"wrap(child)"] && [[parent px_value] isEqual:@"base"],
          "class-method path localizes both selectors on the metaclass and is idempotent");
    Add(parent, @selector(px_alias), (IMP)WrappedValue, "@@:");
    Add(child, @selector(px_value), (IMP)ChildValue, "@@:");
    Install(child);
    CHECK([[[child new] px_value] isEqual:@"wrap(child)"] && [[child px_value] isEqual:@"wrap(child)"],
          "instance and metaclass pairs retain separate installation ownership");
}
static void TestConcurrentAndInvalid(void) {
    Class cls = NewClass(NSObject.class);
    Add(cls, @selector(px_value), (IMP)BaseValue, "@@:");
    Add(cls, @selector(px_alias), (IMP)WrappedValue, "@@:");
    dispatch_apply(64, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
        (void)index; @autoreleasepool { Install(cls); }
    });
    CHECK([[[cls new] px_value] isEqual:@"wrap(base)"] && [[[cls new] px_alias] isEqual:@"base"],
          "concurrent duplicate requests exchange only once under the shared installation monitor");
    IMP before = method_getImplementation(class_getInstanceMethod(cls, @selector(px_value)));
    [MethodSwizzler swizzleClass:Nil originalSelector:NULL swizzledSelector:NULL];
    [MethodSwizzler swizzleClassMethod:Nil originalSelector:NULL swizzledSelector:NULL];
    [MethodSwizzler swizzleClass:cls originalSelector:@selector(px_value) swizzledSelector:@selector(px_value)];
    [MethodSwizzler swizzleClass:cls originalSelector:@selector(px_value) swizzledSelector:NSSelectorFromString(@"missingAlias")];
    CHECK(method_getImplementation(class_getInstanceMethod(cls, @selector(px_value))) == before,
          "nil missing and identical selectors leave effective implementation intact");
}
int main(void) {
    @autoreleasepool {
        @try { TestEncodings(); TestLocalInheritance(); TestHierarchySuper(); TestClassMethods(); TestConcurrentAndInvalid(); }
        @catch (NSException *exception) { gFailures++; fprintf(stderr, "FAIL: unexpected swizzle exception: %s\n", exception.description.UTF8String); }
        printf("Method swizzler: %lu/%lu checks passed\n", (unsigned long)(gChecks-gFailures), (unsigned long)gChecks);
        return gFailures ? 1 : 0;
    }
}
