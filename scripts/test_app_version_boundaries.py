#!/usr/bin/env python3
"""App-version source/cache, NSBundle and borrowed CF boundaries."""
from pathlib import Path
import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from test_runtime_identifier_writers import method
from test_profile_creation_flow import check_macro_arity
ROOT=Path(__file__).resolve().parents[1]
HOOK=ROOT/'TLinkIOSTweak/AppVersionHooks.x'
NS=['- (NSDictionary *)infoDictionary','- (NSDictionary *)localizedInfoDictionary']
CF=['static CFDictionaryRef replaced_CFBundleGetInfoDictionary(CFBundleRef bundle)',
    'static CFDictionaryRef replaced_CFBundleGetLocalInfoDictionary(CFBundleRef bundle)']


def source_contracts(source=None):
    s=HOOK.read_text(encoding='utf-8') if source is None else source
    assert 'gAppVersionCacheGeneration' not in s and 'PXReleaseCFInfoDictCacheEntry' not in s
    publish=method(s,'static BOOL PXAppVersionPublish(NSDictionary *basis, NSDictionary *candidate)')
    held=publish.split('os_unfair_lock_lock',1)[1].split('os_unfair_lock_unlock',1)[0]
    assert '[' not in held and 'gAppVersionState == basis' in held and 'objc_precise_lifetime' in publish
    assert publish.rindex('retired = nil;') > publish.index('os_unfair_lock_unlock')
    invalidation=method(s,'void PXAppVersionHooksInvalidateCache(void)')
    assert 'gAppVersionBorrowedDictionaries' not in invalidation
    assert '[NSObject new]' in invalidation and 'PXInvalidateScopeDecisionCache();' in invalidation
    load=method(s,'static NSDictionary *PXAppVersionLoadPath(NSString *path, id epoch)')
    assert 'if (state[@"epoch"] != epoch) return nil;' in load
    assert 'before && saved && [before isEqualToDate:saved]' in load
    assert 'PXAppVersionEpochCurrent(epoch)' in load and 'before && after && [before isEqualToDate:after]' in load
    store=method(s,'static BOOL PXAppVersionStore(id epoch, NSString *section, id key, NSDictionary *entry)')
    assert 'if (basis[@"epoch"] != epoch) return NO;' in store and 'PXAppVersionPublish(basis,candidate)' in store
    query=method(s,'BOOL PXGetSpoofedAppVersionForBundle(NSString *bundleID, NSString **outVersion, NSString **outBuild)')
    assert query.index('gPXAppVersionReading = YES;') < query.index('[bundleID isKindOfClass:NSString.class]')
    assert 'gPXAppVersionReading = previous;' in query and '@catch' in query and 'field = nil;' in query
    assert 'PXAppVersionScalar(flag)' in query and 'if (!PXAppVersionEpochCurrent(epoch)) return NO;' in query
    intern=method(s,'static NSDictionary *PXInternAppVersionDictionary(NSDictionary *value)')
    assert 'gPXAppVersionInterning = previous;' in intern and 'objc_precise_lifetime' in intern
    assert '[working addObject:frozen]' in intern and 'gAppVersionBorrowedDictionaries == basis' in intern
    project=method(s,'static NSDictionary *PXAppVersionProjectInfo(NSBundle *bundle, CFBundleRef cfBundle, NSDictionary *original, BOOL localized, BOOL cf)')
    assert all(token in project for token in ['cached[@"version"]','cached[@"build"]','cached[@"base"]','isEqualToDictionary:original','PXInternAppVersionDictionary(result)'])
    assert 'PXAppVersionEpochCurrent(epoch) ? result : original' in project
    for sig in NS:
        b=method(s,sig)
        assert 'objc_precise_lifetime' in b and 'if (entered) gPXAppVersionInfoRecursion--;' in b
        assert b.count('%orig')==2 and b.index('original = %orig;') < b.index('@catch')
        assert 'original = nil;result = nil;' in b and '@finally' in b
    for sig in CF:
        b=method(s,sig)
        assert 'if (retainedOriginal) CFRelease(original)' in b and 'if (retainedBundle) CFRelease(bundle)' in b
        assert 'if (entered) gPXAppVersionInfoRecursion--;' in b and b.index('original = original_CF') < b.index('@catch')
        assert 'CFRetain(original)' in b
    helper=(ROOT/'common/PXP1BFilters.m').read_text(encoding='utf-8')
    assert 'original = nil;version = nil;build = nil;mutable = nil;' in helper
    check_macro_arity((ROOT/'tests/PXAppVersionBoundaryTests.m').read_text(encoding='utf-8'),'app-version')
    assert 'scripts/test_app_version_boundaries.py --native' in (ROOT/'.github/workflows/build-ios-arm.yml').read_text()
    assert 'scripts/test_app_version_boundaries.py' in (ROOT/'scripts/release_hardening.py').read_text()
    print('PASS: App-version epoch, projection and borrowed lifetime source contracts (native behavior not implied)')


def generate_fragment(folder):
    s=HOOK.read_text(encoding='utf-8')
    head=s[:s.index('%group AppVersionFullDictionary')]
    head=re.sub(r'^#import[^\n]*\n','',head,flags=re.M)
    funcs=[head]
    for index,sig in enumerate(NS):
        b=method(s,sig);body=b[b.index('{'):].replace('%orig',f'PXNativeNS(self,{index})')
        funcs.append(f'static NSDictionary *PXHookNS{index}(__unsafe_unretained NSBundle *self) '+body)
    funcs.extend(method(s,sig) for sig in CF)
    result='\n\n'.join(funcs).replace('[NSFileManager defaultManager]','PXFixtureFiles()')
    result=result.replace('[NSDictionary dictionaryWithContentsOfFile:path]','PXFixtureRead(path)')
    result=result.replace('PXAppVersionApplyToInfoDictionary(original,version,build)','PXFixtureApply(original,version,build)')
    (folder/'PXAppVersionBoundaries.inc').write_text(result,encoding='utf-8')


def native_tests():
    assert sys.platform=='darwin' and shutil.which('xcrun'),'--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-app-version-') as tmp:
        folder=Path(tmp);generate_fragment(folder)
        for scheme,defines in [('rootful',[]),('roothide',['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])]:
            for mode,flag in [('plain-arc','-fno-objc-arc-exceptions'),('arc-eh','-fobjc-arc-exceptions')]:
                binary=folder/(scheme+'-'+mode)
                subprocess.run(['xcrun','clang','-O0','-fobjc-arc','-fblocks','-fexceptions','-fobjc-exceptions',flag,
                                '-Wall','-Wextra','-Werror=implicit-function-declaration','-I',str(ROOT/'common'),'-I',str(ROOT/'TLinkIOSTweak'),'-I',str(folder),
                                *defines,str(ROOT/'common/PXP1BFilters.m'),str(ROOT/'tests/PXAppVersionBoundaryTests.m'),
                                '-framework','Foundation','-framework','CoreFoundation','-o',str(binary)],cwd=ROOT,check=True,timeout=60)
                print('App-version native matrix:',scheme,mode,flush=True)
                subprocess.run([str(binary)],cwd=ROOT,check=True,timeout=90)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--native',action='store_true');args=parser.parse_args()
    source_contracts()
    if args.native:native_tests()
