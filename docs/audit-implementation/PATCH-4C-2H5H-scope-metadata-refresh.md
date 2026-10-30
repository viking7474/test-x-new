# Patch 4C.2H5H — Conditional scope metadata refresh

2026-10-30: user reports H5G build pass. Shared IdentifierManager code is changed
for rootful and RootHide. Native Foundation/Theos and private-framework device
behavior cannot be executed on this Windows host.

## Findings

- **High, confirmed write-boundary defect:** refreshScopedAppsInfoIfNeeded changed
  live records before persistence and unconditionally called saveSettings. A scope
  write failure could leave new version/build in memory with old source bytes.
  The full save also flushed the manager's unrelated dirty flags and entire scope,
  so stale manager state could replace newer settings/enablement during a metadata
  refresh. H5G protects explicit whole-scope replacement, not this separate path.
- **Medium, confirmed unnecessary I/O:** opening App Version settings/list/editor
  refreshed every app then saved settings and scope, even with identical metadata.
  A nil shortVersionString was compared before normalization; an existing empty
  string still compared unequal to nil, causing repeated writes.
- **High crash risk, confirmed unsafe calls:** a stored non-string version/build
  could receive isEqualToString:, and private class/factory/getters were assumed
  available. Wrong stored Foundation types are reproducible inputs. Missing
  LaunchServices selectors are compatibility scenarios exercised by host fixtures;
  no specific iOS version is claimed to lack these APIs on a physical device.

Production callers inspected: SecurityTabViewController opens the App Version list
and AppVersionListDetailViewController opens its editor after this refresh. Neither
caller relies on flushing unrelated IdentifierManager flags. H5F made loaded records
mutable, but did not narrow refresh writes or validate arbitrary metadata field types.

## Implementation

The legacy void entry delegates to a private BOOL method. It first takes standalone
source admission and reads/validates immutable canonical scope, then releases the
gate. A detached memory basis records version/build before private callbacks. The
installed-app query iterates immutable canonical keys, not a mutable live dictionary.
Dynamic class/factory/getter checks and typed string returns leave unsupported or
unresolved apps untouched. Valid nil getters normalize to empty strings before
comparison. String copies detach mutable provider results.

After any required SourceStore recovery, if neither source nor local metadata needs change, return after this one read
admission with no source writes, permission repair, cache invalidation or topic.
Otherwise a second standalone transaction rereads current scope. It patches only
version/build of existing records whose old version/build still matches the captured
basis, or which already equals the desired installed metadata. Removed apps and
newer version/build are skipped. Current enablement, names, unknown app fields,
new scope members and top-level metadata are preserved. No settings file is staged.
Only an actual source metadata change advances the marker and sends one topic.

After source success, admitted fields may update a live record only if its version/
build still matches the independent memory basis. Missing records are not recreated;
newer local metadata and unrelated dirty fields are preserved. Matching source can
refresh stale local metadata without a source write/topic. Relevant cache invalidation
follows actual source or memory change. Failure preserves memory/caches/topics and
lets SourceStore recovery preserve bytes/marker. The invocation returns its local
receipt; successful publication does not clear a newer shared error.

**Deliberate behavior correction:** opening a metadata screen no longer flushes
unrelated pending flags/scope or repairs their directories/permissions. Explicit
settings/scope setters retain their policies. This follows the refresh purpose and
removes a demonstrated stale-write path; it is not a formatting-only refactor.
Installed version/build string conventions and unresolved-app values are retained.
Source and memory maps may intentionally diverge after a newer local edit; the
refresh does not synchronize all manager state.

## Concurrency, compatibility and lifecycle limits

No source gate is held during LaunchServices calls, cache invalidation or notification.
Standalone admission rejects nested uncommitted callers before private lookup and
poisons ignored outer staging. Blocks are synchronous, with no persistent callback,
queue, timer or retain cycle. Existing provider/publication exception propagation is
unchanged. No new runtime hook, package dependency or RootHide bootstrap is introduced.

This is value-conditional metadata merging, not whole-marker CAS or same-value ABA
protection. A state can change again after source unlock, and live dictionary check/
assignment is not a cross-thread lock. The current UI callers are synchronous; global
manager memory concurrency, defaults authority, mirror/filter order, power-loss
persistence and the full Reset workflow remain separate.

## Performance

No-op avoids two source-file writes plus journal/marker publication from the old full
save. It still reads bounded source/control data, validates scope and detaches memory;
changed metadata requires two short standalone admissions and one scope write. Private
lookups remain synchronous on the caller's thread; there is no claim to have removed
all UI latency. Work and allocation scale with scope size, expected low/moderate on
this cold action, without benchmark numbers. The two-field comparison allocates no
per-call key array. No unmeasured hot-path optimization is introduced.

## Verification

The group recipe extracts 61 exact production methods plus the field matcher, compiled
for both scheme defines in macOS CI. The controlled private-framework collaborator
uses a unique fixture class and forwards other class lookups unchanged. Scenarios
cover one-file refresh/settings-byte preservation, enable/name/unknown fields and
unresolved apps, unchanged wrapper and normalized-nil no-ops, missing class/factory/
getters and wrong optional types, failed write/retry, outside-gate callbacks, removal/
newer-version conflicts, merge of newer source enable/name, independent local edits,
source-equal stale memory adoption, nested poison, malformed bytes with exact teardown,
and non-string stored version repair. Source/fixture generation is not native execution.

## Local validation

Windows regression: **62/63 Python suites and 4/4 Node suites pass**. The remaining
keychain bridge retirement suite still fails at Git Bash `mkdir /c/Users/ADMIN:
Permission denied` (4 failures, 1 error, 1 skip in 10 tests), the known host limitation.
Release source hardening, RootHide metadata/negative controls 6/6, exact group/profile
fragment generation, CHECK macro arity and git diff whitespace checks pass. The macro
scan caught an unprotected dictionary-literal comma in the new fixture; it was fixed
before final regression. Six in-memory negative controls for removing the source
field guard, using canonical instead of memory basis, reintroducing whole-settings
flush, unconditional topic, removing nil normalization or removing a getter guard are
caught by source contracts. No production files are changed by those controls.
Native Foundation/Theos rootful/RootHide builds, LaunchServices behavior and physical
injection remain for macOS CI/device. Full Patch 4 writer rollout remains partial.
