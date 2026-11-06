# Patch 4C.2H6R — Battery enable-gate ABI and invocation work

2026-11-06: user confirms H6Q build passes and authorizes continuation. Reviewed
BatteryHooks in full, IdentifierManager's public declarations and actual enable
implementation, existing runtime ABI helpers, source gates and native recipes.
This batch changes only bundle/scope/enable preparation in BatteryHooks. It does
not complete BatteryManager synchronization or the overall Patch 4 rollout.

## Findings and changes

1. **High / P1, potential memory-safety issue under an incompatible provider ABI.**
   TLinkIOSTweak/BatteryHooks.x, isBatterySpoofingEnabled. The previous invocation
   copied its return into BOOL enabled without checking methodReturnLength or
   methodReturnType. A runtime provider advertising a wide integer/double/object/
   struct result could copy more bytes than the BOOL slot holds. Argument count
   and the object argument at index 2 were also unchecked. The selector name or
   respondsToSelector result alone does not establish a calling convention.

   The in-repo IdentifierManager implements the expected BOOL method correctly.
   This is not a demonstrated crash in that implementation or a claim that such
   a mismatch occurs on a device. It matters when dynamic lookup finds an
   incompatible class/provider, a different implementation version, or forwarding
   advertises another signature. A controlled native fixture supplies those shapes
   without actually invoking them; its assertions remain pending macOS CI.

   Add ABI checks before dispatch or return-buffer copy. A concrete factory must
   return an ordinary Objective-C object with two hidden arguments. A concrete
   enable method must return this architecture's @encode(BOOL), have three total
   arguments and an ordinary object at index 2. Check hidden object receiver and
   SEL encodings too. String/class annotations on object encodings and standard
   qualifiers are accepted; blocks, pointers, scalars and incompatible shapes are
   rejected. Forwarded signatures additionally require the exact return-buffer
   width (sizeof(id) or sizeof(BOOL)) and a real NSMethodSignature root.

   A second potential unsafe path was the unvalidated direct sharedManager send:
   an incompatible scalar/struct result could be interpreted as an object before
   any BOOL check. Factory validation now precedes that send as well. An Objective-C
   catch cannot be relied on to recover an invalid object pointer or stack damage.

2. **Low / P2, confirmed repeated object work — invocation on concrete reads.**
   Every enabled, scoped read previously requested a method signature and built
   an NSInvocation for an ordinary, concretely implemented BOOL getter. All three
   battery hooks call this gate, as do notification and seed flows. Invocation
   work happened even when the battery scalar snapshot was warm. There is no
   measured hook frequency or evidence these battery hooks run thousands of times
   per second; do not extrapolate the source pattern into a device benchmark.

   On a concrete compatible Method, use a normal typed Objective-C message send.
   Validate metadata via runtime C APIs with bounded, zero-initialized stack
   buffers; no explicit signature/invocation object is created in that branch.
   Use @selector constants instead of NSSelectorFromString. Keep a checked
   NSInvocation path for full forwarding when no concrete method resolves.

   Do not cache class misses, instances, enable values, signatures or IMPs. Each
   request retains live scope -> class -> factory -> enable ordering, uses the
   same Battery key and queries the manager once. A class appearing later and
   ordinary same-ABI swizzles remain observable. No manual IMP call or function
   pointer authentication assumption is introduced. Dynamic lookup and metadata
   validation still run on every admitted read.

3. **Low / P2, potential exceptional-lifetime issue — own preparation references.**
   Named bundle/manager/signature/invocation slots now clear in finally. Bundle
   lookup clears its own NSBundle root; the scope adapter clears its proc/input
   references; the forwarded-signature validator clears its own object parameter.
   Return, exception-to-NO and normal nil policy are unchanged. This addresses own
   references when ordinary ARC does not perform implicit exception cleanup; it
   does not prove all foreign callees or throwing destructors release their inputs.

   Forwarded factory object results use an unsafe return-buffer slot only for the
   immediate getReturnValue operation, then promote into the strong manager slot
   while the invocation/result is valid. No unsafe object is retained as a cache.
   The fixture includes a properly autoreleased forwarded manager and weak-root
   checks after pool cleanup, plus own bundle/scope exception cleanup. The throwing
   scope stand-in borrows parameters to avoid attributing a mock's own exception
   lifetime to the gate. No device leak, heap metric or native pass is claimed.

4. **Low / P2, code smell — two unused scope helpers and a misleading source gate.**
   loadScopedApps was called only by isInScopedAppsList, which had no caller.
   Remove both. The active predicate already uses PXProcessIsAllowedForSpoofing
   with PXScopeOptionNone. P3 now checks that actual Battery predicate, as it
   already does for Storage/WiFi, rather than finding PXScopedAppsSnapshot only in
   dead code. P3 grows from 82 to 83 checks. Removing unused static code is not
   assigned runtime CPU or I/O savings.

## Behavior, compatibility and limits

The expected concrete IdentifierManager factory and enable method retain their
results and exception-to-NO behavior. Scope rejection still precedes class lookup
or provider work. Missing class/factory/manager/selector, nil or unusable forwarded
signature and incompatible metadata fail closed. Full forwarding with an ordinary
object factory and BOOL/object enable signature remains supported, with no retry
or duplicate provider query.

Concrete runtime method metadata is now authoritative; a concrete provider's
custom methodSignatureForSelector override is not queried. Full forwarding is
consulted only when no concrete Method resolves. A factory relying exclusively on
fast forwarding without supplying a usable method signature now fails closed.
The actual in-repo component has concrete matching methods and no such overrides.
These are explicit compatibility boundaries of the defensive path, not a promise
to execute arbitrary providers which merely claim respondsToSelector.

Checks describe advertised ABI, not proof that a foreign IMP obeys its metadata.
Concurrent incompatible isa/method-type replacement between check and dispatch,
malformed runtime encoding storage or arbitrary corrupt/expired object returns
remain outside this guarantee. Native BOOL encoding is used rather than guessing
that all one-byte integer returns are interchangeable across architectures.
Existing runtime/Foundation APIs are used; no deployment target, private OS class
or package dependency is added.

Both rootful and RootHide use this gate. The entire rootful/captured snapshot
reader, profile/TTL/cache helpers, H6Q baseline/notification flow, all three hooks
and original calls, and the whole constructor are byte-for-byte unchanged.
RootHide's iOS 15.8.8/AIDA64 synchronous bootstrap, captured toggle authority in
IdentifierManager, process gating and injector/package/Makefile remain intact.
No common manager, source writer, manifest, disk read policy, queue, timer,
polling, logging or persistence path changes.

## Performance assessment

The concrete branch removes one explicit NSInvocation construction and the
provider signature request per admitted read, while adding validation for both
factory and enable metadata. Expected avoided object-work cost is low/moderate
relative to the gate alone; total CPU/latency direction is unmeasured because
runtime metadata parsing also has cost. No claim of an allocation-free gate or
an end-to-end speedup is made: Foundation/runtime internals and provider/scope
work can allocate. The fixture counts requests to provider signature overrides
and the invocation factory, not every allocation in the process.

The forwarding branch still allocates invocation objects and now validates them;
its added work is bounded and justified by safe return-buffer use. No lock or
cache contention is added. Repeated class lookup, scope/provider cost and the
separate BatteryManager synchronous readers remain for future measurement.

## Verification

- Windows regression: 62/63 Python suites and 4/4 Node suites passed. The remaining
  test_keychain_bridge_retirement.py suite has the established Git Bash
  mkdir /c/Users/ADMIN permission failure (4 failures, 1 error, 1 skip).
- Artifact source contracts, P3 83/83, Phase-10 source hardening, RootHide static
  build and metadata/negative controls 6/6 passed. git diff --check passed.
- Four fragment generators completed; seven exact enable/helper bodies appear
  uniquely and in dependency order in the new native fragment. Restoring the
  admitted helper region and removing the string import reconstructs HEAD exactly.
  Snapshot/LPM helper bodies and the complete constructor also compare exactly.
- Fourteen in-memory negative source controls reject missing concrete/forwarded
  ABI guards, wrong argument/hidden selector/return-width checks, loose type match,
  bypassed live send and removed own-reference cleanup.
- New exact-source fixture specifies 100 concrete calls with live toggles and
  signature/invocation counters, missing/late class/provider/selector cases,
  scope-first behavior, exceptions, wide/scalar/object/block/struct and hidden
  argument mismatches, platform BOOL, qualified/annotated types, current IMP
  replacement, full forwarding, nil result and autoreleased object lifetime.
- Recipes captured for rootful/RootHide x both ARC exception modes at -O0.
  No compiler or binary was run. The fixture substitutes bundle/class lookup,
  scope policy and invocation construction instrumentation; it uses Foundation
  signatures/invocations and actual Objective-C method metadata for the native
  scenarios. It does not exercise the real scope or RootHide snapshot transport.

Foundation/xcrun/Theos and an iOS device are unavailable on Windows. New native
assertions, builds and device behavior require macOS CI/device verification. No
new native/build/device pass, commit, push or deployment is claimed. BatteryManager
cache concurrency, repeated I/O and cross-component authority remain pending;
full Patch 4/H5S-partial and later rollout stages are still incomplete.
