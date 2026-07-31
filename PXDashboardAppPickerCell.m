#import "PXDashboardAppPickerCell.h"
#import "WeaponXTheme.h"

UIColor *PXAppPickerBackgroundColor(void) {
    if (@available(iOS 13.0, *)) return [UIColor systemGroupedBackgroundColor];
    return [UIColor colorWithWhite:0.96 alpha:1.0];
}

UIColor *PXAppPickerCardColor(void) {
    if (@available(iOS 13.0, *)) return [UIColor secondarySystemGroupedBackgroundColor];
    return [UIColor whiteColor];
}

UIColor *PXAppPickerSecondaryTextColor(void) {
    if (@available(iOS 13.0, *)) return [UIColor secondaryLabelColor];
    return [UIColor colorWithWhite:0.42 alpha:1.0];
}

UIColor *PXAppPickerBorderColor(void) {
    if (@available(iOS 13.0, *)) return [UIColor separatorColor];
    return [UIColor colorWithWhite:0.84 alpha:1.0];
}

@implementation PXDashboardAppPickerCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;

    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.clipsToBounds = NO;

    self.cardView = [[UIView alloc] init];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.backgroundColor = PXAppPickerCardColor();
    self.cardView.layer.cornerRadius = 15.0;
    self.cardView.layer.borderWidth = 0.5;
    self.cardView.layer.borderColor = PXAppPickerBorderColor().CGColor;
    self.cardView.layer.masksToBounds = YES;
    [self.contentView addSubview:self.cardView];

    self.appIconView = [[UIImageView alloc] init];
    self.appIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.appIconView.contentMode = UIViewContentModeScaleAspectFill;
    self.appIconView.layer.cornerRadius = 12.0;
    self.appIconView.layer.masksToBounds = YES;
    if (@available(iOS 13.0, *)) {
        self.appIconView.backgroundColor = [UIColor tertiarySystemFillColor];
        self.appIconView.tintColor = [UIColor systemBlueColor];
    } else {
        self.appIconView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        self.appIconView.tintColor = [UIColor blueColor];
    }
    [self.cardView addSubview:self.appIconView];

    self.appNameLabel = [[UILabel alloc] init];
    self.appNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.appNameLabel.font = WXScaledFont(17.0, UIFontWeightSemibold);
    self.appNameLabel.adjustsFontForContentSizeCategory = YES;
    self.appNameLabel.numberOfLines = 1;
    self.appNameLabel.adjustsFontSizeToFitWidth = YES;
    self.appNameLabel.minimumScaleFactor = 0.82;
    [self.cardView addSubview:self.appNameLabel];

    self.appDetailLabel = [[UILabel alloc] init];
    self.appDetailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.appDetailLabel.font = WXScaledFont(13.5, UIFontWeightRegular);
    self.appDetailLabel.adjustsFontForContentSizeCategory = YES;
    self.appDetailLabel.textColor = PXAppPickerSecondaryTextColor();
    self.appDetailLabel.numberOfLines = 1;
    self.appDetailLabel.adjustsFontSizeToFitWidth = YES;
    self.appDetailLabel.minimumScaleFactor = 0.76;
    [self.cardView addSubview:self.appDetailLabel];

    self.selectionCircleView = [[UIView alloc] init];
    self.selectionCircleView.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionCircleView.layer.cornerRadius = 15.0;
    self.selectionCircleView.layer.borderWidth = 2.0;
    self.selectionCircleView.userInteractionEnabled = NO;
    [self.cardView addSubview:self.selectionCircleView];

    self.selectionCheckLabel = [[UILabel alloc] init];
    self.selectionCheckLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.selectionCheckLabel.text = @"✓";
    self.selectionCheckLabel.textAlignment = NSTextAlignmentCenter;
    self.selectionCheckLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightBold];
    self.selectionCheckLabel.textColor = [UIColor whiteColor];
    self.selectionCheckLabel.userInteractionEnabled = NO;
    [self.selectionCircleView addSubview:self.selectionCheckLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:5.0],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-5.0],

        [self.appIconView.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16.0],
        [self.appIconView.centerYAnchor constraintEqualToAnchor:self.cardView.centerYAnchor],
        [self.appIconView.widthAnchor constraintEqualToConstant:54.0],
        [self.appIconView.heightAnchor constraintEqualToConstant:54.0],

        [self.selectionCircleView.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16.0],
        [self.selectionCircleView.centerYAnchor constraintEqualToAnchor:self.cardView.centerYAnchor],
        [self.selectionCircleView.widthAnchor constraintEqualToConstant:30.0],
        [self.selectionCircleView.heightAnchor constraintEqualToConstant:30.0],

        [self.selectionCheckLabel.topAnchor constraintEqualToAnchor:self.selectionCircleView.topAnchor],
        [self.selectionCheckLabel.leadingAnchor constraintEqualToAnchor:self.selectionCircleView.leadingAnchor],
        [self.selectionCheckLabel.trailingAnchor constraintEqualToAnchor:self.selectionCircleView.trailingAnchor],
        [self.selectionCheckLabel.bottomAnchor constraintEqualToAnchor:self.selectionCircleView.bottomAnchor constant:-1.0],

        [self.appNameLabel.leadingAnchor constraintEqualToAnchor:self.appIconView.trailingAnchor constant:16.0],
        [self.appNameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.selectionCircleView.leadingAnchor constant:-14.0],
        [self.appNameLabel.bottomAnchor constraintEqualToAnchor:self.cardView.centerYAnchor constant:-2.0],

        [self.appDetailLabel.leadingAnchor constraintEqualToAnchor:self.appNameLabel.leadingAnchor],
        [self.appDetailLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.selectionCircleView.leadingAnchor constant:-14.0],
        [self.appDetailLabel.topAnchor constraintEqualToAnchor:self.cardView.centerYAnchor constant:4.0]
    ]];

    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.representedBundleID = nil;
    self.appIconView.image = nil;
    self.appNameLabel.text = nil;
    self.appDetailLabel.text = nil;
}

- (void)configureWithApp:(NSDictionary *)app icon:(UIImage *)icon selected:(BOOL)selected {
    NSString *bundleID = [app[@"bundleID"] isKindOfClass:[NSString class]] ? app[@"bundleID"] : @"";
    NSString *name = [app[@"name"] isKindOfClass:[NSString class]] ? app[@"name"] : bundleID;
    NSString *version = [app[@"version"] isKindOfClass:[NSString class]] ? app[@"version"] : @"1.0";

    self.representedBundleID = bundleID;
    self.appNameLabel.text = name.length ? name : @"Ứng dụng";
    self.appDetailLabel.text = [NSString stringWithFormat:@"%@ (v%@)", bundleID, version];
    self.appIconView.image = icon;

    UIColor *blue = nil;
    UIColor *unselectedBorder = nil;
    if (@available(iOS 13.0, *)) {
        blue = [UIColor systemBlueColor];
        unselectedBorder = [UIColor systemGray3Color];
    } else {
        blue = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
        unselectedBorder = [UIColor colorWithWhite:0.80 alpha:1.0];
    }
    self.selectionCircleView.layer.borderColor = (selected ? blue : unselectedBorder).CGColor;
    self.selectionCircleView.backgroundColor = selected ? blue : [UIColor clearColor];
    self.selectionCheckLabel.hidden = !selected;
}

@end
