# P1-C — PXScope thread safety & Jailbreak hook groups (Newplan §5)

This phase covers Newplan §5: the PXScope immutable snapshot and the Jailbreak
hook groups / master toggle. Audit conclusion: the live code in
`ProjectXTweak/PXScope.m` and `ProjectXTweak/JailbreakBypassHooks.x` already
implements §5. This document records that audit and adds host-runnable
regression tests (`common/PXP1CFilters.*`) that lock the §5 decision math so it
cannot drift. No live on-device code path is changed by P1-C.

## Audit: PXScope immutable snapshot (§5)

`ProjectXTweak/PXScope.m` satisfies every §5 requirement:

- **Immutable snapshot** — `PXScopeSnapshot` is a readonly object holding the
  device/Safari/display toggles, the enabled scoped-app map, the scope
  generation, and an expiration time. It is published once and never mutated.
- **`os_unfair_lock` usage** — `gSnapshotLock` is held only briefly to read or
  publish the snapshot pointer. Disk/settings reads in `PXBuildSnapshot` run
  *without* holding the lock.
- **Dedicated refresh lock** — `gRefreshLock` guarantees only one thread
  reloads from disk; other threads keep using the last valid snapshot.
- **Dedicated decision-log lock** — `gDecisionLogTimes` is protected by
  `gDecisionLogLock` and only touched when debug flags are on.
- **Darwin notifications** — `PXInvalidateScopeDecisionCache` atomically nils
  the snapshot and bumps `gScopeGeneration`; in-flight builds for a stale
  generation are discarded instead of published, so readers never see a
  mutated dictionary.
- **WebKit host cache fail-closed** — `PXWebKitHostBundleIdentifier` resolves
  the host once via `dispatch_once` (process-lifetime). When no host resolves,
  `PXWebKitHostIsScopedForSpoofing` returns NO (fail closed).
- **No hot-path logging** — `PXProcessIsAllowedForSpoofing` only logs when a
  debug flag file is present; otherwise it performs no file/NSLog work.

## Audit: Jailbreak hook groups (§5)

`ProjectXTweak/JailbreakBypassHooks.x` `%ctor` satisfies the §5 constructor
contract, in order:

1. **Critical/eligible process check** — `PXJBProcessIsEligibleAtLaunch`
   excludes launchd/SpringBoard/backboardd/`com.apple.*`/ProjectX and then
   defers to `PXProcessIsAllowedForSpoofing` (scope check). Ineligible → return.
2. **Master toggle at launch** — `jailbreakDetectionEnabled`. When off, the
   ctor logs and returns *before installing any Logos group or native
   provider* (no groups, no coordinator providers).
3. **Launch-only capability install** — the requested policy mask
   (`PXJBBuildRequestedPolicyMask`) is captured at launch; aggressive/
   experimental capabilities (dyld hide, add-image blocker, task_info,
   dl_iterate_phdr, dlopen/dlsym, proc maps, objc images) install only when
   their launch toggle is set.
4. **Install audit → immutable installed mask** —
   `PXJBFinalizeCapabilityRegistryAndAudit` publishes the installed mask; the
   effective mask is `requested & installed` (`PXJBPublishPolicySnapshot`).

Runtime behavior follows directly from `effective = requested & installed`:

- **Master off at runtime** → the reload timer recomputes `requested = 0`, so
  `effective = 0` and every installed handler falls through to `%orig`/original
  after the next reload (pass-through).
- **Master on after launch** → capabilities not installed at launch are absent
  from `installed`, so `effective` cannot gain them; a relaunch is required.
  The UI surfaces the "relaunch app" requirement.
- **Common gate** — hook bodies gate on `PXJBPolicyFeatureEnabled` (which
  requires BOTH the master bit and the feature bit) plus the reentry-scope
  macros, so even handlers that would return `NO` still consult the gate first.

Coordinator ownership (§5 "JB sysctl/statfs/getifaddrs → coordinator
provider"):

- **statfs** — registered as a coordinator post-provider
  (`jb.statfs.sanitize`, priority `PXNativeHookPriorityJailbreakSanitize`); JB
  does not `MSHookFunction` statfs itself.
- **sysctl / sysctlbyname** — registered as coordinator pre-providers
  (`jb.sysctl.sanitize` / `jb.sysctlbyname.sanitize`) that only claim
  KERN_PROC/kern.bootargs and pass every other key through.
- **getifaddrs** — JailbreakBypassHooks.x contains no `getifaddrs` logic; per
  §1 that surface is owned by the Network module, so there is nothing for JB
  to migrate.

## Host-testable helpers (`common/PXP1CFilters.{h,m}`)

Pure mirrors of the §5 decision math, no globals/locks/IO:

- `PXP1CScopeBundleEnabled(scopedApps, bundleID)` — mirrors
  `PXScopedBundleEnabledInSnapshot`.
- `PXP1CWebKitHostScoped(deviceSpoof, host, critical, enabled)` — mirrors the
  `PXWebKitHostIsScopedForSpoofing` fail-closed rule.
- `PXP1CSnapshotNeedsRefresh(hasSnapshot, now, expiration)` — mirrors the
  `PXCurrentSnapshot` refresh test.
- `PXP1CJBRequestedMask(masterEnabled, masterBit, featureBits)` — mirrors
  `PXJBBuildRequestedPolicyMask` (0 when master off).
- `PXP1CJBEffectivePolicyMask(requested, installed)` — mirrors
  `PXJBPublishPolicySnapshot` (`requested & installed`).
- `PXP1CJBFeatureActive(effective, masterBit, featureBit)` — mirrors
  `PXJBPolicyFeatureEnabled` (master AND feature required).
- `PXP1CJBIsSensitiveMountPath(path)` — mirrors `PXJBIsSensitiveMountPath`.
- `PXP1CJBNormalizeStatfsFlags(flags)` — mirrors `PXJBNormalizeStatfs`
  (`flags | MNT_RDONLY`).

These are reference/parity helpers: the live bodies in PXScope.m and
JailbreakBypassHooks.x remain the on-device implementation and are not
delegated (mirroring the P1-B ATT decision — low-risk, no behavior change).

## Run the host tests

```sh
clang -fobjc-arc -framework Foundation -Icommon \
  common/PXP1CFilters.m tests/PXP1CFiltersTests.m tests/PXP1CFiltersMain.m \
  -o /tmp/px_p1c_tests && /tmp/px_p1c_tests
```

Expected output: `ALL P1-C HELPER TESTS PASSED`.

> Note: like P1-A/P1-B, this is static/host verification only. The device
> tweak has not been compiled in this environment (no theos/clang-ios
> toolchain available here).
