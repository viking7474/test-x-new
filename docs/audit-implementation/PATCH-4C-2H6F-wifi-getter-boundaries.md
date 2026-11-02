# Patch 4C.2H6F — WiFi synchronous getter boundaries

2026-11-01: user confirms H6E build passes and authorizes continued implementation.
This batch covers four NEHotspotNetwork property replacements, two MobileWiFi
Get adapters and two optional NWPath getters. The manager implementation/callers,
CF coordinator forwarding, installer/ctor and H6A–H6E boundaries were reviewed.
No manager writer or CF Copy/fetch lifecycle rewrite is included.

## Findings and changes

1. **Medium potential / P1 — unguarded field assumptions at getter boundaries.**
   Six string getters directly subscripted the provider result and accepted any
   nonnil field. Objective-C callers could receive an unexpected object; the two
   C adapters cast that object to CFStringRef before CFStringCreateCopy. The shared
   preparation helper now admits a dictionary root and an NSString field before
   returning it. A malformed/missing requested field uses original, once, while
   a valid other field remains independently usable. Existing normal readers
   already type-check identity pairs; no ordinary valid-artifact crash is claimed.
   The native fixture injects malformed roots and fields to exercise the boundary.

   Empty strings, case, Unicode, string object identity and spelling are preserved.
   No length, MAC-format, pair-validity or normalization policy is added. The
   private NWPath BSSID original remains opaque id: its fallback output is never
   revalidated or converted into NSString by this patch.

2. **Medium potential / P1 — preparation exceptions escape ordinary getters.**
   Scope/bundle/provider/type-check exceptions previously escaped these getters.
   PXWiFiGetterAllowed and PXWiFiGetterString catch preparation failure only,
   return unavailable and let the hook call original. All original calls remain
   outside any catch, preserving original exceptions and preventing retries.
   Signal and secure use only the scope helper: they still never resolve WiFi data.
   Signal keeps the double ABI, one random draw and discrete 0.70...0.89 range;
   secure still returns YES when admitted and original BOOL otherwise.

3. **Medium potential / P1 — owned references on exceptional preparation exits.**
   Explicit finally stores clear this code's bundle, dictionary and selected-field
   references. C adapters also clear their own string reference if Copy raises.
   This avoids relying on automatic strong-local unwind cleanup in Objective-C
   builds without -fobjc-arc-exceptions. See [Clang ARC exceptions](https://clang.llvm.org/docs/AutomaticReferenceCounting.html#exceptions).
   Injected lifetime probes distinguish root/field checks and a throwing Copy.
   This does not prove exception safety of foreign providers, custom collection
   implementations, original methods or private CF callees.

4. **Low confirmed / P2 — duplicate lookup and repeated preparation logic.**
   The six field getters looked up the same field once as a condition and again
   for the result. One typed field observation replaces the pair; scope and field
   preparation are shared. No lock, map, timer, queue, log, class lookup, selector
   lookup or extra runtime-snapshot acquisition is added to getter bodies. The
   extra helper call, type checks, strong stores and exception regions have small
   expected cost; no net CPU/latency improvement is asserted without profiling.
   Actual hook frequency is unknown, so this is not described as a measured hot
   path optimization. Existing synchronous cold provider I/O remains unchanged.

## Ownership, threading and compatibility limits

The two MobileWiFi spoof adapters still return CFStringCreateCopy results with
this tweak's existing +1 convention. Original pointers are passed through without
retain/release; a NULL original is safe. Copy NULL still returns NULL rather than
retrying original; Copy exceptions propagate. The host fixture releases only its
known +1 spoof results and never consumes its borrowed original constants.

Apple's [CF ownership policy](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFMemoryMgmt/Concepts/Ownership.html)
distinguishes Create/Copy and Get ownership. It does not establish the ownership
contract of these particular private functions across devices. The H6D private
Get risk remains open: +1 may leak for +0 consumers; returning a borrowed pointer
without a lifetime contract can instead cause use-after-free. No cached borrowed
CF pointer or return-convention change is introduced here.

Each of the eight getters retains its existing lexical PX_RUNTIME_READ_OPERATION.
Helpers run inside that operation rather than opening another one. H6C admission,
method encodings, swizzle aliases, installer and RootHide cold bootstrap are
unchanged. No thread hop or synchronization protocol is added. Type checking and
catching exceptions do not make concurrent mutation/torn ownership safe, validate
wild pointers or prove a private API's ABI/semantics. Entry snapshot acquisition
is not moved under a catch; its failure is outside getter preparation recovery.
The manager's nonatomic
cache pair, stale-load/adoption ordering and external mutation remain separate
work; those issues must not be reported as fixed by this boundary patch.

All source outside the two new helpers and eight replacements is compared exactly
with HEAD: cache/reader, H6B owned fallback, H6D CF Copy/scan adapters, H6E synthetic
factory/fetch, ctor/notifications and install code remain unchanged. Common
WiFiManager, MethodSwizzler, Makefile, package dependencies and writer manifest
are unchanged. Full Patch 4 remains partial; H5S-partial marker is preserved.

## Verification

The existing artifact --native recipe adds a Foundation/CoreFoundation fixture
linked with the real MethodSwizzler.m for rootful and RootHide, each at -O0 with
and without ARC exception cleanup. It compiles two exact helpers, four exact
category methods and two exact C bodies/original pointer declarations. Two exact
NWPath bodies replace only %orig with typed fixture calls. Host classes exercise
runtime exchange and dispatch without claiming to reproduce NetworkExtension or
MobileWiFi internals; the actual Logos/iOS build remains a separate CI check.

Cases cover valid/unavailable/malformed roots and fields, independent values,
empty strings/Unicode/case/mutable field identity, denied/scoped scalar ABI and
random endpoints, nested original-to-hook calls, missing originals, opaque
argument/pointer forwarding, Copy NULL/throw, original exceptions on all eight
surfaces and root/field/string reference lifetime. Throwing mock functions borrow
inputs to avoid hidden mock-owned strong references. Lifetime assertions run
after an autorelease pool drains, with sources retired to remove other owners.

Local Windows: 62/63 Python and 4/4 Node regression suites pass. The remaining
Python suite is the known Keychain-retirement Git Bash mkdir permission failure.
Release source hardening and RootHide metadata/static gates (6/6), four native
fragment generators, exact helper/method/CF/Logos-body extraction, CHECK arity and
duplicate-class checks pass. Preservation of all regions outside the two helpers
and eight getters, protected files and 12 in-memory type/policy/ownership negative
controls pass. A captured-command recipe check confirms all four getter builds
link the real swizzler; it is not a compiler/runtime test. Final targeted source
contracts and git diff checks pass after lifetime/diagnostic review.

Foundation native execution, Logos/Theos builds, packages and device behavior
are unavailable locally and remain for macOS CI/device verification. No H6F
native pass, measured performance gain or complete private ownership/thread
safety is claimed from source checks or the user's H6E build confirmation.
