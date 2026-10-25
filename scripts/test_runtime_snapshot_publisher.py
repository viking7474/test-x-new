#!/usr/bin/env python3
"""Publication wiring; --native tests the real serial engine, flock and file IPC."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text(encoding="utf-8")


def source_contracts():
    publisher = read("common/PXRuntimePublisher.m")
    runtime = read("common/PXRuntimeSnapshot.m")
    daemon = read("WeaponXMountDaemon/WeaponXDaemon.m")
    fixture = read("tests/PXRuntimePublisherTests.m")
    for token in ("DISPATCH_QUEUE_SERIAL", "DISPATCH_SOURCE_TYPE_DATA_OR", "flock(fd, LOCK_EX | LOCK_NB)",
                  "O_CLOEXEC | O_NOFOLLOW", "st.st_nlink != 1", "_epoch = NSUUID.UUID.UUIDString", "++_revision",
                  "UINT64_MAX", 'candidate[@"schemaVersion"] = @2', "NSPropertyListImmutable"):
        assert token in publisher, f"publisher ownership/identity contract missing: {token}"
    assert 'unlink(' not in publisher.split("- (BOOL)acquireOnQueue:", 1)[1].split("- (BOOL)tryAcquireOwnership:", 1)[0]
    atomic = publisher.split("BOOL PXRuntimeWritePropertyList", 1)[1].split("@interface", 1)[0]
    for token in ("mkstemp(temporary)", "fchown(fd", "fchmod(fd", "errno == EINTR", "remaining -=", "rename(temporary,", "unlink(temporary)"):
        assert token in atomic, f"atomic writer missing: {token}"
    assert atomic.index("fchmod(fd") < atomic.index("rename(temporary,")
    assert publisher.index("_writer(snapshot, &error)") < publisher.index("return [self distribute:snapshot]")
    assert 'BOOL success = complete && notified' in publisher and '_pendingSnapshot = success ? nil : snapshot' in publisher
    assert 'NSDictionary *retry = _pendingSnapshot' in publisher and '[self distribute:retry]' in publisher
    assert '_pendingSnapshot = nil; _needsPublication = NO' in publisher
    assert '1u << _retryCount' in publisher and 'CLOCK_MONOTONIC' in publisher
    assert 'NSTimer' not in publisher and 'DISPATCH_SOURCE_TYPE_TIMER' not in publisher
    assert 'requestID' in publisher and '.request.plist' in publisher and '.ack.plist' in publisher
    assert 'Timed out waiting for publisher acknowledgement' in publisher and 'MIN(timeout, 30.0)' in publisher
    assert '[self onQueue]' in publisher and 'Reentrant publication rejected' in publisher
    assert 'PXPublishRuntimeSnapshot(' not in runtime + daemon, "unowned publishing entry point must be retired"
    assert 'PXCreateRuntimeSnapshotPublisher' in runtime + daemon
    assert 'PXRuntimeSnapshotLastPublishStats' not in runtime + daemon
    record = daemon.split('- (void)recordRuntimePublication:(NSDictionary *)result {', 1)[1].split('- (void)recordBootstrapDecisionSignal', 1)[0]
    assert 'PXLoadRuntimeSnapshot' not in record and 'result[@"stats"]' in record
    assert 'tryAcquireOwnership:&publisherError' in daemon and 'syncOnceWithTimeout:10.0' in daemon
    assert 'return [result[@"success"] boolValue] ? 0 : 1' in daemon
    mirror = runtime.split('static NSDictionary *PXMirrorRuntimeSnapshotIntoScopedContainers', 1)[1].split('#endif', 1)[0]
    assert 'scanError' in mirror and 'stale-mirror-removal-failed' in mirror
    assert '@"complete": @(failures.count == 0 && missing.count == 0)' in mirror
    assert 'removeItemAtPath:existingMirrorPath error:&revocationError' in mirror, "stale removal policy must report errors"
    assert 'PXRuntimeReadSnapshot *view' in runtime, "compatibility loader must validate schema 1 and schema 2"
    postinst = read('DEBIAN/postinst')
    assert postinst.index('launchctl bootout system/com.hydra.weaponx.guardian') < postinst.index('WeaponXDaemon" --sync-once')
    assert 'common/PXRuntimePublisher.m' in read('Makefile').split('WeaponXDaemon_FILES =', 1)[1].splitlines()[0]
    for token in ('production reader accepts published identity', 'serialized global mirror identity ordering',
                  'failed revision never reused', 'retry uses exact committed snapshot', 'new publication supersedes old retry',
                  'notification burst coalesced', 'two CLI clients receive acknowledgements',
                  'process exit releases ownership', 'unacknowledged sync times out', 'same-queue reentry fails'):
        assert token in fixture, f"native scenario missing: {token}"
    assert 'test_runtime_snapshot_publisher.py --native' in read('.github/workflows/build-ios-arm.yml')
    print('PASS: Runtime publisher source contracts (native runtime not implied)')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-runtime-publisher-') as folder:
        binary = Path(folder) / 'publisher-tests'
        # Link production adapters as well as the exercised engine, so missing
        # transitive sources cannot hide behind a fixture-only implementation.
        sources = ['common/PXRuntimePublisher.m', 'common/PXRuntimeSnapshot.m',
                   'common/PXRuntimeSnapshotReader.m', 'common/PXRuntimeReadScope.m',
                   'common/PXPaths.m', 'common/PXRuntimeSourceStore.m', 'common/PXRuntimeSources.m',
                   'tests/PXRuntimePublisherTests.m']
        subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions',
                        '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(ROOT / 'common'),
                        *[str(ROOT / source) for source in sources], '-framework', 'Foundation',
                        '-framework', 'CoreFoundation', '-o', str(binary)], check=True, cwd=ROOT, timeout=60)
        for _ in range(3):
            subprocess.run([str(binary)], check=True, cwd=ROOT, timeout=60)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--native', action='store_true')
    args = parser.parse_args()
    source_contracts()
    if args.native:
        native_tests()
