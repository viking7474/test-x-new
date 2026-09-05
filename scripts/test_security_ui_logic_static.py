#!/usr/bin/env python3
"""Static regression contract for Security UI/runtime consistency and iOS 12 compatibility."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)
    print(f"PASS: {message}")


def method_body(source: str, signature: str, window: int = 7000) -> str:
    start = source.find(signature)
    if start < 0:
        raise AssertionError(f"missing method: {signature}")
    return source[start:start + window]


security = read("SecurityTabViewController.m")
store_h = read("common/PXSecuritySettingsStore.h")
store_m = read("common/PXSecuritySettingsStore.m")
domain_h = read("common/DomainBlockingSettings.h")
domain_m = read("common/DomainBlockingSettings.m")
domain_ui = read("DomainManagementViewController.m")
domain_hook = read("TLinkIOSTweak/DomainBlockingHooks.x")
app_editor = read("AppVersionEditorViewController.m")
app_list = read("AppVersionListDetailViewController.m")
identifier_h = read("common/IdentifierManager.h")
tlink_h = read("TLinkIOS.h")
identifier_m = read("common/IdentifierManager.m")
device_ui = read("DeviceSpecificSpoofingViewController.m")
legacy_ui = read("TLinkIOSViewController.m")
rrs_ui = read("PXRRSManagerViewController.m")
jailbreak_hook = read("TLinkIOSTweak/JailbreakBypassHooks.x")
uikit_h = read("common/PXUIKitCompat.h")
uikit_m = read("common/PXUIKitCompat.m")

# Shared authoritative Security settings store.
for symbol in (
    "PXReadSecuritySetting",
    "PXReadSecurityBool",
    "PXReadSecurityInteger",
    "PXWriteSecuritySetting",
    "PXWriteSecurityBool",
    "PXWriteSecurityInteger",
):
    require(symbol in store_h and symbol in store_m, f"shared security store exposes and implements {symbol}")
require("flock(fd, LOCK_EX)" in store_m and "flock(fd, LOCK_UN)" in store_m,
        "security settings writes are file-lock protected")
require("NSDataWritingAtomic" in store_m, "security settings authoritative plist uses atomic writes")
primary_write = store_m.find("writeToFile:path options:NSDataWritingAtomic")
mirror_loop = store_m.find("for (NSString *suiteName in PXSecuritySuiteNames())")
require(primary_write >= 0 and mirror_loop > primary_write,
        "NSUserDefaults mirrors happen only after authoritative plist write")

# Parent Security tab must refresh effective state after returning from detail screens.
refresh = method_body(security, "- (void)refreshSecurityControlsFromAuthoritativeState")
for token in (
    'jailbreakDetectionEnabled',
    'vpnDetectionBypassEnabled',
    'refreshCanvasFingerprintingControlState',
    'refreshNetworkDependencyState',
    'refreshDeviceSpoofingDependencyState',
    'appVersionSpoofingEnabled',
    'timeSpoofingMode',
    'deepCleanEnabled',
    'allowSystemKeychainWipeEnabled',
    'profileIndicatorEnabled',
    'domainBlockingToggleSwitch',
    'updateSecurityHeroCount',
):
    require(token in refresh, f"Security refresh covers {token}")
view_will_appear = method_body(security, "- (void)viewWillAppear:(BOOL)animated", 1400)
require("refreshSecurityControlsFromAuthoritativeState" in view_will_appear,
        "Security tab reloads authoritative state on viewWillAppear")
require("@property (nonatomic, strong) UISegmentedControl *timeSpoofingModeSegment" in security,
        "Time Spoof segment is retained for parent refresh")

# Network dependency state: child mutation controls cannot stay interactive while parent is off.
network_refresh = method_body(security, "- (void)refreshNetworkDependencyState")
require("BOOL allowISO = enabled && showISO" in network_refresh,
        "Network ISO controls derive enablement from master + Cellular state")
for token in (
    "self.networkISOCountrySegment.enabled = allowISO",
    "self.customISOButton.enabled = allowISO",
    "self.quickGenerateButton.enabled = allowISO",
    "self.carrierNameField.enabled = allowISO && customISO",
    "self.localIPField.enabled = enabled && showLocalIP",
):
    require(token in network_refresh, f"Network dependency refresh enforces {token}")
network_toggle = method_body(security, "- (void)networkDataSpoofToggleChanged:", 3200)
require("refreshNetworkDependencyState" in network_toggle,
        "Network master toggle refreshes all dependent controls")

# Full Spoof Test must force effective Safari state without overwriting the user's stored preference.
device_refresh = method_body(security, "- (void)refreshDeviceSpoofingDependencyState")
require("BOOL effectiveSafari = deviceEnabled && (fullTest || configuredSafari)" in device_refresh,
        "Safari/Auth UI uses effective Full-Test state")
require("self.safariStackSpoofingToggleSwitch.enabled = deviceEnabled && !fullTest" in device_refresh,
        "Safari/Auth switch is disabled while Full Spoof Test forces it")
full_toggle = method_body(security, "- (void)fullSpoofTestModeToggleChanged:", 1700)
require('PXWriteSecurityBool(@"fullSpoofTestModeEnabled"' in full_toggle,
        "Full Spoof Test uses verified persistence")
require('PXWriteSecurityBool(@"safariStackSpoofEnabled"' not in full_toggle,
        "Full Spoof Test does not overwrite stored Safari/Auth preference")
safari_toggle = method_body(security, "- (void)safariStackSpoofingToggleChanged:", 1500)
require('PXReadSecurityBool(@"fullSpoofTestModeEnabled", NO)' in safari_toggle,
        "Safari/Auth handler rejects mutation while Full Spoof Test is active")

# Audited Security toggles use verified persistence and rollback instead of direct false-success writes.
for path, key in (
    ("JailbreakDetailViewController.m", "jailbreakDetectionEnabled"),
    ("NetworkDataDetailViewController.m", "networkDataSpoofEnabled"),
    ("VPNDetectionDetailViewController.m", "vpnDetectionBypassEnabled"),
    ("SystemKeychainWipeDetailViewController.m", "allowSystemKeychainWipeEnabled"),
):
    source = read(path)
    require(f'PXWriteSecurityBool(@"{key}"' in source, f"{path} persists {key} through verified store")
    require("setOn:" in source and "return;" in source, f"{path} has failure rollback/early return")

# Domain Blocking: verified save, synchronized snapshots, successful writes notify running injected processes.
require("- (BOOL)saveSettings" in domain_h and "- (BOOL)loadSettings" in domain_h,
        "Domain Blocking save/load APIs return success")
require(domain_m.count("@synchronized (self)") >= 8,
        "Domain Blocking serializes mutation and accessor paths")
require("- (BOOL)isDomainBlocked:(NSString *)domain" in domain_m and
        "@synchronized (self)" in method_body(domain_m, "- (BOOL)isDomainBlocked:(NSString *)domain", 1800),
        "Domain runtime decision reads a synchronized snapshot")
require("- (NSArray<NSDictionary *> *)getCustomDomains" in domain_m and
        "@synchronized (self)" in method_body(domain_m, "- (NSArray<NSDictionary *> *)getCustomDomains", 1500),
        "Domain UI accessor is synchronized with runtime reload")
require("domainBlockingSettingsChanged" in domain_hook and "loadSettings" in domain_hook and
        'CFSTR("com.hydra.tlinkios.domainBlockingChanged")' in domain_hook,
        "Domain Blocking runtime listens for cross-process reload notification")
require("Install hooks even when Domain Blocking is currently OFF" in domain_hook,
        "Domain hooks support hot enable/disable without target restart")
require("if (![settings setCustomDomainEnabled:domain enabled:enabled])" in domain_ui and
        "[self postDomainBlockingChanged];" in domain_ui,
        "Domain management notifies runtime only after verified model mutation")
domain_master = method_body(security, "- (void)domainBlockingToggleChanged:", 1800)
require("if (![settings saveSettings])" in domain_master and "settings.isEnabled = previous" in domain_master,
        "Domain master switch rolls back on persistence failure")

# App Version editor/list: authoritative writes are checked and UI success is conditional.
require("- (BOOL)saveVersion:" in app_editor and "return NO;" in method_body(app_editor, "- (BOOL)saveVersion:", 4500),
        "App Version save reports authoritative write failure")
require("- (BOOL)persistToggle:" in app_editor and "return NO;" in method_body(app_editor, "- (BOOL)persistToggle:", 2600),
        "App Version per-app toggle reports write failure")
save_tapped = method_body(app_editor, "- (void)saveTapped", 1800)
require("if (![self saveVersion:version build:build])" in save_tapped and "reloadFromPlist" in save_tapped,
        "App Version save UI reloads persisted truth on failure")
per_app_toggle = method_body(app_editor, "- (void)perAppToggleChanged:", 1300)
require("if (![self persistToggle:enabled])" in per_app_toggle and "[sender setOn:!enabled" in per_app_toggle,
        "App Version per-app switch rolls back on failure")
app_list_appear = method_body(app_list, "- (void)viewWillAppear:(BOOL)animated", 900)
require('PXReadSecurityBool(@"appVersionSpoofingEnabled", NO)' in app_list_appear and
        "[self.mainSwitch setOn:enabled" in app_list_appear,
        "App Version list refreshes master switch on return")
app_enabled_state = method_body(app_list, "- (void)updateEnabledState", 900)
require("self.appsCard.userInteractionEnabled = on" in app_enabled_state and "self.addButton.enabled = on" in app_enabled_state,
        "App Version child actions are disabled while master is off")

# Device-specific identifier state: UI callers use verified API; primary + secondary failures roll back.
require("setIdentifierEnabledAndPersist" in tlink_h and '"TLinkIOS.h"' in identifier_h,
        "IdentifierManager verified identifier-toggle API is exported through the shared header")
verified_identifier = method_body(identifier_m, "- (BOOL)setIdentifierEnabledAndPersist:", 4300)
for token in (
    "primarySuccess",
    "secondarySuccess",
    "self.settings[type] = @(previous)",
    "PXWriteSecurityBool(secondaryKey, previous",
    "return NO;",
):
    require(token in verified_identifier, f"Identifier verified setter contains {token}")
require("setIdentifierEnabledAndPersist:enabled forType:key" in device_ui,
        "Device-specific screen uses verified identifier setter")
legacy_switch = method_body(legacy_ui, "- (void)identifierSwitchChanged:", 1800)
require("setIdentifierEnabledAndPersist:requestedState" in legacy_switch,
        "legacy identifier switch also uses verified setter")
require("setIdentifierEnabled:sender.isOn" not in legacy_ui,
        "legacy identifier UI no longer bypasses verified setter")

# iOS 12 compatibility contract: modern API tokens must be isolated behind runtime helpers.
for symbol in (
    "PXLabelColor",
    "PXSecondaryLabelColor",
    "PXSeparatorColor",
    "PXSystemBackgroundColor",
    "PXMediumActivityIndicatorStyle",
    "PXInsetGroupedTableViewStyle",
    "PXDynamicColor",
    "PXApplicationWindows",
    "PXKeyWindow",
):
    require(symbol in uikit_h and symbol in uikit_m, f"UIKit compat implements {symbol}")
require("respondsToSelector" in uikit_m and "NSClassFromString" in uikit_m,
        "UIKit compatibility is based on runtime capability checks")
require('NSClassFromString(@"NSRelativeDateTimeFormatter")' in rrs_ui and
        "if (@available(iOS 13.0, *)) {\n        NSRelativeDateTimeFormatter" not in rrs_ui,
        "RRS relative-date formatter uses runtime class detection")
require('NSSelectorFromString(@"searchTextField")' in legacy_ui and
        "self.appSearchBar.searchTextField" not in legacy_ui,
        "UISearchBar searchTextField access is runtime-gated")
optional_dir_gate = method_body(jailbreak_hook, "static BOOL PXJBOptionalDirectoryEntryHooksSupported", 700)
require("isOperatingSystemAtLeastVersion" in optional_dir_gate and "@available" not in optional_dir_gate,
        "Jailbreak optional directory hooks use runtime OS version detection")

source_files = list(ROOT.glob("*.m")) + list((ROOT / "common").glob("*.m")) + list((ROOT / "TLinkIOSTweak").glob("*.x"))
compat_path = (ROOT / "common/PXUIKitCompat.m").resolve()
forbidden = (
    re.compile(r"\[UIColor\s+(?:labelColor|secondaryLabelColor|tertiaryLabelColor|separatorColor|systemBackgroundColor|secondarySystemBackgroundColor|tertiarySystemBackgroundColor|secondarySystemGroupedBackgroundColor|tertiarySystemGroupedBackgroundColor|systemFillColor|secondarySystemFillColor|tertiarySystemFillColor)\]"),
    re.compile(r"\.connectedScenes\b"),
    re.compile(r"\[UIImage\s+systemImageNamed:"),
    re.compile(r"\bselectedSegmentTintColor\b"),
)
violations = []
for path in source_files:
    if path.resolve() == compat_path:
        continue
    text = path.read_text(encoding="utf-8")
    for pattern in forbidden:
        match = pattern.search(text)
        if match:
            line = text.count("\n", 0, match.start()) + 1
            violations.append(f"{path.relative_to(ROOT)}:{line}: {match.group(0)}")
require(not violations, "no direct audited iOS 13 semantic/Scene API usage outside compatibility layer" +
        ("; " + "; ".join(violations) if violations else ""))

# Inset grouped and Medium spinner enums are allowed only inside the compatibility implementation.
for token in ("UITableViewStyleInsetGrouped", "UIActivityIndicatorViewStyleMedium"):
    offenders = []
    for path in source_files:
        if path.resolve() == compat_path:
            continue
        text = path.read_text(encoding="utf-8")
        if token in text:
            offenders.append(str(path.relative_to(ROOT)))
    require(not offenders, f"{token} is isolated to PXUIKitCompat" + (f": {offenders}" if offenders else ""))

print("security UI/runtime/iOS12 static contract: PASS")
