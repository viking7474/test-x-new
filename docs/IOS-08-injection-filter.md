# IOS-08 — Injection filter

Single source of truth for how ProjectX turns the global scope selection into the
two MobileSubstrate filter plists and how the mount daemon validates them before
installing. Both sides now delegate to `common/PXInjectionFilter.{h,m}` so their
rules can never drift, and the logic is covered by a host-runnable test.

## Why

Before IOS-08 the union/empty-state rules were duplicated: the app writer
(`PXWriteSubstrateFilterPlists` in `ProjectXViewController.m`) computed the bundle
lists inline, while the mount daemon (`WeaponXDaemon.m`) re-implemented the
validation and checksum. That drift produced a real bug: the empty-scope tweak
filter was written as `[com.apple.springboard, <placeholder>]`, which the daemon's
own validator rejects with `placeholder-with-real-bundles`. IOS-08 extracts one
pure module, wires both callers to it, and fixes the empty-state rule.

## Module API (`common/PXInjectionFilter.h`)

| Function | Purpose |
| --- | --- |
| `PXInjectionNormalizeBundleList` | Sort + de-dup + drop empty/non-string entries (stable output). |
| `PXInjectionBundleIsProjectXApp` | `com.hydra.projectx` / `com.hydra.weaponx` guard. |
| `PXInjectionBundleIsAppleOrWebKit` | Apple- or WebKit-family classifier (nil → YES, defensive). |
| `PXInjectionDefaultWebKitHelperBundleIDs` | Safari/WebKit helper cluster added when ≥1 app is scoped. |
| `PXInjectionEnabledMainBundlesFromScopePlist` | Enabled third-party mains from a loaded `global_scope.plist`. |
| `PXInjectionComputeTweakBundles` | Tweak filter = scope + SpringBoard when apps are scoped, else placeholder-only. |
| `PXInjectionComputeBridgeBundles` | Keychain bridge filter = third-party app/extensions only. |
| `PXInjectionFilterPlistDictionary` | Build `{ Filter: { Bundles, Mode: "Any" } }`. |
| `PXInjectionFilterPlistIsValid` | Daemon-side validation (returns reason on failure). |
| `PXInjectionBundlesChecksum` | Stable `count:comma-joined` checksum. |

Constants: `PXInjectionPlaceholderBundleID` = `com.hydra.projectx.no-injection-placeholder`,
`PXInjectionSpringBoardBundleID` = `com.apple.springboard`.

## Rules

1. **Source of truth** — enabled third-party mains come only from
   `global_scope.plist` → `ScopedApps` entries with `enabled == YES`. ProjectX's
   own bundles and Apple WebKit/Safari helpers are removed.
2. **Union, not partial** — the writer always rebuilds from the full enabled
   scope (expand extensions → append WebKit cluster → normalize). It never passes
   the just-added app's expanded list into the writer.
3. **Tweak filter (`ProjectXTweak.plist`)** — when ≥1 app is scoped: expanded
   scope **plus SpringBoard** (Profile Indicator runs in SpringBoard), normalized.
   A non-empty list never contains the placeholder.
4. **Empty scope** — tweak collapses to the placeholder alone (never `Bundles=[]`,
   never SpringBoard-only), matching the keychain bridge and the Newplan
   acceptance rule "remove all apps → installed filter only placeholder".
5. **Keychain bridge (`WeaponXKeychainBridge.plist`)** — third-party app and
   extension bundles only (Apple/WebKit and the placeholder are dropped). When
   empty it collapses to the placeholder alone.
6. **Daemon validation** — rejects non-dictionaries, missing `Filter`, `Mode`
   other than `Any`, empty `Bundles`, non-string/empty items, `com.apple.UIKit`,
   wildcards, and the placeholder mixed with real bundles. It installs atomically
   (temp file → `chmod 644` → `chown 0:0` → `rename`) and records a
   `count:comma-joined` checksum in `filter_daemon_debug.plist`.

## Paths

- Staging: `/var/mobile/Library/ProjectX/filter_plists/{ProjectXTweak,WeaponXKeychainBridge}.plist`
- Installed: `/Library/MobileSubstrate/DynamicLibraries` and `/var/jb/Library/MobileSubstrate/DynamicLibraries`
- App debug state: `/var/mobile/Library/ProjectX/filter_sync_debug.plist` (`syncStatus` ∈ `in_sync` | `staging_mismatch` | `installed_mismatch`)
- Daemon debug state: `/var/mobile/Library/ProjectX/filter_daemon_debug.plist`
- Change notification (Darwin): `com.hydra.projectx.filterPlistChanged`

## Callers

- **App** — `ProjectXViewController.m`: `PXEnabledScopeBundleIDs`,
  `PXNormalizedBundleList` and `PXWriteSubstrateFilterPlists` delegate to the
  module. Invoked on add/remove/reset scope changes and after `saveScopedApps`.
- **Daemon** — `WeaponXMountDaemon/WeaponXDaemon.m`: `filterPlistIsValid` and
  `PXFilterBundlesChecksum` delegate to the module. The daemon target compiles
  `common/PXInjectionFilter.m` (pure Foundation) via the Makefile.

## Tests

`tests/PXInjectionFilterTests.m` (+ `tests/PXInjectionFilterMain.m`) is a
host-runnable harness covering normalization, scope filtering, tweak/bridge
computation, empty-state rules, the full validator reason table, a
writer↔daemon round-trip (computed plists must pass the daemon validator), and
the checksum. Build and run on macOS:

```sh
clang -fobjc-arc -framework Foundation \
  -I./common \
  common/PXInjectionFilter.m \
  tests/PXInjectionFilterTests.m \
  tests/PXInjectionFilterMain.m \
  -o /tmp/pxinjectionfilter_tests
/tmp/pxinjectionfilter_tests
```

Expected: `ALL INJECTION FILTER TESTS PASSED` (exit code 0).
