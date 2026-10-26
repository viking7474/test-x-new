#!/usr/bin/env python3
"""4C.2A writer enrollment; --native tests real NetworkManager/staging/source engine."""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text(encoding='utf-8')


def objc_method(source, signature):
    start = source.index(signature + ' {')
    ends = [i for marker in ('\n- (', '\n+ (', '\n@end') if (i := source.find(marker, start + len(signature))) != -1]
    return source[start:min(ends)]


def source_contracts():
    helper = read('common/PXRuntimeArtifactWriter.m')
    header = read('common/PXRuntimeArtifactWriter.h')
    network = read('common/NetworkManager.m')
    wifi = read('common/WiFiManager.m')
    battery = read('common/BatteryManager.m')
    uptime = read('common/UptimeManager.m')
    storage = read('common/StorageManager.m')
    core = read('common/PXRuntimeSourceStore.m')
    fixture = read('tests/PXRuntimeArtifactWriterTests.m')
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2H3C-partial'
    for name in ('network', 'wifi', 'battery', 'uptime', 'storage', 'identifier-artifacts'):
        assert manifest['writers'][name]['status'] == 'enrolled', name
    assert manifest['writers']['profile-lifecycle']['status'] == 'partial'
    for name in ('security-store', 'security-direct', 'storage-preference'):
        assert manifest['writers'][name]['status'] == 'pending', f'cannot claim coverage of {name}'
    for forbidden in ('PXActiveProfile', 'PXPerformRuntimeSourceWrite', 'writeToFile:', 'createDirectory', 'PXLog(',
                      'PostNotification', 'dispatch_', 'getifaddrs', 'NSClassFromString'):
        assert forbidden not in helper, f'staging helper must remain pure except transaction reads: {forbidden}'
    for name in ('Addresses', 'Carrier', 'WiFi', 'Battery', 'Uptime'):
        assert f'PXStageRuntime{name}' in helper and f'PXStageRuntime{name}' in header
    assert 'exists:&exists error:error' in helper and 'if (!exists) return YES;' in helper
    assert 'self.staged[path]) { if (exists) *exists = YES;' in core
    assert 'ipv6 = PXArtifactIPv6(network, ids) ?: ipv6' in helper
    assert 'ids[@"SSID"] = wifi[@"ssid"]' in helper and 'ids[@"BSSID"] = wifi[@"bssid"]' in helper
    assert 'timeIntervalSince1970' in helper and 'ids[@"LastUpdated"] = timestamp' in helper
    assert 'writeToFile:' not in network, 'NetworkManager may not bypass source transactions'
    for signature in ('+ (BOOL)saveAddresses:(NSString *)ipAddress ipv6:(NSString *)ipv6Address inIdentityDirectory:(NSString *)identityDir',
                      '+ (BOOL)saveSingleAddress:(NSString *)ipAddress inIdentityDirectory:(NSString *)identityDir',
                      '+ (BOOL)saveCarrier:(NSDictionary *)carrierDict inIdentityDirectory:(NSString *)identityDir'):
        body = objc_method(network, signature)
        assert 'PXPerformRuntimeSourceWrite' in body and 'PXStageRuntime' in body
        assert 'profileIdentityPath' not in body, 'explicit-target persistence must not select a second profile'
    single = objc_method(network, '+ (BOOL)saveSingleAddress:(NSString *)ipAddress inIdentityDirectory:(NSString *)identityDir')
    assert single.index('PXStageRuntimeIPv4WithExistingPair') < single.index('generateSpoofedLocalIPv6AddressFromCurrent')
    assert single.index('}, &error)') < single.index('generateSpoofedLocalIPv6AddressFromCurrent')
    for body, helper_name in ((objc_method(wifi, '- (void)saveWiFiInfoToCurrentProfile'), 'WiFi'),
                              (objc_method(battery, '- (void)saveBatteryInfoToDisk'), 'Battery'),
                              (objc_method(uptime, '- (void)generateConsistentUptimeAndBootTimeForProfile:(NSString *)profilePath'), 'Uptime')):
        assert f'PXStageRuntime{helper_name}' in body and 'PXPerformRuntimeSourceWrite' in body
        assert 'writeToFile:deviceIdsPath' not in body
    assert 'writeToFile:BATTERY_PLIST_PATH' in battery, 'legacy global battery compatibility remains separate'
    storage_save = objc_method(storage, '- (void)saveToProfile:(NSString *)profileId')
    assert 'PXProfileRootPath(profileId)' in storage_save and '[tx setDictionary:prepared atPath:storagePath' in storage_save
    assert 'writeToFile:' not in storage_save
    assert 'initWithSuiteName:@"com.hydra.tlinkios.settings"' in storage, 'defaults authority rollout remains pending'
    uptime_save = objc_method(uptime, '- (void)generateConsistentUptimeAndBootTimeForProfile:(NSString *)profilePath')
    assert uptime_save.index('PXPerformRuntimeSourceWrite') < uptime_save.index('self.bootTimeValue = bootTime')
    assert 'PXPrepareRuntimeUptime(now, realUptime, sysctlResult == 0)' in uptime_save
    assert 'if (uptime < minUptime) uptime = minUptime;' in read('common/PXRuntimeArtifactPreparation.m'), 'generation policy must not silently change'
    for token in ('network IPv6 precedence preserved', 'existing IPv6 avoids generation',
                  'profile switch during prepare cannot redirect', 'prepared candidate cannot overwrite',
                  'carrier refresh preserves captured target', 'battery does not create previously absent',
                  'all artifact stages compose', 'boot date uptime string and version schema',
                  'artifact failure rolls back', 'corrupt artifact is not silently replaced',
                  'concurrent disjoint artifact merges preserve'):
        assert token in fixture, f'native scenario missing: {token}'
    assert 'test_runtime_artifact_writers.py --native' in read('.github/workflows/build-ios-arm.yml')
    print('PASS: Runtime artifact writer source contracts (partial enrollment; native runtime not implied)')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-artifact-writers-') as folder:
        binary = Path(folder) / 'artifact-writers'
        # Only the root/path/transaction-selection/log sink are fixture backends.
        # Compile actual manager, carrier dependency, stage helpers and source engine.
        sources = ['common/NetworkManager.m', 'common/CarrierDB.m', 'common/PXRuntimeArtifactWriter.m',
                   'common/PXRuntimeSourceStore.m', 'common/PXRuntimePublisher.m', 'tests/PXRuntimeArtifactWriterTests.m']
        subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions',
                        '-DPX_SOURCE_TRANSACTION_TESTING=1', '-Wall', '-Wextra', '-Werror=implicit-function-declaration',
                        '-I', str(ROOT / 'common'), *[str(ROOT / source) for source in sources],
                        '-framework', 'Foundation', '-framework', 'Security', '-o', str(binary)],
                       check=True, cwd=ROOT, timeout=60)
        for _ in range(3):
            subprocess.run([str(binary)], check=True, cwd=ROOT, timeout=60)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        native_tests()
