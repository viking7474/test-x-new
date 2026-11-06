# Patch 4C.2H6P — BatteryHooks snapshot epoch and profile paths

2026-11-06: user confirms H6O build passes and authorizes continuation. Reviewed
BatteryHooks in full, its PXPaths implementation and H6O manager fallback contract.
This batch changes the rootful snapshot/cache/path helpers, with matching native
fixture recipes. It does not complete the overall battery or Patch 4 audit.

## Findings and corrections

1. **Medium / P1, confirmed ordering gap — invalidation can be undone.**
   TLinkIOSTweak/BatteryHooks.x, PXReadBatterySnapshot / PXGetBatterySnapshot /
   PXPublishBatterySnapshot / PXInvalidateBatterySnapshot. Previously, clearing
   the cache did not revoke a loader already reading disk or calling the optional
   manager. Schedule loader A -> notification clears cache -> loader B publishes
   a newer value -> A publishes its older candidate. A could overwrite B for the
   normal TTL and return its own revoked value. No device occurrence is claimed.

   Capture a scalar generation with the cached struct under the existing unfair
   lock; invalidation increments that generation and clears the struct in the
   same lock. Publish only when the captured generation still matches. A revoked
   read returns an unavailable struct (both has-flags false), so hooks use their
   existing original fallback for that operation. It neither retries nor returns
   a competing winner that could belong to another profile. A rejected publisher
   cannot clear a newer winner. This is an intentional correction on a race,
   not a new global freshness or selection transaction guarantee.

   The new native fixture schedules invalidation both without a replacement and
   with a second NSThread publishing before A resumes. It asserts A is unavailable,
   B survives, TLS is restored and the next request can fill an empty cache.
   A bounded semaphore rendezvous also detects a lock accidentally held over I/O.
   Native execution is pending; source inspection establishes the old ordering gap.

2. **Medium / P1, confirmed path consistency gap — two selection reads.**
   PXProfileBatteryInfoPath previously called PXActiveProfileIdentityPath and
   PXActiveProfileRootPath independently. Both call PXActiveProfileID, which
   synchronously reads selection plists. A switch between them could pair A's
   canonical battery file with B's legacy battery file. If A's canonical file was
   missing, the reader could return B's legacy data while considering A first.

   Copy the selected ID once, derive its identity path using PXProfileIdentityPath,
   then derive the legacy parent from that same identity path. Canonical-first,
   legacy-second, missing-canonical return and nil/no-selection policy stay intact.
   The native fixture changes the global selection during the first lookup but
   returns its captured A ID: both paths must still belong to A. Complete canonical
   records require only one existence check and one active-ID resolution.

   This fixes this path helper only. BatteryManager fallback still resolves its
   own authority and may supply fields after a switch; no whole-flow target pin or
   immutable cross-component generation is introduced here.

3. **Medium / P1, confirmed TTL arithmetic gap — wall-clock reversal.**
   PXGetBatterySnapshot used NSDate wall time and only age < 2. A backwards clock
   adjustment made negative age fresh, potentially extending stale fake values
   until wall time caught up. Use CLOCK_MONOTONIC for the rootful TTL and require
   finite positive timestamps, now >= loadedAt and the existing exclusive two
   second boundary. Clock failure performs a one-shot read with loadedAt zero;
   matching-generation publication clears old cache rather than retaining either
   that result or an older snapshot that might reappear on clock recovery.

   Native cases cover warm reads, exact expiry, defensive negative-age rejection,
   failed clock, repeated failed-clock reads and cleared prior cache. No device
   timing or latency benchmark, suspend/resume experiment or clock failure rate
   is claimed. No clock read is added to the RootHide captured branch.

4. **Low / P1 defensive input fix — malformed LPM skips fallback.**
   PXGetBatterySnapshot sent boolValue to any non-nil LowPowerMode field. A plist
   container can throw; the existing catch prevents that exception escaping, but
   then bypasses the optional manager/default path and caches a partial snapshot.
   Accept NSString/NSNumber, matching the existing H6O manager scalar contract;
   unsupported values follow the existing missing-field fallback. Level parsing,
   float bounds, field precedence, optional manager calls and default NO remain.
   A native container case checks fallback fills only LPM, without a level getter.

5. **Low / P2, potential exceptional-lifetime issue — own ARC references.**
   Add named path/dictionary/field/manager slots with explicit finally cleanup,
   and release them before resetting the existing TLS reentry depth. The depth
   guard remains set through cleanup. Ordinary read exceptions were already
   caught and reached the old depth decrement; this is not evidence they previously
   poisoned TLS. Explicit cleanup addresses own reference lifetime under ordinary
   ARC configurations without implicit exception cleanup. No measured device leak,
   foreign callee/destructor guarantee or allocator-failure recovery is asserted.
   The fixture checks read exceptions and singleton reentry restore the guard;
   it does not measure heap leaks or prove arbitrary throwing collaborator safety.

## Behavior and performance boundaries

RootHide's PXGetBatterySnapshot captured branch is byte-for-byte unchanged,
including its existing NSDate loadedAt field, captured artifact precedence and
runtime-ID fallback. Its production path does not use the live cache/path/clock.
The standalone fixture exercises its captured result separately from testing the
otherwise unused shared path helper. RootHide constructor/scope/injection and the
iOS 15.8.8/AIDA64 cold-bootstrap correction are untouched.

The three actual hooks, original-call guards, observer registration, LPM event
posting, BatteryManager H6O implementation, package/Makefile/dependencies, source
writers and writer manifest remain unchanged. Existing rootful reentry returns
last/empty snapshot without invoking the manager again. Read exceptions retain
existing partial-result policy. No synchronous disk work is moved to another
thread and no production queue/timer/polling, provider or persistence call is added.

Warm rootful snapshot reads keep one clock call and one short scalar-cache lock, with no
profile lookup. Finite/generation checks have expected low relative overhead,
unmeasured. Cold path removes one active-selection resolution (one current plist
read, or two with legacy selection fallback) and duplicate base path construction.
Avoided cost can be moderate on a disk miss, but this is source-flow reasoning,
not benchmark evidence. Invalidation and publish locks contain scalar operations;
file I/O, manager work, callbacks and ObjC object release remain outside them.

Cache reads can linearize at their short lock capture before a later invalidation.
Same-generation concurrent loaders still use last-writer-wins; warm freshness
without a notification remains TTL-based. Independent manager authority and
partial-field mixing, common manager cache synchronization, repeated synchronous
manager I/O, unsynchronized gHavePostedLPM/gLastPostedLPM and notification ordering
remain separate work. No claim of global profile/cache/event atomicity is made.
Full Patch 4/H5S-partial remains partial; later rollout stages are still pending.

## Verification

- Windows regression: 62/63 Python suites and 4/4 Node suites passed. The remaining
  test_keychain_bridge_retirement.py suite has the established Git Bash
  mkdir /c/Users/ADMIN permission failure (4 failures, 1 error, 1 skip).
- Artifact source contracts, Phase-10 source hardening, RootHide static build and
  metadata/negative controls 6/6 passed. git diff --check passed.
- Four fragment generators completed. New snapshot globals, clock/cache helpers,
  TLS declaration and three snapshot/path/invalidation bodies are extracted exactly
  and uniquely, with dependencies defined before use.
- Restoring the admitted helpers and removing their added imports/global/clock
  reconstructs HEAD BatteryHooks exactly; the captured RootHide branch matches HEAD.
- Ten in-memory negative source controls reject double selection, wall clock,
  negative-age acceptance, stale/ignored publication, missing epoch increment,
  missing depth/reference cleanup, invalid-clock retention and unsafe bool access.
- Captured recipes include rootful/RootHide x both ARC exception modes for the
  new snapshot fixture at -O0. These are command/fragment checks only: no compiler
  or native binary was executed on this Windows host. New fixture assertions,
  Foundation/Theos builds and device behavior require macOS CI/device verification.

No new native/build/device pass, commit, push or deployment is claimed.
