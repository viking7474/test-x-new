#!/usr/bin/env python3
"""P1.1 source and semantic matrix for DeviceSpec CPU/memory spoofing.

The matrix intentionally stays host-runnable: it validates source ownership and
models sysctl serializer/memory contracts without requiring an iOS SDK runtime.
"""

from __future__ import annotations

import errno as errno_module
import re
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEVICE_PATH = ROOT / "ProjectXTweak" / "DeviceSpecHooks.x"
TWEAK_PATH = ROOT / "ProjectXTweak" / "Tweak.x"
PROBE_PATH = ROOT / "scripts" / "probe_device_spec_p1_1.sh"
DEVICE_SOURCE = DEVICE_PATH.read_text(encoding="utf-8")
TWEAK_SOURCE = TWEAK_PATH.read_text(encoding="utf-8")
PROBE_SOURCE = PROBE_PATH.read_text(encoding="utf-8")


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
            print(f"device spec P1.1 matrix: FAIL ({self.failed}/{self.total})")
            raise SystemExit(1)
        print(f"device spec P1.1 matrix: PASS ({self.total}/{self.total})")


@dataclass(frozen=True)
class CPUProfile:
    token: str
    qualifier: str | None
    brand: str
    arch_description: str
    subtype: str
    family: int
    cores: int
    min_hz: int
    max_hz: int
    l1i: int
    l1d: int
    l2: int
    cache_line: int
    flags: str
    feature_string: str


PROFILE_ROW = re.compile(
    r'^\s*\{\s*"(?P<token>[^"]+)",\s*'
    r'(?P<qualifier>NULL|"[^"]+"),\s*'
    r'"(?P<brand>[^"]+)",\s*'
    r'"(?P<arch>[^"]+)",\s*'
    r'(?P<subtype>CPU_SUBTYPE_[A-Z0-9_]+),\s*'
    r'(?P<family>0x[0-9A-Fa-f]+)u,\s*'
    r'(?P<cores>\d+)u,\s*'
    r'(?P<min_hz>\d+)ULL,\s*'
    r'(?P<max_hz>\d+)ULL,\s*'
    r'(?P<l1i>\d+)ULL,\s*'
    r'(?P<l1d>\d+)ULL,\s*'
    r'(?P<l2>\d+)ULL,\s*'
    r'(?P<cache_line>\d+)u,\s*'
    r'(?P<flags>[A-Z0-9_]+),\s*'
    r'"(?P<features>[^"]*)"\s*\},\s*$',
    re.M,
)


def extract_profiles() -> list[CPUProfile]:
    profiles: list[CPUProfile] = []
    for match in PROFILE_ROW.finditer(DEVICE_SOURCE):
        qualifier_raw = match.group("qualifier")
        profiles.append(
            CPUProfile(
                token=match.group("token"),
                qualifier=None if qualifier_raw == "NULL" else qualifier_raw.strip('"'),
                brand=match.group("brand"),
                arch_description=match.group("arch"),
                subtype=match.group("subtype"),
                family=int(match.group("family"), 16),
                cores=int(match.group("cores")),
                min_hz=int(match.group("min_hz")),
                max_hz=int(match.group("max_hz")),
                l1i=int(match.group("l1i")),
                l1d=int(match.group("l1d")),
                l2=int(match.group("l2")),
                cache_line=int(match.group("cache_line")),
                flags=match.group("flags"),
                feature_string=match.group("features"),
            )
        )
    return profiles


PROFILES = extract_profiles()

EXPECTED_FAMILIES = {
    ("A9", None): 0x92FB37C8,
    ("A10", None): 0x67CEEE93,
    ("A11", None): 0xE81E7EF6,
    ("A12", None): 0x07D34B9F,
    ("A12X", None): 0x07D34B9F,
    ("A12Z", None): 0x07D34B9F,
    ("A13", None): 0x462504D2,
    ("A14", None): 0x1B588BB3,
    ("A15", None): 0xDA33D83D,
    ("A16", None): 0x8765EDEA,
    ("A17", None): 0x2876F5B5,
    ("A18", None): 0x204526D0,
    ("A18", "PRO"): 0x75D4ACB9,
    ("M1", None): 0x1B588BB3,
    ("M2", None): 0xDA33D83D,
}

EXPECTED_FLAG_TOKENS = {
    "PX_CPU_BASE_FLAGS": {"NEON", "AES", "CRC32"},
    "PX_CPU_ATOMICS_FLAGS": {"NEON", "AES", "CRC32", "ATOMICS"},
    "PX_CPU_ARM64E_FLAGS": {"NEON", "AES", "CRC32", "ATOMICS", "FCMA"},
    "PX_CPU_ARM64E_FP16_FLAGS": {"NEON", "AES", "CRC32", "ATOMICS", "FCMA", "FP16", "JSCVT"},
    "PX_CPU_ARM64E_LRCPC_FLAGS": {"NEON", "AES", "CRC32", "ATOMICS", "FCMA", "FP16", "JSCVT", "LRCPC"},
}

EXPECTED_OPTIONAL_KEYS = {
    "hw.optional.arm64",
    "hw.optional.neon",
    "hw.optional.neon_fp16",
    "hw.optional.armv8_crc32",
    "hw.optional.armv8_1_atomics",
    "hw.optional.armv8_3_compnum",
    "hw.optional.arm.AdvSIMD",
    "hw.optional.arm.FEAT_AES",
    "hw.optional.arm.FEAT_CRC32",
    "hw.optional.arm.FEAT_LSE",
    "hw.optional.arm.FEAT_FCMA",
    "hw.optional.arm.FEAT_FP16",
    "hw.optional.arm.FEAT_JSCVT",
    "hw.optional.arm.FEAT_LRCPC",
}


def extract_optional_keys() -> set[str]:
    match = re.search(
        r"static const PXDeviceCPUOptionalKey kPXDeviceCPUOptionalKeys\[\] = \{(.*?)\n\};",
        DEVICE_SOURCE,
        re.S,
    )
    if not match:
        raise RuntimeError("missing optional-key table")
    return set(re.findall(r'\{\s*"([^"]+)"\s*,', match.group(1)))


OPTIONAL_KEYS = extract_optional_keys()


def has_token(architecture: str, token: str) -> bool:
    """Python model of PXCPUArchitectureHasToken."""
    upper_architecture = architecture.upper()
    upper_token = token.upper()
    start = 0
    while start < len(upper_architecture):
        index = upper_architecture.find(upper_token, start)
        if index < 0:
            return False
        end = index + len(upper_token)
        before_boundary = index == 0 or not upper_architecture[index - 1].isalnum()
        after_boundary = end >= len(upper_architecture) or not upper_architecture[end].isalnum()

        if not after_boundary and upper_token == "A12" and end < len(upper_architecture):
            suffix = upper_architecture[end]
            suffix_end = end + 1
            suffix_boundary = suffix_end >= len(upper_architecture) or not upper_architecture[suffix_end].isalnum()
            after_boundary = suffix in {"X", "Z"} and suffix_boundary

        if before_boundary and after_boundary:
            return True
        start = index + 1
    return False


def resolve_profile(architecture: str) -> CPUProfile | None:
    for profile in PROFILES:
        if not has_token(architecture, profile.token):
            continue
        if profile.qualifier and not has_token(architecture, profile.qualifier):
            continue
        return profile
    return None


@dataclass(frozen=True)
class SysctlResult:
    handled: bool
    result: int
    errno_value: int
    required_size: int
    original_calls: int = 0


def write_bytes(value_size: int, has_buffer: bool, capacity: int, incoming_errno: int) -> SysctlResult:
    if not has_buffer:
        return SysctlResult(True, 0, incoming_errno, value_size)
    if capacity < value_size:
        return SysctlResult(True, -1, errno_module.ENOMEM, value_size)
    return SysctlResult(True, 0, incoming_errno, value_size)


def write_existing(
    value_size: int,
    has_buffer: bool,
    capacity: int,
    incoming_errno: int,
    original_result: int,
    original_errno: int,
) -> SysctlResult:
    calls = 1
    if original_result != 0 and original_errno != errno_module.ENOMEM:
        return SysctlResult(True, original_result, original_errno, capacity, calls)
    result = write_bytes(value_size, has_buffer, capacity, incoming_errno)
    return SysctlResult(
        result.handled,
        result.result,
        result.errno_value,
        result.required_size,
        calls,
    )


def memory_buckets(total: int, free_fraction: float) -> tuple[int, int, int, int]:
    normalized = max(0.10, min(0.70, free_fraction))
    free = int(total * normalized)
    remaining = max(0, total - free)
    wired = (remaining * 4) // 13
    active = (remaining * 6) // 13
    inactive = remaining - wired - active
    return free, wired, active, inactive


def source_function(source: str, name: str) -> str:
    # Match a definition whose signature may span lines; prototypes terminate at
    # ';' and therefore cannot satisfy the final opening-brace requirement.
    match = re.search(
        rf"(?ms)^static\s+[^;{{}}]+?\b{re.escape(name)}\s*\([^;{{}}]*?\)\s*\{{",
        source,
    )
    if not match:
        raise RuntimeError(f"missing function: {name}")
    brace = source.index("{", match.start())
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
    provider_region = DEVICE_SOURCE[
        DEVICE_SOURCE.index('registerSysctlBynameProvider:@"devicespec.sysctlbyname"') - 250 :
        DEVICE_SOURCE.index('registerSysctlBynameProvider:@"devicespec.sysctlbyname"') + 1600
    ]
    serializer = source_function(DEVICE_SOURCE, "PXWriteExistingSysctlBytes")
    core_resolver = source_function(DEVICE_SOURCE, "PXCPUCoreCountFromSpecs")
    nx_hook = source_function(DEVICE_SOURCE, "hook_nx_get_local_arch_info")
    memory_hook = source_function(DEVICE_SOURCE, "hook_host_statistics64")
    memory_log = source_function(DEVICE_SOURCE, "logMemoryHook")
    result_logger = source_function(DEVICE_SOURCE, "PXCompleteDeviceSpecSysctlResult")
    device_provider = source_function(DEVICE_SOURCE, "handleDeviceSpecSysctlByname")
    tweak_provider = source_function(TWEAK_SOURCE, "sysctlbyname_hook")

    matrix.check("source: DeviceSpec registers a named coordinator provider", 'registerSysctlBynameProvider:@"devicespec.sysctlbyname"' in provider_region)
    matrix.check("source: DeviceSpec provider is selective pre-only", "pre:^BOOL" in provider_region and "post:nil" in provider_region)
    matrix.check("source: provider registration requires coordinator original", "if (orig_sysctlbyname_device_spec)" in provider_region)
    matrix.check("source: provider registration emits runtime evidence", "[DeviceSpec.provider] registered=%d original=%d" in DEVICE_SOURCE)
    matrix.check("source: runtime probe validates provider and terminal results", "\\[DeviceSpec.provider\\] registered=1 original=1" in PROBE_SOURCE and "\\[DeviceSpec.sysctlbyname.result\\]" in PROBE_SOURCE)
    matrix.check("source: old post-provider implementation removed", "applyDeviceSpecSysctlBynamePost" not in DEVICE_SOURCE)
    matrix.check("source: DeviceSpec never directly hooks sysctlbyname", not re.search(r"MSHookFunction\([^;]*sysctlbyname", DEVICE_SOURCE, re.S))
    matrix.check("source: existence helper calls original exactly once", serializer.count("orig_sysctlbyname_device_spec(") == 1)
    matrix.check("source: existence helper preserves non-ENOMEM original failures", "originalErrno != ENOMEM" in serializer and "errno = originalErrno" in serializer)
    matrix.check("source: successful existence transform restores incoming errno", "int incomingErrno = errno;" in serializer and "errno = incomingErrno;" in serializer)
    matrix.check("source: direct serializer reports required size", "*oldlenp = valueSize;" in source_function(DEVICE_SOURCE, "PXWriteSysctlBytes"))
    matrix.check("source: direct serializer returns ENOMEM for short buffer", "errno = ENOMEM;" in source_function(DEVICE_SOURCE, "PXWriteSysctlBytes"))
    matrix.check("source: unknown CPU architecture fails open as one unit", "return profile ? profile->defaultCoreCount : 0;" in core_resolver)
    matrix.check("source: Tweak no longer claims physical CPU keys", all(key not in tweak_provider for key in ["hw.physicalcpu", "hw.logicalcpu", "hw.ncpu", "hw.activecpu"]))
    matrix.check("source: DeviceSpec owns all topology keys", all(key in device_provider for key in ["hw.physicalcpu", "hw.physicalcpu_max", "hw.logicalcpu", "hw.logicalcpu_max", "hw.ncpu", "hw.activecpu"]))
    matrix.check("source: CPU qualifier uses boundary matcher", "PXCPUArchitectureHasToken(architecture, qualifier)" in DEVICE_SOURCE)
    matrix.check("source: NXArchInfo copy is thread-local", "static __thread NXArchInfo" in DEVICE_SOURCE)
    matrix.check("source: NXArchInfo sets complete ABI identity", all(field in nx_hook for field in [".name =", ".cputype =", ".cpusubtype =", ".description ="]))
    matrix.check("source: memory log registry is synchronized", "@synchronized(hookedMemoryAPIs)" in memory_log and "dispatch_once" in memory_log)
    matrix.check("source: sysctl result counter is atomic", "__sync_fetch_and_add(&resultLogCount" in result_logger)
    matrix.check("source: sysctl result logging preserves errno", "int resultErrno = errno;" in result_logger and "errno = resultErrno;" in result_logger)
    matrix.check("source: handled sysctl paths emit result evidence", device_provider.count("PXCompleteDeviceSpecSysctlResult") >= 15)
    matrix.check("source: VM64 write is count-gated", "*count >= HOST_VM_INFO64_COUNT" in memory_hook)
    matrix.check("source: VM32 write is count-gated", "*count >= HOST_VM_INFO_COUNT" in memory_hook)
    matrix.check("source: HOST_BASIC_INFO write is count-gated", "*count >= HOST_BASIC_INFO_COUNT" in memory_hook)
    matrix.check("source: CPU feature string contains no x86 ISA tokens", not re.search(r"\b(?:SSE|AVX|MMX)\b", DEVICE_SOURCE))
    matrix.check("source: optional-feature whitelist is exact", OPTIONAL_KEYS == EXPECTED_OPTIONAL_KEYS)
    matrix.check("source: optional-feature whitelist does not invent arm64e key", "hw.optional.arm64e" not in OPTIONAL_KEYS)
    matrix.check("source: legacy standalone CPU core table removed from Tweak", "CPU INFO SPOOFING" not in TWEAK_SOURCE and "int64_t cores =" not in TWEAK_SOURCE)


def run_profile_matrix(matrix: Matrix) -> None:
    matrix.check("profile: expected canonical row count", len(PROFILES) == 15)
    matrix.check("profile: every row has a nonzero family", all(profile.family > 0 for profile in PROFILES))
    matrix.check("profile: every row has a sane core count", all(1 <= profile.cores <= 16 for profile in PROFILES))
    matrix.check("profile: every row has ordered frequencies", all(0 < profile.min_hz <= profile.max_hz for profile in PROFILES))
    matrix.check("profile: every row uses 64-byte cache lines", all(profile.cache_line == 64 for profile in PROFILES))
    matrix.check("profile: every row has positive cache geometry", all(min(profile.l1i, profile.l1d, profile.l2) > 0 for profile in PROFILES))
    actual_families = {(profile.token, profile.qualifier): profile.family for profile in PROFILES}
    matrix.check("profile: every canonical cpufamily mapping is exact", actual_families == EXPECTED_FAMILIES)
    matrix.check("profile: feature flags and feature strings agree", all(
        EXPECTED_FLAG_TOKENS.get(profile.flags) is not None
        and EXPECTED_FLAG_TOKENS[profile.flags].issubset(set(profile.feature_string.split()))
        for profile in PROFILES
    ))
    matrix.check("profile: no modeled feature is present only in the string", all(
        not (({"ATOMICS", "FCMA", "FP16", "JSCVT", "LRCPC"} & set(profile.feature_string.split()))
             - EXPECTED_FLAG_TOKENS[profile.flags])
        for profile in PROFILES
    ))
    matrix.check("profile: row tokens are intentionally unique except A18", [profile.token for profile in PROFILES].count("A18") == 2 and all([profile.token for profile in PROFILES].count(token) == 1 for token in {p.token for p in PROFILES if p.token != "A18"}))
    matrix.check("profile: A18 Pro row precedes generic A18", [(p.token, p.qualifier) for p in PROFILES].index(("A18", "PRO")) < [(p.token, p.qualifier) for p in PROFILES].index(("A18", None)))
    matrix.check("profile: A12X/A12Z rows precede generic A12", max([p.token for p in PROFILES].index("A12X"), [p.token for p in PROFILES].index("A12Z")) < [p.token for p in PROFILES].index("A12"))

    a18_pro = resolve_profile("Apple A18 Pro")
    a18 = resolve_profile("Apple A18")
    a18_professional = resolve_profile("Apple A18 Professional")
    a12x = resolve_profile("Apple A12X Bionic")
    a12z = resolve_profile("Apple A12Z Bionic")

    matrix.check("profile: exact A18 Pro qualifier selects Pro row", a18_pro is not None and a18_pro.brand == "Apple A18 Pro")
    matrix.check("profile: generic A18 selects non-Pro row", a18 is not None and a18.brand == "Apple A18")
    matrix.check("profile: qualifier is not a substring match", a18_professional is not None and a18_professional.brand == "Apple A18")
    matrix.check("profile: A12X resolves before A12 family fallback", a12x is not None and a12x.token == "A12X")
    matrix.check("profile: A12Z resolves before A12 family fallback", a12z is not None and a12z.token == "A12Z")
    matrix.check("profile: A180 does not alias A18", resolve_profile("Apple A180") is None)
    matrix.check("profile: M10 does not alias M1", resolve_profile("Apple M10") is None)
    matrix.check("profile: unknown architecture fails open", resolve_profile("Unknown Custom SoC") is None)
    matrix.check("profile: legacy A9-A11 expose ARM64 V8 subtype", all(resolve_profile(f"Apple {token}").subtype == "CPU_SUBTYPE_ARM64_V8" for token in ["A9", "A10", "A11"]))
    matrix.check("profile: A12+ and M-series expose ARM64E subtype", all(resolve_profile(f"Apple {token}").subtype == "CPU_SUBTYPE_ARM64E" for token in ["A12", "A13", "A14", "A15", "A16", "A17", "A18", "M1", "M2"]))


def run_serializer_matrix(matrix: Matrix) -> None:
    incoming = errno_module.EBUSY

    size_query = write_bytes(8, False, 0, incoming)
    matrix.check("serializer: size query succeeds", size_query.result == 0 and size_query.required_size == 8)
    matrix.check("serializer: size query preserves incoming errno", size_query.errno_value == incoming)

    exact = write_bytes(8, True, 8, incoming)
    matrix.check("serializer: exact buffer succeeds", exact.result == 0 and exact.required_size == 8)
    matrix.check("serializer: exact buffer preserves incoming errno", exact.errno_value == incoming)

    short = write_bytes(8, True, 4, incoming)
    matrix.check("serializer: short buffer reports ENOMEM", short.result == -1 and short.errno_value == errno_module.ENOMEM)
    matrix.check("serializer: short buffer reports required size", short.required_size == 8)

    absent = write_existing(8, True, 8, incoming, -1, errno_module.ENOENT)
    matrix.check("serializer: absent kernel key preserves ENOENT", absent.result == -1 and absent.errno_value == errno_module.ENOENT)
    matrix.check("serializer: absent kernel key calls original once", absent.original_calls == 1)

    exists = write_existing(8, True, 8, incoming, 0, 0)
    matrix.check("serializer: existing key transforms successfully", exists.result == 0 and exists.required_size == 8)
    matrix.check("serializer: successful transform preserves incoming errno", exists.errno_value == incoming)
    matrix.check("serializer: successful transform calls original once", exists.original_calls == 1)

    real_too_large_but_spoof_fits = write_existing(4, True, 4, incoming, -1, errno_module.ENOMEM)
    matrix.check("serializer: original ENOMEM may become spoof success", real_too_large_but_spoof_fits.result == 0)
    matrix.check("serializer: recovered ENOMEM restores incoming errno", real_too_large_but_spoof_fits.errno_value == incoming)

    spoof_too_large = write_existing(8, True, 4, incoming, -1, errno_module.ENOMEM)
    matrix.check("serializer: spoofed value still enforces caller capacity", spoof_too_large.result == -1 and spoof_too_large.errno_value == errno_module.ENOMEM)
    matrix.check("serializer: spoofed ENOMEM reports spoofed required size", spoof_too_large.required_size == 8)


def run_memory_matrix(matrix: Matrix) -> None:
    totals = [1 << 30, 3 << 30, 6 << 30, 64 << 30]
    fractions = [-1.0, 0.10, 0.35, 0.70, 2.0]
    samples = [memory_buckets(total, fraction) for total in totals for fraction in fractions]

    matrix.check("memory: buckets always sum exactly to total", all(sum(bucket) == total for total in totals for bucket in [memory_buckets(total, fraction) for fraction in fractions]))
    matrix.check("memory: buckets are never negative", all(all(value >= 0 for value in bucket) for bucket in samples))
    matrix.check("memory: free fraction is clamped to 10 percent", memory_buckets(1000, -1.0)[0] == 100)
    matrix.check("memory: free fraction is clamped to 70 percent", memory_buckets(1000, 2.0)[0] == 700)
    matrix.check("memory: inactive absorbs integer remainder", all(bucket[3] == total - bucket[0] - bucket[1] - bucket[2] for total in totals for bucket in [memory_buckets(total, 0.35)]))
    matrix.check("memory: 64 GB conversion fits uint64", (64 * 1024**3) < 2**64)
    matrix.check("memory: legacy hw.physmem saturation is explicit", "totalMemory > UINT32_MAX ? UINT32_MAX" in DEVICE_SOURCE)
    matrix.check("memory: hw.memsize uses uint64 serializer", "PXWriteSysctlBytes(&totalMemory, sizeof(totalMemory)" in DEVICE_SOURCE)


def main() -> None:
    matrix = Matrix()
    run_source_matrix(matrix)
    run_profile_matrix(matrix)
    run_serializer_matrix(matrix)
    run_memory_matrix(matrix)
    matrix.finish()


if __name__ == "__main__":
    main()
