#!/usr/bin/env python3
"""4C.2G fixed-target batch generation; --native uses exact production methods."""
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
    manager = read('common/IdentifierManager.m')
    current = groups.method(manager, '- (BOOL)regenerateAllEnabledIdentifiersWithError:(NSError **)error')
    flow = groups.method(manager, '- (BOOL)commitRuntimeGenerationAtIdentityDirectory:(NSString *)identityDir networkArtifacts:(NSDictionary *)networkArtifacts lifecycleLease:(PXProfileLifecycleLease *)lease expectedSelection:(NSDictionary *)selection deferSettings:(BOOL)deferSettings receipt:(PXCommittedRuntimeGeneration **)receipt error:(NSError **)error')
    publisher_wrapper = groups.method(manager, '- (PXCommittedRuntimeGeneration *)ownedRuntimeGenerationForProfileID:(NSString *)profileID currentProfile:(BOOL)current networkArtifacts:(NSDictionary *)networkArtifacts deferSettings:(BOOL)deferSettings error:(NSError **)error')
    wrapper = groups.method(manager, '- (void)regenerateAllEnabledIdentifiers')
    assert 'regenerateAllEnabledIdentifiersWithError:&error' in wrapper
    assert publisher_wrapper.count('[self profileIdentityPathWithLifecycleLease:lease]') == 1
    assert 'ownedRuntimeGenerationForProfileID:nil currentProfile:YES' in current
    assert publisher_wrapper.index('acquireInDirectory:') < publisher_wrapper.index('[self profileIdentityPathWithLifecycleLease:lease]')
    assert publisher_wrapper.index('PXRequireNoPendingProfileDeletion') < publisher_wrapper.index('[self profileIdentityPathWithLifecycleLease:lease]')
    assert '@finally { [lease invalidate]; }' in publisher_wrapper
    assert current.index('ownedRuntimeGenerationForProfileID:') < current.index('publishCommittedRuntimeGeneration:')
    assert 'directoryProofForProfileID:' in flow and 'validateForDirectory:' in flow
    assert flow.index('PXProfileDeletionJournalPath() exists:') < flow.index('PXStageRuntimeGeneration(')
    borrowed = groups.method(manager, '- (PXCommittedRuntimeGeneration *)commitRuntimeGenerationForProfileID:(NSString *)profileID networkArtifacts:(NSDictionary *)networkArtifacts lifecycleLease:(PXProfileLifecycleLease *)lease error:(NSError **)error')
    assert 'validateForDirectory:PXProfilesPath()' in borrowed and '[lease invalidate]' not in borrowed
    assert 'profileIdentityPath' not in flow
    assert flow.index('PXSanitizedIdentifierSettings(self.settings)') < flow.index('prepareDeviceProfileGroupWithOptions:')
    assert flow.index('PXStageRuntimeGeneration(') < flow.index('initWithIdentityDirectory:')
    assert publisher_wrapper.index('commitRuntimeGenerationAtIdentityDirectory:') < publisher_wrapper.index('@finally')
    assert flow.index('initWithIdentityDirectory:') < flow.index('if (!committed)')
    assert 'return committedGeneration != nil;' in flow
    assert 'publishRuntimeGeneration:' not in flow
    expected_api = groups.method(manager, '- (BOOL)regenerateAllEnabledIdentifiersForExpectedActiveProfileID:(NSString *)profileID error:(NSError **)error')
    assert 'PXValidatedProfileID(profileID)' in expected_api and 'ownedRuntimeGenerationForProfileID:expected currentProfile:YES' in expected_api
    assert publisher_wrapper.index('captureExpectedActiveSelection:') < publisher_wrapper.index('existingGenerationIdentityForProfileID:')
    assert flow.count('PXRuntimeProfileSelectionMatches(') == 2
    assert flow.index('PXRuntimeProfileSelectionMatches(') < flow.index('prepareDeviceProfileGroupWithOptions:')
    assert flow.rindex('PXRuntimeProfileSelectionMatches(') < flow.index('PXStageRuntimeGeneration(')
    legacy_core = groups.method(manager, '- (BOOL)commitRuntimeGenerationAtIdentityDirectory:(NSString *)identityDir networkArtifacts:(NSDictionary *)networkArtifacts lifecycleLease:(PXProfileLifecycleLease *)lease deferSettings:(BOOL)deferSettings receipt:(PXCommittedRuntimeGeneration **)receipt error:(NSError **)error')
    assert 'expectedSelection:nil' in legacy_core
    for forbidden in ('[self saveSettings]', 'generateWiFiInfo]', 'generateBootTimeForProfile:',
                      'setTotalStorageCapacity:', 'generateDeviceTheme]', 'setCustomValue:', 'dispatch_'):
        assert forbidden not in flow, forbidden
    stage = read('common/PXRuntimeGeneration.m')
    assert stage.index('Generation dependencies changed') < stage.index('PXStageRuntimeIdentifierReplacement(')
    for token in ('PXStageRuntimeWiFi(', 'PXStageRuntimeUptime(', 'PXStageRuntimeBattery(',
                  'PXStageRuntimeIdentifierValue(', 'StorageSystemEnabled', 'ScopedApps', 'NSPropertyListImmutable'):
        assert token in stage, token
    for forbidden in ('PXActiveProfile', 'sharedManager', 'NSNotification', 'writeToFile:', 'dispatch_async', 'PXPerformRuntimeSourceWrite'):
        assert forbidden not in stage, forbidden
    publisher = groups.method(manager, '- (void)publishRuntimeGeneration:(NSDictionary *)payload identityDirectory:(NSString *)identityDir model:(PXPreparedDeviceProfileGroup *)model publicationGuard:(BOOL (^)(NSArray *, NSArray *))guard')
    assert 'PXActiveProfileID()' in publisher and '@catch' in publisher
    assert publisher.index('removeAllObjects]') < publisher.index('publishCommittedBatteryInfo:')
    assert 'checkedPublication:YES' in expected_api
    legacy_publication = groups.method(manager, '- (void)publishCommittedRuntimeGeneration:(PXCommittedRuntimeGeneration *)generation')
    assert 'checkedPublication:NO' in legacy_publication
    publication_wrapper = groups.method(manager, '- (void)publishCommittedRuntimeGeneration:(PXCommittedRuntimeGeneration *)generation checkedPublication:(BOOL)checked')
    assert publication_wrapper.index('PXRuntimeGenerationMatchesProof') < publication_wrapper.index('publicationGuard:guard')
    assert 'runtimeGenerationPublicationIsCurrent:generation identifierKeys:keys artifactPaths:paths' in publication_wrapper
    checkpoint = groups.method(manager, '- (BOOL)runtimeGenerationPublicationIsCurrent:(PXCommittedRuntimeGeneration *)generation identifierKeys:(NSArray *)keys artifactPaths:(NSArray *)paths')
    for token in ('runtimePublicationHasCurrentIdentity:identity transaction:tx error:error', 'for (NSString *key in keys)', 'for (NSString *path in paths)', 'PXRuntimeGenerationMatchesProof(tx, @{path: record}', 'exists:&exists'):
        assert token in checkpoint, token
    for forbidden in ('setDictionary:', 'sharedManager', 'self.error', 'generation.proof,', 'dispatch_'):
        assert forbidden not in checkpoint, forbidden
    assert 'guard(@[type], paths)' in publisher and 'if (!guard || guard(batteryKeys, batteryPaths))' in publisher
    assert publisher.index('adoptCommittedBatteryInfo:') < publisher.index('if (!guard || guard(batteryKeys, batteryPaths))') < publisher.index('publishCommittedBatteryInfo:')
    required_signature = '- (BOOL)enableRequiredIdentifiers:(NSArray<NSString *> *)types forExpectedActiveProfileID:(NSString *)profileID error:(NSError **)error'
    assert required_signature in groups.SIGNATURES and required_signature in read('TLinkIOS.h')
    required = groups.method(manager, required_signature)
    for token in ('PXValidatedProfileID(profileID)', '[type copy]', '[capturedTypes copy]', 'captureExpectedActiveSelection:expected',
                  'PXProfileDeletionJournalPath() exists:&pending', 'PXStageRuntimeGenerationSettings(tx, payload, writeError)',
                  'wrote = success && changed;', 'PXPerformStandaloneRuntimeSourceWrite(', 'PXDetachRuntimeGeneration(', '@finally { [lease invalidate]; }'):
        assert token in required, token
    assert required.index('[capturedTypes copy]') < required.index('acquireInDirectory:') < required.index('captureExpectedActiveSelection:')
    assert required.index('PXRuntimeProfileSelectionMatches(') < required.index('PXStageRuntimeGenerationSettings(')
    assert required.index('[lease invalidate]') < required.index('self.settings[type] = @YES') < required.index('PXPostSettingsChangedNotification()')
    for forbidden in ('profileIdentityPath', 'existingGenerationIdentityForProfileID:', 'setIdentifierEnabled:', 'currentValueForIdentifier:',
                      'prepareDeviceProfileGroup', 'publishPreparedIdentifier:', '[self saveSettings]', 'dispatch_'):
        assert forbidden not in required, forbidden
    for file, signature in (
        ('WiFi', '- (void)adoptCommittedWiFiInfo:(NSDictionary *)wifiInfo profileID:(NSString *)profileID'),
        ('Battery', '- (void)adoptCommittedBatteryInfo:(NSDictionary *)batteryInfo'),
        ('Storage', '- (void)adoptCommittedStorageInfo:(NSDictionary *)storageInfo'),
        ('Uptime', '- (void)adoptCommittedUptimeInfo:(NSDictionary *)uptimeInfo timestamp:(NSDate *)timestamp'),
    ):
        body = groups.method(read(f'common/{file}Manager.m'), signature)
        assert 'save' not in body and 'Notification' not in body and 'PXActiveProfile' not in body
    battery = groups.method(read('common/BatteryManager.m'), '- (void)publishCommittedBatteryInfo:(NSDictionary *)batteryInfo timestamp:(NSDate *)timestamp')
    assert 'saveBatteryInfoToDisk' not in battery and 'PXPerformRuntimeSourceWrite' not in battery
    fixture = read('tests/PXRuntimeDeviceGroupWriterTests.m')
    for case in ('required flags commit once without target resolution providers migration or profile artifact writes',
                 'required packet keeps enable-only policy unrelated flags top-level keys scope and storage alias',
                 'already enabled required packet validates selection without writes or notification',
                 'required packet rejects authoritative mismatch even when all flags are already enabled',
                 'required flag fault rolls back settings scope and memory without publication',
                 'required packet revalidates selection receipt and deletion before staging any flag',
                 'busy required packet rejects before selection capture and settings mutation',
                 'required packet freezes caller ID container and strings before source callbacks',
                 'required packet including no-op rejects nested source acknowledgement before publication',
                 'required flag notification exception after ownership release preserves committed success'):
        assert case in fixture, case
    assert 'TestRequiredIdentifiers(Identity(@"a"), Identity(@"b"))' in fixture
    for case in ('expected generation checks authoritative post-commit selection without negating source success or matching metadata merges',
                 'generation field and sidecar checkpoints skip only stale callback inputs',
                 'generation rechecks between software and model callbacks including throwing reentry',
                 'generation rechecks each scalar and battery publication after reentrant adoption',
                 'expected generation publication uses source selection even when resolver cache is stale',
                 'generic generation retains legacy publication without targeted checkpoint reads'):
        assert case in fixture, case
    assert 'TestExpectedGenerationPublication(Identity(@"a"), Identity(@"b"))' in fixture
    for case in ('expected active mismatch rejects before target lookup migration providers writes or caches',
                 'expected owners reject busy lifecycle before resolving target',
                 'expected owners reject invalid IDs without selection repair',
                 'expected owners freeze caller ID and never resolve the stale current profile',
                 'expected selection receipt drift aborts complete generation or preview before source commit and publication',
                 'expected owner source fault rolls back artifacts without cache or notification effects',
                 'expected owners preserve legacy fallback without creating or repairing canonical selection'):
        assert case in fixture, case
    assert 'TestExpectedActiveOwners(manager, Identity(@"a"), Identity(@"b"))' in fixture
    expected_cases = groups.method(fixture, 'static void TestExpectedActiveOwners(PXDeviceGroupFixture *manager, NSString *a, NSString *b)')
    assert '[other[@"files"] isEqual:after[@"files"]]' in expected_cases
    assert '![other[@"sourceCommitID"] isEqual:after[@"sourceCommitID"]]' in expected_cases
    assert '[other isEqual:Snapshot(b)]' not in expected_cases, 'a successful A commit changes the store-wide marker, not B file bytes'
    for case in ('whole regenerate commits once at one captured target',
                 'whole batch rollback restores artifacts settings scope',
                 'batch scalar preparation failure leaves all source and caches intact',
                 'batch dependency drift rejects entire candidate including absence',
                 'batch freezes nested caller intent and merges unrelated updates',
                 'batch target switch commits A and skips inactive compatibility caches',
                 'post commit callback exception cannot report a false rollback',
                 'batch counter exhaustion prevents every artifact and notification',
                 'batch malformed beforeimage fails without replacing any source',
                 'batch disabled options preserve tuple and unconditional WiFi policy',
                 'batch cellular only refresh preserves model and build',
                 'batch missing baseline seeds canonical group with frozen cellular policy',
                 'held lifecycle lease blocks current batch before target lookup',
                 'held lifecycle lease blocks explicit batch before migration',
                 'held lifecycle lease blocks standalone deferred generation',
                 'busy generation leaves source providers target resolution and caches untouched',
                 'borrowed generation succeeds without recursively acquiring or releasing caller lease',
                 'borrowed generation exception preserves source and caller lease',
                 'invalidated capability rejected before migration and providers',
                 'wrong root capability rejected while preserving its ownership',
                 'borrowed capability accepts configured root aliases by inode',
                 'pending deletion blocks all owned batch APIs before target lookup migration or preparation',
                 'pending deletion also blocks borrowed batch without releasing caller',
                 'owned provider exception leaves source and callbacks untouched',
                 'batch holds lifecycle during providers and releases before compatibility publication',
                 'late deletion intent rejects batch before staging any artifact',
                 'directory replacement rejects prepared batch without writing replacement or old target'):
        assert case in fixture, case
    for source in ('common/PXRuntimeGeneration.m', 'common/PXRuntimeScalarPreparation.m', 'common/PXRuntimeArtifactPreparation.m',
                   'common/PXProfileLifecycleLease.m', 'common/PXProfileDeletionJournal.m'):
        assert source in read('scripts/test_runtime_device_group_writers.py')
    assert 'test_runtime_generation.py' in read('.github/workflows/build-ios-arm.yml')
    assert 'test_runtime_generation.py' in read('scripts/release_hardening.py')
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2H5G-partial'
    assert manifest['writers']['identifier-artifacts']['status'] == 'enrolled'
    assert manifest['writers']['profile-lifecycle']['status'] == 'partial'
    assert manifest['writers']['dashboard-preview']['status'] == 'enrolled'
    assert manifest['writers']['storage-preference']['status'] == 'enrolled'
    for pending in ('security-store', 'security-direct'):
        assert manifest['writers'][pending]['status'] == 'partial'
    print('PASS: Whole-regenerate source contracts (partial enrollment; native runtime not implied)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        groups.native_tests()
