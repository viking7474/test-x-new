#import "CanvasDetailViewController.h"
#import "TLinkIOSLogging.h"
#import "IdentifierManager.h"
#import <notify.h>

@interface CanvasDetailViewController ()
@property (nonatomic, strong) NSUserDefaults *securitySettings;
@property (nonatomic, strong) UISwitch *mainSwitch;
@property (nonatomic, strong) UIButton *resetButton;
@end

@implementation CanvasDetailViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.securitySettings = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Canvas Fingerprinting";
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

    // ACTIONS section
    [stack addArrangedSubview:[self sectionHeader:@"ACTIONS"]];
    UIView *actionsCard = [self cardContainer];
    UIStackView *actionsInner = [self innerStackIn:actionsCard];
    [actionsInner addArrangedSubview:[self resetRow]];
    [stack addArrangedSubview:actionsCard];

    // Info note
    [stack addArrangedSubview:[self noteLabel:@"Canvas fingerprinting is a tracking technique that allows websites to identify your device by generating unique images. This protection adds subtle noise to canvas operations to prevent tracking while maintaining normal website functionality."]];

    [self refreshResetButtonState];
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
    UIView *chip = [self iconChip:@"paintbrush.pointed" color:[UIColor systemPurpleColor]];
    [card addSubview:chip];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Canvas Fingerprinting";
    title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    title.textColor = [UIColor labelColor];
    [card addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"Prevent browser fingerprinting through canvas operations";
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

- (UIView *)hairline {
    UIView *line = [[UIView alloc] init];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    line.backgroundColor = [UIColor separatorColor];
    [line.heightAnchor constraintEqualToConstant:0.5].active = YES;
    return line;
}

- (UIView *)mainToggleRow {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Canvas Fingerprint Protection";
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    title.textColor = [UIColor labelColor];
    title.numberOfLines = 0;
    [row addSubview:title];

    self.mainSwitch = [[UISwitch alloc] init];
    self.mainSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainSwitch.onTintColor = [UIColor systemBlueColor];
    [self.mainSwitch setOn:[self loadCanvasEnabled] animated:NO];
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

- (UIView *)resetRow {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    self.resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.resetButton.tintColor = [UIColor systemBlueColor];
    self.resetButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.resetButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    if (@available(iOS 13.0, *)) {
        UIImage *resetImage = [UIImage systemImageNamed:@"arrow.counterclockwise"];
        [self.resetButton setImage:resetImage forState:UIControlStateNormal];
    }
    [self.resetButton setTitle:@"  Reset Noise Patterns" forState:UIControlStateNormal];
    [self.resetButton addTarget:self action:@selector(resetTapped:) forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:self.resetButton];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:60],
        [self.resetButton.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [self.resetButton.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [self.resetButton.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    return row;
}

#pragma mark - State

- (BOOL)loadCanvasEnabled {
    // Replicates SecurityTab multi-source load, source of truth first.
    BOOL toggleEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"canvasFingerprintingEnabled"];
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"canvasFingerprintingEnabled"]) {
        toggleEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"CanvasFingerprint"];
    }
    if (![self.securitySettings objectForKey:@"canvasFingerprintingEnabled"] &&
        ![self.securitySettings objectForKey:@"CanvasFingerprint"]) {
        toggleEnabled = [self.securitySettings boolForKey:@"canvasFingerprintingEnabled"] ||
                        [self.securitySettings boolForKey:@"CanvasFingerprint"];
    }
    if (!toggleEnabled) {
        NSString *securitySettingsPath = @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist";
        NSDictionary *settingsDict = [NSDictionary dictionaryWithContentsOfFile:securitySettingsPath];
        if (settingsDict) {
            toggleEnabled = [settingsDict[@"canvasFingerprintingEnabled"] boolValue] ||
                            [settingsDict[@"CanvasFingerprint"] boolValue];
        }
    }
    Class identifierManagerClass = NSClassFromString(@"IdentifierManager");
    if (identifierManagerClass) {
        id manager = [identifierManagerClass sharedManager];
        if ([manager respondsToSelector:@selector(isCanvasFingerprintProtectionEnabled)]) {
            toggleEnabled = [manager isCanvasFingerprintProtectionEnabled];
        }
    }
    return toggleEnabled;
}

- (void)refreshResetButtonState {
    BOOL enabled = self.mainSwitch.isOn;
    self.resetButton.enabled = enabled;
    self.resetButton.alpha = enabled ? 1.0 : 0.5;
}

#pragma mark - Actions

- (void)mainToggleChanged:(UISwitch *)sender {
    BOOL enabled = sender.isOn;

    // ONLY update the plist file - THE SINGLE SOURCE OF TRUTH
    NSString *securitySettingsPath = @"/var/mobile/Library/Preferences/com.weaponx.securitySettings.plist";
    NSMutableDictionary *settingsDict = [NSMutableDictionary dictionaryWithContentsOfFile:securitySettingsPath] ?: [NSMutableDictionary dictionary];
    settingsDict[@"canvasFingerprintingEnabled"] = @(enabled);
    settingsDict[@"CanvasFingerprint"] = @(enabled); // old key compatibility

    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:settingsDict
                                                                  format:NSPropertyListXMLFormat_v1_0
                                                                 options:0
                                                                   error:nil];
    if (plistData) {
        [plistData writeToFile:securitySettingsPath atomically:YES];
    }

    // Also mirror into the suite defaults for consistency
    [self.securitySettings setBool:enabled forKey:@"canvasFingerprintingEnabled"];
    [self.securitySettings setBool:enabled forKey:@"CanvasFingerprint"];
    [self.securitySettings synchronize];

    // Call IdentifierManager to handle the toggle
    Class identifierManagerClass = NSClassFromString(@"IdentifierManager");
    if (identifierManagerClass) {
        id manager = [identifierManagerClass sharedManager];
        if ([manager respondsToSelector:@selector(setCanvasFingerprintProtection:)]) {
            [manager setCanvasFingerprintProtection:enabled];
        }
    }

    // Update reset button availability
    [self refreshResetButtonState];

    // NSNotification with enhanced information
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:@(enabled) forKey:@"enabled"];
    [userInfo setObject:@"SecurityTabView" forKey:@"sender"];
    [userInfo setObject:[NSDate date] forKey:@"timestamp"];
    [userInfo setObject:@YES forKey:@"forceReload"];
    [userInfo setObject:securitySettingsPath forKey:@"settingsPath"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"com.hydra.tlinkios.toggleCanvasFingerprintProtection"
                                                            object:nil
                                                          userInfo:userInfo];
    });

    // Darwin notifications for system-wide changes
    CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
    if (enabled) {
        CFNotificationCenterPostNotification(darwinCenter, CFSTR("com.hydra.tlinkios.enableCanvasFingerprintProtection"), NULL, NULL, YES);
        CFNotificationCenterPostNotification(darwinCenter, CFSTR("com.hydra.tlinkios.canvasFingerprintToggleChanged"), NULL, NULL, YES);
        CFNotificationCenterPostNotification(darwinCenter, CFSTR("com.hydra.tlinkios.toggleCanvasFingerprint"), NULL, NULL, YES);
    } else {
        CFNotificationCenterPostNotification(darwinCenter, CFSTR("com.hydra.tlinkios.disableCanvasFingerprintProtection"), NULL, NULL, YES);
        CFNotificationCenterPostNotification(darwinCenter, CFSTR("com.hydra.tlinkios.canvasFingerprintToggleChanged"), NULL, NULL, YES);
        CFNotificationCenterPostNotification(darwinCenter, CFSTR("com.hydra.tlinkios.toggleCanvasFingerprint"), NULL, NULL, YES);
    }

    NSString *resetCmd = enabled ? @"ON" : @"OFF";
    notify_post([@"com.hydra.tlinkios.resetCanvasFingerprint." stringByAppendingString:resetCmd].UTF8String);

    NSString *message = enabled ? @"Canvas Fingerprinting Protection Enabled" : @"Canvas Fingerprinting Protection Disabled";
    [self showToast:message];

    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [generator prepare];
    [generator impactOccurred];
}

- (void)resetTapped:(UIButton *)sender {
    UIColor *originalColor = sender.backgroundColor;
    UIColor *originalTintColor = sender.tintColor;
    [UIView animateWithDuration:0.1 animations:^{
        sender.backgroundColor = [UIColor systemBlueColor];
        sender.tintColor = [UIColor whiteColor];
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2 animations:^{
            sender.backgroundColor = originalColor;
            sender.tintColor = originalTintColor;
        }];
    }];

    Class identifierManagerClass = NSClassFromString(@"IdentifierManager");
    if (identifierManagerClass) {
        id manager = [identifierManagerClass sharedManager];
        if ([manager respondsToSelector:@selector(resetCanvasNoise)]) {
            [manager resetCanvasNoise];
            [self showToast:@"Canvas Fingerprint Noise Patterns Reset"];
            UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [generator prepare];
            [generator impactOccurred];
        }
    }
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
    CGFloat pad = 16.0;
    toast.layoutMargins = UIEdgeInsetsMake(0, pad, 0, pad);
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
