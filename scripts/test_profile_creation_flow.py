#!/usr/bin/env python3
"""4C.2H1 creation completion, fixed-target generation and paired selection."""
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
CREATE = '- (void)createProfile:(Profile *)profile completion:(void (^)(BOOL success, NSError * _Nullable error))completion'
SWITCH = '- (void)switchToProfile:(Profile *)profile completion:(void (^)(BOOL success, NSError * _Nullable error))completion'
METHODS = [CREATE, SWITCH,
    '- (void)updateProfile:(Profile *)profile completion:(void (^)(BOOL success, NSError * _Nullable error))completion',
    '- (void)deleteProfile:(Profile *)profile completion:(void (^)(BOOL success, NSError * _Nullable error))completion',
    '- (NSDictionary *)prepareNetworkArtifactsWithOptions:(NSDictionary *)options error:(NSError **)error',
    '- (BOOL)persistProfileSelectionInfo:(NSDictionary *)info error:(NSError **)error',
    '- (BOOL)updateCurrentProfileInfoWithProfile:(Profile *)profile error:(NSError **)error',
    '- (BOOL)saveCentralProfileInfo:(NSDictionary *)infoDict',
    '- (void)saveProfilesWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion',
    '- (NSString *)generateProfileID', '- (BOOL)isNumericString:(NSString *)string',
    '- (void)publishProfileChangedNotification',
    '- (void)finishProfileCreation:(Profile *)profile targetID:(NSString *)targetID generation:(PXCommittedRuntimeGeneration *)generation expectedSelection:(NSDictionary *)expected error:(NSError *)generationError completion:(void (^)(BOOL success, NSError * _Nullable error))completion',
    '- (NSDictionary *)captureProfileSelectionWithError:(NSError **)error',
    '- (NSString *)identityForActivationProfile:(Profile *)profile generation:(PXCommittedRuntimeGeneration *)generation error:(NSError **)error',
    '- (BOOL)validateActivationForProfile:(Profile *)profile expectedSelection:(NSDictionary *)expected generation:(PXCommittedRuntimeGeneration *)generation error:(NSError **)error',
    '- (BOOL)activateProfile:(Profile *)profile expectedSelection:(NSDictionary *)expected generation:(PXCommittedRuntimeGeneration *)generation error:(NSError **)error',
    '- (BOOL)bootstrapProfileSelectionWithError:(NSError **)error',
    '- (void)scheduleProfileMirrorForSelection:(NSDictionary *)expected',
    '- (void)loadProfilesWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion',
    '- (NSDictionary *)loadCentralProfileInfo',
    '- (Profile *)loadCurrentProfileInfoFromCentralStore',
    '- (Profile *)currentProfile',
    '- (void)updateCurrentProfileInfoWithProfile:(Profile *)profile',
    '- (void)createProfileZeroImmediately',
    '- (BOOL)refreshCurrentProfileFromCommittedSelectionWithError:(NSError **)error']


def source_contracts():
    source = read('common/ProfileManager.m')
    create = writers.method(source, CREATE)
    for signature in METHODS[:4]:
        body = writers.method(source, signature)
        assert 'if (!NSThread.isMainThread)' in body and 'if (self.creationInProgress)' in body
    finish = writers.method(source, '- (void)finishProfileCreation:(Profile *)profile targetID:(NSString *)targetID generation:(PXCommittedRuntimeGeneration *)generation expectedSelection:(NSDictionary *)expected error:(NSError *)generationError completion:(void (^)(BOOL success, NSError * _Nullable error))completion')
    assert create.index('NSString *targetID = [profile.profileId copy]') < create.index('dispatch_get_global_queue')
    assert 'commitRuntimeGenerationForProfileID:targetID' in create
    for forbidden in ('terminateEnabledScopedApps', 'mutableCurrentProfile =', 'mutableProfiles addObject:', 'updateCurrentProfileInfoWithProfile:'):
        assert forbidden not in create, forbidden
    assert finish.index('validateActivationForProfile:') < finish.index('mutableProfiles addObject:') < finish.index('saveProfilesWithCompletion:')
    assert finish.index('saveProfilesWithCompletion:') < finish.index('activateProfile:') < finish.index('publishCommittedRuntimeGeneration:')
    assert 'removeObjectIdenticalTo:profile' in finish
    assert finish.index('self.creationInProgress = NO;', finish.index('activateProfile:')) < finish.index('if (completion) completion(activated,')
    for forbidden in ('NSInvocation', '__unsafe_unretained', 'carrier_details.plist', 'network_settings.plist', 'device_ids.plist', 'regenerateAllEnabledIdentifiers]'):
        assert forbidden not in create, forbidden
    network = writers.method(source, METHODS[4])
    for forbidden in ('writeToFile:', 'PXPerformRuntimeSourceWrite', 'saveLocalIPAddress:', 'PXActiveProfile', 'NSInvocation'):
        assert forbidden not in network, forbidden
    assert 'generateSpoofedLocalIPAddressFromCurrent' in network and 'generateSpoofedLocalIPv6AddressFromCurrent' in network
    archive = writers.method(source, METHODS[8])
    assert 'NSDataWritingAtomic' in archive and '@catch' in archive
    assert 'removeItemAtPath:' not in archive and 'temp_profiles.plist' not in source
    assert source.count('decodeObjectOfClasses:PXProfileArchiveClasses()') == 3
    allocation = writers.method(source, '- (NSString *)generateProfileID')
    assert 'if (existingIDs.count == 0) {\n            NSError *error' not in allocation
    manager = read('common/IdentifierManager.m')
    explicit = writers.method(manager, '- (NSString *)existingGenerationIdentityForProfileID:(NSString *)profileID error:(NSError **)error')
    assert 'PXProfileIdentityPath(PXValidatedProfileID(profileID))' in explicit
    assert 'migrateProfileSchemaAtIdentityDirectory:identityDir' in explicit
    assert 'profileIdentityPath]' not in explicit and 'PXActiveProfile' not in explicit
    stage = read('common/PXRuntimeGeneration.m')
    assert 'PXStageRuntimeCarrier(tx, identity, network[@"carrier"]' in stage
    assert 'network[@"ipv6"], YES, now' in stage
    pair = read('common/PXRuntimeProfileSelection.m')
    assert 'setDictionary:info atPath:centralPath' in pair and 'setDictionary:info atPath:legacyPath' in pair
    activation = writers.method(source, '- (BOOL)activateProfile:(Profile *)profile expectedSelection:(NSDictionary *)expected generation:(PXCommittedRuntimeGeneration *)generation error:(NSError **)error')
    assert 'PXStageRuntimeProfileSelectionIfUnchanged' in activation and 'PXRuntimeGenerationMatchesProof' in activation
    assert 'PXStageRuntimeGenerationSettings' in activation
    assert activation.index('if (!committed)') < activation.index('self.mutableCurrentProfile = profile;') < activation.index('mirrorCurrentProfileID:')
    load = writers.method(source, '- (void)loadProfilesWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion')
    assert 'captureProfileSelectionWithError:' in load and 'CurrentProfileID' not in load and 'createDefaultProfile' not in load
    assert 'SelectionRevision' in source and 'selectionUnavailable' in source
    assert 'registryUnavailable' in source
    ui = read('ProfileManagerViewController.m')
    assert ui.count('refreshCurrentProfileFromCommittedSelectionWithError:NULL') == 4
    assert ui.count('updateCurrentProfileInfoWithProfile:profile]') == 2, 'only explicit metadata edits retain the guarded helper'
    metadata = writers.method(source, '- (BOOL)updateCurrentProfileInfoWithProfile:(Profile *)profile error:(NSError **)error')
    assert 'observed isEqualToString:info[@"ProfileId"]' in metadata and 'PXStageRuntimeProfileSelectionIfUnchanged' in metadata
    getter = writers.method(source, '- (Profile *)currentProfile')
    assert 'updateCurrentProfileInfoWithProfile:' not in getter and 'writeToFile:' not in getter
    assert 'PXRuntimeProfileSelectionMatches' in pair and 'exists' in pair
    fixture = read('tests/PXProfileCreationFlowTests.m')
    for case in ('creation waits for generation and completion runs once on main',
                 'creation worker preserves supplied profile after selection drift',
                 'overlapping lifecycle operations reject while creation is pending',
                 'generation failure never publishes profile success',
                 'generation exception releases busy state and reports failure',
                 'metadata failure never unlinks the last archive destination',
                 'selection pair failure preserves files memory and defaults mirror',
                 'background creation is marshalled to main',
                 'directory-only IDs are never reused when archive already has entries',
                 'pending creation preserves active selection settings registry caches and apps',
                 'selection drift ABA and settings changes never clobber newer state',
                 'activation rollback restores selection settings and scope without publication',
                 'restart restores committed selection before stale defaults mirror',
                 'stale startup mirror never overwrites newer activation',
                 'corrupt archive never guesses or rewrites selection'):
        assert case in fixture, case
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2H2-partial'
    assert manifest['writers']['profile-lifecycle']['status'] == 'pending'
    assert manifest['writers']['profile-create-completion']['status'] == 'partial'
    assert 'test_profile_creation_flow.py --native' in read('.github/workflows/build-ios-arm.yml')
    assert 'test_profile_creation_flow.py' in read('scripts/release_hardening.py')
    print('PASS: Profile creation completion and fixed-target source contracts (activation/directory lifecycle partial; native runtime not implied)')


def generate_native_fragments(folder):
    source = read('common/ProfileManager.m')
    methods = [writers.method(source, signature) for signature in METHODS]
    (folder / 'PXProfileFlowMethods.inc').write_text('\n\n'.join(methods), encoding='utf-8')
    (folder / 'PXProfileFlowDeclarations.inc').write_text('\n'.join(m.split(' {', 1)[0] + ';' for m in methods), encoding='utf-8')
    start = source.index('@implementation Profile\n')
    end = source.index('\n@end', start) + len('\n@end')
    helper = writers.method(source, 'static NSSet<Class> *PXProfileArchiveClasses(void)')
    (folder / 'PXProfileModel.inc').write_text(helper + '\n' + source[start:end], encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-profile-flow-') as temp:
        folder = Path(temp)
        generate_native_fragments(folder)
        sources = ['common/PXRuntimeProfileSelection.m', 'common/PXRuntimeSourceStore.m', 'common/PXRuntimePublisher.m',
                   'common/PXRuntimeGeneration.m', 'common/PXRuntimeArtifactWriter.m', 'common/PXRuntimeIdentifierWriter.m',
                   'tests/PXProfileCreationFlowTests.m']
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            binary = folder / scheme
            subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions',
                '-DPX_SOURCE_TRANSACTION_TESTING=1', '-Wall', '-Wextra', '-Werror=implicit-function-declaration',
                '-I', str(ROOT / 'common'), '-I', str(folder), *defines, *[str(ROOT / s) for s in sources],
                '-framework', 'Foundation', '-o', str(binary)], cwd=ROOT, check=True, timeout=90)
            for _ in range(3):
                subprocess.run([str(binary)], cwd=ROOT, check=True, timeout=90)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        native_tests()
