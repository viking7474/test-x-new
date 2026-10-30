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


def native_compile_command(folder, scheme):
    assert scheme in ('rootful', 'roothide'), f'unsupported native fixture scheme: {scheme}'
    # Compile actual manager, carrier dependency, stage helpers and source engine.
    sources = ['common/NetworkManager.m', 'common/CarrierDB.m', 'common/PXRuntimeArtifactWriter.m',
               'common/PXRuntimeSourceStore.m', 'common/PXRuntimePublisher.m',
               'common/PXProfileArtifactMutation.m', 'common/PXProfileLifecycleLease.m',
               'common/PXProfileDeletionJournal.m', 'common/PXRuntimeProfileSelection.m',
               'tests/PXRuntimeArtifactWriterTests.m']
    command = ['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions',
               '-DPX_SOURCE_TRANSACTION_TESTING=1', '-Wall', '-Wextra', '-Werror=implicit-function-declaration',
               '-I', str(ROOT / 'common')]
    if scheme == 'roothide':
        # This macOS fixture runs before Theos/RootHide SDK setup. Keep the shim
        # in its temporary include directory, never on production include paths.
        support = folder / 'roothide-fixture-include'
        support.mkdir(exist_ok=True)
        shutil.copyfile(ROOT / 'tests/native/roothide/roothide.h', support / 'roothide.h')
        command += ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1', '-I', str(support)]
    return command + [str(ROOT / source) for source in sources] + [
        '-framework', 'Foundation', '-framework', 'Security', '-o', str(folder / scheme)]


def native_support_contracts():
    # Exercise the exact command builder used by --native without requiring a
    # macOS compiler. In particular, a scheme define alone is not SDK support.
    shim = read('tests/native/roothide/roothide.h')
    assert '#if !defined(PX_SOURCE_TRANSACTION_TESTING) || !defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)' in shim
    assert '#error' in shim and 'NSString *jbroot(NSString *path)' in shim and 'NSString *rootfs(NSString *path)' in shim
    assert '#import <roothide.h>' in read('common/PXJailbreakCompat.h'), 'production must keep its real SDK dependency'
    assert 'tests/native/roothide' not in read('Makefile'), 'fixture shim must not enter production include paths'
    with tempfile.TemporaryDirectory(prefix='px-artifact-command-') as temp:
        folder = Path(temp)
        rootful = native_compile_command(folder, 'rootful')
        assert '-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1' not in rootful
        assert not (folder / 'roothide-fixture-include').exists()
        roothide = native_compile_command(folder, 'roothide')
        support = folder / 'roothide-fixture-include'
        assert (support / 'roothide.h').read_text(encoding='utf-8') == shim
        assert roothide.count('-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1') == 1
        assert any(roothide[i:i + 2] == ['-I', str(support)] for i in range(len(roothide) - 1))
        assert str(support) not in rootful
        for command in (rootful, roothide):
            assert '-DPX_SOURCE_TRANSACTION_TESTING=1' in command
            assert str(ROOT / 'common/CarrierDB.m') in command
            assert str(ROOT / 'common/NetworkManager.m') in command


def source_contracts():
    native_support_contracts()
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
    assert manifest['rollout'] == '4C.2H4Y-partial'
    for name in ('network', 'wifi', 'battery', 'uptime', 'storage', 'identifier-artifacts'):
        assert manifest['writers'][name]['status'] == 'enrolled', name
    assert manifest['writers']['profile-lifecycle']['status'] == 'partial'
    assert manifest['writers']['storage-preference']['status'] == 'enrolled'
    for name in ('security-store', 'security-direct'):
        assert manifest['writers'][name]['status'] == 'partial', f'cannot claim full coverage of {name}'
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
    mutation = read('common/PXProfileArtifactMutation.m')
    acquire = objc_method(mutation, '+ (instancetype)acquireWithDirectoryResolver:(NSString *(^)(PXProfileLifecycleLease *))resolver identityTarget:(BOOL)identityTarget lifecycleLease:(PXProfileLifecycleLease *)borrowed error:(NSError **)error')
    assert acquire.index('acquireInDirectory:PXProfilesPath()') < acquire.index('PXRequireNoPendingProfileDeletion') < acquire.index('resolver(mutation.lease)')
    assert 'NS_RETURNS_RETAINED' in read('common/PXProfileArtifactMutation.h')
    assert 'O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW' in acquire and '@finally' in acquire and 'if (!handedOff)' in acquire
    validate = objc_method(mutation, '- (BOOL)validateWithError:(NSError **)error')
    assert 'validateForDirectory:PXProfilesPath()' in validate and 'directoryProofForProfileID:' in validate
    assert 'fstat(_directoryFD' in validate and 'lstat(self.targetDirectory' in validate and 'st_ino' in validate
    write = objc_method(mutation, '- (BOOL)performSourceWrite:(BOOL (^)(PXRuntimeSourceTransaction *, NSError **))body error:(NSError **)error')
    assert write.index('[self validateWithError:') < write.index('PXProfileDeletionJournalPath()') < write.index('return body(tx, writeError)')
    assert 'close(_directoryFD)' in mutation and '- (void)dealloc { [self invalidate]; }' in mutation
    assert 'mutation.ownsLease = borrowed == nil;' in acquire
    assert 'if (self.ownsLease) [self.lease invalidate];' in mutation
    borrowed = objc_method(mutation, '+ (instancetype)borrowWithLifecycleLease:(PXProfileLifecycleLease *)lease identityResolver:(NSString *(^)(void))resolver error:(NSError **)error')
    assert 'isKindOfClass:PXProfileLifecycleLease.class' in borrowed and 'lifecycleLease:lease' in borrowed
    assert 'validateForDirectory:PXProfilesPath()' in acquire

    for forbidden in ('dispatch_', 'createDirectory', 'removeItemAtPath:', 'PXActiveProfile', 'PXLog(', 'NSNotification'):
        assert forbidden not in mutation, forbidden
    for signature in (
        '+ (BOOL)saveLocalIPAddress:(NSString *)ipAddress ipv6Address:(NSString *)ipv6Address',
        '+ (BOOL)saveLocalIPAddress:(NSString *)ipAddress',
        '+ (BOOL)saveCarrierDetails:(NSString *)carrierName mcc:(NSString *)mcc mnc:(NSString *)mnc',
        '+ (NSString *)generateAndSaveAddressForIdentityDirectory:(NSString *)expected forceRefresh:(BOOL)forceRefresh',
        '+ (NSString *)generateAndSaveIPv6ForIdentityDirectory:(NSString *)expected',
        '+ (NSDictionary *)generateAndSaveCarrierForIdentityDirectory:(NSString *)expected'):
        body = objc_method(network, signature)
        assert 'acquireMutationForIdentityDirectory:' in body and '@finally { [mutation invalidate]; }' in body
    assert 'PXPerformRuntimeSourceWrite' not in network and 'inIdentityDirectory:' not in network
    for token in ('busy network writers stop before target lookup providers and source gate',
                  'saved network read hits remain available without lifecycle or source lock',
                  'busy network read misses never generate or persist fallback values',
                  'pending delete blocks network writes before target lookup or generation',
                  'network provider reentry fails busy without deadlock',
                  'network holds lifecycle across IPv6 preparation and paired commit',
                  'network provider exception preserves source and releases owned scope',
                  'network read miss rejects selection drift before generating at either target',
                  'late delete intent rejects network candidate before paired staging',
                  'network commit rejects missing replaced or symlink identity without recreating it',
                  'network refuses missing profile before providers and never creates a retired target',
                  'network getter preserves candidate return on persistence failure without partial source commit',
                  'invalidated artifact mutation never calls staging body',
                  'artifact mutation rejects malformed resolver target',
                  'artifact mutation success failure exception and dealloc paths close every descriptor'):
        assert token in fixture, token

    for signature in ('+ (BOOL)saveAddresses:(NSString *)ipAddress ipv6:(NSString *)ipv6Address inMutation:(PXProfileArtifactMutation *)mutation error:(NSError **)error',
                      '+ (BOOL)saveSingleAddress:(NSString *)ipAddress inMutation:(PXProfileArtifactMutation *)mutation error:(NSError **)error',
                      '+ (BOOL)saveCarrierDetails:(NSString *)carrierName mcc:(NSString *)mcc mnc:(NSString *)mnc inMutation:(PXProfileArtifactMutation *)mutation error:(NSError **)error'):
        body = objc_method(network, signature)
        assert '[mutation performSourceWrite:' in body and 'PXStageRuntime' in body
        assert 'profileIdentityPath' not in body, 'explicit-target persistence must not select a second profile'
    single = objc_method(network, '+ (BOOL)saveSingleAddress:(NSString *)ipAddress inMutation:(PXProfileArtifactMutation *)mutation error:(NSError **)error')
    assert single.index('PXStageRuntimeIPv4WithExistingPair') < single.index('generateSpoofedLocalIPv6AddressFromCurrent')
    assert single.index('} error:error]') < single.index('generateSpoofedLocalIPv6AddressFromCurrent')
    for body, helper_name in ((objc_method(wifi, '- (void)saveWiFiInfoToCurrentProfile'), 'WiFi'),
                              (objc_method(battery, '- (BOOL)persistBatteryRecord:(NSDictionary *)record'), 'Battery'),
                              (objc_method(uptime, '- (void)generateConsistentUptimeAndBootTimeForProfile:(NSString *)profilePath'), 'Uptime')):
        assert f'PXStageRuntime{helper_name}' in body
        assert '[mutation performSourceWrite:' in body
        assert 'writeToFile:deviceIdsPath' not in body
    assert 'writeToFile:BATTERY_PLIST_PATH' in battery, 'legacy global battery compatibility remains separate'
    storage_save = objc_method(storage, '- (BOOL)persistStorageToProfile:(NSString *)profileID current:(BOOL)current error:(NSError **)error')
    assert 'mutation.profileDirectory' in storage_save and 'acquireWithProfileIDResolver:' in storage_save and '[tx setDictionary:prepared atPath:storagePath' in storage_save
    assert 'writeToFile:' not in storage_save
    assert 'initWithSuiteName:@"com.hydra.tlinkios.settings"' in storage, 'defaults authority rollout remains pending'
    uptime_save = objc_method(uptime, '- (void)generateConsistentUptimeAndBootTimeForProfile:(NSString *)profilePath')
    assert uptime_save.index('[mutation performSourceWrite:') < uptime_save.index('self.bootTimeValue = bootTime')
    provider = objc_method(uptime, '- (NSDictionary *)prepareConsistentUptimeInfo')
    assert 'PXPrepareRuntimeUptime(now, realUptime, sysctlResult == 0)' in provider
    assert uptime_save.index('acquireWithIdentityResolver:') < uptime_save.index('[self prepareConsistentUptimeInfo]') < uptime_save.index('[mutation performSourceWrite:')
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
        folder = Path(folder)
        for scheme in ('rootful', 'roothide'):
            binary = folder / scheme
            if scheme == 'roothide':
                print('RootHide define fixture uses a test-only path shim; real SDK/namespace behavior is not tested', flush=True)
            subprocess.run(native_compile_command(folder, scheme), check=True, cwd=ROOT, timeout=60)
            for _ in range(3):
                subprocess.run([str(binary)], check=True, cwd=ROOT, timeout=60)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        native_tests()
