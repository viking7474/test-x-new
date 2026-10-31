
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// Cold runtime admission: compare return and every argument, ignoring frame
// offsets and top-level qualifiers. Object class annotations share one ABI;
// blocks and other encodings are conservatively distinct.
FOUNDATION_EXPORT BOOL PXMethodHasCompatibleTypeEncoding(Method method, const char *encoding);

// Installation-only utility: duplicate/reversed pairs do not toggle hooks off.
// One installation per pair in a class hierarchy avoids alias/super recursion.
@interface MethodSwizzler : NSObject

+ (void)swizzleClass:(Class)cls originalSelector:(SEL)originalSelector swizzledSelector:(SEL)swizzledSelector;
+ (void)swizzleClassMethod:(Class)cls originalSelector:(SEL)originalSelector swizzledSelector:(SEL)swizzledSelector;

@end