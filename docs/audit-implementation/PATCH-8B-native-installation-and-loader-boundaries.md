# Patch 8B — Native installation and loader boundaries

Date: 2026-11-15. Baseline `4c2f26b` (Patch 8A), whose build the user confirms
passed. This batch covers all 15 owned symbol installation routes, shared loader
and logging helpers, immutable install metadata, both metadata accessors and
diagnostics. It preserves the provider registry and every native dispatcher.
Writer enrollment remains H5S-partial; full audit/release acceptance stays open.

## Top ten changes by priority and expected impact

| Priority / severity / confidence | Finding, impact and reproduction | Change / expected relative cost |
| --- | --- | --- |
| P1 / High / potential deadlock | IOKit, CF and SC installation held the coordinator metadata lock while invoking MSHookFunction. A synchronous callback querying diagnostics/isSymbolInstalled/originalForSymbol would try to take that lock again. Reproduce with a controlled hook engine querying all three. This is source-proven lock exposure, not a captured device deadlock. | Route all 15 symbols through one installer; loader, engine, logging and collection work run outside coordinator locks. Only owned-pointer capture/publication uses the metadata lock. High stability impact, low cold control-flow cost. |
| P1 / High / potential recursive once wait | installOwnedSymbolsIfNeeded entered process dispatch_once without a same-thread admission guard. dlopen initializers, hook callbacks or diagnostics could call it again and wait for the pass currently executing on that same thread. | Set thread-local admission before engine lookup or once; synchronous reentry returns and restores prior state in finally. Keep first-pass installation inline and retain existing cross-thread once serialization. Does not solve cross-thread loader/hook lock inversion or make a nested call an installation-completion acknowledgement. |
| P1 / High / inconsistent engine precondition | Ten base-symbol routes checked MSHookFunction visibility but the five framework routes called it directly. Consuming once while the engine was unavailable could also permanently skip those base symbols. | One preflight checks visibility before consuming once. An unavailable/throwing preflight leaves the pass unstarted, so a later explicit call can try again. Framework routes now share that requirement. This deliberately changes engine-unavailable behavior; no timer, worker, polling or automatic delayed retry is added. Normal visible-engine behavior is preserved. |
| P1 / Medium / exception consistency and partial state | Metadata updates mutated installed set/count/original dictionaries separately under a lock with no finally-unlock. An exception could leave the lock poisoned or a partly updated report. | Build an immutable installed/count/original packet outside the lock and publish by retained-basis identity. Exceptions before publication leave the old packet intact; retired roots release after unlocking. Metadata acknowledgement still follows the engine call. Cold copies grow with installed symbols (at most 15 here), so this is a correctness tradeoff rather than a claimed launch-speed win. |
| P1 / Medium / potential exceptional cleanup leak | Installer parameters, copied names, metadata roots and callback captures had no consistent explicit cleanup in plain-ARC exception paths. Original lookup also used strong NSValue state inside its lock. | Named roots/finally and precise receiver pins across foreign name preparation; lexical block construction ends before once. Capture metadata under the lock and do lookups/pointerValue outside. Native original slots remain the engine-owned output locations. Low retain/release cost. |
| P1 / Medium / uncertain patch outcome | An engine can throw after writing a trampoline, or metadata can fail after patching. Re-running such a route can patch the replacement again and corrupt chaining. Native C crashes cannot be handled as ObjC exceptions. | Contain per-symbol NSException, report an interrupted installation, continue other routes and keep the process once consumed. Do not clear engine-written slots, invent rollback or retry from absent metadata. Metadata can therefore say absent even if code was partially patched. Ordinary NULL trampoline output retains the old installed=true/originalPresent=false reporting behavior; it is not certified usable. |
| P2 / Moderate cold resource overhead / source evidence | Each base-symbol fallback could dlopen the same libSystem images again without releasing those references. Equal returned handle addresses do not prevent extra loader reference counts. Framework references also had implicit lifetime. | Cache one acquisition result per each of five existing image paths; at most one successful handle reference per path is intentionally pinned for process lifetime so trampoline code cannot be unloaded. Missing acquisitions are cached as well. No dlclose while hooks use an image. Bounded references replace repeated fallback opens; resident-memory/launch improvement is unmeasured. |
| P2 / Low compatibility clarity | Three separate framework branches duplicated lookup, install, original-slot and metadata handling, increasing drift risk. CF also has a private-name fallback that must not be lost. | One resolver keeps RTLD_DEFAULT then the same two libSystem fallbacks for base symbols; handle-local IOKit/CF/SC lookups retain their existing order. CF tries canonical then _CFCopySystemVersionDictionary. NOLOAD explicitly uses LAZY, matching its previous default, while fallback/framework loads retain NOW and existing default visibility. No new library path, symbol or API is admitted. |
| P2 / Medium defensive accessor safety | Metadata getters performed caller-string hashing/lookup while holding the metadata lock. A nonstandard NSString implementation could reenter a getter or throw. Adding defensive copying indiscriminately would also add work to Storage's existing hot installed-symbol query. | Known exported symbol constants take a pointer-identity fast path before validation/copy. Other inputs become detached canonical strings outside the lock under a separate TLS guard; malformed/throwing names return NO/NULL. Getter capture then lookup occurs outside the lock. Extra fixed pointer checks/retains are low; no per-call string allocation is requested for internal constants. |
| P2 / Low optional diagnostic failure | Logging and final diagnostics could interrupt installation even though they do not determine whether native patching succeeded. Diagnostics previously copied installation collections under the metadata lock. | Optional install reporting and final report construction contain NSException. Diagnostics retains the immutable metadata packet and builds its unchanged report outside locks. Registry and install packets remain two observations, not an atomic transaction between registration and patching. No new hot-path log or periodic diagnostic is introduced. |

Apple documents that repeated opens, including NOLOAD handles, increment loader
references and that dlopen may execute image initializers before returning:
[dlopen manual](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/dlopen.3.html).
Retaining a bounded set for the lifetime of installed code is an explicit design
choice, not a claim that these references are automatically balanced at teardown.
Handle-local versus RTLD_DEFAULT lookup retains Apple's
[dlsym semantics](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/dlsym.3.html).
The underscore is the existing private CF export fallback, not a prefix added to
all dlsym names.

## Flow and preserved behavior

The first caller still completes its admitted installation pass synchronously.
All 15 replacement/original-slot bindings and their order remain: ten base
symbols, three IOKit symbols, CF system version, then CNCopyCurrentNetworkInfo.
Hooks are still installed independently of whether a provider has registered
yet. Late registration continues to work through the immutable provider packet.

The process once is unconsumed only when preflight cannot start. Once a pass
starts, a missing individual symbol, missing image or interrupted symbol attempt
is not retried by subsequent callers. The image cache also stores failed first
opens. This batch makes these limits explicit rather than silently enabling a
new retry policy around potentially irreversible native patching.

An admitted second thread retains the prior dispatch_once waiting behavior.
Same-thread nested callers return promptly and may see only the already
published prefix of metadata; they do not receive a fabricated original pointer.
The public API remains void. Installation bookkeeping is associated with the
instance running the process pass, as before; production uses sharedCoordinator.
Arbitrary independent instances or overrides of private installation methods
are not given a new process-wide metadata authority contract.

_markInstalled publishes only after a normal engine return. Counts stay one,
duplicate bookkeeping is idempotent and getters use one retained metadata packet
per query. A false installed getter following a caught engine/metadata exception
does not prove the target machine code is unmodified. Logs report the uncertainty.
No native output slot is cleared to hide it. Actual trampoline publication/order
is still the hook library's responsibility; the source's global function-pointer
slots and dispatcher reads are unchanged. No new atomic-publication guarantee is
claimed for a target thread entering replacement code during installation.

RootHide cold-snapshot priming, source-reader preparation, capability/process/
scope gates, constructor order, all hook .x files, provider registry/dispatch
semantics, package paths/dependencies, Makefile and common runtime engine are
protected. No async queue, timer, timeout or worker is added to bootstrap.

## Fixture and validation

test_native_hook_installation.py compiles the actual coordinator implementation
through PXNativeHookInstallationTests.m and links the real read-scope engine.
Only this translation unit's loader calls are redirected to controlled functions;
Foundation/dyld are not globally interposed. The fixture hook engine writes
non-callable sentinel addresses into the exact expected output slots. It never
patches native code or invokes those sentinels, and issues no kernel/network
request. It proves control-flow/metadata contracts, not real loader/trampoline ABI.

Each native scenario starts a fresh process, preserving actual dispatch_once
semantics. Eleven scenarios cover ordinary success; engine appearing after a
preflight miss; missing individual symbol with no later retry; engine throwing
after writing output; post-patch metadata failure; loader/lookup/logger exceptions;
concurrent callers; malformed/reentrant/mutable names; and NULL original output.
Checks include exact 15 replacement/slot bindings, one attempt each, callbacks
into installer/getters/diagnostics at loader/hook/report boundaries, coherent
metadata, bounded loader calls, both system fallbacks, CF alias ordering, real
cross-thread once completion, guard restoration and selected foreign-input
release after pool drain. Existing registry/dispatch coverage remains enrolled.

CI adds four builds (rootful/RootHide x plain ARC/ARC exception cleanup), each
with 11 isolated scenario runs: 44 new process runs. Local recipe capture checked
those commands only. No compiler, binary, actual hook engine or device test ran on
Windows. Local results: 71/72 Python suites and 4/4 Node suites. The sole failing
suite remains Keychain retirement's Git Bash mkdir /c/Users/ADMIN permission
failure (4 failures, 1 error, 1 skip). Source hardening and RootHide static gates,
20 negative source controls, CHECK arity, recipe capture, full registry/dispatcher/
original-slot protected comparisons and diff checks pass.

## Remaining acceptance

macOS CI must compile/run the new real-source matrix and package both schemes;
device checks must exercise real Substrate/ElleKit chaining, arm64/arm64e pointer
behavior and scoped/unscoped launch, including iOS 15.8.8/AIDA64 RootHide cold
bootstrap. The fixture does not resolve actual symbol availability on each iOS.

Cross-thread waits can still participate in a loader/hook-library dependency
cycle if one thread waits for a callback on a thread waiting for this once. There
is no cancellation, automatic repair, safe unload, individual-symbol retry or
atomic trampoline publication layer here. Independent-instance authority and
private override behavior remain outside the production singleton contract.
Benchmark cold startup/fallback and hook bursts before claiming performance
improvement. CF exceptional output ownership, matcher/model I/O, movement,
profiling and full transactional/release-device acceptance remain pending.
