# UIKit/WebKit injection and bootstrap policy

TLinkIOS uses broad loading with explicit runtime capabilities. `com.apple.UIKit`
only makes a process eligible for dylib loading; it grants no spoofing permission.
The full dylib and linked frameworks are still mapped before a constructor can
return. This implementation does not claim zero loading cost in unrelated apps.

## Filter pipeline

`common/PXInjectionFilter.m` is shared by the app writer and mount daemon.
With at least one real scoped app/extension, the canonical tweak filter contains:

- Exact scoped app and discovered extension bundle IDs.
- `com.apple.UIKit` and `com.apple.springboard`.
- `com.apple.WebKit.WebContent`, `com.apple.WebKit.Networking`,
  `com.apple.WebKit.GPU`, and `com.apple.SafariViewService`.

Empty scope remains placeholder-only. Coverage targets, self bundles and legacy
placeholders do not count as real scope anchors. Canonicalizing an already
expanded filter is idempotent. The daemon now canonicalizes both staged filters;
the Keychain Bridge remains restricted to third-party app/extensions. Alternate
`Executables`/`Classes` filter keys are rejected rather than silently widening it.
The checked-in package plist intentionally remains placeholder-only until scope
selection generates the runtime filter.

`UberURLHooks.x` is retired and excluded from the build; its source is untouched.

## Runtime capabilities

`PXBootstrapDecisionForCurrentProcess()` captures original process identity once,
then evaluates a live immutable scope snapshot using `common/PXBootstrapPolicy.h`.
The result includes role, capabilities, denial reason and scope generation.
All 27 remaining explicit hook constructors in source (including the optional
research constructor) enter this gate before module setup, logging or scheduling.
There is one additional debug-only early load marker, guarded by explicit files.
The old unconditional PXScope constructor is replaced by lazy scope observers.

| Process | Allowed capabilities when its owner is scoped and master is on |
| --- | --- |
| Main app | Native, WebContent, WebNetworking, WebGraphics, Telephony server identity |
| Extension | Native, WebContent, WebNetworking, WebGraphics |
| WebContent | WebContent, WebGraphics |
| Networking | WebNetworking |
| GPU | WebGraphics |
| SafariViewService | WebContent, WebNetworking |
| SpringBoard | Freeze/Profile Indicator only, independent of spoofing toggles |
| Unknown helper/system daemon/unscoped app | None |

WebKit helper capabilities also require the Safari-stack toggle. Enabling that
toggle or full-spoof test mode does not implicitly scope Safari or another app.
An extension inherits only an actual enclosing `.app/PlugIns/*.appex` owner's
scope; an explicit disabled extension entry takes precedence. A bundle prefix or
process-name substring is not ownership evidence.

Canvas's WKWebView construction/document-start script hooks stay in the app and
SafariViewService. iOS version/UA hooks can run in WebContent and Networking;
locale/timezone in WebContent; domain blocking in Networking; Metal identity in
WebContent/GPU. Native UUID/dyld, ObjC runtime guards, private identity wrappers,
DeviceSpec, storage, Wi-Fi and pasteboard hooks remain excluded from helpers.
Tweak.x's monolithic native constructor does not run in any WebKit helper.
Capabilities allow installation; existing feature toggles and profile-backed
value checks remain additional requirements.
The Telephony capability gates `CoreTelephonyServerIdentityHooks`; existing
app/extension network-information hooks remain in the Native capability.

## Host evidence and lifecycle

WebKit host resolution reads `MCMMetadataIdentifier` only from captured HOME
candidates resolving under an application data-container directory. Missing or
conflicting readable metadata denies access. Names of known helpers are matched
exactly; unknown WebKit variants have no capability policy and are denied.
This is container evidence, not an IPC/audit-token ownership proof. It must be
validated separately for each helper kind and supported iOS/loader version.

Host evidence is cached for at most one second and tied to scope generation;
negative results are retryable. Scope predicates fail closed on recursive entry,
including direct snapshot/setting getters during preference reads. Hook callers
re-evaluate scope through the central decision; no cached YES permanently grants
permission. Missing/new identity or settings after a constructor has returned do
not automatically install hooks: restart the app/helper after changing scope,
profile, master toggles, or host availability. Existing JS documents and
process-global changes likewise require restart for a deterministic transition.

SpringBoard's capability is independent of spoofing. The existing empty-scope
filter behavior is preserved: a fresh SpringBoard is not injected when the filter
is placeholder-only. This change does not redesign Freeze's injection lifecycle.

## Verification and on-device acceptance

Local portable production-policy tests:

```sh
python scripts/test_bootstrap_policy.py
python scripts/test_bootstrap_topology.py
python scripts/test_webkit_unscoped_zero_interference.py
python scripts/release_hardening.py regression --iterations 2
```

macOS CI additionally compiles/runs `PXBootstrapScopeTests.m` against the actual
PXScope adapter and `PXInjectionFilterTests.m` against the actual shared filter
implementation, then builds the iOS package. Static checks and the C capability
matrix do not prove dylib load safety, host attribution, or WebKit hook coverage
on a device.

Compare the previous scoped-filter build against this build with identical
profile, Freeze state and debug settings. Restart target apps/helpers between
runs and respring after filter changes. Test scoped and unscoped apps running
concurrently, explicit extension disable, Safari not in scope, unresolved helper
host, empty scope, and disabled spoofing master. Check actual API/JS outputs as
well as installed hooks; merely seeing the dylib in a process is not coverage.
Measure startup latency, memory, helper crashes/restarts and cross-app identity
leakage. Test iPhone/iPad and each supported iOS/loader combination before release.
AIDA64's earlier Freeze failure is not treated as proof for or against load safety.

Optional diagnostics, disabled by default:

```sh
touch /tmp/px_debug_scope
touch /tmp/px_debug_webkit
cat /var/mobile/Library/TLinkIOS/scope_decision.log
cat /tmp/tlinkios_loads.log
cat /var/mobile/Library/TLinkIOS/filter_daemon_debug.plist
cat /Library/MobileSubstrate/DynamicLibraries/TLinkIOSTweak.plist
cat /Library/MobileSubstrate/DynamicLibraries/WeaponXKeychainBridge.plist
```

`[PXBootstrap]` logs role/capability/reason changes, with numeric definitions in
`PXBootstrapPolicy.h`. The early marker proves loading even when all module gates
deny. `[PXScopeDecision]` logs the resolved WebKit host for allowed module paths.
Rootless installations may use `/var/jb/Library/MobileSubstrate/DynamicLibraries`.
Disable marker files for performance measurements; do not leave verbose logging
on. Roll back by installing the previous matching app/daemon/tweak build and
regenerating filters, then restart affected processes; editing the installed
plist alone is overwritten by daemon canonicalization.
