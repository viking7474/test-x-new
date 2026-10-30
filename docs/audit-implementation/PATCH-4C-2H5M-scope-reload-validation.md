# Patch 4C.2H5M — Explicit scope reload validation and cache invalidation

2026-10-30: user reports H5L build pass. This phase changes the shared manager
implementation and the legacy rootful reload path. Native Foundation/Theos/device
execution is unavailable on the local Windows host.

## Findings and reproduction

**High, confirmed unchecked-container crash risk** — IdentifierManager.loadScopedApps
passed unvalidated ScopedApps into count/allKeys/setDictionary:. A plist dictionary
with ScopedApps as an array or a scalar app record could either throw immediately or
leave invalid records for later dictionary subscripting. H5F hardened loadSettings;
this independent reload path remained uncovered. Reproduce by invoking reload after
writing a structurally invalid but syntactically valid scope plist.

**Medium, confirmed error masking** — dictionaryWithContentsOfFile: returning nil
was replaced by an empty dictionary. Corrupt/unreadable scope could therefore erase
live scope instead of reporting failure. Missing files intentionally still load an
empty scope; malformed files now preserve old memory and expose an error.

**Medium, confirmed stale-cache path** — reload changed scopedApps without clearing
spoofCache or the file-static _appEnabledCache. Prime an enablement decision, change
canonical scope and reload: the old decision could survive until another invalidation
or expiry. This phase clears both caches only when the loaded values differ.

**Potential nested uncommitted view** — manager recovery previously allowed joining
an existing transaction before reload capture. Standalone recovery rejects that
nested use and poisons ignored parent staging rather than presenting it as a successful
reload. This is a defensive contract change; no device occurrence is claimed.

## Implementation and preserved policy

The existing void loadScopedApps delegates to private reloadScopedAppsWithError:.
The helper clears its optional error output, verifies the process role and returns an
operation-local BOOL. It leaves the historical shared manager error untouched on
success; callers must use the local receipt. RootHide injected YES means a skipped
no-op, not acknowledgement of a loaded canonical source.

Manager: run an empty standalone owner transaction to recover pending journals, then
read the scope through PXCaptureRuntimeSources and the existing bounded immutable
decoder/shared settings validator. There are no newly staged source writes or
notifications. Recovery may finish/restore earlier pending source work. Decode,
validation or capture failure preserves the exact live scope object and both caches.
A successful observation is not a guarantee that another writer cannot commit after
the capture releases its lock.

Legacy rootful injected process: use the bounded decoder directly on the scope file,
without source owner initialization/recovery or control-directory access. This remains
an uncoordinated single-file observation, not a transaction acknowledgement; it may
see bytes from a writer that later rolls back. Nonregular, oversized, malformed or
unreadable input now fails closed. Valid dictionaries and absent-file empty policy
are retained. PXRuntimeSourceStore.h documents this explicit legacy decoder use;
the helper grants no additional source write authority.

After all validation, build one mutable root with independently mutable app records,
compare values with existing memory, adopt once and invalidate both caches if changed.
No callbacks are introduced between validation and adoption. Existing enabled scalar
compatibility, unknown fields and exact bundle ID case are retained. Nested plist
values remain immutable decoder-owned values, as in the H5F load policy.

## Performance, lifetime and limits

Work is O(n) for validation, record copying and comparison on a cold reload path.
The existing rootful cache-miss caller and 60-second throttle are unchanged; failure
still consumes that caller's reload interval. Owner recovery/capture lock acquisition
retains existing deadlines. The manager has an additional serialization/detachment
cost; no measured speedup is claimed. The shared decoder rejects a file whose lstat
size exceeds 64 MiB before reading it. This is a preflight limit, not a hard bound
against a noncooperative concurrent file replacement/growth between lstat and read.
Repeated file-existence probes, full key-array/debug-list allocation and verbose
debug logging were removed from this reload; expected saving is low and workload dependent.

No timer, queue, observer, hook, bootstrap, filter, package dependency or callback
lifetime is changed. The production enabled cache is file-static and shared across
manager instances. The fixture models its clearing through an ivar: that proves the
invalidation call contract, not global cache ownership or concurrency. Unsynchronized
manager memory access, shared-cache ownership and cross-thread hot reads remain
separate work. No new lock is held around manager memory or callbacks.

## Validation

The native recipe now extracts 71 exact production methods (including both reload
entry points), shared validator/C helpers and the existing UI helpers. New fixtures
cover typed adoption, record mutability, matching-value cache retention, malformed
containers and byte/root errors, capture failure, nested staging, writer rejection
during capture, missing-source behavior and both process/scheme branches. Source and
settings bytes, source commit marker, memory identity, caches and notification counts
are checked where applicable. Malformed-byte fixtures restore exact original bytes.

Local Windows regression: **62/63 Python suites and 4/4 Node suites pass**. The
remaining keychain bridge retirement suite retains its existing Git Bash mkdir
permission failure at /c/Users/ADMIN (4 failures, 1 error, 1 skip in 10 tests).
Release source hardening and RootHide package metadata/negative controls 6/6 pass.
Exact group/profile fragment extraction, native C-helper definition order, CHECK
macro arity and git diff whitespace checks pass.

Nine in-memory reload mutations are rejected: raw decode fallback, bypassed manager
schema validation, early memory publication, shared immutable records, missing enabled
cache clearing, unconditional cache clearing, missing RootHide early exit, legacy
rootful owner access and nested recovery admission. Reversed native C-helper order
is rejected separately. Negative controls do not edit production files.

Both scheme native builds/runtime checks remain pending macOS CI; full Patch 4 and
global reader/cache ordering remain partial.

2026-10-30: user reports H5M build pass. H5N addresses per-instance enabled-cache
ownership; local Windows checks still do not imply native/device execution.
