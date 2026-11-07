# Patch 4C.2H5Y — Storage object cache epoch, time and lifetime

2026-10-31: user confirms H5X build passes and authorizes continued implementation.
This batch addresses the Foundation object cache in StorageHooks.x. It does not
change the H5X native C tuple protocol, refresh scheduler, constructor/provider
registration or StorageManager persistence. RootHide continues bypassing the
object cache in favor of its captured runtime view.

## Findings and changes

1. **Medium / P1 — confirmed invalidation/publication race.** A rootful reader
   could miss cache, load profile A, receive profile/settings invalidation, then
   repopulate cache with its old A packet. Clearing the dictionary alone did not
   revoke in-flight publication. Keep a lock-owned invalidation generation;
   capture it with the cache lookup and pass it through every publication call.
   Invalidation increments it. Publication compares after preparation under the
   same lock and cannot store a packet from an invalidated loader. A stale loader
   may return an already-published fresh winner; it cannot reuse an expired
   winner or overwrite newer invalidation state. With no valid winner it returns
   unavailable; the registered notification has already scheduled refresh work.

2. **Medium / P1 — wall-clock TTL.** Freshness used NSDate wall time and only
   checked delta < 30, so clock rollback could count negative elapsed time as
   fresh and prolong a stale value. Use CLOCK_MONOTONIC, reject negative elapsed
   and non-finite timestamps and retain the exclusive 30-second TTL. The stamp
   still represents load-attempt start, preserving the old age budget. Clock
   failure misses cache; a valid detached result can be returned once but is not
   stored with an invalid timestamp. RootHide uses no real clock for this cache.

3. **Medium / P1 — confirmed shallow mutable alias.** Publishing copied only
   the outer dictionary. Legacy mutable strings/descendants could change the
   cached value without invalidation or a source commit. A concrete producer is
   a mutable string retained by a legacy StorageManager setter, returned by its
   getter and retained in the hook's fallback dictionary. Detach an encodable
   rootful plist graph with binary encode/immutable decode before entering the
   cache lock. Preserve all valid plist keys, not just the two display fields.
   A non-plist dictionary gets the enabled invalid-data byte defaults (128/38
   marketing GB), rather than retaining an unsupported graph or introducing a
   physical-capacity fallback. Nil/non-dictionary publication stays unavailable.
   RootHide does not serialize/copy its already captured view.

4. **Medium potential / P1 — release under unfair lock.** Replacing or clearing
   the owning dictionary could destroy it and its descendants while the
   non-recursive lock was held. A dealloc callback that invalidated again would
   reenter that lock; ordinary large graphs could also lengthen the critical
   section. Retain discarded objects in objc_precise_lifetime locals through
   unlock for expiration, replacement and invalidation. The new immutable
   candidate also survives through unlock, including rejected publications.
   Serialization, clock probing and graph destruction stay outside the lock.
   This is a demonstrated callback risk in the fixture, not a claimed real-device
   dealloc incident. Retaining a cached hit under the lock still protects lifetime.

## Preserved policies and remaining ordering

The generation is private process cache state, not a source commit ID or the H5X
native tuple revision. It advances on invalidation, not on every lookup or
publication. Concurrent loaders within one invalidation epoch retain their prior
last-completer publication policy; this does not establish source version order
or coalesce object-cache misses. Generation wrap has the usual theoretical
2^64-invalidations-during-one-load ABA limit.

Rootful authority and enablement checks remain in their existing order: a warm
cache hit still precedes preferences lookup. Changes without a delivered
registered notification may therefore remain cached until TTL, as before. No
claim of instant toggle enforcement, newest-profile source CAS or multi-file
consistency is added. Invalidation after an accepted publication can still make
that returned value historical; the linearization point is the locked check.

RootHide's getStorageValues toggle/captured-view block is unchanged except for
an ignored cache-token argument. Its clock helper returns zero, lookup always
misses and publication directly returns the captured dictionary, with no codec
or cross-generation object caching. Its producer/lexical-view validation remains
the authority. All constructor and provider registration text is identical to
HEAD; initial inline refresh and the iOS 15.8.8/AIDA64 bootstrap fix are preserved.

Valid source formats, scope filtering, fallback values, observer topics and H5X
queue coalescing/native packet semantics are unchanged. No preferences/files are
written, no polling/queue/timer is added and no source is enrolled. Rollout stays
H5S-partial; full Patch 4 remains partial.

## Performance and lifecycle

Warm rootful reads still use a short lock to retain one immutable dictionary and
read its metadata. They use a monotonic C clock instead of constructing/querying
an NSDate; no heap allocation count or timing improvement is asserted because
Foundation object representations can vary. RootHide avoids that wall-time
object operation entirely and still bypasses the object cache.

Rootful cold publication now has in-memory encode/decode CPU and temporary
allocation proportional to the packet graph, plus a monotonic probe for a fresh
winner. Expected relative cost is moderate for cold publication, with no added
file/IPC operation; correctness of mutable descendants is the reason for this
cost. It is not presented as a universal speedup. A result that is invalidated
during preparation can still spend that preparation work before being rejected.
Expensive release work moves outside the lock, lowering potential contention.

Caller-owned input must still be stable while being serialized; the change
detaches later mutations and does not make concurrently-mutated Foundation
collections safe. A slow load can consume the original TTL before publication.
Platform monotonic clock semantics apply; this is not a persistent wall-clock
deadline across process/device lifecycle changes.

## Validation

The existing artifact-preparation native CI command now also builds/runs
PXStorageObjectCacheTests.m for rootful and RootHide. It includes the entire exact
cache state/helper region with its original preprocessor branches. A forwarding
Foundation codec adapter injects invalidation during preparation; production
helpers contain no test callbacks.

Rootful cases cover descendant detachment, 29.999/30-second boundaries, negative
age, unavailable-clock one-shot behavior, stale publication after invalidation,
fresh/expired winner reuse, invalidation inside preparation, malformed packet
fallback and nil publication. Dealloc sentinels retained only by a legacy cache
reenter invalidation on expiration/replacement/clear, checking release-after-unlock
without relying on private Foundation mutability classes. RootHide cases check
direct view identity, no codec use and no object-cache authority after invalidation.

Local Windows: 62/63 Python and 4/4 Node gates pass, plus source hardening,
RootHide metadata/static checks, exact identifier/artifact/group/profile/cache
regions, CHECK arity and 12 in-memory negative controls. The remaining Python
failure is the known bridge-retirement Git Bash mkdir permission issue. H5X
native copy/refresh/scheduler bodies and the entire storage constructor/provider
registration are compared with HEAD and unchanged. Foundation/Theos/device
execution is unavailable locally; H5Y requires the next macOS CI/device run.

## Native follow-up — deterministic TTL clock fixture (2026-11-07)

Baseline 2594ed7. The user's native artifact preparation runs pass 848/848 three
times, then rootful Storage object cache fails 20/22 at the exclusive 30-second
boundary and the immediately following MissAt call. Earlier logs passed the same
22 checks. The fixture constructs a deadline from a real fractional monotonic
sample, then expects (now + 30) - now to equal exactly 30. Floating addition across
an exponent boundary need not preserve that equality. Local binary64 arithmetic
reproduces now=226.00000000000003, now+30=256.0, elapsed=29.99999999999997.
The production '< 30' predicate therefore accepts this constructed timestamp,
leaving the cache populated for the next miss assertion too. The same defect
is reachable through the exact production timespec conversion: tv_sec=226 and
tv_nsec=2 yield now=226.000000002, deadline=256.000000002 and the same elapsed
29.99999999999997. Analogous reachable samples are 31 seconds/3 nanoseconds and
1009 seconds/6 nanoseconds. This explains the two-failure pattern without a
generation bug. The runner did not print its actual
sample, so this is a reproducible fixture defect consistent with the log, not a
claim to know that runner's exact timestamp.

Only the fixture and its source guards change. Wrap the external clock_gettime
backend around the exact production cache fragment. Deterministic cases use
1000 integral seconds and zero nanoseconds; both explicit query timestamps and
PXStoragePublishValues' internal observed-now query now use one controlled clock
domain. The existing 29.999-hit and exact-30-miss assertions stay strict. Do not
add an epsilon, shorten the TTL, relax the miss assertion, change production time
math or use sleep/retry. A failure diagnostic records full-precision now, loaded
origin, computed age, hit states and generation.

A separate clock-adapter control forwards to the real CLOCK_MONOTONIC backend
once on rootful, verifies nanosecond conversion using exact 1000.25, injects an
unavailable backend and checks NAN, then restores the exact TTL origin. RootHide
still returns zero without calling either backend; its existing no-cache policy
also asserts zero backend calls. The fixture's unused backend attribute only
accounts for that intentional compile-time bypass. A controlled backend avoids
both phase-dependent arithmetic at the exact boundary and scheduler-dependent
fresh-winner assertions. Foundation codec, invalidation-during-freeze callback,
reentrant deallocation, stale generations, negative elapsed time and safe-default
cases are unchanged.

Local validation: twelve source negatives reject missing clock wrapping,
live-backend forwarding, exact origin, live-clock-independent checks, RootHide
bypass counters, either TTL boundary, strict expiry assertion, adapter invocation,
fractional conversion or failure sentinel. An arithmetic reproduction confirms
the old two-hit pattern at representable samples near 31, 226 and 1009 seconds,
while the fixed origin expresses the exact boundary without rounding loss. These
are arithmetic/source checks, not native cache execution. Five fragment generators,
exact unchanged cache region, CHECK arity, both rootful/RootHide object-cache native
recipes, source hardening, RootHide metadata/static checks (6/6) and diff checks
pass locally. Recipes were captured; compiler/binary calls were not executed.
Full Windows regression remains 62/63 Python and 4/4 Node, with only the known
Keychain Git Bash permission failure (4 failures, 1 error, 1 skip).

No production file, TTL, cache epoch/authority, hook, bootstrap/ctor/install policy,
package/Makefile/dependency or iOS 15.8.8/AIDA64 behavior changes. macOS CI must
confirm the native fix and remaining matrices; no new native/device pass,
benchmark or rollout completion is claimed.
