# Patch 8G — Pasteboard native boundaries, counter packets and hook surface

Date: 2026-11-20. The user confirms the Patch 5E working tree builds successfully;
HEAD is still `87b1b9e`, so that commit alone is not the full baseline. Existing
5E source/header/helper/test/report files are preserved byte-for-byte. This batch
covers Pasteboard's ten behavioral adapters, state/hash/invalidation, naming
helper and installer admission together. It does not finish clipboard privacy,
UUID source authority, device profiling or the complete audit.

## Top 10 changes, priority and expected impact

No Critical issue is established. A proven code branch differs from a device
reproducer. Relative costs below come from operations in source, not benchmarks.

| # / Priority / Severity / evidence | File/function and issue | Change and impact |
| --- | --- | --- |
| 1 / P1 / High potential duplicate native effect | `TLinkIOSTweak/PasteboardHooks.x`, old named/URL factories and setPersistent: native calls inside optional try were caught and could fall through to a second native call with original arguments. | Prepare effective arguments separately; invoke native outside the optional catch, once per nonrecursive route. Native exceptions propagate and finally restores TLS/ownership. Tests exercise native throws with transformed arguments enabled, not only the fallback branch. Prevents accidental duplicate creation/set attempts. |
| 2 / P1 / Medium actual false acknowledgment | Old setData/setItems incremented custom state before native ran, including when original was absent or threw. | Preserve raw arguments, invoke native, then account only after normal return and only if the captured epoch remains current. A void native return is the available ACK; it does not prove UIKit changed data or performed a durable write. Missing/throwing originals cannot increment. |
| 3 / P1 / Medium potential reentry and extra accounting | Policy, providers and native UIKit can invoke another hooked selector. Hashing also read through value/type hooks, repeating optional work; setter delegation could count multiple internal calls. | One same-thread preparation/native guard for all ten adapters, restored in finally. Nested calls use the native path directly. An outer setter's successful delegation is counted once. Other threads remain admitted. This intentionally changes internal nested-hook behavior; device testing must validate framework interactions. |
| 4 / P1 / Medium state race | Counter initialization, hash comparison/store and increment were separate mutable-map operations. Concurrent calls could split one logical observation; hashing/string/NSNumber operations and resets also ran under an unfair lock without comprehensive cleanup. | Immutable epoch/entries packet with count and hash in one per-app entry; prepare collection work outside lock, compare-and-publish/retry, precise retired ownership after unlock. Hash observation and increment commit together. Invalidation replaces the epoch, so a late setter/hash callback cannot repopulate the successor state. |
| 5 / P1 / High compatibility risk | Every old installer call supplied NULL expectedEncoding, disabling even the old loose compatibility test. Optional/private selectors could acquire a changed return/argument ABI while still being installed. | All ten remaining bindings supply complete expected signatures. NSMethodSignature compares argument count, return and every argument; qualifiers and annotated objects are accepted, byte BOOL c/B is accepted, blocks/structs/incompatible scalars are rejected. NSInteger follows host width. Missing/incompatible selectors still skip with diagnostics; no selector is fabricated. Actual private semantics beyond ABI remain unverified. |
| 6 / P1 / Medium potential lifetime leak | Native/format/provider exceptions can unwind through receiver, strings, arrays, NSData and partial naming/hash objects in plain ARC. | Precise receiver roots and named finally cleanup in adapters, hash preparation and the real deterministic-name helper. Native exceptions remain distinct from optional preparation failures. Selected weak payload/token tests drain the relevant pool; this does not prove every UIKit/Foundation internal allocation is leak-free. |
| 7 / P2 / Medium avoidable hook overhead | Five adapters only returned native output and emitted diagnostics: generalPasteboard, pasteboardWithUniqueName, itemProviders, itemSetWithPreferredPasteboardTypes: and containsPasteboardTypes:. They added runtime dispatch, scope/provider work and logging without changing those results. | Remove their wrappers, original slots and installer calls. The methods run natively with no replacement; the ten actual behavioral bindings remain. This deliberately retires those diagnostics. General-board naming protection and named/URL creation behavior remain in their behavioral adapters. |
| 8 / P2 / Low/moderate repeated work | Hash preparation read image and URL twice and triggered optional work through nested value hooks. Successful hot adapters also formatted/logged every access. | Read each image/URL once, use the guard's native nested path, remove per-access adapter logs and bypass non-UUID type preparation. Text order, image PNG/data.hash representation, URL string, NSString.hash result and ERROR sentinel remain. PNG encoding and clipboard access still happen on every eligible count query. |
| 9 / P1 / Low arithmetic bug | An increment at NSIntegerMax used signed overflow. | Saturate at NSIntegerMax. This gives a defined boundary behavior in place of undefined arithmetic. Ordinary counter values are unchanged; this is not a redesign to UIKit's native count policy. |
| 10 / P2 / Low allocation tradeoff | Replacing maps with COW could otherwise allocate on every unchanged count read. | Return the existing count when hash is unchanged and no explicit increment is requested, without publishing a new packet. Mutations still copy the entries map and can retry under contention; this normally has one main-bundle entry per injected process. No overall performance win is claimed without profiling. |

## Behavioral contracts

UUID override still skips native when a valid projected NSUUID is available.
The name getter still calls native first, preserves the general-board name and
maps custom names using the same PXPasteboardDeterministicName algorithm. Named
factory preserves its create flag and general-board exception. URL factory
retains the old query construction, including its existing fragment/query
limitations. Scoped persistence still forces YES. UUID pasteboard type still
returns NSKeyedArchiver data with requiringSecureCoding:NO; an invalid/nil UUID
now preserves native data rather than attempting to archive a nil UUID. Other
types retain their native value and no longer trigger diagnostic scope work.

Native object returns are retained through optional work and remain identical
fallbacks. Native exceptions propagate; optional failures return/use native
values or original effective arguments as appropriate. No dispatch queue, timer
or forced main-thread hop is introduced. Calls keep their existing thread.
The archiver entry point is available within the existing iOS 12+ deployment
contract; no older target support is newly asserted.

Counters remain per app, not per pasteboard object. First observed content still
seeds native count plus one; an explicit setter before the first read still
starts its count from zero plus one. A subsequent changed-content observation can
increment again after a successful setter, preserving the old two-source counter
policy. Failed/missing native setters and internal nested delegations are the
intentional correctness changes. Multiple boards can still influence the same
per-app count. Hash collisions, concatenation ambiguity and simultaneous content
observations have not been redesigned.

An operation can finish with state observed just before a concurrent invalidation.
An old epoch cannot republish into a newer one. This is not a transaction with
UIKit's clipboard state: content may change during hashing, and two concurrent
content observations can complete in either order. No native-changeCount-based
memoization is added without proving equivalent content semantics on devices.

## Compatibility and protected scope

The ten remaining hook bindings keep their native function-pointer shapes and
ordering. Signature admission uses full runtime metadata instead of the old
first-return-character helper; the exported loose P1-A helper remains unchanged
for API compatibility and its header explains it is not sufficient for runtime
installation. UIKit private selector existence, behavior and original-trampoline
publication remain runtime dependencies. Install-once/idempotence beyond the
existing constructor and safe arbitrary dylib unload are not established.

The complete Pasteboard constructor is byte-identical, including bootstrap,
scope/WebKit exclusions, notification topics and installer entry. Existing scope
and UUID-source helpers are byte-identical, including RootHide captured-reader
inheritance and rootful manager/generation/file fallback. No UUID preference or
source authority is changed. Existing RootHide cold priming/ElleKit/package,
other hooks, Patch 5E files and source writers remain untouched.

## Performance, memory and remaining work

The directly removed cost is five replacement dispatches and their diagnostics,
plus repeated scope/log work when hashing traverses native methods. Stable hash
observations reuse the count packet. Each actual state mutation copies immutable
maps and may retry. Retired packets can stay alive with in-flight readers or
until their autorelease pools drain. There is no bound on observed bundle keys
or new lock-free claim.

Eligible changeCount queries still read three text representations and image/URL
content, allocate hash inputs and encode PNG data. Large images can have **high**
CPU/memory/latency cost. Clipboard access/privacy prompts, UIKit thread assumptions
and UI latency require real-device evidence. This batch does not eliminate those
reads, cache contents by native count, remove all remaining helper logging or
benchmark request rates. PNG/hash facades cannot establish real UIKit semantics.

The rootful UUID manager, fallback generation/persistence, source snapshot
authority, private method coverage, query-fragment handling, per-board counter
policy, hashing collisions and profile publication timing remain open. Removing
diagnostic-only hooks is justified by their exact native returns; it does not
claim the entire Pasteboard module is now minimal or optimal.

## Verification

`scripts/test_pasteboard_boundaries.py` is enrolled in release and macOS CI. It
extracts the exact state/callback/hash/adapter/ABI bodies and original slots,
links the real PXP1AFilters implementation, and supplies Foundation-only UIKit,
scope, UUID and native-call facades. No system clipboard is read and no real hook
is installed. RootHide/rootful defines test common adapter portability, not an
actual RootHide publication, UIKit privacy dialog or real PNG encoding.

The fixture checks ten fallback routes, transformed factory/setPersistent native
exceptions, one native call/no retry/TLS restoration, naming/general protection,
URL and archive outputs, forced persistence, provider/native reentry, initial and
unchanged hashes, changed content, one image/URL getter read, native failure and
invalidation during native/hash callbacks, nested setter accounting, missing
setter, overflow, stale epoch and concurrent increments. Selected weak payload/
token roots are checked after pool drain. ABI cases include offsets, qualifiers,
annotated objects, byte BOOL, missing args, wrong scalar, struct and block return.

Four compile/run pairs cover rootful/RootHide x plain ARC/ARC exception cleanup
at -O0. Windows checks exact extraction, CHECK arity, 20 rejected negative source
controls and the eight compile/run command recipes; no compiler/binary execution
is implied. Native macOS CI still must compile/run them and Theos must compile
actual UIKit/runtime installation.

Local regression: **76/77 Python suites and 4/4 Node suites**. The remaining
Keychain suite is the established Git Bash mkdir `/c/Users/ADMIN` permission
failure (4 failures, 1 error, 1 skip). Source hardening, RootHide build/package
gates, protected-byte comparisons and diff checks pass. The new source gate is
rerun after fixture refinements. P3 now validates coherent count/hash packet
publication instead of two mutable-map initializations.

Device acceptance remains scoped/unscoped and master OFF/ON, named/general/URL
boards, UUID type archive consumers, repeated count reads, failed native writes,
UIKit internal delegation, large images, profile notifications, rootful and
RootHide including iOS 15.8.8/AIDA64. Full audit/movement/profiling and release
acceptance remain pending; H5S-partial is unchanged.
