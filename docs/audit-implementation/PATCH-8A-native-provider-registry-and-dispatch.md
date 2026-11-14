# Patch 8A — Native provider registry and dispatch ownership

Date: 2026-11-14. Baseline `4792224` (Patch 2B), whose build the user confirms
passed. This coherent batch covers the shared registry, all 15 native dispatchers,
all 15 typed registration wrappers and diagnostic construction. It implements
the provider-registry item in the audit plan. It does not complete Patch 8's
profiling/release acceptance or the remaining transactional writer work.

## Top ten changes, in priority order

| Priority / severity / confidence | Finding, impact and reproduction | Implementation / expected relative impact |
| --- | --- | --- |
| P1 / High / actual retry defect | PXCoord_sysctlnametomib set originalCalled only after native returned. If a native interposer threw, its catch invoked original a second time. A second exception could then escape. Reproduce with a throwing original counter. | Keep original outside provider catches; invoke once and propagate its exception. Pre-provider fault still uses native once with no later posts; post fault keeps the current result. Nested mapping keeps native bypass and restores the previous TLS state. Correctness impact high; runtime cost negligible. |
| P1 / High / potential deadlock and partial registration | registerProviderID held an unfair lock while allocating records, copying caller strings/blocks, mutating arrays and sorting IDs. A foreign copy could read/register again under the same nonrecursive lock, or throw before unlock, poisoning later hook reads. | Prepare detached IDs/records, list, global ID set and state outside the registry lock. Publish by retained-basis pointer identity; on contention rebuild against the new basis. Failed preparation leaves both list and ID set untouched. A throwing/reentrant copy fixture probes registry reads and diagnostics before throwing. No device deadlock is claimed. |
| P1 / Medium / potential exceptional lifetime leak | Dispatchers and typed registrar wrappers had strong parameters, collection/enumeration roots and block locals with no explicit plain-ARC exceptional cleanup. Retired snapshots or an independently owned coordinator could remain retained after provider/native failure. | Named coordinator/list roots and finally across all 15 dispatchers; explicit cleanup in ten macro-generated and five explicit typed registrars plus generic registration. Borrow provider/block locals from the owned immutable list and index it rather than relying on hidden fast-enumeration roots. Preserve strong callback ownership in the registry. Selected scalar and wrapper lifetime oracles run after pool drain. |
| P1 / Medium / race prevention during redesign | Moving registration preparation outside a lock without an atomic publication contract could lose another thread's providers or accept a duplicate global ID twice. | One immutable packet owns symbol lists and the global ID set. Compare-and-publish the entire packet under a short lock and retry on basis mismatch. A retained basis prevents pointer ABA through deallocation. Concurrent unique/duplicate registration tests check 64 retained entries and one duplicate winner. No wait-free/fairness guarantee is claimed. |
| P1 / Medium / ownership and identity preservation | Late registration is used after installation by existing constructors. Freezing the registry at install would silently drop real providers; mutating a shared list would mix pre/post generations. | Publish new immutable per-symbol lists while preserving old lists for active calls. Pre-capable dispatchers retain one list through pre/native/post. Four statfs-family dispatchers still capture only after native, preserving their existing ordering. A callback registration affects the next relevant capture. |
| P1 / Medium / defensive reentry/lifetime | Caller-controlled string validation/copy can recursively register or release the receiver's outside owner. The old path had no explicit preparation boundary. | Thread-local registration guard begins before input validation and restores in finally, rejecting nested same-thread registration while allowing reads/diagnostics and other threads. Canonical immutable string copies plus post-copy nonempty checks detach mutable IDs/symbol names. Precise receiver pin spans foreign preparation. Concurrent mutation of caller strings during copy is not made safe. |
| P2 / Moderate avoidable hot-path work / source evidence | _providersCopyForSymbol copied its mutable array for every dispatched sysctl, statfs, IOKit, hostname, interface or network-info call. Populated mutable-array copies generally allocate and retain entries, scaling with provider count. | Capture the state under one short lock, look up the immutable list after unlocking and retain that same list for the operation. Warm reader cost becomes O(1) list acquisition, with no requested array copy. Reader still performs singleton/message/dictionary lookup and retain/release work. No measured CPU/latency improvement is asserted. |
| P2 / Medium contention risk / source evidence | Provider lookup shared a lock with registration, diagnostics and installation metadata. Cold copies/sorts or a large diagnostic build could delay hot readers. | Separate registry publication lock from the unchanged installation metadata lock. No dictionary lookup, copy/sort, logging or retired-root destruction occurs under the registry lock. Registration copies the symbol map/global ID set and the affected list, so cold cost and contention retries increase; this is a deliberate tradeoff. |
| P2 / Low / diagnostic cleanup | diagnostics allocated and assembled its entire nested report under the shared lock with no exception-safe unlock. | Capture the registry packet separately; copy installation metadata under its existing lock with finally-unlock, then build the same report schema outside locks. These two snapshots are observations at potentially different instants, not one atomic install/registration transaction. Install metadata copying still allocates under its own lock. |
| P2 / Low / contract clarity | The generic API comment said duplicate IDs were per-symbol although the code enforced a global set. Tests also depended on the exact old strong post-local declaration. | Document global uniqueness, lexical tie ordering, late registration and caller-supplied block ABI. Update the existing getifaddrs source guard to the borrowed typed local while retaining its semantic requirement: sanitizing posts run after a handled pre result as well as native. No hook, provider or priority band is retired. |

## Preserved behavior and integration

Public registrar signatures, priority values, symbol constants, original function
pointer types and all current provider registrations are unchanged. Lower
priority runs first, equal priority compares provider IDs, duplicate IDs are
global, empty IDs/symbols and absent callbacks reject. Generic callers remain
responsible for supplying a real block with the correct ABI; id input does not
permit runtime signature inference. Unknown symbol registrations remain accepted
and appear in diagnostics, as before.

For ordinary pre-capable symbols, the first YES skips native and posts.
getifaddrs deliberately runs post sanitizers even after a pre handles the base
list. gethostuuid still has pre/native only. The statfs family still calls native
before capturing post providers. Missing original return values stay -1/NULL or
kIOReturnError as applicable; this batch does not invent errno values. Native
arguments and call expressions for the other fourteen dispatchers are preserved.

sysctlnametomib retains its special provider-failure containment. Other provider
exceptions still propagate, now with named root cleanup; arbitrary buffer writes,
partial native effects and ownership of a CF result being mutated by a throwing
post provider are not automatically rolled back. No broad catch silently retries
or submits a different native operation.

The complete Installation section through isSymbolInstalled/originalForSymbol is
identical to baseline after line-ending normalization. Hook modules, capability/
scope gates, constructor order, RootHide synchronous cold-bootstrap fix, package
paths/dependencies and common runtime engine are untouched. Install-before-late-
register remains supported. Do not infer installation thread safety or a missing-
symbol retry fix from this registry batch: dispatch_once behavior, hook-library
resolution, dlopen handle retention and installation under its legacy lock remain
separate work.

## Validation

test_native_provider_registry.py compiles the actual coordinator .m through the
fixture translation unit and links the real PXRuntimeReadScope.m. No coordinator
body is rewritten or emulated. Fixture-only replacement of sharedCoordinator
selects independently owned instances; logging, installation, original functions
and runtime acquisition are controlled dependencies. No native hook is installed
and no kernel or network request is issued by these tests. RootHide acquisition
uses a nil view while exercising real lexical inheritance/cleanup.

The native matrix covers all 15 original result/missing-original routes and all
11 pre-capable handled routes, including getifaddrs posts. Additional cases check
priority/tie ordering, stable list identity, detached mutable names, cross-symbol
duplicates, late callback registration, logging/copy reentry into diagnostics,
throwing input/copy with no partial ID publication, concurrent registration,
mapper pre/post/native faults and nesting, plain-ARC coordinator/list/capture
release and both macro/manual registrar exceptional inputs. Four CI recipes use
rootful/RootHide defines x plain ARC/ARC exception cleanup at -O0. Real package
constructor ordering and kernel/provider behavior require device acceptance.

Local Windows: 70/71 Python suites and 4/4 Node suites. The established Keychain
retirement Git Bash mkdir /c/Users/ADMIN permission failure remains (4 failures,
1 error, 1 skip). Source hardening and RootHide static gates pass. Twenty negative
source controls, CHECK arity, installation/forwarding/protected-file comparisons
and diff checks pass. Four compile/run recipe pairs were captured, with no
compiler or binary execution locally. Native Foundation/ARC, actual MSHookFunction,
Logos/Theos arm64/arm64e and package/device acceptance still require macOS CI and
hardware; recipe capture is not a native test pass.

## Remaining work

Measure representative hook bursts, registration/startup and contention with
Time Profiler/Allocations before claiming a performance win. State/list retention
is bounded by registrations plus in-flight/autoreleased historical packets; the
public API still has no unregister and blocks can capture long-lived owners.
There is no per-dispatch autorelease pool added, so historical packet reclamation
can also wait for the caller pool to drain. Registration under continuous writer
contention can retry and allocate repeated candidates.

Installation still needs a separate reentry/ownership review: some symbol paths
invoke hook-library code under the legacy metadata lock, dispatch_once does not
retry missing symbols, and original pointer publication assumes existing startup
ordering. CF provider exceptional output ownership, arbitrary provider recursion,
model matcher locking/I/O, movement, full source authority and release-device
acceptance remain open. Writer enrollment stays H5S-partial.
