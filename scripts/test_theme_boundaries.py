#!/usr/bin/env python3
"""Theme scalar cache and six UIKit/WebKit boundaries; native needs macOS."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys
import tempfile
from test_runtime_identifier_writers import method
from test_profile_creation_flow import check_macro_arity

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'TLinkIOSTweak/ThemeHooks.x'
ADAPTERS = [
    ('ThemeStyleGetter', '- (UIUserInterfaceStyle)userInterfaceStyle', 'PXFixtureScalarGetter', 'UIUserInterfaceStyle', 'PXNativeStyle(self, 0)'),
    ('ThemeEffectiveGetter', '- (UIUserInterfaceStyle)effectiveUserInterfaceStyle', 'PXFixtureEffectiveGetter', 'UIUserInterfaceStyle', 'PXNativeStyle(self, 1)'),
    ('ThemeScreenTraits', '- (UITraitCollection *)traitCollection', 'PXFixtureScreenTraits', 'UITraitCollection *', 'PXNativeTraits(self, 2)'),
    ('ThemeViewTraits', '- (UITraitCollection *)traitCollection', 'PXFixtureViewTraits', 'UITraitCollection *', 'PXNativeTraits(self, 3)'),
    ('ThemeControllerTraits', '- (UITraitCollection *)traitCollection', 'PXFixtureControllerTraits', 'UITraitCollection *', 'PXNativeTraits(self, 4)'),
    ('ThemeWebKitScheme', '- (void)_setPreferredColorScheme:(NSInteger)colorScheme', 'PXFixtureSetScheme', 'void', 'PXNativeScheme(self, resolved)'),
]


def source_contracts(source=None):
    s = SOURCE.read_text(encoding='utf-8') if source is None else source
    assert 'NSDate' not in s and 'cachedThemeValue' not in s and 'cacheTimestamp' not in s
    begin = method(s, 'static BOOL PXThemeCacheBegin(double now, WeaponXThemeStyle *style, uint64_t *ticket)')
    assert 'now >= gThemeLoadedAt' in begin and 'now - gThemeLoadedAt <= kCacheValidityDuration' in begin
    assert '*ticket = ++gThemeCacheGeneration;' in begin and 'gThemeCacheValid = NO;' in begin
    publish = method(s, 'static BOOL PXThemeCachePublish(uint64_t ticket, double now, WeaponXThemeStyle style)')
    assert 'ticket == gThemeCacheGeneration' in publish and 'isfinite(now)' in publish
    invalidate = method(s, 'static void PXThemeInvalidateCache(void)')
    assert '++gThemeCacheGeneration; gThemeCacheValid = NO;' in invalidate
    for body in [begin, publish, invalidate]:
        locked = body.split('os_unfair_lock_lock(&gThemeCacheLock);', 1)[1].split('os_unfair_lock_unlock', 1)[0]
        assert '[' not in locked and 'PXLog' not in locked
    read = method(s, 'static WeaponXThemeStyle getThemeStyleFromProfile(void)')
    assert read.count('PXCaptureRuntimeSnapshot()') == 1 and read.count('PXActiveProfileIdentityPath()') == 1
    assert 'PXActiveProfileDeviceIDsPath()' not in read and '[runtimeView profileArtifact:@"deviceTheme"]' in read
    assert 'if (!PXThemeCachePublish(ticket, now, style)) return WeaponXThemeStyleUnspecified;' in read
    assert 'if (!themeValue) themeValue = @"Light";' in read and 'raw = nil;' in read
    assert 'isInScopedAppsList' not in s and 'loadScopedApps' not in s
    resolve = method(s, 'static WeaponXThemeStyle PXThemeResolveOverride(NSString *__strong *bundleOut)')
    assert 'if (previous || gPXThemeBypass)' in resolve and 'gPXThemePreparing = previous;' in resolve
    assert '@catch' in resolve
    project = method(s, 'static UITraitCollection *PXThemeProjectTraits(UITraitCollection *original)')
    assert 'if (!original || previous || bypass || !gPXThemeTraitFactoriesAvailable) return original;' in project
    assert project.index('gPXThemeBypass = YES;') < project.index('original.userInterfaceStyle == style') < project.index('traitCollectionWithUserInterfaceStyle:')
    assert 'if (!styleTrait) return original;' in project and 'return merged ?: original;' in project
    assert 'gPXThemePreparing = previous; gPXThemeBypass = bypass;' in project and 'inputs = nil;' in project
    assert 'PXThemeMethodSupported' in s and 'signature.numberOfArguments == (argument ? 3u : 2u)' in s
    for group, signature, *_ in ADAPTERS:
        body = method(s.split('%group ' + group, 1)[1], signature)
        assert 'objc_precise_lifetime' in body and '@finally' in body and body.count('%orig') == 1
        assert f'%init({group});' in s
    notification = method(s, 'static void themeSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)')
    assert notification.index('PXThemeInvalidateCache();') < notification.index('PXInvalidateScopeDecisionCache();') < notification.index('PXLog(')
    assert '@autoreleasepool' in notification and notification.count('@catch') == 2
    ctor = s.split('%ctor {', 1)[1]
    assert ctor.index('PXBootstrapAllows(PXHookCapabilityNative)') < ctor.index('PXThemeMethodSupported')
    assert ctor.count('CFNotificationCenterAddObserver(') == 4 and '%init(ThemeHooks)' not in ctor
    assert 'PXLog(' not in ctor and '@finally { bundleID = nil; process = nil; }' in ctor
    assert 'NSSelectorFromString(@"effectiveUserInterfaceStyle")' in ctor and 'NSSelectorFromString(@"_setPreferredColorScheme:")' in ctor
    check_macro_arity((ROOT / 'tests/PXThemeBoundaryTests.m').read_text(encoding='utf-8'), 'theme-boundary')
    assert 'scripts/test_theme_boundaries.py --native' in (ROOT / '.github/workflows/build-ios-arm.yml').read_text()
    assert 'scripts/test_theme_boundaries.py' in (ROOT / 'scripts/release_hardening.py').read_text()
    print('PASS: Theme cache/six adapter/capability source contracts (UIKit/device behavior not implied)')


def generate_native_fragments(folder):
    s = SOURCE.read_text(encoding='utf-8')
    state = s[s.index('// Scalar cache state'):s.index('static double PXThemeMonotonicNow')]
    helpers = s[s.index('static double PXThemeMonotonicNow'):s.index('%group ThemeStyleGetter')]
    helpers = helpers.replace('clock_gettime(CLOCK_MONOTONIC, &ts)', 'PXFixtureThemeClock(CLOCK_MONOTONIC, &ts)')
    helpers = helpers.replace('[NSBundle mainBundle]', 'PXFixtureMainBundle()').replace('[NSProcessInfo processInfo].processName', 'PXFixtureProcessName()')
    helpers = helpers.replace('[NSDictionary dictionaryWithContentsOfFile:', 'PXFixtureThemeFile(')
    # Only the two file-provider call expressions are changed; all theme work is exact.
    helpers = helpers.replace('PXFixtureThemeFile(deviceIDsPath]', 'PXFixtureThemeFile(deviceIDsPath)')
    helpers = helpers.replace('PXFixtureThemeFile([identityPath stringByAppendingPathComponent:@"device_theme.plist"]]', 'PXFixtureThemeFile([identityPath stringByAppendingPathComponent:@"device_theme.plist"])')
    (folder / 'PXThemeState.inc').write_text(state, encoding='utf-8')
    notification = method(s, 'static void themeSettingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)')
    (folder / 'PXThemeWork.inc').write_text(helpers + notification, encoding='utf-8')
    adapters = []
    for group, signature, name, result, original in ADAPTERS:
        body = method(s.split('%group ' + group, 1)[1], signature)
        args = 'id __unsafe_unretained self' + (', NSInteger colorScheme' if name == 'PXFixtureSetScheme' else '')
        body = body.replace(signature, f'static {result} {name}({args})', 1)
        body = body.replace('%orig(resolved)', original).replace('%orig', original)
        body = body.replace('@available(iOS 17.0, *)', 'gPXFixtureIOS17')
        adapters.append(body)
    (folder / 'PXThemeAdapters.inc').write_text('\n\n'.join(adapters), encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-theme-boundaries-') as tmp:
        folder = Path(tmp)
        generate_native_fragments(folder)
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            for mode, flag in (('plain-arc', '-fno-objc-arc-exceptions'), ('arc-eh', '-fobjc-arc-exceptions')):
                binary = folder / (scheme + '-' + mode)
                print('Theme boundary native matrix:', scheme, mode, flush=True)
                subprocess.run(['xcrun', 'clang', '-O0', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions', flag,
                                '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(ROOT / 'common'), '-I', str(folder), *defines,
                                str(ROOT / 'tests/PXThemeBoundaryTests.m'), str(ROOT / 'common/PXRuntimeReadScope.m'),
                                '-framework', 'Foundation', '-framework', 'CoreFoundation', '-o', str(binary)], cwd=ROOT, check=True, timeout=60)
                subprocess.run([str(binary)], cwd=ROOT, check=True, timeout=90)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        native_tests()
