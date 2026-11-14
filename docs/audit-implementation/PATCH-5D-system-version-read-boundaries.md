# Patch 5D — SystemVersion file, CF and bundle read boundaries

Date: 2026-11-14. Baseline `de5c90c` (Patch 5C): user confirms build passed and
requests larger batches. This batch covers seven active read entry points, the
shared transformer/projection factories and borrowed-string publication. It does
not close Patch 4, full OS reporting/device acceptance, movement or profiling.
Writer enrollment remains H5S-partial.

## Ten changes and their evidence

| Priority / severity / confidence | Finding, impact and reproduction | Change / relative cost |
| --- | --- | --- |
| P1 / High / actual failure boundary | The three Foundation file replacements called scope/projection helpers after a successful native read without a projection catch. An identifier/policy provider exception could turn successful file I/O into an app exception. Inject a provider fault after native returns. | Keep native outside the projection catch; path/scope/transform failure returns the identical native result. Nil reads remain nil; original NSError output and arguments are forwarded. Each available original runs once; original exceptions propagate. Low control-flow/cleanup overhead. |
| P1 / High / actual retry defect | CFBundleGetValueForInfoDictionaryKey invoked original in several branches inside a catch. An exception could fall through and invoke it again. Inject a native exception on scoped binary metadata or a foreign bundle. | Native fallback is outside projection catches. Preserve original borrowed result identity and exception; no replay. Valid app-version overrides keep zero native calls. |
| P1 / High / potential deadlock | Borrowed-string interning called dictionary lookup, string copy and dictionary insertion while holding an unfair lock, without exception-safe unlocking. A throwing hash/copy could poison it; reentrant foreign methods could wait on it. Normal profile strings are usually Foundation strings; no device deadlock is claimed. | Retain an immutable dictionary basis under the lock, perform all explicit string/dictionary methods outside it, then publish by retained-basis identity. Defer retired-root release until unlock. Thread-local interner guard rejects nested preparation. Warm lookup is O(1); a new distinct value copies O(N) entries and contending writers can retry. This is a correctness tradeoff, not an asserted performance win. |
| P1 / Medium / potential recursive expansion | Projection providers may themselves read SystemVersion through another convenience method/CF provider. Separate entry points could prepare the same identity again or recursively expand work. | One common thread-local projection guard shared by both CF Copy providers and all three file entry points. Nested provider reads still call native, then skip projection. Enter/leave preserves prior state in finally. Native originals run before entering this guard; corrupt/self-recursing original pointers or arbitrary third-party swizzle loops are not repaired. |
| P1 / Medium / potential exceptional lifetime leak | The transformer/factories and CF/file adapters owned parameters, partial dictionaries, parsed roots and model/provider objects inside try/catch without explicit plain-ARC exceptional cleanup. | Named roots and finally throughout the active chain; snapshot captured once, partial roots cleared and policy/error output slots use explicit autoreleasing locals without hidden strong writeback state. The implementation of external identity/AppVersion/policy providers is not claimed leak-free by this batch. |
| P1 / Medium / potential cross-surface recursion/lifetime issue | ObjC and CF Info.plist hooks used independent preparation guards; a provider could enter the other adapter. A callback can also release an incoming CF key owner. | Check the other Info guard before preparing; nested reads use native. Restore the saved TLS value, pin the ObjC receiver and relevant CF key across callbacks, and keep constructor-cached main bundle identity. Do not resolve bundleIdentifier from an Info.plist hook. |
| P1 / Medium / actual defensive fallback inconsistency | With the CF original symbol absent, main-bundle MinimumOSVersion returned NULL when scoped but could return physical version when unscoped, due to an early metadata return. | Uniform physical-runtime fallback for main-bundle MinimumOSVersion only when original is absent. Foreign/nil bundles/keys keep NULL behavior. Existing original always wins for binary metadata. This deliberately changes the scoped missing-symbol edge case, not ordinary supported-symbol behavior. |
| P1 / Medium / protocol preservation | Copy results must retain ownership across pool drain; Get results must not add a caller-owned retain. Earlier normal-flow ownership was already correct; a cleanup refactor must preserve it. | CF Copy stages the new +1 result before relinquishing the old +1 result; success, no-op and failure preserve the correct pointer/ownership. Borrowed overrides still retain process lifetime and mutable inputs are copied. Native borrowed passthrough gains no extra ownership. No TTL/eviction is added to the borrowed cache. |
| P1 / Medium / consistency defense | Dictionary transformation fetched three projection fields repeatedly during validation/comparison/insertion. A nonstandard mutable/KVC collaborator could change them across reads. | Capture ProductVersion/ProductBuildVersion/ReleaseType fields once, validate them and atomically publish a new dictionary as before. The projection model's immutable contract remains required; three property reads do not create a global transaction against arbitrary concurrent mutation. |
| P2 / Low-to-moderate avoidable work / source evidence | Every main-bundle metadata key entered scope/provider work although only app version/build can change. | Whitelist the two app keys before read-scope/admission/provider work. MinimumOSVersion, DTPlatformVersion, DTSDKName and other keys remain native. File readers still enter their existing lexical read scope and still classify paths; this batch does not claim to remove all hot-path overhead. |

The ownership distinction follows Apple's
[Core Foundation ownership policy](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFMemoryMgmt/Concepts/Ownership.html).
The override cache keeps its previous, stronger process-lifetime guarantee.
Unique historical override strings therefore still consume resident memory; it
would be unsafe to silently add eviction while retaining that guarantee.

## Preserved policy and integration

- Both CF Copy entry points use the same reporting projection and common guard.
  IOSVersionHooks retains shouldSpoofForBundle + IOSVersion enablement. Tweak's
  coordinator provider retains class/manager presence, IOSVersion enablement and
  its existing Safari/Auth process option. A missing/nil native Copy source still
  permits the existing empty-base reporting projection; nil file reads never do.
- Configured upward OS reporting, native-safe helper policy, legacy Fix Version,
  source tuple, release type and unknown keys remain. Data transformation retains
  XML/binary source format; strings retain the existing source-encoding/UTF-8
  serialization policy and malformed/no-op failure behavior.
- Path standardization/canonical-or-rootless suffix matching is unchanged. No
  broader plist parser hook, path access, network work, timer or observer is added.
- App-version/build metadata remains distinct from IOSVersion projection. Invalid
  or absent AppVersion fields use native. Main-bundle-only admission and cached
  identity proof remain; binary deployment/SDK metadata uses native whenever the
  original exists. The absence-only physical fallback does not use hooked UIDevice.
- Preserve both CF providers' inner autorelease pools around projection work,
  keeping transient serialization/model objects from accumulating in caller pools.
- CF Copy original calls occur before projection guards/catches; available file
  originals occur before path/projection catches. They are not retried or suppressed
  by an optional provider failure. ObjC/CF Get overrides can intentionally skip
  native on a matching projection; otherwise native runs once.
- Keep Tweak's existing diagnostic dispatch_once and successful log-once claim.
  The diagnostic callback is the inspected C notify helper; it is not replaced
  based on a hypothetical Objective-C reentry assumption. Projection failures
  quietly preserve native. Original exceptions sit outside these catches and
  propagate without being logged/retried there.
- Retire no API or hook. The complete UA policy/sync/adapters, reporting caches,
  three reporting getters, dormant IOSVersion sysctl function, ctor/destructor,
  package/dependency settings and RootHide cold-bootstrap fix are protected.
  Tweak.x changes only one CF provider; every byte/EOL outside it is preserved.

## Native fixture and local verification

New `test_system_version_boundaries.py` extracts the exact seven entry points,
file projection helpers and interner. Provider expressions and the ObjC original
call are adapted for controlled dependencies. Native recipes link the real
PXSystemVersionTransformer.m, PXDeviceProfileSchema.m and the existing
PXSystemVersionTransformerTests.m. Identity, scope, AppVersion and reporting/
physical policy collaborators are facades; this does not prove actual device
provider transport or swizzle behavior.

Four recipes at -O0: rootful/RootHide defines x plain ARC/ARC exception cleanup.
Coverage includes:

- Canonical dictionary/string/data file routes, unknown-key and XML/binary parity,
  NSError output preservation, malformed bytes, generic paths, nil/missing originals,
  scope/off/provider failure and exactly-one native exception propagation.
- Both CF Copy providers, shared provider reentry into a file route, empty-base
  legacy behavior, exception fallback, and weak unknown-object ownership across
  source release/pool drain followed by caller CFRelease.
- ObjC/CF main/foreign bundle admission, app overrides, binary metadata native
  bypass/provider counts, cross-surface reentry, partial AppVersion output failure,
  native exceptions, malformed/missing fields and absent-symbol physical fallback.
- Native borrowed Get output with no extra retain; copied mutable override,
  stable old borrowed pointers after cache replacement, same-value identity,
  throwing/reentrant hash with lock availability, and concurrent cache publications
  preserving every entry. The NSString subclass probe is created directly through
  the ObjC runtime to avoid class-cluster initializer substitution in the fixture.
- Nested/thread-local guard behavior, selected reporting/native-safe policy-fault
  snapshot/profile-identifier release after pool drain, and actual file boundary
  fallback when reporting policy throws. These checks are not proof of every
  Foundation-internal allocation/exception path.

Local Windows results: 68/69 Python suites, 4/4 Node suites. The remaining failure
is the established Keychain retirement Git Bash `mkdir /c/Users/ADMIN` permission
failure (4 failures, 1 error, 1 skip). Source hardening and RootHide metadata/static
checks pass. Exact fragments, CHECK arity, four compile/run recipe captures,
20 negative source controls, protected source/EOL comparisons and diff checks pass.
The C-02/OS metadata source guards now follow the stronger native-forwarding and
ownership transfer structure rather than requiring retired implementation text.

Recipe capture does not execute a compiler or binary. Native Foundation/ARC,
Logos, arm64/arm64e packages and device tests still require macOS CI/hardware.
No measured CPU/latency/memory benchmark is claimed.

## Remaining acceptance

Verify actual Foundation IMP/coordinator chaining and CF ownership on supported
rootful and RootHide devices, including concurrent profile/toggle changes, cold
bootstrap, unscoped/framework bundles, XML/binary file reads, app-version changes
and native failures. The borrowed cache is still unbounded by unique values, cold
insertion copies its current entries and writers can retry under contention.
Cross-provider source authority, arbitrary native partial side effects, path
provenance limits, dormant symbol retirement, movement and profiling remain open.
