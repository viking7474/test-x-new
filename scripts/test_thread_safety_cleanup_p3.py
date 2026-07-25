#!/usr/bin/env python3
"""P3 thread-safety, cache ownership, path cleanup and browser schema matrix."""

from __future__ import annotations

import re
import threading
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType
from typing import Any

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


SOURCES = {
    "scope_h": read("ProjectXTweak/PXScope.h"),
    "scope": read("ProjectXTweak/PXScope.m"),
    "runtime_h": read("common/PXRuntimeUtilities.h"),
    "runtime": read("common/PXRuntimeUtilities.m"),
    "paths_h": read("common/PXPaths.h"),
    "paths": read("common/PXPaths.m"),
    "tweak": read("ProjectXTweak/Tweak.x"),
    "ios": read("ProjectXTweak/IOSVersionHooks.x"),
    "battery": read("ProjectXTweak/BatteryHooks.x"),
    "boot": read("ProjectXTweak/BootTimeHooks.x"),
    "theme": read("ProjectXTweak/ThemeHooks.x"),
    "pasteboard": read("ProjectXTweak/PasteboardHooks.x"),
    "canvas": read("ProjectXTweak/CanvasFingerprintHooks.x"),
    "storage": read("ProjectXTweak/StorageHooks.x"),
    "wifi": read("ProjectXTweak/WiFiHook.x"),
    "network": read("ProjectXTweak/NetworkConnectionTypeHooks.x"),
    "app_version": read("ProjectXTweak/AppVersionHooks.x"),
    "device_model": read("ProjectXTweak/DeviceModelHooks.x"),
    "user_defaults": read("ProjectXTweak/UserDefaultsHooks.x"),
    "missing": read("ProjectXTweak/MissingSpoofHooks.x"),
    "locale": read("ProjectXTweak/LocaleTimeZoneHooks.x"),
    "storage_manager": read("common/StorageManager.m"),
    "wifi_manager": read("common/WiFiManager.m"),
    "network_manager": read("common/NetworkManager.m"),
    "device_model_manager": read("common/DeviceModelManager.m"),
    "workflow": read(".github/workflows/build-ios-arm.yml"),
}

PROJECT_TWEAK_FILES = list((ROOT / "ProjectXTweak").glob("*.x")) + list((ROOT / "ProjectXTweak").glob("*.m"))
PROJECT_TWEAK_TEXT = "\n".join(path.read_text(encoding="utf-8") for path in PROJECT_TWEAK_FILES)
COMMON_FILES = list((ROOT / "common").glob("*.m")) + list((ROOT / "common").glob("*.h"))
COMMON_TEXT = "\n".join(path.read_text(encoding="utf-8") for path in COMMON_FILES)


class Matrix:
    def __init__(self) -> None:
        self.total = 0
        self.failed = 0

    def check(self, name: str, condition: bool) -> None:
        self.total += 1
        if condition:
            print(f"PASS: {name}")
        else:
            self.failed += 1
            print(f"FAIL: {name}")

    def finish(self) -> None:
        if self.failed:
            print(f"thread safety/cleanup P3 matrix: FAIL ({self.failed}/{self.total})")
            raise SystemExit(1)
        print(f"thread safety/cleanup P3 matrix: PASS ({self.total}/{self.total})")


def function_body(source: str, name: str) -> str:
    match = None
    brace = -1
    for candidate in re.finditer(
        rf"(?m)^\s*(?:static\s+)?[^;{{\n]+\b{re.escape(name)}\s*\(", source
    ):
        candidate_brace = source.find("{", candidate.end())
        candidate_semicolon = source.find(";", candidate.end())
        if candidate_brace >= 0 and (candidate_semicolon < 0 or candidate_brace < candidate_semicolon):
            match = candidate
            brace = candidate_brace
            break
    if match is None:
        raise RuntimeError(f"missing function: {name}")

    depth = 0
    state = "code"
    quote = ""
    escaped = False
    index = brace
    while index < len(source):
        char = source[index]
        nxt = source[index + 1] if index + 1 < len(source) else ""
        if state == "code":
            if char == "/" and nxt == "/":
                state = "line"
                index += 2
                continue
            if char == "/" and nxt == "*":
                state = "block"
                index += 2
                continue
            if char in {'"', "'"}:
                state = "string"
                quote = char
                index += 1
                continue
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    return source[match.start() : index + 1]
            index += 1
        elif state == "line":
            if char == "\n":
                state = "code"
            index += 1
        elif state == "block":
            if char == "*" and nxt == "/":
                state = "code"
                index += 2
            else:
                index += 1
        else:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                state = "code"
            index += 1
    raise RuntimeError(f"unterminated function: {name}")


def run_source_matrix(matrix: Matrix) -> None:
    scope_load = function_body(SOURCES["scope"], "PXLoadScopedAppsFromDisk")
    scope_current = function_body(SOURCES["scope"], "PXCurrentSnapshot")
    scope_invalidate = function_body(SOURCES["scope"], "PXInvalidateScopeDecisionCache")
    log_claim = function_body(SOURCES["runtime"], "PXLogOnceClaim")
    log_reset = function_body(SOURCES["runtime"], "PXLogOnceResetNamespace")

    matrix.check("source: PXScope exposes immutable scoped snapshot API", "PXScopedAppsSnapshot" in SOURCES["scope_h"] and "PXBundleIsEnabledInScope" in SOURCES["scope_h"])
    matrix.check("source: scoped snapshot property is copy/readonly", "copy, readonly" in SOURCES["scope"] and "scopedApps" in SOURCES["scope"])
    matrix.check("source: scoped apps are copied before publication", "_scopedApps = [scopedApps copy] ?: @{}" in SOURCES["scope"])
    matrix.check("source: scoped snapshot reads are lock protected", "os_unfair_lock_lock(&gSnapshotLock)" in scope_current and "os_unfair_lock_unlock(&gSnapshotLock)" in scope_current)
    matrix.check("source: scope refresh build occurs outside snapshot lock", "PXBuildSnapshot" in SOURCES["scope"] and "Disk/settings reads happen WITHOUT holding gSnapshotLock" in SOURCES["scope"])
    matrix.check("source: stale scope builds are never published", "Never publish the stale build" in scope_current and "if (!gSnapshot) gSnapshot = built" not in scope_current)
    matrix.check("source: PXScope is sole tweak scoped-disk reader", "PXGlobalScopePath()" in scope_load and "global_scope.plist" not in PROJECT_TWEAK_TEXT)
    matrix.check("source: scoped cache invalidation clears snapshot and advances generation", "gSnapshot = nil" in scope_invalidate and "gScopeGeneration++" in scope_invalidate)
    matrix.check("source: PXScope observes settings notification", 'CFSTR("com.hydra.projectx.settings.changed")' in SOURCES["scope"])
    matrix.check("source: PXScope observes profile notification", 'CFSTR("com.hydra.projectx.profileChanged")' in SOURCES["scope"])
    matrix.check("source: PXScope observes scoped-app notification", 'CFSTR("com.hydra.projectx.scopedAppsChanged")' in SOURCES["scope"])

    forbidden_scope_tokens = ["scopedAppsCache", "scopedAppsCacheTimestamp", "kScopedAppsPath", "kScopedAppsCacheValidDuration"]
    for token in forbidden_scope_tokens:
        matrix.check(f"source: removed local scoped cache token {token}", token not in PROJECT_TWEAK_TEXT and token not in COMMON_TEXT)

    scoped_consumers = ["battery", "boot", "ios", "theme", "pasteboard", "storage", "wifi", "network"]
    matrix.check("source: scoped consumers read shared immutable snapshot", all("PXScopedAppsSnapshot()" in SOURCES[name] for name in scoped_consumers))
    matrix.check("source: direct scope consumers use shared membership helper", "PXBundleIsEnabledInScope" in SOURCES["locale"] and "PXBundleIsEnabledInScope" in SOURCES["missing"])

    matrix.check("source: thread-safe log-once utility is public", "PXLogOnceClaim" in SOURCES["runtime_h"] and "PXLogOnceResetNamespace" in SOURCES["runtime_h"])
    matrix.check("source: log-once set initializes exactly once", SOURCES["runtime"].count("gPXLogOnceClaims = [NSMutableSet set]") == 1 and "dispatch_once" in SOURCES["runtime"])
    matrix.check("source: log-once claim uses unfair lock", "os_unfair_lock_lock(&gPXLogOnceLock)" in log_claim and "os_unfair_lock_unlock(&gPXLogOnceLock)" in log_claim)
    matrix.check("source: log-once reset uses same lock", "os_unfair_lock_lock(&gPXLogOnceLock)" in log_reset and "os_unfair_lock_unlock(&gPXLogOnceLock)" in log_reset)
    matrix.check("source: all former log-once sites use utility", all("PXLogOnceClaim" in SOURCES[name] for name in ["boot", "ios"] if name == "boot") and all("PXLogOnceClaim" in SOURCES[name] for name in ["tweak", "battery", "theme", "pasteboard", "canvas"] if name not in {"battery", "canvas"}))
    matrix.check("source: no mutable log-once sets remain", not re.search(r"static\s+NSMutableSet\s*\*\s*(?:logged|handled|gMissing)", PROJECT_TWEAK_TEXT))
    matrix.check("source: remaining mutable set is synchronized hook registry only", SOURCES["missing"].count("static NSMutableSet *hookedClasses") == 1 and "@synchronized(hookedClasses)" in SOURCES["missing"])

    lock_expectations = {
        "scope": "gSnapshotLock",
        "tweak": "gDeviceIDsSnapshotLock",
        "ios": "gIOSVersionCacheLock",
        "battery": "gBatterySnapshotLock",
        "boot": "gBootTimeCacheLock",
        "theme": "gThemeCacheLock",
        "pasteboard": "gPasteboardStateLock",
        "canvas": "gCanvasCacheLock",
        "storage": "gStorageCacheLock",
        "wifi": "gWiFiCacheLock",
        "network": "gNetworkCacheLock",
        "app_version": "gAppVersionCacheLock",
    }
    for source_name, lock_name in lock_expectations.items():
        source = SOURCES[source_name]
        matrix.check(f"source: {source_name} declares {lock_name}", f"{lock_name} = OS_UNFAIR_LOCK_INIT" in source)
        matrix.check(f"source: {source_name} locks {lock_name}", f"os_unfair_lock_lock(&{lock_name})" in source and f"os_unfair_lock_unlock(&{lock_name})" in source)

    matrix.check("source: DeviceModel mutable map and timestamp share synchronized block", "@synchronized(modelCache)" in SOURCES["device_model"] and "cacheTimestamp = nil" in SOURCES["device_model"])
    matrix.check("source: Canvas no longer uses global srand/rand state", "srand(" not in SOURCES["canvas"] and "rand()" not in SOURCES["canvas"])
    matrix.check("source: Canvas maps initialize at one site", SOURCES["canvas"].count("cachedBundleDecisions = [NSMutableDictionary dictionary]") == 1 and SOURCES["canvas"].count("noiseSeedCache = [NSMutableDictionary dictionary]") == 1)
    matrix.check("source: Pasteboard maps initialize at one site", SOURCES["pasteboard"].count("customChangeCountMap = [NSMutableDictionary dictionary]") == 1 and SOURCES["pasteboard"].count("lastKnownPasteboardData = [NSMutableDictionary dictionary]") == 1)
    matrix.check("source: AppVersion maps initialize at one site", SOURCES["app_version"].count("gCachedProfileVersionPlists = [NSMutableDictionary dictionary]") == 1 and SOURCES["app_version"].count("gCachedProfileVersionMTime = [NSMutableDictionary dictionary]") == 1)

    matrix.check("source: DeviceSpec cache is initialized only through setup method", "deviceSpecsCache" not in COMMON_TEXT and SOURCES["device_model_manager"].count("[self setupDeviceSpecifications]") == 1)
    matrix.check("source: device specifications publish once", SOURCES["device_model_manager"].count("self.deviceSpecifications = [specs copy]") == 1)

    profile_path_consumers = [
        "tweak", "ios", "battery", "boot", "theme", "pasteboard", "storage", "wifi",
        "network", "app_version", "device_model", "user_defaults", "missing",
        "storage_manager", "wifi_manager", "network_manager",
    ]
    matrix.check("source: profile consumers import/use PXPaths", all("PX" in SOURCES[name] and any(token in SOURCES[name] for token in ["PXActiveProfile", "PXProfileRootPath", "PXProfileIdentityPath", "PXProfileDeviceIDsPath"]) for name in profile_path_consumers))
    matrix.check("source: no absolute Profiles root remains", "/var/mobile/Library/WeaponX/Profiles" not in PROJECT_TWEAK_TEXT and "/var/mobile/Library/WeaponX/Profiles" not in COMMON_TEXT)
    matrix.check("source: no arbitrary first-profile fallback remains in network/wifi paths", "contentsOfDirectoryAtPath" not in SOURCES["network"] and "contentsOfDirectoryAtPath" not in SOURCES["wifi"] and "contentsOfDirectoryAtPath" not in SOURCES["network_manager"])

    browser_literals = [
        "com.apple.mobilesafari",
        "com.google.chrome",
        "org.mozilla.ios.Firefox",
        "com.brave.ios",
        "com.microsoft.msedge",
        "com.opera",
    ]
    matrix.check("source: browser list API is centralized", "PXBrowserBundleIdentifierPrefixes" in SOURCES["scope_h"] and "PXIsBrowserBundleIdentifier" in SOURCES["scope_h"])
    matrix.check("source: each browser literal appears only in PXScope", all(PROJECT_TWEAK_TEXT.count(browser) == SOURCES["scope"].count(browser) == 1 for browser in browser_literals))
    matrix.check("source: DeviceSpec consumes centralized browser helper", "PXIsBrowserBundleIdentifier(bundleID)" in read("ProjectXTweak/DeviceSpecHooks.x"))
    matrix.check("source: IOSVersion consumes centralized Safari helpers", "PXIsSafariBrowserBundleIdentifier" in SOURCES["ios"] and "PXIsSafariStackProcess" in SOURCES["ios"])

    libsystem_targets = SOURCES["tweak"] + SOURCES["ios"] + read("ProjectXTweak/DeviceSpecHooks.x")
    matrix.check("source: no unnecessary libSystem dlopen remains in project hooks", not re.search(r'dlopen\([^\n]*libSystem', PROJECT_TWEAK_TEXT))
    matrix.check("source: no unnecessary libSystem handle remains in project hooks", "libSystemHandle" not in PROJECT_TWEAK_TEXT and "libcHandle" not in PROJECT_TWEAK_TEXT and "dlclose(libSystem)" not in PROJECT_TWEAK_TEXT)
    matrix.check("source: system symbols resolve through RTLD_DEFAULT", all(token in libsystem_targets for token in ['dlsym(RTLD_DEFAULT, "uname")', 'dlsym(RTLD_DEFAULT, "host_statistics64")', 'dlsym(RTLD_DEFAULT, "NXGetLocalArchInfo")']) and 'return symbol ? dlsym(RTLD_DEFAULT, symbol) : NULL;' in read("ProjectXTweak/JailbreakBypassHooks.x"))

    matrix.check("source: identity notification clears identity and scope caches", "PXInvalidateDeviceIdsSnapshot();" in SOURCES["tweak"] and "PXInvalidateScopeDecisionCache();" in function_body(SOURCES["tweak"], "PXIdentitySnapshotChanged"))
    matrix.check("source: WiFi notification clears WiFi and scope caches", "PXWiFiInvalidateCache();" in function_body(SOURCES["wifi"], "settingsChanged") and "PXInvalidateScopeDecisionCache();" in function_body(SOURCES["wifi"], "settingsChanged"))
    matrix.check("source: Network scoped notification clears network and scope caches", "PXNetworkInvalidateCaches();" in function_body(SOURCES["network"], "scopedAppsChanged") and "PXInvalidateScopeDecisionCache();" in function_body(SOURCES["network"], "scopedAppsChanged"))
    matrix.check("source: Storage notification clears storage and scope caches", "PXStorageInvalidateCache();" in function_body(SOURCES["storage"], "PXStorageSettingsChanged") and "PXInvalidateScopeDecisionCache();" in function_body(SOURCES["storage"], "PXStorageSettingsChanged"))
    matrix.check("source: AppVersion invalidation clears scope cache", "PXInvalidateScopeDecisionCache();" in function_body(SOURCES["app_version"], "PXAppVersionHooksInvalidateCache"))

    matrix.check("source: CI includes P3 matrix", "python3 scripts/test_thread_safety_cleanup_p3.py" in SOURCES["workflow"])


@dataclass(frozen=True)
class ScopeSnapshot:
    generation: int
    apps: MappingProxyType[str, bool]


class ScopeStore:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._snapshot = ScopeSnapshot(0, MappingProxyType({}))

    def publish(self, generation: int) -> None:
        apps = MappingProxyType({f"g{generation}:a": True, f"g{generation}:b": False})
        with self._lock:
            self._snapshot = ScopeSnapshot(generation, apps)

    def read(self) -> ScopeSnapshot:
        with self._lock:
            return self._snapshot

    def invalidate(self) -> None:
        with self._lock:
            self._snapshot = ScopeSnapshot(0, MappingProxyType({}))


class LogOnceRegistry:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._claims: set[tuple[str, str]] = set()

    def claim(self, namespace: str, key: str) -> bool:
        composite = (namespace, key)
        with self._lock:
            if composite in self._claims:
                return False
            self._claims.add(composite)
            return True


class CacheUnit:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._value: tuple[int, str] | None = None
        self._timestamp = 0

    def publish(self, generation: int) -> None:
        with self._lock:
            self._value = (generation, f"value-{generation}")
            self._timestamp = generation

    def read(self) -> tuple[tuple[int, str] | None, int]:
        with self._lock:
            return self._value, self._timestamp

    def invalidate(self) -> None:
        with self._lock:
            self._value = None
            self._timestamp = 0


def run_concurrency_matrix(matrix: Matrix) -> None:
    scope = ScopeStore()
    scope_errors: list[str] = []

    def scope_writer() -> None:
        for generation in range(1, 1501):
            scope.publish(generation)

    def scope_reader() -> None:
        for _ in range(5000):
            snapshot = scope.read()
            if snapshot.generation == 0:
                continue
            prefix = f"g{snapshot.generation}:"
            if any(not key.startswith(prefix) for key in snapshot.apps):
                scope_errors.append("mixed generation")
                return
            try:
                snapshot.apps["mutate"] = True  # type: ignore[index]
                scope_errors.append("snapshot was mutable")
                return
            except TypeError:
                pass

    threads = [threading.Thread(target=scope_writer)] + [threading.Thread(target=scope_reader) for _ in range(8)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    matrix.check("concurrency: scope readers never observe mixed generations", not scope_errors)
    matrix.check("concurrency: published scope snapshot is immutable", not scope_errors)
    scope.invalidate()
    matrix.check("concurrency: scope invalidation clears snapshot", scope.read().generation == 0 and not scope.read().apps)

    registry = LogOnceRegistry()
    counts: Counter[str] = Counter()
    counts_lock = threading.Lock()

    def claimant(worker: int) -> None:
        for key_index in range(100):
            key = f"key-{key_index}"
            for _ in range(5):
                if registry.claim("P3", key):
                    with counts_lock:
                        counts[key] += 1

    claim_threads = [threading.Thread(target=claimant, args=(index,)) for index in range(32)]
    for thread in claim_threads:
        thread.start()
    for thread in claim_threads:
        thread.join()
    matrix.check("concurrency: log-once returns exactly one winner per key", len(counts) == 100 and all(value == 1 for value in counts.values()))

    cache = CacheUnit()
    cache_errors: list[str] = []

    def cache_writer() -> None:
        for generation in range(1, 5001):
            cache.publish(generation)

    def cache_reader() -> None:
        for _ in range(10000):
            value, timestamp = cache.read()
            if value is None:
                if timestamp != 0:
                    cache_errors.append("nil value with nonzero timestamp")
                    return
            elif value[0] != timestamp or value[1] != f"value-{timestamp}":
                cache_errors.append("mixed cache unit")
                return

    cache_threads = [threading.Thread(target=cache_writer)] + [threading.Thread(target=cache_reader) for _ in range(8)]
    for thread in cache_threads:
        thread.start()
    for thread in cache_threads:
        thread.join()
    matrix.check("concurrency: cache value and timestamp remain coherent", not cache_errors)
    cache.invalidate()
    matrix.check("concurrency: cache invalidation clears value and timestamp together", cache.read() == (None, 0))


def main() -> None:
    matrix = Matrix()
    run_source_matrix(matrix)
    run_concurrency_matrix(matrix)
    matrix.finish()


if __name__ == "__main__":
    main()
