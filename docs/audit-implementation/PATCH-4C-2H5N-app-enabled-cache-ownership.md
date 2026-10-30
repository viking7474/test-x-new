# Patch 4C.2H5N — Per-manager app-enabled cache and reload state

2026-10-30: user reports H5M build pass. Changes apply to the shared IdentifierManager
implementation used by both schemes. The pre-existing local workflow edit changing
the RootHide runner to macos-15 is left untouched by this phase.

## Findings and priority

Production location: common/IdentifierManager.m, private reader state, -init and
-isApplicationEnabled:.

**Medium, confirmed multi-instance logic defect (P1)** — isApplicationEnabled: used
a file-static enabled cache keyed only by bundle ID, although scopedApps belongs to
each IdentifierManager instance. Warm the same key in two instances with opposite
scope flags: the second could return the first instance's cached value. Existing
writer invalidations also cleared that shared cache across all instances. Source
inspection proves the ownership mismatch; the application commonly uses sharedManager,
so the frequency of distinct live production instances has not been measured. This
is not evidence of an observed single-instance/device regression.

**Medium, confirmed multi-instance reload suppression (P1)** — the same reader kept
a method-static lastReloadTime. A first miss on one manager could prevent another
manager with an empty/stale local map from loading canonical scope for 60 seconds.
The second manager could then cache its false result for 30 seconds. Last-app logging
state was shared similarly. Reproduce with two empty managers and a canonical enabled
member, calling each reader in turn.

**Medium, potential caller-input crash (P1)** — the manager/rootful reader lacked an
input guard before subscripting and later inserting into a mutable dictionary. nil
can reach a nil-key write; a wrong object type can reach string selectors. The public
method accepts NSString pointers without a runtime precondition. The new guard returns
NO for nil, empty or non-string input before cache/log/reload/snapshot work. This does
not claim that an existing production caller currently passes invalid IDs.

## Implementation and behavior

Private properties own the mutable enabled cache, last reload time, last logged bundle
ID and last log time on each manager. The production constructor allocates its own
cache. All existing _appEnabledCache reads and invalidations now refer to that ivar;
no file-static cache or reader dispatch_once initializer remains. Automatic ARC object
lifetime releases the dictionary and retained logging key with the manager.

Exact lookup, self-app exclusion, case-insensitive fallback, enabled scalar conventions,
30-second cache TTL, 60-second reload interval and last-app/30-second logging policy
are preserved. The reload time is still advanced after a failed reload, matching H5M;
this prevents repeated I/O for different misses on the same instance. Each independent
instance now gets its own reload budget, which can increase aggregate reload work if
many instances are used. It is a correctness tradeoff, not a claimed I/O speedup.

RootHide injected readers still return from runtime snapshot logic before accessing
owner cache, logging/reload state or file paths. Exact/fallback/malformed snapshot
behavior is retained. Valid input still opens the existing runtime read operation;
invalid input exits earlier. Bootstrap scheduling, cold priming, hooks, process role
policy, package dependency and filter expansion are unchanged.

A source write does not synchronize every manager's scopedApps. Another instance
continues to represent its own view until its existing load/reload policy refreshes
it. Its cache is no longer silently interpreted as the writer's view. Cross-instance
publication ordering and same-instance thread safety remain separate problems.

## Performance, memory and remaining risks

Steady cached lookup remains O(1); uncached case fallback remains O(n) with its existing
string allocations. Removing a dispatch_once fast-path check is negligible; no timing
benchmark is claimed. Each manager adds one empty dictionary plus three state fields
and may retain one copied logging key. This includes a small allocation at construction
in injected hosts, though their reader bypasses the dictionary. No timer, queue, lock
or new callback/retain cycle is introduced by production changes.

Mutable scope/cache access and logging/throttle fields are still unsynchronized on a
single instance. This phase is ownership isolation, not a thread-safety claim. The
legacy scope read is still uncoordinated in rootful injected hosts; cache TTL/reload
clock behavior, unbounded distinct-key growth, raw memory mutation and other readers'
cache/schema issues remain outside this patch. Full Patch 4 remains partial.

## Validation

The group recipe now extracts **72 exact production methods**, plus the exact
IdentifierManager constructor and four reader-state property declarations. The fixture
uses those declarations rather than an independently declared cache ivar. A separate
small class compiles the real constructor to verify initialization and release. The
existing collaborator-heavy group fixture retains its test-specific initial flags.
The recipe links production PXRuntimeSnapshotReader.m for PXRuntimeReadBool and the
real immutable snapshot initializer; no bool-helper stub is substituted.

New native fixtures cover opposite same-key decisions in two managers, invalid input,
fresh/expired cache policy, case/scalar compatibility, independent first reloads,
per-instance throttling after success/failure, source-write owner invalidation, sibling
explicit reload and cache lifetime. RootHide fixtures seed a real snapshot with values
opposite to memory/cache and verify snapshot authority without source calls or manager
state changes. They exercise the extracted method; runtime-scope macros and transport
remain fixture collaborators, so this is not proof of real device injection/bootstrap.

Windows regression: **62/63 Python suites and 4/4 Node suites pass**. The remaining
keychain bridge retirement suite retains the known Git Bash mkdir permission failure
at /c/Users/ADMIN (4 failures, 1 error, 1 skip in 10 tests). Release source hardening
and RootHide package metadata/negative controls 6/6 pass. Exact group/profile fragment
extraction, the 72-method count, separate constructor and four state declarations,
C-helper order, CHECK macro arity and git diff whitespace checks pass.

Ten in-memory negative controls reject reintroduced global cache state, omitted cache
initialization, missing input guard, shared reload/log clocks, changed TTL, retry after
every failed reload, cache access before the injected fast return, missing real
snapshot/bool link and omitted exact-constructor fixture. Production files are not
edited by these controls. Final extraction review excludes the marker comment tail
from property declarations and asserts a property-only state fragment.

Native Foundation/Theos builds for both schemes and real device behavior remain
pending macOS CI/device testing; local source checks are not native runtime proof.
