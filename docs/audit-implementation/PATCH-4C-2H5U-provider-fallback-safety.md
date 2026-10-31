# Patch 4C.2H5U — Compound and provider fallback safety

2026-10-30: user confirms the corrected H5T native build passes and authorizes
continued implementation. Shared IdentifierManager changes apply to rootful and
RootHide manager reads. This is a grouped correctness/performance supplement;
source-writer enrollment remains H5S-partial and the full audit is not complete.

## Findings and implementation

All locations below are in common/IdentifierManager.m unless stated otherwise.
The unsafe operations are confirmed in source. Malformed provider results,
partial provider implementations and device crash frequency are not asserted
to have been observed on a real device.

1. **Medium / P1 — compound display packet types.**
   currentValueForIdentifier: trusted the iOS version provider to return a
   dictionary and sent containsString to an untyped file version. Storage and
   battery generator results were also subscripted without root checks. Arrays,
   NSNull or scalar packets can raise unsupported-selector exceptions. Admit
   dictionaries before keyed access; use the existing scalar display helper for
   iOS members, WiFi pairs, storage fields and generated battery display. Reject
   container descriptions instead of displaying them as identities. Valid
   canonical/string/number precedence and empty-string handling remain intact.

2. **Medium / P1 — optional storage setters.**
   Both generated and final storage fallbacks checked some getters/generators,
   then unconditionally invoked all three compatibility setters. A partial
   provider can support generation but omit a setter. Check each setter before
   invocation in both paths. Generated total/free must be scalar before adoption;
   a malformed optional filesystem member is ignored, not converted to nil and
   used to erase existing metadata. A genuinely absent filesystem retains the
   prior nil setter behavior. Normal complete providers still receive all three
   setter calls in the same order.

3. **Medium / P1 — battery float-to-int conversion.**
   Two paths converted an unchecked provider float times 100 to int. Containers
   can fail floatValue; NaN/infinity or out-of-int-range finite values make that
   integer conversion undefined. A shared PXIdentifierBatteryPercentage helper
   admits NSString/NSNumber, keeps the same float multiplication and truncation,
   and checks finiteness plus INT_MIN/INT_MAX using double comparisons before
   the cast. Using double for bounds avoids rounding INT_MAX to 2^31 in a float
   comparison. Invalid cached levels proceed to the existing generated fallback;
   invalid generated levels are unavailable. Finite negative or >100 percentages
   that remain representable are deliberately not clamped; numeric parsing of
   legacy strings is unchanged.

4. **Medium / P1 — remaining scalar/provider return boundaries.**
   Thirteen scalar provider getters and the individual battery level could
   return arbitrary objects through an NSString API. Apply the same H5T scalar
   boundary: preserve strings, stringify NSNumber, reject containers/dates.
   Guard the provider BootTime result as NSDate before NSDateFormatter. This
   protects the return/formatting boundary, not the internals of provider calls;
   a provider that itself throws is still allowed to surface that exception.

5. **Low / P2 — duplicate profile resolution in admitted uptime/boot reads.**
   The method had already resolved identityDir, then resolved it again just to
   build system_uptime.plist or boot_time.plist. Reuse the first directory in
   those two branches. This removes one resolver invocation per such read and
   prevents those sidecar paths drifting to another profile during the same
   admitted branch. Other legacy resolver/provider calls remain unchanged; this
   is not a single-profile or atomic-read guarantee for the entire method.

## Reproduction and native cases

Use controlled provider adapters or temporary profile plists, never a live user
profile. Return an array as currentIOSVersionInfo/generateBatteryInfo/storage
generation result; use an array as a WiFi scalar or iOS version; return NSNumber
NaN/infinity/large magnitude as batteryLevel; provide storage generation without
setTotalStorageCapacity:/setFreeStorageSpace:/setFilesystemType:; return a string
as a provider boot date. These reproduce the unsupported-selector/unsafe-cast
paths or incorrect return types independently of a device incident.

Extend the existing PXIdentifierReaderTests fixture and its CI command rather
than adding a separate platform lane. Controlled provider overrides cover:

- Malformed packet roots and members, canonical/sidecar/provider precedence,
  numeric scalars and valid/empty generated display values.
- Cached and generated storage, exact setter values/order, providers with no
  setters, final fallback with no setters, malformed filesystem suppression.
- Cached battery avoiding generation, one reload retained, generated fallback
  exactly once, non-finite/boundary values, truncation and no new clamping.
- All 13 scalar providers returning containers or numbers, stored uptime/boot
  resolving once, and invalid provider boot dates.

The fixture now extracts the percentage helper as a fifth exact C helper and
includes math/limits headers explicitly. Existing six production method bodies
are still extracted with the corrected balanced-brace parser and an independent
section boundary oracle. Existing writer production fragments and the injected
RootHide read prefix are checked against HEAD and remain identical.

## Performance, side effects and residual work

The new checks have low relative CPU cost and add no files, IPC, queues, timers
or locks. Numeric provider string conversion allocates only when a number must
cross the string API. Formatter allocation/locale behavior is unchanged. Resolver
reuse saves one call on each admitted stored uptime/boot display; the absolute
I/O/latency effect depends on resolver state and is not benchmarked.

**Confirmed remaining performance/consistency issue:** StorageManager's setters
at setTotalStorageCapacity:, setFreeStorageSpace: and setFilesystemType: each call
saveToCurrentProfile. A complete legacy fallback can therefore perform three
separate persistence attempts. H5U intentionally preserves those calls on valid
data. Gating optional selectors does not make them atomic or reduce their normal
write count. A follow-up should prepare one packet and persist/adopt it under
one lifecycle/source owner, preserving error, fallback and notification policy.
Replacing setters with cache-only adoption here would lose persistence.

Legacy storage fallback may still generate random capacities and write from a
display read; battery fallback may reload/generate/persist. The iOS fallback can
still resolve/read its file again. No global manager thread-safety, callback
reentrancy, provider ABI validation, coherent read snapshot or pure-reader claim.
No hook, bootstrap, filter, package, notification or polling policy changes.
RootHide injected reads still stop at their snapshot branch and cannot enter
these manager disk/provider fallbacks.

## Validation and status

Local Windows: 62/63 Python and 4/4 Node gates pass, plus source hardening,
RootHide metadata/static contracts, exact identifier/group/profile fragments,
CHECK arity/helper order and 12 in-memory negative controls. The known bridge
retirement Git Bash mkdir permission failure remains the single Python gate
failure. No native Foundation, Theos or device execution is available locally;
the expanded rootful/RootHide native reader fixtures need the next macOS CI run.

P1 fixes: packet/field types, optional selectors, safe percentage conversion and
scalar/date return boundaries. P2: reuse the admitted sidecar directory. Next
material item: combine the legacy storage fallback persistence under one owner,
with rollback/error/notification coverage. Full Patch 4 remains partial.
