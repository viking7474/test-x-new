#import "PXUIKitCompat.h"
//
//  WeaponXTheme.m
//  TLinkIOS
//

#import "WeaponXTheme.h"

const CGFloat WXCornerRadiusSmall = 12.0;
const CGFloat WXCornerRadiusMedium = 16.0;
const CGFloat WXCornerRadiusLarge = 20.0;

@implementation UIColor (WeaponXTheme)

+ (UIColor *)wxBrandBlue {
    UIColor *fallback = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    SEL selector = NSSelectorFromString(@"colorWithDynamicProvider:");
    if ([UIColor respondsToSelector:selector]) {
        UIColor *(^provider)(UITraitCollection *) = ^UIColor *(UITraitCollection *tc) {
            if (PXIsDarkUserInterfaceStyle(tc)) {
                return [UIColor colorWithRed:0.20 green:0.60 blue:1.0 alpha:1.0];
            }
            return fallback;
        };
        IMP imp = [UIColor methodForSelector:selector];
        id (*fn)(id, SEL, id) = (void *)imp;
        UIColor *dynamicColor = fn(UIColor.class, selector, provider);
        if ([dynamicColor isKindOfClass:UIColor.class]) return dynamicColor;
    }
    return fallback;
}

+ (UIColor *)wxSuccess {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemGreenColor];
    }
    return [UIColor colorWithRed:0.0 green:0.6 blue:0.0 alpha:1.0];
}

+ (UIColor *)wxDanger {
    if (@available(iOS 13.0, *)) {
        return [UIColor systemRedColor];
    }
    return [UIColor colorWithRed:0.8 green:0.0 blue:0.0 alpha:1.0];
}

+ (UIColor *)wxMatrixGreen {
    return [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:1.0];
}

@end

BOOL WXReduceMotionEnabled(void) {
    return UIAccessibilityIsReduceMotionEnabled();
}

UIFont *WXScaledFont(CGFloat baseSize, UIFontWeight weight) {
    UIFont *base = [UIFont systemFontOfSize:baseSize weight:weight];
    if (@available(iOS 11.0, *)) {
        return [[UIFontMetrics defaultMetrics] scaledFontForFont:base];
    }
    return base;
}
