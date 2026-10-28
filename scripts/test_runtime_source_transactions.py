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
    assert manifest['schemaVersion'] == 1 and manifest['rollout'] == '4C.2H4P-partial'
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
    save = method(manager, '- (void)saveSettings')
    scope = method(manager, '- (void)saveScopedApps')
    for body in (save, scope):
        assert 'PXPerformRuntimeSourceWrite' in body and 'atPath:scopedAppsFile' in body
        assert 'writeToFile:scopedAppsFile' not in body
        assert body.index('}, &sourceError)') < body.index('PXPostSettingsChangedNotification()')
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
