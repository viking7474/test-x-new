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
STORAGE_READ_SIGNATURES = [
    '- (NSString *)totalStorageCapacity', '- (NSString *)freeStorageSpace', '- (NSString *)filesystemType',
    '- (uint64_t)convertGBStringToBytes:(id)gbString', '- (uint64_t)normalizeStorageBytes:(uint64_t)bytes',
    '- (uint64_t)convertGBStringToBytes:(id)gbString useBinaryUnits:(BOOL)useBinary',
    '- (uint64_t)normalizeStorageBytes:(uint64_t)bytes useMarketingUnits:(BOOL)useMarketingUnits',
    '- (uint64_t)totalStorageCapacityInBinaryBytes', '- (uint64_t)totalStorageCapacityInMarketingBytes',
    '- (uint64_t)freeStorageSpaceInBinaryBytes', '- (uint64_t)freeStorageSpaceInMarketingBytes',
    '- (uint64_t)normalizedTotalStorageForDisplay:(BOOL)useMarketingUnits', '- (uint64_t)normalizedFreeStorageForDisplay:(BOOL)useMarketingUnits',
    '- (NSString *)randomizeStorageCapacity', '- (NSString *)randomizeStorageCapacityForProfile:(NSString *)profileID',
    '- (NSString *)randomizeStorageCapacityForDeviceModel:(NSString *)deviceModel',
    '- (void)setDefaultStorage', '- (void)setDefaultStorageForProfile:(NSString *)profileID',
    '- (void)loadFromCurrentProfile', '- (BOOL)loadFromProfile:(NSString *)profileId',
]
STORAGE_OBJC_METHODS = [
    ('- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path error:(NSError **)error', '[self fixtureAttributes:path error:error]'),
    ('- (unsigned long long)volumeAvailableCapacityForImportantUsageForURL:(NSURL *)url error:(NSError **)error', '[self fixtureCapacity:url error:error]'),
    ('- (unsigned long long)volumeTotalCapacityForURL:(NSURL *)url error:(NSError **)error', '[self fixtureCapacity:url error:error]'),
    ('- (unsigned long long)volumeAvailableCapacityForOpportunisticUsageForURL:(NSURL *)url error:(NSError **)error', '[self fixtureCapacity:url error:error]'),
    ('- (BOOL)getResourceValue:(id *)value forKey:(NSURLResourceKey)key error:(NSError **)error', '[self fixtureResource:value key:key error:error]'),
    ('- (NSDictionary<NSURLResourceKey, id> *)resourceValuesForKeys:(NSArray<NSURLResourceKey> *)keys error:(NSError **)error', '[self fixtureResources:keys error:error]'),
]
STORAGE_OBJC_HELPERS = [
    'static NSUInteger PXStorageCapacityKeyKind(id key)', 'static BOOL PXStorageKeysContainCapacity(id keys)',
    'static BOOL PXStorageAttributesHaveCapacity(id values)', 'static BOOL PXStorageResourceValuesHaveCapacity(id values, id keys)',
    'static NSNumber *PXStorageCapacityValue(NSUInteger kind, uint64_t total, uint64_t free)',
    'static NSDictionary *PXStorageAttributesWithCapacity(NSDictionary *original, uint64_t total, uint64_t free)',
    'static NSDictionary *PXStorageResourceValuesWithCapacity(NSDictionary *original, NSArray *keys, uint64_t total, uint64_t free)',
    'static const char *PXStorageSkipTypeQualifiers(const char *type)', 'static BOOL PXStorageObjectEncoding(const char *type)',
    'static BOOL PXStorageCapacityCompatibilityMatches(Class cls, SEL selector)',
]
WIFI_CF_SIGNATURES = [
    'static BOOL PXWiFiInfoHasIdentity(id info)',
    'static CFDictionaryRef PXCreateSpoofedNetworkInfoDict(NSString *ssid, NSString *bssid)',
    'static CFTypeRef PXWiFiReplaceOwnedCopy(CFTypeRef original, CFTypeRef replacement)',
    'static CFDictionaryRef replaced_CNCopyCurrentNetworkInfo(CFStringRef interfaceName)',
    'static CFArrayRef replaced_CNCopySupportedInterfaces(void)',
    'static int replaced_Apple80211GetInfoCopy(void *handle, CFDictionaryRef *info)',
    'static id replaced_dictionaryWithScanResult(id self, SEL _cmd, id arg1)',
]
WIFI_FETCH_SIGNATURES = [
    'static id PXCreateSpoofedNEHotspotNetwork(NSString *ssid, NSString *bssid)',
    'static void replaced_NEHotspotNetwork_fetchCurrent(id self, SEL _cmd, void (^completion)(id network))',
]
WIFI_MANAGER_CACHE_METHODS = [
    '- (uint64_t)beginWiFiCacheUpdate', '- (BOOL)wiFiCacheRevisionIsCurrent:(uint64_t)revision',
    '- (uint64_t)publishWiFiCache:(NSMutableDictionary *)info profileID:(NSString *)profileID revision:(uint64_t)revision readable:(BOOL)readable',
    '- (NSDictionary *)wiFiCacheSnapshotForProfileID:(NSString *)profileID requireReadable:(BOOL)readable',
    '- (void)setWiFiCacheError:(NSError *)error revision:(uint64_t)revision',
]
WIFI_MANAGER_READERS = [
    '- (id)wiFiCachedValueForKey:(NSString *)key valueClass:(Class)valueClass',
    '- (NSDictionary *)cachedWiFiDisplayInfo', '- (NSString *)currentSSID', '- (NSString *)currentBSSID',
    '- (NSString *)currentNetworkType', '- (NSString *)currentWiFiStandard', '- (BOOL)currentAutoJoinStatus', '- (NSDate *)lastConnectionTime',
]
WIFI_MANAGER_RESOLUTION = [
    '- (NSString *)profileIDFromManager:(id)manager', '- (NSString *)getCurrentProfileID',
    '- (void)loadWiFiInfoFromCurrentProfile', '- (void)handleWiFiProfileNotification:(NSNotification *)note',
]
WIFI_MANAGER_LOAD = '- (uint64_t)loadWiFiInfoForProfileID:(NSString *)profileID revision:(uint64_t)revision'
WIFI_MANAGER_GENERATE = '- (NSDictionary *)generateWiFiInfoAtRevision:(uint64_t)revision'
WIFI_MANAGER_CAS = '- (uint64_t)beginWiFiCacheUpdateIfRevision:(uint64_t)revision'
WIFI_MANAGER_SAVE = '- (void)saveWiFiInfoToCurrentProfileAtRevision:(uint64_t)revision'
WIFI_GETTER_HELPERS = ['static BOOL PXWiFiGetterAllowed(void)', 'static NSString *PXWiFiGetterString(NSString *key)']
WIFI_GETTER_METHODS = ['- (NSString *)weaponx_SSID', '- (NSString *)weaponx_BSSID',
                       '- (double)weaponx_signalStrength', '- (BOOL)weaponx_secure']
WIFI_GETTER_CF = ['static CFStringRef replaced_WiFiNetworkGetSSID(WiFiNetworkRef network)',
                  'static CFStringRef replaced_WiFiNetworkGetBSSID(WiFiNetworkRef network)']
WIFI_GETTER_PATH = [('- (NSString *)_getSSID', '[self originalSSID]'), ('- (id)_getBSSID', '[self originalBSSID]')]
CF_EXCEPTION_MODES = (('plain-arc', '-fno-objc-arc-exceptions'), ('arc-eh', '-fobjc-arc-exceptions'))
WRAPPERS = {
    'PXPreparedWiFiMethod.inc': ('common/WiFiManager.m', [*WIFI_MANAGER_CACHE_METHODS, WIFI_MANAGER_CAS, WIFI_MANAGER_GENERATE, '- (NSDictionary *)generateWiFiInfo', '- (void)adoptCommittedWiFiInfo:(NSDictionary *)wifiInfo profileID:(NSString *)profileID']),
    'PXOwnedWiFiMethods.inc': ('common/WiFiManager.m', [*WIFI_MANAGER_CACHE_METHODS, WIFI_MANAGER_CAS, WIFI_MANAGER_SAVE, WIFI_MANAGER_LOAD, WIFI_MANAGER_GENERATE, WIFI_MANAGER_RESOLUTION[3],
        '- (instancetype)init', '- (void)registerForProfileNotifications', '- (id)profileManagerForWiFi',
        '- (NSString *)getCurrentProfileID', '- (NSString *)profileIDFromManager:(id)manager',
        '- (void)loadWiFiInfoFromCurrentProfile', '- (void)loadWiFiInfoForProfileID:(NSString *)profileID',
        '- (void)saveWiFiInfoToCurrentProfile', '- (NSDictionary *)generateWiFiInfo',
        '- (void)adoptCommittedWiFiInfo:(NSDictionary *)wifiInfo profileID:(NSString *)profileID',
        '- (NSDictionary *)currentWiFiInfo', '- (NSDictionary *)cachedWiFiInfoForProfileID:(NSString *)profileID', '- (void)setCurrentWiFiInfo:(NSDictionary *)wifiInfo',
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
        *STORAGE_READ_SIGNATURES,
        '- (BOOL)commitDisplayStorageInfo:(NSDictionary *)values updateFilesystem:(BOOL)updateFilesystem error:(NSError **)error',
        '- (void)saveToCurrentProfile', '- (void)saveToProfile:(NSString *)profileId',
        '- (BOOL)persistStorageToProfile:(NSString *)profileID current:(BOOL)current error:(NSError **)error',
        '- (void)setTotalStorageCapacity:(NSString *)capacity', '- (void)setFreeStorageSpace:(NSString *)freeSpace', '- (void)setFilesystemType:(NSString *)fsType',
        '- (BOOL)isStorageSpoofingEnabled', '- (void)setStorageSpoofingEnabled:(BOOL)enabled',
        '- (BOOL)setStorageSpoofingEnabled:(BOOL)enabled error:(NSError **)error']),
    'PXPreparedUptimeMethod.inc': ('common/UptimeManager.m', ['- (void)generateConsistentUptimeAndBootTimeForProfile:(NSString *)profilePath', '- (void)adoptCommittedUptimeInfo:(NSDictionary *)uptimeInfo timestamp:(NSDate *)timestamp',
        '- (NSDictionary *)prepareConsistentUptimeInfo',
        '- (NSTimeInterval)currentUptimeForProfile:(NSString *)profilePath',
        '- (NSDate *)currentBootTimeForProfile:(NSString *)profilePath',
        '- (NSTimeInterval)currentUptimeForProfile:(NSString *)profilePath generateIfMissing:(BOOL)generateIfMissing',
        '- (NSDate *)currentBootTimeForProfile:(NSString *)profilePath generateIfMissing:(BOOL)generateIfMissing']),
}


def source_contracts():
    from test_profile_creation_flow import check_macro_arity
    preparation = read('common/PXRuntimeArtifactPreparation.m')
    for forbidden in ('PXActiveProfile', 'PXProfile', 'NSFileManager', 'writeToFile:', 'dictionaryWithContentsOfFile:',
                      'PXPerformRuntimeSourceWrite', 'dispatch_', 'NSNotification', 'PXLog(', 'self.', 'sharedManager', 'sysctl('):
        assert forbidden not in preparation, f'prepare API may not have effects: {forbidden}'
    assert '-(NSTimeInterval)arc4random_uniform(86400)' in preparation, 'unsigned time offset must not wrap into the future'
    assert 'if (uptime < minUptime) uptime = minUptime;' in preparation
    assert 'UINT64_MAX / 1e9' in preparation and '!isfinite(parsedCapacity)' in preparation
    wifi = identifier.method(read('common/WiFiManager.m'), WIFI_MANAGER_GENERATE)
    assert 'PXPrepareRuntimeWiFiInfo()' in wifi and wifi.count('saveWiFiInfoToCurrentProfile') == 1
    wifi_source = read('common/WiFiManager.m')
    save_wifi = identifier.method(wifi_source, WIFI_MANAGER_SAVE)
    assert save_wifi.index('[self profileManagerForWiFi]') < save_wifi.index('acquireWithIdentityResolver:') < save_wifi.index('[candidate copy]')
    assert '[self profileIDFromManager:manager]' in save_wifi and '[mutation performSourceWrite:' in save_wifi
    assert '@finally' in save_wifi and 'prepared = nil; candidate = nil; mutation = nil;' in save_wifi
    assert 'createDirectoryAtPath:' not in save_wifi
    assert 'PXPerformRuntimeSourceWrite' not in wifi_source
    begin = identifier.method(wifi_source, WIFI_MANAGER_CACHE_METHODS[0])
    assert '@synchronized (self)' in begin and '++_wifiCacheRevision' in begin and '_wifiCacheReadable = NO;' in begin
    publish = identifier.method(wifi_source, WIFI_MANAGER_CACHE_METHODS[2])
    assert 'revision == _wifiCacheRevision' in publish and '++_wifiCacheRevision' in publish
    assert publish.index('discardedInfo = self.wifiInfo') < publish.index('self.wifiInfo = info; self.currentProfileId = profileID;')
    assert 'objc_precise_lifetime' in publish and '(void)discardedInfo; (void)discardedID;' in publish
    snapshot = identifier.method(wifi_source, WIFI_MANAGER_CACHE_METHODS[3])
    assert snapshot.index('@synchronized (self)') < snapshot.index('result = [info copy];') < snapshot.index('wiFiCacheRevisionIsCurrent:revision')
    assert 'eligible = !readable || _wifiCacheReadable;' in snapshot and 'result = nil; owner = nil; info = nil;' in snapshot
    for body in (begin, publish, snapshot):
        for forbidden in ('dictionaryWithContentsOfFile:', 'profileManagerForWiFi', 'performSourceWrite:', 'dispatch_'):
            assert forbidden not in body
    assert '@property (atomic, strong) NSMutableDictionary *wifiInfo;' in wifi_source
    assert '@property (atomic, strong) NSString *currentProfileId;' in wifi_source
    for signature in (WIFI_MANAGER_GENERATE, '- (void)setCurrentWiFiInfo:(NSDictionary *)wifiInfo'):
        candidate = identifier.method(wifi_source, signature)
        assert 'readable:NO' in candidate and 'saveWiFiInfoToCurrentProfileAtRevision:revision' in candidate
    setter = identifier.method(wifi_source, '- (void)setCurrentWiFiInfo:(NSDictionary *)wifiInfo')
    assert setter.index('revision = _wifiCacheRevision') < setter.index('[wifiInfo isKindOfClass:NSDictionary.class]')
    assert setter.index('candidate = [wifiInfo mutableCopy]') < setter.index('rawSSID = candidate[@"ssid"]')
    assert '[wifiInfo[@' not in setter and 'wifiInfo[@' not in setter
    assert 'isKindOfClass:NSMutableDictionary.class' in setter
    assert '[rawSSID copy]' in setter and '[rawBSSID copy]' in setter
    assert setter.index('[rawSSID copy]') < setter.index('PXValidateIdentityValue(ssid, PXIdentityValueKindSSID, NO)')
    assert setter.index('[rawBSSID copy]') < setter.index('PXValidateIdentityValue(bssid, PXIdentityValueKindMACAddress, NO)')
    assert setter.index('candidate[@"ssid"] = ssid; candidate[@"bssid"] = bssid;') < setter.index('beginWiFiCacheUpdateIfRevision:revision')
    assert setter.index('beginWiFiCacheUpdateIfRevision:revision') < setter.index('publishWiFiCache:candidate') < setter.index('saveWiFiInfoToCurrentProfileAtRevision:revision')
    assert '[self setWiFiCacheError:failure revision:revision]' in setter and 'self.error =' not in setter
    assert '[self isValidSSID:' not in setter and '[self isValidBSSID:' not in setter
    assert 'beginWiFiCacheUpdate]' not in setter
    assert '@finally' in setter and 'rawSSID = nil; rawBSSID = nil;' in setter
    value_reader = identifier.method(wifi_source, WIFI_MANAGER_READERS[0])
    assert value_reader.index('isKindOfClass:NSDictionary.class') < value_reader.index('value = info[key]')
    assert 'isKindOfClass:valueClass' in value_reader and '@finally' in value_reader
    display_cache = identifier.method(wifi_source, WIFI_MANAGER_READERS[1])
    assert display_cache.index('@synchronized (self)') < display_cache.index('result = [info copy]') < display_cache.index('wiFiCacheRevisionIsCurrent:revision')
    for body in (value_reader, display_cache):
        for token in ('loadWiFi', 'generateWiFi', 'getCurrentProfileID', 'profileManagerForWiFi', 'self.error', 'dictionaryWithContentsOfFile:', 'performSourceWrite:', 'dispatch_'):
            assert token not in body
    for signature in WIFI_MANAGER_READERS[2:]:
        assert 'wiFiCachedValueForKey:' in identifier.method(wifi_source, signature)
    auto_join = identifier.method(wifi_source, '- (BOOL)currentAutoJoinStatus')
    assert 'respondsToSelector:@selector(boolValue)' in auto_join and '@catch' in auto_join and '@finally' in auto_join
    check_macro_arity(read('tests/PXWiFiManagerCacheTests.m'), 'PXWiFiManagerCacheTests.m')
    wifi_hooks = read('TLinkIOSTweak/WiFiHook.x')
    wifi_cache_read = identifier.method(wifi_hooks, 'static NSDictionary *PXWiFiCachedInfo(NSString *profileId, NSTimeInterval now, uint64_t *generation)')
    wifi_cache_publish = identifier.method(wifi_hooks, 'static NSDictionary *PXWiFiPublishInfo(NSDictionary *info, NSString *profileId, NSTimeInterval now, uint64_t generation)')
    wifi_cache_clear = identifier.method(wifi_hooks, 'static void PXWiFiInvalidateCache(void)')
    assert 'if (generation) *generation = gWiFiCacheGeneration;' in wifi_cache_read
    assert 'now >= gWiFiCacheLoadedAt' in wifi_cache_read and 'now - gWiFiCacheLoadedAt <= kCacheValidityDuration' in wifi_cache_read
    assert 'generation == gWiFiCacheGeneration' in wifi_cache_publish and 'gWiFiCacheGeneration++;' in wifi_cache_clear
    assert wifi_cache_publish.index('NSPropertyListImmutable') < wifi_cache_publish.index('os_unfair_lock_lock')
    assert wifi_cache_publish.index('[profileId copy]') < wifi_cache_publish.index('os_unfair_lock_lock')
    assert wifi_cache_publish.index('os_unfair_lock_unlock') < wifi_cache_publish.index('[publishedProfile isEqualToString:frozenProfile]')
    for body in (wifi_cache_read, wifi_cache_publish, wifi_cache_clear):
        for name in ('discardedInfo', 'discardedProfile'):
            assert f'objc_precise_lifetime)) ' in body and f'{name} =' in body
            assert body.index('os_unfair_lock_unlock') < body.index(f'(void){name};')
    wifi_identity = identifier.method(wifi_hooks, 'static BOOL PXWiFiInfoHasIdentity(id info)')
    assert 'isKindOfClass:NSDictionary.class' in wifi_identity and wifi_identity.count('isKindOfClass:NSString.class') == 2
    wifi_reader = identifier.method(wifi_hooks, 'static NSDictionary *getProfileWiFiInfo(void)')
    assert 'PXWiFiCachedInfo(profileId, now, &generation)' in wifi_reader and 'PXWiFiPublishInfo(resolved, profileId, now, generation)' in wifi_reader
    assert 'cacheTimestamp' not in wifi_hooks and 'CLOCK_MONOTONIC' in wifi_hooks
    assert 'resolved ? Nil : NSClassFromString(@"WiFiManager")' in wifi_reader and wifi_reader.count('NSClassFromString(@"WiFiManager")') == 1
    assert 'respondsToSelector:@selector(sharedManager)' in wifi_reader
    assert 'PXWiFiInfoHasIdentity(wifiInfo)' in wifi_reader
    assert 'PXResolveHookWiFiInfo(profileId,' in wifi_reader and '[manager cachedWiFiInfoForProfileID:target]' in wifi_reader
    assert wifi_reader.count('profileId = getCurrentProfileID();') == 1
    assert wifi_reader.index('profileId = getCurrentProfileID();') < wifi_reader.index('PXWiFiCachedInfo(profileId, now, &generation)')
    assert wifi_reader.index('if (cached) return cached;') < wifi_reader.index('identityDir = PXProfileIdentityPath(profileId);')
    assert wifi_reader.count('PXProfileIdentityPath(profileId)') == 1 and 'PXProfileDeviceIDsPath(profileId)' not in wifi_reader
    assert 'deviceIdsPath = [identityDir stringByAppendingPathComponent:@"device_ids.plist"];' in wifi_reader
    assert '@finally { manager = nil; target = nil; }' in wifi_reader
    assert 'deviceIds = nil; wifiInfo = nil; resolved = nil; cached = nil;' in wifi_reader
    assert 'wifiInfoPath = nil; deviceIdsPath = nil; identityDir = nil; profileId = nil;' in wifi_reader
    assert '@finally { detached = nil; data = nil; }' in wifi_cache_publish
    assert 'immutable = nil; frozenProfile = nil; profileId = nil; info = nil;' in wifi_cache_publish
    assert 'discardedProfile = nil; discardedInfo = nil; profileId = nil;' in wifi_cache_read
    assert '@finally { info = nil; }' in wifi_identity
    reader_fixture = read('tests/PXWiFiHookCacheTests.m')
    assert reader_fixture.count('TestCacheExceptionalLifetime();') == 1
    for case in ('warm WiFi reader keeps active-selection checks but constructs no artifact identity paths',
                 'WiFi failed freeze releases encoded data and decoded graph after pool drain',
                 'WiFi reader unwinding releases its retained artifact root after pool drain',
                 'WiFi cache-reader callback releases its manager on exceptional exit'):
        assert case in reader_fixture, case
    for forbidden in ('currentWiFiInfo]', 'generateWiFiInfo]', 'writeToFile:', 'createDirectoryAtPath:'):
        assert forbidden not in wifi_reader
    cached_wifi = identifier.method(wifi_source, '- (NSDictionary *)cachedWiFiInfoForProfileID:(NSString *)profileID')
    assert '[self wiFiCacheSnapshotForProfileID:target requireReadable:YES]' in cached_wifi
    for forbidden in ('generateWiFiInfo', 'saveWiFi', 'loadWiFi', 'getCurrentProfileID'): assert forbidden not in cached_wifi
    hook_resolver = read('common/PXWiFiHookResolver.m')
    owner = identifier.method(hook_resolver, 'NSDictionary *PXResolveHookWiFiInfo(NSString *profileID, PXWiFiHookCacheReader cacheReader, NSError **error)')
    assert owner.index('PXPerformStandaloneRuntimeSourceWrite(') < owner.index('cacheReader(target, &cacheError)') < owner.index('acquireWithIdentityResolver:')
    assert owner.index('PXWiFiHookSelection(tx, target, failure)') < owner.index('PXPrepareRuntimeWiFiInfo()')
    assert owner.index('PXRuntimeProfileSelectionMatches(') < owner.index('PXStageRuntimeWiFi(')
    assert 'nowWifi != wifiExists || nowIDs != idsExist' in owner and '![currentWifi isEqual:wifi] || ![currentIDs isEqual:ids]' in owner
    assert 'return committed ? prepared : nil;' in owner and '@finally { [mutation invalidate]; }' in owner
    assert owner.index('PXPerformStandaloneRuntimeSourceWrite(') < owner.index('if (gWiFiHookResolving)') < owner.index('cacheReader(target, &cacheError)')
    assert '@finally { gWiFiHookResolving = NO; }' in owner
    assert 'merged[@"WiFi"] = display;' in owner and 'preparedInput = PXPrepareRuntimeWiFiInfo();' in owner
    assert 'prepared = PXWiFiHookFreeze(preparedInput);' in owner
    assert '@finally { candidate = nil; cacheError = nil; }' in owner
    assert '@finally { target = nil; cacheReader = nil; profileID = nil; }' in owner
    assert 'mutation = nil; resolved = nil; ids = nil; wifi = nil; selection = nil;' in owner
    assert 'prepared = nil; preparedInput = nil; idsPath = nil; wifiPath = nil; cached = nil;' in owner
    assert '@finally { display = nil; merged = nil; currentIDs = nil; currentWifi = nil; tx = nil; }' in owner
    assert owner.index('[mutation invalidate]') < owner.index('mutation = nil; resolved = nil;') < owner.index('gWiFiHookResolving = NO;')
    freeze = identifier.method(hook_resolver, 'static NSDictionary *PXWiFiHookFreeze(id info)')
    assert freeze.index('PXWiFiHookHasPair(info)') < freeze.index('data = [NSPropertyListSerialization')
    assert freeze.index('PXWiFiHookHasPair(info)') < freeze.index('@try', freeze.index('@try') + 4)
    assert '@finally { frozen = nil; data = nil; info = nil; }' in freeze
    pair = identifier.method(hook_resolver, 'static BOOL PXWiFiHookHasPair(id info)')
    assert '@finally { info = nil; }' in pair
    source_info = identifier.method(hook_resolver, 'static NSDictionary *PXWiFiHookSourceInfo(NSDictionary *wifi, NSDictionary *ids)')
    assert '@finally { bssid = nil; ssid = nil; value = nil; ids = nil; wifi = nil; }' in source_info
    selection_helper = identifier.method(hook_resolver, 'static NSDictionary *PXWiFiHookSelection(PXRuntimeSourceTransaction *tx, NSString *target, NSError **error)')
    assert '@finally { legacy = nil; selected = nil; selection = nil; target = nil; tx = nil; }' in selection_helper
    resolver_fixture = read('tests/PXWiFiResolverLifetimeTests.m')
    check_macro_arity(resolver_fixture, 'PXWiFiResolverLifetimeTests.m')
    assert '#include "PXWiFiResolverLifetime.inc"' in resolver_fixture
    assert resolver_fixture.count('TestSuccessAndNestedGuard();') == 1
    for forbidden in ('createDirectoryAtPath:', 'writeToFile:', 'sharedManager', 'currentWiFiInfo', 'postNotification', 'dispatch_'):
        assert forbidden not in hook_resolver
    for field in ('SSID', 'BSSID'): assert f'[deviceIds[@"{field}"] isKindOfClass:NSString.class]' in wifi_reader
    check_macro_arity(read('tests/PXWiFiHookCacheTests.m'), 'PXWiFiHookCacheTests.m')
    swizzler = read('TLinkIOSTweak/MethodSwizzler.m')
    encoding_gate = identifier.method(swizzler, 'BOOL PXMethodHasCompatibleTypeEncoding(Method method, const char *encoding)')
    assert 'from.numberOfArguments < 2' in encoding_gate and 'from.numberOfArguments != to.numberOfArguments' in encoding_gate
    assert 'PXSwizzleTypeEqual(from.methodReturnType, to.methodReturnType)' in encoding_gate
    assert 'index < from.numberOfArguments' in encoding_gate and '[from getArgumentTypeAtIndex:index], [to getArgumentTypeAtIndex:index]' in encoding_gate
    install = identifier.method(swizzler, 'static void PXInstallLocalSwizzle(Class target, SEL original, SEL alias)')
    assert '@synchronized (MethodSwizzler.class)' in install and 'original == alias' in install
    assert install.index('PXSwizzlePairInstalled(') < install.index('method_exchangeImplementations(')
    assert install.index('calloc(') < install.index('class_addMethod(')
    assert install.index('PXSwizzleHasOwnSelector(target, original)') < install.index('method_exchangeImplementations(')
    assert install.index('PXSwizzleHasOwnSelector(target, alias)') < install.index('method_exchangeImplementations(')
    pair_gate = identifier.method(swizzler, 'static BOOL PXSwizzlePairInstalled(Class target, SEL original, SEL alias)')
    assert 'entry->original == alias && entry->alias == original' in pair_gate and 'PXSwizzleClassesRelated(target, entry->target)' in pair_gate
    assert 'class_isMetaClass(left) != class_isMetaClass(right)' in swizzler
    assert 'if (!methods) return NO;' in swizzler
    for group, selector in (('PXWiFiNWPathSSID', '_getSSID'), ('PXWiFiNWPathBSSID', '_getBSSID')):
        assert wifi_hooks.count('%group ' + group) == 1 and wifi_hooks.count('%init(' + group + ')') == 1
        assert 'pathClass && PXMethodHasCompatibleTypeEncoding(class_getInstanceMethod(pathClass, @selector(' + selector + ')), "@@:")' in wifi_hooks
    assert 'PXMethodHasCompatibleTypeEncoding(dictionaryMethod, "@@:@")' in wifi_hooks
    assert 'PXMethodHasCompatibleTypeEncoding(fetchMethod, "v@:@?")' in wifi_hooks
    assert 'method_setImplementation(' not in wifi_hooks and '%init;' not in wifi_hooks
    for retired in ('WiFiManagerClientCreate', 'WiFiDeviceClientCopyCurrentNetwork', '%hook NWPathMonitor',
                    'usesInterfaceType:', 'setPathUpdateHandler:', '- (id)currentPath', '- (NSInteger)quality',
                    '- (double)latency', '- (BOOL)isExpensive', '- (BOOL)isConstrained', '- (id)gatherDiagnostics'):
        assert retired not in wifi_hooks, retired
    check_macro_arity(read('tests/PXMethodSwizzlerTests.m'), 'PXMethodSwizzlerTests.m')
    allowed = identifier.method(wifi_hooks, WIFI_GETTER_HELPERS[0])
    assert 'return shouldSpoofForBundle(bundleID);' in allowed and 'return NO;' in allowed
    assert '@finally' in allowed and allowed.index('@finally') < allowed.rindex('bundleID = nil;')
    field = identifier.method(wifi_hooks, WIFI_GETTER_HELPERS[1])
    assert field.index('if (!PXWiFiGetterAllowed()) return nil;') < field.index('PXResolvedWiFiInfo()')
    assert field.index('isKindOfClass:NSDictionary.class') < field.index('value = info[key];')
    assert field.count('info[key]') == 1 and 'isKindOfClass:NSString.class' in field
    assert 'value = nil; info = nil;' in field and '@catch' in field and '@finally' in field
    assert '.length' not in field and 'PXWiFiInfoHasIdentity' not in field
    for signature in WIFI_GETTER_METHODS + WIFI_GETTER_CF + [row[0] for row in WIFI_GETTER_PATH]:
        body = identifier.method(wifi_hooks, signature)
        assert body.count('PX_RUNTIME_READ_OPERATION;') == 1 and '@catch' not in body
        assert 'dispatch_' not in body and 'NSClassFromString' not in body
        if 'signalStrength' not in signature and 'weaponx_secure' not in signature:
            assert body.count('PXWiFiGetterString(') == 1
    for signature in WIFI_GETTER_CF:
        body = identifier.method(wifi_hooks, signature)
        assert 'if (value) return CFStringCreateCopy(kCFAllocatorDefault, (__bridge CFStringRef)value);' in body
        assert '@finally' in body and 'value = nil;' in body
    strength = identifier.method(wifi_hooks, WIFI_GETTER_METHODS[2])
    assert '0.7 + ((double)arc4random_uniform(20) / 100.0)' in strength
    assert '!PXWiFiGetterAllowed()' in strength
    secure = identifier.method(wifi_hooks, WIFI_GETTER_METHODS[3])
    assert '!PXWiFiGetterAllowed()' in secure and 'return YES;' in secure
    getter_fixture = read('tests/PXWiFiGetterTests.m')
    check_macro_arity(getter_fixture, 'PXWiFiGetterTests.m')
    for call in ('TestObjectGetters();', 'TestScalarGetters();', 'TestCGetters();', 'TestFailureAndLifetime();'):
        assert getter_fixture.count(call) == 1
    factory = identifier.method(wifi_hooks, WIFI_FETCH_SIGNATURES[0])
    assert factory.index('isKindOfClass:NSString.class') < factory.index('NSClassFromString(')
    assert factory.count('[cls alloc]') == 1 and factory.count('[net init]') == 1
    assert 'respondsToSelector:@selector(init)' not in factory and 'isKindOfClass:cls' in factory
    assert '@finally' in factory and 'net = nil; ssid = nil; bssid = nil;' in factory
    assert 'static NSString * const ssidKeys[]' in factory and 'static NSString * const bssidKeys[]' in factory
    assert all('@"' + key + '"' in factory for key in ('SSID', '_SSID', 'ssid', '_ssid', 'BSSID', '_BSSID', 'bssid', '_bssid'))
    fetch = identifier.method(wifi_hooks, WIFI_FETCH_SIGNATURES[1])
    assert fetch.index('if (!completion)') < fetch.index('PX_RUNTIME_READ_OPERATION;')
    assert 'orig_NEHotspotNetwork_fetchCurrent(self, _cmd, nil)' in fetch
    assert fetch.index('if (network) { completion(network); return; }') < fetch.index('shouldSpoofForBundle(')
    assert fetch.index('PXWiFiInfoHasIdentity(info)') < fetch.index('synthetic = PXCreateSpoofedNEHotspotNetwork(')
    assert fetch.count('PX_RUNTIME_READ_OPERATION;') == 2
    assert 'network = nil; synthetic = nil; info = nil;' in fetch
    assert 'deliver = nil; completion = nil;' in fetch and fetch.count('@finally') == 2
    assert fetch.count('@catch') == 1, 'only preparation exceptions may be swallowed'
    assert fetch.index('@catch') < fetch.index('completion(synthetic);') < fetch.index('network = nil;')
    assert 'dispatch_' not in fetch and 'dispatch_' not in factory
    fetch_fixture = read('tests/PXWiFiFetchTests.m')
    check_macro_arity(fetch_fixture, 'PXWiFiFetchTests.m')
    for call in ('TestFactory();', 'TestForwarding();', 'TestExceptionalClosureLifetime();', 'TestDeferred();'):
        assert fetch_fixture.count(call) == 1
    cf_builder = identifier.method(wifi_hooks, WIFI_CF_SIGNATURES[1])
    assert cf_builder.count('isKindOfClass:NSString.class') == 2
    assert '@finally' in cf_builder and 'ssidData = nil; spoofedInfo = nil; bssid = nil; ssid = nil;' in cf_builder
    finish_copy = identifier.method(wifi_hooks, WIFI_CF_SIGNATURES[2])
    assert 'if (!replacement) return original;' in finish_copy and 'CFRelease(replacement); @throw;' in finish_copy
    for index in (3, 4):
        body = identifier.method(wifi_hooks, WIFI_CF_SIGNATURES[index])
        assert body.index('@catch') < body.index('PXWiFiReplaceOwnedCopy(original, replacement)')
        assert 'CFRelease(original)' not in body
    interfaces = identifier.method(wifi_hooks, WIFI_CF_SIGNATURES[4])
    assert interfaces.index('PX_RUNTIME_READ_OPERATION;') < interfaces.index('CFArrayRef original =')
    assert interfaces.index('CFGetTypeID(original) != CFArrayGetTypeID()') < interfaces.index('CFArrayGetCount(original)') < interfaces.index('shouldSpoofForBundle(')
    assert 'interfaces = @[@"en0"];' in interfaces and 'CFBridgingRetain(interfaces)' in interfaces
    assert '@finally { interfaces = nil; bundleID = nil; }' in interfaces
    network = identifier.method(wifi_hooks, WIFI_CF_SIGNATURES[3])
    assert '@finally { wifiInfo = nil; bundleID = nil; }' in network
    assert network.index('orig_CNCopyCurrentNetworkInfo(interfaceName)') < network.index('@try')
    assert interfaces.index('orig_CNCopySupportedInterfaces()') < interfaces.index('@try')
    apple = identifier.method(wifi_hooks, WIFI_CF_SIGNATURES[5])
    assert apple.index('if (!info) return orig_') < apple.index('PX_RUNTIME_READ_OPERATION;')
    assert apple.index('if (!admitted) return orig_') < apple.index('*info = NULL;') < apple.index('int result = orig_')
    assert apple.index('CFGetTypeID(original) != CFDictionaryGetTypeID()') < apple.index('PXResolvedWiFiInfo()')
    assert apple.index('CFBridgingRetain(dict)') < apple.index('if (!replacement) return result;') < apple.index('*info = replacement;') < apple.index('CFRelease(original);')
    assert apple.rindex('@catch') < apple.index('*info = replacement;')
    assert '@finally' in apple and 'ssidData = nil; dict = nil; bssid = nil; ssid = nil; wifiInfo = nil;' in apple
    scan = identifier.method(wifi_hooks, WIFI_CF_SIGNATURES[6])
    assert scan.index('PXWiFiInfoHasIdentity(wifi)') < scan.index('[original mutableCopy]')
    assert scan.index('(!kind || [original[@"WifiStandard"] isEqual:kind])') < scan.index('[original mutableCopy]')
    assert all(token in scan for token in ('containsString:@"802.11ax"', 'containsString:@"802.11ac"', 'containsString:@"802.11n"'))
    assert 'containsString:@"n"' not in scan
    first_try = scan.index('@try')
    original_call = scan.index('original = orig_dictionaryWithScanResult')
    assert first_try < original_call < scan.index('@try', first_try + 4) < scan.index('@catch')
    assert scan.count('orig_dictionaryWithScanResult(self, _cmd, arg1)') == 1
    assert scan.index('[original mutableCopy]') < scan.index('isKindOfClass:NSMutableDictionary.class') < scan.index('modified[@"SSID"] =')
    assert '@finally' in scan and 'modified = nil; kind = nil; standard = nil; wifi = nil; bundleID = nil;' in scan
    assert 'original = nil; arg1 = nil; self = nil;' in scan
    for removed in ('loadScopedApps', 'isInScopedAppsList', 'URLSessionTaskTransactionMetrics', 'URLSessionTaskMetrics'):
        assert removed not in wifi_hooks, removed
    check_macro_arity(read('tests/PXWiFiCFHookTests.m'), 'PXWiFiCFHookTests.m')
    cf_fixture = read('tests/PXWiFiCFHookTests.m')
    bridge = identifier.method(cf_fixture, 'static CFTypeRef PXFixtureBridge(CFTypeRef value)')
    assert 'CFRetain(value)' in bridge and 'PXFixtureBridge(id value)' not in cf_fixture
    assert '#define CFBridgingRetain(value) PXFixtureBridge((__bridge CFTypeRef)(value))' in cf_fixture
    assert cf_fixture.count('TestLifetimeOracle();') == 1
    assert cf_fixture.count('TestPreparationLifetime();') == 1
    for case in ('network preparation failure releases provider root builder dictionary and mutable fields after pool drain',
                 'network builder encoding unwind releases its dictionary and both input parameters',
                 'network builder result keeps its independent CF owner after local cleanup',
                 'interface failed retain preserves the original owned empty array without retry',
                 'interface original exception propagates before scope or preparation'):
        assert case in cf_fixture, case
    assert cf_fixture.count('TestScanLifetime();') == 1
    assert 'OriginalScan(id __unsafe_unretained self, SEL command, id __unsafe_unretained input)' in cf_fixture
    for case in ('scan exceptional preparation releases its partial copy and retained roots after pool drain',
                 'scan classification exception releases retained standard and WiFi graph',
                 'scan original exception propagates once and releases adapter-owned receiver and argument',
                 'scan unusable mutable-copy result preserves original instead of returning nil or mutating another type'):
        assert case in cf_fixture, case
    assert 'gDeaths == 0, "lifetime oracle detects a deliberately surviving CF owner"' in cf_fixture
    assert 'gDeaths == 1, "preserved Apple output has no ownership leak after caller release"' in cf_fixture
    assert 'faultNames[fault]' in cf_fixture
    assert CF_EXCEPTION_MODES == (('plain-arc', '-fno-objc-arc-exceptions'), ('arc-eh', '-fobjc-arc-exceptions'))
    assert read('tests/PXRuntimeArtifactPreparationTests.m').count('TestHookWiFiResolver();') == 1
    observer = identifier.method(wifi_source, '- (void)registerForProfileNotifications')
    assert '@synchronized (self)' in observer and 'if (self.profileChangeObserver) return;' in observer
    assert '__weak typeof(self) weakSelf' in observer and '__strong typeof(weakSelf) owner' in observer
    assert '[owner handleWiFiProfileNotification:note]' in observer
    assert '@finally { owner = nil; note = nil; }' in observer
    handler = identifier.method(wifi_source, WIFI_MANAGER_RESOLUTION[3])
    assert handler.index('isKindOfClass:NSDictionary.class') < handler.index('payload[@"ProfileId"]')
    assert 'loadWiFiInfoFromCurrentProfile' in handler and 'currentProfileId = eventID' not in handler
    assert '@property (nonatomic, strong) id profileChangeObserver;' in wifi_source
    resolution = identifier.method(wifi_source, WIFI_MANAGER_RESOLUTION[0])
    assert '[value description]' not in resolution
    assert resolution.index('[manager currentProfile]') < resolution.index('PXCurrentProfileInfoPath()')
    assert 'if (![value isKindOfClass:NSString.class]) return nil;' in resolution
    assert 'isKindOfClass:NSNumber.class' in resolution and '[[value stringValue] copy]' in resolution
    assert resolution.index('isKindOfClass:NSDictionary.class') < resolution.index('profileInfo[@"ProfileId"]')
    assert '@catch' in resolution and '@finally' in resolution
    reload = identifier.method(wifi_source, WIFI_MANAGER_RESOLUTION[2])
    assert reload.index('beginWiFiCacheUpdate') < reload.index('getCurrentProfileID') < reload.index('loadWiFiInfoForProfileID:profileID revision:revision')
    profile_manager = identifier.method(wifi_source, '- (id)profileManagerForWiFi')
    assert 'respondsToSelector:@selector(sharedManager)' in profile_manager
    loader = identifier.method(wifi_source, WIFI_MANAGER_LOAD)
    assert loader.index('publishWiFiCache:empty') < loader.index('dictionaryWithContentsOfFile:')
    assert 'PXProfileIdentityPath(target)' in loader and 'PXProfilesPath()' not in loader
    getter = identifier.method(wifi_source, '- (NSDictionary *)currentWiFiInfo')
    assert getter.count('getCurrentProfileID') == 1 and 'loadWiFiInfoForProfileID:currentID revision:revision' in getter
    assert getter.count('beginWiFiCacheUpdateIfRevision:revision') == 2
    assert 'revision = [self loadWiFiInfoForProfileID:currentID revision:revision];' in getter
    assert 'generateWiFiInfoAtRevision:revision' in getter

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
    scalar = identifier.method(storage, 'static NSString *PXStorageScalarField(id settings, NSString *key)')
    assert 'if (![settings isKindOfClass:NSDictionary.class]) return nil;' in scalar
    assert 'isKindOfClass:NSString.class' in scalar and 'isKindOfClass:NSNumber.class' in scalar
    conversion = identifier.method(storage, '- (uint64_t)convertGBStringToBytes:(id)gbString')
    assert 'isKindOfClass:NSString.class' in conversion and 'isKindOfClass:NSNumber.class' in conversion
    assert conversion.index('!isfinite(bytes) || bytes >= 0x1p64') < conversion.index('(uint64_t)bytes')
    normalization = identifier.method(storage, '- (uint64_t)normalizeStorageBytes:(uint64_t)bytes')
    assert normalization.index('inputBytes >= 0x1p64) return bytes') < normalization.index('inputBytes / BYTES_PER_GB')
    assert normalization.index('normalized >= 0x1p64) return bytes') < normalization.index('(uint64_t)normalized')
    for name, key in (('totalStorageCapacity', 'TotalStorage'), ('freeStorageSpace', 'FreeStorage'), ('filesystemType', 'FilesystemType')):
        assert f'PXStorageScalarField(_storageSettings, @"{key}")' in identifier.method(storage, '- (NSString *)' + name)
    chooser = identifier.method(storage, '- (NSString *)randomizeStorageCapacityForDeviceModel:(NSString *)deviceModel')
    assert chooser.index('deviceModel && ![deviceModel isKindOfClass:NSString.class]') < chooser.index('[IPhoneModelDB sharedManager]')
    assert 'candidates = capacities;' in chooser and 'if (capacities.count > 1 && previous.length)' in chooser
    loader = identifier.method(storage, '- (BOOL)loadFromProfile:(NSString *)profileId')
    assert loader.index('PXValidatedProfileID(profileId)') < loader.index('PXProfileRootPath(profileId)')
    assert 'if (!profileId) return NO;' in loader
    assert '[self setDefaultStorageForProfile:profileId]' in loader and '[self setDefaultStorage]' not in loader
    targeted = identifier.method(storage, '- (NSString *)randomizeStorageCapacityForProfile:(NSString *)profileID')
    assert 'PXProfileIdentityPath(target)' in targeted and 'PXActiveProfileID' not in targeted
    hooks = read('TLinkIOSTweak/StorageHooks.x')
    import re
    for group, selector in (('PXStorageImportantCapacity', 'volumeAvailableCapacityForImportantUsageForURL:error:'),
                            ('PXStorageTotalCapacity', 'volumeTotalCapacityForURL:error:'),
                            ('PXStorageOpportunisticCapacity', 'volumeAvailableCapacityForOpportunisticUsageForURL:error:')):
        assert hooks.count('%group ' + group) == 1 and hooks.count('%init(' + group + ')') == 1
        pattern = r'if \(PXStorageCapacityCompatibilityMatches\(fileManagerClass, @selector\(' + re.escape(selector) + r'\)\)\) \{\s*%init\(' + group + r'\);'
        assert re.search(pattern, hooks), 'optional hook must be gated independently by ABI'
    assert 'URLForDirectory:' not in hooks and 'isInScopedAppsList' not in hooks and 'loadScopedApps' not in hooks
    single = identifier.method(hooks, STORAGE_OBJC_METHODS[4][0]); batch = identifier.method(hooks, STORAGE_OBJC_METHODS[5][0])
    assert single.index('if (!kind) return %orig;') < single.index('PX_RUNTIME_READ_OPERATION;')
    assert batch.index('if (!PXStorageKeysContainCapacity(keys)) return %orig;') < batch.index('PX_RUNTIME_READ_OPERATION;')
    assert batch.index('PXStorageResourceValuesHaveCapacity(originalValues, keys)') < batch.index('getStorageValuesForApp(')
    value_helper = identifier.method(hooks, STORAGE_OBJC_HELPERS[4])
    assert 'if (kind == 2) return @(free);' in value_helper and 'if (!total || free > total) return nil;' in value_helper
    for index in (1, 3): assert 'if (totalBytes > 0 && freeBytes <= totalBytes)' in identifier.method(hooks, STORAGE_OBJC_METHODS[index][0])
    abi = identifier.method(hooks, STORAGE_OBJC_HELPERS[-1])
    assert 'method_getNumberOfArguments(entry) != 4' in abi and "returnType[0] == 'Q' && returnType[1] == 0" in abi
    for name in ('result', 'url', 'error'): assert f'{name}[sizeof({name}) - 1] = 0;' in abi
    check_macro_arity(read('tests/PXStorageObjCHookTests.m'), 'PXStorageObjCHookTests.m')
    for file in ('tests/PXWiFiHookCacheTests.m', 'tests/PXRuntimeArtifactPreparationTests.m', 'tests/PXMethodSwizzlerTests.m', 'tests/PXWiFiCFHookTests.m', 'tests/PXWiFiFetchTests.m', 'tests/PXWiFiGetterTests.m', 'tests/PXWiFiManagerCacheTests.m'):
        declarations = re.findall(r'^@(interface|implementation)\s+(\w+)(?:[ \t]*\(([^)]*)\))?', read(file), re.M)
        assert len(declarations) == len(set(declarations)), 'duplicate native fixture class declaration: ' + file
    for label in ('hook source arrival baseline seeded', 'hook mutable target baseline seeded'):
        assert read('tests/PXRuntimeArtifactPreparationTests.m').count(label) == 1
    assert 'return bytes / blockSize + (bytes % blockSize != 0);' in hooks
    assert 'convertGBStringToBytes(' not in hooks and 'normalizeStorageBytes(' not in hooks
    clock = identifier.method(hooks, 'static NSTimeInterval PXStorageCacheTime(void)')
    assert 'CLOCK_MONOTONIC' in clock and 'return NAN;' in clock and '#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)' in clock
    cache_read = identifier.method(hooks, 'static NSDictionary *PXStorageCachedValues(NSTimeInterval now, uint64_t *generation)')
    cache_publish = identifier.method(hooks, 'static NSDictionary *PXStoragePublishValues(NSDictionary *values, NSTimeInterval now, uint64_t generation)')
    invalidation = identifier.method(hooks, 'static void PXStorageInvalidateCache(void)')
    assert 'now >= gStorageCacheLoadedAt' in cache_read and 'now - gStorageCacheLoadedAt < 30.0' in cache_read
    assert 'if (generation) *generation = gStorageCacheGeneration;' in cache_read
    assert 'if (generation == gStorageCacheGeneration)' in cache_publish and 'gStorageCacheGeneration++;' in invalidation
    assert cache_publish.index('NSPropertyListImmutable') < cache_publish.index('os_unfair_lock_lock')
    for body in (cache_read, cache_publish, invalidation):
        assert '__attribute__((objc_precise_lifetime)) NSDictionary *discarded = nil;' in body
        assert body.index('discarded = gCachedStorageValues;') < body.index('gCachedStorageValues =')
        assert body.index('os_unfair_lock_unlock') < body.index('(void)discarded;')
    values_reader = identifier.method(hooks, 'static NSDictionary *getStorageValues()')
    assert 'PXStorageCachedValues(now, &generation)' in values_reader and values_reader.count('now, generation)') == 5
    assert 'timeIntervalSince1970' not in values_reader
    check_macro_arity(read('tests/PXStorageObjectCacheTests.m'), 'PXStorageObjectCacheTests.m')
    native_copy = identifier.method(hooks, 'static BOOL PXStorageCopyNativeSnapshot(uint64_t *totalBytes, uint64_t *freeBytes)')
    assert native_copy.count('atomic_load_explicit(&gStorageNativeRevision, memory_order_seq_cst)') == 2
    assert 'free > total' in native_copy and 'revision & 1' in native_copy
    for token in ('while (', 'for (', 'os_unfair_lock', 'NSBundle', 'PX_RUNTIME_READ_OPERATION', 'dispatch_'):
        assert token not in native_copy, 'native mount snapshot must remain bounded pure C'
    scheduler = identifier.method(hooks, 'static void PXStorageScheduleNativeRefresh(dispatch_queue_t queue)')
    assert 'atomic_compare_exchange_strong_explicit' in scheduler and scheduler.count('dispatch_async(') == 1
    assert scheduler.index('gStorageRefreshScheduled, false') < scheduler.index('PXStorageRefreshNativeSnapshot();')
    callback = hooks[hooks.index('static void PXStorageSettingsChanged('):hooks.index('// Helper function to get consistent storage values')]
    assert 'PXStorageScheduleNativeRefresh(refreshQueue);' in callback and 'dispatch_async(' not in callback
    begin = identifier.method(hooks, 'static BOOL PXStorageBeginNativeRefresh(void)')
    end = identifier.method(hooks, 'static void PXStorageEndNativeRefresh(uint64_t total, uint64_t free, BOOL allowed)')
    assert 'atomic_compare_exchange_strong_explicit' in begin and 'atomic_fetch_add_explicit(&gStorageNativeRevision' in begin
    assert end.index('gStorageNativeFreeBytes') < end.index('gStorageNativeRevision') < end.index('gStorageNativeRefreshInProgress')
    for body in (begin, end, native_copy):
        assert 'memory_order_relaxed' not in body and 'memory_order_acquire' not in body and 'memory_order_release' not in body
    refresh = identifier.method(hooks, 'static void PXStorageRefreshNativeSnapshot(void)')
    assert 'if (!PXStorageBeginNativeRefresh()) return;' in refresh and '@finally' in refresh and 'PXStorageEndNativeRefresh(' in refresh
    assert 'if (freeBytes > 0)' not in identifier.method(hooks, 'static void PXStorageModifyStatfsWithValues(struct statfs *buf,\n                                            uint64_t totalBytes,\n                                            uint64_t freeBytes)')
    assert hooks.count('count = PXStorageBoundedMountCount(') == 4
    assert 'if (!isfinite(scaled) || scaled >= 0x1p64) { PXStorageSetSafeByteDefaults(totalBytes, freeBytes); return; }' in hooks
    check_macro_arity(read('tests/PXStorageNativeSnapshotTests.m'), 'PXStorageNativeSnapshotTests.m')
    display = identifier.method(storage, '- (BOOL)commitDisplayStorageInfo:(NSDictionary *)values updateFilesystem:(BOOL)updateFilesystem error:(NSError **)error')
    assert display.index('[rawTotal copy]') < display.index('acquireWithProfileIDResolver:') < display.index('dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()') < display.index('[_storageSettings copy]')
    assert 'PXActiveProfileID()' not in display and 'mutation.identityDirectory' not in display
    assert display.count('[mutation performSourceWrite:') == 1 and display.count('[tx setDictionary:') == 1
    assert display.index('PXPerformStandaloneRuntimeSourceWrite') < display.index('acquireWithProfileIDResolver:')
    assert 'mutation.profileDirectory' in display and 'if (updateFilesystem) candidate[@"FilesystemType"] = filesystem;' in display
    assert display.index('adoptable = [staged mutableCopy]') < display.index('if (!committed) return NO;') < display.index('_storageSettings = adoptable;') < display.index('@finally { [mutation invalidate]; }')
    assert 'saveToCurrentProfile' not in display and 'adoptCommittedStorageInfo:' not in display and 'PostNotification' not in display
    check_macro_arity(read('tests/PXRuntimeArtifactPreparationTests.m'), 'PXRuntimeArtifactPreparationTests.m')
    persist = identifier.method(storage, '- (BOOL)persistStorageToProfile:(NSString *)profileID current:(BOOL)current error:(NSError **)error')
    assert persist.index('acquireWithProfileIDResolver:') < persist.index('dictionaryWithContentsOfFile:PXCurrentProfileInfoPath()') < persist.index('[_storageSettings copy]')
    assert 'mutation.profileDirectory' in persist and 'mutation.identityDirectory' not in persist
    assert '[mutation performSourceWrite:' in persist and '@finally { [mutation invalidate]; }' in persist
    assert 'PXActiveProfileID()' not in persist and 'PXLegacyActiveProfileInfoPath()' not in persist
    assert 'current:YES' in identifier.method(storage, '- (void)saveToCurrentProfile')
    assert 'current:NO' in identifier.method(storage, '- (void)saveToProfile:(NSString *)profileId')
    flag = identifier.method(storage, '- (BOOL)setStorageSpoofingEnabled:(BOOL)enabled error:(NSError **)error')
    legacy_flag = identifier.method(storage, '- (void)setStorageSpoofingEnabled:(BOOL)enabled')
    assert '[self setStorageSpoofingEnabled:enabled error:&error]' in legacy_flag and 'Failed to commit storage enable flag' in legacy_flag
    assert 'PXPerformStandaloneRuntimeSourceWrite' in flag and 'dictionaryAtPath:path' in flag and 'PXTLinkIOSSettingsPath()' in flag
    assert 'candidate[@"StorageSystemEnabled"] = @(enabled)' in flag and 'EnabledIdentifiers' not in flag
    assert flag.index('if (!committed) return NO;') < flag.index('_isEnabled = enabled') < flag.index('setBool:enabled')
    assert '@finally' in flag and '_storagePreferenceWriteInFlight = NO' in flag and '_storagePreferenceWriteInFlight = YES' in flag
    assert '@catch (NSException *exception)' in flag and '@"com.hydra.tlinkios.settings"' in flag
    assert 'PostNotification' not in flag and 'dispatch_' not in flag and 'writeToFile:' not in flag
    assert '@synchronized (self)' in identifier.method(storage, '- (BOOL)isStorageSpoofingEnabled')
    fixture = read('tests/PXRuntimeArtifactPreparationTests.m')
    for case in ('display storage commits one complete packet instead of three setter writes',
                 'display storage failure restores source bytes and marker without adopting cache',
                 'nested display storage poisons outer transaction without source or cache publication',
                 'display storage freezes caller values and keeps one canonical target through selection drift'):
        assert case in fixture, case
    assert 'gWrites++; return [gStore performStandaloneWrite:body error:error];' in fixture
    assert '#define NSUserDefaults PXStoragePreferenceDefaultsFixture' in fixture
    for case in ('storage flag mirror observes committed source and cache after source unlock',
                 'storage mirror reentry fails busy before source entry without deadlock',
                 'storage flag commit preserves unrelated primary toggle and legacy mirror scope without notifications',
                 'failed storage flag commit preserves source cache and mirrors',
                 'storage writer admission is released after source failure',
                 'storage mirror exception does not negate primary commit or cache adoption',
                 'nested storage high-level writer rejects before cache and mirror effects',
                 'storage flag rollback preserves original source absence',
                 'void storage setter preserves corrupt source and prior cache on failure',
                 'concurrent storage flag writer fails busy while getter remains available',
                 'storage flag writer accepts a later request after completion'):
        assert case in fixture, case
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
                 'WiFi invalid custom inputs retain error precedence and readable cache without providers ownership or writes',
                 'WiFi nil custom input remains a complete no-op',
                 'WiFi setter validates its copied candidate rather than earlier external subscript values',
                 'WiFi custom copy exceptions propagate without invalidating the readable cache',
                 'WiFi custom candidate freezes required strings before provider callbacks while preserving spelling and metadata',
                 'WiFi superseded custom preparation cannot reclaim cache or publish a stale validation error',
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
    assert manifest['rollout'] == '4C.2H5S-partial'
    assert manifest['writers']['identifier-artifacts']['status'] == 'enrolled'
    assert manifest['writers']['profile-lifecycle']['status'] == 'partial'
    assert manifest['writers']['wifi-hook-legacy']['status'] == 'enrolled'
    wifi_field = next(row for row in manifest['sources'] if row['field'] == 'wifiInfo')
    assert wifi_field['status'] == 'enrolled' and 'wifi-hook-legacy' in wifi_field['writers']
    print('PASS: Artifact preparation and battery/WiFi/storage/uptime ownership contracts (remaining writers partial; native runtime not implied)')


def generate_native_fragments(folder):
    resolver_source = read('common/PXWiFiHookResolver.m')
    (folder / 'PXWiFiResolverLifetime.inc').write_text(resolver_source[resolver_source.index('static __thread BOOL gWiFiHookResolving'):], encoding='utf-8')
    for name, (source, signatures) in WRAPPERS.items():
        (folder / name).write_text('\n\n'.join(identifier.method(read(source), signature) for signature in signatures), encoding='utf-8')
    wifi_manager = read('common/WiFiManager.m')
    cache_declarations = [identifier.method(wifi_manager, sig).split(' {', 1)[0] + ';' for sig in WIFI_MANAGER_CACHE_METHODS + [WIFI_MANAGER_CAS, WIFI_MANAGER_SAVE]]
    (folder / 'PXWiFiCacheDeclarations.inc').write_text('\n'.join(cache_declarations), encoding='utf-8')
    (folder / 'PXWiFiCacheCoreDeclarations.inc').write_text('\n'.join(cache_declarations[:-1]), encoding='utf-8')
    (folder / 'PXWiFiCacheReaderDeclarations.inc').write_text('\n'.join(identifier.method(wifi_manager, sig).split(' {', 1)[0] + ';' for sig in WIFI_MANAGER_READERS), encoding='utf-8')
    (folder / 'PXWiFiResolutionDeclarations.inc').write_text('\n'.join(identifier.method(wifi_manager, sig).split(' {', 1)[0] + ';' for sig in WIFI_MANAGER_RESOLUTION), encoding='utf-8')
    cache_methods = WIFI_MANAGER_CACHE_METHODS + WIFI_MANAGER_READERS + WIFI_MANAGER_RESOLUTION + [WIFI_MANAGER_CAS, WIFI_MANAGER_LOAD, '- (void)loadWiFiInfoForProfileID:(NSString *)profileID', '- (void)adoptCommittedWiFiInfo:(NSDictionary *)wifiInfo profileID:(NSString *)profileID', '- (NSDictionary *)cachedWiFiInfoForProfileID:(NSString *)profileID']
    (folder / 'PXWiFiManagerCacheMethods.inc').write_text('\n\n'.join(identifier.method(wifi_manager, sig) for sig in cache_methods), encoding='utf-8')
    storage = read('common/StorageManager.m'); hooks = read('TLinkIOSTweak/StorageHooks.x')
    wifi = read('TLinkIOSTweak/WiFiHook.x')
    start = wifi.index('static os_unfair_lock gWiFiCacheLock =')
    end = wifi.index('// Forward declarations', start)
    (folder / 'PXWiFiHookCache.inc').write_text(wifi[start:end], encoding='utf-8')
    cf_names = ('orig_CNCopyCurrentNetworkInfo', 'orig_dictionaryWithScanResult', 'orig_CNCopySupportedInterfaces', 'orig_Apple80211GetInfoCopy')
    declarations = [line for line in wifi.splitlines() if line.startswith('typedef int (*Apple80211GetInfoCopy_t)') or
                    (line.startswith('static ') and any(name in line for name in cf_names) and line.endswith(';'))]
    assert len(declarations) == 5
    (folder / 'PXWiFiCFHooks.inc').write_text('\n\n'.join(declarations + [identifier.method(wifi, sig) for sig in WIFI_CF_SIGNATURES]), encoding='utf-8')
    fetch_original = next(line for line in wifi.splitlines() if line.startswith('static void (*orig_NEHotspotNetwork_fetchCurrent)'))
    (folder / 'PXWiFiFetchHooks.inc').write_text('\n\n'.join([fetch_original] + [identifier.method(wifi, sig) for sig in WIFI_FETCH_SIGNATURES]), encoding='utf-8')
    (folder / 'PXWiFiGetterHelpers.inc').write_text('\n\n'.join(identifier.method(wifi, sig) for sig in WIFI_GETTER_HELPERS), encoding='utf-8')
    (folder / 'PXWiFiGetterMethods.inc').write_text('\n\n'.join(identifier.method(wifi, sig) for sig in WIFI_GETTER_METHODS), encoding='utf-8')
    cf_originals = [line for line in wifi.splitlines() if line.startswith('static CFStringRef (*orig_WiFiNetworkGet')]
    assert len(cf_originals) == 2
    (folder / 'PXWiFiGetterCF.inc').write_text('\n\n'.join(cf_originals + [identifier.method(wifi, sig) for sig in WIFI_GETTER_CF]), encoding='utf-8')
    (folder / 'PXWiFiGetterPath.inc').write_text('\n\n'.join(identifier.method(wifi, sig).replace('%orig', original) for sig, original in WIFI_GETTER_PATH), encoding='utf-8')
    (folder / 'PXWiFiHookReader.inc').write_text('\n\n'.join(identifier.method(wifi, sig) for sig in
        ('static NSString *getCurrentProfileID(void)', 'static NSDictionary *getProfileWiFiInfo(void)')), encoding='utf-8')
    declarations = [identifier.method(storage, sig).split(' {', 1)[0] + ';' for sig in STORAGE_READ_SIGNATURES]
    (folder / 'PXStorageReadDeclarations.inc').write_text('\n'.join(declarations), encoding='utf-8')
    definitions = [next(line for line in storage.splitlines() if line.startswith('#define BYTES_PER_GB ')),
                   next(line for line in hooks.splitlines() if line.startswith('#define DEFAULT_BLOCK_SIZE ')),
                   identifier.method(storage, 'static NSString *PXStorageScalarField(id settings, NSString *key)'),
                   identifier.method(hooks, 'static uint64_t calculateBlockCount(uint64_t bytes, uint32_t blockSize)')]
    (folder / 'PXStorageReadHelpers.inc').write_text('\n\n'.join(definitions), encoding='utf-8')
    globals_and_publishers = [line for line in hooks.splitlines() if line.startswith('static _Atomic(')]
    globals_and_publishers += [identifier.method(hooks, 'static BOOL PXStorageBeginNativeRefresh(void)'),
                              identifier.method(hooks, 'static void PXStorageEndNativeRefresh(uint64_t total, uint64_t free, BOOL allowed)')]
    (folder / 'PXStorageNativePublish.inc').write_text('\n\n'.join(globals_and_publishers), encoding='utf-8')
    (folder / 'PXStorageNativeCopy.inc').write_text(identifier.method(hooks, 'static BOOL PXStorageCopyNativeSnapshot(uint64_t *totalBytes, uint64_t *freeBytes)'), encoding='utf-8')
    constants = [line for line in hooks.splitlines() if line.startswith('#define BYTES_PER_') or line.startswith('#define DEFAULT_BLOCK_SIZE ')]
    native_signatures = ['static NSString *getCurrentBundleID(void)', 'static BOOL PXStorageBundleIsProblematic(NSString *bundleID)',
                         'static void PXStorageSetSafeByteDefaults(uint64_t *totalBytes, uint64_t *freeBytes)',
                         'static void getStorageValuesForApp(uint64_t *totalBytes, uint64_t *freeBytes)',
                         'static void PXStorageRefreshNativeSnapshot(void)', 'static void PXStorageScheduleNativeRefresh(dispatch_queue_t queue)',
                         'static uint64_t calculateBlockCount(uint64_t bytes, uint32_t blockSize)',
                         'static int PXStorageBoundedMountCount(int result, int bufsize, size_t entrySize)',
                         'static void PXStorageModifyStatfsWithValues(struct statfs *buf,\n                                            uint64_t totalBytes,\n                                            uint64_t freeBytes)']
    (folder / 'PXStorageNativeWork.inc').write_text('\n\n'.join(constants + [identifier.method(hooks, sig) for sig in native_signatures]), encoding='utf-8')
    cache_start = hooks.index('static os_unfair_lock gStorageCacheLock =')
    cache_end = hooks.index('static void PXStorageSettingsChanged(', cache_start)
    (folder / 'PXStorageObjectCache.inc').write_text(hooks[cache_start:cache_end], encoding='utf-8')
    objc_constants = [line for line in hooks.splitlines() if line.startswith('#define NSFileSystem')]
    (folder / 'PXStorageObjCHelpers.inc').write_text('\n\n'.join(objc_constants + [identifier.method(hooks, sig) for sig in STORAGE_OBJC_HELPERS]), encoding='utf-8')
    for name, rows in (('FileManager', STORAGE_OBJC_METHODS[:4]), ('URL', STORAGE_OBJC_METHODS[4:])):
        methods = [identifier.method(hooks, sig) for sig, _ in rows]
        (folder / ('PXStorage' + name + 'Declarations.inc')).write_text('\n'.join(m.split(' {', 1)[0] + ';' for m in methods), encoding='utf-8')
        adapted = [body.replace('%orig', expression) for body, (_, expression) in zip(methods, rows)]
        (folder / ('PXStorage' + name + 'Methods.inc')).write_text('\n\n'.join(adapted), encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-artifact-preparation-') as temp:
        folder = Path(temp)
        generate_native_fragments(folder)
        sources = ['common/PXRuntimeArtifactPreparation.m', 'common/PXRuntimeArtifactWriter.m',
                   'common/PXRuntimeSourceStore.m', 'common/PXRuntimePublisher.m', 'common/PXIdentityValidator.m',
                   'common/PXProfileArtifactMutation.m', 'common/PXProfileLifecycleLease.m',
                   'common/PXProfileDeletionJournal.m', 'common/PXRuntimeProfileSelection.m', 'common/PXWiFiHookResolver.m',
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
            native_binary = folder / ('storage-native-' + scheme)
            subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions',
                            '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(folder), *defines,
                            str(ROOT / 'tests/PXStorageNativeSnapshotTests.m'), '-framework', 'Foundation',
                            '-o', str(native_binary)], check=True, cwd=ROOT, timeout=60)
            subprocess.run([str(native_binary)], check=True, cwd=ROOT, timeout=60)
            cache_binary = folder / ('storage-cache-' + scheme)
            subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions',
                            '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(folder), *defines,
                            str(ROOT / 'tests/PXStorageObjectCacheTests.m'), '-framework', 'Foundation',
                            '-o', str(cache_binary)], check=True, cwd=ROOT, timeout=60)
            subprocess.run([str(cache_binary)], check=True, cwd=ROOT, timeout=60)
            objc_binary = folder / ('storage-objc-' + scheme)
            subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions',
                            '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(folder), *defines,
                            str(ROOT / 'tests/PXStorageObjCHookTests.m'), '-framework', 'Foundation',
                            '-o', str(objc_binary)], check=True, cwd=ROOT, timeout=60)
            subprocess.run([str(objc_binary)], check=True, cwd=ROOT, timeout=60)
            swizzle_binary = folder / ('method-swizzler-' + scheme)
            subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions',
                            '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(ROOT / 'TLinkIOSTweak'), *defines,
                            str(ROOT / 'TLinkIOSTweak/MethodSwizzler.m'), str(ROOT / 'tests/PXMethodSwizzlerTests.m'),
                            '-framework', 'Foundation', '-o', str(swizzle_binary)], check=True, cwd=ROOT, timeout=60)
            subprocess.run([str(swizzle_binary)], check=True, cwd=ROOT, timeout=60)
            for arc_mode, arc_flag in CF_EXCEPTION_MODES:
                wifi_binary = folder / ('wifi-hook-cache-' + scheme + '-' + arc_mode)
                print('WiFi cache/reader native matrix:', scheme, arc_mode, flush=True)
                subprocess.run(['xcrun', 'clang', '-O0', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions', arc_flag,
                                '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(folder), '-I', str(ROOT / 'common'), *defines,
                                str(ROOT / 'tests/PXWiFiHookCacheTests.m'), '-framework', 'Foundation', '-o', str(wifi_binary)], check=True, cwd=ROOT, timeout=60)
                subprocess.run([str(wifi_binary)], check=True, cwd=ROOT, timeout=60)
                resolver_binary = folder / ('wifi-resolver-lifetime-' + scheme + '-' + arc_mode)
                print('WiFi resolver lifetime native matrix:', scheme, arc_mode, flush=True)
                subprocess.run(['xcrun', 'clang', '-O0', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions', arc_flag,
                                '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(folder), '-I', str(ROOT / 'common'), *defines,
                                str(ROOT / 'tests/PXWiFiResolverLifetimeTests.m'), '-framework', 'Foundation', '-o', str(resolver_binary)], check=True, cwd=ROOT, timeout=60)
                subprocess.run([str(resolver_binary)], check=True, cwd=ROOT, timeout=60)
                cf_binary = folder / ('wifi-cf-hooks-' + scheme + '-' + arc_mode)
                print('WiFi CF native matrix:', scheme, arc_mode, flush=True)
                subprocess.run(['xcrun', 'clang', '-O0', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions', arc_flag,
                                '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(folder), *defines,
                                str(ROOT / 'tests/PXWiFiCFHookTests.m'), '-framework', 'Foundation', '-framework', 'CoreFoundation',
                                '-o', str(cf_binary)], check=True, cwd=ROOT, timeout=60)
                subprocess.run([str(cf_binary)], check=True, cwd=ROOT, timeout=60)
                fetch_binary = folder / ('wifi-fetch-' + scheme + '-' + arc_mode)
                print('WiFi fetch native matrix:', scheme, arc_mode, flush=True)
                subprocess.run(['xcrun', 'clang', '-O0', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions', arc_flag,
                                '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(folder), *defines,
                                str(ROOT / 'tests/PXWiFiFetchTests.m'), '-framework', 'Foundation',
                                '-o', str(fetch_binary)], check=True, cwd=ROOT, timeout=60)
                subprocess.run([str(fetch_binary)], check=True, cwd=ROOT, timeout=60)
                getter_binary = folder / ('wifi-getters-' + scheme + '-' + arc_mode)
                print('WiFi getter native matrix:', scheme, arc_mode, flush=True)
                subprocess.run(['xcrun', 'clang', '-O0', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions', arc_flag,
                                '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(folder), '-I', str(ROOT / 'TLinkIOSTweak'), *defines,
                                str(ROOT / 'TLinkIOSTweak/MethodSwizzler.m'), str(ROOT / 'tests/PXWiFiGetterTests.m'),
                                '-framework', 'Foundation', '-framework', 'CoreFoundation', '-o', str(getter_binary)], check=True, cwd=ROOT, timeout=60)
                subprocess.run([str(getter_binary)], check=True, cwd=ROOT, timeout=60)
                manager_cache_binary = folder / ('wifi-manager-cache-' + scheme + '-' + arc_mode)
                print('WiFi manager cache native matrix:', scheme, arc_mode, flush=True)
                subprocess.run(['xcrun', 'clang', '-O0', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions', arc_flag,
                                '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(folder), *defines,
                                str(ROOT / 'tests/PXWiFiManagerCacheTests.m'), '-framework', 'Foundation', '-o', str(manager_cache_binary)], check=True, cwd=ROOT, timeout=60)
                subprocess.run([str(manager_cache_binary)], check=True, cwd=ROOT, timeout=60)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        native_tests()
