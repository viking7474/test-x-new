# Patch 2B — Domain DNS and legacy transport boundaries

Date: 2026-11-14. Baseline `4f4957e` (Patch 5D), whose build the user confirms
passed. This batch covers 19 adapter entry points: three DNS, fourteen ObjC and
two CFNetwork. Eighteen bodies change; NSHost's address factory remains an
unchanged passthrough control. Reload, policy and delayed-delivery helpers are
also covered. Full audit/release acceptance remains open; writer enrollment is
still H5S-partial.

## Ten prioritized changes

| Priority / severity / confidence | Finding, impact and reproduction | Change / relative cost |
| --- | --- | --- |
| P1 / High / potential exception crash | Domain adapters consulted scope, settings and request URL getters without a consistent policy failure boundary. A malformed collaborator or throwing reload could escape into an application's networking call or Darwin notification delivery. Inject scope/matcher/reload exceptions. | Policy failures return NO and native arguments continue unchanged; reload exceptions are contained. This deliberately chooses fail-open on unavailable policy. Reload containment does not roll back partially mutated model state. Low control-flow overhead. |
| P1 / High / actual unsafe failure branch | CFHTTPMessageCreateRequest unconditionally released its redirect URL after creation, including a NULL creation result. The stream adapter also passed unchecked method/version copies to its internal constructor. Force redirect URL creation to return NULL. | Guard every owned CF release and required redirect input. After a positive block decision, failed redirect preparation returns NULL/nil without submitting the real target. This changes only failure handling, not the configured domain set or ordinary redirects. |
| P1 / Medium / actual SDK signature mismatch | The reverse resolver replacement used size_t host/service lengths rather than Darwin's current socklen_t prototype. This is a formal function-pointer ABI mismatch, not evidence of an observed arm64 crash. | Derive original pointers from SDK declarations, use socklen_t in the replacement and assert type compatibility against the actual build SDK. Negligible runtime cost. |
| P1 / Medium / potential error-state corruption | DNS policy calls execute ObjC/CF/runtime work that may alter errno/h_errno before native sees them or after native reverse lookup sets them. Inject a policy provider that overwrites both. | Save/restore ambient errors around policy only; preserve native results/errors and call native once. Missing original reports ENOSYS with the applicable resolver failure. Blocked getaddrinfo clears a nonnull result slot defensively; POSIX guarantees that list on success, so this is not presented as a proven prior output-contract violation. Negligible scalar cost. |
| P1 / Medium / defensive buffer safety | Reverse policy decoded the output as an unbounded C string. A conforming successful native resolver terminates it, but an interposed/bad provider may not. Return a successful unterminated buffer with a canary immediately beyond hostlen. | Search for the terminator within hostlen before decoding. Native errors skip policy, and a denied successful lookup clears only the host field, retaining service output. Low bounded scan cost. This cannot validate an arbitrary invalid C pointer. |
| P1 / Medium / potential reentrant expansion | Bundle/scope/settings evaluation can enter another networking adapter. The internal CF stream request also entered the public message hook and repeated loopback policy/allocation. The old code does not establish infinite recursion: the inner message hook called its original directly. | A thread-local policy guard covers even foreign host validation and restores its prior value. A separate redirect flag bypasses only the exact internal loopback target during internal construction; other nested targets still receive policy. No blanket cross-request bypass or permanent loopback exemption. Low TLS cost. |
| P1 / Medium / potential exceptional lifetime leak | CF Create/Copy temporaries and ObjC parameters/callback roots were mostly cleaned on normal flow. Native/provider exceptions could skip releases, especially in plain ARC builds without ARC exception cleanup. Inject faults at internal message construction, native message/stream and callback stages. | Named roots/finally, retained CF input/allocator pins and precise WebKit receiver lifetime. Native exceptions propagate once, outside preparation catches; internal blocked construction failures are contained. Normal CF Create returns remain +1 for the caller. Extra retain/release work is low, not a claimed performance win. |
| P1 / Medium / protocol preservation | Three session factories could lose a successful native constructor result if optional task observation threw. Callback rewrites also risk wrong queue, duplicate delivery or premature client release. | Preserve the native session on observation failure. Keep the live policy predicate and unchanged task engine. Legacy async retains its 0.2-second delay, supplied queue/main fallback, nil-handler no-op and one delivery. Two lexical block-construction scopes plus named callback locals handle exceptional cleanup. NSError creation moves before scheduling; error contents remain identical. Scheduling/client exceptions propagate without retry. |
| P2 / Low / source-proven redundant work | The old central path resolved the bundle twice, and several adapters repeatedly fetched URL/host fields. | Read bundle/scope once per decision, URL/host once per adapter and instantiate settings only after a valid enabled scope entry. Helpers returning BOOL have local autorelease pools for callers entering from C. Removes repeated work but adds pool/cleanup cost; no measured net CPU/latency claim. |
| P2 / Low / maintainability | Two private scope wrapper functions had no remaining caller beyond their forwarding relationship. | Remove them and retain the exact entry.enabled policy, including NSNumber/NSString boolean handling and malformed-entry fail-open. Keep NSHost address passthrough, all hook installation gates and all real model matching behavior. |

Apple's archived [getnameinfo documentation](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/getnameinfo.3.html)
shows the socklen_t prototype and bounded output contract (its historical
synopsis also documents the older size_t form). The actual SDK assertion is the
build authority. The [getaddrinfo contract](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/getaddrinfo.3.html)
defines successful output ownership; CF cleanup follows Apple's
[Create/Copy ownership rules](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFMemoryMgmt/Concepts/Ownership.html).

## Preserved flow and behavior

- Constructor admission, critical-process/SpringBoard exclusions, scope option,
  install-even-when-OFF policy, observer registration and group initialization
  are unchanged. RootHide cold-bootstrap, package dependencies and injector
  selection are protected. Common hook source applies to rootful and RootHide.
- DomainBlockingSettings.m/.h and PXDomainTaskBlocker.m/.h are byte-identical to
  baseline. Exact/suffix matching, case/trailing-dot handling, mutable settings
  API, persistence and NSURLSession task cancellation/completion remain there.
- Legacy sync keeps its NSError code/text/output tuple; async keeps its separate
  NSError code/text and caller queue. Retained callbacks can remain live while
  a caller queue is suspended or never executes. Exceptions on a real GCD worker
  are not made safe to escape the worker by these cleanup guards.
- NSURLConnection init still redirects a copy to https://127.0.0.1:1. CF stream
  redirection still builds a method/version request without copying headers/body,
  as before. WebKit request/file denial keeps about:blank; HTML base and navigation
  request denial keep loopback. No transport semantics redesign is claimed.
- Native calls sit outside optional preparation catches and are not retried.
  Known-blocked redirect allocation failure returns nil/NULL; unavailable policy
  falls through to native. A failed optional session observer can still leave
  that session unprotected; preserving construction does not guarantee coverage.

## Verification and limits

New test_domain_transport_boundaries.py extracts six include files from the
production helper/adapter bodies. Only dependency providers, Logos originals,
timer scheduling and controlled CF URL creation are substituted. The fixture
uses real Foundation queues, CF messages, CF streams and custom CF allocator
contexts without opening network streams. Its matcher/scope/session observer and
WebKit host are facades; it does not validate real resolver traffic, Logos IMP
chaining, private classes or device WebKit transport.

Four CI recipes cover rootful/RootHide x plain ARC/ARC exception cleanup at -O0.
Tests cover resolver argument/result/error preservation, missing originals,
bounded reverse buffers, malformed/faulting scope, policy reentry and validation
reentry, live session policy, native call cardinality, legacy/WebKit destinations,
real caller-queue completion, retained/released callback captures, scheduling/
queue/client faults, nested CF redirects, fail-closed allocation and allocator
context release after preparation/native exceptions. Existing native task
lifecycle coverage remains enrolled. Its source check now recognizes standalone
`session = %orig` assignment inside cleanup rather than requiring initialization
and original call in the same declaration.

Local Windows: 69/70 Python suites and 4/4 Node suites. The only failing suite is
the established Keychain retirement Git Bash mkdir /c/Users/ADMIN permission
failure (4 failures, 1 error, 1 skip). Source hardening and RootHide static gates,
20 negative source controls, six extracted fragments, CHECK arity, protected
source comparisons and diff checks pass. Four compile/run recipe pairs were
captured; no compiler or binary ran locally. Native Foundation/ARC, Logos/Theos,
arm64/arm64e packages and device acceptance require macOS CI/hardware.

## Remaining acceptance

Exercise actual DNS/CFNetwork/WebKit/task chaining, live enable/disable, reloads
and blocked/allowed traffic on both package schemes, including iOS 15.8.8/AIDA64
cold launch. No new timer, polling, queue, file access or production logging is
introduced, but existing cold settings I/O remains synchronous. The matcher and
settings writers still share a monitor across normalization/I/O; public mutable
arrays/nonatomic setting access and malformed custom-domain status handling need
a separate model/writer audit. No immutable matcher cache, lock narrowing or
authority change is attempted without that design and equivalence evidence.
Private CFHost/NWEndpoint selector/class availability, additional networking
stacks and cross-process coverage remain compatibility risks. Main-thread use
of WebKit is still the caller's requirement. Full source authority, movement,
profiling and release-device acceptance remain pending.
