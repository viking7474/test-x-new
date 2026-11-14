#!/usr/bin/env python3
"""Domain policy/DNS/legacy transport boundaries; --native needs macOS."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys
import tempfile
from test_runtime_identifier_writers import method
from test_profile_creation_flow import check_macro_arity
ROOT = Path(__file__).resolve().parents[1]
HOOK = ROOT / 'TLinkIOSTweak/DomainBlockingHooks.x'
POLICY = ['static NSString *getCurrentBundleID(void)', 'static BOOL shouldBlockDomain(NSString *host)',
          'static BOOL shouldBlockHostname(const char *hostname)', 'static BOOL PXDomainBlockResolvedHost(const char *hostname, socklen_t length)',
          'static BOOL PXDomainBlocksRequest(NSURLRequest *request)', 'static BOOL PXDomainBlocksURL(NSURL *url)']
INTERNAL = 'static BOOL PXDomainIsInternalRedirect(NSURL *url)'
DNS = ['static struct hostent* hooked_gethostbyname(const char *name)',
       'static int hooked_getaddrinfo(const char *hostname, const char *servname, const struct addrinfo *hints, struct addrinfo **res)',
       'static int hooked_getnameinfo(const struct sockaddr *sa, socklen_t salen, char *host, socklen_t hostlen, char *serv, socklen_t servlen, int flags)']
DELAY = 'static void PXDomainDeliverBlockedAsync(NSOperationQueue *queue, void (^handler)(NSURLResponse *, NSData *, NSError *))'
OBSERVE = 'static NSURLSession *PXDomainObservedSession(NSURLSession *session)'
RELOAD = 'static void domainBlockingSettingsChanged(CFNotificationCenterRef center,\n                                          void *observer,\n                                          CFStringRef name,\n                                          const void *object,\n                                          CFDictionaryRef userInfo)'
SIGS = ['+ (CFHostRef)createWithName:(CFStringRef)hostname', '+ (NSHost *)hostWithName:(NSString *)name', '+ (NSHost *)hostWithAddress:(NSString *)address',
        '+ (instancetype)endpointWithHost:(NSString *)hostname port:(NSString *)port', '+ (NSURLSession *)sharedSession',
        '+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration',
        '+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration\n                                delegate:(id<NSURLSessionDelegate>)delegate\n                           delegateQueue:(NSOperationQueue *)queue',
        '+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error',
        '+ (void)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))handler',
        '- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate',
        '- (WKNavigation *)loadRequest:(NSURLRequest *)request', '- (WKNavigation *)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL',
        '- (WKNavigation *)loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL', '- (NSURLRequest *)request']
CF = ['%hookf(CFReadStreamRef, CFReadStreamCreateForHTTPRequest, CFAllocatorRef alloc, CFHTTPMessageRef request)',
      '%hookf(CFHTTPMessageRef, CFHTTPMessageCreateRequest, CFAllocatorRef alloc, CFStringRef requestMethod, CFURLRef url, CFStringRef httpVersion)']


def source_contracts(source=None):
    s = HOOK.read_text(encoding='utf-8') if source is None else source
    policy = method(s, POLICY[1])
    assert policy.count('getCurrentBundleID()') == 1 and policy.count('PXScopedAppsSnapshot()') == 1
    assert policy.index('entry = scope[bundleID]') < policy.index('[DomainBlockingSettings sharedSettings]')
    assert 'gPXDomainEvaluating = previous;' in policy and 'gPXDomainRedirecting' not in policy
    assert policy.index('gPXDomainEvaluating = YES;') < policy.index('[host isKindOfClass:NSString.class]')
    internal = method(s, INTERNAL)
    assert 'if (!gPXDomainRedirecting) return NO;' in internal and 'isEqualToString:@"https://127.0.0.1:1"' in internal
    assert 'isKindOfClass:NSNumber.class' in policy and 'isKindOfClass:NSString.class' in policy
    assert '@catch (__unused NSException *exception) { return NO; }' in policy
    assert 'isInScopedAppsList(' not in s and 'loadScopedApps(' not in s
    for sig in POLICY[2:]: assert '@autoreleasepool' in method(s, sig) and '@finally' in method(s, sig)
    assert 'memchr(hostname, 0, (size_t)length)' in method(s, POLICY[3])
    for sig in DNS[:2]:
        body = method(s, sig); assert 'errno = savedErrno; h_errno = savedHostError;' in body
        assert 'ENOSYS' in body
    addr = method(s, DNS[1]); assert 'if (res) *res = NULL;' in addr and 'return EAI_NONAME;' in addr
    reverse = method(s, DNS[2]); assert reverse.index('original_getnameinfo(sa') < reverse.index('PXDomainBlockResolvedHost')
    assert 'errno = savedErrno; h_errno = savedHostError;' in reverse
    assert '__typeof__(&getnameinfo)' in s and '_Static_assert(__builtin_types_compatible_p' in s
    assert '@catch' in method(s, RELOAD) and 'settings = nil;' in method(s, RELOAD)
    observed = method(s, OBSERVE); assert '@catch' in observed and 'return session;' in observed and 'session = nil;' in observed
    delayed = method(s, DELAY)
    assert '0.2 * NSEC_PER_SEC' in delayed and '[target addOperationWithBlock:callback]' in delayed
    assert delayed.index('delivery = ^{') < delayed.index('delayed = ^{') < delayed.index('dispatch_after(')
    assert 'completion = nil; failure = nil;' in delayed and 'target = nil; callback = nil;' in delayed
    for sig in CF:
        body = method(s, sig)
        assert body.count('%orig(') == 1 and body.index('@catch') < body.index('return %orig')
        assert 'if (blocked) return NULL;' in body
        assert 'if (heldAllocator) CFRelease(heldAllocator);' in body
    stream = method(s, CF[0])
    assert 'gPXDomainRedirecting = YES;' in stream and 'gPXDomainRedirecting = previous;' in stream
    assert 'if (!blockURL || !method || !version) return NULL;' in stream
    for root in ('requestURL', 'blockURL', 'method', 'version', 'blockRequest', 'heldRequest'):
        assert 'if ('+root+') CFRelease('+root+');' in stream
    for sig in SIGS[10:]: assert 'objc_precise_lifetime' in method(s, sig) and '@finally' in method(s, sig)
    assert 'scripts/test_domain_transport_boundaries.py --native' in (ROOT / '.github/workflows/build-ios-arm.yml').read_text()
    assert 'scripts/test_domain_transport_boundaries.py' in (ROOT / 'scripts/release_hardening.py').read_text()
    check_macro_arity((ROOT / 'tests/PXDomainTransportBoundaryTests.m').read_text(encoding='utf-8'), 'domain-transport')
    print('PASS: Domain DNS/policy/legacy transport source contracts (native networking not implied)')


def generate_native_fragments(folder):
    s = HOOK.read_text(encoding='utf-8')
    top = s.split('// Use the active SDK',1)[1].split('static void domainBlockingSettingsChanged',1)[0]
    top = '// Use the active SDK' + top
    (folder / 'PXDomainPolicyState.inc').write_text(top,encoding='utf-8')
    policy = '\n\n'.join(method(s, sig) for sig in [RELOAD] + POLICY + [INTERNAL] + DNS)
    policy += '\n_Static_assert(__builtin_types_compatible_p(__typeof__(&hooked_getnameinfo), __typeof__(&getnameinfo)), "resolver ABI");\n'
    (folder / 'PXDomainPolicyWork.inc').write_text(policy.replace('[NSBundle mainBundle]', 'PXFixtureMainBundle()'),encoding='utf-8')
    helpers = method(s, OBSERVE) + '\n' + method(s, DELAY)
    helpers = helpers.replace('dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), delayed)', 'PXFixtureAfter(0.2, delayed)')
    (folder / 'PXDomainTransportHelpers.inc').write_text(helpers,encoding='utf-8')
    replacements = ['PXOrigCFHost(hostname)', 'PXOrig(1, name, nil, nil)', 'PXOrig(2, address, nil, nil)',
                    'PXOrig(3, hostname, port, nil)', 'PXOrig(4, nil, nil, nil)', 'PXOrig(5, configuration, nil, nil)',
                    'PXOrig(6, configuration, delegate, queue)', 'PXOrigSync(request, response, error)',
                    'PXOrigAsync(request, queue, handler)', 'PXOrigInit(self, blocked ? blockRequest : request, delegate)',
                    'PXOrig(10, blocked ? blockRequest : request, nil, nil)', 'PXOrig(11, string, blocked ? blockURL : baseURL, nil)',
                    'PXOrig(12, URL, readAccessURL, nil)', 'PXOrig(13, nil, nil, nil)']
    methods=[]
    for index,sig in enumerate(SIGS):
        body=method(s,sig)
        # Each adapter has a single native call; the blocked file adapter delegates to loadRequest.
        begin=body.index('%orig'); end=begin+5
        if body[end:end+1]=='(':
            depth=1;end+=1
            while depth:
                if body[end]=='(':depth+=1
                elif body[end]==')':depth-=1
                end+=1
        body=body[:begin]+replacements[index]+body[end:]
        assert '%orig' not in body
        methods.append(body)
    (folder/'PXDomainTransportDeclarations.inc').write_text('\n'.join(m.split(' {',1)[0]+';' for m in methods),encoding='utf-8')
    (folder/'PXDomainTransportMethods.inc').write_text('\n\n'.join(methods),encoding='utf-8')
    cf=[]
    for index,sig in enumerate(CF):
        body=method(s,sig)
        if index==0:
            body=body.replace(sig,'static CFReadStreamRef PXFixtureStream(CFAllocatorRef alloc, CFHTTPMessageRef request)')
            body=body.replace('%orig(alloc, blocked ? blockRequest : request)', 'PXOrigStream(alloc, blocked ? blockRequest : request)')
            body=body.replace('CFHTTPMessageCreateRequest(alloc, method, blockURL, version)', 'PXFixtureMessage(alloc, method, blockURL, version)')
        else:
            body=body.replace(sig,'static CFHTTPMessageRef PXFixtureMessage(CFAllocatorRef alloc, CFStringRef requestMethod, CFURLRef url, CFStringRef httpVersion)')
            body=body.replace('%orig(alloc, requestMethod, blocked ? blockURL : url, httpVersion)', 'PXOrigMessage(alloc, requestMethod, blocked ? blockURL : url, httpVersion)')
        body=body.replace('CFURLCreateWithString(', 'PXFixtureBlockURL(')
        cf.append(body)
    # Message must be defined first because the real stream preparation enters that public adapter.
    (folder/'PXDomainCFMethods.inc').write_text('\n\n'.join(reversed(cf)),encoding='utf-8')


def native_tests():
    assert sys.platform=='darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-domain-transport-') as tmp:
        folder=Path(tmp);generate_native_fragments(folder)
        for scheme,defines in (('rootful',[]),('roothide',['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            for mode,flag in (('plain-arc','-fno-objc-arc-exceptions'),('arc-eh','-fobjc-arc-exceptions')):
                binary=folder/(scheme+'-'+mode);print('Domain transport native matrix:',scheme,mode,flush=True)
                subprocess.run(['xcrun','clang','-O0','-fobjc-arc','-fblocks','-fexceptions','-fobjc-exceptions',flag,
                                '-Wall','-Wextra','-Werror=implicit-function-declaration','-I',str(folder),'-I',str(ROOT/'TLinkIOSTweak'),
                                *defines,str(ROOT/'tests/PXDomainTransportBoundaryTests.m'),'-framework','Foundation',
                                '-framework','CoreFoundation','-framework','CFNetwork','-o',str(binary)],cwd=ROOT,check=True,timeout=60)
                subprocess.run([str(binary)],cwd=ROOT,check=True,timeout=60)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--native',action='store_true');args=parser.parse_args()
    source_contracts()
    if args.native:native_tests()
