#import "common/PXUIKitCompat.h"
#import "PXRRSManagerViewController.h"
#import "WeaponXTheme.h"

#pragma mark - Helpers

static UITableViewStyle PXRRSSCompatibleInsetGrouped(void) {
    if (@available(iOS 13.0, *)) return PXInsetGroupedTableViewStyle();
    return UITableViewStyleGrouped;
}

static NSString *PXRRSString(NSDictionary *e, NSString *key) {
    id v = e[key];
    return [v isKindOfClass:[NSString class]] ? v : @"";
}

static NSString *PXRRSRelativeDate(NSString *raw) {
    if (!raw.length || [raw isEqualToString:@"(null)"]) return @"Chưa có";
    NSDate *date = nil;
    NSDateFormatter *iso = [[NSDateFormatter alloc] init];
    iso.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    for (NSString *fmt in @[ @"yyyy-MM-dd'T'HH:mm:ssZ", @"yyyy-MM-dd HH:mm:ss", @"yyyy-MM-dd" ]) {
        iso.dateFormat = fmt;
        date = [iso dateFromString:raw];
        if (date) break;
    }
    if (!date) {
        NSTimeInterval ts = [raw doubleValue];
        if (ts > 1000000000) date = [NSDate dateWithTimeIntervalSince1970:ts];
    }
    if (!date) return raw;
    Class relativeFormatterClass = NSClassFromString(@"NSRelativeDateTimeFormatter");
    if (relativeFormatterClass) {
        id rel = [[relativeFormatterClass alloc] init];
        if ([rel respondsToSelector:NSSelectorFromString(@"setUnitsStyle:")]) {
            [rel setValue:@0 forKey:@"unitsStyle"]; // NSRelativeDateTimeFormatterUnitsStyleFull
        }
        if ([rel respondsToSelector:NSSelectorFromString(@"localizedStringForDate:relativeToDate:")]) {
            return [rel localizedStringForDate:date relativeToDate:[NSDate date]];
        }
    }
    NSDateFormatter *out = [[NSDateFormatter alloc] init];
    out.dateStyle = NSDateFormatterMediumStyle;
    out.timeStyle = NSDateFormatterShortStyle;
    return [out stringFromDate:date];
}

static UIImage *PXRRSAppPlaceholder(NSString *name) {
    NSString *letter = name.length ? [[name substringToIndex:1] uppercaseString] : @"?";
    CGSize size = CGSizeMake(44, 44);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    UIColor *bg = [UIColor systemBlueColor];
    if (@available(iOS 13.0, *)) bg = PXSystemIndigoColor();
    [bg setFill];
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 44, 44) cornerRadius:11];
    [path fill];
    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont systemFontOfSize:18 weight:UIFontWeightBold],
        NSForegroundColorAttributeName: [UIColor whiteColor]
    };
    CGSize t = [letter sizeWithAttributes:attrs];
    [letter drawAtPoint:CGPointMake((44 - t.width) / 2.0, (44 - t.height) / 2.0) withAttributes:attrs];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
    (void)ctx;
}

#pragma mark - Detail VC

@interface PXRRSDetailViewController : UITableViewController
@property (nonatomic, copy) NSDictionary *entry;
@property (nonatomic, copy) void (^onSaveAndRestore)(NSString *backupDir);
@property (nonatomic, copy) void (^onRestoreOnly)(NSString *backupDir);
@property (nonatomic, copy) void (^onDelete)(NSString *backupDir);
@end

@implementation PXRRSDetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Chi tiết";
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:PXRRSSCompatibleInsetGrouped()];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = PXSystemGroupedBackgroundColor();
    [self buildFooter];
}

- (void)buildFooter {
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 190)];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [footer addSubview:stack];

    UIButton *primary = [UIButton buttonWithType:UIButtonTypeSystem];
    primary.backgroundColor = [UIColor systemBlueColor];
    [primary setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    primary.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    primary.layer.cornerRadius = 12;
    [primary setTitle:@"Lưu RRS hiện tại & Restore" forState:UIControlStateNormal];
    [primary.heightAnchor constraintEqualToConstant:50].active = YES;
    [primary addTarget:self action:@selector(saveRestoreTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton *secondary = [UIButton buttonWithType:UIButtonTypeSystem];
    secondary.backgroundColor = PXTertiarySystemFillColor();
    [secondary setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    secondary.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    secondary.layer.cornerRadius = 12;
    [secondary setTitle:@"Chỉ Restore (không lưu mới)" forState:UIControlStateNormal];
    [secondary.heightAnchor constraintEqualToConstant:50].active = YES;
    [secondary addTarget:self action:@selector(restoreOnlyTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton *danger = [UIButton buttonWithType:UIButtonTypeSystem];
    danger.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.12];
    [danger setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    danger.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    danger.layer.cornerRadius = 12;
    [danger setTitle:@"Xóa RRS này" forState:UIControlStateNormal];
    [danger.heightAnchor constraintEqualToConstant:50].active = YES;
    [danger addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];

    [stack addArrangedSubview:primary];
    [stack addArrangedSubview:secondary];
    [stack addArrangedSubview:danger];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:footer.topAnchor constant:16],
        [stack.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-16]
    ]];
    self.tableView.tableFooterView = footer;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (section == 1) return 4;
    return 2;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) return @"Thông tin";
    if (section == 2) return @"Ghi chú & Checksum";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = PXSecondarySystemGroupedBackgroundColor();
    NSDictionary *e = self.entry ?: @{};
    NSString *appName = PXRRSString(e, @"appName");
    if (!appName.length) appName = @"RRS";

    if (indexPath.section == 0) {
        cell.imageView.image = PXRRSAppPlaceholder(appName);
        cell.textLabel.text = appName;
        cell.textLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        cell.detailTextLabel.text = PXRRSString(e, @"dir").lastPathComponent;
        cell.detailTextLabel.font = PXMonospacedSystemFont(12, UIFontWeightRegular);
        cell.detailTextLabel.textColor = PXSecondaryLabelColor();
        cell.detailTextLabel.numberOfLines = 2;
        return cell;
    }
    if (indexPath.section == 1) {
        NSArray *titles = @[ @"Dung lượng", @"Backup", @"Restore lần cuối", @"IP reset" ];
        NSArray *values = @[
            PXRRSString(e, @"size").length ? PXRRSString(e, @"size") : @"—",
            PXRRSRelativeDate(PXRRSString(e, @"backupDate")),
            PXRRSRelativeDate(PXRRSString(e, @"restoreDate")),
            PXRRSString(e, @"ip").length ? PXRRSString(e, @"ip") : @"—"
        ];
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = PXSecondarySystemGroupedBackgroundColor();
        cell.textLabel.text = titles[indexPath.row];
        cell.detailTextLabel.text = values[indexPath.row];
        if (indexPath.row == 3) {
            cell.detailTextLabel.font = PXMonospacedSystemFont(13, UIFontWeightRegular);
        }
        return cell;
    }
    if (indexPath.row == 0) {
        cell.textLabel.text = PXRRSString(e, @"note").length ? PXRRSString(e, @"note") : @"(không có ghi chú)";
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.textLabel.textColor = PXRRSString(e, @"note").length ? PXLabelColor() : PXSecondaryLabelColor();
        return cell;
    }
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = PXSecondarySystemGroupedBackgroundColor();
    cell.textLabel.text = @"Checksum";
    cell.textLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    cell.detailTextLabel.text = PXRRSString(e, @"checksum").length ? PXRRSString(e, @"checksum") : @"—";
    cell.detailTextLabel.font = PXMonospacedSystemFont(12, UIFontWeightRegular);
    cell.detailTextLabel.numberOfLines = 3;
    cell.detailTextLabel.textColor = PXSecondaryLabelColor();
    UIButton *copy = [UIButton buttonWithType:UIButtonTypeSystem];
    [copy setTitle:@"Copy" forState:UIControlStateNormal];
    copy.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [copy sizeToFit];
    [copy addTarget:self action:@selector(copyChecksum) forControlEvents:UIControlEventTouchUpInside];
    cell.accessoryView = copy;
    return cell;
}

- (void)copyChecksum {
    NSString *cs = PXRRSString(self.entry, @"checksum");
    if (cs.length) [UIPasteboard generalPasteboard].string = cs;
}

- (void)saveRestoreTapped {
    NSString *dir = PXRRSString(self.entry, @"dir");
    if (self.onSaveAndRestore && dir.length) self.onSaveAndRestore(dir);
}

- (void)restoreOnlyTapped {
    NSString *dir = PXRRSString(self.entry, @"dir");
    if (self.onRestoreOnly && dir.length) self.onRestoreOnly(dir);
    else if (self.onSaveAndRestore && dir.length) self.onSaveAndRestore(dir);
}

- (void)deleteTapped {
    NSString *dir = PXRRSString(self.entry, @"dir");
    NSString *name = PXRRSString(self.entry, @"appName");
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Xóa RRS này?"
                                                                   message:[NSString stringWithFormat:@"%@ sẽ bị xóa vĩnh viễn. Không thể hoàn tác.", name.length ? name : @"Bản RRS"]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Xóa" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) {
        if (weakSelf.onDelete && dir.length) weakSelf.onDelete(dir);
        [weakSelf.navigationController popViewControllerAnimated:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - Sequence Sheet VC (interface)

@interface PXRRSSequenceSheetViewController : UIViewController
@property (nonatomic, copy) void (^onModeSelected)(NSInteger mode);
@property (nonatomic, copy) void (^onRangeEdited)(NSInteger begin, NSInteger end);
@property (nonatomic, copy) void (^onRestoreNext)(void);
@property (nonatomic, copy) NSDictionary *(^nextInfoProvider)(void);
@end

#pragma mark - Manager VC

@interface PXRRSManagerViewController () <UISearchResultsUpdating>
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedDirs;
@property (nonatomic, copy) NSString *filterText;
@property (nonatomic, assign) BOOL editingSelection;
@property (nonatomic, strong) UIBarButtonItem *selectButton;
@property (nonatomic, strong) UIBarButtonItem *doneSelectButton;
@property (nonatomic, strong) UIBarButtonItem *closeButton;
@property (nonatomic, strong) UIButton *sequenceFooterButton;
@property (nonatomic, strong) UIButton *deleteFooterButton;
@property (nonatomic, strong) UIView *footerContainer;
@property (nonatomic, strong) UIVisualEffectView *footerBlur;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *footerHostConstraints;
@property (nonatomic, strong) UISearchController *searchController;
@end

@implementation PXRRSManagerViewController

- (instancetype)init {
    return [self initWithStyle:PXRRSSCompatibleInsetGrouped()];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = PXSystemGroupedBackgroundColor();
    self.selectedDirs = [NSMutableSet set];
    self.filterText = @"";

    // iPhone 6s: large title + search + sticky footer eats vertical space.
    BOOL compact = (CGRectGetHeight(UIScreen.mainScreen.bounds) < 700.0);
    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = !compact;
        self.navigationItem.largeTitleDisplayMode = compact
            ? UINavigationItemLargeTitleDisplayModeNever
            : UINavigationItemLargeTitleDisplayModeAlways;
    }
    self.title = @"RRS";
    self.navigationItem.prompt = nil;

    UIImage *backImg = nil;
    if (@available(iOS 13.0, *)) backImg = PXSystemImageNamed(@"chevron.left");
    self.closeButton = backImg
        ? [[UIBarButtonItem alloc] initWithImage:backImg style:UIBarButtonItemStylePlain target:self action:@selector(closeTapped)]
        : [[UIBarButtonItem alloc] initWithTitle:@"Đóng" style:UIBarButtonItemStylePlain target:self action:@selector(closeTapped)];
    self.selectButton = [[UIBarButtonItem alloc] initWithTitle:@"Chọn"
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(enterSelectionMode)];
    self.doneSelectButton = [[UIBarButtonItem alloc] initWithTitle:@"Hủy"
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(exitSelectionMode)];
    self.navigationItem.leftBarButtonItem = self.closeButton;
    self.navigationItem.rightBarButtonItem = self.selectButton;

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.placeholder = @"Tìm app, note, IP…";
    if (@available(iOS 11.0, *)) {
        self.navigationItem.searchController = self.searchController;
        self.navigationItem.hidesSearchBarWhenScrolling = YES;
    }
    self.definesPresentationContext = YES;

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"RRSCell"];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 84;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 68, 0, 16);

    [self buildFooterBar];
    [self refreshChrome];
}

// Footer lives in the navigation controller's view (NOT the table view). A
// UITableViewController's view IS the scroll view, so pinning an overlay to it
// anchors the button to content coordinates -> taps miss. Hosting it outside the
// scroll view makes the button hit-test reliably.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    UIView *host = self.navigationController.view ?: self.view;
    if (self.footerContainer && self.footerContainer.superview != host) {
        [self.footerContainer removeFromSuperview];
        [host addSubview:self.footerContainer];
        self.footerHostConstraints = @[
            [self.footerContainer.leadingAnchor constraintEqualToAnchor:host.leadingAnchor],
            [self.footerContainer.trailingAnchor constraintEqualToAnchor:host.trailingAnchor],
            [self.footerContainer.bottomAnchor constraintEqualToAnchor:host.bottomAnchor]
        ];
        [NSLayoutConstraint activateConstraints:self.footerHostConstraints];
    }
    [host bringSubviewToFront:self.footerContainer];
    [self refreshChrome];
    [self.view setNeedsLayout];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // Not called for the overFullScreen sequence sheet, so the footer stays put
    // behind it; removed when pushing Detail or dismissing the manager.
    [self.footerContainer removeFromSuperview];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat h = CGRectGetHeight(self.footerContainer.bounds);
    if (h < 1) {
        CGFloat safe = 0;
        if (@available(iOS 11.0, *)) safe = self.view.safeAreaInsets.bottom;
        h = 70 + safe;
    }
    UIEdgeInsets inset = self.tableView.contentInset;
    UIEdgeInsets ind = self.tableView.scrollIndicatorInsets;
    if (fabs(inset.bottom - (h + 8)) > 0.5) {
        inset.bottom = h + 8;
        ind.bottom = h + 8;
        self.tableView.contentInset = inset;
        self.tableView.scrollIndicatorInsets = ind;
    }
}

#pragma mark - Footer

- (void)buildFooterBar {
    self.footerContainer = [[UIView alloc] init];
    self.footerContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.footerContainer.backgroundColor = [UIColor clearColor];

    self.footerBlur = [[UIVisualEffectView alloc] initWithEffect:PXChromeMaterialBlurEffect()];
    self.footerBlur.translatesAutoresizingMaskIntoConstraints = NO;
    self.footerBlur.userInteractionEnabled = NO;
    [self.footerContainer addSubview:self.footerBlur];

    UIView *sep = [[UIView alloc] init];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    sep.backgroundColor = PXSeparatorColor();
    [self.footerContainer addSubview:sep];

    UIColor *fill = [UIColor colorWithWhite:0.5 alpha:0.16];
    if (@available(iOS 13.0, *)) fill = PXSecondarySystemFillColor();

    self.sequenceFooterButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sequenceFooterButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.sequenceFooterButton.backgroundColor = fill;
    [self.sequenceFooterButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    self.sequenceFooterButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.sequenceFooterButton.layer.cornerRadius = 12;
    self.sequenceFooterButton.clipsToBounds = YES;
    [self.sequenceFooterButton setTitle:@"Restore theo thứ tự…" forState:UIControlStateNormal];
    [self.sequenceFooterButton addTarget:self action:@selector(presentSequenceSheet) forControlEvents:UIControlEventTouchUpInside];
    [self.footerContainer addSubview:self.sequenceFooterButton];

    self.deleteFooterButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.deleteFooterButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteFooterButton.backgroundColor = [UIColor systemRedColor];
    [self.deleteFooterButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.deleteFooterButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.deleteFooterButton.layer.cornerRadius = 12;
    self.deleteFooterButton.clipsToBounds = YES;
    self.deleteFooterButton.hidden = YES;
    [self.deleteFooterButton addTarget:self action:@selector(deleteSelectedTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.footerContainer addSubview:self.deleteFooterButton];

    UILayoutGuide *safe = self.footerContainer.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.footerBlur.topAnchor constraintEqualToAnchor:self.footerContainer.topAnchor],
        [self.footerBlur.leadingAnchor constraintEqualToAnchor:self.footerContainer.leadingAnchor],
        [self.footerBlur.trailingAnchor constraintEqualToAnchor:self.footerContainer.trailingAnchor],
        [self.footerBlur.bottomAnchor constraintEqualToAnchor:self.footerContainer.bottomAnchor],

        [sep.topAnchor constraintEqualToAnchor:self.footerContainer.topAnchor],
        [sep.leadingAnchor constraintEqualToAnchor:self.footerContainer.leadingAnchor],
        [sep.trailingAnchor constraintEqualToAnchor:self.footerContainer.trailingAnchor],
        [sep.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [self.sequenceFooterButton.topAnchor constraintEqualToAnchor:self.footerContainer.topAnchor constant:10],
        [self.sequenceFooterButton.leadingAnchor constraintEqualToAnchor:self.footerContainer.leadingAnchor constant:16],
        [self.sequenceFooterButton.trailingAnchor constraintEqualToAnchor:self.footerContainer.trailingAnchor constant:-16],
        [self.sequenceFooterButton.heightAnchor constraintEqualToConstant:50],
        [self.sequenceFooterButton.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-10],

        [self.deleteFooterButton.topAnchor constraintEqualToAnchor:self.sequenceFooterButton.topAnchor],
        [self.deleteFooterButton.leadingAnchor constraintEqualToAnchor:self.sequenceFooterButton.leadingAnchor],
        [self.deleteFooterButton.trailingAnchor constraintEqualToAnchor:self.sequenceFooterButton.trailingAnchor],
        [self.deleteFooterButton.bottomAnchor constraintEqualToAnchor:self.sequenceFooterButton.bottomAnchor]
    ]];
}

#pragma mark - Data

- (NSArray<NSDictionary *> *)visibleEntries {
    NSArray *src = self.entries ?: @[];
    if (!self.filterText.length) return src;
    NSString *q = self.filterText;
    NSPredicate *p = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *e, NSDictionary *bindings) {
        NSString *hay = [NSString stringWithFormat:@"%@ %@ %@ %@",
                         PXRRSString(e, @"note"), PXRRSString(e, @"checksum"),
                         PXRRSString(e, @"ip"), PXRRSString(e, @"appName")];
        return [hay rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound;
    }];
    return [src filteredArrayUsingPredicate:p];
}

- (NSDictionary *)nextEntry {
    NSArray *visible = [self visibleEntries];
    if (!visible.count) return nil;
    NSInteger idx = self.nextIndex;
    if (self.sequenceMode == 1) {
        idx = (NSInteger)visible.count - 1 - self.nextIndex;
    }
    if (self.rangeEnd > 0 && self.nextIndex >= self.rangeEnd) return nil;
    if (idx < 0 || idx >= (NSInteger)visible.count) return nil;
    return visible[(NSUInteger)idx];
}

- (NSString *)sequenceModeLabel {
    switch (self.sequenceMode) {
        case 1: return @"Ngược lại";
        case 2: return @"Theo số";
        default: return @"Đầu → cuối";
    }
}

- (void)reloadFromSource {
    if (self.onReload) self.entries = self.onReload() ?: @[];
    [self.selectedDirs removeAllObjects];
    [self refreshChrome];
    [self.tableView reloadData];
}

- (void)refreshChrome {
    NSUInteger count = self.entries.count;
    self.navigationItem.prompt = nil;

    if (self.editingSelection) {
        NSUInteger n = self.selectedDirs.count;
        self.title = n ? [NSString stringWithFormat:@"Đã chọn %lu", (unsigned long)n] : @"Chọn RRS";
        self.navigationItem.leftBarButtonItem = self.doneSelectButton;
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Tất cả"
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(selectAllTapped)];
        self.sequenceFooterButton.hidden = YES;
        self.deleteFooterButton.hidden = NO;
        NSString *delTitle = n ? [NSString stringWithFormat:@"Xóa %lu RRS", (unsigned long)n] : @"Xóa";
        [self.deleteFooterButton setTitle:delTitle forState:UIControlStateNormal];
        self.deleteFooterButton.enabled = n > 0;
        self.deleteFooterButton.alpha = n > 0 ? 1.0 : 0.45;
    } else {
        self.title = count ? [NSString stringWithFormat:@"RRS (%lu)", (unsigned long)count] : @"RRS";
        self.navigationItem.leftBarButtonItem = self.closeButton;
        self.navigationItem.rightBarButtonItem = self.selectButton;
        self.sequenceFooterButton.hidden = NO;
        self.deleteFooterButton.hidden = YES;
        self.selectButton.enabled = count > 0;
        self.sequenceFooterButton.enabled = count > 0;
        self.sequenceFooterButton.alpha = count > 0 ? 1.0 : 0.45;
    }
}

#pragma mark - Selection mode

- (void)enterSelectionMode {
    self.editingSelection = YES;
    [self.selectedDirs removeAllObjects];
    [self.tableView setEditing:YES animated:YES];
    [self refreshChrome];
    [self.tableView reloadData];
}

- (void)exitSelectionMode {
    self.editingSelection = NO;
    [self.selectedDirs removeAllObjects];
    [self.tableView setEditing:NO animated:YES];
    [self refreshChrome];
    [self.tableView reloadData];
}

- (void)selectAllTapped {
    NSArray *vis = [self visibleEntries];
    if (self.selectedDirs.count == vis.count) {
        [self.selectedDirs removeAllObjects];
    } else {
        for (NSDictionary *e in vis) {
            NSString *dir = PXRRSString(e, @"dir");
            if (dir.length) [self.selectedDirs addObject:dir];
        }
    }
    [self refreshChrome];
    [self.tableView reloadData];
}

- (void)deleteSelectedTapped {
    if (!self.selectedDirs.count) return;
    NSArray *dirs = self.selectedDirs.allObjects;
    NSMutableArray *names = [NSMutableArray array];
    for (NSDictionary *e in self.entries) {
        if ([dirs containsObject:PXRRSString(e, @"dir")]) {
            NSString *n = PXRRSString(e, @"appName");
            [names addObject:n.length ? n : @"RRS"];
        }
    }
    NSString *list = [names componentsJoinedByString:@", "];
    if (list.length > 80) list = [[list substringToIndex:77] stringByAppendingString:@"…"];
    NSString *title = [NSString stringWithFormat:@"Xóa %lu RRS?", (unsigned long)dirs.count];
    NSString *msg = [NSString stringWithFormat:@"%@ sẽ bị xóa vĩnh viễn. Không thể hoàn tác.", list.length ? list : @"Các bản đã chọn"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Xóa" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) {
        if (weakSelf.onDelete) weakSelf.onDelete(dirs);
        [weakSelf exitSelectionMode];
        [weakSelf reloadFromSource];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUInteger n = [self visibleEntries].count;
    if (!n && !self.filterText.length) {
        self.tableView.backgroundView = [self emptyStateView];
    } else if (!n && self.filterText.length) {
        UILabel *empty = [[UILabel alloc] init];
        empty.text = @"Không có kết quả";
        empty.textAlignment = NSTextAlignmentCenter;
        empty.textColor = PXSecondaryLabelColor();
        empty.font = [UIFont systemFontOfSize:15];
        self.tableView.backgroundView = empty;
    } else {
        self.tableView.backgroundView = nil;
    }
    return (NSInteger)n;
}

- (UIView *)emptyStateView {
    UIView *v = [[UIView alloc] initWithFrame:self.tableView.bounds];
    UIImageView *icon = [[UIImageView alloc] init];
    if (@available(iOS 13.0, *)) icon.image = PXSystemImageNamed(@"externaldrive");
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = PXTertiaryLabelColor();
    icon.contentMode = UIViewContentModeScaleAspectFit;
    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Chưa có RRS";
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    title.textAlignment = NSTextAlignmentCenter;
    UILabel *sub = [[UILabel alloc] init];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.text = @"Trên Home: chọn app → Lưu RRS để tạo bản đầu tiên.";
    sub.font = [UIFont systemFontOfSize:14];
    sub.textColor = PXSecondaryLabelColor();
    sub.textAlignment = NSTextAlignmentCenter;
    sub.numberOfLines = 0;
    [v addSubview:icon];
    [v addSubview:title];
    [v addSubview:sub];
    [NSLayoutConstraint activateConstraints:@[
        [icon.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:v.centerYAnchor constant:-36],
        [icon.widthAnchor constraintEqualToConstant:40],
        [icon.heightAnchor constraintEqualToConstant:40],
        [title.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:12],
        [title.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:28],
        [title.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-28],
        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6],
        [sub.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [sub.trailingAnchor constraintEqualToAnchor:title.trailingAnchor]
    ]];
    return v;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"RRSCell" forIndexPath:indexPath];
    for (UIView *v in cell.contentView.subviews) [v removeFromSuperview];
    cell.accessoryView = nil;
    cell.accessoryType = self.editingSelection ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.backgroundColor = PXSecondarySystemGroupedBackgroundColor();

    NSDictionary *e = [self visibleEntries][(NSUInteger)indexPath.row];
    NSString *dir = PXRRSString(e, @"dir");
    NSString *appName = PXRRSString(e, @"appName");
    if (!appName.length) appName = @"RRS";
    BOOL restored = PXRRSString(e, @"restoreDate").length > 0 && ![PXRRSString(e, @"restoreDate") isEqualToString:@"(null)"];

    BOOL isNext = NO;
    if (!self.editingSelection) {
        NSDictionary *n = [self nextEntry];
        if (n && [PXRRSString(n, @"dir") isEqualToString:dir]) isNext = YES;
    }

    UIImageView *icon = [[UIImageView alloc] initWithImage:PXRRSAppPlaceholder(appName)];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.layer.cornerRadius = 10;
    icon.clipsToBounds = YES;

    UILabel *title = [[UILabel alloc] init];
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    title.text = appName;
    title.lineBreakMode = NSLineBreakByTruncatingTail;
    [title setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [title setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    // Pills on a separate row under the title so the name never disappears on 6s width.
    UIStackView *pillStack = [[UIStackView alloc] init];
    pillStack.axis = UILayoutConstraintAxisHorizontal;
    pillStack.spacing = 4;
    pillStack.alignment = UIStackViewAlignmentCenter;
    if (isNext) [pillStack addArrangedSubview:[self pillWithText:@"NEXT" color:[UIColor systemBlueColor]]];
    if (restored) [pillStack addArrangedSubview:[self pillWithText:@"Đã restore" color:[UIColor systemTealColor]]];
    UIView *pillSpacer = [[UIView alloc] init];
    [pillSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [pillStack addArrangedSubview:pillSpacer];

    UILabel *sub = [[UILabel alloc] init];
    sub.font = [UIFont systemFontOfSize:13];
    sub.textColor = PXSecondaryLabelColor();
    NSString *size = PXRRSString(e, @"size");
    NSString *when = PXRRSRelativeDate(PXRRSString(e, @"backupDate"));
    sub.text = size.length ? [NSString stringWithFormat:@"%@ · %@", when, size] : when;
    sub.lineBreakMode = NSLineBreakByTruncatingTail;

    NSMutableArray *rows = [NSMutableArray arrayWithObject:title];
    if (pillStack.arrangedSubviews.count > 1) [rows addObject:pillStack];
    [rows addObject:sub];

    NSString *noteText = PXRRSString(e, @"note");
    if (noteText.length) {
        UILabel *note = [[UILabel alloc] init];
        note.font = [UIFont systemFontOfSize:12];
        note.textColor = PXTertiaryLabelColor();
        note.text = noteText;
        note.lineBreakMode = NSLineBreakByTruncatingTail;
        [rows addObject:note];
    }

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:rows];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 3;
    textStack.translatesAutoresizingMaskIntoConstraints = NO;

    [cell.contentView addSubview:icon];
    [cell.contentView addSubview:textStack];

    CGFloat trail = self.editingSelection ? 16.0 : 4.0;
    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [icon.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:40],
        [icon.heightAnchor constraintEqualToConstant:40],
        [icon.topAnchor constraintGreaterThanOrEqualToAnchor:cell.contentView.topAnchor constant:12],

        [textStack.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12],
        [textStack.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:11],
        [textStack.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-11],
        [textStack.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-trail]
    ]];

    if (self.editingSelection && [self.selectedDirs containsObject:dir]) {
        [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
    return cell;
}

- (UILabel *)pillWithText:(NSString *)text color:(UIColor *)color {
    UILabel *l = [[UILabel alloc] init];
    l.text = [NSString stringWithFormat:@" %@ ", text];
    l.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    l.textColor = color;
    l.backgroundColor = [color colorWithAlphaComponent:0.14];
    l.layer.cornerRadius = 6;
    l.clipsToBounds = YES;
    l.textAlignment = NSTextAlignmentCenter;
    return l;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *e = [self visibleEntries][(NSUInteger)indexPath.row];
    NSString *dir = PXRRSString(e, @"dir");
    if (self.editingSelection) {
        if (dir.length) [self.selectedDirs addObject:dir];
        [self refreshChrome];
        return;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self pushDetail:e];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.editingSelection) return;
    NSDictionary *e = [self visibleEntries][(NSUInteger)indexPath.row];
    NSString *dir = PXRRSString(e, @"dir");
    if (dir.length) [self.selectedDirs removeObject:dir];
    [self refreshChrome];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editingSelection) return nil;
    NSDictionary *e = [self visibleEntries][(NSUInteger)indexPath.row];
    NSString *dir = PXRRSString(e, @"dir");
    NSString *name = PXRRSString(e, @"appName");
    __weak typeof(self) weakSelf = self;
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                      title:@"Xóa"
                                                                    handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completion)(BOOL)) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Xóa RRS này?"
                                                                       message:[NSString stringWithFormat:@"%@ sẽ bị xóa vĩnh viễn. Không thể hoàn tác.", name.length ? name : @"Bản RRS"]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *a) { completion(NO); }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Xóa" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) {
            if (weakSelf.onDelete && dir.length) weakSelf.onDelete(@[dir]);
            [weakSelf reloadFromSource];
            completion(YES);
        }]];
        [weakSelf presentViewController:alert animated:YES completion:nil];
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[del]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editingSelection) return nil;
    NSDictionary *e = [self visibleEntries][(NSUInteger)indexPath.row];
    NSString *dir = PXRRSString(e, @"dir");
    __weak typeof(self) weakSelf = self;
    UIContextualAction *restore = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                          title:@"Restore"
                                                                        handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completion)(BOOL)) {
        if (weakSelf.onSaveAndRestore && dir.length) weakSelf.onSaveAndRestore(dir);
        completion(YES);
    }];
    restore.backgroundColor = [UIColor systemBlueColor];
    return [UISwipeActionsConfiguration configurationWithActions:@[restore]];
}

#pragma mark - Detail

- (void)pushDetail:(NSDictionary *)entry {
    PXRRSDetailViewController *detail = [[PXRRSDetailViewController alloc] initWithStyle:PXRRSSCompatibleInsetGrouped()];
    detail.entry = entry;
    __weak typeof(self) weakSelf = self;
    detail.onSaveAndRestore = ^(NSString *backupDir) {
        if (weakSelf.onSaveAndRestore) weakSelf.onSaveAndRestore(backupDir);
    };
    detail.onRestoreOnly = ^(NSString *backupDir) {
        if (weakSelf.onSaveAndRestore) weakSelf.onSaveAndRestore(backupDir);
    };
    detail.onDelete = ^(NSString *backupDir) {
        if (weakSelf.onDelete) weakSelf.onDelete(@[backupDir ?: @""]);
        [weakSelf reloadFromSource];
    };
    [self.navigationController pushViewController:detail animated:YES];
}

#pragma mark - Sequence sheet

- (void)presentSequenceSheet {
    if (!self.entries.count) {
        [self showMessage:@"Chưa có RRS" message:@"Không có bản RRS nào để restore."];
        return;
    }
    PXRRSSequenceSheetViewController *sheet = [[PXRRSSequenceSheetViewController alloc] init];
    sheet.modalPresentationStyle = UIModalPresentationOverFullScreen;
    sheet.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    __weak typeof(self) weakSelf = self;
    sheet.nextInfoProvider = ^NSDictionary *{
        __strong typeof(weakSelf) s = weakSelf;
        if (!s) return @{};
        NSDictionary *n = [s nextEntry];
        NSString *nm = PXRRSString(n, @"appName");
        if (!nm.length) nm = n ? @"RRS" : @"—";
        return @{ @"name": nm,
                  @"index": @(s.nextIndex + 1),
                  @"size": PXRRSString(n, @"size"),
                  @"available": @(n != nil),
                  @"total": @(s.entries.count),
                  @"begin": @(s.rangeBegin),
                  @"end": @(s.rangeEnd),
                  @"mode": @(s.sequenceMode) };
    };
    sheet.onModeSelected = ^(NSInteger mode) { [weakSelf applySequenceMode:mode]; };
    sheet.onRangeEdited = ^(NSInteger begin, NSInteger end) { [weakSelf applyRangeBegin:begin end:end]; };
    sheet.onRestoreNext = ^{
        [weakSelf dismissViewControllerAnimated:YES completion:^{
            [weakSelf confirmRestoreNext];
        }];
    };
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)applySequenceMode:(NSInteger)mode {
    self.sequenceMode = mode;
    if (mode == 0 || mode == 1) {
        self.nextIndex = 0;
        self.rangeBegin = 0;
        self.rangeEnd = 0;
        if (self.onSequenceChanged) self.onSequenceChanged(mode, 0, 0);
        if (self.onNextChanged) self.onNextChanged(0);
    } else {
        if (self.rangeBegin <= 0) self.rangeBegin = 1;
        self.nextIndex = self.rangeBegin - 1;
        if (self.onSequenceChanged) self.onSequenceChanged(2, self.rangeBegin, self.rangeEnd);
        if (self.onNextChanged) self.onNextChanged(self.nextIndex);
    }
    [self refreshChrome];
    [self.tableView reloadData];
}

- (void)applyRangeBegin:(NSInteger)begin end:(NSInteger)end {
    self.sequenceMode = 2;
    self.rangeBegin = begin;
    self.rangeEnd = end;
    self.nextIndex = begin > 0 ? (begin - 1) : 0;
    if (self.onSequenceChanged) self.onSequenceChanged(2, begin, end);
    if (self.onNextChanged) self.onNextChanged(self.nextIndex);
    [self refreshChrome];
    [self.tableView reloadData];
}

- (void)confirmRestoreNext {
    if (![self visibleEntries].count) {
        [self showMessage:@"Chưa có RRS" message:@"Không có file RRS để restore."];
        return;
    }
    NSDictionary *target = [self nextEntry];
    if (!target) {
        if (self.rangeEnd > 0 && self.nextIndex >= self.rangeEnd) {
            [self showMessage:@"Đã hết RRS" message:[NSString stringWithFormat:@"Đã vượt end (%ld). Đặt lại thứ tự nếu cần.", (long)self.rangeEnd]];
        } else {
            [self showMessage:@"Thiếu RRS" message:@"Không tìm thấy bản NEXT. Thử đặt lại thứ tự."];
        }
        return;
    }
    NSString *name = PXRRSString(target, @"appName");
    NSString *dir = PXRRSString(target, @"dir");
    NSString *size = PXRRSString(target, @"size");
    NSString *msg = [NSString stringWithFormat:
                     @"Thứ tự: %@\nNEXT #%ld\n%@%@\n\nSẽ Lưu RRS hiện tại rồi restore bản này.",
                     [self sequenceModeLabel],
                     (long)(self.nextIndex + 1),
                     name.length ? name : @"RRS",
                     size.length ? [NSString stringWithFormat:@" · %@", size] : @""];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lưu RRS & Restore NEXT?"
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Restore" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        if (weakSelf.onSaveAndRestore && dir.length) weakSelf.onSaveAndRestore(dir);
        weakSelf.nextIndex += 1;
        if (weakSelf.onNextChanged) weakSelf.onNextChanged(weakSelf.nextIndex);
        [weakSelf reloadFromSource];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Search

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    self.filterText = searchController.searchBar.text ?: @"";
    [self.tableView reloadData];
    [self refreshChrome];
}

#pragma mark - Misc

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showMessage:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - Sequence Sheet VC (impl)

@interface PXRRSSequenceSheetViewController ()
@property (nonatomic, strong) UISegmentedControl *segmented;
@property (nonatomic, strong) UILabel *nextNameLabel;
@property (nonatomic, strong) UILabel *nextIndexLabel;
@property (nonatomic, strong) UIStackView *rangeRow;
@property (nonatomic, strong) UITextField *beginField;
@property (nonatomic, strong) UITextField *endField;
@property (nonatomic, strong) UIButton *primaryButton;
@property (nonatomic, weak) UIView *cardRef;
@end

@implementation PXRRSSequenceSheetViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backdropTapped:)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) card.backgroundColor = PXSystemBackgroundColor();
    else card.backgroundColor = [UIColor whiteColor];
    card.layer.cornerRadius = 16;
    if (@available(iOS 11.0, *)) card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    card.clipsToBounds = YES;
    [self.view addSubview:card];
    self.cardRef = card;

    UIView *grabber = [[UIView alloc] init];
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    grabber.backgroundColor = [UIColor colorWithWhite:0.6 alpha:0.4];
    grabber.layer.cornerRadius = 2.5;
    [card addSubview:grabber];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"Restore theo thứ tự";
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.text = @"Chọn cách duyệt danh sách RRS";
    subtitle.font = [UIFont systemFontOfSize:13];
    subtitle.textColor = PXSecondaryLabelColor();
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 0;

    self.segmented = [[UISegmentedControl alloc] initWithItems:@[ @"Từ đầu→cuối", @"Ngược lại", @"Theo số" ]];
    [self.segmented addTarget:self action:@selector(segmentChanged) forControlEvents:UIControlEventValueChanged];

    UIView *nextBox = [[UIView alloc] init];
    nextBox.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.08];
    nextBox.layer.cornerRadius = 12;
    nextBox.layer.borderWidth = 1;
    nextBox.layer.borderColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.25].CGColor;

    UILabel *nextCaption = [[UILabel alloc] init];
    nextCaption.text = @"Bản tiếp theo (NEXT)";
    nextCaption.font = [UIFont systemFontOfSize:13];
    nextCaption.textColor = PXSecondaryLabelColor();

    self.nextNameLabel = [[UILabel alloc] init];
    self.nextNameLabel.font = [UIFont systemFontOfSize:13];
    self.nextNameLabel.textColor = PXSecondaryLabelColor();
    self.nextNameLabel.numberOfLines = 1;
    self.nextNameLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    UIStackView *nextTextStack = [[UIStackView alloc] initWithArrangedSubviews:@[ nextCaption, self.nextNameLabel ]];
    nextTextStack.axis = UILayoutConstraintAxisVertical;
    nextTextStack.spacing = 2;
    nextTextStack.translatesAutoresizingMaskIntoConstraints = NO;

    self.nextIndexLabel = [[UILabel alloc] init];
    self.nextIndexLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    self.nextIndexLabel.textColor = [UIColor systemBlueColor];
    self.nextIndexLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.nextIndexLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.nextIndexLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    [nextBox addSubview:nextTextStack];
    [nextBox addSubview:self.nextIndexLabel];
    [NSLayoutConstraint activateConstraints:@[
        [nextTextStack.leadingAnchor constraintEqualToAnchor:nextBox.leadingAnchor constant:12],
        [nextTextStack.topAnchor constraintEqualToAnchor:nextBox.topAnchor constant:12],
        [nextTextStack.bottomAnchor constraintEqualToAnchor:nextBox.bottomAnchor constant:-12],
        [self.nextIndexLabel.trailingAnchor constraintEqualToAnchor:nextBox.trailingAnchor constant:-12],
        [self.nextIndexLabel.centerYAnchor constraintEqualToAnchor:nextBox.centerYAnchor],
        [self.nextIndexLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:nextTextStack.trailingAnchor constant:8]
    ]];

    UIView *beginBox = [self fieldBoxWithCaption:@"Begin" field:&_beginField];
    UIView *endBox = [self fieldBoxWithCaption:@"End" field:&_endField];
    self.rangeRow = [[UIStackView alloc] initWithArrangedSubviews:@[ beginBox, endBox ]];
    self.rangeRow.axis = UILayoutConstraintAxisHorizontal;
    self.rangeRow.distribution = UIStackViewDistributionFillEqually;
    self.rangeRow.spacing = 10;

    UIColor *fill = [UIColor colorWithWhite:0.5 alpha:0.16];
    if (@available(iOS 13.0, *)) fill = PXSecondarySystemFillColor();

    self.primaryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.primaryButton.backgroundColor = [UIColor systemBlueColor];
    [self.primaryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.primaryButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.primaryButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.primaryButton.titleLabel.minimumScaleFactor = 0.85;
    self.primaryButton.layer.cornerRadius = 12;
    self.primaryButton.clipsToBounds = YES;
    [self.primaryButton setTitle:@"Lưu RRS hiện tại & Restore NEXT" forState:UIControlStateNormal];
    [self.primaryButton addTarget:self action:@selector(restoreTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.primaryButton.heightAnchor constraintEqualToConstant:50].active = YES;

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.backgroundColor = fill;
    [closeBtn setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    closeBtn.layer.cornerRadius = 12;
    closeBtn.clipsToBounds = YES;
    [closeBtn setTitle:@"Đóng" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [closeBtn.heightAnchor constraintEqualToConstant:50].active = YES;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[ title, subtitle, self.segmented, nextBox, self.rangeRow, self.primaryButton, closeBtn ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14;
    stack.alignment = UIStackViewAlignmentFill;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 11.0, *)) {
        [stack setCustomSpacing:6 afterView:title];
        [stack setCustomSpacing:8 afterView:self.primaryButton];
    }
    [card addSubview:stack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [card.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [grabber.topAnchor constraintEqualToAnchor:card.topAnchor constant:8],
        [grabber.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [grabber.widthAnchor constraintEqualToConstant:36],
        [grabber.heightAnchor constraintEqualToConstant:5],

        [stack.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:12],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [stack.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-16]
    ]];

    [self refreshAll];
}

- (UIView *)fieldBoxWithCaption:(NSString *)caption field:(UITextField * __strong *)outField {
    UIView *box = [[UIView alloc] init];
    box.translatesAutoresizingMaskIntoConstraints = NO;
    UIColor *bg = [UIColor colorWithWhite:0.95 alpha:1.0];
    if (@available(iOS 13.0, *)) bg = PXSecondarySystemBackgroundColor();
    box.backgroundColor = bg;
    box.layer.cornerRadius = 12;

    UILabel *cap = [[UILabel alloc] init];
    cap.translatesAutoresizingMaskIntoConstraints = NO;
    cap.text = [caption uppercaseString];
    cap.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    cap.textColor = PXSecondaryLabelColor();

    UITextField *tf = [[UITextField alloc] init];
    tf.translatesAutoresizingMaskIntoConstraints = NO;
    tf.keyboardType = UIKeyboardTypeNumberPad;
    tf.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    tf.textColor = [UIColor systemBlueColor];
    tf.placeholder = @"—";
    [tf addTarget:self action:@selector(rangeChanged) forControlEvents:UIControlEventEditingChanged];

    [box addSubview:cap];
    [box addSubview:tf];
    [NSLayoutConstraint activateConstraints:@[
        [cap.topAnchor constraintEqualToAnchor:box.topAnchor constant:8],
        [cap.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:12],
        [cap.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-12],
        [tf.topAnchor constraintEqualToAnchor:cap.bottomAnchor constant:2],
        [tf.leadingAnchor constraintEqualToAnchor:box.leadingAnchor constant:12],
        [tf.trailingAnchor constraintEqualToAnchor:box.trailingAnchor constant:-12],
        [tf.bottomAnchor constraintEqualToAnchor:box.bottomAnchor constant:-8]
    ]];
    if (outField) *outField = tf;
    return box;
}

- (void)refreshAll {
    NSDictionary *info = self.nextInfoProvider ? self.nextInfoProvider() : @{};
    NSInteger mode = [info[@"mode"] integerValue];
    if (mode >= 0 && mode <= 2) self.segmented.selectedSegmentIndex = mode;
    BOOL rangeMode = (mode == 2);
    self.rangeRow.hidden = !rangeMode;
    NSInteger begin = [info[@"begin"] integerValue];
    NSInteger end = [info[@"end"] integerValue];
    self.beginField.text = begin > 0 ? [NSString stringWithFormat:@"%ld", (long)begin] : @"";
    self.endField.text = end > 0 ? [NSString stringWithFormat:@"%ld", (long)end] : @"";
    [self refreshNextBox];
}

- (void)refreshNextBox {
    NSDictionary *info = self.nextInfoProvider ? self.nextInfoProvider() : @{};
    BOOL available = [info[@"available"] boolValue];
    NSString *name = info[@"name"] ?: @"—";
    NSString *size = info[@"size"] ?: @"";
    NSInteger idx = [info[@"index"] integerValue];
    self.nextNameLabel.text = available ? (size.length ? [NSString stringWithFormat:@"%@ · %@", name, size] : name) : @"Đã hết bản để restore";
    self.nextIndexLabel.text = available ? [NSString stringWithFormat:@"#%ld", (long)idx] : @"—";
    self.primaryButton.enabled = available;
    self.primaryButton.alpha = available ? 1.0 : 0.4;
}

- (void)segmentChanged {
    NSInteger mode = self.segmented.selectedSegmentIndex;
    if (self.onModeSelected) self.onModeSelected(mode);
    [self refreshAll];
}

- (void)rangeChanged {
    NSInteger b = [self.beginField.text integerValue];
    NSInteger e = [self.endField.text integerValue];
    if (self.onRangeEdited) self.onRangeEdited(b, e);
    [self refreshNextBox];
}

- (void)restoreTapped {
    if (self.onRestoreNext) self.onRestoreNext();
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)backdropTapped:(UITapGestureRecognizer *)g {
    CGPoint p = [g locationInView:self.view];
    if (self.cardRef && CGRectContainsPoint(self.cardRef.frame, p)) return;
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
