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

## Native follow-up — network builder argument accessors (2026-11-07)

Baseline 26f28fd. The user log confirms Storage manager cache 57/57 and WiFi
resolver/writer lifetime 109/109 in rootful plain ARC. CI then fails WiFi CF
boundaries at 87/88: the provider/builder/mutable-field lifetime assertion in
TestPreparationLifetime fails once. That loop includes NULL and throwing bridge
outcomes; the old output does not identify which root or iteration survived.
The new diagnostic prints bridge-null/bridge-throw plus provider/SSID/BSSID/builder
weak states without changing the assertion.

The adapter still passed wifiInfo[ssid] and wifiInfo[bssid] directly into
PXCreateSpoofedNetworkInfoDict. Builder finally cleanup covers its own dictionary,
data and parameter roots; adapter cleanup covers its provider root, but neither
owns caller full-expression temporaries from those accessor results. A builder
exception is caught by the adapter, and plain ARC does not guarantee their
abnormal-exit cleanup. This is a concrete remaining boundary consistent with the
failure, not a locally confirmed identification of the runner's exact retained
object or instruction. See the [ARC exception contract](https://clang.llvm.org/docs/AutomaticReferenceCounting.html#exceptions).

The adapter now assigns both fields to named strong locals before the C call and
clears them in its existing finally. Each assignment completes before the builder
can unwind. No copy, normalization or allocation is added for the fields; the
same accessor values are passed once after the same identity guard. Builder body,
CFBridgingRetain, original/provider calls, returned Copy +1 ownership, key aliases,
UTF-8 encoding, fallback catches and PXWiFiReplaceOwnedCopy are unchanged. Cleanup
of caller locals cannot consume the builder's independently retained CF result.

Keep all existing assertions and both failed-retain iterations. Add a caller-level
encoding exception with nonconstant field objects to verify adapter cleanup when
the builder throws before bridging. A successful mutable-field adapter result
must outlive provider-root and named-local cleanup, then release its descendants
only after the caller drops the final CF owner. Weak-load observations are drained
before that release so the test does not retain its own probes. Direct-builder
encoding/ownership tests, the deliberately surviving-owner oracle and Apple/scan/
interface coverage remain. Bridge stand-ins and production fragments are unchanged.

Local source gates now require both named accessor assignments and releases, the
named builder call, every original lifetime predicate and the new caller-level
retained-result/released-result predicates. Ten negative controls remove each of
these boundaries or controls and are rejected. Five fragment generators, exact
CF body extraction, macro arity, four CF rootful/RootHide x plain ARC/ARC-EH recipe
captures, source hardening, RootHide static/package checks (6/6) and diff checks
pass. Full Windows regression: 62/63 Python and 4/4 Node; the remaining Keychain
retirement failure is the established Git Bash permission issue (4 failures,
1 error, 1 skip). Compiler/binary recipes are captured, not executed.

Only replaced_CNCopyCurrentNetworkInfo changes in production. Its original/
provider/builder/replacement calls and other hook text are preserved. Standard
NEHotspot synthesis catches its own preparation exceptions; no broader change to
that caller is inferred from this CF failure. Bootstrap, installation/ABI gates,
constructors, package/Makefile/dependencies, captured runtime authority and the
iOS 15.8.8/AIDA64 fix are untouched. Common hook code applies to both schemes;
rootful is the first matrix entry, not evidence of a rootful-only defect. The
scope is retained-reference cleanup, without a benchmark or claim of full source
consistency. macOS CI must rerun the reported 87/88 failure; no native pass for
this fix is claimed on Windows.
