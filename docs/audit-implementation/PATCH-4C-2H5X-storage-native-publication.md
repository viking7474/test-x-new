# Patch 4C.2H5X — Storage native publication, queue and buffer boundaries

2026-10-31: user confirms H5W build passes and authorizes continued implementation.
Changes are shared by rootful and RootHide StorageHooks. Constructor scope/bootstrap
prefix remains identical to HEAD and initial refresh remains synchronous, before
observer registration/native provider installation. No new source writer or
packaging dependency; source enrollment stays H5S-partial.

## Findings and changes

**Medium / P1 — confirmed torn tuple interleaving.**
PXStorageCopyNativeSnapshot checked the refresh flag once, then loaded total/free
separately. A refresh could begin and complete between those loads: the reader
could accept old total and new free after the flag had returned to false. Each
field was atomic, but the tuple was not. Overlapping direct publishers could
also independently set/clear the shared refresh flag.

Add an exclusive single-attempt refresh claim and a uint64 odd/even revision.
The claimed publisher marks the revision odd before computation, stores the
scalars/allowed flag, advances to even and clears refresh ownership. Publisher
and snapshot-copy atomics are sequentially consistent so the version and payload
participate in one C ordering argument. The reader makes one bounded pass,
rejecting active/odd/changed revisions, denied state or free > total, and writes
caller outputs only after validating the whole observed tuple. It never retries,
waits, locks, allocates or calls Foundation. Counter wrap is unsigned; one read
cannot meaningfully span 2^63 complete publications, the theoretical ABA limit.

**Medium / P1 — exception/lifetime state.**
Refresh previously set its in-progress flag before Foundation/scope work without
finally cleanup. An exception outside the inner conversion catch could escape the
queue or leave refresh stuck. Scope/metadata exceptions now publish disabled state
and finally end the claimed refresh. An overlapping producer fails its claim and
does not clear the active owner's state. Normal producers are the inline ctor
followed by the existing serial refresh queue; there is no new retry timer for
external callers that bypass that sequencing.

**Medium / P2 — notification burst work.**
Every Darwin event enqueued its own Foundation-backed recomputation. Keep the
existing immediate storage/scope invalidations, but admit only one pending queue
block. Clear the pending slot before capture/compute so events during a running
refresh can schedule one follow-up. This bounds pending work, not the total number
of computations across arbitrarily spaced events. It uses the same serial queue,
does not defer initial constructor priming and adds no delay/debounce interval.
Each queued recomputation has an explicit autorelease pool to bound temporary
Foundation object lifetimes to that work item; no pool is added to mount readers.

**Medium / P1 — unchecked byte casts and scalar types.**
The active getStorageValuesForApp path still cast custom double capacities and
free-space products without range checks; NSNumber fields also received length.
Admit strings/numbers, check finite positive total and the exclusive 2^64 scaled
limit, and bound the free-space conversion. Valid numeric plist scalars now retain
their configured capacity rather than throwing into a default. Existing 64/128
marketing/binary/Settings special cases, custom scaling and free ratio are kept.

For a present unsupported/non-finite/unrepresentable total, use the existing
exception fallback (128 marketing GB / 38 marketing GB), avoiding a new path to
physical-capacity disclosure when the feature was already enabled. Missing/empty/
nonpositive total retains its old miss behavior. Unsupported free objects retain
the exception fallback; missing/empty/out-of-range/non-finite numeric free values
remain zero. Nil getStorageValues (feature off) remains a miss. No parser or
global primary/secondary toggle policy is changed.

**Medium / P1 — confirmed zero-free result leak.**
PXStorageModifyStatfsWithValues only replaced f_bfree/f_bavail when fake free > 0.
A valid full fake disk therefore retained physical free-space counters. For a
valid total/free pair always set both counters, including zero. Invalid/absent
tuples leave the statfs fields unchanged. Default block size and H5W overflow-safe
block ceiling remain in use.

**High potential memory risk / P1 — conditional oversized mount result.**
Both active getfsstat providers iterated the reported result without checking how
many complete records fit bufsize. Given an oversized count (for example from
another hook/provider), this could read/write outside the caller buffer. No claim
is made that a normal kernel response violates its contract. Clamp iteration to
min(positive result, positive bufsize / sizeof entry); zero/partial/invalid buffers
do not iterate. Keep the original result/errno and matching mount policy. Apply
the same bound to the retained legacy replacement functions. No struct ABI or
invented statfs64 layout is introduced.

## Validation

The artifact preparation CI recipe now additionally compiles
PXStorageNativeSnapshotTests.m for rootful and RootHide. It extracts twelve exact
production functions across publication/copy, queue, conversion, buffer and
metadata helpers, plus their actual atomic globals/constants. Controlled bundle,
scope and storage-value adapters replace only collaborators; no Logos/private
injection is claimed by this host fixture.

An atomic-load adapter in the test translation unit deterministically publishes
between the two payload loads, verifying rejection without partial output. The
production body is unchanged and contains no test callback. Additional cases
cover stable/disabled/zero-free/wrapped revisions, rejected concurrent publisher
claim, concurrent accepted tuple invariants, normal and invalid numeric values,
technical/Settings formatting, zero-free statfs counters, buffer capacities and
exception cleanup. A blocked queue followed by 1000 schedule attempts must compute
once; 1000 events inside computation must produce one follow-up; a later event
must still run. These are fixture assertions awaiting native execution locally.

Local Windows source regression: 62/63 Python and 4/4 Node, source hardening,
RootHide metadata/static checks, mount Foundation-free guards, exact native
fragment/helper ordering, CHECK macro arity and 12 in-memory negative controls.
The known bridge-retirement Git Bash mkdir permission issue remains the one
Python gate failure. No local Foundation/Theos/device execution is available;
H5X needs the next macOS CI run and real-device compatibility/performance checks.

## Performance and remaining boundaries

The native read adds version/closing-state atomic loads with no explicit loop,
mutex or Foundation/IPC/I/O calls. This is an expected low CPU cost required for
correctness; hot-path latency is not benchmarked. Publication uses two revision
RMWs off the native read path. Coalescing removes redundant block allocations and
metadata/file work for pending bursts; impact depends on actual event frequency.
Immediate invalidation still runs per event. Buffer clamping is constant C work.

A declined copy leaves original syscall results untouched, including during
refresh as before. The packet protocol guarantees coherence of computed C values,
not an atomic multi-file source generation or newest-scope publication CAS.
Rootful wall-clock TTL/shallow object cache and delayed notification authority
remain separate. ObjC paths can still compute from file/provider state and are
not all protected by the native tuple protocol. Exceptions thrown by invalid
memory/signals are not covered by Objective-C exception cleanup.

Darwin observer topics, filtering, hooks, scope rules, original syscall invocation,
RootHide captured-view authority and H5V/H5W StorageManager paths are unchanged.
Do not describe this as complete global concurrency, privacy or audit closure;
full Patch 4 remains partial.
