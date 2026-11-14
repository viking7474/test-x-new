# Patch 5C — UA adapter delegation, re-entry and request fast path

Date: 2026-11-13. Baseline `5d0a339` (Patch 5B): user confirms build passed and
requests larger implementation batches. This batch covers ten active UA/WebView
adapter methods and their preparation chain in IOSVersionHooks.x. It does not
claim the full audit, writer authority, movement engine or profiling is complete.
Source-writer rollout remains H5S-partial.

## Ten prioritized changes

| Priority / severity / confidence | Evidence, impact and reproduction | Implementation / relative cost |
| --- | --- | --- |
| P1 / High / actual retry defect | Custom-UA, application-name and request setters called original inside projection catches. If native threw, catch/fallthrough called original again. A setter can mutate/notify before throwing, so replay can duplicate effects. Inject an exception in each original and count invocations. | Prepare a candidate under a projection catch; invoke original outside it. Original failures propagate once. Native nil results stay nil. Low control-flow overhead. |
| P1 / High / actual failure boundary | WebView init resolved native UA before original, then performed unguarded canonical preparation; four load methods prepared UA before reaching native. An optional UA failure could prevent successful construction/navigation. | Isolate optional preparation before/after init and before each load. Each original executes once; original exceptions are not swallowed. Preserve synchronous canonical setup before the first load when preparation succeeds. No async JS round-trip added. |
| P1 / High / potential lifetime issue | Prep/native callbacks can release the receiver's external owner. New post-native metadata work must not dereference a receiver that disappeared; prep can also drop the last owner before original. No observed device use-after-free is claimed. | Seven non-init instance adapters hold an explicit precise-lifetime receiver through preparation/native/post-work and clear it in finally. Init retains its returned object as before; class getters need no instance pin. Low retain/release cost; no receiver captured by a new async job. |
| P1 / Medium / potential recursion | Private UA, policy and scope providers can call intercepted methods. Repeating policy/normalization during that call can recurse or project twice. | Thread-local preparation guard shared across UA surfaces; nested preparation uses native behavior. The guard is restored in finally and is not held across ordinary external originals, so their legitimate nested calls can still prepare independently. Original code that directly recurses into itself is outside this guarantee. |
| P1 / Medium / actual metadata acknowledgment gap | Old custom-UA metadata marked ownership before native acceptance. Simply moving it after native would overwrite a newer reentrant setter's accepted base. Reproduce with native setter updating its value then invoking a callback that sets another UA. | Stage raw base and a per-view opaque intent token; adopt base/ownership only after native success and if that token is still current. Newer reentrant setter wins. Internal sync/canonical/preparation bypasses do not record external bases. One additional token allocation per participating custom setter, one bounded current token per view. Native partial mutation on a thrown exception cannot be rolled back safely; prior base/ownership remain. |
| P1 / Medium / actual cross-layer side effect | JS sync was queued before the native request header setter. A rejected header could therefore still change WebView JS UA. | Prepare immutable host/UA plus epoch, call native once, then enqueue optional sync after acknowledgment. Native failure produces no sync submission; sync failure after acknowledgment never replays the native setter or changes its success. Low copying/check overhead, with the existing main async apply path. |
| P1 / Medium / actual HTTP correctness defect | UA dispatch matched only exactly `User-Agent`, while other casing bypassed projection and JS sync. | Recognize all four managed names with case-insensitive comparisons. Preserve the caller's original field argument in the native invocation. Nil/removal, malformed input types and unrelated fields stay native. This intentionally fixes casing-dependent behavior. |
| P2 / Low-to-moderate avoidable work / source evidence | Every header set allocated an array/NSSet and a lowercased field, including unrelated headers. All calls entered runtime read scope. | Classify without an explicit collection/lowercase allocation; unrelated fields and nil/invalid values call native before runtime capture, URL, policy, scope, version or normalizer access. At most four string comparisons remain; Foundation internals are not assumed allocation-free. No benchmark claim. |
| P1 / Medium / potential exceptional retain leaks | New/active C preparation helpers retained parameters/partial roots across provider faults; an autoreleasing in/out slot can introduce hidden writeback lifetime. | Named input/result/URL/configuration/base/candidate roots with finally in preparation, native-base, synthetic, modified, canonical and exact-setter boundaries. Internal modifier uses an explicit strong NSString slot and exactly typed caller variables. This is not a proof against every exception inside Foundation or the unchanged normalizer implementation. |
| P2 / Low / actual duplicate work and cleanup opportunity | Debug admission queried multiple packets for individual fields. The real OS version was fetched solely for an argument the modifier never used. Master/sync wrapper functions became unreferenced after grouping. | Pass one copied debug packet into each debug scope decision, retain existing flags and central normalizer, use the established unused `native` placeholder, and remove only newly unused static wrappers. No regex cache or lock-free publication is introduced. |

HTTP field-name behavior is documented by Apple's
[NSMutableURLRequest setter contract](https://developer.apple.com/documentation/foundation/nsmutableurlrequest/setvalue(_:forhttpheaderfield:)).
The casing change is based on that contract, not a new header policy.

## Flow and behavior retained

1. Header classification is lazy. Managed identity headers retain the existing
   central locale/platform/mobile transformation and host admission. Only UA
   captures a sync epoch, before bundle/policy/scope/version provider work.
2. UA debug flags, JS-only, Safari/Auth stack, FullSpoof, sensitive-host exemptions,
   configured versions, Mobile build replacement and central normalization stay
   under their existing policies. The three managed identity headers continue
   using PXCanonicalWebIdentityHeaders. No capability/availability is fabricated.
3. Request preparation returns a candidate and strong, immutable sync output slots.
   Any preparation exception discards all outputs and falls back to raw native
   arguments. Diagnostic intent events, including UASync.remember, remain; they
   describe preparation, not a guarantee that native later accepted the header.
4. Native setters/loaders are outside projection catches. Deferred sync and
   metadata adoption are best-effort after native acknowledgment. Invalidating
   during preparation/native retains the old admitted epoch for the existing
   Patch 5B job checks; it never captures a newer epoch to revive old UA work.
5. WebView property work is main-only. Background calls still reach native with
   original arguments; this does not make an invalid off-main WebKit caller safe.
   Weak registry registration remains available for any successful constructor,
   independently of optional canonical preparation and sync enablement.
6. RootHide captured-view reader/policy and rootful policy packet are unchanged.
   Relevant request operations retain their read scope through native and sync
   submission; unrelated headers now have no projection scope to capture.
   Scope construction itself is not replaced by the new preparation catch.
7. Preserve the reporting cache region/getIOSVersionInfo/three reporting getters,
   kernel/CF/bundle/file tail, full ctor/destructor and the RootHide cold-bootstrap
   fix. No package/dependency/build flags or hook selector surface changes.

## Verification

`test_ua_hook_dispatch.py` extracts all ten exact Logos adapter bodies, the header
classifier/preparation region, canonical state and eight real preparation/scope
helpers. Native compilation adapts only original calls and dependency expressions
for controlled providers. PXUserAgentNormalizer.m is linked unchanged, so expected
header and UA output exercises its actual algorithm. The Foundation facade links
no WebKit; original validation and network/browser behavior are not simulated as
proof of actual platform acceptance.

Four native recipes: rootful/RootHide defines x plain ARC/ARC exception cleanup at
-O0. They cover:

- Exact native invocation counts and propagated exceptions for constructor, four
  loads, two setters, request setter and both Safari getters; return and argument
  parity, nil constructor/getter behavior, and preparation-failure fallback.
- Real normalization, UA casing, all three canonical identity headers, unrelated
  header burst with zero projection-provider/capture/URL work, nil and malformed
  native arguments, scope/debug/Safari-sensitive/FullSpoof policy.
- JS-only output, no sync after native rejection, contained post-ack sync failure,
  stale epoch preserved during a provider callback and discarded partial outputs
  after normalizer/trace/URL failures.
- Provider reentry, internal setter bypass, native callback reentry preserving
  newer metadata, guard restoration, and background UI passthrough with no added
  view property access.
- Pool-drained weak inputs/receiver after selected projection/native/exact-setter
  faults, and direct +1 receiver construction with the external owner removed in
  a provider/native callback. Receiver must remain live inside the callback and
  disappear after the call/pool. Mock originals use borrowed IMP-like parameters
  so their own C parameters do not manufacture a retain leak.

Existing Patch 5B epoch/sync/weak-registry tests remain enrolled. Its epoch source
contract follows the extracted preparation helper and additionally verifies sync
submission occurs after native. The old phase-9 token assertion now recognizes
the explicit classifier instead of requiring the retired NSSet variable; header
behavior has native fixture coverage.

Windows results: 67/68 Python suites, 4/4 Node suites. Only the established
Keychain retirement Git Bash `mkdir /c/Users/ADMIN` permission failure remains
(4 failures, 1 error, 1 skip). Source hardening, RootHide package/static gates,
exact extraction/CHECK arity, four compile/run recipe captures, 20 negative source
controls, protected-slice comparisons and diff checks pass. Recipe capture does
not execute a compiler or binary. New Foundation/ARC assertions, real Logos,
arm64/arm64e package builds and device tests still require macOS CI/hardware.
There is no local CPU/latency/leak benchmark or new device pass claim.

## Remaining acceptance

Run actual WebView construction, first/immediate load, raw/custom/nil UA setters,
case-varied headers, JS-only, sensitive login and profile/toggle transitions on
rootful and RootHide devices. Check third-party swizzles and native callback
ordering. Patch 5B burst main/JS backlog, cold rootful preferences, live defaults
publication authority, arbitrary native partial failures and navigation after JS
submission remain limited. Movement callers/full engine, full Patch 4 and later
profiling/release gates stay pending.
