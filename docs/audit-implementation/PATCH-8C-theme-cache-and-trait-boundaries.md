# Patch 8C — Theme cache, trait projection and runtime capability boundaries

Date: 2026-11-15. Baseline `d073756` (Patch 8B), whose build the user confirms
passed. Implementation is in TLinkIOSTweak/ThemeHooks.x. This batch covers six
adapter bodies, cache/policy/projection helpers, notification delivery and guarded
installation. It does not complete theme enablement authority, all of Patch 8,
profiling or release-device acceptance. Writer enrollment stays H5S-partial.

## Top ten changes by priority and expected impact

| Priority / severity / confidence | Finding, impact and reproduction | Change / relative cost |
| --- | --- | --- |
| P1 / High / actual nil failure branch | The three traitCollection adapters constructed @[originalTraitCollection, interfaceStyleTrait] without nil checks. A nil native/factory result raises instead of preserving native behavior. Inject nil at either boundary. | One PXThemeProjectTraits helper returns the identical native result on nil, unavailable factories, missing projection, nil merge or preparation exception. Adapter originals run once outside preparation catches; their exceptions still propagate. |
| P1 / High / potential recursive expansion | Scope/data providers or trait factories can query the very traits being projected. There was no shared preparation guard across six adapters, so nested calls could repeat policy, I/O and allocation. | Shared thread-local preparation guard covers policy and factory work; canonical bypass spans native style inspection and factories. Nested getters/trait projections preserve native, and both prior TLS values restore in finally. Low branch/TLS cost, no lock or cross-thread wait. Arbitrary recursion inside native originals is not repaired. |
| P1 / Medium / actual invalidation race | getThemeStyleFromProfile read outside its lock and unconditionally adopted afterward. A notification clearing cache during that read could be overwritten by the old candidate. Concurrent cold reads could similarly overwrite each other. | Scalar generation ticket issued on a cold miss; invalidation and newer cold reads revoke it. Rejected candidate neither repopulates cache nor supplies this invocation's override: return Unspecified/native. Latest-started cold read wins adoption; this is not a filesystem/source transaction. Low scalar-lock cost. |
| P1 / Medium / clock correctness | Rootful TTL used wall-clock NSDate subtraction; a backwards clock change could keep a theme fresh beyond the intended interval. | CLOCK_MONOTONIC seconds, finite/nondecreasing checks and the original inclusive 300-second boundary. Invalid clock permits a current uncached source result but never a fresh cache packet. Unknown nonempty themes remain Unspecified/uncached, preserving their repeated-read behavior. No timing benchmark is claimed. |
| P1 / Medium / actual mixed selection window | Rootful called PXActiveProfileIdentityPath and PXActiveProfileDeviceIDsPath independently. Both resolve the active ID through files; a selection change between them could combine one profile's IDs with another profile's sidecar. | Resolve identity directory once, derive device_ids.plist from it and read sidecar in the same directory. Removes a duplicated active-selection lookup on a cold read. Paths/precedence are equivalent for an unchanged selection. Does not pin directory/inodes or atomically capture file contents. |
| P1 / Medium / potential private API crash/surface fabrication | One Logos group installed six selectors together. The effective getter was labelled iOS 17 without proving runtime presence, and the private WebKit setter/ABI could be absent or change. | Six separately guarded groups; validate class/method, arity, receiver/SEL and return/argument types before init. Also validate both public trait factories and scalar getter before enabling projection adapters. Keep the effective getter's existing iOS-17 minimum and private setter's existing 0/1 mapping only when ABI matches. Unsupported entries skip; no method is fabricated. Type compatibility is not proof of private enum semantics. |
| P1 / Medium / exceptional lifetime risk | Helpers, adapter inputs, native traits, partial factory results and merge arrays had no explicit plain-ARC exception cleanup. Foreign policy callbacks may release a receiver's outside owner. | Named strong roots/finally and precise receiver pins for all six bodies. Strong out-slot captures bundle identity once for the scalar diagnostic. Native and caller exceptions are not retried. Selected receiver, snapshot/input and failed-merge partial trait oracles run after pool drain in both ARC modes. |
| P1 / Medium / notification and constructor fault ordering | themeSettingsChanged invalidated scope and logged before clearing theme cache; either exception could prevent invalidation. Constructor logs could abort installation or throw again from its catch. | Invalidate scalar cache first, independently contain scope/log faults and keep a local callback pool. Constructor informational/error logs use a nonthrowing wrapper; identity/process roots clear in finally. Observer topics, admission policy and initial synchronous execution remain unchanged. No new worker or retry. |
| P2 / Moderate source-proven avoidable work | RootHide created NSDate and acquired/read/wrote the global cache although its TTL branch was disabled and it always read the operation snapshot. | RootHide profile read uses one captured runtime view and no theme clock, theme-cache lock, cached NSString copy or live file fallback. Keep deviceIDs then deviceTheme artifact and missing-data Light default. Rootful global cache holds enum/time/generation only; no foreign method or object release occurs under its lock. This reduces requested work, not a measured CPU/latency claim. |
| P2 / Moderate allocation opportunity / exact branch evidence | All three traitCollection adapters always called two factories and constructed a merge array even if native style already matched the desired style. | Read native style under bypass; if equal, return the original immutable trait collection and skip factories/array. Mismatch still merges native first/style second, preserving other traits. Matching branch now preserves native pointer identity rather than returning a fresh merge; callers relying on fresh identity can observe this change. Mismatch pays one additional native style read. Net device performance remains unmeasured. |

Apple documents UITraitCollection as immutable/read-only in
[UIMutableTraits](https://developer.apple.com/documentation/uikit/uimutabletraits-8l00o?language=objc),
and the last-specified trait wins when
[merging collections](https://developer.apple.com/documentation/uikit/uitraitcollection/init%28traitsfrom%3A%29?language=objc).
The matching-style branch preserves the original value object; there is no new
cross-call trait cache or associated-object graph that could retain a receiver or
reuse stale unrelated traits. The existing merge API is deprecated in current
documentation; it is retained for older deployment compatibility. No newer UIKit
mutation API is introduced based only on the build SDK.

## Preserved behavior and deliberate limits

All six bodies retain lexical runtime-read operations. RootHide scope and theme
therefore inherit the same original view even if publication changes during a
policy callback. Rootful retains its live path/file authority with a five-minute
cache and existing four invalidation topics. Scope/Safari checks still precede
profile reads on every call, including warm hits. No new decision TTL or bundle-
admission cache is added.

Missing/empty/wrong-type primary data tries the sidecar, then defaults Light.
A nonempty unknown primary string remains Unspecified and never gets replaced
by a recognized sidecar. No trimming, case folding, new theme value or guessed
enablement behavior is introduced. Scalar overrides still skip native on success;
traitCollection adapters still call native first. The private scheme setter
forwards raw original input when no override applies, otherwise Light=0/Dark=1.

Scope/provider/factory failures preserve native, while available native original
failures propagate exactly once. Log-once claiming remains through the existing
shared utility and its namespace; this batch contains its optional failure but
does not audit or repair that utility's internals. No new production hot log,
notification topic, timer, polling loop, main-queue hop or disk writer is added.
UIKit callers keep their existing thread requirements; synchronous getters are
not moved to a different thread.

Constructor native capability, bundle/self exclusions, scope option and four
observer registrations retain their policy/order. Only capability-specific group
installation, diagnostic containment and local root cleanup change there. RootHide
inline cold priming, PXScope/runtime engine, all source writers, other hook files,
native coordinator, package/dependencies and Makefile are untouched. A class or
selector appearing only after constructor evaluation is not installed later.

## Important remaining correctness finding: DeviceTheme toggle

The existing active theme admission checks overall scope/Safari, but does not
check DeviceTheme enablement. A scoped process with DeviceTheme disabled can
still override its theme. This is a source-proven logic gap, not fixed or hidden
by the cache work. Notifications alone are not an enablement decision.

Before changing that behavior, define and test one canonical reader packet for
both schemes: explicit primary EnabledIdentifiers false must win; specify missing
primary/secondary fallback, legacy rootful paths, notification freshness and
RootHide captured-view semantics. Reusing IdentifierManager blindly is
insufficient: rootful isIdentifierEnabled reads its in-memory settings and the
singleton's initial load does not itself establish live notification refresh;
RootHide uses captured primary/secondary values. Calling loadSettings from a
Darwin callback would add I/O and mutable-manager concurrency without an agreed
contract. Keep this P1 item open for a focused authority batch. Theme source
generation/publication and setCustomDeviceTheme remain unchanged here.

## Verification

test_theme_boundaries.py extracts three includes: exact state/helpers and all six
adapter bodies. Bundle/process, clock and two file expressions are controlled
dependencies, Logos originals become native counters and iOS-17 availability is
a fixture flag. Foundation, real ObjC runtime ABI introspection and the real
PXRuntimeReadScope.m are used. UIKit/trait factories are explicit Foundation
facades; this is not real UIKit/Logos/device execution and does not prove private
method availability on any iOS release.

Four CI recipes cover rootful/RootHide x plain ARC/ARC exception cleanup at -O0.
Coverage includes inclusive TTL/expiry/backwards/invalid clocks, invalidation and
newer-candidate suppression, source precedence/malformed data, one rootful path
lookup/warm I/O avoidance, RootHide zero live I/O/clock and captured-view
inheritance, scope revocation/Safari/provider/log faults, all six native
cardinalities/exceptions, private raw/light/dark values, three projection
adapters, nil native/factories, raw-style bypass, factory reentry, unrelated
traits, capability absence, qualified/mismatched ABI and selected lifetime roots.
Matching-style factory counters demonstrate zero requested merge work in that
facade branch; they are not UIKit allocation or device CPU measurements.

The old P3 static guard required Theme's unused PXScopedAppsSnapshot wrapper.
It now checks the active central predicate and Safari exclusion, preserving the
intent rather than requiring dead code. P3 reports 84/84 checks locally.

Local Windows: 72/73 Python suites, 4/4 Node suites. Only the established Keychain
retirement Git Bash mkdir /c/Users/ADMIN permission failure remains (4 failures,
1 error, 1 skip). Source hardening and RootHide static gates, 20 negative source
controls, extraction/CHECK arity, four compile/run recipe captures, protected
admission/topics/files and diff checks pass. Recipe capture executes no compiler
or binary. New native Foundation/ARC, Logos/Theos and UIKit/device results still
require macOS CI/hardware.

## Remaining acceptance and cost

Verify iOS 12 capability skipping, supported rootful/RootHide releases, actual
effective/private WebKit selector/enum behavior, trait subclass interactions,
factory chaining, UI colors and scope/profile changes. The matching-style pointer
identity change and internal native bypass need real app/UI regression coverage.
No native pointer/IMP is guessed when runtime ABI is absent or incompatible.

Rootful cold misses still do synchronous selection/plist I/O on the caller thread;
concurrent misses can duplicate work and skipped old candidates return native.
Missed notifications can retain old rootful data until TTL, as before. Directory/
file mutation is not transactional, and a notification after the final generation
check cannot revoke an already-returning value. Per-call bundle/process/scope
work and shared log-once key work remain. Collect Time Profiler/Allocations/UI
evidence before further caching or claiming a net win. DeviceTheme enablement,
full source authority, movement, profiling and release acceptance remain open.
