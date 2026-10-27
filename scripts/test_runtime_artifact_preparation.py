#!/usr/bin/env python3
"""4C.2E effect-free artifact preparation, exact manager wrappers, staged composition."""
from pathlib import Path
import argparse
import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text(encoding='utf-8')
spec = importlib.util.spec_from_file_location('identifier_writers', ROOT / 'scripts/test_runtime_identifier_writers.py')
identifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(identifier)
WRAPPERS = {
    'PXPreparedWiFiMethod.inc': ('common/WiFiManager.m', ['- (NSDictionary *)generateWiFiInfo', '- (void)adoptCommittedWiFiInfo:(NSDictionary *)wifiInfo profileID:(NSString *)profileID']),
    'PXPreparedBatteryMethods.inc': ('common/BatteryManager.m', ['- (NSString *)randomizeBatteryLevel', '- (NSDictionary *)generateBatteryInfo', '- (void)adoptCommittedBatteryInfo:(NSDictionary *)batteryInfo', '- (void)publishCommittedBatteryInfo:(NSDictionary *)batteryInfo timestamp:(NSDate *)timestamp']),
    'PXPreparedStorageMethod.inc': ('common/StorageManager.m', ['- (NSDictionary *)generateStorageForCapacity:(NSString *)capacity', '- (void)adoptCommittedStorageInfo:(NSDictionary *)storageInfo',
        '- (void)saveToCurrentProfile', '- (void)saveToProfile:(NSString *)profileId',
        '- (BOOL)persistStorageToProfile:(NSString *)profileID current:(BOOL)current error:(NSError **)error',
        '- (void)setTotalStorageCapacity:(NSString *)capacity', '- (void)setFreeStorageSpace:(NSString *)freeSpace', '- (void)setFilesystemType:(NSString *)fsType']),
    'PXPreparedUptimeMethod.inc': ('common/UptimeManager.m', ['- (void)generateConsistentUptimeAndBootTimeForProfile:(NSString *)profilePath', '- (void)adoptCommittedUptimeInfo:(NSDictionary *)uptimeInfo timestamp:(NSDate *)timestamp']),
}


def source_contracts():
    preparation = read('common/PXRuntimeArtifactPreparation.m')
    for forbidden in ('PXActiveProfile', 'PXProfile', 'NSFileManager', 'writeToFile:', 'dictionaryWithContentsOfFile:',
                      'PXPerformRuntimeSourceWrite', 'dispatch_', 'NSNotification', 'PXLog(', 'self.', 'sharedManager', 'sysctl('):
        assert forbidden not in preparation, f'prepare API may not have effects: {forbidden}'
    assert '-(NSTimeInterval)arc4random_uniform(86400)' in preparation, 'unsigned time offset must not wrap into the future'
    assert 'if (uptime < minUptime) uptime = minUptime;' in preparation
    assert 'UINT64_MAX / 1e9' in preparation and '!isfinite(parsedCapacity)' in preparation
    wifi = identifier.method(read('common/WiFiManager.m'), WRAPPERS['PXPreparedWiFiMethod.inc'][1][0])
    assert 'PXPrepareRuntimeWiFiInfo()' in wifi and wifi.count('saveWiFiInfoToCurrentProfile') == 1
    battery = identifier.method(read('common/BatteryManager.m'), '- (NSDictionary *)generateBatteryInfo')
    assert 'PXPrepareRuntimeBatteryInfo(_currentLowPowerMode)' in battery
    assert battery.count('[self saveBatteryInfoToDisk]') == 1 and 'randomizeBatteryLevel' not in battery
    assert battery.index('[self saveBatteryInfoToDisk]') < battery.index('postNotificationName:')
    assert 'PXPrepareRuntimeStorage(capacity)' in read('common/StorageManager.m')
    uptime = identifier.method(read('common/UptimeManager.m'), WRAPPERS['PXPreparedUptimeMethod.inc'][1][0])
    assert 'PXPrepareRuntimeUptime(now, realUptime, sysctlResult == 0)' in uptime
    assert uptime.index('acquireWithIdentityResolver:') < uptime.index('sysctl(mib') < uptime.index('[mutation performSourceWrite:')
    assert uptime.index('[mutation invalidate]') < uptime.index('self.bootTimeValue = bootTime')
    assert '@finally { [mutation invalidate]; }' in uptime and 'createDirectoryAtPath:' not in uptime
    storage = read('common/StorageManager.m')
    persist = identifier.method(storage, '- (BOOL)persistStorageToProfile:(NSString *)profileID current:(BOOL)current error:(NSError **)error')
    assert persist.index('acquireWithProfileIDResolver:') < persist.index('dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()') < persist.index('[_storageSettings copy]')
    assert 'mutation.profileDirectory' in persist and 'mutation.identityDirectory' not in persist
    assert '[mutation performSourceWrite:' in persist and '@finally { [mutation invalidate]; }' in persist
    assert 'PXActiveProfileID()' not in persist and 'PXLegacyActiveProfileInfoPath()' not in persist
    assert 'current:YES' in identifier.method(storage, '- (void)saveToCurrentProfile')
    assert 'current:NO' in identifier.method(storage, '- (void)saveToProfile:(NSString *)profileId')
    mutation = read('common/PXProfileArtifactMutation.m')
    root = identifier.method(mutation, '+ (instancetype)acquireWithProfileIDResolver:(NSString *(^)(void))resolver error:(NSError **)error')
    assert 'PXProfileRootPath(PXValidatedProfileID(' in root and 'identityTarget:NO' in root

    assert uptime.index('[mutation performSourceWrite:') < uptime.index('self.bootTimeValue = bootTime')
    for path, _ in WRAPPERS.values():
        assert '#import "PXRuntimeArtifactPreparation.h"' in read(path), path
    fixture = read('tests/PXRuntimeArtifactPreparationTests.m')
    for case in ('WiFi past connection time cannot unsigned wrap', 'battery weighted buckets retain endpoint policy',
                 'storage rejects unsafe capacity before staging', 'uptime preserves legacy minimum over real uptime',
                 'preparation never writes sources', 'battery batch saves once before notifications',
                 'WiFi wrapper keeps detached result and mutable cache', 'all prepared artifacts commit together',
                 'prepared artifact failure rolls back entire tuple', 'uptime cache changes only after commit'):
        assert case in fixture, case
    for case in ('storage explicit inactive target persists once without selecting active profile',
                 'busy storage blocks current and explicit persistence before copying cache',
                 'pending delete blocks storage before target cache capture',
                 'storage supports existing profile without requiring or creating identity child',
                 'current storage does not substitute legacy selection when canonical ID is absent',
                 'invalid storage selection fails before copying cache or writing source',
                 'current storage captures target once and cannot redirect after preparation',
                 'storage commit failure preserves previous file and source token',
                 'storage cache-copy exception preserves source and releases scope',
                 'late deletion journal rejects storage before staging',
                 'storage rejects removed replaced and symlink profile roots without recreating target',
                 'storage setter autosaves use owned current-target persistence without altering units',
                 'profile-root capability closes descriptors on explicit release dealloc and failed acquire',
                 'uptime cache setter sees committed tuple after ownership release',
                 'busy uptime avoids sysctl preparation cache changes and source writes',
                 'pending delete stops uptime before sysctl and preserves cache',
                 'uptime refuses absent identity instead of recreating legacy directory',
                 'uptime provider exception releases lease before error logging and leaves cache unchanged',
                 'uptime preparation excludes reentrant storage writer',
                 'uptime detaches mutable caller path and cannot redirect during preparation',
                 'late deletion journal rejects entire uptime tuple without adopting cache',
                 'uptime rejects removed replaced and symlink identity without source or cache adoption'):
        assert case in fixture, case
    assert 'test_runtime_artifact_preparation.py --native' in read('.github/workflows/build-ios-arm.yml')
    # The common glob carries the new factory into both manager app and tweak.
    make = read('Makefile')
    assert 'TLinkIOS_FILES = $(wildcard *.m) $(wildcard common/*.m)' in make
    assert 'TLinkIOSTweak_FILES =' in make and '$(wildcard common/*.m)' in make
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2H3F-partial'
    assert manifest['writers']['identifier-artifacts']['status'] == 'enrolled'
    assert manifest['writers']['profile-lifecycle']['status'] == 'partial'
    print('PASS: Artifact preparation and storage/uptime ownership contracts (remaining writers partial; native runtime not implied)')


def generate_native_fragments(folder):
    for name, (source, signatures) in WRAPPERS.items():
        (folder / name).write_text('\n\n'.join(identifier.method(read(source), signature) for signature in signatures), encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-artifact-preparation-') as temp:
        folder = Path(temp)
        generate_native_fragments(folder)
        sources = ['common/PXRuntimeArtifactPreparation.m', 'common/PXRuntimeArtifactWriter.m',
                   'common/PXRuntimeSourceStore.m', 'common/PXRuntimePublisher.m', 'common/PXIdentityValidator.m',
                   'common/PXProfileArtifactMutation.m', 'common/PXProfileLifecycleLease.m',
                   'common/PXProfileDeletionJournal.m', 'common/PXRuntimeProfileSelection.m',
                   'tests/PXRuntimeArtifactPreparationTests.m']
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            binary = folder / scheme
            subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions',
                            '-DPX_SOURCE_TRANSACTION_TESTING=1', '-Darc4random_uniform=PXPreparationFixtureRandom',
                            '-Wall', '-Wextra', '-Werror=implicit-function-declaration',
                            '-I', str(ROOT / 'common'), '-I', str(folder), *defines,
                            *[str(ROOT / source) for source in sources], '-framework', 'Foundation', '-framework', 'CoreFoundation',
                            '-o', str(binary)], check=True, cwd=ROOT, timeout=60)
            for _ in range(3):
                subprocess.run([str(binary)], check=True, cwd=ROOT, timeout=60)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        native_tests()
