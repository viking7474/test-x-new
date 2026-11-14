#!/usr/bin/env python3
"""UA policy/main-thread sync source contracts; native Foundation facades require macOS."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys
import tempfile
from test_runtime_identifier_writers import method
from test_profile_creation_flow import check_macro_arity

ROOT = Path(__file__).resolve().parents[1]
HOOK = ROOT / 'TLinkIOSTweak/IOSVersionHooks.x'


def regions(source):
    debug = source.split('typedef struct {\n    BOOL masterEnabled;', 1)[1].split('} PXUADebugSettings;', 1)[0]
    policy = source.split('#pragma mark - UA policy packet\n', 1)[1].split('#pragma mark - End UA policy packet', 1)[0]
    sync = source.split('#pragma mark - UA sync pipeline\n', 1)[1].split('#pragma mark - End UA sync pipeline', 1)[0]
    return 'typedef struct {\n    BOOL masterEnabled;' + debug + '} PXUADebugSettings;\n' + policy, sync


def source_contracts(source=None):
    s = HOOK.read_text(encoding='utf-8') if source is None else source
    policy, sync = regions(s)
    for retired in ('gUADebug.', 'PXSecuritySettingBoolDefault', 'PXUADebugEnsure', 'gUAMobileBuildValid',
                    'gUASyncEnabledValid', 'NSPointerArray', 'gWKWebViewsQueue', 'gUAByHost', 'gUASyncLastUA',
                    'PXUASyncLookupHostUA', 'PXUASyncUnregisterWKWebView', 'PXUASyncRememberHostUA'):
        assert retired not in s, retired
    assert 'PXUAPolicyValues debug' not in policy
    assert 'gUAPolicyEpoch++; gUAPolicyRevision++; gUAPolicyValid = NO;' in policy
    assert 'epoch != gUAPolicyEpoch' in policy and 'revision == gUAPolicyRevision' in policy
    assert 'PXIOSVersionTimeIsFresh(now, gUAPolicyLoadedAt, gUAPolicyValid, 1.0)' in policy
    assert 'if (gUALoadingPolicy) return values;' in policy and 'gUALoadingPolicy = NO;' in policy
    for chunk in policy.split('os_unfair_lock_lock(&gUAPolicyLock);')[1:]:
        locked = chunk.split('os_unfair_lock_unlock(&gUAPolicyLock);', 1)[0]
        assert '[' not in locked and 'dispatch_' not in locked
    current = method(s, 'static PXUAPolicyValues PXUACurrentPolicy(void)')
    root = current.split('#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)', 2)[2].split('#else', 1)[0]
    assert 'view.valid ? view.securitySettings : nil' in root and 'PXUABuildPolicy(settings, nil)' in root
    assert 'objc_getAssociatedObject(view, &kPXRuntimeUAPolicy)' in root
    assert 'PXIOSVersionCacheTime' not in root and 'initWithSuiteName' not in root and 'PXReadSecuritySettingsDict' not in root
    assert policy.count('dictionaryWithContentsOfFile:') == 2
    assert 'isKindOfClass:NSNumber.class' in policy and 'isKindOfClass:NSString.class' in policy
    assert 'if (!value) value = [defaults objectForKey:key];' in policy
    assert 'NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality' in sync
    assert '__weak WKWebView *weakView = webView' in sync and 'owner = weakView;' in sync
    assert 'if ([NSThread isMainThread]) operation();' in sync
    apply = method(s, 'static void PXUASyncApplyToWebViewsForHost(NSString *host, NSString *ua, uint64_t epoch)')
    assert 'lowerHost = host.lowercaseString; frozenHost = [lowerHost copy]; frozenUA = [ua copy];' in apply
    assert 'dispatch_async(dispatch_get_main_queue(), operation);' in apply
    assert apply.index('operation = ^{') < apply.index('targets = gWKWebViews.allObjects;')
    assert 'PX_RUNTIME_READ_OPERATION;' in apply and '!policy.syncEnabled || epoch != PXUASyncEpoch()' in apply
    per_view = method(s, 'static void PXUASyncApplyToView(WKWebView *view, NSString *host, NSString *ua, PXUAPolicyValues policy, uint64_t epoch)')
    assert '[NSThread isMainThread]' in per_view and 'gUASyncApplying = previous;' in per_view
    assert per_view.count('PXUASyncViewMatches(view, host, policy.applyAll)') == 2
    assert per_view.count('epoch != PXUASyncEpoch()') == 2 and 'epoch == PXUASyncEpoch()' in per_view
    script = method(s, 'static NSString *PXUASyncScript(NSString *ua)')
    assert 'NSJSONSerialization dataWithJSONObject:packet' in script
    assert 'withString:@"\\\\u2028"' in script and 'withString:@"\\\\u2029"' in script
    canonical = method(s, 'static void PXUASetExactCustomUserAgent(WKWebView *webView, NSString *userAgent, BOOL owned)')
    assert 'BOOL previous = gUACanonicalApplying;' in canonical and 'gUACanonicalApplying = previous;' in canonical
    init = method(s, '- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration')
    assert 'PXUASyncRegisterWKWebView(webView);' in init and 'PXUASyncHeaderAndJSEnabled' not in init
    header = method(s, '- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field')
    prepared = method(s, 'static NSString *PXUAPrepareRequestHeader(NSMutableURLRequest *request, NSString *value, NSString *field,\n                                        PXUAHeaderKind kind, NSString *__strong *syncHost,\n                                        NSString *__strong *syncUA, uint64_t *epoch)')
    assert prepared.index('PXUASyncEpoch()') < prepared.index('BOOL syncEnabled =')
    assert '*epoch = syncEpoch;' in prepared
    assert 'PXUASyncApplyToWebViewsForHost(host, modifiedValue, syncEpoch);' in header
    assert header.index('%orig(candidate ?: value, field);') < header.index('PXUASyncApplyToWebViewsForHost')
    settings = method(s, 'static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)')
    assert settings.count('PXUAPolicyInvalidate();') == 1
    assert 'scripts/test_ua_policy_and_sync.py --native' in (ROOT / '.github/workflows/build-ios-arm.yml').read_text()
    assert 'scripts/test_ua_policy_and_sync.py' in (ROOT / 'scripts/release_hardening.py').read_text()
    check_macro_arity((ROOT / 'tests/PXUAPolicySyncTests.m').read_text(encoding='utf-8'), 'ua-policy-sync')
    print('PASS: UA policy/main-thread sync source contracts (native WebKit/device behavior not implied)')


def generate_native_fragments(folder):
    s = HOOK.read_text(encoding='utf-8')
    policy, sync = regions(s)
    # Dependency substitution only: keep real packet, cache, builder and sync bodies.
    policy = policy.replace('[NSDictionary dictionaryWithContentsOfFile:', 'PXFixtureRead(')
    policy = policy.replace('com.weaponx.securitySettings.plist"];', 'com.weaponx.securitySettings.plist");')
    assert policy.count('PXFixtureRead(') == 2
    policy = policy.replace('NSUserDefaults', 'PXFixtureDefaults')
    fresh = method(s, 'static BOOL PXIOSVersionTimeIsFresh(double now, double loadedAt, BOOL valid, double ttl)')
    (folder / 'PXUAPolicy.inc').write_text(fresh + '\n' + policy, encoding='utf-8')
    (folder / 'PXUASync.inc').write_text(sync, encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-ua-policy-sync-') as temp:
        folder = Path(temp); generate_native_fragments(folder)
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            for mode, flag in (('plain-arc', '-fno-objc-arc-exceptions'), ('arc-eh', '-fobjc-arc-exceptions')):
                binary = folder / (scheme + '-' + mode)
                print('UA policy/sync native matrix:', scheme, mode, flush=True)
                subprocess.run(['xcrun', 'clang', '-O0', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions', flag,
                                '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(folder), *defines,
                                str(ROOT / 'tests/PXUAPolicySyncTests.m'), '-framework', 'Foundation', '-framework', 'CoreFoundation',
                                '-o', str(binary)], cwd=ROOT, check=True, timeout=60)
                subprocess.run([str(binary)], cwd=ROOT, check=True, timeout=60)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--native', action='store_true'); args = parser.parse_args()
    source_contracts()
    if args.native: native_tests()
