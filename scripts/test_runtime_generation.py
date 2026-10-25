#!/usr/bin/env python3
"""4C.2G fixed-target batch generation; --native uses exact production methods."""
from pathlib import Path
import argparse
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding='utf-8')
spec = importlib.util.spec_from_file_location('device_groups', ROOT / 'scripts/test_runtime_device_group_writers.py')
groups = importlib.util.module_from_spec(spec)
spec.loader.exec_module(groups)


def source_contracts():
    manager = read('common/IdentifierManager.m')
    current = groups.method(manager, '- (BOOL)regenerateAllEnabledIdentifiersWithError:(NSError **)error')
    flow = groups.method(manager, '- (BOOL)regenerateAllEnabledIdentifiersAtIdentityDirectory:(NSString *)identityDir networkArtifacts:(NSDictionary *)networkArtifacts error:(NSError **)error')
    wrapper = groups.method(manager, '- (void)regenerateAllEnabledIdentifiers')
    assert 'regenerateAllEnabledIdentifiersWithError:&error' in wrapper
    assert current.count('[self profileIdentityPath]') == 1 and 'regenerateAllEnabledIdentifiersAtIdentityDirectory:' in current
    assert 'profileIdentityPath' not in flow
    assert flow.index('PXSanitizedIdentifierSettings(self.settings)') < flow.index('prepareDeviceProfileGroupWithOptions:')
    assert flow.index('PXStageRuntimeGeneration(') < flow.index('publishRuntimeGeneration:payload')
    assert flow.index('if (!committed)') < flow.index('publishRuntimeGeneration:payload')
    for forbidden in ('[self saveSettings]', 'generateWiFiInfo]', 'generateBootTimeForProfile:',
                      'setTotalStorageCapacity:', 'generateDeviceTheme]', 'setCustomValue:', 'dispatch_'):
        assert forbidden not in flow, forbidden
    stage = read('common/PXRuntimeGeneration.m')
    assert stage.index('Generation dependencies changed') < stage.index('PXStageRuntimeIdentifierReplacement(')
    for token in ('PXStageRuntimeWiFi(', 'PXStageRuntimeUptime(', 'PXStageRuntimeBattery(',
                  'PXStageRuntimeIdentifierValue(', 'StorageSystemEnabled', 'ScopedApps', 'NSPropertyListImmutable'):
        assert token in stage, token
    for forbidden in ('PXActiveProfile', 'sharedManager', 'NSNotification', 'writeToFile:', 'dispatch_async', 'PXPerformRuntimeSourceWrite'):
        assert forbidden not in stage, forbidden
    publisher = groups.method(manager, '- (void)publishRuntimeGeneration:(NSDictionary *)payload identityDirectory:(NSString *)identityDir model:(PXPreparedDeviceProfileGroup *)model')
    assert 'PXActiveProfileID()' in publisher and '@catch' in publisher
    assert publisher.index('removeAllObjects]') < publisher.index('publishCommittedBatteryInfo:')
    for file, signature in (
        ('WiFi', '- (void)adoptCommittedWiFiInfo:(NSDictionary *)wifiInfo profileID:(NSString *)profileID'),
        ('Battery', '- (void)adoptCommittedBatteryInfo:(NSDictionary *)batteryInfo'),
        ('Storage', '- (void)adoptCommittedStorageInfo:(NSDictionary *)storageInfo'),
        ('Uptime', '- (void)adoptCommittedUptimeInfo:(NSDictionary *)uptimeInfo timestamp:(NSDate *)timestamp'),
    ):
        body = groups.method(read(f'common/{file}Manager.m'), signature)
        assert 'save' not in body and 'Notification' not in body and 'PXActiveProfile' not in body
    battery = groups.method(read('common/BatteryManager.m'), '- (void)publishCommittedBatteryInfo:(NSDictionary *)batteryInfo timestamp:(NSDate *)timestamp')
    assert 'saveBatteryInfoToDisk' not in battery and 'PXPerformRuntimeSourceWrite' not in battery
    fixture = read('tests/PXRuntimeDeviceGroupWriterTests.m')
    for case in ('whole regenerate commits once at one captured target',
                 'whole batch rollback restores artifacts settings scope',
                 'batch scalar preparation failure leaves all source and caches intact',
                 'batch dependency drift rejects entire candidate including absence',
                 'batch freezes nested caller intent and merges unrelated updates',
                 'batch target switch commits A and skips inactive compatibility caches',
                 'post commit callback exception cannot report a false rollback',
                 'batch counter exhaustion prevents every artifact and notification',
                 'batch malformed beforeimage fails without replacing any source',
                 'batch disabled options preserve tuple and unconditional WiFi policy',
                 'batch cellular only refresh preserves model and build',
                 'batch missing baseline seeds canonical group with frozen cellular policy'):
        assert case in fixture, case
    for source in ('common/PXRuntimeGeneration.m', 'common/PXRuntimeScalarPreparation.m', 'common/PXRuntimeArtifactPreparation.m'):
        assert source in read('scripts/test_runtime_device_group_writers.py')
    assert 'test_runtime_generation.py' in read('.github/workflows/build-ios-arm.yml')
    assert 'test_runtime_generation.py' in read('scripts/release_hardening.py')
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2H1-partial'
    assert manifest['writers']['identifier-artifacts']['status'] == 'enrolled'
    for pending in ('profile-lifecycle', 'dashboard-preview', 'storage-preference', 'security-store', 'security-direct'):
        assert manifest['writers'][pending]['status'] == 'pending'
    print('PASS: Whole-regenerate source contracts (partial enrollment; native runtime not implied)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        groups.native_tests()
