# Patch 4C.2H6A — WiFi cache and reader boundaries

2026-10-31: user confirms H5Z build passes and authorizes continued implementation.
The complete WiFiHook.x flow was read from cache/profile lookup through CF hooks,
Objective-C methods, swizzles, initialization and notification cleanup. This
batch changes the rootful live cache/reader; the RootHide captured reader and the
entire hook/installation/constructor/notification tail remain identical to HEAD.
The common WiFiManager persistence implementation is unchanged.

## Findings and changes

1. **Medium / P1, confirmed invalidation race.** A cache miss could read old
   WiFi data, receive settings/profile invalidation, then repopulate that data
   for another 300 seconds. Clearing the cached objects did not revoke loaders
   already doing I/O. Capture a lock-owned invalidation generation with lookup
   and check it after preparing publication. A stale loader cannot publish; it
   may return only a still-fresh winner for exactly its requested profile ID.
   Reproduce by invalidating inside the artifact read, optionally switching to
   B and publishing B while A's read is suspended. A returns nil rather than B
   or resurrecting A. This is a demonstrated source interleaving and a fixture
   scenario; no device race frequency is claimed. See cache functions near
   WiFiHook.x:99/125 and generation forwarding in getProfileWiFiInfo.

2. **High potential / P1, confirmed unsafe type path.** Rootful checked only
   existence of ssid/bssid in file, manager and generated dictionaries. For
   example an NSNumber SSID could be returned by Objective-C string getters
   or bridged into CFStringCreateCopy in the MobileWiFi replacement. Objective-C
   exceptions in some wrappers do not make an invalid CFStringRef safe. Require
   a dictionary with two NSString fields before choosing a candidate; also type
   check the canonical SSID/BSSID pair before constructing fallback data.
   Reproduce with a plist whose ssid is numeric and whose bssid is a string.
   The reader now tries its existing typed fallback order instead of publishing
   the malformed pair. This is type validation, not a new MAC/SSID format rule:
   empty strings, case and the legacy display parser retain their prior policy.
   No actual device crash is asserted. See PXWiFiInfoHasIdentity near line 84.

3. **Medium / P1, confirmed aliasing.** The previous [info copy] detached only
   the outer dictionary. WiFiManager's setter/adoption/current getters also use
   shallow dictionary copies, so a caller-retained NSMutableString or nested
   value could change a cached packet without a source commit or invalidation.
   Freeze an encodable packet with binary plist encode/immutable decode before
   taking the lock; copy the profile key there too. Reproduce by publishing a
   mutable SSID/nested array and mutating them after publication. Preserve all
   valid plist extensions. Unsupported non-plist graphs or failed freeze return
   nil and leave an existing cache intact; they do not get invented WiFi defaults
   or a partially retained graph. That rejection is intentional for unsupported
   provider results and is a behavior difference from the old shallow cache.

4. **Medium potential / P1, lifetime and lock reentry.** Assigning/clearing cache
   objects could release their entire graph under a non-recursive unfair lock;
   publication also copied a possibly custom NSString under that lock. Retain
   both discarded info and profile through unlock with objc_precise_lifetime,
   copy/freeze outside the lock and compare profile strings after unlocking.
   An info descendant whose dealloc invalidates the cache demonstrates the
   reentry hazard in the fixture. Actual ordinary graph destruction may simply
   lengthen lock occupancy. No real-device dealloc incident or contention
   benchmark is claimed. Returning retained hits/winners still protects lifetime.

5. **Medium / P1, confirmed time edge case.** NSDate-based freshness accepted
   every negative age because it checked only age <= 300. Moving wall time
   backwards could keep a stale packet fresh beyond its intended duration.
   Use CLOCK_MONOTONIC and finite/nonnegative age guards, preserving the original
   inclusive 300-second boundary. Clock failure may serve a detached one-shot
   result but does not retain it. Stale-loader winner checks take a fresh clock
   observation outside the lock. Reproduce old behavior with a now timestamp
   earlier than its loaded timestamp; the new fixture uses deterministic times.

6. **Low / P2, confirmed unnecessary initialization.** Every cold reader resolved
   WiFiManager twice by name and called sharedManager even after finding a valid
   artifact or canonical pair. The singleton init loads profile data and installs
   an observer. Resolve the class once, only when a provider is required, and
   check sharedManager before invoking it. Move NSFileManager setup into the
   explicit valid-generation branch. A valid file now needs no manager class
   lookup/factory call; a class lacking the factory safely falls through. Expected
   relative saving is low for a warmed singleton, potentially moderate for cold
   initialization; no call rate, milliseconds or universal hot-path gain is
   claimed. Existing source-selection/path resolution still precedes cache lookup.

## Authority and remaining work

RootHide still uses the same captured view, typed artifact/device-ID/display
fallbacks and associated result/NSNull memoization. Its live-cache lookup is
explicitly a miss and publication is a direct return, without codec or clock
work. It never enters the rootful live file/provider/generation branch. This is
verified by exact source comparison and separate native fixture cases; no new
bootstrap, swizzle, private ABI, process scope, queue, timer or observer is added.

Cache generations are not source transaction IDs. Within one invalidation epoch,
concurrent loaders retain last-completer replacement semantics; the cache is
still a single profile-keyed slot. Lost notifications, canonical selection
changes without invalidation, historical in-flight returns, multi-file source
coherence and mutable manager state are not solved by this cache change. Input
graphs must be stable during serialization. Epoch wrap has the theoretical
2^64-invalidations-during-one-load ABA limit.

Inspection also found an omitted writer: after optional manager generation the
rootful reader can create identity directories and directly write wifi_info.plist
and device_ids.plist, outside the source/lifecycle transaction. The current
manager may already persist during generation, so this can duplicate writes;
manager-target drift, raw-write failure acknowledgement and directory races need
a dedicated owned adapter. A malformed nonempty manager packet followed by valid
generation is one concrete path to the explicit fallback. This batch preserves
that legacy valid-generation behavior and does not claim its writes are atomic.

The manifest now lists wifi-hook-legacy as pending for both affected sources and
corrects wifiInfo from enrolled to partial. Common WiFiManager's enrolled writer
status remains accurate for its own entry points. This is an inventory correction,
not new enrollment. Rollout stays H5S-partial and full Patch 4 remains partial.
MobileWiFi Get-function ownership, optional method ABI and pass-through hooks are
separate review items; this batch does not assert their compatibility or fix them.

## Performance and validation

Warm rootful cache reads now use a C clock and short locked reference capture;
string comparison and graph destruction run outside the lock. Cold publication
adds in-memory encode/decode CPU and temporary allocations proportional to the
packet, expected low-to-moderate cost for these small records. This is a stability
tradeoff, not a blanket speedup. No extra file read/write, IPC or background work
is introduced by the cache itself. Legacy reader/provider I/O remains synchronous.

The existing artifact-preparation --native recipe adds PXWiFiHookCacheTests.m for
rootful and RootHide. The fixture includes the entire exact cache region and two
exact reader helpers. Controlled codec/file/provider/snapshot collaborators inject
invalidation, emulate missing/malformed data and count effects; no real files or
singleton are modified. Coverage includes alias detachment, exact TTL boundary,
negative age/unavailable clock, matching/different-profile stale winners, failure
during freeze, dealloc reentry, integrated file-read invalidation/profile switch,
typed fallback/parser behavior, lazy class/factory setup, missing factory, valid
legacy generation writes and RootHide captured-only authority.

Local Windows: 62/63 Python and 4/4 Node gates pass; the remaining Python failure
is the known bridge-retirement Git Bash mkdir permission issue. Source hardening,
RootHide metadata/static gates, P3 81/81, four native fragment generators, exact
cache/readers, helper order, CHECK arity, source-preservation comparisons and 12
in-memory negative controls pass. Final gates are rerun after the manifest update.
Foundation/Theos/package/device execution is unavailable locally; the new native
fixture and actual device behavior require macOS CI/device verification.
