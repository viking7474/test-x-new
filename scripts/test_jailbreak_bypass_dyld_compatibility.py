#!/usr/bin/env python3
"""Static regression matrix for compatibility-first dyld sanitization."""
from __future__ import annotations

import re
from pathlib import Path

import test_jailbreak_bypass_matcher_hardening as matcher_model

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "TLinkIOSTweak" / "JailbreakBypassHooks.x").read_text(encoding="utf-8")


class Matrix:
    def __init__(self) -> None:
        self.total = 0
        self.failed = 0

    def check(self, label: str, condition: bool) -> None:
        self.total += 1
        print(f"{'PASS' if condition else 'FAIL'}: {label}")
        if not condition:
            self.failed += 1

    def finish(self) -> None:
        if self.failed:
            raise SystemExit(f"dyld compatibility matrix: FAIL ({self.failed}/{self.total})")
        print(f"dyld compatibility matrix: PASS ({self.total}/{self.total})")


def source_function(name: str) -> str:
    match = re.search(
        rf"(?:static\s+)?[^;\n]+\b{re.escape(name)}\s*\([^;]*?\)\s*\{{",
        SOURCE,
        re.S,
    )
    if not match:
        raise AssertionError(f"function not found: {name}")
    start = match.start()
    brace = SOURCE.index("{", match.start(), match.end())
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
            elif char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    return SOURCE[start:index + 1]
        elif state == "line":
            if char == "\n":
                state = "code"
        elif state == "block":
            if char == "*" and nxt == "/":
                state = "code"
                index += 2
                continue
        else:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                state = "code"
        index += 1
    raise AssertionError(f"unterminated function: {name}")


def extract_aliases() -> list[str]:
    body = source_function("PXJBSanitizedImageName")
    array = re.search(r"static const char \*const aliases\[\] = \{(.*?)\};", body, re.S)
    if not array:
        raise AssertionError("alias array not found")
    return re.findall(r'"([^"]+)"', array.group(1))


def fnv1a_casefold(value: str) -> int:
    result = 2166136261
    for byte in value.encode("utf-8"):
        if 65 <= byte <= 90:
            byte += 32
        result ^= byte
        result = (result * 16777619) & 0xFFFFFFFF
    return result


def main() -> None:
    matrix = Matrix()
    legacy = (
        "PXDyldSnapshot", "gDyldCurrentSnapshot", "tls_dyldSnapshot",
        "PXDyldEnsureVisibleMap", "PXDyldRebuildVisibleMapLocked",
        "hook__dyld_image_count", "hook__dyld_get_image_header",
        "hook__dyld_get_image_vmaddr_slide", "orig__dyld_image_count",
        "orig__dyld_get_image_header", "orig__dyld_get_image_vmaddr_slide",
    )
    matrix.check("dyld: snapshot and remap removed", all(token not in SOURCE for token in legacy))
    matrix.check("dyld: count remains unhooked", 'FindSymbol("_dyld_image_count")' not in SOURCE)
    matrix.check("dyld: header remains unhooked", 'FindSymbol("_dyld_get_image_header")' not in SOURCE)
    matrix.check("dyld: slide remains unhooked", 'FindSymbol("_dyld_get_image_vmaddr_slide")' not in SOURCE)
    matrix.check("dyld: name remains hooked", 'FindSymbol("_dyld_get_image_name")' in SOURCE)

    name_hook = source_function("hook__dyld_get_image_name")
    matrix.check("dyld: original index is preserved", "PXDyldOriginalImageName(image_index)" in name_hook)
    matrix.check("dyld: no real-index remap", "realIndex" not in name_hook and "map[" not in name_hook)
    matrix.check("dyld: shared name sanitizer used", "PXJBSanitizedImageName(name)" in name_hook)

    aliases = extract_aliases()
    forbidden = ("substrate", "frida", "jailbreak", "tlinkios", "cy-", "dopamine", "ellekit")
    matrix.check("alias: pool size is stable", len(aliases) == 16)
    matrix.check("alias: aliases are unique", len(aliases) == len(set(aliases)))
    matrix.check("alias: aliases are absolute system paths", all(x.startswith(("/System/Library/", "/usr/lib/")) for x in aliases))
    matrix.check("alias: no jailbreak fingerprints", all(not any(term in x.lower() for term in forbidden) for x in aliases))
    matrix.check("alias: project matcher leaves every alias visible", all(not matcher_model.artifact_match(x) for x in aliases))
    sample = "/Library/MobileSubstrate/DynamicLibraries/TLinkIOSTweak.dylib"
    matrix.check("rename: current tweak image is hidden", matcher_model.artifact_match(sample))
    matrix.check("rename: legacy tweak image remains hidden", matcher_model.artifact_match("@rpath/ProjectXTweak.dylib"))
    matrix.check("alias: hash is case-insensitive", fnv1a_casefold(sample) == fnv1a_casefold(sample.swapcase()))
    matrix.check("alias: hash selects valid entry", fnv1a_casefold(sample) % len(aliases) < len(aliases))

    dladdr = source_function("hook_dladdr")
    matrix.check("dladdr: only dli_fname is sanitized", "info->dli_fname = PXJBSanitizedImageName" in dladdr)
    matrix.check("dladdr: metadata is not zeroed", "memset(info" not in dladdr)
    matrix.check("dladdr: success result is preserved", dladdr.count("return result;") >= 1)

    objc_list = source_function("hook_objc_copyImageNames")
    matrix.check("objc: outCount is not reduced", re.search(r"\*outCount\s*=(?!=)", objc_list) is None)
    matrix.check("objc: replacement retains count", "calloc(count + 1" in objc_list and "out[count] = NULL" in objc_list)
    matrix.check("objc: entries are sanitized in place-order", "out[i] = PXJBSanitizedImageName(list[i])" in objc_list)
    matrix.check("objc: allocation failure fails open", "if (!out) return list" in objc_list)

    class_name = source_function("hook_class_getImageName")
    matrix.check("objc: class image does not return NULL", "return NULL" not in class_name)
    matrix.check("objc: class image uses shared sanitizer", "return PXJBSanitizedImageName(name)" in class_name)

    phdr = source_function("px_dl_iterate_phdr_cb")
    matrix.check("phdr: hidden entries are not skipped", "return 0; // skip" not in phdr)
    matrix.check("phdr: name-field ABI guard is used", "offsetof(struct dl_phdr_info, dlpi_name)" in phdr and "size >= nameFieldEnd" in phdr)
    matrix.check("phdr: full runtime size is copied", "malloc(size)" in phdr and "memcpy(copy, info, size)" in phdr)
    matrix.check("phdr: only copied name is replaced", "((struct dl_phdr_info *)copy)->dlpi_name = sanitized" in phdr)
    matrix.check("phdr: callback cardinality is preserved", "ctx->cb((struct dl_phdr_info *)copy, size, ctx->data)" in phdr)
    matrix.check("phdr: allocation failure fails open", "return ctx->cb(info, size, ctx->data)" in phdr)

    start = SOURCE.index("// Compatibility-first dyld concealment")
    end = SOURCE.index("// Phase 3 extension: block suspicious add_image", start)
    install = SOURCE[start:end]
    matrix.check("install: only name and dladdr are resolved", install.count("FindSymbol(") == 2)
    matrix.check("install: only indexed name hook is installed", "hook__dyld_get_image_name" in install and all(token not in install for token in ("hook__dyld_image_count", "hook__dyld_get_image_header", "hook__dyld_get_image_vmaddr_slide")))
    matrix.check("audit: name trampoline remains mandatory", 'kPXJBCapabilityDyldIndexed, "_dyld_get_image_name", orig__dyld_get_image_name, true' in SOURCE)
    matrix.check("audit: pass-through APIs are absent", all(token not in SOURCE for token in ('"_dyld_image_count", orig_', '"_dyld_get_image_header", orig_', '"_dyld_get_image_vmaddr_slide", orig_')))

    matrix.finish()


if __name__ == "__main__":
    main()
