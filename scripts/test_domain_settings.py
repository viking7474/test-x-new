#!/usr/bin/env python3
"""Domain matcher/persistence packets. Native Foundation requires macOS."""
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


def source_contracts(source=None):
    s = (ROOT/'common/DomainBlockingSettings.m').read_text(encoding='utf-8') if source is None else source
    query = method(s, '- (BOOL)isDomainBlocked:(NSString *)domain')
    assert query.count('[self capturedPolicy]') == 1
    assert 'if (!policy.enabled) return NO;' in query
    assert '@synchronized' not in query and 'writePolicy' not in query and 'loadSettings' not in query
    assert 'lowercaseString' not in query and 'stringByAppendingString' not in query
    assert '[policy.normalized containsObject:host]' in query and '[host hasSuffix:suffix]' in query
    assert 'gPXDomainMatching = previous;' in query
    assert query.index('gPXDomainMatching = YES;') < query.index('[domain isKindOfClass:NSString.class]')
    norm = method(s,'static NSString *PXDomainNormalized(NSString *domain)')
    assert 'lowercaseString' in norm and 'substringToIndex:lower.length-1' in norm
    publish = method(s,'- (void)publishPolicy:(PXDomainPolicy *)policy')
    assert 'objc_precise_lifetime' in publish
    held = publish.split('os_unfair_lock_lock',1)[1].split('os_unfair_lock_unlock',1)[0]
    assert '[' not in held and 'retired = _policy;_policy = policy;' in held
    assert publish.index('retired = nil;policy = nil;') > publish.index('os_unfair_lock_unlock')
    for signature in ['- (BOOL)changeDomain:(NSString *)domain replacement:(NSString *)replacement operation:(PXDomainEdit)operation enabled:(BOOL)enabled', '- (BOOL)setEnabledAndSave:(BOOL)enabled', '- (BOOL)loadSettings']:
        body = method(s, signature)
        assert '@synchronized (self)' in body and '_changing = previous;' in body
        assert 'if (previous) return NO;_changing = YES;' in body
        assert body.index('[self writePolicy:candidate]') < body.index('[self publishPolicy:candidate]')
    load = method(s, '- (BOOL)loadSettings')
    assert 'if (PXDomainPathPresent(files,path)) return NO;' in load
    assert 'if (statuses && ![statuses isKindOfClass:NSDictionary.class]) return NO;' in load
    assert 'if (flag && !PXDomainScalar(flag)) return NO;' in load
    assert 'if (migration && ![self writePolicy:candidate]) return NO;' in load
    assert 'NSFileReadNoSuchFileError' in s and 'NSPOSIXErrorDomain' in s
    assert 'NSLog(' not in s and 'addEntriesFromDictionary:' not in s
    assert 'return [policy.domains mutableCopy]' in s
    assert 'gPXDomainCreating = previous;' in s
    ui = (ROOT/'SecurityTabViewController.m').read_text(encoding='utf-8')
    toggle = method(ui,'- (void)domainBlockingToggleChanged:(UISwitch *)sender')
    assert 'if (![settings setEnabledAndSave:sender.isOn])' in toggle and 'settings.isEnabled =' not in toggle
    assert toggle.index('setEnabledAndSave:') < toggle.index('CFNotificationCenterPostNotification')
    assert 'scripts/test_domain_settings.py --native' in (ROOT/'.github/workflows/build-ios-arm.yml').read_text()
    assert 'scripts/test_domain_settings.py' in (ROOT/'scripts/release_hardening.py').read_text()
    check_macro_arity((ROOT/'tests/PXDomainSettingsTests.m').read_text(encoding='utf-8'),'domain-settings')
    print('PASS: Domain matcher and save-before-publication source contracts (native/device behavior not implied)')


def generate_fragment(folder):
    source = (ROOT/'common/DomainBlockingSettings.m').read_text(encoding='utf-8')
    for name, index in [('kDomainBlockingSettingsFile',0),('kDomainBlockingSettingsFileAlt1',1),('kDomainBlockingSettingsFileAlt2',2)]:
        source, count = re.subn(r'static NSString \*const '+name+r' = @"[^"\n]+";',f'#define {name} PXFixturePath({index})',source)
        assert count == 1
    source = source.replace('[NSFileManager defaultManager]','PXFixtureFiles()')
    (folder/'PXDomainSettings.inc').write_text(source,encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'),'--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-domain-settings-') as tmp:
        folder=Path(tmp);generate_fragment(folder)
        for scheme, defines in [('rootful',[]),('roothide',['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])]:
            for mode, flag in [('plain-arc','-fno-objc-arc-exceptions'),('arc-eh','-fobjc-arc-exceptions')]:
                binary=folder/(scheme+'-'+mode)
                subprocess.run(['xcrun','clang','-O0','-fobjc-arc','-fblocks','-fexceptions','-fobjc-exceptions',flag,
                                '-Wall','-Wextra','-Werror=implicit-function-declaration','-I',str(ROOT/'common'),'-I',str(folder),*defines,
                                str(ROOT/'tests/PXDomainSettingsTests.m'),'-framework','Foundation','-o',str(binary)],cwd=ROOT,check=True,timeout=60)
                print('Domain settings native matrix:',scheme,mode,flush=True)
                subprocess.run([str(binary)],cwd=ROOT,check=True,timeout=90)


if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--native',action='store_true');args=parser.parse_args()
    source_contracts()
    if args.native:native_tests()
