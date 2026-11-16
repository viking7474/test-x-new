#!/usr/bin/env python3
"""Log-once registry and diagnostic sinks; native Foundation requires macOS."""
from pathlib import Path
import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from test_runtime_identifier_writers import method
from test_profile_creation_flow import check_macro_arity
ROOT = Path(__file__).resolve().parents[1]
CASES = ['normal', 'path-fault', 'regex-fault', 'db-formatter-fault']


def source_contracts(registry=None, logger=None, db=None):
    r = (ROOT/'common/PXRuntimeUtilities.m').read_text(encoding='utf-8') if registry is None else registry
    s = (ROOT/'common/TLinkIOSLogging.m').read_text(encoding='utf-8') if logger is None else logger
    d = (ROOT/'common/DBDebugLogger.m').read_text(encoding='utf-8') if db is None else db
    assert 'PXLogOnceCompositeKey' not in r and 'stringWithFormat:' not in r and 'hasPrefix:' not in r
    assert 'NSDictionary<NSString *, NSSet<NSString *> *> *gPXLogOnceClaims' in r
    pub = method(r,'static BOOL PXLogOncePublish(NSDictionary *basis, NSDictionary *candidate)')
    assert '__attribute__((objc_precise_lifetime)) NSDictionary *retired = nil;' in pub
    locked = pub.split('os_unfair_lock_lock',1)[1].split('os_unfair_lock_unlock',1)[0]
    assert 'gPXLogOnceClaims == basis' in locked and '[' not in locked
    assert 'retired = gPXLogOnceClaims; gPXLogOnceClaims = candidate;' in locked
    assert pub.rindex('retired = nil;') > pub.index('os_unfair_lock_unlock')
    for sig in ['BOOL PXLogOnceClaim(NSString *namespaceName, NSString *key)','void PXLogOnceResetNamespace(NSString *namespaceName)']:
        b = method(r,sig);assert 'gPXLogOncePreparing = previous;' in b and 'PXLogOncePublish(basis, candidate)' in b
        assert b.index('gPXLogOncePreparing = YES;') < b.index('[namespaceName isKindOfClass:NSString.class]')
        assert '[[NSString alloc] initWithString:namespaceName]' in b and '@finally' in b
    assert '[basis[space] containsObject:frozenKey]' in r and '[namespaces removeObjectForKey:space]' in r
    entry = method(s,'void PXLog(NSString *format, ...)')
    assert entry.index('gPXInsideDiagnosticLog = YES;') < entry.index('[format isKindOfClass:NSString.class]')
    assert '@finally { va_end(args); }' in entry and 'gPXInsideDiagnosticLog = previous;' in entry
    assert '"%{private}@"' in entry and 'if (PXFileLoggingEnabled()) PXAppendToLogFile(redacted);' in entry
    write = method(s,'static void PXWriteQueuedLog(NSString *message)')
    assert write.index('gPXInsideDiagnosticLog = YES;') < write.index('!message.length')
    assert '@catch' in write and '@finally' in write and '[handle closeFile]' in write
    assert 'gPXInsideDiagnosticLog = previous;' in write and 'handle = nil;message = nil;' in write
    assert '[NSDateFormatter new]' in write and 'PXLogFileMaxBytes' in write
    queue = method(s,'static void PXAppendToLogFile(NSString *message)')
    assert queue.index('{ job = ^{') < queue.index('dispatch_async(') and 'message = nil;job = nil;' in queue
    redact = method(s,'static NSString *PXRedactSensitiveValues(NSString *message)')
    assert 'if (!ipv4Regex || !uuidRegex) return nil;' in redact and '@catch' in redact
    assert '<redacted-ip>' in redact and '<redacted-id>' in redact and 'message = nil;redacted = nil;' in redact
    error = method(s,'void PXLogError(NSError *error, NSString *context)')
    assert 'gPXInsideErrorLog = previous;' in error and '@catch' in error and '[defaults synchronize]' in error
    dbentry = method(d,'void PXDBLog(NSString *format, ...)')
    assert dbentry.index('gPXInsideDBLog = YES;') < dbentry.index('[format isKindOfClass:NSString.class]')
    assert '@finally { va_end(args); }' in dbentry and 'if (!handle) return;' in dbentry
    assert 'fileLock = PXDBFileLock();if (!fileLock) return;' in dbentry and '@synchronized(fileLock)' in dbentry
    assert '[handle closeFile]' in dbentry and 'gPXInsideDBLog = previous;' in dbentry
    assert 'dispatch_async' not in d and 'synchronize]' not in d
    for filename in ['PXLogOnceRegistryTests.m','PXDiagnosticSinkTests.m']:
        check_macro_arity((ROOT/'tests'/filename).read_text(encoding='utf-8'),'logging')
    assert 'scripts/test_logging_boundaries.py --native' in (ROOT/'.github/workflows/build-ios-arm.yml').read_text()
    assert 'scripts/test_logging_boundaries.py' in (ROOT/'scripts/release_hardening.py').read_text()
    print('PASS: Log-once and primary/DB diagnostic source contracts (native sinks not implied)')


def generate_fragments(folder):
    s = (ROOT/'common/TLinkIOSLogging.m').read_text(encoding='utf-8')
    s = s[s.index('static const unsigned long long'):]
    s = s.replace('[NSUserDefaults standardUserDefaults]','PXFixtureDefaults()').replace('[NSFileManager defaultManager]','PXFixtureFiles()')
    s = s.replace('NSTemporaryDirectory()','PXFixtureTemp()')
    for index,path in enumerate(['/var/mobile/Library/Logs/TLinkIOS','/private/var/mobile/Library/Logs/TLinkIOS','/var/LIB/var/mobile/Library/Logs/TLinkIOS']):
        s = s.replace('@"'+path+'"',f'PXFixtureDirectory(YES,{index})')
    s = s.replace('[NSFileHandle fileHandleForWritingAtPath:path]','PXFixtureOpen(path)')
    s = re.sub(r'\[NSRegularExpression regularExpressionWithPattern:(@"(?:\\.|[^"\\])*") options:0 error:NULL\]',r'PXFixtureRegex(\1)',s)
    s = s.replace('os_log_with_type(PXLogObject(),OS_LOG_TYPE_DEFAULT,"%{private}@",redacted)','PXFixtureEmit(redacted)')
    s = s.replace('dispatch_async(PXLogFileQueue(),job)','PXFixtureSchedule(job)')
    (folder/'PXPrimaryLogging.inc').write_text(s,encoding='utf-8')
    d = (ROOT/'common/DBDebugLogger.m').read_text(encoding='utf-8')
    d = d[d.index('static __thread BOOL'):]
    d = d.replace('[NSFileManager defaultManager]','PXFixtureFiles()').replace('NSTemporaryDirectory()','PXFixtureTemp()')
    d = d.replace('[NSFileHandle fileHandleForWritingAtPath:path]','PXFixtureOpen(path)')
    for index,path in enumerate(['/var/mobile/Library/WeaponX/Logs','/private/var/mobile/Library/WeaponX/Logs']):
        d = d.replace('@"'+path+'"',f'PXFixtureDirectory(NO,{index})')
    d = d.replace('[NSDateFormatter new]','PXFixtureDBFormatter()')
    (folder/'PXDBLogging.inc').write_text(d,encoding='utf-8')


def native_tests():
    assert sys.platform=='darwin' and shutil.which('xcrun'),'--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-logging-') as tmp:
        folder=Path(tmp);generate_fragments(folder)
        for scheme,defines in [('rootful',[]),('roothide',['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])]:
            for mode,flag in [('plain-arc','-fno-objc-arc-exceptions'),('arc-eh','-fobjc-arc-exceptions')]:
                for fixture in ['PXLogOnceRegistryTests.m','PXDiagnosticSinkTests.m']:
                    binary=folder/(fixture+'-'+scheme+'-'+mode)
                    subprocess.run(['xcrun','clang','-O0','-fobjc-arc','-fblocks','-fexceptions','-fobjc-exceptions',flag,
                                    '-Wall','-Wextra','-Werror=implicit-function-declaration','-I',str(ROOT/'common'),'-I',str(folder),*defines,
                                    str(ROOT/'tests'/fixture),'-framework','Foundation','-o',str(binary)],cwd=ROOT,check=True,timeout=60)
                    for case in CASES if fixture=='PXDiagnosticSinkTests.m' else ['registry']:
                        print('Logging native matrix:',scheme,mode,fixture,case,flush=True)
                        subprocess.run([str(binary),case],cwd=ROOT,check=True,timeout=90)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--native',action='store_true');args=parser.parse_args()
    source_contracts()
    if args.native:native_tests()
