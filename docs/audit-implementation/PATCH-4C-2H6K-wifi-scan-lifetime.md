# Patch 4C.2H6K — WiFi scan adapter lifetime and dead-code cleanup

2026-11-06: user confirms H6J build passes and authorizes continuation. Read the
complete WiFi hook, current resolver, manager/caller boundary, build flags and
existing CF/scan native fixture. This batch changes the registered private scan
adapter, removes file-local dead code and updates the corresponding source gates.
The cold resolver itself remains unchanged.

## Findings and changes

1. **Medium potential / P1 — retained scan preparation survives a caught exception.**
   TLinkIOSTweak/WiFiHook.x, replaced_dictionaryWithScanResult: near line 411.
   The old implementation declared wifi, standard, kind and modified inside the
   preparation try block. An exception during standard classification or after a
   dictionary mutation could skip normal strong-local cleanup while the catch
   returned the original result and let the app continue. A partial dictionary
   can retain original descendants and spoof data across repeated failures.

   ARC cleanup on abnormal Objective-C scope exit requires the relevant compiler
   option; Objective-C++ has different defaults. The Makefile specifies ARC and
   Objective-C exceptions without explicitly selecting ARC exception cleanup.
   See [Clang ARC exception rules](https://clang.llvm.org/docs/AutomaticReferenceCounting.html#exceptions).
   The exact effective iOS compiler invocation and device occurrence still need
   CI/device evidence; no leak size/frequency is asserted.

   Hoist adapter-owned references and clear them in finally. Keep the original
   call outside the preparation catch, inside the cleanup region. This also
   releases this C adapter's strong receiver/input parameters if the original
   throws, without swallowing/retrying that exception. Returned original/copy
   values retain their normal return ownership before local cleanup.

   Reproduce in the native fixture by throwing from containsString:, or after
   mutation one/two/three of a controlled mutable-copy stand-in. After the returned
   original and test globals release and the pool drains, the copy and original/
   WiFi roots must be gone. A throwing original checks receiver/input weak refs,
   exactly one original invocation, and no preparation. Test callees borrow their
   own parameters so their artificial exceptions do not manufacture unrelated
   callee-owned leaks.

2. **Low potential / P2 — unusable copy can discard a valid original result.**
   Same function, mutable-copy result. Sending writes to nil is a no-op, so a nil
   result from a custom copy implementation could reach return modified and hide
   the original dictionary. An unexpected nonmutable result instead relied on an
   exception for recovery. Guard the result as NSMutableDictionary before writing;
   keep original identity on nil/wrong-type results. Foundation dictionaries
   normally supply a mutable dictionary here; allocation-failure recovery or
   hostile object safety is not claimed. The fixture injects nil and an array.

3. **Low code smell / P2 — unused scope helpers and unrelated private declarations.**
   Original WiFiHook.x lines 34/50 and 862/868: two URLSessionTask*Metrics interface
   declarations had no references; isInScopedAppsList was uncalled and its sole
   loadScopedApps caller chain was dead. Both functions were static, with no
   escaping addresses or external callers. Remove their bodies/prototypes and
   the unrelated declarations. Keep getCurrentBundleID, which the ctor uses.
   These were not active scope-policy bugs or proven CPU costs.

   The old P3 WiFi gate passed by finding PXScopedAppsSnapshot in that dead helper.
   Replace it with a check of the actual shouldSpoofForBundle call into
   PXProcessIsAllowedForSpoofing and that centralized predicate's snapshot read.
   The live predicate and its behavior are unchanged.

## Behavior, performance and remaining scope

Original calls remain exactly once when available; missing original still returns
nil. Denied, non-dictionary, unavailable/malformed/throwing WiFi input and already
matching scan values retain the original result. Matching output makes no mutable
copy; changed output makes at most one. The ax > ac > n mapping, unknown-standard
preservation, original extras and original immutability remain unchanged. Only
spoof preparation is caught; original exceptions propagate. No partial modified
result escapes after a failed mutation.

Cleanup covers adapter-owned slots, not retains leaked inside foreign throwing
callees or throwing destructors. It does not make concurrently mutable provider
objects coherent, change original/private API contracts, or cover all WiFi
helpers' exception ownership. PX_RUNTIME_READ_OPERATION remains at the same
lexical function entry; exceptional failure of that entry itself is outside this
new cleanup region. No new global ARC flags are enabled.

Expected normal-path cost is low: explicit reference stores and one mutable-result
type check only when a change requires a copy. There is no new file/IPC/network
work, class lookup, timer, queue, lock or polling. Actual scan call frequency,
exception rate, retained bytes, code-size and latency effects are unmeasured.
Removing dead functions/declarations is a maintenance change; compiler dead-code
elimination may already remove the functions, so no runtime speedup is claimed.

The rest of WiFiHook.x is compared exactly with HEAD after accounting for the
single adapter and identified dead sections. Cache/readers/CF/fetch/getter bodies,
constructor, private ABI admission, hook installation and all observers remain
unchanged. H6J/common source, RootHide captured projection and the iOS 15.8.8/AIDA64
bootstrap fix, Makefile, package dependencies and writer manifest are untouched.
Both schemes compile this shared hook; actual private-selector availability and
hits still require device evidence. Full Patch 4 and H5S-partial remain partial.

## Patch outline

```objc
@try {
    original = orig_dictionaryWithScanResult ? orig_dictionaryWithScanResult(self, _cmd, arg1) : nil;
    @try {
        // Existing scope/data/equality checks, then one copy and type guard.
        return modified;
    } @catch (__unused NSException *exception) { return original; }
} @finally {
    modified = nil; kind = nil; standard = nil; wifi = nil; bundleID = nil;
    original = nil; arg1 = nil; self = nil;
}
```

## Verification

- Windows regression: 62/63 Python and 4/4 Node suites passed. The remaining
  test_keychain_bridge_retirement.py suite is the known Git Bash mkdir
  /c/Users/ADMIN permission failure (4 failures, 1 error, 1 skip), unchanged.
- Artifact source contracts, P3 82/82, Phase-10 source hardening, RootHide build
  static contracts and RootHide metadata/negative controls 6/6 passed.
- All four affected fragment generators completed. The CF fixture includes each
  of its seven exact source bodies once, including the revised scan adapter.
- Ten in-memory negative source controls reject swallowed original exceptions,
  a duplicate original call, missing partial-copy/standard/input cleanup,
  missing copy-result guard, eager copy, a restored dead scope helper, a strong
  throwing original mock, and bypass of the active WiFi scope predicate.
- Captured recipe inspection retains rootful/RootHide x ARC exception cleanup
  enabled/disabled at -O0 for the CF/scan fixture. No compiler/binary command was
  executed. New cases cover partial mutation/lifetime, standard-accessor failure,
  original propagation/input lifetime, nil/wrong-type copy and original shapes.
- Exact preservation outside the admitted hook/dead-code regions and
  git diff --check passed.

Foundation/xcrun/Logos/Theos and device execution are unavailable on this Windows
host. New native lifetime assertions, package builds and device behavior require
macOS CI/device verification. No new native/build/device pass, measured speedup,
commit, push or deployment is claimed.
