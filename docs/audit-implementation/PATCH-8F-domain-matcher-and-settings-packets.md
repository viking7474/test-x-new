# Patch 8F — Domain matcher and settings publication packets

Date: 2026-11-16. Baseline `286db57` (Patch 8E), whose build the user confirms
passed. This batch covers the DomainBlockingSettings model from load/migration
through edits/save/publication and network/UI readers, plus the master switch's
call into that model. Transport adapters and NSURLSession task lifecycle stay
unchanged. This is source implementation with native CI enrollment, not a claim
that the full audit or device acceptance is complete.

## Top 10 changes, ordered by priority and expected impact

No new Critical issue is established. Severity describes the failure's impact;
priority includes correctness before optimization. Costs are relative estimates
from the operations in source, without a benchmark or a device reproducer.

| # / Priority / Severity / Evidence | File/function and problem | Change / expected impact |
| --- | --- | --- |
| 1 / P1 / Medium / proven lock coupling | `common/DomainBlockingSettings.m`, old `isDomainBlocked:`, save/load/edit methods: the same recursive monitor covered matcher reads and synchronous filesystem work. A decision could wait for another thread's disk access. | One retained policy packet under a separate short unfair lock; matching, UI projection, hashing and retirement run outside it. Writer I/O still serializes under its own monitor. Network readers can use the last committed packet while an edit is pending. Removes disk wait from that reader lock path; writer latency itself is unchanged. |
| 2 / P1 / High data-loss branch | Old `loadSettings`: dictionary parse failure was treated like a missing file and called saveSettings. A corrupt/non-dictionary/unreadable present source could be overwritten by current defaults/state if writing succeeded. | Distinguish confirmed absence from present/unreadable metadata. A present invalid source returns NO and is left intact. Metadata errors also stop fallback to a later alias; only confirmed no-such-file errors allow fallback/first-run creation. Fixture compares corrupt source bytes before/after. Existing path names/order, including the duplicate primary alias, are preserved. |
| 3 / P1 / Medium / proven partial-state opportunity | Old edits mutated status/list before saving, then rebuilt them again for rollback. Reentrant same-thread code could observe the tentative values; load could update the master flag before failing on another field. | Build a detached complete candidate, save it, then publish the pointer once. Failed/throwing save leaves the previous packet unchanged. Readers no longer observe partially rebuilt arrays or tentative edits. An operation already holding an old packet may finish with that packet, including during a successful concurrent edit. |
| 4 / P1 / Medium / malformed-source risk | Old status dictionaries were copied without checking value types; `boolValue` on an array/dictionary can throw, including during the load catch's rebuild. Invalid master scalars could throw after partial mutation. | Validate string keys and NSNumber/NSString scalar values before publication. Materialize status values as booleans, detach strings, and compile both exact/suffix representations together. Malformed complete records are rejected while retaining the whole previous packet; this includes its previous enabled bit. No partial application of a false master flag from a malformed record is promised. |
| 5 / P1 / Medium / master-toggle consistency | `SecurityTabViewController.m`, `domainBlockingToggleChanged:` formerly published an in-memory master value before saving, then restored it on failure. Separating readers from writer I/O requires an explicit pending-versus-committed contract. | New `setEnabledAndSave:` performs the complete save-before-publication operation. UI failure still restores the switch and returns before notification/feedback; success sends the same Darwin topic. Only the three old setter/save/rollback lines in this handler are replaced. |
| 6 / P1 / Medium / potential mutable alias race | Public `blockedDomains` exposed the actual mutable array; direct mutation could race enumeration and bypass future compiled matcher invalidation. No production caller outside the model was found using this property. | Keep the property selectors and replacement setter, detach assigned lists and return a mutable copy. Mutating a returned array intentionally no longer changes policy. Invalid replacements are ignored; later management edits rebuild from custom statuses as before. This is an explicit compatibility narrowing, not an assertion that arbitrary external mutable-array callers are supported. |
| 7 / P1 / Medium / potential reentry/once failure | String validation, file methods and singleton initialization can call arbitrary Objective-C code. A nested edit during a pending save could recursively overwrite state; same-thread sharedSettings reentry could wait on its own once token. | Per-instance writer admission under the recursive monitor rejects nested load/save/edit/compatibility setters. Thread-local singleton admission precedes once; nested creation returns nil, and setup exceptions are caught inside once. Matcher admission precedes foreign input validation and restores on all exits. Other threads still wait normally for singleton initialization. |
| 8 / P1 / Medium / potential exceptional lifetime | New/old paths hold dictionaries, policy objects, paths and inputs through Foundation callbacks; plain ARC does not automatically clean every strong local during Objective-C unwinding. | Named roots/finally throughout preparation/edit/read chains. Retired packets use precise lifetime and clear after unlock, preventing early destruction in the publication critical section. Selected weak input/token/packet tests check pool-drained ownership under plain ARC and ARC exception cleanup. No timer, observer or persistent file handle is added. |
| 9 / P2 / Medium CPU/allocation cost / proven repeated work | Old `isDomainBlocked:` lowercased and trimmed every enabled rule, then created its dot-prefixed suffix on each request, even though rules normally did not change. | Compile an exact NSSet and suffix array when policy changes; normalize the query once. Keep Foundation `hasSuffix:` for suffix decisions, rather than substitute a label parser with potentially different unusual/Unicode behavior. Removes per-rule normalization/suffix allocation from the hot read. Suffix matching is still O(rule count); improvement depends on rule count/traffic. |
| 10 / P2 / Low / unconditional diagnostics | Old singleton/init/rebuild printed full domain/status lists using NSLog, including during reload/edit/rollback. | Remove temporary debug/list dumps and optional error NSLog calls from this model; APIs still return failures and UI reports them. Reduces startup/update formatting and log I/O and avoids these plaintext list dumps. This does not remove unrelated logging or establish complete app privacy. |

## Preserved behavior and explicit failure-path differences

Matching still means exact or dot-boundary suffix after lowercasing and removing
exactly one trailing dot. There is no new URL parsing, whitespace trimming,
leading-www removal, public-suffix policy, IDNA conversion, IP classification or
hostname syntax restriction in the model. The UI's existing input cleanup stays
unchanged. Empty/non-string queries return NO. Odd but previously accepted rule
strings, consecutive dots and Unicode variants are compared against the original
Foundation matcher in the fixture, rather than explained by a Python substitute.

The two Apple defaults, default master YES, all three settings keys and existing
paths stay. A present custom dictionary, including an empty one, takes precedence
over the legacy blockedDomains array. When customDomains is absent, valid legacy
strings merge into the current default/status map as before. Legacy migration
still writes the modern representation, but now publishes only after save
success. Failed migration keeps old memory and source; it does not acknowledge a
partially adopted candidate. First-run confirmed absence still writes defaults;
this batch does not retire read-triggered initialization/migration.

`addDomain` on an enabled entry and `removeDomain` on a missing/disabled entry
remain successful no-ops without a write. Explicit toggle of an absent entry,
delete of a missing custom entry, and replace with an existing raw key still
return NO. Raw keys retain their spelling/case, so differently spelled keys can
coexist in UI even when their normalized matching meaning is identical. Replace
preserves the old enabled value; disabling does not delete the custom entry.
UI rows are still sorted using NSString compare:. Accepted scalar status values
are persisted as boolean values in the next successful save; their prior string
or nonzero-number spelling is not retained, while boolValue semantics are.

The compatibility `isEnabled` setter remains an in-memory operation and can
publish without saving. All repository persisted master changes now use the new
API. It is not an interprocess transaction or a universal persistence guarantee.
There is no automatic retry after once initialization failure, no new queue or
polling, and no extra notification. The existing domain reload callback still
runs load synchronously and ignores NO; a rejected load retains the previous
complete policy until a later accepted reload. A first initialization that cannot
load retains the same in-memory defaults as before.

## Performance, concurrency and remaining limits

The read critical section only captures an owned pointer. Publication only swaps
owned pointers while retaining the previous object for destruction after unlock.
No file, string normalization, set lookup, collection copy, logging or callbacks
run there. Reads are thread-safe, not lock-free. The singleton's initial load
remains synchronous and may wait for initialization; this batch does not put an
asynchronous cold start back into the RootHide constructor path.

Normal reads still allocate/obtain a normalized host, do one set lookup and scan
cached suffix strings. Candidate building costs O(rule count), allocates complete
immutable collections and adds O(rule count) cached strings/references. A master
toggle currently rebuilds these collections too. Small lists may see negligible
overall savings; large lists/frequent decisions have more removed work. No trie,
global decision cache, queue or preference cache is added without a freshness
contract and profiling. Callers must not concurrently mutate inputs while they
are being detached; hostile subclasses and unsafe pointers are not a new API
contract.

Writer serialization is per instance. Different instances/processes can still
read and overwrite the same file without a shared revision/CAS, lease or source
transaction. Metadata, plist reading and rename are not one descriptor-pinned
operation; source replacement/TOCTOU and uncertain write outcomes remain. A
normal atomic write YES is used as the existing success signal; there is no
fsync/readback/durability acknowledgment or rollback after a write that took
effect but reported failure. The read-side packet is coherent, not the entire
cross-process filesystem workflow.

UI saves, directory preparation and reload remain synchronous and can cause
moderate/high storage latency on their calling thread. Slow permission/disk work
can still stall a writer or a Darwin callback; it now does not hold the matcher
capture lock. Notifications can be lost/coalesce and no new fallback refresh is
introduced. Other injected processes see the new policy after their own accepted
reload, not at the UI's publication instant. In-flight old packets may continue
to block or allow according to their captured decision. No already-created task
is retroactively cancelled by this model change.

## Verification and acceptance

`scripts/test_domain_settings.py` is enrolled in release gates and macOS CI.
It extracts the whole production model, replacing only settings path constants
and the file-manager entry point with controlled providers. The Foundation-only
fixture uses unique real temporary plist files; no production path is accessed.
It preserves the duplicate primary alias in its path provider.

`PXDomainSettingsTests.m` covers the old/new Foundation matcher oracle, mutable
inputs/detached getter, OFF behavior, defaults, custom/legacy precedence, scalar
and malformed/corrupt sources, migration failure, alternate path, permission and
metadata faults. It injects false and throwing writes into all six persisted edit
routes, checks packet identity/source bytes and success semantics, and exercises
readers while the writer monitor is deliberately held. Concurrent independent
writers must retain all edits; concurrent readers must retain stable decisions.
Reentrant input/singleton/writer probes and selected weak input/token/retired
packet checks run after the relevant pool drains. Permission rejection uses a
facade because real permission behavior depends on runner privileges.

The matrix has four compile/run pairs: rootful/RootHide x plain ARC/ARC exception
cleanup, at -O0 with Foundation. Windows recipe capture verifies those commands,
exact path substitutions and CHECK arity only; no native compiler/binary ran.
Both defines test common model portability, not RootHide injection or path
relocation. Twenty negative source controls are rejected. The old security gate
now checks six writer admissions plus captured-reader publication, replacing its
requirement that readers take the same I/O monitor.

Local regression: **74/75 Python suites, 4/4 Node suites**, with the unchanged
Keychain retirement Git Bash mkdir `/c/Users/ADMIN` permission failure (4 failures,
1 error, 1 skip). Source hardening and RootHide build/package gates pass; after
final fixture refinements the new source suite is rerun. Protected file and byte
comparisons preserve all hook/transport/task/constructor/bootstrap/coordinator/
source-writer code, package metadata, Makefile, DomainManagement UI and the rest
of SecurityTabViewController. RootHide synchronous cold priming and ElleKit
dependency stay unchanged.

macOS CI still needs to compile/run these fixtures and build both real package
schemes. Device acceptance must cover master/custom edits, failed saves, live
reload, pending network decisions and performance under a large list, including
RootHide iOS 15.8.8/AIDA64 and rootful. Full domain transport coverage, source
authority/durability, movement, profiling and release acceptance remain open.
H5S-partial remains unchanged.
