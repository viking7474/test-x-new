# Patch 4C.2H5T — Reader and custom-input safety batch

2026-10-30: user confirms the H5S build passes and requests several related
items per implementation round. This batch changes shared IdentifierManager
production code used by rootful and RootHide. It does not complete Patch 4.
The source-writer enrollment marker remains H5S-partial: this supplement does
not enroll a new source or establish a new authority/transaction boundary.

## Findings and changes

1. **Medium, confirmed unsupported-selector paths:** `isIdentifierEnabled:`
   indexed an unchecked live settings root and called `boolValue` on arbitrary
   values. A dictionary/array flag can raise an exception. Capture the live root
   once, admit dictionaries and check `respondsToSelector:boolValue` before
   invoking it. Keep custom live-memory bool converters accepted by the existing
   full-save sanitizer; injected RootHide still uses the existing stricter
   PXRuntimeReadBool and missing-key inference. Invalid/empty identifier input
   now returns before beginning the snapshot operation in both public readers.

2. **Medium, confirmed return-contract mismatch:** `currentValueForIdentifier:`
   coerced canonical NSNumber values to NSString but returned arbitrary objects
   from scalar sidecars and battery sidecars. ATT display converted even a
   container into its textual description. One scalar display helper now accepts
   NSString unchanged (including empty manager strings), converts NSNumber with
   stringValue, and ignores unsupported objects. This intentionally fixes the
   numeric sidecar return type; well-formed string display is unchanged. A caller
   sending string selectors to the old array/number result could crash; no
   measured device crash frequency is asserted.

3. **Medium, confirmed unsupported-selector paths:** `attAuthorizationStatus`
   and the stored-uptime display sent integerValue/doubleValue to untyped plist
   members. Array/dictionary/date values can raise an exception. Admit NSString
   and NSNumber before conversion. ATT retains canonical-first, tracking fallback,
   0..3 bounds and default 0, including legacy integerValue semantics for
   nonnumeric strings. Uptime retains positive-only hours formatting and Not Set.

4. **Medium, confirmed malformed preference crash path:** the Canvas reader sent
   boolValue directly to both security plist aliases. Use existing PXRuntimeReadBool.
   A present primary false or malformed primary remains authoritative (disabled);
   the legacy alias is consulted only when the primary key is absent. This does
   not change the security writer, noise nonce, notification or IPC contract.

5. **Medium, confirmed custom-input validation/lifecycle gap:** a wrong-type
   serial used length, and a wrong-type theme could fail during copy or
   isEqualToString. Generic custom save resolved/migrated the target and acquired
   ownership before rejecting nil/unsupported input. Reject non-string values or
   unknown sidecar identifiers before ownership; guard serial type before length
   and theme type before copy/comparison. Theme keeps error 2004, Light/Dark and
   paired commit policy. Generic/serial invalid input returns NO without adding a
   new error contract. Existing valid string handling, generation counters,
   ownership release and post-commit publication remain unchanged.

6. **Low, refactoring/performance opportunity:** 16 scalar sidecar branches
   duplicated the writer filename registry; the sparse-toggle inference helper
   constructed a constant dictionary and arrays each time it reached its schema.
   Reuse PXRuntimeIdentifierSidecar and initialize only the constant inference
   schema with dispatch_once. Cache no profile values, decisions or mutable state.

Reproduction for selector bugs: in a disposable test profile, use an array or
dictionary for ATTAuthorizationStatus/system_uptime value or a Canvas flag, then
invoke the corresponding getter. For the return mismatch, store NSNumber under
advertising_id.plist/value and inspect the dynamic result type. The fixtures use
temporary directories rather than modifying a real profile.

## Preserved authority and boundaries

RootHide injected identifier values still come from PXCurrentIdentitySnapshot;
missing/invalid snapshots cannot reach manager file/provider fallbacks. Injected
toggle explicit false still beats inferred evidence; missing keys keep the same
inference map, WiFiAddress alias and secondary flag rules. Manager values still
use the live selected profile. Canonical IDs precede sidecars, and SystemBootUUID
retains its one-way HardwareUUID fallback and the existing difference between
empty manager and empty injected strings.

ATT and Canvas getters retain their existing file authority, including their
pre-existing behavior when called in injected processes. This batch does not
redesign that authority. Nor does it make the complete legacy display method a
pure or globally type-safe reader: unchanged provider fallbacks can still
generate data, reload disk or return provider-specific objects. The existing
profile resolver/migration, compound WiFi/storage display, battery percentage
formatting and provider exception handling remain separate work.

No bootstrap/ctor, hook/filter installation, package dependency, polling interval,
network policy, observer ownership or queue changes. The iOS 15.8.8/AIDA64 cold
bootstrap fix remains intact. No manager-wide concurrency, atomic multi-file read,
durability, or full source consistency claim is added.

## Relative cost

Type/selector guards are low overhead; no new file opens, IPC, locks or queues
are added to valid reads. Scalar sidecar fallback still opens only the requested
sidecar after the existing canonical read. Registry lookup replaces a chain of
string comparisons; expected cost is low and no latency benchmark is claimed.
The inference schema avoids repeated dictionary/array construction on missing-key
reads; impact depends on sparse preference frequency, which is not measured.
Invalid custom input avoids target resolution, possible migration and ownership
work. Existing synchronous file/provider paths remain and may dominate latency.

## Validation

The existing test_runtime_identifier_writers.py --native CI command now also
builds PXIdentifierReaderTests.m for rootful and RootHide. It extracts six exact
production reader/wrapper methods, four exact C helpers including the real writer
registry, and compiles the real PXRuntimeSnapshotReader.m. Only role, operation
entry instrumentation, capture, paths and legacy providers are controlled
collaborators. This tests method behavior, not injection or lexical-scope runtime.

Native cases cover all 16 sidecars, canonical/legacy precedence, empty strings,
numeric conversion, malformed roots/members, all ATT statuses and fallbacks,
Canvas primary/alias precedence, serial dispatch, invalid identifiers before
capture, live custom bool conversion, injected no-disk fallback and new snapshot
evidence after the cached schema has been initialized. The existing writer
fixture adds invalid value/type/theme cases and verifies no target/provider/write
or compatibility-cache effects. CHECK macro arity and C helper ordering are
checked before native compilation.

Local Windows validation: 62/63 Python gates and 4/4 Node gates pass, plus source
hardening, RootHide metadata/static contracts, exact identifier/group/profile
fragment extraction and ten in-memory negative controls. The remaining bridge
retirement shell test has its existing Git Bash mkdir permission failure.
Native Foundation, Theos packages and device tests cannot run in this workspace;
this batch requires the next macOS CI build and device verification. A successful
source-contract run is not reported as a successful native test run.

## Priority

P1: guard the five correctness/input areas above. P2: shared registry and constant
schema cache. No new P0 finding or evidence of a device-level critical incident.
Full Patch 4 remains partial, especially authority, concurrent manager memory,
remaining direct writers and real-device compatibility/performance validation.
