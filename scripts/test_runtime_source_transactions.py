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
    assert manifest['schemaVersion'] == 1 and manifest['rollout'] == '4C.2H5C-partial'
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
    assert '[self saveSettingsWithSourceCommitIdentifier:NULL error:error]' in method(manager, '- (BOOL)saveSettingsWithError:(NSError **)error')
    save = method(manager, '- (BOOL)saveSettingsWithSourceCommitIdentifier:(NSString **)identifier error:(NSError **)error')
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
    apply = method(manager, '- (BOOL)applyIdentifierEnabled:(BOOL)enabled forType:(NSString *)type operation:(id)operation primaryCommitted:(BOOL *)primaryCommitted sourceCommitIdentifier:(NSString **)sourceCommitIdentifier error:(NSError **)error')
    assert 'BOOL writeSuccess = [self applyIdentifierEnabled:enabled forType:type operation:operation primaryCommitted:&primaryCommitted sourceCommitIdentifier:&sourceIdentifier error:&writeError]' in toggle
    assert 'if (writeSuccess && primarySuccess && secondarySuccess) return YES;' in toggle
    assert toggle.index('type = [type copy]') < toggle.index('[self applyIdentifierEnabled:')
    assert toggle.index('NSError *failure = writeError ?:') < toggle.index('self.settings[type] = @(previous)')
    assert toggle.index('[self rollbackIdentifier:') < toggle.index('self.error = failure')
    assert '[self applyIdentifierEnabled:enabled forType:type error:NULL]' in method(manager, '- (void)setIdentifierEnabled:(BOOL)enabled forType:(NSString *)type')
    assert '[self saveSettingsWithSourceCommitIdentifier:&primaryIdentifier error:&saveError]' in apply
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
    assert 'operation:operation primaryCommitted:NULL sourceCommitIdentifier:NULL error:error' in apply_wrapper

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
    assert toggle.index('validateIdentifierToggle:') < toggle.index('NSDictionary *persistedSettings')
    rollback = method(manager, '- (void)rollbackIdentifier:(NSString *)type previous:(BOOL)previous secondaryKey:(NSString *)secondaryKey notificationName:(CFStringRef)notificationName operation:(id)operation sourceCommitIdentifier:(NSString *)identifier')
    assert 'PXPublishSecurityBoolForSourceCommit(secondaryKey, previous, rollbackIdentifier)' in rollback
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
    assert 'updatedFlags[type] = @(previous)' in rollback and 'updatedSecurity[secondaryKey] = @(previous)' in rollback
    assert 'updated[@"StorageSystemEnabled"] = @(previous)' in rollback
    assert rollback.index('}, &failure)') < rollback.index('removeAllObjects]') < rollback.index('PXPostSettingsChangedNotification()')
    assert rollback.index('PXPostSettingsChangedNotification()') < rollback.index('PXPublishSecurityBoolForSourceCommit')
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
    publisher = method(security, 'BOOL PXPublishSecurityBoolForSourceCommit(NSString *key, BOOL value, NSString *identifier)')
    assert publisher.index('PXPerformStandaloneRuntimeSourceWrite(current, NULL)') < publisher.index('PXMirrorSecurityUpdates')
    assert publisher.index('PXMirrorSecurityUpdates') < publisher.rindex('PXPerformStandaloneRuntimeSourceWrite(current, NULL)')
    assert '[transaction dictionaryAtPath:prefsFile error:writeError]' in save
    assert 'setDictionary:saveDict atPath:prefsFile' in save and 'writeToFile:prefsFile' not in save
    load = method(manager, '- (void)loadSettings')
    assert load.index('PXPerformRuntimeSourceWrite') < load.index('fileExistsAtPath:prefsFile')
    assert 'managerSources[@"settings"]' in load and 'managerSources[@"scope"]' in load
    assert 'PXCaptureRuntimeSources' in load
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
