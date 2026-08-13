#!/usr/bin/env python3
"""P1.3 subtype and ARM feature exposure regression matrix."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEVICE_PATH = ROOT / "TLinkIOSTweak" / "DeviceSpecHooks.x"
DEVICE_SOURCE = DEVICE_PATH.read_text(encoding="utf-8")

ALLOWED_SUBTYPES = {
    "CPU_SUBTYPE_ARM64_ALL",
    "CPU_SUBTYPE_ARM64_V8",
    "CPU_SUBTYPE_ARM64E",
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

X86_TOKENS = ("SSE", "AVX", "MMX", "X86")


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
            print(f"device spec P1.3 matrix: FAIL ({self.failed}/{self.total})")
            raise SystemExit(1)
        print(f"device spec P1.3 matrix: PASS ({self.total}/{self.total})")


@dataclass(frozen=True)
class Profile:
    token: str
    qualifier: str | None
    subtype: str
    feature_string: str


PROFILE_ROW = re.compile(
    r'^\s*\{\s*"(?P<token>[^"]+)",\s*'
    r'(?P<qualifier>NULL|"[^"]+"),\s*'
    r'"[^"]+",\s*'
    r'"[^"]+",\s*'
    r'(?P<subtype>CPU_SUBTYPE_[A-Z0-9_]+),\s*'
    r'0x[0-9A-Fa-f]+u,.*?'
    r'"(?P<features>[^"]*)"\s*\},\s*$',
    re.M,
)


def extract_profiles() -> list[Profile]:
    profiles: list[Profile] = []
    for match in PROFILE_ROW.finditer(DEVICE_SOURCE):
        qualifier = match.group("qualifier")
        profiles.append(
            Profile(
                token=match.group("token"),
                qualifier=None if qualifier == "NULL" else qualifier.strip('"'),
                subtype=match.group("subtype"),
                feature_string=match.group("features"),
            )
        )
    return profiles


PROFILES = extract_profiles()


def source_function(name: str) -> str:
    matches = list(
        re.finditer(
            rf"(?ms)^static\s+[^;{{}}]+?\b{re.escape(name)}\s*\([^;{{}}]*?\)\s*\{{",
            DEVICE_SOURCE,
        )
    )
    if not matches:
        raise RuntimeError(f"missing function: {name}")
    match = matches[-1]
    brace = DEVICE_SOURCE.index("{", match.start())
    depth = 0
    state = "code"
    quote = ""
    escaped = False
    index = brace
    while index < len(DEVICE_SOURCE):
        char = DEVICE_SOURCE[index]
        nxt = DEVICE_SOURCE[index + 1] if index + 1 < len(DEVICE_SOURCE) else ""
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
                    return DEVICE_SOURCE[match.start() : index + 1]
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


def extract_optional_map() -> dict[str, str]:
    table = re.search(
        r"static const PXDeviceCPUOptionalKey kPXDeviceCPUOptionalKeys\[\] = \{(.*?)\n\};",
        DEVICE_SOURCE,
        re.S,
    )
    if not table:
        raise RuntimeError("missing optional whitelist")
    return dict(
        re.findall(
            r'\{\s*"([^"]+)"\s*,\s*(PXDeviceCPUFeature[A-Za-z0-9_]+)\s*\}',
            table.group(1),
        )
    )


OPTIONAL_MAP = extract_optional_map()


def has_token(architecture: str, token: str) -> bool:
    upper_architecture = architecture.upper()
    upper_token = token.upper()
    start = 0
    while start < len(upper_architecture):
        index = upper_architecture.find(upper_token, start)
        if index < 0:
            return False
        end = index + len(upper_token)
        before_boundary = index == 0 or not upper_architecture[index - 1].isalnum()
        after_boundary = end == len(upper_architecture) or not upper_architecture[end].isalnum()
        if before_boundary and after_boundary:
            return True
        start = index + 1
    return False


def feature_string_is_arm_only(feature_string: str) -> bool:
    upper = feature_string.upper()
    return not any(token in upper for token in X86_TOKENS)


def profile_usable(profile: Profile, subtype_override: str | None = None, feature_override: str | None = None) -> bool:
    subtype = subtype_override or profile.subtype
    features = profile.feature_string if feature_override is None else feature_override
    return subtype in ALLOWED_SUBTYPES and feature_string_is_arm_only(features)


def resolve_profile(architecture: str) -> Profile | None:
    for profile in PROFILES:
        if not has_token(architecture, profile.token):
            continue
        if profile.qualifier and not has_token(architecture, profile.qualifier):
            continue
        return profile if profile_usable(profile) else None
    return None


def lookup_optional(name: str, enabled_features: set[str]) -> tuple[bool, int | None]:
    feature = OPTIONAL_MAP.get(name)
    if feature is None:
        return False, None
    return True, 1 if feature in enabled_features else 0


def run_source_matrix(matrix: Matrix) -> None:
    subtype_validator = source_function("PXCPUProfileHasSupportedSubtype")
    ascii_contains = source_function("PXASCIIContainsCaseInsensitive")
    arm_feature_validator = source_function("PXCPUFeatureStringIsARMOnly")
    profile_validator = source_function("PXCPUProfileIsUsable")
    profile_resolver = source_function("PXCPUProfileForArchitecture")
    arch_name = source_function("PXCPUArchNameForSubtype")
    optional_lookup = source_function("PXOptionalFeatureValue")
    core_count = source_function("PXCPUCoreCountFromSpecs")
    nx_hook = source_function("hook_nx_get_local_arch_info")
    provider = source_function("handleDeviceSpecSysctlByname")

    matrix.check("source: imports public Mach subtype definitions", '#import <mach/machine.h>' in DEVICE_SOURCE)
    matrix.check("source: no local numeric ARM64 subtype fallback", not re.search(r"#\s*define\s+CPU_SUBTYPE_ARM64\w*\s+.*\b(?:[0-9]|1[0-3])\b", DEVICE_SOURCE))
    matrix.check("source: no raw subtype assignment 2-13", not re.search(r"(?:cpuSubtype|cpusubtype)\s*=\s*(?:\([^)]*\)\s*)?(?:[2-9]|1[0-3])\b", DEVICE_SOURCE))
    matrix.check("source: profile table uses only public subtype symbols", bool(PROFILES) and {p.subtype for p in PROFILES} <= ALLOWED_SUBTYPES)
    matrix.check("source: subtype validator allows ARM64_ALL", "case CPU_SUBTYPE_ARM64_ALL:" in subtype_validator)
    matrix.check("source: subtype validator allows ARM64_V8", "case CPU_SUBTYPE_ARM64_V8:" in subtype_validator)
    matrix.check("source: subtype validator allows ARM64E", "case CPU_SUBTYPE_ARM64E:" in subtype_validator)
    matrix.check("source: subtype validator rejects all other values", "default:" in subtype_validator and "return NO;" in subtype_validator)
    matrix.check("source: architecture name maps only public subtype classes", all(token in arch_name for token in ["CPU_SUBTYPE_ARM64_ALL", "CPU_SUBTYPE_ARM64_V8", "CPU_SUBTYPE_ARM64E", 'return "arm64"', 'return "arm64e"', "return NULL"]))
    matrix.check("source: matched malformed profile fails open", "return PXCPUProfileIsUsable(profile) ? profile : NULL;" in profile_resolver)
    matrix.check("source: profile validator combines subtype and ARM feature checks", "PXCPUProfileHasSupportedSubtype" in profile_validator and "PXCPUFeatureStringIsARMOnly" in profile_validator)
    matrix.check("source: unknown core profile returns zero", "return profile ? profile->defaultCoreCount : 0;" in core_count)
    matrix.check("source: NX unknown profile preserves original", "if (!profile) return original;" in nx_hook)
    matrix.check("source: NX invalid subtype preserves original", "if (!archName) return original;" in nx_hook)
    matrix.check("source: NX uses canonical subtype name helper", "PXCPUArchNameForSubtype(profile->cpuSubtype)" in nx_hook)
    matrix.check("source: sysctl subtype is profile-gated", 'if (profile && strcmp(name, "hw.cpusubtype") == 0)' in provider)
    matrix.check("source: optional whitelist is exact", set(OPTIONAL_MAP) == EXPECTED_OPTIONAL_KEYS)
    matrix.check("source: optional lookup uses exact strcmp", "strcmp(name, optionalKey->name) == 0" in optional_lookup)
    matrix.check("source: optional lookup has no default YES", "*outValue = 1" not in optional_lookup and "return NO;" in optional_lookup)
    matrix.check("source: handler synthesizes only whitelist hits", "profile && PXOptionalFeatureValue(name, profile, &optionalValue)" in provider)
    matrix.check("source: unknown optional key falls through to coordinator original", 'if (strncmp(name, "hw.optional.", 12) == 0)' in provider and "return NO;" in provider[provider.index('if (strncmp(name, "hw.optional.", 12) == 0)'):])
    matrix.check("source: known optional keys preserve kernel existence", "PXWriteExistingSysctlBytes" in provider[provider.index("optionalValue"):provider.index('if (strncmp(name, "hw.optional.", 12) == 0)')])
    matrix.check("source: x86 optional keys are absent", not any(any(token.lower() in key.lower() for token in X86_TOKENS) for key in OPTIONAL_MAP))
    matrix.check("source: public arm64e optional key is not invented", "hw.optional.arm64e" not in OPTIONAL_MAP)
    matrix.check("source: feature flags have no synthetic ARM64E capability bit", "PXDeviceCPUFeatureARM64E" not in DEVICE_SOURCE)
    matrix.check("source: x86 guard is allocation-free ASCII matching", "strncasecmp" in ascii_contains and "NSString" not in ascii_contains)
    matrix.check("source: ARM feature validator rejects SSE", '"SSE"' in arm_feature_validator)
    matrix.check("source: ARM feature validator rejects AVX", '"AVX"' in arm_feature_validator)
    matrix.check("source: ARM feature validator rejects MMX/X86", '"MMX"' in arm_feature_validator and '"X86"' in arm_feature_validator)
    matrix.check("source: hw.cpu.features is profile-gated", 'if (profile && strcmp(name, "hw.cpu.features") == 0)' in provider)
    matrix.check("source: emitted profile feature strings contain no x86 ISA", all(feature_string_is_arm_only(profile.feature_string) for profile in PROFILES))


def run_semantic_matrix(matrix: Matrix) -> None:
    matrix.check("model: canonical profile count remains stable", len(PROFILES) == 15)
    matrix.check("model: ARM64_ALL is an accepted ABI subtype", "CPU_SUBTYPE_ARM64_ALL" in ALLOWED_SUBTYPES)
    matrix.check("model: raw subtype 3 is rejected", not profile_usable(PROFILES[0], subtype_override="3"))
    matrix.check("model: raw subtype 13 is rejected", not profile_usable(PROFILES[0], subtype_override="13"))
    matrix.check("model: SSE feature string is rejected", not profile_usable(PROFILES[0], feature_override="NEON AES SSE4.2"))
    matrix.check("model: AVX feature string is rejected", not profile_usable(PROFILES[0], feature_override="NEON AES AVX2"))
    matrix.check("model: unknown architecture preserves original", resolve_profile("Unknown Custom SoC") is None)
    matrix.check("model: A180 does not alias A18", resolve_profile("Apple A180") is None)
    matrix.check("model: M10 does not alias M1", resolve_profile("Apple M10") is None)
    matrix.check("model: A9-A11 use ARM64_V8", all(resolve_profile(f"Apple {token}").subtype == "CPU_SUBTYPE_ARM64_V8" for token in ["A9", "A10", "A11"]))
    matrix.check("model: A12+ and M-series use ARM64E", all(resolve_profile(f"Apple {token}").subtype == "CPU_SUBTYPE_ARM64E" for token in ["A12", "A13", "A14", "A15", "A16", "A17", "A18", "M1", "M2"]))

    known_true, true_value = lookup_optional("hw.optional.arm64", {"PXDeviceCPUFeatureARM64"})
    matrix.check("model: whitelisted enabled feature returns one", known_true and true_value == 1)
    known_false, false_value = lookup_optional("hw.optional.arm.FEAT_LRCPC", set())
    matrix.check("model: whitelisted disabled feature returns zero", known_false and false_value == 0)
    unknown, unknown_value = lookup_optional("hw.optional.future_unknown", {"PXDeviceCPUFeatureARM64"})
    matrix.check("model: unknown optional key preserves original", not unknown and unknown_value is None)
    sse_known, sse_value = lookup_optional("hw.optional.sse4_2", set(OPTIONAL_MAP.values()))
    matrix.check("model: SSE optional key is never synthesized", not sse_known and sse_value is None)
    avx_known, avx_value = lookup_optional("hw.optional.avx2_0", set(OPTIONAL_MAP.values()))
    matrix.check("model: AVX optional key is never synthesized", not avx_known and avx_value is None)


def main() -> None:
    matrix = Matrix()
    run_source_matrix(matrix)
    run_semantic_matrix(matrix)
    matrix.finish()


if __name__ == "__main__":
    main()
