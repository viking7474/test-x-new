#!/usr/bin/env python3
"""4C.2F prepared model/scalars, deferred publication and serial memory safety."""
from pathlib import Path
import argparse
import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding='utf-8')
spec = importlib.util.spec_from_file_location('identifier_writers', ROOT / 'scripts/test_runtime_identifier_writers.py')
writers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(writers)


def source_contracts():
    scalar = read('common/PXRuntimeScalarPreparation.m')
    for forbidden in ('self.', 'PXPerformRuntimeSourceWrite', 'PXActiveProfile', 'NSUserDefaults', 'NSFileManager',
                      'writeToFile:', 'PXLog(', 'sharedManager', 'usleep(', 'sysctl(', 'currentIdentifier'):
        assert forbidden not in scalar, f'scalar factory must not publish or perform policy I/O: {forbidden}'
    for key in ('IDFA', 'IDFV', 'DeviceName', 'UDID', 'SystemBootUUID', 'DyldCacheUUID', 'PasteboardUUID',
                'KeychainUUID', 'UserDefaultsUUID', 'AppGroupUUID', 'CoreDataUUID', 'AppInstallUUID', 'AppContainerUUID'):
        assert '@"' + key + '"' in scalar
    assert 'PXPrepareRuntimeSerial(NSString *prefix' in scalar
    assert 'SecRandomCopyBytes' in scalar and 'arc4random() % 16' in scalar
    for _, cls, generator, key, _ in writers.GENERATORS:
        body = writers.method(read('common/' + cls + '.m'), '- (NSString *)' + generator)
        assert 'PXRuntimeScalarPreparation.h' in read('common/' + cls + '.m')
        if key == 'SerialNumber':
            assert 'prepareSerialNumber' in body
        else:
            assert f'PXPrepareRuntimeScalar(@"{key}", &error)' in body
    serial = read('common/SerialNumberManager.m')
    clear = writers.method(serial, '- (void)clearSensitiveData')
    assert 'self.currentIdentifier = nil;' in clear and 'memset(' not in clear and '[self.currentIdentifier UTF8String]' not in clear
    prepare = writers.method(serial, '- (NSString *)prepareSerialNumber')
    assert 'atomic_compare_exchange_weak_explicit' in prepare and 'memory_order_relaxed' in prepare
    assert 'usleep(arc4random_uniform(50000))' in prepare and '[self isEnvironmentSecure]' in prepare
    assert 'self.currentIdentifier =' not in prepare and 'PXPrepareRuntimeSerial(prefixes[next], &error)' in prepare
    manager = read('common/IdentifierManager.m')
    flow = writers.method(manager, '- (NSString *)generatePreparedIdentifierForType:(NSString *)type')
    assert flow.index('persistPreparedIdentifier:') < flow.index('publishPreparedIdentifier:')
    builder = writers.method(manager, '- (PXPreparedDeviceProfileGroup *)prepareDeviceProfileGroupWithOptions:(NSDictionary *)options error:(NSError **)error')
    for forbidden in ('PXPerformRuntimeSourceWrite', 'profileIdentityPath', 'self.error', 'setCurrent', '[self isIdentifierEnabled:'):
        assert forbidden not in builder
    assert '[options copy]' in builder and 'options[@"wantsIMEI"]' in builder and 'options[@"webCompat"]' in builder
    packet = read('common/PXRuntimeIdentifierWriter.m').split('@implementation PXPreparedDeviceProfileGroup', 1)[1].split('@end', 1)[0]
    assert 'NSPropertyListImmutable' in packet and 'dataWithPropertyList:' in packet
    fixture = read('tests/PXRuntimeScalarPreparationTests.m')
    assert 'isKindOfClass:NSMutableString.class' not in fixture, 'class cluster membership cannot establish string mutability'
    uuid_factory = writers.method(scalar, 'static NSString *PXScalarLowerUUID(NSString *errorDomain, NSError **error)')
    assert 'return [uuid copy];' in uuid_factory, 'retain the production detached-copy contract'
    for variant in ('8000', '9111', 'a222', 'b333'):
        assert '-' + variant + '-' in fixture, f'UUID fixture must cover variant {variant[0]}'
    assert '@(UINT32_MAX)' in fixture and 'UUID fixture: type=' in fixture
    for case in ('scalar formats preserve case version and variant', 'device name patterns retain legacy templates',
                 'scalar results stay detached across mutable copies and subsequent generation',
                 'secure entropy failure preserves provider cache', 'serial prepare leaves existing identifier intact',
                 'serial clear never modifies borrowed immutable bytes', 'serial prefix reservations remain balanced across threads'):
        assert case in fixture, case
    model_fixture = read('tests/PXRuntimeDeviceGroupWriterTests.m')
    for case in ('model prepare captures options without source writes', 'prepared model deep detaches mutable provider graphs',
                 'prepared model publishes caches only after explicit commit'):
        assert case in model_fixture, case
    assert 'test_runtime_identity_preparation.py --native' in read('.github/workflows/build-ios-arm.yml')
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2H3N-partial'
    assert manifest['writers']['identifier-artifacts']['status'] == 'enrolled'
    assert manifest['writers']['profile-lifecycle']['status'] == 'partial'
    print('PASS: Model/scalar preparation source contracts (profile lifecycle pending; native runtime not implied)')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-scalar-preparation-') as temp:
        sources = ['common/PXRuntimeScalarPreparation.m', 'common/PXIdentityValidator.m',
                   *['common/' + row[1] + '.m' for row in writers.GENERATORS], 'tests/PXRuntimeScalarPreparationTests.m']
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            binary = Path(temp) / scheme
            subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions',
                            '-Darc4random=PXScalarFixtureRandom', '-Darc4random_uniform=PXScalarFixtureUniform',
                            '-DSecRandomCopyBytes=PXScalarFixtureSecure',
                            '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(ROOT / 'common'), *defines,
                            *[str(ROOT / source) for source in sources], '-framework', 'Foundation', '-framework', 'Security',
                            '-o', str(binary)], check=True, cwd=ROOT, timeout=90)
            for _ in range(3):
                subprocess.run([str(binary)], check=True, cwd=ROOT, timeout=60)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        native_tests()
