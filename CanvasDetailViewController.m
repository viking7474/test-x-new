#import "CanvasDetailViewController.h"
#import "TLinkIOSLogging.h"
#import "IdentifierManager.h"
#import "PXPaths.h"
#import <notify.h>
#import <math.h>
#import <math.h>

@interface CanvasDetailViewController ()
@property (nonatomic, strong) NSUserDefaults *securitySettings;
@property (nonatomic, strong) UISwitch *mainSwitch;
@property (nonatomic, strong) UISlider *noiseSlider;
@property (nonatomic, strong) UILabel *noiseValueLabel;
@property (nonatomic, strong) UISwitch *webKitSwitch;
@property (nonatomic, strong) UISwitch *nativeSwitch;
@property (nonatomic, strong) UISwitch *stableSeedSwitch;
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
    self.title = @"Canvas";
    self.view.backgroundColor = [self groupedBackgroundColor];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.layoutMargins = UIEdgeInsetsMake(16, 16, 28, 16);
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

    [stack addArrangedSubview:[self buildHero]];

    [stack addArrangedSubview:[self sectionHeader:@"STATUS"]];
    UIView *statusCard = [self cardContainer];
    [[self innerStackIn:statusCard] addArrangedSubview:[self mainToggleRow]];
    [stack addArrangedSubview:statusCard];

    [stack addArrangedSubview:[self sectionHeader:@"NOISE LEVEL"]];
    UIView *noiseCard = [self cardContainer];
    [[self innerStackIn:noiseCard] addArrangedSubview:[self noiseLevelRow]];
    [stack addArrangedSubview:noiseCard];

    [stack addArrangedSubview:[self sectionHeader:@"SCOPE"]];
    UIView *scopeCard = [self cardContainer];
    UIStackView *scopeStack = [self innerStackIn:scopeCard];

    self.webKitSwitch = [self configuredSwitchWithSelector:@selector(webKitScopeChanged:)];
    [scopeStack addArrangedSubview:[self switchRowWithTitle:@"WebKit / Canvas APIs"
                                                     subtitle:@"Protect canvas, WebGL and related web fingerprint surfaces"
                                                       toggle:self.webKitSwitch]];
    [scopeStack addArrangedSubview:[self hairline]];

    self.nativeSwitch = [self configuredSwitchWithSelector:@selector(nativeScopeChanged:)];
    [scopeStack addArrangedSubview:[self switchRowWithTitle:@"Native Canvas Bridge"
                                                     subtitle:@"Also perturb WKNativeCanvas drawing data when available"
                                                       toggle:self.nativeSwitch]];
    [scopeStack addArrangedSubview:[self hairline]];

    self.stableSeedSwitch = [self configuredSwitchWithSelector:@selector(stableSeedChanged:)];
    [scopeStack addArrangedSubview:[self switchRowWithTitle:@"Stable Noise Seed"
                                                     subtitle:@"Keep noise stable until Reset Noise is used"
                                                       toggle:self.stableSeedSwitch]];
    [stack addArrangedSubview:scopeCard];

    [stack addArrangedSubview:[self sectionHeader:@"ACTIONS"]];
    UIView *actionsCard = [self cardContainer];
    [[self innerStackIn:actionsCard] addArrangedSubview:[self resetRow]];
    [stack addArrangedSubview:actionsCard];

    [stack addArrangedSubview:[self noteLabel:
        @"Canvas protection uses deterministic, low-amplitude perturbations to reduce fingerprint stability. "
         "Noise Level controls pixel perturbation strength. Scope settings can be prepared even while the master switch is off."]];

    [self reloadCanvasControls];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.isViewLoaded) {
        [self reloadCanvasControls];
    }
}

#pragma mark - Compatibility colors

- (UIColor *)groupedBackgroundColor {
    if (@available(iOS 13.0, *)) return [UIColor systemGroupedBackgroundColor];
    return [UIColor groupTableViewBackgroundColor];
}

- (UIColor *)cardBackgroundColor {
    if (@available(iOS 13.0, *)) return [UIColor secondarySystemGroupedBackgroundColor];
    return [UIColor whiteColor];
}

- (UIColor *)primaryTextColor {
    if (@available(iOS 13.0, *)) return [UIColor labelColor];
    return [UIColor blackColor];
}

- (UIColor *)secondaryTextColor {
    if (@available(iOS 13.0, *)) return [UIColor secondaryLabelColor];
    return [UIColor darkGrayColor];
}

- (UIColor *)separatorLineColor {
    if (@available(iOS 13.0, *)) return [UIColor separatorColor];
    return [UIColor colorWithWhite:0.82 alpha:1.0];
}

- (UIColor *)canvasAccentColor {
    if (@available(iOS 13.0, *)) return [UIColor systemPurpleColor];
    return [UIColor purpleColor];
}

#pragma mark - Building blocks

- (UIView *)iconChip:(NSString *)symbolName color:(UIColor *)color {
    UIView *chip = [[UIView alloc] init];
    chip.translatesAutoresizingMaskIntoConstraints = NO;
    chip.backgroundColor = [color colorWithAlphaComponent:0.15];
    chip.layer.cornerRadius = 7;

    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.tintColor = color;
    if (@available(iOS 13.0, *)) {
        imageView.image = [[UIImage systemImageNamed:symbolName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [chip addSubview:imageView];

    [NSLayoutConstraint activateConstraints:@[
        [chip.widthAnchor constraintEqualToConstant:30],
        [chip.heightAnchor constraintEqualToConstant:30],
        [imageView.centerXAnchor constraintEqualToAnchor:chip.centerXAnchor],
        [imageView.centerYAnchor constraintEqualToAnchor:chip.centerYAnchor],
        [imageView.widthAnchor constraintEqualToConstant:17],
        [imageView.heightAnchor constraintEqualToConstant:17],
    ]];
    return chip;
}

- (UIView *)buildHero {
    UIView *card = [self cardContainer];
    UIView *chip = [self iconChip:@"paintbrush.pointed" color:[self canvasAccentColor]];
    [card addSubview:chip];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Canvas Fingerprint Protection";
    title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    title.textColor = [self primaryTextColor];
    title.numberOfLines = 0;
    [card addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"Control deterministic Canvas noise and protection scope";
    subtitle.font = [UIFont systemFontOfSize:13];
    subtitle.textColor = [self secondaryTextColor];
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
    card.backgroundColor = [self cardBackgroundColor];
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
    label.textColor = [self secondaryTextColor];
    return label;
}

- (UILabel *)noteLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [UIFont systemFontOfSize:12];
    label.textColor = [self secondaryTextColor];
    label.numberOfLines = 0;
    return label;
}

- (UIView *)hairline {
    UIView *line = [[UIView alloc] init];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    line.backgroundColor = [self separatorLineColor];
    [line.heightAnchor constraintEqualToConstant:0.5].active = YES;
    return line;
}

- (UISwitch *)configuredSwitchWithSelector:(SEL)selector {
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.onTintColor = [UIColor systemBlueColor];
    [toggle addTarget:self action:selector forControlEvents:UIControlEventValueChanged];
    return toggle;
}

- (UIView *)mainToggleRow {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *chip = [self iconChip:@"paintbrush.pointed" color:[self canvasAccentColor]];
    [row addSubview:chip];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Enable Canvas Noise";
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    title.textColor = [self primaryTextColor];
    [row addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"toDataURL · getImageData · WebGL";
    subtitle.font = [UIFont systemFontOfSize:12];
    subtitle.textColor = [self secondaryTextColor];
    [row addSubview:subtitle];

    self.mainSwitch = [self configuredSwitchWithSelector:@selector(mainToggleChanged:)];
    [row addSubview:self.mainSwitch];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:72],
        [chip.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [chip.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [title.leadingAnchor constraintEqualToAnchor:chip.trailingAnchor constant:12],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:self.mainSwitch.leadingAnchor constant:-12],
        [title.topAnchor constraintEqualToAnchor:row.topAnchor constant:15],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:self.mainSwitch.leadingAnchor constant:-12],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4],
        [self.mainSwitch.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [self.mainSwitch.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    return row;
}

- (UIView *)noiseLevelRow {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Noise level";
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    title.textColor = [self primaryTextColor];
    [row addSubview:title];

    self.noiseValueLabel = [[UILabel alloc] init];
    self.noiseValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.noiseValueLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    self.noiseValueLabel.textColor = [UIColor systemBlueColor];
    self.noiseValueLabel.textAlignment = NSTextAlignmentRight;
    [row addSubview:self.noiseValueLabel];

    self.noiseSlider = [[UISlider alloc] init];
    self.noiseSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.noiseSlider.minimumValue = 0.0f;
    self.noiseSlider.maximumValue = 3.0f;
    self.noiseSlider.continuous = YES;
    [self.noiseSlider addTarget:self action:@selector(noiseSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.noiseSlider addTarget:self action:@selector(noiseSliderCommit:) forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel)];
    [row addSubview:self.noiseSlider];

    UIStackView *ticks = [[UIStackView alloc] init];
    ticks.translatesAutoresizingMaskIntoConstraints = NO;
    ticks.axis = UILayoutConstraintAxisHorizontal;
    ticks.distribution = UIStackViewDistributionEqualSpacing;
    for (NSString *text in @[@"Off", @"Low", @"Med", @"High"]) {
        UILabel *tick = [[UILabel alloc] init];
        tick.text = text;
        tick.font = [UIFont systemFontOfSize:10];
        tick.textColor = [self secondaryTextColor];
        [ticks addArrangedSubview:tick];
    }
    [row addSubview:ticks];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:116],
        [title.topAnchor constraintEqualToAnchor:row.topAnchor constant:16],
        [title.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [self.noiseValueLabel.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [self.noiseValueLabel.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:self.noiseValueLabel.leadingAnchor constant:-12],
        [self.noiseSlider.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:16],
        [self.noiseSlider.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [self.noiseSlider.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [ticks.topAnchor constraintEqualToAnchor:self.noiseSlider.bottomAnchor constant:4],
        [ticks.leadingAnchor constraintEqualToAnchor:self.noiseSlider.leadingAnchor],
        [ticks.trailingAnchor constraintEqualToAnchor:self.noiseSlider.trailingAnchor],
        [ticks.bottomAnchor constraintLessThanOrEqualToAnchor:row.bottomAnchor constant:-12],
    ]];
    return row;
}

- (UIView *)switchRowWithTitle:(NSString *)titleText subtitle:(NSString *)subtitleText toggle:(UISwitch *)toggle {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = titleText;
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    title.textColor = [self primaryTextColor];
    title.numberOfLines = 0;
    [row addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = subtitleText;
    subtitle.font = [UIFont systemFontOfSize:12];
    subtitle.textColor = [self secondaryTextColor];
    subtitle.numberOfLines = 0;
    [row addSubview:subtitle];

    [row addSubview:toggle];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:74],
        [title.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:toggle.leadingAnchor constant:-12],
        [title.topAnchor constraintEqualToAnchor:row.topAnchor constant:14],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:toggle.leadingAnchor constant:-12],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4],
        [subtitle.bottomAnchor constraintLessThanOrEqualToAnchor:row.bottomAnchor constant:-12],
        [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
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
        [self.resetButton setImage:[UIImage systemImageNamed:@"arrow.counterclockwise"] forState:UIControlStateNormal];
        [self.resetButton setTitle:@"  Reset Noise" forState:UIControlStateNormal];
    } else {
        [self.resetButton setTitle:@"↻  Reset Noise" forState:UIControlStateNormal];
    }
    [self.resetButton addTarget:self action:@selector(resetTapped:) forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:self.resetButton];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"Rotate the seed; WebKit applies it on the next document load";
    subtitle.font = [UIFont systemFontOfSize:12];
    subtitle.textColor = [self secondaryTextColor];
    [row addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:72],
        [self.resetButton.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [self.resetButton.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [self.resetButton.topAnchor constraintEqualToAnchor:row.topAnchor constant:10],
        [subtitle.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [subtitle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [subtitle.topAnchor constraintEqualToAnchor:self.resetButton.bottomAnchor constant:1],
        [subtitle.bottomAnchor constraintLessThanOrEqualToAnchor:row.bottomAnchor constant:-10],
    ]];
    return row;
}

#pragma mark - Settings

- (NSDictionary *)canvasSettingsDictionary {
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:PXSecuritySettingsPath()];
    return settings ?: @{};
}

- (id)canvasValueForKey:(NSString *)key defaultValue:(id)defaultValue {
    id diskValue = [self canvasSettingsDictionary][key];
    if (diskValue) return diskValue;
    id suiteValue = [self.securitySettings objectForKey:key];
    return suiteValue ?: defaultValue;
}

- (BOOL)persistCanvasValues:(NSDictionary<NSString *, id> *)values {
    if (values.count == 0) return YES;

    NSString *settingsPath = PXSecuritySettingsPath();
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:settingsPath] ?: [NSMutableDictionary dictionary];
    [settings addEntriesFromDictionary:values];
    BOOL success = [settings writeToFile:settingsPath atomically:YES];
    if (!success) {
        PXLog(@"[CanvasDetail] Failed to persist Canvas settings at %@", settingsPath);
        return NO;
    }

    [values enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        [self.securitySettings setObject:value forKey:key];
    }];
    [self.securitySettings synchronize];
    PXPostSettingsChangedNotification();
    return YES;
}

- (BOOL)loadCanvasEnabled {
    Class managerClass = NSClassFromString(@"IdentifierManager");
    if (managerClass) {
        id manager = [managerClass sharedManager];
        if ([manager respondsToSelector:@selector(isCanvasFingerprintProtectionEnabled)]) {
            return [manager isCanvasFingerprintProtectionEnabled];
        }
    }

    NSDictionary *settings = [self canvasSettingsDictionary];
    id primary = settings[@"canvasFingerprintingEnabled"];
    if (primary) return [primary boolValue];
    id legacy = settings[@"CanvasFingerprint"];
    if (legacy) return [legacy boolValue];

    primary = [self.securitySettings objectForKey:@"canvasFingerprintingEnabled"];
    if (primary) return [primary boolValue];
    legacy = [self.securitySettings objectForKey:@"CanvasFingerprint"];
    return legacy ? [legacy boolValue] : NO;
}

- (NSInteger)currentNoiseLevel {
    NSInteger value = [[self canvasValueForKey:@"canvasNoiseLevel" defaultValue:@1] integerValue];
    return MAX(0, MIN(3, value));
}

- (BOOL)boolSetting:(NSString *)key defaultValue:(BOOL)defaultValue {
    return [[self canvasValueForKey:key defaultValue:@(defaultValue)] boolValue];
}

- (NSString *)noiseLevelName:(NSInteger)level {
    switch (MAX(0, MIN(3, level))) {
        case 0: return @"Off";
        case 1: return @"Low";
        case 2: return @"Med";
        case 3: return @"High";
        default: return @"Low";
    }
}

- (void)reloadCanvasControls {
    BOOL enabled = [self loadCanvasEnabled];
    [self.mainSwitch setOn:enabled animated:NO];

    NSInteger level = [self currentNoiseLevel];
    self.noiseSlider.value = (float)level;
    self.noiseValueLabel.text = [self noiseLevelName:level];

    [self.webKitSwitch setOn:[self boolSetting:@"canvasWebKitNoiseEnabled" defaultValue:YES] animated:NO];
    [self.nativeSwitch setOn:[self boolSetting:@"canvasNativeNoiseEnabled" defaultValue:NO] animated:NO];
    [self.stableSeedSwitch setOn:[self boolSetting:@"canvasStableSeedEnabled" defaultValue:YES] animated:NO];

    [self refreshResetButtonState];
}

- (void)refreshResetButtonState {
    BOOL enabled = self.mainSwitch.isOn;
    self.resetButton.enabled = enabled;
    self.resetButton.alpha = enabled ? 1.0 : 0.45;
}

#pragma mark - Actions

- (void)mainToggleChanged:(UISwitch *)sender {
    BOOL enabled = sender.isOn;
    BOOL success = NO;
    BOOL managerHandledPersistence = NO;

    Class managerClass = NSClassFromString(@"IdentifierManager");
    if (managerClass) {
        id manager = [managerClass sharedManager];
        if ([manager respondsToSelector:@selector(setCanvasFingerprintProtection:)]) {
            managerHandledPersistence = YES;
            success = [manager setCanvasFingerprintProtection:enabled];
        }
    }
    if (!managerHandledPersistence) {
        success = [self persistCanvasValues:@{
            @"canvasFingerprintingEnabled": @(enabled),
            @"CanvasFingerprint": @(enabled)
        }];
    }

    if (!success) {
        [sender setOn:!enabled animated:YES];
        [self refreshResetButtonState];
        [self showToast:@"Could not save Canvas protection setting"];
        return;
    }

    [self refreshResetButtonState];

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[@"enabled"] = @(enabled);
    userInfo[@"sender"] = @"CanvasDetailView";
    userInfo[@"timestamp"] = [NSDate date];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.hydra.tlinkios.toggleCanvasFingerprintProtection"
                                                        object:nil
                                                      userInfo:userInfo];

    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(center,
                                         enabled ? CFSTR("com.hydra.tlinkios.enableCanvasFingerprintProtection")
                                                 : CFSTR("com.hydra.tlinkios.disableCanvasFingerprintProtection"),
                                         NULL, NULL, YES);
    CFNotificationCenterPostNotification(center, CFSTR("com.hydra.tlinkios.canvasFingerprintToggleChanged"), NULL, NULL, YES);
    CFNotificationCenterPostNotification(center, CFSTR("com.hydra.tlinkios.toggleCanvasFingerprint"), NULL, NULL, YES);

    NSString *resetCmd = enabled ? @"ON" : @"OFF";
    notify_post([@"com.hydra.tlinkios.resetCanvasFingerprint." stringByAppendingString:resetCmd].UTF8String);

    [self showToast:enabled ? @"Canvas Protection Enabled" : @"Canvas Protection Disabled"];
    [self performHapticFeedback];
}

- (void)noiseSliderValueChanged:(UISlider *)sender {
    NSInteger level = (NSInteger)lroundf(sender.value);
    self.noiseValueLabel.text = [self noiseLevelName:level];

    // VoiceOver/keyboard value changes may not emit touch-up events. Persist
    // immediately when the slider is not actively being dragged by touch.
    if (!sender.tracking) {
        [self noiseSliderCommit:sender];
    }
}

- (void)noiseSliderCommit:(UISlider *)sender {
    NSInteger oldLevel = [self currentNoiseLevel];
    NSInteger newLevel = MAX(0, MIN(3, (NSInteger)lroundf(sender.value)));
    sender.value = (float)newLevel;
    self.noiseValueLabel.text = [self noiseLevelName:newLevel];
    if (newLevel == oldLevel) return;

    if (![self persistCanvasValues:@{@"canvasNoiseLevel": @(newLevel)}]) {
        sender.value = (float)oldLevel;
        self.noiseValueLabel.text = [self noiseLevelName:oldLevel];
        [self showToast:@"Could not save Canvas noise level"];
        return;
    }

    [self showToast:[NSString stringWithFormat:@"Canvas Noise: %@", [self noiseLevelName:newLevel]]];
    [self performHapticFeedback];
}

- (void)webKitScopeChanged:(UISwitch *)sender {
    [self persistSwitch:sender key:@"canvasWebKitNoiseEnabled" successMessage:@"WebKit Canvas scope updated"];
}

- (void)nativeScopeChanged:(UISwitch *)sender {
    [self persistSwitch:sender key:@"canvasNativeNoiseEnabled" successMessage:@"Native Canvas scope updated"];
}

- (void)stableSeedChanged:(UISwitch *)sender {
    [self persistSwitch:sender key:@"canvasStableSeedEnabled" successMessage:@"Canvas seed mode updated"];
}

- (void)persistSwitch:(UISwitch *)sender key:(NSString *)key successMessage:(NSString *)message {
    BOOL newValue = sender.isOn;
    if (![self persistCanvasValues:@{key: @(newValue)}]) {
        [sender setOn:!newValue animated:YES];
        [self showToast:@"Could not save Canvas setting"];
        return;
    }
    [self showToast:message];
    [self performHapticFeedback];
}

- (void)resetTapped:(UIButton *)sender {
    UIColor *originalColor = sender.backgroundColor;
    UIColor *originalTint = sender.tintColor;
    [UIView animateWithDuration:0.1 animations:^{
        sender.backgroundColor = [UIColor systemBlueColor];
        sender.tintColor = [UIColor whiteColor];
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.2 animations:^{
            sender.backgroundColor = originalColor;
            sender.tintColor = originalTint;
        }];
    }];

    BOOL success = NO;
    Class managerClass = NSClassFromString(@"IdentifierManager");
    if (managerClass) {
        id manager = [managerClass sharedManager];
        if ([manager respondsToSelector:@selector(resetCanvasNoiseAndPersist)]) {
            success = [manager resetCanvasNoiseAndPersist];
        } else if ([manager respondsToSelector:@selector(resetCanvasNoise)]) {
            [manager resetCanvasNoise];
            success = YES;
        }
    }

    if (!success) {
        [self showToast:@"Could not reset Canvas noise"];
        return;
    }

    [self showToast:@"Canvas Noise Seed Reset"];
    [self performHapticFeedback];
}

- (void)performHapticFeedback {
    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [generator prepare];
    [generator impactOccurred];
}

#pragma mark - Toast

- (void)showToast:(NSString *)message {
    UILabel *toast = [[UILabel alloc] init];
    toast.translatesAutoresizingMaskIntoConstraints = NO;
    toast.text = [NSString stringWithFormat:@"  %@  ", message ?: @""];
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
        [toast.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24],
        [toast.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24],
        [toast.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];

    [UIView animateWithDuration:0.22 animations:^{
        toast.alpha = 1.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.22 delay:1.5 options:0 animations:^{
            toast.alpha = 0.0;
        } completion:^(BOOL finished2) {
            [toast removeFromSuperview];
        }];
    }];
}

@end
