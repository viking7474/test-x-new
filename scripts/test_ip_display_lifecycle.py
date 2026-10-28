#!/usr/bin/env python3
"""Exact IP display adapter and lookup; controlled native transport, no real network."""
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
ADAPTERS = ['- (void)fetchCurrentIP', '- (void)fetchSimpleIP', '- (void)fetchIPDisplayUsingFallback:(BOOL)fallback']


def source_contracts():
    core = read('common/PXIPDisplayLookup.m')
    cancel = identifier.method(core, '- (void)cancel')
    assert cancel.index('self.token = nil') < cancel.index('[session invalidateAndCancel]')
    assert 'self.attemptToken = nil' in cancel and '[self updateWorkerToken:nil]' in cancel
    assert 'self.token != token || self.attemptToken != attempt' in core
    assert core.index('self.attemptToken = nil;', core.index('completionHandler:')) < core.index('[finished finishTasksAndInvalidate]')
    assert 'workerTokenIsCurrent:token' in core and 'DISPATCH_QUEUE_SERIAL' in core
    assert 'os_unfair_lock_lock(&_intentLock)' in core and 'objc_precise_lifetime' in core
    assert 'dispatch_sync' not in core and '- (void)dealloc { [_session invalidateAndCancel]; }' in core
    for token in ('[json isKindOfClass:NSDictionary.class]', '[ip isKindOfClass:NSString.class]',
                  'https://api.ipify.org', 'https://ipwhois.app/json/', 'fallback ? 5.0 : 8.0',
                  'timeoutIntervalForResource = 15.0', 'WeaponX iOS App'):
        assert token in core, token
    source = read('SecurityTabViewController.m')
    adapter = identifier.method(source, ADAPTERS[-1])
    assert '__weak typeof(self) weakSelf' in adapter and 'if (!NSThread.isMainThread)' in adapter
    assert 'prepare:^NSDictionary *' in adapter and 'completion:^(NSDictionary *display)' in adapter
    assert adapter.index('persistTimeZoneName:timezoneName') < adapter.index('completion:^(NSDictionary *display)') < adapter.index('updateIPLabelWithIP:')
    for method in ADAPTERS:
        assert 'NSURLSession' not in identifier.method(source, method)
    fixture = read('tests/PXIPDisplayLifecycleTests.m')
    for case in ('stale primary error cannot launch fallback', 'primary finishes before one fallback starts',
                 'duplicate primary cannot create another fallback', 'old fallback cannot overwrite newer generation',
                 'cancel drops queued preparation before source effects', 'invalid optional fields cannot escape to UIKit or timezone selectors',
                 'exact adapter persists timezone off main and delivers formatted display', 'unchanged timezone skips another source write',
                 'pending transport does not retain controller and dealloc cancels session', 'consumer reentry retains its new lookup',
                 'admitted preparation finishes before newer effects and stale UI is suppressed',
                 'background adapter entry routes main without dispatch sync'):
        assert case in fixture, case
    assert 'test_ip_display_lifecycle.py --native' in read('.github/workflows/build-ios-arm.yml')
    assert 'scripts/test_ip_display_lifecycle.py' in read('scripts/release_hardening.py')
    print('PASS: IP display lifecycle source contracts (native/runtime/source authority not implied)')


def generate_native_fragments(folder):
    source = read('SecurityTabViewController.m')
    (folder / 'PXIPDisplayAdapters.inc').write_text('\n\n'.join(identifier.method(source, method) for method in ADAPTERS), encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    failures = []
    with tempfile.TemporaryDirectory(prefix='px-ip-display-') as temp:
        folder = Path(temp)
        generate_native_fragments(folder)
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            print(f'IP display native lane: {scheme}', flush=True)
            binary = folder / scheme
            try:
                subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-Wall', '-Wextra', '-Werror=implicit-function-declaration',
                                '-I', str(ROOT / 'common'), '-I', str(folder), *defines,
                                str(ROOT / 'tests/PXIPDisplayLifecycleTests.m'), '-framework', 'Foundation',
                                '-framework', 'CoreFoundation', '-o', str(binary)], check=True, cwd=ROOT, timeout=60)
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
