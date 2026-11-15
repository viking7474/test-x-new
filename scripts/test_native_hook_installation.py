#!/usr/bin/env python3
"""Native installation reentry, metadata and loader boundaries; macOS required."""
from pathlib import Path
import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from test_runtime_identifier_writers import method
from test_profile_creation_flow import check_macro_arity

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'TLinkIOSTweak/PXNativeHookCoordinator.m'
CASES = ['success', 'engine-late', 'missing-symbol', 'hook-throws', 'metadata-throws',
         'loader-throws', 'lookup-throws', 'logging-throws', 'concurrent', 'names', 'null-original']
SYMBOLS = ['Sysctl', 'SysctlByname', 'SysctlNameToMIB', 'Gethostname', 'Getifaddrs', 'Gethostuuid',
           'Statfs', 'Statfs64', 'Getfsstat', 'Getfsstat64', 'IORegistryEntryCreateCFProperty',
           'IORegistryEntryCreateCFProperties', 'IORegistryEntrySearchCFProperty',
           'CFCopySystemVersionDictionary', 'CNCopyCurrentNetworkInfo']


def source_contracts(source=None):
    s = SOURCE.read_text(encoding='utf-8') if source is None else source
    install = method(s, '- (void)installOwnedSymbolsIfNeeded')
    assert install.index('if (previous) return;') < install.index('dlsym(RTLD_DEFAULT, "MSHookFunction")') < install.index('dispatch_once(&onceToken, installation)')
    assert 'gPXInsideNativeInstallPass = previous; owner = nil;' in install
    bindings = re.findall(r'_installSymbol:kPXNativeSymbol(\w+)', install)
    assert bindings == SYMBOLS
    assert 'installation = ^{' in install and 'installation = nil;' in install
    assert '@catch (__unused NSException *exception) { }' in install
    helper = method(s, '- (BOOL)_installSymbol:(NSString *)symbolName replace:(void *)replace originalOut:(void **)originalOut')
    assert helper.count('MSHookFunction(address, replace, originalOut);') == 1
    assert helper.index('MSHookFunction(address') < helper.index('[self _markInstalled:symbol original:*originalOut]')
    assert 'os_unfair_lock_lock' not in helper and 'dispatch_once' not in helper
    assert 'if (!symbol || !replace || !originalOut) return NO;' in helper
    assert '@catch' in helper and 'symbolName = nil; symbol = nil; metadata = nil; owner = nil;' in helper
    capture = method(s, '- (PXNativeInstallMetadata *)_captureInstallationMetadata')
    assert 'metadata = _installationMetadata;' in capture and '@finally { os_unfair_lock_unlock(&_lock); }' in capture
    mark = method(s, '- (void)_markInstalled:(NSString *)symbol original:(void *)orig')
    assert '[basis.installed containsObject:symbol]' in mark and 'counts[symbol] = @1;' in mark
    assert 'candidate.installed = installed; candidate.counts = counts; candidate.originals = originals;' in mark
    pub = mark.split('os_unfair_lock_lock(&_lock);', 1)[1].split('os_unfair_lock_unlock(&_lock);', 1)[0]
    assert '_installationMetadata == basis' in pub and 'retired = _installationMetadata; _installationMetadata = candidate;' in pub
    assert 'copy]' not in pub and 'MSHookFunction' not in pub and 'PXLog' not in pub
    assert mark.index('retired = nil; basis = nil; candidate = nil;') > mark.index('os_unfair_lock_unlock(&_lock);')
    canon = method(s, 'static NSString *PXNativeCanonicalSymbol(NSString *symbol)')
    assert canon.index('gPXReadingNativeSymbol = YES;') < canon.index('if (symbol == kPXNativeSymbolSysctl') < canon.index('[[NSString alloc] initWithString:symbol]')
    assert 'gPXReadingNativeSymbol = previous; symbol = nil; frozen = nil;' in canon and '@catch' in canon
    for sig in ['- (BOOL)isSymbolInstalled:(NSString *)symbolName', '- (void *)originalForSymbol:(NSString *)symbolName']:
        body = method(s, sig)
        assert 'os_unfair_lock_lock' not in body and 'PXNativeCanonicalSymbol(symbolName)' in body
        assert 'objc_precise_lifetime' in body and '@finally' in body
    image = method(s, 'static void *PXNativeInstallImage(NSUInteger index)')
    assert 'static void *handles[5];' in image and 'static dispatch_once_t tokens[5];' in image
    assert 'if (index >= 5) return NULL;' in image and 'RTLD_NOLOAD | RTLD_LAZY' in image
    assert '@catch (__unused NSException *exception) { handles[index] = NULL; }' in image
    resolve = method(s, 'static void *PXNativeResolveInstallSymbol(NSString *symbol)')
    for index in [2, 3, 4]: assert f'PXNativeInstallImage({index})' in resolve
    assert resolve.index('dlsym(handle, "CFCopySystemVersionDictionary")') < resolve.index('dlsym(handle, "_CFCopySystemVersionDictionary")')
    assert 'for (NSUInteger index = 0; index < 2; index++)' in resolve
    assert 'dlopen(' not in resolve and 'symbol = nil;' in resolve
    report = method(s, 'static void PXNativeInstallReport(NSString *symbol, NSString *reason, void *original)')
    assert '@catch' in report and 'symbol = nil; reason = nil;' in report
    diag = method(s, '- (NSDictionary *)diagnostics')
    assert 'metadata = [self _captureInstallationMetadata];' in diag and 'os_unfair_lock' not in diag
    assert '_installedSymbols' not in s and '_originalPointers' not in s and '_installCounts' not in s
    check_macro_arity((ROOT / 'tests/PXNativeHookInstallationTests.m').read_text(encoding='utf-8'), 'native-installation')
    assert 'scripts/test_native_hook_installation.py --native' in (ROOT / '.github/workflows/build-ios-arm.yml').read_text()
    assert 'scripts/test_native_hook_installation.py' in (ROOT / 'scripts/release_hardening.py').read_text()
    print('PASS: Native installation/metadata/loader source contracts (native patching not implied)')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-native-install-') as temp:
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            for mode, flag in (('plain-arc', '-fno-objc-arc-exceptions'), ('arc-eh', '-fobjc-arc-exceptions')):
                binary = Path(temp) / (scheme + '-' + mode)
                subprocess.run(['xcrun', 'clang', '-O0', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions', flag,
                                '-Wall', '-Wextra', '-Werror=implicit-function-declaration', *defines,
                                '-I', str(ROOT / 'common'), '-I', str(ROOT / 'TLinkIOSTweak'),
                                str(ROOT / 'tests/PXNativeHookInstallationTests.m'), str(ROOT / 'common/PXRuntimeReadScope.m'),
                                '-framework', 'Foundation', '-framework', 'CoreFoundation', '-o', str(binary)],
                               cwd=ROOT, check=True, timeout=60)
                # Fresh processes preserve real dispatch_once semantics for each scenario.
                for case in CASES:
                    print('Native installation matrix:', scheme, mode, case, flush=True)
                    subprocess.run([str(binary), case], cwd=ROOT, check=True, timeout=60)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        native_tests()
