# Patch 4C.2H6N — WiFi CF preparation lifetime

2026-11-06: user confirms H6M build passes and authorizes continuation. Read the
remaining Copy adapters/builder, their caller/ownership boundary, build contracts
and CF fixture. This batch changes three bodies in WiFiHook.x only. H6D's CF
replacement ownership helper and H6M's cache/reader remain unchanged.

## Findings and changes

1. **Medium potential / P1 — network builder retains preparation on unwind.**
   TLinkIOSTweak/WiFiHook.x, PXCreateSpoofedNetworkInfoDict. The builder's mutable
   dictionary, encoded data and strong C string parameters relied on normal ARC
   scope cleanup. If encoding or an injected retain collaborator throws, its
   caller catches preparation failure, but these references need not be released
   without ARC exception cleanup. A partially populated dictionary also retains
   the input fields through several aliases.

   Name the dictionary/data before try and clear them plus both C parameters in
   finally. Keep the existing guards, encoding, key aliases and CFBridgingRetain
   return. No catch is added to the builder: direct encoding exceptions still
   propagate to its caller. A successful returned CF retain survives clearing the
   builder's local Objective-C references.

2. **Medium potential / P1 — network Copy adapter retains provider root after
   recovering from preparation failure.** Same file,
   replaced_CNCopyCurrentNetworkInfo. bundleID and wifiInfo were strong locals
   inside the try whose abnormal exit was caught. Hoist/clear them in finally.
   This complements builder cleanup: releasing just the builder dictionary does
   not release an independent provider-root retain in its caller.

   The fixture injects bridge NULL and bridge throw with a mutable provider root
   and mutable fields. It releases caller/global ownership, drains the pool, then
   checks provider, builder and field weak references. A separate encoding fault
   checks the builder's parameter/dictionary cleanup; a successful direct build
   checks CF ownership remains valid until caller release.

3. **Low defensive ownership / P2 — interface synthesis uses an unnamed array.**
   replaced_CNCopySupportedInterfaces passed its array literal directly into the
   bridge expression, and its bundle local was scoped inside preparation try.
   Bind the existing array to a named NSArray slot and clear array/bundle in
   finally. This makes the caller's preparation ownership explicit on all exits;
   it is not a claim that a particular compiler leaked the old literal or that
   production CF retain normally throws. There is still one array per synthesis,
   with the same en0 value; no process-global cached array is introduced.

Plain Objective-C ARC does not provide all normal releases on exception unwind
without the relevant option; Objective-C++ defaults differ. See
[Clang ARC exception rules](https://clang.llvm.org/docs/AutomaticReferenceCounting.html#exceptions).
These are defensive exceptional-exit fixes. No device incident, ordinary
Foundation/CF retain failure, normal-path leak rate or retained-byte measurement
is asserted. Fault injection tests the adapters' recovery contract, not the
likelihood of a platform API throwing.

## Preserved behavior and limits

Original network/interface functions remain outside preparation catches and run
once when available. Original exceptions propagate, without scope/preparation
retry. Missing original behavior and scoped synthesis are unchanged. Nonempty or
unexpected valid CF interface output still bypasses scope/synthesis work and keeps
original order/identity. Denied or throwing scope and unavailable/preparation
failure retain the original owned result. Failed retain does not consume it.

PXWiFiReplaceOwnedCopy remains the sole ownership-consumption step, after
preparation catches/cleanup. Its replacement/original release rules and release
exception propagation are unchanged. Copy results still supply a CF +1 retain
for the caller. Network key aliases, UTF-8 data, empty-string validation, original
fallback, en0 synthesis and per-call allocation policy remain unchanged. No new
validation, notification, retry, I/O, lock, class lookup, queue, timer or polling.

Cleanup covers named adapter-owned references. It does not release unknown
ownership acquired inside a foreign callee before that callee throws, cover every
compiler-generated temporary, make mutable input coherent, or support throwing
foreign destructors. Test retain callbacks borrow CF pointers and fail before
retaining; tests do not imply recovery of an unknowable partially completed CF
transfer. Weak destruction assertions use the mutable dictionary/input graphs;
no assumption about immutable array interning/lifetime is used.

All other WiFiHook.x source reconstructs HEAD unchanged after restoring the three
bodies: cache/reader, scan/fetch/getters, Apple output adapter, scope, constructor,
ABI admission, installation and observers. Common manager/resolver/writers,
Makefile, package dependencies and manifest are untouched. Both rootful and
RootHide compile these adapters and retain their existing data authority, including
the captured RootHide path and iOS 15.8.8/AIDA64 bootstrap fix. Full Patch 4 and
H5S-partial remain partial.

## Performance and verification

Expected normal-path added cost is low: named reference stores and unwind regions.
Dictionary, data and array allocation counts are unchanged; no benchmarked CPU,
latency, I/O, allocation reduction or code-size improvement is claimed. Benefit
is bounded ownership when a recoverable preparation error occurs; frequency and
real retained graph sizes are unmeasured.

- Windows regression: 62/63 Python + 4/4 Node suites passed. The remaining
  test_keychain_bridge_retirement.py suite is the existing Git Bash
  mkdir /c/Users/ADMIN permission failure (4 failures, 1 error, 1 skip).
- Artifact source contracts, Phase-10 source hardening, RootHide static build and
  RootHide metadata/negative controls 6/6 passed.
- Four fragment generators completed. All seven CF fixture bodies are extracted
  exactly once. Restoring only the three changed bodies reconstructs HEAD;
  policy-literal multisets and counts of original/provider/scope/bridge/ownership
  calls match the previous implementations.
- Six in-memory source negative controls reject omitted builder/network/interface
  cleanup, an unnamed interface literal, original moved inside preparation catch,
  and early original release outside the ownership helper.
- Existing CF recipe retains rootful/RootHide x ARC exception cleanup enabled/
  disabled at -O0. Captured commands confirm all four variants; no compiler or
  binary command was executed. New cases cover encoding/bridge failure, weak
  graph lifetime, direct CF return ownership and interface original/scope failure.
- Existing Apple output, scan, release-reentry and CF owner oracle cases remain.
  git diff --check passed.

Foundation/xcrun/Logos/Theos and a device are unavailable on this Windows host.
New native assertions, package builds and device behavior require macOS CI/device
verification. No new native/build/device pass, commit, push or deployment is claimed.
