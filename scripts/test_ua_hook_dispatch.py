#!/usr/bin/env python3
"""Exact UA adapters/preparation + real normalizer; --native requires macOS."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys
import tempfile
from test_runtime_identifier_writers import method
from test_profile_creation_flow import check_macro_arity

ROOT = Path(__file__).resolve().parents[1]
HOOK = ROOT / 'TLinkIOSTweak/IOSVersionHooks.x'
SIGS = [
    '- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration',
    '- (WKNavigation *)loadRequest:(NSURLRequest *)request',
    '- (WKNavigation *)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL',
    '- (WKNavigation *)loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL',
    '- (WKNavigation *)loadData:(NSData *)data\n                  MIMEType:(NSString *)MIMEType\n     characterEncodingName:(NSString *)characterEncodingName\n                   baseURL:(NSURL *)baseURL',
    '- (void)setCustomUserAgent:(NSString *)customUserAgent',
    '- (void)setApplicationNameForUserAgent:(NSString *)applicationNameForUserAgent',
    '- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field',
    '+ (NSString *)userAgentWithDomain:(NSString *)domain',
    '+ (NSString *)defaultUserAgentString',
]
PREP = 'static NSString *PXUAPrepareRequestHeader(NSMutableURLRequest *request, NSString *value, NSString *field,\n                                        PXUAHeaderKind kind, NSString *__strong *syncHost,\n                                        NSString *__strong *syncUA, uint64_t *epoch)'
FUNCTIONS = [
    'static BOOL PXUADebugScopeAllowsWithSettings(NSString *bundleID, NSString *processName, PXUADebugSettings debug)',
    'static void modifyUserAgentString(NSString *__strong *userAgentString, NSString *originalVersion, NSString *spoofedVersion)',
    'static NSString *PXUANativeBaseUserAgent(WKWebViewConfiguration *configuration)',
    'static NSString *PXUASyntheticSpoofedUserAgent(WKWebViewConfiguration *configuration)',
    'static BOOL PXUAShouldApplyForHost(NSString *bundleID, NSString *processName, NSString *host)',
    'static NSString *PXUAModifiedUserAgent(NSString *baseUserAgent, WKWebViewConfiguration *configuration)',
    'static void PXUASetExactCustomUserAgent(WKWebView *webView, NSString *userAgent, BOOL owned)',
    'static void PXUAEnsureCanonicalUserAgent(WKWebView *webView,\n                                         WKWebViewConfiguration *configuration,\n                                         NSString *host,\n                                         NSString *hookName)',
]
ORIGINALS = [
    ('%orig(frame, configuration)', 'PXOriginalInit(self, frame, configuration)'),
    ('%orig(request)', 'PXOriginalRequest(self, request)'),
    ('%orig(string, baseURL)', 'PXOriginalHTML(self, string, baseURL)'),
    ('%orig(URL, readAccessURL)', 'PXOriginalFile(self, URL, readAccessURL)'),
    ('%orig(data, MIMEType, characterEncodingName, baseURL)', 'PXOriginalData(self, data, MIMEType, characterEncodingName, baseURL)'),
    ('%orig(candidate ?: customUserAgent)', 'PXOriginalCustom(self, candidate ?: customUserAgent)'),
    ('%orig(candidate ?: applicationNameForUserAgent)', 'PXOriginalAppName(self, candidate ?: applicationNameForUserAgent)'),
    ('%orig', 'HEADER_SPECIAL'),
    ('%orig(domain)', 'PXOriginalDomain(domain)'),
    ('%orig', 'PXOriginalDefault()'),
]


def source_contracts(source=None):
    s = HOOK.read_text(encoding='utf-8') if source is None else source
    bodies = [method(s, sig) for sig in SIGS]
    for i, body in enumerate(bodies):
        assert body.count('%orig') == (2 if i == 7 else 1), SIGS[i]
        assert '@finally' in body
        if 1 <= i <= 7:
            assert '__attribute__((objc_precise_lifetime)) id receiver = self;' in body and 'receiver = nil;' in body
    for i in (0, 5, 6, 8, 9):
        body = bodies[i]
        assert 'gPXPreparingUA = previous;' in body
        # First preparation catch closes before native call (getters are original-first).
        if i in (0, 5, 6): assert body.index('@catch') < body.index('%orig')
        else: assert body.index('%orig') < body.index('@catch')
    for body in bodies[1:5]:
        assert '[NSThread isMainThread] && !gPXPreparingUA' in body
        assert body.index('@catch') < body.index('return %orig')
        assert 'configuration = nil; destination = nil; host = nil;' in body
    custom = bodies[5]
    assert '!gUASyncApplying && !gUACanonicalApplying' in custom
    assert custom.index('%orig') < custom.index('objc_setAssociatedObject(self, kPXUABaseUserAgentKey')
    assert 'recordBase && currentIntent == intent' in custom
    assert 'intent = nil; currentIntent = nil;' in custom
    header = bodies[7]
    assert 'kind == PXUAHeaderOther) { %orig(value, field); return; }' in header
    assert header.index('kind == PXUAHeaderOther)') < header.index('PX_RUNTIME_READ_OPERATION;')
    assert 'NSSet' not in header and 'lowercaseString' not in header
    assert header.index('%orig(candidate ?: value, field)') < header.index('PXUASyncApplyToWebViewsForHost')
    assert 'candidate = nil; host = nil; modifiedValue = nil;' in header
    classifier = method(s, 'static PXUAHeaderKind PXUAClassifyHeader(id field)')
    assert classifier.count('caseInsensitiveCompare:') == 4
    assert '[field isKindOfClass:NSString.class]' in classifier
    for token in ('NSSet', 'NSArray', 'lowercaseString', 'dispatch_once', 'PXUACurrentPolicy', 'PXCaptureRuntimeSnapshot'):
        assert token not in classifier
    prepared = method(s, PREP)
    assert prepared.index('PXUASyncEpoch()') < prepared.index('bundleID = [[NSBundle')
    assert 'BOOL syncEnabled = policy.syncEnabled;' in prepared
    assert 'PXUADebugScopeAllowsWithSettings(bundleID, processName, debug)' in prepared
    assert '*syncHost = [host copy]; *syncUA = [modifiedValue copy]; *epoch = syncEpoch;' in prepared
    assert 'gPXPreparingUA = previous;' in prepared
    ensure = method(s, FUNCTIONS[-1])
    assert '!webView || ![NSThread isMainThread] || previous' in ensure
    assert 'gPXPreparingUA = previous;' in ensure and 'storedBase = nil;' in ensure
    assert 'webView = nil; userAgent = nil;' in method(s, FUNCTIONS[-2])
    assert 'NSString *__strong *userAgentString' in s
    assert 'PXUADebugMasterEnabled' not in s and 'PXUASyncHeaderAndJSEnabled' not in s
    assert 'scripts/test_ua_hook_dispatch.py --native' in (ROOT / '.github/workflows/build-ios-arm.yml').read_text()
    assert 'scripts/test_ua_hook_dispatch.py' in (ROOT / 'scripts/release_hardening.py').read_text()
    check_macro_arity((ROOT / 'tests/PXUAHookDispatchTests.m').read_text(encoding='utf-8'), 'ua-hook-dispatch')
    print('PASS: UA dispatch/request preparation source contracts (native WebKit behavior not implied)')


def generate_native_fragments(folder):
    s = HOOK.read_text(encoding='utf-8')
    debug = 'typedef struct {\n    BOOL masterEnabled;' + s.split('typedef struct {\n    BOOL masterEnabled;', 1)[1].split('} PXUADebugSettings;', 1)[0] + '} PXUADebugSettings;\n'
    packet = s.split('#pragma mark - UA policy packet', 1)[1].split('static os_unfair_lock', 1)[0]
    state = s.split('#pragma mark - Canonical WKWebView User Agent', 1)[1].split('static NSString *PXUANativeBaseUserAgent', 1)[0]
    (folder / 'PXUADispatchState.inc').write_text(debug + packet + state, encoding='utf-8')
    request = s.split('#pragma mark - UA request preparation', 1)[1].split('#pragma mark - End UA request preparation', 1)[0]
    work = '\n\n'.join(method(s, sig) for sig in FUNCTIONS) + '\n' + request
    methods = []
    for i, sig in enumerate(SIGS):
        body = method(s, sig)
        if i == 7:
            body = body.replace('%orig(value, field)', 'PXOriginalHeader(self, value, field)').replace('%orig(candidate ?: value, field)', 'PXOriginalHeader(self, candidate ?: value, field)')
        else:
            before, after = ORIGINALS[i]; body = body.replace(before, after)
        assert '%orig' not in body
        methods.append(body)
    (folder / 'PXUADispatchDeclarations.inc').write_text('\n'.join(m.split(' {', 1)[0] + ';' for m in methods), encoding='utf-8')
    # Substitute dependency expressions, never decision/ordering bodies or normalizer algorithm.
    def providers(text):
        for before, after in (
            ('[[NSBundle mainBundle] bundleIdentifier]', 'PXFixtureBundle()'),
            ('[NSProcessInfo processInfo].processName', 'PXFixtureProcess()'),
            ('[NSLocale currentLocale]', 'PXFixtureLocale()'),
            ('NSMutableURLRequest *request', 'WKWebView *request'),
            ('PXNormalizeUserAgent(', 'PXFixtureNormalize('),
            ('PXCanonicalWebIdentityHeaders(', 'PXFixtureIdentityHeaders('),
        ): text = text.replace(before, after)
        return text
    (folder / 'PXUADispatchWork.inc').write_text(providers(work), encoding='utf-8')
    (folder / 'PXUADispatchMethods.inc').write_text(providers('\n\n'.join(methods)), encoding='utf-8')


def native_tests():
    assert sys.platform == 'darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-ua-dispatch-') as temp:
        folder = Path(temp); generate_native_fragments(folder)
        for scheme, defines in (('rootful', []), ('roothide', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            for mode, flag in (('plain-arc', '-fno-objc-arc-exceptions'), ('arc-eh', '-fobjc-arc-exceptions')):
                binary = folder / (scheme + '-' + mode)
                print('UA hook dispatch native matrix:', scheme, mode, flush=True)
                subprocess.run(['xcrun', 'clang', '-O0', '-fobjc-arc', '-fblocks', '-fexceptions', '-fobjc-exceptions', flag,
                                '-Wall', '-Wextra', '-Werror=implicit-function-declaration', '-I', str(folder), '-I', str(ROOT / 'common'), *defines,
                                str(ROOT / 'common/PXUserAgentNormalizer.m'), str(ROOT / 'tests/PXUAHookDispatchTests.m'),
                                '-framework', 'Foundation', '-framework', 'CoreGraphics', '-o', str(binary)], cwd=ROOT, check=True, timeout=60)
                subprocess.run([str(binary)], cwd=ROOT, check=True, timeout=60)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('--native', action='store_true'); args = parser.parse_args()
    source_contracts()
    if args.native: native_tests()
