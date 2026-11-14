#!/usr/bin/env python3
"""SystemVersion file/CF/bundle boundaries and real shared transformer."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys
import tempfile
from test_runtime_identifier_writers import method
from test_profile_creation_flow import check_macro_arity
ROOT = Path(__file__).resolve().parents[1]
READ = lambda p: (ROOT / p).read_text(encoding='utf-8')
IOS = 'TLinkIOSTweak/IOSVersionHooks.x'
FILES = [
    'NSData *replaced_NSData_dataWithContentsOfFile(Class self, SEL _cmd, NSString *path)',
    'NSDictionary *replaced_NSDictionary_dictionaryWithContentsOfFile(Class self, SEL _cmd, NSString *path)',
    'id replaced_NSString_stringWithContentsOfFile(Class self, SEL _cmd, NSString *path,\n                                               NSStringEncoding encoding, NSError **error)']
CFGET = 'CFTypeRef replaced_CFBundleGetValueForInfoDictionaryKey(CFBundleRef bundle, CFStringRef key)'
OBJ = '- (id)objectForInfoDictionaryKey:(NSString *)key'
CF = 'CFDictionaryRef replaced_CFCopySystemVersionDictionary(void)'
TWEAKCF = 'static CFDictionaryRef CFCopySystemVersionDictionary_hook(void)'


def source_contracts(s=None):
    s = READ(IOS) if s is None else s
    for sig in FILES:
        body = method(s, sig)
        assert body.index(' = original_NS') < body.index('@catch')
        assert 'PXSystemVersionProjectionActive()' in body
        assert 'PXSystemVersionProjectionLeave(previous);' in body
        assert '@finally { path = nil;' in body
    for body in (method(s, CF), method(READ('TLinkIOSTweak/Tweak.x'), TWEAKCF)):
        name = 'original_CFCopySystemVersionDictionary' if 'original_CFCopySystemVersionDictionary' in body else 'CFCopySystemVersionDictionary_orig'
        native_call = body.index('original = ' + name + ' ?')
        assert body.count(name + '()') == 1
        assert native_call < body.index('BOOL previous = PXSystemVersionProjectionEnter();')
        assert native_call < body.index('@catch')
        assert native_call < body.index('@autoreleasepool')
        assert 'CFDictionaryRef retired = original; original = result;' in body and 'if (retired) CFRelease(retired);' in body
        assert 'PXSystemVersionProjectionLeave(previous)' in body and 'transformed = nil;' in body
    obj = method(s, OBJ); cf = method(s, CFGET)
    assert 'gPXInsideIOSVersionCFBundleInfoHook' in obj and 'gPXInsideIOSVersionBundleInfoHook' in cf
    assert obj.index('if (!relevant') < obj.index('PX_RUNTIME_READ_OPERATION;')
    assert 'if (projectedValue) return projectedValue;' in obj
    assert 'NSString *__autoreleasing spoofVer = nil;' in obj and 'NSString *__autoreleasing spoofBuild = nil;' in cf
    assert 'gPXIOSVersionMainBundleID' in obj and 'gPXIOSVersionMainBundleID' in cf
    assert cf.index('if (original_CFBundleGetValueForInfoDictionaryKey) return') > cf.index('@finally { gPXInsideIOSVersionCFBundleInfoHook = previous; }')
    assert 'actualVersion = PXRealRuntimeIOSVersion();' in cf
    assert '__attribute__((objc_precise_lifetime)) id retainedKey = nil;' in cf
    assert 'retainedKey = (__bridge id)key;' in cf and 'retainedKey = nil;' in cf
    intern = method(s, 'static CFStringRef PXIOSVersionBorrowedInfoString(NSString *value)')
    assert 'gPXInterningInfoString = previous;' in intern
    assert 'gPXBorrowedInfoStrings == basis' in intern and 'retired = nil;' in intern
    assert 'frozen = [value copy];' in intern and 'stored = basis[frozen];' in intern
    assert 'dispatch_once' not in intern
    for part in intern.split('os_unfair_lock_lock(&gPXBorrowedInfoLock);')[1:]:
        locked = part.split('os_unfair_lock_unlock(&gPXBorrowedInfoLock);', 1)[0]
        assert '[' not in locked and ' copy' not in locked
    common = READ('common/PXSystemVersionTransformer.m')
    for sig in ('PXSystemVersionProjection *PXSystemVersionProjectionFromSnapshot(PXIdentitySnapshot *snapshot)',
                'PXSystemVersionProjection *PXCurrentReportingSystemVersionProjectionForBundle(NSString *bundleID)',
                'PXSystemVersionProjection *PXCurrentNativeSafeSystemVersionProjection(void)',
                'BOOL PXIsSystemVersionPlistPath(NSString *path)'):
        assert '@finally' in method(common, sig)
    assert 'version = projection.productVersion; build = projection.productBuildVersion; release = projection.releaseType;' in common
    assert 'gPXSystemVersionProjectionActive = previous;' in common
    assert 'static __thread BOOL gPXSystemVersionProjectionActive;' in common
    assert 'scripts/test_system_version_boundaries.py --native' in READ('.github/workflows/build-ios-arm.yml')
    assert 'scripts/test_system_version_boundaries.py' in READ('scripts/release_hardening.py')
    check_macro_arity(READ('tests/PXSystemVersionBoundaryTests.m'), 'system-version-boundaries')
    print('PASS: SystemVersion boundary/ownership/cache source contracts (native platform behavior not implied)')


def generate_native_fragments(folder):
    s = READ(IOS)
    intern = s.split('static os_unfair_lock gPXBorrowedInfoLock', 1)[1].split('// Replacement function for CFBundle', 1)[0]
    intern = 'static os_unfair_lock gPXBorrowedInfoLock' + intern
    helpers = ['static BOOL isSystemVersionFile(NSString *path)', 'static PXSystemVersionProjection *PXScopedSystemVersionProjection(void)', 'static NSDictionary *spoofSystemVersionPlist(NSDictionary *originalPlist)']
    work = '\n\n'.join(method(s, sig) for sig in helpers + FILES + [CF, CFGET])
    work += '\n' + method(READ('TLinkIOSTweak/Tweak.x'), TWEAKCF)
    def providers(text):
        for before, after in (('[[NSBundle mainBundle] bundleIdentifier]', 'PXFixtureBundleID()'),
                              ('[NSProcessInfo processInfo].processName', 'PXFixtureProcess()'),
                              ('[NSBundle mainBundle]', 'PXFixtureMainBundle()'),
                              ('CFBundleGetMainBundle()', 'PXFixtureCFMainBundle()'),
                              ('%c(IdentifierManager)', 'PXFixtureManagerClass()')):
            text = text.replace(before, after)
        return text
    (folder / 'PXSystemReadWork.inc').write_text(providers(intern + '\n' + work), encoding='utf-8')
    obj = method(s, OBJ).replace('%orig(key)', 'PXOriginalObjCInfo(self, key)')
    (folder / 'PXBundleInfoMethod.inc').write_text(providers(obj), encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-system-version-boundaries-') as temp:
        folder = Path(temp); generate_native_fragments(folder)
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            for mode, flag in (('plain-arc', '-fno-objc-arc-exceptions'), ('arc-eh', '-fobjc-arc-exceptions')):
                binary = folder / (scheme + '-' + mode)
                print('SystemVersion boundaries native matrix:', scheme, mode, flush=True)
                subprocess.run(['xcrun', 'clang', '-O0', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions', flag,
                                '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(folder), '-I', str(ROOT / 'common'),
                                '-I', str(ROOT / 'TLinkIOSTweak'), *defines,
                                str(ROOT / 'common/PXSystemVersionTransformer.m'), str(ROOT / 'common/PXDeviceProfileSchema.m'),
                                str(ROOT / 'tests/PXSystemVersionTransformerTests.m'), str(ROOT / 'tests/PXSystemVersionBoundaryTests.m'),
                                '-framework', 'Foundation', '-framework', 'CoreFoundation', '-o', str(binary)], cwd=ROOT, check=True, timeout=60)
                subprocess.run([str(binary)], cwd=ROOT, check=True, timeout=60)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--native', action='store_true'); args = parser.parse_args()
    source_contracts()
    if args.native: native_tests()
