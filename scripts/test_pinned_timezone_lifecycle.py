#!/usr/bin/env python3
"""Latest pinned timezone lookup and exact UI adapters; controlled geocoder on macOS."""
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
TIME = '- (void)resolvePinnedLocationTimeZone'
SECURITY = '- (void)getTimeZoneForLocation:(CLLocationCoordinate2D)coordinate completion:(void (^)(NSTimeZone *timeZone, NSString *timeZoneId))completion'


def source_contracts():
    core = read('common/PXPinnedTimeZoneLookup.m')
    cancel = identifier.method(core, '- (void)cancel')
    resolve = identifier.method(core, '- (void)resolveCoordinate:(CLLocationCoordinate2D)coordinate completion:(PXPinnedTimeZoneCompletion)completion')
    assert cancel.index('self.token = nil') < cancel.index('[geocoder cancelGeocode]')
    assert 'token != self.token' in resolve and 'CLLocationCoordinate2DIsValid' in resolve
    assert '__weak typeof(self) weakSelf' in resolve and 'dispatch_async(dispatch_get_main_queue()' in resolve
    delivery = resolve[resolve.index('if (!self || token != self.token) return;'):]
    assert delivery.index('self.token = nil') < delivery.index('completion(nil, error)')
    assert delivery.index('self.geocoder = nil') < delivery.index('completion(nil, error)')
    cleanup = identifier.method(core, '- (void)dealloc')
    assert 'CLGeocoder *geocoder = _geocoder;' in cleanup and 'dispatch_async(dispatch_get_main_queue()' in cleanup
    assert 'weakSelf' not in cleanup and '[self cancel]' not in cleanup
    assert 'dispatch_sync' not in core and 'writeToFile:' not in core and 'PXWriteSecurity' not in core
    time = read('TimeSpoofDetailViewController.m')
    adapter = identifier.method(time, TIME)
    assert adapter.count('PXReadSecurityInteger(@"timeSpoofingMode", 0) != 2') == 2
    assert adapter.index('PXPinnedCoordinateMatchesLocation') < adapter.index('[self persistLocationTimeZoneName:name]')
    assert '__weak typeof(self) weakSelf' in adapter and '[self.pinnedTimeZoneLookup cancel]' in adapter
    mode = identifier.method(time, '- (void)modeRowTapped:(UITapGestureRecognizer *)g')
    assert mode.index('return;') < mode.index('[self.pinnedTimeZoneLookup cancel]') < mode.index('[self publishTimeSpoofSettingsChanged]')
    security = read('SecurityTabViewController.m')
    adapter = identifier.method(security, SECURITY)
    assert adapter.index('PXPinnedCoordinateMatchesLocation') < adapter.index('completion(error ? nil : zone')
    assert '__weak typeof(self) weakSelf' in adapter
    refresh = identifier.method(security, '- (void)refreshPinnedCoordinates')
    assert refresh.index('[self.pinnedTimeZoneLookup cancel]') < refresh.index('loadSpoofingLocation')
    before_call = refresh[:refresh.index('[self getTimeZoneForLocation:')]
    assert '__weak typeof(self) weakSelf' in before_call
    assert '__strong typeof(weakSelf) self = weakSelf;' in refresh
    assert 'CLGeocoder *' not in time and 'CLGeocoder *' not in adapter
    fixture = read('tests/PXPinnedTimeZoneLifecycleTests.m')
    for case in ('superseded and cancelled lookups drop late geocoder results',
                 'lookup delivers current zone once on main thread',
                 'consumer reentry preserves its newly started lookup',
                 'geocoder does not retain lookup or controller owner',
                 'time detail rejects result after pin or mode changes',
                 'security adapter rejects stale coordinates and delivers current result on main',
                 'invalid coordinates and missing completion launch no geocoder',
                 'background controls reach main without synchronous dispatch'):
        assert case in fixture, case
    assert 'test_pinned_timezone_lifecycle.py --native' in read('.github/workflows/build-ios-arm.yml')
    assert 'scripts/test_pinned_timezone_lifecycle.py' in read('scripts/release_hardening.py')
    print('PASS: Pinned timezone lifecycle source contracts (geocoder/device behavior not implied)')


def generate_native_fragments(folder):
    (folder / 'PXTimeZoneDetailAdapter.inc').write_text(identifier.method(read('TimeSpoofDetailViewController.m'), TIME), encoding='utf-8')
    (folder / 'PXSecurityTimeZoneAdapter.inc').write_text(identifier.method(read('SecurityTabViewController.m'), SECURITY), encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    failures = []
    with tempfile.TemporaryDirectory(prefix='px-pinned-timezone-') as temp:
        folder = Path(temp)
        generate_native_fragments(folder)
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            print(f'Pinned timezone native lane: {scheme}', flush=True)
            binary = folder / scheme
            try:
                subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-Wall', '-Wextra', '-Werror=implicit-function-declaration',
                                '-I', str(ROOT / 'common'), '-I', str(folder), *defines,
                                str(ROOT / 'tests/PXPinnedTimeZoneLifecycleTests.m'), '-framework', 'Foundation',
                                '-framework', 'CoreFoundation', '-framework', 'CoreLocation', '-o', str(binary)], cwd=ROOT, check=True, timeout=60)
                for _ in range(3):
                    subprocess.run([str(binary)], cwd=ROOT, check=True, timeout=60)
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
