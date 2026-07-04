# WebKit Filtering Notes

## Problem

ProjectX no longer uses `com.apple.UIKit` as the tweak filter because that injects into too many UIKit/system helper processes and can break app launch paths.

Modern apps often use WebKit helper processes for webviews, login, captcha, payment, ads, and Safari/Mail content. If ProjectX only injects into the main app bundle, web fingerprinting can leak through:

- `com.apple.WebKit.WebContent`: JavaScript, canvas, WebGL, screen metrics, UA-visible behavior.
- `com.apple.WebKit.Networking`: network requests, headers, cookies, UA paths.
- `com.apple.WebKit.GPU`: GPU/WebGL-related rendering paths.
- `com.apple.SafariViewService`: in-app Safari/SFSafariViewController flows.

## Filter Strategy

The runtime filter is generated dynamically from `Chọn App RESET`:

- Main app bundle ID.
- Exact extension bundle IDs found in `PlugIns/*.appex` and `Plugins/*.appex`.
- Default WebKit cluster:
  - `com.apple.SafariViewService`
  - `com.apple.WebKit.WebContent`
  - `com.apple.WebKit.Networking`
  - `com.apple.WebKit.GPU`

The filter is staged by the ProjectX app at:

```text
/var/mobile/Library/ProjectX/filter_plists/ProjectXTweak.plist
/var/mobile/Library/ProjectX/filter_plists/WeaponXKeychainBridge.plist
```

`WeaponXDaemon` runs as root, validates the staging plist, and atomically installs it into:

```text
/Library/MobileSubstrate/DynamicLibraries/
```

The daemon rejects invalid filter plists, `com.apple.UIKit`, and wildcard bundle IDs.

## WebKit Host Detection

WebKit helpers are shared services, so their own bundle ID is not enough to decide whether spoofing should run.

ProjectX now detects the host app using the WebKit helper HOME container metadata:

```text
NSHomeDirectory()/.com.apple.mobile_container_manager.metadata.plist
```

The key used is:

```text
MCMMetadataIdentifier
```

Example from Safari:

```text
bundleID = com.apple.WebKit.WebContent
MCMMetadataIdentifier = com.apple.mobilesafari
```

This means WebKit spoofing is only allowed when the detected host bundle is explicitly enabled in `global_scope.plist`.

## Runtime Scope Rules

`PXProcessIsAllowedForSpoofing()` applies these rules:

- Critical system processes are always denied.
- Main apps/extensions are allowed only if explicitly enabled in `global_scope.plist`.
- WebKit/SafariViewService helpers are allowed only if:
  - The hook requested `PXScopeOptionAllowSafariAuthStack`.
  - Safari/WebKit stack spoofing is enabled.
  - `MCMMetadataIdentifier` resolves to a host app that is enabled in scope.
- WebKit helpers are not allowed just because their bundle ID is `com.apple.WebKit.*`.

Scope decision logs include the detected host:

```text
[PXScopeDecision] bundle=com.apple.WebKit.WebContent proc=com.apple.WebKit.WebContent host=com.apple.mobilesafari strict=0 safari=0 webkitHost=1 options=1 allowed=1
```

## WebKit-Safe Hook Profile

WebKit helpers should not run the same native/low-level hooks as normal app processes.

Currently skipped in WebKit:

- Main low-level native hook path in `Tweak.x`.
- `BootTimeHooks.x`
- `StorageHooks.x`
- `UUIDHooks.x`
- `PasteboardHooks.x`
- `WiFiHook.x`
- `UserDefaultsHooks.x`
- `DeviceSpecHooks.x`
- `NetworkConnectionTypeHooks.x`
- `WeaponXKeychainBridge` is excluded from WebKit in the generated bridge filter.

Allowed in WebKit when host is scoped:

- Canvas/WebGL fingerprint protection.
- iOS version and UA-related hooks.
- Locale/timezone hooks.
- Missing spoof hooks such as Metal/WebGL-facing names.
- Domain blocking if enabled by settings.

## Debugging

Enable WebKit trace:

```sh
touch /tmp/px_debug_webkit
rm -f /var/mobile/Library/ProjectX/webkit_trace.log /tmp/webkit_trace.log
```

Open Safari, Mail, or an app with WebView, then inspect:

```sh
cat /var/mobile/Library/ProjectX/webkit_trace.log
cat /tmp/webkit_trace.log
```

Disable trace:

```sh
rm -f /tmp/px_debug_webkit
```

Check daemon filter sync:

```sh
cat /var/mobile/Library/ProjectX/filter_daemon_debug.plist
cat /Library/MobileSubstrate/DynamicLibraries/ProjectXTweak.plist
cat /Library/MobileSubstrate/DynamicLibraries/WeaponXKeychainBridge.plist
```

After filter changes, respring so Substrate reloads the updated filter.

## Scope Decision File Logging

Unified logs can miss early or short-lived helper-process messages. Scope decisions can be logged directly to file with flag files:

```sh
touch /tmp/px_debug_scope
rm -f /var/mobile/Library/ProjectX/scope_decision.log /tmp/scope_decision.log
```

Read logs:

```sh
cat /var/mobile/Library/ProjectX/scope_decision.log
cat /tmp/scope_decision.log
```

Disable scope file logging:

```sh
rm -f /tmp/px_debug_scope
```

By default, repeated identical scope decisions are throttled. For full verbose logging, enable:

```sh
touch /tmp/px_debug_scope_verbose
```

Disable verbose mode:

```sh
rm -f /tmp/px_debug_scope_verbose
```

`/tmp/px_debug_all` also enables scope file logging.

Do not leave verbose scope logging enabled while testing performance-sensitive apps like Safari or Chrome. Verbose mode writes every scope decision to disk and can make older browser builds load slowly. Prefer this sequence for normal tests:

```sh
rm -f /tmp/px_debug_scope_verbose /tmp/px_debug_all
touch /tmp/px_debug_scope
```

Use verbose only for short captures, then disable it immediately.
