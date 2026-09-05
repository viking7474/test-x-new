#import "common/PXUIKitCompat.h"
#import "ProgressHUDView.h"
#import "WeaponXTheme.h"

@interface ProgressHUDView ()
@property (nonatomic, strong) UIVisualEffectView *cardView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation ProgressHUDView

+ (ProgressHUDView *)showHUDAddedTo:(UIView *)view title:(NSString *)title {
    // Avoid stacking multiple HUDs in the same host view.
    [self hideHUDForView:view];

    ProgressHUDView *hud = [[ProgressHUDView alloc] initWithFrame:view.bounds];
    hud.translatesAutoresizingMaskIntoConstraints = NO;
    hud.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.35];

    // Modern material card that adapts to light/dark automatically.
    UIVisualEffectView *card;
    if (@available(iOS 13.0, *)) {
        card = [[UIVisualEffectView alloc] initWithEffect:PXThickMaterialBlurEffect()];
    } else {
        card = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    }
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.layer.cornerRadius = WXCornerRadiusMedium;
    card.clipsToBounds = YES;
    hud.cardView = card;
    UIView *content = card.contentView;

    // Activity spinner.
    UIActivityIndicatorView *spinner;
    if (@available(iOS 13.0, *)) {
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:PXMediumActivityIndicatorStyle()];
        spinner.color = PXLabelColor();
    } else {
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    }
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [spinner startAnimating];
    hud.spinner = spinner;
    [content addSubview:spinner];

    // Title label (Dynamic Type).
    hud.titleLabel = [[UILabel alloc] init];
    hud.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hud.titleLabel.text = title;
    hud.titleLabel.textAlignment = NSTextAlignmentCenter;
    hud.titleLabel.numberOfLines = 2;
    hud.titleLabel.font = WXScaledFont(16.0, UIFontWeightSemibold);
    hud.titleLabel.adjustsFontForContentSizeCategory = YES;
    if (@available(iOS 13.0, *)) {
        hud.titleLabel.textColor = PXLabelColor();
    } else {
        hud.titleLabel.textColor = [UIColor whiteColor];
    }
    [content addSubview:hud.titleLabel];

    // Progress bar tinted with the brand color.
    hud.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    hud.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    hud.progressView.progress = 0.0f;
    hud.progressView.progressTintColor = [UIColor wxBrandBlue];
    [content addSubview:hud.progressView];

    // Detail label (Dynamic Type).
    hud.detailLabel = [[UILabel alloc] init];
    hud.detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    hud.detailLabel.textAlignment = NSTextAlignmentCenter;
    hud.detailLabel.numberOfLines = 1;
    hud.detailLabel.font = WXScaledFont(13.0, UIFontWeightRegular);
    hud.detailLabel.adjustsFontForContentSizeCategory = YES;
    if (@available(iOS 13.0, *)) {
        hud.detailLabel.textColor = PXSecondaryLabelColor();
    } else {
        hud.detailLabel.textColor = [UIColor lightGrayColor];
    }
    [content addSubview:hud.detailLabel];

    [hud addSubview:card];
    [view addSubview:hud];

    // Pin the dimming overlay to the host view.
    [NSLayoutConstraint activateConstraints:@[
        [hud.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
        [hud.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [hud.topAnchor constraintEqualToAnchor:view.topAnchor],
        [hud.bottomAnchor constraintEqualToAnchor:view.bottomAnchor]
    ]];

    // Center the card and lay out its contents with Auto Layout.
    [NSLayoutConstraint activateConstraints:@[
        [card.centerXAnchor constraintEqualToAnchor:hud.centerXAnchor],
        [card.centerYAnchor constraintEqualToAnchor:hud.centerYAnchor],
        [card.widthAnchor constraintGreaterThanOrEqualToConstant:240.0],
        [card.widthAnchor constraintLessThanOrEqualToConstant:300.0],

        [spinner.topAnchor constraintEqualToAnchor:content.topAnchor constant:20.0],
        [spinner.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],

        [hud.titleLabel.topAnchor constraintEqualToAnchor:spinner.bottomAnchor constant:12.0],
        [hud.titleLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20.0],
        [hud.titleLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20.0],

        [hud.progressView.topAnchor constraintEqualToAnchor:hud.titleLabel.bottomAnchor constant:14.0],
        [hud.progressView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20.0],
        [hud.progressView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20.0],

        [hud.detailLabel.topAnchor constraintEqualToAnchor:hud.progressView.bottomAnchor constant:10.0],
        [hud.detailLabel.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20.0],
        [hud.detailLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20.0],
        [hud.detailLabel.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-20.0]
    ]];

    // Fade/scale-in, respecting the Reduce Motion accessibility setting.
    hud.alpha = 0.0;
    if (WXReduceMotionEnabled()) {
        [UIView animateWithDuration:0.2 animations:^{ hud.alpha = 1.0; }];
    } else {
        card.transform = CGAffineTransformMakeScale(0.9, 0.9);
        [UIView animateWithDuration:0.28 delay:0.0 usingSpringWithDamping:0.8 initialSpringVelocity:0.4 options:UIViewAnimationOptionCurveEaseOut animations:^{
            hud.alpha = 1.0;
            card.transform = CGAffineTransformIdentity;
        } completion:nil];
    }

    return hud;
}

+ (void)hideHUDForView:(UIView *)view {
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[ProgressHUDView class]]) {
            [sub removeFromSuperview];
        }
    }
}

- (void)setProgress:(float)progress animated:(BOOL)animated {
    [self.progressView setProgress:progress animated:animated];
}

- (void)setDetailText:(NSString *)text {
    self.detailLabel.text = text;
}

@end
