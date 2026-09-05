#import "PXUIKitCompat.h"
//
//  WeaponXToast.m
//  TLinkIOS
//

#import "WeaponXToast.h"
#import "WeaponXTheme.h"
#import "PXUIKitCompat.h"

@implementation WeaponXToast

+ (nullable UIWindow *)wx_keyWindow {
    return PXKeyWindow();
}

+ (void)wx_presentMessage:(NSString *)message
                isSuccess:(BOOL)isSuccess
                 duration:(CGFloat)duration
              inContainer:(UIView *)container {
    if (!container || message.length == 0) { return; }

    UIView *toast = [[UIView alloc] init];
    toast.backgroundColor = [(isSuccess ? [UIColor wxSuccess] : [UIColor wxDanger]) colorWithAlphaComponent:0.95];
    toast.layer.cornerRadius = WXCornerRadiusLarge;
    toast.clipsToBounds = YES;
    toast.alpha = 0.0;
    toast.translatesAutoresizingMaskIntoConstraints = NO;

    // Drop shadow for readability over any background.
    toast.layer.shadowColor = [UIColor blackColor].CGColor;
    toast.layer.shadowOffset = CGSizeMake(0, 4);
    toast.layer.shadowOpacity = 0.3;
    toast.layer.shadowRadius = 5;

    UIImageView *iconView = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) {
        NSString *iconName = isSuccess ? @"checkmark.circle.fill" : @"exclamationmark.triangle.fill";
        iconView.image = [PXSystemImageNamed(iconName) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    iconView.tintColor = [UIColor whiteColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *label = [[UILabel alloc] init];
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentLeft;
    label.numberOfLines = 2;
    label.text = message;
    label.font = WXScaledFont(15.0, UIFontWeightSemibold);
    label.adjustsFontForContentSizeCategory = YES;
    label.translatesAutoresizingMaskIntoConstraints = NO;

    [toast addSubview:iconView];
    [toast addSubview:label];
    [container addSubview:toast];

    UILayoutGuide *guide = container.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [toast.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [toast.topAnchor constraintEqualToAnchor:guide.topAnchor constant:20],
        [toast.leadingAnchor constraintGreaterThanOrEqualToAnchor:container.leadingAnchor constant:20],
        [toast.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-20],
        [toast.heightAnchor constraintGreaterThanOrEqualToConstant:44],

        [iconView.leadingAnchor constraintEqualToAnchor:toast.leadingAnchor constant:15],
        [iconView.centerYAnchor constraintEqualToAnchor:toast.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:24],
        [iconView.heightAnchor constraintEqualToConstant:24],

        [label.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:10],
        [label.trailingAnchor constraintEqualToAnchor:toast.trailingAnchor constant:-15],
        [label.topAnchor constraintEqualToAnchor:toast.topAnchor constant:12],
        [label.bottomAnchor constraintEqualToAnchor:toast.bottomAnchor constant:-12],
    ]];

    void (^dismiss)(void) = ^{
        [UIView animateWithDuration:0.3 animations:^{
            toast.alpha = 0.0;
            toast.transform = CGAffineTransformMakeScale(0.95, 0.95);
        } completion:^(BOOL done) {
            [toast removeFromSuperview];
        }];
    };

    if (WXReduceMotionEnabled()) {
        // Respect Reduce Motion: plain fade, no spring/scale.
        [UIView animateWithDuration:0.2 animations:^{
            toast.alpha = 1.0;
        } completion:^(BOOL done) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), dismiss);
        }];
    } else {
        [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            toast.alpha = 1.0;
            toast.transform = CGAffineTransformMakeScale(1.05, 1.05);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.2 animations:^{
                toast.transform = CGAffineTransformIdentity;
            }];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), dismiss);
        }];
    }
}

+ (void)showMessage:(NSString *)message isSuccess:(BOOL)isSuccess {
    [self showMessage:message isSuccess:isSuccess duration:(isSuccess ? 3.0 : 2.0)];
}

+ (void)showMessage:(NSString *)message isSuccess:(BOOL)isSuccess duration:(CGFloat)duration {
    UIWindow *window = [self wx_keyWindow];
    if (window) {
        [self wx_presentMessage:message isSuccess:isSuccess duration:duration inContainer:window];
    }
}

+ (void)showMessage:(NSString *)message isSuccess:(BOOL)isSuccess inView:(UIView *)view {
    if (view) {
        [self wx_presentMessage:message isSuccess:isSuccess duration:(isSuccess ? 3.0 : 2.0) inContainer:view];
    } else {
        [self showMessage:message isSuccess:isSuccess];
    }
}

@end
