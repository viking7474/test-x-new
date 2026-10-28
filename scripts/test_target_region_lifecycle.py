#!/usr/bin/env python3
"""Actual region coordinator and UI adapters with controlled native transport/storage."""
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
HELPERS = ['static NSString *PXFlagEmojiFromCountryCode(NSString *cc)',
           'static void PXPublishTargetRegionSettings(void)', 'static NSDictionary *PXCommitTargetRegionToggle(BOOL enabled)']
ADAPTERS = ['- (void)publishTargetRegionChanged', '- (void)targetRegionFollowsIPToggleChanged:(UISwitch *)sender',
            '- (NSDictionary *)applyTargetRegionResponse:(NSDictionary *)json', '- (void)syncTargetRegionFromIPTapped:(id)sender']


def source_contracts():
    core = read('common/PXTargetRegionSync.m')
    assert 'DISPATCH_QUEUE_SERIAL' in core and '[self admitsToken:token]' in core
    assert 'self.token != token || self.requestToken != token' in core
    assert 'durable ? self : nil' in core and 'keepAlive ?: weakSelf' in core
    assert 'os_unfair_lock_lock(&_intentLock)' in core and 'objc_precise_lifetime' in core
    begin = identifier.method(core, '- (NSObject *)beginIntent')
    assert begin.index('self.token = token') < begin.index('[old invalidateAndCancel]')
    assert 'self.requestToken = nil' in core and '[finished finishTasksAndInvalidate]' in core
    assert '- (void)dealloc { [_session invalidateAndCancel]; }' in core
    assert 'dispatch_sync' not in core and 'writeToFile:' not in core
    for token in ('ephemeralSessionConfiguration', 'timeoutIntervalForRequest = 10.0', 'timeoutIntervalForResource = 15.0',
                  'https://ip-api.com/json/?fields=status,message,countryCode,lat,lon,timezone,query'):
        assert token in core, token
    source = read('SecurityTabViewController.m')
    toggle = identifier.method(source, ADAPTERS[1])
    sync = identifier.method(source, ADAPTERS[3])
    apply = identifier.method(source, ADAPTERS[2])
    assert 'performChange:^NSDictionary *{ return PXCommitTargetRegionToggle(enabled); }' in toggle
    assert '__weak UISwitch *weakSender = sender' in toggle and '[current setOn:[result[@"enabled"] boolValue]' in toggle
    assert 'syncWithApply:^NSDictionary *' in sync and '__weak typeof(self) weakSelf' in sync
    assert 'NSURLSession' not in sync and 'writeToFile:' not in sync and 'PXWriteSecurityBool' not in toggle
    assert apply.index('persistPinnedTargetRegionFromResponse:') < apply.index('savePinnedLocation:') < apply.index('writeToFile:') < apply.index('[self publishTargetRegionChanged]')
    fixture = read('tests/PXTargetRegionLifecycleTests.m')
    for case in ('stale sync response cannot write source GPS cache or notifications',
                 'duplicate sync completion has no repeated effects', 'toggle invalidates pending sync before any apply effects',
                 'in-flight sync finishes before newer disable and cannot resurrect UI',
                 'queued sync and older toggle are discarded before effects for latest intent',
                 'failed primary commit suppresses GPS cache notifications and success feedback',
                 'failed toggle restores worker-read previous state on main',
                 'pending network does not retain controller and dealloc cancels session',
                 'detached explicit toggle persists after UI owner release', 'background sync entry reaches main asynchronously'):
        assert case in fixture, case
    assert 'test_target_region_lifecycle.py --native' in read('.github/workflows/build-ios-arm.yml')
    assert 'scripts/test_target_region_lifecycle.py' in read('scripts/release_hardening.py')
    print('PASS: TargetRegion request/worker lifecycle contracts (cross-process atomicity/native/device not implied)')


def generate_native_fragments(folder):
    source = read('SecurityTabViewController.m')
    (folder / 'PXRegionLifecycleHelpers.inc').write_text('\n\n'.join(identifier.method(source, signature) for signature in HELPERS), encoding='utf-8')
    (folder / 'PXRegionLifecycleAdapters.inc').write_text('\n\n'.join(identifier.method(source, signature) for signature in ADAPTERS), encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    failures = []
    with tempfile.TemporaryDirectory(prefix='px-region-sync-') as temp:
        folder = Path(temp)
        generate_native_fragments(folder)
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            print(f'TargetRegion native lane: {scheme}', flush=True)
            binary = folder / scheme
            try:
                subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-Wall', '-Wextra', '-Werror=implicit-function-declaration',
                                '-I', str(ROOT / 'common'), '-I', str(folder), *defines,
                                str(ROOT / 'tests/PXTargetRegionLifecycleTests.m'), '-framework', 'Foundation',
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
