# Patch 4C.2H5O — Typed scope reader packets and shape guards

2026-10-30: user reports H5N build pass. The shared IdentifierManager implementation
changes for rootful and RootHide. No local macOS/Foundation/Theos/device execution
is available. Hook installation, bootstrap and package/filter policy are unchanged.

## Findings, reproduction and priority

Locations: common/IdentifierManager.m, -shouldSpoofForBundle:,
-isApplicationEnabled:, -isExtensionEnabled:, -isBundleIDMatch:withPattern:.

**Medium, confirmed cache namespace defect (P1):** shouldSpoofForBundle stored its
BOOL at bundleID and NSDate at bundleID + "_timestamp" in the same dictionary. Two
nonempty IDs accepted by the manager API can therefore share a decision/date slot.
Reproduce with fixture.packet enabled and fixture.packet_timestamp disabled; alternate
three reads of both IDs. One call overwrites the other's timestamp/decision, causing
recomputation or potentially sending boolValue to NSDate. This is a code-level defect;
no affected installed app or production frequency has been established.

**Medium, potential malformed-state crashes (P1 hardening):** manager/rootful readers
subscripted direct app records and called boolValue without validating record/scalar
types. The enabled cache also called timestamp doubleValue on unvalidated values.
A locally inserted array/number app record, array enabled flag or wrong cache payload
could raise an exception. Regex/extension helpers accepted non-string pointer values
before calling string selectors. H5F/H5M already reject malformed load packets; these
findings concern direct/inherited mutable memory and unexpected API input, not a claim
that the hardened loader now adopts invalid files. RootHide injected direct-record
checks were already defensive and retain their policy.

**Low, allocation opportunity (P2, incidental):** the derived timestamp key allocated
a string on a spoof-cache hit and used an additional dictionary namespace slot. No
active repository caller of shouldSpoofForBundle was found beyond its definition;
dynamic/external callers cannot be ruled out. Its invocation frequency/hot-path impact
is unknown, so no CPU saving or benchmark is claimed.

## Implementation and preserved behavior

Each spoof-cache ID now owns one immutable dictionary containing enabled and timestamp
(NSDate). Cache reads validate packet, enabled scalar and date types before using them.
Malformed or legacy scalar entries are cache misses and are replaced on demand.
The existing 30-second wall-clock TTL is preserved. Packets are private in-memory
state, not a persisted preferences schema; no file migration or new I/O is introduced.
Existing writers still invalidate the whole spoof cache after their own successful
source/adoption work. No new observer or timer is needed.

The enabled reader validates its existing numeric/string timestamp and enabled fields;
malformed payloads fall through to ordinary lookup. The shared PXScopeRecordEnabled
helper requires a dictionary record and delegates typed boolean interpretation to
PXRuntimeReadBool. Direct lookup, post-reload lookup and case fallback use the helper.
Both local scope roots and fallback keys are checked before subscripting/string calls.
Each local reference is read once from the property and then type-checked. A local
scope root replaced during reload is observed again afterward. This is not
synchronization against mutation of the dictionary while enumerating it.

Spoof direct lookup still uses exact case, and a present malformed/disabled direct
member returns NO rather than falling through to an enabled extension pattern. The
app-enabled reader retains its case-insensitive fallback. Extension lookup retains its
self/system exclusions and first-match return policy. shouldSpoofForBundle's existing
direct-member policy is distinct: an explicitly enabled self/system member is not
newly excluded by this patch. Changing that policy would require separate review.

The regex helper now rejects non-string inputs before string selectors. Its original
dot escaping, wildcard replacement, anchoring, case-insensitive matching and error
handling remain unchanged, including the empty-string match at this low-level helper.
The legacy wildcard conversion is permissive (fixture.parent.* can also match
fixture.parentSuffix); tests preserve it intentionally. Tightening that scope policy,
resolving overlapping patterns or introducing regex caching is deferred.

All high-level readers reject nil/empty/non-string IDs before runtime operation/cache
work. RootHide injected spoof/extension readers still use the pinned runtime operation
and snapshot branch before owner cache or I/O. A malformed snapshot scope does not
revive a positive local cache. The existing nested operation mechanism, rather than
this patch, is responsible for pinning views across a fallback helper call.

## Performance, memory and concurrency limits

A spoof-cache hit removes the derived-key string operation. Each miss now allocates a
small immutable dictionary instead of storing two top-level entries. Net memory cost
is not measured: fewer keys/slots do not prove lower memory once packet overhead is
included. Typed checks are constant cost; extension traversal/regex creation and
uncached case fallback remain O(n). No regex cache or new dispatch/locking is added.
The app-enabled reader retains its 30/60-second cache/reload behavior and existing
cold-miss source calls. The other three helpers gain no source I/O.

A single packet is not an atomic or thread-safe publication mechanism. Mutable cache
maps, scopedApps, cross-instance refresh and same-instance concurrent reads/writes
still require separate work. Packet values contain only scalar/date objects, without
retaining manager/observer callbacks. Unbounded distinct-key growth and wall-clock
rollback semantics remain unchanged. Full Patch 4 remains partial.

## Validation

The native group recipe extracts **75 exact production methods** plus the exact
constructor/state declarations and PXScopeRecordEnabled helper. It retains the real
snapshot initializer and PXRuntimeReadBool implementation linked in H5N. New fixtures
cover accepted-ID collisions, fresh/expired/legacy/malformed cache packets, invalid
roots/records/flags/keys, exact-versus-case behavior, direct-presence precedence,
regex/exclusion compatibility, writer invalidation and RootHide snapshot authority.
Reader-only cases assert no source calls, writes or notifications. The test runtime
operation/transport remains a collaborator, not proof of device bootstrap/injection.

Windows regression: **62/63 Python suites and 4/4 Node suites pass**. The remaining
keychain bridge retirement suite retains its known Git Bash mkdir permission failure
at /c/Users/ADMIN (4 failures, 1 error, 1 skip in 10 tests). Release source hardening
and RootHide package metadata/negative controls 6/6 pass. Exact 75-method group/helper,
constructor/state and profile fragment extraction, C-helper definition order, CHECK
macro arity and git diff whitespace checks pass. Final review strengthens malformed
packet assertions to require repaired typed fields and gives the malformed RootHide
snapshot fixture a positive local packet, so stale-cache revival would be detected.

Twelve in-memory source negative controls reject derived timestamp keys, untyped
packets/date/timestamp/local root/records, malformed-direct fallback, missing extension
root and regex-input guards, changed wildcard policy, added owner source I/O and owner cache
reads before the snapshot branch. Reversed native C-helper order is rejected separately.
No production files are modified by negative controls. Regression and targeted checks
were rerun after changing root reads to a single local reference per observation.

Native builds and runtime tests for both schemes remain pending macOS CI/device
validation; source contracts and generated-fragment review are not native runtime proof.

2026-10-30: user reports H5O build pass. H5P follows for Reset scope replacement
preparation; the local host still cannot run native/device validation.
