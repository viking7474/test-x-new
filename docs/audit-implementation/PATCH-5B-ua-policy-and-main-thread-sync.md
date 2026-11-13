# Patch 5B — UA policy packet and main-thread WebView sync

Date: 2026-11-13. Baseline `e61d769` (Patch 6A): user confirms build passed.
This batch covers the active UA policy and optional HTTP/JS sync flow in
`TLinkIOSTweak/IOSVersionHooks.x`. It does not close the full audit, Patch 4,
movement engine, backup roadmap, or device acceptance. Writer enrollment stays
H5S-partial. No package, dependency, hook admission or bootstrap changes.

## Findings and changes, in priority order

| Priority / severity / confidence | Before, impact and reproduction | Implemented correction / relative cost |
| --- | --- | --- |
| P1 / High / actual wrong-thread access | Sync iterated WebViews on its worker and read `wv.URL.host` before sending setters to main. Enable sync, modify a request UA from a background thread and inspect WebView property access. | Weak registry, strong enumeration and URL/setter/evaluation all run on main. Removes one serial queue and the worker-to-main fan-out; required O(live views) iteration now runs on main. This is correctness, not an asserted latency win. |
| P1 / High / potential lifetime race | `NSPointerArray` yielded raw weak pointers that were bridged after separate loads. A view could disappear between lookup and strong promotion. Registration also captured a strong view until worker execution. No observed device use-after-free is claimed. | Main-owned weak, pointer-identity NSHashTable; promote once during weak registration, enumerate strong `allObjects` only when executing the main job. Pending jobs do not hold individual WebViews. Low bookkeeping cost per live view. |
| P1 / High / potential data race | Debug fields, valid bits and three wall-clock caches were shared without synchronization across request, UI and notification threads. Readers could see partially updated debug settings; a loader could republish after invalidation. | One POD packet under a short C-only unfair lock for rootful; monotonic exclusive one-second TTL, epoch/revision before providers and conditional publication. No Objective-C providers, collections, destruction or dispatch under the lock. Low lock overhead; concurrent cold builds can still duplicate preparation. |
| P1 / Medium / actual ordering defect | A queued UI job could apply old UA after settings/profile invalidation. The old callback cleared only a write-only host map, not work already queued. | Capture epoch before UA request providers, check before job policy/registry access and every view, then again after setter and before JS. Optional policy/provider exceptions are contained in the async job. Low bounded scalar checks. Already-entered setters cannot be undone; epochs do not atomically serialize external notifications with WebKit execution. |
| P1 / Medium / actual registration defect | Views were registered only if sync was enabled during initialization. Later enabling sync missed those still-live views. | Weakly register every view created through the hooked initializer, even while disabled. Disabled policy performs no setters/evaluation. Duplicate registrations deduplicate by pointer identity. Views created before hook installation remain undiscovered. |
| P1 / Medium / actual stale-host window | Worker matched a host, then a later main job could modify a navigated view. A setter may itself synchronously navigate. | For applyAll=NO, check current main-thread host before setter and again before JS; invalidation during setter skips JS. applyAll=YES keeps the existing cross-host behavior. Native evaluation is asynchronous; navigation after submission still requires device observation and is not made atomic by these checks. |
| P1 / Medium / actual serialization defect | Manual escaping handled backslash and single quote only. Newlines/control characters in an accepted UA could produce invalid JS source. | Encode UA through a JSON string literal and escape U+2028/U+2029 for older JS parsers. Keep the same navigator.userAgent getter/configurable policy. Small extra JSON allocation only when JS injection is enabled. |
| P1 / Medium / defensive lifecycle change | Sync and canonical setters reset TLS to NO instead of restoring an outer state. Malformed present preference arrays/dictionaries/NSNull received `boolValue` and could throw. | Restore previous TLS in finally, including exceptions; accept NSNumber/NSString boolean semantics and otherwise use each established default. Malformed-present values do not fall through to another authority. Low cost. |
| P2 / Moderate avoidable I/O / actual source evidence | Each debug key independently loaded the same dictionary, often constructing separate defaults suites. Mobile/sync/trace/application settings repeated this work. | Rootful cold packet probes the two paths once in established order and constructs one suite; missing fields fall back per key. Warm hits do no file/suite work. RootHide reads only its lexical captured securitySettings view and memoizes the POD there. No claimed measured CPU or latency reduction. |
| P2 / Low to unbounded storage / actual dead flow | Static host lookup/unregister helpers had no callers; the host map and last-UA variable were written/cleared but never consumed. The map could grow with distinct hosts. | Remove write-only map, last-UA root, unused helpers and registry queue. Keep diagnostic event name `UASync.remember` for compatibility; the actual apply call remains. No public Objective-C API is retired. |

Main ownership follows Apple's documented
[WKWebView main-actor declaration](https://developer.apple.com/documentation/webkit/wkwebview).
Weak storage uses [NSHashTable](https://developer.apple.com/documentation/foundation/nshashtable)
with explicit weak memory and pointer personality; tests use a Foundation facade,
not real WebKit.

## Authority, preservation and practical limits

- Rootful retains file path precedence (the first dictionary wins, even empty),
  per-key missing-value defaults fallback, all existing flags/defaults and
  one-second caching. Packet construction still performs synchronous cold I/O.
  A delayed main job can encounter a cold rootful packet. Eliminating this I/O
  requires a separate authority/publication design, not an extra queue assumed
  to be faster.
- RootHide policy now derives only from the captured runtime `securitySettings`
  dictionary, with no live file/defaults/clock fallback. The existing publisher
  includes that whole dictionary, not a UA key whitelist. Pending/invalid views
  use established flag defaults; old views retain their memo, new views derive
  independently. This deliberately removes RootHide's remaining live-UA-policy
  fallback. External defaults-only edits require source publication/refresh to
  become visible; uncoordinated cfprefsd/direct writers remain part of the
  incomplete Patch 4 authority rollout. Device tests must verify the actual
  supported toggle/publication path before claiming end-to-end acceptance.
- Invalidation during a rootful build rejects stale publication and returns pure
  defaults for that canceled read. The next read can reload. A competing builder
  in the same epoch uses the winning packet; no single-flight wait is added.
- Preserve current request hook admission, UA normalization, Safari/Auth scope,
  sensitive-host exemptions, FullSpoof testing, header modification/JS-only
  policies, and ordinary enqueue order. No latest-request or per-host coalescing
  is introduced. Request bursts can still queue repeated main/JS work; log I/O
  retains the existing optional serial log queue, formatting and rotation.
- Snapshot registry on execution rather than per-view enqueue. Registration from
  background is weakly queued to main. No caller blocks waiting for main.
- Settings/profile observers now invalidate one scalar packet/epoch; they do not
  touch a UI collection on a notification thread. Registration lives for the
  process, with zeroing weak entries rather than per-view dealloc swizzles.
- Reporting cache state, getIOSVersionInfo and the three reporting getters,
  kernel/CF/bundle/file transforms, ctor/destructor and RootHide iOS 15.8.8/AIDA64
  cold-bootstrap behavior are preserved. No Makefile/dependency/architecture
  change is needed; shared sync fixes apply to rootful and RootHide.

## Verification

`test_ua_policy_and_sync.py` extracts the exact packet/cache/builder and sync
regions, plus the real freshness helper. Only preference file/default provider
names are substituted. Native recipes compile at -O0 for rootful/RootHide x plain
ARC/ARC exception cleanup, against Foundation/CoreFoundation. The facade asserts:

- Defaults, all hook/scope flags, typed malformed values, legacy strings, sync OR,
  first-file/empty precedence, per-key fallback and cold/warm provider counters.
- One-second exclusive TTL, unavailable/rollback freshness, canceled publication,
  recursive providers, provider exceptions/guard reuse, concurrent whole packets,
  and RootHide per-view memo/isolation with no file/default suite/clock calls.
- Main-only UI access, duplicate and disabled registration, later enabling,
  apply-all/JS-off, invalidation before job/during setter, navigation before job
  and during setter, per-view failures and queued provider exceptions.
- Nested TLS restoration on normal and exceptional exits, immutable queued inputs,
  JSON roundtrip for quotes/slashes/newlines/control/Unicode separators, weak
  registration/queued job ownership, background callers and pool-drained views.
- Policy builder/typed helper input release after an injected defaults exception
  and pool drain, including plain ARC mode.

Windows: 66/67 Python suites and 4/4 Node suites. The sole failing Python suite
is the established Keychain retirement Git Bash `mkdir /c/Users/ADMIN` permission
failure (4 failures, 1 error, 1 skip). Source hardening, RootHide package/static
checks, exact fragment generation, macro arity, four compile/run recipe captures,
20 negative source controls and diff checks pass. Recipe capture does not execute
a compiler or binary. No local Foundation, xcrun, Theos or device tests are
available; new native checks, Logos and arm64/arm64e packages await macOS CI.
No benchmarks or measured leak/latency claims are made.

## Movement assessment and remaining work

Repository search finds movement start/update/stop definitions, header and one
internal forwarding call, but no external in-repo caller. This is insufficient
to retire dynamic/public Objective-C APIs. They remain unchanged. The tail has
potential unbounded interpolation, index/startIndex inconsistencies, run-loop and
timer ownership, callback-under-lock and per-tick persistence concerns; these
need a complete owner/run-token design and caller contract rather than a lone
speed guard. Full movement implementation and profiling remain pending.
