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
            '- (NSString *)generatePreparedIdentifierForType:(NSString *)type',
            '- (void)publishPreparedIdentifier:(NSString *)value type:(NSString *)type includeNameAndSerial:(BOOL)includeNameAndSerial',
            '- (BOOL)persistPreparedIdentifier:(NSString *)value type:(NSString *)type identityDirectory:(NSString *)identityDir incrementGeneration:(BOOL)increment',
            *['- (NSString *)' + row[0] for row in GENERATORS], '- (NSString *)generateUDID',
            '- (BOOL)saveCustomValue:(NSString *)value forType:(NSString *)type',
            '- (void)setATTAuthorizationStatus:(NSInteger)status', '- (BOOL)setCustomDeviceTheme:(NSString *)value',
            '- (NSString *)generateSystemUptime', '- (NSString *)generateBootTime',
            '- (void)migrateProfileSchemaIfNeeded', '- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identityDir']


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
    assert flow.count('[self profileIdentityPath]') == 1
    assert flow.index('[self profileIdentityPath]') < flow.index('PXPrepareRuntimeScalar(type, &prepareError)')
    assert flow.index('persistPreparedIdentifier:') < flow.index('publishPreparedIdentifier:')
    assert 'incrementGeneration:NO' in flow and 'prepareSerialNumber' in flow
    for signature in selected_signatures():
        body = method(manager, signature)
        assert 'writeToFile:' not in body, f'unenrolled direct write: {signature}'
    migration = method(manager, '- (BOOL)migrateProfileSchemaAtIdentityDirectory:(NSString *)identityDir')
    assert 'dictionaryWithContentsOfFile:' not in migration and 'PXPerformRuntimeSourceWrite' in migration
    assert 'PXAdvanceRuntimeIdentifierGeneration(deviceIds, error)' in migration
    assert 'schemaVersion >= 2' in migration and 'profileBatteryPath' in migration
    assert migration.index('}, &writeError)') < migration.index('PXLog('), 'migration logs must run after unlock'
    identity = method(manager, '- (NSString *)profileIdentityPath')
    assert 'static _Thread_local BOOL sMigratingSchema' in identity and '@finally { sMigratingSchema = NO; }' in identity
    assert '[self migrateProfileSchemaAtIdentityDirectory:identityDir]' in identity
    assert identity.index('[schema integerValue] < 2') < identity.index('[self migrateProfileSchemaAtIdentityDirectory:identityDir]'), 'already-current live readers may not enter writer flock'
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
                  'schema migration commits whole group', 'concurrent migrations bump once',
                  'thread-local migration guard resets', 'migration rollback restores all sidecars',
                  'already-current live path never enters writer gate', 'malformed migration input preserves bytes'):
        assert token in fixture, f'missing native case: {token}'
    make = read('Makefile').split('WeaponXDaemon_FILES =', 1)[1].splitlines()[0]
    assert 'common/PXRuntimeIdentifierWriter.m' in make
    for runner in ('test_runtime_snapshot_publisher.py', 'test_runtime_source_transactions.py'):
        assert 'common/PXRuntimeIdentifierWriter.m' in read('scripts/' + runner), 'new allowlist registry must link transitively'
    assert 'test_runtime_identifier_writers.py --native' in read('.github/workflows/build-ios-arm.yml')
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2H3F-partial'
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
                   'common/PXRuntimePublisher.m', 'tests/PXRuntimeIdentifierWriterTests.m']
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
