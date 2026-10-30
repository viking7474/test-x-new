#!/usr/bin/env python3
"""4C.1 partial enrollment contracts; --native runs production source transactions."""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text(encoding='utf-8')


def method(source, signature):
    return source.split(signature + ' {', 1)[1].split('\n- (', 1)[0]


def manager_role_fragment():
    """Keep production preprocessor directives, including any guard BEFORE the helper."""
    source = read('common/IdentifierManager.m')
    sanitizer = source.index('static NSDictionary *PXSanitizedIdentifierSettings')
    start = source.index('\n}', sanitizer) + 2
    end = source.index('\nstatic BOOL PXRuntimeSnapshotImpliesIdentifierEnabled', start)
    return source[start:end]


def source_contracts():
    core = read('common/PXRuntimeSourceStore.m')
    paths = read('common/PXRuntimeSources.m')
    runtime = read('common/PXRuntimeSnapshot.m')
    manager = read('common/IdentifierManager.m')
    fixture = read('tests/PXRuntimeSourceStoreTests.m')
    role = manager_role_fragment()
    assert role.lstrip().startswith('static BOOL PXIdentifierManagerIsManagerProcess(void)'), 'manager role helper must compile on rootful too'
    assert role.index('static BOOL PXIdentifierManagerIsManagerProcess') < role.index('#if defined(THEOS_PACKAGE_SCHEME_ROOTHIDE)')
    publisher_header = read('common/PXRuntimePublisher.h')
    for name in ('Loader', 'Writer', 'Distributor', 'Notifier'):
        assert f'(^ _Nonnull PXRuntimePublication{name})' in publisher_header
    assert 'NSDictionary * _Nonnull (^ _Nonnull PXRuntimePublicationDistributor)' in publisher_header
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['schemaVersion'] == 1 and manifest['rollout'] == '4C.2H5F-partial'
    assert len(manifest['sources']) == 19 and len({x['field'] for x in manifest['sources']}) == 19
    for source in manifest['sources']:
        for writer in source['writers']:
            assert writer in manifest['writers'], f'unknown writer: {writer}'
    for writer in manifest['writers'].values():
        for file in writer['files']:
            assert (ROOT / file).is_file(), f'manifest refers to missing source: {file}'
    assert manifest['writers']['profile-lifecycle']['status'] == 'partial'
    assert manifest['writers']['preferences-daemon']['status'] == 'external'
    assert manifest['writers']['identifier-settings-scope']['status'] == 'enrolled'
    for token in ('NSRecursiveLock', 'LOCK_SH', 'LOCK_EX', 'LOCK_NB', 'CLOCK_MONOTONIC',
                  'O_CLOEXEC | O_NOFOLLOW', 'st.st_nlink != 1', 'geteuid() != _owner',
                  'pending.plist', 'commit.plist', 'transactionID', 'commitID',
                  'Source transaction pending recovery', 'NSPropertyListImmutable'):
        assert token in core, f'source gate/journal contract missing: {token}'
    assert 'if (![self checkPaths:entries error:error]) return NO;' in core
    restore = method(core, '- (BOOL)restoreEntries:(NSArray<NSDictionary *> *)entries error:(NSError **)error')
    assert restore.index('checkPaths:entries') < restore.index('for (NSDictionary *entry')
    assert 'unlink(path.fileSystemRepresentation)' in restore and 'unsignedShortValue' in restore
    commit = method(core, '- (BOOL)commitTransaction:(PXRuntimeSourceTransaction *)transaction error:(NSError **)error')
    assert commit.index('self.journalPath, _owner') < commit.index('transaction.staged[path], path') < commit.index('commit, self.commitPath')
    assert '@finally' in commit and '[self recover:NULL]' in commit
    assert commit.index('BOOL markerCommitted = NO;') < commit.index('@try')
    assert commit.index('PXRuntimeWritePropertyList(commit, self.commitPath') < commit.index('markerCommitted = YES;') < commit.index('self.testCheckpoint(@"commit-written")')
    assert commit.count('if (!markerCommitted) @throw;') == 2
    assert commit.index('@catch (NSException *exception)') < commit.index('@finally') < commit.index('@catch (NSException *recoveryException)')
    assert 'self.testCheckpoint(@"journal-cleanup")' in commit and 'self.testCheckpoint(@"transaction-recovery")' in commit

    capture = method(core, '- (NSDictionary *)capture:(NSDictionary *(^)(NSError **))loader error:(NSError **)error')
    assert 'LOCK_SH' in capture and 'journalRecord' in capture and 'commit[@"commitID"]' in capture
    assert 'recover:' not in capture and 'writeToFile' not in capture and 'removeItem' not in capture
    assert capture.index('NSPropertyListImmutable') < capture.index('flock(_lockFD, LOCK_UN)')
    decoder = core.split('NSDictionary *PXReadRuntimeSourceDictionary(', 1)[1].split('@interface', 1)[0]
    assert 'PXReadRuntimeSourceDictionary' in read('common/PXRuntimeSourceStore.h')
    assert 'PXSourceReadPlist(path, &absent, NULL, NULL, &failure)' in decoder
    assert 'if (absent) return @{};' in decoder and 'isKindOfClass:NSDictionary.class' in decoder
    assert 'if (error) *error = failure ?: PXSourceError(@"Malformed source dictionary during capture"); return nil;' in decoder
    assert 'return value;' in decoder and 'Invalid source dictionary path' in decoder
    assert 'flock(' not in decoder and 'recover:' not in decoder and 'writeToFile:' not in decoder
    for case in ('capture decoder distinguishes valid dictionary from missing empty source',
                 'capture decoder rejects malformed source instead of silently treating it as missing',
                 'capture decoder rejects valid plist with non dictionary root',
                 'capture decoder failures preserve original commit marker and restored tuple'):
        assert case in fixture, case
    assert 'TestCaptureDictionaryDecoder(root);' in fixture
    assert 'transaction.staged' in core and '_activeTransaction.failure' in core
    regular = method(core, '- (BOOL)performWrite:(BOOL (^)(PXRuntimeSourceTransaction *, NSError **))body error:(NSError **)error')
    standalone = method(core, '- (BOOL)performStandaloneWrite:(BOOL (^)(PXRuntimeSourceTransaction *, NSError **))body error:(NSError **)error')
    assert 'allowNested:YES' in regular and 'allowNested:NO' in standalone
    internal = method(core, '- (BOOL)performWrite:(BOOL (^)(PXRuntimeSourceTransaction *, NSError **))body allowNested:(BOOL)allowNested error:(NSError **)error')
    assert internal.index('if (!allowNested)') < internal.index('BOOL success = body(_activeTransaction')
    assert internal.index('if (error) *error = nil;') < internal.index('geteuid() != _owner')
    for case in ('acknowledged marker survives post-commit and finally exceptions without rollback or error',
                 'failed post-commit housekeeping retains only a matching committed journal',
                 'subsequent owner cleans committed journal and writes after acknowledgement exception',
                 'candidate and earlier committed marker never acknowledge a throwing body',
                 'pre-marker recovery exception still fails closed and keeps uncommitted journal',
                 'failed marker rename never acknowledges completed source writes',
                 'marker failure recovery restores old tuple and releases source ownership'):
        assert case in fixture, case
    assert 'TestCommitAcknowledgement(root)' in fixture
    probe = fixture.split('NSThread *ownerThread = NSThread.currentThread;', 1)[1].split('NSTask *child =', 1)[0]
    assert 'dispatch_async(dispatch_get_global_queue' in probe and 'dispatch_sync(' not in probe
    assert 'offOwner = NSThread.currentThread != ownerThread' in probe
    assert 'dispatch_semaphore_signal(checked)' in probe and 'dispatch_semaphore_wait(checked, dispatch_time(' in probe
    assert 'return completed && offOwner && rejected && [tx requireBaseCommitIdentifier:current error:error]' in probe
    assert 'BOOL requireRejected = ![tx requireBaseCommitIdentifier:current error:&requireError]' in probe
    assert 'BOOL baseRejected = [tx baseCommitIdentifierWithError:&baseError] == nil' in probe
    assert 'BOOL candidateRejected = [tx prospectiveCommitIdentifierWithError:&candidateError] == nil' in probe
    assert 'source commit probe completes on a distinct thread' in fixture

    consumer_ack = read('tests/PXRuntimeDeviceGroupWriterTests.m')
    for case in ('verified toggle acknowledges both committed writes without spurious compensation after housekeeping exceptions',
                 'acknowledged compensation publishes restored tuple while retaining original forward failure'):
        assert case in consumer_ack, case
    assert 'TestTogglePostCommitAcknowledgement();' in consumer_ack
    assert 'security receipt and all mirrors survive acknowledged marker housekeeping exception' in read('tests/PXRuntimeSecurityWriterTests.m')
    assert 'TestPostCommitSecurityAcknowledgement();' in read('tests/PXRuntimeSecurityWriterTests.m')

    assert '_activeTransaction.failure = PXSourceError(@"Standalone source write' in internal

    assert 'self.thread != NSThread.currentThread' in core and '!self.active' in core
    assert '[PXValidatedProfileID(parts[0]) isEqualToString:parts[0]]' in paths and 'stringByResolvingSymlinksInPath' in paths
    assert 'owner:501 group:501' in paths and 'RuntimeSource' in paths
    assert 'PXProfileIndicatorPositionPath()' in paths
    path_impl = read('common/PXPaths.m')
    assert 'NSString *PXProfileIndicatorPositionPath(void)' in path_impl and '@"indicator_position.plist"' in path_impl
    ancillary = manifest['ancillaryArtifacts']
    assert len(ancillary) == 2 and ancillary[0]['writer'] == 'indicator-position' and ancillary[0]['status'] == 'enrolled'
    assert ancillary[1]['writer'] == 'profile-display-metadata' and ancillary[1]['status'] == 'partial'
    for name in ('@"Info.plist"', '@"identifiers.plist"', '@"scoped-apps.plist"'):
        assert name in paths
    assert 'parts.count == 3 && [parts[1] isEqual:@"appdata"] && [parts[2] isEqual:@"Info.plist"]' in paths
    assert 'PXCaptureRuntimeSources(' in runtime and '@"sourceContractCoverage"] = @"settings-scope-manager-artifacts-identifier-telephony-partial"' in runtime
    assert '[self saveSettingsWithError:NULL]' in method(manager, '- (void)saveSettings')
    assert '[self saveSettingsWithSourceCommitIdentifier:NULL forIdentifier:nil beforeImage:NULL error:error]' in method(manager, '- (BOOL)saveSettingsWithError:(NSError **)error')
    save = method(manager, '- (BOOL)saveSettingsWithSourceCommitIdentifier:(NSString **)identifier forIdentifier:(NSString *)type beforeImage:(NSDictionary **)beforeImage error:(NSError **)error')
    scope = method(manager, '- (void)saveScopedApps')
    for body in (save, scope):
        assert 'PXPerformStandaloneRuntimeSourceWrite' in body and 'atPath:scopedAppsFile' in body
        assert 'PXPerformRuntimeSourceWrite(' not in body
        assert 'writeToFile:scopedAppsFile' not in body
        assert body.index('}, &sourceError)') < body.index('PXPostSettingsChangedNotification()')
        assert body.index('if (!success)') < body.index('removeAllObjects]')
    assert scope.index('}, &sourceError)') < scope.index('setAttributes:fileAttributes')
    fixture_settings = read('tests/PXRuntimeDeviceGroupWriterTests.m')
    for case in ('standalone settings and scope saves commit once before one compatibility notification',
                 'nested settings helpers reject before permissions caches or notification and poison ignored outer staging',
                 'standalone settings source faults preserve bytes commit identity caches and notification count',
                 'settings helpers preserve corrupt source without cache or notification effects',
                 'settings corruption teardown restores shared files and commit identity'):
        assert case in fixture_settings, case
    assert 'TestStandaloneSettingsSaves(manager, Identity(@"a"))' in fixture_settings
    toggle = method(manager, '- (BOOL)setIdentifierEnabledAndPersist:(BOOL)enabled forType:(NSString *)type')
    apply_wrapper = method(manager, '- (BOOL)applyIdentifierEnabled:(BOOL)enabled forType:(NSString *)type error:(NSError **)error')
    apply = method(manager, '- (BOOL)applyIdentifierEnabled:(BOOL)enabled forType:(NSString *)type operation:(id)operation primaryCommitted:(BOOL *)primaryCommitted sourceCommitIdentifier:(NSString **)sourceCommitIdentifier beforeImage:(NSDictionary **)beforeImage error:(NSError **)error')
    assert 'BOOL writeSuccess = [self applyIdentifierEnabled:enabled forType:type operation:operation primaryCommitted:&primaryCommitted sourceCommitIdentifier:&sourceIdentifier beforeImage:&beforeImage error:&writeError]' in toggle
    assert 'if (writeSuccess && primarySuccess && secondarySuccess) return YES;' in toggle
    verification_sig = '- (NSDictionary *)captureIdentifierVerification:(NSString *)type enabled:(BOOL)enabled secondaryKey:(NSString *)secondaryKey error:(NSError **)error'
    verification = method(manager, verification_sig)
    assert manager.index(verification_sig + ' {') > manager.index('@implementation IdentifierManager')
    assert 'NSDictionary *verification = writeSuccess' in toggle
    assert '[self captureIdentifierVerification:type enabled:enabled secondaryKey:secondaryKey error:&verificationError]' in toggle
    assert 'dictionaryWithContentsOfFile:' not in toggle and 'PXReadSecuritySetting(' not in toggle
    assert verification.count('PXCaptureRuntimeSources(') == 1
    assert verification.index('PXCaptureRuntimeSources(') < verification.index('PXReadRuntimeSourceDictionary(PXTLinkIOSSettingsPath()')
    assert 'PXReadRuntimeSourceDictionary(PXSecuritySettingsPath(), readError)' in verification
    assert 'PXReadSecuritySetting' not in verification and 'NSUserDefaults' not in verification
    assert 'if (secondaryKey)' in verification and 'BOOL secondaryMatches = YES' in verification
    assert 'isKindOfClass:NSNumber.class' in verification and 'isKindOfClass:NSString.class' in verification
    assert 'if (flags && ![flags isKindOfClass:NSDictionary.class])' in verification
    for case in ('independent legacy reads can falsely accept a mixed primary and secondary pair',
                 'paired verification holds capture through both reads and cannot mix source versions',
                 'next verification observes the complete newer pair',
                 'matching verification accepts newer unrelated metadata without requiring the old receipt',
                 'verification never substitutes defaults for a missing canonical secondary key',
                 'primary-only verification does not read security source',
                 'missing secondary cannot verify a requested false value',
                 'missing primary cannot verify a requested false value',
                 'malformed verification container fails with a typed error',
                 'known forward failure skips final verification capture and preserves original error',
                 'failed coherent capture never acknowledges a write and still uses owned compensation'):
        assert case in read('tests/PXRuntimeDeviceGroupWriterTests.m'), case
    assert 'TestCoherentToggleVerification();' in read('tests/PXRuntimeDeviceGroupWriterTests.m')

    assert toggle.index('type = [type copy]') < toggle.index('[self applyIdentifierEnabled:')
    assert toggle.index('NSError *failure = writeError ?: verificationError ?:') < toggle.index('self.settings[type] = previousValue')
    assert toggle.index('[self rollbackIdentifier:') < toggle.index('self.error = failure')
    assert '[self applyIdentifierEnabled:enabled forType:type error:NULL]' in method(manager, '- (void)setIdentifierEnabled:(BOOL)enabled forType:(NSString *)type')
    assert '[self saveSettingsWithSourceCommitIdentifier:&primaryIdentifier forIdentifier:type beforeImage:&capturedImage error:&saveError]' in apply
    assert apply.index('return NO;', apply.index('if (!saved)')) < apply.index('PXWriteSecurityBool')
    assert apply_wrapper.index('type = [type copy]') < apply_wrapper.index('beginIdentifierToggleForType:')
    assert apply.index('validateIdentifierToggle:') < apply.index('self.settings[type] = @(enabled)')
    assert apply.index('[persistedState boolValue] != enabled') < apply.index('PXWriteSecurityBool')
    assert 'if (error) *error = self.error;' in apply and 'return NO;' in apply[apply.index('self.error = secondaryError'):]
    assert save.index('PXPostSettingsChangedNotification()') < save.index('return YES;')
    assert save.count('if (error) *error = self.error;') == 2
    for case in ('matching old primary value never acknowledges a failed forward write',
                 'primary forward failure restores memory without a compensating commit or notification',
                 'verified secondary toggles retain successful enable and disable behavior',
                 'matching old secondary value cannot hide forward failure and rollback retains original error',
                 'toggle success uses local receipt despite stale shared manager error',
                 'failed primary receipt stops secondary writes even when old enabled flag matches',
                 'nested toggle matching old primary rejects acknowledgement and poisons ignored outer staging',
                 'toggle receipt retains readback guard before secondary publication after notification reentry',
                 'toggle freezes mutable caller key before legacy provider callbacks without changing generation policy',
                 'legacy void setter skips existing generation and verified storage retains atomic alias',
                 'invalid toggle keys fail before settings source or notification work'):
        assert case in fixture_settings, case
    assert 'TestIdentifierToggleAcknowledgement();' in fixture_settings
    assert 'BOOL primaryCommitted = NO;' in toggle
    assert 'if (primaryCommitted) {\n            [self rollbackIdentifier:' in toggle
    assert '[self saveSettings]' not in toggle
    assert apply.index('if (primaryCommitted) *primaryCommitted = NO;') < apply.index('validateIdentifierToggle:')
    assert apply.index('if (primaryCommitted) *primaryCommitted = YES;') > apply.index('if (!saved)')
    assert apply.index('if (primaryCommitted) *primaryCommitted = YES;') < apply.index('[persistedState boolValue] != enabled')
    assert 'operation:operation primaryCommitted:NULL sourceCommitIdentifier:NULL beforeImage:NULL error:error' in apply_wrapper

    begin = method(manager, '- (id)beginIdentifierToggleForType:(NSString *)type')
    validate = method(manager, '- (BOOL)validateIdentifierToggle:(id)operation forType:(NSString *)type error:(NSError **)error')
    finish = method(manager, '- (void)finishIdentifierToggle:(id)operation forType:(NSString *)type')
    for body in (begin, validate, finish):
        assert '@synchronized (self)' in body
        for forbidden in ('PXPerform', 'PXPost', 'PXWriteSecurity', 'saveSettings', 'generateIDFA', 'dispatch_'):
            assert forbidden not in body
    assert 'self.identifierToggleOperations[type] = operation' in begin and '[NSObject new]' in begin
    assert 'self.identifierToggleOperations[type] == operation' in validate
    assert 'if (self.identifierToggleOperations[type] == operation)' in finish
    assert 'removeObjectForKey:type' in finish and 'code:6035' in validate
    cleanup = '@finally { [self finishIdentifierToggle:operation forType:type]; }'
    assert cleanup in toggle and cleanup in apply_wrapper
    assert toggle.index('validateIdentifierToggle:') < toggle.index('NSDictionary *verification')
    rollback = method(manager, '- (void)rollbackIdentifier:(NSString *)type previous:(BOOL)previous beforeImage:(NSDictionary *)beforeImage secondaryKey:(NSString *)secondaryKey notificationName:(CFStringRef)notificationName operation:(id)operation sourceCommitIdentifier:(NSString *)identifier')
    assert 'PXPublishSecurityValueForSourceCommit(secondaryKey,' in rollback
    assert 'if (secondaryKey && notificationName && [self validateIdentifierToggle:' in rollback
    assert 'if ([self validateIdentifierToggle:operation forType:type error:NULL]) self.error = failure;' in toggle
    assert apply.count('validateIdentifierToggle:operation') >= 8
    assert 'if (![self validateIdentifierToggle:operation forType:type error:error]) return NO;\n    NSError *saveError = nil;' in apply
    assert apply.index('validateIdentifierToggle:', apply.index('saveSettingsWithError:')) < apply.index('[persistedState boolValue] != enabled')
    assert apply.index('validateIdentifierToggle:', apply.index('BOOL secondaryCommitted =')) < apply.index('CFNotificationCenterPostNotification')
    assert 'return [self validateIdentifierToggle:operation forType:type error:error];' in apply
    for case in ('newer same identifier notification call survives older forward path rollback caches and shared error',
                 'matching ABA values never restore superseded toggle ownership or permit stale secondary publication',
                 'different identifier reentry preserves both successful operations',
                 'provider reentry supersedes older toggle before its settings commit',
                 'secondary return reentry suppresses older failure rollback or obsolete success notification',
                 'successor during rollback keeps newer sources caches error and skips remaining stale effects',
                 'secondary notification successor prevents older verification rollback',
                 'throwing provider releases toggle token without changing legacy exception policy',
                 'throwing void setter observer releases toggle token and preserves later operations',
                 'stale toggle cleanup cannot revoke newer owner token',
                 'toggle token registry removes completed keys',
                 'bare toggle token never retains its manager owner'):
        assert case in fixture_settings, case
    assert 'TestIdentifierToggleReentry();' in fixture_settings
    for case in ('failed primary uses one source attempt without compensation security cache or notification effects',
                 'failed primary preserves exact missing sources instead of creating rollback settings or scope',
                 'uncommitted primary failure never overwrites a later manager or direct writer commit',
                 'primary acknowledgement survives a later secondary failure independently of whole apply result',
                 'primary acknowledgement resets before rejected owner admission'):
        assert case in fixture_settings, case
    assert 'TestToggleFailedPrimaryOwnership();' in fixture_settings
    assert 'if (!identifier || ![tx requireBaseCommitIdentifier:identifier error:error]) return NO;' in rollback
    assert rollback.index('requireBaseCommitIdentifier:') < rollback.index('setDictionary:updated atPath:')
    assert 'PXGlobalScopePath' not in rollback and '[self saveSettings]' not in rollback
    assert 'PXRestoreToggleBeforeImage(updatedFlags, type, beforeImage[@"primary"], error)' in rollback
    assert 'PXRestoreToggleBeforeImage(updatedSecurity, secondaryKey, beforeImage[@"secondary"], error)' in rollback
    assert 'PXRestoreToggleBeforeImage(updated, @"StorageSystemEnabled", beforeImage[@"storage"], error)' in rollback
    assert rollback.index('}, &failure)') < rollback.index('removeAllObjects]') < rollback.index('PXPostSettingsChangedNotification()')
    assert rollback.index('PXPostSettingsChangedNotification()') < rollback.index('PXPublishSecurityValueForSourceCommit')
    assert 'self.settings[type] = observed ?: @(previous)' in rollback
    assert 'PXWriteSecurityBoolWithRollbackAuthority(secondaryKey, enabled, primaryIdentifier' in apply
    assert 'if (secondaryCommitted && sourceCommitIdentifier) *sourceCommitIdentifier = secondaryIdentifier' in apply
    assert save.index('prospectiveCommitIdentifierWithError:') < save.index('}, &sourceError)')
    assert save.index('if (identifier) *identifier = candidate') < save.index('PXPostSettingsChangedNotification()')
    assert 'candidateCommitIdentifier = NSUUID.UUID.UUIDString' in core
    assert 'NSString *identifier = [transaction prospectiveCommitIdentifierWithError:error]' in core
    assert 'baseCommitIdentifier:baseCommit[@"commitID"] ?: @""' in core
    assert core.index('[self recover:error]', core.index('allowNested:(BOOL)')) < core.index('NSDictionary *baseCommit =')


    for case in ('conditional rollback preserves foreign primary ABA and malformed-field successors without stale effects',
                 'secondary rollback authority preserves foreign successor after legacy forward notification',
                 'conditional rollback physical fault restores complete forward tuple marker caches and notifications',
                 'rollback notification successor suppresses obsolete security mirror and topic',
                 'conditional rollback keeps storage alias atomic and never rewrites scope'):
        assert case in fixture_settings, case
    assert 'TestConditionalToggleRollback();' in fixture_settings
    assert 'beforeImage:&beforeImage error:&writeError' in toggle
    assert 'PXCaptureToggleBeforeImage(transaction, existing, type, writeError)' in save
    assert save.index('PXCaptureToggleBeforeImage(') < save.index('setDictionary:saveDict')
    assert save.index('if (beforeImage) *beforeImage = capturedImage;') < save.index('PXPostSettingsChangedNotification()')
    assert 'updatedImage[@"secondaryWritten"] = @YES' in apply
    assert 'beforeImage[@"secondary"][@"present"]' in rollback and 'beforeImage[@"secondaryWritten"]' in rollback
    assert '[beforeImage[@"secondary"][@"present"] boolValue] || [beforeImage[@"secondaryWritten"] boolValue]' in rollback
    assert '![beforeImage[@"secondaryFilePresent"] boolValue] && !updatedSecurity.count' in rollback
    assert 'removeDictionaryAtPath:PXSecuritySettingsPath()' in rollback
    assert 'if (observedMissing) [self.settings removeObjectForKey:type]' in rollback
    assert 'updatedFlags[type] = @(previous)' not in rollback and 'updatedSecurity[secondaryKey] = @(previous)' not in rollback
    capture_image = method(manager, 'static NSDictionary *PXCaptureToggleBeforeImage(PXRuntimeSourceTransaction *tx, NSDictionary *settings, NSString *type, NSError **error)').split('\nstatic BOOL PXRestoreToggleBeforeImage', 1)[0]
    restore_image = method(manager, 'static BOOL PXRestoreToggleBeforeImage(NSMutableDictionary *target, NSString *key, NSDictionary *field, NSError **error)').split('\nstatic NSDictionary *PXSanitizedIdentifierSettings', 1)[0]
    assert 'flags[type] ?: NSNull.null' in capture_image and 'exists:&filePresent' in capture_image
    assert 'image[name] = @{ @"present": @(present), @"value": present ? value : @NO }' in capture_image
    assert 'isKindOfClass:NSNumber.class' in capture_image and 'isKindOfClass:NSString.class' in capture_image
    assert 'else [target removeObjectForKey:key]' in restore_image and 'target[key] = field[@"value"]' in restore_image
    for case in ('compensation restores source scalar types and absence independently of stale memory or divergent secondary',
                 'successful secondary followed by failed readback restores source file presence and removes introduced key and mirror',
                 'storage compensation restores independent alias value type and presence without forcing equality',
                 'malformed canonical before-image rejects before primary staging or publication',
                 'before-image captures source after providers at primary admission',
                 'missing before-image fails closed without using stale memory fallback for source writes'):
        assert case in fixture_settings, case
    assert 'TestToggleAuthoritativeBeforeImages();' in fixture_settings

    for case in ('staged source receipt is exactly the committed marker including legacy admission',
                 'no-op candidate never becomes a committed source receipt',
                 'ignored stale source precondition poisons staged writes despite matching ABA values',
                 'cross-process source commit invalidates stale precondition without writes',
                 'source commit helpers reject wrong thread without poisoning owner',
                 'failed candidate preserves old marker and exact source tuple'):
        assert case in fixture, case
    security = read('common/PXSecuritySettingsStore.m')
    conditional = method(security, 'BOOL PXWriteSecurityBoolWithRollbackAuthority(NSString *key, BOOL value, NSString *expectedIdentifier,\n                                       NSString **rollbackIdentifier, NSError **error)')
    assert conditional.index('baseCommitIdentifierWithError:') < conditional.index('setDictionary:settings')
    assert 'BOOL ownsChain = [base isEqual:expectedIdentifier]' in conditional
    assert 'return !ownsChain || candidate != nil' in conditional
    assert conditional.index('if (rollbackIdentifier) *rollbackIdentifier = candidate') < conditional.index('PXMirrorSecurityUpdates')
    assert 'PXPublishSecurityValueForSourceCommit(key, @(value), YES, identifier)' in method(security, 'BOOL PXPublishSecurityBoolForSourceCommit(NSString *key, BOOL value, NSString *identifier)')
    publisher = method(security, 'BOOL PXPublishSecurityValueForSourceCommit(NSString *key, id value, BOOL updateMirrors, NSString *identifier)')
    assert publisher.index('PXPerformStandaloneRuntimeSourceWrite(current, NULL)') < publisher.index('PXMirrorSecurityUpdates')
    assert publisher.index('PXMirrorSecurityUpdates') < publisher.rindex('PXPerformStandaloneRuntimeSourceWrite(current, NULL)')
    assert 'if (updateMirrors)' in publisher and '[defaults removeObjectForKey:key]' in publisher
    raw_fixture = read('tests/PXRuntimeSecurityWriterTests.m')
    for case in ('absence without forward mirror preserves legacy fallback and source tuple',
                 'committed absence removes all compatibility mirrors without source writes',
                 'raw scalar publication preserves string representation',
                 'removal publisher rechecks marker after mirror reentry'):
        assert case in raw_fixture, case
    assert 'TestRawSecurityPublication();' in raw_fixture

    assert '[transaction dictionaryAtPath:prefsFile error:writeError]' in save
    assert 'setDictionary:saveDict atPath:prefsFile' in save and 'writeToFile:prefsFile' not in save
    load = method(manager, '- (void)loadSettings')
    assert load.index('PXPerformRuntimeSourceWrite') < load.index('fileExistsAtPath:prefsFile')
    assert 'managerSources[@"settings"]' in load and 'managerSources[@"scope"]' in load
    assert 'PXCaptureRuntimeSources' in load
    packet = load.split('managerSources = PXCaptureRuntimeSources(', 1)[1].split('}, &sourceError)', 1)[0]
    assert 'dictionaryWithContentsOfFile:' not in packet
    assert 'PXReadRuntimeSourceDictionary(settingsPath, error)' in packet
    assert 'PXReadRuntimeSourceDictionary(scopedAppsFile, error)' in packet
    assert packet.index('fileExistsAtPath:settingsPath') < packet.index('PXReadRuntimeSourceDictionary(settingsPath')
    assert 'PXValidateManagerSettingsSources(settings, scope, error)' in packet
    assert 'if (!managerSources) { self.error = sourceError; return; }' in load
    validation = 'if (!managerSources && !PXValidateManagerSettingsSources(loadedDict, scopedAppsDict, &sourceError)) { self.error = sourceError; return; }'
    assert validation in load
    assert load.index(validation) < load.index('self.settings = newSettings;') < load.index('self.scopedApps = newScope;')
    assert load.count('self.settings =') == 1 and load.count('self.scopedApps =') == 1
    assert 'for (NSString *bundleID in apps) newScope[bundleID] = [apps[bundleID] mutableCopy];' in load
    validator = manager.split('static BOOL PXValidateManagerSettingsSources(', 1)[1].split('static NSDictionary *PXSanitizedIdentifierSettings', 1)[0]
    for field in ('SettingsInitialized', 'EnabledIdentifiers', 'ScopedApps', 'enabled'):
        assert f'@"{field}"' in validator
    assert 'code:6039' in validator and 'isKindOfClass:NSNumber.class' in validator and 'isKindOfClass:NSString.class' in validator
    assert '![app isKindOfClass:NSDictionary.class]' in validator and '![apps isKindOfClass:NSDictionary.class]' in validator
    assert 'writeToFile' not in validator and 'NSUserDefaults' not in validator
    for case in ('valid manager load preserves scalar compatibility aliases and source bytes without notification',
                 'loaded scope records are independently mutable without modifying source data',
                 'malformed load packet preserves both live dictionaries and source bytes',
                 'null initialization scalar is rejected before boolValue',
                 'malformed manager plist is never converted to an empty successful load',
                 'manager legacy fallback loads without canonical repair or marker writes',
                 'missing optional load fields preserve legacy defaults policy',
                 'absent manager sources retain defaults without materializing files',
                 'RootHide injected load still exits before source access'):
        assert case in fixture_settings, case
    assert 'TestManagerSettingsLoading();' in fixture_settings
    group_recipe = read('scripts/test_runtime_device_group_writers.py')
    assert "SIGNATURES += ['- (void)loadSettings']" in group_recipe
    assert 'static BOOL PXValidateManagerSettingsSources(NSDictionary *settings, NSDictionary *scope, NSError **error)' in group_recipe
    for token in ('nested writer shares staged dictionaries', 'ignored nested failure', 'rollback restores exact prior bytes',
                  'rollback preserves original source permissions', 'validate all journal paths before any recovery writes',
                  'commit marker decides complete new tuple', 'rollback restores absence',
                  'concurrent capture never mixes', 'no lost increments', 'source capture times out',
                  'committed journal does not block revocation', 'transaction rejects cross-thread use',
                  'staged removal reads as absence', 'unapproved removal poisons outer transaction',
                  'removal recovery preserves committed absence', 'malformed source deletion fails before mutation'):
        assert token in fixture, f'native scenario missing: {token}'
    make = read('Makefile').split('WeaponXDaemon_FILES =', 1)[1].splitlines()[0]
    for file in ('common/PXRuntimeSourceStore.m', 'common/PXRuntimeSources.m'):
        assert file in make and file in read('scripts/test_runtime_snapshot_publisher.py'), f'missing transitive link dependency: {file}'
    assert 'test_runtime_source_transactions.py --native' in read('.github/workflows/build-ios-arm.yml')
    print('PASS: Runtime source transaction contracts (partial enrollment; native runtime not implied)')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-source-transactions-') as folder:
        # Compile the exact production role/macro region with its surrounding
        # preprocessor guards preserved. This catches rootful-only declarations
        # before the full UIKit application build. Header annotations are strict.
        check = Path(folder) / 'manager-role.m'
        check.write_text('#import "PXRuntimeSnapshot.h"\n#import "PXRuntimeSourceStore.h"\n#import "PXRuntimeArtifactWriter.h"\n#import "PXRuntimeIdentifierWriter.h"\n#import "PXRuntimeArtifactPreparation.h"\n#import "PXRuntimeScalarPreparation.h"\n'
                         + '#import "PXRuntimeGeneration.h"\n#import "PXRuntimeProfileSelection.h"\n'
                         + manager_role_fragment()
                         + '\nBOOL PXCheckManagerRole(void) { return PXIdentifierManagerIsManagerProcess(); }\n', encoding='utf-8')
        for defines in ([], ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1']):
            subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fsyntax-only',
                            '-Werror=implicit-function-declaration', '-Werror=nullability-completeness',
                            '-I', str(ROOT / 'common'), *defines, str(check)], check=True, cwd=ROOT, timeout=30)
        binary = Path(folder) / 'source-transactions'
        sources = ['common/PXRuntimeSourceStore.m', 'common/PXRuntimeSources.m', 'common/PXRuntimePublisher.m',
                   'common/PXRuntimeSnapshot.m', 'common/PXRuntimeSnapshotReader.m', 'common/PXRuntimeReadScope.m',
                   'common/PXPaths.m', 'common/PXRuntimeIdentifierWriter.m', 'tests/PXRuntimeSourceStoreTests.m']
        subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions',
                        '-DPX_SOURCE_TRANSACTION_TESTING=1', '-Wall', '-Wextra', '-Werror=implicit-function-declaration',
                        '-I', str(ROOT / 'common'), *[str(ROOT / source) for source in sources],
                        '-framework', 'Foundation', '-framework', 'CoreFoundation', '-o', str(binary)],
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
