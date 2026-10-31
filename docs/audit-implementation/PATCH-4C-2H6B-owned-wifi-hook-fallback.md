# Patch 4C.2H6B — Owned WiFi hook fallback

2026-10-31: user confirms H6A build passes and authorizes continued implementation.
This batch closes the rootful writer discovered by H6A. It replaces the fallback
in WiFiHook.x with PXResolveHookWiFiInfo and adds one read-only WiFiManager API.
Existing public manager generation/getter/setter/persistence methods remain
unchanged. The RootHide captured branch, H6A cache region and the entire
hook/swizzle/constructor/notification tail are compared with HEAD and unchanged.

## Findings and fixes

1. **High potential / P1 — wrong-target transitive generation.** The hook had
   already resolved profile A, but called currentWiFiInfo/generateWiFiInfo on a
   manager whose own selection policy prefers ProfileManager memory. That could
   resolve/generate/persist B after canonical selection or manager memory drift.
   The subsequent raw fallback still used A's paths. No device incident is
   asserted; the conflicting target resolution is visible in the call graph.
   The hook now requests cachedWiFiInfoForProfileID:A, which never reloads,
   resolves current selection, generates or saves. A new resolver copies the
   requested ID, validates authoritative canonical/legacy selection and keeps
   the existing A identity directory pinned through generation and commit.
   Reproduce with canonical A and manager cache/memory B: B is not used as A's
   cache candidate or generation target. See WiFiHook.x near line 275,
   WiFiManager.m near line 178 and PXWiFiHookResolver.m near line 49.

2. **High potential / P1 — raw writes outside lifecycle/source ownership.** The
   explicit fallback could mkdir an identity directory, then atomically rename
   wifi_info.plist and device_ids.plist separately. A concurrent delete could
   be resurrected, and a fault after either file could leave a mixed pair.
   Remove all mkdir/raw write calls from the hook. Borrow the established
   PXProfileArtifactMutation protocol for an existing fixed identity, capture
   both source records/presence and selection under the source gate, prepare
   using the same pure WiFi factory outside the gate, then stage both files in
   one acknowledged transaction. Before staging, compare the exact selection
   pair and source presence/values; the common mutation helper also rechecks
   directory proof and pending deletion. Never recreate a missing target.
   Reproduce with a fault after file one/two, a removed identity or an external
   source/selection update during preparation. Failure returns nil rather than
   advertising newly generated data as persisted.

3. **Medium / P1 — duplicate persistence and incomplete acknowledgement.** On
   the explicit fallback, generateWiFiInfo could already commit via WiFiManager,
   followed by the hook's two unchecked raw writes. The replacement performs
   one paired source commit and no manager adoption/notification. It preserves
   unrelated device-ID fields and includes the legacy formatted WiFi scalar
   alongside SSID/BSSID. The old explicit branch wrote this scalar; the hidden
   currentWiFiInfo generation path did not necessarily update it. All new hook
   seeds now keep the scalar consistent with the new pair, an intentional
   consistency correction. A normal old missing-cache getter already made one
   paired commit; do not claim every lookup changed from three commits to one.

4. **Medium potential / P1 — staged success and singleton reentry.** Initial
   standalone admission rejects/poisons nested source calls before singleton
   warmup or lifecycle acquisition. It also rejects an already-stale requested
   active ID before provider calls. The optional cache provider runs outside
   both source gate and lifecycle, since its singleton initializer may itself
   resolve profiles. A thread-local resolver guard stops same-thread warmup
   reentry before another provider invocation; finally clears it on every exit.
   Standalone admission precedes that guard so a nested source call still poisons
   ignored outer staging. This protects an explicit fixture interleaving; no
   actual singleton recursion on a device is claimed.

## Preserved paths and intentional failure behavior

Normal artifact/canonical-pair/display-string hits and warm cache hits stay on
their H6A path. The fallback provider class is still looked up lazily once; an
absent class/factory returns no result. A provider lacking the new read-only
selector fails conservatively with error 3024; it never invokes the old
auto-generating getter as compatibility fallback.

After warmup, the owned resolver rereads source data, so a valid artifact that
arrived meanwhile takes precedence over an older manager candidate. Typed
existing source and matching-profile frozen cache candidates can return without
writes. Such a cache candidate remains a read-only, unacknowledged fallback and
is never used as a seed to overwrite sources. Otherwise, the existing pure
PXPrepareRuntimeWiFiInfo factory supplies the same generation policy and fields.
New generated data is returned only after successful source acknowledgement;
post-marker housekeeping faults retain SourceStore's acknowledged success.

Busy lifecycle, missing/replaced identity, pending deletion, malformed source
roots, stale selection, changed preparation basis and source faults fail closed.
This deliberately removes the old cache-first/unacknowledged generated success
and directory recreation behavior. The hook retains its original framework
fallback when no fake record is available. Same-profile cache double checks
before/after copy are not an atomic manager snapshot: concurrent mutable manager
graphs and same-ID ABA remain separate. Caller graphs must be stable during
freeze. Legacy source readers, uncooperative writers after the final checkpoint,
missed notifications and H6A within-epoch cache ordering remain separate too.

The cache-provider contract forbids generation/persistence, but is a trusted
internal callback contract rather than a sandbox. Singleton initialization can
still execute its existing profile-loading work outside lifecycle. This batch
does not claim that all transitive initialization has no effects. No new queue,
timer, observer, hook, swizzle or process scope is added. RootHide continues
returning from its captured-only branch and does not call this live resolver;
the resolver itself compiles and is tested under both package schemes.

## Performance and enrollment

Successful missing-source generation uses one lifecycle lease, three source
entries (standalone selection admission, owned read/recheck, paired commit),
one pure generation and one commit marker. The IDs dictionary is staged twice
to preserve the display scalar, but is physically written once in that commit.
There is no duplicate legacy getter/generator or pair of extra raw file writes.

Cold fallback now incurs source ownership, selection/dependency reads, namespace
checks and immutable freezing. Expected relative cost is moderate, potentially
high on slow storage/contention; synchronous hook latency remains a limitation.
It is a correctness change, not a benchmarked speedup. Warm/source hits retain
their existing path. No network request, polling or asynchronous waiting is added.

Manifest wifi-hook-legacy is now enrolled through the replacement resolver, and
wifiInfo aggregate returns to enrolled for the known current writers. DeviceIDs
and full Patch 4 remain partial; old/external binaries do not join this contract.
The overall H5S-partial rollout marker remains the prior broad checkpoint rather
than a claim that all later reader/writer work is complete.

## Validation

The existing artifact-preparation native recipe links the real resolver for both
rootful and RootHide, with the real source journal, artifact writer, lifecycle
and selection helpers. New cases cover fixed A/B targeting, one commit/display
scalar, read-only matching cache, source arrival during provider warmup, invalid
or stale target, frozen mutable input, missing provider, cache/preparation
exceptions, ignored nested staging, singleton reentry, busy/pending state, faults
after either file, post-marker acknowledgement, dependency/selection drift and
no recreation of a removed identity. Preparation checkpoints use the existing
controlled random backend; production contains no test callback.

The separate exact hook-reader fixture uses a resolver collaborator to check
wiring, no legacy getter/generator/raw-write retry and conservative handling of
older providers. Actual ownership is verified in the artifact binary. The
read-only manager method is extracted exactly alongside existing wrappers.
Duplicate native class declarations and repeated new fixture blocks are also
checked locally to catch compile failures without an Apple SDK.

Local Windows: 62/63 Python and 4/4 Node gates; the remaining failure is the known
bridge-retirement Git Bash mkdir permission issue. Source hardening, RootHide
metadata/static gates, exact four native generators, helper/wrapper/reader
preservation, CHECK arity and 14 in-memory negative controls pass. Final targeted
and regression gates are rerun after fixture review. No Foundation/Theos/package
or device execution is available locally; H6B still needs macOS CI/device checks.
