# Patch 4C.2H5G — Scope replacement acknowledgement and adoption

2026-10-30: user reports H5F build pass. This patch changes the shared
IdentifierManager implementation for rootful and RootHide. Native Foundation/Theos
and physical injection cannot run on the local Windows host.

## Finding

**High, confirmed logic bug:** `replaceApplicationScopeWithBundleIDs:` assigned
`self.scopedApps = replacement` before calling the void `saveScopedApps`. A source
failure left memory at the requested map, while canonical bytes remained old or
absent. A retry with the same list then returned YES at the memory equality check
without attempting another write. A matching in-memory map could also hide an
external canonical change, a malformed file, or an enclosing uncommitted transaction.
The final `return self.error == nil` additionally confused the invocation's write
receipt with errors set by post-commit publication reentry.

Production caller: `TLinkIOSViewController.syncHookScopeToResetAppIDs:waitingForDaemon:`
requires this BOOL before rebuilding injection filters from canonical scope. A false
success can therefore let filter synchronization continue with stale source scope.
This is a demonstrated source/control-flow defect; no claim that it caused an earlier
RootHide device regression or that every Reset hits this interleaving.

Reproducer: seed old scope, inject one physical source-write failure, request a new
list, then retry the identical list. Previously the first call returned NO after
adopting memory; the second call could return YES with unchanged old source bytes.

## Implementation and deliberate behavior corrections

- Build the requested complete replacement without adopting it. Copy input bundle
  strings before metadata callbacks; retain existing filtering, deduplication,
  case-sensitive IDs, nil-as-empty policy, metadata and helper/extension defaults.
  Reject a non-array request or malformed retained app record with error 6040.
- A private BOOL persistence helper validates and deeply detaches the scope packet
  before source admission. It prepares independent mutable app records for adoption,
  preserving H5F ownership and unknown metadata.
- A replacement always enters standalone source admission and reads canonical scope.
  Only an equal canonical dictionary is a no-op. Missing/different scope is written;
  malformed source fails. Nested attempts reject/poison outer staging as in H4X,
  including a replacement whose local memory already matches.
- Only acknowledged success adopts the candidate. Failed staging/commit keeps prior
  memory, caches and notifications; source recovery retains responsibility for bytes
  and absence. No blind compensating save is added.
- Canonical no-op skips file permission repair, marker writes and notification. If
  memory differs, adopt the canonical-matching candidate and invalidate its stale
  decision caches. A fully matching no-op preserves caches.
- A source write keeps existing permission repair/cache invalidation/topic order.
  Candidate adoption precedes notification; a successor invoked during publication
  is not overwritten afterward. Return the invocation-local success, preserving a
  newer shared error rather than inferring failure from it.

Legacy `saveScopedApps` delegates with adoption disabled and keeps its explicit-write
and notification policy, even for equal bytes. Its already-dirty caller memory remains
caller-owned on failure. The new helper validates/detaches that payload too. Valid
source shape and whole-map replacement policy are unchanged: this is not a merge
API, and existing top-level scope replacement semantics remain intentional.

## Tests and compatibility boundaries

Native group extraction now includes 59 exact production methods, with a controlled
LSApplicationProxy collaborator. Real SourceStore recovery, transaction, capture and
plist encoding remain in the fixture. Cases cover physical failure with present/absent
source and a successful identical retry, canonical no-op/cache/mode invariants, nested
no-op rejection, drifted source despite matching memory, source-equal fresh memory,
mutable metadata detachment, post-marker cleanup exceptions, changed shared error,
publication successor, mutable caller keys/filtering/case, corrupt source teardown,
invalid request/record, and nil/empty scope. Existing void-save H4X fixtures continue
to verify explicit writes, failure rollback, caches and publication.

No RootHide bootstrap, package dependency, hook surface, injection policy or filter
installation procedure is changed. Both native scheme recipes use the same helper;
host stubs do not establish real LaunchServices selector availability or device hooking.

This acknowledges a particular write/observation, not source equality forever after
unlock or an atomic source/filter install. Full replacement can intentionally supersede
another writer. Metadata-lookup reentry, concurrent manager memory, defaults/cfprefsd,
permission/directory durability and whole-workflow transactionality remain separate.
Existing Objective-C exception propagation from providers/publication is unchanged;
no broad exception catch is introduced.

## Performance and lifecycle

No hot hook, polling, timer or queue is added. Replacement no-op now performs bounded
source-gate/control/dictionary reads (existing one-second lock deadline), but avoids
journal/source/marker writes when canonical content already matches. Legacy void save
does not add the replacement-only comparison read. Dirty scope needs
one explicit commit. Detachment plus one mutable copy per adopted record costs O(scope
size) allocations; expected low/moderate relative cost on this cold settings action,
without benchmark claims. Blocks execute synchronously and are not retained on manager.

## Local validation

Windows regression: **62/63 Python suites, 4/4 Node suites pass**. The only failing
suite remains keychain bridge retirement with Git Bash `mkdir /c/Users/ADMIN:
Permission denied` (4 failures, 1 error, 1 skip in 10 tests). Release source gate,
RootHide metadata/negative controls 6/6, exact group/profile-flow fragment generation,
CHECK macro arity and git diff whitespace checks pass. After limiting canonical
comparison reads to the replacement path, source/device-group/profile contracts and
extraction were rerun and pass. Six in-memory negative controls for precommit adoption,
memory-only no-op, shared-error receipt, mutable caller key, void policy drift and
missing ordered adoption are caught by source contracts. These controls do not edit
production files. Native rootful/RootHide Foundation, Theos, package and device results
remain pending macOS CI. Full Patch 4 writer rollout remains partial.


## Build acknowledgement

2026-10-30: user reports H5G build pass. Confirmation is user-provided; local Windows did not execute native Foundation/Theos. H5H continues with version/build metadata refresh transactionality, no-op I/O and defensive optional LaunchServices calls.
