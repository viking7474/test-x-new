#import "AppVersionListDetailViewController.h"
#import "AppVersionEditorViewController.h"

@interface AppVersionListDetailViewController ()
@property (nonatomic, strong) NSUserDefaults *securitySettings;
@property (nonatomic, strong) UISwitch *mainSwitch;
@property (nonatomic, strong) UIStackView *appsStack;
@property (nonatomic, strong) UIView *appsCard;
@property (nonatomic, strong) UILabel *appsSectionHeader;
@property (nonatomic, strong) UIButton *addButton;
@property (nonatomic, strong) NSArray *configuredApps;
@end

@implementation AppVersionListDetailViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.securitySettings = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"App Version";
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

    // STATUS section (master toggle)
    [stack addArrangedSubview:[self sectionHeader:@"STATUS"]];
    UIView *statusCard = [self cardContainer];
    UIStackView *statusInner = [self innerStackIn:statusCard];
    [statusInner addArrangedSubview:[self mainToggleRow]];
    [stack addArrangedSubview:statusCard];

    // Configured apps section
    self.appsSectionHeader = [self sectionHeader:@"APP \u0110\u00c3 C\u1ea4U H\u00ccNH"];
    [stack addArrangedSubview:self.appsSectionHeader];
    self.appsCard = [self cardContainer];
    self.appsStack = [self innerStackIn:self.appsCard];
    [stack addArrangedSubview:self.appsCard];

    // Add app button
    self.addButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.addButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.addButton setTitle:@"+ Th\u00eam app" forState:UIControlStateNormal];
    self.addButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [self.addButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    self.addButton.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.12];
    self.addButton.layer.cornerRadius = 12;
    [self.addButton addTarget:self action:@selector(addButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.addButton.heightAnchor constraintEqualToConstant:48].active = YES;
    [stack addArrangedSubview:self.addButton];

    // Info note
    [stack addArrangedSubview:[self noteLabel:@"Spoof s\u1ed1 phi\u00ean b\u1ea3n (CFBundleShortVersionString) ri\u00eang cho t\u1eebng app trong danh s\u00e1ch scope. Ch\u1ea1m m\u1ed9t app \u0111\u1ec3 ch\u1ec9nh phi\u00ean b\u1ea3n."]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadApps];
    [self updateEnabledState];
}

#pragma mark - Data

- (void)reloadApps {
    self.configuredApps = [self loadConfiguredApps];
    [self rebuildAppRows];
}

- (NSArray *)loadConfiguredApps {
    NSString *prefsPath = @"/var/mobile/Library/Preferences";
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:prefsPath]) {
        prefsPath = @"/private/var/mobile/Library/Preferences";
        if (![fm fileExistsAtPath:prefsPath]) {
            prefsPath = @"/var/mobile/Library/Preferences";
        }
    }
    NSString *scopedAppsFile = [prefsPath stringByAppendingPathComponent:@"com.hydra.tlinkios.global_scope.plist"];
    NSString *versionSpoofFile = [prefsPath stringByAppendingPathComponent:@"com.hydra.tlinkios.version_spoof.plist"];
    NSDictionary *scopedAppsDict = [NSDictionary dictionaryWithContentsOfFile:scopedAppsFile];
    NSDictionary *savedApps = scopedAppsDict[@"ScopedApps"];
    NSDictionary *versionSpoofDict = [NSDictionary dictionaryWithContentsOfFile:versionSpoofFile];
    NSDictionary *spoofedVersions = versionSpoofDict[@"SpoofedVersions"];

    NSMutableArray *result = [NSMutableArray array];
    if ([savedApps isKindOfClass:[NSDictionary class]]) {
        NSArray *sortedKeys = [savedApps.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
        for (NSString *bundleID in sortedKeys) {
            NSDictionary *appInfo = savedApps[bundleID];
            if (![appInfo isKindOfClass:[NSDictionary class]]) { continue; }
            NSString *name = appInfo[@"name"] ?: bundleID;
            NSString *version = nil;
            BOOL enabled = NO;
            NSDictionary *spoofInfo = spoofedVersions[bundleID];
            if ([spoofInfo isKindOfClass:[NSDictionary class]]) {
                version = spoofInfo[@"spoofedVersion"];
                enabled = [spoofInfo[@"spoofingEnabled"] boolValue];
            }
            [result addObject:@{ @"name": name, @"bundleID": bundleID, @"version": version ?: @"", @"enabled": @(enabled) }];
        }
    }
    return result;
}

- (void)rebuildAppRows {
    for (UIView *v in self.appsStack.arrangedSubviews) {
        [self.appsStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    if (self.configuredApps.count == 0) {
        UILabel *empty = [[UILabel alloc] init];
        empty.translatesAutoresizingMaskIntoConstraints = NO;
        empty.text = @"Ch\u01b0a c\u00f3 app n\u00e0o \u0111\u01b0\u1ee3c c\u1ea5u h\u00ecnh";
        empty.font = [UIFont systemFontOfSize:15];
        empty.textColor = [UIColor secondaryLabelColor];
        empty.textAlignment = NSTextAlignmentCenter;
        UIView *row = [[UIView alloc] init];
        row.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:empty];
        [NSLayoutConstraint activateConstraints:@[
            [row.heightAnchor constraintGreaterThanOrEqualToConstant:60],
            [empty.centerXAnchor constraintEqualToAnchor:row.centerXAnchor],
            [empty.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [empty.leadingAnchor constraintGreaterThanOrEqualToAnchor:row.leadingAnchor constant:16],
            [empty.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor constant:-16],
        ]];
        [self.appsStack addArrangedSubview:row];
        return;
    }
    NSInteger idx = 0;
    for (NSDictionary *app in self.configuredApps) {
        UIView *row = [self appRowForApp:app showSeparator:(idx > 0)];
        row.tag = idx;
        [self.appsStack addArrangedSubview:row];
        idx++;
    }
}

- (UIView *)appRowForApp:(NSDictionary *)app showSeparator:(BOOL)showSeparator {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    if (showSeparator) {
        UIView *sep = [[UIView alloc] init];
        sep.translatesAutoresizingMaskIntoConstraints = NO;
        sep.backgroundColor = [UIColor separatorColor];
        [row addSubview:sep];
        [NSLayoutConstraint activateConstraints:@[
            [sep.topAnchor constraintEqualToAnchor:row.topAnchor],
            [sep.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
            [sep.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
            [sep.heightAnchor constraintEqualToConstant:0.5],
        ]];
    }

    UIView *chip = [self iconChip:@"app.badge" color:[UIColor systemBlueColor]];
    [row addSubview:chip];

    UILabel *name = [[UILabel alloc] init];
    name.translatesAutoresizingMaskIntoConstraints = NO;
    name.text = app[@"name"];
    name.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    name.textColor = [UIColor labelColor];
    [row addSubview:name];

    UILabel *bundle = [[UILabel alloc] init];
    bundle.translatesAutoresizingMaskIntoConstraints = NO;
    bundle.text = app[@"bundleID"];
    bundle.font = [UIFont systemFontOfSize:12];
    bundle.textColor = [UIColor secondaryLabelColor];
    [row addSubview:bundle];

    UILabel *value = [[UILabel alloc] init];
    value.translatesAutoresizingMaskIntoConstraints = NO;
    NSString *ver = app[@"version"];
    value.text = (ver.length > 0) ? ver : @"\u2014";
    value.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    BOOL enabled = [app[@"enabled"] boolValue];
    value.textColor = enabled ? [UIColor systemGreenColor] : [UIColor secondaryLabelColor];
    [row addSubview:value];

    UIImageView *chevron = [[UIImageView alloc] init];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    chevron.tintColor = [UIColor tertiaryLabelColor];
    if (@available(iOS 13.0, *)) {
        chevron.image = [[UIImage systemImageNamed:@"chevron.right"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [row addSubview:chevron];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:64],
        [chip.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [chip.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [name.leadingAnchor constraintEqualToAnchor:chip.trailingAnchor constant:12],
        [name.topAnchor constraintEqualToAnchor:row.topAnchor constant:12],
        [bundle.leadingAnchor constraintEqualToAnchor:name.leadingAnchor],
        [bundle.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:2],
        [bundle.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-12],
        [chevron.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [chevron.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [chevron.widthAnchor constraintEqualToConstant:12],
        [chevron.heightAnchor constraintEqualToConstant:16],
        [value.trailingAnchor constraintEqualToAnchor:chevron.leadingAnchor constant:-8],
        [value.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [name.trailingAnchor constraintLessThanOrEqualToAnchor:value.leadingAnchor constant:-8],
        [bundle.trailingAnchor constraintLessThanOrEqualToAnchor:value.leadingAnchor constant:-8],
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(appRowTapped:)];
    [row addGestureRecognizer:tap];
    return row;
}

- (void)updateEnabledState {
    BOOL on = [self.securitySettings boolForKey:@"appVersionSpoofingEnabled"];
    CGFloat alpha = on ? 1.0 : 0.5;
    self.appsSectionHeader.alpha = alpha;
    self.appsCard.alpha = alpha;
    self.addButton.alpha = alpha;
}

#pragma mark - Actions

- (void)mainToggleChanged:(UISwitch *)sender {
    BOOL enabled = sender.isOn;
    [self.securitySettings setBool:enabled forKey:@"appVersionSpoofingEnabled"];
    [self.securitySettings synchronize];

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:@(enabled) forKey:@"enabled"];
    [userInfo setObject:@"AppVersionListDetailView" forKey:@"sender"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"com.hydra.tlinkios.toggleAppVersionSpoofing"
                                                            object:nil
                                                          userInfo:userInfo];
    });

    [self updateEnabledState];
    [self showToast:(enabled ? @"App Version Spoof Enabled" : @"App Version Spoof Disabled")];

    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [generator prepare];
    [generator impactOccurred];
}

- (void)appRowTapped:(UITapGestureRecognizer *)recognizer {
    NSInteger i = recognizer.view.tag;
    if (i < 0 || i >= (NSInteger)self.configuredApps.count) { return; }
    NSDictionary *app = self.configuredApps[i];
    [self openEditorForBundleID:app[@"bundleID"] name:app[@"name"]];
}

- (void)addButtonTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Th\u00eam app" message:@"H\u00e3y th\u00eam app v\u00e0o Scope \u1edf tab TLinkIOS (Home). Sau \u0111\u00f3 app s\u1ebd hi\u1ec7n \u1edf \u0111\u00e2y \u0111\u1ec3 ch\u1ec9nh phi\u00ean b\u1ea3n." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openEditorForBundleID:(NSString *)bundleID name:(NSString *)name {
    if (bundleID.length == 0) { return; }
    if (![self.securitySettings boolForKey:@"appVersionSpoofingEnabled"]) {
        [self showToast:@"B\u1eadt App Version Spoof tr\u01b0\u1edbc"];
        return;
    }

    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [generator prepare];
    [generator impactOccurred];

    Class idManagerClass = NSClassFromString(@"IdentifierManager");
    if (idManagerClass && [idManagerClass respondsToSelector:@selector(sharedManager)]) {
        id idManager = [idManagerClass performSelector:@selector(sharedManager)];
        if ([idManager respondsToSelector:@selector(refreshScopedAppsInfoIfNeeded)]) {
            [idManager performSelector:@selector(refreshScopedAppsInfoIfNeeded)];
        }
    }

    AppVersionEditorViewController *editor = [[AppVersionEditorViewController alloc] initWithBundleID:bundleID appName:name];
    if (self.navigationController) {
        [self.navigationController pushViewController:editor animated:YES];
    } else {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:editor];
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:nav animated:YES completion:nil];
    }
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
    UIView *chip = [self iconChip:@"app.badge" color:[UIColor systemBlueColor]];
    [card addSubview:chip];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"App Version Spoof";
    title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    title.textColor = [UIColor labelColor];
    title.numberOfLines = 0;
    [card addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"Fake app version numbers per app";
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
    title.text = @"B\u1eadt App Version Spoof";
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    title.textColor = [UIColor labelColor];
    [row addSubview:title];

    UILabel *sub = [[UILabel alloc] init];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.text = @"CFBundleShortVersionString";
    sub.font = [UIFont systemFontOfSize:12];
    sub.textColor = [UIColor secondaryLabelColor];
    [row addSubview:sub];

    self.mainSwitch = [[UISwitch alloc] init];
    self.mainSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainSwitch.onTintColor = [UIColor systemBlueColor];
    [self.mainSwitch setOn:[self.securitySettings boolForKey:@"appVersionSpoofingEnabled"] animated:NO];
    [self.mainSwitch addTarget:self action:@selector(mainToggleChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:self.mainSwitch];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:64],
        [title.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [title.topAnchor constraintEqualToAnchor:row.topAnchor constant:12],
        [sub.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],
        [sub.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-12],
        [self.mainSwitch.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [self.mainSwitch.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:self.mainSwitch.leadingAnchor constant:-12],
        [sub.trailingAnchor constraintLessThanOrEqualToAnchor:self.mainSwitch.leadingAnchor constant:-12],
    ]];
    return row;
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
