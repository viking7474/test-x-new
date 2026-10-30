# Patch 4C.2H5I — Verified per-app scope toggle

2026-10-30: user reports H5H build pass. Production changes apply to common manager
code used by rootful/RootHide and the dashboard app switch. No device/native compiler
is available on the local Windows host.

## Findings and production path

**High, confirmed correctness defect:** `setApplication:enabled:` changed live scope
before a full saveSettings call. A failed source write left memory at the requested
enabled state while source retained its previous value. Saving the entire settings/
scope bag also allowed a stale manager to flush unrelated flags or overwrite another
scope record. H5G fixed full replacement and H5H fixed metadata refresh, but neither
changed this setter.

**Medium, confirmed UI receipt gap:** `appSwitchChanged:` invoked the void setter
without checking persistence, leaving the user's switch at an uncommitted value.
Caller review also found the setter in explicit add/enable loops; those retain the
void API and remain part of later workflow review. Add/remove themselves are unchanged.

Reproduce by seeding a disabled app in scope and failing a physical source write,
then toggling its switch on. Previously live memory and the UI could show enabled
while canonical scope stayed disabled. A manager with dirty/stale unrelated flags
also flushed those flags when only this app's enabled state was requested.

## Implementation and compatibility

New public `setApplicationEnabledAndPersist:forBundleID:error:` returns its local
source outcome and optional error. Validate/copy the case-sensitive ID before source
callbacks. A standalone transaction reads/validates the current canonical scope and
merges only the requested entry's enabled field. No settings file, other app, name/
version/build or top-level scope metadata is changed.

A typed NSNumber/NSString already matching the desired BOOL is a canonical no-op.
Missing enabled is explicitly persisted even for requested NO. A missing app/source
returns error 6043 without recreating membership from stale memory; invalid IDs use
6042. Malformed scope fails without replacement. These failures leave manager memory,
cache and notification unchanged, with SourceStore retaining recovery responsibility.
A matching no-op still enters standalone admission and cannot acknowledge outer
uncommitted staging; ignored nested attempts poison that staging as in H4X.

After source success, update only the requested local enabled field on an owned
mutable record. Keep unrelated dirty memory metadata. If that live record is absent
or malformed, it may be adopted from the existing canonical record; this does not
create source membership. Canonical no-op can refresh stale local state and clear
its caches without a write/topic. Fully matching no-op preserves caches; actual
writes retain the existing settings-changed topic and clear the same decision caches.
No whole-map compensation is introduced. A publication successor is not overwritten
because adoption precedes notification and nothing adopts afterward.

The old void setter delegates to this API, preserving its signature. Successful calls
do not clear a newer shared manager error; the verified result/error is invocation
local. The switch action uses that receipt, reads the current manager record after
publication, restores the switch to its current typed state and presents the local
failure only when saving failed. A single-record getApplicationInfo guard returns
nil for malformed live records rather than attempting mutableCopy on an invalid type.

**Deliberate corrections:** toggling does not flush unrelated pending settings/scope,
no-op is based on source rather than memory, and missing canonical membership is an
explicit failure instead of an implicit dirty-memory save. Add/remove and full scope
replacement retain their own policies. Main switch restoration reflects manager state,
not a new cross-process read; prior manager/source drift remains a broader authority
concern. No filter synchronization policy or RootHide bootstrap/dependency is changed.

## Performance, concurrency and lifetime

A changed toggle uses one scope source file instead of the old settings/scope pair.
A no-op still reads source/control state and takes the existing bounded source gate
(up to its one-second contention budget), but stages no new file/marker/topic after
any necessary recovery. Record copying and source decode are low/moderate relative
cost on this cold UI action; no benchmark or hot-hook speedup is claimed. No provider,
network, queue, polling, timer or observer is added.

The source gate is released before adoption/cache/UI/notification. Blocks run
synchronously and are not stored on the manager. Existing Objective-C publication
exception propagation remains unchanged. Cooperative source serialization is not a
cross-thread lock around manager dictionaries, a final-state guarantee after unlock,
or an atomic scope/filter publication. Concurrent local dictionary access, add/remove
failure handling and complete UI batch workflows remain separate.

## Verification

The group recipe extracts 64 exact production methods plus the exact dashboard
switch action. A Foundation-only UISwitch/controller adapter executes that action
against the real manager methods/SourceStore, including failure UI recovery and
post-notification successor state. It does not establish UIKit presentation behavior.
Existing native recipes compile/run the fixture for both scheme defines on macOS.

Cases cover one-file targeted merge, other records/root metadata/settings bytes and
dirty memory preservation, canonical no-op/cache behavior, stale local adoption,
physical fault and void-wrapper retry, nested no-op poisoning, absent source/missing
member/invalid ID, explicit false for a missing key, detached mutable ID, local receipt
with a newer shared error, corrupt bytes and exact teardown, safe single-record view,
switch failure/retry/publication successor and unknown sender. Existing H5F guards
cover invalid source containers/scalars used by the shared validator.

## Local validation

Windows regression: **62/63 Python suites and 4/4 Node suites pass**. The remaining
keychain bridge retirement suite retains the known Git Bash error `mkdir
/c/Users/ADMIN: Permission denied` (4 failures, 1 error, 1 skip in 10 tests). Release
source hardening, RootHide metadata/negative controls 6/6, exact group/profile fragment
generation, CHECK macro arity and git diff whitespace checks pass. The macro scan
caught a comma-separated declaration in a new CHECK block; it was split before final
regression. After strengthening the no-memory-access-before-commit guard, targeted
source/group/profile contracts and extraction were rerun successfully.

Seven in-memory negative controls reverting the void wrapper to full save, mutating
memory before commit, retaining a mutable caller ID, bypassing missing membership,
using shared error as receipt, accepting missing enabled as false, or inverting an
obsolete UI intent are all rejected. These controls do not edit production files.
Native Foundation/Theos builds for rootful/RootHide, UIKit presentation and device
injection remain pending macOS CI/device. Full Patch 4 writer rollout remains partial.
