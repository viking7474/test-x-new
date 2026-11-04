# Patch 4C.2H6G — WiFi manager cache revisions and paired ownership

2026-11-01: user confirms H6F build passes and authorizes continued implementation.
Reviewed the complete common/WiFiManager implementation/header, its IdentifierManager
adoption/display callers, H6B hook fallback, source mutation lifecycle and existing
preparation/owned-manager fixtures. Scope is this manager's cache protocol and its
standalone save handoff; hooks, source formats and authority policy stay unchanged.

## Findings and changes

1. **High / P1, confirmed synchronization defect — ID/data pairing and ABA.**
   `cachedWiFiInfoForProfileID:` checked currentProfileId, copied wifiInfo and checked
   the ID again. An A → B → A update during copy passed both checks despite stale
   bytes; separate unsynchronized ID/data assignments could expose another profile's
   data. Snapshot acquisition now retains both fields and their revision under one
   short monitor. Copy and string comparison happen after unlock. Recheck the
   revision after copy: any intervening own mutation, including same-ID adoption,
   makes the operation a miss. Native deterministic copy callbacks exercise ABA,
   same-profile replacement and another-thread adoption. Device occurrence has not
   been observed; the new native cases still require CI execution.

2. **High / P1, confirmed ordering defect — completed save relabels newer data.**
   The old save copied one candidate for source, then set only currentProfileId
   after commit. Adoption during that interval could replace wifiInfo with B's
   bytes, after which the save tagged them with its earlier target A. Save now
   captures an owned candidate at its revision, commits that fixed snapshot, then
   conditionally publishes the prepared bytes and ID together. A newer cache owner
   prevents adoption of the older save's cache/error result; it does not negate
   an already completed source commit. The real source-store fixture injects a
   B adoption at source-written while persisting a distinct A candidate, and
   verifies A's source success plus B's unchanged cache identity. Distinct bytes
   force an actual write rather than relying on a no-op transaction checkpoint.

3. **Medium / P1 — stale loaders, adoption callbacks and lazy misses.**
   A file read or mutableCopy callback could publish older data after a newer
   cache update. Each operation begins with a revision before external work;
   load clears ID/data together, then publishes a completed result only at its
   owned revision. Adoption freezes the ID before copying payload data. Generation
   and setter pass their candidate's revision to persistence, so save cannot pick
   up an unrelated newer candidate. A currentWiFiInfo miss conditionally claims
   work and carries its loader's completion receipt into generation admission;
   it cannot borrow the revision of a newer operation that has only begun.
   Superseded lazy work returns nil instead of retrying or resurrecting its target.

4. **Medium potential / P1 — nonatomic retained-object lifetime and release reentry.**
   The private info, ID and error accessors are now synthesized atomic properties
   to protect individual get/set ownership for legacy scalar readers. Their pair
   still requires the separate monitor/revision protocol: property atomicity alone
   does not establish object thread safety, as [Apple explains](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/EncapsulatingData/EncapsulatingData.html).
   Before a pair/error swap, precise-lifetime locals retain the displaced objects;
   their final release happens after leaving the monitor. A dealloc callback may
   therefore inspect the completed replacement from another thread without waiting
   on this publication's monitor. Preparation/snapshot/save locals are explicitly
   cleared on exceptional exits; source ownership is invalidated before releasing
   save temporaries. Foreign throwing destructors/accessor overrides remain outside
   this guarantee.

## Cache contract and preserved behavior

The read-only hook fallback does no selection lookup, I/O, generation or save.
An in-flight/unacknowledged candidate is now a miss until load, committed adoption
or successful save establishes a readable entry. Failed writes leave that entry
ineligible; a later load/adoption may restore it. This deliberately avoids serving
new candidate bytes under a previous profile ID. It can cause more cache misses in
these error/transition cases. The public header records this policy.

Legacy generate/set/currentWiFiInfo remain cache-first: failed persistence keeps
candidate data and lastError. Generation returns its prepared candidate once
preparation runs; supersession before preparation may instead return nil.
The default/no-active ephemeral cache, validation/error codes, numeric ID fallback,
optional-manager-first authority, fixed target and paired source staging are
preserved. A superseded concurrent currentWiFiInfo may return nil; it does not
retry, poll, schedule work or report another profile's cache as the requested one.
Read-only API results remain shallow dictionary copies. Root dictionaries are
replaced by own writers, never mutated in place by this protocol.

There is no monitor held across dictionary/string copying, file reads, pure
preparation, manager callbacks, lifecycle acquisition, source I/O or logging.
Save still holds its existing lifecycle lease while snapshotting the candidate,
but never holds the cache monitor while invoking copy. Lease → short cache capture
has no inverse cache → lease acquisition in these methods. No new queue/timer,
notification, file format, source writer or process-global lock is introduced.

## Limits and compatibility

This is a per-instance cache order, not a global profile-selection/source revision.
A ProfileManager/selection change without a cache operation may occur independently.
A source commit already in progress is not rolled back because cache ownership
changed. `lastError` is a latest-manager diagnostic, not an operation receipt or
persistence ACK. Existing main-thread/authority requirements of ProfileManager and
its cold initialization are not made thread-safe here.

Cooperative own writers replace cache roots through the protocol. Concurrent
external mutation of caller inputs, nested mutable objects, KVC/private-property
writes or overridden private accessors is not covered. Shallow-copy compatibility
is preserved, so this patch does not deep-freeze the complete object graph or
claim whole-manager thread safety. uint64 revisions skip zero (reserved for failed
admission) and order this instance's operations; they are not durable generations.
Same-ID external file changes/notification loss and other instances can still
require reload. Separate legacy currentSSID/currentBSSID calls (including the
IdentifierManager display caller) are not a combined observation across cache
updates. No global freshness, crash durability or reader distribution ACK is added.

All of TLinkIOSTweak/WiFiHook.x, MethodSwizzler, H6A–H6F hook behavior, bootstrap
(including the RootHide iOS 15.8.8/AIDA64 fix), package dependencies, Makefile and
source writer enrollment stay unchanged. Both package schemes compile the shared
manager changes. Full Patch 4 remains partial and marker H5S-partial is unchanged.

## Performance and verification

Cache reads now take two short monitor acquisitions plus individual atomic
property access, while still copying outside the monitor. This adds low expected
uncontended overhead; contention has not been measured. Standalone success makes
one additional mutable dictionary copy to publish the exact committed snapshot.
Revision checks can avoid obsolete copy/I/O/generation work, but extra misses may
increase cold fallback latency. No net CPU, latency or memory benchmark claim is
made. No busy polling or unbounded retry is used.

The artifact native recipe expands exact manager methods/declarations into its
existing preparation/real-source fixtures and adds a Foundation cache fixture for
rootful/RootHide × both ARC exception modes at -O0. Cases include deterministic
ABA/same-ID changes, nested load/adopt, outside-monitor copying, deferred dealloc
reentry, pending eligibility, stale error/publication rejection, conditional
admission, missing/malformed files, exceptional snapshot lifetime, 1000 concurrent
writer/read iterations with pair checks, source-save adoption/warmup races and
lazy hit/miss supersession. Controlled copy collaborators borrow/clean their own
references rather than manufacturing unrelated ARC leaks.

Local Windows: 62/63 Python and 4/4 Node regression suites pass. The remaining
Python suite is the existing Keychain-retirement Git Bash mkdir permission error.
Four native fragment generators, exact manager method/declaration expansion,
CHECK/duplicate-class checks, 12 in-memory revision/eligibility/lifetime negative
controls and monitor-region checks pass. Protected hook/ownership/build/manifest
files are unchanged. A captured-command check confirms four manager-cache native
configurations; it is not native execution. Source hardening, RootHide metadata
and static gates are checked independently; final targeted/diff checks pass.

Foundation native, Logos/Theos, package and device execution are unavailable on
this Windows host. The new interleaving/lifetime/stress cases require macOS CI;
no H6G native/build/device pass or measured contention/latency result is claimed.
