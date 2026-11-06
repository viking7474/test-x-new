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
