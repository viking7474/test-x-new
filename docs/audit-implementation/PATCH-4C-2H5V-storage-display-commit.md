# Patch 4C.2H5V — One owned storage display commit

2026-10-30: user confirms H5U build passes and requests continued implementation.
This closes the previously recorded three-autosave path for the modern
StorageManager used by IdentifierManager. Shared code applies to rootful and
RootHide manager processes. The injected RootHide snapshot path is unchanged.

## Confirmed problem and scope

**Medium / P1 correctness, P2 I/O cost:** currentValueForIdentifier: generated and
final StorageSystem fallbacks called setTotalStorageCapacity:,
setFreeStorageSpace: and setFilesystemType:. Each setter changed cache first,
then saveToCurrentProfile acquired its own lifecycle owner and persisted the
whole cache. A successful fallback could publish three intermediate source
records; a later failure could leave a partial tuple or a cache not matching the
last committed record. Re-resolving current selection for each setter also let
one fallback distribute values across different targets after selection drift.

This is a code-level path, not a measured frequency or a claim about an observed
device incident. Cached/file display hits do not execute those three setters.
The writer still owns <profile>/storage.plist; no identity/storage.plist or
device_ids schema/location change is introduced.

## Production implementation

StorageManager.h/.m adds
commitDisplayStorageInfo:updateFilesystem:error:. It validates dictionary/string
input and copies the three requested strings before target resolution. Extra
input keys are ignored; empty strings retain the old scalar setter policy.
updateFilesystem=NO preserves the cached filesystem field. YES with a missing
filesystem requests removal, matching the prior nil setter. The caller suppresses
ownership of a malformed optional generated filesystem member, preserving H5U.

Perform a standalone no-op admission before lifecycle/target/cache work. This
rejects an enclosing uncommitted SourceStore transaction and poisons its outer
staging if the caller ignores failure. The no-op does not publish a new commit
marker in ordinary operation. Recovery/admission may still touch control files.

Acquire one PXProfileArtifactMutation for a profile-root target. Resolve canonical
current_profile_info.plist only inside that lifecycle resolver, retaining the
old current-save authority and support for existing root-only legacy profiles.
Missing targets are rejected; the API never creates a profile/identity directory.
Cache capture/preparation runs after ownership and before the artifact source
gate, allowing the existing busy/pending-deletion and directory-proof checks.

Merge the three requested fields into one cached full-record candidate, preserving
unrelated cache keys. As with old setters, this is not a fresh merge of disk-only
fields absent from cache. Stage that record once at mutation.profileDirectory /
storage.plist, read the immutable staged dictionary back and allocate its mutable
cache shell before commit. A preparation/allocation error can still abort staging.

After performSourceWrite acknowledges success, assign that prepared shell directly
to the private cache while the lifecycle lease is still held; then invalidate in
finally. No overridable adopt/setter/provider/notification callback or new cache
allocation runs at that publication step. Pre-marker failure retains old source
and cache; existing SourceStore post-marker acknowledgement semantics remain in
force. Cache-copy exceptions before staging release ownership before propagating.

IdentifierManager checks for the new selector in both storage fallbacks. A modern
provider receives exactly one packet attempt. Failure is logged once after the
API has released ownership and is not retried through legacy setters. The reader
still returns its prepared display string, as before. This intentionally changes
the failed-persistence cache behavior: it no longer pretends the candidate was
committed. Older/partial providers without the new selector retain the H5U guarded
per-field setter fallback. Public per-field setters elsewhere remain unchanged.
Because failed candidates are not cached as committed, a later display read can
generate/retry again. No timer or backoff is introduced; failure-path frequency
depends on existing callers and needs device observation.

## Performance and lifecycle

For an ordinary successful complete-provider fallback with no recovery work:

- Artifact commits: three becomes one; lifecycle acquisitions: three becomes one.
- Source helper entries: six becomes three. Previously each autosave entered for
  pending-deletion preflight and again to write. Now one standalone admission,
  one ownership preflight and one artifact write occur. A busy attempt still
  performs the standalone admission before failing lifecycle acquisition.
- One serialization/journaled record replaces three. One staged dictionary read
  and a cache shell allocation are added before acknowledgement; path checking
  can include symlink/metadata I/O.

Expected cost reduction is moderate to high when this cold/fallback path is hit;
absolute latency and call frequency are unmeasured. Synchronous source/control
I/O remains on the calling thread, with the existing bounded source gate waits.
No queues, polling, timers, observers, network requests or new notifications.
No stronger fsync/durability claim. Blocks are synchronous and do not retain a
long-lived manager/callback cycle; finally closes the mutation's held resources.

## Tests and limitations

Extend the existing artifact-preparation native fixture with the exact new method
and the reader native fixture with a modern provider adapter. Both existing CI
commands already run rootful and RootHide variants; no new platform lane.

Artifact cases cover one commit/three admissions, cache remaining old during the
commit checkpoint, complete tuple/metadata preservation, filesystem removal vs
preservation, root artifact location, inactive target/notification invariants,
pre-marker fault rollback including marker bytes, post-marker housekeeping
exception acknowledgement, invalid input, busy ownership, pending deletion,
reentry, caller string freezing, canonical selection drift, cache-copy exception,
root-only legacy targets and missing canonical selection. Nested source calls
must fail and poison the outer transaction without cache publication.

Reader cases cover one modern packet in generated and final fallback, no legacy
setter calls on success or failure, unchanged candidate display on failure and
the filesystem ownership flags. H5U partial-provider setter tests remain active.
Source contracts verify ordering/target/single staging and exact extracted bodies;
CHECK macro arity and native fragment generation are checked locally.

The new cache assignment is ordered against cooperating lifecycle owners, not
all code touching _storageSettings. Legacy setters still mutate memory before
their own autosaves; external/CFPreferences writers and unsynchronized manager
cache access remain separate. External canonical selection drift after capture
does not redirect this owned target, but no newest-selection publication CAS is
added. Legacy providers without the new API can still execute three saves.

Hook/bootstrap/filter/package behavior, generation distributions, formatting,
default capacities, global toggle authority and reset workflow are unchanged.
No new source is enrolled. The storage manifest entry lists the new entry point;
rollout stays H5S-partial and full Patch 4 remains incomplete.

Local Windows regression: 62/63 Python and 4/4 Node; known Git Bash mkdir permission
failure remains in bridge retirement. Source hardening, RootHide metadata/static
contracts, exact identifier/artifact/group/profile fragments and focused mutation
controls (12/12) are checked separately. Native Foundation/Theos/device execution is
unavailable locally; H5V needs the next macOS CI and device verification.
