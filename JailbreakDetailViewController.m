#import "JailbreakDetailViewController.h"
#import <notify.h>

@interface JailbreakDetailViewController ()
@property (nonatomic, strong) NSUserDefaults *securitySettings;
@property (nonatomic, strong) UISwitch *mainSwitch;
@end

@implementation JailbreakDetailViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.securitySettings = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Jailbreak Detection Bypass";
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    }

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.layoutMargins = UIEdgeInsetsMake(16, 16, 24, 16);
    stack.layoutMarginsRelativeArrangement = YES;
    [scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
    ]];

    // Hero
    [stack addArrangedSubview:[self buildHero]];

    // STATUS section
    [stack addArrangedSubview:[self sectionHeader:@"STATUS"]];
    UIView *statusCard = [self cardContainer];
    UIStackView *statusInner = [self innerStackIn:statusCard];
    [statusInner addArrangedSubview:[self mainToggleRow]];
    [stack addArrangedSubview:statusCard];

    // Info note
    [stack addArrangedSubview:[self noteLabel:@"Enables the Jailbreak Detection Bypass feature. This feature helps you bypass certain security measures that might be in place to prevent unauthorized access to your device."]];
}

#pragma mark - Building blocks

- (UIView *)iconChip:(NSString *)symbolName color:(UIColor *)color {
    UIView *chip = [[UIView alloc] init];
    chip.translatesAutoresizingMaskIntoConstraints = NO;
    chip.backgroundColor = [color colorWithAlphaComponent:0.15];
    chip.layer.cornerRadius = 7;
    UIImageView *iv = [[UIImageView alloc] init];
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.tintColor = color;
    if (@available(iOS 13.0, *)) {
        iv.image = [[UIImage systemImageNamed:symbolName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [chip addSubview:iv];
    [NSLayoutConstraint activateConstraints:@[
        [chip.widthAnchor constraintEqualToConstant:30],
        [chip.heightAnchor constraintEqualToConstant:30],
        [iv.centerXAnchor constraintEqualToAnchor:chip.centerXAnchor],
        [iv.centerYAnchor constraintEqualToAnchor:chip.centerYAnchor],
        [iv.widthAnchor constraintEqualToConstant:17],
        [iv.heightAnchor constraintEqualToConstant:17],
    ]];
    return chip;
}

- (UIView *)buildHero {
    UIView *card = [self cardContainer];
    UIView *chip = [self iconChip:@"lock.shield" color:[UIColor systemBlueColor]];
    [card addSubview:chip];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Jailbreak Detection Bypass";
    title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    title.textColor = [UIColor labelColor];
    title.numberOfLines = 0;
    [card addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"Bypass app checks that block jailbroken devices";
    subtitle.font = [UIFont systemFontOfSize:13];
    subtitle.textColor = [UIColor secondaryLabelColor];
    subtitle.numberOfLines = 0;
    [card addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [chip.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [chip.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [title.leadingAnchor constraintEqualToAnchor:chip.trailingAnchor constant:12],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [title.centerYAnchor constraintEqualToAnchor:chip.centerYAnchor],
        [subtitle.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [subtitle.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [subtitle.topAnchor constraintEqualToAnchor:chip.bottomAnchor constant:12],
        [subtitle.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
    ]];
    return card;
}

- (UIView *)cardContainer {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    } else {
        card.backgroundColor = [UIColor whiteColor];
    }
    card.layer.cornerRadius = 16;
    card.clipsToBounds = YES;
    return card;
}

- (UIStackView *)innerStackIn:(UIView *)card {
    UIStackView *inner = [[UIStackView alloc] init];
    inner.axis = UILayoutConstraintAxisVertical;
    inner.spacing = 0;
    inner.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:inner];
    [NSLayoutConstraint activateConstraints:@[
        [inner.topAnchor constraintEqualToAnchor:card.topAnchor],
        [inner.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [inner.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [inner.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
    ]];
    return inner;
}

- (UILabel *)sectionHeader:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    label.textColor = [UIColor secondaryLabelColor];
    return label;
}

- (UILabel *)noteLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [UIFont systemFontOfSize:12];
    label.textColor = [UIColor secondaryLabelColor];
    label.numberOfLines = 0;
    return label;
}

- (UIView *)mainToggleRow {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Jailbreak Detection Bypass";
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    title.textColor = [UIColor labelColor];
    title.numberOfLines = 0;
    [row addSubview:title];

    self.mainSwitch = [[UISwitch alloc] init];
    self.mainSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainSwitch.onTintColor = [UIColor systemBlueColor];
    [self.mainSwitch setOn:[self.securitySettings boolForKey:@"jailbreakDetectionEnabled"] animated:NO];
    [self.mainSwitch addTarget:self action:@selector(mainToggleChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:self.mainSwitch];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:64],
        [title.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [title.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [self.mainSwitch.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [self.mainSwitch.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:self.mainSwitch.leadingAnchor constant:-12],
    ]];
    return row;
}

#pragma mark - Actions

- (void)mainToggleChanged:(UISwitch *)sender {
    BOOL enabled = sender.isOn;

    // 1) Persist to the security settings plist (source of truth)
    NSString *securitySettingsPath = @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist";
    NSMutableDictionary *settingsDict = [NSMutableDictionary dictionaryWithContentsOfFile:securitySettingsPath] ?: [NSMutableDictionary dictionary];
    settingsDict[@"jailbreakDetectionEnabled"] = @(enabled);
    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:settingsDict
                                                                  format:NSPropertyListXMLFormat_v1_0
                                                                 options:0
                                                                   error:nil];
    if (plistData) {
        [plistData writeToFile:securitySettingsPath atomically:YES];
    }

    // 2) Update NSUserDefaults suites
    NSArray *suiteNames = @[
        @"com.weaponx.securitySettings",
        @"com.hydra.projectx.SecuritySettings",
        @"com.hydra.projectx"
    ];
    for (NSString *suiteName in suiteNames) {
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
        [defaults setBool:enabled forKey:@"jailbreakDetectionEnabled"];
        [defaults synchronize];
    }
    [self.securitySettings setBool:enabled forKey:@"jailbreakDetectionEnabled"];
    [self.securitySettings synchronize];

    // 3) Notify tweaks/processes
    CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
    if (darwinCenter) {
        CFNotificationCenterPostNotification(darwinCenter,
                                            CFSTR("com.hydra.projectx.settings.changed"),
                                            NULL,
                                            NULL,
                                            YES);
        CFNotificationCenterPostNotification(darwinCenter,
                                            CFSTR("com.hydra.projectx.jailbreakBypassChanged"),
                                            NULL,
                                            NULL,
                                            YES);
    }

    // 4) User feedback
    NSString *message = enabled ? @"Jailbreak Detection Bypass Enabled" : @"Jailbreak Detection Bypass Disabled";
    [self showToast:message];

    // 5) Haptic feedback
    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [generator prepare];
    [generator impactOccurred];
}

#pragma mark - Toast

- (void)showToast:(NSString *)message {
    UILabel *toast = [[UILabel alloc] init];
    toast.translatesAutoresizingMaskIntoConstraints = NO;
    toast.text = message;
    toast.textColor = [UIColor whiteColor];
    toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    toast.numberOfLines = 0;
    toast.layer.cornerRadius = 12;
    toast.clipsToBounds = YES;
    toast.alpha = 0.0;
    [self.view addSubview:toast];
    [NSLayoutConstraint activateConstraints:@[
        [toast.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [toast.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-32],
        [toast.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:32],
        [toast.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-32],
        [toast.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];
    [UIView animateWithDuration:0.25 animations:^{
        toast.alpha = 1.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.25 delay:1.6 options:0 animations:^{
            toast.alpha = 0.0;
        } completion:^(BOOL finished2) {
            [toast removeFromSuperview];
        }];
    }];
}

@end
