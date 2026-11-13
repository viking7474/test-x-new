# Patch 5A — Active iOS reporting caches, policy and original delegation

Date: 2026-11-13. Baseline `6078d43`: user confirms H6X build passed. This is an
isolated implementation of the active reporting portion of Patch 5, including
its companion version-info cache. Patch 4/source-writer rollout remains
H5S-partial; this does not mark Patch 4, full Patch 5 or device acceptance complete.

## Findings and implementation

| Priority / severity | Evidence and impact | Change |
| --- | --- | --- |
| P1 / High potential lifetime race | Rootful UIDevice.systemVersion read/wrote a shared strong NSString and timestamp without synchronization. Another thread could replace/release the object while a reader used it; value and time could also belong to different updates. | One lock owns the result, retained version-info identity, bundle and timestamp/validity/revision. Prepare/copy outside the lock, retain captured roots under the lock, compare strings outside it and defer retired-root destruction until unlock. No observed device use-after-free is claimed. |
| P1 / Medium logic defect | mach_absolute_time ticks were compared directly with a nanosecond constant. The actual throttle depended on hardware timebase. | CLOCK_MONOTONIC seconds with explicit nanosecond conversion; retain the intended exclusive 100ms interval. The companion 30-minute cache also uses monotonic finite/nonnegative-age checks. Zero time is valid; clock failure cannot make an immortal hit. |
| P1 / High intent defect | Rootful returned a throttled value before scope checks, and invalidation did not clear that value. All three public reporting getters checked scope but omitted the IOSVersion toggle, although SystemVersion file/CF consumers and ctor diagnostics used that toggle. | Scope and current IOSVersion enablement are checked before a system-result hit. Cache only reported values; off/out-of-scope preserves the original method on every call. Both schemes honor the toggle in UIDevice.systemVersion and the two NSProcessInfo reporting getters. This is a deliberate correction of disabled behavior. |
| P1 / Medium stale publication risk | A version-info build could repopulate the 30-minute cache after invalidation; the cache had no identity key. A new profile could therefore reuse old info until TTL/notification. | Key rootful info by the retained PXIdentitySnapshot object. Capture info revision before any identity provider work; revalidate source identity and compare revision at publication. Capture system-result revision before policy/info providers, then key the 100ms result by the actual info object and bundle. Generation numbers are not assumed globally monotonic. |
| P1 / Medium potential original retry | Original getters were inside projection catch blocks. If an original or later formatting operation threw, catch/fallthrough could invoke original again. | Originals execute outside projection catches, with shared reporting TLS restored in finally. Rootful UIDevice retains zero original calls on an authorized matching warm hit; misses/passthrough invoke original once. RootHide retains its first-original/one-call policy. NSProcessInfo invokes original once, then projects or returns it. Original exceptions propagate without retrying that invocation. |
| P1 / Medium reentrancy risk | Policy, identity and fallback providers can call reporting getters; a direct recursive info load could also reenter its provider. | Shared thread-local reporting guard sends nested reporting calls to their original methods. A separate info guard returns unavailable for nested same-thread info requests. Other threads remain independent. No new single-flight wait/queue is introduced. |
| P1 / Medium malformed/lifetime defense | Rootful manager fallback was subscripted without checking root shape and accepted arbitrary non-nil required fields. Retained views/settings/partial strings relied on implicit unwind cleanup. | Freeze the five required nonempty NSString fields into an immutable packet, preserve optional fallback metadata, isolate mutable strings, and use named roots/finally in new adapters and publishers. Malformed fallback data now yields no projection. RootHide still never consults the live fallback manager. |
| P2 / Low per call, mixed tradeoff | Old verified warm system results skipped all policy work. Correctness requires current admission and identity checks before a hit. | Warm rootful paths add bounded snapshot/cache locks and admission checks while retaining zero original calls and avoiding parsing/fallback on a hit. The new admission helper uses the existing scope policy/options without amplifying per-query success logging. NSProcessInfo diagnostic logging is retained. No CPU/latency saving or benchmark is claimed. |

## Preserved scope and behavior

- Valid configured reporting remains upward-capable and uses the unchanged
  PXReportingIOSVersionBuildForBundle policy. Fix Version retains its narrow
  kern.osproductversion-only exception. Availability/capability methods are not
  hooked or fabricated.
- Raw version or formatted version/build parsing, explicit-build precedence,
  five-field primary completeness, rootful manager fallback and the 30-minute
  interval remain. Regex construction stays on a cold formatted parse; no new
  dispatch_once around foreign initialization is introduced as a micro-optimization.
- RootHide memoizes info on the captured view and has no shared result throttle
  or cache clock calls. An existing captured view retains its derived value;
  newer views derive independently. Common runtime/identity capture and lexical
  scope behavior are not changed.
- Both caches are revoked together by the existing notification handler and
  destructor. A read already in progress may finish its captured projection but
  cannot republish after its revision was revoked. This is per-cache consistency,
  not an atomic rootful cross-file/profile transaction.
- UA helpers/hooks/debug/sync queues, kernel/CF/NSBundle/file transformers and
  the complete ctor remain byte-for-byte unchanged. Bootstrap/install/package/
  dependencies and the RootHide iOS 15.8.8/AIDA64 cold-bootstrap fix are retained.
  Legacy unregistered hooked_sysctlbyname code, including its old timing patterns,
  is preserved pending the plan's separate call-graph/generated-artifact evidence.

## Verification

New `test_ios_reporting_cache.py` extracts the exact cache state/helpers,
preparation/admission/info functions and three Logos method bodies, adapting
only %orig calls to controlled original providers. It also extracts the real
reporting policy and its pure validators from PXRuntimeOSCompatibility.m.
`PXIOSReportingCacheTests.m` uses Foundation/Objective-C runtime with controlled
scope/toggle/snapshot/fallback/clock providers. It exercises:

- All three reporting surfaces, toggle/scope changes inside a warm interval,
  missing manager, invalid version, new profile/view and upward reporting.
- Exact actual-hook 99ms/100ms cases at an exactly representable origin, the
  30-minute boundary, clock conversion/zero/failure/rollback and info/bundle keys.
- Formatted build precedence, malformed fallback shapes, preserved optional
  metadata and isolation of mutable required strings.
- Original/projection/admission exceptions, exactly-once original delegation,
  post-exception reuse and weak captured identity/view roots after pool drain.
- Same-thread info recursion, cross-surface policy recursion, invalidation during
  identity acquisition and an unnotified identity switch before publication.
- Two actual background/main publication races, five-root destructor reentry,
  deferred info/system replacement and a retained info reader across invalidation.
- RootHide per-view memo reuse/new-view isolation, zero cache-clock calls and
  preservation of its one-original-call-per-system-query policy.

CI adds rootful/RootHide-defined x plain ARC/ARC exception cleanup at -O0.
Exact fragments, CHECK arity and four compile/run recipes were checked/captured
on Windows; no compiler or binary was executed here. Twenty negative source
controls cover clock/TTL/key/revision/policy/cleanup/reentry contracts. Protected
source slices verify UA/kernel/CF/bundle/file/ctor preservation.

Windows regression: 64/65 Python suites, 4/4 Node suites. The established Keychain
retirement Git Bash mkdir /c/Users/ADMIN permission failure remains (4 failures,
1 error, 1 skip). Source hardening, RootHide static/package gates and diff checks
pass. Native/Theos/device execution is unavailable on this Windows host; new
native assertions, Logos preprocessing, arm64/arm64e packages and device behavior
still require macOS CI/device verification. These fixtures use provider/scope
facades, not the real runtime scope engine or UIKit originals. No new native,
build, device or benchmark pass is claimed.

## Remaining work

Patch 4 writer enrollment/authority and full Patch 5 acceptance remain partial.
The fallback manager's internal threading/profile ownership, UA debug toggle
caches, WebView/queue lifecycle, private API ABI, logging profiling and legacy
inactive code retirement remain separate. Notification freshness still depends
on the existing scope/identity/runtime providers and publication protocol; a
cache cannot detect unpublished filesystem changes on its own. Device acceptance
should test Fake iOS on/off and scope/profile changes on RootHide iOS 15.8.8/AIDA64,
a supported rootful device, and both target architectures where available.
