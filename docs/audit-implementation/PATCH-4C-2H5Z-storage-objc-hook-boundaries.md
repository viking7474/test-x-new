# Patch 4C.2H5Z — Storage Objective-C hook boundaries

2026-10-31: user confirms H5Y build passes and authorizes continued implementation.
This batch covers six Objective-C hook bodies, their shared capacity helpers and
admission of three optional NSFileManager selectors. Production changes are in
TLinkIOSTweak/StorageHooks.x and apply to rootful and RootHide.

## Findings and changes

1. **Medium / P1, confirmed correctness bug — valid zero free space.** The
   attributes, NSURL single/batch and important/opportunistic compatibility
   hooks required freeBytes > 0, retaining the physical free-space value when
   the fake disk was full. Reproduce with a valid positive total and zero free
   bytes while the original reports a positive free value. Accept zero when
   total > 0 and free <= total; unavailable or inconsistent tuples retain the
   original output. Preserve the existing opportunistic double * 0.9 truncation
   policy. The total-only compatibility method keeps its existing total check.
   See capacity helpers near line 553 and hooks from line 864.

2. **Medium / P2, confirmed unnecessary work; frequency unmeasured — unrelated
   NSURL resource queries.** Both methods previously captured a runtime read
   operation and prepared storage values even for unrelated keys; batch also
   copied its dictionary. Classify supported keys before runtime capture and
   call original immediately for unrelated queries. For relevant queries,
   missing/nonnumeric output fields return before byte preparation; failed
   dictionary results also skip the spoof decision. Reproduce with NSURLNameKey
   or a batch without any capacity keys. Relative benefit is low on a warm
   lookup and potentially moderate when it avoids cold metadata/fallback work;
   no call-rate or device latency benchmark is claimed.

3. **Medium / P1, confirmed output-contract inconsistency — batch fabricated
   missing results.** Batch NSURL/attributes hooks unconditionally inserted
   capacity fields into any returned dictionary, including missing or nonnumeric
   entries. The single-key NSURL hook already required a numeric original.
   Replace only existing requested numeric capacity fields in batch; attributes
   similarly replace only existing numeric size/free fields. Reproduce with a
   partial dictionary containing a missing capacity key or NSNull. Preserve
   absent/nonnumeric/unrelated fields, original errors and partial dictionary
   shape. This deliberately changes malformed/unsupported/partial outputs;
   ordinary numeric successful outputs retain their policy. It does not infer
   success/failure from a possibly stale NSError pointer.

4. **High potential / P1, compatibility crash risk — unguarded optional
   selectors.** The three unsigned-long-long NSFileManager compatibility
   methods were in the default group without checking existence or signature.
   A missing original or incompatible runtime signature can make a hook unsafe;
   no particular iOS release or observed device crash is asserted. Move each
   method to its own group and admit independently after default %init using
   class_getInstanceMethod, four arguments, unsigned 64-bit Q result, object URL
   and object-pointer error ABI. Qualifiers and quoted object encodings are
   accepted; block objects, signed/object results, wrong arity, primitive URL and
   void error pointers are rejected. Fixed buffers are NUL-terminated. Checks
   occur once during admitted construction, with negligible expected runtime
   cost. The default attributes/NSURL hooks still initialize when an optional
   selector is absent. See helper near line 605 and ctor checks near line 1118.

5. **Low / P2, allocation opportunity — unconditional mutable copies.** Copy
   dictionaries lazily on the first changed supported numeric value. Equal or
   ineligible results retain original identity; original dictionaries are never
   mutated. Reproduce with a dictionary already reporting the fake values, or
   a partial result with no numeric capacity field. Expected relative saving is
   low per eligible query; relevant queries still classify keys and box values.
   Numeric equality uses isEqualToNumber, avoiding unsigned conversions that
   would mistakenly equate fractional/negative original values.

6. **Low / P2, confirmed dead/pass-through code.** Remove the URLForDirectory
   hook that only returned %orig and two local scope helpers without live
   callers. The active constructor/refresh still uses the shared scope
   predicate. Removing the pass-through hook saves a small interception cost;
   dead static helpers may already be stripped, so no runtime saving is claimed
   for them. The P3 static gate now checks the active centralized snapshot
   predicate instead of requiring a token from the removed helper.

## Behavior and remaining limits

Each executed path calls original exactly once. NSURL has two lexical %orig
sites for mutually exclusive branches. Original exceptions remain outside the
replacement catch and propagate. Replacement failures preserve original results;
BOOL and error forwarding remain intact. No new observer, timer, dispatch queue,
file write, preference read or logging is added.

The full cache region, native copy/refresh/scheduler bodies and constructor
prefix through the first %init are compared with HEAD and unchanged. Initial
synchronous preparation, process/scope admission, notification registration and
native provider registration therefore retain H5X/H5Y and the prior iOS
15.8.8/AIDA64 RootHide bootstrap fix. Only optional group admission follows the
existing default initialization. RootHide captured-view authority is preserved.

Structural ABI validation does not prove private selector semantics or guarantee
the absence of later swizzles. Selectors first added after this constructor are
not enrolled; no loader observer/polling is introduced. This fixture does not
exercise a real Logos/Substrate/ElleKit installation. Existing volume/path
policy, within-epoch cache ordering, missed notification TTL behavior, source
coherence and manager concurrency remain separate. Caller-owned Foundation
collections must remain stable during a query. No source writer is enrolled;
rollout remains H5S-partial and full Patch 4 remains partial.

## Validation

The existing artifact-preparation --native CI recipe now also builds and runs
PXStorageObjCHookTests.m for rootful and RootHide. It includes ten exact helper
bodies and six production method bodies with only %orig translated to explicit
fixture original-call adapters. Controlled collaborators count runtime capture,
scope decisions, byte reads and original calls. Cases cover unrelated keys,
zero/invalid/full-uint64 tuples, disabled scope, nil results/output pointers,
partial and nonnumeric fields, duplicate/unrequested keys, immutable-original
preservation, equal-result identity, provider/original exceptions, opportunistic
rounding and runtime class/method/ABI admission. Synthetic incompatible methods
are inspected as metadata and never invoked.

Local Windows validation: 62/63 Python gates and 4/4 Node gates, source hardening,
RootHide metadata negative controls 6/6/static gate, P3 matrix 81/81, four native
fragment generators, exact helpers/orig adapters, CHECK arity, helper dependency
order, Logos group balance and 12 in-memory negative controls pass. The remaining
Python failure is the known bridge-retirement Git Bash mkdir permission issue.
Final targeted checks are rerun after fail-fast ordering/fixture additions.
Foundation/Theos/package/device execution is unavailable locally; H5Z native
behavior and actual hook installation require macOS CI and device verification.
