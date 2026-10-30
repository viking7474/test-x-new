# Patch 4C.2H5Q — Detached, typed scope metadata exports

2026-10-30: user reports H5P build pass. Shared rootful/RootHide manager changes;
no native Foundation/Theos or device execution is available locally on Windows.

## Findings and production callers

Location: common/IdentifierManager.m, getApplicationInfo:; public contract in
common/IdentifierManager.h. Concrete callers include TLinkIOSViewController's settings
list and dashboard rows, ProfileManagerViewController.appsNeedingBackupBeforeSwitch,
BottomButtons.killEnabledApps, ProfileManager's termination fallback and
FreezeManager.freezeApplication:. None of those device actions is executed by this patch.

**Medium, potential malformed-metadata exception (P1):** the bulk getter assumed every
root, key and record had dictionary/string shape. It copied a record, subscripted it
and projected originalBundleID without validating its type. Non-dictionary local
records could throw in the getter; invalid enabled/installed fields or string metadata
could escape into callers that use boolValue, length or string APIs. Existing load
validation covers root/records/enabled, but does not validate all display metadata or
installed. H5O hardened decision readers, not this bulk export. These are conditional
failure paths; no current device crash is asserted.

Reproduce with a dictionary scope containing a valid record plus an array/number
record, or a record whose installed/name/originalBundleID is an array. Request all
metadata, then follow the installed/display consumer path. A malformed local root or
non-string map key is another defensive case. The fixtures test those shapes directly.

**Medium, confirmed shallow-copy ownership defect (P1):** both query variants copied
only the record dictionary. Nested mutable strings, arrays, dictionaries and data
still belonged to manager memory. A caller holding an exported record could observe
later manager mutation or mutate nested data without a source commit/cache invalidation.
The fixture demonstrates both directions. Repository callers mostly read metadata;
no specific production nested-mutation writer is claimed.

## API behavior and implementation

The input contract is retained: nil requests all records, a string requests an exact
key, and a missing single record returns nil. Non-string non-nil input now returns nil
before accessing state. Empty strings remain string lookups rather than becoming bulk
requests. A missing/malformed local root yields nil for a single request and a mutable
empty dictionary for the bulk request.

Single lookup detaches only its selected dictionary through PXDetachRuntimeGeneration,
validates the detached known fields and returns a mutable record. No entire-scope clone
is needed for a single lookup. Invalid or non-plist single records return nil.

Bulk lookup independently skips non-string keys, non-dictionary records and non-plist
rows before collecting candidates. It serializes/detaches the aggregate once, rather
than doing a binary encode/decode per row. It validates known fields on that detached
packet, then makes mutable output records under their original exact-case map keys.
This prevents one invalid opaque row from discarding all unrelated valid rows. It is
not synchronization against another thread mutating a dictionary during collection.

The exported schema permits missing fields, NSNumber/NSString enabled and installed,
and NSString name/version/build/bundleID/originalBundleID/extensionPattern. Known fields
with other types cause that row to be omitted (or nil for single lookup). Raw valid
scalar values, including false and string booleans, are retained without coercion.
Unknown plist-compatible fields remain in the record. Static C arrays of field names
avoid allocating field-list NSArray objects for each record validation.

Bulk-only display projection is preserved: originalBundleID, when present, replaces
the exported record's bundleID; the dictionary key is never renamed. A single query
continues to return its raw bundleID field. Empty originalBundleID strings retain the
old projection behavior. Disabled/uninstalled records and empty valid dictionaries
remain visible. The getter never filters by the spoof decision, installed truth or
self/system ID policy.

## Deliberate malformed-data correction and limits

Malformed rows no longer crash or expose unsafe known field types to list consumers.
They can be absent from UI/backup/termination enumeration until repaired by an owning
write/reload. This is an export policy, not scope revocation: no membership, flag,
canonical bytes or hook enablement is repaired/disabled by the read. The getter has
no NSError result; it preserves shared manager error and does not add logging/UI
feedback. Better malformed-row diagnostics remain separate work.

Outer dictionaries and exported record dictionaries stay mutable, matching prior
caller behavior. Nested plist values are detached immutable values under the existing
serialization convention. Callers may copy a nested value before editing/replacing it.
No record/container identity, custom subclass or NSNumber storage-width preservation
is promised. Aliases within the original graph are not part of the export contract.

Authority is unchanged: getApplicationInfo: reads local manager memory, including in
an injected process. It does not enroll this metadata API in runtime snapshot reads,
trigger bootstrap, load disk on a cache miss or consult providers. The specialized
RootHide boolean reader paths continue to use their own snapshot authority.

Concurrent mutation of manager scope/maps, arbitrary hostile Objective-C subclasses,
and read/export failure diagnostics remain outside this phase. Full Patch 4 remains
partial; detached output does not make the mutable source graph thread-safe.

## Performance and lifecycle

A shallow O(record count) copy becomes O(exported plist graph size) work. Single-query
cost is limited to one record; bulk performs per-row validity preflight and one
aggregate detachment followed by mutable record copies. Temporary encoded bytes and
the immutable graph add peak memory/autorelease pressure. Relative cost is low/moderate
for small metadata and can be high for large custom blobs; no device profile or timing
benchmark is available. This is a correctness/lifetime change, not a claimed speedup.
The UI's bulk-then-single pattern may copy a row again; it does not clone the full map
for each row. No export cache is added without a complete invalidation contract.

There are no new source writes, preferences reads, IPC, private class lookups, timers,
observers, queues or production callbacks. ARC owns temporary records/data without
retaining manager callbacks or creating cycles. Existing cache/error/notification
state is not changed by a metadata read.

## Validation

The group recipe retains **75 exact production methods** and adds the exact
PXScopeInfoRecordIsSafe C helper to its extracted statics. Existing constructor/state,
metadata UI and profile-flow fragments remain included. Native fixtures cover both
query variants, mutable output records, exact key/projection behavior, false/string
flags, empty metadata, missing/non-string IDs, malformed roots/records/keys/known
fields, a non-plist row beside a valid row, nested string/container/data isolation,
local injected authority, and unchanged source marker/cache/error/provider counters.
The reverse-alias check edits a returned mutable nested container when available,
otherwise a caller-owned copy, and verifies the manager graph remains unchanged.

Windows regression: **62/63 Python suites and 4/4 Node suites pass**. The remaining
keychain bridge retirement suite retains the known Git Bash mkdir permission failure
at /c/Users/ADMIN (4 failures, 1 error, 1 skip in 10 tests). Release source hardening,
RootHide metadata/negative controls 6/6 and the RootHide static build gate pass.
Exact 75-method group/export-helper/constructor/state/profile fragments, emitted
C-helper definition order, CHECK macro arity and git diff whitespace checks pass.
The reversed C-helper order negative control is rejected as before.

Twelve in-memory export controls reject shallow single/bulk copies, skipped single/bulk
shape validation, allowing one invalid graph to poison the aggregate, non-string keys,
unvalidated installed flags, filtering disabled rows, projecting originalBundleID into
single queries, renaming bulk map keys, new disk reloads and shared-error mutation.
No production files are modified by negative controls. Targeted source/profile/RootHide
checks and fragment review pass after strengthening reverse-alias assertions.

Native Foundation/Theos builds and runtime checks for both schemes remain pending
macOS CI/device validation; local contracts are not native execution proof.
