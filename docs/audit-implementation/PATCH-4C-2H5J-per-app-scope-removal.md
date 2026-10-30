# Patch 4C.2H5J — Verified per-app scope removal

2026-10-30: user reports H5I build pass. Changes apply to the common manager used
by rootful/RootHide and the two dashboard removal actions. Windows cannot run the
native Foundation/Theos or UIKit/device validation.

## Findings and reproduction

**High, confirmed logic defect:** removeApplicationFromScope: deleted live memory
before calling full saveSettings. A source failure retained the app on disk while
removing it from manager memory. Full-bag saving also flushed unrelated dirty flags
and stale scope records during an operation intended to remove just one ID.

**Medium, confirmed UI receipt gap:** the app-options remove action always reloaded
its list and the remove-button action always called updateAppsList after the void
remover, without checking persistence. A failed write could therefore hide the app
from the visible list while canonical scope still enabled it.

Reproducer: seed a scoped app, fail a physical source write, then invoke either remove
action. Previously memory lost the entry before failure; UI proceeded to refresh from
that memory. H5I corrected enablement only. This patch handles removal; add and extension
batch operations still require their own review.

## Implementation and intentional corrections

New `removeApplicationFromScopeAndPersist:error:` validates a nonempty NSString ID,
then copies its exact case before source callbacks. A standalone transaction reads
and validates current canonical scope. If that key exists, clone/merge the current
scope and remove only the requested app. Other app records, top-level metadata and
settings bytes are preserved. Last-member removal keeps the scope plist with its
empty map, as before; this is not deletion of an app's data or its source directory.

If the source entry/file is already absent, acknowledgement is a read-only no-op
(after required recovery). It does not materialize a new scope file, marker or topic.
It still passes standalone admission, including nested-call rejection/poisoning.
Matching memory is never used to skip a remaining canonical app.

Only source success removes the requested live entry. Other dirty memory records
remain untouched. Clear decision caches on a source write or actual memory deletion;
fully matching absence preserves caches. Notify only for a source change. Source
failure leaves live membership/cache/topic untouched and delegates byte/absence
recovery to SourceStore. Invalid IDs report error 6044 instead of unsafe nil/type use.

The old void API delegates. Success/error outputs are invocation-local and successful
publication does not clear a newer shared error. Memory removal precedes notification,
with no later delete, so a callback that re-adds the ID retains its newer source and
memory record. A successful acknowledgement does not promise permanent absence after
unlock or notification.

The two dashboard removal actions now call one BOOL UI helper and refresh their list
only on success. The helper presents the local error on failure. The action-sheet
path still passes sharedManager; the remove-button path still passes self.manager,
preserving their prior instance choices. No additional confirmation step is added;
persistence failure uses the existing error presenter.

**Deliberate corrections:** remove no longer flushes unrelated pending settings/scope,
failed persistence no longer hides membership from memory/UI, and absent canonical
membership is verified rather than rebuilding a file from stale memory. Existing
exact-key, case-sensitive deletion and notification topic remain. No hook, injection
filter policy, RootHide bootstrap/dependency or app termination behavior changes.

## Performance, lifecycle and boundaries

A changed deletion stages one scope file instead of a settings/scope pair. Canonical
absence still takes the existing bounded source gate/read/control checks but avoids
new source/journal/marker writes after recovery. No LaunchServices query, queue, timer,
polling or observer is added. Work/copies scale with scope size; relative cost expected
low/moderate on a cold UI action, with no measured latency claim. The one-second lock
contention budget remains.

The gate is released before memory/cache/topic/UI effects. All new blocks are
synchronous and not retained on manager. Existing Objective-C publication exception
propagation remains unchanged. This is cooperative file serialization and a local
receipt, not a global lock around mutable manager dictionaries or a source/filter
transaction. Another owner may re-add the same bundle after admission; removal is
an explicit ID operation, not a generation/ABA-guarded delete. Add/extension batches,
global memory/defaults authority and cache/filter convergence remain separate.

## Verification

The native group recipe extracts 66 production methods plus the exact switch action
and removal UI helper. A Foundation-only UI adapter tests local error/receipt and
supplied-manager identity with actual manager methods and SourceStore. Source guards
check both real UIKit closures return on helper failure before their existing list
refresh. UIAlert presentation and closure dispatch still require UIKit/device checks.

Scenarios cover one-file removal and unrelated fields/settings preservation, canonical
absence with stable caches/marker, stale local cleanup, missing memory with present
source, physical failure and void retry, nested present/absent no-op poisoning, absent
file preservation, invalid/case-sensitive IDs, corrupt bytes and exact teardown,
mutable ID capture, post-marker housekeeping, a publication successor re-adding the
app with a newer error, and UI helper failure/retry using its supplied manager.
The macOS native recipe compiles/runs both rootful and RootHide defines; local source
extraction does not prove native execution.

## Local validation

Windows regression: **62/63 Python suites and 4/4 Node suites pass**. The keychain
bridge retirement suite retains the known Git Bash `mkdir /c/Users/ADMIN: Permission
denied` failure (4 failures, 1 error, 1 skip in 10 tests). Release source hardening,
RootHide metadata/negative controls 6/6, exact group/profile fragment generation,
CHECK macro arity and git diff whitespace checks pass.

Eight in-memory negative controls for restoring the void full save, precommit memory
delete, allowing nested staging, trusting memory absence, retaining mutable caller ID,
using shared error as receipt, UI false success or UI refresh without receipt are all
rejected. These controls do not modify production files. Native Foundation/Theos
rootful/RootHide builds, real UIAlert delivery and physical-device injection remain
for macOS CI/device validation. Full Patch 4 writer rollout remains partial.
