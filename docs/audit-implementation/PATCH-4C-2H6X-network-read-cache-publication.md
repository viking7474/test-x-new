# Patch 4C.2H6X — Network connection/ISO/pinned/carrier read caches

Baseline `f57d71d`: user confirms the H6W build passed. This batch addresses the
four remaining process caches in NetworkConnectionTypeHooks together. It retains
H6W signal/radio logic and all actual hook/ctor code exactly. No new source writer
is enrolled; rollout remains H5S-partial and full Patch 4 is incomplete.

## Findings and changes

| Priority / severity | Source evidence / reproduction | Implementation / expected impact |
| --- | --- | --- |
| P1 / Medium potential | Connection mode, ISO, pinned region and carrier sampled NSDate and used wall-clock subtraction for 5/60-second freshness. Backwards clock adjustment could extend freshness. | Use the H6W CLOCK_MONOTONIC adapter and finite/nonnegative-age checks. Keep each original exclusive TTL: mode/pin 5s, ISO/carrier 60s. A valid nil pin remains a negative hit. Time remains anchored before provider work, as before. |
| P1 / Medium race | Each cache could read its input, receive invalidation, then unconditionally republish the old result. Two cold builders could also overwrite each other out of completion order. | Each cache has its own revision and scalar validity/time metadata. Capture before provider work; compare-and-publish under the existing lock. Invalidation revokes every revision. Provider/file/catalog work remains outside the lock. |
| P1 / Medium nested race | Carrier resolves pinned region before using/filling its carrier cache. Capturing a carrier revision after that nested call would allow a revoked old pin to become a new carrier publication. | Capture carrier revision and retained hit before entering the pinned provider. A notification during pin resolution revokes both the pin and the outer carrier publication. Keep pinned precedence even over a warm carrier cache. |
| P1 / Medium lifecycle potential | Invalidation set NSString/NSDictionary/NSDate cache roots to nil under an unfair lock. Replacement also released prior roots there. A final destructor that reentered the cache would deadlock. | Retain retired roots in explicit precise-lifetime locals under lock, clear/swap roots there, then release in finally after unlock. Native sentinels exercise destructor reentry on replacement and invalidation and ownership held by a reader. No observed Foundation deadlock on the user's device is claimed. |
| P2 / Low per call | Carrier warm hits constructed a fresh dictionary inside the lock from three strings; pinned updates copied three fields under lock. All schemes allocated dates and RootHide did unused global-cache work before returning captured values. | Publish one immutable carrier dictionary, retaining legacy copies of its three fields. Warm unpinned carrier returns that packet. RootHide derived readers use only captured-view memos and providers: no global cache lookup/publication, clock call or extra path read. No benchmark or aggregate CPU saving is claimed. Mode now boxes one scalar packet per miss; warm mode retains that packet and reads integerValue outside the lock. |
| P1 / Medium consistency | Enablement was a separate mutable BOOL from the returned mode. The cache representation could carry detached mode/enablement state across invalidation. | Encode disabled as -1 in the same mode NSNumber packet; the gate captures that packet. A losing mode builder adopts the current winner, including disabled, rather than returning obsolete enablement or bypassing spoofing merely because another cold reader won. If invalidation leaves no packet, return -1. This does not make every rootful nested hook operation a globally atomic snapshot. |
| P1 / Medium defensive lifetime | More provider boundaries are used while retaining a captured view, settings, strings and partial carrier fields. Plain ARC alone does not guarantee cleanup on arbitrary Objective-C exception unwind. | Use named strong roots and explicit finally cleanup in ISO/pin/mode/carrier adapters and carrier packet preparation. Propagate provider exceptions without claiming a cache revision. The new framework does not introduce heap callbacks or background work. |

## Preserved behavior

- Whole-record carrier order remains carrier_details, network_settings,
  device_ids; rootful uses the H6W fixed identity directory. Valid pin overrides
  remain first. Defaults, legacy uppercase keys, branding lookup, raw MCC/MNC
  spelling, ISO lowercase policy and missing/invalid mode Auto fallback remain.
- Pin absence is cached for five seconds on rootful and by NSNull on a captured
  RootHide view. ISO/carrier values may finish an already-running read after
  invalidation, but cannot repopulate a revoked shared cache. Mode instead adopts
  a current winner or discards stale enablement when none exists. There is no
  unbounded retry or single-flight wait.
- A pinned carrier still resolves the pin before deciding whether an unpinned
  carrier hit can be used. Pin expiry can therefore reveal an updated pin before
  the carrier's 60-second interval ends; the tests distinguish this from unpinned
  carrier TTL behavior.
- RootHide continues using per-view associations and captured profile artifacts.
  Invalidation does not rewrite the derived values of an already-captured view.
  No shared TTL substitutes for captured-view authority. The existing bootstrap,
  AIDA64/iOS 15.8.8 admission fix, packaging/dependencies and %orig flow are intact.

## Verification

`test_network_hook_state.py` retains the H6W suite and adds exact production
extraction of read-cache declarations/publication/invalidation and ISO/pin/mode
adapters. The existing carrier reader/packet and typed helpers are also exact
extractions. `PXNetworkReadCacheTests.m` uses real Foundation/Objective-C runtime
with controlled clock/settings/catalog/identity providers and real rootful
carrier fixture files. It covers:

- All four cache TTL boundaries, clock failure/recovery/rollback, revoked and
  newer publications, and nil negative hits distinct from misses.
- Four actual background/main publication interleavings, four reentrant
  provider invalidation/new-winner flows, and matching concurrent cold mode
  winners without an accidental real-value passthrough.
- Retired-root destructor reentry and a retained reader across invalidation.
- Per-consumer defaults, malformed inputs, scalar strings, branding fallback,
  copied mutable carrier fields, negative pin TTL and unpinned carrier TTL.
- Settings/catalog exceptions with weak settings roots after a pool drain and
  reuse after failure, in both ARC modes.
- RootHide globals deliberately containing poison values, zero clock/identity
  provider calls, no shared publication, memo reuse/new-view isolation and
  negative memo reuse.

Four new native compile/run recipes add rootful/RootHide-defined x plain ARC/
ARC exception cleanup at -O0, beside the four retained H6W recipes. Eight recipes
were captured on Windows, not executed. Both fixture CHECK arities, seven exact
fragment files, 20 new negative source controls and exact preservation of H6W
signals/radio plus the full hook/ctor tail are checked locally.

Windows regression: 63/64 Python suites, 4/4 Node. The established Keychain Git
Bash mkdir /c/Users/ADMIN permission failure remains (4 failures, 1 error, 1 skip).
RootHide static guard now checks the exact carrier reader for a single captured
operationView shared by memo and all artifacts, replacing the obsolete
runtimeView spelling check; five additional negative controls enforce this
exact-reader requirement (25 new controls total). Source hardening, RootHide static/package gates and
diff checks pass. This host
has no Foundation/xcrun/Theos runtime; the new native matrix and package/device
behavior still require macOS CI and device verification. Scope macros and
snapshot providers in these fixtures are facades, not the real runtime scope
engine, Logos preprocessing or Darwin transport. No local native/build/device
pass, allocation measurement or latency benchmark is claimed.

## Remaining scope

This is per-cache publication consistency, not a cross-cache transactional
snapshot of rootful preferences or multiple file contents. A reader can retain
its earlier captured value across invalidation; it cannot write it back. Already
captured RootHide views remain valid under their existing operation policy.
Private selector ABI/availability, legacy uninstalled CF adapter ownership,
logging frequency and later audit stages remain separate. Shared lock contention
has not been profiled, so no lock-free/single-flight redesign is introduced.
