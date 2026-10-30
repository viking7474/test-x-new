# Patch 4C.2H5E — Coherent final identifier toggle verification

## Context and finding

2026-10-30: user confirms the H5D build and foreign-thread fixture follow-up pass.
H5E addresses a confirmed logic window in `setIdentifierEnabledAndPersist:forType:`.
After the forward acknowledgements, the old implementation independently read primary
settings and the security compatibility getter. For requested YES, tuple A can be
(primary YES, security NO); a cooperating writer then commits tuple B (NO, YES).
Reading primary from A and security from B falsely confirms a pair that never existed.
The compatibility getter can additionally substitute defaults for a missing canonical
key. Severity: Medium; correctness of the verified receipt, not a demonstrated crash.

## Change and behavior

The wrapper verifies only after forward success. One `PXCaptureRuntimeSources` loader
reads canonical settings plus optional security under the same shared source gate.
It returns detached match booleans with the existing source state/commit marker.
Both NSNumber and NSString bool representations remain supported. Missing keys do
not confirm either requested value; malformed containers fail with error 6038.
Primary-only toggles skip the security read. A capture error produces NO and follows
the existing H5B/H5D conditional compensation. Forward failure skips final verification
and preserves the original write error. A newer unrelated metadata commit does not
invalidate a currently matching pair merely because its marker changed.

`PXReadRuntimeSourceDictionary` reuses SourceStore's bounded regular-file and immutable
plist decoder. Missing file returns an empty dictionary; malformed plist, non-dictionary
root, nonregular input or oversized source fails. This helper acquires no lock and
performs no recovery: callers must use configured canonical paths inside a capture.
It is not a new arbitrary-path admission API. Capture checks pending journal/marker
before the loader, accepts an already committed matching journal, and rejects an
uncommitted recovery-pending state. The capture never repairs sources.

Legacy read/fallback APIs, void setter behavior, generation policy, storage alias,
forward primary/secondary commit boundaries and notifications are unchanged. The
only deliberate read-policy change is canonical-only final verification of a source
write. No new preference field, external dependency, queue or persistent observer.
Rootful and RootHide share the production files and native fixture recipe; RootHide
cold synchronous bootstrap and package dependencies are untouched.

## Tests and limits

Native fixture scenarios demonstrate the old mixed-read false success, reject a
reentrant writer between the two reads while capture is held, and observe the complete
newer tuple after release. They cover unrelated metadata, missing/false keys, primary-only
read count, malformed container, skipped capture on known write failure, and capture
failure with owned compensation. The reentrant check uses the real SourceStore guard;
it is deterministic and does not claim to simulate all cross-process schedules. Existing
source-store process/capture fixtures exercise the common lock implementation.
Decoder fixtures distinguish absence, malformed bytes and a valid non-dictionary plist,
then restore exact bytes and verify the original marker/tuple. Generated native methods
include the exact production helper; the old before-image verification fault now targets
capture rather than the compatibility getter. Source guards and CHECK arity scan cover
the new scenarios; they do not replace native execution.

Healthy paired verification still reads two source dictionaries. Added shared-gate,
marker/journal checks and immutable detachment have expected low/moderate relative
cost on this settings action, not a hook hot path. Under contention capture can wait
up to the existing one-second budget. Known-failure paths avoid final readback I/O.
No timings or speedup are claimed without measurements.

A coherent observation can become outdated after unlock. This change does not make
forward primary/security commits atomic, serialize defaults/cfprefsd/raw writers,
or guarantee mirror/notification order or power-loss durability. H5B conservative
CAS and per-key reentry tokens remain required. Patch 4 and the writer rollout remain
partial. Native Foundation/Theos/package/device validation requires macOS CI; local
Windows source checks cannot establish those results.

## Local validation

Windows regression: 62/63 Python suites and 4/4 Node suites pass. The only failing
suite is keychain bridge retirement: Git Bash cannot create `/c/Users/ADMIN`
(permission denied; 4 failures, 1 error, 1 skip across 10 tests), the existing host
limitation. Release source hardening, RootHide metadata/negative controls (6/6),
exact device-group and profile-flow fragment extraction, and CHECK arity pass.
The group recipe now extracts 56 production methods. Four in-memory negative
mutations removing shared capture, bypassing the forward-success gate, substituting
the compatibility getter, or treating malformed plist roots as absence are all
rejected by the scoped source contracts. The malformed-root mutation exposed a
weak assertion during development; that assertion was strengthened and all four
controls rerun successfully. No repository source was mutated by these controls.
Final source transaction contracts and git diff whitespace validation pass.

These are source/fixture-generation results only. H5E native Foundation, Theos,
rootful/RootHide package and physical-device checks remain for macOS CI/device.
