# Patch 4C.2H6I — WiFi profile resolution and reload admission

2026-11-06: user confirms H6H build passes and authorizes continued implementation.
Read the complete WiFiManager, profile-path validator, artifact mutation acquisition,
manager generation/adoption/read callers and existing real-source/cache fixtures.
This batch covers profile resolution, current-profile reload admission and the
notification adapter. H6G/H6H cache/write/display contracts remain in place.

## Findings and changes

1. **Medium potential / P1 — unsupported selection values become path keys.**
   common/WiFiManager.m, profileIDFromManager: used description for unsupported
   ProfileId values from the selection plist. Arrays, dictionaries, NSNull and
   dates could therefore become strings; PXValidatedProfileID only rejects certain
   path forms, not every description string. If a matching identity directory
   existed, persistence could target that unintended leaf. The helper now accepts
   NSString and the existing NSNumber.stringValue file representation only.
   It never derives identity from an arbitrary object's description.

   A present nonstring manager ID was already rejected by downstream string/path
   validation on writes. It now returns nil at the resolver and never falls back
   to a competing file target. Manager/current-profile/ID getter exceptions likewise
   return unresolved rather than implicitly choosing another authority. Native
   cases inject malformed IDs and the real source fixture verifies no candidate
   copy or source write; device occurrence has not been observed.

2. **Medium / P1, confirmed ordering gap — reload claims after lookup.**
   loadWiFiInfoFromCurrentProfile obtained the ID first, then called the public
   loader, which started a new revision. A getter/factory callback adopting newer
   B while returning older A could thus be followed by a newly admitted A reload.
   Claim the revision before lookup, run provider work outside the monitor, then
   pass the same revision to the private loader. A superseding adoption prevents
   old-target path/file work. The deterministic fixture adopts B in the ID getter
   while returning A and checks B plus an unchanged file-read counter.

3. **Medium potential / P1 — untyped notification payload and callback ownership.**
   The observer indexed userInfo without a root guard. Move its small adapter into
   handleWiFiProfileNotification:, check NSDictionary before indexing, and keep
   valid events as reload hints rather than adopting the event ID. Malformed roots
   or unsupported event fields cause no lookup/invalidation. The observer still
   promotes weakSelf only for delivery, with explicit owner/note cleanup on exit;
   registration remains idempotent and dealloc removes the existing token.
   A direct handler stand-in tests out-of-contract root shapes; this does not claim
   that NSNotificationCenter normally creates notifications with those shapes.

## Authority and compatibility

Valid manager strings remain first and are copied before returning. Do not trim,
normalize, change case or apply a new profile-ID grammar here: existing downstream
PXValidatedProfileID/path checks remain the authority for filesystem access.
Numeric manager IDs do not acquire the file API's numeric compatibility rule.
A nil/absent optional manager/profile/ID selector still permits the canonical
file fallback; valid file NSNumber values still use stringValue, including the
old numeric grammar. Nil read/missing field still produces the legacy default
cache label. Unsupported *present* values return nil, not default or a second
selection source. The public generate/current cache-first policy remains intact.

NSDictionary's legacy file API does not distinguish absent from unreadable files
for this caller; a nil read still uses default. This patch does not turn that API
into a strict missing/corrupt/permission result. No additional existence probe,
registry scan, legacy-active-file authority or daemon-snapshot writer authority
is added. Frozen strings prevent later caller mutation from changing the observed
key, but concurrent mutation during a foreign getter/copy is outside the contract.

getCurrentProfileID converts a throwing optional factory into nil without reading
the competing selection file. The writer still calls its factory directly before
lifecycle acquisition: factory exceptions propagate as before and cannot write a
fallback target. Resolution errors under an acquired writer lease return nil so
artifact acquisition rejects the target and releases ownership. The shared-manager
factory was not moved under the cache monitor or lifecycle lease.

ProfileManager's thread affinity/lifetime rules, optional provider ABI, global
selection/source freshness, same-ID notification filtering, nested mutable input
aliases and arbitrary foreign throwing accessors/destructors remain separate.
The notification handler preserves the existing same-ID skip, ignored numeric
notification IDs, main operation queue and topic. Payload/API misuse is handled
only at the documented guards; wildcard memory safety is not inferred from type
checks. No timeout, queue hop, timer, observer topic or retry loop is added.

H6G publication/save/generation/revision helpers and H6H display/accessors are
compared unchanged. All WiFi hooks/CF ownership, bootstrap, package dependencies,
Makefile and source writer enrollment stay unchanged. Both package schemes compile
the common manager changes. Full Patch 4 remains partial; H5S-partial is preserved.

## Performance and verification

Expected additional cost is low: bounded type checks, an ID string copy and a
short revision claim already required by reload. Obsolete work can stop before
old-target file I/O. Removal of description conversion and a fallback ID value-log
avoids unnecessary work, but read frequency and net latency/CPU are unmeasured.
There is no cache on failed class lookups and no new polling. Files are still read
synchronously under the existing authority policy, outside the cache monitor.

The native cache fixture extracts four exact resolution/notification/reload bodies
alongside H6G/H6H cache code. It provides an optional-manager seam, typed scalar
matrix, mutable ID freeze, throwing getter/factory cases, numeric/default file
fallback, lookup reentry and malformed/stale event cases. The real-source fixture
adds an invalid authoritative profile with a valid competing file and a distinct
candidate, checking error, no copy/write and free lifecycle ownership. Observer
instrumentation now observes the private revision-aware load entry actually used.
Existing actual-center weak-owner/dealloc/idempotent/queued-event cases remain.

The cache fixture is enrolled for rootful/RootHide with both ARC exception modes;
none of these host stand-ins prove private provider/device ABI or threading.
Local validation (Windows, 2026-11-06):

- Regression: 62/63 Python suites and 4/4 Node suites passed. The existing
  test_keychain_bridge_retirement.py environment failure remains: Git Bash cannot
  create /c/Users/ADMIN (4 failures, 1 error, 1 skip). This is not a native build
  failure or a new H6I regression.
- Targeted artifact source contracts, Phase-10 source hardening, RootHide build
  static contracts and RootHide package metadata/negative controls (6/6) passed.
- All four affected native fragment generators completed. The cache and owned
  WiFi fixtures contain the four exact new/updated method bodies; the cache has
  their four unique declarations. Optional provider selector declarations precede
  the generated resolver implementation so ARC can type-check id messages.
- Eight in-memory negative source controls were rejected: arbitrary description,
  missing manager type admission, changed numeric representation, missing file
  root guard, missing event root guard, strong observer owner, missing observer
  exception cleanup, and revision admission moved after lookup. These validate
  source gates, not Objective-C runtime behavior.
- Captured native recipe inspection confirms four cache variants: rootful and
  RootHide, each with/without ARC exception cleanup. No captured compiler or
  binary command was executed. The existing real-source artifact fixture remains
  enrolled for both schemes.
- Reversing only the four changed manager method bodies, removing the added
  handler and its declaration reconstructs HEAD exactly. All other manager code,
  including cache/save/display helpers, is unchanged. git diff --check passed.

macOS Foundation/xcrun/Theos and an iOS device are unavailable here. New native
assertions, package builds and AIDA64/device behavior still require CI/device
verification. No native pass, measured speedup, commit, push or deployment is
claimed.
