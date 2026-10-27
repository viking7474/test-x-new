#!/usr/bin/env python3
"""4C.2B exact production scalar/migration methods with native temporary storage."""
from pathlib import Path
import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text(encoding='utf-8')
GENERATORS = [
    ('generateIDFA', 'IDFAManager', 'generateIDFA', 'IDFA', 'setCurrentIDFA'),
    ('generateIDFV', 'IDFVManager', 'generateIDFV', 'IDFV', 'setCurrentIDFV'),
    ('generateDeviceName', 'DeviceNameManager', 'generateDeviceName', 'DeviceName', 'setCurrentDeviceName'),
    ('generateSerialNumber', 'SerialNumberManager', 'generateSerialNumber', 'SerialNumber', 'setCurrentSerialNumber'),
    ('generateSystemBootUUID', 'SystemUUIDManager', 'generateBootUUID', 'SystemBootUUID', 'setCurrentBootUUID'),
    ('generateDyldCacheUUID', 'DyldCacheUUIDManager', 'generateDyldCacheUUID', 'DyldCacheUUID', 'setCurrentDyldCacheUUID'),
    ('generatePasteboardUUID', 'PasteboardUUIDManager', 'generatePasteboardUUID', 'PasteboardUUID', 'setCurrentPasteboardUUID'),
    ('generateKeychainUUID', 'KeychainUUIDManager', 'generateKeychainUUID', 'KeychainUUID', 'setCurrentKeychainUUID'),
    ('generateUserDefaultsUUID', 'UserDefaultsUUIDManager', 'generateUserDefaultsUUID', 'UserDefaultsUUID', 'setCurrentUserDefaultsUUID'),
    ('generateAppGroupUUID', 'AppGroupUUIDManager', 'generateAppGroupUUID', 'AppGroupUUID', 'setCurrentAppGroupUUID'),
    ('generateCoreDataUUID', 'CoreDataUUIDManager', 'generateCoreDataUUID', 'CoreDataUUID', 'setCurrentCoreDataUUID'),
    ('generateAppInstallUUID', 'AppInstallUUIDManager', 'generateAppInstallUUID', 'AppInstallUUID', 'setCurrentAppInstallUUID'),
    ('generateAppContainerUUID', 'AppContainerUUIDManager', 'generateAppContainerUUID', 'AppContainerUUID', 'setCurrentAppContainerUUID'),
]
# Independent on-disk contract, not derived from the implementation's registry.
FILES = dict(IDFA='advertising_id.plist', IDFV='vendor_id.plist', DeviceName='device_name.plist',
             SerialNumber='serial_number.plist', IMEI='imei.plist', MEID='meid.plist', UDID='udid.plist',
             SystemBootUUID='system_boot_uuid.plist', DyldCacheUUID='dyld_cache_uuid.plist',
             PasteboardUUID='pasteboard_uuid.plist', KeychainUUID='keychain_uuid.plist',
             UserDefaultsUUID='userdefaults_uuid.plist', AppGroupUUID='appgroup_uuid.plist',
             CoreDataUUID='coredata_uuid.plist', AppInstallUUID='appinstall_uuid.plist', AppContainerUUID='appcontainer_uuid.plist')


def method(source, signature):
    start = source.index(signature + ' {')
    # These selected production methods close at column zero. Reject a missing
    # closing brace rather than falling back to a separately implemented model.
    match = re.search(r'^}', source[start:], re.M)
    assert match
    return source[start:start + match.end()]


def selected_signatures():
    return ['- (NSString *)profileIdentityPath',
            '- (NSString *)profileIdentityPathWithLifecycleLease:(PXProfileLifecycleLease *)lease',
            '- (NSString *)prepareProfileIdentityForProfileID:(NSString *)profileID lifecycleLease:(PXProfileLifecycleLease *)lease',
            '- (PXProfileArtifactMutation *)currentIdentifierMutation',
            '- (NSString *)generatePreparedIdentifierForType:(NSString *)type',
            '- (void)publishPreparedIdentifier:(NSString *)value type:(NSString *)type includeNameAndSerial:(BOOL)includeNameAndSerial',
            '- (BOOL)persistPreparedIdentifier:(NSString *)value type:(NSString *)type mutation:(PXProfileArtifactMutation *)mutation incrementGeneration:(BOOL)increment',
            *['- (NSString *)' + row[0] for row in GENERATORS], '- (NSString *)generateUDID',
            '- (BOOL)saveCustomValue:(NSString *)value forType:(NSString *)type',
            '- (void)setATTAuthorizationStatus:(NSInteger)status', '- (BOOL)setCustomDeviceTheme:(NSString *)value',
            '- (NSString *)generateSystemUptime', '- (NSString *)generateBootTime',
            '- (NSString *)generateUptimeCompatibilityForBootTime:(BOOL)isBoot',
            '- (void)migrateProfileSchemaIfNeeded', '- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identityDir',
            '- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identityDir lifecycleLease:(PXProfileLifecycleLease *)lease',
            '- (BOOL)commitProfileSchemaWithMutation:(PXProfileArtifactMutation *)mutation']


def source_contracts():
    manager = read('common/IdentifierManager.m')
    helper = read('common/PXRuntimeIdentifierWriter.m')
    paths = read('common/PXRuntimeSources.m')
    fixture = read('tests/PXRuntimeIdentifierWriterTests.m')
    for name, _, generator, key, _ in GENERATORS:
        body = method(manager, '- (NSString *)' + name)
        assert f'[self generatePreparedIdentifierForType:@"{key}"]' in body
        assert 'profileIdentityPath' not in body and '] ' + generator + ']' not in body
    flow = method(manager, '- (NSString *)generatePreparedIdentifierForType:(NSString *)type')
    acquire = method(manager, '- (PXProfileArtifactMutation *)currentIdentifierMutation')
    assert acquire.count('[self profileIdentityPathWithLifecycleLease:lease]') == 1 and 'acquireWithIdentityResolverUsingLease:' in acquire
    assert flow.index('[self currentIdentifierMutation]') < flow.index('PXPrepareRuntimeScalar(type, &prepareError)')
    assert '@finally { [mutation invalidate]; }' in flow
    assert flow.index('[mutation invalidate]') < flow.index('publishPreparedIdentifier:')
    assert flow.index('persistPreparedIdentifier:') < flow.index('publishPreparedIdentifier:')
    assert 'incrementGeneration:NO' in flow and 'prepareSerialNumber' in flow
    persist = method(manager, '- (BOOL)persistPreparedIdentifier:(NSString *)value type:(NSString *)type mutation:(PXProfileArtifactMutation *)mutation incrementGeneration:(BOOL)increment')
    assert '[mutation performSourceWrite:' in persist and 'mutation.identityDirectory' in persist
    assert 'PXPerformRuntimeSourceWrite' not in persist and 'PXLog(' not in persist
    for signature in ('- (BOOL)saveCustomValue:(NSString *)value forType:(NSString *)type',
                      '- (void)setATTAuthorizationStatus:(NSInteger)status', '- (BOOL)setCustomDeviceTheme:(NSString *)value'):
        body = method(manager, signature)
        assert '[self currentIdentifierMutation]' in body and '@finally { [mutation invalidate]; }' in body
        assert 'PXPerformRuntimeSourceWrite' not in body
    assert '#import "PXProfileArtifactMutation.h"' in fixture
    for header in ('PXProfileLifecycleLease.h', 'PXProfileDeletionJournal.h'):
        assert f'#import "{header}"' in fixture
    for source in ('common/PXProfileArtifactMutation.m', 'common/PXProfileLifecycleLease.m',
                   'common/PXProfileDeletionJournal.m', 'common/PXRuntimeProfileSelection.m'):
        assert source in read('scripts/test_runtime_identifier_writers.py')

    for signature in selected_signatures():
        body = method(manager, signature)
        assert 'writeToFile:' not in body, f'unenrolled direct write: {signature}'
    migration = method(manager, '- (BOOL)commitProfileSchemaWithMutation:(PXProfileArtifactMutation *)mutation')
    assert 'dictionaryWithContentsOfFile:' not in migration and '[mutation performSourceWrite:' in migration
    assert 'PXAdvanceRuntimeIdentifierGeneration(deviceIds, error)' in migration
    assert 'schemaVersion >= 2' in migration and 'profileBatteryPath' in migration
    assert migration.index('} error:&writeError]') < migration.index('PXLog('), 'migration logs must run after unlock'
    owned = method(manager, '- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identityDir')
    borrowed = method(manager, '- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identityDir lifecycleLease:(PXProfileLifecycleLease *)lease')
    assert 'acquireWithIdentityResolver:' in owned and 'borrowWithLifecycleLease:lease' in borrowed
    for body in (owned, borrowed):
        assert 'commitProfileSchemaWithMutation:mutation' in body and '@finally { [mutation invalidate]; }' in body
        assert '[lease invalidate]' not in body
    path = method(manager, '- (NSString *)prepareProfileIdentityForProfileID:(NSString *)profileID lifecycleLease:(PXProfileLifecycleLease *)lease')
    assert path.index('PXRequireNoPendingProfileDeletion') < path.index('createDirectoryAtPath:')
    assert 'migrateProfileSchemaAtIdentityDirectory:identityDir lifecycleLease:lease' in path
    current = method(manager, '- (void)migrateProfileSchemaIfNeeded')
    assert current.index('acquireInDirectory:') < current.index('getActiveProfileId')
    assert '@finally { [lease invalidate]; }' in current
    for case in ('direct migration fails busy before source staging',
                 'current migration acquires ownership before active lookup',
                 'cold reader migration fails busy without source mutation',
                 'busy cold reader never creates missing profile identity',
                 'direct and cold reader migration stop at pending deletion',
                 'pending deletion blocks cold path directory repair',
                 'migration reentry requires explicit capability instead of implicit reuse',
                 'borrowed migration commits once without acquiring or invalidating caller ownership',
                 'current schema reader remains available under contention without writer gate',
                 'borrowed migration rollback preserves sidecars token and caller lease',
                 'migration rejects invalidated capability without source mutation',
                 'migration rejects wrong root while preserving foreign ownership',
                 'borrowed migration exception closes child scope while caller remains held',
                 'migration checks late deletion before staging entire schema group',
                 'owned migration rejects removed replaced and symlink identity before schema staging',
                 'cold reader rejects selection drift before directory repair or migration',
                 'cold reader migration succeeds with one schema bump after ownership retry'):
        assert case in fixture, case
    uptime = method(manager, '- (NSString *)generateUptimeCompatibilityForBootTime:(BOOL)isBoot')
    assert '[self currentIdentifierMutation]' in uptime and '@finally { [mutation invalidate]; }' in uptime
    assert 'generateIfMissing:NO' in uptime and 'prepareConsistentUptimeInfo' in uptime
    assert '[mutation performSourceWrite:' in uptime and 'PXStageRuntimeUptime' in uptime
    assert uptime.index('PXStageRuntimeUptime') < uptime.index('PXStageRuntimeIdentifierState')
    assert uptime.index('[mutation invalidate]') < uptime.index('adoptCommittedUptimeInfo:')
    assert 'PXPerformRuntimeSourceWrite' not in uptime
    for name, flag in (('generateSystemUptime', 'NO'), ('generateBootTime', 'YES')):
        assert f'generateUptimeCompatibilityForBootTime:{flag}' in method(manager, '- (NSString *)' + name)
    for case in ('busy uptime compatibility rejects before target read provider and source mutation',
                 'pending deletion blocks both uptime compatibility paths',
                 'uptime compatibility reentry fails busy without getter generation',
                 'uptime read hit or missing pair commits once and adopts only after success',
                 'uptime read exception releases ownership without cache or source effects',
                 'uptime preparation exception cannot publish or leak lifecycle',
                 'late delete rejects compatibility pair initialization and scalar together',
                 'uptime compatibility rejects missing replaced and symlink identity without adopting cache',
                 'uptime compatibility transaction failure rolls back pair scalar and commit token'):
        assert case in fixture, case
    identity = method(manager, '- (NSString *)profileIdentityPath')
    assert identity.index('[schema integerValue] >= 2') < identity.index('acquireInDirectory:')
    assert '@finally { [lease invalidate]; }' in identity and 'sMigratingSchema' not in identity
    assert 'prepareProfileIdentityForProfileID:profileID lifecycleLease:lease' in identity
    custom = method(manager, '- (BOOL)saveCustomValue:(NSString *)value forType:(NSString *)type')
    assert 'PXRuntimeIdentifierSidecar(type)' in custom and 'incrementGeneration:YES' in custom
    assert custom.index('if (success)') < custom.index('publishPreparedIdentifier:value type:type includeNameAndSerial:NO')
    publisher = method(manager, '- (void)publishPreparedIdentifier:(NSString *)value type:(NSString *)type includeNameAndSerial:(BOOL)includeNameAndSerial')
    assert 'setCurrentIDFA:value' in publisher and 'includeNameAndSerial &&' in publisher
    assert 'if (generation == NSIntegerMax)' in helper and 'generation + 1' in helper
    assert 'PXRuntimeIdentifierSidecars()' in paths and '@"tracking_info.plist"' in paths
    assert '@"storage.plist", @"battery_info.plist"' in paths
    for file in FILES.values():
        assert f'@"{file}"' in helper
    assert '@"HardwareUUID":' not in helper and '@"DeviceTheme":' not in helper
    for forbidden in ('PXActiveProfile', 'PXPerformRuntimeSourceWrite', 'writeToFile:', 'dispatch_async', 'PXLog('):
        assert forbidden not in helper
    for token in ('generator captures target once', 'compatibility setter runs after complete commit',
                  'failed custom commit cannot publish', 'counter exhaustion rejects',
                  'schema migration commits whole group', 'concurrent migrations accept explicit busy',
                  'migration capability cleanup permits retry', 'migration rollback restores all sidecars',
                  'already-current live path never enters writer gate', 'malformed migration input preserves bytes'):
        assert token in fixture, f'missing native case: {token}'
    for case in ('busy scalar metadata writers never resolve migrate prepare write or publish',
                 'pending deletion blocks scalar metadata before target and preparation',
                 'scalar preparation reentry fails busy without deadlock',
                 'scalar generation owns target across provider and source commit',
                 'throwing scalar provider preserves files and releases lifecycle ownership',
                 'late deletion intent rejects scalar sidecar IDs and cache publication',
                 'scalar commit rejects missing replaced and symlink identity after preparation',
                 'custom scalar freezes caller value and type before commit and publication',
                 'owned ATT preserves clamp policy and releases before logging',
                 'owned theme retains paired state without changing generation policy',
                 'scalar failure preserves completed schema preflight without claiming whole-operation rollback',
                 'writer resolver exception releases lifecycle and permits schema retry'):
        assert case in fixture, case
    make = read('Makefile').split('WeaponXDaemon_FILES =', 1)[1].splitlines()[0]
    assert 'common/PXRuntimeIdentifierWriter.m' in make
    for runner in ('test_runtime_snapshot_publisher.py', 'test_runtime_source_transactions.py'):
        assert 'common/PXRuntimeIdentifierWriter.m' in read('scripts/' + runner), 'new allowlist registry must link transitively'
    assert 'test_runtime_identifier_writers.py --native' in read('.github/workflows/build-ios-arm.yml')
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2H3N-partial'
    for name in ('identifier-values', 'identifier-migration', 'identifier-artifacts'):
        assert manifest['writers'][name]['status'] == 'enrolled'
    assert manifest['writers']['profile-lifecycle']['status'] == 'partial'
    for name in ('storage-preference', 'security-store', 'security-direct'):
        assert manifest['writers'][name]['status'] == 'pending'
    print('PASS: Runtime identifier writer source contracts (partial rollout; native runtime not implied)')


def objc_array(rows):
    return '@[' + ',\n'.join('@[' + ', '.join('@"' + value + '"' for value in row) + ']' for row in rows) + ']'


def generate_native_fragments(folder):
    manager = read('common/IdentifierManager.m')
    methods = [method(manager, signature) for signature in selected_signatures()]
    (folder / 'PXIdentifierProductionDeclarations.inc').write_text('\n'.join(m.split(' {', 1)[0] + ';' for m in methods), encoding='utf-8')
    (folder / 'PXIdentifierProductionMethods.inc').write_text('\n\n'.join(methods), encoding='utf-8')
    static = method(manager, 'static BOOL PXIsNonZeroUUIDString(NSString *uuid)')
    (folder / 'PXIdentifierFixtureStatics.inc').write_text(static, encoding='utf-8')
    providers = []
    for _, cls, generator, key, setter in GENERATORS:
        methods_decl = f'- (NSString *){generator};\n' + (f'- (void){setter}:(NSString *)value;\n' if setter else '')
        impl = f'- (NSString *){generator} {{ return PXFixtureGenerate(self, @"{key}"); }}\n'
        if key == 'SerialNumber':
            methods_decl += '- (NSString *)prepareSerialNumber;\n'
            impl += '- (NSString *)prepareSerialNumber { return PXFixtureGenerate(self, @"SerialNumber"); }\n'
        if setter:
            impl += f'- (void){setter}:(NSString *)value {{ PXFixtureSet(self, @"{key}", value); }}\n'
        providers.append(f'@interface {cls} : PXGenerator\n{methods_decl}@end\n@implementation {cls}\n{impl}@end\n')
    generator_cases = [(name, key, FILES[key]) for name, _, _, key, _ in GENERATORS] + [('generateUDID', 'UDID', FILES['UDID'])]
    providers.append('static NSArray *PXFixtureGeneratorCases(void) { return ' + objc_array(generator_cases) + '; }\n')
    providers.append('static NSArray *PXFixtureCustomCases(void) { return ' + objc_array(list(FILES.items())) + '; }\n')
    (folder / 'PXIdentifierFixtureProviders.inc').write_text('\n'.join(providers), encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-identifier-writers-') as temp:
        folder = Path(temp)
        generate_native_fragments(folder)
        sources = ['common/PXRuntimeScalarPreparation.m', 'common/PXIdentityValidator.m', 'common/PXRuntimeIdentifierWriter.m', 'common/PXRuntimeSourceStore.m',
                   'common/PXRuntimePublisher.m', 'common/PXProfileArtifactMutation.m',
                   'common/PXProfileLifecycleLease.m', 'common/PXProfileDeletionJournal.m',
                   'common/PXRuntimeProfileSelection.m', 'common/PXRuntimeArtifactWriter.m',
                   'common/PXRuntimeArtifactPreparation.m', 'tests/PXRuntimeIdentifierWriterTests.m']
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            binary = folder / ('identifier-' + scheme)
            subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions',
                            '-DPX_SOURCE_TRANSACTION_TESTING=1', '-Darc4random=PXIdentifierFixtureRandom',
                            '-Darc4random_uniform=PXIdentifierFixtureUniform', '-DSecRandomCopyBytes=PXIdentifierFixtureSecure',
                            '-Wall', '-Wextra', '-Werror=implicit-function-declaration',
                            '-I', str(ROOT / 'common'), '-I', str(folder), *defines,
                            *[str(ROOT / source) for source in sources], '-framework', 'Foundation', '-framework', 'Security', '-o', str(binary)],
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
