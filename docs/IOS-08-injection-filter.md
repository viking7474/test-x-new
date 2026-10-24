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
5. Keychain Bridge is retired. The app and daemon generate/install only the main
   tweak filter. Keychain backup/restore/clear use the resigned helper; legacy
   archive `method=in_app` is migrated to that helper without launching the app.
6. Validation rejects malformed bundle arrays, wildcard targets, unsupported
   filter keys, invalid Mode and mixed placeholders. UIKit is now supported.
7. The writer and daemon share the same computation. A hand-edited installed
   plist is not a durable policy change.

## Paths

- Scope: `/var/mobile/Library/Preferences/com.hydra.tlinkios.global_scope.plist` (via `PXGlobalScopePath`).
- Staging: `/var/mobile/Library/TLinkIOS/filter_plists`.
- Installed: RootHide/ElleKit uses `jbroot("/usr/lib/TweakInject")` as the canonical injector directory. Legacy rootful/rootless builds retain `/Library/MobileSubstrate/DynamicLibraries` (or `/var/jb/...`).
- Plist: `TLinkIOSTweak.plist` only.
- Daemon diagnostics: `/var/mobile/Library/TLinkIOS/filter_daemon_debug.plist`.
- Cross-sandbox tweak-load probe: `/var/mobile/Library/TLinkIOS/tweak_load_probe.plist`. On a RootHide bootstrap shell, rootfs user-data paths are addressed as `/rootfs/var/mobile/...`; the injected app never needs a `/tmp` flag for this probe.

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
unscoped Safari and recursive scope reads. CI runs the native
harnesses. See `WebKit_Filtering.md` for capabilities, lifecycle and device checks.

`python3 scripts/test_keychain_bridge_retirement.py` executes the package preinst
on disposable rootful/rootless/RootHide trees, checks exact artifact cleanup and
failure/idempotence semantics, and guards against reintroducing the listener or
filter writers. CI additionally checks the extracted release package in both lanes.

## Upgrade migration

The package preinst removes only the retired bridge's named plist/dylib files in
known injector locations and its staging filters (including legacy ProjectX data).
Postinst stops the previous daemon and reruns the same migration after legacy data
copy, before self-test/bootstrap. Other tweak files, profile data and archives are
preserved. A reused build staging tree is cleaned of the retired injection artifacts.

Migration writes `/var/mobile/Library/Preferences/com.hydra.tlinkios.bridge-retirement.plist`
(rootfs-prefixed in the RootHide bootstrap). Preinst must not create the TLinkIOS
data directory, which would suppress the existing first-upgrade ProjectX data copy.
When old artifacts were found, `pending-target-restart` remains set on reruns.
Restart TLinkIOS and previously injected target apps in the controlled upgrade flow;
removing a file does not unload an image or unregister its Darwin observer.
The migration never terminates those apps and never claims runtime verification.
