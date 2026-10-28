#!/usr/bin/env python3
"""Profile creation, conditional activation and exclusive directory reservation."""
from pathlib import Path
import argparse
import importlib.util
import json
import re
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
METHODS += ['- (BOOL)beginProfileOperationWithError:(NSError **)error', '- (void)endProfileOperation',
    '- (void)loadProfilesUnderLeaseWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion',
    '- (BOOL)deleteRegisteredProfileID:(NSString *)targetID selectionChanged:(BOOL *)selectionChanged error:(NSError **)error',
    '- (BOOL)updateProfileUnderLease:(Profile *)profile index:(NSUInteger)index error:(NSError **)error']
METHODS += ['- (NSArray<Profile *> *)decodeRegistryRecord:(NSDictionary *)record error:(NSError **)error',
            '- (BOOL)validateDeletionArchives:(NSDictionary *)intent error:(NSError **)error']


def check_macro_arity(source, label):
    """C macro argument splitting recognizes parentheses, not ObjC [] or {}."""
    # Preserve offsets so diagnostics point at the original source. Strings,
    # character constants and comments cannot contribute delimiter tokens.
    masked = re.sub(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'',
                    lambda match: ' ' * len(match.group()), source)
    for invocation in re.finditer(r'\bCHECK\s*\(', masked):
        line_start = source.rfind('\n', 0, invocation.start()) + 1
        if re.match(r'\s*#\s*define\b', source[line_start:invocation.start()]):
            continue
        depth, arguments = 1, 1
        for token in masked[invocation.end():]:
            if token == '(':
                depth += 1
            elif token == ')':
                depth -= 1
                if depth == 0:
                    break
            elif token == ',' and depth == 1:
                arguments += 1
        line = source.count('\n', 0, invocation.start()) + 1
        assert depth == 0 and arguments == 2, f'{label}:{line}: CHECK needs 2 macro arguments, found {arguments}; move ObjC literals/blocks to a local or parenthesize the expression'


def source_contracts():
    # Exercise the regression checker against the exact failure category, not
    # only the corrected fixture: braced literals do not protect their commas.
    broken = 'CHECK([tx write:@{ @"first": @1, @"second": @2 }], "literal");'
    try:
        check_macro_arity(broken, 'unprotected-literal')
    except AssertionError:
        pass
    else:
        raise AssertionError('macro checker missed an unprotected dictionary comma')
    check_macro_arity('CHECK(([tx write:@{ @"first": @1, @"second": @2 }]), "literal, message()");', 'protected-literal')
    check_macro_arity('/* CHECK(not, an, invocation) */ CHECK(ok && (a, b), "escaped \\\"quote");', 'comments-and-strings')
    for path in ('tests/PXProfileCreationFlowTests.m', 'tests/PXRuntimeDeviceGroupWriterTests.m', 'tests/PXRuntimeArtifactWriterTests.m', 'tests/PXRuntimeArtifactPreparationTests.m', 'tests/PXRuntimeIdentifierWriterTests.m', 'tests/PXRuntimeSecurityWriterTests.m', 'tests/PXIPMonitorLifecycleTests.m', 'tests/PXPinnedTimeZoneLifecycleTests.m', 'tests/PXPinnedCountryLifecycleTests.m'):
        check_macro_arity(read(path), path)
    source = read('common/ProfileManager.m')
    create = writers.method(source, CREATE)
    assert 'reserveProfileID:profile.profileId' in create and 'self.creationReservation = reservation;' in create
    assert 'createDirectoryIfNeeded:' not in create and 'writeToFile:' not in create
    assert create.count('[reservation validateWithError:&generationError]') == 2
    for signature in METHODS[:4]:
        body = writers.method(source, signature)
        assert 'if (!NSThread.isMainThread)' in body and 'if (self.creationInProgress)' in body
    finish = writers.method(source, '- (void)finishProfileCreation:(Profile *)profile targetID:(NSString *)targetID generation:(PXCommittedRuntimeGeneration *)generation expectedSelection:(NSDictionary *)expected error:(NSError *)generationError completion:(void (^)(BOOL success, NSError * _Nullable error))completion')
    assert create.index('targetID = [profile.profileId copy]') < create.index('dispatch_get_global_queue')
    assert 'commitRuntimeGenerationForProfileID:targetID' in create
    assert 'networkArtifacts:network lifecycleLease:generationLease error:' in create
    assert create.index('generationLease = self.lifecycleLease') < create.index('dispatch_get_global_queue')
    for forbidden in ('terminateEnabledScopedApps', 'mutableCurrentProfile =', 'mutableProfiles addObject:', 'updateCurrentProfileInfoWithProfile:'):
        assert forbidden not in create, forbidden
    assert finish.index('validateActivationForProfile:') < finish.index('mutableProfiles addObject:') < finish.index('saveProfilesWithCompletion:')
    assert finish.index('saveProfilesWithCompletion:') < finish.index('activateProfile:') < finish.index('publishCommittedRuntimeGeneration:')
    assert 'removeObjectIdenticalTo:profile' in finish
    assert finish.count('[self endProfileOperation];') == 3
    assert finish.index('[self endProfileOperation];', finish.index('activateProfile:')) < finish.index('if (completion) completion(activated,')
    for forbidden in ('NSInvocation', '__unsafe_unretained', 'carrier_details.plist', 'network_settings.plist', 'device_ids.plist', 'regenerateAllEnabledIdentifiers]'):
        assert forbidden not in create, forbidden
    network = writers.method(source, METHODS[4])
    for forbidden in ('writeToFile:', 'PXPerformRuntimeSourceWrite', 'saveLocalIPAddress:', 'PXActiveProfile', 'NSInvocation'):
        assert forbidden not in network, forbidden
    assert 'generateSpoofedLocalIPAddressFromCurrent' in network and 'generateSpoofedLocalIPv6AddressFromCurrent' in network
    archive = writers.method(source, METHODS[8])
    assert 'writeRegistryData:data expected:self.registryRecord' in archive and '@catch' in archive
    assert 'removeItemAtPath:' not in archive and 'temp_profiles.plist' not in source
    assert source.count('decodeObjectOfClasses:PXProfileArchiveClasses()') == 3
    coding = writers.method(source, '- (instancetype)initWithCoder:(NSCoder *)coder')
    for key in ('shortDescription', 'createdAt', 'lastUsed', 'settings'):
        assert f'[coder containsValueForKey:@"{key}"] ? [coder decodeObjectOfClass' in coding, f'optional {key} must not request an absent key'
    assert '_profileId = [coder decodeObjectOfClass:[NSString class] forKey:@"profileId"];' in coding
    assert '[coder failWithError:' in coding and 'failure = failure ?: decoder.error;' in source

    allocation = writers.method(source, '- (NSString *)generateProfileID')
    assert 'if (existingIDs.count == 0) {\n            NSError *error' not in allocation
    manager = read('common/IdentifierManager.m')
    explicit = writers.method(manager, '- (NSString *)existingGenerationIdentityForProfileID:(NSString *)profileID lifecycleLease:(PXProfileLifecycleLease *)lease error:(NSError **)error')
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
    assert '[self.creationReservation validateWithError:writeError]' in activation
    assert activation.index('if (!committed)') < activation.index('self.mutableCurrentProfile = profile;') < activation.index('mirrorCurrentProfileID:')
    reload_entry = writers.method(source, '- (void)loadProfilesWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion')
    assert 'if (self.creationInProgress)' in reload_entry and '@finally { [self endProfileOperation]; }' in reload_entry
    load = writers.method(source, '- (void)loadProfilesUnderLeaseWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion')
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
    assert 'creation did not retain lifecycle ownership on worker' in fixture
    assert 'generation invalidated caller lease' in fixture
    assert 'gMemoryID' not in fixture, 'mirror-time sample must not masquerade as live manager memory'
    assert 'NSString *memoryID = gNotifyingManager.mutableCurrentProfile.profileId;' in fixture
    assert 'BOOL ordered = ProfileNoticeHasCommittedMemory(gNotifyingManager);' in fixture
    assert '@try { [super publishProfileChangedNotification]; }' in fixture
    assert '@finally { gNotifyingManager = previous; }' in fixture
    assert '[PXProfileCreationFixture new]' not in fixture, 'notification producers must use the observed fixture factory'
    for case in ('legacy reload adopts committed memory while the defaults mirror is still queued',
                 'notification oracle rejects stale producer memory and accepts committed memory independently of mirror samples',
                 'inactive deletion notifies committed producer memory before deferred defaults mirroring',
                 'queued defaults mirror eventually adopts the committed profile after inactive deletion'):
        assert case in fixture, case
    assert 'PXLegacyDatesArchiverFixture' not in fixture, 'legacy fixture must use a standard archiver envelope'
    assert '- (Class)classForKeyedArchiver { return Profile.class; }' in fixture
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
    reservation = read('common/PXProfileCreationReservation.m')
    for token in ('mkdirat(', 'O_EXCL', 'O_NOFOLLOW', 'O_CLOEXEC', 'AT_SYMLINK_NOFOLLOW',
                  'st_ino', 'st_dev', 'st_nlink != 1', 'pread(', 'EINTR', 'dealloc',
                  '.creation-owner.plist', 'operationID', '@"state": @"reserved"'):
        assert token in reservation, token
    for forbidden in ('removeItemAtPath:', 'unlink(', 'rmdir(', 'dispatch_', 'PXPerformRuntimeSourceWrite'):
        assert forbidden not in reservation, forbidden
    for fd in ('_rootFD', '_profileFD', '_identityFD', '_markerFD'):
        assert f'if ({fd} >= 0) close({fd});' in reservation
    for case in ('exactly one process exclusively reserves the same profile ID',
                 'exited creator leaves an untouched reservation and restart cannot adopt it',
                 'success and failure reservations close every held descriptor',
                 'directory proof rejects replacement symlink and in-place marker mutation',
                 'configured root aliases remain supported',
                 'replaced creation directory never activates or publishes success',
                 'directory change in termination adapter is rechecked before activation'):
        assert case in fixture, case
    lease = read('common/PXProfileLifecycleLease.m')
    for token in ('LOCK_EX | LOCK_NB', 'O_CLOEXEC | O_NOFOLLOW', 'st_uid != geteuid()',
                  'AT_SYMLINK_NOFOLLOW', 'NSDataWritingAtomic', 'observed isEqual:expected', 'dealloc'):
        assert token in lease, token
    begin = writers.method(source, '- (BOOL)beginProfileOperationWithError:(NSError **)error')
    assert 'expected isEqual:observed' in begin and 'self.lifecycleLease = lease;' in begin
    assert '[self.lifecycleLease invalidate];' in writers.method(source, '- (void)endProfileOperation')
    assert 'NS_RETURNS_RETAINED' in read('common/PXProfileLifecycleLease.h')
    for signature in METHODS[:4]:
        assert 'beginProfileOperationWithError:' in writers.method(source, signature)
    delete = writers.method(source, '- (BOOL)deleteRegisteredProfileID:(NSString *)targetID selectionChanged:(BOOL *)selectionChanged error:(NSError **)error')
    assert delete.index('PXPrepareProfileDeletion(') < delete.index('PXCommitProfileDeletion(') < delete.index('writeRegistryData:afterBytes') < delete.index('removeDirectoryForProfileID:')
    assert 'PXMarkProfileDeletionArchiveWritten(' in delete and 'PXRecoverProfileDeletion(' in delete
    for signature in ('- (BOOL)bootstrapProfileSelectionWithError:(NSError **)error',
                      '- (BOOL)persistProfileSelectionInfo:(NSDictionary *)info error:(NSError **)error',
                      '- (BOOL)updateCurrentProfileInfoWithProfile:(Profile *)profile error:(NSError **)error'):
        assert 'objc_precise_lifetime' in writers.method(source, signature)
    for case in ('pending create excludes other instances reload and raw selection writers',
                 'synchronous preparation exception releases lifecycle ownership before failure completion',
                 'lifecycle lease excludes another process without waiting',
                 'registry CAS rejects stale bytes without overwriting the newer archive',
                 'exited process releases lifecycle ownership',
                 'stale manager cannot overwrite a registry changed by another instance',
                 'active deletion uses committed selection and persists a valid fallback before removing files',
                 'delete selection failure preserves registry and directory',
                 'archive preparation failure preserves selection registry and directory',
                 'selection drift after unregister restores only our own registry and preserves all files',
                 'registry drift after unregister preserves files and never overwrites an external archive',
                 'cleanup refuses a replaced target and restart preserves the committed registry',
                 'restart never adopts an inactive directory from a reserved marker alone',
                 'duplicate registry IDs reject load without guessing or rewriting the archive'):
        assert case in fixture, case
    journal = read('common/PXProfileDeletionJournal.m')
    for token in ('@"prepared"', '@"committed"', '@"archived"', '@"compensating"',
                  'PXStageRuntimeProfileSelection(tx', 'PXProfileDeletionJournalPath()',
                  'Unknown registry during deletion recovery', 'PXClearDeletionIntent'):
        assert token in journal, token
    for forbidden in ('removeDirectoryForProfileID:', 'removeItemAtPath:', 'dispatch_', 'PXPostSettingsChangedNotification()'):
        assert forbidden not in journal, forbidden
    assert 'PXProfileDeletionJournalPath()' in read('common/PXRuntimeSources.m')
    assert load.index('PXRecoverProfileDeletion(') < load.index('captureProfileSelectionWithError:')
    assert activation.count('Profile registry changed before activation') == 1
    assert fixture.count('Profile *registryDrift = SeedRegistered') == 1
    for case in ('absent optional timestamps and description never poison decoder or discard later settings',
                 'absent legacy settings uses the existing empty dictionary fallback without decoding a missing key',
                 'explicit nil timestamps preserve the existing date fallback',
                 'present invalid timestamp still fails validation instead of using a missing-key fallback',
                 'required profile ID remains a required decode request',
                 'prepared intent aborts on restart without changing selection registry or files',
                 'committed deletion replays known archive and preserves the committed fallback',
                 'recovery is idempotent and never retries recursive directory removal',
                 'compensating decision survives restart and never rolls back a newer selection',
                 'malformed deletion intent never rewrites selection archive or directory',
                 'unknown registry blocks replay and preserves the deletion journal',
                 'journal validation preserves legacy timestamp fallback compatibility'):
        assert case in fixture, case
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2H3T-partial'
    assert manifest['writers']['profile-lifecycle']['status'] == 'partial'
    assert manifest['writers']['profile-create-completion']['status'] == 'partial'
    assert 'test_profile_creation_flow.py --native' in read('.github/workflows/build-ios-arm.yml')
    assert 'test_profile_creation_flow.py' in read('scripts/release_hardening.py')
    print('PASS: Profile creation completion and fixed-target source contracts (activation/directory lifecycle partial; native runtime not implied)')


def generate_native_fragments(folder):
    source = read('common/ProfileManager.m')
    methods = [writers.method(source, signature) for signature in METHODS]
    (folder / 'PXProfileFlowMethods.inc').write_text('\n\n'.join(methods), encoding='utf-8')
    (folder / 'PXProfileFlowDeclarations.inc').write_text('\n'.join(m.split(' {', 1)[0] + ';' for m in methods), encoding='utf-8')
    start = source.index('@interface Profile ()\n')
    implementation = source.index('@implementation Profile\n', start)
    end = source.index('\n@end', implementation) + len('\n@end')
    helper = writers.method(source, 'static NSSet<Class> *PXProfileArchiveClasses(void)')
    (folder / 'PXProfileModel.inc').write_text(helper + '\n' + source[start:end], encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-profile-flow-') as temp:
        folder = Path(temp)
        generate_native_fragments(folder)
        sources = ['common/PXProfileDeletionJournal.m', 'common/PXProfileLifecycleLease.m', 'common/PXProfileCreationReservation.m', 'common/PXRuntimeProfileSelection.m', 'common/PXRuntimeSourceStore.m', 'common/PXRuntimePublisher.m',
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
