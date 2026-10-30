# Patch 4C.2H5R — Full settings reload cache and source admission

2026-10-30: user reports H5Q build pass. This patch changes the shared rootful/RootHide
IdentifierManager implementation. Native Foundation/Theos/device runs are unavailable
on the local Windows host.

## Findings and evidence

Location: common/IdentifierManager.m, -loadSettings. Public declaration: TLinkIOS.h.
The source call site found is IdentifierManager.sharedManager initialization. No
recurring production reload loop is established; repeated invocation of the public
API is the reproducer, not a claimed cause of an observed device regression.

**Medium, confirmed stale-decision API bug (P1):** loadSettings adopted a fresh scope
without clearing spoofCache or appEnabledCache. Warm both decisions as NO, externally
commit an enabled scope, then call loadSettings: memory changes but both APIs can still
return the prior cached decision until expiry. H5M covered loadScopedApps; this full
loader remained independent. RootHide injected boolean getters already bypass those
manager caches, so do not claim that all injected apps suffer this path.

**Medium, confirmed nested admission mismatch (P1):** the recovery prelude used
PXPerformRuntimeSourceWrite, allowing it to join an outer active transaction. The later
capture rejected that uncommitted context and set manager.error, but ignoring the void
loader error still allowed the parent staging to commit. Other high-level reload APIs
already require standalone admission. The fixture now requires the attempted nested
load to poison ignored outer staging before capture, without memory/cache effects.
This is an intentional admission contract correction, not a reported device deadlock.

## Implementation and preserved behavior

Manager recovery uses PXPerformStandaloneRuntimeSourceWrite with the same empty body.
Nested calls fail before the capture loader; source error is kept in manager.error.
The prelude still runs only for the manager process. RootHide injected early return
and the runtime-operation macro preceding it are unchanged; no new bootstrap/read-scope
behavior is introduced.

After successful existing validation/default normalization and owned-record preparation,
compare the candidate scope with the resident map using generic isEqual:. Adopt settings
and scope in their existing order, then clear both decision caches only when scope
values differ. Cache effects do not precede either dictionary assignment. Identical
scope values and settings-only changes retain caches. Metadata-only scope differences
conservatively invalidate too, as in H5M; this is not an enabled-field-only projection.

Malformed source/capture/admission failures keep the old dictionary objects and caches.
Success retains the legacy shared-error policy: it does not clear an older manager.error,
and the void API does not provide an operation-local success receipt. Never infer a
successful reload merely from that shared property. Normalization, aliases, default
flags, secondary/security/defaults fallbacks, per-record mutability and logging remain
unchanged. The loader does not newly save files, repair preferences, publish or notify.
Owner recovery can still finish prior pending journal work or initialize controls;
this is not a claim of zero filesystem activity.

Rootful non-manager loading keeps its existing raw legacy reads and does not gain
source owner recovery/capture. Its successful scope adoption now invalidates its own
stale caches. Those raw reads remain uncoordinated and may mix/transiently observe
source versions; this patch does not enroll them in a transaction acknowledgement.
RootHide injected load still exits before owner source/cache/adoption work.

## Performance, lifetime and limits

Comparing full scope values adds O(scope graph size) CPU to a cold load, with no new
source read, serialization, timer, queue or lock. Relative cost is low/moderate depending
on scope size; no benchmark is available. Changed scope loses stale cache entries once;
matching values avoid unnecessary invalidation. Existing cache TTL, miss reload/log
throttles and per-app load logs are retained. A failed standalone load inside an outer
transaction fails promptly rather than making the later rejected capture attempt.

No new callback or retain cycle is introduced. Candidate dictionaries retain existing
H5F ownership rules. This does not synchronize mutable dictionaries, atomically publish
settings/scope to concurrent readers, order every manager instance, or validate cache
provenance after unsupported direct memory mutation. Secondary/defaults authority and
RootHide runtime publication remain separate. Full Patch 4 remains partial.

## Validation

The group recipe retains **75 exact production methods** plus existing constructor,
state and static helpers. New native fixtures warm actual decision readers, change
canonical scope in both enable/revoke directions and verify invalidation/readback;
matching and settings-only reloads
preserve caches. They also cover metadata-only changes, validation/capture failures,
nested staging poisoning before reads, RootHide early exit, rootful legacy owner-call
avoidance and absent-source defaults without materialization. Source bytes/marker,
object identity, caches, errors and notification/capture counters are checked where
applicable. Role/runtime-scope collaborators are not proof of real device injection.

Windows regression: **62/63 Python suites and 4/4 Node suites pass**. The remaining
keychain bridge retirement suite retains the known Git Bash mkdir permission failure
at /c/Users/ADMIN (4 failures, 1 error, 1 skip in 10 tests). Release source hardening,
RootHide metadata/negative controls 6/6/static build gate, exact group/constructor/state/
profile fragments, C-helper order, CHECK macro arity and git diff whitespace checks pass.

Eight in-memory controls reject regular nested recovery, missing either cache clear,
unconditional clearing, comparing settings instead of scope, early clearing before
failure checks, removed RootHide early exit and non-manager owner recovery. Production
files are not modified by negative controls. Final targeted contracts, extraction and
macro scans also pass with the explicit warm-positive revocation fixture. Native
builds/runtime checks for both
schemes and real device behavior remain pending macOS CI/device validation.
