#!/usr/bin/env python3
"""Real native coordinator registry/dispatch tests; --native requires macOS."""
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


def source_contracts(source=None):
    s = SOURCE.read_text(encoding='utf-8') if source is None else source
    capture = method(s, '- (PXNativeProviderState *)_captureProviderState')
    assert '@finally { os_unfair_lock_unlock(&_registryLock); }' in capture
    assert 'state = _providerState;' in capture
    register = method(s, '- (BOOL)registerProviderID:(NSString *)providerID\n                symbolName:(NSString *)symbolName\n                  priority:(NSInteger)priority\n                  preBlock:(id)preBlock\n                 postBlock:(id)postBlock')
    assert register.index('gPXPreparingNativeProvider = YES;') < register.index('[providerID isKindOfClass:NSString.class]')
    assert 'objc_precise_lifetime' in register and 'owner = nil;' in register
    assert 'gPXPreparingNativeProvider = previous;' in register
    assert '[[NSString alloc] initWithString:providerID]' in register and '[[NSString alloc] initWithString:symbolName]' in register
    assert '[basis.providerIDs containsObject:frozenID]' in register
    assert 'lists[frozenSymbol] = [list copy];' in register
    assert 'if (a.priority < b.priority) return NSOrderedAscending;' in register
    assert 'if (a.priority > b.priority) return NSOrderedDescending;' in register
    assert 'return [a.providerID compare:b.providerID];' in register
    assert 'candidate.providers = lists; candidate.providerIDs = ids;' in register
    publication = register.split('os_unfair_lock_lock(&_registryLock);', 1)[1].split('os_unfair_lock_unlock(&_registryLock);', 1)[0]
    assert '_providerState == basis' in publication and 'retired = _providerState; _providerState = candidate;' in publication
    assert 'sortUsing' not in publication and 'copy]' not in publication and 'PXLog' not in publication
    assert register.index('retired = nil; candidate = nil; basis = nil;') > register.index('os_unfair_lock_unlock(&_registryLock);')
    reader = method(s, '- (NSArray<PXNativeHookProvider *> *)_providersCopyForSymbol:(NSString *)symbol')
    assert 'list = state.providers[symbol] ?: @[];' in reader and ' copy]' not in reader
    assert '@finally { symbol = nil; state = nil; list = nil; }' in reader
    wrappers = s.split('#define PX_REG_TYPED', 1)[1].split('#pragma mark - Dispatch helpers', 1)[0]
    assert '@finally { providerID = nil; pre = nil; post = nil; }' in wrappers
    assert wrappers.count('@finally { providerID = nil; post = nil; }') == 4
    assert '@finally { providerID = nil; pre = nil; }' in wrappers
    dispatch = s.split('#pragma mark - Dispatch helpers', 1)[1].split('#pragma mark - Installation', 1)[0]
    signatures = re.findall(r'^static [^\n]+(?= \{)', dispatch, re.M)
    assert len(signatures) == 15
    for signature in signatures:
        body = method(s, signature)
        assert 'PX_RUNTIME_READ_OPERATION;' in body and 'providers = nil; coord = nil;' in body
        assert 'for (PXNativeHookProvider *p in providers)' not in body
        assert 'PXNativeHookProvider * __unsafe_unretained p = providers[index];' in body
        assert body.count('_providersCopyForSymbol:') == 1
    mapper = method(s, next(sig for sig in signatures if 'PXCoord_sysctlnametomib(' in sig))
    assert 'originalCalled' not in mapper and 'g_inside_sysctlnametomib = previous;' in mapper
    assert mapper.count('result = g_orig_sysctlnametomib ?') == 1
    assert 'providers = nil;\n        }\n        if (!handled)' in mapper
    diag = method(s, '- (NSDictionary *)diagnostics')
    assert 'state = [self _captureProviderState];' in diag and 'metadata = [self _captureInstallationMetadata];' in diag
    assert 'os_unfair_lock_lock' not in diag
    assert diag.index('_captureInstallationMetadata') < diag.index('for (NSString *sym in state.providers)')
    assert 'providersBySymbol' not in s and 'globalProviderIDs' not in s
    check_macro_arity((ROOT / 'tests/PXNativeProviderRegistryTests.m').read_text(encoding='utf-8'), 'provider-registry')
    assert 'scripts/test_native_provider_registry.py --native' in (ROOT / '.github/workflows/build-ios-arm.yml').read_text()
    assert 'scripts/test_native_provider_registry.py' in (ROOT / 'scripts/release_hardening.py').read_text()
    print('PASS: Immutable native provider registry and 15 dispatch contracts (native execution not implied)')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-native-registry-') as tmp:
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            for mode, flag in (('plain-arc', '-fno-objc-arc-exceptions'), ('arc-eh', '-fobjc-arc-exceptions')):
                binary = Path(tmp) / (scheme + '-' + mode)
                print('Native provider registry matrix:', scheme, mode, flush=True)
                subprocess.run(['xcrun', 'clang', '-O0', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions', flag,
                                '-Wall', '-Wextra', '-Werror=implicit-function-declaration', *defines,
                                '-I', str(ROOT / 'common'), '-I', str(ROOT / 'TLinkIOSTweak'),
                                str(ROOT / 'tests/PXNativeProviderRegistryTests.m'), str(ROOT / 'common/PXRuntimeReadScope.m'),
                                '-framework', 'Foundation', '-framework', 'CoreFoundation', '-o', str(binary)],
                               cwd=ROOT, check=True, timeout=60)
                subprocess.run([str(binary)], cwd=ROOT, check=True, timeout=90)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        native_tests()
