# Patch 4C.2H6C — WiFi runtime hook admission and swizzle ownership

2026-10-31: user confirms H6B build passes and authorizes continued implementation.
This batch covers MethodSwizzler and WiFi installation. All current production
callers of MethodSwizzler were inspected: four NEHotspotNetwork instance getters
in initializeHooks. Its class-method API had no production caller found. The
complete WiFiHook flow was read in H6A; H6B resolver/cache/read bodies are unchanged.

## Findings and changes

1. **High potential / P1 — incomplete ABI check.** The old swizzler compared
   return type and number of arguments, then admitted every argument shape. An
   object argument and a double argument could pass despite different calling
   conventions. The API flaw is confirmed; the four current production callers
   are getters without explicit arguments, so this is not a claimed observed
   device crash from those callers. Add PXMethodHasCompatibleTypeEncoding to
   compare return and every argument through NSMethodSignature, excluding frame
   offsets. Strip top-level qualifiers, accept ordinary object class annotations,
   keep blocks distinct from objects, and conservatively compare other shapes
   exactly. Reject missing/empty encodings and signatures without self/_cmd.
   Apply the same gate to private WiFi installation. Reproducer: @@:@ versus
   @@:d must be rejected despite matching return/count. See MethodSwizzler.m.

2. **High potential / P1 — inherited alias mutated its superclass.** When the
   original method was local but the replacement alias was inherited, the old
   class_addMethod(original) failed because it already existed; the fallback
   exchange then modified the superclass's alias Method. That could affect
   unrelated instances/siblings and break the alias's original-call route.
   Localize both selectors before exchanging target-local methods. The class
   method path uses the same implementation on the metaclass. Reproducer: parent
   defines alias, child overrides original, then swizzle child; parent and sibling
   implementations must remain unchanged. This is a confirmed utility API bug;
   the existing four category getter aliases are normally local, so real-device
   occurrence for this inheritance layout remains unproven.

3. **Medium / P1 — duplicate exchange undid installation.** A second call with
   the same pair exchanged the methods back. Concurrent requests were also
   unserialized. Add a shared installation monitor and process-lifetime records;
   exact and reversed requests do not toggle installed hooks. No repeated call
   from the current one-shot WiFi ctor was found, so this is defensive API
   correctness rather than a claimed production repeat-init regression.

   Reusing the same alias at multiple hierarchy levels can recurse when a child
   original calls super and the parent wrapper dispatches self.alias again.
   Admit one owner per selector pair/hierarchy, in either registration order.
   Siblings may install independently; instance/metaclass pairs remain distinct.
   A subclass override is not automatically hooked by a skipped second request;
   inherited methods still receive the parent hook. The utility is now explicitly
   installation-only, not an unswizzle or multi-level composition API. Current
   production's four distinct pairs on one class fit this policy.

4. **High potential / P1 — optional private selectors lacked ABI admission.**
   NWPath _getSSID/_getBSSID previously entered the default Logos group without
   checking existence/signature. Split them into independent named groups and
   initialize each only for an existing object-returning zero-explicit-argument
   method. NEHotspotHelper dictionaryWithScanResult now requires object result
   and object argument; NEHotspotNetwork fetchCurrent requires void result and
   a block argument. Missing classes/methods or incompatible ABI skip safely.
   No iOS version is asserted to have a particular private signature. The scan
   class hook now uses the already-supported, availability-checked MSHookMessageEx
   path instead of directly replacing a possibly inherited Method. Host tests
   validate the gate; actual Logos/Substrate/ElleKit installation needs CI/device
   evidence. Scope admission still precedes all installation.

5. **Low / P2 — ten unnecessary interceptions.** Remove pass-through MobileWiFi
   WiFiManagerClientCreate and WiFiDeviceClientCopyCurrentNetwork hooks; six NWPath
   methods (usesInterfaceType, quality, latency, isExpensive, isConstrained,
   gatherDiagnostics); and NWPathMonitor currentPath/setPathUpdateHandler hooks.
   The latter setter only created a block that immediately called the supplied
   handler, without changing path, queue or delivery. Removing it avoids that
   retained wrapper/capture and callback layer and lets the original setter
   retain the caller's handler directly. It does not fix a handler that itself
   retains its monitor. Delete unused associated function pointers/types and
   compatibility declarations. No fake WiFi values or connectivity policy change.

## Compatibility, concurrency and lifecycle limits

The shared monitor serializes this utility's installations, not third-party
swizzles. Runtime mutations from other libraries and future method replacement
are outside its ordering contract. Admission checks a structural signature;
it does not prove private API semantics, ownership conventions, variadic behavior
or compatibility with every iOS release. Complex shapes/pointer pointee types are
compared conservatively; two machine-compatible but differently encoded types
may be rejected. Class/selector additions after ctor are not watched or polled.

Installation records are small C nodes allocated before runtime mutation and
retained intentionally for the process; the current production call graph has
four pairs. Failed admission frees an uninstalled node. Registered classes must
remain alive: arbitrary objc_disposeClassPair/plugin unloading is unsupported.
If localizing the second selector fails after the first succeeds, no exchange
occurs; an unexchanged local copy may remain because Objective-C has no symmetric
method-removal API. This is not a transactional class-metadata rollback protocol.

The H6A cache region, full profile WiFi reader (including RootHide captured view),
SSID/BSSID/signal/secure replacement bodies, ctor prefix through initializeHooks,
and subsequent observer/helper tail are compared with HEAD and unchanged.
Only explicit optional Logos group admission replaces the old default %init.
The synchronous bootstrap/scope behavior and the iOS 15.8.8/AIDA64 RootHide fix
remain intact. H6B source resolver and all source writer enrollment are unchanged.
No queue, timer, notification topic, polling or package/backend dependency is added.

MobileWiFi Get-string ownership, Apple80211 result handling, manager mutable-cache
concurrency, source/reader ordering and synchronous cold fallback latency remain
separate work. This batch does not claim those CF/private paths are validated.
Full Patch 4 remains partial and the H5S-partial rollout marker is unchanged.

## Performance

ABI parsing, method-list localization, synchronization and the small installation
registry add cold initialization cost, expected low for the fixed four swizzle
pairs and four optional ABI checks. No registry lookup, signature parsing or
new allocation is placed in the WiFi getter/callback hot path. Removed forwarding
hooks save a dispatch/call layer per use; the path-handler setter also avoids its
extra wrapper. Expected saving is negligible-to-low per getter and low per
handler setup, with cumulative impact depending on actual application frequency.
There is no device benchmark or unsupported calls-per-second estimate.

## Validation

The existing artifact-preparation --native recipe now builds the real
MethodSwizzler.m with PXMethodSwizzlerTests.m for rootful and RootHide. Tests cover
frame offsets/qualifiers/object annotations, full argument ABI, object/block and
struct/pointer distinctions, missing inputs, local/inherited original/alias
combinations, unaffected parent/sibling dispatch, duplicate/reversed calls,
parent/child installation order with a real super call, class methods, separate
instance/metaclass ownership and 64 concurrent duplicate requests. Synthetic
incompatible signatures are inspected only as metadata; they are never invoked.
The fixture also verifies that a rejected object-versus-double argument pair
retains its correctly typed original implementation.

Local Windows: 62/63 Python and 4/4 Node gates pass. The remaining Python failure
is the known bridge-retirement Git Bash mkdir permission issue. Source hardening,
RootHide metadata/static gates, four native fragment generators, exact preservation
checks, CHECK arity/duplicate-class checks, Logos group balance and 14 in-memory
ABI/install/retirement negative controls pass. Foundation/Theos/package/device
execution is unavailable locally; H6C requires the next macOS CI/device run.
