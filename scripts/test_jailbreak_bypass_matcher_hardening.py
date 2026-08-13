#!/usr/bin/env python3
"""Table-driven semantic matrix for JailbreakBypassHooks matcher hardening."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = ROOT / "TLinkIOSTweak" / "JailbreakBypassHooks.x"
SOURCE = SOURCE_PATH.read_text(encoding="utf-8")


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
            print(f"matcher hardening matrix: FAIL ({self.failed}/{self.total})")
            raise SystemExit(1)
        print(f"matcher hardening matrix: PASS ({self.total}/{self.total})")


def extract_c_string_array(name: str) -> list[str]:
    pattern = re.compile(
        rf"static const char \*const {re.escape(name)}\[\] = \{{(.*?)\n\}};",
        re.S,
    )
    match = pattern.search(SOURCE)
    if not match:
        raise RuntimeError(f"missing C string array: {name}")
    return re.findall(r'"((?:\\.|[^"\\])*)"', match.group(1))


def extract_path_rule_array(name: str) -> list[str]:
    pattern = re.compile(
        rf"static const PXJBStaticPathRule {re.escape(name)}\[\] = \{{(.*?)\n\}};",
        re.S,
    )
    match = pattern.search(SOURCE)
    if not match:
        raise RuntimeError(f"missing path rule array: {name}")
    return re.findall(r'PXJB_PATH_RULE\("((?:\\.|[^"\\])*)"\)', match.group(1))


def source_function(name: str) -> str:
    match = re.search(rf"(?m)^static [^\n]+\b{re.escape(name)}\([^\n]*\) \{{", SOURCE)
    if not match:
        raise RuntimeError(f"missing function: {name}")
    brace = SOURCE.index("{", match.start())
    depth = 0
    state = "code"
    quote = ""
    escaped = False
    index = brace
    while index < len(SOURCE):
        char = SOURCE[index]
        nxt = SOURCE[index + 1] if index + 1 < len(SOURCE) else ""
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
                    return SOURCE[match.start() : index + 1]
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


EXACT_BASENAMES = extract_c_string_array("kPXJBArtifactExactBasenames")
BASENAME_PREFIXES = extract_c_string_array("kPXJBArtifactBasenamePrefixes")
EXACT_COMPONENTS = extract_c_string_array("kPXJBArtifactExactComponents")
ABSOLUTE_PREFIXES = extract_c_string_array("kPXJBArtifactAbsolutePrefixes")
RELATIVE_EXACT = extract_c_string_array("kPXJBArtifactRelativeExactSequences")
RELATIVE_PREFIXES = extract_c_string_array("kPXJBArtifactRelativeSequencePrefixes")
PREBOOT_COMPONENTS = extract_c_string_array("kPXJBPrivatePrebootExactComponents")
PREBOOT_PREFIXES = extract_c_string_array("kPXJBPrivatePrebootComponentPrefixes")
HIDDEN_EXACT = extract_path_rule_array("kPXJBHiddenExactRules")
HIDDEN_PREFIX = extract_path_rule_array("kPXJBHiddenPrefixRules")


def components(value: str) -> list[str]:
    return [part for part in value.split("/") if part]


def basename(value: str) -> str:
    return value.rstrip("/").rsplit("/", 1)[-1] if value.rstrip("/") else ""


def sequence_prefix_match(value: str, prefix: str) -> bool:
    value_parts = components(value)
    for start in range(len(value_parts)):
        candidate = "/".join(value_parts[start:])
        if candidate.lower().startswith(prefix.lower()):
            return True
    return False


def private_preboot_hidden(value: str) -> bool:
    lower = value.lower()
    descendants: list[str] | None = None
    if value.startswith("/"):
        prefix = "/private/preboot"
        if not lower.startswith(prefix):
            return False
        if len(value) > len(prefix) and value[len(prefix)] != "/":
            return False
        descendants = components(value[len(prefix):])
    else:
        parts = components(value)
        for index in range(len(parts) - 1):
            if parts[index].lower() == "private" and parts[index + 1].lower() == "preboot":
                descendants = parts[index + 2:]
                break
    if not descendants:
        return False
    exact = {item.lower() for item in PREBOOT_COMPONENTS}
    prefixes = tuple(item.lower() for item in PREBOOT_PREFIXES)
    return any(
        part.lower() in exact or part.lower().startswith(prefixes)
        for part in descendants
    )


def artifact_match(value: str) -> bool:
    if not value:
        return False
    base = basename(value).lower()
    if base in {item.lower() for item in EXACT_BASENAMES}:
        return True
    if any(base.startswith(prefix.lower()) for prefix in BASENAME_PREFIXES):
        return True
    component_set = {part.lower() for part in components(value)}
    if component_set & {item.lower() for item in EXACT_COMPONENTS}:
        return True
    if private_preboot_hidden(value):
        return True
    if value.startswith("/"):
        return any(value.lower().startswith(prefix.lower()) for prefix in ABSOLUTE_PREFIXES)
    value_parts = components(value)
    for start in range(len(value_parts)):
        candidate = "/".join(value_parts[start:]).lower()
        if any(candidate == sequence.lower() or candidate.startswith(sequence.lower() + "/") for sequence in RELATIVE_EXACT):
            return True
    return any(sequence_prefix_match(value, prefix) for prefix in RELATIVE_PREFIXES)


def hidden_filesystem_path(value: str) -> bool:
    return (
        value in HIDDEN_EXACT
        or any(value.startswith(prefix) for prefix in HIDDEN_PREFIX)
        or private_preboot_hidden(value)
    )


def mount_path_hidden(value: str) -> bool:
    return (
        value == "/var/jb"
        or value.startswith("/var/jb/")
        or value == "/private/var/jb"
        or value.startswith("/private/var/jb/")
        or private_preboot_hidden(value)
    )


def mount_source_hidden(value: str) -> bool:
    if mount_path_hidden(value):
        return True
    for _, suffix in re.findall(r"(@)(/[^@]*)", value):
        if mount_path_hidden(suffix):
            return True
    return False


KNOWN_BINDS = {
    "/usr/standalone/firmware",
    "/System/Library/Pearl/ReferenceFrames",
    "/System/Library/Caches/com.apple.factorydata",
}


def mount_hidden(fs_type: str, mount_point: str, source: str) -> bool:
    jailbreak_mount = mount_path_hidden(mount_point) or mount_source_hidden(source)
    if fs_type == "bindfs":
        if mount_point in KNOWN_BINDS:
            return False
        return jailbreak_mount
    if mount_point != "/" and fs_type == "apfs" and "@" in source:
        return jailbreak_mount
    return False


@dataclass(frozen=True)
class Fixture:
    name: str
    value: str
    expected: bool


def run_artifact_matrix(matrix: Matrix) -> None:
    fixtures = [
        Fixture("exact basename: libsubstrate", "/usr/lib/libsubstrate.dylib", True),
        Fixture("renamed tweak basename", "@rpath/TLinkIOSTweak.dylib", True),
        Fixture("legacy tweak basename", "@rpath/ProjectXTweak.dylib", True),
        Fixture("exact basename is case-insensitive", "@rpath/LIBELLEKIT.DYLIB", True),
        Fixture("basename prefix: versioned FridaGadget", "@rpath/FridaGadget-16.2.dylib", True),
        Fixture("exact component: MobileSubstrate", "/Library/MobileSubstrate/DynamicLibraries/Foo.dylib", True),
        Fixture("absolute prefix: rootless var jb", "/var/jb/usr/lib/unknown-injector.dylib", True),
        Fixture("preboot component: jb dash", "/private/preboot/UUID/jb-123/procursus/usr/lib/foo.dylib", True),
        Fixture("false positive: ShadowAnalytics", "/Frameworks/ShadowAnalytics.framework/ShadowAnalytics", False),
        Fixture("false positive: LibertyNetworking", "/Frameworks/LibertyNetworking.framework/LibertyNetworking", False),
        Fixture("false positive: SubstrateKit", "/Frameworks/SubstrateKit.framework/SubstrateKit", False),
        Fixture("false positive: FridaKahlo", "/Frameworks/FridaKahlo.framework/FridaKahlo", False),
        Fixture("false positive: ProcursusBank", "/Applications/ProcursusBank.app/ProcursusBank", False),
        Fixture("false positive: substitute helper suffix", "/tmp/libsubstitutehelper.dylib", False),
        Fixture("false positive: libhooker tools suffix", "/tmp/libhookerTools.dylib", False),
        Fixture("false positive: preboot Cryptex", "/private/preboot/UUID/Cryptexes/OS/System/Library/libfoo.dylib", False),
    ]
    for fixture in fixtures:
        matrix.check(f"artifact: {fixture.name}", artifact_match(fixture.value) is fixture.expected)

    # Both image-name and dlopen surfaces intentionally consume this same policy.
    image_body = source_function("PXJBShouldHideImageName")
    dlopen_body = source_function("PXJBShouldBlockDlopenPath")
    matrix.check("source: image matcher delegates to artifact policy", "PXJBArtifactPathShouldMatch(name)" in image_body)
    matrix.check("source: dlopen matcher delegates to artifact policy", "PXJBArtifactPathShouldMatch(path)" in dlopen_body)
    matrix.check("source: image matcher has no substring scan", "PXStrContainsNoCase" not in image_body)
    matrix.check("source: dlopen matcher has no substring scan", "PXStrContainsNoCase" not in dlopen_body)


def run_relative_matrix(matrix: Matrix) -> None:
    fixtures = [
        Fixture("rootless exact sequence", "../../var/jb", True),
        Fixture("rootless sequence descendant", "../../var/jb/usr/lib/foo.dylib", True),
        Fixture("MobileSubstrate sequence", "Library/MobileSubstrate/DynamicLibraries/Foo.dylib", True),
        Fixture("frida directory sequence", "usr/lib/frida/agent.bin", True),
        Fixture("preboot jb sequence", "../../private/preboot/UUID/jb-ABCD/usr/lib/foo.dylib", True),
        Fixture("exact suspicious basename", "Frameworks/Shadow.dylib", True),
        Fixture("ordinary substrate documentation", "assets/substrate-guide.json", False),
        Fixture("var jboss is not var jb", "../../var/jboss/config.xml", False),
        Fixture("cyber cache is not cy dash", "Library/Caches/cyber.db", False),
        Fixture("frida substring is visible", "Frameworks/FridaKahlo.framework/FridaKahlo", False),
        Fixture("libhooker suffix is visible", "Frameworks/libhookerTools.dylib", False),
    ]
    for fixture in fixtures:
        matrix.check(f"relative: {fixture.name}", artifact_match(fixture.value) is fixture.expected)

    body = source_function("PXJBRelativePathLooksLikeProbe")
    matrix.check("source: unresolved relative matcher is boundary-aware", "PXJBArtifactPathShouldMatch(path)" in body)
    matrix.check("source: unresolved relative matcher rejects absolute input", "path[0] == '/'" in body)
    matrix.check("source: unresolved relative matcher removed broad needles", "needles" not in body and "PXStrContainsNoCase" not in body)


def run_preboot_matrix(matrix: Matrix) -> None:
    fixtures = [
        Fixture("preboot root visible", "/private/preboot", False),
        Fixture("preboot UUID root visible", "/private/preboot/UUID", False),
        Fixture("preboot Cryptex visible", "/private/preboot/UUID/Cryptexes/OS", False),
        Fixture("preboot System visible", "/private/preboot/UUID/System/Library", False),
        Fixture("preboot exact jb hidden", "/private/preboot/UUID/jb/usr/lib", True),
        Fixture("preboot jb prefix hidden", "/private/preboot/UUID/jb-1234/usr/lib", True),
        Fixture("preboot procursus hidden", "/private/preboot/UUID/procursus/usr/lib", True),
        Fixture("preboot dopamine hidden", "/private/preboot/UUID/dopamine/basebin", True),
        Fixture("prebootish prefix visible", "/private/prebootish/UUID/jb/usr/lib", False),
    ]
    for fixture in fixtures:
        matrix.check(f"preboot: {fixture.name}", hidden_filesystem_path(fixture.value) is fixture.expected)

    matrix.check("source: preboot root removed from exact rules", "/private/preboot" not in HIDDEN_EXACT)
    matrix.check("source: generic preboot prefix removed", "/private/preboot/" not in HIDDEN_PREFIX)
    matcher_body = source_function("PXJBPathMatchesHiddenRules")
    matrix.check("source: filesystem matcher uses dedicated preboot policy", "PXJBPrivatePrebootPathShouldHide(path)" in matcher_body)


def run_mount_matrix(matrix: Matrix) -> None:
    fixtures = [
        ("known Apple bindfs remains visible", "bindfs", "/usr/standalone/firmware", "/System/Library/Firmware", False),
        ("unknown ordinary bindfs fails open", "bindfs", "/private/var/mobile/Containers/Data/Application/ABC", "/tmp/app-bind", False),
        ("rootless bindfs mountpoint hidden", "bindfs", "/var/jb", "/private/preboot/UUID/jb-123", True),
        ("rootless bindfs source hidden", "bindfs", "/usr/local", "/private/preboot/UUID/jb-123/procursus", True),
        ("Apple APFS snapshot remains visible", "apfs", "/System/Volumes/Preboot", "com.apple.os.update-ABC@/private/preboot/UUID/Cryptexes", False),
        ("ordinary APFS at-source remains visible", "apfs", "/private/var/mobile", "disk3s1@com.apple.mobile", False),
        ("rootless APFS mountpoint hidden", "apfs", "/var/jb", "disk3s1@rootless", True),
        ("rootless APFS source suffix hidden", "apfs", "/usr/local", "disk3s1@/private/preboot/UUID/jb-123/procursus", True),
        ("root filesystem never filtered", "apfs", "/", "disk3s1@/private/preboot/UUID/jb-123", False),
    ]
    for name, fs_type, mount_point, source, expected in fixtures:
        matrix.check(f"mount: {name}", mount_hidden(fs_type, mount_point, source) is expected)

    body = source_function("PXJBMountEntryShouldHide")
    matrix.check("source: mount snapshot no longer reuses broad filesystem classifier", "PXJBPathShouldHide" not in body)
    matrix.check("source: unknown bindfs requires jailbreak evidence", "return jailbreakMount;" in body)
    matrix.check("source: mount decision checks both mountpoint and source", "PXJBMountSourceShouldHide" in body and "PXJBMountPathShouldHide" in body)


def run_rule_integrity_matrix(matrix: Matrix) -> None:
    arrays = {
        "exact basenames": EXACT_BASENAMES,
        "basename prefixes": BASENAME_PREFIXES,
        "exact components": EXACT_COMPONENTS,
        "absolute prefixes": ABSOLUTE_PREFIXES,
        "relative exact sequences": RELATIVE_EXACT,
        "relative prefixes": RELATIVE_PREFIXES,
        "preboot components": PREBOOT_COMPONENTS,
        "preboot prefixes": PREBOOT_PREFIXES,
    }
    for name, values in arrays.items():
        lowered = [value.lower() for value in values]
        matrix.check(f"rules: {name} are non-empty", bool(values))
        matrix.check(f"rules: {name} are unique case-insensitively", len(lowered) == len(set(lowered)))


def main() -> None:
    matrix = Matrix()
    run_rule_integrity_matrix(matrix)
    run_artifact_matrix(matrix)
    run_relative_matrix(matrix)
    run_preboot_matrix(matrix)
    run_mount_matrix(matrix)
    matrix.finish()


if __name__ == "__main__":
    main()
