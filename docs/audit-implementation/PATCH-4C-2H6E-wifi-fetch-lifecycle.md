# Patch 4C.2H6E — WiFi fetch callback and synthetic network lifecycle

2026-11-01: user confirms the H6D native-build follow-up passes and authorizes
continued implementation. Read the entire WiFiHook.x, constructor/install flow,
MethodSwizzler and H6A–H6D boundaries before selecting this batch. Scope is the
two synthetic-network/fetch functions; the CF fixes confirmed by the user remain.

## Findings and changes

1. **Medium potential / P1 — wrapper lifetime during exceptions.** The function
   held an ARC-strong wrapper and input completion, and the callback held its
   network/preparation references. When original/client throws, default
   Objective-C ARC exception policy need not unwind these strong references.
   An exception could strand a captured consumer even though the callback is
   otherwise one-shot. Explicit `@finally` clears the factory's own inputs/object,
   callback's network/preparation references and fetch's handler/wrapper. Client
   and original exceptions propagate; only fallback preparation exceptions are
   converted to nil. No exception-driven retry or duplicate delivery is added.
   This is a compiler/source risk with injected tests, not an observed device leak.
   [Clang ARC exceptions](https://clang.llvm.org/docs/AutomaticReferenceCounting.html#exceptions)
   describes the default policy. Arbitrary callee-owned references, throwing
   initializers/destructors and allocations that fail before returning a usable
   owner remain outside this explicit caller-reference cleanup guarantee.

2. **Medium potential / P1 — synthetic identity and initialization assumptions.**
   The factory accessed length without checking NSString types, probed an
   allocated but uninitialized instance with respondsToSelector, and retried
   allocation/init after nil/exception. Typed guards now run before class lookup;
   one allocation/init attempt must produce an instance of the resolved class.
   A nil initializer stays nil and a different-class result is rejected. This
   changes only failure/unexpected-result paths deliberately: a failed
   initializer is not retried with duplicate side effects. Current normal profile
   readers already validate SSID/BSSID, so malformed-provider crash risk is
   defensive, not a demonstrated normal source path.

3. **Low confirmed / P2 — unnecessary callback and container work.** A nonnil
   original network needs no fallback, yet the old callback still resolved bundle
   and checked scope. It now forwards that exact object before scope/provider
   work; existing property swizzles still decide spoofing on property reads. Keep
   the entry and callback lexical runtime operations, including around the client
   callback, to preserve RootHide snapshot boundaries. Eight KVC aliases and their
   order are preserved, with fixed string-pointer tables replacing two NSArray
   constructions per synthetic fetch. Each KVC failure remains best effort; no
   unsupported assumptions about direct ivars/setters are introduced.

4. **Low edge case / P2 — nil completion.** The old adapter replaced nil with a
   nonnil wrapper, masking any original validation and doing unused fallback
   work. It now forwards nil to original once without snapshot/scope/provider
   work, or returns if original is absent. This restores original behavior for
   invalid input; it does not promise that Apple's nonnull-handler API accepts nil.

## Behavior, queues and compatibility

Apple documents [fetchCurrent(completionHandler:)](https://developer.apple.com/documentation/networkextension/nehotspotnetwork/fetchcurrent%28completionhandler%3A%29)
as delivering on the main thread, possibly with nil when requirements are unmet.
The wrapper forwards on the original callback thread and does not add a queue,
timer, polling, cancellation object or once gate. A deliberately off-main fake
original verifies forwarding rather than pretending to prove Apple's queue
behavior. Original callback multiplicity is not normalized by this patch.

A nil system result still synthesizes only when delivery-time scope allows and
provider identity is valid; a nonnil original preserves identity. The handler is
retained only by ordinary block ownership while the original retains the wrapper.
A consumer that independently retains a task/owner can still create its own cycle.
Missing-original fallback remains synchronous for compatibility; installer
admission normally prevents this path. It is not a new public API queue promise.

Public NEHotspotNetwork does not document arbitrary synthetic init/KVC contracts.
The existing eight aliases remain attempted even if all are unsupported, and the
initialized object is still returned in that case as before. Host fixtures cannot
prove private field layout, later access to other properties or compatibility on
all iOS releases. No direct ivar memory access or artificial subclass is added.

All source outside these two functions is compared exactly with HEAD: cache,
profile reader, H6B fallback, CF Copy/Get/scan adapters, four property swizzles,
H6C installer, ctor and notification/helper tail remain unchanged. Bootstrap,
RootHide iOS 15.8.8/AIDA64 fix, package/backend dependencies, Makefile and source
writer manifest remain unchanged. Full Patch 4 is partial; marker H5S-partial stays.

## Performance and validation

Expected saving is low per real-network callback (one scope decision avoided),
low per synthetic callback (two array containers avoided), and potentially larger
on nil-handler cold fallback (provider/file work avoided). There is no evidence
of an active high-rate fetch hot path and no latency/CPU benchmark. The wrapper
block and synchronous rootful cold fallback remain. Eight unsupported-key
exceptions may still be expensive; changing those compatibility attempts needs
real-device evidence. Explicit cleanup adds bounded stores/exception regions;
this patch does not claim net performance improvement under every compiler mode.

The existing artifact --native recipe extracts two exact production bodies plus
the original pointer declaration into PXWiFiFetchHooks.inc, linking a Foundation
fixture without a fabricated NetworkExtension implementation claim. Both rootful
and RootHide run at -O0 with and without ARC exception cleanup, alongside the CF
matrix from H6D. The production flags are unchanged.

Cases include identity/type/empty/missing-class guards, one initialization,
nil/different-class initializer, lookup/allocation/KVC faults, eight-key order,
original receiver/selector/identity/count, nil handler, absent original, denied or
malformed provider, original/client exceptions, synthetic and captured-consumer
destruction, deferred delivery with scope revocation, and callback thread
forwarding. Mocks borrow parameters for injected throws so callee parameter
ownership does not contaminate the lifetime oracle. Weak observations are drained
in a separate autorelease pool before owner-release assertions.

Local Windows: 62/63 Python and 4/4 Node regression suites pass. The remaining
Python failure is the existing Keychain-retirement Git Bash mkdir permission
issue. Release source hardening and RootHide metadata/static gates (6/6) pass.
Four native fragment generators pass; the two fetch bodies and seven CF bodies
are extracted exactly. Source preservation outside the two functions, protected
files, macro arity/duplicate-class checks and 12 in-memory boundary/cleanup
negative controls pass. A captured-command recipe check verifies all four fetch
configurations; it is not a native execution result. Targeted source checks and
diff checks are rerun after the final fixture review.

Foundation/Theos/package/device execution is unavailable locally and requires
macOS CI. No H6E native pass, real private object compatibility, device leak-free
claim or runtime latency improvement is asserted on the basis of these checks.
