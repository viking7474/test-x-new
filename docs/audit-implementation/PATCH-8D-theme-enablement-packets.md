# Patch 8D — Theme enablement, fallback and resolved cache packets

Date: 2026-11-15. Baseline `d3968f4` (Patch 8C), whose build the user confirms
passed. Production changes are confined to ThemeHooks.x's common data/enablement
helpers and scalar cache publication. All six adapter bodies, capability checks,
notification handlers and constructor are unchanged. This closes the source-level
DeviceTheme admission gap recorded in Patch 8C; native/device acceptance and the
broader source authority rollout remain pending, with enrollment H5S-partial.

## Top ten changes by priority and expected impact

| Priority / severity / confidence | Finding / practical impact / reproduction | Change / relative cost |
| --- | --- | --- |
| P1 / High / actual logic gap | getThemeStyleFromProfile supplied a theme whenever overall scope allowed it, without consulting DeviceTheme. A persisted OFF with an existing Dark artifact still overrode native getters and the private setter. | Read enablement before identity/artifacts in the common path. Disabled/missing enablement resolves Unspecified, so both scalar getters, three trait adapters and the private setter use their existing native paths. Native cardinality and raw setter argument remain unchanged. This intentionally changes OFF behavior; it is a bug fix, not a stylistic refactor. |
| P1 / High / precedence requirement | Treating primary false as missing, or OR-ing it with a stale true secondary, would keep the bug during ordinary paired-source updates/rollback. | PXThemePrimaryEnablement is tri-state: missing, disabled, enabled. A present DeviceTheme scalar is authoritative, including false; only genuine absence permits secondary fallback. Present invalid scalar/root/map disables. Valid booleans keep NSNumber/NSString boolValue conventions. No profile-value evidence infers enablement. |
| P1 / Medium / RootHide consistency | A separate live enablement lookup could mix the toggle from one generation with the theme from another, or introduce sandbox-inaccessible file/defaults access. | One captured runtimeView supplies tlinkSettings, optional securitySettings and, only if enabled, deviceIDs/deviceTheme. No second capture, live fallback, theme clock or theme-cache access is added. Current operation keeps its original view through publication replacement; the next operation sees an adopted successor. Low local dictionary/type-check cost. |
| P1 / Medium / rootful freshness | IdentifierManager's rootful isIdentifierEnabled uses mutable in-memory settings. A singleton's initial load alone is not a live-reader contract, and invoking loadSettings in a Darwin callback would add unrelated I/O/mutation. | A cold read-only resolver uses persisted settings and security sources. It neither constructs/reloads IdentifierManager nor invokes source capture/recovery/writers. Existing notifications revoke the complete resolved cache packet. This is a legacy live-file reader, not an atomic source transaction. |
| P1 / Medium / absence versus failure | fileExists=false can conflate absence with inaccessible input. Falling through to a legacy file/defaults after an unreadable primary could enable despite an unseen false. | PXThemePresenceAtPath distinguishes Foundation's confirmed no-such-file errors from present/unreadable. An inaccessible modern/legacy/security source disables; a present corrupt/non-dictionary source also blocks fallback. No permission repair or file creation. Controlled permission-error cases complement real file parsing tests. |
| P1 / Medium / compatibility | Rootful manager loading recognizes com.hydra.tlinkios.plist only when the modern settings file is absent. Always preferring legacy data would ignore a modern false or use stale configuration. | Keep PXTLinkIOSSettingsPath first; consider the same legacy filename only after confirmed modern absence. A present modern dictionary does not consult legacy, even when its DeviceTheme key is missing. Missing key then follows secondary precedence. Extra cold presence probes; no warm file access. |
| P1 / Medium / secondary authority | Defaults can retain stale values while the canonical security file contains false or a malformed value. | For rootful missing-primary cases, use security disk first. Present key decides; only an absent file/key reaches the existing com.weaponx.securitySettings defaults suite. Corrupt/unreadable disk blocks defaults. RootHide uses its captured secondary only. No synchronize, CFPreferences refresh or mirror write is performed. |
| P1 / Medium / cache correctness | Caching style independently from enablement could leave a valid Dark packet while OFF, or force repeated settings/file reads on every disabled hook. | Publish the resolved result as one scalar unit: OFF is cacheable Unspecified and discards any supplied style. Enabled recognized styles remain cacheable; enabled unknown theme remains uncached as in 8C. The same generation ticket revokes stale ON and OFF candidates. Inclusive 300-second TTL, invalidation ordering and monotonic clock behavior remain. |
| P1 / Medium / exceptional lifetime | New file-manager, dictionary, path, defaults and captured-settings objects would otherwise add plain-ARC cleanup gaps on provider exceptions. | Named roots/finally throughout the new chain; autoreleasing error slot avoids strong writeback temporaries. Exceptions propagate to the existing optional-preparation catch, preserving native without publishing a positive packet. Weak snapshot/input/defaults-owner probes run after pool drain. No callback, timer or retained observer is introduced. |
| P2 / Moderate avoided work while OFF / source evidence | Rechecking files per getter or reading profile data before the flag would put additional I/O/allocations on hot trait paths even when disabled. | Rootful caches resolved OFF across all six adapters; RootHide skips identity/artifact access and secondary lookup when primary is present. Both skip factories while OFF through existing adapter logic. Rootful cold ON now adds a primary presence/read (and optional secondary/defaults work), a deliberate correctness cost. No measured net CPU/latency gain is claimed. |

## Concrete decision contract

| Observed primary | Secondary | Result |
| --- | --- | --- |
| Valid present true | Any | Enabled; do not read secondary |
| Valid present false | Any, including stale true | Disabled; do not read secondary |
| Invalid present value/root/EnabledIdentifiers map | Any | Disabled; do not infer ON |
| Missing DeviceTheme/map/primary source | Valid secondary true | Enabled |
| Missing primary | False/absent/invalid secondary | Disabled |

SettingsInitialized is not an additional Theme enablement key: the observed
EnabledIdentifiers.DeviceTheme value decides, matching the captured-reader
primary contract. This read path does not normalize or repair persisted settings.
Rootful corrupt present files are distinct from missing files. Secondary-only
legacy inputs remain supported under the explicit fallback rule. Malformed-map
and unreadable-source rejection is deliberately conservative; it is stricter than
some older generic readers which could infer fallback after malformed input.

The absent-theme Light default and primary-deviceIDs/sidecar precedence are
unchanged **after enablement succeeds**. No source or enabled flag now produces
native, rather than inferring permission from an existing theme artifact. Unknown
nonempty theme values remain Unspecified; no new theme strings, trimming or
case normalization are added.

Rootful misses read enablement and theme within the same generation ticket and
cache only the resulting override/no-op enum. The cache does not publish a
separate mutable toggle alongside a style. A newer read or notification rejects
an old positive adoption; rejected OFF adoption still returns native and cannot
overwrite a newer positive cache. Normal OFF packets use the existing TTL and
are revoked by the existing toggle/settings/profile/scope topics.

## Preservation and practical limits

The six exact adapter bodies, raw WebKit scheme forwarding, native-first trait
collection calls, scalar short-circuit behavior, matching-style allocation fast
path, ABI/capability groups and constructor are text-identical to baseline. Hooks
remain installed while DeviceTheme is OFF, allowing a later accepted enablement
change without a new constructor pass. Scope/Safari checks still precede all
Theme data reads. RootHide synchronous cold priming, PXScope/runtime engine,
shared manager/security readers, writers, source/publisher implementations,
other hooks, coordinator, packaging and Makefile are untouched.

No queue hop, source-store lock/recovery, busy polling, asynchronous refresh,
new notification topic, defaults synchronization, filesystem write or shared
manager mutation occurs in production. Rootful packet construction remains
synchronous on the getter's caller. It can stat up to three candidate source
paths, parse primary/secondary as needed and consult defaults before existing
profile reads. Warm hits add no such work; OFF skips profile selection/data.
All foreign/object work remains outside the scalar cache lock.

This is not a rollback of previously applied UI state. It fixes subsequent method
decisions; it does not force a UIKit redraw or replay a saved native WebKit scheme
when no further setter call occurs. Actual UI response still needs device tests.

## Validation

The existing Theme native fixture now covers primary/secondary typed values,
invalid containers, false-versus-stale-true, secondary-only fallback, all six OFF
native paths/cardinalities/raw arguments, OFF negative-cache hits, enable/disable
notifications, lazy profile/secondary/defaults access, legacy and inaccessible
rootful sources, stale ON rejection during identity reads, RootHide one-view
inheritance through disable, provider failures/recovery and weak lifetime roots.
Controlled UIKit/scope/file providers remain facades; real lexical read-scope
cleanup is linked. These tests do not execute real UIKit or the actual daemon.

New PXThemeEnablementFileTests compiles the exact cold enablement helpers with
real Foundation file metadata/plist reads. It uses a unique temporary directory
and defaults suite; only path providers and suite identity are substituted.
It checks missing/modern/legacy precedence, canonical false, secondary disk false
over defaults true, absent disk key fallback, corrupt/non-dictionary/invalid
values, a directory at the primary path and typed scalar conversions. Each read
compares source bytes, absence, directory entries and defaults values before and
after to check no source mutation. Permission errors use the controlled fixture
because chmod behavior depends on runner privileges. The file fixture is compiled
under both scheme defines as a cold-reader portability test; it does not imply
RootHide production reads these files.

The Theme CI entry now covers eight compile/run pairs: two fixtures x rootful/
RootHide x plain ARC/ARC exception cleanup, at -O0. Four include fragments are
extracted; source methods and native call expressions are not reimplemented in
Python. Windows recipe capture checked those commands only, with no compiler or
binary execution. macOS CI must still compile and execute them.

Local: 72/73 Python suites, 4/4 Node suites. The remaining Keychain retirement
failure is the established Git Bash mkdir /c/Users/ADMIN permission problem
(4 failures, 1 error, 1 skip). Source hardening/RootHide gates, 20 negative controls,
fragment/CHECK/recipe capture, protected adapter/constructor/notification/files
comparisons and diff checks pass. No native Foundation/UIKit/Logos/Theos/device
pass or performance benchmark is claimed locally.

## Remaining acceptance

Validate actual toggle OFF/ON without restart on supported rootful/RootHide apps,
including iOS 15.8.8/AIDA64, physical Light/Dark, WebKit and concurrent profile
publication. RootHide OFF becomes effective when the reader sees the relevant
invalidation/new publication; it never bypasses publication latency with live
files. A captured in-flight operation may finish with its original enabled view.
Rootful lost notifications can retain an old resolved result until TTL.

Rootful file selection, settings/security/profile reads and defaults are not one
transaction. Concurrent file replacement or a cooperative write's intermediate
uncommitted files may still be observed; this batch does not acknowledge a source
commit or complete rootful captured-reader rollout. Presence/read races are
conservative when reads fail, but do not create a global snapshot. Full
authority/durability, independent external writers, UI restoration, movement,
profiling and release acceptance remain pending. H5S-partial is unchanged.
