#!/usr/bin/env python3
"""Exact IP Monitor lifecycle methods; controlled transport, real GCD/timers on macOS."""
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
SIGNATURES = ['- (void)dealloc', '- (BOOL)setMonitoringEnabledAndPersist:(BOOL)enabled error:(NSError **)error',
              '- (void)startMonitoring', '- (void)stopMonitoring', '- (BOOL)isMonitoring',
              '- (void)startAdaptivePolling', '- (void)adaptiveCheckForIPChange:(NSTimer *)timer',
              '- (void)checkForIPChange', '- (void)fetchCurrentIPWithConsensus:(void (^)(NSString *ip, NSError *error))completion']


def selected_methods():
    source = read('common/IPMonitorService.m')
    start = source.index('- (void)fetchIPFromService:')
    signature = source[start:source.index(' {', start)]
    return [identifier.method(source, signature) for signature in [*SIGNATURES, signature]]


def source_contracts():
    source = read('common/IPMonitorService.m')
    methods = selected_methods()
    stopped, fetch = methods[3], methods[8]
    assert stopped.index('self.monitoringToken = nil') < stopped.index('[session invalidateAndCancel]')
    assert '[self.monitoringSessions removeAllObjects]' in stopped
    assert '[self.monitoringSessions addObject:session]' in fetch
    assert fetch.index('[session finishTasksAndInvalidate]') < fetch.index('token != self.monitoringToken') < fetch.index('completion(mostCommonIP, nil)')
    assert '__weak typeof(self) weakSelf' in fetch
    for index in (2, 6, 7):
        assert '__weak typeof(self) weakSelf' in methods[index]
    assert 'timer != self.monitoringTimer' in methods[6]
    assert 'static NSString *lastCheckedIP' not in source and 'self.lastCheckedIP = ip' in methods[6]
    assert 'token != self.monitoringToken' in methods[6]
    assert 'repeats:YES block:' in methods[5] and '[weakSelf adaptiveCheckForIPChange:timer]' in methods[5]
    assert 'dispatch_sync' not in source
    assert methods[1].index('if (!NSThread.isMainThread)') < methods[1].index('PXWriteSecurityBool')
    assert 'SCNetworkReachabilitySetCallback(self.reachability, NULL, NULL)' in methods[0]
    assert '@property (nonatomic, weak) IPMonitorService *service;' in source
    assert '(__bridge void *)owner, CFRetain, CFRelease, NULL' in source
    assert '[json isKindOfClass:NSDictionary.class]' in methods[9] and '[ip isKindOfClass:NSString.class]' in methods[9]
    alert = identifier.method(source, '- (void)showIPChangeAlertWithOldIP:(NSString *)oldIP newIP:(NSString *)newIP')
    assert alert.index('token != self.monitoringToken') < alert.index('[UIAlertController alertControllerWithTitle:')
    # Keep endpoint, timeout, throttle, fallback and interval policy intact.
    for token in ('https://ifconfig.me/ip', 'https://api.myip.com', 'https://api.ipify.org',
                  'timeoutIntervalForRequest = 8.0', 'timeoutIntervalForResource = 20.0',
                  'HTTPMaximumConnectionsPerHost = 3', 'highestCount >= 2',
                  'now - self.lastCheckTime < 5.0', 'MAX(30.0, self.adaptiveInterval * 0.5)',
                  'MIN(300.0, self.adaptiveInterval * 1.5)'):
        assert token in source, token
    fixture = read('tests/PXIPMonitorLifecycleTests.m')
    for case in ('stopped initial callbacks cannot save IP or resurrect timer',
                 'stale adaptive and manual callbacks cannot mutate restarted monitoring',
                 'normal consensus finishes session and delivers on main thread',
                 'disabled preference drops result and still finishes session',
                 'invalid JSON shapes never escape as IP values',
                 'pending transport and timer do not retain monitor owner',
                 'old timer and disabled controls launch no transport',
                 'off-main toggle fails before persistence or service mutation',
                 'independent instances do not share adaptive baseline',
                 'cache callback reentry cannot reschedule old adaptive work into new generation'):
        assert case in fixture, case
    assert 'test_ip_monitor_lifecycle.py --native' in read('.github/workflows/build-ios-arm.yml')
    assert 'scripts/test_ip_monitor_lifecycle.py' in read('scripts/release_hardening.py')
    print('PASS: IP Monitor lifecycle source contracts (controlled transport; native/device runtime not implied)')


def generate_native_fragments(folder):
    methods = selected_methods()
    (folder / 'PXIPMonitorLifecycleDeclarations.inc').write_text('\n'.join(method.split(' {', 1)[0] + ';' for method in methods if not method.startswith('- (void)dealloc')), encoding='utf-8')
    (folder / 'PXIPMonitorLifecycleMethods.inc').write_text('\n\n'.join(methods), encoding='utf-8')
    source = read('common/IPMonitorService.m')
    start = source.index('@interface PXIPMonitorReachabilityOwner')
    end = source.index('@end', source.index('@implementation PXIPMonitorReachabilityOwner', start)) + len('@end')
    (folder / 'PXIPMonitorReachabilityOwner.inc').write_text(source[start:end], encoding='utf-8')
    start = source.index('static void ReachabilityCallback(')
    signature = source[start:source.index(' {', start)]
    (folder / 'PXIPMonitorReachabilityCallback.inc').write_text(identifier.method(source, signature), encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    failures = []
    with tempfile.TemporaryDirectory(prefix='px-ip-monitor-') as temp:
        folder = Path(temp)
        generate_native_fragments(folder)
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            print(f'IP Monitor native lane: {scheme}', flush=True)
            binary = folder / scheme
            try:
                subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-Wall', '-Wextra', '-Werror=implicit-function-declaration',
                                '-I', str(ROOT / 'common'), '-I', str(folder), *defines,
                                str(ROOT / 'tests/PXIPMonitorLifecycleTests.m'), '-framework', 'Foundation',
                                '-framework', 'CoreFoundation', '-framework', 'SystemConfiguration', '-o', str(binary)], cwd=ROOT, check=True, timeout=60)
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
