# Patch 4C.2H5F — Manager settings load validation and scope ownership

2026-10-30: user reports H5E build pass. This patch applies to shared rootful/RootHide
manager sources. No device or native compiler is available on the Windows host.

## Findings and reproduction

1. **High, confirmed unsafe path:** `IdentifierManager.loadSettings` used boolValue
on an unchecked SettingsInitialized value, and adopted ScopedApps without checking
its container or app records. A valid plist with SettingsInitialized as an array,
ScopedApps as an array/string, or a scalar instead of an app dictionary can throw
an unrecognized-selector/subscript exception at load or in scope readers. An NSNull
initialization value also fails if supplied in memory; it is tested as an in-memory
packet, not claimed to be serializable by the plist writer. Initial sharedManager
loading calls this method, so this is a production read path.

2. **Medium, confirmed logic loss:** the manager capture converted failed
`dictionaryWithContentsOfFile` results to empty dictionaries. Malformed/unreadable
settings or scope could therefore replace live memory with disabled defaults or
empty scope while reporting a successful load. A later save may persist that lost
state; H5F proves the erroneous load, not every possible subsequent save. Reproduce
by writing malformed bytes to either file and calling loadSettings on a manager
with existing memory. SourceStore recovery itself does not validate every source
on a no-op write, so prior recovery did not close this gap.

3. **High, conditional crash path:** scope loading copied only the outer dictionary.
App records remained immutable following source capture's immutable plist detachment.
`refreshScopedAppsInfoIfNeeded` later mutates each record's version/build directly.
SecurityTabViewController and AppVersionListDetailViewController call that method.
A resolved app whose installed version/build changed can thus hit mutation of an
immutable dictionary. The native fixture exercises the underlying record mutation;
actual LSApplicationProxy resolution/version refresh requires device verification.

## Implementation

Manager capture now reads settings and scope with the existing bounded immutable
source decoder. Only actual absence becomes an empty dictionary; decoder errors
abort load and keep both live dictionaries. The canonical-to-legacy choice is made
inside the same capture gate, preserving file-first fallback and avoiding repair
writes. A malformed existing selected file is not replaced with defaults.

A pure validator checks root dictionaries, optional SettingsInitialized scalar,
optional EnabledIdentifiers/ScopedApps maps, and per-app dictionary/enabled scalar.
Numbers and strings retain their existing boolValue interpretation; absent fields
keep the old default/alias policies. Unknown metadata and per-identifier sanitization
remain compatible. Invalid structural packets report error 6039. This is not a full
schema validator for every metadata field such as version/build/name.

Manager validation occurs once inside capture. The rootful nonmanager legacy read
path validates its assembled packet before adoption too; its raw-file absence/error
semantics remain unchanged in this patch. RootHide injected load still returns early
before source access. Both new memory dictionaries are prepared before either is
assigned. Each scope app record receives its own mutable copy, allowing later
version/build edits while preserving source values and unknown app metadata.

No new settings, notifications, queues, observers, framework or build source is
introduced. No automatic saving/default repair, directory mutation, cache invalidation,
or swallowing of unrelated Objective-C exceptions is added. Existing stale shared
error policy after a later successful load remains unchanged. Two property assignments
are not an atomic cross-thread memory transaction; full IdentifierManager concurrency,
compatibility-defaults authority and post-release ordering remain separate.

## Performance and lifetime

This is cold manager initialization/reload work, not a hook hot path. Source file
count remains two plus existing legacy presence probes. The decoder uses the same
regular-file/size/immutable rules already used by SourceStore. Validation is O(apps),
and one mutable copy per app record is necessary to satisfy the later mutation
contract. Relative cost low/moderate depending on scope size; no timing claim or
cache optimization without measurements. Candidates are synchronous local objects;
no persistent block capture, callback lifetime or observer cleanup is added.

## Verification

Group native extraction includes exact loadSettings plus the new production static
validator (57 methods total). Host fixture substitutes only manager-role/runtime
reader dependencies; source recovery, capture and decoding use the actual store.
Scenarios cover valid numeric/string flags and legacy iOS aliases, mutable record
ownership, five malformed structural packets preserving both memory objects and
bytes, an in-memory NSNull scalar, corrupt settings/scope byte streams, read-only
legacy fallback with exact-byte teardown, optional/missing sources, and RootHide
injected early return. Existing H5E/source-store fixtures retain bounded decoder,
coherent capture and missing-vs-malformed coverage. CI native recipe compiles and
runs the same fixture for rootful and RootHide; the local extraction does not prove
native compilation or device behavior.

Local Windows verification: **62/63 Python suites and 4/4 Node suites pass**.
The keychain bridge retirement suite retains the existing Git Bash failure:
`mkdir /c/Users/ADMIN: Permission denied` (4 failures, 1 error, 1 skip in 10 tests).
Release source hardening, RootHide metadata/negative controls 6/6, exact group and
profile-flow fragment generation, CHECK macro arity, and git diff whitespace checks
pass. Five in-memory negative controls restoring raw decode fallback, removing packet
validation, restoring shallow scope records, removing app-record type checks, or
assigning live memory before validation are all caught by source contracts. The
controls do not modify production files. No native Foundation, Theos, package or
device validation is claimed locally; H5F awaits macOS CI. Writer rollout remains
partial.


## Build acknowledgement

2026-10-30: user reports H5F build pass. This is user-provided confirmation; no native Foundation/Theos execution occurred on the Windows host. H5G proceeds to scope replacement write acknowledgement and candidate adoption.
