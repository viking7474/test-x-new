# Patch 4C.2H5K — Verified single-app scope addition

2026-10-30: user reports H5J build pass. Shared rootful/RootHide manager code and two
basic dashboard add paths change. No native Foundation/Theos/UIKit/device validation
can run on the local Windows host.

## Findings and production paths

- **High, confirmed correctness defect:** addApplicationToScope: adopted a rebuilt
  app record into memory before full saveSettings. A source write failure left an
  uncommitted added/enabled app in memory. Full settings/scope saving could flush
  stale unrelated flags or scope records while adding a single ID.
- **High, confirmed exception path:** optional build fallback checked whether proxy
  responds to valueForKey:, which does not prove bundleVersion/CFBundleVersion exists.
  Unknown KVC keys can raise. Private factory/name/version/getter availability and
  returned types were also assumed, risking unsafe metadata in the UI/source.
- **Medium, confirmed receipt gap:** installed-app picker and text-entry add button
  checked shared lastError after a void call. A stale error from an earlier request
  or a publication successor could hide this call's acknowledged source success.

Reproduce with a physical scope write fault after metadata preparation: old memory
already contained the new record despite old/absent canonical scope. A proxy with
no build getter and throwing KVC demonstrates the exception branch. Source flags
in a stale manager also flushed during the old full save. H5J fixed removal only.

## Implementation and preserved policy

The void entry delegates to public addApplicationToScopeAndPersist:error:. Validate
nonempty NSString IDs, copy exact case, and retain the existing exact self-app block
and error codes 3001/3003. Initial standalone read validates canonical scope and rejects
nested uncommitted staging before LaunchServices callbacks or preferences mkdir.

Metadata lookup runs outside the source gate. Dynamic class/factory/getter guards
and typed string copies retain existing defaults: unresolved app name is its ID,
version Helper/Extension, build Unknown, installed/enabled YES. For a proxy with nil
version, version remains Unknown; an available but nil build getter still yields
Unknown without an extra KVC fallback. If the getter is absent, the same two optional
KVC keys are tried in order. Only these optional KVC invocations catch exceptions;
wrong types are treated as unavailable. Other factory/getter/publication exception
propagation is not broadly changed.

Final standalone admission rereads current scope and upserts only the requested ID.
Other source apps, top-level metadata and settings bytes survive provider-time source
changes. A fully matching canonical target record is a no-write/no-topic observation.
After success only that local entry is adopted, with the same cache policy as H5I/J.
No-op can restore missing local membership without rewriting source; failure preserves
memory/cache/topic and source recovery handles original bytes or absence.

**Target-record compatibility is intentional:** like the old add operation, reconstruct
exactly the standard name/version/build/installed/enabled/bundleID/originalBundleID
record for this ID. Prior target custom fields and extensionPattern are removed.
Preserving them would change existing extension policy; this patch does not do so.
Other apps' dirty local records are untouched, and absent canonical scope does not
resurrect unrelated stale memory members. Explicit add remains an upsert at its final
admission, not a last-started-intent or generation/ABA CAS.

Preferences parent creation retains the legacy directory/ownership policy. It occurs
after initial admission/metadata but before final staging, outside byte rollback.
Native fixture preference roots already exist; missing-parent ownership requires
device/integration validation. No global settings file is created as an implicit side
effect of adding an app; explicit settings writers retain their own policy.

Two basic UI callers use a BOOL helper with local NSError. Failure stops input clear,
list refresh/picker dismissal and success feedback. Success uses this call's receipt,
not shared lastError. The existing manager instance and error presenter remain.
No confirmation or injection/filter policy is added. Extension expansion loops,
redundant saves/filter rebuilds and their batch success handling are separate work.

## Performance, lifecycle and limits

Changed add stages one scope file rather than settings plus scope. Healthy no-op
stages nothing after required recovery. It still performs two source admissions and
metadata lookup; each gate retains its one-second contention budget. This is a cold,
synchronous UI action with expected low/moderate work dependent on scope size; no
benchmark or universal latency improvement is claimed. No queue, timer, observer,
polling or hook is added. Source blocks and the metadata helper are synchronous.

Source/cache/UI/notification do not share one atomic transaction. Source gates end
before external metadata callbacks and publication; candidate adoption precedes topic
with no later overwrite. Publication successors retain their newer state/error.
Concurrent local dictionary access, post-unlock changes, directory durability,
defaults authority and full batch workflow ordering remain separate.

## Verification

The group recipe extracts 68 production methods plus the exact addition UI helper.
A unique optional-proxy collaborator exercises missing class/factory/name/version/
build, nil values, malformed name/version, primary and both KVC exceptions. KVC call
counts distinguish getter-present nil policy from fallback. Other scenarios cover
legacy target reset/no wildcard retention, concurrent other-member merge, settings/
root/dirty-memory preservation, canonical no-op and local adoption, physical faults
with present/absent source and void retry, no resurrection of stale other apps,
invalid/self input, nested poisoning before lookup, corrupt source teardown,
mutable caller ID, publication removal successor and basic UI receipt/retry.

Source guards verify both UIKit callers gate their existing clear/refresh/dismiss
steps on the helper result. Foundation adapters execute exact helper code against
real SourceStore; UIKit presentation and LaunchServices behavior remain device checks.
The macOS recipe compiles/runs both scheme defines; extraction alone is not native
compilation/execution.

## Local validation

Windows regression: **62/63 Python suites and 4/4 Node suites pass**. The remaining
keychain bridge retirement suite retains the known Git Bash `mkdir /c/Users/ADMIN:
Permission denied` failure (4 failures, 1 error, 1 skip in 10 tests). Release source
hardening, RootHide metadata/negative controls 6/6, exact group/profile fragment
generation, CHECK macro arity and git diff whitespace checks pass.

Eight in-memory negative controls restore the blind void save, early memory adoption,
nested staging, mutable input key, uncaught optional KVC, old target record retention,
shared-error receipt or premature UI input clear. All are rejected by source contracts;
the KVC guard was also checked using a syntactically valid unguarded-read replacement.
These controls do not modify production files. Native Foundation/Theos builds for
both schemes, real metadata APIs, UIKit presentation and physical injection remain
for macOS CI/device validation. Full Patch 4 writer rollout remains partial.
