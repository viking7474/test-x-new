#import "AppVersionEditorViewController.h"
#import "common/PXUIKitCompat.h"
#import "VersionManagementViewController.h"

@interface AppVersionEditorViewController () <VersionManagementViewControllerDelegate, UITextFieldDelegate>
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *appName;
@property (nonatomic, strong) NSUserDefaults *securitySettings;
@property (nonatomic, strong) UISwitch *perAppSwitch;
@property (nonatomic, strong) UITextField *versionField;
@property (nonatomic, strong) UITextField *buildField;
@end

@implementation AppVersionEditorViewController

- (instancetype)initWithBundleID:(NSString *)bundleID appName:(NSString *)appName {
    self = [super init];
    if (self) {
        _bundleID = [bundleID copy];
        _appName = [appName copy];
        _securitySettings = [[NSUserDefaults alloc] initWithSuiteName:@"com.weaponx.securitySettings"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = (self.appName.length > 0) ? self.appName : @"App Version";
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = PXSystemGroupedBackgroundColor();
    } else {
        self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    }

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
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

    [stack addArrangedSubview:[self buildHero]];

    [stack addArrangedSubview:[self sectionHeader:@"TR\u1ea0NG TH\u00c1I"]];
    UIView *statusCard = [self cardContainer];
    [self addToggleRowToCard:statusCard];
    [stack addArrangedSubview:statusCard];

    [stack addArrangedSubview:[self sectionHeader:@"NH\u1eacP TAY"]];
    UIView *manualCard = [self cardContainer];
    [self addManualFieldsToCard:manualCard];
    [stack addArrangedSubview:manualCard];

    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [saveBtn setTitle:@"L\u01b0u phi\u00ean b\u1ea3n" forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveBtn.backgroundColor = [UIColor systemBlueColor];
    saveBtn.layer.cornerRadius = 12;
    [saveBtn addTarget:self action:@selector(saveTapped) forControlEvents:UIControlEventTouchUpInside];
    [saveBtn.heightAnchor constraintEqualToConstant:48].active = YES;
    [stack addArrangedSubview:saveBtn];

    [stack addArrangedSubview:[self sectionHeader:@"APP STORE"]];
    UIButton *fetchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    fetchBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [fetchBtn setTitle:@"Fetch phi\u00ean b\u1ea3n t\u1eeb App Store" forState:UIControlStateNormal];
    fetchBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [fetchBtn setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    fetchBtn.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.12];
    fetchBtn.layer.cornerRadius = 12;
    [fetchBtn addTarget:self action:@selector(fetchTapped) forControlEvents:UIControlEventTouchUpInside];
    [fetchBtn.heightAnchor constraintEqualToConstant:48].active = YES;
    [stack addArrangedSubview:fetchBtn];

    [stack addArrangedSubview:[self noteLabel:@"S\u1ed1 phi\u00ean b\u1ea3n (CFBundleShortVersionString) s\u1ebd \u0111\u01b0\u1ee3c spoof ri\u00eang cho app n\u00e0y. L\u01b0u s\u1ebd t\u1ef1 b\u1eadt spoof cho app."]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadFromPlist];
}

#pragma mark - Data paths

- (NSString *)prefsPath {
    NSString *p = @"/var/mobile/Library/Preferences";
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:p]) {
        p = @"/private/var/mobile/Library/Preferences";
        if (![fm fileExistsAtPath:p]) {
            p = @"/var/mobile/Library/Preferences";
        }
    }
    return p;
}

- (NSString *)versionSpoofFile {
    return [[self prefsPath] stringByAppendingPathComponent:@"com.hydra.tlinkios.version_spoof.plist"];
}

- (NSDictionary *)currentSpoofInfo {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[self versionSpoofFile]];
    NSDictionary *sv = dict[@"SpoofedVersions"];
    NSDictionary *info = sv[self.bundleID];
    return [info isKindOfClass:[NSDictionary class]] ? info : @{};
}

- (void)reloadFromPlist {
    NSDictionary *info = [self currentSpoofInfo];
    NSString *v = info[@"spoofedVersion"];
    NSString *b = info[@"spoofedBuild"];
    self.versionField.text = [v isKindOfClass:[NSString class]] ? v : @"";
    self.buildField.text = [b isKindOfClass:[NSString class]] ? b : @"";
    [self.perAppSwitch setOn:[info[@"spoofingEnabled"] boolValue] animated:NO];
}

#pragma mark - Persistence

- (BOOL)saveVersion:(NSString *)version build:(NSString *)build {
    NSString *profileId = nil;
    Class idc = NSClassFromString(@"IdentifierManager");
    if (idc && [idc respondsToSelector:@selector(sharedManager)]) {
        id mgr = [idc performSelector:@selector(sharedManager)];
        if ([mgr respondsToSelector:@selector(getActiveProfileId)]) {
            profileId = [mgr performSelector:@selector(getActiveProfileId)];
        }
    }

    if (profileId.length > 0) {
        NSString *profileDir = [NSString stringWithFormat:@"/var/mobile/Library/WeaponX/Profiles/%@", profileId];
        NSString *appVersionsDir = [profileDir stringByAppendingPathComponent:@"app_versions"];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:appVersionsDir]) {
            NSDictionary *attrs = @{NSFilePosixPermissions: @0755, NSFileOwnerAccountName: @"mobile"};
            [fm createDirectoryAtPath:appVersionsDir withIntermediateDirectories:YES attributes:attrs error:nil];
        }
        NSString *profileVersionFile = [appVersionsDir stringByAppendingPathComponent:[[self.bundleID stringByReplacingOccurrencesOfString:@"." withString:@"_"] stringByAppendingString:@"_version.plist"]];
        NSMutableDictionary *avd = [NSMutableDictionary dictionary];
        avd[@"bundleID"] = self.bundleID;
        avd[@"name"] = self.appName ?: self.bundleID;
        if (version.length > 0) { avd[@"spoofedVersion"] = version; }
        if (build.length > 0) { avd[@"spoofedBuild"] = build; }
        avd[@"lastUpdated"] = [NSDate date];
        if (![avd writeToFile:profileVersionFile atomically:YES]) {
            NSLog(@"[AppVersionEditor] Profile version mirror write failed: %@", profileVersionFile);
        }
    }

    NSString *file = [self versionSpoofFile];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithContentsOfFile:file];
    if (![dict isKindOfClass:[NSMutableDictionary class]]) { dict = [NSMutableDictionary dictionary]; }
    NSMutableDictionary *sv = [dict[@"SpoofedVersions"] mutableCopy];
    if (![sv isKindOfClass:[NSMutableDictionary class]]) { sv = [NSMutableDictionary dictionary]; }
    NSMutableDictionary *info = [sv[self.bundleID] mutableCopy];
    if (![info isKindOfClass:[NSMutableDictionary class]]) { info = [NSMutableDictionary dictionary]; }
    info[@"name"] = self.appName ?: self.bundleID;
    if (version.length > 0) { info[@"spoofedVersion"] = version; }
    if (build.length > 0) { info[@"spoofedBuild"] = build; }
    info[@"spoofingEnabled"] = @YES;
    sv[self.bundleID] = info;
    dict[@"SpoofedVersions"] = sv;
    dict[@"LastUpdated"] = [NSDate date];
    if (![dict writeToFile:file atomically:YES]) {
        NSLog(@"[AppVersionEditor] Failed to persist version spoof data: %@", file);
        return NO;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.hydra.tlinkios.appVersionDataChanged" object:nil];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         CFSTR("com.hydra.tlinkios.appVersionSpoofChanged"),
                                         NULL, NULL, YES);
    return YES;
}

- (BOOL)persistToggle:(BOOL)enabled {
    NSString *file = [self versionSpoofFile];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithContentsOfFile:file];
    if (![dict isKindOfClass:[NSMutableDictionary class]]) { dict = [NSMutableDictionary dictionary]; }
    NSMutableDictionary *sv = [dict[@"SpoofedVersions"] mutableCopy];
    if (![sv isKindOfClass:[NSMutableDictionary class]]) { sv = [NSMutableDictionary dictionary]; }
    NSMutableDictionary *info = [sv[self.bundleID] mutableCopy];
    if (![info isKindOfClass:[NSMutableDictionary class]]) { info = [NSMutableDictionary dictionary]; }
    info[@"spoofingEnabled"] = @(enabled);
    info[@"name"] = self.appName ?: self.bundleID;
    sv[self.bundleID] = info;
    dict[@"SpoofedVersions"] = sv;
    dict[@"LastUpdated"] = [NSDate date];
    if (![dict writeToFile:file atomically:YES]) {
        NSLog(@"[AppVersionEditor] Failed to persist per-app toggle: %@", file);
        return NO;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"com.hydra.tlinkios.appVersionDataChanged" object:nil];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         CFSTR("com.hydra.tlinkios.appVersionSpoofChanged"),
                                         NULL, NULL, YES);
    return YES;
}

#pragma mark - Actions

- (void)saveTapped {
    [self.view endEditing:YES];
    NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *version = [self.versionField.text stringByTrimmingCharactersInSet:ws];
    NSString *build = [self.buildField.text stringByTrimmingCharactersInSet:ws];
    if (version.length == 0 && build.length == 0) {
        [self showToast:@"Nh\u1eadp phi\u00ean b\u1ea3n tr\u01b0\u1edbc"];
        return;
    }
    if (![self saveVersion:version build:build]) {
        [self reloadFromPlist];
        [self showToast:@"Kh\u00f4ng th\u1ec3 l\u01b0u phi\u00ean b\u1ea3n"];
        return;
    }
    [self.perAppSwitch setOn:YES animated:YES];
    [self showToast:@"\u0110\u00e3 l\u01b0u"];
    UIImpactFeedbackGenerator *g = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [g prepare];
    [g impactOccurred];
}

- (void)perAppToggleChanged:(UISwitch *)sender {
    BOOL enabled = sender.isOn;
    if (![self persistToggle:enabled]) {
        [sender setOn:!enabled animated:YES];
        [self reloadFromPlist];
        [self showToast:@"Kh\u00f4ng th\u1ec3 l\u01b0u tr\u1ea1ng th\u00e1i spoof"];
        return;
    }
    [self showToast:(enabled ? @"\u0110\u00e3 b\u1eadt spoof" : @"\u0110\u00e3 t\u1eaft spoof")];
}

- (void)fetchTapped {
    [self.view endEditing:YES];
    if (self.bundleID.length == 0) { [self showToast:@"Thi\u1ebfu bundle ID"]; return; }

    UIActivityIndicatorView *spinner;
    if (@available(iOS 13.0, *)) {
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:PXLargeActivityIndicatorStyle()];
    } else {
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        spinner.color = PXLabelColor();
    }
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:spinner];
    [NSLayoutConstraint activateConstraints:@[
        [spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
    [spinner startAnimating];
    self.view.userInteractionEnabled = NO;

    NSString *lookupStr = [NSString stringWithFormat:@"https://itunes.apple.com/lookup?bundleId=%@&entity=software&country=us", self.bundleID];
    NSURL *lookupUrl = [NSURL URLWithString:lookupStr];
    if (!lookupUrl) {
        [spinner stopAnimating]; [spinner removeFromSuperview];
        self.view.userInteractionEnabled = YES;
        [self showToast:@"URL kh\u00f4ng h\u1ee3p l\u1ec7"];
        return;
    }

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:lookupUrl completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *appStoreInfo = nil;
        if (data && !error) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSArray *results = json[@"results"];
            if ([results isKindOfClass:[NSArray class]] && results.count > 0) {
                appStoreInfo = results.firstObject;
            }
        }
        if (![appStoreInfo isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [spinner stopAnimating]; [spinner removeFromSuperview];
                self.view.userInteractionEnabled = YES;
                [self showToast:@"Kh\u00f4ng t\u00ecm th\u1ea5y app tr\u00ean App Store"];
            });
            return;
        }
        NSString *appId = [NSString stringWithFormat:@"%@", appStoreInfo[@"trackId"]];
        NSString *curVer = [self coerceString:appStoreInfo[@"version"]];
        NSString *curBuild = [self coerceString:appStoreInfo[@"build"]];
        NSString *histStr = [NSString stringWithFormat:@"https://apis.bilin.eu.org/history/%@", appId];
        NSURL *histUrl = [NSURL URLWithString:histStr];
        NSURLSessionDataTask *ht = [[NSURLSession sharedSession] dataTaskWithURL:histUrl completionHandler:^(NSData *hd, NSURLResponse *hr, NSError *he) {
            NSMutableArray *items = [NSMutableArray array];
            if (curVer.length > 0) {
                [items addObject:@{ @"version": curVer, @"build": (curBuild ?: @"") }];
            }
            if (hd && !he) {
                NSDictionary *hj = [NSJSONSerialization JSONObjectWithData:hd options:0 error:nil];
                NSArray *versions = hj[@"data"];
                if ([versions isKindOfClass:[NSArray class]]) {
                    for (NSDictionary *v in versions) {
                        if (![v isKindOfClass:[NSDictionary class]]) { continue; }
                        NSString *ver = [self coerceString:v[@"bundle_version"]];
                        if (ver.length == 0) { continue; }
                        NSString *bn = [self coerceString:v[@"build"]];
                        if (bn.length == 0) { bn = [self coerceString:v[@"build_number"]]; }
                        [items addObject:@{ @"version": ver, @"build": (bn ?: @"") }];
                    }
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [spinner stopAnimating]; [spinner removeFromSuperview];
                self.view.userInteractionEnabled = YES;
                if (items.count == 0) { [self showToast:@"Kh\u00f4ng l\u1ea5y \u0111\u01b0\u1ee3c phi\u00ean b\u1ea3n"]; return; }
                [self showVersionPicker:items];
            });
        }];
        [ht resume];
    }];
    [task resume];
}

- (NSString *)coerceString:(id)v {
    if ([v isKindOfClass:[NSString class]]) { return v; }
    if ([v isKindOfClass:[NSNumber class]]) { return [v stringValue]; }
    return nil;
}

- (void)showVersionPicker:(NSArray *)items {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Ch\u1ecdn phi\u00ean b\u1ea3n" message:@"Ch\u1ecdn phi\u00ean b\u1ea3n \u0111\u1ec3 spoof cho app n\u00e0y" preferredStyle:UIAlertControllerStyleActionSheet];
    NSInteger maxCount = MIN((NSInteger)items.count, 40);
    for (NSInteger k = 0; k < maxCount; k++) {
        NSDictionary *it = items[k];
        NSString *ver = it[@"version"];
        NSString *bld = it[@"build"];
        NSString *title = (bld.length > 0) ? [NSString stringWithFormat:@"%@ (build %@)", ver, bld] : ver;
        UIAlertAction *a = [UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.versionField.text = ver;
            self.buildField.text = bld;
            if (![self saveVersion:ver build:bld]) {
                [self reloadFromPlist];
                [self showToast:@"Kh\u00f4ng th\u1ec3 l\u01b0u phi\u00ean b\u1ea3n"];
                return;
            }
            [self.perAppSwitch setOn:YES animated:YES];
            [self showToast:@"\u0110\u00e3 l\u01b0u"];
        }];
        [sheet addAction:a];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"H\u1ee7y" style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = self.view;
        sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
        sheet.popoverPresentationController.permittedArrowDirections = 0;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - VersionManagementViewControllerDelegate

- (void)versionManagementDidUpdateVersions {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadFromPlist];
        [self showToast:@"\u0110\u00e3 c\u1eadp nh\u1eadt phi\u00ean b\u1ea3n"];
    });
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Building blocks

- (UITextField *)makeFieldWithPlaceholder:(NSString *)ph {
    UITextField *f = [[UITextField alloc] init];
    f.translatesAutoresizingMaskIntoConstraints = NO;
    f.placeholder = ph;
    f.borderStyle = UITextBorderStyleRoundedRect;
    f.font = [UIFont systemFontOfSize:16];
    f.autocorrectionType = UITextAutocorrectionTypeNo;
    f.autocapitalizationType = UITextAutocapitalizationTypeNone;
    f.clearButtonMode = UITextFieldViewModeWhileEditing;
    f.delegate = self;
    f.returnKeyType = UIReturnKeyDone;
    return f;
}

- (void)addManualFieldsToCard:(UIView *)card {
    self.versionField = [self makeFieldWithPlaceholder:@"Phi\u00ean b\u1ea3n (VD: 8.0.1)"];
    self.buildField = [self makeFieldWithPlaceholder:@"Build (t\u00f9y ch\u1ecdn)"];
    [card addSubview:self.versionField];
    [card addSubview:self.buildField];
    [NSLayoutConstraint activateConstraints:@[
        [self.versionField.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
        [self.versionField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [self.versionField.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [self.versionField.heightAnchor constraintEqualToConstant:44],
        [self.buildField.topAnchor constraintEqualToAnchor:self.versionField.bottomAnchor constant:12],
        [self.buildField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [self.buildField.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [self.buildField.heightAnchor constraintEqualToConstant:44],
        [self.buildField.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
    ]];
}

- (void)addToggleRowToCard:(UIView *)card {
    UIView *row = [[UIView alloc] init];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:row];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"B\u1eadt spoof cho app n\u00e0y";
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    title.textColor = PXLabelColor();
    [row addSubview:title];

    UILabel *sub = [[UILabel alloc] init];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.text = self.bundleID;
    sub.font = [UIFont systemFontOfSize:12];
    sub.textColor = PXSecondaryLabelColor();
    sub.numberOfLines = 1;
    sub.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [row addSubview:sub];

    self.perAppSwitch = [[UISwitch alloc] init];
    self.perAppSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.perAppSwitch.onTintColor = [UIColor systemBlueColor];
    [self.perAppSwitch addTarget:self action:@selector(perAppToggleChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:self.perAppSwitch];

    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:card.topAnchor],
        [row.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [row.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [row.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:64],
        [title.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [title.topAnchor constraintEqualToAnchor:row.topAnchor constant:12],
        [sub.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],
        [sub.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-12],
        [self.perAppSwitch.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [self.perAppSwitch.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:self.perAppSwitch.leadingAnchor constant:-12],
        [sub.trailingAnchor constraintLessThanOrEqualToAnchor:self.perAppSwitch.leadingAnchor constant:-12],
    ]];
}

- (UIView *)buildHero {
    UIView *card = [self cardContainer];
    UIView *chip = [self iconChip:@"app.badge" color:[UIColor systemBlueColor]];
    [card addSubview:chip];

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = (self.appName.length > 0) ? self.appName : @"App Version";
    title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    title.textColor = PXLabelColor();
    title.numberOfLines = 0;
    [card addSubview:title];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = self.bundleID;
    subtitle.font = [UIFont systemFontOfSize:13];
    subtitle.textColor = PXSecondaryLabelColor();
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
        iv.image = [PXSystemImageNamed(symbolName) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
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

- (UIView *)cardContainer {
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        card.backgroundColor = PXSecondarySystemGroupedBackgroundColor();
    } else {
        card.backgroundColor = [UIColor whiteColor];
    }
    card.layer.cornerRadius = 16;
    card.clipsToBounds = YES;
    return card;
}

- (UILabel *)sectionHeader:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    label.textColor = PXSecondaryLabelColor();
    return label;
}

- (UILabel *)noteLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [UIFont systemFontOfSize:12];
    label.textColor = PXSecondaryLabelColor();
    label.numberOfLines = 0;
    return label;
}

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
