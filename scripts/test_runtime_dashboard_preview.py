#!/usr/bin/env python3
"""Owned dashboard preview coordinator; --native uses exact production group fixture."""
from pathlib import Path
import argparse
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding='utf-8')
spec = importlib.util.spec_from_file_location('device_groups', ROOT / 'scripts/test_runtime_device_group_writers.py')
groups = importlib.util.module_from_spec(spec)
spec.loader.exec_module(groups)


def source_contracts():
    source = read('common/IdentifierManager.m')
    signature = '- (BOOL)applyDashboardPreview:(NSDictionary *)preview expectedActiveProfileID:(NSString *)profileID error:(NSError **)error'
    body = groups.method(source, signature)
    ui = groups.method(read('TLinkIOSViewController.m'), '- (BOOL)applyFakePreviewToCurrentProfile:(NSDictionary *)preview')
    assert 'applyDashboardPreview:preview error:&error' in ui
    for forbidden in ('writeToFile:', 'setCustomDeviceModel:', 'setCustomDeviceName:', 'setCustomSerialNumber:',
                      'setTotalStorageCapacity:', 'setFreeStorageSpace:', 'setFilesystemType:', 'dispatch_'):
        assert forbidden not in body and forbidden not in ui, forbidden
    assert body.count('[self currentIdentifierMutation]') == 1
    assert body.count('[mutation performSourceWrite:') == 1
    assert body.index('[value copy]') < body.index('[self currentIdentifierMutation]') < body.index('captureDeviceIDsAtIdentityDirectory:')
    assert 'NSPropertyListImmutable' in body and 'dataWithPropertyList:' in body
    for token in ('PXStageRuntimeIdentifierReplacement', 'PXStageRuntimeIdentifierValue', 'PXStageRuntimeIdentifierState',
                  'currentStorageInfo', 'storage.plist', 'CommittedAt', 'serial.length < 8', 'PXRuntimeIdentifierDependencies'):
        assert token in body, token
    assert body.index('[mutation invalidate]') < body.index('setCurrentDeviceModel:') < body.index('adoptCommittedStorageInfo:')
    assert '@finally' in body and 'if (!committed && error) *error = self.error;' in body
    assert 'if (!committed) return NO;' in body and '@catch' in body
    assert body.count('dashboardPreviewPublicationIsCurrentAtIdentity:publicationIdentity') == 2
    assert body.index('[mutation invalidate]') < body.index('dashboardPreviewPublicationIsCurrentAtIdentity:publicationIdentity') < body.index('setCurrentDeviceModel:')
    publication = groups.method(source, '- (BOOL)dashboardPreviewPublicationIsCurrentAtIdentity:(NSString *)identity model:(NSString *)model storage:(NSDictionary *)storage')
    for token in ('PXReadRuntimeProfileSelection(', 'isEqual:profileID', 'ids[@"DeviceModel"] isEqual:model', '[current isEqual:storage]', 'exists:&exists'):
        assert token in publication, token
    for forbidden in ('setCurrent', 'adoptCommitted', 'sharedManager', 'setDictionary:', 'dispatch_', 'self.error'):
        assert forbidden not in publication, forbidden
    assert 'identifierMutationForExpectedProfileID:profileID selection:&selection' in body
    assert body.index('PXRuntimeProfileSelectionMatches(') < body.index('PXStageRuntimeIdentifierReplacement(')
    expected_owner = groups.method(source, '- (PXProfileArtifactMutation *)identifierMutationForExpectedProfileID:(NSString *)profileID selection:(NSDictionary **)selection')
    assert expected_owner.index('acquireWithIdentityResolverUsingLease:') < expected_owner.index('captureExpectedActiveSelection:') < expected_owner.index('existingGenerationIdentityForProfileID:')
    assert 'profileIdentityPath' not in expected_owner
    capture = groups.method(source, '- (NSDictionary *)captureExpectedActiveSelection:(NSString *)profileID lifecycleLease:(PXProfileLifecycleLease *)lease error:(NSError **)error')
    assert capture.index('validateForDirectory:') < capture.index('PXReadRuntimeProfileSelection(')
    for forbidden in ('PXStage', 'writeToFile:', 'PXActiveProfileID()', 'profileIdentityPath'):
        assert forbidden not in capture
    legacy = groups.method(source, '- (BOOL)applyDashboardPreview:(NSDictionary *)preview error:(NSError **)error')
    assert 'expectedActiveProfileID:nil' in legacy
    builder = groups.method(source, '- (PXPreparedDeviceProfileGroup *)prepareCustomDeviceModel:(NSString *)value error:(NSError **)error')
    for forbidden in ('self.error', 'performSourceWrite:', 'profileIdentityPath', 'setCurrentDeviceModel:'):
        assert forbidden not in builder
    for method in (signature, '- (BOOL)validateCustomDeviceModel:(NSString *)value error:(NSError **)error',
                   '- (PXPreparedDeviceProfileGroup *)prepareCustomDeviceModel:(NSString *)value error:(NSError **)error'):
        assert method in groups.SIGNATURES
    fixture = read('tests/PXRuntimeDeviceGroupWriterTests.m')
    for case in ('expected preview skips stale publication after post-commit selection or model changes',
                 'expected preview publishes matching model but skips newer storage values',
                 'preview model callback may publish newer target without stale storage overwrite',
                 'expected preview publication suppression preserves source success and released ownership',
                 'generic preview preserves legacy cache publication without checkpoint reads'):
        assert case in fixture, case
    for case in ('custom model builder prepares detached replacement without source or cache effects',
                 'busy dashboard stops before target providers and all candidate writes',
                 'pending deletion blocks dashboard without partial setters',
                 'dashboard model sidecars tuple storage and legacy counter policy commit together once before caches',
                 'dashboard storage keeps legacy cache authority and unrelated cached fields',
                 'dashboard storage selection uses final preview model instead of previous persisted model',
                 'dashboard fault at each written source restores hardware tuple sidecars storage counter and token',
                 'dashboard storage preparation failure writes no source',
                 'dashboard model preparation failure has no partial model name serial or storage write',
                 'dashboard malformed DB tuple never publishes a partial software identity',
                 'dashboard freezes mutable intent merges unrelated updates and keeps one captured target',
                 'dashboard provider exception releases ownership without mutation',
                 'late deletion rejects entire dashboard candidate before staging',
                 'dashboard rejects missing replaced or symlink identity without source or cache publication',
                 'dashboard software resolution rejects captured model drift without overwriting competitor',
                 'dashboard counter exhaustion rolls back all intermediate increments',
                 'dashboard rejects short serial rather than writing unpaired invalid scalar',
                 'dashboard committed source remains success after compatibility callback exception'):
        assert case in fixture, case
    assert 'otherBefore = Snapshot(b)[@"files"]' in fixture, 'a successful A commit changes the global token; compare only B file bytes'
    assert 'TestDashboardPreview(manager, Identity(@"a"), Identity(@"b"))' in fixture
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2H4R-partial'
    assert manifest['writers']['dashboard-preview']['status'] == 'enrolled'
    assert manifest['writers']['profile-lifecycle']['status'] == 'partial'
    assert 'test_runtime_dashboard_preview.py' in read('.github/workflows/build-ios-arm.yml')
    assert 'test_runtime_dashboard_preview.py' in read('scripts/release_hardening.py')
    print('PASS: Dashboard preview source contracts (whole reset workflow partial; native runtime not implied)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        groups.native_tests()
