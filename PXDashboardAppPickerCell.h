#import <UIKit/UIKit.h>

/// Shared app-picker palette. Adapts to light/dark on iOS 13+, with sensible
/// fallbacks on older systems. Defined in PXDashboardAppPickerCell.m and also
/// used by the app-picker screen in TLinkIOSViewController.
UIColor *PXAppPickerBackgroundColor(void);
UIColor *PXAppPickerCardColor(void);
UIColor *PXAppPickerSecondaryTextColor(void);
UIColor *PXAppPickerBorderColor(void);

/// Table cell used by the dashboard app-picker list.
@interface PXDashboardAppPickerCell : UITableViewCell
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIImageView *appIconView;
@property (nonatomic, strong) UILabel *appNameLabel;
@property (nonatomic, strong) UILabel *appDetailLabel;
@property (nonatomic, strong) UIView *selectionCircleView;
@property (nonatomic, strong) UILabel *selectionCheckLabel;
@property (nonatomic, copy) NSString *representedBundleID;
- (void)configureWithApp:(NSDictionary *)app icon:(UIImage *)icon selected:(BOOL)selected;
@end
