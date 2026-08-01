#import "ConnectionTypeDetailViewController.h"

@interface ConnectionTypeDetailViewController ()
@property (nonatomic, strong) NSUserDefaults *securitySettings;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *typeChecks;
@end

@implementation ConnectionTypeDetailViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _securitySettings = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
        _typeChecks = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Connection Type";
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

    NSInteger saved = [self.securitySettings integerForKey:@"networkConnectionType"];
    if (saved < 0 || saved > 3) { saved = 0; }

    [stack addArrangedSubview:[self sectionHeader:@"CONNECTION TYPE"]];
    UIView *typeCard = [self cardContainer];
    UIStackView *typeStack = [self innerStackIn:typeCard];
    [typeStack addArrangedSubview:[self typeRowTitle:@"Auto" desc:@"Apps see WiFi or Cellular randomly based on profile settings" tag:0 selected:(saved == 0)]];
    [typeStack addArrangedSubview:[self hairline]];
    [typeStack addArrangedSubview:[self typeRowTitle:@"WiFi" desc:@"Apps always see a WiFi connection" tag:1 selected:(saved == 1)]];
    [typeStack addArrangedSubview:[self hairline]];
    [typeStack addArrangedSubview:[self typeRowTitle:@"Cellular" desc:@"Apps always see a Cellular connection" tag:2 selected:(saved == 2)]];
    [typeStack addArrangedSubview:[self hairline]];
    [typeStack addArrangedSubview:[self typeRowTitle:@"None" desc:@"Apps see no network connection" tag:3 selected:(saved == 3)]];
    [stack addArrangedSubview:typeCard];

    UILabel *note = [[UILabel alloc] init];
    note.translatesAutoresizingMaskIntoConstraints = NO;
    note.text = @"Select how apps should see your network connection. This setting only works when Network Data Spoof is enabled.";
    note.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    note.textColor = [UIColor secondaryLabelColor];
    note.numberOfLines = 0;
    [stack addArrangedSubview:note];

    UILabel *related = [[UILabel alloc] init];
    related.translatesAutoresizingMaskIntoConstraints = NO;
    related.text = @"When Cellular is selected, Country (ISO) options appear on the Security tab.";
    related.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    related.textColor = [UIColor tertiaryLabelColor];
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
        iv.image = [[UIImage systemImageNamed:symbol] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
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
    UIView *chip = [self iconChip:@"wifi" color:[UIColor systemTealColor]];
    [card addSubview:chip];
    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Network Connection Type";
    title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    title.textColor = [UIColor labelColor];
    [card addSubview:title];
    UILabel *sub = [[UILabel alloc] init];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.text = @"Choose how apps see your connection.";
    sub.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    sub.textColor = [UIColor secondaryLabelColor];
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
        card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
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
    l.textColor = [UIColor secondaryLabelColor];
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
        line.backgroundColor = [UIColor separatorColor];
    } else {
        line.backgroundColor = [UIColor lightGrayColor];
    }
    [line.heightAnchor constraintEqualToConstant:0.5].active = YES;
    return line;
}

- (UIView *)typeRowTitle:(NSString *)title desc:(NSString *)desc tag:(NSInteger)tag selected:(BOOL)selected {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.tag = tag;
    row.userInteractionEnabled = YES;

    UILabel *t = [[UILabel alloc] init];
    t.translatesAutoresizingMaskIntoConstraints = NO;
    t.text = title;
    t.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    t.textColor = [UIColor labelColor];
    [row addSubview:t];

    UILabel *d = [[UILabel alloc] init];
    d.translatesAutoresizingMaskIntoConstraints = NO;
    d.text = desc;
    d.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    d.textColor = [UIColor secondaryLabelColor];
    d.numberOfLines = 0;
    [row addSubview:d];

    UIImageView *check = [[UIImageView alloc] init];
    check.translatesAutoresizingMaskIntoConstraints = NO;
    check.contentMode = UIViewContentModeScaleAspectFit;
    check.tintColor = [UIColor systemBlueColor];
    if (@available(iOS 13.0, *)) {
        check.image = [[UIImage systemImageNamed:@"checkmark"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    check.hidden = !selected;
    [row addSubview:check];
    [self.typeChecks addObject:check];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(typeRowTapped:)];
    [row addGestureRecognizer:tap];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:60],
        [t.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [t.topAnchor constraintEqualToAnchor:row.topAnchor constant:11],
        [t.trailingAnchor constraintLessThanOrEqualToAnchor:check.leadingAnchor constant:-12],
        [d.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [d.trailingAnchor constraintLessThanOrEqualToAnchor:check.leadingAnchor constant:-12],
        [d.topAnchor constraintEqualToAnchor:t.bottomAnchor constant:3],
        [d.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-11],
        [check.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [check.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [check.widthAnchor constraintEqualToConstant:18],
        [check.heightAnchor constraintEqualToConstant:18]
    ]];
    return row;
}

- (void)typeRowTapped:(UITapGestureRecognizer *)g {
    NSInteger selectedType = g.view.tag;

    [self.securitySettings setInteger:selectedType forKey:@"networkConnectionType"];
    [self.securitySettings synchronize];

    CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(darwinCenter, CFSTR("com.hydra.projectx.networkConnectionTypeChanged"), NULL, NULL, YES);

    for (NSInteger i = 0; i < (NSInteger)self.typeChecks.count; i++) {
        self.typeChecks[i].hidden = (i != selectedType);
    }

    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [generator prepare];
    [generator impactOccurred];
}

@end
