//
//  WeaponXTheme.h
//  ProjectX
//
//  P1 design-system: single source of truth for brand colors, radii,
//  Dynamic Type scaling, and the Reduce Motion accessibility flag.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIColor (WeaponXTheme)

/// Primary brand blue. Dark-mode aware on iOS 13+.
+ (UIColor *)wxBrandBlue;
/// Positive / success state color.
+ (UIColor *)wxSuccess;
/// Destructive / error state color.
+ (UIColor *)wxDanger;
/// Matrix rain accent green.
+ (UIColor *)wxMatrixGreen;

@end

/// Corner-radius design tokens (keep radii consistent across the app).
extern const CGFloat WXCornerRadiusSmall;   // 12
extern const CGFloat WXCornerRadiusMedium;  // 16
extern const CGFloat WXCornerRadiusLarge;   // 20

/// YES when the user enabled Accessibility > Reduce Motion.
BOOL WXReduceMotionEnabled(void);

/// A font that scales with Dynamic Type around a base point size.
UIFont *WXScaledFont(CGFloat baseSize, UIFontWeight weight);

NS_ASSUME_NONNULL_END
