#!/usr/bin/env python3
"""Actual country lookup and UI adapter; controlled transport on macOS."""
from pathlib import Path
import argparse
import importlib.util
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding='utf-8')
spec = importlib.util.spec_from_file_location('identifier', ROOT / 'scripts/test_runtime_identifier_writers.py')
identifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(identifier)
ADAPTER = '- (void)fetchCountryForCoordinates:(double)lat longitude:(double)lon completion:(void (^)(NSString *countryCode, NSString *flag))completion'


def source_contracts():
    core = read('common/PXPinnedCountryLookup.m')
    cancel = identifier.method(core, '- (void)cancel')
    resolve = identifier.method(core, '- (void)resolveCoordinate:(CLLocationCoordinate2D)coordinate completion:(PXPinnedCountryCompletion)completion')
    assert cancel.index('self.token = nil') < cancel.index('[task cancel]')
    assert '__weak typeof(self) weakSelf' in resolve and 'self.token != token' in resolve
    delivery = resolve[resolve.index('if (!self || self.token != token) return;'):]
    assert delivery.index('self.token = nil') < delivery.index('completion(code)')
    assert delivery.index('self.task = nil') < delivery.index('completion(code)')
    assert '[[NSURLSession sharedSession] dataTaskWithRequest:' in resolve
    assert 'request.timeoutInterval = 10.0' in resolve and 'WeaponX iOS App' in resolve
    assert 'lat=%.6f&lon=%.6f&zoom=18&addressdetails=1' in resolve
    for token in ('[json isKindOfClass:NSDictionary.class]', '[address isKindOfClass:NSDictionary.class]',
                  '[rawCode isKindOfClass:NSString.class]', 'CLLocationCoordinate2DIsValid'):
        assert token in resolve, token
    assert '[_task cancel]' in identifier.method(core, '- (void)dealloc')
    for forbidden in ('dispatch_sync', 'invalidateAndCancel', 'finishTasksAndInvalidate', 'writeToFile:'):
        assert forbidden not in core, forbidden
    security = read('SecurityTabViewController.m')
    adapter = identifier.method(security, ADAPTER)
    assert '__weak typeof(self) weakSelf' in adapter and 'if (!NSThread.isMainThread)' in adapter
    assert adapter.index('[self.pinnedCountryLookup cancel]') < adapter.index('if (!completion)') < adapter.index('objectForKey:cacheKey')
    assert '@"%.4f,%.4f"' in adapter and 'NSURLSession' not in adapter
    refresh = identifier.method(security, '- (void)refreshPinnedCoordinates')
    assert refresh.index('[self.pinnedCountryLookup cancel]') < refresh.index('loadSpoofingLocation')
    consumer = refresh[refresh.index('[self fetchCountryForCoordinates:'):]
    assert consumer.index('__strong typeof(weakSelf) self = weakSelf;') < consumer.index('PXPinnedCoordinateMatchesLocation')
    assert consumer.index('PXPinnedCoordinateMatchesLocation') < consumer.index('coordsLabel.attributedText') < consumer.index('savePinnedLocation:')
    fixture = read('tests/PXPinnedCountryLifecycleTests.m')
    for case in ('late superseded result has no consumer effects', 'current country delivered once and normalized',
                 'consumer reentry keeps newly started request', 'invalid coordinates and nil completion launch no transport',
                 'pending transport does not retain lookup and dealloc cancels task', 'network adapter does not retain controller',
                 'rounded cache hit cancels previous request without new transport', 'stale adapter cannot populate owner cache',
                 'background adapter enters main without synchronous dispatch', 'background cancellation reaches main'):
        assert case in fixture, case
    assert 'test_pinned_country_lifecycle.py --native' in read('.github/workflows/build-ios-arm.yml')
    assert 'scripts/test_pinned_country_lifecycle.py' in read('scripts/release_hardening.py')
    print('PASS: Pinned country lifecycle source contracts (native transport/device behavior not implied)')


def generate_native_fragments(folder):
    (folder / 'PXSecurityCountryAdapter.inc').write_text(identifier.method(read('SecurityTabViewController.m'), ADAPTER), encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    failures = []
    with tempfile.TemporaryDirectory(prefix='px-pinned-country-') as temp:
        folder = Path(temp)
        generate_native_fragments(folder)
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            print(f'Pinned country native lane: {scheme}', flush=True)
            binary = folder / scheme
            try:
                subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-Wall', '-Wextra', '-Werror=implicit-function-declaration',
                                '-I', str(ROOT / 'common'), '-I', str(folder), *defines,
                                str(ROOT / 'tests/PXPinnedCountryLifecycleTests.m'), '-framework', 'Foundation',
                                '-framework', 'CoreFoundation', '-framework', 'CoreLocation', '-o', str(binary)], check=True, cwd=ROOT, timeout=60)
                for _ in range(3):
                    subprocess.run([str(binary)], check=True, cwd=ROOT, timeout=60)
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
                failures.append(f'{scheme}: {error}')
    assert not failures, '\n'.join(failures)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        native_tests()
