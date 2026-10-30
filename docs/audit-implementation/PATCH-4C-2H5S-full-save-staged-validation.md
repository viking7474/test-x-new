# Patch 4C.2H5S — Full-save staged schema and storage alias consistency

2026-10-30: user reports H5R build pass. Shared rootful/RootHide IdentifierManager
changes; native Foundation/Theos and device execution remain unavailable locally.

## Findings and production flow

Location: common/IdentifierManager.m,
saveSettingsWithSourceCommitIdentifier:forIdentifier:beforeImage:error:.
It serves the generic saveSettings/saveSettingsWithError wrappers and the primary
phase of applyIdentifierEnabled:. The writer is in the production toggle path.

**Medium, confirmed write/read schema mismatch (P1):** full save wrapped a shallow copy
of scopedApps and staged it without the shared load validator. SourceStore validates
plist encodability/root dictionaries, not ScopedApps member schema. A local scope map
with a scalar app record or array enabled flag could therefore commit successfully,
publish and then be rejected by loadSettings with 6039. This is a code-level round-trip
failure; no existing production producer of such invalid memory or device incident
is asserted. The new fixture also tests malformed scope roots.

**Medium, confirmed repeated-evaluation inconsistency (P1):** canonical flags were
normalized from self.settings, then StorageSystem was read/evaluated again from live
memory for StorageSystemEnabled. Mutation between reads can split the two source
values. A bool-convertible object accepted by the existing sanitizer, returning NO
then YES, demonstrates the defect without a thread timing assumption. Ordinary
NSNumber/NSString values are stable; the frequency of concurrent/reentrant mutation
in production is not measured.

## Implementation

Keep the existing standalone source admission, canonical settings read and raw
before-image capture. Capture the admitted settings/scope root references once,
validate root types and copy the settings key map. Scope must remain a dictionary;
nil settings retains the prior empty-flags behavior, while nil scope still fails.

Stage scope first through SourceStore's existing encode/decode. This produces an
immutable in-memory packet. Read that staged packet back and run the shared schema
validator before invoking the sanitizer. Invalid scope returns NO and is never
physically committed; before-image/receipt outputs remain nil and caches/topics are
untouched. Root/type/schema failures retain the outer 4006 save-error contract.

Normalize from the copied settings key map once. Store that normalized map under
EnabledIdentifiers and use the same normalized StorageSystem value for its top-level
alias. If StorageSystem was absent, preserve the existing alias without creating or
removing it. An unsupported present scalar still fails rather than inventing NO.
The sanitizer's allowed-key/respondsToSelector policy is retained, including ignoring
unknown settings keys; this is not a stricter identifier-value policy.

Stage the merged settings record, reread/validate current staged scope once more,
then obtain the prospective receipt. The final check protects against an invalid
low-level nested replacement during normalization. Only acknowledged success promotes
receipt/before-image outputs and publishes the existing cache invalidation/topic.
Normalization exceptions remain inside SourceStore's existing exception boundary;
no broad catch is extended over post-commit publication.

Staging order changes from settings-then-scope to scope-then-settings. Physical file
write order is unchanged: commitTransaction sorts staged paths and performs one
journaled group commit after the body succeeds. The first staged scope is detached
before a converter can mutate live nested metadata; the copied key map also preserves
an ordinary scalar field when a callback replaces the live dictionary value. Newer
caller-owned dirty memory is not adopted over, undone or automatically resaved.

## Preserved policy and limits

Suite-level unrelated features are still merged from the current canonical settings
file; SettingsInitialized, flag allowlist, before-image raw scalar/absence handling,
receipt identity, post-marker acknowledgement and failure rollback policy are unchanged.
Full save still intentionally replaces global scope with its memory intent; it is not
an additive merge. Existing directory preflight/recovery can touch control files, so
invalid input is not claimed to have zero filesystem side effects.

The roots/key map are captured at source admission, not atomically at invocation entry.
Concurrent mutation while copying/serializing remains unsupported. Generic boolValue
callbacks still execute under the source gate, as before. Blocking/hostile converters
and their manager-memory side effects are not made safe or compensated by this patch.

Trusted low-level nested participants share staging and may now observe scope staging
earlier. A valid nested scope replacement is not rejected by a value/marker CAS; the
final check guarantees accepted schema, not identical intent across every participant.
An invalid nested replacement now aborts the whole group. No global manager thread
safety, cache ordering or default-authority claim is added. Full Patch 4 remains partial.

RootHide bootstrap/injected read authority, hook installation, filter expansion,
package dependencies, notification policy and polling/deadline values are untouched.
This is not a claimed explanation for an earlier AIDA64 injection regression.

## Performance and lifecycle

The writer reuses SourceStore staging as its immutable scope copy. There is still one
encode/decode per staged source and no extra source transaction/admission or separate
whole-graph detachment pass. Two staged lookups do not reread source plist contents;
checkPath still runs, including production symlink-resolution/path-admission work,
so extra filesystem metadata overhead is possible and no zero-I/O claim is made.

Extra work is a shallow settings-map copy, two O(app-record count) schema scans and
those path checks inside the existing source critical section. Relative cost is
low/moderate depending on scope size/path state; no device benchmark or speedup is
claimed. Source serialization/physical order and commit count are retained. No timer,
queue, observer, new lock or production callback is added. ARC temporaries contain
only the captured/prepared graph, without a new retained-manager cycle.

## Validation

The group recipe retains **75 exact production methods** plus existing constructor,
state and helper fragments. New native fixtures cover invalid roots/records/flags,
zero scalar conversion before invalid-scope rejection, stale output reset, a flipping
bool converter, mutable live metadata/flag replacement, raw before images, unknown
feature preservation, loader round trip, conversion exception, nested invalid scope,
unsupported storage scalar, nil settings/alias absence and nil scope failure.
Existing H4X/H5C/H5D fixtures retain physical fault/rollback and receipt coverage.
The controlled converter is a reproducer, not evidence of an installed production class.

Windows regression: **62/63 Python suites and 4/4 Node suites pass**. The remaining
keychain bridge retirement suite retains the known Git Bash mkdir permission failure
at /c/Users/ADMIN (4 failures, 1 error, 1 skip in 10 tests). Release source hardening,
RootHide package metadata/negative controls 6/6/static gate, exact 75-method group/
constructor/state/profile fragments, C-helper order, CHECK macro arity and git diff
whitespace checks pass.

The RootHide settings gate now checks the normalized-map binding, alias reuse and both
staged validations instead of pinning the old direct self.settings expression. Three
in-memory negatives reject bypassed normalization, independently evaluated alias and
missing final scope validation. The allowlist/top-level feature guards remain.

Ten full-save negatives reject absent/final-only-removed schema checks, live key-map
alias, repeated raw storage conversion, live manager normalization, lost storage
absence semantics, coerced unsupported storage, delayed scope staging, premature
before-image promotion and receipt promotion before commit. No production files are
modified by controls. Final targeted source/group/profile checks and fragment/macro
review pass after strengthening output-promotion contracts. Native builds/runtime
checks for both schemes remain pending macOS CI/device validation; local contracts
are not native execution or device-hooking proof.
