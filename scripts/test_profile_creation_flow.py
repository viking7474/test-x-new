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
    '- (void)createProfileZeroImmediately', '- (void)createProfileZero', '- (BOOL)createProfileZeroWithError:(NSError **)error',
    '- (BOOL)refreshCurrentProfileFromCommittedSelectionWithError:(NSError **)error']
METHODS += ['- (BOOL)beginProfileOperationWithError:(NSError **)error', '- (void)endProfileOperation',
    '- (void)loadProfilesUnderLeaseWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion',
    '- (BOOL)deleteRegisteredProfileID:(NSString *)targetID selectionChanged:(BOOL *)selectionChanged error:(NSError **)error',
    '- (BOOL)updateProfileUnderLease:(Profile *)profile index:(NSUInteger)index error:(NSError **)error']
METHODS += ['- (NSArray<Profile *> *)decodeRegistryRecord:(NSDictionary *)record error:(NSError **)error',
            '- (NSDictionary *)preparedRegistryRecordForProfiles:(NSArray<Profile *> *)profiles error:(NSError **)error',
            '- (BOOL)validateDeletionArchives:(NSDictionary *)intent error:(NSError **)error',
            '- (BOOL)registryValue:(id)before matchesValue:(id)after seen:(NSMapTable *)seen',
            '- (BOOL)registryValue:(id)before matchesValue:(id)after seen:(NSMapTable *)seen allowLegacyDates:(BOOL)allowLegacyDates',
            '- (BOOL)activationProfile:(Profile *)profile matchesRegistry:(NSDictionary *)record error:(NSError **)error',
            '- (Profile *)detachedProfileForCreation:(Profile *)profile expectedID:(NSString *)expectedID error:(NSError **)error']
EDIT = '- (void)editProfileID:(NSString *)profileID name:(NSString *)name shortDescription:(NSString *)shortDescription completion:(void (^)(BOOL success, NSError * _Nullable error))completion'
METHODS += [EDIT, '- (void)renameProfile:(NSString *)oldName to:(NSString *)newName']
DELETE_ID = '- (void)deleteProfileID:(NSString *)profileID requireInactive:(BOOL)requireInactive completion:(void (^)(BOOL success, NSError * _Nullable error))completion'
DELETE_CORE = '- (BOOL)deleteRegisteredProfileID:(NSString *)targetID requireInactive:(BOOL)requireInactive selectionChanged:(BOOL *)selectionChanged error:(NSError **)error'
METHODS += ['- (NSArray<Profile *> *)profiles', DELETE_ID, DELETE_CORE,
            '- (void)deleteInactiveProfileID:(NSString *)profileID completion:(void (^)(BOOL success, NSError * _Nullable error))completion',
            '- (void)deleteInactiveProfilesWithCompletion:(void (^)(NSDictionary *result))completion',
            '- (void)deleteInactiveProfileIDs:(NSArray<NSString *> *)profileIDs index:(NSUInteger)index result:(NSMutableDictionary *)result completion:(void (^)(NSDictionary *result))completion']
METHODS += ['- (NSString *)generateProfileIDWithError:(NSError **)error',
            '- (NSUInteger)allocationOrdinalForID:(NSString *)profileID',
            '- (NSString *)nextProfileIDForExistingIDs:(NSSet<NSString *> *)existing occupied:(NSSet<NSString *> *)occupied error:(NSError **)error',
            '- (NSString *)nextProfileIDForExistingIDs:(NSSet<NSString *> *)existing occupied:(NSSet<NSString *> *)occupied probe:(BOOL (^)(NSString *, BOOL *, NSError **))probe error:(NSError **)error']
METHODS += ['- (BOOL)validateCurrentProfileID:(NSString *)profileID error:(NSError **)error']
UI_ADAPTERS = {
    'PXFakePreviewUI.inc': ('TLinkIOSViewController.m', [
        '- (NSDictionary *)generateFakePreviewFromOptions:(NSDictionary *)options',
        '- (NSDictionary *)generateFakePreviewFromOptions:(NSDictionary *)options currentDeviceIDs:(NSDictionary *)currentDeviceIDs']),
    'PXDeviceCreateUI.inc': ('DeviceSpecificSpoofingViewController.m', ['- (void)createDeviceProfileWithName:(NSString *)name shortDescription:(NSString *)shortDescription']),
    'PXManualCreateUI.inc': ('TLinkIOSViewController.m', ['- (void)submitManualProfileName:(NSString *)name shortDescription:(NSString *)shortDescription']),
    'PXFormCreateUI.inc': ('ProfileCreationViewController.m', ['- (void)createButtonTapped', '- (void)cancelButtonTapped', '- (void)textFieldDidChangeSelection:(UITextField *)textField']),
    'PXResetPreparationUI.inc': ('TLinkIOSViewController.m', [
        '- (BOOL)ensureDashboardFakeOptionsEnableRequiredIdentifiers:(NSDictionary *)options error:(NSError **)error',
        '- (BOOL)prepareResetProfileWithOptions:(NSDictionary *)options preview:(NSDictionary *)preview error:(NSError **)error',
        '- (NSDictionary *)captureResetIntentWithOptions:(NSDictionary *)options preview:(NSDictionary *)preview error:(NSError **)error',
        '- (BOOL)discardConsumedResetPreviewForIntent:(NSDictionary *)intent',
        '- (BOOL)prepareResetProfileWithOptions:(NSDictionary *)options preview:(NSDictionary *)preview expectedProfileID:(NSString *)profileID error:(NSError **)error',
        '- (BOOL)validateDashboardResetProfileID:(NSString *)profileID error:(NSError **)error',
        '- (BOOL)ensureDashboardFakeOptionsEnableRequiredIdentifiers:(NSDictionary *)options expectedProfileID:(NSString *)profileID error:(NSError **)error']),
    'PXResetWorkflowUI.inc': ('TLinkIOSViewController.m', [
        '- (NSObject *)beginDashboardResetInPhase:(NSString *)phase',
        '- (BOOL)advanceDashboardReset:(NSObject *)token fromPhase:(NSString *)phase toPhase:(NSString *)nextPhase',
        '- (BOOL)finishDashboardReset:(NSObject *)token',
        '- (void)saveRRSThenResetTapped', '- (void)resetDataTapped',
        '- (void)performResetAndPrepareNextProfileWithWarnings:(NSArray<NSString *> *)warnings',
        '- (void)createNextProfileAndRandomizeWithWarnings:(NSArray<NSString *> *)warnings']),
    'PXResetBatchUI.inc': ('TLinkIOSViewController.m', [
        '- (BOOL)isDashboardReset:(NSObject *)token inPhase:(NSString *)phase',
        '- (void)backupApps:(NSArray<NSString *> *)apps index:(NSUInteger)index savedCount:(NSUInteger)savedCount warnings:(NSMutableArray<NSString *> *)warnings completion:(void (^)(NSArray<NSString *> *warnings, NSUInteger savedCount))completion',
        '- (void)backupApps:(NSArray<NSString *> *)apps index:(NSUInteger)index savedCount:(NSUInteger)savedCount warnings:(NSMutableArray<NSString *> *)warnings resetToken:(NSObject *)resetToken completion:(void (^)(NSArray<NSString *> *warnings, NSUInteger savedCount))completion',
        '- (void)clearApps:(NSArray<NSString *> *)apps index:(NSUInteger)index warnings:(NSMutableArray<NSString *> *)warnings completion:(void (^)(NSArray<NSString *> *warnings))completion',
        '- (void)clearApps:(NSArray<NSString *> *)apps index:(NSUInteger)index warnings:(NSMutableArray<NSString *> *)warnings resetToken:(NSObject *)resetToken completion:(void (^)(NSArray<NSString *> *warnings))completion']),
    'PXResetInputsUI.inc': ('TLinkIOSViewController.m', [
        '- (NSArray<NSString *> *)captureDashboardAppIDs:(NSArray<NSString *> *)apps error:(NSError **)error',
        '- (NSDictionary *)captureDashboardResetInputsForBackup:(BOOL)backup error:(NSError **)error']),
}


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
    for path in ('tests/PXProfileCreationFlowTests.m', 'tests/PXRuntimeDeviceGroupWriterTests.m', 'tests/PXRuntimeArtifactWriterTests.m', 'tests/PXRuntimeArtifactPreparationTests.m', 'tests/PXRuntimeIdentifierWriterTests.m', 'tests/PXRuntimeSecurityWriterTests.m', 'tests/PXIPMonitorLifecycleTests.m', 'tests/PXPinnedTimeZoneLifecycleTests.m', 'tests/PXPinnedCountryLifecycleTests.m', 'tests/PXIPDisplayLifecycleTests.m', 'tests/PXTargetRegionLifecycleTests.m'):
        check_macro_arity(read(path), path)
    source = read('common/ProfileManager.m')
    seed_owner = writers.method(source, '- (BOOL)createProfileZeroWithError:(NSError **)error')
    immediate_seed = writers.method(source, '- (void)createProfileZeroImmediately')
    explicit_seed = writers.method(source, '- (void)createProfileZero')
    assert 'acquireInDirectory:self.profilesDirectory' in seed_owner and 'PXSeedDefaultProfile(lease, error)' in seed_owner
    assert '@finally { [lease invalidate]; }' in seed_owner
    assert seed_owner.index('if (!PXSeedDefaultProfile') < seed_owner.index('seed committed')
    assert 'createProfileZeroWithError:&error' in immediate_seed and 'writeToFile:' not in immediate_seed
    assert explicit_seed.index('if (![self createProfileZeroWithError:') < explicit_seed.index('bootstrapProfileSelectionWithError:')
    seed = read('common/PXDefaultProfileSeed.m')
    assert 'validateForDirectory:PXProfilesPath()' in seed and 'PXRequireNoPendingProfileDeletion' in seed
    assert 'directoryProofForProfileID:@"0"' in seed and 'mkdirat(rootFD, "0", 0755)' in seed
    assert 'openat(rootFD, "0"' in seed and 'openat(profileFD, "identity"' in seed and 'AT_SYMLINK_NOFOLLOW' in seed
    assert 'PXPerformStandaloneRuntimeSourceWrite' in seed and '[scope performSourceWrite:' in seed
    assert 'dictionaryAtPath:idsPath exists:&exists' in seed and '(exists || [staging setDictionary:@{}' in seed
    assert 'PXDefaultSeedDirectoryMatches(profileFD' in seed and 'PXDefaultSeedDirectoryMatches(identityFD' in seed
    assert 'if (committed)' in seed and '@0644' in seed and 'close(identityFD)' in seed and 'close(profileFD)' in seed and 'close(rootFD)' in seed
    for forbidden in ('PXActiveProfileID', 'createDirectoryAtPath:', 'mutableProfiles', 'PostNotification', 'dispatch_'):
        assert forbidden not in seed, forbidden
    fixture = read('tests/PXProfileCreationFlowTests.m')
    assert '#import "PXDefaultProfileSeed.h"' in source and '#import "PXDefaultProfileSeed.h"' in fixture
    seed_capture = fixture[fixture.index('static NSDictionary *PXCaptureDefaultSeedFixture('):fixture.index('@interface PXDefaultSeedControlFixture')]
    assert 'NSNull' not in seed_capture and '@"exists": @(exists)' in seed_capture and '@"bytes": bytes' in seed_capture
    for case in ('default seed commits display while preserving existing identity bytes',
                 'default seed absence oracle is plist-safe and nonnil',
                 'default seed failure after each file restores paired original absence',
                 'default seed creates empty identity only when missing',
                 'default seed rejects corrupt display or identity without partial repair',
                 'busy default seed rejects before namespace or source effects and releases failed acquire descriptors',
                 'default seed borrowed lifecycle remains owned and closes every helper descriptor',
                 'default seed pending deletion rejects before changing either source file',
                 'explicit default create stops before bootstrap or reload when seed fails',
                 'default seed rejects identity symlink without changing its target',
                 'default seed rejects profile symlink without changing its target',
                 'default seed creates only legacy directories and source files for missing zero',
                 'default seed leaves manager slots unchanged and closes descriptors on every tested return'):
        assert case in fixture, case
    update = writers.method(source, '- (BOOL)updateProfileUnderLease:(Profile *)profile index:(NSUInteger)index error:(NSError **)error')
    assert 'writeToFile:' not in update and 'createDirectoryIfNeeded:' not in update and 'saveProfilesWithCompletion:' not in update
    assert update.index('preparedRegistryRecordForProfiles:candidate') < update.index('PXWriteProfileDisplayMetadata(') < update.index('writeRegistryData:archive') < update.index('self.mutableProfiles = candidate')
    assert 'if (!record) return NO;' in update and 'NSData *archive = record[@"bytes"]' in update
    assert 'expected:self.registryRecord' in update and 'self.registryRecord =' in update
    assert '#import "PXProfileMetadataWriter.h"' in source
    fixture = read('tests/PXProfileCreationFlowTests.m')
    capture_start = fixture.index('static NSDictionary *PXCaptureMetadataFixture(')
    capture_end = fixture.index('static NSUInteger PXMetadataFixtureDescriptorCount(', capture_start)
    metadata_capture = fixture[capture_start:capture_end]
    assert 'NSNull.null' not in metadata_capture and 'error:&captureError' in metadata_capture
    assert '@"exists": @(exists)' in metadata_capture and '@"bytes": bytes' in metadata_capture
    assert 'if (!bytes) return nil;' in metadata_capture
    assert 'metadata absence snapshot is nonnil plist-safe and preserves file presence separately from bytes' in fixture
    assert 'metadata snapshot distinguishes empty file from absence' in fixture
    assert 'writes == failAfter' in fixture and 'Metadata rollback: fault=' in fixture
    assert '#import "PXProfileMetadataWriter.h"' in fixture and 'PXPerformStandaloneRuntimeSourceWrite(' in fixture
    metadata = read('common/PXProfileMetadataWriter.m')
    assert 'borrowWithLifecycleLease:lease profileID:targetID' in metadata
    assert 'PXPerformStandaloneRuntimeSourceWrite' in metadata and '[scope performSourceWrite:' in metadata
    assert metadata.count('[staging setDictionary:') == 4 and 'dictionaryAtPath:scopedPath' in metadata
    assert 'if (!existing) return NO;' in metadata and 'if (!scoped[@"Apps"])' in metadata
    assert 'mkdirat(rootFD, "appdata", 0755)' in metadata and 'openat(rootFD, "appdata"' in metadata
    assert 'O_NOFOLLOW' in metadata and 'held.st_ino != current.st_ino' in metadata
    assert '@finally' in metadata and 'close(appDataFD)' in metadata and 'close(rootFD)' in metadata and '[scope invalidate]' in metadata
    for case in ('metadata fault after each file rolls back bytes and absence before registry memory or notification',
                 'metadata update commits all display files once before registry adoption and preserves scoped extras and selection',
                 'registry failure after metadata commit reports partial failure without memory adoption or success notification',
                 'corrupt scoped metadata rejects entire edit without silent repair',
                 'metadata registry encoding failure stops before any display file write',
                 'metadata writer rejects appdata symlink without writing its target or registry',
                 'metadata borrowed root supports legacy profile without creating identity or releasing parent lease',
                 'metadata high-level writer cannot acknowledge an uncommitted outer transaction',
                 'metadata writer rejects expired caller lease'):
        assert case in fixture, case
    create = writers.method(source, CREATE)
    assert 'reserveProfileID:creationProfile.profileId' in create and 'self.creationReservation = reservation;' in create
    assert 'createDirectoryIfNeeded:' not in create and 'writeToFile:' not in create
    assert create.count('[reservation validateWithError:&generationError]') == 2
    detach = writers.method(source, '- (Profile *)detachedProfileForCreation:(Profile *)profile expectedID:(NSString *)expectedID error:(NSError **)error')
    assert 'requiringSecureCoding:YES' in detach and 'decoder.requiresSecureCoding = YES' in detach
    assert 'decodeObjectOfClasses:PXProfileArchiveClasses()' in detach and 'decoder.error' in detach and 'decoded != profile' in detach
    assert '[[decoded profileId] isEqual:expectedID]' in detach and '@catch' in detach
    assert create.index('detachedProfileForCreation:profile') < create.index('reserveProfileID:creationProfile.profileId')
    assert 'finishProfileCreation:creationProfile' in create and 'finishProfileCreation:profile ' not in create
    worker = create[create.index('dispatch_async(dispatch_get_global_queue'):]
    assert 'profile.' not in worker
    switch = writers.method(source, SWITCH)
    assert 'profile = registeredProfile;' in switch and 'PXValidatedProfileID(rawID)' in switch
    assert switch.index('profile = registeredProfile;') < switch.index('profile.lastUsed = NSDate.date')
    for case in ('owned creation completes once despite later caller model mutation',
                 'creation owns a deep secure snapshot including nested mutable settings and allowed Profile values',
                 'creation display registry selection and generation agree without overwriting later caller edits',
                 'switch resolves registered model by ID and persists canonical lastUsed without adopting alias fields',
                 'unregistered switch alias has no persistence effects',
                 'queued creation does not retain the caller input model',
                 'owned creation survives caller model deallocation',
                 'failed creation capture releases ownership before completion',
                 'uncapturable creation input fails before reservation providers registry or publication'):
        assert case in fixture, case
    for signature in METHODS[:3] + [DELETE_ID]:
        body = writers.method(source, signature)
        assert 'if (!NSThread.isMainThread)' in body and 'if (self.creationInProgress)' in body
    finish = writers.method(source, '- (void)finishProfileCreation:(Profile *)profile targetID:(NSString *)targetID generation:(PXCommittedRuntimeGeneration *)generation expectedSelection:(NSDictionary *)expected error:(NSError *)generationError completion:(void (^)(BOOL success, NSError * _Nullable error))completion')
    assert create.index('targetID = [creationProfile.profileId copy]') < create.index('dispatch_get_global_queue')
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
    assert 'preparedRegistryRecordForProfiles:self.mutableProfiles' in archive and '@catch' in archive
    assert 'success = record && [self.lifecycleLease writeRegistryData:record[@"bytes"] expected:self.registryRecord' in archive
    preparation = writers.method(source, '- (NSDictionary *)preparedRegistryRecordForProfiles:(NSArray<Profile *> *)profiles error:(NSError **)error')
    assert preparation.index('archivedDataWithRootObject:profiles') < preparation.index('decodeRegistryRecord:record error:&failure')
    assert '@"bytes": data' in preparation and 'return readable ? record : nil' in preparation
    assert '@autoreleasepool' in preparation and 'if (!readable && error) *error = failure' in preparation
    for forbidden in ('writeToFile:', 'writeRegistryData:', 'PXWriteProfileDisplayMetadata(', 'mutableProfiles =', 'publishProfileChangedNotification'):
        assert forbidden not in preparation, forbidden
    for case in ('registry preflight rejects securely encodable records that the reader cannot load',
                 'rejected registry save preserves acknowledged bytes receipt and publication state',
                 'invalid edit archive fails before display writes registry adoption or notification',
                 'registry preflight preserves optional field and legacy timestamp fallbacks',
                 'valid edit still saves exact validated bytes and keeps legal nested Profile values'):
        assert case in fixture, case
    assert 'removeItemAtPath:' not in archive and 'temp_profiles.plist' not in source
    assert source.count('decodeObjectOfClasses:PXProfileArchiveClasses()') == 3, 'ID allocation must reuse the registry decoder'
    coding = writers.method(source, '- (instancetype)initWithCoder:(NSCoder *)coder')
    for key in ('shortDescription', 'createdAt', 'lastUsed', 'settings'):
        assert f'[coder containsValueForKey:@"{key}"] ? [coder decodeObjectOfClass' in coding, f'optional {key} must not request an absent key'
    assert '_profileId = [coder decodeObjectOfClass:[NSString class] forKey:@"profileId"];' in coding
    assert '[coder failWithError:' in coding and 'failure = failure ?: decoder.error;' in source

    allocation = writers.method(source, '- (NSString *)generateProfileID')
    assert 'generateProfileIDWithError:&error' in allocation and 'return @"1"' not in allocation
    verified_allocation = writers.method(source, '- (NSString *)generateProfileIDWithError:(NSError **)error')
    assert 'self.lifecycleLease ?:' in verified_allocation and 'allocationInventoryWithError:error' in verified_allocation
    assert 'validateForDirectory:PXProfilesPath()' in verified_allocation and 'PXRequireNoPendingProfileDeletion' in verified_allocation
    assert 'decodeRegistryRecord:registry' in verified_allocation and 'self.registryRecord isEqual:registry' in verified_allocation
    assert 'profileLeafExistsForID:candidate exists:exists error:probeError' in verified_allocation and 'return nil;' in verified_allocation
    assert 'generateProfileIDWithError:&preparationError' in create and 'if (profileID)' in create
    assert create.index('if (profileID)') < create.index('[profile setValue:profileID') < create.index('reserveProfileID:')
    ordering = writers.method(source, '- (NSString *)nextProfileIDForExistingIDs:(NSSet<NSString *> *)existing occupied:(NSSet<NSString *> *)occupied probe:(BOOL (^)(NSString *, BOOL *, NSError **))probe error:(NSError **)error')
    for forbidden in ('sortedArray', 'intValue', 'contentsOfDirectoryAtPath:', 'writeToFile:'):
        assert forbidden not in ordering, forbidden
    assert '26 * 99' in ordering and 'code:33' in ordering and 'occupied containsObject:candidate' in ordering
    lease_inventory = writers.method(read('common/PXProfileLifecycleLease.m'), '- (NSDictionary *)allocationInventoryWithError:(NSError **)error')
    for token in ('openat(_rootFD, "."', 'fdopendir(fd)', 'readdir(directory)', 'AT_SYMLINK_NOFOLLOW', 'S_ISDIR(item.st_mode)', '@finally { closedir(directory); }'):
        assert token in lease_inventory, token
    assert 'dup(_rootFD)' not in lease_inventory and 'removeItemAtPath:' not in lease_inventory
    leaf_probe = writers.method(read('common/PXProfileLifecycleLease.m'), '- (BOOL)profileLeafExistsForID:(NSString *)profileID exists:(BOOL *)exists error:(NSError **)error')
    assert 'AT_SYMLINK_NOFOLLOW' in leaf_probe and 'errno != ENOENT' in leaf_probe
    assert leaf_probe.count('validateWithError:error') == 2
    for file in ('TLinkIOSViewController.m', 'DeviceSpecificSpoofingViewController.m'):
        preview = read(file)
        assert 'generateProfileIDWithError:NULL' in preview and 'sampleProfileID.length ?' in preview
        assert 'Profile ID will be assigned when creation starts.' in preview
    auto = writers.method(read('TLinkIOSViewController.m'), '- (void)createNextProfileAndRandomizeWithWarnings:(NSArray<NSString *> *)warnings')
    assert auto.index('if (!NSThread.isMainThread)') < auto.index('generateProfileIDWithError:&allocationError')
    assert auto.index('if (!candidateID)') < auto.index('[pm createProfile:') and '[pm generateProfileID]' not in auto
    for filename, (path, signatures) in UI_ADAPTERS.items():
        if filename.startswith('PXReset'):
            continue  # Reset intentionally retains its extra enabled-group generation.
        for signature in signatures:
            adapter = writers.method(read(path), signature)
            for forbidden in ('switchToProfile:', 'regenerateAllEnabledIdentifiers', 'regenerateDeviceProfileGroup', 'generateDeviceTheme', 'dispatch_after'):
                assert forbidden not in adapter, (path, forbidden)
    for path, signature, busy in (
        ('DeviceSpecificSpoofingViewController.m', UI_ADAPTERS['PXDeviceCreateUI.inc'][1][0], 'profileCreationInProgress'),
        ('TLinkIOSViewController.m', UI_ADAPTERS['PXManualCreateUI.inc'][1][0], 'manualProfileCreationInProgress'),
        ('ProfileCreationViewController.m', '- (void)createButtonTapped', 'profileCreationInProgress')):
        adapter = writers.method(read(path), signature)
        assert 'if (!NSThread.isMainThread)' in adapter and f'if (self.{busy}) return;' in adapter
        expected_call = 'createProfile:newProfile completion:' if 'createButtonTapped' in signature else 'createProfile:input completion:'
        assert 'weakSelf' in adapter and expected_call in adapter
    for path in ('DeviceSpecificSpoofingViewController.m', 'TLinkIOSViewController.m'):
        adapter = writers.method(read(path), UI_ADAPTERS['PXDeviceCreateUI.inc' if 'DeviceSpecific' in path else 'PXManualCreateUI.inc'][1][0])
        assert adapter.index('if (!success)') < adapter.index('validateCurrentProfileID:input.profileId')
    assert 'addProfileWithName:' not in read('DeviceSpecificSpoofingViewController.m')
    form = read('ProfileCreationViewController.m')
    assert '!self.profileCreationInProgress && trimmedText.length > 0' in form
    reset_wrapper = writers.method(read('TLinkIOSViewController.m'), UI_ADAPTERS['PXResetPreparationUI.inc'][1][1])
    reset_prepare = writers.method(read('TLinkIOSViewController.m'), UI_ADAPTERS['PXResetPreparationUI.inc'][1][4])
    required_wrapper = writers.method(read('TLinkIOSViewController.m'), UI_ADAPTERS['PXResetPreparationUI.inc'][1][0])
    required = writers.method(read('TLinkIOSViewController.m'), UI_ADAPTERS['PXResetPreparationUI.inc'][1][-1])
    assert 'expectedProfileID:nil error:error' in required_wrapper
    assert required.index('if (profileID)') < required.index('enumerateKeysAndObjectsUsingBlock:')
    assert 'enableRequiredIdentifiers:types forExpectedActiveProfileID:profileID error:error' in required
    assert 'if (error) *error = nil;' in reset_prepare and 'if (!NSThread.isMainThread)' in reset_prepare
    assert 'if (![self ensureDashboardFakeOptionsEnableRequiredIdentifiers:options expectedProfileID:profileID error:error]) return NO;' in reset_prepare
    assert reset_prepare.index('ensureDashboardFakeOptionsEnableRequiredIdentifiers:options') < reset_prepare.index('regenerateAllEnabledIdentifiersWithError:') < reset_prepare.index('applyFakePreviewToCurrentProfile:preview')
    assert 'regenerateAllEnabledIdentifiersForExpectedActiveProfileID:profileID error:&generationError' in reset_prepare and 'if (!generated)' in reset_prepare
    assert 'applyDashboardPreview:preview expectedActiveProfileID:profileID error:&previewError' in reset_prepare and 'if (!applied)' in reset_prepare
    assert 'generationError ?: [NSError' in reset_prepare and reset_prepare.count('validateDashboardResetProfileID:profileID error:error') == 4
    assert 'expectedProfileID:nil error:error' in reset_wrapper
    assert auto.count('captureCurrentDashboardHardwareWithError:&intentError') == 1
    assert auto.index('captureCurrentDashboardHardwareWithError:') < auto.index('if (previewNeedsRefresh)') < auto.index('generateProfileIDWithError:')
    assert 'generateFakePreviewFromOptions:fakeOptions currentDeviceIDs:currentDeviceIDs' in auto
    assert 'profileIdentityPath]' not in auto and 'dictionaryWithContentsOfFile:' not in auto
    preview_wrapper = writers.method(read('TLinkIOSViewController.m'), UI_ADAPTERS['PXFakePreviewUI.inc'][1][0])
    preview_provider = writers.method(read('TLinkIOSViewController.m'), UI_ADAPTERS['PXFakePreviewUI.inc'][1][1])
    assert 'currentDeviceIDs:nil' in preview_wrapper
    assert preview_provider.count('currentDeviceIDs ? currentDeviceIDs[@"DeviceModel"] : [self.manager currentValueForIdentifier:@"DeviceModel"]') == 2
    assert '*stop = YES;' in required and 'return failure == nil;' in required and 'NSUnderlyingErrorKey' in required
    assert '[self.manager regenerateAllEnabledIdentifiers];' not in auto
    assert 'prepareResetProfileWithOptions:fakeOptions preview:preparedPreview expectedProfileID:createdProfileID error:&preparationError' in auto
    checkpoint = writers.method(read('TLinkIOSViewController.m'), UI_ADAPTERS['PXResetPreparationUI.inc'][1][5])
    assert 'validateCurrentProfileID:profileID error:error' in checkpoint
    assert auto.index('NSString *createdProfileID = [newProfile.profileId copy];') < auto.index('[pm switchToProfile:newProfile')
    assert auto.count('validateDashboardResetProfileID:createdProfileID') == 3
    assert 'Skipping Reset restart after selection checkpoint failure' in auto
    for case in ('reset hardware capture failure stops before profile creation flags generation and preview',
                 'reset iOS-only reuses one hardware packet for preview refresh marker validation and variant preservation',
                 'other reset option modes keep legacy preview path without hardware capture',
                 'actual preview generator uses supplied hardware without rereading mutable current model',
                 'generic preview wrapper retains existing live model lookup policy'):
        assert case in read('tests/PXProfileCreationFlowTests.m'), case
    for case in ('reset selection change after create never switches back to the old request',
                 'reset selection checkpoints stop after toggle generation or preview supersession',
                 'queued reset feedback rejects a selection changed after persistence',
                 'delayed reset restart is skipped after another profile becomes active',
                 'reset feedback uses the frozen created ID after caller model edits'):
        assert case in fixture, case
    failure_tail = auto.split('if (![self prepareResetProfileWithOptions:', 1)[1].split('[self discardConsumedResetPreviewForIntent:submittedIntent];', 1)[0]
    assert '[self hideProgressHUD];' in failure_tail and '[self showError:preparationError];' in failure_tail and 'return;' in failure_tail
    capture = writers.method(read('TLinkIOSViewController.m'), UI_ADAPTERS['PXResetPreparationUI.inc'][1][2])
    consume = writers.method(read('TLinkIOSViewController.m'), UI_ADAPTERS['PXResetPreparationUI.inc'][1][3])
    for token in ('dataWithPropertyList:payload', 'NSPropertyListImmutable', '@catch', 'fakeIOSVersionEnabled', 'modelMinIndex'):
        assert token in capture, token
    for forbidden in ('writeToFile:', 'setObject:', 'NSUserDefaults', 'dispatch_', 'self.manager'):
        assert forbidden not in capture, forbidden
    assert auto.index('captureResetIntentWithOptions:self.nextFakeOptions') < auto.index('BOOL fakeIOS =')
    assert auto.index('captureResetIntentWithOptions:fakeOptions preview:preparedPreview') < auto.index('generateProfileIDWithError:') < auto.index('[pm createProfile:')
    assert 'NSDictionary *preparedPreview = submittedIntent[@"preview"];' in auto and 'preparedPreview = preparedIntent[@"preview"];' in auto
    assert 'self.nextFakePreview = nil;' not in auto
    assert 'NSThread.isMainThread' in consume and consume.index('isEqual:intent[@"options"]') < consume.index('self.nextFakePreview = nil;')
    assert consume.index('isEqual:intent[@"preview"]') < consume.index('self.nextFakePreview = nil;')
    for case in ('reset request deeply detaches mutable options preview strings and nested containers',
                 'reset nil request keeps defaults and capture has no persistence or provider effects',
                 'reset malformed option scalars and invalid property lists fail with an error',
                 'reset consumes only an unchanged options and preview packet',
                 'reset completion preserves a replaced or mutated newer preview or options',
                 'reset final provider preview is detached before asynchronous creation',
                 'reset pending preparation uses the captured options after the caller edits its packet',
                 'off-main reset preview consumption preserves current pending intent'):
        assert case in fixture, case
    reset_source = read('TLinkIOSViewController.m')
    reset_begin, reset_advance, reset_finish, backup_entry, reset_entry, clear_entry, _ = [writers.method(reset_source, s) for s in UI_ADAPTERS['PXResetWorkflowUI.inc'][1]]
    assert 'NSThread.isMainThread' in reset_begin and 'self.dashboardResetToken' in reset_begin
    for helper in (reset_advance, reset_finish):
        assert '!NSThread.isMainThread' in helper and 'self.dashboardResetToken != token' in helper
    for entry in (backup_entry, reset_entry):
        assert 'if (!NSThread.isMainThread)' in entry and 'weakSelf' in entry and 'beginDashboardResetInPhase:' in entry
    assert 'fromPhase:@"backup" toPhase:@"clear"' in backup_entry
    assert 'fromPhase:@"clear" toPhase:@"clearing"' in clear_entry
    assert 'fromPhase:@"clearing" toPhase:@"preparing"' in clear_entry
    weak_delivery = '__strong typeof(weakSelf) self = weakSelf; if (!self) return;'
    assert weak_delivery in backup_entry and weak_delivery in clear_entry
    assert auto.count(weak_delivery) == 5, 'Reset must promote weak owner separately for entry/create/switch/feedback/restart deliveries'
    assert 'warnings:[NSMutableArray array] resetToken:token completion:' in backup_entry
    assert 'warnings:[warnings mutableCopy] resetToken:token completion:' in clear_entry
    assert 'NSArray<NSString *> *apps = self.dashboardResetInputs[@"resetApps"];' in clear_entry
    assert 'syncHookScopeToResetAppIDs:apps waitingForDaemon:YES' in clear_entry and '[self clearApps:apps index:0' in clear_entry
    assert 'self.selectedResetAppIDs' not in clear_entry and 'self.selectedRRSAppIDs' not in backup_entry
    assert 'self.dashboardResetInputs[@"backupApps"]' in backup_entry
    assert reset_begin.index('captureDashboardResetInputsForBackup:') < reset_begin.index('self.dashboardResetToken = token;')
    assert 'self.dashboardResetInputs = nil;' in reset_finish
    app_capture, input_capture = [writers.method(reset_source, s) for s in UI_ADAPTERS['PXResetInputsUI.inc'][1]]
    assert '[value copy]' in app_capture and 'return [captured copy];' in app_capture and 'NSString.class' in app_capture
    assert '!NSThread.isMainThread' in input_capture and '[note copy]' in input_capture
    scope_adapter = writers.method(reset_source, '- (BOOL)syncHookScopeToResetAppIDs:(NSArray<NSString *> *)bundleIDs waitingForDaemon:(BOOL)waitForDaemon')
    assert 'PXResetBundlesForSpoofScope(bundleIDs)' in scope_adapter and 'self.selectedResetAppIDs' not in scope_adapter
    assert scope_adapter.index('PXExpandedResetBundleIDs(spoofEligibleResetApps)') < scope_adapter.index('replaceApplicationScopeWithBundleIDs:expandedBundles') < scope_adapter.index('PXWriteSubstrateFilterPlists()')
    for old, new in (('preparing','preflight'), ('preflight','create'), ('create','switch'), ('switch','apply'), ('apply','restart'), ('restart','restarting')):
        assert f'fromPhase:@"{old}" toPhase:@"{new}"' in auto
    assert '@finally { [self finishDashboardReset:token]; }' in auto
    for case in ('reset admission excludes both buttons before clear through scheduled restart',
                 'duplicate phase callbacks produce one create switch apply notification and restart',
                 'old reset callbacks and delayed restart cannot affect a newer run',
                 'reset terminal preparation failures release admission and skip success tail',
                 'backup failure and missing selections release reset admission without clearing',
                 'backup success advances once and filter failure permits a later reset',
                 'restart exception releases only its own reset token',
                 'off-main reset entries admit one run and keep UI effects on main'):
        assert case in fixture, case
    batch_helpers = [writers.method(reset_source, s) for s in UI_ADAPTERS['PXResetBatchUI.inc'][1]]
    for batch, phase in ((batch_helpers[2], 'backup'), (batch_helpers[4], 'clearing')):
        assert 'if (!NSThread.isMainThread)' in batch and '__block BOOL completed = NO;' in batch
        assert batch.count(f'isDashboardReset:resetToken inPhase:@"{phase}"') == 2
        assert batch.index('if (completed) return;') < batch.index('completed = YES;') < batch.rindex('isDashboardReset:resetToken')
        assert 'resetToken:resetToken' in batch and 'dispatch_async(dispatch_get_main_queue()' in batch
        assert '__strong typeof(self) retainedOwner = resetToken ? nil : self;' in batch
        assert batch.count('__strong typeof(weakSelf) self = retainedOwner ?: weakSelf; if (!self) return;') == 2
        assert batch.index('completed = YES;') < batch.rindex('self = retainedOwner ?: weakSelf') < batch.rindex('isDashboardReset:resetToken')
    assert 'resetToken:nil' in batch_helpers[1] and 'resetToken:nil' in batch_helpers[3]
    assert 'NSString *resetNote = resetToken ? self.dashboardResetInputs[@"note"] : nil;' in batch_helpers[2]
    assert 'note:resetToken ? (resetNote ?: @"") : (self.rrsNoteTextField.text ?: @"")' in batch_helpers[2]
    for case in ('reset backup clear create switch and restart callbacks do not retain the UI owner',
                 'late reset phase callbacks and restart skip UI effects and later work after owner release',
                 'queued reset feedback does not extend owner lifetime or schedule restart after release',
                 'reset per-app service and already queued delivery do not retain the controller',
                 'released reset batch rejects late duplicate service deliveries without metadata or next submissions',
                 'generic nil-token batches preserve strong owner lifetime until callback release',
                 'generic batch owner releases when producer callbacks are released',
                 'off-main reset service and creation bounce do not retain the controller'):
        assert case in fixture, case
    assert 'TestResetOwnerLifetime();' in fixture
    for case in ('reset admission captures app order duplicates and mutable strings without editing live choices',
                 'reset scope and clear use the admitted list after backup while newer choices survive',
                 'reset backup metadata uses the admitted note after UI text changes',
                 'invalid app selections fail before admission HUD filter or service effects',
                 'direct reset ignores unused malformed RRS input and matching finish releases its snapshot',
                 'off-main input capture fails without reading mutable UI state'):
        assert case in fixture, case
    for case in ('backup per-app callbacks advance once with one metadata write on main',
                 'clear per-app callbacks append one failure and advance once on main',
                 'retired reset batches ignore metadata warnings and remaining app submissions',
                 'wrong-phase reset batches submit no service requests',
                 'generic backup keeps nil-token behavior during an unrelated reset',
                 'synchronous duplicate service results stay sequential without recursive stack growth',
                 'batch empty suffix and null completion preserve terminal behavior'):
        assert case in fixture, case
    for case in ('reset required identifier defaults and option matrix preserve enable-only policy',
                 'reset stops at each failed required identifier before generation and preview',
                 'reset preserves earlier verified toggles when a later toggle fails',
                 'reset generation failure never applies preview and always returns an error',
                 'reset preview failure is reported after one successful generation',
                 'reset full preparation preserves ordering and skips already enabled identifiers',
                 'off-main reset preparation rejects before providers or persistence'):
        assert case in fixture, case
    current_check = writers.method(source, '- (BOOL)validateCurrentProfileID:(NSString *)profileID error:(NSError **)error')
    assert 'captureProfileSelectionWithError:error' in current_check and 'code:20' in current_check
    for forbidden in ('mutableCurrentProfile =', 'PXStage', 'mirrorCurrentProfileID:', 'writeRegistryData:'):
        assert forbidden not in current_check, forbidden
    generation = writers.method(read('common/IdentifierManager.m'), '- (BOOL)commitRuntimeGenerationAtIdentityDirectory:(NSString *)identityDir networkArtifacts:(NSDictionary *)networkArtifacts lifecycleLease:(PXProfileLifecycleLease *)lease expectedSelection:(NSDictionary *)selection deferSettings:(BOOL)deferSettings receipt:(PXCommittedRuntimeGeneration **)receipt error:(NSError **)error')
    assert 'BOOL needsBaseline = !PXProfileString(ids[@"DeviceModel"]).length' in generation and 'candidate[@"theme"] = ' in generation
    for case in ('device creation adapter waits for completion and rejects duplicate submission',
                 'device creation adapter refreshes only committed current success and reports failure or supersession',
                 'manual popup adapter submits once and publishes no premature success',
                 'manual popup adapter gates active success on completion and current selection without delayed regeneration',
                 'form pending state survives text changes duplicate submit and cancel attempts',
                 'form creation publishes captured name once only on success after restoring controls',
                 'pending core creation does not retain controller ownership',
                 'late creation completion skips released UI while producer still completes',
                 'off-main manual create handoff reaches producer on main',
                 'current profile checkpoint reads committed ID without repairing selection memory archive or defaults',
                 'completion checkpoint preserves newer selection instead of switching back'):
        assert case in fixture, case
    for case in ('ID ordering preserves normal numeric and alpha progression without overflow or foreign-name poisoning',
                 'allocation grammar is nonempty ASCII with bounded canonical alpha suffixes',
                 'namespace probing advances each candidate once without redoing sequence discovery',
                 'namespace probe errors stop allocation without fallback or retry',
                 'verified allocation skips occupied leaves without following symlinks or modifying files',
                 'registered IDs remain occupied even when their directories are missing',
                 'repeated borrowed allocation inventories reset directory offsets retain ownership and close descriptors',
                 'busy allocation reports failure without a guessed legacy fallback',
                 'allocation rejects stale registry receipts instead of guessing an ID',
                 'allocation rejects unreadable registry bytes through the shared decoder',
                 'allocation failure stops create before caller mutation reservation provider or selection effects',
                 'exclusive reservation remains authoritative when a leaf appears after allocation',
                 'allocation respects the actual filesystem case-alias policy without assuming case sensitivity',
                 'sequence exhaustion preserves occupied namespace instead of inventing an invalid next prefix'):
        assert case in fixture, case
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
    assert ui.count('refreshCurrentProfileFromCommittedSelectionWithError:NULL') == 3
    list_ui = writers.method(ui, '- (void)loadProfilesFromDisk')
    assert 'loadProfilesWithCompletion:' in list_ui and 'manager.profiles' in list_ui and 'performSearch' in list_ui
    for forbidden in ('contentsOfDirectoryAtPath:', 'NSKeyedUnarchiver', 'enrichProfilesWithAdditionalInfo', 'intValue'):
        assert forbidden not in list_ui, forbidden
    for signature in ('- (void)deleteAllProfiles', '- (void)showDeleteConfirmationForProfile:(Profile *)profile',
                      '- (void)confirmDeletionOfProfileID:(NSString *)profileID showResult:(BOOL)showResult completion:(void (^)(BOOL))completion',
                      '- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath'):
        body = writers.method(ui, signature)
        for forbidden in ('removeItemAtPath:', 'contentsOfDirectoryAtPath:', 'removeObjectAtIndex:', 'deleteRowsAtIndexPaths:'):
            assert forbidden not in body, forbidden
    confirmation = writers.method(ui, '- (void)confirmDeletionOfProfileID:(NSString *)profileID showResult:(BOOL)showResult completion:(void (^)(BOOL))completion')
    assert 'deleteInactiveProfileID:targetID' in confirmation and 'finish(success)' in confirmation and 'if (!finished)' in confirmation
    bulk = writers.method(source, '- (void)deleteInactiveProfilesWithCompletion:(void (^)(NSDictionary *result))completion')
    step = writers.method(source, '- (void)deleteInactiveProfileIDs:(NSArray<NSString *> *)profileIDs index:(NSUInteger)index result:(NSMutableDictionary *)result completion:(void (^)(NSDictionary *result))completion')
    assert 'self.mutableProfiles' in bulk and '[ids copy]' in bulk
    assert 'dispatch_get_main_queue()' in step and 'deleteInactiveProfileID:profileID' in step
    assert '@"0"' in step and '@"profile_0"' in step and 'error.code == 32' in step
    assert 'removeItemAtPath:' not in bulk + step and 'contentsOfDirectoryAtPath:' not in bulk + step
    edit = writers.method(source, EDIT)
    assert edit.index('beginProfileOperationWithError:') < edit.index('archivedDataWithRootObject:models') < edit.index('updateProfileUnderLease:edit') < edit.index('PXStageRuntimeProfileSelectionIfUnchanged')
    assert '@finally { [self endProfileOperation]; }' in edit
    assert edit.index('[self endProfileOperation];') < edit.index('if (mirroredSelection)') < edit.index('if (success) [self publishProfileChangedNotification]')
    assert 'requestedName = [name copy]' in edit and 'requestedDescription = [shortDescription copy]' in edit
    compatibility_rename = writers.method(source, '- (void)renameProfile:(NSString *)oldName to:(NSString *)newName')
    assert 'editProfileID:profileToRename.profileId' in compatibility_rename and 'profileToRename.name =' not in compatibility_rename
    rename_ui = writers.method(ui, '- (void)showRenameDialogForProfile:(Profile *)profile')
    description_ui = writers.method(ui, '- (void)infoTapped:(UIButton *)sender')
    edit_ui = writers.method(ui, '- (void)saveMetadataForProfileID:(NSString *)profileID name:(NSString *)name shortDescription:(NSString *)shortDescription successTitle:(NSString *)successTitle successMessage:(NSString *)successMessage notifyDelegate:(BOOL)notifyDelegate')
    for body in (rename_ui, description_ui, edit_ui):
        for forbidden in ('writeToFile:', 'dictionaryWithContentsOfFile:', 'updateCurrentProfileInfoWithProfile:', 'profile.name =', 'profile.shortDescription =', 'didUpdateAnyFile'):
            assert forbidden not in body, forbidden
        assert 'weakSelf' in body
    assert 'weakAlert' in rename_ui and 'weakAlert' in description_ui
    assert 'editProfileID:profileID' in edit_ui and 'success ? successTitle' in edit_ui and 'if (success && notifyDelegate' in edit_ui
    assert 'scoped[@"Description"] = description' in read('common/PXProfileMetadataWriter.m')
    for case in ('owned metadata edit faults preserve caller model archive display absence and selection',
                 'inactive metadata edit owns the graph preserves empty description and leaves active selection unchanged',
                 'active metadata edit commits registry before selection labels and publishes only after both phases',
                 'label failure reports partial metadata commit without overwriting selection or publishing success',
                 'post-registry edit exception clears success and releases lifecycle before completion',
                 'metadata edit selection CAS preserves a newer target after registry commit',
                 'metadata edit rejects invalid unknown and busy requests before persistence',
                 'background metadata edit delivers on main after releasing ownership',
                 'ID-based edits do not select another profile with the same display name',
                 'legacy rename routes through the owned metadata edit API'):
        assert case in fixture, case
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
    for fd in ('_rootFD', '_profileFD', '_identityFD', '_markerFD', '_metadataFD'):
        assert f'if ({fd} >= 0) close({fd});' in reservation
    reserve = writers.method(reservation, '+ (instancetype)reserveProfileID:(NSString *)profileID inProfilesDirectory:(NSString *)directory metadata:(NSDictionary *)metadata error:(NSError **)error')
    assert reserve.index('dataWithPropertyList:metadata') < reserve.index('mkdirat(')
    assert reserve.index('propertyListWithData:metadataData') < reserve.index('mkdirat(')
    assert 'frozenMetadata[@"Identifier"] isEqual:profileID' in reserve and '@catch' in reserve
    assert 'PXWriteNewProfileData' in reserve and 'reservation.metadataData = metadataData' in reserve
    validate = writers.method(reservation, '- (BOOL)validateWithError:(NSError **)error')
    assert 'PXReservationDataMatches(_metadataFD, self.metadataData)' in validate and 'PXReservationDataMatches(_markerFD, self.markerData)' in validate
    assert 'metadata.st_nlink != 1' in validate and 'metadata.st_ino != metadataPath.st_ino' in validate
    assert '#include <string.h>' in reservation and 'uint8_t buffer[4096]' in reservation and 'memcmp(' in reservation and 'return tail == 0;' in reservation
    assert 'NSMutableData' not in validate
    for case in ('invalid reservation metadata fails before creating a directory or orphan marker',
                 'reservation freezes actual XML bytes independently of mutable caller metadata',
                 'reservation rejects missing replaced symlink mutated truncated hardlinked or extended display metadata',
                 'streaming display comparison detects corruption beyond the first buffer',
                 'metadata reservation success and rejection release every descriptor',
                 'display ownership loss never activates or publishes creation success',
                 'display corruption after generation rejects before registry or termination',
                 'display corruption during termination leaves inactive registration without activating it',
                 'display rejection retains reserved directory without automatic cleanup'):
        assert case in fixture, case
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
    for signature in METHODS[:3] + [DELETE_ID]:
        assert 'beginProfileOperationWithError:' in writers.method(source, signature)
    delete = writers.method(source, DELETE_CORE)
    delete_entry = writers.method(source, DELETE_ID)
    assert '@finally { [self endProfileOperation]; }' in delete_entry
    assert 'requireInactive:NO' in writers.method(source, METHODS[3])
    assert 'requireInactive:YES' in writers.method(source, '- (void)deleteInactiveProfileID:(NSString *)profileID completion:(void (^)(BOOL success, NSError * _Nullable error))completion')
    assert delete.index('if (requireInactive && active)') < delete.index('archivedDataWithRootObject:remaining')
    assert delete.index('PXProfileDeletionCheckpoint(@"settled")') < delete.index('PXRuntimeProfileSelectionMatches') < delete.index('removeDirectoryForProfileID:')
    for case in ('verified list exposes registered models without adopting orphan or reserved directories',
                 'inactive-only delete checks committed active ID instead of stale UI memory',
                 'profile activated after confirmation cannot be removed through UI deletion',
                 'UI delete decision failure preserves registry directory and callback lifecycle',
                 'UI delete success unregisters before file cleanup without mutating a captured list',
                 'source drift after logical deletion preserves newly active files and reports partial failure',
                 'bulk delete preserves live active protected orphan reserved and newly created profiles',
                 'busy bulk deletion reports one bounded failure per captured candidate without retry or mutation',
                 'background inactive delete completes on main after releasing lifecycle ownership',
                 'invalid registry stops bulk deletion before any namespace cleanup'):
        assert case in fixture, case
    legacy_compare = writers.method(source, '- (BOOL)registryValue:(id)before matchesValue:(id)after seen:(NSMapTable *)seen')
    assert 'allowLegacyDates:YES' in legacy_compare
    compare = writers.method(source, '- (BOOL)registryValue:(id)before matchesValue:(id)after seen:(NSMapTable *)seen allowLegacyDates:(BOOL)allowLegacyDates')
    archive_validation = writers.method(source, '- (BOOL)validateDeletionArchives:(NSDictionary *)intent error:(NSError **)error')
    assert 'registryValue:oldFields matchesValue:newFields seen:nil' in archive_validation
    assert '[oldFields isEqual:newFields]' not in archive_validation and '|| !datesValid' in archive_validation
    for token in ('Profile.class', 'NSArray.class', 'NSDictionary.class', 'NSPointerFunctionsObjectPointerPersonality',
                  'left.profileId', 'left.name', 'left.shortDescription', 'left.iconName', 'left.settings',
                  'right.pxDecodedMissingCreatedAt', 'right.pxDecodedMissingLastUsed', '[before isEqual:after]'):
        assert token in compare, token
    model_proof = writers.method(source, '- (BOOL)activationProfile:(Profile *)profile matchesRegistry:(NSDictionary *)record error:(NSError **)error')
    assert 'decodeRegistryRecord:record' in model_proof and 'allowLegacyDates:NO' in model_proof and 'code:31' in model_proof
    assert 'left.createdAt matchesValue:right.createdAt' in compare and 'left.lastUsed matchesValue:right.lastUsed' in compare
    activate = writers.method(source, '- (BOOL)activateProfile:(Profile *)profile expectedSelection:(NSDictionary *)expected generation:(PXCommittedRuntimeGeneration *)generation error:(NSError **)error')
    assert activate.count('readRegistryWithError:') == 1
    assert activate.index('activationProfile:profile matchesRegistry:observedRegistry') < activate.index('PXPerformRuntimeSourceWrite(')
    assert '[profile.name copy]' in activate and '[profile.shortDescription copy]' in activate
    for body in (finish, switch):
        assert body.index('activationProfile:profile matchesRegistry:self.registryRecord') < body.index('terminateEnabledScopedApps')
    for case in ('activation accepts equal persisted date values despite transient legacy provenance flags',
                 'activation strict date matching does not inherit deletion legacy timestamp relaxation',
                 'activation model proof rejects target metadata dates settings and nested date drift',
                 'create and switch reject callback model drift without activating or publishing success',
                 'post-archive model drift rejects before termination and post-termination drift is not repeated',
                 'callback model drift does not rewrite the acknowledged registry archive',
                 'explicit reload replaces callback-mutated slots with committed registry values'):
        assert case in fixture, case
    for case in ('deletion archive validation preserves equal nested Profile values across separate decodes',
                 'deletion archive validation rejects changes to every nested Profile identity metadata date or settings field',
                 'nested archive comparison has no persistent memo state and preserves original before bytes',
                 'registry value comparison terminates for equivalent cyclic containers',
                 'registry value comparison still rejects mismatched values inside cycles'):
        assert case in fixture, case
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
    assert manifest['rollout'] == '4C.2H4V-partial'
    assert manifest['writers']['default-profile-seed']['status'] == 'enrolled'
    assert 'default-profile-seed' in next(item for item in manifest['sources'] if item['field'] == 'deviceIDs')['writers']
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
    for filename, (path, signatures) in UI_ADAPTERS.items():
        (folder / filename).write_text('\n\n'.join(writers.method(read(path), signature) for signature in signatures), encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-profile-flow-') as temp:
        folder = Path(temp)
        generate_native_fragments(folder)
        sources = ['common/PXProfileDeletionJournal.m', 'common/PXProfileLifecycleLease.m', 'common/PXProfileCreationReservation.m', 'common/PXRuntimeProfileSelection.m', 'common/PXRuntimeSourceStore.m', 'common/PXRuntimePublisher.m',
                   'common/PXRuntimeGeneration.m', 'common/PXRuntimeArtifactWriter.m', 'common/PXRuntimeIdentifierWriter.m',
                   'common/PXProfileArtifactMutation.m', 'common/PXProfileMetadataWriter.m', 'common/PXDefaultProfileSeed.m',
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
