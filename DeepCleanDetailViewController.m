#import "DeepCleanDetailViewController.h"
#import "common/PXUIKitCompat.h"
#import "common/PXSecuritySettingsStore.h"

@interface DeepCleanDetailViewController ()
@property (nonatomic, strong) NSUserDefaults *securitySettings;
@property (nonatomic, strong) UIImageView *fullCheck;
@property (nonatomic, strong) UIImageView *deepCheck;
@end

@implementation DeepCleanDetailViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _securitySettings = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Clear Data Mode";
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

    [stack addArrangedSubview:[self sectionHeader:@"MODE"]];
    UIView *modeCard = [self cardContainer];
    UIStackView *modeStack = [self innerStackIn:modeCard];
    BOOL deep = PXReadSecurityBool(@"deepCleanEnabled", NO);
    UIButton *fRow = [self modeRowTitle:@"Full" desc:@"Standard 4-scope + Keychain wipe (faster)" tag:0 selected:!deep];
    UIButton *dRow = [self modeRowTitle:@"Deep" desc:@"Scans containers for leftover tokens (slower)" tag:1 selected:deep];
    [modeStack addArrangedSubview:fRow];
    [modeStack addArrangedSubview:[self hairline]];
    [modeStack addArrangedSubview:dRow];
    [stack addArrangedSubview:modeCard];

    [stack addArrangedSubview:[self sectionHeader:@"WHAT GETS CLEARED"]];
    UIView *scopeCard = [self cardContainer];
    UIStackView *scopeStack = [self innerStackIn:scopeCard];
    [scopeStack addArrangedSubview:[self scopeRowTitle:@"App container" desc:@"Caches, preferences, documents"]];
    [scopeStack addArrangedSubview:[self hairline]];
    [scopeStack addArrangedSubview:[self scopeRowTitle:@"Extension" desc:@"Extension containers"]];
    [scopeStack addArrangedSubview:[self hairline]];
    [scopeStack addArrangedSubview:[self scopeRowTitle:@"App Groups" desc:@"Shared app group data"]];
    [scopeStack addArrangedSubview:[self hairline]];
    [scopeStack addArrangedSubview:[self scopeRowTitle:@"PluginKit" desc:@"PluginKit containers"]];
    [scopeStack addArrangedSubview:[self hairline]];
    [scopeStack addArrangedSubview:[self scopeRowTitle:@"Keychain" desc:@"Stored credentials & tokens"]];
    [stack addArrangedSubview:scopeCard];

    UILabel *note = [[UILabel alloc] init];
    note.translatesAutoresizingMaskIntoConstraints = NO;
    note.text = @"Deep mode additionally scans inside containers for leftover tokens/encrypted data after wiping. More thorough but slower.";
    note.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    note.textColor = PXSecondaryLabelColor();
    note.numberOfLines = 0;
    [stack addArrangedSubview:note];
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
    UIView *chip = [self iconChip:@"trash" color:[UIColor systemRedColor]];
    [card addSubview:chip];
    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Clear Data Mode";
    title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    title.textColor = PXLabelColor();
    [card addSubview:title];
    UILabel *sub = [[UILabel alloc] init];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.text = @"Global mode applied to every Clear Data action.";
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

- (UIButton *)modeRowTitle:(NSString *)title desc:(NSString *)desc tag:(NSInteger)tag selected:(BOOL)selected {
    UIButton *row = [UIButton buttonWithType:UIButtonTypeCustom];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.tag = tag;
    [row addTarget:self action:@selector(modeRowTapped:) forControlEvents:UIControlEventTouchUpInside];

    UILabel *t = [[UILabel alloc] init];
    t.translatesAutoresizingMaskIntoConstraints = NO;
    t.text = title;
    t.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    t.textColor = PXLabelColor();
    t.userInteractionEnabled = NO;
    [row addSubview:t];

    UILabel *d = [[UILabel alloc] init];
    d.translatesAutoresizingMaskIntoConstraints = NO;
    d.text = desc;
    d.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    d.textColor = PXSecondaryLabelColor();
    d.numberOfLines = 0;
    d.userInteractionEnabled = NO;
    [row addSubview:d];

    UIImageView *check = [[UIImageView alloc] init];
    check.translatesAutoresizingMaskIntoConstraints = NO;
    check.contentMode = UIViewContentModeScaleAspectFit;
    check.tintColor = [UIColor systemBlueColor];
    if (@available(iOS 13.0, *)) {
        check.image = [PXSystemImageNamed(@"checkmark") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    check.hidden = !selected;
    [row addSubview:check];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:64],
        [t.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [t.topAnchor constraintEqualToAnchor:row.topAnchor constant:12],
        [t.trailingAnchor constraintLessThanOrEqualToAnchor:check.leadingAnchor constant:-12],
        [d.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [d.trailingAnchor constraintLessThanOrEqualToAnchor:check.leadingAnchor constant:-12],
        [d.topAnchor constraintEqualToAnchor:t.bottomAnchor constant:3],
        [d.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-12],
        [check.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [check.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [check.widthAnchor constraintEqualToConstant:20],
        [check.heightAnchor constraintEqualToConstant:20]
    ]];

    if (tag == 0) {
        self.fullCheck = check;
    } else {
        self.deepCheck = check;
    }
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

- (void)modeRowTapped:(UIButton *)sender {
    BOOL deep = (sender.tag == 1);
    NSError *error = nil;
    if (!PXWriteSecurityBool(@"deepCleanEnabled", deep, &error)) {
        BOOL persisted = PXReadSecurityBool(@"deepCleanEnabled", NO);
        self.fullCheck.hidden = persisted;
        self.deepCheck.hidden = !persisted;
        return;
    }
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         CFSTR("com.hydra.tlinkios.settings.changed"),
                                         NULL, NULL, YES);
    self.fullCheck.hidden = deep;
    self.deepCheck.hidden = !deep;
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [gen prepare];
    [gen impactOccurred];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.hydra.tlinkios.deepCleanModeChanged" object:nil userInfo:@{ @"deep": @(deep) }];
}

@end
