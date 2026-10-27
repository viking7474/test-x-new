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
    '- (PXPreparedDeviceProfileGroup *)commitDeviceProfileGroupWithMutation:(PXProfileArtifactMutation *)mutation',
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
    '- (PXPreparedDeviceProfileGroup *)prepareDeviceProfileGroupWithOptions:(NSDictionary *)options error:(NSError **)error',
    '- (void)publishPreparedDeviceProfileGroup:(PXPreparedDeviceProfileGroup *)prepared',
    '- (NSDictionary *)prepareCellularRefreshForDeviceIDs:(NSDictionary *)capturedIDs options:(NSDictionary *)options error:(NSError **)error',
    '- (void)regenerateAllEnabledIdentifiers',
    '- (BOOL)regenerateAllEnabledIdentifiersWithError:(NSError **)error',
    '- (void)publishRuntimeGeneration:(NSDictionary *)payload identityDirectory:(NSString *)identityDir model:(PXPreparedDeviceProfileGroup *)model',
    '- (BOOL)regenerateAllEnabledIdentifiersForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)networkArtifacts error:(NSError **)error',
    '- (PXCommittedRuntimeGeneration *)ownedRuntimeGenerationForProfileID:(NSString *)profileID currentProfile:(BOOL)current networkArtifacts:(NSDictionary *)networkArtifacts deferSettings:(BOOL)deferSettings error:(NSError **)error',
    '- (NSString *)existingGenerationIdentityForProfileID:(NSString *)profileID error:(NSError **)error',
    '- (PXCommittedRuntimeGeneration *)commitRuntimeGenerationForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)networkArtifacts error:(NSError **)error',
    '- (BOOL)commitRuntimeGenerationAtIdentityDirectory:(NSString *)identityDir networkArtifacts:(NSDictionary *)networkArtifacts lifecycleLease:(PXProfileLifecycleLease *)lease deferSettings:(BOOL)deferSettings receipt:(PXCommittedRuntimeGeneration **)receipt error:(NSError **)error',
    '- (PXCommittedRuntimeGeneration *)commitRuntimeGenerationForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)networkArtifacts lifecycleLease:(PXProfileLifecycleLease *)lease error:(NSError **)error',
    '- (void)publishCommittedRuntimeGeneration:(PXCommittedRuntimeGeneration *)generation',
    '- (PXProfileArtifactMutation *)currentIdentifierMutation',
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
    'static NSSet<NSString *> *PXCanonicalIdentifierToggleKeys(void)',
    'static NSDictionary *PXSanitizedIdentifierSettings(NSDictionary *settings)',
]


def source_contracts():
    manager = read('common/IdentifierManager.m')
    helper = read('common/PXRuntimeIdentifierWriter.m')
    core = read('common/PXRuntimeSourceStore.m')
    for signature in SIGNATURES[:6]:
        body = method(manager, signature)
        assert 'writeToFile:' not in body and 'removeItemAtPath:' not in body
        if signature == SIGNATURES[0]:
            assert 'PXPerformRuntimeSourceWrite' in body
        else:
            assert 'PXPerformRuntimeSourceWrite' not in body
    for signature in (SIGNATURES[1], SIGNATURES[3], SIGNATURES[4], SIGNATURES[5]):
        body = method(manager, signature)
        assert body.count('[self currentIdentifierMutation]') == 1
        assert '@finally { [mutation invalidate]; }' in body
        assert 'profileIdentityPath' not in body
    for signature in (SIGNATURES[4], SIGNATURES[5]):
        body = method(manager, signature)
        assert 'captureDeviceIDsAtIdentityDirectory:identityDir' in body
        assert 'PXCellularPreparationDependencies(capturedIDs)' in body
        assert 'commitDeviceProfileGroupWithMutation:mutation' in body
        assert '[mutation performSourceWrite:' in body
    ios = method(manager, SIGNATURES[4])
    assert 'iosBuild:iosBuild' in ios and 'PXPopulateCanonicalCellularIdentity' in ios
    assert 'expected, NO, YES, error' in ios
    assert ios.index('if (!success)') < ios.index('setCurrentIOSVersionInfo:versionDict')
    assert ios.index('[mutation invalidate]') < ios.index('publishPreparedDeviceProfileGroup:prepared')
    assert '[mutation invalidate];\n        [[IOSVersionInfo sharedManager] setCurrentIOSVersionInfo:versionDict]' in ios
    custom = method(manager, SIGNATURES[3])
    assert '[value copy]' in custom and '[mutation performSourceWrite:' in custom
    assert custom.index('[mutation invalidate]') < custom.index('setCurrentDeviceModel:value')
    group = method(manager, SIGNATURES[2])
    assert '[NSMutableDictionary dictionaryWithContentsOfFile:' not in group
    assert 'prepared.updates, prepared.replacedKeys, nil, YES, YES, error' in group
    assert '[mutation performSourceWrite:' in group and 'mutation.identityDirectory' in group
    assert 'publishPreparedDeviceProfileGroup:' not in group and '[mutation invalidate]' not in group
    assert 'currentIdentifierMutation' not in group and 'return wrote ? prepared : nil' in group
    wrapper = method(manager, SIGNATURES[1])
    assert wrapper.index('[mutation invalidate]') < wrapper.index('publishPreparedDeviceProfileGroup:prepared')
    assert 'regenerateDeviceProfileGroupAtIdentityDirectory:' not in manager
    builder = method(manager, '- (PXPreparedDeviceProfileGroup *)prepareDeviceProfileGroupWithOptions:(NSDictionary *)options error:(NSError **)error')
    assert 'initWithUpdates:deviceIds replacedKeys:managedKeys versionInfo:version error:error' in builder
    for forbidden in ('self.error', 'profileIdentityPath', 'PXPerformRuntimeSourceWrite', 'setCurrentIOSVersionInfo:', 'setCurrentDeviceModel:'):
        assert forbidden not in builder
    publisher = method(manager, '- (void)publishPreparedDeviceProfileGroup:(PXPreparedDeviceProfileGroup *)prepared')
    assert 'setCurrentIOSVersionInfo:prepared.versionInfo' in publisher and 'setCurrentDeviceModel:ids[@"DeviceModel"]' in publisher
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
    for case in ('dependency APIs including fallbacks fail busy before target preparation and publication',
                 'dependency APIs including fallbacks stop at pending deletion',
                 'dependency preparation reentry fails busy instead of acquiring recursively',
                 'dependency success and missing tuple fallbacks share scope without changing counter policy',
                 'dependency preparation exception preserves sources caches and releases ownership',
                 'dependency late deletion prevents tuple sidecar removal and publication',
                 'dependency namespace replacement never stages or removes competitor files',
                 'owned dependency commit fault restores complete tuple sidecars counter and token',
                 'dependency compatibility callback can acquire fresh scope after release',
                 'throwing software publication preserves already committed source',
                 'custom model detaches mutable caller before DB callbacks and publication',
                 'missing dependency selection rejects before provider work',
                 'owned custom model preserves non iPhone validation fallback and counter',
                 'invalid custom model keeps validation before target ownership'):
        assert case in fixture, case
    assert 'TestDependencyLifecycle(manager, Identity(@"a"), Identity(@"b"))' in fixture
    assert 'test_runtime_device_group_writers.py --native' in read('.github/workflows/build-ios-arm.yml')
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2H3L-partial'
    assert manifest['writers']['identifier-dependencies']['status'] == 'enrolled'
    assert manifest['writers']['identifier-artifacts']['status'] == 'enrolled'
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
                   'common/PXRuntimeProfileSelection.m', 'common/PXProfileLifecycleLease.m', 'common/PXProfileDeletionJournal.m',
                   'common/PXProfileArtifactMutation.m',
                   'common/PXRuntimeGeneration.m', 'common/PXRuntimeArtifactPreparation.m',
                   'common/PXRuntimeArtifactWriter.m', 'common/PXRuntimeScalarPreparation.m',
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
