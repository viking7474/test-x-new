#import "TimeSpoofDetailViewController.h"
#import "IPStatusCacheManager.h"
#import "LocationSpoofingManager.h"
#import "IPMonitorService.h"

@interface TimeSpoofDetailViewController ()
@property (nonatomic, strong) NSUserDefaults *securitySettings;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *modeChecks;
@property (nonatomic, strong) UIView *dataCard;
@property (nonatomic, strong) UILabel *dataTitleLabel;
@property (nonatomic, strong) UILabel *dataLabel;
@end

@implementation TimeSpoofDetailViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _securitySettings = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
        _modeChecks = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Time Spoof";
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

    NSInteger saved = [self.securitySettings integerForKey:@"timeSpoofingMode"];
    if (saved < 0 || saved > 2) { saved = 0; }

    [stack addArrangedSubview:[self sectionHeader:@"MODE"]];
    UIView *modeCard = [self cardContainer];
    UIStackView *modeStack = [self innerStackIn:modeCard];
    [modeStack addArrangedSubview:[self modeRowTitle:@"Off" desc:@"Disables time spoofing" tag:0 selected:(saved == 0)]];
    [modeStack addArrangedSubview:[self hairline]];
    [modeStack addArrangedSubview:[self modeRowTitle:@"Use IP" desc:@"Uses your public IP address to determine time zone" tag:1 selected:(saved == 1)]];
    [modeStack addArrangedSubview:[self hairline]];
    [modeStack addArrangedSubview:[self modeRowTitle:@"Use Location" desc:@"Uses your pinned location to determine time zone" tag:2 selected:(saved == 2)]];
    [stack addArrangedSubview:modeCard];

    [stack addArrangedSubview:[self sectionHeader:@"CURRENT DATA"]];
    self.dataCard = [self cardContainer];
    UIStackView *dataStack = [self innerStackIn:self.dataCard];
    dataStack.layoutMarginsRelativeArrangement = YES;
    dataStack.layoutMargins = UIEdgeInsetsMake(14, 16, 14, 16);
    dataStack.spacing = 6;

    self.dataTitleLabel = [[UILabel alloc] init];
    self.dataTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dataTitleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.dataTitleLabel.textColor = [UIColor secondaryLabelColor];
    [dataStack addArrangedSubview:self.dataTitleLabel];

    self.dataLabel = [[UILabel alloc] init];
    self.dataLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.dataLabel.font = [UIFont systemFontOfSize:14];
    self.dataLabel.textColor = [UIColor labelColor];
    self.dataLabel.numberOfLines = 0;
    [dataStack addArrangedSubview:self.dataLabel];
    [stack addArrangedSubview:self.dataCard];

    UILabel *note = [[UILabel alloc] init];
    note.translatesAutoresizingMaskIntoConstraints = NO;
    note.text = @"Choose how the system spoofs time. Time data is stored in the iplocationtime.plist file and includes timestamp information.";
    note.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    note.textColor = [UIColor secondaryLabelColor];
    note.numberOfLines = 0;
    [stack addArrangedSubview:note];

    UILabel *related = [[UILabel alloc] init];
    related.translatesAutoresizingMaskIntoConstraints = NO;
    related.text = @"Use Location mode relies on your pinned location. Set it from the Location screen.";
    related.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    related.textColor = [UIColor tertiaryLabelColor];
    related.numberOfLines = 0;
    [stack addArrangedSubview:related];

    [self refreshDataDisplayForMode:saved];
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
    UIView *chip = [self iconChip:@"clock" color:[UIColor systemOrangeColor]];
    [card addSubview:chip];
    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Time Spoofing";
    title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    title.textColor = [UIColor labelColor];
    [card addSubview:title];
    UILabel *sub = [[UILabel alloc] init];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.text = @"Spoof time zone using IP or pinned location.";
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

- (UIView *)modeRowTitle:(NSString *)title desc:(NSString *)desc tag:(NSInteger)tag selected:(BOOL)selected {
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
    [self.modeChecks addObject:check];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(modeRowTapped:)];
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

- (void)modeRowTapped:(UITapGestureRecognizer *)g {
    NSInteger selected = g.view.tag;

    [self.securitySettings setInteger:selected forKey:@"timeSpoofingMode"];
    [self.securitySettings synchronize];

    for (NSInteger i = 0; i < (NSInteger)self.modeChecks.count; i++) {
        self.modeChecks[i].hidden = (i != selected);
    }

    [self refreshDataDisplayForMode:selected];

    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [generator prepare];
    [generator impactOccurred];
}

- (void)refreshDataDisplayForMode:(NSInteger)mode {
    if (mode == 1) {
        self.dataCard.hidden = NO;
        self.dataTitleLabel.text = @"IP-BASED TIME ZONE";
        NSDictionary *ipData = [IPStatusCacheManager getPublicIPData];
        NSString *ip = ipData[@"publicIP"];
        NSString *flagEmoji = ipData[@"ipFlagEmoji"];
        NSString *timestamp = ipData[@"ipTimestamp"];
        if (ip) {
            NSMutableAttributedString *attributedString;
            if (flagEmoji) {
                attributedString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"IP: %@ %@", flagEmoji, ip]];
            } else {
                attributedString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"IP: %@", ip]];
            }
            if (timestamp) {
                NSString *timeAgo = [self timeAgoFromTimestamp:timestamp];
                if (timeAgo) {
                    [attributedString appendAttributedString:[[NSAttributedString alloc]
                        initWithString:[NSString stringWithFormat:@"\nRecorded: %@", timeAgo]
                        attributes:@{
                            NSFontAttributeName: [UIFont systemFontOfSize:12],
                            NSForegroundColorAttributeName: [UIColor secondaryLabelColor]
                        }]];
                }
            }
            self.dataLabel.attributedText = attributedString;
        } else {
            NSString *fallbackIp = [[IPMonitorService sharedInstance] loadLastKnownIP];
            if (fallbackIp && [fallbackIp length] > 0) {
                self.dataLabel.text = [NSString stringWithFormat:@"IP: %@", fallbackIp];
            } else {
                self.dataLabel.text = @"IP: Not available";
            }
        }
    } else if (mode == 2) {
        self.dataCard.hidden = NO;
        self.dataTitleLabel.text = @"LOCATION-BASED TIME ZONE";
        NSDictionary *locationData = [IPStatusCacheManager getPinnedLocationData];
        NSNumber *latitude = locationData[@"latitude"];
        NSNumber *longitude = locationData[@"longitude"];
        NSString *flagEmoji = locationData[@"locationFlagEmoji"];
        NSString *timestamp = locationData[@"locationTimestamp"];
        if (latitude && longitude) {
            NSMutableAttributedString *attributedString;
            if (flagEmoji) {
                attributedString = [[NSMutableAttributedString alloc]
                    initWithString:[NSString stringWithFormat:@"Location: %@ %.6f, %.6f",
                                  flagEmoji, [latitude doubleValue], [longitude doubleValue]]];
            } else {
                attributedString = [[NSMutableAttributedString alloc]
                    initWithString:[NSString stringWithFormat:@"Location: %.6f, %.6f",
                                  [latitude doubleValue], [longitude doubleValue]]];
            }
            if (timestamp) {
                NSString *timeAgo = [self timeAgoFromTimestamp:timestamp];
                if (timeAgo) {
                    [attributedString appendAttributedString:[[NSAttributedString alloc]
                        initWithString:[NSString stringWithFormat:@"\nRecorded: %@", timeAgo]
                        attributes:@{
                            NSFontAttributeName: [UIFont systemFontOfSize:12],
                            NSForegroundColorAttributeName: [UIColor secondaryLabelColor]
                        }]];
                }
            }
            self.dataLabel.attributedText = attributedString;
        } else {
            NSDictionary *pinned = [[LocationSpoofingManager sharedManager] loadSpoofingLocation];
            if (pinned && pinned[@"latitude"] && pinned[@"longitude"]) {
                self.dataLabel.text = [NSString stringWithFormat:@"Location: %.6f, %.6f",
                                          [pinned[@"latitude"] doubleValue], [pinned[@"longitude"] doubleValue]];
            } else {
                self.dataLabel.text = @"Location: Not available";
            }
        }
    } else {
        self.dataCard.hidden = YES;
        self.dataLabel.text = @"";
        self.dataTitleLabel.text = @"";
    }
}

- (NSString *)timeAgoFromTimestamp:(NSString *)timestamp {
    if (!timestamp) return nil;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSDate *date = [formatter dateFromString:timestamp];
    if (!date) {
        NSNumber *timestampNum = nil;
        if ([timestamp doubleValue] > 0) {
            timestampNum = @([timestamp doubleValue]);
        }
        if (timestampNum) {
            date = [NSDate dateWithTimeIntervalSince1970:[timestampNum doubleValue]];
        } else {
            return @"unknown time";
        }
    }
    NSTimeInterval timeSince = -[date timeIntervalSinceNow];
    if (timeSince < 60) {
        return @"just now";
    } else if (timeSince < 3600) {
        int minutes = (int)(timeSince / 60);
        return [NSString stringWithFormat:@"%d %@ ago", minutes, minutes == 1 ? @"minute" : @"minutes"];
    } else if (timeSince < 86400) {
        int hours = (int)(timeSince / 3600);
        return [NSString stringWithFormat:@"%d %@ ago", hours, hours == 1 ? @"hour" : @"hours"];
    } else if (timeSince < 2592000) {
        int days = (int)(timeSince / 86400);
        return [NSString stringWithFormat:@"%d %@ ago", days, days == 1 ? @"day" : @"days"];
    } else if (timeSince < 31536000) {
        int months = (int)(timeSince / 2592000);
        return [NSString stringWithFormat:@"%d %@ ago", months, months == 1 ? @"month" : @"months"];
    } else {
        int years = (int)(timeSince / 31536000);
        return [NSString stringWithFormat:@"%d %@ ago", years, years == 1 ? @"year" : @"years"];
    }
}

@end
