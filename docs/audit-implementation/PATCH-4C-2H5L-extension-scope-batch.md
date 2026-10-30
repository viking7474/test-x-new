# Patch 4C.2H5L — Additive extension scope batch and filter receipt

2026-10-30: user reports H5K build pass. Shared rootful/RootHide manager and two manual
extension-add UI paths change. No native Foundation/Theos/UIKit/device execution is
available on the local Windows host.

## Findings and reproduction

**High, confirmed partial-write defect:** both manual extension paths looped over
expanded IDs, calling single add and enable for each, then saveScopedApps. A later
failure did not undo earlier committed records. Return values were unavailable or
ignored, and the final whole-map save could publish a stale manager bag. One UI path
always showed success; the other inferred success from shared lastError after all
writes. H5K improved single add but did not make this loop a transaction.

**High, confirmed false-success branch:** both callers ignored
PXWriteSubstrateFilterPlists's BOOL. A staging/daemon-sync failure could still display
extensions-added success although injection filters had not converged. This is a
manual workflow finding, not a claimed cause of the earlier AIDA64 RootHide regression.

Reproduce with three expanded IDs and fail the second add, or have filter sync return
NO after source success. Previously some scope changes could remain, final saving
could obscure failures, and success feedback could still occur.

## Implementation

New additive addApplicationsToScopeAndPersist:error: validates the whole array and
copies every nonempty case-sensitive ID before callbacks. Invalid/self entries reject
the entire packet; exact duplicates are removed while preserving order. Empty arrays
are verified read-only no-ops, not replacement/clear commands, and still reject nested
staging. Other scope members are retained.

Initial standalone admission reads/validates current source before metadata. Resolve
LaunchServices class once per batch and prepare each unique standard record outside
the gate. The H5K builder/fallback policy is shared with the single-add wrapper: typed
string copies, Helper/Extension or Unknown defaults, guarded optional KVC, installed/
enabled YES, and target record rebuild with old extensionPattern/custom fields removed.
Unexpected factory/getter/preparation exceptions now become local NSError 6046 before
preferences mkdir or source staging. This is a deliberate crash/failure-policy change
for both batch and its single-item wrapper; KVC fallback is unchanged. Source commit
and post-commit publication are not wrapped in this preparation catch.

One final standalone transaction rereads current canonical scope and merges all
requested records into the current app map. Changed records stage one scope file;
fully matching records stage nothing. Unrequested members, root metadata and settings
bytes survive concurrent provider-time changes. Only after acknowledged source success
are all requested live records adopted and caches/topics published once. Failure in
preparation/staging/commit leaves all requested memory/source publication unchanged,
with byte/absence rollback owned by SourceStore. Memory iteration is synchronous but
is not a global cross-thread atomic map swap.

Both manual extension UI paths call one helper, retaining their prior manager choice.
The existing PXExpandedResetBundleIDs policy is unchanged: exact app/appex IDs, no
wildcard or appended shared WebKit/Safari helpers. Redundant per-ID enable passes and
final whole-scope save are removed. Success feedback/list refresh follows successful
source acknowledgement **and** successful existing full-scope filter synchronization.

If source fails, no filter sync runs. If filter sync fails after commit, report local
partial error 6047 stating that scope was saved and filter sync needs retry. Do not
roll back committed scope or overwrite a newer actor. Retry still runs filter sync
after a canonical batch no-op, avoiding duplicate scope writes/topics when metadata
matches. Error/receipt checks do not use shared lastError. Source/filter installation
remain separate operations; no distributed-transaction claim is made.

## Performance and compatibility limits

For N distinct changed IDs, the previous H5K loop normally used N scope writes plus
an unconditional final scope save, with additional per-ID admissions/enable checks.
The batch has two source admissions and at most one scope write/topic. Metadata lookup
remains once per unique ID; class lookup is once per batch. Healthy matching retries
stage no source writes after required recovery. Work and allocations remain O(scope
size plus requested IDs), expected low/moderate on this cold action, without timings.

Source lock deadlines and the existing synchronous filter writer/polling policy are
unchanged. Filter sync can still block the caller while waiting for installation;
this patch does not solve all main-thread latency or alter its timeout/interval.
Preferences mkdir remains preflight outside byte rollback, as in H5K. No new queue,
timer, observer, package dependency or runtime hook is introduced.

Explicit add is still an upsert at final admission, not a last-started-intent/ABA CAS.
Another actor may replace records after unlock or notification. No gate is held across
metadata, cache/UI effects or filter installation. Concurrent manager dictionary access,
raw/whole-map writers, directory durability, defaults authority and global filter/source
ordering remain separate. The batch covers source atomicity and ordinary preparation/
commit failure publication, not every possible UI or memory-allocation exception.

## Verification

The group recipe extracts 69 production methods plus the exact extension workflow
helper; a Foundation adapter supplies expansion/filter collaborators while preserving
real manager/SourceStore logic. Existing H5K single-add cases still exercise the shared
metadata builder and fallback variants.

New scenarios cover immutable/deduplicated IDs and caller array mutation, concurrent
other-member/root merge, one batch source write/topic, matching and empty no-ops,
physical fault with present/absent scope and retry, second-metadata failure before any
publication, whole-packet invalid/self rejection, nested empty poison, all-members-visible
notification and a removal successor. UI cases verify source failure skips filter,
filter failure retains committed scope with error 6047, retry sync after source no-op,
empty expansion rejection and frozen root identity. Source guards check both actual
UIKit callers gate success dialogs and remove the old loops/saves.

The filter collaborator verifies outside-gate canonical observation and receipt
handling; it does not install real filter files. Exact expansion/filter implementations
and their bootstrap policy checks are unchanged. Real LaunchServices, UIKit, daemon
transport/injection and native compilation require macOS CI/device validation.

## Local validation

Windows regression: **62/63 Python suites and 4/4 Node suites pass**. The remaining
keychain bridge retirement suite retains Git Bash `mkdir /c/Users/ADMIN: Permission
denied` (4 failures, 1 error, 1 skip in 10 tests), the existing host limitation. Release
source hardening, RootHide metadata/negative controls 6/6, exact group/profile fragment
generation, CHECK macro arity and git diff whitespace checks pass.

Eight in-memory source mutations for nested staging, mutable keys, early memory
publication, uncaught metadata preparation, empty admission bypass, ignored source
failure, ignored filter receipt and ungated UI success are rejected. The unguarded
preparation control was also rerun as a syntactically valid removal of the try/catch.
Final fragment review caught a native recipe ordering issue: the extracted builder
preceded its optional-KVC C helper. Production order was already correct. The recipe
was reordered, with a dedicated guard, emitted-fragment assertion and reversed-order
negative check. Targeted source/group/profile contracts and extraction pass afterward.
No production file is edited by negative controls.

Native Foundation/Theos builds for both schemes, real expansion/LaunchServices,
UIKit, daemon filter installation and device injection remain pending macOS CI/device.
Full Patch 4 writer rollout remains partial.

2026-10-30: user reports H5L build pass. This acknowledges their build result; local
Windows validation still does not imply native or device execution. H5M follows.
