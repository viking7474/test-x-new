# Patch 5E — App Version source cache and NS/CF dictionary boundaries

Date: 2026-11-17. Baseline `87b1b9e` (Patch 8F), whose build the user confirms
passed. This batch covers AppVersionHooks.x source resolution, invalidation,
projection caches, two NSBundle getters and two CFBundle getters together, plus
the two shared App Version helpers. Constructor/install bindings remain intact.
It does not finish source authority, profiling, movement or release acceptance.

## Top 10 changes, by priority and expected impact

No new Critical finding is established. The CF lifetime issue is a code-proven
unsafe ownership window with a potential crash; there is no device crash trace.
Relative costs below describe source operations, not measured speedups.

| # / Priority / Severity / evidence | Location and problem | Change / expected impact |
| --- | --- | --- |
| 1 / P1 / High potential use-after-free | `TLinkIOSTweak/AppVersionHooks.x`, old PXCachedOrBuildCFInfoDict / PXReleaseCFInfoDictCacheEntry: a Get hook returned a non-retained cache pointer; another thread could invalidate/replace its only owner before the caller used or retained it. Retaining the input bundle alone did not own this fabricated dictionary. | Keep distinct CF projection values in a process-owned immutable history, including across invalidation. Retain native input/result for the wrapper frame. Fixture holds a borrowed result without caller retain across pool drain/invalidation, then uses it and balances a caller retain/release pair. Historical ownership is deliberate and unbounded by count; this is not a free memory optimization. |
| 2 / P1 / High potential permanent bypass | Old NS/CF wrappers incremented recursion before original, but original execution was outside their cleanup. If native code threw, the thread could remain marked recursive, silently bypassing future projection. | Outer try/finally restores depth for native success, nil, missing-original and exceptions. Original stays outside the optional-preparation catch, so a native exception propagates once and is not retried. Main routes are checked for one native call each. CF alias identity lookup may additionally call the native metadata getter, preserving existing policy. |
| 3 / P1 / Medium actual stale projection | Old full-dictionary cache validity used only bundle/localized/generation. Raw plist cache could detect a changed mtime and return a new version, yet the full dictionary still returned the old generation-only value. Changed native unrelated fields were also hidden. | A projection entry includes bundle, version, build and an immutable top-level copy of the original dictionary; compare these outside the lock. Content changes rebuild even without a notification. Localized and ordinary dictionaries retain separate slots. New warm equality work costs O(dictionary contents); correctness takes priority over a claimed speedup. |
| 4 / P1 / Medium invalidation race | Raw/plist and full-dictionary candidates prepared outside the lock could repopulate state after invalidation. Old generation integer could also wrap; old source caches had no generation ticket. | Unique object epoch and immutable files/projections packet. Capture before work, compare epoch before adoption/return, merge same-epoch publications with retained-basis compare-and-publish/retry. Invalidation replaces the whole state with a fresh epoch. Stale work cannot merge into the successor epoch; a later call retries normally. |
| 5 / P1 / Medium potential deadlock/lock poisoning | Old cache code called dictionary/string/date operations, removed mutable maps and released CF dictionaries while holding the unfair lock, without comprehensive unlock cleanup. | Lock only retained root capture, identity compare or pointer publication. File access, hashing, equality, copying and retired-object destruction run outside. Precise retired roots plus finally protect cleanup. A single lock still serializes short pointer operations; the design is not lock-free or wait-free. |
| 6 / P1 / Medium potential lifetime failure | Original NS receiver/native dictionaries, CF inputs, source paths, output fields and partial dictionary clones cross callbacks that can throw. Plain ARC does not generally clean all strong locals during Objective-C exception unwinding. | Precise NS receiver, explicit native CF retains/releases and named roots/finally across source/projection helpers. PXP1BFilters' App Version clone and filename helpers get explicit cleanup. Selected weak caller/token/partial-clone tests drain the relevant pool. Unsafe pointers, arbitrary destruction exceptions and every framework-internal allocation are not covered. |
| 7 / P1 / Medium malformed-state risk | Master/per-app enabled fields previously received unchecked boolValue messages. Bad plist containers or scalar types could raise or partially assign output fields. | Require NSNumber/NSString flags and expected dictionary/string fields, normalize output strings before assigning both output slots at the end, and clear outputs on entry. Guard source/master preparation before foreign input callbacks and restore on all exits. Invalid, disabled or unavailable data returns NO, retaining native metadata. |
| 8 / P1 / Medium stale metadata case | Old cached data with both old/current mtime nil was considered valid, allowing a positive dictionary to remain memoized without reliable metadata. | Only reuse a positive timestamp match. On misses, compare timestamps before/after reading before memoization. Without reliable metadata use that read only; repeated nil metadata reads again. This can increase I/O under metadata failure. Same-mtime replacement, stat/read races and multi-file consistency remain unresolved. |
| 9 / P2 / Low/moderate avoidable work | Old NS foreign-bundle decisions evaluated main-bundle scope before rejecting foreign object identity. Lazy main-ID fallback also wrote a shared string without synchronization. | Reject foreign NSBundle identity first, then scope/version work. Capture/publish the immutable lazy main ID under a short lock; read/copy native metadata outside it. Constructor still captures the ID before hook installation. Non-main CF aliases with the main ID retain their old coverage; they are not reduced to object identity. |
| 10 / P1/P2 / Low cleanup and callback risk | Separate mutable source maps, duplicated NS/CF cache paths, integer generation and an unused path resolver complicated lifetime reasoning. Notification/dtor invalidation could also let optional exceptions escape. | One source/projection packet and one projector serve all four routes; remove unused resolver and old CF release machinery. Notification/dtor contain optional invalidation exceptions. The history remains owned and observers/install machinery remain as before; arbitrary dylib unload is not made safe. |

The ownership distinction follows [Apple's Core Foundation ownership policy](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFMemoryMgmt/Concepts/Ownership.html):
Get returns do not transfer ownership; code retaining a value must balance its own
ownership. Process history is the conservative implementation choice here, not
an Apple requirement that all Get results live forever. Cleanup and precise roots
follow the [Clang ARC lifetime/exception rules](https://clang.llvm.org/docs/AutomaticReferenceCounting.html).

## Flow and preserved semantics

Public PXGetSpoofedAppVersionForBundle clears requested outputs, freezes the
bundle identifier, captures an epoch, reads the same security master source,
loads the global SpoofedVersions entry and only falls back to the current
profile's app_versions file for missing fields of an enabled entry. Per-app OFF
does not enable from profile data. One available version/build still permits
projection; the other native field remains. NULL output slots remain supported.
Scalar conversion retains NSNumber/NSString boolValue conventions; no stricter
version-format policy is introduced.

Global filename, master key, field keys, profile ID/root resolver and safe bundle
filename mapping stay unchanged. Paths remain live file readers in both schemes;
there is no migration to a different source/defaults authority. A single query
uses one invalidation epoch, but that is not an atomic snapshot of its multiple
source files or of a profile switch that has not delivered notification.

NS wrappers call native and keep its exact result as fallback. Nil dictionaries,
out-of-scope/master OFF/per-app OFF, malformed data and optional preparation
failure retain native output. NS only projects the actual main bundle. CF keeps
the existing main-bundle/alias-with-main-identifier policy, without treating a
CFBundle as a toll-free NSBundle. CF input remains a CFBundleRef throughout.
The original native dictionary is never modified in place.

Raw file cache entries and projected NS entries can be reclaimed on invalidation.
Only CF projection history has process-owned lifetime. Equal contents share an
owner across epochs; ordinary and localized bases stay distinct when their
contents differ. Top-level copies preserve native nested-object semantics; this
does not support concurrent mutation of arbitrary nested original values.

An operation may finish with a view captured just before a later invalidation.
Candidate publication and final checks prevent acknowledged obsolete-epoch work
from rebuilding the successor cache; they do not make the response atomic with
an external writer. Same-epoch overlapping reads can finish in either order, and
the next timestamp check is still needed. No source-file write, preference write,
timer, queue, observer topic or polling mechanism is added.

## Performance and limits

The master security plist is still read on each query; positive global/profile
entries still perform metadata I/O. Cold reads add a second metadata check, while
profile path handling removes the separate fileExists probe. No benchmark or
overall CPU/I/O reduction is asserted. The important hot-path removal is
collection/file/equality work under the cache lock and unnecessary NS foreign
bundle preparation. Projection equality adds work proportional to metadata size.

Source/projection packet updates copy affected immutable maps and may retry under
contention. Cache memory scales with visited paths until invalidation. CF history
scales with distinct projected contents over the process lifetime, scans old
values outside the lock and copies its array on a new value. CF projection work
that becomes obsolete just before return can also pin a candidate; no bounded
eviction is claimed. Repeatedly changing large metadata can therefore have
moderate/high memory and equality cost. There is no borrowed-result release
signal permitting safe arbitrary eviction.

File mtime is not content identity: preserved/coarse mtimes can miss changes,
and pre/post stat does not pin a file descriptor or make plist sources a
transaction. Missing notifications, cross-process publication latency, rootful/
RootHide reader authority, sandbox accessibility and write durability remain
pending. Main-ID constructor-before-hook publication, hook-engine trampoline
publication and original native bundle lifetime remain runtime assumptions.
Process-lifetime history does not establish safe arbitrary image unloading;
observer removal and hook removal are not implemented in this patch.

## Verification and acceptance

`scripts/test_app_version_boundaries.py` is enrolled in release gates and macOS CI.
It extracts exact shared helpers, both NS bodies and both CF wrappers; NS native
calls, source file/metadata entry points, scope and projection factory use
controlled facades. The two pure App Version helpers are compiled from the actual
PXP1BFilters.m. The fixture uses real Foundation/CoreFoundation objects, unique
temporary plists, real bundle handles and real queues. No actual hook is installed.

`PXAppVersionBoundaryTests.m` checks four native routes/counts, original exception
propagation/TLS restoration, nil/missing originals, scope failures and OFF cases,
NS foreign-bundle lazy behavior, CF alias identity and cross-NS/CF reentry. Source
tests cover timestamp reuse, changed source without notification, changed native
unrelated fields, profile fallback/switch, typed scalars, nil metadata, exceptions,
invalidation during read/scope work and concurrent cache merge. Borrowed CF values
are used after pool drain/invalidation without a caller retain, then after a
balanced caller retain/release. Selected caller/partial-clone/token lifetime probes
and a failing projection factory test optional boundaries. The clone test uses a
real NSDictionary and a length-only fault provider that throws before any string
is passed into Foundation; no incomplete NSDictionary class-cluster subclass is
required.

The matrix is four compile/run pairs: rootful/RootHide x plain ARC/ARC exception
cleanup at -O0. Windows checks capture those eight commands, exact extraction,
native-call substitutions and CHECK arity; compiler and binaries do not execute.
Twenty negative source controls are rejected. P3's mutable-map-init assertion is
replaced with immutable epoch/publication contracts; its 84/84 checks pass.

Local regression: **75/76 Python suites, 4/4 Node suites**. The remaining suite is
the established Keychain Git Bash mkdir `/c/Users/ADMIN` permission failure
(4 failures, 1 error, 1 skip). Source hardening and RootHide build/package gates
pass; new source gates are rerun after fixture refinements. Protected byte checks
preserve the complete App Version constructor/install bindings, all other hooks,
bootstrap/RootHide synchronous cold priming, package/Makefile, source writers,
Location manager and the hostname/ATT portion of PXP1BFilters. The same changes
compile in both schemes through the existing source enrollment.

Native Foundation/Logos/Theos/device execution is still pending macOS CI/hardware.
Device acceptance should cover repeated metadata reads, live version/build edits,
profile switch, native localized metadata, OFF/unscoped behavior and memory under
many versions on rootful and RootHide, including iOS 15.8.8/AIDA64. H5S-partial
remains; full audit and release acceptance are not complete.

Preflight also rechecked movement selectors/callers. Static inventory finds only
the manager's own movement implementation and declarations, while production
hooks use the separate active snapshot/delegate flow. This does not prove no
dynamic API/selector caller exists. Movement implementation is preserved; its
validation, eager generation, timer/completion/index/persistence issues and the
runtime retirement decision remain open. No device simulator/profiling evidence
is invented to close Patch 7.
