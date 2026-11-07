# Patch 4C.2H6L — WiFi cold-resolver exceptional lifetime

2026-11-06: user confirms H6K build passes and authorizes continuation. Read the
complete resolver, caller contract, lifecycle/selection helpers and existing
real-source fixture. This batch adds explicit cleanup of the resolver's owned
references, including its helper and source-callback scopes. No hook, manager,
writer enrollment, build flag or selection-authority policy changes.

## Findings and changes

1. **Medium potential / P1 — cache/freezing scopes retain objects after recovery.**
   common/PXWiFiHookResolver.m, PXWiFiHookHasPair, PXWiFiHookFreeze and the cache
   provider step of PXResolveHookWiFiInfo. The helper predicate, input candidate
   and serialized data previously relied on ARC releasing strong locals/parameters
   when an exception unwound their scopes. Recovering via a catch does not itself
   guarantee that cleanup in plain Objective-C ARC without ARC exception cleanup.
   See [Clang ARC exception rules](https://clang.llvm.org/docs/AutomaticReferenceCounting.html#exceptions).

   A throwing provider record predicate or plist decode can retain the candidate
   or encoded graph. Put named inputs/data/frozen values in explicit finally
   cleanup and clear the provider candidate/error at its boundary. Preserve the
   initial pair predicate outside the codec's catch: its exception must still
   reach the provider/preparation catch, while codec failure still yields nil.
   No device occurrence, leak size or exception frequency is established.

2. **Medium potential / P1 — transaction callback and captured snapshots outlive
   failed cold preparation.** Same file, owned-read/commit blocks and parent
   resolver. Releasing lifecycle ownership and resetting TLS did not explicitly
   release the captured selection/WiFi/IDs roots, callback transaction argument,
   current comparison roots or partially merged dictionary after an exception.
   Those are independent resources: releasing the lease does not release every
   retained object in a failed block frame.

   Add cleanup to each callback and the parent resolver. Name the prepared input
   before freezing, clear it immediately after a successful freeze and on failure,
   and keep the final display string in a named cleanup slot during staging.
   Release lifecycle through the existing invalidate finally, then drop owned
   parent snapshots/mutation, then reset this invocation's TLS guard. A nested
   request that never acquired that guard must not reset the outer invocation.

   The lifetime fixture throws after an owned source read, during commit reads,
   selection matching, staging and final merged-dictionary submission, checking
   weak roots after pool drain. These tests isolate the resolver; they do not
   prove cleanup inside the real source/lifecycle callees.

3. **Medium potential / P1 — strong C inputs survive a propagating early error.**
   PXResolveHookWiFiInfo, target preparation/standalone admission/acquisition.
   Its caller ID and cache-reader block are strong function parameters. If an
   exceptional collaborator propagates out before normal scope termination, a
   retained block can keep its captured graph alive. Wrap the complete existing
   lookup/admission flow in input cleanup. Admission/acquisition exceptions still
   propagate at the same catch boundary; no new catch or fallback is introduced.
   Fixtures retain an input string and heap block capture only through the call,
   inject those failures, release the caller's references, then check weak refs.

These are exception-lifetime issues, not evidence of a normal-path retain cycle,
use-after-free, deadlock or failed lease release. Source declarations/build flags
show the gap; new native assertions still need execution. Objective-C++ or a build
that enables ARC exception cleanup has different defaults and is tested separately.

## Preserved flow and limitations

The successful order remains standalone selection admission, TLS check/claim,
cache provider outside source/lifecycle ownership, fixed-target acquisition,
owned source reread, source/cache hit or pure generation, selection/source CAS,
paired write, release and return. Nested staging still reaches standalone admission
before the TLS check, preserving its poisoning behavior. There is no extra probe,
retry, file write, notification, queue, timer, class lookup or provider invocation.

Source takes precedence over a cache candidate. Cache fallback remains detached,
read-only and not commit acknowledgement. A new seed is returned only on source
commit acknowledgement. Missing target, changed selection/source, busy/pending
state, canonical/legacy precedence, parser/spelling, error strings/codes and
post-marker success retain their existing policies. Source rollback/inactive
cleanup are handled by the existing real helpers, which this batch does not alter.

Initial cache pair-predicate exceptions retain provider error 3023; codec failure
retains the prior nil/fallback behavior. Preparation exceptions escaping a source
collaborator still reach the existing 3023 catch; real source-store errors can be
converted internally and retain that helper's error. The injected lifetime stand-in
allows exceptions to escape so the resolver boundary is exercised directly.

Return-value ownership protects returned source/cache/prepared graphs before
local cleanup. Named owned references are cleared explicitly; this is not a claim
that every compiler-generated full-expression temporary or foreign callee retain
is cleaned. Caller mutation during freeze, malicious copy behavior, throwing
foreign destructors and common source/lifecycle helpers' own abnormal-exit
ownership remain separate. No global thread-safety/freshness guarantee is added.

All of WiFiHook.x/H6K, WiFiManager/H6J, bootstrap/scope/private hook installation,
package dependencies, Makefile and writer manifest remain unchanged. RootHide's
injected WiFi branch still uses its captured view and does not call this live
fallback. Both schemes compile the shared resolver and run its test recipes.
The iOS 15.8.8/AIDA64 bootstrap fix is untouched. Full Patch 4/H5S-partial remains
partial.

## Performance

This is a cold fallback, not the warm hook cache hit. Expected added normal-path
cost is low relative to its existing synchronous source/lease/I/O work: explicit
reference stores and unwind regions, with no additional serialization, generation
or commit. The raw prepared graph is released once freezing succeeds, before the
commit. Some hoisted references deliberately remain until lease cleanup rather
than relying on the optimizer's early release. Code size and transient memory
can differ; no measured CPU, latency, retained-byte or code-size improvement is
claimed. Repeated recoverable failures should no longer retain these named
resolver-owned graphs; native/device evidence is still required.

## Verification

- Windows regression: 62/63 Python + 4/4 Node suites passed. The remaining
  test_keychain_bridge_retirement.py suite is the established Git Bash
  mkdir /c/Users/ADMIN permission failure (4 failures, 1 error, 1 skip).
- Artifact source contracts, Phase-10 source hardening, RootHide build static
  contracts and RootHide package metadata/negative controls 6/6 passed.
- Four fragment generators completed. The new fragment is the exact complete
  resolver region (TLS plus six function bodies); collaborator type/codec names
  are adapted by test-only macros. Policy literal multiset and counts of existing
  admission/provider/acquire/read/write/generate/invalidate operations match HEAD.
- Twelve in-memory negative source controls rejected missing provider/input/
  snapshot/commit/helper/codec cleanup, an unnamed prepared factory expression,
  missing capability release and missing TLS reset. These are source-gate checks,
  not proof of runtime cleanup.
- New Foundation fixture covers ten injected boundaries (admission, acquisition,
  provider pair, decode, owned read, commit read, selection match, stage, merge,
  prepared pair), plus nested guard, generated/source/cache return ownership.
  Throwing stand-ins borrow inputs; weak tables observe roots without retaining
  them. The stand-ins do not model real journaling, locks, files or crash recovery.
- Captured native recipes contain four lifetime variants: rootful/RootHide x ARC
  exception cleanup enabled/disabled at -O0. The existing two real-source variants
  still link the actual resolver for paired-write/rollback/drift/busy/pending/
  post-marker tests. Compiler/binary calls were captured, not executed.
- git diff --check passed. No unrelated production files changed.

Foundation/xcrun/Theos and an iOS device are unavailable on this Windows host.
New native assertions, package builds and device behavior require macOS CI/device
verification. No new native/build/device pass, commit, push or deployment is claimed.


## Native follow-up — method argument block ownership (2026-11-06)

User CI reached rootful plain-ARC resolver lifetime 61/65. The four failed
cases were commit-read, selection-match, stage and merge. Each reported only
mutation=1 and frozen=1 after the pool drained; transaction, input/provider,
selection, original sources, codec data, prepared input and merged roots were
already released. This is a runtime assertion failure after compilation, rather
than an unused-function warning or a missing RootHide dependency.

The commit callback was still an inline Objective-C method argument. Its heap
copy captures the mutation and frozen prepared packet by value. Clearing their
parent locals in finally does not release an independently retained block copy;
plain ARC does not promise cleanup of that argument temporary if the method call
unwinds. The earlier explicit cleanup covered the named roots and callback
frames, but left this caller-side temporary boundary unowned. The four failures
have this boundary in common. The read callback and acquisition resolver also
used inline method arguments, though their remaining captures were not exposed
by the original object-root oracle (byref roots were cleared; an immutable target
can also conceal retained callback lifetime).

PXResolveHookWiFiInfo now owns both source callbacks through a named strong
sourceWrite slot and the acquisition callback through a named identityResolver
slot. Each slot is cleared after normal synchronous completion and in the
existing parent finally on exceptional exit. Capability invalidation still comes
before the exceptional callback/snapshot cleanup, and TLS is cleared last. No
__block conversion of mutation/prepared, unsafe capture, new catch, exception
swallowing, extra source transaction or global ARC build flag is introduced.
Acquisition exceptions still propagate; source-preparation exceptions still
reach the existing 3023 catch. Admission, provider, selection/source comparisons,
paired write and returned data policies retain their order.

The lifetime fixture retains the ten original fault cases and every original
object-root assertion. A weak callback table additionally observes the actual
method argument blocks in its borrowed stand-ins. It checks their release after
pool drain on all exceptional cases and on generated success, existing source
and read-only cache returns. This detects leaked callback objects even when the
resolver has cleared their byref capture cells. The production resolver fragment
remains an exact extraction; no test-only ownership change is injected into it.

This fixture intentionally permits source collaborators to throw out to the
resolver. The real PXRuntimeSourceStore normally catches body exceptions and
returns an error before its caller unwinds. Accordingly, the CI failure proves
an exceptional caller-lifetime gap under this fault injection, not that every
normal failed source transaction leaks, nor a measured leak on a device. Cleanup
of foreign callees and unrelated full-expression temporaries remains outside
this patch. Shared common source applies to rootful and RootHide; injected
captured-view authority, bootstrap, hook installation, packaging/dependencies,
Makefile, writer enrollment and the iOS 15.8.8/AIDA64 fix are untouched. Rootful
is the first native matrix entry; a failure there prevents later matrix entries
from running and does not establish a rootful-only defect.

Validation on this Windows host:

- 62/63 Python suites and 4/4 Node suites passed. The remaining retirement suite
  has the established Git Bash mkdir /c/Users/ADMIN permission failure
  (4 failures, 1 error, 1 skip), unrelated to resolver source.
- Artifact source contracts, Phase-10 source hardening and RootHide build/static
  package checks (metadata/negative controls 6/6) passed.
- Four fragment generators completed, including byte-exact resolver extraction.
  Helper bodies, error/policy literals and source/provider operation counts are
  preserved. Eight negative source controls rejected missing slot cleanup,
  incorrect callback arguments and missing weak-block observations/assertions.
- Recipe capture verified rootful/RootHide x plain-arc/arc-eh resolver compiles
  at -O0 and their corresponding binary invocations. Those compiler/binary calls
  were captured, not executed. The existing real-source tests remain enrolled.

Foundation/xcrun/Theos are unavailable locally. The updated native lifetime
assertions and package builds must be verified by macOS CI; no native or device
pass is claimed. No measured performance improvement is claimed. The change
binds the existing method-argument block copies to explicit cleanup and adds no
provider, disk, notification, dispatch or polling work. Full Patch 4 remains
partial at the existing rollout marker.

## Native follow-up — complete WiFi callback boundaries (2026-11-07)

Baseline 8a2b78f. The new user log confirms rootful plain-ARC Storage manager
cache now passes 57/57 and Uptime passes 76/76. The next executable, WiFi resolver
lifetime, fails at 74/78. Commit-read, selection-match, stage and merge each retain
mutation=1 and frozen=1, with provider/input/source/transaction/merged/codec/other
prepared roots released. The heap callback assertions do not fail. This isolates
a different remaining layer from the earlier inline method-argument copy gap:
the named heap slots were present, but the stack block literals still shared the
lexical scope containing the throwing source calls. The latest log is evidence
for these four resolver faults only, not for a failing RootHide or device run.

### Changes addressing the reported failure

- End construction scopes normally before both resolver source calls and before
  capability acquisition. Keep the existing named strong slots and their finally
  cleanup. This releases stack captures of mutation/prepared while retaining the
  heap callback needed during synchronous calls. Strong captures remain; no weak,
  unsafe or raw-pointer ownership workaround is introduced.
- Put standalone admission in a named admissionWrite slot with its own completed
  construction scope and outer finally cleanup. Keep admission before the TLS
  check/provider and keep nested rejection from clearing the outer TLS guard.
  Admission/acquisition exceptions still propagate; preparation/source exceptions
  still become error 3023. Pending source errors and successful return policies
  keep their previous meaning.
- Evaluate mutation.identityDirectory into a callback-local strong identity before
  staging, and clear it in finally. This closes the getter-result expression
  boundary already exposed by Network's copied-identity oracle.
- Evaluate the post-stage IDs read into a named stagedIDs before mutableCopy, then
  clear it in finally. This retains the required re-read after staging; it does
  not reuse the earlier comparison snapshot or add/remove transaction reads.
  A new merge-copy fault observes the otherwise unnamed copy input weakly.

These boundaries follow Clang's documented distinction between stack capture
scope and owned heap blocks, and its [plain ARC exception cleanup contract](https://clang.llvm.org/docs/AutomaticReferenceCounting.html#exceptions).
The exact retain instruction sequence on the runner has not been inspected.
The real SourceStore normally catches body exceptions and returns an error;
throwing stand-ins intentionally test unwind through the caller. This is not a
claim that every ordinary failed transaction leaks or a measured device leak.

### Related boundaries fixed in the same batch

Source review found the same pattern in two nearby WiFi paths exercised by this
matrix. These are source-level cleanup gaps, not additional failures shown by the
user's log:

- WiFiManager's owned save still passed both resolver and source callbacks inline
  as Objective-C method arguments. Give them named strong slots, completed
  construction scopes and explicit cleanup after capability invalidation. Own the
  stage identity getter result and transaction callback argument in finally.
  Preserve optional manager lookup, one captured target, all revision checks,
  cache snapshot, source commit and post-commit readable cache/error policy.
- NEHotspotNetwork fetch's deliver block was named, but its literal still captured
  completion in the enclosing scope. Complete construction in a separate scope
  before original/fallback execution. The callback body remains byte-for-byte
  equivalent apart from indentation. Nil-handler forwarding, real-network fast
  return, delivery-time scope, optional synthesis, original callback thread,
  synchronous missing-original fallback, original/client exception propagation
  and asynchronous consumer ownership stay unchanged. No new dispatch or retry.

There are seven completed construction boundaries across the three production
files. Resolver and manager have two named identity getter results; the resolver
also owns the late-copy input. No C-stage/source/lifecycle engine, scope/install
policy, constructor, bootstrap, hook ABI, package, dependency or Makefile is
changed. The hook function body changes only its local construction scope; all
other WiFiHook text is preserved. RootHide's iOS 15.8.8/AIDA64 bootstrap fix and
rollout marker 4C.2H5S-partial remain unchanged.

### Regression coverage

Keep all ten original resolver faults, both original object/block predicates,
and generated/source/cache returns plus nested TLS behavior. Add merge-copy and
weak observation of a distinct owned capability identity, including on success
returns. Stand-ins observe admission callbacks too, borrow throwing arguments,
and clean their own partial acquisition references if resolution throws.

The same native file now includes the byte-exact WiFiManager save method in a
facade. Six outcomes cover acquire failure, profile resolution exception, source
entry exception, stage exception, source NO/error and acknowledged success.
Weak probes cover manager/provider/prepared metadata/transaction/capability/
identity/heap callbacks. Cache helper/source collaborators are controlled; this
is lifetime coverage, not proof of real filesystem rollback or full cache
concurrency. Existing real source and WiFi manager-cache tests remain enrolled.

Fetch tests keep every prior case. The captured-consumer exception loop also
covers a real system-network result, and an added deferred-client exception case
checks retention by the original while pending, one propagated delivery and
release after that original callback is dropped. It drains weak-load observations
before delivery to avoid a test-owned autorelease extending consumer lifetime.

Local verification: 62/63 Python and 4/4 Node suites pass; the only failure is the
established Keychain retirement Git Bash permission issue (4 failures, 1 error,
1 skip). Source hardening, RootHide metadata/static controls (6/6), macro arity,
five fragment generators, exact resolver/writer/fetch fragments and diff checks
pass. Eighteen negative source controls reject missing construction scopes,
getter assignment/cleanup, named copy input/cleanup and native probes/invocations.
Eight affected resolver/fetch scheme x ARC recipes at -O0 were captured, not
executed. A preservation check retains the resolver's helpers and policy literals,
all other WiFiManager methods and WiFiHook content outside the fetch function,
and the fetch callback body. Provider/transaction/stage call counts are unchanged.

macOS/Foundation/Theos and device execution are unavailable on this Windows host.
The reported 74/78 failure and new native controls still require CI rerun; no
passing result is claimed for this batch. New slots/scopes add bounded retention
and cleanup work, no provider/I/O/polling; no performance benchmark is claimed.
This closes selected exceptional owned-root boundaries, not every foreign callee,
compiler temporary or raw allocation lifetime throughout the repository. Patch 4
and later stages remain incomplete.
