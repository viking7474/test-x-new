#import "PXRRSManagerViewController.h"
#import "WeaponXTheme.h"

#pragma mark - Helpers

static UITableViewStyle PXRRSSCompatibleInsetGrouped(void) {
    if (@available(iOS 13.0, *)) return UITableViewStyleInsetGrouped;
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
    if (@available(iOS 13.0, *)) {
        NSRelativeDateTimeFormatter *rel = [[NSRelativeDateTimeFormatter alloc] init];
        rel.unitsStyle = NSRelativeDateTimeFormatterUnitsStyleFull;
        return [rel localizedStringForDate:date relativeToDate:[NSDate date]];
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
    if (@available(iOS 13.0, *)) bg = [UIColor systemIndigoColor];
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
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
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
    secondary.backgroundColor = [UIColor tertiarySystemFillColor];
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
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    NSDictionary *e = self.entry ?: @{};
    NSString *appName = PXRRSString(e, @"appName");
    if (!appName.length) appName = @"RRS";

    if (indexPath.section == 0) {
        cell.imageView.image = PXRRSAppPlaceholder(appName);
        cell.textLabel.text = appName;
        cell.textLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        cell.detailTextLabel.text = PXRRSString(e, @"dir").lastPathComponent;
        cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
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
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        cell.textLabel.text = titles[indexPath.row];
        cell.detailTextLabel.text = values[indexPath.row];
        if (indexPath.row == 3) {
            cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
        }
        return cell;
    }
    if (indexPath.row == 0) {
        cell.textLabel.text = PXRRSString(e, @"note").length ? PXRRSString(e, @"note") : @"(không có ghi chú)";
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.textLabel.textColor = PXRRSString(e, @"note").length ? [UIColor labelColor] : [UIColor secondaryLabelColor];
        return cell;
    }
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    cell.textLabel.text = @"Checksum";
    cell.textLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    cell.detailTextLabel.text = PXRRSString(e, @"checksum").length ? PXRRSString(e, @"checksum") : @"—";
    cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    cell.detailTextLabel.numberOfLines = 3;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
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
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UISearchController *searchController;
@end

@implementation PXRRSManagerViewController

- (instancetype)init {
    return [self initWithStyle:PXRRSSCompatibleInsetGrouped()];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.selectedDirs = [NSMutableSet set];
    self.filterText = @"";

    if (@available(iOS 11.0, *)) {
        self.navigationController.navigationBar.prefersLargeTitles = YES;
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    }
    self.title = @"RRS";

    self.closeButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.left"]
                                                        style:UIBarButtonItemStylePlain
                                                       target:self
                                                       action:@selector(closeTapped)];
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
    self.tableView.estimatedRowHeight = 76;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;

    [self buildFooterBar];
    [self refreshChrome];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat h = CGRectGetHeight(self.footerContainer.bounds);
    if (h < 1) h = 90;
    UIEdgeInsets inset = self.tableView.contentInset;
    if (fabs(inset.bottom - h) > 0.5) {
        inset.bottom = h;
        self.tableView.contentInset = inset;
        self.tableView.scrollIndicatorInsets = inset;
    }
}

#pragma mark - Footer

- (void)buildFooterBar {
    self.footerContainer = [[UIView alloc] init];
    self.footerContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.footerContainer.backgroundColor = [UIColor secondarySystemBackgroundColor];
    [self.view addSubview:self.footerContainer];

    UIView *sep = [[UIView alloc] init];
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    sep.backgroundColor = [UIColor separatorColor];
    [self.footerContainer addSubview:sep];

    self.sequenceFooterButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sequenceFooterButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.sequenceFooterButton.backgroundColor = [UIColor tertiarySystemFillColor];
    [self.sequenceFooterButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    self.sequenceFooterButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.sequenceFooterButton.layer.cornerRadius = 12;
    [self.sequenceFooterButton setTitle:@"Restore theo thứ tự…" forState:UIControlStateNormal];
    [self.sequenceFooterButton addTarget:self action:@selector(presentSequenceSheet) forControlEvents:UIControlEventTouchUpInside];
    [self.footerContainer addSubview:self.sequenceFooterButton];

    self.deleteFooterButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.deleteFooterButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.deleteFooterButton.backgroundColor = [UIColor systemRedColor];
    [self.deleteFooterButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.deleteFooterButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.deleteFooterButton.layer.cornerRadius = 12;
    self.deleteFooterButton.hidden = YES;
    [self.deleteFooterButton addTarget:self action:@selector(deleteSelectedTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.footerContainer addSubview:self.deleteFooterButton];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.footerContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.footerContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.footerContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [sep.topAnchor constraintEqualToAnchor:self.footerContainer.topAnchor],
        [sep.leadingAnchor constraintEqualToAnchor:self.footerContainer.leadingAnchor],
        [sep.trailingAnchor constraintEqualToAnchor:self.footerContainer.trailingAnchor],
        [sep.heightAnchor constraintEqualToConstant:0.5],

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

- (void)reloadFromSource {
    if (self.onReload) self.entries = self.onReload() ?: @[];
    [self.selectedDirs removeAllObjects];
    [self refreshChrome];
    [self.tableView reloadData];
}

- (void)refreshChrome {
    NSUInteger count = self.entries.count;
    NSString *sub = [NSString stringWithFormat:@"%lu bản", (unsigned long)count];
    // Approximate total size if present
    self.navigationItem.prompt = sub;

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
        self.deleteFooterButton.alpha = n > 0 ? 1.0 : 0.4;
    } else {
        self.title = @"RRS";
        self.navigationItem.leftBarButtonItem = self.closeButton;
        self.navigationItem.rightBarButtonItem = self.selectButton;
        self.sequenceFooterButton.hidden = NO;
        self.deleteFooterButton.hidden = YES;
        self.selectButton.enabled = count > 0;
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
        // empty state handled via background view
        self.tableView.backgroundView = [self emptyStateView];
    } else {
        self.tableView.backgroundView = nil;
    }
    return (NSInteger)n;
}

- (UIView *)emptyStateView {
    UIView *v = [[UIView alloc] initWithFrame:self.tableView.bounds];
    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Chưa có RRS";
    title.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    title.textAlignment = NSTextAlignmentCenter;
    UILabel *sub = [[UILabel alloc] init];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.text = @"Chọn app trên Home → Lưu RRS để tạo bản đầu tiên.";
    sub.font = [UIFont systemFontOfSize:14];
    sub.textColor = [UIColor secondaryLabelColor];
    sub.textAlignment = NSTextAlignmentCenter;
    sub.numberOfLines = 0;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"externaldrive"]];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.tintColor = [UIColor tertiaryLabelColor];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    [v addSubview:icon];
    [v addSubview:title];
    [v addSubview:sub];
    [NSLayoutConstraint activateConstraints:@[
        [icon.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:v.centerYAnchor constant:-40],
        [icon.widthAnchor constraintEqualToConstant:48],
        [icon.heightAnchor constraintEqualToConstant:48],
        [title.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:12],
        [title.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:24],
        [title.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-24],
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
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];

    NSDictionary *e = [self visibleEntries][(NSUInteger)indexPath.row];
    NSString *dir = PXRRSString(e, @"dir");
    NSString *appName = PXRRSString(e, @"appName");
    if (!appName.length) appName = @"RRS";
    BOOL restored = PXRRSString(e, @"restoreDate").length > 0 && ![PXRRSString(e, @"restoreDate") isEqualToString:@"(null)"];
    BOOL isNext = (!self.editingSelection && indexPath.row == (NSInteger)self.nextIndex);

    UIImageView *icon = [[UIImageView alloc] initWithImage:PXRRSAppPlaceholder(appName)];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.layer.cornerRadius = 11;
    icon.clipsToBounds = YES;

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    title.text = appName;

    UILabel *sub = [[UILabel alloc] init];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.font = [UIFont systemFontOfSize:13];
    sub.textColor = [UIColor secondaryLabelColor];
    NSString *size = PXRRSString(e, @"size");
    NSString *when = PXRRSRelativeDate(PXRRSString(e, @"backupDate"));
    sub.text = size.length ? [NSString stringWithFormat:@"Backup %@ · %@", when, size]
                           : [NSString stringWithFormat:@"Backup %@", when];

    UILabel *note = [[UILabel alloc] init];
    note.translatesAutoresizingMaskIntoConstraints = NO;
    note.font = [UIFont italicSystemFontOfSize:13];
    note.textColor = [UIColor secondaryLabelColor];
    NSString *noteText = PXRRSString(e, @"note");
    note.text = noteText.length ? noteText : @"—";

    UIStackView *pillStack = [[UIStackView alloc] init];
    pillStack.axis = UILayoutConstraintAxisHorizontal;
    pillStack.spacing = 6;
    pillStack.alignment = UIStackViewAlignmentCenter;
    if (restored) [pillStack addArrangedSubview:[self pillWithText:@"Đã restore" color:[UIColor systemTealColor]]];
    if (isNext) [pillStack addArrangedSubview:[self pillWithText:@"NEXT" color:[UIColor systemBlueColor]]];

    UIStackView *titleRow = [[UIStackView alloc] initWithArrangedSubviews:@[title, pillStack]];
    titleRow.axis = UILayoutConstraintAxisHorizontal;
    titleRow.spacing = 6;
    titleRow.alignment = UIStackViewAlignmentCenter;

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[titleRow, sub, note]];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 2;
    textStack.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *chev = [[UILabel alloc] init];
    chev.translatesAutoresizingMaskIntoConstraints = NO;
    chev.text = @"›";
    chev.font = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
    chev.textColor = [UIColor tertiaryLabelColor];
    chev.hidden = self.editingSelection;

    [cell.contentView addSubview:icon];
    [cell.contentView addSubview:textStack];
    [cell.contentView addSubview:chev];

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [icon.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:44],
        [icon.heightAnchor constraintEqualToConstant:44],

        [textStack.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12],
        [textStack.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
        [textStack.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
        [textStack.trailingAnchor constraintEqualToAnchor:chev.leadingAnchor constant:-8],

        [chev.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-14],
        [chev.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [chev.widthAnchor constraintEqualToConstant:14]
    ]];

    if (self.editingSelection && [self.selectedDirs containsObject:dir]) {
        [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
    return cell;
}

- (UILabel *)pillWithText:(NSString *)text color:(UIColor *)color {
    UILabel *l = [[UILabel alloc] init];
    l.text = [NSString stringWithFormat:@"  %@  ", text];
    l.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    l.textColor = color;
    l.backgroundColor = [color colorWithAlphaComponent:0.15];
    l.layer.cornerRadius = 8;
    l.clipsToBounds = YES;
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
        // Same pipeline as save+restore from parent for now (parent owns clear+restore).
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
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Restore theo thứ tự"
                                                                   message:@"Chọn cách duyệt danh sách RRS"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;

    void (^apply)(NSInteger) = ^(NSInteger mode) {
        weakSelf.sequenceMode = mode;
        if (mode == 0 || mode == 1) {
            weakSelf.nextIndex = 0;
            weakSelf.rangeBegin = 0;
            weakSelf.rangeEnd = 0;
        }
        if (mode == 2) {
            [weakSelf promptBeginEndThenRestore];
            return;
        }
        if (weakSelf.onSequenceChanged) weakSelf.onSequenceChanged(mode, weakSelf.rangeBegin, weakSelf.rangeEnd);
        if (weakSelf.onNextChanged) weakSelf.onNextChanged(weakSelf.nextIndex);
        [weakSelf refreshChrome];
        [weakSelf.tableView reloadData];
        [weakSelf confirmRestoreNext];
    };

    [sheet addAction:[UIAlertAction actionWithTitle:@"Từ đầu → cuối" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { apply(0); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Ngược lại" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { apply(1); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Theo số thứ tự (begin/end)" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { apply(2); }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Restore NEXT ngay" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        [weakSelf confirmRestoreNext];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];

    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        sheet.popoverPresentationController.sourceView = self.sequenceFooterButton;
        sheet.popoverPresentationController.sourceRect = self.sequenceFooterButton.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)promptBeginEndThenRestore {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Theo số thứ tự"
                                                                   message:@"Nhập begin/end (1-based). Để trống end = đến cuối."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"begin";
        tf.keyboardType = UIKeyboardTypeNumberPad;
        if (self.rangeBegin > 0) tf.text = [NSString stringWithFormat:@"%ld", (long)self.rangeBegin];
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"end";
        tf.keyboardType = UIKeyboardTypeNumberPad;
        if (self.rangeEnd > 0) tf.text = [NSString stringWithFormat:@"%ld", (long)self.rangeEnd];
    }];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Áp dụng & Restore" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        NSInteger begin = [alert.textFields[0].text integerValue];
        NSInteger end = [alert.textFields[1].text integerValue];
        weakSelf.sequenceMode = 2;
        weakSelf.rangeBegin = begin;
        weakSelf.rangeEnd = end;
        if (begin > 0) weakSelf.nextIndex = begin - 1;
        if (weakSelf.onSequenceChanged) weakSelf.onSequenceChanged(2, begin, end);
        if (weakSelf.onNextChanged) weakSelf.onNextChanged(weakSelf.nextIndex);
        [weakSelf refreshChrome];
        [weakSelf.tableView reloadData];
        [weakSelf confirmRestoreNext];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)confirmRestoreNext {
    NSArray *visible = [self visibleEntries];
    if (!visible.count) {
        [self showMessage:@"Chưa có RRS" message:@"Không có file RRS để restore."];
        return;
    }
    NSInteger idx = self.nextIndex;
    if (self.sequenceMode == 1) {
        // newest first: reverse index into visible
        idx = (NSInteger)visible.count - 1 - self.nextIndex;
    }
    if (self.rangeEnd > 0 && self.nextIndex >= self.rangeEnd) {
        [self showMessage:@"Đã hết RRS" message:[NSString stringWithFormat:@"Vị trí hiện tại đã vượt end (%ld).", (long)self.rangeEnd]];
        return;
    }
    if (idx < 0 || idx >= (NSInteger)visible.count) {
        [self showMessage:@"Thiếu RRS" message:@"Không tìm thấy file RRS theo vị trí NEXT."];
        return;
    }
    NSDictionary *target = visible[(NSUInteger)idx];
    NSString *name = PXRRSString(target, @"appName");
    NSString *dir = PXRRSString(target, @"dir");
    NSString *msg = [NSString stringWithFormat:@"NEXT #%@ · %@\n%@",
                     [NSString stringWithFormat:@"%ld", (long)(self.nextIndex + 1)],
                     name.length ? name : @"RRS",
                     PXRRSString(target, @"size")];
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
