#import "NetworkDataDetailViewController.h"
#import "common/PXUIKitCompat.h"
#import "common/PXSecuritySettingsStore.h"
#import "common/PXPaths.h"

@interface NetworkDataDetailViewController ()
@property (nonatomic, strong) NSUserDefaults *securitySettings;
@property (nonatomic, strong) UISwitch *mainSwitch;
@end

@implementation NetworkDataDetailViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _securitySettings = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Network Data Spoof";
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = PXSystemGroupedBackgroundColor();
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
    stack.layoutMarginsRelativeArrangement = YES;
    stack.layoutMargins = UIEdgeInsetsMake(16, 16, 24, 16);
    [scroll addSubview:stack];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:g.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:g.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor]
    ]];

    [stack addArrangedSubview:[self buildHero]];

    BOOL on = PXReadSecurityBool(@"networkDataSpoofEnabled", NO);

    [stack addArrangedSubview:[self sectionHeader:@"STATUS"]];
    UIView *toggleCard = [self cardContainer];
    UIStackView *toggleStack = [self innerStackIn:toggleCard];
    [toggleStack addArrangedSubview:[self mainToggleRow:on]];
    [stack addArrangedSubview:toggleCard];

    [stack addArrangedSubview:[self sectionHeader:@"WHAT IT SPOOFS"]];
    UIView *scopeCard = [self cardContainer];
    UIStackView *scopeStack = [self innerStackIn:scopeCard];
    [scopeStack addArrangedSubview:[self scopeRowTitle:@"WiFi data" desc:@"Total received & sent over WiFi"]];
    [scopeStack addArrangedSubview:[self hairline]];
    [scopeStack addArrangedSubview:[self scopeRowTitle:@"Cellular data" desc:@"Total received & sent over cellular"]];
    [stack addArrangedSubview:scopeCard];

    UILabel *note = [[UILabel alloc] init];
    note.translatesAutoresizingMaskIntoConstraints = NO;
    note.text = @"Spoofs network data statistics including total data received and sent for both WiFi and cellular connections. This helps maintain privacy by preventing apps from tracking your actual network usage.";
    note.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    note.textColor = PXSecondaryLabelColor();
    note.numberOfLines = 0;
    [stack addArrangedSubview:note];

    UILabel *related = [[UILabel alloc] init];
    related.translatesAutoresizingMaskIntoConstraints = NO;
    related.text = @"Connection Type and Country settings appear on the Security tab and apply only when Network Data Spoof is on.";
    related.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    related.textColor = PXTertiaryLabelColor();
    related.numberOfLines = 0;
    [stack addArrangedSubview:related];
}

- (UIView *)iconChip:(NSString *)symbol color:(UIColor *)color {
    UIView *chip = [[UIView alloc] init];
    chip.translatesAutoresizingMaskIntoConstraints = NO;
    chip.backgroundColor = [color colorWithAlphaComponent:0.15];
    chip.layer.cornerRadius = 7;
    UIImageView *iv = [[UIImageView alloc] init];
    iv.translatesAutoresizingMaskIntoConstraints = NO;
    iv.contentMode = UIViewContentModeScaleAspectFit;
    iv.tintColor = color;
    if (@available(iOS 13.0, *)) {
        iv.image = [PXSystemImageNamed(symbol) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [chip addSubview:iv];
    [NSLayoutConstraint activateConstraints:@[
        [chip.widthAnchor constraintEqualToConstant:30],
        [chip.heightAnchor constraintEqualToConstant:30],
        [iv.centerXAnchor constraintEqualToAnchor:chip.centerXAnchor],
        [iv.centerYAnchor constraintEqualToAnchor:chip.centerYAnchor],
        [iv.widthAnchor constraintEqualToConstant:17],
        [iv.heightAnchor constraintEqualToConstant:17]
    ]];
    return chip;
}

- (UIView *)buildHero {
    UIView *card = [self cardContainer];
    UIView *chip = [self iconChip:@"antenna.radiowaves.left.and.right" color:[UIColor systemTealColor]];
    [card addSubview:chip];
    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Network Data Spoof";
    title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    title.textColor = PXLabelColor();
    [card addSubview:title];
    UILabel *sub = [[UILabel alloc] init];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.text = @"Optional - hides your real WiFi and cellular data usage.";
    sub.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    sub.textColor = PXSecondaryLabelColor();
    sub.numberOfLines = 0;
    [card addSubview:sub];
    [NSLayoutConstraint activateConstraints:@[
        [chip.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [chip.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [title.leadingAnchor constraintEqualToAnchor:chip.trailingAnchor constant:12],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [title.centerYAnchor constraintEqualToAnchor:chip.centerYAnchor],
        [sub.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [sub.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [sub.topAnchor constraintEqualToAnchor:chip.bottomAnchor constant:12],
        [sub.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16]
    ]];
    return card;
}

- (UIView *)cardContainer {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        card.backgroundColor = PXSecondarySystemGroupedBackgroundColor();
    } else {
        card.backgroundColor = [UIColor whiteColor];
    }
    card.layer.cornerRadius = 16;
    return card;
}

- (UILabel *)sectionHeader:(NSString *)text {
    UILabel *l = [[UILabel alloc] init];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    l.text = text;
    l.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    l.textColor = PXSecondaryLabelColor();
    return l;
}

- (UIStackView *)innerStackIn:(UIView *)card {
    UIStackView *s = [[UIStackView alloc] init];
    s.axis = UILayoutConstraintAxisVertical;
    s.spacing = 0;
    s.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:s];
    [NSLayoutConstraint activateConstraints:@[
        [s.topAnchor constraintEqualToAnchor:card.topAnchor],
        [s.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [s.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [s.bottomAnchor constraintEqualToAnchor:card.bottomAnchor]
    ]];
    return s;
}

- (UIView *)hairline {
    UIView *line = [[UIView alloc] init];
    line.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        line.backgroundColor = PXSeparatorColor();
    } else {
        line.backgroundColor = [UIColor lightGrayColor];
    }
    [line.heightAnchor constraintEqualToConstant:0.5].active = YES;
    return line;
}

- (UIView *)mainToggleRow:(BOOL)on {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *t = [[UILabel alloc] init];
    t.translatesAutoresizingMaskIntoConstraints = NO;
    t.text = @"Enable Network Data Spoof";
    t.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    t.textColor = PXLabelColor();
    [row addSubview:t];
    UILabel *d = [[UILabel alloc] init];
    d.translatesAutoresizingMaskIntoConstraints = NO;
    d.text = @"Spoof WiFi & cellular data statistics";
    d.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    d.textColor = PXSecondaryLabelColor();
    d.numberOfLines = 0;
    [row addSubview:d];
    UISwitch *sw = [[UISwitch alloc] init];
    sw.translatesAutoresizingMaskIntoConstraints = NO;
    sw.onTintColor = [UIColor systemBlueColor];
    [sw setOn:on animated:NO];
    [sw addTarget:self action:@selector(mainToggleChanged:) forControlEvents:UIControlEventValueChanged];
    self.mainSwitch = sw;
    [row addSubview:sw];
    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:64],
        [t.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [t.topAnchor constraintEqualToAnchor:row.topAnchor constant:12],
        [t.trailingAnchor constraintLessThanOrEqualToAnchor:sw.leadingAnchor constant:-12],
        [d.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [d.trailingAnchor constraintLessThanOrEqualToAnchor:sw.leadingAnchor constant:-12],
        [d.topAnchor constraintEqualToAnchor:t.bottomAnchor constant:3],
        [d.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-12],
        [sw.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [sw.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
    ]];
    return row;
}

- (UIView *)scopeRowTitle:(NSString *)title desc:(NSString *)desc {
    UIView *rowv = [[UIView alloc] init];
    rowv.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *t = [[UILabel alloc] init];
    t.translatesAutoresizingMaskIntoConstraints = NO;
    t.text = title;
    t.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    t.textColor = PXLabelColor();
    [rowv addSubview:t];
    UILabel *d = [[UILabel alloc] init];
    d.translatesAutoresizingMaskIntoConstraints = NO;
    d.text = desc;
    d.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    d.textColor = PXSecondaryLabelColor();
    d.numberOfLines = 0;
    [rowv addSubview:d];
    [NSLayoutConstraint activateConstraints:@[
        [rowv.heightAnchor constraintGreaterThanOrEqualToConstant:52],
        [t.leadingAnchor constraintEqualToAnchor:rowv.leadingAnchor constant:16],
        [t.trailingAnchor constraintEqualToAnchor:rowv.trailingAnchor constant:-16],
        [t.topAnchor constraintEqualToAnchor:rowv.topAnchor constant:10],
        [d.leadingAnchor constraintEqualToAnchor:rowv.leadingAnchor constant:16],
        [d.trailingAnchor constraintEqualToAnchor:rowv.trailingAnchor constant:-16],
        [d.topAnchor constraintEqualToAnchor:t.bottomAnchor constant:2],
        [d.bottomAnchor constraintEqualToAnchor:rowv.bottomAnchor constant:-10]
    ]];
    return rowv;
}

- (void)mainToggleChanged:(UISwitch *)sender {
    BOOL enabled = sender.isOn;
    NSError *error = nil;
    if (!PXWriteSecurityBool(@"networkDataSpoofEnabled", enabled, &error)) {
        [sender setOn:!enabled animated:YES];
        NSLog(@"[NetworkDataDetail] Failed to persist networkDataSpoofEnabled: %@", error);
        return;
    }

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:@(enabled) forKey:@"enabled"];
    [userInfo setObject:@"NetworkDataDetailView" forKey:@"sender"];
    [userInfo setObject:[NSDate date] forKey:@"timestamp"];
    [userInfo setObject:@YES forKey:@"forceReload"];
    [userInfo setObject:PXSecuritySettingsPath() forKey:@"settingsPath"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"com.hydra.tlinkios.toggleNetworkDataSpoof"
                                                            object:nil
                                                          userInfo:userInfo];
    });

    CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
    NSString *notificationName = enabled ? @"com.hydra.tlinkios.enableNetworkDataSpoof" : @"com.hydra.tlinkios.disableNetworkDataSpoof";
    CFNotificationCenterPostNotification(darwinCenter, (__bridge CFStringRef)notificationName, NULL, NULL, YES);
    CFNotificationCenterPostNotification(darwinCenter, CFSTR("com.hydra.tlinkios.networkDataSpoofChanged"), NULL, NULL, YES);
    CFNotificationCenterPostNotification(darwinCenter, CFSTR("com.hydra.tlinkios.settings.changed"), NULL, NULL, YES);

    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [generator prepare];
    [generator impactOccurred];
}

@end
