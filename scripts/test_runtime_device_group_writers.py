#!/usr/bin/env python3
"""4C.2C/D production dependency/telephony writers; native fixture on macOS."""
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
identifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(identifier)
method = identifier.method
SIGNATURES = [
    '- (NSDictionary *)captureDeviceIDsAtIdentityDirectory:(NSString *)identityDir',
    '- (NSString *)regenerateDeviceProfileGroup',
    '- (NSString *)regenerateDeviceProfileGroupAtIdentityDirectory:(NSString *)identityDir',
    '- (BOOL)setCustomDeviceModel:(NSString *)value',
    '- (NSDictionary *)generateIOSVersion',
    '- (BOOL)refreshCanonicalCellularIdentityForCurrentProfile',
    '- (NSString *)prepareAndPersistTelephonyValue:(NSString *)value type:(NSString *)type generate:(BOOL)generate',
    '- (BOOL)setCustomIMEI:(NSString *)value',
    '- (BOOL)setCustomMEID:(NSString *)value',
    '- (NSString *)generateIMEI',
    '- (NSString *)generateMEID',
    '- (BOOL)isValidIMEI:(NSString *)imei',
    '- (BOOL)isValidMEID:(NSString *)meid',
]
STATICS = [
    'static NSString *PXWebCompatMaxIOSForDeviceMaxIOS(NSString *deviceMaxIOS)',
    'static NSUInteger PXRandomIndex3(NSUInteger upperBoundExclusive)',
    'static NSString *PXGenerateIMEIFromAuthoritativeTACs(NSArray *tacs)',
    'static NSString *PXGenerateMEIDFromAuthoritativePrefixes(NSArray *prefixes)',
    'static BOOL PXIdentityHasAllowedPrefix(NSString *value, NSArray *prefixes)',
    # Multiline signature is taken from the source below.
    'static BOOL PXPopulateCanonicalCellularIdentity',
    'static NSArray<NSString *> *PXCellularManagedKeys(void)',
    'static NSDictionary *PXCellularPreparationDependencies(NSDictionary *ids)',
    'static NSDictionary *PXPickHardwareVariantFromModelSpec(NSDictionary *modelSpec)',
    'static NSString *PXPickRegulatoryModelNumberFromModelSpec(NSDictionary *modelSpec, NSDictionary *pickedVariant)',
    'static NSArray<NSString *> *PXDeviceProfileManagedKeys(void)',
    'static NSInteger PXHexValue(unichar c)',
    'static NSInteger PXMEIDLuhnCheckDigit(NSString *body)',
]


def source_contracts():
    manager = read('common/IdentifierManager.m')
    helper = read('common/PXRuntimeIdentifierWriter.m')
    core = read('common/PXRuntimeSourceStore.m')
    for signature in SIGNATURES[:6]:
        body = method(manager, signature)
        assert 'writeToFile:' not in body and 'removeItemAtPath:' not in body
        if signature != '- (NSString *)regenerateDeviceProfileGroup':
            assert 'PXPerformRuntimeSourceWrite' in body
    for signature in (SIGNATURES[4], SIGNATURES[5]):
        body = method(manager, signature)
        assert body.count('[self profileIdentityPath]') == 1
        assert 'captureDeviceIDsAtIdentityDirectory:identityDir' in body
        assert 'PXCellularPreparationDependencies(capturedIDs)' in body
        assert 'regenerateDeviceProfileGroupAtIdentityDirectory:identityDir' in body
    ios = method(manager, SIGNATURES[4])
    assert 'iosBuild:iosBuild' in ios and 'PXPopulateCanonicalCellularIdentity' in ios
    assert 'expected, NO, YES, error' in ios
    assert ios.index('if (!success)') < ios.index('setCurrentIOSVersionInfo:versionDict')
    group = method(manager, SIGNATURES[2])
    assert '[NSMutableDictionary dictionaryWithContentsOfFile:' not in group
    assert 'managedKeys, nil, YES, YES, error' in group
    assert group.index('if (!wrote)') < group.index('setCurrentDeviceModel:productType')
    assert 'PXRemoveLegacyCellularFiles' not in manager
    assert 'replacedKeys, NSDictionary *expected' in helper
    assert helper.index('Identifier dependencies changed') < helper.index('[ids removeObjectsForKeys:replacedKeys]')
    assert 'removeDictionaryAtPath:' in helper and 'removeDictionaryAtPath:' in core
    assert 'self.staged[path] == NSNull.null' in core and 'transaction.staged[path] == NSNull.null' in core
    fixture = read('tests/PXRuntimeDeviceGroupWriterTests.m')
    for case in ('unrelated update survives preparation', 'fixed target survives profile switch',
                 'model rollback restores removed sidecars', 'custom model preserves counter',
                 'software refresh includes matching baseband', 'dependency drift rejects prepared software',
                 'cellular refresh preserves valid IMEI', 'missing model fallback keeps captured target',
                 'known cellular without firmware fails closed', 'counter exhaustion leaves entire group intact'):
        assert case in fixture, case
    assert 'test_runtime_device_group_writers.py --native' in read('.github/workflows/build-ios-arm.yml')
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2D-partial'
    assert manifest['writers']['identifier-dependencies']['status'] == 'enrolled'
    assert manifest['writers']['identifier-artifacts']['status'] == 'pending'
    print('PASS: Device dependency writer contracts (partial enrollment; native runtime not implied)')


def generate_native_fragments(folder):
    manager = read('common/IdentifierManager.m')
    methods = [method(manager, signature) for signature in SIGNATURES]
    (folder / 'PXDeviceGroupDeclarations.inc').write_text('\n'.join(m.split(' {', 1)[0] + ';' for m in methods), encoding='utf-8')
    (folder / 'PXDeviceGroupMethods.inc').write_text('\n\n'.join(methods), encoding='utf-8')
    statics = ['static NSInteger PXMEIDLuhnCheckDigit(NSString *body);']
    for signature in STATICS:
        if signature == 'static BOOL PXPopulateCanonicalCellularIdentity':
            start = manager.index(signature + '(')
            signature = manager[start:manager.index(' {', start)]
        statics.append(method(manager, signature))
    (folder / 'PXDeviceGroupStatics.inc').write_text('\n\n'.join(statics), encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-device-groups-') as temp:
        folder = Path(temp)
        generate_native_fragments(folder)
        sources = ['common/PXRuntimeIdentifierWriter.m', 'common/PXRuntimeSourceStore.m', 'common/PXRuntimePublisher.m',
                   'common/PXDeviceProfileSchema.m', 'common/PXIdentityValidator.m', 'common/VersionCompare.m',
                   'tests/PXRuntimeDeviceGroupWriterTests.m']
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            binary = folder / scheme
            subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions',
                            '-DPX_SOURCE_TRANSACTION_TESTING=1', '-Wall', '-Wextra', '-Werror=implicit-function-declaration',
                            '-I', str(ROOT / 'common'), '-I', str(folder), *defines,
                            *[str(ROOT / source) for source in sources], '-framework', 'Foundation', '-framework', 'Security',
                            '-o', str(binary)], check=True, cwd=ROOT, timeout=60)
            for _ in range(3):
                subprocess.run([str(binary)], check=True, cwd=ROOT, timeout=90)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        native_tests()
