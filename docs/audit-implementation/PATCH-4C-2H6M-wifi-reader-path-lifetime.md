# Patch 4C.2H6M — WiFi reader path work and exceptional lifetime

2026-11-06: user confirms H6L build passes and authorizes continuation. Read the
hook cache/reader, PXPaths definitions, captured-view dictionary contract, current
fixture and native enrollment. This batch changes four WiFiHook.x bodies only:
identity predicate, cache read/publication and rootful getProfileWiFiInfo branch.
RootHide branches and lock regions are compared unchanged with HEAD.

## Findings and changes

1. **Low / P2, confirmed redundant work — paths built before a warm cache hit.**
   TLinkIOSTweak/WiFiHook.x, getProfileWiFiInfo. Every rootful call resolved active
   ID, then constructed identity/device-ID paths before checking the WiFi cache.
   PXProfileDeviceIDsPath calls PXProfileIdentityPath again, so this derived the
   identity path twice even when the cached packet was returned immediately.
   A cold artifact hit also built an unused device-ID leaf.

   Keep active-ID resolution on every call. Check the cache first, construct the
   identity only on miss, and append device_ids.plist to that fixed identity only
   when artifact fallback needs it. PXPaths.m defines the public device-ID helper
   as exactly that derivation, so requested namespace/validation remains the same.
   PXActiveProfileID already validates the returned ID; a local NSString guard
   additionally rejects an unexpected provider value before length/path messages.

   The deterministic fixture counts identity-helper calls: one for a cold artifact
   or device-ID hit, zero additional identity calls across 100 warm reads, while
   the active-selection counter advances on all 100 calls. This is a counter test,
   not a benchmark. The previous call graph derived identity twice per warm call;
   the new warm branch does neither derivation.

2. **Medium potential / P1 — cache codec/comparison exception retains owned roots.**
   Same file, PXWiFiInfoHasIdentity, PXWiFiCachedInfo, PXWiFiPublishInfo. The predicate
   and data/decoded locals could retain graphs when an exception unwound their
   scopes without ARC exception cleanup. Cache comparisons occur after unlock,
   but the retained ID/data snapshots still need cleanup on that exit.

   Add explicit finally cleanup for named inputs, encoded/decoded values and
   retained snapshot/publication roots. Keep freezing and comparisons outside the
   unfair lock, and keep old roots retained until after unlock. The exact lock
   region contents, inclusive 300-second TTL, invalidation epoch, matching-profile
   winner, one-shot invalid-clock behavior and immutable detachment are unchanged.
   See [Clang ARC exception rules](https://clang.llvm.org/docs/AutomaticReferenceCounting.html#exceptions)
   for why ordinary Objective-C ARC scope cleanup is insufficient on unwind.

   Native cases inject a throwing pair accessor, decoded-predicate/decode failure,
   and a throwing comparison stand-in. They check nil/nonpublication or exception
   propagation as appropriate, then weak roots after caller/global release and
   pool drain. Existing dealloc-reentry cases still check release after unlocking.
   No normal-path leak, device incident or failure frequency is asserted.

3. **Medium potential / P1 — reader/provider callback leaves strong references on
   exceptional exits.** getProfileWiFiInfo rootful branch and its optional manager
   cache-reader block. A throwing artifact accessor can unwind retained source and
   path locals; a throwing manager getter can unwind a retained manager even when
   the surrounding real resolver converts that exception to unavailability.

   Name reader references outside its try and clear them in finally. In the cache
   callback, clear manager and target in finally. No new production catch/retry
   is added; reader exceptions retain their propagation policy. Source/canonical
   pair/display parsing, one lazy class lookup and the fixed-target owned resolver
   fallback retain their existing precedence. Fixtures cover reader unwind and
   manager deallocation, with borrowed/cleaned throwing collaborators to avoid
   unrelated mock-owned leaks.

## Compatibility, costs and limits

RootHide getProfileWiFiInfo, PXWiFiCachedInfo and PXWiFiPublishInfo branch text is
unchanged. It still uses the captured view, memoization and no live object-cache
clock/codec/files/provider work. Only the shared identity predicate gains cleanup;
its two-string/empty-string policy and exception propagation remain unchanged.
The iOS 15.8.8/AIDA64 bootstrap fix, constructor, scope predicate, hook installation,
private ABI admission, observers, CF builders/scan/fetch/getters and shared manager/
resolver/writers/manifest/Makefile are untouched. Both schemes receive native gates.

Warm rootful allocation/validation work is reduced with low expected relative
cost benefit; cold paths avoid one repeated identity derivation and can skip the
unused device-ID leaf. No additional root copy, serialization, file read, IPC,
network request, lock, class lookup, queue, timer or polling is introduced.
Explicit cleanup adds reference stores/unwind regions; generated code size and
latency have not been measured. The cache clock is sampled at cache lookup before
miss-only path construction; the TTL algorithm/duration are unchanged.

PXActiveProfileID still reads canonical/possibly legacy selection on each call.
This can dominate warm latency; this patch does not cache it, skip it or switch
rootful authority to a captured snapshot. Such a change requires a separate
freshness contract. Artifact/source reads are still synchronous on a cold miss.
No net CPU/I/O/latency benchmark or reduction in active-selection file I/O is claimed.

Cleanup covers named owned references, not all compiler-generated temporaries,
foreign callee retains, throwing destructors or mutation during serialization.
Cache publication ordering within one epoch, missed invalidations, arbitrary
provider misuse and global source freshness remain separate. Type/predicate fault
stand-ins model boundary misuse; NSDictionary's normal file API is not claimed to
return a deliberately malformed object. Full Patch 4/H5S-partial remains partial.

## Verification

- Windows regression: 62/63 Python + 4/4 Node suites passed. The remaining
  test_keychain_bridge_retirement.py suite is the established Git Bash
  mkdir /c/Users/ADMIN permission failure (4 failures, 1 error, 1 skip).
- Artifact source contracts, Phase-10 source hardening, RootHide static build and
  RootHide package metadata/negative controls 6/6 passed.
- Four native fragment generators completed. Each revised cache helper/reader is
  extracted exactly once; restoring those four bodies reconstructs HEAD exactly.
  RootHide branch prefixes and cache lock-region statements match HEAD unchanged.
- Nine in-memory negative source controls reject eager path work, repeated identity
  resolution, missing codec/cache-read/reader/callback/predicate/publication cleanup
  and bypass of per-call active selection. These test gates, not runtime behavior.
- The existing cache/reader native fixture expands from two scheme variants to
  rootful/RootHide x ARC exception cleanup enabled/disabled, at -O0. Captured recipe
  checks confirm all four configurations; compiler/binary calls were not executed.
  Existing ownership/rollback resolver recipes remain in place.
- Fixtures add path counters, common predicate lifetime, rootful codec/comparison/
  reader/provider lifetime and preserve captured-only, TTL, epoch, profile switch,
  immutable graph and dealloc-reentry coverage. git diff --check passed.

Foundation/xcrun/Logos/Theos and an iOS device are unavailable on this Windows
host. New native assertions, both package builds and device behavior require
macOS CI/device verification. No new native/build/device pass, commit, push or
deployment is claimed.
