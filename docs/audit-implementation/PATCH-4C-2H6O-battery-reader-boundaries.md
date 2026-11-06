# Patch 4C.2H6O — BatteryManager scalar and range boundaries

2026-11-06: user confirms H6N build passes and authorizes continuation. Read the
complete BatteryManager/header, BatteryHooks consumers, IdentifierManager display
calls, H3H persistence contract and artifact fixture. This batch changes three
reader bodies, adds one private field adapter and math import/declaration. Other
BatteryManager implementation, including persistence/publication, is unchanged.

## Findings and changes

1. **Medium / P1, confirmed logic bug — exact 1% is spuriously repaired.**
   common/BatteryManager.m, batteryLevel. storedLevel is float, but the lower
   comparison used double literal 0.01. Binary32 0.01 is approximately
   0.009999999776482582, so promoting it to double for the comparison makes it
   less than the double threshold. A stored string 0.01 can therefore invoke
   generateBatteryLevel, replacing a valid requested 1% with a random level and
   attempting the owned save/mirror path. Later reads use the repaired value;
   this is not a claim of a save on every read unless 1% is repeatedly reapplied.

   Compare with 0.01f/1.0f in the same precision as storedLevel. This also matches
   the hook's float-domain battery bounds. Intentional correction: exact float
   1% is accepted and no longer randomized merely by reading it. Existing float
   parsing/range policy is retained; no strict decimal parser or clamp is added.
   Host struct-pack evidence confirms the comparison; new native Foundation and
   real-plist cases must confirm the complete Objective-C path on CI.

2. **Medium / P1, confirmed unsafe selector paths — untyped persisted fields.**
   loadBatteryInfoFromDisk adopted BatteryLevel directly into a string cache,
   then batteryLevel sent length/floatValue. Numeric plist levels do not supply
   NSString.length; arrays/dictionaries/data/dates can likewise crash on string
   selectors. LowPowerMode was sent boolValue without a type guard, so valid
   plist containers in that field can raise an unrecognized-selector exception
   during load, including singleton initialization. No device occurrence or
   frequency is asserted; the selector paths and malformed plist inputs suffice
   to reproduce the type mismatch.

   Add private applyLoadedBatteryInfo:profileSpecific:. Accept NSString levels
   by copy without reformatting; accept NSNumber levels through stringValue/copy
   so the public reader returns its documented string. Numeric compatibility is
   intentional and consistent with BatteryHooks' existing numeric scalar support;
   the old manager path could crash instead. Bool conversion remains boolValue
   for NSString/NSNumber, including explicit false and existing textual grammar.
   Unsupported fields use the existing missing-field policy. Check cache type
   before string selectors as well, so malformed in-memory values can reach the
   existing repair path. Mutable loaded strings no longer alias caller storage.

3. **Medium potential / P1 — NaN bypasses two-sided comparisons.** batteryLevel.
   Neither NaN < minimum nor NaN > maximum is true, so an available NaN conversion
   could pass the old range guard. Add isfinite before the float bounds. Infinite,
   malformed, empty and out-of-range levels still use the existing generator/save
   path. NSString parsing of NaN text is platform-dependent; the fixture includes
   a controlled string-converter stand-in returning NaN to exercise this branch
   without claiming a particular Foundation text parser behavior.

## Read/fallback behavior and lifecycle

Keep canonical identity battery_info, then pre-identity profile battery_info,
then global plist. A present dictionary, including an empty dictionary, remains
an authoritative profile record rather than a request to merge missing fields
from the global mirror. A missing or unsupported level preserves the prior cache.
A profile missing/unsupported LPM resets NO and marks loaded; a global missing/
unsupported LPM preserves an already loaded value, otherwise defaults NO without
marking loaded. These subtle profile/global differences are covered explicitly.

Canonical selection remains the only profile-path authority here. Missing/invalid
or numeric ProfileId continues to global read fallback; the WiFi numeric-ID policy
is not imported. Add root checking and explicit local cleanup to the path/loader/
field adapter. Unsupported field values change from unsafe selector behavior to
missing-field handling; unexpected non-dictionary collaborator roots are treated
as unavailable. Normal NSDictionary file APIs already return nil for invalid roots.

Both scalar conversions finish before field adoption. That is not an atomic
multi-thread cache transaction: raw ivars remain unsynchronized, other entry
points can still mutate them, and per-instance/profile revision ordering remains
separate. No broad catch of foreign throwing conversions is added. Public setters,
committed adoption and publication input validation are outside this reader batch.

Generation retains existing cache-first and persistence-failure behavior. Missing/
invalid level repair still calls the existing generator, which owns its save;
the getter adds no second save. No range validation is moved into load-only calls,
so lowPowerModeEnabled does not become a level-repair writer. Source/lease/journal,
mirror/notification order, no-active global-only write policy and errors remain
unchanged. Literal strings keep spelling, whitespace and the existing floatValue
parser; NSNumber values get their ordinary stringValue representation.

The common implementation is compiled for rootful and RootHide. BatteryHooks,
WiFi/H6N, RootHide captured-reader authority and iOS 15.8.8/AIDA64 bootstrap,
constructor, scope, hook installation, Makefile, package dependencies and writer
manifest remain untouched. Full Patch 4/H5S-partial remains partial.

## Performance

Avoiding the incorrect 1% repair removes a generation, attempted source ownership/
commit and legacy mirror on that trigger; relative avoided cost can be moderate
or high when persistence succeeds. This is source-flow reasoning, not a benchmark.
Normal reads gain bounded type/finite checks, one field adapter call and scalar
copies/conversion. Immutable NSString copies normally retain/share immutable data;
numeric normalization may allocate a string. Expected ordinary overhead is low
relative to existing synchronous file reads, but no CPU/latency/allocation claim
has been measured. Getters still reload from disk, including existing redundant
loads in display callers. No TTL, queue, timer, observer, lock or polling is added.

## Verification

- Windows regression: 62/63 Python + 4/4 Node suites passed. The remaining
  test_keychain_bridge_retirement.py suite is the established Git Bash
  mkdir /c/Users/ADMIN permission failure (4 failures, 1 error, 1 skip).
- Artifact source contracts, Phase-10 source hardening, RootHide static build and
  RootHide metadata/negative controls 6/6 passed.
- Four fragment generators completed. Four reader/adapter bodies and their unique
  declarations are extracted exactly; the owned fixture includes the same bodies
  and declares the new helper before use. Restoring the three original reader
  bodies and removing helper/import/declaration reconstructs HEAD exactly.
- Eight in-memory negative source controls reject the double boundary, missing
  finite check, missing numeric compatibility/copy, unsafe bool conversion,
  removed profile/global missing-field rules and missing adapter input cleanup.
- New Foundation reader fixture covers precedence/read counts, empty profile,
  missing/numeric/malformed selection, scalar/container/date/data/NSNull fields,
  textual/numeric bool conversion, mutable strings, float endpoints, repair and
  malformed cache. NSNull/custom converter/root stand-ins are not claimed to be
  values returned by the normal plist reader in those shapes.
- Existing real-source fixture adds actual plist 1% and numeric/container cases,
  asserting no repair/source commit/mirror/notification, then restores exact
  artifact bytes. Existing one-save repair/rollback/busy/pending/mirror checks stay.
- Captured native recipes include rootful/RootHide x both ARC exception modes for
  the new reader at -O0, plus both existing real-source variants. No compiler or
  binary call was executed. git diff --check passed.

Foundation/xcrun/Theos and an iOS device are unavailable on this Windows host.
New native assertions, package builds and device behavior require macOS CI/device
verification. No new native/build/device pass, commit, push or deployment is claimed.

Remaining BatteryManager cache concurrency, BatteryHooks snapshot/profile/clock
ordering, repeated synchronous read cost and total mirror/publication ordering
remain separate work; this batch does not claim the battery flow is complete.
