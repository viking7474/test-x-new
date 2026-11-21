#!/usr/bin/env python3
"""Pasteboard native boundaries and count/hash state; UIKit is a facade in native tests."""
from pathlib import Path
import argparse,re,shutil,subprocess,sys,tempfile
from test_runtime_identifier_writers import method
from test_profile_creation_flow import check_macro_arity
ROOT=Path(__file__).resolve().parents[1]
HOOK=ROOT/'TLinkIOSTweak/PasteboardHooks.x'
RETIRED=['generalPasteboard','pasteboardWithUniqueName','itemProviders','itemSetWithPreferredPasteboardTypes','containsPasteboardTypes']

def source_contracts(source=None):
    s=HOOK.read_text(encoding='utf-8') if source is None else source
    for name in RETIRED:assert 'hook_'+name+'(' not in s and '(IMP)hook_'+name not in s
    bodies=s.split('#pragma mark - Hook implementations',1)[1].split('#pragma mark - Runtime installer',1)[0]
    assert bodies.count('static ')==10 and bodies.count('gPXInsidePasteboard=previous;')==10
    assert bodies.count('objc_precise_lifetime')==10 and 'PXLog(' not in bodies
    for sig in ['static UIPasteboard *hook_pasteboardWithNameCreate(id self, SEL _cmd, NSString *pasteboardName, BOOL create)',
                'static UIPasteboard *hook_pasteboardWithURLCreate(id self, SEL _cmd, NSURL *url, BOOL create)',
                'static void hook_setPersistent(id self, SEL _cmd, BOOL persistent)']:
        b=method(s,sig);assert b.index('@catch') < b.rindex('orig_')
    for sig,original in [('static void hook_setItems(id self, SEL _cmd, NSArray *items)','orig_setItems(receiver,_cmd, items);'),
                         ('static void hook_setDataForPasteboardType(id self, SEL _cmd, NSData *data, NSString *pasteboardType)','orig_setDataForPasteboardType(receiver,_cmd, data, pasteboardType);')]:
        b=method(s,sig);assert b.rindex(original)<b.index('PXUpdatePasteboardState')
    update=method(s,'static NSNumber *PXUpdatePasteboardState(NSString *bundleID, NSInteger nativeCount, NSString *hash, BOOL increment, id epoch)')
    assert 'if (basis[@"epoch"]!=epoch) return nil;' in update
    assert 'count<NSIntegerMax' in update and 'if (entry[@"count"] && !increment && !changed) return entry[@"count"];' in update
    assert 'PXPublishPasteboardState(basis,candidate)' in update
    publish=method(s,'static BOOL PXPublishPasteboardState(NSDictionary *basis, NSDictionary *candidate)')
    held=publish.split('os_unfair_lock_lock',1)[1].split('os_unfair_lock_unlock',1)[0]
    assert '[' not in held and 'objc_precise_lifetime' in publish and 'gPasteboardState == basis' in held
    hashbody=method(s,'static NSString *getPasteboardContentHash(UIPasteboard *pasteboard)')
    assert hashbody.count('pasteboard.image')==1 and hashbody.count('pasteboard.URL')==1
    assert 'return @"ERROR";' in hashbody and 'image=nil;data=nil;url=nil;' in hashbody
    abi=method(s,'static BOOL typeEncodingCompatible(const char *existing, const char *expected)')
    assert 'actual.numberOfArguments!=wanted.numberOfArguments' in abi and 'getArgumentTypeAtIndex:i' in abi
    installer=s.split('static void installPasteboardHooks(void)',1)[1].split('#pragma mark - Constructor',1)[0]
    assert installer.count('(IMP)hook_')==10 and not re.search(r'\(IMP \*\)&orig_\w+,\s*NULL',installer)
    assert 'PX_RUNTIME_READ_OPERATION;' in bodies
    check_macro_arity((ROOT/'tests/PXPasteboardBoundaryTests.m').read_text(encoding='utf-8'),'pasteboard')
    assert 'scripts/test_pasteboard_boundaries.py --native' in (ROOT/'.github/workflows/build-ios-arm.yml').read_text()
    assert 'scripts/test_pasteboard_boundaries.py' in (ROOT/'scripts/release_hardening.py').read_text()
    print('PASS: Pasteboard native ACK/ABI/epoch source contracts (UIKit/device behavior not implied)')

def generate_fragment(folder):
    s=HOOK.read_text(encoding='utf-8')
    state=s[s.index('// One immutable packet'):s.index('#pragma mark - Scoped Apps Helper Functions')]
    pointers=s[s.index('#pragma mark - Per-selector original IMPs'):s.index('#pragma mark - Hook implementations')]
    hooks=s.split('#pragma mark - Hook implementations',1)[1].split('#pragma mark - Runtime installer',1)[0]
    abi='\n'.join(method(s,sig) for sig in ['static const char *PXUnqualifiedPasteboardType(const char *type)',
        'static BOOL PXPasteboardABIType(const char *actual, const char *expected)','static BOOL typeEncodingCompatible(const char *existing, const char *expected)'])
    helpers='\n'.join(method(s,sig) for sig in ['static NSString *getPasteboardContentHash(UIPasteboard *pasteboard)',
        'static NSString *deterministicPasteboardName(NSString *originalName, NSString *uuidString)'])
    (folder/'PXPasteboardBoundaries.inc').write_text('\n'.join([state,pointers,helpers,hooks,abi]),encoding='utf-8')

def native_tests():
    assert sys.platform=='darwin' and shutil.which('xcrun'),'--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-pasteboard-') as tmp:
        folder=Path(tmp);generate_fragment(folder)
        for scheme,defines in [('rootful',[]),('roothide',['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])]:
            for mode,flag in [('plain-arc','-fno-objc-arc-exceptions'),('arc-eh','-fobjc-arc-exceptions')]:
                binary=folder/(scheme+'-'+mode)
                subprocess.run(['xcrun','clang','-O0','-fobjc-arc','-fblocks','-fexceptions','-fobjc-exceptions',flag,
                    '-Wall','-Wextra','-Werror=implicit-function-declaration','-I',str(ROOT/'common'),'-I',str(folder),*defines,
                    str(ROOT/'common/PXP1AFilters.m'),str(ROOT/'tests/PXPasteboardBoundaryTests.m'),'-framework','Foundation','-framework','CoreFoundation','-o',str(binary)],cwd=ROOT,check=True,timeout=60)
                print('Pasteboard native facade matrix:',scheme,mode,flush=True)
                subprocess.run([str(binary)],cwd=ROOT,check=True,timeout=90)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--native',action='store_true');args=p.parse_args();source_contracts()
    if args.native:native_tests()
