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

### Current accepted baseline

The current production policy is the broad filter described above: when at least
one real app/extension is scoped, `TLinkIOSTweak.plist` contains the scoped
app/extensions plus SpringBoard, UIKit, SafariViewService and the WebKit helper
cluster. This configuration has been exercised on-device across multiple apps and
is the accepted stable baseline. Do not narrow the filter or introduce an A/B
coverage variant merely as routine verification when the build is behaving
normally.

The current source does **not** implement runtime selector files named
`enable_webkit_filter` or `enable_uikit_filter`. Creating or deleting such files
does not select narrow/WebKit/UIKit stages. `PXInjectionComputeTweakBundles()` and
the daemon canonicalizer intentionally reconstruct the current broad policy for
every non-empty real scope. Any future staged selector must be implemented and
tested in both the app writer and daemon before it is used as an experiment.

Local portable production-policy tests remain useful before packaging:

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

### Regression-only diagnostic runbook

Return to this section only when a new launch hang, crash, cross-app identity leak,
missing spoof surface, unexpected helper behavior, or measurable startup/memory
regression appears. First reproduce the problem on the unchanged broad baseline.
Keep profile, Freeze state, selected scope, feature toggles and test steps fixed so
only the suspected injection/loading variable changes.

Before changing code or filters, capture the actual pipeline on the affected
device:

```sh
cat /var/mobile/Library/TLinkIOS/filter_plists/TLinkIOSTweak.plist
cat /Library/MobileSubstrate/DynamicLibraries/TLinkIOSTweak.plist
cat /var/mobile/Library/TLinkIOS/filter_daemon_debug.plist
```

Rootless installations may use:

```sh
cat /var/jb/Library/MobileSubstrate/DynamicLibraries/TLinkIOSTweak.plist
```

For the current broad baseline, a non-empty real scope is expected to contain the
scoped app/extensions together with:

```text
com.apple.springboard
com.apple.UIKit
com.apple.SafariViewService
com.apple.WebKit.WebContent
com.apple.WebKit.Networking
com.apple.WebKit.GPU
```

`STAGING == INSTALLED` for the bundle list means the daemon installed the policy it
received. If they differ, debug the writer/daemon pipeline before drawing any
conclusion about hook behavior. Do not edit only the installed plist: daemon
canonicalization will overwrite non-canonical changes.

Enable load/scope diagnostics only while reproducing the regression by creating
`/tmp/px_debug_scope` and `/tmp/px_debug_webkit`, then clear any previous
`tlinkios_loads.log` and `tlinkios_scope_debug.log` before the run.

Restart the affected app/helper (and respring after an actual filter change),
reproduce the exact failure, and collect:

```sh
cat /tmp/tlinkios_loads.log
cat /tmp/tlinkios_scope_debug.log
cat /var/mobile/Library/TLinkIOS/scope_decision.log
```

`[PXBootstrap]` records role/capability/reason changes using the numeric definitions
in `PXBootstrapPolicy.h`. The early load marker proves that the dylib reached a
process even when all module gates deny. `[PXScopeDecision]` records the resolved
WebKit host for module paths that evaluate scope. Interpret evidence in this order:

```text
no load marker                  -> loader/filter/process-lifecycle problem
load marker + denied decision   -> bootstrap/scope/host-attribution decision
allowed decision + no spoof     -> hook/API/feature-toggle problem
unscoped host + allowed work    -> policy leak; stop broad-policy rollout
```

Host ownership must remain fail-closed. Missing, conflicting or unresolved helper
metadata must not grant spoofing. Test the affected scoped app and at least one
unscoped control app concurrently; for WebKit regressions also test helper restart,
Safari/SafariViewService when relevant, and a host whose ownership cannot be
resolved.

If the broad baseline is reproducibly implicated, perform an isolation experiment
in a dedicated diagnostic build, one variable at a time:

```text
1. current broad baseline (UIKit + WebKit cluster)
2. WebKit cluster without UIKit
3. narrow scoped apps/extensions + SpringBoard
```

These are **diagnostic build variants**, not marker-file modes in the current
production source. The app writer, `PXInjectionFilter`, validator, daemon
canonicalizer and tests must agree on the chosen variant; changing only one layer
invalidates the comparison. Restart affected processes between variants and keep
all profile/Freeze/scope settings identical.

For each variant, record real outputs rather than only hook installation: affected
API/JS values, launch latency, memory, helper crashes/restarts, and cross-app
identity leakage. Merely seeing the dylib in a process is not feature coverage.
AIDA64's earlier Freeze failure remains evidence about Freeze/SpringBoard state,
not proof for or against UIKit/WebKit load safety.

After testing, delete the two temporary debug marker files and do not leave verbose
logging enabled. Roll back by installing the previous matching app/daemon/tweak
build, regenerating filters through the normal scope writer, and restarting
affected processes.
