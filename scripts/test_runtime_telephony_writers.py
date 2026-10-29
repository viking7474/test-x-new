#!/usr/bin/env python3
"""4C.2D standalone telephony flow; --native reuses exact production group fixture."""
from pathlib import Path
import argparse
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding='utf-8')
spec = importlib.util.spec_from_file_location('device_group_writers', ROOT / 'scripts/test_runtime_device_group_writers.py')
groups = importlib.util.module_from_spec(spec)
spec.loader.exec_module(groups)


def source_contracts():
    source = read('common/IdentifierManager.m')
    signature = '- (NSString *)prepareAndPersistTelephonyValue:(NSString *)value type:(NSString *)type generate:(BOOL)generate'
    body = groups.method(source, signature)
    assert body.count('[self currentIdentifierMutation]') == 1
    assert 'NSString *identityDir = mutation.identityDirectory;' in body
    assert 'PXPerformRuntimeSourceWrite' not in body and '[mutation performSourceWrite:' in body
    assert '@finally { [mutation invalidate]; }' in body
    assert body.index('[type copy]') < body.index('[self currentIdentifierMutation]')
    assert body.count('cellularSpecForProductType:') == 1
    assert body.index('[value copy]') < body.index('[self isValidIMEI:prepared]') < body.index('[self currentIdentifierMutation]')
    assert body.index('[self currentIdentifierMutation]') < body.index('captureDeviceIDsAtIdentityDirectory:identityDir') < body.index('cellularSpecForProductType:')
    assert 'if (generate || [productType hasPrefix:@"iPhone"])' in body
    for token in ('if (!productType.length || !regulatoryModelNumber.length)',
                  'if (!enabled || (!isIMEI && !cdma))', 'PXIdentityHasAllowedPrefix(prepared, tacs)',
                  'PXIdentityHasAllowedPrefix(prepared, prefixes)', 'PXCellularPreparationDependencies(deviceIds)',
                  'PXStageRuntimeIdentifierValueWithDependencies(tx, identityDir, type, prepared, timestamp, expected, error)'):
        assert token in body, token
    for forbidden in ('saveCustomValue:', 'setCustomIMEI:', 'setCustomMEID:', 'dictionaryWithContentsOfFile:', 'writeToFile:', 'dispatch_'):
        assert forbidden not in body
    for wrapper, key, generate in (('- (BOOL)setCustomIMEI:(NSString *)value', 'IMEI', 'NO'),
                                    ('- (BOOL)setCustomMEID:(NSString *)value', 'MEID', 'NO'),
                                    ('- (NSString *)generateIMEI', 'IMEI', 'YES'),
                                    ('- (NSString *)generateMEID', 'MEID', 'YES')):
        wrapper_body = groups.method(source, wrapper)
        assert 'prepareAndPersistTelephonyValue:' in wrapper_body
        assert f'type:@"{key}" generate:{generate}' in wrapper_body
        assert 'profileIdentityPath' not in wrapper_body and wrapper in groups.SIGNATURES
    helper = read('common/PXRuntimeIdentifierWriter.m')
    stage = helper.split('BOOL PXStageRuntimeIdentifierValueWithDependencies(', 1)[1]
    assert '@{type: value}, @[type], expected, YES, NO, error' in stage
    assert 'PXRuntimeIdentifierSidecar(type)' in stage and '@"value": value, @"lastUpdated": timestamp' in stage
    fixture = read('tests/PXRuntimeDeviceGroupWriterTests.m')
    for case in ('four telephony APIs keep one target and one regional lookup',
                 'standalone IMEI and MEID keep independent fields and sidecars',
                 'telephony pair merges unrelated fields and increments once',
                 'four telephony APIs reject dependency drift without sidecar writes',
                 'telephony pair failure restores bytes counter and commit identity',
                 'invalid manual formats reject before target lookup', 'manual lowercase MEID spelling preserved',
                 'unknown cellular rejects all standalone APIs', 'disabled cellular rejects all standalone APIs',
                 'non CDMA rejects standalone MEID', 'valid checksums cannot bypass regional prefix policy',
                 'missing authoritative prefixes never use generic generation',
                 'manual input copy survives provider callbacks', 'iPhone writes reject missing regulatory slot',
                 'manual non iPhone compatibility policy preserved', 'telephony counter exhaustion preserves complete pair',
                 'malformed telephony sidecar is never silently replaced'):
        assert case in fixture, case
    for case in ('all telephony APIs reject busy lifecycle before target and DB lookup',
                 'all telephony APIs reject pending deletion before target and DB lookup',
                 'telephony provider reentry fails busy without deadlock',
                 'telephony owned success clears reentry error and increments once',
                 'telephony provider exception preserves sources and releases lease',
                 'late deletion blocks telephony sidecar IDs counter and commit token together',
                 'telephony rejects missing replaced and symlink identity without touching competitor bytes',
                 'telephony resolver exception releases acquired ownership',
                 'telephony missing selection fails before provider and releases lease',
                 'telephony copies type before provider can mutate caller input'):
        assert case in fixture, case
    assert 'TestTelephonyLifecycle(manager, Identity(@"a"), Identity(@"b"))' in fixture
    assert fixture.index('#import "PXProfileArtifactMutation.h"') < fixture.index('#include "PXDeviceGroupDeclarations.inc"')
    assert '- (PXProfileArtifactMutation *)currentIdentifierMutation' in groups.SIGNATURES
    assert 'common/PXProfileArtifactMutation.m' in read('scripts/test_runtime_device_group_writers.py')
    assert 'TestTelephony(manager, Identity(@"a"), Identity(@"b"))' in fixture
    workflow = read('.github/workflows/build-ios-arm.yml')
    assert 'test_runtime_telephony_writers.py' in workflow and 'test_runtime_device_group_writers.py --native' in workflow
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2H4R-partial'
    assert manifest['writers']['identifier-telephony']['status'] == 'enrolled'
    assert manifest['writers']['identifier-artifacts']['entryPoints'] == [
        'regenerateAllEnabledIdentifiers', 'regenerateAllEnabledIdentifiersWithError:',
        'regenerateAllEnabledIdentifiersForProfileID:networkArtifacts:error:',
        'commitRuntimeGenerationForProfileID:networkArtifacts:error:',
        'commitRuntimeGenerationForProfileID:networkArtifacts:lifecycleLease:error:',
        'regenerateAllEnabledIdentifiersForExpectedActiveProfileID:error:']
    assert manifest['writers']['profile-lifecycle']['status'] == 'partial'
    print('PASS: Standalone telephony source contracts (native runtime not implied; lifecycle rollout partial)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        groups.native_tests()
