# IOS-08 — Injection filter

The shared source of truth is `common/PXInjectionFilter.{h,m}`. The app writer in
`TLinkIOSViewController.m` expands the full enabled scope into exact app/extension
bundle IDs. The daemon in `WeaponXMountDaemon/WeaponXDaemon.m` validates and
canonicalizes staging plists before atomically installing them.

## Rules

1. Only dictionary scope entries with `enabled == YES` are anchors. Self bundles,
   UIKit, SpringBoard and WebKit helpers cannot act as anchors.
2. Non-empty tweak scope adds UIKit, SpringBoard and the explicit WebKit cluster.
   Runtime bootstrap independently authorizes every hook module and host.
3. Empty scope is exactly `com.hydra.tlinkios.no-injection-placeholder`; no empty
   Bundles array, broad-only filter, or placeholder mixed with real targets.
4. Recomputing a canonical filter is idempotent. Legacy placeholders and coverage
   targets are stripped before rebuilding, so they cannot keep injection alive.
5. The Keychain Bridge accepts third-party app/extensions only. The daemon also
   narrows stale bridge staging; UIKit/WebKit/SpringBoard never enter the bridge.
6. Validation rejects malformed bundle arrays, wildcard targets, unsupported
   filter keys, invalid Mode and mixed placeholders. UIKit is now supported.
7. The writer and daemon share the same computation. A hand-edited installed
   plist is not a durable policy change.

## Paths

- Scope: `/var/mobile/Library/Preferences/com.hydra.tlinkios.global_scope.plist` (via `PXGlobalScopePath`).
- Staging: `/var/mobile/Library/TLinkIOS/filter_plists`.
- Installed: `/Library/MobileSubstrate/DynamicLibraries`, or its `/var/jb` counterpart.
- Plists: `TLinkIOSTweak.plist`, `WeaponXKeychainBridge.plist`.
- Daemon diagnostics: `/var/mobile/Library/TLinkIOS/filter_daemon_debug.plist`.

## Tests

On macOS:

```sh
clang -fobjc-arc -fblocks -Icommon common/PXInjectionFilter.m   tests/PXInjectionFilterTests.m tests/PXInjectionFilterMain.m   -framework Foundation -o /tmp/px-injection-tests
/tmp/px-injection-tests
clang -fobjc-arc -fblocks -Icommon tests/PXBootstrapScopeTests.m   -framework Foundation -framework CoreFoundation -o /tmp/px-bootstrap-scope
/tmp/px-bootstrap-scope
```

Tests cover writer/daemon round trips, normalization, all helper targets,
idempotent migration, empty/coverage-only input, explicit extension ownership,
unscoped Safari, recursive scope reads and bridge isolation. CI runs the native
harnesses. See `WebKit_Filtering.md` for capabilities, lifecycle and device checks.
