#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT UIColor *PXLabelColor(void);
FOUNDATION_EXPORT UIColor *PXSecondaryLabelColor(void);
FOUNDATION_EXPORT UIColor *PXTertiaryLabelColor(void);
FOUNDATION_EXPORT UIColor *PXSeparatorColor(void);
FOUNDATION_EXPORT UIColor *PXSystemBackgroundColor(void);
FOUNDATION_EXPORT UIColor *PXSecondarySystemGroupedBackgroundColor(void);
FOUNDATION_EXPORT UIColor *PXTertiarySystemGroupedBackgroundColor(void);
FOUNDATION_EXPORT UIColor *PXSecondarySystemBackgroundColor(void);
FOUNDATION_EXPORT UIColor *PXTertiarySystemBackgroundColor(void);
FOUNDATION_EXPORT UIColor *PXSystemFillColor(void);
FOUNDATION_EXPORT UIColor *PXSecondarySystemFillColor(void);
FOUNDATION_EXPORT UIColor *PXTertiarySystemFillColor(void);
FOUNDATION_EXPORT UIColor *PXSystemGray2Color(void);
FOUNDATION_EXPORT UIColor *PXSystemGray3Color(void);
FOUNDATION_EXPORT UIColor *PXSystemGray4Color(void);
FOUNDATION_EXPORT UIColor *PXSystemGray5Color(void);
FOUNDATION_EXPORT UIColor *PXSystemGray6Color(void);
FOUNDATION_EXPORT UIColor *PXSystemIndigoColor(void);
FOUNDATION_EXPORT UIColor *PXSystemGroupedBackgroundColor(void);
FOUNDATION_EXPORT UIBlurEffect *PXThinMaterialLightBlurEffect(void);
FOUNDATION_EXPORT UIBlurEffect *PXMaterialBlurEffect(void);
FOUNDATION_EXPORT UIBlurEffect *PXThickMaterialBlurEffect(void);
FOUNDATION_EXPORT UIBlurEffect *PXChromeMaterialBlurEffect(void);
FOUNDATION_EXPORT UIImage * _Nullable PXSystemImageNamed(NSString *name);
FOUNDATION_EXPORT UIImage * _Nullable PXSystemImageNamedWithPointSize(NSString *name, CGFloat pointSize);
FOUNDATION_EXPORT UIImage * _Nullable PXImageWithTintColor(UIImage * _Nullable image, UIColor *color);
FOUNDATION_EXPORT BOOL PXIsDarkUserInterfaceStyle(UITraitCollection * _Nullable traitCollection);
FOUNDATION_EXPORT UIActivityIndicatorViewStyle PXLargeActivityIndicatorStyle(void);
FOUNDATION_EXPORT UIActivityIndicatorViewStyle PXMediumActivityIndicatorStyle(void);
FOUNDATION_EXPORT UIFont *PXMonospacedSystemFont(CGFloat size, UIFontWeight weight);
FOUNDATION_EXPORT void PXSetSegmentedControlSelectedTint(UISegmentedControl *control, UIColor *color);
FOUNDATION_EXPORT UITableViewStyle PXInsetGroupedTableViewStyle(void);
FOUNDATION_EXPORT UIColor *PXDynamicColor(UIColor *(^provider)(UITraitCollection *traitCollection), UIColor *fallback);

// Window/scene helpers use runtime capability checks so the same binary is safe on iOS 12.
FOUNDATION_EXPORT id _Nullable PXForegroundWindowScene(void);
FOUNDATION_EXPORT NSArray<UIWindow *> *PXApplicationWindows(void);
FOUNDATION_EXPORT UIWindow * _Nullable PXKeyWindow(void);

NS_ASSUME_NONNULL_END
