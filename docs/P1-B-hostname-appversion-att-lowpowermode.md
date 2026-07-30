# P1-B — Hostname, App Version, ATT, Low Power Mode

Plan reference: `Newplan.md` §4. This document records how each acceptance
rule is satisfied by the current code, and how the pure logic is covered by
host-runnable tests (`tests/PXP1BFiltersTests.m`) with no drift from the live
hooks.

Shared pure helpers: `common/PXP1BFilters.{h,m}` (no I/O, no runtime hooking).

## 1. gethostname

- Owned by `PXNativeHookCoordinator` (single `MSHookFunction` install; works on
  MobileSubstrate and ElleKit-compatible runtimes). Not gated by
  `jailbreakDetectionEnabled`.
- Provider `tweak.gethostname` (registered in `ProjectXTweak/Tweak.x`):
  - Returns NO (coordinator calls original) when out of scope, `DeviceName`
    toggle off, missing/empty profile value, or null buffer / `namelen == 0`.
  - When scoped + `DeviceName` on, writes the profile DeviceName via
    `PXGethostnameWriteValue`, which copies `min(strlen, namelen-1)` bytes and
    always NUL-terminates.
- `UIDevice.name`, `NSHost` and `sysctlbyname("kern.hostname")` all resolve the
  same `DeviceName` profile value.
- Tests: `testGethostnameWrite` covers exact-fit, truncation, NUL guarantee,
  and the null/zero/empty rejection paths.

## 2. App Version full dictionary

- Kept as-is (owned by `IOSVersionHooks.x`): `objectForInfoDictionaryKey:` and
  `CFBundleGetValueForInfoDictionaryKey`.
- Added (`ProjectXTweak/AppVersionHooks.x`):
  - `-[NSBundle infoDictionary]`, `-[NSBundle localizedInfoDictionary]`
  - `CFBundleGetInfoDictionary`, `CFBundleGetLocalInfoDictionary`
- Rules enforced:
  - Main bundle only, and only when app-version spoof is active
    (`PXAppVersionSpoofMasterEnabled` + per-bundle `spoofingEnabled`).
  - Immutable copy returned via `PXAppVersionApplyToInfoDictionary`; system
    dictionary is never mutated in place.
  - CF full-dictionary hooks use a retained cache keyed by
    (bundleID + localized + generation); released on invalidation and in
    `%dtor`.
  - `CFBundleShortVersionString` and `CFBundleVersion` are kept in sync on every
    access path.
  - Cache invalidated on `settings.changed`, `profileChanged`,
    `scopedAppsChanged`, and `appVersionSpoofChanged` Darwin notifications.
  - Recursion guard `__thread gPXAppVersionInfoRecursion` prevents
    infoDictionary <-> bundleIdentifier <-> CFBundleGetInfoDictionary loops.
- Tests: `testAppVersionApply` (override/preserve/immutable/original-untouched/
  non-dict passthrough) and `testSafeBundleFilename` (profile filename mapping).

## 3. ATT consistency by profile

- Storage: `tracking_info.plist` and `device_ids["ATTAuthorizationStatus"]`,
  enum `0...3` (notDetermined/restricted/denied/authorized).
- Getter/setter: `IdentifierManager.attAuthorizationStatus` /
  `setATTAuthorizationStatus:`.
- Active when identifier `IDFA` is enabled (no second master toggle):
  `PXATTSpoofActive()`.
- Runtime (`ProjectXTweak/Tweak.x`):
  - `ATTrackingManager.trackingAuthorizationStatus` returns the profile status.
  - `requestTrackingAuthorizationWithCompletionHandler:` does not show the
    system prompt; delivers the profile status async on the main queue.
  - Legacy `ASIdentifierManager.isAdvertisingTrackingEnabled` returns YES only
    when authorized.
  - `advertisingIdentifier` returns the profile IDFA when authorized, else the
    zero UUID (`PXATTZeroIDFAUUIDString`).
  - ATT selectors installed only when the class/methods exist; older iOS keeps
    the legacy path.
- `common/PXP1BFilters` provides reference helpers `PXATTClampStatus` (0...3) and
  `PXATTStatusIsAuthorized` (== 3) that mirror the inline Tweak.x normalization /
  authorized-decision logic. They are covered by host tests to lock the contract;
  the live ATT bodies remain inline in `Tweak.x` (not delegated) to avoid edits to
  that large file.
- Tests: `testATT` covers clamp bounds, authorized detection, and the zero-IDFA
  constant.

## 4. Low Power Mode by profile

- `BatteryManager` extended: `lowPowerModeEnabled` / `setLowPowerModeEnabled:`.
- Boolean `LowPowerMode` persisted in `battery_info.plist` and
  `device_ids.plist`; default migration is `NO`.
- `generateBatteryInfo` preserves the current LPM (no randomization).
- `ProjectXTweak/BatteryHooks.x` hooks `-[NSProcessInfo isLowPowerModeEnabled]`
  only when the Battery identifier is enabled and the selector exists.
- A single profile snapshot (short TTL) backs battery level, state and LPM; no
  per-call independent file reads on the hot path.
- On profile/settings change with an observed LPM transition, posts
  `NSProcessInfoPowerStateDidChangeNotification` on the main queue (baseline is
  seeded at ctor without posting).

## Build / run the host tests

```
clang -fobjc-arc -framework Foundation -Icommon \
  common/PXP1BFilters.m tests/PXP1BFiltersTests.m tests/PXP1BFiltersMain.m \
  -o /tmp/px_p1b_tests && /tmp/px_p1b_tests
```

Note: the device tweak itself is built with Theos (`make`); these helper tests
are host-only and require no jailbroken device. `common/PXP1BFilters.m` is
picked up automatically by both `ProjectX_FILES` and `ProjectXTweak_FILES`
(`$(wildcard common/*.m)`).
