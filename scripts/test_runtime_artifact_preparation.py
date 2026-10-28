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
    'PXOwnedWiFiMethods.inc': ('common/WiFiManager.m', [
        '- (instancetype)init', '- (void)registerForProfileNotifications', '- (id)profileManagerForWiFi',
        '- (NSString *)getCurrentProfileID', '- (NSString *)profileIDFromManager:(id)manager',
        '- (void)loadWiFiInfoFromCurrentProfile', '- (void)loadWiFiInfoForProfileID:(NSString *)profileID',
        '- (void)saveWiFiInfoToCurrentProfile', '- (NSDictionary *)generateWiFiInfo',
        '- (void)adoptCommittedWiFiInfo:(NSDictionary *)wifiInfo profileID:(NSString *)profileID',
        '- (NSDictionary *)currentWiFiInfo', '- (void)setCurrentWiFiInfo:(NSDictionary *)wifiInfo',
        '- (BOOL)isValidSSID:(NSString *)ssid', '- (BOOL)isValidBSSID:(NSString *)bssid', '- (void)dealloc']),
    'PXPreparedBatteryMethods.inc': ('common/BatteryManager.m', ['- (NSString *)randomizeBatteryLevel', '- (NSDictionary *)generateBatteryInfo', '- (void)adoptCommittedBatteryInfo:(NSDictionary *)batteryInfo', '- (void)publishCommittedBatteryInfo:(NSDictionary *)batteryInfo timestamp:(NSDate *)timestamp',
        '- (NSDictionary *)batteryRecordForLevel:(NSString *)level lowPowerMode:(BOOL)enabled',
        '- (BOOL)mirrorBatteryRecord:(NSDictionary *)record error:(NSError **)error']),
    'PXOwnedBatteryMethods.inc': ('common/BatteryManager.m', [
        '- (NSString *)batteryLevel', '- (void)setBatteryLevel:(NSString *)level', '- (NSString *)generateBatteryLevel',
        '- (NSString *)randomizeBatteryLevel', '- (BOOL)lowPowerModeEnabled', '- (void)setLowPowerModeEnabled:(BOOL)enabled',
        '- (NSDictionary *)generateBatteryInfo', '- (void)adoptCommittedBatteryInfo:(NSDictionary *)batteryInfo',
        '- (void)publishCommittedBatteryInfo:(NSDictionary *)batteryInfo timestamp:(NSDate *)timestamp', '- (NSError *)lastError',
        '- (NSString *)batteryInfoPathForCurrentProfile', '- (void)loadBatteryInfoFromDisk', '- (void)saveBatteryInfoToDisk',
        '- (NSDictionary *)batteryRecordForLevel:(NSString *)level lowPowerMode:(BOOL)enabled',
        '- (BOOL)persistBatteryRecord:(NSDictionary *)record', '- (BOOL)mirrorBatteryRecord:(NSDictionary *)record error:(NSError **)error']),
    'PXPreparedStorageMethod.inc': ('common/StorageManager.m', ['- (NSDictionary *)generateStorageForCapacity:(NSString *)capacity', '- (void)adoptCommittedStorageInfo:(NSDictionary *)storageInfo', '- (NSDictionary *)currentStorageInfo',
        '- (void)saveToCurrentProfile', '- (void)saveToProfile:(NSString *)profileId',
        '- (BOOL)persistStorageToProfile:(NSString *)profileID current:(BOOL)current error:(NSError **)error',
        '- (void)setTotalStorageCapacity:(NSString *)capacity', '- (void)setFreeStorageSpace:(NSString *)freeSpace', '- (void)setFilesystemType:(NSString *)fsType']),
    'PXPreparedUptimeMethod.inc': ('common/UptimeManager.m', ['- (void)generateConsistentUptimeAndBootTimeForProfile:(NSString *)profilePath', '- (void)adoptCommittedUptimeInfo:(NSDictionary *)uptimeInfo timestamp:(NSDate *)timestamp',
        '- (NSDictionary *)prepareConsistentUptimeInfo',
        '- (NSTimeInterval)currentUptimeForProfile:(NSString *)profilePath',
        '- (NSDate *)currentBootTimeForProfile:(NSString *)profilePath',
        '- (NSTimeInterval)currentUptimeForProfile:(NSString *)profilePath generateIfMissing:(BOOL)generateIfMissing',
        '- (NSDate *)currentBootTimeForProfile:(NSString *)profilePath generateIfMissing:(BOOL)generateIfMissing']),
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
    wifi_source = read('common/WiFiManager.m')
    save_wifi = identifier.method(wifi_source, '- (void)saveWiFiInfoToCurrentProfile')
    assert save_wifi.index('[self profileManagerForWiFi]') < save_wifi.index('acquireWithIdentityResolver:') < save_wifi.index('[self.wifiInfo copy]')
    assert '[self profileIDFromManager:manager]' in save_wifi and '[mutation performSourceWrite:' in save_wifi
    assert '@finally { [mutation invalidate]; }' in save_wifi and 'createDirectoryAtPath:' not in save_wifi
    assert 'PXPerformRuntimeSourceWrite' not in wifi_source
    observer = identifier.method(wifi_source, '- (void)registerForProfileNotifications')
    assert '@synchronized (self)' in observer and 'if (self.profileChangeObserver) return;' in observer
    assert '__weak typeof(self) weakSelf' in observer and '__strong typeof(weakSelf) owner' in observer
    assert 'loadWiFiInfoFromCurrentProfile' in observer and 'currentProfileId = eventID' not in observer
    assert '@property (nonatomic, strong) id profileChangeObserver;' in wifi_source
    profile_manager = identifier.method(wifi_source, '- (id)profileManagerForWiFi')
    assert 'respondsToSelector:@selector(sharedManager)' in profile_manager
    loader = identifier.method(wifi_source, '- (void)loadWiFiInfoForProfileID:(NSString *)profileID')
    assert loader.index('self.wifiInfo = [NSMutableDictionary dictionary]') < loader.index('dictionaryWithContentsOfFile:')
    assert 'PXProfileIdentityPath(target)' in loader and 'PXProfilesPath()' not in loader
    getter = identifier.method(wifi_source, '- (NSDictionary *)currentWiFiInfo')
    assert getter.count('getCurrentProfileID') == 1 and 'loadWiFiInfoForProfileID:currentID' in getter

    battery = identifier.method(read('common/BatteryManager.m'), '- (NSDictionary *)generateBatteryInfo')
    assert 'PXPrepareRuntimeBatteryInfo(_currentLowPowerMode)' in battery
    assert battery.count('[self persistBatteryRecord:record]') == 1 and 'randomizeBatteryLevel' not in battery
    assert battery.index('[self persistBatteryRecord:record]') < battery.index('postNotificationName:')
    battery_source = read('common/BatteryManager.m')
    persist_battery = identifier.method(battery_source, '- (BOOL)persistBatteryRecord:(NSDictionary *)record')
    assert persist_battery.index('acquireInDirectory:PXProfilesPath()') < persist_battery.index('PXRequireNoPendingProfileDeletion') < persist_battery.index('dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()')
    assert 'borrowWithLifecycleLease:lease' in persist_battery and 'PXStageRuntimeBattery' in persist_battery
    assert persist_battery.index('[mutation performSourceWrite:') < persist_battery.index('[lease invalidate]') < persist_battery.index('[self mirrorBatteryRecord:')
    assert 'if (!profileCommitted)' in persist_battery and 'if (!mirrored && !profileCommitted)' in persist_battery
    assert '@finally' in persist_battery and 'createDirectoryAtPath:' not in persist_battery
    path_reader = identifier.method(battery_source, '- (NSString *)batteryInfoPathForCurrentProfile')
    assert 'createDirectoryAtPath:' not in path_reader and 'PXProfileArtifactMutation' not in path_reader and 'PXLog(' not in path_reader
    level_reader = identifier.method(battery_source, '- (NSString *)batteryLevel')
    assert 'saveBatteryInfoToDisk' not in level_reader and level_reader.count('[self generateBatteryLevel]') == 2
    low_power = identifier.method(battery_source, '- (void)setLowPowerModeEnabled:(BOOL)enabled')
    assert low_power.index('if (![self persistBatteryRecord:record]) return;') < low_power.index('postNotificationName:')
    assert 'if (![self persistBatteryRecord:record]) return batteryInfo;' in battery

    assert 'PXPrepareRuntimeStorage(capacity)' in read('common/StorageManager.m')
    uptime = identifier.method(read('common/UptimeManager.m'), WRAPPERS['PXPreparedUptimeMethod.inc'][1][0])
    provider = identifier.method(read('common/UptimeManager.m'), '- (NSDictionary *)prepareConsistentUptimeInfo')
    assert 'PXPrepareRuntimeUptime(now, realUptime, sysctlResult == 0)' in provider
    assert uptime.index('acquireWithIdentityResolver:') < uptime.index('[self prepareConsistentUptimeInfo]') < uptime.index('[mutation performSourceWrite:')
    assert uptime.index('[mutation invalidate]') < uptime.index('self.bootTimeValue = bootTime')
    assert '@finally { [mutation invalidate]; }' in uptime and 'createDirectoryAtPath:' not in uptime
    for typename, name, sentinel in (('NSTimeInterval', 'currentUptimeForProfile', '0'), ('NSDate *', 'currentBootTimeForProfile', 'nil')):
        typename = typename.rstrip()
        signature = f'- ({typename}){name}:(NSString *)profilePath generateIfMissing:(BOOL)generateIfMissing'
        body = identifier.method(read('common/UptimeManager.m'), signature)
        assert f'if (!generateIfMissing) return {sentinel};' in body
        assert body.index('if (!generateIfMissing)') < body.index('[self generateConsistentUptimeAndBootTimeForProfile:')
    for case in ('read only uptime preserves boot precedence and avoids lock generation persistence and cache adoption',
                 'read only uptime preserves elapsed sidecar and boot scalar fallbacks',
                 'malformed uptime sidecar fields fall through instead of sending unsafe selectors',
                 'read only missing or malformed uptime returns sentinel without creating profile or source',
                 'legacy uptime getters retain safe default policy when generation is busy'):
        assert case in read('tests/PXRuntimeArtifactPreparationTests.m'), case
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
    # Extracting method bodies does not bring their production file's imports.
    # The linked .m supplies a definition, but clang also needs its real header
    # before parsing the extracted call (C99 rejects implicit declarations).
    assert fixture.index('#import "PXProfileDeletionJournal.h"') < fixture.index('#include "PXOwnedBatteryMethods.inc"')
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
    for case in ('WiFi observer registration is idempotent and retains one token',
                 'WiFi profile notification clears old cache on missing target without writing source',
                 'WiFi missing-profile getter generates B instead of returning or overwriting A',
                 'WiFi cached read hit adds no lifecycle or source transaction',
                 'WiFi malformed reload clears cache instead of retaining previous data',
                 'busy WiFi persistence stops before target resolution snapshot and source writes',
                 'pending deletion stops WiFi persistence before cache snapshot',
                 'WiFi persistence never recreates missing identity directory',
                 'WiFi snapshot excludes reentrant storage persistence',
                 'WiFi persistence captures one target and never redirects during snapshot',
                 'WiFi read after source-target switch reloads actual active profile',
                 'WiFi source failure rolls back wifi and IDs before error logging',
                 'WiFi snapshot exception releases scope and preserves source',
                 'late journal rejects WiFi candidate before paired staging',
                 'WiFi persistence rejects missing replaced and symlink identity without recreating it',
                 'WiFi custom setter retains MAC validation and rejects all-zero address',
                 'WiFi custom setter persists candidate through owned paired commit',
                 'WiFi persistence preserves optional manager-first profile authority',
                 'WiFi fallback retains numeric profile ID normalization',
                 'WiFi default fallback keeps ephemeral cache without repeated generation or directory writes',
                 'WiFi observer does not retain manager and dealloc removes its token',
                 'queued WiFi notification reloads current authority and safely ignores deallocated observer owner'):
        assert case in fixture, case
    for case in ('battery generation commits once before mirror and both notifications',
                 'battery legacy mirror preserves complete source record at XML precision',
                 'fractional battery timestamp matches real legacy XML round trip',
                 'legacy mirror oracle rejects changed battery level',
                 'legacy mirror oracle rejects changed low power mode',
                 'legacy mirror oracle rejects different timestamp beyond XML precision',
                 'legacy mirror oracle rejects omitted timestamp',
                 'legacy mirror oracle rejects extra fields',
                 'battery profile commit precedes global mirror with the same captured record',
                 'busy battery leaves profile mirror and notifications untouched while returning legacy candidate',
                 'pending delete blocks battery source mirror and notifications',
                 'invalid active battery ID never downgrades into global-only success',
                 'missing battery identity cannot create directory or update global mirror',
                 'battery source rollback preserves old mirror and suppresses success notifications',
                 'profile battery success survives failed legacy mirror without false rollback',
                 'global-only battery mirror failure is not announced as persisted success',
                 'no-active battery preserves coordinated global-only save without profile source commit',
                 'battery read preserves legacy fallback and missing LPM default without directory writes or lease',
                 'battery captures immutable level once for profile and mirror',
                 'battery getter repair performs one save instead of duplicate persistence',
                 'owned battery persistence retains no-new-device-IDs policy',
                 'missing battery record reports failure without mirror or success notification',
                 'battery global read fallback works when profiles root is unavailable',
                 'battery mutation refuses unavailable lifecycle namespace without creating root or changing mirror',
                 'borrowed artifact invalidation preserves caller lifecycle ownership',
                 'failed borrowed artifact resolution leaves caller ownership intact',
                 'throwing borrowed artifact resolver cannot release caller lease',
                 'nil borrowed capability never silently acquires an owned lease',
                 'borrowed artifact scope rejects replaced identity while keeping caller lease',
                 'borrowed artifact scope rejects late deletion before staging',
                 'wrong-root borrowed artifact capability is rejected without invalidating it',
                 'released borrowed artifact capability is rejected'):
        assert case in fixture, case
    assert 'test_runtime_artifact_preparation.py --native' in read('.github/workflows/build-ios-arm.yml')
    # The common glob carries the new factory into both manager app and tweak.
    make = read('Makefile')
    assert 'TLinkIOS_FILES = $(wildcard *.m) $(wildcard common/*.m)' in make
    assert 'TLinkIOSTweak_FILES =' in make and '$(wildcard common/*.m)' in make
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2H3U-partial'
    assert manifest['writers']['identifier-artifacts']['status'] == 'enrolled'
    assert manifest['writers']['profile-lifecycle']['status'] == 'partial'
    print('PASS: Artifact preparation and battery/WiFi/storage/uptime ownership contracts (remaining writers partial; native runtime not implied)')


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
