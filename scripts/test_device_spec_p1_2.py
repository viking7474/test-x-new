#!/usr/bin/env python3
"""P1.2 immutable DeviceSpec snapshot source and concurrency matrix."""

from __future__ import annotations

import re
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType

ROOT = Path(__file__).resolve().parents[1]
DEVICE_PATH = ROOT / "ProjectXTweak" / "DeviceSpecHooks.x"
CANVAS_PATH = ROOT / "ProjectXTweak" / "CanvasFingerprintHooks.x"
PATHS_PATH = ROOT / "common" / "PXPaths.m"
SCHEMA_PATH = ROOT / "common" / "PXDeviceProfileSchema.m"
PROBE_PATH = ROOT / "scripts" / "probe_device_spec_p1_2.sh"
DEVICE_SOURCE = DEVICE_PATH.read_text(encoding="utf-8")
CANVAS_SOURCE = CANVAS_PATH.read_text(encoding="utf-8")
PATHS_SOURCE = PATHS_PATH.read_text(encoding="utf-8")
SCHEMA_SOURCE = SCHEMA_PATH.read_text(encoding="utf-8")
PROBE_SOURCE = PROBE_PATH.read_text(encoding="utf-8") if PROBE_PATH.exists() else ""


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
            print(f"device spec P1.2 matrix: FAIL ({self.failed}/{self.total})")
            raise SystemExit(1)
        print(f"device spec P1.2 matrix: PASS ({self.total}/{self.total})")


def source_function(source: str, name: str) -> str:
    match = None
    brace = -1
    for candidate in re.finditer(
        rf"(?m)^\s*(?:static\s+)?[^;{{\n]+\b{re.escape(name)}\s*\(",
        source,
    ):
        candidate_brace = source.find("{", candidate.end())
        candidate_semicolon = source.find(";", candidate.end())
        if candidate_brace >= 0 and (candidate_semicolon < 0 or candidate_brace < candidate_semicolon):
            match = candidate
            brace = candidate_brace
            break
    if not match or brace < 0:
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


def logos_method(source: str, signature: str, occurrence: int = 1) -> str:
    starts = [m.start() for m in re.finditer(re.escape(signature), source)]
    if len(starts) < occurrence:
        raise RuntimeError(f"missing method {signature!r} occurrence {occurrence}")
    start = starts[occurrence - 1]
    brace = source.index("{", start)
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
                    return source[start : index + 1]
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
    raise RuntimeError(f"unterminated method: {signature}")


def validate_profile_id(value: object) -> str | None:
    if not isinstance(value, str):
        return None
    profile_id = value.strip()
    if not profile_id or len(profile_id) > 128:
        return None
    if profile_id in {".", ".."}:
        return None
    if "/" in profile_id or "\\" in profile_id:
        return None
    return profile_id


@dataclass(frozen=True)
class SnapshotModel:
    generation: int
    enabled: bool
    profile_id: str | None
    model: str | None
    specs: MappingProxyType | None
    source: str


def resolve_requested_enabled(
    manager_available: bool,
    manager_enabled: bool,
    has_profile_value: bool,
    profile_value: bool,
) -> bool:
    if manager_available:
        return manager_enabled
    return profile_value if has_profile_value else False


def build_snapshot_model(
    generation: int,
    requested: bool,
    profile_id: str | None,
    profile_model: str | None,
    manager_model: str | None,
    profile_specs: dict[str, object] | None,
    manager_specs: dict[str, object] | None,
) -> SnapshotModel:
    # P1.2 never adopts a cached manager model because it may belong to the
    # previous profile during a live switch. The argument remains in the model
    # solely to test that such a value is ignored.
    _ = manager_model
    model = profile_model
    source = "disabled"
    specs: dict[str, object] | None = None
    if requested and profile_id and model and profile_specs:
        specs = dict(profile_specs)
        source = "device_ids"
    elif requested and profile_id and model and manager_specs:
        specs = dict(manager_specs)
        source = "device_model_manager"

    enabled = bool(requested and profile_id and model and specs)
    if requested and not enabled:
        source = "missing-specs" if model else "missing-model"
    immutable_specs = MappingProxyType(specs) if enabled and specs is not None else None
    return SnapshotModel(generation, enabled, profile_id, model, immutable_specs, source)


class AtomicSnapshotStore:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._snapshot = SnapshotModel(0, False, None, None, None, "initial")

    def publish(self, snapshot: SnapshotModel) -> None:
        with self._lock:
            self._snapshot = snapshot

    def read(self) -> SnapshotModel:
        with self._lock:
            return self._snapshot


def run_source_matrix(matrix: Matrix) -> None:
    builder = source_function(DEVICE_SOURCE, "PXBuildDeviceSpecSnapshot")
    reload_fn = source_function(DEVICE_SOURCE, "PXReloadDeviceSpecSnapshot")
    current_fn = source_function(DEVICE_SOURCE, "PXCurrentDeviceSpecSnapshot")
    active_fn = source_function(DEVICE_SOURCE, "PXActiveDeviceSpecSnapshot")
    deep_copy = source_function(DEVICE_SOURCE, "PXDeviceSpecDeepImmutableCopy")
    validator = source_function(PATHS_SOURCE, "PXValidatedProfileID")
    reconstruct = source_function(SCHEMA_SOURCE, "PXDeviceSpecificationsFromDeviceIDs")
    refresh = source_function(DEVICE_SOURCE, "refreshCaches")
    sysctl_handler = source_function(DEVICE_SOURCE, "handleDeviceSpecSysctlByname")
    result_logger = source_function(DEVICE_SOURCE, "PXCompleteDeviceSpecSysctlResult")
    free_memory = source_function(DEVICE_SOURCE, "getFreeMemoryPercentage")
    memory_stats = source_function(DEVICE_SOURCE, "getConsistentMemoryStats")
    host_stats = source_function(DEVICE_SOURCE, "hook_host_statistics64")
    nx_hook = source_function(DEVICE_SOURCE, "hook_nx_get_local_arch_info")

    matrix.check("source: immutable snapshot class exists", "@interface PXDeviceSpecSnapshot" in DEVICE_SOURCE and "@implementation PXDeviceSpecSnapshot" in DEVICE_SOURCE)
    matrix.check("source: snapshot state is readonly", all(fragment in DEVICE_SOURCE for fragment in ["readonly, getter=isEnabled", "readonly) uint64_t generation", "copy, readonly) NSString *profileID", "copy, readonly) NSDictionary *specs"]))
    matrix.check("source: snapshot initializer copies reference fields", all(fragment in DEVICE_SOURCE for fragment in ["_profileID = [profileID copy]", "_deviceModel = [deviceModel copy]", "_specs = [specs copy]", "_source = [source copy]"]))
    matrix.check("source: deep copy recursively detaches dictionaries", "enumerateKeysAndObjectsUsingBlock" in deep_copy and "PXDeviceSpecDeepImmutableCopy(value)" in deep_copy and "return [copy copy]" in deep_copy)
    matrix.check("source: deep copy handles arrays and sets", "isKindOfClass:[NSArray class]" in deep_copy and "isKindOfClass:[NSSet class]" in deep_copy)
    matrix.check("source: profile ID rejects traversal", all(fragment in validator for fragment in ['isEqualToString:@".."', 'rangeOfString:@"/"', 'rangeOfString:@"\\\\"', "lastPathComponent"]))
    matrix.check("source: profile ID length is bounded", "profileID.length > 128" in validator)
    matrix.check("source: canonical identity snapshot is used", '#import "PXIdentitySnapshot.h"' in DEVICE_SOURCE and "PXCurrentIdentitySnapshot()" in builder and "identitySnapshot.profileID" in builder and "identitySnapshot.deviceIDs" in builder)
    matrix.check("source: legacy profile info fallback is supported", "PXLegacyActiveProfileInfoPath()" in PATHS_SOURCE and 'legacyInfo[@"currentProfileId"]' in PATHS_SOURCE)
    matrix.check("source: DeviceSpec performs no direct profile plist reads", DEVICE_SOURCE.count("dictionaryWithContentsOfFile") == 0 and builder.count("dictionaryWithContentsOfFile") == 0)
    matrix.check("source: hot snapshot getters perform no plist I/O", "dictionaryWithContentsOfFile" not in current_fn and "dictionaryWithContentsOfFile" not in active_fn)
    matrix.check("source: stable lock is initialized once", "dispatch_once" in source_function(DEVICE_SOURCE, "PXDeviceSpecSnapshotLockObject") and "gDeviceSpecSnapshotLock = [NSObject new]" in DEVICE_SOURCE)
    matrix.check("source: reload serializes generation and publication", "@synchronized(lock)" in reload_fn and "gDeviceSpecSnapshot = candidate" in reload_fn)
    matrix.check("source: generation comes from canonical identity snapshot", "uint64_t generation = [PXCurrentIdentitySnapshot() generation]" in reload_fn and "++gDeviceSpecSnapshotGeneration" not in DEVICE_SOURCE)
    build_position = reload_fn.index("candidate = PXBuildDeviceSpecSnapshot")
    publish_lock_position = reload_fn.rindex("@synchronized(lock)")
    matrix.check("source: expensive snapshot build occurs outside publication lock", build_position < publish_lock_position and "Build outside the publication lock" in reload_fn)
    matrix.check("source: snapshot build owns an autorelease pool", "@autoreleasepool" in reload_fn and "candidate = PXBuildDeviceSpecSnapshot" in reload_fn)
    matrix.check("source: stale concurrent candidates cannot overwrite newer generation", "candidate.generation > gDeviceSpecSnapshot.generation" in reload_fn)
    matrix.check("source: transient build failures retain last-known-good snapshot", "transientFailure && gDeviceSpecSnapshot" in reload_fn and "[DeviceSpec.snapshot.reject]" in reload_fn)
    matrix.check("source: intentional disabled snapshot is still publishable", 'isEqualToString:@"disabled"' not in reload_fn)
    matrix.check("source: recursive build guard is thread-local", "static __thread BOOL gDeviceSpecSnapshotBuildInProgress" in DEVICE_SOURCE and "gDeviceSpecSnapshotBuildInProgress = YES" in reload_fn)
    matrix.check("source: reload preserves errno", "int incomingErrno = errno" in reload_fn and "errno = incomingErrno" in reload_fn)
    matrix.check("source: current getter preserves errno", "int incomingErrno = errno" in current_fn and "errno = incomingErrno" in current_fn)
    matrix.check("source: scope denial publishes disabled snapshot", 'source:@"scope-denied"' in builder and "enabled:NO" in builder)
    matrix.check("source: manager enable state is canonical", "managerAvailable ? managerEnabled : profileFallbackEnabled" in builder and "managerEnabled ||" not in builder)
    matrix.check("source: profile enable is legacy fallback only", "profileFallbackEnabled = hasProfileEnableValue" in builder and "managerAvailable = identifierManager != nil" in builder)
    matrix.check("source: selected profile is the only model source", 'deviceIDs[@"DeviceModel"]' in builder and "currentValueForIdentifier" not in builder and "currentDeviceModel" not in builder)
    matrix.check("source: profile specs come from canonical identity snapshot", "specs = identitySnapshot.specs" in builder and 'identitySnapshot.source ?: @"device_ids"' in builder and "PXDeviceSpecificationsFromDeviceIDs" in reconstruct)
    matrix.check("source: manager specs are deep-copied for the locked profile model", "PXDeviceSpecDeepImmutableCopy(managerSpecs)" in builder and "deviceSpecificationsForModel:deviceModel" in builder)
    matrix.check("source: incomplete requested profile fails closed", "requestedEnabled && profileID.length && deviceModel.length && specs.count > 0" in builder and "effectiveEnabled ? specs : nil" in builder)
    matrix.check("source: notification rebuilds a new generation", "PXReloadDeviceSpecSnapshot" in refresh and "rebuilding immutable snapshot" in refresh)
    matrix.check("source: notification reload owns an autorelease pool", "@autoreleasepool" in refresh)

    observer_pos = DEVICE_SOURCE.index("CFNotificationCenterAddObserver")
    ctor_reload_pos = DEVICE_SOURCE.index('PXReloadDeviceSpecSnapshot(@"constructor")')
    provider_pos = DEVICE_SOURCE.index('registerSysctlBynameProvider:@"devicespec.sysctlbyname"')
    matrix.check("source: observers precede initial publication", observer_pos < ctor_reload_pos)
    matrix.check("source: initial publication precedes provider registration", ctor_reload_pos < provider_pos)
    matrix.check("source: old mutable caches are removed", not re.search(r"\b(?:scopedAppsCache|deviceSpecsCache|cacheTimestamp|cachedDeviceModel|cachedBundleDecisions)\b", DEVICE_SOURCE))
    matrix.check("source: legacy multi-read helpers are removed", all(name not in DEVICE_SOURCE for name in ["isSpoofingEnabled", "getSpoofedDeviceModel", "getDeviceSpecs", "loadScopedApps", "isInScopedAppsList"]))

    matrix.check("source: sysctl handler captures exactly one snapshot", sysctl_handler.count("PXActiveDeviceSpecSnapshot()") == 1 and "NSDictionary *specs = snapshot.specs" in sysctl_handler)
    matrix.check("source: sysctl results carry snapshot generation", "uint64_t generation = snapshot.generation" in sysctl_handler and sysctl_handler.count("generation,") == 15)
    matrix.check("source: result evidence includes generation", "generation=%llu" in result_logger and "uint64_t generation" in result_logger)
    matrix.check("source: memory percentage accepts caller specs", "getFreeMemoryPercentage(NSDictionary *specs)" in free_memory and "PXActiveDeviceSpecSnapshot" not in free_memory)
    matrix.check("source: memory buckets use same specs argument", "getFreeMemoryPercentage(specs)" in memory_stats and "PXActiveDeviceSpecSnapshot" not in memory_stats)
    matrix.check("source: host statistics captures one snapshot", host_stats.count("PXActiveDeviceSpecSnapshot()") == 1 and "NSDictionary *specs = snapshot.specs" in host_stats)
    matrix.check("source: NX architecture captures one snapshot", nx_hook.count("PXActiveDeviceSpecSnapshot()") == 1 and "NSDictionary *specs = snapshot.specs" in nx_hook)

    web_script = DEVICE_SOURCE[DEVICE_SOURCE.index("void PXInstallDeviceSpecUserScripts"):DEVICE_SOURCE.index("// Parse resolution string")]
    matrix.check("source: WebKit capability script is generation-tagged", "generationMarker" in web_script and "snapshot.generation" in web_script)
    matrix.check("source: generation placeholder remains extractor-safe", "Number('%llu')||1" in web_script)
    matrix.check("source: generation marker is replaceable", "delete globalThis.__weaponx_device_capabilities_generation__" in web_script and "writable:true" in web_script)
    matrix.check("source: newer or equal WebKit generation cannot overwrite", "if(current>=generation)return" in web_script)
    matrix.check("source: legacy capability invariant remains published", "__weaponx_device_capabilities__" in web_script)
    matrix.check("source: same WebKit generation is not installed twice", "containsString:generationMarker" in web_script)
    matrix.check("source: Canvas always delegates generation-aware capability install", "PXInstallDeviceSpecUserScripts(controller);" in CANVAS_SOURCE and "if (!hasCapabilities)" not in CANVAS_SOURCE)

    hot_methods = [
        ("- (CGRect)bounds", 1),
        ("- (CGRect)nativeBounds", 1),
        ("- (CGFloat)scale", 1),
        ("- (unsigned long long)physicalMemory", 1),
        ("- (unsigned long long)availableMemory", 1),
        ("- (NSUInteger)processorCount", 1),
        ("- (NSString *)machineHardwareName", 1),
        ("- (id)getParameter:(unsigned)pname", 1),
        ("- (NSString *)name", 1),
        ("- (NSString *)familyName", 1),
        ("- (CGFloat)nativeScale", 1),
        ("- (CGFloat)native_scale", 1),
        ("- (unsigned int)max_cpus", 1),
    ]
    hot_bodies = [logos_method(DEVICE_SOURCE, signature, occurrence) for signature, occurrence in hot_methods]
    matrix.check("source: every hot method captures one snapshot", all(body.count("PXActiveDeviceSpecSnapshot()") == 1 for body in hot_bodies))
    matrix.check("source: hot methods read specs from captured snapshot", all("snapshot.specs" in body for body in hot_bodies))
    matrix.check("source: hot methods contain no profile file reads", all("dictionaryWithContentsOfFile" not in body for body in hot_bodies))
    matrix.check("source: runtime snapshot evidence is emitted", "[DeviceSpec.snapshot] generation=%llu" in reload_fn)
    matrix.check("source: P1.2 probe checks generation linkage", "published_generations" in PROBE_SOURCE and "result_generations" in PROBE_SOURCE)


def run_model_matrix(matrix: Matrix) -> None:
    matrix.check("model: normal profile ID is accepted", validate_profile_id(" profile-123 ") == "profile-123")
    matrix.check("model: empty profile ID is rejected", validate_profile_id("   ") is None)
    matrix.check("model: parent traversal is rejected", validate_profile_id("../profile") is None and validate_profile_id("..") is None)
    matrix.check("model: Windows-style traversal is rejected", validate_profile_id(r"folder\profile") is None)
    matrix.check("model: oversized profile ID is rejected", validate_profile_id("a" * 129) is None)

    matrix.check("model: manager enable overrides legacy profile disable", resolve_requested_enabled(True, True, True, False))
    matrix.check("model: manager disable overrides legacy profile enable", not resolve_requested_enabled(True, False, True, True))
    matrix.check("model: unavailable manager falls back to profile enable", resolve_requested_enabled(False, False, True, True))
    matrix.check("model: unavailable manager without profile key stays disabled", not resolve_requested_enabled(False, False, False, False))

    profile = build_snapshot_model(
        1,
        True,
        "p1",
        "iPhone16,1",
        "iPhone15,2",
        {"model": "iPhone16,1", "cpu": "A17"},
        {"model": "iPhone15,2", "cpu": "A16"},
    )
    matrix.check("model: cached manager model cannot replace selected profile", profile.model == "iPhone16,1")
    matrix.check("model: profile specs stay paired with profile model", profile.specs is not None and profile.specs["cpu"] == "A17" and profile.source == "device_ids")

    manager_specs = build_snapshot_model(2, True, "p2", "iPhone15,2", "iPhone14,5", None, {"cpu": "A16"})
    matrix.check("model: manager specs fallback uses locked profile model", manager_specs.enabled and manager_specs.model == "iPhone15,2" and manager_specs.specs["cpu"] == "A16")

    manager_only = build_snapshot_model(3, True, "p3", None, "iPhone15,2", None, {"cpu": "A16"})
    matrix.check("model: manager-only cached model fails closed", not manager_only.enabled and manager_only.source == "missing-model")

    disabled = build_snapshot_model(3, False, "p3", "iPhone16,1", "iPhone16,1", {"cpu": "A17"}, {"cpu": "A17"})
    matrix.check("model: disabled request publishes no specs", not disabled.enabled and disabled.specs is None)

    missing = build_snapshot_model(4, True, "p4", "iPhone16,1", None, None, None)
    matrix.check("model: missing specs fails closed", not missing.enabled and missing.specs is None and missing.source == "missing-specs")

    immutable = build_snapshot_model(5, True, "p5", "iPhone16,1", None, {"cpu": "A17"}, None)
    mutation_blocked = False
    try:
        assert immutable.specs is not None
        immutable.specs["cpu"] = "A9"  # type: ignore[index]
    except TypeError:
        mutation_blocked = True
    matrix.check("model: published specs are immutable", mutation_blocked)


def publish_candidate_model(current: SnapshotModel | None, candidate: SnapshotModel) -> SnapshotModel:
    transient = candidate.source in {"exception", "missing-model", "missing-specs"}
    if transient and current is not None:
        return current
    if current is None or candidate.generation > current.generation:
        return candidate
    return current


def run_retention_matrix(matrix: Matrix) -> None:
    good = build_snapshot_model(10, True, "p10", "model-10", None, {"cpu": "A17"}, None)
    missing = build_snapshot_model(11, True, "p11", "model-11", None, None, None)
    retained = publish_candidate_model(good, missing)
    matrix.check("retention: missing specs cannot replace last-known-good", retained is good)

    exception = SnapshotModel(12, False, None, None, None, "exception")
    matrix.check("retention: exception cannot replace last-known-good", publish_candidate_model(good, exception) is good)

    disabled = SnapshotModel(13, False, "p13", "model-13", None, "disabled")
    matrix.check("retention: intentional disable replaces prior snapshot", publish_candidate_model(good, disabled) is disabled)

    initial_failure = SnapshotModel(1, False, None, None, None, "missing-model")
    matrix.check("retention: initial failure remains fail-open disabled", publish_candidate_model(None, initial_failure) is initial_failure)


def run_concurrency_matrix(matrix: Matrix) -> None:
    store = AtomicSnapshotStore()
    failures: list[str] = []
    stop = threading.Event()
    start_barrier = threading.Barrier(9)
    ready_barrier = threading.Barrier(9)
    read_counts = [0] * 8

    def reader(reader_index: int) -> None:
        start_barrier.wait()
        # Prove every reader has entered the critical read path before publishing.
        store.read()
        read_counts[reader_index] += 1
        ready_barrier.wait()
        while not stop.is_set():
            snapshot = store.read()
            read_counts[reader_index] += 1
            if not snapshot.enabled:
                continue
            assert snapshot.specs is not None
            expected_model = f"model-{snapshot.generation}"
            expected_cpu = f"cpu-{snapshot.generation}"
            if snapshot.model != expected_model or snapshot.specs.get("cpu") != expected_cpu:
                failures.append(
                    f"mixed generation={snapshot.generation} model={snapshot.model} specs={dict(snapshot.specs)}"
                )
                stop.set()

    readers = [threading.Thread(target=reader, args=(index,)) for index in range(8)]
    for thread in readers:
        thread.start()
    start_barrier.wait()
    ready_barrier.wait()

    for generation in range(1, 3001):
        specs = MappingProxyType({"cpu": f"cpu-{generation}", "memory": generation})
        store.publish(
            SnapshotModel(
                generation,
                True,
                f"profile-{generation}",
                f"model-{generation}",
                specs,
                "device_ids",
            )
        )
        if generation == 1:
            deadline = time.monotonic() + 1.0
            while not all(count > 1 for count in read_counts) and time.monotonic() < deadline:
                time.sleep(0.001)
        elif generation % 50 == 0:
            time.sleep(0)
        if failures:
            break

    stop.set()
    for thread in readers:
        thread.join()

    matrix.check("concurrency: readers were exercised during publication", all(count > 1 for count in read_counts))
    matrix.check("concurrency: readers never observe mixed generations", not failures)
    final = store.read()
    matrix.check("concurrency: generation publication is monotonic", final.generation == 3000)
    matrix.check("concurrency: final tuple remains coherent", final.model == "model-3000" and final.specs is not None and final.specs["cpu"] == "cpu-3000")


def main() -> None:
    matrix = Matrix()
    run_source_matrix(matrix)
    run_model_matrix(matrix)
    run_retention_matrix(matrix)
    run_concurrency_matrix(matrix)
    matrix.finish()


if __name__ == "__main__":
    main()
