#!/usr/bin/env python3
"""Transactional security/canvas writers; defaults authority deliberately partial."""
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
spec = importlib.util.spec_from_file_location('identifier', ROOT / 'scripts/test_runtime_identifier_writers.py')
identifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(identifier)
METHODS = ['- (BOOL)setCanvasFingerprintProtection:(BOOL)enabled', '- (BOOL)resetCanvasNoiseAndPersist']
DETAIL = '- (BOOL)persistCanvasValues:(NSDictionary<NSString *, id> *)values'


def source_contracts():
    store = read('common/PXSecuritySettingsStore.m')
    assert 'PXPerformStandaloneRuntimeSourceWrite' in store and '[tx dictionaryAtPath:path error:writeError]' in store
    assert 'if (!existing) return NO;' in store and 'NSPropertyListImmutable' in store
    assert store.index('if (!committed) return NO;') < store.index('PXMirrorSecurityUpdates(updates);')
    for forbidden in ('flock(', 'open(', 'writeToFile:', 'NSDataWritingAtomic'):
        assert forbidden not in store, forbidden
    assert 'value == UINT32_MAX ? 1 : value + 1' in store
    assert 'if (committed && committedValue) *committedValue = next;' in store
    assert 'respondsToSelector:@selector(unsignedIntValue)' in store
    core = read('common/PXRuntimeSourceStore.m')
    assert 'allowNested:YES' in core and 'allowNested:NO' in core
    assert 'if (!allowNested)' in core and '_activeTransaction.failure = PXSourceError(@"Standalone source write' in core
    assert 'performStandaloneWrite:body error:error' in read('common/PXRuntimeSources.m')
    for signature in METHODS:
        body = identifier.method(read('common/IdentifierManager.m'), signature)
        assert 'writeToFile:' not in body and 'NSUserDefaults' not in body
    toggle = identifier.method(read('common/IdentifierManager.m'), METHODS[0])
    assert 'PXWriteSecuritySettings' in toggle and '@"canvasFingerprintingEnabled"' in toggle and '@"CanvasFingerprint"' in toggle
    nonce = identifier.method(read('common/IdentifierManager.m'), METHODS[1])
    assert 'PXAdvanceSecurityNonce' in nonce
    assert nonce.index('return NO;') < nonce.index('CFNotificationCenterPostNotification')
    detail = identifier.method(read('CanvasDetailViewController.m'), DETAIL)
    assert 'PXWriteSecuritySettings(values, &error)' in detail and 'writeToFile:' not in detail and 'synchronize' not in detail
    assert detail.index('return NO;') < detail.index('PXPostSettingsChangedNotification()')
    fixture = read('tests/PXRuntimeSecurityWriterTests.m')
    assert fixture.index('#define NSUserDefaults PXFixtureDefaults') < fixture.index('#include "../common/PXSecuritySettingsStore.m"')
    for case in ('empty security packet is a no-op without source or compatibility effects',
                 'invalid security keys values and payloads fail before source entry',
                 'security packet freezes caller graph before staging and mirrors same committed values',
                 'security callback reentry cannot deadlock source gate',
                 'mirror exception cannot negate committed source or suppress other suites',
                 'nested security rejection poisons outer staging and emits no mirror',
                 'capture reentry preserves source and compatibility state',
                 'security commit failure restores source bytes token nonce output and suppresses mirrors',
                 'malformed security dictionary is preserved instead of replaced with empty defaults',
                 'concurrent security nonce updates have no duplicates or lost increments',
                 'canvas protection aliases commit together before notification',
                 'failed canvas alias detail and nonce writes preserve all bytes and emit no success callbacks'):
        assert case in fixture, case
    manifest = json.loads(read('docs/audit-implementation/runtime-source-writers.json'))
    assert manifest['rollout'] == '4C.2H3O-partial'
    for name in ('security-store', 'security-direct'):
        assert manifest['writers'][name]['status'] == 'partial'
    assert manifest['writers']['preferences-daemon']['status'] == 'external'
    assert manifest['sources'][4]['field'] == 'securitySettings' and manifest['sources'][4]['status'] == 'partial'
    assert 'test_runtime_security_writers.py --native' in read('.github/workflows/build-ios-arm.yml')
    assert 'test_runtime_security_writers.py' in read('scripts/release_hardening.py')
    print('PASS: Security/canvas source contracts (defaults authority and remaining writers partial; native runtime not implied)')


def generate_native_fragments(folder):
    source = read('common/IdentifierManager.m')
    (folder / 'PXCanvasManagerMethods.inc').write_text('\n\n'.join(identifier.method(source, method) for method in METHODS), encoding='utf-8')
    (folder / 'PXCanvasDetailMethod.inc').write_text(identifier.method(read('CanvasDetailViewController.m'), DETAIL), encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-security-writers-') as temp:
        folder = Path(temp)
        generate_native_fragments(folder)
        sources = ['common/PXRuntimeSourceStore.m', 'common/PXRuntimePublisher.m', 'tests/PXRuntimeSecurityWriterTests.m']
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            binary = folder / scheme
            subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions',
                            '-DPX_SOURCE_TRANSACTION_TESTING=1', '-Wall', '-Wextra', '-Werror=implicit-function-declaration',
                            '-I', str(ROOT / 'common'), '-I', str(folder), *defines,
                            *[str(ROOT / source) for source in sources], '-framework', 'Foundation', '-framework', 'CoreFoundation',
                            '-o', str(binary)], cwd=ROOT, check=True, timeout=60)
            for _ in range(3):
                subprocess.run([str(binary)], cwd=ROOT, check=True, timeout=90)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        native_tests()
