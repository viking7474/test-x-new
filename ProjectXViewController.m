#import "ProjectX.h"
#import "IdentifierManager.h"
#import "UptimeManager.h"
#import "CopyHelper.h"
#import "BottomButtons.h"
#import "FreezeManager.h"
#import "AppDataCleaner.h"
#import "AppEntitlementsReader.h"
#import "KeychainGroupsViewController.h"
#import "AppVersionManager.h"
#import "ProfileButtonsView.h"
#import "ProfileManagerViewController.h"
#import "ProfileCreationViewController.h"
#import "ProfileManager.h"
#import "StorageManager.h"
#import "BatteryManager.h"
#import "AppDataBackupRestoreViewController.h"
#import "AppDataBackupManager.h"
#import "ToolViewController.h"
#import "NetworkManager.h"
#import "PXPaths.h"
#import <UIKit/UIKit.h>
#import "ProgressHUDView.h"
#import <spawn.h>
#import <sys/wait.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import "common/UIButton+SafeConfiguration.h"

static NSString *PXKeychainWipeEnabledKey(NSString *bundleID);
static NSString *PXKeychainWipeGroupsKey(NSString *bundleID);

static NSString * const PXKeychainGroupsSavedNotification = @"com.hydra.projectx.keychainGroupsSaved";
static NSString * const PXDashboardResetAppsKey = @"PXDashboardResetApps";
static NSString * const PXDashboardRRSAppsKey = @"PXDashboardRRSApps";
static NSString * const PXDashboardFakeOptionsKey = @"PXDashboardFakeOptions";
static NSString * const PXDashboardFakePreviewKey = @"PXDashboardFakePreview";
static NSString * const PXDashboardRestoreOrderKey = @"PXDashboardRestoreOrder";
static NSString * const PXDashboardRestoreIndexKeyPrefix = @"PXDashboardRestoreIndex_";
static NSString * const PXDashboardRestoreEndKeyPrefix = @"PXDashboardRestoreEnd_";

static UITableViewStyle PXCompatibleInsetGroupedStyle(void) {
    if (@available(iOS 13.0, *)) return UITableViewStyleInsetGrouped;
    return UITableViewStyleGrouped;
}

static UIImage *PXDrawCircleIcon(BOOL drawX, BOOL drawMinus) {
    CGSize size = CGSizeMake(24, 24);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) {
        return nil;
    }

    CGContextSetLineWidth(ctx, 2.0);
    CGContextSetStrokeColorWithColor(ctx, [UIColor blackColor].CGColor);
    CGRect circleRect = CGRectInset((CGRect){CGPointZero, size}, 2.0, 2.0);
    CGContextStrokeEllipseInRect(ctx, circleRect);

    if (drawX) {
        CGContextMoveToPoint(ctx, 7.0, 7.0);
        CGContextAddLineToPoint(ctx, 17.0, 17.0);
        CGContextMoveToPoint(ctx, 17.0, 7.0);
        CGContextAddLineToPoint(ctx, 7.0, 17.0);
        CGContextStrokePath(ctx);
    } else if (drawMinus) {
        CGContextMoveToPoint(ctx, 7.0, 12.0);
        CGContextAddLineToPoint(ctx, 17.0, 12.0);
        CGContextStrokePath(ctx);
    }

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

static UIImage *PXClearDataIcon(void) {
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"externaldrive.fill.badge.minus"];
        if (img) return img;
    }
    return PXDrawCircleIcon(NO, YES);
}

static UIImage *PXRemoveFromScopeIcon(void) {
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"trash.slash.circle.fill"];
        if (img) return img;
    }
    return PXDrawCircleIcon(YES, NO);
}

// Add missing methods via category
@interface LSApplicationWorkspace (ProjectX)
- (NSArray *)allInstalledApplications;
@end

// Add missing properties via category
@interface LSApplicationProxy (ProjectX)
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSString *bundleIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSString *shortVersionString;
@property (nonatomic, readonly) NSString *buildVersionString;  // Add this line to get build number
@end

@interface ProjectXViewController () <UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UIScrollViewDelegate, ProfileCreationViewControllerDelegate>
@property (nonatomic, strong) ProgressHUDView *progressHUD;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *mainStackView;
@property (nonatomic, strong) UIStackView *appsStackView;
@property (nonatomic, strong) UITextField *bundleIDTextField;
@property (nonatomic, strong) FreezeManager *freezeManager;
@property (nonatomic, strong) NSMutableDictionary *appSwitches;
@property (nonatomic, strong) NSMutableDictionary *identifierSwitches;
@property (nonatomic, strong) UITableView *appsTableView;
@property (nonatomic, strong) UIViewController *installedAppsPopupVC;
@property (nonatomic, strong) UITableView *installedAppsTableView;
@property (nonatomic, strong) UISearchBar *appSearchBar;
@property (nonatomic, strong) NSArray *installedApps;
@property (nonatomic, strong) NSArray *filteredApps;
@property (nonatomic, strong) UIViewController *versionsPopupVC;
@property (nonatomic, strong) UITableView *versionsTableView;
@property (nonatomic, strong) NSArray *appVersions;
@property (nonatomic, strong) NSString *selectedBundleID;
@property (nonatomic, strong) UISearchBar *versionSearchBar;
@property (nonatomic, strong) NSArray *filteredVersions;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) NSCache *iconCache;
@property (nonatomic, weak) UIButton *pendingClearDataSender;
@property (nonatomic, copy) NSString *pendingClearDataBundleID;
@property (nonatomic, copy) NSString *pendingClearDataSizeStr;
@property (nonatomic, copy) NSString *pendingClearDataDetailsStr;
@property (nonatomic, strong) NSArray *scopedApps;
@property (nonatomic, strong) UIButton *scrollToBottomButton;

// Trial offer banner properties
@property (nonatomic, strong) UIView *trialOfferBannerView;
@property (nonatomic, strong) UIButton *getTrialButton;
@property (nonatomic, assign) BOOL hasShownTrialOffer;
@property (nonatomic, assign) BOOL hasPlan;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

// Method declarations
- (void)showError:(NSError *)error;
- (void)killEnabledAppsAndRespring;
- (void)loadSettings;
- (void)setupUI;
- (void)addIdentifierSection:(NSString *)type title:(NSString *)title;
- (void)addAppManagementSection;
- (UIView *)createSectionHeaderWithTitle:(NSString *)title;
- (void)updateAppsList;
- (instancetype)init;
- (void)fetchAppIconForBundleID:(NSString *)bundleID completion:(void (^)(UIImage *icon))completion;
- (UIImage *)createNotInAppStoreImage;
- (void)installAppWithAdamId:(NSString *)adamId appExtVrsId:(NSString *)appExtVrsId bundleID:(NSString *)bundleID appName:(NSString *)appName version:(NSString *)version;

// Add this new method to directly update identifier values
- (void)directUpdateIdentifierValue:(NSString *)identifierType withValue:(NSString *)value;


- (BOOL)checkTrialOfferEligibility;
- (void)getTrialButtonTapped;
- (void)hideTrialOfferBanner;

// Helper methods for finding view controllers
- (UIViewController *)findTopViewController;
- (UITabBarController *)findTabBarController;

@property (nonatomic, strong) ProfileButtonsView *profileButtonsView;
@property (nonatomic, strong) NSMutableArray *profiles;

// Profile Management Methods
- (void)setupProfileButtons;
- (void)setupProfileManagement;
- (void)showProfileCreation;
- (void)showProfileManager;

// Profile Indicator
@property (nonatomic, strong) UIView *profileIndicatorView;

// Add helper methods for finding buttons by tag
- (UIButton *)buttonWithTag:(NSInteger)tag;
- (NSArray *)findSubviewsOfClass:(Class)cls inView:(UIView *)view;

- (void)addApplicationWithExtensionsToScope:(NSString *)bundleID;

// Add loadScopedApps method
- (void)loadScopedApps;

// Add property to track advanced identifiers visibility in the @interface section
@property (nonatomic, assign) BOOL showAdvancedIdentifiers;
@property (nonatomic, strong) UIButton *showAdvancedButton;
@property (nonatomic, strong) NSMutableArray *advancedIdentifierViews;

@property (nonatomic, strong) NSMutableArray<NSString *> *selectedResetAppIDs;
@property (nonatomic, strong) NSMutableArray<NSString *> *selectedRRSAppIDs;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectionDraftAppIDs;
@property (nonatomic, copy) NSString *selectionPickerMode;
@property (nonatomic, strong) UILabel *resetSelectionValueLabel;
@property (nonatomic, strong) UILabel *rrsSelectionValueLabel;
@property (nonatomic, strong) UILabel *fakeSelectionValueLabel;
@property (nonatomic, strong) UILabel *fakeInfoSelectionValueLabel;
@property (nonatomic, strong) UITextField *rrsNoteTextField;
@property (nonatomic, strong) NSDictionary *nextFakeOptions;
@property (nonatomic, strong) NSDictionary *nextFakePreview;
@property (nonatomic, copy) NSString *rrsRestoreOrder;

// Modify setupUI method to add a "Show Advanced" button and initially hide the advanced identifier sections
- (void)setupUI;

// Add methods for the show advanced button and advanced identifier sections
- (void)addShowAdvancedButton;

// Add a version of addIdentifierSection that adds to our tracking array and hides them initially
- (void)addAdvancedIdentifierSection:(NSString *)type title:(NSString *)title;

// Handle toggle of advanced identifiers
- (void)toggleAdvancedIdentifiers:(UIButton *)sender;
@end

@interface PXFakeSelectionViewController : UITableViewController
@property (nonatomic, copy) NSDictionary *options;
@property (nonatomic, copy) NSDictionary *preview;
@property (nonatomic, copy) void (^onDone)(NSDictionary *options, NSDictionary *preview);
@end

@implementation PXFakeSelectionViewController

- (NSMutableDictionary *)mutableOptions {
    NSMutableDictionary *dict = [self.options mutableCopy] ?: [NSMutableDictionary dictionary];
    if (!dict[@"fakeIOSVersionEnabled"]) dict[@"fakeIOSVersionEnabled"] = @(YES);
    if (!dict[@"fakeModelEnabled"]) dict[@"fakeModelEnabled"] = @(YES);
    return dict;
}

- (BOOL)boolOption:(NSString *)key defaultValue:(BOOL)defaultValue {
    id value = self.options[key];
    return value ? [value boolValue] : defaultValue;
}

- (void)setBoolOption:(NSString *)key value:(BOOL)value {
    NSMutableDictionary *dict = [self mutableOptions];
    dict[key] = @(value);
    self.options = dict;
    [self.tableView reloadData];
}

- (NSArray<NSDictionary *> *)models {
    return @[
        @{ @"name": @"iPhone X", @"id": @"iPhone10,3", @"modelNumber": @"MQA52LL/A" },
        @{ @"name": @"iPhone XR", @"id": @"iPhone11,8", @"modelNumber": @"MRY42LL/A" },
        @{ @"name": @"iPhone XS", @"id": @"iPhone11,2", @"modelNumber": @"MT9E2LL/A" },
        @{ @"name": @"iPhone 11", @"id": @"iPhone12,1", @"modelNumber": @"MWKM2LL/A" },
        @{ @"name": @"iPhone 11 Pro", @"id": @"iPhone12,3", @"modelNumber": @"MWC22LL/A" },
        @{ @"name": @"iPhone 12", @"id": @"iPhone13,2", @"modelNumber": @"MGJ53LL/A" },
        @{ @"name": @"iPhone 12 Pro", @"id": @"iPhone13,3", @"modelNumber": @"MGMK3LL/A" },
        @{ @"name": @"iPhone 13", @"id": @"iPhone14,5", @"modelNumber": @"MLPF3LL/A" },
        @{ @"name": @"iPhone 13 Pro", @"id": @"iPhone14,2", @"modelNumber": @"MLTP3LL/A" },
        @{ @"name": @"iPhone 14", @"id": @"iPhone14,7", @"modelNumber": @"MPVN3LL/A" },
        @{ @"name": @"iPhone 14 Pro", @"id": @"iPhone15,2", @"modelNumber": @"MQ0E3LL/A" },
        @{ @"name": @"iPhone 15", @"id": @"iPhone15,4", @"modelNumber": @"MTP63LL/A" },
        @{ @"name": @"iPhone 15 Pro", @"id": @"iPhone16,1", @"modelNumber": @"MTV13LL/A" },
        @{ @"name": @"iPhone 15 Pro Max", @"id": @"iPhone16,2", @"modelNumber": @"MU693LL/A" }
    ];
}

- (NSArray<NSString *> *)iosVersions { return @[ @"13.7", @"14.8", @"15.4.1", @"15.7", @"16.0", @"16.3.1" ]; }

- (NSArray<NSDictionary *> *)countries {
    return @[
        @{ @"name": @"United States", @"code": @"us" },
        @{ @"name": @"Việt Nam", @"code": @"vn" },
        @{ @"name": @"Canada", @"code": @"ca" },
        @{ @"name": @"India", @"code": @"in" }
    ];
}

- (NSArray<NSDictionary *> *)carriersForCountry:(NSString *)code {
    if ([code isEqualToString:@"vn"]) {
        return @[
            @{ @"name": @"Viettel", @"mcc": @"452", @"mnc": @"04" },
            @{ @"name": @"VinaPhone", @"mcc": @"452", @"mnc": @"02" },
            @{ @"name": @"MobiFone", @"mcc": @"452", @"mnc": @"01" },
            @{ @"name": @"Vietnamobile", @"mcc": @"452", @"mnc": @"05" }
        ];
    }
    return [NetworkManager getCarriersForCountry:code ?: @"us"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Chon Fake";
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:PXCompatibleInsetGroupedStyle()];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(doneTapped)];
    UIImage *backImage = [UIImage systemImageNamed:@"chevron.left"];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:backImage style:UIBarButtonItemStylePlain target:self action:@selector(cancelTapped)];
    self.options = [self mutableOptions];
    if (!self.preview) self.preview = @{};
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? 7 : 4; }
- (NSInteger)fakeRowForIndexPath:(NSIndexPath *)indexPath { return indexPath.section == 0 ? indexPath.row : indexPath.row + 7; }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger row = [self fakeRowForIndexPath:indexPath];
    if (row == 1 || row == 3) return 52;
    if (row == 8) return 34;
    return 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger row = [self fakeRowForIndexPath:indexPath];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    cell.textLabel.font = [UIFont systemFontOfSize:(row == 4 || row == 5 || row == 9) ? 14 : 15 weight:UIFontWeightSemibold];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
    cell.detailTextLabel.textColor = [UIColor systemBlueColor];
    cell.indentationWidth = 24;
    if (row == 4 || row == 5 || row == 9) cell.indentationLevel = 1;

    if (row == 0) [self configureCheckboxCell:cell title:@"1. Fake iOS Version" key:@"fakeIOSVersionEnabled" defaultValue:YES];
    else if (row == 1) [self configureRangeCell:cell text:[self iosRangeText]];
    else if (row == 2) [self configureCheckboxCell:cell title:@"2. Fake Model" key:@"fakeModelEnabled" defaultValue:YES];
    else if (row == 3) [self configureRangeCell:cell text:[self modelRangeText]];
    else if (row == 4) [self configureCheckboxCell:cell title:@"2.1 Fake Screen Size" key:@"fakeScreenSizeEnabled" defaultValue:NO];
    else if (row == 5) [self configureCheckboxCell:cell title:@"2.2 Fake Full Screen" key:@"fakeFullScreenEnabled" defaultValue:NO];
    else if (row == 6) [self configureCheckboxCell:cell title:@"3. Fake Name" key:@"fakeNameEnabled" defaultValue:NO];
    else if (row == 7) [self configureCheckboxCell:cell title:@"4. Check IP Address" key:@"checkIPEnabled" defaultValue:NO];
    else if (row == 8) { cell.textLabel.text = [NSString stringWithFormat:@"🌐 Chọn server: %@", self.options[@"ipServer"] ?: @"ip-api.com"]; cell.textLabel.textColor = [UIColor systemBlueColor]; cell.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium]; }
    else if (row == 9) [self configureCheckboxCell:cell title:@"5. Fake GPS Location" key:@"fakeGPSEnabled" defaultValue:NO];
    else [self configureRadioCell:cell title:@"Ngẫu nhiên theo ip address" key:@"gpsRandomByIPEnabled" defaultValue:NO];
    return cell;
}

- (void)configureCheckboxCell:(UITableViewCell *)cell title:(NSString *)title key:(NSString *)key defaultValue:(BOOL)defaultValue {
    BOOL checked = [self boolOption:key defaultValue:defaultValue];
    UIImage *image = [UIImage systemImageNamed:checked ? @"checkmark.square.fill" : @"square"];
    cell.imageView.image = image;
    cell.imageView.tintColor = checked ? [UIColor systemBlueColor] : [UIColor systemGray3Color];
    cell.textLabel.text = title;
    cell.accessoryType = UITableViewCellAccessoryNone;
}

- (void)configureRadioCell:(UITableViewCell *)cell title:(NSString *)title key:(NSString *)key defaultValue:(BOOL)defaultValue {
    BOOL checked = [self boolOption:key defaultValue:defaultValue];
    UIImage *image = [UIImage systemImageNamed:checked ? @"largecircle.fill.circle" : @"circle"];
    cell.imageView.image = image;
    cell.imageView.tintColor = checked ? [UIColor systemBlueColor] : [UIColor systemGray3Color];
    cell.textLabel.text = title;
    cell.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    cell.textLabel.textColor = [UIColor secondaryLabelColor];
    cell.indentationLevel = 1;
    cell.accessoryType = UITableViewCellAccessoryNone;
}

- (void)configureRangeCell:(UITableViewCell *)cell text:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor systemBlueColor];
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    label.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
    label.layer.borderColor = [UIColor separatorColor].CGColor;
    label.layer.borderWidth = 1.0;
    label.layer.cornerRadius = 7;
    label.clipsToBounds = YES;
    [cell.contentView addSubview:label];
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    chevron.tintColor = [UIColor systemBlueColor];
    [cell.contentView addSubview:chevron];
    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:8],
        [label.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:46],
        [label.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [label.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8],
        [chevron.centerYAnchor constraintEqualToAnchor:label.centerYAnchor],
        [chevron.trailingAnchor constraintEqualToAnchor:label.trailingAnchor constant:-14],
        [chevron.widthAnchor constraintEqualToConstant:12],
        [chevron.heightAnchor constraintEqualToConstant:12]
    ]];
}

- (NSString *)iosRangeText {
    NSString *min = self.options[@"iosMin"];
    NSString *max = self.options[@"iosMax"];
    if (!min.length && !max.length) return @"Random iOS version";
    return [NSString stringWithFormat:@"Từ %@ đến %@", min.length ? min : @"Random", max.length ? max : @"Random"];
}

- (NSString *)modelRangeText {
    NSInteger minIdx = [self.options[@"modelMinIndex"] integerValue];
    NSInteger maxIdx = [self.options[@"modelMaxIndex"] integerValue];
    NSArray *models = [self models];
    if (minIdx <= 0 && maxIdx <= 0) return @"Random iPhone model";
    if (minIdx <= 0) minIdx = 1;
    if (maxIdx <= 0 || maxIdx > (NSInteger)models.count) maxIdx = (NSInteger)models.count;
    NSDictionary *minModel = models[(NSUInteger)minIdx - 1];
    NSDictionary *maxModel = models[(NSUInteger)maxIdx - 1];
    return [NSString stringWithFormat:@"Từ %ld %@ đến %ld %@", (long)minIdx, minModel[@"name"], (long)maxIdx, maxModel[@"name"]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSInteger row = [self fakeRowForIndexPath:indexPath];
    NSDictionary *toggleKeys = @{
        @0: @"fakeIOSVersionEnabled",
        @2: @"fakeModelEnabled",
        @4: @"fakeScreenSizeEnabled",
        @5: @"fakeFullScreenEnabled",
        @6: @"fakeNameEnabled",
        @7: @"checkIPEnabled",
        @9: @"fakeGPSEnabled",
        @10: @"gpsRandomByIPEnabled"
    };
    if (row == 1) { [self showRangePickerWithTitle:@"Fake iOS Version" values:[self iosVersions] minKey:@"iosMin" maxKey:@"iosMax" labels:nil]; return; }
    if (row == 3) {
        NSMutableArray *labels = [NSMutableArray array];
        for (NSUInteger i = 0; i < [self models].count; i++) [labels addObject:[NSString stringWithFormat:@"%lu %@", (unsigned long)i + 1, [self models][i][@"name"]]];
        [self showRangePickerWithTitle:@"Fake Model" values:labels minKey:@"modelMinIndex" maxKey:@"modelMaxIndex" labels:labels];
        return;
    }
    if (row == 8) return;
    NSString *key = toggleKeys[@(row)];
    if (key.length) [self setBoolOption:key value:![self boolOption:key defaultValue:(row == 0 || row == 2)]];
}

- (void)showRangePickerWithTitle:(NSString *)title values:(NSArray<NSString *> *)values minKey:(NSString *)minKey maxKey:(NSString *)maxKey labels:(NSArray<NSString *> *)labels {
    UIViewController *content = [[UIViewController alloc] init];
    content.preferredContentSize = CGSizeMake(300, 190);
    UIPickerView *picker = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 0, 300, 190)];
    picker.dataSource = (id<UIPickerViewDataSource>)self;
    picker.delegate = (id<UIPickerViewDelegate>)self;
    picker.tag = [minKey isEqualToString:@"iosMin"] ? 8101 : 8102;
    objc_setAssociatedObject(picker, @"PXValues", values, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [content.view addSubview:picker];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert setValue:content forKey:@"contentViewController"];
    [alert addAction:[UIAlertAction actionWithTitle:@"Random" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        NSMutableDictionary *dict = [self mutableOptions];
        [dict removeObjectForKey:minKey];
        [dict removeObjectForKey:maxKey];
        self.options = dict;
        [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        NSInteger first = [picker selectedRowInComponent:0];
        NSInteger second = [picker selectedRowInComponent:1];
        if (first > second) { NSInteger t = first; first = second; second = t; }
        NSMutableDictionary *dict = [self mutableOptions];
        if ([minKey isEqualToString:@"modelMinIndex"]) { dict[minKey] = [NSString stringWithFormat:@"%ld", (long)first + 1]; dict[maxKey] = [NSString stringWithFormat:@"%ld", (long)second + 1]; }
        else { dict[minKey] = values[(NSUInteger)first]; dict[maxKey] = values[(NSUInteger)second]; }
        self.options = dict;
        [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView { return 2; }

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    NSArray *values = objc_getAssociatedObject(pickerView, @"PXValues");
    return values.count;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSArray *values = objc_getAssociatedObject(pickerView, @"PXValues");
    if (row < 0 || row >= (NSInteger)values.count) return @"";
    return values[(NSUInteger)row];
}

- (void)showModelPicker {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Model" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *m in [self models]) {
        NSString *title = [NSString stringWithFormat:@"%@ (%@)", m[@"name"], m[@"id"]];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { [self setModel:m]; }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentActionSheet:sheet];
}

- (void)showStringPickerWithTitle:(NSString *)title values:(NSArray<NSString *> *)values key:(NSString *)key {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSString *v in values) {
        [sheet addAction:[UIAlertAction actionWithTitle:v style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { NSMutableDictionary *p = [self.preview mutableCopy] ?: [NSMutableDictionary dictionary]; p[key] = v; self.preview = p; [self.tableView reloadData]; }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentActionSheet:sheet];
}

- (void)showCountryPicker {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Country" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *c in [self countries]) {
        [sheet addAction:[UIAlertAction actionWithTitle:c[@"name"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
            NSMutableDictionary *p = [self.preview mutableCopy] ?: [NSMutableDictionary dictionary];
            p[@"CountryName"] = c[@"name"]; p[@"CountryCode"] = c[@"code"]; [p removeObjectForKey:@"CarrierName"]; self.preview = p; [self.tableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentActionSheet:sheet];
}

- (void)showCarrierPicker {
    NSString *countryCode = self.preview[@"CountryCode"] ?: @"us";
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Carrier" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *carrier in [self carriersForCountry:countryCode]) {
        [sheet addAction:[UIAlertAction actionWithTitle:carrier[@"name"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
            NSMutableDictionary *p = [self.preview mutableCopy] ?: [NSMutableDictionary dictionary];
            p[@"CarrierName"] = carrier[@"name"]; p[@"CarrierMCC"] = carrier[@"mcc"]; p[@"CarrierMNC"] = carrier[@"mnc"]; self.preview = p; [self.tableView reloadData];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentActionSheet:sheet];
}

- (void)presentActionSheet:(UIAlertController *)sheet {
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) { sheet.popoverPresentationController.sourceView = self.view; sheet.popoverPresentationController.sourceRect = self.view.bounds; }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)setModel:(NSDictionary *)m {
    NSMutableDictionary *p = [self.preview mutableCopy] ?: [NSMutableDictionary dictionary];
    p[@"DeviceModel"] = m[@"id"]; p[@"DeviceModelName"] = m[@"name"]; p[@"ModelNumber"] = m[@"modelNumber"];
    self.preview = p;
    [self.tableView reloadData];
}

- (NSString *)randomSerial {
    NSArray *prefixes = @[ @"C02", @"FVF", @"DLXJ", @"GG78", @"HC79" ];
    NSString *prefix = prefixes[arc4random_uniform((uint32_t)prefixes.count)];
    NSString *chars = @"23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
    NSMutableString *s = [prefix mutableCopy];
    for (int i = 0; i < 8; i++) [s appendFormat:@"%C", [chars characterAtIndex:arc4random_uniform((uint32_t)chars.length)]];
    return s;
}

- (NSString *)randomMAC { return [NSString stringWithFormat:@"02:%02X:%02X:%02X:%02X:%02X", arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256)]; }
- (NSString *)randomDeviceName { NSArray *names = @[ @"Stitch", @"Alex", @"Minh", @"Henry", @"Emma", @"Liam" ]; return [NSString stringWithFormat:@"iPhone của %@", names[arc4random_uniform((uint32_t)names.count)]]; }
- (void)randomDeviceNameOnly { NSMutableDictionary *p = [self.preview mutableCopy] ?: [NSMutableDictionary dictionary]; p[@"DeviceName"] = [self randomDeviceName]; self.preview = p; [self.tableView reloadData]; }

- (void)randomTapped {
    NSDictionary *model = [self models][arc4random_uniform((uint32_t)[self models].count)];
    NSDictionary *country = [self countries][arc4random_uniform((uint32_t)[self countries].count)];
    NSArray *carriers = [self carriersForCountry:country[@"code"]];
    NSDictionary *carrier = carriers.count ? carriers[arc4random_uniform((uint32_t)carriers.count)] : @{};
    NSString *ios = [self iosVersions][arc4random_uniform((uint32_t)[self iosVersions].count)];
    self.preview = @{
        @"DeviceName": [self randomDeviceName],
        @"DeviceModel": model[@"id"] ?: @"",
        @"DeviceModelName": model[@"name"] ?: @"",
        @"IOSVersion": ios,
        @"CountryName": country[@"name"] ?: @"",
        @"CountryCode": country[@"code"] ?: @"",
        @"CarrierName": carrier[@"name"] ?: @"",
        @"CarrierMCC": carrier[@"mcc"] ?: @"",
        @"CarrierMNC": carrier[@"mnc"] ?: @"",
        @"ModelNumber": model[@"modelNumber"] ?: @"",
        @"SerialNumber": [self randomSerial],
        @"MACAddress": [self randomMAC]
    };
    [self.tableView reloadData];
}

- (void)doneTapped { if (self.onDone) self.onDone(self.options ?: @{}, self.preview ?: @{}); [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)cancelTapped { [self dismissViewControllerAnimated:YES completion:nil]; }

@end

@interface PXRRSManagerViewController : UITableViewController <UISearchBarDelegate>
@property (nonatomic, copy) NSArray<NSDictionary *> *entries;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedDirs;
@property (nonatomic, copy) NSString *filterText;
@property (nonatomic, assign) NSInteger nextIndex;
@property (nonatomic, assign) NSInteger sequenceMode;
@property (nonatomic, strong) UITextField *beginTextField;
@property (nonatomic, strong) UITextField *endTextField;
@property (nonatomic, strong) UILabel *nextValueLabel;
@property (nonatomic, strong) UIButton *sequenceButton;
@property (nonatomic, copy) void (^onDelete)(NSArray<NSString *> *dirs);
@property (nonatomic, copy) void (^onSaveAndRestore)(NSString *backupDir);
@property (nonatomic, copy) void (^onSequenceChanged)(NSInteger mode, NSInteger begin, NSInteger end);
@property (nonatomic, copy) void (^onNextChanged)(NSInteger nextIndex);
@property (nonatomic, copy) NSArray<NSDictionary *> *(^onReload)(void);
@end

@implementation PXRRSManagerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [NSString stringWithFormat:@"%lu RRS", (unsigned long)self.entries.count];
    self.selectedDirs = [NSMutableSet set];
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:PXCompatibleInsetGroupedStyle()];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.left"] style:UIBarButtonItemStylePlain target:self action:@selector(closeTapped)];
    [self setupHeaderFooter];
}

- (void)setupHeaderFooter {
    CGFloat width = CGRectGetWidth(self.view.bounds);
    if (width <= 0) width = CGRectGetWidth(UIScreen.mainScreen.bounds);
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 58)];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIStackView *row = [[UIStackView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = 8;
    UIButton *selectAll = [UIButton buttonWithType:UIButtonTypeSystem];
    [selectAll setImage:[UIImage systemImageNamed:@"square"] forState:UIControlStateNormal];
    [selectAll addTarget:self action:@selector(selectAllTapped:) forControlEvents:UIControlEventTouchUpInside];
    [selectAll.widthAnchor constraintEqualToConstant:40].active = YES;
    UISearchBar *search = [[UISearchBar alloc] init];
    search.placeholder = @"Lọc RRS";
    search.delegate = self;
    UIButton *delete = [UIButton buttonWithType:UIButtonTypeSystem];
    [delete setTitle:@"Xóa" forState:UIControlStateNormal];
    delete.backgroundColor = [UIColor systemBlueColor];
    delete.tintColor = [UIColor whiteColor];
    delete.layer.cornerRadius = 8;
    delete.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [delete.widthAnchor constraintEqualToConstant:54].active = YES;
    [delete addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];
    [row addArrangedSubview:selectAll];
    [row addArrangedSubview:search];
    [row addArrangedSubview:delete];
    [header addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:header.topAnchor constant:8],
        [row.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:14],
        [row.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-14],
        [row.heightAnchor constraintEqualToConstant:44]
    ]];
    self.tableView.tableHeaderView = header;

    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 132)];
    footer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UILabel *next = [[UILabel alloc] initWithFrame:CGRectMake(18, 8, 220, 18)];
    next.text = @"NEXT:";
    next.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    [footer addSubview:next];
    self.nextValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 30, 96, 34)];
    self.nextValueLabel.textAlignment = NSTextAlignmentCenter;
    self.nextValueLabel.text = [NSString stringWithFormat:@"%ld", (long)self.nextIndex + 1];
    self.nextValueLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    self.nextValueLabel.layer.borderColor = [UIColor systemBlueColor].CGColor;
    self.nextValueLabel.layer.borderWidth = 0.6;
    self.nextValueLabel.layer.cornerRadius = 7;
    self.nextValueLabel.clipsToBounds = YES;
    [footer addSubview:self.nextValueLabel];

    self.beginTextField = [[UITextField alloc] initWithFrame:CGRectMake(126, 30, 96, 34)];
    self.beginTextField.placeholder = @"begin";
    self.beginTextField.textAlignment = NSTextAlignmentCenter;
    self.beginTextField.keyboardType = UIKeyboardTypeNumberPad;
    self.beginTextField.borderStyle = UITextBorderStyleRoundedRect;
    [footer addSubview:self.beginTextField];

    self.endTextField = [[UITextField alloc] initWithFrame:CGRectMake(234, 30, 96, 34)];
    self.endTextField.placeholder = @"end";
    self.endTextField.textAlignment = NSTextAlignmentCenter;
    self.endTextField.keyboardType = UIKeyboardTypeNumberPad;
    self.endTextField.borderStyle = UITextBorderStyleRoundedRect;
    [footer addSubview:self.endTextField];

    UIButton *saveRestore = [UIButton buttonWithType:UIButtonTypeSystem];
    saveRestore.frame = CGRectMake(18, 82, 170, 30);
    [saveRestore setTitle:@"Lưu RRS & Restore" forState:UIControlStateNormal];
    saveRestore.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [saveRestore addTarget:self action:@selector(saveRestoreTapped) forControlEvents:UIControlEventTouchUpInside];
    [footer addSubview:saveRestore];
    self.sequenceButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sequenceButton.frame = CGRectMake(200, 82, 160, 30);
    [self.sequenceButton setTitle:[NSString stringWithFormat:@"Trình tự restore: %ld", (long)self.sequenceMode] forState:UIControlStateNormal];
    self.sequenceButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.sequenceButton addTarget:self action:@selector(sequenceTapped) forControlEvents:UIControlEventTouchUpInside];
    [footer addSubview:self.sequenceButton];
    self.tableView.tableFooterView = footer;
}

- (NSArray<NSDictionary *> *)visibleEntries {
    if (!self.filterText.length) return self.entries ?: @[];
    NSPredicate *p = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *e, NSDictionary *bindings) {
        NSString *hay = [NSString stringWithFormat:@"%@ %@ %@ %@", e[@"note"] ?: @"", e[@"checksum"] ?: @"", e[@"ip"] ?: @"", e[@"appName"] ?: @""];
        return [hay rangeOfString:self.filterText options:NSCaseInsensitiveSearch].location != NSNotFound;
    }];
    return [self.entries filteredArrayUsingPredicate:p];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self visibleEntries].count; }
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath { return 112; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    NSDictionary *e = [self visibleEntries][(NSUInteger)indexPath.row];
    BOOL selected = [self.selectedDirs containsObject:e[@"dir"] ?: @""];
    cell.textLabel.text = [NSString stringWithFormat:@"%@  %ld", selected ? @"☑" : @"☐", (long)indexPath.row + 1];
    cell.textLabel.font = [UIFont systemFontOfSize:13];
    cell.detailTextLabel.numberOfLines = 5;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@\n%@\nip reset: %@\n%@\n%@", e[@"note"] ?: @"", e[@"checksum"] ?: @"", e[@"ip"] ?: @"", e[@"backupDate"] ?: @"", e[@"restoreDate"] ?: @"(null)"];
    UILabel *right = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 135, 80)];
    right.numberOfLines = 4;
    right.textAlignment = NSTextAlignmentRight;
    right.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    right.textColor = [UIColor systemBlueColor];
    right.text = [NSString stringWithFormat:@"%@\n%@", e[@"size"] ?: @"", e[@"appName"] ?: @""];
    cell.accessoryView = right;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *e = [self visibleEntries][(NSUInteger)indexPath.row];
    NSString *dir = e[@"dir"];
    if ([self.selectedDirs containsObject:dir]) [self.selectedDirs removeObject:dir]; else [self.selectedDirs addObject:dir];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText { self.filterText = searchText; [self.tableView reloadData]; }
- (void)closeTapped { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)selectAllTapped:(UIButton *)sender { if (self.selectedDirs.count == [self visibleEntries].count) [self.selectedDirs removeAllObjects]; else for (NSDictionary *e in [self visibleEntries]) [self.selectedDirs addObject:e[@"dir"]]; [self.tableView reloadData]; }
- (void)deleteTapped { if (self.onDelete) self.onDelete(self.selectedDirs.allObjects); if (self.onReload) self.entries = self.onReload(); [self.selectedDirs removeAllObjects]; self.title = [NSString stringWithFormat:@"%lu RRS", (unsigned long)self.entries.count]; [self.tableView reloadData]; }
- (void)showRRSMessage:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)refreshRRSListAfterAction {
    if (self.onReload) self.entries = self.onReload();
    self.title = [NSString stringWithFormat:@"%lu RRS", (unsigned long)self.entries.count];
    self.nextValueLabel.text = [NSString stringWithFormat:@"%ld", (long)self.nextIndex + 1];
    [self.tableView reloadData];
}

- (void)saveRestoreTapped {
    NSDictionary *target = nil;
    NSArray *visible = [self visibleEntries];
    if (!visible.count) {
        [self showRRSMessage:@"Chưa có RRS" message:@"Không có file RRS để restore."];
        return;
    }
    if (self.selectedDirs.count) {
        for (NSDictionary *e in [self visibleEntries]) {
            if ([self.selectedDirs containsObject:e[@"dir"]]) { target = e; break; }
        }
    } else {
        NSInteger begin = [self.beginTextField.text integerValue];
        NSInteger idx = begin > 0 ? begin - 1 : self.nextIndex;
        NSInteger end = [self.endTextField.text integerValue];
        if (end > 0 && idx >= end) {
            [self showRRSMessage:@"Đã hết RRS" message:[NSString stringWithFormat:@"Vị trí hiện tại đã vượt end (%ld).", (long)end]];
            return;
        }
        if (idx >= 0 && idx < (NSInteger)visible.count) target = visible[(NSUInteger)idx];
    }
    if (!target) {
        [self showRRSMessage:@"Thiếu RRS" message:@"Không tìm thấy file RRS theo vị trí đã chọn."];
        return;
    }
    if (self.onSaveAndRestore) self.onSaveAndRestore(target[@"dir"]);
    if (!self.selectedDirs.count) self.nextIndex += 1;
    if (self.onNextChanged) self.onNextChanged(self.nextIndex);
    [self refreshRRSListAfterAction];
}

- (void)sequenceTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Trình tự restore" message:@"Chọn thứ tự restore" preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    void (^applyMode)(NSInteger) = ^(NSInteger mode) {
        weakSelf.sequenceMode = mode;
        if (mode == 0) weakSelf.nextIndex = 0;
        if (mode == 1) weakSelf.nextIndex = 0;
        NSInteger begin = [weakSelf.beginTextField.text integerValue];
        NSInteger end = [weakSelf.endTextField.text integerValue];
        if (mode == 2 && begin > 0) weakSelf.nextIndex = begin - 1;
        [weakSelf.sequenceButton setTitle:[NSString stringWithFormat:@"Trình tự restore: %ld", (long)mode] forState:UIControlStateNormal];
        weakSelf.nextValueLabel.text = [NSString stringWithFormat:@"%ld", (long)weakSelf.nextIndex + 1];
        if (weakSelf.onSequenceChanged) weakSelf.onSequenceChanged(mode, begin, end);
    };
    [alert addAction:[UIAlertAction actionWithTitle:@"0. Từ đầu đến cuối" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { applyMode(0); }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"1. Ngược lại" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { applyMode(1); }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"2. Theo số thứ tự" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { applyMode(2); }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) { alert.popoverPresentationController.sourceView = self.view; alert.popoverPresentationController.sourceRect = self.view.bounds; }
    [self presentViewController:alert animated:YES completion:nil];
}

@end

@interface PXFakeInfoViewController : UITableViewController
@property (nonatomic, copy) NSDictionary *preview;
@property (nonatomic, copy) NSDictionary *(^onRandom)(void);
@property (nonatomic, copy) void (^onClose)(void);
@end

@implementation PXFakeInfoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"INFO FAKE";
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:PXCompatibleInsetGroupedStyle()];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneTapped)];
    [self setupFooter];
}

- (void)setupFooter {
    CGFloat width = CGRectGetWidth(self.view.bounds);
    if (width <= 0) width = 320;
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 74)];
    footer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor systemBlueColor];
    button.tintColor = [UIColor whiteColor];
    button.layer.cornerRadius = 12;
    button.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [button setTitle:@"Random" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(randomTapped) forControlEvents:UIControlEventTouchUpInside];
    [footer addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [button.topAnchor constraintEqualToAnchor:footer.topAnchor constant:12],
        [button.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:16],
        [button.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-16],
        [button.heightAnchor constraintEqualToConstant:48]
    ]];
    self.tableView.tableFooterView = footer;
}

- (NSArray<NSArray<NSString *> *> *)rows {
    return @[
        @[ @"Device Name", @"DeviceName" ],
        @[ @"Model", @"DeviceModel" ],
        @[ @"iOS Version", @"IOSVersion" ],
        @[ @"Country", @"CountryName" ],
        @[ @"Carrier", @"CarrierName" ],
        @[ @"Model Number", @"ModelNumber" ],
        @[ @"Serial Number", @"SerialNumber" ],
        @[ @"MAC Address", @"MACAddress" ]
    ];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self rows].count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FakeInfoCell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"FakeInfoCell"];
    NSArray *row = [self rows][(NSUInteger)indexPath.row];
    NSString *key = row[1];
    NSString *value = self.preview[key];
    if ([key isEqualToString:@"DeviceModel"] && [self.preview[@"DeviceModelName"] length] && [self.preview[@"DeviceModel"] length]) {
        value = [NSString stringWithFormat:@"%@ (%@)", self.preview[@"DeviceModelName"], self.preview[@"DeviceModel"]];
    }
    cell.textLabel.text = row[0];
    cell.detailTextLabel.text = value.length ? value : @"Random";
    cell.detailTextLabel.numberOfLines = 2;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)randomTapped {
    if (self.onRandom) self.preview = self.onRandom() ?: @{};
    [self.tableView reloadData];
}

- (void)doneTapped {
    if (self.onClose) self.onClose();
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@implementation ProjectXViewController

- (void)floatingScrollButtonTapped:(UIButton *)sender {
    CGFloat y = self.scrollView.contentOffset.y;
    CGFloat maxY = self.scrollView.contentSize.height - self.scrollView.bounds.size.height;
    if (maxY <= 0) return;
    if (y <= maxY * 0.20) {
        // Scroll to bottom
        CGFloat bottomOffset = self.scrollView.contentSize.height - self.scrollView.bounds.size.height + self.scrollView.contentInset.bottom;
        if (bottomOffset > 0) {
            [self.scrollView setContentOffset:CGPointMake(0, bottomOffset) animated:YES];
        }
    } else if (y >= maxY * 0.80) {
        // Scroll to top
        [self.scrollView setContentOffset:CGPointZero animated:YES];
    }
    // Hide the button after tap
    [UIView animateWithDuration:0.2 animations:^{
        self.scrollToBottomButton.alpha = 0.0;
    }];
}

// Show/hide scrollToBottomButton based on scroll position
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat y = scrollView.contentOffset.y;
    CGFloat maxY = scrollView.contentSize.height - scrollView.bounds.size.height;
    if (maxY <= 0) {
        self.scrollToBottomButton.alpha = 0.0;
        return;
    }
    UIImage *downArrow = [[UIImage systemImageNamed:@"arrow.down"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImage *upArrow = [[UIImage systemImageNamed:@"arrow.up"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    if (y <= maxY * 0.20) {
        // Top 20%: show button to scroll to bottom
        [self.scrollToBottomButton setImage:downArrow forState:UIControlStateNormal];
        self.scrollToBottomButton.accessibilityLabel = @"Scroll to bottom";
        [self.scrollToBottomButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        [self.scrollToBottomButton addTarget:self action:@selector(floatingScrollButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [UIView animateWithDuration:0.2 animations:^{
            self.scrollToBottomButton.alpha = 1.0;
        }];
    } else if (y >= maxY * 0.80) {
        // Bottom 20%: show button to scroll to top
        [self.scrollToBottomButton setImage:upArrow forState:UIControlStateNormal];
        self.scrollToBottomButton.accessibilityLabel = @"Scroll to top";
        [self.scrollToBottomButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
        [self.scrollToBottomButton addTarget:self action:@selector(floatingScrollButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [UIView animateWithDuration:0.2 animations:^{
            self.scrollToBottomButton.alpha = 1.0;
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self.scrollToBottomButton.alpha = 0.0;
        }];
    }
}

#pragma mark - Helper Methods

// Helper method to find top view controller without using keyWindow
- (UIViewController *)findTopViewController {
    UIViewController *rootVC = nil;
    
    // Get the key window using the modern approach for iOS 13+
    if (@available(iOS 13.0, *)) {
        NSSet<UIScene *> *connectedScenes = [UIApplication sharedApplication].connectedScenes;
        for (UIScene *scene in connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        rootVC = window.rootViewController;
                        break;
                    }
                }
                if (rootVC) break;
            }
        }
        
        // Fallback if we couldn't find the key window
        if (!rootVC) {
            UIWindowScene *windowScene = (UIWindowScene *)[connectedScenes anyObject];
            rootVC = windowScene.windows.firstObject.rootViewController;
        }
    } else {
        // Fallback for iOS 12 and below (though this is less likely to be used in iOS 15)
        rootVC = [UIApplication sharedApplication].delegate.window.rootViewController;
    }
    
    // Navigate through presented view controllers to find the topmost one
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    
    return rootVC;
}

- (UIViewController *)findTopViewControllerFromViewController:(UIViewController *)viewController {
    if (viewController.presentedViewController) {
        return [self findTopViewControllerFromViewController:viewController.presentedViewController];
    } else if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)viewController;
        return [self findTopViewControllerFromViewController:navigationController.topViewController];
    } else if ([viewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabController = (UITabBarController *)viewController;
        return [self findTopViewControllerFromViewController:tabController.selectedViewController];
    } else {
        return viewController;
    }
}

- (UITabBarController *)findTabBarController {
    UIViewController *rootViewController = [self findTopViewController];
    
    // Check if root is a tab bar controller
    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        return (UITabBarController *)rootViewController;
    }
    
    // Check if root is a navigation controller with a tab bar controller
    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navController = (UINavigationController *)rootViewController;
        if ([navController.viewControllers.firstObject isKindOfClass:[UITabBarController class]]) {
            return (UITabBarController *)navController.viewControllers.firstObject;
        }
    }
    
    // Check if tab bar controller is presented
    if ([rootViewController.presentedViewController isKindOfClass:[UITabBarController class]]) {
        return (UITabBarController *)rootViewController.presentedViewController;
    }
    
    return nil;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.installedAppsTableView) {
        return self.filteredApps.count;
    } else if (tableView == self.versionsTableView) {
        return self.filteredVersions.count;
    }
    return self.appSwitches.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.installedAppsTableView) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"InstalledAppCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"InstalledAppCell"];
        }
        
        NSDictionary *app = self.filteredApps[indexPath.row];
        cell.textLabel.text = app[@"name"];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (v%@)", app[@"bundleID"], app[@"version"]];
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        if (self.selectionPickerMode.length) {
            NSString *bundleID = app[@"bundleID"];
            cell.accessoryType = [self.selectionDraftAppIDs containsObject:bundleID] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        
        return cell;
    } else if (tableView == self.versionsTableView) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"VersionCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"VersionCell"];
        }
        
        // Clear existing content
        for (UIView *view in cell.contentView.subviews) {
            [view removeFromSuperview];
        }
        
        NSDictionary *version = self.filteredVersions[indexPath.row];
        NSString *releaseDate = version[@"releaseDate"];
        NSString *appName = version[@"appName"];
        
        // Truncate app name to 15 characters
        if (appName.length > 15) {
            appName = [[appName substringToIndex:15] stringByAppendingString:@"..."];
        }
        
        // Format the date for display
        NSString *formattedDate = @"Unknown";
        if (![releaseDate isEqualToString:@"Unknown"]) {
            // Try parsing as ISO 8601 date string first
            NSDateFormatter *isoFormatter = [[NSDateFormatter alloc] init];
            isoFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
            NSDate *date = [isoFormatter dateFromString:releaseDate];
            
            // If that fails, try parsing as "yyyy-MM-dd HH:mm:ss" format
            if (!date) {
                NSDateFormatter *altFormatter = [[NSDateFormatter alloc] init];
                altFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
                date = [altFormatter dateFromString:releaseDate];
            }
            
            // If that fails, try parsing as timestamp
            if (!date && releaseDate.length > 0) {
                NSTimeInterval timestamp = [releaseDate doubleValue];
                if (timestamp > 0) {
                    date = [NSDate dateWithTimeIntervalSince1970:timestamp];
                }
            }
            
            if (date) {
                if (!self.dateFormatter) {
                    self.dateFormatter = [[NSDateFormatter alloc] init];
                    self.dateFormatter.dateFormat = @"MMM d, yyyy";
                }
                formattedDate = [self.dateFormatter stringFromDate:date];
            }
        }
        
        // Create main content view
        UIView *contentContainer = [[UIView alloc] init];
        contentContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:contentContainer];
        
        // Version label
        UILabel *versionLabel = [[UILabel alloc] init];
        versionLabel.text = version[@"version"];
        versionLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
        versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [contentContainer addSubview:versionLabel];
        
        // Date label
        UILabel *dateLabel = [[UILabel alloc] init];
        dateLabel.text = formattedDate;
        dateLabel.font = [UIFont systemFontOfSize:12];
        dateLabel.textColor = [UIColor secondaryLabelColor];
        dateLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [contentContainer addSubview:dateLabel];
        
        // Install button
        UIButton *installButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [installButton setTitle:[NSString stringWithFormat:@"Install %@", appName] forState:UIControlStateNormal];
        installButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        installButton.tag = indexPath.row;
        [installButton addTarget:self action:@selector(installButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        installButton.translatesAutoresizingMaskIntoConstraints = NO;
        [contentContainer addSubview:installButton];
        
        // Highlight installed version by comparing to installed version from plist
        // --- Begin: Robust installed version fetch (rootless/jailbreak aware, same as AppVersionSpoofingViewController) ---
        NSString *installedVersion = nil;
        NSString *prefsPath = @"/var/mobile/Library/Preferences";
        NSString *scopedAppsFile = [prefsPath stringByAppendingPathComponent:@"com.hydra.projectx.global_scope.plist"];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:prefsPath]) {
            // Try Dopamine 2 path
            prefsPath = @"/private/var/mobile/Library/Preferences";
            scopedAppsFile = [prefsPath stringByAppendingPathComponent:@"com.hydra.projectx.global_scope.plist"];
            if (![fileManager fileExistsAtPath:prefsPath]) {
                prefsPath = @"/var/mobile/Library/Preferences";
                scopedAppsFile = [prefsPath stringByAppendingPathComponent:@"com.hydra.projectx.global_scope.plist"];
            }
        }
        NSDictionary *scopedAppsDict = [NSDictionary dictionaryWithContentsOfFile:scopedAppsFile];
        NSDictionary *savedApps = scopedAppsDict[@"ScopedApps"];
        if (savedApps && self.selectedBundleID) {
            NSDictionary *appInfo = savedApps[self.selectedBundleID];
            if ([appInfo isKindOfClass:[NSDictionary class]]) {
                installedVersion = appInfo[@"version"];
            }
        }
        // --- End: Robust installed version fetch ---
        BOOL isHighlighted = (installedVersion && [version[@"version"] isEqualToString:installedVersion]);
        if (isHighlighted) {
            contentContainer.backgroundColor = [UIColor colorWithRed:0.90 green:0.97 blue:1.0 alpha:1.0];
            contentContainer.layer.cornerRadius = 10;
            contentContainer.layer.borderWidth = 1.5;
            contentContainer.layer.borderColor = [UIColor colorWithRed:0.20 green:0.60 blue:1.0 alpha:0.35].CGColor;
            versionLabel.textColor = [UIColor systemBlueColor];
            dateLabel.textColor = [UIColor systemBlueColor];
        } else {
            contentContainer.backgroundColor = [UIColor clearColor];
            contentContainer.layer.cornerRadius = 0;
            contentContainer.layer.borderWidth = 0;
            versionLabel.textColor = [UIColor labelColor];
            dateLabel.textColor = [UIColor secondaryLabelColor];
        }
        
        // Setup constraints
        CGFloat topPad = isHighlighted ? 0 : 8;
        CGFloat leftPad = isHighlighted ? 0 : 16;
        CGFloat rightPad = isHighlighted ? 0 : -16;
        CGFloat bottomPad = isHighlighted ? 0 : -8;
        [NSLayoutConstraint activateConstraints:@[
            // Container constraints
            [contentContainer.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:topPad],
            [contentContainer.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:leftPad],
            [contentContainer.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:rightPad],
            [contentContainer.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:bottomPad],
            
            // Version label constraints
            [versionLabel.topAnchor constraintEqualToAnchor:contentContainer.topAnchor],
            [versionLabel.leadingAnchor constraintEqualToAnchor:contentContainer.leadingAnchor],
            
            // Date label constraints
            [dateLabel.topAnchor constraintEqualToAnchor:versionLabel.bottomAnchor constant:2],
            [dateLabel.leadingAnchor constraintEqualToAnchor:contentContainer.leadingAnchor],
            [dateLabel.bottomAnchor constraintEqualToAnchor:contentContainer.bottomAnchor],
            
            // Install button constraints
            [installButton.centerYAnchor constraintEqualToAnchor:contentContainer.centerYAnchor],
            [installButton.trailingAnchor constraintEqualToAnchor:contentContainer.trailingAnchor],
            [installButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:versionLabel.trailingAnchor constant:8]
        ]];
        
        return cell;
    }
    
    // Return cell for app switches table
    static NSString *cellIdentifier = @"AppCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
        cell.backgroundColor = [UIColor systemBackgroundColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    // Clear existing subviews to prevent stacking
    for (UIView *view in cell.contentView.subviews) {
        [view removeFromSuperview];
    }
    
    NSString *bundleID = self.appSwitches.allKeys[indexPath.row];
    // Use original bundle ID from app info to preserve case
    NSDictionary *appInfo = [self.manager getApplicationInfo:bundleID];
    NSString *displayBundleID = appInfo[@"bundleID"] ?: bundleID;
    
    // Create app view container
    UIView *appView = [[UIView alloc] init];
    appView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    appView.layer.cornerRadius = 8;
    appView.clipsToBounds = YES;
    
    // Create background icon view with blur
    UIImageView *iconBackgroundView = [[UIImageView alloc] init];
    iconBackgroundView.contentMode = UIViewContentModeScaleAspectFit;
    iconBackgroundView.alpha = 0.3; // 30% opacity
    iconBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    [appView addSubview:iconBackgroundView];
    
    // Add blur effect
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.alpha = 0.7; // Adjust blur intensity
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [appView addSubview:blurView];
    
    // Create stack view for app content
    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = 8;
    contentStack.layoutMargins = UIEdgeInsetsMake(12, 12, 12, 12);
    contentStack.layoutMarginsRelativeArrangement = YES;
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [appView addSubview:contentStack];
    
    // Setup constraints for background icon and blur
    [NSLayoutConstraint activateConstraints:@[
        [iconBackgroundView.centerXAnchor constraintEqualToAnchor:appView.centerXAnchor],
        [iconBackgroundView.centerYAnchor constraintEqualToAnchor:appView.centerYAnchor],
        [iconBackgroundView.widthAnchor constraintEqualToAnchor:appView.widthAnchor multiplier:0.3], // Reduced to 30%
        [iconBackgroundView.heightAnchor constraintEqualToAnchor:iconBackgroundView.widthAnchor],
        
        [blurView.topAnchor constraintEqualToAnchor:appView.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:appView.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:appView.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:appView.bottomAnchor],
        
        [contentStack.topAnchor constraintEqualToAnchor:appView.topAnchor],
        [contentStack.leadingAnchor constraintEqualToAnchor:appView.leadingAnchor],
        [contentStack.trailingAnchor constraintEqualToAnchor:appView.trailingAnchor],
        [contentStack.bottomAnchor constraintEqualToAnchor:appView.bottomAnchor]
    ]];
    
    // Fetch and set app icon
    [self fetchAppIconForBundleID:bundleID completion:^(UIImage *icon) {
        iconBackgroundView.image = icon;
    }];
    
    // Create bundle ID with copy button
    UIStackView *bundleStack = [[UIStackView alloc] init];
    bundleStack.axis = UILayoutConstraintAxisHorizontal;
    bundleStack.spacing = 4;  // Reduced spacing
    bundleStack.alignment = UIStackViewAlignmentCenter;
    
    // Add extension button with smaller size
    UIButton *extensionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *plusImage = [[UIImage systemImageNamed:@"plus.circle.fill"] imageWithConfiguration:
                         [UIImageSymbolConfiguration configurationWithPointSize:14.0]];  // Reduced size
    [extensionButton setImage:plusImage forState:UIControlStateNormal];
    extensionButton.tintColor = [UIColor systemBlueColor];
    extensionButton.tag = [self.appSwitches.allKeys indexOfObject:bundleID];
    [extensionButton addTarget:self action:@selector(extensionButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // Set fixed size for extension button
    [extensionButton.heightAnchor constraintEqualToConstant:16].active = YES;  // Fixed height
    [extensionButton.widthAnchor constraintEqualToConstant:16].active = YES;   // Fixed width
    extensionButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    // Add to stack with no extra padding
    [bundleStack setCustomSpacing:2 afterView:extensionButton];  // Minimal spacing after button
    [bundleStack addArrangedSubview:extensionButton];
    
    UILabel *bundleLabel = [[UILabel alloc] init];
    bundleLabel.text = displayBundleID;
    bundleLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    bundleLabel.numberOfLines = 1;
    bundleLabel.adjustsFontSizeToFitWidth = YES;
    bundleLabel.minimumScaleFactor = 0.75;
    [bundleStack addArrangedSubview:bundleLabel];
    
    UIButton *copyButton = [CopyHelper createCopyButtonWithText:displayBundleID];
    [copyButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [bundleStack addArrangedSubview:copyButton];
    
    [contentStack addArrangedSubview:bundleStack];
    
    // Add app info
    UILabel *infoLabel = [[UILabel alloc] init];
    if ([appInfo[@"installed"] boolValue]) {
        NSString *frozenStatus = [self.freezeManager isApplicationFrozen:bundleID] ? @" [FROZEN]" : @"";
        NSString *infoText = [NSString stringWithFormat:@"%@ - v%@%@", appInfo[@"name"], appInfo[@"version"], frozenStatus];
        
        NSMutableAttributedString *attributedInfoText = [[NSMutableAttributedString alloc] initWithString:infoText];
        if ([self.freezeManager isApplicationFrozen:bundleID]) {
            NSRange frozenRange = [infoText rangeOfString:@"[FROZEN]"];
            [attributedInfoText addAttribute:NSForegroundColorAttributeName value:[UIColor systemBlueColor] range:frozenRange];
        }
        
        infoLabel.attributedText = attributedInfoText;
        infoLabel.textColor = [UIColor labelColor];
    } else {
        infoLabel.text = @"Removed From Scope";
        infoLabel.textColor = [UIColor systemOrangeColor];
    }
    infoLabel.font = [UIFont systemFontOfSize:12];
    [contentStack addArrangedSubview:infoLabel];
    
    // Add delete button with trash icon
    UIStackView *controlStack = [[UIStackView alloc] init];
    controlStack.axis = UILayoutConstraintAxisHorizontal;
    controlStack.alignment = UIStackViewAlignmentCenter;
    controlStack.distribution = UIStackViewDistributionEqualSpacing;
    controlStack.spacing = 8;
    
    UIButton *deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [deleteButton setImage:PXRemoveFromScopeIcon() forState:UIControlStateNormal];
    [deleteButton setTintColor:[UIColor systemRedColor]];
    deleteButton.tag = [self.appSwitches.allKeys indexOfObject:bundleID];
    [deleteButton addTarget:self action:@selector(deleteAppButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [controlStack addArrangedSubview:deleteButton];
    
    // Replace freeze button with more options button (ellipsis)
    UIButton *moreOptionsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [moreOptionsButton setImage:[UIImage systemImageNamed:@"ellipsis.circle.fill"] forState:UIControlStateNormal];
    [moreOptionsButton setTintColor:[UIColor systemBlueColor]];
    moreOptionsButton.tag = [self.appSwitches.allKeys indexOfObject:bundleID];
    [moreOptionsButton addTarget:self action:@selector(moreOptionsButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [controlStack addArrangedSubview:moreOptionsButton];
    
    // Add clear data button
    UIButton *clearDataButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [clearDataButton setImage:PXClearDataIcon() forState:UIControlStateNormal];
    [clearDataButton setTintColor:[UIColor systemRedColor]];
    clearDataButton.tag = [self.appSwitches.allKeys indexOfObject:bundleID];
    [clearDataButton addTarget:self action:@selector(clearDataButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [controlStack addArrangedSubview:clearDataButton];
    
    // Add versions button
    UIButton *versionsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [versionsButton setImage:[UIImage systemImageNamed:@"arrow.up.and.down.circle.fill"] forState:UIControlStateNormal];
    [versionsButton setTintColor:[UIColor systemBlueColor]];
    versionsButton.tag = [self.appSwitches.allKeys indexOfObject:bundleID];
    [versionsButton addTarget:self action:@selector(versionsButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [controlStack addArrangedSubview:versionsButton];
    
    // Add switch
    UISwitch *appSwitch = self.appSwitches[bundleID];
    [controlStack addArrangedSubview:appSwitch];
    
    [contentStack addArrangedSubview:controlStack];
    
    // Setup constraints
    [NSLayoutConstraint activateConstraints:@[
        [contentStack.topAnchor constraintEqualToAnchor:appView.topAnchor],
        [contentStack.leadingAnchor constraintEqualToAnchor:appView.leadingAnchor],
        [contentStack.trailingAnchor constraintEqualToAnchor:appView.trailingAnchor],
        [contentStack.bottomAnchor constraintEqualToAnchor:appView.bottomAnchor]
    ]];
    
    [cell.contentView addSubview:appView];
    
    // Setup constraints for appView
    appView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [appView.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor],
        [appView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
        [appView.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        [appView.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor]
    ]];
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (tableView == self.installedAppsTableView) {
        // Restrict adding if user has no plan
        // if (![[APIManager sharedManager] userHasPlan]) {
        //     UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Plan Required"
        //                                                                    message:@"You need an active plan to add apps to scope."
        //                                                             preferredStyle:UIAlertControllerStyleAlert];
        //     [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        //     [self presentViewController:alert animated:YES completion:nil];
        //     return;
        // }
        // Handle installed apps selection
        NSDictionary *selectedApp = self.filteredApps[indexPath.row];
        NSString *bundleID = selectedApp[@"bundleID"];
        if (self.selectionPickerMode.length) {
            if ([self.selectionDraftAppIDs containsObject:bundleID]) {
                [self.selectionDraftAppIDs removeObject:bundleID];
            } else if (bundleID.length) {
                [self.selectionDraftAppIDs addObject:bundleID];
            }
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            return;
        }
        
        if (bundleID) {
            // Add the app to scope
            [self.manager addApplicationToScope:bundleID];
            
            // Check for errors
            if ([self.manager lastError]) {
                [self showError:[self.manager lastError]];
                return;
            }
            
            // Refresh UI
            [self loadSettings];
            
            // Dismiss the popup
            [self dismissViewControllerAnimated:YES completion:^{
                // Show success message
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Success"
                                                                             message:[NSString stringWithFormat:@"Added %@ to scope", selectedApp[@"name"]]
                                                                      preferredStyle:UIAlertControllerStyleAlert];
                
                [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                        style:UIAlertActionStyleDefault
                                                      handler:nil]];
                
                [self presentViewController:alert animated:YES completion:nil];
            }];
        }
    }
    else if (indexPath.section == 0) { // Scoped Apps section
        NSDictionary *appInfo = self.scopedApps[indexPath.row];
        NSString *bundleID = appInfo[@"bundleID"];
        if (bundleID) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"App Options"
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
            
            UIAlertAction *addWithExtensionsAction = [UIAlertAction actionWithTitle:@"Add with Extensions"
                                                                            style:UIAlertActionStyleDefault
                                                                          handler:^(UIAlertAction * _Nonnull action) {
                // if (![[APIManager sharedManager] userHasPlan]) {
                //     UIAlertController *planAlert = [UIAlertController alertControllerWithTitle:@"Plan Required"
                //                                                                       message:@"You need an active plan to add apps with extensions to scope."
                //                                                                preferredStyle:UIAlertControllerStyleAlert];
                //     [planAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                //     [self presentViewController:planAlert animated:YES completion:nil];
                //     return;
                // }
                [self addApplicationWithExtensionsToScope:bundleID];
            }];
            
            UIAlertAction *removeAction = [UIAlertAction actionWithTitle:@"Remove from Scope"
                                                                 style:UIAlertActionStyleDestructive
                                                               handler:^(UIAlertAction * _Nonnull action) {
                [[IdentifierManager sharedManager] removeApplicationFromScope:bundleID];
                [self loadScopedApps];
            }];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                                 style:UIAlertActionStyleCancel
                                                               handler:nil];
            
            [alert addAction:addWithExtensionsAction];
            [alert addAction:removeAction];
            [alert addAction:cancelAction];
            
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
}

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        self.iconCache = [[NSCache alloc] init];
        self.iconCache.countLimit = 50; // Cache up to 50 icons
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleKeychainGroupsSaved:)
                                                 name:PXKeychainGroupsSavedNotification
                                               object:nil];
    
    // Add iPad-specific layout adaptations
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        // Use regular width size class layout for iPad
        self.view.backgroundColor = [UIColor systemBackgroundColor];
        
        // Create container view for iPad layout
        UIView *containerView = [[UIView alloc] init];
        containerView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:containerView];
        
        // Center container with max width for iPad
        [NSLayoutConstraint activateConstraints:@[
            [containerView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
            [containerView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
            [containerView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
            [containerView.widthAnchor constraintLessThanOrEqualToConstant:768], // iPad-appropriate max width
            [containerView.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor constant:-40],
            [containerView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:20],
            [containerView.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-20]
        ]];
        
        // Move existing content to container
        for (UIView *subview in self.view.subviews) {
            if (subview != containerView) {
                [containerView addSubview:subview];
            }
        }
    }
    
    self.title = @"Project X";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    
    if ([UIButton buttonConfigurationClassExists]) {
        // Modern button style for iOS 15+
        UIButtonConfiguration *filesConfig = [UIButtonConfiguration plainButtonConfiguration];
        filesConfig.title = @"Files";
        filesConfig.image = [UIImage systemImageNamed:@"arrow.down.circle"];
        filesConfig.imagePlacement = NSDirectionalRectEdgeLeading;
        filesConfig.imagePadding = 4;
        filesConfig.cornerStyle = UIButtonConfigurationCornerStyleMedium;
        filesConfig.baseForegroundColor = [UIColor systemBlueColor];
    } else {
        // Fallback for iOS 14 and below without using deprecated properties
        // Create a container view to hold the image and text
        UIView *buttonContentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 80, 30)];
        
        // Add icon image view
        UIImageView *iconImageView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"arrow.down.circle"]];
        iconImageView.tintColor = [UIColor systemBlueColor];
        iconImageView.translatesAutoresizingMaskIntoConstraints = NO;
        iconImageView.contentMode = UIViewContentModeScaleAspectFit;
        [buttonContentView addSubview:iconImageView];
        
        // Add text label
        UILabel *textLabel = [[UILabel alloc] init];
        textLabel.text = @"Files";
        textLabel.font = [UIFont systemFontOfSize:16];
        textLabel.textColor = [UIColor systemBlueColor];
        textLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [buttonContentView addSubview:textLabel];
        
        // Set up constraints
        [NSLayoutConstraint activateConstraints:@[
            [iconImageView.leadingAnchor constraintEqualToAnchor:buttonContentView.leadingAnchor],
            [iconImageView.centerYAnchor constraintEqualToAnchor:buttonContentView.centerYAnchor],
            [iconImageView.widthAnchor constraintEqualToConstant:20],
            [iconImageView.heightAnchor constraintEqualToConstant:20],
            
            [textLabel.leadingAnchor constraintEqualToAnchor:iconImageView.trailingAnchor constant:4],
            [textLabel.trailingAnchor constraintEqualToAnchor:buttonContentView.trailingAnchor],
            [textLabel.centerYAnchor constraintEqualToAnchor:buttonContentView.centerYAnchor]
        ]];
        

    }
        
    
    // Add Tools button to navigation bar (right side)
    UIButton *toolsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [toolsButton setTitle:@"Tools" forState:UIControlStateNormal];
    toolsButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [toolsButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    
    if ([UIButton buttonConfigurationClassExists]) {
        // Use modern button configuration for iOS 15+
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.title = @"Tools";
        config.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) {
            NSMutableDictionary *newAttributes = [attributes mutableCopy];
            newAttributes[NSFontAttributeName] = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
            newAttributes[NSForegroundColorAttributeName] = [UIColor systemBlueColor];
            return newAttributes;
        };
        config.contentInsets = NSDirectionalEdgeInsetsMake(4, 10, 4, 10);
        [toolsButton safeSetConfiguration:config];
    } else {
        // Fall back to older style for iOS 14 and below
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        toolsButton.contentEdgeInsets = UIEdgeInsetsMake(4, 10, 4, 10);
        #pragma clang diagnostic pop
    }
    
    toolsButton.layer.cornerRadius = 10;
    toolsButton.layer.borderWidth = 1;
    toolsButton.layer.borderColor = [UIColor systemBlueColor].CGColor;
    [toolsButton addTarget:self action:@selector(toolsButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *toolsBarButton = [[UIBarButtonItem alloc] initWithCustomView:toolsButton];
    self.navigationItem.rightBarButtonItem = toolsBarButton;
    
    // Initialize managers
    self.manager = [IdentifierManager sharedManager];
    self.freezeManager = [FreezeManager sharedManager];
    self.appSwitches = [NSMutableDictionary dictionary];
    self.identifierSwitches = [NSMutableDictionary dictionary];
    
    // Add tap gesture recognizer to dismiss keyboard
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tapGesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tapGesture];
    
    // Add long press gesture to show debug info for trial banner
    UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(showTrialBannerDebugInfo:)];
    longPressGesture.minimumPressDuration = 2.0; // 2 seconds
    [self.view addGestureRecognizer:longPressGesture];
    
    // Register for keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    // Register for frozen state changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleFrozenStateChanged:)
                                                 name:@"AppFrozenStateChanged"
                                               object:nil];
    
    
    // Register for profile changes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(handleProfileChanged:)
                                                name:@"com.hydra.projectx.profileChanged"
                                              object:nil];
    
    [self setupUI];
    [self loadSettings];
    // Remove duplicate call to setupProfileButtons since it's already called in setupUI
    [self setupProfileManagement];
    

}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    // Ensure the gradient layer in the trial banner is properly sized
    if (self.trialOfferBannerView) {
        for (CALayer *layer in self.trialOfferBannerView.layer.sublayers) {
            if ([layer isKindOfClass:[CAGradientLayer class]]) {
                CAGradientLayer *gradientLayer = (CAGradientLayer *)layer;
                gradientLayer.frame = self.trialOfferBannerView.bounds;
            }
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // ... existing code ...
    
    // Check if we should refresh the trial offer banner
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // Remember if we had a banner
    self.hasShownTrialOffer = (self.trialOfferBannerView != nil);
    
    // Clean up trial banner when view disappears to avoid memory issues
    if (self.trialOfferBannerView) {
        [self hideTrialOfferBanner];
    }
}

#pragma mark - UI Setup

- (void)setupUI {
    [self setupDashboardUI];
    return;

    // Setup scroll view with refresh control
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    
    // Hide vertical scroll indicator (removes the scrollbar line when scrolling)
    self.scrollView.showsVerticalScrollIndicator = NO;
    
    // Set delegate to self to implement scroll restriction
    self.scrollView.delegate = self;
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refreshData) forControlEvents:UIControlEventValueChanged];
    self.scrollView.refreshControl = refreshControl;
    [self.view addSubview:self.scrollView];
    
    // Setup main stack view with improved spacing
    self.mainStackView = [[UIStackView alloc] init];
    self.mainStackView.axis = UILayoutConstraintAxisVertical;
    self.mainStackView.spacing = 24;
    self.mainStackView.alignment = UIStackViewAlignmentFill;
    self.mainStackView.layoutMargins = UIEdgeInsetsMake(0, 0, 100, 0);
    self.mainStackView.layoutMarginsRelativeArrangement = YES;
    self.mainStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.mainStackView];
    
    // Initialize the advanced identifiers tracking array and flag
    self.advancedIdentifierViews = [NSMutableArray array];
    self.showAdvancedIdentifiers = NO;
    
    // Setup constraints with safe area
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        
        [self.mainStackView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.mainStackView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor constant:16],
        [self.mainStackView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor constant:-16],
        [self.mainStackView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.mainStackView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor constant:-32]
    ]];
    
    // Add sections with visual separation
    UIView *identifiersSection = [self createSectionHeaderWithTitle:@"Device IDs"];
    
    // Create header stack view for title and generate button
    UIStackView *headerStack = [[UIStackView alloc] init];
    headerStack.axis = UILayoutConstraintAxisHorizontal;
    headerStack.spacing = 8;
    headerStack.alignment = UIStackViewAlignmentCenter;
    headerStack.distribution = UIStackViewDistributionEqualSpacing;
    
    [headerStack addArrangedSubview:identifiersSection];
    

    // Add Generate All button with minimalistic style
    UIButton *generateAllButton = [UIButton buttonWithType:UIButtonTypeSystem];
    
    if ([UIButton buttonConfigurationClassExists]) {
        UIButtonConfiguration *generateAllConfig = [UIButtonConfiguration plainButtonConfiguration];
        generateAllConfig.title = @"Generate All";
        generateAllConfig.cornerStyle = UIButtonConfigurationCornerStyleMedium;
        generateAllConfig.background.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.15];
        generateAllConfig.baseForegroundColor = [UIColor systemBlueColor];
        generateAllConfig.contentInsets = NSDirectionalEdgeInsetsMake(2, 4, 2, 4);
        
        // Create a smaller icon that matches the text size
        UIImage *smallIcon = [UIImage systemImageNamed:@"arrow.triangle.2.circlepath" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:10]];
        generateAllConfig.image = smallIcon;
        
        generateAllConfig.imagePlacement = NSDirectionalRectEdgeLeading;
        generateAllConfig.imagePadding = 2;
        [generateAllButton safeSetConfiguration:generateAllConfig];
    } else {
        // iOS 12-14 fallback
        [generateAllButton setTitle:@"Generate All" forState:UIControlStateNormal];
        [generateAllButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
        generateAllButton.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.15];
        
        if (@available(iOS 13.0, *)) {
            UIImage *smallIcon = [UIImage systemImageNamed:@"arrow.triangle.2.circlepath"];
            [generateAllButton setImage:smallIcon forState:UIControlStateNormal];
        }
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        generateAllButton.contentEdgeInsets = UIEdgeInsetsMake(2, 4, 2, 4);
        #pragma clang diagnostic pop
    }
    
    generateAllButton.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    generateAllButton.layer.cornerRadius = 8;
    generateAllButton.clipsToBounds = YES;
    [generateAllButton addTarget:self action:@selector(generateAllButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [headerStack addArrangedSubview:generateAllButton];
    
    [self.mainStackView addArrangedSubview:headerStack];
    
    // Add basic identifier sections
    [self addIdentifierSection:@"IDFA" title:@"Advertising Identifier"];
    [self addIdentifierSection:@"IDFV" title:@"Vendor Identifier"];
    [self addIdentifierSection:@"DeviceName" title:@"Device Name"];
    [self addIdentifierSection:@"IOSVersion" title:@"iOS Version & Build"];
    [self addIdentifierSection:@"WiFi" title:@"WiFi Information"];
    [self addIdentifierSection:@"StorageSystem" title:@"Storage Information"];
    [self addIdentifierSection:@"Battery" title:@"Battery Information"];
    
    // Add basic UUID sections - moved System Uptime and Boot Time from advanced to basic
    [self addIdentifierSection:@"SystemUptime" title:@"System Uptime"];
    [self addIdentifierSection:@"BootTime" title:@"Boot Time"];
    
    // Add "Show Advanced" button
    [self addShowAdvancedButton];
    
    // Add advanced identifier sections (will be initially hidden)
    [self addAdvancedIdentifierSection:@"KeychainUUID" title:@"Keychain UUID"];
    [self addAdvancedIdentifierSection:@"UserDefaultsUUID" title:@"UserDefaults UUID"];
    [self addAdvancedIdentifierSection:@"AppGroupUUID" title:@"App Group UUID"];
    [self addAdvancedIdentifierSection:@"CoreDataUUID" title:@"Core Data UUID"];
    [self addAdvancedIdentifierSection:@"AppInstallUUID" title:@"App Install UUID"];
    [self addAdvancedIdentifierSection:@"AppContainerUUID" title:@"App Container UUID"];
    // Moved Serial Number and Pasteboard UUID from basic to advanced
    [self addAdvancedIdentifierSection:@"SerialNumber" title:@"Serial Number"];
    [self addAdvancedIdentifierSection:@"PasteboardUUID" title:@"Pasteboard UUID"];
    // Moved System Boot UUID and Dyld Cache UUID from basic to advanced
    [self addAdvancedIdentifierSection:@"SystemBootUUID" title:@"System Boot UUID"];
    [self addAdvancedIdentifierSection:@"DyldCacheUUID" title:@"Dyld Cache UUID"];
    
    UIView *appsSection = [self createSectionHeaderWithTitle:@"Scoped Apps"];
    [self.mainStackView addArrangedSubview:appsSection];
    
    [self addAppManagementSection];
    
    // Add bottom buttons view
    UIView *bottomButtonsView = [[BottomButtons sharedInstance] createBottomButtonsView];
    [self.view addSubview:bottomButtonsView];
    
    // Setup constraints for bottom buttons view
    [NSLayoutConstraint activateConstraints:@[
        [bottomButtonsView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bottomButtonsView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bottomButtonsView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
    
    // Add profile buttons view
    self.profileButtonsView = [[ProfileButtonsView alloc] initWithFrame:CGRectZero];
    self.profileButtonsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.profileButtonsView];
    
    // Setup profile button actions
    __weak typeof(self) weakSelf = self;
    
    // Set the block for new profile button
    self.profileButtonsView.onNewProfileTapped = ^{
        [weakSelf showProfileCreation];
    };
    self.profileButtonsView.onManageProfilesTapped = ^{
        [weakSelf showProfileManager];
    };
    
    // Add profile buttons constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.profileButtonsView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:11],
        [self.profileButtonsView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.profileButtonsView.widthAnchor constraintEqualToConstant:60],
        [self.profileButtonsView.heightAnchor constraintEqualToConstant:136] // 2 buttons * 60 + 16 spacing
    ]];

    // --- Floating scroll-to-bottom button ---
    UIButton *scrollToBottomButton = [UIButton buttonWithType:UIButtonTypeCustom];
    scrollToBottomButton.translatesAutoresizingMaskIntoConstraints = NO;
    // Use system background color that adapts to light/dark mode
    if (@available(iOS 13.0, *)) {
        scrollToBottomButton.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        scrollToBottomButton.backgroundColor = [UIColor whiteColor];
    }
    scrollToBottomButton.layer.cornerRadius = 18;
    scrollToBottomButton.clipsToBounds = YES;
    [scrollToBottomButton setImage:[[UIImage systemImageNamed:@"arrow.down"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    // Use system label color for the icon (adapts to theme)
    if (@available(iOS 13.0, *)) {
        scrollToBottomButton.tintColor = [UIColor labelColor];
    } else {
        scrollToBottomButton.tintColor = [UIColor blackColor];
    }
    scrollToBottomButton.alpha = 0.0; // Initially hidden
    scrollToBottomButton.layer.shadowColor = [UIColor blackColor].CGColor;
    scrollToBottomButton.layer.shadowOpacity = 0.2;
    scrollToBottomButton.layer.shadowOffset = CGSizeMake(0,2);
    scrollToBottomButton.layer.shadowRadius = 4;
    [self.view addSubview:scrollToBottomButton];

    // Constraints: right below profile buttons, horizontally aligned
    [NSLayoutConstraint activateConstraints:@[
        [scrollToBottomButton.centerXAnchor constraintEqualToAnchor:self.profileButtonsView.centerXAnchor],
        [scrollToBottomButton.topAnchor constraintEqualToAnchor:self.profileButtonsView.bottomAnchor constant:18],
        [scrollToBottomButton.widthAnchor constraintEqualToConstant:36],
        [scrollToBottomButton.heightAnchor constraintEqualToConstant:36]
    ]];

    // Action: scroll to bottom
    [scrollToBottomButton addTarget:self action:@selector(scrollToBottomButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.scrollToBottomButton = scrollToBottomButton;

    // Observe scroll events to show/hide button
    self.scrollView.delegate = self;

    
    // Initialize profiles array
    self.profiles = [[ProfileManager sharedManager].profiles mutableCopy];
    
    // Setup profile indicator
    [self setupProfileIndicator];
}

#pragma mark - Settings Management

- (void)loadSettings {
    // Load identifier states
    UISwitch *idfaSwitch = self.identifierSwitches[@"IDFA"];
    UISwitch *idfvSwitch = self.identifierSwitches[@"IDFV"];
    
    if (idfaSwitch) {
        idfaSwitch.on = [self.manager isIdentifierEnabled:@"IDFA"];
    }
    
    if (idfvSwitch) {
        idfvSwitch.on = [self.manager isIdentifierEnabled:@"IDFV"];
    }
    
    // Clear existing app switches
    [self.appSwitches removeAllObjects];
    
    // Load app states
    NSDictionary *appInfo = [self.manager getApplicationInfo:nil];
    for (NSString *bundleID in appInfo) {
        UISwitch *appSwitch = [[UISwitch alloc] init];
        [appSwitch addTarget:self action:@selector(appSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        appSwitch.on = [self.manager isApplicationEnabled:bundleID];
        self.appSwitches[bundleID] = appSwitch;
    }
    
    // Update UI to reflect current state
    [self updateAppsList];
}

#pragma mark - UI Updates

- (void)updateAppsList {
    // Remove all existing app views
    for (UIView *view in self.appsStackView.arrangedSubviews) {
        [view removeFromSuperview];
    }
    
    // Add app views for each app in appSwitches
    for (NSString *bundleID in self.appSwitches) {
        NSDictionary *appInfo = [self.manager getApplicationInfo:bundleID];
        NSString *displayBundleID = appInfo[@"bundleID"] ?: bundleID;
        
        // Create app view container
        UIView *appView = [[UIView alloc] init];
        appView.backgroundColor = [UIColor secondarySystemBackgroundColor];
        appView.layer.cornerRadius = 8;
        appView.clipsToBounds = YES;
        
        // Create background icon view with blur
        UIImageView *iconBackgroundView = [[UIImageView alloc] init];
        iconBackgroundView.contentMode = UIViewContentModeScaleAspectFit;
        iconBackgroundView.alpha = 0.3; // 30% opacity
        iconBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
        [appView addSubview:iconBackgroundView];
        
        // Add blur effect
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.alpha = 0.7; // Adjust blur intensity
        blurView.translatesAutoresizingMaskIntoConstraints = NO;
        [appView addSubview:blurView];
        
        // Create stack view for app content
        UIStackView *contentStack = [[UIStackView alloc] init];
        contentStack.axis = UILayoutConstraintAxisVertical;
        contentStack.spacing = 8;
        contentStack.layoutMargins = UIEdgeInsetsMake(12, 12, 12, 12);
        contentStack.layoutMarginsRelativeArrangement = YES;
        contentStack.translatesAutoresizingMaskIntoConstraints = NO;
        [appView addSubview:contentStack];
        
        // Setup constraints for background icon and blur
        [NSLayoutConstraint activateConstraints:@[
            [iconBackgroundView.centerXAnchor constraintEqualToAnchor:appView.centerXAnchor],
            [iconBackgroundView.centerYAnchor constraintEqualToAnchor:appView.centerYAnchor],
            [iconBackgroundView.widthAnchor constraintEqualToAnchor:appView.widthAnchor multiplier:0.3], // Reduced to 30%
            [iconBackgroundView.heightAnchor constraintEqualToAnchor:iconBackgroundView.widthAnchor],
            
            [blurView.topAnchor constraintEqualToAnchor:appView.topAnchor],
            [blurView.leadingAnchor constraintEqualToAnchor:appView.leadingAnchor],
            [blurView.trailingAnchor constraintEqualToAnchor:appView.trailingAnchor],
            [blurView.bottomAnchor constraintEqualToAnchor:appView.bottomAnchor],
            
            [contentStack.topAnchor constraintEqualToAnchor:appView.topAnchor],
            [contentStack.leadingAnchor constraintEqualToAnchor:appView.leadingAnchor],
            [contentStack.trailingAnchor constraintEqualToAnchor:appView.trailingAnchor],
            [contentStack.bottomAnchor constraintEqualToAnchor:appView.bottomAnchor]
        ]];
        
        // Fetch and set app icon
        [self fetchAppIconForBundleID:bundleID completion:^(UIImage *icon) {
            iconBackgroundView.image = icon;
        }];
        
        // Create bundle ID with copy button
        UIStackView *bundleStack = [[UIStackView alloc] init];
        bundleStack.axis = UILayoutConstraintAxisHorizontal;
        bundleStack.spacing = 4;  // Reduced spacing
        bundleStack.alignment = UIStackViewAlignmentCenter;
        
        // Add extension button with smaller size
        UIButton *extensionButton = [UIButton buttonWithType:UIButtonTypeSystem];
        UIImage *plusImage = [[UIImage systemImageNamed:@"plus.circle.fill"] imageWithConfiguration:
                             [UIImageSymbolConfiguration configurationWithPointSize:14.0]];  // Reduced size
        [extensionButton setImage:plusImage forState:UIControlStateNormal];
        extensionButton.tintColor = [UIColor systemBlueColor];
        extensionButton.tag = [self.appSwitches.allKeys indexOfObject:bundleID];
        [extensionButton addTarget:self action:@selector(extensionButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        // Set fixed size for extension button
        [extensionButton.heightAnchor constraintEqualToConstant:16].active = YES;  // Fixed height
        [extensionButton.widthAnchor constraintEqualToConstant:16].active = YES;   // Fixed width
        extensionButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        // Add to stack with no extra padding
        [bundleStack setCustomSpacing:2 afterView:extensionButton];  // Minimal spacing after button
        [bundleStack addArrangedSubview:extensionButton];
        
        UILabel *bundleLabel = [[UILabel alloc] init];
        bundleLabel.text = displayBundleID;
        bundleLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
        bundleLabel.numberOfLines = 1;
        bundleLabel.adjustsFontSizeToFitWidth = YES;
        bundleLabel.minimumScaleFactor = 0.75;
        [bundleStack addArrangedSubview:bundleLabel];
        
        UIButton *copyButton = [CopyHelper createCopyButtonWithText:displayBundleID];
        [copyButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [bundleStack addArrangedSubview:copyButton];
        
        [contentStack addArrangedSubview:bundleStack];
        
        // Add app info
        UILabel *infoLabel = [[UILabel alloc] init];
        if ([appInfo[@"installed"] boolValue]) {
            NSString *frozenStatus = [self.freezeManager isApplicationFrozen:bundleID] ? @" [FROZEN]" : @"";
            NSString *infoText = [NSString stringWithFormat:@"%@ - v%@%@", appInfo[@"name"], appInfo[@"version"], frozenStatus];
            
            NSMutableAttributedString *attributedInfoText = [[NSMutableAttributedString alloc] initWithString:infoText];
            if ([self.freezeManager isApplicationFrozen:bundleID]) {
                NSRange frozenRange = [infoText rangeOfString:@"[FROZEN]"];
                [attributedInfoText addAttribute:NSForegroundColorAttributeName value:[UIColor systemBlueColor] range:frozenRange];
            }
            
            infoLabel.attributedText = attributedInfoText;
            infoLabel.textColor = [UIColor labelColor];
        } else {
            infoLabel.text = @"Removed From Scope";
            infoLabel.textColor = [UIColor systemOrangeColor];
        }
        infoLabel.font = [UIFont systemFontOfSize:12];
        [contentStack addArrangedSubview:infoLabel];
        
        // Add delete button with icon
        UIStackView *controlStack = [[UIStackView alloc] init];
        controlStack.axis = UILayoutConstraintAxisHorizontal;
        controlStack.alignment = UIStackViewAlignmentCenter;
        controlStack.distribution = UIStackViewDistributionEqualSpacing;
        controlStack.spacing = 8;
        
        UIButton *deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [deleteButton setImage:PXRemoveFromScopeIcon() forState:UIControlStateNormal];
        [deleteButton setTintColor:[UIColor systemRedColor]];
        deleteButton.tag = [self.appSwitches.allKeys indexOfObject:bundleID];
        [deleteButton addTarget:self action:@selector(deleteAppButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [controlStack addArrangedSubview:deleteButton];
        
        // Replace freeze button with more options button (ellipsis)
        UIButton *moreOptionsButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [moreOptionsButton setImage:[UIImage systemImageNamed:@"ellipsis.circle.fill"] forState:UIControlStateNormal];
        [moreOptionsButton setTintColor:[UIColor systemBlueColor]];
        moreOptionsButton.tag = [self.appSwitches.allKeys indexOfObject:bundleID];
        [moreOptionsButton addTarget:self action:@selector(moreOptionsButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [controlStack addArrangedSubview:moreOptionsButton];
        
        // Add clear data button
        UIButton *clearDataButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [clearDataButton setImage:PXClearDataIcon() forState:UIControlStateNormal];
        [clearDataButton setTintColor:[UIColor systemRedColor]];
        clearDataButton.tag = [self.appSwitches.allKeys indexOfObject:bundleID];
        [clearDataButton addTarget:self action:@selector(clearDataButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [controlStack addArrangedSubview:clearDataButton];
        
        // Add versions button
        UIButton *versionsButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [versionsButton setImage:[UIImage systemImageNamed:@"arrow.up.and.down.circle.fill"] forState:UIControlStateNormal];
        [versionsButton setTintColor:[UIColor systemBlueColor]];
        versionsButton.tag = [self.appSwitches.allKeys indexOfObject:bundleID];
        [versionsButton addTarget:self action:@selector(versionsButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [controlStack addArrangedSubview:versionsButton];
        
        // Add switch
        UISwitch *appSwitch = self.appSwitches[bundleID];
        [controlStack addArrangedSubview:appSwitch];
        
        [contentStack addArrangedSubview:controlStack];
        
        // Setup constraints
        [NSLayoutConstraint activateConstraints:@[
            [contentStack.topAnchor constraintEqualToAnchor:appView.topAnchor],
            [contentStack.leadingAnchor constraintEqualToAnchor:appView.leadingAnchor],
            [contentStack.trailingAnchor constraintEqualToAnchor:appView.trailingAnchor],
            [contentStack.bottomAnchor constraintEqualToAnchor:appView.bottomAnchor]
        ]];
        
        [self.appsStackView addArrangedSubview:appView];
    }
}

#pragma mark - Button Actions

- (void)backupRestoreButtonTapped:(UIButton *)sender {
    // Open the AppDataBackupRestoreViewController when the new icon is tapped
    AppDataBackupRestoreViewController *vc = [[AppDataBackupRestoreViewController alloc] init];
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:vc animated:YES completion:nil];
}

// (Freeze logic remains for now, but is not connected to any UI)
- (void)freezeAppButtonTapped:(UIButton *)sender {
    NSString *bundleID = self.appSwitches.allKeys[sender.tag];
    if (!bundleID) {
        return;
    }
    
    // Disable the button temporarily to prevent multiple taps
    sender.enabled = NO;
    
    BOOL isFrozen = [self.freezeManager isApplicationFrozen:bundleID];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (isFrozen) {
            [self.freezeManager unfreezeApplication:bundleID];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [sender setTintColor:[UIColor systemGrayColor]];
                sender.enabled = YES;
                [self.appsTableView reloadData];
            });
        } else {
            [self.freezeManager freezeApplication:bundleID];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [sender setTintColor:[UIColor systemBlueColor]];
                sender.enabled = YES;
                [self.appsTableView reloadData];
            });
        }
    });
}

#pragma mark - Process Management

- (void)killEnabledAppsAndRespring {
    // Get all enabled apps
    NSDictionary *allApps = [self.manager getApplicationInfo:nil];
    for (NSString *bundleID in allApps) {
        if ([self.manager isApplicationEnabled:bundleID]) {
            // Use posix_spawn to kill apps
            pid_t pid;
            const char *killall = "/usr/bin/killall";
            const char *bundleIDStr = [bundleID UTF8String];
            char *const argv[] = {(char *)"killall", (char *)bundleIDStr, NULL};
            posix_spawn(&pid, killall, NULL, NULL, argv, NULL);
            int status;
            waitpid(pid, &status, WEXITED);
        }
    }
    
    // Respring using sbreload
    pid_t pid;
    const char *sbreload = "/usr/bin/sbreload";
    char *const argv[] = {(char *)"sbreload", NULL};
    posix_spawn(&pid, sbreload, NULL, NULL, argv, NULL);
    waitpid(pid, NULL, WEXITED);
}

#pragma mark - Error Handling

- (void)showError:(NSError *)error {
    if (!error) return;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                 message:error.localizedDescription
                                                          preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil];
    
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Keyboard Handling

- (void)keyboardWillShow:(NSNotification *)notification {
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardFrame.size.height, 0.0);
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.scrollView.contentInset = UIEdgeInsetsZero;
    self.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
    [self.versionSearchBar resignFirstResponder];
    [self.appSearchBar resignFirstResponder];
}

#pragma mark - UI Components

- (void)addIdentifierSection:(NSString *)type title:(NSString *)title {
    // Create section title
    NSArray *shippingboxTypes = @[ @"KeychainUUID", @"UserDefaultsUUID", @"AppGroupUUID", @"CoreDataUUID", @"AppInstallUUID", @"AppContainerUUID" ];
    if (@available(iOS 15.0, *)) {
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        titleLabel.textColor = [UIColor labelColor];
        
        // Determine which icon to use based on type
        NSString *iconName = [shippingboxTypes containsObject:type] ? @"shippingbox" : @"pencil";
        UIImage *iconImage = [UIImage systemImageNamed:iconName];
        
        if (iconImage) {
            // Tint the icon to match text
            iconImage = [iconImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            NSTextAttachment *iconAttachment = [[NSTextAttachment alloc] init];
            iconAttachment.image = iconImage;
            CGFloat iconSize = 18;
            iconAttachment.bounds = CGRectMake(0, -3, iconSize, iconSize);
            
            NSAttributedString *space = [[NSAttributedString alloc] initWithString:@"  "];
            NSAttributedString *titleString = [[NSAttributedString alloc] initWithString:title attributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:18 weight:UIFontWeightBold],
                NSForegroundColorAttributeName: [UIColor labelColor]
            }];
            
            NSMutableAttributedString *full = [[NSMutableAttributedString alloc] initWithAttributedString:titleString];
            [full appendAttributedString:space];
            [full appendAttributedString:[NSAttributedString attributedStringWithAttachment:iconAttachment]];
            titleLabel.attributedText = full;
            titleLabel.tintColor = [UIColor labelColor];
            
            // Add tap gesture for the label to show edit dialog
            UITapGestureRecognizer *titleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(titleIconTapped:)];
            titleLabel.userInteractionEnabled = YES;
            [titleLabel addGestureRecognizer:titleTap];
            objc_setAssociatedObject(titleTap, "identifierType", type, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        } else {
            // Unicode fallback
            titleLabel.text = [NSString stringWithFormat:@"%@ \U0001F4E6", title];
        }
        [self.mainStackView addArrangedSubview:titleLabel];
    } else {
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.text = title;
        titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        titleLabel.textColor = [UIColor labelColor];
        [self.mainStackView addArrangedSubview:titleLabel];
    }
    
    // Reduce spacing between title and container by 50%
    UIView *lastTitleView = nil;
    if (@available(iOS 15.0, *)) {
        if ([shippingboxTypes containsObject:type]) {
            lastTitleView = self.mainStackView.arrangedSubviews.lastObject; // titleStack
        } else {
            lastTitleView = self.mainStackView.arrangedSubviews.lastObject; // titleLabel
        }
    } else {
        lastTitleView = self.mainStackView.arrangedSubviews.lastObject; // titleLabel
    }
    if (lastTitleView) {
        [self.mainStackView setCustomSpacing:4 afterView:lastTitleView];
    }
    
    // Create container view with glassmorphism effect
    UIView *containerView = [[UIView alloc] init];
    
    // Set up glassmorphism effect - works in both light and dark mode
    containerView.backgroundColor = [UIColor clearColor];
    
    // Create blur effect - adapts to light/dark mode automatically
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:blurView];
    
    // Add vibrancy effect for content
    UIVibrancyEffect *vibrancyEffect = [UIVibrancyEffect effectForBlurEffect:blurEffect];
    UIVisualEffectView *vibrancyView = [[UIVisualEffectView alloc] initWithEffect:vibrancyEffect];
    vibrancyView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Setup blur view constraints to fill container
    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor]
    ]];
    
    // Add subtle border
    containerView.layer.borderWidth = 0.5;
    containerView.layer.borderColor = [UIColor.labelColor colorWithAlphaComponent:0.2].CGColor;
    containerView.layer.cornerRadius = 20;
    containerView.clipsToBounds = YES;
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Add subtle shadow
    containerView.layer.shadowColor = [UIColor blackColor].CGColor;
    containerView.layer.shadowOffset = CGSizeMake(0, 4);
    containerView.layer.shadowRadius = 8;
    containerView.layer.shadowOpacity = 0.1;
    
    // Create vertical stack for identifier and controls
    UIStackView *contentStack = [[UIStackView alloc] init];
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = 10;
    contentStack.layoutMargins = UIEdgeInsetsMake(16, 16, 16, 16);
    contentStack.layoutMarginsRelativeArrangement = YES;
    contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:contentStack];
    
    // Setup content stack constraints
    [NSLayoutConstraint activateConstraints:@[
        [contentStack.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [contentStack.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [contentStack.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [contentStack.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor]
    ]];
    
    // Create identifier container with background
    UIView *identifierContainer = [[UIView alloc] init];
    identifierContainer.backgroundColor = [UIColor.labelColor colorWithAlphaComponent:0.1];
    identifierContainer.layer.cornerRadius = 12;
    identifierContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Create identifier label
    UILabel *identifierLabel = [[UILabel alloc] init];
    NSString *currentValue = [self.manager currentValueForIdentifier:type];
    identifierLabel.text = currentValue ?: @"Not Set";
    identifierLabel.font = [UIFont monospacedSystemFontOfSize:18 weight:UIFontWeightRegular];
    identifierLabel.textColor = [UIColor labelColor];
    identifierLabel.numberOfLines = 1;
    identifierLabel.adjustsFontSizeToFitWidth = YES;
    identifierLabel.minimumScaleFactor = 0.5;
    identifierLabel.textAlignment = NSTextAlignmentCenter;
    identifierLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Add padding to identifier label
    [identifierContainer addSubview:identifierLabel];
    [NSLayoutConstraint activateConstraints:@[
        [identifierLabel.topAnchor constraintEqualToAnchor:identifierContainer.topAnchor constant:12],
        [identifierLabel.leadingAnchor constraintEqualToAnchor:identifierContainer.leadingAnchor constant:12],
        [identifierLabel.trailingAnchor constraintEqualToAnchor:identifierContainer.trailingAnchor constant:-12],
        [identifierLabel.bottomAnchor constraintEqualToAnchor:identifierContainer.bottomAnchor constant:-12]
    ]];
    
    [contentStack addArrangedSubview:identifierContainer];
    
    // Create horizontal stack for controls
    UIStackView *controlsStack = [[UIStackView alloc] init];
    controlsStack.axis = UILayoutConstraintAxisHorizontal;
    controlsStack.distribution = UIStackViewDistributionEqualSpacing;
    controlsStack.alignment = UIStackViewAlignmentCenter;
    
    // Create copy button with enhanced style
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    if ([UIButton buttonConfigurationClassExists]) {
        UIButtonConfiguration *copyConfig = [UIButtonConfiguration plainButtonConfiguration];
        copyConfig.image = [UIImage systemImageNamed:@"doc.on.doc"];
        copyConfig.cornerStyle = UIButtonConfigurationCornerStyleMedium;
        copyConfig.background.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.1];
        copyConfig.baseForegroundColor = [UIColor systemBlueColor];
        copyConfig.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
        [copyButton safeSetConfiguration:copyConfig];
    } else {
        [copyButton setImage:[UIImage systemImageNamed:@"doc.on.doc"] forState:UIControlStateNormal];
        copyButton.tintColor = [UIColor systemBlueColor];
        copyButton.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.1];
        copyButton.layer.cornerRadius = 8;
        copyButton.clipsToBounds = YES;
    }
    
    copyButton.tag = [self tagForIdentifierType:type];
    copyButton.accessibilityValue = currentValue;
    [copyButton addTarget:self action:@selector(copyButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // Create switch and status container
    UIStackView *switchStatusStack = [[UIStackView alloc] init];
    switchStatusStack.axis = UILayoutConstraintAxisHorizontal;
    switchStatusStack.spacing = 8;
    switchStatusStack.alignment = UIStackViewAlignmentCenter;
    
    // Create status label
    UILabel *stateLabel = [[UILabel alloc] init];
    stateLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    stateLabel.textColor = [UIColor labelColor];
    stateLabel.text = [self.manager isIdentifierEnabled:type] ? @"Enabled" : @"Disabled";
    stateLabel.tag = 100; // Tag to find this label later
    
    // Create switch with modern style
    UISwitch *identifierSwitch = [[UISwitch alloc] init];
    [identifierSwitch setOn:[self.manager isIdentifierEnabled:type] animated:NO];
    identifierSwitch.onTintColor = [UIColor systemBlueColor];
    [identifierSwitch addTarget:self action:@selector(identifierSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    identifierSwitch.tag = [self tagForIdentifierType:type];
    
    [switchStatusStack addArrangedSubview:stateLabel];
    [switchStatusStack addArrangedSubview:identifierSwitch];
    
    // Create generate button with minimalistic style
    UIButton *generateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    if ([UIButton buttonConfigurationClassExists]) {
        UIButtonConfiguration *generateConfig = [UIButtonConfiguration plainButtonConfiguration];
        generateConfig.image = [UIImage systemImageNamed:@"arrow.clockwise"];
        generateConfig.title = @"Generate";
        generateConfig.imagePlacement = NSDirectionalRectEdgeLeading;
        generateConfig.imagePadding = 4;
        generateConfig.cornerStyle = UIButtonConfigurationCornerStyleMedium;
        generateConfig.background.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.15];
        generateConfig.baseForegroundColor = [UIColor systemBlueColor];
        generateConfig.contentInsets = NSDirectionalEdgeInsetsMake(4, 6, 4, 6);
        [generateButton safeSetConfiguration:generateConfig];
    } else {
        [generateButton setTitle:@"Generate" forState:UIControlStateNormal];
        [generateButton setImage:[UIImage systemImageNamed:@"arrow.clockwise"] forState:UIControlStateNormal];
        generateButton.tintColor = [UIColor systemBlueColor];
        generateButton.backgroundColor = [UIColor.systemBlueColor colorWithAlphaComponent:0.15];
        generateButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    }
    generateButton.layer.cornerRadius = 10;
    generateButton.clipsToBounds = YES;
    
    generateButton.tag = [self tagForIdentifierType:type];
    [generateButton addTarget:self action:@selector(generateButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // Add all elements to controls stack
    [controlsStack addArrangedSubview:copyButton];
    [controlsStack addArrangedSubview:switchStatusStack];
    [controlsStack addArrangedSubview:generateButton];
    
    // Add controls stack to content stack
    [contentStack addArrangedSubview:controlsStack];
    
    // Add container to main stack
    [self.mainStackView addArrangedSubview:containerView];
    
    // Add spacing after the container - reduce by 50% from default spacing
    [self.mainStackView setCustomSpacing:12 afterView:containerView]; // 50% of the default 24 spacing
    
    // Store switch reference
    if (!self.identifierSwitches) {
        self.identifierSwitches = [NSMutableDictionary dictionary];
    }
    self.identifierSwitches[type] = identifierSwitch;
}

- (void)addAppManagementSection {
    // Create apps stack view
    self.appsStackView = [[UIStackView alloc] init];
    self.appsStackView.axis = UILayoutConstraintAxisVertical;
    self.appsStackView.spacing = 12;
    self.appsStackView.alignment = UIStackViewAlignmentFill;
    
    // Add bundle ID input field and buttons container
    UIStackView *inputStack = [[UIStackView alloc] init];
    inputStack.axis = UILayoutConstraintAxisHorizontal;
    inputStack.spacing = 8;
    inputStack.alignment = UIStackViewAlignmentCenter;
    inputStack.layoutMargins = UIEdgeInsetsMake(0, 8, 0, 8);
    inputStack.layoutMarginsRelativeArrangement = YES;
    
    // Create container view for text field to control its size
    UIView *textFieldContainer = [[UIView alloc] init];
    textFieldContainer.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.bundleIDTextField = [[UITextField alloc] init];
    self.bundleIDTextField.placeholder = @"Enter Bundle ID";
    self.bundleIDTextField.font = [UIFont systemFontOfSize:16];
    self.bundleIDTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.bundleIDTextField.delegate = self;
    self.bundleIDTextField.translatesAutoresizingMaskIntoConstraints = NO;
    [textFieldContainer addSubview:self.bundleIDTextField];
    
    // Set fixed height and width for text field container
    [NSLayoutConstraint activateConstraints:@[
        [textFieldContainer.heightAnchor constraintEqualToConstant:36],
        [textFieldContainer.widthAnchor constraintEqualToConstant:200],  // Fixed width
        [self.bundleIDTextField.topAnchor constraintEqualToAnchor:textFieldContainer.topAnchor],
        [self.bundleIDTextField.bottomAnchor constraintEqualToAnchor:textFieldContainer.bottomAnchor],
        [self.bundleIDTextField.leadingAnchor constraintEqualToAnchor:textFieldContainer.leadingAnchor],
        [self.bundleIDTextField.trailingAnchor constraintEqualToAnchor:textFieldContainer.trailingAnchor]
    ]];
    
    [inputStack addArrangedSubview:textFieldContainer];
    
    // Create buttons stack
    UIStackView *buttonsStack = [[UIStackView alloc] init];
    buttonsStack.axis = UILayoutConstraintAxisHorizontal;
    buttonsStack.spacing = 12;  // Increased spacing between buttons
    buttonsStack.alignment = UIStackViewAlignmentCenter;
    
    // Add installed apps button (plus button)
    UIButton *installedAppsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [installedAppsButton setImage:[UIImage systemImageNamed:@"plus.diamond.fill"] forState:UIControlStateNormal];
    [installedAppsButton addTarget:self action:@selector(addAppButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [installedAppsButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [buttonsStack addArrangedSubview:installedAppsButton];
    
    // Add App button
    UIButton *addButton = [UIButton buttonWithType:UIButtonTypeSystem];
    if ([UIButton buttonConfigurationClassExists]) {
        UIButtonConfiguration *addButtonConfig = [UIButtonConfiguration plainButtonConfiguration];
        addButtonConfig.contentInsets = NSDirectionalEdgeInsetsMake(4, 6, 4, 6);
        addButtonConfig.title = @"Add App";
        addButtonConfig.cornerStyle = UIButtonConfigurationCornerStyleMedium;
        addButtonConfig.background.backgroundColor = [UIColor.systemGreenColor colorWithAlphaComponent:0.15];
        addButtonConfig.baseForegroundColor = [UIColor systemGreenColor];
        [addButton safeSetConfiguration:addButtonConfig];
    } else {
        [addButton setTitle:@"Add App" forState:UIControlStateNormal];
        addButton.tintColor = [UIColor systemGreenColor];
        addButton.backgroundColor = [UIColor.systemGreenColor colorWithAlphaComponent:0.15];
        addButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    }
    addButton.layer.cornerRadius = 10;
    addButton.clipsToBounds = YES;
    [addButton addTarget:self action:@selector(showInstalledAppsPopup:) forControlEvents:UIControlEventTouchUpInside];
    [addButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [buttonsStack addArrangedSubview:addButton];
    
    [inputStack addArrangedSubview:buttonsStack];
    
    // Set content hugging and compression resistance for the container
    [textFieldContainer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [textFieldContainer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    
    // Set content hugging and compression resistance for buttons stack
    [buttonsStack setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [buttonsStack setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    
    [self.mainStackView addArrangedSubview:inputStack];
    [self.mainStackView addArrangedSubview:self.appsStackView];
}

- (UIView *)createSectionHeaderWithTitle:(NSString *)title {
    UIView *headerView = [[UIView alloc] init];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:titleLabel];
    
    UIView *separatorView = [[UIView alloc] init];
    separatorView.backgroundColor = [UIColor separatorColor];
    separatorView.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:separatorView];
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:headerView.topAnchor constant:16],
        [titleLabel.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor],
        [titleLabel.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor],
        
        [separatorView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [separatorView.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor],
        [separatorView.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor],
        [separatorView.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor],
        [separatorView.heightAnchor constraintEqualToConstant:1]
    ]];
    
    return headerView;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    // Get the new text that would result from this change
    NSString *newText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    // Limit text field to 50 characters (increased from 26)
    if (newText.length > 50) {
        return NO;
    }
    
    // Only allow alphanumeric characters, dots, and hyphens
    NSCharacterSet *allowedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"];
    NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:string];
    return [allowedCharacters isSupersetOfSet:characterSet] || [string isEqualToString:@""];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    
    // If there's text, automatically try to add the app
    if (textField.text.length > 0) {
        [self addAppButtonTapped:nil];
    }
    
    return YES;
}

#pragma mark - UITableViewDelegate


#pragma mark - Switch Actions

- (void)identifierSwitchChanged:(UISwitch *)sender {
    // Find which identifier type this switch belongs to
    NSString *identifierType = nil;
    for (NSString *type in self.identifierSwitches) {
        if (self.identifierSwitches[type] == sender) {
            identifierType = type;
            break;
        }
    }
    
    if (!identifierType) return;
    
    // Update the identifier state in manager
    [self.manager setIdentifierEnabled:sender.isOn forType:identifierType];
    
    // Find and update state label
    UIStackView *switchStatusStack = (UIStackView *)sender.superview;
    if ([switchStatusStack isKindOfClass:[UIStackView class]]) {
        UILabel *stateLabel = [switchStatusStack.arrangedSubviews filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
                return [object isKindOfClass:[UILabel class]] && ((UILabel *)object).tag == 100;
            }]].firstObject;
        
        if (stateLabel) {
            stateLabel.text = sender.isOn ? @"Enabled" : @"Disabled";
        }
    }
    
    // If enabled, just update the UI with the existing value from plist
    if (sender.isOn) {
        NSString *existingValue = [self.manager currentValueForIdentifier:identifierType];
        if (existingValue) {
            [self directUpdateIdentifierValue:identifierType withValue:existingValue];
        }
    }
    
    // Save settings to persist the enabled state
    [self.manager saveSettings];
}

- (void)appSwitchChanged:(UISwitch *)sender {
    // Find which app this switch belongs to
    NSString *bundleID = nil;
    for (NSString *appBundleID in self.appSwitches) {
        if (self.appSwitches[appBundleID] == sender) {
            bundleID = appBundleID;
            break;
        }
    }
    
    if (!bundleID) return;
    
    // Update app state in manager
    [self.manager setApplication:bundleID enabled:sender.isOn];
}

- (void)addAppButtonTapped:(UIButton *)sender {
    // if (![[APIManager sharedManager] userHasPlan]) {
    //     UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Plan Required"
    //                                                                    message:@"You need an active plan to add apps to scope."
    //                                                             preferredStyle:UIAlertControllerStyleAlert];
    //     [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    //     [self presentViewController:alert animated:YES completion:nil];
    //     return;
    // }
    NSString *bundleID = self.bundleIDTextField.text;
    if (!bundleID.length) {
        [self showError:[NSError errorWithDomain:@"com.hydra.projectx" 
                                           code:3001 
                                       userInfo:@{NSLocalizedDescriptionKey: @"Please enter a bundle ID"}]];
        return;
    }
    
    // Add app to manager
    [self.manager addApplicationToScope:bundleID];
    
    // Check for errors
    if ([self.manager lastError]) {
        [self showError:[self.manager lastError]];
        return;
    }
    
    // Clear text field
    self.bundleIDTextField.text = @"";
    [self.bundleIDTextField resignFirstResponder];
    
    // Refresh UI
    [self loadSettings];
}

- (void)handleFrozenStateChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Update the table view to reflect frozen state changes
        [self.appsTableView reloadData];
        
        // If specific app info was provided, update just that row
        NSString *bundleID = notification.userInfo[@"bundleID"];
        if (bundleID) {
            NSInteger index = [self.appSwitches.allKeys indexOfObject:bundleID];
            if (index != NSNotFound) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                [self.appsTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            }
        }
    });
}

- (void)refreshData {
    [self loadSettings];
    [self.scrollView.refreshControl endRefreshing];
}

- (void)generateButtonTapped:(UIButton *)sender {
    // Check if user has an active plan
    BOOL isRestricted = [[NSUserDefaults standardUserDefaults] boolForKey:@"WeaponXRestrictedAccess"];
    
    // Also check associated object as a backup
    if (!isRestricted) {
        UIViewController *topVC = [self findTopViewController];
        NSNumber *restrictedAccess = objc_getAssociatedObject(topVC, "WeaponXRestrictedAccess");
        isRestricted = restrictedAccess ? [restrictedAccess boolValue] : NO;
    }
    
    // If user doesn't have an active plan, show alert and prevent action
    // if (isRestricted) {
    //     UIAlertController *alert = [UIAlertController 
    //         alertControllerWithTitle:@"Access Restricted" 
    //         message:@"Please subscribe to a plan to use the generate feature." 
    //         preferredStyle:UIAlertControllerStyleAlert];
        
    //     [alert addAction:[UIAlertAction 
    //         actionWithTitle:@"View Plans" 
    //         style:UIAlertActionStyleDefault 
    //         handler:^(UIAlertAction * _Nonnull action) {
    //             // Switch to account tab to view plans
    //             UITabBarController *tabController = [self findTabBarController];
    //             if ([tabController respondsToSelector:@selector(switchToAccountTab)]) {
    //                 [tabController performSelector:@selector(switchToAccountTab)];
    //             }
    //         }]];
        
    //     [alert addAction:[UIAlertAction 
    //         actionWithTitle:@"Cancel" 
    //         style:UIAlertActionStyleCancel 
    //         handler:nil]];
        
    //     [self presentViewController:alert animated:YES completion:nil];
    //     return;
    // }
    
    // Determine which identifier type based on the button's tag
    NSString *identifierType;
    if (sender.tag == 1) {
        identifierType = @"IDFA";
    } else if (sender.tag == 2) {
        identifierType = @"IDFV";
    } else if (sender.tag == 3) {
        identifierType = @"DeviceName";
    } else if (sender.tag == 4) {
        identifierType = @"SerialNumber";
    } else if (sender.tag == 5) {
        identifierType = @"IOSVersion";
    } else if (sender.tag == 6) {
        identifierType = @"WiFi";
    } else if (sender.tag == 7) {
        identifierType = @"StorageSystem";
    } else if (sender.tag == 8) {
        identifierType = @"Battery";
    } else if (sender.tag == 9) {
        identifierType = @"SystemBootUUID";
    } else if (sender.tag == 10) {
        identifierType = @"DyldCacheUUID";
    } else if (sender.tag == 11) {
        identifierType = @"PasteboardUUID";
    } else if (sender.tag == 12) {
        identifierType = @"KeychainUUID";
    } else if (sender.tag == 13) {
        identifierType = @"UserDefaultsUUID";
    } else if (sender.tag == 14) {
        identifierType = @"AppGroupUUID";
    } else if (sender.tag == 15) {
        identifierType = @"SystemUptime";
    } else if (sender.tag == 16) {
        identifierType = @"BootTime";
    } else if (sender.tag == 17) {
        identifierType = @"CoreDataUUID";
    } else if (sender.tag == 18) {
        identifierType = @"AppInstallUUID";
    } else if (sender.tag == 19) {
        identifierType = @"AppContainerUUID";
    } else {
        return;
    }
    
    // Disable button temporarily
    sender.enabled = NO;
    
    // Show loading state
    UIColor *originalColor = sender.tintColor;
    [sender setTitle:@"Generating..." forState:UIControlStateNormal];
    [sender setTintColor:[UIColor systemGrayColor]];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Generate only the specific identifier that was tapped
        NSString *newValue = nil;
        if ([identifierType isEqualToString:@"IDFA"]) {
            newValue = [self.manager generateIDFA];
        } else if ([identifierType isEqualToString:@"IDFV"]) {
            newValue = [self.manager generateIDFV];
        } else if ([identifierType isEqualToString:@"DeviceName"]) {
            newValue = [self.manager generateDeviceName];
        } else if ([identifierType isEqualToString:@"SerialNumber"]) {
            newValue = [self.manager generateSerialNumber];
        } else if ([identifierType isEqualToString:@"IOSVersion"]) {
            // Generate iOS Version and then get the string representation
            [self.manager generateIOSVersion];
            newValue = [self.manager currentValueForIdentifier:@"IOSVersion"];
        } else if ([identifierType isEqualToString:@"WiFi"]) {
            newValue = [self.manager generateWiFiInformation];
        } else if ([identifierType isEqualToString:@"SystemBootUUID"]) {
            newValue = [self.manager generateSystemBootUUID];
        } else if ([identifierType isEqualToString:@"DyldCacheUUID"]) {
            newValue = [self.manager generateDyldCacheUUID];
        } else if ([identifierType isEqualToString:@"PasteboardUUID"]) {
            newValue = [self.manager generatePasteboardUUID];
        } else if ([identifierType isEqualToString:@"KeychainUUID"]) {
            newValue = [self.manager generateKeychainUUID];
        } else if ([identifierType isEqualToString:@"UserDefaultsUUID"]) {
            newValue = [self.manager generateUserDefaultsUUID];
        } else if ([identifierType isEqualToString:@"AppGroupUUID"]) {
            newValue = [self.manager generateAppGroupUUID];
        } else if ([identifierType isEqualToString:@"StorageSystem"]) {
            // Get StorageManager class
            Class storageManagerClass = NSClassFromString(@"StorageManager");
            if (storageManagerClass && [storageManagerClass respondsToSelector:@selector(sharedManager)]) {
                id storageManager = [storageManagerClass sharedManager];
                if (storageManager) {
                    // Generate a random storage capacity (either 64GB or 128GB)
                    NSString *capacity = [storageManager respondsToSelector:@selector(randomizeStorageCapacity)] ? 
                                       [storageManager randomizeStorageCapacity] : @"64";
                    
                    // Generate the storage information based on the capacity
                    if ([storageManager respondsToSelector:@selector(generateStorageForCapacity:)]) {
                        NSDictionary *storageInfo = [storageManager generateStorageForCapacity:capacity];
                        if (storageInfo) {
                            // Update the StorageManager with the generated values
                            [storageManager setTotalStorageCapacity:storageInfo[@"TotalStorage"]];
                            [storageManager setFreeStorageSpace:storageInfo[@"FreeStorage"]];
                            [storageManager setFilesystemType:storageInfo[@"FilesystemType"]];
                            
                            // Format the value for display
                            newValue = [NSString stringWithFormat:@"Total: %@ GB, Free: %@ GB", 
                                      storageInfo[@"TotalStorage"], 
                                      storageInfo[@"FreeStorage"]];
                        }
                    }
                }
            }
            
            // If we couldn't generate a value, use a fallback
            if (!newValue) {
                BOOL use128GB = (arc4random_uniform(100) < 60);
                newValue = use128GB ? @"Total: 128 GB, Free: 38.4 GB" : @"Total: 64 GB, Free: 19.8 GB";
            }
        } else if ([identifierType isEqualToString:@"Battery"]) {
            // Get BatteryManager class
            Class batteryManagerClass = NSClassFromString(@"BatteryManager");
            if (batteryManagerClass && [batteryManagerClass respondsToSelector:@selector(sharedManager)]) {
                id batteryManager = [batteryManagerClass sharedManager];
                if (batteryManager && [batteryManager respondsToSelector:@selector(generateBatteryInfo)]) {
                    NSDictionary *batteryInfo = [batteryManager generateBatteryInfo];
                    if (batteryInfo) {
                        // Update display value - just show battery percentage now
                        NSString *level = batteryInfo[@"BatteryLevel"];
                        float levelFloat = [level floatValue];
                        int percentage = (int)(levelFloat * 100);
                        
                        newValue = [NSString stringWithFormat:@"%d%%", percentage];
                    }
                }
            }
            
            // If we couldn't generate a value, use a fallback
            if (!newValue) {
                int randomPercentage = 20 + arc4random_uniform(81); // 20-100%
                newValue = [NSString stringWithFormat:@"%d%%", randomPercentage];
            }
        } else if ([identifierType isEqualToString:@"SystemUptime"]) {
            NSString *profilePath = [self.manager profileIdentityPath];
            [[UptimeManager sharedManager] generateUptimeForProfile:profilePath];
            newValue = [self.manager currentValueForIdentifier:@"SystemUptime"];
        } else if ([identifierType isEqualToString:@"BootTime"]) {
            NSString *profilePath = [self.manager profileIdentityPath];
            [[UptimeManager sharedManager] generateBootTimeForProfile:profilePath];
            newValue = [self.manager currentValueForIdentifier:@"BootTime"];
        } else if ([identifierType isEqualToString:@"CoreDataUUID"]) {
            newValue = [self.manager generateCoreDataUUID];
        } else if ([identifierType isEqualToString:@"AppInstallUUID"]) {
            newValue = [self.manager generateAppInstallUUID];
        } else if ([identifierType isEqualToString:@"AppContainerUUID"]) {
            newValue = [self.manager generateAppContainerUUID];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Re-enable button
            sender.enabled = YES;
            [sender setTitle:@"Generate" forState:UIControlStateNormal];
            [sender setTintColor:originalColor];
            
            if ([self.manager lastError]) {
                [self showError:[self.manager lastError]];
                return;
            }
            
            // Save settings after generating new value
            [self.manager saveSettings];
            
            // Use our direct update method for immediate UI update
            [self directUpdateIdentifierValue:identifierType withValue:newValue];
            
            // Enable this identifier's switch if it's not already enabled
            UISwitch *identifierSwitch = self.identifierSwitches[identifierType];
            if (identifierSwitch && !identifierSwitch.isOn) {
                identifierSwitch.on = YES;
                [self.manager setIdentifierEnabled:YES forType:identifierType];
                [self.manager saveSettings];
                
                // Update the status label
                UIStackView *switchStatusStack = (UIStackView *)identifierSwitch.superview;
                if ([switchStatusStack isKindOfClass:[UIStackView class]]) {
                    UILabel *stateLabel = [switchStatusStack.arrangedSubviews filteredArrayUsingPredicate:
                        [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
                            return [object isKindOfClass:[UILabel class]] && ((UILabel *)object).tag == 100;
                        }]].firstObject;
                    
                    if (stateLabel) {
                        stateLabel.text = @"Enabled";
                    }
                }
            }
            
            // Show success feedback
            [sender setTintColor:[UIColor systemGreenColor]];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.3 animations:^{
                    [sender setTintColor:originalColor];
                }];
            });
        });
    });
}

- (void)updateValueLabel:(NSString *)identifierType withValue:(NSString *)value {
    // Find the container view for this specific identifier type
    for (UIView *view in self.mainStackView.arrangedSubviews) {
        // Skip non-container views (like labels and spacers)
        if (![view isKindOfClass:[UIView class]] || 
            ![view.subviews.firstObject isKindOfClass:[UIVisualEffectView class]]) {
            continue;
        }
        
        // Get the content stack view
        UIStackView *contentStack = nil;
        for (UIView *subview in view.subviews) {
            if ([subview isKindOfClass:[UIStackView class]]) {
                contentStack = (UIStackView *)subview;
                break;
            }
        }
        
        if (!contentStack) continue;
        
        // Get the controls stack to find which identifier this is
        if (contentStack.arrangedSubviews.count < 2) continue;
        
        UIStackView *controlsStack = contentStack.arrangedSubviews.lastObject;
        if (![controlsStack isKindOfClass:[UIStackView class]]) continue;
        
        // Find the generate button to check its tag
        UIButton *generateButton = nil;
        for (UIView *control in controlsStack.arrangedSubviews) {
            if ([control isKindOfClass:[UIButton class]] && 
                [[(UIButton *)control currentTitle] isEqualToString:@"Generate"]) {
                generateButton = (UIButton *)control;
                break;
            }
        }
        
        if (!generateButton) continue;
        
        // Check if this is the container we want based on the tag
        BOOL isTargetContainer = (generateButton.tag == [self tagForIdentifierType:identifierType]);
        
        if (isTargetContainer) {
            // Get the identifier container
            if (contentStack.arrangedSubviews.count < 1) continue;
            
            UIView *identifierContainer = contentStack.arrangedSubviews.firstObject;
            if (![identifierContainer isKindOfClass:[UIView class]]) continue;
            
            // Get the identifier label
            UILabel *identifierLabel = nil;
            for (UIView *subview in identifierContainer.subviews) {
                if ([subview isKindOfClass:[UILabel class]]) {
                    identifierLabel = (UILabel *)subview;
                    break;
                }
            }
            
            if (!identifierLabel) continue;
            
            // Update the label text with animation
            [UIView transitionWithView:identifierLabel
                              duration:0.3
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                                identifierLabel.text = value ?: @"Not Set";
                            }
                            completion:nil];
            
            // Also update the copy button's accessibility value
            UIButton *copyButton = controlsStack.arrangedSubviews.firstObject;
            if ([copyButton isKindOfClass:[UIButton class]]) {
                copyButton.accessibilityValue = value;
            }
            
            // Found and updated the target container, no need to continue
            break;
        }
    }
}

- (void)copyButtonTapped:(UIButton *)sender {
    NSString *value = sender.accessibilityValue;
    if (value && ![value isEqualToString:@"Not Set"]) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        [pasteboard setString:value];
        
        // Enhanced visual feedback for copy action
        UIColor *originalColor = sender.tintColor;
        
        if ([UIButton buttonConfigurationClassExists]) {
            // Create a checkmark configuration for success feedback
            // Need to get configuration safely - if safeSetConfiguration was used, we can try to access .configuration
            // but it might not return what we expect if not on iOS 15. Hmmm.
            // On iOS < 15 config is not supported so we shouldn't be here.
            // But if we are here, we know the CLASS exists.
            // However, [sender configuration] might return nil or default if not set. 
            // Let's assume safeguards elsewhere work.
            UIButtonConfiguration *originalConfig = sender.configuration;
            UIButtonConfiguration *successConfig = [originalConfig copy];
            successConfig.image = [UIImage systemImageNamed:@"checkmark"];
            successConfig.baseForegroundColor = [UIColor systemGreenColor];
            
            // Animate the change
            [UIView animateWithDuration:0.2 animations:^{
                [sender safeSetConfiguration:successConfig];
            } completion:^(BOOL finished) {
                // Show success state for a moment
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    // Animate back to original state
                    [UIView animateWithDuration:0.2 animations:^{
                        UIButtonConfiguration *revertConfig = [originalConfig copy];
                        revertConfig.baseForegroundColor = originalColor;
                        [sender safeSetConfiguration:revertConfig];
                    }];
                });
            }];
        } else {
            // Fallback for iOS < 15 using tint color change
            [UIView animateWithDuration:0.2 animations:^{
                [sender setImage:[UIImage systemImageNamed:@"checkmark"] forState:UIControlStateNormal];
                sender.tintColor = [UIColor systemGreenColor];
            } completion:^(BOOL finished) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [UIView animateWithDuration:0.2 animations:^{
                        [sender setImage:[UIImage systemImageNamed:@"doc.on.doc"] forState:UIControlStateNormal];
                        sender.tintColor = originalColor;
                    }];
                });
            }];
        }
    }
}



#pragma mark - Installed Apps Popup

- (void)showInstalledAppsPopup:(UIButton *)sender {
    // Create popup view controller if not exists
    if (!self.installedAppsPopupVC) {
        self.installedAppsPopupVC = [[UIViewController alloc] init];
        self.installedAppsPopupVC.view.backgroundColor = [UIColor systemBackgroundColor];
        self.installedAppsPopupVC.modalPresentationStyle = UIModalPresentationFormSheet;
        self.installedAppsPopupVC.preferredContentSize = CGSizeMake(350, 500);
        
        // Add search bar
        self.appSearchBar = [[UISearchBar alloc] init];
        self.appSearchBar.placeholder = @"Search Apps";
        self.appSearchBar.delegate = self;
        self.appSearchBar.translatesAutoresizingMaskIntoConstraints = NO;
        [self.installedAppsPopupVC.view addSubview:self.appSearchBar];
        
        // Add close button
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [closeButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
        [closeButton addTarget:self action:@selector(closeInstalledAppsPopup:) forControlEvents:UIControlEventTouchUpInside];
        closeButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.installedAppsPopupVC.view addSubview:closeButton];
        
        // Add table view
        self.installedAppsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        self.installedAppsTableView.delegate = self;
        self.installedAppsTableView.dataSource = self;
        self.installedAppsTableView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.installedAppsPopupVC.view addSubview:self.installedAppsTableView];
        
        // Setup constraints
        [NSLayoutConstraint activateConstraints:@[
            [closeButton.topAnchor constraintEqualToAnchor:self.installedAppsPopupVC.view.topAnchor constant:16],
            [closeButton.trailingAnchor constraintEqualToAnchor:self.installedAppsPopupVC.view.trailingAnchor constant:-16],
            
            [self.appSearchBar.topAnchor constraintEqualToAnchor:closeButton.bottomAnchor constant:8],
            [self.appSearchBar.leadingAnchor constraintEqualToAnchor:self.installedAppsPopupVC.view.leadingAnchor],
            [self.appSearchBar.trailingAnchor constraintEqualToAnchor:self.installedAppsPopupVC.view.trailingAnchor],
            
            [self.installedAppsTableView.topAnchor constraintEqualToAnchor:self.appSearchBar.bottomAnchor],
            [self.installedAppsTableView.leadingAnchor constraintEqualToAnchor:self.installedAppsPopupVC.view.leadingAnchor],
            [self.installedAppsTableView.trailingAnchor constraintEqualToAnchor:self.installedAppsPopupVC.view.trailingAnchor],
            [self.installedAppsTableView.bottomAnchor constraintEqualToAnchor:self.installedAppsPopupVC.view.bottomAnchor]
        ]];
        
        // Register cell
        [self.installedAppsTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"InstalledAppCell"];
    }
    
    // Load installed apps
    [self loadInstalledApps];
    
    // Present popup
    [self presentViewController:self.installedAppsPopupVC animated:YES completion:nil];
}

- (void)loadInstalledApps {
    // Get all installed apps from LSApplicationWorkspace
    LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
    NSArray *installedApps = [workspace allInstalledApplications];
    NSMutableArray *apps = [NSMutableArray array];
    
    for (LSApplicationProxy *app in installedApps) {
        NSMutableDictionary *appInfo = [NSMutableDictionary dictionary];
        appInfo[@"name"] = app.localizedName ?: @"Unknown";
        appInfo[@"bundleID"] = app.bundleIdentifier ?: app.applicationIdentifier;
        appInfo[@"version"] = app.shortVersionString ?: @"1.0";
        [apps addObject:appInfo];
    }
    
    // Sort apps by name
    self.installedApps = [apps sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *app1, NSDictionary *app2) {
        return [app1[@"name"] compare:app2[@"name"]];
    }];
    self.filteredApps = self.installedApps;
    [self.installedAppsTableView reloadData];
}

- (void)closeInstalledAppsPopup:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchBar == self.versionSearchBar) {
        // Handle version search
        if (searchText.length == 0) {
            self.filteredVersions = self.appVersions;
        } else {
            NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *version, NSDictionary *bindings) {
                NSString *versionString = version[@"version"];
                NSString *releaseDate = version[@"releaseDate"];
                
                // Format the date for display
                NSString *formattedDate = @"Unknown";
                if (![releaseDate isEqualToString:@"Unknown"]) {
                    // Try parsing as ISO 8601 date string first
                    NSDateFormatter *isoFormatter = [[NSDateFormatter alloc] init];
                    isoFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
                    NSDate *date = [isoFormatter dateFromString:releaseDate];
                    
                    // If that fails, try parsing as "yyyy-MM-dd HH:mm:ss" format
                    if (!date) {
                        NSDateFormatter *altFormatter = [[NSDateFormatter alloc] init];
                        altFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
                        date = [altFormatter dateFromString:releaseDate];
                    }
                    
                    // If that fails, try parsing as timestamp
                    if (!date && releaseDate.length > 0) {
                        NSTimeInterval timestamp = [releaseDate doubleValue];
                        if (timestamp > 0) {
                            date = [NSDate dateWithTimeIntervalSince1970:timestamp];
                        }
                    }
                    
                    if (date) {
                        formattedDate = [self.dateFormatter stringFromDate:date];
                    }
                }
                
                return [versionString localizedCaseInsensitiveContainsString:searchText] ||
                       [formattedDate localizedCaseInsensitiveContainsString:searchText];
            }];
            
            self.filteredVersions = [self.appVersions filteredArrayUsingPredicate:predicate];
        }
        [self.versionsTableView reloadData];
    } else if (searchBar == self.appSearchBar) {
        // Handle app search
        if (searchText.length == 0) {
            self.filteredApps = self.installedApps;
        } else {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@ OR bundleID CONTAINS[cd] %@", searchText, searchText];
            self.filteredApps = [self.installedApps filteredArrayUsingPredicate:predicate];
        }
        [self.installedAppsTableView reloadData];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - App Versions Management

- (void)versionsButtonTapped:(UIButton *)sender {
    NSString *bundleID = self.appSwitches.allKeys[sender.tag];
    self.selectedBundleID = bundleID;
    
    // Create versions popup if not exists
    if (!self.versionsPopupVC) {
        self.versionsPopupVC = [[UIViewController alloc] init];
        self.versionsPopupVC.view.backgroundColor = [UIColor systemBackgroundColor];
        self.versionsPopupVC.modalPresentationStyle = UIModalPresentationFormSheet;
        self.versionsPopupVC.preferredContentSize = CGSizeMake(350, 500);
        
        // Add tap gesture recognizer to dismiss keyboard
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
        tapGesture.cancelsTouchesInView = NO;
        [self.versionsPopupVC.view addGestureRecognizer:tapGesture];
        
        // Title label
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.text = @"TAP ON APPNAME TO INSTALL";
        titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        titleLabel.textColor = [UIColor secondaryLabelColor];
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.versionsPopupVC.view addSubview:titleLabel];
        
        // Add close button
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [closeButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
        [closeButton addTarget:self action:@selector(closeVersionsPopup:) forControlEvents:UIControlEventTouchUpInside];
        closeButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.versionsPopupVC.view addSubview:closeButton];
        
        // Add search bar
        self.versionSearchBar = [[UISearchBar alloc] init];
        self.versionSearchBar.placeholder = @"Search versions or dates";
        self.versionSearchBar.delegate = self;
        self.versionSearchBar.translatesAutoresizingMaskIntoConstraints = NO;
        [self.versionsPopupVC.view addSubview:self.versionSearchBar];
        
        // Add loading indicator
        UIActivityIndicatorView *loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
        [self.versionsPopupVC.view addSubview:loadingIndicator];
        
        // Add table view
        self.versionsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        self.versionsTableView.delegate = self;
        self.versionsTableView.dataSource = self;
        self.versionsTableView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.versionsPopupVC.view addSubview:self.versionsTableView];
        
        // Setup constraints
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.centerYAnchor constraintEqualToAnchor:closeButton.centerYAnchor],
            [titleLabel.leadingAnchor constraintEqualToAnchor:self.versionsPopupVC.view.leadingAnchor constant:16],
            [titleLabel.trailingAnchor constraintEqualToAnchor:closeButton.leadingAnchor constant:-8],
            
            [closeButton.topAnchor constraintEqualToAnchor:self.versionsPopupVC.view.topAnchor constant:16],
            [closeButton.trailingAnchor constraintEqualToAnchor:self.versionsPopupVC.view.trailingAnchor constant:-16],
            
            [self.versionSearchBar.topAnchor constraintEqualToAnchor:closeButton.bottomAnchor constant:8],
            [self.versionSearchBar.leadingAnchor constraintEqualToAnchor:self.versionsPopupVC.view.leadingAnchor],
            [self.versionSearchBar.trailingAnchor constraintEqualToAnchor:self.versionsPopupVC.view.trailingAnchor],
            
            [loadingIndicator.centerXAnchor constraintEqualToAnchor:self.versionsPopupVC.view.centerXAnchor],
            [loadingIndicator.centerYAnchor constraintEqualToAnchor:self.versionsPopupVC.view.centerYAnchor],
            
            [self.versionsTableView.topAnchor constraintEqualToAnchor:self.versionSearchBar.bottomAnchor],
            [self.versionsTableView.leadingAnchor constraintEqualToAnchor:self.versionsPopupVC.view.leadingAnchor],
            [self.versionsTableView.trailingAnchor constraintEqualToAnchor:self.versionsPopupVC.view.trailingAnchor],
            [self.versionsTableView.bottomAnchor constraintEqualToAnchor:self.versionsPopupVC.view.bottomAnchor]
        ]];
        
        // Register cell
        [self.versionsTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"VersionCell"];
        
        // Initialize date formatter
        self.dateFormatter = [[NSDateFormatter alloc] init];
        self.dateFormatter.dateStyle = NSDateFormatterMediumStyle;
        self.dateFormatter.timeStyle = NSDateFormatterNoStyle;
    }
    
    // Show loading indicator
    UIActivityIndicatorView *loadingIndicator = [self.versionsPopupVC.view.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [object isKindOfClass:[UIActivityIndicatorView class]];
    }]].firstObject;
    [loadingIndicator startAnimating];
    self.versionsTableView.hidden = YES;
    
    // Present popup
    [self presentViewController:self.versionsPopupVC animated:YES completion:^{
        // Fetch versions
        [[AppVersionManager sharedManager] fetchVersionsForBundleID:bundleID completion:^(NSArray<NSDictionary *> *versions, NSError *error) {
            [loadingIndicator stopAnimating];
            self.versionsTableView.hidden = NO;
            
            if (error) {
                [self showError:error];
                return;
            }
            
            self.appVersions = versions;
            self.filteredVersions = versions;
            [self.versionsTableView reloadData];
        }];
    }];
}

- (void)closeVersionsPopup:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Clear Data Button

- (void)showProgressHUDWithTitle:(NSString *)title {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.progressHUD) [self.progressHUD removeFromSuperview];
        self.progressHUD = [ProgressHUDView showHUDAddedTo:self.view title:title];
    });
}

- (void)updateProgress:(float)progress detail:(NSString *)detail {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.progressHUD) {
            [self.progressHUD setProgress:progress animated:YES];
            [self.progressHUD setDetailText:detail];
        }
    });
}

- (void)hideProgressHUD {
    dispatch_async(dispatch_get_main_queue(), ^{
        [ProgressHUDView hideHUDForView:self.view];
        self.progressHUD = nil;
    });
}

- (void)clearDataButtonTapped:(UIButton *)sender {
    NSString *bundleID = self.appSwitches.allKeys[sender.tag];
    if (!bundleID) {
        return;
    }
    
    // --- Show progress HUD for data search ---
    [self showProgressHUDWithTitle:@"Fetching data..."];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block BOOL foundData = NO;
        // Simulate progress for data search (replace with real progress if possible)
        for (int i = 0; i <= 100; i += 10) {
            [self updateProgress:i/100.0 detail:[NSString stringWithFormat:@"Scanning... %d%%", i]];
            [NSThread sleepForTimeInterval:0.01];
        }
        foundData = [[AppDataCleaner sharedManager] hasDataToClear:bundleID];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideProgressHUD];
            // --- End progress HUD for data search ---

            // Check if there's data to clear
            if (!foundData) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"No Data"
                                                                             message:@"No app data found to clear."
                                                                      preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:nil];
                [alert addAction:okAction];
                [self presentViewController:alert animated:YES completion:nil];
                return;
            }

            // Get data usage information from UserDefaults where AppDataCleaner stores it
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSDictionary *dataUsage = [defaults objectForKey:[NSString stringWithFormat:@"DataUsage_%@", bundleID]];
            // Format the data size for display
            NSString *dataSizeStr = @"Unknown size";
            if (dataUsage && dataUsage[@"totalSize"]) {
                long long totalSize = [dataUsage[@"totalSize"] longLongValue];
                NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
                formatter.countStyle = NSByteCountFormatterCountStyleFile;
                dataSizeStr = [formatter stringFromByteCount:totalSize];
            }
            NSString *dataDetailsStr = @"";
            if (dataUsage) {
                NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
                formatter.countStyle = NSByteCountFormatterCountStyleFile;
                if (dataUsage[@"dataSize"])
                    dataDetailsStr = [dataDetailsStr stringByAppendingFormat:@"\n• App Data: %@",
                                      [formatter stringFromByteCount:[dataUsage[@"dataSize"] longLongValue]]];
                if (dataUsage[@"sharedSize"])
                    dataDetailsStr = [dataDetailsStr stringByAppendingFormat:@"\n• Shared Data: %@",
                                     [formatter stringFromByteCount:[dataUsage[@"sharedSize"] longLongValue]]];
            }
            [self presentClearDataAlertForBundleID:bundleID sender:sender dataSizeStr:dataSizeStr dataDetailsStr:dataDetailsStr];
        });
    });
}

- (void)handleKeychainGroupsSaved:(NSNotification *)note {
    NSString *bundleID = nil;
    if ([note.userInfo[@"bundleID"] isKindOfClass:[NSString class]]) {
        bundleID = note.userInfo[@"bundleID"];
    }
    if (!bundleID.length) return;
    if (!self.pendingClearDataBundleID.length || ![bundleID isEqualToString:self.pendingClearDataBundleID]) {
        return;
    }
    if (!self.pendingClearDataSender) {
        return;
    }
    NSString *sizeStr = self.pendingClearDataSizeStr ?: @"";
    NSString *detailsStr = self.pendingClearDataDetailsStr ?: @"";
    UIButton *sender = self.pendingClearDataSender;

    self.pendingClearDataBundleID = nil;
    self.pendingClearDataSender = nil;
    self.pendingClearDataSizeStr = nil;
    self.pendingClearDataDetailsStr = nil;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentClearDataAlertForBundleID:bundleID sender:sender dataSizeStr:sizeStr dataDetailsStr:detailsStr];
    });
}

- (void)presentClearDataAlertForBundleID:(NSString *)bundleID
                                  sender:(UIButton *)sender
                              dataSizeStr:(NSString *)dataSizeStr
                           dataDetailsStr:(NSString *)dataDetailsStr {
    if (!bundleID.length) return;

     BOOL isSystemApp = [bundleID hasPrefix:@"com.apple."];
     NSUserDefaults *sec = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
     BOOL allowSystemKeychainWipe = [sec boolForKey:@"allowSystemKeychainWipeEnabled"];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *enabledKey = PXKeychainWipeEnabledKey(bundleID);
    NSString *groupsKey = PXKeychainWipeGroupsKey(bundleID);

    // Default OFF (safer): wiping keychain will log out many apps.
    BOOL keychainEnabled = NO;
    if ([defaults objectForKey:enabledKey] != nil) {
        keychainEnabled = [defaults boolForKey:enabledKey];
    }

    NSArray<NSString *> *selectedGroups = nil;
    id savedGroups = [defaults objectForKey:groupsKey];
    if ([savedGroups isKindOfClass:[NSArray class]]) {
        selectedGroups = (NSArray<NSString *> *)savedGroups;
    }

    // Default: select ALL groups from entitlements if not present.
    if (!selectedGroups.count) {
        NSError *err = nil;
        AppEntitlementsReader *reader = [[AppEntitlementsReader alloc] init];
        NSArray<NSString *> *entGroups = [reader keychainAccessGroupsForBundleID:bundleID error:&err];
        if (entGroups.count > 0) {
            selectedGroups = entGroups;
            [defaults setObject:entGroups forKey:groupsKey];
            // Do not auto-enable keychain wipe.
            [defaults setBool:NO forKey:enabledKey];
            [defaults synchronize];
            keychainEnabled = NO;
        } else {
            selectedGroups = @[];
        }
    }

     if (isSystemApp && !allowSystemKeychainWipe) {
         // Force keychain wipe off for system apps unless explicitly enabled.
         keychainEnabled = NO;
         [defaults setBool:NO forKey:enabledKey];
         [defaults synchronize];
     }

     NSString *keychainState = keychainEnabled ? @"ON" : ((isSystemApp && !allowSystemKeychainWipe) ? @"OFF (Not supported)" : @"OFF");
     NSString *groupsLine = (isSystemApp && !allowSystemKeychainWipe) ? @"N/A" : (selectedGroups.count > 0 ? [NSString stringWithFormat:@"%lu", (unsigned long)selectedGroups.count] : @"Unavailable");

    NSString *msg = [NSString stringWithFormat:@"Are you sure you want to clear all data for this app? This will remove %@.%@\n\nKeychain Wipe: %@ (may log you out)\nKeychain Groups: %@\n\nThis action cannot be undone.",
                     dataSizeStr ?: @"", dataDetailsStr ?: @"", keychainState, groupsLine];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Clear App Data"
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleAlert];

    __weak typeof(self) weakSelf = self;
     if (!isSystemApp || allowSystemKeychainWipe) {
        NSString *toggleTitle = [NSString stringWithFormat:@"Keychain Wipe: %@", keychainState];
        UIAlertAction *toggleAction = [UIAlertAction actionWithTitle:toggleTitle
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(__unused UIAlertAction *action) {
            BOOL newVal = !keychainEnabled;
            [defaults setBool:newVal forKey:enabledKey];
            [defaults synchronize];
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf presentClearDataAlertForBundleID:bundleID sender:sender dataSizeStr:dataSizeStr dataDetailsStr:dataDetailsStr];
            });
        }];
        [alert addAction:toggleAction];

        NSString *groupsTitle = selectedGroups.count > 0 ? [NSString stringWithFormat:@"Keychain Groups (%lu)…", (unsigned long)selectedGroups.count] : @"Keychain Groups…";
        UIAlertAction *groupsAction = [UIAlertAction actionWithTitle:groupsTitle
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(__unused UIAlertAction *action) {
            KeychainGroupsViewController *vc = [[KeychainGroupsViewController alloc] initWithBundleID:bundleID];
            weakSelf.pendingClearDataBundleID = bundleID;
            weakSelf.pendingClearDataSender = sender;
            weakSelf.pendingClearDataSizeStr = dataSizeStr;
            weakSelf.pendingClearDataDetailsStr = dataDetailsStr;
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }];
        [alert addAction:groupsAction];
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];

    UIAlertAction *clearAction = [UIAlertAction actionWithTitle:@"Clear Data"
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(__unused UIAlertAction *action) {
        // Disable the button temporarily
        sender.enabled = NO;
        [sender setTintColor:[UIColor systemGrayColor]];

        [weakSelf showProgressHUDWithTitle:@"Clearing data..."];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            for (int i = 0; i <= 100; i += 10) {
                [weakSelf updateProgress:i/100.0 detail:[NSString stringWithFormat:@"Deleting... %d%%", i]];
                [NSThread sleepForTimeInterval:0.01];
            }

            [[AppDataCleaner sharedManager] clearDataForBundleID:bundleID completion:^(BOOL success, NSError *error) {
                [weakSelf hideProgressHUD];
                dispatch_async(dispatch_get_main_queue(), ^{
                    sender.enabled = YES;
                    [sender setTintColor:[UIColor systemRedColor]];
                    if (!success) {
                        [weakSelf showError:error];
                        return;
                    }
                    NSDictionary *cleaningResult = [defaults objectForKey:[NSString stringWithFormat:@"DataCleaningResult_%@", bundleID]];
                    NSString *resultMessage = @"App data has been cleared successfully.";
                    if (cleaningResult) {
                        NSDictionary *beforeSize = cleaningResult[@"beforeSize"];
                        NSDictionary *afterSize = cleaningResult[@"afterSize"];
                        if (beforeSize && afterSize && beforeSize[@"totalSize"] && afterSize[@"totalSize"]) {
                            long long clearedBytes = [beforeSize[@"totalSize"] longLongValue] - [afterSize[@"totalSize"] longLongValue];
                            if (clearedBytes > 0) {
                                NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
                                formatter.countStyle = NSByteCountFormatterCountStyleFile;
                                NSString *clearedSizeStr = [formatter stringFromByteCount:clearedBytes];
                                resultMessage = [NSString stringWithFormat:@"Successfully cleared %@ of app data.", clearedSizeStr];
                            }
                        }
                    }
                    UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"Success"
                                                                                           message:resultMessage
                                                                                    preferredStyle:UIAlertControllerStyleAlert];
                    [successAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [weakSelf presentViewController:successAlert animated:YES completion:nil];
                });
            }];
        });
    }];
    [alert addAction:clearAction];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)deleteAppButtonTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    if (index < 0 || index >= self.appSwitches.allKeys.count) {
        return;
    }
    
    NSString *bundleID = self.appSwitches.allKeys[index];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Remove App"
                                                                   message:[NSString stringWithFormat:@"Are you sure you want to remove %@ from the scoped apps list?", bundleID]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Remove" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self.manager removeApplicationFromScope:bundleID];
        [self updateAppsList];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)installAppWithAdamId:(NSString *)adamId appExtVrsId:(NSString *)appExtVrsId bundleID:(NSString *)bundleID appName:(NSString *)appName version:(NSString *)version {
    // This is the exact method MuffinStore uses
    NSString *urlString = [NSString stringWithFormat:@"itms-apps://buy.itunes.apple.com/WebObjects/MZBuy.woa/wa/buyProduct?id=%@&mt=8&appExtVrsId=%@", 
                          adamId, appExtVrsId];
    NSURL *url = [NSURL URLWithString:urlString];
    
    // MuffinStore uses this exact method to open the URL
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        if (success) {
            // Show success alert
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *truncatedAppName = appName;
                if (appName.length > 15) {
                    truncatedAppName = [NSString stringWithFormat:@"%@...", [appName substringToIndex:15]];
                }
                
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Installation Started"
                                                                              message:[NSString stringWithFormat:@"%@ version %@ is being installed.", truncatedAppName, version]
                                                                       preferredStyle:UIAlertControllerStyleAlert];
                
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            });
        } else {
            // Show error alert
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Installation Failed"
                                                                              message:@"Failed to initiate installation. Please try again."
                                                                       preferredStyle:UIAlertControllerStyleAlert];
                
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            });
        }
    }];
}

- (void)installButtonTapped:(UIButton *)sender {
    // Check if the sender tag is valid
    if (sender.tag < 0 || sender.tag >= self.filteredVersions.count) {
        return;
    }
    
    // Get the selected version
    NSDictionary *selectedVersion = self.filteredVersions[sender.tag];
    
    // Extract required information
    NSString *bundleID = selectedVersion[@"bundleId"];
    NSNumber *trackIdNum = selectedVersion[@"trackId"];
    NSNumber *externalIdNum = selectedVersion[@"external_identifier"];
    NSString *appName = selectedVersion[@"appName"];
    NSString *versionString = selectedVersion[@"version"];
    
    // Check if we have all required information
    if (!bundleID || !trackIdNum || !externalIdNum || !appName || !versionString) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" 
                                                                       message:@"Missing required app information" 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // Convert track ID and external ID to strings
    NSString *trackId = [trackIdNum stringValue];
    NSString *externalId = [externalIdNum stringValue];
    
    // Temporarily disable the button and update its title
    sender.enabled = NO;
    NSString *originalButtonTitle = [sender titleForState:UIControlStateNormal];
    [sender setTitle:@"Installing..." forState:UIControlStateNormal];
    
    // Use the MuffinStore-style installation method
    [self installAppWithAdamId:trackId appExtVrsId:externalId bundleID:bundleID appName:appName version:versionString];
    
    // Re-enable the button after a short delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        sender.enabled = YES;
        [sender setTitle:originalButtonTitle forState:UIControlStateNormal];
    });
}

- (UIImage *)createNotInAppStoreImage {
    // Create a context with a transparent background
    CGSize size = CGSizeMake(200, 200);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    
    // Setup text attributes
    NSString *text = @"App Not In AppStore";
    UIFont *font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: [UIColor.labelColor colorWithAlphaComponent:3],
        NSParagraphStyleAttributeName: paragraphStyle
    };
    
    // Calculate text size and position
    CGRect textRect = [text boundingRectWithSize:size
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:attributes
                                         context:nil];
    
    CGRect drawRect = CGRectMake((size.width - textRect.size.width) / 2,
                                 (size.height - textRect.size.height) / 2,
                                 textRect.size.width,
                                 textRect.size.height);
    
    // Draw the text
    [text drawInRect:drawRect withAttributes:attributes];
    
    // Get the image and end the context
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (void)fetchAppIconForBundleID:(NSString *)bundleID completion:(void (^)(UIImage *icon))completion {
    // Check cache first
    UIImage *cachedIcon = [self.iconCache objectForKey:bundleID];
    if (cachedIcon) {
        completion(cachedIcon);
        return;
    }
    
    // Construct iTunes lookup URL
    NSString *urlString = [NSString stringWithFormat:@"https://itunes.apple.com/lookup?bundleId=%@", bundleID];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage *notFoundImage = [self createNotInAppStoreImage];
                [self.iconCache setObject:notFoundImage forKey:bundleID];
                completion(notFoundImage);
            });
            return;
        }
        
        NSError *jsonError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (jsonError || ![json isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage *notFoundImage = [self createNotInAppStoreImage];
                [self.iconCache setObject:notFoundImage forKey:bundleID];
                completion(notFoundImage);
            });
            return;
        }
        
        NSArray *results = json[@"results"];
        if (![results isKindOfClass:[NSArray class]] || results.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage *notFoundImage = [self createNotInAppStoreImage];
                [self.iconCache setObject:notFoundImage forKey:bundleID];
                completion(notFoundImage);
            });
            return;
        }
        
        NSDictionary *appInfo = results.firstObject;
        NSString *iconURLString = appInfo[@"artworkUrl512"];
        if (!iconURLString) {
            iconURLString = appInfo[@"artworkUrl100"];
        }
        
        if (!iconURLString) {
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage *notFoundImage = [self createNotInAppStoreImage];
                [self.iconCache setObject:notFoundImage forKey:bundleID];
                completion(notFoundImage);
            });
            return;
        }
        
        NSURL *iconURL = [NSURL URLWithString:iconURLString];
        [[session dataTaskWithURL:iconURL completionHandler:^(NSData *iconData, NSURLResponse *iconResponse, NSError *iconError) {
            UIImage *icon = nil;
            if (!iconError && iconData) {
                icon = [UIImage imageWithData:iconData];
                if (icon) {
                    [self.iconCache setObject:icon forKey:bundleID];
                } else {
                    icon = [self createNotInAppStoreImage];
                    [self.iconCache setObject:icon forKey:bundleID];
                }
            } else {
                icon = [self createNotInAppStoreImage];
                [self.iconCache setObject:icon forKey:bundleID];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(icon);
            });
        }] resume];
    }] resume];
}

- (void)directUpdateIdentifierValue:(NSString *)identifierType withValue:(NSString *)value {
    // Find all identifier cells
    BOOL foundContainer = NO;
    
    for (UIView *view in self.mainStackView.arrangedSubviews) {
        // Skip if not a view or doesn't have subviews
        if (![view isKindOfClass:[UIView class]] || view.subviews.count == 0) {
            continue;
        }
        
        // Find the content stack view
        UIStackView *contentStack = nil;
        for (UIView *subview in view.subviews) {
            if ([subview isKindOfClass:[UIStackView class]]) {
                contentStack = (UIStackView *)subview;
                break;
            }
        }
        
        if (!contentStack || contentStack.arrangedSubviews.count < 2) {
            continue;
        }
        
        // Get the controls stack
        UIStackView *controlsStack = contentStack.arrangedSubviews.lastObject;
        if (![controlsStack isKindOfClass:[UIStackView class]]) continue;
        
        // Find the generate button to check its tag
        UIButton *generateButton = nil;
        for (UIView *control in controlsStack.arrangedSubviews) {
            if ([control isKindOfClass:[UIButton class]]) {
                UIButton *button = (UIButton *)control;
                NSString *buttonTitle = [button titleForState:UIControlStateNormal];
                BOOL isGenerate = [buttonTitle isEqualToString:@"Generate"];
                
                if (!isGenerate && [UIButton buttonConfigurationClassExists]) {
                    // Only check configuration if class exists (iOS 15+)
                    // Use performSelector to avoid compiler warnings if strict checking is enabled
                    // But direct access is fine since we verified class exists
                    // Actually, to be super safe against dynamic dispatch issues if the property isn't seen by compiler on older SDKs?
                    // No, SDK is new enough.
                    if (@available(iOS 15.0, *)) {
                         if ([button.configuration.title isEqualToString:@"Generate"]) {
                             isGenerate = YES;
                         }
                    }
                }
                
                if (isGenerate) {
                    generateButton = button;
                    break;
                }
            }
        }
        
        if (!generateButton) {
            continue;
        }
        
        // Check if this is the container we want based on the tag
        BOOL isTargetContainer = (generateButton.tag == [self tagForIdentifierType:identifierType]);
        
        if (isTargetContainer) {
            NSLog(@"[WeaponX] ✅ Found container for %@ (tag: %ld)", identifierType, (long)generateButton.tag);
            foundContainer = YES;
            
            // Get the identifier container (first subview in content stack)
            UIView *identifierContainer = contentStack.arrangedSubviews.firstObject;
            if (![identifierContainer isKindOfClass:[UIView class]]) {
                NSLog(@"[WeaponX] ❌ Identifier container is not a UIView");
                continue;
            }
            
            // Find the label within the container
            UILabel *identifierLabel = nil;
            for (UIView *subview in identifierContainer.subviews) {
                if ([subview isKindOfClass:[UILabel class]]) {
                    identifierLabel = (UILabel *)subview;
                    break;
                }
            }
            
            if (identifierLabel) {
                NSLog(@"[WeaponX] 🔄 Updating label from '%@' to '%@'", identifierLabel.text, value);
                
                // Ensure the update happens on the main thread
                if ([NSThread isMainThread]) {
                    identifierLabel.text = value ?: @"Not Set";
                    NSLog(@"[WeaponX] ✅ Label updated directly on main thread");
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        identifierLabel.text = value ?: @"Not Set";
                        NSLog(@"[WeaponX] ✅ Label updated via dispatch to main thread");
                    });
                }
                
                // Update the copy button's accessibility value
                UIButton *copyButton = controlsStack.arrangedSubviews.firstObject;
                if ([copyButton isKindOfClass:[UIButton class]]) {
                    copyButton.accessibilityValue = value;
                }
                
                return;
            } else {
                NSLog(@"[WeaponX] ❌ Could not find label in container");
            }
        }
    }
    
    if (!foundContainer) {
        NSLog(@"[WeaponX] ❌ Could not find container for %@", identifierType);
    }
}

- (void)generateAllButtonTapped:(UIButton *)sender {
    // Check if user has an active plan
    BOOL isRestricted = [[NSUserDefaults standardUserDefaults] boolForKey:@"WeaponXRestrictedAccess"];
    
    // Also check associated object as a backup
    if (!isRestricted) {
        UIViewController *topVC = [self findTopViewController];
        NSNumber *restrictedAccess = objc_getAssociatedObject(topVC, "WeaponXRestrictedAccess");
        isRestricted = restrictedAccess ? [restrictedAccess boolValue] : NO;
    }
    
    // If user doesn't have an active plan, show alert and prevent action
    // if (isRestricted) {
    //     UIAlertController *alert = [UIAlertController 
    //         alertControllerWithTitle:@"Access Restricted" 
    //         message:@"Please subscribe to a plan to use the generate feature." 
    //         preferredStyle:UIAlertControllerStyleAlert];
        
    //     [alert addAction:[UIAlertAction 
    //         actionWithTitle:@"View Plans" 
    //         style:UIAlertActionStyleDefault 
    //         handler:^(UIAlertAction * _Nonnull action) {
    //             // Switch to account tab to view plans
    //             UITabBarController *tabController = [self findTabBarController];
    //             if ([tabController respondsToSelector:@selector(switchToAccountTab)]) {
    //                 [tabController performSelector:@selector(switchToAccountTab)];
    //             }
    //         }]];
        
    //     [alert addAction:[UIAlertAction 
    //         actionWithTitle:@"Cancel" 
    //         style:UIAlertActionStyleCancel 
    //         handler:nil]];
        
    //     [self presentViewController:alert animated:YES completion:nil];
    //     return;
    // }
    
    // Disable button temporarily
    sender.enabled = NO;
    
    // Show loading state
    UIColor *originalColor = sender.tintColor;
    [sender setTintColor:[UIColor systemGrayColor]];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Regenerate all enabled identifiers
        [self.manager regenerateAllEnabledIdentifiers];
        
        // Get the new values for UI update
        NSString *newIDFA = [self.manager currentValueForIdentifier:@"IDFA"];
        NSString *newIDFV = [self.manager currentValueForIdentifier:@"IDFV"];
        NSString *newDeviceName = [self.manager currentValueForIdentifier:@"DeviceName"];
        NSString *newSerialNumber = [self.manager currentValueForIdentifier:@"SerialNumber"];
        NSString *newIOSVersion = [self.manager currentValueForIdentifier:@"IOSVersion"];
        NSString *newWiFiInfo = [self.manager currentValueForIdentifier:@"WiFi"];
        NSString *newStorageInfo = [self.manager currentValueForIdentifier:@"StorageSystem"];
        NSString *newBatteryInfo = [self.manager currentValueForIdentifier:@"Battery"];
        NSString *newSystemBootUUID = [self.manager currentValueForIdentifier:@"SystemBootUUID"];
        NSString *newDyldCacheUUID = [self.manager currentValueForIdentifier:@"DyldCacheUUID"];
        NSString *newPasteboardUUID = [self.manager currentValueForIdentifier:@"PasteboardUUID"];
        NSString *newKeychainUUID = [self.manager currentValueForIdentifier:@"KeychainUUID"];
        NSString *newUserDefaultsUUID = [self.manager currentValueForIdentifier:@"UserDefaultsUUID"];
        NSString *newAppGroupUUID = [self.manager currentValueForIdentifier:@"AppGroupUUID"];
        NSString *newDeviceModel = [self.manager currentValueForIdentifier:@"DeviceModel"];
        [self.manager generateSystemUptime];
        [self.manager generateBootTime];
        NSString *newSystemUptime = [self.manager currentValueForIdentifier:@"SystemUptime"];
        NSString *newBootTime = [self.manager currentValueForIdentifier:@"BootTime"];
        NSString *newCoreDataUUID = [self.manager generateCoreDataUUID];
        NSString *newAppInstallUUID = [self.manager currentValueForIdentifier:@"AppInstallUUID"];
        NSString *newAppContainerUUID = [self.manager currentValueForIdentifier:@"AppContainerUUID"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Re-enable button
            sender.enabled = YES;
            [sender setTintColor:originalColor];
            
            // Update UI with new values
            if ([self.manager isIdentifierEnabled:@"IDFA"]) {
                [self directUpdateIdentifierValue:@"IDFA" withValue:newIDFA];
            }
            
            if ([self.manager isIdentifierEnabled:@"IDFV"]) {
                [self directUpdateIdentifierValue:@"IDFV" withValue:newIDFV];
            }
            
            if ([self.manager isIdentifierEnabled:@"DeviceName"]) {
                [self directUpdateIdentifierValue:@"DeviceName" withValue:newDeviceName];
            }
            
            if ([self.manager isIdentifierEnabled:@"SerialNumber"]) {
                [self directUpdateIdentifierValue:@"SerialNumber" withValue:newSerialNumber];
            }
            
            if ([self.manager isIdentifierEnabled:@"IOSVersion"]) {
                [self directUpdateIdentifierValue:@"IOSVersion" withValue:newIOSVersion];
            }
            
            if ([self.manager isIdentifierEnabled:@"WiFi"]) {
                [self directUpdateIdentifierValue:@"WiFi" withValue:newWiFiInfo];
            }
            
            if ([self.manager isIdentifierEnabled:@"StorageSystem"]) {
                [self directUpdateIdentifierValue:@"StorageSystem" withValue:newStorageInfo];
            }
            
            if ([self.manager isIdentifierEnabled:@"Battery"]) {
                [self directUpdateIdentifierValue:@"Battery" withValue:newBatteryInfo];
            }
            
            if ([self.manager isIdentifierEnabled:@"SystemBootUUID"]) {
                [self directUpdateIdentifierValue:@"SystemBootUUID" withValue:newSystemBootUUID];
            }
            
            if ([self.manager isIdentifierEnabled:@"DyldCacheUUID"]) {
                [self directUpdateIdentifierValue:@"DyldCacheUUID" withValue:newDyldCacheUUID];
            }
            
            if ([self.manager isIdentifierEnabled:@"PasteboardUUID"]) {
                [self directUpdateIdentifierValue:@"PasteboardUUID" withValue:newPasteboardUUID];
            }
            
            if ([self.manager isIdentifierEnabled:@"KeychainUUID"]) {
                [self directUpdateIdentifierValue:@"KeychainUUID" withValue:newKeychainUUID];
            }
            
            if ([self.manager isIdentifierEnabled:@"UserDefaultsUUID"]) {
                [self directUpdateIdentifierValue:@"UserDefaultsUUID" withValue:newUserDefaultsUUID];
            }
            
            if ([self.manager isIdentifierEnabled:@"AppGroupUUID"]) {
                [self directUpdateIdentifierValue:@"AppGroupUUID" withValue:newAppGroupUUID];
            }
            
            if ([self.manager isIdentifierEnabled:@"SystemUptime"]) {
                [self directUpdateIdentifierValue:@"SystemUptime" withValue:newSystemUptime];
            }
            
            if ([self.manager isIdentifierEnabled:@"BootTime"]) {
                [self directUpdateIdentifierValue:@"BootTime" withValue:newBootTime];
            }
            
            if ([self.manager isIdentifierEnabled:@"CoreDataUUID"]) {
                [self directUpdateIdentifierValue:@"CoreDataUUID" withValue:newCoreDataUUID];
            }
            
            if ([self.manager isIdentifierEnabled:@"AppInstallUUID"]) {
                [self directUpdateIdentifierValue:@"AppInstallUUID" withValue:newAppInstallUUID];
            }
            
            if ([self.manager isIdentifierEnabled:@"AppContainerUUID"]) {
                [self directUpdateIdentifierValue:@"AppContainerUUID" withValue:newAppContainerUUID];
            }
            
            // Always update the device model
            [self directUpdateIdentifierValue:@"DeviceModel" withValue:newDeviceModel];
            
            if ([self.manager isIdentifierEnabled:@"SystemUptime"]) {
                [self directUpdateIdentifierValue:@"SystemUptime" withValue:newSystemUptime];
            }
            
            // Show success feedback
            UIAlertController *alert = [UIAlertController 
                alertControllerWithTitle:@"Success" 
                message:@"All enabled identifiers have been regenerated" 
                preferredStyle:UIAlertControllerStyleAlert];
            
            [self presentViewController:alert animated:YES completion:^{
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [alert dismissViewControllerAnimated:YES completion:nil];
                });
            }];
        });
    });
}

#pragma mark - UIScrollViewDelegate


- (void)showProfileCreation {
    // Create alert controller
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Create New Profile"
                                                                             message:@"Enter a name and optional description for the new profile."
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    // Add text fields for profile name and description
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Profile Name";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Short Description (optional)";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    
    // Generate a sample profile ID
    NSString *sampleProfileID = [[ProfileManager sharedManager] generateProfileID];
    
    // Set the message to include the profile ID
    alertController.message = [NSString stringWithFormat:@"NEW Profile ID: %@", sampleProfileID];
    
    // Add cancel action
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:cancelAction];
    
    // Add create action
    UIAlertAction *createAction = [UIAlertAction actionWithTitle:@"Create" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *nameField = alertController.textFields.firstObject;
        UITextField *descriptionField = alertController.textFields.lastObject;
        
        NSString *profileName = [nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *profileDescription = [descriptionField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (profileName.length == 0) {
            [self showError:[NSError errorWithDomain:@"WeaponXError" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Profile name cannot be empty"}]];
            return;
        }
        
        // Create profile
        Profile *newProfile = [[Profile alloc] initWithName:profileName 
                                            shortDescription:profileDescription 
                                                iconName:@"default_profile"];
        
        // Show loading indicator
        [self showLoadingIndicator];
        
        // Save profile
        [[ProfileManager sharedManager] createProfile:newProfile completion:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                // Update profiles array
                self.profiles = [[ProfileManager sharedManager].profiles mutableCopy];
                
                // Auto-switch to the newly created profile
                [[ProfileManager sharedManager] switchToProfile:newProfile completion:^(BOOL switchSuccess, NSError * _Nullable switchError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // First update the profile indicator
                        [self updateProfileIndicator];
                        
                        // Then force regenerate all identifiers
                        [self.manager regenerateAllEnabledIdentifiers];
                        
                        // Explicitly generate device model if it's not already set
                        if (![self.manager currentValueForIdentifier:@"DeviceModel"]) {
                            NSString *deviceModel = [self.manager regenerateDeviceProfileGroup];
                            if (!deviceModel) {
                                deviceModel = [self.manager generateDeviceModel];
                                if (deviceModel) {
                                    [self.manager setCustomDeviceModel:deviceModel];
                                }
                            }
                        }
                        
                        // Explicitly generate device theme if it's not already set
                        if (![self.manager currentValueForIdentifier:@"DeviceTheme"] && 
                            [self.manager respondsToSelector:@selector(generateDeviceTheme)]) {
                            NSString *deviceTheme = [self.manager generateDeviceTheme];
                            if (deviceTheme && [self.manager respondsToSelector:@selector(setCustomDeviceTheme:)]) {
                                [self.manager setCustomDeviceTheme:deviceTheme];
                                NSLog(@"[ProjectXViewController] Generated device theme for new profile: %@", deviceTheme);
                            }
                        }
                        
                        // Add a delay to ensure all values are generated and stored
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            // Update UI with new identifiers
                            Class identifierManagerClass = NSClassFromString(@"IdentifierManager");
                            if (identifierManagerClass) {
                                id identifierManager = [identifierManagerClass sharedManager];
                                if ([identifierManager respondsToSelector:@selector(currentValueForIdentifier:)] &&
                                    [identifierManager respondsToSelector:@selector(isIdentifierEnabled:)]) {
                                    // Refresh UI with generated identifiers
                                    [self refreshIdentifierValuesInUI];
                                }
                            }
                            
                            [self hideLoadingIndicator];
                            
                            if (switchSuccess) {
                                // Show success message with the profile ID and mention that the profile is now active
                                NSString *profileID = newProfile.profileId;
                                NSString *successMessage = [NSString stringWithFormat:@"Profile created successfully.\nID: %@\n\nProfile is now active.", profileID];
                                [self showSuccessMessage:successMessage];
                            } else {
                                // Profile created but switch failed
                                NSString *profileID = newProfile.profileId;
                                NSString *successMessage = [NSString stringWithFormat:@"Profile created successfully.\nID: %@\n\nFailed to switch to profile: %@", profileID, switchError.localizedDescription];
                                [self showSuccessMessage:successMessage];
                            }
                        });
                    });
                }];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hideLoadingIndicator];
                    [self showError:error];
                });
            }
        }];
    }];
    [alertController addAction:createAction];
    
    // Present the alert controller
    [self presentViewController:alertController animated:YES completion:nil];
}

// Helper methods for the profile creation popup
- (void)showLoadingIndicator {
    if (!self.loadingIndicator) {
        self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        self.loadingIndicator.center = self.view.center;
        self.loadingIndicator.hidesWhenStopped = YES;
        [self.view addSubview:self.loadingIndicator];
    }
    
    [self.loadingIndicator startAnimating];
}

- (void)hideLoadingIndicator {
    [self.loadingIndicator stopAnimating];
}

- (void)showSuccessMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Success"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showProfileManager {
    // Create profile manager controller with nil profiles since it will load them directly
    ProfileManagerViewController *profileVC = [[ProfileManagerViewController alloc] initWithProfiles:nil];
    profileVC.delegate = (id<ProfileManagerViewControllerDelegate>)self;
    
    // Create navigation controller
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:profileVC];
    
    // Show modal
    [self presentViewController:navController animated:YES completion:nil];
}

#pragma mark - ProfileCreationViewControllerDelegate

- (void)profileCreationViewController:(UIViewController *)controller didCreateProfile:(NSString *)profileName {
    // Update profiles array since the profile was already created by ProfileCreationViewController
    self.profiles = [[ProfileManager sharedManager].profiles mutableCopy];
    
    // Update the profile indicator to reflect the newly created profile
    [self updateProfileIndicator];
    
    // NOTE: We no longer need to send additional notifications here
    // The profile update is already handled by ProfileManager.createProfile
    // These extra notifications were causing duplicate indicators to appear
}

#pragma mark - ProfileManagerViewControllerDelegate

- (void)profileManagerViewController:(UIViewController *)viewController didUpdateProfiles:(NSArray<Profile *> *)profiles {
    self.profiles = [profiles mutableCopy];
    [self updateProfileIndicator];
}

- (void)profileManagerViewController:(UIViewController *)viewController didSelectProfile:(Profile *)profile {
    // Update the local profiles array
    self.profiles = [[ProfileManager sharedManager].profiles mutableCopy];
    
    // Update UI if needed based on the newly selected profile
    // For example, refresh any profile-dependent UI elements
    
    // Update the profile indicator
    [self updateProfileIndicator];
    
    // Explicitly notify floating profile indicator to refresh
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ProfileManagerCurrentProfileChanged" 
                                                        object:nil 
                                                      userInfo:nil];
    
    // Also post a Darwin notification for the floating indicator
    CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterPostNotification(darwinCenter, 
                                         CFSTR("com.hydra.projectx.profileChanged"), 
                                         NULL, 
                                         NULL, 
                                         YES);
}

// Profile Management Methods
- (void)setupProfileButtons {
    // Add profile buttons view
    self.profileButtonsView = [[ProfileButtonsView alloc] initWithFrame:CGRectZero];
    self.profileButtonsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.profileButtonsView];
    
    // Setup profile button actions
    __weak typeof(self) weakSelf = self;
    self.profileButtonsView.onNewProfileTapped = ^{
        [weakSelf showProfileCreation];
    };
    self.profileButtonsView.onManageProfilesTapped = ^{
        [weakSelf showProfileManager];
    };
    
    // Add profile buttons constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.profileButtonsView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:11],
        [self.profileButtonsView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.profileButtonsView.widthAnchor constraintEqualToConstant:60],
        [self.profileButtonsView.heightAnchor constraintEqualToConstant:136] // 2 buttons * 60 + 16 spacing
    ]];
}

- (void)setupProfileManagement {
    // Initialize profiles array
    self.profiles = [[ProfileManager sharedManager].profiles mutableCopy];
}

#pragma mark - Profile Indicator

- (void)setupProfileIndicator {
    // Remove existing indicator if any
    if (self.profileIndicatorView) {
        [self.profileIndicatorView removeFromSuperview];
    }
    
    // Create profile indicator view with no styling
    self.profileIndicatorView = [[UIView alloc] init];
    self.profileIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
    self.profileIndicatorView.backgroundColor = [UIColor clearColor]; // Make completely transparent
    [self.view addSubview:self.profileIndicatorView];
    
    // Position at the left edge of the screen - move further left with negative constant
    [NSLayoutConstraint activateConstraints:@[
        [self.profileIndicatorView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-8],
        [self.profileIndicatorView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.profileIndicatorView.widthAnchor constraintEqualToConstant:30],
        [self.profileIndicatorView.heightAnchor constraintEqualToConstant:260]
    ]];
    
    // Update the profile indicator content
    [self updateProfileIndicator];
}

- (void)updateProfileIndicator {
    if (!self.isViewLoaded) return;
    if (!self.profileIndicatorView || !self.profileIndicatorView.superview) {
        self.profileIndicatorView = [[UIView alloc] init];
        self.profileIndicatorView.translatesAutoresizingMaskIntoConstraints = NO;
        self.profileIndicatorView.backgroundColor = [UIColor clearColor];
        [self.view addSubview:self.profileIndicatorView];
        [NSLayoutConstraint activateConstraints:@[
            [self.profileIndicatorView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:-8],
            [self.profileIndicatorView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
            [self.profileIndicatorView.widthAnchor constraintEqualToConstant:30],
            [self.profileIndicatorView.heightAnchor constraintEqualToConstant:260]
        ]];
    }

    // Clear existing content
    for (UIView *subview in self.profileIndicatorView.subviews) {
        [subview removeFromSuperview];
    }
    
    // Read from central profile info using ProfileManager
    ProfileManager *profileManager = [ProfileManager sharedManager];
    NSString *centralProfileInfoPath = [profileManager centralProfileInfoPath];
    NSDictionary *profileInfo = [NSDictionary dictionaryWithContentsOfFile:centralProfileInfoPath];
    NSString *profileId = profileInfo[@"ProfileId"];
    
    if (!profileId) {
        NSLog(@"[WeaponX] ProjectX: ❌ Failed to read profile ID from current_profile_info.plist");
        return;
    }
    
    NSLog(@"[WeaponX] ProjectX: Using profile ID %@ from central store", profileId);
    
    // Update UI with profile info
    NSString *profileName = profileInfo[@"ProfileName"] ?: [NSString stringWithFormat:@"Profile %@", profileId];
    NSString *iconName = profileInfo[@"IconName"] ?: @"default_profile";
    
    // Update the indicator view
    [self updateIndicatorWithName:profileName iconName:iconName profileId:profileId];
    
    // Also refresh the identifier values in the UI
    [self refreshIdentifierValuesInUI];
}

- (void)updateIndicatorWithName:(NSString *)name iconName:(NSString *)iconName profileId:(NSString *)profileId {
    if (!self.profileIndicatorView) return;

    // Create a single label that combines all elements with the exact format requested
    UILabel *profileIndicatorLabel = [[UILabel alloc] init];
    profileIndicatorLabel.text = [NSString stringWithFormat:@"←------------------ Profile Num: %@ -----------------→", profileId];
    profileIndicatorLabel.textColor = [UIColor systemBlueColor];
    profileIndicatorLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    profileIndicatorLabel.textAlignment = NSTextAlignmentCenter;
    profileIndicatorLabel.numberOfLines = 0;
    
    // Rotate the label to make text vertical, going from bottom to top
    profileIndicatorLabel.transform = CGAffineTransformMakeRotation(-M_PI_2);
    profileIndicatorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.profileIndicatorView addSubview:profileIndicatorLabel];
    
    // Center the rotated label in the indicator view
    [NSLayoutConstraint activateConstraints:@[
        [profileIndicatorLabel.centerXAnchor constraintEqualToAnchor:self.profileIndicatorView.centerXAnchor],
        [profileIndicatorLabel.centerYAnchor constraintEqualToAnchor:self.profileIndicatorView.centerYAnchor],
        [profileIndicatorLabel.widthAnchor constraintEqualToAnchor:self.profileIndicatorView.heightAnchor],
        [profileIndicatorLabel.heightAnchor constraintEqualToAnchor:self.profileIndicatorView.widthAnchor]
    ]];
}

- (void)copyIdentifierValue:(UIButton *)sender {
    // Determine which identifier type this is for
    NSString *identifierType = nil;
    NSUInteger tag = sender.tag;
    
    // Find the identifier type based on the tag
    for (NSString *type in self.identifierSwitches.allKeys) {
        if ([self.identifierSwitches[type] tag] == tag) {
            identifierType = type;
            break;
        }
    }
    
    if (!identifierType) return;
    
    // Get the current value of the identifier
    NSString *value = [self.manager currentValueForIdentifier:identifierType];
    if (value) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        [pasteboard setString:value];
        
        // Show a success message
        UIAlertController *alert = [UIAlertController 
            alertControllerWithTitle:@"Copied!" 
            message:[NSString stringWithFormat:@"%@ copied to clipboard", identifierType]
            preferredStyle:UIAlertControllerStyleAlert];
        
        [self presentViewController:alert animated:YES completion:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [alert dismissViewControllerAnimated:YES completion:nil];
            });
        }];
    }
}

- (void)regenerateIdentifier:(UIButton *)sender {
    // Determine which identifier type this is for
    NSString *identifierType = nil;
    NSUInteger tag = sender.tag;
    
    // Find the identifier type based on the tag
    for (NSString *type in self.identifierSwitches.allKeys) {
        if ([self.identifierSwitches[type] tag] == tag) {
            identifierType = type;
            break;
        }
    }
    
    if (!identifierType) return;
    
    // Check if the identifier is enabled first
    if (![self.manager isIdentifierEnabled:identifierType]) {
        UIAlertController *alert = [UIAlertController 
            alertControllerWithTitle:@"Identifier Disabled" 
            message:[NSString stringWithFormat:@"Enable %@ spoofing first", identifierType]
            preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction 
            actionWithTitle:@"OK" 
            style:UIAlertActionStyleDefault 
            handler:nil]];
        
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // Generate new value based on identifier type
    if ([identifierType isEqualToString:@"IDFA"]) {
        [self.manager generateIDFA];
    } else if ([identifierType isEqualToString:@"IDFV"]) {
        [self.manager generateIDFV];
    } else if ([identifierType isEqualToString:@"DeviceName"]) {
        [self.manager generateDeviceName];
    } else if ([identifierType isEqualToString:@"SerialNumber"]) {
        [self.manager generateSerialNumber];
    } else if ([identifierType isEqualToString:@"IOSVersion"]) {
        [self.manager generateIOSVersion];
    } else if ([identifierType isEqualToString:@"WiFi"]) {
        [self.manager generateWiFiInformation];
    } else if ([identifierType isEqualToString:@"StorageSystem"]) {
        // ... existing StorageSystem code ...
    } else if ([identifierType isEqualToString:@"Battery"]) {
        // ... existing Battery code ...
    } else if ([identifierType isEqualToString:@"SystemBootUUID"]) {
        [self.manager generateSystemBootUUID];
    } else if ([identifierType isEqualToString:@"DyldCacheUUID"]) {
        [self.manager generateDyldCacheUUID];
    } else if ([identifierType isEqualToString:@"PasteboardUUID"]) {
        [self.manager generatePasteboardUUID];
    } else if ([identifierType isEqualToString:@"KeychainUUID"]) {
        [self.manager generateKeychainUUID];
    } else if ([identifierType isEqualToString:@"UserDefaultsUUID"]) {
        [self.manager generateUserDefaultsUUID];
    } else if ([identifierType isEqualToString:@"AppGroupUUID"]) {
        [self.manager generateAppGroupUUID];
    } else if ([identifierType isEqualToString:@"SystemUptime"]) {
        [self.manager generateSystemUptime];
    } else if ([identifierType isEqualToString:@"BootTime"]) {
        [self.manager generateBootTime];
    } else if ([identifierType isEqualToString:@"CoreDataUUID"]) {
        [self.manager generateCoreDataUUID];
    } else if ([identifierType isEqualToString:@"AppInstallUUID"]) {
        [self.manager generateAppInstallUUID];
} else if ([identifierType isEqualToString:@"AppContainerUUID"]) {
        [self.manager generateAppContainerUUID];
    } else {
        return;
    }
    
    // Check for errors
    if ([self.manager lastError]) {
        [self showError:[self.manager lastError]];
        return;
    }
    
    // Refresh UI to show new value
    [self loadSettings];
    
    // Show a success message
    UIAlertController *alert = [UIAlertController 
        alertControllerWithTitle:@"Regenerated" 
        message:[NSString stringWithFormat:@"%@ has been regenerated", identifierType]
        preferredStyle:UIAlertControllerStyleAlert];
    
    [self presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

// New method to refresh identifier values
- (void)refreshIdentifierValuesInUI {
    // Get the IdentifierManager
    Class identifierManagerClass = NSClassFromString(@"IdentifierManager");
    if (!identifierManagerClass) {
        NSLog(@"[WeaponX] ❌ Could not find IdentifierManager class for refresh");
        return;
    }
    
    id identifierManager = [identifierManagerClass sharedManager];
    if (!identifierManager) {
        NSLog(@"[WeaponX] ❌ Could not get IdentifierManager instance for refresh");
        return;
    }
    
    // Log the current profile path for debugging
    if ([identifierManager respondsToSelector:@selector(profileIdentityPath)]) {
        NSString *profilePath = [identifierManager performSelector:@selector(profileIdentityPath)];
        NSLog(@"[WeaponX] 🔍 Current profile path: %@", profilePath);
    }
    
    // Check if identifiers are enabled and get current values
    SEL isEnabledSel = NSSelectorFromString(@"isIdentifierEnabled:");
    SEL currentValueSel = NSSelectorFromString(@"currentValueForIdentifier:");
    
    if ([identifierManager respondsToSelector:isEnabledSel] && [identifierManager respondsToSelector:currentValueSel]) {
        // Helper method to safely perform selector
        BOOL (^performBoolSelector)(id, SEL, id) = ^(id target, SEL selector, id object) {
            NSMethodSignature *signature = [target methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:target];
            [invocation setSelector:selector];
            if (object) {
                [invocation setArgument:&object atIndex:2];
            }
            [invocation invoke];
            BOOL result = NO;
            [invocation getReturnValue:&result];
            return result;
        };
        
        NSString* (^performStringSelector)(id, SEL, id) = ^(id target, SEL selector, id object) {
            NSMethodSignature *signature = [target methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:target];
            [invocation setSelector:selector];
            if (object) {
                [invocation setArgument:&object atIndex:2];
            }
            [invocation invoke];
            __unsafe_unretained NSString *result = nil;
            [invocation getReturnValue:&result];
            return result;
        };
        
        NSArray *identifierTypes = @[@"IDFA", @"IDFV", @"DeviceName", @"SerialNumber", @"IOSVersion", @"WiFi", @"StorageSystem", @"Battery", @"SystemBootUUID", @"DyldCacheUUID", @"PasteboardUUID", @"KeychainUUID", @"UserDefaultsUUID", @"AppGroupUUID", @"CoreDataUUID", @"SystemUptime", @"BootTime", @"AppInstallUUID", @"AppContainerUUID"];
        
        for (NSString *type in identifierTypes) {
            BOOL isEnabled = performBoolSelector(identifierManager, isEnabledSel, type);
            NSLog(@"[WeaponX] 🔍 Checking %@ - Enabled: %@", type, isEnabled ? @"YES" : @"NO");
            
            if (isEnabled) {
                NSString *value = performStringSelector(identifierManager, currentValueSel, type);
                NSLog(@"[WeaponX] 🔍 %@ current value: %@", type, value ?: @"nil");
                
                if (value) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self directUpdateIdentifierValue:type withValue:value];
                    });
                } else {
                    NSLog(@"[WeaponX] ⚠️ No value found for enabled identifier: %@", type);
                }
            }
        }
    } else {
        NSLog(@"[WeaponX] ❌ IdentifierManager missing required methods");
    }
}

- (void)createProfileTapped:(id)sender {
    NSLog(@"[WeaponX] Create profile tapped");
    
    // Create alert controller for profile creation
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Create New Profile"
                                                                             message:@"Enter a name and optional description for the new profile."
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    // Add text fields for name and description
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Profile Name";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleRoundedRect;
    }];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Description (optional)";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleRoundedRect;
    }];
    
    // Add cancel action
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [alertController addAction:cancelAction];
    
    // Add create action
    UIAlertAction *createAction = [UIAlertAction actionWithTitle:@"Create" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *nameField = alertController.textFields.firstObject;
        UITextField *descriptionField = alertController.textFields.lastObject;
        
        NSString *profileName = [nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *profileDescription = [descriptionField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (profileName.length == 0) {
            [self showError:[NSError errorWithDomain:@"WeaponXError" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Profile name cannot be empty"}]];
            return;
        }
        
        // Create profile
        Profile *newProfile = [[Profile alloc] initWithName:profileName 
                                            shortDescription:profileDescription 
                                                iconName:@"default_profile"];
        
        // Show loading indicator
        [self showLoadingIndicator];
        
        // Save profile
        [[ProfileManager sharedManager] createProfile:newProfile completion:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                // Update profiles array
                self.profiles = [[ProfileManager sharedManager].profiles mutableCopy];
                
                // Auto-switch to the newly created profile
                [[ProfileManager sharedManager] switchToProfile:newProfile completion:^(BOOL switchSuccess, NSError * _Nullable switchError) {
                    // Add a small delay to ensure identifier generation completes
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        // Update UI with new identifiers
                        Class identifierManagerClass = NSClassFromString(@"IdentifierManager");
                        if (identifierManagerClass) {
                            id identifierManager = [identifierManagerClass sharedManager];
                            if ([identifierManager respondsToSelector:@selector(currentValueForIdentifier:)] &&
                                [identifierManager respondsToSelector:@selector(isIdentifierEnabled:)]) {
                                // Refresh UI with generated identifiers
                                [self refreshIdentifierValuesInUI];
                                
                                // Also generate Device Theme if missing for the new profile
                                if ([identifierManager respondsToSelector:@selector(currentValueForIdentifier:)] &&
                                    ![identifierManager currentValueForIdentifier:@"DeviceTheme"]) {
                                    if ([identifierManager respondsToSelector:@selector(generateDeviceTheme)]) {
                                        NSString *deviceTheme = [identifierManager generateDeviceTheme];
                                        if (deviceTheme && [identifierManager respondsToSelector:@selector(setCustomDeviceTheme:)]) {
                                            [identifierManager setCustomDeviceTheme:deviceTheme];
                                            NSLog(@"[ProjectXViewController] Generated device theme for new profile: %@", deviceTheme);
                                        }
                                    }
                                }
                            }
                        }
                        
                        [self hideLoadingIndicator];
                        
                        // Update the profile indicator
                        [self updateProfileIndicator];
                        
                        if (switchSuccess) {
                            // Show success message with the profile ID and mention that the profile is now active
                            NSString *profileID = newProfile.profileId;
                            NSString *successMessage = [NSString stringWithFormat:@"Profile created successfully.\nID: %@\n\nProfile is now active.", profileID];
                            [self showSuccessMessage:successMessage];
                        } else {
                            // Profile created but switch failed
                            NSString *profileID = newProfile.profileId;
                            NSString *successMessage = [NSString stringWithFormat:@"Profile created successfully.\nID: %@\n\nFailed to switch to profile: %@", profileID, switchError.localizedDescription];
                            [self showSuccessMessage:successMessage];
                        }
                    });
                }];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hideLoadingIndicator];
                    [self showError:error];
                });
            }
        }];
    }];
    [alertController addAction:createAction];
    
    // Present the alert controller
    [self presentViewController:alertController animated:YES completion:nil];
}

// Replace the identifierDidTap method to handle Battery like other simple identifiers
- (void)identifierDidTap:(UITapGestureRecognizer *)gesture {
    // Get the identifier type from the associated object
    NSString *identifierType = objc_getAssociatedObject(gesture, "identifierType");
    if (!identifierType) {
        return;
    }
    
    // Check if spoofing is enabled for this identifier
    if (![self.manager isIdentifierEnabled:identifierType]) {
        UIAlertController *alert = [UIAlertController 
            alertControllerWithTitle:@"Spoofing Disabled" 
            message:[NSString stringWithFormat:@"Please enable %@ spoofing first.", identifierType]
            preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction 
            actionWithTitle:@"OK" 
            style:UIAlertActionStyleDefault 
            handler:nil]];
        
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // For all identifiers, simply click the generate button
    int tag = 0;
    if ([identifierType isEqualToString:@"IDFA"])
        tag = 1;
    else if ([identifierType isEqualToString:@"IDFV"])
        tag = 2;
    else if ([identifierType isEqualToString:@"DeviceName"])
        tag = 3;
    else if ([identifierType isEqualToString:@"SerialNumber"])
        tag = 4;
    else if ([identifierType isEqualToString:@"IOSVersion"])
        tag = 5;
    else if ([identifierType isEqualToString:@"WiFi"])
        tag = 6;
    else if ([identifierType isEqualToString:@"StorageSystem"])
        tag = 7;
    else if ([identifierType isEqualToString:@"Battery"])
        tag = 8;
    else if ([identifierType isEqualToString:@"SystemBootUUID"])
        tag = 9;
    else if ([identifierType isEqualToString:@"DyldCacheUUID"])
        tag = 10;
    else if ([identifierType isEqualToString:@"PasteboardUUID"])
        tag = 11;
    else if ([identifierType isEqualToString:@"KeychainUUID"])
        tag = 12;
    else if ([identifierType isEqualToString:@"UserDefaultsUUID"])
        tag = 13;
    else if ([identifierType isEqualToString:@"AppGroupUUID"])
        tag = 14;
    else if ([identifierType isEqualToString:@"SystemUptime"])
        tag = 15;
    else if ([identifierType isEqualToString:@"BootTime"])
        tag = 16;
    else if ([identifierType isEqualToString:@"CoreDataUUID"])
        tag = 17;
    else if ([identifierType isEqualToString:@"AppInstallUUID"])
        tag = 18;
else if ([identifierType isEqualToString:@"AppContainerUUID"])
        tag = 19;
    if (tag > 0) {
        [self generateButtonTapped:[self buttonWithTag:tag]];
    }
}

// Remove unused battery configuration methods
// Delete these methods:
// showBatteryConfigurationUI
// setBatteryLevel:lowPowerMode:
// toggleLowPowerMode
// showCustomBatteryInput
// randomizeBattery

// Add helper methods for finding buttons by tag
- (UIButton *)buttonWithTag:(NSInteger)tag {
    for (UIView *view in self.mainStackView.arrangedSubviews) {
        // Find buttons with matching tag
        if ([view isKindOfClass:[UIView class]]) {
            NSArray *buttons = [self findSubviewsOfClass:[UIButton class] inView:view];
            for (UIButton *button in buttons) {
                if (button.tag == tag) {
                    return button;
                }
            }
        }
    }
    return nil;
}

- (NSArray *)findSubviewsOfClass:(Class)cls inView:(UIView *)view {
    NSMutableArray *result = [NSMutableArray array];
    
    if ([view isKindOfClass:cls]) {
        [result addObject:view];
    }
    
    for (UIView *subview in view.subviews) {
        [result addObjectsFromArray:[self findSubviewsOfClass:cls inView:subview]];
    }
    
    return result;
}

// Add this helper method at the end of the @implementation
- (NSInteger)tagForIdentifierType:(NSString *)type {
    if ([type isEqualToString:@"IDFA"]) return 1;
    if ([type isEqualToString:@"IDFV"]) return 2;
    if ([type isEqualToString:@"DeviceName"]) return 3;
    if ([type isEqualToString:@"SerialNumber"]) return 4;
    if ([type isEqualToString:@"IOSVersion"]) return 5;
    if ([type isEqualToString:@"WiFi"]) return 6;
    if ([type isEqualToString:@"StorageSystem"]) return 7;
    if ([type isEqualToString:@"Battery"]) return 8;
    if ([type isEqualToString:@"SystemBootUUID"]) return 9;
    if ([type isEqualToString:@"DyldCacheUUID"]) return 10;
    if ([type isEqualToString:@"PasteboardUUID"]) return 11;
    if ([type isEqualToString:@"KeychainUUID"]) return 12;
    if ([type isEqualToString:@"UserDefaultsUUID"]) return 13;
    if ([type isEqualToString:@"AppGroupUUID"]) return 14;
    if ([type isEqualToString:@"SystemUptime"]) return 15;
    if ([type isEqualToString:@"BootTime"]) return 16;
    if ([type isEqualToString:@"CoreDataUUID"]) return 17;
    if ([type isEqualToString:@"AppInstallUUID"]) return 18;
    if ([type isEqualToString:@"AppContainerUUID"]) return 19;
    return 0;
}

// Add iPad orientation support
- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return UIInterfaceOrientationMaskAll;
    }
    return UIInterfaceOrientationMaskPortrait;
}

- (void)addApplicationWithExtensionsToScope:(NSString *)bundleID {

    if (!bundleID) return;
    
    // Get the app proxy
    LSApplicationProxy *appProxy = [LSApplicationProxy applicationProxyForIdentifier:bundleID];
    if (!appProxy) return;
    
    // Add the app with extensions to scope
    [[IdentifierManager sharedManager] addApplicationWithExtensionsToScope:bundleID];
    
    // Show success message
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Success"
                                                                 message:@"Application and its extensions have been added to scope"
                                                          preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
    // Refresh the app list
    [self loadScopedApps];
}

// Add loadScopedApps method
- (void)loadScopedApps {
    // Get all scoped apps from IdentifierManager
    NSDictionary *appInfo = [self.manager getApplicationInfo:nil];
    NSMutableArray *apps = [NSMutableArray array];
    
    for (NSString *bundleID in appInfo) {
        NSMutableDictionary *app = [NSMutableDictionary dictionaryWithDictionary:appInfo[bundleID]];
        if (!app[@"bundleID"]) {
            app[@"bundleID"] = bundleID;
        }
        [apps addObject:app];
    }
    
    // Sort apps by name
    self.scopedApps = [apps sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *app1, NSDictionary *app2) {
        return [app1[@"name"] compare:app2[@"name"]];
    }];
    
    // Refresh the table view if it exists
    if (self.appsTableView) {
        [self.appsTableView reloadData];
    }
}

// Add the extension button handler method
- (void)extensionButtonTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    if (index < 0 || index >= self.appSwitches.allKeys.count) {
        return;
    }
    
    NSString *bundleID = self.appSwitches.allKeys[index];
    if (!bundleID) return;
    
    // Add the app with extensions
    [self.manager addApplicationWithExtensionsToScope:bundleID];
    
    // Check for errors
    if ([self.manager lastError]) {
        [self showError:[self.manager lastError]];
        return;
    }
    
    // Show success message
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Success"
                                                                 message:@"App extensions have been added to scope"
                                                          preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                            style:UIAlertActionStyleDefault
                                          handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
    
    // Update UI
    [self loadSettings];
}

- (void)titleIconTapped:(UITapGestureRecognizer *)gesture {
    // Get the identifier type from the associated object
    NSString *identifierType = objc_getAssociatedObject(gesture, "identifierType");
    if (!identifierType) {
        return;
    }
    
    // Check if spoofing is enabled for this identifier
    if (![self.manager isIdentifierEnabled:identifierType]) {
        UIAlertController *alert = [UIAlertController 
            alertControllerWithTitle:@"Spoofing Disabled" 
            message:[NSString stringWithFormat:@"Please enable %@ spoofing first.", identifierType]
            preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction 
            actionWithTitle:@"OK" 
            style:UIAlertActionStyleDefault 
            handler:nil]];
        
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // Get current value
    NSString *currentValue = [self.manager currentValueForIdentifier:identifierType];
    
    // Create alert with text field to edit value
    UIAlertController *editAlert = [UIAlertController 
        alertControllerWithTitle:[NSString stringWithFormat:@"Edit %@", identifierType]
        message:@"Enter a new value or leave blank to auto-generate"
        preferredStyle:UIAlertControllerStyleAlert];
    
    [editAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"New Value";
        textField.text = currentValue;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        
        // For UUID types, add validation
        if ([identifierType containsString:@"UUID"]) {
            textField.keyboardType = UIKeyboardTypeDefault;
            textField.autocorrectionType = UITextAutocorrectionTypeNo;
            textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        }
    }];
    
    // Add cancel action
    [editAlert addAction:[UIAlertAction 
        actionWithTitle:@"Cancel" 
        style:UIAlertActionStyleCancel 
        handler:nil]];
    
    // Add save action
    [editAlert addAction:[UIAlertAction 
        actionWithTitle:@"Save" 
        style:UIAlertActionStyleDefault 
        handler:^(UIAlertAction *action) {
            UITextField *textField = editAlert.textFields.firstObject;
            NSString *newValue = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            // If empty, generate a new value
            if (newValue.length == 0) {
                [self generateValueForIdentifier:identifierType];
                return;
            }
            
            // For UUID values, validate format
            if ([identifierType containsString:@"UUID"]) {
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$" 
                                                                            options:NSRegularExpressionCaseInsensitive 
                                                                            error:nil];
                
                NSUInteger matches = [regex numberOfMatchesInString:newValue 
                                                          options:0 
                                                            range:NSMakeRange(0, newValue.length)];
                
                if (matches != 1) {
                    // Invalid UUID format
                    UIAlertController *errorAlert = [UIAlertController 
                        alertControllerWithTitle:@"Invalid Format" 
                        message:@"Please enter a valid UUID in the format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" 
                        preferredStyle:UIAlertControllerStyleAlert];
                    
                    [errorAlert addAction:[UIAlertAction 
                        actionWithTitle:@"OK" 
                        style:UIAlertActionStyleDefault 
                        handler:nil]];
                    
                    [self presentViewController:errorAlert animated:YES completion:nil];
                    return;
                }
            }
            
            // Update value in manager
            [self setCustomValue:newValue forIdentifier:identifierType];
        }]];
    
    [self presentViewController:editAlert animated:YES completion:nil];
}

- (void)setCustomValue:(NSString *)value forIdentifier:(NSString *)type {
    // This implementation depends on how values can be set in your manager
    // We need to forward it to the appropriate manager
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL success = NO;
        
        // Save the custom value depending on identifier type
        if ([type isEqualToString:@"IDFA"]) {
            success = [self.manager setCustomIDFA:value];
        } else if ([type isEqualToString:@"IDFV"]) {
            success = [self.manager setCustomIDFV:value];
        } else if ([type isEqualToString:@"DeviceName"]) {
            success = [self.manager setCustomDeviceName:value];
        } else if ([type isEqualToString:@"SerialNumber"]) {
            success = [self.manager setCustomSerialNumber:value];
        } else if ([type isEqualToString:@"SystemBootUUID"]) {
            success = [self.manager setCustomSystemBootUUID:value];
        } else if ([type isEqualToString:@"DyldCacheUUID"]) {
            success = [self.manager setCustomDyldCacheUUID:value];
        } else if ([type isEqualToString:@"PasteboardUUID"]) {
            success = [self.manager setCustomPasteboardUUID:value];
        } else if ([type isEqualToString:@"KeychainUUID"]) {
            success = [self.manager setCustomKeychainUUID:value];
        } else if ([type isEqualToString:@"UserDefaultsUUID"]) {
            success = [self.manager setCustomUserDefaultsUUID:value];
        } else if ([type isEqualToString:@"AppGroupUUID"]) {
            success = [self.manager setCustomAppGroupUUID:value];
        } else if ([type isEqualToString:@"CoreDataUUID"]) {
            success = [self.manager setCustomCoreDataUUID:value];
        } else if ([type isEqualToString:@"AppInstallUUID"]) {
            success = [self.manager setCustomAppInstallUUID:value];
        } else if ([type isEqualToString:@"AppContainerUUID"]) {
            success = [self.manager setCustomAppContainerUUID:value];
        }
        
        // Update UI
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                // Refresh the value in UI
                NSString *updatedValue = [self.manager currentValueForIdentifier:type];
                [self directUpdateIdentifierValue:type withValue:updatedValue];
                
                // Show success message
                UIAlertController *alert = [UIAlertController 
                    alertControllerWithTitle:@"Value Updated" 
                    message:[NSString stringWithFormat:@"%@ has been updated.", type]
                    preferredStyle:UIAlertControllerStyleAlert];
                
                [self presentViewController:alert animated:YES completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [alert dismissViewControllerAnimated:YES completion:nil];
                    });
                }];
            } else {
                // Show error message
                UIAlertController *alert = [UIAlertController 
                    alertControllerWithTitle:@"Update Failed" 
                    message:[NSString stringWithFormat:@"Failed to update %@. Please try again.", type]
                    preferredStyle:UIAlertControllerStyleAlert];
                
                [alert addAction:[UIAlertAction 
                    actionWithTitle:@"OK" 
                    style:UIAlertActionStyleDefault 
                    handler:nil]];
                
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    });
}

- (void)generateValueForIdentifier:(NSString *)identifierType {
    // Show loading indicator
    [self showLoadingIndicator];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Generate a new value for the specified identifier
        NSString *newValue = nil;
        if ([identifierType isEqualToString:@"IDFA"]) {
            newValue = [self.manager generateIDFA];
        } else if ([identifierType isEqualToString:@"IDFV"]) {
            newValue = [self.manager generateIDFV];
        } else if ([identifierType isEqualToString:@"DeviceName"]) {
            newValue = [self.manager generateDeviceName];
        } else if ([identifierType isEqualToString:@"SerialNumber"]) {
            newValue = [self.manager generateSerialNumber];
        } else if ([identifierType isEqualToString:@"IOSVersion"]) {
            // Generate iOS Version and then get the string representation
            [self.manager generateIOSVersion];
            newValue = [self.manager currentValueForIdentifier:@"IOSVersion"];
        } else if ([identifierType isEqualToString:@"WiFi"]) {
            newValue = [self.manager generateWiFiInformation];
        } else if ([identifierType isEqualToString:@"SystemBootUUID"]) {
            newValue = [self.manager generateSystemBootUUID];
        } else if ([identifierType isEqualToString:@"DyldCacheUUID"]) {
            newValue = [self.manager generateDyldCacheUUID];
        } else if ([identifierType isEqualToString:@"PasteboardUUID"]) {
            newValue = [self.manager generatePasteboardUUID];
        } else if ([identifierType isEqualToString:@"KeychainUUID"]) {
            newValue = [self.manager generateKeychainUUID];
        } else if ([identifierType isEqualToString:@"UserDefaultsUUID"]) {
            newValue = [self.manager generateUserDefaultsUUID];
        } else if ([identifierType isEqualToString:@"AppGroupUUID"]) {
            newValue = [self.manager generateAppGroupUUID];
        } else if ([identifierType isEqualToString:@"CoreDataUUID"]) {
            newValue = [self.manager generateCoreDataUUID];
        } else if ([identifierType isEqualToString:@"AppInstallUUID"]) {
            newValue = [self.manager generateAppInstallUUID];
        } else if ([identifierType isEqualToString:@"AppContainerUUID"]) {
            newValue = [self.manager generateAppContainerUUID];
        } else if ([identifierType isEqualToString:@"StorageSystem"]) {
            // Get StorageManager class
            Class storageManagerClass = NSClassFromString(@"StorageManager");
            if (storageManagerClass && [storageManagerClass respondsToSelector:@selector(sharedManager)]) {
                id storageManager = [storageManagerClass sharedManager];
                if (storageManager) {
                    // Generate a random storage capacity (either 64GB or 128GB)
                    NSString *capacity = [storageManager respondsToSelector:@selector(randomizeStorageCapacity)] ? 
                                       [storageManager randomizeStorageCapacity] : @"64";
                    
                    // Generate the storage information based on the capacity
                    if ([storageManager respondsToSelector:@selector(generateStorageForCapacity:)]) {
                        NSDictionary *storageInfo = [storageManager generateStorageForCapacity:capacity];
                        if (storageInfo) {
                            // Update the StorageManager with the generated values
                            [storageManager setTotalStorageCapacity:storageInfo[@"TotalStorage"]];
                            [storageManager setFreeStorageSpace:storageInfo[@"FreeStorage"]];
                            [storageManager setFilesystemType:storageInfo[@"FilesystemType"]];
                            
                            // Format the value for display
                            newValue = [NSString stringWithFormat:@"Total: %@ GB, Free: %@ GB", 
                                      storageInfo[@"TotalStorage"], 
                                      storageInfo[@"FreeStorage"]];
                        }
                    }
                }
            }
            
            // If we couldn't generate a value, use a fallback
            if (!newValue) {
                BOOL use128GB = (arc4random_uniform(100) < 60);
                newValue = use128GB ? @"Total: 128 GB, Free: 38.4 GB" : @"Total: 64 GB, Free: 19.8 GB";
            }
        } else if ([identifierType isEqualToString:@"Battery"]) {
            // Get BatteryManager class
            Class batteryManagerClass = NSClassFromString(@"BatteryManager");
            if (batteryManagerClass && [batteryManagerClass respondsToSelector:@selector(sharedManager)]) {
                id batteryManager = [batteryManagerClass sharedManager];
                if (batteryManager && [batteryManager respondsToSelector:@selector(generateBatteryInfo)]) {
                    NSDictionary *batteryInfo = [batteryManager generateBatteryInfo];
                    if (batteryInfo) {
                        // Update display value - just show battery percentage now
                        NSString *level = batteryInfo[@"BatteryLevel"];
                        float levelFloat = [level floatValue];
                        int percentage = (int)(levelFloat * 100);
                        
                        newValue = [NSString stringWithFormat:@"%d%%", percentage];
                    }
                }
            }
            
            // If we couldn't generate a value, use a fallback
            if (!newValue) {
                int randomPercentage = 20 + arc4random_uniform(81); // 20-100%
                newValue = [NSString stringWithFormat:@"%d%%", randomPercentage];
            }
        } else if ([identifierType isEqualToString:@"SystemUptime"]) {
            NSString *profilePath = [self.manager profileIdentityPath];
            [[UptimeManager sharedManager] generateUptimeForProfile:profilePath];
            newValue = [self.manager currentValueForIdentifier:@"SystemUptime"];
        } else if ([identifierType isEqualToString:@"BootTime"]) {
            NSString *profilePath = [self.manager profileIdentityPath];
            [[UptimeManager sharedManager] generateBootTimeForProfile:profilePath];
            newValue = [self.manager currentValueForIdentifier:@"BootTime"];
        }
        
        // Update UI
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideLoadingIndicator];
            
            if ([self.manager lastError]) {
                [self showError:[self.manager lastError]];
                return;
            }
            
            // Save settings
            [self.manager saveSettings];
            
            // Update the UI with the new value
            if (newValue) {
                [self directUpdateIdentifierValue:identifierType withValue:newValue];
                
                // Show success message
                UIAlertController *alert = [UIAlertController 
                    alertControllerWithTitle:@"Generated" 
                    message:[NSString stringWithFormat:@"New %@ generated", identifierType]
                    preferredStyle:UIAlertControllerStyleAlert];
                
                [self presentViewController:alert animated:YES completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [alert dismissViewControllerAnimated:YES completion:nil];
                    });
                }];
            } else {
                // Show error message
                UIAlertController *alert = [UIAlertController 
                    alertControllerWithTitle:@"Generation Failed" 
                    message:[NSString stringWithFormat:@"Failed to generate %@. Please try again.", identifierType]
                    preferredStyle:UIAlertControllerStyleAlert];
                
                [alert addAction:[UIAlertAction 
                    actionWithTitle:@"OK" 
                    style:UIAlertActionStyleDefault 
                    handler:nil]];
                
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    });
}

// Add methods for the show advanced button and advanced identifier sections
- (void)addShowAdvancedButton {
    // Create a container for the button with padding
    UIView *buttonContainer = [[UIView alloc] init];
    buttonContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.mainStackView addArrangedSubview:buttonContainer];
    
    // Create the "Show Advanced" button
    self.showAdvancedButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.showAdvancedButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Configure button with modern appearance
    if ([UIButton buttonConfigurationClassExists]) {
        UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
        config.cornerStyle = UIButtonConfigurationCornerStyleMedium;
        config.baseBackgroundColor = [UIColor systemBlueColor];
        config.baseForegroundColor = [UIColor whiteColor];
        config.title = @"Show Advanced Identifiers";
        config.image = [UIImage systemImageNamed:@"chevron.down"];
        config.imagePlacement = NSDirectionalRectEdgeTrailing;
        config.imagePadding = 8;
        config.contentInsets = NSDirectionalEdgeInsetsMake(8, 16, 8, 16);
        [self.showAdvancedButton safeSetConfiguration:config];
    } else {
        // Fallback for older iOS versions - use classic button styling
        [self.showAdvancedButton setTitle:@"Show Advanced Identifiers" forState:UIControlStateNormal];
        self.showAdvancedButton.backgroundColor = [UIColor systemBlueColor];
        [self.showAdvancedButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.showAdvancedButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
        self.showAdvancedButton.layer.cornerRadius = 10;
        self.showAdvancedButton.clipsToBounds = YES;
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        self.showAdvancedButton.contentEdgeInsets = UIEdgeInsetsMake(8, 16, 8, 16);
        #pragma clang diagnostic pop
        
        // Add chevron icon manually for older iOS
        UIImageView *chevronIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down"]];
        chevronIcon.tintColor = [UIColor whiteColor];
        chevronIcon.translatesAutoresizingMaskIntoConstraints = NO;
        [self.showAdvancedButton addSubview:chevronIcon];
        
        [NSLayoutConstraint activateConstraints:@[
            [chevronIcon.trailingAnchor constraintEqualToAnchor:self.showAdvancedButton.trailingAnchor constant:-8],
            [chevronIcon.centerYAnchor constraintEqualToAnchor:self.showAdvancedButton.centerYAnchor],
            [chevronIcon.widthAnchor constraintEqualToConstant:12],
            [chevronIcon.heightAnchor constraintEqualToConstant:12]
        ]];
    }
    
    [self.showAdvancedButton addTarget:self action:@selector(toggleAdvancedIdentifiers:) forControlEvents:UIControlEventTouchUpInside];
    [buttonContainer addSubview:self.showAdvancedButton];
    
    // Center the button in its container
    [NSLayoutConstraint activateConstraints:@[
        [self.showAdvancedButton.centerXAnchor constraintEqualToAnchor:buttonContainer.centerXAnchor],
        [self.showAdvancedButton.topAnchor constraintEqualToAnchor:buttonContainer.topAnchor constant:8],
        [self.showAdvancedButton.bottomAnchor constraintEqualToAnchor:buttonContainer.bottomAnchor constant:-8],
        [self.showAdvancedButton.widthAnchor constraintLessThanOrEqualToAnchor:buttonContainer.widthAnchor constant:-32]
    ]];
    
    // Add some spacing after the button
    [self.mainStackView setCustomSpacing:16 afterView:buttonContainer];
}

// Add a version of addIdentifierSection that adds to our tracking array and hides them initially
- (void)addAdvancedIdentifierSection:(NSString *)type title:(NSString *)title {
    // Get the current count of views in main stack before adding
    NSUInteger beforeCount = self.mainStackView.arrangedSubviews.count;
    
    // Call the original method to create the section (adds title label and container)
    [self addIdentifierSection:type title:title];
    
    // Get both the title label and container view that were just added
    if (self.mainStackView.arrangedSubviews.count >= beforeCount + 2) {
        // The title label is typically added first, then the container
        UIView *titleLabel = self.mainStackView.arrangedSubviews[beforeCount];
        UIView *containerView = self.mainStackView.arrangedSubviews[beforeCount + 1];
        
        // Initially hide both views
        titleLabel.hidden = YES;
        containerView.hidden = YES;
        
        // Add both views to our tracking array
        [self.advancedIdentifierViews addObject:titleLabel];
        [self.advancedIdentifierViews addObject:containerView];
    } else {
        // Fallback in case we couldn't identify both views properly
        // Just hide the last view added (likely the container)
        UIView *lastView = self.mainStackView.arrangedSubviews.lastObject;
        lastView.hidden = YES;
        [self.advancedIdentifierViews addObject:lastView];
    }
}

// Handle toggle of advanced identifiers
- (void)toggleAdvancedIdentifiers:(UIButton *)sender {
    // Toggle the state
    self.showAdvancedIdentifiers = !self.showAdvancedIdentifiers;
    
    // Update button appearance
    if ([UIButton buttonConfigurationClassExists]) {
        UIButtonConfiguration *config = self.showAdvancedButton.configuration;
        if (self.showAdvancedIdentifiers) {
            config.title = @"Hide Advanced Identifiers";
            config.image = [UIImage systemImageNamed:@"chevron.up"];
        } else {
            config.title = @"Show Advanced Identifiers";
            config.image = [UIImage systemImageNamed:@"chevron.down"];
        }
        [self.showAdvancedButton safeSetConfiguration:config];
    } else {
        // Update for older iOS versions
        if (self.showAdvancedIdentifiers) {
            [self.showAdvancedButton setTitle:@"Hide Advanced Identifiers" forState:UIControlStateNormal];
            
            // Update chevron icon
            for (UIView *subview in self.showAdvancedButton.subviews) {
                if ([subview isKindOfClass:[UIImageView class]]) {
                    UIImageView *imageView = (UIImageView *)subview;
                    imageView.image = [UIImage systemImageNamed:@"chevron.up"];
                    break;
                }
            }
        } else {
            [self.showAdvancedButton setTitle:@"Show Advanced Identifiers" forState:UIControlStateNormal];
            
            // Update chevron icon
            for (UIView *subview in self.showAdvancedButton.subviews) {
                if ([subview isKindOfClass:[UIImageView class]]) {
                    UIImageView *imageView = (UIImageView *)subview;
                    imageView.image = [UIImage systemImageNamed:@"chevron.down"];
                    break;
                }
            }
        }
    }
    
    // Toggle visibility of advanced identifiers with animation
    if (self.showAdvancedIdentifiers) {
        // Show the advanced identifier views with a sequential animation
        [UIView animateWithDuration:0.3 animations:^{
            for (NSInteger i = 0; i < self.advancedIdentifierViews.count; i++) {
                UIView *view = self.advancedIdentifierViews[i];
                view.hidden = NO;
                view.alpha = 0;
                
                // Add a slight delay between each view appearing
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [UIView animateWithDuration:0.3 animations:^{
                        view.alpha = 1.0;
                    }];
                });
            }
        }];
        
        // Scroll to show the first advanced identifier
        if (self.advancedIdentifierViews.count > 0) {
            UIView *firstView = self.advancedIdentifierViews.firstObject;
            [self.scrollView scrollRectToVisible:firstView.frame animated:YES];
        }
    } else {
        // Hide the advanced identifier views
        [UIView animateWithDuration:0.2 animations:^{
            for (UIView *view in self.advancedIdentifierViews) {
                view.alpha = 0;
            }
        } completion:^(BOOL finished) {
            for (UIView *view in self.advancedIdentifierViews) {
                view.hidden = YES;
            }
        }];
    }
}

#pragma mark - Dashboard UI

- (NSArray<NSDictionary *> *)pxSupportedFakeModels {
    return @[
        @{ @"name": @"iPhone X", @"id": @"iPhone10,3", @"modelNumber": @"MQA52LL/A" },
        @{ @"name": @"iPhone XR", @"id": @"iPhone11,8", @"modelNumber": @"MRY42LL/A" },
        @{ @"name": @"iPhone XS", @"id": @"iPhone11,2", @"modelNumber": @"MT9E2LL/A" },
        @{ @"name": @"iPhone 11", @"id": @"iPhone12,1", @"modelNumber": @"MWKM2LL/A" },
        @{ @"name": @"iPhone 11 Pro", @"id": @"iPhone12,3", @"modelNumber": @"MWC22LL/A" },
        @{ @"name": @"iPhone 12", @"id": @"iPhone13,2", @"modelNumber": @"MGJ53LL/A" },
        @{ @"name": @"iPhone 12 Pro", @"id": @"iPhone13,3", @"modelNumber": @"MGMK3LL/A" },
        @{ @"name": @"iPhone 13", @"id": @"iPhone14,5", @"modelNumber": @"MLPF3LL/A" },
        @{ @"name": @"iPhone 13 Pro", @"id": @"iPhone14,2", @"modelNumber": @"MLTP3LL/A" },
        @{ @"name": @"iPhone 14", @"id": @"iPhone14,7", @"modelNumber": @"MPVN3LL/A" },
        @{ @"name": @"iPhone 14 Pro", @"id": @"iPhone15,2", @"modelNumber": @"MQ0E3LL/A" },
        @{ @"name": @"iPhone 15", @"id": @"iPhone15,4", @"modelNumber": @"MTP63LL/A" },
        @{ @"name": @"iPhone 15 Pro", @"id": @"iPhone16,1", @"modelNumber": @"MTV13LL/A" },
        @{ @"name": @"iPhone 15 Pro Max", @"id": @"iPhone16,2", @"modelNumber": @"MU693LL/A" }
    ];
}

- (NSArray<NSString *> *)pxSupportedIOSVersions {
    return @[ @"13.0", @"13.7", @"14.0", @"14.8", @"15.0", @"15.7", @"16.0", @"16.3.1" ];
}

- (void)setupDashboardUI {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.selectedResetAppIDs = [[defaults objectForKey:PXDashboardResetAppsKey] mutableCopy] ?: [NSMutableArray array];
    self.selectedRRSAppIDs = [[defaults objectForKey:PXDashboardRRSAppsKey] mutableCopy] ?: [NSMutableArray array];
    self.nextFakeOptions = [defaults objectForKey:PXDashboardFakeOptionsKey] ?: @{};
    self.nextFakePreview = [defaults objectForKey:PXDashboardFakePreviewKey];
    self.rrsRestoreOrder = [defaults stringForKey:PXDashboardRestoreOrderKey] ?: @"oldestFirst";

    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.title = @"Project X";

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];

    self.mainStackView = [[UIStackView alloc] init];
    self.mainStackView.axis = UILayoutConstraintAxisVertical;
    self.mainStackView.spacing = 16;
    self.mainStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.mainStackView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.mainStackView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:18],
        [self.mainStackView.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor constant:18],
        [self.mainStackView.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor constant:-18],
        [self.mainStackView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-24],
        [self.mainStackView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-36]
    ]];

    [self.mainStackView addArrangedSubview:[self dashboardStatusCard]];

    UIStackView *actions = [[UIStackView alloc] init];
    actions.axis = UILayoutConstraintAxisHorizontal;
    actions.spacing = 12;
    actions.distribution = UIStackViewDistributionFillEqually;
    [actions addArrangedSubview:[self dashboardActionCardWithTitle:@"Lưu RRS" subtitle:@"+ Reset Data" color:[UIColor systemBlueColor] icon:@"checkmark.rectangle" selector:@selector(saveRRSThenResetTapped)]];
    [actions addArrangedSubview:[self dashboardActionCardWithTitle:@"Reset Data" subtitle:@"System Clean" color:[UIColor systemRedColor] icon:@"arrow.clockwise" selector:@selector(resetDataTapped)]];
    [self.mainStackView addArrangedSubview:actions];

    [self.mainStackView addArrangedSubview:[self dashboardSectionLabel:@"SELECTION CENTER"]];
    UIView *selectionCard = [self dashboardGroupCard];
    UIStackView *selectionStack = (UIStackView *)[selectionCard viewWithTag:7001];
    UILabel *resetSelectionLabel = nil;
    UILabel *rrsSelectionLabel = nil;
    UILabel *fakeSelectionLabel = nil;
    UILabel *fakeInfoSelectionLabel = nil;
    [selectionStack addArrangedSubview:[self dashboardSelectionRowWithTitle:@"Chọn App RESET!" icon:@"square.grid.2x2.fill" color:[UIColor systemIndigoColor] valueLabel:&resetSelectionLabel selector:@selector(selectResetAppsTapped)]];
    [selectionStack addArrangedSubview:[self dashboardSelectionRowWithTitle:@"Chọn App lưu RRS" icon:@"externaldrive.fill.badge.icloud" color:[UIColor systemPinkColor] valueLabel:&rrsSelectionLabel selector:@selector(selectRRSAppsTapped)]];
    [selectionStack addArrangedSubview:[self dashboardSelectionRowWithTitle:@"Chọn Fake" icon:@"face.smiling.inverse" color:[UIColor systemGrayColor] valueLabel:&fakeSelectionLabel selector:@selector(selectFakeTapped)]];
    [selectionStack addArrangedSubview:[self dashboardSelectionRowWithTitle:@"INFO FAKE" icon:@"info.circle.fill" color:[UIColor systemBlueColor] valueLabel:&fakeInfoSelectionLabel selector:@selector(infoFakeTapped)]];
    self.resetSelectionValueLabel = resetSelectionLabel;
    self.rrsSelectionValueLabel = rrsSelectionLabel;
    self.fakeSelectionValueLabel = fakeSelectionLabel;
    self.fakeInfoSelectionValueLabel = fakeInfoSelectionLabel;
    [self.mainStackView addArrangedSubview:selectionCard];

    [self.mainStackView addArrangedSubview:[self dashboardSectionLabel:@"MANAGEMENT"]];
    UIView *managementCard = [self dashboardGroupCard];
    UIStackView *managementStack = (UIStackView *)[managementCard viewWithTag:7001];
    [managementStack addArrangedSubview:[self dashboardPlainRowWithTitle:@"Quản lý RRS" value:nil selector:@selector(manageRRSTapped)]];
    [managementStack addArrangedSubview:[self dashboardPlainRowWithTitle:@"Restore nhanh" value:@"⚡" selector:@selector(quickRestoreTapped)]];
    [self.mainStackView addArrangedSubview:managementCard];

    self.rrsNoteTextField = [[UITextField alloc] init];
    self.rrsNoteTextField.placeholder = @"Ghi chú khi lưu RRS";
    self.rrsNoteTextField.borderStyle = UITextBorderStyleNone;
    self.rrsNoteTextField.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.rrsNoteTextField.layer.cornerRadius = 10;
    self.rrsNoteTextField.font = [UIFont systemFontOfSize:15];
    self.rrsNoteTextField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];
    self.rrsNoteTextField.leftViewMode = UITextFieldViewModeAlways;
    [self.rrsNoteTextField.heightAnchor constraintEqualToConstant:44].active = YES;
    [self.mainStackView addArrangedSubview:self.rrsNoteTextField];

    [self refreshDashboardSelectionLabels];
}

- (UIView *)dashboardStatusCard {
    UIView *card = [self dashboardRoundedCard];
    UIStackView *row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 10;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:row];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"iphone"]];
    icon.tintColor = [UIColor systemBlueColor];
    [icon.widthAnchor constraintEqualToConstant:28].active = YES;
    [icon.heightAnchor constraintEqualToConstant:28].active = YES;
    [row addArrangedSubview:icon];
    UILabel *label = [[UILabel alloc] init];
    NSString *model = [self.manager currentValueForIdentifier:@"DeviceModel"] ?: @"Unknown";
    NSString *ios = [self.manager currentValueForIdentifier:@"IOSVersion"] ?: @"Unknown";
    label.text = [NSString stringWithFormat:@"DEVICE STATUS\n%@, %@", ios, model];
    label.numberOfLines = 2;
    label.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [row addArrangedSubview:label];
    UILabel *state = [[UILabel alloc] init];
    state.text = @"Connected";
    state.font = [UIFont systemFontOfSize:12];
    [row addArrangedSubview:state];
    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [row.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [row.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
        [row.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14]
    ]];
    return card;
}

- (UIView *)dashboardRoundedCard {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 12;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    return card;
}

- (UIView *)dashboardGroupCard {
    UIView *card = [self dashboardRoundedCard];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.tag = 7001;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor]
    ]];
    return card;
}

- (UILabel *)dashboardSectionLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.textColor = [UIColor secondaryLabelColor];
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    return label;
}

- (UIButton *)dashboardActionCardWithTitle:(NSString *)title subtitle:(NSString *)subtitle color:(UIColor *)color icon:(NSString *)icon selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    BOOL filled = [title containsString:@"Lưu"];
    button.backgroundColor = [color colorWithAlphaComponent:filled ? 1.0 : 0.08];
    button.layer.cornerRadius = 12;
    button.tintColor = filled ? [UIColor whiteColor] : color;
    [button.heightAnchor constraintEqualToConstant:108].active = YES;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    NSString *full = [NSString stringWithFormat:@"%@\n%@", title, subtitle];
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:full attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:15 weight:UIFontWeightBold], NSForegroundColorAttributeName: button.tintColor}];
    [attr addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:11 weight:UIFontWeightRegular] range:[full rangeOfString:subtitle]];
    [button setAttributedTitle:attr forState:UIControlStateNormal];
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) [button setImage:[UIImage systemImageNamed:icon] forState:UIControlStateNormal];
    return button;
}

- (UIView *)dashboardSelectionRowWithTitle:(NSString *)title icon:(NSString *)icon color:(UIColor *)color valueLabel:(UILabel * __strong *)outLabel selector:(SEL)selector {
    UIView *row = [self dashboardPlainRowWithTitle:title value:nil selector:selector];
    UIStackView *stack = (UIStackView *)row.subviews.firstObject;
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:icon]];
    iconView.tintColor = color;
    iconView.backgroundColor = [color colorWithAlphaComponent:0.14];
    iconView.layer.cornerRadius = 6;
    iconView.contentMode = UIViewContentModeCenter;
    [iconView.widthAnchor constraintEqualToConstant:28].active = YES;
    [iconView.heightAnchor constraintEqualToConstant:28].active = YES;
    [stack insertArrangedSubview:iconView atIndex:0];
    UILabel *value = [[UILabel alloc] init];
    value.font = [UIFont systemFontOfSize:13];
    value.textColor = [UIColor secondaryLabelColor];
    [stack insertArrangedSubview:value atIndex:2];
    if (outLabel) *outLabel = value;
    return row;
}

- (UIView *)dashboardPlainRowWithTitle:(NSString *)title value:(NSString *)value selector:(SEL)selector {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [row.heightAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:stack];
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [stack addArrangedSubview:label];
    [label setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    UILabel *right = [[UILabel alloc] init];
    right.text = value ?: @"›";
    right.font = [UIFont systemFontOfSize:18];
    right.textColor = [UIColor tertiaryLabelColor];
    [stack addArrangedSubview:right];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:row.topAnchor constant:8],
        [stack.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:14],
        [stack.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-14],
        [stack.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-8]
    ]];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:selector];
    [row addGestureRecognizer:tap];
    row.userInteractionEnabled = YES;
    return row;
}

- (NSString *)displayNameForBundleID:(NSString *)bundleID {
    NSDictionary *info = [self.manager getApplicationInfo:bundleID];
    return info[@"name"] ?: bundleID;
}

- (NSDateFormatter *)rrsDateFormatter {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.locale = [NSLocale currentLocale];
    fmt.dateFormat = @"dd MMMM yyyy\nHH:mm:ss";
    return fmt;
}

- (NSString *)rrsShortDateString:(NSDate *)date {
    NSDateFormatter *fmt = [self rrsDateFormatter];
    return [fmt stringFromDate:date ?: [NSDate date]];
}

- (NSString *)rrsFallbackNoteForBundleID:(NSString *)bundleID appName:(NSString *)appName date:(NSDate *)date {
    NSString *profileName = [ProfileManager sharedManager].currentProfile.name ?: @"Profile";
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"dd-MM HH:mm";
    return [NSString stringWithFormat:@"%@ + %@ + %@", profileName, appName ?: bundleID ?: @"App", [fmt stringFromDate:date ?: [NSDate date]]];
}

- (void)updateRRSManifestAtBackupDirectory:(NSString *)backupDir bundleID:(NSString *)bundleID appName:(NSString *)appName note:(NSString *)note {
    NSString *manifestPath = [backupDir stringByAppendingPathComponent:@"manifest.plist"];
    NSMutableDictionary *manifest = [NSMutableDictionary dictionaryWithContentsOfFile:manifestPath];
    if (!manifest) return;
    NSDate *now = [NSDate date];
    NSString *trimmed = [note stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    manifest[@"rrsNote"] = trimmed.length ? trimmed : [self rrsFallbackNoteForBundleID:bundleID appName:appName date:now];
    manifest[@"backupIPAddress"] = [NetworkManager getCurrentLocalIPAddress] ?: @"";
    if (!manifest[@"restoreAt"]) manifest[@"restoreAt"] = @"";
    if (!manifest[@"restoreCount"]) manifest[@"restoreCount"] = @0;
    [manifest writeToFile:manifestPath atomically:YES];
}

- (void)markRRSManifestRestoredAtBackupDirectory:(NSString *)backupDir {
    NSString *manifestPath = [backupDir stringByAppendingPathComponent:@"manifest.plist"];
    NSMutableDictionary *manifest = [NSMutableDictionary dictionaryWithContentsOfFile:manifestPath];
    if (!manifest) return;
    manifest[@"restoreAt"] = [NSDate date];
    manifest[@"restoreCount"] = @([manifest[@"restoreCount"] integerValue] + 1);
    [manifest writeToFile:manifestPath atomically:YES];
}

- (void)refreshDashboardSelectionLabels {
    self.resetSelectionValueLabel.text = self.selectedResetAppIDs.count ? [NSString stringWithFormat:@"đã chọn %lu app", (unsigned long)self.selectedResetAppIDs.count] : @"None";
    self.rrsSelectionValueLabel.text = self.selectedRRSAppIDs.count ? [NSString stringWithFormat:@"đã chọn %lu app", (unsigned long)self.selectedRRSAppIDs.count] : @"None";
    NSString *fakeText = @"Options";
    NSString *modelName = self.nextFakePreview[@"DeviceModelName"];
    NSString *model = self.nextFakePreview[@"DeviceModel"];
    if (modelName.length && model.length) fakeText = [NSString stringWithFormat:@"%@ (%@)", modelName, model];
    else if (model.length) fakeText = model;
    self.fakeSelectionValueLabel.text = fakeText;
    NSString *infoText = @"Random";
    if (modelName.length && model.length) infoText = [NSString stringWithFormat:@"%@ (%@)", modelName, model];
    else if (self.nextFakePreview[@"IOSVersion"]) infoText = self.nextFakePreview[@"IOSVersion"];
    self.fakeInfoSelectionValueLabel.text = infoText;
}

- (void)persistDashboardSelections {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.selectedResetAppIDs ?: @[] forKey:PXDashboardResetAppsKey];
    [defaults setObject:self.selectedRRSAppIDs ?: @[] forKey:PXDashboardRRSAppsKey];
    if (self.nextFakeOptions) [defaults setObject:self.nextFakeOptions forKey:PXDashboardFakeOptionsKey];
    if (self.nextFakePreview) [defaults setObject:self.nextFakePreview forKey:PXDashboardFakePreviewKey];
    else [defaults removeObjectForKey:PXDashboardFakePreviewKey];
    [defaults setObject:self.rrsRestoreOrder ?: @"oldestFirst" forKey:PXDashboardRestoreOrderKey];
    [defaults synchronize];
}

- (void)selectResetAppsTapped { [self presentDashboardAppPickerWithMode:@"reset"]; }
- (void)selectRRSAppsTapped { [self presentDashboardAppPickerWithMode:@"rrs"]; }

- (void)randomFakeInfoTapped {
    self.nextFakePreview = [self generateFakePreviewFromOptions:self.nextFakeOptions ?: @{}];
    [self persistDashboardSelections];
    [self refreshDashboardSelectionLabels];
}

- (void)infoFakeTapped {
    PXFakeInfoViewController *vc = [[PXFakeInfoViewController alloc] initWithStyle:PXCompatibleInsetGroupedStyle()];
    vc.preview = self.nextFakePreview ?: @{};
    __weak typeof(self) weakSelf = self;
    vc.onRandom = ^NSDictionary *(void) {
        weakSelf.nextFakePreview = [weakSelf generateFakePreviewFromOptions:weakSelf.nextFakeOptions ?: @{}];
        [weakSelf persistDashboardSelections];
        [weakSelf refreshDashboardSelectionLabels];
        return weakSelf.nextFakePreview ?: @{};
    };
    vc.onClose = ^{
        [weakSelf refreshDashboardSelectionLabels];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)presentDashboardAppPickerWithMode:(NSString *)mode {
    self.selectionPickerMode = mode;
    NSArray *source = [mode isEqualToString:@"reset"] ? self.selectedResetAppIDs : self.selectedRRSAppIDs;
    self.selectionDraftAppIDs = [NSMutableSet setWithArray:source ?: @[]];

    UIViewController *picker = [[UIViewController alloc] init];
    picker.title = [mode isEqualToString:@"reset"] ? @"Chọn App RESET" : @"Chọn App lưu RRS";
    picker.view.backgroundColor = [UIColor systemBackgroundColor];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    picker.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelDashboardAppPicker)];
    picker.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneDashboardAppPicker)];

    self.appSearchBar = [[UISearchBar alloc] init];
    self.appSearchBar.delegate = self;
    self.appSearchBar.translatesAutoresizingMaskIntoConstraints = NO;
    [picker.view addSubview:self.appSearchBar];
    self.installedAppsTableView = [[UITableView alloc] initWithFrame:CGRectZero style:PXCompatibleInsetGroupedStyle()];
    self.installedAppsTableView.delegate = self;
    self.installedAppsTableView.dataSource = self;
    self.installedAppsTableView.translatesAutoresizingMaskIntoConstraints = NO;
    [picker.view addSubview:self.installedAppsTableView];
    [NSLayoutConstraint activateConstraints:@[
        [self.appSearchBar.topAnchor constraintEqualToAnchor:picker.view.safeAreaLayoutGuide.topAnchor],
        [self.appSearchBar.leadingAnchor constraintEqualToAnchor:picker.view.leadingAnchor],
        [self.appSearchBar.trailingAnchor constraintEqualToAnchor:picker.view.trailingAnchor],
        [self.installedAppsTableView.topAnchor constraintEqualToAnchor:self.appSearchBar.bottomAnchor],
        [self.installedAppsTableView.leadingAnchor constraintEqualToAnchor:picker.view.leadingAnchor],
        [self.installedAppsTableView.trailingAnchor constraintEqualToAnchor:picker.view.trailingAnchor],
        [self.installedAppsTableView.bottomAnchor constraintEqualToAnchor:picker.view.bottomAnchor]
    ]];
    [self loadInstalledApps];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)cancelDashboardAppPicker {
    self.selectionPickerMode = nil;
    self.selectionDraftAppIDs = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)doneDashboardAppPicker {
    NSArray *selected = [[self.selectionDraftAppIDs allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    if ([self.selectionPickerMode isEqualToString:@"reset"]) self.selectedResetAppIDs = [selected mutableCopy];
    else if ([self.selectionPickerMode isEqualToString:@"rrs"]) self.selectedRRSAppIDs = [selected mutableCopy];
    self.selectionPickerMode = nil;
    self.selectionDraftAppIDs = nil;
    [self persistDashboardSelections];
    [self refreshDashboardSelectionLabels];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)selectFakeTapped {
    __weak typeof(self) weakSelf = self;
    PXFakeSelectionViewController *vc = [[PXFakeSelectionViewController alloc] initWithStyle:PXCompatibleInsetGroupedStyle()];
    vc.options = self.nextFakeOptions ?: @{};
    vc.preview = self.nextFakePreview ?: @{};
    vc.onDone = ^(NSDictionary *options, NSDictionary *preview) {
        weakSelf.nextFakeOptions = options ?: @{};
        weakSelf.nextFakePreview = nil;
        [weakSelf persistDashboardSelections];
        [weakSelf refreshDashboardSelectionLabels];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (NSDictionary *)generateFakePreviewFromOptions:(NSDictionary *)options {
    BOOL fakeIOS = options[@"fakeIOSVersionEnabled"] ? [options[@"fakeIOSVersionEnabled"] boolValue] : YES;
    BOOL fakeModel = options[@"fakeModelEnabled"] ? [options[@"fakeModelEnabled"] boolValue] : YES;
    BOOL fakeName = options[@"fakeNameEnabled"] ? [options[@"fakeNameEnabled"] boolValue] : NO;
    NSArray *models = [self pxSupportedFakeModels];
    NSInteger minIdx = [options[@"modelMinIndex"] integerValue];
    NSInteger maxIdx = [options[@"modelMaxIndex"] integerValue];
    if (minIdx <= 0) minIdx = 1;
    if (maxIdx <= 0 || maxIdx > (NSInteger)models.count) maxIdx = (NSInteger)models.count;
    if (minIdx > maxIdx) { NSInteger t = minIdx; minIdx = maxIdx; maxIdx = t; }
    NSInteger picked = minIdx - 1 + arc4random_uniform((uint32_t)(maxIdx - minIdx + 1));
    NSDictionary *model = models[(NSUInteger)picked];
    NSArray *allIOSVersions = [self pxSupportedIOSVersions];
    NSMutableArray *iosVersions = [NSMutableArray array];
    NSString *iosMin = options[@"iosMin"];
    NSString *iosMax = options[@"iosMax"];
    for (NSString *version in allIOSVersions) {
        BOOL aboveMin = !iosMin.length || [version compare:iosMin options:NSNumericSearch] != NSOrderedAscending;
        BOOL belowMax = !iosMax.length || [version compare:iosMax options:NSNumericSearch] != NSOrderedDescending;
        if (aboveMin && belowMax) [iosVersions addObject:version];
    }
    if (!iosVersions.count) [iosVersions addObjectsFromArray:allIOSVersions];
    NSArray *countries = @[
        @{ @"name": @"United States", @"code": @"us" },
        @{ @"name": @"Việt Nam", @"code": @"vn" },
        @{ @"name": @"Canada", @"code": @"ca" },
        @{ @"name": @"India", @"code": @"in" }
    ];
    NSDictionary *country = countries[arc4random_uniform((uint32_t)countries.count)];
    NSArray *carriers = [self pxCarriersForCountry:country[@"code"]];
    NSDictionary *carrier = carriers.count ? carriers[arc4random_uniform((uint32_t)carriers.count)] : @{};
    NSMutableDictionary *preview = [NSMutableDictionary dictionary];
    if (fakeName) preview[@"DeviceName"] = [self pxRandomDeviceName];
    if (fakeModel) {
        preview[@"DeviceModel"] = model[@"id"] ?: @"";
        preview[@"DeviceModelName"] = model[@"name"] ?: @"";
        preview[@"ModelNumber"] = model[@"modelNumber"] ?: @"";
    }
    if (fakeIOS) preview[@"IOSVersion"] = iosVersions[arc4random_uniform((uint32_t)iosVersions.count)] ?: @"";
    preview[@"CountryName"] = country[@"name"] ?: @"";
    preview[@"CountryCode"] = country[@"code"] ?: @"";
    preview[@"CarrierName"] = carrier[@"name"] ?: @"";
    preview[@"CarrierMCC"] = carrier[@"mcc"] ?: @"";
    preview[@"CarrierMNC"] = carrier[@"mnc"] ?: @"";
    preview[@"SerialNumber"] = [self pxRandomSerial];
    preview[@"MACAddress"] = [self pxRandomMAC];
    return preview;
}

- (NSArray *)pxCarriersForCountry:(NSString *)code {
    if ([code isEqualToString:@"vn"]) {
        return @[
            @{ @"name": @"Viettel", @"mcc": @"452", @"mnc": @"04" },
            @{ @"name": @"VinaPhone", @"mcc": @"452", @"mnc": @"02" },
            @{ @"name": @"MobiFone", @"mcc": @"452", @"mnc": @"01" },
            @{ @"name": @"Vietnamobile", @"mcc": @"452", @"mnc": @"05" }
        ];
    }
    return [NetworkManager getCarriersForCountry:code ?: @"us"];
}

- (NSString *)pxRandomDeviceName {
    NSArray *names = @[ @"Stitch", @"Alex", @"Minh", @"Henry", @"Emma", @"Liam" ];
    return [NSString stringWithFormat:@"iPhone của %@", names[arc4random_uniform((uint32_t)names.count)]];
}

- (NSString *)pxRandomSerial {
    NSArray *prefixes = @[ @"C02", @"FVF", @"DLXJ", @"GG78", @"HC79" ];
    NSString *chars = @"23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
    NSMutableString *serial = [prefixes[arc4random_uniform((uint32_t)prefixes.count)] mutableCopy];
    for (int i = 0; i < 8; i++) [serial appendFormat:@"%C", [chars characterAtIndex:arc4random_uniform((uint32_t)chars.length)]];
    return serial;
}

- (NSString *)pxRandomMAC {
    return [NSString stringWithFormat:@"02:%02X:%02X:%02X:%02X:%02X", arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256)];
}

- (void)applyFakePreviewToCurrentProfile:(NSDictionary *)preview {
    if (!preview.count) return;
    NSString *model = preview[@"DeviceModel"];
    if (model.length) [self.manager setCustomDeviceModel:model];
    NSString *deviceName = preview[@"DeviceName"];
    if (deviceName.length) [self.manager setCustomDeviceName:deviceName];
    NSString *serial = preview[@"SerialNumber"];
    if (serial.length) [self.manager setCustomSerialNumber:serial];

    NSString *identityDir = [self.manager profileIdentityPath];
    if (!identityDir.length) return;
    NSString *deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];
    NSMutableDictionary *deviceIds = [NSMutableDictionary dictionaryWithContentsOfFile:deviceIdsPath] ?: [NSMutableDictionary dictionary];
    NSArray *keys = @[ @"DeviceName", @"DeviceModel", @"DeviceModelName", @"IOSVersion", @"IOSBuild", @"CountryCode", @"CountryName", @"CarrierName", @"CarrierMCC", @"CarrierMNC", @"ModelNumber", @"SerialNumber", @"MACAddress" ];
    for (NSString *key in keys) {
        NSString *value = preview[key];
        if ([value isKindOfClass:[NSString class]] && value.length) deviceIds[key] = value;
    }
    NSString *mac = preview[@"MACAddress"];
    if (mac.length) deviceIds[@"WiFiAddress"] = mac;
    [deviceIds writeToFile:deviceIdsPath atomically:YES];
}

- (void)saveRRSThenResetTapped {
    if (!self.selectedRRSAppIDs.count) { [self showDashboardMessage:@"Thiếu app lưu RRS" message:@"Hãy chọn ít nhất một app trong Chọn App lưu RRS."]; return; }
    [self showProgressHUDWithTitle:@"Lưu RRS..."];
    [self backupApps:self.selectedRRSAppIDs index:0 warnings:[NSMutableArray array] completion:^(NSArray<NSString *> *warnings) {
        [self performResetAndPrepareNextProfileWithWarnings:warnings];
    }];
}

- (void)resetDataTapped {
    [self showProgressHUDWithTitle:@"Reset Data..."];
    [self performResetAndPrepareNextProfileWithWarnings:@[]];
}

- (void)performResetAndPrepareNextProfileWithWarnings:(NSArray<NSString *> *)warnings {
    if (!self.selectedResetAppIDs.count) {
        [self hideProgressHUD];
        [self showDashboardMessage:@"Thiếu app reset" message:@"Hãy chọn ít nhất một app trong Chọn App RESET!."];
        return;
    }
    [self clearApps:self.selectedResetAppIDs index:0 warnings:[warnings mutableCopy] completion:^(NSArray<NSString *> *allWarnings) {
        [self createNextProfileAndRandomizeWithWarnings:allWarnings];
    }];
}

- (void)backupApps:(NSArray<NSString *> *)apps index:(NSUInteger)index warnings:(NSMutableArray<NSString *> *)warnings completion:(void (^)(NSArray<NSString *> *warnings))completion {
    if (index >= apps.count) { completion(warnings); return; }
    NSString *bundleID = apps[index];
    NSString *name = [self displayNameForBundleID:bundleID];
    [self updateProgress:(float)index / MAX((float)apps.count, 1.0) detail:[NSString stringWithFormat:@"Backup %@", name]];
    PXBackupOptions options = PXBackupOptionIncludeAppGroups | PXBackupOptionIncludePreferences;
    [[AppDataBackupManager shared] createBackupForBundleID:bundleID appName:name options:options completion:^(PXBackupResult *result, NSError *error) {
        if (error) [warnings addObject:[NSString stringWithFormat:@"Backup %@: %@", name, error.localizedDescription ?: @"failed"]];
        if (result.backupDirectory.length) [self updateRRSManifestAtBackupDirectory:result.backupDirectory bundleID:bundleID appName:name note:self.rrsNoteTextField.text ?: @""];
        if (result.warnings.count) [warnings addObjectsFromArray:result.warnings];
        [self backupApps:apps index:index + 1 warnings:warnings completion:completion];
    }];
}

- (void)clearApps:(NSArray<NSString *> *)apps index:(NSUInteger)index warnings:(NSMutableArray<NSString *> *)warnings completion:(void (^)(NSArray<NSString *> *warnings))completion {
    if (index >= apps.count) { completion(warnings); return; }
    NSString *bundleID = apps[index];
    NSString *name = [self displayNameForBundleID:bundleID];
    [self updateProgress:(float)index / MAX((float)apps.count, 1.0) detail:[NSString stringWithFormat:@"Clear %@", name]];
    [[AppDataCleaner sharedManager] clearDataForBundleID:bundleID completion:^(BOOL success, NSError *error) {
        if (!success) [warnings addObject:[NSString stringWithFormat:@"Clear %@: %@", name, error.localizedDescription ?: @"failed"]];
        [self clearApps:apps index:index + 1 warnings:warnings completion:completion];
    }];
}

- (void)createNextProfileAndRandomizeWithWarnings:(NSArray<NSString *> *)warnings {
    ProfileManager *pm = [ProfileManager sharedManager];
    NSString *profileName = [NSString stringWithFormat:@"Auto %@", [pm generateProfileID]];
    Profile *newProfile = [[Profile alloc] initWithName:profileName shortDescription:@"Auto-created after Reset Data" iconName:@"person.crop.circle.badge.plus"];
    [pm createProfile:newProfile completion:^(BOOL success, NSError *error) {
        if (!success) {
            [self hideProgressHUD];
            [self showError:error];
            return;
        }
        [pm switchToProfile:newProfile completion:^(BOOL switchSuccess, NSError *switchError) {
            if (!switchSuccess) {
                [self hideProgressHUD];
                [self showError:switchError];
                return;
            }
            [self.manager regenerateAllEnabledIdentifiers];
            NSDictionary *preview = self.nextFakePreview ?: [self generateFakePreviewFromOptions:self.nextFakeOptions ?: @{}];
            [self applyFakePreviewToCurrentProfile:preview];
            self.nextFakePreview = nil;
            [self persistDashboardSelections];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD];
                [self refreshDashboardSelectionLabels];
                NSString *msg = [NSString stringWithFormat:@"Đã tạo profile mới: %@.%@", newProfile.profileId, warnings.count ? [NSString stringWithFormat:@"\n\nWarnings:\n%@", [warnings componentsJoinedByString:@"\n"]] : @""];
                [self showDashboardMessage:@"Hoàn tất" message:msg];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self killEnabledAppsAndRespring];
                });
            });
        }];
    }];
}

- (NSString *)currentProfileRestoreIndexKey {
    NSString *pid = [ProfileManager sharedManager].currentProfile.profileId ?: @"default";
    return [PXDashboardRestoreIndexKeyPrefix stringByAppendingString:pid];
}

- (NSString *)currentProfileRestoreEndKey {
    NSString *pid = [ProfileManager sharedManager].currentProfile.profileId ?: @"default";
    return [PXDashboardRestoreEndKeyPrefix stringByAppendingString:pid];
}

- (NSString *)rrsFormattedSize:(NSNumber *)bytes {
    double value = bytes.doubleValue;
    if (value < 1024.0) return [NSString stringWithFormat:@"%.0f B", value];
    value /= 1024.0;
    if (value < 1024.0) return [NSString stringWithFormat:@"%.0f KB", value];
    value /= 1024.0;
    return [NSString stringWithFormat:@"%.1f MB", value];
}

- (NSArray<NSString *> *)allRRSBackupDirectories {
    NSMutableArray<NSString *> *dirs = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray<NSString *> *roots = [NSMutableArray array];
    NSString *profilesRoot = PXProfilesPath();
    NSArray *profiles = [fm contentsOfDirectoryAtPath:profilesRoot error:nil];
    for (NSString *profile in profiles) {
        NSString *root = [[profilesRoot stringByAppendingPathComponent:profile] stringByAppendingPathComponent:@"backups"];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:root isDirectory:&isDir] && isDir) [roots addObject:root];
    }
    NSString *legacyRoot = [PXWeaponXBasePath() stringByAppendingPathComponent:@"Backups"];
    BOOL legacyIsDir = NO;
    if ([fm fileExistsAtPath:legacyRoot isDirectory:&legacyIsDir] && legacyIsDir) [roots addObject:legacyRoot];

    for (NSString *root in roots) {
        NSArray *bundleDirs = [fm contentsOfDirectoryAtPath:root error:nil];
        for (NSString *bundle in bundleDirs) {
            NSString *bundlePath = [root stringByAppendingPathComponent:bundle];
            BOOL bundleIsDir = NO;
            if (![fm fileExistsAtPath:bundlePath isDirectory:&bundleIsDir] || !bundleIsDir) continue;
            NSArray *items = [fm contentsOfDirectoryAtPath:bundlePath error:nil];
            for (NSString *item in items) {
                NSString *dir = [bundlePath stringByAppendingPathComponent:item];
                BOOL itemIsDir = NO;
                if ([fm fileExistsAtPath:dir isDirectory:&itemIsDir] && itemIsDir && [fm fileExistsAtPath:[dir stringByAppendingPathComponent:@"manifest.plist"]]) {
                    [dirs addObject:dir];
                }
            }
        }
    }
    [dirs sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        if ([self.rrsRestoreOrder isEqualToString:@"newestFirst"]) return [b.lastPathComponent compare:a.lastPathComponent];
        return [a.lastPathComponent compare:b.lastPathComponent];
    }];
    return dirs;
}

- (NSArray<NSDictionary *> *)rrsEntries {
    NSMutableArray *entries = [NSMutableArray array];
    for (NSString *dir in [self allRRSBackupDirectories]) {
            NSError *err = nil;
            NSDictionary *m = [[AppDataBackupManager shared] readManifestAtBackupDirectory:dir error:&err];
            if (!m) continue;
            NSString *bundleID = m[@"bundleID"] ?: dir.stringByDeletingLastPathComponent.lastPathComponent;
            NSDate *created = [m[@"createdAt"] isKindOfClass:[NSDate class]] ? m[@"createdAt"] : nil;
            id restored = m[@"restoreAt"];
            NSString *restoreText = @"(null)";
            if ([restored isKindOfClass:[NSDate class]]) restoreText = [self rrsShortDateString:restored];
            else if ([restored isKindOfClass:[NSString class]] && [restored length]) restoreText = restored;
            NSString *checksum = m[@"archiveChecksum"] ?: @"";
            if (checksum.length > 24) checksum = [checksum substringToIndex:24];
            [entries addObject:@{
                @"dir": dir,
                @"bundleID": m[@"bundleID"] ?: bundleID,
                @"appName": m[@"appName"] ?: [self displayNameForBundleID:bundleID],
                @"note": m[@"rrsNote"] ?: [self rrsFallbackNoteForBundleID:bundleID appName:m[@"appName"] date:created],
                @"checksum": checksum,
                @"ip": m[@"backupIPAddress"] ?: @"",
                @"size": [self rrsFormattedSize:m[@"totalSize"] ?: @0],
                @"backupDate": [self rrsShortDateString:created],
                @"restoreDate": restoreText
            }];
    }
    return entries;
}

- (NSArray<NSString *> *)orderedBackupsForQuickRestoreBundleID:(NSString **)outBundleID appName:(NSString **)outAppName {
    NSString *bundleID = self.selectedRRSAppIDs.firstObject ?: self.selectedResetAppIDs.firstObject;
    if (!bundleID.length) return @[];
    if (outBundleID) *outBundleID = bundleID;
    if (outAppName) *outAppName = [self displayNameForBundleID:bundleID];
    NSArray *backups = [[AppDataBackupManager shared] listBackupDirectoriesForBundleID:bundleID];
    if ([self.rrsRestoreOrder isEqualToString:@"newestFirst"]) return backups;
    return [[backups reverseObjectEnumerator] allObjects];
}

- (void)quickRestoreTapped {
    NSArray<NSString *> *apps = self.selectedRRSAppIDs.count ? self.selectedRRSAppIDs : self.selectedResetAppIDs;
    if (!apps.count) { [self showDashboardMessage:@"Thiếu app" message:@"Hãy chọn app trong Chọn App lưu RRS trước khi Restore nhanh."]; return; }
    NSInteger idx = [[NSUserDefaults standardUserDefaults] integerForKey:[self currentProfileRestoreIndexKey]];
    NSInteger end = [[NSUserDefaults standardUserDefaults] integerForKey:[self currentProfileRestoreEndKey]];

    NSMutableDictionary<NSString *, NSArray<NSString *> *> *backupMap = [NSMutableDictionary dictionary];
    for (NSString *bundleID in apps) {
        NSArray *backups = [[AppDataBackupManager shared] listBackupDirectoriesForBundleID:bundleID];
        if (![self.rrsRestoreOrder isEqualToString:@"newestFirst"]) {
            backups = [[backups reverseObjectEnumerator] allObjects];
        }
        if (end > 0 && idx >= end) {
            [self showDashboardMessage:@"Đã hết backup" message:[NSString stringWithFormat:@"Đã restore hết đến vị trí %ld.", (long)end]];
            return;
        }
        if (idx >= (NSInteger)backups.count) {
            [self showDashboardMessage:@"Đã hết backup" message:[NSString stringWithFormat:@"%@ không còn backup ở vị trí %ld.", [self displayNameForBundleID:bundleID], (long)idx + 1]];
            return;
        }
        backupMap[bundleID] = backups;
    }

    [self showProgressHUDWithTitle:@"Restore nhanh..."];
    [self restoreQuickApps:apps backupMap:backupMap index:0 restoreIndex:idx warnings:[NSMutableArray array] completion:^(NSArray<NSString *> *warnings) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideProgressHUD];
            [[NSUserDefaults standardUserDefaults] setInteger:idx + 1 forKey:[self currentProfileRestoreIndexKey]];
            [[NSUserDefaults standardUserDefaults] synchronize];
            NSString *msg = [NSString stringWithFormat:@"Đã restore lượt %ld cho %lu app.%@", (long)idx + 1, (unsigned long)apps.count, warnings.count ? [NSString stringWithFormat:@"\n\nWarnings:\n%@", [warnings componentsJoinedByString:@"\n"]] : @""];
            [self showDashboardMessage:@"Restore xong" message:msg];
        });
    }];
}

- (void)restoreQuickApps:(NSArray<NSString *> *)apps
               backupMap:(NSDictionary<NSString *, NSArray<NSString *> *> *)backupMap
                   index:(NSUInteger)index
            restoreIndex:(NSInteger)restoreIndex
                warnings:(NSMutableArray<NSString *> *)warnings
              completion:(void (^)(NSArray<NSString *> *warnings))completion {
    if (index >= apps.count) { completion(warnings); return; }
    NSString *bundleID = apps[index];
    NSString *appName = [self displayNameForBundleID:bundleID];
    NSArray *backups = backupMap[bundleID];
    NSString *dir = backups[(NSUInteger)restoreIndex];
    NSDictionary *manifest = [[AppDataBackupManager shared] readManifestAtBackupDirectory:dir error:nil];
    NSString *manifestBundleID = manifest[@"bundleID"] ?: bundleID;
    NSString *manifestAppName = manifest[@"appName"] ?: appName;
    [self updateProgress:(float)index / MAX((float)apps.count, 1.0) detail:[NSString stringWithFormat:@"Clear %@", manifestAppName]];
    [[AppDataCleaner sharedManager] clearDataForBundleID:manifestBundleID completion:^(BOOL clearSuccess, NSError *clearError) {
        if (!clearSuccess) [warnings addObject:[NSString stringWithFormat:@"Clear %@: %@", manifestAppName, clearError.localizedDescription ?: @"failed"]];
        [self updateProgress:(float)index / MAX((float)apps.count, 1.0) detail:[NSString stringWithFormat:@"Restore %@", manifestAppName]];
        [[AppDataBackupManager shared] restoreBackupAtDirectory:dir bundleID:manifestBundleID appName:manifestAppName completion:^(PXRestoreResult *result, NSError *error) {
            if (error) [warnings addObject:[NSString stringWithFormat:@"Restore %@: %@", manifestAppName, error.localizedDescription ?: @"failed"]];
            if (result.warnings.count) [warnings addObjectsFromArray:result.warnings];
            [self markRRSManifestRestoredAtBackupDirectory:dir];
            [self restoreQuickApps:apps backupMap:backupMap index:index + 1 restoreIndex:restoreIndex warnings:warnings completion:completion];
        }];
    }];
}

- (void)manageRRSTapped {
    PXRRSManagerViewController *vc = [[PXRRSManagerViewController alloc] initWithStyle:PXCompatibleInsetGroupedStyle()];
    vc.entries = [self rrsEntries];
    vc.nextIndex = [[NSUserDefaults standardUserDefaults] integerForKey:[self currentProfileRestoreIndexKey]];
    vc.sequenceMode = [self.rrsRestoreOrder isEqualToString:@"newestFirst"] ? 1 : 0;
    __weak typeof(self) weakSelf = self;
    vc.onReload = ^NSArray<NSDictionary *> *{ return [weakSelf rrsEntries]; };
    vc.onDelete = ^(NSArray<NSString *> *dirs) {
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *dir in dirs) [fm removeItemAtPath:dir error:nil];
    };
    vc.onSaveAndRestore = ^(NSString *backupDir) {
        if (!backupDir.length) { [weakSelf showDashboardMessage:@"Thiếu RRS" message:@"Không tìm thấy file RRS để restore."]; return; }
        [weakSelf saveCurrentRRSThenRestoreBackupDirectory:backupDir];
    };
    vc.onNextChanged = ^(NSInteger nextIndex) {
        [[NSUserDefaults standardUserDefaults] setInteger:nextIndex forKey:[weakSelf currentProfileRestoreIndexKey]];
        [[NSUserDefaults standardUserDefaults] synchronize];
    };
    vc.onSequenceChanged = ^(NSInteger mode, NSInteger begin, NSInteger end) {
        weakSelf.rrsRestoreOrder = mode == 1 ? @"newestFirst" : @"oldestFirst";
        if (mode == 0 || mode == 1) [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:[weakSelf currentProfileRestoreIndexKey]];
        if (mode == 2 && begin > 0) [[NSUserDefaults standardUserDefaults] setInteger:begin - 1 forKey:[weakSelf currentProfileRestoreIndexKey]];
        if (end > 0) [[NSUserDefaults standardUserDefaults] setInteger:end forKey:[weakSelf currentProfileRestoreEndKey]];
        else [[NSUserDefaults standardUserDefaults] removeObjectForKey:[weakSelf currentProfileRestoreEndKey]];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [weakSelf persistDashboardSelections];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)saveCurrentRRSThenRestoreBackupDirectory:(NSString *)backupDir {
    NSArray *apps = self.selectedRRSAppIDs.count ? self.selectedRRSAppIDs : self.selectedResetAppIDs;
    if (!apps.count) { [self showDashboardMessage:@"Thiếu app" message:@"Hãy chọn app lưu RRS hoặc app reset trước."]; return; }
    [self showProgressHUDWithTitle:@"Lưu RRS..."];
    [self backupApps:apps index:0 warnings:[NSMutableArray array] completion:^(NSArray<NSString *> *warnings) {
        [self restoreBackupDirectoryAfterClearingManifestApp:backupDir warnings:[warnings mutableCopy]];
    }];
}

- (void)restoreBackupDirectoryAfterClearingManifestApp:(NSString *)backupDir warnings:(NSMutableArray<NSString *> *)warnings {
    NSError *manifestError = nil;
    NSDictionary *manifest = [[AppDataBackupManager shared] readManifestAtBackupDirectory:backupDir error:&manifestError];
    NSString *bundleID = manifest[@"bundleID"];
    NSString *appName = manifest[@"appName"] ?: [self displayNameForBundleID:bundleID];
    if (!bundleID.length) {
        [self hideProgressHUD];
        [self showDashboardMessage:@"RRS lỗi" message:@"Không đọc được app trong manifest backup."];
        return;
    }
    [self updateProgress:0.4 detail:[NSString stringWithFormat:@"Clear %@", appName]];
    [[AppDataCleaner sharedManager] clearDataForBundleID:bundleID completion:^(BOOL success, NSError *error) {
        if (!success) [warnings addObject:[NSString stringWithFormat:@"Clear %@: %@", appName, error.localizedDescription ?: @"failed"]];
        [self updateProgress:0.7 detail:[NSString stringWithFormat:@"Restore %@", appName]];
        [[AppDataBackupManager shared] restoreBackupAtDirectory:backupDir bundleID:bundleID appName:appName completion:^(PXRestoreResult *result, NSError *restoreError) {
            if (restoreError) [warnings addObject:[NSString stringWithFormat:@"Restore %@: %@", appName, restoreError.localizedDescription ?: @"failed"]];
            if (result.warnings.count) [warnings addObjectsFromArray:result.warnings];
            [self markRRSManifestRestoredAtBackupDirectory:backupDir];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD];
                NSString *msg = [NSString stringWithFormat:@"Đã restore %@.%@", appName, warnings.count ? [NSString stringWithFormat:@"\n\nWarnings:\n%@", [warnings componentsJoinedByString:@"\n"]] : @""];
                [self showDashboardMessage:@"Restore xong" message:msg];
            });
        }];
    }];
}

- (void)presentRRSSequenceModal {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Trình tự restore" message:@"Chọn thứ tự hoặc nhập begin/end" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"begin (trống = next)"; tf.keyboardType = UIKeyboardTypeNumberPad; }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"end (trống = cuối)"; tf.keyboardType = UIKeyboardTypeNumberPad; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Từ đầu đến cuối" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { self.rrsRestoreOrder = @"oldestFirst"; [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:[self currentProfileRestoreIndexKey]]; [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self currentProfileRestoreEndKey]]; [self persistDashboardSelections]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Ngược lại" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) { self.rrsRestoreOrder = @"newestFirst"; [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:[self currentProfileRestoreIndexKey]]; [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self currentProfileRestoreEndKey]]; [self persistDashboardSelections]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Theo số thứ tự" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a) {
        NSInteger begin = [alert.textFields[0].text integerValue];
        NSInteger end = [alert.textFields[1].text integerValue];
        if (begin > 0) [[NSUserDefaults standardUserDefaults] setInteger:begin - 1 forKey:[self currentProfileRestoreIndexKey]];
        if (end > 0) [[NSUserDefaults standardUserDefaults] setInteger:end forKey:[self currentProfileRestoreEndKey]];
        else [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self currentProfileRestoreEndKey]];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showDashboardMessage:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - More Options Button Action

- (void)moreOptionsButtonTapped:(UIButton *)sender {
    // Add safety check for the tag value
    if (sender.tag < 0 || !self.appSwitches || sender.tag >= self.appSwitches.allKeys.count) {
        NSLog(@"[WeaponX] ⚠️ Invalid button tag or appSwitches state");
        return;
    }
    
    NSString *bundleID = self.appSwitches.allKeys[sender.tag];
    if (!bundleID) {
        NSLog(@"[WeaponX] ⚠️ Could not find bundleID for tag: %ld", (long)sender.tag);
        return;
    }
    
    // Verify manager instances exist
    if (!self.manager || !self.freezeManager) {
        NSLog(@"[WeaponX] ⚠️ Manager instances are nil");
        return;
    }
    
    // Get app info with error handling
    NSDictionary *appInfo = [self.manager getApplicationInfo:bundleID];
    
    // Use safe values for app info
    NSString *appName = bundleID;
    BOOL isFrozen = NO;
    
    // Only if we have valid appInfo, extract information
    if (appInfo) {
        appName = appInfo[@"name"] ?: bundleID;
        isFrozen = [self.freezeManager isApplicationFrozen:bundleID];
    } else {
        NSLog(@"[WeaponX] ⚠️ Could not get app info for %@", bundleID);
    }
    
    // Create action sheet with app name as title
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:appName
                                                                        message:nil
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
    
    // Add freeze/unfreeze option with appropriate styling based on current state
    NSString *freezeTitle = isFrozen ? @"Unfreeze App" : @"Freeze App";
    UIImage *freezeImage = [UIImage systemImageNamed:@"snowflake.circle.fill"];
    
    UIAlertAction *freezeAction = [UIAlertAction actionWithTitle:freezeTitle
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
        @try {
            // Use the manager directly instead of calling freezeAppButtonTapped
            if (isFrozen) {
                [self.freezeManager unfreezeApplication:bundleID];
            } else {
                [self.freezeManager freezeApplication:bundleID];
            }
            
            // Update the UI for the specific cell that changed - with safety checks
            NSInteger index = [self.appSwitches.allKeys indexOfObject:bundleID];
            if (index != NSNotFound && self.appsTableView) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                [self.appsTableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            }
            
            // Also update the app list to reflect changes
            [self updateAppsList];
            
            // Show confirmation of the action
            NSString *confirmMessage = isFrozen ? 
                [NSString stringWithFormat:@"%@ has been unfrozen", appName] : 
                [NSString stringWithFormat:@"%@ has been frozen", appName];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:@"Status Changed"
                                                                                 message:confirmMessage
                                                                          preferredStyle:UIAlertControllerStyleAlert];
                [confirmAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                
                // Present after a short delay to let the action complete
                [self presentViewController:confirmAlert animated:YES completion:nil];
            });
        } @catch (NSException *exception) {
            NSLog(@"[WeaponX] ⚠️ Exception during freeze/unfreeze: %@", exception);
            
            // Show error message
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                             message:[NSString stringWithFormat:@"Could not perform action: %@", exception.reason]
                                                                      preferredStyle:UIAlertControllerStyleAlert];
                [errorAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:errorAlert animated:YES completion:nil];
            });
        }
    }];
    
    // Add visual indicator of freeze state to the action title - with error handling
    if (isFrozen && freezeImage) {
        @try {
            // Create attributed string with freeze icon for frozen apps
            NSMutableAttributedString *attributedTitle = [[NSMutableAttributedString alloc] initWithString:freezeTitle];
            NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
            attachment.image = [freezeImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            
            // Set the bounds to control image size
            CGFloat imageSize = 20.0;
            attachment.bounds = CGRectMake(0, -4, imageSize, imageSize);
            
            NSAttributedString *imageString = [NSAttributedString attributedStringWithAttachment:attachment];
            [attributedTitle insertAttributedString:imageString atIndex:0];
            [attributedTitle insertAttributedString:[[NSAttributedString alloc] initWithString:@" "] atIndex:1];
            
            [freezeAction setValue:attributedTitle forKey:@"attributedTitle"];
            [freezeAction setValue:[UIColor systemBlueColor] forKey:@"titleTextColor"];
        } @catch (NSException *exception) {
            NSLog(@"[WeaponX] ⚠️ Exception during attributed text creation: %@", exception);
            // Continue without styled text if there's an error
        }
    }
    
    // Add app info option
    UIAlertAction *infoAction = [UIAlertAction actionWithTitle:@"App Info"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * _Nonnull action) {
        @try {
            // Display app info in an alert
            NSString *version = appInfo[@"version"] ?: @"Unknown";
            
            // Fix: Use buildVersionString instead of buildNumber (per LSApplicationProxy category properties)
            NSString *buildNumber = appInfo[@"buildVersionString"] ?: appInfo[@"build"] ?: @"Unknown";
            
            // Log available keys to debug
            NSLog(@"[WeaponX] 📱 App Info keys: %@", [appInfo allKeys]);
            
            NSString *infoMessage = [NSString stringWithFormat:
                                   @"Bundle ID: %@\nVersion: %@\nBuild: %@\nFrozen: %@",
                                   bundleID, 
                                   version,
                                   buildNumber,
                                   isFrozen ? @"Yes" : @"No"];
            
            UIAlertController *infoAlert = [UIAlertController alertControllerWithTitle:appName
                                                                             message:infoMessage
                                                                      preferredStyle:UIAlertControllerStyleAlert];
            
            // Add copy action to copy bundle ID
            UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"Copy Bundle ID"
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * _Nonnull action) {
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                [pasteboard setString:bundleID];
            }];
            
            // Add close action
            UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"Close"
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil];
            
            [infoAlert addAction:copyAction];
            [infoAlert addAction:closeAction];
            [self presentViewController:infoAlert animated:YES completion:nil];
        } @catch (NSException *exception) {
            NSLog(@"[WeaponX] ⚠️ Exception during info view: %@", exception);
        }
    }];
    
    // Add backup/restore option
    UIAlertAction *backupRestoreAction = [UIAlertAction actionWithTitle:@"BACKUP/RESTORE"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
        @try {
            // Create and configure the backup/restore view controller
            AppDataBackupRestoreViewController *backupRestoreVC = [[AppDataBackupRestoreViewController alloc] init];
            
            // Configure it with the current app info if needed
            // We could store the bundleID and app name as properties if the VC needs them
            if ([backupRestoreVC respondsToSelector:@selector(setBundleID:)]) {
                [backupRestoreVC performSelector:@selector(setBundleID:) withObject:bundleID];
            }
            
            if ([backupRestoreVC respondsToSelector:@selector(setAppName:)]) {
                [backupRestoreVC performSelector:@selector(setAppName:) withObject:appName];
            }
            
            // Present the view controller with a navigation controller for better UX
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:backupRestoreVC];
            navController.modalPresentationStyle = UIModalPresentationFormSheet;
            [self presentViewController:navController animated:YES completion:nil];
        } @catch (NSException *exception) {
            NSLog(@"[WeaponX] ⚠️ Exception during backup/restore view: %@", exception);
        }
    }];
    
    // Add "Open in Settings" option with correct URL format for iOS Settings app
    UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:@"Open in Settings"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
        @try {
            // Try multiple methods to open app settings
            [self openAppSettings:bundleID];
        } @catch (NSException *exception) {
            NSLog(@"[WeaponX] ⚠️ Exception opening settings: %@", exception);
            
            // Fallback to general settings as a last resort
            NSURL *generalSettingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            [[UIApplication sharedApplication] openURL:generalSettingsURL options:@{} completionHandler:nil];
        }
    }];
    
    // Add actions in logical order
    [actionSheet addAction:freezeAction];
    [actionSheet addAction:infoAction];
    [actionSheet addAction:backupRestoreAction]; // Add the new action
    [actionSheet addAction:settingsAction];
    
    // Add cancel option
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                         style:UIAlertActionStyleCancel
                                                       handler:nil];
    [actionSheet addAction:cancelAction];
    
    // For iPad support - set source view for popover
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        actionSheet.popoverPresentationController.sourceView = sender;
        actionSheet.popoverPresentationController.sourceRect = sender.bounds;
    }
    
    [self presentViewController:actionSheet animated:YES completion:nil];
}

// Keeping only one openAppSettings implementation - the more comprehensive one that calls tryAppPrefsFormat
// Remove the helper method for opening general settings as a fallback
- (void)openGeneralSettings {
    NSLog(@"[WeaponX] ⚠️ Falling back to general settings");
    NSURL *generalSettingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    [[UIApplication sharedApplication] openURL:generalSettingsURL options:@{} completionHandler:nil];
}

// Implementation of openAppSettings method
- (void)openAppSettings:(NSString *)bundleID {
    NSLog(@"[WeaponX] 🔍 Attempting to open settings for %@", bundleID);
    
    // Try all possible URL schemes with proper URL encoding
    NSString *encodedBundleID = [bundleID stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    // Priority 1: prefs:root=Privacy&path=APPLEID/[bundle-id] - as explicitly requested
    NSString *privacyPathUrlString = [NSString stringWithFormat:@"prefs:root=Privacy&path=APPLEID/%@", encodedBundleID];
    NSURL *privacyPathUrl = [NSURL URLWithString:privacyPathUrlString];
    
    NSLog(@"[WeaponX] 🔍 Trying URL: %@", privacyPathUrlString);
    
    // Check if the URL can be opened
    if ([[UIApplication sharedApplication] canOpenURL:privacyPathUrl]) {
        [[UIApplication sharedApplication] openURL:privacyPathUrl options:@{} completionHandler:^(BOOL success) {
            NSLog(@"[WeaponX] %@ Opening prefs:root=Privacy&path=APPLEID/%@", success ? @"✅" : @"❌", bundleID);
            
            if (!success) {
                // Continue with next method if this fails
                [self tryAppPrefsFormat:bundleID];
            }
        }];
        return;
    } else {
        NSLog(@"[WeaponX] ❌ Cannot open URL: %@", privacyPathUrlString);
        [self tryAppPrefsFormat:bundleID];
    }
}

// Try App-Prefs format - second priority as requested
- (void)tryAppPrefsFormat:(NSString *)bundleID {
    NSString *encodedBundleID = [bundleID stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    // Format variations to try
    NSArray *appPrefsFormats = @[
        [NSString stringWithFormat:@"App-Prefs:%@", encodedBundleID],
        [NSString stringWithFormat:@"App-prefs:root=%@", encodedBundleID],
        [NSString stringWithFormat:@"app-prefs:root=%@", encodedBundleID]
    ];
    
    // Try each format in order
    for (NSString *urlString in appPrefsFormats) {
        NSURL *url = [NSURL URLWithString:urlString];
        NSLog(@"[WeaponX] 🔍 Trying URL: %@", urlString);
        
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                NSLog(@"[WeaponX] %@ Opening %@", success ? @"✅" : @"❌", urlString);
                
                if (!success && [urlString isEqualToString:[appPrefsFormats lastObject]]) {
                    // If this was the last App-Prefs format and it failed, try other approaches
                    [self tryOtherApproaches:bundleID];
                }
            }];
            return;
        } else {
            NSLog(@"[WeaponX] ❌ Cannot open URL: %@", urlString);
        }
    }
    
    // If we get here, none of the App-Prefs formats worked
    [self tryOtherApproaches:bundleID];
}

// Try other approaches as fallbacks
- (void)tryOtherApproaches:(NSString *)bundleID {
    NSString *encodedBundleID = [bundleID stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    // Additional formats to try
    NSArray *otherFormats = @[
        [NSString stringWithFormat:@"prefs:root=General&path=ManagedConfigurationList/%@", encodedBundleID],
        [NSString stringWithFormat:@"app-settings:%@", encodedBundleID],
        [NSString stringWithFormat:@"prefs:root=SettingsForApp-%@", encodedBundleID]
    ];
    
    // Try each format in order
    for (NSString *urlString in otherFormats) {
        NSURL *url = [NSURL URLWithString:urlString];
        NSLog(@"[WeaponX] 🔍 Trying URL: %@", urlString);
        
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                NSLog(@"[WeaponX] %@ Opening %@", success ? @"✅" : @"❌", urlString);
                
                if (!success && [urlString isEqualToString:[otherFormats lastObject]]) {
                    // If this was the last format and it failed, try the universal method
                    [self tryUniversalSettingsMethod:bundleID];
                }
            }];
            return;
        } else {
            NSLog(@"[WeaponX] ❌ Cannot open URL: %@", urlString);
        }
    }
    
    // If we get here, none of the other formats worked
    [self tryUniversalSettingsMethod:bundleID];
}

// Try the universal settings method as last resort
- (void)tryUniversalSettingsMethod:(NSString *)bundleID {
    // Use UIApplicationOpenSettingsURLString with query parameter as a "universal" approach
    NSString *encodedBundleID = [bundleID stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *settingsString = [NSString stringWithFormat:@"%@?app=%@", 
                             UIApplicationOpenSettingsURLString, 
                             encodedBundleID];
    NSURL *url = [NSURL URLWithString:settingsString];
    
    NSLog(@"[WeaponX] 🔍 Trying universal settings URL: %@", settingsString);
    
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        NSLog(@"[WeaponX] %@ Opening universal settings URL", success ? @"✅" : @"❌");
        
        if (!success) {
            // Last resort - open general settings
            NSLog(@"[WeaponX] ⚠️ All methods failed, falling back to general settings");
            NSURL *generalSettingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            [[UIApplication sharedApplication] openURL:generalSettingsURL options:@{} completionHandler:nil];
        }
    }];
}

// Remove the openGeneralSettings method since it's now included in the tryUniversalSettingsMethod

#pragma mark - Tools Button

- (void)toolsButtonTapped {
    ToolViewController *toolsVC = [[ToolViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:toolsVC];
    if (@available(iOS 15.0, *)) {
        // Modern styling for iOS 15+
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithDefaultBackground];
        navController.navigationBar.standardAppearance = appearance;
        navController.navigationBar.scrollEdgeAppearance = appearance;
    }
    [self presentViewController:navController animated:YES completion:nil];
}



- (void)handleProfileChanged:(NSNotification *)notification {
    // This method is called when the profile changes
    NSLog(@"[WeaponX] Profile changed notification received");
    
    // Update the profile indicator to show the new profile
    [self updateProfileIndicator];
    
    // Refresh all identifier values in the UI
    [self refreshIdentifierValuesInUI];
    
    // Also refresh the apps list in case app scoping has changed
    [self loadSettings];
}

#pragma mark - Memory Management

- (void)dealloc {
    // Remove all notification observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end

static NSString *PXKeychainWipeEnabledKey(NSString *bundleID) {
    return [NSString stringWithFormat:@"dataCleanerKeychainWipeEnabled_%@", bundleID ?: @""];
}

static NSString *PXKeychainWipeGroupsKey(NSString *bundleID) {
    return [NSString stringWithFormat:@"dataCleanerKeychainWipeGroups_%@", bundleID ?: @""];
}
