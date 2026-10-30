# Patch 4C.2H5P — Reset scope replacement preparation

2026-10-30: user reports H5O build pass. This phase changes the shared
IdentifierManager implementation and its existing native fixtures for both schemes.
Local Windows validation cannot run Foundation/Theos builds or device injection.

## Findings and production flow

Location: common/IdentifierManager.m, replaceApplicationScopeWithBundleIDs: and
persistScopedApps:adopt:error:. Production caller: TLinkIOSViewController.m,
syncHookScopeToResetAppIDs:waitingForDaemon:, reached by Reset scope preflight,
selection changes and deferred startup scope repair. The caller requires replacement
YES before writing injection filters. This call chain exists in production source; there is no evidence that a private API
failure has occurred on a user's device.

**High, potential compatibility crash (P1):** missing-member preparation directly
sent applicationProxyForIdentifier:, localizedName, shortVersionString and
bundleVersion to private runtime classes/objects without availability checks. Private
factory/getter exceptions escaped this BOOL API. Unexpected metadata types could also
enter records. A missing selector or throwing provider could abort the action; the
deferred background repair path has no local exception handler around this call.
H5K/H5L protected additive scope insertion; full replacement still used its older path.

**Medium, confirmed nested admission ordering defect (P1):** standalone source
rejection happened only in the final persistence helper. A replacement requested
inside an outer uncommitted transaction could perform private metadata work first,
while that outer source gate was still active. A controlled provider demonstrates the
unnecessary callback path; no production deadlock or frequency is claimed.

**Medium, demonstrated callback-dependent metadata loss (P1):** the replacement loop
read live retained records one ID at a time, interleaved with private callbacks for
missing records. A callback during an earlier missing member can mutate/remove a later
requested member, losing its existing custom metadata or changing the request's basis.
The fixture demonstrates this interleaving. Actual LaunchServices reentry frequency
is unknown; full replacement is intentionally allowed to supersede intervening scope
changes, so this patch does not introduce a source CAS policy.

**Medium, potential post-commit malformed-root exception:** the persistence helper
used isEqualToDictionary: on old local scope after source acknowledgement. An explicit
empty replacement over a non-dictionary local root could commit then throw before
adoption. Generic isEqual: keeps valid dictionary equality and permits safe empty-map
adoption. Hardened loading already prevents malformed source roots from becoming
normal manager state; this is defensive recovery for an unexpected local value.

## Implementation and error handling

Normalize/copy/filter/deduplicate IDs using the existing exact-case policy. Take one
local scope reference and inspect only requested retained members. A selected record
must be a dictionary; a malformed root with selected IDs returns 6040. Unrequested
invalid members are dropped normally, and an empty request retains the clear policy.

Apply the fields owned by replacement intent (enabled=YES, bundleID and
originalBundleID) before validating/detaching retained metadata. This preserves the
old ability to repair those overwritten fields. Freeze only retained requested
metadata with PXDetachRuntimeGeneration and the shared schema validator before any
private framework call. Unknown retained fields and nested plist values are preserved;
non-plist retained data fails before private lookup rather than at final persistence.

An initial standalone source admission reads the current root without staging writes.
Nested use is rejected and poisons ignored parent staging before class/factory work.
Undecodable source keeps the existing 4006 error. A decodable dictionary with malformed
old scope schema is still repairable by full replacement; do not reuse additive's
stricter current-record validator at this admission point.

After admission releases, prepare missing members inside a bounded try/catch region.
Resolve the private class lazily once per invocation, only when a member needs metadata.
Check factory/getter availability, accept copied NSString values and use original
fallback strings: name=ID, version=Unknown or Helper/Extension, build=Unknown. Unlike
additive insertion, replacement historically had no KVC build fallback; none is added.
Factory/getter preparation exceptions return NO with error 6048 before new source
staging, adoption or notification. Optional API absence uses fallback metadata.

The catch ends before calling the existing persistence helper. Its canonical no-op,
source failure/rollback, final deep detachment, owned mutable adoption, cache
invalidation and publication receipts remain authoritative. Publication exceptions
are not converted into preparation failures after a source commit. The UI still
stops before filter sync when replacement returns NO. No new API or UI flow is added.

## Scope, lifecycle and compatibility limits

Whole-map replacement, nil/empty clear behavior, filtering of the three self aliases,
invalid-member skipping, deduplication and metadata preservation are unchanged. This
is not an additive merge. The final helper rereads canonical root under its existing
standalone gate; a provider's intervening source change is not protected from a later
explicit replacement. Frozen retained metadata expresses the original request basis,
not global last-writer or cross-instance manager ordering.

There are no new timers, observers, queues or locks in production. Blocks execute
synchronously, and temporary detached records do not retain callbacks or managers.
Only the preparation region catches metadata exceptions. Arbitrary hostile NSObject
subclasses, concurrent mutation while capturing the local dictionary, shared manager
error races and same-instance thread safety remain outside this patch. Object-return
ABIs of the declared private selectors are still assumed; availability/value guards
do not prove safety if a future runtime changes a selector to a different ABI.

Owner admission may recover previous journals or initialize source control files;
there are no newly staged writes during metadata preparation. Do not describe failed
preparation as having no filesystem I/O. The caller's existing synchronized UI region
and filter wait remain unchanged; providers are outside the source gate, not a claim
that every caller lock has been released. RootHide injected reader authority, cold
bootstrap, hook surface, package dependencies and expansion/filter policy are unchanged.
This is not a claimed cause/fix for the earlier AIDA64 bootstrap regression.

## Performance

This is a cold scope-changing path. It adds an initial canonical root read and an
O(retained metadata size) immutable detachment before the existing final persistence
detachment/read. Expect low/moderate extra CPU, memory and I/O depending on scope size;
no latency benchmark or speedup is claimed. Avoiding lookups for retained entries and
using one lazy class lookup limit new preparation overhead. The initial read still
uses existing source deadlines. No polling interval, source lock deadline or injection
filter wait has changed. Contention can add another bounded admission wait; this is
not a latency optimization. Full Patch 4 remains partial.

## Validation

The native group recipe retains 75 exact production methods plus the exact constructor,
state declarations and existing helpers. New fixtures cover nine missing/bad/nil API
metadata cases with no KVC calls, retained-only lookup avoidance, nested admission,
late factory and getter exceptions, provider work outside the gate, one class lookup,
frozen retained nested metadata, overwritten-field repair, ignored dropped malformed
members, invalid retained plist data, decodable canonical schema repair, corrupt-source
failure/teardown and safe empty replacement over a malformed local root. H5G still
covers physical final-write faults/retry, no-op/cache/mode, post-marker acknowledgement
and publication successors. Native collaborators do not establish actual iOS private
selector availability or device runtime behavior.

Windows regression: **62/63 Python suites and 4/4 Node suites pass**. The remaining
keychain bridge retirement suite retains the known Git Bash mkdir permission failure
at /c/Users/ADMIN (4 failures, 1 error, 1 skip in 10 tests). Release source hardening,
exact 75-method group/constructor/state/profile fragments, C-helper definition order,
CHECK macro arity and git diff whitespace checks pass.

The separate RootHide static gate initially failed because it pinned the old typed
proxy.bundleVersion call and prohibited respondsToSelector entirely. That historical
contract protected a forward-declared private receiver compiler issue. It now requires
guarded id receivers for optional selectors and preserves the no-performSelector,
no-KVC policy. RootHide metadata/negative controls 6/6 and the revised static gate pass.
Three extra in-memory negatives reject a typed private receiver, an unguarded build
getter and newly introduced KVC fallback. This replaces the contract with a defensive
one rather than removing the compatibility check.

Thirteen in-memory replacement negatives reject missing retained detachment, live
metadata reads after callbacks, nested source admission, eager class resolution,
unguarded factory/getter calls, untyped names, KVC policy drift, stricter canonical
schema policy, loss of replacement-owned field repair, unsafe post-commit equality,
metadata exception propagation and a catch region extended across final publication.
No files are changed by negative controls. Targeted source/RootHide checks pass after
the gate update. Native Foundation/Theos builds and runtime tests for both schemes
remain pending macOS CI; local contracts are not native/device execution proof.
