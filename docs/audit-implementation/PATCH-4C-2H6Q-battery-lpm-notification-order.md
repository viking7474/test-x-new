# Patch 4C.2H6Q — Battery LPM baseline and notification ordering

2026-11-06: user confirms H6P build passes and authorizes continuation. Reviewed
the complete BatteryHooks flow, BatteryManager/header, existing source gates and
H6P cache/fixture. This batch addresses notification-state ordering shared by
rootful and RootHide. Common BatteryManager synchronization remains separate.

## Findings and changes

1. **Medium / P1 — unsynchronized LPM baseline, potential concurrency defect.**
   TLinkIOSTweak/BatteryHooks.x, batterySettingsChanged and constructor baseline.
   Both accessed gHavePostedLPM/gLastPostedLPM without synchronization. Callback
   comparison also used a pair copied before scope/provider work. Two callbacks
   could compare against the same old baseline, enqueue duplicate notifications,
   or finish in reverse order and restore an older value. A constructor seed
   could overwrite a baseline that a callback had already established.

   There is no explicit shared-thread contract in these consumers. The raw state
   accesses and ordering gap are established by source inspection; actual overlap
   depends on notification delivery and initialization threads. No guarantee about
   Apple's Darwin delivery threads, device occurrence or failure rate is claimed.
   The controlled native fixture exercises overlap/reentry using real worker
   threads and direct calls into the exact callback, not Darwin transport.

   Add PXObserveBatteryLowPowerMode. All production baseline reads/writes now use
   gBatterySnapshotLock, including comparison against the latest accepted value.
   Baseline seeding is conditional on it still being unknown and is always silent.
   A missing snapshot or disabled spoofing never establishes a baseline. First
   unseeded observation still posts once; equal later values still deduplicate.

2. **Medium / P1 — callback receipt must precede external work.**
   PXInvalidateBatterySnapshot now returns the generation that it increments and
   clears under the existing lock. batterySettingsChanged claims that receipt
   before runtime-read capture, scope invalidation/check or snapshot/provider work.
   Only a matching receipt may update baseline or submit an event. This closes a
   gap left by H6P: H6P rejected invalidated disk loaders, but notification state
   was independent; RootHide's captured reader intentionally bypasses that cache.

   Example: A captures NO and pauses, B invalidates and accepts YES, A resumes.
   A may not replace YES with NO or enqueue a reverse transition. Constructor seed
   similarly captures the generation before scope/provider work; it cannot replace
   a newer callback's baseline even if it resumes later. Already accepted changes
   are not retroactively cancelled when another callback starts. An unavailable
   newer read can leave the last known accepted baseline intact until a later
   available observation, matching the existing no-result behavior.

   Callback cache invalidation moves before scope invalidation, so even capture/
   scope preparation cannot allow an older handler to acquire a newer receipt
   after reentry. Scope/provider work remains outside the lock. The seed helper
   retains the original scope/read-operation boundaries: no new outer captured
   operation or asynchronous bootstrap is introduced.

3. **Medium / P1 — state decision and event submission need the same ordering.**
   Independently locking the bool assignment then dispatching outside the lock
   would still allow A's accepted YES and B's accepted NO to submit in reverse
   order. Submit the existing capture-free dispatch_async main-queue block inside
   the decision lock. The block contains only the existing notification call,
   NSProcessInfo object and notification name; it captures no candidate/manager/
   provider object. There is no dispatch_sync or waiting under this lock.

   Actual observer execution is asynchronous on main, outside the producer's
   critical section. It may briefly contend with a producer, but no lock is held
   across observer execution, file I/O, manager lookup or scope checks. Submission
   can allocate an internal dispatch item while locked; this deliberate bounded
   tradeoff preserves submission order without adding a queue or cancelling and
   coalescing accepted events. A slow main queue still delays delivery as before.

   A sequential accepted NO -> YES -> NO -> YES still submits three notifications
   in that order, even if delivery has not drained yet. Notifications retain their
   original no-payload behavior: an observer querying the getter sees its current
   authority, not an attached historical value. Superseded work which had not yet
   been accepted is now rejected; this is the intended race correction.

4. **Low / P2 — unused duplicate state flow.**
   Remove PXMaybePostLPMChangeNotification, which had only a definition and no
   active callers in the repository. Its separate unsynchronized comparison/post
   logic is replaced by the shared admission helper used by the real callback
   and seed flow. This reduces maintenance duplication; no runtime speedup is
   attributed to deleting an unused static function.

## Compatibility, performance and remaining scope

The LPM fix applies to both schemes. RootHide's complete captured snapshot reader,
rootful H6P snapshot/path/clock/loading/publication, the three getter hooks and
original calls are byte-for-byte unchanged. Constructor hook installation, process
scope gate and the three Darwin observer registrations are unchanged; only the
existing final baseline block calls the new synchronous seed helper. The
RootHide iOS 15.8.8/AIDA64 cold-bootstrap correction, injector/package dependencies,
Makefile, common managers, source writers and manifest are untouched.

No additional disk/provider requests, timers, polling, production queue or logging
are added. Seeding gains one scalar cache read/lock. Each available callback adds
one decision critical section and submits only a first/changed accepted value.
The existing cache lock is shared with snapshot readers, so concurrent readers can
briefly contend with notification enqueue. Expected ordinary overhead is low
relative to existing scope/snapshot work, with no latency/CPU benchmark claim.
Reducing duplicate event work is a correctness consequence, not measured savings.

NSInvocation allocation/ABI checks and dead scope helpers in the enable gate,
BatteryManager raw-ivar concurrency and repeated synchronous reads, optional
manager independent profile authority, same-generation cache winners and missing
notification/TTL freshness remain separate. Exceptions thrown by notification
observers retain the existing propagation policy on main; no broad catch is added.
This is not a global profile/source/event transaction or a proof of Darwin
transport, captured-operation binding, device hook behavior or leak freedom.
Full Patch 4/H5S-partial and later rollout stages remain unfinished.

## Verification

- Windows regression: 62/63 Python suites and 4/4 Node suites passed. The remaining
  test_keychain_bridge_retirement.py suite has the established Git Bash
  mkdir /c/Users/ADMIN permission failure (4 failures, 1 error, 1 skip).
- Artifact source contracts, Phase-10 source hardening, RootHide static build and
  metadata/negative controls 6/6 passed. git diff --check passed.
- Four fragment generators completed. The new fragment contains both exact static
  state declarations and the three exact admission/seed/callback bodies; the
  existing snapshot fragment contains the exact returning invalidation helper.
  Dependencies are defined before use and definitions are unique.
- Restoring admitted invalidation/notification/seed regions reconstructs HEAD
  BatteryHooks exactly. Snapshot reader/RootHide branch and hook/install regions
  are preserved; the enqueue block is checked to have no local/object captures.
- Twelve in-memory negative source controls reject missing generation/lock/seed
  guards, duplicate-event admission, unordered enqueue, missing baseline update,
  late callback receipt, missing seed receipt, unavailable-result admission,
  wrong seed/event modes and restoration of the dead raw-state flow.
- Extended exact-source native fixture specifies silent seed, disabled/first/equal
  cases, three pending transitions without coalescing, old callback/newer-worker
  ordering, slow seed, scope reentry, unavailable/recovery, 64 equal and 64 mixed
  concurrent admissions and observer reentry. Existing snapshot/path/clock tests
  stay in the same fixture. Test counters avoid overlapping unsynchronized writes;
  concurrent admissions use the production state lock and a separate fixture job
  lock, while provider tests use bounded semaphore handoffs.
- The fixture substitutes a deterministic enqueue adapter and notification center:
  it verifies main-queue selection, queued-not-inline behavior, submission values,
  main-thread manual delivery and reentry. It does not run the actual main queue,
  real NSNotificationCenter observers or Darwin notification delivery. Fixture
  values recorded for order are test-only and add no production notification data.
- Captured recipes retain rootful/RootHide x both ARC exception modes at -O0,
  compiling both exact fragments in the existing battery fixture. These are
  command/fragment checks only: no compiler or native binary was executed here.

Foundation/xcrun/Theos and an iOS device are unavailable on Windows. New native
assertions, builds, actual notification delivery and device behavior require
macOS CI/device verification. No new native/build/device pass, commit, push or
deployment is claimed.
