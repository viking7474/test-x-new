# Patch 4C.2H6S — BatteryManager cache, readers and captured writers

2026-11-06: user confirms H6R build passes and asks to implement more connected
items in one batch. This batch covers the manager's cache ownership, load order,
pending reads, setter/generation/adoption flow, immutable write records, bounded
repair, error publication and exceptional cleanup together. Read BatteryManager
and its header in full, its hook/IdentifierManager consumers, source mutation
implementation and the existing reader/preparation/source-owner fixtures.

## Findings and implemented changes

1. **High / P1, potential unsafe object access under concurrency.**
   common/BatteryManager.m, batteryLevel, loadBatteryInfoFromDisk, setters,
   generateBatteryInfo, adoptCommittedBatteryInfo and lastError. The old methods
   loaded/stored strong ivars directly or through nonatomic properties. A reader
   could load a pointer while another thread replaced/released it; ARC does not
   make that compound object-lifetime operation atomic. There was no common lock
   around own cache reads and writes. No device crash, TSAN or ASAN result is
   asserted; source inspection establishes the unsynchronized paths.

   All own accesses to level/LPM/loaded now use short @synchronized(self) regions,
   except initial values before publication. Capture retains the level with the
   bool/loaded/revision/mutation values in the same region. Own cache writers
   update their intended fields together. Parsing, validation, copy, random
   preparation, path/file reads, source ownership and notifications stay outside.

2. **Medium / P1, mixed cache observation and overwritten fields.**
   Independent raw level/LPM reads could describe different updates. Setter and
   generation paths also persisted by rereading shared cache after adopting a
   candidate. Another thread could change the level between setBatteryLevel and
   saveBatteryInfoToDisk, causing the old setter to save a different operation's
   value. Capture the resulting level/LPM tuple during the cache publication and
   build a separate immutable record from those values. Standalone save captures
   one tuple too. Later cache changes cannot relabel that record.

3. **Medium / P1, old file loads could replace new cache state.**
   loadBatteryInfoFromDisk now captures cache revision and a load sequence before
   selection/path lookup. Canonical, legacy and global fallback stay in their
   original order. Field conversion finishes outside the monitor; adoption checks
   both receipts inside it. A mutation invalidates older loads; a later load also
   revokes an earlier one even if completion order reverses. Empty/missing fields
   preserve H6O profile/global loaded/default distinctions and raw string spelling.
   No directory is created, source lease acquired or repair done by load alone.

4. **Medium / P1 correctness; Low/Moderate avoided I/O on the trigger.**
   A load starting after a writer published its candidate but before persistence
   finished could still reread the old source and replace that candidate. Track
   the current pending mutation. Loads while it is pending return before selection
   or artifact I/O, and do not adopt disk data. Getter repair cannot claim pending
   state either. Finishing an owned mutation clears its flag and advances cache
   revision; an older owner cannot clear a newer pending flag. Every writer's
   finally releases ownership on success, failure, early return and exception.

   Reads use the captured cache during that window, without waiting for the writer.
   Before the candidate is published this can be the prior valid cache, which
   linearizes before that publication. An invalid cache may return nil while work
   is pending rather than start a competing repair. After completion, disk-first
   reads resume, including after a failed save; the candidate is not an indefinitely
   authoritative cache. No TTL, polling, timer or production dispatch queue is added.

5. **Medium / P1, reentrant old preparation could reclaim the cache/source.**
   Mutations claim a sequence before foreign copy/provider work. Cache publication
   accepts only its current owner. A later setter/adoption can supersede old input
   copy, generation or record-building work; the old request does not publish or
   start obsolete persistence. Records carry an explicit mutation receipt into
   persistBatteryRecord:mutation:. Recheck at entry, after lifecycle acquisition
   before target lookup, and immediately before staging in the existing source
   callback. The legacy private persistBatteryRecord: wrapper remains available.

   Accepted staging/commits are not retroactively cancelled. Once admitted, an
   operation may complete its captured source/mirror/notification effects while a
   newer local mutation exists. Cache receipts are not a global source commit CAS.
   Source lease/journal still controls actual filesystem ownership; no cache monitor
   is held while acquiring it. Checks inside the source callback take only a short
   cache monitor; own monitor regions never wait for a source lease/gate.

6. **Medium / P1, obsolete getter repair and redundant cache reassignment.**
   batteryLevel captures the loaded level/revision, validates in float precision,
   and conditionally claims repair only if that exact cache is still current and
   no mutation is pending. Its private generation helper publishes/saves once with
   that receipt. The getter no longer assigns the public generator's return back
   over a newer cache update. If superseded, return one latest valid cached level
   or nil; no retry loop or second repair. Exact 0.01f/1.0f, finite checks, ordinary
   parsing and the actual weighted generator remain unchanged.

   Public generation still returns its candidate when persistence fails or its
   preparation is superseded. Automatic getter repair intentionally uses the
   receipt-aware private generator; external overrides/hooks observing only public
   generateBatteryLevel may no longer observe that internal repair call. No such
   production subclass/override exists in this repository. This is a compatibility
   boundary, not a claim that arbitrary external overrides are preserved.

7. **Medium / P1, error lifetime and completion ordering.**
   lastError now reads a retained error through custom monitor-protected accessors.
   Receipt-aware publication ignores a result from an older mutation, including an
   old success clearing a newer error. Error replacement defers the previous root's
   final release until after monitor exit. Internal publication uses a raw protected
   ivar store instead of calling property methods/KVO or subclass callbacks under
   the monitor. The private property setter still exists and enters the same
   protocol outside its capture lock.

   Internal error updates no longer rely on automatic KVO for the private error
   property; the public API promises lastError reads, not private KVO notifications.
   No in-repository error KVO consumer was found. Local/Darwin battery success
   notifications retain their existing delivery/failure policy and are unchanged
   by this choice. lastError is the current cooperative mutation's shared result,
   not thread-local status or a per-call completion object. Independent raw private
   saves sharing one mutation lineage are not given a separate attempt order.

8. **Medium / P1 defensive input ownership.**
   setBatteryLevel copies NSString input before cache adoption; nil still clears
   without saving. Immutable strings retain original spelling/range policy.
   Unsupported roots/unusable copies are ignored rather than poisoning cache.
   Committed adoption validates dictionary/scalars and freezes/normalizes string/
   numeric levels with typed LPM handling before one paired publication. Valid
   committed records remain cache-only. Unexpected incomplete/malformed adoption
   is ignored. Claiming a mutation still revokes older pending work even if the
   new input is rejected; ordinary valid-input behavior is preserved.

9. **Low / P2, release/callback and exceptional cleanup.**
   Displaced level/error roots have precise retained lifetimes outside the monitor,
   so their dealloc callbacks cannot run inside the pair swap. Own preparation
   references and pending ownership clear in finally. No new block capture cycle,
   observer, timer, FD or long-lived queue is introduced. Source mutation/lease
   invalidation remains in its existing finally. This does not establish arbitrary
   foreign callee/destructor exception safety, heap leak freedom or complete
   exceptional cleanup of the unchanged source-owner implementation.

## Source behavior and compatibility

Common implementation changes apply to rootful and RootHide. BatteryHooks is
untouched, including H6R enable ABI checks, H6P captured/rootful snapshot logic,
H6Q event ordering, all hook/original calls and the complete constructor. Manager
singleton/init, path resolver, public weighted generation wrapper, committed
publisher and legacy mirror bodies compare exactly with HEAD. UIDevice monitoring
and its existing initialization/thread assumptions are not changed in this batch.
No bootstrap, scope, injector, dependency, Makefile or deployment target change.

The source persistence body reconstructs HEAD after removing receipt checks and
mapping conditional error stores back to old assignments: lifecycle -> pending
journal -> canonical target -> existing identity mutation -> staged source commit
-> lease release -> best-effort mirror remains. Global-only no-selection policy,
invalid/missing target rejection, no-new-device-IDs policy, mirror precision,
source-success despite failed mirror and post-source notifications remain intact.
Existing source-owner tests stay, with a real commit checkpoint assertion added:
a newer cache/error adoption survives old source completion while the captured
source and mirror still match.

The writer manifest adds the actual receipt entry point and clarifies cooperative
per-instance cache coverage. Enrollment status and 4C.2H5S-partial marker do not
advance. Source-writer source tests inspect the actual new staging method rather
than the compatibility wrapper; they do not weaken lifecycle/staging checks.

Receipts cover this instance's own methods. Other instances/processes, direct
KVC/private ivar edits, external mutable objects violating copy conventions and
incompatible foreign method overrides do not join the protocol. Cache is not
profile-tagged: independent active-profile authority can still change during a
read/save without a cooperative mutation. Global selection/source/cache ordering,
post-release mirror convergence and eventual process publication remain separate.
Separate public getters are separate observations. Caller-thread local notification
delivery and ordinary observer exception propagation are preserved, not converted
into a main-thread guarantee. Full Patch 4 and later rollout work remain partial.

## Performance

Pending reads avoid selection and canonical/legacy/global file operations instead
of rereading a source known to lag the current writer. Relative avoided cost can
be moderate for those reads, especially under reentry; no frequency, CPU or latency
benchmark is claimed. Own state publication uses scalar fields and retained roots,
not a freshly allocated dictionary on every cache observation. New counters,
monitor entries and reference retention add expected low/moderate overhead relative
to the existing synchronous reader path; contention is unmeasured.

Outside pending ownership, getters still reload disk on every request. The
IdentifierManager display's redundant explicit reload and independent hook/manager
fallback authority remain unchanged. No assumption-based TTL, async I/O or scope
cache is introduced. Ordinary generation weights, formatting and one intended save
are retained; superseded requests avoid obsolete writes and repair attempts.

## Verification

- Windows regression after adapting the source-writer scanner: 62/63 Python suites
  and 4/4 Node suites passed. Remaining test_keychain_bridge_retirement.py has the
  established Git Bash mkdir /c/Users/ADMIN permission failure (4 failures, 1 error,
  1 skip). Phase-10 source hardening and RootHide static/metadata 6/6 passed.
- Four fragment generators completed. Cache/reader/prepared/owned bodies are exact,
  unique and declared before use. All facades explicitly declare/synthesize the
  error root and four counters needed by the expanded common helpers.
- Source checks confine own raw cache access to initialization/monitor helpers,
  keep copy/conversion/I/O/providers/notifications out of critical regions, and
  verify finish on all writer exits. Eighteen negative source controls reject
  broken receipts, pending/read guards, record capture, repair, error ownership,
  deferred lifetime and cleanup. These are source checks, not native execution.
- New native cache fixture specifies reversed loads, setter/adopt races, pending
  read I/O suppression/recovery, reentrant input/record/provider work, bounded
  repair, errors completing late, exception cleanup, notification ordering,
  256 concurrent pair updates/captures, error property reentry and discarded-root
  dealloc reentry. Backends are controlled stand-ins, with real worker handoffs;
  mock file/counter accesses are serialized and the pair stress uses an atomic
  failure counter. This is not a TSAN/ASAN or real filesystem stress result.
- Existing reader fixture retains precedence, malformed fields, scalar conversion,
  mutable input, exact float endpoints and repair cases with the new receipt
  contract. Existing owned fixture retains real lifecycle/source rollback/mirror/
  namespace tests and adds the real commit-checkpoint cache/error case.
- Captured recipes include rootful/RootHide x both ARC exception modes at -O0 for
  the new cache fixture, alongside the expanded reader and existing real source
  variants. Foundation/CoreFoundation are explicit. No compiler or native binary
  was executed on this Windows host. git diff --check passed.

New native assertions, Theos builds and device behavior require macOS CI/device
verification. No new native/build/device pass, commit, push or deployment is claimed.


## Build follow-up: WiFi observer owner qualifier

The reported macOS compile failure is in the previously existing WiFi registration
body extracted into PXOwnedWiFiMethods.inc. In that block, typeof(weakSelf) carries
a top-level const qualifier on the captured binding; its strong local owner cannot
then be assigned nil in finally. This is a shared source/compiler typing problem,
not a rootful-only dependency or a Battery cache-layout failure.

Use an explicit `__strong id owner = weakSelf;` local in WiFiManager.m. It retains
the same live instance, invokes the same declared handler and clears owner/note
in the same finally, while avoiding inferred const. Keep the weak capture,
idempotent token registration, notification name and main operation queue.
No newer typeof-unqualifying language extension or cached class/IMP is needed.
Other strong typeof(weakSelf) locals were inspected: they are not reassigned, so
there is no reason to rewrite those declarations for this error.

The existing four-mode WiFi cache fixture now compiles the exact registration
body through PXWiFiObserver.inc with a distinct facade class, and specifies normal,
throwing, duplicate-registration and deallocated-weak-owner cases. Throwing mock
handler arguments have explicit cleanup so they do not create a false owner/note
lifetime failure. The real owned fixture's notification/dealloc tests remain.
No new binary/queue or production behavior is added for this regression test.

Local verification: 62/63 Python + 4/4 Node; the established Git Bash permission
failure remains. Source hardening/RootHide static/metadata 6/6, four generators,
exact owned/observer extraction, three negative controls, recipe capture and diff
checks pass. Production code outside registration is byte-for-byte unchanged;
H6S BatteryManager and BatteryHooks are untouched by this follow-up. Native
Foundation/Theos execution still requires macOS CI; no new build pass is claimed.
